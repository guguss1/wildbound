Caramelo plot geometry: source-of-truth report (read-only; no files edited, no Studio tools used)

Coordinates. Everything is plot-local: world = local + CENTRE (672, -3). x runs east and z is the same as in the world. Most v8 positions are a v7 literal times S = 1.3. I computed the values below from the source formulas, and checked the river and nest arithmetic with a PowerShell calculation.

## 1. Constants

### tools/WildboundCandyLayout.luau (requires nothing, pure)

**Identity and version**
- ROOT_NAME "Candy_Bioma_v1" (:10)
- VERSION 3 (:16; kept at 3 on purpose, see section 4)
- SEED 20261114 (:17)

**Plot size and shape**
- CENTRE (672, -3) (:24)
- HALF 260 (:25)
- V8 = { S 1.3, OLD_CENTRE (612, -3), OLD_HALF 200 } (:26)
- fromV7Local(x, z) = (1.3x, 1.3z) (:29-31)
- fromV7World(x, z) = (672 + 1.3(x-612), -3 + 1.3(z+3)) (:34-37)

**Floor and flags**
- FLOOR_TOP 0.5 (:51)
- PATH_WIDTH 14 (:52)
- SPAWNS_ENABLED false (:54)
- NESTS_ENABLED true (:57)

**Entrance, junction, Torta, boss, portal**
- ENTRANCE = (-HALF, 0) = (-260, 0), world (412, -3) (:60)
- FORK (-143, 0) (:61)
- JUNCTION (0, 0) (:64)
- TORTA (148.2, 0), radius 42 (:66-67). It is scaled, not tied to the east edge. Its plaza edge is 53.8 studs from the east edge.
- BOSS (:73-74):
  - centre (148.2, 0)
  - plazaRadius 58, territoryRadius 76
  - perception 36, whipLength 22
  - home (98.2, 0)
- PORTAL (-31.2, 0), quiet 5, channel 2, cooldown 30, enabled true (:79-80)

**Routes (:83-94).** Each is a polyline of points; paths are PATH_WIDTH wide.

| Route | Points |
| --- | --- |
| main | (-260,0) (-143,0) (0,0) (90.2,0). The last point is TORTA.x - plazaRadius. |
| left | (-143,0) (-130,-104) (-65,-182) (65,-182) (117,-143) (0,0) |
| right | (-143,0) (-117,91) (-52,156) (52,156) (104,130) (0,0) |
| deep | (0,0) (-31.2,0) |

- ROUTE_ORDER: main, left, right, deep
- RETURN_ROUTES: left, right

**Legacy syrup lake and biscuit bridge (pre-v3)**
- BRIDGE (0, -182), length 86 (:101-104)
- LAKE discs (:108-112): (0,-162) r24, (26,-176) r16, (-26,-176) r16
- These are not the live chocolate. They are still read by WildboundCandyBuilder.luau:528, 1169-1175 and WildboundCandyFlyers.luau:173.

**KEEP_CLEAR (:119-126)**
- (214.5, 195) r26, La Nube's pond
- (-78, 240.5) r10, La Abeja's hive
- (250, 0) r16, "Cloud gate to Caramelo Este". This row is stale: the gate was removed in PGM-D5.

**NESTS (:129-163): 28 nests.** Each entry is { id, rarity, x, z, eventOnly = (rarity == Legendaria) }.

| Rarity | Nests, plot-local |
| --- | --- |
| Comun | C1 (-208,-23.4), C2 (-182,31.2), C3 (-117,-171.6), C4 (-80.6,169), C5 (78,197.6), C6 (13,-210.6), C7 (6.5,184.6), C8 (78,-221), C9 (-175.5,-80.6), C10 (-78,-210.6), C11 (-39,195), C12 (-169,-130), C13 (130,-195) |
| Rara | R1 (-101.4,-39), R2 (-101.4,44.2), R3 (-58.5,-120.9), R4 (-26,123.5), R5 (114.4,145.6), R6 (124.8,-158.6), R7 (-150.8,75.4), R8 (-143,123.5), R9 (-78,91), R10 (-13,-58.5), R11 (46.8,96.2) |
| Epica | E1 (-44.2,-26), E2 (-44.2,31.2), E3 (0,46.8) |
| Legendaria | L1 (46.8,-28.6), event-only |

