# Big4 map experiment: four larger biomes, fully reversible

Branch `agus/big4-map` (worktree `E:\juego roblox\wb-big4`, from `codex/wildbound-first-playable` at 8703ea0).
Studio place 122652861404212. Status: **in the place, left in big4 mode for the owner to try** (2026-11-16).

## En castellano, para el dueño

- El mapa ahora tiene solo cuatro biomas, cada uno mucho más grande: el Bosque de la Silueta, el Reino Caramelo,
  las Montañas Heladas y las Tierras Volcánicas (el "infierno"). El Pantano, el Cementerio, las Cuevas de Roca y el
  Abismo están guardados (no borrados) en `ServerStorage.WildboundMapArchive`.
- **Para volver al mapa de antes:** en Studio, abrí la barra de comandos (View > Command Bar), pegá esta línea y
  apretá Enter (con Studio en modo edición, no en Play):

      require(game.ServerStorage.WildboundMapModeSwitch).apply("classic")

  O pedíselo al asistente. Vuelve todo exactamente como estaba (lo comprobé pieza por pieza). Para volver a probar
  el mapa grande: lo mismo con `apply("big4")`.
- Si querés que el "infierno" sea el Abismo en vez de las Tierras Volcánicas, es un cambio chico (ver decisión D1).
- Acordate de guardar el lugar (File > Save to Roblox) cuando quieras quedarte con alguno de los dos: los agentes no
  guardan el lugar.

## Objective

Let the owner try a map with only four biomes, each much larger, without losing anything: one call switches between
today's map ("classic") and the experiment ("big4"), and the code behaves byte-for-byte as before when the mode is
absent or "classic".

## Decisions taken for the user

| ID | Decision | Why |
| --- | --- | --- |
| D1 | "Infierno" = Tierras Volcánicas (`WildboundVolcanicLands`), not Abismo | lava, fire and Neon magma read as hell; flat and walkable; 400 x 400 vs 300 x 300; Abismo's chasms over a drop floor with no way up would be a trap in a big map. Swapping is cheap: change `Annex.SCALED[2]` and the Volcanic big4 square to Abismo's root/corner and move `WildboundDemonAbyss` out of `CLASSIC_ONLY` |
| D2 | Montañas and Volcán grow by `Model:ScaleTo` on a clone (1.55 and 1.9) pinned at the corner nearest the hub | zero extra parts; the Python planners cannot run here; neither biome has pinned gameplay coordinates |
| D3 | Forest and Caramelo grow by annexes (floor slabs + seeded scatter of their own kits); `WildboundP0` and `Candy_Bioma_v1` are never edited | every forest system (fog, home, islands, spawn graph, relief) and every Caramelo post is pinned in world coordinates; Stream A works in Caramelo |
| D4 | The annexes hold scenery only: no eggs, nests, creature posts or fog | the spawn graph is generated in Python; new spawns would need a WildboundServer edit (a lock zone) |
| D5 | The classic road slabs to the old Frozen gate (`Road_frozen-mountains_1..3`) are archived in big4 and replaced by one slab from the N trunk node (352, -223) to the scaled gate | the old gate now sits in the middle of the scaled mountains |
| D6 | The Volcanic S trunk is kept whole and extended by one slab (82, 307) -> (73, 370) | its last leg already ends on the scaled floor |
| D7 | Phases unchanged: forest (and its annex) Night rules, Caramelo (and its annex) Day, Montañas Day, Volcán Dusk look with Day rules; the archived squares read as the hub | keeps every RULES/PRESETS row (Balance_Test pins them) |
| D8 | Classic mode clears the attribute (nil), it does not write "classic" | "exactly today's Workspace" |
| D9 | No Version History save was possible to check from Studio; the switch (reparent only, never destroy, one undo recording) is the safety net | the owner was told to save before the change; agents never save |

## Bounds (world x east, z south)

Current (Owner feedback 3, symmetric plus; the first big4 squares are in brackets):

| Biome | Classic square | Big4 square |
| --- | --- | --- |
| Forest | -218..182, -203..197 | -418..182, -303..297 (was -618..182, -563..197) |
| Meadow (Caramelo) | 412..812, -203..197 | 412..1012, -303..297 (was 412..1012, -203..537) |
| Mountains | 522..1022, -743..-243 | -3..597, -943..-343 (was 247..1022, -1018..-243) |
| Volcanic | -308..92, 237..637 | -3..597, 337..937 (was -668..92, 237..997) |

