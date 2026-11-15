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
-- Return to the hub (pack 04_ENTORNO/03: 5 s without threat, 2 s channel, 30 s cooldown). A position only for now.
Layout.PORTAL = table.freeze({ x = 160, z = 0, quietSeconds = 5, channelSeconds = 2, cooldownSeconds = 30, enabled = false })

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
})

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
