# Review: Caramelo GT (cake move) + RC (relentless chases), uncommitted at review start, now `efb1f48`

Scope: `git diff a6a2227 efb1f48` (same content as the reviewed working tree) plus `tools/wildbound-caramelo-cake-move.luau`.
Read-only review; nothing was executed (Luau runs only in Studio). Line numbers are for `efb1f48`.

## BLOCKER

### B1. `syncTower` builds the v3 tower on a live v2 map that has no saved Tower
`tools/WildboundCandyBuilder.luau:168-180`. The "do nothing until the GranTorta carries the key" guard only runs when a
Tower already exists. odd/tasks/wildbound-caramelo-v2.md CT-D1 says the Tower is built at every server start and "the
place file needs no save", so the live v2 place most likely has no `Tower` (and no `Nest_T1`) in Edit. On the first
Play/server start with v3 code before the migration, `applyFlags -> syncTower` takes the "no Tower" path and lays a
67-step stair, turntables, glaze and a summit nest round (726, -3) at 65 studs up, around empty floor, while the v2
GranTorta still stands at (612, -3). That is the half-rebuild the design says cannot happen. After the migration (run in
Edit mode) this is fine.

Fix: check the key before either branch.
```lua
local key = Builder.layoutKey(L)
if torta:GetAttribute("LayoutKey") ~= key then return 0 end -- a v2 map under a v3 layout: nothing until the cake move
local old = root:FindFirstChild("Tower")
if old then
	if old:GetAttribute("LayoutKey") == key then return 0 end
	old:Destroy()
	...
```
(old: `if old:GetAttribute("LayoutKey") == key or torta:GetAttribute("LayoutKey") ~= key then return 0 end`). The
test fixtures that make a bare GranTorta then need the key:
`tests/WildboundCandyTower_Test.luau:32` and `tests/WildboundCandyGlaze_Test.luau:81` should add
`torta:SetAttribute("LayoutKey", Builder.layoutKey(Layout))`. Add a GT8 row: no Tower and an unkeyed GranTorta gives 0.

### B2. Deploy order: v3 code must not reach a running server before the migration has run in Edit
This is not one code line, but it breaks the map if ignored. Until the cake move runs, v3 code on the v2 map gives:
- the return portal refused: `WildboundPortal.STATIONS` says (588, -3) but the v2 Portal model stands at (772, -3)
  (the service refuses a portal more than 2 studs off);
- Don Glaseon sleeping at `Sites.FIXED.bossHome` (676, -3) with territory (726, -3) r 76, while the map's plaza and
  Boss markers are still at (612, -3) r 62;
- La Duquesa's seat and Frutillon's ring computed for a 65-stud summit at x = 726 (`Frut.summit(Layout)`), with no cake
  there.

Studio agent order: deploy everything to Edit, run the migration (DRY_RUN, then real), verify, and only then Play or
publish. Say so in the deploy note.

## MAJOR

### M1. The return portal is unusable in practice: Mochimiau's new post is 35.8 studs from it, and every hunt is relentless
`src/wildbound/WildboundPraderaSites.luau:51` `candyPostR10 = (602, -36)` = local (-10, -33). The portal is at local
(-24, 0), so they are 35.8 studs apart. Mochimiau has wake 45 and sight 40. A player who stops on the pad wakes and is
seen by that copy. Under RC the copy then hunts until the player is safe (the portal pad is not a safe zone) or 180 s
pass. While it hunts, the beast server stamps `beastEngagedAt` every step, so the portal's 5 s calm never comes and a
running channel is cut. In plain terms: with that post, a player at the portal will usually be chased off it. The way
home becomes the walk to the hub, and the portal does not help. Gomibu's new `candyPostE3` (600, 33) = local (-12, 36)
is also only 37.9 studs from the portal (guard 30 plus its patrol radius), so it can do the same.
Fix: put candyPostR10 on the far side of nest R10, at least 50 studs from the portal. For example,
`candyPostR10 = table.freeze({ x = 608, z = -59 })` (local (-4, -56)): 12.5 from nest R10, 59.5 from the portal,
about 38 from the left leg and 56 from the main path. Re-run Nests CH1/CC4 and BeastSites. Keep candyPostE3 at least
45 studs from the portal, or accept the risk with Gomibu's sight of 24. Also consider adding a portal clearance to
`Sites.ambushRoll`: an ambush spot within ~45 of `Layout.PORTAL` returns nil. An ambusher every 15 s that then hunts
relentlessly has the same effect on the pad.

### M2. A test now fails: `tests/WildboundBeastAbeja_Test.luau:196` still pins the pond at (762, -3)
`Sites.OFFSETS.pond` moved to (150, 40), so `Sites.world(nil, "pond")` is now (762, 37). The KB-3 case fails with
"expected -3, got 37". Neither agent re-pinned it. Fix: `equal(pond.x, 762); equal(pond.z, 37) -- GT: pond offset (150, 0) -> (150, 40)`.