All inside the 2048 x 2048 baseplate (no extra ground needed), 40+ studs apart, the hub disc (282, -3) r 90 clear.

## Checklist

- [x] BIG4-1 Code: `AREAS_BIG4`, `areasFor(mode)`, `mode()` (pcall read of the Workspace attribute) and an optional
  mode argument on `Biomes.at/has` and `BiomeLight.presetAt/phaseAt`; classic tables unchanged. Commit 6f32792.
- [x] BIG4-2 Switch `tools/WildboundMapModeSwitch.luau` -> `ServerStorage.WildboundMapModeSwitch` (Edit only, refuses
  under WildboundPlayLock / WildboundImportLock, reparent only, one ChangeHistory recording). Commit 6f32792.
- [x] BIG4-3 Builder `tools/WildboundBig4Annex.luau` -> `ServerStorage.WildboundBig4Annex` (scaled clones child by child,
  seeded scatter, roads; a yield every 250 parts; writes only into the archive). Commit 6f32792.
- [x] BIG4-4 Tests: classic cases now pin `"classic"` (the place may sit in big4) and big4 cases added in
  WildboundBiomeLight_Test, WildboundPlacePhase_Test, WildboundBeastSight_Test; new WildboundBig4Map_Test (switch on
  stand-in folders, geometry plan, scatter, portals). Runner SPECS row and deploy manifest rows added.
- [x] BIG4-5 Studio sync under the fingerprint rule (all seven sources matched the repo before writing; read back equal).
- [x] BIG4-6 Geometry built and big4 applied (S3).
- [x] BIG4-7 Walked Play check (S4), see evidence.
- [x] BIG4-8 Round trip big4 -> classic -> big4 (S5); place left in big4.
- [x] BIG4-11 Switch guards (review fix): `apply("big4")` refuses, changing nothing, unless all five
  `Switch.BIG4_ROOTS` are available (in the Big4 archive or under Workspace with `MapMode = "big4"`); before, an empty
  Big4 archive would have archived every classic biome and left only the forest and Caramelo. `apply("classic")`
  refuses, changing nothing, when a classic-only item is in neither Workspace nor the Classic archive or has no home
  folder left; the error lists the paths. big4 still reports classic items already gone as `missing`. See evidence.
- [ ] BIG4-9 Owner tries it and decides keep / revert / swap infierno (D1).
- [ ] BIG4-10 Not done: phone FPS measurement; `docs/wildbound-game-overview.md` section 3 table; Python manifest tests
  (no Python on this PC).

## Evidence

### Tests (fresh loader, only the needed SPECS, temporary StringValue destroyed afterwards)

| Run | Mode | Result |
| --- | --- | --- |
| RED (suites pushed, old sources) | classic | 47 passed, 5 failed: only the new BIG4 cases; Big4Map_Test "module not found: WildboundMapModeSwitch" |
| GREEN | classic | BeastSight 8/0, Big4Map 10/0, BiomeLight 10/0, CandyLayout 14/0, PlacePhase 9/0, Portal 11/0 = 62 passed, 0 failed |
| GREEN | big4 (after apply) | same 62 passed, 0 failed; ambient `Biomes.mode()` = big4, (-500,-400) Forest/Night, (282,387) Hub |

The first GREEN run had one red (a forest prop rectangle straddled two slabs); data fixed in repo and Studio.

### Fingerprints (CRLF->LF, trailing newlines stripped, length + Adler-32), Studio == repo after writing

WildboundBiomes 4187 695550744; WildboundBiomeLight 8413 710710116; WildboundMapModeSwitch 7623 1345326414;
WildboundBig4Annex 18472 3189329384; WildboundBig4Map_Test 15895 4038590492; WildboundBiomeLight_Test 11006 2855894757;
WildboundPlacePhase_Test 9833 1989957072; WildboundBeastSight_Test 7544 635566043.

### Part counts (Workspace BaseParts, Terrain included)

- Classic before: 5892 (P0 1027, Candy 736, Frozen 553, Volcanic 440, Pantano 606, Cementerio 224, Cuevas 1113,
  Abismo 360, roads 27, hub 502, gallery 138, Sonriente 114, Patio 25, others).
