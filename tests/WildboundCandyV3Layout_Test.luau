-- Invoke with require(freshTestClone)(require(freshCandyV3LayoutClone), require(freshCandyLayoutClone),
--   require(freshPraderaSitesClone), require(freshCandyTrapCakeClone)).
-- Caramelo v3 (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md): the pure layout rules of the new
-- pieces over layout VERSION 3. Caramelo v4 (V4-D1 to V4-D17): the river runs from M1's waterfall pool by the north
-- edge through the lake to the south edge, a barrier west of the cake; the routes meet the chocolate only on a bridge, nests, creature posts, trap cakes, the boss ground, the portal, the entrance and the stair stay clear,
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
		-- Deliberately changed (V4): VERSION 1 -> 2, and the v4 mark
		-- Deliberately changed (V5): VERSION 2 -> 3, and the v5 mark
		equal(V3.VERSION, 3, "VERSION")
		equal(V3.V4_MARK, "CaramelV4", "v4 mark")
		equal(V3.V5_MARK, "CaramelV5", "v5 mark")
		equal(V3.MARK, "CaramelV3", "mark")
		equal(V3.KIT_FOLDER, "CandyKitV3", "kit folder")
		assert(table.isfrozen(V3) and table.isfrozen(V3.RIVER) and table.isfrozen(V3.HOUSES), "frozen")
		equal(Layout.VERSION, 3, "laid over the GT layout")
		for _, name in ipairs({ "CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple", "CV3_IceCreamMountain_L",
			"CV3_LicoriceArch", "CV3_CakeBase", "CV3_CookieS", "CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower", "CV3_BananaRaft" }) do
			assert(table.find(V3.ASSETS, name), "asset " .. name)
		end
	end)

	-- Deliberately changed (V4): the river runs from M1's pool by the north edge through the lake to the south edge
	-- (V4-D1); it was a south-band river ending in the lake, at least 20 wide, inside the plot, 1.3 deep.
	case("V3-2: a big river from the waterfall pool's outlet through the lake to the south edge, 3.5 deep", function()
		local first, last = V3.RIVER[1], V3.RIVER[#V3.RIVER]
		assert(flat(first[1], first[2], V3.POOL.x, V3.POOL.z) <= V3.POOL.r + 1, "the river starts at the pool's outlet")
		local throughLake = false
		for i = 1, #V3.RIVER - 1 do
			local a, b = V3.RIVER[i], V3.RIVER[i + 1]
			for _, disc in ipairs(V3.LAKE) do
				if V3.segmentDistance(disc.x, disc.z, a[1], a[2], b[1], b[2]) < disc.r then throughLake = true end
			end
		end
		assert(throughLake, "the river does not run through the lake")
		assert(math.abs(Layout.depth(last[1], last[2])) < 0.01 and last[2] < 0, "the river ends on the south edge")
		local m1
		for _, m in ipairs(V3.MOUNTAINS) do if m.river then m1 = m end end
		assert(m1.z > 0 and m1.z + m1.r >= Layout.HALF - 0.5, "M1 stands on the north edge")
		assert(V3.riverLength() >= 340, "a short river: " .. V3.riverLength())
		local widest = 0
		for i, p in ipairs(V3.RIVER) do
			assert(i == 1 or p[3] >= 10, "point " .. i .. " is narrower than 10")
			widest = math.max(widest, p[3])
			assert(i == #V3.RIVER or Layout.depth(p[1], p[2]) - p[3] / 2 >= 2, "point " .. i .. " leaves the plot")
		end
		assert(widest >= 20, "a wide stretch for the raft")
		assert(V3.liquidDistance(V3.POOL.x, V3.POOL.z) < 0 and V3.liquidDistance(V3.LAKE[1].x, V3.LAKE[1].z) < 0, "pool and lake are chocolate")
		equal(V3.LIQUID.depth, 3.5, "V4-D2: 3.5 deep")
		local samples = V3.riverSamples(2)
		assert(#samples > 100, "samples")
		-- Deliberately changed (V6-D4): the lake's island stands in the river's mouth; its centreline meets the island's
		-- dry land and leaves it again, so a sample on an island is not a gap
		for _, s in ipairs(samples) do
			assert(V3.liquidDistance(s.x, s.z) < 0 or V3.islandAt(s.x, s.z), "a gap in the river")
		end
	end)

	-- V4-D1: no dry walk round the river: every west-to-east line meets the chocolate west of the cake's territory (or
	-- M1, the source, standing on the north edge).
	case("V3-14: the river is a barrier west of the cake", function()
		local m1
		for _, m in ipairs(V3.MOUNTAINS) do if m.river then m1 = m end end
		local B = Layout.BOSS
		for z = -Layout.HALF, Layout.HALF, 2 do
			if not (math.abs(z - m1.z) <= m1.r) then
				local westmost = math.huge
				for x = -Layout.HALF, Layout.HALF do
					if V3.liquidDistance(x, z) < 0 then westmost = math.min(westmost, x) end
				end
				assert(westmost < math.huge, "a dry line at z " .. z)
				assert(westmost < B.x - B.territoryRadius + 1, "the chocolate at z " .. z .. " is not west of the cake")
			end
		end
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

	-- Deliberately changed (V4): a list of bridges, one on every route leg the river crosses (was the single BRIDGE).
	case("V3-4: routes meet the chocolate only on a bridge, one on each crossed leg", function()
		for _, p in ipairs(routeSamples()) do
			local d = V3.liquidDistance(p.x, p.z)
			if d <= 0 then
				assert(V3.onBridge(p.x, p.z, true), ("%s wades at %.1f, %.1f"):format(p.name, p.x, p.z))
			end
			if d < half then
				assert(V3.onBridge(p.x, p.z), ("%s's edge wades at %.1f, %.1f"):format(p.name, p.x, p.z))
			end
		end
		local crossed = {}
		for _, B in ipairs(V3.BRIDGES) do
			assert(B.width > Layout.PATH_WIDTH, B.id .. ": the deck is wider than the path")
			assert(B.deck >= V3.LIQUID.depth + 0.6 - 1e-9, B.id .. ": the deck stands 0.6 over the surface")
			assert(math.deg(math.atan2(B.deck, B.ramp)) <= 25, B.id .. ": end ramps walkable")
			local onLeg = false
			local route = Layout.ROUTES[B.route]
			for i = 1, #route - 1 do
				local a, b = route[i], route[i + 1]
				if a.x == B.from[1] and a.z == B.from[2] and b.x == B.to[1] and b.z == B.to[2] then
					local legLength = flat(a.x, a.z, b.x, b.z)
					onLeg = B.at - B.length / 2 - B.ramp >= -1e-6 and B.at + B.length / 2 + B.ramp <= legLength + 1e-6
				end
			end
			assert(onLeg, B.id .. " lies on one straight leg of the " .. B.route .. " route")
			assert(V3.liquidDistance(B.x, B.z) < 0, B.id .. " stands over the chocolate")
			assert(V3.onBridge(B.x, B.z, true) == B, B.id .. " finds itself")
			crossed[B.route] = true
		end
		assert(crossed.main and crossed.left and crossed.right, "the main avenue, the left and the right route are bridged")
		-- no two bridges touch (deck, end ramps and side ramps), by separating axes
		local function overlap(p, q)
			for _, poly in ipairs({ p, q }) do
				for i = 1, 4 do
					local a, b = poly[i], poly[i % 4 + 1]
					local nx, nz = -(b.z - a.z), b.x - a.x
					local pMin, pMax, qMin, qMax = math.huge, -math.huge, math.huge, -math.huge
					for _, c in ipairs(p) do local v = nx * c.x + nz * c.z; pMin, pMax = math.min(pMin, v), math.max(pMax, v) end
					for _, c in ipairs(q) do local v = nx * c.x + nz * c.z; qMin, qMax = math.min(qMin, v), math.max(qMax, v) end
					if pMax < qMin or qMax < pMin then return false end
				end
			end
			return true
		end
		for i, a in ipairs(V3.BRIDGES) do
			for j = i + 1, #V3.BRIDGES do
				local b = V3.BRIDGES[j]
				assert(not overlap(V3.bridgeCorners(a), V3.bridgeCorners(b)), a.id .. " and " .. b.id .. " overlap")
			end
		end
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
			if p.kind ~= "dock" then assert(not V3.nearBridge(p.x, p.z, p.r), label .. " on a bridge") end
		end
		for i, a in ipairs(pieces) do
			for j = i + 1, #pieces do
				local b = pieces[j]
				-- the cake's ramp is built against its base
				local sameDock = a.kind == "dock" and b.kind == "dock" and string.sub(a.id, 1, 1) == string.sub(b.id, 1, 1)
				assert(a.kind == "cake" and b.kind == "cake" or sameDock or flat(a.x, a.z, b.x, b.z) - a.r - b.r >= C.pieceApart, a.kind .. " " .. a.id .. " touches " .. b.kind .. " " .. b.id)
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
		-- V4-D5: H1, H3 and H5 (one of each kind) at 1.4, footprints scaled with them
		local base = { CV3_SweetHouse = 20, CV3_ChocoHouse = 16, CV3_CaramelTower = 15 }
		local big = {}
		for _, h in ipairs(V3.HOUSES) do
			assert(h.scale == 1 or h.scale == 1.4, h.id .. " scale")
			assert(math.abs(h.r - base[h.asset] * h.scale) < 0.05, h.id .. " footprint")
			if h.scale > 1 then big[h.id] = h.asset end
		end
		equal(big.H1, "CV3_SweetHouse", "H1 bigger"); equal(big.H3, "CV3_ChocoHouse", "H3 bigger")
		equal(big.H5, "CV3_CaramelTower", "H5 bigger")
		-- V4-D15: the towers' balconies (+Z) look at the junction; every door keeps an approach inside the plot
		for _, h in ipairs(V3.HOUSES) do
			equal(h.turn or 0, h.asset == "CV3_CaramelTower" and 180 or 0, h.id .. " turn")
			local yaw = V3.houseYaw(h, Layout)
			local lx, lz = -math.sin(yaw), -math.cos(yaw) -- where the door (-Z) looks
			local toJunction = { x = Layout.JUNCTION.x - h.x, z = Layout.JUNCTION.z - h.z }
			local dot = lx * toJunction.x + lz * toJunction.z
			assert((h.turn == 180) == (dot < 0), h.id .. " faces the wrong way")
			local dx, dz = h.x + lx * (h.r + 4), h.z + lz * (h.r + 4)
			assert(Layout.depth(dx, dz) >= 5, h.id .. "'s door faces the plot edge")
			assert(V3.liquidDistance(dx, dz) >= 4, h.id .. "'s door faces the chocolate")
			for _, p in ipairs(V3.pieces()) do
				if not (p.kind == "house" and p.id == h.id) then
					assert(flat(dx, dz, p.x, p.z) - p.r >= 4, h.id .. "'s door faces " .. p.kind .. " " .. p.id)
				end
			end
		end
		-- V4-D12: the creatures' list of footprints
		local feet = V3.houseFootprints(Layout)
		equal(#feet, #V3.HOUSES, "a footprint per house")
		for i, f in ipairs(feet) do
			equal(f.id, V3.HOUSES[i].id, "id"); equal(f.r, V3.HOUSES[i].r, f.id .. " r"); equal(f.x, V3.HOUSES[i].x, f.id .. " x")
		end
	end)

	-- Deliberately changed (V4): the raft is steered (V4-D3), so there is no lane any more; each dock tip has 6 studs of
	-- chocolate round it and is 6 off every bridge; the docks stand on opposite banks (the line between their stands
	-- crosses the chocolate).
	case("V3-8: the docks stand on both banks with open chocolate at the tips", function()
		equal(#V3.DOCKS, 2, "two docks")
		local a, b = V3.DOCKS[1], V3.DOCKS[2]
		for _, d in ipairs(V3.DOCKS) do
			assert(V3.liquidDistance(d.standX, d.standZ) > 0, "stand " .. d.id .. " on land")
			assert(V3.liquidDistance(d.tipX, d.tipZ) <= -6, "tip " .. d.id .. " not in open chocolate")
			assert(not V3.nearBridge(d.tipX, d.tipZ, 6), "tip " .. d.id .. " by a bridge")
		end
		local wet = false
		for s = 1, 99 do
			local x, z = a.standX + (b.standX - a.standX) * s / 100, a.standZ + (b.standZ - a.standZ) * s / 100
			if V3.liquidDistance(x, z) < 0 then wet = true end
		end
		assert(wet, "the docks are on the same bank")
		equal(V3.RAFT.homeDock, 1, "home dock")
		equal(V3.RAFT.asset, "CV3_BananaRaft", "raft asset")
		assert(math.deg(math.atan2(V3.LIQUID.depth + V3.DOCK.deckOver, V3.DOCK.rampBack - 1.5)) <= 25, "dock ramps walkable")
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
			-- Deliberately changed (V4): off every bridge (deck, end ramps and side ramps)
			assert(not V3.nearBridge(pl.x, pl.z, pl.r), "platform " .. i .. " on a bridge")
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
		equal(V3.TREES.heightFactor, 1.35, "V4-D4: 35 % taller")
	end)

	case("V3-11: helpers", function()
		assert(math.abs(V3.faceYaw(0, 0, 0, -10)) < 1e-9, "looking north (-z) is yaw 0")
		local yaw = V3.faceYaw(0, 0, 10, 0)
		assert(math.abs(-math.sin(yaw) - 1) < 1e-9 and math.abs(-math.cos(yaw)) < 1e-9, "looking east")
		-- Deliberately changed (V4): over every bridge, along its own leg
		for _, B in ipairs(V3.BRIDGES) do
			assert(V3.onBridge(B.x, B.z, true), B.id .. ": the centre is on the deck")
			local px, pz = B.x + B.ux * (B.length / 2 + 1), B.z + B.uz * (B.length / 2 + 1)
			assert(not V3.onBridge(px, pz, true), B.id .. ": past the deck")
			assert(V3.onBridge(px, pz), B.id .. ": on a ramp")
		end
		local ok, why = V3.clearOfPieces(V3.POOL.x, V3.POOL.z, 1)
		assert(not ok and why == "in the chocolate", "the pool is not open ground")
		ok = V3.clearOfPieces(-150, 60, 3)
		assert(ok, "open ground in the west")
		equal(V3.surfaceY(0.5), 0.5 + V3.LIQUID.depth, "surface height")
	end)

	-- V3 review M3: the bridge is no wall across the lake.
	-- Deliberately changed (V4): every bridge; gaps are optional (the three by the junction have none).
	case("V3-12: the bridges' rail gaps open with side ramps, off every creature post", function()
		local any = false
		for _, B in ipairs(V3.BRIDGES) do
			assert(B.gapWidth >= 8, "gaps at least 8 studs")
			assert(math.deg(math.atan2(B.deck, B.sideRamp)) <= 25, "side ramps are walkable")
			for i, gx in ipairs(B.gaps) do
				any = true
				assert(math.abs(gx) + B.gapWidth / 2 <= B.length / 2, B.id .. " gap " .. i .. " past the deck")
				for j = i + 1, #B.gaps do
					assert(math.abs(gx - B.gaps[j]) >= B.gapWidth + 4, B.id .. " gaps run together")
				end
				-- V3-D25: every side ramp's footprint keeps pieceFromPost studs off every creature post
				for _, s in ipairs({ -1, 1 }) do
					local lo, hi = math.min(s * B.width / 2, s * (B.width / 2 + B.sideRamp)), math.max(s * B.width / 2, s * (B.width / 2 + B.sideRamp))
					for _, p in ipairs(posts()) do
						local along, across = V3.bridgeFrame(B, p.x, p.z)
						local da = math.max(math.abs(along - gx) - B.gapWidth / 2, 0)
						local dc = math.max(lo - across, 0, across - hi)
						assert(math.sqrt(da * da + dc * dc) >= C.pieceFromPost,
							("%s's side ramp at gap %d (side %d) is on post %s"):format(B.id, gx, s, p.id))
					end
				end
				local sx, sz = B.x + B.ux * gx - B.uz * (B.width / 2 + B.sideRamp - 0.5), B.z + B.uz * gx + B.ux * (B.width / 2 + B.sideRamp - 0.5)
				assert(V3.nearBridge(sx, sz, 0), B.id .. ": a side ramp is part of the bridge")
			end
		end
		assert(any, "some bridge opens for waders")
	end)

	-- V3 review M1 and m5.
	case("V3-13: the creature tags, and the docks as stand, ramp and deck", function()
		equal(V3.BEAST_PASS_TAG, "WildboundBeastPass", "pass tag")
		equal(V3.PLATFORM.over > 0, true, "V4-D2: the platforms' walk tops over the surface")
		equal(V3.BEAST_OVERHEAD_TAG, "WildboundBeastOverhead", "overhead tag")
		local docks = 0
		for _, p in ipairs(V3.pieces()) do if p.kind == "dock" then docks += 1 end end
		equal(docks, #V3.DOCKS * 3, "three discs per dock")
		for _, d in ipairs(V3.DOCKS) do
			local foot, mid, dir, deckEnd = V3.dockPoints(d)
			assert(V3.liquidDistance(foot.x, foot.z) > 0, d.id .. "'s ramp foot on land")
			assert(deckEnd > 0 and math.abs(dir.x ^ 2 + dir.z ^ 2 - 1) < 1e-9, d.id .. " deck")
			assert(flat(mid.x, mid.z, d.standX, d.standZ) < flat(d.tipX, d.tipZ, d.standX, d.standZ), d.id .. " deck middle")
		end
		assert(V3.DOCK.tipGap >= 4, "the docked hull has room")
	end)

	-- V4-D6: pink hills at the crystal spots, off everything
	case("V3-15: pink hills stand at the crystals' spots, off every nest, post, route, piece and the chocolate", function()
		equal(V3.CRYSTAL.asset, "RockSugar", "the yellow crystal"); equal(V3.CRYSTAL.folder, "SugarHills", "its folder")
		equal(#V3.CRYSTAL_HILLS, 6, "one per Hill_ spot")
		local B = Layout.BOSS
		for _, h in ipairs(V3.CRYSTAL_HILLS) do
			equal(h.x, 198, h.id .. " at the crystals' x")
			for _, spec in ipairs(Layout.NESTS) do assert(flat(h.x, h.z, spec.x, spec.z) - h.r >= C.pieceFromNest, h.id .. " on nest " .. spec.id) end
			for _, p in ipairs(posts()) do assert(flat(h.x, h.z, p.x, p.z) - h.r >= C.pieceFromPost, h.id .. " on post " .. p.id) end
			assert(Layout.routeDistance(h.x, h.z) - h.r - half >= C.pieceFromRoute, h.id .. " on a route")
			assert(flat(h.x, h.z, B.x, B.z) - h.r >= B.territoryRadius, h.id .. " in the boss territory")
			for _, spot in ipairs(Layout.KEEP_CLEAR) do assert(flat(h.x, h.z, spot.x, spot.z) - h.r - spot.r >= C.pieceApart, h.id .. " on " .. spot.why) end
			for _, p in ipairs(V3.pieces()) do assert(flat(h.x, h.z, p.x, p.z) - h.r - p.r >= C.pieceApart, h.id .. " on " .. p.kind .. " " .. p.id) end
			assert(V3.liquidDistance(h.x, h.z) - h.r >= C.pieceApart, h.id .. " in the chocolate")
		end
	end)

	-- V4-D7: the backdrop stands outside the plot's east side, the edge fill is a dense band
	case("V3-16: the backdrop is outside the east edge; the edge fill is dense and budgeted", function()
		assert(#V3.BACKDROP >= 6, "a backdrop")
		for i, b in ipairs(V3.BACKDROP) do
			assert(b.x > Layout.HALF, "backdrop " .. i .. " east of the plot")
			local dx, dz = math.max(math.abs(b.x) - Layout.HALF, 0), math.max(math.abs(b.z) - Layout.HALF, 0)
			assert(math.sqrt(dx * dx + dz * dz) >= b.r, "backdrop " .. i .. " reaches into the plot")
			assert(table.find(V3.ASSETS, b.asset), "backdrop " .. i .. " asset")
		end
		local E = V3.EDGE
		assert(E.bandMin < E.bandMax and E.bandMax >= 40, "the band")
		assert(E.spacing <= 16 and E.maxTrees + E.maxProps >= 80, "dense")
		assert(E.maxParts > 0 and V3.V4_PART_TARGET <= V3.BIOME_PART_CAP - 100, "budgets")
		for _, asset in ipairs(E.trees) do assert(table.find(V3.ASSETS, asset), asset) end
	end)

	-- V5-D3, V5-D10 to V5-D13 (the clearances themselves are V3-4, V3-5, V3-6, V3-8 and V3-9, unchanged)
	case("V3-17: v5: a 24-wide river on its open legs, the junction arc 10, a bigger lake, longer Top and Bottom bridges", function()
		local wide, wideLength = 0, 0
		for i, p in ipairs(V3.RIVER) do
			if p[3] >= 24 then wide += 1 end
			if flat(p[1], p[2], Layout.JUNCTION.x, Layout.JUNCTION.z) <= 31 then equal(p[3], 10, "junction arc point " .. i) end
			local q = V3.RIVER[i + 1]
			if q and math.min(p[3], q[3]) >= 24 then wideLength += flat(p[1], p[2], q[1], q[2]) end
		end
		assert(wide >= 10, "24-wide points: " .. wide)
		assert(wideLength >= 180, "24-wide legs: " .. wideLength)
		equal(#V3.LAKE, 2, "two lake discs")
		assert(V3.LAKE[1].r >= 34 and V3.LAKE[2].r >= 18, "the lake grew")
		local open = 0
		for x = -60, 79 do
			for z = -150, -21 do
				if V3.liquidDistance(x + 0.5, z + 0.5) <= -3 and not V3.nearBridge(x + 0.5, z + 0.5, 3) then open += 1 end
			end
		end
		-- Deliberately changed (V6-D4): the island takes about 280 square studs of the hull's water (3692 -> 3416)
		assert(open >= 3350, "open water for the raft's hull: " .. open)
		local byId = {}
		for _, B in ipairs(V3.BRIDGES) do byId[B.id] = B end
		assert(byId.Top.length >= 28 and byId.Bottom.length >= 28, "the long bridges grew")
		for _, id in ipairs({ "RightLast", "Main", "LeftLast" }) do equal(byId[id].length, 11, id .. " stays short") end
		for _, id in ipairs({ "Top", "Bottom" }) do
			local B = byId[id]
			for s = -math.floor(B.length / 2) - 9, math.floor(B.length / 2) + 9 do
				if V3.liquidDistance(B.x + B.ux * s, B.z + B.uz * s) <= 1 then
					assert(math.abs(s) <= B.length / 2, id .. ": chocolate past the deck at " .. s)
				end
			end
		end
		local a, b = V3.DOCKS[1], V3.DOCKS[2]
		assert(a.standX < 0 and b.standX > 0, "dock A west, dock B east")
		assert(flat(a.tipX, a.tipZ, b.tipX, b.tipZ) >= 50, "the docks face each other across open water")
	end)

	return result
end
