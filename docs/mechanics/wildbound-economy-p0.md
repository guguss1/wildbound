# Wildbound P0 economy

Unit M5.1, wave W4a. Implements D5 and D10, and D4 and D14 where they touch rewards.

**Status: proposal. All numbers are hypotheses. Nothing here is built, balanced or tested with people.** Written 2026-11-07 without Studio. Everything stays session-only until M6. **No monetization: no Robux, no paid items, no `MarketplaceService`.** Ember cannot be bought.

## Choices worth your review

| # | Choice taken | Tradeoff |
| --- | --- | --- |
| 1 | **Calculated: D5's 3 to 8 minute expedition may not fit this map.** Walking all 14 gather nodes takes about 76 s plus 14 s of holds | Expect 2 to 4 minutes. I did not slow players or add filler to force it. F1 measures it; levers are listed below |
| 2 | Loss rounds to the **nearest** unit per stack, not down as the pack suggests | Floor would make any stack under 9 lose nothing, hiding the rule. Nearest makes stacks under 5 safe |
| 3 | Risk pays through Ember: a Lumipol from territory earns more than one from outside the leash | Without it the safe route wins, since all Lumipols are identical. Rewards bravery but widens progress gaps |
| 4 | After the D10 hold expires, the result equals a defeat. On return in time, you resume **where you left**, not at camp | Otherwise logging out teleports loot to the extraction point. Requires changing the respawn pivot |
| 5 | No release or sell for duplicates. Duplicates earn Ember once, at extraction | No way to delete a companion by mistake. Collection limit 100 stays unsolved until M6 |
| 6 | Tier 2 skills and advanced items need Nightbloom | A reason to go out at night. A day-only player cannot finish the tree |

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

Pack values used as hypotheses: 12%, totem hostile cost, reinforced pack 12 to 8%, capsule at shelter, four skill paths, bond 1 to 5 from active use (`resources/skill-packs/wildbound-codex-complete-v0.4.2/knowledge/wildbound/RISK_AND_PROTECTION.md:13-24`, `PROGRESSION.md:3-5`, `CREATURE_PROGRESSION.md:3-5`). Roblox random-item rule as read on 11-07: rewards earned only through play need no odds disclosure (`docs/wildbound-roadmap.md:415`). Recheck if that ever changes.

## The loop this creates

Leave camp. Gather and catch until the bag or pouch is full, or Silueta marks you, or Night tempts you to stay. Walk home slower if you carry eggs. Extract. Spend at camp. Go back better prepared, for something you could not reach before.

## Model

| Thing | Where it lives | At risk? |
| --- | --- | --- |
| **Bag items:** eggs, captured Lumipols | `pending`, 3 slots | Yes. Lost on defeat unless warded |
| **Carried materials:** Fogbark, Glowmoss, Nightbloom | `carried`, 30 units total | 12% per stack on defeat |
| **Banked materials** | `banked` | **Never** |
| **Ember**, the camp currency | `ember`, earned only at extraction | **Never** |
| **Registered companions**, banked eggs | Existing lists | **Never** |
| Crafted consumables | `consumables`, carried | Not lost; used up by their rules |
| Upgrades, skills, bond levels | Profile | **Never** |

Hatching stays free (`WildboundServer.server.luau:102`). Flashlight stays free.

```luau
-- Profile additions in WildboundState. All integers, all nonnegative.
carried = { fogbark = 0, glowmoss = 0, nightbloom = 0 }
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

expedition = { id = string, startedAt = number, leftCamp = boolean, maxDistanceFromCamp = number,
    territorySeconds = number, paidSlots = {}, pendingBondXp = 0, bondEvents = {}, newUnits = 0, newItems = 0 }
```

**Expedition boundaries.** Opens when an alive player crosses out of the camp safe circle (`WildboundWorldRules.luau:50`). Closes on extraction, defeat or hold expiry. Crossing back into camp without extracting keeps it open. There is no expedition state today.