- Big4 roots: Frozen_Big4 553, Volcanic_Big4 440, ForestOuter_Big4 1003 (330 props), CandyAnnex_Big4 693 (170 props),
  Big4Roads 4. Roads model keeps 10 parts.
- Big4 total: **5272** (budget 6000).

### Walked Play check (S4, Play lock "big4-S4", character_navigation from the hub spawn, speed x2)

| Walk | Observed |
| --- | --- |
| Spawn | hub (298, -3): Hub preset, clock 13, phase Day |
| Hub W trail -> forest (170, 10) | Forest, clock 0, phase Night |
| Through the forest -> outer forest (-299, 40) -> (-480, -350) -> north annex (20, -450) | Forest/Night; standing on `Floor_Big4_2`; 33 annex props streamed within 120 studs |
| Back to the hub (282, -60) | Hub/Day |
| N trunk (282, -118) -> node (350, -222) -> new slab -> Frozen gate (288, -334) | Mountains/Day, on the clone's own trail `Path1_1` |
| Deeper (417, -429) -> (664, -522) | Mountains/Day on `Path1_4` |
| Back to hub, S trunk (282, 110) -> (191, 217) -> (112, 217) -> (112, 305) -> (82, 307) -> gate (74, 368) | Volcanic, clock 19, Dusk look (Day rules), on `Path1_1` |
| Deeper (-117, 370) -> (-478, 522) | Volcanic, on `Path1_3`, health 100 |
| Back through the hub E trail -> Caramelo (500, -3) | Caramelo/Day on `Joint_main_2` |
| -> south annex (620, 420) -> (950, 300) -> east annex (950, 0) | Caramelo/Day on `Floor_Big4_2` / `Floor_Big4_1` |
| -> Caramelo portal (768, -3), E | teleported home to the hub (348, 25) |
| Hub -> forest portal (-94, 11), E (3 tries) | not used: a beast kept the player engaged (`WildboundBeastEngagedAt` refreshed each second), so the portal's quiet rule held. Prompt present and enabled; the portal sits inside both Forest squares. Not a big4 change, but **not verified** in this run |

- Road connectivity (Edit): every slab end touches another slab, a biome floor or the hub trail; no dead end.
- Caramelo posts (server): all ten `WildboundPraderaSites` points raycast onto Caramelo's own ground and read Meadow
  in big4; `WildboundPradera` marker unchanged (627, 0, 107). No Caramelo creature was spawned during the walk
  (they spawn per encounter), so their behaviour was not observed.
- Console: no script errors and no "Candy_Bioma_v1.Portal is not at" warning; only the usual asset/TexturePack upload
  noise and the DataStore Studio notice.
- Global beasts in the forest annex: not observed (none rolled during the walk); the director gets Forest tags and
  Night there by the same code path as the forest.

### Round trip (S5)

- `apply("classic")`: moved 28, missing 0, attribute nil; every Workspace root's part count and position/size hash
  equal to the pre-change baseline (no differences); named positions equal (Frozen gate (547, 1.5, -303), Volcanic gate
  (82, 1.5, 307), RockCaves (622, 0.5, 387), Abyss (-108, 0.5, -393), Road_living-forest_3 (352, 0.56, -240.5),
  Gate_volcanic-lands (82, 1.5, 307), Road_frozen-mountains_2 (502, 0.56, -263), Candy portal (772, 0.5, -3)).
- `apply("big4")` again: moved 28, missing 0, hashes identical to the first big4. Left in big4.

### Switch guards (BIG4-11, 2026-11-16)

- Before writing, Studio == repo HEAD: WildboundMapModeSwitch 7623 1345326414, WildboundBig4Map_Test 15895 4038590492.
- Spec first: the fixture now archives the five real root names; new cases (BIG4_ROOTS list matches the builder; big4
  with no roots refuses; big4 with one root missing, plus an untagged same-named impostor, refuses and names it; roots
  already in Workspace count; classic refuses with an item in neither place; classic refuses with no home folder).
  The old "gone from both places" case now expects classic to refuse instead of half-restoring.
