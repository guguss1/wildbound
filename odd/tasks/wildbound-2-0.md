# Wildbound 2.0

Objective: stage the 2.0 numbers and the plan without touching the teammate's live systems.

Scope: T01 writes `src/wildbound/WildboundBalance.luau` (Studio `ReplicatedStorage.WildboundBalance`), `tests/WildboundBalance_Test.luau` (Studio `ServerStorage.WildboundBalance_Test`), `docs/design/wildbound-2-0-schema-plan.md`, this file, `tools/studio-fresh-runner.luau`, `tools/test_wildbound_balance_unwired.py`, and small status fixes in `docs/wildbound-game-overview.md`. Later tasks are listed below and are not authorized yet.

Constraints:
- Lock zone (a teammate edits it live in the same Team Create place; never write it, in the repo or in Studio): every `SistemaSonriente` folder (ServerScriptService, ReplicatedStorage, StarterPlayerScripts, Workspace) and its `LEEME` script; the scripts `WildboundServer`, `WildboundState`, `WildboundEggCarry`, `WildboundBatKnock`, `WildboundWorldClient` (`WildboundWorld.client.luau`); the tests `WildboundEggCarry_Test`, `WildboundBat_Test`, `WildboundMechanicsWiring_Test`. Never edit Workspace.
- Team Create: one writer per script set; reverify the Studio instance and place every session.
- `monetization = "none"`. No publish. Damage stays off outside the private test place.

TDD: Strict, source "user CLAUDE.md". Runner: the Studio suites through MCP `execute_luau` with the fresh-clone runner (`require(test:Clone())(require(module:Clone()), module.Source)`; the multi-suite version is `tools/studio-fresh-runner.luau`), plus `python -I -B -m unittest discover -s tools -p "test_*.py"`.

Delivery: ask-on-risk; forecast about 400 authored lines per slice.

## Tasks

Route: T01 delegated, one writer.

Free now:

| ID | Scope | Decision to ask first |
| --- | --- | --- |
| T01 | Balance config, its test and the two docs | — |
| T08a | Portal pure rules module (calm, channel, cooldown) | — |
| T05b | Pure sell and farm value rules plus the Record2 step | Separate step or merged |
| T09a | Roulette per-prize odds | Hub chest vs base chest, and the pity rule |

After teammate stage 1:

| ID | Scope | Decision to ask first |
| --- | --- | --- |
| T02 | Day cycle 240/60/300/120. Largely live already: the synced WildboundWorldRules runs Day 300 / Dusk 60 / Night 300 / Dawn 60, so night is already 300 s; open: the 240/60/300/120 split | Threat pace |
| T03 | Hotbar | Lumipol pulse and bond |
| T04 | Farm | Income model |
| T05a | Sell wiring | Confirm before selling a Legendaria; base theft off |
| T06 | Treadmill and speeds | Silueta and parent speeds |
| T07 | Bat | Bat on players without an egg, and on the Sonriente guardian |
| T08b | Portal placement | Portal locations |
| T09b | Roulette wiring | — |
| T10 | Incubation tiers and second cradle | — |

