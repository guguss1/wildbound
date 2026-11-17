# Caramelo CH review (uncommitted diffs, 2026-11-16)

Scope: working-tree diffs of `wb-first-playable` (A "Caramelo harder", B "Trees") and `wb-big4` (`WildboundBig4Annex`,
`WildboundBig4Map_Test`). `WildboundCandyFlyers*` / `WildboundCandyDuquesa*` ignored. Read-only review: nothing was
run (Luau only runs in Studio); test outcomes below are hand-traced.

## BLOCKER

### B1. Four candy critters lost `hitHeight` and `disengage` (a comment swallowed them)
`src/wildbound/WildboundBeastConfig.luau:406` (Mochimiau), `:448` (Flanin), `:471` (Mielita), `:495` (GatoRepartidor).
The CH5 comment was inserted in the middle of the line, so `hitHeight = 8, disengage = 0.9,` is now comment text:

```
cooldown = SUMMONED_REST, damage = 12, keepsEgg = true, grounded = true, -- CH5: damage 8 -> 12 hitHeight = 8, disengage = 0.9,
```

Effects:
- `src/wildbound/WildboundBeastCandyCritter.luau:186` `math.abs(target.y - p.y) <= C.hitHeight` compares a number with
  nil: a Luau error as soon as a target stands in a patch (Mochimiau's puddle, Flanin's and Mielita's trails, Mielita's
  swarm puffs). `stepEncounter` is pcall'd, so the encounter ends as `Error` (counts.errors) every time.
- `Attack.inside(shape, target, floor, C.hitHeight)` (`WildboundBeastCandyCritter.luau:210`, `:294`) treats a nil height
  as "no height check": the four critters' leaps, bursts and lobs hit a player at any height (on a ledge, mid-jump).
- `tests/WildboundBeastCandyCritter_Test.luau:162-163` fail (`hitHeight`, `disengage` must be numbers): a correct red.

Fix (each of the four lines): move the comment to the end, e.g.
`cooldown = SUMMONED_REST, damage = 12, keepsEgg = true, grounded = true, -- CH5: damage 8 -> 12 hitHeight = 8, disengage = 0.9,`
-> `cooldown = SUMMONED_REST, damage = 12, keepsEgg = true, grounded = true, hitHeight = 8, disengage = 0.9, -- CH5: damage 8 -> 12`
(Flanin `23 ... -- CH5: damage 16 -> 23`, Mielita `14, ... grounded = false, hitHeight = 8, disengage = 0.9, -- CH5: damage 10 -> 14`,
Gato `13 ... -- CH5: damage 9 -> 13`). Canelin (`:428`) was done correctly.

## MAJOR

