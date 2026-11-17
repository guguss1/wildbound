-- Caramelo v6, proposal 4 (odd/tasks/wildbound-caramelo-v2.md V6-D4; docs/design/wildbound-caramelo-v3-plan.md V6-D60
-- on): an island in the big chocolate lake with one Epica egg nest and a few candy decorations, reached by raft or by
-- wading. Its place and size are the layout's (WildboundCandyV3Layout.ISLANDS: centre, waterline r, level top `flat`,
-- underwater foot; V3.ISLAND: the top's height over the surface, the bank's steepness, the slices), and the layout
-- already treats it as dry land (V3.liquidDistance), so the raft, wading and the current keep off it with no change of
-- their own. This module lays it on the live map at server start:
--   ground  plain parts, all colliding: a cookie core (a cylinder from the floor to the top), a gentle caramel beach in
--           `sectors` tilted slabs from the top's edge down to the waterline, and a chocolate-soaked bank in as many
--           slabs from the waterline down to the floor, so a wader walks up out of the chocolate. A thin icing disc
--           (decor) on top.
--   decor   three gumdrops (plain parts) and, when the old candy kit is in ServerStorage, a lollipop, a gumdrop bush and
--           a cream mushroom (WildboundCandyKit.place, as WildboundCandyHideSpots does); decor never collides and is
--           never queried.
--   nest    the kit's Nest prefab (a plain bowl and ring without the kit) in the biome's Nests folder as Nest_<island
--           id> ("I1": never a Layout.NESTS id, the summit's T1 or a house's H<n>), with the marker attributes of
--           WildboundCandyBuilder.addNest plus LakeIsland = true and IslandId. WildboundCandyNests.read makes it an
--           island nest (CandyI1, Epica: a Flanfuria egg, FogFar pay) and never binds it to a creature post, so a
--           steal raises the usual alarm and the frenzy (WildboundBeasts.stealCheck: any nest in the biome).
-- Called from WildboundCandyNests.applyFlags (its eighth step, guarded) and idempotent: an island already laid with
-- this BUILD at its place is left alone, one of another build or place is laid again; the nest is moved onto its spot
-- and follows the layout's NESTS_ENABLED. Nothing happens without the v5 water (root.CaramelV3 of Version 3 or more,
-- with its Lake). No asset upload, no service script, no remote.
local CollectionService = game:GetService("CollectionService")

local Island = {}

Island.TAG = "WildboundCandyIsland"
Island.FOLDER = "LakeIslands"
Island.NEST_TAG = "WildboundCandyNestCandidate"
Island.BUILD = 1 -- bumped when the island's shape changes: an island of another build is laid again
Island.RARITY = "Epica"
Island.NEST_SCALE = 0.9 -- the bowl 4.8 wide and its ring 6.7 on the 9-wide top
Island.THICK = 1.2 -- a slab's thickness
Island.CORE_OUT = 0.25 -- the core reaches this far past the level top over the beach's start (no gap; a 0.14 step)
Island.BANK_OUT = 0.5 -- a bank slab reaches this far past its foot, into the floor
-- The beach and the bank slabs meet on the waterline (a convex knee: extending either past it would stand proud of the
-- other), so their top faces are one walkable surface.
Island.WIDTH_EXTRA = 0.2 -- a slab is this much wider than its slice at its outer end (no gap)
local COLORS = {
	core = Color3.fromRGB(232, 182, 108), beach = Color3.fromRGB(240, 196, 128), bank = Color3.fromRGB(122, 74, 46),
	icing = Color3.fromRGB(255, 196, 222), wafer = Color3.fromRGB(179, 106, 56),
	gumdrops = { Color3.fromRGB(88, 214, 220), Color3.fromRGB(255, 150, 190), Color3.fromRGB(251, 225, 94) },
	ring = Color3.fromRGB(117, 64, 121), -- Epica (WildboundCandyBuilder's rarity colour)
}
-- Kit decor on the top: { asset, degrees (round the centre, from +x towards +z), radius, scale }.
Island.DECOR = table.freeze({
	table.freeze({ asset = "TreeLollipop_Straight", degrees = 40, radius = 3.6, scale = 0.55 }),
	table.freeze({ asset = "GumdropBush_B", degrees = 160, radius = 3.6, scale = 0.45 }),
	table.freeze({ asset = "CreamMushroom", degrees = 280, radius = 3.6, scale = 0.35 }),
})
-- Plain gumdrops on the top: { degrees, radius, size }.
Island.GUMDROPS = table.freeze({
	table.freeze({ degrees = 100, radius = 3.7, size = 1.3 }),
	table.freeze({ degrees = 220, radius = 3.8, size = 1.1 }),
	table.freeze({ degrees = 340, radius = 3.7, size = 1.2 }),
})

local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function lookup(name)
	local module = game:GetService("ServerStorage"):FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, loaded = pcall(require, module)
	return ok and type(loaded) == "table" and loaded or nil
end

-- The nest id of an island: its id ("I1"); never one of Layout.NESTS (C, R, E, L), the summit (T1) or a house (H<n>).
function Island.nestId(island)
	return type(island) == "table" and type(island.id) == "string" and island.id or nil
end

-- The island's heights over the floor: its top, the surface (its waterline).
function Island.heights(V3)
	local surface = V3.LIQUID.depth
	return surface + V3.ISLAND.top, surface
end

-- profile(island, V3, rho) -> the ground's height over the floor at rho studs from the island's centre: the level top
-- to `flat`, the beach down to the surface at the waterline r, the bank down to the floor at the foot, 0 past it.
function Island.profile(island, V3, rho)
	local top, surface = Island.heights(V3)
	if rho <= island.flat then return top end
	if rho <= island.r then return top + (surface - top) * (rho - island.flat) / (island.r - island.flat) end
	if rho <= island.foot then return surface * (island.foot - rho) / (island.foot - island.r) end
	return 0
end

-- The beach's and the bank's slopes, degrees.
function Island.slopes(island, V3)
	local top, surface = Island.heights(V3)
	return math.deg(math.atan2(top - surface, island.r - island.flat)), math.deg(math.atan2(surface, island.foot - island.r))
end

-- One slab whose top face runs along the slice's centre line (ux, uz) from (ri, hi) to (ro, ho) (studs from the centre,
-- heights over the floor): its CFrame and Size, top face up.
local function slab(cx, cz, floorTop, ux, uz, ri, hi, ro, ho, width)
	local dr, dh = ro - ri, ho - hi
	local length = math.sqrt(dr * dr + dh * dh)
	local up = Vector3.new(-ux * dh, dr, -uz * dh) / length
	local right = Vector3.new(-uz, 0, ux)
	local mid = Vector3.new(cx + ux * (ri + ro) / 2, floorTop + (hi + ho) / 2, cz + uz * (ri + ro) / 2)
	return CFrame.fromMatrix(mid - up * Island.THICK / 2, right, up), Vector3.new(width, Island.THICK, length)
