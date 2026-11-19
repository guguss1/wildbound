Pueblo Gatito park geometry: what assumes the 520 x 520 floor, and what has to change for 600 x 1200 (read-only; nothing edited, Studio not touched)

1. How the frame works (src/wildbound/WildboundGatitoArea.luau)
- :20 `Area.HALF = 260`. :22 `ORIGIN (282, 600)`. :23 `YAW = -90`. :24 `ARM = {minX -3, maxX 597, minZ 337, maxZ 937}`. :25 `V1 = (1208, -3, 0)`. :18 `VERSION = 2`.
- :38-41 `turn` gives world(lx, lz) = (282 - lz, 600 + lx).
  - Local +x is world +z: from the gate at the hub, outward (south).
  - Local +z is world -x.
  - So yes: "+world z = +local x". The long side, outward, is local x.
- :60-63 `worldYaw = yaw - 90`. :66-73 `frame()` and `pivot()` use `CFrame.Angles(0, -90°)`.
- :76-82 `rect(m)` is symmetric: `h = HALF + m`, from world(-h, -h) to world(h, h). That gives x 22..542, z 340..860.
  - This is the one function that bakes in the square. Its consumers are `Park.plan().space` (WildboundKittenPark.luau:1286) and `WildboundCandyKittens.PARK` (the music rectangle, WildboundCandyKittens.luau:29). PraderaSites' hunt-clearance rule names it too (only in its comment, WildboundPraderaSites.luau:134-136).
- Floor margins inside the arm today: 3 studs on the gate side (z 337 → 340), 25 west, 55 east, 77 at the far end (move-plan :32).

2. Literals in tools/WildboundKittenPark.luau that assume the square or the current half-size
- :12 comment "520 x 520".
- :39 `FLOOR.size = {2*HALF, 1, 2*HALF}`.
  - The size is in **world** axes: buildGround places the floor with no rotation (:1405).
  - It only works today because the floor is a square. When it grows, world X is the across width and world Z is the length.
- :1405 `buildGround` centres the floor on `CFrame.new(Area.ORIGIN.x, FLOOR_TOP - 0.5, Area.ORIGIN.z)`, which assumes the floor is centred on the origin. Comment :1390-1393.
- :1120 and :1286 `space = Area.rect()`. Comment :1121 (the arch at local -254).
- LOCAL tables :109-190: every point lies in lx -254..240 and |lz| ≤ 240. Nothing occupies the new lx 260..860. The far-end pieces are:
  - main path M ends at (190, 0) (:113);
  - TowerPlaza junction (215, 0) d 50 (:127);
  - TorreGatoVigia (220, 0) yaw 90 (:139);
  - tall lanterns up to lx 180 (:177);
  - the 4 lit tower lanterns at lx 195 and 235 (:182);
  - far scatter and toys at lx 230-240 (:153, :174, :176).
- :84-93 NESTS are written as V1 world literals, converted by `moved()` (:66-70). Depth runs from K1 at lx -170 to K7/K8 at lx 150. The rarity "grows with depth" comment is :80-83, so Epica sits only about 410 studs from the gate.
- :96-101 PORTAL local (-228, 43) and ARRIVAL local (-244, 0), r 30. These are gate-side and unaffected.
- :47 CLEAR and :50 REACH are unaffected.
- :52 GATE_CORRIDOR and :1555/:1582 `archiveAnnex` / `clearGate` work in the old frame and are obsolete (PGM-D8). They don't need to change.
- :56-58 BUDGET (sum 1392). :58 `PART_CAP = 1400`. :1128 comment "1378 parts".
- :1129-1291 `plan()` itself has no size literal beyond `Area.rect()`. It loops over LOCAL and turns each point with `Area.world`, so a longer park only needs new LOCAL rows.

3. Literals in the tests
- tests/WildboundGatitoArea_Test.luau:
  - :21 case name "a 520 square";
  - :24 `HALF 260`;
  - :27 `ARM.maxZ 937`;
  - :29 `rect().maxZ 860`;
  - :30 floor-inside-arm assertion (still fine);
  - :32 `rect(16).maxZ 876`;
  - :48 the round-trip points are fine.
- tests/WildboundKittenPark_Test.luau:
  - :53-54 KD18 table and :95 `total 1392`;
  - :91 `PART_CAP 1400`;
  - :115-120 `space maxZ 860`;
  - :123 the inset-4 inside check (follows rect);
  - :197 posts band `plx -170..180, |plz| ≤ 180` (must widen if posts go deeper);
  - :256/:272 "under 1400";
  - KP12 :588 name;
  - :590 `FLOOR.size[1] == 2*HALF` (still right if [1] stays the across width);
  - :602 `Size.Z 520`;
  - :604 and :615 `centre z 600`.
- Outside my area but pinned to the same numbers:
  - tests/WildboundCandyKittens_Test.luau:64-65 SPACE and ARM literals;
  - tests/WildboundCandyKittenArt_Test.luau:263 `PARK.maxZ 860`;
  - WildboundBiomes.luau:25 and WildboundBiomeLight.luau:33 have the ARM literal `337, 937`, checked by WildboundBiomeLight_Test.luau:92;
  - comment copies at WildboundCandyKittens.luau:25-27, WildboundCandyKittenAmbience.client.luau:4 and WildboundPraderaSites.luau:130-136.

