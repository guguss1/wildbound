-- Caramelo biome (odd/tasks/wildbound-candy-critters.md, CC2-CC3): one data-driven brain for the five small candy
-- creatures (Mochimiau, Canelin, Flanin, Mielita, GatoRepartidor). Server only and pure, stepped by
-- WildboundBeastEncounters through Enc.register (one module, five names: it reads Config.BEASTS[e.beast]). Built on
-- WildboundBeastAttack the way WildboundBeastGomibu is. Each one is summoned at its fixed post (Director.summon, points
-- 0) and lives there; e.pos is the ground under it (Mielita: HoverStuds over it). State machine:
--   Patrol / Calm (walks between points within PatrolRadiusStuds of home as Patrol, pausing at each as Calm; both calm
--      phases for the portal; PF2: unvisited for IdleSeconds it walks home and ends "Idle")
--   -> Notice (AlertSeconds still, after the target comes within PerceptionStuds)
--   -> Chase (ChaseSpeed, never past LeashStuds from home)
--   -> Telegraph (one attack within Attack.RangeStuds; tell never under Config.MIN_TELL, and the shape is locked at
--      least MIN_TELL before the strike) -> Release (Attack.TravelSeconds: the hop, roll, wave or throw; the strike
--      is its end) -> Recover (Attack.RecoverSeconds) -> Chase ...
--   -> GiveUp: the target past AbandonStuds, or the creature held at its leash with the target out of attack range
--      for GiveUpSeconds. PF3 (odd/tasks/wildbound-caramelo-playfix.md): it walks home (Return, reason GiveUp) and the
--      encounter ends at its post with no fade, where its resting copy stands; the next summon starts there in Patrol.
--   Escape: the target outside EscapeDistance of home for EscapeSeconds: the same walk home (reason Escape). Death and
--   the safe zone end it at once (Attack.guard).
--   RC (owner request 2026-11-16, WildboundCandySmarts.RELENTLESS): once it notices (Smarts.engage, at most maxChasers
--   per player) it hunts: the leash, the abandon distance, the held-at-leash give-up and the escape no longer apply; only
--   the safe zone, death, a leave or the hard limit (180 s, reason Timeout) end it, and an ending farther than fadeStuds
--   from home fades out (Disengage) instead of the walk home.
-- Attack kinds (tuning.Attack.kind):
--   leap  a circle of RadiusStuds on the target that follows it until LockSeconds; the creature hops there.
--   dash  a lane LengthStuds x WidthStuds forward from the creature, aimed until LockSeconds; it rolls along it.
--   burst a circle of RadiusStuds on the creature, locked at once; it stays put.
--   lob   a circle of RadiusStuds on the target that follows it until LockSeconds; the creature stays put.
-- Threat (OF2): the hit carries Config.BEASTS[name].damage, which the beast script sends to BeastHit with the egg kept;
-- the side attacks and patches never damage. A hit carries a slow (SlowMultiplier, SlowSeconds) and, when PushStuds > 0, a push away from the
-- shape (event.push, applied by the server); the egg stays (keepsEgg: the beast script skips BeastHit). After a strike
-- it opens no other attack for CooldownSeconds (counted from the strike, the recovery included).
-- A2 (odd/tasks/wildbound-caramelo-playfix.md): the "Otras habilidades" of each creature sheet, as data on its tuning
-- (tuning.Extras), all with damage 0:
--   Puddle (Mochimiau) a patch of RadiusStuds where its leap lands, for LifeSeconds.
--   Trail  (Canelin on its roll, Phase "Release"; Flanin and Mielita while chasing, Phase "Chase") a patch every
--          SpacingStuds along its way.
--   Follow (Mochimiau's second hop, Flanin's bounces) up to Max more attacks right after the recovery, each with its
--          full tell, while the target stays within RangeStuds; then CooldownSeconds from the chain's last strike.
--   Swarm  (Mielita) every EverySeconds of a chase (the first FirstSeconds after it starts), Puffs pollen circles
--          OffsetStuds beside the target, locked at once; a puff slows (an Afflict), never pushes.
--   Gift   (GatoRepartidor) one encounter in Every (by its number, "beast:<n>"): it walks up to HandStuds, stands
--          "Deliver" for HandSeconds, hands a golden order (a "Gift" event: the server raises the walk speed by
--          Multiplier for Seconds) and walks home ("Delivered"). It never attacks in that encounter.
--   Call   (GatoRepartidor) every EverySeconds of a chase a helper Gato appears RingStuds beside the target (a "Helper"
--          event the server draws), throws fries once on the target (a circle locked at once) and leaves.
-- Patches are "Patch" events (the beast server lays a fading flat part every player sees); the slow is the server's:
-- while the target stands in a live patch the brain emits an Afflict (applySlow: clamped by WildboundBeastChase.EFFECTS
-- and never stacked), at most once per SlowSeconds + PATCH_GAP.
local DataModel = script:FindFirstAncestorOfClass("DataModel") :: any
local Config = require(DataModel:GetService("ReplicatedStorage"):WaitForChild("WildboundBeastConfig"))
local Attack = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundBeastAttack"))
-- OF3 (owner feedback 3): the sprint, the lead, flanking, side-steps, the dodge pause and the call to allies
local Smarts = require(DataModel:GetService("ServerScriptService"):WaitForChild("WildboundCandySmarts"))
local Critter = {}

