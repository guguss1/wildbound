# Wildbound balance pass (simulator findings, 2026-11-15)

## Objective

Apply the economy simulator's 2026-11-15 suggestions (`docs/balance/wildbound-2-0-economy-sim.md`, section "2026-11-15 findings") to the live game, one bounded task at a time, keeping saved data valid and the simulator mirrors in step with the live values.

## Problem and why

The live model shows the treadmill paying 37.5 Esencia/min for standing still, the walk training reaching the top in 136 s so the console is never worth buying, and a trained carrier outrunning every chaser. The user approved applying the suggestions ("Sí, aplicalos", 2026-11-15).

## Scope and constraints

- Server-authoritative. Saved data stays valid: schema steps only with a migration and tests; the 20 KB profile budget (RT-17) must hold.
- Strict TDD with a fresh loader: RED, then GREEN. Re-pin suites whose pinned numbers change on purpose and say so.
- Studio target: the instance whose place is 122652861404212 (confirmed). Edit mode only; compare fingerprints with repo HEAD before writing; read back after.
- No uploads, publishing, place save, monetization or SistemaSonriente changes.
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"` (known failure: `test_lumipol_v2` V1IsKept); `tools/test_wildbound_economy_sim_v2.py` and `check_drift` stay green.
- TDD: on (session configuration, Strict TDD Mode). Runner: Studio fresh loader (`tools/studio-fresh-runner.luau` SPECS) for Luau suites; unittest for Python.

## Checklist

- [x] BP1 Treadmill and training: a lap pays Esencia only on a level-up lap; level L+1 needs L+1 laps (about 20 min to the top); re-price the console as a shortcut; keep the unburdened walk cap 50. Route: inline (parent subagent, one writer). Done 2026-11-15 (`5287a33`; Studio suites and solo Play below).
- [x] BP2 Capped carrier speed: a carrier's share is taken of at most a 24 walk (one egg 16.5, three or more 13.5). Supersedes the 2026-11-14 decision "the trained walk also applies while carrying" (`odd/tasks/wildbound-playtest-fixes.md`). Done 2026-11-15 (Studio suites and solo Play below).
- [x] BP3 Reward findings 4, 5 and 9: Caramelo nests one reward tier lower, Nightbloom scarce again, trip-bonus minimum 45 s -> 25 s. Done 2026-11-15 (Studio suites and solo Play below). The other remaining findings (collection limit, sinks, incubation slots) are BP4a below.
- [x] BP4a "Liberar" (finding 8; handoff B4, first part): a server-validated release of a duplicate hatched creature for +4 Esencia, never the companion, a farm creature or the last of its species. Done 2026-11-15 (Studio suites and solo Play below).
- [x] BP4b Incubator slot upgrades that count on the base path (finding 7): the base fills the bought slots only (1, then 2 and 3), no longer a free eight. Done 2026-11-15 (Studio suites and solo Play below).
- [x] BP4c Extra farm slots for sale (400 / 900; finding 6), within the RT-17 20 KB profile budget. Done 2026-11-15 (Studio suites and solo Play below).
- [ ] BP4 Rerun the simulator, record before and after numbers, refresh the findings section.

## Decisions taken for the user

