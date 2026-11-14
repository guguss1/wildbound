# Wildbound 2.0 economy simulation (T05b)

Model, not measured balance; ASSUMED fields listed below.

Inputs are read from the repo (live WildboundEconomyConfig, proposed unwired WildboundBalance); every profile field, the PvP and bat rates and the roulette prize values are ASSUMED. This is not measured play data.

Regenerate: `python -I -B tools/wildbound_economy_sim_v2.py --profile all --minutes 10,30,60 --seed 7 --runs 200 --source live --balance proposed --farm-mode both --md`

Seed 7, 200 runs per cell (seeds seed..seed+runs-1), source `live`, incubation balance `proposed`, farm modes `fresh, carry`. Values are mean (p10-p90).

Farm modes (both ASSUMED): `fresh` = every session is a fresh account (empty farm, the 10 s first egg, the first-steal bonus and the free spin; the farm is worth nothing after the session ends). `carry` = a returning account: the farm starts with the profile's `carry_farm`, the first-time bonuses are spent, and a farmed creature is valued for 60 min past the session end. Upgrade levels start at 0 in both.

## Esencia and eggs per hour

Esencia/h net is all income minus the Esencia paid for roulette spins (0 with `--roulette-policy free`). Hatches per session is a count per session, not per hour. First egg and first hatch are session minutes; the first and second egg timers count hatches already finished (Balance `previousHatches`).

| Profile | Farm mode | Min | Esencia/h net | Expedition | Farm | Sale | Roulette | Spin spend/h | Passive % | Sale % | Eggs stolen/h | Eggs banked/h | Hatches per session | First egg | First hatch |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 517 (144-879) | 342 | 42 | 0 | 133 | 0 | 7 | 0 | 9.8 | 6.4 | 1.0 | 5.2 min (76%) | 5.3 min (74%) |
| beginner | fresh | 30 | 613 (399-883) | 393 | 176 | 0 | 44 | 0 | 27 | 0 | 11.7 | 7.9 | 3.9 | 7.6 min (98%) | 7.8 min (98%) |
| beginner | fresh | 60 | 756 (534-1041) | 401 | 332 | 0 | 22 | 0 | 42 | 0 | 12.1 | 8.1 | 8.0 | 8.1 min | 8.2 min |
| beginner | carry | 10 | 698 (500-908) | 323 | 375 | 0 | 0 | 0 | 56 | 0 | 9.3 | 6.5 | 1.0 | 5.2 min (80%) | 6.0 min (78%) |
| beginner | carry | 30 | 819 (655-1003) | 379 | 440 | 0 | 0 | 0 | 54 | 0 | 11.3 | 7.7 | 3.7 | 6.9 min | 7.9 min |
| beginner | carry | 60 | 954 (752-1210) | 409 | 545 | 0 | 0 | 0 | 56 | 0 | 12.3 | 8.6 | 8.5 | 7.1 min | 8.0 min |
| intermediate | fresh | 10 | 1461 (821-2102) | 1100 | 226 | 2 | 133 | 0 | 14 | 0 | 35.1 | 26.1 | 3.5 | 3.3 min (99%) | 3.5 min (99%) |
| intermediate | fresh | 30 | 2173 (1358-3028) | 1193 | 684 | 251 | 44 | 0 | 31 | 10 | 39.1 | 28.7 | 13.3 | 3.4 min | 3.6 min |
| intermediate | fresh | 60 | 3034 (2157-3992) | 1238 | 1140 | 634 | 22 | 0 | 37 | 20 | 41.2 | 30.0 | 29.4 | 3.4 min | 3.6 min |
| intermediate | carry | 10 | 2245 (1536-3018) | 1103 | 917 | 225 | 0 | 0 | 43 | 8 | 36.3 | 26.6 | 3.4 | 3.0 min | 4.2 min |
| intermediate | carry | 30 | 2993 (2180-3855) | 1200 | 1183 | 610 | 0 | 0 | 40 | 19 | 39.7 | 29.2 | 13.5 | 3.1 min | 4.3 min |
| intermediate | carry | 60 | 3666 (2832-4561) | 1248 | 1536 | 882 | 0 | 0 | 42 | 24 | 41.4 | 30.3 | 29.7 | 3.1 min | 4.3 min |
| advanced | fresh | 10 | 4679 (2256-7872) | 2677 | 407 | 1462 | 133 | 0 | 10 | 21 | 79.9 | 61.8 | 6.4 | 2.6 min | 2.8 min |
| advanced | fresh | 30 | 9071 (6069-11803) | 2751 | 1325 | 4950 | 44 | 0 | 15 | 52 | 83.0 | 64.4 | 29.8 | 2.6 min | 2.8 min |
| advanced | fresh | 60 | 11654 (9432-14094) | 2872 | 2317 | 6443 | 22 | 0 | 20 | 55 | 86.2 | 67.3 | 65.0 | 2.6 min | 2.8 min |
| advanced | carry | 10 | 6008 (4664-7251) | 2660 | 2056 | 1292 | 0 | 0 | 35 | 21 | 80.6 | 63.0 | 6.2 | 2.5 min | 4.1 min |
| advanced | carry | 30 | 9709 (7610-11467) | 2756 | 2959 | 3993 | 0 | 0 | 31 | 40 | 82.5 | 64.7 | 30.4 | 2.5 min | 4.1 min |
| advanced | carry | 60 | 12051 (9980-14266) | 2884 | 3770 | 5397 | 0 | 0 | 32 | 44 | 85.9 | 67.8 | 65.7 | 2.5 min | 4.1 min |

