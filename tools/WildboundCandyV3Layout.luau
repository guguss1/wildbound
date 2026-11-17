-- Caramelo v3 (owner request 2026-11-17; odd/tasks/wildbound-caramelo-v2.md "Caramelo v3"; plan
-- docs/design/wildbound-caramelo-v3-plan.md): the new pieces of the candy biome laid over layout VERSION 3
-- (WildboundCandyLayout): a big chocolate river that leaves the outlet of the big ice-cream mountain's waterfall pool
-- in the south-east corner, runs along the south of the plot and pours into the chocolate lake under the left route's
-- bridge; the raft's two docks, seven enterable houses, the rainbow licorice arch over the main path, the modular cake,
-- the cookie platforms on the lake, the tree swap rule and the filler that keeps the map from feeling empty.
-- Pure data and flat geometry: no services, no clock, no random, no require. Coordinates are local to the plot centre
-- (Layout.CENTRE), x east, z as in the world, like WildboundCandyLayout. Functions that need the base layout take it as
-- an argument. The kit numbers (sizes, pool, outlet, sockets) come from tools/WildboundCandyV3KitSpec.luau (generated
-- from the Blender kits' contracts); tools/test_caramelo_v3.py checks they agree. WildboundCandyV3Builder lays it out;
-- WildboundCandyV3Layout_Test and tools/test_caramelo_v3.py hold the rules. Every number is a first proposal to tune.
local V3 = {}

local function freeze(value)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in pairs(value) do freeze(child) end
		table.freeze(value)
	end
	return value
end

V3.VERSION = 1
-- The root attribute the migration sets (tools/wildbound-caramelo-v3-migrate.luau) and the folder every v3 piece
-- lives in (root.CaramelV3.<Piece folder>), so the whole batch can be archived in one move.
V3.MARK = "CaramelV3"
V3.FOLDER = "CaramelV3"
V3.SEED = 20261117
-- V3-D18 (review M1): what the candy creatures make of the v3 pieces (WildboundBeasts.server refreshFilter). A model
-- tagged PASS (houses, the tower, the cake) is not there for them: no ground, no wall, no cover, so a chase follows a
-- player inside instead of landing on a roof. A model tagged OVERHEAD (mountains, hills, the licorice) is still a wall
-- but never ground, so no creature lands on a summit or an arch.
V3.BEAST_PASS_TAG = "WildboundBeastPass"
V3.BEAST_OVERHEAD_TAG = "WildboundBeastOverhead"
-- The kits the Blender agents deliver: ServerStorage.WildboundAssets.CandyKitV3.<AssetName>, one Model each, pivot at
-- the ground centre of the base, front -Z, meshes that never collide (the builder makes the Collision_ parts from the
-- kit spec). A missing model is replaced by a plain-part placeholder of the same footprint (WildboundCandyV3Builder).
V3.KIT_FOLDER = "CandyKitV3"
V3.ASSETS = freeze({
	"CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple", "CV3_IceCreamMountain_L", "CV3_IceCreamMountain_M",
	"CV3_LicoriceArch", "CV3_CakeBase", "CV3_CakeRamp", "CV3_CakeTop", "CV3_CookieS", "CV3_CookieM", "CV3_CookieL",
	"CV3_SweetHouse", "CV3_ChocoHouse", "CV3_CaramelTower", "CV3_BananaRaft",
})

-- V3-D6: the chocolate is shallow and walk-through. Its surface is a non-colliding, non-queried volume `depth` studs
-- over the floor (the floor stays the ground every ray and every foot meets), so a player wades knee-deep, never swims
-- and never drowns, and the creatures keep chasing straight through it. 1.3 is the kit's pool surface and the raft's
-- draft, so the raft floats on it with its hull just off the floor.
V3.LIQUID = freeze({ depth = 1.3, color = { 92, 52, 34 }, transparency = 0.08 })

-- The ice-cream mountains (the biome's relief): { id, asset, x, z, scale, r (footprint at that scale), height, faceX,
-- faceZ (the kit's front, its pool outlet, turns towards that point) }. M1 feeds the river: its outlet is RIVER[1].
-- Footprint: 54 (L) or 35.5 (M) studs x scale, the kit's widest half side plus its pivot offset.
V3.MOUNTAINS = freeze({
	{ id = "M1", asset = "CV3_IceCreamMountain_L", x = 170, z = -118, scale = 0.55, r = 29.7, height = 49.7,
		faceX = 128, faceZ = -168, river = true },
	{ id = "M2", asset = "CV3_IceCreamMountain_M", x = 184, z = -72, scale = 0.4, r = 14.2, height = 24.1, faceX = 0, faceZ = 0 },
	{ id = "M3", asset = "CV3_IceCreamMountain_M", x = 76, z = 187, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
	{ id = "M4", asset = "CV3_IceCreamMountain_M", x = 122, z = 187, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
	{ id = "M5", asset = "CV3_IceCreamMountain_M", x = -186, z = -186, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
	{ id = "M6", asset = "CV3_IceCreamMountain_M", x = -186, z = 186, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
})

-- The river: { x, z, w } points from M1's outlet to the lake; w is the width at that point. A leg is as wide as its
-- wider end for every clearance rule (V3.liquidDistance), so the rules are on the safe side of what is laid.
V3.RIVER = freeze({
	{ 152.7, -139.1, 14 }, -- M1's outlet (kit outlet x 0.55, turned to face (128, -168))
	{ 128, -168, 24 },
	{ 96, -186, 20 }, -- the south run, under nests C13 and C8
	{ 40, -187, 20 },
	{ -6, -185, 20 },
	{ -24, -168, 24 }, -- turns north between posts C10 and C6
	{ -24, -140, 24 }, -- under the bridge of the left route
	{ -14, -118, 24 }, -- into the lake
})
-- M1's waterfall pool (the kit's pool centre and radius x 0.55, at the kit's turn) and the waterfall: the kit's own
-- sheet falls from the ledge (33.72 x 0.55 studs) into the pool; the builder adds streaks of lighter chocolate in front
-- of it that slide down on the client (WildboundCandyAmbienceClient reads their attributes). Without the kit, a
-- placeholder sheet stands there.
V3.POOL = freeze({ x = 156.9, z = -134.1, r = 6.05 })
V3.WATERFALL = freeze({ x = 159.3, z = -131.3, width = 8, top = 18.5, faceX = 156.9, faceZ = -134.1, streaks = 5,
	flowSpeed = 12 }) -- review m8: top is studs over the floor (the kit ledge 33.72 x 0.55), not a world height
-- The chocolate lake: the old Laguna de Almibar's three discs (now covered in chocolate) and a wider disc to the
-- north, where the river ends and the cookie platforms float.
V3.LAKE = freeze({
	{ x = 0, z = -110, r = 30 },
	{ x = 0, z = -120, r = 24 },
	{ x = 26, z = -134, r = 16 },
	{ x = -26, z = -134, r = 16 },
})
-- The bridge: the left route's bottom leg crosses the river mouth and the lake here. A deck `deck` studs over the floor
-- (above the liquid), `width` wide, from x - length/2 to x + length/2 along the route, and a ramp of `ramp` studs at
-- each end. It replaces the old flat biscuit tiles (the migration archives them). V3-D19 (review M3): the rails open in
-- gaps of gapWidth studs centred at x + gaps[i], each with a walkable side ramp of sideRamp studs down to the floor on
-- both sides, so a wader, an egg run or a creature crosses north-south without a detour.
V3.BRIDGE = freeze({ x = 0, z = -140, length = 88, ramp = 7, width = 16, deck = 2.2, route = "left",
	gaps = { -30, 0, 30 }, gapWidth = 8, sideRamp = 6 })

-- The houses (enterable, with an interior, kit scale 1 so the 7 x 9.5 doors fit an avatar): { id, asset, x, z, r (the
-- footprint disc round the kit's bounding box) }. Each faces the junction.
V3.HOUSES = freeze({
	{ id = "H1", asset = "CV3_SweetHouse", x = -160, z = 160, r = 20 },
	{ id = "H2", asset = "CV3_CaramelTower", x = -120, z = 178, r = 15 },
	{ id = "H3", asset = "CV3_ChocoHouse", x = -165, z = -160, r = 16 },
	{ id = "H4", asset = "CV3_SweetHouse", x = 178, z = 100, r = 20 },
	{ id = "H5", asset = "CV3_CaramelTower", x = -180, z = 76, r = 15 },
	{ id = "H6", asset = "CV3_ChocoHouse", x = 182, z = -176, r = 16 }, -- review m5: off dock B's ramp
	{ id = "H7", asset = "CV3_SweetHouse", x = 20, z = 172, r = 20 },
})
-- Placeholder sizes (side of the square, wall height) when a house model is missing.
V3.HOUSE_PLACEHOLDER = freeze({ CV3_SweetHouse = { 24, 14 }, CV3_ChocoHouse = { 22, 14 }, CV3_CaramelTower = { 20, 20 } })

-- The raft docks, one on each bank of the river's first leg below the waterfall: stand (on the bank, where a player
-- boards and is set down) and tip (over the river, where the raft waits). The raft's lane goes tip A -> upstream
-- towards the waterfall -> tip B (WildboundCandyRaft). homeDock is where it respawns.
V3.DOCKS = freeze({
	{ id = "A", standX = 123.6, standZ = -139.3, tipX = 135, tipZ = -149 },
	{ id = "B", standX = 157.1, standZ = -167.9, tipX = 145.7, tipZ = -158.1 },
})
V3.RAFT = freeze({ asset = "CV3_BananaRaft", lane = { { 135, -149 }, { 148.5, -144 }, { 145.7, -158.1 } }, homeDock = 1 })
-- A dock's build (review m5, m6): its deck stops tipGap studs short of the tip (the docked hull's room), its ramp
-- starts rampBack studs behind the stand, deckWidth wide; its top stands deckOver studs over the chocolate's surface.
V3.DOCK = freeze({ deckWidth = 6, tipGap = 5, rampBack = 5, deckOver = 0.4 })

-- The rainbow licorice arch (CV3_LicoriceArch) over the main path, between the entrance and the fork, its span (the
-- kit's X) across the path. The kit's ribbon meets the ground at four feet, feet = { |x| of the inner pair, of the
-- outer pair } with their footprint radii, at kit scale 1; everything scales by `scale`.
V3.LICORICE = freeze({ x = -124, z = 0, scale = 0.8, height = 27, span = 62.3,
	feet = { { offset = 20.6, r = 5.7 }, { offset = 34.8, r = 4.5 } } })
-- The modular cake (CV3_CakeBase, CV3_CakeTop on its top_tier socket, CV3_CakeRamp at its ramp_front socket), in the
-- open north-west, its front (and ramp) facing (faceX, faceZ). r is the base's footprint, rampReach how far in front
-- of the centre the ramp's low end lies, both at `scale`.
V3.CAKE = freeze({ x = -150, z = 112, scale = 0.8, r = 18, rampReach = 38.5, faceX = -150, faceZ = 0, height = 21.6 })
-- The cookie platforms standing on the lake floor, their walk tops over the surface (kit scale 1).
V3.PLATFORMS = freeze({
	{ asset = "CV3_CookieM", x = -12, z = -112, r = 6.7 },
	{ asset = "CV3_CookieL", x = 10, z = -100, r = 11.7 },
	{ asset = "CV3_CookieS", x = 20, z = -122, r = 3.9 },
	{ asset = "CV3_CookieS", x = -22, z = -100, r = 3.9 },
})

-- V3-D9 tree rule: every old tree of a kind on the left takes the new kind on the right at the same spot and turn,
-- scaled to the old tree's height (heightFactor), then fitted by the CH clearance rule (WildboundCandyBuilder.treeFits):
-- smaller down to minFactor, or nudged by one of nudges; a tree that still does not fit keeps its old model. The
-- lollipops stay (the avenue of lollipops is a path, not a wood). A cotton tree's Roof disc (La Nube's sky ray) moves
-- into the new tree.
V3.TREES = freeze({
	map = { TreeCotton_S = "CV3_TreeCotton", TreeCotton_M = "CV3_TreeCotton", TreeCotton_L = "CV3_TreeCotton",
		TreeCream = "CV3_TreeIceCream", TreeCookie = "CV3_TreeCaramelApple" },
	heightFactor = 1, minFactor = 0.7, step = 0.05, nudges = { 2, 4, 6, 8 },
	-- the placeholder's shape, per unit of height: trunk radius and crown radius
	trunk = 0.05, crown = 0.3,
	attribute = "CaramelTreeV3",
})

-- Filler (V3-D11, "the map must not feel empty"): candy props of the old kit (WildboundCandyKit) along both banks of
-- the river and round each house, and small ice-cream hills by the plot edge; seeded (SEED), each on open ground.
V3.FILLER = freeze({
	bankEvery = 22, bankOffset = 7, perHouse = 3, hills = 6, hillScale = 0.2,
	assets = { "GumdropBush_A", "GumdropBush_B", "CreamMushroom", "ConfettiPile", "RockChocolate" },
	reach = 4,
})

-- Clearances (studs) every piece keeps, checked by the suites.
V3.CLEAR = freeze({
	nestFromLiquid = 6, -- a nest centre this far beyond the liquid's edge
	postFromLiquid = 8, -- a creature post (WildboundPraderaSites.FIXED) this far beyond it
	pieceFromNest = 8, -- a solid piece's edge this far from a nest centre
	pieceFromPost = 6,
	pieceFromRoute = 3, -- beyond the path's edge
	pieceApart = 2,
	trapFromAnything = 10,
	edgeDepth = 2, -- a house or the cake this far inside the plot edge; a mountain may touch it
})

-- Part budget (V3-D12): what the v3 batch may add on the live map (kit colliders counted; the tree swap is counted on
-- its own) and the whole biome's cap.
V3.MAX_NEW_PARTS = 1300
V3.BIOME_PART_CAP = 2800

-- Geometry ---------------------------------------------------------------------------------------------------
local function flat(ax, az, bx, bz) return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2) end
V3.flat = flat

function V3.segmentDistance(x, z, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local length2 = dx * dx + dz * dz
	local t = 0
	if length2 > 0 then t = math.clamp(((x - ax) * dx + (z - az) * dz) / length2, 0, 1) end
	return flat(x, z, ax + dx * t, az + dz * t)
end

-- Signed distance from (x, z) to the edge of the river band: negative inside.
function V3.riverDistance(x, z)
	local best = math.huge
	for i = 1, #V3.RIVER - 1 do
		local a, b = V3.RIVER[i], V3.RIVER[i + 1]
		best = math.min(best, V3.segmentDistance(x, z, a[1], a[2], b[1], b[2]) - math.max(a[3], b[3]) / 2)
	end
	return best
end

-- Signed distance to the nearest chocolate (river, pool or lake): negative inside.
function V3.liquidDistance(x, z)
	local best = V3.riverDistance(x, z)
	best = math.min(best, flat(x, z, V3.POOL.x, V3.POOL.z) - V3.POOL.r)
	for _, disc in ipairs(V3.LAKE) do best = math.min(best, flat(x, z, disc.x, disc.z) - disc.r) end
	return best
end

function V3.riverLength()
	local total = 0
	for i = 1, #V3.RIVER - 1 do
		local a, b = V3.RIVER[i], V3.RIVER[i + 1]
		total += flat(a[1], a[2], b[1], b[2])
	end
	return total
end

-- Whether (x, z) is on the bridge's deck (deckOnly = true) or on the deck or one of its ramps.
function V3.onBridge(x, z, deckOnly)
	local B = V3.BRIDGE
	local reach = B.length / 2 + (deckOnly and 0 or B.ramp)
	return math.abs(z - B.z) <= B.width / 2 and math.abs(x - B.x) <= reach
end

-- The liquid surface height in world studs, for a layout floor top.
function V3.surfaceY(floorTop)
	return floorTop + V3.LIQUID.depth
end

-- The yaw (radians about +Y) that turns a model's look vector (-Z) from (x, z) towards (tx, tz).
function V3.faceYaw(x, z, tx, tz)
	return math.atan2(-(tx - x), -(tz - z))
end

-- A kit-local point (X, Z, Roblox axes) of a piece at (x, z) turned by yaw and scaled: the plot point { x, z }.
function V3.kitPoint(x, z, yaw, scale, X, Z)
	X, Z = X * scale, Z * scale
	return x + X * math.cos(yaw) + Z * math.sin(yaw), z - X * math.sin(yaw) + Z * math.cos(yaw)
end

-- A dock's ramp foot and the middle of its deck (plot coordinates).
function V3.dockPoints(d)
	local dx, dz = d.tipX - d.standX, d.tipZ - d.standZ
	local length = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / length, dz / length
	local deckEnd = length - V3.DOCK.tipGap
	return { x = d.standX - ux * V3.DOCK.rampBack, z = d.standZ - uz * V3.DOCK.rampBack },
		{ x = d.standX + ux * deckEnd / 2, z = d.standZ + uz * deckEnd / 2 }, { x = ux, z = uz }, deckEnd
end

-- Every solid footprint of the batch as discs: { kind, id, x, z, r }. The docks are their stand points, the
-- licorice its four feet, the cake its base and its ramp.
function V3.pieces()
	local list = {}
	for _, m in ipairs(V3.MOUNTAINS) do table.insert(list, { kind = "mountain", id = m.id, x = m.x, z = m.z, r = m.r }) end
	for _, h in ipairs(V3.HOUSES) do table.insert(list, { kind = "house", id = h.id, x = h.x, z = h.z, r = h.r }) end
	for _, d in ipairs(V3.DOCKS) do
		-- review m5/m7: the stand, the ramp's foot and the deck's middle, each as a disc of the deck's half width
		local foot, mid = V3.dockPoints(d)
		table.insert(list, { kind = "dock", id = d.id, x = d.standX, z = d.standZ, r = 3 })
		table.insert(list, { kind = "dock", id = d.id .. "Ramp", x = foot.x, z = foot.z, r = V3.DOCK.deckWidth / 2 + 0.5 })
		table.insert(list, { kind = "dock", id = d.id .. "Deck", x = mid.x, z = mid.z, r = V3.DOCK.deckWidth / 2 })
	end
	local Lc = V3.LICORICE
	for i, foot in ipairs(Lc.feet) do
		for k, side in ipairs({ -1, 1 }) do
			table.insert(list, { kind = "licorice", id = "Foot" .. i .. k, x = Lc.x, z = Lc.z + side * foot.offset * Lc.scale,
				r = foot.r * Lc.scale })
		end
	end
	local K = V3.CAKE
	table.insert(list, { kind = "cake", id = "Base", x = K.x, z = K.z, r = K.r })
	local yaw = V3.faceYaw(K.x, K.z, K.faceX, K.faceZ)
	local mid = (K.r + K.rampReach) / 2
	local rx, rz = K.x - math.sin(yaw) * mid, K.z - math.cos(yaw) * mid
	table.insert(list, { kind = "cake", id = "Ramp", x = rx, z = rz, r = (K.rampReach - K.r) / 2 + 2 })
	return list
end

-- Whether a prop of reach r may stand at local (x, z) among the v3 pieces: off the chocolate by margin, off every
-- piece's disc by margin, off the bridge. Returns true, or false and why. (The base layout's ground is the builder's.)
function V3.clearOfPieces(x, z, r, margin)
	margin = margin or 2
	if V3.liquidDistance(x, z) < r + margin then return false, "in the chocolate" end
	for _, p in ipairs(V3.pieces()) do
		if flat(x, z, p.x, p.z) < p.r + r + margin then return false, "on " .. p.kind .. " " .. p.id end
	end
	if V3.nearBridge(x, z, r + margin) then return false, "on the bridge" end
	return true
end

-- Whether something of the given reach at (x, z) touches the bridge: its deck, end ramps or side ramps (review m7).
function V3.nearBridge(x, z, reach)
	local B = V3.BRIDGE
	reach = reach or 0
	return math.abs(z - B.z) <= B.width / 2 + B.sideRamp + reach and math.abs(x - B.x) <= B.length / 2 + B.ramp + reach
end

-- The raft's lane in world coordinates for a plot centre { x, z }: a list of { x, z }.
function V3.raftLane(centre)
	local out = {}
	for i, p in ipairs(V3.RAFT.lane) do out[i] = { x = centre.x + p[1], z = centre.z + p[2] } end
	return out
end

-- Points every `step` studs along the river's centreline: { x, z, w (the leg's band width), along }.
function V3.riverSamples(step)
	step = step or 2
	local out, travelled = {}, 0
	for i = 1, #V3.RIVER - 1 do
		local a, b = V3.RIVER[i], V3.RIVER[i + 1]
		local length = flat(a[1], a[2], b[1], b[2])
		local n = math.max(1, math.ceil(length / step))
		for s = 0, n - 1 do
			local t = s / n
			table.insert(out, { x = a[1] + (b[1] - a[1]) * t, z = a[2] + (b[2] - a[2]) * t, w = math.max(a[3], b[3]),
				along = travelled + length * t })
		end
		travelled += length
	end
	local last = V3.RIVER[#V3.RIVER]
	table.insert(out, { x = last[1], z = last[2], w = last[3], along = travelled })
	return out
end

return freeze(V3)
