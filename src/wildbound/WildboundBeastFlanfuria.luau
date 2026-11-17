-- Caramelo biome (pack 03_PERSONAJES/02_FLANFURIA.md): Flanfuria, the flan with a cream kitten, guarding a candy nest.
-- Server only and pure, stepped by WildboundBeastEncounters through Enc.register, on the WildboundBeastGomibu pattern.
-- It is summoned at its nest (Director.summon, points 0) and lives there; e.pos is the ground under it. State machine:
--   Calm (waits at the nest) -> Notice (Alert: AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (hops after it at ChaseSpeed, never past LeashStuds from the nest)
--   -> Telegraph (Onda de Caramelo within CastRange: a circle of radius 11 on the flan, fixed from the start; 0.80 s)
--   -> Release (0.80 s: the ring front grows from radius 2 to 11; the target is slowed once, when the front passes it,
--      unless it is in the air) -> Recover (0.60 s) -> Chase ... -> GiveUp (the target past AbandonStuds; GiveUpSeconds
--      standing) -> Return (B5: walks back to the nest; the encounter ends there with no fade, where its resting copy
--      stands).
--   From the end of the release a puddle of radius 4 lies where the flan stood for 3 s and slows whoever stands in it.
--   Escape: the target outside EscapeDistance of the nest for EscapeSeconds: the same walk home. Death and the safe zone
--   end it at once (Attack.guard).
--   RC (owner request 2026-11-16, WildboundCandySmarts.RELENTLESS): once it notices it hunts: no leash, abandon or
--   escape; only the safe zone, death, a leave or the hard limit (reason Timeout) end it, and an ending far from the
--   nest fades out (Disengage) instead of the walk home.
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
-- OF3 (owner feedback 3): sprint, predictive pursuit, flanking, side-steps, the dodge pause, nest guard and the call
local Smarts = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundCandySmarts"))
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
-- B5 (odd/tasks/wildbound-caramelo-playfix.md): a calm ending never fades out where it stands (Gomibu's PF4 path). It
-- may stand a moment first (GiveUp, for `seconds`), then walks back to its nest (Return) and the encounter ends there,
-- where its resting copy stands between encounters.
local function retreat(events, e, world, now, phase, reason, seconds)
	Attack.closeAll(e, world)
	if e.cast then Onda.cancel(e.cast) end
	e.wave, e.cast = nil, nil
	e.returnReason = reason
	-- the shared guard (Attack.guard) reads e.farSince too: a stale one would fade it out on the walk home
	e.farSince = nil
	-- RC3: a hunt that ended far from the nest fades out there (the shared Disengage fade); its resting copy is back home
	if Smarts.farFromHome(e) then
		Attack.disengage(events, e, reason, now, Config.BEASTS[e.beast].disengage)
		return
	end
	if phase then
		Attack.phase(events, e, phase, now, now + seconds)
		e.returnAt = now + seconds
	else
		Attack.phase(events, e, "Return", now, nil, { reason = reason })
	end
end

-- Moves toward (x, z) at speed for dt on the ground; returns true on arrival.
local function walkTo(e, world, x, z, speed, dt)
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance <= 1e-3 then return true end
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	local step = math.min(speed * (dt or 0), distance)
	e.pos.x += dx * step
	e.pos.z += dz * step
	e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	e.dx, e.dz = dx, dz
	return step >= distance - 1e-6
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
	-- B5: standing a moment after giving up, then the walk home; the encounter ends at the nest with no fade
	if e.phase == "GiveUp" then
		if now >= (e.returnAt or now) then Attack.phase(events, e, "Return", now, nil, { reason = e.returnReason }) end
		return
	end
	if e.phase == "Return" then
		if walkTo(e, world, e.home.x, e.home.z, T.ChaseSpeedStudsPerSecond * 0.6, dt) then
			e.dx, e.dz = 0, 1 -- the resting copy's facing
			table.insert(events, Attack.finish(e, e.returnReason or "Done", now))
		end
		return
	end
	-- RC1: a relentless hunt has one hard limit (Smarts.RELENTLESS.hardSeconds); it ends like a give-up
	if Smarts.overtime(e, now) then
		retreat(events, e, world, now, "GiveUp", "Timeout", T.GiveUpSeconds)
		return
	end
	-- RC1: the escape distance only sends home a calm flan whose visitor walked away, never one that hunts
	if not Smarts.hunting(e) and flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
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
		local saw = Flanfuria.sees(e, target, T) or Smarts.guards(e, target) -- OF3: its nest guarded, allies called
		-- RC4: it starts its hunt only while fewer than Smarts.RELENTLESS.maxChasers hunt this player
		if (saw or Smarts.called(e, world, now)) and Smarts.engage(e, world, now) then
			if saw then Smarts.alarm(e, world, now) end
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
		local hunting = Smarts.hunting(e) -- RC1: no abandon distance and no leash while it hunts
		if not hunting and distance > T.AbandonStuds then
			retreat(events, e, world, now, "GiveUp", "GiveUp", T.GiveUpSeconds)
			return
		end
		if Smarts.dodged(e, world, now, target) then Attack.face(e, target) return end -- OF3: a dodge: it stops and re-aims
		if distance <= T.CastRangeStuds and now >= e.readyAt then
			Attack.face(e, target)
			if openWave(events, e, now, world, C) then return end
		end
		if distance > T.StandOffStuds then
			-- OF3: for the lead (or flank) point, sprinting at first, round obstacles
			local gx, gz = Smarts.goal(e, world, now, target)
			local dx, dz = Smarts.direction(e, world, gx, gz)
			if dx then
				local step = math.min(Smarts.speed(e, now, T.ChaseSpeedStudsPerSecond, target) * dt, distance - T.StandOffStuds)
				e.pos.x += dx * step
				e.pos.z += dz * step
				e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
				e.dx, e.dz = dx, dz
			end
		end
		if not hunting then leash(e, T) end
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
