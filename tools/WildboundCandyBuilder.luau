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
Builder.MAX_PARTS = 1300 -- CH: was 900; the extra trees add about 270 parts (Builder.EXTRA_TREES), the 8 new nests 40

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

-- CH3 (owner request 2026-11-16, "more eggs too"): one layout nest the way Builder.build places it (the kit's Nest
-- prefab on the floor, its rarity ring, the marker attributes and tag), into `folder`. For a build older than the nest.
function Builder.addNest(folder, spec, layout, kit, library)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	-- No WaitForChild here: this runs during the server's start (applyFlags), where an endless yield would stall it.
	local SS = game:GetService("ServerStorage")
	local Kit = kit or require(assert(SS:FindFirstChild("WildboundCandyKit"), "no ServerStorage.WildboundCandyKit"))
	local assets = SS:FindFirstChild("WildboundAssets")
	local prefabs = library or assert(assets and assets:FindFirstChild(Kit.LIBRARY_NAME), "no ServerStorage.WildboundAssets.CandyKit")
	local nest = Kit.place(prefabs, "Nest", CFrame.new(L.CENTRE.x + spec.x, L.FLOOR_TOP, L.CENTRE.z + spec.z), 1)
	nest.Name = "Nest_" .. spec.id
	for _, d in ipairs(nest:GetChildren()) do
		if d:IsA("MeshPart") then
			d:SetAttribute("Role", "decor")
		elseif d:IsA("Part") then
			d:SetAttribute("Role", "solid")
		end
	end
	nest.PrimaryPart = nest:FindFirstChild("Collision_Bowl")
	local ring = nest:FindFirstChild("RarityRing")
	if ring then ring.Color = RARITY_COLOR[spec.rarity] or palette.mint end
	nest:SetAttribute("NestId", spec.id)
	nest:SetAttribute("Rarity", spec.rarity)
	nest:SetAttribute("EventOnly", spec.eventOnly)
	nest:SetAttribute("Candidate", true)
	nest:SetAttribute("Enabled", Builder.nestEnabled(spec, L))
	CollectionService:AddTag(nest, "WildboundCandyNestCandidate")
	nest.Parent = folder
	return nest
end

