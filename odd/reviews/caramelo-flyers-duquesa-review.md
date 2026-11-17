# Review: Zumbidulces (flyers) and La Duquesa's rage (uncommitted, 2026-11-16)

Read-only review of the uncommitted code in `wb-first-playable` (branch codex/wildbound-first-playable). Nothing was
run (Luau only runs in Studio). Every test case below was traced by hand against the code. The collaborators I read
were the `BeastHit` bindable (`WildboundServer.server.luau` 2354-2380), `WildboundDodge`, `WildboundDodgeService`,
`WildboundWorldRules.zone`, `Heist.syncEggArms` / `Heist.dropEgg` / `EggCarry.carriedBy`, `spawnEncounter` (the
`EncounterId` and `Island` attributes), `WildboundCandyNests.islands`, `WildboundAudioCatalog`, `WildboundText.BEAST`,
`WildboundCandyCritterAnim` (the cue parse), `WildboundCandyCritterClipsDuquesaBurbuja`, `Frut.summit`, and the push
slot in `WildboundBeasts` / `Frutillon` / `TrapCake`.

**Verdict: no BLOCKER found.** Nothing I found will throw at runtime, and no argument order or arity is wrong against
the real callees. There are 3 MAJOR findings (all on the Duquesa side) and a set of MINOR ones. Two test cases (FL10,
DR8) are too long to trace by hand with certainty. Run them first.

---

## MAJOR

### D-1 MAJOR: her lunge cannot be avoided except by a perfect dodge (the tell never locks)
`tools/WildboundCandyDuquesa.luau:257-264`. During `Tell` she keeps calling
`fly(summit, her, p.x, ty, p.z, speed, Duq.HOLD_STUDS, dt)`, so she holds 3 studs from the thief at 27 to 34 studs/s.
At the strike she dashes `min(LUNGE_REACH_STUDS, distance)` straight at the thief's **current** position, so she lands
on the thief every time the thief is within 10 studs of her. Nobody at 11, 16 or 23 studs/s can be more than 13 studs
from a pursuer that flies at 27. Running or juking never works. The tell is only a timing cue for the dodge button.
DR8 confirms this ("a carrier who never dodges is caught by her first lunge"). The flyers do the opposite: they lock
the spot at `diveAt`, and FL8 shows that a juke beats the dive.

A related point: a dodge press that misses the perfect window still gives 0.28 s of dash invulnerability. If the
strike lands inside that time, `BeastHit` returns `dodged` (no damage, no egg drop, no push), but the rules already
counted a `Hit`. She then recovers for 1.2 s instead of being stunned. That is harmless, but it is a second path.

