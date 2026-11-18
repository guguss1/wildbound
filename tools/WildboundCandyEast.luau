-- Caramelo v8, V8-D2 and V8-D3 (owner request 2026-11-17: "make another space of the same size, separated by clouds: an
-- invisible wall with a cloud texture that you can see through"; docs/design/wildbound-caramelo-v8-plan.md). Caramelo
-- Este: a 16-stud cloud band along the bigger plot's east edge and, east of it, a second playable square as big as the
-- plot. Deployed as ServerStorage.WildboundCandyEast. Pure plan (every number from WildboundCandyLayout: CENTRE, HALF,
-- FLOOR_TOP) plus build(), which lays the floor and the cloud wall into Workspace.Candy_Este_v1.
-- PGM-D5 (owner request 2026-11-18, "Sí, movelo"; docs/design/wildbound-pueblo-gatito-move-plan.md): Pueblo Gatito
-- moved to the big4 south arm (ReplicatedStorage.WildboundGatitoArea, its own root PuebloGatito_v1), so the cloud wall
-- is Caramelo's closed east edge: no gate, the Collider whole again, the floor under the band only, in the plot's pink.
-- The second space east of the band is no longer built; plan() still returns it (space, shift) for annexMove,
-- annexGround, the v8 migration tool and WildboundKittenPark's archive step.
--   Ground.Floor        one floor part under the band (the band's x, the plot's z: the annex strips cover the band's
--                       overhangs), its top at FLOOR_TOP (named Floor in its own root, so readers of
--                       Candy_Bioma_v1.Ground.Floor keep finding the first plot); PGM-D5: back to the plot's pink
--                       SmoothPlastic (was K-D15's grass green under the band and the park's space);
--   CloudWall.Collider  an invisible block 4 thick and 80 tall on the band's centre line, the band's whole length (PGM-D5:
--                       the K-D1 gate and its ColliderSouth piece are gone; the move tool archives a live ColliderSouth):
--                       anchored, collides and answers queries (creature sight stops at it), never touched, no shadow,
--                       Role "solid", never tagged WildboundBeastPass; carries WallMargin; WildboundCandySmarts.wallOf
--                       reads it (V8-D3);
--   CloudWall.Veil      the band itself, 16 thick and 80 tall, ForceField in cloud pink: no collision, no query, no
--                       touch, so the player sees through it; WildboundCandyCloudWallClient puts the puffs on it;
--   CloudWall.CapNorth  V8-D3 amendment (fixer, 2026-11-17): two invisible end caps with the Collider's flags, 4 thick
--   CloudWall.CapSouth  and 80 tall, inside the band's two ends, from the Collider east to the second space's far edge.
--                       The big4 annex strips (z -303..-263 and 257..297, to x 1012) and the grey Baseplate (to x 1024
--                       at every z) run past the band's ends, so without them a player walks round the wall ("nobody
--                       crosses it"); east of x 1024 is void, so nobody gets round a cap either. The Veil stays whole.
-- Anything named SistemaSonriente is never touched.
-- tools/wildbound-caramelo-v8-migrate.luau and tools/wildbound-pueblo-gatito-move.luau call build() on the live map;
-- WildboundCandyEast_Test holds the rules.
local East = {}

East.VERSION = 1
East.ROOT_NAME = "Candy_Este_v1"
-- PGM-D5 (owner request 2026-11-18, "Sí, movelo"): the cloud wall is Caramelo's, so East.TAG is gone (it named the
-- CandyEast biome row, now Pueblo Gatito's south arm: WildboundBiomes keeps the tag; nothing else read East.TAG) and the
-- root attribute Key names the wall itself (was "pueblo-gatito", PG-D2; "caramelo-este" before it). PuebloGatito_v1
-- carries Key "pueblo-gatito" (PGM-D7).
East.KEY = "caramelo-nube"
East.BAND = 16 -- the cloud band's width (studs)
East.BAND_OVERHANG = 8 -- the band runs this far past the plot's north and south edges
East.COLLIDER_THICK = 4
East.CAP_THICK = 4 -- V8-D3 amendment: the two end caps' thickness (z)
East.HEIGHT = 80 -- the wall's height over the floor's top
East.WALL_MARGIN = 8 -- creatures stop this far from the wall's centre line (half the band: the plot's east edge)
East.FOLDER = "CloudWall"
-- PGM-D5 (owner request 2026-11-18, "Sí, movelo"): the band's floor is the plot's pink again; the park lays its own grass
-- (WildboundKittenPark.buildGround) (was K-D15's { 140, 201, 107 }, Grass)
East.FLOOR_COLOR = table.freeze({ 255, 177, 209 })
East.FLOOR_MATERIAL = "SmoothPlastic"
East.VEIL_COLOR = table.freeze({ 255, 226, 240 }) -- cloud pink
-- PGM-D5: East.GATE (K-D1's 14-stud gap in the Collider) is gone; the wall is closed.
East.FORBIDDEN = "SistemaSonriente"

local function rect(minX, maxX, minZ, maxZ)
	return table.freeze({ minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ })
end
local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local function forbidden(instance)
	return typeof(instance) == "Instance" and (instance.Name == East.FORBIDDEN or instance:FindFirstAncestor(East.FORBIDDEN) ~= nil)
end
East.forbidden = forbidden

local function layout(L)
	if type(L) == "table" then return L end
	return require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
end

-- plan(L) -> the world numbers of Caramelo Este for layout L (default ServerStorage's WildboundCandyLayout):
--   plot      the first plot's square (x CENTRE.x +- HALF, z CENTRE.z +- HALF)
--   band      the cloud band: BAND wide along the plot's east edge, the plot's length plus BAND_OVERHANG at each end
--   space     the second space: as big as the plot, east of the band; centre { x, z } (PGM-D5: no longer built, kept
--             for annexMove, annexGround, the v8 tool and KittenPark's archive step)
--   ground    the floor under the band only (PGM-D5; the band's x, the plot's z range; was the band and the space)
--   wallX     the band's centre line (the Collider's x); margin = WALL_MARGIN
--   shift     how far east a point of the plot lands at the same spot of the space (2 * HALF + BAND)
--   parts     the specs of Ground.Floor, CloudWall.Collider, CloudWall.Veil, CloudWall.CapNorth and CloudWall.CapSouth,
--             in that order: { name, folder, size = { x, y, z }, position = { x, y, z }, color, material, transparency,
--             canCollide, canQuery, canTouch, castShadow, role } (PGM-D5: ColliderSouth left, the Collider whole again)
--   caps      the two end caps' rectangles { north, south } (V8-D3 amendment)
function East.plan(L)
	L = layout(L)
	local cx, cz, half, top = L.CENTRE.x, L.CENTRE.z, L.HALF, L.FLOOR_TOP
	local plot = rect(cx - half, cx + half, cz - half, cz + half)
	local band = rect(plot.maxX, plot.maxX + East.BAND, plot.minZ - East.BAND_OVERHANG, plot.maxZ + East.BAND_OVERHANG)
	local space = rect(band.maxX, band.maxX + 2 * half, plot.minZ, plot.maxZ)
	-- PGM-D5: the band only (was band.minX..space.maxX); the plot's z, so it never fights the annex strips past it
	local ground = rect(band.minX, band.maxX, plot.minZ, plot.maxZ)
	local wallX = (band.minX + band.maxX) / 2
	local bandZ, bandLength = (band.minZ + band.maxZ) / 2, band.maxZ - band.minZ
	local wallY = top + East.HEIGHT / 2
	-- V8-D3 amendment: the end caps, inside the band's two ends, from the Collider's west face to the space's far edge
	local capWest = wallX - East.COLLIDER_THICK / 2
	local caps = {
		north = rect(capWest, space.maxX, band.maxZ - East.CAP_THICK, band.maxZ),
		south = rect(capWest, space.maxX, band.minZ, band.minZ + East.CAP_THICK),
	}
	local function cap(name, r)
		return { name = name, folder = East.FOLDER, role = "solid",
			size = { r.maxX - r.minX, East.HEIGHT, r.maxZ - r.minZ },
			position = { (r.minX + r.maxX) / 2, wallY, (r.minZ + r.maxZ) / 2 },
			color = East.VEIL_COLOR, material = "SmoothPlastic", transparency = 1,
			canCollide = true, canQuery = true, canTouch = false, castShadow = false }
	end
	-- PGM-D5: no gate; the Collider runs the band's whole length again (K-D1 cut it at z -10..4)
	local function collider(name, minZ, maxZ)
		return { name = name, folder = East.FOLDER, role = "solid",
			size = { East.COLLIDER_THICK, East.HEIGHT, maxZ - minZ }, position = { wallX, wallY, (minZ + maxZ) / 2 },
			color = East.VEIL_COLOR, material = "SmoothPlastic", transparency = 1,
			canCollide = true, canQuery = true, canTouch = false, castShadow = false }
	end
	local parts = {
		{ name = "Floor", folder = "Ground", role = "floor",
			size = { ground.maxX - ground.minX, 1, ground.maxZ - ground.minZ },
			position = { (ground.minX + ground.maxX) / 2, top - 0.5, (ground.minZ + ground.maxZ) / 2 },
			color = East.FLOOR_COLOR, material = East.FLOOR_MATERIAL, transparency = 0,
			canCollide = true, canQuery = true, canTouch = false, castShadow = true },
		collider("Collider", band.minZ, band.maxZ), -- PGM-D5: whole again (was K-D1's north piece and ColliderSouth)
		{ name = "Veil", folder = East.FOLDER, role = "decor",
			size = { East.BAND, East.HEIGHT, bandLength }, position = { wallX, wallY, bandZ },
			color = East.VEIL_COLOR, material = "ForceField", transparency = 0,
			canCollide = false, canQuery = false, canTouch = false, castShadow = false },
		cap("CapNorth", caps.north),
		cap("CapSouth", caps.south),
	}
	return {
		plot = plot, band = band, space = space, ground = ground, caps = table.freeze(caps),
		centre = table.freeze({ x = (space.minX + space.maxX) / 2, z = (space.minZ + space.maxZ) / 2 }),
		wallX = wallX, margin = East.WALL_MARGIN, shift = space.minX - plot.minX, floorTop = top,
		parts = parts,
	}
end

-- wallX(L) -> the cloud wall's centre line (world x) for the creature clamp (WildboundCandySmarts.outsideWall).
function East.wallX(L)
	return East.plan(L).wallX
end

-- inside(r, x, z) -> whether a flat point lies in a plan rectangle (edges included).
function East.inside(r, x, z)
	return type(x) == "number" and type(z) == "number" and x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ
end

-- annexMove(L, x, z) -> where a point of the big4 annex goes (V8-D4 step 4): "move" and its new (x + shift, z) when it
-- lies in the bigger plot; "band" (archive it) when it lies in the cloud band; "keep" anywhere else (the second space,
-- the annex strips north and south).
function East.annexMove(L, x, z)
	local P = East.plan(L)
	if East.inside(P.plot, x, z) then return "move", x + P.shift, z end
	if East.inside(P.band, x, z) then return "band", x, z end
	return "keep", x, z
end

local function area(r)
	return math.max(r.maxX - r.minX, 0) * math.max(r.maxZ - r.minZ, 0)
end
local function overlap(a, b)
	return rect(math.max(a.minX, b.minX), math.min(a.maxX, b.maxX), math.max(a.minZ, b.minZ), math.min(a.maxZ, b.maxZ))
end

-- annexGround(L, slabs) -> { archive = { names }, resize = { { name, rect } }, keep = { names }, overlap = { names } }
-- (V8-D4 step 4). slabs = { { name, minX, maxX, minZ, maxZ } }: the big4 annex's floor slabs, whose tops are level with
-- the new floors (they would fight). The floors (the plot and Ground.Floor) cover one rectangle, x plot.minX..space.maxX
-- by z plot.minZ..plot.maxZ. When it spans the slabs' whole x range, what the slabs still have to cover is two strips,
-- north and south of it: each strip goes to the slab that overlaps it most (resized to it, 0 new parts) and every other
-- slab is archived. Otherwise (an unexpected annex) only the slabs the floors cover whole are archived and the others
-- are kept and listed in `overlap` when they meet the floors. Pure; deterministic (name order on ties).
function East.annexGround(L, slabs)
	local P = East.plan(L)
	local floors = rect(P.plot.minX, P.space.maxX, P.plot.minZ, P.plot.maxZ)
	local out = { archive = {}, resize = {}, keep = {}, overlap = {} }
	local list = table.clone(slabs or {})
	table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
	if #list == 0 then return out end
	local u = { minX = math.huge, maxX = -math.huge, minZ = math.huge, maxZ = -math.huge }
	for _, s in ipairs(list) do
		u.minX, u.maxX = math.min(u.minX, s.minX), math.max(u.maxX, s.maxX)
		u.minZ, u.maxZ = math.min(u.minZ, s.minZ), math.max(u.maxZ, s.maxZ)
	end
	if floors.minX <= u.minX + 1e-6 and floors.maxX >= u.maxX - 1e-6 then
		local strips = {}
		if u.minZ < floors.minZ - 1e-6 then table.insert(strips, rect(u.minX, u.maxX, u.minZ, math.min(floors.minZ, u.maxZ))) end
		if u.maxZ > floors.maxZ + 1e-6 then table.insert(strips, rect(u.minX, u.maxX, math.max(floors.maxZ, u.minZ), u.maxZ)) end
		local used = {}
		for _, strip in ipairs(strips) do
			local best, bestArea = nil, -1
			for _, s in ipairs(list) do
				if not used[s.name] then
					local a = area(overlap(s, strip))
					if a > bestArea then best, bestArea = s, a end
				end
			end
			if best then
				used[best.name] = true
				table.insert(out.resize, { name = best.name, rect = strip })
			end
		end
		for _, s in ipairs(list) do
			if not used[s.name] then table.insert(out.archive, s.name) end
		end
		return out
	end
	for _, s in ipairs(list) do
		local covered = area(overlap(s, floors))
		if covered >= area(s) - 1e-6 then
			table.insert(out.archive, s.name)
		else
			table.insert(out.keep, s.name)
			if covered > 1e-6 then table.insert(out.overlap, s.name) end
		end
	end
	return out
end

-- Whether a property already holds a value (vectors, frames and colours within float noise).
local function same(a, b)
	if typeof(a) ~= typeof(b) then return false end
	if typeof(a) == "Vector3" or typeof(a) == "CFrame" then return a:FuzzyEq(b, 1e-4) end
	if typeof(a) == "Color3" then
		return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
	end
	if type(a) == "number" then return math.abs(a - b) < 1e-6 end
	return a == b
end

-- One part to its spec: every property that differs is set; returns how many were changed (0: it already matched).
local function conform(part, spec)
	local changed = 0
	local function set(key, value)
		if not same(part[key], value) then
			part[key] = value
			changed += 1
		end
	end
	set("Anchored", true)
	set("Shape", Enum.PartType.Block)
	set("Size", Vector3.new(spec.size[1], spec.size[2], spec.size[3]))
	set("CFrame", CFrame.new(spec.position[1], spec.position[2], spec.position[3]))
	set("Color", rgb(spec.color))
	set("Material", Enum.Material[spec.material])
	set("Transparency", spec.transparency)
	set("CanCollide", spec.canCollide)
	set("CanQuery", spec.canQuery)
	set("CanTouch", spec.canTouch)
	set("CastShadow", spec.castShadow)
	set("TopSurface", Enum.SurfaceType.Smooth)
	set("BottomSurface", Enum.SurfaceType.Smooth)
	if part:GetAttribute("Role") ~= spec.role then
		part:SetAttribute("Role", spec.role)
		changed += 1
	end
	return changed
end

local function child(parent, class, name)
	local found = parent:FindFirstChild(name)
	if found then
		assert(found:IsA(class), parent:GetFullName() .. "." .. name .. " is a " .. found.ClassName .. ", not a " .. class)
		return found, false
	end
	local made = Instance.new(class)
	made.Name = name
	made.Parent = parent
	return made, true
end

-- build(parent, L) -> root, report { created, changed, parts }: Caramelo Este's floor and cloud wall under
-- parent (default Workspace) as parent.Candy_Este_v1 (a Model; created when missing). Idempotent: a missing piece is
-- made, a piece that differs from the plan is set back to it, and a second call changes nothing (created 0, changed 0).
-- The Collider (PGM-D5: whole again; on a live map K-D1's north piece grows back to the band's length and the floor
-- shrinks to the band) carries WallMargin (WildboundCandySmarts.wallOf); the root carries Version, WallX and Key. Never
-- removes anything: a live ColliderSouth is left as it is (tools/wildbound-pueblo-gatito-move.luau archives it). Refuses
-- a parent inside SistemaSonriente; never touches anything else under parent.
function East.build(parent, L)
	parent = parent or game:GetService("Workspace")
	assert(typeof(parent) == "Instance", "parent must be an Instance")
	assert(not forbidden(parent), "refusing to touch " .. East.FORBIDDEN)
	local P = East.plan(L)
	local report = { created = 0, changed = 0, parts = 0 }
	local root, made = child(parent, "Model", East.ROOT_NAME)
	if made then report.created += 1 end
	for key, value in pairs({ Version = East.VERSION, WallX = P.wallX, Key = East.KEY }) do
		if root:GetAttribute(key) ~= value then
			root:SetAttribute(key, value)
			report.changed += 1
		end
	end
	for _, spec in ipairs(P.parts) do
		local folder, newFolder = child(root, "Folder", spec.folder)
		if newFolder then report.created += 1 end
		local part, newPart = child(folder, "Part", spec.name)
		local n = conform(part, spec)
		if newPart then report.created += 1 else report.changed += n end
		report.parts += 1
	end
	local collider = root[East.FOLDER].Collider
	if collider:GetAttribute("WallMargin") ~= East.WALL_MARGIN then
		collider:SetAttribute("WallMargin", East.WALL_MARGIN)
		report.changed += 1
	end
	return root, report
end

return East
