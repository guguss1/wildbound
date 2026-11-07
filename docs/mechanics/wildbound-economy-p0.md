# Wildbound P0 economy

Unit M5.1, wave W4a. Implements D5 and D10, and D4 and D14 where they touch rewards.

**Status: partly built (W7 part 1, M5.2, M5.4, M5.5). All numbers are hypotheses, not balanced or tested with people.** Written 2026-11-07 without Studio, then revised the same day because `tools/simulate_economy.py` showed the first version did not work. Everything stays session-only until M6. **No monetization: no Robux, no paid items, no `MarketplaceService`.** Ember cannot be bought.

## Build status, W7 part 1 (2026-11-07)

| Built | Where | Proof |
| --- | --- | --- |
| Tuning copy of the JSON below, generated, never hand-edited | `src/wildbound/WildboundEconomyConfig.luau` by `tools/export_economy_config_luau.py`; `tools/test_export_economy_config_luau.py` fails on any drift | 11 Python tests |
| Loss rule, capacities, carry speed, Ember, atomic payment | `src/wildbound/WildboundEconomy.luau` | 14 Studio contracts, incl. AFK-1 source checks |
| Materials, Ember, gather claims, Nightbloom bundles, extraction, defeat loss, risk preview; seal fix (B8), crafting, totem, Reinforced Pack, capsule | `src/wildbound/WildboundState.luau` | 52 Studio contracts, incl. AFK-2 to AFK-6 |
| Spawn pipeline: biome, zone, phase, weather, event; seeded | `src/wildbound/WildboundSpawn.luau` | 11 Studio contracts, 100,000 draws |
| Server wiring: expedition tracking, actions, gather seam, carry speed, totem downside | `WildboundServer.server.luau`, `WildboundWorld.server.luau` | One solo Play, below |

Not built: world nodes, Night resource on, skills, bond, camp screen, HUD loss display (part 2); 12-minute cycle (M5.7); D10 hold (M6.5). `nightRewardsEnabled` stays false.

**Play, desktop Studio, damage off throughout.** Eight fog nodes through the seam paid 19 units and set walk speed 13; a repeat slot gave `AlreadyGathered`, a far claim `InvalidContext`. A 47 s, 369-stud materials-only trip extracted for 4 Ember and the first seal. Crafted a seal at camp, armed it, and the next egg was warded. Defeat through `Health = 0` lost 2 of 4 Glowmoss and 2 of 3 Fogbark, kept the egg, spent one seal, kept Ember and banked materials. No errors or warnings. Not run in Play: totem, capsule, pack, two players, phones.

**Where this document proved wrong or silent, and what was decided:**

| Point | Decision |
| --- | --- |
| ECO-07 assumes crafted seals before the first extraction | Unreachable: crafting needs banked materials, which only an extraction gives. The grant still adds, and is capped at the seal limit of 3 |
| ECO-02 uses a stack of 100 | The pouch holds 30, or 45 with the pack. Tested with 25 and 30 |
| Camp sink range and shelter point were prose only | Added `sinks.campRange` 20 and `capsule.x`, `capsule.z` to the JSON |
| Which ward a totem holder's first Protect uses | The totem: it is spent with the trip anyway, so the seal is kept |
| "Next item into the bag" for an armed seal | Next new item only; a reclaimed drop is not new. A manual seal uses the armed one |
| Night tables with night rewards off | Nightbloom is filtered out and the rest renormalized; nothing is multiplied |
| Weather and events in M5.4 | P0 has none. Only `Clear` and `None` are accepted; a future table replaces, never multiplies |
| Egg tier at pickup | Every nest is in territory, so eggs are stored as `Territory` |
| "Camp safe circle" for expeditions | The `Rules.zone` safe circle nearer camp than the shelter |
| Existing contract `kept.ember == 0` | Became 18: Ember now exists and is never lost |

## Wiring notes for part 2

| Unit | What exists | What part 2 does |
| --- | --- | --- |
| World nodes (M5.3) | Server-only bindables in `WildboundNetwork`. `GatherSpawn:Invoke(slotId)` rolls and registers a node and returns `{ id, slotId, zone, heart, x, z, material, quantity, phase, hold }`. `GatherClaim:Invoke(player, id)` checks reach (8 studs, flat), claims, replies to the player and returns `ok, receipt` or `false, reason`. `GatherRetire:Invoke(id)` removes only | Draw the node, a `ProximityPrompt` with `HoldDuration = hold`; claim on `Triggered`. Keep the node on `PouchFull`, `BackpackFull`, `AlreadyGathered`. Keep `Spawn.activeCount` nodes per zone; after a claim wait `respawnSeconds`, then `Spawn.pickSlot`. ECO-25 cancel-on-move needs its own check |
| Night resource | `GatherSpawn` reads `WildboundWorldRuntime` attributes `CycleStartedAt` and `NightRewardsEnabled` at spawn time | Turn it on test-first at `WildboundWorld.server.luau:54` and its payload; reword the Night notice; at Dawn, `GatherRetire` unclaimed Nightbloom nodes |
| Skill tree (M5.6) | `config.skills`; `State` has `atCamp` and `purchase` helpers | Add `State:learn` with `NeedsPrerequisite`, a `Learn` entry in `ECONOMY_ACTIONS`, then each effect where its rule lives |
| Bond | Nothing | Pending XP on the expedition, banked in `extract`, cleared in `defeat`. Pulse hits are decided in the world script, so they need a server-only event to this script, like `TotemChanged` in reverse |
| Camp screen (M5.8) | `Action` arguments: `Craft` seal, capsule, totem; `Upgrade` reinforcedPack; `ArmSeal`, `SealNewest` seal; `ArmTotem`, `DisarmTotem` totem; `UseCapsule` pending uid. Costs in `ReplicatedStorage.WildboundEconomyConfig`; `Economy.canPay` for disabled buttons | Camp is 20 studs from `CampCenter`; the shelter is the point (105, 125), range 12. No `ShelterMarker` part exists yet |
| HUD loss display | Snapshot adds `carried`, `banked`, `pouchCapacity`, `ember`, `consumables`, `sealArmed`, `totemActive`, `upgrades`, `expedition`, `riskPreview = { loseItems, keep, loseMaterials }`. The loss summary adds `materialsLost` and `savedItems` | `WildboundHudView.lossSummary` shows items and one saved item only; add materials, a second save and the name of a `Nightbloom` bundle (`quantity`). `WildboundClient.client.luau:199-200` still says seals work only at camp |

## Choices worth your review

