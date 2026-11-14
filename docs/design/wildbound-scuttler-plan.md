# Wildbound: Scuttler implementation plan

Status: **Design only** (plan, nothing built). Source: the user's Scuttler pack (`Scuttler_Pack_Wildbound.zip`, received 2026-11-14), read as design input. Every number below is a PROPUESTA to tune in Studio unless it is marked as an existing value.

## Quick path

- Scuttler is a **global beast, threat 3**: it fills the whole per-player budget (`DIRECTOR.MAX_POINTS = 3`), so while it hunts no other beast can start.
- It is built as a **wave 2 behaviour** (`WildboundBeastScuttler`, registered with `WildboundBeastEncounters`), reusing `WildboundBeastAttack` (tells, one outcome per attack), `WildboundDodge` (perfect window, Early/miss cooldown) and the beast script's world adapter. No second scheduler, no second dodge, no second drop path.
- Its 4 mechanics map to existing systems: **Ruta predictiva** = velocity lead (Pouncer's `predictSeconds` idea) plus a drawn intercept zone; **Finta de caza** = an unregistered fake tell, then a real registered charge; the early press is read from the server attribute `WildboundDash` that `WildboundDodgeService.press` already sets; **Pulso de pánico** = a dodgeable circle that slows (Root's `applySlow`) through a new non-hit outcome; **Castigo y caída** = Streamer/Lurker's "perfect dodge -> stun", with a longer fall when the overrun meets a wall (Viper's `castLane` crash).
- Spawn: **uniform, no biome preference** (owner, 2026-11-14), like every global beast under `Config.BIOME_PREFERENCE = false`. The pack's "more common near return routes and dense vegetation" becomes a later toggle, off by default.
- Art: Part proxy first (`Proxies.scuttler`), then a Blender rig with baked clips (`WildboundBeastAnimScuttler`, the Lumipol approach, no animation upload). Uploading the mesh needs the user's explicit approval.

## 1. Goal

Add a fourth kind of chase: a big, readable, slightly unsettling insect that **reads the player** instead of only running at them. It rewards patience and timing (waiting for the real tell, the perfect dodge) and punishes panic (dashing at the first red line). It must stay kids-friendly: every hit is telegraphed for at least 0.8 s, the pulse never deals damage, and a skilled player always has an out.

Success for the first playable: in solo Play, a player who reads the tells can survive a full Scuttler encounter without being hit, can make it fall at least once with a perfect dodge, and can tell a feint from a real charge after one or two encounters.

## 2. What exists today (verified in the repo, 2026-11-14)

| System | File | What Scuttler reuses |
| --- | --- | --- |
| Beast numbers and shapes | `WildboundBeastConfig` | A `BEASTS.Scuttler` entry with a `tuning` table; `ORDER`, `PLAYABLE`, `WAVE2`; shapes `lane`, `circle`, `sector`, `multi` and `shapeHit` (what is drawn is the hit volume) |
| Biome switch | `WildboundBeastConfig` (working tree, parallel task) | `Config.BIOME_PREFERENCE = false`, `Config.homeBiome`, `Config.categoryOf`. Scuttler is `Global` with `biome = nil`, so it rolls anywhere except safe zones and `NO_GLOBAL_BIOMES` (Pradera) |
| Director | `WildboundBeastDirector` | Calendar slot (20 s, 1 s offset per `ORDER` index), `check` (budget, `MAX_ACTIVE`, cooldowns, `siluetaActive`), atomic `reserve`, `release` once. A beast that cannot start does not roll |
| Encounter host | `WildboundBeastEncounters` | `Enc.register(name, { init, step })`, `MAX_DT`, End handling |
| Attack layer | `WildboundBeastAttack` | `phase`, `walk`, `face`, `guard` (death, safe zone, escape, timeout), `open` (tell + dodge registration + `claimStrike` stagger), `aim`, `lock`, `hit`, `miss`, `drop`, `closeAll`, `inside` |
| Perfect dodge | `WildboundDodge`, `WildboundDodgeService` | `WINDOW 0.35`, `MIN_TELEGRAPH 0.8`, `MISS_COOLDOWN 1.2`, `SUCCESS_COOLDOWN 0.6`, `DASH_SPEED 52` for `DASH_DURATION 0.22` (about 11 studs), `DASH_IFRAMES 0.28`. `Service.press` sets the server attribute `WildboundDash = now` on every Perfect, Early, Late or Whiff press. `Dodge.SOURCES` lists the sources allowed to register |
| Fair strike | `WildboundFairStrike` | `WARNING_LEAD 0.8` floor (`Config.MIN_TELL`), `MARKED_HEALTH 35` |
| Stamina | `WildboundStamina` | Rested sprint `SPRINT_MULTIPLIER 1.45`, cap 24 (about 23.2 studs/s); the old Burst is replaced by the dodge |
| Beast script | `WildboundBeasts.server.luau` | `worldFor(player)` (telegraph, resolve, cancel, claimStrike, reposition), `castLane`, `landing`, `lineOfSight`, `safe`, `spawnSpec`/`spawnPoint`, `applySlow` (clamped 0.5..1, at most 3 s, never stacks), `landHit` -> `BeastHit` |
| Hit and egg | `WildboundServer` `BeastHit` (lock zone, read only) | Any `Hit` calls `Heist.dropEgg(player, "Hit")`; damage only in private mode. Damage 0 is accepted (`damage >= 0`) |
| Client | `WildboundBeasts.client.luau`, `WildboundBeastAnim.client.luau`, `WildboundBeastAnimPlan`, `WildboundBeastProxies` | Generic `Phase`/`Tell`/`Strike` drawing for wave 2, `shake`, stun stars, phase text from `Text.BEAST.<beast>.phases`, baked bone clips |
| Audio | `WildboundAudioCatalog` | Existing slots only (see section 9) |

