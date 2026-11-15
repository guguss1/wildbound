-- Invoke with require(freshTestClone)(require(freshBuilderClone), require(freshLayoutClone), require(freshKitClone),
-- ServerStorage.WildboundAssets.CandyKit). Yields: it builds twice.
-- Caramelo biome blockout (odd/tasks/caramelo-bioma.md, T1, S2 S4 S5): what WildboundCandyBuilder must produce. Every
-- build goes into a detached scratch folder that is destroyed at the end, so the place and the live biome are never
-- touched. Checks the instances a player and a beast would meet: floor, corridors, collisions, nests, boss limits.
return function(Builder, Layout, Kit, library)
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
		assert(actual == expected, (label and label .. ": " or "") .. "Expected " .. tostring(expected) .. ", got "
			.. tostring(actual))
	end
	local function near(actual, expected, label, tolerance)
		assert(type(actual) == "number" and math.abs(actual - expected) <= (tolerance or 1e-3),
			(label and label .. ": " or "") .. "Expected about " .. tostring(expected) .. ", got " .. tostring(actual))
	end
	local top, centre = Layout.FLOOR_TOP, Layout.CENTRE
	-- Horizontal reach and half height of a part in world axes (round shapes are upright here).
	local function footprint(p)
		local cf, s = p.CFrame, p.Size
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local hx = (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2
		local hy = (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2
		local hz = (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
		if p:IsA("Part") and p.Shape ~= Enum.PartType.Block then return math.max(hx, hz), hy end
		return math.sqrt(hx * hx + hz * hz), hy
	end
	local function at(instance, p, y, label)
		local position = instance:IsA("Model") and instance:GetPivot().Position or instance.Position
		near(position.X, centre.x + p.x, label .. " x")
		near(position.Z, centre.z + p.z, label .. " z")
		if y then near(position.Y, y, label .. " y") end
	end

	-- The first build goes into a WorldModel parked in ServerStorage: spatial queries need it inside the DataModel
	-- (detached, every query met nothing). It is destroyed before the suite returns.
	local scratch, again = Instance.new("WorldModel"), Instance.new("Folder")
	scratch.Name = "CandyBuilderTestScratch"
	scratch.Parent = game:GetService("ServerStorage")
	local okBuild, root = pcall(Builder.build, scratch, Layout, Kit, library)
	if not okBuild then
		result.failed += 1
		table.insert(result.messages, "build: " .. tostring(root))
		scratch:Destroy()
		return result
	end
	local parts = {}
	for _, d in ipairs(root:GetDescendants()) do if d:IsA("BasePart") then table.insert(parts, d) end end

	case("S4: the build is one versioned Candy_ model that says what it is", function()
		assert(root:IsA("Model"), "root is not a Model")
		equal(root.Name, Layout.ROOT_NAME, "name")
		equal(root.Parent, scratch, "parent")
		equal(root:GetAttribute("Biome"), "Caramelo", "Biome")
		equal(root:GetAttribute("Replaces"), "PraderaArcoiris", "Replaces")
		equal(root:GetAttribute("LayoutVersion"), Layout.VERSION, "LayoutVersion")
		equal(root:GetAttribute("Seed"), Layout.SEED, "Seed")
		equal(root:GetAttribute("Blockout"), true, "Blockout")
		assert(CollectionService:HasTag(root, "WildboundCandyBiome"), "missing biome tag")
		assert(not pcall(Builder.build, scratch, Layout, Kit, library), "a second build in the same parent was accepted")
		equal(#scratch:GetChildren(), 1, "children after the refused build")
	end)

	case("S4: spawns stay off and the model carries no code", function()
		equal(root:GetAttribute("SpawnsEnabled"), false, "SpawnsEnabled")
		for _, d in ipairs(root:GetDescendants()) do
			assert(not d:IsA("LuaSourceContainer"), "script in the blockout: " .. d.Name)
			assert(not d:IsA("SpawnLocation"), "spawn in the blockout: " .. d.Name)
		end
	end)

	case("S4: optimised primitives, all anchored, within the part budget", function()
		equal(root:GetAttribute("PartCount"), #parts, "PartCount")
		assert(#parts >= 100 and #parts <= Builder.MAX_PARTS, "part count " .. #parts)
		for _, p in ipairs(parts) do
			local kitMesh = p:IsA("MeshPart") and p.Parent:GetAttribute("KitAsset") ~= nil
			assert(p:IsA("Part") or kitMesh, p.Name .. " is neither a primitive nor a kit mesh")
			if kitMesh then
				local role = p:GetAttribute("Role")
				assert(role == "decor" or role == "canopy", p:GetFullName() .. ": a kit mesh must never collide")
			end
			equal(p.Anchored, true, p.Name .. " Anchored")
			equal(p.CanTouch, false, p.Name .. " CanTouch")
		end
	end)

	case("S4: collisions follow the role of each part", function()
		local roles = { floor = { true, true }, solid = { true, true }, decor = { false, false }, canopy = { false, true },
			marker = { false, false } }
		for _, p in ipairs(parts) do
			local rule = roles[p:GetAttribute("Role")]
			assert(rule, p.Name .. " has no role")
			equal(p.CanCollide, rule[1], p.Name .. " CanCollide")
			equal(p.CanQuery, rule[2], p.Name .. " CanQuery")
			if p:GetAttribute("Role") == "marker" then equal(p.Transparency, 1, p.Name .. " visible marker") end
		end
	end)

	case("S2: the floor fills the plot at the old ground level", function()
		local floor = root.Ground.Floor
		equal(floor.Size, Vector3.new(Layout.HALF * 2, 1, Layout.HALF * 2), "size")
		at(floor, { x = 0, z = 0 }, top - 0.5, "floor")
		equal(floor:GetAttribute("Role"), "floor", "role")
	end)

	case("S4: the corridors stay clear for eight players and for beasts", function()
		-- Nothing solid may reach into a path: a box as wide as the path and 7 studs tall is swept along every route.
		-- (The first version compared centres against a circle, which a long rail beside the path cannot pass or fail fairly.)
		local swept, control = 0, scratch:GetPartBoundsInBox(root.GranTorta:GetPivot(), Vector3.new(4, 4, 4), OverlapParams.new())
		assert(#control > 0, "the control query inside the Torta met nothing, so the sweep proves nothing")
		for _, name in ipairs(Layout.ROUTE_ORDER) do
			local points = Layout.ROUTES[name]
			for i = 1, #points - 1 do
				local a = Vector3.new(centre.x + points[i].x, top + 4.2, centre.z + points[i].z)
				local b = Vector3.new(centre.x + points[i + 1].x, top + 4.2, centre.z + points[i + 1].z)
				local box = Vector3.new(Layout.PATH_WIDTH - 0.1, 7, (b - a).Magnitude)
				for _, p in ipairs(scratch:GetPartBoundsInBox(CFrame.lookAt((a + b) / 2, b), box, OverlapParams.new())) do
					assert(p:GetAttribute("Role") ~= "solid", p:GetFullName() .. " reaches into the " .. name .. " path")
				end
				swept += 1
			end
		end
		equal(swept, 13, "route segments swept")
		local paved = 0
		for _, p in ipairs(root.Paths:GetChildren()) do
			equal(p:GetAttribute("Role"), "floor", p.Name .. " role")
			if p.Shape == Enum.PartType.Block then
				equal(p.Size.X, Layout.PATH_WIDTH, p.Name .. " width")
				paved += p.Size.Z
			end
		end
		local planned = 0
		for _, name in ipairs(Layout.ROUTE_ORDER) do planned += Layout.routeLength(name) end
		near(paved, planned, "paved length")
	end)

	case("S5: twelve candidate nests with their rarity, live per the layout flag (CE1)", function()
		local nests = root.Nests:GetChildren()
		equal(#nests, #Layout.NESTS, "nests")
		for _, spec in ipairs(Layout.NESTS) do
			local nest = root.Nests:FindFirstChild("Nest_" .. spec.id)
			assert(nest and nest:IsA("Model"), "missing Nest_" .. spec.id)
			assert(CollectionService:HasTag(nest, "WildboundCandyNestCandidate"), spec.id .. " tag")
			equal(nest:GetAttribute("NestId"), spec.id, "NestId")
			equal(nest:GetAttribute("Rarity"), spec.rarity, spec.id .. " Rarity")
			equal(nest:GetAttribute("EventOnly"), spec.eventOnly, spec.id .. " EventOnly")
			equal(nest:GetAttribute("Candidate"), true, spec.id .. " Candidate")
			-- Deliberately changed (CE1, layout NESTS_ENABLED): every nest but the event-only legendary one is live.
			equal(nest:GetAttribute("Enabled"), Layout.NESTS_ENABLED == true and not spec.eventOnly, spec.id .. " Enabled")
			local base = nest.PrimaryPart
			assert(base and base.Name == "Collision_Bowl", spec.id .. " primary part")
			at(base, spec, nil, spec.id)
			local reach, half = footprint(base)
			assert(reach * 2 >= 4 and reach * 2 <= 6, spec.id .. " diameter " .. reach * 2)
			assert(half * 2 >= 2 and half * 2 <= 3, spec.id .. " height " .. half * 2)
			near(base.Position.Y - half, top, spec.id .. " sits on the floor")
		end
	end)

	case("S4: the boss territory has a marked limit and nothing to snag on", function()
		local zone = root.Boss.BossTerritory
		equal(zone:GetAttribute("Role"), "marker", "role")
		equal(zone:GetAttribute("Radius"), Layout.BOSS.territoryRadius, "Radius")
		equal(zone:GetAttribute("Enabled"), false, "Enabled")
		at(zone, Layout.BOSS, nil, "territory")
		local reach = footprint(zone)
		near(reach, Layout.BOSS.territoryRadius, "zone size")
		local posts = 0
		for _, p in ipairs(root.Boss:GetChildren()) do
			if string.sub(p.Name, 1, 9) == "LimitPost" then
				posts += 1
				equal(p.CanCollide, false, p.Name .. " collides")
				near(Layout.flat(p.Position.X - centre.x, p.Position.Z - centre.z, Layout.BOSS.x, Layout.BOSS.z),
					Layout.BOSS.territoryRadius, p.Name .. " on the limit")
			end
		end
		assert(posts >= 8, "limit posts " .. posts)
		for _, p in ipairs(parts) do
			local inside = Layout.flat(p.Position.X - centre.x, p.Position.Z - centre.z, Layout.BOSS.x, Layout.BOSS.z)
				< Layout.BOSS.territoryRadius - 1
			if inside and p:GetAttribute("Role") == "solid" then
				assert(p:IsDescendantOf(root.GranTorta) or p:IsDescendantOf(root.Nests), p:GetFullName() .. " blocks the boss")
			end
		end
	end)

	case("S4: the Gran Torta is the landmark and the entrance names the biome", function()
		local torta = root.GranTorta
		local widest, highest = 0, 0
		for _, p in ipairs(torta:GetChildren()) do
			local reach, half = footprint(p)
			if p:GetAttribute("Role") == "solid" then widest = math.max(widest, reach) end
			highest = math.max(highest, p.Position.Y + half)
		end
		near(widest, Layout.TORTA.radius, "Torta radius", 0.02)
		assert(highest - top >= 40, "Torta height " .. highest - top)
		local label = root.Entrance.Sign:FindFirstChildWhichIsA("TextLabel", true)
		assert(label, "no sign text")
		equal(label.Text, "REINO DE CARAMELO", "sign")
		local gui = label:FindFirstAncestorWhichIsA("SurfaceGui")
		equal(gui.Face, Enum.NormalId.Left, "sign faces the hub")
		-- The words stay between the two posts that hold the board (seen clipped in the first walk test).
		local board, north, south = root.Entrance.Sign, root.Entrance.PostNorth, root.Entrance.PostSouth
		local gap = math.abs(south.Position.Z - north.Position.Z) - footprint(north) * 2
		assert(label.Size.X.Scale * board.Size.Z <= gap, "the posts cover the sign text")
		near(label.Position.X.Scale * 2 + label.Size.X.Scale, 1, "sign text centred")
	end)

	case("S4: the portal is a switched-off position with its proposed rules", function()
		local portal = root.Portal
		at(portal, Layout.PORTAL, nil, "portal")
		equal(portal:GetAttribute("Enabled"), false, "Enabled")
		equal(portal:GetAttribute("QuietSeconds"), Layout.PORTAL.quietSeconds, "QuietSeconds")
		equal(portal:GetAttribute("ChannelSeconds"), Layout.PORTAL.channelSeconds, "ChannelSeconds")
		equal(portal:GetAttribute("CooldownSeconds"), Layout.PORTAL.cooldownSeconds, "CooldownSeconds")
	end)

	case("S4: markers name the walk test stops", function()
		local main = Layout.ROUTES.main
		local stops = { Entrance = Layout.ENTRANCE, Fork = Layout.FORK, Junction = Layout.JUNCTION, FirstNest = Layout.NESTS[1],
			TortaPlaza = main[#main], BossHome = Layout.BOSS.home, Portal = Layout.PORTAL }
		for name, p in pairs(stops) do
			local marker = root.Markers:FindFirstChild(name)
			assert(marker, "missing marker " .. name)
			equal(marker:GetAttribute("Role"), "marker", name .. " role")
			at(marker, p, top + 1, name)
		end
	end)

	case("cotton trees give cover on the left route and keep La Nube's roof rule", function()
		local trees = root.CottonTrees:GetChildren()
		assert(#trees >= 24, "trees " .. #trees)
		local kinds = {}
		for _, tree in ipairs(trees) do kinds[tostring(tree:GetAttribute("KitAsset"))] = true end
		assert(kinds.TreeCotton_S and kinds.TreeCotton_M and kinds.TreeCotton_L, "the three cotton tree sizes are not all used")
		local left = 0
		for _, tree in ipairs(trees) do
			local roofs = 0
			for _, p in ipairs(tree:GetChildren()) do
				if CollectionService:HasTag(p, "WildboundRoof") then
					roofs += 1
					equal(p:GetAttribute("Role"), "canopy", tree.Name .. " roof role")
					-- the kit crowns are narrower than the blockout's canopy: an invisible disc keeps the cover it gave
					equal(p.Transparency, 1, tree.Name .. " roof is a visible part")
					assert(math.max(p.Size.Y, p.Size.Z) >= 13, tree.Name .. " roof narrower than the blockout canopy")
					assert(p.Position.Y - top >= 6, tree.Name .. " roof below head height")
				end
			end
			equal(roofs, 1, tree.Name .. " roofs")
			local pivot = tree:GetPivot().Position
			local x, z = pivot.X - centre.x, pivot.Z - centre.z
			if z < 0 then left += 1 end
			assert(Layout.flat(x, z, Layout.BOSS.x, Layout.BOSS.z) >= Layout.BOSS.territoryRadius, tree.Name .. " in the territory")
			assert(Layout.depth(x, z) >= 0, tree.Name .. " outside the plot")
		end
		assert(left > #trees - left, "the left route has no more cover than the right")
	end)

	case("the same seed builds the same biome", function()
		local second = Builder.build(again, Layout, Kit, library)
		equal(second:GetAttribute("PartCount"), root:GetAttribute("PartCount"), "PartCount")
		local function signature(model)
			local list = {}
			for _, tree in ipairs(model.CottonTrees:GetChildren()) do
				local p = tree:GetPivot().Position
				table.insert(list, string.format("%s %.2f %.2f", tree.Name, p.X, p.Z))
			end
			table.sort(list)
			return table.concat(list, ";")
		end
		equal(signature(second), signature(root), "tree positions")
	end)

	scratch:Destroy()
	again:Destroy()
	return result
end