4. The one-shot move tool (tools/wildbound-pueblo-gatito-move.luau, deployed as ServerStorage.WildboundPuebloGatitoMove)
- :80 asserts `Layout.HALF == 260`. :84 asserts `Area.VERSION == 2`.
- :125-134 returns "already" once the `PuebloGatito` mark is set. The log (odd/tasks/wildbound-pueblo-gatito.md:96) records it as already run with mark = 2.
- So it cannot be reused. The grow needs a new one-shot tool on the same pattern:
  - DRY_RUN;
  - Edit-mode assert;
  - a fresh-clone `module()`;
  - backup;
  - one ChangeHistory recording in `task.delay`;
  - a rebuild expected to report 0/0;
  - a JSON summary;
  - the overCap check (:271 uses `PART_CAP + 16 + 1`).
- KP11 (:563-586) pins the old build tool's source strings. A grow tool would need its own wiring case.

5. What has to change for 1200 long outward, following the Caramelo v9 pattern (CL-D1: CENTRE and HALF stay, `EAST = HALF + GROWTH = 860`)
- 5.1 Area
  - Keep ORIGIN (282, 600), YAW -90 and HALF 260. HALF then means the gate-side half-length and the across half-width.
  - Add `GROWTH = 600` and `FAR = HALF + GROWTH = 860`. Bump VERSION to 3.
  - Every existing local and world number then stays the same: nests, posts, Portal (239, 372), PraderaSites EAST_FIXED, ARRIVAL.
- 5.2 Rewrite `rect(m)` to go from world(-HALF-m, -HALF-m) to world(FAR+m, HALF+m).
  - That gives x 22..542, z 340..1460.
  - `rect(16)` gives x 6..558, z 324..1476. The music ENTER_MARGIN 16 still reaches z 324, by the road's end.
  - The floor is 520 x 1120, the same as Caramelo's 1120 x 520.
- 5.3 Change `ARM.maxZ` 937 to 1537. The floor's far end keeps 77 studs to the arm's end, as today.
- 5.4 Floor:
  - `FLOOR.size = {2*HALF, 1, HALF + FAR}` = {520, 1, 1120}, in world axes;
  - the centre in buildGround = Area.world((FAR - HALF)/2, 0) = world(300, 0) = **(282, 900)**.
  - `buildGround` already conforms an existing Floor, so the regrow resizes it in place with 0 new parts.
- 5.5 Content: add LOCAL rows for lx 260..860.
  - `build()` conforms by id, so moving an item (for example the tower, TowerPlaza and the 4 lit lanterns to the new far end, around lx 815) relocates it without duplicates.
  - `build()` never removes. Anything the new drop rules would drop is left standing and needs an archive step.
- 5.6 Extend main path M from (190, 0) to about (790, 0). Decide whether nests and posts deepen; that is an owner question, since it touches rarity by depth, KP2's band (:197) and the PraderaSites comment band.
- 5.7 Outside the park module but needed:
  - Apron_Volcanic is 648 x 648 at (297, 637), so z 313..961 (move-plan :21). The baseplate likely ends at ±1024, as Caramelo's at x 1024 (v9 plan :37); not checked for the z axis.
  - So the arm margins (25 W, 55 E, 77 S) past z ~961 to 1024 lose the apron, and past z 1024 they open onto the void.
  - Copy CL-D13 (v9 plan :376-391): invisible side walls at x -3 and 597 and an end wall at z 1537, or an apron or cloud border, which also suits the queued "hedge or cloud border".
  - Also update the Biomes/BiomeLight ARM literals to 1537.
- 5.8 The queued 16-stud grey gap (z 324.5..340, log :82): closing it by starting the floor at the road (lx -275.5) breaks GA1 :30 (`r.minZ >= ARM.minZ 337`). Use a separate apron piece, or move ARM.minZ to about 324.

6. Part counts
- Live: Park 1378. The split is Paths 254, Gate 8, Village 310, ToyPark 98, Toys 160, Chests 88, Trees 202, Lanterns 130, Scatter 128 (log :161). Plus Ground 1 and Nests 16, so PuebloGatito_v1 has about 1395 parts.
- The pre-drop budget is 1392. 14 parts are dropped: TreeL_01 (6 parts) and Scatter 8.
- Main path M today is 445.6 studs long: 89 slabs + 8 strips + 7 joints = 104 parts. The forks and 5 junctions are the other 150.
- Density today is 1378 / 270,400 sq studs = 5.1 parts per 1000 sq studs. The grown floor is 582,400 sq studs (×2.15).
- Estimates (the dry run would measure them):
  - **Stretch only** (extend M by 600 studs, move the tower group): about +125 parts (120 slabs + 3-5 strips/joints), so about 1505 park parts. That is over PART_CAP 1400, which must rise to about 1600. The new 600 studs would be bare grass.
  - **Caramelo's v9 density** (4.5 per 1000): about 2620 park parts, so about +1240.
  - **Doubled** (a second village/toy/tree set in lx 260..860 plus the path): about 1378 + 1378 + 125 ≈ **2880 park parts**, about 2900 in the root. PART_CAP goes to about 3000, and KP0, KP4 and the move/grow overCap lines change with it.
  - For reference, Caramelo v9 raised BIOME_PART_CAP from 2800 to 3400 (v9 plan :439).
