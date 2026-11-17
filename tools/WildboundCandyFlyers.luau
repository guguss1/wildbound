-- Caramelo (owner request 2026-11-16, "bichos voladores que te persiguen"): the Zumbidulces, small flying candy bugs (a
-- striped sweet body with two wings) that make the biome harder and more alive. Pure rules: no services, no clock, no
-- random (deterministic given its inputs). A handful of hives (F.hives) sit beside the Layout's routes, off the paths,
-- clear of the entrance, the boss plaza, the tower and its stair, the KEEP_CLEAR zones, the portal's quiet area and every
-- nest (all read from the Layout at run time). Each hive holds a swarm of 2 or 3 bugs that hover and drift round it.
--   Idle     hovering; a live player outside a safe zone, inside the biome, within NOTICE_STUDS wakes it (a player has
--            at most MAX_AWAKE_PER_PLAYER swarms awake on them).
--   Alert    the tell (WAKE_TELL_SECONDS >= the 0.8 s fair-strike floor: the buzz rises, the bugs glow and shake).
--   Chase    the bugs fly at the target through the air (ignoring the ground, CHASE_HEIGHT_STUDS over the target's
--            floor) at CRUISE_STUDS_PER_SECOND, faster than a sprint. One bug of a swarm dives at a time: within
--            AIM_RANGE_STUDS it pulls up (Aim, DIVE_TELL_SECONDS, a marker on the floor where it will strike, led by the
--            target's velocity), locks the spot and dives (DIVE_SECONDS, at most DIVE_REACH_STUDS). At the strike a target
--            within HIT_STUDS is stung once (DAMAGE, a small push; the egg is kept) unless the perfect dodge holds it (the
--            bug is stunned STUN_SECONDS); then the bug recovers (RECOVER_SECONDS, climbing slowly in place).
--   Return   they give up (a safe zone, death, a leave, the boss plaza or the tower (F.noGoZones), or the hard limit
--            HARD_SECONDS) and fly home; Cooldown until COOLDOWN_SECONDS after the give-up.
--   Vanish   RC3: a give-up farther than FADE_STUDS from the hive: they climb for VANISH_SECONDS (the client fades them
--            out), then reappear at the hive in Cooldown, instead of a long flight home.
-- RC (owner request 2026-11-16, "all the creatures keep chasing you, and fast, until you reach the base"): no leash, no
-- biome edge, no chase timer and no sting cap end a chase any more: a swarm follows its target out of the plot to the
-- base. After MAX_STINGS stings in one chase it tires (its dives come TIRED_DIVE_GAP_SECONDS apart instead of
-- DIVE_GAP_SECONDS), so one swarm hurts but rarely defeats a runner. Escape: reach a safe zone, dodging or juking the
-- dives meanwhile (RC7 holds the math). hooks.claim (optional) books each dive's strike in the shared strike ledger
-- (WildboundCandySmarts.claimStrike); a refused dive waits for a later step. WildboundCandyFlyersService runs it and
-- applies the hits through the beasts' BeastHit (the place's damage switch) with the egg kept.
local F = {}

F.BEAST_NAME = "Zumbidulce"
F.DODGE_SOURCE = "Zumbidulce" -- WildboundDodge.SOURCES
F.KEEPS_EGG = true -- only Don Glaseon's lash drops the carried egg

-- Player-facing words (neutral Spanish). The service shows them through the client's small notice.
F.TEXT = table.freeze({
	name = "Zumbidulce",
	wake = "¡Zumbidulces! Te siguen hasta tu base: esquiva su picada.", -- RC: they chase to the base now
	home = "Los Zumbidulces vuelven a su panal.",
})

-- Caps: at most MAX_HIVES swarms of 3 and MAX_BUGS bugs on the server; PARTS_PER_BUG is the service's build.
-- RC ("more bugs"): hives 5 -> 8, swarms of 2 or 3 -> 3, bugs 15 -> 24 (168 parts), awake per player 2 -> 3.
F.MAX_HIVES = 8
F.MIN_BUGS_PER_HIVE = 3
F.MAX_BUGS_PER_HIVE = 3
F.MAX_BUGS = 24
F.PARTS_PER_BUG = 7
F.MAX_AWAKE_PER_PLAYER = 3
F.STEP_SECONDS = 1 / 12 -- the service's throttled step (12 Hz)
F.MAX_DT = 0.25 -- a long server hitch never teleports a bug

-- Waking and flying.
F.NOTICE_STUDS = 35
F.WAKE_TELL_SECONDS = 1
F.CRUISE_STUDS_PER_SECOND = 26 -- an untrained sprint is 23.2, a walk 16, the candy critters chase at 21.5-23 (hard tune: 24 -> 25; RC: 25 -> 26)
F.RETURN_STUDS_PER_SECOND = 16
F.IDLE_RADIUS_STUDS = 3.5
F.IDLE_TURN_RADIANS_PER_SECOND = 0.9
F.IDLE_HEIGHT_STUDS = 5
F.IDLE_BOB_STUDS = 0.6
F.MIN_HEIGHT_STUDS = 4 -- over the floor, until a dive
F.MAX_HEIGHT_STUDS = 9
F.CHASE_HEIGHT_STUDS = 6
F.CHASE_RING_STUDS = 5 -- each bug holds its own slot round the target
F.CHASE_RING_TURN = 0.8 -- radians per second
F.ROOT_HEIGHT_STUDS = 3 -- a character's root stands about this far over its floor
F.HOME_STUDS = 0.75

