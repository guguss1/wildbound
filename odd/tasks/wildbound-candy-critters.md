# Wildbound: the Caramelo candy critters

## Objective

Five new Caramelo creatures live in the candy biome with a behaviour, like Gomibu, Flanfuria and Tortidragon: Mochimiau (5 studs), Canelin (5.5), Flanin (8), Mielita (4.5, flies) and Gato Repartidor (3.5, biped). Duquesa Burbuja (18 studs) stays seated scenery on the Gran Torta top, with no brain, for now.

## Scope

- In: one shared data-driven brain, the config entries, the posts and the summon rule, the beast server registration, the model service that parks the real rigs for the beast client, the suites, a solo Play check.
- Out (other owners): the client-side live animation (`WildboundCandyClipKit`, `WildboundCandyCritterClips*`, `WildboundCandyCritterAnim`), the beast client (tell colours), `WildboundText` lines, Don Glaseon.

## Behaviour

### Checklist

- [x] **CC1** Config: five `Config.BEASTS` entries with the Gomibu field set (Guardian, damage 0, keepsEgg, chance 0, never rolled, hitHeight 8, disengage 0.9) and their tuning plus an `Attack` table; the names join `WAVE2` and `SUMMONED`, not `ORDER` (still 9) or `PLAYABLE`. Evidence: `WildboundBeastCandyCritter_Test` CC1; `WildboundBeastDirector_Test` 48/0.
- [x] **CC2** Brain `ServerScriptService.WildboundBeastCandyCritter` (`src/wildbound/WildboundBeastCandyCritter.luau`): one `{init, step}` for the five names, built on `WildboundBeastAttack` the way Gomibu's is. Phases: Spawn, Patrol (wander within `PatrolRadiusStuds`, calm), Notice, Chase (leash), Telegraph, Release, Recover; GiveUp (the target past `AbandonStuds`, or the creature held at its leash with the target out of attack range for `GiveUpSeconds`) ends the encounter like Gomibu (Disengage "GiveUp" for `GiveUpSeconds`, then End); Escape, death and the safe zone end it too. Evidence: CC2 cases (review fix R2/R3 below).
- [x] **CC3** Attacks from `tuning.Attack.kind`, each with a tell of at least `Config.MIN_TELL` before the strike and a lock at least `MIN_TELL` before the strike, damage 0, a slow on every hit and a push where the sheet asks for one, `CooldownSeconds` counted from the strike. Evidence: CC3 cases.
- [x] **CC4** Posts (`WildboundPraderaSites`): five fixed posts beside free nests, and the hard-coded Gomibu/Flanfuria/Tortidragon wake check replaced by `name ~= "DonGlaseon" and Sites.FIXED[key]`. Evidence: `WildboundCandyBeastSites_Test` CC4 (11/0).
- [x] **CC5** Registration and models: five KIDS rows in `WildboundBeasts.server` (module `WildboundBeastCandyCritter`), and `ServerScriptService.WildboundCandyCritterService` parks each rig in `ReplicatedStorage.WildboundBeasts.Models.<Name>`. Evidence: CC5 wiring case; Play (below).
- [x] **CC6** Solo Play: each creature summoned at its post, Notice, Chase, a telegraphed attack, the slow and push observed, no script error. Evidence below.
- [ ] **CC7** Tell colours for the five in `WildboundBeasts.client` `TELL_COLOR` (today they fall back to RED, the colour the kids and candy rule avoids). Not done: the beast client was out of this task's scope.
- [ ] **CC8** `WildboundText.BEAST` lines for the five (optional; the client returns quietly without them).

### The five creatures (first proposal, tune in play)

| Creature | Post (world x, z) | Attack | Tell / lock / travel (s) | Shape | Outcome | Cooldown | Sight / leash / abandon | Patrol / chase |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mochimiau | `candyNestR2` (539, 43) | leap, "Rodada cremosa" | 0.8 / 0.45 / 0.45 | circle r 4 on the target | push 5 studs over 0.3 s, slow x0.75 for 2.5 s | 6 | 14 / 14 / 22 | 6 / 11 |
| Canelin | `candyNestR3` (664, -101) | dash | 0.9 / 0.5 / 0.6 | lane 14 x 5 forward from itself (shortened to stay in its leash) | slow x0.8 for 2 s | 6 | 14 / 16 / 24 | 7 / 12 |
| Flanin | `candyNestR4` (664, 71) | burst, "Onda cremosa" | 1.0 / at once / 0.25 | circle r 10 on itself | slow x0.7 for 3 s, no push | 7 | 14 / 12 / 20 | 5 / 9 |
| Mielita | `candyNestC4` (542, 139) | lob, pollen cloud | 0.9 / 0.5 / 0.6 | circle r 6 on the target | slow x0.75 for 3 s | 9 | 16 / 14 / 24 | 8 / 13 |
| Gato Repartidor | `candyNestC2` (466, 34) | lob, fries | 0.9 / 0.5 / 0.6 | circle r 4 on the target | push 2 studs over 0.25 s, slow x0.9 for 1.5 s | 8 | 8 / 8 / 14 | 5 / 9 |