### M3. The migration destroys the old Tower and summit nest, despite saying it "never destroys"
`tools/wildbound-caramelo-cake-move.luau:193` calls `Builder.syncTower`, which runs `old:Destroy()` and
`stale:Destroy()` (`WildboundCandyBuilder.luau:176-179`). If the live place does have a saved Tower or Nest_T1 (see B1),
they are destroyed. The backup copy and the undo step make this recoverable, but it breaks the tool's contract.
Fix (in the tool, before step 3):
```lua
local oldTower = root:FindFirstChild("Tower")
if oldTower then archive(oldTower, "laid again for layout v3") end
local nestsFolder = root:FindFirstChild("Nests")
local oldSummit = nestsFolder and nestsFolder:FindFirstChild("Nest_" .. Layout.TOWER.summit.id)
if oldSummit then archive(oldSummit, "laid again for layout v3") end
```
syncTower then finds no Tower and lays a fresh one (with B1 applied, the new GranTorta already carries the key).

## MINOR

- m1 `tools/wildbound-caramelo-cake-move.luau:46-48,173-177`: `forbidden` checks only the instance's name and its
  ancestors. Archiving `Paths`, `Boss`, `Markers`, `GranTorta` or a prop folder child would also carry away a
  `SistemaSonriente` nested inside it. Add `or instance:FindFirstChild("SistemaSonriente", true) ~= nil`, and make the
  run refuse (error, so the recording is cancelled) instead of silently skipping.
- m2 `tools/WildboundCandyBuilder.luau:1052-1053` (cakeMovePlan refit): when a tree has no `CaramelTreeScaleV2`,
  `factor = TREE_SCALE[asset]`, but `m` was measured on the ungrown model. fitTree then checks the tree at f/1.7 of its
  real grown size, and `growTree(model, asset, f)` grows it from 1 to f, bigger than what was checked. Harmless if the
  live map was grown (the tree-resize tool ran), but guard it:
  `if type(recorded) ~= "number" then m = Builder.scaleMeasure(m, factor) end` before fitTree (and use that m for treeFits).
- m3 `tools/wildbound-caramelo-cake-move.luau:93`: the only refusal is the `CakeMoveV1` mark. A root built fresh from
  the v3 builder (LayoutVersion 3, GranTorta already keyed) would be "moved" again: cake, boss, paths and markers would
  be archived and re-laid, and props archived or refitted. Add
  `assert(root:GetAttribute("LayoutVersion") ~= 3 and (root:FindFirstChild("GranTorta") and root.GranTorta:GetAttribute("LayoutKey")) ~= Builder.layoutKey(Layout), "already a v3 map")`.
- m4 Same tool, `module()`: a plain `require` from the command bar is cached for the Studio session. If a DRY_RUN
  required an older Builder/Layout before the deploy, the real run can use the stale copy. Require a fresh clone
  (`require(found:Clone())`), as the test runner does.
- m5 `tools/WildboundCandyDuquesa.luau:132-135`: because the east edge is ignored, `plotDepth >= 0` holds for any point
  east of the plot (unbounded in x), so a carrier far east still starts her rage. Clamp it, e.g.
  `math.max(Layout.CENTRE.x - x, x - Layout.CENTRE.x - Layout.HALF - 30, math.abs(z - Layout.CENTRE.z))`.
- m6 Duquesa outside the plot: `Duq.floorUnder` returns the Caramelo `FLOOR_TOP`, so between the plot and the hub she
  hovers at least `FLOOR_TOP + 4`. If that ground is lower, `|her.y - ty| <= LUNGE_HIT_HEIGHT` can fail and her lunges
  stop (her bubbles still come). Check the hub and corridor floor height in Studio.
- m7 Relentless cap: a hunter stuck behind an obstacle (Telegraph/Chase phase, still stepping) holds one of the 5 places
  for up to 180 s. A refused creature also ignores a theft from the nest it guards (`Smarts.guards`), so a guardian can
  sit calm while its egg is taken. This is a design trade-off; note it in the task file.
- m8 A flyer dive whose claim was booked and then cancelled (giveUp, DiveCancel) keeps its ledger entry for up to about
  1 s, which can refuse a beast strike. Optional: `Smarts.releaseStrikes(id, "flyers:" .. swarmId)` on GiveUp in
  the service.
- m9 Client `WildboundCandyFlyers.client.luau:35-38`: `rec.parts` is collected once in `track()`. Parts streamed in later
  never fade. This is cosmetic; collect them lazily in the first Vanish frame instead.