| # | Choice taken | Tradeoff |
| --- | --- | --- |
| 1 | **Defeat takes half of each carried stack, a quarter with the Reinforced Pack.** Replaces the pack's 12% and 8% | One sentence to explain, and materials finally matter. At 12% a node paid more than a defeat could take. Harsh. The run barely moves at 25%, so the math requires less than this (see Revision) |
| 2 | **Nightbloom is a bag item, one slot per bundle,** lost entirely on defeat unless warded | Bag pressure at Night and a real use for seals and capsules. Adds a third kind to `pending` |
| 3 | **Holds grow with exposure:** 3 s outside, 4 s fog, 6 s territory, 9 s at heart slots | About 30 s of the expedition. Outside and fog holds are plain pacing, not danger, and may feel like waiting. Touch is unverified |
| 4 | **Heart slots** T1, T2, T6: 9 s hold, one extra unit, chosen because the pressure geometry strikes there most | Value sits where standing still is dangerous. A slot's danger depends on proposed ambush anchors |
| 5 | **A loaded pouch slows you:** 13 studs/s from 40% full, 11 from 80%, never below `carrySpeed > 8` | A second cost on the way home. Slower feels bad, and a phone stick may hide why |
| 6 | Solo slots rise to 24 in all, 18 active. Ten new coordinates, checked by script only | Supply stops ending trips. More world dressing in M5.3 |
| 7 | **D5 stands, at its low end.** Medians land at 190 to 208 s, not mid-range. Nothing replaced | A cautious route needs all 16 safe nodes to reach 3 minutes. See Revision |
| 8 | Tier 2 skills and advanced items still need Nightbloom. **The safe path is fog beyond the leash at Night,** where Silueta cannot target by rule | A player who goes home every Night still cannot finish the tree. Simulated: never earns any. I kept this as the reason to go out at Night |
| 9 | Loss rounds to the **nearest** unit per stack, not down as the pack suggests | At 50% a stack of 1 is lost. Readable: nothing is ever secretly safe |
| 10 | Risk pays through Ember: a Lumipol from territory earns more than one from outside the leash | Without it the safe route wins. Rewards bravery but widens progress gaps |
| 11 | After the D10 hold expires, the result equals a defeat. On return in time, you resume **where you left**, not at camp | Otherwise logging out teleports loot to the extraction point. Requires changing the respawn pivot |
| 12 | No release or sell for duplicates. Duplicates earn Ember once, at extraction | No way to delete a companion by mistake. Collection limit 100 stays unsolved until M6 |

## Revision after the simulator

The first version failed on the simulator's archetypes. **The archetypes, their nerve and their risk rule are invented, so these numbers show structure, not players.** 200 seeded runs of 90 expeditions, `python -I -B tools/simulate_economy.py`.

| Measure | Before | After |
| --- | --- | --- |
| Median expedition, cautious, balanced, greedy | 52, 73, 77 s | 208, 203, 190 s |
| Nodes per expedition against plan | 4.0 of 7, 6.0 of 7, 4.9 of 8 | 15.9 of 16, 13.7 of 16, 11.5 of 16 |
| Trips ended by the player judging the risk | Not possible | 0, 35, 12% |
| Materials alone: break-even hazard in territory | 0.82, against an invented 0.30 | 0.14, against 0.41 from geometry |
| One heart node at Night while marked: break-even, light against loaded | Not measured | 0.52 against 0.06. Real strike share is 0.30 to 0.41, so the answer flips with the load |
| Greedy that stays when loaded or marked, against one that leaves | Not measured | Value per minute 22.1 against 25.1, defeats 32% against 17% |
| Value per minute, cautious against balanced | Not measured | 17.5 against 24.4 |
| Bag full, share of trips | 0, 0, 0%, at most 2 of 3 | 18, 32, 42% |
| Pouch full, whole run | 0, 3, 5% | 13, 22, 31%. On the base pouch: 41, 56, 62% |
| Everything owned | Never, 21, 18 min | 132, 97, 87 min, which is 4 to 7 sessions of F1's 20 minutes |
| Purchases in the first 20 minutes, of 9 | Not measured, nearly all for balanced | 2, 3, 3 |
| `capturer_1` | Trip 1 for balanced | Trip 2 for all |
| Cautious reaches tier 2, capsule, totem | Never | Yes, with 30 Nightbloom over 90 trips and no strike |
| Full pouch, expected units lost, base against Reinforced | 3.60 against 3.60 | 15 against 11.25 |

**Why these changes.** The route is 798 studs, about 50 s, and the map cannot give 3 minutes of walking. Time comes from more objectives per trip, holds, captures, evasion and slower walking when loaded. The pressure simulator showed that a still player at 4.5 s is mostly warned, and at 6 s is struck, near the patrol. Moving players are almost never hit. So standing still is the risk. Holds became the exposure, value moved to where they are dangerous, and the defeat chance stopped being an input: it now comes from geometry, plus nerve at a warning. D6's two strikes then create the decision. Unmarked, the next strike costs one item. Marked, it costs the trip.

**Decisions.** D5, D4, D6, D10 and D14 stand. No replacement was needed. The first version's own claim that a day-only player cannot finish stays true.

**Sensitivity** (25 runs of 70 trips each). Nerve halved or raised by half, risk aversion halved or doubled, evade time 4 or 14 s, Nightbloom's comparison value 5 or 40, capture rates 0.5 or 0.95: medians stay 164 to 215 s, cautious finishes in at least 96% of runs, and balanced stays at least 1.27 times cautious in value per minute. Greedy with nerve 1.0 drops to 164 s, below target, because 40% of its trips end early in defeat. Holds of 1, 2, 3 and 5 s give 163 to 178 s. Halving the loss rates moves value per minute by under 3%, so the run itself does not justify 50%; only the break-even math and a simple sentence do.

### Still only math

| Item | Status |
| --- | --- |
| Archetypes, `holdThroughWarning`, `riskAversion`, `dropRecovery`, `defeatChance`, `valueWeights`, `evadeSeconds`, `campSeconds` | Invented |
| Strike shares | Geometry from `simulate_silueta_pressure.py`, averaged over proposed ambush anchors. No line of sight, so a worst case. Each hold is treated as independent |
| Walking | Straight lines, so a lower bound. Never struck, and walking warnings cost no time, so another lower bound |
| Skills, seals, totems, capsules | Prices are simulated; their effects are not. Consumables are never bought in a run |
| Purchase order | Cheapest first, invented. The pack lands late for that reason; its cost alone is covered by trips 6 to 7 |
| Sessions | 20 minutes of expedition time. Camp time excluded, so real progress is slower |
| Multiple players | Not simulated. Solo rows only |
| Fun, fear, fairness, whether anyone weighs anything | Not modelled at all |

### What would falsify this in play

| Claim | Falsified by |
| --- | --- |
| 3 to 8 minute expeditions | F1 median outside that range, or a large gap between defeated and extracted trips |
| Holds read as tension | Testers say "I just stood there", or outside and fog holds get complaints while heart holds do not |
| Players weigh stay against leave | Marked players leave at the same rate whatever they carry, or stay at the same rate as unmarked ones |
| Half of carried materials is a fair stake | Testers stop going out after one defeat, or cannot state the rule (ECO-33) |
| Bag pressure is a decision | Bag fills without comment, or players drop nothing and never leave a bundle behind |
| Slower when loaded adds tension | Testers blame lag or controls for it |
| Fog at Night is a safe path that still feels frightening | Cautious testers never go out at Night, or it feels like free loot |
| Heart slots are worth it | Under 10% of nodes taken are heart slots after informing players, or over 60% |
| Several sessions of progress | A tester cannot name a next goal, or reaches a plateau in a session |

