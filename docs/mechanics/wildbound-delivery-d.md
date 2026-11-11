# Wildbound delivery D: fog, horror audio, stamina and hiding (design)

Status: built. Stamina (D2 to D4) was built in the dread pass after the user answered D-D5 ("make sprint cost something"): sprint is loud (noise 30) and frightens a carried Lumipol until it slips free; sneak (D4b) was cut. See `odd/tasks/wildbound-capture-extraction-horror.md`, section "Dread pass". Earlier status: built except stamina (D2 to D4b, blocked on decision D-D5; see section 12). The design below is unchanged; measured results and the decisions taken while building are in section 12 and in `odd/tasks/wildbound-capture-extraction-horror.md`. Original status: design only. Every number is a hypothesis to tune in play, in the same sense as the numbers in `wildbound-guardian.md`. Player-facing words are neutral Spanish and live in `ReplicatedStorage.WildboundText`; code, docs and commits stay English. Sources read: the feature document `odd/tasks/wildbound-capture-extraction-horror.md`, `docs/audio/wildbound-horror-audio-shortlist.md`, `docs/ui/wildbound-world.md`, `docs/mechanics/wildbound-guardian.md` and `wildbound-extraction.md`, `src/wildbound/WildboundWorld.client.luau` (lighting block, lines 193-203 and 417-437), `WildboundWorld.server.luau` (`visible`, `targetContext`), `WildboundGuardianBrain.luau`, `WildboundWorldRules.luau`, `WildboundLumipolWild.luau`, `WildboundSettings.luau`. The shared knowledge index only holds a game-growth video note; nothing in it bears on this delivery and none of it is used as a requirement.

## What the user asked for

"Fog over the whole map, much more fog at night, gloomier and scarier", while the avatar, the path edge and the nearest lantern stay readable on phones. Plus the delivery D brief: layered horror audio from real threat state, a controlled jumpscare with a reduced-horror option, hiding spots that break the guardian's sight, and stamina with sprint.

## Decisions for user review

| ID | Decision |
| --- | --- |
| DD-1 | Fog covers every zone, not only the fog territory. Three zones (camp, open, fog territory) times three times of day (day, dusk, night), blended by the replicated `clockTime`. Night in the territory is the thickest. |
| DD-2 | Atmosphere stays client-local (as today). The server only supplies `clockTime`, phase and the fog/safe flags it already sends. Readability is guarded by hard floors (FogStart at least 15, FogEnd at least 90) tested in a pure module, not by taste. |
| DD-3 | One comfort switch. The existing `reducedEffects` setting (shown as "Efectos suaves") now also lowers audio and removes the defeat vignette. No second toggle; session-only, nothing saved (no DataStore without consent). |
| DD-4 | Sprint is a server-owned stance. The client sends an intent; the server owns stamina and `WalkSpeed`. Sprint is x1.3 of the current walk speed (carry, eggs and pouch load still count), so the carry cost from B-5 is kept. |
| DD-5 | Sprint is loud, walking is silent. Sprint emits a `sprint` noise to the guardian brain; this is the price of speed and the reason sprint cannot be chained forever. |
| DD-6 | Hiding is a server rule, not geometry. A hidden player cannot be acquired or struck; the only way to be found is the guardian standing near the spot for a dwell time. Entering is refused while the guardian is actively hunting you (awareness `seen`), so hiding is for the Search phase, not an escape button. |
| DD-7 | Threat level is a server bucket (`Safe`, `Distant`, `Near`, `Chase`) published per player; the client plays all audio from it. No new position data leaves the server. |
| DD-8 | The jumpscare is the defeat stinger only, once per life, 15 s cooldown, no flash, no shake, slow fade. The existing red hit flash stays for the marking strike and is not used on defeat. |
| DD-9 | Hit impact is 0.35, not the shortlist's 0.40, so no one-shot exceeds the chase music level (the shortlist's own rule: one-shot peaks at or below chase music). |
| DD-10 | Hiding props are placeholders again (H4): primitive bushes, plus 4 of the 17 existing `FK_FallenLog` models marked as hollow logs. No new uploads. |
| DD-11 | Sneak (x0.45) is included as the cheap answer to A-7 (a keyboard player could not approach slowly). It is keyboard and gamepad only and is the first thing to cut if scope grows (task D4b). |

## 1. Fog and lighting (task D1)

The controller today fogs only inside the territory box (`Rules.zone`) and leaves the open map at the place's own near-infinite `FogEnd`. D1 replaces the inline numbers in `WildboundWorld.client.luau` with a pure `WildboundAtmosphere` module (`ReplicatedStorage`), applied by the same smoothed render step.

### Zones and times

- Zone: `camp` when `state.isSafe`, else `fog` when `state.isFog`, else `open` (the same flags the controller reads now).
- Time of day follows `state.clockTime`, piecewise linear between keyframes: Day until 18.0, Dusk at 19.0, Night from 20.0 to 29.0 (05:00), Dusk again at 29.5 (05:30), Day at 30.0 (06:00). The phase lengths (Day 360 s, Dusk 72, Night 216, Dawn 72) therefore give a 72 s ramp into night and a 72 s ramp out. Zone changes use the existing exponential smoothing (about 2 s).

### Fog numbers (full mood, Reduced off)

