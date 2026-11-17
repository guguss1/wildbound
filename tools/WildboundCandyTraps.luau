-- Caramelo v6 (odd/tasks/wildbound-caramelo-v2.md, V6-D5; the extra decisions are V6-D40 and up in
-- docs/design/wildbound-caramelo-v3-plan.md): sticky caramel traps. About TARGET flat puddles of shiny sticky caramel on
-- open ground beside the routes and near the houses, laid by READING the live map (Workspace.Candy_Bioma_v1; coordinates
-- local to Layout.CENTRE like the layouts), the same way WildboundCandyGrass lays the licorice grass.
--   Each puddle is a Model Trap_<id> (id: H<n> near a house, R<n> beside a route, from the candidate's fixed number, so a
--   puddle keeps its name), tagged TAG, its pivot on the floor at the puddle's centre, attribute Radius = RADIUS (the
--   footprint that slows a creature: WildboundCandyTrapRules.inTrap), TrapId, Near and CandyTrap. It holds PARTS flat
--   plain parts (no asset, no upload), anchored, never colliding, touching or queried, with no shadow.
--   What a puddle does is WildboundCandyTrapRules' (TRAP): a candy creature on the ground inside one moves at 40 % speed
--   while inside and for 2 s after. Players are never slowed.
-- A puddle keeps clear (Traps.blocked) of the chocolate (V3.liquidDistance of the layout module read at sync time, plus
-- the live River and Lake parts), the paths, nests (the layout's, the summit's and the live ones, house nests included),
-- creature posts (WildboundPraderaSites.FIXED), houses, the v3 pieces (mountains, docks, licorice arch, the trap cake),
-- bridges, the boss plaza, the portal, the entrance, the kept-clear grounds, the plot edge, the v5 hide spots (the live
-- HideSpots folder), the v6 licorice grass (the live LicoriceGrass folder) and anything that collides in the live biome
-- within SOLID_CLEAR of its centre. The live map is read through WildboundCandyHideSpots.read (one reader for all three).
-- A blocked puddle is skipped.
-- Called from WildboundCandyNests.applyFlags at server start, after the grass, idempotent: a puddle already there is
-- moved when its place changed, rebuilt when its radius or part count changed, one no longer planned is removed,
-- nothing else touched.
local CollectionService = game:GetService("CollectionService")

local Traps = {}

Traps.TAG = "WildboundCandyTrap" -- WildboundCandyTrapRules.TRAP.tag
Traps.FOLDER = "CaramelTraps"
Traps.GRASS_FOLDER = "LicoriceGrass" -- WildboundCandyGrass.FOLDER
Traps.GRASS_RADIUS = 9 -- a grass patch without a Radius attribute (WildboundCandyGrass.RADIUS)
Traps.TARGET = 8
Traps.MAX_HOUSE = 3 -- at most this many near the houses (one per house); the rest beside the routes
Traps.RADIUS = 6 -- the footprint that slows a creature (WildboundCandyTrapRules.TRAP radiusAttribute)
Traps.LIQUID_MARGIN = 4 -- past the radius, off the chocolate's edge
Traps.ROUTE_MARGIN = 2 -- past the radius, off the path's edge
Traps.NEST_CLEAR = 10 -- past the radius, off a nest's centre
Traps.POST_CLEAR = 14 -- past the radius, off a creature post's centre (its patrol ring is 10)
Traps.PIECE_MARGIN = 2 -- past the radius, off a house's or a v3 piece's footprint disc
Traps.BRIDGE_MARGIN = 3
Traps.HIDE_CLEAR = 8 -- past the radius, off a v5 hide spot's centre (its reach is 6)
Traps.GRASS_MARGIN = 4 -- past both radii, off a licorice grass patch
Traps.PORTAL_CLEAR = 14
Traps.ENTRANCE_CLEAR = 60 -- no puddle at the hub's door
Traps.EDGE_DEPTH = 4 -- past the radius, inside the plot edge
Traps.SPACING = 40 -- between two puddles' centres
Traps.SOLID_CLEAR = 7 -- nothing that collides this close to a puddle's centre, at body height
Traps.SOLID_HEIGHTS = table.freeze({ 1, 3.5 }) -- over the floor
Traps.HOUSE_GAP = 4 -- past the radius, a house try's centre this far out from the house's footprint disc
Traps.HOUSE_TURNS = table.freeze({ 0, 45, -45, 90, -90, 135, -135, 180 }) -- degrees off the junction
Traps.ROUTE_STEP = 24
Traps.ROWS = table.freeze({ 1, 9, 17 }) -- each row this much farther out than the nearest a puddle may stand to a path
Traps.SKIP_ROUTES = table.freeze({ deep = true })
-- The look: one wide disc and LOBES smaller discs round it (an irregular puddle), plus BUBBLES shiny drops on top. Every
-- part stays inside the footprint radius.
Traps.LOBES = 4
Traps.BUBBLES = 3
Traps.PARTS = 1 + Traps.LOBES + Traps.BUBBLES
Traps.THICKNESS = 0.2
Traps.COLORS = table.freeze({
	caramel = Color3.fromRGB(201, 122, 38), dark = Color3.fromRGB(150, 82, 22), shine = Color3.fromRGB(246, 196, 112),
})

