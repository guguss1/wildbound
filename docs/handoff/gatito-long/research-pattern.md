Report: what outside the park module reads Pueblo Gatito or the south arm, and what changes at z 337..1537

Assumption used for the numbers below: the Caramelo v9 pattern (CL-D1 keeps CENTRE and adds EAST = 860). Here that means the park keeps ORIGIN (282, 600) and HALF 260 (the gate side and the width), and adds a far-end half-length of 860. The floor would then be x 22..542, z 340..1460, park-local lx -260..860. The arm is z 337..1537, which keeps today's 77-stud margin past the far end (1460 + 77 = 1537). If the origin moves instead, every world literal below shifts as well.

1. **WildboundGatitoArea (the source of the copies).**
   - `src/wildbound/WildboundGatitoArea.luau:24` has `Area.ARM = { minX = -3, maxX = 597, minZ = 337, maxZ = 937 }`. maxZ becomes 1537.
   - `:20` `Area.HALF = 260` and `:76-82` `rect(margin)` use one HALF for both axes, so the rect is always a square. It needs an asymmetric far end (a new constant, e.g. FAR 860), otherwise `rect()` stays x 22..542, z 340..860.
   - The header comment at `:9-12` changes with it.
   - Suite `tests/WildboundGatitoArea_Test.luau:27` pins maxZ 937; `:29` pins rect maxZ 860; `:32` pins `rect(16).maxZ` 876 (would become 1476).

2. **WildboundCandyKittens (music rectangle, ENTER/LEAVE margins).**
   - `src/wildbound/WildboundCandyKittens.luau:29` `Kittens.PARK = Area.rect()` is derived, so it follows item 1 with no literal of its own.
   - `:30` `ENTER_MARGIN = 16` and `:31` `LEAVE_MARGIN = 24` stay. At the gate the flag still turns on at z 324 and off past z 316 (comment `:26-27`). At the far end it turns off past z 1460 + 24 = 1484.
   - `inPark` (`:322-330`) has no literals.
   - Comments at `:25-26` (z 340..860) need updating.
   - Suites:
     - `tests/WildboundCandyKittenArt_Test.luau:263` pins `PARK.maxZ` 860, `:281` pins `inPark(false, 542, 860)`, and `:283-286` pin 860+8, 860+24 and 860+24.5. All become 1460.
     - `tests/WildboundCandyKittens_Test.luau:64` pins SPACE maxZ 860 and `:65` pins ARM maxZ 937.
     - `:309-323` checks that the floor lies inside the arm, that the arm overlaps no Meadow square (classic and big4), and that the four arm corners are CandyEast.

3. **KittenAmbienceClient.** `src/wildbound/WildboundCandyKittenAmbience.client.luau:37` polls `Kittens.inPark` every 0.25 s (`:15`). It has no coordinates of its own and needs no code change; only the comment at `:4` (z 340..860) is stale. Audio, CandyAmbience and CandyLife read only the GatitoAmbience flag (`WildboundAudio.client.luau:209`, `WildboundCandyAmbience.client.luau:397`, `WildboundCandyLife.client.luau:201`), so they have no coordinates either.

4. **Kitten posts (WildboundPraderaSites).**
   - `src/wildbound/WildboundPraderaSites.luau:143-152` `EAST_FIXED` holds K1..K8 via `parkPost(lx, lz)` = `Area.world`. Today lx is -170..150 and the world z is 430..750.
   - The post rule is in the comment at `:130-131`: lx -170..150, |lz| ≤ 108, 85 studs apart, "the suites allow up to lx 180, |lz| 180". That lx 180 ceiling has to rise for posts in the new part (lx up to about 860 - 85).
   - `:134-136` reasons that the hunt reach (60 + 12) stays on the floor, 25 studs inside the far end. That margin grows on its own.
   - `:155-158` `EAST_EXTRA_POSTS` (K5..K8): new posts are appended here. Beasts.server (`:1135`) and RestingService (`:66`) walk this list on their own.
   - Existing posts do not move, as long as the origin is kept.

5. **Portal "parque" station.** `src/wildbound/WildboundPortal.luau:52` has `{ id = "parque", source = "build", x = 239, z = 372, y = 0.5, yaw = 0 }`, which is park-local (-228, 43) (`:45-47`). It is unchanged if the origin is kept. If the origin moves, this literal and the Portal_Test check against Area both change.