| Zone | Time | Atmosphere Density | Offset | Haze | FogStart | FogEnd |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| open | Day | 0.30 | 0.15 | 1.0 | 70 | 450 |
| open | Dusk | 0.40 | 0.08 | 1.8 | 40 | 260 |
| open | Night | 0.52 | 0.00 | 2.6 | 25 | 150 |
| fog | Day | 0.40 | 0.10 | 1.6 | 40 | 240 |
| fog | Dusk | 0.52 | 0.04 | 2.4 | 28 | 160 |
| fog | Night | 0.62 | 0.00 | 3.4 | 16 | 100 |
| camp | Day | 0.22 | 0.15 | 0.6 | 90 | 700 |
| camp | Dusk | 0.30 | 0.08 | 1.0 | 60 | 380 |
| camp | Night | 0.38 | 0.00 | 1.8 | 40 | 260 |

Before: fog-territory night was density 0.40, haze 1, FogStart 45, FogEnd 130; every other zone and time was density 0.2, haze 0 and the place's own FogEnd (about 98,000 in the readback in `silueta-encounter-phase-report.md`). The new night in the territory is 1.55x denser, 3.4x hazier, and sees 100 studs instead of 130; the open map at night goes from clear to 150 studs. Offset was never written by the controller; the original Offset is read from Studio before the first edit and restored on cleanup like the other properties.

### Colours and light

| Time | Atmosphere.Color | FogColor | Ambient | OutdoorAmbient | Brightness x place's own | ExposureCompensation |
| --- | --- | --- | --- | --- | ---: | ---: |
| Day | 150, 160, 152 | 104, 116, 110 | place's own (not written) | place's own (not written) | 1.00 | 0 |
| Dusk | 112, 104, 114 | 66, 66, 84 | 62, 70, 84 | 74, 82, 96 | 0.80 | -0.15 |
| Night | 64, 78, 100 | 26, 36, 54 | 30, 40, 68 | 36, 48, 76 | 0.55 | -0.30 |

In the fog territory the Atmosphere and Fog colours are multiplied by 0.92 so the thickest fog is also the darkest. Previous night values (delivery T7): Ambient 34, 46, 76, OutdoorAmbient 40, 54, 86, fog zone FogColor 40, 54, 72 and Atmosphere 78, 94, 116; the new night is roughly 12 percent darker and bluer-black. Lantern lights (Brightness 1.0, Range 18, warm) are unchanged: darker fog makes them stand out more, which is the point.

### Readability floors (pure contracts, so a tuning change cannot break phones)

For every zone and time, full and reduced: FogStart at least 15 (the default camera sits 12.5 studs behind the avatar, so avatar and path edge are never fogged); FogEnd at least 90 (the nearest lantern, expected within about 40 studs, is still at least 60 percent visible: at night in the fog (40 - 16) / (100 - 16) = 29 percent fogged); FogEnd at least 4 times FogStart (a ramp, not a wall); Density at most 0.65; Haze at most 4; each Night Ambient channel at least 26. Orderings: within a zone Day is milder than Dusk is milder than Night; within a time camp is milder than open is milder than fog (Density up, FogEnd down).

Studio phone gates (D13, from the same single-capture pixel method as the T7 pass, so they carry the same caveat): path at least 1.5x brighter than the ground beside it; avatar silhouette at least 1.8x darker than the path; lantern glass at least 8x its surround at 25 studs and at least 3x the fog behind it at 40 studs. T7 measured 1.8-2.5x, 2.4x and 14x. If a gate fails, step the night fog-zone row one notch (Density -0.05, FogEnd +10) and recapture; do not argue with the capture. Real devices are not measured.

### Reduced effects

`reduced` blends every numeric target 50 percent toward the same zone's Day row, and colours 50 percent toward Day (Ambient and OutdoorAmbient 50 percent toward the place's own). Night in the fog territory becomes Density 0.51, FogStart 28, FogEnd 170 (the old reduced FogEnd was 180). The contracts above are asserted for the reduced values as well.

## 2. Stamina, sprint and sneak (tasks D2 to D4b)

| Parameter | Value |
| --- | --- |
| Pool | 100, full at spawn and after respawn; not saved |
| Sprint speed | walk x 1.45 since the chase pass (x 1.3 before), capped at 24: 16 -> 23.2, carrying 14 -> 20.3, loaded pouch 11 -> 15.95, three eggs 9 -> 13.05 |
| Drain | 25 per second while sprinting and moving (4.0 s from full) |
| Start threshold | 10 (30 after exhaustion) |
| Exhaustion | at 0: no sprint until stamina is back at 30 |
| Regen | starts 1.5 s after the last drain; 10 per second walking, 15 per second standing still or hiding; none while sprinting |
| Moving | horizontal speed at least 4 studs per second (server reading), so holding Shift in place costs nothing |
| Sneak | walk x 0.45: 16 -> 7.2, carrying 14 -> 6.3; below the Lumipol calm speed of 8 (A-1); guardian detection radius x 0.8 |
| Sprint noise | kind `sprint`, base 16, every 1.2 s while sprinting outside camp; see section 3 |
| Refused while | a capture session is open, hiding, dead |

Why these numbers: a full pool lasts one dash across a clearing, not a lap. The longest chained duty is 10 / (25 + 10) = 28.6 percent of the time (ignoring the 1.5 s delays), so the best mean speed gain is 28.6 percent x 30 percent = 8.6 percent over walking. Running away from the guardian already works without sprint (hunt speeds 7, 9, 10 stay below 11), so sprint is about reaching cover and shortening exposed legs, paid for in noise.

