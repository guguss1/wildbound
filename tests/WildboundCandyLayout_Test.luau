-- Invoke with require(freshTestClone)(require(freshLayoutClone), require(freshBiomesClone)).
-- Caramelo biome blockout (odd/tasks/caramelo-bioma.md, T1, S2 S4 S5): the pure layout rules of the candy biome that
-- takes the Pradera plot. Coordinates are local to the plot centre: x grows east (away from the hub), the entrance is
-- on the west edge. No services and no instances; the built model has its own suite (WildboundCandyBuilder_Test).
-- V8-D1 (Caramelo v8): Biomes is still passed but no longer read; the plot left the classic "pradera" square.
return function(Layout, _Biomes)
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function same(a, b, label)
		assert(type(a) == "table" and type(b) == "table" and a.x == b.x and a.z == b.z, (label or "point") .. " differs")
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	-- Points every 2 studs along a named route.
	local function samples(name)
		local route, points = Layout.ROUTES[name], {}
		for i = 1, #route - 1 do
			local a, b = route[i], route[i + 1]
			local steps = math.max(1, math.ceil(flat(a.x, a.z, b.x, b.z) / 2))
			for s = 0, steps do
				table.insert(points, { x = a.x + (b.x - a.x) * s / steps, z = a.z + (b.z - a.z) * s / steps })
			end
		end
		return points
	end

	-- Deliberately changed (V8-D1, owner request 2026-11-17 "make the Reino Caramelo map a bit bigger"): the plot is no
	-- longer the classic "pradera" square (x 412..812, z -203..197); it grows 1.3 times to world x 412..932, z -263..257,
	-- inside the big4 Meadow square (x 412..1012, z -303..297), and its entrance stays at world (412, -3) on the hub road.
	-- Deliberately changed again (CL-D1, Caramelo v9, owner request 2026-11-18 "agranda mas el bioma caramelo a lo
	-- largo"): the plot grows 600 studs east only, to world x 412..1532 (EAST 860), inside the big4 arm x 412..1612;
	-- CENTRE and HALF (the west and z half-lengths) stay.
	case("S2/V8-D1/CL-D1: the plot lies inside the big4 Caramelo arm, its entrance on the hub road", function()
		local C, H = Layout.CENTRE, Layout.HALF
		equal(H, 260, "HALF")
		equal(Layout.EAST, 860, "CL-D1: EAST")
		equal(C.x, 672, "centre x")
		equal(C.z, -3, "centre z")
		equal(C.x - H, 412, "CL-D1: the plot's west edge, world x")
		equal(C.x + Layout.EAST, 1532, "CL-D1: the plot's east edge, world x")
		assert(C.x - H >= 412 and C.x + Layout.EAST <= 1612, "CL-D1: the plot leaves the big4 arm in x")
		assert(C.z - H >= -303 and C.z + H <= 297, "the plot leaves the big4 arm in z")
		equal(C.x + Layout.ENTRANCE.x, 412, "entrance world x")
		equal(C.z + Layout.ENTRANCE.z, -3, "entrance world z")
		equal(Layout.FLOOR_TOP, 0.5, "floor top, level with the hub road")
		equal(string.sub(Layout.ROOT_NAME, 1, 6), "Candy_", "versioned Candy_ prefix")
	end)

	case("S5: the central path is 14 studs wide", function()
		equal(Layout.PATH_WIDTH, 14)
	end)

	case("S4: the main corridor runs from the west entrance through the fork to the Torta plaza", function()
		local main = Layout.ROUTES.main
		same(main[1], Layout.ENTRANCE, "start")
		equal(Layout.ENTRANCE.x, -Layout.HALF, "entrance on the west edge")
		equal(Layout.ENTRANCE.z, 0, "entrance in line with the hub east gate")
		same(main[2], Layout.FORK, "fork")
		local last = main[#main]
		equal(flat(last.x, last.z, Layout.TORTA.x, Layout.TORTA.z), Layout.BOSS.plazaRadius, "ends at the plaza edge")
	end)

	case("S4: two return routes join the fork and the deep junction without crossing the boss", function()
		equal(#Layout.RETURN_ROUTES, 2, "return routes")
		local keepOut = Layout.BOSS.territoryRadius + Layout.PATH_WIDTH / 2
		for _, name in ipairs(Layout.RETURN_ROUTES) do
			local route = Layout.ROUTES[name]
			same(route[1], Layout.FORK, name .. " start")
			same(route[#route], Layout.JUNCTION, name .. " end")
			for _, p in ipairs(samples(name)) do
				assert(flat(p.x, p.z, Layout.BOSS.x, Layout.BOSS.z) >= keepOut, name .. " enters the boss territory")
				assert(Layout.depth(p.x, p.z) >= 20, name .. " leaves the plot")
			end
		end
		assert(Layout.routeLength("left") > Layout.routeLength("right"), "the covered left route is the slower one")
		same(Layout.ROUTES.deep[1], Layout.JUNCTION, "deep start")
		equal(Layout.ROUTES.deep[2].x, Layout.PORTAL.x, "deep end x")
		equal(Layout.ROUTES.deep[2].z, Layout.PORTAL.z, "deep end z")
	end)

	-- Deliberately changed (CH3, owner request 2026-11-16 "more eggs too"): 8 more floor nests near the routes, 5 Comun
	-- (C6-C10) and 3 Rara (R5-R7), no new Epica or Legendaria: 12 -> 20 (5 -> 10 Comun, 4 -> 7 Rara).
	-- Deliberately changed again (GT2, owner request 2026-11-16 "more eggs and more creatures, a livelier map"): 8 more,
	-- 3 Comun (C11-C13), 4 Rara (R8-R11) and 1 Epica (E3), no Legendaria: 20 -> 28 (10 -> 13 Comun, 7 -> 11 Rara, 2 -> 3
	-- Epica).
	-- Deliberately changed again (CL-D10, Caramelo v9): 17 new nests on the grown east, 6 Comun (C14-C19), 8 Rara
	-- (R12-R19) and 3 Epica (E4-E6): 28 -> 45 (19 Comun, 19 Rara, 6 Epica, 1 Legendaria), 44 live.
	case("S5/CH3/GT2/CL-D10: forty-five candidate nests, 19 Comun, 19 Rara, 6 Epica, 1 Legendaria", function()
		equal(#Layout.NESTS, 45, "nests")
		local count, ids = {}, {}
		for _, nest in ipairs(Layout.NESTS) do
			count[nest.rarity] = (count[nest.rarity] or 0) + 1
			assert(type(nest.id) == "string" and not ids[nest.id], "duplicate or missing nest id")
			ids[nest.id] = true
		end
		equal(count.Comun, 19, "Comun")
		equal(count.Rara, 19, "Rara")
		equal(count.Epica, 6, "Epica")
		equal(count.Legendaria, 1, "Legendaria")
		local live = 0
		for _, nest in ipairs(Layout.NESTS) do
			if not nest.eventOnly then live += 1 end
		end
		equal(live, 44, "CL-D10: live nests")
	end)

	case("S5: only the legendary nest waits for an event", function()
		for _, nest in ipairs(Layout.NESTS) do
			equal(nest.eventOnly, nest.rarity == "Legendaria", nest.id .. " eventOnly")
		end
	end)

	-- Deliberately changed (V8-D1): the rings scale with the plot, 0-75, 75-160, 160-200 -> 0-97.5, 97.5-208, 208-260.
	case("layout contract: each rarity sits in its depth ring (v7 0-75, 75-160, 160-200, x 1.3)", function()
		local S = Layout.V8.S
		local ring = { Comun = { 0, 75 * S }, Rara = { 75 * S, 160 * S }, Epica = { 160 * S, 200 * S }, Legendaria = { 160 * S, 200 * S } }
		for _, nest in ipairs(Layout.NESTS) do
			local depth = Layout.depth(nest.x, nest.z)
			local band = ring[nest.rarity]
			assert(depth >= band[1] and depth <= band[2], nest.id .. " at depth " .. depth)
		end
		equal(Layout.depth(-Layout.HALF, 0), 0, "edge depth")
		equal(Layout.depth(0, 0), Layout.HALF, "centre depth")
		equal(Layout.depth(39, -195), 65, "square rings")
		-- CL-D1: the depth is now the rectangle's, min(x + HALF, EAST - x, HALF - |z|); the ring numbers stay
		equal(Layout.depth(860, 0), 0, "CL-D1: the east edge")
		equal(Layout.depth(800, 0), 60, "CL-D1: 60 inside the east edge")
		equal(Layout.depth(300, 250), 10, "CL-D1: by the north edge in the east")
	end)

	-- Deliberately changed (V8-D1): the band scales with the plot, 30-70 -> 39-91 studs (C1 57, C2 84).
	case("S5: the first common nests are 39 to 91 studs past the entrance (v7 30 to 70, x 1.3)", function()
		local near, S = 0, Layout.V8.S
		for _, nest in ipairs(Layout.NESTS) do
			local distance = flat(nest.x, nest.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z)
			assert(distance >= 30 * S, nest.id .. " crowds the entrance")
			if distance <= 70 * S then
				equal(nest.rarity, "Comun", nest.id .. " near the entrance")
				near += 1
			end
		end
		assert(near >= 2, "fewer than two first nests")
	end)

	case("nests are off the paths, reachable, apart and clear of the Torta", function()
		for i, nest in ipairs(Layout.NESTS) do
			local toRoute = Layout.routeDistance(nest.x, nest.z)
			local toTorta = flat(nest.x, nest.z, Layout.TORTA.x, Layout.TORTA.z)
			assert(toRoute >= Layout.PATH_WIDTH / 2 + 4, nest.id .. " blocks a path")
			-- Deliberately changed (V8-D1): 40 -> 40 x 1.3 = 52 studs off a route (the farthest, C13, is 49.4 off)
			assert(toRoute <= 40 * Layout.V8.S or toTorta <= Layout.BOSS.plazaRadius, nest.id .. " is unreachable")
			assert(toTorta >= Layout.TORTA.radius + 6, nest.id .. " is inside the Torta")
			for j = i + 1, #Layout.NESTS do
				local other = Layout.NESTS[j]
				assert(flat(nest.x, nest.z, other.x, other.z) >= 20, nest.id .. " touches " .. other.id)
			end
		end
	end)

	-- CH3: every nest (the new ones too) stays out of the syrup and off the parked Pradera beasts' ground (KEEP_CLEAR); the
	-- new ones lie outside Don Glaseon's territory and away from the hub entrance (the stair: WildboundCandyTower_Test).
	case("CH3: nests stay out of the syrup and off KEEP_CLEAR; the new ones are outside the boss territory and past the entrance", function()
		for _, nest in ipairs(Layout.NESTS) do
			for _, disc in ipairs(Layout.LAKE) do
				assert(flat(nest.x, nest.z, disc.x, disc.z) >= disc.r + 6, nest.id .. " in the syrup")
			end
			for _, spot in ipairs(Layout.KEEP_CLEAR) do
				assert(flat(nest.x, nest.z, spot.x, spot.z) >= spot.r + 20, nest.id .. " on " .. spot.why)
			end
		end
		local new = { C6 = true, C7 = true, C8 = true, C9 = true, C10 = true, R5 = true, R6 = true, R7 = true }
		local found = 0
		for _, nest in ipairs(Layout.NESTS) do
			if new[nest.id] then
				found += 1
				equal(nest.eventOnly, false, nest.id .. " is live")
				assert(flat(nest.x, nest.z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius + 20, nest.id .. " in the boss territory")
				assert(flat(nest.x, nest.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= 80, nest.id .. " by the hub entrance")
			end
		end
		equal(found, 8, "new nests")
	end)

	case("S4: the boss territory has limits inside the plot and holds the plaza", function()
		local B = Layout.BOSS
		equal(B.x, Layout.TORTA.x, "centred on the Torta x")
		equal(B.z, Layout.TORTA.z, "centred on the Torta z")
		assert(B.plazaRadius > Layout.TORTA.radius + Layout.PATH_WIDTH, "no room for the boss around the Torta")
		assert(B.territoryRadius > B.plazaRadius, "territory smaller than the plaza")
		-- Deliberately changed (GT, the cake at the east end): the territory may reach the outer ring now, but stays 10
		-- studs inside the plot (was >= 75 with the Torta in the middle).
		assert(Layout.depth(B.x + B.territoryRadius, B.z) >= 10 and Layout.depth(B.x, B.z + B.territoryRadius) >= 10
			and Layout.depth(B.x, B.z - B.territoryRadius) >= 10, "territory leaves the plot")
		assert(flat(B.home.x, B.home.z, B.x, B.z) <= B.plazaRadius, "home outside the plaza")
		assert(flat(B.home.x, B.home.z, B.x, B.z) >= Layout.TORTA.radius + 6, "home inside the Torta")
		-- Deliberately changed (CL-D6): the east fork, where the far routes leave the avenue, is a safe point too
		for _, p in ipairs({ Layout.ENTRANCE, Layout.FORK, Layout.JUNCTION, Layout.EAST_FORK }) do
			assert(flat(p.x, p.z, B.x, B.z) >= B.territoryRadius + B.perception, "a safe point is within boss sight")
		end
	end)

	case("S4: the portal is past the boss's reach and, since CE3, switched on", function()
		local P, B = Layout.PORTAL, Layout.BOSS
		assert(flat(P.x, P.z, B.x, B.z) - B.territoryRadius >= B.perception + B.whipLength, "portal under the boss")
		assert(Layout.depth(P.x, P.z) >= 30, "portal on the plot edge")
		-- Deliberately changed (GT): the portal is on the way back from the cake (was "on the deep side", P.x > 0)
		assert(P.x < Layout.TORTA.x - B.territoryRadius, "portal on the way back from the cake")
		equal(P.enabled, true, "enabled (CE3: the return portal is live)")
		equal(P.quietSeconds, 5, "quiet")
		equal(P.channelSeconds, 2, "channel")
		equal(P.cooldownSeconds, 30, "cooldown")
	end)

	case("S4: spawns stay off in the blockout", function()
		equal(Layout.SPAWNS_ENABLED, false)
	end)

	case("CE1: the nests are live egg nests; the legendary one stays event-only", function()
		equal(Layout.NESTS_ENABLED, true, "NESTS_ENABLED")
		local events = 0
		for _, spec in ipairs(Layout.NESTS) do
			if spec.eventOnly then events += 1; equal(spec.rarity, "Legendaria", spec.id) end
		end
		equal(events, 1, "event-only nests")
	end)

	case("the syrup lake stays out of the boss territory and under the bridge", function()
		assert(#Layout.LAKE >= 1, "no lake")
		for _, disc in ipairs(Layout.LAKE) do
			assert(flat(disc.x, disc.z, Layout.BOSS.x, Layout.BOSS.z) - disc.r >= Layout.BOSS.territoryRadius, "lake in territory")
			assert(Layout.depth(disc.x, disc.z) - disc.r >= 20, "lake leaves the plot")
		end
		local bridge = Layout.BRIDGE
		for _, name in ipairs({ "main", "left", "right", "deep" }) do
			for _, p in ipairs(samples(name)) do
				for _, disc in ipairs(Layout.LAKE) do
					if flat(p.x, p.z, disc.x, disc.z) <= disc.r then
						assert(math.abs(p.x - bridge.x) <= bridge.length / 2 and math.abs(p.z - bridge.z) <= Layout.PATH_WIDTH / 2,
							name .. " wades through syrup at " .. p.x .. ", " .. p.z)
					end
				end
			end
		end
	end)

	-- GT (owner request 2026-11-16, "the cake with the princess at the end, and much bigger";
	-- docs/design/wildbound-caramelo-cake-move-plan.md): layout version 3.
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end

	case("GT1: the Gran Torta is the end of the biome: east of every route, nest and the portal, its plaza by the east edge", function()
		equal(Layout.VERSION, 3, "layout version")
		local T = Layout.TORTA
		assert(T.x >= Layout.HALF / 2, "the Torta is not in the east half's far part: " .. T.x)
		-- Deliberately changed (V8-D1): <= 30 -> <= 60: the plot grew 1.3 times and the plaza kept its 58, so it ends 53.8
		-- studs from the east edge (was 28; V8-D3 counts on that room by the cloud wall)
		-- CL-D9: the same rule, now through the rectangle depth: the Torta moved +600 with the east edge, 53.8 again
		assert(Layout.depth(T.x + Layout.BOSS.plazaRadius, T.z) <= 60, "its plaza does not reach the east edge's ring")
		near(Layout.depth(T.x + Layout.BOSS.plazaRadius, T.z), 53.8, "CL-D9: the plaza ends 53.8 from the east edge", 1e-6)
		for _, name in ipairs(Layout.ROUTE_ORDER) do
			for _, p in ipairs(Layout.ROUTES[name]) do assert(p.x < T.x, name .. " passes behind the Torta") end
		end
		for _, nest in ipairs(Layout.NESTS) do assert(nest.x < T.x, nest.id .. " is behind the Torta") end
		assert(Layout.PORTAL.x < Layout.JUNCTION.x + 1, "the portal is past the junction")
		local main = Layout.ROUTES.main
		local last, before = main[#main], main[#main - 1]
		same(before, Layout.JUNCTION, "the avenue starts at the junction")
		assert(last.x > before.x and last.z == T.z and before.z == T.z, "the avenue runs straight east at the Torta")
	end)

	case("GT2: radius 40-44 (1.6 times the old 26), every tier from it, no scale of its own", function()
		local T, tiers = Layout.TORTA, Layout.TOWER.tiers
		assert(T.radius >= 40 and T.radius <= 44, "radius " .. T.radius)
		near(tiers[1].radius, T.radius, "the bottom tier is the Torta")
		near(tiers[1].bottom, 0, "on the floor")
		for i, row in ipairs({ { 72, 18, 0 }, { 56, 15, 18 }, { 40, 13, 33 }, { 24, 10, 46 } }) do
			near(tiers[i].radius, row[1] / 72 * T.radius, "radius " .. i)
			near(tiers[i].top, (row[3] + row[2]) / 36 * T.radius, "top " .. i)
		end
		assert(tiers[#tiers].top >= 60, "the summit stands " .. tiers[#tiers].top .. " studs up")
	end)

	case("GT3: the plaza holds the whole stair and room to walk round; the territory holds the plaza and stays in the plot", function()
		local B, T = Layout.BOSS, Layout.TORTA
		local outer = 0
		for _, s in ipairs(Layout.stairSteps()) do
			outer = math.max(outer, flat(s.x, s.z, T.x, T.z) + Layout.TOWER.stair.width / 2)
		end
		assert(outer + Layout.PATH_WIDTH / 2 <= B.plazaRadius, ("the stair reaches %.1f of the plaza's %d"):format(outer, B.plazaRadius))
		assert(B.territoryRadius >= B.plazaRadius + 10, "territory hugs the plaza")
		for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { 0, -1 } }) do
			assert(Layout.depth(B.x + d[1] * B.territoryRadius, B.z + d[2] * B.territoryRadius) >= 10, "territory leaves the plot")
		end
		local main = Layout.ROUTES.main
		equal(flat(main[#main].x, main[#main].z, B.x, B.z), B.plazaRadius, "the avenue ends at the plaza edge")
		local home = B.home
		assert(flat(home.x, home.z, main[#main].x, main[#main].z) <= 10, "he sleeps at the end of the avenue")
	end)

	case("GT4: the junction and every return route stay out of the boss's sight", function()
		local B = Layout.BOSS
		assert(flat(Layout.JUNCTION.x, Layout.JUNCTION.z, B.x, B.z) >= B.territoryRadius + B.perception, "the junction is in his sight")
		for _, name in ipairs(Layout.RETURN_ROUTES) do
			for _, p in ipairs(samples(name)) do
				assert(flat(p.x, p.z, B.x, B.z) >= B.territoryRadius + Layout.PATH_WIDTH / 2, name .. " enters the territory")
			end
		end
	end)

	case("GT5: the portal is out of the boss's reach, on the deep route from the junction, off the nests", function()
		local P, B = Layout.PORTAL, Layout.BOSS
		assert(flat(P.x, P.z, B.x, B.z) - B.territoryRadius >= B.perception + B.whipLength, "portal under the boss")
		local deep = Layout.ROUTES.deep
		same(deep[1], Layout.JUNCTION, "deep start"); equal(deep[#deep].x, P.x, "deep end x"); equal(deep[#deep].z, P.z, "deep end z")
		for _, nest in ipairs(Layout.NESTS) do assert(flat(nest.x, nest.z, P.x, P.z) >= 16, nest.id .. " on the portal") end
	end)

	case("GT6: the summit nest and the glaze puddles follow the Torta", function()
		local T, S = Layout.TORTA, Layout.TOWER.summit
		equal(S.x, T.x, "summit x"); near(S.z - T.z, 9.4, "summit z, from the centre"); equal(S.scale, 1, "the kit's nest at full size")
		for i, g in ipairs(Layout.TOWER.glaze) do
			local r = flat(g.x, g.z, T.x, T.z)
			assert(r - g.r >= T.radius + 2 and r <= Layout.BOSS.plazaRadius, "puddle " .. i .. " round the Torta")
		end
	end)

	-- GT2 (owner request "more eggs and more creatures"): the eight new nests are live (not event-only), outside the boss
	-- territory and away from the hub entrance, like CH3's.
	case("GT2: the eight new nests are live, outside the boss territory and past the entrance", function()
		local new, found = { E3 = true, R8 = true, R9 = true, R10 = true, R11 = true, C11 = true, C12 = true, C13 = true }, 0
		for _, nest in ipairs(Layout.NESTS) do
			if new[nest.id] then
				found += 1
				equal(nest.eventOnly, false, nest.id .. " is live")
				assert(flat(nest.x, nest.z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius + 20, nest.id .. " in the boss territory")
				assert(flat(nest.x, nest.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= 80, nest.id .. " by the hub entrance")
			end
		end
		equal(found, 8, "new nests")
	end)

	-- V8-D1 (owner request 2026-11-17, "more space between things"; docs/design/wildbound-caramelo-v8-plan.md): the v7 ->
	-- v8 transform other modules use, and the layout built from it: positions x 1.3 about the centre, sizes kept, the
	-- re-anchored and translated exceptions.
	case("V8-D1: fromV7Local / fromV7World scale 1.3 about the centre, pure; positions follow, sizes stay", function()
		local V = Layout.V8
		assert(table.isfrozen(V) and table.isfrozen(V.OLD_CENTRE), "V8 frozen")
		equal(V.S, 1.3, "S"); equal(V.OLD_HALF, 200, "old half")
		equal(V.OLD_CENTRE.x, 612, "old centre x"); equal(V.OLD_CENTRE.z, -3, "old centre z")
		local x, z = Layout.fromV7Local(100, -50)
		near(x, 130, "local x"); near(z, -65, "local z")
		x, z = Layout.fromV7World(612, -3)
		equal(x, 672, "old centre -> new centre x"); equal(z, -3, "old centre -> new centre z")
		x, z = Layout.fromV7World(412, -3)
		near(x, 412, "the v7 entrance stays x"); near(z, -3, "the v7 entrance stays z")
		x, z = Layout.fromV7World(812, 197)
		near(x, 932, "the v7 north-east corner x"); near(z, 257, "the v7 north-east corner z")
		local lx, lz = Layout.fromV7Local(-150, 60)
		local wx, wz = Layout.fromV7World(612 - 150, -3 + 60)
		near(wx - Layout.CENTRE.x, lx, "world and local agree x"); near(wz - Layout.CENTRE.z, lz, "world and local agree z")
		local again = { Layout.fromV7World(500, 100) }
		local twice = { Layout.fromV7World(500, 100) }
		equal(again[1], twice[1], "pure x"); equal(again[2], twice[2], "pure z")
		-- positions scale
		near(Layout.FORK.x, -143, "fork"); same(Layout.JUNCTION, { x = 0, z = 0 }, "junction")
		-- Deliberately changed (CL-D9): the Torta moves +600 with the east edge, 148.2 -> 748.2 (the transform stays as a
		-- record: its v8 spot is fromV7Local(114, 0))
		near(Layout.TORTA.x, 748.2, "Torta"); near(Layout.PORTAL.x, -31.2, "portal")
		near(Layout.fromV7Local(114, 0), 148.2, "the v8 Torta, kept as the transform's record")
		near(Layout.NESTS[1].x, -208, "C1 x"); near(Layout.NESTS[1].z, -23.4, "C1 z")
		near(Layout.KEEP_CLEAR[1].x, 214.5, "pond x"); near(Layout.KEEP_CLEAR[1].z, 195, "pond z")
		-- sizes stay
		equal(Layout.TORTA.radius, 42, "Torta radius"); equal(Layout.BOSS.plazaRadius, 58, "plaza")
		equal(Layout.BOSS.territoryRadius, 76, "territory"); equal(Layout.PATH_WIDTH, 14, "path")
		equal(Layout.KEEP_CLEAR[1].r, 26, "pond radius"); equal(Layout.BRIDGE.length, 86, "biscuit bridge")
		-- re-anchored: the entrance on the west edge, the avenue's end on the plaza edge
		same(Layout.ENTRANCE, { x = -Layout.HALF, z = 0 }, "entrance")
		local main = Layout.ROUTES.main
		near(main[#main].x, Layout.TORTA.x - Layout.BOSS.plazaRadius, "the avenue ends on the plaza edge")
		-- translated with their parent: home with the boss, the glaze with the Torta, the syrup with its bridge
		near(Layout.BOSS.home.x - Layout.BOSS.x, 64 - 114, "home keeps its v7 offset")
		for i, offset in ipairs({ { 0, 52 }, { 56, 9 }, { -39, 34 } }) do
			local g = Layout.TOWER.glaze[i]
			near(g.x - Layout.TORTA.x, offset[1], "puddle " .. i .. " x"); near(g.z - Layout.TORTA.z, offset[2], "puddle " .. i .. " z")
		end
		near(Layout.BRIDGE.z, -182, "the biscuit bridge scales")
		for i, offset in ipairs({ { 0, 20 }, { 26, 6 }, { -26, 6 } }) do
			local d = Layout.LAKE[i]
			near(d.x - Layout.BRIDGE.x, offset[1], "syrup " .. i .. " x"); near(d.z - Layout.BRIDGE.z, offset[2], "syrup " .. i .. " z")
		end
		assert(table.isfrozen(Layout.NESTS) and table.isfrozen(Layout.NESTS[1]) and table.isfrozen(Layout.ROUTES.main)
			and table.isfrozen(Layout.LAKE[1]) and table.isfrozen(Layout.TOWER.glaze[1]), "the layout stays frozen")
	end)

	-- K-D2 (owner request 2026-11-17, the kitten park: "es como el mundo de gatito"): the plot side of the cloud gate to
	-- Caramelo Este was kept clear for the server-start planners (hide spots, grass, traps, bee hives).
	-- Deliberately changed (CL-D12, PGM-D8): Pueblo Gatito left the east of the plot, the gate is gone and the plot now
	-- runs on past (250, 0), so the stale gate row goes; only the two Pradera rows remain.
	case("K-D2/CL-D12: the KEEP_CLEAR gate row is gone; the pond and the hive rows stay first", function()
		for _, spot in ipairs(Layout.KEEP_CLEAR) do
			assert(spot.why ~= "Cloud gate to Caramelo Este", "CL-D12: the stale gate row is still there")
			assert(table.isfrozen(spot), spot.why .. " is frozen")
		end
		-- the two Pradera rows are still the first two, unchanged (the suites pin [1])
		equal(Layout.KEEP_CLEAR[1].why, "La Nube's pond"); equal(Layout.KEEP_CLEAR[2].why, "La Abeja's hive")
		equal(#Layout.KEEP_CLEAR, 2, "CL-D12: two rows")
	end)

	-- CL-D1, CL-D9 (Caramelo v9, owner request 2026-11-18: the kingdom grows east only, "a lo largo";
	-- docs/design/wildbound-caramelo-v9-plan.md): one new number, V9.GROWTH, makes EAST and moves the Torta.
	case("V9-1: EAST 860 and the rectangle depth; the Torta is the v8 one + 600; plaza 53.8; CENTRE and ENTRANCE stay", function()
		local V = Layout.V9
		assert(type(V) == "table" and table.isfrozen(V), "V9 frozen")
		equal(V.GROWTH, 600, "growth"); equal(V.OLD_EAST, 260, "the v8 east half")
		equal(Layout.EAST, Layout.HALF + V.GROWTH, "EAST = HALF + GROWTH")
		equal(Layout.EAST, 860, "EAST")
		equal(Layout.HALF, 260, "HALF stays (the west and z half-lengths)")
		equal(Layout.CENTRE.x, 672, "centre x"); equal(Layout.CENTRE.z, -3, "centre z")
		same(Layout.ENTRANCE, { x = -260, z = 0 }, "entrance")
		for _, row in ipairs({ { 0, 0, 260 }, { -260, 0, 0 }, { 860, 0, 0 }, { 800, 0, 60 }, { 300, 250, 10 }, { 39, -195, 65 },
			{ 300, -260, 0 }, { -100, 0, 160 } }) do
			near(Layout.depth(row[1], row[2]), row[3], ("depth(%g, %g)"):format(row[1], row[2]))
		end
		local v8x = Layout.fromV7Local(114, 0)
		near(Layout.TORTA.x, v8x + V.GROWTH, "the Torta is the v8 one + 600")
		near(Layout.TORTA.x, 748.2, "Torta x"); equal(Layout.TORTA.z, 0, "Torta z"); equal(Layout.TORTA.radius, 42, "Torta radius")
		near(Layout.BOSS.home.x, 698.2, "boss home x")
		near(Layout.TOWER.summit.x, 748.2, "summit x"); near(Layout.TOWER.summit.z, 9.4, "summit z")
		near(Layout.depth(Layout.TORTA.x + Layout.BOSS.plazaRadius, 0), 53.8, "plaza edge depth")
		near(Layout.depth(Layout.TORTA.x + Layout.BOSS.territoryRadius, 0), 35.8, "territory edge depth")
		same(Layout.EAST_FORK, { x = 300, z = 0 }, "the east fork")
		equal(Layout.CENTRE.x + Layout.EAST_FORK.x, 972, "east fork world x")
		near(Layout.PORTAL.x, -31.2, "the Portal stays")
		local main = Layout.ROUTES.main
		near(main[#main].x, 690.2, "the avenue's end follows the Torta")
		near(Layout.routeLength("main"), 950.2, "the avenue's length")
	end)

	-- CL-D10: the 17 new nests on the grown east.
	local NEW_V9 = { "C14", "C15", "C16", "C17", "C18", "C19", "R12", "R13", "R14", "R15", "R16", "R17", "R18", "R19", "E4", "E5", "E6" }
	local function nestById(id)
		for _, nest in ipairs(Layout.NESTS) do
			if nest.id == id then return nest end
		end
		return nil
	end
	case("V9-2: the 17 new nests are live, in their rings, reachable, >= 96 from the boss and >= 80 from the entrance", function()
		local ring = { Comun = { 0, 97.5 }, Rara = { 97.5, 208 }, Epica = { 208, 260 } }
		local B = Layout.BOSS
		for _, id in ipairs(NEW_V9) do
			local nest = nestById(id)
			assert(nest, id .. " is missing")
			assert(table.isfrozen(nest), id .. " is frozen")
			equal(nest.eventOnly, false, id .. " is live")
			equal(nest.rarity, ({ C = "Comun", R = "Rara", E = "Epica" })[string.sub(id, 1, 1)], id .. " rarity")
			local depth, band = Layout.depth(nest.x, nest.z), ring[nest.rarity]
			assert(depth >= band[1] and depth <= band[2], id .. " at depth " .. depth)
			local toRoute = Layout.routeDistance(nest.x, nest.z)
			assert(toRoute >= Layout.PATH_WIDTH / 2 + 4 and toRoute <= 52, id .. " route " .. toRoute)
			assert(flat(nest.x, nest.z, B.x, B.z) >= B.territoryRadius + 20, id .. " in the boss territory")
			assert(flat(nest.x, nest.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= 80, id .. " by the hub entrance")
			assert(nest.x < Layout.TORTA.x, id .. " behind the Torta")
		end
		-- the four moved nests (nestAt, v9 literals, no 1.3 scaling)
		for _, row in ipairs({ { "C6", 55, -168 }, { "C8", 105, -183 }, { "C10", -52, -167 }, { "C13", 35, 190 } }) do
			local nest = nestById(row[1])
			assert(nest, row[1] .. " is missing")
			equal(nest.x, row[2], row[1] .. " x"); equal(nest.z, row[3], row[1] .. " z"); equal(nest.rarity, "Comun", row[1])
			assert(flat(nest.x, nest.z, B.x, B.z) >= B.territoryRadius + 20, row[1] .. " in the boss territory")
		end
	end)

	-- CL-D6: the far routes south and north leave the avenue at the east fork.
	case("V9-3: south and north start at EAST_FORK on the avenue, west of the Torta, >= 83 from the boss, depth >= 20", function()
		local order = {}
		for i, name in ipairs(Layout.ROUTE_ORDER) do order[name] = i end
		equal(#Layout.ROUTE_ORDER, 6, "six routes")
		assert(order.south and order.north, "south and north are in ROUTE_ORDER")
		assert(Layout.routeDistance(Layout.EAST_FORK.x, Layout.EAST_FORK.z, "main") < 1e-6, "the east fork is on the avenue")
		local B = Layout.BOSS
		for _, name in ipairs({ "south", "north" }) do
			local route = Layout.ROUTES[name]
			assert(table.isfrozen(route), name .. " is frozen")
			same(route[1], Layout.EAST_FORK, name .. " start")
			for _, p in ipairs(route) do assert(p.x < Layout.TORTA.x, name .. " passes behind the Torta") end
			for _, p in ipairs(samples(name)) do
				assert(flat(p.x, p.z, B.x, B.z) >= B.territoryRadius + Layout.PATH_WIDTH / 2, name .. " enters the territory")
				assert(Layout.depth(p.x, p.z) >= 20, name .. " leaves the plot")
			end
		end
		near(Layout.routeLength("south"), 527.4, "south length", 0.05)
		near(Layout.routeLength("north"), 426.6, "north length", 0.05)
		equal(#Layout.RETURN_ROUTES, 2, "the return routes stay left and right")
	end)

	-- CL-D10 reward lean: the new Epica sit deepest east, on the cake bank (x >= 500, past the 60-wide reach at x 470;
	-- the bank itself is WildboundCandyV3Layout_Test V3-21's flood fill).
	case("V9-4: the 3 new Epica are on the cake bank; their mean x exceeds the new Rara's and the new Comun's", function()
		local sum, count = {}, {}
		for _, id in ipairs(NEW_V9) do
			local nest = nestById(id)
			assert(nest, id .. " is missing")
			sum[nest.rarity] = (sum[nest.rarity] or 0) + nest.x
			count[nest.rarity] = (count[nest.rarity] or 0) + 1
			if nest.rarity == "Epica" then assert(nest.x >= 500, id .. " is not on the cake bank") end
		end
		equal(count.Epica, 3, "new Epica"); equal(count.Rara, 8, "new Rara"); equal(count.Comun, 6, "new Comun")
		local epica, rara, comun = sum.Epica / count.Epica, sum.Rara / count.Rara, sum.Comun / count.Comun
		assert(epica > rara and epica > comun, ("mean x: Epica %.1f, Rara %.1f, Comun %.1f"):format(epica, rara, comun))
	end)

	return result
end
