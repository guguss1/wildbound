REPORT: what surrounds Caramelo in big4, how far it can grow along x, and which systems read its rectangle

Sources I read (read-only, no Studio tools used):
- E:\juego roblox\wb-first-playable\src\wildbound\WildboundBiomes.luau and WildboundBiomeLight.luau. These are the classic copies; neither has AREAS_BIG4.
- The big4 copies, which are only on branch agus/big4-map in E:\juego roblox\wb-big4: src\wildbound\WildboundBiomes.luau, src\wildbound\WildboundBiomeLight.luau, tools\WildboundBig4Annex.luau, tools\WildboundMapModeSwitch.luau, odd\tasks\wildbound-big4-map.md.
- The asked-for odd/tasks/wildbound-big4-map.md does not exist in wb-first-playable. It exists only in wb-big4.
- Also read: tools\WildboundCandyEast.luau, tools\WildboundCandyLayout.luau, src\wildbound\WildboundPortal.luau, WildboundWorldRules.luau, the candy client scripts, docs\design\wildbound-caramelo-v8-plan.md, docs\design\wildbound-pueblo-gatito-move-plan.md, odd\tasks\wildbound-pueblo-gatito.md and docs\wildbound-game-overview.md:116-117, 627.

Coordinates: x grows east, z grows south.

## 1. What lies around Caramelo in big4 (world coordinates)

Caramelo itself:
- **The plot.** `Candy_Bioma_v1`: x 412..932, z -263..257, centre (672, -3), HALF 260. Source: WildboundCandyLayout.luau:20-25.
- **The big4 Meadow square.** x 412..1012, z -303..297. Sources: wb-big4 WildboundBiomes.luau:33 and WildboundBiomeLight.luau:40.
  - By the 2026-11-18 docs, Studio's hand-patched big4 copies keep this Meadow row. Their first row is now CandyEast (x -3..597, z 337..937), which replaces the Volcanic row (pueblo-gatito.md:71, 137-139; move-plan:50).
  - I could not read the Studio copies. This is inferred from the docs.
- **The annex strips.** Two ground strips, x 412..1012 at z -303..-263 and z 257..297. They are what was left of `WildboundCandyAnnex_Big4`'s three slabs after the v8 migration: the east slab x 812..1012 was archived (CandyEast_Test:303-312; v8-migrate.luau:34-36).
  - Annex props: the annex was laid with scatter areas x 424..800 in the strips and x 832..1000 to the east (Big4Annex.luau:76).
  - The v8 migration moved props standing inside the plot east by 536 and archived the ones in the cloud band. The kitten park later archived everything in x 948..1468 (kitten-park-plan:422).
  - So any live props should be only in the outer strip parts. I could not verify this live.

West: the hub and the road.
- **Hub safe disc.** Centre (282, -3), radius 90, so x 192..372 (WorldRules.luau:54, 157).
- **Hub bounding box.** x 166..387 (big4-map.md:211, 263).
- **The Caramelo arch.** On the hub road at about (372, -3) (big4-map.md:170, 201).
- **`Road_pradera_1`.** Centre x 405.5, length 37, width 14, so x 387..424, z -10..4. It reaches 12 studs into the plot (build-wildbound-open-world-roads.luau:168). The `Gate_pradera` marker is at (417, -3) (:191).
- **The entrance.** Local (-HALF, 0), world (412, -3) (Layout.luau:59-60). It is pinned by CandyLayout_Test S1 and by CandyLayout_Test:44 (plot inside x 412..1012).
- **The Forest arm.** x -418..182, z -303..297. It is the mirror of Caramelo about x 297 (Big4Annex.luau:8-11).
- **Candy apron.** `Apron_Candy` is visual only: x 388..1024, z -327..321, top 0.42. It is the big4 square plus 24, clipped to the baseplate (Big4Annex.luau:133-151). Its west edge (388) was chosen so it does not tint the hub, whose east edge is 387 (big4-map.md:211).

North: the Mountains arm and open meadow.
- **The 40-stud gap.** z -343..-303 lies between the big4 square and the Mountains arm.
- **The Mountains arm.** x -3..597, z -943..-343. It is a scaled clone, `WildboundFrozenMountains_Big4` (Big4Annex.luau:39-40; wb-big4 Biomes:34). `Apron_Frozen` covers x -27..621, z -967..-319.
- **The north road.** From (282, -124) to (282, -323), then west to (-47, -323), (-47, -415), and the gate at (27, -415) (Big4Annex.luau:99). No road runs north of Caramelo's x range except the trunk at x 275..289.
- **North-east.** Past x 597 or 621 there is nothing up to z -1024: only the visual Meadow grass over the grey Baseplate.

