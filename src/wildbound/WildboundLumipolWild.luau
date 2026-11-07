-- Pure rules for wild Lumipol: where they spawn, how they behave, who may start a capture on a slot,
-- and what carrying eggs costs. Positions, time and randomness are passed in; nothing here reads the world.
-- Numbers are hypotheses. See docs/mechanics/wildbound-capture.md (Spawn slots, States, Egg carry cost).
local Wild = {}

Wild.CONSTANTS = table.freeze({
	STEP = 0.2,
	WANDER_SPEED = 2,
	WANDER_RADIUS = 6,
	PAUSE_MIN = 2,
	PAUSE_MAX = 5,
	CURIOUS_RANGE = 12,
	ARRIVE = 0.05,
	FLEE_SPEED = 10,
	FLEE_MIN = 8,
	FLEE_MAX = 12,
	FLEE_LIMIT = 10,
	SPOOK_SECONDS = 2,
	CROWDED_PLAYERS = 5,
	WALK_SPEED = 16,
	-- Silueta's fastest speed is 8 (fog night), so a loaded carrier must stay above it.
	SILUETA_FASTEST = 8,
})
local C = Wild.CONSTANTS

local function slot(id, kind, tier, x, z)
	return table.freeze({ id = id, kind = kind, tier = tier, x = x, z = z })
end

-- Coordinates are the capture document's slots. "Safe" is outside fog; "Territory" is inside Silueta's
-- leash; "Fog" is inside fog but outside the leash, so a no-Silueta route exists.
Wild.SLOTS = table.freeze({
	slot("S0a", "Creature", "Safe", -95, 75),
	slot("S0b", "Creature", "Safe", -112, 92),
	slot("L1", "Creature", "Territory", -10, -60),
	slot("L2", "Creature", "Territory", 30, -105),
	slot("L3", "Creature", "Territory", 65, -60),
	slot("L4", "Creature", "Fog", 110, 5),
	slot("E1", "Egg", nil, 35, -99),
	slot("E2", "Egg", nil, -38, -85),
	slot("E3", "Egg", nil, 60, -125),
})

-- Which L slot is added first as players join: a Territory slot, then the Fog route, then the rest.
local LONG_ORDER = table.freeze({ "L1", "L4", "L2", "L3" })
local EGG_ORDER = table.freeze({ "E1", "E2", "E3" })

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function Wild.slot(id)
	for _, entry in ipairs(Wild.SLOTS) do
		if entry.id == id then return entry end
	end
	return nil
end

local function players(count)
	if not finite(count) or count < 1 then return 1 end
	return math.floor(count)
end

-- D4: slots scale with connected players. Always returns the slots in the SLOTS order.
function Wild.activeSlotIds(count)
	local n = players(count)
	local want = { S0a = true, E1 = true }
	local long, eggs = 2, 1
	if n >= 2 then long, eggs = 3, 2 end
	if n >= 3 then
		want.S0b = true
		long, eggs = 4, 3
	end
	for index = 1, long do want[LONG_ORDER[index]] = true end
	for index = 1, eggs do want[EGG_ORDER[index]] = true end
	local list = {}
	for _, entry in ipairs(Wild.SLOTS) do
		if want[entry.id] then table.insert(list, entry.id) end
	end
	return list
end

-- Seconds until a taken slot is filled again. Crowded servers refill the far slots sooner.
function Wild.respawnSeconds(entry, count)
	if type(entry) ~= "table" then return nil end
	local crowded = players(count) >= C.CROWDED_PLAYERS
	if entry.kind == "Egg" then return crowded and 40 or 60 end
	if entry.tier == "Safe" then return 8 end
	return crowded and 30 or 45
end

-- The first-capture rule for the Safe slots, from the player's snapshot. Fails closed on a bad snapshot.
function Wild.slotRefusal(tier, snapshot)
	if tier ~= "Safe" then return nil end
	if type(snapshot) ~= "table" or type(snapshot.registered) ~= "table" or type(snapshot.pending) ~= "table" then
		return "InvalidContext"
	end
	if #snapshot.registered > 0 then return "FirstCaptureOnly" end
	for _, item in ipairs(snapshot.pending) do
		if type(item) == "table" and item.kind == "Creature" then return "FirstCapturePending" end
	end
	return nil
end

function Wild.eggsCarried(snapshot)
	local total = 0
	if type(snapshot) ~= "table" or type(snapshot.pending) ~= "table" then return 0 end
	for _, item in ipairs(snapshot.pending) do
		if type(item) == "table" and item.kind == "Egg" then total += 1 end
	end
	return total
end

-- Walk speed by eggs in the bag. Captured creatures add no cost. Never at or below Silueta's fastest.
function Wild.carrySpeed(eggs)
	if not finite(eggs) or eggs < 1 then return C.WALK_SPEED end
	if eggs < 2 then return 11 end
	if eggs < 3 then return 10 end
	return 9
