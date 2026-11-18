COMPLETENESS CRITIC REPORT: a longer Caramelo and a river 5 times wider (read-only; no files edited, no Studio tools used)

Coordinates: "plot" means local to CENTRE (672, -3), so world = plot + (672, -3). I checked the arithmetic with two PowerShell scripts in the scratchpad: C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\river5x.ps1 and C:\Users\Agustina\AppData\Local\Temp\claude\80e2a77a287fbcbe\6e13884a-c13d-46c1-86d0-627c2213786c\scratchpad\routes.ps1. A third script, area.ps1 in the same folder, gives the areas. "x5" below means every RIVER width times 5, with the lake discs, pool and island unchanged, because the owner asked only for the river.

== A. Contradictions between the five reports, now settled ==

1. **The open-water box in test V3-17.**
   - The pins report gives x -60..79, z -150..-21. Those are the v7 numbers.
   - The test scales them: floor(-60Â·1.3)..floor(79Â·1.3) by floor(-150Â·1.3)..floor(-21Â·1.3), which is x -78..102, z -195..-28 (tests/WildboundCandyV3Layout_Test.luau:477-485, needs 3350 or more open cells).
   - The raft report is right.

2. **Whether the live raft is the kit model or the placeholder.** It is the kit model.
   - All 16 models were uploaded and inserted into ServerStorage.WildboundAssets.CandyKitV3 (odd/tasks/wildbound-caramelo-v2.md:469-470).
   - "All 16 bounding boxes match the kit spec within 0.05 studs, base at y 0 (the raft 1.26 below: its 1.25 draft, by design)" (:477-478).
   - The service uses the kit whenever it finds it (src/wildbound/WildboundCandyRaftService.server.luau:58-75).
   - So the real raft (BalsaBananaSplit) measures 8.64 wide Ã— 7.90 tall Ã— 14.2 long (tools/WildboundCandyV3KitSpec.luau:132). Its bottom is 1.26 below the chocolate surface and its top is about 6.64 above it, plus a bob of Â±0.15.
   - Collision hull: 7 Ã— 1.94 Ã— 12.4 (:10-14). The bow scoops reach +3.7 (:59-63). The seat is at (0, 1.2, 1.6) (:128-131).

3. **How far the raft can overhang a bank.**
   - The rules treat the raft as a circle of radius HULL 3 (src/wildbound/WildboundCandyRaft.luau:36, :84).
   - The real model overhangs by up to 4.1 studs at bow and stern (half-length 7.1 - 3) and 1.3 at the sides (4.32 - 3). The raft report's "about 3" is too low at the ends.

4. **North and south mean opposite things in code and in the world docs.**
   - Layout comments call +z "north": M1 "on the north edge" at plot z +236, and the river ends on "the south edge" at z -260 (tools/WildboundCandyV3Layout.luau:80-85, 109-114).
   - The big4 docs use world +z = south. The park frame says "+x ... points to world +z (south, away from the hub)" (docs/design/wildbound-pueblo-gatito-move-plan.md:30). The Mountains arm (z -943..-343) is "North" and Pueblo Gatito (z 337..937) is "South" (:13-16).
   - So the river's source (M1, plot z +214..+236, world z about 211..233) faces the south road (z 310..324) and Pueblo Gatito. Its mouth (world z -263) faces the Mountains side.
   - The layout, migrate and world reports each use one of the two conventions. A designer brief must pick one.

5. **What "point 23" means.**
   - The only occurrence is docs/design/wildbound-pueblo-gatito-biome-plan.md:102; nothing else in the repo names it.
   - Arithmetic supports RIVER[23] at plot (37.7, -221), w 24. At x5 its band is 120 wide, but the point sits only 39 studs from the plot edge. That gives depth - w/2 = -21, which fails V3-2's "point leaves the plot" rule (V3Layout_Test.luau:91; only the last point is exempt).
   - No other point fails that rule at x5. The next tightest are RIVER[2] (+14.5), RIVER[1] (+15.9) and RIVER[22] (+18.0).

