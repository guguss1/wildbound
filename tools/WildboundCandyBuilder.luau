-- Caramelo biome blockout builder (odd/tasks/caramelo-bioma.md, T1; pack 06_PROMPTS_CLAUDE/01_BIOMA_BLOCKOUT.md).
-- Turns WildboundCandyLayout into one detached Model and parents it once complete. Since layout version 2 the props are
-- prefabs of the Blender kit (WildboundCandyKit, library ServerStorage.WildboundAssets.CandyKit); ground, paths, plaza,
-- lake, boss limit, sign and markers stay plain parts. Still no scripts, no spawns, no DataStore. Nests, boss territory and portal are inert markers that game
-- code may bind later by tag or attribute. Each part carries a Role attribute that fixes its collisions:
--   floor, solid = collide and answer queries; canopy = queries only (roofs for the sky ray); decor, marker = neither.
-- Scatter (trees, gumdrops, hill yaw) comes from Layout.SEED, so the same layout always builds the same biome.
-- Refuses to build where a model of the same name already exists. Rules: WildboundCandyBuilder_Test.
local CollectionService = game:GetService("CollectionService")

local Builder = {}
Builder.MAX_PARTS = 900

local YIELD_EVERY = 150
local palette = {
	floor = Color3.fromRGB(255, 177, 209),
	glaze = Color3.fromRGB(255, 230, 205),
	icing = Color3.fromRGB(255, 247, 238),
	cake = Color3.fromRGB(246, 150, 140),
	strawberry = Color3.fromRGB(244, 90, 153),
	magenta = Color3.fromRGB(216, 52, 133),
	cotton = Color3.fromRGB(255, 150, 190),
	caramel = Color3.fromRGB(179, 106, 56),
	biscuit = Color3.fromRGB(248, 191, 102),
	chocolate = Color3.fromRGB(92, 58, 44),
	grape = Color3.fromRGB(117, 64, 121),
	mint = Color3.fromRGB(88, 214, 220),
	confetti = Color3.fromRGB(251, 225, 94),
	syrup = Color3.fromRGB(222, 150, 60),
	sugar = Color3.fromRGB(250, 214, 110),
	sugarLight = Color3.fromRGB(253, 232, 150),
	orange = Color3.fromRGB(255, 140, 40),
}
local RARITY_COLOR = { Comun = palette.mint, Rara = palette.confetti, Epica = palette.grape, Legendaria = palette.orange }
local SWEETS = { palette.mint, palette.confetti, palette.magenta, palette.grape, palette.strawberry, palette.biscuit }

-- CE1: whether a nest marker is live: the layout's NESTS_ENABLED, never an event-only nest (decision 24).
function Builder.nestEnabled(spec, layout)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	return L.NESTS_ENABLED == true and type(spec) == "table" and spec.eventOnly ~= true
end

-- CE1: applies the layout's nest flag to an existing build: the nests' Enabled attribute and the root's NestsEnabled,
-- nothing else (no part is added, moved or removed). Returns how many nests changed.
function Builder.syncNests(root, layout)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	local folder = typeof(root) == "Instance" and root:FindFirstChild("Nests") or nil
	assert(folder, "no Nests folder")
	local changed = 0
	for _, spec in ipairs(L.NESTS) do
		local nest = folder:FindFirstChild("Nest_" .. spec.id)
		local live = Builder.nestEnabled(spec, L)
		if nest and nest:GetAttribute("Enabled") ~= live then
			nest:SetAttribute("Enabled", live)
			changed += 1
		end
	end
	root:SetAttribute("NestsEnabled", L.NESTS_ENABLED == true)
	return changed
end

-- CE3: applies the layout's portal flag to an existing build (the Portal model's Enabled attribute), nothing else.
-- Returns 1 when it changed, 0 when it already matched.
function Builder.syncPortal(root, layout)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	local portal = typeof(root) == "Instance" and root:FindFirstChild("Portal") or nil
	assert(portal, "no Portal model")
	local live = L.PORTAL.enabled == true
	if portal:GetAttribute("Enabled") == live then return 0 end
	portal:SetAttribute("Enabled", live)
	return 1