## Verified facts

| Fact | Source |
| --- | --- |
| No materials, currency, tools, upgrades or skills exist | `docs/wildbound-roadmap.md:76`; `src/wildbound/WildboundState.luau:113-119` |
| Bag capacity is a file constant of 3, collection limit 100 | `WildboundState.luau:4` |
| First nonempty extraction **assigns** `sealCharges = 1`, once | `WildboundState.luau:121-124` |
| `State:protect` needs no distance, but the adapter requires 12 studs from camp marker | `WildboundState.luau:149-162`; `src/wildbound/WildboundServer.server.luau:104-110` |
| A seal is spent only if it saves the item; extraction clears protection free | `WildboundState.luau:176-182`; `docs/mechanics/wildbound-state.md:22` |
| Registered pets and banked eggs survive defeat | `WildboundState.luau:174-184`; `tests/WildboundState_Test.luau:201` |
| Night rewards flag is hardcoded false | `src/wildbound/WildboundWorld.server.luau:34`, `:195`, `:304` |
| Cycle is 1200 s with Day 600, Dusk 120, Night 360, Dawn 120, and a contract pins it | `src/wildbound/WildboundWorldRules.luau:4`, `:31-38`; `tests/WildboundWorldRules_Test.luau:21-23` |
| Leaving discards the profile | `WildboundServer.server.luau:263`; `WildboundState.luau:62-67` |
| Every new character is moved to camp | `WildboundServer.server.luau:245` |
| Shelter does not bank loot | `docs/mechanics/wildbound-world.md:17` |
| Pulse hit is decided by the server, cooldown 30 s | `WildboundWorldRules.luau:117-131` |

Pack values used as hypotheses: totem hostile cost, capsule at shelter, four skill paths, bond 1 to 5 from active use. The pack's 12% and 8% loss were tried and replaced, per choice 1 (`resources/skill-packs/wildbound-codex-complete-v0.4.2/knowledge/wildbound/RISK_AND_PROTECTION.md:13-24`, `PROGRESSION.md:3-5`, `CREATURE_PROGRESSION.md:3-5`). Roblox random-item rule as read on 11-07: rewards earned only through play need no odds disclosure (`docs/wildbound-roadmap.md:415`). Recheck if that ever changes.

## The loop this creates

Leave camp. Gather and catch until the bag or pouch is full, or Silueta marks you, or Night tempts you to stay. Walk home slower if you carry eggs or a heavy pouch. Extract. Spend at camp. Go back better prepared, for something you could not reach before.

## Model

| Thing | Where it lives | At risk? |
| --- | --- | --- |
| **Bag items:** eggs, captured Lumipols, Nightbloom bundles | `pending`, 3 slots | Yes. Lost on defeat unless warded |
| **Carried materials:** Fogbark, Glowmoss | `carried`, 30 units total | Half of each stack on defeat |
| **Banked materials** | `banked` | **Never** |
| **Ember**, the camp currency | `ember`, earned only at extraction | **Never** |
| **Registered companions**, banked eggs | Existing lists | **Never** |
| Crafted consumables | `consumables`, carried | Not lost; used up by their rules |
| Upgrades, skills, bond levels | Profile | **Never** |

Hatching stays free (`WildboundServer.server.luau:102`). Flashlight stays free.

```luau
-- Profile additions in WildboundState. All integers, all nonnegative.
carried = { fogbark = 0, glowmoss = 0 }   -- Nightbloom travels in the bag
banked = { fogbark = 0, glowmoss = 0, nightbloom = 0 }
ember = 0
consumables = { seal = 0, capsule = 0, totem = 0 }   -- seal replaces sealCharges
sealArmed = false
totemActive = false
upgrades = { reinforcedPack = false }
skills = {}                  -- [skillId] = true
bond = {}                    -- [petUid] = { xp = 0, level = 1 }
dropped = {}                 -- [uid] = { entry, expiresAt }
expedition = nil             -- below
-- pending entry gains: riskTier, wardSource = "Seal" | "Totem" | nil (replaces protected in M5.5)
-- and a third kind: { kind = "Nightbloom", quantity = number }. It banks as a material and pays no Ember

expedition = { id = string, startedAt = number, leftCamp = boolean, maxDistanceFromCamp = number,
    territorySeconds = number, paidSlots = {}, pendingBondXp = 0, bondEvents = {}, newUnits = 0, newItems = 0 }
```

**Expedition boundaries.** Opens when an alive player crosses out of the camp safe circle (`WildboundWorldRules.luau:50`). Closes on extraction, defeat or hold expiry. Crossing back into camp without extracting keeps it open. There is no expedition state today.

## Loss rule on defeat

Applied once per defeat operation, inside `State:defeat`, with no yield. Integer arithmetic only, so no float error.

```text
lost(stack) = (quantity * rateBasisPoints + 5000) // 10000
rate = 5000, or 2500 with the Reinforced Pack
```

| Stack | Lost at 50% | Lost at 25% |
| --- | --- | --- |
| 100 | 50 | 25 |
| 25 | 13 | 6 |
| 12 | 6 | 3 |
| 5 | 3 | 1 |
| 4 | 2 | 1 |
| 1 | 1 | 0 |

**Order, once per `operationId`:** 1. Warded items survive, spending one seal if seal-warded. 2. Other pending items go. 3. Dropped items go. 4. Each carried stack loses `lost(stack)`. 5. Totem spent if it left camp. 6. Pending bond XP goes. 7. Expedition closes. 8. Return loss summary (`wildbound-fair-strike.md`).

**Never lost, with a contract each:** Ember, banked materials, registered companions, banked eggs, upgrades, skills, bond. Night does not change the rate. Remaining carried materials stay carried and bank at the next extraction.

**Strike drop (D6):** first strike drops one bag item, which may be a Nightbloom bundle, never pouch materials. See `wildbound-fair-strike.md`.

### Disconnect (D10)

| Case | Result |
| --- | --- |
| Leave, return within 180 s, same server | Resume at last position with bag, pouch, mark and K intact, plus a new 3 s grace in which Silueta cannot acquire that player |
| Not back in 180 s | Resolves as a defeat without a mark: same order as above |
| Server closes in the hold | Session-only today, so all is gone. M6 defines the durable case |
| Leave in camp | Nothing at risk changes; hold still applies to carried items |

Before M6, returning to a **different** server starts fresh, because nothing is saved. **Changes existing behavior:** `removePlayer` becomes a hold, and the pivot at `WildboundServer.server.luau:245` must skip a returning player with a live hold. Implement in M6.5; M5 only keeps the shape ready.

## Gather nodes

