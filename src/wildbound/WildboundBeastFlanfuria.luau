-- Caramelo biome (pack 03_PERSONAJES/02_FLANFURIA.md): Flanfuria, the flan with a cream kitten, guarding a candy nest.
-- Server only and pure, stepped by WildboundBeastEncounters through Enc.register, on the WildboundBeastGomibu pattern.
-- It is summoned at its nest (Director.summon, points 0) and lives there; e.pos is the ground under it. State machine:
--   Calm (waits at the nest) -> Notice (Alert: AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (hops after it at ChaseSpeed, never past LeashStuds from the nest)
--   -> Telegraph (Onda de Caramelo within CastRange: a circle of radius 11 on the flan, fixed from the start; 0.80 s)
--   -> Release (0.80 s: the ring front grows from radius 2 to 11; the target is slowed once, when the front passes it,
--      unless it is in the air) -> Recover (0.60 s) -> Chase ... -> GiveUp (the target past AbandonStuds).
--   From the end of the release a puddle of radius 4 lies where the flan stood for 3 s and slows whoever stands in it.
--   Escape: the target outside EscapeDistance of the nest for EscapeSeconds. Death and the safe zone end it (Attack.guard).
-- The attack's numbers and rules are WildboundCandyFlanfuriaAttack (one source); this module only walks it through the
-- shared attack layer. Threat (OF2): the ring's slow carries damage. Both slows travel as Afflict events, which the beast script applies with its
-- non-stacking, self-expiring applySlow and never sends to BeastHit: no damage, and the carried egg stays.
-- applySlow restores the speed by a delayed task, so no slow of this beast starts until SLOW_GAP_SECONDS after its
-- last one ended (e.slowFreeAt): the puddle slow is a short pulse repeated while stood on, and its first pulse waits
-- for the ring slow to be over. A slow landing on a speed not yet restored would stay.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Onda = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyFlanfuriaAttack"))
local Flanfuria = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy

function Flanfuria.init(e)
	e.home = copy(e.pos)
	e.readyAt = -math.huge
end

function Flanfuria.sees(e, target, T)
	return Attack.distance(e, target) <= T.PerceptionStuds
end

function Flanfuria.tellSeconds()
	return math.max(Onda.TELEGRAPH_SECONDS, Config.MIN_TELL)
end

-- The target as the attack rules see it. In the air: its body is more than JumpClearStuds over the ground under it
-- (a standing body is about 3).
local function seen(target, world, T)
	local ground = Attack.groundAt(world, target.x, target.z, target.y - 3)
	return { id = 1, x = target.x, z = target.z, alive = target.alive == true, safe = target.safe == true,
		airborne = target.y - ground > T.JumpClearStuds }
end

local function leash(e, T)
	local d = flat(e.pos.x, e.pos.z, e.home.x, e.home.z)
	if d > T.LeashStuds then
		local ux, uz = unit(e.pos.x - e.home.x, e.pos.z - e.home.z)
		e.pos.x, e.pos.z = e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
end

-- Leaving combat: the open tell, the ring and the puddle all go.
local function retreat(events, e, world, now, phase, reason, seconds)
	Attack.closeAll(e, world)
	if e.cast then Onda.cancel(e.cast) end
	e.wave = nil
	if phase then Attack.phase(events, e, phase, now, now + seconds) end
	Attack.disengage(events, e, reason, now, seconds)
end

local function openWave(events, e, now, world, C)
	local releaseAt = now + Flanfuria.tellSeconds()
	local attack = Attack.open(events, e, world, { key = "wave", startAt = now, strikeAt = releaseAt, dodgeable = false,
		damage = C.damage, lockAt = now, shape = { kind = "circle", x = e.pos.x, y = e.pos.y, z = e.pos.z, r = Onda.RING_TO_STUDS } })
	if not attack then return false end
	Attack.lock(events, e, attack, nil, now) -- the flan stands still: the circle never moves
	e.wave = attack
	e.cast = Onda.start(now, { x = e.pos.x, z = e.pos.z }, {})
	Attack.phase(events, e, "Telegraph", now, releaseAt)
	return true
end

function Flanfuria.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Flanfuria
	local T = C.tuning
	if Attack.guard(events, e, now, target, {}) then
		if e.done and e.cast then Onda.cancel(e.cast) end
		return
	end
	if flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
		e.farSince = e.farSince or now
	else
		e.farSince = nil
	end
	if e.farSince and now - e.farSince >= T.EscapeSeconds then
		retreat(events, e, world, now, nil, "Escape", C.disengage)
		return
	end

	-- The puddle outlives the cast's phases: it is checked on every step of a living encounter.
	if e.cast and Onda.puddleActive(e.cast, now) and now >= (e.slowFreeAt or -math.huge) then
		local stuck = Onda.puddle(e.cast, now, { seen(target, world, T) })[1]
		if stuck then
			e.slowFreeAt = now + stuck.slowSeconds + Onda.SLOW_GAP_SECONDS
			Attack.emit(events, e, "Afflict", now, { slow = stuck.slowFactor, slowSeconds = stuck.slowSeconds, puddle = true })
		end
	end

	if e.phase == "Spawn" then Attack.phase(events, e, "Calm", e.phaseAt) end
	if e.phase == "Calm" then
		if Flanfuria.sees(e, target, T) then
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
		if distance <= T.CastRangeStuds and now >= e.readyAt then
			Attack.face(e, target)
			if openWave(events, e, now, world, C) then return end
		end
		if distance > T.StandOffStuds then
			local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
			if dx then
				local step = math.min(T.ChaseSpeedStudsPerSecond * dt, distance - T.StandOffStuds)
				e.pos.x += dx * step
				e.pos.z += dz * step
				e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
				e.dx, e.dz = dx, dz
			end
		end
		leash(e, T)
		return
	end
	if e.phase == "Telegraph" and e.cast then
		if now < Onda.releaseAt(e.cast) then return end
		Attack.phase(events, e, "Release", Onda.releaseAt(e.cast), Onda.puddleAt(e.cast))
	end
	if e.phase == "Release" and e.cast then
		if e.wave then
			local caught = Onda.sweep(e.cast, now, { seen(target, world, T) })[1]
			if caught then
				-- a perfect dodge leaves no slow, so only a landed one holds the next slow back
				-- OF2: the ring's slow carries its damage (the beast script sends it to BeastHit with the egg kept)
				if Attack.afflict(events, e, world, e.wave, now, { slow = caught.slowFactor, slowSeconds = caught.slowSeconds, shake = true,
					damage = Config.BEASTS[e.beast].damage }) == "Afflicted" then
					e.slowFreeAt = now + caught.slowSeconds + Onda.SLOW_GAP_SECONDS
				end
				e.wave = nil
			end
		end
		if now < Onda.puddleAt(e.cast) then return end
		if e.wave then
			Attack.miss(events, e, world, e.wave, Onda.puddleAt(e.cast))
			e.wave = nil
		end
		e.readyAt = Onda.endsAt(e.cast) + Onda.COOLDOWN_SECONDS
		Attack.phase(events, e, "Recover", Onda.puddleAt(e.cast), Onda.endsAt(e.cast))
		return
	end
	if e.phase == "Recover" and e.cast and now >= Onda.endsAt(e.cast) then
		Attack.phase(events, e, "Chase", Onda.endsAt(e.cast))
	end
end

return Flanfuria
