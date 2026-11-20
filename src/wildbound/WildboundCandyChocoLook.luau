-- Caramelo's chocolate look (TB-2, owner request 2026-11-20: "que el agua marron sea de la toolbox tambien, no se si se
-- puede cambiar los colores"). Pure rules for WildboundCandyChocoLookClient, which lays a Creator Store chocolate texture
-- (rbxassetid://82311877461867, glossy melted chocolate; its colour is tinted through Texture.Color3) on the upward face
-- of every chocolate liquid part of Caramelo, on the local client only, and slowly scrolls it downstream:
--   which parts   Workspace.Candy_Bioma_v1.CaramelV3.River: Choco_River_<n> (one block per river leg, laid with
--                 CFrame.lookAt(RIVER[n], RIVER[n + 1]), so its LookVector is downstream) and Choco_Pool (the waterfall's
--                 pool); CaramelV3.Lake: Choco_Lake_<n> (the lake discs); Workspace.Candy_Este_v1.CloudWall.MouthSheet
--                 (the river flowing on under the cloud, east). Never the waterfall's Sheet, the Bank_ crumbs or anything
--                 named SistemaSonriente.
--   overlaps      every liquid part's top is the same plane (WildboundCandyV3Builder layLiquid), and two see-through
--                 textures on one plane draw doubled and flicker as their sort order flips. So the round joints
--                 (Choco_Joint_<n>, under both block ends at every river point) stay plain, and a drum (the pool or a
--                 lake disc) whose centre lies inside a river block's footprint (insideBlock) stays plain too: the
--                 block's texture already covers it. With the v9 layout that is every lake disc (the lake proper and
--                 the dock basins lie in the 110-120 wide river band; only lake 1's south rim, about 17 studs past the
--                 band, is left plain); the pool stays textured (its rim stops short of leg 1). Still doubled: the
--                 small wedge where two legs overlap inside a bend (no part rule removes it).
--   which face    the face whose outward normal points most up: Top on the river blocks and the MouthSheet, Right on the
--                 drums (WildboundCandyV3Builder turns them 90 degrees about Z, so their local +X is world up).
--   the texture   StudsPerTile STUDS_PER_TILE, Transparency TRANSPARENCY, Color3 the part's own colour lifted TINT_LIFT
--                 toward white (the image is already brown: the plain chocolate colour would multiply it nearly black).
--   the scroll    along the river: a river block along its own LookVector, the pool along leg 1, every textured lake
--                 disc along one shared direction (the river block nearest the lake's centre, so overlapping discs
--                 always move together), the MouthSheet east (MOUTH_FLOW); at WildboundCandyCurrent's speeds (river 4,
--                 lake 1.5 studs/s); offsets from the clock (no drift), at most 10 Hz (STEP_SECONDS), only while the
--                 camera is within NEAR_STUDS of the chocolate, never with "Efectos suaves" (the world gui's Reduced).
-- The texture's U and V axes per face (UV) and SCROLL_SIGN are what Studio shows; if the chocolate scrolls upstream on a
-- face, that face's row (or the sign) is the one to flip. Every number is a hypothesis to check in Studio Play.
-- Shared (ReplicatedStorage), no services, no clock, no require. Rules: WildboundCandyChocoLook_Test.
local Look = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

local function finite(value)
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
Look.finite = finite

Look.IMAGE = "rbxassetid://82311877461867" -- Creator Store chocolate texture (TB-2)
Look.TEXTURE_NAME = "WildboundChocoLook" -- the Texture made on each part (client-only, never replicated)
Look.ROOT_NAME = "Candy_Bioma_v1"
Look.V3_FOLDER = "CaramelV3"
Look.FOLDERS = freeze({ "River", "Lake" })
Look.EAST_ROOT = "Candy_Este_v1"
Look.EAST_FOLDER = "CloudWall"
Look.MOUTH_NAME = "MouthSheet"
Look.FORBIDDEN = "SistemaSonriente"

Look.STUDS_PER_TILE = 24
Look.TRANSPARENCY = 0.3
Look.TINT_LIFT = 0.5
Look.STEP_SECONDS = 0.1 -- the scroll is written at most 10 times a second
Look.SCAN_SECONDS = 3 -- the parts are looked up again this often (streaming)
Look.DIRTY_SECONDS = 0.5 -- and at most this often after a watched folder changed
Look.NEAR_STUDS = 700 -- flat studs from the camera to the chocolate's box past which nothing scrolls
-- The scroll speeds, studs/s: WildboundCandyCurrent.RIVER_SPEED and LAKE_SPEED (the suite pins them equal).
Look.SPEED = freeze({ river = 4, lake = 1.5 })
Look.SCROLL_SIGN = 1
Look.MOUTH_FLOW = freeze({ 1, 0 }) -- world x, z: the river leaves the plot east, under the cloud

-- The texture's U axis (left to right) and V axis (top to bottom) on each face, in the part's local axes, seen from
-- outside the face with the part upright (side faces) or from above with its Front away (Top).
Look.UV = freeze({
	Top = { u = { 1, 0, 0 }, v = { 0, 0, 1 } },
	Bottom = { u = { -1, 0, 0 }, v = { 0, 0, 1 } },
	Right = { u = { 0, 0, -1 }, v = { 0, -1, 0 } },
	Left = { u = { 0, 0, 1 }, v = { 0, -1, 0 } },
	Back = { u = { 1, 0, 0 }, v = { 0, -1, 0 } },
	Front = { u = { -1, 0, 0 }, v = { 0, -1, 0 } },
})

-- classify(name) -> kind, index: "river", "joint", "lake" (with their number), "pool" or "mouth"; nil for anything else.
function Look.classify(name)
	if type(name) ~= "string" then return nil end
	if name == "Choco_Pool" then return "pool", nil end
	if name == Look.MOUTH_NAME then return "mouth", nil end
	for _, row in ipairs({ { "^Choco_River_(%d+)$", "river" }, { "^Choco_Joint_(%d+)$", "joint" }, { "^Choco_Lake_(%d+)$", "lake" } }) do
		local digits = string.match(name, row[1])
		if digits then return row[2], tonumber(digits) end
	end
	return nil
end

-- accepts(folderName, kind) -> whether a part of that kind gets the texture in that folder (River: river, pool; Lake:
-- lake; CloudWall: mouth). Never a joint: it lies on the same plane under both block ends (see overlaps above).
function Look.accepts(folderName, kind)
	if folderName == "River" then return kind == "river" or kind == "pool" end
	if folderName == "Lake" then return kind == "lake" end
	if folderName == Look.EAST_FOLDER then return kind == "mouth" end
	return false
end

-- speedFor(kind) -> studs/s: the lake's for the lake discs and the pool, the river's for the rest; 0 for junk.
function Look.speedFor(kind)
	if kind == "lake" or kind == "pool" then return Look.SPEED.lake end
	if kind == "river" or kind == "mouth" then return Look.SPEED.river end
	return 0
end

-- legFor(kind, index, hasLeg) -> the river leg whose block gives the part its direction, or nil (the lake discs share
-- the block nearest the lake's centre, the MouthSheet MOUTH_FLOW). hasLeg(i) says whether Choco_River_<i> is there.
function Look.legFor(kind, index, hasLeg)
	if kind == "river" then return index end
	if kind == "pool" then return hasLeg(1) and 1 or nil end
	return nil
end

-- coverable(kind) -> whether a part of that kind is a drum left plain when a river block covers its centre.
function Look.coverable(kind)
	return kind == "pool" or kind == "lake"
end

Look.INSIDE_MARGIN = 1 -- studs: a centre on a block's edge (a dock basin at a river point) counts as inside

-- insideBlock(px, pz, cx, cz, lookX, lookZ, halfWidth, halfLength) -> whether the flat point (px, pz) lies inside the
-- footprint of a block centred at (cx, cz) whose LookVector is (lookX, lookZ) flat, halfWidth across (its Size.X / 2)
-- and halfLength along (its Size.Z / 2), widened by INSIDE_MARGIN. False for junk or a block with no flat direction.
function Look.insideBlock(px, pz, cx, cz, lookX, lookZ, halfWidth, halfLength)
	for _, value in ipairs({ px, pz, cx, cz, lookX, lookZ, halfWidth, halfLength }) do
		if not finite(value) then return false end
	end
	local m = math.sqrt(lookX * lookX + lookZ * lookZ)
	if m < 1e-6 then return false end
	local lx, lz = lookX / m, lookZ / m
	local dx, dz = px - cx, pz - cz
	local along = dx * lx + dz * lz
	local across = dz * lx - dx * lz
	return math.abs(along) <= halfLength + Look.INSIDE_MARGIN and math.abs(across) <= halfWidth + Look.INSIDE_MARGIN
end

-- upFace(rightY, upY, lookY) -> the face (a NormalId name) whose outward normal points most up, from the Y of the
-- part's RightVector, UpVector and LookVector (Back is -LookVector).
function Look.upFace(rightY, upY, lookY)
	local best, bestY = "Top", -math.huge
	for _, row in ipairs({ { "Top", upY }, { "Right", rightY }, { "Back", -lookY }, { "Front", lookY },
		{ "Left", -rightY }, { "Bottom", -upY } }) do
		if finite(row[2]) and row[2] > bestY + 1e-9 then best, bestY = row[1], row[2] end
	end
	return best
end

-- project(face, lx, ly, lz) -> du, dv: a direction in the part's local axes along that face's texture U and V.
function Look.project(face, lx, ly, lz)
	local axes = Look.UV[face]
	if not axes or not (finite(lx) and finite(ly) and finite(lz)) then return 0, 0 end
	local u, v = axes.u, axes.v
	return lx * u[1] + ly * u[2] + lz * u[3], lx * v[1] + ly * v[2] + lz * v[3]
end

-- offsets(t, speed, du, dv, tile) -> OffsetStudsU, OffsetStudsV at clock t: speed * t studs along (du, dv), wrapped
-- into 0..tile (so the texture never jumps and the numbers stay small).
function Look.offsets(t, speed, du, dv, tile)
	if not (finite(t) and finite(speed) and finite(du) and finite(dv) and finite(tile)) or tile <= 0 then return 0, 0 end
	local travelled = Look.SCROLL_SIGN * speed * t
	return (travelled * du) % tile, (travelled * dv) % tile
end

-- tint(r, g, b) -> the texture's Color3 channels (0..1): the part's colour lifted TINT_LIFT toward white.
function Look.tint(r, g, b)
	local function lift(c)
		if not finite(c) then return 1 end
		c = math.clamp(c, 0, 1)
		return c + (1 - c) * Look.TINT_LIFT
	end
	return lift(r), lift(g), lift(b)
end

-- spec(face, r, g, b) -> the texture's properties for a part of colour (r, g, b) (0..1) whose up face is face.
function Look.spec(face, r, g, b)
	local tr, tg, tb = Look.tint(r, g, b)
	return {
		name = Look.TEXTURE_NAME, image = Look.IMAGE, face = Look.UV[face] and face or "Top",
		studsPerTile = Look.STUDS_PER_TILE, transparency = Look.TRANSPARENCY, color = { tr, tg, tb },
	}
end

-- near(box, x, z, radius) -> whether the flat point (x, z) lies within radius of the box { minX, maxX, minZ, maxZ }.
function Look.near(box, x, z, radius)
	if type(box) ~= "table" or not (finite(x) and finite(z) and finite(radius)) then return false end
	if not (finite(box.minX) and finite(box.maxX) and finite(box.minZ) and finite(box.maxZ)) then return false end
	local dx = math.max(box.minX - x, 0, x - box.maxX)
	local dz = math.max(box.minZ - z, 0, z - box.maxZ)
	return dx * dx + dz * dz <= radius * radius
end

-- shouldScroll(reduced, near) -> whether the texture moves this step: near the chocolate and not with Efectos suaves.
function Look.shouldScroll(reduced, near)
	return reduced ~= true and near == true
end

return table.freeze(Look)