South: Pueblo Gatito and the south road.
- **The south road.** It runs (282, 118) â†’ (282, 317) â†’ (617, 317) â†’ (617, 442) â†’ (582, 442) (Big4Annex.luau:101). With width 14 the legs are:
  - leg 2: x 275..624, z 310..324, which passes 13 studs south of the big4 square under Caramelo's x 412..624;
  - leg 3: x 610..624, z 310..449;
  - leg 4: x 575..624, z 435..449.
  - Legs 2-4 and the gate marker were kept, and now lead round the park's east side (move-plan:73).
- **Pueblo Gatito.** The arm is x -3..597, z 337..937 (WildboundBiomes.luau:25). Its floor is x 22..542, z 340..860, and its gate arch is at (282, 346) (move-plan:28-33).
- **Grey gap.** Baseplate between the road and the park floor at z 324..340 is left grey on purpose (pueblo-gatito.md:82).
- **Overlap with Caramelo.** The arm shares only x 412..597 with Caramelo, about 80 studs south of the plot (z 257 â†’ 337).
- **Kitten music rectangle.** x 22..542, z 340..860; it turns on 16 studs out and off 24 studs out (WildboundCandyKittens.luau:28-31). It no longer touches Caramelo.
- **South-east.** Past x 624 there is nothing up to z 1024.

East: the cloud wall, the empty old space and the void.
- **Cloud band.** x 932..948, z -271..265: the plot's length plus 8 at each end (CandyEast.luau:84; CandyEast_Test:49).
- **Collider.** 4 thick, centre x 940 (face 938..942), 80 tall, whole length, no gate (CandyEast.luau:105-117).
- **Veil.** 16 thick, ForceField, no collision and no queries.
- **Floor.** Under the band only: x 932..948, z -263..257, pink (CandyEast.luau:87).
- **End caps.** Two invisible walls, 80 tall, running east-west from the Collider's west face out to the old space's far edge:
  - one at z 261..265, x 938..1468;
  - one at z -271..-267, x 938..1468 (CandyEast.luau:92-96; CandyEast_Test:105-106).
  - Together with the Collider they form a U fence round x 938..1468 that is open only to the east, where there is void.
  - Both caps lie just outside the plot's z range.