**TOWER (:174-202)**
- Scale = 42/36.
- Tiers: radius 42 / 32.67 / 23.33 / 14, tops 21 / 38.5 / 53.67 / 65.33.
- Spin period 140 s, directions {1, -1, 1, 0}.
- Stair: width 7.4, inset 0.45, tread 5.2, maxRise 1, startDegrees -100, landingDegrees 15; 67 steps.
- Summit nest T1, Legendaria (not event-only), at (148.2, 9.4), scale 1.
- Glaze puddles, r 6: (148.2,52), (204.2,9), (109.2,34).

**Helpers**
- stairSteps (:206)
- flat (:226)
- depth(x, z) = HALF - max(|x|, |z|) (:231-233)
- segmentDistance (:236)
- routeDistance (:245)
- routeLength (:258)
- world(p, centre) (:267)

### tools/WildboundCandyV3Layout.luau (requires nothing, pure)

**Version and identity**
- VERSION 4 (:39)
- V8 = { S 1.3, HALF 260, OLD_HALF 200 } (:42). This is its own copy, pinned equal to Layout by V3Layout_Test:55-56.
- Marks: V4_MARK "CaramelV4", V5_MARK "CaramelV5", MARK and FOLDER "CaramelV3" (:46-51)
- SEED 20261117 (:52)
- Tags: BEAST_PASS_TAG and BEAST_OVERHEAD_TAG (:57-58)
- KIT_FOLDER and ASSETS, 16 kit names (:62-67)

**Chocolate**
- LIQUID: depth 3.5, color (92,52,34), transparency 0.08 (:75)

**MOUNTAINS (:85-107)**
- M1 is tied to the north edge. Its shift is M1_DX = -1.2 and M1_DZ = HALF - 24 - 176 = 60.
- The others are scaled.

| Id | Position | Scale | r | Height | Note |
| --- | --- | --- | --- | --- | --- |
| M1 | (-5.2, 236) | 0.45 | 24.3 | 40.7 | faces (-13.2, 198); feeds the river |
| M2 | (234, -117) | 0.4 | 14.2 | 24.1 | |
| M3 | (98.8, 243.1) | 0.37 | 13.1 | 22.3 | |
| M4 | (214.5, -156) | 0.37 | 13.1 | 22.3 | |
| M5 | (-241.8, -241.8) | 0.37 | 13.1 | 22.3 | |
| M6 | (-243.1, 243.1) | 0.37 | 13.1 | 22.3 | |

**RIVER (:123-160):** 24 points of { x, z, w }. The list is in section 5.
- RIVER_TOP_Z = 1.3Â·120 + 4 = 160 (:123)

**Pool and waterfall (:166-172)**
- POOL (-8.44, 219.36), r 4.95
- WATERFALL (-7.82, 222.3): width 7, top 15.17 (studs above the floor), faces the pool, 5 streaks, flowSpeed 12

**LAKE (:181-190): 2 discs**
- Disc 1: (10.4, -127.4), r 34.5
- Disc 2 (west lobe): (-18.2, -148.2), r 18
- withDisc keeps each attached piece's v7 offset from its disc. Disc 1 adds (+2.4, -29.4); disc 2 adds (-4.2, -34.2).

**Bridges**
- BRIDGE_BUILD (:201): width 15, deck 4.1 (top above the floor), ramp 9, gapWidth 8, sideRamp 9.
- BRIDGES (:205-229) are computed. Deck centre, direction (ux, uz) and length:

| Id | Route | Deck centre | Direction (ux, uz) | Deck length | Rail gaps |
| --- | --- | --- | --- | --- | --- |
| Top | right, leg (-52,156)â†’(52,156), at 40.3 | (-11.7, 156) | (1, 0) | 28 | gap at 0 |
| RightLast | right, (104,130)â†’(0,0), at 126.83 | (24.77, 30.96) | (-0.6247, -0.7809) | 11 | none |
| Main | main, (0,0)â†’(90.2,0), at 39.65 | (39.65, 0) | (1, 0) | 11 | none |
| LeftLast | left, (117,-143)â†’(0,0), at 145.12 | (25.10, -30.68) | (-0.6332, 0.7740) | 11 | none |
| Bottom | left, (-65,-182)â†’(65,-182), at 98.8 | (33.8, -182) | (1, 0) | 28 | gap at 0 |