Economy risk: delivery C found the expedition median at 178 s against a 180 s target when speeds moved by a few percent. A 1.086 speed factor could push it under again. D2 adds a `sprintBoost` input to `tools/simulate_economy.py` (default 1.0 in the economy JSON, sensitivity-tested at 1.086); if the invariants fail, tune in this order: sprint multiplier 1.3 -> 1.2, regen 10 -> 8, then drain 25 -> 30. Do not change the economy JSON for it.

Stance table (server decides, client only asks):

| Stance | Entered when | Speed | Noise | Detection |
| --- | --- | --- | --- | --- |
| walk | default | base | none | x 1 |
| sprint | intent sprint, moving, stamina at or above the threshold, not blocked | base x 1.3 | `sprint` | x 1 |
| sneak | intent sneak | base x 0.45 | none | x 0.8 |
| exhausted | stamina reached 0 | base | none | x 1 |

Input: keyboard hold LeftShift (sprint) and hold LeftControl (sneak); gamepad hold ButtonL3 (sprint); touch is a toggle on a 64 x 64 "Correr" button, because a held button would take the right thumb off the camera. Shift is also Roblox's shift-lock key, so D4 must verify in Play that Shift does not toggle shift lock (bind it with a sinking `ContextActionService` action at high priority; if that fails, set `StarterPlayer.EnableMouseLockOption = false`, a Studio edit the writer reports). LeftShift, LeftControl and H are free of the keys already taken (F, Q, X, G, C, I, M, E, R, T, V, B).

## 3. Hiding (tasks D5 to D7)

### Spots

Ten spots: 6 primitive "Arbusto espeso" (dark green ellipsoid cluster about 6 studs wide and 3.5 tall, `CanQuery` on so standing behind one also blocks the ray) and 4 "Tronco hueco" (existing `FK_FallenLog` models; the log is untouched, and the spot adds an invisible `HideZone` along its axis and a dark `Hollow` disc at one end). Each spot is a `HideSpot` model tagged `WildboundHideSpot` with attributes `SpotId` (`H01`..`H10`), `Kind`, and one invisible `HideZone` (5 x 3 x 5, `CanCollide`, `CanQuery`, `CanTouch` off) and one `ProximityPrompt` on it. Layout rules (planner script plus Python test, then the builder): none inside either safe circle; at least 25 studs apart; 8 to 14 studs off the nearest route centerline; at least 10 studs from any trunk core; at least 1 spot 25 to 45 studs from each of the nest (35, -99), the ruin and the marsh (115, 15), and 1 near the Lumipol clearing (-95, 75). The existing forest-dress test pins that only trunks have `CanQuery`; the hide builder never touches `ForestKit` models, so that test stays as it is.

### Enter, stay, exit

- Prompt "Esconderse", key H (distinct from all others in `WildboundPromptKeys`), hold 0.4 s, 7 studs, exclusive. The server handles `Triggered`; there is no entry remote.
- `Hide.canEnter` refuses with a reason, all server-side: `Dead`, `Capturing` (a session is open), `Occupied` (one player per spot), `Seen` (the guardian is in Alert, Hunt or Telegraph with this player as its target, that is awareness `seen`), `Cooldown` (that spot for that player until 8 s after a forced exit).
- On enter: the character is placed at the spot's `Inside` point, root anchored, `WalkSpeed` 0, jump off, stance forced to walk, and the player attribute `WildboundHidden` is set to the spot id. Entering rustles: a `rustle` noise (base 10) is raised once at the spot, so hiding right next to the guardian gives you away.
- Exit: the "Salir" button (the same 64 x 64 slot as "Correr"), key H, or the `WorldAction("HideExit")` remote with no arguments (the server knows the spot). Thumbstick input held above half for 0.25 s also exits. The character is placed 3 studs outside the spot, facing away, unanchored, with the speed restored from the stored base.
- Forced exits: death; discovery; 45 s inside (then an 8 s spot cooldown); a capture session starting (cannot happen: refused earlier).

### How hiding plugs into the guardian

Sight today is one ray from the guardian body to the player's root inside `targetContext` (`WildboundWorld.server.luau`), and the strike gates need `visible == true`. The plug is a single early return: if the player is hidden, `targetContext` returns nil (no acquisition), and any strike or hunt context for a hidden player reports `visible = false`, which the hunt already handles as `Brain.lostSight` (Search at the last seen point). No second sight system is added.

Discovery (pure `WildboundHide.discover`, called each 0.2 s step):

| Phase | Discover radius (horizontal, to the spot centre) | Dwell |
| --- | ---: | ---: |
| Day | 4 | 2.0 s |
| Dusk, Dawn | 5 | 1.6 s |
| Night | 6 | 1.2 s |

The guardian in Patrol, Suspicious, Investigate, Search or Retreat (or Hunt on a different player) within the radius adds `dt` to a dwell timer; outside it the timer decays at twice the rate. At the dwell the player is ejected and the brain engages with the shorter re-acquire wind-up (0.6 s, `Brain.engage` from Search). The Search state walks the last known spot and four points 7 studs around it, so a spot within about 7 studs of the last seen point is a real risk and one 15 studs away is a good hide. Search lasts 6, 9 or 12 s by phase, then Retreat: that is the intended hiding window.