Wake radius: 30 (Mielita 32, Gato 24). Escape: 50 studs from home for 2 s. GiveUp lasts 2 s.

### Decisions taken for the user

1. **One brain, four kinds.** The brief's kinds were followed (Mochimiau leap, Canelin dash, Flanin burst, Mielita and Gato lob), not the earlier survey's table (which had Canelin burst, Flanin leap, Mielita dash).
2. **Phase names.** Idle phases are `Spawn` and `Patrol`, both in `WildboundPortal.CALM_PHASES`, so an idle critter never blocks the return portal. The attack is `Telegraph` then `Release` (the hop, roll, wave or throw; the strike is its end) then `Recover`. Giving up is `Disengage` (reason "GiveUp", calm) for 2 s, then the encounter ends. The brain no longer emits `GiveUp` or `Return` phases (review fix R2). The animation agent can map these names.
3. **Give up ends the encounter (review fix R2, replaces the first decision).** First version: a critter walked home and patrolled inside the same encounter, so it held one of the player's `MAX_ACTIVE = 2` beast slots while the player stayed within 50 studs of its post. Mochimiau's circle overlaps Don Glaseon's territory, so that slot could make the boss summon return "MaxActive". Now GiveUp ends the encounter like Gomibu's; the next summon (species `cooldown` 10 s, the player inside `WakeRadiusStuds`) starts again at home in Patrol. The creature disappears during that gap, as Gomibu does. A critter held at its leash with the target out of attack range for `GiveUpSeconds` also gives up (review fix R3: before, it could stay in Chase for ever with the target between leash + range and leash + abandon from home).
4. **Cooldown counted from the strike** (the recovery included), so "cooldown 6 s" means no new tell until 6 s after the last strike.
5. **Fair lock.** Every shape locks at least `MIN_TELL` (0.8 s) before its strike, not only the tell start.
6. **Mielita's hover is server height.** The brain keeps `e.pos.y` at the ground plus `HoverStuds` 2.5 (the client skips its bob for rigged models). Its attack shapes stay on the ground. No change to `WildboundBeasts.server` was needed.
7. **Posts.** All five posts are 13 to 15 studs from a free nest on the side away from the routes, at least 62 + leash studs from the boss territory centre, at least perception + 7 studs off every route centreline, and apart from every guardian and critter post by at least the sum of their leashes. Mielita sits by nest C4, near La Abeja's hive (honey theme, 44 studs from the hive). Gato Repartidor, the friendly one, sits by nest C2 near the entrance.
8. **Slows stay inside the server's caps (review fix R1).** The brief asked 3.5 s (Flanin) and 4 s (Mielita), but `applySlow` and `WildboundBeastChase.EFFECTS.slowMaxSeconds` cap every slow at 3 s, so both are now 3 s in the config and CC1 asserts `SlowSeconds <= slowMaxSeconds` and `SlowMultiplier >= slowMinMultiplier` for all five. The multipliers are unchanged.
9. **Models.** The service prepares each import live at server start (no new prefab in `ServerStorage.WildboundAssets`): clone, PackageLinks removed, PrimaryPart = RootPart, pivot at the bottom of the bounding box under the root, facing the RootPart's -Z (the import's RootPart already looks the creature's way: the eyes are at local -Z), root anchored, all parts out of collisions and queries, an AnimationController with an Animator. The clip ids table is empty, behind the guarded `Clip_` pattern.
10. **Preview copies.** The five roaming copies in `Workspace.WildboundNewCandyPreview` were removed (one ChangeHistory recording, so Ctrl+Z restores them; the imports in `ServerStorage.WildboundNewCandyImports` are untouched). The seated Duquesa stays.
11. **Mochimiau's post moved (review fix R4).** The first post (546, 37) kept 62 + leash from the boss territory centre, but a leap circle at the end of the leash plus its 5-stud push could carry the player inside the 62-stud territory (seen in Play: Don Glaseon chased briefly). `candyNestR2` is now (539, 43): 86.3 studs from the territory centre (rule 62 + leash 14 + circle 4 + push 5 = 85), 13.0 studs from its nest, 22.9 off the routes, on the floor. CC4 now asserts territory + leash + (RadiusStuds or WidthStuds) + PushStuds for all five posts.

### Evidence

