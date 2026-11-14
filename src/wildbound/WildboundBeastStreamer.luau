-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Streamer, the screaming rusher (pack 02_BESTIAS/STREAMER).
-- Server only and pure, stepped by WildboundBeastEncounters through Enc.register. State machine (pack names):
--   Spawn -> Dormant (walks in until the target is within AggroRadius with a clear line of sight)
--   -> Warn (WarningSeconds, no damage, target fixed) -> ScreamCharge (ScreamWindupSeconds, the ring shows the real radius)
--   -> ScreamPulse (one radial hit, ScreamDamage and a light push, once per target) -> Pursue (WalkSpeed)
--   -> RushTelegraph (the lane follows the target until lockLead before the commit, then never moves; registered with
--      the perfect dodge) -> RushCommit (a straight swept lane at RushSpeed, at most RushMaxRange, cut at a wall; no
--      homing) -> Recovery (RushMissRecoverySeconds) or Stunned (PerfectDodgeStunSeconds, when a validated perfect dodge
--      held the window at the moment of contact) -> Pursue ... -> Disengage (escape, timeout) -> End.
-- Authority: the server for every transition; the client only draws Phase and Tell events. Cleanup: an attack still
-- open at the end is cancelled by the beast script (WildboundBeastAttack.closeAll); nothing physical exists on the
-- server. Every number is Config.BEASTS.Streamer (tuning = PROPUESTA DE BALANCE).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Streamer = {}

local finite, unit = Config.finite, Config.unit
local copy, emit = Attack.copy, Attack.emit

function Streamer.init(e)
	e.rushReadyAt = -math.huge
end

local function lineOfSight(world, e, target)
	if not world.lineOfSight then return true end
	return world.lineOfSight(e.pos, target) == true
end

local function laneShape(e, C)
	return { kind = "lane", ox = e.origin.x, oy = e.origin.y, oz = e.origin.z, dx = e.dx, dz = e.dz,
		length = e.length, width = C.laneWidth }
end

local function startScream(events, e, now, C, T)
	Attack.phase(events, e, "ScreamCharge", now, now + T.ScreamWindupSeconds)
	-- The ring is drawn from the charge's start at the real radius; it is not dodgeable (0.75 s is under the 0.8 s
	-- dodge floor): the warning plus the charge (1.75 s) is the time to step out, as the pack asks.
	e.scream = Attack.open(events, e, {}, { key = "scream", startAt = now, strikeAt = now + T.ScreamWindupSeconds,
		dodgeable = false, damage = T.ScreamDamage,
		shape = { kind = "circle", x = e.pos.x, y = e.pos.y, z = e.pos.z, r = T.ScreamRadiusStuds } })
end

local function startRush(events, e, now, target, world, C, T)
	local opened = { x = e.pos.x, y = e.pos.y, z = e.pos.z }
	local dx, dz = unit(target.x - opened.x, target.z - opened.z)
	if dx then e.dx, e.dz = dx, dz end
	local distance = math.min(Attack.distance(e, target), T.RushMaxRangeStuds)
	local commitAt = now + T.RushTelegraphSeconds
	-- The dodge's strike instant: the commit plus the time the head needs to reach the target's distance.
	local strikeAt = commitAt + distance / T.RushSpeedStudsPerSecond
	e.origin, e.length = opened, T.RushMaxRangeStuds
	local attack = Attack.open(events, e, world, { key = "rush", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.RushDamage, lockAt = commitAt - C.lockLead, shape = laneShape(e, C) })
	if not attack then return false end
	e.rush, e.commitAt, e.lockAt, e.swept, e.crashed = attack, commitAt, commitAt - C.lockLead, 0, false
	Attack.phase(events, e, "RushTelegraph", now, commitAt)
	return true
end