| Rule | Value |
| --- | --- |
| Input | Prompt, hold by band below, 8 studs. Server rechecks alive and distance, as `context()` does |
| Claim | One owner (D4). First valid trigger takes it, node disappears for all |
| Respawn | 75 s, at any inactive slot of the same zone |
| Per player | A slot pays one player once per expedition. Repeat: `AlreadyGathered`, node stays for others |
| Pouch | Takes what fits, wastes the rest, says so. No space at all: `PouchFull`, node not claimed |
| Bag | A Nightbloom node takes one bag slot for its whole bundle. No slot: `BackpackFull`, node not claimed |
| Night rule | Material is chosen when the node spawns, by the current phase table. Unclaimed Nightbloom wilts when Dawn starts. A bundle in the bag keeps |
| IDs | Same as encounters: never reused, retired after use (`WildboundState.luau:78-84`) |

| Band | Hold | Slots | Strike share if you never flinch, Day / Night |
| --- | --- | --- | --- |
| Outside | 3 s | O1 to O8 | 0, by rule |
| Fog | 4 s | M1 to M8 | 0, by rule |
| Territory | 6 s | T3, T4, T5, T7, T8 | 0.00 to 0.17 / 0.03 to 0.24 |
| Heart | 9 s | T1, T2, T6 | 0.25 to 0.27 / 0.30 to 0.41 |

Strike share comes from `simulate_silueta_pressure.py`, run once for each patrol anchor in `wildbound-fair-strike.md` and averaged by weight, with no line of sight. For comparison, a 5.5 s capture is 0.15 / 0.21 at `L1`, 0.09 / 0.21 at `L2`, 0.05 / 0.08 at `L3`, 0 at `L4`. Warned means Alert begins; moving then escapes, at the cost of the hold.

**Carrying.** Walk speed is the slower of the pouch step and the egg speed in `wildbound-capture.md`. It is set on the server when the pouch or bag changes, along with M3.5's egg speed.

| Pouch filled | Walk speed |
| --- | --- |
| Under 40% | 16 |
| 40% or more | 13 |
| 80% or more | 11 |

Silueta's fastest speed is 8, so the contract `carrySpeed > 8` holds for every combination, and a loaded player still outruns it.

Slot coordinates are in the JSON below, checked against zones by script and, on 11-07, for at least 5 studs from any instance in `forest-layout-v1.json`. O5 to O8, M5 to M8, T7 and T8 are new. Nodes are non-colliding, so tight spots are acceptable. Not verified in play.

**Zones** (by `WildboundWorldRules.zone` and `inTerritory`): `outside` is out of the fog rectangle, `fog` is in the rectangle but beyond Silueta's leash, `territory` is where it can target you.

## Night-only resource (D5)

**Nightbloom.** Spawns only at Night, only in `fog` and `territory`. A node yields one bundle that takes a bag slot. It feeds totems, capsules and tier 2 skills. No new species or variant, because D5 chose one resource and the pack warns about false rarity. Turning this on means `nightRewardsEnabled = true` and rewording `WildboundWorld.server.luau:304`.

**Safe path.** Fog beyond the leash is outside Silueta's reach by rule (`WildboundWorldRules.luau:55-58`), and it has eight slots, at 15% Nightbloom, one per bundle. So a cautious player can earn every Nightbloom without entering territory, slowly: about 0.10 per minute against 0.34 for balanced (simulated). Territory pays more per node, and heart slots most: 2 to 3 per bundle. M5 sits at the old nest, far from camp, so the safe path is long rather than dangerous.

**Cycle, per D5.** 12 minutes, keeping the current proportions: Day 360, Dusk 72, Night 216, Dawn 72. The server draws one start offset, uniform over non-Night time, once at start. **Changes existing behavior:** `Rules.CYCLE_SECONDS`, the phase table, the origin at `WildboundWorld.server.luau:30`, and the contract at `tests/WildboundWorldRules_Test.luau:21-23` (update first, observe RED).

**Calculated:** median wait to the first Night is about 253 s, 90th percentile 453 s, maximum 504 s. M1.5 still asks for a natural 20-minute run. Run it, and repeat at 12 minutes after M5.7.

## Spawn weights

Filter first by zone and phase, then normalize: `p = weight / sum(weights)`. Weights are not published odds. One table only: no multiplier is stacked on top, avoiding the double-boost warned about in the pack's `SPAWN_SYSTEM.md:27`. RNG is one server `Random` with a logged seed; clients never get the seed.

| Zone, phase | Fogbark | Glowmoss | Nightbloom |
| --- | --- | --- | --- |
| Outside, any | 85.0% | 15.0% | 0 |
| Fog, not Night | 55.0% | 45.0% | 0 |
| Fog, Night | 45.0% | 40.0% | 15.0% |
| Territory, not Night | 40.0% | 60.0% | 0 |
| Territory, Night | 25.0% | 40.0% | 35.0% |

Yields, per node, inclusive:

| Zone | Fogbark | Glowmoss | Nightbloom |
| --- | --- | --- | --- |
| Outside | 1 to 2 | 1 | |
| Fog | 2 to 3 | 2 | 1 |
| Territory | 2 to 3 | 2 | 1 to 2 |
| Heart slot | 3 to 4 | 3 | 2 to 3 |

Low yields are deliberate: one pouch is about 13 nodes, so filling it takes most of a trip.

Creature and egg slots are in `wildbound-capture.md`. All are Lumipol in P0, one outcome, weight 100.

## Earning Ember

Paid once at extraction. Only at extraction, so it can be lost by not returning, though earned Ember never is.

| Source | Ember | Condition |
| --- | --- | --- |
| Completed trip | 4 | Expedition at least 45 s, reached 60 studs from camp, at least one new item or unit |
| Lumipol, tier Safe | 6 | First-capture slot |
| Lumipol, tier Fog | 8 | `L4` |
| Lumipol, tier Territory | 14 | `L1` to `L3` |
| Egg, tier Territory | 10 | Any nest |
| Nightbloom bundle | 0 | Banks as a material |

Duplicates pay the same. This fixes B1, "duplicates are useless". Tier is stored on the item at capture and read at extraction, so nobody can upgrade it on the way home. **Changes existing behavior:** `extract` accepts materials-only trips; `Empty` now means no bag items and no carried units. Its first-extraction seal stays, but must add 1, not assign, so a crafted seal is not overwritten (`WildboundState.luau:123`).

## Sinks

All at camp, within 20 studs of `CampCenter`, alive, non-yielding: check, pay, grant.

| Item | Cost | What it does | Limit |
| --- | --- | --- | --- |
| **Ward Seal** | 8 Fogbark, 4 Glowmoss | Saves one chosen bag item on defeat. Spent only if it saves | Hold 3 |
| **Last Breath Totem** | 12 Glowmoss, 2 Nightbloom, 20 Ember | Wards one extra item with no seal. **Downside below** | Hold 1, one active |
| **Extraction Capsule** | 8 Fogbark, 5 Glowmoss, 1 Nightbloom, 12 Ember | Banks one bag item at the shelter, on the spot | Hold 1 |
| **Reinforced Pack** | 60 Fogbark, 30 Glowmoss, 120 Ember | Permanent. Bag 4, pouch 45, loss 25% | Once |
| **Skills** | Below | Permanent | Once each |

