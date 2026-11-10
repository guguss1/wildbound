-- Pure rules for the creature islands (docs/mechanics/wildbound-expedition-islands.md section 2, task I2).
-- One shared sleep meter ("inquietud", 0 to 100) per island: what raises it, its stir at 40 and wake at 100, the
-- Alerta window that closes the nest, the nest content roll, respawn, and island 1's first-steal cap. When the adults
-- wake (decision EI-2) they scream (the server's guardian noise) and one adult chases the thief, leashed to its island.
-- Chase pass (CP-D5, user: "the parents can kill you"): the adult stands up for a short wind-up, and a reach starts a
-- readable strike; a landed strike drops the cria and, behind the damage gates, hurts (three hits kill). Positions,
-- time, phase and randomness are passed in; nothing here reads the world. Every number is a hypothesis to tune in play.
local Island = {}

Island.CONSTANTS = table.freeze({
	STIR = 40,
	WAKE = 100,
	-- Per second, inside the wake radius.
	LINGER = 6, -- walking within LINGER_RANGE of a sleeping adult
	LINGER_RANGE = 6,
	SPRINT = 45,
	LIGHT = 10, -- the light on a sleeping face at Dusk or Night
	LIGHT_FAROL = 5, -- with the "Farol tapado" upgrade
	LIGHT_RANGE = 12,
	LIGHT_DOT = 0.85,
	LULL = 3,
	-- Once, from the capture session, the hide spot and the sprint noise.
	-- Fix pass (FP4d): La Silueta's chase-start scream wakes a sleeping island at once (island 1 halves it: it stirs).
	PENALTY = table.freeze({ LeftRing = 25, Failed = 25, SealMissed = 35, Rustle = 10, SprintNoise = 25,
		SiluetaScream = 100 }),
	-- Fear pass (FA2, user: "stealing must be an adrenaline rush"): the grab itself is loud. A granted cria capture
	-- ("CriaTaken") or an egg pickup ("EggTaken", was 30) adds GRAB once: a careful thief on a calm island keeps it
	-- asleep (63 after 3 s by an adult), a sloppy one wakes the parents the moment the cria is lifted.
	GRAB = 45,
	SPRINT_NOISE_REACH = 30, -- a sprint noise (DP-2) this close to the nest counts
	DECAY = 8,
	DECAY_EMPTY = 20,
	DECAY_DELAY = 2,
	ALERT_SECONDS = 30,
	ALERT_SECONDS_FIRST = 8, -- island 1 only shoos you
	RESET = 30,
	FIRST_CAP = 95,
	FIRST_SCALE = 0.5, -- island 1 halves every input
	-- EI-2, chase pass (CP-D5): the woken adult's chase. It stands up for WAKE_WINDUP (IW-4: it used to catch a thief
	-- beside it in about 0.3 s), then runs faster than a walker (16) and slower than a sprinting carrier (14 x 1.45 =
	-- 20.3). Within STRIKE_REACH it stands still and swings for STRIKE_WINDUP (above the 0.35 s floor of a readable
	-- tell); the swing lands if the thief is still within HIT_RANGE. DAMAGE 35: three hits kill (100, 65, 30, 0).
	-- Fear pass (FA2, user: "faster"): up in 0.4 s (was 0.6), 19 studs/s (was 17), for 14 s (was 10). A walking
	-- carrier (14) or walker (16) is caught; only a sprint (which scares a carried cria) outruns it, by 1.3 studs/s.
	WAKE_WINDUP = 0.4,
	CHASE_SPEED = 19,
	CHASE_SECONDS = 14,
	CHASE_LEASH = 35,
	STRIKE_REACH = 3.5,
	STRIKE_WINDUP = 0.45,
	HIT_RANGE = 5,
	STRIKE_COOLDOWN = 1.2,
	RETURN_SPEED = 8,
	DAMAGE = 35,
	-- Nests (as the old slots): respawn by kind, sooner on a crowded server; island 1 refills fast for the tutorial.
	RESPAWN_CREATURE = 45,
	RESPAWN_CREATURE_CROWDED = 30,
	RESPAWN_EGG = 60,
	RESPAWN_EGG_CROWDED = 40,
	RESPAWN_FIRST = 8,
	CROWDED_PLAYERS = 5,
	CREATURE_SHARE = 0.7,
	-- Fix pass (FP5, parents; each toggle is 1 on, 0 off). (a) Pack call: the island's adults share one meter, so when
	-- one wakes the pack wakes with it, after PACK_CALL_SECONDS (0: at once; the plan allows up to 10 s).
	PACK_CALL_SECONDS = 0,
	-- (b) Charge (Nest Heist NH3, was the FP5b pounce): a thief within POUNCE_RANGE (but outside STRIKE_REACH) after
	-- POUNCE_AFTER s of chase gets a POUNCE_TELL s tell (the adult rears and stands still; never under 0.8 s, the
	-- fair-strike warning lead), then a straight charge at CHARGE_SPEED along the line to where the thief stood when the
	-- tell ended, CHARGE_OVERSHOOT past that point (at most CHARGE_MAX, never past the leash). Touching the thief
	-- (CHARGE_HIT) lands a hit; a miss leaves the adult EXPOSED_SECONDS still, then it chases again. POUNCE_COOLDOWN
	-- between charges.
	POUNCE_ON = 1,
	POUNCE_RANGE = 12,
	POUNCE_AFTER = 1,
	POUNCE_TELL = 0.8,
	POUNCE_COOLDOWN = 6,
	CHARGE_SPEED = 40,
	CHARGE_OVERSHOOT = 4,
	CHARGE_MAX = 18,
	CHARGE_HIT = 3,
	EXPOSED_SECONDS = 1,
	-- Nest Heist (NH3): stealing an egg wakes the island at once (1), with no meter to fill; 0 restores the grab noise.
	STEAL_WAKE = 1,
	-- Nest Heist (NH5): a chasing adult turns on a new egg carrier only if that player is within PERCEIVE_RANGE of it.
	PERCEIVE_RANGE = 24,
	-- (c) Egg recovery: an egg dropped inside the leash is fetched and carried to the nest at RETURN_SPEED.
	EGG_RECOVERY_ON = 1,
	-- (d) Sleep cycle: from DEEP_FROM to DEEP_TO o'clock of the day cycle every wake input is scaled by DEEP_SCALE.
	DEEP_SLEEP_ON = 1,
	DEEP_SCALE = 0.7,
	DEEP_FROM = 11,
	DEEP_TO = 13,
})
local POUNCE_TELL_FLOOR = 0.8 -- NH3: the charge's tell never under the fair-strike warning lead
local FIRST = "I1"
local HEART = "Heart"

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

