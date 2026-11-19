-- Invoke with require(freshTestClone)(require(freshCandyV3LayoutClone), require(freshCandyLayoutClone),
--   require(freshPraderaSitesClone), require(freshCandyTrapCakeClone), require(freshCandyV3KitSpecClone)).
-- Caramelo v3 (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md): the pure layout rules of the new
-- pieces over layout VERSION 3. Caramelo v4 (V4-D1 to V4-D17): the river runs from M1's waterfall pool by the north
-- edge through the lake to the south edge, a barrier west of the cake; the routes meet the chocolate only on a bridge, nests, creature posts, trap cakes, the boss ground, the portal, the entrance and the stair stay clear,
-- the houses, mountains, docks, licorice and cake keep their distances, and the raft's lane floats between two banks.
-- No services and no instances; tools/test_caramelo_v3.py checks the same geometry outside Studio.
-- Caramelo v9 (docs/design/wildbound-caramelo-v9-plan.md, CL-D1..CL-D18): one long west-to-east river from M1's
-- waterfall in the south-west corner to the east edge, three raised bridges the raft passes under, four docks. The
-- optional fifth argument is require(freshCandyV3KitSpecClone): with it, V3-1 also pins M1_KIT to the kit spec.
return function(V3, Layout, Sites, Trap, KitSpec)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-6),
			label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	-- The river's mountain (M1, the source).
	local function riverMountain()
		for _, m in ipairs(V3.MOUNTAINS) do if m.river then return m end end
		error("no river mountain")
	end

	-- CL-D5 (Caramelo v9): the plot's 2-stud cells (centres at -HALF + 1 + 2i, -HALF + 1 + 2j, x up to EAST) with the
	-- liquid at each centre, computed once and shared by the barrier (V3-14, V3-21), the raft's reach (V3-22) and the
	-- open water (V3-17). The centres stay 1 stud inside the plot, so the plot clip never makes a dry edge column.
	local gridMemo = nil
	local function grid()
		if gridMemo then return gridMemo end
		local W, H = -Layout.HALF, Layout.HALF
		local nx, nz = math.floor((Layout.EAST - W) / 2), math.floor(2 * H / 2)
		local liquid = table.create(nx * nz, 0)
		for i = 0, nx - 1 do
			local x = W + 1 + 2 * i
			for j = 0, nz - 1 do
				liquid[i * nz + j + 1] = V3.liquidDistance(x, -H + 1 + 2 * j)
			end
		end
		local g = { nx = nx, nz = nz, liquid = liquid }
		function g.x(k) return W + 1 + 2 * ((k - 1) // nz) end
		function g.z(k) return -H + 1 + 2 * ((k - 1) % nz) end
		-- the cell holding (x, z), as its index
		function g.at(x, z)
			local i = math.clamp(math.round((x - W - 1) / 2), 0, nx - 1)
			local j = math.clamp(math.round((z + H - 1) / 2), 0, nz - 1)
			return i * nz + j + 1
		end
		gridMemo = g
		return g
	end
	-- A 4-neighbour flood fill over the grid from cell `start` through the cells open(k) accepts: seen[k], count.
	local function flood(g, start, open)
		local seen, queue, head, count = {}, {}, 1, 0
		local function push(i, j)
			if i < 0 or j < 0 or i >= g.nx or j >= g.nz then return end
			local k = i * g.nz + j + 1
			if seen[k] or not open(k) then return end
			seen[k] = true
			count += 1
			queue[count] = k
		end
		push((start - 1) // g.nz, (start - 1) % g.nz)
		while head <= count do
			local k = queue[head]
			head += 1
			local i, j = (k - 1) // g.nz, (k - 1) % g.nz
			push(i + 1, j); push(i - 1, j); push(i, j + 1); push(i, j - 1)
		end
		return seen, count
	end
	-- CL-D5: the walkers' banks. A cell is dry when its liquid is >= 0 and M1 (the source) does not stand on it; the
	-- bridges are ignored. entrance = the cells reached dry from the entrance, cake = those reached dry from the Torta.
	local barrierMemo = nil
	local function barrier()
		if barrierMemo then return barrierMemo end
		local g, m1 = grid(), riverMountain()
		local dry = table.create(g.nx * g.nz, false)
		for k = 1, g.nx * g.nz do
			dry[k] = g.liquid[k] >= 0 and flat(g.x(k), g.z(k), m1.x, m1.z) > m1.r
		end
		local function open(k) return dry[k] end
		local entrance, count = flood(g, g.at(Layout.ENTRANCE.x, Layout.ENTRANCE.z), open)
		local cake = flood(g, g.at(Layout.TORTA.x, Layout.TORTA.z), open)
		barrierMemo = { entrance = entrance, cake = cake, count = count }
		return barrierMemo
	end
	local function bankOf(x, z)
		local b, k = barrier(), grid().at(x, z)
		if b.entrance[k] then return "entrance" elseif b.cake[k] then return "cake" end
		return "none"
	end

	case("V3-1: the data is versioned, frozen and names its kit", function()
		-- Deliberately changed (V4): VERSION 1 -> 2, and the v4 mark
		-- Deliberately changed (V5): VERSION 2 -> 3, and the v5 mark
		-- Deliberately changed (V8-D1): VERSION 3 -> 4 (the plot 1.3 times bigger), so the older migrations refuse to run
		-- Deliberately changed (CL-D2): VERSION 4 -> 5 (the plot grows east, the river is new), so the v3..v8 tools refuse
		equal(V3.VERSION, 5, "VERSION")
		equal(V3.V8.S, Layout.V8.S, "V8-D1: the same scale as the layout")
		equal(V3.V8.HALF, Layout.HALF, "V8-D1: the same plot as the layout")
		equal(V3.V8.OLD_HALF, Layout.V8.OLD_HALF, "V8-D1: the same v7 plot")
		equal(V3.V9.EAST, Layout.EAST, "CL-D2: the same east edge as the layout")
		equal(V3.V9_MARK, "CaramelV9", "CL-D2: v9 mark")
		-- CL-D4: M1's kit offsets are data, copied from WildboundCandyV3KitSpec (X, Z of the kit's water points)
		local K = V3.M1_KIT
		assert(table.isfrozen(K), "M1_KIT frozen")
		equal(K.outlet[1], 0.5653, "outlet X"); equal(K.outlet[2], -49.6671, "outlet Z")
		equal(K.pool[1], 0.5653, "pool X"); equal(K.pool[2], -37.6671, "pool Z"); equal(K.poolRadius, 11, "pool radius")
		equal(K.fall[1], 0.5653, "fall X"); equal(K.fall[2], -31.0, "fall Z")
		if KitSpec ~= nil then
			local water = KitSpec.CV3_IceCreamMountain_L.water
			equal(K.outlet[1], water.outlet[1], "KitSpec outlet X"); equal(K.outlet[2], water.outlet[3], "KitSpec outlet Z")
			equal(K.pool[1], water.poolCentre[1], "KitSpec pool X"); equal(K.pool[2], water.poolCentre[3], "KitSpec pool Z")
			equal(K.poolRadius, water.poolRadius, "KitSpec pool radius")
		end
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
	-- Deliberately changed again (CL-D3, CL-D4, owner request 2026-11-18 "el rio necesito qeu sea 5 veces su ancho ... que
	-- llegue al final"): from M1's outlet in the south-west corner along the -z edge, north up the reach at x 470 and
	-- along the +z edge to the east edge; at least 50 wide but at the outlet, 100+ in the east, 1300+ long.
	case("V3-2: a big river from the waterfall pool's outlet in the south-west corner to the east edge, 3.5 deep", function()
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
		-- CL-D3: the mouth lies on the east edge, under the cloud wall
		assert(math.abs(Layout.depth(last[1], last[2])) < 0.01 and last[1] > 0, "the river ends on the east edge")
		equal(last[1], Layout.EAST, "the mouth's x")
		-- CL-D4: M1 closes the south-west corner (it may overhang both edges by 0.5)
		local m1 = riverMountain()
		assert(m1.x < 0 and m1.z < 0, "M1 stands in the south-west corner")
		assert(m1.x - m1.r <= -Layout.HALF + 0.5 and m1.z - m1.r <= -Layout.HALF + 0.5, "M1 touches both edges")
		assert(Layout.depth(m1.x, m1.z) >= m1.r - 0.5, "M1 leaves the plot")
		assert(V3.riverLength() >= 1300, "a short river: " .. V3.riverLength())
		local widest = 0
		for i, p in ipairs(V3.RIVER) do
			assert(i == 1 or p[3] >= 50, "point " .. i .. " is narrower than 50")
			widest = math.max(widest, p[3])
			assert(i == #V3.RIVER or Layout.depth(p[1], p[2]) - p[3] / 2 >= 2, "point " .. i .. " leaves the plot")
		end
		assert(widest >= 100, "a wide stretch for the raft: " .. widest)
		assert(V3.liquidDistance(V3.POOL.x, V3.POOL.z) < 0 and V3.liquidDistance(V3.LAKE[1].x, V3.LAKE[1].z) < 0, "pool and lake are chocolate")
		equal(V3.LIQUID.depth, 3.5, "V4-D2: 3.5 deep")
		local samples = V3.riverSamples(2)
		assert(#samples > 100, "samples")
		-- Deliberately changed (V6-D4): the lake's island stands in the river's mouth; its centreline meets the island's
		-- dry land and leaves it again, so a sample on an island is not a gap
		-- CL-D3: the plot clip makes the edge itself dry, so only samples more than 0.5 inside the plot must be wet
		for _, s in ipairs(samples) do
			if Layout.depth(s.x, s.z) > 0.5 then
				assert(V3.liquidDistance(s.x, s.z) < 0 or V3.islandAt(s.x, s.z), ("a gap in the river at %.1f, %.1f"):format(s.x, s.z))
			end
		end
	end)

	-- V4-D1: no dry walk round the river: every west-to-east line meets the chocolate west of the cake's territory (or
	-- M1, the source, standing on the north edge).
	-- Deliberately changed (CL-D5): the river now runs along the plot, so the rule is a flood fill. On the plot's 2-stud
	-- cells with liquid >= 0 (M1's footprint solid, the bridges ignored), the walker from the entrance never reaches the
	-- Torta: the only dry links between the banks are the three bridges.
	case("V3-14: the river is a barrier between the entrance and the Torta (flood fill)", function()
		local b = barrier()
		local g = grid()
		assert(g.liquid[g.at(Layout.ENTRANCE.x, Layout.ENTRANCE.z)] >= 0, "the entrance is dry")
		assert(b.count >= 50000, "the entrance bank is the big west part: " .. b.count .. " cells")
		assert(not b.entrance[g.at(Layout.TORTA.x, Layout.TORTA.z)], "the Torta is reached dry from the entrance")
		assert(b.cake[g.at(Layout.TORTA.x, Layout.TORTA.z)], "the Torta stands on dry ground")
	end)

	case("V3-3: the waterfall falls from the big mountain into the pool", function()
		local W, m1 = V3.WATERFALL, riverMountain()
		assert(m1 and m1.asset == "CV3_IceCreamMountain_L", "the river's mountain is the big one")
		equal(m1.faceX, V3.RIVER[2][1], "its outlet faces the river x"); equal(m1.faceZ, V3.RIVER[2][2], "z")
		assert(flat(W.x, W.z, m1.x, m1.z) < m1.r, "the sheet stands on the mountain")
		assert(flat(W.x, W.z, V3.POOL.x, V3.POOL.z) < V3.POOL.r, "it falls into the pool")
		equal(W.faceX, V3.POOL.x, "faces the pool x"); equal(W.faceZ, V3.POOL.z, "faces the pool z")
		assert(W.top >= 15 and W.top < m1.height, "under the mountain's top")
		assert(W.streaks >= 3 and W.flowSpeed > 0, "it flows")
		-- Deliberately changed (CL-D4): M1 at 0.75 (was 0.45); the waterfall's numbers follow the kit via kitPoint
		equal(m1.scale, 0.75, "M1's scale")
		near(m1.r, 54 * m1.scale, "M1's footprint"); near(m1.height, 67.82, "M1's height", 0.01)
		near(W.top, 33.72 * m1.scale, "the kit ledge x scale"); near(W.width, 7 / 0.45 * m1.scale, "the sheet width")
		near(V3.POOL.r, V3.M1_KIT.poolRadius * m1.scale, "the pool radius")
		near(V3.RIVER[1][3], 12 / 0.45 * m1.scale, "the outlet width", 1e-9)
		local yaw = V3.faceYaw(m1.x, m1.z, m1.faceX, m1.faceZ)
		local fx, fz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, V3.M1_KIT.fall[1], V3.M1_KIT.fall[2])
		near(W.x, fx, "the fall x"); near(W.z, fz, "the fall z")
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
		-- CL-D7: one raised deck on every route leg the chocolate meets
		for _, name in ipairs(Layout.ROUTE_ORDER) do
			local route = Layout.ROUTES[name]
			for i = 1, #route - 1 do
				local a, b = route[i], route[i + 1]
				local wet = false
				local steps = math.max(1, math.ceil(flat(a.x, a.z, b.x, b.z) / 2))
				for s = 0, steps do
					if V3.liquidDistance(a.x + (b.x - a.x) * s / steps, a.z + (b.z - a.z) * s / steps) <= 0 then wet = true end
				end
				if wet then
					local decks = 0
					for _, B in ipairs(V3.BRIDGES) do
						if B.route == name and a.x == B.from[1] and a.z == B.from[2] and b.x == B.to[1] and b.z == B.to[2] then decks += 1 end
					end
					equal(decks, 1, name .. " leg " .. i .. ": raised decks")
				end
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
		-- Deliberately changed (CL-D6, CL-D7): the v9 river crosses the main avenue and the far routes south and north at
		-- the reach (x 470); the left and right routes stay on the entrance bank
		assert(crossed.main and crossed.north and crossed.south, "the main avenue, the north and the south route are bridged")
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

	-- Deliberately changed (CL-D12): 5..7 -> 5..10 houses (H8-H10 are new on the grown east)
	case("V3-7: five to ten houses of the three kinds, in every quarter of the plot", function()
		assert(#V3.HOUSES >= 5 and #V3.HOUSES <= 10, "houses " .. #V3.HOUSES)
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
	-- Deliberately changed (CL-D8): more than two docks (4), on both banks (V3-21 names the banks), tips at least 50
	-- apart; the home dock is any valid index
	case("V3-8: the docks stand on both banks with open chocolate at the tips", function()
		assert(#V3.DOCKS >= 3, "CL-D8: at least three docks: " .. #V3.DOCKS)
		for i, d in ipairs(V3.DOCKS) do
			assert(table.isfrozen(d), d.id .. " frozen")
			assert(V3.liquidDistance(d.standX, d.standZ) > 0, "stand " .. d.id .. " on land")
			assert(V3.liquidDistance(d.tipX, d.tipZ) <= -6, "tip " .. d.id .. " not in open chocolate")
			assert(not V3.nearBridge(d.tipX, d.tipZ, 6), "tip " .. d.id .. " by a bridge")
			for j = i + 1, #V3.DOCKS do
				local e = V3.DOCKS[j]
				assert(flat(d.tipX, d.tipZ, e.tipX, e.tipZ) >= 50, "tips " .. d.id .. " and " .. e.id .. " are closer than 50")
			end
		end
		local wet = false
		for i, a in ipairs(V3.DOCKS) do
			for j = i + 1, #V3.DOCKS do
				local b = V3.DOCKS[j]
				for s = 1, 99 do
					local x, z = a.standX + (b.standX - a.standX) * s / 100, a.standZ + (b.standZ - a.standZ) * s / 100
					if V3.liquidDistance(x, z) < 0 then wet = true end
				end
			end
		end
		assert(wet, "the docks are all on the same bank")
		local home = V3.RAFT.homeDock
		assert(type(home) == "number" and home == math.floor(home) and V3.DOCKS[home] ~= nil, "home dock " .. tostring(home))
		equal(home, 1, "home dock A")
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
			-- Deliberately changed (CL-D3): in discs 1 and 2, the lake proper (3..5 are the dock basins)
			for d = 1, 2 do
				local disc = V3.LAKE[d]
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
	-- Deliberately changed (CL-D7): the raised v9 bridges have no rail gaps (a side ramp down from a 12.5-stud deck would
	-- fill the reach the raft sails); the gap rules stay for any gap a later bridge gets.
	case("V3-12: no bridge has rail gaps; a side ramp would be walkable and off every creature post", function()
		for _, B in ipairs(V3.BRIDGES) do
			equal(#B.gaps, 0, B.id .. ": CL-D7 rail gaps")
			assert(B.gapWidth >= 8, "gaps at least 8 studs")
			assert(math.deg(math.atan2(B.deck, B.sideRamp)) <= 25, "side ramps are walkable")
			for i, gx in ipairs(B.gaps) do
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
	end)

	-- V3 review M1 and m5.
	case("V3-13: the creature tags, and the docks as stand, ramp and deck", function()
		equal(V3.BEAST_PASS_TAG, "WildboundBeastPass", "pass tag")
		equal(V3.PLATFORM.over > 0, true, "V4-D2: the platforms' walk tops over the surface")
		equal(V3.BEAST_OVERHEAD_TAG, "WildboundBeastOverhead", "overhead tag")
		local docks = 0
		for _, p in ipairs(V3.pieces()) do if p.kind == "dock" then docks += 1 end end
		-- Deliberately changed (CL-D8): four docks (A, B on the entrance bank, C, D on the cake bank)
		equal(#V3.DOCKS, 4, "CL-D8: four docks")
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
			-- Deliberately changed (V8-D1): x 198 -> HALF - 2 (258), re-anchored to the edge like the v7 crystals
			-- Deliberately changed again (CL-D12): the east edge is EAST now, so x = EAST - 2 (858), straddling it
			equal(h.x, Layout.EAST - 2, h.id .. " at the crystals' x, 2 inside the edge")
			assert(h.x - h.r < Layout.EAST and h.x + h.r > Layout.EAST, h.id .. " straddles the east edge")
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
		-- Deliberately changed (V8-D2, fixer): the v8 backdrop is empty (was at least 6 pieces): east of the bigger plot
		-- lie the cloud band and Caramelo Este, where every v7 piece, re-anchored to the east edge, would stand. The v7
		-- rows are kept as a record (V3.BACKDROP_V7) and still hold their v7 rules
		equal(#V3.BACKDROP, 0, "no backdrop in v8")
		assert(#V3.BACKDROP_V7 >= 6, "the v7 record")
		-- Deliberately changed (CL-D13): the east edge is EAST; past it lie the cloud band (16) and the arm's 64-stud tail,
		-- where every v7 piece, re-anchored to the east edge, would stand
		for i, b in ipairs(V3.BACKDROP_V7) do
			local x = Layout.EAST + (b.x - Layout.V8.OLD_HALF)
			assert(x - b.r < Layout.EAST + 16 + 64, "v7 backdrop " .. i .. " would stand in the band or the arm's tail")
			assert(b.x > Layout.V8.OLD_HALF and table.find(V3.ASSETS, b.asset), "v7 backdrop " .. i)
		end
		for i, b in ipairs(V3.BACKDROP) do
			assert(b.x > Layout.EAST, "backdrop " .. i .. " east of the plot")
			local dx = math.max(b.x - Layout.EAST, -Layout.HALF - b.x, 0)
			local dz = math.max(math.abs(b.z) - Layout.HALF, 0)
			assert(math.sqrt(dx * dx + dz * dz) >= b.r, "backdrop " .. i .. " reaches into the plot")
			assert(table.find(V3.ASSETS, b.asset), "backdrop " .. i .. " asset")
		end
		local E = V3.EDGE
		assert(E.bandMin < E.bandMax and E.bandMax >= 40, "the band")
		assert(E.spacing <= 16 and E.maxTrees + E.maxProps >= 80, "dense")
		assert(E.maxParts > 0 and V3.V4_PART_TARGET <= V3.BIOME_PART_CAP - 100, "budgets")
		for _, asset in ipairs(E.trees) do assert(table.find(V3.ASSETS, asset), asset) end
		-- Deliberately changed (CL-D16): the v9 budget: cap 2800 -> 3400, the v9 real run refuses above 3100, the v3
		-- batch may add 1300 -> 1600; the edge fill keeps its 600
		equal(V3.BIOME_PART_CAP, 3400, "CL-D16: cap")
		equal(V3.V9_PART_TARGET, 3100, "CL-D16: v9 target")
		equal(V3.MAX_NEW_PARTS, 1600, "CL-D16: new parts")
		equal(E.maxParts, 600, "CL-D16: the edge fill's budget")
		assert(V3.V9_PART_TARGET <= V3.BIOME_PART_CAP - 100, "the v9 target leaves room under the cap")
	end)

	-- V5-D3, V5-D10 to V5-D13 (the clearances themselves are V3-4, V3-5, V3-6, V3-8 and V3-9, unchanged)
	-- Deliberately changed (CL-D3, owner request 2026-11-18 "5 veces su ancho"): the v5 widths (24, the junction arc 10)
	-- become the v9 ones: the west channel 50..64 (held by the left route), the reach 60, the east 90..120 (5 x 24); five
	-- lake discs (the harbour lake, its west lobe, three dock basins); three 68-stud decks; the hull's open water counted
	-- over the whole plot on the 2-stud cells (x 4 square studs; the C# port counts 102,390 one-stud cells).
	case("V3-17: v9: the river's widths, five lake discs, 68-stud decks, open water for the hull", function()
		equal(#V3.RIVER, 16, "river points")
		local widths = { [2] = 50, [3] = 64, [4] = 64, [5] = 64, [6] = 64, [7] = 64, [8] = 60, [9] = 60, [10] = 60, [11] = 60,
			[12] = 90, [13] = 110, [14] = 120, [15] = 120, [16] = 120 }
		for i, w in pairs(widths) do equal(V3.RIVER[i][3], w, "width of point " .. i) end
		equal(#V3.LAKE, 5, "five lake discs")
		for i, r in ipairs({ 52, 34, 22, 24, 32 }) do equal(V3.LAKE[i].r, r, "disc " .. i .. " radius") end
		equal(#V3.BRIDGES, 3, "three bridges")
		for _, B in ipairs(V3.BRIDGES) do equal(B.length, 68, B.id .. " deck") end
		local g, open = grid(), 0
		for k = 1, g.nx * g.nz do
			if g.liquid[k] <= -3 and not V3.nearBridge(g.x(k), g.z(k), 3) then open += 1 end
		end
		assert(open * 4 >= 90000, "open water for the raft's hull: " .. open * 4)
	end)

	-- V8-D1 (owner request 2026-11-17, "more space between things"; docs/design/wildbound-caramelo-v8-plan.md): the v7
	-- positions scale 1.3 about the centre and the sizes stay; the exceptions keep their v7 relation to their parent.
	-- Deliberately changed (CL-D3, CL-D4, CL-D7, CL-D8, Caramelo v9): the v8 pins of the river, M1, the lake, the bridges
	-- and the docks become the v9 pins; the kept west pieces (H1, the licorice, the cake) keep their v8 spots.
	case("V3-18: v9 pins: M1 and its water, the river's ends and reach, the lake, the bridges, the docks; the west kept", function()
		local S = Layout.V8.S
		local m1 = V3.MOUNTAINS[1]
		equal(m1.id, "M1", "M1 first")
		equal(m1.x, -219.8, "M1 x"); equal(m1.z, -219.8, "M1 z"); near(m1.r, 40.5, "M1 footprint")
		equal(m1.faceX, -150, "M1 faces RIVER[2], x"); equal(m1.faceZ, -224, "z")
		near(V3.RIVER[1][1], -182.59, "the outlet x", 0.01); near(V3.RIVER[1][2], -221.61, "the outlet z", 0.01)
		near(V3.RIVER[1][3], 20, "the outlet width", 1e-9)
		near(V3.POOL.x, -191.58, "the pool x", 0.01); near(V3.POOL.z, -221.07, "the pool z", 0.01); near(V3.POOL.r, 8.25, "the pool r")
		near(V3.WATERFALL.x, -196.57, "the fall x", 0.01); near(V3.WATERFALL.z, -220.77, "the fall z", 0.01)
		near(V3.WATERFALL.width, 11.67, "the sheet width", 0.01); near(V3.WATERFALL.top, 25.29, "the sheet top", 0.01)
		for _, row in ipairs({ { 2, -150, -224, 50 }, { 10, 470, -175, 60 }, { 11, 470, 175, 60 }, { 16, 860, 195, 120 } }) do
			local p = V3.RIVER[row[1]]
			equal(p[1], row[2], "RIVER[" .. row[1] .. "] x"); equal(p[2], row[3], "z"); equal(p[3], row[4], "w")
		end
		near(V3.riverLength(), 1412.2, "the river's length", 0.1)
		for i, row in ipairs({ { 670, 170, 52 }, { 580, 172, 34 }, { -150, -222, 22 }, { 240, -222, 24 }, { 815, 170, 32 } }) do
			local d = V3.LAKE[i]
			equal(d.x, row[1], "disc " .. i .. " x"); equal(d.z, row[2], "disc " .. i .. " z"); equal(d.r, row[3], "disc " .. i .. " r")
		end
		local byId = {}
		for _, B in ipairs(V3.BRIDGES) do byId[B.id] = B end
		for id, row in pairs({ Top = { "north", 470, 125 }, Main = { "main", 470, 0 }, Bottom = { "south", 470, -125 } }) do
			local B = byId[id]
			assert(B, id .. " is missing")
			equal(B.route, row[1], id .. " route"); near(B.x, row[2], id .. " centre x"); near(B.z, row[3], id .. " centre z")
		end
		equal(byId.RightLast, nil, "CL-D7: RightLast is retired"); equal(byId.LeftLast, nil, "CL-D7: LeftLast is retired")
		near(byId.Main.to[1], Layout.TORTA.x - Layout.BOSS.plazaRadius, "Main's leg ends where the avenue does")
		for i, row in ipairs({ { "A", -150, -187, -150, -210 }, { "B", 240, -186, 240, -208 }, { "C", 670, 104, 670, 128 },
			{ "D", 815, 124, 815, 148 } }) do
			local d = V3.DOCKS[i]
			equal(d.id, row[1], "dock " .. i)
			equal(d.standX, row[2], d.id .. " standX"); equal(d.standZ, row[3], d.id .. " standZ")
			equal(d.tipX, row[4], d.id .. " tipX"); equal(d.tipZ, row[5], d.id .. " tipZ")
		end
		equal(V3.RAFT.clearance, 8, "CL-D8: the raft's clearance")
		equal(V3.ISLANDS[1].x, 690, "the island x"); equal(V3.ISLANDS[1].z, 150, "the island z"); equal(V3.ISLANDS[1].r, 6, "the island r")
		near(V3.HOUSES[1].x, -148 * S, "H1 x"); near(V3.HOUSES[1].z, 166 * S, "H1 z"); equal(V3.HOUSES[1].r, 28, "H1 footprint kept")
		near(V3.LICORICE.x, -124 * S, "the arch"); near(V3.CAKE.z, 112 * S, "the cake"); equal(V3.CAKE.r, 18, "the cake's size kept")
		for _, h in ipairs(V3.CRYSTAL_HILLS) do
			assert(h.x - h.r < Layout.EAST and h.x + h.r > Layout.EAST, h.id .. " straddles the east edge")
		end
		-- Deliberately changed (V8-D2, fixer): no v8 backdrop to re-anchor (V3-16); the v7 record and the empty list are frozen
		equal(#V3.BACKDROP, 0, "no backdrop in v8")
		assert(table.isfrozen(V3.V8) and table.isfrozen(V3.V9) and table.isfrozen(V3.RIVER[1]) and table.isfrozen(V3.DOCKS[1])
			and table.isfrozen(V3.BRIDGES[1].from) and table.isfrozen(V3.BACKDROP) and table.isfrozen(V3.BACKDROP_V7[1])
			and table.isfrozen(V3.M1_V8) and table.isfrozen(V3.BRIDGE_BUILD.pier), "frozen")
	end)

	-- CL-D7 (Caramelo v9): the three bridges stand high enough for the raft to sail under them.
	case("V3-19: raised bridges: the raft passes under, ramps <= 25 degrees, no gaps, the wet span under the deck, dry ends and piers", function()
		local P = V3.BRIDGE_BUILD.pier
		assert(type(P) == "table" and P.size > 0 and P.inset >= P.size / 2, "the piers' build")
		for _, B in ipairs(V3.BRIDGES) do
			local under = B.deck - 0.4 - V3.LIQUID.depth
			assert(under >= V3.RAFT.clearance, ("%s: the deck's underside is %.2f over the chocolate"):format(B.id, under))
			assert(math.deg(math.atan2(B.deck, B.ramp)) <= 25, B.id .. ": end ramps walkable")
			equal(#B.gaps, 0, B.id .. " gaps")
			for s = -math.floor(B.length / 2) - 9, math.floor(B.length / 2) + 9 do
				if V3.liquidDistance(B.x + B.ux * s, B.z + B.uz * s) <= 1 then
					assert(math.abs(s) <= B.length / 2, B.id .. ": chocolate past the deck at " .. s)
				end
			end
			for _, s in ipairs({ -1, 1 }) do
				local along = s * B.length / 2
				assert(V3.liquidDistance(B.x + B.ux * along, B.z + B.uz * along) > 0, B.id .. ": a deck end stands in the chocolate")
			end
			-- the four piers under the deck's corners, their footprints on dry land
			for _, sa in ipairs({ -1, 1 }) do
				for _, sc in ipairs({ -1, 1 }) do
					local along, across = sa * (B.length / 2 - P.inset), sc * (B.width / 2 - P.inset)
					assert(math.abs(along) + P.size / 2 <= B.length / 2 and math.abs(across) + P.size / 2 <= B.width / 2,
						B.id .. ": a pier sticks out of the deck")
					for _, da in ipairs({ -1, 1 }) do
						for _, dc in ipairs({ -1, 1 }) do
							local a, c = along + da * P.size / 2, across + dc * P.size / 2
							local x, z = B.x + B.ux * a - B.uz * c, B.z + B.uz * a + B.ux * c
							assert(V3.liquidDistance(x, z) >= 0.5, ("%s: a pier stands in the chocolate at %.1f, %.1f"):format(B.id, x, z))
						end
					end
				end
			end
		end
	end)

	-- CL-D8: the raft's bridge rule and the plot clip.
	case("V3-20: raftBlocks: the raised bridges never block the raft, a low one does; outside the plot nothing is chocolate", function()
		for _, B in ipairs(V3.BRIDGES) do
			equal(V3.raftBlocks(B.x, B.z, 3), false, B.id .. " blocks the raft")
			equal(V3.raftBlocks(B.x + B.ux * B.length / 2, B.z + B.uz * B.length / 2, 3), false, B.id .. "'s deck end blocks the raft")
		end
		local low = { { id = "Low", route = "fake", x = 0, z = 0, ux = 1, uz = 0, width = 15, length = 11, ramp = 9, deck = 4.1,
			gapWidth = 8, sideRamp = 9, gaps = {} } }
		equal(V3.raftBlocks(0, 0, 3, low), true, "a v8-height bridge blocks the raft")
		equal(V3.raftBlocks(5.5 + 9 + 2, 0, 3, low), true, "its ramp plus the hull's reach blocks too")
		equal(V3.raftBlocks(0, 40, 3, low), false, "away from the low bridge")
		-- the plot clip (CL-D3): the mouth stops at the east edge; the raft stops 3 inside it
		for _, p in ipairs({ { Layout.EAST + 0.5, 195 }, { Layout.EAST + 10, 150 }, { Layout.EAST + 30, 195 }, { Layout.EAST + 30, 240 } }) do
			assert(V3.liquidDistance(p[1], p[2]) >= 0, ("chocolate outside the plot at %.1f, %.1f"):format(p[1], p[2]))
		end
		near(V3.liquidDistance(Layout.EAST - 3, 195), -3, "the hull's last spot, 3 inside the east edge")
		for _, p in ipairs({ { 0, 0 }, { -260, 0 }, { 860, 0 }, { 800, 0 }, { 300, 250 }, { 39, -195 }, { 900, 0 }, { 0, -300 } }) do
			near(V3.plotDepth(p[1], p[2]), Layout.depth(p[1], p[2]), ("plotDepth(%g, %g)"):format(p[1], p[2]))
		end
	end)

	-- CL-D5: the banks the river makes.
	case("V3-21: the barrier's banks: docks A and B on the entrance bank, C and D on the cake bank; the bridges are the only dry links", function()
		local want = { A = "entrance", B = "entrance", C = "cake", D = "cake" }
		for _, d in ipairs(V3.DOCKS) do
			equal(bankOf(d.standX, d.standZ), want[d.id], "dock " .. d.id .. "'s stand")
		end
		local byId = {}
		for _, nest in ipairs(Layout.NESTS) do byId[nest.id] = nest end
		for _, id in ipairs({ "C14", "C15", "R12", "R13", "R14", "R15" }) do
			equal(bankOf(byId[id].x, byId[id].z), "entrance", "nest " .. id)
		end
		for _, id in ipairs({ "E4", "E5", "E6", "C16", "C17", "C18", "C19", "R16", "R17", "R18", "R19" }) do
			equal(bankOf(byId[id].x, byId[id].z), "cake", "nest " .. id)
		end
		-- with the decks and ramps walkable, the Torta is reached from the entrance
		local g, m1 = grid(), riverMountain()
		local function open(k)
			local x, z = g.x(k), g.z(k)
			if flat(x, z, m1.x, m1.z) <= m1.r then return false end
			return g.liquid[k] >= 0 or V3.onBridge(x, z) ~= nil
		end
		local seen = flood(g, g.at(Layout.ENTRANCE.x, Layout.ENTRANCE.z), open)
		assert(seen[g.at(Layout.TORTA.x, Layout.TORTA.z)], "the bridges do not link the banks")
	end)

	-- CL-D8: the raft sails the whole river.
	case("V3-22: from dock 1's tip the raft reaches every hull cell, every tip, the pool and the east edge", function()
		local g = grid()
		local hull, total = table.create(g.nx * g.nz, false), 0
		for k = 1, g.nx * g.nz do
			if g.liquid[k] <= -3 and not V3.raftBlocks(g.x(k), g.z(k), 3) then
				hull[k] = true
				total += 1
			end
		end
		local home = V3.DOCKS[V3.RAFT.homeDock]
		local start = g.at(home.tipX, home.tipZ)
		assert(hull[start], "dock " .. home.id .. "'s tip is not open water")
		local seen, count = flood(g, start, function(k) return hull[k] end)
		equal(count, total, "hull cells reached")
		for _, d in ipairs(V3.DOCKS) do
			assert(seen[g.at(d.tipX, d.tipZ)], "the raft cannot reach dock " .. d.id)
		end
		assert(seen[g.at(V3.POOL.x, V3.POOL.z)], "the raft cannot reach the pool")
		local east = -math.huge
		for k in pairs(seen) do east = math.max(east, g.x(k)) end
		assert(east >= Layout.EAST - 5, "the raft stops at x " .. east)
	end)

	-- CL-D3, CL-D8: the dock basins.
	case("V3-23: every dock tip sits >= LAKE_BLEND (8) inside a lake disc; the basins (discs 3..5) lie inside the river band", function()
		-- 8 is WildboundCandyCurrent's LAKE_BLEND: past it the current is the lake's 1.5
		for _, d in ipairs(V3.DOCKS) do
			local inside = -math.huge
			for _, disc in ipairs(V3.LAKE) do inside = math.max(inside, disc.r - flat(d.tipX, d.tipZ, disc.x, disc.z)) end
			assert(inside >= 8, ("dock %s's tip is %.2f inside a disc"):format(d.id, inside))
		end
		for i = 3, #V3.LAKE do
			local disc = V3.LAKE[i]
			for a = 0, 71 do
				local angle = a * math.pi / 36
				local x, z = disc.x + math.cos(angle) * disc.r, disc.z + math.sin(angle) * disc.r
				assert(V3.riverDistance(x, z) <= 0, ("basin %d's rim leaves the river at %.1f, %.1f"):format(i, x, z))
			end
		end
	end)

	-- CL-D4: M1's water is placed from the kit's offsets.
	case("V3-24: POOL, WATERFALL and RIVER[1] are kitPoints of M1; kitPoint at the M1_V8 row reproduces the v8 pool", function()
		local m1, K = riverMountain(), V3.M1_KIT
		local yaw = V3.faceYaw(m1.x, m1.z, m1.faceX, m1.faceZ)
		near(yaw, -1.5107, "M1's turn", 1e-4)
		local px, pz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.pool[1], K.pool[2])
		near(V3.POOL.x, px, "the pool x", 1e-9); near(V3.POOL.z, pz, "the pool z", 1e-9)
		local wx, wz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.fall[1], K.fall[2])
		near(V3.WATERFALL.x, wx, "the fall x", 1e-9); near(V3.WATERFALL.z, wz, "the fall z", 1e-9)
		local ox, oz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.outlet[1], K.outlet[2])
		near(V3.RIVER[1][1], ox, "the outlet x", 1e-9); near(V3.RIVER[1][2], oz, "the outlet z", 1e-9)
		near(flat(V3.RIVER[1][1], V3.RIVER[1][2], V3.POOL.x, V3.POOL.z), 9, "outlet to pool", 1e-6)
		local V = V3.M1_V8
		assert(table.isfrozen(V), "M1_V8 frozen")
		equal(V.scale, 0.45, "the v8 scale")
		local vyaw = V3.faceYaw(V.x, V.z, V.faceX, V.faceZ)
		local vx, vz = V3.kitPoint(V.x, V.z, vyaw, V.scale, K.pool[1], K.pool[2])
		near(vx, -8.44, "the v8 pool x", 0.01); near(vz, 219.36, "the v8 pool z", 0.01)
	end)

	-- CL-D3: the joint drums match the rule's capsules.
	case("V3-25: jointRadius is half the widest of a point and its neighbours; no drum at the last point", function()
		local n = #V3.RIVER
		for i = 1, n do
			local w = V3.RIVER[i][3]
			if i > 1 then w = math.max(w, V3.RIVER[i - 1][3]) end
			if i < n then w = math.max(w, V3.RIVER[i + 1][3]) end
			equal(V3.jointRadius(i), w / 2, "joint " .. i)
		end
		equal(V3.jointRadius(1), 25, "the foot basin"); equal(V3.jointRadius(11), 45, "the reach's end")
		equal(V3.jointRadius(15), 60, "the east stretch")
		assert(math.abs(Layout.depth(V3.RIVER[n][1], V3.RIVER[n][2])) < 0.01, "the mouth lies on the edge (no drum there)")
		for i = 1, n - 1 do
			assert(Layout.depth(V3.RIVER[i][1], V3.RIVER[i][2]) > 0.01, "point " .. i .. " gets its drum")
		end
		assert(flat(V3.RIVER[1][1], V3.RIVER[1][2], V3.POOL.x, V3.POOL.z) + V3.POOL.r <= V3.jointRadius(1),
			"the foot basin holds the kit pool")
	end)

	return result
end