- RED (fresh loader, Big4Map spec only, temporary StringValue destroyed): 10 passed, 5 failed, exactly the new cases.
- GREEN: WildboundBig4Map_Test 15 passed, 0 failed; no leaks; Workspace mode stayed big4.
- After writing, Studio == repo: WildboundMapModeSwitch 10333 3756365835, WildboundBig4Map_Test 20239 1701286667.
- The live map was not switched. Read-only `status()` afterwards: mode big4, classicInPlace 0, classicArchived 23,
  big4InPlace 5, big4Archived 0. A read-only preflight with the same rules: classic would not refuse (all 23 items
  archived with their home folders present), no big4 root unavailable.

## Studio objects

- `ServerScriptService.WildboundBiomes`, `ReplicatedStorage.WildboundBiomeLight` (edited, mode-aware).
- `ServerStorage.WildboundMapModeSwitch`, `ServerStorage.WildboundBig4Annex` (new modules).
- `ServerStorage.WildboundBig4Map_Test` (new), `WildboundBiomeLight_Test`, `WildboundPlacePhase_Test`,
  `WildboundBeastSight_Test` (edited).
- `ServerStorage.WildboundMapArchive.Classic` (23 items while big4 is on) and `.Big4` (5 roots while classic is on).
- Workspace attribute `WildboundMapMode` = "big4".

## Next step

The owner walks the big4 map and decides. To drop the experiment completely: `apply("classic")`, then (optional) delete
the archive's Big4 folder and restore the two modules' sources from `codex/wildbound-first-playable` under the
fingerprint rule (the mode-aware code is harmless in classic, so leaving it is fine).

## Ground cover and fuller candy trees (2026-11-16)

Owner, from a screenshot by the Reino de Caramelo arch on the hub road: "no quiero que el mapa se vea así con esas partes
grises" and "quiero que los árboles del reino caramelo sean más frondosos".

Cause: the place's `Workspace.Baseplate` (2048 x 16 x 2048, grey Plastic with a tiled Texture, top at y 0) is the only
ground around the hub, between the biomes and in the gaps left by the archived Pantano, Cementerio, Cuevas and Abismo.

Done:
- `WildboundBig4Annex`: `GROUND` (name `WildboundBig4Ground`, baseplate rect, margin 24, thickness 0.4),
  `groundSlabs()` (pure data), `buildGround()` (Edit only, classic mode, into the Big4 archive like the other roots),
  `fluffCandyAnnex(root, kit)` (calls `WildboundCandyKit.fluff` on every `TreeCotton_*` prop; `build()` now runs it
  and `buildGround()`).
- `WildboundMapModeSwitch.BIG4_ROOTS`: sixth root `WildboundBig4Ground`.
- Five slabs, all visual only (CanCollide, CanQuery, CanTouch, CastShadow false): `Meadow` over the whole baseplate
  (Grass 124,168,92, top 0.2), `Apron_Forest` (Grass 96,138,78, top 0.27), `Apron_Volcanic` (Basalt 104,70,58, top
  0.32), `Apron_Frozen` (Snow 232,241,248, top 0.37), `Apron_Candy` (SmoothPlastic 255,190,218, top 0.42). Each apron
  is its big4 square plus 24 studs, clipped to the baseplate. Every biome floor and road top is 0.5 or more, and a
  scan found no visible part with its top under 0.46 inside the baseplate, so nothing is covered.
- `WildboundCandyAnnex_Big4`: its 44 cotton trees got 5 canopy blobs each (220 parts).

Checks:
- Spec first, `WildboundBig4Map_Test` (six roots; ground slabs: meadow = baseplate, aprons = squares + margin, distinct
  tops in (0.1, 0.45], not grey, themed materials; `fluffCandyAnnex` only on cotton trees). RED with the fresh loader
  (only the Big4Map and CandyFluff specs, engine in a temporary ServerStorage StringValue, destroyed after): 13 passed,
  4 failed. GREEN: 17 passed, 0 failed, no leaks.
- Studio == repo after writing: `WildboundMapModeSwitch` 10356 69939f95, `WildboundBig4Annex` 22626 137c926b,
  `WildboundBig4Map_Test` 23757 112ff747 (length, Adler-32 hex).
- Round trip: `apply("classic")` -> hash of every Workspace BasePart (sorted full name, position, colour, material):
  6052 parts 7060b723 -> `buildGround()` (5 parts) -> big4: 5657 parts da8c2ede -> classic again: 6052 7060b723 (equal)
  -> big4 again: 5657 da8c2ede (equal). Final `status()`: big4, classicArchived 23, big4InPlace 6, big4Archived 0.
  Big4 total 5657 BaseParts (budget 6000).
