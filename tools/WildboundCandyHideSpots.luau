-- Caramelo v5 (odd/tasks/wildbound-caramelo-v2.md, V5-D1, owner 2026-11-17: "the mountains or something should let you
-- hide"): hiding places in the candy kingdom for the existing hide-spot system (WildboundWorld binds every Model tagged
-- WildboundHideSpot named HideSpot_H<nn> with a HideZone part holding a ProximityPrompt: the "Esconderse" prompt, the
-- WildboundHidden attribute, WildboundHide's 45 s stay and 8 s cooldown). About TARGET spots, laid by READING the live
-- map (Workspace.Candy_Bioma_v1; coordinates local to Layout.CENTRE like the layouts):
--   cave   a hollow at the foot of each ice-cream mountain (CaramelV3.Mountains.Mountain_<id>, attribute MountainId), on
--          the side that faces the play area (the plot centre), turned round the mountain when that side is blocked;
--          ids H51..H56 (M1..M6). A soft ice-cream scoop the player crouches in, its dark opening facing out.
--   house  a cotton-candy bush or a hollow cake stump beside a house (CaramelV3.Houses, HouseId), at most MAX_HOUSE,
--          spread out (each next one the farthest from those laid); ids H61..H67 (H1..H7).
--   route  bushes and stumps beside the routes (Layout.ROUTES), spread out the same way until TARGET; ids H71 and up
--          (the candidate's number along the routes).
-- The forest's spots are H01..H10 (tools/build-wildbound-p0-map.luau), so the two sets never share a name.
-- A spot keeps clear (Spots.blocked) of the chocolate (V3.liquidDistance of the layout module read at sync time, plus
-- the live River and Lake parts, LIQUID_MARGIN past its reach: another agent is widening the river), the paths, nests
-- (the layout's, the summit's and the live ones, house nests included), creature posts (WildboundPraderaSites.FIXED),
-- houses, the v3 pieces (mountains, docks, licorice, the trap cake), bridges, the boss plaza, the portal, the entrance,
-- the kept-clear grounds and the plot edge, and of anything that collides in the live biome within SOLID_CLEAR (a
-- player steps out of a spot Hide.EXIT_DISTANCE, 5.5 studs, from its centre). A blocked spot is skipped. Every part of
-- a spot is plain (kit decor from ServerStorage.WildboundAssets.CandyKit when present, through WildboundCandyKit, as
-- WildboundCandyHouseNests does) and never collides. No asset upload.
-- Called from WildboundCandyNests.applyFlags at server start (after the house nests), idempotent: a spot already there
-- is moved when its place changed, one no longer planned (blocked now) is removed, nothing else is touched.
local CollectionService = game:GetService("CollectionService")

local Spots = {}

Spots.TAG = "WildboundHideSpot"
Spots.FOLDER = "HideSpots"
Spots.TARGET = 14
Spots.MAX_HOUSE = 4
Spots.ID = table.freeze({ cave = 50, house = 60, route = 70 })
-- A spot's reach: its zone (5 wide), its decor (about 4 from the centre) and where a player steps out (5.5).
Spots.REACH = 6
Spots.LIQUID_MARGIN = 6 -- past the reach, off the chocolate's edge
Spots.ROUTE_MARGIN = 3 -- past the reach, off the path's edge
Spots.NEST_CLEAR = 8 -- past the reach, off a nest's centre
Spots.POST_CLEAR = 16 -- a creature post's patrol ring (its centre this far)
Spots.PIECE_MARGIN = 1 -- past the reach, off a house's or a v3 piece's footprint disc
Spots.BRIDGE_MARGIN = 2
Spots.PORTAL_CLEAR = 14
Spots.ENTRANCE_CLEAR = 60 -- no hiding at the hub's door
Spots.EDGE_DEPTH = 8
Spots.SPACING = 26
Spots.SOLID_CLEAR = 6.5
Spots.SOLID_HEIGHTS = table.freeze({ 1, 3.5, 6 }) -- over the floor
Spots.LIQUID_FOLDERS = table.freeze({ "River", "Lake" })
Spots.CAVE_GAPS = table.freeze({ 7.5, 9.5, 12 }) -- a cave's centre this far out from its mountain's footprint disc
Spots.CAVE_TURNS = table.freeze({ 0, 20, -20, 40, -40, 60, -60, 80, -80, 100, -100 }) -- degrees off the plot centre
Spots.HOUSE_GAP = 8 -- a house spot's centre this far out from the house's footprint disc
Spots.HOUSE_TURNS = table.freeze({ 0, 45, -45, 90, -90, 135, -135, 180 }) -- degrees off the junction
Spots.ROUTE_STEP = 30
Spots.SKIP_ROUTES = table.freeze({ deep = true })
Spots.ZONE_SIZE = Vector3.new(5, 3, 5)
Spots.PROMPT_DISTANCE = 7
Spots.PROMPT_HOLD = 0.4
local COLORS = {
	scoop = Color3.fromRGB(255, 214, 230), drip = Color3.fromRGB(244, 90, 153), dark = Color3.fromRGB(60, 36, 26),
	cotton = Color3.fromRGB(255, 150, 190), cottonLight = Color3.fromRGB(255, 195, 220), cottonMid = Color3.fromRGB(255, 173, 208),
	sponge = Color3.fromRGB(248, 191, 102), icing = Color3.fromRGB(255, 247, 238), cherry = Color3.fromRGB(224, 38, 60),
	hollow = Color3.fromRGB(90, 52, 34),
}

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

-- "H" .. (ID[kind] + n): caves H51.., houses H61.., routes H71...
function Spots.spotId(kind, n)
	return "H" .. tostring(Spots.ID[kind] + n)
end

-- The pure context of the clearance rule (local coordinates): the layout's nests (and the summit nest), the v3 houses,
-- opts.posts ({ { x, z } } local), the spots laid so far, and no live boxes. Spots.read adds the live map to it.
function Spots.context(L, V3, opts)
	opts = opts or {}
	local ctx = { L = L, V3 = V3, nests = {}, posts = {}, houses = {}, spots = {}, solids = {}, liquids = {},
		centre = L.CENTRE, floorTop = L.FLOOR_TOP }
	for _, n in ipairs(L.NESTS or {}) do table.insert(ctx.nests, { x = n.x, z = n.z }) end
	local summit = L.TOWER and L.TOWER.summit
	if summit then table.insert(ctx.nests, { x = summit.x, z = summit.z }) end
	for _, h in ipairs(V3.HOUSES or {}) do table.insert(ctx.houses, { id = h.id, x = h.x, z = h.z, r = h.r }) end
	for _, p in ipairs(opts.posts or {}) do table.insert(ctx.posts, { x = p.x, z = p.z }) end
	-- the v3 pieces but the houses (ctx.houses); Spots.read puts the live mountains in place of the layout's
	ctx.pieces = {}
	for _, p in ipairs(V3.pieces()) do
		if p.kind ~= "house" then table.insert(ctx.pieces, p) end
	end
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
-- The name of the first box within `clear` (flat) of world (wx, wz) at one of `heights` (nil: at the box's own height,
-- so a chocolate sheet counts whatever its height), or nil.
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

-- Why a spot centred at local (x, z) may not stand there, or nil when it may. noSpacing skips the spacing rule (the
-- rest never changes while one sync lays its spots).
function Spots.blocked(x, z, ctx, noSpacing)
	if not (finite(x) and finite(z)) or type(ctx) ~= "table" then return "nowhere" end
	local L, V3, R = ctx.L, ctx.V3, Spots.REACH
	if L.depth(x, z) < Spots.EDGE_DEPTH then return "edge" end
	if V3.liquidDistance(x, z) < Spots.LIQUID_MARGIN + R then return "liquid" end
	if L.routeDistance(x, z) < L.PATH_WIDTH / 2 + Spots.ROUTE_MARGIN + R then return "route" end
	for _, n in ipairs(ctx.nests) do
		if flat(x, z, n.x, n.z) < Spots.NEST_CLEAR + R then return "nest" end
	end
	for _, p in ipairs(ctx.posts) do
		if flat(x, z, p.x, p.z) < Spots.POST_CLEAR then return "post" end
	end
	for _, h in ipairs(ctx.houses) do
		if flat(x, z, h.x, h.z) < h.r + R + Spots.PIECE_MARGIN then return "house" end
	end
	for _, p in ipairs(ctx.pieces) do
		if flat(x, z, p.x, p.z) < p.r + R + Spots.PIECE_MARGIN then return p.kind end
	end
	if V3.nearBridge(x, z, R + Spots.BRIDGE_MARGIN) then return "bridge" end
	if L.TORTA and flat(x, z, L.TORTA.x, L.TORTA.z) < (L.BOSS and L.BOSS.plazaRadius or L.TORTA.radius) + R then return "torta" end
	if L.PORTAL and flat(x, z, L.PORTAL.x, L.PORTAL.z) < Spots.PORTAL_CLEAR + R then return "portal" end
	if L.ENTRANCE and flat(x, z, L.ENTRANCE.x, L.ENTRANCE.z) < Spots.ENTRANCE_CLEAR then return "entrance" end
	for _, k in ipairs(L.KEEP_CLEAR or {}) do
		if flat(x, z, k.x, k.z) < k.r + R then return "keep" end
	end
	if not noSpacing then
		for _, s in ipairs(ctx.spots) do
			if flat(x, z, s.x, s.z) < Spots.SPACING then return "spacing" end
		end
	end
	if #ctx.liquids > 0 or #ctx.solids > 0 then
		local wx, wz, top = ctx.centre.x + x, ctx.centre.z + z, ctx.floorTop
		if boxNear(ctx.liquids, wx, wz, nil, Spots.LIQUID_MARGIN + R) then return "liquid" end
		local heights = {}
		for i, h in ipairs(Spots.SOLID_HEIGHTS) do heights[i] = top + h end
		if boxNear(ctx.solids, wx, wz, heights, Spots.SOLID_CLEAR) then return "solid" end
	end
	return nil
end

-- A mountain's cave tries (local { x, z, faceX, faceZ }): the side facing the plot centre first, then turned round it,
-- each CAVE_GAP out from its footprint disc. m = { id, x, z, r }.
function Spots.caveCandidates(m)
	local list = {}
	local ux, uz = unit(-m.x, -m.z)
	if not ux then ux, uz = 0, -1 end
	for _, g in ipairs(Spots.CAVE_GAPS) do
		for _, turn in ipairs(Spots.CAVE_TURNS) do
			local dx, dz = turned(ux, uz, turn)
			table.insert(list, { x = m.x + dx * (m.r + g), z = m.z + dz * (m.r + g), faceX = dx, faceZ = dz, near = m.id })
		end
	end
	return list
end

-- A house's spot tries: towards the junction first, then round it, HOUSE_GAP out from its footprint disc.
function Spots.houseCandidates(h, L)
	local list = {}
	local j = L and L.JUNCTION or { x = 0, z = 0 }
	local ux, uz = unit(j.x - h.x, j.z - h.z)
	if not ux then ux, uz = 0, -1 end
	for _, turn in ipairs(Spots.HOUSE_TURNS) do
		local dx, dz = turned(ux, uz, turn)
		table.insert(list, { x = h.x + dx * (h.r + Spots.HOUSE_GAP), z = h.z + dz * (h.r + Spots.HOUSE_GAP), faceX = dx,
			faceZ = dz, near = h.id, group = h.id })
	end
	return list
end

-- The route tries: every ROUTE_STEP studs along each route (but SKIP_ROUTES), on both sides, just past the path's
-- margin, facing the path. n numbers them in a fixed order (their ids).
function Spots.routeCandidates(L)
	local list, n = {}, 0
	local off = L.PATH_WIDTH / 2 + Spots.ROUTE_MARGIN + Spots.REACH + 1
	for _, name in ipairs(L.ROUTE_ORDER) do
		if not Spots.SKIP_ROUTES[name] then
			local points = L.ROUTES[name]
			for i = 1, #points - 1 do
				local a, b = points[i], points[i + 1]
				local length = flat(a.x, a.z, b.x, b.z)
				local ux, uz = unit(b.x - a.x, b.z - a.z)
				if ux then
					local s = Spots.ROUTE_STEP / 2
					while s < length do
						for _, side in ipairs({ 1, -1 }) do
							n += 1
							local nx, nz = -uz * side, ux * side
							table.insert(list, { x = a.x + ux * s + nx * off, z = a.z + uz * s + nz * off, faceX = -nx, faceZ = -nz,
								near = name, n = n })
						end
						s += Spots.ROUTE_STEP
					end
				end
			end
		end
	end
	return list
end

-- Lays the plan: the caves (one per mountain, its first clear try), then the house spots and the route spots, each next
-- one the clear try farthest from every spot laid (one per house). Returns { { id, kind, x, z, faceX, faceZ, near } }
-- and the ids (or groups) that found no place.
function Spots.plan(ctx, mountains, houses)
	local out, skipped = {}, {}
	local function lay(c, id, kind)
		c.id, c.kind = id, kind
		table.insert(out, c)
		table.insert(ctx.spots, c)
	end
	for _, m in ipairs(mountains) do
		local n = tonumber(string.match(tostring(m.id), "^M(%d+)$"))
		if n and #out < Spots.TARGET then
			local pick = nil
			for _, c in ipairs(Spots.caveCandidates(m)) do
				if not Spots.blocked(c.x, c.z, ctx) then pick = c break end
			end
			if pick then lay(pick, Spots.spotId("cave", n), "cave") else table.insert(skipped, Spots.spotId("cave", n)) end
		end
	end
	local function spread(cands, limit, kinds, idOf)
		local taken, got = {}, 0
		for _, c in ipairs(cands) do
			if c.static == nil then c.static = Spots.blocked(c.x, c.z, ctx, true) or false end
		end
		while got < limit and #out < Spots.TARGET do
			local best, bestD = nil, -1
			for _, c in ipairs(cands) do
				if c.static == false and not (c.group and taken[c.group]) then
					local d, ok = math.huge, true
					for _, s in ipairs(ctx.spots) do
						local gap = flat(c.x, c.z, s.x, s.z)
						if gap < Spots.SPACING then ok = false break end
						d = math.min(d, gap)
					end
					if ok and d > bestD + 1e-9 then best, bestD = c, d end
				end
			end
			if not best then break end
			got += 1
			if best.group then taken[best.group] = true end
			lay(best, idOf(best), kinds[(got - 1) % #kinds + 1])
		end
		return got
	end
	local houseCands = {}
	for _, h in ipairs(houses) do
		local n = tonumber(string.match(tostring(h.id), "^H(%d+)$"))
		if n then
			for _, c in ipairs(Spots.houseCandidates(h, ctx.L)) do
				c.n = n
				table.insert(houseCands, c)
			end
		end
	end
	spread(houseCands, Spots.MAX_HOUSE, { "stump", "bush" }, function(c) return Spots.spotId("house", c.n) end)
	if #out < Spots.TARGET then
		spread(Spots.routeCandidates(ctx.L), Spots.TARGET, { "bush", "stump" }, function(c) return Spots.spotId("route", c.n) end)
	end
	if #out < Spots.TARGET then table.insert(skipped, ("short:%d"):format(Spots.TARGET - #out)) end
	return out, skipped
end

-- The live map under `root` (Candy_Bioma_v1) into a context: the floor's top, the live mountains, houses and nests, the
-- colliding parts (solids) and the chocolate's parts (liquids), and the creature posts (opts.posts, local; else
-- WildboundPraderaSites.FIXED's candy posts, world). Returns ctx, mountains, houses (local, sorted by id).
function Spots.read(root, L, V3, opts)
	opts = opts or {}
	local ctx = Spots.context(L, V3, opts)
	local C = L.CENTRE
	local v3 = root:FindFirstChild(V3.FOLDER)
	local ground = root:FindFirstChild("Ground")
	local floorPart = ground and ground:FindFirstChild("Floor")
	if floorPart and floorPart:IsA("BasePart") then ctx.floorTop = floorPart.Position.Y + floorPart.Size.Y / 2 end
	local own = root:FindFirstChild(Spots.FOLDER)
	local rows = {}
	for _, m in ipairs(V3.MOUNTAINS) do rows[m.id] = m end
	local mountains = {}
	local folder = v3 and v3:FindFirstChild("Mountains")
	for _, m in ipairs(folder and folder:GetChildren() or {}) do
		local id = m:GetAttribute("MountainId")
		if m:IsA("Model") and type(id) == "string" then
			local p = m:GetPivot().Position
			local r = rows[id] and rows[id].r
			if not r then
				local _, size = m:GetBoundingBox()
				r = math.max(size.X, size.Z) / 2
			end
			table.insert(mountains, { id = id, x = p.X - C.x, z = p.Z - C.z, r = r })
		end
	end
	table.sort(mountains, function(a, b) return a.id < b.id end)
	if #mountains == 0 then
		-- no live mountain models (an old build): the layout's, which the pieces already hold
		for _, m in ipairs(V3.MOUNTAINS) do table.insert(mountains, { id = m.id, x = m.x, z = m.z, r = m.r }) end
	else
		local kept = {}
		for _, p in ipairs(ctx.pieces) do
			if p.kind ~= "mountain" then table.insert(kept, p) end
		end
		for _, m in ipairs(mountains) do table.insert(kept, { kind = "mountain", id = m.id, x = m.x, z = m.z, r = m.r }) end
		ctx.pieces = kept
	end
	local houseRows = {}
	for _, h in ipairs(V3.HOUSES) do houseRows[h.id] = h end
	local houses = {}
	local hfolder = v3 and v3:FindFirstChild("Houses")
	for _, h in ipairs(hfolder and hfolder:GetChildren() or {}) do
		local id = h:GetAttribute("HouseId")
		if h:IsA("Model") and type(id) == "string" then
			local p = h:GetPivot().Position
			local frame, size = h:GetBoundingBox()
			local r = math.max(size.X, size.Z) / 2 + flat(p.X, p.Z, frame.Position.X, frame.Position.Z)
			if houseRows[id] then r = math.max(r, houseRows[id].r) end
			table.insert(houses, { id = id, x = p.X - C.x, z = p.Z - C.z, r = r })
		end
	end
	table.sort(houses, function(a, b) return a.id < b.id end)
	if #houses > 0 then ctx.houses = houses end
	local nests = root:FindFirstChild("Nests")
	for _, n in ipairs(nests and nests:GetChildren() or {}) do
		if n:IsA("Model") then
			local p = n:GetPivot().Position
			table.insert(ctx.nests, { x = p.X - C.x, z = p.Z - C.z })
		end
	end
	if opts.posts == nil then
		local Sites = opts.Sites
		if Sites == nil then
			local module = game:GetService("ServerScriptService"):FindFirstChild("WildboundPraderaSites")
			if module and module:IsA("ModuleScript") then
				local ok, loaded = pcall(require, module)
				Sites = ok and loaded or nil
			end
		end
		if type(Sites) == "table" and type(Sites.FIXED) == "table" then
			for key, p in pairs(Sites.FIXED) do
				if type(key) == "string" and string.sub(key, 1, 5) == "candy" and type(p) == "table" and finite(p.x) and finite(p.z) then
					table.insert(ctx.posts, { x = p.x - C.x, z = p.z - C.z })
				end
			end
		end
	end
	local liquidRoots = {}
	for _, name in ipairs(Spots.LIQUID_FOLDERS) do
		local f = v3 and v3:FindFirstChild(name)
		if f then table.insert(liquidRoots, f) end
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and not (own and d:IsDescendantOf(own)) then
			local isLiquid = false
			for _, f in ipairs(liquidRoots) do
				if d:IsDescendantOf(f) then isLiquid = true break end
			end
			local box = { name = d.Name, cframe = d.CFrame, size = d.Size, reach = d.Size.Magnitude / 2 }
			if isLiquid then
				table.insert(ctx.liquids, box)
			elseif d.CanCollide and not (floorPart and d == floorPart) then
				local c, s = d.CFrame, d.Size
				local top = d.Position.Y + (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z) / 2
				if top > ctx.floorTop + 0.6 then table.insert(ctx.solids, box) end
			end
		end
	end
	return ctx, mountains, houses
end

-- The world frame of a planned spot: on the floor at its place, its front (-Z) facing (faceX, faceZ).
function Spots.frame(spot, ctx)
	local at = Vector3.new(ctx.centre.x + spot.x, ctx.floorTop, ctx.centre.z + spot.z)
	local fx, fz = spot.faceX or 0, spot.faceZ or -1
	if not unit(fx, fz) then fx, fz = 0, -1 end
	return CFrame.lookAt(at, at + Vector3.new(fx, 0, fz))
end

local function piece(model, name, shape, size, cframe, color, query)
	local p = Instance.new("Part")
	p.Name, p.Shape, p.Size, p.CFrame, p.Color = name, shape, size, cframe, color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, query == true, query == true
	p.Parent = model
	return p
end
-- A disc whose face looks along the frame's -Z (a Cylinder's axis is its X).
local FACING = CFrame.Angles(0, math.rad(90), 0)
local LYING = CFrame.Angles(0, 0, math.rad(90))

local function decor(model, kit, library, name, cframe, scale)
	if not (kit and library) then return end
	local ok, made = pcall(kit.place, library, name, cframe, scale)
	if not ok or not made then return end
	for _, d in ipairs(made:GetDescendants()) do
		if d:IsA("BasePart") then d.CanCollide, d.CanTouch = false, false end
	end
	made.Name = "Decor_" .. name
	made.Parent = model
end

-- A detached spot model for a planned spot at its world frame cf. kit and library are optional (decor only).
function Spots.build(spot, cf, kit, library)
	local model = Instance.new("Model")
	model.Name = "HideSpot_" .. spot.id
	if spot.kind == "cave" then
		piece(model, "Scoop", Enum.PartType.Ball, Vector3.new(9, 7.5, 9), cf * CFrame.new(0, 1.2, 0), COLORS.scoop, true)
		piece(model, "Drip", Enum.PartType.Ball, Vector3.new(2, 2, 2), cf * CFrame.new(2.5, 4.3, 1), COLORS.drip, false)
		piece(model, "Drip", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(-2.2, 4, -1.5), COLORS.drip, false)
		piece(model, "Cave", Enum.PartType.Cylinder, Vector3.new(0.3, 4.2, 4.2), cf * CFrame.new(0, 1.9, -4.3) * FACING, COLORS.dark, false)
		decor(model, kit, library, "ConfettiPile", cf * CFrame.new(0, 0, -6.5), 1)
		decor(model, kit, library, "GumdropBush_A", cf * CFrame.new(4.6, 0, -2.5), 1)
	elseif spot.kind == "stump" then
		piece(model, "Stump", Enum.PartType.Cylinder, Vector3.new(4.6, 7, 7), cf * CFrame.new(0, 2.3, 0) * LYING, COLORS.sponge, true)
		piece(model, "Icing", Enum.PartType.Cylinder, Vector3.new(0.7, 7.6, 7.6), cf * CFrame.new(0, 4.7, 0) * LYING, COLORS.icing, true)
		piece(model, "Jam", Enum.PartType.Cylinder, Vector3.new(0.25, 7.7, 7.7), cf * CFrame.new(0, 4.2, 0) * LYING, COLORS.drip, false)
		piece(model, "Cherry", Enum.PartType.Ball, Vector3.new(1.6, 1.6, 1.6), cf * CFrame.new(0, 5.6, 0), COLORS.cherry, false)
		piece(model, "Hollow", Enum.PartType.Cylinder, Vector3.new(0.3, 3.4, 3.4), cf * CFrame.new(0, 1.9, -3.55) * FACING, COLORS.hollow, false)
		decor(model, kit, library, "CreamMushroom", cf * CFrame.new(4.4, 0, 1.6), 0.6)
	else
		piece(model, "Bush", Enum.PartType.Ball, Vector3.new(6.4, 4.9, 6.4), cf * CFrame.new(0, 2.2, 0), COLORS.cotton, true)
		piece(model, "Bush", Enum.PartType.Ball, Vector3.new(4.8, 3.6, 4.8), cf * CFrame.new(2.2, 1.7, 1.1), COLORS.cottonLight, true)
		piece(model, "Bush", Enum.PartType.Ball, Vector3.new(4.5, 3.4, 4.5), cf * CFrame.new(-2.1, 1.5, -1.3), COLORS.cottonMid, true)
		decor(model, kit, library, "GumdropBush_B", cf * CFrame.new(3.8, 0, -2.6), 1.2)
	end
	local zone = Instance.new("Part")
	zone.Name, zone.Size, zone.CFrame = "HideZone", Spots.ZONE_SIZE, cf * CFrame.new(0, Spots.ZONE_SIZE.Y / 2, 0)
	zone.Transparency, zone.Anchored, zone.CanCollide, zone.CanQuery, zone.CanTouch, zone.CastShadow = 1, true, false, false, false, false
	zone.Parent = model
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HidePrompt"
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Spots.PROMPT_DISTANCE
	prompt.HoldDuration = Spots.PROMPT_HOLD
	prompt.Parent = zone
	-- the model's pivot stays on the floor spot (a PrimaryPart moves GetPivot to its own CFrame otherwise)
	model.PrimaryPart = zone
	zone.PivotOffset = zone.CFrame:ToObjectSpace(cf)
	model:SetAttribute("SpotId", spot.id)
	model:SetAttribute("Kind", spot.kind)
	model:SetAttribute("Near", spot.near)
	model:SetAttribute("CandyHideSpot", true)
	CollectionService:AddTag(model, Spots.TAG)
	return model
end

local function lookup(name)
	local module = game:GetService("ServerStorage"):FindFirstChild(name)
	if not (module and module:IsA("ModuleScript")) then return nil end
	local ok, loaded = pcall(require, module)
	return ok and type(loaded) == "table" and loaded or nil
end

-- The server's start step (through WildboundCandyNests.applyFlags). L and V3 default to ServerStorage's
-- WildboundCandyLayout and WildboundCandyV3Layout (read now, so a widened river is respected); opts = { kit, library
-- (false: no decor; nil: ServerStorage's), posts, Sites }. Nothing happens without the v3 biome (root.CaramelV3).
-- Returns how many spots changed (laid, moved, retagged or removed), the skipped ids, and how many stand.
function Spots.sync(root, L, V3, opts)
	if typeof(root) ~= "Instance" then return 0, {}, 0 end
	L = L or lookup("WildboundCandyLayout")
	V3 = V3 or lookup("WildboundCandyV3Layout")
	if type(L) ~= "table" or type(V3) ~= "table" or not root:FindFirstChild(V3.FOLDER) then return 0, {}, 0 end
	opts = opts or {}
	local ctx, mountains, houses = Spots.read(root, L, V3, opts)
	local plan, skipped = Spots.plan(ctx, mountains, houses)
	local folder = root:FindFirstChild(Spots.FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = Spots.FOLDER
		folder.Parent = root
	end
	local Kit, library = opts.kit, opts.library
	if Kit == nil then
		Kit = lookup("WildboundCandyKit")
	end
	if Kit and library == nil then
		local assets = game:GetService("ServerStorage"):FindFirstChild("WildboundAssets")
		library = assets and assets:FindFirstChild(Kit.LIBRARY_NAME) or nil
	end
	if Kit == false then Kit = nil end
	local changed, want = 0, {}
	for _, spot in ipairs(plan) do
		local name = "HideSpot_" .. spot.id
		want[name] = true
		local cf = Spots.frame(spot, ctx)
		local old = folder:FindFirstChild(name)
		if old and old:GetAttribute("Kind") ~= spot.kind then
			old:Destroy()
			old = nil
		end
		if old then
			if (old:GetPivot().Position - cf.Position).Magnitude > 0.5 then
				old:PivotTo(cf)
				changed += 1
			end
			if not CollectionService:HasTag(old, Spots.TAG) then
				CollectionService:AddTag(old, Spots.TAG)
				changed += 1
			end
		else
			Spots.build(spot, cf, Kit, library).Parent = folder
			changed += 1
		end
	end
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") and string.match(child.Name, "^HideSpot_H%d+$") and not want[child.Name] then
			child:Destroy()
			changed += 1
		end
	end
	return changed, skipped, #plan
end

return Spots
