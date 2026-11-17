-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D1; the extra decisions are V6-D10 and up in
-- docs/design/wildbound-caramelo-v3-plan.md): tall licorice grass. About TARGET patches of tall black and red licorice
-- blades in the open meadows beside the routes, laid by READING the live map (Workspace.Candy_Bioma_v1; coordinates
-- local to Layout.CENTRE like the layouts), the same way WildboundCandyHideSpots lays the v5 hide spots.
--   Each patch is a Model Grass_G<n> (n: the candidate's number along the routes, so a patch keeps its name), tagged TAG,
--   its pivot on the floor at the patch's centre, attribute Radius = RADIUS (the footprint that hides a player:
--   WildboundCandyHiding.inGrass), PatchId and CandyGrass. It holds BLADES thin plain parts (no asset, no upload),
--   anchored, never colliding, touching or queried, with no shadow.
--   What the grass does is WildboundCandyHiding's (GRASS): a player in a patch who is not sprinting is seen by the candy
--   creatures only within 10 studs.
-- A patch keeps clear (Grass.blocked) of the chocolate (V3.liquidDistance of the layout module read at sync time, plus
-- the live River and Lake parts), the paths, nests (the layout's, the summit's and the live ones, house nests included),
-- creature posts (WildboundPraderaSites.FIXED), houses, the v3 pieces (mountains, docks, licorice arch, the trap cake),
-- bridges, the boss plaza, the portal, the entrance, the kept-clear grounds, the plot edge, the v5 hide spots (the live
-- HideSpots folder) and anything that collides in the live biome within SOLID_CLEAR of its centre. The live map is read
-- through WildboundCandyHideSpots.read (one reader for both). A blocked patch is skipped.
-- Called from WildboundCandyNests.applyFlags at server start, after the hide spots, idempotent: a patch already there is
-- moved when its place changed, rebuilt when its radius changed, one no longer planned is removed, nothing else touched.
local CollectionService = game:GetService("CollectionService")

local Grass = {}

Grass.TAG = "WildboundCandyGrass" -- WildboundCandyHiding.GRASS.tag
Grass.FOLDER = "LicoriceGrass"
Grass.TARGET = 10
Grass.RADIUS = 9 -- the footprint that hides a player (WildboundCandyHiding.GRASS radiusAttribute)
Grass.BLADES = 34 -- parts per patch (at most 40)
Grass.LIQUID_MARGIN = 4 -- past the radius, off the chocolate's edge
Grass.ROUTE_MARGIN = 2 -- past the radius, off the path's edge
-- past the radius, off a nest's centre. V6-D7 (2026-11-17): 12 laid only 5 to 7 of the 10 patches on the live map; 8
-- lays all 10 (a patch's edge still 8 studs from a nest's centre, outside its bowl and ring)
Grass.NEST_CLEAR = 8
Grass.POST_CLEAR = 14 -- past the radius, off a creature post's centre (its patrol ring is 10)
Grass.PIECE_MARGIN = 2 -- past the radius, off a house's or a v3 piece's footprint disc
Grass.BRIDGE_MARGIN = 3
Grass.HIDE_CLEAR = 10 -- past the radius, off a v5 hide spot's centre (its reach is 6)
Grass.PORTAL_CLEAR = 14
Grass.ENTRANCE_CLEAR = 60 -- no grass at the hub's door
Grass.EDGE_DEPTH = 4 -- past the radius, inside the plot edge
Grass.SPACING = 40 -- between two patches' centres
Grass.SOLID_CLEAR = 7 -- nothing that collides this close to a patch's centre, at body height
Grass.SOLID_HEIGHTS = table.freeze({ 1, 3.5 }) -- over the floor
Grass.LIQUID_FOLDERS = table.freeze({ "River", "Lake" })
Grass.ROUTE_STEP = 24
Grass.ROWS = table.freeze({ 1, 13 }) -- each row this much farther out than the nearest a patch may stand to a path
Grass.SKIP_ROUTES = table.freeze({ deep = true })
Grass.BLADE_HEIGHT = table.freeze({ min = 5.2, max = 7.6 }) -- a character is about 5 tall
Grass.BLADE_WIDTH = 0.45
Grass.BLADE_DEPTH = 0.3
Grass.COLORS = table.freeze({
	black = Color3.fromRGB(32, 24, 30), red = Color3.fromRGB(196, 30, 48), redDark = Color3.fromRGB(150, 22, 40),
})