This is an owner decision, not a crash. If running or juking should be able to beat the lunge, the smallest fix is to
make her hold position during the tell and dash toward the spot locked when the tell starts:
```
-- old (rageStep, Tell branch)
		elseif r.phase == "Tell" then
			fly(summit, her, p.x, ty, p.z, speed, Duq.HOLD_STUDS, dt)
			if now >= r.lunge.strikeAt then
				local ux, uz = unit(p.x - her.x, p.z - her.z)
				if not ux then ux, uz = 1, 0 end
				local reach = math.min(Duq.LUNGE_REACH_STUDS, flat(her.x, her.z, p.x, p.z))
-- new
		elseif r.phase == "Tell" then
			fly(summit, her, her.x, ty, her.z, 0, 0, dt) -- height only: she hangs in the air during the tell
			if now >= r.lunge.strikeAt then
				local ax, az = r.lunge.aimX or p.x, r.lunge.aimZ or p.z
				local ux, uz = unit(ax - her.x, az - her.z)
				if not ux then ux, uz = 1, 0 end
				local reach = math.min(Duq.LUNGE_REACH_STUDS, flat(her.x, her.z, ax, az))
```
Also set `aimX/aimZ = p.x, p.z` (plus the thief's lead, as in `throw`) in the `Lunge` creation at line 252. This fix
**will break** DR8 ("never" caught at lunge 1) and probably the K bounds, so those tests need re-tuning (for example
`LUNGE_START_STUDS` 9 -> 6, `LUNGE_REACH_STUDS` 10 -> 12). If "only the dodge saves you" is what the owner wants, leave
it as is and record that decision in the task file.

### D-2 MAJOR: an invisible Duquesa still rages, lunges and drops the egg when her model is missing
`src/wildbound/WildboundCandyDuquesaService.server.luau:43-45, 344-348`. If `WildboundNewCandyPreview.DuquesaBurbuja`
is not found within 30 s plus 30 s, the service only warns. The rules still run: `carriesHerEgg` is still sampled, so a
rage starts, and lunges hit for 25 damage and drop the egg. The only visible parts are the red line, the ring and the
bursts. No body, red tint or sign is shown, because `setRed`, `leaveSeat` and the Heartbeat move all return early when
`duquesa` is nil. A thief gets hit by nothing.

Fix (one line, in the sampling):
```
-- old
			if arms and herEggs[arms:GetAttribute("EggId")] then
-- new
			if arms and duquesa and duquesa.Parent and herEggs[arms:GetAttribute("EggId")] then
```

### D-3 MAJOR (existing gap, but this rewrite is what would ship): the Duquesa files are not in the deploy manifest
`tools/deploy_manifest.py` has no rows for `tools/WildboundCandyDuquesa.luau`, `WildboundCandyDuquesaService`,
`tests/WildboundCandyDuquesa_Test.luau` (nor for `WildboundCandyCritterAnim`). The playfix task log already lists this
as the known `test_studio_fresh_runner` failure. A Studio agent that deploys "by manifest" will silently leave the old
Duquesa in place and run the new test against the old rules (DR1 onward would then fail with "no rage"). Either add
the rows (ServerStorage / ServerScriptService / ServerStorage, matching how they live in the place today) together
with their `test_deploy_manifest.py` mirror, or tell the Studio agent to write these three by hand and check their
hashes.

---

## MINOR

### Flyers
- **F-1 MINOR (idle replication and performance)**, `WildboundCandyFlyersService.server.luau:274-280`. Idle swarms
  still write `body.CFrame` plus the `At` and `Vel` attributes every third step, forever, even when nobody is in the
  biome. That is about 15 bugs x 3 properties x about 3.3 Hz, roughly 150 replicated changes a second, reaching every
  client including players in the hub. Chasing swarms add about 450 a second. Fix: skip `place()` for a calm swarm
  when no sampled player is within about 150 studs of its hive (`sample()` already has the positions). Better: let the
  client compute the idle hover itself from `F.idlePoint`.
- **F-2 MINOR (idle stutter on the client)**, `WildboundCandyFlyers.client.luau:20, 87`. `EXTRAPOLATE = 0.15`, but
  idle bugs get a new `At` only every about 0.3 s (every third step of an about 10 Hz step). Each idle bug moves for
  0.15 s, freezes for about 0.15 s, then snaps by about 0.4 studs. Idle is the state players see most. Fix:
  `local EXTRAPOLATE = 0.15` -> `local EXTRAPOLATE = 0.35` (or measure the gap between two `At` updates and use that).
- **F-3 MINOR (step rate)**, `WildboundCandyFlyersService.server.luau:268-269`. `clock = 0` throws away the remainder,
  so at 60 fps a step fires every 6 frames, about 10 Hz rather than 12. That is still inside FL1's 10-15 Hz range.
  Fix: `clock = 0` -> `clock -= F.STEP_SECONDS` (and clamp `clock` to at most `F.MAX_DT` after a hitch). The same
  pattern exists in the Duquesa service (STEP 0.1, already existing).
- **F-4 MINOR (a sting yields the step)**, service line 232. `sting()` calls `beastHit:Invoke` inline, inside the
  pcall'd step loop. If `OnInvoke` ever yields, the step stalls, and the next Heartbeat starts a second overlapping
  step on the same `world`. Duquesa already does this safely. Fix: `if player then sting(player, e) end` ->
  `if player then task.spawn(sting, player, e) end`.
- **F-5 MINOR (StreamingEnabled only)**, client `track()` / `scan()`. With streaming on, a bug part that streams out
  and back in comes back as a new instance. `bugs[model]` still points at the dead `Body`, so that bug is never
  smoothed again and its wings freeze. The hive's buzz is also lost, because the Sound was parented to the old
  `Bug_1.Body`. Fix: in `scan()`, drop the records whose body has no parent before `track()`:
  `for model, rec in pairs(bugs) do if not rec.body.Parent then bugs[model] = nil end end`, and the same for
  `hives[h].sound.Parent`. If streaming is off, ignore this.
- **F-6 MINOR (hives on the syrup lake)**, `tools/WildboundCandyFlyers.luau:115-134`. `hiveSpotOk` has no
  `Layout.LAKE` / `BRIDGE` rule. The left route's bottom leg (z = -140) puts candidates at z = -124, inside the lake
  disc (0, -120, r 24) and the side discs. Fix: add
  `for _, w in ipairs(L.LAKE or {}) do if flat(lx, lz, w.x, w.z) < w.r + 4 then return false, "Lake" end end`. Decor
  (trees, lollipops) is not checked either, so a hive can clip into scenery.
- **F-7 MINOR (jump snap)**, rules lines 315, 336, 343-344. "ground" is `target.y - ROOT_HEIGHT`, so it follows a
  jumping root. A jump lifts every flying bug by up to about 7 studs in one step (the clamp at line 336 runs after
  `setAt`, so `Vel` does not show it and the client snaps), and the Aim marker floats in mid-air. The fix is cosmetic:
  ignore upward root motion above the last grounded `y` (for example take `HumanoidRootPart` y only when
  `humanoid.FloorMaterial ~= Air`).
- **F-8 MINOR (buzz ignores the mixer)**, client lines 48-54. The buzz Sound has no `SoundGroup`, so the game's volume
  and mute settings (`WildboundAudioMix`) do not affect it. Parent it under the Ambient group the audio client uses,
  or set `sound.SoundGroup`.
- **F-9 MINOR (client cost per frame)**, client `RenderStepped`. Every frame it writes 15 body CFrames and 30 weld C0s
  on every client, wherever the player is. Skip bugs farther than about 200 studs from `workspace.CurrentCamera`.

### Duquesa
- **D-4 MINOR (lunge visual lags behind the hit)**, service lines 319-328. She moves up to 10 studs in one rules step,
  but the model lerps at `dt*10`, so it arrives about 0.2 s after the strike burst and the push. Fix: snap on strike:
  in `play`'s `Strike` branch add
  `if duquesa and seatPivot then duquesa:PivotTo(CFrame.new(Vector3.new(ev.x, ev.y, ev.z) + seatOffset) * duquesa:GetPivot().Rotation) end`.
- **D-5 MINOR (blind spot with several eggs)**, service line 344. `WildboundEggCarried.EggId` is only the newest egg
  (`EggCarry.carriedBy` returns the last one). A thief who picks up any other egg after hers stops looking like her
  thief: she calms with reason "Dropped", and she never rages at someone whose newest egg is not hers. The egg she
  knocks loose is always the newest one, which is hers whenever she rages, so the drop is correct. It is a cheap
  exploit, not a crash. Fix (server side): expose the whole carried list as an attribute, or accept the gap.
- **D-6 MINOR (no cleanup on stop)**. The service has no `script.Destroying` / `BindToClose` handler. A script disable
  or reload during a rage leaves her mid-air, without collision, with the Highlight and sign on. Add a `stop()` that
  calls `setRed(false); sitDown(); folder:Destroy()`.
- **D-7 MINOR (generic hit text)**. `WildboundText.BEAST` has no `DuquesaBurbuja` and no `Zumbidulce` entry, so a
  flyer sting shows "¡Una bestia te golpeó!". The Duquesa hit shows `Text.EGG.knocked` when the egg drops, which is
  fine. Add `Zumbidulce = { hit = "¡Picadura de Zumbidulce!" }` and `DuquesaBurbuja = { hit = "¡La Duquesa te
  embistió!" }` to `Text.BEAST`.
- **D-8 MINOR (test coverage silently lost)**, `tests/WildboundCandyDuquesa_Test.luau:51`. This is the exact comment
  bug named in the brief, already in the committed file. `equal(Duq.BUBBLES, 3, ...)` and `equal(Duq.DAMAGE, 0, ...)`
  sit after the `--` and never run. Fix: split the line:
  ```
  		equal(Duq.EVERY_SECONDS, 6, "every") -- Deliberately changed (OF3, a hard summit): 10 -> 6 s
  		equal(Duq.BUBBLES, 3, "bubbles"); equal(Duq.DAMAGE, 0, "damage")
  ```
- **D-9 MINOR (cosmetic)**. Dead players are filtered out of `players` (service line 339), so a thief's death always
  ends the rage with reason "Gone" in play, never "Dead". Only telemetry or debug text would notice.

---

## Tests traced by hand

**Runner SPECS.** The flyers row `{ mod:Flyers, mod:Layout, mod:WildboundDodge, {service, client} }` matches the
signature `(F, Layout, Dodge, sources)`. Every token names a script that is in the manifest. The Duquesa row matches
`(Duq, Frut, Layout, {service, anim}, Chase)`. `WildboundCandySmarts_Test` also loads the new Duquesa. It never sets
`carriesHerEgg`, so it keeps the old behaviour.

**Flyers.**
- FL1: pass (CRUISE 25, GAP 0.9, dive 32 studs/s, heights 4.4-8.5, STEP 1/12, 3 x 12 x 2 = 72, 5 x 3 = 15, TEXT
  frozen).
- FL2: pass by inspection. Valid spots exist on the left, right and main routes, for example (-62.7, -99.7) passes
  every rule. The floor equals FLOOR_TOP, the `safe` stub returns 0 hives, and a plot centred elsewhere moves the
  hives with it.
- FL2b: pass. The `__index` proxy reads NESTS, BOSS and TORTA through `L`.
- FL3: pass.
- FL4: pass. Safe and dead players are not woken; the tell is 1.0 s; the bugs stay at the hive during the tell; Chase
  starts exactly at `chaseAt`.
- FL5: pass. The first chase step's dt is 0.05; the bugs start at idle height 4.4-5.6, so the clamp never adds
  movement beyond cruise speed.
- FL6: pass. The pull-up reaches 9.0 (8.5 + floor) inside 0.8 s; the strike lands on (10, 0); resolve is called
  once; the recover climb is 0.15 per step.
- FL7: pass.
- FL8: pass. The lock is `px + 16 x 0.5`, inside the 16-stud reach; after reversing, the player is 16 studs off at the
  strike, so it is a Miss and the dodge is never asked.
- FL9: pass for every reason. The noGo case uses (10, 0) to wake and (32, 0) to give up; the tower zone radius 30 is
  at least the stair's 28.4; Timeout comes at 1.1 + 14; Satisfied after 3 hits; Cooldown and Idle land on both sides
  of 12 s; DiveCancel carries `id = 1` because it is emitted before `swarm.target = nil`.
- FL10: **not confirmable by hand**. My estimate: the sprinter takes about 2 stings, then Leash at about 7 s; the walker
  reaches about 3, or Satisfied; the straight sprint hits Leash at about 3.3 s with 0 stings. All are inside the bounds,
  but the margins are thin (one late step can move the sprinter to 3 stings).
- FL11: pass.
- FL12: pass. There is exactly 1 `Raycast(`; `WaitForChild("WildboundNetwork"` matches the call with its timeout; there
  is no `Health -`, `dropEgg` or `TakeDamage`.
- FL13: pass with the edited WildboundDodge.

**Duquesa.**
- A2 cases: unchanged; pass. Only line 51 has dead asserts (D-8).
- DR1: pass. She rages at t = 0, roars, and ignores a second carrier, another egg, a safe player and a player outside
  the plot (depth -2).
- DR2: pass. At t = 1.0 the Chase starts and she moves 2.7 studs.
- DR3: pass. 4 x 2.7 = 10.8 studs flat. Height trace: 44.94 -> 37.74 at t = 1.5 -> 6.54 at t = 2.8, the lunge starts
  at 8.7 studs flat, and the strike at t = 3.7 is 4.5 over the floor.
- DR4: pass. Strikes at 3.7, 5.8 and 7.9 are all Hit with a unit push; the second lunge starts 1.2 s after the first
  strike; rage volleys at 1.5 and 4.0 (the 4.0 one is allowed during Recover); rings at y = 0.5.
- DR5: pass. Safe, Dead, Gone and Left (depth -13) all end the rage, and the -11 margin keeps chasing. The lunge
  started at 2.8 is cancelled at 3.3. Dropped -> Calm for 3 s, then Return at 4.5 and Home at about 5.5.
  Timeout at t = 25.0.
- DR6: pass. Dodged at 3.7, stunned in place, the next lunge comes about 2.5 s later, and resolve gets `(7, 1)`.
- DR7: pass. Safe at 1.5, then Return, Home at about 2.4, and the next Rage at Home + 20.
- DR8: "never" passes (caught by lunge 1 at about 1.9 s). The "perfect" cases are **not confirmable by hand**. A cycle
  of stun 2.5 + catch-up about 1.2 + tell 0.9 gives K of about 5 for the walker (the test requires at least 5) and
  about 3-4 at 16 studs/s. The walker's bound is right at the edge, and the chord across the spinning tiers can make
  her climb and delay a lunge (fewer K). Run it first. If it fails, `STUN_SECONDS` 2.5 -> 2.2 is the obvious tune.
- DR9: pass. Every pinned string is present verbatim; `Raycast` appears only as lower-case "raycast" in a comment, so
  the case-sensitive `lacks` check passes.

---

## Checked and found fine (one line each)
- `BeastHit:Invoke(player, beast, damage, keepEgg)`: both callers pass `(Player, string, number in 0..100, bool)`. The
  flyers pass `true` (egg kept), the Duquesa passes `ev.drop ~= true` = `false` (egg drops through `Heist.dropEgg`).
- The `dodged` return (dash invulnerability) is honoured by both: no push.
- `Heist.dropEgg` drops `EggCarry.carriedBy` (the newest egg), the same egg the `WildboundEggCarried` model shows, so
  she never knocks loose the wrong egg.
- `EggId` on the carried model is the encounter id (`EggCarry.add(eggs, id, ...)`), and `EncounterId` / `Island` are
  set synchronously in `spawnEncounter` before the deferred `noteEgg` runs. `slot.island = spec.id` = "CandyT1".
- `herEggs[nil]` is a legal read in Luau (no error when `EggId` is missing).
- DodgeService: `telegraph(player, id, source, startAt, strikeAt)`, `resolve(player, id, now)`, `cancel(player, id)`.
  All calls use this order. Sources "Zumbidulce" (added) and "DonGlaseon" exist. Telegraphs are 1.3 s (flyers) and
  0.9 s (Duquesa), at least 0.8. Ids are at most 64 characters (`Zumbidulce:H5:3:n`, `Duquesa:s:userId:n`).
- Both scripts share the one `WildboundDodgeService` module state (same ModuleScript, same VM), so the press that the
  inventory server records is the one these scripts resolve.
- Every lunge or dive is resolved, missed (cancelled), or cancelled on give-up/calm, so no attack is left in the dodge
  state, and `prune` covers the rest.
- One hit per dive or lunge: the strike runs once (the phase leaves Dive/Tell in the same step), and `swarm.diving`
  allows only one diving bug per swarm.
- No hit in a safe zone, on a dead player or after the target leaves: `lost()` / the rage end checks run before
  `chaseBug` / the strike in the same step.
- The cap of 2 swarms per player is counted from Alert+Chase before the wake loop and updated in it (FL11 traced).
- The swarm state machine has no dead end: Idle -> Alert -> Chase -> Return -> Cooldown -> Idle. Return always
  converges (16 studs/s against an idle point moving at 3.15). The cooldown clears from `cooldownUntil` even when the
  trip home takes longer.
- Rage machine: Roar -> Chase <-> Tell -> Recover/Stunned -> Chase. Every end -> Calm -> Return -> Home, then the
  cooldown is set. `fly()` toward the seat converges because `floorUnder(seat) + 4 == seat.y`.
- Non-rage Duquesa: the summit volleys run only while `mode == nil` and are otherwise unchanged; `push` clamp 8 -> 12
  does not affect the bubble push (4 studs); `hands()` changes only while she is away from the seat.
- Seat restore: `leaveSeat` saves the pivot and collidable parts, and `sitDown` restores both on Home. The yaw maths
  (`atan2(-x, -z)` delta, premultiplied about world Y) is correct.
- The server Highlight and BillboardGui replicate to everyone, are removed on Calm, and there is only one of each.
- Clip cues "Surprised", "Charge", "Whip", "Glide" exist in her clip set, and the animator's `^(%a+):` parse accepts
  the "r<n>" suffix.
- Flyers replication: the client writes the anchored body's CFrame in `RenderStepped`, which runs before render, and
  replicated values are applied after render. The client value is what gets drawn: the smoothing works, it does not
  fight replication, and the server writes are only wasted bandwidth (F-1). Local weld C0 writes are never overwritten
  (the server never changes them).
- `WildboundAudioCatalog.SOUNDS.insectsNight.ids[1]` exists, and the require is inside a pcall (a missing catalog
  means no buzz, not an error).
- Infinite yields: the server WaitForChild calls without a timeout are for manifest-deployed modules
  (WildboundCandyFlyers, Layout, WorldRules, DodgeService); Workspace lookups use timeouts of 15, 30 or 60 s.
- Leaks: `noted` is cleared on PlayerRemoving; markers are removed on Hit, Miss, Dodged and DiveCancel; push
  attachments are destroyed by `task.delay`; the folder is destroyed on Destroying and BindToClose.
- Luau syntax: no comment swallows code in the new or rewritten files (searched; the only case is the existing D-8
  line). Same-line statements such as `x:Destroy() y = nil` and `swarm = s break end` are valid.
- Phones and fairness: tells are 1.0 s (wake), 0.8 s + 0.5 s (dive), 1.0 s (roar) and 0.9 s (lunge). Hits are 12
  (flyer) and 25 (Duquesa). No single hit is 35 or more. 15 x 7 = 105 parts plus 5 hives. The only raycasts are one
  per hive at start (flyers); Duquesa has none.
