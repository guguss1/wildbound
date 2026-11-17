-- Invoke with require(freshTestClone)(require(freshCandyV3BuilderClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone), require(freshCandyBuilderClone), require(freshCandyV3KitSpecClone),
--   require(freshCandyKitClone), ServerStorage.WildboundAssets.CandyKit). Yields: it builds three times.
-- Caramelo v3 (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md): what WildboundCandyV3Builder lays.
-- Every build goes into a detached scratch Model (never parented into the place), so the live biome is never touched:
-- the placeholder batch (no kit), a batch with a stand-in kit house built from the kit spec's colliders, the plan of
-- what a live map archives, and the tree swap.
return function(V3Builder, V3, Layout, Builder, KitSpec, Kit, library)
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
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local centre, floorTop = Layout.CENTRE, Layout.FLOOR_TOP
	local surface = V3.surfaceY(floorTop)
	local function topOf(p)
		local cf, s = p.CFrame, p.Size
		return p.Position.Y + (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z) / 2
	end
	local function parts(instance)
		local out = {}
		for _, d in ipairs(instance:GetDescendants()) do if d:IsA("BasePart") then table.insert(out, d) end end
		return out
	end

	-- 1. the placeholder batch: no CandyKitV3 at all
	local scratch = Instance.new("Model")
	scratch.Name = "CandyV3BuilderScratch"
	local okBuild, report = pcall(V3Builder.layAll, scratch, { Layout = Layout, V3 = V3, kitV3 = nil, kitSpec = KitSpec,
		Kit = Kit, library = library, keepOut = {} })
	if not okBuild then
		result.failed += 1
		table.insert(result.messages, "layAll: " .. tostring(report))
		scratch:Destroy()
		return result
	end
	local holder = scratch:FindFirstChild(V3.FOLDER)

	case("B1: one CaramelV3 folder with every piece, placeholders named, within the part budget, refused twice", function()
		assert(holder and holder:IsA("Folder"), "no " .. V3.FOLDER .. " folder")
		for _, name in ipairs({ "River", "Lake", "Waterfall", "Bridge", "Docks", "Mountains", "Houses", "Licorice", "Cake",
			"Platforms", "Trees", "Filler" }) do
			assert(holder:FindFirstChild(name), "missing " .. name)
		end
		equal(#report.placeholders, #V3.MOUNTAINS + #V3.HOUSES + 1 + 1 + #V3.PLATFORMS, "placeholders")
		equal(holder:GetAttribute("PartCount"), report.parts, "PartCount")
		equal(#parts(holder), report.parts, "every part counted")
		assert(report.parts <= V3.MAX_NEW_PARTS, "over budget: " .. report.parts)
		assert(not pcall(V3Builder.layAll, scratch, { Layout = Layout, V3 = V3 }), "a second batch was accepted")
		for _, d in ipairs(holder:GetDescendants()) do
			assert(not d:IsA("LuaSourceContainer"), "a script in the batch: " .. d:GetFullName())
			if d:IsA("BasePart") then
				assert(d.Anchored, d.Name .. " is not anchored")
				assert(type(d:GetAttribute("Role")) == "string", d:GetFullName() .. " has no Role")
				equal(d.CanCollide, d:GetAttribute("Role") == "floor" or d:GetAttribute("Role") == "solid", d:GetFullName() .. " collision")
			end
		end
	end)

	case("B2: the chocolate is walk-through, never queried, its surface at the layout's depth", function()
		local count = 0
		for _, folderName in ipairs({ "River", "Lake" }) do
			for _, p in ipairs(holder[folderName]:GetChildren()) do
				if string.sub(p.Name, 1, 6) == "Choco_" then
					count += 1
					equal(p.CanCollide, false, p.Name .. " collides")
					equal(p.CanQuery, false, p.Name .. " answers rays")
					equal(p:GetAttribute("Liquid"), "Chocolate", p.Name)
					near(topOf(p), surface, p.Name .. " surface", 0.01)
				end
			end
		end
		equal(count, #V3.RIVER * 2 - 1 + 1 + #V3.LAKE, "river legs, joints, the placeholder pool and the lake discs")
	end)

	case("B3: the bridge's deck and ramps are walkable over the surface, its rails off the path", function()
		local bridge = holder.Bridge
		local deck = bridge.Deck
		equal(deck:GetAttribute("Role"), "floor", "deck role")
		near(topOf(deck), floorTop + V3.BRIDGE.deck, "deck top", 0.01)
		assert(topOf(deck) > surface, "the deck is under the chocolate")
		near(deck.Position.X, centre.x + V3.BRIDGE.x, "deck x"); near(deck.Position.Z, centre.z + V3.BRIDGE.z, "deck z")
		for i = 1, 2 do
			equal(bridge["Ramp_" .. i]:GetAttribute("Role"), "floor", "ramp " .. i)
			local rail = bridge["Rail_" .. i]
			assert(math.abs(rail.Position.Z - deck.Position.Z) - rail.Size.Z / 2 >= Layout.PATH_WIDTH / 2, "rail " .. i .. " on the path")
		end
	end)

	case("B4: two docks at the layout's stands, tagged, their decks over the surface", function()
		local CollectionService = game:GetService("CollectionService")
		equal(#holder.Docks:GetChildren(), 2, "docks")
		for _, d in ipairs(V3.DOCKS) do
			local dock = holder.Docks:FindFirstChild("Dock_" .. d.id)
			assert(dock, "Dock_" .. d.id)
			near(dock:GetAttribute("StandX"), centre.x + d.standX, "stand x", 0.01)
			near(dock:GetAttribute("StandZ"), centre.z + d.standZ, "stand z", 0.01)
			assert(CollectionService:HasTag(dock, "WildboundCandyRaftDock"), "tag")
			assert(topOf(dock.Deck) > surface, "the dock deck is under the chocolate")
		end
	end)

	case("B5: seven houses you can walk into, each at its spot", function()
		equal(#holder.Houses:GetChildren(), #V3.HOUSES, "houses")
		for _, h in ipairs(V3.HOUSES) do
			local house = holder.Houses:FindFirstChild("House_" .. h.id)
			assert(house, "House_" .. h.id)
			equal(house:GetAttribute("Interior"), true, "interior")
			equal(house:GetAttribute("KitAsset"), h.asset, "asset")
			local floor = house.Floor
			near(floor.Position.X, centre.x + h.x, h.id .. " x", 0.01); near(floor.Position.Z, centre.z + h.z, h.id .. " z", 0.01)
			local l, r = house.WallFrontL, house.WallFrontR
			local gap = (r.Position - l.Position).Magnitude - (l.Size.X + r.Size.X) / 2
			assert(gap >= 6, h.id .. " door " .. gap .. " wide")
			assert(house.Lintel.Position.Y - house.Lintel.Size.Y / 2 - floorTop >= 9, h.id .. " door too low")
			for _, p in ipairs(parts(house)) do
				local d = math.sqrt((p.Position.X - centre.x - h.x) ^ 2 + (p.Position.Z - centre.z - h.z) ^ 2)
				assert(d <= h.r, h.id .. "'s " .. p.Name .. " leaves its footprint")
			end
		end
	end)

	case("B6: mountains stand in their footprints; the waterfall flows into the pool", function()
		for _, m in ipairs(V3.MOUNTAINS) do
			local mountain = holder.Mountains:FindFirstChild("Mountain_" .. m.id)
			assert(mountain, "Mountain_" .. m.id)
			local solid = 0
			for _, p in ipairs(parts(mountain)) do
				if p.CanCollide then solid += 1 end
				local d = math.sqrt((p.Position.X - centre.x - m.x) ^ 2 + (p.Position.Z - centre.z - m.z) ^ 2)
				assert(d + math.max(p.Size.Y, p.Size.Z) / 2 <= m.r + 0.5, m.id .. "'s " .. p.Name .. " leaves its footprint")
			end
			assert(solid >= 2, m.id .. " is not solid")
		end
		local fall = holder.Waterfall
		assert(fall:FindFirstChild("Sheet"), "the placeholder sheet")
		assert(fall:GetAttribute("FlowSpeed") > 0, "FlowSpeed")
		local streaks = 0
		for _, s in ipairs(fall:GetChildren()) do
			if string.sub(s.Name, 1, 7) == "Streak_" then
				streaks += 1
				assert(s:GetAttribute("FlowTop") > s:GetAttribute("FlowBottom"), s.Name .. " flows up")
				local ph = s:GetAttribute("FlowPhase")
				assert(ph >= 0 and ph < 1, s.Name .. " phase")
				equal(s.CanCollide, false, s.Name)
			end
		end
		equal(streaks, V3.WATERFALL.streaks, "streaks")
		assert(holder.River:FindFirstChild("Choco_Pool"), "the placeholder pool")
	end)

	case("B7: the licorice's feet clear the main path; the cake and the platforms are walkable", function()
		local arch = holder.Licorice.LicoriceArch
		assert(arch:GetAttribute("Height") >= 18, "height")
		for _, p in ipairs(parts(arch)) do
			if p.CanCollide then
				local offset = math.abs(p.Position.Z - centre.z - V3.LICORICE.z) - math.max(p.Size.Y, p.Size.Z) / 2
				assert(offset >= Layout.PATH_WIDTH / 2, p.Name .. " stands on the path")
			end
		end
		local cake = holder.Cake.CakeModular
		local walkable = 0
		for _, p in ipairs(parts(cake)) do if p:GetAttribute("Role") == "floor" then walkable += 1 end end
		assert(walkable >= 3, "the cake has tiers and a ramp to walk")
		for i, spec in ipairs(V3.PLATFORMS) do
			local platform = holder.Platforms:FindFirstChild("Platform_" .. i)
			local slab = platform and platform:FindFirstChild("Collision_Slab")
			assert(slab and slab:GetAttribute("Role") == "floor", "platform " .. i .. " walkable")
			assert(topOf(slab) > surface, "platform " .. i .. " under the chocolate")
			near(slab.Position.X, centre.x + spec.x, "platform x", 0.01)
		end
	end)

	case("B8: the filler stands on open ground, off the chocolate", function()
		if not library then return end
		assert(report.filler >= 6, "only " .. report.filler .. " filler props")
		for _, m in ipairs(holder.Filler:GetChildren()) do
			local p = m:GetPivot().Position
			assert(V3.liquidDistance(p.X - centre.x, p.Z - centre.z) > 0, m.Name .. " in the chocolate")
			assert(Layout.routeDistance(p.X - centre.x, p.Z - centre.z) > Layout.PATH_WIDTH / 2, m.Name .. " on a route")
		end
		assert(report.hills >= 1, "no hills")
	end)
	scratch:Destroy()

	-- 2. a stand-in kit house: one coloured "mesh" (a part) and two colliders from a spec of the generated shape
	case("B9: a kit model is placed at scale 1, its meshes never collide, its colliders come from the spec", function()
		local kit = Instance.new("Folder")
		local fake = Instance.new("Model")
		fake.Name = "CV3_SweetHouse"
		local wall = Instance.new("Part")
		wall.Name = "CV3_SweetHouse_Walls"
		wall.Size = Vector3.new(20, 10, 20)
		wall.CFrame = CFrame.new(0, 5, 0)
		wall.CanCollide = true
		wall.Parent = fake
		fake.WorldPivot = CFrame.new()
		fake.Parent = kit
		local spec = { CV3_SweetHouse = {
			size = { 20, 10, 20 },
			pieces = { Walls = { object = "CV3_SweetHouse_Walls", color = "E3A869", role = "visual" } },
			colliders = {
				{ name = "Collision_Floor", shape = "block", pos = { 0, 0.3, 0 }, size = { 20, 0.6, 20 }, orient = { 0, 0, 0 } },
				{ name = "Collision_Wall_Back", shape = "block", pos = { 0, 5, 9.5 }, size = { 20, 10, 1 }, orient = { 0, 0, 0 } },
			},
		} }
		local root = Instance.new("Model")
		local r = V3Builder.layAll(root, { Layout = Layout, V3 = V3, kitV3 = kit, kitSpec = spec, keepOut = {} })
		equal(#r.placeholders, #V3.MOUNTAINS + #V3.HOUSES - 3 + 1 + 1 + #V3.PLATFORMS, "three sweet houses from the kit")
		local h1 = V3.HOUSES[1]
		local house = root[V3.FOLDER].Houses.House_H1
		equal(house:GetAttribute("Placeholder"), false, "kit")
		equal(house:GetAttribute("KitAsset"), "CV3_SweetHouse", "asset")
		local mesh = house.CV3_SweetHouse_Walls
		equal(mesh.CanCollide, false, "the mesh collides"); equal(mesh.CanQuery, false, "the mesh answers rays")
		equal(mesh.Color, Color3.fromRGB(0xE3, 0xA8, 0x69), "colour from the spec")
		local floor, back = house.Collision_Floor, house.Collision_Wall_Back
		equal(floor:GetAttribute("Role"), "floor", "floor role"); equal(back:GetAttribute("Role"), "solid", "wall role")
		equal(floor.Transparency, 1, "invisible collider"); equal(floor.CanCollide, true, "the collider collides")
		local pivot = house:GetPivot()
		near(pivot.X, centre.x + h1.x, "pivot x", 0.01); near(pivot.Z, centre.z + h1.z, "pivot z", 0.01); near(pivot.Y, floorTop, "pivot y", 0.01)
		near((pivot:PointToObjectSpace(back.Position) - Vector3.new(0, 5, 9.5)).Magnitude, 0, "the wall sits in the pivot frame", 0.01)
		local look = pivot.LookVector
		local toJunction = Vector3.new(Layout.JUNCTION.x - h1.x, 0, Layout.JUNCTION.z - h1.z).Unit
		assert(look:Dot(toJunction) > 0.99, "the front faces the junction")
		root:Destroy()
	end)

	case("B10: the generated kit spec covers every v3 asset, colliders well formed", function()
		for _, asset in ipairs(V3.ASSETS) do
			local spec = KitSpec[asset]
			assert(spec, "no spec for " .. asset)
			assert(#spec.colliders >= 1, asset .. " has no collider")
			for _, c in ipairs(spec.colliders) do
				assert(c.shape == "block" or c.shape == "cylinder", asset .. " shape")
				assert(#c.pos == 3 and #c.size == 3 and #c.orient == 3, asset .. " collider fields")
				assert(c.size[1] > 0 and c.size[2] > 0 and c.size[3] > 0, asset .. " collider size")
			end
		end
		assert(KitSpec.CV3_BananaRaft.seat, "the raft's seat anchor")
		assert(KitSpec.CV3_IceCreamMountain_L.water.outlet, "the big mountain's outlet")
		assert(KitSpec.CV3_CakeBase.sockets.ramp_front and KitSpec.CV3_CakeRamp.sockets.high_end, "cake sockets")
		equal(V3Builder.colliderRole("Collision_Stair_03", "solid"), "floor", "stairs are walked")
		equal(V3Builder.colliderRole("Collision_Wall_Back", "solid"), "solid", "walls stop")
	end)

	-- 3. the plan and the tree swap on a scratch copy of a live map
	local function oldTree(into, name, asset, x, z, withRoof)
		local m = Instance.new("Model")
		m.Name = name
		local trunk = Instance.new("Part")
		trunk.Name = "Collision_Trunk"
		trunk.Shape = Enum.PartType.Cylinder
		trunk.Size = Vector3.new(8, 2, 2)
		trunk.CFrame = CFrame.new(centre.x + x, floorTop + 4, centre.z + z) * CFrame.Angles(0, 0, math.rad(90))
		trunk.Anchored, trunk.CanCollide = true, true
		trunk.Parent = m
		local crown = Instance.new("Part")
		crown.Name = "CrownA"
		crown.Shape = Enum.PartType.Ball
		crown.Size = Vector3.new(8, 8, 8)
		crown.CFrame = CFrame.new(centre.x + x, floorTop + 12, centre.z + z)
		crown.Anchored, crown.CanCollide = true, false
		crown.Parent = m
		if withRoof then
			local roof = Instance.new("Part")
			roof.Name = "Roof"
			roof.Shape = Enum.PartType.Cylinder
			roof.Size = Vector3.new(0.4, 13, 13)
			roof.CFrame = CFrame.new(centre.x + x, floorTop + 9.5, centre.z + z) * CFrame.Angles(0, 0, math.rad(90))
			roof.Anchored, roof.CanCollide, roof.CanQuery, roof.Transparency = true, false, true, 1
			roof.Parent = m
		end
		m.WorldPivot = CFrame.new(centre.x + x, floorTop, centre.z + z)
		m:SetAttribute("KitAsset", asset)
		m.Parent = into
		return m
	end

	case("B11: the plan archives props in the chocolate and the old lake; open ground is kept", function()
		local root = Instance.new("Model")
		local cotton = Instance.new("Folder")
		cotton.Name = "CottonTrees"
		cotton.Parent = root
		local wet = oldTree(cotton, "CottonTree_1", "TreeCotton_M", V3.RIVER[3][1], V3.RIVER[3][2], true)
		oldTree(cotton, "CottonTree_2", "TreeCotton_M", -150, 60, true)
		local lake = Instance.new("Folder")
		lake.Name = "Lake"
		lake.Parent = root
		for _, name in ipairs({ "Syrup_1", "Bridge_1" }) do
			local p = Instance.new("Part")
			p.Name = name
			p.Parent = lake
		end
		local plan = V3Builder.plan(root, Layout, V3)
		equal(#plan.archive, 3, "archived")
		equal(plan.archive[1].instance, wet, "the wet tree first")
		equal(plan.archive[1].why, "in the chocolate", "why")
		equal(plan.kept, 1, "kept")
		equal(wet.Parent, cotton, "the plan moves nothing")
		root:Destroy()
	end)

	case("B12: a tree swap keeps the spot and turn, carries La Nube's roof and archives the old tree", function()
		local root = Instance.new("Model")
		local cotton = Instance.new("Folder")
		cotton.Name = "CottonTrees"
		cotton.Parent = root
		local old = oldTree(cotton, "CottonTree_2", "TreeCotton_M", -150, 60, true)
		local roof = old.Roof
		local wet = oldTree(cotton, "CottonTree_1", "TreeCotton_M", V3.RIVER[3][1], V3.RIVER[3][2], false)
		local archived = {}
		local deps = { Layout = Layout, V3 = V3, Builder = Builder, kitV3 = nil, kitSpec = KitSpec, keepOut = {} }
		local dry = V3Builder.swapTrees(root, deps, function() error("a dry run archived") end, true)
		equal(#dry.swapped, 1, "dry: one to swap"); equal(#dry.kept, 1, "dry: the wet one stays")
		equal(root:FindFirstChild(V3.FOLDER), nil, "a dry run builds nothing")
		local r = V3Builder.swapTrees(root, deps, function(instance, why)
			table.insert(archived, { instance = instance, why = why })
			instance.Parent = nil
		end, false)
		equal(#r.swapped, 1, "swapped"); equal(#archived, 1, "archived")
		equal(archived[1].instance, old, "the old tree is archived")
		equal(wet.Parent, cotton, "a tree with no fit stays")
		local tree = root[V3.FOLDER].Trees.Tree_1
		equal(tree:GetAttribute(V3.TREES.attribute), "TreeCotton_M", "marked with the old kind")
		equal(tree:GetAttribute("V3Kind"), "cotton", "kind")
		equal(tree:GetAttribute("KitAsset"), "CV3_TreeCotton", "the new kind")
		local p = tree:GetPivot().Position
		assert(math.abs(p.X - (centre.x - 150)) <= 8 and math.abs(p.Z - (centre.z + 60)) <= 8, "moved too far")
		near(p.Y, floorTop, "on the floor", 0.01)
		equal(roof.Parent, tree, "the roof moved into the new tree")
		local height = V3Builder.measureTree(tree).height
		assert(height >= 16 * V3.TREES.minFactor - 0.5 and height <= 16 + 0.5, "height " .. height)
		root:Destroy()
	end)

	return result
end