6. **"Nine nests and dock B" is confirmed exactly.** Details are in section C.
   - The layout report says "dock A's tip" falls inside the x5 band. That is harmless, because a tip is meant to be in the chocolate.
   - Dock A survives: its stand keeps 7.2 studs of bank. Dock B is lost: its stand is 39.5 inside the band.

== B. The river today: exact course and width ==

- **Source.** tools/WildboundCandyV3Layout.luau:123-160. It is 24 points {x, z, w}, built from v7 literals (RIVER_V7, :124-149):
  - x and z are times 1.3;
  - points 1-2 move with M1 instead: M1_DX = -1.2, M1_DZ = 60 (:85);
  - point 4's z is pinned to 160;
  - point 24's z is -HALF.
- **Points (plot x, z, width):**

| # | x | z | w | # | x | z | w |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | -9.56 | 214.08 | 12 | 13 | 35.74 | 17.17 | 10 |
| 2 | -13.2 | 198 | 19 | 14 | 39.65 | 0 | 10 |
| 3 | -13 | 170.3 | 19.5 | 15 | 35.84 | -16.98 | 10 |
| 4 | -11.7 | 160 | 24 | 16 | 25.10 | -30.68 | 10 |
| 5 | -3.9 | 135.2 | 24 | 17 | 15.04 | -38.91 | 10 |
| 6 | 6.5 | 106.6 | 24 | 18 | 15.6 | -54.6 | 14 |
| 7 | 14.3 | 80.6 | 24 | 19 | 22.1 | -75.4 | 20 |
| 8 | 16.9 | 70.2 | 24 | 20 | 18.2 | -117 | 24 |
| 9 | 15.6 | 65 | 16 | 21 | 31.2 | -162.5 | 24 |
| 10 | 15.6 | 57.2 | 10 | 22 | 35.1 | -182 | 24 |
| 11 | 14.63 | 39.09 | 10 | 23 | 37.7 | -221 | 24 |
| 12 | 24.78 | 30.97 | 10 | 24 | 39 | -260 | 24 |

- **Extent.** The centreline stays between plot x -13.2 and +39.65 (world x 658.8..711.65). It runs the full height of the plot, z +214 to -260 (world 211 to -263). Length 500.8 studs.
- **It runs across the plot's long axis, not along it.** Growing the plot in x adds no river length.
- **The barrier rule (V3-14, V3Layout_Test.luau:105-121).** Every 2-stud z line must meet chocolate west of x = BOSS.x - territory + 1 = 73.2. The river is a deliberate north-south barrier that you cross by bridge, by wading or by raft.
  - A long river running in x along a longer plot would break V3-14 by design.
  - That is a rule change for the owner to decide, not a tuning change.
- **Lake:** disc 1 at (10.4, -127.4), r 34.5; disc 2 at (-18.2, -148.2), r 18 (:181-190).
- **Pool:** (-8.44, 219.36), r 4.95 (:166-172).
- **Island I1:** (18.9, -102.4), r 6 (:319-324).
- **M1's own water is part of the kit.** M1's kit mountain carries its own "water" pieces: River, Pool, PoolLip and Waterfall, made translucent chocolate by the builder (KitSpec.luau:1545-1592; tools/WildboundCandyV3Builder.luau:172). The kit outlet strip is at kit scale 0.45 (pool radius 11 Ã— 0.45). At x5, point 1 (60 wide) and point 2 (95 wide) would dwarf the kit's built-in outlet. Nothing in code resizes it.
- **Area (4-stud grid, inside the plot):**

| | Wet area | Share of the plot | Hull-centre area (liquid â‰¤ -3, bridges ignored) |
| --- | --- | --- | --- |
| Today | 13,088 sq studs | 4.8 % | 9,680 |
| x5 | 57,344 sq studs | 21.2 % | 53,856 |

== C. Nests, posts and other pieces against a x5 river on today's course ==

How to read the numbers: margin = river distance - piece radius - required clearance. A negative margin means the piece is in the band or too close to it. The required clearances are nest 6 and post 8 (V3Layout.luau:413-422), trap 10 and portal 16.

