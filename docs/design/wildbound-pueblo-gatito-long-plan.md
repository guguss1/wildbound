# Pueblo Gatito 600 x 1200: the long kitten park and the Jardín de Ovillos (plan, 2026-11-19)

Owner's words:
- 2026-11-18: "que todos los biomas tengan el mismo tamaño, pero ahora hacelos mas largos aun"
- 2026-11-19: "hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas zonas hazlo"

The parent's decisions GL-PD1..GL-PD11 (`docs/handoff/gatito-long/decisions.md`) are taken as given and are not reopened. This plan turns them into numbers (GL-D1..GL-D17). The research is in the same folder: `research-frame-layout.md`, `research-readers.md`, `research-pattern.md`, `research-critic.md`. The pattern is Caramelo v9 (`docs/design/wildbound-caramelo-v9-plan.md`, `tools/wildbound-caramelo-v9-migrate.luau`, the CandyEast walls in `tools/WildboundCandyEast.luau`). The earlier park plans are `docs/design/wildbound-kitten-park-plan.md` (K-D1..K-D21) and `docs/design/wildbound-pueblo-gatito-move-plan.md` (PGM-D1..PGM-D9).

Standing rules that apply:
- no questions to the owner (decide and record);
- never touch SistemaSonriente;
- no asset uploads: the park's own recipes and primitive Parts only;
- kids game on phones: every new part is counted, and the dry run measures the total.

**Conventions.**
- Park-local (lx, lz) unless marked "world". world(lx, lz) = (282 - lz, 600 + lx) (`WildboundGatitoArea`).
- Local +x runs from the gate (lx -260) to the far end (now lx 860) and is world +z (south). Local +z is world -x (west).
- "The K-D half" is today's park (lx -260..260). "The garden" is the new half (lx 260..860), the Jardín de Ovillos.

**How this plan was checked.** By hand, with the arithmetic written into the tables below: every new item against the drop rules (`Park.CLEAR` nest 8, portal 12, path 6 + half the width; `Park.REACH` patch 10), the KP1 inset, KP3 (solid parts off paths and nests), the posts' 85-stud spacing and each kitten's hunt reach (zone 60 + 12 + attack range + push: Lanudo 85, Guerrero 90, Bouquet 92, Actually 85). There is no local Luau runner, so the suites must pass in Studio before the real run, and the dry run's `dropped` list is the final word.

## What is there today (repo, read 2026-11-19)

- `WildboundGatitoArea`: VERSION 2, ORIGIN (282, 600), YAW -90, HALF 260, ARM x -3..597, z 337..937. `rect()` is the square x 22..542, z 340..860.
- `Workspace.PuebloGatito_v1` (live, mark `PuebloGatito = 2`): `Ground.Floor` 520 x 520 at (282, 600), `Park` (1378 parts in nine folders; K-D18 budget 1392 before 14 dropped parts), `Nests` (K1..K8, 16 parts). About 1395 parts.
- Main path M ends at (190, 0). TowerPlaza (215, 0) d 50, TorreGatoVigia (220, 0), 4 lit short lanterns at (195, ±20) and (235, ±20).
- 8 nests (3 Comun, 3 Rara, 2 Epica) at lx -170..150; 8 kitten posts (4 home, 4 east extra); one portal station "parque" (239, 372).
- `Park.plan` draws every random yaw and jitter from one generator, `Random.new(Park.SEED)`, in table order.
- Past the old floor: Apron_Volcanic (basalt, top 0.32) to z 961, meadow to z 1024, then void (the Baseplate ends at ±1024).

## Decisions (GL-D1..GL-D17)

### GL-D1, the frame (GL-PD1)

ORIGIN, YAW and HALF stay, so every park-local and world literal of the K-D half keeps its value. In `src/wildbound/WildboundGatitoArea.luau`:

| Constant | Value |
|---|---|
| `Area.VERSION` | 2 → **3** (the move tool asserts 2 and now errors before doing anything) |
| `Area.HALF` | 260: now the gate-side half-length and the across half-width |
| `Area.GROWTH` | **600** (new) |
| `Area.FAR` | **`Area.HALF + Area.GROWTH` = 860** (new) |
| `Area.ARM` | `{ minX = -3, maxX = 597, minZ = 337, maxZ = 1537 }` |
| `Area.ORIGIN`, `Area.YAW`, `Area.FLOOR_TOP`, `Area.V1`, `Area.ROOT_NAME` | unchanged |

`rect(margin)`:

```lua
function Area.rect(margin)
	local m = margin or 0
	local ax, az = Area.world(-Area.HALF - m, -Area.HALF - m)
	local bx, bz = Area.world(Area.FAR + m, Area.HALF + m)
	return freeze({ minX = math.min(ax, bx), maxX = math.max(ax, bx), minZ = math.min(az, bz), maxZ = math.max(az, bz) })
end
```

- `rect()` = x 22..542, z 340..1460 (520 x 1120, local lx -260..860, |lz| <= 260). This is the "space": items stand inside it, inset 4.
- `rect(16)` = x 6..558, z 324..1476 (the music's enter margin still reaches the road's end at z 324).
- The header comment (:1-13) is rewritten: lx from -260 to +860, the space x 22..542, z 340..1460, ARM to 1537.

### GL-D2, the arm and the biome rows (GL-PD2)

- The big4 south arm is x -3..597, z 337..1537 (600 x 1200, centre (297, 937)).
- Repo classic copies: `WildboundBiomes.luau:25` `square("CandyEast", "pueblo-gatito", -3, 597, 337, 1537)` and `WildboundBiomeLight.luau:33` `square("CandyEast", -3, 597, 337, 1537)` (still the first row, because `presetAt` takes the first match). Comment `WildboundBiomes.luau:21` follows.
- Studio-only big4 copies: hand patches H1..H5 (see the list at the end). They are load-bearing: `world.inCandy` and the summon landing read `Biomes.has(x, z, "CandyEast")`, so without H1 no kitten wakes past z 937.

### GL-D3, the floor and the Approach (GL-PD3)

`root.Ground` holds two parts, both laid and conformed by `Park.buildGround(root)`:

| Part | World rectangle | Size | Centre (x, y, z) | Look |
|---|---|---|---|---|
| `Ground.Floor` | x -3..597, z 337..1537 (the whole arm) | 600 x 1 x 1200 | (297, 0, 937) | K-D15 grass (140, 201, 107), Grass |
| `Ground.Approach` | x 272..292, z 324..337 | 20 x 1 x 13 | (282, 0, 330.5) | the same grass |