### Seal fix for B8

Today the seal is pointless: usable only within 12 studs of camp on an item already in the bag, where you would just extract, and only one per session (`docs/wildbound-roadmap.md:129`).

| Change | Old | New |
| --- | --- | --- |
| Where | 12 studs from camp | **Anywhere, alive.** Remove the check at `WildboundServer.server.luau:107` |
| Before leaving | Not possible, bag is empty | **Arm at camp:** the next item into the bag is warded automatically. Not spent if nothing comes |
| Supply | One, ever | First extraction gives one; craft more, repeatedly |
| Input | Inventory selection only | One-tap "Seal newest" on the quick bar, plus existing selection |
| Limit | One item at a time | Unchanged, `AlreadyProtected`, at most one seal-warded item |

Spend-only-if-it-saves stays, per the existing contract. A warded item cannot drop to a strike. No softlock: Ward Seal costs materials reachable without entering territory.

### Totem with a downside

| Effect | Detail |
| --- | --- |
| Upside | Wards one more chosen item, no seal spent |
| Downside 1 | Silueta detects the holder from 6 studs farther: 34 by day, 44 at night. Applied only to that player, in `targetContext` range. Chase range stays 65 |
| Downside 2 | Ambush anchors within 60 studs of the holder get weight x2 before normalizing (`wildbound-fair-strike.md`). No camera or gaze input |
| Use | Arm at camp. HUD chip says "Totem: Silueta senses you from farther." Disarm before leaving refunds it |
| Spent | When an expedition that left camp ends, whether or not it saved anything. Reconnect does not refresh it |
| Stacking | One. Night does not change it |

### Capsule

Used within 12 studs of a new `ShelterMarker` at (105, 125). Choose one bag item; it moves to banked eggs, registered or banked Nightbloom, and pays its Ember now. No hatching. **Changes existing behavior:** the shelter gains one banking use (`docs/mechanics/wildbound-world.md:17`). Calculated distance: nest to shelter 235 studs, nest to camp 296.

## Skill tree

Four branches, two nodes each. Cost: tier 1 is 40 Ember, 20 Fogbark and 10 Glowmoss. Tier 2 is 100 Ember, 30 Fogbark, 20 Glowmoss and 3 Nightbloom, and needs tier 1. No respec in P0.

| Branch | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| Explorer | Trail Sense | Compass shows active gather nodes within 60 studs | Capture slots stay unmarked |
| Explorer | Night Nose | Nightbloom shown within 100 studs | Night only |
| Capturer | Steady Hands | `CALM_REQUIRED` 4.5 to 4.0 | **Standing still must still fail:** stationary maximum is about 3.6 |
| Capturer | Soft Approach | Retry cooldown 6 to 3 s | Others' reservation unchanged |
| Survivor | Light Load | Egg walk speed +1, cap 16 | `carrySpeed > 8` |
| Survivor | Quick Rest | Mark clears in 2 s instead of 5 | Safe zone only |
| Occultist | Read the Signs | Notice "Something moved in the fog" 5 s after an ambush move, no location | No camera or gaze input |
| Occultist | Long Reveal | Your flashlight reveal lasts 5 s, not 4 | Overlaps take the max, per `WildboundWorld.server.luau:320` |

No skill cancels Silueta, and none is needed to finish a route.

## Bond

Per companion, levels 1 to 5, only from the active companion (D14).

| Event | XP | Limit per expedition | Server evidence |
| --- | --- | --- | --- |
| Pulse reveals Silueta, player in fog | 5 | 4 | `Rules.tryAbility` returned hit |
| Telegraph misses you within 10 s of your pulse | 5 | 2 | Attack cancelled for geometry, target moved |
| Extract with it equipped | 10 | 1 | Trip meets the completed-trip condition |

| Level | Total XP | Effect |
| --- | --- | --- |
| 1 | 0 | Pulse as today |
| 2 | 40 | Stronger pulse cue |
| 3 | 100 | Pulse cooldown 27 s |
| 4 | 180 | Glow cosmetic |
| 5 | 280 | Pulse cooldown 25 s |

XP is pending until extraction and lost on defeat. Cap 40 per expedition. Equipping does not transfer XP.

## No AFK path

**Contract:** no quantity grows from the passage of time alone, and no reward is reachable without server-observed player action, plus a walk back to camp.

| ID | Rule | Test |
| --- | --- | --- |
| AFK-1 | No grant runs on a timer. Only prompts, extraction and pulse hits grant | Source check: no economy write in any Heartbeat, `task.delay` or `task.wait` path except wilt and expiry, which only remove |
| AFK-2 | Idle hour changes nothing | Simulated 3600 s of steps for an idle player at camp, at a node and in territory: full snapshot unchanged |
| AFK-3 | A held key on one node cannot farm | One slot pays once per expedition |
| AFK-4 | A pulse macro cannot bank XP | XP banks only on extraction; event cap; cap per trip |
| AFK-5 | Empty trips pay nothing | Base Ember conditions |
| AFK-6 | Standing in camp pays nothing | Expedition not open; extraction `Empty` |

A bot that really walks the route is active play as far as the server can see. It is outside this contract, with no leaderboard or trade to protect.

## Network

Extend `Action` (`WildboundServer.server.luau:192-200`). Second argument remains one string of at most 128 bytes, and is looked up in a server table; unknown IDs are dropped silently. Existing rate limits apply.

| Action | Argument | Refusals |
| --- | --- | --- |
| `Craft` | `seal`, `capsule`, `totem` | `NotAtCamp`, `CannotAfford`, `AtLimit` |
| `Upgrade` | `reinforcedPack` | `NotAtCamp`, `CannotAfford`, `AlreadyOwned` |
| `Learn` | Skill ID | `NotAtCamp`, `CannotAfford`, `AlreadyOwned`, `NeedsPrerequisite` |
| `ArmSeal` | `seal` | `NoSeal`, `InvalidContext` |
| `SealNewest` | `seal` | `NoSeal`, `Empty`, `AlreadyProtected` |
| `ArmTotem`, `DisarmTotem` | `totem` | `NotAtCamp`, `NoTotem`, `AlreadyLeft` |
| `UseCapsule` | Pending UID | `NotAtShelter`, `NoCapsule`, `NotOwnedPending` |

Gather uses prompts, like pickup. Replies go through `reply()` and `State`.

**Snapshot additions:** `carried`, `banked`, `pouchCapacity`, `ember`, `consumables`, `sealArmed`, `totemActive`, `upgrades`, `skills`, `bond`, `dropped`, and `riskPreview = { loseItems, loseMaterials, keep }`, computed by the server for the HUD in M5.8. `capacity` becomes per player. Detached copies, as `WildboundState.luau:196-201`.

