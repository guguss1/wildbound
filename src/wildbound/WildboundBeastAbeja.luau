-- Kids biome (odd/tasks/wildbound-kids-beasts.md; docs/design/wildbound-biome-pradera.md s6, adapted from
-- kids-biome-concepts/bee.md): La Abeja Reina, the event creature that guards La Colmena. Server only and pure, stepped
-- by WildboundBeastEncounters through Enc.register. She is summoned at La Colmena while the server's biome event window
-- is open (target.eventOpen) and the player is near; e.pos is the ground under her (she hovers tuning.HoverStuds up).
-- State machine:
--   Wake (Despierta: WakeSeconds, no notice, no strike) -> Guard (a loop of PatrolRadius around La Colmena at
--   PatrolSpeed) -> Heard (Te oyó: HeardSeconds still) -> Search (Te busca: SearchSpeed to the last heard point, kept
--   within LeashStuds of La Colmena) -> Telegraph (¡Zum! within DiveRange: a locked lane DiveLaneWidth x DiveLaneLength,
--   DiveTelegraphSeconds) -> strike (Picotazo only inside the lane) -> After (Después: AfterSeconds) -> Search ...
--   -> Lost (Te perdió: SearchMemorySeconds unheard) -> Guard. Ends: the window closes (Sleep, a SleepSeconds retreat,
--   End "EventEnded", every open attack cancelled), Escape (beyond EscapeDistance of La Colmena), the safe zone, death.
-- Sense: hearing only. target.noise is the server's noise radius (WildboundPraderaSites.noiseRadius); she hears the
-- target when it is inside GuardRadius of La Colmena and its noise radius reaches her.
-- Threat (kids rule): damage 0. The first sting asks BeastHit (the carried egg falls) and makes the target sticky
-- (event.sticky: WalkSpeed StickyWalkSpeed for StickySeconds, never lower, never raised); a sting while sticky
-- (target.stickyUntil) is Vuelo de vuelta: event.knock toward the Plaza del Molino.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Abeja = {}

local finite, flat, unit = Config.finite, Config.flat, Config.unit
local copy, emit = Attack.copy, Attack.emit

function Abeja.init(e)
	e.home = copy(e.pos)
	e.angle, e.heardAt = 0, -math.huge
end

-- Heard: inside the guard radius of La Colmena, with a noise radius that reaches her.
function Abeja.hears(e, target, T)
	if flat(e.home.x, e.home.z, target.x, target.z) > T.GuardRadiusStuds then return false end
	local noise = finite(target.noise) and target.noise or 0
	return noise > 0 and noise >= Attack.distance(e, target)
end

function Abeja.tellSeconds(T)
	return math.max(T.DiveTelegraphSeconds, Config.MIN_TELL)
end

local function clampToLeash(e, x, z, T)
	local d = flat(x, z, e.home.x, e.home.z)
	if d <= T.LeashStuds then return x, z end
	local ux, uz = unit(x - e.home.x, z - e.home.z)
	return e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
end

local function moveTo(e, x, z, speed, dt, world)
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	if not dx then return end
	local step = math.min(speed * dt, flat(e.pos.x, e.pos.z, x, z))
	e.pos.x += dx * step
	e.pos.z += dz * step
	e.pos.y = Attack.groundAt(world, e.pos.x, e.pos.z, e.pos.y)
	e.dx, e.dz = dx, dz
end

local function remember(e, now, target, T)
	e.heardAt = now
	local x, z = clampToLeash(e, target.x, target.z, T)
	e.lastHeard = { x = x, z = z }
end

local function retreat(events, e, world, now, phase, reason, seconds)
	Attack.closeAll(e, world)
	e.dive = nil
	if phase then Attack.phase(events, e, phase, now, now + seconds) end
	Attack.disengage(events, e, reason, now, seconds)
end

local function openDive(events, e, now, target, world, C, T)
	local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if not dx then dx, dz = e.dx, e.dz end
	e.dx, e.dz = dx, dz
	local strikeAt = now + Abeja.tellSeconds(T)
	local shape = { kind = "lane", ox = e.pos.x, oy = e.pos.y, oz = e.pos.z, dx = dx, dz = dz,
		length = T.DiveLaneLengthStuds, width = T.DiveLaneWidthStuds }
	local attack = Attack.open(events, e, world, { key = "dive", startAt = now, strikeAt = strikeAt, dodgeable = false,
		damage = C.damage, lockAt = now, shape = shape })
	if not attack then return false end
	Attack.lock(events, e, attack, nil, now)
	e.dive = attack
	Attack.phase(events, e, "Telegraph", now, strikeAt)
	return true