-- Dev tuning (docs/testing/wildbound-tuning.md): CONSTANTS stay the defaults the tests pin; the rules and the server
-- read `live`, a copy the server's tuning bridge may override at runtime. No override, no change.
local C = {}
Island.live = C

function Island.tunable()
	local defaults = {}
	for key, value in pairs(Island.CONSTANTS) do
		if type(value) == "number" then defaults[key] = value end
	end
	return defaults
end

-- overrides: { [constant] = number }. Unknown keys and non-finite values are ignored; nil restores the defaults.
function Island.tune(overrides)
	for key, value in pairs(Island.CONSTANTS) do C[key] = value end
	if type(overrides) == "table" then
		for key, value in pairs(overrides) do
			if type(Island.CONSTANTS[key]) == "number" and finite(value) then C[key] = value end
		end
	end
	C.POUNCE_TELL = math.max(C.POUNCE_TELL, POUNCE_TELL_FLOOR)
end
Island.tune(nil)

local function dark(phase)
	return phase == "Dusk" or phase == "Night"
end

function Island.wakeRadius(island, phase)
	if type(island) ~= "table" then return 0 end
	return dark(phase) and island.wakeNight or island.wakeDay
end

function Island.newMeter(island)
	return { island = island and island.id, first = island ~= nil and island.id == FIRST, value = 0, state = "Asleep",
		stirred = false, quiet = 0, alertFor = 0 }
end

