-- Invoke with require(freshTestClone)(require(freshCandyIslandClone), require(freshCandyNestsClone),
--   require(freshCandyLayoutClone), require(freshCandyV3LayoutClone), require(freshCandyRaftClone),
--   require(freshCandyWadeClone), require(freshCandyCurrentClone), require(freshCandyLifeClone),
--   { nests = <WildboundCandyNests Source>, beasts = <WildboundBeasts Source> }).
-- Caramelo v6, proposal 4 (odd/tasks/wildbound-caramelo-v2.md V6-D4; docs/design/wildbound-caramelo-v3-plan.md V6-D60
-- on): an island in the big lake with one Epica egg nest. The layout's island (V3.ISLANDS) clear of the docks, the
-- straight dock-to-dock line, the cookie platforms and the bridges, with a raft channel all round; the chocolate ends at
-- its waterline for every reader of V3.liquidDistance (the raft cannot enter it, still sails round it and docks at every
-- dock, CL-D8; a wader walks up out of it by the feet rule; the current is 0 on it; no fish jumps out of it); the ground's
-- slabs follow the shore profile; WildboundCandyIsland.sync on a detached biome lays the island and its nest
-- idempotently, read as the unguarded Epica island nest CandyI1; and the wiring (applyFlags' eighth step, the reader,
-- the frenzy on any steal). Every fixture is built detached (never parented to a service); the kit is a fake.
return function(Island, Nests, Layout, V3, Raft, Wade, Current, Life, sources)
	local CollectionService = game:GetService("CollectionService")
	local result = { passed = 0, failed = 0, messages = {} }
	local function case(name, run)
		local ok, message = pcall(run)
		if ok then result.passed += 1 else
			result.failed += 1
			table.insert(result.messages, name .. ": " .. tostring(message))
		end
	end
	local function equal(actual, expected, label)
		assert(actual == expected, (label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "expected " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
	end
	local function hasNot(source, needle, label)
		assert(type(source) == "string" and not string.find(source, needle, 1, true), (label or "must not appear") .. ": " .. needle)
	end
	local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
	assert(type(Island) == "table" and type(Nests) == "table" and type(Layout) == "table" and type(V3) == "table"
		and type(Raft) == "table" and type(Wade) == "table" and type(Current) == "table",
		"pass the island, the nests, both layouts, the raft, the wade and the current modules")
	sources = type(sources) == "table" and sources or {}

	local C = Layout.CENTRE
	local I = V3.ISLANDS[1]
	-- The chocolate without the islands (the river, the pool and the lake discs), as before V6-D4.
	-- CL-D3: with the v9 plot clip (nothing outside the plot is chocolate), as V3.liquidDistance has it.
	local function water(x, z)
		local best = V3.riverDistance(x, z)
		best = math.min(best, flat(x, z, V3.POOL.x, V3.POOL.z) - V3.POOL.r)
		for _, disc in ipairs(V3.LAKE) do best = math.min(best, flat(x, z, disc.x, disc.z) - disc.r) end
		return math.max(best, -V3.plotDepth(x, z))
	end
	-- A point `rho` studs from the island's centre, `degrees` round it (plot coordinates).
	local function round(rho, degrees)
		local a = math.rad(degrees)
		return I.x + math.cos(a) * rho, I.z + math.sin(a) * rho
	end
	local area = Raft.area(V3, C, Current.flow)
	local docks = Raft.docksFrom(V3, C)

	-- The layout ---------------------------------------------------------------------------------------------------
	case("IS1: one island in the big lake, about 9 across the floor, clear of the docks, their line, the cookies and the bridges", function()
		equal(#V3.ISLANDS, 1, "one island")
		equal(I.id, "I1", "its id")
		assert(I.flat < I.r and I.r < I.foot, "a level top, a beach to the waterline, a bank to the foot")
		assert(I.r >= 6 and I.foot >= 9 and I.foot <= 12, ("about 9: waterline %g, foot %g"):format(I.r, I.foot))
		near(I.foot, I.r + V3.LIQUID.depth / math.tan(math.rad(V3.ISLAND.bankDegrees)), "the foot follows the bank's slope", 0.05)
		local big = V3.LAKE[1]
		assert(flat(I.x, I.z, big.x, big.z) + I.r < big.r, "inside the big disc")
		-- the raft's channel all round: water (as laid) a hull past the hull's ring
		for k = 0, 359 do
			local x, z = round(I.r + Raft.HULL + 0.25, k)
			assert(water(x, z) <= -Raft.HULL, ("no raft channel at %d degrees (%.2f)"):format(k, water(x, z)))
			assert(not V3.nearBridge(x, z, Raft.HULL), "the channel passes a bridge at " .. k)
		end
		-- the underwater bank stays in the chocolate
		for k = 0, 359, 5 do
			local x, z = round(I.foot, k)
			assert(water(x, z) < 0, "the foot leaves the lake at " .. k)
		end
		-- away from the docks' tips and approach, and from the straight line between them, by more than a raft
		-- CL-D8: four docks (A, B, C, D); every tip and stand is checked, and the straight line is A-B's (the only two
		-- that face each other along open water, the west channel; C and D are reached along the river)
		assert(#V3.DOCKS >= 3, "the v9 docks")
		local a, b = V3.DOCKS[1], V3.DOCKS[2]
		for _, d in ipairs(V3.DOCKS) do
			assert(flat(I.x, I.z, d.tipX, d.tipZ) - I.foot >= Raft.ARM_STUDS + 2 * Raft.HULL, "by dock " .. d.id)
			assert(flat(I.x, I.z, d.standX, d.standZ) - I.foot >= 20, "by dock " .. d.id .. "'s stand")
		end
		assert(V3.segmentDistance(I.x, I.z, a.tipX, a.tipZ, b.tipX, b.tipZ) - I.foot >= 4 * Raft.HULL,
			"on the raft's main line between the docks")
		-- clear of the cookie platforms (their walk tops by pieceApart, their pedestals by the underwater foot)
		for i, p in ipairs(V3.PLATFORMS) do
			assert(flat(I.x, I.z, p.x, p.z) - p.r - I.r >= V3.CLEAR.pieceApart, "on cookie platform " .. i)
			assert(flat(I.x, I.z, p.x, p.z) - p.r * V3.PLATFORM.pedestalShare - I.foot >= 0, "the bank in pedestal " .. i)
		end
		assert(not V3.nearBridge(I.x, I.z, I.foot + 2 * Raft.HULL), "by a bridge")
		-- off the land's things: routes, nests, posts, pieces
		assert(Layout.routeDistance(I.x, I.z) - I.foot - Layout.PATH_WIDTH / 2 >= V3.CLEAR.pieceFromRoute, "on a route")
		for _, n in ipairs(Layout.NESTS) do assert(flat(I.x, I.z, n.x, n.z) - I.foot >= V3.CLEAR.pieceFromNest, "on nest " .. n.id) end
		for _, p in ipairs(V3.pieces()) do assert(flat(I.x, I.z, p.x, p.z) - I.foot - p.r >= V3.CLEAR.pieceApart, "on " .. p.kind .. " " .. p.id) end
		-- the nest id is the island's and clashes with no other candy nest
		local id = Island.nestId(I)
		equal(id, "I1", "the nest id")
		for _, n in ipairs(Layout.NESTS) do assert(n.id ~= id, "clashes with layout nest " .. n.id) end
		assert(Layout.TOWER.summit.id ~= id, "clashes with the summit nest")
		for _, h in ipairs(V3.HOUSES) do assert(h.id ~= id, "clashes with house nest " .. h.id) end
	end)

	case("IS2: the chocolate ends at the island's waterline; everywhere else it is as laid", function()
		near(V3.liquidDistance(I.x, I.z), I.r, "the centre is dry, r from the water")
		assert(V3.liquidDistance(round(I.r - 0.01, 30)) > 0, "just inside the waterline: land")
		assert(V3.liquidDistance(round(I.r + 0.01, 30)) < 0, "just outside it: chocolate")
		near(V3.islandDistance(I.x, I.z), -I.r, "the island's own distance")
		local px, pz = round(I.r + 2, 0)
		equal(V3.islandAt(I.x, I.z), I, "islandAt"); equal(V3.islandAt(px, pz), nil, "past the waterline")
		equal(V3.islandAt(px, pz, 3), I, "within a reach")
		for k = 0, 359, 10 do
			local x, z = round(I.r + Raft.HULL + 0.25, k)
			local d = V3.liquidDistance(x, z)
			assert(d <= -Raft.HULL, "round the island: open chocolate at " .. k)
			assert(d >= -(Raft.HULL + 0.25) - 1e-9, "round the island: the shore is the nearest edge at " .. k)
		end
		-- far from the island nothing changed
		for _, p in ipairs({ { V3.LAKE[2].x, V3.LAKE[2].z }, { V3.DOCKS[1].tipX, V3.DOCKS[1].tipZ }, { -150, 0 }, { 5, 82 } }) do
			near(V3.liquidDistance(p[1], p[2]), water(p[1], p[2]), ("as laid at %g, %g"):format(p[1], p[2]), 1e-9)
		end
		local ok, why = V3.clearOfPieces(I.x, I.z, 1)
		assert(not ok and why == "on island I1", "the fill never stands on the island: " .. tostring(why))
	end)

	-- The raft, wading and the current ------------------------------------------------------------------------------
	case("IS3: the raft cannot enter the island, sails round it, and still crosses and docks at every dock", function()
		local wx, wz = C.x + I.x, C.z + I.z
		for rho = 0, I.r + Raft.HULL - 0.05, 0.5 do
			for k = 0, 330, 30 do
				local x, z = round(rho, k)
				assert(not area.inside(C.x + x, C.z + z, Raft.HULL), ("the hull fits at %g studs, %d degrees"):format(rho, k))
			end
		end
		-- round it: every point of the ring fits the hull
		for k = 0, 359 do
			local x, z = round(I.r + Raft.HULL + 0.25, k)
			assert(area.inside(C.x + x, C.z + z, Raft.HULL), "the ring is blocked at " .. k)
		end
		-- driven straight at it from each side at full throttle, with the current: it stops at its hull's reach
		local runs = 0
		for k = 0, 315, 45 do
			local x, z
			for _, rho in ipairs({ I.r + Raft.HULL + 3, I.r + Raft.HULL + 1.5, I.r + Raft.HULL + 0.25 }) do
				x, z = round(rho, k)
				if area.inside(C.x + x, C.z + z, Raft.HULL) then break end
			end
			runs += 1
			local s = Raft.new(docks, V3.RAFT.homeDock)
			s.status, s.rider, s.armed = "Sailing", 1, true
			s.x, s.z, s.speed = C.x + x, C.z + z, 0
			s.yaw = math.atan2(-(wx - s.x), -(wz - s.z))
			for step = 1, 90 do
				Raft.step(s, 1 / 30, step / 30, { throttle = 1, steer = 0 }, true, area)
				assert(flat(s.x, s.z, wx, wz) >= I.r + Raft.HULL - 1e-6, ("the raft ran aground from %d degrees"):format(k))
			end
		end
		equal(runs, 8, "a run from every side")
		-- the straight crossing between the docks still floats the hull (reach 0 by a tip, as the raft's rule)
		local a, b = docks[1], docks[2]
		for s = 0, 100 do
			local x, z = a.x + (b.x - a.x) * s / 100, a.z + (b.z - a.z) * s / 100
			local reach = Raft.nearDock({ docks = docks }, x, z, Raft.ARM_STUDS) and 0 or Raft.HULL
			assert(area.inside(x, z, reach), "the crossing is blocked at " .. s .. " %")
		end
		-- docking at every dock with the current (as WildboundCandyCurrent_Test CU7)
		-- CL-D8: #V3.DOCKS docks; each approach starts 10 studs out along the dock's own look (stand -> tip)
		for i = 1, #V3.DOCKS do
			local tip = docks[i]
			local dx, dz = -math.sin(tip.yaw), -math.cos(tip.yaw)
			local s = Raft.new(docks, V3.RAFT.homeDock)
			s.status, s.rider, s.armed, s.speed = "Sailing", 40 + i, true, 0
			s.x, s.z = tip.x + dx * 10, tip.z + dz * 10
			s.yaw = math.atan2(dx, dz)
			local t, arrived = 0, nil
			while t < 15 and not arrived do
				t += 1 / 30
				local want = math.atan2(-(tip.x - s.x), -(tip.z - s.z))
				local diff = (want - s.yaw + math.pi) % (2 * math.pi) - math.pi
				for _, e in ipairs(Raft.step(s, 1 / 30, t, { throttle = 0.15, steer = math.clamp(-diff * 3, -1, 1) }, true, area)) do
					if e.kind == "Arrived" then arrived = e end
				end
			end
			assert(arrived and arrived.dock == i, "docked at dock " .. i)
		end
	end)

	case("IS4: a wader walks up out of the chocolate: the shore's profile and the feet rule", function()
		local top, surface = Island.heights(V3)
		near(top, V3.LIQUID.depth + V3.ISLAND.top, "the top"); near(surface, V3.LIQUID.depth, "the waterline")
		assert(V3.ISLAND.top >= 0.6, "the top stands clear of the surface")
		near(Island.profile(I, V3, 0), top, "level top"); near(Island.profile(I, V3, I.flat), top, "the top's edge")
		near(Island.profile(I, V3, I.r), surface, "the waterline"); near(Island.profile(I, V3, I.foot), 0, "the foot")
		near(Island.profile(I, V3, I.foot + 3), 0, "past the foot")
		local beach, bank = Island.slopes(I, V3)
		assert(beach <= 30, "a gentle beach: " .. beach)
		assert(bank <= 45, "a walkable bank: " .. bank)
		-- the feet rule: a player standing on the ground at rho (an R15 root 2 + 1 over its feet)
		local function wades(rho)
			local x, z = round(rho, 200)
			local feet = Layout.FLOOR_TOP + Island.profile(I, V3, rho)
			local info = Wade.probe(V3, C, Layout.FLOOR_TOP, Vector3.new(C.x + x, feet + 3, C.z + z), 1, 2, false)
			info.alive, info.seated, info.airborne = true, false, false
			return Wade.wading(true, info), info
		end
		assert((wades(I.foot + 1)), "on the lake floor past the foot: wading")
		assert((wades(I.foot - 1)), "low on the bank: still wading")
		local on, info = wades(I.r + 0.5)
		assert(info.liquid < 0 and not on, "high on the bank, feet over the wading line: walking, not wading")
		assert(not (wades(I.r - 0.5)), "on the beach: dry")
		assert(not (wades(0)), "on the top: dry")
		-- every step up the bank keeps the feet rule monotonic: once out, out until the top
		local out = false
		for rho = I.foot + 1, 0, -0.25 do
			local w = (wades(rho))
			if out then assert(not w, "back into the chocolate at " .. rho) end
			if not w then out = true end
		end
		assert(out, "the wader got out")
	end)

	case("IS5: the current is 0 on the island and never pushes a wader across it", function()
		-- (to just inside the waterline: on it the rounding of the distances leaves a 1e-16 flow)
		for rho = 0, I.r - 0.25, 0.5 do
			for k = 0, 330, 30 do
				local vx, vz = Current.flow(V3, round(rho, k))
				equal(vx, 0, "x on the island"); equal(vz, 0, "z on the island")
				local px, pz = Current.push(V3, round(rho, k))
				equal(px, 0); equal(pz, 0, "no push on the island")
			end
		end
		-- at the waterline it eases from 0 (the bank's EDGE), and the river still flows past the island
		for k = 0, 330, 30 do
			assert(Current.speedAt(V3, round(I.r + 0.25, k)) <= Current.RIVER_SPEED * 0.25 / Current.EDGE + 1e-6,
				"eased at the shore " .. k)
		end
		local flowing = 0
		for k = 0, 330, 30 do
			if Current.speedAt(V3, round(I.r + Current.EDGE + 1, k)) > 0.5 then flowing += 1 end
		end
		equal(flowing, 12, "the chocolate flows all round the island")
	end)

	case("IS6: no fish jumps out of the island (WildboundCandyLife)", function()
		if type(Life) ~= "table" then return end
		for _, spot in ipairs(Life.FISH_SPOTS) do
			for step = 0, 20 do
				local u = step / 20
				local x = spot.x + math.cos(spot.heading) * Life.FISH_JUMP.length * u
				local z = spot.z + math.sin(spot.heading) * Life.FISH_JUMP.length * u
				equal(V3.islandAt(x, z, Life.FISH_MARGIN), nil, spot.id .. " jumps on the island")
			end
		end
	end)

	-- The ground ----------------------------------------------------------------------------------------------------
	case("IS7: the ground's slabs follow the shore's profile, collide, and stay within the foot", function()
		local floorTop = Layout.FLOOR_TOP
		local list = Island.ground(I, V3, C, floorTop)
		local kinds = { core = 0, beach = 0, bank = 0 }
		for _, g in ipairs(list) do kinds[g.kind] += 1 end
		equal(kinds.core, 1, "one core"); equal(kinds.beach, V3.ISLAND.sectors, "a beach slab per slice")
		equal(kinds.bank, V3.ISLAND.sectors, "a bank slab per slice")
		local function topAt(g, x, z)
			local n = g.cframe.UpVector
			local p = g.cframe.Position + n * g.size.Y / 2
			return p.Y - (n.X * (x - p.X) + n.Z * (z - p.Z)) / n.Y
		end
		local wx, wz = C.x + I.x, C.z + I.z
		for _, g in ipairs(list) do
			if g.kind ~= "core" then
				assert(g.cframe.UpVector.Y > 0.5, g.name .. " faces up")
				-- the slice's centre line runs along the slab's length through its centre
				local c = g.cframe.Position
				local dx, dz = c.X - wx, c.Z - wz
				local length = math.sqrt(dx * dx + dz * dz)
				local ux, uz = dx / length, dz / length
				local from, to = g.kind == "beach" and I.flat or I.r, g.kind == "beach" and I.r or I.foot
				for s = 0, 10 do
					local rho = from + (to - from) * s / 10
					near(topAt(g, wx + ux * rho, wz + uz * rho) - floorTop, Island.profile(I, V3, rho),
						("%s at %.2f"):format(g.name, rho), 0.02)
				end
			else
				near(g.cframe.Position.Y + g.size.X / 2 - floorTop, (Island.heights(V3)), "the core's top is the island's top", 1e-3)
			end
		end
		-- a built island: everything that collides is the ground; the decor never collides or answers a ray
		local model = Island.build(I, V3, C, floorTop, nil, nil)
		local solid = 0
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				assert(d.Anchored, d.Name .. " anchored")
				if d.CanCollide then
					solid += 1
					assert(d:GetAttribute("Role") == "floor", d.Name .. " is ground")
				else
					assert(not d.CanQuery and not d.CanTouch, d.Name .. " decor answers rays")
					local p = d.Position
					assert(flat(p.X, p.Z, wx, wz) <= I.flat + 0.01, d.Name .. " decor off the top")
				end
			end
		end
		equal(solid, #list, "every ground part collides")
		near((model:GetPivot().Position - Vector3.new(wx, floorTop, wz)).Magnitude, 0, "the pivot on the floor at the centre")
		model:Destroy()
	end)

	-- The sync on a detached biome ----------------------------------------------------------------------------------
	local function biome(version, withLake)
		local root = Instance.new("Model")
		root.Name = Nests.ROOT_NAME
		local ground = Instance.new("Folder")
		ground.Name, ground.Parent = "Ground", root
		local floor = Instance.new("Part")
		-- CL-D13: the v9 floor, x -HALF..EAST, so the island (local x 690) stands on it
		floor.Name, floor.Anchored, floor.Size = "Floor", true, Vector3.new(Layout.HALF + Layout.EAST, 1, Layout.HALF * 2)
		floor.Position = Vector3.new(C.x + (Layout.EAST - Layout.HALF) / 2, Layout.FLOOR_TOP - 0.5, C.z)
		floor.Parent = ground
		local v3 = Instance.new("Folder")
		v3.Name, v3.Parent = V3.FOLDER, root
		v3:SetAttribute("Version", version or 3)
		if withLake ~= false then
			local lake = Instance.new("Folder")
			lake.Name, lake.Parent = "Lake", v3
		end
		local nests = Instance.new("Folder")
		nests.Name, nests.Parent = "Nests", root
		return root, nests
	end
	-- The fake kit: the Nest prefab as the kit's bowl (Collision_Bowl 5.3 x 2.2 at `scale`) and a ring; any other asset
	-- a model with a colliding part.
	local function fakeKit()
		local placed = {}
		local kit = { LIBRARY_NAME = "CandyKit", place = function(library, name, cframe, scale)
			table.insert(placed, { library = library, name = name, scale = scale, cframe = cframe })
			local model = Instance.new("Model")
			if name == "Nest" then
				local bowl = Instance.new("Part")
				bowl.Name, bowl.Shape, bowl.Anchored = "Collision_Bowl", Enum.PartType.Cylinder, true
				bowl.Size = Vector3.new(2.2, 5.3, 5.3) * scale
				bowl.CFrame = CFrame.new(0, 1.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
				bowl.Parent = model
				local ring = Instance.new("Part")
				ring.Name, ring.Anchored, ring.Parent = "RarityRing", true, model
			else
				local trunk = Instance.new("Part")
				trunk.Name, trunk.Anchored, trunk.CanCollide, trunk.Size = "Collision_Trunk", true, true, Vector3.new(0.5, 3, 0.5)
				trunk.CFrame = CFrame.new(0, 1.5, 0)
				trunk.Parent = model
			end
			model.WorldPivot = CFrame.new()
			model:PivotTo(cframe)
			return model
		end }
		return kit, placed
	end

	case("IS8: sync lays the island and its Epica nest once, read as the unguarded island nest CandyI1", function()
		local root, nests = biome()
		local kit, placed = fakeKit()
		local library = Instance.new("Folder")
		local changed, skipped, count = Island.sync(root, Layout, V3, { kit = kit, library = library })
		equal(changed, 2, "the island and its nest"); equal(#skipped, 0, "nothing skipped"); equal(count, 1, "one island")
		local folder = root:FindFirstChild(Island.FOLDER)
		local model = folder and folder:FindFirstChild("LakeIsland_I1")
		assert(model, "LakeIsland_I1 laid")
		assert(CollectionService:HasTag(model, Island.TAG), "tagged")
		equal(model:GetAttribute("IslandId"), "I1"); equal(model:GetAttribute("Build"), Island.BUILD)
		equal(model:GetAttribute("CandyIsland"), true)
		local decor = 0
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("Model") and d.Name:match("^Decor_") then
				decor += 1
				for _, p in ipairs(d:GetDescendants()) do
					if p:IsA("BasePart") then assert(not p.CanCollide and not p.CanQuery, d.Name .. " decor collides") end
				end
			end
		end
		equal(decor, #Island.DECOR, "the kit decor")
		local nest = nests:FindFirstChild("Nest_I1")
		assert(nest, "Nest_I1 in the Nests folder")
		equal(nest:GetAttribute("NestId"), "I1"); equal(nest:GetAttribute("Rarity"), "Epica", "an Epica egg")
		equal(nest:GetAttribute("LakeIsland"), true); equal(nest:GetAttribute("IslandId"), "I1")
		equal(nest:GetAttribute("EventOnly"), false); equal(nest:GetAttribute("Candidate"), true)
		equal(nest:GetAttribute("Enabled"), Layout.NESTS_ENABLED == true, "follows the layout's flag")
		assert(CollectionService:HasTag(nest, "WildboundCandyNestCandidate"), "the nest tag")
		equal(nest.PrimaryPart and nest.PrimaryPart.Name, "Collision_Bowl", "the bowl")
		local at = Island.nestFrame(I, V3, C, Layout.FLOOR_TOP)
		near((nest:GetPivot().Position - at.Position).Magnitude, 0, "on the island's top")
		near(at.Position.Y, Layout.FLOOR_TOP + V3.LIQUID.depth + V3.ISLAND.top, "the top's height")
		local nestCalls = 0
		for _, p in ipairs(placed) do if p.name == "Nest" then nestCalls += 1; near(p.scale, Island.NEST_SCALE, "nest scale") end end
		equal(nestCalls, 1, "one Nest prefab")
		-- idempotent
		local before = #placed
		equal(select(1, Island.sync(root, Layout, V3, { kit = kit, library = library })), 0, "a second start changes nothing")
		equal(#placed, before, "and places nothing"); equal(#folder:GetChildren(), 1, "no duplicate island")
		local count1 = 0
		for _, c in ipairs(nests:GetChildren()) do if c.Name == "Nest_I1" then count1 += 1 end end
		equal(count1, 1, "no duplicate nest")
		-- a moved nest goes back; the flag follows the layout; an old build is laid again
		nest:PivotTo(nest:GetPivot() * CFrame.new(3, 0, 0))
		equal(select(1, Island.sync(root, Layout, V3, { kit = kit, library = library })), 1, "the nest put back")
		near((nest:GetPivot().Position - at.Position).Magnitude, 0, "back on its spot")
		equal(select(1, Island.sync(root, { CENTRE = Layout.CENTRE, FLOOR_TOP = Layout.FLOOR_TOP, NESTS_ENABLED = false }, V3,
			{ kit = kit, library = library })), Layout.NESTS_ENABLED == true and 1 or 0, "the flag off")
		equal(nest:GetAttribute("Enabled"), false)
		Island.sync(root, Layout, V3, { kit = kit, library = library })
		model:SetAttribute("Build", Island.BUILD - 1)
		equal(select(1, Island.sync(root, Layout, V3, { kit = kit, library = library })), 1, "an old build laid again")
		assert(folder:FindFirstChild("LakeIsland_I1"):GetAttribute("Build") == Island.BUILD, "the new build")
		-- read by the nest pipeline: an Epica island nest nobody guards
		local read = Nests.read(root)
		equal(#read, 1, "one marker")
		local m = read[1]
		equal(m.id, "I1"); equal(m.rarity, "Epica"); equal(m.island, true, "marked as the island's"); equal(m.house, false)
		near(m.top, at.Position.Y + 2.2 * Island.NEST_SCALE, "the bowl's top (the egg's height)", 0.01)
		local posts = { { name = "Flanfuria", x = m.x + 2, z = m.z } }
		equal(Nests.bind(read, posts).I1, nil, "a post beside it does not guard it")
		if Layout.NESTS_ENABLED == true then
			local list = Nests.islands(read, posts)
			equal(#list, 1, "one island nest")
			local entry = list[1]
			equal(entry.id, "CandyI1", "the island id (telemetry Island_CandyI1)"); equal(entry.key, "caramelo_i1")
			equal(entry.rarity, "Epica"); equal(entry.species, Nests.pick("Epica").species, "an Epica species")
			equal(entry.eggs, 1, "one egg"); equal(entry.guard, nil, "no guardian post")
			equal(entry.adults, 0, "no sleeping parent")
			-- merged with the other islands, its id is new (the expedition islands are I1..I5, the candy ones Candy<id>)
			local merged = Nests.merge({ islands = { { id = "I1" }, { id = "CandyH5" } } }, read, posts)
			equal(#merged.islands, 3, "added after the others")
		end
		root:Destroy(); library:Destroy()
	end)

	case("IS9: without the kit a plain nest; nothing without the v5 water; a stale island goes", function()
		local root, nests = biome()
		local changed = Island.sync(root, Layout, V3, { kit = false })
		equal(changed, 2, "laid without the kit")
		local nest = nests:FindFirstChild("Nest_I1")
		assert(nest and nest.PrimaryPart and nest.PrimaryPart.Name == "Collision_Bowl", "a plain bowl")
		assert(nest.PrimaryPart.CanCollide, "the plain bowl is solid")
		for _, d in ipairs(root[Island.FOLDER].LakeIsland_I1:GetChildren()) do
			assert(not d:IsA("Model"), "no kit decor without the kit")
		end
		equal(Nests.read(root)[1].rarity, "Epica")
		-- an island no longer in the layout (and its nest) is removed
		local empty = setmetatable({ ISLANDS = {} }, { __index = V3 })
		equal(select(1, Island.sync(root, Layout, empty, { kit = false })), 2, "the stale island and nest removed")
		equal(nests:FindFirstChild("Nest_I1"), nil); equal(root[Island.FOLDER]:FindFirstChild("LakeIsland_I1"), nil)
		root:Destroy()
		-- an older water (v4) or no lake: nothing
		local old = biome(2)
		equal(select(1, Island.sync(old, Layout, V3, { kit = false })), 0, "a v4 biome")
		equal(old:FindFirstChild(Island.FOLDER), nil)
		local dry = biome(3, false)
		equal(select(1, Island.sync(dry, Layout, V3, { kit = false })), 0, "no lake")
		equal(select(1, Island.sync(Instance.new("Model"), Layout, V3, { kit = false })), 0, "no v3 biome")
		equal(select(1, Island.sync(nil, Layout, V3, { kit = false })), 0, "no root: nothing, no error")
		-- no Nests folder: the island, its nest skipped
		local bare = biome()
		bare.Nests:Destroy()
		local n, skipped = Island.sync(bare, Layout, V3, { kit = false })
		equal(n, 1, "the island alone"); equal(skipped[1], "I1", "the nest skipped")
		old:Destroy(); dry:Destroy(); bare:Destroy()
	end)

	-- Wiring --------------------------------------------------------------------------------------------------------
	case("IS10: applyFlags lays the island eighth (after the traps, guarded); the reader and the frenzy", function()
		local root = Instance.new("Model")
		local fakeBuilder = { syncNests = function() return 0 end, syncPortal = function() return 0 end }
		local calls = 0
		local fake = { sync = function(r, L) assert(r == root and L == Layout, "the root and layout"); calls += 1; return 4 end }
		equal(select(8, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, false, fake)), 4, "the eighth value")
		equal(calls, 1, "called once")
		equal(select(8, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, false, false)), 0, "false: none")
		equal(select(8, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, false, { sync = function() error("boom") end })),
			0, "an error is contained")
		equal(select(7, Nests.applyFlags(root, fakeBuilder, Layout, false, false, false, { sync = function() return 3 end }, false)),
			3, "the traps' value is unchanged")
		root:Destroy()
		local nests = sources.nests
		has(nests, 'FindFirstChild("WildboundCandyIsland")', "the module is looked up in ServerStorage (no wait)")
		has(nests, "pcall(I.sync, root, Layout)", "guarded")
		assert(nests:find("pcall(I.sync, root, Layout)", 1, true) > nests:find("pcall(T.sync, root, Layout)", 1, true),
			"after the traps")
		has(nests, "okIsland and tonumber(island) or 0", "an eighth value")
		has(nests, 'island = nest:GetAttribute("LakeIsland") == true', "read marks the island's nest")
		has(nests, "and m.island ~= true", "bind skips it")
		-- the frenzy: any egg first carried inside the biome starts it, whatever its nest (no nest filter)
		local beasts = sources.beasts
		has(beasts, "function world.stealCheck(player, character, p, at, inside)", "the steal check")
		has(beasts, "world.smarts.frenzy(world, player.UserId, at, p.X, p.Z)", "starts the frenzy")
		has(beasts, "if inside and id ~= nil and world.lastEgg[player] ~= id then", "on any new egg inside the biome")
		hasNot(beasts, "LakeIsland", "no island exception in the beasts")
	end)

	return result
end
