-- SC0 shared beast visibility (odd/tasks/wildbound-scuttler.md, docs/design/wildbound-scuttler-plan.md Q4). Pure: who
-- besides the target sees an encounter, and what they receive. The target always gets every event (the beast script
-- sends it as before); a bystander is another player within Config.AUDIENCE.RADIUS (flat studs) of the beast, kept
-- until RADIUS + LEAVE_MARGIN, at most MAX_PER_CLIENT beasts each (the nearest first; a current member counts as
-- LEAVE_MARGIN nearer, so two beasts at about the same distance never trade places every refresh). A viewer in a safe
-- zone sees no beast and a viewer in the Pradera only the summoned kids beasts (an encounter never exists there for its
-- own target either). A bystander receives only visual events (posture, tells, moves, ends), copied without any effect
-- field and marked `bystander = true`, so a client can never apply a hit, slow, knock or mark that was not meant for
-- it; a late joiner gets a spawn snapshot plus a replay of the live visual state (tells, lane, circle, move). La Silueta
-- is personal and never shared. Nothing here touches the director, the budget, the dodge states or the hit path; it
-- never reads the clock (callers pass `at`).
local Audience = {}

-- Beasts that stay visible to their own player only (owner decision Q4).
Audience.PERSONAL = table.freeze({ Silueta = true })

-- Events a bystander may draw. Anything else (Hit, Afflict, Exposure, SightBreak, Notice, a future type) stays with the
-- target: a new event is private until it is listed here.
Audience.VISUAL = table.freeze({ Spawn = true, Snap = true, Phase = true, Tell = true, TellEnd = true, Strike = true,
	Move = true, Windup = true, Lock = true, Dash = true, Recover = true, Telegraph = true, Freeze = true, Leap = true,
	Land = true, Cancel = true, Disengage = true, End = true, Stalk = true, Hunt = true,
	-- BR2 (odd/tasks/wildbound-beast-revision.md): Pouncer's web throw and ball are seen by nearby players (the root, an
	-- Afflict, stays with the target).
	Throw = true, Web = true, WebEnd = true,
	-- DG5 (odd/tasks/wildbound-caramelo-v2.md): Don Glaseon's anger tint, seen by every nearby player.
	Anger = true })

-- Fields that carry an effect or a target-only cue (the dodge verdict, a HUD line); never copied to a bystander.
Audience.EFFECT_FIELDS = table.freeze({ "damage", "knock", "slow", "sticky", "mark", "eggDropped", "dodged", "line", "hit" })

function Audience.shared(beast)
	return type(beast) == "string" and not Audience.PERSONAL[beast]
end

function Audience.kind(event)
	if type(event) == "table" and type(event.type) == "string" and Audience.VISUAL[event.type] then return "visual" end
	return "target"
end

-- A shallow copy for bystanders, or nil when the event is not visual. The target's own event is never changed.
function Audience.forBystander(event)
	if Audience.kind(event) ~= "visual" then return nil end
	local copy = table.clone(event)
	for _, field in ipairs(Audience.EFFECT_FIELDS) do copy[field] = nil end
	copy.bystander = true
	return copy
end

-- The spawn snapshot a bystander gets on entering: the beast where it is now, in its current phase.
function Audience.spawnFor(e, at)
	local pos = e.pos or {}
	return { type = "Spawn", id = e.id, beast = e.beast, at = at, pos = { x = pos.x, y = pos.y, z = pos.z },
		dx = e.dx, dz = e.dz, phase = e.phase, bystander = true }
end

-- The cleanup a bystander gets on leaving the radius (the client ends that view like any End).
function Audience.leaveFor(id, at)
	return { type = "End", id = id, at = at, reason = "OutOfRange", bystander = true }
end

function Audience.new()
	-- members[encounter id][userId] = true; snapAt[id][userId] = last snapshot time; memory[id] = the live visual state
	return { members = {}, snapAt = {}, memory = {} }
end

