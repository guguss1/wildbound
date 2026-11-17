-- Invoke with require(freshTestClone)(require(freshLayoutClone), require(freshBiomesClone)).
-- Caramelo biome blockout (odd/tasks/caramelo-bioma.md, T1, S2 S4 S5): the pure layout rules of the candy biome that
-- takes the Pradera plot. Coordinates are local to the plot centre: x grows east (away from the hub), the entrance is
-- on the west edge. No services and no instances; the built model has its own suite (WildboundCandyBuilder_Test).
return function(Layout, Biomes)
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

	case("S2: the plot is the square Pradera used", function()
		local area
		for _, candidate in ipairs(Biomes.AREAS) do if candidate.key == "pradera" then area = candidate end end
		assert(area, "no pradera square in WildboundBiomes")
		equal(Layout.CENTRE.x - Layout.HALF, area.minX, "minX")
		equal(Layout.CENTRE.x + Layout.HALF, area.maxX, "maxX")
		equal(Layout.CENTRE.z - Layout.HALF, area.minZ, "minZ")
		equal(Layout.CENTRE.z + Layout.HALF, area.maxZ, "maxZ")
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
	case("S5/CH3/GT2: twenty-eight candidate nests, 13 Comun, 11 Rara, 3 Epica, 1 Legendaria", function()
		equal(#Layout.NESTS, 28, "nests")
		local count, ids = {}, {}
		for _, nest in ipairs(Layout.NESTS) do
			count[nest.rarity] = (count[nest.rarity] or 0) + 1
			assert(type(nest.id) == "string" and not ids[nest.id], "duplicate or missing nest id")
			ids[nest.id] = true
		end
		equal(count.Comun, 13, "Comun")
		equal(count.Rara, 11, "Rara")
		equal(count.Epica, 3, "Epica")
		equal(count.Legendaria, 1, "Legendaria")
	end)

	case("S5: only the legendary nest waits for an event", function()
		for _, nest in ipairs(Layout.NESTS) do
			equal(nest.eventOnly, nest.rarity == "Legendaria", nest.id .. " eventOnly")
		end
	end)

	case("layout contract: each rarity sits in its depth ring (0-75, 75-160, 160-200)", function()
		local ring = { Comun = { 0, 75 }, Rara = { 75, 160 }, Epica = { 160, 200 }, Legendaria = { 160, 200 } }
		for _, nest in ipairs(Layout.NESTS) do
			local depth = Layout.depth(nest.x, nest.z)
			local band = ring[nest.rarity]
			assert(depth >= band[1] and depth <= band[2], nest.id .. " at depth " .. depth)
		end
		equal(Layout.depth(-200, 0), 0, "edge depth")
		equal(Layout.depth(0, 0), 200, "centre depth")
		equal(Layout.depth(30, -150), 50, "square rings")
	end)

	case("S5: the first common nests are 30 to 70 studs past the entrance", function()
		local near = 0
		for _, nest in ipairs(Layout.NESTS) do
			local distance = flat(nest.x, nest.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z)
			assert(distance >= 30, nest.id .. " crowds the entrance")
			if distance <= 70 then
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
			assert(toRoute <= 40 or toTorta <= Layout.BOSS.plazaRadius, nest.id .. " is unreachable")
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
		for _, p in ipairs({ Layout.ENTRANCE, Layout.FORK, Layout.JUNCTION }) do
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
		assert(Layout.depth(T.x + Layout.BOSS.plazaRadius, T.z) <= 30, "its plaza does not reach the east edge's ring")
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

	return result
end
