-- Pure per-player Silueta awareness. Inputs are server-read observations passed by value and the
-- clock is injected. See docs/mechanics/wildbound-awareness.md for states and wiring.
local Awareness = {}

-- All hypotheses, justified in the mechanics document. SEARCH_SECONDS mirrors the literal in
-- WildboundSiluetaHunt, and a contract runs the two together so they cannot drift silently.
Awareness.CONSTANTS = table.freeze({
	SEARCH_SECONDS = 1.5,
	SEEN_HOLD_SECONDS = 0.6,
	ALLY_ENTER_RANGE = 46,
	ALLY_EXIT_RANGE = 54,
})

local CONSTANTS = Awareness.CONSTANTS
local EPSILON = 1e-7
local THREAT_MODES = table.freeze({ Alert = true, Hunt = true, Telegraph = true })
local STATES = table.freeze({ seen = true, searching = true, ally = true, none = true })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Awareness.new()
	return { players = {} }
end

-- First valid entry per id wins. Studio user ids are negative, so any finite number is an identity.
local function readPlayers(list)
	local byId = {}
	for _, entry in ipairs(list) do
		if type(entry) == "table" and finite(entry.id) and byId[entry.id] == nil then
			byId[entry.id] = entry
		end
	end
	return byId
end

-- The one target this step, or nil when nobody is threatened. A threat needs a known mode, a live
-- target on its locked life, and either sight now or a search that has not expired yet.
local function readThreat(input, byId, now)
	if now == nil or type(input.mode) ~= "string" or not THREAT_MODES[input.mode] then return nil end
	if not finite(input.targetId) or input.targetLife == nil then return nil end
	local target = byId[input.targetId]
	if not target or target.alive ~= true or target.life ~= input.targetLife then return nil end
	if input.targetVisible == true then
		local telegraph = input.telegraphEndsAt
		local deadline = input.mode == "Telegraph" and finite(telegraph) and telegraph > 0 and telegraph or nil
		return { target = target, visible = true, attackEndsAt = deadline }
	end
	if not finite(input.lastVisibleAt) then return nil end
	-- A clock that stepped back cannot make the countdown longer than the search itself.
	local lastVisibleAt = math.min(input.lastVisibleAt, now)
	-- Chase pass: the world passes the hunt's memory as searchSeconds; otherwise the 1.5 s default.
	local search = finite(input.searchSeconds) and input.searchSeconds > 0 and input.searchSeconds or CONSTANTS.SEARCH_SECONDS
	if now - lastVisibleAt >= search then return nil end
	return { target = target, visible = false, searchEndsAt = lastVisibleAt + search }
end

-- Returns state, searchEndsAt, attackEndsAt and updates this player's debounce memory.
local function evaluate(memory, entry, threat, now)
	if not threat or entry.alive ~= true then
		memory.lastSeenAt, memory.near = nil, false
		return "none"
	end
	if entry == threat.target then
		-- A retarget falls back through the exit range, so a former target is not dropped abruptly.
		memory.near = true
		if threat.visible then
			memory.lastSeenAt = now
			return "seen", nil, threat.attackEndsAt
		end
		-- Only sight flicker is held. Retreat, retarget, removal and a new life all skip this path.
		if memory.lastSeenAt and now - memory.lastSeenAt + EPSILON < CONSTANTS.SEEN_HOLD_SECONDS then
			return "seen"
		end
		memory.lastSeenAt = nil
		return "searching", threat.searchEndsAt
	end
	memory.lastSeenAt = nil
	local range = memory.near and CONSTANTS.ALLY_EXIT_RANGE or CONSTANTS.ALLY_ENTER_RANGE
	memory.near = entry.safe ~= true and finite(entry.distance) and entry.distance >= 0 and entry.distance <= range
	return memory.near and "ally" or "none"
end

-- input = { now, mode, targetId, targetLife, targetVisible, lastVisibleAt, telegraphEndsAt, searchSeconds?,
--           players = { { id, life, alive, distance, safe } } }
-- Returns { [id] = { state, searchEndsAt?, attackEndsAt?, changed } }, each table fresh.
function Awareness.step(state, input)
	local results = {}
	if type(state) ~= "table" or type(state.players) ~= "table"
		or type(input) ~= "table" or type(input.players) ~= "table" then
		return results
	end
	local byId = readPlayers(input.players)
	local now = finite(input.now) and input.now or nil
	-- A backward clock cancels holds, so the raw truth shows instead of a stretched debounce.
	local backward = now ~= nil and state.lastNow ~= nil and now < state.lastNow
	if now ~= nil then state.lastNow = now end
	local threat = readThreat(input, byId, now)
	for id in pairs(state.players) do
		if byId[id] == nil then state.players[id] = nil end
	end
	for id, entry in pairs(byId) do
		local memory = state.players[id]
		if not memory then
			memory = { state = "none", life = entry.life, near = false }
			state.players[id] = memory
		elseif memory.life ~= entry.life then
			memory.life, memory.lastSeenAt, memory.near = entry.life, nil, false
		end
		if backward then memory.lastSeenAt = nil end
		local current, searchEndsAt, attackEndsAt = evaluate(memory, entry, threat, now)
		results[id] = { state = current, searchEndsAt = searchEndsAt, attackEndsAt = attackEndsAt,
			changed = current ~= memory.state or searchEndsAt ~= memory.searchEndsAt
				or attackEndsAt ~= memory.attackEndsAt }
		memory.state, memory.searchEndsAt, memory.attackEndsAt = current, searchEndsAt, attackEndsAt
	end
	return results
end

-- The per-player value for a later snapshot: one string plus at most one finite number.
function Awareness.toSnapshot(result)
	if type(result) ~= "table" or type(result.state) ~= "string" or not STATES[result.state] then
		return { state = "none" }
	end
	local snapshot = { state = result.state }
	if result.state == "searching" and finite(result.searchEndsAt) then
		snapshot.searchEndsAt = result.searchEndsAt
	elseif result.state == "seen" and finite(result.attackEndsAt) then
		snapshot.attackEndsAt = result.attackEndsAt
	end
	return snapshot
end

return Awareness