**Duplicate taps.** A second `Craft` pays twice for two items, so nothing is duplicated or lost. The client disables the button until a reply. Durable operation IDs arrive in M6.4 and are out of scope here.

## Pacing estimate

**Not measured, and says nothing about fun.** From `tools/simulate_economy.py` on the JSON below: 200 seeded runs of 90 expeditions, solo, invented archetypes. Defeat chance here is an output, except a 1 to 2% invented misplay per trip.

| Archetype | Median expedition | Walk, holds, captures, evading | Nodes | Ember per trip | Units per trip | Defeats | First skill | Everything owned |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cautious | 208 s | 66, 27, 7, 0% | 15.9 | 19.5 | 28.5 | 1% | Trip 2 | 132 min |
| Balanced | 203 s | 48, 38, 5, 8% | 13.7 | 23.7 | 27.7 | 7% | Trip 2 | 97 min |
| Greedy | 190 s | 50, 38, 5, 7% | 11.5 | 22.9 | 23.9 | 30% | Trip 2 | 87 min |

| Why a trip ended | Cautious | Balanced | Greedy |
| --- | --- | --- | --- |
| Finished its plan | 84% | 21% | 19% |
| Pouch full | 13% | 21% | 30% |
| Judged the next node not worth the risk | 0 | 35% | 12% |
| No node left for one player | 2% | 16% | 9% |
| Defeated | 1% | 7% | 30% |

**Stay or leave, one heart node at Night (value units invented: Fogbark 1, Glowmoss 2, Nightbloom 15, Ember 1).** Break-even is gain over gain plus what the next strike costs.

| Situation | Gain | Next strike costs | Break-even | Against 0.30 to 0.41 |
| --- | --- | --- | --- | --- |
| Light, not marked | 16.4 | 3.2 | 0.84 | Stay |
| Light, marked | 16.4 | 15.0 | 0.52 | Stay, if you accept it |
| Loaded, not marked | 3.3 | 4.0 | 0.45 | Stay, little to gain |
| Loaded, marked | 3.3 | 54.0 | 0.06 | Leave |

Purchases per 20-minute session, median: cautious 2, 2, 1, 1, 1, 1, 1. Balanced 3, 2, 1, 1, 1. Greedy 3, 2, 2, 1, 1. After that, income has no sink except consumables, which is M5's limit until new content.

**If F1 logs show medians under 3 minutes**, in the order I would try: add a second objective type per trip, widen the walkable distance with routes that leave the straight line, raise active nodes for one player, then extend the map. **Never** lower walk speed below `carrySpeed > 8` or add waits with no exposure.

## Tuning tables

Stable schema for `tools/simulate_economy.py`, and later `WildboundEconomyConfig.luau`. Parse the block fenced as `json economy-tuning`. Bump `schemaVersion` on any breaking change. Costs are integers. `[a, b]` is an inclusive integer range. The simulator reads this block at run time and checks it on every run. `simulatorInputs` are invented assumptions, not game data.

