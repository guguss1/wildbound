# Silueta awareness rule

Unit M2.1, wave W3a. Answers one question per player: is it after me, my friend, or nobody?

**Status (W3b): wired on the server and read by the HUD.** The rule and its 57 contracts passed in Studio in W3a. W3b adds `WildboundWorld.server.luau` wiring (below) and the HUD chip. Real two-client runs are recorded in the section "Wired in W3b". No person has tried the cue, and every constant is a hypothesis. The awareness result is presentation only and is never read by a strike check.

| File | Explorer path |
| --- | --- |
| `src/wildbound/WildboundSiluetaAwareness.luau` | `ServerScriptService.WildboundSiluetaAwareness` |
| `tests/WildboundSiluetaAwareness_Test.luau` | `ServerStorage.WildboundSiluetaAwareness_Test` |

## States

| State | Meaning | Extra field |
| --- | --- | --- |
| `seen` | This player is the current target and in sight (or inside the sight-flicker hold) | `attackEndsAt`, only in Telegraph |
| `searching` | This player is the target, sight is lost, the search is still running | `searchEndsAt`, absolute server time |
| `ally` | Someone else is seen or searched, and this player is near enough to care | None |
| `none` | No threat to read: Patrol, Retreat, expired search, dead, in a safe zone, far away, or invalid input | None |

## Transitions

| From | To | When | Delay |
| --- | --- | --- | --- |
| Any | `seen` | Becomes the target with sight, or regains sight | **None**, so a warning is never late |
| `seen` | `searching` | Sight lost on the same target and life | Held for `SEEN_HOLD_SECONDS` since the last sight |
| `seen` | `ally` or `none` | Retarget to someone else | None, so both chips flip in one step and two players are never `seen` |
| `seen` or `searching` | `none` | Retreat, Patrol, target removed or dead, new character, search expired | None. These are real endings, not flicker |
| `searching` | `none` | `now - lastVisibleAt >= SEARCH_SECONDS` | None. Same comparison as `WildboundSiluetaHunt` |
| `none` | `ally` | Threat exists and distance is at most `ALLY_ENTER_RANGE` | None |
| `ally` | `none` | Distance above `ALLY_EXIT_RANGE`, or the threat ends, or dead, or safe | None |

The hold never moves `searchEndsAt`. That value stays `lastVisibleAt + SEARCH_SECONDS`, so a held search shows a shorter countdown, not a longer one.

## Constants

All in `Awareness.CONSTANTS`, frozen. Trunk width is from `docs/maps/wildbound-p0.md:30`; the other inputs are from `WildboundWorldRules.luau`, the 0.2 s step at `WildboundWorld.server.luau:354`, and walk speed 16 and fog start 45 from `docs/testing/wildbound-baseline-m1.md`.

| Name | Value | Why | Falsified by |
| --- | --- | --- | --- |
| `SEARCH_SECONDS` | 1.5 | Not a choice. Mirrors the literal at `WildboundSiluetaHunt.luau:23`. A contract runs the real Hunt to the exact boundary | That contract failing |
| `SEEN_HOLD_SECONDS` | 0.6 | Three fixed steps, so up to two dropped sight samples cannot flip the chip. Calculated: a player at 16 studs/s passing a 3 to 4 stud trunk is hidden about 0.25 s with the trunk beside them, about 0.5 s with it halfway to Silueta. A 0.5 s block usually drops two samples, but the worst alignment drops three and flips the chip. It leaves 0.9 s of readable countdown | Testers say the chip lags after they hide, or the chip still flickers in the forest |
| `ALLY_ENTER_RANGE` | 46 | Night detection 38 plus half a second of walking (8), so the chip arrives before this player can be retargeted. Also about where fog starts (45), so the player can likely still see Silueta. One value day and night, for a stable meaning | Allies report warnings for a threat they cannot see or reach, or are retargeted with no earlier cue |
| `ALLY_EXIT_RANGE` | 54 | Enter plus 8 studs: half a second of walking, about 2.5 steps of movement, so walking along the edge does not flicker. Below chase range 65 | Testers see `ally` flicker at the edge, or it lingers after they left |

## Decisions

| Decision | Why | Tradeoff |
| --- | --- | --- |
| Invalid input gives `none` and never throws | A throw inside a server step is worse than a missing cue | A bad input hides a cue for one step. Damage gates must never read this rule |
| A backward clock cancels holds | Raw truth beats a stretched debounce. The countdown is also capped at `now + SEARCH_SECONDS` | A small clock step can end one hold early |
| Time hold on `seen`, range hysteresis on `ally` | `ally` does not depend on target sight, so only position can flicker it | No time hold on `ally`. Crossing both edges still takes at least 0.5 s each way |
| A former target falls back through the exit range | Being chased at 50 studs, then instantly `none`, reads as a glitch | A former target stays `ally` farther out than a newcomer would |
| `safe == true` is never `ally`; being outside the fog can be | A friend beyond the fog line cannot be retargeted but can still watch | Could be noisy; check in the five-pair test |
| Ally range is measured to Silueta, not to the target | Matches the existing snapshot `distance` and the retarget rule | A friend beside a far target may read `none` |