- Walked Play (WildboundPlayLock "claude-map-look", both locks nil before, cleared after; `character_navigation` only):
  spawn (298, -3) -> the hub road by the Caramelo arch (372, -3), standing on the road (root part y 3.7) -> off-road
  (395, 40): Humanoid.FloorMaterial Plastic, root part y 3.1 (the character still stands on the baseplate; the meadow
  does not collide, so the feet sink 0.2 into the grass, not noticeable). `WildboundBig4Ground` replicated (5 parts).
- Not verified visually: `screen_capture` returned a blank white 3D view in Play and in Edit in this session (HUD only),
  so there is no picture of the new ground yet. The owner should look at the arch from the hub road.

Decisions taken for the user:
- A new big4 root (not recolouring the baseplate): the switch keeps its rule of only reparenting, classic is exactly
  as before (hash above), and the themed aprons need separate parts anyway.
- Visual-only slabs over the baseplate rather than solid ground: no physics, raycast or walking change anywhere.
- Margin 24 studs: enough to show the theme at each biome edge without tinting the hub (hub east edge x 387, candy apron
  starts at x 388).
- Basalt apron coloured dark red-brown, not grey, because the owner asked for no grey.
- The fuller cotton trees in `Candy_Bioma_v1` show in both modes (that plot is shared); the classic hash above already
  includes them.

## Owner feedback 3: four equal biomes with the base in the centre (2026-11-16)

Owner, looking at a top view of big4: "es rara la distribución de los biomas, deberían ser los 4 iguales con la base al
centro".

En castellano: ahora los cuatro biomas miden lo mismo (600 x 600) y forman una cruz alrededor de la base: el bosque a la
izquierda (oeste), el Reino Caramelo a la derecha (este), las Montañas Heladas arriba (norte) y el Volcán abajo (sur).
Los caminos a las Montañas y al Volcán salen recto de la base y miden lo mismo. Volver al mapa de antes sigue siendo la
misma línea `apply("classic")`.

Layout: a plus of four equal 600 x 600 squares, mirrored about x 297 (halfway between `WildboundP0` and
`Candy_Bioma_v1`) and z -3 (the hub row); 40-stud gaps between the arms; all on the baseplate.

| Biome | Big4 square | How |
| --- | --- | --- |
| Forest (W) | -418..182, -303..297 | P0 kept; annex slabs W (200), N (100) and S (100); 150 ForestKit props (was 330) |
| Caramelo (E) | 412..1012, -303..297 | plot kept; annex slabs E (200), N (100) and S (100); 120 CandyKit props (was 170), cotton trees fluffed |
| Montañas (N) | -3..597, -943..-343 | clone scale 1.2 (was 1.55 about its SE corner), centre (297, -643) |
| Volcán (S) | -3..597, 337..937 | clone scale 1.5 (was 1.9 about its NE corner), centre (297, 637) |

Roads (`WildboundBig4Roads`, one slab per axis-aligned leg, width 14, classic style), both 694 studs (centre line):
- N: Road_living-forest_1 end (282, -124) -> (282, -323) -> along the N gap to (-47, -323) -> (-47, -415) -> gate (27,
  -415), entered from the west like the classic gate.
- S: Road_cryptic-ruins_1 end (282, 118) -> (282, 317) -> along the S gap to (617, 317) -> (617, 442) -> gate (582, 442),
  entered from the east like the classic gate.
- W and E unchanged: the hub's W trail meets P0 at (182, 17); `Road_pradera_1` meets Caramelo at (412, -3).
- In big4 the switch now also archives the classic diagonal trunk legs `Road_living-forest_2` and
  `Road_volcanic-lands_1..4` (CLASSIC_ONLY 23 -> 28 items); they come back in classic.
- Ground aprons follow the new squares automatically (`groundSlabs()` reads the same data).

Decisions taken for the user:
- Plus, not 2x2. P0 and Candy_Bioma_v1 both straddle the hub row (z -203..197) on either side of the hub, so in a 2x2
  the hub would have to move about 315 studs to a corner. Moving the hub is not possible "in big4 only": its safe disc
  is `Rules.HUB_X/HUB_Z` (WildboundWorldRules, read by `Rules.zone`, `farFromBase`, the hub script, WildboundServer,
  WildboundBeasts, BeastConfig and HudView). The plus keeps the hub, spawn (298, -3), portals and safe zone exactly
  where they are: nothing outside this branch's files changes.
