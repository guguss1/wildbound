-- Caramelo biome (pack 03_PERSONAJES/01_GOMIBU.md): Gomibu, the gummy bear that guards a candy nest. Server only and
-- pure, stepped by WildboundBeastEncounters through Enc.register, on the WildboundBeastNube pattern. It is summoned at
-- its nest (Director.summon, points 0) and lives there; e.pos is the ground under it. State machine:
--   Calm (waits at the nest) -> Notice (Alert: AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (bounces after it at ChaseSpeed, never past LeashStuds from the nest)
--   -> Telegraph (Golpe de Goma within JumpRange: a circle of RadiusStuds on the target that follows it until
--      LockSeconds and never again; TelegraphSeconds, never under Config.MIN_TELL)
--   -> Jump (one straight arc of JumpSeconds from where it stood to the locked circle; the strike is the landing)
--   -> Recover (RecoverSeconds) -> Chase ... -> GiveUp (the target past AbandonStuds).
--   Escape: the target outside EscapeDistance of the nest for EscapeSeconds. Death and the safe zone end it (Attack.guard).
-- Threat: damage 0. A hit slows (event.slow) and pushes away from the circle (event.push, applied by the server: a
-- client-side knock barely moves a standing player); the egg stays (the beast
-- script skips BeastHit for a keepsEgg beast). After a jump it cannot open another for AttackCooldownSeconds.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Gomibu = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy

function Gomibu.init(e)
	e.home = copy(e.pos)
	e.readyAt = -math.huge
end

function Gomibu.sees(e, target, T)
	return Attack.distance(e, target) <= T.PerceptionStuds
end

function Gomibu.tellSeconds(T)
	return math.max(T.TelegraphSeconds, Config.MIN_TELL)
end

-- Where the circle goes for a target: on it, or JumpRange away from Gomibu in its direction when it is further.
local function aimPoint(e, target, T)
	local x, z = target.x, target.z
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance > T.JumpRangeStuds then
		local ux, uz = unit(x - e.pos.x, z - e.pos.z)
		x, z = e.pos.x + ux * T.JumpRangeStuds, e.pos.z + uz * T.JumpRangeStuds
	end
	-- and never lands past the leash from the nest
	local fromHome = flat(x, z, e.home.x, e.home.z)
	if fromHome > T.LeashStuds then
		local ux, uz = unit(x - e.home.x, z - e.home.z)
		x, z = e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
	return x, z
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
	e.jump = nil
	if phase then Attack.phase(events, e, phase, now, now + seconds) end
	Attack.disengage(events, e, reason, now, seconds)
end

local function openJump(events, e, now, target, world, C, T)
	local x, z = aimPoint(e, target, T)
	local y = Attack.groundAt(world, x, z, target.y - 3)
	local takeOff = now + Gomibu.tellSeconds(T)
	local attack = Attack.open(events, e, world, { key = "jump", startAt = now, strikeAt = takeOff + T.JumpSeconds, dodgeable = false,
		damage = C.damage, lockAt = now + T.LockSeconds, shape = { kind = "circle", x = x, y = y, z = z, r = T.RadiusStuds } })
	if not attack then return false end
	e.jump, e.takeOffAt, e.lockAt = attack, takeOff, now + T.LockSeconds
	Attack.face(e, target)
	Attack.phase(events, e, "Telegraph", now, takeOff)
	return true
end

local function land(events, e, target, world, C, T)
	local attack = e.jump
	local at = attack.strikeAt
	e.pos.x, e.pos.z = attack.shape.x, attack.shape.z
	if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) and target.safe ~= true then
		local kx, kz = unit(target.x - attack.shape.x, target.z - attack.shape.z)
		Attack.hit(events, e, world, attack, at, { push = { dx = kx or e.dx, dz = kz or e.dz, studs = T.PushStuds, seconds = T.PushSeconds },
			slow = { multiplier = T.SlowMultiplier, seconds = T.SlowSeconds } })
	else
		Attack.miss(events, e, world, attack, at)
	end
	e.jump = nil
	e.readyAt = at + T.RecoverSeconds + T.AttackCooldownSeconds
	Attack.phase(events, e, "Recover", at, at + T.RecoverSeconds)
end

function Gomibu.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Gomibu
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
		if Gomibu.sees(e, target, T) then
			Attack.face(e, target)
			Attack.phase(events, e, "Notice", now, now + T.AlertSeconds)
		end
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
			retreat(events, e, world, now, "GiveUp", "GiveUp", T.GiveUpSeconds)
			return
		end
		if distance <= T.JumpRangeStuds and now >= e.readyAt then
			if openJump(events, e, now, target, world, C, T) then return end
		end
		if distance > 3 then
			local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
			if dx then
				local step = math.min(T.ChaseSpeedStudsPerSecond * dt, distance)
				e.pos.x += dx * step
				e.pos.z += dz * step
				e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
				e.dx, e.dz = dx, dz
			end
		end
		leash(e, T)
		return
	end
	if e.phase == "Telegraph" and e.jump then
		local attack = e.jump
		if now < e.lockAt then
			-- the circle follows the target, never further than a jump from where Gomibu stands
			local x, z = aimPoint(e, target, T)
			Attack.aim(events, e, attack, { kind = "circle", x = x, y = attack.shape.y, z = z, r = T.RadiusStuds }, now)
			Attack.face(e, target)
		else
			Attack.lock(events, e, attack, nil, e.lockAt) -- does nothing once locked
		end
		if now >= e.takeOffAt then
			Attack.lock(events, e, attack, nil, e.lockAt)
			e.from = copy(e.pos)
			Attack.phase(events, e, "Jump", e.takeOffAt, attack.strikeAt)
		end
		return
	end
	if e.phase == "Jump" and e.jump then
		local attack = e.jump
		local progress = math.clamp((now - e.takeOffAt) / T.JumpSeconds, 0, 1)
		e.pos.x = e.from.x + (attack.shape.x - e.from.x) * progress
		e.pos.z = e.from.z + (attack.shape.z - e.from.z) * progress
		e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
		if now >= attack.strikeAt then land(events, e, target, world, C, T) end
		return
	end
	if e.phase == "Recover" and now - e.phaseAt >= T.RecoverSeconds then
		Attack.phase(events, e, "Chase", e.phaseAt + T.RecoverSeconds)
	end
end

return Gomibu