## Time to each upgrade

Minutes from session start, mean over the runs that bought it during play (share of runs when under 100%). Purchases at the final session-end shop are excluded.

| Profile | Farm mode | Min | treadmill_1 | treadmill_2 | treadmill_3 | treadmill_4 | treadmill_5 | incubator_1 | incubator_2 | incubator_3 | cradle_2 | farm_slot_5 | farm_slot_6 | farm_slot_7 | farm_slot_8 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 3.0 min (88%) | 6.9 min (30%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | fresh | 30 | 4.2 min | 13.8 min (98%) | 27.4 min (3%) | not reached | not reached | 22.3 min (76%) | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | fresh | 60 | 4.3 min | 14.3 min | 41.1 min (97%) | not reached | not reached | 25.0 min | 58.7 min (2%) | not reached | 55.2 min (24%) | 50.5 min (66%) | not reached | TBD | TBD |
| beginner | carry | 10 | 5.8 min (79%) | 8.7 min (2%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | carry | 30 | 6.9 min | 11.7 min | 26.0 min (12%) | not reached | not reached | 20.3 min | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| beginner | carry | 60 | 6.9 min | 11.7 min | 33.8 min | not reached | not reached | 20.3 min | 54.8 min (8%) | not reached | 54.2 min (54%) | 46.5 min | not reached | TBD | TBD |
| intermediate | fresh | 10 | 2.0 min | 5.0 min (95%) | 9.2 min (15%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | fresh | 30 | 2.1 min | 5.4 min | 13.8 min | 24.3 min (78%) | 27.8 min (1%) | 27.1 min (0%) | 29.1 min (0%) | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | fresh | 60 | 2.1 min | 5.4 min | 13.9 min | 26.5 min | 42.7 min (98%) | 43.9 min (97%) | 47.8 min (90%) | 52.7 min (50%) | 53.9 min (40%) | 54.6 min (32%) | 54.9 min (10%) | TBD | TBD |
| intermediate | carry | 10 | 3.0 min | 6.3 min | 8.9 min (58%) | not reached | not reached | not reached | not reached | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | carry | 30 | 3.0 min | 6.3 min | 10.7 min | 20.0 min | 27.1 min (16%) | 28.0 min (10%) | 28.3 min (2%) | not reached | not reached | not reached | not reached | TBD | TBD |
| intermediate | carry | 60 | 3.0 min | 6.3 min | 10.7 min | 20.0 min | 35.5 min | 37.1 min | 41.5 min | 49.3 min (86%) | 51.2 min (74%) | 52.3 min (66%) | 54.5 min (32%) | TBD | TBD |
| advanced | fresh | 10 | 2.7 min | 4.7 min (91%) | 6.3 min (26%) | 8.0 min (2%) | 9.7 min (0%) | 7.5 min (46%) | 7.6 min (18%) | 9.4 min (0%) | 6.6 min (90%) | 8.9 min (55%) | 9.5 min (2%) | TBD | TBD |
| advanced | fresh | 30 | 2.7 min | 5.5 min | 12.6 min | 19.2 min (98%) | 24.8 min (74%) | 10.7 min | 16.1 min (98%) | 23.5 min (84%) | 7.2 min | 10.5 min | 16.3 min | TBD | TBD |
| advanced | fresh | 60 | 2.7 min | 5.7 min | 15.0 min | 22.3 min | 29.3 min | 12.0 min | 20.6 min | 26.9 min | 7.7 min | 10.6 min | 17.9 min | TBD | TBD |
| advanced | carry | 10 | 2.5 min | 4.7 min (95%) | 9.5 min (46%) | not reached | not reached | 8.1 min (82%) | not reached | not reached | 5.8 min (98%) | 6.8 min (98%) | not reached | TBD | TBD |
| advanced | carry | 30 | 2.5 min | 5.0 min | 11.7 min | 18.3 min | 25.1 min (92%) | 8.8 min | 16.4 min | 23.0 min (96%) | 5.9 min | 6.9 min | 13.1 min | TBD | TBD |
| advanced | carry | 60 | 2.5 min | 5.0 min | 11.7 min | 18.3 min | 25.7 min | 8.8 min | 16.4 min | 23.4 min | 5.9 min | 6.9 min | 13.1 min | TBD | TBD |

## Indicators

- Stall (slow progress, the spec's rule): more than 300 s with no affordable upgrade while earning under the cheapest remaining cost per 10 min. A stalled player still earns.
- Hard lockout (a dead end), checked at session end: stalled more than 300 s and either the session's mean income is under 1 Esencia/h (ASSUMED floor) or the Esencia on hand plus one more whole session at that mean income cannot pay the cheapest remaining upgrade.
- Ladder flags (each run at its own owned level and Esencia/h): growth above 2.5 per level, next step above 3 sessions of income, or the top level above 20 sessions of income (all three thresholds ASSUMED). Training is not simulated, so it is read at level 0.

| Profile | Farm mode | Min | Stall runs % | Hard lockout runs % | Longest stall s | Treadmill level | Treadmill hours for next | Treadmill sessions to top | Ladder flags (runs %) | Idle farm Esencia/h | Idle / expedition | Legendary sell attractive | Sell mandatory | Viable at end |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| beginner | fresh | 10 | 21 | 2 | 259 | 1.2 | 0.22 | 27.1 | treadmill_proposed 51%, incubator_proposed 100%, farm_slots_proposed 36% | 110 | 0.32 | True | False | none |
| beginner | fresh | 30 | 88 | 0 | 547 | 2.1 | 0.40 | 5.9 | treadmill_proposed 0%, incubator_proposed 100%, farm_slots_proposed 0% | 376 | 0.96 | True | False | none |
| beginner | fresh | 60 | 99 | 0 | 782 | 3.0 | 0.63 | 1.9 | incubator_proposed 100% | 616 | 1.54 | False | False | none |
| beginner | carry | 10 | 17 | 0 | 274 | 1.6 | 0.21 | 14.5 | treadmill_proposed 10%, incubator_proposed 100%, farm_slots_proposed 4% | 411 | 1.27 | True | False | none |
| beginner | carry | 30 | 74 | 0 | 436 | 2.5 | 0.38 | 3.7 | incubator_proposed 100% | 533 | 1.41 | True | False | none |
| beginner | carry | 60 | 98 | 0 | 635 | 3.0 | 0.49 | 1.5 | incubator_proposed 100% | 775 | 1.90 | False | False | none |
| intermediate | fresh | 10 | 4 | 0 | 82 | 2.2 | 0.17 | 7.3 | treadmill_proposed 2%, incubator_proposed 100%, farm_slots_proposed 2% | 495 | 0.45 | True | False | incubator_1 49% |
| intermediate | fresh | 30 | 4 | 0 | 97 | 3.9 | 0.40 | 1.0 | incubator_proposed 100% | 1230 | 1.03 | True | False | cradle_2 68%, farm_slot_5 74%, incubator_1 89% |
| intermediate | fresh | 60 | 4 | 0 | 157 | 5.0 | 0.62 | 0.0 | incubator_proposed 100% | 1952 | 1.58 | False | False | cradle_2 23%, farm_slot_5 31%, incubator_1 0% |
| intermediate | carry | 10 | 1 | 0 | 50 | 2.7 | 0.17 | 4.1 | incubator_proposed 100% | 1079 | 0.98 | True | False | cradle_2 2%, farm_slot_5 9%, incubator_1 60% |
| intermediate | carry | 30 | 1 | 0 | 65 | 4.3 | 0.35 | 0.5 | incubator_proposed 100% | 1543 | 1.29 | True | False | cradle_2 71%, farm_slot_5 74%, incubator_1 71% |
| intermediate | carry | 60 | 1 | 0 | 168 | 5.0 | - | 0.0 | incubator_proposed 100% | 2288 | 1.83 | False | False | cradle_2 10%, farm_slot_5 12% |
| advanced | fresh | 10 | 0 | 0 | 29 | 2.2 | 0.06 | 2.5 | incubator_proposed 100% | 915 | 0.34 | True | False | farm_slot_5 5%, incubator_1 17%, incubator_2 1%, treadmill_2 6%, treadmill_3 1% |
| advanced | fresh | 30 | 0 | 0 | 116 | 4.8 | 0.15 | 0.1 | incubator_proposed 100% | 2313 | 0.84 | True | False | incubator_2 1%, incubator_3 2% |
| advanced | fresh | 60 | 0 | 0 | 90 | 5.0 | - | 0.0 | incubator_proposed 100% | 2958 | 1.03 | False | False | none |
| advanced | carry | 10 | 0 | 0 | 35 | 2.7 | 0.06 | 1.5 | incubator_proposed 100% | 2455 | 0.92 | True | False | incubator_1 6%, incubator_2 22%, treadmill_3 15%, treadmill_4 2% |
| advanced | carry | 30 | 0 | 0 | 79 | 4.9 | 0.13 | 0.0 | incubator_proposed 100% | 4008 | 1.45 | True | False | none |
| advanced | carry | 60 | 0 | 0 | 79 | 5.0 | - | 0.0 | incubator_proposed 100% | 4987 | 1.73 | False | False | none |

## Cost ladders

| Ladder | Paid costs | Ratios | Mean growth | Growth flag |
| --- | --- | --- | --- | --- |
| treadmill_proposed | 30/80/200/450/900 | 2.667/2.5/2.25/2.0 | 2.34 | False |
| incubator_proposed | 100/300/750 | 3.0/2.5 | 2.74 | True |
| farm_slots_proposed | 200/500 | 2.5 | 2.50 | False |
| training_live | 30/48/77/123 | 1.6/1.604/1.597 | 1.60 | False |

## Stalls and lockouts, stated plainly

- beginner, fresh, 10 min: stalled in 21% of runs (longest stall 259 s on average); hard lockout in 2% of runs.
- beginner, fresh, 30 min: stalled in 88% of runs (longest stall 547 s on average); hard lockout in 0% of runs.
- beginner, fresh, 60 min: stalled in 99% of runs (longest stall 782 s on average); hard lockout in 0% of runs.
- beginner, carry, 10 min: stalled in 17% of runs (longest stall 274 s on average); hard lockout in 0% of runs.
- beginner, carry, 30 min: stalled in 74% of runs (longest stall 436 s on average); hard lockout in 0% of runs.
- beginner, carry, 60 min: stalled in 98% of runs (longest stall 635 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 10 min: stalled in 4% of runs (longest stall 82 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 30 min: stalled in 4% of runs (longest stall 97 s on average); hard lockout in 0% of runs.
- intermediate, fresh, 60 min: stalled in 4% of runs (longest stall 157 s on average); hard lockout in 0% of runs.
- intermediate, carry, 10 min: stalled in 1% of runs (longest stall 50 s on average); hard lockout in 0% of runs.
- intermediate, carry, 30 min: stalled in 1% of runs (longest stall 65 s on average); hard lockout in 0% of runs.
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
| advanced | 60 | 55 | 20 | 100 | 44 | 32 | 41 |

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
- `egg_share` = 0 (src/wildbound/WildboundSpawnClock.luau)
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
- The treadmill walk 17-21 conflicts with Q9 (walk 16) and the live WALK_CAP 16; the model uses the proposed speeds.
- No day/night, no material gathering, no consumables, no portals.
