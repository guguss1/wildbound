# Wildbound dev tuning

How developers tune La Silueta, sprint, carrying, the islands, capture, hiding and the camera feel live, without a code change for every try.

## Where the values live

| What | Where |
| --- | --- |
| The live values | `ReplicatedStorage.WildboundTuning` (a `Configuration`), one child `Configuration` per system: `Silueta`, `Sprint`, `Carry`, `Islands`, `Capture`, `Hide`, `Incubator`, `Camera`. Every value is an attribute on its system. |
| Labels, ranges, steps, defaults | `src/wildbound/WildboundTuningSchema.luau` (`ReplicatedStorage.WildboundTuningSchema`) |
| The defaults (source of truth) | The modules themselves: `Stamina.CONSTANTS`, `Island.CONSTANTS`, the `DAY`, `TWILIGHT` and Night profiles and `Brain.NOISE` in `WildboundGuardianBrain`, `Rules.*` in `WildboundWorldRules`, `Hide.CONFIG`, `Carry.CONFIG`, `CaptureSession.CONSTANTS`, `View.CONSTANTS` in `WildboundHudView`, `Incubator.CONSTANTS` |
| Server bridge | `src/wildbound/WildboundTuning.server.luau` (`ServerScriptService.WildboundTuning`) |
| Developer panel | `src/wildbound/WildboundTuning.client.luau` (`StarterPlayer.StarterPlayerScripts.WildboundTuningClient`) |

`WildboundTuning_Test` fails if a schema default and the module default diverge, so the two cannot drift. Change a default in the module, then the matching `default` in the schema.

The folder is created by the server bridge at Play start (`Schema.ensureFolder`) and also exists in the place for Edit-mode editing. To rebuild it in Edit, run in the command bar:

```lua
require(game.ReplicatedStorage.WildboundTuningSchema).ensureFolder(game.ReplicatedStorage)
```

It only adds missing systems and attributes; values already there are kept.

## Tune during Play (nothing persists)

Two ways, both apply at once with no restart:

1. **The panel.** Press **F8** or tap **Ajustes dev** (left edge). Tap a system to expand it. Each value has a slider (the thin mark is the repo default), `−` and `+` buttons (one step) and a box to type an exact number. Amber means "different from the repo default"; the system header counts them. **Restablecer** returns every value to the repo default. **Copiar valores** opens the export box.
2. **Properties.** In Studio, switch the Play view to **Server** (Home or Test tab, "Current: Server"), select `ReplicatedStorage > WildboundTuning > <system>` and edit an attribute. Values read on the server must be edited in the Server view; an edit in the Client view only reaches that client (only the `Camera` system is read on the client).

**Play-mode edits are lost when Play stops.** Export them first.

## Keep good values

1. Press **Copiar valores**. The box first lists every changed value with its file, then shows a Luau table, one line per value, with `-- CHANGED (default X)` on the values you changed and, above each group, the file that holds the default. Roblox cannot write the clipboard: click the box, Ctrl+A, Ctrl+C.
2. Paste the changed numbers into the named module default (for example `SPRINT_MULTIPLIER = 1.45` in `Stamina.CONSTANTS`).
3. Change the same `default` in `WildboundTuningSchema.luau`.
4. Update the tests that pin the old number on purpose (mark the change in the test), run the suites, and commit. `tools/simulate_economy.py` and `tools/simulate_silueta_pressure.py` read the module source, so they see the new default; they never see live tuning.

## Edit mode: values persist in the place

An attribute edited in Edit mode is saved with the place and applies to every server, including players on the published place. That is how a team can try a value for longer, but the place then differs from the repo. To keep that visible:

- the server prints, at start, every value that differs from the repo defaults (`WildboundTuning: N value(s) differ from the repo defaults: ...`);
- the panel shows those values in amber with the repo number.

If the repo default later changes, a stale Edit-mode attribute still wins in that place: reset it (panel **Restablecer**, or delete the attribute, then run `ensureFolder` again). The fear pass hit this: the place's folder still held `CHASE_SPEED` 17, `WAKE_WINDUP` 0.6 and `CHASE_SECONDS` 10 after the defaults changed; they were set to the new defaults in Edit and `ensureFolder` added the new keys (0 values differ afterwards).

## Values

Ranges are clamps: an attribute outside its range is clamped (and written back, so Properties shows what applies); a non-number is ignored and the default applies. Every value is read on the server except the `Camera` system.