end

-- ground(island, V3, centre, floorTop) -> { { name, kind ("core", "beach", "bank"), cframe, size, shape } }: the
-- colliding parts, world studs. centre: the plot's centre { x, z }.
function Island.ground(island, V3, centre, floorTop)
	local top, surface = Island.heights(V3)
	local cx, cz = centre.x + island.x, centre.z + island.z
	local list = {}
	local core = (island.flat + Island.CORE_OUT) * 2
	table.insert(list, { name = "Core", kind = "core", shape = Enum.PartType.Cylinder,
		size = Vector3.new(top + 0.2, core, core),
		cframe = CFrame.new(cx, floorTop + (top - 0.2) / 2, cz) * CFrame.Angles(0, 0, math.rad(90)) })
	local n = V3.ISLAND.sectors
	local half = math.tan(math.pi / n)
	local bankSlope = surface / (island.foot - island.r)
	for k = 0, n - 1 do
		local a = 2 * math.pi * k / n
		local ux, uz = math.cos(a), math.sin(a)
		local cf, size = slab(cx, cz, floorTop, ux, uz, island.flat, top, island.r, surface,
			2 * island.r * half + Island.WIDTH_EXTRA)
		table.insert(list, { name = ("Beach_%02d"):format(k + 1), kind = "beach", shape = Enum.PartType.Block, cframe = cf, size = size })
		local ko = island.foot + Island.BANK_OUT
		cf, size = slab(cx, cz, floorTop, ux, uz, island.r, surface, ko, -Island.BANK_OUT * bankSlope,
			2 * ko * half + Island.WIDTH_EXTRA)
		table.insert(list, { name = ("Bank_%02d"):format(k + 1), kind = "bank", shape = Enum.PartType.Block, cframe = cf, size = size })
	end
	return list
end

-- The world CFrame of the island's nest: the bowl's base on the top, at the centre.
function Island.nestFrame(island, V3, centre, floorTop)
	local top = Island.heights(V3)
	return CFrame.new(centre.x + island.x, floorTop + top, centre.z + island.z)
end

-- A point on the top, `degrees` round the centre at `radius`, facing out.
local function onTop(island, V3, centre, floorTop, degrees, radius)
	local top = Island.heights(V3)
	local a = math.rad(degrees)
	local ux, uz = math.cos(a), math.sin(a)
	local at = Vector3.new(centre.x + island.x + ux * radius, floorTop + top, centre.z + island.z + uz * radius)
	return CFrame.lookAt(at, at + Vector3.new(ux, 0, uz))
