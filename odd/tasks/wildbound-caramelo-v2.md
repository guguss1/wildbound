# Caramelo v2: Don Glaseón mechanics, the cake tower and the economy (decisions 2026-11-15)

## Status

Design only. Nothing in this file is implemented yet. It records the user's decisions of 2026-11-15, made while the balance pass (`odd/tasks/wildbound-balance-pass.md`) was running. Implement one task at a time, after that pass.

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
- [ ] EC Steal hold by rarity, plus the economy options once the user picks them
- [ ] AR Remove the Arrullo minigame. It returns later, improved (user, 2026-11-15).
  - Épica (and Legendaria) eggs use a plain longer hold instead (1.3 s / 1.8 s per the EC scale).
  - Disable the minigame path and keep its module for later; do not delete it.
  - Re-pin the suites that expect it.