-- The live visual state of an encounter, kept from its bystander copies so a late joiner can be brought up to date:
-- the last Phase, Viper's lane (Windup, Lock, Dash until Recover or Cancel), Pouncer's circle (Telegraph, Freeze, Leap
-- until Land or Cancel), the open tells (until their Strike or TellEnd), the last Move and a Disengage.
local function memoryOf(state, id)
	state.memory = state.memory or {}
	local mem = state.memory[id]
	if not mem then
		mem = { tells = {} }
		state.memory[id] = mem
	end
	return mem
end

function Audience.remember(state, id, copy)
	if type(copy) ~= "table" or Audience.kind(copy) ~= "visual" then return end
	local kind = copy.type
	if kind == "End" then
		if state.memory then state.memory[id] = nil end
		return
	end
	local mem = memoryOf(state, id)
	if kind == "Phase" then mem.phase = copy
	elseif kind == "Windup" then mem.lane = { copy }
	elseif (kind == "Lock" or kind == "Dash") and mem.lane then table.insert(mem.lane, copy)
	elseif kind == "Recover" then mem.lane = nil
	elseif kind == "Telegraph" then mem.circle = { copy }
	elseif (kind == "Freeze" or kind == "Leap") and mem.circle then table.insert(mem.circle, copy)
	elseif kind == "Land" then mem.circle = nil
	elseif kind == "Cancel" then mem.lane, mem.circle = nil, nil
	elseif kind == "Tell" and type(copy.tell) == "string" then mem.tells[copy.tell] = copy
	elseif (kind == "TellEnd" or kind == "Strike") and type(copy.tell) == "string" then mem.tells[copy.tell] = nil
	elseif kind == "Move" then mem.move = copy.kind ~= "blink" and copy or nil
	elseif kind == "Disengage" then
		mem.lane, mem.circle, mem.move, mem.disengage = nil, nil, nil, copy
		table.clear(mem.tells)
	end
end

-- When a remembered move ends (the same rule as the client); nil when unknown, so the move is replayed.
local function moveEnd(m)
	if m.kind == "dash" and type(m.length) == "number" and type(m.speed) == "number" and type(m.at) == "number" then
		return m.at + m.length / math.max(m.speed, 1e-3)
	elseif m.kind == "arc" then return m.landAt
	elseif m.kind == "burrow" or m.kind == "slide" then return m.untilAt end
	return nil
end

-- The events a late joiner gets right after its spawn snapshot, in an order the client can apply: the phase, the lane,
-- the circle, the open tells (sorted), a move still running, a Disengage.
function Audience.replay(state, id, at)
	local mem = state.memory and state.memory[id]
	if not mem then return {} end
	local list = {}
	if mem.phase then table.insert(list, mem.phase) end
	for _, ev in ipairs(mem.lane or {}) do table.insert(list, ev) end
	for _, ev in ipairs(mem.circle or {}) do table.insert(list, ev) end
	local keys = {}
	for key in pairs(mem.tells) do table.insert(keys, key) end
	table.sort(keys)
	for _, key in ipairs(keys) do table.insert(list, mem.tells[key]) end
	if mem.move then
		local endAt = moveEnd(mem.move)
		if type(endAt) ~= "number" or at < endAt then table.insert(list, mem.move) end
	end
	if mem.disengage then table.insert(list, mem.disengage) end
	return list
end

local function leave(state, id, userId)
	local set = state.members[id]
	if set then set[userId] = nil end
	local snaps = state.snapAt[id]
	if snaps then snaps[userId] = nil end
end

local function sortedKeys(set)
	local list = {}
	for userId in pairs(set or {}) do table.insert(list, userId) end
	table.sort(list, function(a, b) return tostring(a) < tostring(b) end)
	return list
end