6. **RestingService.**
   - `src/wildbound/WildboundCandyRestingService.server.luau:29-30` finds `PuebloGatito_v1.Ground`. The rays at `:43`, `:57` and `:70` drop from y 200, 400 long, filtered to Include those floors.
   - It has no coordinates. Any new post past z 860 must stand over a part under `PuebloGatito_v1.Ground` (a resized Floor, or extra parts in that folder). Otherwise the ray misses and y falls back to 0, the baseplate top. Past z 1024 there is no baseplate, so the copy would hang at y 0 over the void.

7. **CandyNests.**
   - `src/wildbound/WildboundCandyNests.luau:38` `PARK_ROOT = "PuebloGatito_v1"`; `:42` `PARK_ID_PREFIX = "Gatito"`; `:126-132` builds id `Gatito..m.id`, key `gatito_<id>` and biome "PuebloGatito"; `:46-50` `PARK_POOL` is Comun, Rara and Epica only.
   - It has no coordinates, so it is unchanged. New nests K9 and up work as `GatitoK9` and `gatito_k9` (letters and digits only, `:40`).
   - A park nest marked Legendaria is silently dropped (`:114`, `pick` returns nil).
   - `tests/WildboundCandyNests_Test.luau:796,816` uses a fixture "K9" Legendaria, expected nil. That is only a fixture, but a real K9 would share the name.

8. **WildboundBiomes and WildboundBiomeLight.**
   - Repo, classic:
     - `src/wildbound/WildboundBiomes.luau:25` `square("CandyEast", "pueblo-gatito", -3, 597, 337, 937)` becomes 337..1537.
     - `src/wildbound/WildboundBiomeLight.luau:33` `square("CandyEast", -3, 597, 337, 937)` changes the same way. It stays the first row, because `presetAt` returns the first match.
     - In classic mode the only overlap is still classic Volcanic (z ≤ 637), Cemetery and Caves (z ≤ 537). No classic square lies past z 637.
   - Big4, Studio only: the CandyEast row replaced Volcanic in `AREAS_BIG4` (`odd/tasks/wildbound-pueblo-gatito.md:71,90,138`) and has to be hand-patched there.
   - `E:\juego roblox\wb-big4\src\wildbound\WildboundBiomes.luau:35` and `WildboundBiomeLight.luau:42` still read `square("Volcanic", ..., -3, 597, 337, 937)` (older than the move). The branch needs the CandyEast row at 1537 when it merges.
   - This is load-bearing: `WildboundBeasts.server.luau:244` `world.inCandy` = `Biomes.has(x, z, "CandyEast")`. Without the big4 row, kitten summoning stops at z 937, as research-r5 warned for Caramelo.
   - Suite `tests/WildboundBiomeLight_Test.luau:92` pins "-3,597,337,937". `:98` samples (590, 930), which should move to the new far corner (e.g. 590, 1530). `:106` checks that (282, 940) is not Gatuno; that probe becomes 282, 1540. `:153-157` covers the big4 rows.

9. **Studio-only big4 suites.**
   - `wb-big4\tests\WildboundBig4Map_Test.luau:444-445` requires every arm to be 600 x 600 and `maxZ <= 1024` ("on the baseplate"). The v9 Studio copy was relaxed for Caramelo only ("the other three arms keep 600", `odd/tasks/wildbound-caramelo-v9.md:96-99`). It must now also let the south arm be 1200 long and end at z 1537.
   - The other checks there still hold: S centred at x 297 (`:450`), N and S the same distance from z -3 (`:451`, 340 = 340), and the 40-stud gaps (`:452`).
   - BeastSight_Test (big4) was changed to read CandyEast in the south arm (`pueblo-gatito.md:81`). Its far-edge samples are not visible in the repo.
   - Repo `src/wildbound/WildboundBeastSight.luau` and its test have no biome coordinates.

10. **CandySky, Atmosphere and CloudWall.**
    - `src/wildbound/WildboundCandySky.client.luau:78` uses `BiomeLight.presetAt`; the Gatuno look is at `:34-35`. It has no coordinates and follows item 8.
    - `src/wildbound/WildboundAtmosphere.luau:27` park row (Day fogEnd 1100) and `:33` park colours are picked by the preset's `zone = "park"` (BiomeLight `:59`). They have no coordinates. A 1120-long floor is about the Day view, so the far end fades from the gate (a look check, not a code change).
    - CloudWall paints by the camera's preset and has no coordinates.

