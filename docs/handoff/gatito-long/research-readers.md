REPORT: how Caramelo v9 grew, and how each piece maps onto Pueblo Gatito (south arm). This was read-only; I edited nothing and did not touch Studio.

**1. Caramelo v9 kept the hub side fixed and grew one edge**
- It added one number, `Layout.V9 = {GROWTH 600, OLD_EAST 260}`, and set `EAST = HALF + GROWTH = 860`. CENTRE and HALF stayed, so every literal on the west side kept its value (caramelo-v9-plan.md:59-87).
- The depth rule became a rectangle: `min(x+HALF, EAST-x, HALF-|z|)` (plan:71).
- The end landmark moved +600 so the goal is still at the end. The Torta went to local x 748.2 (plan:285-301).
- Versions and marks: VERSION 4→5 so the old tools refuse to run; mark `CaramelV9`; folders Backup/Archived/Reverted; summary attribute; recordings "CaramelV9" and "CaramelV9Restore" (plan:89-101).

**2. The plot's own floor past the Baseplate**
- `Ground.Floor` stays one part, because Ambience, Life and Flyers read it. It was resized to 1120 x 520 at (972, 0, -3), adding 0 parts (plan:373-374; migrate.luau:623-628).
- The Baseplate ends at x 1024 and past it is void (research-r4.md:63). So everything past 1024 is the biome's own parts.
- CandyEast's `Ground.Floor` covers the cloud band plus the tail, x 1532..1612 (WildboundCandyEast.luau:146-147, 187-192).

**3. The walls**
- Constants: `TAIL 64`, `EDGE_WALL 4`, `BASEPLATE_MAX_X 1024` (East.luau:74-79).
- SideWallNorth and SideWallSouth run x 1020..1616 along the outer edges of the stretched strips. EndWall is x 1612..1616 across the arm (East.luau:158-165).
- All three use `cap()`: 80 tall, transparency 1, CanCollide and CanQuery true, CanTouch false, Role "solid" (East.luau:173-179, 203-205).
- The walls start at 1020 because the grey baseplate before 1024 is walkable anyway.
- `East.build` is idempotent: it conforms what exists, creates what is missing, never removes anything, and a second call must report created 0 / changed 0 (East.luau:408-436; migrate:665-667).

**4. The strips**
- `East.stripPlan` finds the two annex strips by their shape (within 1 stud), resizes them to the arm's x and creates 0 parts (East.luau:316-346).
- The run is refused unless both strips are found (migrate:531-533).

**5. The big4 row (Studio-only copies)**
- The Meadow row went x 412..1012 → 412..1612 in the Studio copies of the big4 WildboundBiomes and WildboundBiomeLight (plan:401, 859-863).
- The Studio-only Big4Map_Test was changed so Caramelo's square may be 1200 long and end at x 1612, while the other arms keep 600 (task log wildbound-caramelo-v9.md:96-99).
- The wb-big4 branch copy shows what has to be relaxed (wb-big4\tests\WildboundBig4Map_Test.luau:440-458):
  - line 444: width and depth must both be 600;
  - line 445: every square must lie inside ±1024.
- BeastSight (big4) and BiomeLight_Test take the same number.

**6. Migration tool safety pieces** (tools/wildbound-caramelo-v9-migrate.luau)
- Defaults `DRY_RUN = true`, `RESTORE = false` (60-62). Edit mode only (65).
- Modules come from fresh clones (88-94).
- Version and number asserts (208-239). The keep-out must see every creature post (243-258).
- Preconditions: it needs the `CaramelV8` mark, and returns "already" when `CaramelV9` is set (263-265, 285-290).
- `SONRIENTE_BOX` refusal, computed on rotated bounds (83, 412-432).
- Survey (P1-P5) with warnings for anything else in the growth area (295-384).
- The probe lays everything into a detached scratch model. Its `:Destroy` is the tool's only Destroy (436-456).
- Estimate = before − archived + relaid; the run is refused above `V9_PART_TARGET` 3100 (547-563).
- The real run goes in `task.delay`, then `TryBeginRecording`, then `pcall`, then Commit or Cancel (581-600, 670-671).
- Backup clones are made, then the old pieces are reparented to the archive, never destroyed (604-621).
- Mark last (668). JSON summary on an attribute and on `_G` (106-112).
- RESTORE swaps the live roots for the backup clones in one recording (136-204).
- The Gatito move tool already has this skeleton (tools/wildbound-pueblo-gatito-move.luau:30-275). Its `forbidden` also checks descendants (53-56), which is stricter than v9's (95-97). Reuse that one.

