-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-4): the shared layer of the four new beasts' state machines
-- (Streamer, Root, Gaze, Lurker). Server only and pure: the beast script passes the clock, the target's server state
-- and a world adapter; this module only returns events. One attack is: a telegraph (a "Tell" event with the shape the
-- client draws, which is the exact hit volume, and its server times), registered with the perfect dodge when it can be
-- dodged (world.telegraph -> WildboundDodgeService.telegraph), then exactly one outcome: Attack.hit (the server found
-- the target inside the shape: world.resolve decides "Dodged" or "Hit", once) or Attack.miss (the window closed with
-- nobody inside: world.cancel). A "Hit" event goes to the inventory server's BeastHit (damage and the one egg drop
-- path); nothing is decided by contact events or by the client. Attack.closeAll cancels whatever is open when an
-- encounter ends, so no hit can land after the end. world.claimStrike is the anti-frustration rule of the pack's
-- combinations matrix: two telegraphed strikes on one player never land closer than DIRECTOR.STRIKE_SEPARATION; the
-- later one waits (the state machine retries on its next step).
local Config = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastConfig"))
-- Beast revision BR0 (odd/tasks/wildbound-beast-revision.md): the shared chase rules (persistent chase, one end check,
-- the catch-up walk).
local Chase = require((script:FindFirstAncestorOfClass("DataModel") :: any):GetService("ReplicatedStorage")
	:WaitForChild("WildboundBeastChase"))
local Attack = {}

local finite, flat, unit = Config.finite, Config.flat, Config.unit
Attack.TELL_RATE = 0.1 -- a following tell is re-sent at most this often (the client redraws it)

function Attack.copy(p) return { x = p.x, y = p.y, z = p.z } end

function Attack.emit(events, e, kind, at, fields)
	local ev = { type = kind, id = e.id, beast = e.beast, at = at }
	for k, v in pairs(fields or {}) do ev[k] = v end
	table.insert(events, ev)
	return ev
end

-- Sets the phase and tells the client (posture, warning line, sound). `untilAt` is when the phase is planned to end.
function Attack.phase(events, e, phase, at, untilAt, fields)
	e.phase, e.phaseAt = phase, at
	local payload = { phase = phase, untilAt = untilAt }
	for k, v in pairs(fields or {}) do payload[k] = v end
	return Attack.emit(events, e, "Phase", at, payload)
end

function Attack.groundAt(world, x, z, y)
	local value = world.ground and world.ground(x, z, y)
	return finite(value) and value or y
end

-- Walks toward (sign 1) or away from (sign -1) the target at `speed`, on the ground. Never teleports.
function Attack.walk(e, target, speed, sign, dt, world)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if not dx then dx, dz = e.dx, e.dz end
	-- BR0: a persistent beast far behind closes in at least at the catch-up speed.
	speed = Chase.walkSpeed(e.beast, speed, flat(e.pos.x, e.pos.z, target.x, target.z), sign)
	e.pos.x += dx * speed * dt * sign
	e.pos.z += dz * speed * dt * sign
	e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	e.dx, e.dz = dx, dz
end

-- Faces the target without moving.
function Attack.face(e, target)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if dx then e.dx, e.dz = dx, dz end
end

function Attack.distance(e, target)
	return flat(e.pos.x, e.pos.z, target.x, target.z)
end

function Attack.disengage(events, e, reason, at, seconds)
	e.phase, e.phaseAt = "Disengage", at
	e.disengageReason = reason
	e.disengageUntil = at + (seconds or 0.9)
	Attack.emit(events, e, "Disengage", at, { reason = reason, untilAt = e.disengageUntil })
end

function Attack.finish(e, reason, now)
	if e.done then return nil end
	e.done, e.endReason, e.phase = true, reason, "Ended"
	return { type = "End", id = e.id, beast = e.beast, at = now, reason = reason }
end

-- The end checks every wave 2 beast shares. opts = { timeout, escapeDistance, escapeSeconds, busy, disengage }.
-- Death, a respawned body (the beast script passes nil) and a safe zone end the encounter at once; a long absence
-- (escape), the timeout or a caller's reason (lost target) start the retreat. Returns true when nothing else may run.
-- BR0: a persistent beast (WildboundBeastChase.PERSISTENT) skips escape and timeout: only death or a safe zone ends it.
function Attack.guard(events, e, now, target, opts)
	local ended = Chase.ended(target)
	if ended then
		table.insert(events, Attack.finish(e, ended, now))
		return true
	end
	if e.phase == "Disengage" then
		if now >= e.disengageUntil then table.insert(events, Attack.finish(e, e.disengageReason or "Done", e.disengageUntil)) end
		return true
	end
	if Chase.persistent(e.beast) then
		e.farSince = nil
		return false
	end
	if finite(opts.escapeDistance) then
		if Attack.distance(e, target) > opts.escapeDistance then e.farSince = e.farSince or now else e.farSince = nil end
	end
	if opts.busy then return false end
	if e.farSince and now - e.farSince >= (opts.escapeSeconds or 4) then
		Attack.disengage(events, e, "Escape", now, opts.disengage)
		return true
	end
	if finite(opts.timeout) and now - e.startedAt >= opts.timeout then
		Attack.disengage(events, e, "Timeout", now, opts.disengage)
		return true
	end
	return false
end

