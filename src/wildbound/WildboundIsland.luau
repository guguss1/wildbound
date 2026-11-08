-- Pure rules for the creature islands (docs/mechanics/wildbound-expedition-islands.md section 2, task I2).
-- One shared sleep meter ("inquietud", 0 to 100) per island: what raises it, its stir at 40 and wake at 100, the
-- Alerta window that closes the nest, the nest content roll, respawn, and island 1's first-steal cap. When the adults
-- wake (decision EI-2) they scream (the server's guardian noise) and one adult chases the thief: a short, leashed,
-- non-lethal chase; a touch only makes the thief drop the cria. Positions, time, phase and randomness are passed in;
-- nothing here reads the world. Every number is a hypothesis to tune in play.
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
	-- Once, from the capture session, the egg pickup, the hide spot and the sprint noise.
	PENALTY = table.freeze({ LeftRing = 25, Failed = 25, SealMissed = 35, EggTaken = 30, Rustle = 10, SprintNoise = 25 }),
	SPRINT_NOISE_REACH = 30, -- a sprint noise (DP-2) this close to the nest counts
	DECAY = 8,
	DECAY_EMPTY = 20,
	DECAY_DELAY = 2,
	ALERT_SECONDS = 30,
	ALERT_SECONDS_FIRST = 8, -- island 1 only shoos you
	RESET = 30,
	FIRST_CAP = 95,
	FIRST_SCALE = 0.5, -- island 1 halves every input
	-- EI-2: the woken adult's chase. Faster than a carrier (14), slower than a sprinting carrier (14 x 1.3 = 18.2).
	CHASE_SPEED = 16,
	CHASE_SECONDS = 7,
	CHASE_LEASH = 35,
	CATCH = 3.5,
	RETURN_SPEED = 8,
	DAMAGE = 0,
	-- Nests (as the old slots): respawn by kind, sooner on a crowded server; island 1 refills fast for the tutorial.
	RESPAWN_CREATURE = 45,
	RESPAWN_CREATURE_CROWDED = 30,
	RESPAWN_EGG = 60,
	RESPAWN_EGG_CROWDED = 40,
	RESPAWN_FIRST = 8,
	CROWDED_PLAYERS = 5,
	CREATURE_SHARE = 0.7,
})
local C = Island.CONSTANTS
local FIRST = "I1"
local HEART = "Heart"

local function finite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

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
function Island.event(meter, kind, options)
	local amount = type(meter) == "table" and type(kind) == "string" and C.PENALTY[kind] or nil
	if not amount then return { stirred = false, woke = false, settled = false } end
	meter.quiet = 0
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
	return { mode = "Chase", x = point.x, z = point.z, homeX = point.x, homeZ = point.z, nestX = island.x,
		nestZ = island.z, left = C.CHASE_SECONDS, fx = 0, fz = 1 }
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

-- One step. While chasing, runs at CHASE_SPEED toward (targetX, targetZ), never past CHASE_LEASH from the nest;
-- returns "Caught" on a touch or "GaveUp" when its time runs out, then walks home. Returns nil otherwise.
function Island.chaseStep(chase, dt, targetX, targetZ)
	if type(chase) ~= "table" or not finite(dt) or dt <= 0 then return nil end
	if chase.mode == "Return" then
		if moveToward(chase, chase.homeX, chase.homeZ, C.RETURN_SPEED * dt) then chase.mode = "Home" end
		return nil
	end
	if chase.mode ~= "Chase" then return nil end
	if finite(targetX) and finite(targetZ) then
		moveToward(chase, targetX, targetZ, C.CHASE_SPEED * dt)
		local ox, oz = chase.x - chase.nestX, chase.z - chase.nestZ
		local out = math.sqrt(ox * ox + oz * oz)
		if out > C.CHASE_LEASH then
			chase.x, chase.z = chase.nestX + ox / out * C.CHASE_LEASH, chase.nestZ + oz / out * C.CHASE_LEASH
		end
		if math.sqrt((targetX - chase.x) ^ 2 + (targetZ - chase.z) ^ 2) <= C.CATCH then
			chase.mode = "Return"
			return "Caught"
		end
	end
	chase.left -= dt
	if chase.left <= 1e-9 then
		chase.mode = "Return"
		return "GaveUp"
	end
	return nil
end

return Island
