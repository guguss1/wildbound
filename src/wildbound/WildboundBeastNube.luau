-- Kids biome (odd/tasks/wildbound-kids-beasts.md; docs/design/wildbound-biome-pradera.md s5): La Nube Gruñona, the
-- Pradera's grumpy cloud guardian. Server only and pure, stepped by WildboundBeastEncounters through Enc.register. It is
-- summoned at the pond (Director.summon, points 0) and lives there; e.pos is the ground under it (the body hovers
-- tuning.HoverStuds up, a visual offset only). State machine:
--   Calm (drifts between four pond waypoints, PondWaypointRadius, at CalmSpeed) -> Notice (Gruñido: GrowlSeconds still,
--   after a valid sighting) -> Chase (ChaseSpeed, never past LeashStuds from the pond; memory ChaseMemorySeconds)
--   -> Telegraph (Relámpago within BoltRange: a fixed circle at the target's spot, BoltRadius, BoltTelegraphSeconds,
--   never under Config.MIN_TELL) -> strike -> Chase ... -> GiveUp (Desinflada: unseen past the memory, ChaseGiveUpSeconds
--   or ChaseGiveUpDistance; a GiveUpSeconds retreat, End "GiveUp") or Yawn (Bostezo: YawnRoofLosses roof losses in one
--   chase; End "Yawn", the director's 60 s nap cooldown). Escape: the target outside EscapeDistance of the pond for
--   EscapeSeconds. Death and the safe zone end it at once (Attack.guard).
-- Sense: sight only, from the server: target.covered (one upward ray against WildboundRoof parts) and the flat range
-- (DetectionRadius, Night NightDetectionRadius). No camera, no hearing.
-- Threat (kids rule): damage 0. The first hit asks BeastHit (the carried egg falls) and marks the target (event.mark,
-- MarkSeconds); a hit while marked (target.markedUntil) is the Ráfaga: event.knock toward the Pradera gate.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Nube = {}

local finite, flat, unit = Config.finite, Config.flat, Config.unit
local copy = Attack.copy

function Nube.init(e)
	e.home = copy(e.pos)
	e.waypoint, e.roofLosses, e.boltReadyAt = 1, 0, -math.huge
end

-- A valid sighting: open sky over the target and inside the detection range (smaller at Night).
function Nube.sees(e, target, T)
	if target.covered == true then return false end
	local range = target.night == true and T.NightDetectionRadiusStuds or T.DetectionRadiusStuds
	return Attack.distance(e, target) <= range
end

function Nube.tellSeconds(T)
	return math.max(T.BoltTelegraphSeconds, Config.MIN_TELL)
end

-- Keeps the cloud within LeashStuds of the pond.
local function leash(e, T)
	local d = flat(e.pos.x, e.pos.z, e.home.x, e.home.z)
	if d > T.LeashStuds then
		local ux, uz = unit(e.pos.x - e.home.x, e.pos.z - e.home.z)
		e.pos.x, e.pos.z = e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
end

local function moveTo(e, x, z, speed, dt, world)
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	if not dx then return end
	local step = math.min(speed * dt, flat(e.pos.x, e.pos.z, x, z))
	e.pos.x += dx * step
	e.pos.z += dz * step
	e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	e.dx, e.dz = dx, dz
end

local function retreat(events, e, world, now, phase, reason, seconds)
	Attack.closeAll(e, world)
	e.bolt = nil
	if phase then Attack.phase(events, e, phase, now, now + seconds) end
	Attack.disengage(events, e, reason, now, seconds)
end

local function startChase(events, e, now)
	e.chaseAt, e.seenAt, e.wasSeen, e.roofLosses = now, now, true, 0
	Attack.phase(events, e, "Chase", now)
end

local function openBolt(events, e, now, target, world, C, T)
	local y = Attack.groundAt(world, target.x, target.z, target.y - 3)
	local strikeAt = now + Nube.tellSeconds(T)
	local attack = Attack.open(events, e, world, { key = "bolt", startAt = now, strikeAt = strikeAt, dodgeable = false,
		damage = C.damage, lockAt = now, shape = { kind = "circle", x = target.x, y = y, z = target.z, r = T.BoltRadiusStuds } })
	if not attack then return false end
	-- The ring never follows the target: it is fixed where it was drawn.
	Attack.lock(events, e, attack, nil, now)
	e.bolt = attack
	Attack.face(e, target)
	Attack.phase(events, e, "Telegraph", now, strikeAt)
	return true
end

local function strike(events, e, now, target, world, C, T)
	local attack = e.bolt
	local at = attack.strikeAt
	local inside = Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) and target.covered ~= true
		and target.safe ~= true
	if inside then
		local fields
		if finite(target.markedUntil) and target.markedUntil > at then
			-- Ráfaga: a second hit while marked pushes the target back toward the gate (client-clamped).
			local gate = world.site and world.site("gate")
			local kx, kz
			if gate then kx, kz = unit(gate.x - target.x, gate.z - target.z) end
			if not kx then kx, kz = unit(target.x - e.pos.x, target.z - e.pos.z) end
			fields = { knock = { dx = kx or e.dx, dz = kz or e.dz, speed = T.GustStudsPerSecond }, line = "Gust" }
		else
			fields = { mark = T.MarkSeconds }
		end
		Attack.hit(events, e, world, attack, at, fields)
	else
		Attack.miss(events, e, world, attack, at)
	end
	e.bolt = nil
	e.boltReadyAt = at + T.BoltRecoverSeconds
	Attack.phase(events, e, "Chase", at)