New noise kinds, added to `Brain.NOISE` and sent on the existing server-only `GuardianNoise` event with the zone's tier (fog 1.0, territory 1.4; camp and hidden players send nothing):

| Kind | Base radius | Night in territory (x 1.4 x 1.3) | Day in fog (x 1.0 x 0.8) |
| --- | ---: | ---: | ---: |
| `sprint` | 16 | 29.1 studs | 12.8 studs |
| `rustle` | 10 | 18.2 studs | 8.0 studs |

Strength rules are unchanged: under 0.5 the guardian is Suspicious, at 0.5 or more it Investigates. Carrying adds nothing to what it senses (B-6), and DD-6 keeps that: a carried creature does not change hiding (see open question 1).

## 4. Threat level and audio (tasks D8 to D10)

### Server threat level (pure `WildboundThreatLevel`)

Per player each 0.2 s, from the guardian's mode, its horizontal distance, whether this player is the target, `Hidden`, and the safe zone:

| Level | Rule |
| --- | --- |
| Safe | in the safe zone (always), or the guardian is farther than 120 studs, or it is in Retreat and farther than 55 studs |
| Distant | within 120 studs, or Alert/Hunt/Telegraph on another player at any distance |
| Near | within 55 studs and not hunting this player; or Suspicious, Investigate or Search within 80 |
| Chase | Alert, Hunt or Telegraph with this player as target |

Hidden demotes Chase to Near (sight is lost). Rises are immediate; falls are held (hysteresis) so the music does not flicker: Chase -> Near after 3 s, Near -> Distant 3 s, Distant -> Safe 5 s. The server publishes the player attributes `WildboundThreatLevel` (string) and `WildboundThreatAt` (server time). The bucket reveals nothing a streamed client cannot already see about the guardian (bodies replicate), and it removes any need for the client to compute threat.

### Layers and volumes (full mood; `Sound.Volume`; every id is from the shortlist, never invented)

All ids are unaudited candidates. D10 first auditions them (loads, loops, `TimeLength`, peak `PlaybackLoudness`) and records rejected ids in the shortlist; the catalog lists a primary and a fallback per slot, and a failed or moderated id is skipped silently, never blocking play.

| Slot | Asset id (fallback) | Safe | Distant | Near | Chase |
| --- | --- | ---: | ---: | ---: | ---: |
| Wind bed | 9112777807 | 0.20 (night 0.14) | same | x 0.7 | x 0.4 |
| Day birds and leaves | 9112806209 | 0.10 day only | same | 0 | 0 |
| Insects, dusk | 9112810042 | 0.12 | same | x 0.7 | x 0.4 |
| Insects, night | 9117114084 | 0.12 | same | x 0.7 | x 0.4 |
| Safe music | 9046399990 (day 0.15, dusk 0.12, night 0.08) | as listed | 0.08 | 0 | 0 |
| Night under-bed | 9043359885 | night 0.08 | 0 | 0 | 0 |
| Unsettling music | 9043359270 (9114353534) | 0 | 0.20 | 0.20 | 0 |
| Branch snaps, one-shot | 9120259118 (9114518080) | 0 | 0.25 every 8-20 s | 0.25 every 6-14 s | 0 |
| Dirt impacts, one-shot | 9114106242 | 0 | 0 | 0.20 every 6-14 s, alternating with snaps | 0 |
| Whispers, one-shot | 9125440130 | 0 | 0.20 every 20-40 s | 0 | 0 |
| Breathing, 3D on the guardian body, rolloff 8-60 | 9113586909 | 0 | 0 | 0.30 | 0.30 |
| Guardian steps, 3D, rolloff 8-60 | 9114080709 (9114079718) | 0 | 0 | 0.35 | 0.40, PlaybackSpeed 1.15 |
| Chase music, starts from the top | 1847568713 | 0 | 0 | 0 | 0.35 |
| Tension pulse under the music | 9114504259 | 0 | 0 | 0 | 0.12 |
| Silueta signature (a short slice) | 9125440130 | 0 | 0 | 0 | 0.30 at chase start, then every 12-20 s |
| Hit impact | 9113525391 | 0.35 once | | | |
| Death stinger | 9126006341 (9119640924) | 0.35 once | | | |
| Hidden breathing, 2D | 9113586909 | 0.12 while hidden | | | |

Step interval is stride over speed: `interval = 5 / speed` seconds (patrol 4 -> 1.25 s, night hunt 10 -> 0.5 s), at most 3 overlapping steps. Snap and dirt positions are placed 15 to 70 studs from the player on a bearing toward the guardian plus a random offset of up to 35 degrees (random bearing if the guardian is not streamed).

### Crossfade and mix rules

