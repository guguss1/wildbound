-- Caramelo biome (odd/tasks/wildbound-candy-critters.md, CC2-CC3): one data-driven brain for the five small candy
-- creatures (Mochimiau, Canelin, Flanin, Mielita, GatoRepartidor). Server only and pure, stepped by
-- WildboundBeastEncounters through Enc.register (one module, five names: it reads Config.BEASTS[e.beast]). Built on
-- WildboundBeastAttack the way WildboundBeastGomibu is. Each one is summoned at its fixed post (Director.summon, points
-- 0) and lives there; e.pos is the ground under it (Mielita: HoverStuds over it). State machine:
--   Patrol (wanders between points within PatrolRadiusStuds of home, pausing at each; a calm phase for the portal)
--   -> Notice (AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (ChaseSpeed, never past LeashStuds from home)
--   -> Telegraph (one attack within Attack.RangeStuds; tell never under Config.MIN_TELL, and the shape is locked at
--      least MIN_TELL before the strike) -> Release (Attack.TravelSeconds: the hop, roll, wave or throw; the strike
--      is its end) -> Recover (Attack.RecoverSeconds) -> Chase ...
--   -> GiveUp: the target past AbandonStuds, or the creature held at its leash with the target out of attack range
--      for GiveUpSeconds. Like Gomibu it ends the encounter (Disengage "GiveUp" for GiveUpSeconds, then End), so an
--      idle critter never holds one of the director's MAX_ACTIVE slots; the next summon starts again at home in Patrol.
--   Escape: the target outside EscapeDistance of home for EscapeSeconds. Death and the safe zone end it (Attack.guard).
-- Attack kinds (tuning.Attack.kind):
--   leap  a circle of RadiusStuds on the target that follows it until LockSeconds; the creature hops there.
--   dash  a lane LengthStuds x WidthStuds forward from the creature, aimed until LockSeconds; it rolls along it.
--   burst a circle of RadiusStuds on the creature, locked at once; it stays put.
--   lob   a circle of RadiusStuds on the target that follows it until LockSeconds; the creature stays put.
-- Threat: damage 0. A hit carries a slow (SlowMultiplier, SlowSeconds) and, when PushStuds > 0, a push away from the
-- shape (event.push, applied by the server); the egg stays (keepsEgg: the beast script skips BeastHit). After a strike
-- it opens no other attack for CooldownSeconds (counted from the strike, the recovery included).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Critter = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy
local GOLDEN = math.pi * (3 - math.sqrt(5)) -- the patrol's next heading: spread round home without a random source
local LEASH_EDGE = 0.05 -- studs: this close to LeashStuds from home counts as held at the leash

function Critter.tellSeconds(A)
	return math.max(A.TelegraphSeconds, Config.MIN_TELL)
end

local function hover(e, T)
	return e.hover and (T.HoverStuds or 0) or 0
end

-- The ground under (x, z) plus the hover height.
local function settle(e, world, T, x, z)
	local h = hover(e, T)
	e.pos.x, e.pos.z = x, z
	e.pos.y = Attack.groundAt(world, x, z, e.pos.y - h) + h
end

function Critter.init(e)
	local C = Config.BEASTS[e.beast]
	e.hover = C and C.grounded ~= true or false
	e.home = copy(e.pos)
	if e.hover then e.pos.y += C.tuning.HoverStuds or 0 end
	e.readyAt = -math.huge
	e.patrolIndex = 0
end

function Critter.sees(e, target, T)
	return Attack.distance(e, target) <= T.PerceptionStuds
end

-- Clamps a point to the leash round home.
local function leashed(e, T, x, z)
	local d = flat(x, z, e.home.x, e.home.z)
	if d > T.LeashStuds then
		local ux, uz = unit(x - e.home.x, z - e.home.z)
		return e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
	return x, z
end

-- Moves toward (x, z) at speed for dt; returns true on arrival.
local function walkTo(e, world, T, x, z, speed, dt)
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance <= 1e-3 then return true end
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	local step = math.min(speed * dt, distance)
	settle(e, world, T, e.pos.x + dx * step, e.pos.z + dz * step)
	e.dx, e.dz = dx, dz
	return step >= distance - 1e-6
end

-- Where a target circle goes: on the target, or RangeStuds away from the creature in its direction; never past the
-- leash for a leap (the creature lands there).
local function aimPoint(e, target, T, A)
	local x, z = target.x, target.z
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance > A.RangeStuds then
		local ux, uz = unit(x - e.pos.x, z - e.pos.z)
		x, z = e.pos.x + ux * A.RangeStuds, e.pos.z + uz * A.RangeStuds
	end
	if A.kind == "leap" then x, z = leashed(e, T, x, z) end
	return x, z
end

-- The longest roll along (dx, dz) from the creature that stays inside the leash (at most LengthStuds).
local function laneLength(e, T, A, dx, dz)
	local ox, oz = e.pos.x - e.home.x, e.pos.z - e.home.z
	local b = ox * dx + oz * dz
	local c = ox * ox + oz * oz - T.LeashStuds * T.LeashStuds
	local reach = -b + math.sqrt(math.max(b * b - c, 0))
	return math.clamp(reach, 0, A.LengthStuds)
end

local function shapeFor(e, target, world, T, A)
	if A.kind == "dash" then
		local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
		if not dx then dx, dz = e.dx, e.dz end
		return { kind = "lane", ox = e.pos.x, oy = e.pos.y - hover(e, T), oz = e.pos.z, dx = dx, dz = dz,
			length = laneLength(e, T, A, dx, dz), width = A.WidthStuds }
	end
	if A.kind == "burst" then
		return { kind = "circle", x = e.pos.x, y = e.pos.y - hover(e, T), z = e.pos.z, r = A.RadiusStuds }
	end
	local x, z = aimPoint(e, target, T, A)
	return { kind = "circle", x = x, y = Attack.groundAt(world, x, z, target.y - 3), z = z, r = A.RadiusStuds }
end

local function closeAttack(e, world)
	Attack.closeAll(e, world)
	e.attack = nil
end

local function retreat(events, e, world, now, reason, seconds)
	closeAttack(e, world)
	Attack.disengage(events, e, reason, now, seconds)
end

local function openAttack(events, e, now, target, world, C, T, A)
	local shape = shapeFor(e, target, world, T, A)
	if shape.kind == "lane" and shape.length < 2 then return false end -- at the end of its leash: no room to roll
	local release = now + Critter.tellSeconds(A)
	local lockAt = A.kind == "burst" and now or now + A.LockSeconds
	local attack = Attack.open(events, e, world, { key = A.kind, startAt = now, strikeAt = release + A.TravelSeconds,
		dodgeable = false, damage = C.damage, lockAt = lockAt, shape = shape })
	if not attack then return false end
	e.attack, e.releaseAt, e.lockAt = attack, release, lockAt
	if A.kind == "burst" then Attack.lock(events, e, attack, nil, now) end
	Attack.face(e, target)
	Attack.phase(events, e, "Telegraph", now, release)
	return true
end

local function strike(events, e, target, world, C, T, A)
	local attack = e.attack
	local at = attack.strikeAt
	local shape = attack.shape
	local floor = shape.kind == "lane" and shape.oy or shape.y
	if Attack.inside(shape, target, floor, C.hitHeight) and target.safe ~= true then
		local fields = { slow = { multiplier = A.SlowMultiplier, seconds = A.SlowSeconds } }
		if (A.PushStuds or 0) > 0 then
			local kx, kz
			if shape.kind == "lane" then
				kx, kz = shape.dx, shape.dz
			else
				kx, kz = unit(target.x - shape.x, target.z - shape.z)
			end
			fields.push = { dx = kx or e.dx, dz = kz or e.dz, studs = A.PushStuds, seconds = A.PushSeconds }
		end
		Attack.hit(events, e, world, attack, at, fields)
	else
		Attack.miss(events, e, world, attack, at)
	end
	e.attack = nil
	e.readyAt = at + A.CooldownSeconds
	Attack.phase(events, e, "Recover", at, at + A.RecoverSeconds)
end

local function patrol(e, now, world, T, dt)
	if e.waitUntil and now < e.waitUntil then return end
	e.waitUntil = nil
	if not e.waypoint then
		e.patrolIndex += 1
		local angle = e.patrolIndex * GOLDEN
		local radius = T.PatrolRadiusStuds * (0.45 + 0.55 * ((e.patrolIndex * 0.618) % 1))
		e.waypoint = { x = e.home.x + math.cos(angle) * radius, z = e.home.z + math.sin(angle) * radius }
	end
	if walkTo(e, world, T, e.waypoint.x, e.waypoint.z, T.PatrolSpeedStudsPerSecond, dt) then
		e.waypoint = nil
		e.waitUntil = now + (T.PatrolPauseSeconds or 1.5)
	end
end

function Critter.step(events, e, now, target, world, dt)
	local C = Config.BEASTS[e.beast]
	local T = C.tuning
	local A = T.Attack
	if Attack.guard(events, e, now, target, {}) then
		if e.done then e.attack = nil end
		return
	end
	if flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
		e.farSince = e.farSince or now
	else
		e.farSince = nil
	end
	if e.farSince and now - e.farSince >= T.EscapeSeconds then
		retreat(events, e, world, now, "Escape", C.disengage)
		return
	end

	if e.phase == "Spawn" then Attack.phase(events, e, "Patrol", e.phaseAt) end
	if e.phase == "Patrol" then
		if Critter.sees(e, target, T) then
			e.waypoint, e.waitUntil = nil, nil
			Attack.face(e, target)
			Attack.phase(events, e, "Notice", now, now + T.AlertSeconds)
			return
		end
		patrol(e, now, world, T, dt)
		return
	end
	if e.phase == "Notice" then
		Attack.face(e, target)
		if now - e.phaseAt >= T.AlertSeconds then Attack.phase(events, e, "Chase", e.phaseAt + T.AlertSeconds) end
		return
	end
	if e.phase == "Chase" then
		local distance = Attack.distance(e, target)
		if distance > T.AbandonStuds then
			retreat(events, e, world, now, "GiveUp", T.GiveUpSeconds)
			return
		end
		-- held at the end of its leash with the target out of reach: GiveUpSeconds of that and it gives up
		if distance > A.RangeStuds and flat(e.pos.x, e.pos.z, e.home.x, e.home.z) >= T.LeashStuds - LEASH_EDGE then
			e.pinnedSince = e.pinnedSince or now
			if now - e.pinnedSince >= T.GiveUpSeconds then
				retreat(events, e, world, now, "GiveUp", T.GiveUpSeconds)
				return
			end
		else
			e.pinnedSince = nil
		end
		if distance <= A.RangeStuds and now >= e.readyAt then
			if openAttack(events, e, now, target, world, C, T, A) then
				e.pinnedSince = nil
				return
			end
		end
		local stand = A.kind == "leap" and 3 or math.min(A.RangeStuds * 0.6, 4)
		if distance > stand then
			local x, z = leashed(e, T, target.x, target.z)
			walkTo(e, world, T, x, z, T.ChaseSpeedStudsPerSecond, dt)
			local lx, lz = leashed(e, T, e.pos.x, e.pos.z)
			if lx ~= e.pos.x or lz ~= e.pos.z then settle(e, world, T, lx, lz) end
		else
			Attack.face(e, target)
		end
		return
	end
	if e.phase == "Telegraph" and e.attack then
		local attack = e.attack
		if now < e.lockAt then
			Attack.aim(events, e, attack, shapeFor(e, target, world, T, A), now)
			Attack.face(e, target)
		else
			Attack.lock(events, e, attack, nil, e.lockAt) -- does nothing once locked
		end
		if now >= e.releaseAt then
			Attack.lock(events, e, attack, nil, e.lockAt)
			e.from = copy(e.pos)
			Attack.phase(events, e, "Release", e.releaseAt, attack.strikeAt)
		end
		return
	end
	if e.phase == "Release" and e.attack then
		local attack = e.attack
		local shape = attack.shape
		local progress = A.TravelSeconds > 0 and math.clamp((now - e.releaseAt) / A.TravelSeconds, 0, 1) or 1
		if A.kind == "leap" then
			settle(e, world, T, e.from.x + (shape.x - e.from.x) * progress, e.from.z + (shape.z - e.from.z) * progress)
		elseif A.kind == "dash" then
			local along = shape.length * progress
			settle(e, world, T, shape.ox + shape.dx * along, shape.oz + shape.dz * along)
			e.dx, e.dz = shape.dx, shape.dz
		end
		if now >= attack.strikeAt then strike(events, e, target, world, C, T, A) end
		return
	end
	if e.phase == "Recover" and now - e.phaseAt >= A.RecoverSeconds then
		Attack.phase(events, e, "Chase", e.phaseAt + A.RecoverSeconds)
	end
end

return Critter
