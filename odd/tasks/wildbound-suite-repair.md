# Wildbound stale-suite repair

Objective: make the Studio suites that pin values or strings the live modules changed (the Studio sync at `34eab83`) pass on the live modules again, without weakening any guard on a behaviour the live code lost.

Problem: a full fresh run (tools/studio-fresh-runner.luau) classed 29 failing cases in 15 suites as "stale suite". Some are deliberate live retunes, some look like lost behaviour, and some read the teammate's lock-zone scripts.

Scope (test files only): `tests/WildboundWorldRules_Test`, `WildboundDusk_Test`, `WildboundEconomy_Test`, `WildboundIsland_Test`, `WildboundAggroWiring_Test`, `WildboundHideWiring_Test`, `WildboundSiluetaMovesWiring_Test`, `WildboundSiluetaReworkWiring_Test`, `WildboundStartWiring_Test`, `WildboundIslandWiring_Test`, and the non-server cases of `WildboundBaseZone_Test`, `WildboundEggLoop_Test`, `WildboundHub_Test`, `WildboundIncubator_Test`, `WildboundWaveClock_Test`; their Studio copies in ServerStorage; this file.

Constraints:
- Never edit modules, `Tuning_Test`, `Record_Test`, `SpawnClock_Test`, or the lock zone (`WildboundServer`, `WildboundState`, `WildboundEggCarry`, `WildboundBatKnock`, `WildboundWorldClient`, their suites, every `SistemaSonriente` folder).
- Per failing case: (1) a deliberate live change: pin the live value and cite the live line; (2) the live code lost a guarded behaviour: leave the test, report a possible bug; (3) the case reads a lock-zone script: leave it, "teammate". When unsure, (2).
- Before overwriting a Studio Source, it must equal the repo (length and Adler-32 after CRLF to LF and trailing newlines trimmed). Read back after deploy. Never save, publish or edit Workspace.

TDD: Strict, source "user CLAUDE.md". Runner: the fresh-clone loader of `tools/studio-fresh-runner.luau` (filtered to the 15 suites, every failure message printed) in the Edit DataModel, plus `python -I -B -m unittest discover -s tools -p "test_*.py"`.

Route: inline (one writer, test files only; the classification read about 20 live sources through rg, no delegation available to this worker).

## Checklist