- Fade-in 1.5 s on any rise; Chase fade-out 3 s after the level falls; Near and Distant fade-outs 2 s; Safe beds 4 s; phase changes crossfade the Safe beds over 4 s. Every one-shot fades in over at least 80 ms.
- Ducking order, higher over lower: hit/death over Chase over Near over Distant over Safe. A hit or death ducks everything else by 40 percent for 1.5 s.
- Invariants tested in the pure mix (all combinations of level, time of day and Reduced): the guardian cues (steps and breathing) are at least as loud as any music layer; no music layer above 0.35; no one-shot above the chase music level (0.35); at most 2 concurrent snaps or whispers, 3 steps, and 14 `Sound` instances in total; a stinger never within 15 s of another.
- Hidden: world beds and music go through a muffle (`EqualizerSoundEffect` on the ambient and music groups, HighGain -18 dB, MidGain -6 dB, 0.4 s) and the 2D breathing fades in; both clear on exit.
- Groups: one `SoundGroup` per layer under `SoundService.WildboundMix` (Ambient, Music, Threat, Chase, Impact) under a Master group, so ducking and the Reduced scale are group volumes.
- Sound instances are created on the client, parented to `SoundService` or, for 3D layers, to the replicated guardian body. If the body is not streamed the 3D layers are skipped.
- Creature cues (B2 hook): the capsule's `SoundCue` "unease" plays 9118057295 at 0.15, pitched 1.4, and "fear" plays 9118050871 at 0.20, both 3D on the capsule, once per cue (the server already limits cues to one per 8 s). The fear whimper stops on Chase start so it does not stack with the signature.
- Not in delivery D: the camp and UI layer (chime, crackle, seal sounds) belongs to delivery F.

## 5. Jumpscare and reduced horror (tasks D11, D12)

Trigger: the server sets `LastHitSound = "defeat"` (existing, C3) with a fresh `LastHitAt`; the client plays only if the event is no more than 2 s old. Only a lethal defeat counts; spared (shadow) strikes and the marking first hit never do.

`Jumpscare.allowed(state, now, reduced)` (pure) refuses when: a stinger played in the last 15 s; one already played this life; the stinger asset is unloaded (then the impact alone plays).

Sequence, full mood: t0 duck every layer to 0 over 0.15 s (this resolves the shortlist rule "never a stinger during a chase fade-out": on defeat the chase layer is cut first); t0 + 0.2 s the stinger 9126006341 at 0.35 with a 100 ms fade-in; at t0 the screen eases to a dark overlay (alpha 0.85) over 0.5 s, then the existing Spanish defeat screen appears. No flash, no shake, no sudden light change; the old 0.45 s red hit flash is not used on defeat. Layers return 2 s after respawn with a 2 s fade-in.

Reduced horror (`reducedEffects` On): master x 0.6; stinger replaced by 9043355570 at 0.25 with a 300 ms fade-in; overlay fades over 0.8 s to alpha 0.6; chase music capped at 0.20, signature 0.15 and once per chase; whispers off; breathing 0.15; hit impact 0.30; snaps, steps and the awareness chip unchanged (reduced lowers dread, not information); every layer fades in over 2 s; fog and light at the 50 percent blend of section 1.

## 6. Server and client authority

| Piece | Server | Client |
| --- | --- | --- |
| Fog and lighting | publishes `clockTime`, phase, fog and safe flags (existing) | computes targets and writes local Lighting; restores on cleanup |
| Stamina and speed | owns pool, drain, regen, stance and `WalkSpeed`; validates the intent | sends intent (sprint, walk, sneak) at most 8 per second plus a 0.5 s heartbeat while held; draws the bar from `WildboundStamina` and `WildboundStance` |
| Sprint noise | raises `sprint` and `rustle` on `GuardianNoise` | nothing |
| Hiding | occupancy, enter and exit, targetability, discovery, forced exits | prompt text, the "Salir" button, the vignette |
| Threat level | computes and publishes the bucket | plays layers from it |
| Audio, snaps, steps | none | everything (local only) |
| Jumpscare | already publishes `LastHitSound` and `LastHitAt` | gate, cooldown, stinger, overlay |
| Reduced horror | nothing (a client setting, session-only) | reads the `Reduced` attribute on `WildboundWorldUI` as the capture UI does |

The stance remote accepts only one of three known strings, ignores anything else, drops more than 8 calls a second per player, and expires an intent not refreshed within 1.2 s (so a lost release cannot leave a player sprinting). Client-side `WalkSpeed` tampering is an existing risk this delivery does not add to or fix.

## 7. Spanish words (neutral, added to `WildboundText`)

| Key | Text |
| --- | --- |
| STAMINA.label | Aliento |
| STAMINA.sprint | Correr |
| STAMINA.sneak | Sigilo |
| STAMINA.exhausted | Sin aliento |
| STAMINA.notice | Te falta el aliento. Espera un momento. |
| HIDE.prompt | Esconderse |
| HIDE.exit | Salir |
| HIDE.entered | Te escondes. No te muevas. |
| HIDE.seen | Te están viendo. Rompe su línea de visión primero. |
| HIDE.occupied | Este escondite está ocupado. |
| HIDE.busy | Termina de calmar al Lumipol primero. |
| HIDE.tooLong | Ya no aguantas más ahí dentro. |
| HIDE.found | ¡La Silueta te encontró! |
| HIDE.kind.bush | Arbusto espeso |
| HIDE.kind.log | Tronco hueco |
| SETTINGS.reducedEffects | Efectos suaves |
| SETTINGS.reducedEffectsDescription | Niebla, luz y sonidos de miedo más suaves. Apagado mantiene el ambiente completo. |

## 8. Tasks

All tasks use strict TDD: write the test, run it against an empty stub in a temporary `ServerStorage` folder to observe RED, implement to GREEN, add the pair to `tools/deploy_manifest.py` and its test, commit by exact path with a conventional message. Test files follow `tests/WildboundXxx_Test.luau`: `return function(Module, ...)` with `case("Dn: ...")`. Route for every task: delegated direct, one Studio writer, instance and place verified read-only and confirmed before the first Studio edit. About 400 authored changed lines per task is the planning heuristic only. Delivery C (guardian brain, damage) is paused; D5 to D7 and D8 touch the same world script and brain, so they are sequenced after C1 and C3 are committed (this design does not depend on C2 to C5 being finished, except that the sprint noise needs the C1 `GuardianNoise` event).

