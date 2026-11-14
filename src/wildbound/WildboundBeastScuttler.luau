-- Scuttler (docs/design/wildbound-scuttler-plan.md, SC3; odd/tasks/wildbound-scuttler.md): the global threat-3 insect
-- that reads the player. Server only and pure, stepped by WildboundBeastEncounters through Enc.register. This is the
-- brain with the feint (SC4), the route intercept (SC5) and the panic pulse (SC6).
-- State machine:
--   Spawn (spawnSeconds, the rise) -> Stalk (keeps StalkMin..StalkMax studs, faces the target)
--   -> [FeintTell (Finta de caza, FeintSeconds: a lane drawn like a real one, feint = true, never registered with the
--      dodge, never a strike or a hit, the body holds still). A press inside the feint (world.lastDash, the server
--      attribute WildboundDash) is the bait: PunishTell at once, re-aimed, PunishTelegraphSeconds. No press: ChargeTell.]
--   -> ChargeTell (ChargeTelegraphSeconds; the lane follows the target until lockLead before the commit, then never
--      moves; registered with the perfect dodge) or PunishTell (the same, shorter) -> Charge (a straight swept lane at
--      ChargeSpeed, at most ChargeMaxRangeStuds, cut at a wall; no homing)
--   -> Recovery (ChargeMissRecoverySeconds, the charge landed or missed) or Fallen (Castigo y caida: a validated
--      perfect dodge held the window at contact; it overruns OverrunStuds along the same line, then stumbles for
--      FallStumbleSeconds, or crashes for FallCrashSeconds when a wall stops the overrun or cut the lane) -> Stalk
--   -> [Read (Ruta predictiva, ReadSeconds: it stops and reads the target's flat velocity; only after the first
--      charge, never twice in a row, and only while the target moves faster than InterceptMinSpeed) -> Intercept (the
--      predicted point P = target + v * PredictSeconds, at most InterceptMaxStuds ahead, on valid ground, outside every
--      safe zone and in sight; committed only when it arrives first: ETA(Scuttler) + InterceptMarginSeconds <
--      ETA(target). It runs straight to P at InterceptSpeed, below a rested sprint; the zone, a circle of SnapRadius at
--      P, is drawn from the phase's start) -> Block (BlockSeconds at P, facing the target; a target inside the zone
--      opens a Snap, a registered sector swipe, never before the zone was drawn MIN_TELL) -> Stalk. A point it cannot
--      win falls back to the pursuit (Stalk with fallback = "Pursue"). A press (world.lastDash) during Read is read at
--      the choice and uses the one re-plan; a press during Intercept re-plans once with the new velocity, no sooner
--      than ReplanCooldownSeconds after the plan (MaxReplans per intercept); a re-plan it cannot win falls back.]
--   -> [PulseCharge (Pulso de panico, PulseChargeSeconds: only after the first charge, once the pulse is ready and the
--      target is within PulseRadiusStuds + 4; the ring, a circle of PulseRadiusStuds at Scuttler, is drawn, registered
--      with the perfect dodge and fixed from the charge start; the body holds still) -> Pulse (the release: one radial
--      check against the drawn ring. Outside: nothing. Inside: Afflict, a slow and a shake, never damage. A second
--      landed pulse inside PressureMemorySeconds while the target carries an egg is a damage-0 Hit instead, the one egg
--      drop path, when PulseCanDropEgg is on) -> Stalk. A perfect press cancels it (no slow, no pressure, no fall).]
--   -> Disengage (Escape, Timeout, Outplayed once FallsToGiveUp falls ended, or EggDropped right after any landed hit
--      on an egg carrier: the charge, the Snap or the escalated pulse, or Silueta (SC7) once the player's own Silueta
--      hunts and no attack is open) -> End.
-- Authority: the server for every transition; the client only draws Phase, Tell and Move events. While Fallen nothing
-- is open (the charge settled before the fall) and no attack opens. Cleanup: an attack still open at the end is
-- cancelled by the beast script (WildboundBeastAttack.closeAll). Every number is Config.BEASTS.Scuttler (PROPUESTA).
-- Feint limits: the first charge of an encounter is never a feint, never two feints in a row, a feint only when
-- world.random() < FeintChance (no world.random: never), and at most MaxFeintsWhileEgg feints per encounter while the
-- target carries an egg (target.carryingEgg). A feint is not an open attack, so closeAll has nothing to cancel.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Scuttler = {}