-- CE1: applies the layout's nest flag to an existing build: the nests' Enabled attribute and the root's NestsEnabled,
-- nothing else (no part is added, moved or removed). Returns how many nests changed.
-- CH3: except a layout nest the build lacks (added to the layout after the biome was built), which is placed once
-- (Builder.addNest; kit and library default to ServerStorage's) and counted as changed; one that cannot be placed
-- (no kit) is skipped.
function Builder.syncNests(root, layout, kit, library)
	local L = layout or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
	local folder = typeof(root) == "Instance" and root:FindFirstChild("Nests") or nil
	assert(folder, "no Nests folder")
	local changed = 0
	for _, spec in ipairs(L.NESTS) do
		local nest = folder:FindFirstChild("Nest_" .. spec.id)
		if not nest then
			local ok, made = pcall(Builder.addNest, folder, spec, L, kit, library)
			if ok then changed += 1 end
			nest = ok and made or nil
		end
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
	-- DG4: the glaze puddles, flat glossy discs just over the plaza (decor: no collision, no ray); the glaze client and
	-- the server read them by their Radius and Top attributes.
	if T.glaze then
		local glaze = Instance.new("Folder")
		glaze.Name = "Glaze"
		for i, g in ipairs(T.glaze) do
			local surface = top + 0.09
			local disc = part(glaze, "Glaze_" .. i, "decor", Enum.PartType.Cylinder, Vector3.new(0.06, g.r * 2, g.r * 2),
				CFrame.new(L.CENTRE.x + g.x, surface + 0.03, L.CENTRE.z + g.z) * CFrame.Angles(0, 0, math.rad(90)), palette.icing)
			disc.Material, disc.Reflectance, disc.Transparency = Enum.Material.Glass, 0.25, 0.15
			disc:SetAttribute("Radius", g.r)
			disc:SetAttribute("Top", surface + 0.06)
		end
		glaze.Parent = tower
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

-- CH (owner, 2026-11-16: "the Caramelo trees leafier and bigger"). Every candy tree grows by its kind's factor about
-- its pivot (the trunk's foot stays on the floor), and the leafy kinds' crowns grow CANOPY_BOOST more about the
-- canopy's lowest centre point (so a crown never hangs lower than the grown tree's). No part is added. La Nube's Roof
-- disc keeps ROOF_DIAMETER (the cover she meets is unchanged) and only rises with the crown. The attribute TREE_ATTRIBUTE
-- records the factor, so a fresh build and a live map grown by tools/wildbound-caramelo-tree-resize.luau grow their
-- trees by the same rule and nothing grows twice.
Builder.TREE_SCALE = table.freeze({ TreeCotton_S = 1.7, TreeCotton_M = 1.7, TreeCotton_L = 1.7, TreeLollipop_Straight = 1.6,
	TreeLollipop_Tilted = 1.6, TreeCookie = 1.6, TreeCream = 1.6 })
Builder.CANOPY_BOOST = 1.15
Builder.LEAFY = table.freeze({ TreeCotton_S = true, TreeCotton_M = true, TreeCotton_L = true, TreeCookie = true, TreeCream = true })
Builder.ROOF_DIAMETER = 13
Builder.TREE_ATTRIBUTE = "CaramelTreeScaleV2"
-- Clearance of a grown tree (studs; reaches from Builder.measureTree): its trunk collider stays trunkMargin past a path
-- edge; a canopy whose bottom is under headroom never overhangs a path, a higher one by at most overhang (decor never
-- collides); trunk collider and Roof edge stay nestTrunk from a nest centre; a canopy lower than nestHeadroom stays
-- nestRadius off a nest centre (the egg stays in view). A tree that does not fit at its factor may take less, down to
-- minFactor by step, or move by one of nudges studs (fitTree).
Builder.TREE_CLEAR = table.freeze({ trunkMargin = 1.5, headroom = 8, overhang = 4, nestTrunk = 8, nestHeadroom = 12,
	nestRadius = 4, minFactor = 1.5, step = 0.05, nudges = table.freeze({ 2, 4, 6, 8 }) })
local TRUNK_MESH = { Trunk = true, StickA = true, StickB = true }

-- A part's centre in the given frame and its half extents along that frame's axes.
local function extents(frame, p)
	local cf, s = frame:ToObjectSpace(p.CFrame), p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position, (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
end
local function isCanopy(p)
	return p:IsA("BasePart") and p.Name ~= "Roof" and not TRUNK_MESH[p.Name] and string.sub(p.Name, 1, 10) ~= "Collision_"
		and not p.CanCollide
end

-- growTree(model, asset, factor) -> true when it changed the model. Scales about the pivot from the factor already
-- recorded (1 when none) to `factor`, keeps the Roof at ROOF_DIAMETER and, the first time only, gives a LEAFY kind's
-- canopy (every piece but the trunk meshes, the colliders and the Roof) its CANOPY_BOOST.
function Builder.growTree(model, asset, factor)
	assert(typeof(model) == "Instance" and model:IsA("Model"), "model must be a Model")
	assert(type(factor) == "number" and factor > 0, "factor must be a positive number")
	local was = model:GetAttribute(Builder.TREE_ATTRIBUTE)
	local from = type(was) == "number" and was or 1
	if was ~= nil and math.abs(from - factor) < 1e-6 then return false end
	if math.abs(factor / from - 1) > 1e-9 then model:ScaleTo(model:GetScale() * factor / from) end
	local roof = model:FindFirstChild("Roof")
	if roof and roof:IsA("BasePart") then roof.Size = Vector3.new(0.4, Builder.ROOF_DIAMETER, Builder.ROOF_DIAMETER) end
	if was == nil and Builder.LEAFY[asset] and Builder.CANOPY_BOOST ~= 1 then
		local pivot, pieces = model:GetPivot(), {}
		local low, high = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, p in ipairs(model:GetChildren()) do
			if isCanopy(p) then
				local at, hx, hy, hz = extents(pivot, p)
				local half = Vector3.new(hx, hy, hz)
				low, high = low:Min(at - half), high:Max(at + half)
				table.insert(pieces, p)
			end
		end
		if #pieces > 0 then
			local anchor = pivot * CFrame.new((low.X + high.X) / 2, low.Y, (low.Z + high.Z) / 2)
			for _, p in ipairs(pieces) do
				local rel = anchor:ToObjectSpace(p.CFrame)
				p.Size *= Builder.CANOPY_BOOST
				p.CFrame = anchor * CFrame.new(rel.Position * Builder.CANOPY_BOOST) * rel.Rotation
			end
		end
	end
	model:SetAttribute(Builder.TREE_ATTRIBUTE, factor)
	return true
end

-- measureTree(model) -> { trunk, canopy, roof, bottom }: from the pivot (the trunk's foot), the horizontal reach of the
-- colliders (Collision_* parts), of the canopy (every other piece but the trunk meshes and the Roof) and of the Roof,
-- and the canopy's lowest point above the pivot. Meshes and round parts count their wider half-side, blocks a corner.
function Builder.measureTree(model)
	local pivot = model:GetPivot()
	local m = { trunk = 0, canopy = 0, roof = 0, bottom = math.huge }
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			local at, hx, hy, hz = extents(pivot, p)
			local block = p:IsA("Part") and p.Shape == Enum.PartType.Block
			local reach = math.sqrt(at.X * at.X + at.Z * at.Z) + (block and math.sqrt(hx * hx + hz * hz) or math.max(hx, hz))
			if p.Name == "Roof" then
				m.roof = math.max(m.roof, reach)
			elseif string.sub(p.Name, 1, 10) == "Collision_" or p.CanCollide then
				m.trunk = math.max(m.trunk, reach)
			elseif isCanopy(p) then
				m.canopy = math.max(m.canopy, reach)
				m.bottom = math.min(m.bottom, at.Y - hy)
			end
		end
	end
	if m.bottom == math.huge then m.bottom = 0 end
	return m
end

-- The measure of the same tree grown k times more (the Roof keeps its width).
function Builder.scaleMeasure(m, k)
	return { trunk = m.trunk * k, canopy = m.canopy * k, roof = m.roof, bottom = m.bottom * k }
end

-- Every nest a tree keeps clear of: Layout.NESTS as it is at build time, and the summit nest. { id, x, z }.
function Builder.treeNests(L)
	local list = {}
	for _, spec in ipairs(L.NESTS) do table.insert(list, { id = spec.id, x = spec.x, z = spec.z }) end
	local S = L.TOWER and L.TOWER.summit
	if S then table.insert(list, { id = S.id, x = S.x, z = S.z }) end
	return list
end

-- treeKeepOut(L) -> { { x, z, r, why } } local to the plot, where no trunk collider or Roof may reach besides the layout's
-- own ground, read from the deployed modules when they are there (a missing one adds nothing): the trap cakes
-- (ServerStorage.WildboundCandyTrapCake SPOTS, r its PROMPT_STUDS) and the beasts' fixed posts
-- (ServerScriptService.WildboundPraderaSites FIXED, r 5: WildboundCandyBeastSites_Test casts its ground rays up to 4
-- studs around a post, and a Roof or a collider would answer them).
function Builder.treeKeepOut(L)
	local list = {}
	local trap = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyTrapCake")
	if trap and trap:IsA("ModuleScript") then
		local ok, Trap = pcall(require, trap)
		if ok and type(Trap) == "table" and type(Trap.SPOTS) == "table" then
			for _, s in ipairs(Trap.SPOTS) do
				table.insert(list, { x = s.x, z = s.z, r = Trap.PROMPT_STUDS or 8, why = "trap cake " .. tostring(s.key) })
			end
		end
	end
	local sites = game:GetService("ServerScriptService"):FindFirstChild("WildboundPraderaSites")
	-- the sites module waits for ReplicatedStorage.WildboundBeastConfig when required: only when that is there
	if sites and sites:IsA("ModuleScript") and game:GetService("ReplicatedStorage"):FindFirstChild("WildboundBeastConfig") then
		local ok, Sites = pcall(require, sites)
		if ok and type(Sites) == "table" and type(Sites.FIXED) == "table" then
			local keys = {}
			for key in pairs(Sites.FIXED) do table.insert(keys, key) end
			table.sort(keys)
			for _, key in ipairs(keys) do
				local p = Sites.FIXED[key]
				table.insert(list, { x = p.x - L.CENTRE.x, z = p.z - L.CENTRE.z, r = 5, why = "post " .. key })
			end
		end
	end
	return list
end

-- treeFits(L, x, z, m, keepOut) -> ok, reason: whether a tree measured m (measureTree, already grown) may stand at the
-- local point (x, z) under TREE_CLEAR, off the plot edge, the boss plaza (which holds the whole tower stair), the
-- layout's KEEP_CLEAR ground, the entrance, the portal and the keepOut discs.
function Builder.treeFits(L, x, z, m, keepOut)
	local C = Builder.TREE_CLEAR
	local half = L.PATH_WIDTH / 2
	if L.depth(x, z) < 10 then return false, "by the plot edge" end
	local road = L.routeDistance(x, z)
	if road < half + m.trunk + C.trunkMargin then return false, "trunk by a route" end
	if road < half + m.canopy - (m.bottom >= C.headroom and C.overhang or 0) then return false, "canopy over a route" end
	for _, n in ipairs(Builder.treeNests(L)) do
		local d = L.flat(x, z, n.x, n.z)
		if d < C.nestTrunk + math.max(m.trunk, m.roof) then return false, "trunk or roof by nest " .. n.id end
		if m.bottom < C.nestHeadroom and d < C.nestRadius + m.canopy then return false, "low canopy over nest " .. n.id end
	end
	local widest = math.max(m.trunk, m.canopy, m.roof)
	if L.flat(x, z, L.BOSS.x, L.BOSS.z) < L.BOSS.plazaRadius + widest then return false, "over the boss plaza" end
	-- the tower stair winds round the Torta's bottom tier (read from the layout, wherever the Torta stands)
	local T = L.TOWER
	if T and T.tiers and T.stair and L.TORTA
		and L.flat(x, z, L.TORTA.x, L.TORTA.z) < T.tiers[1].radius + T.stair.inset + T.stair.width + widest then
		return false, "over the tower stair"
	end
	for _, spot in ipairs(L.KEEP_CLEAR or {}) do
		if L.flat(x, z, spot.x, spot.z) < spot.r + widest then return false, "in " .. tostring(spot.why) end
	end
	if L.flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < 28 then return false, "at the entrance" end
	if L.flat(x, z, L.PORTAL.x, L.PORTAL.z) < 16 + math.max(m.trunk, m.canopy) then return false, "at the portal" end
	for _, k in ipairs(keepOut or {}) do
		if L.flat(x, z, k.x, k.z) < k.r + math.max(m.trunk, m.roof) then return false, "on " .. tostring(k.why) end
	end
	return true
end

-- fitTree(L, x, z, m, factor, keepOut, also) -> factor, dx, dz, or nil and the first reason. m is the tree measured at
-- `factor`. In place at `factor` or less (down to minFactor by step); else moved by each of TREE_CLEAR.nudges in turn,
-- eight directions from +x towards +z, at the largest factor that fits there (the first direction on a tie). also(x, z),
-- optional, must accept the spot too. Deterministic.
function Builder.fitTree(L, x, z, m, factor, keepOut, also)
	local C = Builder.TREE_CLEAR
	local reason
	local function largest(px, pz)
		if also and not also(px, pz) then
			reason = reason or "taken"
			return nil
		end
		local f = factor
		while f >= C.minFactor - 1e-9 do
			local ok, why = Builder.treeFits(L, px, pz, Builder.scaleMeasure(m, f / factor), keepOut)
			if ok then return f end
			reason = reason or why
			f = math.round((f - C.step) * 1000) / 1000
		end
		return nil
	end
	local f = largest(x, z)
	if f then return f, 0, 0 end
	for _, d in ipairs(C.nudges) do
		local best, bx, bz
		for k = 0, 7 do
			local a = k * math.pi / 4
			local dx, dz = math.round(math.cos(a) * d * 100) / 100, math.round(math.sin(a) * d * 100) / 100
			local g = largest(x + dx, z + dz)
			if g and (not best or g > best + 1e-9) then best, bx, bz = g, dx, dz end
		end
		if best then return best, bx, bz end
	end
	return nil, reason
end

-- CH "more trees" (owner, 2026-11-16: "MORE leafy and big trees"): on top of the base scatter, EXTRA_TREES more trees
-- (about +50 %: cotton 32 -> 48, cookie and cream 5 -> 8 each, avenue lollipops on the slots avenueFrom + k avenueEvery
-- studs along the right route, between the base pairs), placed by Builder.syncTrees under the same rule. Base trees
-- and extras are spaced by TREE_SPACING of their grown canopy (crowns may meet: a fuller wood).
Builder.EXTRA_TREES = table.freeze({ cottonLeft = 11, cottonRight = 5, TreeCookie = 3, TreeCream = 3, avenueFrom = 35,
	avenueEvery = 60 })
Builder.TREE_SPACING = 0.5
Builder.TREES_ADDED_ATTRIBUTE = "CaramelTreesAddedV2"

-- openGround(L, x, z, routeClear, reach, taken) -> whether a scattered prop of the given reach may stand at (x, z):
-- inside the plot, off the routes by routeClear, the boss territory, the entrance, the portal, KEEP_CLEAR, the nests,
-- the lake and every { x, z, reach } of taken.
function Builder.openGround(L, x, z, routeClear, reach, taken)
	if L.depth(x, z) < 10 or x > L.HALF - 42 then return false end
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

-- A kit prop with the builder's roles (meshes decor; Collision_ parts solid, or floor for a "box" piece), parented.
-- Returns the model and its part count.
local function kitProp(Kit, prefabs, into, name, asset, cframe, scale)
	local model = Kit.place(prefabs, asset, cframe, scale)
	model.Name = name
	local parts = 0
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("MeshPart") then
			d:SetAttribute("Role", "decor")
		elseif d:IsA("Part") then
			local piece = Kit.SPEC[asset].pieces[string.sub(d.Name, 11)]
			d:SetAttribute("Role", piece and piece[3] == "box" and "floor" or "solid")
		end
		if d:IsA("BasePart") then parts += 1 end
	end
	model.Parent = into
	return model, parts
end

-- dressCotton(model, Kit, top) -> parts added to a cotton tree before it grows: La Nube's Roof and the fluff blobs.
-- La Nube's sky ray needs a roof. The crowns are narrower than the blockout's canopy and a mesh would answer the ray
-- with its precise shape, so one invisible disc of the blockout's width stands in, just inside the crown. Fuller
-- canopy: visual-only ball blobs around the crowns (Kit.fluff; no collision, rays pass through; Role decor).
local function dressCotton(model, Kit, top)
	local low = math.huge
	for _, crown in ipairs({ model.CrownA, model.CrownB }) do low = math.min(low, crown.Position.Y - crown.Size.Y / 2) end
	local pivot = model:GetPivot().Position
	local roof = Instance.new("Part")
	roof.Name = "Roof"
	roof.Shape = Enum.PartType.Cylinder
	roof.Size = Vector3.new(0.4, Builder.ROOF_DIAMETER, Builder.ROOF_DIAMETER)
	roof.CFrame = CFrame.new(pivot.X, math.max(low + 1.5, top + 7.5), pivot.Z) * CFrame.Angles(0, 0, math.rad(90))
	roof.Color = palette.cotton
	roof.Material = Enum.Material.SmoothPlastic
	roof.TopSurface, roof.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	roof.Anchored, roof.CanTouch, roof.CanCollide, roof.CanQuery, roof.CastShadow = true, false, false, true, false
	roof.Transparency = 1
	roof:SetAttribute("Role", "canopy")
	roof.Parent = model
	CollectionService:AddTag(roof, "WildboundRoof")
	local parts = 1
	if Kit.fluff then
		parts += Kit.fluff(model)
		for _, blob in ipairs(model:GetChildren()) do
			if string.sub(blob.Name, 1, 6) == "Fluff_" then blob:SetAttribute("Role", "decor") end
		end
	end
	return parts
end

-- measureKind(Kit, prefabs, asset, scale, cache) -> the grown measure of a tree kind at a base scale, from a detached
-- prototype (with its fluff, and the Roof's width for a cotton tree), cached by asset and scale.
local function measureKind(Kit, prefabs, asset, scale, cache)
	local key = asset .. "@" .. scale
	if not cache[key] then
		local proto = Kit.place(prefabs, asset, CFrame.new(), scale)
		local cotton = string.sub(asset, 1, 11) == "TreeCotton_"
		if cotton and Kit.fluff then Kit.fluff(proto) end
		Builder.growTree(proto, asset, Builder.TREE_SCALE[asset])
		cache[key] = Builder.measureTree(proto)
		if cotton then cache[key].roof = Builder.ROOF_DIAMETER / 2 end
		proto:Destroy()
	end
	return cache[key]
end

-- plantSpot(L, rng, m, minZ, maxZ, taken, keepOut) -> x, z (local) for a grown tree measured m, or nil after 400 draws:
-- open ground spaced by TREE_SPACING of its canopy that also fits the tree (treeFits).
local function plantSpot(L, rng, m, minZ, maxZ, taken, keepOut)
	local reach = m.canopy * Builder.TREE_SPACING
	for _ = 1, 400 do
		local x, z = math.round(rng:NextNumber(-L.HALF + 10, L.HALF - 42)), math.round(rng:NextNumber(minZ, maxZ))
		if Builder.openGround(L, x, z, 0, reach, taken) and Builder.treeFits(L, x, z, m, keepOut) then return x, z end
	end
	return nil
end

-- The cotton kinds, weighted towards the big ones (fuller canopy: S 20 %, M 40 %, L 40 %; it was 30, 45 and 25).
local function cottonKind(rng)
	local pick = rng:NextNumber()
	return pick < 0.2 and "TreeCotton_S" or pick < 0.6 and "TreeCotton_M" or "TreeCotton_L"
end

-- syncTrees(root, layout, kit, library, dryRun) -> report { added, parts, skipped, already, planned }: adds the
-- EXTRA_TREES to an existing build (Builder.build calls it last; the live map gets them through
-- tools/wildbound-caramelo-tree-resize.luau), into its CottonTrees, Lollipops and Sweets folders only, seeded by
-- Layout.SEED + 1, around every kit prop already standing there (trees by TREE_SPACING of their canopy). The same code
-- and seed, but the props it spaces around differ between a fresh build and the live map, so their extras do not land
-- on exactly the same spots. Each new tree is grown (growTree) and marked TREES_ADDED_ATTRIBUTE; trees already marked
-- count as added (report.kept), so a sync cut short only adds what is missing; the root is marked with the total at the
-- end, and a marked root is left as it is (a second sync adds nothing). dryRun: only plans (report.planned).
function Builder.syncTrees(root, layout, kit, library, dryRun)
	local ServerStorage = game:GetService("ServerStorage")
	local L = layout or require(ServerStorage:WaitForChild("WildboundCandyLayout"))
	local Kit = kit or require(ServerStorage:WaitForChild("WildboundCandyKit"))
	local prefabs = library or ServerStorage:WaitForChild("WildboundAssets"):WaitForChild(Kit.LIBRARY_NAME)
	local report = { added = 0, kept = 0, parts = 0, skipped = 0, already = false, planned = {} }
	assert(typeof(root) == "Instance", "root must be an Instance")
	local cottonFolder, lollipopFolder, sweetsFolder = root:FindFirstChild("CottonTrees"), root:FindFirstChild("Lollipops"),
		root:FindFirstChild("Sweets")
	assert(cottonFolder and lollipopFolder and sweetsFolder, "no CottonTrees, Lollipops or Sweets folder")
	if root:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE) ~= nil then
		report.already = true
		return report
	end
	local E, C, top = Builder.EXTRA_TREES, L.CENTRE, L.FLOOR_TOP
	local rng, keepOut, cache, taken = Random.new(L.SEED + 1), Builder.treeKeepOut(L), {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		local asset = d:IsA("Model") and d:GetAttribute("KitAsset")
		if type(asset) == "string" and not d:FindFirstAncestor("Nests") then
			local m, p = Builder.measureTree(d), d:GetPivot().Position
			table.insert(taken, { x = p.X - C.x, z = p.Z - C.z,
				reach = Builder.TREE_SCALE[asset] and m.canopy * Builder.TREE_SPACING or math.max(m.trunk, m.canopy) })
		end
	end
	-- extras already standing (a sync cut short): they count, only the missing ones are added
	local have, keptLollipops = { cottonLeft = 0, cottonRight = 0, TreeCookie = 0, TreeCream = 0 }, {}
	for _, folder in ipairs({ cottonFolder, lollipopFolder, sweetsFolder }) do
		for _, c in ipairs(folder:GetChildren()) do
			if c:IsA("Model") and c:GetAttribute(Builder.TREES_ADDED_ATTRIBUTE) ~= nil then
				report.kept += 1
				local p = c:GetPivot().Position
				local asset = c:GetAttribute("KitAsset")
				if folder == cottonFolder then
					local key = p.Z - C.z < 0 and "cottonLeft" or "cottonRight"
					have[key] += 1
				elseif folder == sweetsFolder then
					if have[asset] then have[asset] += 1 end
				else
					table.insert(keptLollipops, { x = p.X - C.x, z = p.Z - C.z })
				end
			end
		end
	end
	local function nextIndex(folder)
		local n = 0
		for _, c in ipairs(folder:GetChildren()) do n = math.max(n, tonumber(string.match(c.Name, "_(%d+)$")) or 0) end
		return n + 1
	end
	local sinceYield = 0
	local function place(folder, name, asset, x, z, yaw, scale, factor)
		report.added += 1
		table.insert(report.planned, ("%s.%s %s (%.1f, %.1f) x%.2f"):format(folder.Name, name, asset, x, z, factor))
		if dryRun then return end
		local model, parts = kitProp(Kit, prefabs, folder, name, asset,
			CFrame.new(C.x + x, top, C.z + z) * CFrame.Angles(0, yaw, 0), scale)
		if string.sub(asset, 1, 11) == "TreeCotton_" then parts += dressCotton(model, Kit, top) end
		Builder.growTree(model, asset, factor)
		model:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, true)
		report.parts += parts
		sinceYield += parts
		if sinceYield >= YIELD_EVERY then
			sinceYield = 0
			task.wait()
		end
	end
	local function plant(count, minZ, maxZ, folder, prefix, kind)
		for _ = 1, count do
			local asset, scale = kind()
			local m = measureKind(Kit, prefabs, asset, scale, cache)
			local x, z = plantSpot(L, rng, m, minZ, maxZ, taken, keepOut)
			if x then
				table.insert(taken, { x = x, z = z, reach = m.canopy * Builder.TREE_SPACING })
				local name = (prefix or asset .. "_") .. nextIndex(folder)
				if dryRun then name ..= "+" .. report.added end
				place(folder, name, asset, x, z, rng:NextNumber(0, math.pi * 2), scale, Builder.TREE_SCALE[asset])
			else
				report.skipped += 1
			end
		end
	end
	local function cotton() return cottonKind(rng), 1 end
	plant(math.max(0, E.cottonLeft - have.cottonLeft), -L.HALF + 10, -10, cottonFolder, "CottonTree_", cotton)
	plant(math.max(0, E.cottonRight - have.cottonRight), 10, L.HALF - 10, cottonFolder, "CottonTree_", cotton)
	for _, asset in ipairs({ "TreeCookie", "TreeCream" }) do
		plant(math.max(0, E[asset] - have[asset]), -L.HALF + 5, L.HALF - 5, sweetsFolder, nil,
			function() return asset, rng:NextNumber(0.9, 1.1) end)
	end
	-- avenue lollipops between the base pairs, heads facing the walker, alternating like the base ones; a slot that
	-- already holds an extra lollipop (within the 8-stud nudge, plus slack) is kept as it is
	local avenue, travelled, nextAt, lollipops = L.ROUTES.right, 0, E.avenueFrom, 0
	local function slotKept(x, z)
		for _, k in ipairs(keptLollipops) do
			if L.flat(x, z, k.x, k.z) < 10 then return true end
		end
		return false
	end
	for i = 1, #avenue - 1 do
		local a, b = avenue[i], avenue[i + 1]
		local length = L.flat(a.x, a.z, b.x, b.z)
		local dx, dz = (b.x - a.x) / length, (b.z - a.z) / length
		while nextAt <= travelled + length do
			local along = nextAt - travelled
			for _, side in ipairs({ -1, 1 }) do
				local x, z = a.x + dx * along - dz * 13 * side, a.z + dz * along + dx * 13 * side
				local index = nextIndex(lollipopFolder) + (dryRun and lollipops or 0)
				local asset = index % 2 == 0 and "TreeLollipop_Straight" or "TreeLollipop_Tilted"
				local function free(qx, qz) return Builder.openGround(L, qx, qz, 0, 3, taken) end
				local f, mx, mz = nil, 0, 0
				if not slotKept(x, z) and free(x, z) then
					f, mx, mz = Builder.fitTree(L, x, z, measureKind(Kit, prefabs, asset, 1, cache), Builder.TREE_SCALE[asset], keepOut, free)
				end
				if f then
					table.insert(taken, { x = x + mx, z = z + mz, reach = 3 })
					place(lollipopFolder, "Lollipop_" .. index, asset, x + mx, z + mz, math.atan2(-dx, -dz), 1, f)
					lollipops += 1
				end
			end
			nextAt += E.avenueEvery
		end
		travelled += length
	end
	if not dryRun then root:SetAttribute(Builder.TREES_ADDED_ATTRIBUTE, report.added + report.kept) end
	return report
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

		-- CH: grown trees. measure(asset, scale): a kind measured once, on a detached prototype grown by its factor (with
		-- its fluff, and the Roof's width for a cotton tree). keepOut: Builder.treeKeepOut. treesSkipped: scattered or
		-- entrance trees that found no room (the root's TreesSkipped).
		local keepOut, measured, treesSkipped = Builder.treeKeepOut(L), {}, 0
		local function measure(asset, scale) return measureKind(Kit, prefabs, asset, scale, measured) end

		-- Entrance: the biome sign over the path, facing the hub, between two giant lollipops.
		-- CH: a lollipop grows to the largest factor that fits at (x, z) or a few studs off (Builder.fitTree; also(x, z),
		-- optional, must accept the spot too), else it is left out. Returns where it stands.
		local function lollipop(into, name, x, z, dx, dz, scale, index, also)
			-- the disc faces along (dx, dz), so a walker on the path sees it flat on
			local asset = index % 2 == 0 and "TreeLollipop_Straight" or "TreeLollipop_Tilted"
			local f, mx, mz = Builder.fitTree(L, x, z, measure(asset, scale), Builder.TREE_SCALE[asset], keepOut, also)
			if not f then return nil end
			Builder.growTree(prop(into, name, asset, x + mx, z + mz, math.atan2(-dx, -dz), scale), asset, f)
			return x + mx, z + mz
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
			local x, z = lollipop(entrance, "GiantLollipop_" .. i, L.ENTRANCE.x + 24, L.ENTRANCE.z + 20 * side, 1, 0, 1.5, 0)
			if x then table.insert(taken, { x = x, z = z, reach = 4 }) else treesSkipped += 1 end
		end
		-- a doughnut gate on the way from the fork to the Torta, wide enough to leave the whole path free
		prop(entrance, "DonutGate", "DonutArch", L.FORK.x + 22, L.FORK.z, math.rad(90), 1.5)
		table.insert(taken, { x = L.FORK.x + 22, z = L.FORK.z, reach = 15 })

		-- Whether a scattered prop of the given reach may stand at (x, z).
		local function open(x, z, routeClear, reach) return Builder.openGround(L, x, z, routeClear, reach, taken) end

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
					-- CH: the route clearance of the grown lollipop is fitTree's
					if open(x, z, 0, 3) then
						local px, pz = lollipop(lollipops, "Lollipop_" .. placed + 1, x, z, dx, dz, 1, placed + 1, function(qx, qz)
							return open(qx, qz, 0, 3)
						end)
						if px then
							placed += 1
							table.insert(taken, { x = px, z = pz, reach = 3 })
						end
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

		-- CH: plant(count, minZ, maxZ, plan, place) scatters grown trees. plan() draws one tree (asset, base scale) before
		-- its spot is searched; the spot must be open, spaced by TREE_SPACING of the grown canopy, and fit the grown tree
		-- (Builder.treeFits). A tree with no spot in 400 draws is skipped and counted.
		local function plant(count, minZ, maxZ, plan, place)
			for _ = 1, count do
				local asset, scale = plan()
				local m = measure(asset, scale)
				local spotX, spotZ = plantSpot(L, rng, m, minZ, maxZ, taken, keepOut)
				if spotX then
					table.insert(taken, { x = spotX, z = spotZ, reach = m.canopy * Builder.TREE_SPACING })
					place(spotX, spotZ, asset, scale)
				else
					treesSkipped += 1
				end
			end
		end

		-- Bosquecillo de Algodon: more trees on the left (covered) route. The big canopy is the roof La Nube's ray meets.
		local trees, treeCount = group("Folder", "CottonTrees"), 0
		local function tree(x, z, asset)
			treeCount += 1
			local model = prop(trees, "CottonTree_" .. treeCount, asset, x, z, rng:NextNumber(0, math.pi * 2), 1)
			-- La Nube's Roof and the fluff blobs (dressCotton), then the growth
			created += dressCotton(model, Kit, top)
			Builder.growTree(model, asset, Builder.TREE_SCALE[asset])
		end
		local function cotton() return cottonKind(rng), 1 end
		plant(22, -190, -10, cotton, tree)
		plant(10, 10, 190, cotton, tree)

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
			if Builder.TREE_SCALE[row[1]] then
				-- CH: a cookie or cream tree draws its scale first, then a spot its grown size fits (row[2], row[3] unused)
				plant(row[4], -195, 195, function() return row[1], rng:NextNumber(row[5], row[6]) end, function(x, z, asset, scale)
					sweetCount += 1
					local model = prop(sweets, asset .. "_" .. sweetCount, asset, x, z, rng:NextNumber(0, math.pi * 2), scale)
					Builder.growTree(model, asset, Builder.TREE_SCALE[asset])
				end)
			else
				scatter(row[4], -195, 195, row[3], row[2], function(x, z)
					sweetCount += 1
					prop(sweets, row[1] .. "_" .. sweetCount, row[1], x, z, rng:NextNumber(0, math.pi * 2), rng:NextNumber(row[5], row[6]))
				end)
			end
		end
		-- CH more trees: the extra trees, by the same code the live map uses (Builder.syncTrees; not the same spots there)
		local extra = Builder.syncTrees(root, L, Kit, prefabs)
		created += extra.parts
		root:SetAttribute("TreesSkipped", treesSkipped + extra.skipped)

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