-- Opens a telegraphed attack. spec = { key, startAt, strikeAt, shape, dodgeable, damage, lockAt }. Returns the attack,
-- or nil and "Stagger" when another strike on this player lands too close (try again on a later step).
function Attack.open(events, e, world, spec)
	e.attackCount = (e.attackCount or 0) + 1
	local id = ("%s:%s:%d"):format(e.id, spec.key, e.attackCount)
	if world.claimStrike and not world.claimStrike(e.id, id, spec.strikeAt) then
		e.attackCount -= 1
		e.staggered = (e.staggered or 0) + 1
		return nil, "Stagger"
	end
	local attack = { id = id, key = spec.key, startAt = spec.startAt, strikeAt = spec.strikeAt, shape = spec.shape,
		dodgeable = spec.dodgeable == true, damage = spec.damage, done = false, sentAt = spec.startAt, locked = false }
	if attack.dodgeable and world.telegraph then
		-- A refusal (a telegraph under 0.8 s) leaves the attack undodgeable; it still lands only where it was drawn.
		attack.registered = world.telegraph(id, e.beast, spec.startAt, spec.strikeAt) == true
	end
	e.open = e.open or {}
	e.open[id] = attack
	Attack.emit(events, e, "Tell", spec.startAt, { tell = id, shape = spec.shape, startAt = spec.startAt,
		strikeAt = spec.strikeAt, lockAt = spec.lockAt, dodgeable = attack.dodgeable, locked = false })
	return attack
end

-- Re-aims an attack before its lock (the client redraws the tell). Throttled to TELL_RATE.
function Attack.aim(events, e, attack, shape, now)
	if attack.locked or attack.done then return end
	attack.shape = shape
	if now - attack.sentAt >= Attack.TELL_RATE then
		attack.sentAt = now
		Attack.emit(events, e, "Tell", now, { tell = attack.id, shape = shape, startAt = attack.startAt,
			strikeAt = attack.strikeAt, dodgeable = attack.dodgeable, locked = false })
	end
end

-- Freezes the shape: from now on the hit volume never moves.
function Attack.lock(events, e, attack, shape, at)
	if attack.locked or attack.done then return end
	attack.locked = true
	if shape then attack.shape = shape end
	Attack.emit(events, e, "Tell", at, { tell = attack.id, shape = attack.shape, startAt = attack.startAt,
		strikeAt = attack.strikeAt, dodgeable = attack.dodgeable, locked = true })
end

local function close(e, attack)
	attack.done = true
	if e.open then e.open[attack.id] = nil end
end

-- Settles a landed attack once: closes it, asks the dodge (only when dodgeable) and emits the Strike. Returns nil when
-- already settled, true when a perfect dodge held the window, false when it landed.
local function land(events, e, world, attack, now)
	if attack.done then return nil end
	close(e, attack)
	local verdict = "Hit"
	if attack.dodgeable and world.resolve then verdict = world.resolve(attack.id, now) end
	if verdict == "Dodged" then
		Attack.emit(events, e, "Strike", now, { tell = attack.id, hit = false, dodged = true })
		return true
	end
	Attack.emit(events, e, "Strike", now, { tell = attack.id, hit = true })
	return false
end

-- The target is inside the attack's volume: the one outcome of this attack. Returns "Dodged" (a perfect dodge held
-- the window: no damage) or "Hit" (a Hit event with the damage and the extra fields). nil when already settled.
function Attack.hit(events, e, world, attack, now, fields)
	local dodged = land(events, e, world, attack, now)
	if dodged == nil then return nil end
	if dodged then return "Dodged" end
	local payload = { damage = attack.damage, attack = attack.id }
	for k, v in pairs(fields or {}) do payload[k] = v end
	Attack.emit(events, e, "Hit", now, payload)
	return "Hit"
end

-- SC2 (odd/tasks/wildbound-scuttler.md): the non-damaging outcome of an attack whose target is inside its volume. The
-- same dodge resolution as Attack.hit, but a landed attack emits an "Afflict" event (the attack id and the extra
-- fields, e.g. a slow and a shake; no damage) and never "Hit", so the beast script applies the effect without reaching
-- BeastHit (damage and the egg drop). Returns "Dodged", "Afflicted", or nil when already settled.
function Attack.afflict(events, e, world, attack, now, fields)
	local dodged = land(events, e, world, attack, now)
	if dodged == nil then return nil end
	if dodged then return "Dodged" end
	local payload = { attack = attack.id }
	for k, v in pairs(fields or {}) do payload[k] = v end
	Attack.emit(events, e, "Afflict", now, payload)
	return "Afflicted"
end

-- The window closed with nobody inside. Returns "Miss" once, nil when already settled.
function Attack.miss(events, e, world, attack, now)
	if attack.done then return nil end
	close(e, attack)
	if attack.dodgeable and world.cancel then world.cancel(attack.id) end
	Attack.emit(events, e, "Strike", now, { tell = attack.id, hit = false })
	return "Miss"
end

-- An attack called off before its strike (the target left, the beast gave up): no strike, the tell goes away.
function Attack.drop(events, e, world, attack, now, reason)
	if attack.done then return end
	close(e, attack)
	if attack.dodgeable and world.cancel then world.cancel(attack.id) end
	Attack.emit(events, e, "TellEnd", now, { tell = attack.id, reason = reason })
end

-- Every attack still open: their ids (sorted). The beast script cancels them with the dodge service on End.
function Attack.openIds(e)
	local ids = {}
	for id in pairs(e.open or {}) do table.insert(ids, id) end
	table.sort(ids)
	return ids
end

-- Ends every open attack without a strike (End, error). Idempotent.
function Attack.closeAll(e, world)
	for _, id in ipairs(Attack.openIds(e)) do
		local attack = e.open[id]
		close(e, attack)
		if attack.dodgeable and world and world.cancel then world.cancel(id) end
	end
end

-- The target's flat point is inside the shape and within `height` studs of `groundY` (the shape's floor).
function Attack.inside(shape, target, groundY, height)
	if not Config.shapeHit(shape, target.x, target.z) then return false end
	return not finite(groundY) or not finite(height) or math.abs(target.y - groundY) <= height
end

return Attack
