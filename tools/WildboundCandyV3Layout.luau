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

-- Caramelo v4 (owner's second round 2026-11-17; odd/tasks/wildbound-caramelo-v2.md "Caramelo v4", decisions V4-D1 to
-- V4-D10; docs/design/wildbound-caramelo-v3-plan.md "Caramelo v4"): VERSION 2. The river is a north-south barrier west
-- of the cake's territory, from M1's waterfall by the north edge through the chocolate lake to the south edge, with a
-- bridge on every route leg it crosses (BRIDGES); the chocolate is 3.5 deep; the new trees are 35 % taller; three
-- houses are built at 1.4; pink hills replace the yellow crystals; the edge band is filled and a backdrop stands
-- outside the east edge. tools/wildbound-caramelo-v4-migrate.luau changes the live map (mark V4_MARK).
-- Caramelo v5 (owner's third round 2026-11-17; odd/tasks/wildbound-caramelo-v2.md "Caramelo v5", V5-D3 to V5-D5;
-- docs/design/wildbound-caramelo-v3-plan.md "Caramelo v5", V5-D10 on): VERSION 3. A wider river (24 on the open legs,
-- narrower only where a nest or a post leaves no room), a bigger lake (two discs, as big as the nests, posts and the left
-- route allow), longer Top and Bottom bridges, the docks on the new banks. tools/wildbound-caramelo-v5-migrate.luau
-- changes the live map (mark V5_MARK).
-- Caramelo v8 (owner request 2026-11-17, "make the Reino Caramelo map a bit bigger ... more space between things";
-- docs/design/wildbound-caramelo-v8-plan.md, V8-D1): VERSION 4, so the older migrations refuse to run. The plot grows
-- 1.3 times about its centre (WildboundCandyLayout HALF 200 -> 260). Every position below keeps its v7 literal, mapped
-- at load (x S); sizes, radii, widths and deck lengths keep their v7 values. The exceptions say V8-D1: re-anchored to
-- an edge, or translated with their parent (M1, a lake disc, a bridge), their v7 offset kept.
-- tools/wildbound-caramelo-v8-migrate.luau changes the live map.
-- Caramelo v9 (owner request 2026-11-18, "agranda mas el bioma caramelo a lo largo, el rio necesito qeu sea 5 veces su
-- ancho asi es navegable por la balsa"; docs/design/wildbound-caramelo-v9-plan.md, CL-D1..CL-D18): VERSION 5, so the
-- v3..v8 tools refuse to run. The plot grows 600 studs east only (WildboundCandyLayout.EAST 860). One long river runs
-- west to east from M1's waterfall in the south-west corner to the east edge, 50..120 wide; three raised bridges let
-- the raft pass under; four docks. Rows marked CL-D are v9 plot-local literals; the kept west rows keep their v7
-- literals, mapped by v8(). tools/wildbound-caramelo-v9-migrate.luau changes the live map (mark V9_MARK).
V3.VERSION = 5
-- V8-D1: this module requires nothing, so it carries its own copy of WildboundCandyLayout.V8.S and HALF;
-- WildboundCandyV3Layout_Test pins that they agree.
V3.V8 = freeze({ S = 1.3, HALF = 260, OLD_HALF = 200 })
-- CL-D2: the same for WildboundCandyLayout.EAST (V3-1 pins it).
V3.V9 = freeze({ EAST = 860 })
local S, HALF, EAST = V3.V8.S, V3.V8.HALF, V3.V9.EAST
-- A v7 plot-local coordinate in the v8 plot.
local function v8(n) return n * S end
-- CL-D9: the Gran Torta's x, as WildboundCandyLayout computes it (the v8 spot + the growth, the same float).
local TORTA_X = v8(114) + (EAST - HALF)
V3.V4_MARK = "CaramelV4"
V3.V5_MARK = "CaramelV5"
V3.V9_MARK = "CaramelV9"
-- The root attribute the migration sets (tools/wildbound-caramelo-v3-migrate.luau) and the folder every v3 piece
-- lives in (root.CaramelV3.<Piece folder>), so the whole batch can be archived in one move.
V3.MARK = "CaramelV3"
V3.FOLDER = "CaramelV3"
V3.SEED = 20261117
-- V3-D18 (review M1): what the candy creatures make of the v3 pieces (WildboundBeasts.server refreshFilter). A model
-- tagged PASS (the cake; V4-D12: no longer the houses, which are OVERHEAD now) is not there for them: no ground, no wall, no cover, so a chase follows a
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
-- V4-D2: 3.5 studs deep (was 1.3), still walk-through over the floor; bridge decks, dock decks and cookie platforms
-- stand over this surface.
V3.LIQUID = freeze({ depth = 3.5, color = { 92, 52, 34 }, transparency = 0.08 })

-- The yaw (radians about +Y) that turns a model's look vector (-Z) from (x, z) towards (tx, tz).
function V3.faceYaw(x, z, tx, tz)
	return math.atan2(-(tx - x), -(tz - z))
end

-- A kit-local point (X, Z, Roblox axes) of a piece at (x, z) turned by yaw and scaled: the plot point { x, z }.
function V3.kitPoint(x, z, yaw, scale, X, Z)
	X, Z = X * scale, Z * scale
	return x + X * math.cos(yaw) + Z * math.sin(yaw), z - X * math.sin(yaw) + Z * math.cos(yaw)
end

-- CL-D4: M1's kit offsets, { X, Z } in the kit's frame at scale 1: the river outlet, the pool's centre and radius, and
-- where the kit's sheet meets the pool (the fall), copied from WildboundCandyV3KitSpec CV3_IceCreamMountain_L.water
-- (WildboundCandyV3Layout_Test V3-1 pins them). V3.kitPoint places them at M1's spot, turn and scale.
V3.M1_KIT = freeze({ outlet = { 0.5653, -49.6671 }, pool = { 0.5653, -37.6671 }, poolRadius = 11, fall = { 0.5653, -31.0 } })
-- The kit's ledge height (studs over the floor at scale 1): the waterfall's top.
local KIT_LEDGE = 33.72
-- CL-D4: the v8 M1 row (north edge, scale 0.45), frozen as a record for the regression pin: kitPoint there gives the
-- v8 pool (-8.44, 219.36) (WildboundCandyV3Layout_Test V3-24). Nothing lays it.
V3.M1_V8 = freeze({ x = -5.2, z = 236, scale = 0.45, faceX = -13.2, faceZ = 198 })

-- The ice-cream mountains (the biome's relief): { id, asset, x, z, scale, r (footprint at that scale), height, faceX,
-- faceZ (the kit's front, its pool outlet, turns towards that point) }. M1 feeds the river: its outlet is RIVER[1].
-- Footprint: 54 (L) or 35.5 (M) studs x scale, the kit's widest half side plus its pivot offset.
-- V4-D1: M1 moved to the north edge (scale 0.55 -> 0.45 to fit between nests C11 and C7; its footprint touches the
-- edge, so it closes the barrier there), M2 and M4 moved off the east edge's pink hills and the freed south-east.
-- V8-D1: M2, M3, M4 and M6 keep their v7 literals, scaled by v8().
-- CL-D4: M1 moves to the south-west corner at 0.75 (r 40.5, height 67.82): depth 40.2 >= r - 0.5, so it closes the
-- corner (overhanging both edges by 0.3); it faces RIVER[2]. CL-D12: M5 gives M1 its corner and moves east, facing the
-- Torta; M7 (L 0.45, facing the Torta) and M8 (M 0.4, facing the east fork) are new. The v9 rows are local literals.
do
	local list = {}
	for i, row in ipairs({
		{ id = "M1", asset = "CV3_IceCreamMountain_L", x = -219.8, z = -219.8, scale = 0.75, r = 40.5, height = 67.82,
			faceX = -150, faceZ = -224, river = true, v9 = true },
		{ id = "M2", asset = "CV3_IceCreamMountain_M", x = 180, z = -90, scale = 0.4, r = 14.2, height = 24.1, faceX = 0, faceZ = 0 },
		{ id = "M3", asset = "CV3_IceCreamMountain_M", x = 76, z = 187, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
		{ id = "M4", asset = "CV3_IceCreamMountain_M", x = 165, z = -120, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
		{ id = "M5", asset = "CV3_IceCreamMountain_M", x = 800, z = -236, scale = 0.37, r = 13.1, height = 22.3,
			faceX = TORTA_X, faceZ = 0, v9 = true },
		{ id = "M6", asset = "CV3_IceCreamMountain_M", x = -187, z = 187, scale = 0.37, r = 13.1, height = 22.3, faceX = 0, faceZ = 0 },
		{ id = "M7", asset = "CV3_IceCreamMountain_L", x = 790, z = -170, scale = 0.45, r = 24.3, height = 40.7,
			faceX = TORTA_X, faceZ = 0, v9 = true },
		{ id = "M8", asset = "CV3_IceCreamMountain_M", x = 300, z = 230, scale = 0.4, r = 14.2, height = 24.1,
			faceX = 300, faceZ = 0, v9 = true },
	}) do
		if not row.v9 then
			row.x, row.z, row.faceX, row.faceZ = v8(row.x), v8(row.z), v8(row.faceX), v8(row.faceZ)
		end
		row.v9 = nil
		list[i] = row
	end
	V3.MOUNTAINS = freeze(list)
end

-- The river: { x, z, w } points from M1's outlet to the mouth; w is the width at that point. A leg is as wide as its
-- wider end for every clearance rule (V3.liquidDistance), so the rules are on the safe side of what is laid; a width
-- step gets its own point.
-- CL-D3 (Caramelo v9, "5 veces su ancho"): one long west-to-east river, 1412 studs. From M1's outlet in the south-west
-- corner it runs as a 50..64-wide channel along the -z edge of the west half (64 is what the left route's bottom leg at
-- z -182 leaves), turns into a straight 60-wide north-south reach at x 470 (the three raised bridges, the barrier), and
-- widens to 90..120 (5 x the v8 24) along the +z edge to the east edge, where the last point lies, under the cloud wall.
-- It flows west to east. Points 2..16 are local literals; point 1 is M1's kit outlet (kitPoint).
do
	local m1 = V3.MOUNTAINS[1]
	local K = V3.M1_KIT
	local yaw = V3.faceYaw(m1.x, m1.z, m1.faceX, m1.faceZ)
	local ox, oz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.outlet[1], K.outlet[2])
	local px, pz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.pool[1], K.pool[2])
	local wx, wz = V3.kitPoint(m1.x, m1.z, yaw, m1.scale, K.fall[1], K.fall[2])
	V3.RIVER = freeze({
		{ ox, oz, 12 / 0.45 * m1.scale }, -- 1: M1's outlet (-182.59, -221.61), 20 wide (the v8 12 at 0.45, x 0.75)
		{ -150, -224, 50 }, -- 2: M1 faces it; dock A
		{ -60, -225, 64 }, -- 3: 3 studs inside the -z edge
		{ 40, -224, 64 }, -- 4: 10 off the left route's bottom leg
		{ 140, -225, 64 }, -- 5
		{ 240, -224, 64 }, -- 6: dock B
		{ 330, -218, 64 }, -- 7
		{ 400, -210, 60 }, -- 8: the bend
		{ 445, -200, 60 }, -- 9
		{ 470, -175, 60 }, -- 10: the reach starts
		{ 470, 175, 60 }, -- 11: the reach ends (350 long; the Bottom, Main and Top bridges)
		{ 510, 200, 90 }, -- 12
		{ 575, 195, 110 }, -- 13: 10 off the north route
		{ 650, 195, 120 }, -- 14: the harbour lake, dock C
		{ 760, 195, 120 }, -- 15
		{ EAST, 195, 120 }, -- 16: the mouth, on the east edge
	})
	-- M1's waterfall pool (the kit's pool centre and radius at M1's scale and turn) and the waterfall: the kit's own
	-- sheet falls from the ledge into the pool; the builder adds streaks of lighter chocolate in front of it that slide
	-- down on the client (WildboundCandyAmbienceClient reads their attributes). V4-D11: the pool disc is laid at the
	-- river's depth even with the kit (the kit's own pool is 0.6 deep). CL-D4: both from the kit by kitPoint, the sheet's
	-- width and top at 0.75 (11.67 and 25.29; review m8: top is studs over the floor, not a world height).
	V3.POOL = freeze({ x = px, z = pz, r = K.poolRadius * m1.scale })
	V3.WATERFALL = freeze({ x = wx, z = wz, width = 7 / 0.45 * m1.scale, top = KIT_LEDGE * m1.scale, faceX = px, faceZ = pz,
		streaks = 5, flowSpeed = 12 })
end
-- The chocolate lake: { x, z, r } discs. CL-D3: order matters, 1 and 2 are the lake proper, 3..5 the dock basins.
-- 1 is the harbour lake on the east stretch (the island, the cookie platforms, dock C), 2 its west lobe. Each river
-- dock gets a basin wholly inside the river band, so its tip sits at least LAKE_BLEND (8) inside a disc and the current
-- there is the lake's 1.5: 3 basin A (its rim at least 8 inside the band), 4 basin B (6.06), 5 basin D (3).
V3.LAKE = freeze({
	{ x = 670, z = 170, r = 52 },
	{ x = 580, z = 172, r = 34 },
	{ x = -150, z = -222, r = 22 },
	{ x = 240, z = -222, r = 24 },
	{ x = 815, z = 170, r = 32 },
})
-- The bridges (V4-D1): one on every route leg the river crosses, each straight on that leg: { id, route, from, to (the
-- leg's two route points), at (studs from `from` to the deck's centre), length (the deck), gaps (rail gaps, studs
-- along the deck from its centre) }. Every bridge shares BRIDGE_BUILD: a deck `width` wide whose top stands `deck`
-- studs over the floor (V4-D2: 0.6 over the 3.5 surface), a ramp of `ramp` studs at each end (24.5 degrees), and in
-- each rail gap (gapWidth) a side ramp of sideRamp studs down to the floor on both sides (V3-D19, V3-D25: 6 studs off
-- every creature post). V4-D16: round the junction the river is an arc 30.5 studs from it, 10 wide, so the main
-- avenue and the two last legs cross it square on short bridges (15 wide) that never touch; those three have no gaps
-- (their side ramps would meet the next bridge; the walk round is short). V3.BRIDGES carries x, z (the deck centre) and ux, uz (along).
-- V5-D12: over the 24-wide river the Top deck is 28 (was 22, at 31: x -9) and the Bottom deck 28 (was 24, at 76: x 26);
-- the three junction bridges are unchanged.
-- CL-D7 (Caramelo v9): three raised bridges the raft passes under. The deck stands 12.5 over the floor, so its underside
-- (12.5 - 0.4 - LIQUID.depth = 8.6) clears RAFT.clearance (8); ramps of 28 studs (24.06 degrees). No rail gaps (gaps
-- {}, so no side ramps). pier: four blocks (size x size) under the deck's corners, inset studs in from its ends and
-- sides, from the floor to the deck's underside (WildboundCandyV3Builder layBridge), so kids see the raft fits under.
V3.BRIDGE_BUILD = freeze({ width = 15, deck = 12.5, ramp = 28, gapWidth = 8, sideRamp = 28, pier = { size = 2, inset = 1 } })
-- CL-D7: three rows, all square to the straight 60-wide reach at x 470, each deck 68 long (the wet span reaches 31 of
-- its 34-stud half). Top on the north route, Main on the main avenue (it never breaks), Bottom on the south route; the
-- v8 Top, RightLast, Main, LeftLast and Bottom are retired with the old water. v9 local literals; Main's `to` is the
-- avenue's end like WildboundCandyLayout.ROUTES.main (the Torta's x less the plaza's 58), the same float.
local BRIDGE_ROWS = {
	{ id = "Top", route = "north", from = { 320, 125 }, to = { 620, 125 }, at = 150, length = 68, gaps = {} },
	{ id = "Main", route = "main", from = { 0, 0 }, to = { TORTA_X - 58, 0 }, at = 470, length = 68, gaps = {} },
	{ id = "Bottom", route = "south", from = { 320, -125 }, to = { 640, -125 }, at = 150, length = 68, gaps = {} },
}
do
	local list = {}
	for i, row in ipairs(BRIDGE_ROWS) do
		local dx, dz = row.to[1] - row.from[1], row.to[2] - row.from[2]
		local length = math.sqrt(dx * dx + dz * dz)
		local b = table.clone(row)
		b.ux, b.uz = dx / length, dz / length
		b.x, b.z = row.from[1] + b.ux * row.at, row.from[2] + b.uz * row.at
		for key, value in pairs(V3.BRIDGE_BUILD) do b[key] = value end
		list[i] = b
	end
	V3.BRIDGES = freeze(list)
end

-- The houses (enterable, with an interior): { id, asset, x, z, r (the footprint disc round the kit's bounding box at
-- its scale), scale, turn (degrees added to facing the junction) }. Each faces the junction; V4-D15: the caramel
-- towers (balcony at the kit's +Z) turn 180 degrees, so the balcony looks at the kingdom and the door faces away. V4-D5: H1, H3 and H5 (one of each kind) at kit scale 1.4 (doors 9.8 x
-- 13.3); the others at 1 (7 x 9.5). V4-D1: H2, H3, H5, H6 and H7 moved for the bigger houses, M1 and the pink hills.
-- V8-D1: the spots scale; footprints and kit scales stay.
-- CL-D12 (Caramelo v9): 7 -> 10 houses. H3 and H6 move out of the river's west channel; H8 (Sweet), H9 (Choco) and H10
-- (a caramel tower) are new on the grown east; still a house in every quarter. The moved and new rows (v9 = true) are
-- local literals; H1, H2, H4, H5 and H7 keep their v7 literals, scaled by v8(). WildboundCandyLife.HOUSES copies them.
do
	local list = {}
	for i, row in ipairs({
		{ id = "H1", asset = "CV3_SweetHouse", x = -148, z = 166, r = 28, scale = 1.4 },
		{ id = "H2", asset = "CV3_CaramelTower", x = -100, z = 175, r = 15, scale = 1, turn = 180 },
		{ id = "H3", asset = "CV3_ChocoHouse", x = -10, z = -118, r = 22.4, scale = 1.4, v9 = true }, -- was v8 (-205.4, -195)
		{ id = "H4", asset = "CV3_SweetHouse", x = 178, z = 100, r = 20, scale = 1 },
		{ id = "H5", asset = "CV3_CaramelTower", x = -168, z = -82, r = 21, scale = 1.4, turn = 180 },
		{ id = "H6", asset = "CV3_ChocoHouse", x = 45, z = -125, r = 16, scale = 1, v9 = true }, -- was v8 (195, -221)
		{ id = "H7", asset = "CV3_SweetHouse", x = 110, z = 178, r = 20, scale = 1 },
		{ id = "H8", asset = "CV3_SweetHouse", x = 380, z = -60, r = 20, scale = 1, v9 = true },
		{ id = "H9", asset = "CV3_ChocoHouse", x = 600, z = -200, r = 16, scale = 1, v9 = true },
		{ id = "H10", asset = "CV3_CaramelTower", x = 530, z = 70, r = 15, scale = 1, turn = 180, v9 = true },
	}) do
		if not row.v9 then row.x, row.z = v8(row.x), v8(row.z) end
		row.v9 = nil
		list[i] = row
	end
	V3.HOUSES = freeze(list)
end
-- Placeholder sizes (side of the square, wall height) when a house model is missing, at scale 1.
V3.HOUSE_PLACEHOLDER = freeze({ CV3_SweetHouse = { 24, 14 }, CV3_ChocoHouse = { 22, 14 }, CV3_CaramelTower = { 20, 20 } })

-- V4-D12: the houses are a refuge: no creature enters a footprint (houseFootprints); they are tagged OVERHEAD (a wall,
-- never ground), not PASS. The cake keeps PASS.

-- The raft docks (V4-D1, V4-D3): one on each bank of the lake, the raft's open water between the left route's last
-- bridge and its bottom bridge: stand (on the bank, where a player boards and is set down) and tip (over the chocolate,
-- where the raft waits; at least 6 studs inside it and 6 off every bridge). The rider steers the raft
-- (WildboundCandyRaft); homeDock is where it respawns.
-- V5-D3, V5-D13: A on the west lobe's west bank, B on the big disc's east bank (its ramp keeps 11 studs off the left
-- route's last leg), 70 studs apart across the open lake.
-- CL-D8 (Caramelo v9): four docks, plain local rows, each square to its bank, its tip 10 studs inside its disc (dock
-- C's the harbour lake, the others' their basins), at least 50 apart and 6 off every bridge. A (home) and B on the
-- entrance bank of the west channel, C and D on the cake bank of the east stretch. Rafts call to any dock; homeDock is
-- where it respawns.
V3.DOCKS = freeze({
	{ id = "A", standX = -150, standZ = -187, tipX = -150, tipZ = -210 },
	{ id = "B", standX = 240, standZ = -186, tipX = 240, tipZ = -208 },
	{ id = "C", standX = 670, standZ = 104, tipX = 670, tipZ = 128 },
	{ id = "D", standX = 815, standZ = 124, tipX = 815, tipZ = 148 },
})
-- CL-D8: clearance is the least height a bridge deck's underside must keep over the chocolate's surface for the raft
-- to pass under it (V3.raftBlocks); the kit raft's top with its bob is 6.79.
V3.RAFT = freeze({ asset = "CV3_BananaRaft", homeDock = 1, clearance = 8 })
-- A dock's build (review m5, m6): its deck stops tipGap studs short of the tip (the docked hull's room), its ramp
-- starts rampBack studs behind the stand, deckWidth wide; its top stands deckOver studs over the chocolate's surface.
-- V4-D2: rampBack 5 -> 10, so the ramp up to the deck over the deeper surface stays walkable (under 25 degrees).
V3.DOCK = freeze({ deckWidth = 6, tipGap = 5, rampBack = 10, deckOver = 0.4 })

-- The rainbow licorice arch (CV3_LicoriceArch) over the main path, between the entrance and the fork, its span (the
-- kit's X) across the path. The kit's ribbon meets the ground at four feet, feet = { |x| of the inner pair, of the
-- outer pair } with their footprint radii, at kit scale 1; everything scales by `scale`.
-- V8-D1: the arch, the cake and the point the cake faces scale; their sizes stay.
V3.LICORICE = freeze({ x = v8(-124), z = v8(0), scale = 0.8, height = 27, span = 62.3,
	feet = { { offset = 20.6, r = 5.7 }, { offset = 34.8, r = 4.5 } } })
-- The modular cake (CV3_CakeBase, CV3_CakeTop on its top_tier socket, CV3_CakeRamp at its ramp_front socket), in the
-- open north-west, its front (and ramp) facing (faceX, faceZ). r is the base's footprint, rampReach how far in front
-- of the centre the ramp's low end lies, both at `scale`.
V3.CAKE = freeze({ x = v8(-150), z = v8(112), scale = 0.8, r = 18, rampReach = 38.5, faceX = v8(-150), faceZ = v8(0),
	height = 21.6 })
-- The cookie platforms standing on the lake floor (kit scale 1). V4-D2: each kit cookie is lifted on a pedestal
-- collider so its walk top stands PLATFORM.over studs over the 3.5-deep surface.
-- CL-D3 (Caramelo v9): local literals in the harbour lake (the medium one in its west lobe, disc 2; the rest in disc 1),
-- at least 2 apart, 4 off the island's foot and off every bridge.
V3.PLATFORMS = freeze({
	{ asset = "CV3_CookieM", x = 580, z = 170, r = 6.7 },
	{ asset = "CV3_CookieL", x = 650, z = 180, r = 11.7 },
	{ asset = "CV3_CookieS", x = 700, z = 185, r = 3.9 },
	{ asset = "CV3_CookieS", x = 630, z = 150, r = 3.9 },
})
V3.PLATFORM = freeze({ over = 0.5, pedestalShare = 0.8 })
-- Caramelo v6, proposal 4 (odd/tasks/wildbound-caramelo-v2.md V6-D4; docs/design/wildbound-caramelo-v3-plan.md V6-D60
-- on): an island in the big lake with one Epica egg nest, laid at server start by tools/WildboundCandyIsland.luau.
-- { id, x, z, r, flat, foot }: r is its waterline (inside it is dry land for every rule that reads liquidDistance: the
-- raft, wading, the current, the clearances), flat the radius of its level top, foot where its underwater bank meets
-- the floor. It stands in the river's mouth, north of the cookie platforms: the lake leaves no wider spot with a raft
-- channel all round (V6-D60). No VERSION bump: nothing laid by a migration moves.
-- V8-D1: it moved with the big disc and shrank a little (r 6.5 -> 6, flat 4.5 -> 4, foot 10.4 -> 9.9, the same bank).
-- CL-D3 (Caramelo v9): a local literal in the harbour lake (disc 1), with the raft's channel all round (its foot + 3 at
-- liquid <= -3), its foot at least 15 from every dock tip and 20 from every stand.
V3.ISLANDS = freeze({
	{ id = "I1", x = 690, z = 150, r = 6, flat = 4, foot = 9.9 },
})
-- The island's build: its top `top` studs over the chocolate's surface, a beach from the top's edge down to the
-- waterline and an underwater bank (bankDegrees steep: foot = r + LIQUID.depth / tan(bankDegrees)) down to the floor,
-- in `sectors` slices.
V3.ISLAND = freeze({ top = 1.1, bankDegrees = 42, sectors = 16 })

-- V3-D9 tree rule: every old tree of a kind on the left takes the new kind on the right at the same spot and turn,
-- scaled to the old tree's height (heightFactor), then fitted by the CH clearance rule (WildboundCandyBuilder.treeFits):
-- smaller down to minFactor, or nudged by one of nudges; a tree that still does not fit keeps its old model. The
-- lollipops stay (the avenue of lollipops is a path, not a wood). A cotton tree's Roof disc (La Nube's sky ray) moves
-- into the new tree. V4-D4: heightFactor 1 -> 1.35 (35 % taller; the v4 migration refits the live trees,
-- V3Builder.refitTrees).
V3.TREES = freeze({
	map = { TreeCotton_S = "CV3_TreeCotton", TreeCotton_M = "CV3_TreeCotton", TreeCotton_L = "CV3_TreeCotton",
		TreeCream = "CV3_TreeIceCream", TreeCookie = "CV3_TreeCaramelApple" },
	heightFactor = 1.35, minFactor = 0.7, step = 0.05, nudges = { 2, 4, 6, 8 },
	-- the placeholder's shape, per unit of height: trunk radius and crown radius
	trunk = 0.05, crown = 0.3,
	attribute = "CaramelTreeV3",
})

-- Filler (V3-D11, "the map must not feel empty"): candy props of the old kit (WildboundCandyKit) along both banks of
-- the river and round each house, and small ice-cream hills by the plot edge; seeded (SEED), each on open ground.
V3.FILLER = freeze({
	bankEvery = 22, bankOffset = 7, perHouse = 3, hills = 4, hillScale = 0.2, -- V4-D17: 6 -> 4 (the pink hills, the edge fill)
	assets = { "GumdropBush_A", "GumdropBush_B", "CreamMushroom", "ConfettiPile", "RockChocolate" },
	reach = 4,
})

-- V4-D6: the yellow crystals (the old kit's RockSugar, laid only in the old builder's SugarHills along the east edge)
-- are gone; a pink ice-cream hill (the medium mountain at `scale`, footprint r) stands at each Hill_ spot where it
-- fits (x 198 like the crystals, so it straddles the edge). The Peak_ spots stood outside the plot: the backdrop takes
-- their place. Hill_3 and Hill_5 are smaller (M2, H4 and La Nube's pond stand near them).
V3.CRYSTAL = freeze({ asset = "RockSugar", folder = "SugarHills", hillAsset = "CV3_IceCreamMountain_M", hillHeight = 60.3 })
-- V8-D1: x was re-anchored to the edge (HALF - 2, as the v7 198 was), z scaled.
-- CL-D12 (Caramelo v9): all six re-anchor to the new east edge, x = EAST - 2 (858, straddling it), at new local z
-- literals that keep clear of the river's mouth (z 135..255) and of the boss ground.
do
	local list = {}
	for i, row in ipairs({
		{ id = "Hill_1", z = -247, scale = 0.5, r = 17.75 },
		{ id = "Hill_2", z = -190, scale = 0.45, r = 16 },
		{ id = "Hill_3", z = -125, scale = 0.5, r = 17.75 },
		{ id = "Hill_4", z = -60, scale = 0.45, r = 16 },
		{ id = "Hill_5", z = 60, scale = 0.45, r = 16 },
		{ id = "Hill_6", z = 105, scale = 0.28, r = 9.94 },
	}) do
		list[i] = { id = row.id, x = EAST - 2, z = row.z, scale = row.scale, r = row.r }
	end
	V3.CRYSTAL_HILLS = freeze(list)
end

-- V4-D7, the sides: a seeded fill of the edge band (plot depth bandMin to bandMax, the x > 158 strip outside the boss
-- territory included) every `spacing` studs (jittered), and of the interior where no prop stands within emptyRadius
-- (every interiorSpacing studs): new-kind trees (kit CV3_Tree*, treeHeight tall, V3Kind so the ambience sways and
-- sparkles them, in CaramelV3.Trees with EdgeFill = true), candy props of the old kit, and a few small ice-cream hills,
-- all on open ground (V3Builder.openSpot, off every prop already standing). maxParts is its own budget (V4-D17).
V3.EDGE = freeze({
	bandMin = 4, bandMax = 45, spacing = 13, jitter = 4, interiorSpacing = 26, emptyRadius = 22,
	treeShare = 0.5, hillShare = 0.04, maxTrees = 60, maxProps = 60, maxHills = 4, hillScale = 0.2,
	treeHeight = { 17, 27 }, propReach = 3.5, seedOffset = 4, maxParts = 600,
	trees = { "CV3_TreeCotton", "CV3_TreeIceCream", "CV3_TreeCaramelApple" },
	assets = { "GumdropBush_A", "GumdropBush_B", "CreamMushroom", "ConfettiPile", "RockChocolate" },
})
-- The backdrop (V4-D7): big decor just outside the east edge and its corners (local x > 200), never colliding and never
-- queried (decor only), clear of every neighbouring biome square (WildboundBiomes: nothing east of the Meadow; Caves
-- from world z 237 north, Mountains from world z -243 south). { asset, x, z, scale, r (footprint at that scale) }.
-- V8-D2 (fixer): east of the v8 plot lie the cloud band (local x 260..276) and Caramelo Este, so every one of these
-- pieces, re-anchored to the east edge (HALF + (x - 200)), would stand in the Veil or on the second space's floor. The
-- v8 backdrop is empty: a fresh build matches the live map, where tools/wildbound-caramelo-v8-migrate.luau archives
-- the old backdrop ("would stand east of the plot"). V3.BACKDROP_V7 keeps the v7 rows as a record (nothing lays them).
-- CL-D13 (Caramelo v9): still empty. East of the v9 plot (local x 860) lie the cloud band (860..876) and the arm's
-- 64-stud tail, where the river's MouthSheet runs on under the cloud.
V3.BACKDROP_V7 = freeze({
	{ asset = "CV3_IceCreamMountain_L", x = 236, z = -160, scale = 0.6, r = 32.4 },
	{ asset = "CV3_IceCreamMountain_L", x = 240, z = -40, scale = 0.65, r = 35.1 },
	{ asset = "CV3_IceCreamMountain_L", x = 238, z = 90, scale = 0.6, r = 32.4 },
	{ asset = "CV3_IceCreamMountain_M", x = 222, z = 30, scale = 0.5, r = 17.75 },
	{ asset = "CV3_IceCreamMountain_M", x = 222, z = -95, scale = 0.45, r = 16 },
	{ asset = "CV3_IceCreamMountain_M", x = 226, z = 170, scale = 0.5, r = 17.75 },
	{ asset = "CV3_IceCreamMountain_M", x = 222, z = 222, scale = 0.45, r = 16 },
	{ asset = "CV3_IceCreamMountain_M", x = 222, z = -222, scale = 0.45, r = 16 },
	{ asset = "CV3_TreeCotton", x = 212, z = 130, scale = 1.3, r = 11 },
	{ asset = "CV3_TreeIceCream", x = 214, z = -10, scale = 1.3, r = 12 },
	{ asset = "CV3_TreeCaramelApple", x = 212, z = -125, scale = 1.3, r = 10.3 },
	{ asset = "CV3_TreeCotton", x = 213, z = 60, scale = 1.2, r = 10.1 },
	{ asset = "CV3_TreeIceCream", x = 212, z = -195, scale = 1.2, r = 11 },
	{ asset = "CV3_TreeCaramelApple", x = 212, z = 200, scale = 1.2, r = 9.5 },
})
V3.BACKDROP = freeze({})

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
-- CL-D16 (Caramelo v9, the plot 2.15 times bigger): MAX_NEW_PARTS 1300 -> 1600 and BIOME_PART_CAP 2800 -> 3400.
V3.MAX_NEW_PARTS = 1600
V3.BIOME_PART_CAP = 3400
-- V4-D17: the v4 migration's dry-run estimate must stay at or under this (100 under the cap: room for the house nests
-- and the Duquesa of the other v4 tasks).
V3.V4_PART_TARGET = 2700
-- CL-D16: the v9 migration's real run refuses an estimate above this (saved about 2640 +- 300).
V3.V9_PART_TARGET = 3100

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

-- Signed distance to the nearest island's waterline (V6-D4): negative on an island, math.huge with none.
function V3.islandDistance(x, z)
	local best = math.huge
	for _, island in ipairs(V3.ISLANDS) do best = math.min(best, flat(x, z, island.x, island.z) - island.r) end
	return best
end

-- The island whose waterline holds (x, z) (within `reach` past it), or nil.
function V3.islandAt(x, z, reach)
	for _, island in ipairs(V3.ISLANDS) do
		if flat(x, z, island.x, island.z) <= island.r + (reach or 0) then return island end
	end
	return nil
end

-- CL-D3: studs from the nearest plot edge, inwards (negative outside): the rectangle x -HALF..EAST, z -HALF..HALF, as
-- WildboundCandyLayout.depth.
function V3.plotDepth(x, z)
	return math.min(x + HALF, EAST - x, HALF - math.abs(z))
end

-- Signed distance to the nearest chocolate (river, pool or lake): negative inside. V6-D4: an island is dry land, so
-- the chocolate round it ends at its waterline (the larger of the water's distance and the island's, negated).
-- CL-D3: the plot clip: nothing outside the plot is chocolate (for the raft, wading, the current and every clearance),
-- so the river ends at the east edge and the raft stops with its centre 3 inside it.
function V3.liquidDistance(x, z)
	local best = V3.riverDistance(x, z)
	best = math.min(best, flat(x, z, V3.POOL.x, V3.POOL.z) - V3.POOL.r)
	for _, disc in ipairs(V3.LAKE) do best = math.min(best, flat(x, z, disc.x, disc.z) - disc.r) end
	best = math.max(best, -V3.islandDistance(x, z))
	return math.max(best, -V3.plotDepth(x, z))
end

-- CL-D3: the radius of the round joint the builder lays at RIVER[i]: half the widest of the point and its neighbours
-- (a missing neighbour skipped), so the laid chocolate covers the rule's capsules at every width step.
function V3.jointRadius(i)
	local R = V3.RIVER
	local w = R[i][3]
	if R[i - 1] then w = math.max(w, R[i - 1][3]) end
	if R[i + 1] then w = math.max(w, R[i + 1][3]) end
	return w / 2
end

function V3.riverLength()
	local total = 0
	for i = 1, #V3.RIVER - 1 do
		local a, b = V3.RIVER[i], V3.RIVER[i + 1]
		total += flat(a[1], a[2], b[1], b[2])
	end
	return total
end

-- A point in a bridge's frame: along (studs from the deck's centre along its leg) and across.
function V3.bridgeFrame(B, x, z)
	local dx, dz = x - B.x, z - B.z
	return dx * B.ux + dz * B.uz, -dx * B.uz + dz * B.ux
