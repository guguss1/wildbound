# Caramelo play fix (step A1): creatures that work for a walking player

## Objective

The owner walked through the Caramelo biome and saw that nothing worked:

- the critters "appear and fade, don't chase, have no attacks";
- "Gomibu and Don Glaseon are always in the same place";
- the trap cake "does nothing";
- "I want more frequency of beasts".

Earlier checks passed because agents teleported next to each post and used probes. The walk-through diagnosis found that
every system ran, but the tuning and some design gates made the beasts all but invisible to a player who walks past. This
step retunes and fixes them for a walking player, and every Play check here walks the character in from the road.

Scope: the director, the five critters (Mochimiau, Canelin, Flanin, Mielita, GatoRepartidor), Gomibu, Don Glaseon, the
trap cakes and the beast frequency. Out of scope: the map files of stream B (WildboundBiomes, WildboundBiomeLight,
WildboundMapModeSwitch, geometry), `SistemaSonriente`, and the extra mechanics on the creature sheets (see "Not done").

## Checklist

- [x] PF1 Director: a summoned points-0 beast neither counts toward nor is refused by MAX_ACTIVE; rolled beasts keep the
  cap; every summon refusal goes to `WildboundTelemetry.Beast_lastSummonRefusal` ("name:reason").
- [x] PF2 Critters: they see about as far as they wake, chase far, hold on for a few seconds, patrol a visible loop
  (walk clip while walking, idle while pausing), end an unvisited patrol quietly, and every hit pushes and slows.
- [x] PF3 No pop-in or fade: a resting copy of each critter, Gomibu, Flanfuria and Tortidragon stands at its post between
  encounters (client copy, idle-animated, hidden while a live view of that beast exists); critters and Gomibu walk home
  before the encounter ends, with no fade.
- [x] PF4 Gomibu: a slow patrol round its nest while calm; sight 24.
- [x] PF5 Don Glaseon: a 3 s grace before "Left"; longer Bored/Tired/Search timers; the sleeping copy breathes.
- [x] PF6 Trap cakes: all three outside Don Glaseon's territory; a clearer prompt; a bite shows a line, plays a sound and
  sparkles; a refused bite says "Ya comiste de esta torta".
- [x] PF7 Frequency: summoned beasts rest 5 s between encounters; rolled beasts' chances up moderately; global cooldown
  10 s.
- [x] PF4b (found in the walked Play) Gomibu gives up after GiveUpSeconds held at its leash with the target out of jump
  range (it chased there for ever), and the walk home is never faded out by a stale escape timer.
- [x] PF5b (found in the walked Play) Don Glaseon: a ring of LeftMarginStuds 12 past the territory edge (his lash's
  shove) still counts as his ground.
- [x] PF8 Walked Play check of every item (see Evidence), commit a32e320 and earlier.

## What changed (old -> new)

### PF1 Director (`WildboundBeastDirector`, `WildboundBeasts`)

- `Director.uncapped(name)`: a `Config.SUMMONED` beast with `points == 0`. The MAX_ACTIVE check skips them and counts
  only the others. Every other rule stands: one of a kind (AlreadyActive), Don Glaseon one per server (BossBusy,
  BossResting), the Scuttler alone (Budget), safe zones, death, Silueta, respawn grace, species cooldown.
- `summonPass` and `bossPass` write the refusal to `Beast_lastSummonRefusal`. The roll keeps `Beast_lastRefusal`.

### PF2 Critters (`WildboundBeastConfig`, `WildboundBeastCandyCritter`, `WildboundCandyCritterAnimSpec`, `WildboundBeastsClient`)

| Critter | Wake | Sight | Leash | Abandon | Patrol radius | Chase | Escape | Give-up | Push | Slow |
|---|---|---|---|---|---|---|---|---|---|---|
| Mochimiau | 30 -> 45 | 14 -> 40 | 14 -> 34 | 22 -> 50 | 6 -> 10 | 11 -> 13 | 50 -> 90 | 2 -> 4.5 | 5 -> 8 (0.35 s) | 0.75 -> 0.7, 2.5 s |
| Canelin | 30 -> 45 | 14 -> 40 | 16 -> 36 | 24 -> 52 | 7 -> 11 | 12 -> 14 | 50 -> 90 | 2 -> 4.5 | none -> 8 (0.35 s) | 0.8 / 2 s -> 0.7 / 2.5 s |
| Flanin | 30 -> 42 | 14 -> 38 | 12 -> 32 | 20 -> 48 | 5 -> 9 | 9 -> 12 | 50 -> 90 | 2 -> 4.5 | none -> 6 (0.3 s) | 0.7, 3 s |
| Mielita | 32 -> 48 | 16 -> 42 | 14 -> 38 | 24 -> 55 | 7 -> 12 | 13 -> 14 | 50 -> 90 | 2 -> 4.5 | none -> 6 (0.3 s) | 0.75 -> 0.7, 3 s |
| GatoRepartidor | 24 -> 40 | 8 -> 34 | 8 -> 30 | 14 -> 45 | 5 -> 8 | 9 -> 12 | 50 -> 90 | 2 -> 4 | 2 -> 6 (0.3 s) | 0.9 / 1.5 s -> 0.8 / 2 s |