local GOLDEN = math.pi * (3 - math.sqrt(5))
local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil end
	return x / length, z / length
end

function Grass.patchId(n)
	return "G" .. tostring(n)
end

-- The pure context (local coordinates): WildboundCandyHideSpots.context's (nests, posts, houses, the v3 pieces but the
-- houses), plus hides = { { x, z } } (opts.hides: the v5 hide spots) and the patches laid so far. Spots is
-- WildboundCandyHideSpots.
function Grass.context(L, V3, Spots, opts)
	opts = opts or {}
	local ctx = Spots.context(L, V3, opts)
	ctx.hides, ctx.patches = {}, {}
	for _, h in ipairs(opts.hides or {}) do table.insert(ctx.hides, { x = h.x, z = h.z }) end
	return ctx
end

-- The flat distance from (x, z) at height y to a box { cframe, size }, or nil when y is above or under it.
local function boxGap(box, x, y, z)
	local p = Vector3.new(x, y, z)
	local l = box.cframe:PointToObjectSpace(p)
	local h = box.size / 2
	local q = box.cframe:PointToWorldSpace(Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y),
		math.clamp(l.Z, -h.Z, h.Z)))
	if math.abs(q.Y - y) > 1e-3 then return nil end
	return Vector2.new(q.X - x, q.Z - z).Magnitude
end
local function boxNear(boxes, wx, wz, heights, clear)
	for _, box in ipairs(boxes) do
		local c = box.cframe.Position
		if flat(c.X, c.Z, wx, wz) - box.reach <= clear then
			for _, y in ipairs(heights or { c.Y }) do
				local g = boxGap(box, wx, y, wz)
				if g and g < clear then return box.name end
			end
		end
	end
	return nil
end

-- Why a patch centred at local (x, z) may not stand there, or nil when it may. noSpacing skips the spacing rule.
function Grass.blocked(x, z, ctx, noSpacing)
	if not (finite(x) and finite(z)) or type(ctx) ~= "table" then return "nowhere" end
	local L, V3, R = ctx.L, ctx.V3, Grass.RADIUS
	if L.depth(x, z) < R + Grass.EDGE_DEPTH then return "edge" end
	if V3.liquidDistance(x, z) < R + Grass.LIQUID_MARGIN then return "liquid" end
	if L.routeDistance(x, z) < L.PATH_WIDTH / 2 + Grass.ROUTE_MARGIN + R then return "route" end
	for _, n in ipairs(ctx.nests) do
		if flat(x, z, n.x, n.z) < R + Grass.NEST_CLEAR then return "nest" end
	end
	for _, p in ipairs(ctx.posts) do
		if flat(x, z, p.x, p.z) < R + Grass.POST_CLEAR then return "post" end
	end
	for _, h in ipairs(ctx.houses) do
		if flat(x, z, h.x, h.z) < h.r + R + Grass.PIECE_MARGIN then return "house" end
	end
	for _, p in ipairs(ctx.pieces) do
		if flat(x, z, p.x, p.z) < p.r + R + Grass.PIECE_MARGIN then return p.kind end
	end
	if V3.nearBridge(x, z, R + Grass.BRIDGE_MARGIN) then return "bridge" end
	if L.TORTA and flat(x, z, L.TORTA.x, L.TORTA.z) < (L.BOSS and L.BOSS.plazaRadius or L.TORTA.radius) + R then return "torta" end
	if L.PORTAL and flat(x, z, L.PORTAL.x, L.PORTAL.z) < Grass.PORTAL_CLEAR + R then return "portal" end
	if L.ENTRANCE and flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < Grass.ENTRANCE_CLEAR then return "entrance" end
	for _, k in ipairs(L.KEEP_CLEAR or {}) do
		if flat(x, z, k.x, k.z) < k.r + R then return "keep" end
	end
	for _, h in ipairs(ctx.hides) do
		if flat(x, z, h.x, h.z) < R + Grass.HIDE_CLEAR then return "hide" end
	end
	if not noSpacing then
		for _, s in ipairs(ctx.patches) do
			if flat(x, z, s.x, s.z) < Grass.SPACING then return "spacing" end
		end
	end
	if #ctx.liquids > 0 or #ctx.solids > 0 then
		local wx, wz, top = ctx.centre.x + x, ctx.centre.z + z, ctx.floorTop
		if boxNear(ctx.liquids, wx, wz, nil, Grass.LIQUID_MARGIN + R) then return "liquid" end
		local heights = {}
		for i, h in ipairs(Grass.SOLID_HEIGHTS) do heights[i] = top + h end
		if boxNear(ctx.solids, wx, wz, heights, Grass.SOLID_CLEAR) then return "solid" end
	end
	return nil