- Equal squares, not equal distances. With P0 and Caramelo fixed 230 studs apart, the W and E arms sit 115 studs from x
  297; N and S must clear their 600-stud width, so they sit 340 from z -3. The plus is mirror-symmetric on both axes.
- Equal road lengths for N and S (694 each). W and E stay the short existing links (P0 and Caramelo touch the hub area);
  they cannot be lengthened without moving the two hand-built plots, which the brief forbids.
- 600 studs: the largest equal size that fits on the 2048 baseplate (x 182 - S >= -1024 and z -3 - 1.5 S - 40 >= -1024
  give S <= 612), so no extra ground part is needed.
- No rotation of the clones: each gate keeps its classic approach side (Montañas from the west, Volcán from the east),
  point-symmetric about the centre; the N side leg runs 20 studs farther out than the S one to even the lengths.
- The first big4 roots are not destroyed: they wait in `ServerStorage.WildboundMapArchive.Retired_Big4_v1_20261116`
  (six roots) and can be deleted by the owner once this layout is kept.
- The hub's bounding box (x 166..387) already overlaps P0's east edge by 16 studs in classic; unchanged.

Checks:
- Studio == repo HEAD before writing (all eight sources, length + Adler-32).
- RED (fresh loadstring+setfenv loader in a temporary ServerStorage StringValue, destroyed after; only the Big4Map,
  BiomeLight, PlacePhase and BeastSight suites; WildboundFreshRunnerLock set and cleared): 38 passed, 7 failed, all
  new cases (symmetry, factors, polyline roads, new sample points). PlacePhase was already green: its new points read
  the same phases in both layouts.
- GREEN: Big4Map 18/0, BiomeLight 10/0, PlacePhase 9/0, BeastSight 8/0 = 45 passed, 0 failed.
- Studio == repo after writing: WildboundBiomes 4310 1757703428; WildboundBiomeLight 8431 3935279600;
  WildboundMapModeSwitch 10783 3046062213; WildboundBig4Annex 24329 3998718749; WildboundBig4Map_Test 26972 4000307929;
  WildboundBiomeLight_Test 11330 4157857190; WildboundPlacePhase_Test 9889 4213335406; WildboundBeastSight_Test 7703
  434186860.
- Rebuild (Edit, locks nil): `apply("classic")` (moved 29) -> classic hash 6051 parts 99d13bf3 -> old roots retired ->
  `build()`: Frozen_Big4 553, Volcanic_Big4 440, ForestOuter_Big4 463 (150 props), CandyAnnex_Big4 719 (120 props),
  Roads 10, Ground 5. Clone grounds measured exactly -3..597 x -943..-343 and -3..597 x 337..937; gate markers at
  (27, -415) and (582, 442).
- Round trip: big4 4923 parts 549c22bb -> classic 6051 99d13bf3 (equal to before) -> big4 4923 549c22bb (equal). Moved 34
  each way, missing 0. Final status: big4, classicArchived 28, big4InPlace 6. Big4 total 4923 BaseParts (was 5657;
  budget 6000).
- Road overlap scan: every leg outside the biomes is clear; the last legs touch only the clones' own trail `Path1_1`
  and, for Montañas, its gate `SignBoard`.
- Walked Play (WildboundPlayLock "claude-big4-sym", both locks nil before, cleared after; character_navigation only):
  spawn (298, -3) Hub -> N road (282, -323) -> (-47, -323) -> (-47, -415) -> into Montañas (39, -440) Mountains, floor
  Snow, health 100 -> deeper (250, -620) Mountains, clock 13. Back to the hub -> S road (282, 317) -> (617, 317) ->
  (617, 442) -> Volcán (401, 640) Volcanic, floor Basalt, clock 19. Hub -> Caramelo NE annex (949, -250) Caramelo, clock
  14. -> outer forest SW (-349, 250) Forest, floor Grass, clock 24 (Night). No script errors (only the usual asset /
  TexturePack upload noise and the DataStore Studio notice).
- Not verified: a top-down picture (`screen_capture` from (297, 1900, 20) still renders a blank white view, as before).