- [x] SR1 RED: filtered fresh run of the 15 suites on the live modules (run `afb9755a`, 2026-11-14): 211 passed, 29 failed.
- [x] SR2 Classify all 29 cases (table below): 11 (1), 12 (2), 6 (3).
- [x] SR3 Update the 11 decision-(1) cases in 4 files (WorldRules 5, Dusk 1, Economy 4, Incubator 1).
- [x] SR4 Deployed the 4 test files to Studio (each Source equal to the pre-edit repo first; read back equal to the new repo by length and Adler-32), GREEN rerun `f1e09afe`: 222 passed, 18 failed; every decision-(1) case passes, the 18 left are the 12 decision-(2) and 6 decision-(3) cases.
- [x] SR5 Python suite (2026-11-14): 1298 run, 5 failures, 28 skipped. None from this track: `test_export_economy_config_luau` x3 (EconomyConfig vs its document), `test_lumipol_v2.test_v1_files_are_unchanged`, `test_studio_fresh_runner.test_every_suite_has_a_spec_or_a_skip` (`WildboundRoulette_Test`, another track's new suite). A first run during other tracks' edits showed 16 transient failures; the rerun showed these 5.
- [ ] SR6 Owner decisions on the 12 decision-(2) cases and the open cycle decision (T08a here; T02 in `odd/tasks/wildbound-2-0.md`).

## Cycle decision (T08a)

The live cycle is Day 300 / Dusk 60 / Night 300 / Dawn 60 (`WildboundWorldRules.luau` PHASES and `WildboundEconomyConfig.luau` cycle). The 2.0 pack proposed 240/60/300/120. User decision 2026-11-14 ("Mantener 300/60/300/60"): the live split stays; the suites pinned in `9aaeee1` are final. `docs/mechanics/wildbound-economy-p0.md` still lists 360/72/216/72 (the Python export tests report that gap).

## Classification

| Suite | Case | Decision | Evidence |
| --- | --- | --- | --- |
| WorldRules | phase boundaries use the single 720 second cycle | 1 | `WildboundWorldRules.luau:7-10` Day 300, Dusk 60, Night 300, Dawn 60 (was 360/72/216/72 before `34eab83`) |
| WorldRules | phase duration and progression remain exact | 1 | same |
| WorldRules | clock starts and phase joins are continuous | 1 | same; Dusk starts at 300, Night at 360, Dawn at 660 |
| WorldRules | the start offset is drawn over non-Night time only | 1 | same; non-Night time is 420 s, `startOffset(0.5)` = 210, `startOffset(360/420)` = 660 |
| WorldRules | the wait to the first Night (renamed "follows the live cycle") | 1 | same; uniform over (0, 420]: median 210, p90 378 |
| Dusk | U8: WorldRules names Dusk and gives it longer than NIGHT_SOON | 1 | `WildboundWorldRules.luau:8` Dusk 60 s from 300; 59 s left at 301 > NIGHT_SOON 20 |
| Economy | the tuning copy carries the document's numbers (renamed "live numbers") | 1 | `WildboundEconomyConfig.luau:33` `bagItems = 12` (was 3) |
| Economy | capacity and loss follow owned upgrades only | 1 | `:33` 12 and `:157` Reinforced Pack `bagItems = 16` (was 4) |
| Economy | ECO-17 item Ember reads the stored tier | 1 | `:133-134` creatures 8/14/20/28/42, eggs 4/10/16/24/36 |
| Economy | I7: island tier Ember by tier | 1 | same |
| Economy | ECO-20 AFK-1 no grant runs on a timer | 3 | Studio `WildboundServer` line 3916: `task.wait(1 / Heist.BaseZone.CONSTANTS.STEP_HZ)` loop calling `Heist.stepBaseZones`; teammate. Note: the loop banks and secures eggs, so the AFK guard deserves the teammate's look |
| Incubator | NB4: the defaults, the live copy and the tuning hook | 1 | `WildboundIncubator.luau:20` `HATCH_SECONDS = 15` with the comment "15 s common, scaled by rarity" |
| Incubator | NS3: the hatch card names the companion | 3 | reads `WildboundServer` (`born.equipped`) |
| Island | CP4: the woken adult chases faster than a walker, slower than a carrying sprinter | 2 | `WildboundIsland.luau:46` `CHASE_SPEED = 23` (was 19) while its own comment (`:39-44`) still says a sprinting carrier (14 x 1.45 = 20.3) outruns it; at 23 nothing carrying escapes |
| AggroWiring | losing the quarry searches where it was last known | 2 | `WildboundWorld.server.luau:762-770` `loseTarget` now only `setMode(h, "Patrol")`; no `Brain.lostSight`, no Search, although the aggro-fix comment (`~:431-434`) still says losing it always starts a search there |
| AggroWiring | a fake retreat turns back to the search point | 2 | same: no `Moves.fakeRetreat` / `Moves.newFake` anywhere in the server |
| HideWiring | D6: a hunt on a player who hides becomes Search | 2 | same |
| SiluetaMovesWiring | FP4b: a lost quarry may start the search with a fake retreat | 2 | same |
| SiluetaReworkWiring | S4: a search walks to the hide spots near where she lost her quarry | 2 | same: `hideSpotsNear` (`:294`) and the `h.checkSpots` Search branch remain but nothing fills `checkSpots` |
| StartWiring | WIRE-6: the tutorial card gives way to a capture | 2 | `WildboundStart.client.luau:287` `card.Visible = false` unconditionally (the hide conditions are gone, the comment above still lists them); the tutorial card never shows |
| IslandWiring | K2: the refuge card carries the bonus and the next island | 2 | `WildboundClient.client.luau:699-702` `showCard` is suppressed ("WildboundBaseGuideClient displays a non-blocking top hatch banner"), but `Refuge.card`'s `bonus` and `next` lines are shown nowhere |
| BaseZone | BZ7: the server steps the zones | 3 | reads `WildboundServer` (`Heist.enterBase`) |
| BaseZone | BZ8: the guide client shows the safe banner | 2 | `WildboundBaseGuide.client.luau:113-115` `showBanner` only hides the banner; `Text.HUB.safeBanner` ("¡Estás a salvo!") is no longer shown |
| EggLoop | EL12: the server banks first, rewards, then auto-fills | 3 | reads `WildboundServer` (`Heist.enterBase`) |
| EggLoop | EL13: the clients only draw ... hatch banner | 2 | `WildboundBaseGuide.client.luau:459-483` `onHatched` builds hard-coded Spanish lines ("¡Tu huevo eclosionó!", "... se guardó en tu barra de herramientas") instead of `EggLoop.hatchLines` and `Text.LOOP`; the file header (`:10`) still says the words come from them. Likely tied to the creature toolbar; needs the owner to confirm, then the words belong in `Text.LOOP` |
| Hub | HB-T3: the owner's pedestal banks and secures the egg | 3 | reads `WildboundServer` (`delivery = function`) |
| Hub | HB-T5: the stations module hovers the owner's Lumipols | 2 | `WildboundHubStations.luau:187-189` `refreshDisplay` only clears; the HB-T5 comment above still describes the hover display |
| WaveClock | RW5: the server places the event egg | 3 | the first failing check reads `WildboundServer` (`tier = "Legendaria", kind = "Egg"`). Note: the client's `refreshBanner` now always hides the banner too |
| WaveClock | RW7: the inventory client draws the board and the banner | 2 | `WildboundClient.client.luau` `refreshBoard` and `refreshBanner` set `Visible = false` unconditionally; `View.waveBoard(` and `View.eventBanner(` are no longer called |

## Evidence

- SR1 RED (run `afb9755a`): WorldRules 39/5, Dusk 8/1, Economy 17/5, Incubator 5/2, Island 33/1, AggroWiring 8/2, HideWiring 13/1, SiluetaMovesWiring 4/1, SiluetaReworkWiring 6/1, StartWiring 8/1, IslandWiring 12/1, BaseZone 7/2, EggLoop 11/2, Hub 21/2, WaveClock 19/2 (passed/failed).
- Studio test copies matched the repo before any edit (length and Adler-32 for all 15).

- GREEN (run `f1e09afe`): WorldRules 44/0, Dusk 9/0, Economy 21/1, Incubator 6/1, Island 33/1, AggroWiring 8/2, HideWiring 13/1, SiluetaMovesWiring 4/1, SiluetaReworkWiring 6/1, StartWiring 8/1, IslandWiring 12/1, BaseZone 7/2, EggLoop 11/2, Hub 21/2, WaveClock 19/2.
- No Play session was used (the user was in Play once; this track waited for Edit). Nothing saved or published; Workspace untouched.
- CP4 resolved 2026-11-14 (user decision "Sí, a 19"): `WildboundIsland.luau:46` `CHASE_SPEED = 19`, deployed to Studio with a one-line edit; Studio copy matches the repo (24028 bytes, Adler-32 1077545602). Fresh load: Island 34/0, Tuning 14/1. The remaining Tuning DT1 failure is `WAKE_WINDUP` (module 0.35, schema default 0.4), a separate owner decision.
- WAKE_WINDUP resolved 2026-11-14 (user decision "Volver a 0.4"): `WAKE_WINDUP = 0.4`, deployed; Studio matches the repo (24114 bytes, Adler-32 4027590012). Island 34/0, Tuning 14/1; DT1 now stops at `World.EGG_SHARE` (module 0, schema 0.4), the bough-egg decision.
- Bough eggs resolved 2026-11-14 (user decision "Sí, activalos"): `WildboundSpawnClock.luau` `EGG_SHARE = 0.4` and the `canopy` rule restored; Studio matches the repo (14072 bytes, Adler-32 2557691973). SpawnClock 13/0, Tuning 14/1; DT1 now stops at `Eggs.STEAL_HOLD` (EggCarry 0.8, schema 0.5), in the teammate's lock zone. Economy sim v2 mirror moved to 0.4 (39/39 OK).
- Not committed (the task said do not commit). Engram mirror `odd/wildbound-suite-repair/tasks`: pending (not available to this worker).

## Next step

Tutorial card resolved 2026-11-14 (user decision "Que se muestre"): `WildboundStart.client.luau` `updateTutorial` shows the card again (hints on, no full screen, no capture, inventory closed). Studio matched HEAD before (14100/1578877645) and matches the repo after (14751/4053573199). StartWiring 9/0. Solo Play: state `robar`, card visible with "1/4 Busca un nido y mantén E." and Saltar, no script errors (`assets/exports/forest-kit/captures/tutorial-card-restored-desktop.jpg`). The start screen itself stays skipped (`show("closed")`), unchanged.

Silueta on loss resolved 2026-11-14 (user decision "que siga patrullando normal"): the live behaviour stays (losing a living quarry resumes the patrol). AggroWiring (2 cases), HideWiring D6, SiluetaMovesWiring FP4b and SiluetaReworkWiring S4 now pin it; three stale comments in `WildboundWorld.server.luau` updated (comments only). Studio matched HEAD before the edits and matches the repo after (World 82639/75932747). Fresh load: AggroWiring 10/0, HideWiring 14/0, SiluetaMovesWiring 5/0, SiluetaReworkWiring 7/0. `hideSpotsNear` and the hide-spot index stay in the code unused on loss.

Collection limit resolved 2026-11-14 (user decision "Volver a 100"): `WildboundEconomyConfig.luau` `collectionLimit = 100`; Studio `ReplicatedStorage.WildboundEconomyConfig` matches the repo (8939 bytes, Adler-32 3658947834). Record 25/0 (RT-17 passes). State 64/14: the four messages read are bag-size cases (expected 3, live 12), not checked against the old limit because Studio entered Play. Export tests unchanged at 9/3 (document drift).

Deferred (user decision 2026-11-14 "Después de su etapa"): Tuning DT1 `Eggs.STEAL_HOLD` (EggCarry 0.8 vs schema 0.5) waits until the teammate finishes stage 1; it is in their lock zone.

SR6: the owner decides each decision-(2) case (restore the behaviour, or confirm the change so the suite can pin it), the teammate looks at the 6 decision-(3) cases, and the user decides the cycle split (T08a).