- **The old second space, x 948..1468, z -263..257.** Its floor and contents are gone. `plan()` still computes the space for old helpers (CandyEast.luau:9-10, 71-72, 85).
  - x 948..1024: grey Baseplate (top 0, half a stud below the plot floor's 0.5) under the visual pink apron and meadow.
  - x 1024..1468: void.
- **Baseplate.** x -1024..1024, z -1024..1024 (Big4Annex.luau:121; the Baseplate is 2048 x 16 x 2048 with its top at y 0, big4-map.md:173). East of x 1024 there is void at every z.
- **Light.** In big4, light and tag stop at x 1012. Past it `presetAt` returns "Hub" and `Biomes.at` returns no tag (wb-big4 BiomeLight.luau:100-110).

## 2. How far Caramelo can grow along x, and what must move

**West: practically no room.**
- About 25 studs before the hub's bounding box (387), 40 before the hub disc (372), and the road and arch are there too.
- The entrance at world 412 is a pinned rule (Layout.luau:59-60; CandyLayout_Test:44).
- The big4 doc says the west and east links "cannot be lengthened without moving the two hand-built plots" (big4-map.md:255-256).
- Moving the hub is not possible: `Rules.HUB_X/HUB_Z` are read by many systems (big4-map.md:249-252).

**East within today's world: at most about +80 studs.**
- The plot's east edge can go to about 996, with the band at 996..1012, or to 1008 with the band at 1008..1024.
- Within that limit the big4 Meadow row, BiomeLight, the pink apron and the Baseplate need no change.
- It is a small gain (about 12-15%).

**East into the empty old space: up to x 1468 and beyond.**
- For example, the plot to about 1452 with the band at 1452..1468 gives a length of about 1040, twice today's 520.
- A floor over the void past 1024 has already worked: the v8 floor covered x 932..1468, and the kitten park was played there (pueblo-gatito.md:172-174; big4-map.md walk to (950, 0)).
- I found nothing built past 1024 in the repo or the docs.
- Nothing I found limits growth past 1468 either. Only the visual ground cover ends at 1024.

What must change for growth past about 1012:
- **WildboundCandyLayout.**
  - It has one HALF for both axes (:24-25). Lengthening along x needs a separate x half-length (or an east extension) while keeping `CENTRE.x - HALF_x = 412`.
  - `ENTRANCE = (-HALF, 0)` (:60) and every edge-anchored item (CRYSTAL_HILLS at HALF - 2, V3Layout.luau:358-372; `EDGE` band; `AMBUSH`) read HALF.
  - The Gran Torta is "at the east end": world x 820.2, plaza to 878.2, 53.8 from the east edge (Layout.luau:62-68). It would end up mid-plot unless it moves. That is the owner's earlier request (GT).
- **WildboundCandyEast.plan.**
  - The band, Collider, Veil, caps and `wallX` all come from `CENTRE.x + HALF` (CandyEast.luau:82-96), so the wall moves when the layout does.
  - The caps should be rebuilt to the new band ends. Today they run to `space.maxX` = band.maxX + 2Â·HALF.
  - A live run needs a migration tool. `East.build` conforms parts but never removes any.
  - Tests pin 940, 948, 1468 and 932 (CandyEast_Test:48-57, 81-88, 105-106, 155, 164, 187, 223-265, 283), as do CandySmarts_Test:804-850 and CandyKittens_Test:60-66, 282-286, 371-376.
- **Big4 biome rows (Studio-only copies).** The Meadow row of `AREAS_BIG4` must grow past 1012 in both `WildboundBiomes` and `WildboundBiomeLight`.
  - These are hand-patched hunks. The repo has no big4 copy except wb-big4, which is stale: it still has the Volcanic row and no CandyEast.
  - The Studio-only suites `BiomeLight_Test` (big4), `Big4Map_Test` (it checks that stations lie inside the squares) and `BeastSight_Test` (big4) need the same change.
  - Without it, past 1012 the client shows "Refugio Â· dÃ­a" light, has no pink sky, and the server gives no Meadow tag, so the Meadow creature rules and the director stop there.
  - The classic repo rows (Meadow 412..812, WildboundBiomes.luau:27; BiomeLight.luau:35) are already out of date; v8 does not support classic (Layout.luau:21).
- **`WildboundBig4Ground` (visual only).** `Apron_Candy` and the `Meadow` cover stop at 1024. Past it, the extension would have void beside it unless Caramelo lays its own side strips and skirt.
  - The annex strips also stop at x 1012.
  - The caps would act as invisible side fences along the extension's north and south edges, 4-8 studs outside the plot.
- **Portal "caramelo" station.** A literal at (640.8, -3) = CENTRE + PORTAL (WildboundPortal.luau:34-35, 50).
  - If the centre moves, the literal, WildboundPortal_Test and the builder's Portal model must move together. Otherwise PortalService warns "Candy_Bioma_v1.Portal is not atâ€¦" and there is no Caramelo portal (WildboundPortalService.luau:333).
  - Keeping CENTRE.x fixed and adding a separate x half-length avoids this.
- **Roads.** Nothing changes for east growth. `Road_pradera_1` and the arch stay on the west edge, and the south road (z 310..324) is outside the plot's z range.
- **Big4Annex data is stale.** `CANDY.kept` is still the classic 412..812 (Big4Annex.luau:72-77). Rerunning `Annex.build` would be wrong. Do not run it.
- **KEEP_CLEAR.** The "Cloud gate to Caramelo Este" row at local (250, 0), r 16 (Layout.luau:122-125) is a leftover. The move plan says the longer-Caramelo task removes it (move-plan:90).
- **Server readers that assume a square** (outside my scope, listed only):
  - CandyFlyersService.server.luau:83: `half = Layout.HALF`;
  - PraderaSites.luau:149-151: `AMBUSH half 260`, `entrance -260`;
  - tools\WildboundCandyDuquesa.luau:163: `plotDepth`;
  - CandyNests_Test:725: posts x < 932.

## 3. Client systems that read Caramelo's rectangle

- **WildboundCandyAmbience** (lights, sparkles, sway, and the Caramelo music flag `CandyAmbience`).
  - Bounds come from one part, `Candy_Bioma_v1.Ground.Floor` (position Â± size/2), cached once (Ambience.client.luau:240-249).
  - Before the floor streams in, the fallback is the literal `PLOT_FALLBACK` x 412..932, z -263..257 (Ambience.luau:151). It is used only if BiomeLight has a row tagged Caramelo (:157-168).
  - Music and effects turn on at 8 studs out and off at 32 (Ambience.luau:38-39, 180-184; client:396). The music is the `CandyAmbience` flag, which the audio client turns into the Caramelo bed (client:11-12, 67).
  - Effect: if the extension is a second floor part, it gets no ambience or music. Growing the `Floor` part itself works. CandyAmbience_Test:153-157 pins the fallback.
- **WildboundCandyLife** (birds, butterflies, fish).
  - On/off uses the same floor rectangle and margins (Life.client.luau:174-183, 200).
  - Creature positions are plot-local offsets added to the floor part's centre: `world = f.x + x` (Life.client.luau:243; `plotFrame` in Life.luau:262-266).
  - Literals: `CENTRE` (672, -3) and `HALF` 260 (Life.luau:33-34).
  - **Gotcha:** if the `Floor` part grows east only, its centre moves east by half the growth, and every flock, butterfly site and fish spot shifts with it, away from the river, houses and lake that the server built. Either keep the frame anchored to the layout's CENTRE or update the offsets.
- **WildboundCandySky** (pink clouds, decay, skybox). It uses `BiomeLight.presetAt` on the character's position (Sky.client.luau:63), so the pink sky follows the Meadow row and stops at x 1012 in big4.
- **The HUD label, Atmosphere zone "candy" and Day rules.** They come from `BiomeLight.presetAt`/`phaseAt` (the Caramelo preset, BiomeLight.luau:56-57) and follow the same row.
- **WildboundCandyCloudWall.client.**
  - It finds the Veil by name (`Candy_Este_v1.CloudWall.Veil`, :18, 96-101) and puffs are on while the camera is within 700 studs in x of the Veil (:21, 119).
  - It shows the blue "park" face when the camera is east of the Veil (:121). That is harmless but leftover now.
  - Moving the Veil needs no client change.
- **Creature wall clamp (server).**
  - It reads the live Collider's x and `WallMargin` every 5 s: `Smarts.wallOf` / `outsideWall` (CandySmarts.luau:283-307; Beasts.server.luau:817-821; DuquesaService.server.luau:489-495).
  - Today creatures stop at x 932. Moving the Collider moves the clamp with it.
- **Kitten border.** `WildboundCandyKittens.PARK` is now the south park floor (x 22..542, z 340..860; margins 16/24). Caramelo's Life and Ambience turn off when the kitten flag is on (`inCandy = nearCandy and not kittenOn()`). The kitten rectangle no longer touches Caramelo's x growth.

## 4. Recommendation: lengthen east only

- West is blocked: the hub's bounding box (387), the arch, `Road_pradera_1` and the pinned entrance at 412.
- East is empty: the big4 square to 1012, the Baseplate to 1024, then void that has already carried a played floor up to 1468.
- North and south of any eastern extension (x > 624) there is no neighbour up to z Â±1024.
- **The quick option:** go to about 996-1008 for the plot edge. No world-table changes are needed, but the gain is only +64 to +76 studs.
- **The real option:** take the old space, plot to about 1452 with the band at 1452..1468 (or farther). Implementation order:
  1. Give the layout a separate x half-length. Keep the entrance at 412 and the plot's z range -263..257, so the caps, south road, Pueblo Gatito and Mountains are unaffected.
  2. Grow the single `Ground.Floor` part. Do not add a second floor part, or Ambience and Life miss it. Re-anchor Life's frame to the layout's CENTRE (or re-offset it).
  3. Patch the Studio-only big4 Meadow row's maxX in both modules and their three Studio-only suites.
  4. Rebuild the cloud wall and caps at the new east edge with a migration tool.
  5. Lay candy side strips and a skirt past x 1012-1024, because the visual aprons end there.
  6. Decide whether the Gran Torta moves to the new east end.
- **Owner-visible trade-offs to flag:**
  - It breaks the "4 iguales" symmetric layout the owner asked for (big4-map.md:217-228): Caramelo's arm becomes much longer than the others.
  - Walks home get longer. From x about 1450, the hub (282, -3) is about 1,040-1,170 studs away; the earlier park plan treated 830-985 studs as long (move-plan:97).

## What I could not determine

- What Studio's live big4 `WildboundBiomes` and `WildboundBiomeLight` contain now. My statements come from the docs; the wb-big4 copies are older.
- Whether any part exists today east of x 948 (or 1024) in Studio, and which annex props remain.
- Where `SistemaSonriente` lies in x. The docs give only z -264..264 (move-plan:22). Every builder must avoid it.
- The hub's exact east gate and arch geometry beyond the doc's (372, -3).
- Whether StreamingEnabled is on and at what radius. The default target radius is 1024; the far east would be about 1,100+ studs from the hub.
- `Workspace.FallenPartsDestroyHeight`.