local finite, unit = Config.finite, Config.unit
local copy, emit = Attack.copy, Attack.emit
local PULSE_RELEASE_SECONDS = 0.5 -- the scream release (phase "Pulse"): it holds still, then stalks again

function Scuttler.init(e)
	e.chargeReadyAt = -math.huge -- the first move is a plain committed charge (plan section 4)
	e.falls = 0
	e.charges, e.feints, e.eggFeints, e.lastFeint = 0, 0, 0, false
	e.lastRead, e.reads, e.replans = false, 0, 0
	e.pulseReadyAt, e.pulses, e.lastPulseAt = -math.huge, 0, nil
	-- The egg switch (Q2), copied per encounter from Config so a case can turn it off without touching the frozen table.
	e.pulseCanDropEgg = Config.BEASTS.Scuttler.tuning.PulseCanDropEgg == true
end

local function lineOfSight(world, e, target)
	if not world.lineOfSight then return true end
	return world.lineOfSight(e.pos, target) == true
end

local function laneShape(e, C)
	return { kind = "lane", ox = e.origin.x, oy = e.origin.y, oz = e.origin.z, dx = e.dx, dz = e.dz,
		length = e.length, width = C.laneWidth }
end

-- Opens a real charge toward the target: phase "ChargeTell" (committed, ChargeTelegraphSeconds) or "PunishTell" (the
-- bait was taken, PunishTelegraphSeconds). Returns false when the strike slot is taken (Stagger): stay in Stalk.
local function startCharge(events, e, now, target, world, C, T, phase)
	phase = phase or "ChargeTell"
	local opened = copy(e.pos)
	local dx, dz = unit(target.x - opened.x, target.z - opened.z)
	if dx then e.dx, e.dz = dx, dz end
	local distance = math.min(Attack.distance(e, target), T.ChargeMaxRangeStuds)
	local commitAt = now + (phase == "PunishTell" and T.PunishTelegraphSeconds or T.ChargeTelegraphSeconds)
	-- The dodge's strike instant: the commit plus the time the head needs to reach the target's distance.
	local strikeAt = commitAt + distance / T.ChargeSpeed
	e.origin, e.length = opened, T.ChargeMaxRangeStuds
	local attack = Attack.open(events, e, world, { key = "charge", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.ChargeDamage, lockAt = commitAt - C.lockLead, shape = laneShape(e, C) })
	if not attack then return false end
	e.charge, e.commitAt, e.lockAt, e.swept, e.crashed = attack, commitAt, commitAt - C.lockLead, 0, false
	e.charges += 1
	e.lastFeint, e.lastRead = false, false
	Attack.phase(events, e, phase, now, commitAt)
	return true
end

-- Whether the next charge is a feint. The roll is asked only when every limit allows one.
local function wantsFeint(e, target, world, T)
	if e.charges < 1 or e.lastFeint or not world.random then return false end
	if target.carryingEgg == true and e.eggFeints >= T.MaxFeintsWhileEgg then return false end
	local roll = world.random()
	return finite(roll) and roll < T.FeintChance
end

local function feintShape(e, target, C, T)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if dx then e.dx, e.dz = dx, dz end
	return { kind = "lane", ox = e.pos.x, oy = e.pos.y, oz = e.pos.z, dx = e.dx, dz = e.dz,
		length = T.ChargeMaxRangeStuds, width = C.laneWidth }
end

-- Finta de caza: a lane drawn like a real charge's, never registered with the dodge (no world.telegraph, no strike
-- slot), not an open attack, never a strike or a hit. The client draws a Tell with feint = true as an outline.
local function startFeint(events, e, now, target, C, T)
	e.feints += 1
	if target.carryingEgg == true then e.eggFeints += 1 end
	e.lastFeint, e.lastRead = true, false
	local id = ("%s:feint:%d"):format(e.id, e.feints)
	e.feint = { id = id, startAt = now, endAt = now + T.FeintSeconds, sentAt = now }
	Attack.phase(events, e, "FeintTell", now, e.feint.endAt)
	emit(events, e, "Tell", now, { tell = id, shape = feintShape(e, target, C, T), startAt = now,
		strikeAt = e.feint.endAt, dodgeable = false, feint = true, locked = false })
