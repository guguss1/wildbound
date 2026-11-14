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
- [ ] T05b
- [ ] T09a
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

Next step: optionally the full Studio run with `tools/studio-fresh-runner.luau` (extend its SPECS for suites with other signatures), then the T01 commit, with the overview's unrelated LG/push-state fixes in a separate `docs(wildbound)` commit. The manifest rows already exist (`tools/deploy_manifest.py:301,330`).
