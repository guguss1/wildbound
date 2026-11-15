# Wildbound economy simulation (live game 2026-11-15, proposed 2.0 balance)

Model, not measured balance; ASSUMED fields listed below.

Two models. The live game model reads what is wired today from the Luau (waves, Caramelo and forest nests, the treadmill, base incubation, the hub roulette, the collection limit, Nightbloom). The proposed 2.0 model below it reads the unwired WildboundBalance (T05b). Every profile field, the loss rates and the roulette prize values are ASSUMED. This is not measured play data.

Regenerate: `python -I -B tools/wildbound_economy_sim_v2.py --profile all --minutes 10,30,60 --seed 7 --runs 200 --source live --balance proposed --farm-mode both --md`

## Live game model (2026-11-15)

What the wired game does today, read from the live Luau (no WildboundBalance proposal in this section). Seed 7, 200 runs per cell; values are mean (p10-p90). Solo server and ASSUMED profiles; the ASSUMED values are listed at the end of this section.

- Waves: every 300 s each empty nest refills; no day/night cycle; the forest plays by Night rules.
- Caramelo: 11 nests, one egg each (Comun x5 Gomibu 10 Esencia, hatch 15 s; Rara x4 Tortidragon 16 Esencia, hatch 45 s; Epica x2 Flanfuria 24 Esencia, hatch 60 s), no sleeping parent. Guarded by a beast: C1 (Gomibu), R1 (Flanfuria), C3 (Tortidragon); inside Don Glaseon's territory: E1, E2.
- Forest: I1 Safe 4 Esencia, 2 parents, I2 Fog 10 Esencia, 2 parents, I3 FogFar 16 Esencia, 3 parents, I4 Territory 24 Esencia, 3 parents, I5 Heart 36 Esencia, 4 parents; 3 eggs per nest; woken parents chase at 19.
- Incubation: the own base auto-incubates up to 8 eggs at once; hatch Comun 15 s, Rara 45 s, Epica 60 s, Legendaria 75 s.
- Collection limit 100 (hatched + incubating + banked + carried): at the limit no steal is allowed. Farm: 4 slots, no income.
- Portal carry rule `refuse` (Portal.CARRY): an egg carrier may not use a return portal.

### Esencia per minute by profile and route

Esencia/min is the total; the next five columns split it. Times are session minutes (share of runs when under 100%). Collection is the creatures owned at the end (hatched + incubating + banked).

