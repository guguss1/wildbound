# Pueblo Gatito: build plan for the kitten park in Caramelo Este

> **Since 2026-11-18 (PG-D9), Pueblo Gatito is its own biome, not "phase 2 of Reino Caramelo".** This plan stays the record of how the park was built (K-D1 to K-D21; deployed in `fbcfb6f`). The current plan is `docs/design/wildbound-pueblo-gatito-biome-plan.md`, and the task log is `odd/tasks/wildbound-pueblo-gatito.md`.

Status: plan by the designer, every choice decided for the owner. No code has been written and no Studio tool was called. Line numbers are from `E:\juego roblox\wb-first-playable` unless marked `wb-big4`. Any line marked **(verified)** I read myself; the rest comes from the three research reports.

---

## 1. Facts

### Space and wall (verified)

- **Plan.** `tools/WildboundCandyEast.luau:62-108` lays out:
  - plot x 412..932;
  - band x 932..948, z -271..265;
  - space x 948..1468, z -263..257, centre (1208, -3);
  - floor x 932..1468, top 0.5;
  - wallX 940, margin 8.
- **Parts** (:85-101): Floor, Collider {4, 80, 536} at (940, 40.5, -3), Veil {16, 80, 536}, CapNorth, CapSouth.
- **`build()` is idempotent and only conforms or creates parts** (:248-276). The floor colour is {255,177,209} SmoothPlastic (:33, :86-90).
- **Clamp.**
  - `Smarts.wallOf` reads only the part named `Collider`, and only its X (`src/wildbound/WildboundCandySmarts.luau:279-287`).
  - `outsideWall` keeps a creature that starts east of the wall at x â‰¥ wall.x + margin = 948, and one that starts west at x â‰¤ 932. It never changes z (:292-299).
  - `world.keepOut` applies the clamp after every brain step, before the house early return (`WildboundBeasts.server.luau:805-816, :993`).
- **Biome tags.**
  - Repo Biomes has the `CandyEast` row (`WildboundBiomes.luau:27`), and `Biomes.at` drops Meadow wherever CandyEast holds (:49-51).
  - Repo BiomeLight maps `CandyEast = "Caramelo"` (`WildboundBiomeLight.luau:35, :41`).
  - The Studio copies of both are the big4 versions with that hunk patched in (`odd/tasks/wildbound-caramelo-v2.md:801-807`).
  - In the big4 BiomeLight, `presetAt` returns the first matching area (`wb-big4 .../WildboundBiomeLight.luau:100-110`), and AREAS_BIG4 lists Meadow as x 412..1012 (:38-43).

### Creatures (verified)

- **The candy-critter brain is driven by data.** It reads `Config.BEASTS[e.beast]` and has no per-name branches (`WildboundBeastCandyCritter.luau:1-47`).
  - Attack kinds: leap, dash, burst, lob (:22-26).
  - The tell is at least `MIN_TELL` (:67).
- **Mochimiau's row is the template** (`WildboundBeastConfig.luau:403-424`).
  - `SUMMONED_REST = 5` (:87).
  - WAVE2 is at :568-570 and SUMMONED at :573-574.
  - `homeBiome` returns `beast.biome` for any beast that is not PLAYABLE (:580-586).
  - `NO_GLOBAL_BIOMES = { Meadow = true }` (:70).
- **Director.**
  - `placeBlock` refuses "Biome" when the home tag is missing, and "NoGlobalZone" for a Global beast in a NO_GLOBAL biome (`WildboundBeastDirector.luau:57-69`).
  - A summoned beast worth 0 points stands outside MAX_ACTIVE (:114-117, :154-161).
  - Posts are one of a kind per player (:136-142).
  - `alarm(dir, userId, name, ctx, now, post)` (:237-240).
- **Sites.**
  - `HOME` :30-32, `FIXED` :57-77, `EXTRA_POSTS` :84-95.
  - `Sites.world` reads only FIXED or OFFSETS (:153-160).
  - The fixed-post wake rule is `name ~= "DonGlaseon" and Sites.FIXED[key]` (:179-186). Anything else falls through to the Abeja event rule (:191).
  - The ambush roll returns nil outside the plot square (:131).
- **Beast server.**
  - `KIDS` :47-54.
  - `inMeadow` :237; `world.site` :227-229.
  - `targetOf` sets `meadow = inMeadow` (:513).
  - Summoned beasts spawn at `world.site(Sites.HOME[beast])` on the ground (:369-374).
  - `landHit` damage rule :660-671.
  - `stealCheck` :824-834.
  - A non-summoned beast whose target is in the Meadow is closed (:977-983).
  - `startAtPost` :1074-1084.
- **`summonPass`** :1088-1160.
  - The Meadow-only steal check and the early return are at :1093-1094.
  - The KIDS loop is :1107-1115 and the EXTRA_POSTS loop :1118-1125.
- **GuardAlarm** :1360-1385. It parses `"<name>@<post>"` with `@(%w+)$`, so post keys must be alphanumeric (:1372-1373).
- **Pinned needles** that must stay byte-exact:
  - `for _, extra in ipairs(Sites.EXTRA_POSTS) do` in the beast server (`tests/WildboundCandyNests_Test.luau:549`) and in the resting service (`tests/WildboundBeastCandyCritter_Test.luau:539`);
  - `Sites.world(nil, Sites.HOME[name])` (CandyCritter_Test:523);
  - `meadow = inMeadow(` in refreshAudience (`tests/WildboundBeastWiring_Test.luau:663`);
  - `world.stealCheck(player, character, p, at, inMeadow(p.X, p.Z))` (Nests_Test:523). **This one is deliberately changed by this plan.**
- **Resting copies.**
  - The service lists its names (`WildboundCandyRestingService.server.luau:14`).
  - Its ray filter includes only `Candy_Bioma_v1.Ground` (:22-27).
  - Its extra-post loop is at :43-53.
  - The client names list is at `WildboundCandyRestingClient.client.luau:18`; `nameOf` needs names without "_" (:31-33).
  - The client clones `Models.<name>` and sets BeastPhase "Calm" (:64-72).
- **Beast client.**
  - `visualFor` takes `Models.<beast>` (`WildboundBeasts.client.luau:113-121`).
  - On Spawn it anchors every part through `quiet` (:123-126, :581).
  - `TELL_COLOR` :277-293; `publishPhase` sets the model attributes BeastPhase, BeastPhaseAt and BeastPhaseUntil (:541-547).
  - On Heartbeat it calls `PivotTo(CFrame.lookAt(...))`, so the model faces -Z along its motion (:1194-1206).
  - Heartbeat is used instead of RenderStepped on purpose (:1192-1193; `WildboundCandySky.client.luau:53`).

### Nests and eggs (verified)

- **`WildboundCandyNests.luau`.**
  - POOL :14-19 (Comun Safe, Rara Fog, Epica FogFar, Legendaria Heart) and RISK :22.
  - GUARDIANS :24; `posts` :44-61, pinned at 9 entries (Nests_Test:70).
  - `bind` :64-82; `islands` :86-109; `merge` :112-127.
  - `applyFlags` :141-211, eight guarded steps found with FindFirstChild.
  - `read(root)` reads only `root.Nests` (:214-239).
- **The server merges `read(workspace.Candy_Bioma_v1)` only** (`WildboundServer.server.luau:146-162`; needle pinned at Nests_Test:205, :260).
- **Plain-part nest template:** a Wood `Collision_Bowl` cylinder {2.2, 5.3, 5.3} and a `RarityRing` (`tools/WildboundCandyIsland.luau:198-207`). The marker contract is at :211-241.
- **Ring colours** in `tools/WildboundCandyBuilder.luau:29-31, :37`: Comun mint (88,214,220), Rara confetti (251,225,94), Epica grape (117,64,121).
- **Pay values.**
  - Egg embers by tier: Safe 4, Fog 10, FogFar 16, Territory 24, Heart 36 (`WildboundEconomyConfig.luau:134`).
  - The random world pays Comun Fog, Rara FogFar, Epica Territory (`WildboundSpawnClock.luau:23`).

### Portal (verified)

- `STATIONS` :36-39; a `source = "build"` station is built at server start (`WildboundPortalService.luau:244-288, :307-342`).
- Its posts stand at local z Â±4.6, so `yaw 90` means you walk through along world z.
- `CARRY = "refuse"` (`WildboundPortal.luau:27-28`; decision 47).
- The test pins two stations (`tests/WildboundPortal_Test.luau:167`).

### Audio (verified)

- **Catalog.** `carameloMusic = slot("Music", {1845212471}, {loop = true})` (`WildboundAudioCatalog.luau:63`); SHARED :67-73.
- **Mix.** `BEDS` :15-16; `Mix.CANDY` :73; `Mix.targets` :82-119; beds fade over 4 s (:161-169).
- **Client.** `local candy = â€¦CandyAmbienceâ€¦`, `candyTrack`, `Mix.targets(â€¦)` (`WildboundAudio.client.luau:208-210`). The needles are pinned (`tests/WildboundCandyAmbience_Test.luau:251, :281-283, :300`).
- **CandyAmbience** stays on to x 964 (enter margin 8, leave margin 32 past the plot edge; `WildboundCandyAmbience.luau:38-39, :151, :180-184`).
- **Catalog rule.** Every catalog id must be on a shortlist line without "rejected", and no other script may contain it (`tools/test_wildbound_audio_catalog.py:26-50`).
- **Precedent:** "Cheerful Caramelo music" (`docs/audio/wildbound-horror-audio-shortlist.md:61-65`). It lists the APM alternates 1846279685 "Merry Kids" and 1841060369 "Play School", which no script uses.

### Light (verified)

- **Atmosphere.**
  - `ROWS` has open, fog, camp and candy (`WildboundAtmosphere.luau:8-17`); `ZONE_COLOURS.candy` :19-21.
  - An unknown zone falls back to "open", the misty row with fogEnd 140 (:112, :9).