| ID | Decision | Why |
| --- | --- | --- |
| BP1-D1 | Lap progress is saved as `training.walkLaps` (laps toward the next level) inside the existing `training` map. No schema step: the record already accepts any string key with a count. | Progress survives a rejoin without a migration. |
| BP1-D2 | Laps needed for level L+1 = `LAP_STEP x (L+1)` with `LAP_STEP = 1` (153 laps, 1224 s, 20.4 min to level 17). A constant, not a tuning entry. | The simulator suggestion; no new tuning surface. |
| BP1-D3 | A level-up lap pays 5 Esencia (85 per account in all); other laps and every lap at the top pay nothing. | The suggestion's "at most 85 Esencia per account"; `antiAfk.timeBasedGrants = 0`. |
| BP1-D4 | Console re-priced: BASE_COST 30 -> 20, COST_GROWTH 1.2 -> 1.1 (level 1 20, level 17 92, total 811, was 3178). From level 5 up a bought level costs 35 to 41 Esencia per minute of laps it saves (the old ladder cost 93 to 245), near an intermediate player's 30-47 Esencia/min and under an advanced player's 56-62, so the console is a real shortcut and still a sink. Mirrored in `WildboundTuningSchema` defaults and `Balance.LIVE.training`. | Re-check against the new pace. |
| BP1-D7 | A lap that does not level up says "Vuelta N de M para el nivel L." (new `Text.TRAINING.lapProgress`); a level-up lap says the level, the walk and "+5 de Esencia." (`lapLevelEmber`); a lap at the top repeats `maxed`. `lapEmber` stays unused in Text. | The player sees progress instead of a fake income. |
| BP1-D8 | The simulator's "lap Esencia only on a level-up lap" what-if row is removed (it is now as built); its findings 1, 2 and 6 print "never" for the AFK hours instead of dividing by zero. The dated findings narrative is not regenerated in BP1 (BP4). | The model mirrors the live rule. |
| BP1-D5 | A console purchase keeps the laps already run toward the next level (they are not lost). | Never take progress away. |
| BP1-D6 | The simulator profiles keep their ASSUMED `laps_at_start` (4, 17, 17); with the new rule those laps reach level 2 and level 5. | A profile is behaviour, not the rule. |
| BP2-D1 | The carry cap is `Training.CONSTANTS.CARRY_WALK_CAP = 24`, a constant, not a tuning entry (as BP1-D2 did for `LAP_STEP`). | No new tuning surface; the schema, the bridge and `Balance.liveFrom` stay untouched. |
| BP2-D2 | The cap binds every slowed walk (`speed < base`): eggs, a carried creature and a heavy pouch alike. The lower of `WALK_CAP` and the carry cap applies. | One rule; `walkSpeed` cannot tell the kinds of load apart, and the old share already treated them alike. |
| BP2-D3 | `WildboundServer` was not edited: its `applyCarry` comment still says "a carrier keeps its carry share of the trained walk", which stays true (the share is now of at most 24). | The server is in the teammate's lock zone and at the local limit; a comment is not worth a write there. |
| BP3-D1 | Caramelo nests: the first suggestion of finding 4 (one tier down), not "a guardian on 6 of 11 nests". The event-only Legendaria nest keeps Heart. | The handoff names the tiers (Común 4, Rara 10, Épica 16); L1 is off and was not in the list. |
| BP3-D2 | Only the pay moved: a new `Nests.RISK` keeps the island entry's `tier` (noise events, slot rules) at Fog / FogFar / Territory / Heart, and `POOL` keeps its one-line row shape. | A reward change should not quieten a steal; the simulator parses the `POOL` rows by pattern. |
| BP3-D3 | Nightbloom: the weight suggestion of finding 5 (Night fog 15 -> 6, territory 35 -> 15), not a shorter wilt. The other weights are unchanged (the table is normalised, so shares are over 91 and 80). `NIGHT_ONLY_SECONDS` stays 300. | Back to about the old rate with no timer change; GF pins the 300 s wilt. |
| BP3-D4 | `WildboundEconomyConfig.luau` is a generated file; with no Python here, the JSON block in `docs/mechanics/wildbound-economy-p0.md` and the Luau copy were edited by hand in step (three numbers each). | Run `python -I -B tools/export_economy_config_luau.py --write` and its test on a machine with Python to confirm. |
| BP4a-D1 | "Duplicate" means another registered creature of the same species stays. Either copy may go; the last one may not. | It matches the egg rule (`sellDuplicateEggs`) and keeps the species discovered after a save. |
| BP4a-D2 | A release needs only a living player, not the camp or the base (like "Equipar"). | A full collection blocks steals in the field; freeing a place there is the point. The review judged it no income loop: 4 is at most what selling the same egg paid. |
| BP4a-D3 | The button lives in the Bag tab, as a second row under each spare creature, and asks twice: "Liberar", then "Confirmar"; the question expires after 5 s. | A release cannot be undone; the panel has one button per row. |
| BP4a-D4 | No schema step: the entry leaves `registered`, and its `bond` and unbanked bond go with it. | The saved record refuses a bond for an unregistered creature; a shorter list only shrinks the record (RT-17). |
| BP4a-D5 | The action rides the existing `ECONOMY_ACTIONS` table and a branch in `economyAction`: no new top-level local in `WildboundServer` (NH-W13), three small additive edits in the teammate's lock zone. | The file is at Luau's local limit and shared. |
| BP4a-D6 | Fixed in passing: the "Canjear rep." (duplicate eggs) reply read `Text.BAG`, a table that does not exist, so that button never answered. It now reads `Text.HUD`. `NOTICES.NotOwnedPet` reworded ("Esa criatura no está en tu colección.") since release uses it too; `NOTICES.InFarm` is new and also answers an "Equipar" on a farm creature. | Found by the mapping pass; one-token fixes on the same lines of work. |
| BP4b-D1 | User decision 2026-11-15 ("Sí, bajala a 1"): of finding 7's two options (use the bought slot count, or drop the two upgrades), the base now uses the bought count. | The upgrades (90 and 220 Esencia plus materials) become worth buying; a new player incubates one egg at a time. |
| BP4b-D2 | The line keeps a literal first argument, `math.max(1, Incubator.live.SLOTS, ...)`. | The simulator's `check_drift` reads that number by pattern; its mirror is now 1. |
| BP4c-D1 | The two places are camp upgrades (`farmSlot5` 400 Esencia, `farmSlot6` 900 Esencia, Esencia only), bought on the camp board like the incubator upgrades. | They reuse the saved `upgrades` map, the "Upgrade" action and the board: no schema step, no new remote. |
| BP4c-D2 | `farmSlot6` carries `requires = "farmSlot5"`; `State:upgrade` refuses with `NeedsPrerequisite` and the board says "Requiere Quinto lugar de granja". | Otherwise the sixth place alone (900) would skip the 400. Upgrades had no order rule before. |
| BP4c-D3 | Still no farm income. The farm stays at `State.FARM_SLOTS = 4` for free; `FarmRecord.CAP` 12 is untouched. | The no-AFK-income rule; the cap already allows six. |
| BP4c-D4 | `NOTICES.NeedsPrerequisite` reworded to "Primero consigue la mejora o habilidad anterior." | It was worded for skills only. |

