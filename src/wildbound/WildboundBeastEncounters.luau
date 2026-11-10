-- Nest Heist phase 4a (NB3): the server-authoritative state machines of the two global beasts, Viper (the telegraphed
-- dash, docs/design/beast-pack/01_VIPER.md) and Pouncer (the leap onto a marked circle, 02_POUNCER.md). Pure: the beast
-- script steps each encounter with the target's server position and a small world adapter (ground, lane cast, landing
-- check, arc check), and turns the returned events into target-only client messages and hits. Timed phases start at
-- their scheduled instant, not at the step that noticed them, so the client's telegraph and the server's hit window
-- share the same timestamps. The lane, circle and arc come from WildboundBeastConfig, the same functions the client
-- draws with. No hit is ever decided by contact events or by the client.
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
local Enc = {}

local finite, flat, unit = Config.finite, Config.flat, Config.unit
local MAX_DT = 0.25

local function copy(p) return { x = p.x, y = p.y, z = p.z } end

local function emit(events, e, kind, at, fields)
	local ev = { type = kind, id = e.id, beast = e.beast, at = at }
	for k, v in pairs(fields or {}) do ev[k] = v end
	table.insert(events, ev)
	return ev
end

local function setPhase(e, phase, at)
	e.phase, e.phaseAt = phase, at
end

function Enc.new(beast, id, userId, now, pos)
	assert(Config.BEASTS[beast] and Config.PLAYABLE[beast], "no behaviour for " .. tostring(beast))
	return { beast = beast, id = id, userId = userId, startedAt = now, lastStep = now, phase = "Spawn", phaseAt = now,
		pos = copy(pos), dx = 0, dz = 1, attacks = 0, jumps = 0, skips = 0, done = false, farSince = nil }
end

-- Ends the encounter at once (death, safe zone, leave, error, or the end of the retreat). Returns the End event the
-- first time and nil afterwards.
function Enc.finish(e, reason, now)
	if e.done then return nil end
	e.done, e.endReason, e.phase = true, reason, "Ended"
	return { type = "End", id = e.id, beast = e.beast, at = now, reason = reason }
end

local function disengage(events, e, reason, at)
	setPhase(e, "Disengage", at)
	e.disengageReason = reason
	emit(events, e, "Disengage", at, { reason = reason })
end

local function groundAt(world, x, z, y)
	local value = world.ground and world.ground(x, z, y)
	return finite(value) and value or y
end

-- Walks toward (sign 1) or away from (sign -1) the target at `speed`, on the ground. Never teleports.
local function walk(e, target, speed, sign, dt, world)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if not dx then dx, dz = e.dx, e.dz end
	local stepX, stepZ = dx * speed * dt * sign, dz * speed * dt * sign
	e.pos.x += stepX
	e.pos.z += stepZ
	e.pos.y = groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	e.dx, e.dz = dx, dz
end

-- Shared end checks. Returns true when the encounter is over or retreating for good.
local function guard(events, e, now, target, C, busy)
	if not target or target.alive ~= true then
		table.insert(events, Enc.finish(e, "Death", now))
		return true
	end
	if target.safe == true then
		table.insert(events, Enc.finish(e, "SafeZone", now))
		return true
	end
	if e.phase == "Disengage" then return false end
	local distance = flat(e.pos.x, e.pos.z, target.x, target.z)
	if distance > C.escapeDistance then
		e.farSince = e.farSince or now
	else
		e.farSince = nil
	end
	if busy then return false end
	if e.farSince and now - e.farSince >= C.escapeSeconds then
		disengage(events, e, "Escape", now)
		return true
	end
	if now - e.startedAt >= C.maxSeconds then
		disengage(events, e, "Timeout", now)
		return true
	end
	return false
end

local function stepDisengage(events, e, now, C)
	if e.phase == "Disengage" and now - e.phaseAt >= C.disengage then
		table.insert(events, Enc.finish(e, e.disengageReason or "Done", e.phaseAt + C.disengage))
	end
end

-- Viper ------------------------------------------------------------------------------------------------------------

local function viperWindup(events, e, now, target, C)
	setPhase(e, "Windup", now)
	e.origin = copy(e.pos)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if dx then e.dx, e.dz = dx, dz end
	e.locked, e.length, e.crashed, e.swept, e.hitThisDash = false, C.laneLength, false, 0, false
	e.lockAt, e.dashAt = now + C.windup - C.lockLead, now + C.windup
	emit(events, e, "Windup", now, { origin = copy(e.origin), dx = e.dx, dz = e.dz, length = C.laneLength,
		width = C.laneWidth, lockAt = e.lockAt, dashAt = e.dashAt })
end