## Loss rule on defeat

Applied once per defeat operation, inside `State:defeat`, with no yield. Integer arithmetic only, so no float error.

```text
lost(stack) = (quantity * rateBasisPoints + 5000) // 10000
rate = 1200, or 800 with the Reinforced Pack
```

| Stack | Lost at 12% | Lost at 8% |
| --- | --- | --- |
| 100 | 12 | 8 |
| 25 | 3 | 2 |
| 12 | 1 | 1 |
| 5 | 1 | 0 |
| 4 | 0 | 0 |
| 1 | 0 | 0 |

**Order, once per `operationId`:** 1. Warded items survive, spending one seal if seal-warded. 2. Other pending items go. 3. Dropped items go. 4. Each carried stack loses `lost(stack)`. 5. Totem spent if it left camp. 6. Pending bond XP goes. 7. Expedition closes. 8. Return loss summary (`wildbound-fair-strike.md`).

**Never lost, with a contract each:** Ember, banked materials, registered companions, banked eggs, upgrades, skills, bond. Night does not change the rate. Remaining carried materials stay carried and bank at the next extraction.

**Strike drop (D6):** first strike drops one bag item, never materials. See `wildbound-fair-strike.md`.

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
| Input | Prompt, 1.0 s hold, 8 studs. Server rechecks alive and distance, as `context()` does |
| Claim | One owner (D4). First valid trigger takes it, node disappears for all |
| Respawn | 75 s, at any inactive slot of the same zone |
| Per player | A slot pays one player once per expedition. Repeat: `AlreadyGathered`, node stays for others |
| Pouch | Takes what fits, wastes the rest, says so. No space at all: `PouchFull`, node not claimed |
| Night rule | Material is chosen when the node spawns, by the current phase table. Unclaimed Nightbloom wilts when Dawn starts. Carried Nightbloom keeps |
| IDs | Same as encounters: never reused, retired after use (`WildboundState.luau:78-84`) |

Slot coordinates are in the JSON below, checked against zones by script and against `forest-layout-v1.json`. Nodes are non-colliding, so tight spots are acceptable. Not verified in play.

**Zones** (by `WildboundWorldRules.zone` and `inTerritory`): `outside` is out of the fog rectangle, `fog` is in the rectangle but beyond Silueta's leash, `territory` is where it can target you.

## Night-only resource (D5)

**Nightbloom.** Spawns only at Night, only in `fog` and `territory`. It feeds totems, capsules and tier 2 skills. No new species or variant, because D5 chose one resource and the pack warns about false rarity. Turning this on means `nightRewardsEnabled = true` and rewording `WildboundWorld.server.luau:304`.

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
| Outside | 2 to 3 | 1 to 2 | |
| Fog | 3 to 4 | 2 | 1 |
| Territory | 4 to 5 | 2 to 3 | 1 to 2 |

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

Duplicates pay the same. This fixes B1, "duplicates are useless". Tier is stored on the item at capture and read at extraction, so nobody can upgrade it on the way home. **Changes existing behavior:** `extract` accepts materials-only trips; `Empty` now means no bag items and no carried units. Its first-extraction seal stays, but must add 1, not assign, so a crafted seal is not overwritten (`WildboundState.luau:123`).

## Sinks

All at camp, within 20 studs of `CampCenter`, alive, non-yielding: check, pay, grant.

| Item | Cost | What it does | Limit |
| --- | --- | --- | --- |
| **Ward Seal** | 8 Fogbark, 4 Glowmoss | Saves one chosen bag item on defeat. Spent only if it saves | Hold 3 |
| **Last Breath Totem** | 12 Glowmoss, 2 Nightbloom, 20 Ember | Wards one extra item with no seal. **Downside below** | Hold 1, one active |
| **Extraction Capsule** | 8 Fogbark, 5 Glowmoss, 1 Nightbloom, 12 Ember | Banks one bag item at the shelter, on the spot | Hold 1 |
| **Reinforced Pack** | 30 Fogbark, 15 Glowmoss, 40 Ember | Permanent. Bag 4, pouch 45, loss 8% | Once |
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

