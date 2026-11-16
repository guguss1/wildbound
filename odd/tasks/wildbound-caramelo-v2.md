# Caramelo v2: Don Glaseón mechanics, the cake tower and the economy (decisions 2026-11-15)

## Status

It records the user's decisions of 2026-11-15, made while the balance pass (`odd/tasks/wildbound-balance-pass.md`) was running. Implemented one task at a time; the checklist says which are done, and the evidence is at the end.

## User decisions (2026-11-15)

### Don Glaseón

- **Lash (DG1):**
  - The tell drops from 1.1 s to about 0.8 s, the fair-strike floor.
  - He throws a combo of three lashes: left lane, right lane, then centre.
  - Each lash has its own drawn lane.
  - The lash stays the only attack that can make the carrier drop the egg.
- **Approved mechanics:**
  - **DG2 Boca aspiradora (vacuum mouth):** he opens his mouth, and for about 2 s every player in a cone in front of him is pulled toward him. The player must run against the pull or break line of sight behind cover. A wind or candy-crumb VFX shows the pull. Server side, it is a velocity the client can fight.
  - **DG3 Muro de chocolate (chocolate wall):** he raises chocolate walls that cut the escape path for a few seconds.
    - The walls are telegraphed by a crack line on the floor, at least 0.8 s ahead.
    - They are placed across the target's predicted route.
    - They never seal a player completely: there is always an exit.
  - **DG4 Glaseado resbaloso (slippery glaze):** a puddle where the player skates.
    - It does not slow the player; they lose grip when turning.
    - Fun first: the faster you enter, the more you slide.
    - Above a speed threshold (sprint, or a trained walk), a sharp turn on the glaze makes you slip and fall as a short ragdoll (reuse the teammate's ragdoll path).
    - Going fast is therefore a risk on glaze. Keep the fall short (about 1 s) and readable.
  - **DG5 Rabia creciente (rising anger):** the fight's tempo rises. The user asked whether it should rise with time or with dodges.
    - Decision (taken for the user): both, for the current target.
    - Anger rises over time while that player carries an egg inside his territory, and each perfect dodge adds a chunk.
    - When the meter fills he turns red for 10 s: faster casts, shorter cooldowns.
    - The meter resets when the target leaves the territory or drops the egg.
    - The meter is visible: his colour shifts toward red.
  - **DG6 Rugido de guardianes (guardians' roar):** he roars and SUMMONS NEW Gomibú, Flanfuria and Tortidragón around the thief. These are fresh encounters, not the ones already present.
    - It happens at most once per chase, and only on a player carrying a rare egg or better.
    - The summoned beasts give up after their leash or chase time.
    - This is maximum tension for the best egg.
- **DG7 Torta trampa (trap cake):** the user likes the paranoia but asked why a player would ever walk near the cakes. The design that answers this:
  - The decoy cakes are placed ON the routes a thief must use: the tower stair entrance, the paths between the nests and the Gran Torta, and next to a rare nest.
  - Every decoy cake also holds a small reward the player can take: a slice that gives a few Esencia, or a short speed buff.
  - One of the three is Don Glaseón in disguise. He springs out when a player comes close, does a short grab or lash, and then the decoys pop.
  - The player has to read the tell: the real cake breathes slightly, and a crumb falls from it now and then.
  - He uses it only while Dormant or Patrol, never during a chase.
- **Later, not now:** Cama elástica de bizcochuelo (sponge-cake trampoline; option 10).
- **Not now:** the v2 model and head redesign in Blender. Postponed by the user.

### The Gran Torta tower

- **CT1 Spiral staircase:** add a spiral staircase around the Gran Torta so players can climb the tiers. Build it with the Candy builder, never by hand.
- **CT2 Rotating tiers:** each tier rotates, alternating direction from one tier to the next (counter-rotating), so the cake feels alive.
  - Players standing on a tier must ride with it: use moving platforms with proper friction/velocity, or the character carry pattern.
  - Keep the rotation slow, so it is readable and does not cause motion sickness.
- **CT3 Best egg at the top:** the top of the cake holds the best egg of the biome, the top Legendaria or a unique "Huevo de la Gran Torta". It refills on the 300 s wave like the other nests.
- **CT4 A guardian at the top:** proposal, taken for the user and still open to change.
  - **Frutillón:** the giant strawberry on top of the cake wakes when a player reaches the top. It rolls around the top tier, trying to bump players off the edge.
    - It telegraphs each roll with a squash and a line on the floor.
    - On the stair it throws strawberry seeds that bounce down.
    - It never damages; it only knocks players back and off the tier.
  - Don Glaseón can climb, or roar from the base, while someone carries the top egg.

### Economy (proposed; answer pending from the user)

- **Steal hold by rarity:** Común 0.5 s, Rara 0.9 s, Épica 1.3 s + Arrullo, Legendaria 1.8 s + Arrullo. This answers the 0.8/0.5 schema/live split, DT1.
- **Creature value: options A-G from the conversation:**
  - **A:** passive income per rarity in the farm, shown above each creature and on selection.
  - **B:** a chest that fills, capped at 30 min.
  - **C:** mutations at hatch: Dorada x2, Arcoíris x5.
  - **D:** feeding to level up.
  - **E:** extra farm slots. The balance pass covers this.
  - **F:** the best eggs where it is most dangerous.
  - **G:** stealing from other bases, later.
  - Recommended: A + B + C + D now, G later.
  - Note: A conflicts with the anti-AFK rule `antiAfk.timeBasedGrants = 0`. The capped chest (B) makes it acceptable. Re-run the economy simulator after.

### Icons

- The user wants me to always handle icons.
- Plan: try the `rbxthumb://type=Asset&id=<id>&w=150&h=150` form for `Tool.TextureId`. PF7 found it loads where the plain user-owned asset id does not.
- If that fails, report it. Uploading to the group needs group rights that the assistant token lacks.

## Checklist

- [x] DG1 Lash combo, faster. Done 2026-11-16 (evidence below).
- [x] DG2 Vacuum mouth. Done 2026-11-16 (evidence below).
- [x] DG3 Chocolate wall. Done 2026-11-16 (evidence below).
- [x] DG4 Slippery glaze with a slip-and-fall ragdoll. Done 2026-11-16 (evidence below).
- [x] DG5 Rising anger (time + dodges). Done 2026-11-16 (evidence below; the full rage was seen in suites, not in Play).
- [ ] DG6 Roar summons new guardians
- [x] DG7 Trap cake with lures on the routes. Done 2026-11-16 (evidence below; the bite path through a real prompt hold is noted there).
- [x] CF Faster casts for Gomibú, Flanfuria and Tortidragón:
  - tells down to the 0.8 s floor, shorter recovery;
  - cooldowns about 3.5 / 5 / 4.5 s.
  - Done 2026-11-16 (Studio suites and solo Play in the evidence below).
- [x] CT1 Spiral staircase on the Gran Torta. Done 2026-11-16 (evidence below).
- [x] CT2 Counter-rotating tiers. Done 2026-11-16 (evidence below).
- [x] CT3 Best egg at the top. Done 2026-11-16 (evidence below).
- [x] CT4 Frutillón, the top guardian. Done 2026-11-16 (evidence below).
- [x] IC Icons through rbxthumb. Done 2026-11-16 (the thumbnail form loads; evidence below).
- [x] EC Steal hold by rarity: Común 0.5 s, Rara 0.9 s, Épica 1.3 s, Legendaria 1.8 s. Done 2026-11-15 (evidence below).
- [ ] Economy options A-G, once the user picks them (not started on purpose).
- [x] AR Remove the Arrullo minigame. It returns later, improved (user, 2026-11-15).
  - Épica (and Legendaria) eggs use a plain longer hold instead (1.3 s / 1.8 s per the EC scale).
  - Disable the minigame path and keep its module for later; do not delete it.
  - Re-pin the suites that expect it.
  - Done 2026-11-15 (Studio suites and solo Play in the evidence below).

## Decisions taken for the user

| ID | Decision | Why |
| --- | --- | --- |
| AR-D1 | The switch is one flag, `WildboundArrulloService.ENABLED = false`, checked first in `Service.qualifies`. `WildboundServer` is not edited: its Arrullo branch stays in place and is simply never taken (`entry.arrullo` is false for every egg). | The server is at the 200-local limit and shared with the teammate; one flag brings the minigame back. |
| AR-D2 | Until EC, a rare egg's hold is the existing `RARE_HOLD` (module 0.75 s; the place's tuning folder applies 1 s). | AR only removes the minigame; EC sets the per-rarity scale. |
| AR-D3 | The Arrullo tuning rows, `Text.ARRULLO`, the client and the remote stay. The client panel never opens because the server never starts a session. | "Keep its module for later." |
| EC-D1 | Four keys, one per rarity: `STEAL_HOLD` (Común, and any unknown tier), `RARA_HOLD`, `EPICA_HOLD`, `LEGENDARIA_HOLD`. `RARE_HOLD` is removed from the module and the tuning schema. The biome event's egg holds like a Legendaria (1.8 s) whatever its tier. | The old Épica/Legendaria pair no longer fits four values; the event egg is the Legendaria one (RW5). |
| EC-D2 | Tuning keeps the order Común ≤ Rara ≤ Épica ≤ Legendaria and caps the three rare holds at `RARE_HOLD_MAX = 2.5` s (Común stays 0.35-1 s). The four schema rows take the module defaults and the same ranges. | A tuned value can never make a better egg quicker, and every hold stays under the server's 3 s `HOLD_GRACE`. |
| EC-D3 | DT1 is settled for the steal holds only. The same case still fails on three older drifts it was hiding: `Eggs.PICKUP_DELAY` and `Eggs.PICKUP_HOLD` (schema 0.4, module 0.25) and `Incubator.HATCH_SECONDS` (schema 5, module 15). Live play uses the schema numbers (the place has no saved `Eggs` or `Incubator` tuning folder). Not changed: either side changes what players feel, so it waits for the user. | Out of EC's scope and a gameplay call. |
| EC-D4 | The glove "Robo rápido" still shortens every hold down to the 0.35 s floor, rare eggs included. | Unchanged rule; the user asked only for the base scale. |
| EC-D5 | `tools/wildbound_economy_sim_v2.py` was not edited: it still reads `RARE_HOLD` (gone) and models the Arrullo for Épica and Legendaria. Fix both with the BP4 rerun on a machine with Python. | No Python here; the simulator is not live code. |
| CF-D1 | New timings. Gomibú: tell 0.9 -> 0.8, lock 0.55 -> 0.45, recover 0.7 -> 0.5, cooldown 5.5 -> 3.5. Flanfuria: tell 1.0 -> 0.8, recover 0.85 -> 0.6, cooldown 8 -> 5. Tortidragón: aim 1.0 -> 0.8, lock 0.6 -> 0.45, recover 0.85 -> 0.6, cooldown 7 -> 4.5. The jump (0.45), the ring (0.8) and the flight (0.65) are unchanged. | The user's numbers; "shorter recovery" was not given, so about 0.2 s less each. |
| CF-D2 | Each lock moved with its tell, so the time from the lock to the hit stays as fair as before: Gomibú 0.8 s (was 0.8), Tortidragón 1.0 s (was 1.05). Suites assert at least 0.8 s. | A faster tell must not shorten the sidestep after the lock. |
| CF-D3 | Gomibú's live numbers are in `WildboundBeastConfig.Gomibu.tuning`; the rule module `WildboundCandyGomibuAttack` (ServerStorage, no live caller) carries the same numbers. Flanfuria and Tortidragón read their rule modules. | Keep the two Gomibú copies equal. |
| CF-D4 | The clips keep their lengths (no new animation upload): the 0.9 / 1.0 s telegraph clips and the 0.7 / 0.85 s recover clips are cut at the phase change, so the last 0.1-0.25 s of each is not shown. Fitting the clip speed to the phase (`BeastPhaseAt` / `BeastPhaseUntil` are already on the client model) is a follow-up. | Re-baking the clips means re-publishing animations, an owner action. |
| CF-D5 | The two beast suites (Flanfuria, Tortidragón) now read their times from the rule module instead of literals, and the Gomibú beast suite looks for its lock in the first window too (the lock now falls before 1.2 s). | The literals were the old timings; the rule suites pin the numbers. |
| IC-D1 | `Toolbar.ICON_IDS` holds the four upload ids; `Toolbar.ICONS` is built from it as `rbxthumb://type=Asset&id=<id>&w=150&h=150`. No new upload, no change to who owns the images. | The form the plan named; one place to add an icon later. |
| IC-D2 | The owner action U10 (re-upload or share the icons with the group) is no longer needed for the hotbar; it stays optional in the overview. | The images load as they are. |
| DG1-D1 | The three lanes are side by side (left, right, centre), each 5 studs wide and 22 long, parallel to his facing, with no overlap, and all three are drawn from the start. They follow the target until one lock at 0.35 s. | A player reads the whole combo at once; each lash lands at least 0.8 s after its lane appeared (1.15 / 1.5 / 1.85 s). |
| DG1-D2 | Tell 0.8 s; the three lashes run back to back, 0.35 s each; recovery 1.0 s and cooldown 7 s unchanged (the whole combo takes 2.85 s, was 2.45 s for one lash). | The user asked for a faster tell and a combo, not a shorter rest; DG5 (anger) shortens the cooldown later. |
| DG1-D3 | A player is hit at most once per combo; stepping into a lane whose lash already landed is safe. Each lash is its own dodge telegraph. | One egg drop per combo; it rewards reading the order. |
| DG1-D4 | The licorice ribbon (client art) still unrolls once per combo, at the first lash; the lanes on the ground flash for each lash. The clips are still unpublished (O2). Three ribbons are a client follow-up. | No test harness for the client art; the ground lanes carry the information. |
| DG2-D1 | Numbers: tell 0.9 s (mouth open, a fixed 70-degree cone of 30 studs drawn), pull 2 s at 7 studs/s toward him, no pull within 5 studs, recovery 0.6 s, cooldown 12 s. | The doc said "about 2 s" and "a velocity the client can fight"; 7 is under half a walk (16), so running away always wins. |
| DG2-D2 | He uses it only on a target that stayed out of the lash's reach (18 studs) for 2 s, in front of him, within 30 studs, with time left in the chase. | It reels in a runner who keeps away; the lash stays the close-range attack. |
| DG2-D3 | The pull is re-checked every server step: it needs the target in the cone, a clear line of sight (`world.lineOfSight`, the same as his sight) and the target alive and out of a safe zone. The server sends a `Pull` every 0.25 s, each valid 0.35 s, so cover stops it within about a third of a second. | "Break line of sight behind cover." |
| DG2-D4 | The target's own client applies the pull (it owns its character's physics): it shifts the character flat toward him, capped at 8 studs/s, only while the last `Pull` is valid. The `Pull` event is target-only (not in `Audience.VISUAL`). `WildboundBeasts.server` and `WildboundBeastConfig` were not edited. | The existing pattern for Streamer's knock; no new remote, no shared-server edit. A modified client could ignore its own pull (no damage or egg at stake). |
| DG2-D5 | VFX: candy-coloured crumbs (a ParticleEmitter with Roblox's default particle, no upload) blow from the player toward him during the pull; "Efectos suaves" turns them off, not the pull. No new animation: the boss's clips are still unpublished (O2). | No asset upload. |
| DG2-D6 | The vacuum never hits, never deals damage and never drops the egg. | The lash stays his only egg-drop attack (DG1). |
| DG3-D1 | The wall is a ring of radius 9 around the spot the target runs to (0.5 s ahead, at most 8 studs), with one exit of 140 degrees (a 16.9-stud chord) sideways to the route, on the side away from him. Crack line 1.0 s, up 3 s, cooldown 14 s. | "Across the predicted route", "always an exit", "a crack line at least 0.8 s ahead". |
| DG3-D2 | He raises it only on a runner: a target out of the lash's reach for 1 s, within 30 studs, moving at 10 studs/s or more and away from him (cosine at least 0.5). He keeps chasing while it rises. | It cuts an escape, not a standing player; it comes before the vacuum (2 s) on the same runner. |
| DG3-D3 | It reuses the shared "walls" shape (Root's enclosure layout): the beast client draws it flat, raises it at its time, makes it solid on the target's client only and leaves open any piece that would rise inside the player. No client, server or Config edit. | The tested path; nobody is ever sealed in a wall piece. |
| DG3-D4 | It never hits, never deals damage and never drops the egg. Other players never collide with it (as Root's walls). | Unchanged rules for walls; the lash stays the only egg drop. |
| DG5-D1 | The meter fills in 10 s of carrying an egg inside his territory (the doc said "over time"); a perfect dodge of a lash adds a quarter; full, he rages 10 s; it empties when the target stops carrying, leaves the territory, or after the rage. One meter per encounter (his current target). | A rage has to fit inside his 15 s chase. |
| DG5-D2 | "Faster casts, shorter cooldowns" while raging: every cooldown is halved (lash 7 -> 3.5 s, vacuum 12 -> 6 s, wall 14 -> 7 s). The tells stay as they are (the lash is already at the 0.8 s floor). | Fair-strike floor; the cooldowns are what makes him feel faster. |
| DG5-D3 | The meter is visible to everyone near: the clients tint him red with a Highlight (fill transparency 1 - 0.5 x the meter, 0.35 while raging), and `Anger` joins `WildboundBeastAudience.VISUAL`. No new asset. | "The meter is visible: his colour shifts toward red." |
| DG7-D1 | Three decoys at fixed spots (local to the layout centre): `stair` (6, -33), just outside the bottom tier on the south side where the CT1 stair will start; `path` (-60, 8), the edge of the main route before the plaza; `rareNest` (-86, -21), beside nest R1 (Rara), on the side away from Flanfuria's post. Each is the kit's `CakeTower` at scale 0.07 (about 5 studs wide), built at runtime by `WildboundCandyTrapCakeService` (the place never needs saving). | "On the routes a thief must use"; the kit cake keeps the biome's look; built like the roulette station, not hand-placed. |
| DG7-D2 | The reward is a slice: a sugar rush, x1.25 walk speed for 5 s (cap 26, the dodge boost's cap), once per cake per player per round. It goes through `WildboundServer.applyCarry` (the one WalkSpeed writer) via a server-only player attribute `WildboundCandyRushUntil`, plus one `do` block that re-applies the speed at the start and end. No Esencia. | The economy (options A-G) is still the user's call; a new Esencia source would change it. The server edit is two tiny additive pieces (NH-W13 stays green). |
| DG7-D3 | "Only while Dormant or Patrol" is implemented as "only while he sleeps" (no Don Glaseon encounter lives: `Beast_bossAwake` false). Waking unmasks the disguise; it re-arms 30 s after he sleeps again. A patrolling boss is visibly walking on the plaza, so he cannot also be a cake, and the encounter's phase is not visible outside the beast script without editing a shared file. | Never during a chase, as asked; one Don Glaseon on screen at a time. |
| DG7-D4 | While he is in disguise his bed on BossHome is empty: the service writes `WildboundTelemetry.Candy_bossDisguised` and `WildboundCandyDonGlaseonService` hides the sleeper on it. | The trap cake is him, so he cannot also sleep at home. |
| DG7-D5 | It springs when a player comes within 5 studs or bites it: a sleeping copy of him rises out of the cake for the 0.8 s tell (the fair-strike floor), then a lash pushes everyone within 9 studs away (12 studs over 0.4 s, the beasts' `WildboundBeastPush` slot), no damage and the egg stays; 0.7 s later the three decoys pop (confetti) and grow back 90 s later with a new random pick. The tell for the disguised cake is a slow breath (its meshes grow 4 % and back every 2.4 s) and a crumb now and then (a ParticleEmitter at 0.7 per second). | DG1 keeps the lash as his only egg-drop attack; a push off the route is the scare. No new asset (Roblox's default particle; the boss prefab already in the place). |
| DG7-D6 | The two prompt words ("Comer porción", "Torta") live in `WildboundCandyTrapCake.TEXT`, not in `WildboundText`, which the beast-revision session holds. Move them when it is free. | Shared-file protocol. |
| CT-D1 | The tower pieces are added by the Candy builder at every server start (`Builder.syncTower`, called from `WildboundCandyNests.applyFlags` beside `syncNests` and `syncPortal`), once, into `Candy_Bioma_v1.Tower`. The place file needs no save. | The CG2 pattern: a reopened or published place has them without an Edit session; never built by hand. |
| CT-D2 | CT1: four flights, one per tier, climbing round the outside of each tier from the south (by the DG7 stair decoy), on the floor or on the ledge of the tier below: steps 3.8 wide, 2.6 deep, at most 1 stud high (13 + 11 + 10 + 8 = 42 steps), each a solid column down to its floor; a 15-degree landing on each ledge leads to the next flight. | Walkable without jumping; the ledges are 5.8 studs wide, so a flight fits beside the next tier's wall. |
| CT-D3 | CT2: the kit's cake is one mesh across all tiers, so the tiers' look cannot turn. What turns: an invisible collision disc on each of the three lower tiers (anchored, with `AssemblyAngularVelocity`, which the physics uses to carry whoever stands on it) and a ring of 16 cream dollops on each rim that every client turns at the same rate from the server clock (`WildboundCandyTowerClient`). One turn in 90 s (about 1.8 studs/s at the widest rim), alternating sense. | Proper carrying with no moving physics parts and no jitter; slow and readable. |
| CT-D4 | The top tier does not turn: it is the summit for the best egg (CT3), Frutillón (CT4) and La Duquesa Burbuja, whose seat at (612, 46, -3) stays where it is. | The parent session's scenery stays put; Frutillón's rolls stay readable on still ground. |
| CT-D5 | The stair is static while the ledges turn, so a player standing on a ledge is carried slowly into the next flight's steps (a gentle bump). Accepted as part of the tower's feel. | No pinning at 1.8 studs/s; they can walk or jump. |
| CT3-D1 | The summit holds a new nest T1, rarity Legendaria but not event-only, so the island system gives it what the Legendaria row already gives (a Flanfuria egg, reward tier Heart, the 1.8 s steal hold) and refills it on the 300 s wave like every other nest. No new `Huevo de la Gran Torta` species. | The doc allowed "the top Legendaria"; a new species would need art and economy numbers the user has not chosen. |
| CT3-D2 | The nest is the kit's nest at 70 % (5.2 studs wide) at local (0, 5.8) on the summit (radius 8.7): clear of La Duquesa's 6-stud seat on the centre and across the summit from where the stair arrives (about 17 studs away). It is built by `syncTower` into the `Nests` folder, so `WildboundCandyNests` reads it like the others; it is not in `Layout.NESTS` (the floor nests). No guardian post binds it: CT4 Frutillón guards it. | The summit is small; the player must cross it past Frutillón. |
| CT4-D1 | Frutillón is built at runtime from plain parts (a 4-stud red body with a SpecialMesh sphere, a leaf cap, yellow seeds) by `WildboundCandyFrutillonService`: no model upload. It is not a beast encounter of `WildboundBeasts.server` (no director slot, no BeastHit): a standalone guard with its own pure rules (`WildboundCandyFrutillon`). | The doc's proposal needed a model; parts avoid an upload. Standalone keeps the shared beast server untouched. |
| CT4-D2 | It rolls on a ring of radius 6.3 round the summit's centre (its edge stays 4.3 studs from the centre, outside La Duquesa's 3-stud circle, and inside the 8.7-stud summit), toward the player on the summit nearest it and 0.6 rad past them, at 18 studs/s; tell 0.8 s (squash to 75 % and a red neon line along the arc), recovery 1 s; a player it rolls over (within 3 studs) is pushed 12 studs outward over 0.4 s, once per roll. Alone 6 s, it goes back to its rest spot (west) and sleeps. | "Rolls around the top tier", "telegraphs with a squash and a line", "bump players off the edge", never through her seat. |
| CT4-D3 | Seeds: while anyone stands on the stair, one seed every 2.5 s (at most 3) starts at the top step and bounces down step by step at 8 steps/s; a climber within 2 studs is pushed 6 studs down the stair over 0.3 s, once per seed. | "Throws strawberry seeds that bounce down"; the 5 s trip makes each seed readable from below. |
| CT4-D4 | Knockback only: damage 0, never the egg, all pushes in the beasts' `WildboundBeastPush` slot. Don Glaseón's climbing or roaring for a summit carrier is left to his existing territory rules (no new behaviour). | Candy beasts never damage; DG6 owns the roar. |
| DG4-D1 | The glaze is three permanent puddles on his plaza (local (0, 36), (38, 6), (-30, 26), radius 6), laid by the Candy builder's `syncTower` as flat glossy decor, off the stair and at least 12 studs from any nest. He does not cast them during the fight. | "A puddle where the player skates"; permanent puddles are always readable, and a cast puddle would need a new beast phase and client art. |
| DG4-D2 | Skating runs on the player's own client (it owns its character): on glaze a flat `LinearVelocity` holds the slide, which turns toward the steering at 1.5 per second (0.5 with no input, losing almost no speed). It never slows the player below their walk. Another push in the beasts' slot wins while it lasts. | "It does not slow the player; they lose grip when turning"; the faster you enter, the more you slide. |
| DG4-D3 | A slip is a turn of 75 degrees or more against the slide at 17 studs/s or more (above the 16 walk: a sprint or a trained walk). The client asks the server (`WildboundNetwork.CandyGlazeSlip`, no argument read); the server checks the body is on a puddle, its own flat speed is at least 13 (lag tolerance), it is not already down and 3 s passed since its last slip, then calls the shared server ragdoll (`SistemaSonriente` `Ragdoll.aplicar`, used, not edited) for 1 s, carried along the slide (0.8 of its speed, at most 25) with a small lift. No damage, the egg stays. | "Reuse the teammate's ragdoll path"; "about 1 s and readable"; the server never trusts the client's word alone. |
| DG4-D4 | The server edit is one `do` block (no new top-level local; NH-W13 stays green). | The 200-local limit. |
| AR-D4 | Fixed in passing: MechanicsWiring W1's stale pin (`canSteal` / `steal` without `maxCarry`, a known red since NH2) now pins the current calls. | The same case was being re-pinned; W1 leaves the known-red list. |

## Evidence

### AR (2026-11-15)

- Change: `WildboundArrulloService`: `Service.ENABLED = false`; `qualifies` returns false while it is off. Suite: MechanicsWiring W1 re-pinned on purpose (the flag, the guard in `qualifies`; the D10 list kept) and its stale `maxCarry` pin fixed.
- Fingerprint rule: before writing, Studio equalled the repo HEAD for ArrulloService 5524/2803847513 and MechanicsWiring_Test 19129/558721442. Exact replacements (`multi_edit`). After: Studio == repo, ArrulloService 5934/4037729304, MechanicsWiring_Test 19833/2891207789.
- Baseline before any write, run `154105b8`: MechanicsWiring 9/1 (the known W1), Tuning 15/1 (the known DT1), Arrullo 13/0, EggCarry 39/0.
- RED (test pushed, source unchanged), run `8b054286`: MechanicsWiring 9/1 ("lacks Service.ENABLED = false"; the stale `maxCarry` case already passed).
- GREEN, run `0d6a4446`: MechanicsWiring 10/0, Arrullo 13/0, EggCarry 39/0. Known reds only: Tuning DT1, WaveClock RW5. A fresh load of the service answered `qualifies` false for Común, Rara, Épica, Legendaria and the event egg.
- Solo Play (PlayLock `AR`, cleared after; Play stopped; memory saves): the egg prompts showed Común and Rara 0.8 s, Épica (6 eggs) and Legendaria (5) 1 s, all with `WildboundStealHold` set (before AR a rare egg's prompt had no hold). `HeistProbe` "steal" on island I4 (Épica): stolen (`Egg:10`, WalkSpeed 11 while carrying); the client's `WildboundArrulloUI` stayed disabled. No script errors from these scripts in the output (only the place's known texture-pack and DataStore lines).
- Found: the live holds are the tuning folder's 0.8 / 1, not the module's 0.5 / 0.75 that the overview called live. EC settles it.
- Not checked: a real held prompt by a person (the probe stands in for a completed hold), the event egg in Play, two players, a phone.

### EC (2026-11-15)

- Change: `WildboundEggCarry`: `RARE_HOLD` replaced by `RARA_HOLD 0.9`, `EPICA_HOLD 1.3`, `LEGENDARIA_HOLD 1.8` (`STEAL_HOLD 0.5` is the Común hold); `RARE_HOLD_MAX = 2.5`; `tune` keeps the order; `holdFor` picks the rarity's key, the event egg its Legendaria hold. `WildboundTuningSchema`: the `Eggs` rows `STEAL_HOLD` 0.5 (0.35-1), `RARA_HOLD`, `EPICA_HOLD`, `LEGENDARIA_HOLD` (0.35-2.5), `RARE_HOLD` gone. The server is unchanged (it already asks `EggCarry.holdFor(rarity, slot.special)`).
- Suites: EggCarry's two NH1 cases re-pinned on purpose as EC cases, plus a new case on the tuning rows; Tuning's coverage list names the four keys.
- Fingerprint rule: before writing, Studio equalled HEAD for EggCarry 14881/2061714670, EggCarry_Test 41801/2326244369 and TuningSchema 41284/3354955688. **Studio's `WildboundTuning_Test` differed** (21468 vs 21369): it held the BP1 re-pin of `COST_GROWTH` 1.1 that the repo lacked. Pulled into the repo first (then equal, 21468/2754302581). Exact replacements. After: Studio == repo, EggCarry 15624/2066359100, TuningSchema 41632/1344336212, EggCarry_Test 43940/717637582, Tuning_Test 21596/3582425013.
- RED (tests pushed, sources unchanged), run `3fcc04d2`: EggCarry 37/3 ("Rara hold: expected 0.9, got nil", ...), Tuning 14/2 (DT1 STEAL_HOLD 0.8, "missing Eggs.RARA_HOLD").
- GREEN, run `000a3ae2`: EggCarry 40/0, Bat 13/0, Gear 15/0, MechanicsWiring 10/0, NestRefill 5/0, TuningWiring 8/0. Red: Tuning 15/1, DT1 now on `Eggs.PICKUP_DELAY` (EC-D3; a direct scan listed the three drifts), WaveClock RW5 (known).
- Solo Play (PlayLock `EC`, cleared after; Play stopped; memory saves): the egg prompts read Común 0.50 s (16 eggs), Rara 0.90 (8), Épica 1.30 (5), Legendaria 1.80 (5), each with the same `WildboundStealHold`; the runtime tuning folder `Eggs` held the four new values. `HeistProbe` "steal" on island I5 (Legendaria): stolen (`Egg:13`). No script errors from these scripts in the output.
- Not checked: a person holding the prompt (the probe stands in for a full hold, so the server's measured-hold refusal at the new lengths is suite only), a glove's shorter hold on a rare egg, the event egg, two players, a phone. Python (the simulator) not run or edited (EC-D5).

### CF (2026-11-15/16)

- Change: `tools/WildboundCandyGomibuAttack.luau`, `tools/WildboundCandyFlanfuriaAttack.luau`, `tools/WildboundCandyTortidragonAttack.luau` (all in ServerStorage), `WildboundBeastConfig` (Gomibu tuning row), and the timing comment in `WildboundBeastFlanfuria` (CF-D1).
- Suites re-pinned on purpose: the three attack suites (numbers, phases, cooldowns; Flanfuria's `begin` now starts so its release is at 101 whatever the tell) and the three beast suites (CF-D5).
- Fingerprint rule: before any write, the 13 Studio scripts equalled the repo HEAD (the three attack modules and suites, BeastConfig, the three beast modules and suites). The first test edit was checked after the fact (Studio's edited copy equalled the repo's, so both started equal); every later write was checked before. Exact replacements. After: Studio == repo, GomibuAttack 5276/2592455810, FlanfuriaAttack 8453/3924361361, TortidragonAttack 6435/1454845756, BeastConfig 31770/1690292384, BeastFlanfuria 7476/1660655566, GomibuAttack_Test 6973/516961779, FlanfuriaAttack_Test 9253/3889046416, TortidragonAttack_Test 6441/3239426464, BeastGomibu_Test 11039/1727511876, BeastFlanfuria_Test 14213/3321472439, BeastTortidragon_Test 9853/2821800830.
- RED (tests pushed, sources unchanged), run `91c84b8e`: GomibuAttack 2/8, FlanfuriaAttack 8/3, TortidragonAttack 4/3, BeastGomibu 8/1 ("expected 0.8, got 0.9"). The two beast suites reading the rule stayed green (they follow the rule).
- First GREEN run `15de7aec` showed BeastGomibu's lock case looking only in the second window (CF-D5); fixed, run `30eb6020` 9/0. Green in `15de7aec`: the three attack suites, BeastFlanfuria 10/0, BeastTortidragon 9/0, BeastDirector 48/0, BeastEncounters 24/0, BeastAttack 13/0, BeastAudience 17/0, BeastWiring 50/0, BeastDonGlaseon 13/0, Gomibu and Flanfuria clips 8/0. Known red only: TortidragonClips "every clip is published" (owner action O2).
- Solo Play (PlayLock `CF`, cleared after; Play stopped; memory saves). A recorder on the client's beast models logged each phase with its server start and end after `HeistProbe` steals on Caramelo nests:
  - Gomibú (CandyC1): Telegraph 0.80 s, Jump 0.45, Recover 0.50; next tell 3.55 s after the recovery ended; three casts in a row.
  - Flanfuria (CandyR1): Telegraph 0.80, Release 0.80, Recover 0.60; next tell 5.00 s after; four casts.
  - Tortidragón (reached during the later steals): Telegraph 0.80, Release 0.65, Recover 0.60; next tell 4.53 s after.
  - Health stayed 100 (no damage). No script errors in the log (only the place's DataStore, texture-pack and material lines).
- Not checked: how the cut clips look on screen (CF-D4), whether a person can still dodge each cast comfortably, a hit landing in Play, two players, a phone.

### IC (2026-11-16)

- Preload test first (Play, PlayLock `IC`, on the client, `ContentProvider:PreloadAsync`): for each of the four ids the plain `rbxassetid://` form returned `AssetFetchStatus.Failure`, the `rbxthumb://type=Asset&id=<id>&w=150&h=150` form `Success`.
- Change: `WildboundCreatureToolbar`: `Toolbar.ICON_IDS` and `Toolbar.ICONS` built in the thumbnail form (IC-D1). Suite: CT-17 and CT-18 re-pinned on purpose to the thumbnail form; new case "IC: every hotbar icon is an rbxthumb Asset 150x150 of its upload id".
- Fingerprint rule: before writing, Studio equalled HEAD (Toolbar 19587/4270695469, Toolbar_Test 27415/631083022). Exact replacements. After: Studio == repo, Toolbar 19984/3899794392, Toolbar_Test 28673/883761065.
- RED, run `d3f5f902`: CreatureToolbar 19/3. GREEN, run `ebf195e3`: CreatureToolbar 22/0, CandyPets 8/0.
- Solo Play (PlayLock `IC`, cleared after; Play stopped): four temporary tools with `Toolbar.ICONS` as `TextureId` were put in the Backpack; Roblox's own hotbar (`CoreGui.RobloxGui.Backpack.Hotbar` slots 1-4) showed each `Icon` with `IsLoaded = true` at 48 x 48. The tools were removed after. The Studio screen capture does not draw the CoreGui, so there is no picture of it.
- Not checked: a real hatched creature's tool in Play (its `TextureId` comes from the same table, suite only), how the icons look to a person, a phone, a published server.

### DG1 (2026-11-16)

- Change: `tools/WildboundCandyDonGlaseonAttack.luau` (ServerStorage): tell 0.8, lock 0.35, `LASHES = 3`, `SIDES`, `Latigo.lanes`, `impactAt(state, i)`, `comboSeconds()`, `impact(..., i)` once per lash and once per player per combo. `WildboundBeastDonGlaseon`: one telegraphed attack per lash (`e.lashes`), the lanes aim and lock together, the Attack phase lands each lash in order, then Recover; the chase-time check uses the whole combo; `lose` calls off every open lash.
- Suites: CandyDonGlaseonAttack re-pinned (numbers, timeline) plus two new DG1 cases (the three lanes; once per lash, once per player); BeastDonGlaseon re-pinned (three tells, three locks, the strike times, the centre lash at 1.85 s, the 2.85 s combo in the cooldown case) plus a new case (the left lash hits the left lane; stepping into a spent lane is safe).
- Fingerprint rule: before writing, the six Studio scripts (the attack rule and suite, the boss and its suite, the boss service, BossRobustness_Test) equalled HEAD. Exact replacements. After: Studio == repo, DonGlaseonAttack 5973/1856743129, BeastDonGlaseon 13490/3619965978, DonGlaseonAttack_Test 7211/1466872854, BeastDonGlaseon_Test 15488/4155125277.
- RED, run `a2ff002f`: DonGlaseonAttack 3/4, BeastDonGlaseon 9/5. GREEN, run `2cd5e1b3`: DonGlaseonAttack 7/0, BeastDonGlaseon 14/0, BossRobustness 8/0, BeastWiring 50/0, BeastEncounters 24/0, CandyDonGlaseon 6/0, CandyClipPublish 6/0.
- Solo Play (PlayLock `DG1`, cleared after; Play stopped; memory saves), a recorder on the client's boss model:
  - Each combo: Telegraph 0.80 s, Attack 1.05 s (the three lashes), Recover 1.00 s; the next Telegraph 7.05 s after the recovery; the client built 3 tell models per combo (18 for 6 combos).
  - Standing still 17 studs in front of his home on the plaza with a stolen Épica egg (`Egg:24`): the egg left the arms ("Dropped") 1.94 s after the tell began (the centre lash at 1.85 s plus one server step), and the player was pushed from z 14 to z 25.9 (12 studs along the lash).
  - Standing on a cake tier about 24 studs above him, no lash landed (the existing height rule, `hitHeight` 8).
  - No script errors in the log.
- Not checked: dodging the side lanes by hand, the perfect dodge on a lash, how three lanes read on screen, two players, a phone.

### DG2 (2026-11-16)

- Change: new `tools/WildboundCandyDonGlaseonVacuum.luau` (ServerStorage; the pure rule); `WildboundBeastDonGlaseon` (Inhale and Vacuum phases, `Pull` events, the cone Tell and its TellEnd, `lose` clears it); `WildboundBeasts.client.luau` (`handlers.Pull`, `stepPull` on Heartbeat, the crumbs). Registered in `tools/studio-fresh-runner.luau` SPECS, `tools/deploy_manifest.py` and `tools/test_deploy_manifest.py` (the two Python files edited by hand, not run: no Python here).
- Suites: new `WildboundCandyDonGlaseonVacuum_Test` (5 cases); BeastDonGlaseon two new cases (a target kept out of reach is pulled: cone, Inhale 0.9, Vacuum 2, Pulls toward him, Recover; behind cover the pull stops); BeastWiring one new case (the client handler: never a bystander, capped, ends with its refresh; Pull not in `Audience.VISUAL`) and NB6 re-pinned on purpose ("Efectos suaves" now also drops the crumbs: three guards, was two).
- Coordination: the parent session was told before the shared client file and its test were written; it was not writing Studio then.
- Fingerprint rule: before writing, Studio equalled HEAD for BeastWiring_Test 49464/1801545942, BeastsClient 51090/1666555114, BeastDonGlaseon 13490/3619965978 and BeastDonGlaseon_Test 15488/4155125277 (the two new modules did not exist). A replace-all edit did not apply in Studio (caught by the fingerprint: 28 bytes short) and was redone as two edits. After: Studio == repo, Vacuum 4564/2464343848, Vacuum_Test 5241/2859486905, BeastDonGlaseon 16513/822813627, BeastsClient 52992/433460321, BeastDonGlaseon_Test 18017/1210400504, BeastWiring_Test 51083/1289257319. The client compiles.
- RED (tests pushed, sources missing or unchanged), run `18714698`: Vacuum suite "module not found", BeastDonGlaseon 14/2 ("no vacuum cone"), BeastWiring 50/1 ("missing function handlers.Pull").
- Two test fixes before GREEN: the target in the boss test is held inside his territory (it left it 2.2 s into the chase), and the no-hit check is limited to the vacuum's own window (a later lash may land). NB6 re-pinned as above.
- GREEN, run `70ac1dcc`: Vacuum 5/0, DonGlaseonAttack 7/0, BeastDonGlaseon 16/0, BeastWiring 51/0, BossRobustness 8/0, BeastEncounters 24/0, BeastAudience 17/0, BeastAnimPlan 12/0.
- Solo Play (PlayLock `DG2`, cleared after; Play stopped; memory saves), the player's client kept the player 24 studs from him until he inhaled:
  - Crossing the cake: he climbed it in his simulation (y 40.9 against 3.6), the cake blocked his line of sight, the cone Tell arrived and no `Pull` came (DG2-D3 working as designed).
  - On the flat plaza, standing still: 7 `Pull` events (speed 7, direction toward him); the distance went 24.33 -> 10.80 studs in 1.95 s (about 6.9 studs/s).
  - Walking away at 16 during the next vacuum: the distance grew 24.3 -> 31.1 studs in the first second, then the pulls stopped once past his 30-stud range (4 pulls in all); the crumbs were enabled. No script errors in the log.
- Not checked: hiding behind a real wall by hand (only the cake case), a perfect dodge (nothing to dodge), how the cone and crumbs look to a person, two players (a bystander gets no Pull by construction, suite only), a phone.
- Seen in passing, not changed: in his simulation the boss walks up the Gran Torta's tiers (his ground follows the raycast); the territory rule allows it.

### DG3 (2026-11-16)

- Change: new `tools/WildboundCandyDonGlaseonWall.luau` (ServerStorage; the pure rule); `WildboundBeastDonGlaseon` (`raiseWall` in the chase, the wall's own TellEnd at its time in any phase, `lose` clears it). Registered in the runner SPECS and the two manifest files (Python edited by hand, not run). No shared file was edited.
- Suites: new `WildboundCandyDonGlaseonWall_Test` (5 cases: numbers, timeline, placement ahead on the route, the exit sideways and away from him and at least 16 studs, only on a runner); BeastDonGlaseon two new cases (a runner gets one wall: crack line 1.0 s, ahead of it, sideways exit, down after 3 s, at least 1 s into the chase; no wall for a target that does not run).
- Fingerprint rule: before writing, Studio equalled HEAD `b6c90d6` for BeastDonGlaseon 16513/822813627 and BeastDonGlaseon_Test 18017/1210400504. Exact replacements. After: Studio == repo, Wall 3631/3519193033, Wall_Test 4470/3904662168, BeastDonGlaseon 18423/1729599941, BeastDonGlaseon_Test 20137/3509967721.
- RED, run `d74ef6b5`: Wall suite "module not found", BeastDonGlaseon 17/1 ("no wall"). GREEN, run `13946ec4`: Wall 5/0, Vacuum 5/0, DonGlaseonAttack 7/0, BeastDonGlaseon 18/0, BossRobustness 8/0, BeastWiring 51/0, BeastEncounters 24/0.
- Solo Play (PlayLock `DG3`, cleared after; Play stopped; memory saves): the player's client ran around the Gran Torta at walk speed (16) with him chasing. 5.2 s in, the wall's crack line appeared flat on the floor (24 pieces 0.12 studs high, two exit posts); 1 s later it stood solid (12 pieces colliding on this client); the scripted runner, which kept running into it instead of looking for the exit, stood still against it (speed 0) for the 3 s it stood, then ran on when it went down. No script errors.
- Not checked: a person finding the exit by eye, the wall seen by a second player (never solid for them, by construction), how it reads on a phone. The look is Root's wall colours (no chocolate texture: no new asset).

### DG5 (2026-11-16)

- Change: new `tools/WildboundCandyDonGlaseonAnger.luau` (ServerStorage; the pure meter); `WildboundBeastDonGlaseon` (the meter each step, a chunk on a dodged lash, `Anger` events, cooldowns scaled); `WildboundBeasts.client.luau` (`handlers.Anger`, the red Highlight); `WildboundBeastAudience` (`Anger` in VISUAL). Registered in the runner SPECS and the manifests (Python edited by hand, not run).
- Coordination: "writing" sent to the parent and beast-revision sessions before the client, audience and wiring test were written. Studio was in another session's Play (lock `critter-brain`) and was waited out. The beast-revision session had uncommitted edits of its own in the repo's `WildboundBeasts.client.luau` (Viper and Pouncer phases); only the DG5 hunk was staged for this commit, and Studio holds HEAD plus DG5 only.
- Suites: new `WildboundCandyDonGlaseonAnger_Test` (5 cases); BeastDonGlaseon two new cases (a carrier fills it in 10 s and the next lash cooldown is halved; it empties when the egg is gone); BeastWiring one new case (the tint handler; `Anger` visible to bystanders).
- Fingerprint rule: before writing, Studio equalled the committed versions (BeastsClient 52992/433460321, BeastAudience 11067/2813954137, BeastWiring_Test 51083/1289257319, BeastDonGlaseon 18423/1729599941, BeastDonGlaseon_Test 20137/3509967721). After: Anger 2664/1106081784, Anger_Test 4200/1084172373, BeastDonGlaseon 19528/4116056984, BeastDonGlaseon_Test 21796/1186522719, BeastAudience 11183/4179930891, BeastWiring_Test 51698/3946662713, BeastsClient 53799/2312708310 (= HEAD plus the DG5 hunk; the repo file is larger only by the beast-revision session's uncommitted lines).
- RED, run `5e03bd86`: Anger suite "module not found", BeastDonGlaseon 18/2 ("anger reports 0"), BeastWiring 51/1 ("missing function handlers.Anger"). GREEN, run `24f7fa2c`, 155 cases: Anger 5/0, Wall 5/0, Vacuum 5/0, DonGlaseonAttack 7/0, BeastDonGlaseon 20/0, BossRobustness 8/0, BeastWiring 52/0, BeastEncounters 24/0, BeastAudience 17/0, BeastAnimPlan 12/0. The client compiles.
- Solo Play (PlayLock `DG5`, cleared after; Play stopped; memory saves): with a stolen Épica egg (`Egg:25`) and the client keeping the player 24 studs from him, his model's `BossAnger` rose 0.10 -> 0.93 in 9 s and the tint's fill transparency fell 0.95 -> 0.54; when the player drifted out of the territory the meter dropped to 0 and the tint cleared. A first try lost the egg to a lash before the loop started: the meter then also emptied. No script errors.
- Not checked in Play: the full rage (the scripted orbit left the territory at 0.93; the rage and the halved cooldown are suite only), a perfect dodge adding a chunk, the tint seen by a second player.

### DG7 (2026-11-16)

- Change: new `tools/WildboundCandyTrapCake.luau` (ServerStorage; the pure rules: spots, disguise, spring, lash, pop, regrow, slice, rush); new `src/wildbound/WildboundCandyTrapCakeService.server.luau` (ServerScriptService; builds the decoys from the Candy kit at runtime, prompts, breath and crumbs, the pop-out copy, the push, `Candy_bossDisguised`); `WildboundServer` (one rush line in `applyCarry`, one `do` block that re-applies the speed when a rush starts and ends; no new top-level local); `WildboundCandyDonGlaseonService` (the sleeper also hides while disguised). Registered in the runner SPECS and the two manifest files (Python edited by hand, not run: no Python here).
- Suites: new `WildboundCandyTrapCake_Test` (8 cases: numbers, spots on the routes, disguise only while asleep, spring/lash/pop/regrow, the slice and the bite, the rush rule, the service wiring, the two server edits).
- Coordination: "writing WildboundServer / WildboundCandyDonGlaseonService" sent to the parent and beast-revision sessions before the writes; "done with" after.
- Fingerprint rule: before writing, Studio equalled HEAD for WildboundServer 218893/2080545631 and WildboundCandyDonGlaseonService 3779/1409689320 (the three new scripts did not exist). Exact replacements. After: Studio == repo, TrapCake 6507/2920169595, TrapCake_Test 9925/821785540, TrapCakeService 10435/2606548191, WildboundServer 219947/2038955413, DonGlaseonService 4072/1973325740.
- RED: run `c8eb7345` (suite "module not found: WildboundCandyTrapCake"); with the module and the service in, run `ab0897e2`: 7/1 ("applyCarry reads the rush" missing).
- GREEN, run `defd93d9`, 116 cases: CandyTrapCake 8/0, MechanicsWiring 10/0 (NH-W13 local limit), Bat 13/0, CreatureToolbar 22/0, RouletteService 9/0, EggCarry 40/0, BossRobustness 8/0, CandyDonGlaseon 6/0.
- Solo Play (PlayLock `DG7`, cleared after; Play stopped; memory saves):
  - The three cakes stood on the floor at (618, -36), (552, 5) and (526, -24), about 5.2 x 4.6 studs. The stair one was the disguise: crumbs on, its meshes breathing; `Candy_bossDisguised` true, `Beast_bossAwake` false, the sleeper gone from BossHome.
  - The player placed 4 studs from it: the copy of him rose out of it 0.13 s later, the push slot appeared on the root 0.89 s after that, the player went from x 622 to 635 (13 studs, away from the cake), the three decoys popped at 1.65 s (confetti). Health stayed 100. The boss then woke (the spot is inside his territory) and the disguise stayed off.
  - The rush through the server: setting `WildboundCandyRushUntil` 5 s ahead raised WalkSpeed 16 -> 20 and back to 16 after 5.2 s.
  - Regrow: about 90 s after the pop the three cakes were back, a new pick (the rare-nest cake) breathing, `Candy_bossDisguised` true again after he had gone back to sleep.
  - No script errors from these scripts in the output (only the place's texture-pack, asset and DataStore lines).
- Not checked: a bite through the real prompt (neither `ProximityPrompt:InputHoldBegin` from a script nor a simulated E key fired it in Studio; the bite rules are suite only), how the breath and crumbs read to a person, the egg-carrier case (the push never touches the egg by construction), two players, a phone.

### CT1 and CT2 (2026-11-16)

- Change: `tools/WildboundCandyLayout.luau` (`Layout.TOWER`: the four tiers from the kit's proxies at the builder's scale, the spin period and senses, the stair numbers; `Layout.stairSteps()`); `tools/WildboundCandyBuilder.luau` (`Builder.syncTower`: the stair columns, the three turntable discs, the dollop rings); `src/wildbound/WildboundCandyNests.luau` (`applyFlags` also runs `syncTower`, a third return value); new `src/wildbound/WildboundCandyTower.client.luau` (StarterPlayerScripts; turns the rings). Registered in the runner SPECS and the two manifest files (Python edited by hand, not run).
- Suites: new `WildboundCandyTower_Test` (6 cases: tiers equal the kit, the flights and their rises and ledges, the start by the decoy and no nest underfoot, syncTower's stair once, the turning discs and rings, the client and applyFlags wiring).
- Coordination: "writing" sent to the parent session before Layout, Builder and CandyNests were written; the top tier, where La Duquesa sits, does not move.
- Fingerprint rule: before writing, Studio equalled HEAD for CandyLayout 5659/669051350, CandyBuilder 19220/187397696, CandyNests 7804/1134762144 (and CandyKit, CandyNests_Test, CandyLayout_Test, read only). Exact replacements. After: Studio == repo, CandyLayout 7913/3889673665, CandyBuilder 22730/361553883, CandyNests 8159/183275574, TowerClient 1907/3036841359, Tower_Test 7804/2999829394.
- RED, run `b1625743`: Tower 0/6 (`Layout.TOWER` nil, `stairSteps` and `syncTower` missing; the client source was stood in by CandyNests for that run because the client did not exist yet).
- One test fix before GREEN (the disc-height case added 0.1 twice). GREEN, runs `fa275e26` + `616c66e7`: Tower 6/0, CandyLayout 14/0, CandyNests 12/0, CandyTrapCake 8/0, Portal 11/0. After the Heartbeat change, run `b966d9f2`: Tower 6/0, CandyLayout 14/0.
- Solo Play (PlayLock `CT1-CT2`, cleared after; Play stopped twice; memory saves):
  - At start the server built `Candy_Bioma_v1.Tower`: 42 steps, Turntable_1-3 at y 13.6 / 24.43 / 33.82 with angular velocity +0.0698, -0.0698, +0.0698 rad/s.
  - Carry: a player set on tier 1's ledge (radius 23.5) went round with it at 0.0701 rad/s over 6 s, the radius unchanged (23.50 -> 23.51), standing on the disc.
  - Climb: the client walked the player step by step with `Humanoid:MoveTo`. Flights 1 and 2 ended level with their tiers (root y 16.06 and 26.96 over tops 13.5 and 24.33); on the first run the scripted walker fell off during the landing from flight 2 to 3 (it had 1.2 s to cross the turning ledge while Don Glaseon chased). Started again from the end of flight 2, it climbed flights 3 and 4 (root y 36.43 and 43.52 over tops 33.72 and 40.94) and stepped onto the summit (y 44.0).
  - The rings: the first client script used RenderStepped, which never fired in the Studio Play client (0 frames in 2 s), so the rings stood still; changed to Heartbeat, the three rings turned at -0.0698, +0.0698, -0.0698 rad/s in the client's angle measure, the same sense and rate as the carried player.
  - No script errors from these scripts in the output.
- Not checked: how the turning reads to a person (motion comfort), a person climbing by hand, two players, a phone.

### CT3 (2026-11-16)

- Change: `tools/WildboundCandyLayout.luau` (`Layout.TOWER.summit`); `tools/WildboundCandyBuilder.luau` (`syncTower` lays `Nests.Nest_T1` on the summit, optional `kit` and `library` arguments). No server or island code changed: the island system already reads every live marker in the `Nests` folder and refills on the wave.
- Suites: `WildboundCandyTower_Test` gains two cases (the summit spec: Legendaria, not event-only, on the still top tier, clear of La Duquesa, across from the stair's arrival; the built marker, read by `WildboundCandyNests.read` and turned into island `CandyT1`, Legendaria, Heart, one egg, no guardian post). Its spec gains `mod:WildboundCandyNests` and `inst:ServerStorage.WildboundAssets.CandyKit` (read only).
- Fingerprint rule: before writing, Studio equalled the CT1/CT2 versions (CandyLayout 7913/3889673665, CandyBuilder 22730/361553883, Tower_Test 7804/2999829394). Exact replacements. After: Studio == repo, CandyLayout 8223/2050365548, CandyBuilder 24287/3853704070, Tower_Test 10220/2797851613.
- RED, run `026431c5`: Tower 6/2 ("Layout.TOWER.summit", "Nest_T1 in the Nests folder"). GREEN, runs `b8275eaf` + `feb96876`: Tower 8/0, CandyLayout 14/0, CandyNests 12/0, CandyTrapCake 8/0.
- Solo Play (PlayLock `CT3`, cleared after; Play stopped; memory saves):
  - At start `Nest_T1` stood on the summit at (612, 41.7, 2.8), Enabled; the island system had egg `Egg:30` of island `CandyT1` in it.
  - `HeistProbe` "steal" on `CandyT1`: stolen, the player stood on the summit at y 44.0, carrying a Legendaria egg, walk speed 11.
  - The wave: at 301 s of game time `Wave` went 1 -> 2 and `CandyT1` had a new egg `Egg:53` in the nest (the candy egg art: flan body, gold glaze, at y 43.4 on the bowl) while the first one was still carried.
  - No script errors from these scripts in the output.
- Not checked: a person holding the prompt for 1.8 s on the summit, carrying the egg down the turning tiers, Don Glaseon's behaviour toward a summit carrier (his existing territory rules apply; not observed), two players, a phone.

### CT4 (2026-11-16)

- Change: new `tools/WildboundCandyFrutillon.luau` (ServerStorage; the pure rules), new `src/wildbound/WildboundCandyFrutillonService.server.luau` (ServerScriptService). Registered in the runner SPECS and the two manifest files (Python edited by hand, not run). No shared file edited.
- Suites: new `WildboundCandyFrutillon_Test` (6 cases: numbers and the ring clear of La Duquesa; wake and tell; one outward bump per roll and the next roll; back to sleep alone; seeds down the stair; service wiring with no damage or egg path).
- Coordination: the parent session reported the summit floor at y 40.94 with La Duquesa at (612, 40.94, -3); `Frut.summit` reads 40.944 from the layout, and the ring keeps the body 4.3 studs from her centre.
- Fingerprint rule: the three files are new (absent in Studio before; the first test copy was removed after the RED run of the earlier session). After: Studio == repo, Frutillon 8096/4113960932, Frutillon_Test 7624/2383702863, FrutillonService 7081/2994406431 (CandyLayout unchanged, 8223/2050365548).
- RED, run `49de31bd`: "module not found: WildboundCandyFrutillon". GREEN (a minimal loadstring loader: both modules require nothing): Frutillon 6/0.
- Solo Play (PlayLock `CT4`, cleared after; Play stopped; memory saves):
  - Asleep at (605.7, 42.9, -3), its rest spot (west on the ring).
  - The player set on the ring a quarter turn away (y 44): Telegraph at once (body squashed to 0.75, a 10-piece line on the floor), Roll 0.84 s later, the push on the player's root 0.40 s into the roll, Recover at 1.60 s; the player fell from the summit to y 16.8 (a lower tier). Health 100.
  - Seeds: the player held on step 4/2: a seed left the top step every 2.5 s (seeds 2, 3, 4 at 0.1, 2.6, 5.2 s) and the first one pushed the player down the stair (plane velocity (-7.2, 18.7), 20 studs/s = 6 studs over 0.3 s).
  - No script errors from these scripts in the output.
- Not checked: how the roll and seeds read to a person, dodging a roll by hand, a seed bouncing off a moving climber, two players, a phone.

### DG4 (2026-11-16)

- Change: new `src/wildbound/WildboundCandyGlaze.luau` (ReplicatedStorage; the pure rules), new `src/wildbound/WildboundCandyGlaze.client.luau` (StarterPlayerScripts; the skate and the slip request), `tools/WildboundCandyLayout.luau` (`Layout.TOWER.glaze`), `tools/WildboundCandyBuilder.luau` (`syncTower` lays `Tower.Glaze`), `WildboundServer` (one `do` block: the `CandyGlazeSlip` remote, the check, the shared ragdoll). Registered in the runner SPECS and the manifests (Python edited by hand, not run).
- Suites: new `WildboundCandyGlaze_Test` (6 cases: numbers, skating keeps speed and turns slowly, the slip rule, the server's check and the fall push, the builder's puddles on the plaza off the stair and nests, client and server wiring with no egg drop or damage).
- Coordination: "writing WildboundServer / Layout / Builder" sent to the parent session first; the beast-revision session had released every shared beast file.
- Fingerprint rule: before writing, Studio equalled HEAD for WildboundServer 219947/2038955413, CandyLayout 8223/2050365548, CandyBuilder 24287/3853704070. Exact replacements. After: Studio == repo, Glaze 4047/273557321, GlazeClient 3512/3052321404, Glaze_Test 6451/1758198345, CandyLayout 8485/3097716067, CandyBuilder 25042/3383674104, WildboundServer 221570/3444187812.
- RED: "module not found: WildboundCandyGlaze". GREEN (a minimal loadstring loader that skips backup folders): Glaze 6/0, Tower 8/0, Frutillon 6/0, TrapCake 8/0, CandyLayout 14/0, MechanicsWiring 10/0 (NH-W13). A first loader picked `ServerStorage.WildboundAnimationRuntimeBackup_20261107.WildboundWorld` and showed a false W2 red; fixed in the loader, not in the game.
- Solo Play (PlayLock `DG4`, cleared after; Play stopped twice; memory saves):
  - The three puddles stood at (582, 23), (612, 33), (650, 3), radius 6, top 0.65.
  - Found in Play: with streaming the client read the Glaze folder before its parts arrived (no puddles, no skating); the client now re-reads on every child change. After the fix:
  - Walk 16 into puddle 2, then steer 90 degrees: skating on, the velocity turned slowly ((15, 1), (15, 1), (14, 2) over the first frames), no slip.
  - Walk 22 (set on the client for the check) into it, then steer 90 degrees: the slip fired, the server ragdolled the player (state Physics), walk speed and Running came back after; health 100.
  - The shared ragdoll at FALL_SECONDS: Physics at 0.02 s, GettingUp at 1.07 s, Running at 1.08 s.
  - No script errors from these scripts.
- Not checked: a real sprint (the check set the walk speed on the client), how the skate feels by hand, a carrier slipping (the egg stays by construction), two players, a phone.
