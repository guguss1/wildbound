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
- [x] PF9 (independent review) The cake line's old fade no longer hides a newer line: a second bite 2.2-2.7 s after the
  first left "Ya comiste de esta torta" invisible (the first line's 0.5 s fade tween kept running). Fixed test-first;
  walked Play 3 (see Evidence).

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
- PF9: `show()` keeps the delayed fade tween in a local `fade` and cancels it before showing a new line, so a fade
  started for the previous line cannot set the new line's transparency back to 1.

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
14. Independent review: the cake-line race was accepted and fixed (PF9). Its three leftovers (Flanfuria's fade, the
    two-player bystander End, the path cake inside the 74-stud ring) are not defects of this step and were left as they
    are; the bystander case needs a two-player check before any change.

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
| 7d9f76b2 | PF9 RED (CandyTrapCake only) | 9 passed, 1 failed ("the fade tween is kept") |
| ede28033 | PF9 GREEN (CandyTrapCake only) | 10 passed, 0 failed |

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
| WildboundCandyTrapCake_Test | 12582 -> 13522 (PF9) | 24e4f2c1 -> 6b64288c |
| WildboundText | 41118 | 32aa9cc6 |
| WildboundCandyDonGlaseonAnim | 6830 | 4817c91f |
| WildboundBeastNube_Test | 11037 | 43f66afd |
| WildboundBossRobustness_Test | 8474 | 373bd3eb |
| WildboundCandyClipKit_Test | 14896 | bdcf218d |
| WildboundCandyCritterAnimSpec | 4017 | a6e10f17 |
| WildboundCandyRestingService (new) | 2393 | f8a842a0 |
| WildboundCandyRestingClient (new) | 3294 | c89c6be8 |
| WildboundCandyCakeClient (new) | 3449 -> 3602 (PF9) | b7d78713 -> 8f81b99d |

PF9: before writing, Studio matched the repo HEAD for both scripts (3449 b7d78713, 12582 24e4f2c1); after the
`multi_edit` writes, Studio and the repo both read 3602 8f81b99d and 13522 6b64288c.

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

Play 3 (PF9, after the independent review; `WildboundPlayLock = "A1-playfix-review"`, both locks nil before, stopped
and cleared after):

- Walked from spawn (298, -3) with `character_navigation` (the first leg stopped at (368, -11); a second leg reached
  (533, 5), 6.7 studs from the path cake). HP 100 throughout.
- On arrival the cake folder was empty (all three had popped; the cause was not seen, the player had not gone near the
  rareNest cake). They regrew by themselves a little later (the 90 s Regrow), all three back.
- Path cake: hold -> "rush:1", walk speed 16 -> 20, line "¡Subidón de azúcar! Corres más rápido" (transparency 0);
  hold again -> "eaten:2", "Ya comiste de esta torta" stayed visible (transparency 0) for the whole 2 s sampled, then
  faded (1.00 at 6.4 s).
- The race itself: a bite timed so its line came 2.38 s after the previous one (inside the old 2.2-2.7 s window) ->
  "eaten:4", transparency 0.00 at +2.58, +2.80, +3.00, +3.22, +3.43, +3.63 s. Before PF9 the reviewer saw transparency 1
  in this window.

Review leftovers (no change, recorded): Flanfuria still fades (brain unchanged, see Not done); with two players a
bystander who leaves audience range gets an End for the live view, so their resting copy may reappear at the post while
the beast is out elsewhere (code read only, two players not checked); the path cake (72.4 studs from the centre) lies
inside Don Glaseon's 74-stud "still his ground" ring (62 + 12) but outside his territory, so walking to it does not wake
him.

What was not checked: two players (the resting copies and the cap were seen by one player only); a phone; the Nube and
the Abeja beyond seeing the Abeja wake; the rolled forest beasts' new frequency in Play (covered by the suites only);
the trap re-arming 30 s after Don Glaseon sleeps again.

## Not done

- (Done in step A2 below: the extra mechanics on the creature sheets.)
- Don Glaseon's clips: the owner still has to publish them to the group ("Save to Roblox", Creator = group) and fill
  `WildboundCandyDonGlaseonClips.IDS`. Until then the live boss has no clips; only the sleeping copy breathes. (Step A3
  below: until then he, his sleeping copy and Tortidragon play their clip data live.)
- Flanfuria and Tortidragon still fade out where they give up (their brains were not changed); their resting copy then
  reappears at the post.
- While one cake is Don Glaseon in disguise, his bed (BossHome) stays empty by design (DG7); at the start of a Play it
  was empty. Not changed here.
- Gomibu's GiveUp line ("Gomibú volvió a su nido") shows while it still stands, before the walk home.

# Step A2: the creature sheets' extra abilities

## Objective

Give the new candy creatures the special mechanics of the "Otras habilidades" box of their pack 6 sheets
(`Pack_6_Criaturas_Rig_Animacion`; our own designs and names stay, the sheets give mechanics only), as data-driven extras
of the generic brain `WildboundBeastCandyCritter` plus one small new module for La Duquesa Burbuja. Damage stays 0
(push and slow only), every slow goes through the shared non-stacking slot and the `WildboundBeastChase.EFFECTS` caps,
and every check in Play walks the character in like a player.

## Checklist

- [x] A2-1 Mochimiau: "Salpicadura de crema", a cream puddle where its leap lands (2 s, -25 % while inside);
  "Comportamiento social", one more hop right after the recovery if the target is still within 9 studs (once per
  cooldown).
- [x] A2-2 Canelin: it spins in place on the tell (clip Spin) and its roll leaves a glaze trail along the lane (-20 %,
  each patch 2 s).
- [x] A2-3 Flanin: "Charco de caramelo", a caramel trail while it hops after a player (-20 %, each patch 2 s); "Rebote
  continuo", up to two more bounces right after the recovery.
- [x] A2-4 Mielita: "Ruta de polen", a pollen trail while it flies after a player (-15 %, each patch 2 s); "Enjambre",
  every 18 s of a chase two pollen puffs beside the target (1 s tell, -15 % 2 s).
- [x] A2-5 Gato Repartidor: "Entrega especial", one encounter in four it walks up and hands a golden order (+15 % walk
  speed for 10 s, a line on screen, chime and sparkles) and walks home; "Llamado de repartidores", every 20 s of a chase
  a helper Gato appears 10 studs beside the target, throws fries once (1 s tell) and leaves.
- [x] A2-6 La Duquesa Burbuja: seated, but while a player stands on the Gran Torta's summit she throws "Bombas de
  chicle" every 10 s: three slow bubbles that pop in small circles (-30 % 2 s, push 4, ring shown 1.8 s before the
  pop), with her Charge and Whip clips. CT3's nest and CT4 Frutillon untouched.