| Profile | Route | Min | Esencia/min | Eggs | Base | Treadmill | Roulette | Sale | Eggs banked/h | Eggs lost/h | Trip s | Portal trips % | First egg | First hatch | Max walk | Collection | Collection full |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | caramelo | 10 | 17.1 (13.6-19.4) | 10.8 | 3.2 | 2.0 | 1.1 | 0.0 | 47 | 7 | 58 | 0 | 1.5 | 1.8 | - | 8 | - |
| beginner | caramelo | 30 | 16.8 (15.0-18.4) | 12.4 | 3.4 | 0.7 | 0.4 | 0.0 | 51 | 7 | 59 | 0 | 1.5 | 1.8 | - | 25 | - |
| beginner | caramelo | 60 | 16.8 (15.6-18.0) | 12.8 | 3.4 | 0.3 | 0.2 | 0.0 | 52 | 7 | 60 | 0 | 1.5 | 1.8 | - | 52 | - |
| beginner | forest | 10 | 18.7 (11.8-25.2) | 13.3 | 2.3 | 2.0 | 1.1 | 0.0 | 44 | 27 | 57 | 0 | 2.0 | 2.3 | - | 7 | - |
| beginner | forest | 30 | 19.0 (14.8-22.6) | 15.4 | 2.6 | 0.7 | 0.4 | 0.0 | 50 | 27 | 58 | 0 | 2.0 | 2.3 | - | 25 | - |
| beginner | forest | 60 | 18.9 (16.5-21.6) | 15.8 | 2.6 | 0.3 | 0.2 | 0.0 | 51 | 28 | 59 | 0 | 2.0 | 2.3 | - | 51 | - |
| beginner | mixed | 10 | 17.1 (13.6-19.4) | 10.8 | 3.2 | 2.0 | 1.1 | 0.0 | 47 | 7 | 58 | 0 | 1.5 | 1.8 | - | 8 | - |
| beginner | mixed | 30 | 16.8 (15.0-18.4) | 12.4 | 3.4 | 0.7 | 0.4 | 0.0 | 51 | 7 | 59 | 0 | 1.5 | 1.8 | - | 25 | - |
| beginner | mixed | 60 | 16.8 (15.6-18.0) | 12.8 | 3.4 | 0.3 | 0.2 | 0.0 | 52 | 7 | 60 | 0 | 1.5 | 1.8 | - | 52 | - |
| intermediate | caramelo | 10 | 39.4 (32.5-44.3) | 27.9 | 1.9 | 8.5 | 1.1 | 0.0 | 114 | 17 | 47 | 0 | 3.0 | 3.3 | 2.3 | 19 | - |
| intermediate | caramelo | 30 | 33.4 (29.8-36.6) | 28.2 | 2.1 | 2.8 | 0.4 | 0.0 | 115 | 17 | 47 | 0 | 3.0 | 3.3 | 2.3 | 57 | - |
| intermediate | caramelo | 60 | 27.9 (27.4-28.4) | 24.5 | 1.8 | 1.4 | 0.2 | 0.0 | 100 | 14 | 47 | 0 | 3.0 | 3.3 | 2.3 | 100 | 51.7 |
| intermediate | forest | 10 | 69.2 (58.3-78.5) | 59.3 | 0.3 | 8.5 | 1.1 | 0.0 | 189 | 18 | 39 | 0 | 2.9 | 3.1 | 2.3 | 32 | - |
| intermediate | forest | 30 | 61.8 (56.8-66.4) | 58.2 | 0.4 | 2.8 | 0.4 | 0.0 | 193 | 17 | 40 | 0 | 2.9 | 3.1 | 2.3 | 96 | 28.6 (44%) |
| intermediate | forest | 60 | 32.0 (30.4-33.4) | 30.2 | 0.2 | 1.4 | 0.2 | 0.0 | 100 | 9 | 40 | 0 | 2.9 | 3.1 | 2.3 | 100 | 30.4 |
| intermediate | mixed | 10 | 56.3 (46.9-65.5) | 44.9 | 1.8 | 8.5 | 1.1 | 0.0 | 160 | 21 | 44 | 0 | 3.0 | 3.3 | 2.3 | 27 | - |
| intermediate | mixed | 30 | 66.4 (63.6-69.4) | 61.2 | 1.9 | 2.8 | 0.4 | 0.0 | 198 | 24 | 43 | 0 | 3.0 | 3.3 | 2.3 | 99 | 28.2 (82%) |
| intermediate | mixed | 60 | 33.5 (32.1-34.9) | 30.9 | 1.0 | 1.4 | 0.2 | 0.0 | 100 | 12 | 43 | 0 | 3.0 | 3.3 | 2.3 | 100 | 28.8 |
| advanced | caramelo | 10 | 55.4 (46.1-65.4) | 30.2 | 1.5 | 22.6 | 1.1 | 0.0 | 123 | 23 | 51 | 0 | 3.4 | 3.6 | 2.3 | 21 | - |
| advanced | caramelo | 30 | 53.3 (47.9-58.0) | 28.0 | 1.4 | 23.5 | 0.4 | 0.0 | 115 | 22 | 51 | 0 | 3.4 | 3.6 | 2.3 | 57 | - |
| advanced | caramelo | 60 | 50.9 (49.0-52.7) | 24.1 | 1.2 | 25.3 | 0.2 | 0.0 | 99 | 19 | 50 | 0 | 3.4 | 3.6 | 2.3 | 99 | 52.4 (92%) |
| advanced | forest | 10 | 89.2 (78.6-101.5) | 71.9 | 0.0 | 16.3 | 1.1 | 0.0 | 233 | 12 | 32 | 0 | 2.7 | 3.0 | 2.3 | 39 | - |
| advanced | forest | 30 | 80.5 (77.7-83.7) | 60.4 | 0.0 | 19.7 | 0.4 | 0.0 | 200 | 9 | 32 | 0 | 2.7 | 3.0 | 2.3 | 100 | 25.5 |
| advanced | forest | 60 | 59.0 (57.6-60.6) | 30.2 | 0.0 | 28.6 | 0.2 | 0.0 | 100 | 5 | 32 | 0 | 2.7 | 3.0 | 2.3 | 100 | 25.5 |
| advanced | mixed | 10 | 90.8 (75.7-104.0) | 79.2 | 1.4 | 9.1 | 1.1 | 0.0 | 276 | 33 | 39 | 0 | 3.3 | 3.6 | 2.3 | 46 | - |
| advanced | mixed | 30 | 75.1 (72.0-78.3) | 56.3 | 0.9 | 17.5 | 0.4 | 0.0 | 200 | 21 | 38 | 0 | 3.3 | 3.6 | 2.3 | 100 | 19.3 |
| advanced | mixed | 60 | 56.3 (54.7-57.9) | 28.2 | 0.5 | 27.5 | 0.2 | 0.0 | 100 | 11 | 38 | 0 | 3.3 | 3.6 | 2.3 | 100 | 19.3 |

- AFK on the treadmill: 37.5 Esencia/min (2250/h) with no trip and no risk (5 Esencia every 8 s lap, still paid after the last level).

### Treadmill progression

Laps grant the levels for free; the console sells the same levels (Training.cost).

| Level | Walk | Carry 1 egg | Carry 3+ eggs | Laps time s | Laps Esencia | Console price | Console total |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 0 | 16 | 11.0 | 9.0 | 0 | 0 | - | 0 |
| 1 | 18 | 12.4 | 10.1 | 8 | 5 | 30 | 30 |
| 2 | 20 | 13.8 | 11.2 | 16 | 10 | 36 | 66 |
| 3 | 22 | 15.1 | 12.4 | 24 | 15 | 43 | 109 |
| 4 | 24 | 16.5 | 13.5 | 32 | 20 | 52 | 161 |
| 5 | 26 | 17.9 | 14.6 | 40 | 25 | 62 | 223 |
| 6 | 28 | 19.2 | 15.8 | 48 | 30 | 75 | 298 |
| 7 | 30 | 20.6 | 16.9 | 56 | 35 | 90 | 388 |
| 8 | 32 | 22.0 | 18.0 | 64 | 40 | 107 | 495 |
| 9 | 34 | 23.4 | 19.1 | 72 | 45 | 129 | 624 |
| 10 | 36 | 24.8 | 20.2 | 80 | 50 | 155 | 779 |
| 11 | 38 | 26.1 | 21.4 | 88 | 55 | 186 | 965 |
| 12 | 40 | 27.5 | 22.5 | 96 | 60 | 223 | 1188 |
| 13 | 42 | 28.9 | 23.6 | 104 | 65 | 267 | 1455 |
| 14 | 44 | 30.2 | 24.8 | 112 | 70 | 321 | 1776 |
| 15 | 46 | 31.6 | 25.9 | 120 | 75 | 385 | 2161 |
| 16 | 48 | 33.0 | 27.0 | 128 | 80 | 462 | 2623 |
| 17 | 50 | 34.4 | 28.1 | 136 | 85 | 555 | 3178 |

### Nightbloom

Upper bound for one player who claims every forest gather node (solo server), the Night table always on, wilting after 300 s (it never binds while every node is claimed within its cycle).

