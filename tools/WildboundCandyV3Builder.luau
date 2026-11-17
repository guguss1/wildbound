-- Caramelo v3 builder (owner request 2026-11-17; docs/design/wildbound-caramelo-v3-plan.md). Lays the pieces of
-- WildboundCandyV3Layout on a built Caramelo biome (Workspace.Candy_Bioma_v1, layout VERSION 3) or on a detached scratch
-- model (WildboundCandyV3Builder_Test): the chocolate river, lake and waterfall streaks, the bridge, the raft's docks,
-- the ice-cream mountains, the houses with their interiors, the rainbow licorice, the modular cake, the cookie
-- platforms and the filler; and swaps the old trees for the three new kinds.
-- Every piece comes from the Blender kit ServerStorage.WildboundAssets.CandyKitV3.<AssetName> when that Model is there:
-- scaled about its pivot (the ground centre of its base, front -Z), its meshes coloured and made non-colliding, and its
-- invisible Collision_ parts made from the kit spec (tools/WildboundCandyV3KitSpec.luau, generated from the kits'
-- contracts). A missing model is replaced by a plain-part Placeholder of the same footprint (attribute
-- Placeholder = true), so the batch can be laid before the models arrive. Each part carries the CandyBuilder Role
-- attribute: floor and solid collide and answer rays, canopy answers rays only, decor and marker neither. The
-- chocolate is decor (V3-D6: walk-through, the floor below stays the ground). No scripts, no spawns, no DataStore,
-- nothing destroyed on a live map: what goes away is handed to an archive callback. Nothing named SistemaSonriente, or
-- inside it, is touched. Rules: WildboundCandyV3Builder_Test.
local CollectionService = game:GetService("CollectionService")

local V3Builder = {}

local YIELD_EVERY = 150
local FORBIDDEN = "SistemaSonriente"
local PALETTE = {
	chocolate = Color3.fromRGB(92, 52, 34),
	chocolateLight = Color3.fromRGB(140, 86, 52),
	foam = Color3.fromRGB(255, 238, 225),
	rock = Color3.fromRGB(176, 120, 104),
	vanilla = Color3.fromRGB(255, 243, 230),
	strawberry = Color3.fromRGB(242, 123, 160),
	mint = Color3.fromRGB(150, 236, 205),
	cherry = Color3.fromRGB(200, 16, 46),
	caramel = Color3.fromRGB(201, 122, 54),
	apple = Color3.fromRGB(220, 40, 52),
	biscuit = Color3.fromRGB(233, 162, 90),
	wafer = Color3.fromRGB(232, 176, 98),
	cotton = Color3.fromRGB(255, 150, 190),
	cottonBlue = Color3.fromRGB(157, 184, 240),
	stick = Color3.fromRGB(255, 247, 238),
	pinkWall = Color3.fromRGB(227, 168, 105),
	roofPink = Color3.fromRGB(247, 168, 196),
	chocoWall = Color3.fromRGB(138, 75, 42),
	towerWall = Color3.fromRGB(246, 169, 196),
	rainbow = {
		Color3.fromRGB(247, 92, 155), Color3.fromRGB(249, 160, 63), Color3.fromRGB(251, 225, 94),
		Color3.fromRGB(125, 211, 90), Color3.fromRGB(92, 194, 240), Color3.fromRGB(181, 123, 232),
	},
}
V3Builder.PALETTE = PALETTE

local function forbidden(instance)
	return instance.Name == FORBIDDEN or instance:FindFirstAncestor(FORBIDDEN) ~= nil
end
V3Builder.forbidden = forbidden

-- A build context: the layout pair, the kit, the part count and a yield every YIELD_EVERY parts.
local function context(L, V3, deps)
	local ctx = { L = L, V3 = V3, parts = 0, top = L.FLOOR_TOP, kit = deps and deps.kitV3, spec = deps and deps.kitSpec }
	function ctx.counted(n)
		local before = ctx.parts
		ctx.parts += n
		if math.floor(before / YIELD_EVERY) ~= math.floor(ctx.parts / YIELD_EVERY) then task.wait() end
	end
	function ctx.world(x, y, z) return Vector3.new(L.CENTRE.x + x, y, L.CENTRE.z + z) end
	return ctx
end

-- One plain part with the builder's roles, parented and counted.
local function part(ctx, into, name, role, shape, size, cframe, color)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.CFrame, p.Color = name, shape, size, cframe, color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanTouch = true, false
	p.CanCollide = role == "floor" or role == "solid"
	p.CanQuery = role == "floor" or role == "solid" or role == "canopy"
	if role == "marker" then p.Transparency = 1 end
	if role ~= "floor" and role ~= "solid" then p.CastShadow = false end
	p:SetAttribute("Role", role)
	p.Parent = into
	ctx.counted(1)
	return p
end
local function block(ctx, into, name, role, size, cframe, color)
	return part(ctx, into, name, role, Enum.PartType.Block, size, cframe, color)
end
local function ball(ctx, into, name, role, centre, r, color)
	return part(ctx, into, name, role, Enum.PartType.Ball, Vector3.new(r * 2, r * 2, r * 2), CFrame.new(centre), color)
end
-- An upright cylinder of radius r and height h standing on y = bottom at the world point (x, z).
local function drum(ctx, into, name, role, x, z, bottom, r, h, color)
	return part(ctx, into, name, role, Enum.PartType.Cylinder, Vector3.new(h, r * 2, r * 2),
		CFrame.new(x, bottom + h / 2, z) * CFrame.Angles(0, 0, math.rad(90)), color)
end
-- A tilted plank (a ramp) whose top surface runs from world point a to world point b, `width` wide.
local function plank(ctx, into, name, role, a, b, width, color)
	local thick = 0.4
	local down = Vector3.new(0, thick / 2, 0)
	return block(ctx, into, name, role, Vector3.new(width, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2 - down, b - down), color)