Two observations that affect the plan:

- The dodge **press handler is not in `src/wildbound`** outside the lock zone (only `WildboundDodgeService.press` exists; the beast script header says the inventory server calls it). Scuttler only reads the attribute it sets, so no lock-zone change is needed, but SC1 checks in Studio that a live press really moves `WildboundDash`.
- Encounters are **target-only**: the beast script fires `BeastEvent` to the target's client alone, so other players do not see the target's beast. SC0 makes beasts visible to nearby players; the pack's "affects nearby players" for the pulse stays target-only (Q4 decided).
- Pack images: the file names do not match their content (`02_Ruta_Predictiva.png` shows Castigo y caída, `03_Finta_de_Caza.png` shows Ruta predictiva, `04_Pulso_de_Panico.png` shows Finta, `05_Castigo_y_Caida.png` shows Pulso). Use the titles inside the images.

## 3. The four mechanics mapped to existing systems

### 3.1 Ruta predictiva (route read and intercept)

Reads the target's server velocity (`target.vx, vz`, already passed by `targetOf`) and moves ahead of it instead of behind it.

1. **Read** (phase `Read`, `ReadSeconds`): Scuttler stops, antennas glow (client), and samples the target's flat velocity. No damage.
2. **Choose**: predicted point `P = target + v * PredictSeconds`, clamped to `InterceptMaxStuds` ahead. `P` must be valid ground (`world.landing`), outside safe zones (`world.safe`), with a clear line from Scuttler (`world.lineOfSight`). Scuttler commits only if it arrives first: `ETA(Scuttler -> P) + InterceptMarginSeconds < ETA(target -> P)`. Otherwise it falls back to `Pursue` (no secret shortcut, never a teleport).
3. **Intercept** (phase `Intercept`): it runs to `P` at `InterceptSpeed` (below a rested sprint, so sprinting away always works). The client draws the **intercept zone** (a red hatched rectangle across the predicted path, shape `lane` or `circle`) from the start of the phase, at least `MIN_TELL` before Scuttler can strike from it.
4. **Block** (phase `Block`, `BlockSeconds`): it stands in the zone, facing the target. Entering the zone opens a **Snap** (a `sector` swipe, dodgeable, `SnapTelegraphSeconds >= 0.9`). Turning back, going around or waiting is safe.
5. **Dash interaction** ("Dash temprano = te lee"): a press during `Read` or `Intercept` triggers one re-plan with the new velocity (`ReplanCooldownSeconds`, at most `MaxReplans` per intercept), so a panicked dash toward the old route is read; a late route change is the better answer, as the pack says.

Reuse: Pouncer's velocity lead (`predictSeconds` in `landingFor`), `world.landing/safe/lineOfSight`, `Attack.open` for the Snap. Bottleneck detection (snapping `P` to narrow passages) is **not** in v1: it needs map data that does not exist yet; it goes with the later spawn-bias toggle.