-- The dive.
F.AIM_RANGE_STUDS = 7
F.AIM_HEIGHT_STUDS = 8.5 -- the pull-up
F.AIM_FOLLOW_STUDS = 4
F.DIVE_TELL_SECONDS = 0.8
F.DIVE_SECONDS = 0.5
F.DIVE_REACH_STUDS = 16 -- 32 studs/s at most over the dive
F.DIVE_GAP_SECONDS = 0.9 -- after a strike before the swarm's next pull-up (hard tune: 0.5 -> 0.9, so a sprinter passing by
-- takes 2 stings, not the cap, and a walker the cap)
F.LEAD_MAX_SPEED = 30
F.HIT_STUDS = 3
F.HIT_HEIGHT_STUDS = 5
F.DAMAGE = 12
F.PUSH_STUDS = 6
F.PUSH_SECONDS = 0.3
F.RECOVER_SECONDS = 1.5
F.RECOVER_CLIMB_STUDS_PER_SECOND = 3
F.STUN_SECONDS = 2
F.STUN_SINK_STUDS_PER_SECOND = 1

-- Giving up.
-- RC: LEASH_STUDS (110) and CHASE_SECONDS (14) no longer end a chase; they are kept only as the old numbers' record.
F.LEASH_STUDS = 110
F.CHASE_SECONDS = 14
F.HARD_SECONDS = 180 -- RC1: the safety end of any chase (WildboundCandySmarts.RELENTLESS.hardSeconds)
F.COOLDOWN_SECONDS = 12 -- from the give-up
F.MAX_STINGS = 3 -- RC: no longer a give-up: after this many stings in one chase the swarm tires
F.TIRED_DIVE_GAP_SECONDS = 5 -- RC: a tired swarm's gap after a strike (DIVE_GAP_SECONDS before)
F.FADE_STUDS = 120 -- RC3: farther than this from the hive at a give-up, they vanish instead of flying home
F.VANISH_SECONDS = 1
F.VANISH_RISE_STUDS_PER_SECOND = 8
F.TOWER_NO_GO_MARGIN_STUDS = 8 -- F.noGoZones: the tower's disc reaches past its widest tier (the stair; V7-D2: 4 -> 8, the stair twice as wide)
-- V4-D14 (owner 2026-11-17: "proposals to get rid of the bees, they chase too much"): three ways to shake them off.
--   (1) a target inside a house (players[i].sheltered) for HOUSE_GIVEUP_SECONDS: the swarm gives up ("House"); the bugs
--       never enter a house (V4-D12: world.houses, footprint discs { x, z, r }, kept HOUSE_MARGIN_STUDS outside);
--   (2) a target wading in the chocolate (players[i].wading) for WADE_LOSE_SECONDS: lost ("Chocolate");
--   (3) a target without an egg (players[i].carryingEgg == false) farther than NO_EGG_LEASH_STUDS from the hive:
--       given up ("Leash"). With an egg (or unknown: nil) they stay relentless (RC) except for (1) and (2).
-- A sheltered or wading player never wakes a swarm.
F.HOUSE_GIVEUP_SECONDS = 3
-- V5-D2 (Caramelo v5): a target hidden in a hide spot (players[i].hidden, the world script's WildboundHidden) is
-- treated like one in a house: never woken on, no new dive and no sting, and the swarm gives up after
-- HIDE_GIVEUP_SECONDS ("Hidden"), egg or not.
F.HIDE_GIVEUP_SECONDS = F.HOUSE_GIVEUP_SECONDS
-- V6-D1 (Caramelo v6): the tall licorice grass. A player in a grass patch who is not sprinting (players[i].grassCover,
-- worked out by the service from the server's positions: WildboundCandyHiding.covered) is seen by a swarm only within
-- GRASS_SEE_STUDS: such a player wakes a hive only that close (not NOTICE_STUDS), and a chasing swarm whose every bug
-- stays farther than that for GRASS_MEMORY_SECONDS loses them ("Grass"). The same numbers as WildboundCandyHiding.GRASS.
-- A chasing swarm flies a ring CHASE_RING_STUDS round its target, so in practice the grass shakes it off only once the
-- player has left it behind (V6-D11).
F.GRASS_SEE_STUDS = 10
F.GRASS_MEMORY_SECONDS = 3
F.WADE_LOSE_SECONDS = 2
F.NO_EGG_LEASH_STUDS = 70
F.HOUSE_MARGIN_STUDS = 1.5
-- FL10's untrained runner: WildboundStamina's pool 100 at DRAIN 25 a second, a 4 s sprint, then a walk.
F.UNTRAINED_SPRINT_SECONDS = 4

-- Hive placement (local coordinates of the plot).
F.SAMPLE_STUDS = 12
F.HIVE_OFFSET_STUDS = 16 -- beside the route's centreline
F.ROUTE_MIN_STUDS = 10 -- off every path (PATH_WIDTH / 2 + 3)
F.ROUTE_MAX_STUDS = 22 -- but near one
F.EDGE_STUDS = 15
F.ENTRANCE_CLEAR_STUDS = 40
F.PLAZA_MARGIN_STUDS = 12
F.TOWER_CLEAR_STUDS = 20
F.STAIR_CLEAR_STUDS = 15
F.KEEP_CLEAR_MARGIN_STUDS = 12
F.PORTAL_CLEAR_STUDS = 45 -- past WildboundPortal's 40-stud threat radius
F.NEST_CLEAR_STUDS = 15
-- Studio run 2026-11-16: a hive stood 4.7 studs from a creature post. The service passes the candy creatures' posts
-- (opts.posts, world coordinates, read at run time from WildboundPraderaSites.FIXED); no hive within this of one.
F.POST_CLEAR_STUDS = 15
F.LAKE_MARGIN_STUDS = 4
F.HIVE_SPACING_STUDS = 60

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function finite(v) return type(v) == "number" and v == v and v > -math.huge and v < math.huge end

-- The dodge id of one dive (WildboundDodge: a string of at most 64 characters).
function F.attackKey(swarmId, bugIndex, dive)
	return "Zumbidulce:" .. tostring(swarmId) .. ":" .. tostring(bugIndex) .. ":" .. tostring(dive)
end

-- A hive spot in the plot's local coordinates: true, or false and the rule it breaks. steps = L.stairSteps() (optional);
-- posts = the creature posts in the plot's local coordinates ({ { x, z } }, optional: none, no post rule).
function F.hiveSpotOk(L, lx, lz, steps, posts)
	for _, p in ipairs(posts or {}) do
		if flat(lx, lz, p.x, p.z) < F.POST_CLEAR_STUDS then return false, "Post" end
	end
	if L.depth(lx, lz) < F.EDGE_STUDS then return false, "Edge" end
	if flat(lx, lz, L.ENTRANCE.x, L.ENTRANCE.z) < F.ENTRANCE_CLEAR_STUDS then return false, "Entrance" end
	if flat(lx, lz, L.BOSS.x, L.BOSS.z) < L.BOSS.plazaRadius + F.PLAZA_MARGIN_STUDS then return false, "Plaza" end
	if flat(lx, lz, L.TORTA.x, L.TORTA.z) < L.TORTA.radius + F.TOWER_CLEAR_STUDS then return false, "Tower" end
	for _, s in ipairs(steps or L.stairSteps()) do
		if flat(lx, lz, s.x, s.z) < F.STAIR_CLEAR_STUDS then return false, "Stair" end
	end
	for _, k in ipairs(L.KEEP_CLEAR or {}) do
		if flat(lx, lz, k.x, k.z) < k.r + F.KEEP_CLEAR_MARGIN_STUDS then return false, "KeepClear" end
	end
	if L.PORTAL and flat(lx, lz, L.PORTAL.x, L.PORTAL.z) < F.PORTAL_CLEAR_STUDS then return false, "Portal" end
	for _, w in ipairs(L.LAKE or {}) do -- review F-6: never over the syrup lake
		if flat(lx, lz, w.x, w.z) < w.r + F.LAKE_MARGIN_STUDS then return false, "Lake" end
	end
	for _, n in ipairs(L.NESTS or {}) do
		if flat(lx, lz, n.x, n.z) < F.NEST_CLEAR_STUDS then return false, "Nest" end
	end
	local r = L.routeDistance(lx, lz)
	if r < F.ROUTE_MIN_STUDS then return false, "OnPath" end
	if r > F.ROUTE_MAX_STUDS then return false, "FarFromRoute" end
	return true
end

-- Candidate spots: every SAMPLE_STUDS along each route segment, HIVE_OFFSET_STUDS to either side. { { lx, lz } }.
function F.candidates(L)
	local list = {}
	for _, name in ipairs(L.ROUTE_ORDER) do
		local points = L.ROUTES[name]
		for i = 1, #points - 1 do
			local a, b = points[i], points[i + 1]
			local dx, dz = b.x - a.x, b.z - a.z
			local length = math.sqrt(dx * dx + dz * dz)
			if length > 1e-6 then
				local nx, nz = -dz / length, dx / length
				local n = math.max(1, math.floor(length / F.SAMPLE_STUDS))
				for k = 0, n - 1 do
					local t = (k + 0.5) / n
					local px, pz = a.x + dx * t, a.z + dz * t
					table.insert(list, { lx = px + nx * F.HIVE_OFFSET_STUDS, lz = pz + nz * F.HIVE_OFFSET_STUDS })
					table.insert(list, { lx = px - nx * F.HIVE_OFFSET_STUDS, lz = pz - nz * F.HIVE_OFFSET_STUDS })
				end
			end
		end
	end
	return list
end

-- The hives in world coordinates: { { id, index, lx, lz, x, z, floor, count } }, at most MAX_HIVES, HIVE_SPACING_STUDS
-- apart: the first valid candidate (route order), then each next the valid candidate farthest from those chosen.
-- centre = the plot's centre (default L.CENTRE); opts = { floorTop, safe = function(worldX, worldZ) -> bool,
-- posts = { { x, z } } the candy creature posts in world coordinates (optional) }.
function F.hives(L, centre, opts)
	centre = centre or L.CENTRE
	opts = opts or {}
	local floor = opts.floorTop or L.FLOOR_TOP
	local steps = L.stairSteps()
	local posts = {}
	for _, p in ipairs(opts.posts or {}) do
		if finite(p.x) and finite(p.z) then table.insert(posts, { x = p.x - centre.x, z = p.z - centre.z }) end
	end
	local valid = {}
	for _, c in ipairs(F.candidates(L)) do
		if F.hiveSpotOk(L, c.lx, c.lz, steps, posts)
			and not (opts.safe and opts.safe(centre.x + c.lx, centre.z + c.lz) == true) then
			table.insert(valid, c)
		end
	end
	local chosen = {}
	if #valid > 0 then table.insert(chosen, valid[1]) end
	while #chosen < F.MAX_HIVES do
		local best, bestGap = nil, -1
		for _, c in ipairs(valid) do
			local gap = math.huge
			for _, h in ipairs(chosen) do gap = math.min(gap, flat(c.lx, c.lz, h.lx, h.lz)) end
			if gap > bestGap then best, bestGap = c, gap end
		end
		if not best or bestGap < F.HIVE_SPACING_STUDS then break end
		table.insert(chosen, best)
	end
	local hives, bugs = {}, 0
	for i, c in ipairs(chosen) do
		local n = (i % 2 == 1) and F.MAX_BUGS_PER_HIVE or F.MIN_BUGS_PER_HIVE
		n = math.min(n, F.MAX_BUGS - bugs)
		if n <= 0 then break end
		bugs += n
		table.insert(hives, { id = "H" .. i, index = i, lx = c.lx, lz = c.lz, x = centre.x + c.lx, z = centre.z + c.lz,
			floor = floor, count = n })
	end
	return hives
end

-- Ground a swarm never follows a player into (it gives up there, "NoGoZone"), in world coordinates: Don Glaseon's
-- plaza and the Gran Torta with its stair (read from the Layout: a moved or enlarged Torta moves them). { { x, z, r } }.
function F.noGoZones(L, centre)
	centre = centre or L.CENTRE
	return {
		{ x = centre.x + L.BOSS.x, z = centre.z + L.BOSS.z, r = L.BOSS.plazaRadius, why = "Plaza" },
		{ x = centre.x + L.TORTA.x, z = centre.z + L.TORTA.z, r = L.TORTA.radius + F.TOWER_NO_GO_MARGIN_STUDS, why = "Tower" },
	}
end

-- Where an idle bug hovers at `now` (round its hive, bobbing).
function F.idlePoint(swarm, bug, now)
	local a = bug.offset + now * F.IDLE_TURN_RADIANS_PER_SECOND
	local h = swarm.hive
	return h.x + math.cos(a) * F.IDLE_RADIUS_STUDS, h.floor + F.IDLE_HEIGHT_STUDS + math.sin(2 * a + bug.index) * F.IDLE_BOB_STUDS,
		h.z + math.sin(a) * F.IDLE_RADIUS_STUDS
end

-- hives from F.hives (or { id, x, z, floor, count }); bounds = { x, z, half } (the biome's square: a target outside it
-- is lost), optional; noGo = F.noGoZones (a target inside one is lost and never woken on), optional. Returns the world:
-- { swarms, bugs, at, bounds, noGo }.
function F.new(hives, now, bounds, noGo)
	local world = { swarms = {}, bugs = 0, at = now, bounds = bounds, noGo = noGo or {} }
	for i, h in ipairs(hives) do
		if #world.swarms >= F.MAX_HIVES then break end
		local n = math.clamp(math.floor(tonumber(h.count) or F.MAX_BUGS_PER_HIVE), 1, F.MAX_BUGS_PER_HIVE)
		n = math.min(n, F.MAX_BUGS - world.bugs)
		if n <= 0 then break end
		world.bugs += n
		local swarm = { id = h.id or ("H" .. i), index = i, hive = { x = h.x, z = h.z, floor = h.floor or 0 }, phase = "Idle",
			bugs = {}, stings = 0, dives = 0, nextDiveAt = -math.huge, cooldownUntil = -math.huge }
		for b = 1, n do
			local bug = { index = b, offset = (b - 1) * 2 * math.pi / n + i * 0.7, phase = "Idle", vx = 0, vy = 0, vz = 0 }
			bug.x, bug.y, bug.z = F.idlePoint(swarm, bug, now)
			table.insert(swarm.bugs, bug)
		end
		table.insert(world.swarms, swarm)
	end
	return world
end

local function setAt(bug, x, y, z, dt)
	if dt > 0 then bug.vx, bug.vy, bug.vz = (x - bug.x) / dt, (y - bug.y) / dt, (z - bug.z) / dt end
	bug.x, bug.y, bug.z = x, y, z
end

local function moveToward(bug, tx, ty, tz, speed, dt)
	local dx, dy, dz = tx - bug.x, ty - bug.y, tz - bug.z
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	local reach = speed * dt
	if d <= reach or d < 1e-6 then
		setAt(bug, tx, ty, tz, dt)
	else
		local f = reach / d
		setAt(bug, bug.x + dx * f, bug.y + dy * f, bug.z + dz * f, dt)
	end
	return d
end

local function inside(bounds, x, z)
	if not bounds then return true end
	return math.max(math.abs(x - bounds.x), math.abs(z - bounds.z)) <= bounds.half
end

local function inNoGo(world, x, z)
	for _, zone in ipairs(world.noGo or {}) do
		if flat(x, z, zone.x, zone.z) <= zone.r then return true end
	end
	return false
end

local function usable(world, p)
	return p ~= nil and p.alive == true and finite(p.x) and finite(p.y) and finite(p.z) and p.safe ~= true
		and inside(world.bounds, p.x, p.z) and not inNoGo(world, p.x, p.z)
		and p.sheltered ~= true and p.wading ~= true -- V4-D14: never woken on a player in a house or in the chocolate
		and p.hidden ~= true -- V5-D2: nor on a hidden one
end

-- V4-D12 / V4-D14: (x, z) kept outside every house disc of `discs` (grown by HOUSE_MARGIN_STUDS): a point inside one
-- goes out to its edge along the line from its centre (from (px, pz) when it stands on the centre). Returns x, z.
function F.outsideHouses(discs, x, z, px, pz)
	if not (finite(x) and finite(z)) then return x, z end
	for _ = 1, 2 do
		for _, d in ipairs(discs or {}) do
			local r = d.r + F.HOUSE_MARGIN_STUDS
			local dx, dz = x - d.x, z - d.z
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist < r then
				if dist < 1e-6 then
					dx, dz = (finite(px) and px or d.x + 1) - d.x, (finite(pz) and pz or d.z) - d.z
					dist = math.sqrt(dx * dx + dz * dz)
					if dist < 1e-6 then dx, dz, dist = 1, 0, 1 end
				end
				x, z = d.x + dx / dist * (r + 1e-3), d.z + dz / dist * (r + 1e-3)
			end
		end
	end
	return x, z
end

-- Why a swarm loses its target, or nil. RC1: no leash and no biome edge any more (the bounds only gate the wake).
-- V4-D14: the house, chocolate and no-egg escapes (the swarm keeps since-when timers).
local function lost(world, swarm, target, now)
	if not target then return "Gone" end
	if target.alive ~= true or not (finite(target.x) and finite(target.y) and finite(target.z)) then return "Death" end
	if target.safe == true then return "SafeZone" end
	if inNoGo(world, target.x, target.z) then return "NoGoZone" end
	if now then
		if target.sheltered == true then
			swarm.shelterSince = swarm.shelterSince or now
			if now - swarm.shelterSince >= F.HOUSE_GIVEUP_SECONDS - 1e-9 then return "House" end
		else
			swarm.shelterSince = nil
		end
		if target.wading == true then
			swarm.wadeSince = swarm.wadeSince or now
			if now - swarm.wadeSince >= F.WADE_LOSE_SECONDS - 1e-9 then return "Chocolate" end
		else
			swarm.wadeSince = nil
		end
		-- V5-D2: hidden in a hide spot, like a house
		if target.hidden == true then
			swarm.hideSince = swarm.hideSince or now
			if now - swarm.hideSince >= F.HIDE_GIVEUP_SECONDS - 1e-9 then return "Hidden" end
		else
			swarm.hideSince = nil
		end
		-- V6-D1: in the grass, not sprinting, and every bug farther than GRASS_SEE_STUDS
		local unseen = target.grassCover == true
		if unseen then
			for _, bug in ipairs(swarm.bugs) do
				if flat(bug.x, bug.z, target.x, target.z) <= F.GRASS_SEE_STUDS then unseen = false break end
			end
		end
		if unseen then
			swarm.grassSince = swarm.grassSince or now
			if now - swarm.grassSince >= F.GRASS_MEMORY_SECONDS - 1e-9 then return "Grass" end
		else
			swarm.grassSince = nil
		end
	end
	if target.carryingEgg == false and flat(target.x, target.z, swarm.hive.x, swarm.hive.z) > F.NO_EGG_LEASH_STUDS then
		return "Leash"
	end
	return nil
end

-- RC3: far from the hive (any bug past FADE_STUDS) the swarm vanishes (Vanish) instead of the long flight home (Return).
local function giveUp(swarm, now, reason, events)
	local far = false
	for _, bug in ipairs(swarm.bugs) do
		if flat(bug.x, bug.z, swarm.hive.x, swarm.hive.z) > F.FADE_STUDS then far = true end
	end
	for _, bug in ipairs(swarm.bugs) do
		if bug.phase == "Aim" or bug.phase == "Dive" then
			table.insert(events, { kind = "DiveCancel", at = now, swarm = swarm.id, bug = bug.index, id = swarm.target, key = bug.key })
		end
		bug.phase, bug.markX, bug.markZ, bug.markY = far and "Vanish" or "Return", nil, nil, nil
	end
	table.insert(events, { kind = "GiveUp", at = now, swarm = swarm.id, id = swarm.target, reason = reason, vanish = far or nil })
	swarm.phase, swarm.target, swarm.diving = far and "Vanish" or "Return", nil, nil
	swarm.shelterSince, swarm.wadeSince, swarm.hideSince, swarm.grassSince = nil, nil, nil, nil
	swarm.vanishUntil = far and now + F.VANISH_SECONDS or nil
	swarm.cooldownUntil = now + F.COOLDOWN_SECONDS
end

local function hover(swarm, now, dt)
	for _, bug in ipairs(swarm.bugs) do
		local x, y, z = F.idlePoint(swarm, bug, now)
		setAt(bug, x, y, z, dt)
	end
end

local function lead(target)
	local vx, vz = tonumber(target.vx) or 0, tonumber(target.vz) or 0
	if not (finite(vx) and finite(vz)) then vx, vz = 0, 0 end
	local speed = math.sqrt(vx * vx + vz * vz)
	if speed > F.LEAD_MAX_SPEED then vx, vz = vx / speed * F.LEAD_MAX_SPEED, vz / speed * F.LEAD_MAX_SPEED end
	return target.x + vx * F.DIVE_SECONDS, target.z + vz * F.DIVE_SECONDS
end

-- One bug of a chasing swarm. hooks.resolve(targetId, key, now) -> "Dodged" | "Hit" | "Unknown" (the perfect dodge).
local function chaseBug(swarm, bug, target, now, dt, hooks, events, houses)
	-- review F-7: the floor from the root's last grounded height (target.groundY), so a jump never lifts the bugs or
	-- floats the marker; the sting still compares the root's real height (target.y), so a jump can dodge a dive.
	local ground = (finite(target.groundY) and target.groundY or target.y) - F.ROOT_HEIGHT_STUDS
	if bug.phase == "Stunned" then
		if now < bug.stunEndsAt then
			setAt(bug, bug.x, math.max(bug.y - F.STUN_SINK_STUDS_PER_SECOND * dt, math.min(bug.y, ground + F.MIN_HEIGHT_STUDS)), bug.z, dt)
			return
		end
		bug.phase = "Fly"
	end
	if bug.phase == "Recover" then
		if now < bug.recoverEndsAt then
			setAt(bug, bug.x, math.min(bug.y + F.RECOVER_CLIMB_STUDS_PER_SECOND * dt, math.max(bug.y, ground + F.CHASE_HEIGHT_STUDS)),
				bug.z, dt)
			return
		end
		bug.phase = "Fly"
	end
	if bug.phase == "Fly" or bug.phase == "Idle" or bug.phase == "Return" then
		bug.phase = "Fly"
		local a = bug.offset + now * F.CHASE_RING_TURN
		moveToward(bug, target.x + math.cos(a) * F.CHASE_RING_STUDS, ground + F.CHASE_HEIGHT_STUDS,
			target.z + math.sin(a) * F.CHASE_RING_STUDS, F.CRUISE_STUDS_PER_SECOND, dt)
		bug.y = math.clamp(bug.y, ground + F.MIN_HEIGHT_STUDS, ground + F.MAX_HEIGHT_STUDS)
		-- RC4: the dive's strike is booked in the shared strike ledger first (hooks.claim); refused, it waits a step
		local strikeAt = now + F.DIVE_TELL_SECONDS + F.DIVE_SECONDS
		if swarm.diving == nil and now >= swarm.nextDiveAt and flat(bug.x, bug.z, target.x, target.z) <= F.AIM_RANGE_STUDS
			and target.hidden ~= true -- V5-D2: no dive at a hidden player
			and (not (hooks and hooks.claim) or hooks.claim(target.id, swarm.id, strikeAt, now) ~= false) then
			swarm.dives += 1
			swarm.diving = bug.index
			bug.phase, bug.key = "Aim", F.attackKey(swarm.id, bug.index, swarm.dives)
			bug.aimAt, bug.diveAt = now, now + F.DIVE_TELL_SECONDS
			bug.strikeAt = bug.diveAt + F.DIVE_SECONDS
			bug.markX, bug.markZ = lead(target)
			bug.markY = ground
			table.insert(events, { kind = "DiveTell", at = now, swarm = swarm.id, bug = bug.index, id = target.id, key = bug.key,
				startAt = now, strikeAt = bug.strikeAt, x = bug.markX, y = ground, z = bug.markZ })
		end
		return
	end
	if bug.phase == "Aim" then
		bug.markX, bug.markZ = lead(target)
		bug.markY = ground
		if now < bug.diveAt then
			local ox, oz = bug.x - target.x, bug.z - target.z
			local d = math.sqrt(ox * ox + oz * oz)
			if d < 1e-3 then ox, oz, d = 1, 0, 1 end
			moveToward(bug, target.x + ox / d * F.AIM_FOLLOW_STUDS, ground + F.AIM_HEIGHT_STUDS, target.z + oz / d * F.AIM_FOLLOW_STUDS,
				F.CRUISE_STUDS_PER_SECOND, dt)
			bug.y = math.clamp(bug.y, ground + F.MIN_HEIGHT_STUDS, ground + F.MAX_HEIGHT_STUDS)
			return
		end
		-- lock the spot: where the target will be, as far as the dive reaches
		local tx, tz = bug.markX, bug.markZ
		local dx, dz = tx - bug.x, tz - bug.z
		local d = math.sqrt(dx * dx + dz * dz)
		if d > F.DIVE_REACH_STUDS then tx, tz = bug.x + dx / d * F.DIVE_REACH_STUDS, bug.z + dz / d * F.DIVE_REACH_STUDS end
		-- V4-D14: a dive never goes into a house (its spot stops at the edge: a target inside is out of reach)
		tx, tz = F.outsideHouses(houses, tx, tz, bug.x, bug.z)
		bug.fromX, bug.fromY, bug.fromZ = bug.x, bug.y, bug.z
		bug.toX, bug.toY, bug.toZ = tx, ground + F.ROOT_HEIGHT_STUDS, tz
		bug.markX, bug.markZ = tx, tz
		bug.phase = "Dive"
		table.insert(events, { kind = "Dive", at = now, swarm = swarm.id, bug = bug.index, id = target.id, key = bug.key,
			x = tx, y = ground + F.ROOT_HEIGHT_STUDS, z = tz })
	end
	if bug.phase == "Dive" then
		local u = math.clamp((now - bug.diveAt) / F.DIVE_SECONDS, 0, 1)
		setAt(bug, bug.fromX + (bug.toX - bug.fromX) * u, bug.fromY + (bug.toY - bug.fromY) * u,
			bug.fromZ + (bug.toZ - bug.fromZ) * u, dt)
		if now < bug.strikeAt then return end
		setAt(bug, bug.toX, bug.toY, bug.toZ, 0)
		-- RC: a swarm that already stung MAX_STINGS times this chase is tired: longer gaps between its dives
		swarm.diving, swarm.nextDiveAt = nil, now + (swarm.stings >= F.MAX_STINGS and F.TIRED_DIVE_GAP_SECONDS or F.DIVE_GAP_SECONDS)
		bug.markX, bug.markZ, bug.markY = nil, nil, nil
		local reach = flat(target.x, target.z, bug.toX, bug.toZ) <= F.HIT_STUDS and math.abs(target.y - bug.toY) <= F.HIT_HEIGHT_STUDS
			and target.hidden ~= true -- V5-D2: a dive told before the player hid lands on nothing
		if not reach then
			table.insert(events, { kind = "Miss", at = now, swarm = swarm.id, bug = bug.index, id = target.id, key = bug.key })
			bug.phase, bug.recoverEndsAt = "Recover", now + F.RECOVER_SECONDS
			return
		end
		local outcome = hooks and hooks.resolve and hooks.resolve(target.id, bug.key, now) or "Hit"
		if outcome == "Dodged" then
			table.insert(events, { kind = "Dodged", at = now, swarm = swarm.id, bug = bug.index, id = target.id, key = bug.key })
			bug.phase, bug.stunEndsAt = "Stunned", now + F.STUN_SECONDS
			return
		end
		swarm.stings += 1
		if swarm.stings >= F.MAX_STINGS then swarm.nextDiveAt = now + F.TIRED_DIVE_GAP_SECONDS end
		local dx, dz = bug.toX - bug.fromX, bug.toZ - bug.fromZ
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1e-3 then dx, dz, d = target.x - swarm.hive.x, target.z - swarm.hive.z, 0 end
		d = math.sqrt(dx * dx + dz * dz)
		if d < 1e-3 then dx, dz, d = 1, 0, 1 end
		table.insert(events, { kind = "Hit", at = now, swarm = swarm.id, bug = bug.index, id = target.id, key = bug.key,
			damage = F.DAMAGE, dx = dx / d, dz = dz / d, studs = F.PUSH_STUDS, seconds = F.PUSH_SECONDS, keepsEgg = F.KEEPS_EGG })
		bug.phase, bug.recoverEndsAt = "Recover", now + F.RECOVER_SECONDS
	end
end

-- One step of every swarm. players = { { id, alive, x, y, z (the server-side root), groundY (the root's last grounded
-- height, optional), vx, vz, safe, V4-D14: sheltered, wading, carryingEgg, V5-D2: hidden (each optional) } }; world.houses (optional):
-- the house discs { { x, z, r } } (V4-D12). Events: Wake
-- { swarm, id, chaseAt }, Chase, DiveTell { bug, id, key, startAt, strikeAt, x, y, z }, Dive { key, x, y, z }, Hit { id,
-- key, damage, dx, dz, studs, seconds, keepsEgg }, Miss, Dodged, DiveCancel { key }, GiveUp { reason }, Home.
function F.step(world, now, players, hooks)
	local events = {}
	local dt = math.clamp(now - (world.at or now), 0, F.MAX_DT)
	world.at = now
	local byId, awake = {}, {}
	for _, p in ipairs(players or {}) do byId[p.id] = p end
	for _, swarm in ipairs(world.swarms) do
		if (swarm.phase == "Alert" or swarm.phase == "Chase") and swarm.target ~= nil then
			awake[swarm.target] = (awake[swarm.target] or 0) + 1
		end
	end
	for _, swarm in ipairs(world.swarms) do
		local started = false -- the bugs leave the hive on the step after the tell ends
		if swarm.phase == "Cooldown" and now >= swarm.cooldownUntil then swarm.phase = "Idle" end
		if swarm.phase == "Idle" then
			local target, best = nil, nil
			for _, p in ipairs(players or {}) do
				if usable(world, p) and (awake[p.id] or 0) < F.MAX_AWAKE_PER_PLAYER then
					local d = flat(p.x, p.z, swarm.hive.x, swarm.hive.z)
					-- V6-D1: a player in the grass who is not sprinting is noticed only GRASS_SEE_STUDS from the hive
					local reach = p.grassCover == true and F.GRASS_SEE_STUDS or F.NOTICE_STUDS
					if d <= reach and (best == nil or d < best) then target, best = p, d end
				end
			end
			if target then
				awake[target.id] = (awake[target.id] or 0) + 1
				swarm.phase, swarm.target, swarm.stings = "Alert", target.id, 0
				swarm.shelterSince, swarm.wadeSince, swarm.hideSince, swarm.grassSince = nil, nil, nil, nil
				swarm.chaseAt = now + F.WAKE_TELL_SECONDS
				table.insert(events, { kind = "Wake", at = now, swarm = swarm.id, id = target.id, chaseAt = swarm.chaseAt })
			end
			hover(swarm, now, dt)
		elseif swarm.phase == "Cooldown" then
			hover(swarm, now, dt)
		elseif swarm.phase == "Alert" then
			local reason = lost(world, swarm, byId[swarm.target], now)
			if reason then
				giveUp(swarm, now, reason, events)
			elseif now >= swarm.chaseAt then
				swarm.phase, swarm.chaseEndsAt, swarm.nextDiveAt, swarm.diving = "Chase", swarm.chaseAt + F.HARD_SECONDS, -math.huge, nil
				for _, bug in ipairs(swarm.bugs) do bug.phase = "Fly" end
				table.insert(events, { kind = "Chase", at = now, swarm = swarm.id, id = swarm.target })
				started = true
			end
			hover(swarm, now, dt)
		end
		if swarm.phase == "Chase" and not started then
			local target = byId[swarm.target]
			local reason = lost(world, swarm, target, now)
			-- RC1: no sting cap and no chase timer: only the hard limit (chaseEndsAt = chaseAt + HARD_SECONDS)
			if not reason and now >= swarm.chaseEndsAt then reason = "Timeout" end
			if reason then
				giveUp(swarm, now, reason, events)
			else
				for _, bug in ipairs(swarm.bugs) do chaseBug(swarm, bug, target, now, dt, hooks, events, world.houses) end
			end
		elseif swarm.phase == "Return" then
			local home = true
			for _, bug in ipairs(swarm.bugs) do
				local x, y, z = F.idlePoint(swarm, bug, now)
				if moveToward(bug, x, y, z, F.RETURN_STUDS_PER_SECOND, dt) > F.RETURN_STUDS_PER_SECOND * dt + F.HOME_STUDS then home = false end
			end
			if home then
				swarm.phase = "Cooldown"
				for _, bug in ipairs(swarm.bugs) do bug.phase = "Idle" end
				table.insert(events, { kind = "Home", at = now, swarm = swarm.id })
			end
		elseif swarm.phase == "Vanish" then
			-- RC3: they climb while the client fades them out, then stand at the hive again (Cooldown)
			if now >= (swarm.vanishUntil or now) then
				swarm.phase, swarm.vanishUntil = "Cooldown", nil
				for _, bug in ipairs(swarm.bugs) do
					bug.phase = "Idle"
					local x, y, z = F.idlePoint(swarm, bug, now)
					setAt(bug, x, y, z, 0)
					bug.vx, bug.vy, bug.vz = 0, 0, 0
				end
				table.insert(events, { kind = "Home", at = now, swarm = swarm.id, vanished = true })
			else
				for _, bug in ipairs(swarm.bugs) do setAt(bug, bug.x, bug.y + F.VANISH_RISE_STUDS_PER_SECOND * dt, bug.z, dt) end
			end
		end
		-- V4-D12 / V4-D14: no bug ever enters a house (it stops at the edge and slides round it)
		if world.houses and #world.houses > 0 and swarm.phase ~= "Idle" and swarm.phase ~= "Cooldown" then
			for _, bug in ipairs(swarm.bugs) do
				if bug.phase ~= "Dive" then
					local px, pz = bug.x - (bug.vx or 0) * dt, bug.z - (bug.vz or 0) * dt
					bug.x, bug.z = F.outsideHouses(world.houses, bug.x, bug.z, px, pz)
				end
			end
		end
	end
	return events
end

return F
