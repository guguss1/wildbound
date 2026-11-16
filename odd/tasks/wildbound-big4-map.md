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

| Biome | Classic square | Big4 square |
| --- | --- | --- |
| Forest | -218..182, -203..197 | -618..182, -563..197 |
| Meadow (Caramelo) | 412..812, -203..197 | 412..1012, -203..537 |
| Mountains | 522..1022, -743..-243 | 247..1022, -1018..-243 |
| Volcanic | -308..92, 237..637 | -668..92, 237..997 |

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
