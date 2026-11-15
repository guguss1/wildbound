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

	case("S5: twelve candidate nests, 5 Comun, 4 Rara, 2 Epica, 1 Legendaria", function()
		equal(#Layout.NESTS, 12, "nests")
		local count, ids = {}, {}
		for _, nest in ipairs(Layout.NESTS) do
			count[nest.rarity] = (count[nest.rarity] or 0) + 1
			assert(type(nest.id) == "string" and not ids[nest.id], "duplicate or missing nest id")
			ids[nest.id] = true
		end
		equal(count.Comun, 5, "Comun")
		equal(count.Rara, 4, "Rara")
		equal(count.Epica, 2, "Epica")
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

	case("S4: the boss territory has limits inside the plot and holds the plaza", function()
		local B = Layout.BOSS
		equal(B.x, Layout.TORTA.x, "centred on the Torta x")
		equal(B.z, Layout.TORTA.z, "centred on the Torta z")
		assert(B.plazaRadius > Layout.TORTA.radius + Layout.PATH_WIDTH, "no room for the boss around the Torta")
		assert(B.territoryRadius > B.plazaRadius, "territory smaller than the plaza")
		assert(Layout.depth(B.x + B.territoryRadius, B.z) >= 75 and Layout.depth(B.x, B.z + B.territoryRadius) >= 75,
			"territory reaches the outer ring")
		assert(flat(B.home.x, B.home.z, B.x, B.z) <= B.plazaRadius, "home outside the plaza")
		assert(flat(B.home.x, B.home.z, B.x, B.z) >= Layout.TORTA.radius + 6, "home inside the Torta")
		for _, p in ipairs({ Layout.ENTRANCE, Layout.FORK, Layout.JUNCTION }) do
			assert(flat(p.x, p.z, B.x, B.z) >= B.territoryRadius + B.perception, "a safe point is within boss sight")
		end
	end)

	case("S4: the portal is past the boss's reach and switched off", function()
		local P, B = Layout.PORTAL, Layout.BOSS
		assert(flat(P.x, P.z, B.x, B.z) - B.territoryRadius >= B.perception + B.whipLength, "portal under the boss")
		assert(Layout.depth(P.x, P.z) >= 30, "portal on the plot edge")
		assert(P.x > 0, "portal on the deep side")
		equal(P.enabled, false, "enabled")
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

	return result
end
