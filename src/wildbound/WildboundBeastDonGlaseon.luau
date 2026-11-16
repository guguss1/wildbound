-- Caramelo biome (pack 03_PERSONAJES/04_DON_GLASEON_BOSS.md; odd/tasks/wildbound-caramelo.md, CA3): Don Glaseon, the
-- territorial boss of the Gran Torta. Server only and pure, stepped by WildboundBeastEncounters through Enc.register,
-- on the WildboundBeastGomibu pattern, with its own code (nothing of La Silueta's). One boss per server: the director
-- refuses a second encounter while one lives (Config serverUnique), and the beast script picks its target among the
-- players in its territory (WildboundPraderaSites.bossPick: a rare-egg carrier first). It is summoned at BossHome and
-- every encounter ends there, walking (it never teleports); between encounters its model stands dormant at home.
-- e.dx, e.dz is where it faces; it turns at TurnDegreesPerSecond and never leaves the BossTerritory circle (the
-- builder's marker, world.site "bossTerritory"; without it, its home) nor steps into a safe zone (world.safe).
-- States:
--   Dormant (still at home) -> Patrol (a slow loop round home; bored after PatrolSeconds -> LoseTarget)
--   -> Suspicious (Notice: the target seen within PerceptionStuds with a clear line, heard running within NoiseStuds,
--      or a rare-egg carrier seen a little further) -> Roar (once per encounter, no effect) -> Chase (ChaseSpeed, at most
--      ChaseSeconds) -> Telegraph (Latigo de Regaliz, DG1: three lanes, left, right and centre, follow the target until
--      the lock at 0.35 s; 0.80 s) -> Attack (the three 0.35 s lashes back to back; each hits at its end, a target at
--      most once) -> Recover (1.0 s) -> Chase ...
--   Chase -> Search (the target out of sight: it walks to the last seen spot for SearchSeconds) -> Chase or LoseTarget.
--   DG2 Boca aspiradora: a target that stays out of the lash's reach (but within the vacuum's range, in front) for
--      Vacuum.CHASE_BEFORE_SECONDS gets Chase -> Inhale (a fixed cone, 0.9 s) -> Vacuum (2 s of Pull events toward him
--      while the target is in the cone with a clear line) -> Recover -> Chase. Rules: WildboundCandyDonGlaseonVacuum.
--   DG3 Muro de chocolate: while chasing, a target running away out of the lash's reach for Wall.OUT_OF_REACH_SECONDS
--      gets a ring of wall around the spot it runs to (a Tell of the shared walls shape: a crack line, then up, then a
--      TellEnd); the chase goes on. Rules: WildboundCandyDonGlaseonWall.
--   DG5 Rabia creciente: an anger meter rises while the target carries an egg in his territory and with each perfect
--      dodge of his lash; full, he rages (cooldowns halved) for a while. Anger events tell the clients (a red tint).
--      Rules: WildboundCandyDonGlaseonAnger.
--   DG6 Rugido de guardianes: his roar at a carrier of a Rara egg or better (the notice roar, or a new Roar mid-chase
--      when the egg shows later) emits Summon, once per chase; the beast script wakes fresh guardians round the thief.
--   LoseTarget (stops and looks at the exit, LoseTargetSeconds) -> Return (walks home at ReturnSpeed) -> End "Return".
--   The target dead, gone, in a safe zone or out of the territory (PF5: for LeftGraceSeconds in a row, so his own lash's
--   shove never ends it at once): an open lash is called off and it goes LoseTarget.
-- The attack's numbers and rules are WildboundCandyDonGlaseonAttack (one source). Damage 0: a hit is a Hit event, which
-- the beast script sends to BeastHit (the one egg drop path) with the push and, for a target without an egg, the slow.
-- The bat never targets beasts (WildboundBat is player against player), so it is immune by construction (batImmune).
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
local Latigo = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyDonGlaseonAttack"))
local Vacuum = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyDonGlaseonVacuum"))
local Wall = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyDonGlaseonWall"))
local Anger = require(DataModel:GetService("ServerStorage"):WaitForChild("WildboundCandyDonGlaseonAnger"))
-- OF3 (owner feedback 3): a sprint, predictive pursuit (his lash faces where the runner will be), side-steps, the dodge
local Smarts = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundCandySmarts"))
local Boss = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy
local RARE = { Rara = true, Epica = true, Legendaria = true }
-- DG6 Rugido de guardianes: at most once per chase, a roar at a carrier of a Rara egg or better asks the beast script
-- (a Summon event) for fresh candy guardians on a ring of ROAR_RING_STUDS round the thief (Director.roar).
Boss.ROAR_SUMMONS = table.freeze({ "Gomibu", "Flanfuria", "Tortidragon" })
Boss.ROAR_RING_STUDS = 12
local function rareCarrier(target) return target.carryingEgg == true and RARE[target.eggRarity] == true end
local function summon(events, e, at, target)
	e.summoned = true
	Attack.emit(events, e, "Summon", at, { names = Boss.ROAR_SUMMONS, x = target.x, z = target.z, ring = Boss.ROAR_RING_STUDS })
end

function Boss.init(e)
	e.home = copy(e.pos)
	e.readyAt = -math.huge
	e.vacuumReadyAt = -math.huge
	e.wallReadyAt = -math.huge
	e.anger = Anger.new()
	if not e.dx then e.dx, e.dz = 0, -1 end
end

function Boss.tellSeconds()
	return math.max(Latigo.TELEGRAPH_SECONDS + Latigo.RELEASE_SECONDS, Config.MIN_TELL)
end

-- A clear line from its eyes to the target (world.lineOfSight adds 2.5 studs to `from`); no adapter: clear.
local function visible(e, target, world, T)
	if type(world.lineOfSight) ~= "function" then return true end
	return world.lineOfSight({ x = e.pos.x, y = e.pos.y + T.EyeHeightStuds - 2.5, z = e.pos.z }, target) == true
end
local function heard(e, target, T)
	local speed = math.sqrt((target.vx or 0) ^ 2 + (target.vz or 0) ^ 2)
	return speed >= T.NoiseSpeedStuds and Attack.distance(e, target) <= T.NoiseStuds
end

-- Whether it notices the target now: seen within its sight (a rare-egg carrier a little further) or heard running.
function Boss.sees(e, target, world, T)
	if not target or target.alive ~= true or target.safe == true then return false end
	local range = RARE[target.eggRarity] and T.PerceptionStuds * T.RareSightScale or T.PerceptionStuds
	if Attack.distance(e, target) <= range and visible(e, target, world, T) then return true end
	return heard(e, target, T)
end
-- Whether it keeps track of a target it chases: in a longer sight with a clear line, or heard.
local function tracks(e, target, world, T)
	if Attack.distance(e, target) <= T.ChaseSightStuds and visible(e, target, world, T) then return true end
	return heard(e, target, T)
end

local function territory(e, world)
	if not e.territory then
		local site = type(world.site) == "function" and world.site("bossTerritory") or nil
		e.territory = site and { x = site.x, z = site.z } or { x = e.home.x, z = e.home.z }
	end
	return e.territory
end
local function inTerritory(e, world, p, T)
	local c = territory(e, world)
	return flat(c.x, c.z, p.x, p.z) <= T.TerritoryRadiusStuds
end
-- PF5 (odd/tasks/wildbound-caramelo-playfix.md): the target has left only after LeftGraceSeconds outside the territory
-- in a row, so the shove of his own lash (or a step over the edge) never ends the encounter in the same moment. PF5b
-- (walked Play): the ring of LeftMarginStuds past the edge (his lash's shove) still counts as his ground.
local function left(e, world, target, T, now)
	local c = territory(e, world)
	if flat(c.x, c.z, target.x, target.z) <= T.TerritoryRadiusStuds + (T.LeftMarginStuds or 0) then
		e.outsideSince = nil
		return false
	end
	e.outsideSince = e.outsideSince or now
	return now - e.outsideSince >= (T.LeftGraceSeconds or 0)
end

-- Turns the facing toward a point by at most TurnDegreesPerSecond * dt. Returns the angle left, in degrees.
local function turn(e, point, T, dt)
	local tx, tz = unit(point.x - e.pos.x, point.z - e.pos.z)
	if not tx then return 0 end
	local current, wanted = math.atan2(e.dz, e.dx), math.atan2(tz, tx)
	local delta = (wanted - current + math.pi) % (2 * math.pi) - math.pi
	local step = math.rad(T.TurnDegreesPerSecond) * (dt or 0)
	if math.abs(delta) <= step then
		e.dx, e.dz = tx, tz
		return 0
	end
	local angle = current + (delta > 0 and step or -step)
	e.dx, e.dz = math.cos(angle), math.sin(angle)
	return math.deg(math.abs(delta) - step)
end

-- Walks toward a point at `speed`, stopping `stop` studs short, turning as it goes; never out of the territory, never
-- into a safe zone. Returns the distance left.
local function walk(e, point, speed, dt, world, T, stop)
	local distance = flat(e.pos.x, e.pos.z, point.x, point.z)
	turn(e, point, T, dt)
	local step = math.min(speed * (dt or 0), math.max(0, distance - (stop or 0)))
	if step <= 0 then return distance end
	local ux, uz = Smarts.direction(e, world, point.x, point.z) -- OF3: round what blocks his way
	if not ux then return distance end
	local nx, nz = e.pos.x + ux * step, e.pos.z + uz * step
	local c = territory(e, world)
	local out = flat(c.x, c.z, nx, nz)
	if out > T.TerritoryRadiusStuds then
		local rx, rz = unit(nx - c.x, nz - c.z)
		nx, nz = c.x + rx * T.TerritoryRadiusStuds, c.z + rz * T.TerritoryRadiusStuds
	end
	if type(world.safe) == "function" and world.safe(nx, nz) then return distance end
	e.pos.x, e.pos.z = nx, nz
	e.pos.y = Attack.groundAt(world, nx, nz, e.pos.y)
	return flat(nx, nz, point.x, point.z)
end

-- Gives up the target: an open lash is called off (no strike), then it stops and looks at the exit before walking home.
local function lose(events, e, world, now, T, reason)
	for _, lash in ipairs(e.lashes or {}) do Attack.drop(events, e, world, lash, now, reason) end
	if e.vacuum then Attack.emit(events, e, "TellEnd", now, { tell = e.vacuumTell, reason = reason }) end
	if e.wall then Attack.emit(events, e, "TellEnd", now, { tell = e.wall.tell, reason = reason }) end
	e.lashes, e.cast, e.lanes, e.vacuum, e.wall = nil, nil, nil, nil, nil
	e.lostReason = reason
	Attack.phase(events, e, "LoseTarget", now, now + T.LoseTargetSeconds, { reason = reason })
end

local function origin(e) return { x = e.pos.x, y = e.pos.y, z = e.pos.z } end

-- DG1: one telegraphed attack per lash, all drawn at the start, each with its own lane and strike time.
local function openLash(events, e, now, world, C)
	local cast = Latigo.start(now, {})
	if not cast then return false end
	local lanes, lashes = Latigo.lanes(origin(e), e.dx, e.dz), {}
	for i = 1, Latigo.LASHES do
		local attack = Attack.open(events, e, world, { key = "lash" .. i, startAt = now, strikeAt = Latigo.impactAt(cast, i),
			dodgeable = true, damage = C.damage, lockAt = Latigo.lockAt(cast), shape = lanes[i] })
		if not attack then
			for _, open in ipairs(lashes) do Attack.drop(events, e, world, open, now, "Stagger") end
			return false
		end
		lashes[i] = attack
	end
	e.lashes, e.cast, e.lanes, e.lashIndex = lashes, cast, nil, 1
	Attack.phase(events, e, "Telegraph", now, Latigo.releaseAt(cast))
	return true
end

-- DG2: the vacuum's cone is a Tell with no strike (nothing to dodge, nothing lands); it is cleared with TellEnd.
local function openVacuum(events, e, now)
	local state = Vacuum.start(now, {})
	if not state then return false end
	e.vacuumCount = (e.vacuumCount or 0) + 1
	e.vacuum, e.cast, e.nextPullAt = state, nil, now
	e.vacuumTell = ("%s:vacuum:%d"):format(e.id, e.vacuumCount)
	Attack.emit(events, e, "Tell", now, { tell = e.vacuumTell, shape = Vacuum.cone(origin(e), e.dx, e.dz), startAt = now,
		strikeAt = Vacuum.pullEndsAt(state), lockAt = now, dodgeable = false, locked = true })
	Attack.phase(events, e, "Inhale", now, Vacuum.pullAt(state))
	return true
end

-- DG3: a ring of chocolate wall around the spot a runner is heading to. It is a Tell with no strike (it never hits);
-- the client raises it at strikeAt and it goes at its TellEnd. Returns true when a wall rose.
local function raiseWall(events, e, now, target, world)
	local shape = Wall.place(origin(e), target)
	local state = shape and Wall.start(now, {})
	if not state then return false end
	shape.y = Attack.groundAt(world, shape.x, shape.z, e.pos.y)
	e.wallCount = (e.wallCount or 0) + 1
	e.wall = { state = state, tell = ("%s:wall:%d"):format(e.id, e.wallCount) }
	e.wallReadyAt = Wall.downAt(state) + Wall.COOLDOWN_SECONDS * Anger.cooldownScale(e.anger, now)
	Attack.emit(events, e, "Tell", now, { tell = e.wall.tell, shape = shape, startAt = now, strikeAt = Wall.upAt(state),
		lockAt = now, dodgeable = false, locked = true })
	return true
end

local function impact(events, e, target, world, C, i)
	local cast, attack = e.cast, e.lashes[i]
	local at = Latigo.impactAt(cast, i)
	local lane = e.lanes and e.lanes[i] or attack.shape
	local high = math.abs((target.y or e.pos.y) - (lane.oy or e.pos.y)) > C.hitHeight
	local landed = Latigo.impact(cast, lane, { { id = 1, x = target.x, z = target.z, alive = target.alive == true,
		safe = target.safe == true or high, carrying = target.carryingEgg == true } }, i)[1]
	if landed then
		local verdict = Attack.hit(events, e, world, attack, at, { push = { dx = landed.push.dx, dz = landed.push.dz, studs = landed.push.studs,
			seconds = landed.push.seconds }, slow = landed.slowFactor and { multiplier = landed.slowFactor, seconds = landed.slowSeconds } or nil })
		-- DG5: a perfect dodge of a lash angers him
		if verdict == "Dodged" then
			local change = Anger.dodge(e.anger, at)
			if change then Attack.emit(events, e, "Anger", at, { value = change.value, rage = change.rage, untilAt = e.anger.rageUntil }) end
		end
	else
		Attack.miss(events, e, world, attack, at)
	end
end

local function chase(events, e, at)
	Attack.phase(events, e, "Chase", at)
	e.chaseAt = e.chaseAt or at
end

function Boss.step(events, e, now, target, world, dt)
	local C = Config.BEASTS.DonGlaseon
	local T = C.tuning
	if e.phase == "Spawn" then Attack.phase(events, e, "Dormant", e.phaseAt) end
	-- going home: nothing about the target matters any more
	if e.phase == "LoseTarget" then
		if now - e.phaseAt >= T.LoseTargetSeconds then Attack.phase(events, e, "Return", e.phaseAt + T.LoseTargetSeconds) end
		return
	end
	if e.phase == "Return" then
		if walk(e, e.home, T.ReturnSpeedStudsPerSecond, dt, world, T, 0) <= T.HomeToleranceStuds then
			table.insert(events, Attack.finish(e, "Return", now))
		end
		return
	end
	if not target or target.alive ~= true then lose(events, e, world, now, T, "Death") return end
	if target.safe == true then lose(events, e, world, now, T, "SafeZone") return end
	-- DG5: the anger meter, for a target carrying an egg in his territory
	local change = Anger.step(e.anger, now, target.carryingEgg == true and inTerritory(e, world, target, T))
	if change then Attack.emit(events, e, "Anger", now, { value = change.value, rage = change.rage, untilAt = e.anger.rageUntil }) end
	-- DG3: a wall goes down on its own time, whatever he is doing
	if e.wall and now >= Wall.downAt(e.wall.state) then
		Attack.emit(events, e, "TellEnd", Wall.downAt(e.wall.state), { tell = e.wall.tell, reason = "Done" })
		e.wall = nil
	end

	if e.phase == "Dormant" or e.phase == "Patrol" then
		if left(e, world, target, T, now) then lose(events, e, world, now, T, "Left") return end
		if Boss.sees(e, target, world, T) then
			e.lastSeen = { x = target.x, z = target.z }
			turn(e, target, T, dt)
			Attack.phase(events, e, "Suspicious", now, now + T.NoticeSeconds)
			return
		end
		if e.phase == "Dormant" then
			if now - e.phaseAt >= T.DormantSeconds then Attack.phase(events, e, "Patrol", now, now + T.PatrolSeconds) end
			return
		end
		if now - e.phaseAt >= T.PatrolSeconds then lose(events, e, world, now, T, "Bored") return end
		local a = (now - e.phaseAt) * T.PatrolSpeedStudsPerSecond / T.PatrolRadiusStuds
		walk(e, { x = e.home.x + math.cos(a) * T.PatrolRadiusStuds, z = e.home.z + math.sin(a) * T.PatrolRadiusStuds },
			T.PatrolSpeedStudsPerSecond, dt, world, T, 0)
		return
	end
	if e.phase == "Suspicious" then
		turn(e, target, T, dt)
		if now - e.phaseAt >= T.NoticeSeconds then
			local at = e.phaseAt + T.NoticeSeconds
			if not e.roared then
				e.roared = true
				Attack.phase(events, e, "Roar", at, at + T.RoarSeconds)
				if rareCarrier(target) then summon(events, e, at, target) end
			else
				chase(events, e, at)
			end
		end
		return
	end
	if e.phase == "Roar" then
		turn(e, target, T, dt)
		if now - e.phaseAt >= T.RoarSeconds then chase(events, e, e.phaseAt + T.RoarSeconds) end
		if e.phase ~= "Chase" then return end
	end
	if e.phase == "Chase" or e.phase == "Search" then
		if now - e.chaseAt >= T.ChaseSeconds then lose(events, e, world, now, T, "Tired") return end
		if left(e, world, target, T, now) then lose(events, e, world, now, T, "Left") return end
		local seen = tracks(e, target, world, T)
		if seen then e.lastSeen = { x = target.x, z = target.z } end
		if e.phase == "Search" then
			if seen then
				Attack.phase(events, e, "Chase", now)
			elseif now - e.phaseAt >= T.SearchSeconds then
				lose(events, e, world, now, T, "Lost")
				return
			else
				walk(e, e.lastSeen or e.home, T.PatrolSpeedStudsPerSecond, dt, world, T, 0)
				return
			end
		end
		if not seen then
			Attack.phase(events, e, "Search", now, now + T.SearchSeconds)
			return
		end
		-- DG6: a target who shows a rare egg mid-chase gets the guardians' roar, once per chase
		if not e.summoned and rareCarrier(target) then
			Attack.phase(events, e, "Roar", now, now + T.RoarSeconds)
			summon(events, e, now, target)
			return
		end
		local distance = Attack.distance(e, target)
		local fx, fz = unit(target.x - e.pos.x, target.z - e.pos.z)
		local facing = fx and math.deg(math.acos(math.clamp(fx * e.dx + fz * e.dz, -1, 1))) or 0
		-- a lash starts only at a target in front, in reach, after the cooldown and with time left in the chase
		if distance <= T.CastRangeStuds and now >= e.readyAt and facing <= T.CastHalfAngleDegrees
			and now - e.chaseAt + Latigo.comboSeconds() <= T.ChaseSeconds then
			if openLash(events, e, now, world, C) then return end
		end
		-- DG2: a target that keeps out of the lash's reach is reeled in by the vacuum mouth
		if distance <= T.CastRangeStuds then e.outOfReachSince = nil else e.outOfReachSince = e.outOfReachSince or now end
		-- DG3: a runner out of reach gets a wall across its route; the chase goes on
		if e.outOfReachSince and not e.wall and now - e.outOfReachSince >= Wall.OUT_OF_REACH_SECONDS
			and distance <= Wall.RANGE_STUDS and now >= e.wallReadyAt then
			raiseWall(events, e, now, target, world)
		end
		if e.outOfReachSince and now - e.outOfReachSince >= Vacuum.CHASE_BEFORE_SECONDS and distance <= Vacuum.RANGE_STUDS
			and facing <= Vacuum.ARC_DEGREES / 2 and now >= e.vacuumReadyAt
			and now - e.chaseAt + Vacuum.totalSeconds() <= T.ChaseSeconds then
			if openVacuum(events, e, now) then return end
		end
		-- OF3: a dodge stops him a moment; else he runs (a sprint at first) for the lead or flank point
		if Smarts.dodged(e, world, now, target) then turn(e, target, T, dt) return end
		local gx, gz = Smarts.goal(e, world, now, target)
		walk(e, { x = gx, z = gz }, Smarts.speed(e, now, T.ChaseSpeedStudsPerSecond, target), dt, world, T, T.StandOffStuds)
		return
	end
	if (e.phase == "Inhale" or e.phase == "Vacuum") and e.vacuum then
		if left(e, world, target, T, now) then lose(events, e, world, now, T, "Left") return end
		local state = e.vacuum
		if e.phase == "Inhale" then
			if now < Vacuum.pullAt(state) then return end
			Attack.phase(events, e, "Vacuum", Vacuum.pullAt(state), Vacuum.pullEndsAt(state))
		end
		if now < Vacuum.pullEndsAt(state) then
			if now >= e.nextPullAt then
				local pull = Vacuum.pull(state, now, origin(e), e.dx, e.dz, target, visible(e, target, world, T))
				if pull then
					e.nextPullAt = now + Vacuum.REFRESH_SECONDS
					Attack.emit(events, e, "Pull", now, { dx = pull.dx, dz = pull.dz, speed = pull.speed, untilAt = pull.untilAt })
				end
			end
			return
		end
		Attack.emit(events, e, "TellEnd", Vacuum.pullEndsAt(state), { tell = e.vacuumTell, reason = "Done" })
		e.vacuumReadyAt = Vacuum.endsAt(state) + Vacuum.COOLDOWN_SECONDS * Anger.cooldownScale(e.anger, now)
		Attack.phase(events, e, "Recover", Vacuum.pullEndsAt(state), Vacuum.endsAt(state))
		return
	end
	if e.phase == "Recover" and e.vacuum then
		local endAt = Vacuum.endsAt(e.vacuum)
		if now >= endAt then
			e.vacuum, e.outOfReachSince = nil, nil
			Attack.phase(events, e, "Chase", endAt)
		end
		return
	end
	if e.phase == "Telegraph" and e.lashes then
		local cast = e.cast
		if not e.lanes then
			if now < Latigo.lockAt(cast) then
				-- the lanes follow the target until the lock
				turn(e, target, T, dt)
				local lanes = Latigo.lanes(origin(e), e.dx, e.dz)
				for i, lash in ipairs(e.lashes) do Attack.aim(events, e, lash, lanes[i], now) end
				return
			end
			e.lanes = Latigo.lanes(origin(e), e.dx, e.dz)
			for i, lash in ipairs(e.lashes) do Attack.lock(events, e, lash, e.lanes[i], Latigo.lockAt(cast)) end
		end
		if now < Latigo.releaseAt(cast) then return end
		Attack.phase(events, e, "Attack", Latigo.releaseAt(cast), Latigo.impactAt(cast))
	end
	if e.phase == "Attack" and e.lashes then
		-- every lash whose end has come lands, in order; the recovery starts after the last one
		while e.lashIndex <= Latigo.LASHES and now >= Latigo.impactAt(e.cast, e.lashIndex) do
			impact(events, e, target, world, C, e.lashIndex)
			e.lashIndex += 1
		end
		if e.lashIndex <= Latigo.LASHES then return end
		e.lashes = nil
		e.readyAt = Latigo.endsAt(e.cast) + Latigo.COOLDOWN_SECONDS * Anger.cooldownScale(e.anger, now)
		Attack.phase(events, e, "Recover", Latigo.impactAt(e.cast), Latigo.endsAt(e.cast))
		return
	end
	if e.phase == "Recover" and e.cast and now >= Latigo.endsAt(e.cast) then
		Attack.phase(events, e, "Chase", Latigo.endsAt(e.cast))
	end
end

return Boss
