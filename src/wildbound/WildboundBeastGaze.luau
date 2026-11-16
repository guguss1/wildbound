-- Beast revision BR5 (odd/tasks/wildbound-beast-revision.md, owner 2026-11-16): Gaze, the big black watcher. Server
-- only and pure, stepped by WildboundBeastEncounters through Enc.register. State machine:
--   Spawn -> Manifest (manifestSeconds: it can be found, nothing counts yet) -> Watch / ExposureBuild:
--   while the target really looks at it (target.observe: the validated camera direction inside SightConeDegrees and
--   MaxViewDistanceStuds, AND the server's own raycast line of sight, so walls and opaque cover block it; favour false,
--   so lag never counts) the exposure grows by dt; looking away PAUSES it (it never decays, never resets) and the phase
--   goes back to Watch. Exposure events (0..1, `paused`) drive the client's progressive warning.
--   At killSeconds of ACCUMULATED exposure: one Hit with killDamage (100, the BeastHit maximum; MaxHealth is 100) and
--   `kill`, exactly once per encounter (e.killed). The defeat goes through the game's one strike path (WildboundServer
--   BeastHit): health only drops where damage is allowed (the private test place and a lethal player); elsewhere it
--   knocks the carried egg out. A spent Gaze keeps watching and never strikes again in that encounter.
-- Persistent chase (WildboundBeastChase): no Unseen or Timeout exit; out of view range and unobserved it reappears
-- within range (world.reposition, never in a safe zone) at most every repositionSeconds. The exposure lives on the
-- encounter, so it starts at 0 in every new encounter (death, a safe zone and a respawn all end the encounter).
-- Every number is Config.BEASTS.Gaze (the BR5 fields; the pack's zone attack in `tuning` is no longer used).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Gaze = {}

local finite = Config.finite
local copy, emit = Attack.copy, Attack.emit
Gaze.EXPOSURE_RATE = 0.1 -- the exposure meter is sent at most this often while it changes

function Gaze.init(e, now)
	e.exposure, e.exposureSentAt, e.sentExposure, e.sentPaused = 0, -math.huge, -1, nil
	e.killed, e.nextReposition = false, -math.huge
end

local function observed(e, target, T)
	if type(target.observe) ~= "function" then return false end
	local eyes = { x = e.pos.x, y = e.pos.y + Config.BEASTS.Gaze.eyeHeight, z = e.pos.z }
	return target.observe(eyes, T.SightConeDegrees, T.MaxViewDistanceStuds, false) == true
end

local function sendExposure(events, e, now, C, paused, force)
	local value = math.clamp(e.exposure / C.killSeconds, 0, 1)
	local changed = math.abs(value - e.sentExposure) > 0.02 and now - e.exposureSentAt >= Gaze.EXPOSURE_RATE
	if force or changed or paused ~= e.sentPaused then
		e.sentExposure, e.exposureSentAt, e.sentPaused = value, now, paused
		emit(events, e, "Exposure", now, { value = value, paused = paused })
	end
end

-- Exposure for this step: accumulates while seen, holds otherwise. Returns the new total.
function Gaze.expose(e, dt, seen)
	if seen and not e.killed then e.exposure += dt end
	return e.exposure
end

function Gaze.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Gaze
	local T = C.tuning
	if Attack.guard(events, e, now, target, { disengage = C.disengage }) then return end

	if e.phase == "Spawn" then
		Attack.phase(events, e, "Manifest", e.phaseAt, e.phaseAt + C.manifestSeconds)
	end
	if e.phase == "Manifest" then
		Attack.face(e, target)
		if now - e.phaseAt >= C.manifestSeconds then Attack.phase(events, e, "Watch", e.phaseAt + C.manifestSeconds) end
		return
	end
	Attack.face(e, target)
	local seen = not e.killed and observed(e, target, T)
	Gaze.expose(e, dt, seen)
	if seen and e.phase == "Watch" then
		Attack.phase(events, e, "ExposureBuild", now)
	elseif not seen and e.phase == "ExposureBuild" then
		emit(events, e, "SightBreak", now) -- the count pauses (never resets)
		Attack.phase(events, e, "Watch", now)
	end
	if not e.killed and e.exposure >= C.killSeconds - 1e-9 then
		e.killed, e.exposure = true, C.killSeconds
		sendExposure(events, e, now, C, false, true)
		Attack.phase(events, e, "Kill", now)
		emit(events, e, "Hit", now, { damage = C.killDamage, attack = e.id .. ":gaze", kill = true })
		return -- spent: it stays in Kill (watching, never striking again) for the rest of the encounter
	end
	if not e.killed then sendExposure(events, e, now, C, not seen, false) end
	if not seen and Attack.distance(e, target) > T.MaxViewDistanceStuds and now >= e.nextReposition then
		-- Persistent: out of view range and unobserved, it reappears within range behind other cover.
		e.nextReposition = now + C.repositionSeconds
		local spot = world.reposition and world.reposition(e, target)
		if spot then
			emit(events, e, "Move", now, { kind = "blink", from = copy(e.pos), to = copy(spot) })
			e.pos.x, e.pos.y, e.pos.z = spot.x, spot.y, spot.z
		end
	end
	if not finite(e.exposure) then e.exposure = 0 end
end

return Gaze