**Nests that fail (9):**

| Nest | Plot position | Margin today | Margin at x5 |
| --- | --- | --- | --- |
| R4 | (-26, 123.5) | 6.8 | -41.2 |
| L1 | (46.8, -28.6) | 4.8 | -15.4 |
| C6 | (13, -210.6) | 6.0 | -42.0 |
| C7 | (6.5, 184.6) | 3.6 | -41.8 |
| C8 | (78, -221) | 22.3 | -25.7 |
| E3 | (0, 46.8) | 4.0 | -42.0 |
| R10 | (-13, -58.5) | 12.9 | -27.1 |
| R11 | (46.8, 96.2) | 17.6 | -30.4 |
| C11 | (-39, 195) | 9.8 | -30.2 |

**Nests that only just survive at x5:** C4 +1.6, E2 +2.7, R3 +10.8, E1 +10.3, R9 +18.7. All others have 26 or more.

**Posts that fail (8)** (src/wildbound/WildboundPraderaSites.luau:64-84):

| Post | Whose post | Margin at x5 |
| --- | --- | --- |
| candyPostC7 | Gomibu, extra | -41.0 |
| candyPostE3 | Gomibu, extra | -34.9 |
| candyPostC8 | Tortidragon, extra | -32.0 |
| candyPostC6 | Mielita, extra | -34.6 |
| candyPostR10 | Mochimiau, extra | -38.0 |
| candyPostC11 | Canelin, extra | -39.1 |
| candyPostR11 | GatoRepartidor, extra | -38.7 |
| candyNestR3 | Canelin's HOME post | -3.0 |

- The three guardian extra posts that fail guard nests C7, C8 and E3, which also fail. Those whole encounters are lost (EXTRA_POSTS :91-102; bind radius 20, src/wildbound/WildboundCandyNests.luau:27).
- **Posts that only just survive:** candyPostR9 +5.5, candyNestC4 +8.4, candyPostC13 +13.9.

**Other pieces at x5:**

