# Wildbound new mechanics (offline rules, ready to wire)

User decisions Q2b, Q3b, Q4/Q4b, Q10 and Q11 (`docs/design/wildbound-combined-plan.md` section 6). Each is a new pure Luau module with a suite; nothing is wired, deployed or tested in Studio yet. No offline Luau runtime exists on this machine, so every suite is unrun (RED/GREEN pending Studio). Feature document: `odd/tasks/wildbound-new-mechanics.md`.

| # | Module (Explorer path) | Suite | Replaces |
| --- | --- | --- | --- |
| 1 | `WildboundArrullo` (ReplicatedStorage) | `WildboundArrullo_Test(Arrullo, source)` | The capture ring for Rara, Epica and Legendaria eggs |
| 2 | `WildboundDodge` (ReplicatedStorage) | `WildboundDodge_Test(Dodge, source)` | The Burst (`Stamina.burst`) |
| 3 | `WildboundBatKnock` (ServerScriptService) | `WildboundBatKnock_Test(Knock, source)` | `Bat.swing`, `Bat.hit`, the stumble |
| 4 | `WildboundTotemRecord` (ServerScriptService) | `WildboundTotemRecord_Test(TotemRecord, Record, source)` | Session-only `luckTotems` |
| 5 | `WildboundDusk` (ReplicatedStorage) | `WildboundDusk_Test(Dusk, source, WorldRules)` | Nothing (new) |

Each suite returns `{ passed, failed, messages }` like the other Wildbound suites. Run each from a fresh clone of the module.

## 1. Arrullo (rare-egg lullaby)

A vertical bar from 0 to 1. A calm zone glides between random spots on an eased curve, so it never jumps. Rarer eggs get a smaller, faster zone. Holding raises the marker and releasing lets it fall. The progress meter starts at 35, fills inside the zone and drains outside it. The player wins at 100 and loses at 0 or after 18 s. Original look: a lullaby meter with no borrowed art. The server owns `Arrullo.session(rarity, Random.new(seed), now)`. The client sends only `"hold"` or `"release"` (`Arrullo.input`, at most 20 per second, anything else is refused). The server calls `Arrullo.advance(session, now)` from its loop, in 1/30 s substeps, catching up at most 0.5 s, and replicates `Arrullo.view(state)`.

## 2. Esquiva perfecta

The server calls `Dodge.telegraph(state, id, source, startAt, strikeAt)` when a telegraph starts. Sources are `Parent`, `Viper`, `Pouncer` and `Silueta`. A telegraph under 0.8 s is refused. A press in the last 0.35 s up to the strike makes `Dodge.resolve` return `Dodged` at the hit moment, so the hit is cancelled, and grants a 1 s boost (x1.35, cap 26). An Early, Late or Whiff press does nothing and starts a 1.2 s cooldown. More than 4 presses in 1 s lock the dodge for 2 s. It gives no invulnerability: only the attacks whose window held the press are cancelled.

## 3. Bat knockback

The cooldown is 5 s and a miss spends it too. A landed hit ragdolls the target for 1.2 s and drops a carried egg. It pushes the target away from the attacker at 45 studs/s with 20 up. That push is capped so the ballistic flight is never over 24 studs. Immunity lasts 3 s and covers the whole ragdoll. Nobody can swing or be knocked inside a safe zone (pass the hub disc and the bases as `zones`). The hitbox stays in `Bat.inReach` and `Bat.pickTarget`.

## 4. Luck totem persistence

Schema 4 adds `totems = { totemSuerte = count }`, capped at 5. A totem can be `bought` or `earned`, and placing one consumes it. The step `3 -> 4` only adds a missing map and never invents or repairs anything. A malformed section therefore fails validation, Persistence quarantines it, and nothing overwrites real data. No data store is touched.

## 5. Dusk

The rule reads the existing 72 s Dusk phase of `WorldRules.cycle`. It warns once when Dusk starts and once 20 s before Night. A server that joins in the last 20 s sends only the first line. During Dusk only, beasts get speed x1.08, director roll x1.25 and detection x1.1. Night keeps its own x2.

## Tunable rows for `WildboundTuningSchema` (add later; format `value(key, label, system, constant, default, min, max, step)`)

