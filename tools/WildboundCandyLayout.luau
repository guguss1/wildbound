-- Caramelo biome blockout (odd/tasks/caramelo-bioma.md, T1; pack 04_ENTORNO/01_LAYOUT_MUNDO.md). The candy biome takes
-- the Pradera plot (WildboundBiomes key "pradera", tag Meadow). Pure data and flat geometry: no services, no clock, no
-- random. Coordinates are local to the plot centre: x grows east (away from the hub), z as in the world; the entrance is
-- the middle of the west edge, in line with the hub's east gate. Every number here is a first proposal to tune in play.
-- WildboundCandyBuilder turns this into parts; WildboundCandyLayout_Test holds the rules.
local Layout = {}

local function point(x, z) return table.freeze({ x = x, z = z }) end
local function route(points)
	local list = {}
	for i, p in ipairs(points) do list[i] = point(p[1], p[2]) end
	return table.freeze(list)
end
local function nest(id, rarity, x, z)
	return table.freeze({ id = id, rarity = rarity, x = x, z = z, eventOnly = rarity == "Legendaria" })
end

Layout.ROOT_NAME = "Candy_Bioma_v1"
Layout.VERSION = 2
Layout.SEED = 20261114
Layout.CENTRE = point(612, -3)
Layout.HALF = 200
Layout.FLOOR_TOP = 0.5
Layout.PATH_WIDTH = 14
-- The blockout places candidates only: nothing here spawns eggs or beasts.
Layout.SPAWNS_ENABLED = false
-- CE1 (odd/tasks/wildbound-caramelo.md): the nests are live egg nests of the island system (WildboundCandyNests);
-- the event-only legendary nest stays off (no Caramelo event yet). false turns every nest back into a candidate.
Layout.NESTS_ENABLED = true

Layout.ENTRANCE = point(-200, 0)
Layout.FORK = point(-110, 0)
Layout.JUNCTION = point(130, 0)
Layout.TORTA = table.freeze({ x = 0, z = 0, radius = 26 })
-- Don Glaseon's ground: the plaza he walks and the limit he never leaves. perception and whipLength are the pack's
-- starting balance (05_SISTEMAS/04_BALANCE_INICIAL_CONFIG.md); they only size the safe distances here.
Layout.BOSS = table.freeze({ x = 0, z = 0, plazaRadius = 44, territoryRadius = 62, perception = 36, whipLength = 22,
	home = point(-34, 0) })
-- Return to the hub (pack 04_ENTORNO/03: 5 s without threat, 2 s channel, 30 s cooldown). CE3: live; the server's
-- WildboundPortalService binds its prompt while the model's Enabled attribute is true (Builder.syncPortal).
Layout.PORTAL = table.freeze({ x = 160, z = 0, quietSeconds = 5, channelSeconds = 2, cooldownSeconds = 30, enabled = true })

Layout.ROUTES = table.freeze({
	main = route({ { -200, 0 }, { -110, 0 }, { -44, 0 } }),
	-- Left of a player walking in: the syrup riverside, longer and under the cotton trees.
	left = route({ { -110, 0 }, { -100, -80 }, { -50, -140 }, { 50, -140 }, { 110, -90 }, { 130, 0 } }),
	-- Right: the lollipop avenue, open and shorter.
	right = route({ { -110, 0 }, { -90, 70 }, { -40, 120 }, { 40, 120 }, { 100, 80 }, { 130, 0 } }),
	deep = route({ { 130, 0 }, { 160, 0 } }),
})
Layout.ROUTE_ORDER = table.freeze({ "main", "left", "right", "deep" })
Layout.RETURN_ROUTES = table.freeze({ "left", "right" })

-- Laguna de Almibar: shallow discs { x, z, r } crossed by one biscuit bridge on the left route.
Layout.LAKE = table.freeze({
	table.freeze({ x = 0, z = -120, r = 24 }),
	table.freeze({ x = 26, z = -134, r = 16 }),
	table.freeze({ x = -26, z = -134, r = 16 }),
})
Layout.BRIDGE = table.freeze({ x = 0, z = -140, length = 86 })
-- Ground the builder scatters nothing on: the homes of the two Pradera beasts while they are parked in this plot
-- (WildboundCandyBeastSites_Test wants open floor there). Remove a row when its beast leaves.
Layout.KEEP_CLEAR = table.freeze({
	table.freeze({ x = 165, z = 110, r = 26, why = "La Nube's pond" }),
	table.freeze({ x = -60, z = 185, r = 10, why = "La Abeja's hive" }),
})

