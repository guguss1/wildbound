-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Lurker, the stalker that moves while unseen (pack
-- 02_BESTIAS/LURKER). Server only and pure, stepped by WildboundBeastEncounters through Enc.register. State machine:
--   SilentSpawn (behind the target, InitialSpawnDistanceStuds, out of view when possible) -> Presence (Fase 1:
--   presenceSeconds of clues only, never a leap) -> Stalk (Fase 2: observed -> StalkObserved: it freezes for
--   ObservedPauseSeconds, then backs off at ObservedRetreatSpeed while still observed; unobserved -> CoverApproach,
--   Fase 3: it closes in at UnobservedApproachSpeed in bursts with short pauses, always walking, never a teleport; the
--   observed/unobserved switch needs observeHysteresis seconds, so small camera turns never make it flicker)
--   -> LeapWindup (Fase 4: in LeapMin..LeapMax with a clear line, LeapTelegraphSeconds; the landing circle follows the
--   target and freezes at the end of the windup; registered with the perfect dodge for windup + travel)
--   -> LeapCommit (LeapTravelSeconds on a fixed arc, no correction) -> Land, or OverrunStunned (a validated perfect
--   dodge: it lands LeapOverrunDistanceStuds past the spot and is stunned PerfectDodgeStunSeconds)
--   -> Stalk (LeapCooldownSeconds before the next leap) ... -> Disengage (escape, timeout) -> End.
-- The observation is target.observe(point, halfAngle, maxDist, favour): favour is true here, so a short gap in the
-- camera data reads as "observed" (Lurker waits); the data never decides a hit. Every number is Config.BEASTS.Lurker
-- (tuning = PROPUESTA DE BALANCE).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Lurker = {}

local finite, unit = Config.finite, Config.unit
local copy, emit = Attack.copy, Attack.emit

function Lurker.init(e, now)
	e.seen, e.rawSeen, e.rawSince = false, false, now
	e.leapReadyAt, e.pauseUntil, e.burstAt = -math.huge, -math.huge, now
end

local function observedRaw(e, target, C)
	if type(target.observe) ~= "function" then return false end
	local body = { x = e.pos.x, y = e.pos.y + 1.5, z = e.pos.z }
	return target.observe(body, C.observeCone, C.escapeDistance, true) == true
end

-- Hysteresis: the reported state changes only after the raw observation held for observeHysteresis seconds.
function Lurker.see(e, now, raw, C)
	if raw ~= e.rawSeen then e.rawSeen, e.rawSince = raw, now end
	if e.rawSeen ~= e.seen and now - e.rawSince >= C.observeHysteresis then
		e.seen = e.rawSeen
		return true
	end
	return false
end

local function landingCircle(dest, C)
	return { kind = "circle", x = dest.x, y = dest.y, z = dest.z, r = C.leapRadius }
end

local function startLeap(events, e, now, target, world, C, T)
	local dest = { x = target.x, y = Attack.groundAt(world, target.x, target.z, target.y - 3), z = target.z }
	local strikeAt = now + T.LeapTelegraphSeconds + T.LeapTravelSeconds
	-- BR6 (odd/tasks/wildbound-beast-revision.md): the landing circle is hidden (never drawn); the crouch is the only cue.
	local attack = Attack.open(events, e, world, { key = "leap", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.LeapDamage, lockAt = now + T.LeapTelegraphSeconds, shape = landingCircle(dest, C), hidden = C.hideTells })
	if not attack then return false end
	e.leap, e.dest, e.leapAt = attack, dest, now + T.LeapTelegraphSeconds
	Attack.face(e, target)
	Attack.phase(events, e, "LeapWindup", now, e.leapAt)
	return true
end

local function stalk(events, e, at, T)
	Attack.phase(events, e, e.seen and "StalkObserved" or "CoverApproach", at)
end

