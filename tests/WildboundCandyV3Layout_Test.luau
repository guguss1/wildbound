-- Invoke with require(freshTestClone)(require(freshCandyV3LayoutClone), require(freshCandyLayoutClone),
--   require(freshPraderaSitesClone), require(freshCandyTrapCakeClone)).
-- Caramelo v3 (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md): the pure layout rules of the new
-- pieces over layout VERSION 3. The river runs from the waterfall pool into the lake, the routes meet the chocolate only
-- on the bridge, nests, creature posts, trap cakes, the boss ground, the portal, the entrance and the stair stay clear,
-- the houses, mountains, docks, licorice and cake keep their distances, and the raft's lane floats between two banks.
-- No services and no instances; tools/test_caramelo_v3.py checks the same geometry outside Studio.
return function(V3, Layout, Sites, Trap)
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
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	local C = V3.CLEAR
	local half = Layout.PATH_WIDTH / 2
	-- Points every 2 studs along every route: { name, x, z }.
	local function routeSamples()
		local out = {}
		for _, name in ipairs(Layout.ROUTE_ORDER) do
			local route = Layout.ROUTES[name]
			for i = 1, #route - 1 do
				local a, b = route[i], route[i + 1]
				local steps = math.max(1, math.ceil(flat(a.x, a.z, b.x, b.z) / 2))
				for s = 0, steps do
					table.insert(out, { name = name, x = a.x + (b.x - a.x) * s / steps, z = a.z + (b.z - a.z) * s / steps })
				end
			end
		end
		return out
	end
	-- The creature posts in plot coordinates.
	local function posts()
		local out = {}
		for key, p in pairs(Sites.FIXED) do
			table.insert(out, { id = key, x = p.x - Layout.CENTRE.x, z = p.z - Layout.CENTRE.z })
		end
		table.sort(out, function(a, b) return a.id < b.id end)
		return out
	end

	case("V3-1: the data is versioned, frozen and names its kit", function()
		equal(V3.VERSION, 1, "VERSION")
		equal(V3.MARK, "CaramelV3", "mark")
		equal(V3.KIT_FOLDER, "CandyKitV3", "kit folder")
		assert(table.isfrozen(V3) and table.isfrozen(V3.RIVER) and table.isfrozen(V3.HOUSES), "frozen")
		equal(Layout.VERSION, 3, "laid over the GT layout")
		for _, name in ipairs({ "CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple", "CV3_IceCreamMountain_L",
			"CV3_LicoriceArch", "CV3_CakeBase", "CV3_CookieS", "CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower", "CV3_BananaRaft" }) do
			assert(table.find(V3.ASSETS, name), "asset " .. name)
		end
	end)

	case("V3-2: a big river from the waterfall pool's outlet into the lake, inside the plot", function()
		local first, last = V3.RIVER[1], V3.RIVER[#V3.RIVER]
		assert(flat(first[1], first[2], V3.POOL.x, V3.POOL.z) <= V3.POOL.r + 1, "the river starts at the pool's outlet")
		local inLake = false
		for _, disc in ipairs(V3.LAKE) do
			if flat(last[1], last[2], disc.x, disc.z) < disc.r then inLake = true end
		end
		assert(inLake, "the river does not end in the lake")
		assert(V3.riverLength() >= 250, "a short river: " .. V3.riverLength())
		for i, p in ipairs(V3.RIVER) do
			assert(i == 1 or p[3] >= 20, "point " .. i .. " is narrower than 20")
			assert(Layout.depth(p[1], p[2]) - p[3] / 2 >= 2, "point " .. i .. " leaves the plot")
		end
		assert(V3.liquidDistance(V3.POOL.x, V3.POOL.z) < 0 and V3.liquidDistance(0, -110) < 0, "pool and lake are chocolate")
		assert(V3.LIQUID.depth > 0.5 and V3.LIQUID.depth <= 2, "knee-deep at most: nobody drowns")
		local samples = V3.riverSamples(2)
		assert(#samples > 100, "samples")
		for _, s in ipairs(samples) do assert(V3.liquidDistance(s.x, s.z) < 0, "a gap in the river") end
	end)

	case("V3-3: the waterfall falls from the big mountain into the pool", function()
		local W, m1 = V3.WATERFALL, nil
		for _, m in ipairs(V3.MOUNTAINS) do if m.river then m1 = m end end
		assert(m1 and m1.asset == "CV3_IceCreamMountain_L", "the river's mountain is the big one")
		equal(m1.faceX, V3.RIVER[2][1], "its outlet faces the river x"); equal(m1.faceZ, V3.RIVER[2][2], "z")
		assert(flat(W.x, W.z, m1.x, m1.z) < m1.r, "the sheet stands on the mountain")
		assert(flat(W.x, W.z, V3.POOL.x, V3.POOL.z) < V3.POOL.r, "it falls into the pool")
		equal(W.faceX, V3.POOL.x, "faces the pool x"); equal(W.faceZ, V3.POOL.z, "faces the pool z")
		assert(W.top >= 15 and W.top < m1.height, "under the mountain's top")
		assert(W.streaks >= 3 and W.flowSpeed > 0, "it flows")
	end)

	case("V3-4: routes meet the chocolate only on the bridge", function()
		for _, p in ipairs(routeSamples()) do
			local d = V3.liquidDistance(p.x, p.z)
			if d <= 0 then
				assert(V3.onBridge(p.x, p.z, true), ("%s wades at %.1f, %.1f"):format(p.name, p.x, p.z))
			end
			if d < half then
				assert(V3.onBridge(p.x, p.z), ("%s's edge wades at %.1f, %.1f"):format(p.name, p.x, p.z))
			end
		end
		local B = V3.BRIDGE
		assert(B.width > Layout.PATH_WIDTH, "the deck is wider than the path")
		assert(B.deck > V3.surfaceY(0), "the deck stands over the surface")
		local onLeg = false
		local route = Layout.ROUTES[B.route]
		for i = 1, #route - 1 do
			local a, b = route[i], route[i + 1]
			if a.z == B.z and b.z == B.z and math.min(a.x, b.x) <= B.x - B.length / 2 and math.max(a.x, b.x) >= B.x + B.length / 2 then
				onLeg = true
			end
		end
		assert(onLeg, "the deck lies on one straight leg of the " .. B.route .. " route")
	end)

	case("V3-5: nests, posts, trap cakes, the boss ground, the stair, the portal and the entrance stay off the chocolate", function()
		for _, spec in ipairs(Layout.NESTS) do
			assert(V3.liquidDistance(spec.x, spec.z) >= C.nestFromLiquid, "nest " .. spec.id .. " by the chocolate")
		end
		local S = Layout.TOWER.summit
		assert(V3.liquidDistance(S.x, S.z) > 0, "summit nest")
		for _, p in ipairs(posts()) do
			assert(V3.liquidDistance(p.x, p.z) >= C.postFromLiquid, "post " .. p.id .. " by the chocolate")
		end
		for _, spot in ipairs(Trap.SPOTS) do
			assert(V3.liquidDistance(spot.x, spot.z) >= C.trapFromAnything, "trap cake " .. spot.key)
		end
		local B = Layout.BOSS
		assert(V3.liquidDistance(B.x, B.z) >= B.territoryRadius, "chocolate in the boss territory")
		for _, step in ipairs(Layout.stairSteps()) do
			assert(V3.liquidDistance(step.x, step.z) > 10, "chocolate on the stair")
		end
		assert(V3.liquidDistance(Layout.PORTAL.x, Layout.PORTAL.z) >= 16, "portal")
		assert(V3.liquidDistance(Layout.ENTRANCE.x, Layout.ENTRANCE.z) >= 28, "entrance")
		for _, spot in ipairs(Layout.KEEP_CLEAR) do
			assert(V3.liquidDistance(spot.x, spot.z) >= spot.r, "chocolate on " .. spot.why)
		end
	end)

	case("V3-6: houses, mountains, docks, licorice legs and the cake keep their distances", function()
		local pieces = V3.pieces()
		local B = Layout.BOSS
		for _, p in ipairs(pieces) do
			local label = p.kind .. " " .. p.id
			for _, spec in ipairs(Layout.NESTS) do
				assert(flat(p.x, p.z, spec.x, spec.z) - p.r >= C.pieceFromNest, label .. " on nest " .. spec.id)
			end
			for _, post in ipairs(posts()) do
				assert(flat(p.x, p.z, post.x, post.z) - p.r >= C.pieceFromPost, label .. " on post " .. post.id)
			end
			for _, spot in ipairs(Trap.SPOTS) do
				assert(flat(p.x, p.z, spot.x, spot.z) - p.r >= C.trapFromAnything, label .. " on trap cake " .. spot.key)
			end
			assert(Layout.routeDistance(p.x, p.z) - p.r - half >= C.pieceFromRoute, label .. " on a route")
			assert(flat(p.x, p.z, B.x, B.z) - p.r >= B.territoryRadius, label .. " in the boss territory")
			assert(flat(p.x, p.z, Layout.PORTAL.x, Layout.PORTAL.z) - p.r >= 16, label .. " at the portal")
			assert(flat(p.x, p.z, Layout.ENTRANCE.x, Layout.ENTRANCE.z) - p.r >= 28, label .. " at the entrance")
			for _, spot in ipairs(Layout.KEEP_CLEAR) do
				assert(flat(p.x, p.z, spot.x, spot.z) - p.r - spot.r >= C.pieceApart, label .. " on " .. spot.why)
			end
			if p.kind == "mountain" then
				assert(Layout.depth(p.x, p.z) >= p.r - 0.5, label .. " leaves the plot")
			else
				assert(Layout.depth(p.x, p.z) - p.r >= C.edgeDepth, label .. " by the plot edge")
			end
			local source = p.kind == "mountain" and V3.MOUNTAINS[1].id == p.id and V3.MOUNTAINS[1].river
			if not source and p.kind ~= "dock" then
				assert(V3.liquidDistance(p.x, p.z) - p.r >= C.pieceApart, label .. " in the chocolate")
			end
		end
		for i, a in ipairs(pieces) do
			for j = i + 1, #pieces do
				local b = pieces[j]
				-- the cake's ramp is built against its base
				assert(a.kind == "cake" and b.kind == "cake" or flat(a.x, a.z, b.x, b.z) - a.r - b.r >= C.pieceApart, a.kind .. " " .. a.id .. " touches " .. b.kind .. " " .. b.id)
			end
		end
	end)

	case("V3-7: five to seven houses of the three kinds, in every quarter of the plot", function()
		assert(#V3.HOUSES >= 5 and #V3.HOUSES <= 7, "houses " .. #V3.HOUSES)
		local kinds, quarters = {}, {}
		for _, h in ipairs(V3.HOUSES) do
			kinds[h.asset] = true
			quarters[(h.x > 0 and "E" or "W") .. (h.z > 0 and "N" or "S")] = true
			assert(V3.HOUSE_PLACEHOLDER[h.asset], h.asset .. " has a placeholder size")
		end
		assert(kinds.CV3_SweetHouse and kinds.CV3_ChocoHouse and kinds.CV3_CaramelTower, "all three kinds")
		assert(quarters.EN and quarters.ES and quarters.WN and quarters.WS, "a house in every quarter")
	end)

	case("V3-8: the docks stand on both banks and the raft's lane floats", function()
		equal(#V3.DOCKS, 2, "two docks")
		local a, b = V3.DOCKS[1], V3.DOCKS[2]
		for _, d in ipairs(V3.DOCKS) do
			assert(V3.liquidDistance(d.standX, d.standZ) > 0, "stand " .. d.id .. " on land")
			assert(V3.liquidDistance(d.tipX, d.tipZ) < -2, "tip " .. d.id .. " over the river")
		end
		local p, q = V3.RIVER[1], V3.RIVER[2]
		local function side(x, z) return (q[1] - p[1]) * (z - p[2]) - (q[2] - p[2]) * (x - p[1]) end
		assert(side(a.standX, a.standZ) * side(b.standX, b.standZ) < 0, "the docks are on the same bank")
		local lane = V3.RAFT.lane
		equal(lane[1][1], a.tipX, "lane starts at tip A"); equal(lane[1][2], a.tipZ)
		equal(lane[#lane][1], b.tipX, "lane ends at tip B"); equal(lane[#lane][2], b.tipZ)
		for i = 1, #lane - 1 do
			for s = 0, 10 do
				local x = lane[i][1] + (lane[i + 1][1] - lane[i][1]) * s / 10
				local z = lane[i][2] + (lane[i + 1][2] - lane[i][2]) * s / 10
				assert(V3.liquidDistance(x, z) < -1.5, ("the lane runs aground at %.1f, %.1f"):format(x, z))
			end
		end
		equal(V3.RAFT.homeDock, 1, "home dock")
		local world = V3.raftLane(Layout.CENTRE)
		equal(world[1].x, Layout.CENTRE.x + lane[1][1], "world lane x")
		equal(world[1].z, Layout.CENTRE.z + lane[1][2], "world lane z")
	end)

	case("V3-9: the licorice spans the main path, the platforms float on the lake off the bridge", function()
		local Lc = V3.LICORICE
		assert(Layout.routeDistance(Lc.x, Lc.z, "main") < 0.01, "the arch is centred on the main path")
		for _, foot in ipairs(Lc.feet) do
			assert((foot.offset - foot.r) * Lc.scale - half >= 4, "its feet clear the path")
		end
		assert(Lc.height >= 18, "a walker passes under it")
		for i, pl in ipairs(V3.PLATFORMS) do
			local inside = false
			for _, disc in ipairs(V3.LAKE) do
				if flat(pl.x, pl.z, disc.x, disc.z) + pl.r <= disc.r then inside = true end
			end
			assert(inside, "platform " .. i .. " leaves the lake")
			assert(math.abs(pl.z - V3.BRIDGE.z) - pl.r > V3.BRIDGE.width / 2, "platform " .. i .. " under the bridge")
			for j = i + 1, #V3.PLATFORMS do
				local other = V3.PLATFORMS[j]
				assert(flat(pl.x, pl.z, other.x, other.z) - pl.r - other.r >= 2, "platforms " .. i .. " and " .. j .. " touch")
			end
		end
	end)

	case("V3-10: the tree rule keeps the lollipops and maps every other kind to a new one", function()
		local map = V3.TREES.map
		equal(map.TreeCotton_S, "CV3_TreeCotton"); equal(map.TreeCotton_M, "CV3_TreeCotton"); equal(map.TreeCotton_L, "CV3_TreeCotton")
		equal(map.TreeCream, "CV3_TreeIceCream"); equal(map.TreeCookie, "CV3_TreeCaramelApple")
		equal(map.TreeLollipop_Straight, nil, "lollipops stay"); equal(map.TreeLollipop_Tilted, nil, "lollipops stay")
		assert(V3.TREES.minFactor > 0.5 and V3.TREES.minFactor < 1, "a tree shrinks a little at most")
	end)

	case("V3-11: helpers", function()
		assert(math.abs(V3.faceYaw(0, 0, 0, -10)) < 1e-9, "looking north (-z) is yaw 0")
		local yaw = V3.faceYaw(0, 0, 10, 0)
		assert(math.abs(-math.sin(yaw) - 1) < 1e-9 and math.abs(-math.cos(yaw)) < 1e-9, "looking east")
		assert(V3.onBridge(V3.BRIDGE.x, V3.BRIDGE.z, true), "the bridge centre is on the deck")
		assert(not V3.onBridge(V3.BRIDGE.x + V3.BRIDGE.length / 2 + 1, V3.BRIDGE.z, true), "past the deck")
		assert(V3.onBridge(V3.BRIDGE.x + V3.BRIDGE.length / 2 + 1, V3.BRIDGE.z), "on a ramp")
		local ok, why = V3.clearOfPieces(V3.POOL.x, V3.POOL.z, 1)
		assert(not ok and why == "in the chocolate", "the pool is not open ground")
		ok = V3.clearOfPieces(-150, 60, 3)
		assert(ok, "open ground in the west")
		equal(V3.surfaceY(0.5), 0.5 + V3.LIQUID.depth, "surface height")
	end)

	return result
end