end

-- Caramelo v2 (CT1, CT2): adds the Gran Torta's tower pieces to an existing build, once (a root that already has its
-- Tower model is left as it is). CT1: the stair (Layout.stairSteps), one solid column per step, from its floor up to the
-- step's top. CT2: for each turning tier, an invisible collision disc on its top (Turntable_<k>, Role floor) whose
-- AssemblyAngularVelocity carries whoever stands on it (anchored, it never moves; the physics treats it as a slow
-- turntable), and a ring of cream dollops on its rim (Spin_<k>, decor) that WildboundCandyTowerClient turns on each
-- client at the same rate (attributes SpinRate, CentreX, CentreZ). CT3: the summit nest (Layout.TOWER.summit), the kit's
-- Nest prefab on the top tier, added to the Nests folder as a live marker (NestId, Rarity, EventOnly false, Enabled from
-- NESTS_ENABLED, Summit) for WildboundCandyNests to read like any other. Needs the GranTorta prop. Returns the parts added.
function Builder.syncTower(root, layout, kit, library)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	assert(typeof(root) == "Instance" and root:FindFirstChild("GranTorta"), "no Gran Torta")
	if root:FindFirstChild("Tower") then return 0 end
	local T, top = L.TOWER, L.FLOOR_TOP
	local cx, cz = L.CENTRE.x + L.TORTA.x, L.CENTRE.z + L.TORTA.z
	local tower = Instance.new("Model")
	tower.Name = "Tower"
	local created = 0
	local function part(into, name, role, shape, size, cframe, color)
		local p = Instance.new("Part")
		p.Name, p.Shape, p.Size, p.CFrame, p.Color = name, shape, size, cframe, color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		p.Anchored, p.CanTouch = true, false
		p.CanCollide = role == "floor" or role == "solid"
		p.CanQuery = p.CanCollide
		if not p.CanCollide then p.CastShadow = false end
		p:SetAttribute("Role", role)
		p.Parent = into
		created += 1
		return p
	end
	local stair = Instance.new("Folder")
	stair.Name = "Stair"
	stair.Parent = tower
	for _, s in ipairs(L.stairSteps()) do
		local x, z = L.CENTRE.x + s.x, L.CENTRE.z + s.z
		local height = s.top - s.bottom
		local centre = Vector3.new(x, top + s.bottom + height / 2, z)
		local tangent = Vector3.new(-math.sin(s.angle), 0, math.cos(s.angle))
		part(stair, ("Step_%d_%d"):format(s.flight, s.index), "solid", Enum.PartType.Block,
			Vector3.new(T.stair.width, height, T.stair.tread + 0.2), CFrame.lookAt(centre, centre + tangent),
			s.index % 2 == 0 and palette.icing or palette.biscuit)
	end
	local rate = 2 * math.pi / T.spinPeriodSeconds
	for k, tier in ipairs(T.tiers) do
		local direction = T.spinDirections[k] or 0
		if direction ~= 0 then
			local disc = part(tower, "Turntable_" .. k, "floor", Enum.PartType.Cylinder, Vector3.new(0.2, tier.radius * 2, tier.radius * 2),
				CFrame.new(cx, top + tier.top + 0.1, cz) * CFrame.Angles(0, 0, math.rad(90)), palette.cake)
			disc.Transparency = 1
			disc.AssemblyAngularVelocity = Vector3.new(0, rate * direction, 0)
			disc:SetAttribute("SpinRate", rate * direction)
			local spin = Instance.new("Model")
			spin.Name = "Spin_" .. k
			spin:SetAttribute("SpinRate", rate * direction)
			spin:SetAttribute("CentreX", cx)
			spin:SetAttribute("CentreZ", cz)
			for i = 1, 16 do
				local a = (i - 1) * math.pi / 8
				local r = tier.radius - 0.75
				part(spin, "Dollop_" .. i, "decor", Enum.PartType.Ball, Vector3.new(1.4, 1.4, 1.4),
					CFrame.new(cx + math.cos(a) * r, top + tier.top + 0.5, cz + math.sin(a) * r), i % 2 == 0 and palette.strawberry or palette.icing)
			end
			spin.Parent = tower
		end
	end
	local S = T.summit
	local nests = root:FindFirstChild("Nests")
	if S and nests and not nests:FindFirstChild("Nest_" .. S.id) then
		local Kit = kit or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyKit"))
		local prefabs = library or game:GetService("ServerStorage"):WaitForChild("WildboundAssets"):WaitForChild(Kit.LIBRARY_NAME)
		local summitTop = top + T.tiers[#T.tiers].top
		local nest = Kit.place(prefabs, "Nest", CFrame.new(L.CENTRE.x + S.x, summitTop, L.CENTRE.z + S.z), S.scale)
		nest.Name = "Nest_" .. S.id
		for _, d in ipairs(nest:GetChildren()) do
			if d:IsA("MeshPart") then
				d:SetAttribute("Role", "decor")
			elseif d:IsA("Part") then
				d:SetAttribute("Role", "solid")
			end
			if d:IsA("BasePart") then created += 1 end
		end
		nest.PrimaryPart = nest:FindFirstChild("Collision_Bowl")
		local ring = nest:FindFirstChild("RarityRing")
		if ring then ring.Color = RARITY_COLOR[S.rarity] or palette.orange end
		nest:SetAttribute("NestId", S.id)
		nest:SetAttribute("Rarity", S.rarity)
		nest:SetAttribute("EventOnly", false)
		nest:SetAttribute("Candidate", true)
		nest:SetAttribute("Summit", true)
		nest:SetAttribute("Enabled", L.NESTS_ENABLED == true)
		CollectionService:AddTag(nest, "WildboundCandyNestCandidate")
		nest.Parent = nests
	end
	tower:SetAttribute("GeneratedBy", "ServerStorage.WildboundCandyBuilder.syncTower")
	tower.Parent = root
	return created
end

function Builder.build(parent, layout, kit, library)
	assert(typeof(parent) == "Instance", "parent must be an Instance")
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	assert(not parent:FindFirstChild(L.ROOT_NAME), L.ROOT_NAME .. " already exists")
	local Kit = kit or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyKit"))
	local prefabs = library or game:GetService("ServerStorage"):WaitForChild("WildboundAssets"):WaitForChild(Kit.LIBRARY_NAME)
	local root = Instance.new("Model")
	root.Name = L.ROOT_NAME
	local top, created = L.FLOOR_TOP, 0
	local rng = Random.new(L.SEED)

	local function world(x, y, z) return Vector3.new(L.CENTRE.x + x, y, L.CENTRE.z + z) end
	local function group(class, name, into)
		local item = Instance.new(class)
		item.Name = name
		item.Parent = into or root
		return item
	end
	local function part(into, name, role, shape, size, cframe, color)
		local p = Instance.new("Part")
		p.Name = name
		p.Shape = shape
		p.Size = size
		p.CFrame = cframe
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Anchored = true
		p.CanTouch = false
		p.CanCollide = role == "floor" or role == "solid"
		p.CanQuery = role == "floor" or role == "solid" or role == "canopy"
		if role == "marker" then p.Transparency = 1 end
		if role ~= "floor" and role ~= "solid" then p.CastShadow = false end
		p:SetAttribute("Role", role)
		p.Parent = into
		created += 1
		if created % YIELD_EVERY == 0 then task.wait() end
		return p
	end
	local function block(into, name, role, size, cframe, color)
		return part(into, name, role, Enum.PartType.Block, size, cframe, color)
	end
	-- An upright cylinder of radius r and height h standing on y = bottom at the local point (x, z).
	local function drum(into, name, role, x, z, bottom, r, h, color)
		return part(into, name, role, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2),
			CFrame.new(world(x, bottom + h / 2, z)) * CFrame.Angles(0, 0, math.rad(90)), color)
	end
	local function ball(into, name, role, x, y, z, r, color)
		return part(into, name, role, Enum.PartType.Ball, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(world(x, y, z)), color)
	end
	-- A kit prefab standing on the floor at the local point (x, z), turned by yaw. Its meshes are decoration; its
	-- Collision_ parts are solid, or floor when they stand in for a flat "box" piece you walk on.
	local function prop(into, name, asset, x, z, yaw, scale, lift)
		local model = Kit.place(prefabs, asset, CFrame.new(world(x, top + (lift or 0), z)) * CFrame.Angles(0, yaw or 0, 0), scale)
		model.Name = name
		for _, d in ipairs(model:GetChildren()) do
			if d:IsA("MeshPart") then
				d:SetAttribute("Role", "decor")
			elseif d:IsA("Part") then
				local piece = Kit.SPEC[asset].pieces[string.sub(d.Name, 11)]
				d:SetAttribute("Role", piece and piece[3] == "box" and "floor" or "solid")
			end
			if d:IsA("BasePart") then
				created += 1
				if created % YIELD_EVERY == 0 then task.wait() end
			end
		end
		model.Parent = into
		return model
	end

	local ok, failure = pcall(function()
		-- Ground and paths. Thin layers at different heights so no two tops fight.
		local ground = group("Folder", "Ground")
		block(ground, "Floor", "floor", Vector3.new(L.HALF * 2, 1, L.HALF * 2), CFrame.new(world(0, top - 0.5, 0)), palette.floor)
		drum(ground, "Plaza", "floor", L.BOSS.x, L.BOSS.z, top, L.BOSS.plazaRadius, 0.08, palette.biscuit)
		local paths, joints = group("Folder", "Paths"), {}
		for _, name in ipairs(L.ROUTE_ORDER) do
			local points = L.ROUTES[name]
			for i = 1, #points do
				local a, b = points[i], points[i + 1]
				local key = a.x .. "," .. a.z
				if not joints[key] then
					joints[key] = true
					drum(paths, "Joint_" .. name .. "_" .. i, "floor", a.x, a.z, top, L.PATH_WIDTH / 2, 0.12, palette.glaze)
				end
				if b then
					local from, to = world(a.x, top + 0.05, a.z), world(b.x, top + 0.05, b.z)
					block(paths, "Path_" .. name .. "_" .. i, "floor", Vector3.new(L.PATH_WIDTH, 0.1, (to - from).Magnitude),
						CFrame.lookAt((from + to) / 2, to), palette.glaze)
				end
			end
		end

		-- Gran Torta: the kit's cake scaled so its bottom tier has the layout's radius. Only the four tier cylinders collide.
		prop(root, "GranTorta", "CakeTower", L.TORTA.x, L.TORTA.z, 0, L.TORTA.radius * 2 / Kit.PROXIES.CakeTower[1].size.Y)

		-- Boss ground: an invisible zone with its radius, and a ring of posts that never collide.
		local boss = group("Folder", "Boss")
		local zone = drum(boss, "BossTerritory", "marker", L.BOSS.x, L.BOSS.z, top, L.BOSS.territoryRadius, 0.2, palette.magenta)
		zone:SetAttribute("Boss", "DonGlaseon")
		zone:SetAttribute("Radius", L.BOSS.territoryRadius)
		zone:SetAttribute("PlazaRadius", L.BOSS.plazaRadius)
		zone:SetAttribute("Enabled", false)
		for i = 1, 12 do
			local angle = math.rad(15 + 30 * (i - 1))
			local x, z = L.BOSS.x + math.cos(angle) * L.BOSS.territoryRadius, L.BOSS.z + math.sin(angle) * L.BOSS.territoryRadius
			drum(boss, "LimitPost_" .. i, "decor", x, z, top, 0.6, 6, palette.icing)
			ball(boss, "LimitCap_" .. i, "decor", x, top + 6.6, z, 1.1, palette.magenta)
		end

		-- Laguna de Almibar: shallow syrup you can walk through, and the biscuit bridge of the left route.
		local lake = group("Folder", "Lake")
		for i, disc in ipairs(L.LAKE) do
			drum(lake, "Syrup_" .. i, "decor", disc.x, disc.z, top, disc.r, 0.04, palette.syrup)
		end
		-- biscuit tiles a little wider than the path, so the wafer rails stand outside its 14 studs; sunk to a low step
		local tile, tiles = 12 * 1.1, math.ceil(L.BRIDGE.length / (12 * 1.1))
		for i = 1, tiles do
			prop(lake, "Bridge_" .. i, "CookieBridge", L.BRIDGE.x + (i - (tiles + 1) / 2) * tile, L.BRIDGE.z, math.rad(90), 1.1, -0.6)
		end

		-- Nests: one base with a hollow for a single egg and a rarity ring. CE1: live (Enabled) per Builder.nestEnabled.
		local nests = group("Folder", "Nests")
		for _, spec in ipairs(L.NESTS) do
			local nest = prop(nests, "Nest_" .. spec.id, "Nest", spec.x, spec.z, 0, 1)
			nest.PrimaryPart = nest.Collision_Bowl
			nest.RarityRing.Color = RARITY_COLOR[spec.rarity] 
			nest:SetAttribute("NestId", spec.id)
			nest:SetAttribute("Rarity", spec.rarity)
			nest:SetAttribute("EventOnly", spec.eventOnly)
			nest:SetAttribute("Candidate", true)
			nest:SetAttribute("Enabled", Builder.nestEnabled(spec, L))
			CollectionService:AddTag(nest, "WildboundCandyNestCandidate")
		end

		-- Entrance: the biome sign over the path, facing the hub, between two giant lollipops.
		local function lollipop(into, name, x, z, dx, dz, scale, index)
			-- the disc faces along (dx, dz), so a walker on the path sees it flat on
			prop(into, name, index % 2 == 0 and "TreeLollipop_Straight" or "TreeLollipop_Tilted", x, z, math.atan2(-dx, -dz), scale)
		end
		local taken = {}
		local entrance = group("Folder", "Entrance")
		local signX = L.ENTRANCE.x + 14
		drum(entrance, "PostNorth", "solid", signX, L.ENTRANCE.z - 11, top, 0.8, 13, palette.caramel)
		drum(entrance, "PostSouth", "solid", signX, L.ENTRANCE.z + 11, top, 0.8, 13, palette.caramel)
		local sign = block(entrance, "Sign", "decor", Vector3.new(1, 5, 24), CFrame.new(world(signX, top + 11, L.ENTRANCE.z)),
			palette.strawberry)
		sign:SetAttribute("SignKey", "candyGate")
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Left
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 20
		gui.Parent = sign
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.8, 1)
		label.Position = UDim2.fromScale(0.1, 0)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = palette.icing
		label.Text = "REINO DE CARAMELO"
		label.Parent = gui
		for i, side in ipairs({ -1, 1 }) do
			local x, z = L.ENTRANCE.x + 24, L.ENTRANCE.z + 20 * side
			lollipop(entrance, "GiantLollipop_" .. i, x, z, 1, 0, 1.5, 0)
			table.insert(taken, { x = x, z = z, reach = 4 })
		end
		-- a doughnut gate on the way from the fork to the Torta, wide enough to leave the whole path free
		prop(entrance, "DonutGate", "DonutArch", L.FORK.x + 22, L.FORK.z, math.rad(90), 1.5)
		table.insert(taken, { x = L.FORK.x + 22, z = L.FORK.z, reach = 15 })

		-- Whether a scattered prop of the given reach may stand at (x, z).
		local function open(x, z, routeClear, reach)
			if L.depth(x, z) < 10 or x > 158 then return false end
			if L.routeDistance(x, z) < routeClear then return false end
			if L.flat(x, z, L.BOSS.x, L.BOSS.z) < L.BOSS.territoryRadius + 4 + reach then return false end
			if L.flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < 28 then return false end
			if L.flat(x, z, L.PORTAL.x, L.PORTAL.z) < 16 then return false end
			for _, spot in ipairs(L.KEEP_CLEAR or {}) do
				if L.flat(x, z, spot.x, spot.z) < spot.r + reach then return false end
			end
			for _, spec in ipairs(L.NESTS) do
				if L.flat(x, z, spec.x, spec.z) < 8 + reach then return false end
			end
			for _, disc in ipairs(L.LAKE) do
				if L.flat(x, z, disc.x, disc.z) < disc.r + 2 + reach then return false end
			end
			for _, other in ipairs(taken) do
				if L.flat(x, z, other.x, other.z) < other.reach + reach then return false end
			end
			return true
		end

		-- Avenida de Piruletas: pairs along the right route, heads facing the walker. Sticks never collide.
		local lollipops = group("Folder", "Lollipops")
		local avenue, travelled, nextAt, placed = L.ROUTES.right, 0, 20, 0
		for i = 1, #avenue - 1 do
			local a, b = avenue[i], avenue[i + 1]
			local length = L.flat(a.x, a.z, b.x, b.z)
			local dx, dz = (b.x - a.x) / length, (b.z - a.z) / length
			while nextAt <= travelled + length do
				local along = nextAt - travelled
				for _, side in ipairs({ -1, 1 }) do
					local x, z = a.x + dx * along - dz * 13 * side, a.z + dz * along + dx * 13 * side
					if open(x, z, 12.5, 3) then
						placed += 1
						lollipop(lollipops, "Lollipop_" .. placed, x, z, dx, dz, 1, placed)
						table.insert(taken, { x = x, z = z, reach = 3 })
					end
				end
				nextAt += 30
			end
			travelled += length
		end

		local function scatter(count, minZ, maxZ, routeClear, reach, place)
			local done, attempts = 0, 0
			while done < count do
				attempts += 1
				assert(attempts <= 6000, "no room left to scatter")
				local x, z = math.round(rng:NextNumber(-190, 158)), math.round(rng:NextNumber(minZ, maxZ))
				if open(x, z, routeClear, reach) then
					done += 1
					table.insert(taken, { x = x, z = z, reach = reach })
					place(x, z)
				end
			end
		end

		-- Bosquecillo de Algodon: more trees on the left (covered) route. The big canopy is the roof La Nube's ray meets.
		local trees, treeCount = group("Folder", "CottonTrees"), 0
		local function tree(x, z)
			treeCount += 1
			local pick = rng:NextNumber()
			local model = prop(trees, "CottonTree_" .. treeCount, pick < 0.3 and "TreeCotton_S" or pick < 0.75 and "TreeCotton_M" or "TreeCotton_L",
				x, z, rng:NextNumber(0, math.pi * 2), 1)
			-- La Nube's sky ray needs a roof. The crowns are narrower than the blockout's canopy and a mesh would answer the
			-- ray with its precise shape, so one invisible disc of the blockout's width stands in, just inside the crown.
			local low = math.huge
			for _, crown in ipairs({ model.CrownA, model.CrownB }) do low = math.min(low, crown.Position.Y - crown.Size.Y / 2) end
			local roof = part(model, "Roof", "canopy", Enum.PartType.Cylinder, Vector3.new(0.4, 13, 13),
				CFrame.new(world(x, math.max(low + 1.5, top + 7.5), z)) * CFrame.Angles(0, 0, math.rad(90)), palette.cotton)
			roof.Transparency = 1
			CollectionService:AddTag(roof, "WildboundRoof")
		end
		scatter(22, -190, -10, 12, 8, tree)
		scatter(10, 10, 190, 12, 8, tree)

		-- Gumdrops: low props half sunk in the floor, walk-through.
		local gumdrops, gumCount = group("Folder", "Gumdrops"), 0
		scatter(30, -195, 195, 9.5, 3, function(x, z)
			gumCount += 1
			prop(gumdrops, "Gumdrop_" .. gumCount, gumCount % 2 == 0 and "GumdropBush_A" or "GumdropBush_B", x, z, rng:NextNumber(0, math.pi * 2),
				rng:NextNumber(0.8, 1.3))
		end)

		-- The rest of the kit, a few of each: biscuit and cream trees, mushrooms, chocolate rocks, confetti.
		local sweets, sweetCount = group("Folder", "Sweets"), 0
		for _, row in ipairs({ { "TreeCookie", 6, 13, 5, 0.9, 1.1 }, { "TreeCream", 6, 13, 5, 0.9, 1.1 }, { "CreamMushroom", 4, 12, 10, 0.8, 1.4 },
			{ "RockChocolate", 6, 14, 8, 0.8, 1.3 }, { "ConfettiPile", 3, 9, 10, 1.0, 1.6 } }) do
			scatter(row[4], -195, 195, row[3], row[2], function(x, z)
				sweetCount += 1
				prop(sweets, row[1] .. "_" .. sweetCount, row[1], x, z, rng:NextNumber(0, math.pi * 2), rng:NextNumber(row[5], row[6]))
			end)
		end

		-- Colinas de Azucar: cubes standing on a corner along the deep edge, closing the view behind the Torta.
		local hills = group("Folder", "SugarHills")
		for i, hill in ipairs({ { -190, 5.0 }, { -125, 4.4 }, { -60, 4.0 }, { 60, 4.0 }, { 125, 4.4 }, { 190, 5.0 } }) do
			local z, scale = hill[1], hill[2]
			prop(hills, "Hill_" .. i, "RockSugar", 198, z, rng:NextNumber(0, math.pi * 2), scale)
			prop(hills, "Peak_" .. i, "RockSugar", 207, z + (z < 0 and -1 or 1) * scale * 5.5, rng:NextNumber(0, math.pi * 2), scale * 0.55)
		end

		-- Portal back to the hub: a pad and an arch. CE3: WildboundPortalService binds its prompt while Enabled is true.
		local portal = prop(root, "Portal", "ReturnPortal", L.PORTAL.x, L.PORTAL.z, math.rad(90), 1.5) -- posts 9 studs off the path axis
		portal:SetAttribute("Leads", "hub")
		portal:SetAttribute("Enabled", L.PORTAL.enabled)
		portal:SetAttribute("QuietSeconds", L.PORTAL.quietSeconds)
		portal:SetAttribute("ChannelSeconds", L.PORTAL.channelSeconds)
		portal:SetAttribute("CooldownSeconds", L.PORTAL.cooldownSeconds)

		-- Markers: the stops of the walk test and the waypoints of both return routes.
		local markers = group("Folder", "Markers")
		local function marker(name, p)
			block(markers, name, "marker", Vector3.new(1, 1, 1), CFrame.new(world(p.x, top + 1, p.z)), palette.icing)
		end
		local main = L.ROUTES.main
		marker("Entrance", L.ENTRANCE)
		marker("Fork", L.FORK)
		marker("Junction", L.JUNCTION)
		marker("FirstNest", L.NESTS[1])
		marker("TortaPlaza", main[#main])
		marker("BossHome", L.BOSS.home)
		marker("Portal", L.PORTAL)
		for _, name in ipairs(L.RETURN_ROUTES) do
			local points = L.ROUTES[name]
			for i = 2, #points - 1 do marker("Route_" .. name .. "_" .. (i - 1), points[i]) end
		end
		assert(created <= Builder.MAX_PARTS, "part budget exceeded: " .. created)
	end)
	if not ok then
		root:Destroy()
		error(failure, 0)
	end
	if parent:FindFirstChild(L.ROOT_NAME) then
		root:Destroy()
		error(L.ROOT_NAME .. " appeared during construction", 0)
	end
	root:SetAttribute("Biome", "Caramelo")
	root:SetAttribute("Replaces", "PraderaArcoiris")
	root:SetAttribute("LayoutVersion", L.VERSION)
	root:SetAttribute("Seed", L.SEED)
	root:SetAttribute("Blockout", true)
	root:SetAttribute("SpawnsEnabled", L.SPAWNS_ENABLED)
	root:SetAttribute("NestsEnabled", L.NESTS_ENABLED == true)
	root:SetAttribute("PartCount", created)
	root:SetAttribute("GeneratedBy", "ServerStorage.WildboundCandyBuilder")
	root:SetAttribute("KitAssetId", Kit.ASSET_ID)
	CollectionService:AddTag(root, "WildboundCandyBiome")
	root.Parent = parent
	return root
end

return Builder