Checklist:
- [ ] T01 Balance config, test and the two docs. Review corrections applied (findings 1-10, 12, 13; 11 partly). Commit pending.
  - [x] T01.1 Strict RED observed in Studio against the previous module (11 passed / 13 failed, 2026-11-14).
  - [x] T01.2 GREEN in Studio on fresh clones (24 passed / 0 failed); deploy hashes equal the repo.
  - [x] T01.3 Python suite run (1225 run, 5 known failures, none from T01).
  - [ ] T01.4 Full Studio suite through `tools/studio-fresh-runner.luau` (not run; see Evidence).
  - [ ] T01.5 Commit (the overview's LG/push-state fixes go in their own `docs(wildbound)` commit).
- [ ] T08a
- [ ] T05b Economy simulator for the 2.0 numbers (simulation scope; the merged-vs-separate title decision is still open, see T05b evidence). Commit pending.
  - [x] T05b.1 Strict RED: the new test file against a stub module (24 run, 24 errors, every one `NotImplementedError`, 2026-11-14).
  - [x] T05b.2 GREEN: `tools/test_wildbound_economy_sim_v2.py` 24 passed / 0 failed.
  - [x] T05b.3 Python suite run (1249 run, 5 known failures, 28 skipped; none from T05b).
  - [x] T05b.4 Report generated: `docs/balance/wildbound-2-0-economy-sim.md` (seed 7, 200 runs per cell).
  - [x] T05b.6 Review correction (6 findings, one scoped pass): RED 39 run, 3 failures, 13 errors; GREEN 39 passed / 0 failed; report regenerated with both farm modes, byte-identical on rerun (2026-11-14).
  - [ ] T05b.5 Commit.
- [ ] T09a Roulette prize table (unwired, pure). Commit pending; pity ON/OFF and the hub/base choice are open for the user.
  - [x] T09a.1 Strict RED: Python 18 run / 18 errors (all `NotImplementedError`, stub module); manifest test 25 run / 1 failure (new rows); Studio 0 passed / 15 failed on a `return {}` stub (2026-11-14).
  - [x] T09a.2 GREEN: Python 18 passed / 0 failed; manifest 25 / 0; Studio 15 passed / 0 failed through the fresh-clone runner (filtered).
  - [x] T09a.3 Report generated: `docs/balance/wildbound-2-0-roulette.md` (10000 seeded paid spins, seed 7), byte-identical on rerun.
  - [ ] T09a.4 `tools/studio-fresh-runner.luau` SPECS entry for `WildboundRoulette_Test` (owned by another track; see T09a evidence).
  - [ ] T09a.5 Commit.
- [ ] T02, T03, T04, T05a, T06, T07, T08b, T09b, T10 (blocked on teammate stage 1)

Open decision: what a player loses on death or defeat. Today the carried eggs are lost and Esencia is not (`lostOnDefeat = false`).

Conflicts with round-2 decisions:
- A 2.0 walk of 21 breaks Q9 (walk 16, La Silueta night hunt 17). T06 must choose. `Balance.conflicts()` flags it.
- Live values that differ from the pack are recorded in `Balance.LIVE` (from the commit 34eab83 sync) and reported by `Balance.conflicts()` with a `live:` prefix: the day cycle 300/60/300/60 vs 240/60/300/120 (Day and Dawn differ); the WALK_CAP tuning range 16..16.5 would clamp treadmill walks 17-21; Training has MAX_LEVEL 4 at WALK_STEP 0.25 vs 5 Balance levels; the bat has no live `parentStun` (the other bat values match BatKnock, and the immunity range now matches its cap of 15); the incubator has one HATCH_SECONDS 15 and 1 slot. `Balance.liveFrom(modules)` rebuilds LIVE from the live modules, and test B23 fails if the copy drifts. TreadmillService (LAP_SECONDS 8) has no level or cap constants of its own; it calls the server's `onLap`.
- The 2.0 roulette location vs the round-2 base-chest roulette. T09a must choose.

Assumptions to confirm: the T03, T05b, T08a and T10 titles; the per-rarity minimum incubation seconds (25 / 45 / 90 / 180) are a proposal, not from the pack.

Notes for wiring:
- `Balance.incubationSeconds(rarity, previousHatches, upgradeLevel, booster, config)` takes the 0-based saved `hatchCount` and returns nil for anything that is not a whole number of at least 0. The rarity minimum only binds under an incubation booster (`0 < booster <= 1`), because rule 6 keeps each minimum at or below the fully upgraded time.
- Level III of the incubator factors is tunable inside 0.5..1; only the test pins the pack's 0.70.

## Checks

- Studio: RED against the previous module, GREEN on fresh clones, then every deployed `ServerStorage.Wildbound*_Test` through `tools/studio-fresh-runner.luau`. Its totals are not comparable to the old 70 suites / 1454 passed baseline (a different runner, and 87-88 suites now). Lock-zone suites are run, never edited.
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"`; known failure `test_lumipol_v2.test_v1_files_are_unchanged`.
- Deploy check: Adler-32 and length (CRLF normalized) of the two new Studio sources equal the repo files.

## Evidence

- First pass (before the review): Balance GREEN 17/0 in Studio. A full run with a rebuilt runner found 88 suites and 62 failures in 23 suites, some in lock-zone suites. That run is not comparable to the baseline, the 62 failures are not attributed (probably the teammate's live work moving ahead of the suites), and it is not a pass. Its runner was not saved; `tools/studio-fresh-runner.luau` replaces it.
- Sync: commit 34eab83 pulled 97 live Studio scripts into the repo, so the repo now matches the live sources (WorldRules 300/60/300/60, TreadmillService, Training, TuningSchema, BatKnock).
- Studio target (2026-11-14): one instance, place 122652861404212, Edit datamodel, PlaceVersion 416. Both T01 instances were missing at session start (87 tests in ServerStorage, no `WildboundBalance` anywhere); they were recreated as ours.
- RED (2026-11-14): the previous module recreated from the repo (18482 chars, Adler-32 1545246131) and the new test deployed (18816, 2407165975): 11 passed / 13 failed. First failures: B5 `specialEgg dropped, esencia 37: expected validation to fail`; B7 `level III at 0.75: expected validation to pass: ... the last factor must be 0.70`; B8 `first hatch ignores rarity and upgrade: expected 10, got 105`; B9 `attempt to index number with 'incubation'`; B10 `start 4.5: expected validation to fail`; then B12 and B17-B23.
- GREEN (2026-11-14): the new module deployed (26698 chars, Adler-32 3528463710; the test unchanged at 18816 / 2407165975; both equal the repo files with CRLF normalized): 24 passed / 0 failed on fresh clones, including B23 (LIVE equals `liveFrom` of the deployed live modules).
- Runner smoke run: `tools/studio-fresh-runner.luau` filtered to Balance and WorldRules: 2 suites, 63 passed, 5 failed (all in WildboundWorldRules_Test, first `Expected Day, got Dusk`: the repo test still expects the old 360 s day while the live module runs 300); the temp folder was removed. Full suite not run.
- Python (2026-11-14): `python -I -B -m unittest discover -s tools -p "test_*.py"`: 1225 run, 5 failures, 28 skipped. Known: `test_lumipol_v2.test_v1_files_are_unchanged`. The other 4 come from the live Studio sources synced at 34eab83: `test_export_economy_config_luau` x3 (the synced EconomyConfig has the 300/60/300/60 cycle; the document still says 360/72/216/72) and `test_wildbound_audio_catalog.test_d9_no_other_script_names_an_audio_id` (WildboundTreadmill.client.luau names audio ids outside the catalog). The new `test_wildbound_balance_unwired` passes (a guard, so it has no RED).
- Commits: none yet.

## T05b evidence (economy simulator)

- Scope note: the table row above titles T05b "Pure sell and farm value rules plus the Record2 step" with the open decision "Separate step or merged". This pass implements the simulation scope the user asked for ("seguí con la T05b"). Whether it stays T05b (merged) or becomes its own ID is still for the user to decide. The roulette is modelled by category weights only; hub vs base chest, the pity rule and per-prize odds stay in T09a.
- Route: delegated direct, one writer. Python only; nothing in Studio.
- Files: `tools/wildbound_economy_sim_v2.py` (new, stdlib, seeded `random.Random`, no wall clock), `tools/test_wildbound_economy_sim_v2.py` (new, 39 cases after the review correction), `docs/balance/wildbound-2-0-economy-sim.md` (generated report). `simulate_economy.py` and `simulate_hub_economy.py` are unchanged.
- Inputs: the live `WildboundEconomyConfig.luau` (creature and egg Esencia, firstStealBonus 4, extractBaseEmber 4 at 45 s or more), the proposed `WildboundBalance.luau` CONSTANTS and LIVE (a new comment-stripping parser that accepts `[5] = 200` keys), plus regex reads of Training, Incubator, SpawnClock, WaveClock, WorldRules and EggCarry. Mirrors (egg carry speeds 16/11/10/9, island tier distances 45/80/120, Beast Director tick 20 / perRoll 0.20 / cooldown 15, EGGS_PER_NEST 3, EGG_SHARE 0.4 since 2026-11-14) are re-read by `check_drift`; the current drift is none. Any failure to read raises `NumbersUnavailable`. Farm slots 7 and 8 are reported as "TBD".
- RED (2026-11-14): test file against a stub that raises `NotImplementedError`: 24 run, 24 errors, each one `NotImplementedError`.
- GREEN (2026-11-14): 24 passed / 0 failed (0.7 s).
- Python suite (2026-11-14): `python -I -B -m unittest discover -s tools -p "test_*.py"`: 1249 run, 5 failures, 28 skipped. The 5 are the known ones: `test_export_economy_config_luau` x3, `test_lumipol_v2.test_v1_files_are_unchanged`, `test_wildbound_audio_catalog.test_d9_no_other_script_names_an_audio_id`.
- Report: `python -I -B tools/wildbound_economy_sim_v2.py --profile all --minutes 10,30,60 --seed 7 --runs 200 --source live --balance proposed --farm-mode both --md`. The CLI now writes LF bytes, so a rerun is byte-identical with no CRLF normalization (sha256 `313989ea...5a59`, checked twice).
- Review correction (2026-11-14, one scoped pass over an adversarial review's 6 findings):
  1. HIGH, ladder flag: `ladder_indicator` now flags mean growth above `LADDER_GROWTH_THRESHOLD` 2.5 (ASSUMED), the next step above 3 sessions of income, or the top level above `LADDER_TOP_SESSIONS` 20 sessions (ASSUMED). `ladder_runs` evaluates each run at its own owned level and Esencia/h (treadmill, incubator, farm slots; Training is not simulated, so level 0). A crafted 100x ladder flags, both in the pure helper and end to end through `run_all`.
  2. MEDIUM, lockout: the old indicator is renamed `stall_flag` (slow progress). A new `hard_lockout_flag` is checked once at session end: stalled over 5 min and either mean income under 1 Esencia/h (ASSUMED) or the Esencia on hand plus one more whole session at the session's mean income cannot pay the cheapest remaining upgrade. A first version used the rolling 10 min window and fired in 8-11% of beginner runs; a seed probe showed those were streaks of lost trips that recovered, so it was moved to the session mean. "Sell mandatory" now keys off the hard lockout.
  3. MEDIUM, fresh account: `farm_mode` is an ASSUMED field. `fresh` = every session is a new account (empty farm, 10 s first egg, first-steal bonus, free spin, farm worthless after the session). New `carry` (`--farm-mode carry|both`) = a pre-filled `carry_farm` per profile (ASSUMED), the bonuses spent, the first two egg timers used, and a farmed creature valued 60 min past the session end (ASSUMED). Upgrade levels still start at 0 in both modes.
  4. LOW: the roulette Esencia share comes from `roulette.weights` (35.0% today); no literal 0.35 remains.
  5. LOW, tests: the disclaimer is pinned to line index 2; a crafted unaffordable config sets `stall` and `hard_lockout` through `simulate_session`; a crafted ladder sets the ladder flag through `run_all`; an invariant test covers 3 profiles x 3 lengths x 2 farm modes x 2 roulette policies x 5 seeds (Esencia >= 0, every level at or below its maximum, farm within its slots, no in-play purchase at the session end); a `place_hatch` test pins sell versus farm versus storage.
  6. LOW: the first and second egg timers count hatches already finished (Balance `previousHatches`), not eggs started. Session-end purchases go to `end_purchases` and leave the time-to-upgrade table. Spend mode deducts spin spend (`esencia_total` is net). Mirror line numbers are removed. The column is now "Hatches per session".
- RED (correction): 39 run, 3 failures, 13 errors (the new and changed cases; the other 23 passed).
- GREEN (correction): 39 passed / 0 failed (about 1.0 s).
- Python suite (correction): 1270 run, 6 failures, 28 skipped. The 5 known ones plus `test_studio_fresh_runner.test_every_suite_has_a_spec_or_a_skip`, which belongs to another agent's in-progress `tools/studio-fresh-runner.luau` work, not to T05b.
- Key findings (a model with ASSUMED profiles, PvP and bat rates, farm modes and placeholder roulette values; not measured play):
  1. Esencia/h means at 10 / 30 / 60 min. Fresh: beginner 517 / 613 / 756, intermediate 1461 / 2173 / 3034, advanced 4679 / 9071 / 11654. Carry: beginner 698 / 819 / 954, intermediate 2245 / 2993 / 3666, advanced 6008 / 9709 / 12051.
  2. Sell versus farm depends on the fresh-account assumption. Advanced sales at 60 min are 55% of income fresh (6443/h) and 44% carry (5397/h). Runs that sold a Legendaria: fresh 26% / 91% / 100% at 10 / 30 / 60 min, carry 0% / 2% / 41% (carry sales are farm overflow, not the ROI rule). "Selling always beats farming at 10 or 30 min" holds only in the fresh mode; with a persistent farm, keeping a Legendaria wins once it pays for 43.3 min (650 / 15) across sessions.
  3. Farm without exploring pays as much as exploring or more once the farm is filled. Idle farm vs expedition Esencia/h at 60 min: fresh 1.54 / 1.58 / 1.03, carry 1.90 / 1.83 / 1.73 (beginner / intermediate / advanced). Four Legendaria collected every 15 min pay 3600 Esencia/h. This conflicts with the live `antiAfk.timeBasedGrants = 0`; T04 must decide.
  4. The beginner stalls in most sessions. Stall rate for 10 / 30 / 60 min runs: fresh 21% / 88% / 99%, carry 17% / 74% / 98%. The longest stall averages 259 / 547 / 782 s fresh. Hard lockout: 2% of beginner fresh 10 min runs, 0% everywhere else. The intermediate stalls in 4% (fresh) and 1% (carry) of runs, the advanced in none. So the beginner is stuck for minutes in almost every session longer than 10 min. It is not a permanent dead end in this model.
  5. Ladders: the incubator ladder 100/300/750 has a mean growth of 2.74. That is above the ASSUMED 2.5, so it is flagged in every run. The treadmill (2.34) and the farm slots (2.50, exactly at the threshold) are not growth-flagged. But the treadmill top level needs 27.1 sessions of 10 min for a fresh beginner, which flags 51% of those runs (10% in carry). The live Training is 1.6. Roulette is unchanged: EV 34.1 per 45 spin, 21.0 of it Esencia, so there is no money loop until the average Esencia prize reaches 128.6 (91.1 counting the placeholder items).
  6. New player (fresh): the first banked egg comes at about 5.2 min mean (76% of 10 min runs), and the first hatch at 5.3 min (74%).
- Caveats: losses are rolled once per trip, not from Director ticks. The egg price uses the SpawnClock REWARD map (ASSUMED). Balance is `wired=false`. The proposed treadmill 17-21 conflicts with Q9 and the live WALK_CAP 16. There is no day/night or gathering. Upgrade policies are heuristics. Carry mode carries no upgrade levels. All the ladder and lockout thresholds are ASSUMED. The module is about 1360 lines, one file by spec, which is above the 400-line planning heuristic.
- Commits: none.

Next step: optionally the full Studio run with `tools/studio-fresh-runner.luau` (extend its SPECS for suites with other signatures), then the T01 commit, with the overview's unrelated LG/push-state fixes in a separate `docs(wildbound)` commit. The manifest rows already exist (`tools/deploy_manifest.py:301,330`).

## T09a evidence (roulette prize table)

- Route: delegated direct, one writer. Files: `src/wildbound/WildboundRoulette.luau` (Studio `ReplicatedStorage.WildboundRoulette`, new), `tests/WildboundRoulette_Test.luau` (Studio `ServerStorage.WildboundRoulette_Test`, new, 15 cases), `tools/wildbound_roulette_sim.py` and `tools/test_wildbound_roulette_sim.py` (new, 18 cases; reuse the T05b Luau literal parser), `docs/balance/wildbound-2-0-roulette.md` (generated), two rows each in `tools/deploy_manifest.py` and `tools/test_deploy_manifest.py`.
- Table: 21 prizes in basis points; each category sums to its Balance `roulette.weights` x 100 (checked in Luau against the deployed Balance and in Python against the file). By rarity: Comun 69%, Rara 22%, Epica 7.5%, Legendaria 1.5%. 45 Esencia per paid spin, one free spin (neither counts nor resets the pity). Every prize names `whenFull`: Esencia `none`, consumables `convert` (smoke 20, trap 30, portal 60 Esencia), everything else `pending`. `locations = { "hub", "base" }` (both allowed; T09b chooses and wires).
- EV per paid spin (cash = every resale path; value = ASSUMED equivalent): pity OFF Esencia 10.05, cash 19.215, value 36.96; pity ON Rara+ (default) 10.153 / 19.492 / 37.414, pity spins 1.127%; pity Epica+ 11.694 / 24.959 / 44.686, pity spins 6.308% (fails the ASSUMED 50% cash cap, so validate() rejects it with today's caps). No money loop with the default: cash 19.49 < 22.5 cap, Esencia 10.15 < 30.
- Seeded run (10000 paid spins, seed 7): chi-square 17.98 (OFF) / 18.64 (ON) / 17.44 (Epica+) against 45.3 critical (df 20, p 0.001); longest drought without Rara+ 19 OFF, 9 ON.
- Conflicts and gaps for the user: the earlier base-chest design (hub-expansion section 6) ruled out Esencia prizes, the 2.0 weights give 35%; glove recycle values 3/6/12/25 are design only; the saved roulette record needs `pityCount` and `paidSpins`.
- Studio (2026-11-14): one instance, place 122652861404212, PlaceVersion 416, Edit; both instances absent before, created as ours. Waited while another agent's Play (`WildboundPlayLock = patio-merge`) ran; no Play started. RED used a temporary `return {}` stub, replaced after its exact text was confirmed. Read back: module 19762 chars / Adler-32 3161410522, test 17717 / 2491854683, both equal the repo (CRLF normalized, trailing newlines trimmed). The runner was pasted with FILTER `^WildboundRoulette_Test$` and one added SPECS line `{ "mod:WildboundRoulette", "mod:WildboundBalance" }` (comments dropped, engine unchanged) through a temporary `ServerStorage.T09aRunnerTmp`, destroyed afterwards; no runner folder or lock left.
- Python suite (2026-11-14, before the comment fix below): 1298 run, 6 failures, 28 skipped. The known ones plus `test_studio_fresh_runner.test_every_suite_has_a_spec_or_a_skip` (needs `SPECS["WildboundRoulette_Test"] = { "mod:WildboundRoulette", "mod:WildboundBalance" }` in the runner, not owned here) and `test_wildbound_balance_unwired` (fixed: the module comments no longer name the Balance module).
- Python suite after the fix: 1298 run, 5 failures, 28 skipped: `test_export_economy_config_luau` x3, `test_lumipol_v2.test_v1_files_are_unchanged`, and the runner SPECS check above. `test_wildbound_audio_catalog` d9 now passes (another track).
- Commits: none.

Next step (T09a): the user picks pity ON (Rara+), OFF, or Epica+ (needs a lower cap or resale), the location, and whether Esencia prizes stay; the runner owner adds the SPECS line; then commit.