**HOUSES (:240-248).** Positions are scaled; r and scale are not.

| Id | Position | r | Scale | Turn |
| --- | --- | --- | --- | --- |
| H1 | (-192.4, 215.8) | 28 | 1.4 | |
| H2 | (-130, 227.5) | 15 | 1 | 180 |
| H3 | (-205.4, -195) | 22.4 | 1.4 | |
| H4 | (231.4, 130) | 20 | 1 | |
| H5 | (-218.4, -106.6) | 21 | 1.4 | 180 |
| H6 | (195, -221) | 16 | 1 | |
| H7 | (143, 231.4) | 20 | 1 | |

- HOUSE_PLACEHOLDER (:250)

**Docks and raft**
- DOCKS (:263-275), stand and tip:
  - A (disc 2): stand (-42.2, -150.2), tip (-26.2, -148.2)
  - B (disc 1): stand (50.4, -133.4), tip (34.4, -131.4)
- RAFT: asset CV3_BananaRaft, homeDock 1 (:276)
- DOCK: deckWidth 6, tipGap 5, rampBack 10, deckOver 0.4 (:280)

**Licorice, cake, platforms, island**
- LICORICE (-161.2, 0): scale 0.8, height 27, span 62.3, feet {20.6 r 5.7, 34.8 r 4.5} (:286)
- CAKE (-195, 145.6): scale 0.8, r 18, rampReach 38.5, faces (-195, 0), height 21.6 (:291)
- PLATFORMS (:296-308):
  - CookieM (-10.2, -154.2), r 6.7
  - CookieL (2.4, -117.4), r 11.7
  - CookieS (22.4, -115.4), r 3.9
  - CookieS (-17.6, -119.4), r 3.9
- PLATFORM: over 0.5, pedestalShare 0.8 (:309)
- ISLANDS (:319-324): I1 (18.9, -102.4), r 6, flat 4, foot 9.9
- ISLAND: top 1.1, bankDegrees 42, sectors 16 (:328)

**Trees, filler, edge hills, edge fill, backdrop**
- TREES (:336). FILLER: bankEvery 22, bankOffset 7, perHouse 3, hills 4, reach 4 (:347).
- CRYSTAL (:357). CRYSTAL_HILLS (:359-373) are tied to the east edge at x = HALF - 2 = 258, with z scaled:

| Hill | z | Scale | r |
| --- | --- | --- | --- |
| Hill_1 | -247 | 0.5 | 17.75 |
| Hill_2 | -162.5 | 0.45 | 16 |
| Hill_3 | -78 | 0.5 | 17.75 |
| Hill_4 | 78 | 0.5 | 17.75 |
| Hill_5 | 162.5 | 0.28 | 9.94 |
| Hill_6 | 247 | 0.5 | 17.75 |

- EDGE fill (:380-386): bandMin 4, bandMax 45, spacing 13, interiorSpacing 26, emptyRadius 22, maxTrees 60, maxProps 60, maxHills 4, maxParts 600.
- BACKDROP_V7 is a record only. BACKDROP = {}, so it is empty (:394-410).

**Clearances and budget**
- CLEAR (:413-422): nestFromLiquid 6, postFromLiquid 8, pieceFromNest 8, pieceFromPost 6, pieceFromRoute 3, pieceApart 2, trapFromAnything 10, edgeDepth 2.
- MAX_NEW_PARTS 1300, BIOME_PART_CAP 2800, V4_PART_TARGET 2700 (:426-430).

**Geometry helpers (:433-626)**
- flat, segmentDistance, riverDistance, islandDistance, islandAt, liquidDistance, riverLength
- bridgeFrame, onBridge, surfaceY, faceYaw, kitPoint
- houseFootprints, houseYaw, dockPoints, pieces, clearOfPieces, nearBridge, bridgeCorners, riverSamples