end

-- The bait check: a validated press (server attribute WildboundDash) inside [feint start, now].
local function baitTaken(e, world, now)
	local dash = world.lastDash and world.lastDash()
	return finite(dash) and dash >= e.feint.startAt - 1e-9 and dash <= now + 1e-9
end

-- Ruta predictiva. The target's flat speed (server velocity); a route worth reading is faster than InterceptMinSpeed.
local function speedOf(target)
	local vx, vz = target.vx, target.vz
	if not finite(vx) or not finite(vz) then return 0 end
	return math.sqrt(vx * vx + vz * vz)
end

local function wantsRead(e, target, T)
	return e.charges >= 1 and not e.lastRead and speedOf(target) > T.InterceptMinSpeed
end

-- A validated press (server attribute WildboundDash) inside [from, now], or nil.
local function pressedSince(world, from, now)
	local dash = world.lastDash and world.lastDash()
	if finite(dash) and dash >= from - 1e-9 and dash <= now + 1e-9 then return dash end
	return nil
end

-- Whether the straight run from Scuttler to P stays on open ground: no sample every PATH_STEP studs (P included) in a
-- safe zone (world.safe) or the Pradera (world.meadow, optional), and no wall across it (world.castLane).
local PATH_STEP = 2
local function pathClear(e, point, world)
	local fx, fz = e.pos.x, e.pos.z
	local length = Config.flat(fx, fz, point.x, point.z)
	local steps = math.max(1, math.ceil(length / PATH_STEP))
	for i = 1, steps do
		local k = i / steps
		local x, z = fx + (point.x - fx) * k, fz + (point.z - fz) * k
		if world.safe and world.safe(x, z) == true then return false end
		if world.meadow and world.meadow(x, z) == true then return false end
	end
	local dx, dz = unit(point.x - fx, point.z - fz)
	if dx and world.castLane then
		local wall = world.castLane(fx, e.pos.y, fz, dx, dz, length)
		if finite(wall) and wall < length - 1e-6 then return false end
	end
	return true
end

-- The predicted point and whether Scuttler wins the race to it. Returns P, eta (Scuttler), targetEta, or nil when P is
-- a void, a safe zone, out of sight, behind a safe zone, the Pradera or a wall on the straight run, or a race it loses
-- (no secret shortcut: it falls back to the pursuit).
local function choosePoint(e, target, world, T)
	local speed = speedOf(target)
	if speed <= 1e-6 then return nil end
	local lead = math.min(speed * T.PredictSeconds, T.InterceptMaxStuds)
	local px, pz = target.x + target.vx / speed * lead, target.z + target.vz / speed * lead
	if world.safe and world.safe(px, pz) == true then return nil end
	local py = Attack.groundAt(world, px, pz, e.pos.y)
	if world.landing then
		py = world.landing(px, pz, e.pos.y)
		if not finite(py) then return nil end
	end
	local point = { x = px, y = py, z = pz }
	if world.lineOfSight and world.lineOfSight(e.pos, point) ~= true then return nil end
	if not pathClear(e, point, world) then return nil end
	local eta = Config.flat(e.pos.x, e.pos.z, px, pz) / T.InterceptSpeed
	local targetEta = lead / speed
	if not (eta + T.InterceptMarginSeconds < targetEta) then return nil end
	return point, eta, targetEta
end

local function endZone(events, e, at, reason)
	if not e.zone then return end
	emit(events, e, "TellEnd", at, { tell = e.zone.id, reason = reason })
	e.zone = nil
end

local function startRead(events, e, now, T)
	e.reads += 1
	e.lastRead, e.replans, e.pressAt = true, 0, nil
	e.readUntil = now + T.ReadSeconds
	Attack.phase(events, e, "Read", now, e.readUntil)
end

local function pursue(events, e, now)
	Attack.phase(events, e, "Stalk", now, nil, { fallback = "Pursue" })
end