end

function Nube.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.NubeGrunona
	local T = C.tuning
	if Attack.guard(events, e, now, target, {}) then return end
	-- Escape: outside EscapeDistance of the pond for EscapeSeconds.
	if flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
		e.farSince = e.farSince or now
	else
		e.farSince = nil
	end
	if e.farSince and now - e.farSince >= T.EscapeSeconds then
		retreat(events, e, world, now, nil, "Escape", C.disengage)
		return
	end

	if e.phase == "Spawn" then Attack.phase(events, e, "Calm", e.phaseAt) end
	if e.phase == "Calm" then
		if Nube.sees(e, target, T) then
			Attack.face(e, target)
			Attack.phase(events, e, "Notice", now, now + T.GrowlSeconds)
		else
			local a = (e.waypoint - 1) * math.pi / 2
			local wx, wz = e.home.x + math.cos(a) * T.PondWaypointRadiusStuds, e.home.z + math.sin(a) * T.PondWaypointRadiusStuds
			moveTo(e, wx, wz, T.CalmSpeedStudsPerSecond, dt, world)
			if flat(e.pos.x, e.pos.z, wx, wz) < 0.5 then e.waypoint = e.waypoint % 4 + 1 end
		end
		return
	end
	if e.phase == "Notice" then
		-- Gruñido: it growls in place, then chases.
		Attack.face(e, target)
		if now - e.phaseAt >= T.GrowlSeconds then startChase(events, e, e.phaseAt + T.GrowlSeconds) end
		return
	end
	if e.phase == "Chase" then
		local seen = Nube.sees(e, target, T)
		if seen then e.seenAt = now end
		if e.wasSeen and not seen and target.covered == true then e.roofLosses += 1 end
		e.wasSeen = seen
		local distance = Attack.distance(e, target)
		if e.roofLosses >= T.YawnRoofLosses then
			retreat(events, e, world, now, "Yawn", "Yawn", T.YawnSeconds)
			return
		end
		if now - e.seenAt > T.ChaseMemorySeconds or now - e.chaseAt >= T.ChaseGiveUpSeconds
			or distance > T.ChaseGiveUpDistanceStuds then
			retreat(events, e, world, now, "GiveUp", "GiveUp", T.GiveUpSeconds)
			return
		end
		if seen and distance <= T.BoltRangeStuds and now >= e.boltReadyAt then
			if openBolt(events, e, now, target, world, C, T) then return end
		end
		if distance > 2 then moveTo(e, target.x, target.z, T.ChaseSpeedStudsPerSecond, dt, world) end
		leash(e, T)
		return
	end
	if e.phase == "Telegraph" and e.bolt and now >= e.bolt.strikeAt then
		strike(events, e, now, target, world, C, T)
	end
end

return Nube