end

-- The tries: every ROUTE_STEP studs along each route (but SKIP_ROUTES), on both sides, in ROWS just past the path's
-- margin (open meadow beside the route). n numbers them in a fixed order (their ids).
function Grass.candidates(L)
	local list, n = {}, 0
	local base = L.PATH_WIDTH / 2 + Grass.ROUTE_MARGIN + Grass.RADIUS
	for _, name in ipairs(L.ROUTE_ORDER) do
		if not Grass.SKIP_ROUTES[name] then
			local points = L.ROUTES[name]
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local length = flat(a.x, a.z, b.x, b.z)
				local ux, uz = unit(b.x - a.x, b.z - a.z)
				if ux then
					local s = Grass.ROUTE_STEP / 2
					while s < length do
						for _, side in ipairs({ 1, -1 }) do
							for _, row in ipairs(Grass.ROWS) do
								n += 1
								local nx, nz = -uz * side, ux * side
								local off = base + row
								table.insert(list, { x = a.x + ux * s + nx * off, z = a.z + uz * s + nz * off, near = name, n = n })
							end
						end
						s += Grass.ROUTE_STEP
					end
				end
			end
		end
	end
	return list
end

-- Lays the plan: each next patch the clear try farthest from every patch laid, until TARGET. Returns
-- { { id, x, z, r, near, n } } and the shortfall ("short:<k>") when fewer fit.
function Grass.plan(ctx)
	local out, skipped = {}, {}
	local cands = Grass.candidates(ctx.L)
	for _, c in ipairs(cands) do c.static = Grass.blocked(c.x, c.z, ctx, true) or false end
	while #out < Grass.TARGET do
		local best, bestD = nil, -1
		for _, c in ipairs(cands) do
			if c.static == false and not c.taken then
				local d, ok = math.huge, true
				for _, s in ipairs(ctx.patches) do
					local gap = flat(c.x, c.z, s.x, s.z)
					if gap < Grass.SPACING then ok = false break end
					d = math.min(d, gap)
				end
				if ok and d > bestD + 1e-9 then best, bestD = c, d end
			end
		end
		if not best then break end
		best.taken = true
		best.id, best.r = Grass.patchId(best.n), Grass.RADIUS
		table.insert(out, best)
		table.insert(ctx.patches, best)
	end
	if #out < Grass.TARGET then table.insert(skipped, ("short:%d"):format(Grass.TARGET - #out)) end
	return out, skipped
end

-- The live map under `root` into a context (WildboundCandyHideSpots.read, then the live v5 hide spots from its
-- folder). Returns ctx.
function Grass.read(root, L, V3, Spots, opts)
	opts = opts or {}
	local ctx = Spots.read(root, L, V3, opts)
	ctx.hides, ctx.patches = {}, {}
	local C = L.CENTRE
	local spots = root:FindFirstChild(Spots.FOLDER)
	for _, m in ipairs(spots and spots:GetChildren() or {}) do
		if m:IsA("Model") then
			local p = m:GetPivot().Position
			table.insert(ctx.hides, { x = p.X - C.x, z = p.Z - C.z })
		end
	end
	-- (our own blades never collide, so the reader never counts them as solids)
	return ctx
end

-- The world frame of a planned patch: on the floor at its centre.
function Grass.frame(patch, ctx)
	return CFrame.new(ctx.centre.x + patch.x, ctx.floorTop, ctx.centre.z + patch.z)
end