-- Commits the intercept to P: the zone (a circle at P, drawn from now, never an attack) and the straight run.
local function startIntercept(events, e, now, point, eta, targetEta, replan, T)
	e.interceptFrom, e.interceptTo = copy(e.pos), point
	e.planAt, e.arriveAt = now, now + eta
	local dx, dz = unit(point.x - e.pos.x, point.z - e.pos.z)
	if dx then e.dx, e.dz = dx, dz end
	local zoneId = ("%s:zone:%d:%d"):format(e.id, e.reads, e.replans)
	e.zone = { id = zoneId, startAt = now, shape = { kind = "circle", x = point.x, y = point.y, z = point.z, r = T.SnapRadius } }
	Attack.phase(events, e, "Intercept", now, e.arriveAt, { to = copy(point), eta = eta, targetEta = targetEta,
		replan = replan == true })
	emit(events, e, "Tell", now, { tell = zoneId, shape = e.zone.shape, startAt = now, strikeAt = now + Config.MIN_TELL,
		dodgeable = false, zone = true, locked = true })
	emit(events, e, "Move", now, { kind = "run", from = copy(e.pos), to = copy(point), speed = T.InterceptSpeed,
		untilAt = e.arriveAt })
end

-- The Snap: a sector swipe from P toward the target, fixed when drawn, registered with the perfect dodge.
local function startSnap(events, e, now, target, world, T)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if dx then e.dx, e.dz = dx, dz end
	local strikeAt = now + T.SnapTelegraphSeconds
	local attack = Attack.open(events, e, world, { key = "snap", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.SnapDamage, lockAt = now, shape = { kind = "sector", x = e.pos.x, y = e.pos.y, z = e.pos.z, dx = e.dx,
			dz = e.dz, r = T.SnapRadius, arc = T.SnapArc } })
	if not attack then return false end
	Attack.lock(events, e, attack, nil, now)
	e.snap = attack
	Attack.phase(events, e, "Snap", now, strikeAt)
	return true
end

-- Pulso de panico: after the first charge, once ready, with the target close enough to be caught by the ring.
local function wantsPulse(e, now, distance, T)
	return e.charges >= 1 and now >= e.pulseReadyAt - 1e-9 and distance < T.PulseRadiusStuds + 4 - 1e-6
end

-- The ring: a circle of PulseRadiusStuds at Scuttler, drawn, registered with the perfect dodge and fixed from now.
local function startPulse(events, e, now, world, T)
	local strikeAt = now + T.PulseChargeSeconds
	local attack = Attack.open(events, e, world, { key = "pulse", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = 0, lockAt = now, shape = { kind = "circle", x = e.pos.x, y = e.pos.y, z = e.pos.z, r = T.PulseRadiusStuds } })
	if not attack then return false end
	Attack.lock(events, e, attack, nil, now)
	e.pulse = attack
	e.pulses += 1
	e.lastRead = false
	Attack.phase(events, e, "PulseCharge", now, strikeAt, { r = T.PulseRadiusStuds })
	return true
end

-- The release: one check against the drawn ring. Returns true when it knocked a carried egg loose.
local function releasePulse(events, e, target, world, C, T)
	local attack = e.pulse
	local at = attack.strikeAt
	e.pulse = nil
	e.pulseReadyAt = at + T.PulseCooldownSeconds
	if not Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
		Attack.miss(events, e, world, attack, at)
		return false
	end
	local fields = { pulse = true, slow = T.PulseSlowMultiplier, slowSeconds = T.PulseSlowSeconds, shake = true }
	-- "Si ya estabas en mal estado": already pulsed inside PressureMemorySeconds.
	local pressured = e.lastPulseAt ~= nil and at - e.lastPulseAt <= T.PressureMemorySeconds + 1e-9
	local result
	if pressured and e.pulseCanDropEgg and target.carryingEgg == true then
		-- The Hit form of the same slow: the beast script's landHit applies only a table (as for Root's trap).
		fields.escalated = true
		fields.slow, fields.slowSeconds = { multiplier = T.PulseSlowMultiplier, seconds = T.PulseSlowSeconds }, nil
		result = Attack.hit(events, e, world, attack, at, fields) -- damage 0: the one egg drop path (BeastHit)
	else
		result = Attack.afflict(events, e, world, attack, at, fields)
	end
	if result ~= "Dodged" then e.lastPulseAt = at end
	return result == "Hit"
end

