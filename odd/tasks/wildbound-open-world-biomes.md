# Feature: open-world biome placement and Edit-mode builders (offline)

Objective: every existing biome layout can be dropped into the open world in Studio Edit mode with one script each, placed around the hub from `Rules.HUB_X, HUB_Z, HUB_RADIUS`. Offline only: no Studio, no uploads.

Constraints: one Studio writer elsewhere (no Studio MCP or computer use here); never invent asset ids or upload; do not edit `WildboundWorldRules.luau`, `WildboundHub*.luau`, the forest builder or `odd/tasks/wildbound-capture-extraction-horror.md`. TDD: strict (global user configuration), runner `python -I -B -m unittest discover -s tools -p "test_*.py"`. Baseline 1062 tests, 1 known failure (`test_lumipol_v2.test_v1_files_are_unchanged`), 28 skipped.

| ID | Task | Route | Status | Evidence |
| --- | --- | --- | --- | --- |
| OWB-1 | Placement: `generate_placement` in `tools/plan_open_world_layout.py`, `assets/maps/open-world/biome-placement-v1.json` | inline (one writer, this agent) | done | `tools/test_plan_open_world_placement.py` RED 17 errors, GREEN 17/0; `layout-v1.json` byte-identical after a full planner run; commit `c2f1a3a` |
| OWB-2 | Builders: `tools/biome_map_builder.py` generates six `tools/build-wildbound-<biome>-map.luau` and `tools/build-wildbound-open-world-roads.luau` | inline | done | `tools/test_biome_map_builder.py` RED (generator absent: import error; then 9 errors, 2 failures with modules unwritten), GREEN 21/0; commit `ce83398` |
| OWB-3 | Doc `docs/maps/wildbound-open-world-biomes.md` and its contract | inline | done | Doc contract RED (file missing), GREEN 24/0 in the builder suite |
| OWB-4 | Measured forest: the planner takes the real forest square (Studio: `WildboundP0.Floor` centred (-18, -3), 400 x 400, so x -218..182, z -203..197; `MEASURED_FOREST`, `--forest X Z SIZE`, `--slot-forest`). Why: the forest road ran its last 30 studs on the real forest floor and the NW and SW roads grazed its corners with zero clearance. The forest road is dropped (the hub's W gate trail already joins (182, 17)); the NW and SW roads turn at x 191 (forest edge + 7 + 2); no square moved | delegated writer (offline) | done | 8 new contracts in `tools/test_plan_open_world_placement.py` RED (2 errors: no `forest` argument), GREEN 25/0; placement and the roads builder regenerated, the six biome builders byte-identical (`--check`); not committed |

Asset route finding: the forest kit is the only uploaded kit (six Model packages, templates in `ServerStorage.WildboundAssets.ForestKit`); the six other kits were never imported, so their builders build primitive fallbacks and pick up `ServerStorage.WildboundAssets.<Kit>` templates if they ever exist.

Pending (not verified): every Studio check in the doc's section 6. Next step: after the forest shift (S1), the Studio writer runs the builders per the doc's section 4; regenerate first if `Rules.HUB_*` changed (hub v2 plans radius 100).