function Lurker.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Lurker
	local T = C.tuning
	local busy = e.phase == "LeapWindup" or e.phase == "LeapCommit"
	if Attack.guard(events, e, now, target, { timeout = T.EncounterTimeoutSeconds, escapeDistance = C.escapeDistance,
		escapeSeconds = C.escapeSeconds, busy = busy, disengage = C.disengage }) then return end

	if e.phase == "Spawn" then
		Attack.phase(events, e, "Presence", e.phaseAt, e.phaseAt + C.presenceSeconds)
	end
	local changed = Lurker.see(e, now, observedRaw(e, target, C), C)
	if e.phase == "Presence" then
		-- Fase 1: clues only. It keeps its distance and never leaps.
		Attack.face(e, target)
		if now - e.phaseAt >= C.presenceSeconds then
			stalk(events, e, e.phaseAt + C.presenceSeconds, T)
			if e.seen then e.pauseUntil = now + T.ObservedPauseSeconds end
		end
		return
	end
	if (e.phase == "StalkObserved" or e.phase == "CoverApproach") and changed then
		if e.seen then e.pauseUntil = now + T.ObservedPauseSeconds else e.burstAt = now end
		stalk(events, e, now, T)
	end
	if e.phase == "StalkObserved" then
		Attack.face(e, target)
		if now >= e.pauseUntil then Attack.walk(e, target, T.ObservedRetreatSpeedStudsPerSecond, -1, dt, world) end
	elseif e.phase == "CoverApproach" then
		local distance = Attack.distance(e, target)
		local clear = not world.lineOfSight or world.lineOfSight(e.pos, target) == true
		if now >= e.leapReadyAt and distance >= T.LeapMinDistanceStuds and distance <= T.LeapMaxDistanceStuds and clear then
			startLeap(events, e, now, target, world, C, T)
		elseif distance < T.LeapMinDistanceStuds then
			Attack.walk(e, target, T.ObservedRetreatSpeedStudsPerSecond, -1, dt, world)
		else
			-- Bursts: burstSeconds of movement, pauseSeconds still, repeated.
			local cycle = (now - e.burstAt) % (C.burstSeconds + C.pauseSeconds)
			if cycle < C.burstSeconds and distance > T.LeapMinDistanceStuds then
				Attack.walk(e, target, T.UnobservedApproachSpeedStudsPerSecond, 1, dt, world)
			else
				Attack.face(e, target)
			end
		end
	end
	if e.phase == "LeapWindup" then
		local attack = e.leap
		if now < e.leapAt then
			-- The landing spot follows the target until the windup ends.
			e.dest = { x = target.x, y = Attack.groundAt(world, target.x, target.z, target.y - 3), z = target.z }
			Attack.face(e, target)
			Attack.aim(events, e, attack, landingCircle(e.dest, C), now)
		else
			-- The spot is fixed now. A spot with no ground, in a safe zone, or far beyond the leap's reach (the target
			-- teleported) calls the leap off: no strike.
			local y = e.dest.y
			if world.landing then y = world.landing(e.dest.x, e.dest.z, e.dest.y) end
			local reach = Config.flat(e.pos.x, e.pos.z, e.dest.x, e.dest.z)
			if not finite(y) or reach > T.LeapMaxDistanceStuds + T.LeapOverrunDistanceStuds then
				Attack.drop(events, e, world, attack, e.leapAt, "NoLanding")
				e.leap, e.leapReadyAt = nil, now + 1
				stalk(events, e, now, T)
			else
				e.dest.y = y
				Attack.lock(events, e, attack, landingCircle(e.dest, C), e.leapAt)
				e.from = copy(e.pos)
				Attack.phase(events, e, "LeapCommit", e.leapAt, attack.strikeAt)
				emit(events, e, "Move", e.leapAt, { kind = "arc", from = copy(e.from), to = copy(e.dest),
					height = C.arcHeight, landAt = attack.strikeAt })
			end
		end
	end
	if e.phase == "LeapCommit" then
		local attack = e.leap
		local t = math.clamp((now - e.leapAt) / T.LeapTravelSeconds, 0, 1)
		e.pos.x, e.pos.y, e.pos.z = Config.arc(e.from.x, e.from.y, e.from.z, e.dest.x, e.dest.y, e.dest.z, C.arcHeight, t)
		if t >= 1 then
			local landAt = attack.strikeAt
			local result
			if Attack.inside(attack.shape, target, e.dest.y, C.hitHeight) then
				result = Attack.hit(events, e, world, attack, landAt)
			else
				result = Attack.miss(events, e, world, attack, landAt)
			end
			e.leap = nil
			e.leapReadyAt = landAt + T.LeapCooldownSeconds
			if result == "Dodged" then
				-- The overrun: it slides past the spot along the leap, stopping short of a wall or a safe zone.
				local dx, dz = unit(e.dest.x - e.from.x, e.dest.z - e.from.z)
				if dx then
					local ox, oz = e.dest.x + dx * T.LeapOverrunDistanceStuds, e.dest.z + dz * T.LeapOverrunDistanceStuds
					local oy = e.dest.y
					if world.landing then oy = world.landing(ox, oz, e.dest.y) end
					if finite(oy) then
						emit(events, e, "Move", landAt, { kind = "slide", from = copy(e.dest), to = { x = ox, y = oy, z = oz },
							untilAt = landAt + 0.3 })
						e.pos.x, e.pos.y, e.pos.z = ox, oy, oz
					end
				end
				e.stunUntil = landAt + T.PerfectDodgeStunSeconds
				Attack.phase(events, e, "OverrunStunned", landAt, e.stunUntil)
			else
				Attack.phase(events, e, "Land", landAt, landAt)
				stalk(events, e, landAt, T)
			end
		end
	end
	if e.phase == "OverrunStunned" and now >= e.stunUntil then
		stalk(events, e, e.stunUntil, T)
		if e.seen then e.pauseUntil = now + T.ObservedPauseSeconds end
	end
end

return Lurker