-- Castigo y caida: the dodged charge runs on past its lane's end. A wall inside the overrun (or one that already cut
-- the lane) makes it a crash; open ground, a stumble.
local function startFall(events, e, endAt, world, T)
	local from = { x = e.origin.x + e.dx * e.length, y = e.pos.y, z = e.origin.z + e.dz * e.length }
	local overrun, crash = T.OverrunStuds, e.crashed
	if crash then
		overrun = 0
	else
		local wall = world.castLane and world.castLane(from.x, from.y, from.z, e.dx, e.dz, T.OverrunStuds)
		if finite(wall) and wall < T.OverrunStuds then overrun, crash = math.max(0, wall - 0.5), true end
	end
	local slide = overrun / T.ChargeSpeed
	local seconds = crash and T.FallCrashSeconds or T.FallStumbleSeconds
	e.falls += 1
	e.fallFrom, e.fallAt, e.overrun = from, endAt, overrun
	e.recoverUntil = endAt + slide + seconds
	Attack.phase(events, e, "Fallen", endAt, e.recoverUntil, { fall = crash and "Crash" or "Stumble", crashed = crash,
		overrun = overrun, falls = e.falls })
	if overrun > 0 then
		emit(events, e, "Move", endAt, { kind = "dash", from = copy(from), dx = e.dx, dz = e.dz, speed = T.ChargeSpeed,
			length = overrun })
	end
end