### src/wildbound/WildboundPraderaSites.luau

**Copies of the layout**
- MEADOW_CENTRE (672, -3) (:21), a copy of Layout.CENTRE
- OFFSETS from the WildboundPradera marker (:26-31): pond (195, 52), colmena (-97.5, 97.5), gate (-241.8, 0), plaza (-52, 18.2)
- HOME map (:33-39)

**FIXED posts (:60-84).** beside(nest v7, offset) = 672 + 1.3Â·nx + dx, -3 + 1.3Â·nz + dz. World values:

| Post | World position |
| --- | --- |
| candyNest | (458, -20.4) |
| candyNestR1 | (578.6, -50) |
| candyNestC3 | (543, -182.6) |
| bossHome | (770.2, -3) |
| bossTerritory | (820.2, -3) |
| candyNestC2 | (484, 41.2) |
| candyNestR2 | (575.6, 53.2) |
| candyNestR3 | (625.5, -113.9) |
| candyNestR4 (by nest C5) | (756, 208.6) |
| candyNestC4 | (583.4, 178) |
| candyPostC7 | (685.5, 172.6) |
| candyPostR6 | (803.8, -156.6) |
| candyPostC8 | (745, -212) |
| candyPostC9 | (507.5, -79.6) |
| candyPostR7 | (511.2, 80.4) |
| candyPostR5 | (794.4, 152.6) |
| candyPostC6 | (675, -205.6) |
| candyPostC10 | (606, -205.6) |
| candyPostE3 | (660, 43.8) |
| candyPostR8 | (541, 120.5) |
| candyPostR9 | (606, 88) |
| candyPostR10 | (668, -53.5); special offset (9, 8) |
| candyPostC11 | (633, 180) |
| candyPostC12 | (515, -133) |
| candyPostC13 | (790, -197) |
| candyPostR11 | (709.8, 101.2) |

**Other tables**
- EXTRA_POSTS: 16 rows (:91-102)
- EAST_FIXED and EAST_EXTRA_POSTS: the kitten park, outside this plot (:120-135)
- AMBUSH (:145-153): everySeconds 15, chance 0.75, maxActive 3, minStuds 25, maxStuds 40, half 260, edgeStuds 10, entrance (-260, 0), entranceStuds 30, entranceSpotStuds 80, bossClearStuds 126

### src/wildbound/WildboundCandyNests.luau
- Nests are read from the live markers (Workspace.Candy_Bioma_v1.Nests.Nest_<id>, attributes NestId, Rarity, Enabled, EventOnly, House, LakeIsland). The position comes from GetBoundingBox; the top comes from the bowl PrimaryPart (:262-295). Nothing is read from Layout.
- BIND_RADIUS 20 (:27): a guardian post guards the nearest nest within 20 studs. House, island and park nests are never bound (:94-97).
- posts(Sites) uses only the 3 GUARDIANS (Gomibu, Flanfuria, Tortidragon), their home posts and their EXTRA_POSTS (:66-83).
- applyFlags runs the builder syncs: nests, portal, tower, house nests, hide spots, grass, traps, island, park (:174-256).
- Because nests come from markers, moving nests means moving the markers in the live map (builder or migration). Changing the layout alone does not move them.

### Zones
- There are no explicit "zone" constants in these files. The zones are:
  - the rarity depth rings, pinned in tests/WildboundCandyLayout_Test.luau:110-120: Comun depth 0-97.5, Rara 97.5-208, Epica and Legendaria 208-260, using the square depth;
  - BOSS plaza and territory;
  - KEEP_CLEAR.
- Every nest island entry has zone = "outside" (WildboundCandyNests:128).

## 2. How the river is described and used

**Shape**
- A polyline of 24 control points { x, z, w }, where w is the width at that point (V3Layout:123-160). There is no curve, no per-point depth and no terrain.
- Depth is global: LIQUID.depth 3.5. The surface is FLOOR_TOP + 3.5 (surfaceY, :503).