- New `IdleSeconds = 25`: a patrol nobody came near for 25 s walks home and ends "Idle".
- Patrol now alternates "Patrol" (walking; the walk clip) and "Calm" (standing at a point; the idle loop).
- Give-up, escape and idle end with a walk home ("Return", a calm phase) and an End at the post, with no Disengage fade.
  Death and a safe zone still end it at once.
- The target's client shows the beast's own `Text.BEAST[beast].hit` line on a hit that carries no line of its own (on
  top of the hit sound and camera shake it already played). Damage stays 0.

### PF3 Resting copies (`WildboundCandyRestingService`, `WildboundCandyRestingClient`, new)

- The server publishes `ReplicatedStorage.WildboundBeasts` attributes `RestingPost_<name>` (ground under the home site,
  plus Mielita's hover).
- Each client keeps a clone of `WildboundBeasts.Models.<name>` there, in `WildboundBeastsLocal`, tagged
  `WildboundResting`, with `BeastPhase = "Calm"`. The existing animators play its idle. It is destroyed while a live
  view with the same name exists, and a fresh clone comes back when the view ends.

### PF4 Gomibu (`WildboundBeastConfig`, `WildboundBeastGomibu`)

- Sight 16 -> 24, abandon 25 -> 36, patrol speed 7 (unused) -> 4, new PatrolRadiusStuds 8 and PatrolPauseSeconds 1.5.
- Calm is now a slow patrol round the nest.
- GiveUp stands GiveUpSeconds, then walks home ("Return") and ends at the nest; Escape walks home too.
- PF4b: held at its leash with the target out of jump range for GiveUpSeconds (2 s) it gives up; the retreat clears
  the escape and leash timers, so the shared guard (`Attack.guard`, which reads `e.farSince`) can no longer fade it out
  halfway home.

### PF5 Don Glaseon (`WildboundBeastConfig`, `WildboundBeastDonGlaseon`, `WildboundCandyDonGlaseonAnim`)

- New `LeftGraceSeconds = 3`: the target must stay outside the territory 3 s in a row before "Left".
- PF5b, new `LeftMarginStuds = 12`: "outside" means past the territory radius plus 12 studs, so a target his lash shoved
  just over the edge is still chased and lashed again.
- PatrolSeconds 12 -> 25 (Bored), ChaseSeconds 15 -> 30 (Tired), SearchSeconds 3 -> 5 (Lost).
- The sleeping copy breathes on each client while it has no published `Idle_Breath` clip: a chest bone's sway when the
  rig has one, else a 0.18-stud rise and fall over 3.6 s.

### PF6 Trap cakes (`WildboundCandyTrapCake`, `WildboundCandyTrapCakeService`, `WildboundText`, `WildboundCandyCakeClient` new)

- Spots (local to the Candy centre 612, -3; territory radius 62):
  - stair (6, -33), 33.5 studs from the centre -> riverside (-97, -55), on the left route, 111 studs out;
  - path (-60, 8), 60.6 studs -> (-72, 8), 72.4 studs;
  - rareNest (-86, -21) unchanged, 88.5 studs.
- Prompt "Comer porción" / "Torta", hold 0.3 s -> "Comer una porción" / "Torta de caramelo", hold 0.5 s.
- A bite sets the player attribute `WildboundCandyCakeSaid` ("rush:<n>" or "eaten:<n>"). The new client script shows
  `Text.CANDY_CAKE.rush` ("¡Subidón de azúcar! Corres más rápido") or `.eaten` ("Ya comiste de esta torta"). A rush also
  plays the catalogue's `eggBanked` bells and a burst of sparkles on the character.

### PF7 Frequency (`WildboundBeastConfig`)

| Value | Old | New |
|---|---|---|
| Species rest of every summoned beast (Nube, Abeja, Gomibu, Flanfuria, Tortidragon, five critters) | 10 s | 5 s |
| Don Glaseon species rest | 8 s | 5 s (his 4 s switch rest stays) |
| Viper base chance per 10 s (and Streamer, Root, Gaze, Lurker, which use Viper's) | 1/45 | 1/32 |
| Pouncer | 1/55 | 1/40 |
| Scuttler | 1/60 | 1/45 |
| DIRECTOR.GLOBAL_COOLDOWN | 15 s | 10 s |

Unchanged fair-strike rules: MIN_TELL 0.8 s, STRIKE_SEPARATION 0.8 s, MAX_CHANCE (0.20 per 10 s), MAX_MULTIPLIER 4,
MAX_POINTS 3, MAX_ACTIVE 2 for rolled beasts, the Nube's 60 s nap.

## Decisions taken for the user

1. Don Glaseon is also outside MAX_ACTIVE (he is a summoned points-0 beast); he stays one per server.
2. Summon refusals go to a new attribute `Beast_lastSummonRefusal`, so they never hide the roll's `Beast_lastRefusal`.
3. Critter chase speeds went up a little (12-14) but stay under a walking player's 16, so walking away still escapes.
4. The Gato stays the friendliest: the shortest sight (34) and leash (30), a lighter slow (0.8 for 2 s), the same 6-stud
   push as the smallest of the others.
5. Every critter hit pushes (6-8 studs); Canelin, Flanin and Mielita did not push before.
6. Calm endings walk home instead of fading, so the resting copy takes over on the same spot. Death and a safe zone still
   end an encounter at once (the live model then fades or is removed where it is).
7. Resting copies are client-side (in `WildboundBeastsLocal`, so the existing animators drive them); Don Glaseon keeps his
   server-side dormant copy.
8. Mochimiau's longer leash (34) can now bring a chase within about 24 studs of Don Glaseon's territory edge; the old
   "never shoves into the territory" margin no longer holds. Accepted: the player chooses to run there.
9. The stair cake left the tower stair (inside the territory) for the left route; both moved cakes stand at a route edge.
10. The cake hold is 0.5 s (not 1-1.5 s): short, but deliberate enough not to fire by accident.
11. Frequency raise: about +40 % on the rolled chances and a 10 s global cooldown; the caps stay.

12. PF4b and PF5b came out of the walked Play and were fixed test-first in the same step.
13. The cake hold is triggered in the Play check with the prompt's own `InputHoldBegin`/`InputHoldEnd` (the same input
    as holding E), never by calling the server.

## Evidence

Studio: place 122652861404212, instance db843df0-7649-423f-adb7-739088c9746a. Each write was preceded by a fingerprint
check (CRLF -> LF, trailing newlines stripped, byte length + Adler-32): Studio matched the repo HEAD every time, so
nothing had to be pulled. Writes used exact replacements (`multi_edit`, or a plain find-and-replace of `Source` in
`execute_luau`) and were read back.

### Studio suite runs (fresh loader)

The engine of `tools/studio-fresh-runner.luau` ran from a temporary ServerStorage StringValue, with only the SPECS
needed (the 23 suites below) and the `WildboundFreshRunnerLock` respected; the StringValues were destroyed at the end.

| Run | What | Result |
|---|---|---|
| 8a6e4cae | baseline, 23 suites | 369 passed, 0 failed |
| 526ffe2a | PF1 RED | 4 failed (MaxActive, refusal wiring) |
| 6dfafae5 | PF1 GREEN (7 suites) | 170 passed, 0 failed |
| 4d695c0e | PF2 RED | 10 failed |
| 3378128d | PF2 GREEN, 23 suites | 377 passed, 0 failed |
| 1cb4b764 | PF3 RED | the resting scripts did not exist |
| 69b77e65 | PF3 GREEN | 20 passed, 0 failed |
| a2221fbc | PF4 RED | 3 failed |
| 89bd6bec | PF4 GREEN (3 suites) | 83 passed, 0 failed |
| 96c1c5bf | PF5 RED | 3 failed |
| cc8bcd4c, 7b3cf2d4 | PF5 GREEN | 44 + 24 passed, 0 failed |
| 6b483f72 | PF6 RED | the cake client did not exist |
| cdf7f49d | PF6 GREEN (3 suites) | 45 passed, 0 failed |
| 2190b55e | PF7 RED | 11 failed |
| 65d0811e, dfccb68b | PF7 GREEN, 23 suites | 383 passed, 0 failed (65d0811e caught two stale numbers in the Director suite, updated as deliberate changes) |
| 78b3ffb7, 7e427538 | PF4b/PF5b RED | 2 + 1 failed |
| f6a3ac53 | PF4b/PF5b GREEN, 23 suites | 384 passed, 0 failed |

Suites: BeastAbeja, BeastAnimPlan, BeastAttack, BeastAudience, BeastCandyCritter, BeastDirector, BeastDonGlaseon,
BeastEncounters, BeastFlanfuria, BeastGomibu, BeastNube, BeastTortidragon, BeastWiring, BossRobustness, CandyClipKit,
CandyClipPublish, CandyDonGlaseon, CandyLayout, CandyNests, CandyRoar, CandyTrapCake, PortalService, Text. The
pre-existing reds of the handoff (section E) are in suites that were not run here.

### Fingerprints (Studio == repo after each write)

Final check, all 23 touched scripts equal (bytes, Adler-32):

| Script | Bytes | Adler-32 |
|---|---|---|
| WildboundBeastDirector | 16954 | 710c53b6 |
| WildboundBeastDirector_Test | 51821 | 19d23b6b |
| WildboundBeastConfig | 43074 | 2140f0bb |
| WildboundBeastCandyCritter | 13201 | 2471baad |
| WildboundBeastCandyCritter_Test | 27857 | 560d9f83 |
| WildboundBeastGomibu | 10336 | 70e02504 |
| WildboundBeastGomibu_Test | 15168 | 0422dc6f |
| WildboundBeastDonGlaseon | 21449 | db678d83 |
| WildboundBeastDonGlaseon_Test | 27540 | 64e4f88f |
| WildboundBeasts | 54174 | 6ea75702 |
| WildboundBeastsClient | 60063 | a50d25e0 |
| WildboundCandyTrapCakeService | 11016 | 1f518515 |
| WildboundCandyTrapCake | 6761 | deb196c3 |
| WildboundCandyTrapCake_Test | 12582 | 24e4f2c1 |
| WildboundText | 41118 | 32aa9cc6 |
| WildboundCandyDonGlaseonAnim | 6830 | 4817c91f |
| WildboundBeastNube_Test | 11037 | 43f66afd |
| WildboundBossRobustness_Test | 8474 | 373bd3eb |
| WildboundCandyClipKit_Test | 14896 | bdcf218d |
| WildboundCandyCritterAnimSpec | 4017 | a6e10f17 |
| WildboundCandyRestingService (new) | 2393 | f8a842a0 |
| WildboundCandyRestingClient (new) | 3294 | c89c6be8 |
| WildboundCandyCakeClient (new) | 3449 | b7d78713 |

### Walked Play observations

Two Plays, each with `WildboundPlayLock = "A1-playfix"` (both locks were nil before), stopped and cleared afterwards.
The character always walked with `character_navigation` from spawn (298, -3) along the road into the biome; nothing was
teleported. A client sampler (read only) logged every 0.5 s the position, walk speed, slow and push, every live beast
view (name, phase, distance, fade) and the on-screen beast/cake lines.

Play 1:

- At start all eight resting copies stood at their posts, idle (Calm): Gomibu (446, -15), Gato (466, 34), Mochimiau
  (539, 43), Flanfuria (542, -41), Canelin (664, -101), Flanin (664, 71), Mielita (542, 139, 2.5 up), Tortidragon
  (510, -143). The three cakes stood at riverside (515, -58), path (540, 5), rareNest (526, -24), prompt "Comer una
  porción" / "Torta de caramelo", hold 0.5 s.
- Gomibu: seen in Calm at 26 studs, Notice at 18 ("Gomibú te vio"), Chase, Telegraph, Jump, Hit: walk speed 16 -> 12.8,
  pushed about 8 studs, line "¡Boing!". It followed the player out of its patrol and attacked again.
- Gato Repartidor (with Gomibu still on the player, so two at once): Notice at 23 studs, Chase, the fries lob, Hit:
  push, slow 0.8, line "¡Papas por todos lados!". Walking away, its last view was in Return at (465.0, 33.4), its post,
  fade 0, then the view ended and the resting copy stood at (466, 34): no pop, no fade.
- Mochimiau: Notice at 35, Chase, leap, Hit: 16 -> 11.2 (0.7), pushed about 9 studs, "¡Rodada cremosa!". Held at its
  leash out of reach it gave up after 4.5 s, walked home (Return, about 10 studs/s) and ended there; 5 s later it was
  summoned again at its post (Patrol).
- Path cake: hold -> "rush:1", walk speed 20, line "¡Subidón de azúcar! Corres más rápido", sparkles on the root; a
  second hold -> "eaten:2", line "Ya comiste de esta torta".
- RareNest cake (the disguised one, crumbs on): walking within 5 studs sprang it, the lash pushed the player about 12
  studs, and the decoys popped (confetti parts left in the cake folder).
- Don Glaseon's sleeping copy at (578, -3): the Spine_Upper bone swayed between +0.039 and -0.043 rad over 2.4 s.
- Don Glaseon: Suspicious at 22 studs, Roar, Telegraph, Attack, Hit "¡Latigazo!" (push to (549, 5), 63.5 studs from
  the centre). It kept chasing (Chase 24 -> 8 studs) for 3 s, then LoseTarget "Left" and Return, because the player
  stood just outside the territory. This led to PF5b.
- Flanin: Notice at 31, Chase, the wave, Hit (push, slow, "¡Pegajoso!"); it followed about 40 studs, then walked home.
- Mielita: Notice at 35, Chase, pollen, Hit (push, slow, "¡Achís! Polen dulce").
- Canelin: Notice at 32, Chase, the roll, Hit (push, slow, "¡Giro de canela!").
- Gomibu, left standing just past its leash, kept chasing there; when the player walked off it gave up and walked home,
  but faded out halfway at (427.5, -11) ("Disengage"). This led to PF4b.
- Telemetry: `Beast_lastSummonRefusal = Mochimiau:AlreadyActive` (the new attribute works).
- No script errors from these scripts in the console (only the known TexturePack and DataStore noise). The character
  died once on the road west of the biome (x 370); the cause was not identified (no candy creature deals damage).

Play 2 (after PF4b and PF5b):

- Gomibu: chased the player to just past its leash, held there 2 s, GiveUp ("Gomibú volvió a su nido"), Return with no
  fade, the view ended and the resting copy stood at (446, -15).
- Don Glaseon: the first lash pushed the player to (549, 5) (63.5 studs from the centre, inside the 12-stud ring). He
  kept chasing, closed to 8 studs and lashed again 8 s later; the second shove to (536, 9) (76.6 studs) left the ring,
  and he let go 4.6 s later. The encounter lasted 20 s (it was 5-8 s).
- Riverside cake: hold -> rush, walk speed 20, the line.
- Tortidragon: Notice at 16, Chase, the fan, Hit ("¡Confitazo!"); its resting copy was gone while the live one was out.
- Flanfuria (brain unchanged) faded at its own post when the player left; its resting copy then stood there.
- No "Robar" prompt exists in the Caramelo (all 16 prompts listed: 12 nest eggs "Tomar el huevo", hold 0.5-1.8 s; the
  portal; the three cakes) and no prompt anywhere has a 3 s hold. The only "robar" words are the tutorial and HUD
  lines about stealing eggs. The owner's "robar porción" was most likely the old "Comer porción" prompt; it now reads
  "Comer una porción" / "Torta de caramelo".

What was not checked: two players (the resting copies and the cap were seen by one player only); a phone; the Nube and
the Abeja beyond seeing the Abeja wake; the rolled forest beasts' new frequency in Play (covered by the suites only);
the trap re-arming 30 s after Don Glaseon sleeps again.

## Not done

- The extra mechanics on the creature sheets (pack 6): Mochimiau's cream puddle, Flanin's caramel trail and extra
  bounces, Mielita's pollen trail and swarm, Canelin's glaze variants, the Gato's golden order (+15 % speed) and call for
  backup. Recorded for a later step.
- Don Glaseon's clips: the owner still has to publish them to the group ("Save to Roblox", Creator = group) and fill
  `WildboundCandyDonGlaseonClips.IDS`. Until then the live boss has no clips; only the sleeping copy breathes.
- Flanfuria and Tortidragon still fade out where they give up (their brains were not changed); their resting copy then
  reappears at the post.
- While one cake is Don Glaseon in disguise, his bed (BossHome) stays empty by design (DG7); at the start of a Play it
  was empty. Not changed here.
- Gomibu's GiveUp line ("Gomibú volvió a su nido") shows while it still stands, before the walk home.
