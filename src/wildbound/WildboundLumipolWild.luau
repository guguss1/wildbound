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
	-- A still or slow player this close makes it stop and watch them.
	CURIOUS_RANGE = 12,
	ARRIVE = 0.05,
	FLEE_SPEED = 10,
	-- With no cover in reach, a flee backs away this far from the threat.
	FLEE_MIN = 8,
	FLEE_MAX = 12,
	-- A1: alarm drains this much per second while nobody is running near it.
	ALARM_DECAY = 0.5,
	-- An Alert lasts at least this long after the last fast move it saw.
	ALERT_HOLD = 1,
	-- Hidden this long, then peeking at the threat for PEEK_SECONDS, then calm again.
	HIDE_SECONDS = 4,
	PEEK_SECONDS = 2,
	-- Every position stays within LEASH studs of the slot centre (default; a brain may carry its own).
	LEASH = 24,
	-- Cover: a prop counts at most COVER_RADIUS_MAX wide; the hide spot is COVER_OFFSET past that, away from the threat.
	COVER_RADIUS_MAX = 3,
	COVER_OFFSET = 1.5,
	COVER_SPACING = 4,
	MAX_COVER = 8,
	-- A cover whose direction is within about 60 degrees of the threat's is never run to.
	TOWARD_THREAT = 0.5,
	CROWDED_PLAYERS = 5,
	WALK_SPEED = 16,
	-- Silueta's fastest speed is 8 (fog night), so a loaded carrier must stay above it.
	SILUETA_FASTEST = 8,
	-- Delivery B (B1): walk speed while a wild creature rides in the carry capsule. A slight cost (16 to 14) that
	-- never reaches Silueta's fastest; set it to WALK_SPEED to turn the cost off.
	CREATURE_CARRY_SPEED = 14,
})
local C = Wild.CONSTANTS

-- A1: how a Lumipol reads a nearby player. Speeds are horizontal studs per second, distances in studs, alarm in
-- seconds of running seen. A player above calmSpeed inside alertRadius builds alarm, twice as fast inside closeRadius.
-- Gentle is for the tutorial Safe slots. All hypotheses, see docs/mechanics/wildbound-capture.md (Delivery A).
local function profile(calmSpeed, alertRadius, closeRadius, alarmAlert, alarmFlee)
	return table.freeze({ calmSpeed = calmSpeed, alertRadius = alertRadius, closeRadius = closeRadius,
		alarmAlert = alarmAlert, alarmFlee = alarmFlee })
end
Wild.PROFILES = table.freeze({
	Wild = profile(8, 14, 7, 0.2, 0.8),
	Gentle = profile(12, 10, 5, 0.4, 1.2),
})

function Wild.profileFor(tier)
	return tier == "Safe" and Wild.PROFILES.Gentle or Wild.PROFILES.Wild
end

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
	-- B1: the creature now rides in the carry slot, not the bag.
	local carried = snapshot.carrying
	if type(carried) == "table" and carried.kind == "Creature" then return "FirstCapturePending" end
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

-- Walk speed by eggs in the bag and, from delivery B, a creature in the carry slot (`creature` true). The slower
-- of the two applies. Never at or below Silueta's fastest.
local function eggSpeed(eggs)
	if not finite(eggs) or eggs < 1 then return C.WALK_SPEED end
	if eggs < 2 then return 11 end
	if eggs < 3 then return 10 end
	return 9
end

function Wild.carrySpeed(eggs, creature)
	local speed = eggSpeed(eggs)
	if creature == true then speed = math.min(speed, C.CREATURE_CARRY_SPEED) end
	return speed
end

local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil, nil end
	return x / length, z / length
end

local function pause(rand)
	return C.PAUSE_MIN + rand() * (C.PAUSE_MAX - C.PAUSE_MIN)
end

local function radiusOf(value)
	if not finite(value) or value < 0 then return 0 end
	return math.min(value, C.COVER_RADIUS_MAX)
end

-- A1: cover from map props near a slot. candidates = list of { x, z, r } read by the server from the dressed map.
-- Keeps finite props whose centre is within the leash, nearest first, at least COVER_SPACING apart, MAX_COVER at most.
function Wild.coverPoints(entry, candidates, leash)
	local list = {}
	if type(entry) ~= "table" or not finite(entry.x) or not finite(entry.z) or type(candidates) ~= "table" then
		return list
	end
	local limit = finite(leash) and leash > 0 and leash or C.LEASH
	local found = {}
	for _, item in ipairs(candidates) do
		if type(item) == "table" and finite(item.x) and finite(item.z) then
			local distance = math.sqrt((item.x - entry.x) ^ 2 + (item.z - entry.z) ^ 2)
			if distance <= limit then table.insert(found, { x = item.x, z = item.z, r = radiusOf(item.r), d = distance }) end
		end
	end
	table.sort(found, function(a, b)
		if a.d ~= b.d then return a.d < b.d end
		if a.x ~= b.x then return a.x < b.x end
		return a.z < b.z
	end)
	for _, item in ipairs(found) do
		local spaced = true
		for _, kept in ipairs(list) do
			if math.sqrt((kept.x - item.x) ^ 2 + (kept.z - item.z) ^ 2) < C.COVER_SPACING then spaced = false; break end
		end
		if spaced then table.insert(list, table.freeze({ x = item.x, z = item.z, r = item.r })) end
		if #list >= C.MAX_COVER then break end
	end
	return list
