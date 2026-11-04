# Horror map blockout

## Objective and authorization
Build a large static low-poly horror environment in the user-confirmed Place1 Studio instance `41ba204c-3c94-4ed1-bc07-40bd4224f189` (PlaceId=0, GameId=0). No gameplay mechanics, UI, purchases, publication, imported assets, or shared-library changes.

## Problem and scope
The place contains only the default 2048-stud baseplate, spawn, camera, and terrain. Create a 1600-stud environment: neutral spawn clearing, dark forest, rocky ridge/ruins, marsh, connected routes and landmarks. Preserve existing objects. Video advice remains a hypothesis, not an official rule.

## Work unit
- [x] MAP-1: Build and verify the complete static environment, retaining reproducible editor generator, validator, baseline/rollback notes and work-unit commit.
  - Route: delegated direct; preparation trigger and 2+ non-trivial source/validation files.
  - Acceptance: one owned root, anchored primitives, no executable scripts installed, distinct biomes, spawn/path clearance, bounded counts, visual captures and play smoke check.
  - Checks: Studio structural validator, route/spawn raycasts, visual inspection, Play smoke test/output; mobile device performance remains pending.
  - TDD: unspecified; no existing runner/configuration. This unit authors static scenery, not runtime behavior; ordinary Studio checks apply, no RED/GREEN claim. Revisit before implementing mechanics.
  - Rollback: remove only owned map folder/effects; restore recorded Lighting properties. Do not remove original objects.

## Delivery and review
- Branch: codex/horror-map-blockout (unborn repository).
- Forecast: approximately 390 authored lines including supporting docs; strategy ask-on-risk; no PR/push/merge authorized.
- RDD: enabled, global (verified escalated status); assess committed work unit and follow native consent transitions. Initial boundary is empty tree because repository has no commits.
- Work-unit commit: 7cba05fefc655af7fb4da6d5f16d6e5b81d3854c. Initial snapshot 381 lines (372 authored + 9 generated baseline lines). Native assessment: medium, under_budget, review_due=false against empty tree 4b825dc642cb6eb9a060e54bf8d69288fbee4904; pending slice, no review approval claimed. Staged/root diff whitespace checks passed after LF normalization.

## Progress
Exploration complete. Confirmed target stable; shared INDEX and pertinent notes read. CodeGraph initialized (empty index); .codegraph must be ignored. Studio StreamingEnabled=true. Original Lighting effects present, record before mutation. Generated 1684 anchored parts; final Edit readback confirms zero LuaSourceContainers. Validator passed twice (including after dusk tuning). Play smoke: health100, spawn near origin, navigation to (0,3,-100) succeeded, final z=-99.25, health100; console empty. Lighting final ClockTime17.6/Brightness1.7. Captures inspected for clearing, forest, marsh and dusk trail. Blue-gray palette and planar ground joins remain blockout limitations, not final art. Real mobile performance not tested. GUI .rbxl backup failed due app approval timeout; evidence/studio-baseline.json is only a property snapshot, not a full place backup. No publishing performed. Initial staged diff check flagged CRLF as trailing whitespace; enforce LF in .gitattributes and renormalize before final checks. Generator MCP call reported target unreachable but immediate readback and validator proved completion; never rerun blindly.

## Next step
Save a local .rbxl in Studio; no cloud publish. Next optional environment pass: improve palette, terrain relief and ground joins, then measure on real mobile hardware. Mechanics remain outside this task.
