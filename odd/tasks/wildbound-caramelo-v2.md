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

- [ ] DG1 Lash combo, faster
- [ ] DG2 Vacuum mouth
- [ ] DG3 Chocolate wall
- [ ] DG4 Slippery glaze with a slip-and-fall ragdoll
- [ ] DG5 Rising anger (time + dodges)
- [ ] DG6 Roar summons new guardians
- [ ] DG7 Trap cake with lures on the routes
- [ ] CF Faster casts for Gomibú, Flanfuria and Tortidragón:
  - tells down to the 0.8 s floor, shorter recovery;
  - cooldowns about 3.5 / 5 / 4.5 s.
- [ ] CT1 Spiral staircase on the Gran Torta
- [ ] CT2 Counter-rotating tiers
- [ ] CT3 Best egg at the top
- [ ] CT4 Frutillón, the top guardian
- [ ] IC Icons through rbxthumb
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