end
local function folder(into, name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = into
	return f
end
local function model(into, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = into
	return m
end
local function liquid(p, V3)
	p.Transparency = V3.LIQUID.transparency
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.04
	p:SetAttribute("Liquid", "Chocolate")
	return p
end
local function hexColor(hex)
	local n = tonumber(hex, 16) or 0
	return Color3.fromRGB(bit32.rshift(n, 16) % 256, bit32.rshift(n, 8) % 256, n % 256)
end

-- Kit models --------------------------------------------------------------------------------------------------

-- kitModel(kitFolder, asset) -> a fresh clone of the kit Model, scripts stripped, or nil when the kit lacks it.
function V3Builder.kitModel(kitFolder, asset)
	local source = typeof(kitFolder) == "Instance" and kitFolder:FindFirstChild(asset) or nil
	if not (source and source:IsA("Model")) then return nil end
	local copy = source:Clone()
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then d.Parent = nil end
	end
	return copy
end

-- The Role of a kit collider: walkable floor for the pieces you stand on, solid for the rest.
local FLOOR_WORDS = { "Floor", "Stair", "Ramp", "ramp", "landing", "Ledge", "Slab", "Body" }
function V3Builder.colliderRole(name, mode)
	if mode == "floor" then return "floor" end
	for _, word in ipairs(FLOOR_WORDS) do
		if string.find(name, word, 1, true) then return "floor" end
	end
	return "solid"
end

-- applySpec(ctx, m, spec, scale, mode) -> parts: anchors and recolours the kit meshes (never colliding, never queried;
-- the "water" pieces become translucent chocolate) and adds the invisible Collision_ parts of the spec in the model's
-- pivot frame at `scale`. mode "floor" makes every collider walkable. Without a spec, the kit's own collisions stay.
local function applySpec(ctx, m, spec, scale, mode)
	local count, byObject = 0, {}
	for _, piece in pairs(spec and spec.pieces or {}) do byObject[piece.object] = piece end
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			count += 1
			d.Anchored, d.CanTouch = true, false
			local piece = byObject[d.Name]
			if spec then
				d.CanCollide, d.CanQuery, d.CastShadow = false, false, false
				d:SetAttribute("Role", "decor")
			else
				d.CanQuery = d.CanCollide
				d:SetAttribute("Role", d.CanCollide and V3Builder.colliderRole(d.Name, mode) or "decor")
			end
			if piece then
				d.Color = hexColor(piece.color)
				d:SetAttribute("KitRole", piece.role)
				if piece.role == "water" then liquid(d, ctx.V3) end
			end
		end
	end
	if spec then
		local pivot = m:GetPivot()
		for _, c in ipairs(spec.colliders or {}) do
			local size = Vector3.new(c.size[1], c.size[2], c.size[3]) * scale
			local cf = pivot * CFrame.new(Vector3.new(c.pos[1], c.pos[2], c.pos[3]) * scale)
				* CFrame.fromOrientation(math.rad(c.orient[1]), math.rad(c.orient[2]), math.rad(c.orient[3]))
			local p = Instance.new("Part")
			p.Name = string.sub(c.name, 1, 10) == "Collision_" and c.name or "Collision_" .. c.name
			if c.shape == "cylinder" then
				p.Shape = Enum.PartType.Cylinder
				cf *= CFrame.Angles(0, 0, math.rad(90))
			end
			p.Size, p.CFrame = size, cf
			p.Anchored, p.CanTouch, p.CanCollide, p.CanQuery, p.CastShadow = true, false, true, true, false
			p.Transparency = 1
			p:SetAttribute("Role", V3Builder.colliderRole(c.name, mode))
			p.Parent = m
			count += 1
		end
	end
	ctx.counted(count)
	return count
end

-- fromKit(ctx, into, name, asset, cframe, scale, mode) -> the kit model at `scale` about its pivot, its pivot on
-- `cframe`, with its spec colliders, or nil when the kit lacks the asset.
local function fromKit(ctx, into, name, asset, cframe, scale, mode)
	local m = V3Builder.kitModel(ctx.kit, asset)
	if not m then return nil end
	if math.abs(scale - 1) > 1e-6 then m:ScaleTo(m:GetScale() * scale) end
	m:PivotTo(cframe)
	m.Name = name
	applySpec(ctx, m, ctx.spec and ctx.spec[asset], scale, mode)
	m:SetAttribute("KitAsset", asset)
	m:SetAttribute("KitScale", scale)
	m:SetAttribute("Placeholder", false)
	m.Parent = into
	return m
end

-- Placeholders ------------------------------------------------------------------------------------------------

local TREE_LOOK = {
	CV3_TreeCotton = { trunk = PALETTE.stick, crowns = { PALETTE.cotton, PALETTE.cottonBlue, PALETTE.cotton } },
	CV3_TreeIceCream = { trunk = PALETTE.wafer, crowns = { PALETTE.strawberry, PALETTE.mint, PALETTE.vanilla } },
	CV3_TreeCaramelApple = { trunk = PALETTE.stick, crowns = { PALETTE.apple, PALETTE.caramel } },
}
V3Builder.TREE_KIND = { CV3_TreeCotton = "cotton", CV3_TreeIceCream = "sweet", CV3_TreeCaramelApple = "sweet" }

-- A tree `h` studs tall standing on (x, y, z): a solid trunk collider and decor crowns.
local function placeholderTree(ctx, into, name, asset, x, y, z, h)
	local look = TREE_LOOK[asset]
	local m = model(into, name)
	local trunkR, crownR = math.max(ctx.V3.TREES.trunk * h, 0.6), ctx.V3.TREES.crown * h
	local trunk = drum(ctx, m, "Collision_Trunk", "solid", x, z, y, trunkR, h * 0.5, look.trunk)
	trunk.Transparency = 0
	m.WorldPivot = CFrame.new(x, y, z)
	if asset == "CV3_TreeCotton" then
		ball(ctx, m, "Crown", "decor", Vector3.new(x, y + h * 0.7, z), crownR, look.crowns[1])
		ball(ctx, m, "CrownB", "decor", Vector3.new(x + crownR * 0.6, y + h * 0.62, z + crownR * 0.3), crownR * 0.75, look.crowns[2])
		ball(ctx, m, "CrownC", "decor", Vector3.new(x - crownR * 0.55, y + h * 0.64, z - crownR * 0.35), crownR * 0.7, look.crowns[3])
	elseif asset == "CV3_TreeIceCream" then
		for i, color in ipairs(look.crowns) do
			ball(ctx, m, "Scoop" .. i, "decor", Vector3.new(x, y + h * (0.5 + 0.15 * i), z), crownR * (1.05 - 0.17 * i), color)
		end
		ball(ctx, m, "Cherry", "decor", Vector3.new(x, y + h * 0.97, z), math.max(crownR * 0.18, 0.5), PALETTE.cherry)
	else
		ball(ctx, m, "Apple", "decor", Vector3.new(x, y + h * 0.72, z), crownR, look.crowns[1])
		drum(ctx, m, "Caramel", "decor", x, z, y + h * 0.72, crownR * 1.03, crownR * 0.8, look.crowns[2])
	end
	m:SetAttribute("KitAsset", asset)
	m:SetAttribute("Placeholder", true)
	return m
end

-- An ice-cream mountain of footprint r and height h on the floor at (x, z): a rock base, a slope, a scoop, a drip ring
-- and a cherry. The base, slope and scoop are solid.
local function placeholderMountain(ctx, into, name, asset, x, y, z, r, h)
	local m = model(into, name)
	drum(ctx, m, "Base", "solid", x, z, y, r * 0.85, h * 0.35, PALETTE.rock)
	drum(ctx, m, "Slope", "solid", x, z, y + h * 0.35, r * 0.6, h * 0.3, PALETTE.chocolateLight)
	drum(ctx, m, "Drip", "decor", x, z, y + h * 0.6, r * 0.55, h * 0.06, PALETTE.strawberry)
	ball(ctx, m, "Scoop", "solid", Vector3.new(x, y + h - r * 0.45, z), r * 0.45, PALETTE.vanilla)
	ball(ctx, m, "Cherry", "decor", Vector3.new(x, y + h, z), math.max(r * 0.1, 1), PALETTE.cherry)
	m.WorldPivot = CFrame.new(x, y, z)
	m:SetAttribute("KitAsset", asset)
	m:SetAttribute("Placeholder", true)
	return m
end

-- A house you can walk into: a floor, three walls, a front wall with a door gap facing local -Z, a roof and an
-- interior (a table and a lamp). side is the square's side, height the wall height.
V3Builder.DOOR = { width = 7, height = 9.5 }
local function placeholderHouse(ctx, into, name, asset, cf, side, height)
	local m = model(into, name)
	local wallColor = asset == "CV3_ChocoHouse" and PALETTE.chocoWall or (asset == "CV3_CaramelTower" and PALETTE.towerWall or PALETTE.pinkWall)
	local t, half, D = 1, side / 2, V3Builder.DOOR
	block(ctx, m, "Floor", "floor", Vector3.new(side, 0.4, side), cf * CFrame.new(0, 0.2, 0), PALETTE.biscuit)
	m.WorldPivot = cf
	block(ctx, m, "WallBack", "solid", Vector3.new(side, height, t), cf * CFrame.new(0, height / 2, half - t / 2), wallColor)
	block(ctx, m, "WallLeft", "solid", Vector3.new(t, height, side), cf * CFrame.new(-half + t / 2, height / 2, 0), wallColor)
	block(ctx, m, "WallRight", "solid", Vector3.new(t, height, side), cf * CFrame.new(half - t / 2, height / 2, 0), wallColor)
	local piece = (side - D.width) / 2
	block(ctx, m, "WallFrontL", "solid", Vector3.new(piece, height, t), cf * CFrame.new(-half + piece / 2, height / 2, -half + t / 2), wallColor)
	block(ctx, m, "WallFrontR", "solid", Vector3.new(piece, height, t), cf * CFrame.new(half - piece / 2, height / 2, -half + t / 2), wallColor)
	block(ctx, m, "Lintel", "solid", Vector3.new(D.width, height - D.height, t), cf * CFrame.new(0, D.height + (height - D.height) / 2, -half + t / 2), wallColor)
	block(ctx, m, "Roof", "solid", Vector3.new(side + 2, 1, side + 2), cf * CFrame.new(0, height + 0.5, 0), PALETTE.roofPink)
	local capColor = asset == "CV3_ChocoHouse" and PALETTE.vanilla or PALETTE.strawberry
	ball(ctx, m, "RoofCap", "decor", (cf * CFrame.new(0, height + 1 + side * 0.18, 0)).Position, side * 0.3, capColor)
	block(ctx, m, "Table", "solid", Vector3.new(4, 3, 3), cf * CFrame.new(0, 1.9, half * 0.3), PALETTE.wafer)
	ball(ctx, m, "Lamp", "decor", (cf * CFrame.new(0, height - 1.5, 0)).Position, 0.8, PALETTE.foam)
	m:SetAttribute("KitAsset", asset)
	m:SetAttribute("Placeholder", true)
	return m
end

-- A rainbow licorice arch: rope segments along a half circle in the plane of local X (the span), two solid feet.
local function placeholderLicorice(ctx, into, name, cf, span, height)
	local m = model(into, name)
	local radius = span / 2 * 0.6 -- the kit's inner arch spans 60 % of its width
	local footR = 3
	local lift = math.max(height - radius, 0)
	for i, side in ipairs({ -1, 1 }) do
		local foot = (cf * CFrame.new(side * radius, 0, 0)).Position
		drum(ctx, m, "Collision_Foot" .. i, "solid", foot.X, foot.Z, foot.Y, footR, lift + 1, PALETTE.rainbow[1])
	end
	local segments = 12
	for k = 0, segments - 1 do
		local a0, a1 = math.pi * k / segments, math.pi * (k + 1) / segments
		local p0 = (cf * CFrame.new(math.cos(a0) * radius, lift + math.sin(a0) * radius, 0)).Position
		local p1 = (cf * CFrame.new(math.cos(a1) * radius, lift + math.sin(a1) * radius, 0)).Position
		block(ctx, m, "Rope" .. (k + 1), "decor", Vector3.new(footR * 1.6, footR * 1.6, (p1 - p0).Magnitude + footR),
			CFrame.lookAt((p0 + p1) / 2, p1), PALETTE.rainbow[k % #PALETTE.rainbow + 1])
	end
	m.WorldPivot = cf
	m:SetAttribute("KitAsset", "CV3_LicoriceArch")
	m:SetAttribute("Placeholder", true)
	return m
end

-- The modular cake: three walkable tiers and a ramp from the floor in front (local -Z) up to the first tier.
local function placeholderCake(ctx, into, name, cf, r, height, reach)
	local m = model(into, name)
	local tierH = height / 3
	local base = cf.Position
	local tiers = { { r, PALETTE.strawberry }, { r * 0.65, PALETTE.vanilla }, { r * 0.4, PALETTE.mint } }
	for i, row in ipairs(tiers) do
		drum(ctx, m, "Tier" .. i, "floor", base.X, base.Z, base.Y + (i - 1) * tierH, row[1], tierH, row[2])
	end
	plank(ctx, m, "Ramp", "floor", (cf * CFrame.new(0, 0, -reach)).Position, (cf * CFrame.new(0, tierH, -r + 0.5)).Position,
		6, PALETTE.biscuit)
	ball(ctx, m, "Cherry", "decor", base + Vector3.new(0, height + 1.5, 0), 1.5, PALETTE.cherry)
	m.WorldPivot = cf
	m:SetAttribute("KitAsset", "CV3_CakeBase")
	m:SetAttribute("Placeholder", true)
	return m
end

local function placeholderPlatform(ctx, into, name, asset, x, z, top, r)
	local m = model(into, name)
	drum(ctx, m, "Collision_Slab", "floor", x, z, ctx.top, r, top - ctx.top, PALETTE.biscuit)
	m.WorldPivot = CFrame.new(x, ctx.top, z)
	for i = 1, 2 do
		local a = i * 2.4
		ball(ctx, m, "Chip" .. i, "decor", Vector3.new(x + math.cos(a) * r * 0.5, top, z + math.sin(a) * r * 0.5), math.max(r * 0.1, 0.4), PALETTE.chocolate)
	end
	m:SetAttribute("KitAsset", asset)
	m:SetAttribute("Placeholder", true)
	return m
end

-- Measures ----------------------------------------------------------------------------------------------------

-- A part's centre in the frame and its half extents along the frame's axes.
local function extents(frame, p)
	local cf, s = frame:ToObjectSpace(p.CFrame), p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return cf.Position, (math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z) / 2,
		(math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z) / 2,
		(math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z) / 2
end

-- measureTree(model) -> { trunk, canopy, roof, bottom, height }, from the pivot (the trunk's foot): the horizontal
-- reach of the colliders (Collision_ or colliding parts), of the crown (every other part whose bottom is above
-- 35 % of the height) and of a Roof, the crown's lowest point and the top. The shape WildboundCandyBuilder.treeFits
-- reads.
function V3Builder.measureTree(m)
	local pivot = m:GetPivot()
	local out = { trunk = 0, canopy = 0, roof = 0, bottom = math.huge, height = 0 }
	local pieces = {}
	for _, p in ipairs(m:GetDescendants()) do
		if p:IsA("BasePart") then
			local at, hx, hy, hz = extents(pivot, p)
			out.height = math.max(out.height, at.Y + hy)
			table.insert(pieces, { p = p, at = at, hx = hx, hy = hy, hz = hz })
		end
	end
	for _, e in ipairs(pieces) do
		local p = e.p
		local isBlock = p:IsA("Part") and p.Shape == Enum.PartType.Block
		local reach = math.sqrt(e.at.X ^ 2 + e.at.Z ^ 2) + (isBlock and math.sqrt(e.hx ^ 2 + e.hz ^ 2) or math.max(e.hx, e.hz))
		if p.Name == "Roof" then
			out.roof = math.max(out.roof, reach)
		elseif string.sub(p.Name, 1, 10) == "Collision_" or p.CanCollide then
			out.trunk = math.max(out.trunk, reach)
		elseif e.at.Y - e.hy >= out.height * 0.35 then
			out.canopy = math.max(out.canopy, reach)
			out.bottom = math.min(out.bottom, e.at.Y - e.hy)
		end
	end
	if out.bottom == math.huge then out.bottom = 0 end
	return out
end

local function scaled(m, k)
	return { trunk = m.trunk * k, canopy = m.canopy * k, roof = m.roof, bottom = m.bottom * k, height = m.height * k }
end

-- openSpot(L, V3, x, z, reach, taken, keepOut) -> whether a filler prop of that reach may stand at local (x, z): inside
-- the plot, off the routes, nests, boss ground, portal, entrance, KEEP_CLEAR, the keepOut discs (posts, trap cakes),
-- the v3 pieces and the chocolate, and every { x, z, reach } of taken.
function V3Builder.openSpot(L, V3, x, z, reach, taken, keepOut)
	if L.depth(x, z) < reach + 3 then return false end
	if L.routeDistance(x, z) < L.PATH_WIDTH / 2 + reach + 2 then return false end
	if L.flat(x, z, L.BOSS.x, L.BOSS.z) < L.BOSS.territoryRadius + 4 + reach then return false end
	if L.flat(x, z, L.PORTAL.x, L.PORTAL.z) < 16 + reach then return false end
	if L.flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < 28 + reach then return false end
	for _, spot in ipairs(L.KEEP_CLEAR or {}) do
		if L.flat(x, z, spot.x, spot.z) < spot.r + reach then return false end
	end
	for _, spec in ipairs(L.NESTS) do
		if L.flat(x, z, spec.x, spec.z) < 8 + reach then return false end
	end
	for _, k in ipairs(keepOut or {}) do
		if L.flat(x, z, k.x, k.z) < k.r + reach then return false end
	end
	if not V3.clearOfPieces(x, z, reach, 2) then return false end
	for _, other in ipairs(taken or {}) do
		if L.flat(x, z, other.x, other.z) < other.reach + reach then return false end
	end
	return true
end

-- existingProps(root, L) -> { { x, z, reach } } (plot coordinates): every kit prop and nest already standing under root
-- (the old map's trees, lollipops, gumdrops, sweets, sugar hills, nests, the entrance's pieces and the portal) and every
-- v3 tree and filler prop laid so far, by its measured reach (colliders and Roof, or 70 % of its crown). The filler,
-- the hills and the nudged trees keep off them (review M4).
V3Builder.EXISTING_FOLDERS = { "Lollipops", "CottonTrees", "Gumdrops", "Sweets", "SugarHills", "Nests", "Entrance" }
function V3Builder.existingProps(root, L)
	local out = {}
	local function add(m)
		if not (m:IsA("Model") and not forbidden(m)) then return end
		local ok, pivot = pcall(m.GetPivot, m)
		if not ok then return end
		local measure = V3Builder.measureTree(m)
		local reach = math.max(measure.trunk, measure.roof, measure.canopy * 0.7, 1)
		table.insert(out, { x = pivot.X - L.CENTRE.x, z = pivot.Z - L.CENTRE.z, reach = reach, name = m:GetFullName() })
	end
	for _, name in ipairs(V3Builder.EXISTING_FOLDERS) do
		local f = root:FindFirstChild(name)
		for _, c in ipairs(f and f:GetChildren() or {}) do add(c) end
	end
	local portal = root:FindFirstChild("Portal")
	if portal then add(portal) end
	local holder = root:FindFirstChild("CaramelV3")
	for _, sub in ipairs({ "Trees", "Filler" }) do
		local f = holder and holder:FindFirstChild(sub)
		for _, c in ipairs(f and f:GetChildren() or {}) do add(c) end
	end
	return out
end

-- The pieces ------------------------------------------------------------------------------------------------------

local function tag(m, name)
	CollectionService:AddTag(m, name)
	return m
end

local function layLiquid(ctx, into, poolFromKit)
	local L, V3 = ctx.L, ctx.V3
	local depth, top = V3.LIQUID.depth, ctx.top
	local river = folder(into, "River")
	for i, p in ipairs(V3.RIVER) do
		local x, z = L.CENTRE.x + p[1], L.CENTRE.z + p[2]
		liquid(drum(ctx, river, "Choco_Joint_" .. i, "decor", x, z, top, p[3] / 2, depth, PALETTE.chocolate), V3)
		local q = V3.RIVER[i + 1]
		if q then
			local a, b = ctx.world(p[1], top + depth / 2, p[2]), ctx.world(q[1], top + depth / 2, q[2])
			liquid(block(ctx, river, "Choco_River_" .. i, "decor", Vector3.new(math.min(p[3], q[3]), depth, (b - a).Magnitude),
				CFrame.lookAt((a + b) / 2, b), PALETTE.chocolate), V3)
			-- a low crumble bank on each side (decor), the river's relief
			local dir = (b - a).Unit
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local drop = Vector3.new(0, depth / 2 - 0.45, 0)
			for k, s in ipairs({ -1, 1 }) do
				local offset = side * s * (math.max(p[3], q[3]) / 2 + 1.2)
				block(ctx, river, "Bank_" .. i .. "_" .. k, "decor", Vector3.new(2.4, 0.9, (b - a).Magnitude),
					CFrame.lookAt((a + b) / 2 + offset - drop, b + offset - drop), PALETTE.chocolateLight)
			end
		end
	end
	if not poolFromKit then
		local P = V3.POOL
		liquid(drum(ctx, river, "Choco_Pool", "decor", L.CENTRE.x + P.x, L.CENTRE.z + P.z, top, P.r, depth, PALETTE.chocolate), V3)
	end
	local lake = folder(into, "Lake")
	for i, disc in ipairs(V3.LAKE) do
		liquid(drum(ctx, lake, "Choco_Lake_" .. i, "decor", L.CENTRE.x + disc.x, L.CENTRE.z + disc.z, top, disc.r, depth,
			PALETTE.chocolate), V3)
	end
	return river, lake
end

-- The waterfall: streaks of lighter chocolate in front of the fall that the client slides down (FlowTop and
-- FlowBottom in world Y, FlowPhase), and a foam ring where it meets the pool; with no kit mountain, a placeholder sheet
-- and lip too (named Sheet and Lip: an upgrade to the kit archives them).
local function layWaterfall(ctx, into, sheetToo)
	local V3 = ctx.V3
	local W = V3.WATERFALL
	local m = model(into, "Waterfall")
	local surface = V3.surfaceY(ctx.top)
	local height = ctx.top + W.top - surface -- review m8: W.top is studs over the floor
	local base = ctx.world(W.x, surface, W.z)
	local face = ctx.world(W.faceX, surface, W.faceZ)
	local look = CFrame.lookAt(base, Vector3.new(face.X, base.Y, face.Z))
	if sheetToo then
		liquid(block(ctx, m, "Sheet", "decor", Vector3.new(W.width, height, 1), look * CFrame.new(0, height / 2, 0),
			PALETTE.chocolate), V3)
		ball(ctx, m, "Lip", "decor", (look * CFrame.new(0, height, 0)).Position, W.width * 0.3, PALETTE.chocolateLight)
	end
	local foamAt = (look * CFrame.new(0, 0, -1.5)).Position
	local foam = drum(ctx, m, "Foam", "decor", foamAt.X, foamAt.Z, surface - 0.2, W.width * 0.4, 0.4, PALETTE.foam)
	foam.Transparency = 0.25
	m.PrimaryPart = foam
	local streakLength = height * 0.22
	for i = 1, W.streaks do
		local across = (i - 0.5) / W.streaks - 0.5
		local phase = (i * 0.37) % 1
		local y = height - streakLength / 2 - phase * (height - streakLength)
		local streak = block(ctx, m, "Streak_" .. i, "decor", Vector3.new(W.width * 0.12, streakLength, 0.3),
			look * CFrame.new(across * W.width * 0.8, y, -0.8), PALETTE.chocolateLight)
		streak:SetAttribute("FlowTop", surface + height - streakLength / 2)
		streak:SetAttribute("FlowBottom", surface + streakLength / 2)
		streak:SetAttribute("FlowPhase", phase)
	end
	m:SetAttribute("FlowSpeed", W.flowSpeed)
	m:SetAttribute("FlowHeight", height)
	m:SetAttribute("SplashY", surface + 1)
	return m
end

-- The bridge (V3-D19): deck, end ramps, rails broken by gaps, and in each gap a side ramp down to the floor on both
-- sides.
local function layBridge(ctx, into)
	local L, V3 = ctx.L, ctx.V3
	local B = V3.BRIDGE
	local m = model(into, "Bridge")
	local top = ctx.top
	local y = top + B.deck
	local cx, cz = L.CENTRE.x + B.x, L.CENTRE.z + B.z
	local deck = block(ctx, m, "Deck", "floor", Vector3.new(B.length, 0.4, B.width), CFrame.new(cx, y - 0.2, cz), PALETTE.wafer)
	m.PrimaryPart = deck
	for i, s in ipairs({ -1, 1 }) do
		local edge = Vector3.new(cx + s * B.length / 2, y, cz)
		local foot = Vector3.new(cx + s * (B.length / 2 + B.ramp), top, cz)
		plank(ctx, m, "Ramp_" .. i, "floor", foot, edge, B.width, PALETTE.wafer)
	end
	-- the rail runs between the gaps: from -length/2 to the first gap, between gaps, from the last gap to +length/2
	local cuts = {}
	for _, gx in ipairs(B.gaps) do table.insert(cuts, gx) end
	table.sort(cuts)
	local runs, from = {}, -B.length / 2
	for _, gx in ipairs(cuts) do
		table.insert(runs, { from, gx - B.gapWidth / 2 })
		from = gx + B.gapWidth / 2
	end
	table.insert(runs, { from, B.length / 2 })
	for i, s in ipairs({ -1, 1 }) do
		local railZ = cz + s * (B.width / 2 - 0.4)
		for k, run in ipairs(runs) do
			local length = run[2] - run[1]
			if length > 0.5 then
				local mid = cx + (run[1] + run[2]) / 2
				block(ctx, m, "Rail_" .. i .. "_" .. k, "solid", Vector3.new(length, 2.2, 0.8), CFrame.new(mid, y + 1.1, railZ), PALETTE.chocolate)
				ball(ctx, m, "Cap_" .. i .. "_" .. k, "decor", Vector3.new(mid, y + 2.6, railZ), 0.9, PALETTE.strawberry)
			end
		end
		for k, gx in ipairs(cuts) do
			local edgeZ = cz + s * B.width / 2
			plank(ctx, m, "SideRamp_" .. i .. "_" .. k, "floor", Vector3.new(cx + gx, top, edgeZ + s * B.sideRamp),
				Vector3.new(cx + gx, y, edgeZ), B.gapWidth, PALETTE.wafer)
		end
	end
	m:SetAttribute("Route", B.route)
	return m
end

-- The docks (review m5/m6): a deck from the stand to tipGap studs short of the tip, its top deckOver over the surface,
-- a ramp from rampBack studs behind the stand, two posts by the tip.
local function layDocks(ctx, into)
	local L, V3 = ctx.L, ctx.V3
	local D = V3.DOCK
	local out = folder(into, "Docks")
	local top = ctx.top
	local y = V3.surfaceY(top) + D.deckOver
	for _, d in ipairs(V3.DOCKS) do
		local m = model(out, "Dock_" .. d.id)
		local foot, _, dir, deckEnd = V3.dockPoints(d)
		local stand = ctx.world(d.standX, y, d.standZ)
		local dirV = Vector3.new(dir.x, 0, dir.z)
		local stop = stand + dirV * deckEnd
		local deck = block(ctx, m, "Deck", "floor", Vector3.new(D.deckWidth, 0.4, deckEnd + 1.5),
			CFrame.lookAt((stand + stop) / 2 - dirV * 0.75 - Vector3.new(0, 0.2, 0), stop - Vector3.new(0, 0.2, 0)), PALETTE.wafer)
		m.PrimaryPart = deck
		plank(ctx, m, "Ramp", "floor", ctx.world(foot.x, top, foot.z), stand - dirV * 1.5, D.deckWidth, PALETTE.wafer)
		local side = Vector3.new(-dirV.Z, 0, dirV.X)
		for k, s in ipairs({ -1, 1 }) do
			local post = stop + side * s * (D.deckWidth / 2 + 0.3)
			drum(ctx, m, "Post_" .. k, "decor", post.X, post.Z, top, 0.5, y - top + 2, PALETTE.chocolate)
		end
		m:SetAttribute("DockId", d.id)
		m:SetAttribute("StandX", stand.X)
		m:SetAttribute("StandZ", stand.Z)
		m:SetAttribute("DeckY", y)
		CollectionService:AddTag(m, "WildboundCandyRaftDock")
	end
	return out
end

-- One piece each (shared by layAll and upgradePlaceholders). Each returns the model and whether it is a placeholder.
local function mountainPiece(ctx, into, spec)
	local L, V3 = ctx.L, ctx.V3
	local x, z = L.CENTRE.x + spec.x, L.CENTRE.z + spec.z
	local name = "Mountain_" .. spec.id
	local yaw = V3.faceYaw(spec.x, spec.z, spec.faceX, spec.faceZ)
	local m = fromKit(ctx, into, name, spec.asset, CFrame.new(x, ctx.top, z) * CFrame.Angles(0, yaw, 0), spec.scale, "solid")
	local placeholder = m == nil
	if placeholder then m = placeholderMountain(ctx, into, name, spec.asset, x, ctx.top, z, spec.r, spec.height) end
	m:SetAttribute("MountainId", spec.id)
	tag(m, V3.BEAST_OVERHEAD_TAG)
	return m, placeholder
end

local function housePiece(ctx, into, spec)
	local L, V3 = ctx.L, ctx.V3
	local x, z = L.CENTRE.x + spec.x, L.CENTRE.z + spec.z
	local yaw = V3.faceYaw(spec.x, spec.z, L.JUNCTION.x, L.JUNCTION.z)
	local cf = CFrame.new(x, ctx.top, z) * CFrame.Angles(0, yaw, 0)
	local name = "House_" .. spec.id
	local m = fromKit(ctx, into, name, spec.asset, cf, 1, "solid")
	local placeholder = m == nil
	if placeholder then
		local size = V3.HOUSE_PLACEHOLDER[spec.asset]
		m = placeholderHouse(ctx, into, name, spec.asset, cf, size[1], size[2])
	end
	m:SetAttribute("HouseId", spec.id)
	m:SetAttribute("Interior", true)
	tag(m, V3.BEAST_PASS_TAG)
	return m, placeholder
end

local function licoricePiece(ctx, into)
	local L, V3 = ctx.L, ctx.V3
	local S = V3.LICORICE
	-- the span (the kit's X) runs across the main path: a yaw of 90 degrees turns local X onto -Z
	local cf = CFrame.new(L.CENTRE.x + S.x, ctx.top, L.CENTRE.z + S.z) * CFrame.Angles(0, math.rad(90), 0)
	local m = fromKit(ctx, into, "LicoriceArch", "CV3_LicoriceArch", cf, S.scale, "solid")
	local placeholder = m == nil
	if placeholder then m = placeholderLicorice(ctx, into, "LicoriceArch", cf, S.span, S.height) end
	m:SetAttribute("Height", S.height)
	tag(m, V3.BEAST_OVERHEAD_TAG)
	return m, placeholder
end

local CAKE_ASSETS = { "CV3_CakeBase", "CV3_CakeTop", "CV3_CakeRamp" }
-- The cake: CV3_CakeBase, CV3_CakeTop on its top_tier socket and CV3_CakeRamp with its high_end against the base's
-- ramp_front socket (the ramp's +Z towards the centre); a placeholder unless all three are in the kit.
local function cakePiece(ctx, into)
	local L, V3 = ctx.L, ctx.V3
	local K = V3.CAKE
	local yaw = V3.faceYaw(K.x, K.z, K.faceX, K.faceZ)
	local cf = CFrame.new(L.CENTRE.x + K.x, ctx.top, L.CENTRE.z + K.z) * CFrame.Angles(0, yaw, 0)
	local spec, kit = ctx.spec or {}, ctx.kit
	local whole = kit ~= nil and spec.CV3_CakeBase ~= nil and spec.CV3_CakeRamp ~= nil and spec.CV3_CakeBase.sockets ~= nil
		and spec.CV3_CakeRamp.sockets ~= nil
	for _, asset in ipairs(CAKE_ASSETS) do whole = whole and kit:FindFirstChild(asset) ~= nil end
	local m
	if whole then
		local s = K.scale
		local sockets, high = spec.CV3_CakeBase.sockets, spec.CV3_CakeRamp.sockets.high_end
		m = model(into, "CakeModular")
		fromKit(ctx, m, "CakeBase", "CV3_CakeBase", cf, s, "floor")
		local topAt = sockets.top_tier
		fromKit(ctx, m, "CakeTop", "CV3_CakeTop", cf * CFrame.new(topAt[1] * s, topAt[2] * s, topAt[3] * s), s, "floor")
		local front = sockets.ramp_front
		fromKit(ctx, m, "CakeRamp", "CV3_CakeRamp", cf * CFrame.new((front[1] - high[1]) * s, 0, (front[3] - high[3]) * s), s, "floor")
		m:SetAttribute("Placeholder", false)
		m:SetAttribute("KitAsset", "CV3_CakeBase")
		m.WorldPivot = cf
	else
		m = placeholderCake(ctx, into, "CakeModular", cf, K.r, K.height, K.rampReach)
	end
	tag(m, V3.BEAST_PASS_TAG)
	return m, not whole
end

local function platformPiece(ctx, into, i)
	local L, V3 = ctx.L, ctx.V3
	local spec = V3.PLATFORMS[i]
	local x, z = L.CENTRE.x + spec.x, L.CENTRE.z + spec.z
	local name = "Platform_" .. i
	local m = fromKit(ctx, into, name, spec.asset, CFrame.new(x, ctx.top, z) * CFrame.Angles(0, (i * 1.3) % (2 * math.pi), 0), 1, "floor")
	local placeholder = m == nil
	if placeholder then m = placeholderPlatform(ctx, into, name, spec.asset, x, z, V3.surfaceY(ctx.top) + 0.5, spec.r) end
	m:SetAttribute("PlatformIndex", i)
	return m, placeholder
end

local function hillPiece(ctx, into, name, wx, wz, yaw, r)
	local V3 = ctx.V3
	local m = fromKit(ctx, into, name, "CV3_IceCreamMountain_M", CFrame.new(wx, ctx.top, wz) * CFrame.Angles(0, yaw, 0),
		V3.FILLER.hillScale, "solid")
	local placeholder = m == nil
	if placeholder then
		m = placeholderMountain(ctx, into, name, "CV3_IceCreamMountain_M", wx, ctx.top, wz, r, r * 1.7)
		m.WorldPivot = CFrame.new(wx, ctx.top, wz) * CFrame.Angles(0, yaw, 0)
	end
	m:SetAttribute("Hill", true)
	m:SetAttribute("HillRadius", r)
	tag(m, V3.BEAST_OVERHEAD_TAG)
	return m, placeholder
end

local function hillRadius(ctx)
	local mSpec = ctx.spec and ctx.spec.CV3_IceCreamMountain_M
	return mSpec and math.max(mSpec.size[1], mSpec.size[3]) / 2 * ctx.V3.FILLER.hillScale or 7
end

-- The filler: candy props of the old kit (Kit.place from library) along both banks every bankEvery studs, round each
-- house, and small ice-cream hills by the plot edge. Seeded; each on openSpot, off every prop already standing
-- (deps.existing, or V3Builder.existingProps(root)).
local function layFiller(ctx, into, deps, report, existing)
	local L, V3 = ctx.L, ctx.V3
	local F = V3.FILLER
	local out = folder(into, "Filler")
	local rng = Random.new(V3.SEED)
	local taken = {}
	for _, e in ipairs(existing) do table.insert(taken, { x = e.x, z = e.z, reach = e.reach }) end
	local Kit, library = deps.Kit, deps.library
	local count = 0
	local function candy(x, z, reach)
		if not (Kit and library) then
			report.fillerSkipped += 1
			return
		end
		local asset = F.assets[rng:NextInteger(1, #F.assets)]
		local ok, m = pcall(Kit.place, library, asset,
			CFrame.new(ctx.world(x, ctx.top, z)) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0), rng:NextNumber(0.9, 1.4))
		if not ok or not m then
			report.fillerSkipped += 1
			return
		end
		count += 1
		m.Name = "Filler_" .. count
		applySpec(ctx, m, nil, 1, "solid")
		m:SetAttribute("KitAsset", asset)
		m.Parent = out
		table.insert(taken, { x = x, z = z, reach = reach })
		report.filler += 1
	end
	-- along the banks
	local samples = V3.riverSamples(F.bankEvery)
	for i = 1, #samples - 1 do
		local s, n = samples[i], samples[i + 1]
		local dx, dz = n.x - s.x, n.z - s.z
		local length = math.sqrt(dx * dx + dz * dz)
		if length > 0 then
			local side = i % 2 == 0 and 1 or -1
			local x = s.x - dz / length * side * (s.w / 2 + F.bankOffset)
			local z = s.z + dx / length * side * (s.w / 2 + F.bankOffset)
			if V3Builder.openSpot(L, V3, x, z, F.reach, taken, deps.keepOut) then candy(x, z, F.reach) end
		end
	end
	-- round the houses
	for _, h in ipairs(V3.HOUSES) do
		for _ = 1, F.perHouse do
			local a = rng:NextNumber(0, math.pi * 2)
			local d = h.r + F.reach + 3
			local x, z = h.x + math.cos(a) * d, h.z + math.sin(a) * d
			if V3Builder.openSpot(L, V3, x, z, F.reach, taken, deps.keepOut) then candy(x, z, F.reach) end
		end
	end
	-- small ice-cream hills by the plot edge (the kit's medium mountain scaled down, or a placeholder)
	local hills, tries = 0, 0
	local r = hillRadius(ctx)
	while hills < F.hills and tries < 400 do
		tries += 1
		local edge = rng:NextInteger(1, 4)
		local along = rng:NextNumber(-L.HALF + 20, L.HALF - 20)
		local inset = rng:NextNumber(r + 3, r + 10)
		local x, z
		if edge == 1 then x, z = L.HALF - inset, along
		elseif edge == 2 then x, z = -L.HALF + inset, along
		elseif edge == 3 then x, z = along, L.HALF - inset
		else x, z = along, -L.HALF + inset end
		if V3Builder.openSpot(L, V3, x, z, r, taken, deps.keepOut) then
			hills += 1
			local _, placeholder = hillPiece(ctx, out, "Hill_" .. hills, L.CENTRE.x + x, L.CENTRE.z + z, V3.faceYaw(x, z, 0, 0), r)
			if placeholder then table.insert(report.placeholders, "Hill_" .. hills) end
			table.insert(taken, { x = x, z = z, reach = r })
		end
	end
	report.hills = hills
	return out
end

-- layAll(root, deps) -> report: lays every v3 piece into a new root.CaramelV3 folder (refused when one is there).
-- deps = { Layout, V3, kitV3 (the CandyKitV3 folder or nil), kitSpec (WildboundCandyV3KitSpec or nil), Kit and library
-- (the old kit, for the filler; optional), keepOut (WildboundCandyBuilder.treeKeepOut; optional), existing (the props
-- already standing, { x, z, reach }; default V3Builder.existingProps(root)) }.
-- report = { parts, placeholders = { names }, filler, fillerSkipped, hills }.
function V3Builder.layAll(root, deps)
	assert(typeof(root) == "Instance", "root must be an Instance")
	assert(not forbidden(root), "refusing to touch " .. FORBIDDEN)
	local L, V3 = deps.Layout, deps.V3
	assert(type(L) == "table" and L.VERSION == 3, "needs the Caramelo layout VERSION 3")
	assert(type(V3) == "table" and V3.FOLDER, "needs WildboundCandyV3Layout")
	assert(not root:FindFirstChild(V3.FOLDER), V3.FOLDER .. " already exists: archive it first")
	local ctx = context(L, V3, deps)
	local report = { parts = 0, placeholders = {}, filler = 0, fillerSkipped = 0, hills = 0 }
	local existing = deps.existing or V3Builder.existingProps(root, L)
	local holder = Instance.new("Folder")
	holder.Name = V3.FOLDER
	local ok, failure = pcall(function()
		local mountains = folder(holder, "Mountains")
		local riverFromKit = false
		for _, spec in ipairs(V3.MOUNTAINS) do
			local m, placeholder = mountainPiece(ctx, mountains, spec)
			if placeholder then table.insert(report.placeholders, m.Name) elseif spec.river then riverFromKit = true end
		end
		layLiquid(ctx, holder, riverFromKit)
		layWaterfall(ctx, holder, not riverFromKit)
		layBridge(ctx, holder)
		layDocks(ctx, holder)
		local houses = folder(holder, "Houses")
		for _, spec in ipairs(V3.HOUSES) do
			local m, placeholder = housePiece(ctx, houses, spec)
			if placeholder then table.insert(report.placeholders, m.Name) end
		end
		local _, licoricePlaceholder = licoricePiece(ctx, folder(holder, "Licorice"))
		if licoricePlaceholder then table.insert(report.placeholders, "LicoriceArch") end
		local _, cakePlaceholder = cakePiece(ctx, folder(holder, "Cake"))
		if cakePlaceholder then table.insert(report.placeholders, "CakeModular") end
		local platforms = folder(holder, "Platforms")
		for i in ipairs(V3.PLATFORMS) do
			local m, placeholder = platformPiece(ctx, platforms, i)
			if placeholder then table.insert(report.placeholders, m.Name) end
		end
		folder(holder, "Trees")
		layFiller(ctx, holder, deps, report, existing)
	end)
	if not ok then
		holder.Parent = nil
		error(failure, 0)
	end
	report.parts = ctx.parts
	assert(report.parts <= V3.MAX_NEW_PARTS, "v3 part budget exceeded: " .. report.parts)
	holder:SetAttribute("Version", V3.VERSION)
	holder:SetAttribute("PartCount", report.parts)
	holder:SetAttribute("Placeholders", #report.placeholders)
	holder.Parent = root
	return report
end

-- Planning on a live map -----------------------------------------------------------------------------------------

V3Builder.PROP_FOLDERS = { "Lollipops", "CottonTrees", "Gumdrops", "Sweets", "SugarHills" }

-- plan(root, L, V3) -> { archive = { { instance, why } }, kept }. Read only. Every kit prop (a Model with a KitAsset
-- attribute) of PROP_FOLDERS under root that stands in the chocolate, on or by the bridge (its ramps and side ramps,
-- by its reach) or on a v3 piece (the docks as stand, ramp and deck; its colliders and Roof by their reach, its crown
-- by 70 % of its reach), and the old lake's syrup discs and biscuit bridge tiles, which the chocolate lake and the v3
-- bridge replace. Deterministic (full-name order).
function V3Builder.plan(root, L, V3)
	local plan = { archive = {}, kept = 0 }
	local models = {}
	for _, name in ipairs(V3Builder.PROP_FOLDERS) do
		local f = root:FindFirstChild(name)
		for _, c in ipairs(f and f:GetChildren() or {}) do
			if c:IsA("Model") and type(c:GetAttribute("KitAsset")) == "string" and not forbidden(c) then table.insert(models, c) end
		end
	end
	table.sort(models, function(a, b) return a:GetFullName() < b:GetFullName() end)
	local pieces = V3.pieces()
	for _, m in ipairs(models) do
		local measure, p = V3Builder.measureTree(m), m:GetPivot().Position
		local x, z = p.X - L.CENTRE.x, p.Z - L.CENTRE.z
		local solid = math.max(measure.trunk, measure.roof, 1)
		local visual = math.max(solid, measure.canopy * 0.7)
		local why
		if V3.liquidDistance(x, z) < solid + 1 then why = "in the chocolate" end
		if not why and V3.nearBridge(x, z, visual) then why = "on the bridge" end
		for _, piece in ipairs(pieces) do
			if not why and L.flat(x, z, piece.x, piece.z) < piece.r + visual + 1 then why = "on " .. piece.kind .. " " .. piece.id end
		end
		if why then table.insert(plan.archive, { instance = m, why = why }) else plan.kept += 1 end
	end
	local lake = root:FindFirstChild("Lake")
	if lake and not forbidden(lake) then
		local old = {}
		for _, c in ipairs(lake:GetChildren()) do
			if string.sub(c.Name, 1, 6) == "Syrup_" or string.sub(c.Name, 1, 7) == "Bridge_" then table.insert(old, c) end
		end
		table.sort(old, function(a, b) return a.Name < b.Name end)
		for _, c in ipairs(old) do
			table.insert(plan.archive, { instance = c, why = "replaced by the chocolate lake and the v3 bridge" })
		end
	end
	return plan
end

-- Tree swap -----------------------------------------------------------------------------------------------------

local function countParts(instance)
	local n = 0
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then n += 1 end
	end
	return n
end

-- newTree(ctx, into, name, asset, x, y, z, yaw, height) -> model (kit or placeholder) standing at (x, y, z), and
-- whether it is a placeholder.
local function newTree(ctx, into, name, asset, x, y, z, yaw, height)
	local spec = ctx.spec and ctx.spec[asset]
	if spec and ctx.kit and ctx.kit:FindFirstChild(asset) then
		local m = fromKit(ctx, into, name, asset, CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0), height / spec.size[2], "solid")
		if m then return m, false end
	end
	local p = placeholderTree(ctx, into, name, asset, x, y, z, height)
	p:PivotTo(CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0))
	return p, true
end

-- A La Nube Roof disc into a tree, just inside its crown.
local function seatRoof(roof, tree)
	local pivot = tree:GetPivot()
	local now = V3Builder.measureTree(tree)
	roof.CFrame = CFrame.new(pivot.X, pivot.Y + math.max(now.bottom + 1.5, 7.5), pivot.Z) * CFrame.Angles(0, 0, math.rad(90))
	roof.Parent = tree
end

-- swapTrees(root, deps, archive, dryRun) -> report { swapped = { "old -> new" }, kept = { "name: why" }, parts,
-- placeholders, oldParts, newPartsEstimate }. Every old tree of V3.TREES.map in CottonTrees and Sweets takes its new
-- kind at the same spot and turn, as tall as the old one (heightFactor), fitted by WildboundCandyBuilder.treeFits
-- (deps.Builder), off the v3 pieces and off the filler already laid (review M4): smaller down to minFactor, or nudged
-- by one of nudges in eight directions; else the old tree stays. A cotton tree's Roof disc moves into the new tree (La
-- Nube's cover). The old model goes to archive(instance, why). dryRun: only report (newPartsEstimate from the
-- prototypes). New trees go to root.CaramelV3.Trees (made when missing), marked V3.TREES.attribute = the old kind.
function V3Builder.swapTrees(root, deps, archive, dryRun)
	local L, V3, Builder = deps.Layout, deps.V3, deps.Builder
	assert(Builder and type(Builder.treeFits) == "function", "needs WildboundCandyBuilder.treeFits")
	local T = V3.TREES
	local ctx = context(L, V3, deps)
	local protoCtx = context(L, V3, deps) -- review m8: the measured prototypes are not counted
	local report = { swapped = {}, kept = {}, parts = 0, placeholders = 0, oldParts = 0, newPartsEstimate = 0 }
	local holder = root:FindFirstChild(V3.FOLDER)
	local trees = holder and holder:FindFirstChild("Trees")
	if not dryRun then
		if not holder then holder = folder(root, V3.FOLDER) end
		trees = trees or folder(holder, "Trees")
	end
	-- the filler and hills already laid: a nudged tree keeps off them
	local filler = {}
	local fillerFolder = holder and holder:FindFirstChild("Filler")
	for _, c in ipairs(fillerFolder and fillerFolder:GetChildren() or {}) do
		if c:IsA("Model") then
			local p = c:GetPivot().Position
			local m = V3Builder.measureTree(c)
			table.insert(filler, { x = p.X - L.CENTRE.x, z = p.Z - L.CENTRE.z,
				reach = c:GetAttribute("HillRadius") or math.max(m.trunk, m.canopy * 0.7, 1) })
		end
	end
	local scratch = Instance.new("Folder") -- detached: the measured prototypes
	local measured, protoParts = {}, {}
	local olds = {}
	for _, name in ipairs({ "CottonTrees", "Sweets" }) do
		local f = root:FindFirstChild(name)
		for _, c in ipairs(f and f:GetChildren() or {}) do
			if c:IsA("Model") and T.map[c:GetAttribute("KitAsset")] and not forbidden(c) then table.insert(olds, c) end
		end
	end
	table.sort(olds, function(a, b) return a:GetFullName() < b:GetFullName() end)
	local index = trees and #trees:GetChildren() or 0
	for _, old in ipairs(olds) do
		local oldAsset = old:GetAttribute("KitAsset")
		local asset = T.map[oldAsset]
		local pivot = old:GetPivot()
		local x, z = pivot.X - L.CENTRE.x, pivot.Z - L.CENTRE.z
		local _, yaw = pivot:ToOrientation()
		local height = math.max(V3Builder.measureTree(old).height * T.heightFactor, 4)
		-- the new kind measured once at 10 studs tall, then scaled to this tree's height
		if not measured[asset] then
			local proto = newTree(protoCtx, scratch, "Proto", asset, 0, 0, 0, 0, 10)
			measured[asset] = V3Builder.measureTree(proto)
			protoParts[asset] = countParts(proto)
			proto.Parent = nil
		end
		local m = scaled(measured[asset], height / 10)
		if string.sub(oldAsset, 1, 11) == "TreeCotton_" then m.roof = math.max(m.roof, (Builder.ROOF_DIAMETER or 13) / 2) end
		local function fits(px, pz, f)
			local s = scaled(m, f)
			if not Builder.treeFits(L, px, pz, s, deps.keepOut or {}) then return false end
			for _, e in ipairs(filler) do
				if L.flat(px, pz, e.x, e.z) < e.reach + s.trunk + 1 then return false end
			end
			return V3.clearOfPieces(px, pz, math.max(s.trunk, s.canopy * 0.5), 1)
		end
		local best, bx, bz
		local f = 1
		while f >= T.minFactor - 1e-9 and not best do
			if fits(x, z, f) then best, bx, bz = f, 0, 0 end
			f = math.round((f - T.step) * 1000) / 1000
		end
		if not best then
			for _, d in ipairs(T.nudges) do
				for k = 0, 7 do
					local a = k * math.pi / 4
					local dx, dz = math.round(math.cos(a) * d * 100) / 100, math.round(math.sin(a) * d * 100) / 100
					local g = 1
					while g >= T.minFactor - 1e-9 do
						if fits(x + dx, z + dz, g) then break end
						g = math.round((g - T.step) * 1000) / 1000
					end
					if g >= T.minFactor - 1e-9 and (not best or g > best + 1e-9) then best, bx, bz = g, dx, dz end
				end
				if best then break end
			end
		end
		if not best then
			table.insert(report.kept, old:GetFullName() .. ": no fit for " .. asset)
		else
			table.insert(report.swapped, ("%s -> %s x%.2f moved (%.2f, %.2f)"):format(old:GetFullName(), asset, best, bx, bz))
			report.oldParts += countParts(old)
			report.newPartsEstimate += protoParts[asset] + (old:FindFirstChild("Roof") and 1 or 0)
			if not dryRun then
				index += 1
				local wx, wz = L.CENTRE.x + x + bx, L.CENTRE.z + z + bz
				local tree, isPlaceholder = newTree(ctx, trees, "Tree_" .. index, asset, wx, pivot.Y, wz, yaw, height * best)
				if isPlaceholder then report.placeholders += 1 end
				local roof = old:FindFirstChild("Roof")
				if roof and roof:IsA("BasePart") then seatRoof(roof, tree) end
				tree:SetAttribute(T.attribute, oldAsset)
				tree:SetAttribute("V3Kind", V3Builder.TREE_KIND[asset])
				tree:SetAttribute("CrownTop", V3Builder.measureTree(tree).height)
				archive(old, "swapped for " .. asset)
			end
		end
	end
	scratch.Parent = nil
	report.parts = dryRun and 0 or ctx.parts
	return report
end

-- Kit upgrade (review M2) ------------------------------------------------------------------------------------------

-- upgradePlaceholders(root, deps, archive, dryRun) -> report { upgraded = { names }, waiting = { names }, parts }.
-- On a map already laid (root.CaramelV3), every Placeholder piece whose kit model now exists in deps.kitV3 is laid
-- again from the kit at the same spot, and the placeholder goes to archive(instance, why) (never destroyed): the
-- mountains, houses, licorice, cake, platforms, hills and trees. A tree keeps its spot, turn, height and attributes,
-- and its La Nube Roof moves into the kit tree. When M1 (the river's mountain) is upgraded, the placeholder waterfall
-- sheet and lip and the placeholder pool go too (the kit brings its own). Idempotent: a second run finds no
-- placeholder with a kit model. dryRun: only report.
function V3Builder.upgradePlaceholders(root, deps, archive, dryRun)
	local L, V3 = deps.Layout, deps.V3
	local holder = root:FindFirstChild(V3.FOLDER)
	assert(holder, "no " .. V3.FOLDER .. " folder: run the first migration first")
	assert(not forbidden(holder), "refusing to touch " .. FORBIDDEN)
	local ctx = context(L, V3, deps)
	local report = { upgraded = {}, waiting = {}, parts = 0 }
	local kit = deps.kitV3
	local function has(asset) return kit ~= nil and kit:FindFirstChild(asset) ~= nil and (ctx.spec == nil or ctx.spec[asset] ~= nil) end
	local function swap(old, why, build)
		table.insert(report.upgraded, old:GetFullName())
		if dryRun then return end
		local parent = old.Parent
		archive(old, why)
		build(parent)
	end
	local function placeholders(folderName)
		local f = holder:FindFirstChild(folderName)
		local list = {}
		for _, c in ipairs(f and f:GetChildren() or {}) do
			if c:IsA("Model") and c:GetAttribute("Placeholder") == true and not forbidden(c) then table.insert(list, c) end
		end
		table.sort(list, function(a, b) return a.Name < b.Name end)
		return list
	end
	for _, old in ipairs(placeholders("Mountains")) do
		local id = old:GetAttribute("MountainId")
		for _, spec in ipairs(V3.MOUNTAINS) do
			if spec.id == id then
				if has(spec.asset) then
					swap(old, "upgraded to the kit", function(parent) mountainPiece(ctx, parent, spec) end)
					if spec.river and not dryRun then
						local fall = holder:FindFirstChild("Waterfall")
						for _, name in ipairs({ "Sheet", "Lip" }) do
							local piece = fall and fall:FindFirstChild(name)
							if piece then archive(piece, "the kit mountain brings its own fall") end
						end
						local river = holder:FindFirstChild("River")
						local pool = river and river:FindFirstChild("Choco_Pool")
						if pool then archive(pool, "the kit mountain brings its own pool") end
					end
				else
					table.insert(report.waiting, old.Name .. " (" .. spec.asset .. ")")
				end
			end
		end
	end
	for _, old in ipairs(placeholders("Houses")) do
		local id = old:GetAttribute("HouseId")
		for _, spec in ipairs(V3.HOUSES) do
			if spec.id == id then
				if has(spec.asset) then
					swap(old, "upgraded to the kit", function(parent) housePiece(ctx, parent, spec) end)
				else
					table.insert(report.waiting, old.Name .. " (" .. spec.asset .. ")")
				end
			end
		end
	end
	for _, old in ipairs(placeholders("Licorice")) do
		if has("CV3_LicoriceArch") then
			swap(old, "upgraded to the kit", function(parent) licoricePiece(ctx, parent) end)
		else
			table.insert(report.waiting, old.Name)
		end
	end
	for _, old in ipairs(placeholders("Cake")) do
		if has("CV3_CakeBase") and has("CV3_CakeTop") and has("CV3_CakeRamp") then
			swap(old, "upgraded to the kit", function(parent) cakePiece(ctx, parent) end)
		else
			table.insert(report.waiting, old.Name)
		end
	end
	for _, old in ipairs(placeholders("Platforms")) do
		local i = old:GetAttribute("PlatformIndex")
		local spec = i and V3.PLATFORMS[i]
		if spec and has(spec.asset) then
			swap(old, "upgraded to the kit", function(parent) platformPiece(ctx, parent, i) end)
		elseif spec then
			table.insert(report.waiting, old.Name)
		end
	end
	for _, old in ipairs(placeholders("Filler")) do
		if old:GetAttribute("Hill") == true then
			if has("CV3_IceCreamMountain_M") then
				local pivot = old:GetPivot()
				local _, yaw = pivot:ToOrientation()
				swap(old, "upgraded to the kit", function(parent)
					hillPiece(ctx, parent, old.Name, pivot.X, pivot.Z, yaw, old:GetAttribute("HillRadius") or hillRadius(ctx))
				end)
			else
				table.insert(report.waiting, old.Name)
			end
		end
	end
	for _, old in ipairs(placeholders("Trees")) do
		local asset = old:GetAttribute("KitAsset")
		if has(asset) then
			local pivot = old:GetPivot()
			local _, yaw = pivot:ToOrientation()
			local height = V3Builder.measureTree(old).height
			swap(old, "upgraded to the kit", function(parent)
				local tree = newTree(ctx, parent, old.Name, asset, pivot.X, pivot.Y, pivot.Z, yaw, height)
				local roof = old:FindFirstChild("Roof")
				if roof and roof:IsA("BasePart") then seatRoof(roof, tree) end
				for _, key in ipairs({ V3.TREES.attribute, "V3Kind" }) do tree:SetAttribute(key, old:GetAttribute(key)) end
				tree:SetAttribute("CrownTop", V3Builder.measureTree(tree).height)
			end)
		else
			table.insert(report.waiting, old.Name)
		end
	end
	report.parts = ctx.parts
	return report
end

return V3Builder