| Zone | Active slots | Nightbloom share | Mean yield | Slot cycle s | Nightbloom/h |
| --- | --- | --- | --- | --- | --- |
| fog | 6 | 15% | 1.0 | 99 | 32.7 |
| territory | 6 | 35% | 1.5 | 106 | 107.0 |

- Now: 140 Nightbloom/h. With the old cycle (Night 42% of the time): 58/h.
- Every one-time Nightbloom sink (camp upgrades and skills) needs 25 Nightbloom in all: 11 min of gathering at the bound.
- Nightbloom pays no Esencia (Economy.itemEmber).

### Roulette (Roulette.LIVE)

- Spin cost 45, free first spin True, pity every 10 (Rara+; 1.0% of paid spins are pity spins).
- Esencia back per paid spin 12.01: net -32.99 Esencia per spin, a sink. Prize value per spin 21.3 with materials at their ASSUMED table values.
- Free spin Esencia EV 11.9.
- At the best 60 min income (advanced, forest: 3540/h) a player pays 79 spins an hour, losing 2595 Esencia/h; the AFK treadmill alone pays 50 spins an hour.

### One-time Esencia sinks

Camp upgrades 900, skills 560, one of each gear 45: 1505 Esencia (plus materials). The treadmill console ladder (3178) is never needed: laps give the same levels free.

| Profile | Route | Hours of 60 min income to pay every one-time sink |
| --- | --- | --- |
| beginner | caramelo | 1.50 |
| beginner | forest | 1.33 |
| beginner | mixed | 1.50 |
| intermediate | caramelo | 0.90 |
| intermediate | forest | 0.79 |
| intermediate | mixed | 0.75 |
| advanced | caramelo | 0.49 |
| advanced | forest | 0.43 |
| advanced | mixed | 0.45 |

- AFK treadmill: 0.67 h.

### Live profiles and ASSUMED values

| Profile | laps_at_start | idle_on_treadmill | max_eggs_per_trip | overhead_s | caramelo_loss | forest_loss | wild_eggs_per_forest_trip | sell_duplicates | nest_choice | uses_portal |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | 4 | False | 1 | 35.0 | 0.1 | 0.35 | 0.3 | False | nearest | False |
| intermediate | 17 | False | 3 | 18.0 | 0.06 | 0.22 | 0.6 | True | nearest | True |
| advanced | 17 | True | 6 | 8.0 | 0.03 | 0.12 | 1.0 | True | value | True |

- ASSUMED `solo_server`: one player per server: nobody else takes eggs, and every nest is full at session start
- ASSUMED `wave_offset`: the session starts at a uniform random point of the 300 s wave
- ASSUMED `base_to_hub_edge_studs`: 60.0
- ASSUMED `path_factor`: 1.2
- ASSUMED `arrullo_seconds`: 6.0
- ASSUMED `wild_egg_detour_seconds`: 6.0
- ASSUMED `portal_prompt_seconds`: 1.0
- ASSUMED `guarded_nests`: C1 Gomibu, R1 Flanfuria, C3 Tortidragon (decision 25)
- ASSUMED `guard_loss_slow / fast`: 0.25 / 0.05
- ASSUMED `boss_loss_per_epica_nest`: 0.05
- ASSUMED `outrun_factor`: 0.4
- ASSUMED `loss`: a loss drops every carried egg; the nest stays empty until the next wave; banked Esencia is never lost
- ASSUMED `first_steal_bonus`: not paid for eggs (State pays it only when an island cria is registered)
- ASSUMED `extract_base`: 4 Esencia when a trip lasts 45 s or more (minExpeditionSeconds); every trip passes 60 studs
- ASSUMED `forest_eggs`: Species.ONLY rewrites forest eggs to Lumipol (Comun, 15 s hatch); Esencia by the island's tier
- ASSUMED `wild_eggs`: wild/bough pickups per forest trip by profile; rarity by SpawnClock MAX weights, Esencia by REWARD
- ASSUMED `incubation`: eggs start as soon as one of the 8 base slots frees (the owner is assumed near the base)
- ASSUMED `roulette`: the free first spin only, drawn from Roulette.LIVE; paid spins are a separate sink table
- ASSUMED `harvest_travel_seconds`: {'fog': 20.0, 'territory': 25.0}
- ASSUMED `materials`: Nightbloom and roulette materials pay no Esencia; they are counted, not priced

## 2026-11-15 findings

From the live model above (a model with ASSUMED profiles, not measured play). Each finding names the number that makes it too easy or too slow and a concrete change to try; the what-if table under it reruns three profile/route pairs with one change at a time.

### Too easy