local function stepViper(events, e, now, target, world, dt)
	local C = Config.BEASTS.Viper
	if guard(events, e, now, target, C, e.phase == "Dash") then return end
	if e.phase == "Spawn" and now - e.phaseAt >= C.spawnSeconds then
		setPhase(e, "Stalk", e.phaseAt + C.spawnSeconds)
		emit(events, e, "Stalk", e.phaseAt)
	end
	if e.phase == "Stalk" then
		local distance = flat(e.pos.x, e.pos.z, target.x, target.z)
		if distance > C.attackMax then walk(e, target, C.stalkSpeed, 1, dt, world)
		elseif distance < C.attackMin then walk(e, target, C.stalkSpeed, -1, dt, world) end
		distance = flat(e.pos.x, e.pos.z, target.x, target.z)
		if distance >= C.attackMin and distance <= C.attackMax then
			-- In range: wind up only with a clear line to the target; with a trunk or a rock in the way, sidestep for at
			-- most clearSearch seconds, then wind up anyway (the lock will cut the lane at the obstacle).
			local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
			local wall = dx and world.castLane and world.castLane(e.pos.x, e.pos.y, e.pos.z, dx, dz, math.min(distance, C.laneLength))
			e.inRangeSince = e.inRangeSince or now
			if not finite(wall) or now - e.inRangeSince >= C.clearSearch then
				e.inRangeSince = nil
				viperWindup(events, e, now, target, C)
			elseif dx then
				e.side = e.side or 1
				e.pos.x += -dz * e.side * C.strafeSpeed * dt
				e.pos.z += dx * e.side * C.strafeSpeed * dt
				e.pos.y = groundAt(world, e.pos.x, e.pos.z, e.pos.y)
				e.dx, e.dz = dx, dz
			end
		elseif now - e.phaseAt >= C.stalkSeconds then
			if distance <= C.laneLength then viperWindup(events, e, now, target, C)
			else disengage(events, e, "NoApproach", now) end
		end
	end
	if e.phase == "Windup" then
		if not e.locked and now < e.lockAt then
			-- The lane follows the target until the lock. Snapshots carry this aim to the client.
			local dx, dz = unit(target.x - e.origin.x, target.z - e.origin.z)
			if dx then e.dx, e.dz = dx, dz end
		elseif not e.locked then
			e.locked = true
			local wall = world.castLane and world.castLane(e.origin.x, e.origin.y, e.origin.z, e.dx, e.dz, C.laneLength)
			if finite(wall) and wall < C.laneLength then
				e.length, e.crashed = math.max(0, wall - 0.5), true
			end
			emit(events, e, "Lock", e.lockAt, { dx = e.dx, dz = e.dz, length = e.length })
		end
		if e.locked and now >= e.dashAt then
			setPhase(e, "Dash", e.dashAt)
			emit(events, e, "Dash", e.dashAt, { dx = e.dx, dz = e.dz, length = e.length, speed = C.dashSpeed,
				endAt = e.dashAt + e.length / C.dashSpeed })
		end
	end
	if e.phase == "Dash" then
		local travelled = math.min(e.length, (now - e.dashAt) * C.dashSpeed)
		-- Swept hitbox: the part of the lane the head crossed since the last step, with the drawn width.
		if not e.hitThisDash and travelled > e.swept - 1e-9 and math.abs(target.y - e.origin.y) <= C.hitHeight
			and Config.inLane(target.x, target.z, e.origin.x, e.origin.z, e.dx, e.dz, e.swept, travelled, C.laneWidth) then
			e.hitThisDash = true
			emit(events, e, "Hit", now, { damage = C.damage, attack = e.attacks + 1 })
		end
		e.swept = travelled
		e.pos.x, e.pos.z = e.origin.x + e.dx * travelled, e.origin.z + e.dz * travelled
		if travelled >= e.length - 1e-9 then
			local endAt = e.dashAt + e.length / C.dashSpeed
			e.attacks += 1
			setPhase(e, "Recover", endAt)
			e.recoverUntil = endAt + (e.crashed and C.recoverCrash or C.recover)
			emit(events, e, "Recover", endAt, { untilAt = e.recoverUntil, crashed = e.crashed })
		end
	end
	if e.phase == "Recover" and now >= e.recoverUntil then
		if e.attacks < C.maxAttacks and now - e.startedAt < C.maxSeconds then
			setPhase(e, "Stalk", e.recoverUntil)
			emit(events, e, "Stalk", e.phaseAt)
		else
			disengage(events, e, "Done", e.recoverUntil)
		end
	end
	stepDisengage(events, e, now, C)
end

-- Pouncer ----------------------------------------------------------------------------------------------------------

-- The landing spot: the target's position plus a moderate lead, on valid ground (the world adapter refuses a void,
-- a wall or a safe zone), within the height change limit and with a clear arc. Falls back to the current position.
local function landingFor(e, target, world, C)
	local tries = { { target.x + (finite(target.vx) and target.vx or 0) * C.predictSeconds,
		target.z + (finite(target.vz) and target.vz or 0) * C.predictSeconds }, { target.x, target.z } }
	for _, spot in ipairs(tries) do
		local y = target.y
		if world.landing then y = world.landing(spot[1], spot[2], target.y) end
		if finite(y) and math.abs(y - e.pos.y) <= C.maxStep then
			local clear = not world.arcClear or world.arcClear(e.pos.x, e.pos.y, e.pos.z, spot[1], y, spot[2], C.arcHeight)
			if clear then return { x = spot[1], y = y, z = spot[2] } end
		end
	end
	return nil
end