- [x] A2-7 (found in walked Play 1) Flanin's bounces never came: its burst pushed the player 6 studs out of a 7-stud
  follow range. Follow range 16 (burst radius 10 + push 6), test-first.
- [x] A2-8 (found in walked Play 1) La Duquesa never threw: Frutillon bumped the climber off the summit about 1.5 s
  after arriving, before her first volley (1.5 s). First volley 0.3 s after arrival, test-first.
- [x] A2-9 Walked Play checks of each (see Evidence); commits def6c83 (specs), 755027b (implementation), 04a6128
  (walked-Play fixes).

## What changed

### Data (`WildboundBeastConfig`, `tuning.Extras` of each critter, all frozen)

| Creature | Extra | Numbers |
|---|---|---|
| Mochimiau | Puddle | radius 4, life 2 s, slow 0.75 for 2 s |
| Mochimiau | Follow | Max 1, range 9 |
| Canelin | Trail (Phase Release) | every 2.5 studs, radius 2.5, life 2 s, slow 0.8 for 2 s |
| Flanin | Trail (Phase Chase) | every 3 studs, radius 2, life 2 s, slow 0.8 for 2 s |
| Flanin | Follow | Max 2, range 16 (was 7, A2-7) |
| Mielita | Trail (Phase Chase) | every 3 studs, radius 2.5, life 2 s, slow 0.85 for 2 s |
| Mielita | Swarm | every 18 s (first 3 s into a chase), range 16, 2 puffs 5 studs beside the target, radius 3.5, tell 1 s, slow 0.85 for 2 s |
| GatoRepartidor | Gift | one encounter in 4 (by its number), hand-over at 4 studs after 1.5 s, x1.15 for 10 s |
| GatoRepartidor | Call | every 20 s (first 4 s into a chase), range 14, helper 10 studs beside the target, fries radius 4, tell 1 s, push 6, slow 0.8 for 2 s, helper stays 2.5 s |

### Brain (`WildboundBeastCandyCritter`)

- Patches: a "Patch" event (x, y, z, r, life, untilAt) per puddle or trail piece; the brain keeps the live ones (at most
  16) and, while the target's root is inside one, emits an `Afflict` (slow, slowSeconds, patch = true) at most once per
  SlowSeconds + 0.3 s. The beast server applies it with `applySlow` (clamped by the EFFECTS caps, never stacked on a
  slow already running). Patches keep slowing while the creature walks home.
- Follow: a fresh attack starts a chain of up to Max follow-ups; after a strike with follow-ups left the next attack
  may open right after the recovery (full tell each time); when the target leaves the follow range the chain ends and
  the cooldown counts from its last strike.
- Side attacks (Swarm, Call): opened only in Chase, locked at once, strike at least MIN_TELL later, settled on their own
  clock whatever the phase; the Call emits a "Helper" event; the Swarm lands as an Afflict (no push), the helper's fries
  as a Hit (push and slow, damage 0, keepsEgg).
- Gift: `e.gift` from the encounter's number ("beast:<n>", n % 4 == 0). It chases without attacking, stands "Deliver"
  for 1.5 s within 4 studs, emits "Gift" and walks home ("Delivered").

### Server and clients