end

-- options = { cover = list from coverPoints, leash = studs }. Both optional.
function Wild.newBrain(entry, rand, options)
	options = type(options) == "table" and options or {}
	local leash = finite(options.leash) and options.leash > 0 and options.leash or C.LEASH
	return { mode = "Idle", x = entry.x, z = entry.z, cx = entry.x, cz = entry.z, fx = 0, fz = -1,
		pause = pause(rand), moved = false, alarm = 0, alertFor = 0, hideFor = 0, peek = false,
		leash = leash, profile = Wild.profileFor(entry.tier), cover = Wild.coverPoints(entry, options.cover, leash),
		hideX = entry.x, hideZ = entry.z, coverIndex = nil, threatX = nil, threatZ = nil }
end

local function face(brain, x, z)
	local fx, fz = unit(x - brain.x, z - brain.z)
	if fx then brain.fx, brain.fz = fx, fz end
end

local function insideLeash(brain, x, z)
	return math.sqrt((x - brain.cx) ^ 2 + (z - brain.cz) ^ 2) <= brain.leash + 1e-9
end

-- Clamp a point onto the leash circle.
local function leashed(brain, x, z)
	local ox, oz = x - brain.cx, z - brain.cz
	local length = math.sqrt(ox * ox + oz * oz)
	if length <= brain.leash then return x, z end
	return brain.cx + ox / length * brain.leash, brain.cz + oz / length * brain.leash
end

-- Starts a flee from the threat at (x, z): to the nearest cover spot behind a prop, away from the threat and inside
-- the leash; otherwise straight back FLEE_MIN to FLEE_MAX studs, clamped to the leash.
local function startFlee(brain, x, z, rand)
	local tx = finite(x) and x or brain.x
	local tz = finite(z) and z or brain.z
	local ax, az = unit(tx - brain.x, tz - brain.z)
	local best, bestX, bestZ, bestD
	for index, cover in ipairs(brain.cover) do
		local ux, uz = unit(cover.x - tx, cover.z - tz)
		if ux then
			local hx, hz = cover.x + ux * (cover.r + C.COVER_OFFSET), cover.z + uz * (cover.r + C.COVER_OFFSET)
			local dx, dz = unit(cover.x - brain.x, cover.z - brain.z)
			local toward = ax ~= nil and dx ~= nil and dx * ax + dz * az > C.TOWARD_THREAT
			if not toward and insideLeash(brain, hx, hz) then
				local d = math.sqrt((hx - brain.x) ^ 2 + (hz - brain.z) ^ 2)
				if not bestD or d < bestD then best, bestX, bestZ, bestD = index, hx, hz, d end
			end
		end
	end
	if not best then
		local dx, dz = unit(brain.x - tx, brain.z - tz)
		if not dx then
			local angle = rand() * 2 * math.pi
			dx, dz = math.cos(angle), math.sin(angle)
		end
		local distance = C.FLEE_MIN + rand() * (C.FLEE_MAX - C.FLEE_MIN)
		bestX, bestZ = leashed(brain, brain.x + dx * distance, brain.z + dz * distance)
	end
	brain.mode, brain.moved, brain.alarm, brain.alertFor = "Flee", false, 0, 0
	brain.hideX, brain.hideZ, brain.coverIndex = bestX, bestZ, best
	brain.hideFor, brain.peek, brain.threatX, brain.threatZ = 0, false, tx, tz
	brain.targetX, brain.targetZ = nil, nil
	face(brain, bestX, bestZ)
end

-- A capture began: frozen, listening, turned toward its owner.
function Wild.reserve(brain, x, z)
	if brain.mode == "Captured" then return end
	brain.mode, brain.moved, brain.peek = "Reserved", false, false
	if finite(x) and finite(z) then face(brain, x, z) end
end

-- The capture failed or a seal was missed: flee from the threat, then hide.
function Wild.spook(brain, x, z, rand)
	if brain.mode == "Captured" then return end
	startFlee(brain, x, z, rand)
end

-- The capture ended without a flee (the owner left, a server fault): calm again where it stands.
function Wild.release(brain)
	if brain.mode == "Captured" then return end
	brain.mode, brain.moved, brain.alarm, brain.alertFor, brain.peek = "Idle", false, 0, 0, false
	brain.pause, brain.targetX, brain.targetZ = 1, nil, nil
end