**Width rule**
- Each leg counts as wide as its wider end: math.max(a[3], b[3]) (:449, :618).
- riverDistance = distance to the segment - max(w)/2. A negative value means inside (:445-452).
- liquidDistance = min(river, pool, lake discs), then max with -islandDistance (:471-476).

**How it is built** (WildboundCandyV3Builder.luau:468-507, layLiquid). All of these are parts made by liquid(): no collision, no queries, walk-through.
- At each point, a drum "Choco_Joint_i" of radius w/2 and height 3.5. It is skipped on the edge point via L.depth > 0.01 (:475).
- On each leg, a block "Choco_River_i" of size (max w) x 3.5 x leg length (:483).
- Two decor banks "Bank_i_k", 2.4 x 0.9, at max w/2 + 1.2 either side (:489-493).
- The pool drum and the lake drums.

**Where the width is used downstream**
- Raft.area (WildboundCandyRaft.luau:78-90): the hull is allowed where liquidDistance <= -HULL (3) and not nearBridge(r). So every bridge footprint (deck + end ramps + side ramps, V3:587-595) is a wall for the raft.
- Current.flow (WildboundCandyCurrent.luau:33-65):
  - speed 4 on the river, 1.5 in the lake (LAKE_BLEND 8)
  - eased over EDGE 2 from the bank
  - direction from the nearest leg's centreline, blended within JOIN 6
- WildboundCandyWade.luau:39: wading.
- Clearance placement off the chocolate:
  - Grass :107, HideSpots :131, Traps :118
  - V3Builder :1085 and :1387
  - V3.clearOfPieces :574
- riverSamples: the bank filler sits at w/2 + bankOffset 7 (V3Builder:793-803).
- WildboundCandyLife.luau:158-169: 10 hand-placed fish spots (5 river, 5 lake) whose points are pinned by its suite against liquidDistance.
- Clearance rules: nest 6 and post 8 beyond the liquid (V3.CLEAR).

**Today's widths**
- 12 at the outlet
- 19 / 19.5 between post C11 and nest C7
- 24 on the open legs
- 16 by E3
- 10 on the junction arc (points 10-17, radius 39.65 round the junction)
- 14 and 20 into the lake
- 24 to the south edge

Length about 500.8 studs.

**A 5x river on today's course (my calculation)**
- Nine nests fall inside it: R4, L1, C6, C7, C8, E3, R10, R11, C11.
- Eight posts fall within 8 studs: candyNestR3 (5.0), candyPostC11, C6, C7, C8, E3, R10, R11.
- Also inside: dock B (stand and tip), dock A's tip, the island, CookieL, M1 and every bridge (decks of 28 and 11 against widths of 50-120).
- The junction is 6.7 studs outside it.

## 3. Places that assume a square plot (single HALF)

**In my scope**
- Layout.HALF (:25) and depth() = HALF - max(|x|, |z|) (:231-233). Used by the rarity rings and many clearances.
- ENTRANCE = -HALF (:60).
- fromV7Local/fromV7World use one S for both x and z (:29-37).
- KEEP_CLEAR gate x = 250 (HALF - 10 as a literal) (:125).
- V3.V8.HALF copy (:42).
- M1_DZ = HALF - 24 - 176 (north edge, so HALF is used as the z half) (:85).
- The last river point z = -HALF (south edge) (:156).
- CRYSTAL_HILLS x = HALF - 2 (east edge, so HALF is used as the x half) (:369).
- WildboundPraderaSites:
  - AMBUSH.half 260 and entrance (-260, 0) (:151)
  - ambushRoll uses max(|lx|, |lz|) > half and half - max(...) < edgeStuds (:171, :178)
  - a single V8_S (:60)

**Elsewhere, from grep (not read in full)**
- WildboundCandyBuilder.luau:
  - :434 and :517 (depth; x > HALF - 42)
  - :608 and :1278 (x range -HALF+10..HALF-42)
  - :709-712 and :1315-1338 (scatter bands +-HALF)
  - :1160 (Floor size HALF*2 x HALF*2)
- WildboundCandyV3Builder.luau:
  - :411, :475, :956 (depth)
  - :820-826 (edge hills on 4 edges +-HALF)
  - :953-963 (edge-fill grid +-H)
