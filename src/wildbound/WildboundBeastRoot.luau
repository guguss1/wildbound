-- Wave 2 (odd/tasks/wildbound-beasts-wave2.md, BW2-5): Root, the swamp's root beast (pack 02_BESTIAS/ROOT). Server
-- only and pure, stepped by WildboundBeastEncounters through Enc.register. With Config.BIOME_PREFERENCE on it is rolled
-- only with the Swamp tag (director) and gives up when the target stays out of the Pantano; with it off (now) it is a
-- global beast and hunts anywhere. Nothing here needs swamp terrain: the rise, lanes and walls use world.ground and
-- world.landing, which are plain ground raycasts. State machine (pack names):
--   Rise (out of the mud, no tell yet) -> SelectAttack, alternating:
--   a) TelegraphTrap (Fase 1, TrapTelegraphSeconds: cracks mark the exact lanes, fixed by the server, never following
--      the target, cut before any safe zone) -> Erupt (Fase 2, an active window of trapActiveSeconds: one hit per
--      eruption, TrapDamage and a slow; a validated perfect dodge avoids both)
--   b) TelegraphWalls (Fase 3, WallTelegraphSeconds: two walls around the target with ONE gap of at least
--      SafeGapMinimumStuds facing away from Root; a blocked gap is turned, and with no clear gap the enclosure is
--      skipped) -> WallHold (WallHoldSeconds; walls block, never damage) -> WhipWindup (Fase 4, WhipTelegraphSeconds,
--      from Root at the walls' closed end, so the gap side is out of its reach) -> WhipActive (one sweep of the drawn
--      sector, WhipDamage)
--   -> Recovery (AttackCooldownSeconds) -> SelectAttack ... -> Disengage (out of the Pantano, too far, timeout) -> End.
-- Every number is Config.BEASTS.Root (tuning = PROPUESTA DE BALANCE).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Chase = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastChase")) -- BR0
local Root = {}

local finite, unit = Config.finite, Config.unit
local copy, emit = Attack.copy, Attack.emit

function Root.init(e)
	e.nextAttack = "trap"
	e.outSince = nil
end

local function safeAt(world, x, z)
	return world.safe ~= nil and world.safe(x, z) == true
end

-- Cuts a lane before the first point (every 2 studs) that lies in a safe zone. nil when nothing is left.
function Root.trimLane(lane, world)
	local step = 2
	local length = lane.length
	for d = 0, lane.length, step do
		if safeAt(world, lane.ox + lane.dx * d, lane.oz + lane.dz * d) then
			length = d - step
			break
		end
	end
	if length < lane.width then return nil end
	lane.length = length
	return lane
end

-- The gap direction: away from Root through the target, turned by 60 degree steps when world.gapClear says the way out
-- is blocked. nil when every direction is blocked (the pack: cancel the enclosure).
function Root.gapFor(e, center, world, C)
	local gx, gz = unit(center.x - e.pos.x, center.z - e.pos.z)
	if not gx then gx, gz = e.dx, e.dz end
	for _, turn in ipairs({ 0, 60, -60, 120, -120, 180 }) do
		local a = math.rad(turn)
		local x, z = gx * math.cos(a) - gz * math.sin(a), gx * math.sin(a) + gz * math.cos(a)
		if not world.gapClear or world.gapClear(center, x, z, C.enclosureRadius) then return x, z end
	end
	return nil
end

local function startTrap(events, e, now, target, world, C, T)
	-- BR4: the roots reach trapReach (was DetectionRadiusStuds 34).
	local shape = Config.rootLanes(e.pos.x, e.pos.y, e.pos.z, target.x, target.z, C.trapLanes, C.trapSpread,
		T.TrapLaneWidthStuds, C.trapReach)
	if not shape then return false end
	local kept = {}
	for _, lane in ipairs(shape.list) do
		local trimmed = Root.trimLane(lane, world)
		if trimmed then table.insert(kept, trimmed) end
	end
	if #kept == 0 then return false end
	shape.list = kept
	shape.segments = C.trapSegments
	local strikeAt = now + C.trapTelegraph
	local attack = Attack.open(events, e, world, { key = "trap", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.TrapDamage, shape = shape })
	if not attack then return false end
	attack.locked = true -- fixed by the server from the first frame: the lanes never follow the target
	e.trap = attack
	Attack.phase(events, e, "TelegraphTrap", now, strikeAt)
	return true