end

-- The bridge whose deck (deckOnly = true) or deck and end ramps hold (x, z), or nil. V4-D1: over every bridge.
function V3.onBridge(x, z, deckOnly)
	for _, B in ipairs(V3.BRIDGES) do
		local along, across = V3.bridgeFrame(B, x, z)
		if math.abs(across) <= B.width / 2 and math.abs(along) <= B.length / 2 + (deckOnly and 0 or B.ramp) then return B end
	end
	return nil
end

-- The liquid surface height in world studs, for a layout floor top.
function V3.surfaceY(floorTop)
	return floorTop + V3.LIQUID.depth
end

-- (V3.faceYaw and V3.kitPoint are defined before the data, which places M1's water with them.)

-- The house footprints for the creatures (V4-D12): { { id, x, z, r } } plot-local, r at the house's scale. L (the
-- base layout) is accepted for symmetry with the other helpers and is not needed.
function V3.houseFootprints(_L)
	local out = {}
	for _, h in ipairs(V3.HOUSES) do table.insert(out, { id = h.id, x = h.x, z = h.z, r = h.r }) end
	return out
end

-- A house's yaw (radians about +Y): its front (-Z) towards the junction, plus its turn (V4-D15).
function V3.houseYaw(h, L)
	return V3.faceYaw(h.x, h.z, L.JUNCTION.x, L.JUNCTION.z) + math.rad(h.turn or 0)
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
	-- V6-D4: the island is dry but belongs to its nest and decor, never to the fill
	local island = V3.islandAt(x, z, r + margin)
	if island then return false, "on island " .. island.id end
	for _, p in ipairs(V3.pieces()) do
		if flat(x, z, p.x, p.z) < p.r + r + margin then return false, "on " .. p.kind .. " " .. p.id end
	end
	if V3.nearBridge(x, z, r + margin) then return false, "on the bridge" end
	return true