- Other modules:
  - WildboundCandyDuquesa.luau:163-165 (plotDepth, Chebyshev with HALF)
  - WildboundCandyFlyers.luau:162 (depth) and :314 (square bounds); WildboundCandyFlyersService:83 (bounds half = HALF)
  - WildboundCandyGrass:106, HideSpots:130, Traps:117 (depth)
  - WildboundCandyEast.plan :82-85 (plot square, band and space; shift = 2*HALF + BAND)
- Migration and build tools:
  - wildbound-caramelo-v8-migrate.luau :101 (asserts HALF == 260), :175 (EAST_EDGE = CENTRE.x + HALF), :423 and :545 (floor HALF*2 both ways)
  - wildbound-kitten-park-build.luau:76 and wildbound-pueblo-gatito-move.luau:80 (assert HALF == 260)
- Literal copies:
  - WildboundCandyLife.luau:33-34 (CENTRE, HALF 260)
  - WildboundCandyAmbience.luau:151 (PLOT_FALLBACK 412..932, -263..257, already a rectangle)
  - WildboundCandyTrapCake (spot literals, per the v8 plan)
  - WildboundPortal (station, per the v8 plan)
- Tests that pin square or HALF:
  - Layout_Test :41, :59, :75, :110-120, :184, :196, :222, :247, :250, :283
  - V3Layout_Test :55-56, :85, :111-114, :424-425, :444-450, :512, :522, :539
  - Builder_Test :108
  - Grass, HideSpots, Traps and Island tests (floor HALF*2)
  - Nests_Test :473, :569
  - Duquesa_Test :216, :303-306, :546-557
  - East_Test :45 and :393
  - Life_Test :43, :98, :148
  - V3Builder_Test :290
  - Ambience_Test :152

**What a separate HALF_X / HALF_Z would touch**
- Everything above. depth() becomes min(HALF_X - |x|, HALF_Z - |z|), which changes what the rarity rings mean.
- The Floor size.
- The scatter and edge-fill ranges per axis.
- The AMBUSH bounds; Flyers and Duquesa bounds.
- CandyEast band length and shift.
- M1 and the river end (z), the hills (x), ENTRANCE (x).
- The KEEP_CLEAR gate literal.
- The Life and Ambience copies.

**Arithmetic, not checked in Studio**
- With the entrance fixed at world x 412, the big4 Meadow square (to x 1012) allows HALF_X up to 300 (centre 712). The cloud wall at x 932..948 would have to move.
- Beyond that, the AREAS rows and the ground (Baseplate to 1024; the empty second space x 948..1468 has no AREAS ownership by Caramelo) would need changes.
- The Torta is scaled, not tied to the edge, so it stays at local 148.2 unless it is re-anchored.

## 4. Version and migration fields
- Layout.VERSION 3 (:16): asserted by V3Builder:982 and :1608, and by the v5 migration :68. The builder writes root LayoutVersion (Builder:1386).
- Layout.V8 { S, OLD_CENTRE, OLD_HALF } and fromV7Local/fromV7World.
- V3.VERSION 4 (:39): asserted by the v8 migration :104; written as CaramelV3 folder attribute "Version" (V3Builder:1052, :1627).
- V3.V8 { S, HALF, OLD_HALF }.
- Marks: V3.MARK "CaramelV3", V4_MARK "CaramelV4", V5_MARK "CaramelV5".
- v8 migration (tools/wildbound-caramelo-v8-migrate.luau):
  - MARK "CaramelV8", needs "CaramelV5" (:55)
  - root CaramelV8 = 1 (:582)
  - backup CaramelV8Backup and archive CaramelV8Archived (:56)
  - summary attribute WildboundCaramelV8Summary (:54)
  - ChangeHistory recording "CaramelV8" (:498)
- Builder.layoutKey = "x,z,radius" of TORTA (Builder:77-79), on the GranTorta and Tower LayoutKey attribute (:174, :281, :842; migration :552).
- WildboundCandyEast.VERSION 1, KEY "caramelo-nube".
- The 1.3 transform (S and the v7 literals) is the only scaling path. A v9 would need a new transform (or new literals), a new VERSION, and a new mark.

