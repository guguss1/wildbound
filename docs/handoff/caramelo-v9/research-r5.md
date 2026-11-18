## Caramelo: what is hard-coded for (a) a longer plot and (b) a river 5 times wider

All of this was found with Read, Grep and Glob only. I edited nothing and did not touch Studio.

**Legend**
- **D**: derived from Layout or V3Layout. It follows on its own.
- **D-sq**: derived from `HALF`, but the code assumes the plot is a square (one `HALF` for both x and z). It must be edited for a rectangle.
- **L**: a literal copy. It must be edited.
- **(a)** means the longer plot. **(b)** means the 5x river.

**One choice to make before anything else.** Every plot coordinate is local to `CENTRE`.
- If the plot becomes x 412..1452 by moving `CENTRE` to (932, -3), every local literal shifts 260 studs east in the world. That covers nests, river, houses, routes, posts and docks, and each would have to be re-expressed, or the shift handled by a new v7-to-v9 style transform.
- The other way is to keep `CENTRE` at (672, -3) and give the plot uneven extents: local x -260..+780.

Either way, `HALF` has to become two numbers (x and z), or min/max values.

### tools/WildboundCandyLayout.luau
| Line | Literal | Meaning | Kind |
|---|---|---|---|
| 20-21 | `412..932, -263..257` | Comment giving the plot's extent | L (comment) |
| 24 | `CENTRE = point(672, -3)` | Plot centre | L (a) |
| 25 | `HALF = 260` | One half side for both axes | L (a) |
| 26 | `V8 = {S=1.3, OLD_CENTRE=(612,-3), OLD_HALF=200}` | The v7-to-v8 transform. A longer x needs a new transform or new literals | L (a) |
| 60 | `ENTRANCE = point(-HALF, 0)` | West edge | D-sq (a): needs -HALF_X |
| 64-68 | `TORTA = fromV7Local(114, 0)`, radius 42 | The "cake at the east end" sits at local x 148.2, 53.8 studs from the east edge. A longer plot leaves it in the middle unless it is re-anchored | L (a) |
| 73-74 | `BOSS` and `home` | Follow the Torta | D |
| 87-92 | ROUTES main/left/right (v7 literals) | Path layout. The avenue ends at the Torta plaza | L (a, if the cake moves east) |
| 98-112 | Old v1 `BRIDGE` (86 long at v7 (0, -140)) and `LAKE` syrup discs 24/16/16 | The v1 biscuit bridge and syrup lake. `Builder.build` still lays them | L (b, overlaps the river) |
| 119-126 | `KEEP_CLEAR` row `{x = 250, z = 0, r = 16, "Cloud gate to Caramelo Este"}` | Re-anchored to the old east edge, world (922, -3). Obsolete since the gate closed | L (a) |
| 129-163 | 28 `nest()` literals | Nests. With the 5x river, about 9 are swallowed (the earlier quick survey's count; not re-checked here) | L (b) |
| 231-233 | `depth = HALF - max(abs(x), abs(z))` | Square rings, used by every edge or ring rule | D-sq (a) |

### tools/WildboundCandyV3Layout.luau (the river)
| Line | Literal | Meaning | Kind |
|---|---|---|---|
| 42-43 | `V3.V8 = {S=1.3, HALF=260, OLD_HALF=200}` | Its own copy of `HALF`, pinned by V3-1 | L (a) |
| 85 | `M1_DZ = HALF - 24 - 176` | M1 (the river's mountain) is anchored to the north edge | D-sq (uses `HALF` for z) |
| 123 | `RIVER_TOP_Z = v8(120) + 4` | The point under the Top bridge | L (b) |
| 124-149 | `RIVER_V7`: 24 points `{x, z, w}` | Widths: 12; 19, 19.5; 24 on points 4-8; 16; 10 on points 10-17 (the junction arc, radius 30.5 v7 = 39.65 v8); 14; 20; 24 on points 20-24. Times 5 gives 60, 95, 97.5, 120, 80, 50, 70, 100. **Every width is a literal.** Point 23 (v8 (37.7, -221), w 120) would leave the plot | L (b) |
| 156 | Last point `z = -HALF` | Ends on the south edge | D-sq (needs HALF_Z) |
| 181 | `LAKE_V7` r 34.5 at (8, -98), r 18 at (-14, -114) | Lake discs narrower than a 120-wide river | L (b) |
| 201 | `BRIDGE_BUILD = {width=15, deck=4.1, ramp=9, gapWidth=8, sideRamp=9}` | Deck 0.6 over the 3.5 surface. A raised bridge needs a new deck height and much longer ramps (9 studs is 24.5 degrees at 4.1) | L (b) |
| 205-211 | `BRIDGE_ROWS`: Top 28, RightLast 11, Main 11, LeftLast 11, Bottom 28, plus `at` values 31 / 97.56 / 30.5 / 111.63 / 76 | Decks must span the river. V3-4 requires every wet route sample to be on a deck | L (b) |
| 214 | `v8(114) - 58` | Main's leg ends at the plaza (copy of Torta x 114 and plaza 58) | L (a, if the Torta moves) |
| 264-268 | DOCKS A (disc 2) and B (disc 1): stand/tip literals | Two docks. B is swallowed at 5x | L (b) |
| 276 | `RAFT = {homeDock = 1}` | Home dock | L (b) |
| 280 | `DOCK = {deckWidth=6, tipGap=5, rampBack=10, deckOver=0.4}` | Dock build | L (b) |
| 298-303, 320-322 | PLATFORMS (cookies), ISLANDS I1 `withDisc(1, 16.5, -73)`, r 6 | Pieces floating in the lake | L (b) |
| 348 | `FILLER bankEvery=22, bankOffset=7` | Offset from w/2 | D |
| 361-372 | `CRYSTAL_HILLS`: `x = HALF - 2`, z `v8(...)` | Pink hills on the east edge | D-sq (a): needs HALF_X |
| 390-410 | `BACKDROP` empty; comment "cloud band local x 260..276" | Backdrop | L (comment, a) |
| 413-422 | `CLEAR` (nestFromLiquid 6, postFromLiquid 8, trapFromAnything 10, edgeDepth 2) | Clearances the wider river must still respect | D (rules) |
| 445-626 | `riverDistance`, `liquidDistance`, `nearBridge`, `onBridge`, `riverSamples`, `dockPoints` | Geometry helpers | D |

### tools/WildboundCandyBuilder.luau
| Line | What | Kind |
|---|---|---|
| 434, 517 | `depth < 10`; `x > L.HALF - 42` (east band left free for hills) | D-sq (a) |
| 608, 1278 | Scatter x range `-HALF+10 .. HALF-42` | D (x); uses `HALF` for x |
| 709-712, 1315-1316, 1320, 1332, 1338 | Z bands `Â±HALF Â±5/10` | D-sq (a) |
| 1160 | Floor `Vector3.new(HALF*2, 1, HALF*2)` | D-sq (a) |
| 1167-1176 | Old syrup Lake and biscuit `Bridge_i` tiles (uses Layout.BRIDGE/LAKE) | D (b: overlaps the new river) |

### tools/WildboundCandyV3Builder.luau
| Line | What | Kind |
|---|---|---|
| 411 | `openSpot`: `depth < reach + 3` | D-sq |
| 468-507 | `layLiquid`: one block per leg at `max(w)`, a joint drum `w/2`, banks at `w/2 + 1.2`. The part count does not depend on width | D |
| 549-596 | `layBridge`: deck at `top + B.deck`, end ramps, side ramps | D (b: a raised bridge needs new ramp and support geometry here) |
| 606-634 | `layDocks` | D |
| 793-803 | Bank filler | D |
| 816-826 | Edge hills: `along = Â±(HALF-20)`, 4 edges at `Â±HALF` | D-sq (a) |
| 953-965 | Edge fill grid `-H..H` on both axes | D-sq (a) |
| 982 | `assert(L.VERSION == 3)` | L (if the layout version is bumped) |

### tools/WildboundCandyEast.luau (the cloud wall)
- **82-85.** `plot = cx Â± half, cz Â± half`; `band` at `plot.maxX`; `space = band.maxX + 2*half`. This is D-sq. With HALF_X, the wall moves on its own to x 1452..1468 and the caps reach 1468 + 1040.
- **24-26.** A comment: the annex strips reach x 1012 and the Baseplate x 1024; past that is void. This is L, as context.

### Other tools
- **tools/WildboundCandyDuquesa.luau:163-166.** `plotDepth = HALF - max(abs(dx), abs(dz))`, a second copy of `depth`. The comment at 162 says "54 studs from the east edge". D-sq (a).
- **tools/WildboundCandyFlyers.luau:162** uses `depth`. **Line 314** uses square bounds `{x, z, half}`. D-sq (a).
- **tools/WildboundKittenPark.luau:52.** `GATE_CORRIDOR = {minX=896, maxX=932, minZ=-17, maxZ=11}` is L (a). Also at 1553, `archive` reparents everything inside `East.plan(L).space`. After the plot grows that space lies inside the plot, so re-running this one-shot is unsafe.
- **tools/WildboundCandyTrapCake.luau:21-24.** Spots (-126.1, -71.5), (-93.6, 8), (-109.4, -30). They must stay 10 studs off the chocolate. L (b): re-check them.
- **tools/wildbound-caramelo-v8-migrate.luau.** Line 101 asserts `HALF == 260`; line 175 has `EAST_EDGE`; lines 545-546 lay a square floor. It is a one-shot tool, so the live map needs a new migration tool rather than edits here.
- **tools/test_caramelo_v3.py.**
  - Line 143 reads `Layout.HALF`; line 196 has a square `depth`; lines 324 and 328 hard-code `range(-200, 201)` (v7).
  - The regexes at 91 and 114 (`V3.RIVER =`, `V3.DOCKS =`) no longer match the v8 source, which builds from `RIVER_V7`. So the file is already out of date, and Python is not available here.

### src/wildbound
| File:line | Literal | Kind |
|---|---|---|
| WildboundCandyAmbience.luau:151 | `PLOT_FALLBACK = {minX=412, maxX=932, minZ=-263, maxZ=257}` | L (a) |
| WildboundCandyLife.luau:33-34 | `CENTRE (672, -3)`, `HALF 260` | L (a) |
| Life:83-90 | FLOCKS F1-F6. Each must stay 10 or more studs off the chocolate (CL3) | L (b) |
| Life:157-170, 175 | FISH_ROWS River_N1..S3, Lake_1..4; `LAKE_DISC_V7 (8, -98)` | L (b): copies of river and lake spots |
| Life:42-50 | Copies of HOUSES | L |
| WildboundPraderaSites.luau:21 | `MEADOW_CENTRE (672, -3)` | L (a) |
| PraderaSites:64-84 | FIXED posts (nest-relative literals). Must stay 8 or more off the chocolate | L (b) |
| PraderaSites:151 | `AMBUSH half = 260, entrance = (-260, 0)` | L (a) |
| PraderaSites:171, 178 | Square tests `max(abs(lx), abs(lz)) > half` | D-sq (a) |
| WildboundPortal.luau:50 | Station `x = 640.8, z = -3` (CENTRE + PORTAL) | L (a, if CENTRE moves) |
| WildboundBiomes.luau:27 | Meadow `412, 812, -203, 197` (classic; already smaller than v8). It drives `inMeadow` and `world.inCandy`, which control summoning and damage rules (WildboundBeasts.server.luau:241-244, 672, 1064, 1189) | L (a) |
| WildboundBiomeLight.luau:35 | Same Meadow square (light) | L (a) |
| WildboundCandyRaft.luau:84 | Bridges are walls (`not V3.nearBridge`) | L-rule (b): raised bridges need a clearance rule |
| Raft:105, 109 | `#docks < 2`; `homeDock` clamped to 1 or 2 | L (b, if there are more docks) |
| WildboundCandyCookieBridge.luau:16 | `IDS = {"Top", "Bottom"}` | L (b) |
| CookieBridge:29 | `SINK = 7` (tuned to deck 4.1) | L (b) |
| WildboundCandyCurrent.luau:20-25 | `JOIN 6`, `EDGE 2`, `LAKE_BLEND 8`, speeds | D, but tuned for a narrow river: re-tune (b) |
| WildboundCandyFlyersService.server.luau:83 | `half = Layout.HALF` | D-sq (a) |

These follow on their own (D): `Raft.docksFrom`, `Raft.area`, WildboundCandyWade, CandyRaftService (iterates all docks), CookieBridgeService (uses `Cookie.IDS`), WadeService, TrapCakeService, DuquesaService, the Smarts wall (read from the live Collider), Grass/HideSpots/Traps/Island/HouseNests (read V3 at sync time).

### Suites that need deliberate changes (16)
1. **WildboundCandyLayout_Test**
   - S2 (40-49): `H == 260`, `C.x == 672`, plot within â‰¤1012.
   - Ring case (110-120), including `depth(39, -195) == 65`.
   - GT1 (247, 250): Torta in the east part, plaza â‰¤60 from the east edge.
   - V8-D1 (339-348): 412 / 932 / 257.
   - K-D2 (385-394): world 922.
2. **WildboundCandyV3Layout_Test**
   - V3-1 (55); V3-2 (82-93: widths â‰¥10, widest â‰¥20, length â‰¥340, `depth - w/2 â‰¥ 2`).
   - V3-14 (111-114, square loop); V3-4 (136-186); V3-5; V3-6; V3-8 (303 `#DOCKS == 2`, 316 homeDock 1).
   - V3-15 (425, `HALF - 2`); V3-16 (445, `HALF + 16 + 2*HALF`).
   - V3-17 (462-500): 24 widths, arc 10, lake radii, bridge lengths 28/11, docks â‰¥50 apart, open-water box -60..79, -150..-21.
   - V3-18 (505-545): pins RIVER[1], [4], [5], [14], dock and bridge offsets.
3. **WildboundCandyCurrent_Test**
   - CU2 (needs â‰¥15 open legs); CU3 dry points at 114.
   - CU4 grid x -52..78, z -262..226 (144-145); CU5 legs 6 and 18.
   - CU6/CU7 hard-code 2 docks; CU8 uses RIVER[18] and start points (-11.2, 206), (22.4, -139.4), (-2.6, -154.4).
4. **WildboundCandyRaft_Test**: RF1 at 107 (the real layout has 2 docks) and 113.
5. **WildboundCandyIsland_Test**: IS1 (60-103); IS2 dry points (-150, 0), (5, 82) at 120; IS3 hard-codes 2 docks (161-186).
6. **WildboundCandyCookieBridge_Test**: bridge ids in CB1/CB4/CB7/CB11 (56-62, 98, 139, 160, 194); CB10 `SINK > deck + 0.4` (182).
7. **WildboundCandyLife_Test**: CL1 (43); CL3 (88 off chocolate â‰¥10; 98 `|x|,|z| â‰¤ HALF-5`); CL4 (148); CL5 (fish against bridges and docks).
8. **WildboundCandyAmbience_Test**: 152-157 (412 / 932 / -263 / 257, `maxX <= 932`).
9. **WildboundCandyEast_Test**: 47-57, 78-88, 105-106, 121-123, 145-146, 155, 164, 187, 223-264, 273-283, 296-312 (every 932 / 940 / 948 / 1468 literal).
10. **WildboundCandyDuquesa_Test**: 216, 303, 306, 546-557.
11. **WildboundCandyBuilder_Test**: 108 (square floor).
12. **WildboundCandyGrass_Test**: 50, 178.
13. **WildboundCandyHideSpots_Test**: 54, 140.
14. **WildboundCandyTraps_Test**: 51, 214. In 12-14, the square fake floors and the `HALF - 2, 60` probes.
15. **WildboundKittenPark_Test**: 485 (`GATE_CORRIDOR` 896..932).
16. **WildboundCandyNests_Test**: 569 (pins `AMBUSH.half == HALF`) and 473 (`HALF + 60` probe).

**Probably passing, but re-check:** V3Builder_Test (98 part-count formula; 419, 445, 594 use RIVER[3]/[4]; 677 uses DOCKS[2]), Portal_Test (176-178, depends on the Meadow square), BiomeLight_Test (116-118, 156-157), BeastSites_Test (live raycasts), Wade_Test, Flyers_Test, Tower_Test.

**Unchanged:** Smarts_Test (804-850) and Kittens_Test (66, 284-286) use a fake wall at x 940 for a pure function. Nests_Test:725 (`post.x < 932`) stays true.

### Studio-only copies the repo mentions
- **big4 WildboundBiomes**, with `AREAS_BIG4` and Meadow x 412..1012, z -303..297. Mentioned at WildboundBiomes.luau:55-56, WildboundCandyKittens_Test:311, odd/tasks/wildbound-pueblo-gatito.md:47, :90. It must cover x up to 1452 or summoning and damage stop at x 1012.
- **big4 WildboundBiomeLight** (`AREAS_BIG4`) and **big4 WildboundBiomeLight_Test**. Mentioned at BiomeLight_Test:150-158 and pueblo-gatito.md:137-143, 156.
- **Studio-only suites:** WildboundBeastSight_Test (big4 copy) and WildboundBig4Map_Test (pueblo-gatito.md:81).
- **ServerStorage.WildboundBig4Annex.** `CANDY.floors`: Floor_Big4_1 is x 812..1012, z -303..297; the strips are resized to x 412..1012. Also `growCandyAnnex` (branch agus/big4-map, absent here) and `fluffCandyAnnex`. Mentioned at East_Test:301-312, wildbound-caramelo-tree-resize.luau:6, 19, 186, and caramelo-playfix.md:873.
- **Workspace.WildboundCandyAnnex_Big4** (v8-migrate:33, :302; KittenPark:1552). The grey Baseplate ends at x 1024 and is void past that (East.luau:24-26), so no floor exists past x 1024 except what the builder lays.
- **Mixed copies** (pueblo-gatito.md:47): WildboundText and WildboundText_Test. They do not concern the extent.
- **The live Workspace.WildboundPradera marker** (pivot (691.5, 140), PraderaSites.luau:22-25). It must move if `CENTRE` moves.

### Counts
- **Files with something to edit (L or D-sq): 20.**
  - 10 in src: Ambience, Life, PraderaSites, Portal, Biomes, BiomeLight, Raft, CookieBridge, FlyersService, plus Current (re-tune only).
  - 8 in tools: Layout, V3Layout, Builder, V3Builder, East, Duquesa, Flyers, KittenPark.
  - 2 to re-check or replace: the TrapCake spots, and v8-migrate (one-shot, needs a new tool).
- **Suites needing deliberate changes: 16.** Seven more to re-check.
- **Studio-only copies: 6 named items.**
- **Out of date outside this scope:** test_caramelo_v3.py.

### What I could not determine
- The contents of the Studio-only big4 copies.
- The live sizes of `Ground.Floor` and the annex.
- Which nests, posts, flocks and trap spots exactly fall inside a 5x river. I did not run the geometry; the "9 nests" figure is the earlier survey's.
- Whether the old v1 syrup Lake and biscuit bridge (Layout:98-112) are archived on the live map.
- Whether test_caramelo_v3.py runs at all; no Python is available.