| System | Values |
| --- | --- |
| Silueta | patrol, hunt speed, sight radius and memory per phase (Day, Twilight = dusk and dawn, Night); `GIVE_UP_DISTANCE`; `CHASE_LEASH` (at least 80, the territory); `TELEGRAPH_SECONDS` (at least 0.8, the fair-strike warning lead); `ATTACK_COOLDOWN`; fix pass: `MAX_HUNTERS` (1 to 16, default 8: one Silueta per player, a later player takes a freed slot) |
| Sprint | `SPRINT_MULTIPLIER`, `SPEED_CAP`, `DRAIN`, `START`, `RECOVER`, `REGEN_DELAY`, `REGEN_WALK`, `REGEN_STILL`, `NOISE_INTERVAL`, `SPRINT_NOISE` (hearing radius of a sprint) |
| Carry | `FEAR_RISE`, `FEAR_FALL`, `FEAR_WARN`, `FEAR_SLIP` (the slip), `FEAR_RADIUS`, `UNEASY_RADIUS`, `CRY_EVERY` |
| Islands | `STIR`, `WAKE` (at least 96, above island 1's first-steal cap 95), `LINGER`, `SPRINT`, `LIGHT`, `DECAY`, `ALERT_SECONDS`, `GRAB` (the noise of lifting a cría or an egg), `WAKE_WINDUP`, `CHASE_SPEED`, `CHASE_SECONDS`, `CHASE_LEASH`, `STRIKE_REACH`, `STRIKE_WINDUP` (at least 0.35 s), `HIT_RANGE`, `STRIKE_COOLDOWN`, `DAMAGE` |
| Capture | `CALM_REQUIRED` (at least 4), `TIME_LIMIT`, `RING_SPEED`, `OUTSIDE_LIMIT`, `SEAL_SWEEP`, `SEAL_BAND`, `SEAL_LATENCY`, `RETRY_COOLDOWN` (at least 3); a running capture keeps the deadline, calm and seal it started with |
| Hide | discover radius and dwell per phase, `CRY_WIDEN`, `MAX_STAY`, `COOLDOWN` |
| Incubator | `HATCH_SECONDS` (10 to 900, default 90): from an egg going into the incubator to the creature hatching (next batch NB4, `docs/mechanics/wildbound-incubator.md`); an egg already incubating keeps its time |
| Camera (client) | `SPRINT_FOV_KICK`, `DREAD_RANGE`, `DREAD_SHAKE`, `DREAD_VIGNETTE`; fear pass: `FEAR_SECONDS` (the burst after a grab), `FEAR_SHAKE`, `FEAR_FOV` (the punch), `HIT_FLASH`, `HEART_RANGE` (the heartbeat's reach), `KNOCKBACK` (an adult hit's push, applied by the client); stalk sightings: `STALK_EVERY`, `STALK_COOLDOWN`, `STALK_PER_NIGHT`, `STALK_MIN`, `STALK_MAX` (the distance band), `STALK_SECONDS`, `STALK_NEAR`; fix pass: `OTHER_SILUETA_FADE` (0 to 1, default 0.75: how faint another player's Silueta is drawn on this client; 1 hides it) |

Not exposed on purpose: the territory (`HOME_LEASH`), La Silueta's strike range and damage, the island positions, the economy (it has its own generated config and simulator), and La Silueta's art scale (applied when its model is built, not live).

## Security

- The panel is built only when the server set `Player.WildboundTuningDev = true`: in Studio, or on the private place 122652861404212 for the place owner (user, or rank 255 of the owning group) or a user id in `ALLOWLIST` in `WildboundTuning.server.luau`. Regular players never get the interface.
- Every change goes through `ReplicatedStorage.WildboundTuningRequest` (a `RemoteFunction`). The server checks, in order: no extra arguments, the per-player rate limit (burst 20, 10 per second), the caller is a developer (decided on the server again, never from the client's attribute), the action (`set` or `reset`), the system and key exist, the value is a finite number, and it is inside the range (out of range is refused, not clamped). Anything else is refused, counted (`Tuning_rejected` on `ServerStorage.WildboundTelemetry`) and logged with a `warn` at most once a second per player.
- A server never calls the client. The server writes the attribute; every client follows it.
- To check the refusal in Studio, put a `BoolValue` named `TuningSimulateNonDev` in `ServerStorage.WildboundTelemetry` during Play: every request then acts as a stranger's on the public place. Remove it afterwards.
