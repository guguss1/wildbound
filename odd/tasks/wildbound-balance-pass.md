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
- [ ] BP3 Remaining findings (collection limit, base bonus timing, Caramelo tiers, Nightbloom, sinks, incubation slots) as the batch assigns them.
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
  - **A carried creature still outwalks the parents.** `Wild.carrySpeed(0, true)` is 14, so a trained creature carrier walks 14/16 of 24 = 21 from walk level 4 (19.25 at level 3; 22.5 with Light Load), above the parents' chase 19. Before BP2 it was 43.75, so the gap is smaller, but "a chase stays a chase" holds for eggs only. The approved number (24) was kept; a lower cap for this case needs the user's call.
  - The simulator and its tests still pin the uncapped share (`live_carry`, `test_wildbound_economy_sim_v2.py` lines 483, 485, 597, and the "carrier share of at most a 24 walk" what-if, which is now as built). See the next bullet.
  - The overview's two treadmill rows were updated; the `applyCarry` comment was left (BP2-D3).
- Not done on this machine (no Python): `tools/wildbound_economy_sim_v2.py` still models the uncapped share as live and keeps `carry_trained_cap` as a what-if; its tests and `check_drift` were not run. Fold the cap into the sim in BP4.

## Next step

BP3: the remaining findings (Caramelo nest tiers one lower, Nightbloom scarce again, trip-bonus minimum 45 s -> 25 s).