end

-- Whether something of the given reach at (x, z) touches a bridge: its deck, end ramps or side ramps (review m7; a
-- bridge without gaps has no side ramps). V4-D1: over every bridge.
function V3.nearBridge(x, z, reach)
	reach = reach or 0
	for _, B in ipairs(V3.BRIDGES) do
		local along, across = V3.bridgeFrame(B, x, z)
		local side = #B.gaps > 0 and B.sideRamp or 0
		if math.abs(across) <= B.width / 2 + side + reach and math.abs(along) <= B.length / 2 + B.ramp + reach then return true end
	end
	return false
end

-- CL-D8: whether a raft hull of the given reach at (x, z) runs into a bridge too low to pass under: one whose deck
-- underside (deck - 0.4 - LIQUID.depth) stands under RAFT.clearance over the chocolate; its footprint is a wall then, as
-- in V3.nearBridge. The raised v9 bridges are all high enough, so with V3.BRIDGES it is always false. `bridges` (a list
-- of bridge rows, default V3.BRIDGES) lets a test try a low one. WildboundCandyRaft's area reads it.
function V3.raftBlocks(x, z, reach, bridges)
	reach = reach or 0
	for _, B in ipairs(bridges or V3.BRIDGES) do
		if B.deck - 0.4 - V3.LIQUID.depth < V3.RAFT.clearance then
			local along, across = V3.bridgeFrame(B, x, z)
			local side = #B.gaps > 0 and B.sideRamp or 0
			if math.abs(across) <= B.width / 2 + side + reach and math.abs(along) <= B.length / 2 + B.ramp + reach then return true end
		end
	end
	return false
end

-- A bridge's footprint corners (deck, end ramps and side ramps), plot coordinates: four { x, z }.
function V3.bridgeCorners(B)
	local a = B.length / 2 + B.ramp
	local c = B.width / 2 + (#B.gaps > 0 and B.sideRamp or 0)
	local out = {}
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		table.insert(out, { x = B.x + s[1] * a * B.ux - s[2] * c * B.uz, z = B.z + s[1] * a * B.uz + s[2] * c * B.ux })
	end
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
