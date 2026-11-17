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
		-- Deliberately changed (GT): 13 -> 14 segments (the main route gained the avenue to the Torta's plaza)
		equal(swept, 14, "route segments swept")
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

	case("S4: the portal is a live position with its rules (CE3: switched on)", function()
		local portal = root.Portal
		at(portal, Layout.PORTAL, nil, "portal")
		equal(portal:GetAttribute("Enabled"), Layout.PORTAL.enabled, "Enabled")
		equal(portal:GetAttribute("Enabled"), true, "on since CE3")
		equal(portal:GetAttribute("QuietSeconds"), Layout.PORTAL.quietSeconds, "QuietSeconds")
		equal(portal:GetAttribute("ChannelSeconds"), Layout.PORTAL.channelSeconds, "ChannelSeconds")
		equal(portal:GetAttribute("CooldownSeconds"), Layout.PORTAL.cooldownSeconds, "CooldownSeconds")
	end)

	case("CE3: syncPortal applies the layout's portal flag to an existing build, nothing else", function()
		local portal = root.Portal
		portal:SetAttribute("Enabled", false)
		local pivot = portal:GetPivot()
		equal(Builder.syncPortal(root, Layout), 1, "one change")
		equal(portal:GetAttribute("Enabled"), true, "on")
		equal(Builder.syncPortal(root, Layout), 0, "a second sync changes nothing")
		assert((portal:GetPivot().Position - pivot.Position).Magnitude < 1e-6, "not moved")
		assert(not pcall(Builder.syncPortal, Instance.new("Folder"), Layout), "a root without a Portal is an error")
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

	-- CH (owner, 2026-11-16: the Caramelo trees leafier and bigger). Every tree of the build, found by its kit asset.
	local TRUNK_MESH = { Trunk = true, StickA = true, StickB = true }
	local function trees()
		local list = {}
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") and type(Builder.TREE_SCALE) == "table" and Builder.TREE_SCALE[d:GetAttribute("KitAsset")] then
				table.insert(list, d)
			end
		end
		return list
	end
	-- Horizontal reach of a part from its centre: a mesh or a round part counts its wider half-side, a block its corner.
	-- Measured in its tree's upright pivot frame, as the builder measures (a world-axis box of a turned, tilted part,
	-- such as a tilted lollipop's stick, reads up to about 0.4 studs wider than the part reaches).
	local function spread(p)
		local cf, s = p.Parent:GetPivot().Rotation:ToObjectSpace(p.CFrame), p.Size
		local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
		local hx = (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2
		local hy = (math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2
		local hz = (math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
		if p:IsA("Part") and p.Shape == Enum.PartType.Block then return math.sqrt(hx * hx + hz * hz), hy end
		return math.max(hx, hz), hy
	end

	case("CH-T1: every Caramelo tree is grown 1.5 to 1.8 times about its foot, the leafy crowns a little more", function()
		assert(type(Builder.TREE_SCALE) == "table", "no Builder.TREE_SCALE")
		for asset, f in pairs(Builder.TREE_SCALE) do
			assert(Kit.SPEC[asset], asset .. " is not a kit asset")
			assert(f >= 1.5 and f <= 1.8, asset .. " factor " .. f)
		end
		assert(Builder.CANOPY_BOOST > 1 and Builder.CANOPY_BOOST <= 1.25, "canopy boost " .. tostring(Builder.CANOPY_BOOST))
		local list, kinds = trees(), {}
		assert(#list >= 24 + 10 + 2, "grown trees " .. #list)
		for _, tree in ipairs(list) do
			local asset = tree:GetAttribute("KitAsset")
			kinds[asset] = true
			local f = tree:GetAttribute(Builder.TREE_ATTRIBUTE)
			assert(type(f) == "number" and f >= Builder.TREE_CLEAR.minFactor - 1e-6 and f <= Builder.TREE_SCALE[asset] + 1e-6,
				tree:GetFullName() .. " factor " .. tostring(f))
			-- the scale the builder gave it before growing: 1, the entrance pair 1.5, the cookie and cream trees 0.9 to 1.1
			local base = tree:GetScale() / f
			assert(base >= 0.9 - 1e-3 and base <= 1.5 + 1e-3, tree:GetFullName() .. " base scale " .. base)
			near(tree:GetPivot().Y, top, tree:GetFullName() .. " foot on the floor")
			local prefab = library:FindFirstChild(asset)
			for _, piece in ipairs(tree:GetChildren()) do
				local source = prefab:FindFirstChild(piece.Name)
				if piece:IsA("BasePart") and source and source:IsA("BasePart") then
					local crown = Builder.LEAFY[asset] and not TRUNK_MESH[piece.Name] and string.sub(piece.Name, 1, 10) ~= "Collision_"
					near(piece.Size.X / source.Size.X, tree:GetScale() * (crown and Builder.CANOPY_BOOST or 1),
						tree:GetFullName() .. "." .. piece.Name .. " growth", 2e-3)
				end
			end
			local roof = tree:FindFirstChild("Roof")
			if roof then
				-- La Nube's cover keeps the blockout's width: only its height follows the crown
				near(roof.Size.Y, Builder.ROOF_DIAMETER, tree.Name .. " roof width")
				near(roof.Size.Z, Builder.ROOF_DIAMETER, tree.Name .. " roof depth")
			end
		end
		for asset in pairs(Builder.TREE_SCALE) do assert(kinds[asset], "no grown " .. asset) end
	end)

	case("CH-T2: no tree trunk or roof on a route, a nest, the stair or the plaza, and no low crown over a route or a nest", function()
		local keepOut, nests = Builder.treeKeepOut(Layout), Builder.treeNests(Layout)
		assert(#nests >= #Layout.NESTS, "the clearance does not read Layout.NESTS")
		for _, spec in ipairs(Layout.NESTS) do
			local seen = false
			for _, n in ipairs(nests) do if n.id == spec.id then seen = true end end
			assert(seen, "nest " .. spec.id .. " is not cleared")
		end
		-- the boss plaza covers the whole stair, so a tree off the plaza is off the stair
		local outer = 0
		for _, s in ipairs(Layout.stairSteps()) do
			outer = math.max(outer, Layout.flat(s.x, s.z, Layout.TORTA.x, Layout.TORTA.z) + Layout.TOWER.stair.width)
		end
		assert(outer < Layout.BOSS.plazaRadius, "the stair reaches past the plaza")
		local C, half = Builder.TREE_CLEAR, Layout.PATH_WIDTH / 2
		for _, tree in ipairs(trees()) do
			local pivot = tree:GetPivot().Position
			local ok, why = Builder.treeFits(Layout, pivot.X - centre.x, pivot.Z - centre.z, Builder.measureTree(tree), keepOut)
			assert(ok, tree:GetFullName() .. ": " .. tostring(why))
			-- the same rule part by part, without the builder's measure
			for _, p in ipairs(tree:GetChildren()) do
				if p:IsA("BasePart") then
					local reach, halfY = spread(p)
					local px, pz = p.Position.X - centre.x, p.Position.Z - centre.z
					local low = p.Position.Y - halfY - top
					local query = p.CanCollide or p.CanQuery
					local road = Layout.routeDistance(px, pz) - reach
					if p.CanCollide then
						assert(road >= half + C.trunkMargin - 1e-3, p:GetFullName() .. " collides " .. road .. " studs from a route centre")
					elseif not query then
						local allowed = low >= C.headroom and C.overhang or 0
						assert(road >= half - allowed - 1e-3, p:GetFullName() .. " hangs over a route (bottom " .. low .. ")")
					end
					for _, n in ipairs(nests) do
						local d = Layout.flat(px, pz, n.x, n.z) - reach
						if query then
							assert(d >= C.nestTrunk - 1e-3, p:GetFullName() .. " is " .. d .. " studs from nest " .. n.id)
						elseif low < C.nestHeadroom then
							assert(d >= C.nestRadius - 1e-3, p:GetFullName() .. " hangs low over nest " .. n.id)
						end
					end
					assert(Layout.flat(px, pz, Layout.BOSS.x, Layout.BOSS.z) - reach >= Layout.BOSS.plazaRadius - 1e-3,
						p:GetFullName() .. " reaches over the boss plaza")
					for _, spot in ipairs(Layout.KEEP_CLEAR or {}) do
						assert(Layout.flat(px, pz, spot.x, spot.z) - reach >= spot.r - 1e-3, p:GetFullName() .. " in " .. spot.why)
					end
					if query then
						for _, k in ipairs(keepOut) do
							assert(Layout.flat(px, pz, k.x, k.z) - reach >= k.r - 1e-3, p:GetFullName() .. " on " .. tostring(k.why))
						end
					end
				end
			end
		end
	end)

	case("CH-T3: growing adds no part; about +50 % trees, no tree lost for room, and the part growth stays moderate", function()
		local fluff = Kit.fluff and Kit.FLUFF_COUNT or 0
		local E = Builder.EXTRA_TREES
		local count = { cotton = 0, TreeCookie = 0, TreeCream = 0 }
		local base, extra, extraParts = 0, 0, 0
		-- Deliberately changed (GT, cake move): the centre backfill's trees (Builder.syncCentre, CENTRE_ATTRIBUTE) are
		-- counted apart, neither base nor extra trees
		local centreCotton = 0
		for _, tree in ipairs(trees()) do
			local asset = tree:GetAttribute("KitAsset")
			local centreFill = tree:GetAttribute(Builder.CENTRE_ATTRIBUTE) ~= nil
			if centreFill then
				if string.sub(asset, 1, 11) == "TreeCotton_" then centreCotton += 1 end
			elseif tree:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE) then
				extra += 1
				for _, d in ipairs(tree:GetDescendants()) do if d:IsA("BasePart") then extraParts += 1 end end
			else
				base += 1
			end
			local parts, expected = 0, 0
			for _, d in ipairs(tree:GetDescendants()) do if d:IsA("BasePart") then parts += 1 end end
			for _, d in ipairs(library:FindFirstChild(asset):GetDescendants()) do if d:IsA("BasePart") then expected += 1 end end
			if string.sub(asset, 1, 11) == "TreeCotton_" then
				expected += 1 + fluff -- the Roof and the fluff blobs, as before the change
				if not centreFill then count.cotton += 1 end
			elseif count[asset] and not centreFill then
				count[asset] += 1
			end
			equal(parts, expected, tree:GetFullName() .. " parts")
		end
		equal(root:GetAttribute("TreesSkipped"), 0, "trees skipped for lack of room")
		-- deliberately changed (owner: more trees): cotton 32 -> 48, cookie and cream 5 -> 8 each
		equal(count.cotton, 32 + E.cottonLeft + E.cottonRight, "cotton trees")
		equal(count.TreeCookie, 5 + E.TreeCookie, "cookie trees")
		equal(count.TreeCream, 5 + E.TreeCream, "cream trees")
		equal(#root.CottonTrees:GetChildren(), 32 + E.cottonLeft + E.cottonRight + centreCotton, "CottonTrees children")
		assert(root.Entrance:FindFirstChild("GiantLollipop_1") and root.Entrance:FindFirstChild("GiantLollipop_2"), "the entrance pair")
		equal(root:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE), extra, "the root counts the added trees")
		assert(extra >= base * 0.4 and extra <= base * 0.6, ("trees %d + %d: not +40-60 %%"):format(base, extra))
		local total = root:GetAttribute("PartCount")
		assert(extraParts <= 0.35 * (total - extraParts), ("the extra trees add %d parts to %d"):format(extraParts, total - extraParts))
	end)

	case("CH-T8: syncTrees adds nothing to a synced build, and a dry run only plans", function()
		local before = #root:GetDescendants()
		local report = Builder.syncTrees(root, Layout, Kit, library)
		equal(report.already, true, "already synced")
		equal(report.added, 0, "added on a second sync")
		equal(#root:GetDescendants(), before, "instances after a second sync")
		local marked = root:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE)
		root:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, nil)
		local dry = Builder.syncTrees(root, Layout, Kit, library, true)
		root:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, marked)
		equal(#root:GetDescendants(), before, "instances after a dry run")
		equal(#dry.planned, dry.added, "a planned line per tree")
		equal(dry.parts, 0, "a dry run adds no part")
		assert(not pcall(Builder.syncTrees, Instance.new("Folder"), Layout, Kit, library), "a root without tree folders is an error")
	end)

	case("CH-T9: a sync cut short only adds the missing trees, and a dry run plans the same lollipops as the real run", function()
		-- review MINOR 5: one extra cotton tree lost and the root unmarked, as after a failure halfway
		local marked = root:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE)
		local lost
		for _, tree in ipairs(root.CottonTrees:GetChildren()) do
			if tree:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE) then lost = tree end
		end
		assert(lost, "no extra cotton tree")
		lost:Destroy()
		root:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, nil)
		local report = Builder.syncTrees(root, Layout, Kit, library)
		equal(report.kept, marked - 1, "extras already standing")
		assert(report.added <= 1, "a cut-short sync added " .. report.added .. " trees")
		-- Deliberately changed (GT): the centre backfill's cotton trees come on top
		local centreCotton = 0
		for _, tree in ipairs(root.CottonTrees:GetChildren()) do
			if tree:GetAttribute(Builder.CENTRE_ATTRIBUTE) ~= nil then centreCotton += 1 end
		end
		assert(#root.CottonTrees:GetChildren() <= 32 + Builder.EXTRA_TREES.cottonLeft + Builder.EXTRA_TREES.cottonRight + centreCotton,
			"cotton trees doubled")
		equal(root:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE), report.kept + report.added, "the root counts every extra")
		-- review MINOR 4: on the second build with its extras forgotten, the dry plan's lollipops are the real run's
		local second = again:FindFirstChild(Layout.ROOT_NAME)
		assert(second, "no second build")
		for _, d in ipairs(second:GetDescendants()) do
			if d:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE) then d:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, nil) end
		end
		second:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, nil)
		local function lollipopLines(r)
			local list = {}
			for _, line in ipairs(r.planned) do
				if string.sub(line, 1, 10) == "Lollipops." then table.insert(list, line) end
			end
			return table.concat(list, ";")
		end
		local dry = Builder.syncTrees(second, Layout, Kit, library, true)
		local real = Builder.syncTrees(second, Layout, Kit, library)
		equal(lollipopLines(dry), lollipopLines(real), "dry and real lollipops")
		equal(dry.added, real.added, "dry and real counts")
	end)

	case("CH-T4: the clearance refuses a trunk or a low crown on a route or a nest, and fitTree shrinks, then moves, then gives up", function()
		-- a plain test layout: one straight route along x, one nest at (0, 40), the plaza far away
		local plain = { PATH_WIDTH = 14, NESTS = { { id = "N", x = 0, z = 40 } }, TOWER = {}, KEEP_CLEAR = {},
			BOSS = { x = 0, z = 1000, plazaRadius = 44 }, PORTAL = { x = 1000, z = 0 }, ENTRANCE = { x = -1000, z = 0 },
			flat = Layout.flat, depth = function() return 100 end, routeDistance = function(_, z) return math.abs(z) end }
		local high = { trunk = 2, canopy = 10, roof = 0, bottom = 13 }
		local low = { trunk = 2, canopy = 10, roof = 0, bottom = 6 }
		equal((Builder.treeFits(plain, 0, 10, high, {})), false, "trunk 1.5 studs past the path edge needs 10.5")
		equal((Builder.treeFits(plain, 0, 14, high, {})), true, "a high crown may overhang the path by 4")
		equal((Builder.treeFits(plain, 0, 14, low, {})), false, "a low crown never overhangs the path")
		equal((Builder.treeFits(plain, 0, 28, high, {})), true, "a crown higher than 12 may cover the nest")
		equal((Builder.treeFits(plain, 0, 28, low, {})), false, "a low crown 12 studs from the nest covers it")
		equal((Builder.treeFits(plain, 0, 26, { trunk = 2, canopy = 10, roof = 6.5, bottom = 13 }, {})), false, "the roof edge 8 off the nest")
		equal((Builder.treeFits(plain, 0, 28, high, { { x = 20, z = 28, r = 5 } })), true, "a keep-out disc 20 away")
		equal((Builder.treeFits(plain, 0, 28, high, { { x = 5, z = 28, r = 5 } })), false, "the trunk on a keep-out disc")
		plain.BOSS = { x = 0, z = 100, plazaRadius = 44 }
		equal((Builder.treeFits(plain, 0, 60, high, {})), false, "the crown over the boss plaza")
		plain.BOSS = { x = 0, z = 1000, plazaRadius = 44 }
		-- measured at 1.7: canopy 10.2 needs 13.2 from the route; at 1.65 it needs 12.9
		local m = { trunk = 2, canopy = 10.2, roof = 0, bottom = 12 }
		local f, dx, dz = Builder.fitTree(plain, 0, 13, m, 1.7, {})
		near(f, 1.65, "shrunk in place"); equal(dx, 0, "not moved x"); equal(dz, 0, "not moved z")
		f, dx, dz = Builder.fitTree(plain, 0, 9, m, 1.7, {})
		near(f, 1.65, "moved, then the largest factor that fits"); near(dx, 0, "moved straight off the route"); near(dz, 4, "4 studs")
		equal((Builder.fitTree(plain, 0, 40, m, 1.7, {})), nil, "no fit on the nest")
		local scaled = Builder.scaleMeasure({ trunk = 2, canopy = 10, roof = 6.5, bottom = 12 }, 0.5)
		near(scaled.trunk, 1, "trunk scales"); near(scaled.canopy, 5, "canopy scales"); near(scaled.bottom, 6, "bottom scales")
		near(scaled.roof, 6.5, "the roof keeps its width")
	end)

	case("CH-T5: growTree grows about the foot, boosts a leafy crown once, keeps the Roof, and a second run changes nothing", function()
		local at = CFrame.new(centre.x, top, centre.z + 600) * CFrame.Angles(0, 0.7, 0)
		local tree = Kit.place(library, "TreeCotton_M", at, 1)
		local roof = Instance.new("Part")
		roof.Name = "Roof"
		roof.Size = Vector3.new(0.4, 13, 13)
		roof.CFrame = at * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.rad(90))
		roof.Parent = tree
		if Kit.fluff then Kit.fluff(tree) end
		local trunk0, crown0 = tree.Collision_Trunk.Size, tree.CrownA.Size
		local before = Builder.measureTree(tree)
		equal(Builder.growTree(tree, "TreeCotton_M", 1.7), true, "first grow")
		near((tree:GetPivot().Position - at.Position).Magnitude, 0, "the foot stays")
		near(tree.Collision_Trunk.Size.X / trunk0.X, 1.7, "trunk")
		near(tree.CrownA.Size.X / crown0.X, 1.7 * Builder.CANOPY_BOOST, "crown")
		near(roof.Size.Y, Builder.ROOF_DIAMETER, "roof width")
		local after = Builder.measureTree(tree)
		near(after.bottom, before.bottom * 1.7, "the canopy's bottom rises with the tree, never lower", 1e-2)
		near(after.trunk, before.trunk * 1.7, "trunk reach", 1e-2)
		assert(after.canopy > before.canopy * 1.7, "the canopy grows more than the tree")
		equal(tree:GetAttribute(Builder.TREE_ATTRIBUTE), 1.7, "attribute")
		local crownAt = tree.CrownA.Position
		equal(Builder.growTree(tree, "TreeCotton_M", 1.7), false, "a second grow")
		near((tree.CrownA.Position - crownAt).Magnitude, 0, "unchanged by a second grow")
		equal(Builder.growTree(tree, "TreeCotton_M", 1.5), true, "a smaller factor later")
		near(tree.CrownA.Size.X / crown0.X, 1.5 * Builder.CANOPY_BOOST, "rescaled from the recorded factor, boosted once")
		local lolly = Kit.place(library, "TreeLollipop_Straight", at, 1)
		local disc = lolly.DiscA.Size
		Builder.growTree(lolly, "TreeLollipop_Straight", 1.6)
		near(lolly.DiscA.Size.X / disc.X, 1.6, "a lollipop is not leafy")
		tree:Destroy()
		lolly:Destroy()
	end)

	-- GT (owner request 2026-11-16, "the cake with the princess at the end, and much bigger";
	-- docs/design/wildbound-caramelo-cake-move-plan.md): the helpers the build and the live cake move share.
	case("GT8: syncTower rebuilds a Tower laid for another Torta once the GranTorta carries this layout's key", function()
		local key = Builder.layoutKey(Layout)
		equal(key, ("%g,%g,%g"):format(Layout.TORTA.x, Layout.TORTA.z, Layout.TORTA.radius), "the key")
		local function fake(tortaKey, towerKey)
			local r = Instance.new("Model")
			local torta = Instance.new("Model")
			torta.Name = "GranTorta"
			torta:SetAttribute("LayoutKey", tortaKey)
			torta.Parent = r
			local nests = Instance.new("Folder")
			nests.Name = "Nests"
			nests.Parent = r
			local tower = Instance.new("Model")
			tower.Name = "Tower"
			tower:SetAttribute("LayoutKey", towerKey)
			tower.Parent = r
			local stale = Instance.new("Model")
			stale.Name = "Nest_" .. Layout.TOWER.summit.id
			stale.Parent = nests
			return r, tower, stale
		end
		local r, tower, stale = fake(key, "0,0,26")
		local added = Builder.syncTower(r, Layout, Kit, library)
		assert(added > #Layout.stairSteps(), "rebuilt: " .. added .. " parts")
		assert(tower.Parent == nil and stale.Parent == nil, "the stale tower and summit nest are gone")
		local fresh = r:FindFirstChild("Tower")
		assert(fresh and fresh ~= tower, "a new Tower")
		equal(fresh:GetAttribute("LayoutKey"), key, "the new key")
		equal(#fresh.Stair:GetChildren(), #Layout.stairSteps(), "the new stair")
		local nest = r.Nests:FindFirstChild("Nest_" .. Layout.TOWER.summit.id)
		assert(nest and nest ~= stale and nest:GetAttribute("Summit") == true, "a new summit nest")
		near(nest:GetPivot().X, centre.x + Layout.TOWER.summit.x, "summit nest x", 0.05)
		near(nest:GetPivot().Z, centre.z + Layout.TOWER.summit.z, "summit nest z", 0.05)
		equal(Builder.syncTower(r, Layout, Kit, library), 0, "a second sync")
		-- a v2 map under the v3 layout: the GranTorta has not moved yet, so the old tower stays
		local old, oldTower, oldNest = fake(nil, nil)
		equal(Builder.syncTower(old, Layout, Kit, library), 0, "left as it is")
		equal(old:FindFirstChild("Tower"), oldTower, "the old tower stays")
		equal(oldNest.Parent, old.Nests, "the old summit nest stays")
		-- the same map with no Tower at all (it is laid at server start, never saved): still nothing is laid
		oldTower:Destroy()
		equal(Builder.syncTower(old, Layout, Kit, library), 0, "no tower round a cake of another layout")
		equal(old:FindFirstChild("Tower"), nil, "still no tower")
		r:Destroy()
		old:Destroy()
	end)

	case("GT9: the lay helpers lay what the build has; placeTorta scales the kit cake uniformly (its height too)", function()
		local probe = Instance.new("Model")
		local ground = Instance.new("Folder")
		ground.Name = "Ground"
		ground.Parent = probe
		Builder.layPaths(probe, Layout)
		Builder.layBoss(probe, Layout)
		Builder.layMarkers(probe, Layout)
		local function same(built, laid, label)
			equal(#laid:GetChildren(), #built:GetChildren(), label .. " children")
			for _, p in ipairs(built:GetChildren()) do
				local q = laid:FindFirstChild(p.Name)
				assert(q and q:IsA("BasePart"), label .. ": no " .. p.Name)
				near((p.Position - q.Position).Magnitude, 0, label .. "." .. p.Name .. " position")
				near((p.Size - q.Size).Magnitude, 0, label .. "." .. p.Name .. " size")
				equal(q:GetAttribute("Role"), p:GetAttribute("Role"), label .. "." .. p.Name .. " role")
			end
		end
		same(root.Paths, probe.Paths, "Paths")
		same(root.Boss, probe.Boss, "Boss")
		same(root.Markers, probe.Markers, "Markers")
		near((root.Ground.Plaza.Position - probe.Ground.Plaza.Position).Magnitude, 0, "plaza")
		near(probe.Ground.Plaza.Size.Y, Layout.BOSS.plazaRadius * 2, "plaza width")
		equal(probe.Boss.BossTerritory:GetAttribute("Radius"), Layout.BOSS.territoryRadius, "territory radius")
		assert(not pcall(Builder.layPaths, probe, Layout), "a second Paths folder is refused")
		assert(not pcall(Builder.layBoss, probe, Layout), "a second plaza is refused")
		probe:Destroy()
		local torta = root.GranTorta
		equal(torta:GetAttribute("LayoutKey"), Builder.layoutKey(Layout), "the GranTorta's key")
		near(torta:GetScale(), Layout.TORTA.radius * 2 / Kit.PROXIES.CakeTower[1].size.Y, "one scale for the whole cake", 1e-4)
		local highest = 0
		for _, p in ipairs(torta:GetChildren()) do
			if p:IsA("BasePart") then highest = math.max(highest, p.Position.Y + p.Size.Y / 2) end
		end
		local summit = Layout.TOWER.tiers[#Layout.TOWER.tiers].top
		assert(highest - top >= summit - 0.5, ("the cake stands %.1f studs, its summit tier %.1f"):format(highest - top, summit))
	end)

	case("GT10: syncNestPositions slides each layout nest standing off its spot there, once; the summit nest is left alone", function()
		local r = Instance.new("Model")
		local folder = Instance.new("Folder")
		folder.Name = "Nests"
		folder.Parent = r
		local function nest(name, x, z)
			local m = Instance.new("Model")
			m.Name = name
			local p = Instance.new("Part")
			p.Name, p.Anchored, p.Position = "Collision_Bowl", true, Vector3.new(x, top + 1.1, z)
			p.Parent = m
			m.PrimaryPart = p
			m.Parent = folder
			return m
		end
		local spec
		for _, s in ipairs(Layout.NESTS) do if s.id == "C5" then spec = s end end
		assert(spec, "no C5")
		local stale = nest("Nest_C5", centre.x + 128, centre.z + 44)
		nest("Nest_" .. Layout.NESTS[1].id, centre.x + Layout.NESTS[1].x, centre.z + Layout.NESTS[1].z)
		local summit = nest("Nest_" .. Layout.TOWER.summit.id, centre.x + 1, centre.z + 1)
		equal(table.concat(Builder.syncNestPositions(r, Layout), ","), "C5", "moved")
		near(stale:GetPivot().X, centre.x + spec.x, "x"); near(stale:GetPivot().Z, centre.z + spec.z, "z")
		near(stale:GetPivot().Y, top + 1.1, "its height kept")
		near(summit:GetPivot().X, centre.x + 1, "the summit nest is syncTower's")
		equal(#Builder.syncNestPositions(r, Layout), 0, "a second run moves none")
		assert(not pcall(Builder.syncNestPositions, Instance.new("Model"), Layout), "no Nests folder: an error")
		r:Destroy()
	end)

	case("GT11: the centre backfill is laid once (syncCentre) round the junction; a second run and a dry run add nothing", function()
		local F = Builder.CENTRE_FILL
		local marked = root:GetAttribute(Builder.CENTRE_ATTRIBUTE)
		assert(type(marked) == "number" and marked > 0, "the root counts the centre props: " .. tostring(marked))
		local found = 0
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute(Builder.CENTRE_ATTRIBUTE) then
				found += 1
				local p = d:GetPivot().Position
				local r = Layout.flat(p.X - centre.x, p.Z - centre.z, Layout.JUNCTION.x, Layout.JUNCTION.z)
				assert(r <= F.radius + 8 and r >= F.clearing - 8, d:GetFullName() .. " is " .. r .. " studs from the junction")
			end
		end
		equal(found, marked, "every centre prop marked")
		equal(found + root:GetAttribute("CentreSkipped"), F.cotton + F.sweets + F.gumdrops + #F.lollipops * 2, "placed or skipped")
		assert(root:GetAttribute("CentreSkipped") <= 2, "centre props skipped: " .. root:GetAttribute("CentreSkipped"))
		local before = #root:GetDescendants()
		local again = Builder.syncCentre(root, Layout, Kit, library)
		equal(again.already, true, "already laid"); equal(again.added, 0, "added again")
		equal(#root:GetDescendants(), before, "instances after a second run")
		root:SetAttribute(Builder.CENTRE_ATTRIBUTE, nil)
		local dry = Builder.syncCentre(root, Layout, Kit, library, true)
		root:SetAttribute(Builder.CENTRE_ATTRIBUTE, marked)
		equal(#root:GetDescendants(), before, "instances after a dry run")
		equal(#dry.planned, dry.added, "a planned line per prop"); equal(dry.parts, 0, "a dry run adds no part")
	end)

	case("GT-A: a clear view of the Torta down the avenue: no visible tree part within 2 studs of its axis under 40 studs", function()
		local main = Layout.ROUTES.main
		local a, b = Layout.JUNCTION, main[#main]
		for _, tree in ipairs(trees()) do
			for _, p in ipairs(tree:GetChildren()) do
				if p:IsA("BasePart") and p.Transparency < 1 then
					local reach, halfY = spread(p)
					local d = Layout.segmentDistance(p.Position.X - centre.x, p.Position.Z - centre.z, a, b) - reach
					if d < 2 then
						assert(p.Position.Y - halfY - top >= 40, p:GetFullName() .. " blocks the view of the Torta")
					end
				end
			end
		end
	end)

	case("GT12: cakeMovePlan on a v2 build: archives props on the new ground, refits a tree by a new leg, keeps the rest", function()
		local fakeRoot = Instance.new("Model")
		local folders = {}
		for _, name in ipairs({ "Lollipops", "CottonTrees", "Gumdrops", "Sweets" }) do
			local f = Instance.new("Folder")
			f.Name = name
			f.Parent = fakeRoot
			folders[name] = f
		end
		-- a kit prop: a 2 x 2 trunk collider (reach 1.41) and, for a tree, a crown 8 x 8 (reach 5.66) from 10 to 14 up
		local function prop(folder, name, asset, x, z, tree)
			local m = Instance.new("Model")
			m.Name = name
			m:SetAttribute("KitAsset", asset)
			local at = CFrame.new(centre.x + x, top, centre.z + z)
			local trunk = Instance.new("Part")
			trunk.Name, trunk.Anchored, trunk.Size, trunk.CFrame = "Collision_Trunk", true, Vector3.new(2, 6, 2), at * CFrame.new(0, 3, 0)
			trunk.Parent = m
			if tree then
				local crown = Instance.new("Part")
				crown.Name, crown.Anchored, crown.CanCollide = "CrownA", true, false
				crown.Size, crown.CFrame = Vector3.new(8, 4, 8), at * CFrame.new(0, 12, 0)
				crown.Parent = m
				m:SetAttribute(Builder.TREE_ATTRIBUTE, Builder.TREE_SCALE[asset])
			end
			m.WorldPivot = at
			m.Parent = folders[folder]
			return m
		end
		local r4
		for _, s in ipairs(Layout.NESTS) do if s.id == "R4" then r4 = s end end
		local pond = Layout.KEEP_CLEAR[1]
		local left = Layout.ROUTES.left
		local legA, legB = left[#left - 1], left[#left]
		local mx, mz = (legA.x + legB.x) / 2, (legA.z + legB.z) / 2
		local length = Layout.flat(legA.x, legA.z, legB.x, legB.z)
		local nx, nz = -(legB.z - legA.z) / length, (legB.x - legA.x) / length
		if Layout.flat(mx + nx * 8, mz + nz * 8, Layout.BOSS.x, Layout.BOSS.z) < Layout.BOSS.territoryRadius + 14 then nx, nz = -nx, -nz end
		prop("Gumdrops", "Gumdrop_1", "GumdropBush_A", (Layout.JUNCTION.x + Layout.ROUTES.main[#Layout.ROUTES.main].x) / 2, 0)
		prop("Gumdrops", "Gumdrop_2", "GumdropBush_B", r4.x + 3, r4.z)
		prop("Sweets", "RockChocolate_1", "RockChocolate", Layout.BOSS.x - 14, Layout.BOSS.z + 30)
		prop("Sweets", "RockChocolate_2", "RockChocolate", -150, 160)
		prop("CottonTrees", "CottonTree_1", "TreeCotton_M", pond.x, pond.z, true)
		prop("CottonTrees", "CottonTree_2", "TreeCotton_M", mx + nx * 8, mz + nz * 8, true)
		prop("CottonTrees", "CottonTree_3", "TreeCotton_M", -150, -150, true)
		local plan = Builder.cakeMovePlan(fakeRoot, Layout, Builder.treeKeepOut(Layout))
		local why = {}
		for _, a in ipairs(plan.archive) do why[a.instance.Name] = a.why end
		equal(why.Gumdrop_1, "on a route", "a gumdrop on the avenue")
		equal(why.Gumdrop_2, "on nest R4", "a gumdrop on a moved nest")
		equal(why.RockChocolate_1, "in the boss territory", "a rock on the new boss ground")
		equal(why.CottonTree_1, "in " .. pond.why, "a tree in the moved pond")
		equal(#plan.archive, 4, "archived")
		equal(#plan.refit, 1, "refitted")
		local refit = plan.refit[1]
		equal(refit.instance.Name, "CottonTree_2", "the tree by the new left leg")
		assert(refit.dx ~= 0 or refit.dz ~= 0 or refit.factor < Builder.TREE_SCALE.TreeCotton_M - 1e-6, "a refit changes something")
		local moved = Builder.scaleMeasure(Builder.measureTree(refit.instance), refit.factor / Builder.TREE_SCALE.TreeCotton_M)
		local p = refit.instance:GetPivot().Position
		assert(Builder.treeFits(Layout, p.X - centre.x + refit.dx, p.Z - centre.z + refit.dz, moved, Builder.treeKeepOut(Layout)),
			"the refit spot fits")
		equal(plan.kept, 2, "kept")
		for _, d in ipairs(fakeRoot:GetDescendants()) do
			if d:IsA("Model") then assert(d.Parent and d.Parent.Parent == fakeRoot, "the plan moved nothing") end
		end
		fakeRoot:Destroy()
	end)

	scratch:Destroy()
	again:Destroy()
	return result
end
