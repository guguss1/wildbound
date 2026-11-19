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
--   CloudWall.Veil      the band itself, 16 thick and 80 tall, in cloud pink: no collision, no query, no touch, so the
--                       player sees through it; WildboundCandyCloudWallClient puts the puffs on it. OQ1 (owner request
--                       2026-11-19, "quiero que las nubes sean mas realistas, no una foto estirada"): the Veil itself is
--                       not drawn (SmoothPlastic, transparency 1; was ForceField, a stretched shimmering texture): the
--                       client's layered puffs and particles are the cloud;
--   CloudWall.CapNorth  V8-D3 amendment (fixer, 2026-11-17): two invisible end caps with the Collider's flags, 4 thick
--   CloudWall.CapSouth  and 80 tall, inside the band's two ends, from the Collider east to the second space's far edge.
--                       The big4 annex strips (z -303..-263 and 257..297, to x 1012) and the grey Baseplate (to x 1024
--                       at every z) run past the band's ends, so without them a player walks round the wall ("nobody
--                       crosses it"); east of x 1024 is void, so nobody gets round a cap either. The Veil stays whole.
-- Caramelo v9 (CL-D1, CL-D13; docs/design/wildbound-caramelo-v9-plan.md; owner request 2026-11-18: "agranda mas el
-- bioma caramelo a lo largo"): the plot runs east to Layout.EAST (world x 1532), so the band, the wall and the floor
-- follow it, and the big4 arm (x 412..1612, z -303..297) ends TAIL studs past the band:
--   Ground.Floor        the band and the tail, x 1532..1612 (was the band only);
--   CloudWall.CapNorth  the caps end at the arm's end (x 1612), no longer at the second space's far edge;
--   CloudWall.CapSouth
--   CloudWall.SideWallNorth, SideWallSouth, EndWall  invisible solid walls (EDGE_WALL thick, 80 tall) along the stretched
--                       annex strips' outer sides from the Baseplate's east edge (x 1024, past it is void) and across the
--                       arm's end, so nobody falls into the void;
--   CloudWall.MouthGuard  an invisible solid block from the plot's east edge to the Collider across the river's mouth,
--                       so the river's barrier holds to the wall;
--   CloudWall.MouthSheet  decor chocolate (V3.LIQUID's colour, as thick as the chocolate) from the plot's east edge to the
--                       arm's end across the mouth: the river flows on under the cloud. The two mouth parts are planned only
--                       when V3's last river point lies on the east edge, their z from it.
-- stripPlan resizes the two big4 annex strips to the arm (0 new parts).
-- Anything named SistemaSonriente is never touched.
-- tools/wildbound-caramelo-v8-migrate.luau, tools/wildbound-pueblo-gatito-move.luau and
-- tools/wildbound-caramelo-v9-migrate.luau call build() on the live map; WildboundCandyEast_Test holds the rules.
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
-- CL-D13: the big4 arm runs TAIL studs past the cloud band (world x 1548..1612); EDGE_WALL is the side and end walls'
-- thickness. STRIP_WIDTH is the big4 annex strips' width (z), the arm's overhang past the plot's long sides;
-- STRIP_OLD_MAX_X their east end before v9 and BASEPLATE_MAX_X the grey Baseplate's east edge (world x; past it is void).
East.TAIL = 64
East.EDGE_WALL = 4
East.STRIP_WIDTH = 40
East.STRIP_OLD_MAX_X = 1012
East.BASEPLATE_MAX_X = 1024
East.STRIP_SLACK = 1 -- stripPlan finds a strip by its rectangle within this many studs

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

-- CL-D13: the V3 layout for the river's mouth: the one given, else ServerStorage's WildboundCandyV3Layout when it is
-- there (never waited for), else nil (no mouth parts).
local function v3Layout(V3)
	if type(V3) == "table" then return V3 end
	local found = game:GetService("ServerStorage"):FindFirstChild("WildboundCandyV3Layout")
	if found and found:IsA("ModuleScript") then
		local ok, module = pcall(require, found)
		if ok and type(module) == "table" then return module end
	end
	return nil
end

-- CL-D1: the plot's east half-length (Layout.EAST, 860 in v9); a layout without it is square (HALF).
local function eastOf(L)
	return type(L.EAST) == "number" and L.EAST or L.HALF
end

-- The rectangles that need no V3: plot, band, space, arm.
local function frame(L)
	local cx, cz, half = L.CENTRE.x, L.CENTRE.z, L.HALF
	-- CL-D1: x from the west edge (CENTRE.x - HALF) to the east edge (CENTRE.x + EAST) (was CENTRE.x +- HALF)
	local plot = rect(cx - half, cx + eastOf(L), cz - half, cz + half)
	local band = rect(plot.maxX, plot.maxX + East.BAND, plot.minZ - East.BAND_OVERHANG, plot.maxZ + East.BAND_OVERHANG)
	-- CL-D13: a legacy formula (2 * HALF east of the band) for annexMove, annexGround and the old tools
	local space = rect(band.maxX, band.maxX + 2 * half, plot.minZ, plot.maxZ)
	-- CL-D13: the big4 arm, TAIL past the band, STRIP_WIDTH past the plot's long sides
	local arm = rect(plot.minX, band.maxX + East.TAIL, plot.minZ - East.STRIP_WIDTH, plot.maxZ + East.STRIP_WIDTH)
	return plot, band, space, arm
end

-- plan(L, V3) -> the world numbers of Caramelo Este for layout L (default ServerStorage's WildboundCandyLayout) and V3
-- layout V3 (optional; default ServerStorage's WildboundCandyV3Layout when it is there, read for the river's mouth only):
--   plot      the plot (CL-D1: x CENTRE.x - HALF .. CENTRE.x + EAST, z CENTRE.z +- HALF)
--   band      the cloud band: BAND wide along the plot's east edge, the plot's length plus BAND_OVERHANG at each end
--   space     legacy (CL-D13): 2 * HALF east of the band; centre { x, z } (never built, kept for annexMove,
--             annexGround, the v8 tool and KittenPark's archive step)
--   arm       CL-D13: the big4 arm, x plot.minX .. band.maxX + TAIL, z plot +- STRIP_WIDTH (world 412..1612, -303..297)
--   ground    the floor under the band and the tail (CL-D13: band.minX .. arm.maxX, the plot's z; was the band only)
--   wallX     the band's centre line (the Collider's x); margin = WALL_MARGIN
--   shift     legacy: how far east a point of the plot lands at the same spot of the space (space.minX - plot.minX)
--   mouth     CL-D13: the river's mouth past the plot (x plot.maxX .. arm.maxX, z from V3's last river point +- half its
--             width), or nil when the river does not end on the east edge
--   parts     the specs of Ground.Floor, CloudWall.Collider, Veil, CapNorth, CapSouth, SideWallNorth, SideWallSouth,
--             EndWall and, with a mouth, MouthGuard and MouthSheet, in that order: { name, folder, size = { x, y, z },
--             position = { x, y, z }, color, material, transparency, canCollide, canQuery, canTouch, castShadow, role }
--   caps      the two end caps' rectangles { north, south } (V8-D3 amendment; CL-D13: to the arm's end)
function East.plan(L, V3)
	L = layout(L)
	V3 = v3Layout(V3)
	local cz, top = L.CENTRE.z, L.FLOOR_TOP
	local plot, band, space, arm = frame(L)
	-- CL-D13: the band and the tail (was the band only, PGM-D5); the plot's z, so it never fights the annex strips
	local ground = rect(band.minX, arm.maxX, plot.minZ, plot.maxZ)
	local wallX = (band.minX + band.maxX) / 2
	local bandZ, bandLength = (band.minZ + band.maxZ) / 2, band.maxZ - band.minZ
	local wallY = top + East.HEIGHT / 2
	-- V8-D3 amendment: the end caps, inside the band's two ends, from the Collider's west face; CL-D13: to the arm's end
	-- (was the second space's far edge)
	local capWest = wallX - East.COLLIDER_THICK / 2
	local caps = {
		north = rect(capWest, arm.maxX, band.maxZ - East.CAP_THICK, band.maxZ),
		south = rect(capWest, arm.maxX, band.minZ, band.minZ + East.CAP_THICK),
	}
	-- CL-D13: the side walls along the stretched strips' outer sides, from over the Baseplate to past the arm's end, and
	-- the end wall across the arm's end, corner to corner
	local wall = East.EDGE_WALL
	local sides = {
		north = rect(East.BASEPLATE_MAX_X - wall, arm.maxX + wall, arm.maxZ, arm.maxZ + wall),
		south = rect(East.BASEPLATE_MAX_X - wall, arm.maxX + wall, arm.minZ - wall, arm.minZ),
		ending = rect(arm.maxX, arm.maxX + wall, arm.minZ - wall, arm.maxZ + wall),
	}
	-- CL-D13: the mouth, when V3's last river point { x, z, w } (local) lies on the east edge
	local mouth = nil
	local river = V3 and V3.RIVER
	local last = type(river) == "table" and river[#river] or nil
	if type(last) == "table" and type(last[1]) == "number" and math.abs(last[1] - eastOf(L)) <= 1e-3 then
		mouth = rect(plot.maxX, arm.maxX, cz + last[2] - last[3] / 2, cz + last[2] + last[3] / 2)
	end
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
		-- OQ1 (owner request 2026-11-19, "no una foto estirada"): not drawn (was ForceField, transparency 0, a stretched
		-- shimmering texture); WildboundCandyCloudWallClient draws the soft cloud volume around it
		{ name = "Veil", folder = East.FOLDER, role = "decor",
			size = { East.BAND, East.HEIGHT, bandLength }, position = { wallX, wallY, bandZ },
			color = East.VEIL_COLOR, material = "SmoothPlastic", transparency = 1,
			canCollide = false, canQuery = false, canTouch = false, castShadow = false },
		cap("CapNorth", caps.north),
		cap("CapSouth", caps.south),
		-- CL-D13: the side and end walls have the caps' flags
		cap("SideWallNorth", sides.north),
		cap("SideWallSouth", sides.south),
		cap("EndWall", sides.ending),
	}
	if mouth then
		-- CL-D13: the guard closes the gap between the plot's east edge and the Collider across the mouth
		table.insert(parts, cap("MouthGuard", rect(plot.maxX, capWest, mouth.minZ, mouth.maxZ)))
		-- CL-D13: the sheet: decor chocolate from the floor to the river's surface, to the arm's end
		local liquid = type(V3.LIQUID) == "table" and V3.LIQUID or {}
		local depth = type(liquid.depth) == "number" and liquid.depth or 3.5
		table.insert(parts, { name = "MouthSheet", folder = East.FOLDER, role = "decor",
			size = { mouth.maxX - mouth.minX, depth, mouth.maxZ - mouth.minZ },
			position = { (mouth.minX + mouth.maxX) / 2, top + depth / 2, (mouth.minZ + mouth.maxZ) / 2 },
			color = type(liquid.color) == "table" and liquid.color or { 92, 52, 34 }, material = "Glass",
			transparency = type(liquid.transparency) == "number" and liquid.transparency or 0.08,
			canCollide = false, canQuery = false, canTouch = false, castShadow = false })
	end
	return {
		plot = plot, band = band, space = space, arm = arm, ground = ground, caps = table.freeze(caps), mouth = mouth,
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

-- stripPlan(L, slabs) -> { resize = { { name, side, rect } }, done = { { name, side } }, missing = { sides }, ok }
-- (CL-D13). slabs = { { name, minX, maxX, minZ, maxZ } }: the floor slabs of Workspace.WildboundCandyAnnex_Big4. The
-- two strips are found by geometry, within STRIP_SLACK studs: x arm.minX..STRIP_OLD_MAX_X (412..1012) and z the arm's
-- edge to the plot's (south -303..-263, north 257..297). Each found strip is resized to the arm's x (412..1612), its own
-- z range kept; a strip already at the arm's x is `done` (nothing to resize). side is "south" or "north"; missing lists
-- the sides with no strip; ok is true when both were found. 0 new parts; pure; deterministic (name order: the first
-- match wins a side).
function East.stripPlan(L, slabs)
	L = layout(L)
	local plot, _, _, arm = frame(L)
	local slack = East.STRIP_SLACK
	local function close(a, b) return math.abs(a - b) <= slack + 1e-6 end
	local wanted = {
		{ side = "south", minZ = arm.minZ, maxZ = plot.minZ },
		{ side = "north", minZ = plot.maxZ, maxZ = arm.maxZ },
	}
	local list = table.clone(slabs or {})
	table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
	local out = { resize = {}, done = {}, missing = {}, ok = false }
	for _, w in ipairs(wanted) do
		local found = false
		for _, s in ipairs(list) do
			if not found and type(s.minX) == "number" and close(s.minX, arm.minX) and close(s.minZ, w.minZ)
				and close(s.maxZ, w.maxZ) then
				if close(s.maxX, arm.maxX) then
					found = true
					table.insert(out.done, { name = s.name, side = w.side })
				elseif close(s.maxX, East.STRIP_OLD_MAX_X) then
					found = true
					table.insert(out.resize, { name = s.name, side = w.side, rect = rect(arm.minX, arm.maxX, s.minZ, s.maxZ) })
				end
			end
		end
		if not found then table.insert(out.missing, w.side) end
	end
	out.ok = #out.missing == 0
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

-- build(parent, L, V3) -> root, report { created, changed, parts }: Caramelo Este's floor and cloud wall under
-- parent (default Workspace) as parent.Candy_Este_v1 (a Model; created when missing), from plan(L, V3). Idempotent: a
-- missing piece is made, a piece that differs from the plan is set back to it, and a second call changes nothing
-- (created 0, changed 0). The Collider (PGM-D5: whole again; on a live map K-D1's north piece grows back to the band's
-- length) carries WallMargin (WildboundCandySmarts.wallOf); the root carries Version, WallX and Key. CL-D13: on the v8
-- map it conforms the five old parts to the v9 band and creates the five new ones. Never removes anything: a live
-- ColliderSouth is left as it is (tools/wildbound-pueblo-gatito-move.luau archives it). Refuses a parent inside
-- SistemaSonriente; never touches anything else under parent.
function East.build(parent, L, V3)
	parent = parent or game:GetService("Workspace")
	assert(typeof(parent) == "Instance", "parent must be an Instance")
	assert(not forbidden(parent), "refusing to touch " .. East.FORBIDDEN)
	local P = East.plan(L, V3)
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