Used within 12 studs of a new `ShelterMarker` at (105, 125). Choose one bag item; it moves to banked eggs or registered, and pays its Ember now. No hatching. **Changes existing behavior:** the shelter gains one banking use (`docs/mechanics/wildbound-world.md:17`). Calculated distance: nest to shelter 235 studs, nest to camp 296.

## Skill tree

Four branches, two nodes each. Cost: tier 1 is 15 Ember and 4 Glowmoss. Tier 2 is 40 Ember, 6 Glowmoss and 2 Nightbloom, and needs tier 1. No respec in P0.

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

**Not measured, and says nothing about fun.** From a throwaway Monte Carlo run on the JSON below (400 runs of 60 trips, fixed seed), with invented archetype behavior, including defeat chances. The real simulator is `tools/simulate_economy.py`, not built here.

| Archetype | Nodes per trip, by zone | First skill | Reinforced Pack | All 8 skills | Ember per trip | Units per trip |
| --- | --- | --- | --- | --- | --- | --- |
| Cautious, Day only | 3 outside, 4 fog | Trip 2 | Trip 11 | Never, needs Nightbloom | 9.5 | 18.4 |
| Balanced | 1, 3, 3 | Trip 1 | Trip 6 | Trip 17 | 17.9 | 19.9 |
| Greedy | 0, 2, 6, mostly Night | Trip 2 | Trip 6 | Trip 13 | 21.4 | 21.8 |

**Time (calculated):** nearest-neighbor walks from camp, 16 studs/s, no danger or detours.

| Tour | Walk | Plus holds |
| --- | --- | --- |
| All 14 nodes | 1221 studs, 76 s | 90 s |
| Outside and fog, 8 nodes | 719 studs, 45 s | 53 s |
| Fog and territory, 10 nodes | 1119 studs, 70 s | 80 s |

Add 6 to 12 s per capture, slower walking with eggs, and evasion. A solo server has only 7 nodes active at a time. That points to about 2 to 4 minutes, **under D5's 3 to 8 at the low end**, and well under the pack's 5 to 10.

**If F1 logs show medians under 3 minutes**, in the order I would try: raise pouch and active node counts, add a second objective type per trip, widen the walkable distance with routes that leave the straight line, then extend the map. **Never** lower walk speed below `carrySpeed > 8` or add waits.

## Tuning tables