**7. Mapping onto Pueblo Gatito.** World x,z = Area.world(local x, local z) = (282 − local z, 600 + local x).

a) **Frame.** Keep ORIGIN (282, 600), YAW −90 and HALF 260, so every park-local literal stays valid: paths, village, nests, posts, portal (−228, 43) and arrival (WildboundKittenPark.luau:84-191). Then:
- add `Area.FAR = HALF + 600 = 860` beside HALF, as Caramelo added EAST (WildboundGatitoArea.luau:20-25);
- `Area.rect(margin)` covers local x −HALF..FAR and local z ±HALF (now a square, :76-82), so world x 22..542, z 340..1460;
- `ARM.maxZ` 937 → 1537 (:24);
- `Area.VERSION` 2 → 3, so the move tool refuses to run (it asserts VERSION 2, move.luau:84).
- The 77-stud margin past the far end (today z 860..937) carries over as z 1460..1537.

b) **Floor.** `Park.FLOOR.size` becomes {520, 1, 1120} in world axes. `buildGround` currently centres the floor on ORIGIN (KittenPark.luau:39, 1405); it must centre on world (282, 900). The tool resizes the live part with 0 new parts.

c) **Readers that follow rect() on their own.** Music rectangle `Kittens.PARK = Area.rect()` (WildboundCandyKittens.luau:29). Kitten hunt bounds (WildboundPraderaSites.luau:134-135).

d) **Literals to change.**
- Repo: `WildboundBiomes.luau:25` and `WildboundBiomeLight.luau:33`, rows "-3,597,337,937" → 1537.
- Tests: GatitoArea_Test:27-29, BiomeLight_Test:92, CandyKittens_Test:64-65, KittenArt_Test:263, 281-286 (far edge 860 → 1460), KittenPark_Test:120.
- Studio-only: the big4 AREAS_BIG4 rows; in Big4Map_Test, let S be 1200 deep and past the 1024 bound.
- Checks that still hold with no change:
  - S centred on x 297 ((−3 + 597)/2);
  - "N and S the same distance from z −3": 340 = 337 + 3, line 451;
  - the 40-stud gaps.

e) **Ground past the Baseplate (z 1024..1537).**
- The floor part bridges the void for x 22..542 only.
- The arm's side margins have no ground there: x −3..22 (25 wide) and x 542..597 (55 wide). The far tail z 1460..1537 has none either.
- Propose three flush parts at top 0.5:
  - SkirtWest x −3..22, z 1024..1460;
  - SkirtEast x 542..597, z 1024..1460;
  - Tail x −3..597, z 1460..1537.
- Unlike Caramelo there are no annex strips to stretch (the volcanic lands were archived whole: move.luau:233-237), so these are new parts. They are also the natural bed for the owner's hedge or cloud border.

f) **Walls**, built the East way (spec list, `conform`, second build 0/0) in `PuebloGatito_v1.Edge`, all 80 tall:
- SideWallWest x −7..−3, z 1020..1541;
- SideWallEast x 597..601, z 1020..1541;
- EndWall x −7..601, z 1537..1541.
- The south road's legs end at z 449 (research-r4:39-43), so they do not conflict.

g) **The gap (owner's look item).** Optionally, one Ground.Approach part, x 22..542 (or the road's x 275..289), z 324.5..340, top 0.5. The road surface is at y 0.62 (pueblo-gatito.md:82, 107).

