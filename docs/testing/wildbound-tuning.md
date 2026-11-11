# Wildbound dev tuning

How developers tune La Silueta, sprint, carrying, the islands, capture, hiding and the camera feel live, without a code change for every try.

## Where the values live

| What | Where |
| --- | --- |
| The live values | `ReplicatedStorage.WildboundTuning` (a `Configuration`), one child `Configuration` per system: `Silueta`, `Sprint`, `Carry`, `Islands`, `Capture`, `Hide`, `World`, `Gear`, `Eggs`, `PvP`, `Incubator`, `Camera`, `Training`, `Companion`. Every value is an attribute on its system. |
| Labels, ranges, steps, defaults | `src/wildbound/WildboundTuningSchema.luau` (`ReplicatedStorage.WildboundTuningSchema`) |
| The defaults (source of truth) | The modules themselves: `Stamina.CONSTANTS`, `Island.CONSTANTS`, the `DAY`, `TWILIGHT` and Night profiles and `Brain.NOISE` in `WildboundGuardianBrain`, `Rules.*` in `WildboundWorldRules`, `Hide.CONFIG`, `Carry.CONFIG`, `CaptureSession.CONSTANTS`, `EggCarry.CONSTANTS`, `Bat.CONSTANTS`, `View.CONSTANTS` in `WildboundHudView`, `Incubator.CONSTANTS` |
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
| Silueta | patrol, hunt speed, sight radius, memory and (fix pass FP3) chase limit per phase (Day, Twilight = dusk and dawn, Night); `GIVE_UP_DISTANCE`; `CHASE_LEASH` (at least 80, the territory); `TELEGRAPH_SECONDS` (at least 0.8, the fair-strike warning lead); `ATTACK_COOLDOWN`; fix pass: `MAX_HUNTERS` (1 to 16, default 8: one Silueta per player, a later player takes a freed slot); FP4 moves (`WildboundSiluetaMoves`): `LUNGE_ON`, `LUNGE_AFTER`, `LUNGE_TELL` (at least 0.35), `LUNGE_SECONDS`, `LUNGE_SPEED`, `LUNGE_COOLDOWN`, `FAKE_ON`, `FAKE_CHANCE`, `FAKE_SECONDS`, `GLARE_ON`, `GLARE_RANGE`, `GLARE_DOT`, `GLARE_HOLD`, `GLARE_STAGGER`, `SCREAM_ON`, `SCREAM_REACH` (each `_ON` is 1 on, 0 off) |
| Sprint | `SPRINT_MULTIPLIER`, `SPEED_CAP`, `DRAIN`, `START`, `RECOVER`, `REGEN_DELAY`, `REGEN_WALK`, `REGEN_STILL`, `NOISE_INTERVAL`, `SPRINT_NOISE` (hearing radius of a sprint); Nest Heist NH4, the Burst ("Impulso"): `BURST_SECONDS` (0.8), `BURST_MULTIPLIER` (1.7 of the walk speed, never stacked on the sprint), `BURST_COOLDOWN` (6 s from its start), `BURST_CAP` (28 studs/s) |
| Carry | `FEAR_RISE`, `FEAR_FALL`, `FEAR_WARN`, `FEAR_SLIP` (the slip), `FEAR_RADIUS`, `UNEASY_RADIUS`, `CRY_EVERY` |
| Islands | `STIR`, `WAKE` (at least 96, above island 1's first-steal cap 95), `LINGER`, `SPRINT`, `LIGHT`, `DECAY`, `ALERT_SECONDS`, `GRAB` (the noise of lifting a cría or an egg), `WAKE_WINDUP`, `CHASE_SPEED`, `CHASE_SECONDS`, `CHASE_LEASH`, `STRIKE_REACH`, `STRIKE_WINDUP` (0.8, at least 0.8 s since HF-T4: the fair-strike floor), `HIT_RANGE`, `STRIKE_COOLDOWN`, `DAMAGE`; fix pass FP5: `PACK_CALL_SECONDS`, `POUNCE_ON`, `POUNCE_RANGE`, `POUNCE_AFTER`, `POUNCE_TELL` (at least 0.8 since Nest Heist NH3: the pounce became the charge), `POUNCE_COOLDOWN`, NH3 `CHARGE_SPEED` (40), `CHARGE_OVERSHOOT` (4), `CHARGE_MAX` (18), `CHARGE_HIT` (3), `EXPOSED_SECONDS` (1), `STEAL_WAKE` (1: an egg steal wakes the island at once), NH5 `PERCEIVE_RANGE` (24: a chasing adult turns on a new egg carrier only this close), `EGG_RECOVERY_ON`, `DEEP_SLEEP_ON`, `DEEP_SCALE`, `DEEP_FROM`, `DEEP_TO`, and on the client `BREATH_AMPLITUDE`, `BREATH_SECONDS`, `BREATH_DEEP_SECONDS` |
| Capture | `CALM_REQUIRED` (at least 4), `TIME_LIMIT`, `RING_SPEED`, `OUTSIDE_LIMIT`, `SEAL_SWEEP`, `SEAL_BAND`, `SEAL_LATENCY`, `RETRY_COOLDOWN` (at least 3); a running capture keeps the deadline, calm and seal it started with |
| Hide | discover radius and dwell per phase, `CRY_WIDEN`, `MAX_STAY`, `COOLDOWN` |
| World | Random world (plan Parts 3 and 6, `WildboundSpawnClock` and `WildboundWaveClock`): `LIFETIME` (300: a random egg or cria moves after it; a shorter value reaches the spawns already out), `RESPAWN_COMUN`, `RESPAWN_RARA`, `RESPAWN_EPICA`, `RESPAWN_LEGENDARIA` (90, 150, 240, 360 after a claim), `MAX_COMUN`, `MAX_RARA`, `MAX_EPICA`, `MAX_LEGENDARIA` (4, 3, 2, 1 at once), `EGG_SHARE` (0.4); `WAVE_SECONDS` (300, at least 10; counts from the current wave's start), `FIRST_EGG_RADIUS` (70 studs from camp), `REFUGE_MIN`, `REFUGE_MAX` (2, 3), `REFUGE_RADIUS` (12, 4 to 15; a circle that would reach the territory is refused), `REFUGE_REGEN` (2), `EVENT_FIRST` (300), `EVENT_EVERY` (1200), `EVENT_SECONDS` (300), `EVENT_RADIUS` (45 studs from La Silueta's home), `VARIANT_EVERY_WAVES` (1). A wave already running keeps the end its clients were sent |
| Gear | Gloves and the luck totem (Nest Heist Phase 3 NS7, `WildboundGear`, "Guantes y tótem"; the IT1 equipment values are gone): the per-stat caps in percent, each bounded again by `WildboundGear.HARD_CAPS`: `MOVE_CAP` (3, 0 to 3: walk speed, under `Training.WALK_CAP` with training), `STEAL_CAP` (15, 0 to 25: egg steal hold, never under 0.6 s), `BURST_CAP` (20, 0 to 30: Burst cooldown, never under half), `DRAIN_CAP` (30, 0 to 40: sprint drain), `CALM_CAP` (30, 0 to 40: capture calm speed, never under `CALM_MIN`); the rarity weights `WEIGHT_COMUN` (60), `WEIGHT_RARA` (28), `WEIGHT_EPICA` (10), `WEIGHT_LEGENDARIA` (2); the Tótem de la suerte: `LUCK_SECONDS` (60), `LUCK_RADIUS` (40 studs), `LUCK_NOISE_EVERY` (10 s, a capture-ring noise), `LUCK_LURE` (1: it draws one spawn into its radius at once; 0: it only waits for the clock's next spawn), `LUCK_CAMP` (30 studs from the camp centre at least). A lower cap also lowers an already rolled glove's effect. The recipes' prices are in the economy config, not here |
| Training | The camp treadmill (Nest Heist Phase 3 NS5, `WildboundTraining`, "Entrenamiento"): `WALK_STEP` (0.25 studs/s per level, 0 to 1), `MAX_LEVEL` (4, 0 to 10), `WALK_CAP` (16, 16 to 16.5 since HF-T4, user decision Q9: the unencumbered walk ceiling for training and a glove together, under La Silueta's night hunt 17; sprint 24 and Burst 28 keep the stamina caps), `BASE_COST` (30 Esencia, 0 to 500), `COST_GROWTH` (1.6, 1 to 3: prices 30, 48, 77, 123) |
| Companion | The equipped companion's light (Nest Heist Phase 3 NS4, `WildboundRefuge.LIGHT`, "Compañero"): `LIGHT_BRIGHTNESS` (1.2, 0 to 5), `LIGHT_RANGE` (12 studs, 0 to 30). Applied on the next refresh of the companion |
| Eggs | Nest Heist (`WildboundEggCarry`, "Robo de huevos"): `STEAL_HOLD` (0.8 s, 0.6 to 1: a Común or Rara egg's steal hold), `RARE_HOLD` (1 s: an Épica, Legendaria or event egg; never under the steal hold), `PICKUP_DELAY` (0.4 s before a dropped egg can be picked up), `PICKUP_HOLD` (0.4 s, 0.3 to 0.5), `PICKUP_RANGE` (10 studs, at most 10: `State:takeEgg` refuses a pickup beyond 10, Nest Heist phase 2 NP1), `DROP_SECONDS` (30 s before an abandoned egg fades). A prompt's hold is set when its egg spawns, so a new value reaches the next eggs |
| PvP | Nest Heist phase 2, the bat (`WildboundBat`, "Bate entre jugadores"): `COOLDOWN` (12 s from a swing, spent on a miss; at least 3), `REACH` (6 studs root to root, 3 to 8), `HALF_ANGLE` (60 degrees either side of the facing), `HEIGHT` (4 studs), `STUMBLE_SECONDS` (0.45 s, an egg carrier hit; the egg drops), `TAP_SECONDS` (0.2 s, anyone else; never longer than the stumble), `STUMBLE_SPEED` (2 studs/s while stumbling), `IMMUNITY` (6 s with no new PvP stumble after one; always outlasts the stumble). No gear changes any of them |
| Incubator | `HATCH_SECONDS` (10 to 900, default 90): from an egg going into the incubator to the creature hatching (next batch NB4, `docs/mechanics/wildbound-incubator.md`); an egg already incubating keeps its time |
| Camera (client) | `SPRINT_FOV_KICK`, `DREAD_RANGE`, `DREAD_SHAKE`, `DREAD_VIGNETTE`; fear pass: `FEAR_SECONDS` (the burst after a grab), `FEAR_SHAKE`, `FEAR_FOV` (the punch), `HIT_FLASH`, `HEART_RANGE` (the heartbeat's reach), `KNOCKBACK` (an adult hit's push, applied by the client); stalk sightings: `STALK_EVERY`, `STALK_COOLDOWN`, `STALK_PER_NIGHT`, `STALK_MIN`, `STALK_MAX` (the distance band), `STALK_SECONDS`, `STALK_NEAR`; fix pass: `OTHER_SILUETA_FADE` (0 to 1, default 0.75: how faint another player's Silueta is drawn on this client; 1 hides it) |

Not exposed on purpose: the territory (`HOME_LEASH`), La Silueta's strike range and damage, the island positions, the economy (it has its own generated config and simulator), and La Silueta's art scale (applied when its model is built, not live).

## Security

- The panel is built only when the server set `Player.WildboundTuningDev = true`: in Studio, or on the private place 122652861404212 for the place owner (user, or rank 255 of the owning group) or a user id in `ALLOWLIST` in `WildboundTuning.server.luau`. Regular players never get the interface.
- Every change goes through `ReplicatedStorage.WildboundTuningRequest` (a `RemoteFunction`). The server checks, in order: no extra arguments, the per-player rate limit (burst 20, 10 per second), the caller is a developer (decided on the server again, never from the client's attribute), the action (`set` or `reset`), the system and key exist, the value is a finite number, and it is inside the range (out of range is refused, not clamped). Anything else is refused, counted (`Tuning_rejected` on `ServerStorage.WildboundTelemetry`) and logged with a `warn` at most once a second per player.
- A server never calls the client. The server writes the attribute; every client follows it.
- To check the refusal in Studio, put a `BoolValue` named `TuningSimulateNonDev` in `ServerStorage.WildboundTelemetry` during Play: every request then acts as a stranger's on the public place. Remove it afterwards.