end

local function strike(events, e, now, target, world, C, T)
	local attack = e.dive
	local at = attack.strikeAt
	local shape = attack.shape
	if Attack.inside(shape, target, shape.oy, C.hitHeight) then
		local fields
		if finite(target.stickyUntil) and target.stickyUntil > at then
			-- Vuelo de vuelta: a second sting while sticky sends the target back toward the Plaza del Molino.
			local plaza = world.site and world.site("plaza")
			local kx, kz
			if plaza then kx, kz = unit(plaza.x - target.x, plaza.z - target.z) end
			if not kx then kx, kz = shape.dx, shape.dz end
			fields = { knock = { dx = kx, dz = kz, speed = T.FlyBackStudsPerSecond } }
		else
			fields = { sticky = { walkSpeed = T.StickyWalkSpeed, seconds = T.StickySeconds }, line = "Sticky" }
		end
		Attack.hit(events, e, world, attack, at, fields)
	else
		Attack.miss(events, e, world, attack, at)
	end
	-- The dive carries her along the lane she drew (never past the leash).
	emit(events, e, "Move", at, { kind = "dash", from = copy(e.pos), dx = shape.dx, dz = shape.dz,
		speed = T.DiveLaneLengthStuds / 0.4, length = T.DiveLaneLengthStuds })
	local x, z = clampToLeash(e, shape.ox + shape.dx * shape.length, shape.oz + shape.dz * shape.length, T)
	e.pos.x, e.pos.z = x, z
	e.pos.y = Attack.groundAt(world, x, z, e.pos.y)
	e.dive = nil
	Attack.phase(events, e, "After", at, at + T.AfterSeconds)
end

function Abeja.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.AbejaReina
	local T = C.tuning
	if Attack.guard(events, e, now, target, {}) then return end
	if target.eventOpen ~= true then
		-- Vuelve a dormir: the window closed; every open attack is cancelled.
		retreat(events, e, world, now, "Sleep", "EventEnded", T.SleepSeconds)
		return
	end
	if flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
		retreat(events, e, world, now, nil, "Escape", C.disengage)
		return
	end

	if e.phase == "Spawn" then Attack.phase(events, e, "Wake", e.phaseAt, e.phaseAt + T.WakeSeconds) end
	if e.phase == "Wake" then
		-- Despierta: no notice and no strike while she wakes.
		if now - e.phaseAt >= T.WakeSeconds then Attack.phase(events, e, "Guard", e.phaseAt + T.WakeSeconds) end
		return
	end
	local heard = Abeja.hears(e, target, T)
	if e.phase == "Guard" then
		if heard then
			remember(e, now, target, T)
			Attack.face(e, target)
			Attack.phase(events, e, "Heard", now, now + T.HeardSeconds)
			return
		end
		e.angle += T.PatrolSpeedStudsPerSecond / T.PatrolRadiusStuds * dt
		moveTo(e, e.home.x + math.cos(e.angle) * T.PatrolRadiusStuds, e.home.z + math.sin(e.angle) * T.PatrolRadiusStuds,
			T.PatrolSpeedStudsPerSecond, dt, world)
		return
	end
	if e.phase == "Heard" then
		if heard then remember(e, now, target, T) end
		if now - e.phaseAt >= T.HeardSeconds then Attack.phase(events, e, "Search", e.phaseAt + T.HeardSeconds) end
		return
	end
	if e.phase == "Search" then
		if heard then remember(e, now, target, T) end
		if now - e.heardAt >= T.SearchMemorySeconds then
			Attack.phase(events, e, "Lost", now, now + 1)
			Attack.phase(events, e, "Guard", now)
			return
		end
		if heard and Attack.distance(e, target) <= T.DiveRangeStuds then
			if openDive(events, e, now, target, world, C, T) then return end
		end
		if e.lastHeard then moveTo(e, e.lastHeard.x, e.lastHeard.z, T.SearchSpeedStudsPerSecond, dt, world) end
		return
	end
	if e.phase == "Telegraph" and e.dive and now >= e.dive.strikeAt then
		strike(events, e, now, target, world, C, T)
		return
	end
	if e.phase == "After" and now - e.phaseAt >= T.AfterSeconds then
		if heard then remember(e, now, target, T) end
		Attack.phase(events, e, "Search", e.phaseAt + T.AfterSeconds)
	end
end

return Abeja