| Piece | Margin at x5 | Result |
| --- | --- | --- |
| Dock B stand | -36.5 | Lost |
| Dock A stand | +4.2 | Survives |
| Island I1 | -65.3 | Swallowed (it is already in the river's mouth today) |
| Portal | +4.1 past its 16 | Survives |
| Boss territory | 7.5 off the band | Survives |
| Junction | 6.7 off the band | Survives |
| Bird flock F3 | +2.3 past its 10 | Survives |
| Bee-hive keep-clear | +15.9 | Survives |

- **Clear by a wide margin:** houses H1-H7 (at least +55), mountains M2-M4, the three trap-cake spots (+53 or more; tools/WildboundCandyTrapCake.luau:21-25), the cake and the licorice arch.
- **Today's slack is tiny.** Post R10 has 2.0, nest C7 3.6, nest E3 4.0, nest L1 4.8, nest C6 6.0 and nest R4 6.8. Even about 1.2x on today's course would fail, so any real widening needs a new course or moved nests and posts.

**Routes that go under water at x5** (from routes.ps1; in today's layout every route meets the chocolate only on a bridge deck):
- **main** avenue: wet from 14.5 to 65.0 studs along it (50.5 studs).
- **right** route:
  - its whole top leg (-52,156)â†’(52,156) is under water (104 of 104 studs), so both its corners sit in the river;
  - leg 2 is wet for its last 22.9 studs;
  - its last leg is wet for 109.5 studs (49.5..159).
- **left** route:
  - the bottom leg is wet from 39 to 130, running into the corner (65, -182);
  - leg 4 is wet for its first 34.5 studs;
  - its last leg is wet for 119.5 studs (58.5..178).
- **Consequence.** Rule V3-4 needs every bridge to be one straight deck plus its ramps on one leg (V3Layout_Test.luau:136-186). The right and left routes cannot be bridged as drawn, so the routes must be redrawn together with the river.

== D. Things the five reports missed ==

1. **The rule shape and the laid chocolate differ.**
   - The rules (riverDistance, so also Raft.area, wading, current and every clearance) treat each leg as a capsule. Its rounded ends have radius max(w_a, w_b)/2 (V3Layout.luau:445-452).
   - The builder lays only a rectangular block per leg plus a joint drum of the point's own w/2. It lays no drum at the last point (V3Builder.luau:474-477, 483).
   - **South edge.**
     - The capsule extends w/2 past RIVER[24]: 12 studs today and 60 at x5. In that area the raft may sail, players count as wading (speed Ã—0.6) and the current pushes them, but nothing is laid there.
     - Past the plot's z -263 edge that is the annex strip (world z -303..-263). The 40-stud gap and the Mountains arm lie beyond it.
     - Today Raft.area includes up to 9 studs past the edge (12 - HULL 3). The Bottom bridge walls it off now, but raised bridges would let the raft reach it.
     - Nothing walls the plot's z edges west of the cloud caps: a test character walked the strip to x 1010 (caramelo-v2.md:839-840).
     - Wading: Wade.wading only needs liquid < 0 and feet below the surface minus 1 (world 3.0) (src/wildbound/WildboundCandyWade.luau:48-54). A player standing on the dry strip, feet at about 0.5, counts as wading.
   - **Width steps.** Where the width steps, the "invisible chocolate" crescent is today's step Ã— 5:
     - point 9: drum radius 40 against a cap of 60, so 20 studs;
     - points 10 and 18: 15 studs;
     - points 17 and 19: 10 studs.
   - Today the same crescents are only 2-4 studs.

2. **Who the chocolate helps.**
   - Creatures are never slowed by it: no Beasts or creature module reads Wade or liquidDistance. Only these files do: Wade, WadeService, Current, Raft, CookieBridgeService, FlyersService and WildboundServer.
   - Bee swarms lose a target that wades for WADE_LOSE_SECONDS and never wake on one (tools/WildboundCandyFlyers.luau:102, 327, 367; FlyersService.server.luau:299-304).
   - So a river 21 % of the plot wide is a big bee refuge, and a ground-creature advantage, because players wade at 0.6 Ã— speed.
   - Base walk speed is 16 (src/wildbound/WildboundEconomyConfig.luau:39; WildboundServer.server.luau:402-419). Wading gives 9.6 studs/s before any carry penalty. Crossing 120 studs takes about 12.5 s, and the current (1.5 on a wader) drifts the player about 19 studs.

3. **What a x5 river gives the raft.**
   - At full speed (20 studs/s, 70Â°/s) the raft turns on a radius of 16.4 studs and needs about 33 studs for a U-turn. That fits on every x5 leg: hull band = w - 6, so 44 to 114.
   - Today it fits only in the lake.
   - Today the raft can reach only the lake plus legs 17-21, about 120 studs of river between the LeftLast and Bottom bridge footprints.
   - Bridge footprints are 2D walls whatever their height (V3Layout.luau:587-595; Raft.luau:84). A fallen cookie bridge still blocks the raft.

4. **Raised-bridge clearance, now with the real model size.**
   - The kit top sits about 6.64 above the surface, plus 0.15 bob. A seated rider's head is about 5.5-6 above it (seat at +1.2 plus a seated R15; the avatar height is not in the repo).
   - So a deck underside at least 7-8 above the surface is needed: deck top about floor + 11 to 12, against 4.1 today (V3Layout.luau:201).
   - At 25Â° or less (V3-4 :150) each ramp must be at least 2.145 Ã— deck height, about 24-26 studs.
   - The Top and Bottom side ramps (sideRamp 9) drop into the channel and would have to go.
   - Cookie SINK must stay above deck + 0.4 (CookieBridge_Test :182).

5. **Docks.**
   - Raft.new needs at least 2 docks and accepts homeDock only as 1 or 2 (Raft.luau:105, 109).
   - Docks are rows in V3.DOCKS, attached to a lake disc (V3Layout.luau:263-275). A river dock needs a new way to anchor it.
   - Tests pin exactly 2 docks: V3-8 :303, RF1, IS3, CU6/CU7.
   - A call teleports the raft; it does not sail (Raft.luau:175-187), so more docks need no path.

6. **The plot's z extent cannot grow much.**
   - S2 pins the plot inside the big4 square z -303..297 (tests/WildboundCandyLayout_Test.luau:44-45). That is 40 studs either side of today's z -263..257.
   - South of that (world +z) are the road (z 310..324) and Pueblo Gatito (z 337+). North (world -z) is the Mountains arm (from z -343).
   - So a longer river has to run mainly in x if the plot grows east.

7. **Things that exist in Studio but not in this worktree** (from the docs; I could not check any of them):
   - the big4 Biomes and BiomeLight copies, patched as hunks (caramelo-v2.md:801-807; pueblo-gatito-move-plan.md:50);
   - mixed Studio copies of WildboundText, WildboundWorld and WildboundServer that carry another branch's work (caramelo-v2.md:479-481, 552, 562);
   - WildboundBig4Ground, the Baseplate, Apron_Candy and the annex strips (source only on agus/big4-map in E:\juego roblox\wb-big4);
   - ServerStorage.WildboundMapArchive folders: CaramelV3..V8 Backup/Archived, KittenParkAnnex, GatitoMoveBackup, GatitoSouthVolcanic;
   - the disabled migration Scripts in ServerStorage;
   - the live Pradera marker at (691.5, 140);
   - pieces built at run time, never saved: the raft, its call points, hide spots, grass, traps and the island.
   - The deploys record "the place is not saved (the owner saves)" (caramelo-v2.md:550). The live state is whatever the owner last saved.

8. **The old syrup lake and biscuit bridge.**
   - A fresh Builder.build still lays Layout.LAKE syrup discs and the 86-stud biscuit bridge tiles (tools/WildboundCandyBuilder.luau:1167-1176).
   - The v3 planner archives any root-level Lake.Syrup_ or Bridge_ child (V3Builder.luau:1092-1096, 1439-1443), so the live map should not have them.
   - Layout.BRIDGE and LAKE are still read by Builder and Flyers (layout report).

9. **Test-pinned points that a new river must respect or re-pin.**
   - Life fish spots: 10 rows, plus a lake-disc copy at v7 (8, -98) (src/wildbound/WildboundCandyLife.luau:157-189).
   - Fixed points in Current_Test CU3 and CU8, and Island_Test IS2 (listed in the raft and pins reports).
   - RIVER[1], [4], [5] and [14] are pinned exactly in V3-18.
   - The junction arc must be exactly 10 wide within 40.3 studs of the junction (V3-17 :468). This contradicts x5 outright.

== E. Open risks (short list) ==

1. **Design conflict.** The river is a north-south barrier (V3-14) across the short axis. "Longer biome + navigable river" either keeps a 500-stud N-S river, or needs a new long east-west course and a new barrier rule. The owner has to choose.
2. **x5 on today's course is impossible** without moving 9 nests, 8 posts, dock B, the island and two route legs. Point 23 also leaves the plot.
3. **Invisible chocolate past the south edge** (60 studs at x5) and at width steps (up to 20 studs). The raft, wading and current act where nothing is laid. A small form of this already exists today.
4. **Raised bridges** need a code change to Raft.area/nearBridge, about 25-stud ramps, no side ramps, and changes to cookie-bridge SINK and tests. Route legs must be long enough for deck + ramps on one straight leg.
5. **Wading and bee balance.** A 21 % chocolate plot strongly favours ground creatures over players, and lets players escape bees.
6. **Off-repo state.** The Studio-only big4 copies and the unsaved place state cannot be verified from the repo. Every migration needs a Studio check, with the owner confirming the target first.
7. **M1's kit outlet** (12 wide) and the fixed pool (r 4.95) would look wrong at the head of a 60-95-wide river.

== F. Could not determine ==

- The live Studio contents, including whether the place was saved after Pueblo Gatito moved.
- The seated avatar's exact head height.
- Whether CU4's smoothness check and the other pinned dry points pass on a new course; that needs a run.
- What the owner means by "5 times its width" for the lake.
- What the survey author meant by "point 23"; RIVER[23] is the best fit.

