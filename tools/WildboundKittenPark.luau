-- Pueblo Gatito, the kitten park in Caramelo Este (owner request 2026-11-17: "es como el mundo de gatito: un parque verde
-- lindo con las criaturas gatitas, juguetes como rollos de papel, hisopos, papel, bolsas, tiendas de gatitos como que es
-- su village, otra canción que tenga que ver más con gatitos, también tiene que haber huevos para robar";
-- docs/design/wildbound-kitten-park-plan.md, K-D1 to K-D21). Deployed as ServerStorage.WildboundKittenPark.
-- Moved (owner request 2026-11-18 "Sí, movelo"; docs/design/wildbound-pueblo-gatito-move-plan.md PGM-D1, PGM-D2, PGM-D4):
-- the park now stands on the big4 south arm in its own root Workspace.PuebloGatito_v1, and every park position is
-- park-local, turned to world by ReplicatedStorage.WildboundGatitoArea (world(lx, lz) = (282 - lz, 600 + lx)); the K-D
-- world literals below are the old frame's (Area.V1, centre (1208, -3)) and are converted through Area.localOfV1.
-- Grown to 600 x 1200 (owner requests 2026-11-18 "hacelos mas largos aun" and 2026-11-19 "hace el mapa bastante mas
-- largo"; docs/design/wildbound-pueblo-gatito-long-plan.md GL-D1..GL-D17): the park runs from the gate (local x -260)
-- to the far end (local x 860); the K-D half (local x -260..260) keeps every item where it was except the far-end goal
-- (TowerPlaza, the Torre Gato Vigía and its four lit lanterns, +600, GL-D9); the new half is the Jardín de Ovillos
-- (GARDEN, its own generator GARDEN_SEED, GL-D6..GL-D8); 16 nests (GL-D10), a second portal disc (GL-D13).
-- Pure plan and recipes, plus the builders that lay them into Workspace.PuebloGatito_v1:
--   plan(L, East, o)  every path, item and nest of the park in world studs (K-D16, Appendix A, GL-D7, GL-D8), with the
--                     drop rules applied and the part budget per folder (K-D18 + GARDEN_BUDGET); the frame is Area's
--                     (PGM-D4), L and East unused; o.garden == false leaves the garden out (a suite-only switch);
--   buildGround(root) the park's own ground: root.Ground.Floor, the whole arm 600 x 1200 in green Grass (TB-1: with the
--                     toolbox grass MaterialVariant "WildboundGatitoGrass"), and
--                     root.Ground.Approach, the slab from the big4 road's end to the arm (PGM-D2, GL-D3);
--   recipe(kind, v)   one item as plain parts, local to its pivot (its ground centre, front toward -Z): primitive Parts
--                     and Sphere SpecialMeshes only, no upload of any kind (K-D12, K-D21); signs are a SurfaceGui with a
--                     TextLabel (K-D16);
--   build(root)       lays root.Park (idempotent: conforms or creates, never removes);
--   edgePlan()        the edge: three invisible solid walls and 100 hedge puffs along the arm's outer sides (GL-D4, GL-D5);
--   buildEdge(root)   lays root.Edge.Walls and root.Edge.Hedge (idempotent: conforms or creates, never removes);
--   strays(root, L, East) the pieces of root.Park that the plan does not keep where they stand (for the grow tool's archive);
--   syncNests(root)   the sixteen park nests root.Nests.Nest_K1..K16 and their marker contract (K-D8, GL-D10), run at
--                     every server start by WildboundCandyNests.applyFlags (K-D9);
--   archiveAnnex      the big4 annex props that v8 moved into the space go to an archive folder (K-D17);
--   clearGate         the plot's colliding pieces in the gate corridor go to an archive folder (K-D2).
--   (archiveAnnex, clearGate and GATE_CORRIDOR work in the old frame east of Caramelo: obsolete for the move, kept, PGM-D8.)
-- Roles follow WildboundCandyBuilder: floor and solid parts collide and answer queries, decor parts do neither; no part
-- is ever touched (CanTouch false). Anything named SistemaSonriente, or under it, is refused (K-D20).
-- tools/wildbound-kitten-park-build.luau ran it once on the live map, tools/wildbound-pueblo-gatito-move.luau moved it
-- (PGM-D7), tools/wildbound-pueblo-gatito-grow.luau grows it (GL-D14); WildboundKittenPark_Test holds the rules.
local CollectionService = game:GetService("CollectionService")
local Area = require(game:GetService("ReplicatedStorage"):WaitForChild("WildboundGatitoArea"))

local Park = {}

local freeze = table.freeze

Park.VERSION = 2 -- 1: the K-D park; 2: grown to 600 x 1200 (GL-D14)
Park.ROOT_NAME = Area.ROOT_NAME -- PGM-D2: the park's own root, "PuebloGatito_v1" (was "Candy_Este_v1")
Park.FOLDER = "Park"
Park.NESTS_FOLDER = "Nests"
Park.GROUND_FOLDER = "Ground" -- PGM-D2: root.Ground.Floor, the park's own floor (GL-D3: and root.Ground.Approach)
-- GL-D3: the floor covers the whole arm (Area.ARM, 600 x 1200 centred at (297, 937); was the 2 * HALF square at the
-- origin) in the K-D15 park grass; the size is in world axes (buildGround lays it with no turn)
-- TB-1 (owner request 2026-11-20 "el pasto del mundo gatito tambien" from the toolbox): the floor and the Approach wear
-- the MaterialVariant "WildboundGatitoGrass" (MaterialService, BaseMaterial Grass: the Creator Store "Stylized Grass
-- Material" 11314842253, ColorMap 11314835829, NormalMap 11314836132, StudsPerTile 10); the Part colour tints its
-- colour map, so it is a lighter green (was K-D15's { 140, 201, 107 }). Without the variant in MaterialService the
-- part falls back to plain Grass in that colour.
local ARM = Area.ARM
Park.GRASS_VARIANT = "WildboundGatitoGrass"
Park.FLOOR = freeze({ size = freeze({ ARM.maxX - ARM.minX, 1, ARM.maxZ - ARM.minZ }),
	centre = freeze({ x = (ARM.minX + ARM.maxX) / 2, z = (ARM.minZ + ARM.maxZ) / 2 }), color = freeze({ 170, 224, 128 }),
	material = "Grass", variant = Park.GRASS_VARIANT })
-- GL-D3: the Approach, the floor slab from the big4 road's end (z 324.5) to the arm's gate side (z 337), world studs
Park.APPROACH = freeze({ minX = 272, maxX = 292, minZ = 324, maxZ = 337 })
-- GL-D4: the edge (root.Edge, outside Ground on purpose: the resting service and the summon rays include Ground, and an
-- 80-tall wall top would read as ground): walls `wall` thick and `height` tall along the arm's long sides from z
-- wallFromZ, and across its far end
Park.EDGE = freeze({ folder = "Edge", wall = 4, height = 80, wallFromZ = 937 })
Park.EDGE_PARTS = 203 -- GL-D5: 3 walls + 100 hedge puffs x 2
Park.FORBIDDEN = "SistemaSonriente"
Park.SEED = 8128
-- GL-D6: the Jardín de Ovillos draws every seeded yaw and jitter from its own generator, so the K-D half never moves
Park.GARDEN_SEED = Park.SEED + Area.GROWTH -- 8728
Park.NEST_TAG = "WildboundCandyNestCandidate" -- the tag every candy nest marker carries (WildboundCandyIsland.NEST_TAG)
Park.FLOOR_TOP = Area.FLOOR_TOP -- 0.5 (Layout.FLOOR_TOP); used by syncNests when the root has no Ground.Floor
-- K-D16 drop rules: a scatter or decor item is dropped within NEST of a nest, post or chest (its REACH added), within
-- PORTAL of the return portal, inside the arrival disc, or within PATH plus half the width of a path's centre line
-- (path pieces, the gate, the chests and the lanterns are placed on purpose and never dropped by the path rule).
Park.CLEAR = freeze({ nest = 8, portal = 12, path = 6 })
-- How far an item's ground footprint reaches past its pivot, for the nest rule only: a flat ground patch (30 x 20) would
-- otherwise lie under a nest's rarity ring and flicker against it.
Park.REACH = freeze({ patch = 10 })
-- K-D2: the plot side of the gate (world), where clearGate archives colliding pieces of Candy_Bioma_v1 (old frame; PGM-D8).
Park.GATE_CORRIDOR = freeze({ minX = 896, maxX = 932, minZ = -17, maxZ = 11 })
-- K-D18: BaseParts per folder of root.Park (PuebloGatito_v1.Park since PGM-D2) before the drop rules (they only lower
-- it), and the caps.
Park.FOLDERS = freeze({ "Paths", "Gate", "Village", "ToyPark", "Toys", "Chests", "Trees", "Lanterns", "Scatter" })
Park.BUDGET = freeze({ Paths = 254, Gate = 8, Village = 310, ToyPark = 98, Toys = 160, Chests = 88, Trees = 208,
	Lanterns = 130, Scatter = 136 })
-- GL-D8: the Jardín de Ovillos' BaseParts per folder before the drop rules (which should drop none of it), 1211 in all;
-- its Chests are Chest_K9..K16
Park.GARDEN_BUDGET = freeze({ Paths = 288, Gate = 0, Village = 93, ToyPark = 119, Toys = 188, Chests = 88, Trees = 196,
	Lanterns = 105, Scatter = 134 })
Park.PART_CAP = 2800 -- GL-D15: the park folder (2589 planned; was 1400)
Park.NEST_PARTS = 2 -- Collision_Bowl and RarityRing (K-D8)
-- K-D16: the sign strings, Latin text only (no CJK, so no font risk).
Park.SIGNS = freeze({ "Pueblo Gatito", "Café Cat", "Paws & Coffee", "Panadería Gatuna", "=^.^=", "Takoyaki", "Taiyaki",
	"Mochi" })

-- PGM-D4: a K-D world literal (the old frame, Area.V1) in the park frame: its world x, z now (what every consumer
-- compares) and its park-local lx, lz. Exact: the frame turns by a multiple of 90.
local function moved(x, z)
	local lx, lz = Area.localOfV1(x, z)
	local wx, wz = Area.world(lx, lz)
	return wx, wz, lx, lz
end
local function nest(id, rarity, x, z, key, px, pz, guard, cx, cz)
	local nx, nz, nlx, nlz = moved(x, z)
	local postX, postZ, postLx, postLz = moved(px, pz)
	local chestX, chestZ, chestLx, chestLz = moved(cx, cz)
	return freeze({ id = id, rarity = rarity, x = nx, z = nz, lx = nlx, lz = nlz,
		post = freeze({ key = key, x = postX, z = postZ, lx = postLx, lz = postLz }), guard = guard,
		chest = freeze({ x = chestX, z = chestZ, lx = chestLx, lz = chestLz }) })
end
-- GL-D10: a garden nest written park-local (lx, lz) and turned to world by the frame; the post key is "kittenPost" .. id.
local function parkNest(id, rarity, lx, lz, plx, plz, guard, clx, clz)
	local nx, nz = Area.world(lx, lz)
	local postX, postZ = Area.world(plx, plz)
	local chestX, chestZ = Area.world(clx, clz)
	return freeze({ id = id, rarity = rarity, x = nx, z = nz, lx = lx, lz = lz,
		post = freeze({ key = "kittenPost" .. id, x = postX, z = postZ, lx = plx, lz = plz }), guard = guard,
		chest = freeze({ x = chestX, z = chestZ, lx = clx, lz = clz }) })
end
-- K-D7/K-D8: the park nests (K1..K8 written as the K-D world studs of the old frame; PGM-D4 turns them into the park
-- frame, K1 at (337, 430) ... K8 at (162, 750); K9..K16 park-local, GL-D10, K9 at (204, 900) ... K16 at (357, 1330)).
-- Each post stands 12 studs from its nest toward the route; the chest stands 7 studs on the far side, its open lid
-- toward the nest. Rarity grows with the depth from the gate (GL-D10): 5 Comun (K1..K5, local x -170..20), 6 Rara
-- (K6..K11, local x 35..420), 5 Epica (K12..K16, local x 470..730, all in the garden), no Legendaria (event-only, as in
-- the plot). The guard is the kitten's name for a HOME post and "<name>@<post key>" for an east extra post
-- (WildboundPraderaSites.EAST_FIXED / EAST_EXTRA_POSTS).
Park.NESTS = freeze({
	nest("K1", "Comun", 1038, -58, "kittenPostK1", 1038, -46, "GatitoGuerrero", 1038, -65),
	nest("K2", "Comun", 1043, 92, "kittenPostK2", 1043, 104, "GatitaBouquet", 1043, 85),
	nest("K3", "Comun", 1143, -65, "kittenPostK3", 1143, -53, "GatitoActually", 1143, -72),
	nest("K4", "Comun", 1158, 67, "kittenPostK4", 1158, 55, "GatitoLanudo", 1158, 74), -- GL-D10: was Rara
	nest("K5", "Comun", 1228, -73, "kittenPostK5", 1228, -61, "GatitoGuerrero@kittenPostK5", 1228, -80), -- GL-D10: was Rara
	nest("K6", "Rara", 1243, 72, "kittenPostK6", 1243, 60, "GatitaBouquet@kittenPostK6", 1243, 79),
	nest("K7", "Rara", 1358, -123, "kittenPostK7", 1358, -111, "GatitoActually@kittenPostK7", 1358, -130), -- GL-D10: was Epica
	nest("K8", "Rara", 1358, 117, "kittenPostK8", 1358, 105, "GatitoLanudo@kittenPostK8", 1358, 124), -- GL-D10: was Epica
	parkNest("K9", "Rara", 300, 78, 300, 66, "GatitoGuerrero@kittenPostK9", 300, 85),
	parkNest("K10", "Rara", 360, -80, 360, -68, "GatitaBouquet@kittenPostK10", 360, -87),
	parkNest("K11", "Rara", 420, 90, 420, 78, "GatitoActually@kittenPostK11", 420, 97),
	parkNest("K12", "Epica", 470, -95, 470, -83, "GatitoLanudo@kittenPostK12", 470, -102),
	parkNest("K13", "Epica", 560, 85, 560, 73, "GatitoGuerrero@kittenPostK13", 560, 92),
	parkNest("K14", "Epica", 600, -80, 600, -68, "GatitaBouquet@kittenPostK14", 600, -87),
	parkNest("K15", "Epica", 680, 80, 680, 68, "GatitoActually@kittenPostK15", 680, 87),
	parkNest("K16", "Epica", 730, -75, 730, -63, "GatitoLanudo@kittenPostK16", 730, -82),
})
-- GL-D15: the whole root's cap: the park folder, the edge, the Floor and the Approach, the nests (3037)
Park.ROOT_CAP = Park.PART_CAP + Park.EDGE_PARTS + 2 + #Park.NESTS * Park.NEST_PARTS
-- K-D3: the return portal station "parque" (built by WildboundPortalService at server start) and its clear disc.
-- PGM-D4: K-D (980, 40) is local (-228, 43), world (239, 372).
local portalX, portalZ, portalLx, portalLz = moved(980, 40)
Park.PORTAL = freeze({ x = portalX, z = portalZ, lx = portalLx, lz = portalLz })
-- GL-D13: the second portal station "parque2" (WildboundPortal.STATIONS, built by the service) at the far end, local
-- (775, 55), world (227, 1375); the drop rule clears the same 12-stud disc round it.
local portal2X, portal2Z = Area.world(775, 55)
Park.PORTAL2 = freeze({ x = portal2X, z = portal2Z, lx = 775, lz = 55 })
-- K-D16: where a player lands through the gate; only the gate arch and the paths stand in this disc.
-- PGM-D4: K-D (964, -3) is local (-244, 0), world (282, 356).
local arrivalX, arrivalZ, arrivalLx, arrivalLz = moved(964, -3)
Park.ARRIVAL = freeze({ x = arrivalX, z = arrivalZ, lx = arrivalLx, lz = arrivalLz, r = 30 })
-- K-D8: ring colours by rarity (WildboundCandyBuilder: Comun mint, Rara confetti, Epica grape) and the cat basket.
Park.RING_COLORS = freeze({ Comun = freeze({ 88, 214, 220 }), Rara = freeze({ 251, 225, 94 }), Epica = freeze({ 117, 64, 121 }) })
Park.BOWL = freeze({ size = freeze({ 2.2, 6, 6 }), color = freeze({ 205, 150, 105 }), material = "Wood" })
Park.RING = freeze({ size = freeze({ 0.08, 8, 8 }) })

-- Appendix A, park-local (lx, lz): world = Area.world(lx, lz) (PGM-D4; it was (1208 + lx, -3 + lz), north +z, before the
-- move); local +x runs from the gate to the far end.
local LOCAL = {
	paths = {
		-- the main path M, 12 wide: sand strips, joint discs at the bends, slabs every 5 alternating +-2.5 across
		{ id = "M", width = 12, main = true,
			points = { { -252, 0 }, { -200, 0 }, { -160, 6 }, { -120, 0 }, { -60, -8 }, { 0, 0 }, { 60, 10 }, { 120, 0 }, { 190, 0 } } },
		-- the forks, 8 wide, stepping stones every 7 with +-1 jitter
		{ id = "S", width = 8, points = { { -120, 0 }, { -112, -55 }, { -100, -105 } } },
		{ id = "V", width = 8, points = { { -195, -120 }, { -100, -110 }, { -20, -130 }, { 45, -125 } } },
		{ id = "VL", width = 8, points = { { 45, -125 }, { 95, -60 }, { 120, 0 } } },
		{ id = "N", width = 8, points = { { -120, 0 }, { -112, 55 }, { -100, 105 } } },
		{ id = "T", width = 8, points = { { -200, 150 }, { -100, 110 }, { -20, 140 }, { 45, 130 } } },
		{ id = "TL", width = 8, points = { { 45, 130 }, { 95, 60 }, { 120, 0 } } },
	},
	junctions = {
		{ id = "PlazaCentral", x = -120, z = 0, d = 30 },
		{ id = "VillageSquare", x = -100, z = -110, d = 26 },
		{ id = "ToyPlaza", x = -100, z = 110, d = 26 },
		{ id = "EastJunction", x = 120, z = 0, d = 24 },
		-- GL-D9: the far-end goal moved +600 (was (215, 0)); PuertaJardin (GARDEN) covers the seam where it stood
		{ id = "TowerPlaza", x = 815, z = 0, d = 50 },
	},
	arch = { x = -254, z = 0 },
	-- local yaw 0: the front faces local -z; 180 local +z; 90 local -x (plan turns them by Area.worldYaw, PGM-D4)
	buildings = {
		{ id = "CafeCat", kind = "cafe", folder = "Village", x = -170, z = -150, yaw = 180 },
		{ id = "PanaderiaGatuna", kind = "bakery", folder = "Village", x = -130, z = -82, yaw = 0 },
		{ id = "CasaGatoAlfarero", kind = "potter", folder = "Village", x = -60, z = -150, yaw = 180 },
		{ id = "TiendaGloboPez", kind = "fishshop", folder = "Village", x = -30, z = -95, yaw = 0 },
		{ id = "TakoyakiGatuno", kind = "takoyaki", folder = "Village", x = 15, z = -160, yaw = 180 },
		{ id = "TaiyakiMochi", kind = "taiyaki", folder = "Village", x = 40, z = -95, yaw = 0 },
		{ id = "CastilloCarton", kind = "castle", folder = "Village", x = -190, z = -175, yaw = 180 },
		{ id = "TorreGatoVigia", kind = "tower", folder = "Village", x = 820, z = 0, yaw = 90 }, -- GL-D9: was (220, 0)
		{ id = "CastilloRascador", kind = "scratchCastle", folder = "ToyPark", x = -160, z = 175, yaw = 0 },
		{ id = "ArbolRascador", kind = "scratchTree", folder = "ToyPark", x = -60, z = 175, yaw = 0 },
		{ id = "TorreDeCajas", kind = "boxTower", folder = "ToyPark", x = -110, z = 160, yaw = 0 },
	},
	-- toys: { id, kind, x, z, yaw (nil: seeded), variant }
	toys = {
		{ "Yarn_Rainbow", "yarn", 95, 160, nil, "rainbow" }, { "Yarn_Sky", "yarn", 155, 75, nil, "sky" },
		{ "Yarn_Pink", "yarn", 180, 175, nil, "pink" }, { "Yarn_Cream", "yarn", 150, -85, nil, "cream" },
		{ "Yarn_Orange", "yarn", 105, -190, nil, "orange" }, { "Yarn_Lime", "yarn", 195, -160, nil, "lime" },
		{ "Yarn_Purple", "yarn", 210, 75, nil, "purple" },
		{ "YarnSmall_1", "yarnSmall", -140, 198, nil, "pink" }, { "YarnSmall_2", "yarnSmall", -40, 215, nil, "sky" },
		{ "YarnSmall_3", "yarnSmall", -95, 190, nil, "lime" }, { "YarnSmall_4", "yarnSmall", 85, -125, nil, "orange" },
		{ "YarnSmall_5", "yarnSmall", 125, 140, nil, "cream" }, { "YarnSmall_6", "yarnSmall", 180, -30, nil, "purple" },
		{ "YarnSmall_7", "yarnSmall", 230, -80, nil, "rainbow" },
		{ "ToiletRoll", "rollStand", -15, 185, nil }, { "ToiletRollLying", "rollLying", 30, 195, 0 },
		{ "KitchenRoll", "kitchen", -5, 205, nil }, { "TubeTunnel", "tunnel", 20, 215, 0 },
		{ "Tube_1", "tube", 35, 170, nil }, { "Tube_2", "tube", -30, 195, nil }, { "TubeBundle", "bundle", -25, 165, 0 },
		{ "SwabBench_1", "swab", -118, 128, 0, "pink" }, { "SwabBench_2", "swab", -82, 92, 0, "blue" },
		{ "SwabBench_3", "swab", -82, -100, 0, "mint" }, { "SwabCup", "swabCup", -90, 148, 0 },
		{ "SwabCross", "swabCross", 55, 170, nil },
		{ "PaperBall_1", "paperBall", -140, 140, nil }, { "PaperBall_2", "paperBall", -35, 150, nil },
		{ "PaperBall_3", "paperBall", 70, 145, nil }, { "PaperBall_4", "paperBall", -175, 215, nil },
		{ "PaperBall_5", "paperBall", -75, 215, nil }, { "PaperBall_6", "paperBall", 165, -20, nil },
		{ "PaperSheet", "sheet", -150, 235, nil }, { "PaperTent", "tent", -5, 232, nil },
		{ "NotebookSheet", "notebook", -205, 235, nil },
		{ "PaperBag_1", "paperBag", -8, -146, 180 }, { "PaperBag_2", "paperBag", -150, -95, 0 },
		{ "PlasticBag_1", "plasticBag", -5, -100, nil, "blue" }, { "PlasticBag_2", "plasticBag", -200, -100, nil, "pink" },
		{ "GiantBag", "giantBag", -190, 190, -45 },
	},
	treesL = { { -235, 45 }, { -235, -50 }, { -150, 40 }, { -150, -45 }, { 20, 40 }, { 25, -45 }, { -100, -155 }, { 15, -90 },
		{ -125, 222 }, { 105, 100 }, { 130, 40 }, { 165, 115 }, { 205, 200 }, { 60, 190 }, { 105, -110 }, { 175, -60 },
		{ 130, -220 }, { 80, -150 } },
	treesS = { { -215, 85 }, { -215, -90 }, { -75, 35 }, { -80, -40 }, { 60, 60 }, { 65, -60 }, { -205, -140 }, { -85, -75 },
		{ -15, -170 }, { -60, 225 }, { 45, 225 }, { 135, 120 }, { 195, 140 }, { 120, 205 }, { 230, 150 }, { 125, -45 },
		{ 200, -110 }, { 215, -205 }, { 235, -120 } },
	bushes = { { -222, 32 }, { -222, -36 }, { -140, -60 }, { -150, 60 }, { -40, -75 }, { 55, -75 }, { -215, -160 }, { -185, 120 },
		{ -25, 110 }, { 75, 30 }, { 240, 40 }, { 85, -25 } },
	lanternsTall = { { -205, 9 }, { -150, -10 }, { -90, 9 }, { -30, -13 }, { 30, 14 }, { 90, -4 }, { 150, 9 }, { 180, -9 } },
	-- { x, z, lit }: the four on the Tower Plaza carry a light (K-D18: 8 tall + 4 = 12 PointLights; GL-D8: with the
	-- garden's 7 tall ones, 19); GL-D9: they moved +600 with the plaza (were at local x 195 and 235)
	lanternsShort = { { -180, -108 }, { -140, -125 }, { -60, -110 }, { -20, -140 }, { 20, -117 }, { 45, -135 },
		{ -160, 143 }, { -60, 135 }, { 0, 128 }, { 40, 140 },
		{ -132, 12 }, { -132, -12 }, { -108, 12 }, { -108, -12 },
		{ 795, 20, true }, { 795, -20, true }, { 835, 20, true }, { 835, -20, true } },
	patches = { { -230, 120 }, { -230, -130 }, { -165, 95 }, { -60, 70 }, { -60, -60 }, { 0, -215 }, { -140, -220 }, { -120, 240 },
		{ 30, 90 }, { 80, 40 }, { 150, 30 }, { 200, 130 }, { 100, 230 }, { 200, -60 }, { 160, -200 }, { 60, -230 } },
	flowers = { { -212, 20 }, { -212, -22 }, { -185, 18 }, { -190, -22 }, { -140, 25 }, { -95, -22 }, { -70, 15 }, { -20, 22 },
		{ -10, -25 }, { 45, 28 }, { 95, -15 }, { 150, -18 }, { 160, 22 }, { -170, -100 }, { -115, -135 }, { -45, -100 },
		{ 5, -112 }, { -175, 125 }, { -130, 95 }, { -40, 120 }, { 20, 150 }, { -120, 190 }, { 110, 170 }, { 130, -170 } },
	tufts = { { -205, 40 }, { -205, -45 }, { -175, -40 }, { -165, 30 }, { -100, 30 }, { -100, -35 }, { -50, 25 }, { -30, -30 },
		{ 5, 30 }, { 35, -30 }, { 68, -25 }, { 105, 25 }, { 175, 25 }, { 175, -25 }, { -150, -130 }, { -75, -135 },
		{ 25, -140 }, { -185, 160 }, { -70, 150 }, { -5, 160 }, { 75, 120 }, { 200, 170 }, { 120, -140 }, { 190, -200 } },
}

-- GL-D7, GL-D8: the Jardín de Ovillos, the new half (local x 260..860), park-local like LOCAL and with its row shapes.
-- plan() lays it after LOCAL in every category and draws its seeded yaws and jitters from Random.new(GARDEN_SEED), so
-- no K-D item moves (GL-D6). Existing recipes only and no sign-bearing kinds; every row keeps the drop rules' distances.
local GARDEN = {
	paths = {
		-- M2, the main path's continuation from M's end (190, 0) to the far plaza (800, 0), 12 wide: 8 strips, 7 joints,
		-- 123 slabs; a second path, so M and every K-D draw stay as they were
		{ id = "M2", width = 12, main = true,
			points = { { 190, 0 }, { 260, 0 }, { 330, -10 }, { 410, 4 }, { 490, -8 }, { 570, 6 }, { 650, -6 }, { 730, 4 }, { 800, 0 } } },
		-- the garden's forks, 8 wide: from the PlazaOvillos to the two side gardens, and the two long walks
		{ id = "GN", width = 8, points = { { 490, -8 }, { 500, 55 }, { 520, 120 } } },
		{ id = "GS", width = 8, points = { { 490, -8 }, { 500, -65 }, { 520, -125 } } },
		{ id = "GT", width = 8, points = { { 320, 140 }, { 420, 128 }, { 520, 120 }, { 620, 130 }, { 700, 110 } } },
		{ id = "GV", width = 8, points = { { 320, -140 }, { 420, -128 }, { 520, -125 }, { 620, -135 }, { 700, -115 } } },
	},
	junctions = {
		{ id = "PuertaJardin", x = 190, z = 0, d = 24 }, -- the M/M2 seam, where TowerPlaza was
		{ id = "PlazaOvillos", x = 490, z = -8, d = 30 }, -- the garden's centre plaza, on M2's bend
		{ id = "JardinNorte", x = 520, z = 120, d = 26 },
		{ id = "JardinSur", x = 520, z = -125, d = 26 },
	},
	-- local yaw 0: the front faces local -z; 180 local +z
	buildings = {
		{ id = "CasaOvillera", kind = "potter", folder = "Village", x = 380, z = -195, yaw = 180 },
		{ id = "CastilloDeOvillos", kind = "castle", folder = "Village", x = 690, z = 195, yaw = 0 },
		{ id = "ArbolRascadorJardin", kind = "scratchTree", folder = "ToyPark", x = 430, z = 195, yaw = 0 },
		{ id = "TorreDeCajasJardin", kind = "boxTower", folder = "ToyPark", x = 560, z = 190, yaw = 0 },
		{ id = "CastilloRascadorJardin", kind = "scratchCastle", folder = "ToyPark", x = 600, z = -195, yaw = 180 },
		{ id = "TorreDeCajasMirador", kind = "boxTower", folder = "ToyPark", x = 745, z = -185, yaw = 180 },
	},
	-- toys: { id, kind, x, z, yaw (nil: seeded by the garden's generator), variant }; ten giant yarns ring the plaza and
	-- the side gardens, the rolls, tubes and bags make two toy piles by JardinNorte and JardinSur
	toys = {
		{ "Yarn_G1", "yarn", 455, 40, nil, "rainbow" }, { "Yarn_G2", "yarn", 530, -45, nil, "sky" },
		{ "Yarn_G3", "yarn", 455, -50, nil, "pink" }, { "Yarn_G4", "yarn", 530, 45, nil, "cream" },
		{ "Yarn_G5", "yarn", 360, 175, nil, "orange" }, { "Yarn_G6", "yarn", 640, 180, nil, "lime" },
		{ "Yarn_G7", "yarn", 650, -185, nil, "purple" }, { "Yarn_G8", "yarn", 300, -195, nil, "rainbow" },
		{ "Yarn_G9", "yarn", 775, 140, nil, "sky" }, { "Yarn_G10", "yarn", 790, -120, nil, "pink" },
		{ "YarnSmall_G1", "yarnSmall", 470, 55, nil, "pink" }, { "YarnSmall_G2", "yarnSmall", 440, 30, nil, "sky" },
		{ "YarnSmall_G3", "yarnSmall", 545, -30, nil, "lime" }, { "YarnSmall_G4", "yarnSmall", 440, -35, nil, "orange" },
		{ "YarnSmall_G5", "yarnSmall", 550, 60, nil, "cream" }, { "YarnSmall_G6", "yarnSmall", 520, -60, nil, "purple" },
		{ "YarnSmall_G7", "yarnSmall", 380, 190, nil, "rainbow" }, { "YarnSmall_G8", "yarnSmall", 620, 175, nil, "pink" },
		{ "YarnSmall_G9", "yarnSmall", 670, -170, nil, "sky" }, { "YarnSmall_G10", "yarnSmall", 320, -180, nil, "lime" },
		{ "YarnSmall_G11", "yarnSmall", 760, 120, nil, "orange" }, { "YarnSmall_G12", "yarnSmall", 770, -100, nil, "cream" },
		{ "YarnSmall_G13", "yarnSmall", 600, 30, nil, "purple" }, { "YarnSmall_G14", "yarnSmall", 390, -30, nil, "rainbow" },
		{ "ToiletRoll_G", "rollStand", 470, 165, nil }, { "RollStand_G2", "rollStand", 545, -165, nil },
		{ "ToiletRollLying_G", "rollLying", 500, 175, 0 }, { "KitchenRoll_G", "kitchen", 465, 180, nil },
		{ "TubeTunnel_G1", "tunnel", 530, 220, 0 }, { "TubeTunnel_G2", "tunnel", 500, -200, 0 },
		{ "Tube_G1", "tube", 545, 160, nil }, { "Tube_G2", "tube", 455, 205, nil }, { "Tube_G3", "tube", 455, -170, nil },
		{ "TubeBundle_G1", "bundle", 585, 225, 0 }, { "TubeBundle_G2", "bundle", 455, -215, 0 },
		{ "SwabBench_G1", "swab", 480, -150, 0, "mint" }, { "SwabBench_G2", "swab", 480, 150, 0, "pink" },
		{ "SwabBench_G3", "swab", 640, -60, 0, "blue" }, { "SwabCup_G", "swabCup", 575, -230, 0 },
		{ "PaperBall_G1", "paperBall", 510, 200, nil }, { "PaperBall_G2", "paperBall", 590, 155, nil },
		{ "PaperBall_G3", "paperBall", 470, -185, nil }, { "PaperBall_G4", "paperBall", 560, -160, nil },
		{ "PaperBall_G5", "paperBall", 720, 40, nil }, { "PaperBall_G6", "paperBall", 350, 30, nil },
		{ "PaperBag_G", "paperBag", 720, 160, 0 }, { "GiantBag_G", "giantBag", 420, -230, 45 },
	},
	treesL = { { 280, 110 }, { 285, -110 }, { 330, 230 }, { 340, -235 }, { 400, 60 }, { 410, -75 }, { 480, 245 }, { 470, -245 },
		{ 610, 100 }, { 630, -100 }, { 650, 235 }, { 700, -240 }, { 760, 200 }, { 800, -170 }, { 840, 120 }, { 845, -95 } },
	treesS = { { 300, 30 }, { 310, -40 }, { 370, 105 }, { 385, -105 }, { 450, 90 }, { 560, -95 }, { 585, 100 }, { 660, 40 },
		{ 670, -40 }, { 735, 170 }, { 760, -150 }, { 820, 170 }, { 825, -140 }, { 395, 225 }, { 420, -170 }, { 530, 250 },
		{ 540, -250 }, { 290, 200 } },
	bushes = { { 275, 25 }, { 275, -25 }, { 430, 40 }, { 430, -50 }, { 555, 30 }, { 560, -40 }, { 340, 160 }, { 340, -165 },
		{ 640, 150 }, { 640, -150 }, { 750, 60 }, { 755, -45 }, { 850, 40 }, { 850, -40 } },
	-- seven tall lanterns along M2, about 10 off its centre line like the K-D ones, each with its light
	lanternsTall = { { 270, 10 }, { 350, -17 }, { 430, 12 }, { 510, -15 }, { 590, 12 }, { 670, -14 }, { 750, 13 } },
	-- fourteen unlit short ones: the PlazaOvillos (the PlazaCentral pattern), JardinNorte, JardinSur, the two walks
	lanternsShort = { { 478, 4 }, { 478, -20 }, { 502, 4 }, { 502, -20 },
		{ 507, 137 }, { 533, 137 }, { 535, 103 },
		{ 507, -142 }, { 533, -142 }, { 535, -108 },
		{ 395, 140 }, { 645, 140 }, { 395, -140 }, { 645, -140 } },
	patches = { { 300, 120 }, { 300, -120 }, { 390, 170 }, { 400, -165 }, { 460, 70 }, { 440, -80 }, { 575, 50 }, { 575, -50 },
		{ 640, 200 }, { 690, -170 }, { 720, 90 }, { 720, -100 }, { 800, 100 }, { 800, -80 } },
	flowers = { { 290, 20 }, { 295, -22 }, { 360, 20 }, { 335, -30 }, { 410, 24 }, { 400, -22 }, { 470, 25 }, { 465, -30 },
		{ 520, 25 }, { 525, -28 }, { 600, -25 }, { 620, 25 }, { 700, 28 }, { 705, -25 }, { 780, 25 }, { 775, -30 },
		{ 545, 145 }, { 545, -145 }, { 350, 150 }, { 355, -150 }, { 600, 150 }, { 610, -160 }, { 690, 140 }, { 680, -140 } },
	tufts = { { 305, 45 }, { 320, -55 }, { 375, 40 }, { 385, -45 }, { 445, 70 }, { 450, -65 }, { 540, 70 }, { 545, -70 },
		{ 625, 55 }, { 640, -35 }, { 710, 50 }, { 705, -50 }, { 790, 45 }, { 790, -45 }, { 420, 160 }, { 430, -150 },
		{ 585, 175 }, { 590, -175 }, { 665, 200 }, { 725, -200 }, { 760, 165 }, { 775, -160 }, { 825, 60 }, { 825, -60 } },
}

-- Palette (art pass §2): the master photo's green park, beige stones, pink blossom; nothing dark or violet on the ground.
local C = {
	GRASS_DK = { 111, 175, 90 }, GRASS_LT = { 168, 214, 120 },
	SLAB = { 199, 183, 155 }, SLAB_DK = { 176, 162, 140 }, STONE = { 184, 175, 163 }, SAND = { 226, 206, 160 },
	BLOSSOM = { 242, 165, 204 }, BLOSSOM_DK = { 219, 125, 175 }, PETAL_LT = { 248, 196, 222 }, TRUNK = { 150, 104, 72 },
	WOOD = { 193, 139, 91 }, WOOD_DK = { 140, 92, 62 }, LIGHT = { 251, 226, 164 }, GLOW = { 251, 206, 130 }, STEM = { 96, 158, 84 },
	CARD = { 199, 154, 104 }, CARD_DK = { 167, 119, 79 }, SISAL = { 230, 210, 166 }, FELT = { 217, 199, 179 }, PAW = { 187, 141, 106 },
	KRAFT = { 205, 150, 105 }, YEL = { 255, 213, 74 }, PINK = { 255, 111, 167 }, MINT = { 83, 214, 168 },
	CREAM = { 247, 230, 200 }, SAND_CAT = { 228, 182, 122 }, TERRA = { 219, 123, 70 }, TERRA_DK = { 182, 79, 46 },
	STONE_T = { 199, 184, 168 }, STONE_TD = { 159, 142, 127 }, GLASS = { 109, 169, 196 }, PIPE = { 197, 138, 99 },
	PAPER = { 250, 248, 244 }, COTTON = { 250, 246, 240 }, STICK = { 238, 200, 140 }, WHITE = { 252, 250, 248 },
	CLOUD = { 255, 236, 245 }, INK = { 90, 50, 30 }, RED = { 220, 60, 60 }, LILAC = { 150, 110, 200 },
}
local SLAB_COLORS = { C.SLAB, C.SLAB_DK, C.STONE }
-- Ovillo Gigante (sheet 06): diameter, ball and three band colours per variant.
local YARN = {
	rainbow = { d = 16, ball = { 175, 120, 230 }, bands = { { 240, 110, 180 }, { 170, 220, 80 }, { 90, 190, 240 } } },
	sky = { d = 14, ball = { 90, 190, 240 }, bands = { { 60, 150, 215 }, { 150, 215, 245 }, { 60, 150, 215 } } },
	pink = { d = 14, ball = { 240, 110, 180 }, bands = { { 215, 80, 150 }, { 250, 170, 210 }, { 215, 80, 150 } } },
	cream = { d = 12, ball = { 245, 230, 200 }, bands = { { 225, 200, 160 }, { 250, 242, 225 }, { 225, 200, 160 } } },
	orange = { d = 14, ball = { 245, 150, 60 }, bands = { { 220, 115, 35 }, { 250, 190, 120 }, { 220, 115, 35 } } },
	lime = { d = 12, ball = { 170, 220, 80 }, bands = { { 130, 190, 50 }, { 205, 240, 140 }, { 130, 190, 50 } } },
	purple = { d = 16, ball = { 175, 120, 230 }, bands = { { 140, 90, 205 }, { 210, 170, 245 }, { 140, 90, 205 } } },
}
local SWAB_TIPS = { pink = { 247, 170, 200 }, blue = { 140, 200, 240 }, mint = { 150, 225, 190 } }
local BAG_TINTS = { blue = { 230, 240, 250 }, pink = { 255, 205, 225 } }
local FLOWER_HEADS = { { { 250, 248, 240 }, { 247, 180, 210 } }, { { 255, 222, 110 }, { 247, 180, 210 } }, { { 250, 248, 240 }, { 160, 200, 245 } } }

-- Recipe helpers: each adds one part spec to the list l. at = { x, y, z, rx?, ry?, rz? } (degrees) local to the pivot.
local function add(l, name, shape, size, at, color, role, material, extra)
	local spec = { name = name, shape = shape, size = { size[1], size[2], size[3] },
		offset = { at[1], at[2], at[3], at[4] or 0, at[5] or 0, at[6] or 0 }, color = color, role = role or "decor",
		material = material or "SmoothPlastic" }
	if extra then
		for key, value in pairs(extra) do spec[key] = value end
	end
	table.insert(l, spec)
	return spec
end
local function block(l, name, size, at, color, role, material, extra)
	return add(l, name, "Block", size, at, color, role, material, extra)
end
-- "B+S": a Block with a Sphere SpecialMesh, an oval of the part's size
local function oval(l, name, size, at, color, role, material, extra)
	local spec = add(l, name, "Block", size, at, color, role, material, extra)
	spec.mesh = "Sphere"
	return spec
end
local function ball(l, name, d, at, color, role, material)
	return add(l, name, "Ball", { d, d, d }, at, color, role, material)
end
local function wedge(l, name, size, at, color, role, material)
	return add(l, name, "Wedge", size, at, color, role, material)
end
-- an upright cylinder (diameter d, height h); rx and ry of `at` tilt it, its rz is the upright turn
local function drum(l, name, d, h, at, color, role, material, extra)
	return add(l, name, "Cylinder", { h, d, d }, { at[1], at[2], at[3], at[4] or 0, at[5] or 0, 90 }, color, role, material, extra)
end
-- a cylinder lying along local X (turned by `at`'s angles)
local function rodX(l, name, d, len, at, color, role, material)
	return add(l, name, "Cylinder", { len, d, d }, at, color, role, material)
end
-- a cylinder lying along local Z: a disc facing the front when it is short
local function rodZ(l, name, d, len, at, color, role, material)
	return add(l, name, "Cylinder", { len, d, d }, { at[1], at[2], at[3], at[4] or 0, 90, at[6] or 0 }, color, role, material)
end
local function sign(text, color, faces)
	return { text = { text = text, color = color, faces = faces or { "Front" } } }
end

-- The recipes: kind -> function(variant) -> part specs. Each line adds exactly one part (no loops), so the counts in the
-- comments are the K-D18 counts; WildboundKittenPark_Test checks every one.
local R = {}

-- Paths (K-D16 / Appendix B): role floor, laid at the floor's top.
R.strip = function(length) -- [1] a sand strip along a main-path leg (length = the leg's length)
	local l = {}
	block(l, "Strip", { 12, 0.24, tonumber(length) or 10 }, { 0, 0, 0 }, C.SAND, "floor", "Sand")
	return l
end
R.joint = function() -- [1] a sand disc at a bend of the main path
	local l = {}
	drum(l, "Joint", 12, 0.24, { 0, 0, 0 }, C.SAND, "floor", "Sand")
	return l
end
R.junction = function(d) -- [1] a sand disc where paths meet (diameter d)
	local l = {}
	drum(l, "Junction", tonumber(d) or 24, 0.26, { 0, 0.01, 0 }, C.SAND, "floor", "Sand")
	return l
end
local function jitter(i, salt)
	local rng = Random.new(Park.SEED * 7 + salt + 101 * (tonumber(i) or 0))
	return rng:NextNumber(0.88, 1.12), rng:NextNumber(0.88, 1.12), SLAB_COLORS[rng:NextInteger(1, #SLAB_COLORS)]
end
R.slab = function(i) -- [1] a main-path slab on the sand (6.5 across, 4.8 along, sized and tinted by its index)
	local l = {}
	local sx, sz, color = jitter(i, 1)
	block(l, "Slab", { 6.5 * sx, 0.3, 4.8 * sz }, { 0, 0.25, 0 }, color, "floor", "Slate")
	return l
end
R.stone = function(i) -- [1] a fork's stepping stone on the grass
	local l = {}
	local sx, sz, color = jitter(i, 2)
	block(l, "Stone", { 5 * sx, 0.3, 4 * sz }, { 0, 0.15, 0 }, color, "floor", "Slate")
	return l
end

-- K-D16: Arco de Nubes, the cloud gate [8]: two pillars (z +-9, 15 clear between them, over the wall's 14-stud gap),
-- five cloud puffs and the "Pueblo Gatito" sign, readable from both sides of the gate.
R.arch = function()
	local l = {}
	drum(l, "PillarNorth", 3, 14, { 0, 7, 9 }, C.CLOUD, "solid")
	drum(l, "PillarSouth", 3, 14, { 0, 7, -9 }, C.CLOUD, "solid")
	oval(l, "Cloud1", { 8, 5, 6 }, { 0, 15, -6 }, C.CLOUD)
	oval(l, "Cloud2", { 9, 6, 7 }, { 0, 16.5, 0 }, { 255, 246, 250 })
	oval(l, "Cloud3", { 8, 5, 6 }, { 0, 15, 6 }, C.CLOUD)
	oval(l, "Cloud4", { 5, 4, 4 }, { 0, 18.5, -3 }, { 255, 250, 252 })
	oval(l, "Cloud5", { 5, 4, 4 }, { 0, 18.5, 3.5 }, { 255, 250, 252 })
	block(l, "Sign", { 0.4, 2.2, 10 }, { 0, 12.4, 0 }, C.WOOD, "decor", "Wood", sign("Pueblo Gatito", { 255, 248, 235 }, { "Left", "Right" }))
	return l
end

-- Village (sheets 03-11, art pass §4). Bodies are the solid proxies, plinths are floors, every detail is decor.
R.cafe = function() -- Café Cat [38]: brick café with a giant cat-face coffee cup on the roof, a terrace and a sleeping cat
	local l = {}
	block(l, "Plinth", { 24, 1, 24 }, { 0, 0.5, 0 }, { 205, 172, 140 }, "floor")
	block(l, "Body", { 14, 12, 14 }, { 2, 7, 2 }, { 176, 96, 58 }, "solid", "Brick")
	block(l, "Cornice", { 15, 1, 15 }, { 2, 13.5, 2 }, { 120, 66, 40 })
	block(l, "Door", { 4, 6.5, 0.4 }, { -1, 4.25, -5.1 }, { 110, 66, 40 })
	rodZ(l, "DoorArch", 4, 0.4, { -1, 7.5, -5.1 }, { 110, 66, 40 })
	block(l, "Window", { 4.5, 4, 0.3 }, { 5.5, 6, -5.1 }, C.GLOW)
	wedge(l, "Awning1", { 1.6, 1.4, 3 }, { 3.9, 8.7, -6.5 }, { 240, 130, 140 })
	wedge(l, "Awning2", { 1.6, 1.4, 3 }, { 5.5, 8.7, -6.5 }, { 250, 240, 235 })
	wedge(l, "Awning3", { 1.6, 1.4, 3 }, { 7.1, 8.7, -6.5 }, { 240, 130, 140 })
	drum(l, "Cup", 13, 7, { 2, 17.5, 2 }, { 150, 85, 50 })
	drum(l, "CupRim", 13.4, 0.6, { 2, 21.2, 2 }, { 175, 105, 65 })
	oval(l, "Foam", { 12, 3.2, 12 }, { 2, 21.8, 2 }, { 250, 236, 214 })
	rodZ(l, "Handle", 5, 1, { 9.6, 17.5, 2 }, { 150, 85, 50 })
	rodZ(l, "HandleHole", 2.6, 1.2, { 9.6, 17.5, 2 }, C.INK)
	wedge(l, "EarL", { 1, 2.6, 2.4 }, { -2, 23.6, 2 }, { 150, 85, 50 })
	wedge(l, "EarR", { 1, 2.6, 2.4 }, { 6, 23.6, 2 }, { 150, 85, 50 })
	block(l, "EyeL", { 1.6, 0.35, 0.3 }, { 0.2, 18.6, -4.4, 0, 0, 10 }, C.INK)
	block(l, "EyeR", { 1.6, 0.35, 0.3 }, { 3.8, 18.6, -4.4, 0, 0, -10 }, C.INK)
	block(l, "Mouth", { 1.2, 0.3, 0.3 }, { 2, 17.2, -4.6 }, C.INK)
	rodZ(l, "Medallion", 3, 0.3, { 2, 15.4, -4.55 }, { 250, 236, 214 })
	block(l, "SignBoard", { 8, 2, 0.4 }, { 2, 10.6, -5.3 }, { 250, 236, 214 }, "decor", nil, sign("Café Cat", { 110, 66, 40 }))
	drum(l, "TableTop", 4, 0.4, { -6, 3.2, -9 }, { 250, 240, 225 })
	drum(l, "TableLeg", 0.6, 2, { -6, 2, -9 }, C.WOOD_DK)
	drum(l, "UmbrellaPole", 0.3, 6, { -6, 4, -9 }, C.WOOD_DK)
	oval(l, "Umbrella", { 7, 1.4, 7 }, { -6, 7, -9 }, { 247, 170, 195 })
	block(l, "ChairSeatL", { 1.6, 0.3, 1.6 }, { -8.8, 2.2, -9 }, C.WOOD)
	block(l, "ChairBackL", { 0.3, 1.8, 1.6 }, { -9.6, 3.2, -9 }, C.WOOD)
	block(l, "ChairSeatR", { 1.6, 0.3, 1.6 }, { -3.2, 2.2, -9 }, C.WOOD)
	block(l, "ChairBackR", { 0.3, 1.8, 1.6 }, { -2.4, 3.2, -9 }, C.WOOD)
	block(l, "BoardFront", { 2.4, 3, 0.2 }, { 8, 2.45, -11.2, 15, 0, 0 }, C.WOOD_DK, "decor", nil, sign("Paws & Coffee", { 255, 240, 220 }))
	block(l, "BoardBack", { 2.4, 3, 0.2 }, { 8, 2.45, -10.4, -15, 0, 0 }, C.WOOD_DK)
	drum(l, "PotL", 1.6, 1.4, { -4.5, 1.7, -5.9 }, { 200, 110, 70 })
	oval(l, "PlantL", { 1.8, 1.6, 1.8 }, { -4.5, 3, -5.9 }, C.STEM)
	drum(l, "PotR", 1.6, 1.4, { 9, 1.7, -5.9 }, { 200, 110, 70 })
	oval(l, "PlantR", { 1.8, 1.6, 1.8 }, { 9, 3, -5.9 }, C.STEM)
	block(l, "HangingLantern", { 0.8, 1.2, 0.8 }, { -3.5, 8.6, -5.6 }, C.LIGHT, "decor", "Neon")
	oval(l, "SleepyCat", { 2.8, 1.4, 1.8 }, { 9.5, 1.7, -8 }, { 232, 150, 70 })
	ball(l, "SleepyCatHead", 1.2, { 10.9, 2.1, -8 }, { 232, 150, 70 })
	return l
end

R.bakery = function() -- Panadería Gatuna [34]: cream bakery, pink striped awning, display window, chef cat
	local l = {}
	block(l, "Plinth", { 26, 0.6, 20 }, { 0, 0.3, 0 }, { 205, 170, 145 }, "floor")
	block(l, "Body", { 22, 12, 14 }, { 0, 6.6, 1.5 }, { 247, 224, 200 }, "solid", "Plaster")
	block(l, "Fascia", { 23.5, 2.4, 15.5 }, { 0, 13.8, 1.5 }, { 250, 238, 222 }, "decor", nil, sign("Panadería Gatuna", { 200, 95, 120 }))
	block(l, "Chimney", { 3, 4, 3 }, { 6, 16.8, 5 }, { 214, 128, 90 })
	block(l, "ChimneyCap", { 3.6, 0.8, 3.6 }, { 6, 19.2, 5 }, { 150, 90, 70 })
	ball(l, "Smoke1", 2.4, { 6.5, 21, 5 }, C.WHITE)
	ball(l, "Smoke2", 1.8, { 7.6, 22.6, 5.4 }, C.WHITE)
	wedge(l, "Awning1", { 4.4, 2.6, 4 }, { -8.8, 10.3, -7.5 }, { 240, 120, 150 })
	wedge(l, "Awning2", { 4.4, 2.6, 4 }, { -4.4, 10.3, -7.5 }, { 252, 246, 240 })
	wedge(l, "Awning3", { 4.4, 2.6, 4 }, { 0, 10.3, -7.5 }, { 240, 120, 150 })
	wedge(l, "Awning4", { 4.4, 2.6, 4 }, { 4.4, 10.3, -7.5 }, { 252, 246, 240 })
	wedge(l, "Awning5", { 4.4, 2.6, 4 }, { 8.8, 10.3, -7.5 }, { 240, 120, 150 })
	rodX(l, "AwningLip", 1.2, 22, { 0, 9, -9.5 }, { 240, 120, 150 })
	block(l, "DisplayWindow", { 10, 6, 0.4 }, { -4, 5, -5.6 }, C.GLOW)
	block(l, "WindowHeader", { 11, 0.8, 0.6 }, { -4, 8.4, -5.7 }, C.WOOD)
	oval(l, "Loaf1", { 1.8, 0.9, 0.9 }, { -7, 3.2, -6.1 }, { 226, 160, 80 })
	oval(l, "Loaf2", { 1.8, 0.9, 0.9 }, { -4, 3.2, -6.1 }, { 226, 160, 80 })
	oval(l, "Loaf3", { 1.8, 0.9, 0.9 }, { -1, 3.2, -6.1 }, { 226, 160, 80 })
	rodZ(l, "Wreath", 2.2, 0.3, { 5.5, 4.8, -5.9 }, { 210, 140, 70 })
	oval(l, "Bow", { 1, 0.6, 0.4 }, { 5.5, 5.9, -6 }, { 240, 120, 150 })
	block(l, "Door", { 4, 6.5, 0.4 }, { 5.5, 3.85, -5.6 }, { 150, 95, 60 })
	rodZ(l, "DoorArch", 4, 0.4, { 5.5, 7.1, -5.6 }, { 150, 95, 60 })
	oval(l, "ChefBody", { 2.2, 2.6, 1.8 }, { -8, 1.9, -8.5 }, { 110, 105, 110 })
	ball(l, "ChefHead", 1.8, { -8, 3.9, -8.5 }, { 120, 115, 120 })
	drum(l, "ChefHat", 1.4, 1.2, { -8, 5.2, -8.5 }, C.WHITE)
	drum(l, "PotL", 1.6, 1.6, { -11.6, 1.4, -8 }, C.WHITE)
	drum(l, "TrunkL", 0.4, 2, { -11.6, 3.2, -8 }, C.TRUNK)
	oval(l, "CrownL", { 2.6, 2.6, 2.6 }, { -11.6, 5.2, -8 }, { 160, 215, 170 })
	drum(l, "PotR", 1.6, 1.6, { 11.6, 1.4, -8 }, C.WHITE)
	drum(l, "TrunkR", 0.4, 2, { 11.6, 3.2, -8 }, C.TRUNK)
	oval(l, "CrownR", { 2.6, 2.6, 2.6 }, { 11.6, 5.2, -8 }, { 160, 215, 170 })
	block(l, "WallLanternL", { 0.8, 1.2, 0.8 }, { -10, 7.5, -5.9 }, C.LIGHT, "decor", "Neon")
	block(l, "WallLanternR", { 0.8, 1.2, 0.8 }, { 10, 7.5, -5.9 }, C.LIGHT, "decor", "Neon")
	block(l, "SideWindow", { 0.3, 4, 5 }, { -11.1, 6.5, 2 }, C.GLOW)
	return l
end

R.potter = function() -- Casa Gato Alfarero [40]: a grinning cat house in a pot on stilts, wizard hat, ladder, curled tail
	local l = {}
	drum(l, "StoneBase", 18, 0.6, { 0, 0.3, 0 }, { 180, 160, 130 }, "floor")
	drum(l, "Stilt1", 0.8, 3, { 4.5, 2.1, 4.5 }, { 170, 110, 60 })
	drum(l, "Stilt2", 0.8, 3, { -4.5, 2.1, 4.5 }, { 170, 110, 60 })
	drum(l, "Stilt3", 0.8, 3, { 4.5, 2.1, -4.5 }, { 170, 110, 60 })
	drum(l, "Stilt4", 0.8, 3, { -4.5, 2.1, -4.5 }, { 170, 110, 60 })
	oval(l, "Pot", { 15, 7, 15 }, { 0, 6, 0 }, C.LILAC, "solid")
	drum(l, "PotRim", 15.5, 0.8, { 0, 8.8, 0 }, { 170, 130, 215 })
	oval(l, "CatBody", { 13, 12, 12 }, { 0, 13, 0 }, { 196, 150, 120 }, "solid")
	block(l, "EyeL", { 1.8, 0.4, 0.3 }, { -2.2, 15, -5.3, 0, 0, 20 }, { 80, 50, 50 })
	block(l, "EyeR", { 1.8, 0.4, 0.3 }, { 2.2, 15, -5.3, 0, 0, -20 }, { 80, 50, 50 })
	block(l, "Grin", { 6.6, 2.2, 0.3 }, { 0, 11.6, -5.4 }, { 90, 50, 60 })
	block(l, "Teeth", { 6, 1.6, 0.3 }, { 0, 11.6, -5.55 }, { 250, 248, 240 })
	wedge(l, "Nose", { 1, 0.8, 0.8 }, { 0, 13.4, -5.9 }, { 130, 70, 150 })
	wedge(l, "EarL", { 1.2, 3.5, 2.6 }, { -5.2, 20.5, -0.5 }, { 196, 150, 120 })
	wedge(l, "EarR", { 1.2, 3.5, 2.6 }, { 5.2, 20.5, -0.5 }, { 196, 150, 120 })
	drum(l, "HatBrim", 17, 0.6, { 0, 19.3, 0, 8 }, { 150, 100, 70 })
	drum(l, "HatTier1", 6, 1.8, { 0, 20.8, 0.3 }, C.LILAC)
	drum(l, "HatTier2", 5, 1.8, { 0, 22.6, 0.6 }, { 125, 85, 180 })
	drum(l, "HatTier3", 4, 1.8, { 0, 24.4, 0.9 }, C.LILAC)
	drum(l, "HatCap", 4.4, 0.6, { 0, 25.6, 1 }, { 170, 170, 175 })
	block(l, "Door", { 4.5, 5.5, 0.4 }, { 0, 5.5, -7.3 }, { 125, 85, 180 })
	rodZ(l, "DoorArch", 5.4, 0.3, { 0, 7.6, -7.2 }, { 190, 185, 180 })
	block(l, "LadderRailL", { 0.3, 6, 0.3 }, { 3.7, 3.2, -8.5, 25, 0, 0 }, { 190, 120, 60 })
	block(l, "LadderRailR", { 0.3, 6, 0.3 }, { 5.3, 3.2, -8.5, 25, 0, 0 }, { 190, 120, 60 })
	block(l, "LadderRung1", { 1.9, 0.25, 0.25 }, { 4.5, 1.84, -9.13, 25, 0, 0 }, { 190, 120, 60 })
	block(l, "LadderRung2", { 1.9, 0.25, 0.25 }, { 4.5, 3.2, -8.5, 25, 0, 0 }, { 190, 120, 60 })
	block(l, "LadderRung3", { 1.9, 0.25, 0.25 }, { 4.5, 4.56, -7.87, 25, 0, 0 }, { 190, 120, 60 })
	rodX(l, "WindowL", 3, 0.3, { -6.25, 12.5, 1.5 }, C.CREAM)
	block(l, "WindowLBarV", { 0.35, 2.6, 0.3 }, { -6.42, 12.5, 1.5 }, { 150, 100, 70 })
	block(l, "WindowLBarH", { 0.35, 0.3, 2.6 }, { -6.42, 12.5, 1.5 }, { 150, 100, 70 })
	rodX(l, "WindowR", 3, 0.3, { 6.25, 12.5, 1.5 }, C.CREAM)
	block(l, "WindowRBarV", { 0.35, 2.6, 0.3 }, { 6.42, 12.5, 1.5 }, { 150, 100, 70 })
	block(l, "WindowRBarH", { 0.35, 0.3, 2.6 }, { 6.42, 12.5, 1.5 }, { 150, 100, 70 })
	oval(l, "Tail1", { 1.6, 1.6, 4 }, { 3, 8, 7.5, -30, 0, 0 }, { 150, 100, 80 })
	oval(l, "Tail2", { 1.6, 4, 1.6 }, { 3, 11, 9.5 }, { 150, 100, 80 })
	oval(l, "Tail3", { 2.2, 2.2, 2.2 }, { 3, 13.2, 8.6 }, { 150, 100, 80 })
	drum(l, "PlantPotL", 1.8, 1.6, { -6, 1.4, -6 }, C.LILAC)
	oval(l, "LeavesL", { 2.2, 2, 2.2 }, { -6, 3, -6 }, { 70, 200, 220 })
	drum(l, "PlantPotR", 1.8, 1.6, { 6.8, 1.4, -5 }, C.LILAC)
	oval(l, "LeavesR", { 2.2, 2, 2.2 }, { 6.8, 3, -5 }, { 70, 200, 220 })
	return l
end

R.fishshop = function() -- Tienda Globo Pez [36]: a coral kiosk on a cloud, a blue puffer-fish balloon above it
	local l = {}
	oval(l, "Cloud1", { 8, 3, 8 }, { -3, 1, -2 }, { 255, 232, 240 })
	oval(l, "Cloud2", { 8, 3, 8 }, { 3, 1, 2 }, { 255, 232, 240 })
	oval(l, "Cloud3", { 7, 2.6, 7 }, { 3.5, 1, -3 }, { 255, 240, 246 })
	oval(l, "Cloud4", { 7, 2.6, 7 }, { -3, 1, 3 }, { 255, 240, 246 })
	block(l, "Kiosk", { 10, 6, 8 }, { 0, 4, 0 }, { 226, 118, 128 }, "solid")
	oval(l, "RoofCushion", { 11, 2.6, 9 }, { 0, 7.6, 0 }, { 240, 140, 160 })
	wedge(l, "Awning1", { 3.4, 1.6, 2.4 }, { -3.4, 6.2, -5.2 }, C.RED)
	wedge(l, "Awning2", { 3.4, 1.6, 2.4 }, { 0, 6.2, -5.2 }, C.WHITE)
	wedge(l, "Awning3", { 3.4, 1.6, 2.4 }, { 3.4, 6.2, -5.2 }, C.RED)
	block(l, "Counter", { 10, 1, 1.6 }, { 0, 3.2, -4.6 }, { 240, 210, 170 })
	block(l, "Window", { 7, 2.4, 0.3 }, { 0, 4.9, -4.1 }, { 150, 190, 230 })
	block(l, "PawSign", { 4, 1.4, 0.3 }, { 0, 2, -5.5 }, { 255, 150, 190 }, "decor", "Neon", sign("=^.^=", { 255, 255, 255 }))
	block(l, "Crate1", { 2, 2, 2 }, { -2.5, 9.6, 1 }, { 180, 120, 70 })
	block(l, "Crate2", { 1.6, 1.6, 1.6 }, { 2.2, 9.4, 1.6 }, { 180, 120, 70 })
	oval(l, "Fruit", { 1.8, 1.8, 1.8 }, { 2.2, 11, 1.6 }, { 250, 205, 60 })
	drum(l, "BalloonRing", 9, 0.6, { 0, 14.2, 0 }, { 180, 130, 80 })
	block(l, "Rope1", { 0.25, 4.4, 0.25 }, { 3.2, 11.6, 3.2 }, { 150, 110, 70 })
	block(l, "Rope2", { 0.25, 4.4, 0.25 }, { -3.2, 11.6, 3.2 }, { 150, 110, 70 })
	block(l, "Rope3", { 0.25, 4.4, 0.25 }, { 3.2, 11.6, -3.2 }, { 150, 110, 70 })
	block(l, "Rope4", { 0.25, 4.4, 0.25 }, { -3.2, 11.6, -3.2 }, { 150, 110, 70 })
	oval(l, "Balloon", { 14, 12, 13 }, { 0, 20, 0 }, { 90, 160, 230 })
	oval(l, "Belly", { 12, 7, 11.6 }, { 0.5, 17.8, 0 }, { 190, 225, 240 })
	oval(l, "Lips", { 2.6, 2.2, 3 }, { -7, 19.5, 0 }, { 245, 130, 40 })
	rodZ(l, "EyeFront", 3.6, 0.4, { -3.5, 22, -5.3 }, C.WHITE)
	block(l, "EyeFrontX1", { 0.25, 1.8, 0.3 }, { -3.5, 22, -5.5, 0, 0, 45 }, { 40, 35, 45 })
	block(l, "EyeFrontX2", { 0.25, 1.8, 0.3 }, { -3.5, 22, -5.5, 0, 0, -45 }, { 40, 35, 45 })
	rodZ(l, "EyeBack", 3.6, 0.4, { -3.5, 22, 5.3 }, C.WHITE)
	block(l, "EyeBackX1", { 0.25, 1.8, 0.3 }, { -3.5, 22, 5.5, 0, 0, 45 }, { 40, 35, 45 })
	block(l, "EyeBackX2", { 0.25, 1.8, 0.3 }, { -3.5, 22, 5.5, 0, 0, -45 }, { 40, 35, 45 })
	oval(l, "FinFront", { 2.6, 1.4, 3.2 }, { 0.5, 17, -6.4, 0, 20, 0 }, { 170, 220, 240 })
	oval(l, "FinBack", { 2.6, 1.4, 3.2 }, { 0.5, 17, 6.4, 0, -20, 0 }, { 170, 220, 240 })
	wedge(l, "TailUp", { 0.6, 3.2, 3 }, { 8.2, 21.8, 0, 0, 90, 0 }, { 70, 140, 215 })
	wedge(l, "TailDown", { 0.6, 3.2, 3 }, { 8.2, 18.4, 0, 180, 90, 0 }, { 70, 140, 215 })
	wedge(l, "Spike1", { 0.4, 1.6, 1.6 }, { -2, 26.4, 0, 0, 90, 0 }, { 70, 140, 215 })
	wedge(l, "Spike2", { 0.4, 1.6, 1.6 }, { 1, 26.6, 0, 0, 90, 0 }, { 70, 140, 215 })
	wedge(l, "Spike3", { 0.4, 1.6, 1.6 }, { 4, 26, 0, 0, 90, 0 }, { 70, 140, 215 })
	return l
end

R.takoyaki = function() -- Takoyaki Gatuno [39]: a wooden stall with a blue gable, red noren and a cat-head roof sign
	local l = {}
	block(l, "Plinth", { 20, 0.6, 16 }, { 0, 0.3, 0 }, { 200, 185, 165 }, "floor")
	block(l, "Body", { 14, 9, 9 }, { 0, 5.1, 2.5 }, { 170, 110, 60 }, "solid", "Wood")
	block(l, "PostL", { 0.8, 9, 0.8 }, { -6.6, 5.1, -3.6 }, C.WOOD_DK)
	block(l, "PostR", { 0.8, 9, 0.8 }, { 6.6, 5.1, -3.6 }, C.WOOD_DK)
	wedge(l, "RoofFront", { 16, 3, 6.5 }, { 0, 11.1, -0.75 }, { 90, 130, 170 })
	wedge(l, "RoofBack", { 16, 3, 6.5 }, { 0, 11.1, 5.75, 0, 180, 0 }, { 90, 130, 170 })
	rodX(l, "Ridge", 0.8, 16.4, { 0, 12.6, 2.5 }, { 70, 105, 145 })
	block(l, "Noren", { 12, 2.2, 0.15 }, { 0, 8.3, -2.15 }, C.RED, "decor", nil, sign("Takoyaki", { 255, 255, 255 }))
	block(l, "NorenStripe", { 12, 0.4, 0.16 }, { 0, 7.1, -2.2 }, C.WHITE)
	block(l, "Counter", { 12, 1, 2 }, { 0, 3.4, -3 }, { 205, 170, 130 })
	block(l, "Grill", { 4, 0.5, 1.6 }, { -3, 4.15, -3 }, { 60, 55, 55 })
	ball(l, "Ball1", 0.7, { -4.2, 4.6, -3 }, { 210, 150, 80 })
	ball(l, "Ball2", 0.7, { -3, 4.6, -3 }, { 210, 150, 80 })
	ball(l, "Ball3", 0.7, { -1.8, 4.6, -3 }, { 210, 150, 80 })
	oval(l, "SignHead", { 9, 5, 2.6 }, { 0, 15.6, 1.8 }, { 250, 245, 235 })
	oval(l, "SignPatch", { 3, 2.2, 0.6 }, { 2.4, 16.6, 0.6 }, { 245, 160, 60 })
	wedge(l, "SignEarL", { 1.4, 2, 1.2 }, { -3, 18.6, 1.8 }, { 250, 245, 235 })
	wedge(l, "SignEarR", { 1.4, 2, 1.2 }, { 3, 18.6, 1.8 }, { 245, 160, 60 })
	block(l, "SignEyeL", { 1.2, 0.3, 0.2 }, { -1.6, 15.8, 0.5 }, { 60, 50, 50 })
	block(l, "SignEyeR", { 1.2, 0.3, 0.2 }, { 1.6, 15.8, 0.5 }, { 60, 50, 50 })
	block(l, "SignMouth", { 0.8, 0.4, 0.2 }, { 0, 14.6, 0.5 }, { 240, 130, 150 })
	oval(l, "BlackCat", { 2.2, 3.2, 1.8 }, { 5.8, 2.2, -6 }, { 35, 30, 35 })
	ball(l, "BlackCatEyeL", 0.45, { 5.4, 3, -6.85 }, { 250, 210, 40 })
	ball(l, "BlackCatEyeR", 0.45, { 6.2, 3, -6.85 }, { 250, 210, 40 })
	wedge(l, "BlackCatEarL", { 0.6, 0.8, 0.5 }, { 5.2, 3.9, -6 }, { 35, 30, 35 })
	wedge(l, "BlackCatEarR", { 0.6, 0.8, 0.5 }, { 6.4, 3.9, -6 }, { 35, 30, 35 })
	drum(l, "DishPost", 0.3, 2, { 5.5, 13.6, 6 }, { 170, 170, 175 })
	oval(l, "Dish", { 2.6, 2.6, 0.6 }, { 5.5, 14.8, 6, -30, 0, 0 }, { 220, 220, 225 })
	oval(l, "PaperLantern", { 1.6, 2.2, 1.6 }, { -6.6, 7.8, -3.6 }, { 250, 232, 200 })
	drum(l, "LanternBand", 1.7, 0.35, { -6.6, 7.8, -3.6 }, { 245, 150, 60 })
	block(l, "VerticalSign", { 1.8, 5, 0.3 }, { 7.6, 5.5, -3.05 }, { 40, 80, 80 })
	block(l, "VerticalBorder", { 2.2, 5.4, 0.25 }, { 7.6, 5.5, -2.9 }, C.RED)
	block(l, "Crate", { 2, 1.6, 1.6 }, { -8, 1.4, -5.5 }, { 90, 170, 80 })
	block(l, "Chalkboard", { 2, 2.4, 0.2 }, { -6.2, 1.9, -7.2, 12, 0, 0 }, { 40, 45, 40 })
	block(l, "ChalkboardLeg", { 0.2, 2.6, 0.2 }, { -6.2, 1.9, -6.6, -15, 0, 0 }, C.WOOD)
	oval(l, "FrontCatA", { 1.8, 2.2, 1.6 }, { -2, 1.7, -6.8 }, { 250, 245, 240 })
	oval(l, "FrontCatAPatch", { 1, 0.8, 0.4 }, { -2.3, 2.3, -7.5 }, { 245, 160, 60 })
	oval(l, "FrontCatB", { 1.8, 2.2, 1.6 }, { 2, 1.7, -6.8 }, { 200, 195, 200 })
	oval(l, "FrontCatBPatch", { 1, 0.8, 0.4 }, { 2.3, 2.3, -7.5 }, { 80, 75, 80 })
	return l
end

R.taiyaki = function() -- Taiyaki Mochi [33]: a plank-roofed stall, navy noren, a giant taiyaki fish on the roof
	local l = {}
	block(l, "Plinth", { 20, 0.6, 16 }, { 0, 0.3, 0 }, { 205, 190, 170 }, "floor")
	block(l, "Body", { 14, 8, 9 }, { 0, 4.6, 2.5 }, { 196, 140, 85 }, "solid", "Wood")
	block(l, "PostL", { 0.8, 8, 0.8 }, { -6.6, 4.6, -3.6 }, C.WOOD_DK)
	block(l, "PostR", { 0.8, 8, 0.8 }, { 6.6, 4.6, -3.6 }, C.WOOD_DK)
	wedge(l, "RoofFront", { 16, 2.6, 6.5 }, { 0, 9.9, -0.75 }, { 160, 105, 60 }, "decor", "Wood")
	wedge(l, "RoofBack", { 16, 2.6, 6.5 }, { 0, 9.9, 5.75, 0, 180, 0 }, { 160, 105, 60 }, "decor", "Wood")
	rodX(l, "Ridge", 0.7, 16.4, { 0, 11.2, 2.5 }, { 130, 85, 50 })
	block(l, "Noren", { 12, 2.2, 0.15 }, { 0, 7.3, -2.15 }, { 45, 60, 140 }, "decor", nil, sign("Taiyaki", { 255, 255, 255 }))
	block(l, "Counter", { 12, 1, 2 }, { 0, 3.2, -3 }, { 220, 180, 130 })
	oval(l, "Taiyaki1", { 1.6, 0.8, 0.5 }, { -3, 3.9, -3 }, { 230, 160, 60 })
	oval(l, "Taiyaki2", { 1.6, 0.8, 0.5 }, { 0, 3.9, -3 }, { 230, 160, 60 })
	oval(l, "Taiyaki3", { 1.6, 0.8, 0.5 }, { 3, 3.9, -3 }, { 230, 160, 60 })
	ball(l, "Onigiri1", 0.9, { 4.6, 4.1, -3 }, C.WHITE)
	ball(l, "Onigiri2", 0.9, { 5.6, 4.1, -3 }, C.WHITE)
	oval(l, "RoofFish", { 12, 6, 2.5 }, { 0, 14.6, 2.5 }, { 236, 160, 60 })
	wedge(l, "RoofFishTailUp", { 0.6, 2.4, 2.4 }, { 6.8, 15.8, 2.5, 0, 90, 0 }, { 236, 160, 60 })
	wedge(l, "RoofFishTailDown", { 0.6, 2.4, 2.4 }, { 6.8, 13.4, 2.5, 180, 90, 0 }, { 236, 160, 60 })
	oval(l, "RoofFishFace", { 3.4, 3, 0.5 }, { -3.5, 14.8, 1.2 }, { 250, 225, 195 })
	ball(l, "RoofFishEyeFront", 0.7, { -4.4, 15.4, 1.1 }, { 40, 35, 40 })
	ball(l, "RoofFishEyeBack", 0.7, { -4.4, 15.4, 3.8 }, { 40, 35, 40 })
	drum(l, "Tank", 5, 5, { -6.5, 12.3, 6 }, C.CREAM)
	drum(l, "TankBand", 5.2, 0.6, { -6.5, 12.3, 6 }, { 70, 120, 200 })
	drum(l, "PipeA", 0.5, 4, { -4.2, 11.3, 5.4 }, { 240, 100, 160 })
	drum(l, "PipeB", 0.5, 4, { -4.2, 11.3, 6.6 }, { 240, 100, 160 })
	drum(l, "StoolL", 1.4, 1.6, { -3, 1.4, -5.2 }, { 240, 150, 180 })
	drum(l, "StoolR", 1.4, 1.6, { 3, 1.4, -5.2 }, { 240, 150, 180 })
	drum(l, "BannerPole", 0.25, 6, { -8.6, 3.6, -5 }, C.WOOD)
	block(l, "Banner", { 1.4, 3.4, 0.12 }, { -7.8, 4.4, -5 }, { 240, 90, 90 })
	oval(l, "EatingCatA", { 1.8, 2, 1.6 }, { -3, 3.2, -5.2 }, { 170, 165, 175 })
	ball(l, "EatingCatAHead", 1.4, { -3, 4.6, -5.3 }, { 170, 165, 175 })
	oval(l, "EatingCatB", { 1.8, 2, 1.6 }, { 3, 3.2, -5.2 }, { 240, 170, 100 })
	ball(l, "EatingCatBHead", 1.4, { 3, 4.6, -5.3 }, { 240, 170, 100 })
	block(l, "SideSign", { 0.3, 2.4, 6 }, { 7.15, 5.2, 2.5 }, { 250, 236, 214 }, "decor", nil, sign("Mochi", { 200, 95, 120 }, { "Right" }))
	return l
end

R.castle = function() -- Castillo Gatuno de cartón [53]: four towers, a 9-wide gate, merlons, red flags (its cushion stays)
	local l = {}
	block(l, "TowerFL", { 7, 22, 7 }, { -12.5, 11, -10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "TowerFR", { 7, 22, 7 }, { 12.5, 11, -10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "TowerBL", { 7, 18, 7 }, { -12.5, 9, 10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "TowerBR", { 7, 18, 7 }, { 12.5, 9, 10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "CapFL", { 7.8, 1, 7.8 }, { -12.5, 22.5, -10.5 }, { 205, 160, 100 })
	block(l, "CapFR", { 7.8, 1, 7.8 }, { 12.5, 22.5, -10.5 }, { 205, 160, 100 })
	block(l, "CapBL", { 7.8, 1, 7.8 }, { -12.5, 18.5, 10.5 }, { 205, 160, 100 })
	block(l, "CapBR", { 7.8, 1, 7.8 }, { 12.5, 18.5, 10.5 }, { 205, 160, 100 })
	block(l, "MerlonFL1", { 2, 2, 2 }, { -14.5, 24, -12.5 }, { 229, 186, 120 })
	block(l, "MerlonFL2", { 2, 2, 2 }, { -10.5, 24, -8.5 }, { 229, 186, 120 })
	block(l, "MerlonFR1", { 2, 2, 2 }, { 14.5, 24, -12.5 }, { 229, 186, 120 })
	block(l, "MerlonFR2", { 2, 2, 2 }, { 10.5, 24, -8.5 }, { 229, 186, 120 })
	block(l, "MerlonBL1", { 2, 2, 2 }, { -14.5, 20, 12.5 }, { 229, 186, 120 })
	block(l, "MerlonBL2", { 2, 2, 2 }, { -10.5, 20, 8.5 }, { 229, 186, 120 })
	block(l, "MerlonBR1", { 2, 2, 2 }, { 14.5, 20, 12.5 }, { 229, 186, 120 })
	block(l, "MerlonBR2", { 2, 2, 2 }, { 10.5, 20, 8.5 }, { 229, 186, 120 })
	block(l, "FrontWallL", { 4, 16, 2 }, { -6.5, 8, -10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "FrontWallR", { 4, 16, 2 }, { 6.5, 8, -10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "Lintel", { 9, 6, 2 }, { 0, 13, -10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	wedge(l, "FillerL", { 2, 1.5, 1.5 }, { -3.75, 9.25, -10.5, 180, -90, 0 }, { 229, 186, 120 })
	wedge(l, "FillerR", { 2, 1.5, 1.5 }, { 3.75, 9.25, -10.5, 180, 90, 0 }, { 229, 186, 120 })
	block(l, "StoneDotsL", { 0.8, 10, 0.3 }, { -5, 5, -11.65 }, { 165, 160, 150 })
	block(l, "StoneDotsR", { 0.8, 10, 0.3 }, { 5, 5, -11.65 }, { 165, 160, 150 })
	block(l, "StoneDotsTop", { 10.8, 0.8, 0.3 }, { 0, 10.4, -11.65 }, { 165, 160, 150 })
	block(l, "BackWall", { 18, 14, 2 }, { 0, 7, 10.5 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "SideWallL", { 2, 14, 14 }, { -12.5, 7, 0 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "SideWallR", { 2, 14, 14 }, { 12.5, 7, 0 }, { 229, 186, 120 }, "solid", "Cardboard")
	block(l, "WallMerlon1", { 1.6, 1.6, 1.6 }, { -7.5, 16.8, -10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon2", { 1.6, 1.6, 1.6 }, { -3, 16.8, -10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon3", { 1.6, 1.6, 1.6 }, { 3, 16.8, -10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon4", { 1.6, 1.6, 1.6 }, { 7.5, 16.8, -10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon5", { 1.6, 1.6, 1.6 }, { -6, 14.8, 10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon6", { 1.6, 1.6, 1.6 }, { -2, 14.8, 10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon7", { 1.6, 1.6, 1.6 }, { 2, 14.8, 10.5 }, { 229, 186, 120 })
	block(l, "WallMerlon8", { 1.6, 1.6, 1.6 }, { 6, 14.8, 10.5 }, { 229, 186, 120 })
	oval(l, "Cushion", { 5, 1.2, 4 }, { 0, 0.7, 2 }, { 250, 240, 235 })
	drum(l, "CushionPaw", 2, 0.2, { 0, 1.35, 2 }, { 240, 140, 170 })
	drum(l, "PoleFL", 0.3, 4, { -12.5, 25, -10.5 }, C.WOOD_DK)
	wedge(l, "FlagFL", { 0.15, 1.6, 2.4 }, { -12.5, 26.2, -9.2 }, { 226, 60, 70 })
	drum(l, "PoleFR", 0.3, 4, { 12.5, 25, -10.5 }, C.WOOD_DK)
	wedge(l, "FlagFR", { 0.15, 1.6, 2.4 }, { 12.5, 26.2, -9.2 }, { 226, 60, 70 })
	drum(l, "PoleBL", 0.3, 4, { -12.5, 21, 10.5 }, C.WOOD_DK)
	wedge(l, "FlagBL", { 0.15, 1.6, 2.4 }, { -12.5, 22.2, 11.8 }, { 226, 60, 70 })
	drum(l, "PoleBR", 0.3, 4, { 12.5, 21, 10.5 }, C.WOOD_DK)
	wedge(l, "FlagBR", { 0.15, 1.6, 2.4 }, { 12.5, 22.2, 11.8 }, { 226, 60, 70 })
	block(l, "TowerWindow1", { 1.6, 2.4, 0.3 }, { -12.5, 8, -14.15 }, { 110, 70, 40 })
	block(l, "TowerWindow2", { 1.6, 2.4, 0.3 }, { 12.5, 8, -14.15 }, { 110, 70, 40 })
	block(l, "TowerWindow3", { 1.6, 2.4, 0.3 }, { -12.5, 16, -14.15 }, { 110, 70, 40 })
	block(l, "TowerWindow4", { 1.6, 2.4, 0.3 }, { 12.5, 16, -14.15 }, { 110, 70, 40 })
	ball(l, "YarnBig", 3, { -7.5, 1.5, -16.5 }, { 175, 120, 230 }, "decor", "Fabric")
	ball(l, "YarnSmall", 2.4, { -4.5, 1.2, -17 }, { 240, 110, 170 }, "decor", "Fabric")
	block(l, "Box", { 3, 2.4, 3 }, { 8, 1.2, -16.5, 0, 20, 0 }, { 205, 160, 100 }, "decor", "Cardboard")
	drum(l, "GrassMound", 40, 0.3, { 0, 0.12, 0 }, C.GRASS_LT, "decor", "Grass")
	return l
end

R.tower = function() -- Torre Gato Vigía stand-in [37] (the GLB is an upload, K-D21): stone base, tiled skirt, cat head, turret
	local l = {}
	drum(l, "Plinth", 14, 1, { 0, 0.5, 0 }, C.STONE_TD, "floor")
	drum(l, "Base", 12, 7, { 0, 4.5, 0 }, C.STONE_T, "solid", "Cobblestone")
	block(l, "Door", { 3, 4.6, 0.4 }, { 0, 3.3, -5.9 }, C.WOOD_DK)
	rodZ(l, "DoorArch", 3, 0.4, { 0, 5.6, -5.85 }, C.STONE_TD)
	drum(l, "Skirt1", 18, 2.25, { 0, 9.125, 0 }, C.TERRA, "decor", "ClayRoofTiles")
	drum(l, "Skirt2", 16, 2.25, { 0, 11.375, 0 }, C.TERRA_DK, "decor", "ClayRoofTiles")
	drum(l, "Skirt3", 14, 2.25, { 0, 13.625, 0 }, C.TERRA, "decor", "ClayRoofTiles")
	drum(l, "Skirt4", 12, 2.25, { 0, 15.875, 0 }, C.TERRA_DK, "decor", "ClayRoofTiles")
	rodZ(l, "WindowC", 2.2, 0.3, { 0, 11.4, -7.9 }, C.CREAM)
	rodZ(l, "GlassC", 1.4, 0.35, { 0, 11.4, -8 }, C.GLASS)
	rodX(l, "WindowR", 2.2, 0.3, { 5.08, 11.4, -6.05, 0, 50, 0 }, C.CREAM)
	rodX(l, "GlassR", 1.4, 0.35, { 5.14, 11.4, -6.13, 0, 50, 0 }, C.GLASS)
	rodX(l, "WindowL", 2.2, 0.3, { -5.08, 11.4, -6.05, 0, 130, 0 }, C.CREAM)
	rodX(l, "GlassL", 1.4, 0.35, { -5.14, 11.4, -6.13, 0, 130, 0 }, C.GLASS)
	drum(l, "HeadRing", 10, 6, { 0, 20, 0 }, C.SAND_CAT)
	block(l, "EyeL", { 1.6, 0.35, 0.3 }, { -1.8, 20.6, -5, 0, 0, 12 }, { 80, 50, 40 })
	block(l, "EyeR", { 1.6, 0.35, 0.3 }, { 1.8, 20.6, -5, 0, 0, -12 }, { 80, 50, 40 })
	wedge(l, "Nose", { 0.8, 0.6, 0.6 }, { 0, 19.6, -5.1 }, { 220, 130, 120 })
	oval(l, "CheekL", { 2.4, 2, 1 }, { -2.6, 19.2, -4.6 }, C.CREAM)
	oval(l, "CheekR", { 2.4, 2, 1 }, { 2.6, 19.2, -4.6 }, C.CREAM)
	rodX(l, "WhiskerL1", 0.25, 6, { -4.2, 19.6, -4.7, 0, 0, 8 }, { 200, 200, 200 })
	rodX(l, "WhiskerL2", 0.25, 6, { -4.2, 19, -4.7, 0, 0, -8 }, { 200, 200, 200 })
	rodX(l, "WhiskerR1", 0.25, 6, { 4.2, 19.6, -4.7, 0, 0, -8 }, { 200, 200, 200 })
	rodX(l, "WhiskerR2", 0.25, 6, { 4.2, 19, -4.7, 0, 0, 8 }, { 200, 200, 200 })
	wedge(l, "EarL", { 1.5, 3.5, 3 }, { -3.6, 24.6, -0.5 }, C.SAND_CAT)
	wedge(l, "EarR", { 1.5, 3.5, 3 }, { 3.6, 24.6, -0.5 }, C.SAND_CAT)
	drum(l, "Brim", 15, 1.2, { 0, 23.6, 0 }, C.TERRA_DK)
	drum(l, "Turret", 6, 5, { 0, 26.7, 0 }, C.CREAM)
	drum(l, "TurretGlass", 6.2, 1.2, { 0, 27.2, 0 }, C.GLASS)
	drum(l, "Cone1", 7, 1.2, { 0, 29.8, 0 }, C.TERRA)
	drum(l, "Cone2", 5.5, 1.2, { 0, 31, 0 }, C.TERRA_DK)
	drum(l, "Cone3", 4, 1.2, { 0, 32.2, 0 }, C.TERRA)
	drum(l, "Cone4", 2.5, 1.2, { 0, 33.4, 0 }, C.TERRA_DK)
	ball(l, "Tip", 1.2, { 0, 34.6, 0 }, C.CREAM)
	drum(l, "PipeUp", 1, 4, { 3.6, 26.8, 2.2 }, C.PIPE)
	rodX(l, "PipeElbow", 1, 2, { 3.2, 29, 2.2 }, C.PIPE)
	drum(l, "PipeTop", 1, 1.2, { 2.4, 29.6, 2.2 }, C.PIPE)
	return l
end

-- Toy park (sheets 02, 08, 17).
R.scratchCastle = function() -- Castillo Rascador Gigante [44]: stacked cardboard boxes, towers, ledges, felt roofs, flags
	local l = {}
	block(l, "BoxA", { 8, 6, 8 }, { -4, 3, 0 }, C.CARD, "solid", "Cardboard")
	block(l, "BoxB", { 6, 5, 6 }, { 5, 2.5, -3 }, C.CARD, "solid", "Cardboard")
	block(l, "ArchA", { 3, 3.6, 0.3 }, { -4, 1.8, -4.1 }, { 120, 85, 55 })
	block(l, "ArchB", { 3, 3.2, 0.3 }, { 5, 1.6, -6.1 }, { 120, 85, 55 })
	block(l, "TowerA", { 5, 8, 5 }, { -4.5, 10, 1 }, C.CARD_DK, "solid", "Cardboard")
	block(l, "RoomB", { 5, 5, 5 }, { 5, 7.5, -2.5 }, C.CARD, "solid", "Cardboard")
	block(l, "TowerC", { 6, 17, 6 }, { 2, 8.5, 4 }, C.CARD, "solid", "Cardboard")
	block(l, "RoomD", { 5, 4, 5 }, { 2, 19, 4 }, C.CARD_DK, "solid", "Cardboard")
	block(l, "MiddleTower", { 4, 6, 4 }, { -4.5, 17, 1 }, C.CARD, "solid", "Cardboard")
	block(l, "Ledge1", { 6, 0.6, 6 }, { 9.5, 7.3, -1.5 }, C.CARD_DK, "floor", "Cardboard")
	block(l, "Ledge2", { 6, 0.6, 6 }, { -8.5, 9, -2 }, C.CARD_DK, "floor", "Cardboard")
	block(l, "Ledge3", { 6, 0.6, 6 }, { 6.5, 13, 5 }, C.CARD_DK, "floor", "Cardboard")
	block(l, "Ledge4", { 6, 0.6, 6 }, { -8.5, 14, 4 }, C.CARD_DK, "floor", "Cardboard")
	drum(l, "Sisal1", 2, 4, { -7, 2, -5.5 }, C.SISAL, "decor", "Fabric")
	drum(l, "Sisal2", 2, 4, { 8.5, 2, 2 }, C.SISAL, "decor", "Fabric")
	drum(l, "Sisal3", 2, 4, { -1, 2, -6 }, C.SISAL, "decor", "Fabric")
	rodX(l, "TunnelA", 3.2, 6, { -4, 1.6, 5.5 }, C.PAW, "decor", "Fabric")
	rodZ(l, "TunnelB", 3.2, 6, { 10.6, 1.6, -5.5 }, C.PAW, "decor", "Fabric")
	wedge(l, "RampB", { 3, 4, 6 }, { 5, 2, -9 }, { 210, 170, 110 }, "floor", "Cardboard")
	wedge(l, "RampA", { 3, 4, 6 }, { -11, 2, 0, 0, 90, 0 }, { 210, 170, 110 }, "floor", "Cardboard")
	drum(l, "RoofDRing", 5.4, 0.6, { 2, 21.3, 4 }, C.CARD_DK)
	drum(l, "RoofDFelt1", 4.4, 1, { 2, 22.1, 4 }, { 165, 150, 140 }, "decor", "Fabric")
	drum(l, "RoofDFelt2", 2.6, 1, { 2, 23.1, 4 }, { 185, 170, 160 }, "decor", "Fabric")
	drum(l, "RoofMRing", 5.4, 0.6, { -4.5, 20.3, 1 }, C.CARD_DK)
	drum(l, "RoofMFelt1", 4.4, 1, { -4.5, 21.1, 1 }, { 165, 150, 140 }, "decor", "Fabric")
	drum(l, "RoofMFelt2", 2.6, 1, { -4.5, 22.1, 1 }, { 185, 170, 160 }, "decor", "Fabric")
	drum(l, "RoofBRing", 5.4, 0.6, { 5, 10.3, -2.5 }, C.CARD_DK)
	drum(l, "RoofBFelt1", 4.4, 1, { 5, 11.1, -2.5 }, { 165, 150, 140 }, "decor", "Fabric")
	drum(l, "RoofBFelt2", 2.6, 1, { 5, 12.1, -2.5 }, { 185, 170, 160 }, "decor", "Fabric")
	drum(l, "PoleD", 0.25, 3, { 2, 25.1, 4 }, C.WOOD_DK)
	wedge(l, "FlagD", { 0.15, 1.2, 1.8 }, { 2, 26, 5 }, C.PINK)
	drum(l, "PoleM", 0.25, 3, { -4.5, 24.1, 1 }, C.WOOD_DK)
	wedge(l, "FlagM", { 0.15, 1.2, 1.8 }, { -4.5, 25, 2 }, C.YEL)
	drum(l, "PoleB", 0.25, 3, { 5, 14.1, -2.5 }, C.WOOD_DK)
	wedge(l, "FlagB", { 0.15, 1.2, 1.8 }, { 5, 15, -1.5 }, C.PINK)
	block(l, "StringA", { 0.1, 3, 0.1 }, { -10.5, 7.5, -4 }, C.WHITE)
	ball(l, "PomponA", 1, { -10.5, 5.5, -4 }, C.YEL, "decor", "Fabric")
	block(l, "StringB", { 0.1, 3, 0.1 }, { 8.8, 11.5, 7 }, C.WHITE)
	ball(l, "PomponB", 1, { 8.8, 9.6, 7 }, C.YEL, "decor", "Fabric")
	wedge(l, "FeatherPink", { 0.2, 1.2, 2.4 }, { 10.5, 0.9, -9, 0, 30, 0 }, C.PINK)
	wedge(l, "FeatherMint", { 0.2, 1, 2 }, { 11.2, 0.8, -8.6, 0, 60, 0 }, C.MINT)
	oval(l, "Hammock", { 4, 1.2, 3 }, { 1, 4.2, -2.5 }, C.FELT, "decor", "Fabric")
	rodZ(l, "WindowC", 1.6, 0.3, { 2, 12, 0.85 }, { 120, 85, 55 })
	rodZ(l, "WindowD", 1.6, 0.3, { 2, 19, 1.35 }, { 120, 85, 55 })
	return l
end

-- the six staves of the tyre tunnel: a hexagon of radius 4.3 standing upright, its axis along Z
local function tyre(cx, cy, cz, degrees)
	local a = math.rad(degrees)
	return { cx + 4.3 * math.cos(a), cy + 4.3 * math.sin(a), cz, 0, 0, degrees + 90 }
end
R.scratchTree = function() -- Árbol Rascador [33]: a grassy island, a tall trunk with moss canopies, felt steps, toys
	local l = {}
	drum(l, "Island", 26, 0.4, { 0, 0.2, 0 }, C.GRASS_LT, "floor", "Grass")
	oval(l, "Pond", { 8, 0.3, 6 }, { 6, 0.45, -7 }, { 90, 190, 200 })
	drum(l, "Trunk", 3, 22.4, { 0, 11.6, 0 }, { 160, 115, 130 }, "solid", "Wood")
	rodX(l, "BranchE", 1.4, 7, { 3, 12, 0, 0, 0, 30 }, { 160, 115, 130 }, "decor", "Wood")
	rodX(l, "BranchW", 1.4, 7, { -3, 13, 1, 0, 0, -30 }, { 160, 115, 130 }, "decor", "Wood")
	drum(l, "Canopy1", 14, 0.8, { 0, 15, 0 }, { 150, 195, 90 }, "floor", "Grass")
	drum(l, "Canopy2", 11, 0.8, { 0, 23, 0 }, { 165, 210, 105 }, "floor", "Grass")
	drum(l, "Column1", 2.4, 4, { -7, 2.4, 4 }, { 180, 130, 220 }, "solid", "Fabric")
	drum(l, "Column2", 2.4, 7, { 6, 3.9, 5 }, { 180, 130, 220 }, "solid", "Fabric")
	drum(l, "Column3", 2.4, 10, { 8, 5.4, -4 }, { 180, 130, 220 }, "solid", "Fabric")
	drum(l, "Step1", 5, 0.5, { -7, 4.65, 4 }, { 200, 150, 235 }, "floor", "Fabric")
	drum(l, "Step2", 5, 0.5, { 6, 7.65, 5 }, { 200, 150, 235 }, "floor", "Fabric")
	drum(l, "Step3", 5, 0.5, { 8, 10.65, -4 }, { 200, 150, 235 }, "floor", "Fabric")
	block(l, "Tyre1", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 30), { 70, 65, 75 })
	block(l, "Tyre2", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 90), { 70, 65, 75 })
	block(l, "Tyre3", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 150), { 70, 65, 75 })
	block(l, "Tyre4", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 210), { 70, 65, 75 })
	block(l, "Tyre5", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 270), { 70, 65, 75 })
	block(l, "Tyre6", { 4.5, 0.9, 4 }, tyre(-6.5, 5.15, -7.5, 330), { 70, 65, 75 })
	block(l, "Hut", { 4, 4, 4 }, { 7, 2.4, 6 }, { 180, 130, 110 }, "solid", "Wood")
	wedge(l, "HutEarL", { 1, 1.4, 1 }, { 6, 5.1, 6 }, { 180, 130, 110 })
	wedge(l, "HutEarR", { 1, 1.4, 1 }, { 8, 5.1, 6 }, { 180, 130, 110 })
	block(l, "HutDoor", { 1.6, 2.4, 0.2 }, { 7, 1.6, 3.9 }, { 90, 60, 50 })
	block(l, "String1", { 0.1, 4, 0.1 }, { 5.5, 12.6, 0 }, C.WHITE)
	block(l, "String2", { 0.1, 4, 0.1 }, { -5.5, 12.6, 1 }, C.WHITE)
	block(l, "String3", { 0.1, 4, 0.1 }, { 0, 12.6, 5.5 }, C.WHITE)
	block(l, "String4", { 0.1, 4, 0.1 }, { 1, 12.6, -5.5 }, C.WHITE)
	drum(l, "DaisyPetals", 1.6, 0.2, { 10, 0.9, -2 }, C.WHITE)
	ball(l, "DaisyHeart", 0.6, { 10, 1, -2 }, C.YEL)
	oval(l, "Ladybug", { 1.4, 0.8, 1.6 }, { -3, 0.8, 9 }, { 220, 50, 50 })
	oval(l, "Bee", { 1.2, 1, 1.6 }, { 5.5, 10.4, 0 }, { 250, 210, 60 })
	oval(l, "Mushroom", { 2, 1.2, 2 }, { -10, 1.6, 3 }, { 220, 70, 70 })
	oval(l, "Rock", { 3, 2, 2.6 }, { 10.5, 1.2, 3 }, { 200, 185, 200 })
	return l
end

R.boxTower = function() -- Torre de Cajas Gatunas [21]: three stacked cat boxes with faces, striped tails and handles
	local l = {}
	block(l, "Box1", { 6, 3.5, 6 }, { 0, 1.75, 0 }, { 214, 180, 165 }, "solid", "Cardboard")
	block(l, "Box2", { 6, 3.5, 6 }, { 0, 5.25, 0 }, { 214, 180, 165 }, "solid", "Cardboard")
	block(l, "Box3", { 6, 3.5, 6 }, { 0, 8.75, 0 }, { 214, 180, 165 }, "solid", "Cardboard")
	block(l, "Band1", { 6.2, 0.35, 6.2 }, { 0, 3.5, 0 }, { 100, 60, 45 })
	block(l, "Band2", { 6.2, 0.35, 6.2 }, { 0, 7, 0 }, { 100, 60, 45 })
	block(l, "Band3", { 6.2, 0.35, 6.2 }, { 0, 10.5, 0 }, { 100, 60, 45 })
	block(l, "Face1EyeL", { 0.8, 0.3, 0.15 }, { -1.2, 2.15, -3.05 }, { 80, 50, 40 })
	block(l, "Face1EyeR", { 0.8, 0.3, 0.15 }, { 1.2, 2.15, -3.05 }, { 80, 50, 40 })
	block(l, "Face1Mouth", { 0.6, 0.4, 0.15 }, { 0, 1.35, -3.05 }, { 80, 50, 40 })
	block(l, "Face2EyeL", { 0.8, 0.3, 0.15 }, { -1.2, 5.65, -3.05 }, { 80, 50, 40 })
	block(l, "Face2EyeR", { 0.8, 0.3, 0.15 }, { 1.2, 5.65, -3.05 }, { 80, 50, 40 })
	block(l, "Face2Mouth", { 0.6, 0.4, 0.15 }, { 0, 4.85, -3.05 }, { 80, 50, 40 })
	block(l, "Face3EyeL", { 0.8, 0.3, 0.15 }, { -1.2, 9.15, -3.05 }, { 80, 50, 40 })
	block(l, "Face3EyeR", { 0.8, 0.3, 0.15 }, { 1.2, 9.15, -3.05 }, { 80, 50, 40 })
	block(l, "Face3Mouth", { 0.6, 0.4, 0.15 }, { 0, 8.35, -3.05 }, { 80, 50, 40 })
	oval(l, "Tail1", { 1, 3, 1 }, { 3.6, 1.6, 1, 0, 0, -30 }, { 130, 120, 120 })
	oval(l, "Tail1Stripe", { 1.1, 0.8, 1.1 }, { 4, 2.4, 1 }, { 80, 70, 70 })
	oval(l, "Tail2", { 1, 3, 1 }, { -3.6, 5.1, 1, 0, 0, 30 }, { 130, 120, 120 })
	oval(l, "Tail2Stripe", { 1.1, 0.8, 1.1 }, { -4, 5.9, 1 }, { 80, 70, 70 })
	block(l, "HandleL", { 0.4, 0.6, 1.6 }, { -1.6, 11, 0 }, { 100, 60, 45 })
	block(l, "HandleR", { 0.4, 0.6, 1.6 }, { 1.6, 11, 0 }, { 100, 60, 45 })
	return l
end

-- Toys (sheets 06, 18, 19; owner: "rollos de papel, hisopos, papel, bolsas").
R.yarn = function(v) -- Ovillo Gigante [7]: a fabric ball, three tilted bands and a loose strand on the grass
	local l = {}
	local y = YARN[v] or YARN.pink
	local d, r = y.d, y.d / 2
	ball(l, "Ball", d, { 0, r, 0 }, y.ball, "solid", "Fabric")
	rodX(l, "Band1", d + 0.4, 1.2, { 0, r, 0, 0, 0, 35 }, y.bands[1], "decor", "Fabric")
	rodX(l, "Band2", d + 0.4, 1.2, { 0, r, 0, 0, 60, 35 }, y.bands[2], "decor", "Fabric")
	rodX(l, "Band3", d + 0.4, 1.2, { 0, r, 0, 0, 120, 35 }, y.bands[3], "decor", "Fabric")
	oval(l, "Strand1", { 1.2, 0.9, 4.5 }, { r + 1.5, 0.45, -1, 0, 20, 0 }, y.ball, "decor", "Fabric")
	oval(l, "Strand2", { 1.2, 0.9, 4.5 }, { r + 3.5, 0.45, -4.5, 0, -25, 0 }, y.ball, "decor", "Fabric")
	oval(l, "Strand3", { 1.2, 0.9, 4.5 }, { r + 3, 0.45, -8.5, 0, 15, 0 }, y.ball, "decor", "Fabric")
	return l
end
R.yarnSmall = function(v) -- small yarn ball [2]
	local l = {}
	local y = YARN[v] or YARN.pink
	ball(l, "Ball", 5, { 0, 2.5, 0 }, y.ball, "decor", "Fabric")
	rodX(l, "Band", 5.3, 0.8, { 0, 2.5, 0, 0, 30, 35 }, y.bands[1], "decor", "Fabric")
	return l
end
R.rollStand = function() -- toilet roll, standing [4]
	local l = {}
	drum(l, "Roll", 8, 7, { 0, 3.5, 0 }, C.PAPER, "solid", "Fabric")
	drum(l, "Core", 3.4, 7.1, { 0, 3.55, 0 }, C.KRAFT, "decor", "Cardboard")
	drum(l, "Hole", 2.6, 7.2, { 0, 3.6, 0 }, { 110, 70, 45 })
	block(l, "Sheet", { 3.5, 6.6, 0.15 }, { 0, 3.3, -4.08 }, C.PAPER, "decor", "Fabric")
	return l
end
R.rollLying = function() -- toilet roll lying along X [4]; its unrolled tail is a ramp onto it from -Z
	local l = {}
	rodX(l, "Roll", 8, 7, { 0, 4, 0 }, C.PAPER, "solid", "Fabric")
	rodX(l, "Core", 3.4, 7.1, { 0, 4, 0 }, C.KRAFT, "decor", "Cardboard")
	rodX(l, "Hole", 2.6, 7.2, { 0, 4, 0 }, { 110, 70, 45 })
	wedge(l, "Tail", { 7, 4, 12 }, { 0, 2, -10 }, C.PAPER, "floor", "Fabric")
	return l
end
R.kitchen = function() -- kitchen roll [5]
	local l = {}
	drum(l, "Roll", 7, 12, { 0, 6, 0 }, C.PAPER, "solid", "Fabric")
	drum(l, "Core", 3, 12.1, { 0, 6.05, 0 }, C.KRAFT, "decor", "Cardboard")
	drum(l, "Hole", 2.3, 12.2, { 0, 6.1, 0 }, { 110, 70, 45 })
	drum(l, "PrintLow", 7.15, 0.6, { 0, 3, 0 }, { 247, 190, 215 })
	drum(l, "PrintHigh", 7.15, 0.6, { 0, 9, 0 }, { 247, 190, 215 })
	return l
end
-- one stave of the tube tunnel: an octagon of apothem 4.1 round an axis along X, the bottom side left open
local function stave(degrees)
	local a = math.rad(degrees)
	return { 0, 4.4 + 4.1 * math.sin(a), 4.1 * math.cos(a), 90 - degrees, 0, 0 }
end
R.tunnel = function() -- cardboard tube tunnel along X [7], about 7.6 across inside, open at the bottom
	local l = {}
	block(l, "Stave0", { 12, 0.6, 3.4 }, stave(0), C.KRAFT, "solid", "Cardboard")
	block(l, "Stave45", { 12, 0.6, 3.4 }, stave(45), C.KRAFT, "solid", "Cardboard")
	block(l, "Stave90", { 12, 0.6, 3.4 }, stave(90), C.KRAFT, "solid", "Cardboard")
	block(l, "Stave135", { 12, 0.6, 3.4 }, stave(135), C.KRAFT, "solid", "Cardboard")
	block(l, "Stave180", { 12, 0.6, 3.4 }, stave(180), C.KRAFT, "solid", "Cardboard")
	block(l, "Stave225", { 12, 0.6, 3.4 }, stave(225), { 190, 136, 92 }, "solid", "Cardboard")
	block(l, "Stave315", { 12, 0.6, 3.4 }, stave(315), { 190, 136, 92 }, "solid", "Cardboard")
	return l
end
R.tube = function() -- cardboard tube, standing [3]
	local l = {}
	drum(l, "Tube", 6, 10, { 0, 5, 0 }, C.KRAFT, "solid", "Cardboard")
	drum(l, "Inner", 4.6, 10.1, { 0, 5.05, 0 }, { 130, 85, 55 })
	block(l, "Seam", { 0.3, 11, 0.25 }, { 0, 5, -3, 0, 0, 25 }, { 185, 130, 90 })
	return l
end
R.bundle = function() -- tube bundle [4]: three tubes along X, stacked, tied with twine
	local l = {}
	rodX(l, "TubeLow1", 4, 8, { 0, 2, -2.05 }, C.KRAFT, "solid", "Cardboard")
	rodX(l, "TubeLow2", 4, 8, { 0, 2, 2.05 }, { 190, 136, 92 }, "solid", "Cardboard")
	rodX(l, "TubeTop", 4, 8, { 0, 5.5, 0 }, C.KRAFT, "solid", "Cardboard")
	rodX(l, "Twine", 8.6, 0.6, { 0, 3.3, 0 }, { 150, 100, 60 })
	return l
end
R.swab = function(v) -- giant cotton swab lying along X, a bench [3]
	local l = {}
	local tip = SWAB_TIPS[v] or C.COTTON
	rodX(l, "Stick", 1, 16, { 0, 1.2, 0 }, C.STICK)
	oval(l, "TipL", { 3.2, 2.4, 2.4 }, { -9.2, 1.4, 0 }, tip, "decor", "Fabric")
	oval(l, "TipR", { 3.2, 2.4, 2.4 }, { 9.2, 1.4, 0 }, tip, "decor", "Fabric")
	return l
end
R.swabCup = function() -- swab cup [10]: a peach cup with a paw and four standing swabs
	local l = {}
	drum(l, "Cup", 6, 5, { 0, 2.5, 0 }, { 245, 185, 140 }, "solid")
	rodZ(l, "Paw", 2.6, 0.2, { 0, 2.6, -3.05 }, { 235, 120, 110 })
	drum(l, "Stick1", 0.8, 9, { -1.2, 5.5, -1 }, C.STICK)
	oval(l, "Tip1", { 1.8, 2.4, 1.8 }, { -1.2, 10.6, -1 }, SWAB_TIPS.pink, "decor", "Fabric")
	drum(l, "Stick2", 0.8, 9, { 1.2, 5.5, -1 }, C.STICK)
	oval(l, "Tip2", { 1.8, 2.4, 1.8 }, { 1.2, 10.6, -1 }, SWAB_TIPS.blue, "decor", "Fabric")
	drum(l, "Stick3", 0.8, 9, { -1, 5.5, 1.2 }, C.STICK)
	oval(l, "Tip3", { 1.8, 2.4, 1.8 }, { -1, 10.6, 1.2 }, SWAB_TIPS.mint, "decor", "Fabric")
	drum(l, "Stick4", 0.8, 9, { 1.1, 5.5, 1.1 }, C.STICK)
	oval(l, "Tip4", { 1.8, 2.4, 1.8 }, { 1.1, 10.6, 1.1 }, C.COTTON, "decor", "Fabric")
	return l
end
R.swabCross = function() -- two lying swabs crossed at 60 degrees [6]
	local l = {}
	rodX(l, "StickA", 1, 16, { 0, 1.2, 0, 0, 30, 0 }, C.STICK)
	oval(l, "TipA1", { 3.2, 2.4, 2.4 }, { 7.97, 1.4, -4.6, 0, 30, 0 }, SWAB_TIPS.pink, "decor", "Fabric")
	oval(l, "TipA2", { 3.2, 2.4, 2.4 }, { -7.97, 1.4, 4.6, 0, 30, 0 }, SWAB_TIPS.pink, "decor", "Fabric")
	rodX(l, "StickB", 1, 16, { 0, 2.2, 0, 0, -30, 0 }, C.STICK)
	oval(l, "TipB1", { 3.2, 2.4, 2.4 }, { 7.97, 2.4, 4.6, 0, -30, 0 }, SWAB_TIPS.blue, "decor", "Fabric")
	oval(l, "TipB2", { 3.2, 2.4, 2.4 }, { -7.97, 2.4, -4.6, 0, -30, 0 }, SWAB_TIPS.blue, "decor", "Fabric")
	return l
end
R.paperBall = function() -- crumpled paper ball [2]: a ball with a turned cube poking through
	local l = {}
	ball(l, "Ball", 4, { 0, 2, 0 }, { 245, 243, 236 }, "decor", "Fabric")
	block(l, "Crumple", { 3, 3, 3 }, { 0, 2, 0, 35, 45, 20 }, { 235, 232, 225 }, "decor", "Fabric")
	return l
end
R.sheet = function() -- flat paper sheet [1]
	local l = {}
	block(l, "Sheet", { 8, 0.15, 10 }, { 0, 0.08, 0 }, C.PAPER, "decor", "Fabric")
	return l
end
R.tent = function() -- folded paper tent [2]
	local l = {}
	block(l, "HalfNorth", { 8, 0.15, 5.5 }, { 0, 2.25, 1.58, 55, 0, 0 }, C.PAPER, "decor", "Fabric")
	block(l, "HalfSouth", { 8, 0.15, 5.5 }, { 0, 2.25, -1.58, -55, 0, 0 }, C.PAPER, "decor", "Fabric")
	return l
end
R.notebook = function() -- notebook sheet with three blue lines [4]
	local l = {}
	block(l, "Sheet", { 8, 0.15, 10 }, { 0, 0.08, 0 }, C.PAPER, "decor", "Fabric")
	block(l, "Line1", { 7, 0.05, 0.25 }, { 0, 0.18, -2.5 }, { 150, 190, 230 })
	block(l, "Line2", { 7, 0.05, 0.25 }, { 0, 0.18, 0 }, { 150, 190, 230 })
	block(l, "Line3", { 7, 0.05, 0.25 }, { 0, 0.18, 2.5 }, { 150, 190, 230 })
	return l
end
R.paperBag = function() -- kraft paper bag [6]: body, folded band, a three-part handle, a pink paw
	local l = {}
	block(l, "Body", { 6, 8, 4 }, { 0, 4, 0 }, { 205, 160, 110 }, "solid", "Cardboard")
	block(l, "Fold", { 6.1, 1, 4.1 }, { 0, 7.6, 0 }, { 185, 140, 95 }, "decor", "Cardboard")
	block(l, "HandleL", { 0.3, 2, 0.3 }, { -1.4, 9, 0 }, { 150, 100, 60 })
	block(l, "HandleR", { 0.3, 2, 0.3 }, { 1.4, 9, 0 }, { 150, 100, 60 })
	block(l, "HandleTop", { 3.1, 0.3, 0.3 }, { 0, 10, 0 }, { 150, 100, 60 })
	rodZ(l, "Paw", 2, 0.1, { 0, 4.2, -2.05 }, { 240, 140, 170 })
	return l
end
R.plasticBag = function(v) -- pastel plastic bag [3], a little see-through
	local l = {}
	local tint = BAG_TINTS[v] or BAG_TINTS.blue
	oval(l, "Body", { 6, 7, 4 }, { 0, 3.5, 0 }, tint, "decor", nil, { transparency = 0.15 })
	add(l, "LoopL", "Cylinder", { 0.3, 2.2, 2.2 }, { -1.2, 7.4, 0 }, tint, "decor", nil, { transparency = 0.15 })
	add(l, "LoopR", "Cylinder", { 0.3, 2.2, 2.2 }, { 1.2, 7.4, 0 }, tint, "decor", nil, { transparency = 0.15 })
	return l
end
R.giantBag = function() -- giant fallen bag, a hideout [5]: open toward -Z, inside about 9.4 x 7.4 x 13.4
	local l = {}
	block(l, "Roof", { 10, 0.6, 14 }, { 0, 8, 0 }, { 205, 160, 110 }, "solid", "Cardboard")
	block(l, "WallL", { 0.6, 8, 14 }, { -5, 4, 0 }, { 205, 160, 110 }, "solid", "Cardboard")
	block(l, "WallR", { 0.6, 8, 14 }, { 5, 4, 0 }, { 195, 150, 100 }, "solid", "Cardboard")
	block(l, "Back", { 10, 8, 0.6 }, { 0, 4, 7 }, { 195, 150, 100 }, "solid", "Cardboard")
	block(l, "Handle", { 4, 0.4, 0.4 }, { 0, 8.5, -1 }, { 150, 100, 60 })
	return l
end

-- Cofre Gatuno [11] beside each nest (sheet 16): a pink cat chest, its lid open 55 degrees toward the nest (-Z), with
-- ears, a wink and teeth on the lid; only the base is solid.
R.chest = function()
	local l = {}
	block(l, "Base", { 7, 2.8, 4.6 }, { 0, 1.4, 0 }, { 240, 120, 160 }, "solid")
	oval(l, "Lid", { 7, 2.6, 4.6 }, { 0, 4.684, 0.981, 55, 0, 0 }, { 245, 145, 180 })
	block(l, "GoldRim", { 7.2, 0.4, 4.8 }, { 0, 2.6, 0 }, { 245, 180, 70 })
	rodZ(l, "Lock", 1.6, 0.3, { 0, 1.6, -2.4 }, { 245, 180, 70 })
	block(l, "Keyhole", { 0.3, 0.7, 0.1 }, { 0, 1.5, -2.58 }, { 110, 60, 40 })
	wedge(l, "EarL", { 1.2, 1.4, 1 }, { -2.4, 5.11, 2.64, 55, 0, 0 }, { 245, 145, 180 })
	wedge(l, "EarR", { 1.2, 1.4, 1 }, { 2.4, 5.11, 2.64, 55, 0, 0 }, { 245, 145, 180 })
	oval(l, "Eye", { 0.7, 0.9, 0.2 }, { -1.5, 6.69, 0.19, 55, 0, 0 }, { 150, 40, 70 })
	block(l, "Wink", { 0.9, 0.2, 0.2 }, { 1.5, 6.69, 0.19, 55, 0, 0 }, { 150, 40, 70 })
	wedge(l, "ToothL", { 0.7, 0.8, 0.4 }, { -1.4, 6.14, -0.77, 235, 0, 0 }, C.WHITE)
	wedge(l, "ToothR", { 0.7, 0.8, 0.4 }, { 1.4, 6.14, -0.77, 235, 0, 0 }, C.WHITE)
	return l
end

-- Trees, bushes and lanterns (the master photo: pink blossom trees, flower and bell lanterns).
R.treeL = function() -- pink tree, large, about 22 tall [6]
	local l = {}
	drum(l, "Trunk", 2.4, 12, { 0, 6, 0 }, C.TRUNK, "solid", "Wood")
	drum(l, "Flare", 3.6, 1.2, { 0, 0.6, 0 }, { 120, 82, 58 }, "decor", "Wood")
	oval(l, "Crown1", { 14, 10, 14 }, { 0, 15, 0 }, C.BLOSSOM)
	oval(l, "Crown2", { 9, 7, 9 }, { 5, 12, 3 }, C.BLOSSOM_DK)
	oval(l, "Crown3", { 8, 6, 8 }, { -5, 13, -3 }, C.BLOSSOM)
	oval(l, "Crown4", { 7, 5, 7 }, { 1, 19.5, 1 }, C.PETAL_LT)
	return l
end
R.treeS = function() -- pink tree, small, about 14 tall [4]
	local l = {}
	drum(l, "Trunk", 1.6, 7, { 0, 3.5, 0 }, C.TRUNK, "solid", "Wood")
	oval(l, "Crown1", { 9, 7, 9 }, { 0, 9.5, 0 }, C.BLOSSOM)
	oval(l, "Crown2", { 6, 5, 6 }, { 3, 8, 2 }, C.BLOSSOM_DK)
	oval(l, "Crown3", { 5, 4, 5 }, { -1, 12.5, 0 }, C.PETAL_LT)
	return l
end
R.bush = function() -- bush [2]
	local l = {}
	oval(l, "Bush", { 6, 4, 6 }, { 0, 2, 0 }, C.GRASS_DK, "decor", "Grass")
	oval(l, "Top", { 4, 3, 4 }, { 1.5, 3, 1 }, C.GRASS_LT, "decor", "Grass")
	return l
end
R.lanternTall = function() -- tall bell lantern, 12 tall [5]: a green stem, an arm over the path, a pink bell, a lit bulb
	local l = {}
	drum(l, "Foot", 1.6, 0.4, { 0, 0.2, 0 }, { 110, 74, 52 })
	drum(l, "Stem", 0.6, 11, { 0, 5.9, 0 }, C.STEM, "solid")
	block(l, "Arm", { 0.5, 0.5, 3.2 }, { 0, 10.6, -1.39, -30, 0, 0 }, C.STEM)
	oval(l, "Bell", { 2.6, 1.6, 2.6 }, { 0, 9.6, -2.9 }, C.BLOSSOM_DK)
	drum(l, "Bulb", 1.3, 1.4, { 0, 8.6, -2.9 }, C.LIGHT, "decor", "Neon", { light = { range = 14, brightness = 1, color = C.LIGHT } })
	return l
end
R.lanternShort = function(lit) -- short flower lantern, 6.5 tall [5]; the Tower Plaza ones ("light") carry a light
	local l = {}
	drum(l, "Foot", 1.6, 0.5, { 0, 0.25, 0 }, { 70, 50, 45 })
	block(l, "Post", { 0.6, 3.4, 0.6 }, { 0, 2.2, 0 }, { 95, 62, 48 }, "solid")
	block(l, "Lamp", { 1.6, 2, 1.6 }, { 0, 4.9, 0 }, C.LIGHT, "decor", "Neon",
		lit == "light" and { light = { range = 14, brightness = 1, color = C.LIGHT } } or nil)
	oval(l, "PetalRoof", { 4, 0.6, 4 }, { 0, 6.1, 0 }, { 248, 214, 228 })
	ball(l, "Cap", 0.6, { 0, 6.5, 0 }, C.BLOSSOM_DK)
	return l
end

-- Scatter (decor; the drop rules apply).
R.patch = function(v) -- ground patch [1]: a flattened oval, darker or lighter grass
	local l = {}
	oval(l, "Patch", { 30, 0.12, 20 }, { 0, 0.03, 0 }, v == 2 and C.GRASS_LT or C.GRASS_DK, "decor", "Grass")
	return l
end
R.flower = function(v) -- flower cluster [3]: a leafy base and two flat flower heads
	local l = {}
	local heads = FLOWER_HEADS[tonumber(v) or 1] or FLOWER_HEADS[1]
	oval(l, "Leaves", { 3, 0.3, 3 }, { 0, 0.15, 0 }, C.GRASS_DK, "decor", "Grass")
	drum(l, "HeadA", 1.4, 0.25, { 0.6, 0.45, 0.4 }, heads[1])
	drum(l, "HeadB", 1.4, 0.25, { -0.6, 0.45, -0.4 }, heads[2])
	return l
end
R.tuft = function() -- grass tuft [2]: two crossed blades
	local l = {}
	wedge(l, "BladeA", { 0.15, 1.4, 0.9 }, { 0, 0.7, 0 }, C.GRASS_DK, "decor", "Grass")
	wedge(l, "BladeB", { 0.15, 1.4, 0.9 }, { 0, 0.7, 0, 0, 90, 0 }, C.GRASS_DK, "decor", "Grass")
	return l
end

-- GL-D5: the edge border (decor; laid by buildEdge, outside the drop rules).
R.hedge = function(length) -- hedge puff [2]: a long low grass oval and a lighter top, along local X
	local l = {}
	local L = tonumber(length) or 30
	oval(l, "Puff", { L, 5, 8 }, { 0, 2.5, 0 }, C.GRASS_DK, "decor", "Grass")
	oval(l, "Top", { L * 0.6, 3.5, 5.5 }, { 0, 4.6, 0.5 }, C.GRASS_LT, "decor", "Grass")
	return l
end

-- Every kind, for the suite.
Park.KINDS = {}
for kind in pairs(R) do table.insert(Park.KINDS, kind) end
table.sort(Park.KINDS)
freeze(Park.KINDS)

-- recipe(kind, variant) -> { { name, shape, size = { x, y, z }, offset = { x, y, z, rx, ry, rz }, color = { r, g, b },
-- material, role, mesh?, transparency?, light?, text? } }: one item as plain parts local to its pivot (its ground
-- centre at the floor's top, front toward -Z; angles in degrees, applied as CFrame.Angles). shape is Block, Ball,
-- Cylinder (axis along X) or Wedge; mesh "Sphere" makes the part an oval of its size. Names are unique in a recipe.
-- Pure; a fresh table every call.
function Park.recipe(kind, variant)
	local make = R[kind]
	assert(make, "unknown park kind: " .. tostring(kind))
	local list = make(variant)
	local seen = {}
	for _, spec in ipairs(list) do
		local n = (seen[spec.name] or 0) + 1
		seen[spec.name] = n
		if n > 1 then spec.name ..= tostring(n) end
	end
	return list
end

-- Flat geometry -----------------------------------------------------------------------------------------------------

local function flat(ax, az, bx, bz)
	return math.sqrt((ax - bx) ^ 2 + (az - bz) ^ 2)
end
-- the distance from (x, z) to the segment a-b, and the closest point on it
local function segment(x, z, a, b)
	local dx, dz = b.x - a.x, b.z - a.z
	local l2 = dx * dx + dz * dz
	local t = l2 > 0 and math.clamp(((x - a.x) * dx + (z - a.z) * dz) / l2, 0, 1) or 0
	local cx, cz = a.x + t * dx, a.z + t * dz
	return flat(x, z, cx, cz), cx, cz
end
-- the distance from (x, z) to a path's centre line, and the closest point on it
local function pathDistance(path, x, z)
	local best, bx, bz = math.huge, nil, nil
	for i = 1, #path.points - 1 do
		local d, cx, cz = segment(x, z, path.points[i], path.points[i + 1])
		if d < best then best, bx, bz = d, cx, cz end
	end
	return best, bx, bz
end
Park.pathDistance = pathDistance
local function length(points)
	local total = 0
	for i = 1, #points - 1 do total += flat(points[i].x, points[i].z, points[i + 1].x, points[i + 1].z) end
	return total
end
-- the point s studs along a polyline, and its leg's direction (unit)
local function along(points, s)
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local leg = flat(a.x, a.z, b.x, b.z)
		if s <= leg or i == #points - 1 then
			local t = leg > 0 and math.clamp(s / leg, 0, 1) or 0
			return a.x + (b.x - a.x) * t, a.z + (b.z - a.z) * t, (b.x - a.x) / leg, (b.z - a.z) / leg
		end
		s -= leg
	end
	return points[1].x, points[1].z, 1, 0
end
-- the yaw (degrees) that turns local +Z along (dx, dz)
local function yawAlong(dx, dz)
	return math.deg(math.atan2(dx, dz))
end
-- the yaw (degrees) that turns the front (local -Z) from (x, z) toward (tx, tz)
local function yawToward(x, z, tx, tz)
	return math.deg(math.atan2(-(tx - x), -(tz - z)))
end
Park.yawToward = yawToward
local function round(n, places)
	local m = 10 ^ (places or 3)
	return math.floor(n * m + 0.5) / m
end

local function layout(L)
	if type(L) == "table" then return L end
	return require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyLayout"))
end
local function eastModule(E)
	if type(E) == "table" then return E end
	return require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyEast"))
end

-- plan(L, East, options) -> the park in world studs (PGM-D4: the frame is Area's; L and East stay in the signature,
-- unused):
--   centre, space, floorTop          Area.ORIGIN (282, 600), Area.rect() (x 22..542, z 340..1460), Area.FLOOR_TOP 0.5
--   gate = { x, z, width }           the Arco de Nubes (world (282, 346), local (-254, 0)) and its 14-stud gap
--   paths = { { id, width, main, points = { { x, z } } } }   the main path M and the six forks (K-D16, Appendix A), then
--                                    the garden's M2, GN, GS, GT and GV (GL-D7)
--   items = { { id, kind, folder, x, z, yaw, variant? } }   every kept item (world yaw in degrees; 0 = front toward world
--                                    -z): a yaw from the local tables is turned by Area.worldYaw, a yaw computed from world
--                                    points (along a path, toward a nest or a path, seeded) is already a world yaw
--   dropped = { { id, kind, folder, x, z, reason, parts } }  the items the drop rules removed (K-D16)
--   budget = { [folder] = parts }, parts = the Park total; nests = Park.NESTS, portal, portal2, arrival
-- options.garden == false leaves the GARDEN rows out (a suite-only switch, GL-3); build() and the tools pass none.
-- GL-D6: in every category the LOCAL rows come first and draw from Random.new(Park.SEED) in the same order as before the
-- garden, then the GARDEN rows draw from Random.new(Park.GARDEN_SEED), so no K-D item moves. The turn keeps every
-- distance, so the K-D drops are the K-D ones and the garden drops none: K-D18 + GARDEN_BUDGET - 14 = 2589 parts.
-- Deterministic; pure.
function Park.plan(L, East, options)
	local cx, cz, top = Area.ORIGIN.x, Area.ORIGIN.z, Area.FLOOR_TOP
	local rng = Random.new(Park.SEED)
	local grow = Random.new(Park.GARDEN_SEED)
	local world = Area.world
	-- the row sets in plan order, each with its generator; tag goes into the garden's generated ids (TreeL_G01, ...)
	local sets = { { rows = LOCAL, gen = rng, tag = "" } }
	if not (type(options) == "table" and options.garden == false) then
		table.insert(sets, { rows = GARDEN, gen = grow, tag = "G" })
	end
	local items, kept, dropped = {}, {}, {}
	local function item(id, kind, folder, x, z, yaw, variant)
		table.insert(items, { id = id, kind = kind, folder = folder, x = x, z = z, yaw = yaw or 0, variant = variant })
	end
	local function seeded(gen) return gen:NextInteger(0, 359) end

	-- paths (world points): the K-D ones, then the garden's (so the drop rule and the lanterns' facing see them all)
	local paths, pathGen, stones = {}, {}, 0
	for _, set in ipairs(sets) do
		for _, p in ipairs(set.rows.paths) do
			local points = {}
			for i, q in ipairs(p.points) do
				local x, z = world(q[1], q[2])
				points[i] = freeze({ x = x, z = z })
			end
			local path = freeze({ id = p.id, width = p.width, main = p.main == true, points = freeze(points) })
			table.insert(paths, path)
			pathGen[path] = set.gen
		end
	end
	for _, path in ipairs(paths) do
		local pts = path.points
		local gen = pathGen[path]
		if path.main then
			-- a sand strip per leg, a joint disc per bend, a slab every 5 studs alternating +-2.5 across the path
			for i = 1, #pts - 1 do
				local a, b = pts[i], pts[i + 1]
				local leg = flat(a.x, a.z, b.x, b.z)
				item(("Path_%s_Strip%d"):format(path.id, i), "strip", "Paths", (a.x + b.x) / 2, (a.z + b.z) / 2,
					yawAlong(b.x - a.x, b.z - a.z), round(leg, 4))
			end
			for i = 2, #pts - 1 do
				item(("Path_%s_Joint%d"):format(path.id, i - 1), "joint", "Paths", pts[i].x, pts[i].z, 0)
			end
			local total, k = length(pts), 0
			local s = 2.5
			while s <= total do
				k += 1
				local x, z, dx, dz = along(pts, s)
				local across = (k % 2 == 1) and 2.5 or -2.5
				item(("Path_%s_Slab%03d"):format(path.id, k), "slab", "Paths", x - dz * across, z + dx * across,
					yawAlong(dx, dz) + gen:NextNumber(-18, 18), k)
				s += 5
			end
		else
			-- stepping stones: round(length / 7) of them, evenly spaced, jittered +-1 along and across
			local total = length(pts)
			local n = math.max(1, math.floor(total / 7 + 0.5))
			local step = total / n
			for i = 1, n do
				local x, z, dx, dz = along(pts, (i - 0.5) * step)
				local on, off = gen:NextNumber(-1, 1), gen:NextNumber(-1, 1)
				stones += 1
				item(("Path_%s_Stone%02d"):format(path.id, i), "stone", "Paths", x + dx * on - dz * off, z + dz * on + dx * off,
					yawAlong(dx, dz) + gen:NextNumber(-25, 25), stones)
			end
		end
	end
	for _, set in ipairs(sets) do
		for _, j in ipairs(set.rows.junctions) do
			local x, z = world(j.x, j.z)
			item("Junction_" .. j.id, "junction", "Paths", x, z, 0, j.d)
		end
	end
	-- the gate
	local gx, gz = world(LOCAL.arch.x, LOCAL.arch.z)
	item("ArcoDeNubes", "arch", "Gate", gx, gz, Area.worldYaw(0)) -- PGM-D4: local yaw 0, the pillars across the gate's axis
	-- the village and the toy park
	for _, set in ipairs(sets) do
		for _, b in ipairs(set.rows.buildings) do
			local x, z = world(b.x, b.z)
			item(b.id, b.kind, b.folder, x, z, Area.worldYaw(b.yaw))
		end
	end
	-- toys
	for _, set in ipairs(sets) do
		for _, t in ipairs(set.rows.toys) do
			local x, z = world(t[3], t[4])
			local yaw = t[5]
			if yaw == nil then yaw = seeded(set.gen) else yaw = Area.worldYaw(yaw) end
			item(t[1], t[2], "Toys", x, z, yaw, t[6])
		end
	end
	-- chests: at the K-D8 (GL-D10) chest points, the front (and the open lid) toward the nest
	for _, n in ipairs(Park.NESTS) do
		item("Chest_" .. n.id, "chest", "Chests", n.chest.x, n.chest.z, round(yawToward(n.chest.x, n.chest.z, n.x, n.z), 4))
	end
	-- trees and bushes
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.treesL) do
			local x, z = world(q[1], q[2])
			item(("TreeL_%s%02d"):format(set.tag, i), "treeL", "Trees", x, z, seeded(set.gen))
		end
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.treesS) do
			local x, z = world(q[1], q[2])
			item(("TreeS_%s%02d"):format(set.tag, i), "treeS", "Trees", x, z, seeded(set.gen))
		end
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.bushes) do
			local x, z = world(q[1], q[2])
			item(("Bush_%s%02d"):format(set.tag, i), "bush", "Trees", x, z, seeded(set.gen))
		end
	end
	-- lanterns: each faces the nearest path point (the tall ones hang their bell over the path)
	local function facing(x, z)
		local best, bx, bz = math.huge, x, z - 1
		for _, path in ipairs(paths) do
			local d, px, pz = pathDistance(path, x, z)
			if d < best and d > 1e-6 then best, bx, bz = d, px, pz end
		end
		return round(yawToward(x, z, bx, bz), 4)
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.lanternsTall) do
			local x, z = world(q[1], q[2])
			item(("LanternTall_%s%d"):format(set.tag, i), "lanternTall", "Lanterns", x, z, facing(x, z))
		end
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.lanternsShort) do
			local x, z = world(q[1], q[2])
			item(("LanternShort_%s%02d"):format(set.tag, i), "lanternShort", "Lanterns", x, z, facing(x, z), q[3] and "light" or nil)
		end
	end
	-- scatter (a patch's and a flower's variant by its own index in its set)
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.patches) do
			local x, z = world(q[1], q[2])
			item(("Patch_%s%02d"):format(set.tag, i), "patch", "Scatter", x, z, seeded(set.gen), (i % 2) + 1)
		end
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.flowers) do
			local x, z = world(q[1], q[2])
			item(("Flower_%s%02d"):format(set.tag, i), "flower", "Scatter", x, z, seeded(set.gen), (i - 1) % 3 + 1)
		end
	end
	for _, set in ipairs(sets) do
		for i, q in ipairs(set.rows.tufts) do
			local x, z = world(q[1], q[2])
			item(("Tuft_%s%02d"):format(set.tag, i), "tuft", "Scatter", x, z, seeded(set.gen))
		end
	end

	-- K-D16 drop rules
	local CL = Park.CLEAR
	local function reason(it)
		if it.folder == "Paths" or it.folder == "Gate" or it.folder == "Chests" then return nil end
		local reach = Park.REACH[it.kind] or 0
		for _, n in ipairs(Park.NESTS) do
			for _, spot in ipairs({ { n.x, n.z, "nest" }, { n.post.x, n.post.z, "post" }, { n.chest.x, n.chest.z, "chest" } }) do
				if flat(it.x, it.z, spot[1], spot[2]) - reach < CL.nest then return ("by %s %s"):format(spot[3], n.id) end
			end
		end
		if flat(it.x, it.z, Park.PORTAL.x, Park.PORTAL.z) < CL.portal then return "by the portal" end
		if flat(it.x, it.z, Park.PORTAL2.x, Park.PORTAL2.z) < CL.portal then return "by the second portal" end -- GL-D13
		if flat(it.x, it.z, Park.ARRIVAL.x, Park.ARRIVAL.z) < Park.ARRIVAL.r then return "in the arrival disc" end
		if it.folder ~= "Lanterns" then
			for _, path in ipairs(paths) do
				if pathDistance(path, it.x, it.z) < CL.path + path.width / 2 then return "on path " .. path.id end
			end
		end
		return nil
	end
	local budget, total = {}, 0
	for _, folder in ipairs(Park.FOLDERS) do budget[folder] = 0 end
	for _, it in ipairs(items) do
		local n = #Park.recipe(it.kind, it.variant)
		local why = reason(it)
		if why then
			table.insert(dropped, { id = it.id, kind = it.kind, folder = it.folder, x = it.x, z = it.z, reason = why, parts = n })
		else
			table.insert(kept, it)
			budget[it.folder] += n
			total += n
		end
	end
	return {
		centre = { x = cx, z = cz }, space = Area.rect(), floorTop = top,
		gate = { x = gx, z = gz, width = 14 }, -- PGM-D4: the K-D1 gap, no longer East.GATE (PGM-D5 drops it)
		paths = paths, items = kept, dropped = dropped, budget = budget, parts = total,
		nests = Park.NESTS, portal = Park.PORTAL, portal2 = Park.PORTAL2, arrival = Park.ARRIVAL,
	}
end

-- Instances ---------------------------------------------------------------------------------------------------------

local function forbidden(instance)
	return typeof(instance) == "Instance" and (instance.Name == Park.FORBIDDEN or instance:FindFirstAncestor(Park.FORBIDDEN) ~= nil)
end
Park.forbidden = forbidden

local function rgb(c) return Color3.fromRGB(c[1], c[2], c[3]) end
local SHAPES = { Block = Enum.PartType.Block, Ball = Enum.PartType.Ball, Cylinder = Enum.PartType.Cylinder,
	Wedge = Enum.PartType.Wedge }
local function material(name)
	local ok, value = pcall(function() return Enum.Material[name] end)
	return ok and value or Enum.Material.SmoothPlastic
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
-- Sets every key of `props` that differs; returns how many were set.
local function apply(instance, props)
	local changed = 0
	for key, value in pairs(props) do
		if not same(instance[key], value) then
			instance[key] = value
			changed += 1
		end
	end
	return changed
end
local function attribute(instance, key, value)
	if instance:GetAttribute(key) ~= value then
		instance:SetAttribute(key, value)
		return 1
	end
	return 0
end
-- An existing child of that name and class, or a new one; errors when the name holds another class.
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

-- One part to its spec at `pivot`; counts what it made and changed into report (a new instance counts once).
local function conform(part, spec, pivot, report, isNew)
	local o = spec.offset
	local cf = pivot * CFrame.new(o[1], o[2], o[3]) * CFrame.Angles(math.rad(o[4]), math.rad(o[5]), math.rad(o[6]))
	local solid = spec.role == "floor" or spec.role == "solid"
	local s = spec.size
	local biggest = math.max(s[1], s[2], s[3])
	local n = apply(part, { Anchored = true, Shape = SHAPES[spec.shape] or Enum.PartType.Block })
	n += apply(part, {
		Size = Vector3.new(s[1], s[2], s[3]), CFrame = cf, Color = rgb(spec.color), Material = material(spec.material),
		Transparency = spec.transparency or 0, CanCollide = solid, CanQuery = solid, CanTouch = false,
		-- GL-D4: a spec may set its shadow (the invisible edge walls cast none)
		CastShadow = if spec.castShadow ~= nil then spec.castShadow else (spec.role ~= "floor" and biggest >= 2),
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	n += attribute(part, "Role", spec.role)
	if spec.mesh == "Sphere" then
		local mesh, made = child(part, "SpecialMesh", "Mesh")
		local m = apply(mesh, { MeshType = Enum.MeshType.Sphere, Scale = Vector3.new(1, 1, 1) })
		if made then report.created += 1 else n += m end
	end
	if spec.light then
		local light, made = child(part, "PointLight", "Light")
		local m = apply(light, { Range = spec.light.range, Brightness = spec.light.brightness, Color = rgb(spec.light.color),
			Shadows = false })
		if made then report.created += 1 else n += m end
	end
	if spec.text then
		for _, face in ipairs(spec.text.faces) do
			local gui, madeGui = child(part, "SurfaceGui", "Sign" .. face)
			local m = apply(gui, { Face = Enum.NormalId[face], SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
				PixelsPerStud = 40, LightInfluence = 0 })
			if madeGui then report.created += 1 else n += m end
			local label, madeLabel = child(gui, "TextLabel", "Label")
			local k = apply(label, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = spec.text.text,
				TextScaled = true, TextWrapped = true, Font = Enum.Font.FredokaOne, TextColor3 = rgb(spec.text.color) })
			if madeLabel then report.created += 1 else n += k end
		end
	end
	if isNew then report.created += 1 else report.changed += n end
end

-- One ground part of root.Ground: a Part of role floor in Park.FLOOR's colour, material and MaterialVariant (TB-1),
-- size s (world axes), centred on (x, z) with its top at Area.FLOOR_TOP; anchored, it collides and answers queries, is
-- never touched and casts a shadow. Counts into report like conform.
local function groundPart(ground, name, s, x, z, report)
	local part, made = child(ground, "Part", name)
	local n = apply(part, { Anchored = true, Shape = Enum.PartType.Block })
	n += apply(part, {
		Size = Vector3.new(s[1], s[2], s[3]), CFrame = CFrame.new(x, Area.FLOOR_TOP - s[2] / 2, z),
		Color = rgb(Park.FLOOR.color), Material = material(Park.FLOOR.material), Transparency = 0, CanCollide = true,
		CanQuery = true, CanTouch = false, CastShadow = true, TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
	})
	-- TB-1: the variant after the material (set on its own, so a material change can never clear it afterwards)
	n += apply(part, { MaterialVariant = Park.FLOOR.variant })
	n += attribute(part, "Role", "floor")
	if made then report.created += 1 else report.changed += n end
end

-- buildGround(root) -> report { created, changed } (PGM-D2, GL-D3): the park's own ground (root is
-- Workspace.PuebloGatito_v1 on the live map, any Instance in a suite): root.Ground.Floor, Park.FLOOR's size centred on
-- Park.FLOOR.centre (the whole arm, 600 x 1200 at (297, 937); the live 520 x 520 floor is conformed in place), and
-- root.Ground.Approach, the Park.APPROACH slab (20 x 1 x 13 at (282, 330.5)) from the big4 road's end to the arm; both
-- with their tops at Area.FLOOR_TOP. Idempotent like build (a second call reports created 0 and changed 0); refuses
-- SistemaSonriente.
function Park.buildGround(root)
	assert(typeof(root) == "Instance", "root must be an Instance")
	assert(not forbidden(root), "refusing to touch " .. Park.FORBIDDEN)
	local report = { created = 0, changed = 0 }
	local ground, madeGround = child(root, "Folder", Park.GROUND_FOLDER)
	if madeGround then report.created += 1 end
	groundPart(ground, "Floor", Park.FLOOR.size, Park.FLOOR.centre.x, Park.FLOOR.centre.z, report)
	local P = Park.APPROACH
	groundPart(ground, "Approach", { P.maxX - P.minX, Park.FLOOR.size[2], P.maxZ - P.minZ }, (P.minX + P.maxX) / 2,
		(P.minZ + P.maxZ) / 2, report)
	return report
end

-- One planned item { id, kind, x, z, yaw, variant } into folder at the floor's top: an item of one part is a Part named
-- by its id, a bigger one a Model of its recipe's parts (WorldPivot on its ground centre); both carry Kind. Conforms or
-- creates, counting into report; returns the item's part count. cache holds the recipes by kind and variant.
local function layItem(folder, it, floorTop, cache, report)
	local key = it.kind .. "|" .. tostring(it.variant)
	cache[key] = cache[key] or Park.recipe(it.kind, it.variant)
	local specs = cache[key]
	local pivot = CFrame.new(it.x, floorTop, it.z) * CFrame.Angles(0, math.rad(it.yaw or 0), 0)
	if #specs == 1 then
		local part, made = child(folder, "Part", it.id)
		conform(part, specs[1], pivot, report, made)
		report.changed += made and 0 or attribute(part, "Kind", it.kind)
		if made then part:SetAttribute("Kind", it.kind) end
	else
		local model, made = child(folder, "Model", it.id)
		if made then report.created += 1 end
		for _, spec in ipairs(specs) do
			local part, madePart = child(model, "Part", spec.name)
			conform(part, spec, pivot, report, madePart)
		end
		local n = apply(model, { WorldPivot = pivot })
		n += attribute(model, "Kind", it.kind)
		if not made then report.changed += n end
	end
	return #specs
end

-- build(root, L, East) -> report { created, changed, parts, byFolder }: the park under root.Park (root is
-- Workspace.PuebloGatito_v1 on the live map since PGM-D2, any Instance in a suite). Moved parts are conformed to the park
-- frame (PGM-D4). One Folder per K-D18 folder; an item of one part
-- is a Part named by its id, a bigger one a Model of its recipe's parts (WorldPivot on its ground centre). Idempotent:
-- what is missing is made, what differs from the plan is set back, and a second call reports created 0 and changed 0.
-- Never removes anything (a dropped item that already stands is left to the archive). Refuses SistemaSonriente.
function Park.build(root, L, East)
	assert(typeof(root) == "Instance", "root must be an Instance")
	assert(not forbidden(root), "refusing to touch " .. Park.FORBIDDEN)
	local plan = Park.plan(L, East)
	local report = { created = 0, changed = 0, parts = 0, byFolder = {} }
	local park, madePark = child(root, "Folder", Park.FOLDER)
	if madePark then report.created += 1 end
	report.changed += attribute(park, "Version", Park.VERSION)
	local folders = {}
	for _, name in ipairs(Park.FOLDERS) do
		local f, made = child(park, "Folder", name)
		if made then report.created += 1 end
		folders[name] = f
		report.byFolder[name] = 0
	end
	local cache = {}
	for _, it in ipairs(plan.items) do
		local n = layItem(folders[it.folder], it, plan.floorTop, cache, report)
		report.parts += n
		report.byFolder[it.folder] += n
	end
	return report
end

-- syncNests(root) -> changed: the sixteen park nests under root.Nests (GL-D10: K1..K16, K4, K5, K7 and K8 re-flagged in
-- place; root = Workspace.PuebloGatito_v1 since PGM-D2; on
-- root.Ground.Floor's top when there is one, else Area.FLOOR_TOP; at the park-frame x, z of PGM-D4), from Park.NESTS
-- only (K-D8): Model Nest_K<n> with a Wood Collision_Bowl (its PrimaryPart, pivot on the ground centre) and a
-- RarityRing, the attributes NestId, Rarity, EventOnly false, Candidate, Enabled, Park and Guard, and the
-- WildboundCandyNestCandidate tag. A missing nest is made, a moved or re-flagged one is set back; nothing else in the
-- folder is touched. Returns how many nests it made or changed (0 when they already match; 0 for no root).
function Park.syncNests(root)
	if typeof(root) ~= "Instance" then return 0 end
	assert(not forbidden(root), "refusing to touch " .. Park.FORBIDDEN)
	local top = Area.FLOOR_TOP
	local ground = root:FindFirstChild(Park.GROUND_FOLDER)
	local floor = ground and ground:FindFirstChild("Floor")
	if floor and floor:IsA("BasePart") then top = floor.Position.Y + floor.Size.Y / 2 end
	local folder = child(root, "Folder", Park.NESTS_FOLDER)
	local total = 0
	for _, n in ipairs(Park.NESTS) do
		local report = { created = 0, changed = 0 }
		local model, made = child(folder, "Model", "Nest_" .. n.id)
		local at = CFrame.new(n.x, top, n.z)
		local bowl, madeBowl = child(model, "Part", "Collision_Bowl")
		conform(bowl, { shape = "Cylinder", size = Park.BOWL.size, offset = { 0, 1.1, 0, 0, 0, 90 }, color = Park.BOWL.color,
			material = Park.BOWL.material, role = "solid" }, at, report, madeBowl)
		local ring, madeRing = child(model, "Part", "RarityRing")
		conform(ring, { shape = "Cylinder", size = Park.RING.size, offset = { 0, 0.04, 0, 0, 0, 90 },
			color = Park.RING_COLORS[n.rarity] or Park.RING_COLORS.Comun, material = "SmoothPlastic", role = "decor" }, at, report,
			madeRing)
		local changed = report.created + report.changed
		if model.PrimaryPart ~= bowl then
			model.PrimaryPart = bowl
			changed += 1
		end
		changed += apply(bowl, { PivotOffset = bowl.CFrame:ToObjectSpace(at) })
		for key, value in pairs({ NestId = n.id, Rarity = n.rarity, EventOnly = false, Candidate = true, Enabled = true,
			Park = true, Guard = n.guard }) do
			changed += attribute(model, key, value)
		end
		if not CollectionService:HasTag(model, Park.NEST_TAG) then
			CollectionService:AddTag(model, Park.NEST_TAG)
			changed += 1
		end
		if made or changed > 0 then total += 1 end
	end
	return total
end

-- GL-D5: the hedge rows, park-local: W and E along local x at lz 281 and -311 (world x 1 and 593), S across the far end
-- at lx 933 (world z 1533); centres at from + pitch * (i - 0.5) along the row, each puff `length` long along its local X
-- (local yaw 0 runs it along local x, 90 along local z). The puffs (8 deep) lie on the floor's margins, outside the space.
local HEDGE_ROWS = {
	{ row = "W", count = 40, across = 281, from = -256, pitch = 29.75, length = 33.75, yaw = 0 },
	{ row = "E", count = 40, across = -311, from = -256, pitch = 29.75, length = 33.75, yaw = 0 },
	{ row = "S", count = 20, across = 933, from = 277, pitch = -29.2, length = 33.2, yaw = 90 },
}

-- edgePlan() -> { walls = { spec }, hedge = { item } } (GL-D4, GL-D5), world studs; pure, fresh tables every call:
--   walls  SideWallWest (x -7..-3), SideWallEast (x 597..601), both along z 937..1541, and EndWall (x -7..601, z
--          1537..1541): { name, shape, x, z (centre), size, offset (its centre EDGE.height / 2 over the floor's top),
--          color, material, role "solid", transparency 1, castShadow false }, the CandyEast cap() flags (80 tall,
--          invisible, collide and answer queries, never touched, no shadow)
--   hedge  Hedge_W01..W40, Hedge_E01..E40, Hedge_S01..S20: { id, kind "hedge", x, z, yaw (world), variant (the puff
--          length, 4 places), lx, lz }
function Park.edgePlan()
	local E = Park.EDGE
	local function wall(name, minX, maxX, minZ, maxZ)
		return { name = name, shape = "Block", x = (minX + maxX) / 2, z = (minZ + maxZ) / 2,
			size = { maxX - minX, E.height, maxZ - minZ }, offset = { 0, E.height / 2, 0, 0, 0, 0 }, color = C.WHITE,
			material = "SmoothPlastic", role = "solid", transparency = 1, castShadow = false }
	end
	local walls = {
		wall("SideWallWest", ARM.minX - E.wall, ARM.minX, E.wallFromZ, ARM.maxZ + E.wall),
		wall("SideWallEast", ARM.maxX, ARM.maxX + E.wall, E.wallFromZ, ARM.maxZ + E.wall),
		wall("EndWall", ARM.minX - E.wall, ARM.maxX + E.wall, ARM.maxZ, ARM.maxZ + E.wall),
	}
	local hedge = {}
	for _, r in ipairs(HEDGE_ROWS) do
		for i = 1, r.count do
			local along = r.from + r.pitch * (i - 0.5)
			local lx, lz = along, r.across
			if r.yaw == 90 then lx, lz = r.across, along end
			local x, z = Area.world(lx, lz)
			table.insert(hedge, { id = ("Hedge_%s%02d"):format(r.row, i), kind = "hedge", x = x, z = z,
				yaw = Area.worldYaw(r.yaw), variant = round(r.length, 4), lx = lx, lz = lz })
		end
	end
	return { walls = walls, hedge = hedge }
end

-- buildEdge(root) -> report { created, changed, parts } (GL-D4, GL-D5): the edge under root.Edge (root =
-- Workspace.PuebloGatito_v1 on the live map, any Instance in a suite): Edge.Walls holds the three walls (Parts by name),
-- Edge.Hedge the hedge puffs (a Model of two decor parts each, Kind "hedge"); 203 parts (Park.EDGE_PARTS). Idempotent
-- like build: what is missing is made, what differs is set back, a second call reports created 0 and changed 0; never
-- removes anything. Refuses SistemaSonriente.
function Park.buildEdge(root)
	assert(typeof(root) == "Instance", "root must be an Instance")
	assert(not forbidden(root), "refusing to touch " .. Park.FORBIDDEN)
	local plan = Park.edgePlan()
	local report = { created = 0, changed = 0, parts = 0 }
	local edge, madeEdge = child(root, "Folder", Park.EDGE.folder)
	if madeEdge then report.created += 1 end
	local walls, madeWalls = child(edge, "Folder", "Walls")
	if madeWalls then report.created += 1 end
	local hedge, madeHedge = child(edge, "Folder", "Hedge")
	if madeHedge then report.created += 1 end
	for _, spec in ipairs(plan.walls) do
		local part, made = child(walls, "Part", spec.name)
		conform(part, spec, CFrame.new(spec.x, Area.FLOOR_TOP, spec.z), report, made)
		report.parts += 1
	end
	local cache = {}
	for _, it in ipairs(plan.hedge) do
		report.parts += layItem(hedge, it, Area.FLOOR_TOP, cache, report)
	end
	return report
end

-- strays(root, L, East) -> { { instance, path, folder, name } } (GL-D14, the grow tool's archive list): every Model or
-- BasePart directly in one of root.Park's Park.FOLDERS folders whose name is not a kept item of that folder in
-- plan(L, East) (a dropped id, an unknown name, or an item in another folder), sorted by path ("Toys.Junk"). Read only:
-- nothing is moved. A child named SistemaSonriente is never listed; a root inside it is refused; no root.Park, none.
function Park.strays(root, L, East)
	assert(typeof(root) == "Instance", "root must be an Instance")
	assert(not forbidden(root), "refusing to touch " .. Park.FORBIDDEN)
	local out = {}
	local park = root:FindFirstChild(Park.FOLDER)
	if not park then return out end
	local keep = {}
	for _, name in ipairs(Park.FOLDERS) do keep[name] = {} end
	for _, it in ipairs(Park.plan(L, East).items) do keep[it.folder][it.id] = true end
	for _, name in ipairs(Park.FOLDERS) do
		local folder = park:FindFirstChild(name)
		if folder and folder:IsA("Folder") then
			for _, c in ipairs(folder:GetChildren()) do
				if not forbidden(c) and (c:IsA("Model") or c:IsA("BasePart")) and not keep[name][c.Name] then
					table.insert(out, { instance = c, path = name .. "." .. c.Name, folder = name, name = c.Name })
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.path < b.path end)
	return out
end

-- The pieces of a root, walking down through Folders only (a Model or a BasePart is one piece), sorted by name, each
-- with its path under the root ("Props.Tree_3"). Pieces inside SistemaSonriente are skipped; `skip` names root
-- children never walked.
local function pieces(root, skip)
	local out = {}
	local function walk(parent, prefix)
		local list = parent:GetChildren()
		table.sort(list, function(a, b) return a.Name < b.Name end)
		for _, c in ipairs(list) do
			if forbidden(c) or (parent == root and skip and skip[c.Name]) then continue end
			local path = prefix == "" and c.Name or (prefix .. "." .. c.Name)
			if c:IsA("Folder") then
				walk(c, path)
			elseif c:IsA("Model") or c:IsA("BasePart") then
				table.insert(out, { instance = c, path = path })
			end
		end
	end
	walk(root, "")
	return out
end
local function pivotOf(instance)
	return instance:IsA("BasePart") and instance.CFrame or instance:GetPivot()
end
local function inRect(r, x, z)
	return x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ
end
local function move(list, archiveFolder, dryRun)
	local out = { moved = {}, count = 0 }
	for _, p in ipairs(list) do
		table.insert(out.moved, p.path)
		out.count += 1
	end
	if not dryRun then
		assert(typeof(archiveFolder) == "Instance", "an archive folder is needed for the real run")
		assert(not forbidden(archiveFolder), "refusing to touch " .. Park.FORBIDDEN)
		for _, p in ipairs(list) do p.instance.Parent = archiveFolder end
	end
	return out
end

-- archiveAnnex(annexRoot, archiveFolder, L, East, dryRun) -> { moved = { paths }, count } (K-D17): every piece of the
-- big4 annex (Workspace.WildboundCandyAnnex_Big4, walked through its Folders) whose pivot lies in the second space
-- (East.plan(L).space, x 1548..2068 since Caramelo v9, was 948..1468, z -263..257) is reparented into archiveFolder; a dry run only lists them. Never
-- destroys anything; refuses SistemaSonriente.
function Park.archiveAnnex(annexRoot, archiveFolder, L, East, dryRun)
	if typeof(annexRoot) ~= "Instance" then return { moved = {}, count = 0 } end
	assert(not forbidden(annexRoot), "refusing to touch " .. Park.FORBIDDEN)
	local space = eastModule(East).plan(layout(L)).space
	local list = {}
	for _, p in ipairs(pieces(annexRoot)) do
		local pv = pivotOf(p.instance)
		if inRect(space, pv.X, pv.Z) then table.insert(list, p) end
	end
	return move(list, archiveFolder, dryRun)
end

-- Whether a piece blocks: it holds a colliding BasePart that is not a walkable floor.
local function blocks(instance)
	local function hard(part)
		return part:IsA("BasePart") and part.CanCollide and part:GetAttribute("Role") ~= "floor"
	end
	if hard(instance) then return true end
	for _, d in ipairs(instance:GetDescendants()) do
		if hard(d) then return true end
	end
	return false
end
-- clearGate(biomeRoot, archiveFolder, dryRun) -> { moved = { paths }, count } (K-D2): every colliding piece of the plot
-- (Workspace.Candy_Bioma_v1, walked through its Folders; Ground, Paths and Nests are never walked) whose pivot lies in
-- the gate corridor Park.GATE_CORRIDOR (x 896..932, z -17..11) is reparented into archiveFolder; decor and walkable
-- floors stay. A dry run only lists them. Never destroys anything; refuses SistemaSonriente.
function Park.clearGate(biomeRoot, archiveFolder, dryRun)
	if typeof(biomeRoot) ~= "Instance" then return { moved = {}, count = 0 } end
	assert(not forbidden(biomeRoot), "refusing to touch " .. Park.FORBIDDEN)
	local list = {}
	for _, p in ipairs(pieces(biomeRoot, { Ground = true, Paths = true, Nests = true })) do
		local pv = pivotOf(p.instance)
		if inRect(Park.GATE_CORRIDOR, pv.X, pv.Z) and blocks(p.instance) then table.insert(list, p) end
	end
	return move(list, archiveFolder, dryRun)
end

return Park