end

local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil, nil end
	return x / length, z / length
end

local function pause(rand)
	return C.PAUSE_MIN + rand() * (C.PAUSE_MAX - C.PAUSE_MIN)
end

function Wild.newBrain(entry, rand)
	return { mode = "Wander", x = entry.x, z = entry.z, cx = entry.x, cz = entry.z, fx = 0, fz = -1,
		pause = pause(rand), moved = false, spookFor = 0, fleeLeft = 0, endX = entry.x, endZ = entry.z }
end

local function face(brain, x, z)
	local fx, fz = unit(x - brain.x, z - brain.z)
	if fx then brain.fx, brain.fz = fx, fz end
end

-- A capture began: frozen, listening, turned toward its owner.
function Wild.reserve(brain, x, z)
	brain.mode, brain.fleeLeft, brain.moved = "Reserved", 0, false
	if finite(x) and finite(z) then face(brain, x, z) end
end

-- The capture failed: back away from the threat, within FLEE_LIMIT of the slot centre.
function Wild.spook(brain, x, z, rand)
	brain.mode, brain.spookFor, brain.moved = "Spooked", 0, false
	local dx, dz = unit(brain.x - (finite(x) and x or brain.x), brain.z - (finite(z) and z or brain.z))
	if not dx then
		local angle = rand() * 2 * math.pi
		dx, dz = math.cos(angle), math.sin(angle)
	end
	local distance = C.FLEE_MIN + rand() * (C.FLEE_MAX - C.FLEE_MIN)
	local ex, ez = brain.x + dx * distance, brain.z + dz * distance
	local ox, oz = ex - brain.cx, ez - brain.cz
	local length = math.sqrt(ox * ox + oz * oz)
	if length > C.FLEE_LIMIT then
		ex, ez = brain.cx + ox / length * C.FLEE_LIMIT, brain.cz + oz / length * C.FLEE_LIMIT
	end
	brain.endX, brain.endZ, brain.fleeLeft = ex, ez, 1
	face(brain, ex, ez)
end

-- The capture ended without a flee (the owner left, a server fault): simply wander again.
function Wild.release(brain)
	brain.mode, brain.fleeLeft, brain.moved = "Wander", 0, false
	brain.pause, brain.targetX, brain.targetZ = 1, nil, nil
end

local function approach(brain, tx, tz, speed, dt)
	local dx, dz = tx - brain.x, tz - brain.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length <= C.ARRIVE then return true end
	local move = math.min(length, speed * dt)
	brain.x, brain.z = brain.x + dx / length * move, brain.z + dz / length * move
	brain.fx, brain.fz = dx / length, dz / length
	brain.moved = true
	return move >= length - 1e-9
end

-- One fixed step. near = { x, z } of the nearest live player or nil. rand() returns a number in [0, 1).
function Wild.step(brain, dt, near, rand)
	brain.moved = false
	if not finite(dt) or dt <= 0 then return brain end
	dt = math.min(dt, 0.5)
	local mode = brain.mode
	if mode == "Reserved" then
		if type(near) == "table" and finite(near.x) and finite(near.z) then face(brain, near.x, near.z) end
		return brain
	end
	if mode == "Spooked" then
		brain.spookFor += dt
		if brain.fleeLeft > 0 then
			if approach(brain, brain.endX, brain.endZ, C.FLEE_SPEED, dt) then brain.fleeLeft = 0 end
		end
		if brain.spookFor >= C.SPOOK_SECONDS and brain.fleeLeft == 0 then
			brain.mode, brain.pause, brain.targetX, brain.targetZ = "Wander", pause(rand), nil, nil
		end
		return brain
	end
	local close = false
	if type(near) == "table" and finite(near.x) and finite(near.z) then
		local dx, dz = near.x - brain.x, near.z - brain.z
		close = math.sqrt(dx * dx + dz * dz) <= C.CURIOUS_RANGE
		if close then face(brain, near.x, near.z) end
	end
	if close then
		brain.mode = "Curious"
		return brain
	end
	if mode == "Curious" then
		brain.mode, brain.pause, brain.targetX, brain.targetZ = "Wander", 1, nil, nil
	end
	if brain.targetX then
		if approach(brain, brain.targetX, brain.targetZ, C.WANDER_SPEED, dt) then
			brain.targetX, brain.targetZ = nil, nil
			brain.pause = pause(rand)
		end
	else
		brain.pause -= dt
		if brain.pause <= 0 then
			local angle = rand() * 2 * math.pi
			local radius = C.WANDER_RADIUS * math.sqrt(rand())
			brain.targetX, brain.targetZ = brain.cx + math.cos(angle) * radius, brain.cz + math.sin(angle) * radius
		end
	end
	return brain
end

return Wild