local flat, unit = Config.flat, Config.unit
local copy = Attack.copy
local GOLDEN = math.pi * (3 - math.sqrt(5)) -- the patrol's next heading: spread round home without a random source
local LEASH_EDGE = 0.05 -- studs: this close to LeashStuds from home counts as held at the leash
local PATCH_GAP = 0.3 -- seconds between the end of one patch slow and the next (applySlow restores by a delayed task)
local PATCH_MAX = 16 -- live patches kept per encounter (the oldest goes first)
local GIFT_SLACK = 3 -- studs: the order is handed over if the target is still this close past HandStuds
local NONE = table.freeze({})

local function extras(T) return T.Extras or NONE end

function Critter.tellSeconds(A)
	return math.max(A.TelegraphSeconds, Config.MIN_TELL)
end

local function hover(e, T)
	return e.hover and (T.HoverStuds or 0) or 0
end

-- The ground under (x, z) plus the hover height.
local function settle(e, world, T, x, z)
	local h = hover(e, T)
	e.pos.x, e.pos.z = x, z
	e.pos.y = Attack.groundAt(world, x, z, e.pos.y - h) + h
end

function Critter.init(e)
	local C = Config.BEASTS[e.beast]
	e.hover = C and C.grounded ~= true or false
	e.home = copy(e.pos)
	if e.hover then e.pos.y += C.tuning.HoverStuds or 0 end
	e.readyAt = -math.huge
	e.patrolIndex = 0
	-- A2: a gift encounter (the Gato, one in Gift.Every by the encounter's number)
	local G = C and C.tuning.Extras and C.tuning.Extras.Gift
	local number = tonumber(string.match(tostring(e.id), "(%d+)$"))
	e.gift = (G ~= nil and number ~= nil and number % G.Every == 0) or nil
end

function Critter.sees(e, target, T)
	return Attack.distance(e, target) <= T.PerceptionStuds
end

-- Clamps a point to the leash round home (RC1: no leash while it hunts, Smarts.hunting).
local function leashed(e, T, x, z)
	local d = flat(x, z, e.home.x, e.home.z)
	if d > T.LeashStuds and not Smarts.hunting(e) then
		local ux, uz = unit(x - e.home.x, z - e.home.z)
		return e.home.x + ux * T.LeashStuds, e.home.z + uz * T.LeashStuds
	end
	return x, z
end

-- Moves toward (x, z) at speed for dt; returns true on arrival.
local function walkTo(e, world, T, x, z, speed, dt)
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance <= 1e-3 then return true end
	local dx, dz = unit(x - e.pos.x, z - e.pos.z)
	local step = math.min(speed * dt, distance)
	settle(e, world, T, e.pos.x + dx * step, e.pos.z + dz * step)
	e.dx, e.dz = dx, dz
	return step >= distance - 1e-6
end

-- Where a target circle goes: on the target, or RangeStuds away from the creature in its direction; never past the
-- leash for a leap (the creature lands there). OF3: a leap or a lob aims where the target will be (Smarts.lead).
local function aimPoint(e, target, T, A, now)
	local x, z = target.x, target.z
	if now then x, z = Smarts.lead(e, target, now, Smarts.profile(e.beast).aimLead) end
	local distance = flat(e.pos.x, e.pos.z, x, z)
	if distance > A.RangeStuds then
		local ux, uz = unit(x - e.pos.x, z - e.pos.z)
		x, z = e.pos.x + ux * A.RangeStuds, e.pos.z + uz * A.RangeStuds
	end
	if A.kind == "leap" then x, z = leashed(e, T, x, z) end
	return x, z
end

-- The longest roll along (dx, dz) from the creature that stays inside the leash (at most LengthStuds).
local function laneLength(e, T, A, dx, dz)
	if Smarts.hunting(e) then return A.LengthStuds end -- RC1: no leash while it hunts
	local ox, oz = e.pos.x - e.home.x, e.pos.z - e.home.z
	local b = ox * dx + oz * dz
	local c = ox * ox + oz * oz - T.LeashStuds * T.LeashStuds
	local reach = -b + math.sqrt(math.max(b * b - c, 0))
	return math.clamp(reach, 0, A.LengthStuds)
end

local function shapeFor(e, target, world, T, A, now)
	if A.kind == "dash" then
		local dx, dz = unit(target.x - e.pos.x, target.z - e.pos.z)
		if not dx then dx, dz = e.dx, e.dz end
		return { kind = "lane", ox = e.pos.x, oy = e.pos.y - hover(e, T), oz = e.pos.z, dx = dx, dz = dz,
			length = laneLength(e, T, A, dx, dz), width = A.WidthStuds }
	end
	if A.kind == "burst" then
		return { kind = "circle", x = e.pos.x, y = e.pos.y - hover(e, T), z = e.pos.z, r = A.RadiusStuds }
	end
	local x, z = aimPoint(e, target, T, A, now)
	return { kind = "circle", x = x, y = Attack.groundAt(world, x, z, target.y - 3), z = z, r = A.RadiusStuds }
end

local function closeAttack(e, world)
	Attack.closeAll(e, world)
	e.attack, e.side = nil, nil
end

-- A2: a patch (puddle or trail piece) on the ground at (x, y, z), live for P.LifeSeconds.
local function lay(events, e, now, P, x, y, z)
	e.patches = e.patches or {}
	if #e.patches >= PATCH_MAX then table.remove(e.patches, 1) end
	local patch = { x = x, y = y, z = z, r = P.RadiusStuds, untilAt = now + P.LifeSeconds, slow = P.SlowMultiplier,
		seconds = P.SlowSeconds }
	table.insert(e.patches, patch)
	Attack.emit(events, e, "Patch", now, { x = x, y = y, z = z, r = P.RadiusStuds, life = P.LifeSeconds, untilAt = patch.untilAt })
end

-- A2: a trail piece where the creature stands, once it is SpacingStuds past the last one.
local function trail(events, e, now, T, P)
	local last = e.trailLast
	if last and flat(e.pos.x, e.pos.z, last.x, last.z) < P.SpacingStuds - 1e-6 then return end
	e.trailLast = { x = e.pos.x, z = e.pos.z }
	lay(events, e, now, P, e.pos.x, e.pos.y - hover(e, T), e.pos.z)
end

-- A2: the server's slow on a target standing in a live patch (never stacked: one per SlowSeconds + PATCH_GAP).
local function stickyPatches(events, e, now, target, C)
	local patches = e.patches
	if not patches then return end
	for i = #patches, 1, -1 do
		if now >= patches[i].untilAt then table.remove(patches, i) end
	end
	if now < (e.slowFreeAt or -math.huge) or target.safe == true then return end
	-- A2 review: never while its own attack is open (Canelin's first glaze piece pre-empted its roll's -30 %)
	if e.attack then return end
	for _, p in ipairs(patches) do
		if flat(target.x, target.z, p.x, p.z) <= p.r and math.abs(target.y - p.y) <= C.hitHeight then
			e.slowFreeAt = now + p.seconds + PATCH_GAP
			Attack.emit(events, e, "Afflict", now, { slow = p.slow, slowSeconds = p.seconds, patch = true })
			return
		end
	end
end

-- A2: a side attack (Swarm, Call) beside the main one: its shape is locked at once, its strike at least MIN_TELL later.
local function sideOpen(events, e, world, now, key, shape, tell)
	local attack = Attack.open(events, e, world, { key = key, startAt = now, strikeAt = now + math.max(tell, Config.MIN_TELL),
		dodgeable = false, damage = 0, lockAt = now, shape = shape })
	if attack then Attack.lock(events, e, attack, nil, now) end
	return attack
end

-- A2: settles the side attack on the step its strike comes, whatever phase the creature is in.
local function sideSettle(events, e, world, now, target, C)
	local side = e.side
	if not side or now < side.attack.strikeAt then return end
	e.side = nil
	local attack, S = side.attack, side.spec
	local shape = attack.shape
	local floor = shape.kind == "multi" and shape.list[1].y or shape.y
	if Attack.inside(shape, target, floor, C.hitHeight) and target.safe ~= true then
		if side.kind == "swarm" then
			Attack.afflict(events, e, world, attack, attack.strikeAt, { slow = S.SlowMultiplier, slowSeconds = S.SlowSeconds })
		else
			local kx, kz = unit(target.x - side.fromX, target.z - side.fromZ)
			Attack.hit(events, e, world, attack, attack.strikeAt, {
				slow = { multiplier = S.SlowMultiplier, seconds = S.SlowSeconds },
				push = { dx = kx or e.dx, dz = kz or e.dz, studs = S.PushStuds, seconds = S.PushSeconds } })
		end
	else
		Attack.miss(events, e, world, attack, attack.strikeAt)
	end
	e[side.kind .. "At"] = attack.strikeAt + S.EverySeconds
end

-- A2: opens the Swarm or the Call when its clock is due and the target is in reach (Chase only).
local function sideAttacks(events, e, world, now, target, T)
	if e.side then return end
	local X = extras(T)
	local distance = Attack.distance(e, target)
	local fx, fz = unit(target.x - e.pos.x, target.z - e.pos.z)
	if not fx then fx, fz = e.dx or 0, e.dz or 1 end
	local px, pz = -fz, fx -- across the creature's line to the target
	local groundY = Attack.groundAt(world, target.x, target.z, target.y - 3)
	local S = X.Swarm
	if S and now >= (e.swarmAt or math.huge) and distance <= S.RangeStuds then
		local list = {}
		for i = 1, S.Puffs do
			local away = S.OffsetStuds * math.ceil(i / 2) * (i % 2 == 1 and 1 or -1)
			table.insert(list, { kind = "circle", x = target.x + px * away, y = groundY, z = target.z + pz * away, r = S.RadiusStuds })
		end
		local attack = sideOpen(events, e, world, now, "swarm", { kind = "multi", list = list }, S.TellSeconds)
		if attack then e.side = { kind = "swarm", attack = attack, spec = S } end
		return
	end
	local K = X.Call
	if K and not e.gift and now >= (e.callAt or math.huge) and distance <= K.RangeStuds then
		local hx, hz = target.x + px * K.RingStuds, target.z + pz * K.RingStuds
		local attack = sideOpen(events, e, world, now, "call",
			{ kind = "circle", x = target.x, y = groundY, z = target.z, r = K.RadiusStuds }, K.TellSeconds)
		if attack then
			e.side = { kind = "call", attack = attack, spec = K, fromX = hx, fromZ = hz }
			local dx, dz = unit(target.x - hx, target.z - hz)
			Attack.emit(events, e, "Helper", now, { x = hx, y = Attack.groundAt(world, hx, hz, target.y - 3), z = hz,
				dx = dx, dz = dz, throwAt = attack.strikeAt, untilAt = now + K.StaySeconds })
		end
	end
end

-- PF3 (odd/tasks/wildbound-caramelo-playfix.md): every calm ending walks home first (Return, a calm phase) and the
-- encounter ends there with no fade, where its resting copy stands between encounters (WildboundCandyResting).
local function goHome(events, e, world, now, reason)
	closeAttack(e, world)
	e.returnReason = reason
	e.waypoint, e.waitUntil, e.pinnedSince, e.farSince, e.patrolSince = nil, nil, nil, nil, nil
	-- RC3: a hunt that ended far from its post fades out there (the shared Disengage fade); its resting copy is back home
	if Smarts.farFromHome(e) then
		Attack.disengage(events, e, reason, now, Config.BEASTS[e.beast].disengage)
		return
	end
	Attack.phase(events, e, "Return", now, nil, { reason = reason })
end

local function openAttack(events, e, now, target, world, C, T, A)
	local shape = shapeFor(e, target, world, T, A, now)
	if shape.kind == "lane" and shape.length < 2 then return false end -- at the end of its leash: no room to roll
	local release = now + Critter.tellSeconds(A)
	local lockAt = A.kind == "burst" and now or now + A.LockSeconds
	local attack = Attack.open(events, e, world, { key = A.kind, startAt = now, strikeAt = release + A.TravelSeconds,
		dodgeable = false, damage = C.damage, lockAt = lockAt, shape = shape })
	if not attack then return false end
	e.attack, e.releaseAt, e.lockAt = attack, release, lockAt
	-- A2 Follow: a fresh attack starts a chain of up to Max follow-ups; a follow-up uses one
	local F = extras(T).Follow
	if F then
		if e.following then e.followLeft -= 1 else e.followLeft = F.Max end
		e.following = false
	end
	if A.kind == "burst" then Attack.lock(events, e, attack, nil, now) end
	Attack.face(e, target)
	Attack.phase(events, e, "Telegraph", now, release)
	return true
end

local function strike(events, e, target, world, C, T, A)
	local attack = e.attack
	local at = attack.strikeAt
	local shape = attack.shape
	local floor = shape.kind == "lane" and shape.oy or shape.y
	if Attack.inside(shape, target, floor, C.hitHeight) and target.safe ~= true then
		local fields = { slow = { multiplier = A.SlowMultiplier, seconds = A.SlowSeconds } }
		if (A.PushStuds or 0) > 0 then
			local kx, kz
			if shape.kind == "lane" then
				kx, kz = shape.dx, shape.dz
			else
				kx, kz = unit(target.x - shape.x, target.z - shape.z)
			end
			fields.push = { dx = kx or e.dx, dz = kz or e.dz, studs = A.PushStuds, seconds = A.PushSeconds }
		end
		Attack.hit(events, e, world, attack, at, fields)
	else
		Attack.miss(events, e, world, attack, at)
	end
	e.attack = nil
	-- A2 Puddle: where the leap lands, hit or miss
	local X = extras(T)
	if X.Puddle and shape.kind == "circle" then lay(events, e, at, X.Puddle, shape.x, shape.y, shape.z) end
	-- A2 Follow: another attack right after the recovery while follow-ups are left; else the cooldown
	e.lastStrikeAt = at
	if X.Follow and (e.followLeft or 0) > 0 then
		e.following = true
		e.readyAt = at + A.RecoverSeconds
	else
		e.following = false
		e.readyAt = at + A.CooldownSeconds
	end
	Attack.phase(events, e, "Recover", at, at + A.RecoverSeconds)
end

-- PF2: it walks to a point ("Patrol": the walk clip) and stands there a moment ("Calm": the idle loop).
local function patrol(events, e, now, world, T, dt)
	if e.waitUntil and now < e.waitUntil then return end
	if e.waitUntil then
		e.waitUntil = nil
		Attack.phase(events, e, "Patrol", now)
	end
	if not e.waypoint then
		e.patrolIndex += 1
		local angle = e.patrolIndex * GOLDEN
		local radius = T.PatrolRadiusStuds * (0.45 + 0.55 * ((e.patrolIndex * 0.618) % 1))
		e.waypoint = { x = e.home.x + math.cos(angle) * radius, z = e.home.z + math.sin(angle) * radius }
	end
	if walkTo(e, world, T, e.waypoint.x, e.waypoint.z, T.PatrolSpeedStudsPerSecond, dt) then
		e.waypoint = nil
		e.waitUntil = now + (T.PatrolPauseSeconds or 1.5)
		Attack.phase(events, e, "Calm", now, e.waitUntil)
	end
end

function Critter.step(events, e, now, target, world, dt)
	local C = Config.BEASTS[e.beast]
	local T = C.tuning
	local A = T.Attack
	if Attack.guard(events, e, now, target, {}) then
		if e.done then e.attack, e.side = nil, nil end
		return
	end
	local X = extras(T)
	stickyPatches(events, e, now, target, C) -- A2: a live puddle or trail slows even while it walks home
	-- PF3: walking home (nothing about the target matters any more); the encounter ends at its post, with no fade
	if e.phase == "Return" then
		local speed = T.ReturnSpeedStudsPerSecond or T.ChaseSpeedStudsPerSecond * 0.75
		if walkTo(e, world, T, e.home.x, e.home.z, speed, dt) then
			e.dx, e.dz = 0, 1 -- the resting copy's facing
			table.insert(events, Attack.finish(e, e.returnReason or "Done", now))
		end
		return
	end
	sideSettle(events, e, world, now, target, C) -- A2: the swarm's puffs or the helper's fries land on their own clock
	-- RC1: a relentless hunt has one hard limit (Smarts.RELENTLESS.hardSeconds); it ends like a give-up
	if Smarts.overtime(e, now) then
		goHome(events, e, world, now, "Timeout")
		return
	end
	-- RC1: the escape distance only sends home a calm creature whose visitor walked away, never one that hunts
	if not Smarts.hunting(e) and flat(e.home.x, e.home.z, target.x, target.z) > T.EscapeDistanceStuds then
		e.farSince = e.farSince or now
	else
		e.farSince = nil
	end
	if e.farSince and now - e.farSince >= T.EscapeSeconds then
		goHome(events, e, world, now, "Escape")
		return
	end

	if e.phase == "Spawn" then Attack.phase(events, e, "Patrol", e.phaseAt) end
	if e.phase == "Patrol" or e.phase == "Calm" then
		-- OF3: it also notices a target near its post (Smarts.guards) or when a nearby ally calls; one that saw it calls
		local saw = Critter.sees(e, target, T) or Smarts.guards(e, target)
		-- RC4: it starts its hunt only while fewer than Smarts.RELENTLESS.maxChasers hunt this player
		if (saw or Smarts.called(e, world, now)) and Smarts.engage(e, world, now) then
			if saw then Smarts.alarm(e, world, now) end
			e.waypoint, e.waitUntil, e.patrolSince = nil, nil, nil
			Attack.face(e, target)
			Attack.phase(events, e, "Notice", now, now + T.AlertSeconds)
			return
		end
		-- PF2: nobody came near for IdleSeconds: home, quietly (the next summon starts it again)
		e.patrolSince = e.patrolSince or now
		if T.IdleSeconds and now - e.patrolSince >= T.IdleSeconds then
			goHome(events, e, world, now, "Idle")
			return
		end
		patrol(events, e, now, world, T, dt)
		return
	end
	if e.phase == "Notice" then
		Attack.face(e, target)
		if now - e.phaseAt >= T.AlertSeconds then
			local at = e.phaseAt + T.AlertSeconds
			-- A2: the side attacks' first clocks start with the chase
			if X.Swarm and not e.swarmAt then e.swarmAt = at + X.Swarm.FirstSeconds end
			if X.Call and not e.callAt then e.callAt = at + X.Call.FirstSeconds end
			Attack.phase(events, e, "Chase", at)
		end
		return
	end
	Smarts.track(e, world, now) -- OF3: hunting this player (flanking)
	-- A2 Gift: it stands with the order for HandSeconds, hands it over and walks home
	if e.phase == "Deliver" then
		local G = X.Gift
		Attack.face(e, target)
		if now - e.phaseAt < G.HandSeconds then return end
		if Attack.distance(e, target) <= G.HandStuds + GIFT_SLACK then
			Attack.emit(events, e, "Gift", now, { multiplier = G.Multiplier, seconds = G.Seconds })
			e.gift = nil
			goHome(events, e, world, now, "Delivered")
		else
			Attack.phase(events, e, "Chase", now)
		end
		return
	end
	if e.phase == "Chase" then
		local distance = Attack.distance(e, target)
		local hunting = Smarts.hunting(e) -- RC1: no abandon distance and no leash while it hunts
		if not hunting and distance > T.AbandonStuds then
			goHome(events, e, world, now, "GiveUp")
			return
		end
		-- held at the end of its leash with the target out of reach: GiveUpSeconds of that and it gives up
		if not hunting and distance > A.RangeStuds and flat(e.pos.x, e.pos.z, e.home.x, e.home.z) >= T.LeashStuds - LEASH_EDGE then
			e.pinnedSince = e.pinnedSince or now
			if now - e.pinnedSince >= T.GiveUpSeconds then
				goHome(events, e, world, now, "GiveUp")
				return
			end
		else
			e.pinnedSince = nil
		end
		-- A2 Gift: walk up to the target and hand the order over; no attack in this encounter
		if e.gift then
			if distance <= X.Gift.HandStuds then
				Attack.face(e, target)
				Attack.phase(events, e, "Deliver", now, now + X.Gift.HandSeconds)
				return
			end
			local x, z = leashed(e, T, target.x, target.z)
			walkTo(e, world, T, x, z, T.ChaseSpeedStudsPerSecond, dt)
			return
		end
		-- A2 Follow: out of reach, the chain ends and the cooldown counts from its last strike
		if e.following and X.Follow and distance > X.Follow.RangeStuds then
			e.following = false
			e.readyAt = e.lastStrikeAt + A.CooldownSeconds
		end
		-- OF3: the target just dodged: it stands, faces it and re-aims before anything else
		if Smarts.dodged(e, world, now, target) then
			Attack.face(e, target)
			return
		end
		sideAttacks(events, e, world, now, target, T)
		if distance <= A.RangeStuds and now >= e.readyAt then
			if openAttack(events, e, now, target, world, C, T, A) then
				e.pinnedSince = nil
				return
			end
		end
		-- OF2: a thrower with StandOffStuds stops that far away and throws from there
		local stand = T.StandOffStuds or (A.kind == "leap" and 3 or math.min(A.RangeStuds * 0.6, 4))
		if distance > stand then
			-- OF3: run for the lead point (or a flank point when hunting with others), sprinting at first, round obstacles
			local gx, gz = Smarts.goal(e, world, now, target)
			local ax, az = unit(e.pos.x - gx, e.pos.z - gz)
			if T.StandOffStuds and ax then gx, gz = gx + ax * stand, gz + az * stand end -- OF2: stop at the stand-off
			local x, z = leashed(e, T, gx, gz)
			local dx, dz = Smarts.direction(e, world, x, z)
			if dx then
				local step = math.min(Smarts.speed(e, now, T.ChaseSpeedStudsPerSecond, target) * dt, flat(e.pos.x, e.pos.z, x, z))
				settle(e, world, T, e.pos.x + dx * step, e.pos.z + dz * step)
				e.dx, e.dz = dx, dz
			end
			local lx, lz = leashed(e, T, e.pos.x, e.pos.z)
			if lx ~= e.pos.x or lz ~= e.pos.z then settle(e, world, T, lx, lz) end
			if X.Trail and X.Trail.Phase == "Chase" then trail(events, e, now, T, X.Trail) end -- A2
		else
			Attack.face(e, target)
		end
		return
	end
	if e.phase == "Telegraph" and e.attack then
		local attack = e.attack
		if now < e.lockAt then
			Attack.aim(events, e, attack, shapeFor(e, target, world, T, A, now), now)
			Attack.face(e, target)
		else
			Attack.lock(events, e, attack, nil, e.lockAt) -- does nothing once locked
		end
		if now >= e.releaseAt then
			Attack.lock(events, e, attack, nil, e.lockAt)
			e.from = copy(e.pos)
			if X.Trail and X.Trail.Phase == "Release" then e.trailLast = nil end -- A2: a roll's trail starts where it starts
			Attack.phase(events, e, "Release", e.releaseAt, attack.strikeAt)
		end
		return
	end
	if e.phase == "Release" and e.attack then
		local attack = e.attack
		local shape = attack.shape
		local progress = A.TravelSeconds > 0 and math.clamp((now - e.releaseAt) / A.TravelSeconds, 0, 1) or 1
		if A.kind == "leap" then
			settle(e, world, T, e.from.x + (shape.x - e.from.x) * progress, e.from.z + (shape.z - e.from.z) * progress)
		elseif A.kind == "dash" then
			local along = shape.length * progress
			settle(e, world, T, shape.ox + shape.dx * along, shape.oz + shape.dz * along)
			e.dx, e.dz = shape.dx, shape.dz
		end
		if X.Trail and X.Trail.Phase == "Release" then trail(events, e, now, T, X.Trail) end -- A2
		if now >= attack.strikeAt then strike(events, e, target, world, C, T, A) end
		return
	end
	if e.phase == "Recover" and now - e.phaseAt >= A.RecoverSeconds then
		Attack.phase(events, e, "Chase", e.phaseAt + A.RecoverSeconds)
	end
end

return Critter