-- A detached patch model at world frame cf: BLADES thin blades on a sunflower spiral over the footprint (no random,
-- the same patch every start), black and red, each a little tilted.
function Grass.build(patch, cf)
	local model = Instance.new("Model")
	model.Name = "Grass_" .. patch.id
	local R = patch.r or Grass.RADIUS
	local H = Grass.BLADE_HEIGHT
	for i = 0, Grass.BLADES - 1 do
		local f = (i + 0.5) / Grass.BLADES
		local radius = (R - 0.4) * math.sqrt(f)
		local angle = i * GOLDEN
		local h = H.min + (H.max - H.min) * (((i + 1) * 0.618034) % 1)
		local tiltX = math.rad(((i * 0.371) % 1) * 16 - 8)
		local tiltZ = math.rad(((i * 0.529) % 1) * 16 - 8)
		local blade = Instance.new("Part")
		blade.Name = "Blade"
		blade.Size = Vector3.new(Grass.BLADE_WIDTH, h, Grass.BLADE_DEPTH)
		blade.CFrame = cf * CFrame.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			* CFrame.Angles(0, angle, 0) * CFrame.Angles(tiltX, 0, tiltZ) * CFrame.new(0, h / 2 - 0.2, 0)
		local pick = i % 3
		blade.Color = pick == 0 and Grass.COLORS.red or (pick == 1 and Grass.COLORS.black or (i % 2 == 0 and Grass.COLORS.redDark or Grass.COLORS.black))
		blade.Material = Enum.Material.SmoothPlastic
		blade.TopSurface, blade.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		blade.Anchored, blade.CanCollide, blade.CanTouch, blade.CanQuery, blade.CastShadow = true, false, false, false, false
		blade.Parent = model
	end
	model.WorldPivot = cf
	model:SetAttribute("PatchId", patch.id)
	model:SetAttribute("Radius", R)
	model:SetAttribute("Near", patch.near)
	model:SetAttribute("CandyGrass", true)
	CollectionService:AddTag(model, Grass.TAG)
	return model
end

local function lookup(name)
	local module = game:GetService("ServerStorage"):FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, loaded = pcall(require, module)
	return ok and type(loaded) == "table" and loaded or nil
end

-- The server's start step (through WildboundCandyNests.applyFlags, after the hide spots). L, V3 and opts.Spots default
-- to ServerStorage's WildboundCandyLayout, WildboundCandyV3Layout and WildboundCandyHideSpots (read now, so a widened
-- river is respected); opts = { posts, Sites, Spots } as WildboundCandyHideSpots.read takes them. Nothing happens
-- without the v3 biome (root.CaramelV3). Returns how many patches changed (laid, moved, rebuilt, retagged or removed),
-- the skipped notes, how many stand and their part count.
function Grass.sync(root, L, V3, opts)
	if typeof(root) ~= "Instance" then return 0, {}, 0, 0 end
	L = L or lookup("WildboundCandyLayout")
	V3 = V3 or lookup("WildboundCandyV3Layout")
	opts = opts or {}
	local Spots = opts.Spots or lookup("WildboundCandyHideSpots")
	if type(L) ~= "table" or type(V3) ~= "table" or type(Spots) ~= "table" or not root:FindFirstChild(V3.FOLDER) then
		return 0, {}, 0, 0
	end
	local ctx = Grass.read(root, L, V3, Spots, opts)
	local plan, skipped = Grass.plan(ctx)
	local folder = root:FindFirstChild(Grass.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Grass.FOLDER
		folder.Parent = root
	end
	local changed, want = 0, {}
	for _, patch in ipairs(plan) do
		local name = "Grass_" .. patch.id
		want[name] = true
		local cf = Grass.frame(patch, ctx)
		local old = folder:FindFirstChild(name)
		if old and (old:GetAttribute("Radius") ~= patch.r or #old:GetChildren() ~= Grass.BLADES) then
			old:Destroy()
			old = nil
		end
		if old then
			if (old:GetPivot().Position - cf.Position).Magnitude > 0.5 then
				old:PivotTo(cf)
				changed += 1
			end
			if not CollectionService:HasTag(old, Grass.TAG) then
				CollectionService:AddTag(old, Grass.TAG)
				changed += 1
			end
		else
			Grass.build(patch, cf).Parent = folder
			changed += 1
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^Grass_G%d+$") and not want[child.Name] then
			child:Destroy()
			changed += 1
		end
	end
	return changed, skipped, #plan, #plan * Grass.BLADES
end

return Grass