-- The seal hit: frozen for good until the server removes it.
function Wild.capture(brain)
	brain.mode, brain.moved, brain.peek = "Captured", false, false
	brain.targetX, brain.targetZ = nil, nil
end

-- True while it is too scared to be calmed: Alert, Flee, or Hide before it peeks. Fails closed without a brain.
function Wild.wary(brain)
	if type(brain) ~= "table" then return true end
	local mode = brain.mode
	return mode == "Alert" or mode == "Flee" or (mode == "Hide" and brain.peek ~= true)
end

local function approach(brain, tx, tz, speed, dt)
	local dx, dz = tx - brain.x, tz - brain.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length <= C.ARRIVE then return true end
	local move = math.min(length, speed * dt)
	if move >= length - 1e-9 then
		brain.x, brain.z = tx, tz
	else
		brain.x, brain.z = brain.x + dx / length * move, brain.z + dz / length * move
	end
	brain.fx, brain.fz = dx / length, dz / length
	brain.moved = true
	return move >= length - 1e-9
end

local function reading(near)
	if type(near) ~= "table" or not finite(near.x) or not finite(near.z) then return nil end
	local speed = near.speed
	if not finite(speed) or speed < 0 then speed = 0 end
	return near.x, near.z, speed
end

local function wander(brain, dt, rand)
	if brain.targetX then
		brain.mode = "Wander"
		if approach(brain, brain.targetX, brain.targetZ, C.WANDER_SPEED, dt) then
			brain.targetX, brain.targetZ = nil, nil
			brain.pause = pause(rand)
		end
		return
	end
	brain.mode = "Idle"
	brain.pause -= dt
	if brain.pause <= 0 then
		local angle = rand() * 2 * math.pi
		local radius = C.WANDER_RADIUS * math.sqrt(rand())
		brain.targetX, brain.targetZ = brain.cx + math.cos(angle) * radius, brain.cz + math.sin(angle) * radius
	end
end

-- One fixed step. near = { x, z, speed } of the nearest live player, or nil. rand() returns a number in [0, 1).
function Wild.step(brain, dt, near, rand)
	brain.moved = false
	if not finite(dt) or dt <= 0 then return brain end
	dt = math.min(dt, 0.5)
	local mode = brain.mode
	if mode == "Captured" then return brain end
	local px, pz, speed = reading(near)
	if mode == "Reserved" then
		if px then face(brain, px, pz) end
		return brain
	end
	local p = brain.profile
	local distance = px and math.sqrt((px - brain.x) ^ 2 + (pz - brain.z) ^ 2) or math.huge
	local fast = px ~= nil and distance <= p.alertRadius and speed > p.calmSpeed
	if mode == "Flee" then
		if approach(brain, brain.hideX, brain.hideZ, C.FLEE_SPEED, dt) then
			brain.mode, brain.hideFor, brain.peek = "Hide", 0, false
		end
		return brain
	end
	if mode == "Hide" then
		if px then brain.threatX, brain.threatZ = px, pz end
		if fast then
			brain.hideFor, brain.peek = 0, false
			return brain
		end
		brain.hideFor += dt
		if brain.hideFor + 1e-9 >= C.HIDE_SECONDS + C.PEEK_SECONDS then
			brain.mode, brain.peek, brain.alarm, brain.hideFor = "Idle", false, 0, 0
			brain.pause, brain.targetX, brain.targetZ = pause(rand), nil, nil
			return brain
		end
		brain.peek = brain.hideFor + 1e-9 >= C.HIDE_SECONDS
		if brain.peek and brain.threatX then face(brain, brain.threatX, brain.threatZ) end
		return brain
	end
	-- Idle, Wander, Curious and Alert all listen for running.
	if fast then
		brain.alarm += dt * (distance <= p.closeRadius and 2 or 1)
		brain.alertFor = 0
	else
		brain.alarm = math.max(0, brain.alarm - C.ALARM_DECAY * dt)
		if mode == "Alert" then brain.alertFor += dt end
	end
	if brain.alarm + 1e-9 >= p.alarmFlee then
		startFlee(brain, px, pz, rand)
		return brain
	end
	local alerted = brain.alarm + 1e-9 >= p.alarmAlert
		or (mode == "Alert" and brain.alertFor + 1e-9 < C.ALERT_HOLD)
	if alerted then
		if mode ~= "Alert" then brain.alertFor = 0 end
		brain.mode, brain.targetX, brain.targetZ = "Alert", nil, nil
		if px then face(brain, px, pz) end
		return brain
	end
	if px and distance <= C.CURIOUS_RANGE then
		brain.mode = "Curious"
		face(brain, px, pz)
		return brain
	end
	if mode == "Curious" or mode == "Alert" then
		brain.mode, brain.pause, brain.targetX, brain.targetZ = "Idle", 1, nil, nil
	end
	wander(brain, dt, rand)
	return brain
end

return Wild