| System | Rows |
| --- | --- |
| Arrullo | `TIMEOUT` 18 (8-60, 1); `START` 35 (5-95, 5); `LIFT` 2.4 (0.5-8, 0.1); `GRAVITY` 2.0 (0.5-8, 0.1); `MAX_SPEED` 0.9 (0.2-3, 0.1); per rarity R in Rara/Epica/Legendaria: `ZONE_R` 0.30/0.24/0.18 (0.1-0.6, 0.02), `SEGMENT_R` 1.6/1.2/0.9 (0.4-4, 0.1), `FILL_R` 22/20/18 (5-60, 1), `DRAIN_R` 12/14/16 (2-60, 1) |
| Dodge | `WINDOW` 0.35 (0.1-0.4, 0.05); `MIN_TELEGRAPH` 0.8 (0.8-3, 0.05); `BOOST_SECONDS` 1 (0.3-2, 0.1); `BOOST_MULTIPLIER` 1.35 (1-1.6, 0.05); `BOOST_CAP` 26 (16-28, 1); `SUCCESS_COOLDOWN` 0.6 (0.2-5, 0.1); `MISS_COOLDOWN` 1.2 (0.5-5, 0.1); `SPAM_LIMIT` 4 (2-10, 1); `SPAM_SECONDS` 1 (0.5-3, 0.1); `SPAM_LOCKOUT` 2 (0.5-5, 0.5); `LATE_MEMORY` 0.6 (0.1-2, 0.1) |
| BatKnock | `COOLDOWN` 5 (3-30, 0.5); `RAGDOLL_SECONDS` 1.2 (0.5-2, 0.1); `IMMUNITY` 3 (ragdoll+1 to 15, 0.5); `IMPULSE` 45 (10-60, 5); `LIFT` 20 (0-35, 1) |
| Dusk | `SPEED_MULTIPLIER` 1.08 (1-1.15, 0.01); `ROLL_MULTIPLIER` 1.25 (1-1.5, 0.05); `DETECTION_MULTIPLIER` 1.1 (1-1.25, 0.05); `NIGHT_SOON` 20 (5-60, 1) |

Each module also clamps every override, so a panel range wider than these can still never break a floor.

## Wiring tasks for the Studio writer

1. Verify the Studio instance and place, get the user's confirmation, and create the Explorer paths above with fresh clones of the modules and suites. Run all five suites, record the real RED (already passed, no runtime offline) and GREEN results, and fix any failure before wiring.
2. Arrullo: in the capture flow, rare eggs (Rara and up) open an Arrullo session instead of the ring, with a `RemoteEvent` that carries only `"hold"` or `"release"`. The server advances the session on Heartbeat and replicates the view at about 10 Hz to that player only. A win claims the egg and a loss ends the steal, which then works like a failed ring (noise, wake meter). Build a touch button (hold) plus Space or the gamepad A button. The UI must be readable on a phone.
3. Dodge: register a telegraph in each of the four attack paths (parent close swing, Viper dash, Pouncer leap, La Silueta lunge) with the server strike time. Before applying a hit, call `Dodge.resolve` and skip the hit on `Dodged`. Feed `Dodge.speed` into the WalkSpeed composition where `Stamina.speed(..., bursting)` sits. Pass `blocked` while hidden, capturing, ragdolled or dead. Retire the Burst button and remote, and keep a touch "Esquivar" button. Prune on Heartbeat.
4. Bat: route `Swing` through `Knock.swing` (with the attacker's root position and the safe zones) and the hit through `Knock.knock`. Apply the impulse through the target's client, which owns its character's network: fire it to that client, which sets `AssemblyLinearVelocity` and the `Physics` state for `ragdoll` seconds. That client also clamps to the same cap. The server rechecks the travel and teleports the player back if they moved more than `MAX_FLIGHT + 10`. On `drop`, call `Heist.dropEgg(player, "Hit")`. Update the Bat suite's pinned numbers (12 s, 6 s, 0.45 s), which it owns.
5. Totems: in `WildboundRecord`, set `SCHEMA = TotemRecord.SCHEMA` and `MIGRATIONS = TotemRecord.ladder(...)`, add `totems` to `KNOWN` and `blank()`, call `TotemRecord.validate` in `validate`, and call the profile seam in `fromProfile` and `toProfile`. Update `WildboundRecord_Test` (schema 3 to 4, the expected migrated shape). Route a purchase through Persistence's ledgered transaction (atomic, idempotent by operation id) and only after the user approves the price. Esencia only.
6. Dusk: on the server's cycle loop, keep one `Dusk.new()` and send `enteredDusk` and `nightSoon` to every player (a HUD notice). Multiply the beast director's roll, the beast speeds and the detection ranges by `buff`.
7. Add the tuning rows above to `WildboundTuningSchema` and its suite, and map the five systems in the tuning bridge.
8. Playtest on desktop and phone: Arrullo is winnable at each rarity, the dodge timing is fair with real latency, a knock stays inside about 24 studs and never in the hub, a totem survives a rejoin, and both dusk lines show.