Stable schema for `tools/simulate_economy.py`, and later `WildboundEconomyConfig.luau`. Parse the block fenced as `json economy-tuning`. Bump `schemaVersion` on any breaking change. Costs are integers. `[a, b]` is an inclusive integer range. This block was parsed and run through the structural checks below on 11-07. `simulatorInputs` are assumptions, not game data.

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
    "fogbark": { "tier": "common", "nightOnly": false },
    "glowmoss": { "tier": "uncommon", "nightOnly": false },
    "nightbloom": { "tier": "rare", "nightOnly": true }
  },
  "currency": { "id": "ember", "lostOnDefeat": false, "purchasable": false },
  "capacity": {
    "bagItems": 3,
    "pouchUnits": 30,
    "collectionLimit": 100,
    "consumableCaps": { "seal": 3, "capsule": 1, "totem": 1 }
  },
  "loss": {
    "rateBasisPoints": 1200,
    "rateBasisPointsReinforced": 800,
    "rounding": "nearest_half_up_per_stack",
    "appliesTo": ["carried"],
    "neverLost": ["ember", "banked", "registered", "bankedEggs", "consumables", "upgrades", "skills", "bond"],
    "bagItems": "lost_unless_warded",
    "nightChangesRate": false
  },
  "disconnect": { "holdSeconds": 180, "expiryResolvesAs": "defeat_without_mark" },
  "gather": {
    "holdSeconds": 1.0,
    "promptRange": 8,
    "respawnSeconds": 75,
    "payoutPerSlotPerExpedition": 1,
    "activeByPlayers": [
      { "minPlayers": 1, "outside": 2, "fog": 2, "territory": 3 },
      { "minPlayers": 2, "outside": 3, "fog": 3, "territory": 4 },
      { "minPlayers": 3, "outside": 4, "fog": 4, "territory": 5 },
      { "minPlayers": 5, "outside": 4, "fog": 4, "territory": 6 }
    ],
    "slots": [
      { "id": "O1", "zone": "outside", "x": -120, "z": 110 },
      { "id": "O2", "zone": "outside", "x": -70, "z": 40 },
      { "id": "O3", "zone": "outside", "x": -60, "z": 100 },
      { "id": "O4", "zone": "outside", "x": 110, "z": 70 },
      { "id": "M1", "zone": "fog", "x": -30, "z": 10 },
      { "id": "M2", "zone": "fog", "x": 80, "z": -35 },
      { "id": "M3", "zone": "fog", "x": 115, "z": 10 },
      { "id": "M4", "zone": "fog", "x": 135, "z": 30 },
      { "id": "T1", "zone": "territory", "x": -15, "z": -60 },
      { "id": "T2", "zone": "territory", "x": 25, "z": -100 },
      { "id": "T3", "zone": "territory", "x": -45, "z": -75 },
      { "id": "T4", "zone": "territory", "x": 70, "z": -70 },
      { "id": "T5", "zone": "territory", "x": -20, "z": -145 },
      { "id": "T6", "zone": "territory", "x": 55, "z": -130 }
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
    "outside": { "fogbark": [2, 3], "glowmoss": [1, 2] },
    "fog": { "fogbark": [3, 4], "glowmoss": [2, 2], "nightbloom": [1, 1] },
    "territory": { "fogbark": [4, 5], "glowmoss": [2, 3], "nightbloom": [1, 2] }
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
      "cost": { "fogbark": 30, "glowmoss": 15, "ember": 40 },
      "effects": { "bagItems": 4, "pouchUnits": 45, "lossBasisPoints": 800 }
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
  "capsule": { "site": "shelter", "range": 12, "itemsSecured": 1 },
  "skills": {
    "explorer_1": { "branch": "explorer", "tier": 1, "requires": [], "cost": { "ember": 15, "glowmoss": 4 }, "effects": { "nodeHintRange": 60 } },
    "explorer_2": { "branch": "explorer", "tier": 2, "requires": ["explorer_1"], "cost": { "ember": 40, "glowmoss": 6, "nightbloom": 2 }, "effects": { "nightbloomHintRange": 100 } },
    "capturer_1": { "branch": "capturer", "tier": 1, "requires": [], "cost": { "ember": 15, "glowmoss": 4 }, "effects": { "calmRequired": 4.0 } },
    "capturer_2": { "branch": "capturer", "tier": 2, "requires": ["capturer_1"], "cost": { "ember": 40, "glowmoss": 6, "nightbloom": 2 }, "effects": { "retryCooldown": 3 } },
    "survivor_1": { "branch": "survivor", "tier": 1, "requires": [], "cost": { "ember": 15, "glowmoss": 4 }, "effects": { "carrySpeedBonus": 1 } },
    "survivor_2": { "branch": "survivor", "tier": 2, "requires": ["survivor_1"], "cost": { "ember": 40, "glowmoss": 6, "nightbloom": 2 }, "effects": { "restSeconds": 2 } },
    "occultist_1": { "branch": "occultist", "tier": 1, "requires": [], "cost": { "ember": 15, "glowmoss": 4 }, "effects": { "relocationNotice": true } },
    "occultist_2": { "branch": "occultist", "tier": 2, "requires": ["occultist_1"], "cost": { "ember": 40, "glowmoss": 6, "nightbloom": 2 }, "effects": { "flashlightRevealSeconds": 5 } }
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
    "archetypes": {
      "cautious": { "zones": { "outside": 3, "fog": 4, "territory": 0 }, "captureTier": "Fog", "captureRate": 0.7, "eggRate": 0, "defeatChance": 0.02, "nightShare": 0 },
      "balanced": { "zones": { "outside": 1, "fog": 3, "territory": 3 }, "captureTier": "Territory", "captureRate": 0.7, "eggRate": 0.5, "defeatChance": 0.12, "nightShare": 0.3 },
      "greedy": { "zones": { "outside": 0, "fog": 2, "territory": 6 }, "captureTier": "Territory", "captureRate": 0.8, "eggRate": 1.0, "defeatChance": 0.3, "nightShare": 0.8 }
    }
  }
}
```

**Invariants the simulator must assert:** every weight table sums above 0 and normalizes to 1. Night-only materials appear only in `Night` tables. Phases sum to `cycle.seconds`. Rounding examples above hold. Every slot's `zone` matches the rule, and none sits in a safe circle or outside the 400 x 400 map. Tier 2 skills list a tier 1 prerequisite. A Ward Seal is affordable from `outside` and `fog` materials. Standing-still calm stays below every `calmRequired`.

## Changes to existing behavior

| Change | Existing | New |
| --- | --- | --- |
| Cycle | 1200 s, starts at Day | 720 s, random non-Night start |
| Night rewards | False | True, Nightbloom only |
| Extraction | Rejects with no bag items | Also takes materials, pays Ember |
| Seal | `sealCharges`, once, near camp | `consumables.seal`, crafted, anywhere, armable. First-extraction grant adds |
| Defeat | Pending only | Plus dropped, materials, totem, pending XP, summary |
| Capacity | Constant 3 | Per player |
| Shelter | Never banks | One item, with a capsule |
| Detection | Same for all | +6 with totem |
| Leaving | Profile gone at once | 180 s hold, in M6.5 |

## Test matrix

**Pure contracts, RED first (M5.2, M5.5, M5.6).**

| ID | Case | Expected |
| --- | --- | --- |
| ECO-01 | `lost` table above, both rates | Exact, integers |
| ECO-02 | Defeat with 100 Fogbark, 3 items, no ward | 88 kept, items gone, Ember same |
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
| 12% carried loss plus lost bag items is enough stake | Testers shrug at defeat. Or they stop going out |
| Bag and pouch limits force stay-or-return | Testers rarely reach either; or always leave at once with one item |
| Territory pay beats the safe route | Over 80% of captures at `L4` after the first. Or nobody survives territory |
| 12 minutes shows Night in a short session | Testers in a 20-minute session do not see a Night, or Night feels too short to use |
| Nightbloom makes Night worth the danger | Under a quarter of players enter fog at Night once informed. Or Night trips pay so well that Day is ignored |
| A totem's cost is a real decision | Always bought, or never. Holder hunted-time equals non-holder's |
| A field seal matters | Sealed items rarely saved, or no one uses it with the bag at risk |
| Pack at about trip 6 feels reachable | Testers cannot name a next goal, or reach everything in one session |
| Bond is felt | Testers do not notice cooldown changes, or cooldown 25 s trivializes Silueta at 2 and 4 players (M7.4) |
| Expeditions land in 3 to 8 minutes | F1 median outside that range. Calculation above predicts risk at the low end |

## Unverified

| Item | Settle in |
| --- | --- |
| Whether a mid-trip Nightbloom wilt reads as fair | F1 |
| Whether `ProximityPrompt` 1.0 s hold on touch feels acceptable | M5.8 |
| Replication cost of a larger snapshot on each reply, at phone level | M9.1 |
| Place max players, which bounds the active-slot table | M7.1 |
