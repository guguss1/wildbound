-- Beast revision BR3 (odd/tasks/wildbound-beast-revision.md, owner 2026-11-16): the Screamer (internal id "Streamer",
-- kept so the director, the config, the rig data and the saved place keep working; players only ever read "Screamer",
-- WildboundText). Server only and pure, stepped by WildboundBeastEncounters through Enc.register. State machine:
--   Spawn -> Statue (A: it never moves and never attacks; the client draws it in stone) until the target comes within
--   activationDistance -> Scream (B: screamSeconds of a harmless scream: no damage, no push, no tell; the client reveals
--   the true form) -> Pursue (C: chaseSpeed, very fast; the persistent chase of WildboundBeastChase applies from here)
--   -> CatchTell (within catchRange: a catchTell-long grab circle on the target, following it until catchLockLead before
--   the strike, then fixed; registered with the perfect dodge) -> Recovery (catchRecover) -> Pursue ...
-- Teleport repositioning, only in Pursue: when the target is farther than teleportFar, or out of its line of sight for
-- teleportUnseenSeconds, and the cooldown is over, it asks world.nearSpot for a point teleportMin..teleportMax from the
-- target and accepts it only through WildboundBeastChase.validSpot (grounded, out of every safe zone, never within
-- teleportClearance of the target). A refused point cancels that try (a short retry) and the chase goes on; after a jump
-- the grab waits teleportGrabBlock, so a teleport can never land a hit by itself. It never changes the target.
-- An unwoken statue ends quietly after statueSeconds ("Unwoken"): the chase rule starts at the scream.
-- Every number is Config.BEASTS.Streamer (the BR3 fields; the pack's `tuning` table stays for reference only).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Chase = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastChase"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Streamer = {}

local copy, emit = Attack.copy, Attack.emit

function Streamer.init(e)
	e.catchReadyAt, e.teleportReadyAt, e.unseenSince, e.teleports, e.teleportRefused = -math.huge, -math.huge, nil, 0, 0
end

local function lineOfSight(world, e, target)
	if not world.lineOfSight then return true end
	return world.lineOfSight(e.pos, target) == true
end

-- One teleport try. Returns true when it moved.
function Streamer.teleport(events, e, now, target, world, C)
	local spot = world.nearSpot and world.nearSpot(target, C.teleportMin, C.teleportMax) or nil
	local ok, why = Chase.validSpot(spot, target, { min = C.teleportMin, max = C.teleportMax,
		clearance = C.teleportClearance, safe = world.safe })
	if not ok then
		e.teleportRefused += 1
		e.teleportReadyAt = now + C.teleportRetry
		emit(events, e, "TeleportRefused", now, { reason = why })
		return false
	end
	emit(events, e, "Move", now, { kind = "blink", from = copy(e.pos), to = copy(spot) })
	e.pos.x, e.pos.y, e.pos.z = spot.x, spot.y, spot.z
	Attack.face(e, target)
	e.teleports += 1
	e.teleportReadyAt = now + C.teleportCooldown
	e.catchReadyAt = math.max(e.catchReadyAt, now + C.teleportGrabBlock)
	e.unseenSince = nil
	return true
end

local function startCatch(events, e, now, target, world, C)
	local strikeAt = now + C.catchTell
	local attack = Attack.open(events, e, world, { key = "catch", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = C.catchDamage, shape = { kind = "circle", x = target.x, y = Attack.groundAt(world, target.x, target.z, target.y - 3),
			z = target.z, r = C.catchRadius } })
	if not attack then return false end
	e.catch = attack
	Attack.face(e, target)
	Attack.phase(events, e, "CatchTell", now, strikeAt)
	return true
end

function Streamer.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Streamer
	if Attack.guard(events, e, now, target, { busy = e.phase == "CatchTell", disengage = C.disengage }) then return end

	if e.phase == "Spawn" then
		Attack.phase(events, e, "Statue", e.phaseAt)
	end
	if e.phase == "Statue" then
		-- A: still as stone. Only the distance wakes it.
		if Attack.distance(e, target) <= C.activationDistance then
			Attack.face(e, target)
			Attack.phase(events, e, "Scream", now, now + C.screamSeconds)
		elseif now - e.phaseAt >= C.statueSeconds then
			Attack.disengage(events, e, "Unwoken", now, C.disengage)
		end
		return
	end
	if e.phase == "Scream" then
		-- B: the scream is the transformation, never an attack.
		Attack.face(e, target)
		if now - e.phaseAt >= C.screamSeconds then Attack.phase(events, e, "Pursue", e.phaseAt + C.screamSeconds) end
	end
	if e.phase == "Pursue" then
		local distance = Attack.distance(e, target)
		local seen = lineOfSight(world, e, target)
		if seen then e.unseenSince = nil else e.unseenSince = e.unseenSince or now end
		local lost = distance > C.teleportFar or (e.unseenSince ~= nil and now - e.unseenSince >= C.teleportUnseenSeconds)
		if lost and now >= e.teleportReadyAt and Streamer.teleport(events, e, now, target, world, C) then
			return
		end
		if distance <= C.catchRange and now >= e.catchReadyAt then
			if not startCatch(events, e, now, target, world, C) then Attack.face(e, target) end
		elseif distance > C.catchRange * 0.8 then
			Attack.walk(e, target, C.chaseSpeed, 1, dt, world)
		else
			Attack.face(e, target)
		end
	end
	if e.phase == "CatchTell" and now < e.catch.strikeAt then
		-- The grab circle follows the target until catchLockLead before the strike, then never moves; it keeps running
		-- behind the target meanwhile (a perfect dodge or a sidestep after the lock escapes it).
		local attack = e.catch
		Attack.walk(e, target, C.chaseSpeed, 1, dt, world)
		if now < attack.strikeAt - C.catchLockLead then
			Attack.aim(events, e, attack, { kind = "circle", x = target.x,
				y = Attack.groundAt(world, target.x, target.z, target.y - 3), z = target.z, r = C.catchRadius }, now)
		elseif not attack.lockedNow then
			attack.lockedNow = true
			Attack.lock(events, e, attack, nil, attack.strikeAt - C.catchLockLead)
		end
	end
	if e.phase == "CatchTell" and now >= e.catch.strikeAt then
		local attack = e.catch
		if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
			Attack.hit(events, e, world, attack, attack.strikeAt)
		else
			Attack.miss(events, e, world, attack, attack.strikeAt)
		end
		e.catch = nil
		e.catchReadyAt = attack.strikeAt + C.catchCooldown
		e.recoverUntil = attack.strikeAt + C.catchRecover
		Attack.phase(events, e, "Recovery", attack.strikeAt, e.recoverUntil)
	end
	if e.phase == "Recovery" and now >= e.recoverUntil then
		Attack.phase(events, e, "Pursue", e.recoverUntil)
	end
end

return Streamer