## Checked and fine
- Trailing `--` comments swallowing code: grepped every added line with code before `--`; none hide code (3 candidates, all plain comments).
- Merge damage in the shared files (PraderaSites, Duquesa, BeastConfig, Duquesa_Test, Nests_Test): no duplicated, lost or contradictory lines; RC and GT edits sit in separate hunks and agree.
- `F.hiveSpotOk(L, lx, lz, steps, posts)`: the only callers are `F.hives` and FL14; both pass the new order.
- `hooks.claim(target.id, swarm.id, strikeAt, now)` matches the service's `claim(id, swarmId, strikeAt, at)`; ids are UserIds on both sides; both use the `GetServerTimeNow` clock.
- `claimStrike` in `WildboundBeasts.server.luau`: the lazy `require(script.Parent:WaitForChild("WildboundCandySmarts"))` returns at once (the behaviour modules already require it from SSS); entries are released in `close()` and dropped on PlayerRemoving; they never block for good (1 s expiry; an owner never blocks itself); force books past the cap.
- `Smarts.engage`/`chasers`: a hunter leaves on done, a quiet phase (Return, GiveUp, Disengage, Ended...) or a 2 s stale step; a dead or left player ends it through `Attack.guard` (Chase.ended) or the server's close; a new encounter starts with a nil `huntFrom`.
- The 180 s hard limit is checked in all four behaviour modules, after the GiveUp/Return early returns and before every active phase. A far ending fades (Disengage -> End); a near one walks home. The resting copy comes back when the live view goes (event driven, `WildboundCandyRestingClient`).
- `Config`/`Attack`/`Smarts` locals exist in all four modules; `Config.BEASTS[e.beast].disengage` nil falls back to 0.9.
- Flyers: Vanish -> Cooldown (bugs reset to idle points, velocity zeroed) -> Idle at `cooldownUntil`; the client fade resets when the hive leaves Vanish; Vanish swarms do not count as awake; the posts keep-out applies only when the Sites module and BeastConfig are present (pcall'd).
- Duquesa vanish: Calm clears the red tint; Home runs `sitDown` (pivot and saved collisions restored); `state.her` nil stops the follow; a pending volley still pops cleanly.
- Builder: about 20 top-level locals (far under 200); the `build` refactor leaves no dangling `paths`/`boss`/`markers`/`main` locals; the helpers' part counts are added to `created`; `growTree` scales relative to the recorded factor (no double growth); `syncCentre` is guarded by `CaramelCentreFillV1`.
- `applyFlags` wraps `syncNests`/`syncTower` in pcall; with a keyed Tower present nothing waits (`WaitForChild` is reached only when a Tower is built).
- Migration: backup first (kept if present); archives by reparenting; one ChangeHistory recording opened in the delayed thread, committed on success, cancelled (undone) on error, refused cleanly when none can be opened; nests move with all descendants (PivotTo); the Portal moves to CENTRE + PORTAL = (588, -3), matching the station.
- Geometry, hand-checked against the suites: depth rings for all 28 nests; every pair at least 20 apart; route distance 11-40 (tightest C13 38, C12 36, C5 37.6, R10 36.2); L1 13.9 from the new left leg; GT3 stair 53.3 <= 58; GT4 junction 114 >= 112 (2 studs spare) and return routes at least 88 (rule 83); GT5 portal 62 >= 58; GT6 glaze; GT2 new nests >= 96 from the boss; KEEP_CLEAR and lake clearances; Gato's R11 post 119 from the boss centre.
- Test hand-traces: Duquesa DR5, DR8 (path to the hub, HUB 282/-3 r 90), GT13, GT14 (65/48 = 1.36 s <= 43/27 = 1.59 s), RC6 (the outside spot 382 is 10 studs outside the hub, she vanishes in the same step as Calm "Safe"); Nests CH1 (9 posts, binding distances 12-13), CH3, CH4 (ambush 15/0.75/3, the plaza point); Smarts CH2 re-pin, RC1-RC4 (ledger arithmetic); Flyers RC5 tired-gap ordering (the override at sting 3 lands on the 3 -> 4 gap).
- Runner SPECS: Smarts_Test and Duquesa_Test add `mod:WildboundWorldRules` as the last argument, matching the new `Rules` parameter; the other changed suites' signatures are unchanged.
- Fairness: no new hit without a tell (dive 0.8 s, roar 1 s, lunges unchanged); the second wind changes speed only.
- Per-frame cost: the client fade touches each bug's parts only while alpha changes; the cap's counter iterates at most a handful of hunters.
- Not verified (Studio only): `Builder.MAX_PARTS` 1450 against a real build, and that 8 hives fit with the posts keep-out on the real layout (FL14 asserts only >= 3).
