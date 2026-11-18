# Caramelo v9, "least churn" design: the long kingdom and a navigable chocolate river

I edited no repo file and used no Studio tool. Every number below passes my geometry checker, which re-implements the repo's clearance rules (V3-2, V3-4 to V3-9, V3-15, the Layout_Test nest rules, the Life CL3/CL5 rules, and the island channel). It ends with **0 failures**: `C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\v9lc\geo.ps1` (run with `-Mode print` or `-Mode sum`).

Conventions:
- All coordinates are plot-local: world = local + (672, -3).
- "North" means layout +z (world south, the Pueblo Gatito side), as in the code comments.

## 0. The idea in one paragraph

Keep CENTRE, HALF, the entrance, every route, the Torta, the boss, the tower, the portal and 24 of the 28 nests where they are. Retire today's north-south river. PD3 forces this: it cannot be 5x where it is, and keeping it narrow as a second river would contradict "the river is 5x".

Lay one new river:
- **West half (x -260..260):** it runs in the empty south strip, south of the left route's bottom leg, at 60 wide. This is the narrowest legal 5x width, so the band over built content is as thin as possible. Only 4 nests, 4 posts, 2 houses, 1 mountain, the edge hills and one flock are in its way, and each moves the shortest legal distance.
- **East half (x 260..860):** this is all new content. The river climbs north-east through 70 â†’ 100 wide, widens into a harbour lake, and pours into the cloud wall at the east edge.

Two raised cookie bridges (ids Top and Bottom, so `Cookie.IDS` does not change) let the raft pass under. There are 4 docks. The raft sails from the source spring to the mouth.

## 1. The plot

| Item | Value |
|---|---|
| CENTRE | (672, -3), **kept** |
| HALF | 260, **kept** (it is now the z half and the west reach) |
| New | `Layout.EAST = 860` and `Layout.BOUNDS = {minX=-260, maxX=860, minZ=-260, maxZ=260}` (frozen) |
| World plot | x 412..1532, z -263..257 (1120 x 520) |
| Cloud band / Collider | x 1532..1548, Collider centre x 1540 |
| Arm | x 412..1612 (64 studs past the band) |
| `Layout.depth(x, z)` | `min(x - minX, maxX - x, z - minZ, maxZ - z)`; new helper `Layout.inside(x, z, margin)` |
| Layout.VERSION | stays 3 |
| V3.VERSION | 4 â†’ **5** |
| Marks | `CaramelV9`; backup `CaramelV9Backup`; archive `CaramelV9Archived`; summary `WildboundCaramelV9Summary` |

**Why CENTRE is kept rather than using a symmetric HALF_X/HALF_Z:**
- No west-half literal moves. All of these keep their literals:
  - Layout and V3 positions;
  - PraderaSites FIXED and MEADOW_CENTRE;
  - the Portal station (640.8, -3);
  - TrapCake spots;
  - the Life houses and flowers;
  - the Pradera marker.
- The depth of every west-half point is unchanged, except in today's east quarter, where the binding term was 260 - x. Among nests only L1 is affected: depth 213.2 â†’ 231.4, still inside the Legendaria ring. The ring pin `depth(39,-195) == 65` still holds.
- HALF stays 260, so `CRYSTAL_HILLS`' `HALF - 2`, V3-1's HALF copy and the AMBUSH arithmetic do not silently change meaning. Each place that assumed a square is edited explicitly to read BOUNDS (section 12).