- Both are role floor: anchored, collide, answer queries, never touched, cast a shadow, top at 0.5.
- `Park.FLOOR = freeze({ size = { ARM.maxX - ARM.minX, 1, ARM.maxZ - ARM.minZ }, centre = { x = (ARM.minX + ARM.maxX) / 2, z = (ARM.minZ + ARM.maxZ) / 2 }, color, material })`: derived from `Area.ARM`, so 600 x 1200 at (297, 937). The size is in world axes, as today (buildGround places it with no turn).
- `Park.APPROACH = freeze({ minX = 272, maxX = 292, minZ = 324, maxZ = 337 })`.
- The live Floor is conformed in place (Size and CFrame: 0 new parts). The Approach is 1 new part. 1200 is under the 2048 part-size limit.
- The 25-, 55- and 77-stud open margins and the 16-stud grey gap at the road's end are gone.
- The Approach lies outside the arm (z < 337), so GA1's "floor inside the arm" still holds for the Floor; the Approach is checked on its own (GL-10).

### GL-D4, the walls (GL-PD3)

Invisible solid walls, the CandyEast `cap()` flags (80 tall, transparency 1, SmoothPlastic, CanCollide and CanQuery true, CanTouch false, CastShadow false, Role "solid"), in `root.Edge.Walls`:

| Part | World rectangle | Size | Centre (x, y, z) |
|---|---|---|---|
| `SideWallWest` | x -7..-3, z 937..1541 | 4 x 80 x 604 | (-5, 40.5, 1239) |
| `SideWallEast` | x 597..601, z 937..1541 | 4 x 80 x 604 | (599, 40.5, 1239) |
| `EndWall` | x -7..601, z 1537..1541 | 608 x 80 x 4 | (297, 40.5, 1539) |

- `Park.EDGE = freeze({ folder = "Edge", wall = 4, height = 80, wallFromZ = 937 })`.
- The walls stay out of `Ground` on purpose: the resting service and the summon rays Include `Ground`, and an 80-tall wall top would read as ground.
- `conform` gains one override: `CastShadow = if spec.castShadow ~= nil then spec.castShadow else (spec.role ~= "floor" and biggest >= 2)`.

### GL-D5, the hedge border (GL-PD3)

A low hedge of green puffs along the three outer edges (west, east, far end), in `root.Edge.Hedge`. One new recipe from primitives only:

```lua
R.hedge = function(length) -- hedge puff [2]: a long low grass oval and a lighter top, along local X
	local l = {}
	local L = tonumber(length) or 30
	oval(l, "Puff", { L, 5, 8 }, { 0, 2.5, 0 }, C.GRASS_DK, "decor", "Grass")
	oval(l, "Top", { L * 0.6, 3.5, 5.5 }, { 0, 4.6, 0.5 }, C.GRASS_LT, "decor", "Grass")
	return l
end
```

Rows (park-local; each segment is a Model of 2 decor parts with `Kind = "hedge"`, its variant the puff length rounded to 4 places):

| Row | Line | Along | Count | Pitch | Puff length | Local yaw (world) |
|---|---|---|---|---|---|---|
| `Hedge_W01..W40` | lz 281 (world x 1) | lx -256..934 (world z 344..1534), centre lx = -256 + 29.75 (i - 0.5) | 40 | 29.75 | 33.75 | 0 (-90) |
| `Hedge_E01..E40` | lz -311 (world x 593) | the same lx | 40 | 29.75 | 33.75 | 0 (-90) |
| `Hedge_S01..S20` | lx 933 (world z 1533) | lz 277..-307 (world x 5..589), centre lz = 277 - 29.2 (j - 0.5) | 20 | 29.2 | 33.2 | 90 (0) |

- The puffs (8 deep) lie on the floor's margins, outside the space: west x -3..5, east x 589..597, end z 1529..1537. Corners overlap.
- `Park.edgePlan()` returns `{ walls = { 3 specs }, hedge = { 100 items } }` (pure). `Park.buildEdge(root)` lays both under `root.Edge` (idempotent: conforms or creates, never removes; refuses SistemaSonriente) and returns `{ created, changed, parts }`.
- `Park.EDGE_PARTS = 203` (3 walls + 100 x 2).
- The gate side (z 337) gets no hedge: it faces the hub and the road.

### GL-D6, two generators: the K-D half never moves (supports GL-PD1, GL-PD4)

`plan()` draws every seeded yaw and slab jitter from `rng = Random.new(Park.SEED)` in table order, so appending rows to `LOCAL` would turn every K-D tree and toy. So:

- The garden's rows live in a new table `GARDEN`, with the same row shapes as `LOCAL` (paths, junctions, buildings, toys, treesL, treesS, bushes, lanternsTall, lanternsShort, patches, flowers, tufts).
- `Park.GARDEN_SEED = Park.SEED + Area.GROWTH` (8728). Every garden draw uses `grow = Random.new(Park.GARDEN_SEED)`; every K-D draw still uses `rng`, in the same order as today.
- In each category of `plan()`, the `LOCAL` loop runs first with `rng`, then the `GARDEN` loop with `grow`. Garden paths are appended to `paths` after the K-D ones, so the drop rule and the lanterns' facing see them. The stone counter runs on across them.
- `Park.plan(L, East, options)`: `options.garden == false` skips the `GARDEN` rows (a suite-only switch for GL-3). `build()` and the tools call it without options.
- The six K-D rows that move (GL-D9) stay in `LOCAL` with their ids, so `build()` conforms them (moves them) instead of making copies.
- Garden ids: `Path_M2_*`, `Path_GN_*`, `Path_GS_*`, `Path_GT_*`, `Path_GV_*`, `Junction_<id>`, the building and toy ids below, `TreeL_G01..`, `TreeS_G01..`, `Bush_G01..`, `LanternTall_G1..`, `LanternShort_G01..`, `Patch_G01..`, `Flower_G01..`, `Tuft_G01..`. Patch variant `(i % 2) + 1` and flower variant `(i - 1) % 3 + 1` by their own index.