- `WildboundBeasts` (on `world`, no new top-level local): `candyPatch` lays a flat disc in the creature's colour
  (Mochimiau cream, Canelin cinnamon, Flanin caramel, Mielita pollen yellow) in `Workspace.WildboundCandyExtras`,
  fades it over its life and removes it; `candyHelper` parks an anchored copy of the Gato model there until untilAt;
  `candyGift` sets `WildboundCandyOrderUntil` and `WildboundCandyCakeSaid = "order:<n>"` and counts
  `Beast_candyGifts`.
- `WildboundServer` (two additive lines in applyCarry and one new `do ... end` block): x1.15 while the order lasts,
  capped at 26 like the cake rush, re-applied when it starts and ends.
- `WildboundCandyCakeClient`: "order" chimes and sparkles like a rush; `WildboundText.CANDY_CAKE.order` = "¡Pedido
  dorado! Corres más rápido"; `Text.BEAST.GatoRepartidor.phases.Deliver` = "¡El Gato Repartidor te trae un pedido!".
- `WildboundCandyCritterAnimSpec`: Canelin Telegraph -> Spin; Gato Deliver -> Deliver; Deliver is a brain phase (idle
  for the others).
- `WildboundCandyDuquesa` (new, ServerStorage, `tools/`) pure rules and `WildboundCandyDuquesaService` (new): rings,
  bubbles and pops are server parts in `Workspace.WildboundCandyDuquesa`; her clips through the attribute
  `WildboundCritterCue` ("Charge:<n>", "Whip:<n>"), which `WildboundCandyCritterAnim` plays as one-shots on the
  preview model; slow through `WildboundBeastSlowUntil` with `Chase.clampSlow`, push through the `WildboundBeastPush`
  slot (Frutillon's pattern).

## Decisions taken for the user (A2)

1. Patches are server-made parts (seen by every player, faded by a server tween), not a new client renderer: no new
   remote, no change to the beast client.
2. Every patch lives 2 s and slows for 2 s (the sheets' "2 s" read as both); a target standing in one is slowed once per
   2.3 s at most, and never on top of a slow already running (the shared slot). Consequence seen in Play: a stronger
   hit slow can be pre-empted by a weaker patch slow landing first (Canelin's roll: the glaze -20 % came 0.1 s before
   the roll's -30 %), and a puddle under a player its hit just slowed does not add anything. (The pre-emption was fixed
   after the review: A2-10.)
3. Only the encounter's target is slowed by patches; other players only see them.
4. Mochimiau's "Comportamiento social" (the sheet: several Mochimiau attack in sequence) is one more hop right after
   the recovery while the target stays within 9 studs, once per cooldown, as the step asked.
5. Flanin's follow range is 16 so a bounce reaches a player its own burst pushed (A2-7).
6. The Gato's gift is chosen by the encounter's number (one in four), deterministic and testable; a gift encounter
   never attacks and never calls a helper.
7. The helper Gato is a static copy (no live animation: the critter animator only drives models in
   `WildboundBeastsLocal` and the preview folder); it shows for 2.5 s.
8. The swarm puffs land beside the target (not on it), so standing still is safe and a sidestep may not be.
9. La Duquesa targets the first player found on the summit; her volley resolves even if that player leaves; she
   throws 0.3 s after a player arrives (A2-8) and every 10 s after (a short drop keeps that cadence: A2-12).
10. Her slow and push are a copy of the beasts' rules inside her service (same attribute slot and caps), rather than a
    refactor of `WildboundBeasts.applySlow`, to keep the shared beast server untouched there.
11. The fresh runner used for the A2 runs is the engine of `tools/studio-fresh-runner.luau` (the same loader, clone and
    lock code) with a shorter report and no Workspace leak scan, kept in a temporary ServerStorage StringValue
    (`WildboundA2RunnerEngine`, destroyed at the end) with only the needed SPECS passed in each call.
12. Two test mistakes found on the first GREEN run were fixed in the tests (no behaviour change): the encounter ids
    "swarm" and "call" made every tell id contain ":swarm:" / ":call:", and the "out of reach" spot for Mochimiau's
    follow test was inside its follow range. One real bug from the same run was fixed in the brain: a non-roll attack
    reset the trail spacing (Mielita laid two pieces 2.1 studs apart).

## Evidence (A2)

Studio: place 122652861404212, instance db843df0-7649-423f-adb7-739088c9746a. Before the first write every touched
script matched the repo HEAD (CRLF -> LF, trailing newlines stripped, length + Adler-32), so nothing was pulled. Writes
by `multi_edit` exact replacements (new scripts created the same way), read back and compared after each batch.

### Runs (fresh loader, `WildboundFreshRunnerLock` respected)

| Run | What | Result |
|---|---|---|
| 54e3cd7d | RED, CandyCritter + CandyDuquesa | 20 passed, 9 failed; Duquesa suite: module missing |
| ef5e2634 | first GREEN try | 30 passed, 4 failed (decision 12) |
| b8eb0ed8 | GREEN, 15 beast suites (incl. CandyCritter 29, CandyDuquesa 5) | 297 passed, 0 failed |
| 3cfc2888 | GREEN, 12 candy/text/portal suites | 121 passed, 0 failed |
| ee29df73 | A2-7/A2-8 RED | 2 failed (Flanin follow range 7 under 16; first volley 1.5 s) |
| 647956d3 | A2-7/A2-8 GREEN (CandyCritter, CandyDuquesa, Encounters, Director, Frutillon) | 121 passed, 0 failed |

Also: `loadstring` compiles of WildboundServer (still under the local limit), WildboundBeasts, the Duquesa service and
the two clients.

### Fingerprints (Studio == repo, final)

| Script | Bytes | Adler-32 |
|---|---|---|
| WildboundBeastConfig | 45611 | 35b9070e |
| WildboundBeastCandyCritter | 23077 | 7f083f98 |
| WildboundBeastCandyCritter_Test | 45711 | 235d9bdd |
| WildboundBeasts | 57959 | af61499c |
| WildboundServer | 222665 | 4e5d92e9 |
| WildboundText | 41319 | 4733e094 |
| WildboundCandyCakeClient | 3735 | bb53e5e3 |
| WildboundCandyCritterAnim | 10399 | 186291d9 |
| WildboundCandyCritterAnimSpec | 4267 | 397e608e |
| WildboundCandyDuquesa (new) | 4478 | 6d3f85c6 |
| WildboundCandyDuquesaService (new) | 7308 | 4cfa9c21 |
| WildboundCandyDuquesa_Test (new) | 7717 | c3bcae2a |

### Walked Play observations

Two Plays (`WildboundPlayLock` "A2-extras" and "A2-extras-2", both locks nil before, Play stopped and the lock cleared
after each). The character always walked with `character_navigation` from spawn (298, -3) along the road and through
the biome, and up the Gran Torta's stair step by step; nothing was teleported. Read-only samplers: a server log every
0.5 s (position, walk speed, slow and order timers, push slot, cake line attribute) plus new parts in
`WildboundCandyExtras` / `WildboundCandyDuquesa` and La Duquesa's cue; a client log of the beast events
(`BeastEvent.OnClientEvent`), the views' phases and clips, the on-screen line and the parts the client sees.

Play 1:

- Gato (beast:2): helper `Helper_GatoRepartidor` appeared 10 studs from the player (server and client), the fries hit:
  push and 16 -> 12.8 (0.8) for 2 s.
- Mochimiau: leap -> puddle at the landing (527.1, 40.1), hit (push 8, 0.7); 1.9 s later the second hop landed where the
  push left the player (535.6, 38.8), second puddle and hit; the next attack 7.3 s later (cooldown). The puddle slow
  was not seen applied: the hit's own slow was always running (decision 2).
- Mielita: pollen trail pieces about 3.4 studs apart, seen by the client; swarm tells (`beast:5:swarm:14`, 1.00 s, two
  circles) every ~21 s; walking back through the trail gave an `Afflict` patch = true, slow 0.85 (not applied: the lob's
  slow was running).
- Flanin: caramel trail while chasing (client saw each patch, transparency 0.17 fading); three hits 8.3 s apart and no
  bounce: its push moved the player out of the follow range -> A2-7.
- Canelin: Telegraph clip Spin, then the roll laid five glaze patches along the lane; the glaze slow was applied
  (16 -> 12.8 for 2 s) and the roll's 0.7 hit 0.1 s later did not stack on it.
- La Duquesa: the player reached the summit (607.4, 44.0, -7.7) and Frutillon bumped it off within 1.5 s, before her
  first volley -> A2-8.

Play 2 (after A2-7 and A2-8):

- Gato (beast:2): call `beast:2:call:2` with helper, fries hit (0.8).
- Flanin (beast:4): burst at 6131.3, bounce at 6134.0, bounce at 6136.7 (1.25 s tells): two more bounces, then the
  cooldown.
- La Duquesa: on arrival (6214.9) Charge cue, three rings, Whip 0.6 s later, three bubbles from her hands, three pops
  1.9 s after the rings; the client saw her Charge and Whip clips and every part. Second climb: standing on the summit
  at (609.8, 44.0, -5.3), the pop of volley 2 slowed 16 -> 11.2 for 2 s and pushed about 3.7 studs; volley 3 came
  10.1 s later, hit again, then Frutillon bumped the player off the summit (CT4 still works).
- Gato gift: walking in from the north-west (to meet the Gato before Gomibu), encounter beast:12 walked up, "Deliver",
  `Gift`, line "¡Pedido dorado! Corres más rápido" on screen (transparency 0), walk speed 16 -> 18.4 for 10 s (back to
  16 at the end), `Beast_candyGifts = 1`, Return "Delivered", End at its post. The next Gato encounter attacked and
  called its helper as usual.
- No script errors from these scripts in the console (only the known TexturePack, asset and DataStore noise).

What was not checked: a patch slow applied while no other slow was running for Mochimiau's puddle and Flanin's or
Mielita's trails (the brain's Afflict was seen; the shared slot was busy); two players (bystanders seeing the patches
and the helper, a second player on the summit); a phone; the helper Gato's look from far away (it is a static pose);
a Gato call staggered against another strike (claimStrike) in Play. Sheets read: 01 (Princesa Chicle, for La Duquesa);
the other sheets' mechanics were taken from the step's own summary of their "Otras habilidades".

## A2 review fixes

An independent review (walked Play, lock "review") found two defects. Both were real and both are fixed test-first.

### Checklist

- [x] A2-10 Canelin's own glaze pre-empted its roll's slow: the first glaze piece lies where the roll starts, next to
  the player it rolls into, so the patch `Afflict` (0.8) took the one slow slot about 0.1 s before the roll's `Hit`
  (0.7), and every roll hit landed as -20 % instead of -30 %. Fix: `stickyPatches` (WildboundBeastCandyCritter) never
  slows while the creature's own attack is open (Telegraph or Release); the strike settles first. This covers every
  critter with patches (Flanin's and Mielita's chase trails and Mochimiau's puddle too). Spec: "A2 Canelin: a target
  on its lane gets the roll's -30 %, not its own glaze's -20 %, first".
- [x] A2-11 La Duquesa's pops almost never reached a walking climber: Frutillon woke, told and rolled within about
  0.8 s of arrival, while her first pop needs 0.3 + 0.6 + 1.2 = 2.1 s. Fix: Frutillon takes `WAKE_SECONDS = 2` to wake
  up (new phase "Waking", no tell, no roll) before his first tell, so his first roll is at least 2.8 s after arrival.
  If nobody is left when he has woken up he waits and sleeps again after `SLEEP_SECONDS` as before. CT4 specs updated
  (Wake alone, then Telegraph at arrival + 2 s); new cross spec in WildboundCandyDuquesa_Test: a climber on
  Frutillon's rest spot (his fastest bump) is hit by her first pop at least 0.3 s before his first roll starts.
- [x] A2-12 Her cadence restarted on every climb (`state.nextAt = nil` as soon as nobody stood on the summit), so a
  bumped player who climbed straight back got a volley 0.3 s later. Fix: `REARM_SECONDS = 5`; the 10 s cadence is kept
  across a shorter absence and only 5 s with nobody up there starts it again. Spec: "A2 review: a short drop off the
  summit keeps her 10 s cadence; a long absence starts it again".
- [x] A2-13 Walked Play re-check of A2-10 and A2-11 (below). Commits f8003ed (specs) and 53d58d7 (fix).

### Decisions taken for the user (A2 review)

13. The patch fix gates the patch slow on the creature's open attack (the reviewer's first option) instead of tagging
    patches by attack id: simpler, and it also stops a chase trail from pre-empting Flanin's burst or Mielita's lob.
    A patch slow can still land right after the strike (it is refused by the shared slot while the hit's slow runs).
14. For La Duquesa the fix is on Frutillon's side (a 2 s wake-up) rather than a faster first bubble: her ring keeps its
    full 1.8 s tell (well over MIN_TELL), and Frutillon waking up slowly reads naturally. It makes the summit a little
    friendlier for 2 s; Frutillon still bumps players off afterwards.
15. A short drop keeps her cadence for 5 s (REARM_SECONDS); after that the next arrival is greeted at 0.3 s again.

### Evidence

Studio: place 122652861404212, instance db843df0-7649-423f-adb7-739088c9746a. Before the first write the six touched
scripts matched the repo HEAD c501a4f (normalised length + Adler-32): WildboundBeastCandyCritter_Test 45711,
WildboundCandyDuquesa_Test 7717, WildboundCandyFrutillon_Test 7624, WildboundBeastCandyCritter 23077,
WildboundCandyDuquesa 4478, WildboundCandyFrutillon 8096. Writes by `multi_edit` exact replacements only.

| Run | What | Result |
|---|---|---|
| 3c3172c8 | RED: CandyCritter, CandyDuquesa, CandyFrutillon | 38 passed, 5 failed (the 5 new or changed cases, for the expected reasons) |
| 6eb01cb9 | GREEN: the same three suites | 43 passed, 0 failed |
| 9938988a | GREEN: the same plus BeastEncounters_Test | 73 passed, 0 failed |

Runner: the engine of `tools/studio-fresh-runner.luau` in a temporary ServerStorage StringValue
(`WildboundA2ReviewRunnerEngine`, destroyed afterwards) with only these SPECS; `WildboundFreshRunnerLock` respected.

Final fingerprints (Studio == repo):

| Script | Bytes | Adler-32 |
|---|---|---|
| WildboundBeastCandyCritter | 23214 | c3706d8b |
| WildboundCandyDuquesa | 4818 | 4ee1f5ec |
| WildboundCandyFrutillon | 8618 | c186bae4 |
| WildboundBeastCandyCritter_Test | 46690 | f2ced28d |
| WildboundCandyDuquesa_Test | 10173 | 072ea86b |
| WildboundCandyFrutillon_Test | 8537 | 1a4787f5 |

Walked Play (lock "A2-review-fix", both locks nil before; Play stopped and the lock cleared after). The character
walked with `character_navigation` only, from spawn (298, -3) east through the biome to Canelin, then up the Gran
Torta's stair step by step to the summit; nothing was teleported. Samplers only read state: a server log every 0.1 s
(walk speed, push slot, position), Frutillon's `BeastPhase` and new parts in `Workspace.WildboundCandyDuquesa`; a
client log of `BeastEvent` (Tell, Phase, Patch, Hit, Afflict).

- Canelin (beast:3), roll 1: Telegraph 7249.0, Release 7249.9, four glaze patches along the lane, `Hit` slow 0.7 at
  7250.48, then the patch `Afflict` 0.8 at 7250.58 (after the hit, refused by the slot). Server: walk speed 16 -> 11.2
  with the push at 7250.6, back to 16 at 7253.1 (2.5 s). Roll 2: the same (Hit 0.7 at 7258.01, Afflict at 7258.13,
  16 -> 11.2 at 7258.1, back at 7260.6). Before the fix the same walk gave 12.8 on every roll hit.
- La Duquesa and Frutillon: on the stair Don Glaseon (beast:4, 0.85) and Frutillon's seeds bumped the climber down
  twice; the third climb reached the summit. Frutillon `Waking` at 7394.4 (arrival), her rings at 7394.9, bubbles
  7395.5, Frutillon `Telegraph` only at 7396.4, her pops at 7396.7: walk speed 16 -> 11.2 and pushed about 4 studs
  (608.8, -7.7 -> -3.7), back to 16 at 7398.8. Frutillon rolled at 7397.2, 7399.6, 7402.1 and 7404.4 without reaching
  the player standing 3.3 studs from her seat. Volley 2 at 7404.9 (10.0 s later): pops at 7406.8, hit again (11.2).
  Frutillon's roll at 7409.0 then bumped the player off the summit (CT4 still works); he slept at 7415.3.
- Console: no errors from these scripts (only the known TexturePack, asset and DataStore noise).

Not checked in Play: A2-12 (climbing back within 5 s after a bump: the walk back up the stair takes longer than 5 s,
so in practice the spec is what covers it); the patch gate for Flanin, Mielita and Mochimiau in Play (covered by the
same one-line gate and the specs); two players; a phone. Observation, not changed: a player standing within about
3.3 studs of La Duquesa's seat is out of Frutillon's reach (ring 6.3, hit 3), so standing next to her is a safe spot
from his rolls (pre-existing CT4 geometry).

# Step A3: Tortidragon and Don Glaseon animate live

## Objective

Tortidragon and Don Glaseon played no animation: their clip ids (`WildboundCandyTortidragonClips.IDS`,
`WildboundCandyDonGlaseonClips.IDS`) are empty because the owner cannot publish to the group yet, and their clients only
played published ids. Make them animate live with no published asset, the way the six new critters do (the client
writes `Bone.Transform` from the clip data), with as little duplication as possible. A published `Clip_<name>` id still
wins when one exists. Gomibu and Flanfuria (published group clips) are left as they are.

## Checklist

- [x] A3-1 `WildboundCandyClipKit.fromLegacy`: the older `{ time, pose }` clip modules (Enum priority) become kit-format
  clips (`Kit.define`), sampled by `Kit.sample` with the same cubic in-out easing their KeyframeSequences use. Poses are
  shared, not copied; the source modules are unchanged.
- [x] A3-2 Replicated data copy: `WildboundCandyTortidragonService` and `WildboundCandyDonGlaseonService` clone their
  ServerStorage clip module into `ReplicatedStorage.WildboundCandyCritterClipsTortidragon` / `...DonGlaseon` at start
  (one source of truth; no second copy in the repo or the place).
- [x] A3-3 `WildboundCandyCritterAnimSpec`: entries `Tortidragon` (idle `Idle`) and `DonGlaseon` (idle `Idle_Breath`),
  `legacy = true`, phase maps = the old clients' `CLIP` tables, plus Don Glaseon's `Stagger` -> `HitReact_ImmuneBat`.
  New `Spec.SCENERY = { DonGlaseonDormant = "DonGlaseon" }`; `critterName` resolves it.
- [x] A3-4 `WildboundCandyCritterAnim` (the shared live player): converts legacy data, animates `Spec.SCENERY` models
  that are direct children of Workspace (Don Glaseon's sleeping copy, set up again each time the server puts it back),
  and waits for a streamed model's bones for as long as the model exists (it gave up after 10 s before, which a player
  walking in from the spawn could exceed). A clip module not yet replicated is no longer cached as missing.
- [x] A3-5 `WildboundCandyTortidragonAnim` and `WildboundCandyDonGlaseonAnim` keep only their effects (the candy volley,
  the licorice ribbon); they no longer load tracks, and PF5's chest sway is gone (the sleeping copy plays the whole
  `Idle_Breath` clip now). One writer per rig.
- [x] A3-6 The resting Tortidragon copy (A1, `WildboundBeastsLocal`, `BeastPhase = "Calm"`) plays `Idle` through the same
  path; Don Glaseon has no resting copy besides the sleeping one.
- [x] A3-7 Walked Play check (below). Commits 9b1bd95 (specs), f958585 (implementation).

## Decisions taken for the user (A3)

1. Least duplication: the services copy the existing ServerStorage modules to ReplicatedStorage at run time and the
   client converts them with `Kit.fromLegacy`, instead of regenerating them in the critter data format or keeping a
   second copy. The clip data stays in `tools/WildboundCandy*Clips.luau` and its suites and the publisher are unchanged.
2. The shared `WildboundCandyCritterAnim` plays both (through `Spec`), rather than a sibling client: the published-id
   rule, the cross-fade, the camera distance cut and the error retry come for free.
3. The two old clients stopped playing published tracks: `WildboundCandyCritterAnim` already plays a `Clip_<name>` id on
   the Animator, and two players on the same Animator would double the tracks once the owner publishes.
4. The sleeping copy plays `Idle_Breath` (the clip set has no sleep clip); PF5's chest sway was replaced, not kept as a
   fallback, so only one script writes its bones.
5. Don Glaseon's `Stagger` (a bat bouncing off him) now plays `HitReact_ImmuneBat` (it was the idle loop).
6. `WildboundCandyClipKit_Test` CK9 now expects 8 spec entries (deliberate); `WildboundBossRobustness_Test` PF5 now checks
   that the Don Glaseon client no longer writes bones and keeps the ribbon.

## Evidence (A3)

Studio: place 122652861404212, instance db843df0-7649-423f-adb7-739088c9746a. Before any write, all nine touched
scripts matched the repo HEAD b8c4289 (CRLF -> LF, trailing newlines stripped, bytes + Adler-32): ClipKit 6552
527639b6, CritterAnimSpec 4267 397e608e, CritterAnim 10399 186291d9, TortidragonService 1629 73453c80,
DonGlaseonService 4072 759e8fac, TortidragonAnim 5124 1207a30b, DonGlaseonAnim 6830 4817c91f, ClipKit_Test 14896
bdcf218d, BossRobustness_Test 8474 373bd3eb. Writes by `multi_edit` exact replacements; the Don Glaseon client's tail
(setup plus the old breathing code) by an anchored find-and-replace of `Source` in `execute_luau`; the new suite created
with `multi_edit`. Read back after each batch.

Final fingerprints (Studio == repo):

| Script | Bytes | Adler-32 |
|---|---|---|
| WildboundCandyClipKit | 7414 | f79f5d08 |
| WildboundCandyCritterAnimSpec | 5615 | 3e531e3d |
| WildboundCandyCritterAnim | 11135 | c82f950d |
| WildboundCandyTortidragonService | 2038 | 6a44cd41 |
| WildboundCandyDonGlaseonService | 4518 | 79492cf8 |
| WildboundCandyTortidragonAnim | 4120 | 421c5c32 |
| WildboundCandyDonGlaseonAnim | 3978 | c04e2295 |
| WildboundCandyLiveClips_Test (new) | 9395 | 1a61ce67 |
| WildboundCandyClipKit_Test | 15055 | 431f58ce |
| WildboundBossRobustness_Test | 8364 | 9cc1af48 |

Runs: the engine of `tools/studio-fresh-runner.luau` (loader, clones, lock; shorter report, no leak scan) in a temporary
ServerStorage StringValue `WildboundA3RunnerEngine` (destroyed at the end), only these SPECS, `WildboundFreshRunnerLock`
respected (nil before and after).

| Run | What | Result |
|---|---|---|
| ed2d4265 | RED: CandyLiveClips, CandyClipKit, BossRobustness, CandyClipPublish | 26 passed, 8 failed (6 new cases, CK9 count, PF5/A3) |
| a022975e | GREEN, the same four suites (plus `loadstring` compiles of the five edited scripts) | 34 passed, 0 failed |
| 0ee38e6a | Neighbours: BeastCandyCritter, CandyDuquesa, CandyTrapCake, CandyTortidragonClips, CandyDonGlaseonClips | 61 passed, 2 failed: the known "every clip is published" reds of the two clip suites (handoff section E) |

`tools/studio-fresh-runner.luau` has the new SPECS entry; `tools/test_studio_fresh_runner.py` was not run (no Python on
this machine).

### Walked Play

Lock `WildboundPlayLock = "A3-liveclips"` (both locks nil before); Play stopped and the lock cleared after. The character
walked with `character_navigation` only: spawn (298, -3) -> (440, -40) -> (500, -120) -> Tortidragon's post (508, -134)
-> (520, -30) -> into Don Glaseon's territory (565, -5) -> out to (470, -5). A read-only client sampler logged every 0.5 s
the position and, for each Tortidragon / Don Glaseon model, its phase, `WildboundCritterClip`, how many bones had a
non-identity Transform and how many changed since the previous sample.

- Tortidragon's resting copy, from 225 studs away on the road: `Calm`, clip `Idle`, 9-13 of 24 bones posed and changing
  every sample.
- The live view replaced it at 32 studs (no pop: same spot), `Idle` animating; at 16 studs `Notice` -> `Alert`, then
  `Telegraph` -> `Attack_Telegraph` (17 bones changing), `Release` -> `Attack_Release` (18), `Recover` ->
  `Attack_Recover`, `Chase` -> `Run_Quadruped` (16 bones), and again in cycles. The candy volley folder
  (`AbanicoDeConfites`, 3 parts) appeared on a Release. Walking off: `Disengage` -> `Walk_Quadruped` (moving), then the
  resting copy back on the post, `Idle` animating.
- Don Glaseon: his bed was empty at first (`Candy_bossDisguised = true`, DG7). Entering the territory: `Suspicious` ->
  `Notice`, `Roar` -> `Roar_Visual` (17 of 29 bones), `Attack` -> `Attack_Release_Licorice` (19), `Recover`,
  `Chase` -> `Chase_Run` (16), `Telegraph` -> `Attack_Telegraph_Licorice`, `LoseTarget` -> `LoseTarget`, `Return` ->
  `Patrol_Walk`.
- After he went home the sleeping copy came back on BossHome: `Dormant` -> `Idle_Breath`, 5-10 bones changing every
  sample, seen from 50 to 107 studs; `Spine_Upper` rotated 0 -> 0.038 rad and rose up to 0.13 studs over one 3.6 s cycle.
- Console: no error or warning from these scripts (only the known TexturePack, asset, EditableImage and DataStore noise).

What was not checked: the licorice ribbon and the candy arcs on screen. In this Studio session `RunService.RenderStepped`
does not fire (0 per second against 60 Heartbeats, the viewport is not rendering while the window is in the
background); both effects run on RenderStepped (unchanged code), so the ribbon's links stayed invisible here. The bone
animator runs on Heartbeat, which is why it could be checked. Also not checked: a published `Clip_<name>` id taking over
(covered by the spec and the unchanged rule in the shared client), two players, a phone.

## A3 review fix: bones read again after a stream-out

Defect: `WildboundCandyCritterAnim` read a model's bones once. With streaming on (Opportunistic stream-out, radius
1024), a model's parts can stream out and back in while the Model stays; the state kept the old, detached Bone
instances and the model froze (Don Glaseon's sleeping copy, a resting critter).

- [x] A3R-1 `WildboundCandyClipKit.readBones` (moved from the client unchanged) and `Kit.bonesStale(model, list)`: true
  when the list is empty or its first or last bone is no longer a descendant of the model (a part streams with all its
  bones, so two checks per model per frame are enough).
- [x] A3R-2 `WildboundCandyCritterAnim`: each step, when `state.stale` or `Kit.bonesStale(model, state.bones)`, it reads
  the bones again (and their rest); while the parts are away (`readBones` nil) it skips the step and keeps the state.
  A `DescendantAdded` hook on the model sets `state.stale = true` when a Bone arrives later (the count changed); it is
  disconnected on drop.
- [x] A3R-3 Specs A3R-1..3 in `WildboundCandyClipKit_Test` (a probe rig whose root part is removed, then replaced by a
  copy with new bones; a destroyed bone; the client wiring). Commits bef15e2 (specs), ee47522 (fix).

Fingerprints: before writing, Studio == repo HEAD 6a70bd1 for CritterAnim 11135 c82f950d, ClipKit 7414 f79f5d08,
ClipKit_Test 15055 431f58ce. Writes by `multi_edit` exact replacements, read back. Final (Studio == repo): CritterAnim
11191 8969b920, ClipKit 8974 8ffd6742, ClipKit_Test 19251 4162aaf9.

Runs (engine of `tools/studio-fresh-runner.luau` in a temporary ServerStorage StringValue `WildboundA3RRunnerSource`
with only the two SPECS, destroyed after; `WildboundFreshRunnerLock` nil before and after):

| Run | What | Result |
|---|---|---|
| f7c4086d | RED: CandyClipKit, CandyLiveClips | 19 passed, 3 failed (the three new cases) |
| a47d5ace | GREEN, the same two suites | 22 passed, 0 failed (ClipKit 15, LiveClips 7) |

Walked Play (lock `WildboundPlayLock = "a3-review-bones"`, both locks nil before, cleared after; `character_navigation`
only): spawn (298, -3) -> the breathing trap cake (526, -24), which sprang and pushed the character away -> (560, -3), where
Don Glaseon woke and attacked -> (530, 30). Client samples (bones whose Transform changed in 0.6-0.8 s):

- Resting copies in `WildboundBeastsLocal`: Mochimiau 10/13, Canelin 10/15, Flanin 11/12, Mielita 15/16 (`Fly`),
  GatoRepartidor 11/19, Tortidragon 13/24 changing.
- Stream-out stand-in on the client copy only: Mochimiau's root part removed for 0.5 s, then replaced by a copy (new
  Bone instances): 10 of 13 bones changing again, clip `Trot`.
- Don Glaseon's sleeping copy, back on BossHome (578, -3) after he went home: `Idle_Breath`, 11 of 29 bones changing;
  the same root-part swap on the client's copy: new bones, 11 changing again.
- Console: no warning from `WildboundCandyCritterAnim` (only the known TexturePack, asset, EditableImage and DataStore
  noise).

Not checked: a real stream-out by distance (the map does not reach the 1024-stud radius from the walked points); the
part swap above is the stand-in.