function Island.nestOpen(meter)
	return type(meter) == "table" and meter.state == "Asleep"
end

-- Adds `amount` and reports crossings. capped: island 1's first-steal ceiling applies.
local function raise(meter, amount, capped)
	local out = { stirred = false, woke = false, settled = false }
	if meter.state ~= "Asleep" or not finite(amount) or amount <= 0 then return out end
	if meter.first then amount *= C.FIRST_SCALE end
	-- Fix pass (FP5d): the deep noon sleep scales every wake input.
	if finite(meter.sleepScale) then amount *= meter.sleepScale end
	local value = meter.value + amount
	if capped then value = math.min(value, math.max(meter.value, C.FIRST_CAP)) end
	meter.value = value
	if not meter.stirred and value >= C.STIR then
		meter.stirred, out.stirred = true, true
	end
	if value >= C.WAKE then
		meter.state, meter.alertFor, out.woke = "Alert", 0, true
	end
	return out
end

-- A one-off input. options.firstSteal: a player on their first steal is the cause (island 1 caps at 95).
local GRABS = { CriaTaken = true, EggTaken = true }
function Island.event(meter, kind, options)
	local amount = type(meter) == "table" and type(kind) == "string" and (GRABS[kind] and C.GRAB or C.PENALTY[kind]) or nil
	if not amount then return { stirred = false, woke = false, settled = false } end
	meter.quiet = 0
	-- Nest Heist (NH3): an egg steal is seen at once; the parents wake with no meter to fill (never island 1's cria).
	if kind == "EggTaken" and C.STEAL_WAKE >= 0.5 and meter.state == "Asleep" then
		local stirred = not meter.stirred
		meter.value, meter.stirred = math.max(meter.value, C.WAKE), true
		meter.state, meter.alertFor = "Alert", 0
		return { stirred = stirred, woke = true, settled = false }
	end
	local capped = meter.first and type(options) == "table" and options.firstSteal == true
	return raise(meter, amount, capped)
end

-- One step. input = { inside, linger, sprint, light, farol, lulling, phase, firstSteal }, all read by the server.
function Island.step(meter, dt, input)
	local out = { stirred = false, woke = false, settled = false }
	if type(meter) ~= "table" or not finite(dt) or dt <= 0 or type(input) ~= "table" then return out end
	if meter.state == "Alert" then
		meter.alertFor += dt
		local window = meter.first and C.ALERT_SECONDS_FIRST or C.ALERT_SECONDS
		if meter.alertFor + 1e-9 >= window then
			meter.state, meter.value, meter.stirred, meter.quiet = "Asleep", C.RESET, false, 0
			out.settled = true
		end
		return out
	end
	local rate = 0
	if input.inside == true then
		if input.linger == true then rate += C.LINGER end
		if input.sprint == true then rate += C.SPRINT end
		if input.light == true and dark(input.phase) then rate += input.farol == true and C.LIGHT_FAROL or C.LIGHT end
		if input.lulling == true then rate += C.LULL end
	end
	if rate > 0 then
		meter.quiet = 0
		local capped = meter.first and input.firstSteal == true and input.sprint ~= true
		return raise(meter, rate * dt, capped)
	end
	if input.inside ~= true then
		meter.value = math.max(0, meter.value - C.DECAY_EMPTY * dt)
	elseif meter.quiet + 1e-9 >= C.DECAY_DELAY then
		meter.value = math.max(0, meter.value - C.DECAY * dt)
	end
	meter.quiet += dt
	if meter.value < C.STIR then meter.stirred = false end
	return out
end

-- Fix pass (FP5d): how deeply the adults sleep at this hour of the day cycle (clockTime 0 to 24): DEEP_SCALE from
-- DEEP_FROM to DEEP_TO, else 1. setSleep stores it on the meter (every wake input reads it) with meter.deep.
function Island.sleepScale(clockTime)
	if C.DEEP_SLEEP_ON < 0.5 or not finite(clockTime) then return 1 end
	return (clockTime >= C.DEEP_FROM and clockTime < C.DEEP_TO) and C.DEEP_SCALE or 1
end

function Island.setSleep(meter, clockTime)
	if type(meter) ~= "table" then return end
	local scale = Island.sleepScale(clockTime)
	meter.sleepScale, meter.deep = scale, scale < 1
end

-- The nest's next content: island 1 always a cria; island 5 a cria only at Dusk and Night; otherwise 70 % cria.
function Island.rollContent(island, phase, rand)
	if type(island) ~= "table" or type(rand) ~= "function" then return nil end
	if island.id == FIRST then return "Creature" end
	if island.rewardTier == HEART and not dark(phase) then return "Egg" end
	local roll = rand()
	if not finite(roll) then return nil end
	return roll < C.CREATURE_SHARE and "Creature" or "Egg"
end

function Island.respawnSeconds(island, kind, players)
	if type(island) ~= "table" then return nil end
	if island.id == FIRST then return C.RESPAWN_FIRST end
	local crowded = finite(players) and players >= C.CROWDED_PLAYERS
	if kind == "Egg" then return crowded and C.RESPAWN_EGG_CROWDED or C.RESPAWN_EGG end
	return crowded and C.RESPAWN_CREATURE_CROWDED or C.RESPAWN_CREATURE
end

-- Islands 3 to 5 hold a second nest with three or more players.
function Island.nestCount(island, players)
	if type(island) ~= "table" then return 0 end
	local deep = island.id == "I3" or island.id == "I4" or island.id == "I5"
	return deep and finite(players) and players >= 3 and 2 or 1
end

-- EI-2: who the woken adult chases. candidates = list of { key, x, z, carrying = island id of a carried cria }.
-- A thief carrying this island's cria comes first; otherwise the nearest intruder. Only inside the leash.
function Island.chaseTarget(island, candidates)
	if type(island) ~= "table" or type(candidates) ~= "table" then return nil end
	local thief, thiefD, nearest, nearestD = nil, math.huge, nil, math.huge
	for _, item in ipairs(candidates) do
		if type(item) == "table" and finite(item.x) and finite(item.z) then
			local d = math.sqrt((item.x - island.x) ^ 2 + (item.z - island.z) ^ 2)
			if d <= C.CHASE_LEASH then
				if item.carrying == island.id and d < thiefD then thief, thiefD = item.key, d end
				if d < nearestD then nearest, nearestD = item.key, d end
			end
		end
	end
	return thief or nearest
end

function Island.newChase(island, point)
	if type(island) ~= "table" or type(point) ~= "table" or not finite(point.x) or not finite(point.z) then return nil end
	return { mode = "Wake", wake = C.WAKE_WINDUP, x = point.x, z = point.z, homeX = point.x, homeZ = point.z,
		nestX = island.x, nestZ = island.z, left = C.CHASE_SECONDS, fx = 0, fz = 1, swing = 0, cooldown = 0,
		chased = 0, pounce = 0, pounceCooldown = 0, charge = 0, exposed = 0 }
end

local function moveToward(chase, tx, tz, distance)
	local dx, dz = tx - chase.x, tz - chase.z
	local length = math.sqrt(dx * dx + dz * dz)
	if length < 1e-9 then return true end
	chase.fx, chase.fz = dx / length, dz / length
	if distance >= length then
		chase.x, chase.z = tx, tz
		return true
	end
	chase.x, chase.z = chase.x + dx / length * distance, chase.z + dz / length * distance
	return false
end

-- One step. "Wake": stands up for WAKE_WINDUP, still. "Chase": runs at CHASE_SPEED toward (targetX, targetZ), never past
-- CHASE_LEASH from the nest, and within STRIKE_REACH (cooldown over) starts a swing: returns "WindUp". "Strike": stands
-- still; after STRIKE_WINDUP returns "Hit" if the target is within HIT_RANGE, else "Missed", and chases again after
-- STRIKE_COOLDOWN. Returns "GaveUp" when its time runs out (the wind-up does not count), then walks home.
-- NH3: "Pounce" is the charge's tell (returns "PounceWindUp" when it starts and "Charge" when the dash starts);
-- "Charge" dashes and returns "Hit" on contact or "ChargeMissed" at its end; "Exposed" stands still, then "Chase".
local function distanceTo(chase, x, z)
	return math.sqrt((x - chase.x) ^ 2 + (z - chase.z) ^ 2)
end

-- The distance from (px, pz) to the segment (ax, az)-(bx, bz): a fast dash cannot pass through a thief between steps.
local function segmentDistance(ax, az, bx, bz, px, pz)
	local dx, dz = bx - ax, bz - az
	local length2 = dx * dx + dz * dz
	local t = length2 > 1e-12 and math.clamp(((px - ax) * dx + (pz - az) * dz) / length2, 0, 1) or 0
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end

local function leash(chase)
	local ox, oz = chase.x - chase.nestX, chase.z - chase.nestZ
	local out = math.sqrt(ox * ox + oz * oz)
	if out > C.CHASE_LEASH then
		chase.x, chase.z = chase.nestX + ox / out * C.CHASE_LEASH, chase.nestZ + oz / out * C.CHASE_LEASH
		return true
	end
	return false
end

function Island.chaseStep(chase, dt, targetX, targetZ)
	if type(chase) ~= "table" or not finite(dt) or dt <= 0 then return nil end
	if chase.mode == "Return" then
		if moveToward(chase, chase.homeX, chase.homeZ, C.RETURN_SPEED * dt) then chase.mode = "Home" end
		return nil
	end
	if chase.mode == "Wake" then
		chase.wake -= dt
		if chase.wake > 1e-9 then return nil end
		chase.mode = "Chase"
		return nil
	end
	if chase.mode ~= "Chase" and chase.mode ~= "Strike" and chase.mode ~= "Pounce" and chase.mode ~= "Charge"
		and chase.mode ~= "Exposed" then return nil end
	local seen = finite(targetX) and finite(targetZ)
	local event = nil
	chase.pounceCooldown = math.max(0, (chase.pounceCooldown or 0) - dt)
	if chase.mode == "Pounce" then
		-- NH3: stands still for the tell, facing the thief; then the dash's line is locked on where the thief is now.
		chase.pounce -= dt
		if seen then moveToward(chase, targetX, targetZ, 0) end
		if chase.pounce <= 1e-9 then
			local gap = seen and distanceTo(chase, targetX, targetZ) or 0
			chase.mode, chase.pounceCooldown = "Charge", C.POUNCE_COOLDOWN
			chase.charge = math.min(gap + C.CHARGE_OVERSHOOT, C.CHARGE_MAX)
			event = "Charge"
		end
	elseif chase.mode == "Charge" then
		local fromX, fromZ = chase.x, chase.z
		local step = math.min(C.CHARGE_SPEED * dt, chase.charge)
		chase.x, chase.z = chase.x + chase.fx * step, chase.z + chase.fz * step
		chase.charge -= step
		local stopped = leash(chase)
		if seen and segmentDistance(fromX, fromZ, chase.x, chase.z, targetX, targetZ) <= C.CHARGE_HIT then
			chase.mode, chase.charge, chase.cooldown = "Chase", 0, C.STRIKE_COOLDOWN
			event = "Hit"
		elseif stopped or chase.charge <= 1e-9 then
			chase.mode, chase.charge, chase.exposed = "Exposed", 0, C.EXPOSED_SECONDS
			event = "ChargeMissed"
		end
	elseif chase.mode == "Exposed" then
		-- NH3: the miss's opening; it neither turns nor strikes until it recovers.
		chase.exposed -= dt
		if chase.exposed <= 1e-9 then chase.mode = "Chase" end
	elseif chase.mode == "Strike" then
		chase.swing -= dt
		if seen then moveToward(chase, targetX, targetZ, 0) end
		if chase.swing <= 1e-9 then
			chase.mode, chase.cooldown = "Chase", C.STRIKE_COOLDOWN
			event = seen and distanceTo(chase, targetX, targetZ) <= C.HIT_RANGE and "Hit" or "Missed"
		end
	else
		chase.cooldown = math.max(0, chase.cooldown - dt)
		chase.chased = (chase.chased or 0) + dt
		local gap = seen and distanceTo(chase, targetX, targetZ) or math.huge
		if seen and C.POUNCE_ON >= 0.5 and chase.chased + 1e-9 >= C.POUNCE_AFTER and chase.pounceCooldown <= 1e-9
			and gap <= C.POUNCE_RANGE and gap > C.STRIKE_REACH then
			-- NH3: the charge's tell; it faces the thief and stands still.
			moveToward(chase, targetX, targetZ, 0)
			chase.mode, chase.pounce = "Pounce", C.POUNCE_TELL
			event = "PounceWindUp"
		elseif seen then
			moveToward(chase, targetX, targetZ, C.CHASE_SPEED * dt)
			leash(chase)
			if chase.cooldown <= 1e-9 and distanceTo(chase, targetX, targetZ) <= C.STRIKE_REACH then
				chase.mode, chase.swing = "Strike", C.STRIKE_WINDUP
				event = "WindUp"
			end
		end
	end
	chase.left -= dt
	if chase.left <= 1e-9 and event ~= "Hit" then
		chase.mode = "Return"
		return "GaveUp"
	end
	return event
end

-- Nest Heist (NH5): whether a chasing adult can perceive a player at (x, z) (no omniscience): it is chasing, not walking
-- home, and the player is within PERCEIVE_RANGE of it.
function Island.perceives(chase, x, z)
	if type(chase) ~= "table" or not finite(x) or not finite(z) then return false end
	if chase.mode == "Return" or chase.mode == "Home" then return false end
	return distanceTo(chase, x, z) <= C.PERCEIVE_RANGE
end

-- Fix pass (FP5c): which dropped egg an island goes to fetch. drops = list of { key, kind, x, z }: the nearest "Egg"
-- within CHASE_LEASH of the nest, or nil.
function Island.recoverTarget(island, drops)
	if C.EGG_RECOVERY_ON < 0.5 or type(island) ~= "table" or type(drops) ~= "table" then return nil end
	local best, bestD = nil, math.huge
	for _, drop in ipairs(drops) do
		if type(drop) == "table" and drop.kind == "Egg" and finite(drop.x) and finite(drop.z) then
			local d = math.sqrt((drop.x - island.x) ^ 2 + (drop.z - island.z) ^ 2)
			if d <= C.CHASE_LEASH and d < bestD then best, bestD = drop, d end
		end
	end
	return best
end

-- An adult walks from its point to the egg ("Fetch"), picks it up (event "Picked"), walks it to the nest ("Carry") and
-- arrives (event "Home"), at RETURN_SPEED throughout.
function Island.newCarry(island, point, drop)
	if type(island) ~= "table" or type(point) ~= "table" or type(drop) ~= "table" then return nil end
	return { mode = "Fetch", x = point.x, z = point.z, fx = 0, fz = 1, eggX = drop.x, eggZ = drop.z,
		nestX = island.x, nestZ = island.z, key = drop.key }
end

function Island.carryStep(carry, dt)
	if type(carry) ~= "table" or not finite(dt) or dt <= 0 then return nil end
	if carry.mode == "Fetch" then
		if moveToward(carry, carry.eggX, carry.eggZ, C.RETURN_SPEED * dt) then
			carry.mode = "Carry"
			return "Picked"
		end
	elseif carry.mode == "Carry" then
		if moveToward(carry, carry.nestX, carry.nestZ, C.RETURN_SPEED * dt) then
			carry.mode = "Home"
			return "Home"
		end
	end
	return nil
end

-- Chase pass (CP-D5): what one landed adult strike does. input = { carrying = this island's cria is carried,
-- lethal = past the first paid trip (WildboundFairStrike.lethal), damageMode = the effective mode }. Damage only in the
-- private damage mode and for a lethal player, the same gates as La Silueta; the cria always drops.
function Island.hitEffect(input)
	if type(input) ~= "table" then return { drop = false, damage = 0 } end
	local hurts = input.damageMode == "private" and input.lethal == true
	return { drop = input.carrying == true, damage = hurts and C.DAMAGE or 0 }
end

return Island