## What W3b must wire

Nothing below exists yet. Line numbers are for `WildboundWorld.server.luau` unless stated.

1. **Create once.** `local Awareness = require(script.Parent:WaitForChild("WildboundSiluetaAwareness"))`, then `local awareness, awarenessResults = Awareness.new(), {}`.
2. **Step once per fixed step, after the FSM.** Call it directly after `step(now, 0.2)` at `:359`, with the same `now`, so it reads the mode and target that step just set. `workspace:GetServerTimeNow()` is the clock clients already compare against.
3. **Build the input.**

```luau
local context = target and targetContext(target, Rules.CHASE_RANGE, true)
local entries = {}
for player in pairs(records) do
    local character, _, root = characterContext(player)
    local safe, distance = false, nil
    if root then
        _, safe = Rules.zone(root.Position.X, root.Position.Z)
        distance = (root.Position - body.Position).Magnitude
    end
    table.insert(entries, { id = player.UserId, life = character, alive = root ~= nil,
        distance = distance, safe = safe })
end
awarenessResults = Awareness.step(awareness, { now = now, mode = mode,
    targetId = target and target.UserId, targetLife = targetLife,
    targetVisible = context ~= nil and context.visible,
    lastVisibleAt = huntState and huntState.lastVisibleAt,
    telegraphEndsAt = telegraphEndsAt, players = entries })
```

4. **Push on change.** For each player whose result has `changed == true`, call `snapshot(player)`. This replaces waiting for the 1 Hz tick at `:369`. `changed` is false for steady states, so it is bounded by real transitions.
5. **Snapshot payload.** At `:193`, add `awareness = Awareness.toSnapshot(awarenessResults[player.UserId])`. A missing result snapshots to `none`. The value holds one string and at most one finite number, and never the life.
6. **Scene 5, target-only warning.** Stop sending the global `telegraphEndsAt` at `:194`. Make `WildboundWorld.client.luau:142` read `guardian.awareness.attackEndsAt`. The `TelegraphEndsAt` model attribute stays for the 3D pose.
7. **Scene 6, inventory.** The chip must live outside `panel`, which is hidden at `WildboundWorld.client.luau:128-130`.
8. **Scene 8, bodies block sight.** `visible()` at `:120` excludes only the one character. Exclude every player character, or A flips to `searching` when B steps between. This rule only trusts `targetVisible`, so its contract cannot prove this: scene 8 needs the two-client run.
9. **Scene 9, threat.** `:193` must exclude Retreat as M2.2 says. Do not derive the chip from `threat`; derive it from `awareness.state`.
10. **Remove on leave.** Nothing to call: a player missing from `players` loses their memory on the next step. A target leaving is already handled by `clearTarget` at `:345`.

**Later, M4 (`docs/mechanics/wildbound-fair-strike.md`).** `AttackWarning` keeps its own remote and `attackId`. `seen` plus `attackEndsAt` is the cue a chip can show when text is delayed, and it already goes only to the target. It carries no attack ID and **must never be a strike gate**, because the hold can show `seen` after sight has gone.

## Scene coverage

| Scene | Rule contract | Still needs the two-client run |
| --- | --- | --- |
| 1 to 4, 7, 9 | Yes | Yes, for what the HUD shows |
| 5 | `attackEndsAt` only on the target | Yes, the client must read it |
| 6 | Interface state is not an input | Yes, the chip placement decides it |
| 8 | Sight is the only input | **Yes, the sight ray decides it** |

The five-pair human test is untouched by this unit.

## Verification

Run the suite in Studio on fresh clones. The test takes the module, the real Hunt, the real rules and the module's source:

```luau
require(testClone)(require(awarenessClone), require(huntClone), require(rulesClone), awarenessClone.Source)
```

Observed results are recorded in the task document by the parent. Nothing here proves the cue is readable, muted or on a phone.

## Wired in W3b (M2.2)

| Item | Where |
| --- | --- |
| Create once, step once per fixed step right after the guardian step with the same clock | `stepAwareness(now)` in `WildboundWorld.server.luau` |
| Input per player: `life` is the character, `distance` is to Silueta, `safe` from `Rules.zone`; target sight is `targetContext(target, CHASE_RANGE, true)` | same function |
| Push a snapshot to each player whose result has `changed` | same function |
| Payload: `guardian.awareness = Awareness.toSnapshot(result)`. The global `telegraphEndsAt` is no longer sent. `TelegraphEndsAt` stays a model attribute for the 3D pose | `snapshot()` |
| `guardian.threat` is `Rules.isThreat(...)`, which excludes Retreat | `WildboundWorldRules.luau` |
| Other bodies do not block sight: `visible(..., ignoreBodies)` excludes every player character for Silueta's sight. The flashlight and pulse ray still excludes only the caster | `visible()`, `targetContext()` |
| Ground disc: `Rules.groundCue(anySeen)` is amber, larger and more solid while any player is `seen` | `stepAwareness()` |