local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
local function finite(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end
local function unit(x, z)
	local length = math.sqrt(x * x + z * z)
	if length < 1e-6 then return nil end
	return x / length, z / length
end
local function turned(x, z, degrees)
	local a = math.rad(degrees)
	return x * math.cos(a) - z * math.sin(a), x * math.sin(a) + z * math.cos(a)
end

-- "H<n>" near a house (n = house number * 10 + turn), "R<n>" beside a route (n: the candidate's number along the routes).
function Traps.trapId(kind, n)
	return (kind == "house" and "H" or "R") .. tostring(n)
end

-- The pure context (local coordinates): WildboundCandyHideSpots.context's (nests, posts, houses, the v3 pieces but the
-- houses), plus hides = { { x, z } } (opts.hides: the v5 hide spots), grass = { { x, z, r } } (opts.grass: the licorice
-- patches) and the puddles laid so far. Spots is WildboundCandyHideSpots.
function Traps.context(L, V3, Spots, opts)
	opts = opts or {}
	local ctx = Spots.context(L, V3, opts)
	ctx.hides, ctx.grass, ctx.traps = {}, {}, {}
	for _, h in ipairs(opts.hides or {}) do table.insert(ctx.hides, { x = h.x, z = h.z }) end
	for _, g in ipairs(opts.grass or {}) do table.insert(ctx.grass, { x = g.x, z = g.z, r = g.r or Traps.GRASS_RADIUS }) end
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

-- Why a puddle centred at local (x, z) may not stand there, or nil when it may. noSpacing skips the spacing rule.
function Traps.blocked(x, z, ctx, noSpacing)
	if not (finite(x) and finite(z)) or type(ctx) ~= "table" then return "nowhere" end
	local L, V3, R = ctx.L, ctx.V3, Traps.RADIUS
	if L.depth(x, z) < R + Traps.EDGE_DEPTH then return "edge" end
	if V3.liquidDistance(x, z) < R + Traps.LIQUID_MARGIN then return "liquid" end
	if L.routeDistance(x, z) < L.PATH_WIDTH / 2 + Traps.ROUTE_MARGIN + R then return "route" end
	for _, n in ipairs(ctx.nests) do
		if flat(x, z, n.x, n.z) < R + Traps.NEST_CLEAR then return "nest" end
	end
	for _, p in ipairs(ctx.posts) do
		if flat(x, z, p.x, p.z) < R + Traps.POST_CLEAR then return "post" end
	end
	for _, h in ipairs(ctx.houses) do
		if flat(x, z, h.x, h.z) < h.r + R + Traps.PIECE_MARGIN then return "house" end
	end
	for _, p in ipairs(ctx.pieces) do
		if flat(x, z, p.x, p.z) < p.r + R + Traps.PIECE_MARGIN then return p.kind end
	end
	if V3.nearBridge(x, z, R + Traps.BRIDGE_MARGIN) then return "bridge" end
	if L.TORTA and flat(x, z, L.TORTA.x, L.TORTA.z) < (L.BOSS and L.BOSS.plazaRadius or L.TORTA.radius) + R then return "torta" end
	if L.PORTAL and flat(x, z, L.PORTAL.x, L.PORTAL.z) < Traps.PORTAL_CLEAR + R then return "portal" end
	if L.ENTRANCE and flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < Traps.ENTRANCE_CLEAR then return "entrance" end
	for _, k in ipairs(L.KEEP_CLEAR or {}) do
		if flat(x, z, k.x, k.z) < k.r + R then return "keep" end
	end
	for _, h in ipairs(ctx.hides) do
		if flat(x, z, h.x, h.z) < R + Traps.HIDE_CLEAR then return "hide" end
	end
	for _, g in ipairs(ctx.grass) do
		if flat(x, z, g.x, g.z) < R + g.r + Traps.GRASS_MARGIN then return "grass" end
	end
	if not noSpacing then
		for _, s in ipairs(ctx.traps) do
			if flat(x, z, s.x, s.z) < Traps.SPACING then return "spacing" end
		end
	end
	if #ctx.liquids > 0 or #ctx.solids > 0 then
		local wx, wz, top = ctx.centre.x + x, ctx.centre.z + z, ctx.floorTop
		if boxNear(ctx.liquids, wx, wz, nil, Traps.LIQUID_MARGIN + R) then return "liquid" end
		local heights = {}
		for i, h in ipairs(Traps.SOLID_HEIGHTS) do heights[i] = top + h end
		if boxNear(ctx.solids, wx, wz, heights, Traps.SOLID_CLEAR) then return "solid" end
	end
	return nil
end

-- The house tries: round each house (towards the junction first), HOUSE_GAP past the radius out from its footprint
-- disc. houses = { { id = "H<n>", x, z, r } } (local).
function Traps.houseCandidates(houses, L)
	local list = {}
	local j = L and L.JUNCTION or { x = 0, z = 0 }
	for _, h in ipairs(houses or {}) do
		local n = tonumber(string.match(tostring(h.id), "^H(%d+)$"))
		if n then
			local ux, uz = unit(j.x - h.x, j.z - h.z)
			if not ux then ux, uz = 0, -1 end
			for i, turn in ipairs(Traps.HOUSE_TURNS) do
				local dx, dz = turned(ux, uz, turn)
				local off = h.r + Traps.RADIUS + Traps.HOUSE_GAP
				table.insert(list, { x = h.x + dx * off, z = h.z + dz * off, near = h.id, group = h.id, kind = "house",
					n = n * 10 + i })
			end
		end
	end
	return list
end

-- The route tries: every ROUTE_STEP studs along each route (but SKIP_ROUTES), on both sides, in ROWS just past the
-- path's margin (open ground beside the route). n numbers them in a fixed order (their ids).
function Traps.routeCandidates(L)
	local list, n = {}, 0
	local base = L.PATH_WIDTH / 2 + Traps.ROUTE_MARGIN + Traps.RADIUS
	for _, name in ipairs(L.ROUTE_ORDER) do
		if not Traps.SKIP_ROUTES[name] then
			local points = L.ROUTES[name]
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local length = flat(a.x, a.z, b.x, b.z)
				local ux, uz = unit(b.x - a.x, b.z - a.z)
				if ux then
					local s = Traps.ROUTE_STEP / 2
					while s < length do
						for _, side in ipairs({ 1, -1 }) do
							for _, row in ipairs(Traps.ROWS) do
								n += 1
								local nx, nz = -uz * side, ux * side
								local off = base + row
								table.insert(list, { x = a.x + ux * s + nx * off, z = a.z + uz * s + nz * off, near = name,
									kind = "route", n = n })
							end
						end
						s += Traps.ROUTE_STEP
					end
				end
			end
		end
	end
	return list
end

-- Lays the plan: up to MAX_HOUSE puddles near the houses (one per house), then beside the routes until TARGET; each next
-- puddle the clear try farthest from every puddle laid. Returns { { id, kind, x, z, r, near, n } } and the shortfall
-- ("short:<k>") when fewer fit.
function Traps.plan(ctx)
	local out, skipped = {}, {}
	local function spread(cands, limit)
		local taken, got = {}, 0
		for _, c in ipairs(cands) do
			if c.static == nil then c.static = Traps.blocked(c.x, c.z, ctx, true) or false end
		end
		while got < limit and #out < Traps.TARGET do
			local best, bestD = nil, -1
			for _, c in ipairs(cands) do
				if c.static == false and not c.taken and not (c.group and taken[c.group]) then
					local d, ok = math.huge, true
					for _, s in ipairs(ctx.traps) do
						local gap = flat(c.x, c.z, s.x, s.z)
						if gap < Traps.SPACING then ok = false break end
						d = math.min(d, gap)
					end
					if ok and d > bestD + 1e-9 then best, bestD = c, d end
				end
			end
			if not best then break end
			got += 1
			best.taken = true
			if best.group then taken[best.group] = true end
			best.id, best.r = Traps.trapId(best.kind, best.n), Traps.RADIUS
			table.insert(out, best)
			table.insert(ctx.traps, best)
		end
	end
	spread(Traps.houseCandidates(ctx.houses, ctx.L), Traps.MAX_HOUSE)
	spread(Traps.routeCandidates(ctx.L), Traps.TARGET)
	if #out < Traps.TARGET then table.insert(skipped, ("short:%d"):format(Traps.TARGET - #out)) end
	return out, skipped
end

-- The live map under `root` into a context (WildboundCandyHideSpots.read, then the live v5 hide spots and the live
-- licorice grass from their folders). Returns ctx.
function Traps.read(root, L, V3, Spots, opts)
	opts = opts or {}
	local ctx = Spots.read(root, L, V3, opts)
	ctx.hides, ctx.grass, ctx.traps = {}, {}, {}
	local C = L.CENTRE
	local spots = root:FindFirstChild(Spots.FOLDER)
	for _, m in ipairs(spots and spots:GetChildren() or {}) do
		if m:IsA("Model") then
			local p = m:GetPivot().Position
			table.insert(ctx.hides, { x = p.X - C.x, z = p.Z - C.z })
		end
	end
	local grass = root:FindFirstChild(Traps.GRASS_FOLDER)
	for _, m in ipairs(grass and grass:GetChildren() or {}) do
		if m:IsA("Model") then
			local p = m:GetPivot().Position
			local r = m:GetAttribute("Radius")
			table.insert(ctx.grass, { x = p.X - C.x, z = p.Z - C.z, r = finite(r) and r > 0 and r or Traps.GRASS_RADIUS })
		end
	end
	-- (our own puddles never collide, so the reader never counts them as solids)
	return ctx
end

-- The world frame of a planned puddle: on the floor at its centre.
function Traps.frame(trap, ctx)
	return CFrame.new(ctx.centre.x + trap.x, ctx.floorTop, ctx.centre.z + trap.z)
end

-- A disc lying flat (a Cylinder's axis is its X).
local LYING = CFrame.Angles(0, 0, math.rad(90))
local function part(model, name, shape, size, cframe, color, reflect)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.CFrame, p.Color = name, shape, size, cframe, color
	p.Material = Enum.Material.SmoothPlastic
	p.Reflectance = reflect or 0
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.Parent = model
	return p
end

-- A detached puddle model at world frame cf: a wide caramel disc, LOBES darker discs round its rim and BUBBLES shiny
-- drops (no random, the same puddle every start). Every part stays within the footprint radius.
function Traps.build(trap, cf)
	local model = Instance.new("Model")
	model.Name = "Trap_" .. trap.id
	local R = trap.r or Traps.RADIUS
	local T = Traps.THICKNESS
	part(model, "Pool", Enum.PartType.Cylinder, Vector3.new(T, R * 1.7, R * 1.7), cf * CFrame.new(0, T / 2 + 0.02, 0) * LYING,
		Traps.COLORS.caramel, 0.25)
	for i = 0, Traps.LOBES - 1 do
		local angle = i * math.pi * 2 / Traps.LOBES + 0.4
		local d = R * 0.55
		local size = R * 0.8 -- its rim reaches R * 0.95
		part(model, "Lobe", Enum.PartType.Cylinder, Vector3.new(T, size, size),
			cf * CFrame.new(math.cos(angle) * d, T / 2 - 0.02, math.sin(angle) * d) * LYING, Traps.COLORS.dark, 0.15)
	end
	for i = 0, Traps.BUBBLES - 1 do
		local angle = i * 2.4 + 1
		local d = R * (0.2 + 0.18 * i)
		local s = 0.5 + 0.15 * i
		part(model, "Bubble", Enum.PartType.Ball, Vector3.new(s, s, s),
			cf * CFrame.new(math.cos(angle) * d, T + 0.1, math.sin(angle) * d), Traps.COLORS.shine, 0.4)
	end
	model.WorldPivot = cf
	model:SetAttribute("TrapId", trap.id)
	model:SetAttribute("Radius", R)
	model:SetAttribute("Near", trap.near)
	model:SetAttribute("CandyTrap", true)
	CollectionService:AddTag(model, Traps.TAG)
	return model
end

local function lookup(name)
	local module = game:GetService("ServerStorage"):FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, loaded = pcall(require, module)
	return ok and type(loaded) == "table" and loaded or nil
end

-- The server's start step (through WildboundCandyNests.applyFlags, after the grass). L, V3 and opts.Spots default to
-- ServerStorage's WildboundCandyLayout, WildboundCandyV3Layout and WildboundCandyHideSpots (read now, so a widened river
-- is respected); opts = { posts, Sites, Spots } as WildboundCandyHideSpots.read takes them. Nothing happens without the
-- v3 biome (root.CaramelV3). Returns how many puddles changed (laid, moved, rebuilt, retagged or removed), the skipped
-- notes, how many stand and their part count.
function Traps.sync(root, L, V3, opts)
	if typeof(root) ~= "Instance" then return 0, {}, 0, 0 end
	L = L or lookup("WildboundCandyLayout")
	V3 = V3 or lookup("WildboundCandyV3Layout")
	opts = opts or {}
	local Spots = opts.Spots or lookup("WildboundCandyHideSpots")
	if type(L) ~= "table" or type(V3) ~= "table" or type(Spots) ~= "table" or not root:FindFirstChild(V3.FOLDER) then
		return 0, {}, 0, 0
	end
	local ctx = Traps.read(root, L, V3, Spots, opts)
	local plan, skipped = Traps.plan(ctx)
	local folder = root:FindFirstChild(Traps.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Traps.FOLDER
		folder.Parent = root
	end
	local changed, want = 0, {}
	for _, trap in ipairs(plan) do
		local name = "Trap_" .. trap.id
		want[name] = true
		local cf = Traps.frame(trap, ctx)
		local old = folder:FindFirstChild(name)
		if old and (old:GetAttribute("Radius") ~= trap.r or #old:GetChildren() ~= Traps.PARTS) then
			old:Destroy()
			old = nil
		end
		if old then
			if (old:GetPivot().Position - cf.Position).Magnitude > 0.5 then
				old:PivotTo(cf)
				changed += 1
			end
			if not CollectionService:HasTag(old, Traps.TAG) then
				CollectionService:AddTag(old, Traps.TAG)
				changed += 1
			end
		else
			Traps.build(trap, cf).Parent = folder
			changed += 1
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^Trap_[HR]%d+$") and not want[child.Name] then
			child:Destroy()
			changed += 1
		end
	end
	return changed, skipped, #plan, #plan * Traps.PARTS
end

return Traps