- **CandySky.** It acts only when `presetAt == "Caramelo"`: pink clouds, decay and the pink skybox (`WildboundCandySky.client.luau:14-21, :54-69`).
- **Big4 BiomeLight.** PRESETS :77-96, RULES :116-119, `target` uses `preset.zone` (:135-143) (`wb-big4`).

### Layout and the live map (verified)

- **Layout.** `PATH_WIDTH = 14` (:52); BOSS: Torta at plot local 148.2, territory 76, plaza 58 (:73-74).
- **`KEEP_CLEAR` takes v7 coordinates through `keepClear()`** (:115-122). The suites pin only `[1]`.
- **Edge hills Hill_1..6** sit at local x 258 (:361-372). Their world z windows:
  - Hill_3: -98.75..-63.25;
  - Hill_4: 57.25..92.75.
  - So z -63..57 is free at the east edge.
- **Seeded edge fill** at local depth 4..45 (world x 887..928) is saved in the map (`tools/WildboundCandyV3Layout.luau:380-386`).
- **v8 evidence.**
  - 70 annex props moved into the second space and stayed in `WildboundCandyAnnex_Big4`.
  - Part counts: bioma 2072, annex 698, east 5. Runtime bioma 2350.
  - A pushed character stops at x 937.1.
  - Studio's 3D view rendered white in every capture (`odd/tasks/wildbound-caramelo-v2.md:822-843`).
- **Fresh runner.**
  - SPECS format: `tools/studio-fresh-runner.luau:7-15`.
  - Suites that need Workspace are skipped (:43).
  - Studio names: `WildboundBeasts`, `WildboundBeastsClient`, `WildboundCandyRestingService`, `WildboundCandyRestingClient`, `WildboundCandySkyClient` (:152-159, :264-274).

### Owner's pack

- **Look:** a green sunny park, beige stepping-stone paths 10-14 wide, pink trees, lanterns, a clear blue sky, nothing violet or dark (`00_EMPEZAR_AQUI.md`; `GUIA_VISUAL_PARQUE_VERDE.md`).
- **Layout:** entrance meadow, then shop village, toy park, yarn forest and landmark tower. The checkout and conveyor belt are only for an economy use (`DISTRIBUCION_SUGERIDA_DEL_MAPA.md:19-24`).
- **Technical rules:**
  - simple collision proxies;
  - fine details with no collision;
  - signs built with SurfaceGui and TextLabel;
  - eggs are stolen and carried home, with the 5-minute restock (`REGLAS_TECNICAS_ROBLOX.md:11-14`).
- **Kittens:** "No asumir que todos son enemigos". The signature moves: Lanudo bounces like yarn, Guerrero raises his weapon, Bouquet offers flowers, Actually raises his finger (`07_Prompts_Claude/04_Mascotas_Rigs.md:11, :14`).

---

## 2. Decisions

### K-D1. The gate: a 14-stud gap in the Collider at world z -3

- **The split.** `Collider` becomes the north piece and keeps its name, so `wallOf` still finds x 940. A new `ColliderSouth` takes the south part.

  | Piece | z range | Size | Centre |
  |---|---|---|---|
  | `Collider` (north) | 4..265 | {4, 80, 261} | (940, 40.5, 134.5) |
  | `ColliderSouth` | -271..-10 | {4, 80, 261} | (940, 40.5, -140.5) |

- **Flags.** Both keep the same flags and `Role = "solid"`. Only `Collider` carries `WallMargin`.
- **Unchanged:** the Veil (continuous, players walk through the cloud) and both caps.
- **Reasons.**
  - z -63..57 is the only window at the east edge with no hill, house, mountain, nest or post. Its width comes from Hill_3 and Hill_4.
  - It lies on the main avenue's axis and on the park's centre line (1208, -3).
  - Width 14 equals `Layout.PATH_WIDTH`; the pack asks for 10-14.
  - The straight line runs through Don Glaseon's territory (centre (820.2, -3), r 76, edge x 896). The safe ways go round it at |z| â‰¥ 50, for example (880, -100) â†’ (905, -50) â†’ (925, -3), which stays 92 or more from his centre.
  - Code-moved creatures are unaffected, because the clamp uses x only.
- **New data.** `East.GATE = { dz = 0, width = 14 }`, read from plan centre z (-3).

### K-D2. Keep the plot side of the gate clear

- **Server-start planners.** Append a fourth-style row to `Layout.KEEP_CLEAR`, written directly in v8 local coordinates and not through `keepClear()`:
  ```lua
  table.freeze({ x = 250, z = 0, r = 16, why = "Cloud gate to Caramelo Este" })
  ```
  That is world (922, -3), so the hide spots, grass, traps and bee hives keep off the corridor.
- **Saved edge fill.** The one-shot build tool archives every top-level piece under `Candy_Bioma_v1` that has a colliding BasePart and whose pivot lies in the corridor rectangle x 896..932, z -17..11. They go to `ServerStorage.WildboundMapArchive.KittenGate`, with a dry run first.

### K-D3. The return portal: station `parque`

- **Row** in `Portal.STATIONS`:
  ```lua
  table.freeze({ id = "parque", source = "build", x = 980, z = 40, y = 0.5, yaw = 90 })
  ```
- **Position checks.**
  - 45.9 from the arrival point (964, -3).
  - 43 from the main path.
  - 89.8 from the nearest kitten post (K2), so it is outside the 40-stud threat radius.
  - About 700 from the hub, and outside every safe zone.
- **Rules.**
  - The carrier is still refused: decision 47 stands, so the heist stays "carry it home past the beasts". The station only helps empty-handed players.
  - Its name is the fallback "Portal", so WildboundText gets no hunk.
- **Pay.** Park eggs pay one tier more to make up for the walk of about 830-985 studs (K-D8).

### K-D4. The four kittens: four new rows on the existing candy-critter brain

- **No new brain module.** Brain kind â†’ existing `Attack.kind`. All four are `category = "Guardian"`, `biome = "CandyEast"`, `points = 0`, `chance = 0`, `chance10 = 0`, `cooldown = SUMMONED_REST`, `keepsEgg = true`, `grounded = true`, `hitHeight = 8`, `disengage = 0.9`, `riskModifier = 1`.
- **The four names** have no underscore and match the pack sheets 21-24:

  | Name | Attack kind | Attack, in the pack's words | Extra |
  |---|---|---|---|
  | `GatitoLanudo` | leap | Rebota como ovillo | Follow {Max = 1, RangeStuds = 9} |
  | `GatitoGuerrero` | dash | Shield charge | none |
  | `GatitaBouquet` | lob | Petal throw from a stand-off | none |
  | `GatitoActually` | burst | "Â¡De hecho!" shockwave, long comic tell | none |

- **Never `Gift` or `Call`.** The server writes the Gato's golden-order text for those (`WildboundBeasts.server.luau:784-791`).

### K-D5. Kitten tuning

Every chase speed is above 16 and below 23.2, and every tell is at least MIN_TELL. Every kitten shares EscapeDistanceStuds 90, EscapeSeconds 2, GiveUpSeconds 4.5 and IdleSeconds 25.

| | Lanudo | Guerrero | Bouquet | Actually |
|---|---|---|---|---|
| damage | 8 | 10 | 7 | 9 |
| Wake / Perception / Abandon / Leash | 40 / 36 / 46 / 30 | 40 / 36 / 48 / 32 | 42 / 38 / 50 / 34 | 38 / 34 / 46 / 30 |
| Patrol radius / pause / speed | 9 / 1.5 / 6 | 10 / 1.5 / 6.5 | 10 / 2 / 5.5 | 8 / 2 / 5 |
| Chase speed | 21 | 21.5 | 20.5 | 20 |
| AlertSeconds | 0.6 | 0.6 | 0.7 | 0.8 |
| StandOffStuds | none | none | 9 | none |
| Attack range | 7 | 10 | 15 | 7 |
| Telegraph / Lock / Travel (s) | 0.8 / 0.45 / 0.45 | 0.9 / 0.5 / 0.55 | 1.0 / 0.5 / 0.6 | 1.2 / 0 / 0.25 |
| Shape | Radius 4 | Length 13 Ã— Width 4.5 | Radius 4.5 | Radius 9 |
| Recover / Cooldown (s) | 0.6 / 4 | 0.7 / 5.5 | 0.7 / 4.5 | 0.8 / 6.5 |
| Push studs / seconds | 6 / 0.3 | 8 / 0.35 | 5 / 0.3 | 6 / 0.3 |
| Slow multiplier / seconds | 0.8 / 2 | 0.75 / 2.5 | 0.8 / 2 | 0.75 / 2.5 |
| TELL_COLOR (none is red) | `6FE3CF` | `FF9F43` | `FF8FB8` | `7FB8FF` |

