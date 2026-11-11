# Wildbound new mechanics (offline pure modules)

Objective: prepare the user decisions Q2b (Arrullo), Q3b (Esquiva perfecta), Q4/Q4b (bat knockback), Q10 (luck totem persistence) and Q11 (dusk) from `docs/design/wildbound-combined-plan.md` section 6 as new pure Luau modules with suites, so a later Studio writer only wires them in.

Scope: new files only, plus the deploy manifest and its Python test. No Studio, no edits to the files another writer holds (EggCarry, Server, Island, Training, TuningSchema, Text, HudView, Fear, Gear, WorldRules, Hub*, Bases, HubStations and their tests).

Constraints: pure modules (no services, clock and rolls passed in), server simulates, client sends intents only. English code and docs, neutral Spanish player strings. Python suite stays at its baseline.

TDD: mode on (session config, Strict TDD). Runner: the Studio suites (`require(test)(require(module), module.Source)`). No Luau runtime offline (`luau`, `lune`, `luau-analyze` not in PATH; checked 2026-11-10), so tests are written first and RED/GREEN is pending Studio.

## Tasks

Route for every task: direct inline (one new module and its suite; mechanical manifest rows).

- [x] T1 Arrullo minigame: `src/wildbound/WildboundArrullo.luau`, `tests/WildboundArrullo_Test.luau`
- [x] T2 Esquiva perfecta: `src/wildbound/WildboundDodge.luau`, `tests/WildboundDodge_Test.luau`
- [x] T3 Bat knockback: `src/wildbound/WildboundBatKnock.luau`, `tests/WildboundBatKnock_Test.luau`
- [x] T4 Luck totem record step: `src/wildbound/WildboundTotemRecord.luau`, `tests/WildboundTotemRecord_Test.luau`
- [x] T5 Dusk: `src/wildbound/WildboundDusk.luau`, `tests/WildboundDusk_Test.luau`
- [x] T6 Manifest rows and `docs/mechanics/wildbound-new-mechanics.md`

## Checks

- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"` (baseline 1150 run, one known failure `test_lumipol_v2.test_v1_files_are_unchanged`).
- Luau suites: pending Studio (no offline runtime).

## Evidence

- Commits: T1 `ffd43bb`, T2 `9f35d43`, T3 `af3d28b`, T4 `d63d866`, T5 `9f114a2`, T6 the commit that adds this line.
- Python after T6: 1153 run, 1 failure (`test_lumipol_v2.test_v1_files_are_unchanged`, the known one), the same as before T1 (the brief's 1150 grew by 3 tests from parallel work).
- Luau suites: not run (no runtime). RED/GREEN pending Studio.

Next step: the Studio writer follows the wiring list in `docs/mechanics/wildbound-new-mechanics.md`.