1. **The treadmill pays for standing still.** 5 Esencia per 8 s lap, with no cap after the last level, is 37.5 Esencia/min (2250/h) with no trip and no risk. It beats 6 of the 9 active 60 min profile/route cells, and the advanced player's best route pays only 59.0/min (forest). The economy's own `antiAfk.timeBasedGrants = 0` says no time-based grants. Suggest: pay the lap Esencia only on a level-up lap (at most 85 Esencia per account), or 1 Esencia per lap with a cap of 30 per day.
2. **Walk training is free and instant.** 17 laps of 8 s reach the top walk (50) in 136 s; the console's 3178 Esencia ladder (COST_GROWTH 1.2) is never worth buying. Suggest: a lap grants progress, not a level: level L+1 needs L+1 laps (153 laps, about 20 min to the top), or laps train only to level 4 (walk 24) and the console sells 5 to 17.
3. **A trained carrier outruns everything.** At level 17 one egg walks 34.4 and three or more 28.1, against woken parents at 19, the Caramelo guardians at Flanfuria 11, Gomibu 12, Tortidragon 16, La Silueta's lunge at 22 and the sprint cap of 24. Suggest: take the carrier's share of at most a 24 walk (one egg 16.5, three or more 13.5, under the 19 chase), so training still helps while carrying but a chase stays a chase.
4. **Caramelo nests have no parents.** 11 one-egg nests refill every 300 s and only 3 have a guardian; nobody wakes on a steal elsewhere. They pay the forest's tiers (Fog 10, FogFar 16, Territory 24). A beginner there loses 7 eggs/h against 28/h in the forest for about the same income (16.8 vs 18.9 Esencia/min). A wave holds 162 Esencia in Caramelo and 270 in the forest nests. Suggest: one tier down in Caramelo (Comun Safe 4, Rara Fog 10, Epica FogFar 16), or a guardian on at least 6 of the 11 nests.
5. **Nightbloom is no longer scarce.** One player claiming every forest node gets about 140/h now against 58/h under the old cycle; every one-time Nightbloom sink (25 in all) takes 11 min. Suggest: Night nightbloom weight fog 15 -> 6 and territory 35 -> 15 (back to about the old rate), or a wilt of 120 s instead of 300 s.
6. **Nothing to buy after the first hour.** Every one-time Esencia sink costs 1505 Esencia; the 60 min incomes pay it in 0.43 to 1.50 h, and the AFK treadmill in 0.67 h. After that the roulette is the only sink, returning 12.01 Esencia per 45 spin. Suggest: fix finding 1 first (it alone pays every sink in under an hour), then add a repeatable sink (farm slot 5 at 400, slot 6 at 900, the 2.0 proposal's ladder).
7. **Base incubation ignores the slot upgrades.** The own base incubates up to 8 eggs at once with 15 to 60 s hatches, so the first hatch lands 1.8 to 3.6 min into a session and `incubatorSlot2` / `incubatorSlot3` (90 and 220 Esencia plus materials) do nothing on the base path. Suggest: let autoIncubate use the bought slot count (1, 2, 3), or drop the two upgrades; keep the 15 s Comun hatch for the first-session hook.

### Too slow

8. **The collection limit is a dead end.** 100 creatures (hatched + incubating + banked) block every further steal, and nothing in State releases or sells a hatched creature (`sellDuplicateEggs` only sells banked eggs). In the 60 min sessions it is reached by intermediate caramelo at 52 min, intermediate forest at 30 min, intermediate mixed at 29 min, advanced caramelo at 52 min, advanced forest at 26 min, advanced mixed at 19 min. After that the only income is the treadmill. Suggest: let a player release a hatched duplicate for 4 Esencia (the Safe egg price), or count one entry per species, or raise the limit to 300.
9. **Fast trips lose the base bonus.** The 4 Esencia trip bonus needs 45 s; trained forest trips last about 40 s (intermediate), so a better player is paid less per trip. Suggest: minExpeditionSeconds 45 -> 25.

### As intended

- First egg 1.5 min and first hatch 1.8 min for a beginner in Caramelo: the quick first action holds (a hypothesis to test in Play).
- The roulette is a sink, not a money loop: net -32.99 Esencia per paid spin.
- The return portals refuse an egg carrier (Portal.CARRY `refuse`); the model has every carrier walk home, so no trip uses a portal.

### What-if (one change at a time)

60 min sessions, 3 pairs, the same seeds in every case.

| Change | Profile | Route | Esencia/min | Treadmill/min | Eggs banked/h | Eggs lost/h | Collection full |
| --- | --- | --- | --- | --- | --- | --- | --- |
| as built | intermediate | forest | 31.8 | 1.4 | 100 | 10 | 30.6 |
| as built | advanced | mixed | 56.3 | 27.5 | 100 | 11 | 19.3 |
| as built | beginner | caramelo | 16.6 | 0.3 | 51 | 8 | - |
| lap Esencia only on a level-up lap | intermediate | forest | 31.8 | 1.4 | 100 | 10 | 30.6 |
| lap Esencia only on a level-up lap | advanced | mixed | 30.3 | 1.4 | 100 | 11 | 19.3 |
| lap Esencia only on a level-up lap | beginner | caramelo | 16.6 | 0.3 | 51 | 8 | - |
| carrier share of at most a 24 walk | intermediate | forest | 32.7 | 1.4 | 100 | 30 | 37.1 |
| carrier share of at most a 24 walk | advanced | mixed | 53.5 | 21.6 | 100 | 23 | 27.6 |
| carrier share of at most a 24 walk | beginner | caramelo | 16.6 | 0.3 | 51 | 8 | - |
| collection limit 300 | intermediate | forest | 60.2 | 1.4 | 195 | 19 | - |
| collection limit 300 | advanced | mixed | 92.9 | 7.7 | 300 | 31 | 54.7 (99%) |
| collection limit 300 | beginner | caramelo | 16.6 | 0.3 | 51 | 8 | - |

## Proposed 2.0 balance model (T05b, WildboundBalance unwired)

This model is unchanged from T05b: it plays the proposed farm income, sell prices, treadmill ladder (16-21) and incubation timers, none of which the live game uses.

Seed 7, 200 runs per cell (seeds seed..seed+runs-1), source `live`, incubation balance `proposed`, farm modes `fresh, carry`. Values are mean (p10-p90).

Farm modes (both ASSUMED): `fresh` = every session is a fresh account (empty farm, the 10 s first egg, the first-steal bonus and the free spin; the farm is worth nothing after the session ends). `carry` = a returning account: the farm starts with the profile's `carry_farm`, the first-time bonuses are spent, and a farmed creature is valued for 60 min past the session end. Upgrade levels start at 0 in both.

## Esencia and eggs per hour

Esencia/h net is all income minus the Esencia paid for roulette spins (0 with `--roulette-policy free`). Hatches per session is a count per session, not per hour. First egg and first hatch are session minutes; the first and second egg timers count hatches already finished (Balance `previousHatches`).

| Profile | Farm mode | Min | Esencia/h net | Expedition | Farm | Sale | Roulette | Spin spend/h | Passive % | Sale % | Eggs stolen/h | Eggs banked/h | Hatches per session | First egg | First hatch |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 517 (144-879) | 342 | 42 | 0 | 133 | 0 | 7 | 0 | 9.8 | 6.4 | 1.0 | 5.2 min (76%) | 5.3 min (74%) |
| beginner | fresh | 30 | 613 (399-883) | 393 | 176 | 0 | 44 | 0 | 27 | 0 | 11.7 | 7.9 | 3.9 | 7.6 min (98%) | 7.8 min (98%) |
| beginner | fresh | 60 | 756 (534-1041) | 402 | 332 | 0 | 22 | 0 | 42 | 0 | 12.1 | 8.1 | 8.0 | 8.1 min | 8.2 min |
| beginner | carry | 10 | 698 (500-908) | 323 | 375 | 0 | 0 | 0 | 56 | 0 | 9.3 | 6.5 | 1.0 | 5.2 min (80%) | 6.0 min (78%) |
| beginner | carry | 30 | 819 (655-1003) | 379 | 440 | 0 | 0 | 0 | 54 | 0 | 11.3 | 7.7 | 3.7 | 6.9 min | 7.9 min |
| beginner | carry | 60 | 954 (752-1210) | 409 | 545 | 0 | 0 | 0 | 56 | 0 | 12.3 | 8.6 | 8.5 | 7.1 min | 8.0 min |
| intermediate | fresh | 10 | 1462 (822-2102) | 1100 | 227 | 2 | 133 | 0 | 14 | 0 | 35.1 | 26.1 | 3.5 | 3.3 min (99%) | 3.5 min (99%) |
| intermediate | fresh | 30 | 2179 (1383-3032) | 1197 | 686 | 252 | 44 | 0 | 31 | 10 | 39.2 | 28.8 | 13.3 | 3.4 min | 3.6 min |
| intermediate | fresh | 60 | 3044 (2168-3995) | 1241 | 1142 | 638 | 22 | 0 | 37 | 20 | 41.3 | 30.1 | 29.5 | 3.4 min | 3.6 min |
| intermediate | carry | 10 | 2247 (1536-3019) | 1103 | 917 | 227 | 0 | 0 | 43 | 8 | 36.3 | 26.6 | 3.4 | 3.0 min | 4.2 min |
| intermediate | carry | 30 | 2999 (2181-3858) | 1204 | 1184 | 611 | 0 | 0 | 40 | 19 | 39.8 | 29.3 | 13.6 | 3.1 min | 4.3 min |
| intermediate | carry | 60 | 3674 (2834-4570) | 1252 | 1539 | 884 | 0 | 0 | 42 | 24 | 41.5 | 30.4 | 29.8 | 3.1 min | 4.3 min |
| advanced | fresh | 10 | 4700 (2401-7876) | 2694 | 410 | 1463 | 133 | 0 | 10 | 21 | 80.3 | 62.2 | 6.4 | 2.6 min | 2.7 min |
| advanced | fresh | 30 | 9166 (6226-12053) | 2805 | 1330 | 4986 | 44 | 0 | 15 | 52 | 84.7 | 65.6 | 30.0 | 2.6 min | 2.7 min |
| advanced | fresh | 60 | 11754 (9547-14243) | 2893 | 2320 | 6519 | 22 | 0 | 20 | 55 | 86.7 | 67.8 | 65.8 | 2.6 min | 2.7 min |
| advanced | carry | 10 | 6051 (4669-7273) | 2670 | 2056 | 1324 | 0 | 0 | 35 | 21 | 80.8 | 63.2 | 6.3 | 2.5 min | 4.0 min |
| advanced | carry | 30 | 9848 (7678-11667) | 2835 | 2964 | 4049 | 0 | 0 | 31 | 40 | 84.6 | 66.6 | 30.7 | 2.5 min | 4.0 min |
| advanced | carry | 60 | 12171 (10019-14333) | 2914 | 3779 | 5478 | 0 | 0 | 31 | 45 | 86.7 | 68.5 | 66.4 | 2.5 min | 4.0 min |

## Time to each upgrade

Minutes from session start, mean over the runs that bought it during play (share of runs when under 100%). Purchases at the final session-end shop are excluded.

| Profile | Farm mode | Min | treadmill_1 | treadmill_2 | treadmill_3 | treadmill_4 | treadmill_5 | incubator_1 | incubator_2 | incubator_3 | cradle_2 | farm_slot_5 | farm_slot_6 | farm_slot_7 | farm_slot_8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 3.0 min (88%) | 6.8 min (30%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | fresh | 30 | 4.2 min | 13.8 min (98%) | 27.4 min (3%) | not reached | not reached | 22.3 min (76%) | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | fresh | 60 | 4.3 min | 14.3 min | 41.1 min (97%) | not reached | not reached | 25.0 min | 58.7 min (2%) | not reached | 55.2 min (24%) | 50.5 min (66%) | not reached | TBD | TBD |
| beginner | carry | 10 | 5.8 min (79%) | 8.7 min (2%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | carry | 30 | 6.9 min | 11.7 min | 26.0 min (12%) | not reached | not reached | 20.3 min | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | carry | 60 | 6.9 min | 11.7 min | 33.8 min | not reached | not reached | 20.3 min | 54.8 min (8%) | not reached | 54.1 min (54%) | 46.5 min | not reached | TBD | TBD |
| intermediate | fresh | 10 | 2.0 min | 5.0 min (96%) | 9.1 min (17%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | fresh | 30 | 2.1 min | 5.4 min | 13.7 min | 24.2 min (77%) | 27.7 min (1%) | 27.0 min (0%) | 29.0 min (0%) | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | fresh | 60 | 2.1 min | 5.4 min | 13.8 min | 26.5 min | 42.6 min (99%) | 43.7 min (96%) | 47.5 min (88%) | 52.5 min (50%) | 53.7 min (40%) | 54.6 min (32%) | 54.5 min (10%) | TBD | TBD |
| intermediate | carry | 10 | 3.0 min | 6.3 min | 8.8 min (59%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | carry | 30 | 3.0 min | 6.3 min | 10.6 min | 19.9 min | 27.1 min (16%) | 27.9 min (10%) | 28.0 min (2%) | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | carry | 60 | 3.0 min | 6.3 min | 10.6 min | 20.0 min | 35.4 min | 37.0 min | 41.5 min | 49.1 min (86%) | 51.3 min (76%) | 52.3 min (67%) | 54.3 min (32%) | TBD | TBD |
| advanced | fresh | 10 | 2.7 min | 4.6 min (92%) | 6.2 min (26%) | 8.0 min (2%) | 9.6 min (0%) | 7.5 min (47%) | 7.5 min (18%) | 9.2 min (0%) | 6.6 min (91%) | 8.9 min (54%) | 9.5 min (2%) | TBD | TBD |
| advanced | fresh | 30 | 2.7 min | 5.4 min | 12.5 min | 19.2 min (98%) | 24.7 min (75%) | 10.6 min | 16.1 min (98%) | 23.6 min (86%) | 7.2 min | 10.4 min | 16.2 min | TBD | TBD |
| advanced | fresh | 60 | 2.7 min | 5.6 min | 14.9 min | 22.2 min | 29.2 min | 11.9 min | 20.5 min | 26.6 min | 7.7 min | 10.5 min | 17.8 min | TBD | TBD |
| advanced | carry | 10 | 2.5 min | 4.5 min (96%) | 9.5 min (47%) | not reached | not reached | 8.1 min (83%) | not reached | not reached | 5.8 min (98%) | 6.8 min (98%) | not reached | TBD | TBD |
| advanced | carry | 30 | 2.5 min | 4.8 min | 11.6 min | 18.2 min | 25.0 min (92%) | 8.7 min | 16.3 min | 23.0 min (96%) | 5.9 min | 6.9 min | 13.1 min | TBD | TBD |
| advanced | carry | 60 | 2.5 min | 4.8 min | 11.6 min | 18.2 min | 25.5 min | 8.7 min | 16.3 min | 23.4 min | 5.9 min | 6.9 min | 13.1 min | TBD | TBD |

## Indicators

- Stall (slow progress, the spec's rule): more than 300 s with no affordable upgrade while earning under the cheapest remaining cost per 10 min. A stalled player still earns.
- Hard lockout (a dead end), checked at session end: stalled more than 300 s and either the session's mean income is under 1 Esencia/h (ASSUMED floor) or the Esencia on hand plus one more whole session at that mean income cannot pay the cheapest remaining upgrade.
- Ladder flags (each run at its own owned level and Esencia/h): growth above 2.5 per level, next step above 3 sessions of income, or the top level above 20 sessions of income (all three thresholds ASSUMED). Training is not simulated, so it is read at level 0.

| Profile | Farm mode | Min | Stall runs % | Hard lockout runs % | Longest stall s | Treadmill level | Treadmill hours for next | Treadmill sessions to top | Ladder flags (runs %) | Idle farm Esencia/h | Idle / expedition | Legendary sell attractive | Sell mandatory | Viable at end |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 21 | 2 | 259 | 1.2 | 0.22 | 27.1 | treadmill_proposed 51%, incubator_proposed 100%, farm_slots_proposed 36%, training_live 91% | 110 | 0.32 | True | False | none |
| beginner | fresh | 30 | 88 | 0 | 547 | 2.1 | 0.40 | 5.9 | treadmill_proposed 0%, incubator_proposed 100%, farm_slots_proposed 0%, training_live 4% | 377 | 0.96 | True | False | none |
| beginner | fresh | 60 | 99 | 0 | 782 | 3.0 | 0.63 | 1.9 | incubator_proposed 100% | 616 | 1.53 | False | False | none |
| beginner | carry | 10 | 17 | 0 | 274 | 1.6 | 0.21 | 14.5 | treadmill_proposed 10%, incubator_proposed 100%, farm_slots_proposed 4%, training_live 94% | 411 | 1.27 | True | False | none |
| beginner | carry | 30 | 74 | 0 | 437 | 2.5 | 0.38 | 3.7 | incubator_proposed 100% | 533 | 1.41 | True | False | none |
| beginner | carry | 60 | 98 | 0 | 635 | 3.0 | 0.49 | 1.5 | incubator_proposed 100% | 776 | 1.90 | False | False | none |
| intermediate | fresh | 10 | 4 | 0 | 84 | 2.2 | 0.17 | 7.3 | treadmill_proposed 2%, incubator_proposed 100%, farm_slots_proposed 2%, training_live 16% | 496 | 0.45 | True | False | incubator_1 49% |
| intermediate | fresh | 30 | 4 | 0 | 98 | 3.9 | 0.40 | 1.0 | incubator_proposed 100% | 1234 | 1.03 | True | False | cradle_2 68%, farm_slot_5 74%, incubator_1 89% |
| intermediate | fresh | 60 | 4 | 0 | 155 | 5.0 | 0.62 | 0.0 | incubator_proposed 100% | 1955 | 1.57 | False | False | cradle_2 24%, farm_slot_5 32%, incubator_1 0% |
| intermediate | carry | 10 | 1 | 0 | 51 | 2.7 | 0.17 | 4.1 | incubator_proposed 100%, training_live 0% | 1079 | 0.98 | True | False | cradle_2 2%, farm_slot_5 9%, incubator_1 60% |
| intermediate | carry | 30 | 1 | 0 | 67 | 4.3 | 0.34 | 0.5 | incubator_proposed 100% | 1544 | 1.28 | True | False | cradle_2 71%, farm_slot_5 74%, incubator_1 71% |
| intermediate | carry | 60 | 1 | 0 | 168 | 5.0 | - | 0.0 | incubator_proposed 100% | 2297 | 1.84 | False | False | cradle_2 10%, farm_slot_5 12% |
| advanced | fresh | 10 | 0 | 0 | 29 | 2.2 | 0.06 | 2.5 | incubator_proposed 100% | 919 | 0.34 | True | False | farm_slot_5 4%, incubator_1 16%, incubator_2 2%, treadmill_2 4%, treadmill_3 1% |
| advanced | fresh | 30 | 0 | 0 | 112 | 4.8 | 0.15 | 0.1 | incubator_proposed 100% | 2321 | 0.83 | True | False | incubator_2 1%, incubator_3 2% |
| advanced | fresh | 60 | 0 | 0 | 87 | 5.0 | - | 0.0 | incubator_proposed 100% | 2959 | 1.02 | False | False | none |
| advanced | carry | 10 | 0 | 0 | 34 | 2.7 | 0.06 | 1.5 | incubator_proposed 100% | 2455 | 0.92 | True | False | incubator_1 6%, incubator_2 22%, treadmill_3 14%, treadmill_4 3% |
| advanced | carry | 30 | 0 | 0 | 79 | 4.9 | 0.13 | 0.0 | incubator_proposed 100% | 4025 | 1.42 | True | False | none |
| advanced | carry | 60 | 0 | 0 | 80 | 5.0 | - | 0.0 | incubator_proposed 100% | 5006 | 1.72 | False | False | none |

## Cost ladders

| Ladder | Paid costs | Ratios | Mean growth | Growth flag |
| --- | --- | --- | --- | --- |
| treadmill_proposed | 30/80/200/450/900 | 2.667/2.5/2.25/2.0 | 2.34 | False |
| incubator_proposed | 100/300/750 | 3.0/2.5 | 2.74 | True |
| farm_slots_proposed | 200/500 | 2.5 | 2.50 | False |
| training_live | 30/36/43/52/62/75/90/107/129/155/186/223/267/321/385/462/555 | 1.2/1.194/1.209/1.192/1.21/1.2/1.189/1.206/1.202/1.2/1.199/1.197/1.202/1.199/1.2/1.201 | 1.20 | False |

## Stalls and lockouts, stated plainly

- beginner, fresh, 10 min: stalled in 21% of runs (longest stall 259 s on average); hard lockout in 2% of runs.
- beginner, fresh, 30 min: stalled in 88% of runs (longest stall 547 s on average); hard lockout in 0% of runs.
- beginner, fresh, 60 min: stalled in 99% of runs (longest stall 782 s on average); hard lockout in 0% of runs.
- beginner, carry, 10 min: stalled in 17% of runs (longest stall 274 s on average); hard lockout in 0% of runs.
- beginner, carry, 30 min: stalled in 74% of runs (longest stall 437 s on average); hard lockout in 0% of runs.
- beginner, carry, 60 min: stalled in 98% of runs (longest stall 635 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 10 min: stalled in 4% of runs (longest stall 84 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 30 min: stalled in 4% of runs (longest stall 98 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 60 min: stalled in 4% of runs (longest stall 155 s on average); hard lockout in 0% of runs.
- intermediate, carry, 10 min: stalled in 1% of runs (longest stall 51 s on average); hard lockout in 0% of runs.
- intermediate, carry, 30 min: stalled in 1% of runs (longest stall 67 s on average); hard lockout in 0% of runs.
- intermediate, carry, 60 min: stalled in 1% of runs (longest stall 168 s on average); hard lockout in 0% of runs.

## Sell vs farm by farm mode

Share of gross income (mean over runs), and the share of runs that sold at least one Legendaria.

| Profile | Min | Sale % fresh | Farm % fresh | Legendaria sold runs % fresh | Sale % carry | Farm % carry | Legendaria sold runs % carry |
| --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | 10 | 0 | 7 | 0 | 0 | 56 | 0 |
| beginner | 30 | 0 | 27 | 0 | 0 | 54 | 0 |
| beginner | 60 | 0 | 42 | 0 | 0 | 56 | 0 |
| intermediate | 10 | 0 | 14 | 0 | 8 | 43 | 0 |
| intermediate | 30 | 10 | 31 | 0 | 19 | 40 | 0 |
| intermediate | 60 | 20 | 37 | 0 | 24 | 42 | 0 |
| advanced | 10 | 21 | 10 | 26 | 21 | 35 | 0 |
| advanced | 30 | 52 | 15 | 91 | 40 | 31 | 2 |
| advanced | 60 | 55 | 20 | 100 | 45 | 31 | 43 |

## Creature ROI (farm vs sell)

| Rarity | Farm Esencia/min | Sell price | Break-even min | Farm/sell over 10 / 30 / 60 min |
| --- | --- | --- | --- | --- |
| Comun | 1 | 15 | 15.0 | 0.67 / 2.00 / 4.00 |
| Rara | 3 | 60 | 20.0 | 0.50 / 1.50 / 3.00 |
| Epica | 7 | 200 | 28.6 | 0.35 / 1.05 / 2.10 |
| Legendaria | 15 | 650 | 43.3 | 0.23 / 0.69 / 1.38 |

## Roulette (category model)

PLACEHOLDER - exact prizes are T09a. Values per category: esencia 60, materials 10, gloves 20, incubationBoosters 15, consumables 30, specialEgg 150.

- Esencia category share (from Balance roulette.weights): 35.0%.
- EV per spin: 34.1 Esencia-equivalent against a spin cost of 45.
- Break-even Esencia prize value (other categories as above): 91.1.
- Break-even with every other category at 0: 128.6.
- infinite_money_risk: False.
- Only Esencia (or a prize sold back for Esencia) can pay the next spin: counting the esencia category alone, EV is 21.0 per spin.
- No pity and no hub vs base distinction: both are T09a.

## Farm slots

slot 5: 200, slot 6: 500, slot 7: TBD, slot 8: TBD.

## Mirrored values and drift

Each value is re-read from its source by pattern (no line numbers are tracked).

- `egg_carry_speeds` = {0: 16, 1: 11, 2: 10, 3: 9} (src/wildbound/WildboundLumipolWild.luau)
- `island_tier_distances` = {'Legendaria': 45, 'Epica': 80, 'Rara': 120} (src/wildbound/WildboundSpawnClock.luau)
- `beast_tick_seconds` = 20 (src/wildbound/WildboundBeastConfig.luau)
- `beast_per_roll_cap_10s` = 0.2 (src/wildbound/WildboundBeastConfig.luau)
- `beast_global_cooldown` = 15 (src/wildbound/WildboundBeastConfig.luau)
- `eggs_per_nest` = 3 (src/wildbound/WildboundIsland.luau)
- `egg_share` = 0.4 (src/wildbound/WildboundSpawnClock.luau)
- `treadmill_lap_seconds` = 8 (src/wildbound/WildboundTreadmillService.luau)
- `treadmill_lap_esencia` = 5 (src/wildbound/WildboundServer.server.luau)
- `base_incubator_slots` = 8 (src/wildbound/WildboundServer.server.luau)
- `nightbloom_wilt_seconds` = 300 (src/wildbound/WildboundGatherField.luau)
- `candy_nest_eggs` = 1 (src/wildbound/WildboundCandyNests.luau)
- `farm_slots` = 4 (src/wildbound/WildboundState.luau)
- `parent_chase_speed` = 19 (src/wildbound/WildboundIsland.luau)
- `portal_carry` = refuse (src/wildbound/WildboundPortal.luau)
- `egg_max_carry` = 12 (src/wildbound/WildboundEggCarry.luau)
- `wave_seconds` = 300 (src/wildbound/WildboundWaveClock.luau)
- Drift: none

## ASSUMED fields

- `trip_seconds` (beginner): 150
- `steal_success` (beginner): 0.55
- `eggs_per_trip_target` (beginner): 1
- `beast_loss_per_trip` (beginner): 0.25
- `pvp_loss_per_trip` (beginner): 0.05
- `bat_drop_per_trip` (beginner): 0.05
- `rarity_mix` (beginner): (0.75, 0.2, 0.05, 0.0)
- `sell_policy` (beginner): never
- `upgrade_policy` (beginner): cheapest_first
- `collect_interval_s` (beginner): 600
- `creature_items_per_trip` (beginner): 1
- `sell_roi_threshold` (beginner): 1.0
- `carry_farm` (beginner): ('Rara', 'Comun', 'Comun', 'Comun')
- `trip_seconds` (intermediate): 110
- `steal_success` (intermediate): 0.75
- `eggs_per_trip_target` (intermediate): 2
- `beast_loss_per_trip` (intermediate): 0.15
- `pvp_loss_per_trip` (intermediate): 0.1
- `bat_drop_per_trip` (intermediate): 0.04
- `rarity_mix` (intermediate): (0.55, 0.3, 0.12, 0.03)
- `sell_policy` (intermediate): sell_rara_plus_when_farm_full
- `upgrade_policy` (intermediate): treadmill_then_incubator
- `collect_interval_s` (intermediate): 420
- `creature_items_per_trip` (intermediate): 2
- `sell_roi_threshold` (intermediate): 1.0
- `carry_farm` (intermediate): ('Epica', 'Rara', 'Rara', 'Comun')
- `trip_seconds` (advanced): 85
- `steal_success` (advanced): 0.9
- `eggs_per_trip_target` (advanced): 3
- `beast_loss_per_trip` (advanced): 0.08
- `pvp_loss_per_trip` (advanced): 0.12
- `bat_drop_per_trip` (advanced): 0.03
- `rarity_mix` (advanced): (0.35, 0.35, 0.22, 0.08)
- `sell_policy` (advanced): sell_legendary_if_roi<X
- `upgrade_policy` (advanced): roi_greedy
- `collect_interval_s` (advanced): 300
- `creature_items_per_trip` (advanced): 3
- `sell_roi_threshold` (advanced): 1.0
- `carry_farm` (advanced): ('Legendaria', 'Epica', 'Epica', 'Rara')
- `carry_leg_share`: 0.5
- `egg_price_mapping`: SpawnClock.REWARD applied to eggEmberByTier
- `loss_roll`: once per trip, combined beast+pvp+bat
- `session_end_collect`: True
- `roulette_category_values`: {'esencia': 60, 'materials': 10, 'gloves': 20, 'incubationBoosters': 15, 'consumables': 30, 'specialEgg': 150}
- `roulette_policy`: free
- `ladder_threshold_session_multiple`: 3
- `ladder_growth_threshold`: 2.5
- `ladder_top_sessions`: 20
- `hard_lockout_income_floor_per_hour`: 1.0
- `farm_mode`: fresh, carry (fresh: every session is a fresh account (empty farm, first-time bonuses, farm worthless after the session); carry: pre-filled carry_farm, bonuses spent, farm valued 60 min past the session; upgrade levels start at 0 in both)
- `carry_future_minutes`: 60
- `carry_previous_hatches`: 2

## Simplifications

- Losses are rolled once per trip at a combined beast + PvP + bat rate, not from the Beast Director's 20 s ticks.
- PvP and bat drop rates are invented; nothing in the code defines them.
- The egg price uses the live eggEmberByTier through the SpawnClock REWARD map (ASSUMED).
- `fresh` farm mode treats every session as a fresh account, which biases toward selling: the farm is worth nothing after the session. `carry` is the steady-state counterpart; neither carries upgrade levels.
- WildboundBalance is `wired=false`: these results describe the proposed 2.0 economy, not the live game.
- The proposed treadmill walk 17-21 is not the live one (16 to 50 by laps, PF2); the live model above uses the live speeds.
- This proposed model has no waves, material gathering, consumables or portals; the live model above has waves, portals and Nightbloom.