### 3.2 Finta de caza (feint charge)

1. **Feint** (phase `FeintTell`, `FeintSeconds`): Scuttler crouches and draws a charge lane exactly like a real one, but the attack is **not registered** with the dodge (`dodgeable = false`, no `world.telegraph`), deals nothing, and never moves its body along the lane. The HUD's "¡Esquiva!" cue fires only from `WildboundDodgeStrike`, which only registered attacks set, so a player who waits for the cue never takes the bait. The feint lane is also drawn as an outline without fill and without the antenna flash (the "tell" of a real charge).
2. **Bait check**: the server reads the target's `WildboundDash` attribute (server-written by `DodgeService.press`; a client cannot replicate an attribute change). A press time inside `[feintStart, feintEnd]` means the bait was taken. The press itself already did the punishing: it was Early or Whiff, so `MISS_COOLDOWN` (1.2 s) is running.
3. **Punish charge** (bait taken): Scuttler re-aims at the target's new position and opens the **real** charge immediately, with `PunishTelegraphSeconds` (0.9 s, above the 0.8 floor). The player's dodge button is likely still cooling down, so the answer is to **step out of the lane**; never unavoidable.
4. **Committed charge** (bait not taken): Scuttler opens the real charge with the normal `ChargeTelegraphSeconds`. A perfect dodge here is the Castigo y caída trigger.
5. Limits: the first charge of an encounter is **never** a feint (teach the real tell first); never two feints in a row; `FeintChance` per later charge; at most `MaxFeintsWhileEgg` feints per encounter while the target carries an egg.