11. **Creature wall clamp.**
    - `src/wildbound/WildboundCandySmarts.luau:284` `WALL_ROOT = "Candy_Este_v1"`. `:300-307` `outsideWall` clamps x only, at Collider x 1540 ± 8 since v9 (`caramelo-v9.md:132`). It is used at `WildboundBeasts.server.luau:819-821` and `WildboundCandyDuquesaService.server.luau:509-512`.
    - The south arm (x ≤ 597) is always "west", and `min(nx, 1532)` never bites, so nothing changes.
    - `tests/WildboundCandyKittens_Test.luau:303-304` asserts the kittens are never clamped; that still holds.

12. **Balance.** `src/wildbound/WildboundBalance.luau:116-123` has only `Gatuno = "Day"` in rules and light. No coordinates, no change.

13. **big4 roads and the gap.**
    - `wb-big4\tools\WildboundBig4Annex.luau:100-101` defines `Road_big4_volcanic-lands` with points (282, 118) → (282, 317) → (617, 317) → (617, 442) → (582, 442), width 14 (`:95`). Leg 1's slab ends at 317 + 7 = z 324 (documented as 324.5).
    - Ground rays at x 282 hit: road to z 324, baseplate z 326..338, park floor from z 341 (`pueblo-gatito.md:107`). Gap decision: `:82`.
    - Legs 2-4 and the gate marker span x 275..624, z 310..449, east of the arm (`research-r4.md:39-43`).
    - Growing outward does not touch any of this, since the gate end stays at z 340. The 16-stud grey gap and the old legs belong to the look task.

14. **Ground and what is south of z 937 today.**
    - Baseplate: x -1024..1024, z -1024..1024, 2048 x 16 x 2048, top y 0 (`WildboundBig4Annex.luau:121`; `research-r4.md:63`). Past z 1024 there is void at every x.
    - `WildboundBig4Ground` (visual only) has:
      - Meadow grass over the whole baseplate, top 0.2 (`:142`);
      - `Apron_Volcanic` = the scaled square + 24 = x -27..621, z 313..961, Basalt, top 0.32 (`:145`; move-plan `:21`). It was not archived; PGM-D6 archived only `WildboundVolcanicLands_Big4`, into `GatitoSouthVolcanic`.
    - So along x 282 today: park floor to z 860, brown basalt apron to z 961, green meadow to z 1024, then void.
    - The extension runs 436 studs of floor (z 1024..1460) and 513 studs of arm (z 1024..1537) over void. It needs:
      - its own floor;
      - Caramelo-style invisible fences. v9 used SideWallNorth/South, 80 tall, and an EndWall (`docs/design/wildbound-caramelo-v9-plan.md:385-391`). The analogues here would be side walls at x -7..-3 and 597..601 (or at the floor's x 22 and 542 if only the floor is solid), from z about 1020 to 1541, and an end wall at z 1537..1541;
      - a decision on what covers the 25 and 55 studs beside the floor past z 1024 (void otherwise).
    - Nothing else is documented in z 937..1617. No src or tools literal lies in that range (grep). `research-r4.md:48` says "Past x 624 there is nothing up to z 1024". The classic squares end at z 637, and the archived volcanic decor sits in ServerStorage.

15. **SistemaSonriente (never touch).**
    - The only extent on record is "z -264..264 only" (`docs/design/wildbound-pueblo-gatito-move-plan.md:22`). Its x extent is undocumented (`docs/handoff/caramelo-v9/research-r4.md:159`).
    - The v9 tool refuses if any SistemaSonriente part meets the growth area (`tools/wildbound-caramelo-v9-migrate.luau:18`: x 932..1616, z -307..301).
    - The Gatito migration should refuse the same way for x -7..601, z 856..1541.

16. **Other notes.**
    - The walk home grows from 430..750 studs (`move-plan.md:97`) to up to about 1460.
    - StreamingEnabled loading of the far end is a Play check, as the v9 handoff lists for Caramelo (`docs/handoff/HANDOFF-2026-11-18.md:152`).
    - The handoff's task text for this arm is at `HANDOFF-2026-11-18.md:163`.