function Streamer.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Streamer
	local T = C.tuning
	local busy = e.phase == "RushCommit" or e.phase == "ScreamCharge" or e.phase == "RushTelegraph"
	if Attack.guard(events, e, now, target, { timeout = T.EncounterTimeoutSeconds, escapeDistance = C.escapeDistance,
		escapeSeconds = C.escapeSeconds, busy = busy, disengage = C.disengage }) then return end

	if e.phase == "Spawn" and now - e.phaseAt >= C.spawnSeconds then
		Attack.phase(events, e, "Dormant", e.phaseAt + C.spawnSeconds)
	end
	if e.phase == "Dormant" then
		-- Fase 1 trigger: inside the aggro radius with a clear line; until then it walks in, no damage.
		local distance = Attack.distance(e, target)
		if distance <= T.AggroRadiusStuds and lineOfSight(world, e, target) then
			Attack.face(e, target)
			Attack.phase(events, e, "Warn", now, now + T.WarningSeconds)
		else
			Attack.walk(e, target, T.WalkSpeedStudsPerSecond, 1, dt, world)
		end
	end
	if e.phase == "Warn" then
		Attack.face(e, target)
		if now - e.phaseAt >= T.WarningSeconds then startScream(events, e, e.phaseAt + T.WarningSeconds, C, T) end
	end
	if e.phase == "ScreamCharge" and e.scream and now >= e.scream.strikeAt then
		-- Fase 2: one radial check at the pulse, against the ring that was drawn.
		local attack = e.scream
		local at = attack.strikeAt
		if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
			local kx, kz = unit(target.x - attack.shape.x, target.z - attack.shape.z)
			Attack.hit(events, e, world, attack, at, { knock = { dx = kx or e.dx, dz = kz or e.dz,
				speed = T.ScreamKnockbackStudsPerSecond } })
		else
			Attack.miss(events, e, world, attack, at)
		end
		e.scream = nil
		-- The first rush waits one recovery after the pulse, so the push never chains into a rush.
		e.rushReadyAt = at + T.RushMissRecoverySeconds
		Attack.phase(events, e, "Pursue", at)
	end
	if e.phase == "Pursue" then
		local distance = Attack.distance(e, target)
		if now >= e.rushReadyAt and distance <= T.RushMaxRangeStuds and lineOfSight(world, e, target) then
			if not startRush(events, e, now, target, world, C, T) then Attack.face(e, target) end
		elseif distance > T.ScreamRadiusStuds then
			-- It closes in at a trot but stops at its scream radius (PROPUESTA): the rush needs a lane to read.
			Attack.walk(e, target, T.WalkSpeedStudsPerSecond, 1, dt, world)
		else
			Attack.face(e, target)
		end
	end
	if e.phase == "RushTelegraph" then
		local attack = e.rush
		if now < e.lockAt then
			-- The lane follows the target until the lock (never in the last lockLead seconds).
			local dx, dz = unit(target.x - e.origin.x, target.z - e.origin.z)
			if dx then e.dx, e.dz = dx, dz end
			Attack.aim(events, e, attack, laneShape(e, C), now)
		elseif not attack.locked then
			local wall = world.castLane and world.castLane(e.origin.x, e.origin.y, e.origin.z, e.dx, e.dz, T.RushMaxRangeStuds)
			if finite(wall) and wall < T.RushMaxRangeStuds then e.length, e.crashed = math.max(0, wall - 0.5), true end
			Attack.lock(events, e, attack, laneShape(e, C), e.lockAt)
		end
		if attack.locked and now >= e.commitAt then
			Attack.phase(events, e, "RushCommit", e.commitAt, e.commitAt + e.length / T.RushSpeedStudsPerSecond)
			emit(events, e, "Move", e.commitAt, { kind = "dash", from = copy(e.origin), dx = e.dx, dz = e.dz,
				speed = T.RushSpeedStudsPerSecond, length = e.length })
		end
	end
	if e.phase == "RushCommit" then
		local attack = e.rush
		local travelled = math.min(e.length, (now - e.commitAt) * T.RushSpeedStudsPerSecond)
		e.pos.x, e.pos.z = e.origin.x + e.dx * travelled, e.origin.z + e.dz * travelled
		e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
		-- Swept volume: the part of the drawn lane the head crossed since the last step. One outcome per rush.
		if not attack.done and math.abs(target.y - e.pos.y) <= C.hitHeight
			and Config.inLane(target.x, target.z, e.origin.x, e.origin.z, e.dx, e.dz, e.swept, travelled, C.laneWidth) then
			e.rushResult = Attack.hit(events, e, world, attack, now)
		end
		e.swept = travelled
		if travelled >= e.length - 1e-9 then
			local endAt = e.commitAt + e.length / T.RushSpeedStudsPerSecond
			if not attack.done then e.rushResult = Attack.miss(events, e, world, attack, endAt) end
			e.rushReadyAt = e.commitAt + T.RushCooldownSeconds
			if e.rushResult == "Dodged" then
				-- Fase 4: a validated perfect dodge at the contact: the long stun.
				Attack.phase(events, e, "Stunned", endAt, endAt + T.PerfectDodgeStunSeconds, { crashed = e.crashed })
				e.recoverUntil = endAt + T.PerfectDodgeStunSeconds
			else
				Attack.phase(events, e, "Recovery", endAt, endAt + T.RushMissRecoverySeconds, { crashed = e.crashed })
				e.recoverUntil = endAt + T.RushMissRecoverySeconds
			end
			e.rush, e.rushResult = nil, nil
		end
	end
	if (e.phase == "Recovery" or e.phase == "Stunned") and now >= e.recoverUntil then
		Attack.phase(events, e, "Pursue", e.recoverUntil)
	end
end

return Streamer
