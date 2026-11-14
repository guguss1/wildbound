-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Gaze, the watching eyes (pack 02_BESTIAS/GAZE). Server only
-- and pure, stepped by WildboundBeastEncounters through Enc.register. State machine (pack names):
--   Manifest (Fase 1: only the eyes, manifestSeconds, no damage) -> Watch / ExposureBuild (Fase 2: exposure grows by
--   1 per second while the target observes Gaze inside SightConeDegrees and MaxViewDistanceStuds with a clear server
--   line of sight; after SightBreakGraceSeconds without it, it decays by ExposureDecayPerSecond) -> ChargeZone (Fase 3,
--   at ExposureToAttackSeconds: a circle of ZoneRadiusStuds fixed on the target's spot, ZoneTelegraphSeconds, registered
--   with the perfect dodge; looking away no longer cancels it) -> Detonate (one check of the drawn circle, ZoneDamage)
--   -> Dissipate -> Reposition (only while unobserved, to a new spot 32 to 65 studs away) -> Watch ...
--   BreakLineOfSight (Fase 4): looking away or hiding before the charge cancels the build-up (a SightBreak event);
--   DisengageIfUnseenSeconds without being observed, or the timeout, ends it.
-- The observation is target.observe(point, halfAngle, maxDist, favour): the beast script's validated camera data
-- (WildboundBeastSight) plus its own raycast; favour is false here, so lag never builds exposure. It never deals damage
-- by itself. Every number is Config.BEASTS.Gaze (tuning = PROPUESTA DE BALANCE).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Gaze = {}

local finite = Config.finite
local copy, emit = Attack.copy, Attack.emit
Gaze.EXPOSURE_RATE = 0.1 -- the exposure meter is sent at most this often

function Gaze.init(e, now)
	e.exposure, e.lastSeenAt, e.exposureSentAt, e.sentExposure = 0, now, -math.huge, -1
	e.building = false
end

local function observed(e, target, T)
	if type(target.observe) ~= "function" then return false end
	local eyes = { x = e.pos.x, y = e.pos.y + Config.BEASTS.Gaze.eyeHeight, z = e.pos.z }
	return target.observe(eyes, T.SightConeDegrees, T.MaxViewDistanceStuds, false) == true
end

local function sendExposure(events, e, now, T, force)
	local value = math.clamp(e.exposure / T.ExposureToAttackSeconds, 0, 1)
	if force or (math.abs(value - e.sentExposure) > 0.02 and now - e.exposureSentAt >= Gaze.EXPOSURE_RATE) then
		e.sentExposure, e.exposureSentAt = value, now
		emit(events, e, "Exposure", now, { value = value })
	end
end

-- Exposure for this step. Returns true when the target observes Gaze now.
function Gaze.expose(e, now, dt, seen, T)
	if seen then
		e.lastSeenAt = now
		e.exposure += dt
	elseif now - e.lastSeenAt > T.SightBreakGraceSeconds then
		e.exposure = math.max(0, e.exposure - T.ExposureDecayPerSecond * dt)
	end
	return seen
end

local function startZone(events, e, now, target, world, C, T)
	local y = Attack.groundAt(world, target.x, target.z, target.y - 3)
	local strikeAt = now + T.ZoneTelegraphSeconds
	local attack = Attack.open(events, e, world, { key = "zone", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.ZoneDamage, shape = { kind = "circle", x = target.x, y = y, z = target.z, r = T.ZoneRadiusStuds } })
	if not attack then return false end
	attack.locked = true
	e.zone = attack
	e.exposure, e.building = 0, false
	sendExposure(events, e, now, T, true)
	Attack.phase(events, e, "ChargeZone", now, strikeAt)
	return true
end

function Gaze.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Gaze
	local T = C.tuning
	if Attack.guard(events, e, now, target, { timeout = T.EncounterTimeoutSeconds, busy = e.phase == "ChargeZone",
		disengage = C.disengage }) then return end

	if e.phase == "Spawn" then
		Attack.phase(events, e, "Manifest", e.phaseAt, e.phaseAt + C.manifestSeconds)
		e.lastSeenAt = e.phaseAt + C.manifestSeconds
	end
	if e.phase == "Manifest" then
		Attack.face(e, target)
		if now - e.phaseAt >= C.manifestSeconds then Attack.phase(events, e, "Watch", e.phaseAt + C.manifestSeconds) end
		return
	end
	local seen = (e.phase == "Watch" or e.phase == "ExposureBuild") and observed(e, target, T)
	if e.phase == "Watch" or e.phase == "ExposureBuild" then
		Attack.face(e, target)
		Gaze.expose(e, now, dt, seen, T)
		if e.exposure > 0 and e.phase == "Watch" then
			e.building = true
			Attack.phase(events, e, "ExposureBuild", now)
		elseif e.exposure <= 0 and e.phase == "ExposureBuild" then
			-- Fase 4: the link broke before the charge; the build-up is cancelled.
			e.building = false
			emit(events, e, "SightBreak", now)
			Attack.phase(events, e, "Watch", now)
		end
		sendExposure(events, e, now, T, false)
		if e.exposure >= T.ExposureToAttackSeconds then
			if not startZone(events, e, now, target, world, C, T) then
				e.exposure = T.ExposureToAttackSeconds -- staggered: hold at the threshold and try on the next step
			end
		elseif not seen and now - e.lastSeenAt >= T.DisengageIfUnseenSeconds then
			Attack.disengage(events, e, "Unseen", now, C.disengage)
			return
		elseif not seen and e.exposure <= 0 and Attack.distance(e, target) > T.MaxViewDistanceStuds
			and now >= (e.nextReposition or -math.huge) then
			-- Out of view range and unobserved: reappear behind other cover in range (at most once a second).
			e.nextReposition = now + 1
			local spot = world.reposition and world.reposition(e, target)
			if spot then
				emit(events, e, "Move", now, { kind = "blink", from = copy(e.pos), to = copy(spot) })
				e.pos.x, e.pos.y, e.pos.z = spot.x, spot.y, spot.z
			end
		end
	end
	if e.phase == "ChargeZone" and now >= e.zone.strikeAt then
		local attack = e.zone
		if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
			Attack.hit(events, e, world, attack, attack.strikeAt)
		else
			Attack.miss(events, e, world, attack, attack.strikeAt)
		end
		e.zone = nil
		Attack.phase(events, e, "Dissipate", attack.strikeAt, attack.strikeAt + C.dissipateSeconds)
	end
	if e.phase == "Dissipate" and now - e.phaseAt >= C.dissipateSeconds then
		local at = e.phaseAt + C.dissipateSeconds
		local seenNow = observed(e, target, T)
		local distance = Attack.distance(e, target)
		if not seenNow and (distance > T.MaxSpawnDistanceStuds or distance < T.MinSpawnDistanceStuds) and world.reposition then
			local spot = world.reposition(e, target)
			if spot then
				emit(events, e, "Move", at, { kind = "blink", from = copy(e.pos), to = copy(spot) })
				e.pos.x, e.pos.y, e.pos.z = spot.x, spot.y, spot.z
			end
		end
		e.lastSeenAt = at
		Attack.phase(events, e, "Watch", at)
	end
	if not finite(e.exposure) then e.exposure = 0 end
end

return Gaze