## Evidence

### BP1 (2026-11-15, in progress: repo done, Studio BLOCKED)

- Python RED observed: `tools/test_wildbound_economy_sim_v2.py` 8 failures against the old sim (COST_GROWTH 1.2 != 1.1, AFK 37.5 != 0.0, laps time 16 != 24, idle hour paid 2220 != 85, ...). GREEN: 62 tests OK; `check_drift()` = []. Full suite: 1218 tests, only the known `test_lumipol_v2` V1IsKept failure.
- Sim before/after (live model): treadmill to the top 17 laps / 136 s -> 153 laps / 1224 s (20.4 min); AFK on the belt 37.5 Esencia/min -> 0 after the top (85 Esencia per account in all); console ladder 3178 -> 811 Esencia (level 17 price 555 -> 92). 30 min what-if, 5 runs: intermediate forest 59.6 -> 46.5 Esencia/min (its 17 laps now reach level 5, walk 26, not 50); advanced mixed 73.3 -> 62.0, treadmill share 17.4 -> 1.0 per min.
- Luau: new and re-pinned cases written (TR-1 re-pin, TR-8 re-pin, TR-9, TR-10, TR-11; B20 re-pin). Not run: Studio (place 122652861404212) stayed in Play from 18:10 to 18:40, polled about once a minute; nothing was written to Studio.
- Source changes are in the working tree, not committed (Luau RED/GREEN not observed yet).
- Repo fingerprints (LF, trailing newlines stripped; bytes, Adler-32) HEAD -> working: Training 4053/3689825123 -> 4792/1375218450; TuningSchema 41284/1653247914 -> 41284/3354955688; State 54917/1236784352 -> 55710/1188551955; Server 217661/1447361815 -> 218030/2564715851; Text 38373/1300234362 -> 38543/2206283221; Balance 29142/989013169 -> 29230/3954851041; Training_Test 8626/2803364432 -> 12330/3569453963; Balance_Test 21861/2737315898 -> 21970/1724923732.