- **D1 Atmosphere.** Pure `WildboundAtmosphere` (`at(clockTime, zone, reduced)` returning all targets; keyframes; reduced blend; floors). `tests/WildboundAtmosphere_Test.luau`: "D1: keyframes at 18, 19, 20, 29, 29.5, 30 equal the tables", "D1: dawn mirrors dusk", "D1: clock wraps past 24", "D1: zone ordering camp < open < fog", "D1: time ordering day < dusk < night", "D1: readability floors hold for all 18 combinations", "D1: reduced blends 50 percent toward Day and keeps the floors", "D1: night fog zone is at least 1.5x as dense and at most half as far as day open", "D1: bad input (NaN, nil, huge) returns the Day open row". Wiring: `WildboundWorld.client.luau` calls the module, the inline fog and colour numbers are gone, Offset is cached and restored (source patterns on the client source, like `WildboundCarry_Test`). RED expected: all cases against the stub, then the wiring cases until the client moves. Updates `docs/ui/wildbound-world.md` table.
- **D2 Stamina rules.** Pure `WildboundStamina` (`new`, `step(state, dt, input)`, `speed(base, stance)`, `detection(stance)`, `noise(stance, moving, now)`), plus a `sprintBoost` input in `tools/simulate_economy.py`. `tests/WildboundStamina_Test.luau`: "D2: full pool drains in 4 s of sprint", "D2: nothing drains standing still", "D2: regen starts 1.5 s after the last drain", "D2: regen is 10 walking and 15 standing", "D2: exhaustion at 0 locks sprint until 30", "D2: start needs 10", "D2: sprint speed is base x 1.3 capped at 24 for walk, carry, pouch and eggs", "D2: sneak is base x 0.45 and detection x 0.8", "D2: sprint noise at most every 1.2 s and never in camp", "D2: blocked input (capture, hidden, dead) forces walk", "D2: bad dt and NaN keep state", "D2: sprint never exceeds an 8.6 percent mean speed gain over a long run". Python: `tools/test_simulate_economy.py` gains "sprint boost 1.086 keeps the invariants" (RED first if it does not; then tune in the order in section 2).
- **D3 Stamina server.** Wire the stance remote and per-step update into the world server; `applyCarry` stores the base speed and applies the stance on top; attributes `WildboundStamina`, `WildboundStance`; a `sprint` `GuardianNoise` call; `detectionFor` multiplies by the stance factor. `tests/WildboundStaminaWiring_Test.luau`: "D3: remote accepts only three strings and rate limits", "D3: intent expires after 1.2 s", "D3: speed after applyCarry equals base x stance", "D3: respawn restores a full pool", "D3: capture start cancels sprint", "D3: sprint noise reaches the brain only outside camp", plus a Studio-only server probe (like A-8) for a second-player check.
- **D4 Stamina client.** Input (Shift, Ctrl optional, L3, touch toggle), the 64 x 64 action slot and the bar through `WildboundHudLayout` (new `actionSlot` and `staminaBar` rectangles, searched like the capture panel), words from `WildboundText`. `tests/WildboundHudLayout_Test.luau` additions: "D4: the action slot overlaps no HUD rectangle, avatar keep-out, thumbstick or jump zone on the four tested interfaces and 13 viewports", "D4: the bar stays 3:1 against its track", "D4: exhausted shows words, not only colour". `WildboundText_Test`: "D4: stamina words exist". Play check: Shift does not toggle shift lock; touch toggle (BLOCKED under the Device Simulator for taps, as before; use the same remote).
- **D4b Sneak (cuttable).** Wire the sneak intent, key and detection factor only if D4 is green and the user keeps DD-11.
- **D5 Hide rules and brain noise.** Pure `WildboundHide` (`canEnter`, `discover`, `maxStay`, `exitPoint`) and `Brain.NOISE` gains `sprint` 16 and `rustle` 10. `tests/WildboundHide_Test.luau`: "D5: seen, occupied, cooldown, capturing and dead refuse with a reason", "D5: searching is allowed", "D5: discovery needs the radius and the dwell by phase", "D5: the dwell decays twice as fast outside", "D5: a hunt on another player still discovers", "D5: 45 s forces an exit and an 8 s cooldown", "D5: bad numbers never discover". `tests/WildboundGuardianBrain_Test.luau` additions: "D5: sprint noise radius is 16 x tier x hearing", "D5: rustle radius", "D5: sprint under strength 0.5 is Suspicious".
- **D6 Hide server.** Prompt `Triggered`, occupancy, anchor and release, `HideExit`, the `targetContext` early return and `visible = false` for hidden players, discovery each step into `Brain.engage`, forced exits, `rustle` noise, attribute `WildboundHidden`. `tests/WildboundHideWiring_Test.luau`: "D6: a hidden player is not acquired", "D6: a hidden player is not struck even in dwell", "D6: a hunt on a player who hides becomes Search", "D6: entering during Alert, Hunt or Telegraph is refused", "D6: two players cannot take one spot", "D6: death and capture release the spot", "D6: exit restores the stored speed". Studio-only `HideProbe` for the second-player occupancy check, never created outside Studio.
- **D7 Hide spots.** `tools/plan_hide_spots.py` (the layout rules above, written to `assets/maps/forest-layout/hide-spots-v1.json`) with `tools/test_plan_hide_spots.py`: "D7: ten spots, none in a safe circle, at least 25 apart, 8-14 off the route, 10 from any trunk core, objective coverage"; `buildHideSpots(root)` in `tools/build-wildbound-p0-map.luau` (like `buildCamp`: refuses a second run, patches the dressed live map once), `WildboundP0Map_Test` additions: "D7: hide spots are tagged, zones do not collide or query, bush geometry queries, a second build is refused", and `WildboundForestDress_Test` stays untouched and green.
- **D8 Threat level.** Pure `WildboundThreatLevel` plus the per-step publish. `tests/WildboundThreatLevel_Test.luau`: "D8: each level from mode and distance", "D8: safe zone forces Safe", "D8: hidden demotes Chase to Near", "D8: rises are immediate, falls are held 3, 3 and 5 s", "D8: another player's hunt is Distant", "D8: bad input is Safe".
- **D9 Audio mix.** Pure `WildboundAudioCatalog` and `WildboundAudioMix` (targets by level, time and reduced; fades; step interval; snap scheduling with an injected random; `Jumpscare.allowed`). `tests/WildboundAudioMix_Test.luau`: "D9: the table of section 4 for each level", "D9: invariants hold for every level, time and Reduced", "D9: reduced overrides (0.6 master, caps, whispers off)", "D9: step interval is 5 / speed", "D9: jumpscare refuses within 15 s, twice per life, and when unloaded", "D9: no id is repeated across conflicting roles without being listed". `tools/test_wildbound_audio_catalog.py`: every `rbxassetid` in the catalog appears in `docs/audio/wildbound-horror-audio-shortlist.md` and in no "rejected" line.
- **D10 Audio controller.** `WildboundAudio.client.luau`: groups, preload (`ContentProvider:PreloadAsync`), layer players, 3D layers, the muffle, the B2 `SoundCue` hook, the stale-event guard, the 14-instance cap; the audition pass first (a temporary panel in Studio; failed ids go back to the shortlist as rejected). `tests/WildboundAudioWiring_Test.luau`: "D10: only catalog ids are used", "D10: no Sound is created without a group", "D10: a failed load is skipped without an error", "D10: events older than 2 s are ignored", "D10: cleanup destroys every Sound and group".
- **D11 Defeat treatment and cues.** `WildboundHudView` defeat overlay (slow fade, no flash) and the hit and defeat hooks into the controller. `tests/WildboundHudView_Test.luau` additions: "D11: defeat uses a fade of at least 0.5 s and no flash", "D11: reduced uses 0.8 s at alpha 0.6", "D11: the marking hit still flashes".
- **D12 Reduced horror and words.** `WildboundSettings` label and description move to Spanish through `WildboundText`; audio and atmosphere read the same switch. `tests/WildboundSettings_Test.luau`: "D12: reducedEffects text is Spanish", "D12: all three consumers read one switch" (source patterns).
- **D13 Play check.** Studio Play solo with `d-` phone captures (iPhone 17 Pro and Galaxy A06, landscape and portrait): fog by zone and time of day, the readability gates, sprint and exhaustion, hide enter, search past, discovery and exit, threat levels in order, per-id `Sound.IsLoaded`, `TimeLength` and peak `PlaybackLoudness`, the jumpscare once and refused inside 15 s, Reduced On, the economy simulator at 1.086. Update this document with measured values, the suite totals and the feature checklist.