-- Re-evaluates every membership. `encounters`: { id, beast, x, z, target = userId, summoned }; `viewers`: the players
-- with a living body { userId, x, z, safe, meadow } (a missing viewer leaves everything). Returns the enters and the
-- leaves as { id, userId } lists, sorted, so the caller sends one Spawn per enter and one End per leave. Leaves are
-- applied at once. With `deliver(item)`, an enter is committed only when deliver returns true without an error (its
-- spawn was sent), and the returned enters are the committed ones; a failed one is retried on the next refresh.
function Audience.refresh(state, encounters, viewers, settings, deliver)
	local radius, margin, cap = settings.RADIUS, settings.LEAVE_MARGIN, settings.MAX_PER_CLIENT
	local wanted = {} -- [id] = { [userId] = true }
	local byId = {}
	for _, e in ipairs(encounters) do byId[e.id] = e end
	for _, v in ipairs(viewers) do
		local candidates = {}
		for _, e in ipairs(encounters) do
			local allowed = v.safe ~= true and (v.meadow ~= true or e.summoned == true)
			if allowed and Audience.shared(e.beast) and e.target ~= v.userId then
				local d = math.sqrt((e.x - v.x) ^ 2 + (e.z - v.z) ^ 2)
				local member = state.members[e.id] and state.members[e.id][v.userId]
				if d <= radius or (member and d <= radius + margin) then
					-- Hysteresis on the cap: a current member ranks as if LEAVE_MARGIN nearer.
					table.insert(candidates, { id = e.id, d = member and d - margin or d })
				end
			end
		end
		table.sort(candidates, function(a, b)
			if a.d ~= b.d then return a.d < b.d end
			return tostring(a.id) < tostring(b.id)
		end)
		for i = 1, math.min(cap, #candidates) do
			local id = candidates[i].id
			wanted[id] = wanted[id] or {}
			wanted[id][v.userId] = true
		end
	end
	local enters, leaves = {}, {}
	for id, set in pairs(state.members) do
		for _, userId in ipairs(sortedKeys(set)) do
			if not (wanted[id] and wanted[id][userId]) then table.insert(leaves, { id = id, userId = userId }) end
		end
	end
	for id, set in pairs(wanted) do
		for _, userId in ipairs(sortedKeys(set)) do
			if not (state.members[id] and state.members[id][userId]) then table.insert(enters, { id = id, userId = userId }) end
		end
	end
	for _, item in ipairs(leaves) do leave(state, item.id, item.userId) end
	for id, set in pairs(state.members) do
		if next(set) == nil or not byId[id] then state.members[id] = nil; state.snapAt[id] = nil end
	end
	if state.memory then
		for id in pairs(state.memory) do if not byId[id] then state.memory[id] = nil end end
	end
	local function order(a, b)
		if a.id ~= b.id then return tostring(a.id) < tostring(b.id) end
		return tostring(a.userId) < tostring(b.userId)
	end
	table.sort(enters, order)
	table.sort(leaves, order)
	local committed = {}
	for _, item in ipairs(enters) do
		local ok, sent = true, true
		if deliver then ok, sent = pcall(deliver, item) end
		if ok and sent == true then
			state.members[item.id] = state.members[item.id] or {}
			state.members[item.id][item.userId] = true
			table.insert(committed, item)
		end
	end
	return committed, leaves
end

-- The bystanders of one encounter (userIds, sorted).
function Audience.recipients(state, id)
	return sortedKeys(state.members[id])
end

-- The encounter ended: its bystanders (to send the End to) once, then it is forgotten.
function Audience.close(state, id)
	local list = sortedKeys(state.members[id])
	state.members[id] = nil
	state.snapAt[id] = nil
	if state.memory then state.memory[id] = nil end
	return list
end

-- A player left the server: dropped from every audience.
function Audience.forgetViewer(state, userId)
	for id in pairs(state.members) do leave(state, id, userId) end
end

-- Whether a bystander's snapshot is due (at most one every `seconds`); never for a non-member.
function Audience.snapDue(state, id, userId, at, seconds)
	local set = state.members[id]
	if not set or not set[userId] then return false end
	local snaps = state.snapAt[id]
	if not snaps then
		snaps = {}
		state.snapAt[id] = snaps
	end
	local last = snaps[userId]
	if last and at - last < seconds - 1e-6 then return false end
	snaps[userId] = at
	return true
end

return Audience