end

local function startWalls(events, e, now, target, world, C, T)
	local center = { x = target.x, y = Attack.groundAt(world, target.x, target.z, e.pos.y), z = target.z }
	local gx, gz = Root.gapFor(e, center, world, C)
	if not gx then return false end
	-- Root stands at the closed end, opposite the gap, on valid ground.
	local bx, bz = center.x - gx * C.enclosureRadius, center.z - gz * C.enclosureRadius
	local by = center.y
	if world.landing then by = world.landing(bx, bz, center.y) end
	if not finite(by) then return false end
	local walls = Config.enclosure(center.x, center.y, center.z, gx, gz, C.enclosureRadius, T.SafeGapMinimumStuds)
	if not walls then return false end
	local upAt = now + C.wallTelegraph
	e.walls = { shape = walls, upAt = upAt, downAt = upAt + C.wallHold, up = false }
	-- The walls never hit: they are a tell (and, on the target's client, a barrier), not an attack.
	emit(events, e, "Tell", now, { tell = e.id .. ":walls", shape = walls, startAt = now, strikeAt = upAt,
		dodgeable = false, locked = true })
	emit(events, e, "Move", now, { kind = "burrow", from = copy(e.pos), to = { x = bx, y = by, z = bz },
		untilAt = now + math.min(1, C.wallTelegraph) })
	e.pos.x, e.pos.y, e.pos.z = bx, by, bz
	e.dx, e.dz = gx, gz
	Attack.phase(events, e, "TelegraphWalls", now, upAt)
	return true
end

local function startWhip(events, e, now, world, C, T)
	local w = e.walls.shape
	local dx, dz = unit(w.x - e.pos.x, w.z - e.pos.z)
	if not dx then dx, dz = e.dx, e.dz end
	local strikeAt = now + C.whipTelegraph
	local attack = Attack.open(events, e, world, { key = "whip", startAt = now, strikeAt = strikeAt, dodgeable = true,
		damage = T.WhipDamage, shape = { kind = "sector", x = e.pos.x, y = e.pos.y, z = e.pos.z, dx = dx, dz = dz,
			r = C.whipRange, arc = T.WhipArcDegrees } })
	if not attack then return false end
	attack.locked = true -- "bloquea orientación horizontal antes de barrer": fixed at the windup's start
	e.whip = attack
	Attack.phase(events, e, "WhipWindup", now, strikeAt)
	return true
end

local function recover(events, e, at, T)
	e.recoverUntil = at + Config.BEASTS.Root.attackCooldown
	Attack.phase(events, e, "Recovery", at, e.recoverUntil)
end

-- BR4: a target beyond burrowReach is followed underground: Root sinks and rises burrowTo studs from it (toward its
-- old spot, on valid ground), then attacks. With no valid ground there it walks (the shared catch-up speed applies).
local function burrowCloser(events, e, now, target, world, C)
	local dx, dz = unit(e.pos.x - target.x, e.pos.z - target.z)
	if not dx then return false end
	local bx, bz = target.x + dx * C.burrowTo, target.z + dz * C.burrowTo
	local by = world.landing and world.landing(bx, bz, e.pos.y) or Attack.groundAt(world, bx, bz, e.pos.y)
	-- It rises on the target's level (never on a ridge above it), so its lanes and whip, checked against its own feet,
	-- can reach the target.
	if not finite(by) or math.abs(by - (target.y - 3)) > C.hitHeight - 1 then return false end
	emit(events, e, "Move", now, { kind = "burrow", from = copy(e.pos), to = { x = bx, y = by, z = bz },
		untilAt = now + C.burrowSeconds })
	e.pos.x, e.pos.y, e.pos.z = bx, by, bz
	Attack.face(e, target)
	Attack.phase(events, e, "Burrow", now, now + C.burrowSeconds)
	return true
end

function Root.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.Root
	local T = C.tuning
	local busy = e.phase == "TelegraphTrap" or e.phase == "Erupt" or e.phase == "WhipWindup"
	if Attack.guard(events, e, now, target, { timeout = T.EncounterTimeoutSeconds, escapeDistance = T.DetectionRadiusStuds,
		escapeSeconds = C.escapeSeconds, busy = busy, disengage = C.disengage }) then return end
	-- Out of its home biome (the Pantano, only while Config.BIOME_PREFERENCE is on) for escapeSeconds: it gives up.
	-- BR0: the persistent chase overrides the biome exit (only death or a safe zone ends it).
	local home = not Chase.persistent(e.beast) and Config.homeBiome("Root") or nil
	if home and type(target.biomes) == "table" and target.biomes[home] ~= true then
		e.outSince = e.outSince or now
		if not busy and now - e.outSince >= C.escapeSeconds then
			Attack.disengage(events, e, "LeftBiome", now, C.disengage)
			return
		end
	else
		e.outSince = nil
	end

	if e.phase == "Spawn" then
		Attack.phase(events, e, "Rise", e.phaseAt, e.phaseAt + C.spawnSeconds)
	end
	if e.phase == "Rise" and now - e.phaseAt >= C.spawnSeconds then
		Attack.phase(events, e, "SelectAttack", e.phaseAt + C.spawnSeconds)
	end
	if e.phase == "Burrow" and now - e.phaseAt >= C.burrowSeconds then
		Attack.phase(events, e, "SelectAttack", e.phaseAt + C.burrowSeconds)
	end
	if e.phase == "SelectAttack" and Attack.distance(e, target) > C.burrowReach then
		if not burrowCloser(events, e, now, target, world, C) then Attack.walk(e, target, 10, 1, dt, world) end
	end
	if e.phase == "SelectAttack" then
		Attack.face(e, target)
		local started = false
		if e.nextAttack == "walls" then
			started = startWalls(events, e, now, target, world, C, T)
			if started then e.nextAttack = "trap" end
		end
		if not started then
			started = startTrap(events, e, now, target, world, C, T)
			if started then e.nextAttack = "walls" end
		end
	end
	if e.phase == "TelegraphTrap" and now >= e.trap.strikeAt then
		Attack.phase(events, e, "Erupt", e.trap.strikeAt, e.trap.strikeAt + C.trapActiveSeconds)
	end
	if e.phase == "Erupt" then
		local attack = e.trap
		local closeAt = attack.strikeAt + C.trapActiveSeconds
		if not attack.done and now <= closeAt + 1e-9 and Attack.inside(attack.shape, target, e.pos.y, C.hitHeight) then
			Attack.hit(events, e, world, attack, now, { slow = { multiplier = T.TrapSlowMultiplier,
				seconds = T.TrapSlowSeconds } })
		end
		if now >= closeAt then
			if not attack.done then Attack.miss(events, e, world, attack, closeAt) end
			e.trap = nil
			recover(events, e, closeAt, T)
		end
	end
	if e.phase == "TelegraphWalls" and now >= e.walls.upAt then
		e.walls.up = true
		Attack.phase(events, e, "WallHold", e.walls.upAt, e.walls.downAt)
	end
	if e.phase == "WallHold" and now - e.phaseAt >= C.whipDelay then
		-- The first try starts on the planned instant; a staggered retry starts now. A whip that could no longer strike
		-- before the walls drop is skipped (never a strike after the enclosure is gone).
		local startAt = math.max(now - 0.05, e.phaseAt + C.whipDelay)
		local fits = startAt + C.whipTelegraph <= e.walls.downAt
		if not (fits and startWhip(events, e, startAt, world, C, T)) and (not fits or now >= e.walls.downAt) then
			emit(events, e, "TellEnd", now, { tell = e.id .. ":walls" })
			e.walls = nil
			recover(events, e, now, T)
		end
	end
	if e.phase == "WhipWindup" and now >= e.whip.strikeAt then
		local attack = e.whip
		if Attack.inside(attack.shape, target, attack.shape.y, C.hitHeight) then
			Attack.hit(events, e, world, attack, attack.strikeAt)
		else
			Attack.miss(events, e, world, attack, attack.strikeAt)
		end
		e.whip = nil
		Attack.phase(events, e, "WhipActive", attack.strikeAt, e.walls and e.walls.downAt or attack.strikeAt)
	end
	if e.phase == "WhipActive" and (not e.walls or now >= e.walls.downAt) then
		local at = e.walls and e.walls.downAt or now
		if e.walls then emit(events, e, "TellEnd", at, { tell = e.id .. ":walls" }) end
		e.walls = nil
		recover(events, e, at, T)
	end
	if e.phase == "Recovery" and now >= e.recoverUntil then
		Attack.phase(events, e, "SelectAttack", e.recoverUntil)
	end
end

return Root