Layout.NESTS = table.freeze({
	nest("C1", "Comun", -160, -18),
	nest("C2", "Comun", -140, 24),
	nest("C3", "Comun", -90, -132),
	nest("C4", "Comun", -62, 130),
	nest("C5", "Comun", 128, 44), -- was (136, 56): La Nube, parked in the south-east corner, saw players there
	nest("R1", "Rara", -78, -30),
	nest("R2", "Rara", -78, 34),
	nest("R3", "Rara", 60, -110),
	nest("R4", "Rara", 62, 84),
	nest("E1", "Epica", -34, -20),
	nest("E2", "Epica", 20, 36),
	nest("L1", "Legendaria", 36, -22),
	-- CH3 (owner request 2026-11-16, "more eggs too"): eight more floor nests near the routes, outside the boss territory
	-- and past the entrance; C7, R6 and C8 are guarded by the guardians' extra posts, the other five have an extra candy
	-- critter post beside them (WildboundPraderaSites.EXTRA_POSTS).
	nest("C6", "Comun", 10, -162), -- south of the biscuit bridge (left route)
	nest("C7", "Comun", 5, 142), -- north of the lollipop avenue (right route)
	nest("C8", "Comun", 140, -70), -- by the left route's last leg, away from the portal
	nest("C9", "Comun", -135, -62), -- west of the left route's first leg
	nest("C10", "Comun", -60, -162), -- south-west of the bridge
	nest("R5", "Rara", 88, 112), -- outside the right route's bend
	nest("R6", "Rara", 96, -122), -- outside the left route's bend
	nest("R7", "Rara", -116, 58), -- west of the right route's first leg
})

-- Caramelo v2 (odd/tasks/wildbound-caramelo-v2.md, CT1-CT3): the Gran Torta as a tower. tiers are the kit cake's four
-- collision cylinders (WildboundCandyKit.PROXIES.CakeTower) at the builder's scale (TORTA.radius * 2 / 72), heights from
-- FLOOR_TOP. CT1: a spiral stair, one flight per tier, climbing counter-clockwise from startDegrees (south, by the DG7
-- stair decoy) around the outside of each tier, standing on the floor or on the ledge of the tier below; a flight ends
-- level with its tier's top, then a short landing on that ledge leads to the next flight. CT2: the three lower tiers
-- turn slowly, alternating (1 and -1: the sign of the angular velocity about +Y), one turn per spinPeriodSeconds; the top
-- tier (the summit with the best egg, Frutillon and La Duquesa) stays still.
do
	local scale, tiers = 26 / 36, {}
	for i, row in ipairs({ { 72, 18, 0 }, { 56, 15, 18 }, { 40, 13, 33 }, { 24, 10, 46 } }) do
		tiers[i] = table.freeze({ radius = row[1] / 2 * scale, bottom = row[3] * scale, top = (row[3] + row[2]) * scale })
	end
	Layout.TOWER = table.freeze({
		tiers = table.freeze(tiers),
		spinPeriodSeconds = 90,
		spinDirections = table.freeze({ 1, -1, 1, 0 }),
		stair = table.freeze({ width = 3.8, inset = 0.5, tread = 2.6, maxRise = 1, startDegrees = -100, landingDegrees = 15 }),
		-- CT3: the best egg of the biome, a Legendaria nest (not event-only) on the summit, the kit's nest at 70 % so it
		-- fits beside La Duquesa (who sits on the centre), across the summit from where the stair arrives.
		summit = table.freeze({ id = "T1", rarity = "Legendaria", x = 0, z = 5.8, scale = 0.7 }),
		-- DG4: Don Glaseon's glaze puddles on his plaza, round the Torta, off the stair (south) and the nests.
		glaze = table.freeze({
			table.freeze({ x = 0, z = 36, r = 6 }), table.freeze({ x = 38, z = 6, r = 6 }), table.freeze({ x = -30, z = 26, r = 6 }),
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