**Damage.** Kittens hurt lightly (7-10, below the critters' 12-23) through the existing BeastHit path, and the egg is kept. That is the same damage path and rule as the candy critters (`WildboundBeasts.server.luau:660-671`). No new damage path is added.

### K-D6. Smarts profiles and zones

- **Rows** in `Smarts.PROFILES`:
  ```lua
  GatitoLanudo   = profile({ sprint = 28, sprintSeconds = 1.5, guard = 24, relentless = true, zone = 60 })
  GatitoGuerrero = profile({ sprint = 27, sprintSeconds = 1.5, guard = 24, relentless = true, zone = 60 })
  GatitaBouquet  = profile({ sprint = 27, sprintSeconds = 1.5, guard = 24, relentless = true, zone = 60 })
  GatitoActually = profile({ sprint = 26, sprintSeconds = 1.5, guard = 24, relentless = true, zone = 60 })
  ```
- **Sprint gain** is at most (28 - 23.2) Ã— 1.5 = 7.2 studs, which is under the 15 of the CH2 rule. The kittens are not added to the `CANDY` list in Smarts_Test (:515); they get their own suite.
- **Zone 60** (the plot uses 75-100):
  - It keeps every hunt, which goes up to about zone + 12, plus attack and push, at least 30 studs from the wall and from the void edges (K-D7).
  - Neighbouring posts are 85 or more apart.
- **No wall change is needed.** East-born creatures already stay at x â‰¥ 948.
- **Hiding rules** apply automatically through the PROFILES row (`WildboundCandyHiding.luau:54-56`).

### K-D7. Posts: 8 (4 home posts and 4 east extra posts)

- **Rules.** world x 1038..1388, |z + 3| â‰¤ 180, 12 studs from the nest toward the nearest route, at least 85 from any other post (wake circles at most 2 Ã— 42), and at least 20 from a path centre line.
- **Data.** A new `Sites.EAST_FIXED` (world coordinates, frozen). It is deliberately not part of `FIXED`, which is pinned by Nests_Test:593, V3Layout_Test:42-47 and the plot tools.

| Key | Kitten | Kind of post | Post (world) | Nest |
|---|---|---|---|---|
| `kittenPostK1` | GatitoGuerrero | HOME | (1038, -46) | K1 |
| `kittenPostK2` | GatitaBouquet | HOME | (1043, 104) | K2 |
| `kittenPostK3` | GatitoActually | HOME | (1143, -53) | K3 |
| `kittenPostK4` | GatitoLanudo | HOME | (1158, 55) | K4 |
| `kittenPostK5` | GatitoGuerrero | EAST_EXTRA_POSTS | (1228, -61) | K5 |
| `kittenPostK6` | GatitaBouquet | EAST_EXTRA_POSTS | (1243, 60) | K6 |
| `kittenPostK7` | GatitoActually | EAST_EXTRA_POSTS | (1358, -111) | K7 |
| `kittenPostK8` | GatitoLanudo | EAST_EXTRA_POSTS | (1358, 105) | K8 |

- **Reach check.** The worst west case is K1: post 1038 - (60 + 12) = 966; minus range 10 and push 8 gives 948, which is east of the Collider face at 938.
- **Closest posts:**
  - K3â€“K5 at 85.4 (wakes 38 + 40);
  - K4â€“K6 at 85.1 (40 + 42).
- **Frenzy.** A steal at K1 calls posts within 150, which here is K3. No plot post is within 150 of any park nest: plot posts are at x â‰¤ 810, park nests at x â‰¥ 1038.

### K-D8. Nests: 8, ids K1..K8, under `Workspace.Candy_Este_v1.Nests`

**Rarity mix.** 3 Comun, 3 Rara, 2 Epica, by depth from the gate. There is no Legendaria: it stays event-only, as in the plot.

**Species.** `Nests.POOL` species unchanged: Gomibu, Tortidragon, Flanfuria. They need no new egg art, pet or icon.

**Pay.** A new `Nests.PARK_POOL` pays one tier more, the random world's `SpawnClock.REWARD` (eggEmberByTier :134):
- Comun: Gomibu, Fog (10);
- Rara: Tortidragon, FogFar (16);
- Epica: Flanfuria, Territory (24).

The risk tier stays `Nests.RISK`.

**Ids.** "CandyK1".."CandyK8" collide with no existing C, R, E, L, T, H or I id, and "CandyT1" (La Duquesa) is untouched.

| Id | Rarity | Nest (world) | Post | Guard attribute | Chest (world, front faces the nest) |
|---|---|---|---|---|---|
| K1 | Comun | (1038, -58) | K1 | `GatitoGuerrero` | (1038, -65) |
| K2 | Comun | (1043, 92) | K2 | `GatitaBouquet` | (1043, 85) |
| K3 | Comun | (1143, -65) | K3 | `GatitoActually` | (1143, -72) |
| K4 | Rara | (1158, 67) | K4 | `GatitoLanudo` | (1158, 74) |
| K5 | Rara | (1228, -73) | K5 | `GatitoGuerrero@kittenPostK5` | (1228, -80) |
| K6 | Rara | (1243, 72) | K6 | `GatitaBouquet@kittenPostK6` | (1243, 79) |
| K7 | Epica | (1358, -123) | K7 | `GatitoActually@kittenPostK7` | (1358, -130) |
| K8 | Epica | (1358, 117) | K8 | `GatitoLanudo@kittenPostK8` | (1358, 124) |

**Each nest** is a part-built cat basket with 2 parts:
- `Collision_Bowl`: a cylinder {2.2, 6, 6}, Wood, colour (205,150,105), Role "solid", PrimaryPart, laid on its side as in Island.plainNest. Its top is at 2.7, so the egg sits at y about 1.9 (`WildboundServer:1052`).
- `RarityRing`: {0.08, 8, 8} in the ring colours from Facts, CanCollide false.

**Marker contract** (the park writes it; Nests reads it): Model `Nest_K<n>` with attributes:
- `NestId = "K<n>"`, `Rarity`, `EventOnly = false`, `Candidate = true`, `Enabled = true`;
- `Park = true`, `Guard = <string from the table>`;
- tag `WildboundCandyNestCandidate`.

**Restock.** It follows the existing 300 s wave refill with no code (`WildboundServer:1281-1285, :3950-3972`).

### K-D9. Reading the park nests without touching WildboundServer

All of this goes in `WildboundCandyNests.luau`, which is not a protected file:

1. **`Nests.read(root)`.** When `root.Name == Nests.ROOT_NAME` and `root.Parent ~= nil`, it also reads `root.Parent:FindFirstChild(Nests.PARK_ROOT).Nests` (`PARK_ROOT = "Candy_Este_v1"`). Each park marker gets `park = true`, and `guard` from its `Guard` string attribute.
   - The server's existing call `CandyNests.read(workspace:FindFirstChild(CandyNests.ROOT_NAME))` therefore returns both roots.
   - Test scratch roots have no parent, so they are unaffected.
2. **`Nests.bind`** skips `m.park == true`, the same way it skips house and island nests.
3. **`Nests.islands`** uses `Nests.pick(m.rarity, m.park)`, sets `guard = m.park == true and m.guard or binding[m.id]`, and adds `park = true` to the entry.
4. **`Nests.applyFlags(...)` gets a 9th parameter `Park`** (nil = `ServerStorage:FindFirstChild("WildboundKittenPark")`, false = none). After the Island step it does `pcall(P.syncNests, parkRoot)`, where `parkRoot = root.Parent and root.Parent:FindFirstChild(Nests.PARK_ROOT)`, and returns a 9th value.
5. **`Nests.posts`** is unchanged, so the count of 9 still holds.

### K-D10. Biome rules

- **`Config.NO_GLOBAL_BIOMES = { Meadow = true, CandyEast = true }`.** Viper, Pouncer, Streamer, Root, Gaze, Lurker and Scuttler never roll in the park.
- **`world.inCandy(x, z)`**, defined as `inMeadow(x, z) or Biomes.has(x, z, "CandyEast")`, is used at `:513` (targetOf). A forest encounter that follows a player into the park therefore closes ("Pradera").
- **Not changed:**
  - :1056 (pinned needle; park viewers simply count as non-meadow viewers);
  - bossPass (Don Glaseon stays in the plot);
  - ambushes (the plot square only).

### K-D11. Summoning in the park

- **`summonPass`.** Both `:1093` and `:1094` use `world.inCandy(p.X, p.Z)`. A park steal starts the frenzy, and park players reach the KIDS loop. The director's biome rule keeps the two creature sets apart.
  - `want.meadow = true` now means "in a summoning biome".
- **East extra posts.** After the existing EXTRA_POSTS loop, a second loop over `Sites.EAST_EXTRA_POSTS` has the same body. It calls `Director.summon(..., { post = extra.key })` and `world.startAtPost`, and writes the same telemetry refusal string.
- **Sites changes.**
  - `Sites.world`: `local fixed = Sites.FIXED[key] or Sites.EAST_FIXED[key]`.
  - `Sites.wants` :179: `if name ~= "DonGlaseon" and (Sites.FIXED[key] or Sites.EAST_FIXED[key]) then`.

### K-D12. Kitten visuals: part-built templates and a Heartbeat pose client

- **Templates.** `ReplicatedStorage.WildboundBeasts.Models.<Name>`, built at server start from primitive Parts and Sphere SpecialMeshes only. No MeshId, TextureID, Decal or upload.
- **Model rules.**
  - At most 25 BaseParts, the `RootPart` included.
  - `PrimaryPart = RootPart`: {1, 1, 1}, Transparency 1, centred on the ground pivot, facing -Z.
  - Every part Anchored and Massless, with CanCollide, CanQuery and CanTouch false.
  - Every part has a `Joint` attribute: Body, Head, EarL, EarR, Tail, PawL, PawR or Prop.
- **Heights and signature props** (the pack sheets are 2.4-4; scaled up so they read as guardians beside a 5-stud player):

  | Kitten | Height | Signature props |
  |---|---|---|
  | Lanudo | 6 | pink yarn-ball body with 3 bands, mint head |
  | Guerrero | 7 | red spear 9 long, tip at most 8.5 high; shield |
  | Bouquet | 5.5 | white and grey body, pink bow, 3 tulips |
  | Actually | 6 | orange body, black glasses rings, raised index finger |

- **Recipes.** Follow the art pass (Â§B.4), within those counts.
- **Animation.** Both rest offsets and joint pivots are expressed in RootPart space. Every frame:
  ```
  part.CFrame = root.CFrame * CFrame.new(pivot) * pose[joint] * CFrame.new(-pivot) * rest
  ```
  - It runs on Heartbeat, through `workspace:BulkMoveTo`.
  - RootPart is never posed.
  - Models more than 200 studs from the camera are skipped.
  - The order against the beast client's PivotTo does not matter, because PivotTo moves the model rigidly.

### K-D13. Music: a new `gatitoMusic` bed that replaces the Caramelo track inside the park

- **Candidate ids, in fallback order:**
  1. 108517170970006 "Tiny Kitten's Happy Adventure";
  2. 122890771686677 "Lazy Kitten Loop";
  3. 133622392487696 "Sneaky Kitten";
  4. final fallback: 1846279685 APM "Merry Kids", the same library as the live Caramelo track.
- **Rule.** The parent keeps only the ids that pass `search_asset` and a Studio `ContentProvider:PreloadAsync` Success. If none of the three kitten ids passes, the slot is `{ 1846279685 }`, and the owner is told the kitten-named tracks failed.
- **Changed 2026-11-20 (TB-3, owner request "que tenga otra musica").** The slot is now `{ 1839661368, 1846279685 }`: APM "Cute Cat" (95 s), then APM "Merry Kids". The three kitten-named ids above are off the slot.
- **Switch.** A new client sets the local `WildboundWorldUI` attribute `GatitoAmbience`:
  - on inside x 948..1468, z -263..257;
  - off once more than 8 studs outside that rectangle (hysteresis).
- **Precedence.** `Audio.client` computes `candy = CandyAmbience and not kitten`, so the kitten bed wins in the overlap x 948..964.
- **Volumes.** 0.18 when Safe, 0.09 when Distant, 0 when Near or in a Chase. It fades like a bed (4 s). safeMusic and carameloMusic are 0 while in the park.

### K-D14. Sky and light: a new "Gatuno" preset with a blue sky, white clouds and a long, clear view

- **BiomeLight** (repo copy edited in full; Studio big4 copy gets a hunk):
  - `CandyEast` becomes the first row of `AREAS` and `AREAS_BIG4`, so x 932..1012 stops reading "Caramelo";
  - `TAG_PRESET.CandyEast = "Gatuno"`;
  - `PRESETS.Gatuno = { label = "Pueblo Gatito Â· siempre de dÃ­a", mood = "Day", clockTime = 13, zone = "park", variants = false, tint = {255,255,255}, saturation = 0.06, contrast = 0.03, lift = 0.03 }`;
  - `RULES.Gatuno = "Day"`.
- **Atmosphere** (needed, because an unknown zone falls back to fogEnd 140):
  - `ROWS.park = { Day = {0.22, 0.1, 0.6, 150, 1100}, Dusk = {0.28, 0.08, 0.8, 110, 700}, Night = {0.34, 0.05, 1.0, 70, 450} }`;
  - `ZONE_COLOURS.park = { atmosphere = {199,226,245}, fog = {214,236,250} }`.
- **CandySky** becomes per preset:
  - Caramelo stays exactly as today;
  - Gatuno shows white clouds (cover 0.45, density 0.4, colour 255,255,255), with no decay change and no skybox swap, so the place's own blue Sky shows.

### K-D15. Ground and wall look

- `East.FLOOR_COLOR = {140, 201, 107}`, floor material "Grass". The floor still covers the band under the Veil.
- The Veil stays cloud pink, because it belongs to both sides.

### K-D16. Park layout

See Appendix A for the full coordinates.

- **Zones** in park-local coordinates (world = (1208 + lx, -3 + lz); north is +z):
  - gate meadow: lx -260..-200;
  - Plaza Central (-120, 0);
  - shop village south: lz -75..-200;
  - toy park north: lz 90..240;
  - yarn forest: lx 60..240;
  - Torre Gato VigÃ­a stand-in at (220, 0).
- **Arrival clear disc:** world (964, -3), r 30. Only the path and the arch stand in it.
- **Arco de Nubes:** world (954, -3). Its pillars stand at z 6 and -12, which leaves 15 clear studs and lines up with the 14-stud gap.
- **Drop rules,** applied deterministically in `plan()`. A scatter or decor item is dropped when it lies:
  - within 8 of a nest, a post or a chest;
  - within 12 of the portal;
  - inside the arrival disc;
  - within 6 plus half the path width of a path centre line (except path pieces and lanterns placed on purpose).
- **Signs.** SurfaceGui with a TextLabel, Latin text only, strings kept in the park module: "Pueblo Gatito", "CafÃ© Cat", "Paws & Coffee", "PanaderÃ­a Gatuna", "=^.^=", "Takoyaki", "Taiyaki", "Mochi". No CJK, to avoid any font risk.

### K-D17. The 70 annex props in the space are archived

The build tool moves every child of `Workspace.WildboundCandyAnnex_Big4` whose pivot lies in x 948..1468, z -263..257 to `ServerStorage.WildboundMapArchive.KittenParkAnnex`, with a dry run first. They clash with the green park and are not counted in the budget.

### K-D18. Part budget

BaseParts only. SpecialMeshes, 12 PointLights (Shadows false) and about 12 SurfaceGuis come on top.

| Folder (`Candy_Este_v1.*`) | Parts |
|---|---|
| Park.Paths: main 104 (8 sand strips, 7 joint discs, 89 slabs) + forks 145 + 5 junction discs | 254 |
| Park.Gate (Arco de Nubes) | 8 |
| Park.Village: CafÃ© 38, PanaderÃ­a 34, Alfarero 40, Globo Pez 36, Takoyaki 39, Taiyaki 33, Castillo cartÃ³n 53, Torre VigÃ­a 37 | 310 |
| Park.ToyPark: Castillo Rascador 44, Ãrbol Rascador 33, Torre de Cajas 21 | 98 |
| Park.Toys: yarn 63, rolls and tubes 30, swabs 25, paper 19, bags 23 (no laptop) | 160 |
| Park.Chests: 8 Ã— 11 | 88 |
| Park.Trees: 18 large Ã— 6 + 19 small Ã— 4 + 12 bushes Ã— 2 | 208 |
| Park.Lanterns: 8 tall Ã— 5 + 18 short Ã— 5 | 130 |
| Park.Scatter: 16 patches + 24 flower clusters Ã— 3 + 24 tufts Ã— 2 | 136 |
| **Park total (cap 1400; the drop rules only lower it)** | **1392** |
| Nests: 8 Ã— 2 | 16 |
| Ground and CloudWall (Floor, Collider, ColliderSouth, Veil, two caps) | 6 |
| **Candy_Este_v1 total (cap 1422)** | **1414** |

Built at runtime, outside this root:
- the portal station: 5;
- kitten templates: at most 4 Ã— 25 = 100;
- per client: 8 resting copies, about 190 parts, plus at most about 8 live or bystander views.

### K-D19. Build pipeline

- **One-shot Edit tool** (saved into the place): the park geometry, the gate split, the green floor, the annex archive and the corridor archive.
- **At every server start:** kitten templates (KittenService), park nest sync (applyFlags step 9), nest read and merge, the `parque` portal, resting posts, and the KEEP_CLEAR-aware planners.

### K-D20. Protected files

- **No WildboundServer hunk, no WildboundText hunk.** Consequences:
  - kittens show no warning line, which is allowed (`WildboundBeasts.client.luau:742-744`);
  - the portal shows the fallback name "Portal".
- **WildboundBiomes:** no change; verify only.
- **WildboundBiomeLight:** the one Studio hunk set (K-D14).
- **WildboundWorld and WildboundWorldClient:** untouched.
- **SistemaSonriente** is never touched: every new builder refuses it through `East.forbidden`.

### K-D21. Out of scope

- a kitten egg species, pet or hotbar icon (the icon needs an upload approval);
- the Torre VigÃ­a GLB (an upload);
- Ciudad Felina;
- the checkout and conveyor belt;
- shops as refuges (houseDiscs reads `Candy_Bioma_v1` only);
- NPC or shop interactions, and any economy in the shops;
- park ambushes, park bees, Don Glaseon or La Duquesa changes;
- a carrier-allowed link (decision 47 stands);
- monetization, publishing, any asset upload;
- two-player and phone verification.

---

## 3. Work split

Three implementers work in parallel on disjoint files and never call Studio. The parent is the only Studio writer and merges A, B and C before any Studio step.

### Set A: park map and gate

**Files.**
- NEW `tools/WildboundKittenPark.luau` (ServerStorage)
- NEW `tools/wildbound-kitten-park-build.luau` (Studio: disabled Script `ServerStorage.WildboundKittenParkBuild`)
- CHANGED `tools/WildboundCandyEast.luau`: GATE, the split, floor colour and material, header lines 8-18
- CHANGED `tools/WildboundCandyLayout.luau`: the KEEP_CLEAR row from K-D2
- NEW `tests/WildboundKittenPark_Test.luau`
- CHANGED `tests/WildboundCandyEast_Test.luau`, `tests/WildboundCandyLayout_Test.luau`
- CHANGED `tools/studio-fresh-runner.luau`: every SPECS row in Â§4, for all three sets

**Interface it exports** (pure, apart from the build functions):

```lua
Park.VERSION = 1; Park.ROOT_NAME = "Candy_Este_v1"; Park.FOLDER = "Park"; Park.NESTS_FOLDER = "Nests"
Park.FORBIDDEN = "SistemaSonriente"; Park.SEED = 8128
Park.NESTS = frozen { { id = "K1", rarity = "Comun", x = 1038, z = -58,
    post = { key = "kittenPostK1", x = 1038, z = -46 },
    guard = "GatitoGuerrero", chest = { x = 1038, z = -65 } }, ... K8 }   -- the K-D8 table, world coordinates
Park.PORTAL  = frozen { x = 980, z = 40 }
Park.ARRIVAL = frozen { x = 964, z = -3, r = 30 }
Park.plan(L?, East?) -> { centre, space, gate = { x = 954, z = -3, width = 14 }, paths = { { id, width, points = { {x, z} } } },
    items = { { id, kind, folder, x, z, yaw, variant? } }, budget = { [folder] = n }, parts = n }
Park.recipe(kind, variant?) -> { { name, shape, size = {x, y, z}, offset = {x, y, z, rx, ry, rz}, color = {r, g, b},
    material, role, transparency?, light?, text? } }                 -- local to the pivot, front -Z
Park.build(root, L?, East?) -> report { created, changed, parts, byFolder }       -- idempotent
Park.syncNests(root) -> changed:number    -- uses Park.NESTS only; idempotent; creates, re-flags or moves Nest_K*; removes nothing else
Park.archiveAnnex(annexRoot, archiveFolder, L?, East?, dryRun) -> { moved = { names }, count }
Park.clearGate(biomeRoot, archiveFolder, dryRun) -> { moved = { names }, count }  -- corridor x 896..932, z -17..11, colliding pieces only
```

**Roles** (Builder rules): floor parts collide and are queried; solid parts collide and are queried; decor parts do neither and are not touched.

**WildboundCandyEast changes.**
- `East.GATE`.
- `plan().parts` becomes 6, in this order: Floor, Collider, ColliderSouth, Veil, CapNorth, CapSouth.
- `plan().gate = { minZ = -10, maxZ = 4 }`.

**Build tool,** following the v8 migrate pattern (`docs/design/wildbound-caramelo-v8-plan.md:107-133`): `DRY_RUN = true` first.
1. Back up `Candy_Este_v1` to `WildboundMapArchive.KittenParkBackup`.
2. Run `East.build(workspace, Layout)`.
3. Run `Park.clearGate`.
4. Run `Park.archiveAnnex`.
5. Run `Park.build(workspace.Candy_Este_v1)`.
6. Run `Park.syncNests`.
7. Set the root mark `KittenPark = 1`; refuse to run without `CaramelV8`.
8. Record one ChangeHistory entry, "KittenPark".
9. Print a JSON summary of the part counts per folder, before and after.

### Set B: kitten gameplay, nests, portal

**Files** (all CHANGED unless marked):
- `src/wildbound/WildboundBeastConfig.luau`: 4 rows (K-D5); WAVE2 and SUMMONED add the 4 names; NO_GLOBAL_BIOMES (K-D10)
- `src/wildbound/WildboundPraderaSites.luau`: HOME +4, `EAST_FIXED`, `EAST_EXTRA_POSTS`, `world`, `wants` (K-D7, K-D11)
- `src/wildbound/WildboundCandySmarts.luau`: 4 PROFILES rows (K-D6)
- `src/wildbound/WildboundBeasts.server.luau`:
  - KIDS +4 rows before the DonGlaseon row;
  - `world.inCandy` right after :237 (on `world`: no new top-level local);
  - :513, :1093, :1094;
  - the EAST_EXTRA_POSTS loop after :1125.
- `src/wildbound/WildboundBeasts.client.luau`: TELL_COLOR +4 (K-D5)
- `src/wildbound/WildboundCandyRestingService.server.luau`:
  - NAMES +4;
  - the filter becomes Include `{ Candy_Bioma_v1.Ground, Candy_Este_v1.Ground }` (each only if present, `WaitForChild(â€¦, 10)` for the east root; no nil holes in the array);
  - a loop over `Sites.EAST_EXTRA_POSTS` after :53 publishing `RestingPost_<name>_<key>`.
- `src/wildbound/WildboundCandyRestingClient.client.luau`: NAMES +4
- `src/wildbound/WildboundCandyNests.luau`: K-D8 and K-D9
- `src/wildbound/WildboundPortal.luau`: the `parque` row (K-D3), and the comment at :30-35
- NEW `tests/WildboundCandyKittens_Test.luau`
- CHANGED `tests/WildboundCandyNests_Test.luau`, `tests/WildboundPortal_Test.luau`, `tests/WildboundBeastDirector_Test.luau`

**Data shapes.**

```lua
Sites.HOME += { GatitoGuerrero = "kittenPostK1", GatitaBouquet = "kittenPostK2", GatitoActually = "kittenPostK3", GatitoLanudo = "kittenPostK4" }
Sites.EAST_FIXED = frozen { kittenPostK1 = {x = 1038, z = -46}, kittenPostK2 = {x = 1043, z = 104}, kittenPostK3 = {x = 1143, z = -53},
    kittenPostK4 = {x = 1158, z = 55}, kittenPostK5 = {x = 1228, z = -61}, kittenPostK6 = {x = 1243, z = 60},
    kittenPostK7 = {x = 1358, z = -111}, kittenPostK8 = {x = 1358, z = 105} }
Sites.EAST_EXTRA_POSTS = frozen { {name = "GatitoGuerrero", key = "kittenPostK5"}, {name = "GatitaBouquet", key = "kittenPostK6"},
    {name = "GatitoActually", key = "kittenPostK7"}, {name = "GatitoLanudo", key = "kittenPostK8"} }
Nests.PARK_ROOT = "Candy_Este_v1"
Nests.PARK_POOL = frozen { Comun = {species = "Gomibu", rewardTier = "Fog"}, Rara = {species = "Tortidragon", rewardTier = "FogFar"},
    Epica = {species = "Flanfuria", rewardTier = "Territory"} }
Nests.pick(rarity, park?) -> { species, rarity, rewardTier, tier } | nil
-- marker from read(): { id, rarity, x, z, top, enabled, eventOnly, house, island, park, guard }
Nests.applyFlags(root, Builder, Layout, HouseNests, HideSpots, Grass, Traps, Island, Park) -> 9 numbers
```

**Interfaces with the other sets.**
- **With A:** the nest marker contract (K-D8). A suite case asserts that `Park.NESTS[i].post` equals `Sites.EAST_FIXED[key]` and that its guard matches `HOME` or `EAST_EXTRA_POSTS`.
- **With C:** the model names `Models.GatitoLanudo`, `Models.GatitoGuerrero`, `Models.GatitaBouquet` and `Models.GatitoActually` (resting client clones), and TELL_COLOR only.

### Set C: kitten look, music, light

**Files.**
- NEW `src/wildbound/WildboundCandyKittens.luau` (ReplicatedStorage, pure)
- NEW `src/wildbound/WildboundCandyKittenService.server.luau` (Studio `ServerScriptService.WildboundCandyKittenService`)
- NEW `src/wildbound/WildboundCandyKittenAnim.client.luau` (Studio `StarterPlayerScripts.WildboundCandyKittenAnimClient`)
- NEW `src/wildbound/WildboundCandyKittenAmbience.client.luau` (Studio `WildboundCandyKittenAmbienceClient`)
- CHANGED `src/wildbound/WildboundAudioCatalog.luau`: `gatitoMusic`
- CHANGED `src/wildbound/WildboundAudioMix.luau`: BEDS gets `gatitoMusic`, plus `Mix.KITTEN` and `Mix.withKitten`
- CHANGED `src/wildbound/WildboundAudio.client.luau`: lines 208-210 only
- CHANGED `src/wildbound/WildboundAtmosphere.luau`: `ROWS.park` and `ZONE_COLOURS.park`
- CHANGED `src/wildbound/WildboundBiomeLight.luau` (repo copy): K-D14
- CHANGED `src/wildbound/WildboundCandySky.client.luau`: per-preset SKY
- CHANGED `docs/audio/wildbound-horror-audio-shortlist.md`: a new "Kitten park music (2026-11-17)" table with the 4 ids
- NEW `tests/WildboundCandyKittenArt_Test.luau`
- CHANGED `tests/WildboundAudioMix_Test.luau`, `tests/WildboundBiomeLight_Test.luau`, `tests/WildboundCandySky_Test.luau`, `tests/WildboundAtmosphere_Test.luau`

**Interface.**

```lua
Kittens.NAMES = { "GatitoLanudo", "GatitoGuerrero", "GatitaBouquet", "GatitoActually" }
Kittens.MAX_PARTS = 25; Kittens.CULL_STUDS = 200
Kittens.PARK = frozen { minX = 948, maxX = 1468, minZ = -263, maxZ = 257 }; Kittens.LEAVE_MARGIN = 8
Kittens.GUI_ATTRIBUTE = "GatitoAmbience"
Kittens.parts(name) -> { { name, shape = "Block"|"Ball"|"Cylinder"|"Wedge", mesh = "Sphere"?, size = {x, y, z},
    offset = {x, y, z, rx, ry, rz}, color = {r, g, b}, material, joint } }    -- first entry is RootPart
Kittens.pivots(name) -> { [joint] = {x, y, z} }                              -- in RootPart space
Kittens.pose(name, phase, t, reduced) -> { [joint] = CFrame }               -- missing joint = identity; never RootPart
Kittens.build(name) -> Model                                                -- unparented; named name; PrimaryPart RootPart
Kittens.inPark(was, x, z) -> boolean
Mix.KITTEN = { track = 0.18 }
Mix.withKitten(t, level, kitten, kittenTrack) -> t
-- kittenTrack ~= true: t unchanged
-- else: t.gatitoMusic = kitten and 0.18 * (Safe 1 | Distant 0.5 | else 0) or 0
--       when kitten: t.safeMusic = 0, and t.carameloMusic = 0 if the key is present
```

**Poses.**
- Calm and Patrol: an idle bob of at most 0.15 studs, a tail wag of at most 20Â°, ear flicks.
- Notice: a head tilt of 12Â°.
- Chase and Return: a hop of at most 0.6 studs at 3 Hz.
- Telegraph, the signature move:
  - Lanudo: the body rolls 30Â°;
  - Guerrero: Prop (spear) raised 35Â°;
  - Bouquet: PawR and Prop (flowers) forward 0.6;
  - Actually: PawR raised 40Â°.
- Release: a forward lunge of 0.4.
- Recover: a 0.2 crouch.
- Reduced: all amplitudes Ã— 0.4.
- Any other phase: idle.

**KittenService.** Waits up to 60 s for `ReplicatedStorage.WildboundBeasts.Models`. For each name it calls `Kittens.build(name)`, replaces any old `Models.<name>`, and sets the attributes `Species = name` and `Height`.

**Anim client.**
- Watches `workspace:WaitForChild("WildboundBeastsLocal")` with ChildAdded, ChildRemoved and the existing children.
- Sets up each model whose Name is in NAMES once, caching rest offsets.
- On Heartbeat it reads `BeastPhase`; the phase time is local `os.clock()` since the attribute last changed.
- It uses `BulkMoveTo` and skips models beyond CULL_STUDS from `workspace.CurrentCamera`.

**Ambience client.** Polls the character root every 0.25 s and sets `PlayerGui.WildboundWorldUI:SetAttribute("GatitoAmbience", on)`; it sets false on `script.Destroying`.

**Audio.client hunk** (it keeps the pinned needles):

```lua
local kitten = worldGui:GetAttribute("GatitoAmbience") == true
local candy = worldGui:GetAttribute("CandyAmbience") == true and not kitten
local candyTrack = Catalog.SOUNDS.carameloMusic ~= nil
local targets = Mix.withKitten(Mix.targets(level, phase, reduced, candy, candyTrack), level, kitten, Catalog.SOUNDS.gatitoMusic ~= nil)
```

**Interfaces with the other sets.** The model names must equal Set B's Config keys. There is no interface with Set A.

---

## 4. Tests per work set

### Set A

**`WildboundKittenPark_Test`** (Invoke with Park, East, Layout).
- KP1: every item and path point lies within the space inset by 4. The arrival disc holds only the Gate and Paths; the portal disc (r 12) is empty.
- KP2:
  - 8 nests K1..K8 with unique ids, none in `Layout.NESTS`, and no "T1";
  - rarity counts 3, 3, 2;
  - every post 12 Â± 0.01 from its nest;
  - posts at least 85 apart;
  - every post in x 1038..1388 with |z + 3| â‰¤ 180;
  - every chest 7 from its nest, on the far side from the post;
  - every guard string matches `^%w+$` or `^%w+@kittenPost%w+$`.
- KP3: no solid or floor-role part (other than Paths) within 8 of a nest, post or chest. Every solid part is at least 6 plus half the width from every path centre line.
- KP4: the per-folder counts equal the K-D18 table minus the drops; the Park total is at most 1400 and the Nests at most 16.
- KP5: build into an unparented Model:
  - a second build reports created 0 and changed 0;
  - every part Anchored, with roles and flags matching;
  - no MeshPart, Decal, Texture or MeshId;
  - the sources lack "rbxassetid", "MeshId" and "TextureID";
  - a sign is a SurfaceGui with a TextLabel and no ImageLabel.
- KP6: `syncNests` on a scratch root writes 8 `Nest_K*` models with the full contract and `PrimaryPart = Collision_Bowl`. A second call returns 0. A moved nest is put back. A foreign child stays untouched.
- KP7: `archiveAnnex` dry run lists exactly the pieces inside the rectangle and moves nothing; the real run moves only those.
- KP8: `clearGate` moves only colliding pieces in the corridor; decor stays.
- KP9: the builders refuse a parent inside SistemaSonriente.

**`WildboundCandyEast_Test`, deliberately changed.**
- :62 parts 5 â†’ 6;
- :66 collider length 536 â†’ 261;
- :68-71 Collider centre z -3 â†’ 134.5;
- :72-73 and :132 floor colour and material;
- :113-114 parts 6, created at least 9;
- :142 BasePart count 6;
- :143-149 the flag loop adds ColliderSouth.

New case:
- no colliding part at x 938..942 for z in (-10, 4);
- both pieces at x 940;
- `wallOf` still returns x 940;
- `outsideWall(1000, -3, 930, -3, wall)` returns 948, and `outsideWall(900, -3, 950, -3, wall)` returns 932.

**`WildboundCandyLayout_Test`, new case.** The KEEP_CLEAR gate row is at (250, 0) with r 16. No Layout nest lies within r + 8, and no BOSS territory point does either.

**Runner SPECS** (added to `tools/studio-fresh-runner.luau` by Set A):

```lua
SPECS["WildboundKittenPark_Test"] = { "mod:WildboundKittenPark", "mod:WildboundCandyEast", "mod:WildboundCandyLayout" }
SPECS["WildboundCandyKittens_Test"] = { "mod:WildboundBeastEncounters", "mod:WildboundBeastCandyCritter", "mod:WildboundBeastConfig",
    "mod:WildboundPraderaSites", "mod:WildboundCandySmarts", "mod:WildboundBeastDirector", "mod:WildboundBeastChase",
    "mod:WildboundCandyNests", "mod:WildboundKittenPark", "mod:WildboundPortal", "mod:WildboundBiomes",
    { beasts = "src:WildboundBeasts", client = "src:WildboundBeastsClient", resting = "src:WildboundCandyRestingService",
      restingClient = "src:WildboundCandyRestingClient" } }
SPECS["WildboundCandyKittenArt_Test"] = { "mod:WildboundCandyKittens",
    { service = "src:WildboundCandyKittenService", anim = "src:WildboundCandyKittenAnimClient",
      ambience = "src:WildboundCandyKittenAmbienceClient", audio = "src:WildboundAudioClient" } }
```

The existing rows for Nests, Portal, Director, AudioMix, BiomeLight, CandySky, Atmosphere and East are unchanged, unless a suite's header adds an argument; then the row is updated to match.

### Set B

**`WildboundCandyKittens_Test`.** Mirror the harness of `tests/WildboundBeastCandyCritter_Test.luau` :1-6, :41-107.
- KK1 config: for each of the 4 rows:
  - Guardian, CandyEast, points and chance 0;
  - in SUMMONED and WAVE2, not PLAYABLE, frozen, cooldown 5;
  - chase in (16, 23.2), tell at least MIN_TELL;
  - slows within `Chase.EFFECTS`;
  - damage in 7..10, keepsEgg;
  - no Gift and no Call extras.
- KK2 behaviour, per kitten, on a flat fake world: Patrol and Calm at the post; a target at its perception gives Notice then Chase; Telegraph is at least MIN_TELL; a hit carries slow and push; the cooldown holds.
- KK3 zone (RC1 pattern, `Smarts_Test:521-547`): a hunt ends with Return at endX in (60, 72]; relentless; sprint gain under 15.
- KK4 wall: a kitten stepped from (950, -3) toward x 900 ends at x â‰¥ 948 through `outsideWall` with `{x = 940}`.
- KK5 sites:
  - `Sites.world(nil, key)` for the 8 keys equals EAST_FIXED and the K-D7 table;
  - `wants` is true at 1 stud inside the wake radius and false at 1 stud outside, false for a dead or safe player, and true in a frenzy within 150;
  - every post lies inside the space with zone + attack range + push + 12 at least 10 from the space edges, and x - 84 â‰¥ 938;
  - every pair of posts is at least 85 apart;
  - `Park.NESTS` posts and guards agree with Sites.
- KK6 director:
  - each kitten with `{CandyEast = true}` is accepted, and with `{Meadow = true}` refused "Biome";
  - Mochimiau with `{CandyEast = true}` is refused "Biome";
  - Viper with `{CandyEast = true}` is refused "NoGlobalZone";
  - `alarm(..., "kittenPostK5")` for GatitoGuerrero books post kittenPostK5.
- KK7 wiring by source:
  - KIDS has 4 CandyCritter rows;
  - `function world.inCandy(` is present;
  - `world.stealCheck(player, character, p, at, world.inCandy(p.X, p.Z))`;
  - `if not world.inCandy(p.X, p.Z) then`;
  - `for _, extra in ipairs(Sites.EAST_EXTRA_POSTS) do`, present in both the server and the resting service, and the old EXTRA_POSTS needle is still present in both;
  - resting NAMES has the 4 names in both the service and the client;
  - `Candy_Este_v1` is in the resting filter;
  - TELL_COLOR has the 4 hex values.

**`WildboundCandyNests_Test`.**
- Deliberately changed: :523 needle becomes `world.inCandy(p.X, p.Z)`.
- New cases:
  - PK1: a scratch parent Folder holding `Candy_Bioma_v1` (1 nest) and `Candy_Este_v1.Nests` (2 park markers): `read` returns 3, the park ones have park = true and their guard.
  - PK2: `islands` gives a park Comun Fog / Gomibu, and a park Epica Territory / Flanfuria; a park Legendaria is dropped.
  - PK3: the guard comes from the attribute; a plot post 5 studs from a park marker never binds it.
  - PK4: `applyFlags` with a fake Park `{ syncNests = function(r) calls += 1; return 3 end }` calls it once with the sibling root and returns 3 as the 9th value; with an unparented root it is not called; with `false` it is not called.
- Still holding: :70 (#posts 9), :205, :260.

**`WildboundPortal_Test`.**
- Deliberately changed: :167, 2 â†’ 3.
- New case: `parque` is in CandyEast (Biomes), at least 300 from the hub, outside every safe zone, yaw 90, y 0.5.

**`WildboundBeastDirector_Test`.** The KK6 refusals are mirrored next to :594-605, and the :595 loop still expects cooldown 5 for every SUMMONED beast.

### Set C

**`WildboundCandyKittenArt_Test`.**
- KA1: NAMES are the 4 names, none with "_". `parts(name)` has at most 25 entries with RootPart first; joints come from the allowed set; heights are Lanudo 5.5..6.5, Guerrero 6.5..8.6, Bouquet 5..6, Actually 5.5..6.5; the head centre z is below 0 (it faces -Z); no mesh other than Sphere.
- KA2: `build(name)` gives a Model named name, PrimaryPart RootPart with Transparency 1 at y 0 Â± 0.6; every part Anchored and Massless with CanCollide, CanQuery and CanTouch false; no MeshPart or Decal.
- KA3: `pose` for every phase in {Spawn, Calm, Patrol, Notice, Chase, Telegraph, Release, Recover, Return, Disengage, Ended, "x"} and t in {0, 0.37, 1.9}: translation at most 1.0 and rotation at most 45Â°; never a RootPart key; Reduced at most 0.45 Ã— the full amplitude; deterministic.
- KA4: `inPark`: (1000, 0, false) is true; (944, 0, true) is true; (939, 0, true) is false; (944, 0, false) is false; NaN is false.
- KA5 sources:
  - the service, anim and ambience scripts lack "rbxassetid", "MeshId", "TextureID", "FireServer", "RenderStepped" and "SistemaSonriente" (the anim needs no forbidden-name check: it reads only its own folder);
  - the anim has `Heartbeat:Connect`, `BulkMoveTo` and `Kittens.CULL_STUDS`;
  - the ambience has `SetAttribute(Kittens.GUI_ATTRIBUTE` and `script.Destroying`;
  - the audio client has `Mix.withKitten(`, the three CandyAmbience_Test needles, and `Catalog.SOUNDS.gatitoMusic ~= nil`.

**`WildboundAudioMix_Test`, new cases.**
- `withKitten(targets(Safe, Day, false, false, true), "Safe", true, true)` gives gatitoMusic 0.18, carameloMusic 0, safeMusic 0.
- Distant gives 0.09; Chase and Near give 0.
- kitten false gives gatitoMusic 0.
- kittenTrack false gives the input table unchanged, with no gatitoMusic key.
- `fadeSeconds("gatitoMusic", false)` is 4.
- Every key is still a catalog slot (AM8).

**`WildboundBiomeLight_Test`.**
- Deliberately changed: :88-93, CandyEast â†’ "Gatuno".
- New cases:
  - `presetAt(1200, 0, "classic")` is "Gatuno";
  - `PRESETS.Gatuno.zone` is "park" and `RULES.Gatuno` is "Day";
  - AREAS[1].tag is "CandyEast";
  - `target(Atmosphere, "Gatuno", "open")` fogEnd â‰¥ 900.
- The big4 assertions run in Studio only (Â§5).

**`WildboundAtmosphere_Test`.** `at(13, "park")` fogEnd is 1100; `atmosphereColor` matches (199, 226, 245); there are rows for Day, Dusk and Night.

**`WildboundCandySky_Test`.** :45-46 are deliberately changed: SKY is keyed by preset, Caramelo's values are unchanged, and Gatuno has white clouds with no skybox and no decay.

**Python** (`tools/test_wildbound_audio_catalog.py`): the environment has no Python, so the parent checks the shortlist lines by eye: every kept id is on a line without "rejected".

---

## 5. Studio deploy steps (parent only)

1. **Target.** Verify the Studio instance and place (b15ce60a, place 122652861404212), that `workspace.WildboundMapMode` is "big4", and the AGENTS.md target confirmation.
2. **Fingerprints.** Compare every Studio Source to be replaced with the merge base: Config, Sites, Smarts, Nests, Portal, the Beasts server and client, the two Resting scripts, the three Audio scripts, Atmosphere, CandySky, Layout and East. Stop if any of them drifted.
3. **Read-only probes.**
   - `require(WildboundBiomes).at(1150, 0)` is `{CandyEast = true}` and has no Meadow; `at(960, 0)` is the same.
   - Rays down at the 8 posts and 8 nests hit `Candy_Este_v1.Ground.Floor` at y 0.5.
   - List what stands in the gate corridor.
4. **Music.**
   - Run `search_asset` for each candidate id.
   - In Play, run a client `PreloadAsync` on a Sound per id and record each status.
   - Keep the ids that report Success; write the final slot and the shortlist lines (a parent repo edit).
5. **Deploy, in Edit, in this order.**
   1. ReplicatedStorage: `WildboundAtmosphere` (the park row must exist before the preset), then `WildboundBiomeLight` as a **hunk in the big4 copy**:
      - move `square("CandyEast", 932, 1468, -263, 257)` to the first row of AREAS and of AREAS_BIG4;
      - set `TAG_PRESET CandyEast = "Gatuno"`;
      - add `PRESETS.Gatuno` and `RULES.Gatuno`.
      Then `WildboundBeastConfig`, `WildboundCandyKittens`, `WildboundAudioCatalog`, `WildboundAudioMix`.
   2. ServerStorage: `WildboundCandyLayout`, `WildboundCandyEast`, `WildboundKittenPark`, the disabled Script `WildboundKittenParkBuild`, every new or changed `_Test`, and the runner.
   3. ServerScriptService: `WildboundPraderaSites`, `WildboundCandySmarts`, `WildboundCandyNests`, `WildboundPortal`, `WildboundBeasts`, `WildboundCandyRestingService`, and the new Script `WildboundCandyKittenService`.
   4. StarterPlayerScripts: `WildboundBeastsClient`, `WildboundCandyRestingClient`, `WildboundAudioClient`, `WildboundCandySkyClient`, and the new `WildboundCandyKittenAnimClient` and `WildboundCandyKittenAmbienceClient`.
   5. Fingerprint every deployed script against the merged HEAD. BiomeLight is checked against the hunk text.
6. **Suites, in a fresh Play server VM** (the edit-mode require cache is unreliable):
   - new: KittenPark, CandyKittens, CandyKittenArt;
   - existing: CandyEast, CandyLayout, CandyNests, Portal, BeastDirector, CandySmarts, BeastCandyCritter, BeastWiring, CandyAmbience, AudioMix, AudioWiring, Atmosphere, CandySky, BiomeLight (big4 copy), PortalService, V3Layout, HideSpots, Grass, Traps, Flyers.
   - Then a Studio console check: `presetAt(960, 0)` is "Gatuno", `presetAt(1300, 0)` is "Gatuno", `presetAt(900, 0)` is "Caramelo".
7. **One-shot build (Edit).**
   - Run `WildboundKittenParkBuild` with `DRY_RUN = true`. Expect about 70 annex pieces, the listed corridor pieces, Park at most 1400 and Nests 16.
   - Then the real run, then save the place the way v8 was saved. **Never publish.**
8. **What runs at server start** (nothing to do): KittenService templates, applyFlags step 9 `syncNests`, the nest read and merge, the `parque` station, resting posts, and the planners keeping off the gate.
9. **Play checks, solo, each with an observed value.**
   - **Gate.** Walk east at z -3 and pass to x > 960. Walk east at z -30 and stop at x â‰ˆ 937.
   - **Look.** In the park the HUD label reads "Pueblo Gatito", the floor is green and the clouds white. Studio captures may render white, so the owner judges the look.
   - **Music.** At x 1000, `WildboundWorldUI.GatitoAmbience` is true and `CandyAmbience` false, and the gatitoMusic layer is about 0.18. At x 900 the Caramelo track is back.
   - **Templates and resting copies.** `Models` has the 4 kittens. Eight `RestingPost_*` attributes exist. `WildboundBeastsLocal` holds 8 resting copies with BeastPhase Calm at y about 0.5, all moving (bob and tail).
   - **Encounter.** Walk to (1038, -30): Guerrero wakes, chases and hits with a slow. `Beast_lastSummonRefusal` shows no kitten refusal.
   - **Steal.** Take the egg at K1: `Beast_frenzies` goes up by 1, Actually from K3 comes, and the egg prompt shows Gomibu Comun.
   - **Carry home.** Carry it west through the gate to the base and bank it for 10 embers. The `parque` portal refuses while carrying and teleports home when empty-handed.
   - **Wall.** During a chase near the gate no kitten position is below x 948; inspect the encounter in telemetry.
   - **No Global beasts.** Stand in the park for 3 minutes: no Viper or Pouncer spawns, and the director log shows NoGlobalZone.
   - **Restock.** After the next 300 s wave the K1 egg is back.
   - **Part count.** The runtime part count of `Candy_Este_v1` is at most 1422.
10. **Record** the evidence, commit, and the music ids and statuses in `odd/tasks/wildbound-caramelo-v2.md` under a new "Pueblo Gatito (K-D1..K-D21)" section. Tell the owner to audition the music and judge the look.

---

## 6. Risks

1. **BiomeLight ordering in Studio.** The big4 Meadow square runs to x 1012 and is matched first, so if CandyEast is not moved to the first row, x 932..1012 stays pink. Step 6 checks `presetAt(960, 0)` for this.
2. **Deploy order of light.** If BiomeLight is deployed before Atmosphere, the park falls back to the "open" row: fogEnd 140, a grey mist.
3. **Music ids are unverified.** The creators of the three kitten tracks are unknown. The fallback ladder and the Studio preload gate cover a failure, and the owner must audition.
4. **Pinned needles** (Facts). Only Nests_Test:523 is deliberately changed. Every other needle must survive byte for byte.
5. **Luau local limit in the beast server.** Every new helper goes on `world`.
6. **Sight through the gate.** A Caramelo creature clamped at x 932 can see a player in the corridor and lob at them (range up to 18). The park also works as a refuge from plot hunters, who end at their zones anyway.
7. **Kitten lob or burst through the gap.** Posts are at least 90 from the wall and zones are 60, so a hit from the far side of the wall is unlikely. It is not impossible during a long chase to the gate.
8. **The walk home is long** (830-985 studs, compared with about 540 from the Torta). Pay is one tier up; play may show it needs more.
9. **Live map writes.** The annex archive and corridor archive touch `WildboundCandyAnnex_Big4` and `Candy_Bioma_v1`. Both make a backup and a dry run first, and nothing is deleted.
10. **Performance.** About 1414 more saved parts, 12 PointLights, and 8 always-drawn resting copies (the resting client never culls). This has not been checked on phones.
11. **Shared chaser cap.** Kittens share the per-player cap (1 â†’ 3, 5 in a frenzy). A player who just left the plot with candy hunters may not be engaged by kittens at once.
12. **La Silueta and other non-director threats** in the park are not covered by NO_GLOBAL. Check this in Play.
13. **Fresh-runner limits.** Workspace-dependent checks (floor rays at posts) are Studio probes, not suites. Brain suites must run in a fresh Play server VM.
14. **Heartbeat ordering** against the beast client's PivotTo. It is correct by construction (rigid PivotTo), with at most one frame of pose lag.
15. **Damage policy.** The kittens deal damage through the same BeastHit path as the candy critters. Any place-level damage switch applies unchanged.
16. **The KEEP_CLEAR row** moves hide spots, grass and traps near the gate at the next server start. That is intended, but the next Play shows a slightly different scatter near (922, -3).

---

## Appendix A: park layout (park-local (lx, lz); world = (1208 + lx, -3 + lz))

### Paths

**Main path M**, 12 wide: sand strips, joint discs at the bends, slabs every 5 alternating Â±2.5.
(-252, 0) â†’ (-200, 0) â†’ (-160, 6) â†’ (-120, 0) â†’ (-60, -8) â†’ (0, 0) â†’ (60, 10) â†’ (120, 0) â†’ (190, 0)

**Forks**, 8 wide, stepping stones every 7 with Â±1 jitter:

| Fork | Points |
|---|---|
| S | (-120, 0) â†’ (-112, -55) â†’ (-100, -105) |
| V | (-195, -120) â†’ (-100, -110) â†’ (-20, -130) â†’ (45, -125) |
| VL | (45, -125) â†’ (95, -60) â†’ (120, 0) |
| N | (-120, 0) â†’ (-112, 55) â†’ (-100, 105) |
| T | (-200, 150) â†’ (-100, 110) â†’ (-20, 140) â†’ (45, 130) |
| TL | (45, 130) â†’ (95, 60) â†’ (120, 0) |

**Junction discs:**

| Disc | Centre | Diameter |
|---|---|---|
| Plaza Central | (-120, 0) | 30 |
| Village Square | (-100, -110) | 26 |
| Toy Plaza | (-100, 110) | 26 |
| East Junction | (120, 0) | 24 |
| Tower Plaza | (215, 0) | 50 |

### Gate and portal

- Arch at (-254, 0).
- Arrival disc at (-244, 0), r 30.
- Portal at world (980, 40), local (-228, 43).

### Buildings and big toys

| Item | Local | Yaw | Folder |
|---|---|---|---|
| CafÃ© Cat | (-170, -150) | 180 | Village |
| PanaderÃ­a Gatuna | (-130, -82) | 0 | Village |
| Casa Gato Alfarero | (-60, -150) | 180 | Village |
| Tienda Globo Pez | (-30, -95) | 0 | Village |
| Takoyaki | (15, -160) | 180 | Village |
| Taiyaki Mochi | (40, -95) | 0 | Village |
| Castillo cartÃ³n (its cushion stays as decor) | (-190, -175) | 180 | Village |
| Torre Gato VigÃ­a stand-in | (220, 0) | 90 | Village |
| Castillo Rascador | (-160, 175) | 0 | ToyPark |
| Ãrbol Rascador | (-60, 175) | 0 | ToyPark |
| Torre de Cajas | (-110, 160) | 0 | ToyPark |

Yaw 0 means the front faces -z.

### Toys

**Giant yarn balls:**

| Ball | Local | Diameter |
|---|---|---|
| rainbow | (95, 160) | 16 |
| sky | (155, 75) | 14 |
| pink | (180, 175) | 14 |
| cream | (150, -85) | 12 |
| orange | (105, -190) | 14 |
| lime | (195, -160) | 12 |
| purple | (210, 75) | 16 |

**Small yarn balls:** (-140, 198), (-40, 215), (-95, 190), (85, -125), (125, 140), (180, -30), (230, -80).

**Rolls and tubes:**
- toilet roll, standing: (-15, 185);
- toilet roll, lying along x: (30, 195);
- kitchen roll: (-5, 205);
- tube tunnel along x: (20, 215);
- tubes: (35, 170) and (-30, 195);
- tube bundle: (-25, 165).

**Swabs:**
- benches along x: (-118, 128), (-82, 92), (-82, -100);
- swab cup: (-90, 148);
- crossed swabs: (55, 170).

**Paper:**
- balls: (-140, 140), (-35, 150), (70, 145), (-175, 215), (-75, 215), (165, -20);
- flat sheet: (-150, 235); tent: (-5, 232); notebook sheet: (-205, 235).

**Bags:**
- paper bags: (-8, -146) and (-150, -95);
- plastic bags: (-5, -100) and (-200, -100);
- giant fallen bag: (-190, 190), yaw -45.

**Chests:** at the K-D8 chest points.

### Trees and lanterns

**Pink tree, large (18):** (-235, 45), (-235, -50), (-150, 40), (-150, -45), (20, 40), (25, -45), (-100, -155), (15, -90), (-125, 222), (105, 100), (130, 40), (165, 115), (205, 200), (60, 190), (105, -110), (175, -60), (130, -220), (80, -150).
- (-235, 45) falls inside the portal clear radius and is dropped.

**Pink tree, small (19):** (-215, 85), (-215, -90), (-75, 35), (-80, -40), (60, 60), (65, -60), (-205, -140), (-85, -75), (-15, -170), (-60, 225), (45, 225), (135, 120), (195, 140), (120, 205), (230, 150), (125, -45), (200, -110), (215, -205), (235, -120).

**Bushes (12):** (-222, 32), (-222, -36), (-140, -60), (-150, 60), (-40, -75), (55, -75), (-215, -160), (-185, 120), (-25, 110), (75, 30), (240, 40), (85, -25).

**Tall bell lanterns, with light (8):** (-205, 9), (-150, -10), (-90, 9), (-30, -13), (30, 14), (90, -4), (150, 9), (180, -9).

**Short flower lanterns (18):**
- village street: (-180, -108), (-140, -125), (-60, -110), (-20, -140), (20, -117), (45, -135);
- toy loop: (-160, 143), (-60, 135), (0, 128), (40, 140);
- Plaza Central: (-132, Â±12), (-108, Â±12);
- Tower Plaza, with light: (195, Â±20), (235, Â±20).

### Scatter (decor; the drop rules apply)

**Ground patches (16):** (-230, 120), (-230, -130), (-165, 95), (-60, 70), (-60, -60), (0, -215), (-140, -220), (-120, 240), (30, 90), (80, 40), (150, 30), (200, 130), (100, 230), (200, -60), (160, -200), (60, -230).
- (-165, 95), (-60, 70) and (-60, -60) are dropped by the nest rule.

**Flower clusters (24):** (-212, 20), (-212, -22), (-185, 18), (-190, -22), (-140, 25), (-95, -22), (-70, 15), (-20, 22), (-10, -25), (45, 28), (95, -15), (150, -18), (160, 22), (-170, -100), (-115, -135), (-45, -100), (5, -112), (-175, 125), (-130, 95), (-40, 120), (20, 150), (-120, 190), (110, 170), (130, -170).

**Grass tufts (24):** (-205, 40), (-205, -45), (-175, -40), (-165, 30), (-100, 30), (-100, -35), (-50, 25), (-30, -30), (5, 30), (35, -30), (68, -25), (105, 25), (175, 25), (175, -25), (-150, -130), (-75, -135), (25, -140), (-185, 160), (-70, 150), (-5, 160), (75, 120), (200, 170), (120, -140), (190, -200).
- (-175, -40) is dropped by the post rule.

## Appendix B: recipe summary

Each recipe has its pivot at its ground centre, local y from FLOOR_TOP 0.5, front toward -Z. "B+S" means a Block with a Sphere SpecialMesh. Material is SmoothPlastic unless noted.

**Fixed:** the part counts in K-D18 and the footprint and height per item below.

**Free:** inner details, within the pack palette (art pass Â§2): GRASS 140,201,107; SLAB 199,183,155; BLOSSOM 242,165,204; TRUNK 150,104,72; CARD 199,154,104; PAPER 250,248,244; LIGHT Neon 251,226,164.

**Ground and gate:**
- Slab: 6.5 Ã— 0.3 Ã— 4.8, Slate, floor role.
- Sand strip: 12 wide Ã— 0.24, Sand.
- Arch: 2 cylinder pillars, diameter 3, height 14; 5 cloud B+S; a sign 0.4 Ã— 2.2 Ã— 10.

**Buildings** (width Ã— depth footprint, height, parts):

| Building | Footprint | Height | Parts |
|---|---|---|---|
| CafÃ© | 24 Ã— 24 | 24 | 38 |
| PanaderÃ­a | 24 Ã— 18 | 22 | 34 |
| Alfarero | 18 Ã— 18 | 26 | 40 |
| Globo Pez | 14 Ã— 14 | 26 | 36 |
| Takoyaki | 20 Ã— 16 | 19 | 39 |
| Taiyaki | 20 Ã— 16 | 20 | 33 |
| Castillo cartÃ³n | 32 Ã— 28 | 26 | 53 |
| Torre VigÃ­a | 18 across | 34 | 37 |

- Bodies and solid shells use the solid role; walkable tops use the floor role; everything else is decor.
- Each step a player climbs is at most 6.

**Big toys:**
- Castillo Rascador: 16 Ã— 14, 26 tall, 44 parts.
- Ãrbol Rascador: 28 Ã— 24, 24 tall, 33 parts; its platforms use the floor role.
- Torre de Cajas: 6 Ã— 6, 11 tall, 21 parts.

**Small toys:**
- Giant yarn ball: a Fabric Ball plus 3 band cylinders and 3 strand B+S (7 parts). Small yarn ball: 2 parts.
- Toilet roll: diameter 8 Ã— 7 (4 parts). Kitchen roll: diameter 7 Ã— 12 (5).
- Tube tunnel: 7 staves, radius 4.1, open at the bottom. Tube: 3 parts. Bundle: 4 parts.
- Swab bench: a stick of diameter 1 Ã— 16 plus 2 cotton tips (3 parts). Swab cup: 10 parts. Crossed swabs: 6 parts.
- Paper ball: 2 parts; flat sheet: 1; tent: 2; notebook sheet: 4.
- Paper bag: 6 parts. Plastic bag: 3, Transparency 0.15. Giant bag: 5, open toward -Z with an inside of 9.4 Ã— 7.4 Ã— 13.4.
- Chest: about 7 Ã— 5 Ã— 5, 11 parts, lid open 55Â° toward the nest; only the base is solid.

**Trees and lanterns:**
- Large tree: about 22 tall; trunk cylinder of diameter 2.4 Ã— 12 (solid) plus 4 crown B+S (decor). Small tree: about 14 tall, 4 parts.
- Bush: 2 B+S.
- Tall lantern: 12 tall, 5 parts; Neon bulb with a PointLight (range 14, brightness 1, Shadows false).
- Short lantern: 6.5 tall, 5 parts.

**Kittens:** the four pack sheets 21-24 at the K-D12 heights, with the art pass part lists: Lanudo 15, Guerrero 22, Bouquet 24, Actually 24, plus RootPart.