### M1. Server start can hang forever: `syncNests` now adds missing nests through an unbounded `WaitForChild`
`tools/WildboundCandyBuilder.luau:47-48` (`Builder.addNest`). `WildboundServer.server.luau:154` calls
`CandyNests.applyFlags -> pcall(Builder.syncNests, root, Layout)` with no kit/library, synchronously during
WildboundServer's start. On the live map the 8 new nests are missing, so `addNest` runs
`ServerStorage:WaitForChild("WildboundCandyKit")` / `WaitForChild("WildboundAssets"):WaitForChild("CandyKit")`. If either
is absent in a place (they are tools-side instances, not deployed `src`), the yield never ends; `pcall` does not stop a
yield, so the whole server script stalls before `WildboundRuntime` exists (no nests, no economy, no anything).
Fix (keep the pcall'd skip semantics):
```
local Kit = kit or require(game:GetService("ServerStorage"):WaitForChild("WildboundCandyKit"))
local prefabs = library or game:GetService("ServerStorage"):WaitForChild("WildboundAssets"):WaitForChild(Kit.LIBRARY_NAME)
```
->
```
local SS = game:GetService("ServerStorage")
local Kit = kit or require(assert(SS:FindFirstChild("WildboundCandyKit"), "no ServerStorage.WildboundCandyKit"))
local assets = SS:FindFirstChild("WildboundAssets")
local prefabs = library or assert(assets and assets:FindFirstChild(Kit.LIBRARY_NAME), "no ServerStorage.WildboundAssets.CandyKit")
```
Related (verification, not code): a nest added at runtime is placed blind on the live map, which was scattered around the
old 12 nests only. A rock, mushroom or (before the resize script runs) a tree trunk can stand on a new nest spot. The new
`WildboundCandyBeastSites_Test` "CH1/CH3" case checks exactly this; run it on the live biome after the resize script and
before deploying.

### M2. `Builder.MAX_PARTS = 1200` is probably too small for a fresh build
`tools/WildboundCandyBuilder.luau:12`. The previous build was about 896 parts (736 at CA time + 160 fluff; the old cap
was 900). This change adds 8 nests x 5 parts = 40 and the extra trees: 16 cotton x 10 + 3 cookie x 4 + 3 cream x 4 +
12 avenue lollipops x 7 = 268. Estimate about 1204 > 1200, so `Builder.build` would hit
`assert(created <= Builder.MAX_PARTS, "part budget exceeded")` (`:977`) and `WildboundCandyBuilder_Test` line 81 would
fail. The comment budgets only the trees, not the nests. Not proven (I estimated the base count). Fix: `Builder.MAX_PARTS = 1300`
(and note the nests in the comment), or measure the count first.

### M3. Resize script silently skips the new posts/nests if run before the A modules are deployed
`tools/wildbound-caramelo-tree-resize.luau:81` -> `Builder.treeKeepOut` reads `ServerScriptService.WildboundPraderaSites.FIXED`
(and needs `ReplicatedStorage.WildboundBeastConfig`, else it adds no post at all, silently) and `Builder.treeNests` reads the
deployed `ServerStorage.WildboundCandyLayout.NESTS`. Run before the new Sites/Layout are in Studio, a nudged or new tree
can stand on an extra post (its Roof is CanQuery, so the BeastSites CH1 raycast fails) or on a new nest spot. The trees
then carry the "done" attribute, so a second run will not fix them. Fix: add after line 46
```
assert(#Layout.NESTS >= 20, "deploy the CH3 WildboundCandyLayout (20 nests) first")
local postsSeen = false
for _, k in ipairs(Builder.treeKeepOut(Layout)) do if k.why == "post candyPostC7" then postsSeen = true end end
assert(postsSeen, "deploy the CH1 WildboundPraderaSites (extra posts) and WildboundBeastConfig first")
```
Deploy order: Config/Sites/Layout/Builder -> start once (syncNests) or `syncNests` in Edit -> resize DRY_RUN -> resize.

## MINOR

1. Test assertions swallowed by the same comment pattern: `tests/WildboundBeastFlanfuria_Test.luau:92` and
   `tests/WildboundBeastGomibu_Test.luau:76` (`... equal(C.points, 0); -- Deliberately changed ... equal(C.keepsEgg, true); equal(C.grounded, true)`):
   keepsEgg/grounded are no longer checked. Fix: move the comment to the end of the line.
2. Resting client binds too widely and too early (`src/wildbound/WildboundCandyRestingClient.client.luau:18`, `:106`).
   BIND_STUDS 50 lets an ambush critter (spawned anywhere, CH4) or a roar copy hide a dormant post's resting copy of the
   same beast when it appears within 50 studs; the first bind runs via `task.defer` before the beast client has moved the
   freshly parented model (it is still at the template pivot), so the resting copy and the live view overlap ~0.25 s. Fix:
   `BIND_STUDS = 12`, and `task.delay(0.1, bind, child, BIND_TRIES)` instead of `task.defer(bind, ...)` (re-pin the
   CandyCritter_Test CH1 string `local BIND_STUDS, BIND_TRIES, BIND_SECONDS = 50, 8, 0.25`). A cleaner fix is a `post`
   field on the server's Spawn event.
3. Ambush clock not reset outside the Meadow (`src/wildbound/WildboundBeasts.server.luau:878`): `summonPass` returns early, so
   `world.ambushAt[player]` goes stale and a player re-entering after >20 s gets an immediate roll 30 studs past the
   entrance. Fix: `if not inMeadow(p.X, p.Z) then return end` -> `if not inMeadow(p.X, p.Z) then if world.ambushAt then world.ambushAt[player] = nil end return end`.
   (The weak-keyed table needs no PlayerRemoving cleanup.)
4. `syncTrees` dry run plans different lollipops from the real run (`tools/WildboundCandyBuilder.luau:635`):
   `nextIndex(lollipopFolder) + report.added` offsets the index by the cotton/sweet trees planned first; when that count is
   odd every avenue lollipop flips Straight/Tilted (different measure, fit and spot) versus the real run. Fix: keep a
   `lollipops = 0` counter, `local index = nextIndex(lollipopFolder) + (dryRun and lollipops or 0)`, `lollipops += 1` after a placement.
5. Resize partial failure without a ChangeHistory recording (`tools/wildbound-caramelo-tree-resize.luau:75-79, 152-158`):
   when `TryBeginRecording` returns nil (another recording open), an error leaves grown trees and some extra trees in place,
   and `syncTrees` marks the root only at the end (`WildboundCandyBuilder.luau:651`), so a re-run adds a second full set of extra
   trees. Fix: in `syncTrees`, treat any child of the three folders that already has `TREES_ADDED_ATTRIBUTE` as "already"
   (or abort when DRY_RUN is false and `recording` is nil).
6. Resize nudges (up to 8 studs) ignore other props: `Builder.fitTree(..., keepOut)` is called with no `also`
   (`wildbound-caramelo-tree-resize.luau:97`), so a moved tree may land in a rock or another trunk. Fix: build a `taken`
   list from the root's KitAsset models (as `syncTrees` does) and pass
   `function(x, z) return Builder.openGround(Layout, x, z, 0, 3, takenWithoutSelf) end`.
7. The "fresh build and live map agree" comment is not quite true: in `Builder.build` `syncTrees` runs before the hills and
   portal exist (`:940`), and the live map's base scatter was made by the old `scatter` (different rng stream), so the extra
   trees differ. Documentation only.

## Checked and fine
- Director: `check(..., roar, post)` arity at every caller (`blocked`, `reserve`, `summon`, `alarm`, `roar`); encounter ids unique; rest keys `name@post` never collide with home `name`; release clears `encounters`/`active`; roar still one-of-a-kind across posts.
- `Director.alarm` 6th arg: the only callers are the beasts server (passes `key` or nil) and tests (5 or 6 args).
- `WildboundBeasts.server.luau`: no new top-level locals (`world.startAtPost`, `world.ambushAt`); every upvalue used (`groundAt`, `close`, `count`, `safeStart`, `bodyOf`, `rng`, `contextFor`) is defined above its use; no yield in Heartbeat; no live-table mutation during iteration.
- GuardAlarm: `"Gomibu@candyPostC7"` parses (`%w+`), home bindings give `key = nil`; `bodyOf` returns 3 values.
- Extra posts: all 8 FIXED, 8.6-14.4 studs from their own new nest, 13-33 studs off the routes and inside the wake radius, >=133 studs from the boss centre, >=95 from the entrance, >=100 from the home post, all 16 posts >=30 apart; `Nests.bind` gives C7/R6/C8 to the extra guardians and leaves home bindings unchanged.
- Leash/home: every candy brain sets `e.home = copy(e.pos)` from the spawn point, so extra posts and ambushers leash to where they start.
- Ambush: per player every 20 s, chance 0.75, cap 2 active, per-kind rest `name@ambush`, only critters; spot out of safe zones (`world.landing`), >=10 from the plot edge, >=80 from the entrance, >=112 from the boss centre; refused in safe zones by the director; IdleSeconds ends unvisited ones.
- Speeds: every base chase 21.5-23 < 23.2; sprints 28-30; trained caps 36/40; damage max 23 < 35; telegraphs unchanged.
- Resting service: publishes `RestingPost_<name>_<post>` with Include-floor rays; client `nameOf` works (no underscore in beast names); no per-frame work.
- Tests hand-traced as passing: Director CH1, Nests CE1/CH1/CH3/CH4/wiring, CandySmarts OF3-1/CH2 (all gains < 15, reach < escape, chaseEnds <= 8), Flanfuria/Gomibu/Tortidragon re-pins, Layout S5/CH3, TrapCake CH3, Builder CH-T4/CH-T5/CH-T8, Big4 CH-T6/CH-T7; runner SPECS already pass `resting`/`restingClient` and `mod:WildboundCandyBuilder` to the suites that need them. Not traceable without Studio: CH-T1/T2/T3 (TreesSkipped = 0 depends on the seeded scatter), BeastSites CH1/CH3 (live map).
- `growTree`: scales about the kit pivot (base centre), keeps the Roof at 13, boosts a leafy canopy once (only when no attribute), idempotent via `CaramelTreeScaleV2`; `fitTree`/`plantSpot`/`growCandyAnnex` loops are bounded (step 0.05 to 1.5, 4 nudges x 8, 400 draws).
- Resize script: Edit-only assert, DRY_RUN mutates nothing (clones are detached), skips anything under `SistemaSonriente`, touches only tree models, the three tree folders and the root attribute; recording Commit/Cancel used correctly when a recording exists.
- Big4 `candyTreeFits`/`growCandyAnnex`: fields (`CANDY.kept`, `ROADS[].points`, `ROAD_WIDTH`) exist; never moves a prop; the resize script calls it with the right arguments.
- A/B interaction: trees keep trunk/Roof 5 + reach off every FIXED post and 8 + reach off every Layout nest at build/resize time (provided M3's order); canopies are CanCollide/CanQuery false, so beast ground rays (`RespectCanCollide`) ignore them.