### BP1 in Studio (2026-11-15, second session, another machine)

- Found already deployed: before any write, the eight Studio scripts (Training, TuningSchema, State, Server, Text, Balance, Training_Test, Balance_Test) matched the repo at `79892bd` byte for byte (the "working" fingerprints above). This session wrote no Source. Who deployed them is not recorded, and the RED step in Studio was not observed by this session.
- Studio suites, fresh loader (trimmed `tools/studio-fresh-runner.luau`, same SPECS), run `d832e188`: Training 11/0, Balance 25/0, Record 30/0, Text 21/0, TuningWiring 8/0. Red, all on the handoff's known list: State 71/14 (EconomyConfig drift, bag 3 vs 12), Tuning 15/1 (DT1 `Eggs.STEAL_HOLD` 0.8 vs 0.5), Hub 22/1 (HB-T3). No leaks, no timeouts.
- Solo Play (PlayLock `BP1`, cleared after; Play stopped; saves in memory mode): WalkSpeed 16 before; mounted the Base1 belt (WalkSpeed 0). The `Treadmill` remote's lap payloads, 8 s apart: lap 1 `level 1, leveled, ember 5`; lap 2 `laps 1 of need 2, ember 0`; lap 3 `level 2, leveled, ember 5`; lap 4 `laps 1 of need 3, ember 0`. Dismounted through the remote: WalkSpeed 20. No script errors in the output.
- Not checked: the notice wording on screen (`lapProgress`, `lapLevelEmber`), the console purchase at the new prices in Play, a rejoin keeping `training.walkLaps`, two players, a phone. Python tests were not run on this machine (no Python installed).

### BP2 (2026-11-15)

- Change: `WildboundTraining.walkSpeed`, slowed branch: `speed * min(base + bonus, WALK_CAP, CARRY_WALK_CAP) / base` (was `min(base + bonus, WALK_CAP)`); new constant `CARRY_WALK_CAP = 24`. Suite: TR-2 re-pinned on purpose (one egg at the top level 34.375 -> 16.5), new TR-12 (cap constant; under the cap unchanged; one egg 16.5; three or more 13.5; a glove bonus neither lifts a carrier past the cap nor is lost under it; an unburdened walk still 50; a `WALK_CAP` tuned to 20 binds first).
- Fingerprint rule: before writing, Studio `WildboundTraining` and `WildboundTraining_Test` equalled the repo (4792/1375218450, 12330/3569453963). Written with exact replacements (`multi_edit`); after: Studio == repo, Training 5216/154448288, Training_Test 13903/525429571.
- RED (test pushed, source unchanged), fresh loader run `feb47590`: Training 10 passed, 2 failed (TR-2 "Expected 16.5, got 34.375"; TR-12 "Expected 24, got nil").
- GREEN, run `925d5b3e`: Training 12/0, Gear 15/0, Balance 25/0, EggCarry 39/0, Carry 13/0, Stamina 16/0, StaminaWiring 9/0, Text 21/0, Record 30/0, TuningWiring 8/0. Red, all on the handoff's known list: State 71/14, Tuning 15/1 (DT1), Hub 22/1 (HB-T3), Economy 21/1 (ECO-20), MechanicsWiring 9/1 (W1). No leaks, no timeouts.
- Solo Play (PlayLock `BP2`, cleared after; Play stopped; memory saves): 15 laps on the Base1 belt took the walk to level 5; WalkSpeed 26 unburdened; `HeistProbe` "steal" (Egg:19): WalkSpeed 16.5 carrying one egg (the old rule gave 17.875); `HeistProbe` "drop": WalkSpeed back to 26. No script errors in the output.
- Not checked: three eggs or a carried creature in Play (suite only), a sprint or a dodge while carrying, a chase by a parent, two players, a phone.
- Review (workflow `wf_a0d6bc6d-d50`, three lenses, each finding verified): no defect in the rule. Open after it:
  - **A carried creature still outwalks the parents.** `Wild.carrySpeed(0, true)` is 14, so a trained creature carrier walks 14/16 of 24 = 21 from walk level 4 (19.25 at level 3; 22.5 with Light Load), above the parents' chase 19. Before BP2 it was 43.75, so the gap is smaller, but "a chase stays a chase" holds for eggs only. The approved number (24) was kept; a lower cap for this case needs the user's call. Closed by BP2b below.
  - The simulator and its tests still pin the uncapped share (`live_carry`, `test_wildbound_economy_sim_v2.py` lines 483, 485, 597, and the "carrier share of at most a 24 walk" what-if, which is now as built). See the next bullet.
  - The overview's two treadmill rows were updated; the `applyCarry` comment was left (BP2-D3).