function Scuttler.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Scuttler
	local T = C.tuning
	local busy = e.phase == "FeintTell" or e.phase == "ChargeTell" or e.phase == "PunishTell" or e.phase == "Charge"
		or e.phase == "Snap" or e.phase == "PulseCharge"
	if Attack.guard(events, e, now, target, { timeout = T.EncounterTimeoutSeconds, escapeDistance = C.escapeDistance,
		escapeSeconds = C.escapeSeconds, busy = busy, disengage = C.disengage }) then
		endZone(events, e, now, "End") -- the intercept zone goes away with the encounter (it is never an open attack)
		return
	end
	-- SC7 (plan section 7 rule 6): the player's own Silueta hunts or telegraphs (target.siluetaActive, from the beast
	-- script). No new attack opens; an open one (busy) resolves first, then the zone goes and Scuttler retreats.
	if target.siluetaActive == true and not busy then
		endZone(events, e, now, "Silueta")
		Attack.disengage(events, e, "Silueta", now, C.disengage)
		return
	end

	if e.phase == "Spawn" and now - e.phaseAt >= C.spawnSeconds then
		Attack.phase(events, e, "Stalk", e.phaseAt + C.spawnSeconds)
	end
	if e.phase == "Stalk" then
		local distance = Attack.distance(e, target)
		local ready = now >= e.chargeReadyAt and distance <= T.ChargeMaxRangeStuds and lineOfSight(world, e, target)
		if e.plan == "Pulse" and not (ready and wantsPulse(e, now, distance, T)) then e.plan = nil end -- out of reach
		if ready and e.plan == nil then
			-- One roll per move: a staggered charge keeps its choice while it waits for the strike slot. A close target
			-- is pulsed first (Pulso de panico); a running one (after the first charge, never two reads in a row) is
			-- read next (Ruta predictiva).
			if wantsPulse(e, now, distance, T) then
				e.plan = "Pulse"
			elseif wantsRead(e, target, T) then
				e.plan = "Read"
			else
				e.plan = wantsFeint(e, target, world, T) and "Feint" or "Charge"
			end
		end
		if ready and e.plan == "Pulse" then
			if startPulse(events, e, now, world, T) then e.plan = nil end -- staggered: it keeps the plan and holds
		elseif ready and e.plan == "Read" then
			e.plan = nil
			startRead(events, e, now, T)
		elseif ready and e.plan == "Feint" then
			e.plan = nil
			startFeint(events, e, now, target, C, T)
		elseif ready and e.plan ~= "Pulse" and startCharge(events, e, now, target, world, C, T) then
			e.plan = nil -- the charge is open; nothing else this step
		elseif distance > T.StalkMax then
			Attack.walk(e, target, T.StalkSpeed, 1, math.min(dt, (distance - T.StalkMax) / T.StalkSpeed), world)
		elseif distance < T.StalkMin then
			Attack.walk(e, target, T.StalkSpeed, -1, math.min(dt, (T.StalkMin - distance) / T.StalkSpeed), world)
		else
			Attack.face(e, target)
		end
	end
	if e.phase == "Read" then
		-- It stops and reads; a press now is read at the choice and uses the one re-plan.
		Attack.face(e, target)
		if e.replans < T.MaxReplans and pressedSince(world, e.phaseAt, now) then e.replans = T.MaxReplans end
		if now >= e.readUntil - 1e-9 then
			local point, eta, targetEta = choosePoint(e, target, world, T)
			if point then startIntercept(events, e, now, point, eta, targetEta, false, T) else pursue(events, e, now) end
		end
	end
	if e.phase == "Intercept" and e.replans < T.MaxReplans then
		-- Dash temprano = te lee: one re-plan with the new velocity, no sooner than ReplanCooldownSeconds after the plan.
		e.pressAt = e.pressAt or pressedSince(world, e.planAt, now)
		if e.pressAt and now >= e.planAt + T.ReplanCooldownSeconds - 1e-9 then
			e.replans += 1
			e.pressAt = nil
			endZone(events, e, now, "Replan")
			local point, eta, targetEta = choosePoint(e, target, world, T)
			if point then startIntercept(events, e, now, point, eta, targetEta, true, T) else pursue(events, e, now) end
		end
	end
	if e.phase == "Intercept" then
		-- A straight run to P at InterceptSpeed (never a teleport).
		local from, to = e.interceptFrom, e.interceptTo
		local total = Config.flat(from.x, from.z, to.x, to.z)
		local ran = math.min(total, (now - e.planAt) * T.InterceptSpeed)
		local k = total > 1e-9 and ran / total or 1
		e.pos.x, e.pos.z = from.x + (to.x - from.x) * k, from.z + (to.z - from.z) * k
		e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
		if ran >= total - 1e-9 then
			e.pressAt = nil
			e.pos.x, e.pos.y, e.pos.z = to.x, to.y, to.z
			e.blockUntil = e.arriveAt + T.BlockSeconds
			Attack.phase(events, e, "Block", e.arriveAt, e.blockUntil)
		end
	end
	if e.phase == "Block" then
		-- It stands in the zone. Entering it opens the Snap, never before the zone was drawn MIN_TELL; turning back,
		-- going around or waiting is safe. A refused strike slot (Stagger) retries on the next step.
		Attack.face(e, target)
		local zone = e.zone
		local inside = zone ~= nil and Attack.inside(zone.shape, target, zone.shape.y, C.hitHeight)
		if inside and now >= zone.startAt + Config.MIN_TELL - 1e-9 and startSnap(events, e, now, target, world, T) then
			-- the Snap is open; it resolves below
		elseif now >= e.blockUntil - 1e-9 then
			endZone(events, e, e.blockUntil, "Done")
			Attack.phase(events, e, "Stalk", e.blockUntil)
		end
	end
	if e.phase == "Snap" then
		-- The swipe lands only inside its drawn sector at the strike; one outcome.
		local attack = e.snap
		if now >= attack.strikeAt - 1e-9 then
			local dropped = false
			if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
				dropped = Attack.hit(events, e, world, attack, attack.strikeAt) == "Hit" and target.carryingEgg == true
			else
				Attack.miss(events, e, world, attack, attack.strikeAt)
			end
			e.snap = nil
			endZone(events, e, attack.strikeAt, "Done")
			if dropped then
				Attack.disengage(events, e, "EggDropped", attack.strikeAt, C.disengage) -- the egg can be picked back up
			else
				Attack.phase(events, e, "Stalk", attack.strikeAt)
			end
		end
	end
	if e.phase == "FeintTell" then
		-- The body holds still; only the drawn lane follows the target. The feint ends at the bait or at its end.
		local feint = e.feint
		local taken = baitTaken(e, world, math.min(now, feint.endAt))
		if taken or now >= feint.endAt then
			local at = taken and now or feint.endAt
			emit(events, e, "TellEnd", at, { tell = feint.id, reason = "Feint" })
			e.feint = nil
			if not startCharge(events, e, now, target, world, C, T, taken and "PunishTell" or "ChargeTell") then
				Attack.phase(events, e, "Stalk", now) -- staggered: the next charge is real (never two feints in a row)
			end
		elseif now - feint.sentAt >= Attack.TELL_RATE then
			feint.sentAt = now
			emit(events, e, "Tell", now, { tell = feint.id, shape = feintShape(e, target, C, T), startAt = feint.startAt,
				strikeAt = feint.endAt, dodgeable = false, feint = true, locked = false })
		end
	end
	if e.phase == "ChargeTell" or e.phase == "PunishTell" then
		local attack = e.charge
		if now < e.lockAt then
			-- The lane follows the target until the lock (never in the last lockLead seconds).
			local dx, dz = unit(target.x - e.origin.x, target.z - e.origin.z)
			if dx then e.dx, e.dz = dx, dz end
			Attack.aim(events, e, attack, laneShape(e, C), now)
		elseif not attack.locked then
			local wall = world.castLane and world.castLane(e.origin.x, e.origin.y, e.origin.z, e.dx, e.dz, T.ChargeMaxRangeStuds)
			if finite(wall) and wall < T.ChargeMaxRangeStuds then e.length, e.crashed = math.max(0, wall - 0.5), true end
			Attack.lock(events, e, attack, laneShape(e, C), e.lockAt)
		end
		if attack.locked and now >= e.commitAt then
			Attack.phase(events, e, "Charge", e.commitAt, e.commitAt + e.length / T.ChargeSpeed)
			emit(events, e, "Move", e.commitAt, { kind = "dash", from = copy(e.origin), dx = e.dx, dz = e.dz,
				speed = T.ChargeSpeed, length = e.length })
		end
	end
	if e.phase == "Charge" then
		local attack = e.charge
		local travelled = math.min(e.length, (now - e.commitAt) * T.ChargeSpeed)
		e.pos.x, e.pos.z = e.origin.x + e.dx * travelled, e.origin.z + e.dz * travelled
		e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
		-- Swept volume: the part of the drawn lane the head crossed since the last step. One outcome per charge.
		if not attack.done and math.abs(target.y - e.pos.y) <= C.hitHeight
			and Config.inLane(target.x, target.z, e.origin.x, e.origin.z, e.dx, e.dz, e.swept, travelled, C.laneWidth) then
			e.chargeResult = Attack.hit(events, e, world, attack, now)
			if e.chargeResult == "Hit" and target.carryingEgg == true then e.eggDropped = true end
		end
		e.swept = travelled
		if travelled >= e.length - 1e-9 then
			local endAt = e.commitAt + e.length / T.ChargeSpeed
			if not attack.done then e.chargeResult = Attack.miss(events, e, world, attack, endAt) end
			e.chargeReadyAt = e.commitAt + T.ChargeCooldownSeconds
			if e.eggDropped then
				e.eggDropped = nil
				Attack.disengage(events, e, "EggDropped", endAt, C.disengage) -- the egg can be picked back up
			elseif e.chargeResult == "Dodged" then
				startFall(events, e, endAt, world, T)
			else
				Attack.phase(events, e, "Recovery", endAt, endAt + T.ChargeMissRecoverySeconds, { crashed = e.crashed })
				e.recoverUntil = endAt + T.ChargeMissRecoverySeconds
			end
			e.charge, e.chargeResult = nil, nil
		end
	end
	if e.phase == "PulseCharge" then
		-- It rears up and holds still; the ring never moves. One outcome at the release.
		Attack.face(e, target)
		if now >= e.pulse.strikeAt - 1e-9 then
			local at = e.pulse.strikeAt
			if releasePulse(events, e, target, world, C, T) then
				Attack.disengage(events, e, "EggDropped", at, C.disengage) -- the egg can be picked back up
			else
				Attack.phase(events, e, "Pulse", at, at + PULSE_RELEASE_SECONDS)
			end
		end
	end
	if e.phase == "Pulse" and now >= e.phaseAt + PULSE_RELEASE_SECONDS - 1e-9 then
		Attack.phase(events, e, "Stalk", e.phaseAt + PULSE_RELEASE_SECONDS)
	end
	if e.phase == "Fallen" then
		-- The overrun: straight on along the locked line at the charge speed, then the body lies still.
		local slid = math.min(e.overrun, math.max(0, now - e.fallAt) * T.ChargeSpeed)
		e.pos.x, e.pos.z = e.fallFrom.x + e.dx * slid, e.fallFrom.z + e.dz * slid
		e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	end
	if (e.phase == "Recovery" or e.phase == "Fallen") and now >= e.recoverUntil then
		if e.phase == "Fallen" and e.falls >= T.FallsToGiveUp then
			Attack.disengage(events, e, "Outplayed", e.recoverUntil, C.disengage)
		else
			Attack.phase(events, e, "Stalk", e.recoverUntil)
		end
	end
end

return Scuttler
