-- Pure per-player threat bucket (delivery D8): Safe, Distant, Near or Chase from the guardian's mode, its
-- horizontal distance, whether this player is its quarry, hiding and the safe zone. Rises are immediate; falls
-- are held so the music does not flicker. The server publishes the level; the client plays audio from it.
local Threat = {}

Threat.LEVELS = table.freeze({ "Safe", "Distant", "Near", "Chase" })
Threat.CONFIG = table.freeze({
	DISTANT_RADIUS = 120,
	NEAR_RADIUS = 55,
	SEARCH_RADIUS = 80, -- Suspicious, Investigate or Search this close reads as Near
	HOLD = table.freeze({ Chase = 3, Near = 3, Distant = 5 }), -- seconds before one step down
})
local C = Threat.CONFIG
local RANK = { Safe = 1, Distant = 2, Near = 3, Chase = 4 }
local COMBAT = { Alert = true, Hunt = true, Telegraph = true }
local SEARCHING = { Suspicious = true, Investigate = true, Search = true }

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Threat.rank(level)
	return RANK[level] or 0
end

-- raw({ mode, distance, targetIsMe, hidden, safe, alive }) -> level, before any hold.
function Threat.raw(input)
	if type(input) ~= "table" or input.alive ~= true or input.safe == true then return "Safe" end
	local mode, distance = input.mode, input.distance
	if COMBAT[mode] and input.targetIsMe == true then
		return input.hidden == true and "Near" or "Chase"
	end
	if not finite(distance) or distance < 0 then return "Safe" end
	if mode == "Retreat" and distance > C.NEAR_RADIUS then return "Safe" end
	if distance <= C.NEAR_RADIUS or (SEARCHING[mode] and distance <= C.SEARCH_RADIUS) then return "Near" end
	if COMBAT[mode] or distance <= C.DISTANT_RADIUS then return "Distant" end
	return "Safe"
end

function Threat.new()
	return { level = "Safe", lowerSince = nil }
end

-- update(state, input, now) -> the held level. The safe zone drops to Safe at once.
function Threat.update(state, input, now)
	if type(state) ~= "table" then return "Safe" end
	if not RANK[state.level] then state.level = "Safe" end
	if not finite(now) then return state.level end
	local target = Threat.raw(input)
	if type(input) == "table" and input.safe == true then
		state.level, state.lowerSince = "Safe", nil
	elseif RANK[target] >= RANK[state.level] then
		state.level, state.lowerSince = target, nil
	else
		state.lowerSince = state.lowerSince or now
		if now - state.lowerSince >= (C.HOLD[state.level] or 0) - 1e-9 then
			state.level = Threat.LEVELS[RANK[state.level] - 1]
			state.lowerSince = RANK[target] < RANK[state.level] and now or nil
		end
	end
	return state.level
end

return Threat