end

local function part(model, name, shape, size, cframe, color, solid)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.CFrame, p.Color = name, shape, size, cframe, color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, solid, solid, solid, solid
	p.Parent = model
	return p
end

-- build(island, V3, centre, floorTop, kit, library) -> a detached Model LakeIsland_<id>: the ground, the icing and the
-- decor (kit decor only with kit and library). Its pivot is the island's centre on the floor.
function Island.build(island, V3, centre, floorTop, kit, library)
	local model = Instance.new("Model")
	model.Name = "LakeIsland_" .. island.id
	for _, g in ipairs(Island.ground(island, V3, centre, floorTop)) do
		local color = g.kind == "bank" and COLORS.bank or g.kind == "beach" and COLORS.beach or COLORS.core
		local p = part(model, g.name, g.shape, g.size, g.cframe, color, true)
		p:SetAttribute("Role", "floor")
	end
	local top = Island.heights(V3)
	local cx, cz = centre.x + island.x, centre.z + island.z
	part(model, "Icing", Enum.PartType.Cylinder, Vector3.new(0.12, island.flat * 2 - 0.4, island.flat * 2 - 0.4),
		CFrame.new(cx, floorTop + top + 0.06, cz) * CFrame.Angles(0, 0, math.rad(90)), COLORS.icing, false)
	for i, g in ipairs(Island.GUMDROPS) do
		local cf = onTop(island, V3, centre, floorTop, g.degrees, g.radius)
		part(model, "Gumdrop", Enum.PartType.Ball, Vector3.new(g.size, g.size, g.size), cf * CFrame.new(0, g.size * 0.4, 0),
			COLORS.gumdrops[(i - 1) % #COLORS.gumdrops + 1], false)
	end
	if kit and library then
		for _, d in ipairs(Island.DECOR) do
			local ok, made = pcall(kit.place, library, d.asset, onTop(island, V3, centre, floorTop, d.degrees, d.radius), d.scale)
			if ok and made then
				for _, p in ipairs(made:GetDescendants()) do
					if p:IsA("BasePart") then p.CanCollide, p.CanQuery, p.CanTouch = false, false, false end
				end
				made.Name = "Decor_" .. d.asset
				made.Parent = model
			end
		end
	end
	model.WorldPivot = CFrame.new(cx, floorTop, cz)
	model:SetAttribute("IslandId", island.id)
	model:SetAttribute("Radius", island.r)
	model:SetAttribute("Foot", island.foot)
	model:SetAttribute("Build", Island.BUILD)
	model:SetAttribute("CandyIsland", true)
	CollectionService:AddTag(model, Island.TAG)
	return model
end

-- A plain nest when the kit is missing: the kit Nest's bowl (Collision_Bowl, 5.3 x 2.2) and its rarity ring.
local function plainNest(at, scale)
	local nest = Instance.new("Model")
	local bowl = part(nest, "Collision_Bowl", Enum.PartType.Cylinder, Vector3.new(2.2, 5.3, 5.3) * scale,
		at * CFrame.new(0, 1.1 * scale, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.wafer, true)
	bowl.Material = Enum.Material.Wood
	part(nest, "RarityRing", Enum.PartType.Cylinder, Vector3.new(0.08, 7.4 * scale, 7.4 * scale),
		at * CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)), COLORS.ring, false)
	nest.WorldPivot = at
	return nest
end

-- The island's nest at `at`: the kit's Nest prefab (or a plain one), dressed as a live marker (WildboundCandyBuilder.addNest's
-- attributes and tag, plus LakeIsland and IslandId), its pivot kept on the spot.
function Island.makeNest(id, at, kit, library, live)
	local nest = nil
	if kit and library then
		local ok, made = pcall(kit.place, library, "Nest", at, Island.NEST_SCALE)
		nest = ok and made or nil
	end
	nest = nest or plainNest(at, Island.NEST_SCALE)
	for _, d in ipairs(nest:GetChildren()) do
		if d:IsA("MeshPart") then
			d:SetAttribute("Role", "decor")
		elseif d:IsA("Part") then
			d:SetAttribute("Role", "solid")
		end
	end
	local pivot = nest:GetPivot()
	local bowl = nest:FindFirstChild("Collision_Bowl")
	nest.PrimaryPart = bowl
	if bowl then bowl.PivotOffset = bowl.CFrame:ToObjectSpace(pivot) end
	local ring = nest:FindFirstChild("RarityRing")
	if ring and ring:IsA("BasePart") then ring.Color = COLORS.ring end
	nest.Name = "Nest_" .. id
	nest:SetAttribute("NestId", id)
	nest:SetAttribute("Rarity", Island.RARITY)
	nest:SetAttribute("EventOnly", false)
	nest:SetAttribute("Candidate", true)
	nest:SetAttribute("LakeIsland", true)
	nest:SetAttribute("IslandId", id)
	nest:SetAttribute("Enabled", live == true)
	CollectionService:AddTag(nest, Island.NEST_TAG)
	return nest
end

-- Whether the live biome has the v5 water the island stands in.
function Island.ready(root, V3)
	local v3 = typeof(root) == "Instance" and root:FindFirstChild(V3.FOLDER) or nil
	return v3 ~= nil and (tonumber(v3:GetAttribute("Version")) or 0) >= 3 and v3:FindFirstChild("Lake") ~= nil
end

-- The server's start step (through WildboundCandyNests.applyFlags). L and V3 default to ServerStorage's
-- WildboundCandyLayout and WildboundCandyV3Layout; opts = { kit, library } (kit false: no kit, plain nest and no kit
-- decor; nil: ServerStorage's). Returns how many things changed (an island laid or laid again, a nest laid, moved,
-- switched or re-marked, a stale island removed), the ids skipped, and how many islands stand.
function Island.sync(root, L, V3, opts)
	if typeof(root) ~= "Instance" then return 0, {}, 0 end
	L = L or lookup("WildboundCandyLayout")
	V3 = V3 or lookup("WildboundCandyV3Layout")
	if type(L) ~= "table" or type(V3) ~= "table" or type(V3.ISLANDS) ~= "table" or not Island.ready(root, V3) then
		return 0, {}, 0
	end
	opts = opts or {}
	local floorTop = L.FLOOR_TOP
	local ground = root:FindFirstChild("Ground")
	local floorPart = ground and ground:FindFirstChild("Floor")
	if floorPart and floorPart:IsA("BasePart") then floorTop = floorPart.Position.Y + floorPart.Size.Y / 2 end
	local centre = L.CENTRE
	local Kit, library = opts.kit, opts.library
	if Kit == nil then Kit = lookup("WildboundCandyKit") end
	if Kit and library == nil then
		local assets = game:GetService("ServerStorage"):FindFirstChild("WildboundAssets")
		library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME) or nil
	end
	if Kit == false then Kit = nil end
	local folder = root:FindFirstChild(Island.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Island.FOLDER
		folder.Parent = root
	end
	local nests = root:FindFirstChild("Nests")
	local live = L.NESTS_ENABLED == true
	local changed, skipped, count, want, wantNest = 0, {}, 0, {}, {}
	for _, island in ipairs(V3.ISLANDS) do
		local name = "LakeIsland_" .. island.id
		want[name] = true
		local pivot = Vector3.new(centre.x + island.x, floorTop, centre.z + island.z)
		local old = folder:FindFirstChild(name)
		if old and (old:GetAttribute("Build") ~= Island.BUILD or old:GetAttribute("Radius") ~= island.r
			or old:GetAttribute("Foot") ~= island.foot or (old:GetPivot().Position - pivot).Magnitude > 0.5) then
			old:Destroy()
			old = nil
		end
		if not old then
			Island.build(island, V3, centre, floorTop, Kit, library).Parent = folder
			changed += 1
		end
		count += 1
		local id = Island.nestId(island)
		if not nests or not id then
			table.insert(skipped, tostring(id))
		else
			wantNest["Nest_" .. id] = true
			local at = Island.nestFrame(island, V3, centre, floorTop)
			local nest = nests:FindFirstChild("Nest_" .. id)
			if nest then
				if (nest:GetPivot().Position - at.Position).Magnitude > 0.5 then
					nest:PivotTo(at)
					changed += 1
				end
				if nest:GetAttribute("Enabled") ~= live then
					nest:SetAttribute("Enabled", live)
					changed += 1
				end
				if nest:GetAttribute("Rarity") ~= Island.RARITY or nest:GetAttribute("LakeIsland") ~= true then
					nest:SetAttribute("Rarity", Island.RARITY)
					nest:SetAttribute("LakeIsland", true)
					nest:SetAttribute("IslandId", id)
					changed += 1
				end
			else
				Island.makeNest(id, at, Kit, library, live).Parent = nests
				changed += 1
			end
		end
	end
	-- an island (and its nest) no longer in the layout is removed
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^LakeIsland_") and not want[child.Name] then
			child:Destroy()
			changed += 1
		end
	end
	for _, child in ipairs(nests and nests:GetChildren() or {}) do
		if child:IsA("Model") and child:GetAttribute("LakeIsland") == true and not wantNest[child.Name] then
			child:Destroy()
			changed += 1
		end
	end
	return changed, skipped, count
end

return Island
