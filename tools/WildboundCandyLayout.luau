-- Caramelo biome blockout (odd/tasks/caramelo-bioma.md, T1; pack 04_ENTORNO/01_LAYOUT_MUNDO.md). The candy biome takes
-- the Pradera plot (WildboundBiomes key "pradera", tag Meadow). Pure data and flat geometry: no services, no clock, no
-- random. Coordinates are local to the plot centre: x grows east (away from the hub), z as in the world; the entrance is
-- the middle of the west edge, in line with the hub's east gate. Every number here is a first proposal to tune in play.
-- WildboundCandyBuilder turns this into parts; WildboundCandyLayout_Test holds the rules.
local Layout = {}

local function point(x, z) return table.freeze({ x = x, z = z }) end

Layout.ROOT_NAME = "Candy_Bioma_v1"
-- GT (owner request 2026-11-16, "the cake with the princess at the end, and much bigger"): version 3 moves the Gran
-- Torta to the east end, 1.6 times bigger (docs/design/wildbound-caramelo-cake-move-plan.md). A live v2 map gets it
-- through tools/wildbound-caramelo-cake-move.luau.
-- V8-D1: VERSION stays 3 (WildboundCandyV3Builder and the older migrations read it as "the GT layout"); the v8 map is
-- marked by WildboundCandyV3Layout.VERSION 4 and the root's CaramelV8.
Layout.VERSION = 3
Layout.SEED = 20261114
-- Caramelo v8 (owner request 2026-11-17, "make the Reino Caramelo map a bit bigger, in width and in length, so there is
-- more space between things"; docs/design/wildbound-caramelo-v8-plan.md, V8-D1): the plot grows 1.3 times about its
-- centre with the entrance fixed on the hub road: HALF 200 -> 260, CENTRE (612, -3) -> (672, -3), world x 412..932, z
-- -263..257, inside the big4 Meadow square (classic mode is not supported). Every position below keeps its v7 literal,
-- mapped at load by v8() (x S about the centre); sizes and radii keep their v7 values. The exceptions say V8-D1:
-- re-anchored to an edge or the plaza, or translated with their parent (the v7 offset kept).
Layout.CENTRE = point(672, -3)
Layout.HALF = 260
Layout.V8 = table.freeze({ S = 1.3, OLD_CENTRE = point(612, -3), OLD_HALF = 200 })

-- V8-D1: a v7 plot-local point in the v8 plot (x S about the centre): returns the new local x, z. Pure.
function Layout.fromV7Local(x, z)
	return x * Layout.V8.S, z * Layout.V8.S
end

-- V8-D1: a v7 world point in the v8 world, (672 + 1.3 (x - 612), -3 + 1.3 (z + 3)): returns the new world x, z. Pure.
function Layout.fromV7World(x, z)
	local S, old = Layout.V8.S, Layout.V8.OLD_CENTRE
	return Layout.CENTRE.x + (x - old.x) * S, Layout.CENTRE.z + (z - old.z) * S
end

-- A v7 literal as a v8 point, a v7 route and a v7 nest (positions mapped, everything else kept).
local function v8(x, z) return point(Layout.fromV7Local(x, z)) end
local function route(points)
	local list = {}
	for i, p in ipairs(points) do list[i] = v8(p[1], p[2]) end
	return table.freeze(list)
end
local function nest(id, rarity, x, z)
	local nx, nz = Layout.fromV7Local(x, z)
	return table.freeze({ id = id, rarity = rarity, x = nx, z = nz, eventOnly = rarity == "Legendaria" })
end

Layout.FLOOR_TOP = 0.5
Layout.PATH_WIDTH = 14
-- The blockout places candidates only: nothing here spawns eggs or beasts.
Layout.SPAWNS_ENABLED = false
-- CE1 (odd/tasks/wildbound-caramelo.md): the nests are live egg nests of the island system (WildboundCandyNests);
-- the event-only legendary nest stays off (no Caramelo event yet). false turns every nest back into a candidate.
Layout.NESTS_ENABLED = true

-- V8-D1: re-anchored to the west edge, (-HALF, 0): world (412, -3), on the hub road as in v7.
Layout.ENTRANCE = point(-Layout.HALF, 0)
Layout.FORK = v8(-110, 0)
-- GT: the junction is the old Torta's ground, the middle of the plot; the Torta stands at the east end (its plaza 28
-- studs from the east edge; V8-D1: 53.8 now, the plaza kept its size), at the end of the main avenue.
Layout.JUNCTION = v8(0, 0)
do
	local x, z = Layout.fromV7Local(114, 0)
	Layout.TORTA = table.freeze({ x = x, z = z, radius = 42 })