```json economy-tuning
{
  "schema": "wildbound.economy.tuning",
  "schemaVersion": 1,
  "status": "hypothesis",
  "monetization": "none",
  "cycle": {
    "seconds": 720,
    "phases": { "Day": 360, "Dusk": 72, "Night": 216, "Dawn": 72 },
    "phaseOrder": ["Day", "Dusk", "Night", "Dawn"],
    "startRule": "uniform_over_non_night",
    "targetExpeditionSeconds": [180, 480]
  },
  "materials": {
    "fogbark": { "tier": "common", "nightOnly": false, "carriedAs": "pouch" },
    "glowmoss": { "tier": "uncommon", "nightOnly": false, "carriedAs": "pouch" },
    "nightbloom": { "tier": "rare", "nightOnly": true, "carriedAs": "bagItem" }
  },
  "currency": { "id": "ember", "lostOnDefeat": false, "purchasable": false },
  "capacity": {
    "bagItems": 3,
    "pouchUnits": 30,
    "collectionLimit": 100,
    "consumableCaps": { "seal": 3, "capsule": 1, "totem": 1 }
  },
  "carry": {
    "baseSpeed": 16,
    "pouchLoadSteps": [ { "atShare": 0.4, "speed": 13 }, { "atShare": 0.8, "speed": 11 } ],
    "eggSpeeds": "wildbound-capture.md, slower of the two applies"
  },
  "loss": {
    "rateBasisPoints": 5000,
    "rateBasisPointsReinforced": 2500,
    "rounding": "nearest_half_up_per_stack",
    "appliesTo": ["carried"],
    "neverLost": ["ember", "banked", "registered", "bankedEggs", "consumables", "upgrades", "skills", "bond"],
    "bagItems": "lost_unless_warded",
    "nightChangesRate": false
  },
  "disconnect": { "holdSeconds": 180, "expiryResolvesAs": "defeat_without_mark" },
  "gather": {
    "holdSeconds": { "outside": 3, "fog": 4, "territory": 6, "heart": 9 },
    "heartYieldBonus": 1,
    "promptRange": 8,
    "respawnSeconds": 75,
    "payoutPerSlotPerExpedition": 1,
    "activeByPlayers": [
      { "minPlayers": 1, "outside": 6, "fog": 6, "territory": 6 },
      { "minPlayers": 2, "outside": 7, "fog": 7, "territory": 7 },
      { "minPlayers": 3, "outside": 8, "fog": 8, "territory": 8 }
    ],
    "slots": [
      { "id": "O1", "zone": "outside", "x": -120, "z": 110 },
      { "id": "O2", "zone": "outside", "x": -70, "z": 40 },
      { "id": "O3", "zone": "outside", "x": -60, "z": 100 },
      { "id": "O4", "zone": "outside", "x": 110, "z": 70 },
      { "id": "O5", "zone": "outside", "x": -150, "z": 20 },
      { "id": "O6", "zone": "outside", "x": -110, "z": -70 },
      { "id": "O7", "zone": "outside", "x": 40, "z": 110 },
      { "id": "O8", "zone": "outside", "x": -90, "z": -150 },
      { "id": "M1", "zone": "fog", "x": -30, "z": 10 },
      { "id": "M2", "zone": "fog", "x": 80, "z": -35 },
      { "id": "M3", "zone": "fog", "x": 115, "z": 10 },
      { "id": "M4", "zone": "fog", "x": 135, "z": 30 },
      { "id": "M5", "zone": "fog", "x": 110, "z": -130 },
      { "id": "M6", "zone": "fog", "x": 150, "z": -60 },
      { "id": "M7", "zone": "fog", "x": 20, "z": 15 },
      { "id": "M8", "zone": "fog", "x": 130, "z": -30 },
      { "id": "T1", "zone": "territory", "x": -15, "z": -60, "heart": true },
      { "id": "T2", "zone": "territory", "x": 25, "z": -100, "heart": true },
      { "id": "T3", "zone": "territory", "x": -45, "z": -75 },
      { "id": "T4", "zone": "territory", "x": 70, "z": -70 },
      { "id": "T5", "zone": "territory", "x": -20, "z": -145 },
      { "id": "T6", "zone": "territory", "x": 55, "z": -130, "heart": true },
      { "id": "T7", "zone": "territory", "x": -25, "z": -105 },
      { "id": "T8", "zone": "territory", "x": -40, "z": -125 }
    ]
  },
  "spawnWeights": {
    "outside": {
      "Day": { "fogbark": 85, "glowmoss": 15 },
      "Dusk": { "fogbark": 85, "glowmoss": 15 },
      "Night": { "fogbark": 85, "glowmoss": 15 },
      "Dawn": { "fogbark": 85, "glowmoss": 15 }
    },
    "fog": {
      "Day": { "fogbark": 55, "glowmoss": 45 },
      "Dusk": { "fogbark": 55, "glowmoss": 45 },
      "Night": { "fogbark": 45, "glowmoss": 40, "nightbloom": 15 },
      "Dawn": { "fogbark": 55, "glowmoss": 45 }
    },
    "territory": {
      "Day": { "fogbark": 40, "glowmoss": 60 },
      "Dusk": { "fogbark": 40, "glowmoss": 60 },
      "Night": { "fogbark": 25, "glowmoss": 40, "nightbloom": 35 },
      "Dawn": { "fogbark": 40, "glowmoss": 60 }
    }
  },
  "yields": {
    "outside": { "fogbark": [1, 2], "glowmoss": [1, 1] },
    "fog": { "fogbark": [2, 3], "glowmoss": [2, 2], "nightbloom": [1, 1] },
    "territory": { "fogbark": [2, 3], "glowmoss": [2, 2], "nightbloom": [1, 2] }
  },
  "earn": {
    "extractBaseEmber": 4,
    "baseRequires": { "minExpeditionSeconds": 45, "minDistanceFromCamp": 60, "minNewUnitsOrItems": 1 },
    "creatureEmberByTier": { "Safe": 6, "Fog": 8, "Territory": 14 },
    "eggEmberByTier": { "Territory": 10 },
    "firstExtractionSeal": 1
  },
  "recipes": {
    "seal": { "cost": { "fogbark": 8, "glowmoss": 4 } },
    "capsule": { "cost": { "fogbark": 8, "glowmoss": 5, "nightbloom": 1, "ember": 12 } },
    "totem": { "cost": { "glowmoss": 12, "nightbloom": 2, "ember": 20 } }
  },
  "upgrades": {
    "reinforcedPack": {
      "cost": { "fogbark": 60, "glowmoss": 30, "ember": 120 },
      "effects": { "bagItems": 4, "pouchUnits": 45, "lossBasisPoints": 2500 }
    }
  },
  "totem": {
    "wardsExtraItems": 1,
    "detectionBonusStuds": 6,
    "ambushAnchorWeightMultiplier": 2,
    "ambushAnchorRadius": 60,
    "maxActive": 1,
    "consumedWhen": "expedition_ends_after_leaving_camp"
  },
  "capsule": { "site": "shelter", "x": 105, "z": 125, "range": 12, "itemsSecured": 1 },
  "sinks": { "campRange": 20 },
  "skills": {
    "explorer_1": { "branch": "explorer", "tier": 1, "effectLive": true, "requires": [], "cost": { "ember": 40, "fogbark": 20, "glowmoss": 10 }, "effects": { "nodeHintRange": 60 } },
    "explorer_2": { "branch": "explorer", "tier": 2, "effectLive": true, "requires": ["explorer_1"], "cost": { "ember": 100, "fogbark": 30, "glowmoss": 20, "nightbloom": 3 }, "effects": { "nightbloomHintRange": 100 } },
    "capturer_1": { "branch": "capturer", "tier": 1, "effectLive": false, "requires": [], "cost": { "ember": 40, "fogbark": 20, "glowmoss": 10 }, "effects": { "calmRequired": 4.0 } },
    "capturer_2": { "branch": "capturer", "tier": 2, "effectLive": false, "requires": ["capturer_1"], "cost": { "ember": 100, "fogbark": 30, "glowmoss": 20, "nightbloom": 3 }, "effects": { "retryCooldown": 3 } },
    "survivor_1": { "branch": "survivor", "tier": 1, "effectLive": true, "requires": [], "cost": { "ember": 40, "fogbark": 20, "glowmoss": 10 }, "effects": { "carrySpeedBonus": 1 } },
    "survivor_2": { "branch": "survivor", "tier": 2, "effectLive": false, "requires": ["survivor_1"], "cost": { "ember": 100, "fogbark": 30, "glowmoss": 20, "nightbloom": 3 }, "effects": { "restSeconds": 2 } },
    "occultist_1": { "branch": "occultist", "tier": 1, "effectLive": false, "requires": [], "cost": { "ember": 40, "fogbark": 20, "glowmoss": 10 }, "effects": { "relocationNotice": true } },
    "occultist_2": { "branch": "occultist", "tier": 2, "effectLive": false, "requires": ["occultist_1"], "cost": { "ember": 100, "fogbark": 30, "glowmoss": 20, "nightbloom": 3 }, "effects": { "flashlightRevealSeconds": 5 } }
  },
  "bond": {
    "levelThresholdsXp": [0, 40, 100, 180, 280],
    "events": {
      "pulseRevealInFog": { "xp": 5, "maxPerExpedition": 4 },
      "extractWithCompanion": { "xp": 10, "maxPerExpedition": 1 },
      "pulseThenDodge": { "xp": 5, "windowSeconds": 10, "maxPerExpedition": 2 }
    },
    "maxXpPerExpedition": 40,
    "bankedOn": "extraction",
    "levelEffects": { "2": { "pulseCueStronger": true }, "3": { "pulseCooldown": 27 }, "4": { "glowCosmetic": true }, "5": { "pulseCooldown": 25 } }
  },
  "antiAfk": {
    "timeBasedGrants": 0,
    "idleHourExpectedDelta": 0,
    "rewardRequiresServerObservedAction": true,
    "bondBanksOnlyOnExtraction": true
  },
  "simulatorInputs": {
    "campSeconds": 30,
    "evadeSeconds": 8,
    "valueWeights": { "fogbark": 1, "glowmoss": 2, "nightbloom": 15 },
    "archetypes": {
      "cautious": { "zones": { "outside": 8, "fog": 8, "territory": 0 }, "captureTier": "Fog", "capturesMax": 4, "captureRate": 0.7, "eggRate": 0, "defeatChance": 0.01, "holdThroughWarning": 0, "riskAversion": 3, "dropRecovery": 0.8 },
      "balanced": { "zones": { "outside": 3, "fog": 5, "territory": 8 }, "captureTier": "Territory", "capturesMax": 3, "captureRate": 0.7, "eggRate": 0.6, "defeatChance": 0.02, "holdThroughWarning": 0.3, "riskAversion": 1, "dropRecovery": 0.6 },
      "greedy": { "zones": { "outside": 0, "fog": 8, "territory": 8 }, "captureTier": "Territory", "capturesMax": 4, "captureRate": 0.8, "eggRate": 1.0, "defeatChance": 0.02, "holdThroughWarning": 0.7, "riskAversion": 0.25, "dropRecovery": 0.5 }
    }
  }
}
```