h) **End landmark, the Torta analog.** Today the far goal is TowerPlaza (215, 0), 50 across, with TorreGatoVigia (220, 0) and 4 lit lanterns (KittenPark.luau:127, 139, 182). Moving them +600 to local x 815/820 puts the plaza edge at local x 840, 20 from the far edge. Main path M then extends from local x 190 to about 790 (:113).

i) **Tool.**
- Name: `tools/wildbound-pueblo-gatito-grow.luau`.
- Needs mark `PuebloGatito == 2`; sets `GatitoGrow`. Names `GatitoGrowBackup`, `GatitoGrowArchived` and `GatitoGrowReverted`.
- SONRIENTE_BOX x −7..601, z 856..1541.
- Warn about anything else in that box (an Apron_Volcanic, if it is still live, is not verified).
- Budget: `Park.PART_CAP` 1400 (:58) must rise to about 3000, with a target refusal in the same style.

**8. Density** (park floor today 520 x 520 = 270,400 sq studs; Caramelo v9 plot 1120 x 520 = 582,400)

| Measure | Pueblo now | per 1000 sq studs | Caramelo v9 | per 1000 sq studs |
|---|---|---|---|---|
| Saved parts | 1394 (park 1378 + nests 16; pueblo-gatito.md:92, 161) | 5.16 | 2798 (task log:124) | 4.80 (v8: 7.66) |
| Nests | 8 (KittenPark.luau:84-93) | 0.030 | 45 + T1 (plan:303) | 0.077 |
| Creature posts | 8 | 0.030 | 32 | 0.055 |
| Big landmarks | 11 buildings (:131-143) | 0.041 | 10 houses + 8 mountains + 6 hills | 0.041 |
| Toys | 40 (:145-167) | 0.148 | n/a | |
| Trees and bushes | 48 kept of 49 (1 dropped) | 0.178 | | |
| Lanterns | 26 | 0.096 | | |
| Scatter (patches, flowers, tufts) | 60 kept of 64 | 0.222 | | |
| Chests | 8 | 0.030 | | |
| All placed items | 194 | 0.717 | | |

**The new half needs this much content.** It is local x 260..860, world z 860..1460, 312,000 sq studs. Holding today's density (×1.154) means:
- 13 buildings, 46 toys, 55 trees or bushes, 30 lanterns, 69 scatter, 9 chests;
- about 231 items and about 1610 parts;
- the park total becomes about 3000.

Holding Caramelo's v9 density (4.80) means about 1400 more parts, about 2800 total. Paths grow too: main path M lays a slab every 5 studs (:1162-1170), so about 120 more slabs for 600 studs.

Nests are the thin spot: the park has 0.030 per 1000 against Caramelo's 0.077. Caramelo went from 28 to 45 nests, ×1.6 for ×2.15 area. The same ratio gives 13 nests here (+5), and 21 to match Caramelo's density. Rarity grows with depth from the gate (:81-83), so the new Rara and Epica nests go in the far half, the way Caramelo put its new Epica on the cake bank (plan:321-325). PraderaSites kitten posts would need new rows.

**Open points**
- No live read was done: the Apron_Volcanic and Baseplate state under z 860..1537 is unverified.
- The Studio Big4Map_Test text is known only from the task log; the wb-big4 copy is older (it still has the Volcanic tag).
- Kitten eggs are out of scope.

Files: E:\juego roblox\wb-first-playable\docs\design\wildbound-caramelo-v9-plan.md, E:\juego roblox\wb-first-playable\odd\tasks\wildbound-caramelo-v9.md, E:\juego roblox\wb-first-playable\tools\wildbound-caramelo-v9-migrate.luau, E:\juego roblox\wb-first-playable\tools\WildboundCandyEast.luau, E:\juego roblox\wb-first-playable\tools\WildboundKittenPark.luau, E:\juego roblox\wb-first-playable\src\wildbound\WildboundGatitoArea.luau, E:\juego roblox\wb-first-playable\tools\wildbound-pueblo-gatito-move.luau, E:\juego roblox\wb-first-playable\odd\tasks\wildbound-pueblo-gatito.md, E:\juego roblox\wb-big4\tests\WildboundBig4Map_Test.luau