- Not done on this machine (no Python): `tools/wildbound_economy_sim_v2.py` still models the uncapped share as live and keeps `carry_trained_cap` as a what-if; its tests and `check_drift` were not run. Fold the cap into the sim in BP4.

### BP2b (2026-11-15): no trained carrier past 16.5

- User decision 2026-11-15 ("Sí, bajalo"), closing the open point of the BP2 review: a carried creature walks no faster than an egg carrier.
- Change: new constant `Training.CONSTANTS.CARRY_SPEED_CAP = 16.5` (the one-egg figure, 11/16 of 24); the slowed branch of `walkSpeed` returns `max(speed, min(share of the capped walk, CARRY_SPEED_CAP))`. A carried creature (14) at the top level 21 -> 16.5; with Light Load (15) 22.5 -> 16.5; a 40% pouch (13) 19.5 -> 16.5. One egg 16.5, two 15 and three or more 13.5 are unchanged; an untrained carrier is unchanged; an unburdened walk still reaches 50.
- Suite: new TR-13 (those values, plus every carry speed 9 to 15 at every level 0 to 17 with a +5 glove bonus stays under 19 and never under its untrained speed).
- Fingerprint rule: Studio equalled the repo before the write (5216/154448288, 13903/525429571) and after it (Training 5551/3558086912, Training_Test 15448/3177331844). Exact replacements.
- RED, run `53438184`: Training 12/1 (TR-13 "Expected 16.5, got nil"). GREEN, run `5b8dc654`: Training 13/0, Gear 15/0, Balance 25/0, EggCarry 39/0, Carry 13/0, LumipolWild 49/0, Stamina 16/0, StaminaWiring 9/0.
- Not checked: no Play run for this step (carrying a creature needs a full capture; suite only). No review workflow (a two-line change to a pure rule). The simulator does not model it (BP4).

### BP3 (2026-11-15)

- Change:
  - `WildboundCandyNests`: `POOL` reward tiers Comun Fog -> Safe (4 Esencia), Rara FogFar -> Fog (10), Epica Territory -> FogFar (16); new `RISK` table; `pick` returns `tier`; `islands` uses it.
  - `WildboundEconomyConfig` and the economy doc's JSON: `spawnWeights.fog.Night.nightbloom` 15 -> 6, `spawnWeights.territory.Night.nightbloom` 35 -> 15, `earn.baseRequires.minExpeditionSeconds` 45 -> 25.