Reuse: `Attack.open/aim/lock/hit/miss` (Streamer's rush is the template for the real charge), `Dodge` miss cooldown as the punishment, `WildboundDash` as the detector. New: one adapter function `world.lastDash()` in `worldFor(player)` that returns `player:GetAttribute("WildboundDash")`.

### 3.3 Pulso de pánico (panic pulse)

1. **Charge** (phase `PulseCharge`, `PulseChargeSeconds`): Scuttler rears up; the client draws the real ring (`circle`, `PulseRadiusStuds`) from the start, plus antenna and mouth glow.
2. **Pulse**: one radial check at the strike against the drawn ring. The attack is registered with the dodge (a perfect press cancels it), and stepping or dashing out of the ring also avoids it (the pack's "dash lateral").
3. **Effect on a landed pulse**: no damage. A slow (`PulseSlowMultiplier` for `PulseSlowSeconds`, through the existing `applySlow`, which never stacks) and a client camera shake and short desaturation (`shake`, skipped by "Efectos suaves" like every other shake). No control inversion, no camera steal.
4. **Egg risk** ("si ya estabas en mal estado"): "bad state" is defined server-side as **already pulsed within `PressureMemorySeconds`**. The second landed pulse inside that memory is escalated to a `Hit` with damage 0, so the egg drops through the one existing path (`BeastHit` -> `Heist.dropEgg(player, "Hit")`), no lock-zone change. Behind the switch `PulseCanDropEgg` (**on**, Q2 decided by the user). `MARKED_HEALTH` is not used: health only drops in private mode, so it cannot define "bad state" everywhere.

New code needed outside the lock zone: today every `Hit` event reaches `BeastHit` and drops the egg, so a non-damaging effect needs its own outcome. Add `Attack.afflict(events, e, world, attack, now, fields)`: the same dodge resolution as `Attack.hit`, but it emits `Strike` + `Afflict` (not `Hit`). The beast script handles `Afflict` by calling `applySlow` only (and telling the client to shake), never `BeastHit`.

### 3.4 Castigo y caída (overrun and fall)

1. Only **committed charges** (section 3.2 step 4) and **punish charges** can end in a fall; the Snap and the pulse cannot.
2. When `Attack.hit` returns `"Dodged"` for a charge (a validated perfect press held the window at contact), Scuttler overruns `OverrunStuds` past the end of its lane along the same line (no homing). If `world.castLane` finds a wall inside the overrun, it **crashes** (`FallCrashSeconds`); otherwise it **stumbles** (`FallStumbleSeconds`). Either phase is `Fallen`, with stars and the "¡Se cayó! Escapa ahora." line.
3. A missed charge (nobody inside the lane) only gets the short `ChargeMissRecoverySeconds`, as Streamer's `RushMissRecoverySeconds`.
4. Reward: the escape window, plus the dodge's own boost (`BOOST_MULTIPLIER 1.35` for 1 s, existing). After `FallsToGiveUp` falls in one encounter, Scuttler disengages with reason `Outplayed` (a clear, earned win). No coins or loot: economy stays unchanged.
5. While `Fallen`, Scuttler opens no attack, and its `claimStrike` claims are released.

Reuse: Streamer's `Stunned` and Lurker's `OverrunStunned` patterns, Viper's crash via `castLane`.

## 4. State machine (server)

```
Spawn -> Stalk (keeps 20..34 studs, faces target)
  -> choose next move (cooldown-gated, one at a time):
       Read -> Intercept -> Block [-> Snap] -> Stalk          (Ruta predictiva)
       FeintTell -> PunishTell -> Charge -> Recovery | Fallen  (Finta, bait taken)
       FeintTell -> ChargeTell -> Charge -> Recovery | Fallen  (Finta, bait refused)
       ChargeTell -> Charge -> Recovery | Fallen               (plain committed charge)
       PulseCharge -> Pulse -> Stalk                           (Pulso de pánico)
  -> Disengage (Escape, Timeout, Outplayed, EggDropped, Silueta) -> End
```

Move choice (PROPUESTA): the first move is always a plain committed charge; then the pulse when the target is within `PulseRadiusStuds + 4` and the pulse is ready; the intercept when the target moves faster than `InterceptMinSpeed` away from Scuttler; otherwise a charge (feint or real). Every move respects `Attack.guard` (death, safe zone, escape, timeout).

## 5. New modules and responsibilities

| Module | Place | Responsibility |
| --- | --- | --- |
| `WildboundBeastScuttler` (new) | `ServerScriptService` | Pure server brain, `init`/`step`, registered via `Enc.register("Scuttler", ...)`. Only returns events |
| `WildboundBeastAttack` (change) | `ServerScriptService` | Add `Attack.afflict` (non-hit outcome with dodge resolution) |
| `WildboundBeastConfig` (change) | `ReplicatedStorage` | `BEASTS.Scuttler` with `tuning`; add to `ORDER`, `PLAYABLE`, `WAVE2` |
| `WildboundDodge` (change) | `ReplicatedStorage` | Add `Scuttler = true` to `Dodge.SOURCES` |
| `WildboundBeasts.server.luau` (change) | `ServerScriptService` | Register Scuttler (the hard-coded list at line 28), `spawnSpec` entry, `world.lastDash` in `worldFor`, handle `Afflict` (slow + client shake), Silueta yield check, `Disengage` on egg drop |
| `WildboundBeastProxies` (change) | `ServerScriptService` | `Proxies.scuttler()`: a Part proxy of the low-poly insect (carapace plates, two big front claws, 6 legs, two glowing antennas, glowing eyes), pivot on the ground, head along -Z |
| `WildboundBeasts.client.luau` (change) | `StarterPlayerScripts` | Feint lane outline, intercept zone hatch, pulse rings, fall stars, antenna glow by phase, `TELL_COLOR.Scuttler` |
| `WildboundBeastAnimPlan` (change) | `ReplicatedStorage` | Phase -> clip plan for Scuttler |
| `WildboundBeastAnimScuttler` (new, generated) | `ReplicatedStorage` | Baked bone clips from the Blender rig (later task) |
| `WildboundText` (change) | `ReplicatedStorage` | `BEAST.Scuttler` warn, hit and phase lines (Spanish) |
| `WildboundBeastScuttler_Test` (new) | `ServerStorage` | Pure state-machine suite, same harness as `WildboundBeastStreamer_Test` |

Deploy: add `src/wildbound/WildboundBeastScuttler.luau -> ServerScriptService.WildboundBeastScuttler`, `src/wildbound/WildboundBeastAnimScuttler.luau -> ReplicatedStorage.WildboundBeastAnimScuttler` and `tests/WildboundBeastScuttler_Test.luau -> ServerStorage.WildboundBeastScuttler_Test` to `tools/deploy_manifest.py` `DEFAULT_MAPPINGS`, and their pins to `tools/test_deploy_manifest.py`.

## 6. Tunable parameters (PROPUESTA)

Scale: a Roblox avatar is about 5.5 studs for 1.7 m, so 1 stud is about 0.31 m and the pack's 5-6 m is 16-19 studs tall. The plan starts at **14 studs tall, about 16 studs wide**, so it still fits between forest trunks (Q1 decided: 12-14 studs tall).

| Key | Value | Why |
| --- | --- | --- |
| `points` | 3 | Pack; fills the budget alone |
| `chance10` | 1/60 (via `Config.perRoll`) | Rarer than Viper (1/45): a boss-like event. Already rare in practice because it only rolls with 0 points in use |
| `cooldown` (species) | 75 s | Longer than Viper 35 s, Pouncer 40 s |
| `spawnMin` / `spawnMax` | 40 / 75 studs | Viper's ring, a bit wider for the bigger body; hidden point preferred |
| `spawnSeconds` | 1.0 | Rise before any tell |
| `escapeDistance` / `escapeSeconds` / `disengage` | 110 / 4 / 1.2 | Viper's rules, slightly wider |
| `EncounterTimeoutSeconds` | 45 | Streamer's |
| `StalkMin` / `StalkMax` / `StalkSpeed` | 20 / 34 / 14 studs/s | Keeps a readable distance |
| `ReadSeconds` | 0.8 | The read is itself a tell |
| `PredictSeconds` | 1.2 | Lead on the target's velocity |
| `InterceptMaxStuds` | 30 | Never predicts far |
| `InterceptSpeed` | 21 studs/s | Below a rested sprint (about 23.2) |
| `InterceptMarginSeconds` | 0.4 | Commits only if it arrives clearly first |
| `InterceptMinSpeed` | 8 studs/s | Below this, no route to read |
| `BlockSeconds` | 2.5 | Then back to Stalk |
| `ReplanCooldownSeconds` / `MaxReplans` | 0.6 / 1 | One read of an early dash |
| `SnapTelegraphSeconds` / `SnapRadius` / `SnapArc` / `SnapDamage` | 0.9 / 10 / 100 deg / 20 | Dodgeable sector |
| `FeintSeconds` | 0.9 | As long as a real tell |
| `FeintChance` | 0.4 | Per charge after the first |
| `MaxFeintsWhileEgg` | 1 | Per encounter |
| `ChargeTelegraphSeconds` | 1.1 | Lane follows the target until `lockLead` |
| `PunishTelegraphSeconds` | 0.9 | Floor 0.8 |
| `lockLead` | 0.3 | Lane frozen in the last 0.3 s |
| `laneWidth` / `ChargeMaxRangeStuds` / `ChargeSpeed` | 8 / 40 / 46 studs/s | Wider than Viper's 4.5 (bigger body), slower than Viper's 60 |
| `ChargeDamage` | 30 | Private mode only (`BeastHit` rule) |
| `ChargeCooldownSeconds` | 4.5 | |
| `ChargeMissRecoverySeconds` | 1.2 | Streamer's |
| `OverrunStuds` | 8 | Lurker's 7, a bit longer |
| `FallStumbleSeconds` / `FallCrashSeconds` | 2.2 / 3.0 | Streamer's stun is 2.1 |
| `FallsToGiveUp` | 2 | Then `Outplayed` |
| `PulseChargeSeconds` | 1.3 | Time to leave the ring at walk speed |
| `PulseRadiusStuds` | 16 | Pack: about 5-6 m |
| `PulseSlowMultiplier` / `PulseSlowSeconds` | 0.75 / 1.5 | Inside `applySlow`'s clamps (0.5..1, at most 3 s) |
| `PulseCooldownSeconds` | 9 | |
| `PressureMemorySeconds` | 8 | Window for "bad state" |
| `PulseCanDropEgg` | true | Q2 decided by the user |
| `hitHeight` | 8 | Taller body |

## 7. Fairness rules

1. Every attack that can hurt (Snap, real charge, pulse) has a tell of at least `Config.MIN_TELL` (0.8 s) and is registered with `WildboundDodge`; a registration refused as `ShortTelegraph` is a test failure, not a silent undodgeable hit.
2. No unavoidable hit: every hit volume is exactly the drawn shape (`shapeHit`), the charge lane freezes `lockLead` before the commit, and leaving the shape always works, even with the dodge button cooling down.
3. The feint never deals damage, never registers with the dodge and never moves the body; the first charge of every encounter is real.
4. One attack at a time: Scuttler never has two open attacks, and `claimStrike` keeps its strikes `STRIKE_SEPARATION` (0.8 s) away from any other strike on the player.
5. Max pressure while carrying an egg: at most one feint per encounter; the pulse can drop the egg only on the second landed pulse inside `PressureMemorySeconds`; after any Scuttler-caused egg drop, Scuttler disengages (reason `EggDropped`), so the player can pick the egg back up. The director's existing `egg = 1.2` multiplier still applies to its roll.
6. Budget and La Silueta: Scuttler costs 3 points, so it starts only when nothing else is active and nothing else starts while it hunts (`check` refuses with `Budget`). The director already never starts it while the player's Silueta hunts or telegraphs. New: if the Silueta starts hunting mid-encounter, Scuttler opens no new attack and disengages (reason `Silueta`) after any open attack resolves, so the two never stack on one player.
7. Safe zones, Pradera and death end or block it like every beast (`guard`, `placeBlock`, `NO_GLOBAL_BIOMES`). Pradera's kids rule is never in play because no global beast appears there.
8. Damage stays off outside the private test place (`BeastHit` decides; unchanged).

## 8. Spawn

- Now: **uniform**. Scuttler is `category = "Global"`, `biome = nil`; with `Config.BIOME_PREFERENCE = false` every playable beast rolls and spawns anywhere the director allows (never in safe zones, never in Pradera). Its `spawnSpec` is a plain ring like Viper's (hidden point preferred), no route weighting.
- Later toggle (off by default): `Config.SPAWN_BIAS = false`. When on, `spawnPoint` would prefer points between the player and their nearest base (return route) and inside dense vegetation, and the intercept could snap to bottlenecks. It needs map data that does not exist yet and a new owner decision; it is not part of SC1-SC10.

## 9. Animations, VFX, SFX

Animations (clip names for the rig and `WildboundBeastAnimPlan`): `Idle`, `Skitter` (moving, rate by speed), `Read` (head tilt, antennas sweep), `Intercept` (fast skitter), `Block` (claws up), `Feint` (crouch and short lunge, cancelled), `ChargeWindup`, `Charge` (loop), `Snap` (claw sweep), `PulseCharge` (rear up), `Pulse` (scream release), `Recover`, `Stumble`, `Crash` (head into the ground or wall), `Fallen` (dazed loop), `GetUp`, `Retreat`.

VFX (client, drawn from server shapes): feint lane outline without fill; real lane solid red with antenna flash at the lock; intercept zone hatch; pulse rings expanding from the true radius; brief desaturation and shake on a landed pulse (skipped by "Efectos suaves"); dust on overrun; rock chips on a crash; dizzy stars on `Fallen`; glowing eyes and antennas by phase.

SFX, existing `WildboundAudioCatalog` slots only: `steps` (skitter), `snap` (claws, Snap), `roar` (pulse release), `unease` (read), `crack` (crash), `hit`, `stinger` (bait taken), `softStinger` (fall), `dirt` (spawn rise). New sounds (an insect chitter, an ultrasonic pulse) are **flagged as new and need the user's approval** before any id is added; the catalog only takes ids from the audio shortlists (`tools/test_wildbound_audio_catalog.py`).

Text (`WildboundText.BEAST.Scuttler`, Spanish): `warn = "¡El Scuttler va a embestir! Sal del carril."`, `hit = "¡El Scuttler te atrapó!"`, phases `Read = "Te está leyendo..."`, `Intercept = "¡Te corta el camino! Cambia de ruta."`, `FeintTell = "¡Va a embestir!"` (same text as the real one, on purpose), `ChargeTell = "¡Va a embestir! Sal del carril."`, `PulseCharge = "¡Va a chillar! Sal de los anillos."`, `Fallen = "¡Se cayó! Escapa ahora."`.

## 10. Art pipeline

1. **Proxy first** (SC8): `Proxies.scuttler()` from Parts, the same palette approach as the wave 2 proxies (carapace maroon, cream chevrons, moss accents, amber eyes). Gameplay never reads the model.
2. **Blender rig** (SC9): `assets/bestias_rig/scuttler/scuttler_rig.blend`, low poly, bones `Root, Hips, Thorax, Head, Jaw, Antenna_L/R (2 each), Claw arm L/R (Shoulder, Upper, Fore, Pincer A/B), Leg 1-4 L/R (3 bones each)`; clips from section 9 baked into `WildboundBeastAnimScuttler` by the same generator that made `WildboundBeastAnimStreamer` (its header names `tools/beast_rig/to_luau.py`, which is not in this repo: locate or restore it first). No animation upload is needed (bone `Transform` is written on the client).
3. **Mesh upload**: the rigged mesh has to be uploaded as a Model asset to appear in the game (as Viper/Pouncer/Gargoyle/Mire were, `assets/models/beasts/uploaded-assets.json`). **Each upload needs the user's explicit approval** (SC10). Until then the proxy plays.

## 11. Multiplayer and server authority

- One encounter, one target (existing): the server owns every transition and hit; the client only draws `Phase`/`Tell`/`Strike` and sends nothing for Scuttler (it is not an observer, no `BeastObserve`).
- The feint's bait check reads a server-written attribute; a client cannot fake a press or skip a tell.
- The pulse affects only the encounter's target (Q4 decided); after SC0 other nearby clients see it but are not affected.
- Two players near each other can each have their own Scuttler (budgets are per player); the two-player test (SC11) checks this reads fine.

## 12. Dependencies on the lock zone (needs teammate)

| Need | Lock-zone file | Status |
| --- | --- | --- |
| Egg drop from the pulse | `WildboundServer` `BeastHit`, `WildboundEggCarry` | **Not needed** for v1: a damage-0 `Hit` reuses the one drop path |
| A distinct drop reason (`"Pulse"`) or a chance-based drop | `WildboundEggCarry.DROP_REASONS`, `WildboundServer` | Needs teammate, only if the owner wants it |
| A Scuttler-specific hit line when the egg drops | `WildboundServer` (uses `Text.EGG.knocked` when the egg drops) | Needs teammate, optional |
| The dodge press calling `DodgeService.press` | inventory server (lock zone) | Read only; SC1 verifies `WildboundDash` moves on a live press |

## 13. Ordered tasks (ODD IDs)

Each task: strict TDD (cases first, RED against the current Studio module, then implement, deploy, GREEN). Before SC1, the parallel spawn task's edits to `WildboundBeastConfig`, `WildboundBeastDirector`, `WildboundBeastRoot` and `WildboundBeasts.server.luau` (the `BIOME_PREFERENCE` switch) must land, to avoid two writers on the same scripts.

| ID | Task | Acceptance checks | Studio tests |
| --- | --- | --- | --- |
| SC0 | Shared beast visibility (all beasts except La Silueta): the server sends visual BeastEvents to every client within the visibility radius, not only the target; effects (Hit, Afflict, knock, slow, egg drop) stay target-only; client renders other players' beasts without hit feedback | A non-target client within radius sees spawn, tells and phases; a non-target is never hit, slowed or knocked; beyond the radius nothing is sent; Silueta events stay target-only; per-player budget unchanged | `WildboundBeastWiring_Test` (new cases); two-player Studio check |
| SC1 | Config entry and director pins: `BEASTS.Scuttler` (section 6), `ORDER`, `PLAYABLE`, `WAVE2`; `Dodge.SOURCES.Scuttler`. Verify a live press moves `WildboundDash` | Scuttler never starts when any point is in use; nothing starts while it is active; never in Meadow or safe zones; `homeBiome` nil; registration accepted | `WildboundBeastDirector_Test` (new cases), `WildboundDodge_Test` (source) |
| SC2 | `Attack.afflict` | Dodged -> no effect; landed -> `Strike` + `Afflict`, never `Hit`; one outcome only | `WildboundBeastAttack_Test` |
| SC3 | Brain skeleton: Spawn, Stalk, committed charge, Recovery, Castigo y caída, Disengage (Escape, Timeout, Outplayed) | Tell >= 0.8 s and registered; lane frozen after lock; dodged charge -> `Fallen` (stumble vs crash by wall); 2 falls -> `Outplayed`; `closeAll` on End | `WildboundBeastScuttler_Test` (new) |
| SC4 | Finta de caza | First charge never a feint; no two feints in a row; feint never registers or hits; press in the feint window -> punish tell 0.9 s; no press -> committed tell; egg cap | `WildboundBeastScuttler_Test` |
| SC5 | Ruta predictiva | Commits only when it arrives first; intercept speed < sprint; zone drawn >= 0.8 s before a Snap; Snap only when the target enters; one re-plan on an early dash; never targets a safe zone | `WildboundBeastScuttler_Test` |
| SC6 | Pulso de pánico | Ring drawn at real radius from charge start; outside -> nothing; inside -> `Afflict` slow; second pulse inside memory -> `Hit` damage 0 (egg) when `PulseCanDropEgg`; disengage after egg drop | `WildboundBeastScuttler_Test` |
| SC7 | Beast script wiring: register, `spawnSpec`, `world.lastDash`, `Afflict` handler, Silueta yield, egg-drop disengage | Forced spawn (Studio-only `ForceSpawnBeast`) runs a full encounter; budget released once on every end; counters move | `WildboundBeastWiring_Test` |
| SC8 | Client and proxy: `Proxies.scuttler`, tells (feint outline, zone, rings, stars), `Text.BEAST.Scuttler`, audio reuse, `AnimPlan` entries | Proxy pivot on ground, head -Z; every phase has a plan; texts present | `WildboundBeastAnimPlan_Test`; solo Play screenshots |
| SC9 | Blender rig and baked clips (`WildboundBeastAnimScuttler`), no upload | Every clip in section 9 exists and loads; `BeastAnimError` empty on a local rig | `WildboundBeastAnimPlan_Test`; Play check with a local rig |
| SC10 | Mesh upload (**only after explicit user approval**) and adoption via `Proxies.adopt` | Model named `Scuttler` replaces the proxy | Solo Play |
| SC11 | Playtest: solo Play then two players | A reader survives without a hit; a fall is reachable; feint readable after 1-2 encounters; no egg loss that felt unavoidable | Notes in the task file |
| SC12 | Docs: mechanics doc and overview status (after the other writer releases the overview) | Overview row says Prepared/Done with evidence | none |

Also add the new scripts to `tools/deploy_manifest.py` and `tools/test_deploy_manifest.py` in the task that creates them (SC3, SC9), and run `python -I -B -m unittest discover -s tools -p "test_*.py"` at each task's close.

## 14. Risks

- **Size vs the forest**: a 14-19 stud body can get stuck between trunks or hide its own tells. Mitigation: proxy test first; `castLane` cuts charges at walls; scale is Q1.
- **Feint reads as unfair**: if players cannot tell feint from real, it feels like a cheat. Mitigation: first charge real, feint outline without fill, cue only on real attacks, playtest SC11.
- **Intercept reads as teleporting**: a fast reposition out of sight can feel like cheating. Mitigation: speed below sprint, zone drawn from the phase start, `ETA` margin.
- **Too much pressure with an egg**: Scuttler plus the `egg = 1.2` roll step. Mitigation: section 7 rule 5; if the two-player test feels unfair, drop the pulse egg drop first.
- **Shared visibility cost**: SC0 sends visual events to nearby clients; up to 16 active beasts with 8 players. Mitigation: proximity radius and visual-only events.
- **Missing generator**: `tools/beast_rig/to_luau.py` is not in the repo; SC9 may need to rebuild it.
- **Parallel writers**: the spawn task is editing `WildboundBeastConfig` and `WildboundBeasts.server.luau` now; SC1 waits for it.

## 15. Open product questions for the user

- **Q1 Scale**: DECIDED 2026-11-14 by the user: smaller, 12-14 studs tall (not the pack's 16-19), so it moves well between trees.
- **Q2 Egg and the pulse**: DECIDED 2026-11-14 by the user: yes, only on a second landed pulse within PressureMemorySeconds (8 s); the first pulse only slows. PulseCanDropEgg = true.
- **Q3 Rarity**: DECIDED 2026-11-14 by the user: keep about 1/60 per 10 s roll, 75 s species cooldown, only when no other beast is active (3 points).
- **Q4 Other players**: DECIDED 2026-11-14 by the user: every player sees every beast (shared visibility, within a proximity radius such as 150 studs), but strikes, pulses and egg drops affect only the beast's target. La Silueta stays personal (visible only to its own player). This is a beast-system change, task SC0 below, done before SC1.