end
-- Don Glaseon's ground: the plaza he walks and the limit he never leaves. perception and whipLength are the pack's
-- starting balance (05_SISTEMAS/04_BALANCE_INICIAL_CONFIG.md); they only size the safe distances here. GT: plaza 44 ->
-- 58 and territory 62 -> 76 round the bigger Torta; he sleeps at the end of the avenue, at the cake's foot.
-- V8-D1: centred on the Torta; home moves with him (its v7 offset, 50 studs west of the Torta, kept).
Layout.BOSS = table.freeze({ x = Layout.TORTA.x, z = Layout.TORTA.z, plazaRadius = 58, territoryRadius = 76, perception = 36,
	whipLength = 22, home = point(Layout.TORTA.x + (64 - 114), Layout.TORTA.z) })
-- Return to the hub (pack 04_ENTORNO/03: 5 s without threat, 2 s channel, 30 s cooldown). CE3: live; the server's
-- WildboundPortalService binds its prompt while the model's Enabled attribute is true (Builder.syncPortal). GT: on the
-- main path just west of the junction, on the way back from the cake.
do
	local x, z = Layout.fromV7Local(-24, 0)
	Layout.PORTAL = table.freeze({ x = x, z = z, quietSeconds = 5, channelSeconds = 2, cooldownSeconds = 30, enabled = true })
end

Layout.ROUTES = table.freeze({
	-- GT: the last leg is the avenue from the junction to the plaza edge, a straight view of the cake.
	-- V8-D1: the entrance and the avenue's end are re-anchored (the west edge; the plaza edge, TORTA.x - plazaRadius,
	-- because the plaza keeps its 58); the fork and the junction scale.
	main = table.freeze({ Layout.ENTRANCE, v8(-110, 0), v8(0, 0),
		point(Layout.TORTA.x - Layout.BOSS.plazaRadius, Layout.TORTA.z) }),
	-- Left of a player walking in: the syrup riverside, longer and under the cotton trees.
	left = route({ { -110, 0 }, { -100, -80 }, { -50, -140 }, { 50, -140 }, { 90, -110 }, { 0, 0 } }),
	-- Right: the lollipop avenue, open and shorter.
	right = route({ { -110, 0 }, { -90, 70 }, { -40, 120 }, { 40, 120 }, { 80, 100 }, { 0, 0 } }),
	deep = route({ { 0, 0 }, { -24, 0 } }),
})
Layout.ROUTE_ORDER = table.freeze({ "main", "left", "right", "deep" })
Layout.RETURN_ROUTES = table.freeze({ "left", "right" })

-- Laguna de Almibar: shallow discs { x, z, r } crossed by one biscuit bridge on the left route.
-- V8-D1: the bridge's spot scales (v7 (0, -140)); the three discs move with it (their v7 offsets from it kept): with
-- their sizes kept, scaled discs would reach 47.8 studs along the route from the bridge's centre, past its 86-stud deck.
do
	local x, z = Layout.fromV7Local(0, -140)
	Layout.BRIDGE = table.freeze({ x = x, z = z, length = 86 })
end
local function withBridge(x, z, r)
	return table.freeze({ x = Layout.BRIDGE.x + (x - 0), z = Layout.BRIDGE.z + (z + 140), r = r })
end
Layout.LAKE = table.freeze({
	withBridge(0, -120, 24),
	withBridge(26, -134, 16),
	withBridge(-26, -134, 16),
})
-- Ground the builder scatters nothing on: the homes of the two Pradera beasts while they are parked in this plot
-- (WildboundCandyBeastSites_Test wants open floor there). Remove a row when its beast leaves.
local function keepClear(x, z, r, why)
	local kx, kz = Layout.fromV7Local(x, z)
	return table.freeze({ x = kx, z = kz, r = r, why = why })