## 5. Named points: V3.RIVER, numbered 1-24 (plot-local; world = +672, -3)

| # | Local | Width | Meaning |
| --- | --- | --- | --- |
| 1 | (-9.56, 214.08) | 12 | M1's outlet |
| 2 | (-13.2, 198) | 19 | M1 faces it; fixed |
| 3 | (-13, 170.3) | 19.5 | |
| 4 | (-11.7, 160) | 24 | 4 north of the Top bridge leg |
| 5 | (-3.9, 135.2) | 24 | east of R4 |
| 6 | (6.5, 106.6) | 24 | west of post R11 |
| 7 | (14.3, 80.6) | 24 | |
| 8 | (16.9, 70.2) | 24 | |
| 9 | (15.6, 65) | 16 | by E3 |
| 10 | (15.6, 57.2) | 10 | start of the junction arc |
| 11 | (14.625, 39.091) | 10 | |
| 12 | (24.778, 30.966) | 10 | under RightLast |
| 13 | (35.737, 17.173) | 10 | |
| 14 | (39.65, 0) | 10 | under Main |
| 15 | (35.841, -16.978) | 10 | |
| 16 | (25.103, -30.68) | 10 | under LeftLast |
| 17 | (15.041, -38.909) | 10 | |
| 18 | (15.6, -54.6) | 14 | |
| 19 | (22.1, -75.4) | 20 | between L1 and post R10 |
| 20 | (18.2, -117) | 24 | through the lake |
| 21 | (31.2, -162.5) | 24 | |
| 22 | (35.1, -182) | 24 | under the Bottom bridge |
| 23 | (37.7, -221) | 24 | between nest C6 and post C8; world (709.7, -224) |
| 24 | (39, -260) | 24 | on the south edge; world (711, -263) |

"Point 23" in the earlier survey (docs/design/wildbound-pueblo-gatito-biome-plan.md:102) almost certainly means RIVER[23]. That is the squeeze between nest C6 and post C8, both of which a 5x band swallows. I could not confirm this from the doc's text.

The only other numbered points are the stair steps (stairSteps) and the bridge, nest and house ids above.

## 6. Modules that load the layouts

**WildboundCandyLayout**
- require with WaitForChild:
  - CookieBridgeService :18
  - DuquesaService :29
  - FlyersService :22
  - FrutillonService :12
  - RaftService :22
  - TrapCakeService :18
  - WadeService :18
  - CandyEast :65 (default)
  - KittenPark :1112 (default)
  - Builder :83, :90, :124, :148, :169, :630, :881, :1087 (defaults when no layout is passed)
- WildboundServer :152 (FindFirstChild).
- lookup(): Traps :342, HideSpots :483, Grass :290, Island :255.
- module() in tools:
  - v3 migration :77, v4 :68, v5 :67, v8 :100
  - cake-move :68, tree-resize :42, queen-seat :22
  - kitten-park-build :75, pueblo-gatito-move :79

**WildboundCandyV3Layout**
- CookieBridgeService :19, RaftService :23, WadeService :19.
- lookup(): Traps :343, HideSpots :484, Grass :291, Island :256.
- v3 migration :82, v4 :73, v5 :69, v8 :103.

**Take the layout as an argument (no require):** V3Builder, Raft, Current, Wade, CookieBridge, Duquesa, Flyers, HouseNests. HouseNests is inferred from the runner specs and not read.

**Carry literal copies:** WildboundPraderaSites, WildboundCandyLife, WildboundCandyAmbience, WildboundCandyTrapCake, WildboundPortal.

**Test runner:** tools/studio-fresh-runner.luau SPECS :134-358 list both modules for about 20 suites.

**Python mirror:** tools/test_caramelo_v3.py mirrors the V3 geometry. Python is unavailable in this environment.

## Not determined
- The exact meaning of "point 23" (see section 5).
- HouseNests, TrapCake and Portal internals; the Biomes/BiomeLight big4 rows (only quoted from the v8 plan).
- Whether WildboundCandyBuilder still lays the legacy Layout.LAKE/BRIDGE on a fresh build (only the reference lines were seen).
- The live map's actual state (Studio not touched).