- Code commit: `054a4dd` (brain, service, config, posts, KIDS rows, suites, manifest rows and runner SPECS).
- Fingerprints before editing (CRLF to LF, trailing newlines stripped; length and Adler-32): Studio equalled repo HEAD for `WildboundBeastConfig` 31770/1690292384, `WildboundBeasts` 49279/3008816592, `WildboundPraderaSites` 6227/340531337, `WildboundCandyBeastSites_Test` 11645/512545621.
- After writing, Studio equalled the working copy: `WildboundBeastConfig` 36953/336411130, `WildboundPraderaSites` 7063/1864312943, `WildboundBeasts` 49644/1796104371, `WildboundBeastCandyCritter` 11480/2691792342, `WildboundCandyCritterService` 4283/2232064623, `WildboundBeastCandyCritter_Test` 17349/2171883060, `WildboundCandyBeastSites_Test` 14957/3023433313.
- RED with the fresh loader (the runner engine in a temporary ServerStorage StringValue with only the needed SPECS, destroyed afterwards): run c443ef2b `WildboundBeastCandyCritter_Test` ERROR module not found; run 3173acf3 `WildboundCandyBeastSites_Test` 10/1 (CC4: "Mochimiau has no fixed post"); run 5f206ba4 the CC5 case ERROR script not found `WildboundCandyCritterService`.
- GREEN: run 011a9670, 10 suites, 203 passed, 0 failed (`WildboundBeastCandyCritter_Test` 13/0, Abeja 10/0, Director 48/0, DonGlaseon 18/0, Encounters 24/0, Flanfuria 10/0, Gomibu 9/0, Nube 11/0, Tortidragon 9/0, Wiring 51/0); run 38fa8a09 `WildboundCandyBeastSites_Test` 11/0 and `WildboundCandyNests_Test` 12/0.
- Two test fixes during GREEN (test design, not behaviour): the tell case now reads the phases of the whole run (Mochimiau's Release fell before the second window), and the give-up case puts the target past the abandon distance from the end of the leash; the lane's floor is `oy`.
- Solo Play (lock `WildboundPlayLock = "critter-brain"`, cleared after). The models appeared in `ReplicatedStorage.WildboundBeasts.Models` with the pivot at (0, 0, 0) facing -Z, bottom at y 0, no PackageLink. The player was teleported on the server beside each post; the client clone in `workspace.WildboundBeastsLocal` showed (seconds from the teleport, client `BeastPhase`):
  - Gato Repartidor: Telegraph, Release 0.9 s later, Recover 0.6 s later; WalkSpeed 16 to 14.4 for 1.5 s; next Telegraph 8 s after the strike.
  - Mochimiau: Spawn, Notice, Chase 0.6 s later, Telegraph, Release, Recover with the body moved onto the circle (546 to 551.6); WalkSpeed 12 for 2.5 s and the player pushed about 5 studs; next Telegraph 6 s after the strike.
  - Canelin: Notice, Chase, Telegraph, Release, Recover with the body rolled 12 studs along the lane; WalkSpeed 12.8 for 2 s; next Telegraph 6 s after.
  - Flanin: Notice, Chase 0.8 s later, Telegraph, Release, Recover; WalkSpeed 11.2 for about 3 s (the server clamp); next Telegraph 7 s after.
  - Mielita: Notice, Chase, Telegraph, Release, Recover at y 3.0 (ground 0.5 + 2.5 hover); its first hit landed while Flanin's slow was still on (WalkSpeed stayed 11.2, slows do not stack); the second gave WalkSpeed 12; next Telegraph 9 s after.
  - Each one went GiveUp then Disengage when the player was teleported away. No script error in the output (only the known TexturePack, DataStore and EditableImage notices).
- Seen in Play, not a bug in this task: Mochimiau's push sent the player east from its post toward the boss plaza, and Don Glaseon started a chase (then LoseTarget, Return). The post keeps 62 + leash from the territory centre, but a push plus the leash end brings the player close to the territory edge. (Fixed by R4: the post moved.)

### Review fixes (2026-11-16)

An independent review of `054a4dd` found three defects and one note; all four are fixed in the repo and in Studio.

- **R1** Flanin and Mielita asked for slows longer than the server's 3 s cap: both are 3 s; CC1 pins the caps from `WildboundBeastChase.EFFECTS` (the suite now takes `WildboundBeastChase` as a sixth argument; runner SPECS updated).
- **R2** Giving up walked home inside the encounter and kept a `MAX_ACTIVE` slot (it could block Don Glaseon and guardian alarms): GiveUp now ends the encounter (Disengage "GiveUp", then End). The `GiveUp` and `Return` phases are gone from the brain.
- **R3** Held at its leash with the target out of attack range, a critter stayed in Chase for ever: after `GiveUpSeconds` of that it gives up (new CC2 case, target at leash + range + 2).
- **R4** Mochimiau's leap plus push could carry the player onto the boss ground: `candyNestR2` moved from (546, 37) to (539, 43); CC4 asserts territory + leash + shape + push for every post.
- Not changed: the tell colour (beast client, out of scope, CC7) and the client animator's phase map (another agent's file; it lists `Disengage` as calm, and `GiveUp`/`Return` simply never arrive now).
- Fingerprints before writing (CRLF to LF, trailing newlines stripped; length and Adler-32 hex): Studio equalled repo HEAD for `WildboundBeastCandyCritter` 11480/a0717dd6, `WildboundBeastCandyCritter_Test` 17349/81744e34, `WildboundPraderaSites` 7063/6f1f286f, `WildboundCandyBeastSites_Test` 14957/b435ee61. `WildboundBeastConfig` in Studio was 38171/e42ece06 (HEAD 36953/140d39fa plus another agent's uncommitted Viper tuning, equal to the working tree at that moment); only my two exact replacements were applied on top.
- After writing, Studio equalled the repo: `WildboundBeastCandyCritter` 11791/0bddea31, `WildboundBeastCandyCritter_Test` 19748/a7465576, `WildboundPraderaSites` 7271/80f36f2f, `WildboundCandyBeastSites_Test` 15385/166e739c, `WildboundBeastConfig` 38289/a873f4e0 (Studio; the commit holds HEAD plus only the two slow lines).
- RED with the fresh loader (runner engine in a temporary `ServerStorage.CritterBrainRunner_TEMP` StringValue with only the beast SPECS, destroyed afterwards): run c5436082 `WildboundBeastCandyCritter_Test` 10/4 (Flanin slow past the cap; slow time 3.5; Mochimiau phases "GiveUp,Return,Patrol" with no Disengage; Mochimiau never gave up at its leash); run 8abec81c `WildboundCandyBeastSites_Test` 10/1 (Mochimiau: its attack and push reach the boss ground).
- GREEN: run dfe297cf `WildboundBeastCandyCritter_Test` 14/0; run d187a4bc `WildboundCandyBeastSites_Test` 11/0; run d55a3c42, 11 suites, 224 passed, 1 failed: Abeja 10/0, CandyCritter 14/0, Director 48/0, DonGlaseon 20/0, Flanfuria 10/0, Gomibu 9/0, Nube 11/0, Tortidragon 9/0, Wiring 52/0, CandyNests 12/0; the one failure is `WildboundBeastEncounters_Test` "BR2 Pouncer ... one ball per landing" (another agent's in-progress beast revision, untouched by this fix).
- Solo Play (lock `WildboundPlayLock = "critter-brain"`, cleared after; no script error in the output): Mochimiau at the new post went Patrol, Notice, Telegraph, Release, Recover, Chase; its push carried the player from (547, 43) to (552.5, 43), 75 studs from the territory centre (outside 62); WalkSpeed 12 for about 2.5 s. With the player teleported 33 studs away it went straight to Disengage and the clone was removed 2 s later (R2). Re-summoned in Patrol 10 s later; with the player stepped from (528, 43) to (514, 43) it chased to the leash end (525, 43), held there, and went to Disengage 2.3 s after entering Chase, then ended (R3).

### Not checked

- The tells' colour and look on the client (they fall back to RED: `TELL_COLOR` has no entry for the five; CC7).
- The live animation of the five (another agent's client animator was not in Studio during this Play, so the rigs moved unanimated).
- After the review fixes: Don Glaseon waking while a critter encounter is live next to its territory (the slot fix is pinned by suites, not tried in Play); Flanin's and Mielita's 3 s slows were not re-timed in Play.
- Two players, a phone, the egg kept on a hit while carrying, the strike stagger between two critters on one player, the portal calm check next to an idle critter.
- `python -m unittest` for `tools/test_deploy_manifest.py` and `tools/test_studio_fresh_runner.py` (no system Python on this machine); the new manifest rows and the runner SPECS entry were written to their rules by hand.
- The place was not saved: the new Studio scripts, the edited shared scripts and the removed preview copies live in the open session until the owner saves.

### Next step

Tell colours (CC7) and the text lines (CC8) in the beast client and `WildboundText`; then a tuning pass in Play with the live animation.

### Live animation (separate record)

The live animation of the five critters and Duquesa is recorded in `odd/tasks/wildbound-candy-critters-anim.md` (scripts `WildboundCandyCritterAnim`, `WildboundCandyCritterAnimSpec`, `WildboundCandyClipKit`, the six `WildboundCandyCritterClips<Name>` data modules). Since the review fixes it also plays a published `Clip_<clip>` id on the clone's Animator, so the ids for the five go into `CLIPS[<name>].IDS` in `WildboundCandyCritterService` (this session's file; the animation session did not edit it). Duquesa has no id path.