**Cost of keeping CENTRE: the floor part's centre moves to world x 972.**
- `Life.plotFrame` (which takes the floor's centre) must anchor at `floor.minX + 260`.
- Ambience is unaffected: it uses the floor's bounds.

## 2. The river

**V3 data changes:**
- `V3.RIVER` becomes a plain v9 literal list. `RIVER_V7`, `withM1` and `RIVER_TOP_Z` go.
- `V3.BOUNDS` is a copy of `Layout.BOUNDS`, pinned by V3-1.
- **Geometry change 1, plot clip:** `V3.liquidDistance = max(old value, -depth(x, z))`, so outside the plot is dry. This kills the critic's "invisible chocolate past the edge" for the raft, wading and the current.
- **Geometry change 2, joint drums:** a joint drum's radius is `max(w[i-1], w[i], w[i+1]) / 2`. The union of drums and leg blocks then equals the union of the rule's capsules exactly, so there are no invisible crescents at width steps. The part count is unchanged.

**Points.** World = local + (672, -3). The last point is on the east edge. The last leg is horizontal, so its cap lies wholly past the edge and is clipped.

| # | Local x, z | w | Note |
|---|---|---|---|
| 1 | (-209.83, -223.19) | 12 | M1's kit outlet, computed (section 3) |
| 2 | (-190, -222.5) | 24 | the spring widens |
| 3 | (-165, -223) | 40 | |
| 4 | (-130, -225) | 60 | dock A here |
| 5 | (-70, -227) | 60 | |
| 6 | (0, -223) | 60 | south of the left route's bottom leg |
| 7 | (70, -226) | 60 | |
| 8 | (140, -222) | 60 | |
| 9 | (200, -224) | 60 | |
| 10 | (260, -212) | 70 | dock B |
| 11 | (325, -188) | 80 | |
| 12 | (390, -150) | 80 | |
| 13 | (460, -110) | 90 | |
| 14 | (530, -85) | 90 | Bottom bridge (x 520) |
| 15 | (610, -65) | 100 | harbour lake |
| 16 | (690, -55) | 100 | dock C |
| 17 | (750, -35) | 80 | Top bridge (x 760) |
| 18 | (805, -5) | 80 | |
| 19 | (860, -5) | 80 | mouth, on the east edge, world (1532, -8) |

**Measurements:**
- Length about 1115 studs (today 500.8).
- Wet area about 89,800 sq studs, 15.4% of the plot (today 13,088).
- Hull-centre water about 84,700 sq studs, 58,300 of it east of x 260 (today 9,680).
- Every x line from -200 to 856 meets chocolate (8-stud scan).

**Lake (the harbour), `V3.LAKE` literal:**
- disc 1 at (610, -70), r 64;
- disc 2, the south lobe, at (655, -118), r 40.

**Pool:** computed from M1, about (-215.19, -223.80), r 4.95.

**Current:** `WildboundCandyCurrent` needs no code change. It already flows downstream along the polyline, now west â†’ east. RIVER_SPEED 4 and LAKE_SPEED 1.5 stay; the lake is slack water for docking C and D.

## 3. The source mountain: M1 moves (justified)

**Why M1 moves.** PD3 wants a waterfall source at the river's head, at the west end. M1 is the only big (L) kit mountain, and its waterfall is the one the builder animates. Its north-edge spot no longer feeds anything.

**M1's new spot:**
- (-232, -226), world (440, -229), facing (-180, -220) (yaw -96.6Â°, front looking east down the river).
- Scale 0.45, r 24.3 and height 40.7 are unchanged.
- Depth 28 â‰¥ r - 0.5.

**New pure data: the kit offsets.**
- `V3.M1_KIT = { outlet = {0.5653, -49.6671}, pool = {0.5653, -37.6671}, poolRadius = 11, fallBack = 3 }`, copied from `WildboundCandyV3KitSpec`, with a test pinning the copy.
- POOL, WATERFALL and RIVER[1] are `V3.kitPoint(M1.x, M1.z, faceYaw(M1â†’face), 0.45, â€¦)`. This replaces `withM1` translation with the same rotation the builder already applies to the kit.
- Pool â‰ˆ (-215.19, -223.80), r 4.95. Waterfall â‰ˆ (-218.17, -224.15), faces the pool, width 7, top 15.17, 5 streaks.
- Outlet to pool = 5.40 â‰¤ r + 1 = 5.95, so V3-2 holds. Waterfall to M1 = 13.95 < 24.3 and waterfall to pool = 3.0 < 4.95, so V3-3 holds.
- Regression test: kitPoint at v8's M1 spot reproduces v8's pool (-8.44, 219.36) within 0.01.

**M5 swaps into M1's old spot.** M5 is in the new band at the south-west corner, so it must move. It goes to (-5.2, 236), facing (0, 0).
- This keeps the north skyline.
- It fits: nest C11 is at 40 past r, C7 at 39.6, the hive keep-clear at 49.

## 4. Routes

`main`, `left`, `right` and `deep` are unchanged. RETURN_ROUTES stay `{left, right}`. Three routes are added. ROUTE_ORDER becomes `main, left, right, deep, east, south, far`. Each point is local.

| Route | Points |
|---|---|
| east | (104,130) right-loop corner â†’ (200,96) â†’ (320,96) â†’ (420,150) â†’ (620,150) â†’ EJ (760,55) |
| south | (117,-143) left-loop corner â†’ (195,-86) â†’ (300,-40) â†’ (520,0) â†’ (650,25) â†’ EJ (760,55) |
| far | (520,0) â†’ (520,-225) â†’ (760,-225) â†’ EJ (760,55), crossing the river twice |

**Rules the new routes meet:**
- every sample is â‰¥ 83 from the boss (territory 76 + half path 7);
- every sample has depth â‰¥ 20;
- they meet chocolate only on a deck (V3-4).

Optional new constant: `Layout.EAST_JUNCTION = (760, 55)`.

## 5. Bridges: raised, the raft passes under

**Build:** `V3.BRIDGE_BUILD = { width 15, deck 13, ramp 28, gapWidth 8, sideRamp 28 }`.
- Ramp angle: atan(13/28) = 24.9Â° â‰¤ 25Â°.
- The deck top is at world 13.5 and its underside at 13.1, which is 9.1 over the surface (4.0).
- The raft's top is about 6.8 over the surface (kit 6.64 + bob 0.15), so the gap is about 2.3. A seated rider's head is estimated at about 6.2.

**Rows** (`gaps = {}`, so no side ramps drop into the channel):

| Id | Route, leg | at | Deck length | Deck centre local | Deck centre world | Footprint along the leg |
|---|---|---|---|---|---|---|
| Bottom | far, (520,0)â†’(520,-225) | 86.75 | 109 | (520, -86.75) | (1192, -89.75) | 4.3..169.3 of 225 |
| Top | far, (760,-225)â†’(760,55) | 191.75 | 111 | (760, -33.25) | (1432, -36.25) | 108.3..275.3 of 280 |

- Both ramps are on dry land: the minimum liquid distance at a deck end is 1.78, against my new rule of â‰¥ 0.5 over the whole ramp footprint.

**Builder:** `layBridge` lays raised decks with no code change; it only needs the data. Add 4 piers per bridge: drums r 1.2 at along Â±L/2 and across Â±(width/2 - 1), on dry land. That is 7 + 4 = 11 parts per bridge.

**Code changes:**
- `V3.nearBridge(x, z, reach, forRaft)` skips a bridge when `B.deck - 0.4 - LIQUID.depth >= V3.RAFT.clearance`.
- `V3.RAFT = { asset = "CV3_BananaRaft", homeDock = 1, clearance = 8 }`.
- `Raft.area` calls `V3.nearBridge(lx, lz, r, true)`.
- `Cookie.SINK` 7 â†’ 14 (CB10 needs > 13.4). FALL_SECONDS 1.2 â†’ 2.0 (optional).

**Retired:** the 5 old bridges (Top, RightLast, Main, LeftLast, Bottom) are archived with the old River folder. The paths under them are already continuous.

## 6. Docks (4)

The raft code stays generic. Two changes:
- `Raft.new`: `homeDock = (type(homeDock) == "number" and docks[homeDock]) and homeDock or 1`.
- `Raft.dockedAt`: the doc comment changes from "1 or 2" to "an index".

RaftService already loops over every dock (one call point each; a call teleports the raft). Home stays dock 1 (A), so V3.RAFT.homeDock keeps its value.

| Dock | Stand local | Tip local | Stand liquid | Tip liquid | Notes |
|---|---|---|---|---|---|
| A | (-150, -185) | (-150, -201) | 8.79 | -7.18 | world (522, -188) / (522, -204); west run, north bank |
| B | (250, -169) | (250, -185) | 3.80 | -11.21 | world (922, -172); by the old east edge |
| C | (680, 0) | (680, -16) | 5.34 | -10.06 | world (1352, -3); harbour, north shore. Ramp foot is 22.4 from route south, so the margin is 22.4 - 3.5 - 7 = 11.9 â‰¥ 3 |
| D | (655, -163) | (655, -147) | 5.00 | -11.00 | world (1327, -166); harbour, far-bank shore, so the stand line Câ€“D crosses chocolate |

- Tips are â‰¥ 6 inside the chocolate.
- No tip is near a non-raised bridge.
- Tips are pairwise â‰¥ 50 apart; Câ€“D is 133.

## 7. Harbour pieces (moved with the retired lake)

**Island I1** (re-planned at server start; its Epica nest follows):
- (640, -95), r 6, flat 4, foot 9.9 (the v8 sizes).
- Inside disc 1.
- Hull ring at r + 4: worst liquid -4.0 â‰¤ -3.
- Line between the C and D tips: 24.5 - foot â‰¥ 12.

**Cookie platforms** (snapped by PlatformIndex):

| Platform | Position | Disc |
|---|---|---|
| 1, CookieM | (625, -128) | disc 2 |
| 2, CookieL | (595, -25) | disc 1 |
| 3, CookieS | (632, -24) | disc 1 |
| 4, CookieS | (585, -118) | disc 1 |

All are inside their disc, off the bridges, â‰¥ 12 from the dock tips and â‰¥ 3 from the island's foot.

## 8. Nests: 28 â†’ 44

**Kept: 24 nests** at today's spots: C1â€“C5, C7, C9, C11, C12, R1â€“R11, E1â€“E3, L1.

**Moved: 4 nests, forced by the band (band top z â‰ˆ -193).** Each keeps its rarity and moves the shortest legal way. Layout gains a `place(id, rarity, x, z)` row with no 1.3 scaling.

| Nest | Old local | New local | New world | Liquid (â‰¥ 6) | Route (11..52) | Depth ring |
|---|---|---|---|---|---|---|
| C6 | (13, -210.6) | (13, -164), in the freed old lake | (685, -167) | 29.5 | 18 | 96, Comun |
| C10 | (-78, -210.6) | (-50, -163) | (622, -166) | 32.8 | 19 | 97, Comun |
| C8 | (78, -221) | (100, -185) | (772, -188) | **9.22** | 23.4 | 75 |
| C13 | (130, -195) | (140, -182) | (812, -185) | 10.0 | 45 | 78 |

**New east nests: 16** (8 Comun, 6 Rara, 2 Epica). Local, then world.

North land:

| Nest | Local | World |
|---|---|---|
| C14 | (360, 170) | (1032, 167) |
| C15 | (480, 195) | (1152, 192) |
| C16 | (600, 195) | (1272, 192) |
| C17 | (785, 90) | (1457, 87) |
| R12 | (300, 130) | (972, 127) |
| R13 | (470, 110) | (1142, 107) |
| R14 | (650, 100) | (1322, 97) |
| R15 | (720, 130) | (1392, 127) |
| E4 | (400, 20) | (1072, 17) |
| E5 | (600, 40) | (1272, 37) |

Far bank:

| Nest | Local | World |
|---|---|---|
| C18 | (600, -185) | (1272, -188) |
| C19 | (480, -200) | (1152, -203) |
| C20 | (740, -180) | (1412, -183) |
| C21 | (800, -100) | (1472, -103) |
| R16 | (560, -150) | (1232, -153) |
| R17 | (720, -120) | (1392, -123) |

**Checks on all 44 nests:**
- Each nest is in its depth ring. Comun is depth â‰¤ 97.5, so z â‰¤ -162.5 / â‰¥ 162.5 or x â‰¥ 762.5; Epica is depth â‰¥ 208, which needs |z| â‰¤ 52 and x â‰¤ 652.
- 11 â‰¤ route distance â‰¤ 52. The farthest is C5 at 48.8 (existing); C14 is at 46.1.
- Nests are â‰¥ 20 apart; the closest pair is R6/C13 at 27.9.
- Each is â‰¥ 48 from the Torta, â‰¥ 96 from the boss and â‰¥ 80 from the entrance.
- Each is â‰¥ r + 20 from a keep-clear and off the bridges.
- Totals: 21 C, 17 R, 5 E, 1 L. No new Legendaria.

**House nests:** `HouseNests.RARITY` adds H8 = "Comun" and H9 = "Rara".

## 9. Creature posts (WildboundPraderaSites)

**Kept: 22 FIXED** rows unchanged, including bossHome (770.2, -3) and bossTerritory (820.2, -3), because the Torta stays.

**Moved with their nests (v8 offsets kept), world:**

| Post | New world | Old world |
|---|---|---|
| candyPostC6 | (675, -159) | (675, -205.6) |
| candyPostC10 | (634, -158) | (606, -205.6) |
| candyPostC8 (Tortidragon's guard) | (767, -176) | (745, -212) |
| candyPostC13 | (800, -184) | (790, -197) |

Liquid margins: C13 11.62, C8 21.5, C6 37.1 and C10 40.1, all â‰¥ 8.

**New EXTRA_POSTS rows (the third copy of each creature, 24 â†’ 32 posts).** Each post is about 12 from its nest, which is the nearest nest within BIND_RADIUS 20. World values:

| Creature | Post key | World | Guards / beside |
|---|---|---|---|
| Gomibu (guardian) | candyPostR13 | (1142, 119) | R13 |
| Flanfuria (guardian) | candyPostE5 | (1266, 27) | E5 |
| Tortidragon (guardian) | candyPostR16 | (1220, -153) | R16, far bank, by Bottom |
| Mochimiau | candyPostC14 | (1032, 155) | C14 |
| Canelin | candyPostC16 | (1272, 180) | C16 |
| GatoRepartidor | candyPostR14 | (1312, 90) | R14 |
| Mielita | candyPostC18 | (1272, -200) | C18 |
| Flanin | candyPostC21 | (1460, -103) | C21 |

All are â‰¥ 8 off the chocolate (the minimum is candyPostR16 at 17.4) and â‰¥ 6 from every piece.

**AMBUSH:** `half` becomes `bounds = Layout.BOUNDS`. `ambushRoll` changes to rectangle tests: "outside" when lx or lz is outside bounds, and the edge test is `min(sx-minX, maxX-sx, sz-minZ, maxZ-sz) < edgeStuds`. Every other number stays.

## 10. Other pieces

**Houses** (9; V3-7's limit becomes 5..9):

| House | Status | Position local | World | Notes |
|---|---|---|---|---|
| H1, H2, H4, H5, H7 | stay | | | |
| H3 (ChocoHouse 1.4, r 22.4) | moved (in the band) | (-200, -160) | (472, -163) | liquid - r = 19.7 |
| H6 (ChocoHouse 1, r 16) | moved | (183, -170) | (855, -173) | liquid - r = **5.61**; M4 gap 3.55 |
| H8 (SweetHouse 1, r 20) | new | (700, 205) | (1372, 202) | |
| H9 (ChocoHouse 1, r 16) | new, far bank | (690, -180) | (1362, -183) | |

- Every door passes the V3-7 rules.
- Quarters: EN H4, H7, H8; ES H6, H9; WN H1, H2; WS H3, H5.

**Mountains:**
- M1 and M5 move (section 3).
- M2, M3, M4 and M6 stay. M4's edge is 15.7 from the chocolate.
- New M7: CV3_IceCreamMountain_M, scale 0.4, r 14.2, at (560, 246), facing (560, 0).
- New M8: CV3_IceCreamMountain_M, scale 0.37, r 13.1, at (420, -247), facing (420, 0), far bank.

**Pink hills:** all 6 CRYSTAL_HILLS re-anchor to the new edge, x = BOUNDS.maxX - 2 = 858, keeping their z (-247, -162.5, -78, 78, 162.5, 247).
- Why: they are edge pieces by rule. Hill_1 sits in the band. Left at x 258, the hills would wall off the way east (H4 + Hill_4 leave a 20.65 gap).
- Hill_3 and the mouth: liquid - r = 13.7.

**Unchanged:**
- licorice arch;
- cake;
- Gran Torta, Tower, Boss, glaze puddles, summit T1;
- Duquesa, Frutillon;
- portal;
- trap cakes (riverside at -126.1, -71.5 keeps â‰¥ 10);
- La Nube's pond and La Abeja's hive keep-clears.

**KEEP_CLEAR:** the stale "Cloud gate" row at (250, 0) is deleted (PGM-D8).

**Gran Torta stays at (148.2, 0).** Least churn: keeping it avoids relaying the Tower (126 parts), Boss, Markers, bossHome and bossTerritory, Duquesa and Frutillon, and the AMBUSH boss clearance. The river never comes near it (liquid at the boss is 192). Its cost is risk R1.

## 11. Edge, cloud wall and ground (WildboundCandyEast)

**`East.plan`:**
- plot = `cx + BOUNDS.minX .. cx + BOUNDS.maxX`.
- Band x 1532..1548, Collider x 1538..1542, Veil 16 thick.
- `BAND_OVERHANG` 8 â†’ 40, so the band covers the arm's z (-303..297).

**Skirts (new):** Ground `SkirtNorth` (x 1012..1548, z 257..297) and `SkirtSouth` (x 1012..1548, z -303..-263). They are pink, top 0.5, and continue the annex strips past the Baseplate's end at x 1024.

**Caps:**
- CapNorth: x 1024..1542, z 293..297.
- CapSouth: x 1024..1542, z -303..-299.
- They now run west from the Collider along the skirts' outer edges, closing the void past x 1024. Total 0 new caps.
- `plan().space` and `shift` are kept only for the old helpers.

**`Ground.Floor`:** one part, 1120 x 1 x 520, centre (972, 0, -3). It stays one part so Ambience and Life keep working.

**Big4 Studio-only copies:** in WildboundBiomes and WildboundBiomeLight (AREAS_BIG4), the Meadow row x 412..1012 becomes 412..1612. Their Studio-only suites change too: BiomeLight_Test big4, Big4Map_Test and BeastSight_Test big4.

## 12. Code that read a square (each edited to BOUNDS)

| File | Change |
|---|---|
| Builder | Floor size; scatter `-HALF+10 .. maxX-42` |
| V3Builder | edge-hill edges; edge-fill grid; `openSpot` (via depth) |
| Duquesa | `plotDepth` â†’ `Layout.depth` |
| Flyers / FlyersService | bounds `{x = 972, z = -3, halfX = 560, halfZ = 260}`; `inside()` uses halfX/halfZ |
| FlyersService (new rule) | `opts.safe` also rejects a hive whose local spot has `V3.liquidDistance < 4`, because candidates beside the far route's bridges would otherwise sit over the river |
| PraderaSites | AMBUSH (section 9) |
| Life | CENTRE and HALF stay; add BOUNDS; `plotFrame` x = floor.minX + 260 |
| Ambience | PLOT_FALLBACK maxX 1532 |
| v8 migrate | untouched (one-shot) |
| KittenPark GATE_CORRIDOR | dead constant, left alone |

**Client systems:**
- **Life:**
  - Houses copy has 9 rows, with H3 and H6 moved.
  - Flocks: F4 â†’ (150, -115) and F5 â†’ (-104, -150). New F7 (420, 60) r 24 alt 51, F8 (560, 175) r 22 alt 50, F9 (640, -215) r 20 alt 52. All are â‰¥ 10 off the chocolate and off houses and the Torta.
  - Fish (heading in radians): River_W1 (-130, -225) 0; W2 (-40, -223) 0; W3 (60, -224) 0; W4 (170, -224) 0.1; River_E1 (330, -184) 0.52; E2 (430, -127) 0.52; Lake_1 (600, -52) 0.24; Lake_2 (665, -72) 0.12; Lake_3 (650, -125) -0.3; River_E3 (800, -19) 0.35. All are 3 inside the chocolate for the whole jump, â‰¥ 8 from tips, and off bridges, platforms and the island.
  - `LAKE_DISC_V7` and the scaling of fish rows go.
- **Ambience:** the floor bounds follow automatically; only the fallback changes.
- **CloudWall client, Current client, Raft client, Sky:** no change. Sky follows the big4 row.

## 13. Tight spots, with the arithmetic

| Spot | Arithmetic | Margin |
|---|---|---|
| Left route's bottom leg | centre (0, -182); RIVER[6] (0, -223) w 60 puts the top at -193; 11.0 â‰¥ half-path 7 | 4.0 |
| Nest C8 (100, -185) | leg 7â†’8 is at z -224.29 at x 100; 39.2 - 30 = 9.22 â‰¥ 6 | 3.2 |
| Nest C13 (140, -182) | 40 - 30 = 10 â‰¥ 6 | 4 |
| Post candyPostC13 | 11.62 â‰¥ 8 | 3.6 |
| H6 (183, -170) r 16 | liquid 21.6 - 16 = 5.6 â‰¥ 2 | |
| H6 and M4 | 34.65 - 16 - 13.1 = 5.55, minus pieceApart 2 | 3.55 |
| Dock B stand | the cap of leg 10â†’11 (r 40) at (260, -212): 44.1 - 40 â‰ˆ 3.8 > 0 | |
| Bridge deck ends | â‰¥ 1.78 dry, so the raft hull (centre â‰¤ -3) never meets a ramp | |
| Island ring | -4.0 â‰¤ -3 | |
| Head of the spring | point 2's drum r = max(12, 24, 40)/2 = 20, reaching back to the outlet; M1 is exempt as the source | |
| Mouth | point 18 depth 55 - 40 = 15 â‰¥ 2; point 19 is on the edge; the raft is clipped 3 inside the edge | |

## 14. Part budget (estimate; the dry run measures)

- **Before:** saved 2072 (v8 record), runtime about 2350.
- **Archived:**
  - old water 150;
  - displaced props in the band, mostly the south edge-fill band, about 150 (estimate).
- **Added:**

| Item | Parts |
|---|---|
| River (18 joints + 18 x 3 + pool) | 73 |
| Lake | 2 |
| Bridges | 22 |
| Docks | 16 |
| Nests (16 x 2) | 32 |
| H8 / H9 | about 33 / about 54 |
| M7 / M8 | about 27 each |
| Paths | about 24 |
| Skirts | 2 |
| East edge fill | â‰¤ 300 (own budget) |
| East bank filler (bankEvery 44) | â‰¤ 80 |

- **Net:** about +390, so saved about 2460 and runtime about 2750â€“2800, right at today's cap of 2800.
- **Proposal:** raise BIOME_PART_CAP to 3400 and V4_PART_TARGET to 3300 for a plot 2.15x bigger, after a Play performance check. It is reported only, as today.

## 15. Migration: tools/wildbound-caramelo-v9-migrate.luau (v8 pattern)

**Setup:**
- DRY_RUN = true by default; edit mode only; fresh module clones.
- Asserts:
  - `Layout.BOUNDS.maxX == 860`, `Layout.HALF == 260`;
  - `V3.VERSION == 5`;
  - `Builder.syncNests`, `syncNestPositions`, `layPaths`;
  - `V3Builder.layWater`, plus the new `planV9`, `layMissing` and `layEdgeRegion`;
  - `East.build`.
- Preconditions: the root has CaramelV8 and not CaramelV9 (if it has CaramelV9: idempotent "already").
- SistemaSonriente is refused everywhere.
- Only the scratch probe calls `:Destroy`.

**Real run** (one recording, "CaramelV9"):
0. Back up root and Candy_Este_v1 to `CaramelV9Backup`.
1. Compute the plans first. `planV9` = planV5 (the water folders plus every prop in the new chocolate, on a bridge or on a piece/hill) âˆª every prop failing `Builder.treeFits` under the v9 Layout (new route legs, moved or new nests and posts).
2. Resize Ground.Floor to 1120 x 520 at (972, -3).
3. Archive the CaramelV3 River, Lake, Bridges and Docks, the planned props, and any saved runtime folders (HideSpots, LicoriceGrass, CaramelTraps, LakeIslands).
4. Snap moved pieces by attribute:
   - M1 (pivot + yaw), with the Waterfall model moved by the same rigid transform (its FlowTop, FlowBottom and SplashY are Y values, so they are unaffected);
   - M5;
   - H3 and H6;
   - Hill_1..6;
   - Platforms 1..4.
5. `layWater` lays the new river, pool, lake, the 2 raised bridges and the 4 docks.
6. `syncNestPositions` moves C6, C8, C10 and C13; `syncNests` adds the 16 new nests.
7. Archive Paths and run `layPaths` (all 7 routes).
8. `layMissing` (new export: lay V3 rows whose model is absent) adds M7, M8, H8 and H9.
9. `layEdgeRegion` (new export: layEdge plus the bank filler restricted to local x â‰¥ 262, own budgets).
10. `East.build`: wall, Veil, caps, skirts and band floor re-conformed.
11. Set root `CaramelV9 = 1`. The summary carries archived, moved, relaid, partsBefore/After and overCap.

**Not touched:** Torta, Tower, Boss, Markers, Portal, the Pradera marker.

**Re-planned at server start:** island, hide spots, traps, grass, house nests (H3/H6 follow; H8/H9 get one) and the raft.

**Studio-only follow-up (separate hunks):** the big4 Meadow row in both modules and their suites.

## 16. Tests

**Deliberately changed:**

**Layout_Test**
- S2: the arm becomes 412..1612, with BOUNDS pins.
- Rings: add east-edge depth pins.
- Nest count 44 (21 / 17 / 5 / 1).
- **GT1 rewritten:** "the Torta ends the main avenue". This drops "east of every route and nest" and "plaza â‰¤ 60 from the east edge".
- V8-D1 world 932 â†’ 1532.
- K-D2 is replaced by "no gate row".
- New case: east routes are â‰¥ 83 from the boss and at depth â‰¥ 20; the 16 new nests are live, â‰¥ 96 from the boss and â‰¥ 80 from the entrance.

**V3Layout_Test**
- V3-1: VERSION 5 and the BOUNDS copy.
- V3-2:
  - the river runs from M1's outlet to the east edge (last x == maxX);
  - length â‰¥ 1000;
  - points 4..last are â‰¥ 50 wide;
  - samples are wet where depth > 0.5;
  - M1 is at the west end: x - r â‰¤ minX + 10.
- V3-14: replaced by "every x line from RIVER[1].x to maxX meets chocolate".
- V3-4:
  - only `far` is bridged, with Top and Bottom on its legs;
  - raised ramps are dry (â‰¥ 0.5);
  - the underside clearance is â‰¥ RAFT.clearance.
- V3-7: 5..9 houses.
- V3-8: â‰¥ 3 docks (4); one pair across the chocolate; tips pairwise â‰¥ 50; homeDock valid.
- V3-12: no gaps allowed; sideRamp still â‰¤ 25Â°.
- V3-15: hills at x == maxX - 2.
- V3-17 and V3-18: replaced by v9 pins:
  - the profile (â‰¥ 10 points â‰¥ 60, â‰¥ 600 studs of â‰¥ 60-wide legs);
  - lake radii â‰¥ 60 / 36;
  - harbour open water;
  - decks of 13;
  - the M1 kitPoint pins and the v8 regression.

**Other suites**
- **Raft_Test:**
  - RF1: real docks â‰¥ 2, homeDock any index;
  - RF4 and RF16: a fake low bridge is still a wall;
  - RF15: a scripted pilot sails the centreline from RIVER[4] to 3 inside the edge with no Blocked.
- **Current_Test:**
  - CU2 legs;
  - CU3 every dock tip â‰¤ DOCK_SPEED (A and B are at exactly 4);
  - CU4 grid x -200..856;
  - CU5 and CU8 new leg indices and start points;
  - CU6 and CU7 dock at all 4 docks.
- **Island_Test:** IS1â€“IS3 use the docks C and D pair.
- **CookieBridge_Test:** CB10 with SINK 14.
- **Wade_Test:** WD2 deck heights (re-check).
- **Life_Test:** CL1 bounds; CL3 the 9 flocks and bounds; CL4 the 9 houses; CL5 the 4 docks; a new `plotFrame` case.
- **Ambience_Test:** 1532.
- **East_Test:** 1532 / 1540 / 1548; overhang 40; caps and skirts. Add the same "exactly one :Destroy" pin for the v9 tool.
- **Duquesa_Test, Builder_Test (floor), Grass_Test, HideSpots_Test, Traps_Test:** fake floors and probes.
- **Nests_Test:** :569 AMBUSH.bounds; :473 probe maxX + 60.
- **HouseNests_Test:** H8 and H9 rarities.
- **V3Builder_Test:** dock count from #DOCKS; part formula.

**New:**
- joint drum radius = max of the adjacent legs;
- liquid clip outside the plot;
- `nearBridge(forRaft)` skips raised bridges;
- the raft passes under Top and Bottom and cannot leave the plot;
- `Raft.new` accepts homeDock 3 and 4;
- piers on dry land;
- a Flyers hive is never over chocolate;
- `planV9` / `layMissing` / `layEdgeRegion` are idempotent;
- the v9 migration tool's pins.

**Unchanged:** Portal_Test (CENTRE kept), Tower_Test, Smarts_Test, Kittens_Test, KittenPark_Test.

## 17. Open risks

1. **The cake is no longer at the end.** The owner's GT rule ("the cake with the princess at the end") is broken: the Torta is now 650 studs from the east edge, and GT1 has to be rewritten. The alternative is to move the Torta to about local x 760 using the v8 relays (Tower, Boss, Markers, posts, Duquesa, Frutillon). That is the main thing to put to the owner.
2. **The raised decks are long:** 109 and 111 studs, piers only at the ends. Creatures' ground rays (from refY + 20) hit a deck 13 up, so the stretch under a bridge may act as a refuge for waders. This needs checking in Play.
3. **M1's kit outlet is small:** it is 12 wide and the pool r 4.95, at the head of a 60â€“100 river. The optional fix is to scale M1 to 0.6.
4. **Part budget:** the runtime is at today's cap. Raising the cap needs owner OK and a performance check.
5. **Long walks:** the east end is about 1,150â€“1,250 studs from the hub. StreamingEnabled reach is unknown.
6. **The river helps players more:** 15% of the plot is chocolate. Wading is slow, it is a refuge from bees, and ground creatures are not slowed.
7. **Docks A and B sit in full current** (4 studs/s). Docking happens while drifting.
8. **No always-safe crossing:** both bridges are cookie. Wading is the fallback.
9. **Leftovers in the west:** the old bank filler and props now line a river that no longer exists. They are kept for least churn.
10. **Unverified state:**
    - Studio-only big4 rows;
    - the unsaved live map;
    - the void edges past x 1024 (skirts and caps);
    - the 3D look;
    - the rider's head clearance (estimated 2.3).