## 9. Acceptance (per task, observed only)

A task is done when its RED then GREEN is observed, the fresh-clone suite and `python -I -B -m unittest discover -s tools -p "test_*.py"` pass except the known `test_lumipol_v2.test_v1_files_are_unchanged` failure, the deployed sources match the repo by Adler-32 and length, and the Play result is recorded. Audio is judged by `Sound` properties and the loudness reading, not by ear: nobody has heard it in this environment.

## 10. Open questions

1. Hiding with a carried creature: DD-6 says it makes no difference. Should a frightened carried creature (B2 mood `afraid`) widen the discover radius by 2 studs, so carrying costs something while hiding?
2. One comfort switch (DD-3) or a separate audio-only "Sonido suave" next to "Efectos suaves"? One keeps the phone settings panel short; two helps players who want the fog but not the scares.
3. Audio gaps in the shortlist (no seamless chase loop, no real whimper, no confirmed fast footsteps): accept the approximations above, or will the user provide licensed uploads (needs the user's consent and rights, and moderation)?
4. Real bush and log art stays primitive (DD-10); a real model needs the user's approval to upload, as with the Lumipol (H4).
5. Sprint strength (x1.3, 4 s pool) is tuned against the 180 s expedition target by the simulator in D2; if it fails, the user should know the first lever is a weaker multiplier.

## 11. Not verified

Anything audible, all fog thickness on a real phone (Atmosphere Density is not a distance, so the FogStart/FogEnd floors and the capture gates carry the readability claim), Shift versus shift lock, `EqualizerSoundEffect` behaviour on mobile, memory and frame cost of the sounds, the hide discovery feel, touch taps on any button (BLOCKED in the Device Simulator, as in earlier deliveries), and two real clients.

## 12. Results (delivery D build, 2026-11-07)

- Built: D1 atmosphere, D5 to D12 (hiding rules, server, ten spots, threat level, audio catalog and mix, audio controller, defeat fade, one Spanish comfort switch). Commits `099cabc` to `f5e4cc0`. Fresh-clone Studio suites 915 passed, 0 failed over 41 suites; Python 887 run with the one known failure.
- Not built: D2 to D4b. The economy simulator puts the greedy expedition median at 180.5 s with no sprint against the 180 s floor; a sprint boost of 1.04 gives 175.6 s and 1.086 gives 172.0 s, and the section 2 tuning order cannot get back above 180 (decision D-D5, for the user).
- Changes while building, for review: hollow logs count at 15 to 32 studs off the route (no log is 8 to 14 off it) and every spot stays 12 studs off the patrol diamond (D-D4); a hidden root is anchored instead of WalkSpeed 0, and a found player is pulled out on the guardian's side (D-D6); spot ids come from model names and the Play clock shift is a Studio-only `NumberValue`, because the world server reads no attributes (D-D7); the world button reads "Suave: Sí/No".
- Night fog gates (desktop single captures, phones BLOCKED): lantern glass 10.1x its surround at about 25 studs, about 8x the fog behind it at about 39 studs; path 1.5x to 1.7x the ground beside it (at the gate); avatar 3.0x darker than the path. No notch step was needed.
- Audio: all 23 ids load in Edit and in the Play client. First-1.6-s peak `PlaybackLoudness` at Volume 0.5 shows the soft stinger 9043355570 (318) and the hit 9113525391 (290) are louder than the chase music (204), so DD-9 holds by Volume only. Nothing has been heard.


## 13. Dread pass: footsteps you hear before you see (2026-11-07)

User: in a chase you hear its steps getting closer but can barely see it. Ids from `docs/audio/wildbound-dread-assets-shortlist.md` (the parallel research), all kept in `WildboundAudioCatalog`: `giantSteps` loops the ProSoundEffects giant thumps 9125404769 (fallback 9125404774) on the guardian body, its `PlaybackSpeed` following the measured speed (`Mix.gait`: speed / 6 clamped 0.7 to 1.3; no giant-run asset exists, so a run is a faster gait and a shorter stride); `approach` loops the 9.3 s take 9125404796 as a far bed; the stride one-shot stays 9114080709 (fallback 9114079718) at a 9-stud stride (`Mix.STRIDE`, was 5), pitch 0.85 walking and 1.2 in a chase; `crack` 9126239755 sounds from the forest toward it every 8 to 16 s when Near; `groan` 9114628321 at pitch 0.7 comes from its body every 10 to 18 s in a chase (0.15 with Reduced); `creak` 9120262025 loops on it when Near (0.12) or chasing (0.08).

Steps now start at Distant (within 120 studs): steps 0.25, giant steps 0.18, approach 0.12; Near 0.40, 0.30, 0.10; Chase 0.45, 0.35, 0. Their roll-off is 12 to 150 studs (approach 20 to 180), every other spatial cue keeps 8 to 60. The night fog hides the guardian from about 48 studs, the day fog from about 110 to 140.

Play (Studio Play solo, desktop, night at 23:00 by the clock shift): every catalog id loaded in the Play client (`FailedIds` empty). At 107.6 studs (Distant) the body carried `giantSteps` (0.18, gait 0.72), `approach` (0.12) and `steps` (0.25, pitch 0.85), all playing, `IsLoaded` true, roll-off 12 to 150; the capture from 113 studs shows nothing of it. At 40 studs only its two lit eyes and a faint shape show; at 20 studs it fills the frame. In the chase: giant steps 0.35 at gait 1.30 while hunting (0.70 standing to strike), steps 0.45 at pitch 1.2, the groan at 0.7 played. Nobody has listened: loudness, overlap of the loop with the stride one-shots and the 4.6 s clip's own rhythm are NOT VERIFIED by ear.

## 14. Next batch: a readable chase start (2026-11-09)

When La Silueta sees you (threat level Chase), the audio client now plays, before the signature and the roar:

- `chaseSting`, a 2D one-shot in the player's head (Impact group): APM "Evil Mind 9" 1846887425, fallback "Island Chase (sting)" 1842083006, both free APMOfficial assets from `docs/audio/wildbound-dread-assets-shortlist.md` 1.8. Volume 0.45 with a 0.02 s attack; "Efectos suaves" 0.18 eased in over 0.25 s (and the 0.6 master). At most once per 8 s (`Mix.CHASE_STING_COOLDOWN`), so a quick re-sighting is not hit twice.
- The chase music and pulse cut in over 0.2 s (was 1.5 s); "Efectos suaves" keeps the 2 s rise. Every other layer is unchanged.

Measured in Studio Play (desktop, by properties; nobody has listened): the sting started 0.07 to 0.12 s after the level turned Chase (the controller's 0.25 s step), peak `PlaybackLoudness` 348 (the defeat hit reads 290 and the chase music 204; the reading does not follow `Volume`), "Efectos suaves" played it at 0.18 with master 0.6 and the chase music at 0.20. On the very first chase of a session the sound was not yet loaded when it started (`IsLoaded` false on the first frame), so the first sting may come late or be cut. Audio volume is presentation, not a gameplay constant, so it is not in the dev tuning schema.
