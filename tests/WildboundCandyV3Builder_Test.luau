-- Invoke with require(freshTestClone)(require(freshCandyV3BuilderClone), require(freshCandyV3LayoutClone),
--   require(freshCandyLayoutClone), require(freshCandyBuilderClone), require(freshCandyV3KitSpecClone),
--   require(freshCandyKitClone), ServerStorage.WildboundAssets.CandyKit, { beasts = <WildboundBeasts Source> }). Yields:
--   it builds several times.
-- Caramelo v3 (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md): what WildboundCandyV3Builder lays.
-- Every build goes into a detached scratch Model (never parented into the place), so the live biome is never touched:
-- the placeholder batch (no kit), a batch with a stand-in kit house built from the kit spec's colliders, the plan of
-- what a live map archives, and the tree swap.
return function(V3Builder, V3, Layout, Builder, KitSpec, Kit, library, sources)
	local CollectionService = game:GetService("CollectionService")
	local beasts = type(sources) == "table" and sources.beasts or ""
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
	local function has(source, needle, label)
		assert(type(source) == "string" and string.find(source, needle, 1, true), (label or "missing") .. ": " .. needle)
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
		-- Deliberately changed (V3 review): the placeholder hills are listed too (so a kit upgrade finds them)
		equal(#report.placeholders, #V3.MOUNTAINS + #V3.HOUSES + 1 + 1 + #V3.PLATFORMS + report.hills, "placeholders")
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
		-- Deliberately changed (V3 review M3): the rails are runs between gaps (Rail_<side>_<run>), and every gap has a
		-- walkable side ramp down to the floor on both sides
		local B = V3.BRIDGE
		local rails, sideRamps = 0, 0
		for _, p in ipairs(bridge:GetChildren()) do
			if string.sub(p.Name, 1, 5) == "Rail_" then
				rails += 1
				equal(p:GetAttribute("Role"), "solid", p.Name)
				assert(math.abs(p.Position.Z - deck.Position.Z) - p.Size.Z / 2 >= Layout.PATH_WIDTH / 2, p.Name .. " on the path")
				for _, gx in ipairs(B.gaps) do
					local gapLeft, gapRight = centre.x + B.x + gx - B.gapWidth / 2, centre.x + B.x + gx + B.gapWidth / 2
					local railLeft, railRight = p.Position.X - p.Size.X / 2, p.Position.X + p.Size.X / 2
					assert(railRight <= gapLeft + 1e-3 or railLeft >= gapRight - 1e-3, p.Name .. " closes a gap")
				end
			elseif string.sub(p.Name, 1, 9) == "SideRamp_" then
				sideRamps += 1
				equal(p:GetAttribute("Role"), "floor", p.Name)
				assert(p.Size.X >= B.gapWidth - 1e-3, p.Name .. " narrower than its gap")
			end
		end
		equal(rails, 2 * (#B.gaps + 1), "rail runs")
		equal(sideRamps, 2 * #B.gaps, "side ramps")
		for i = 1, 2 do equal(bridge["Ramp_" .. i]:GetAttribute("Role"), "floor", "ramp " .. i) end
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
			-- V3 review m6: the deck stops short of the tip, where the docked hull floats
			local tip = Vector3.new(centre.x + d.tipX, 0, centre.z + d.tipZ)
			local deck = dock.Deck
			local farEnd = (deck.CFrame * CFrame.new(0, 0, -deck.Size.Z / 2)).Position
			assert((Vector3.new(farEnd.X, 0, farEnd.Z) - tip).Magnitude >= V3.DOCK.tipGap - 0.01, "the deck reaches the hull")
			near(dock:GetAttribute("DeckY"), topOf(deck), "DeckY", 0.01)
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
	-- V3 review M1: creatures follow a player into a house instead of landing on its roof; nothing lands on a summit.
	case("B13: houses and the cake are tagged pass, mountains, hills and the licorice overhead; the beasts read the tags", function()
		for _, house in ipairs(holder.Houses:GetChildren()) do
			assert(CollectionService:HasTag(house, V3.BEAST_PASS_TAG), house.Name .. " is not tagged pass")
		end
		assert(CollectionService:HasTag(holder.Cake.CakeModular, V3.BEAST_PASS_TAG), "the cake")
		for _, m in ipairs(holder.Mountains:GetChildren()) do
			assert(CollectionService:HasTag(m, V3.BEAST_OVERHEAD_TAG), m.Name .. " is not tagged overhead")
		end
		for _, m in ipairs(holder.Filler:GetChildren()) do
			if m:GetAttribute("Hill") then assert(CollectionService:HasTag(m, V3.BEAST_OVERHEAD_TAG), m.Name .. " (hill)") end
		end
		assert(CollectionService:HasTag(holder.Licorice.LicoriceArch, V3.BEAST_OVERHEAD_TAG), "the licorice")
		-- every elevated collider of a house is inside a tagged model (the roof the review saw a critter land on)
		for _, house in ipairs(holder.Houses:GetChildren()) do
			for _, p in ipairs(parts(house)) do
				if p.CanCollide and p.Position.Y - p.Size.Y / 2 > floorTop + 3 then
					assert(p:FindFirstAncestorWhichIsA("Model") == house, p.Name .. " outside its house model")
				end
			end
		end
		if beasts ~= "" then
			has(beasts, "CollectionService:GetTagged(\"WildboundBeastPass\")", "the beasts skip houses for ground, walls and cover")
			has(beasts, "CollectionService:GetTagged(\"WildboundBeastOverhead\")", "the beasts never take a summit as ground")
			has(beasts, "params.FilterDescendantsInstances = ground", "the ground ray uses both")
			has(beasts, "overlap.FilterDescendantsInstances = exclude", "a landing still refuses the inside of a mountain")
		end
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
		-- Deliberately changed (V3 review): placeholder hills are listed
		equal(#r.placeholders, #V3.MOUNTAINS + #V3.HOUSES - 3 + 1 + 1 + #V3.PLATFORMS + r.hills, "three sweet houses from the kit")
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

	-- V3 review M4: the filler and the hills keep off the props already on a live map.
	case("B14: the filler keeps off props already standing", function()
		local first = Instance.new("Model")
		local r1 = V3Builder.layAll(first, { Layout = Layout, V3 = V3, kitSpec = KitSpec, Kit = Kit, library = library, keepOut = {} })
		local spots = {}
		for _, m in ipairs(first[V3.FOLDER].Filler:GetChildren()) do
			local p = m:GetPivot().Position
			table.insert(spots, Vector3.new(p.X, floorTop, p.Z))
		end
		assert(#spots >= 3, "too few filler props to test with: " .. #spots .. " (" .. r1.filler .. ")")
		first:Destroy()
		local root = Instance.new("Model")
		local gumdrops = Instance.new("Folder")
		gumdrops.Name = "Gumdrops"
		gumdrops.Parent = root
		for i, at in ipairs(spots) do
			local m = Instance.new("Model")
			m.Name = "Gumdrop_" .. i
			local p = Instance.new("Part")
			p.Name = "Collision_Drop"
			p.Size = Vector3.new(2, 2, 2)
			p.CFrame = CFrame.new(at + Vector3.new(0, 1, 0))
			p.Anchored, p.CanCollide = true, true
			p.Parent = m
			m.WorldPivot = CFrame.new(at)
			m:SetAttribute("KitAsset", "GumdropBush_A")
			m.Parent = gumdrops
		end
		local existing = V3Builder.existingProps(root, Layout)
		equal(#existing, #spots, "existing props found")
		V3Builder.layAll(root, { Layout = Layout, V3 = V3, kitSpec = KitSpec, Kit = Kit, library = library, keepOut = {} })
		for _, m in ipairs(root[V3.FOLDER].Filler:GetChildren()) do
			local p = m:GetPivot().Position
			local reach = m:GetAttribute("HillRadius") or V3.FILLER.reach
			for _, e in ipairs(existing) do
				local d = math.sqrt((p.X - centre.x - e.x) ^ 2 + (p.Z - centre.z - e.z) ^ 2)
				assert(d >= e.reach + reach - 0.01, m.Name .. " stands on " .. e.name)
			end
		end
		root:Destroy()
	end)

	-- V3 review M2: the kit arrives after a placeholder run.
	case("B15: a kit upgrade lays the kit over the placeholders in place, keeps La Nube's roof, and runs once", function()
		local root = Instance.new("Model")
		local cotton = Instance.new("Folder")
		cotton.Name = "CottonTrees"
		cotton.Parent = root
		local old = oldTree(cotton, "CottonTree_2", "TreeCotton_M", -150, 60, true)
		local roof = old.Roof
		local base = { Layout = Layout, V3 = V3, Builder = Builder, kitSpec = KitSpec, keepOut = {} }
		V3Builder.layAll(root, base)
		V3Builder.swapTrees(root, base, function(instance) instance.Parent = nil end, false)
		local placeholderTree = root[V3.FOLDER].Trees.Tree_1
		equal(placeholderTree:GetAttribute("Placeholder"), true, "a placeholder tree first")
		local treePivot = placeholderTree:GetPivot()
		-- the kit arrives: a sweet house and a cotton tree
		local kit = Instance.new("Folder")
		local house = Instance.new("Model")
		house.Name = "CV3_SweetHouse"
		local wall = Instance.new("Part")
		wall.Name = "CV3_SweetHouse_Walls"
		wall.Size = Vector3.new(20, 10, 20)
		wall.CFrame = CFrame.new(0, 5, 0)
		wall.Parent = house
		house.WorldPivot = CFrame.new()
		house.Parent = kit
		local tree = Instance.new("Model")
		tree.Name = "CV3_TreeCotton"
		local crown = Instance.new("Part")
		crown.Name = "CV3_TreeCotton_Crown"
		crown.Shape = Enum.PartType.Ball
		crown.Size = Vector3.new(14, 14, 14)
		crown.CFrame = CFrame.new(0, 18.8, 0)
		crown.Parent = tree
		tree.WorldPivot = CFrame.new()
		tree.Parent = kit
		local spec = setmetatable({ CV3_SweetHouse = {
			size = { 20, 10, 20 }, pieces = {},
			colliders = { { name = "Collision_Floor", shape = "block", pos = { 0, 0.3, 0 }, size = { 20, 0.6, 20 }, orient = { 0, 0, 0 } } },
		} }, { __index = KitSpec })
		local archived = {}
		local deps = { Layout = Layout, V3 = V3, Builder = Builder, kitV3 = kit, kitSpec = spec, keepOut = {} }
		local dry = V3Builder.upgradePlaceholders(root, deps, function() error("a dry run archived") end, true)
		equal(#dry.upgraded, 4, "dry: three sweet houses and the tree")
		local r = V3Builder.upgradePlaceholders(root, deps, function(instance, why)
			table.insert(archived, instance)
			instance.Parent = nil
		end, false)
		equal(#r.upgraded, 4, "upgraded"); equal(#archived, 4, "archived, never destroyed")
		assert(#r.waiting > 0, "the rest waits for its kit")
		local h1 = root[V3.FOLDER].Houses.House_H1
		equal(h1:GetAttribute("Placeholder"), false, "the house is the kit now")
		assert(CollectionService:HasTag(h1, V3.BEAST_PASS_TAG), "still tagged pass")
		equal(h1:GetAttribute("HouseId"), "H1", "same house")
		local kitTree = root[V3.FOLDER].Trees.Tree_1
		equal(kitTree:GetAttribute("Placeholder"), false, "the tree is the kit now")
		equal(kitTree:GetAttribute(V3.TREES.attribute), "TreeCotton_M", "it keeps its old kind")
		equal(roof.Parent, kitTree, "La Nube's roof moved into the kit tree")
		near((kitTree:GetPivot().Position - treePivot.Position).Magnitude, 0, "same spot", 0.01)
		assert(kitTree:FindFirstChild("Collision_Trunk"), "the kit tree has its spec collider")
		local again = V3Builder.upgradePlaceholders(root, deps, function() error("a second run archived") end, false)
		equal(#again.upgraded, 0, "idempotent")
		root:Destroy()
	end)

	return result
end
