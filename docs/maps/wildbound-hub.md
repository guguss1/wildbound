# Wildbound hub with personal bases: integration note

**Update (2026-11-10, HF-T3): the forest shift S1 placed the hub at (282, 0, -3), east of the forest kit; new characters start on its spawn pads facing east (HB6); the camp link is gone and `FK_Evergreen_095` and `FK_Evergreen_101` are removed at start (HB7). Sections 2 and 5 describe the preview state before it.** **Status (2026-11-10, the feature document's "Nest Heist hub", HB-T1 to HB-T7): built in Studio at server start at the preview origin (0, 0, 600), with base assignment, per-owner delivery, incubator, collection display, glove and training stations, the safe disc and a walkable link from the camp, all checked in a solo Studio Play session; not measured on a device, not tried with two or more real players, the forest is not shifted yet (S1).** Written 2026-11-10 for the master prompt's lobby (`docs/design/wildbound-combined-plan.md` sections 1 and 2): a safe central lobby, a personal base for each of up to 8 players around it, physical exits to the forest, and no PvP and no beasts inside. Every number is a hypothesis for playtests.

## Quick path

| You are | Read |
| --- | --- |
| The Studio writer | Sections 2 (deploy and run), 3 (tags), 5 (code changes and what is done) |
| The user | Section 6 (decisions) and the picture in section 1 |
| A reviewer | Section 7 (what is verified) |

## 1. What the builder makes

| File | Role |
| --- | --- |
| `tools/plan_hub_bases.py` | Planner. Writes `assets/maps/hub-layout/hub-bases-v1.json` |
| `tools/build-hub-map.py` | Generator. Turns the JSON into a flat list of primitive parts and renders the module below, plus `assets/maps/hub-layout/hub-kit-report.json` |
| `tools/build-wildbound-hub-map.luau` | Generated ModuleScript. `Builder.build(parent, origin?)` only interprets the part list |
| `tools/test_plan_hub_bases.py`, `tools/test_build_hub_map.py` | Contracts (section 7) |

Regenerate with `python -I -B tools/plan_hub_bases.py`, then `python -I -B tools/build-hub-map.py`. `--check` on either reports a stale file.

Frame: the open-world hub frame of `assets/maps/open-world/layout-v1.json` (studs, origin at the hub centre, x east, z south). A bearing b is `(cos b, sin b)`: 0 east, 90 south, 180 west, 270 north.

| Piece | Where | Notes |
| --- | --- | --- |
| Lobby | Plaza disc r 30, campfire at the centre, 4 spawn pads (6 x 6) at r 16 facing east, 4 log benches, 4 lanterns, a rules sign "Plaza segura / Sin peleas ni bestias" | Warm light 255, 176, 96 as at the camp |
| Promenade | Paved ring r 46 to 54 | Joins every base walk and gate path |
| Bases 1 to 8 | Pad 26 x 22 centred on r 68 at bearings 22.5 + 45k, each facing the lobby | Colours Rojo, Naranja, Amarillo, Verde, Turquesa, Azul, Morado, Rosa (rim, fences, sign, glove, delivery ring, lobby flowers) |
| Base stations (local x right, local z away from the lobby) | Delivery (0, -4.5), treadmill (8, -4.5), gloves (-8, -5), incubator (-7, 4.5), collection display with 3 slots (6.5, 5) | 8-stud entrance gap in the front fence; the delivery pedestal is the first thing inside |
| Hedge wall | r 88, 2 thick, 4 high, 26 straight pieces | Six 16-stud gates |
| Entrances | E (Pradera, joins `umbral_este`), S and N (ring road spokes), W (joins `umbral_oeste` at its knee (-100, 20)), NW and SW (new forest trails to (-112, -90) and (-112, 90)) | Three lead to the forest; gates are at least 67 studs apart, so one player cannot block two |
| Safe zone | Invisible cylinder r 90, 40 high | Covers every base, station and pad |

The hub grew from layout-v1's radius 60 to **90**: eight bases and a lobby need about 81 studs of radius. The 90 disc stays inside the band no beast reaches (x -200 to 340) and outside both region squares (x -100 and 100); every Refugio candidate stays 20 studs clear, both first-steal hooks stay outside, and no spawn seed or Pradera kit prop falls inside (tested). The NW and SW trails would remove two forest edge trees, `FK_Evergreen_095` and `FK_Evergreen_101` (listed in the JSON as `removed_forest_props`).

Budget: **390 parts** (32 per base x 8 = 256, gates 36, hedge 26, lobby 59, paths 12, safe zone 1) under the open-world cap of 400 for the hub, and **19 PointLights** (campfire 1, plaza 4, gates 6, bases 8), all shadowless, range at most 30. Roles: 74 floor and 78 wall parts collide and answer queries; 231 decoration and 7 invisible zone parts have `CanCollide`, `CanQuery` and `CanTouch` off. Nothing is touchable. No MeshParts, uploads, toolbox ids, scripts or `SpawnLocation`.

## 2. Deploy and run (Studio writer)

**As built (HB-T1).** The hub is built at server start, so the place file never needs saving for it: the Script `ServerScriptService.WildboundHub` (`src/wildbound/WildboundHub.server.luau`) requires `ServerStorage.WildboundHubBuilder` (this module, mapped in `tools/deploy_manifest.py`) and calls `Builder.build(workspace, CFrame.new(Rules.HUB_X, 0, Rules.HUB_Z))`; a hub already in the place (built in Edit) is reused. **The origin is one config value**: `Rules.HUB_X, Rules.HUB_Z, Rules.HUB_RADIUS = 0, 600, 90` in `src/wildbound/WildboundWorldRules.luau`; the forest shift (S1) changes only those numbers (the build, the link and `Rules.zone` follow). Until S1 the same script builds `workspace.WildboundHubLink`, a straight 12-stud path (351 studs) from inside the camp's safe circle (`Rules.CAMP_X, CAMP_Z` = -140, 140) to the NW trail's outer end, with three lanterns and the sign "Plaza central y bases"; remove it after S1. The spawn stays at the camp until S1 (HB6). The manual steps below remain valid for a one-off preview in Edit.

1. Verify the Studio instance and place and get the user's confirmation of that target (`AGENTS.md`).
2. Create a ModuleScript `ServerStorage.WildboundHubBuilder` whose Source is the whole of `tools/build-wildbound-hub-map.luau`.
3. Run it once from the command bar or `execute_luau`:

   ```lua
   local Builder = require(game.ServerStorage.WildboundHubBuilder)
   -- Preview while the forest is still in its local frame (see below):
   local hub = Builder.build(workspace, CFrame.new(0, 0, 600))
   print(hub:GetAttribute("PartCount"), hub:GetAttribute("LightCount"), hub:GetAttribute("DataAdler32"))
   ```

   Expect `390 19` and the Adler-32 printed in the module's first line. A second call errors with `WildboundHub already exists`; to rebuild, `workspace.WildboundHub:Destroy()` first. A build error destroys the half-built model and nothing is attached.
4. Parent it to `workspace`, **never inside `WildboundP0`**: the server finds markers with `map:FindFirstChild(name, true)` on that model. The test `test_no_name_shadows_a_marker_the_current_code_looks_up` pins that no hub part is named like a marker the code looks up, but keeping it outside is the real protection.
5. **Origin.** The default `origin` is `CFrame.new(0, 0, 0)`, the open-world hub centre. Today the forest is still built in its local frame around the world origin (`Rules.HOME_X, HOME_Z = 0, -85`, camp at (-140, 140)), so building at the default origin would overlap the current forest. Until step S1 of `docs/design/wildbound-open-world-gaps.md` (the forest root `PivotTo` by (-300, 0, 0)) lands, build at an empty spot such as `CFrame.new(0, 0, 600)` for previews and phone captures. After S1, rebuild at the default origin. Pass only a translation: the safe zone and the plan's coordinates assume no rotation.
6. Play check after building: walk spawn pad to each base's delivery pedestal, through every gate, and onto a treadmill belt; check the signs read from the promenade on a phone.

## 3. Tags and attributes the game code binds to

Tags are CollectionService tags; read positions from the tagged part at runtime (the plan's numbers move with `origin`).

| Tag | On | Count | Attributes |
| --- | --- | --- | --- |
| `WildboundHub` | Root model (`ModelStreamingMode` Persistent) | 1 | `Plan`, `PartCount`, `LightCount`, `DataAdler32`, `SafeRadius` |
| `WildboundBaseSlot` | Base model `Bases/BaseN` (PrimaryPart `Pad`) | 8 | `SlotIndex` 1..8, `BaseId`, `ColourName`, `BaseColor` (Color3), `Bearing`, `Yaw`, `OwnerUserId` 0, `OwnerName` "" |
| `WildboundDeliveryStation` | `DeliveryPedestal` | 8 | `SlotIndex`, `StationKind`, `Label` "Entrega de huevos", `Range` 8 |
| `WildboundIncubatorStation` | `IncubatorBase` | 8 | Same plus `Slots` 1 |
| `WildboundCollectionDisplay` | `DisplayPlatform` (its siblings `DisplaySlot1..3` carry `DisplayIndex`) | 8 | Same plus `DisplaySlots` 3 |
| `WildboundGloveStation` | `GloveBench` | 8 | Same, `Label` "Guantes" |
| `WildboundTrainingStation` | `TreadmillDeck` (the walkable `TreadmillBelt` is its sibling) | 8 | Same plus `Device` "treadmill", `BeltLength` 6.4 |
| `WildboundHubSafeZone` | `HubSafeZone` invisible cylinder | 1 | `ZoneId` "hub", `Radius` 90, `NoPvP`, `NoBeasts` |
| `WildboundHubEntrance` | `EntranceZone` invisible box in each gate | 6 | `EntranceId`, `Leads` (`forest`, `pradera`, `ring`), `Joins`, `Bearing`, `Width` 16 |
| `WildboundHubSpawnPad` | `SpawnPad1..4` | 4 | `SpawnIndex`, `Faces` "east", `Yaw` |
| `WildboundBaseSign` | `NameSign` board (SurfaceGui `Label`) | 8 | `SlotIndex`, `SignKey` `baseN`, `Placeholder` "<jugador>" |
| `WildboundHubCampfire` | Campfire model | 1 | `Radius` 3.5 |

Gate and rules signs carry `SignKey` (`gateE`, `gateW`, ..., `hubRules`) like the camp signs, so `WildboundText` can override their copy.

## 4. How it relates to the current camp

Keep the camp working until the hub replaces it. The builder's model is inert on its own (no scripts, no SpawnLocation, no marker names the server reads); since HB-T1 to HB-T6 the game code binds its tags (section 5), the disc is safe in `Rules.zone`, and the link path leads there from the camp. Players still spawn at the camp, and the camp's chest, incubator, refuge, board, treadmill and display all still work; the shared stations of HB2 (registration, chest, skill tree, trophies) stay at the camp. Retire the camp stations only after the code changes below pass their tests and a Play check, and the user agrees (decision OW2 suggests keeping the camp as a deep-west outpost).

## 5. Code changes (done 2026-11-10 unless marked; RED tests first, one Studio writer)

Done: rows 1 (without `MaxPlayers`: a Game Settings value, still 60; a ninth player simply gets no base), 2, 3, 4, 6 (the display, gloves and the hold-to-buy treadmill; time on the belt is not counted), 7, and 8 as `tests/WildboundHub_Test.luau` (rules and source contracts; the part count and lights are checked in Play, not by a Studio suite over the built model). Not done: row 5 (spawn, waits for S1). Where they live: `src/wildbound/WildboundBases.luau` (pure: slots, signs, the owner and range check, the display choice, the link geometry), `src/wildbound/WildboundHub.server.luau` (build, link, assignment), `src/wildbound/WildboundHubStations.luau` (one prompt per tagged station, owner and range checked on the server, the display), and one `do` block in `WildboundServer.server.luau` (`Heist.hub`, the handlers that reuse the camp's rules). Each client hides the station prompts of every base that is not its own.

| # | Change | Where |
| --- | --- | --- |
| 1 | **Base assignment on join.** A pure `WildboundBases` module: lowest free slot at `PlayerAdded`, released at `PlayerRemoving`, the same player keeps the slot on respawn. The server writes `OwnerUserId` and `OwnerName` on the base model and the sign text "Base de {DisplayName}" (and a free-base text, see HB4). Set the place's `MaxPlayers` to 8; a ninth player gets no base (gaps document 2.2) | New `src/wildbound/WildboundBases.luau`, `WildboundServer.server.luau`, `WildboundText` |
| 2 | **Delivery validation per base owner.** A delivery prompt per `WildboundDeliveryStation`; the server checks, in order: alive, the player carries an egg (`EggCarry` state `Carried`, the player is its carrier), the station's `SlotIndex` is the player's slot, and the server-measured distance to the pedestal is within `Range`. Then NH6 secures the egg and banks it. Another player's pedestal refuses with a new notice (for example `NotYourBase`: "Esta no es tu base"). The client never sends a slot, a position or an egg id the server did not issue | `WildboundServer.server.luau`, `WildboundEggCarry.luau` (unchanged rules), `WildboundText` |
| 3 | **Incubator per base.** Bind `WildboundIncubatorStation` by tag (never by name), one prompt per marker, only the owner's prompt enabled on each client and accepted on the server; `Hatch` measures the owner's own incubator, the camp's stays valid. `State:incubate` keeps its 12-stud rule and one slot. This replaces `docs/mechanics/wildbound-hub-systems.md` section 5's shared hub dome (see HB3 for the tag name) | `WildboundServer.server.luau:110` (the single `IncubatorMarker` binding), `WildboundIncubator` |
| 4 | **Safe zone in `Rules.zone`.** Add `Rules.HUB_X, HUB_Z, HUB_RADIUS = 0, 0, 90` (tunable 60 to 100) and make `safe` true inside it; with the forest translation (S1) this is the open-world doc's row 2 with 90 instead of 60. Every safe-zone consumer then covers the hub: `EggCarry` safe drops, the bat refusal for PvP, `inTerritory`, and the beast director never spawning, targeting or striking inside it. A pinned test: every base pad corner from the plan is safe | `WildboundWorldRules.luau`, `tests/WildboundWorldRules_Test.luau` |
| 5 | **Spawn.** Move the default `SpawnLocation` to the hub (or spawn on a `WildboundHubSpawnPad` facing east) once the hub is the start; the campfire now sits on the origin, so `Rules.SPAWN_PAD_*` must follow the new spawn (HB6) | Place, `WildboundWorldRules.luau`, `WildboundServer.server.luau` spawn pivot |
| 6 | **Collection display, gloves, training.** Hover the owner's Lumipols over `DisplaySlot1..3`; the glove station opens the glove roll (after decision D2); the treadmill counts time while the owner's root part is over `TreadmillBelt` (server position checks at the 1 Hz step, never `Touched`), with the training caps of the combined plan | Phase 3 modules |
| 7 | **Prompt keys.** Five station prompts per base fit in one reach; add them to a `Keys.HUB` group checked by `Keys.conflicts()` | `WildboundPromptKeys.luau` |
| 8 | **Studio contract.** `tests/WildboundHubMap_Test.luau`: part count 390, the tag counts above, only floors and walls collide, every station inside its base | `tests/` |

## 6. Decisions and open questions for the user

| ID | Question | Recommendation |
| --- | --- | --- |
| HB1 | Grow the hub from radius 60 (layout-v1) to 90, shrinking the 40-stud transitions to 10 studs | **Accepted by the parent (2026-11-10)**: `Rules.HUB_RADIUS` 90. Regenerate layout-v1's hub block from this plan in a later pass |
| HB2 | Where the shared stations of layout-v1 go (Refugio registration, Cofre, Puesto, Tablero, Árbol, trophies): the lawn between plaza and promenade, or inside each base | **Parent: they stay at the current camp until a later pass** (recommendation unchanged: the lawn ring r 30 to 46) |
| HB3 | Tag name: `WildboundIncubatorStation` (this builder, per base) or `WildboundIncubator` with `Site` (hub-systems spec) | **Parent: `WildboundIncubatorStation`**; the hub-systems spec section 5 is marked superseded. The camp keeps its `IncubatorMarker` |
| HB4 | Sign text before a player owns the base: the literal "Base de <jugador>" or "Base libre" | **Parent: "Base libre"**, "Base de {DisplayName}" when assigned (`Text.HUB.freeSign`, `ownedSign`) |
| HB5 | Per-base collection display replaces the shared Corral parcels (decision HS1)? | **Parent: yes, for now.** The corral parcels were never built in code; the camp's single display is unchanged |
| HB6 | Campfire on the origin moves the spawn off the old 9-stud spawn pad | **Done (HF-T3)**: a new character starts on the spawn pad of its base slot, facing east; the camp is the fallback |
| HB7 | Accept removing `FK_Evergreen_095` and `FK_Evergreen_101` for the NW and SW forest trails | **Done (HF-T3)**: the hub script removes both at server start |

## 7. What is verified and what is not

Verified offline by `tools/test_plan_hub_bases.py` (18 tests) and `tools/test_build_hub_map.py` (15 tests): schema and frame match layout-v1; eight bases with distinct colours, each facing the lobby; no overlap between bases (gap at least 2), lobby, promenade, gate paths and hedge; stations at least 2 apart and inside their pad with a 1-stud margin; decorations off bases, paths, pads and the campfire; a walking grid search (0.5-stud cells, 0.8-stud body clearance) reaches every station, every entrance trail end and every spawn pad from spawn pad 1; at least 3 entrances to the forest, gates 40+ studs apart, hedge closed between gates and open across each gate; trails join the layout-v1 connectors they name or reach the forest floor outside the fog and 20+ studs from both hooks; the removed forest props are exactly those under the new trails; the safe disc covers every base, station and pad; nothing lies within any beast's reach plus 10 studs; the bigger hub keeps layout-v1's Refugio, hook, seed and Pradera kit clearances; light budget; only floors and walls collide or query; one tag of each station kind per base at the planned spot; part and light budgets; ball and cylinder shapes Roblox accepts; no marker-name collision with the current code; parent-first model order; Spanish copy; block balance; determinism and freshness of every written file.

Verified in Studio (solo Play, 2026-11-10, HB-T1 to HB-T7): the module builds 390 parts and 19 PointLights at pivot (0, 0, 600) in `Workspace`; a walk from the camp spawn along the link reaches the NW gate and the campfire (33 s); the Studio player gets base 1 and its sign; delivery and incubation at the own base, refusals at another owner's (simulated) and a free base; the display, glove bench and treadmill; the safe disc refuses the bat and forced beasts. Not verified: sign readability on a phone; frame time with 19 lights (plus the link's 3); how the 4-stud hedge and 2.5-stud fences feel (both are jumpable); whether eight bases read as "mine" for kids; two or more real players at once; the MeshGen art on the display (its meshes could not be fetched in that session, so the primitive look showed).