- Suites re-pinned on purpose: Economy (ECO-17: 25 s pays, 24.9 s does not), Spawn (fog and territory Night shares; ECO-16's 100,000 draws), CandyNests (CE1 reward and risk tiers), CandyPets (CP-5 tiers Safe / Fog / FogFar, 4 / 10 / 16), State (ECO-19: the short trip is 20 s).
- Fingerprint rule: before writing, the six Studio scripts (the four suites first touched, EconomyConfig, CandyNests) equalled HEAD, and so did State_Test before its edit. Written with exact replacements. After: Studio == repo. EconomyConfig 8938/1612979398, CandyNests 7804/1134762144, Economy_Test 20453/2251548254, Spawn_Test 10201/2417858517, CandyNests_Test 15282/3328652547, CandyPets_Test 12194/3287507693, State_Test 88072/3391150256.
- RED (tests pushed, sources unchanged), run `6842feeb`: CandyNests 10/2, Economy 20/2 (ECO-17 "Expected 25, got 45", plus the known ECO-20), Spawn 10/1.
- First GREEN run `677a3cc7` showed two more pins of the old numbers (Spawn ECO-16, State ECO-19 "30 s is too short"); both re-pinned.
- GREEN, run `2f09ec88`, 25 suites: pass Balance 25, Bat 13, CampView 22, CandyEggArt 14, CandyNests 12, CandyPets 8, EggCarry 39, Funnel 13, GatherField 13, Gear 15, Island 34, NestRefill 5, Persistence 31, PlacePhase 8, Record 30, RouletteService 9, Save 23, SpawnClock 17, Spawn 11, Training 12. Red, all on the handoff's known list: State 71/14, Economy 21/1 (ECO-20), BaseZone 8/1 (BZ7), EggLoop 12/1 (EL12), AnalyticsWiring 11/1 (AN-3). No leaks, no timeouts.
- Solo Play (PlayLock `BP3`, cleared after; Play stopped; memory saves): `HeistProbe` "steal" on CandyC1 (Comun), carried into the own base zone: Esencia 0 -> 8 (Safe egg 4 + first-steal bonus 4; the trip was under 25 s). Then CandyR1 (Rara): 8 -> 22 (Fog egg 10 + trip base 4). Before BP3 these were 10 and 16. Both hatched (Gomibú, Tortidragón). No script errors.
- Not checked in Play: an Épica nest, the Nightbloom rate in the forest, the 25 s boundary itself (suite only), two players, a phone.
- Review (workflow `wf_108110bb-bdd`, three lenses, each finding verified): no defect in the Luau. It read the exporter and judged that it would reproduce the hand-edited config byte for byte. It found leftover pins, now fixed in this commit: two Python tests (`test_extract_base_requires_45s`, renamed `..._25s` with 20 s / 25 s trips; `test_live_caramelo_nests`, now 4 / 10 / 16), the simulator's printed assumption row (25 s), and the old numbers in the economy doc's weight and earning tables and in two overview rows. The Python edits were made **without running them**.
- Not done on this machine (no Python): the exporter and its test (BP3-D4); the Python suite; the simulator rerun. The simulator's dated findings text still suggests the changes BP1 to BP3 already made (regenerate in BP4).

### BP4a "Liberar" (2026-11-15)

- Mapping first (workflow `wf_afd88050-5dc`, three read-only agents: State and Record, server plumbing, client and text).
- Change:
  - `WildboundState`: `State.RELEASE_EMBER = 4`; `State:releaseCreature(key, uid, alive)` with refusals `InvalidPlayer`, `InvalidContext`, `NotOwnedPet`, `IsCompanion`, `InFarm`, `NotDuplicate`. On success it removes the entry from `registered`, clears `bond[uid]` and `expedition.pendingBond[uid]`, adds the Esencia and returns `{ uid, species, ember }`.
  - `WildboundServer`: `ReleaseCreature = true` in `ECONOMY_ACTIONS`; a branch in `economyAction` (State decides; `Heist.creatureToolbar:syncPlayer` drops the tool; `reply` with `Text.HUD.released`); `Text.BAG` -> `Text.HUD` in the duplicate-egg branch.
  - `WildboundCampView`: pure `View.releasable(snapshot)`.
  - `WildboundClient`: the second row and its two-tap handler (`releaseAsk`, `spec.onTap` in `addRow`); `ReleaseCreature` in the client's `ECONOMY_ACTIONS`.
  - `WildboundText`: `HUD.release`, `releaseConfirm`, `releaseRow`, `releaseConfirmRow`, `released`; `NOTICES.IsCompanion`, `InFarm`, `NotDuplicate`; `NotOwnedPet` reworded.
- Suites: new State BP4a-S1 to S3, CampView BP4a, Text BP4a, CreatureToolbar BP4a (server wiring by source text).
- Fingerprint rule: the nine Studio scripts equalled HEAD before any write; exact replacements; after: Studio == repo. State 57106/4263165139, Server 218633/4198778477, CampView 26200/2626978400, Client 48110/1015170953, Text 39200/1428360875, State_Test 91630/4092096713, CampView_Test 23297/3506176978, CreatureToolbar_Test 27415/631083022, Text_Test 25546/2103089438. The server and client sources compile.
- RED (tests pushed, sources unchanged), run `c6a205f8`: CampView 22/1, CreatureToolbar 20/1, Text 21/1, State 71/17 (the three new cases plus the known 14).
- GREEN, runs `7f5268f8` and `a7219270` (after the review fix), 18 suites: CampView 23/0, CreatureToolbar 21/0, Text 22/0, State 74/14 (only the known 14), Record 30/0, Refuge 15/0, Save 23/0, Bat 13/0, CandyPets 8/0, Carry 13/0, HudLayout 24/0, Incubator 7/0, IslandWiring 13/0, RouletteService 9/0, StaminaWiring 9/0, StartWiring 9/0. Known reds: EggLoop EL12, MechanicsWiring W1 (NH-W13's local count still passes).
- Solo Play 1 (PlayLock `BP4a`, cleared after; memory saves): three Lumipol hatched from probe eggs. Through the remote: the companion refused ("Guarda a tu compañero antes de liberarlo."); a spare released, Esencia 72 -> 76, registered 3 -> 2; the same uid again and a made-up uid refused; a second spare released, 76 -> 80; the last Lumipol refused ("Solo puedes liberar criaturas repetidas."). The server Backpack held one creature tool afterwards (the released ones were gone). The Bag tab showed a "Liberar" row (98 x 44 button) under each of three spare creatures.
- Review (workflow `wf_7d36e6bb-fab`, four lenses, each finding verified): no integrity or security defect and no income loop. Fixed from it: a stale "Confirmar" row after 5 s only asked again, and a confirm dropped by `request()`'s 0.5 s guard was lost; now the row's own label decides and the question expires through a timed rebuild. A test pins the client's busy entry. The two docs rows that said nothing releases a duplicate were updated.
- Solo Play 2 (after that fix), a recorder on the button labels while the mouse clicked: "Liberar" -> "Confirmar" on the first click; back to "Liberar" 5.1 s later; "Confirmar" again on a click; a click on it released (three creature rows -> two). No script errors in the output.
- Not checked: a real leave-and-rejoin after a release (memory saves in Studio; the record path is suite only), a phone, two players, releasing a creature whose tool is in the hand.
- Not done (no Python): the simulator still treats the collection limit as a wall (BP4).

### BP4b incubator slots (2026-11-15)

- Change: `Heist.autoIncubate` in `WildboundServer`: `local slots = math.max(8, Incubator.live.SLOTS, ...)` -> `math.max(1, Incubator.live.SLOTS, snapshot and snapshot.incubatorSlots or 1)`, plus its comment. One line in the teammate's lock zone. The simulator mirror `base_incubator_slots` 8 -> 1 (edited, not run).
- Suite: new EggLoop "BP4b" (`Economy.incubatorSlots` is 1 / 2 / 3 with the upgrades; the server line; no `math.max(8`; `nextToIncubate` fills the bought slots only).
- Fingerprint rule: Studio equalled HEAD before the write (EggLoop_Test 14124/1927995124, Server 218633/4198778477) and the repo after it (EggLoop_Test 15545/4264603697, Server 218740/2981586812). The server compiles.
- RED, run `31b2f6f3`: EggLoop 12/2 (the new case, plus the known EL12). GREEN, run `6fdffb15`, 18 suites: EggLoop 13/1 (only EL12), Incubator 7/0, CandyPets 8/0, CandyEggArt 14/0, Balance 25/0, Record 30/0, Save 23/0, Persistence 31/0, Gear 15/0, CampView 23/0, CreatureToolbar 21/0, Text 22/0, RouletteService 9/0. Known reds: BaseZone BZ7, Economy ECO-20, Hub HB-T3, MechanicsWiring W1, State 14.
- Solo Play (PlayLock `BP4b`, cleared after; memory saves): three probe eggs banked, then the player stood in the own base zone. The snapshots showed one egg incubating at a time (banked 1 / incubating 1, then a hatch, then the next egg in), never two; `incubatorSlots` 1. Before this change all three went in at once.
- Not checked: buying `incubatorSlot2` in Play and seeing two eggs incubate (suite only), the Eggs tab's "Incubadora: n/n ranuras" header, two players, a phone. No review workflow (a one-line change).
- Not done (no Python): the Python suite; a test there may pin first-hatch times that assumed eight slots.

### BP4c farm slots for sale (2026-11-15)

- Change:
  - `WildboundEconomyConfig` and the economy doc's JSON (hand-edited in step, as BP3-D4): `upgrades.farmSlot5` and `upgrades.farmSlot6`.
  - `WildboundEconomy`: `Economy.farmSlots(config, upgrades, base)`.
  - `WildboundState`: a local `farmSlots(self, player)`; `placeInFarm` defaults to it; `snapshot.farmSlots` uses it (the hotbar passes that number); `State:upgrade` checks `spec.requires`.
  - `WildboundCampView`: words for the two upgrades; the "Requiere ..." reason.
  - `WildboundText`: `NOTICES.NeedsPrerequisite`.
- Suites: new State BP4c-S1 (prices, order, refusals, the farm filling to 4, 5, 6) and CampView BP4c (the two board rows).
- Fingerprint rule: the seven Studio scripts equalled HEAD before the write; exact replacements; after: Studio == repo. Economy 11012/3505043983, State 57687/2653325141, CampView 26969/3695476606, EconomyConfig 9125/791629780, Text 39233/2605193716, State_Test 94022/3976886250, CampView_Test 24839/1081409781.
- RED, runs `00a9aede` and `17c949b8`: State 74/15 (the new case plus the known 14), CampView 23/1. GREEN, run `65793d5b`, 18 suites: State 75/14 (only the known 14), CampView 24/0, Record 30/0 (RT-17 holds), Save 23/0, Persistence 31/0, Balance 25/0, CreatureToolbar 21/0, Text 22/0, and the rest as in BP4b.
- Solo Play (PlayLock `BP4c`, cleared after; memory saves), at the camp with 1500 Esencia from `GearProbe` "fund": the sixth place first was refused ("Primero consigue la mejora o habilidad anterior."); the fifth cost 400 (1500 -> 1100) and `farmSlots` went 4 -> 5; buying it again was refused ("Ya lo tienes."); the sixth cost 900 (1100 -> 200) and `farmSlots` went to 6. No script errors in the log.
- Review of BP4b and BP4c (workflow `wf_57294e21-9ce`, three lenses, each finding verified):
  - Fixed: on entering the base with two or three slots, the carried egg could fill the second slot while an older stored egg took the first; the banner then said "guardado" and sent "incubadora llena" although it was incubating. `enterBase` now marks it incubating whichever slot it filled (EggLoop BP4b case pins it). Server 218893/2080545631, EggLoop_Test 15929/1775645566; run `e6d79358` green as above.
  - Confirmed sound: the saved-farm grid places 5 and 6 on a second row with no overlap; no other hard-coded 4 for the farm.
  - **Deploy risk, not fixed:** a record saved by this build carries `upgrades.farmSlot5 = false`; a server still on an older build (a rolling update) refuses it ("upgrades has an unknown key") and quarantines the load. Nothing is overwritten, but the player cannot load there. The game is not published, so no old server exists today; before any publish, ship all servers together or make the record tolerant of unknown upgrade keys.
  - **Open, not fixed:** after a hatch the next stored egg goes in only if the owner is alive at that moment; if not, it waits for the next base entry or a manual "Incubar". With one slot that idle time shows more than with eight.
- Not checked in Play: placing a fifth and sixth creature in the farm (suite only), the camp board rows on screen, a rejoin, two players, a phone.
- Not done (no Python): the exporter and its test; the simulator's one-time sink total (1505) does not count the two new upgrades until it is rerun.

## Next step

BP4: rerun the simulator and refresh its findings (needs Python, which this machine lacks). Then the adversarial review of the whole pass (handoff B5).