Checked: no K-D item lies within its drop distance of a garden path (the nearest are LanternTall_8 (180, -9), 13.5 from M2's start and a lantern anyway; Bush_11 (240, 40), 45 from M2; Tuft (175, ±25), 29 from (190, 0)), and no K-D lantern's nearest path changes, except the four lit ones that move.

### GL-D7, the Jardín de Ovillos: paths and junctions (GL-PD4)

`GARDEN.paths`:

| Id | Width | Points (local) | Length | Pieces |
|---|---|---|---|---|
| `M2` (main = true) | 12 | (190, 0), (260, 0), (330, -10), (410, 4), (490, -8), (570, 6), (650, -6), (730, 4), (800, 0) | 615.669 | 8 strips + 7 joints + 123 slabs = 138 |
| `GN` | 8 | (490, -8), (500, 55), (520, 120) | 131.796 | 19 stones |
| `GS` | 8 | (490, -8), (500, -65), (520, -125) | 121.116 | 17 stones |
| `GT` | 8 | (320, 140), (420, 128), (520, 120), (620, 130), (700, 110) | 383.998 | 55 stones |
| `GV` | 8 | (320, -140), (420, -128), (520, -125), (620, -135), (700, -115) | 383.723 | 55 stones |

- M2 is the main path's continuation (GL-PD4: "to local (800, 0)"). It is a second path, not more points on M, so M's 89 slabs and every K-D draw stay as they are (GL-D6). Its first leg runs straight along +x from M's end, so the two strips meet without a gap.
- Stones: `n = floor(length / 7 + 0.5)`; slabs every 5 from 2.5 (612.5 is the last).

`GARDEN.junctions`:

| Id | Local | d | World |
|---|---|---|---|
| `PuertaJardin` | (190, 0) | 24 | (282, 790): covers the M/M2 seam, where TowerPlaza was |
| `PlazaOvillos` | (490, -8) | 30 | (290, 1090): the garden's centre plaza, on M2's bend |
| `JardinNorte` | (520, 120) | 26 | (162, 1120) |
| `JardinSur` | (520, -125) | 26 | (407, 1120) |

Garden Paths: 138 + 146 + 4 = **288 parts**.

### GL-D8, the Jardín de Ovillos: content (GL-PD4)

Only existing recipes, no sign-bearing kinds (KP5's 8..14 SurfaceGuis stay 9). Every row was checked against the drop rules and KP3; the nearest distances are given where they are tight.

**Buildings** (`GARDEN.buildings`; local yaw 0 faces local -z, 180 faces local +z):

| Id | Kind | Folder | Local | Yaw | Parts | Nearest |
|---|---|---|---|---|---|---|
| `CasaOvillera` | potter | Village | (380, -195) | 180 | 40 | GV 62 |
| `CastilloDeOvillos` | castle | Village | (690, 195) | 0 | 53 | GT 82, K15 nest 115 |
| `ArbolRascadorJardin` | scratchTree | ToyPark | (430, 195) | 0 | 33 | GT 68 |
| `TorreDeCajasJardin` | boxTower | ToyPark | (560, 190) | 0 | 21 | GT 66 |
| `CastilloRascadorJardin` | scratchCastle | ToyPark | (600, -195) | 180 | 44 | GV 62, K14 nest 115 |
| `TorreDeCajasMirador` | boxTower | ToyPark | (745, -185) | 180 | 21 | GV end 83 |

Village 93, ToyPark 119.

**Toys** (`GARDEN.toys`, rows `{ id, kind, lx, lz, yaw (nil: seeded by grow), variant }`):

```lua
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
```

47 toys, 188 parts: 10 giant yarns ring the PlazaOvillos and the two side gardens (the "yarn-ball garden"), the rolls, tubes and bags make two toy piles by JardinNorte and JardinSur. Tight ones: Yarn_G2 33 from GS, Yarn_G4 31.6 from GN, YarnSmall_G6 20.5 from GS, YarnSmall_G5 16.4 from post K13 (decor; the rule is 8), SwabBench_G1 23.8 from GV, SwabBench_G2 26.8 from GT.

**Trees and bushes** (`GARDEN.treesL`, `treesS`, `bushes`; yaws seeded by grow):

```lua
treesL = { { 280, 110 }, { 285, -110 }, { 330, 230 }, { 340, -235 }, { 400, 60 }, { 410, -75 }, { 480, 245 }, { 470, -245 },
	{ 610, 100 }, { 630, -100 }, { 650, 235 }, { 700, -240 }, { 760, 200 }, { 800, -170 }, { 840, 120 }, { 845, -95 } },
treesS = { { 300, 30 }, { 310, -40 }, { 370, 105 }, { 385, -105 }, { 450, 90 }, { 560, -95 }, { 585, 100 }, { 660, 40 },
	{ 670, -40 }, { 735, 170 }, { 760, -150 }, { 820, 170 }, { 825, -140 }, { 395, 225 }, { 420, -170 }, { 530, 250 },
	{ 540, -250 }, { 290, 200 } },
bushes = { { 275, 25 }, { 275, -25 }, { 430, 40 }, { 430, -50 }, { 555, 30 }, { 560, -40 }, { 340, 160 }, { 340, -165 },
	{ 640, 150 }, { 640, -150 }, { 750, 60 }, { 755, -45 }, { 850, 40 }, { 850, -40 } },
```

16 + 18 + 14, 196 parts. Tight ones: TreeS_G05 (450, 90) 30 from nest K11; TreeS_G07 (585, 100) 26.5 from GT and 29.2 from nest K13; TreeL_G05 (400, 60) 26.9 from post K11; Bush_G11 (750, 60) 25.5 from the second portal (rule 12).

**Lanterns** (`GARDEN.lanternsTall`, `lanternsShort`; each faces its nearest path point, as today):

```lua
lanternsTall = { { 270, 10 }, { 350, -17 }, { 430, 12 }, { 510, -15 }, { 590, 12 }, { 670, -14 }, { 750, 13 } },
lanternsShort = { { 478, 4 }, { 478, -20 }, { 502, 4 }, { 502, -20 }, -- PlazaOvillos, the PlazaCentral pattern (±12)
	{ 507, 137 }, { 533, 137 }, { 535, 103 }, -- JardinNorte
	{ 507, -142 }, { 533, -142 }, { 535, -108 }, -- JardinSur
	{ 395, 140 }, { 645, 140 }, { 395, -140 }, { 645, -140 } }, -- the two walks
```

7 tall lanterns along M2, 9 to 12 studs off its centre line like the K-D ones, each with its PointLight (lights 12 → 19); 14 unlit short ones. 105 parts.

**Scatter** (`GARDEN.patches`, `flowers`, `tufts`):

```lua
patches = { { 300, 120 }, { 300, -120 }, { 390, 170 }, { 400, -165 }, { 460, 70 }, { 440, -80 }, { 575, 50 }, { 575, -50 },
	{ 640, 200 }, { 690, -170 }, { 720, 90 }, { 720, -100 }, { 800, 100 }, { 800, -80 } },
flowers = { { 290, 20 }, { 295, -22 }, { 360, 20 }, { 335, -30 }, { 410, 24 }, { 400, -22 }, { 470, 25 }, { 465, -30 },
	{ 520, 25 }, { 525, -28 }, { 600, -25 }, { 620, 25 }, { 700, 28 }, { 705, -25 }, { 780, 25 }, { 775, -30 },
	{ 545, 145 }, { 545, -145 }, { 350, 150 }, { 355, -150 }, { 600, 150 }, { 610, -160 }, { 690, 140 }, { 680, -140 } },
tufts = { { 305, 45 }, { 320, -55 }, { 375, 40 }, { 385, -45 }, { 445, 70 }, { 450, -65 }, { 540, 70 }, { 545, -70 },
	{ 625, 55 }, { 640, -35 }, { 710, 50 }, { 705, -50 }, { 790, 45 }, { 790, -45 }, { 420, 160 }, { 430, -150 },
	{ 585, 175 }, { 590, -175 }, { 665, 200 }, { 725, -200 }, { 760, 165 }, { 775, -160 }, { 825, 60 }, { 825, -60 } },
```

134 parts. Patches keep 8 + 10 (REACH) from nests, posts and chests: the tightest is Patch_G12 (720, -100), 20.6 from chest K16 (10.6 past the reach). Flowers on the walks keep 13.6 (Flower_G19) and 14.2 (Flower_G20) from GT and GV (the rule is 10).

**Garden budget** (`Park.GARDEN_BUDGET`, frozen; before the drop rules, which should drop none of it):

| Paths | Gate | Village | ToyPark | Toys | Chests | Trees | Lanterns | Scatter | Total |
|---|---|---|---|---|---|---|---|---|---|
| 288 | 0 | 93 | 119 | 188 | 88 | 196 | 105 | 134 | **1211** |

Chests are the 8 new `Chest_K9..K16` (11 parts each), placed by `plan()` from `Park.NESTS` as today.

### GL-D9, the far-end goal (GL-PD5)

Six `LOCAL` rows move +600 along local x, keeping their ids and yaws:

| Row | Was | Now | World now |
|---|---|---|---|
| junction `TowerPlaza` (d 50) | (215, 0) | **(815, 0)** | (282, 1415); the plaza spans lx 790..840, 20 from the far edge, as before |
| building `TorreGatoVigia` (local yaw 90) | (220, 0) | **(820, 0)** | (282, 1420) |
| `LanternShort_15` (lit) | (195, 20) | (795, 20) | (262, 1395) |
| `LanternShort_16` (lit) | (195, -20) | (795, -20) | (302, 1395) |
| `LanternShort_17` (lit) | (235, 20) | (835, 20) | (262, 1435) |
| `LanternShort_18` (lit) | (235, -20) | (835, -20) | (302, 1435) |

- M2 ends at (800, 0), inside the plaza. The tower's solid Base (at its pivot) is 20 from M2's end (KP3 wants 12).
- The gate-side PlazaCentral and everything else of the K-D half stay. Where TowerPlaza was, the `PuertaJardin` disc covers the seam.
- From the gate (lx -254) the tower is 1074 studs away, inside the Gatuno Day fogEnd 1100: a faint goal at first, clear from PlazaCentral on (GL-D16).

### GL-D10, the nests: 8 → 16, rarity by depth (GL-PD6)

A local helper `parkNest(id, rarity, lx, lz, plx, plz, guard, clx, clz)` builds a row from park-local values through `Area.world` (the K1..K8 rows keep their V1 literals and `moved()`). Each post stands 12 studs from its nest toward M2, each chest 7 studs on the far side; key `"kittenPost" .. id`.

| Nest | Rarity (was) | Nest local / world | Post local / world | Chest local / world | Guard |
|---|---|---|---|---|---|
| K1..K3 | Comun | unchanged | unchanged | unchanged | unchanged |
| K4 | **Comun** (Rara) | (-50, 70) / (212, 550) | unchanged | unchanged | GatitoLanudo |
| K5 | **Comun** (Rara) | (20, -70) / (352, 620) | unchanged | unchanged | GatitoGuerrero@kittenPostK5 |
| K6 | Rara | unchanged | unchanged | unchanged | unchanged |
| K7 | **Rara** (Epica) | (150, -120) / (402, 750) | unchanged | unchanged | GatitoActually@kittenPostK7 |
| K8 | **Rara** (Epica) | (150, 120) / (162, 750) | unchanged | unchanged | GatitoLanudo@kittenPostK8 |
| K9 | Rara | (300, 78) / (204, 900) | (300, 66) / (216, 900) | (300, 85) / (197, 900) | GatitoGuerrero@kittenPostK9 |
| K10 | Rara | (360, -80) / (362, 960) | (360, -68) / (350, 960) | (360, -87) / (369, 960) | GatitaBouquet@kittenPostK10 |
| K11 | Rara | (420, 90) / (192, 1020) | (420, 78) / (204, 1020) | (420, 97) / (185, 1020) | GatitoActually@kittenPostK11 |
| K12 | Epica | (470, -95) / (377, 1070) | (470, -83) / (365, 1070) | (470, -102) / (384, 1070) | GatitoLanudo@kittenPostK12 |
| K13 | Epica | (560, 85) / (197, 1160) | (560, 73) / (209, 1160) | (560, 92) / (190, 1160) | GatitoGuerrero@kittenPostK13 |
| K14 | Epica | (600, -80) / (362, 1200) | (600, -68) / (350, 1200) | (600, -87) / (369, 1200) | GatitaBouquet@kittenPostK14 |
| K15 | Epica | (680, 80) / (202, 1280) | (680, 68) / (214, 1280) | (680, 87) / (195, 1280) | GatitoActually@kittenPostK15 |
| K16 | Epica | (730, -75) / (357, 1330) | (730, -63) / (345, 1330) | (730, -82) / (364, 1330) | GatitoLanudo@kittenPostK16 |

- Counts: **5 Comun (K1..K5, lx -170..20), 6 Rara (K6..K11, lx 35..420), 5 Epica (K12..K16, lx 470..730)**: every Rara lies deeper than every Comun, every Epica deeper than every Rara, and every Epica is in the garden (GL-PD6). No Legendaria (event-only). Species follow the rarity through `PARK_POOL` (K-D8 unchanged).
- The four re-flagged nests change in place: `syncNests` conforms `Rarity` and the ring colour (no new parts).
- Ids `GatitoK9..GatitoK16`, keys `gatito_k9..gatito_k16` (`WildboundCandyNests` needs no change). The `CandyNests_Test` Legendaria fixture "K9" becomes **"K99"** (`GatitoK99`), so it never shares a name with the real K9.
- Nests: 16 x 2 = 32 parts.

### GL-D11, the kitten posts: 8 → 16 (GL-PD7)

`WildboundPraderaSites.EAST_FIXED` gains `kittenPostK9..K16 = parkPost(plx, plz)` (the post column above); `EAST_EXTRA_POSTS` gains 8 rows, appended in this order:

```lua
table.freeze({ name = "GatitoGuerrero", key = "kittenPostK9" }), table.freeze({ name = "GatitaBouquet", key = "kittenPostK10" }),
table.freeze({ name = "GatitoActually", key = "kittenPostK11" }), table.freeze({ name = "GatitoLanudo", key = "kittenPostK12" }),
table.freeze({ name = "GatitoGuerrero", key = "kittenPostK13" }), table.freeze({ name = "GatitaBouquet", key = "kittenPostK14" }),
table.freeze({ name = "GatitoActually", key = "kittenPostK15" }), table.freeze({ name = "GatitoLanudo", key = "kittenPostK16" }),
```

- Each kitten now has one home post and three extra posts (Guerrero K1 + K5, K9, K13; Bouquet K2 + K6, K10, K14; Actually K3 + K7, K11, K15; Lanudo K4 + K8, K12, K16). The existing posts stay.
- Spacing: the nearest pairs are K10-K12 111.0, K13-K15 120.1, K9-K11 120.6, K14-K16 130.1; every pair is at least 85 apart.
- Reach: the deepest post, K16 at world z 1330, hunts to 1330 + 85 = 1415, 45 inside the space's far end (the suites want 10). The widest, K12 at world x 365, reaches 450 (the side edge 542). The post window becomes **lx -170..760, |lz| <= 180** in KP2 and KK5.
- `Beasts.server` and the resting service walk `EAST_EXTRA_POSTS` already: no code change. Every post stands on `Ground.Floor` (the whole arm), so the resting rays and the summon ring always land.
- The comment at `WildboundPraderaSites.luau:127-138` is rewritten: posts lx -170..730, |lz| <= 108, 85 apart; the far end is z 1460.

### GL-D12, visiting critters: no (GL-PD7)

**Decision: no visiting candy critters in the park; kittens only.** Read in the code:

1. Mochimiau and Mielita (and every candy critter) have `biome = "Meadow"`, category Guardian, and are not `Config.PLAYABLE`, so `Config.homeBiome` returns "Meadow" whatever `BIOME_PREFERENCE` says. `Director.placeBlock` refuses a beast whose home biome is not in `ctx.biomes` ("Biome"); in the park `ctx.biomes` holds CandyEast only. `NO_GLOBAL_BIOMES` is not the gate here: it only bars Global beasts.
2. `Beasts.server` `spawnPoint` lands a summoned beast only where `Biomes.has(x, z, spec.biome)`: a Meadow critter never lands on CandyEast ground.
3. The only ways round are to change their biome row (it is shared with their Caramelo posts and with `Sites.AMBUSH`, which rolls them in the Caramelo rectangle), to give the director a second home biome (a shared rule), or to add new beast ids (Config rows, brain registration, models, sites, suites). Each touches Caramelo rules, which GL-PD7 forbids.

So the far half's creatures are the 8 new kitten posts. Other-zone creatures go to the later Bosque and Montañas arms (recorded for those tasks). No park ambush is added.

### GL-D13, the second portal station (GL-PD8)

`Portal.STATIONS` gains a fourth row, built by the service like "parque":

```lua
table.freeze({ id = "parque2", source = "build", x = 227, z = 1375, y = 0.5, yaw = 0 }),
```

- Park-local (775, 55), local yaw 90 = world yaw 0 (its posts stand along world z; it faces M2 across the park). `Park.PORTAL2 = freeze({ x = 227, z = 1375, lx = 775, lz = 55 })`.
- 95.9 from post K15 and 126.3 from post K16 (at least 85 from every post, so a calm kitten nearby never makes it unusable), 68 from the TowerPlaza centre, outside every safe zone, about 1378 studs from the hub.
- The drop rule clears `Park.CLEAR.portal` (12) round `PORTAL2` as round `PORTAL`; KP1 checks both discs.
- A carrier is still refused (CG2, decision 47): it only helps an empty-handed player get home.
- Name: `WildboundText.PORTAL.names.parque2 = "Portal del Jardín"` (17 characters; a one-line hunk in a mixed Studio copy, H6). `WildboundPortalService` needs no change: it builds every "build" row.

### GL-D14, the grow tool (GL-PD9)

`tools/wildbound-pueblo-gatito-grow.luau`, kept in Studio as the disabled Script `ServerStorage.WildboundPuebloGatitoGrow`, on the move/v9 skeleton.

| Item | Value |
|---|---|
| Defaults | `local DRY_RUN = true`, `local RESTORE = false` |
| Mode | `assert(not RunService:IsRunning(), "Edit mode only: stop Play first")` |
| Needs | root `PuebloGatito == 2`; returns "already" when it is 3 |
| Mark | `root:SetAttribute(MARK, Area.VERSION)` (3), last |
| Folders | `WildboundMapArchive.GatitoGrowBackup`, `GatitoGrowArchived`, `GatitoGrowReverted` |
| Recordings | `"PuebloGatitoGrow"`, `"PuebloGatitoGrowRestore"` |
| Summary | attribute `WildboundPuebloGatitoGrowSummary` on ServerStorage and `_G.WildboundPuebloGatitoGrowSummary` (JSON) |
| SistemaSonriente box | `SONRIENTE_BOX = { minX = -7, maxX = 601, minZ = 324, maxZ = 1541 }` (the arm, the walls and the Approach) |

Guards (assert, nothing changed):
- `ReplicatedStorage.WildboundGatitoArea` with `VERSION == 3`, `GROWTH == 600`, `FAR == 860`, `ARM.maxZ == 1537` ("reopen the place if an older copy is cached": Area is a shared require, not a fresh clone, because the park module reads the same one).
- `ServerStorage.WildboundKittenPark` from a fresh clone, with `buildGround`, `build`, `buildEdge`, `edgePlan`, `syncNests`, `strays`, `PART_CAP == 2800`, `#NESTS == 16`, `ROOT_NAME == Area.ROOT_NAME`.
- `ServerStorage.WildboundCandyLayout` and `WildboundCandyEast` from fresh clones (the plan's signature still takes them; unused).
- `Workspace.PuebloGatito_v1`: a Model, not SistemaSonriente (the move tool's `forbidden`, which also checks descendants), with `Ground.Floor`, `Park` and `Nests`.

Survey (read only; the same lines in the dry run and the real run):
- S1. Refuse when any SistemaSonriente part's rotated flat bounds meet `SONRIENTE_BOX` (the v9 `sonrienteHits`).
- S2. Refuse unless the deployed `ServerScriptService.WildboundPraderaSites` has all 16 `Park.NESTS` post keys in `EAST_FIXED` at the nests' post x, z (within 1e-3) and 12 `EAST_EXTRA_POSTS` rows.
- S3. Refuse when a present `AREAS` or `AREAS_BIG4` list of `ServerScriptService.WildboundBiomes` or `ReplicatedStorage.WildboundBiomeLight` (fresh clones) holds a CandyEast square whose maxZ is not 1537 (H1, H2 missing).
- S4. Warn (never touch) for every other Workspace piece (top-level, or a child of a top-level Folder or Model, the v9 `look()`) whose pivot lies in the box; `Apron_Volcanic` and `Road_big4_*` are listed under `known` instead. Warn when `Portal.station("parque2")` is missing from the deployed `ServerScriptService.WildboundPortal`.
- S5. Archive list: `Park.strays(root, Layout, East)`: every Model or BasePart directly in a `root.Park` folder whose name is not a kept item of that folder in the new plan (dropped or unknown). Expected empty.
- S6. Probe: `buildGround`, `build`, `buildEdge` and `syncNests` into a detached scratch Model; count; `scratch:Destroy()` (the tool's only Destroy). `estimate = { park, edge, ground, nests, root, beyond1024 }` (beyond1024: probe BaseParts with Position.Z > 1024). Refuse when `estimate.park > Park.PART_CAP` or `estimate.root > Park.ROOT_CAP`, or when the probe fails.

Real run (in `task.delay(0.5, ...)`, `TryBeginRecording("PuebloGatitoGrow")`, `pcall`, Commit or Cancel; the survey runs again first and any refusal stops it):
1. Backup: a clone of `PuebloGatito_v1` into `GatitoGrowBackup` (an existing one is kept and the summary warns).
2. `Park.buildGround(root)`: the Floor conformed in place to 600 x 1200 at (297, 0, 937); the Approach made.
3. The S5 list reparented into `GatitoGrowArchived` (never destroyed).
4. `Park.build(root)`: the six GL-D9 rows conformed (moved), the garden laid.
5. `Park.buildEdge(root)`: `Edge.Walls` (3) and `Edge.Hedge` (100 models).
6. `Park.syncNests(root)`: K4, K5, K7, K8 re-flagged; K9..K16 made.
7. Rebuild: `buildGround`, `build` and `buildEdge` must report created 0 and changed 0, and `syncNests` 0: asserted, so a failure cancels the whole recording.
8. The mark `PuebloGatito = 3` (`Key` stays "pueblo-gatito").
9. Summary: `partsBefore` and `partsAfter` (root and per folder), the estimate, archived, created, rebuild, warnings, refused, `overCap = partsAfter.gatito > Park.ROOT_CAP`.

`RESTORE = true` (with `DRY_RUN = false`): needs the mark 3 and `GatitoGrowBackup`. In one recording, `PuebloGatitoGrowRestore`, the live root goes into `GatitoGrowReverted` and the backup clone goes back into Workspace. It goes with a git revert of the GL modules.

Idempotent: a second run finds the mark and returns "already"; a second quick real run checks the mark again inside its `task.delay`. The old move tool errors at its `Area.VERSION == 2` assert (kept as a record). `Park.VERSION` 1 → 2 (the live `Park` folder's Version attribute says it was grown).

### GL-D15, budgets (GL-PD4, GL-PD9)

| Item | Parts |
|---|---|
| `Park.BUDGET` (K-D18, the K-D half, unchanged) | 1392 (1378 after its 14 dropped parts) |
| `Park.GARDEN_BUDGET` | 1211 (0 dropped) |
| Park folder planned | **2589** (2603 before drops) |
| `Park.PART_CAP` | 1400 → **2800** (211 headroom) |
| `Ground` (Floor + Approach) | 2 |
| `Edge` (`Park.EDGE_PARTS`) | 203 |
| `Nests` (16 x `NEST_PARTS`) | 32 |
| `PuebloGatito_v1` total | **about 2826** |
| `Park.ROOT_CAP` = PART_CAP + EDGE_PARTS + 2 + 16 x NEST_PARTS | 3037 |

- Density: the park folder is 2589 / 582,400 sq studs of space = 4.45 per 1000 (Caramelo v9: 4.80). The garden alone is 3.88: lighter than the K-D half (5.10), because the walks and lawns carry the hunt.
- PointLights 12 → 19 (no shadows). SurfaceGuis stay 9. The second portal adds 5 runtime parts and 1 light (the service's folder).
- One place holds Caramelo (2798) and the park (about 2826). No phone measurement exists; AGENTS.md wants one before calling it fine (risk R1).

### GL-D16, what else stays (GL-PD10 and the readers)

- **Apron_Volcanic** is left alone (GL-PD10): the floor covers the arm, so the basalt only shows outside it (z 313..337 beside the road).
- **Atmosphere: no change.** The Gatuno Day fogEnd stays 1100, about the floor's 1120 length, as Caramelo's 900 is for its 1120 plot. The tower appearing out of the haze as you walk in is the goal reading as a goal; a Play check, not a code change.
- **Music:** `Kittens.PARK = Area.rect()` follows on its own (x 22..542, z 340..1460; off past z 1484 at the far end). The lawn between x 566 and the east hedge (x 589..597) is past the leave margin and silent (risk R8).
- `WildboundCandyNests`, `WildboundCandyRestingService`, `WildboundBeasts.server`, `WildboundBeastConfig`, `WildboundBeastDirector`, `WildboundCandySmarts` (the wall clamp), `WildboundCandySky`, `WildboundCandyCloudWall`, `WildboundWorld.client`: no change (no coordinates of their own, or lists they already walk).
- The four kittens' rows, zones, music, light and texts; the gate, arrival disc and "parque" station; the K-D half's 194 items; the internal tag CandyEast; `GATE_CORRIDOR`, `archiveAnnex` and `clearGate` (obsolete, kept).

### GL-D17, the walk home (GL-PD11)

The hub is at (282, -3). An egg from K16 (world z 1330) walks about 1335 studs to the hub, past K12..K1's territory zones; from the far plaza about 1420. The empty-handed walk back is solved by "parque2". Recorded as a risk (R3); a playtest decides whether the deep Epica nests need anything more.

## File-by-file changes

Three disjoint groups; each group owns its files only. The interface between them is fixed here:
- Area: `VERSION 3`, `HALF 260`, `GROWTH 600`, `FAR 860`, `ARM` to 1537, `rect()`.
- Park: `VERSION 2`, `PART_CAP 2800`, `GARDEN_BUDGET`, `GARDEN_SEED`, `EDGE`, `EDGE_PARTS 203`, `ROOT_CAP 3037`, `FLOOR { size, centre }`, `APPROACH`, `NESTS` (16), `PORTAL2`, `plan(L, East, options)`, `buildGround(root)`, `edgePlan()`, `buildEdge(root)`, `strays(root, L, East)`, `syncNests(root)`, kind `hedge`.
- Sites: `EAST_FIXED` K1..K16, `EAST_EXTRA_POSTS` 12 rows. Portal: `STATIONS` 4 rows with "parque2".

### (A) the frame and the park module

- `src/wildbound/WildboundGatitoArea.luau`: GL-D1 (VERSION, GROWTH, FAR, ARM, `rect`, header comment). `--!strict` is not used there; keep the style.
- `tools/WildboundKittenPark.luau`:
  - header comments (520 x 520 → the arm floor; the garden; the edge; the tool);
  - `Park.VERSION` 2; `FLOOR` from ARM with `centre`; `APPROACH`; `EDGE`, `EDGE_PARTS`, `ROOT_CAP`, `GARDEN_SEED`, `GARDEN_BUDGET`; `PART_CAP` 2800;
  - `parkNest` and the 16 `NESTS` rows (K4, K5 Comun; K7, K8 Rara; K9..K16), the rarity comment ("grows with depth");
  - `PORTAL2`;
  - the six moved `LOCAL` rows (GL-D9);
  - the `GARDEN` table (GL-D7, GL-D8);
  - `R.hedge` (GL-D5);
  - `plan(L, East, options)`: the `grow` generator, the garden loops after each K-D loop, the `PORTAL2` drop disc, `portal2` and `space` (now 520 x 1120) in the result, the comment's 1378 → 2589;
  - `conform`'s `castShadow` override;
  - `buildGround`: the floor at `FLOOR.centre`, and `Ground.Approach`;
  - `edgePlan()`, `buildEdge(root)`, `strays(root, L, East)` (new; all refuse SistemaSonriente);
  - `syncNests` comment (sixteen nests).
- `tests/WildboundGatitoArea_Test.luau`: GA1 deliberately changed (GL-D1): VERSION 3, ARM.maxZ 1537, `rect().maxZ` 1460, `rect(16).maxZ` 1476, case name "a 520 x 1120 floor". New GL-1.
- `tests/WildboundKittenPark_Test.luau`: deliberately changed KP0, KP1, KP2, KP4, KP5, KP6, KP10, KP12; new GL-2..GL-10 (see the test plan).

### (B) the other readers

- `src/wildbound/WildboundPraderaSites.luau`: GL-D11 (8 `EAST_FIXED` rows with their world comments, 8 `EAST_EXTRA_POSTS` rows, the comment at :127-138 and :153-154).
- `src/wildbound/WildboundPortal.luau`: GL-D13 (the "parque2" row and its comment).
- `src/wildbound/WildboundBiomes.luau` (:21, :25) and `src/wildbound/WildboundBiomeLight.luau` (:33): GL-D2.
- `src/wildbound/WildboundCandyKittens.luau`: the comment at :24-27 only (z 340..1460).
- `src/wildbound/WildboundCandyKittenAmbience.client.luau`: the comment at :4 only.
- `src/wildbound/WildboundText.luau`: one line, `parque2 = "Portal del Jardín",` after `parque` under `PORTAL.names` (mixed Studio copy: this hunk only).
- `src/wildbound/WildboundCandyNests.luau`, `src/wildbound/WildboundAtmosphere.luau`: no change (GL-D10, GL-D16).
- `tests/WildboundCandyKittens_Test.luau`, `tests/WildboundCandyKittenArt_Test.luau`, `tests/WildboundCandyNests_Test.luau`, `tests/WildboundPortal_Test.luau`, `tests/WildboundBiomeLight_Test.luau`, `tests/WildboundText_Test.luau`: see the test plan.

### (C) the tool and its wiring

- `tools/wildbound-pueblo-gatito-grow.luau` (new): GL-D14.
- `tests/WildboundPuebloGatitoGrow_Test.luau` (new): GL-14, GL-15.
- `tools/studio-fresh-runner.luau`: after the GatitoArea row (:305),
  `SPECS["WildboundPuebloGatitoGrow_Test"] = { "mod:WildboundKittenPark", "mod:WildboundGatitoArea", { grow = "src:WildboundPuebloGatitoGrow", move = "src:WildboundPuebloGatitoMove" } }`, with a one-line comment naming GL-D14.
- `tools/deploy_manifest.py`: after `:400`, a comment line (GL-D14) and
  `("tools/wildbound-pueblo-gatito-grow.luau", "ServerStorage.WildboundPuebloGatitoGrow"),`
  `("tests/WildboundPuebloGatitoGrow_Test.luau", "ServerStorage.WildboundPuebloGatitoGrow_Test"),`

### Studio-only hand patches (not in this worktree)

- H1. `ServerScriptService.WildboundBiomes` (the big4 copy): the CandyEast rows of both `AREAS` and `AREAS_BIG4`, `-3, 597, 337, 937` → `-3, 597, 337, 1537` (their places in the lists kept), and the repo's GL-D2 comment lines.
- H2. `ReplicatedStorage.WildboundBiomeLight` (the big4 copy): the same two rows, `AREAS` and `AREAS_BIG4` → 1537, each still the first match of its list.
- H3. `ServerStorage.WildboundBig4Map_Test`: the "600 x 600" and "inside ±1024" checks (wb-big4 :444-445) let the south arm be 600 x 1200, z 337..1537 (as they let Caramelo end at x 1612); the apron check (:427) compares the volcanic apron with the south row's z 337..937 only; :450-452 hold unchanged (S centred on x 297; 340 = 337 + 3; the 40-stud gaps).
- H4. `ServerStorage.WildboundBeastSight_Test` (big4): south-arm samples read CandyEast to z 1537; add (297, 1500) CandyEast and (297, 1545) not.
- H5. `ServerStorage.WildboundBiomeLight_Test` (the big4 copy): the big4 rows (about :153-157) "-3,597,337,1537", plus the repo's GL-D2 changes (the CA4 samples gain (590, 1530), the row "-3,597,337,1537", the "past the far end" probe at (282, 1540), the :45 comment) and the new GL-13 case, all as hunks.
- H6. `WildboundText` (mixed copy): the same one-line `parque2` hunk by hand, never a whole-file deploy.
- Nothing in `WildboundServer`, `WildboundWorld` or `WildboundWorldClient`.

Deploy order: groups A, B, C modules and suites (manifest; by hand, never from the manifest: Text, and WildboundBiomes, WildboundBiomeLight and WildboundBiomeLight_Test, whose Studio copies are the big4 ones with `AREAS_BIG4` and a layout argument to `presetAt`, so a manifest deploy would put the classic repo copies over them), then H1..H6, then the suites in the fresh runner, then the grow tool DRY_RUN, then the real run, then save; all in one Edit session and before any Play (otherwise `CandyNests.applyFlags` lays K9..K16 over the old floor's void and the posts' rest rays miss).

## Test plan

### Deliberately changed (each with a "Deliberately changed (GL-Dn): ..." note)

- GatitoArea_Test GA1 (GL-D1): VERSION 2 → 3; ARM.maxZ 937 → 1537; `rect().maxZ` 860 → 1460; `rect(16).maxZ` 876 → 1476; the case name.
- KittenPark_Test:
  - KP0 (GL-D14, GL-D15): `Park.VERSION` 1 → 2; `PART_CAP` 1400 → 2800 (the K-D18 table and its 1392 stay).
  - KP1 (GL-D1, GL-D13): `space.maxZ` 860 → 1460; every item also outside PORTAL2's 12-stud disc.
  - KP2 (GL-D10, GL-D11): 8 → 16 nests, ids K1..K16; counts 3/3/2 → 5/6/5; the posts' band lx -170..180 → -170..760 (|lz| <= 180 stays); the guard table extended with the 8 GL guards.
  - KP4 (GL-D15): per folder = K-D18 + GARDEN_BUDGET minus the drops; "under 1400" → `PART_CAP` 2800; chests K1..K16; nests 16 → 32 parts.
  - KP5 (GL-D8): lights 12 → 19 (8 + 7 tall + 4 lit).
  - KP6 (GL-D10): `syncNests` makes 16.
  - KP10 (GL-D5): `EXPECT.hedge = 2`.
  - KP12 (GL-D3): the floor 600 x 1200 at (297, 937), `FLOOR.size[1]` = ARM width; Ground holds 2 parts; first call creates 3; `syncNests` 16.
- CandyKittens_Test (GL-D1, GL-D2, GL-D11): SPACE.maxZ 860 → 1460; ARM.maxZ 937 → 1537; SHEET `extra` → `extras` (three keys per kitten); POSTS gains the 8 world literals; KK5 counts 8 → 16 posts, 4 → 12 east extras, one → three per kitten, the window lx -170..760; "eight park nests" → 16; islands 8 → 16.
- CandyKittenArt_Test (GL-D1): `PARK.maxZ` 860 → 1460 (:263) and the `inPark` probes at :281-286 move with it.
- CandyNests_Test (GL-D10): the Legendaria fixture "K9" → "K99" (`byId.GatitoK99`, :796, :816).
- Portal_Test PT-8 (GL-D13): 3 → 4 stations.
- BiomeLight_Test (GL-D2): :92 "-3,597,337,937" → "...,1537"; :98 samples gain (590, 1530); :106 the "past the far end" probe (282, 940) → (282, 1540); the :45 comment.
- Text_Test (GL-D13): the names loop gains "parque2", and `P.names.parque2 == "Portal del Jardín"`.

### New

- GL-1 (GatitoArea): GROWTH 600, FAR 860 = HALF + GROWTH; `rect()` corners are `world(-260, -260)` and `world(860, 260)`; the floor rectangle lies in the arm with margins 3 (gate), 25 (west), 55 (east), 77 (far end); round trips at (860, 260) and (937, -315).
- GL-2 (KittenPark): `GARDEN_BUDGET` per folder and total 1211; the recipe composition per folder (as KP10 does for K-D18); `GARDEN_SEED` 8728; K-D18 + garden = 2603.
- GL-3: `plan(L, East, { garden = false })` against the full plan: every item of the former is in the latter with the same x, z, variant and yaw (the yaw of LanternShort_15..18 excepted: they face M2 only in the full plan); the dropped ids are the same in both.
- GL-4: the six moved rows at their GL-D9 world points; the tower 20 from M2's end; M2's last point (282, 1400).
- GL-5: K9..K16 at their GL-D10 world points (nest, post, chest); every Rara deeper (lx) than every Comun and every Epica deeper than every Rara; every Epica at lx >= 260.
- GL-6: no garden row is dropped (every garden id is kept); M2 has 123 slabs, 8 strips, 7 joints; GN 19, GS 17, GT 55, GV 55 stones.
- GL-7: `PORTAL2` = `Area.world(775, 55)` = (227, 1375); at least 85 from every post.
- GL-8: `edgePlan`: 3 walls with the GL-D4 numbers and flags; 100 hedge items (40/40/20) with the GL-D5 lines and lengths, all inside the arm and outside `rect()`; `buildEdge` into a detached Model twice (second 0/0), 203 BaseParts, walls invisible and solid, hedge decor, a moved wall set back; refuses SistemaSonriente (KP9 gains `buildEdge` and `strays`).
- GL-9: `strays` on a detached fixture: a planted "Junk" in `Park.Toys` and a built `TreeL_01` (a K-D drop) are listed, planned items are not.
- GL-10: `buildGround` lays `Ground.Approach` 20 x 1 x 13 at (282, 0, 330.5), top 0.5, role floor.
- GL-11 (CandyKittens): the 8 new posts at their world literals, in CandyEast and not Meadow, each wake rule and frenzy rule, reach inside the space by 10, 85 apart from all 16.
- GL-12 (Portal): "parque2" built, (227, 1375), y 0.5, yaw 0 = `Area.worldYaw(90)`, CandyEast, not Meadow, outside every safe zone, at least 300 from the hub, at least 85 from every `EAST_FIXED` post.
- GL-13 (BiomeLight): (297, 1500) is Gatuno with Day rules; `Biomes.at(297, 1500).CandyEast` is true.
- GL-14 (PuebloGatitoGrow, source pins): `local DRY_RUN = true`, `local RESTORE = false`, the Edit-mode assert, `MARK` "PuebloGatito" with needs 2, `root:SetAttribute(MARK, Area.VERSION)`, the three folder names, both recording names, `task.delay(0.5, function()`, `Enum.FinishRecordingOperation.Cancel`, the summary attribute, the `SONRIENTE_BOX` literal, `Park.buildGround(root)`, `Park.build(root, Layout, East)`, `Park.buildEdge(root)`, `Park.syncNests(root)`, `Park.strays(`, `Park.PART_CAP`, `Park.ROOT_CAP`, exactly one `:Destroy(` (`scratch:Destroy()`), no `rbxassetid`; the old move tool still asserts `Area.VERSION == 2`.
- GL-15: the module agrees with the tool: `Park.PART_CAP` 2800, `Park.EDGE_PARTS` 203, `Park.ROOT_CAP` 3037, `#Park.NESTS` 16, and the tool's box covers `Area.ARM` grown by the 4-stud walls and the Approach.

### Play checks (after the real run)

- Walk from the hub to the far plaza and back: no grey gap, no void, the walls stop you at the edges, the hedge reads as a border.
- Kittens wake at K9..K16, rest at their posts, chase and give up as before.
- "parque2" refuses a carrier and takes an empty-handed player home.
- The music stays on through the arm (check the east lawn).
- The far end streams in; measure the frame rate on a phone (R1).

## Open risks

- R1. Phones: about 2826 parts in the park beside Caramelo's 2798, 19 lights. No device measurement yet.
- R2. The big4 hand patches H1..H5 are load-bearing and live only in Studio; the grow tool refuses without H1, H2. The wb-big4 branch copy is older and needs the row at merge.
- R3. The walk home from the Epica nests (about 1335 studs): playtest.
- R4. Rarity re-spread: K4, K5 drop to Comun and K7, K8 to Rara, so the near half pays less; playtest.
- R5. Edit-mode module cache: an Area required at VERSION 2 earlier in the session fails the tool's assert; reopen the place.
- R6. Deploy-before-grow: anything that runs `syncNests` or the posts before the grow (a Play) stands K9..K16 over void; the deploy order above avoids it.
- R7. Hand-checked geometry: the dry run's `dropped` must equal the K-D drops (TreeL_01 and the K-D scatter, 14 parts) and nothing else; a garden drop means a row to move.
- R8. The east lawn (x 566..597) is past the music's leave margin.
- R9. The old big4 road's leg 4 (x 582..624, z 435..449, top 0.62) now lies over the park floor's east margin and crosses the east hedge: a look item.
- R10. Fog: the tower is barely visible from the gate (1074 of 1100); a look check.
- R11. The invisible walls answer queries (as Caramelo's): a beast's sight ray at the very edge can be blocked; no post is within 100 of them.
- R12. Streaming of the far half; the dry run reports the parts past z 1024.