**Invariants the simulator must assert:** every weight table sums above 0 and normalizes to 1. Night-only materials appear only in `Night` tables. Phases sum to `cycle.seconds`. Rounding examples above hold. Every slot's `zone` matches the rule, and none sits in a safe circle or outside the 400 x 400 map. Tier 2 skills list a tier 1 prerequisite. A Ward Seal is affordable from `outside` and `fog` materials. Standing-still calm stays below every `calmRequired`. Every load step stays above Silueta's fastest speed. Holds grow outside, fog, territory, heart. Active counts never exceed a zone's slots. Heart slots sit in territory.

## Changes to existing behavior

| Change | Existing | New |
| --- | --- | --- |
| Cycle | 1200 s, starts at Day | 720 s, random non-Night start |
| Night rewards | False | True, Nightbloom only |
| Extraction | Rejects with no bag items | Also takes materials, pays Ember |
| Seal | `sealCharges`, once, near camp | `consumables.seal`, crafted, anywhere, armable. First-extraction grant adds |
| Defeat | Pending only | Plus dropped, half of carried materials, totem, pending XP, summary |
| Pending items | Eggs and creatures | Also Nightbloom bundles |
| Walk speed | Eggs only, once M3.5 lands | Slower of eggs and pouch load |
| Capacity | Constant 3 | Per player |
| Shelter | Never banks | One item, with a capsule |
| Detection | Same for all | +6 with totem |
| Leaving | Profile gone at once | 180 s hold, in M6.5 |

## Test matrix

**Pure contracts, RED first (M5.2, M5.5, M5.6).**

| ID | Case | Expected |
| --- | --- | --- |
| ECO-01 | `lost` table above, both rates | Exact, integers |
| ECO-02 | Defeat with 100 Fogbark, 3 items, no ward | 50 kept, items gone, Ember same |
| ECO-03 | Same operation ID twice | One loss |
| ECO-04 | Defeat keeps banked, Ember, registered, banked eggs, skills, upgrades, bond | Unchanged |
| ECO-05 | Seal: spent only when it saves; extraction clears free | Existing contract still passes |
| ECO-06 | Armed seal: next item warded; no item, not spent | |
| ECO-07 | First extraction with crafted seals held | Adds 1, no overwrite |
| ECO-08 | Seal and totem together on defeat | Two survive, one seal spent, totem spent |
| ECO-09 | Totem: disarm before leaving refunds; after leaving refused; reconnect does not refresh | |
| ECO-10 | Capsule in and out of range; twice; on an egg and a creature | One item banks, Ember once |
| ECO-11 | Craft with exact cost, one short, at limit, away from camp, dead | Atomic. On refusal, nothing changes |
| ECO-12 | Unknown recipe, skill, non-string, 129 bytes | Dropped |
| ECO-13 | Learn tier 2 before tier 1; twice | `NeedsPrerequisite`, `AlreadyOwned` |
| ECO-14 | Gather full pouch, partly full, repeat slot, two players racing | `PouchFull`, partial, `AlreadyGathered`, one owner |
| ECO-15 | Nightbloom at each phase and zone | Only per table |
| ECO-16 | Normalization over 100,000 draws with fixed seed | Within tolerance of table |
| ECO-17 | Ember tiers, materials-only trip, too-short trip | Exact payout |
| ECO-18 | Tier on the item survives a drop and reclaim | Same tier |
| ECO-19 | Bond: each event, caps, defeat clears pending, not equipped | |
| ECO-20 | AFK-1 to AFK-6 | As stated |
| ECO-21 | Hold: return at 179 s, expire at 181 s, expiry equals defeat result | |
| ECO-22 | Cycle: boundaries at 720 s scale; offset never starts in Night, over many draws | |
| ECO-23 | Nightbloom bundle: takes a slot, `BackpackFull` when none, banks as material, pays no Ember, lost on defeat, saved by a seal, drops to a strike | |
| ECO-24 | `carrySpeed` for every pouch step, egg count and skill | Slower of the two, always above 8 |
| ECO-25 | Hold per band; heart yield bonus; moving during a hold | Exact hold; bonus once; hold cancelled, node not claimed |

**Studio and people.**

| ID | Case | Pass |
| --- | --- | --- |
| ECO-30 | Two-client race on nodes, extraction spam, double craft | No duplication; counts balance |
| ECO-31 | Natural 12-minute cycle, Nightbloom appears and wilts | Observed |
| ECO-32 | Phone: camp screen, Seal Newest, risk preview | Readable, muted, no overlap |
| ECO-33 | Exit question at F1: "what do you lose if you die?" | Proposed at least 70% correct (`docs/wildbound-roadmap.md:326`) |
| ECO-34 | F1 logs: expedition length, third expedition, purchases per trip | Reported. Agents never mark F1 passed |

## Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| Half of carried materials plus lost bag items is enough stake | Testers shrug at defeat. Or they stop going out |
| Bag and pouch limits force stay-or-return | Testers rarely reach either; or always leave at once with one item |
| Territory pay beats the safe route | Over 80% of captures at `L4` after the first. Or nobody survives territory |
| 12 minutes shows Night in a short session | Testers in a 20-minute session do not see a Night, or Night feels too short to use |
| Nightbloom makes Night worth the danger | Under a quarter of players enter fog at Night once informed. Or Night trips pay so well that Day is ignored |
| A totem's cost is a real decision | Always bought, or never. Holder hunted-time equals non-holder's |
| A field seal matters | Sealed items rarely saved, or no one uses it with the bag at risk |
| Progress lasts several sessions with a goal in each | Testers cannot name a next goal, or reach everything in a few sessions |
| Bond is felt | Testers do not notice cooldown changes, or cooldown 25 s trivializes Silueta at 2 and 4 players (M7.4) |
| Expeditions land in 3 to 8 minutes | F1 median outside that range. The simulator lands at its low end, on straight lines with no detours |
| Long holds read as tension, not waiting | "I just stood there" at heart slots, or complaints about 3 s holds outside |

## Unverified

| Item | Settle in |
| --- | --- |
| Whether a mid-trip Nightbloom wilt reads as fair | F1 |
| Whether `ProximityPrompt` holds of 3 to 9 s feel acceptable on touch | M5.8 |
| Whether ten new slot coordinates are reachable and read well | M5.3 |
| Proposed ambush anchors behave as averaged here | M4.7 |
| Replication cost of a larger snapshot on each reply, at phone level | M9.1 |
| Place max players, which bounds the active-slot table | M7.1 |