local function pouncerChoose(events, e, now, target, world, C)
	local center = landingFor(e, target, world, C)
	if not center then
		e.skips += 1
		emit(events, e, "Cancel", now, { reason = "NoLanding" })
		if e.skips >= C.maxSkips then disengage(events, e, "NoLanding", now) else e.retryAt = now + 0.5 end
		return
	end
	setPhase(e, "Telegraph", now)
	e.center, e.frozen = center, false
	e.freezeAt, e.leapAt = now + C.freezeAfter, now + C.telegraph
	e.landAt = e.leapAt + C.flight
	emit(events, e, "Telegraph", now, { center = copy(center), radius = C.radius, freezeAt = e.freezeAt,
		leapAt = e.leapAt, landAt = e.landAt })
end

local function stepPouncer(events, e, now, target, world, dt)
	local C = Config.BEASTS.Pouncer
	if guard(events, e, now, target, C, e.phase == "Leap") then return end
	if e.phase == "Spawn" and now - e.phaseAt >= C.spawnSeconds then
		setPhase(e, "Hunt", e.phaseAt + C.spawnSeconds)
		emit(events, e, "Hunt", e.phaseAt)
	end
	if e.phase == "Hunt" then
		local distance = flat(e.pos.x, e.pos.z, target.x, target.z)
		if distance > C.attackMax then walk(e, target, C.huntSpeed, 1, dt, world)
		elseif distance < C.attackMin then walk(e, target, C.huntSpeed, -1, dt, world) end
		distance = flat(e.pos.x, e.pos.z, target.x, target.z)
		local ready = not e.retryAt or now >= e.retryAt
		if ready and distance >= C.attackMin and distance <= C.attackMax then
			pouncerChoose(events, e, now, target, world, C)
		elseif now - e.phaseAt >= C.huntSeconds then
			if ready and distance <= C.attackMax + 6 then pouncerChoose(events, e, now, target, world, C)
			elseif distance > C.attackMax + 6 then disengage(events, e, "NoApproach", now) end
		end
	end
	if e.phase == "Telegraph" then
		if not e.frozen and now < e.freezeAt then
			local center = landingFor(e, target, world, C)
			if center then e.center = center end
		elseif not e.frozen then
			e.frozen = true
			local clear = not world.arcClear
				or world.arcClear(e.pos.x, e.pos.y, e.pos.z, e.center.x, e.center.y, e.center.z, C.arcHeight)
			if not clear then
				-- Never re-aim in secret: the jump is called off and the circle goes away.
				e.skips += 1
				emit(events, e, "Cancel", e.freezeAt, { reason = "Blocked" })
				setPhase(e, "Hunt", now)
				e.retryAt = now + 0.5
				return
			end
			emit(events, e, "Freeze", e.freezeAt, { center = copy(e.center) })
		end
		if e.frozen and now >= e.leapAt then
			setPhase(e, "Leap", e.leapAt)
			e.from = copy(e.pos)
			emit(events, e, "Leap", e.leapAt, { from = copy(e.from), to = copy(e.center), height = C.arcHeight, landAt = e.landAt })
		end
	end
	if e.phase == "Leap" then
		local t = math.clamp((now - e.leapAt) / C.flight, 0, 1)
		local x, y, z = Config.arc(e.from.x, e.from.y, e.from.z, e.center.x, e.center.y, e.center.z, C.arcHeight, t)
		e.pos.x, e.pos.y, e.pos.z = x, y, z
		if t >= 1 then
			-- The landing: one server distance check against the frozen centre, with the drawn radius.
			local hit = Config.inCircle(target.x, target.z, e.center.x, e.center.z, C.radius)
				and math.abs(target.y - e.center.y) <= C.hitHeight
			e.jumps += 1
			emit(events, e, "Land", e.landAt, { hit = hit, center = copy(e.center) })
			if hit then emit(events, e, "Hit", e.landAt, { damage = C.damage, attack = e.jumps }) end
			setPhase(e, "Recover", e.landAt)
			e.recoverUntil = e.landAt + C.recover
			emit(events, e, "Recover", e.landAt, { untilAt = e.recoverUntil })
		end
	end
	if e.phase == "Recover" and now >= e.recoverUntil then
		if e.jumps < math.min(C.jumps, C.maxJumps) and now - e.startedAt < C.maxSeconds then
			setPhase(e, "Hunt", e.recoverUntil)
			e.retryAt = nil
			emit(events, e, "Hunt", e.phaseAt)
		else
			disengage(events, e, "Done", e.recoverUntil)
		end
	end
	stepDisengage(events, e, now, C)
end

-- One server step. `target` is the target's server state ({x, y, z, vx, vz, alive, safe}) or nil when it has no body;
-- `world` holds the optional adapter functions. Returns the events of this step (empty once ended).
function Enc.step(e, now, target, world)
	local events = {}
	if e.done or not finite(now) then return events end
	world = type(world) == "table" and world or {}
	local dt = math.clamp(now - e.lastStep, 0, MAX_DT)
	e.lastStep = now
	if e.beast == "Viper" then stepViper(events, e, now, target, world, dt) else stepPouncer(events, e, now, target, world, dt) end
	return events
end

return Enc