end
Layout.KEEP_CLEAR = table.freeze({
	keepClear(165, 150, 26, "La Nube's pond"), -- GT: was (165, 110), now off the bigger boss ground
	keepClear(-60, 185, 10, "La Abeja's hive"),
	-- K-D2 (owner request 2026-11-17, kitten park: "es como el mundo de gatito: un parque verde lindo"): the plot side of
	-- the cloud gate to Caramelo Este (world (922, -3), in front of the wall's 14-stud gap at z -10..4), kept clear of
	-- hide spots, grass, traps and bee hives. Written in v8 plot coordinates, not through keepClear() (v7 ones).
	table.freeze({ x = 250, z = 0, r = 16, why = "Cloud gate to Caramelo Este" }),
})

-- V8-D1: the v7 spots below, scaled by nest() (x S); the rarity depth rings scale with them (WildboundCandyLayout_Test).
Layout.NESTS = table.freeze({
	nest("C1", "Comun", -160, -18),
	nest("C2", "Comun", -140, 24),
	nest("C3", "Comun", -90, -132),
	nest("C4", "Comun", -62, 130),
	nest("C5", "Comun", 60, 152), -- GT: was (128, 44), now under the boss ground; north of the right route's bend
	nest("R1", "Rara", -78, -30),
	nest("R2", "Rara", -78, 34),
	nest("R3", "Rara", -45, -93), -- GT: was (60, -110), by the new left leg
	nest("R4", "Rara", -20, 95), -- GT: was (62, 84), by the new right leg
	nest("E1", "Epica", -34, -20),
	nest("E2", "Epica", -34, 24), -- GT: was (20, 36), on the new left leg; now across the main path from E1
	nest("L1", "Legendaria", 36, -22),
	-- CH3 (owner request 2026-11-16, "more eggs too"): eight more floor nests near the routes, outside the boss territory
	-- and past the entrance; C7, R6 and C8 are guarded by the guardians' extra posts, the other five have an extra candy
	-- critter post beside them (WildboundPraderaSites.EXTRA_POSTS).
	nest("C6", "Comun", 10, -162), -- south of the biscuit bridge (left route)
	nest("C7", "Comun", 5, 142), -- north of the lollipop avenue (right route)
	nest("C8", "Comun", 60, -170), -- GT: was (140, -70), now under the boss ground; south of the left route's bend
	nest("C9", "Comun", -135, -62), -- west of the left route's first leg
	nest("C10", "Comun", -60, -162), -- south-west of the bridge
	nest("R5", "Rara", 88, 112), -- outside the right route's bend
	nest("R6", "Rara", 96, -122), -- outside the left route's bend
	nest("R7", "Rara", -116, 58), -- west of the right route's first leg
	-- GT2 (owner request 2026-11-16, "more eggs and more creatures, a livelier map"): eight more floor nests, 20 -> 28
	-- (3 Comun, 4 Rara, 1 Epica), each with one more extra post beside it (WildboundPraderaSites.EXTRA_POSTS, 16 -> 24).
	nest("E3", "Epica", 0, 36), -- the freed centre, north of the junction, between the avenue and the right leg
	nest("R8", "Rara", -110, 95), -- outside the right route's first bend
	nest("R9", "Rara", -60, 70), -- inside the right route's first bend
	nest("R10", "Rara", -10, -45), -- south of the junction, by the left route's last leg
	nest("R11", "Rara", 36, 74), -- beside the right route's last leg, off the boss ground
	nest("C11", "Comun", -30, 150), -- north of the lollipop avenue, west of C7
	nest("C12", "Comun", -130, -100), -- south of the left route's first leg
	nest("C13", "Comun", 100, -150), -- outside the left route's bend, south of R6
})

-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT1-CT3): the Gran Torta as a tower. tiers are the kit cake's four
-- collision cylinders (WildboundCandyKit.PROXIES.CakeTower) at the builder's scale (TORTA.radius * 2 / 72), heights from
-- FLOOR_TOP. CT1: a spiral stair, one flight per tier, climbing counter-clockwise from startDegrees (south, by the DG7
-- stair decoy) around the outside of each tier, standing on the floor or on the ledge of the tier below; a flight ends
-- level with its tier's top, then a short landing on that ledge leads to the next flight. CT2: the three lower tiers
-- turn slowly, alternating (1 and -1: the sign of the angular velocity about +Y), one turn per spinPeriodSeconds; the top
-- tier (the summit with the best egg, Frutillon and La Duquesa) stays still.
-- GT: the scale follows TORTA.radius (no literal of its own): radius 42 gives tiers of radius 42, 32.7, 23.3 and 14 with
-- tops 21, 38.5, 53.7 and 65.3, and a stair of 21 + 18 + 16 + 12 = 67 steps.
do
	local scale, tiers = Layout.TORTA.radius / 36, {}
	local function glaze(x, z, r)
		return table.freeze({ x = Layout.TORTA.x + (x - 114), z = Layout.TORTA.z + (z - 0), r = r })
	end
	for i, row in ipairs({ { 72, 18, 0 }, { 56, 15, 18 }, { 40, 13, 33 }, { 24, 10, 46 } }) do
		tiers[i] = table.freeze({ radius = row[1] / 2 * scale, bottom = row[3] * scale, top = (row[3] + row[2]) * scale })
	end
	Layout.TOWER = table.freeze({
		tiers = table.freeze(tiers),
		-- GT: 90 -> 140 s, so the wider bottom rim still turns under 2 studs/s
		spinPeriodSeconds = 140,
		spinDirections = table.freeze({ 1, -1, 1, 0 }),
		-- V7-D2 (owner request 2026-11-17, "the cake's stairs twice as big"): width 3.8 -> 7.4 (7.6 would cover the next
		-- tier's rim dollops: a ledge is 9.33 wide, the dollops take its outer 1.45), tread 2.6 -> 5.2; the rise stays 1
		-- (walkable without jumping), so the step count (67) and the part count stay the same.
		stair = table.freeze({ width = 7.4, inset = 0.45, tread = 5.2, maxRise = 1, startDegrees = -100, landingDegrees = 15 }),
		-- CT3: the best egg of the biome, a Legendaria nest (not event-only) on the summit, beside La Duquesa (who sits on
		-- the centre), across the summit from where the stair arrives. x, z are plot coordinates like every nest's. GT: the
		-- kit's nest at full size (0.7 -> 1) on the wider summit, 9.4 studs from the centre.
		summit = table.freeze({ id = "T1", rarity = "Legendaria", x = Layout.TORTA.x, z = Layout.TORTA.z + 9.4, scale = 1 }),
		-- DG4: Don Glaseon's glaze puddles on his plaza, round the Torta, off the stair (south) and the nests.
		-- V8-D1: they move with the Torta (v7 literals round the v7 Torta at (114, 0), offsets kept).
		glaze = table.freeze({
			-- V7-D2: puddle 2 (165, 8) -> (170, 9), 10.5 studs out from the wider stair's first flight
			glaze(114, 52, 6), glaze(170, 9, 6), glaze(75, 34, 6),
		}),
	})
end

-- CT1: every stair step, flight by flight: { flight, index, x, z (local to the plot), angle (radians, x = cos, z = sin),
-- radius (of its centre), bottom, top (from FLOOR_TOP) }. Pure.
function Layout.stairSteps()
	local T, steps = Layout.TOWER, {}
	local S = T.stair
	local angle = math.rad(S.startDegrees)
	for k, tier in ipairs(T.tiers) do
		local base = k == 1 and 0 or T.tiers[k - 1].top
		local count = math.ceil((tier.top - base) / S.maxRise - 1e-9)
		local rise = (tier.top - base) / count
		local radius = tier.radius + S.inset + S.width / 2
		local step = S.tread / radius
		for i = 1, count do
			local a = angle + (i - 0.5) * step
			table.insert(steps, { flight = k, index = i, angle = a, radius = radius, bottom = base, top = base + i * rise,
				x = Layout.TORTA.x + math.cos(a) * radius, z = Layout.TORTA.z + math.sin(a) * radius })
		end
		angle += count * step + math.rad(S.landingDegrees)
	end
	return steps
end

function Layout.flat(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end

-- Studs from the nearest plot edge, inwards: 0 on the edge, HALF at the centre (the layout's square rings).
function Layout.depth(x, z)
	return Layout.HALF - math.max(math.abs(x), math.abs(z))
end

-- Flat distance from a point to the segment a-b.
function Layout.segmentDistance(x, z, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local length2 = dx * dx + dz * dz
	local t = 0
	if length2 > 0 then t = math.clamp(((x - a.x) * dx + (z - a.z) * dz) / length2, 0, 1) end
	return Layout.flat(x, z, a.x + dx * t, a.z + dz * t)
end

-- Flat distance from a point to the centreline of the nearest route (or of the named one).
function Layout.routeDistance(x, z, name)
	local best = math.huge
	for _, key in ipairs(Layout.ROUTE_ORDER) do
		if name == nil or name == key then
			local points = Layout.ROUTES[key]
			for i = 1, #points - 1 do
				best = math.min(best, Layout.segmentDistance(x, z, points[i], points[i + 1]))
			end
		end
	end
	return best
end

function Layout.routeLength(name)
	local points, total = Layout.ROUTES[name], 0
	for i = 1, #points - 1 do
		total += Layout.flat(points[i].x, points[i].z, points[i + 1].x, points[i + 1].z)
	end
	return total
end

-- A local point in world coordinates for a plot centred at the given centre ({x, z}, default Layout.CENTRE).
function Layout.world(p, centre)
	centre = centre or Layout.CENTRE
	return { x = centre.x + p.x, z = centre.z + p.z }
end

return Layout
