-- Caramelo biome (pack 03_PERSONAJES/03_TORTIDRAGON.md): Tortidragon, the cake-and-strawberry dragon guarding a candy
-- nest. Server only and pure, stepped by WildboundBeastEncounters through Enc.register, on the WildboundBeastGomibu
-- pattern. It is summoned at its nest (Director.summon, points 0) and lives there; e.pos is the ground under it.
-- It is directional: e.dx, e.dz is where it faces, and it turns at TurnDegreesPerSecond (never snaps round).
-- State machine:
--   Calm (waits at the nest) -> Notice (Alert: AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (trots after it at ChaseSpeed, turning toward it, never past LeashStuds from the nest)
--   -> Telegraph (Abanico de Confites, only at a target inside its fan within CastRange: the fan follows the target
--      until the lock at 0.60 s, then three circles freeze along that direction; 1.00 s)
--   -> Release (0.65 s: the shots fly; at its end they land, the only moment anybody is hit) -> Recover (0.85 s)
--   -> Chase ... -> GiveUp (the target past AbandonStuds).
--   Escape: the target outside EscapeDistance of the nest for EscapeSeconds. Death and the safe zone end it (Attack.guard).
-- The attack's numbers and rules are WildboundCandyTortidragonAttack (one source). Threat: damage 0. A hit is a light
-- push away from the dragon and a short stagger (event.push and event.slow on the Hit event); the egg stays (the beast
-- script skips BeastHit for a keepsEgg beast). One hit per cast however many circles the target stands in.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Abanico = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyTortidragonAttack"))
-- OF3 (owner feedback 3): sprint, predictive aim, flanking, side-steps, the dodge pause, nest guard and the call
local Smarts = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundCandySmarts"))
local Tortidragon = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy

function Tortidragon.init(e)
	e.home = copy(e.pos)
	e.readyAt = -math.huge
	if not e.dx then e.dx, e.dz = 0, -1 end
end

function Tortidragon.sees(e, target, T)
	return Attack.distance(e, target) <= T.PerceptionStuds
end

function Tortidragon.tellSeconds()
	return math.max(Abanico.TELEGRAPH_SECONDS + Abanico.RELEASE_SECONDS, Config.MIN_TELL)
end

-- Turns the facing toward the target by at most TurnDegreesPerSecond * dt. Returns the angle left, in degrees.
local function turn(e, target, T, dt)
	local tx, tz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if not tx then return 0 end
	local fx, fz = e.dx or 0, e.dz or -1
	local current, wanted = math.atan2(fz, fx), math.atan2(tz, tx)
	local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
	local step = math.rad(T.TurnDegreesPerSecond) * (dt or 0)
	if math.abs(delta) <= step then
		e.dx, e.dz = tx, tz
		return 0
	end
	local angle = current + (delta > 0 and step or -step)
	e.dx, e.dz = math.cos(angle), math.sin(angle)
	return math.deg(math.abs(delta) - step)
end

local function leash(e, T)
	local d = flat(e.pos.x, e.pos.z, e.home.x, e.home.z)
	if d > T.LeashStuds then
		local ux, uz = unit(e.pos.x - e.home.x, e.pos.z - e.home.z)
		e.pos.x, e.pos.z = e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
end

local function retreat(events, e, world, now, phase, reason, seconds)
	Attack.closeAll(e, world)
	e.fan, e.cast, e.shots = nil, nil, nil
	if phase then Attack.phase(events, e, phase, now, now + seconds) end
	Attack.disengage(events, e, reason, now, seconds)
end

local function origin(e) return { x = e.pos.x, y = e.pos.y, z = e.pos.z } end

local function openFan(events, e, now, world, C)
	local cast = Abanico.start(now, {})
	if not cast then return false end
	local attack = Attack.open(events, e, world, { key = "fan", startAt = now, strikeAt = Abanico.impactAt(cast), dodgeable = false,
		damage = C.damage, lockAt = Abanico.lockAt(cast), shape = Abanico.fan(origin(e), e.dx, e.dz) })
	if not attack then return false end
	e.fan, e.cast, e.shots = attack, cast, nil
	Attack.phase(events, e, "Telegraph", now, Abanico.releaseAt(cast))
	return true
end

-- The lock: the direction freezes and the fan becomes the three circles, which are now the exact hit volume.
local function lock(events, e, target, at)
	local o = origin(e)
	e.shots = Abanico.shots(o, e.dx, e.dz, flat(o.x, o.z, target.x, target.z))
	Attack.lock(events, e, e.fan, e.shots, at)
end

local function impact(events, e, target, world, C)
	local cast, attack = e.cast, e.fan
	local at = Abanico.impactAt(cast)
	local ground = attack.shape.list and attack.shape.list[1].y or e.pos.y
	local inside = Attack.inside(e.shots, target, ground, C.hitHeight)
	local landed = Abanico.impact(cast, e.shots, origin(e), { { id = 1, x = target.x, z = target.z, alive = target.alive == true,
		safe = target.safe == true or not inside } })[1]
	if landed then
		Attack.hit(events, e, world, attack, at, { push = { dx = landed.push.dx, dz = landed.push.dz, studs = landed.push.studs,
			seconds = landed.push.seconds }, slow = { multiplier = landed.slowFactor, seconds = landed.slowSeconds } })
	else
		Attack.miss(events, e, world, attack, at)
	end
	e.fan = nil
	e.readyAt = Abanico.endsAt(cast) + Abanico.COOLDOWN_SECONDS
	Attack.phase(events, e, "Recover", at, Abanico.endsAt(cast))
end

function Tortidragon.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Tortidragon
	local T = C.tuning
	if Attack.guard(events, e, now, target, {}) then return end
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
		local saw = Tortidragon.sees(e, target, T) or Smarts.guards(e, target) -- OF3: its nest guarded, allies called
		if saw or Smarts.called(e, world, now) then
			if saw then Smarts.alarm(e, world, now) end
			turn(e, target, T, dt)
			Attack.phase(events, e, "Notice", now, now + T.AlertSeconds)
		end
		return
	end
	if e.phase == "Notice" then
		turn(e, target, T, dt)
		if now - e.phaseAt >= T.AlertSeconds then Attack.phase(events, e, "Chase", e.phaseAt + T.AlertSeconds) end
		return
	end
	if e.phase == "Chase" then
		local distance = Attack.distance(e, target)
		if distance > T.AbandonStuds then
			retreat(events, e, world, now, "GiveUp", "GiveUp", T.GiveUpSeconds)
			return
		end
		-- only at a target inside the fan it faces now: one behind it or at its side is turned toward first
		if distance <= T.CastRangeStuds and now >= e.readyAt and Abanico.canCast(e.pos, e.dx, e.dz, target) then
			if openFan(events, e, now, world, C) then return end
		end
		if Smarts.dodged(e, world, now) then turn(e, target, T, dt) return end -- OF3: a dodge: it stops and re-aims
		-- OF3: it turns toward the lead (or flank) point, sprints at first and side-steps what blocks its way
		local gx, gz = Smarts.goal(e, world, now, target)
		turn(e, { x = gx, z = gz }, T, dt)
		if distance > T.StandOffStuds then
			local mx, mz = Smarts.steer(e, world, e.dx, e.dz)
			if mx then
				local step = math.min(Smarts.speed(e, now, T.ChaseSpeedStudsPerSecond) * (dt or 0), distance - T.StandOffStuds)
				e.pos.x += mx * step
				e.pos.z += mz * step
				e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
			end
		end
		leash(e, T)
		return
	end
	if e.phase == "Telegraph" and e.fan then
		local cast = e.cast
		if not e.shots then
			if now < Abanico.lockAt(cast) then
				-- the fan follows the target until the lock (OF3: where it will be)
				local lx, lz = Smarts.lead(e, target, now, Smarts.profile(e.beast).aimLead)
				turn(e, { x = lx, z = lz }, T, dt)
				Attack.aim(events, e, e.fan, Abanico.fan(origin(e), e.dx, e.dz), now)
				return
			end
			lock(events, e, target, Abanico.lockAt(cast))
		end
		if now < Abanico.releaseAt(cast) then return end
		Attack.phase(events, e, "Release", Abanico.releaseAt(cast), Abanico.impactAt(cast))
	end
	if e.phase == "Release" and e.fan then
		if now < Abanico.impactAt(e.cast) then return end
		impact(events, e, target, world, C)
		return
	end
	if e.phase == "Recover" and e.cast and now >= Abanico.endsAt(e.cast) then
		Attack.phase(events, e, "Chase", Abanico.endsAt(e.cast))
	end
end

return Tortidragon
