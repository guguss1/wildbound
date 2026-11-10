# Economy concept: skill tree first (the tree is the spine, equipment multiplies it, totems bend one roll)

**Status: design only, unvalidated. Nothing here is built, priced in Creator Hub, played, or run through `tools/simulate_economy.py`.** Written 2026-11-09 for the user's direction of that day: one open world with a permanent safe hub in the centre (incubator, corral, trophies, shop and skill tree), La Silueta's forest to the west and a bright biome for kids to the east, joined side by side; creatures earn Esencia for their owner; Esencia buys the skill tree and upgrades; equipment items and totems are the faster advantages; the free path always exists but grows progressively more expensive; Robux offers shorten it in the Steal-an-Egg manner, as a strong, honest incentive and never as a wall. Every number is a hypothesis for the tuning JSON and the simulator. Design and code in English; in-game names and player strings in neutral Spanish.

**No purchase is implemented or authorized by this document.** `monetization` stays `"none"` in the tuning JSON until the user sets up Creator Hub, `MarketplaceService.ProcessReceipt` and saved progress; DataStore is currently forbidden, so nothing permanent can be sold yet (section 9). Robux prices are placeholders to discuss.

The angle of this concept: **the skill tree is the thing a player is building.** Four branches, five tiers each, costs that multiply by 2.5 per tier. Equipment pieces are multipliers on the branch they belong to, and their higher levels unlock only through that branch, so the tree stays the one ladder everything hangs from. Totems are consumables that bend one roll or one moment. Robux buys conveniences beside the tree (a pen, a piece at level I, a bigger bag, a second incubator slot) and **never a node of the tree**: the tree is the thing money cannot touch, which is what makes every other row easy to defend.

The sibling concepts `idle.md` (the corral as the engine) and `offers.md` (offer design first) share the corral rules and the policy rules below; where this document differs, section 10 says so and leaves the choice to the user.

## Quick path

| You are | Read |
| --- | --- |
| The user | Sections 1, 3 (the tree), 6 (offers), 7 (timelines) and 10 (decisions) |
| The simulator writer | Sections 2, 4, 5, 8 and the tuning block in 9 |
| A later Studio writer | Section 11 (code implications); nothing here authorizes code |

## 0. Facts this design rests on

| Fact | Source | Why it matters here |
| --- | --- | --- |
| Currency is Esencia in player text, `ember` in code; never lost on defeat; `purchasable = false` | `src/wildbound/WildboundEconomyConfig.luau:31`; `WildboundCampView.luau:23-24` | Section 2 keeps both flags; section 6 explains why "never purchasable" is load-bearing |
| Active income, simulated solo: 19.5 / 23.7 / 22.9 Esencia per trip of 208 / 203 / 190 s (cautious / balanced / greedy); greedy median must stay at or above 180 s | `docs/mechanics/wildbound-economy-p0.md:448-452`; `tools/simulate_economy.py` | About 6 Esencia per minute of session time once hub turnaround is added; every ladder below is measured against it |
| Skill tree today: 4 branches x 2 tiers; tier 1 costs 40 Esencia + 20 Fogbark + 10 Glowmoss, tier 2 costs 100 + 30 + 20 + 3 Nightbloom and needs tier 1; five effects are live, three tuned but not live | `WildboundEconomyConfig.luau:170-235`; `wildbound-economy-p0.md:372-387` | Section 3 keeps the eight existing nodes, their ids and their costs as tiers 1 and 2, and adds tiers 3 to 5 |
| Capture rule: `CALM_REQUIRED` 4.5 s, 4.0 with Steady Hands; the stationary maximum is about 3.6 s and the simulator fails any `calmRequired` at or below it | `docs/mechanics/wildbound-capture.md:53`; `simulate_economy.py` `stationary_calm_max`, `check_invariants` | Rules out gloves that fill the calm meter faster (section 5.1) |
| Sprint: pool 100, drain 25 per second (4 s), multiplier 1.45, cap 24; a rested sprint must outrun the fastest hunt (17 at Night) by 5 studs/s | `src/wildbound/WildboundStamina.luau:8-18`; `simulate_economy.py:67-88` | Botas change drain only; Aguante tier 3 changes the pool only; the cap and the margin never move |
| La Silueta: hunt 13 / 15 / 17, memory 4 / 5 / 6 s, chase leash 100, one hunter per player planned (F2) | `src/wildbound/WildboundTuningSchema.luau:42-61`; plan Part 2 | Amuleto and Ocultismo tier 4 scale memory, never speed or telegraph |
| Sinks today: Ward Seal, Last Breath Totem (20 Esencia + 12 Glowmoss + 2 Nightbloom; detection +6, ambush anchors x2), Extraction Capsule, Reinforced Pack (120 + 60 + 30), Farol tapado (10, starter) | `WildboundEconomyConfig.luau:138-167` | All kept; the Pack is the free path of the "Bolsa grande" offer |
| AFK contract: nothing grows from time alone; an idle hour changes nothing | `wildbound-economy-p0.md:409-422`; `WildboundEconomyConfig.luau:252-257` | Section 4 amends it narrowly and says so |
| Hub plan: Corral with 8 pens, Incubadora, Tablero, Árbol de habilidades kiosk, 5 trophy plinths, a Puesto marker with nothing for sale | `docs/design/wildbound-open-world-hub.md:39-50` | Where everything below is shown and bought |
| Pradera corral proposal: 0.5 / 1.0 / 2.0 / 4.0 Esencia per minute by rarity, 4 free pens, pens 5 to 8 at 60 / 150 / 350 / 800, fed first, 20-minute storage, collect by hold; Pradera skill nodes at 40 / 100 / 220 | `docs/design/wildbound-biome-pradera.md:269-299` | Adopted as the corral base and folded into the tree (section 3.4) |
| Rarity bands by distance to the beast's home: Común beyond 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria under 45; stored on the item at the steal | Plan W2; `wildbound-open-world-hub.md:139` | The corral rate keys on it |
| Roblox paid random items (eggs, chests, luck or pity modifiers bought with Robux or with a currency Robux can buy) need odds disclosure and `PolicyService` checks; rewards earned only by play do not | `docs/wildbound-roadmap.md:415` (read 2026-11-07) | Esencia is never sold and totems are never sold, so the luck totem stays a play-earned item |
| Everything is session-only; leaving discards the profile | `wildbound-economy-p0.md:159` | Nothing may be sold until progress persists |

## 1. The economy in one picture

| Loop | What the player does | What it yields | Where it goes |
| --- | --- | --- | --- |
| **Steal and extract** (active) | Leave the hub, steal crías and eggs, gather, come back alive | Esencia at extraction (as today), materials, the creature with its rarity | The Árbol first, then the Taller, the Corral and the Incubadora |
| **Corral income** (while you play) | Place a creature in a pen, feed it one material, go out again, collect on return | Esencia per minute by rarity, stored up to 20 minutes, banked by a hold | The same stations |
| **Spend** | Tree nodes, equipment levels, totems, pens, incubator upgrades | Rules bent in your favour (tree), rates multiplied (equipment), one roll bent (totems), a bigger engine (pens) | Back into the first two loops |

The order a child learns it: the first steal pays the first node (40 Esencia, about 7 minutes); the first node makes the second trip better; the second trip pays the first piece; the piece multiplies what the node taught; the corral keeps paying while you go out for the next node. The ceiling is the same for everyone: 20 nodes, 4 pieces at level III, 8 pens, one incubator ladder. Robux buys *when*, never *what*, and never a node.

## 2. Currency, materials and rarity

| Thing | Rule |
| --- | --- |
| **Esencia** (`ember`) | Earned at extraction, at the corral and from three small capped sources. Never lost on defeat. **Never purchasable with Robux, alone or in any bundle.** One number on the Tablero |
| Materials, west | Fogbark, Glowmoss (pouch), Nightbloom (Night only, bag item), as today |
| Materials, east | Pelusa, Espora (pouch), Espora Brillante (rare, bag item) in the same three roles |
| Cross-side recipes | Every recipe asks for `common`, `uncommon` or `rare` and accepts either side's material, unit for unit. A forest player never needs the Pradera; a Pradera child never needs the forest. No ladder below needs a Night: the rare material has a day path on the east side and a fog-beyond-the-leash path on the west |
| Rarity on the item | Stored at the steal from the W2 band of the spawn. Today's island tiers map Safe and Fog to Común, FogFar to Rara, Territory to Épica, Heart to Legendaria. The PI-1 cría and every biome-event hatchling are Legendaria |
| Extraction payout | Unchanged (6 / 10 / 12 / 14 / 22 by risk tier, eggs 8 / 10 / 11 / 14, base 4, first steal 4), so the 180 s floor is untouched |
| Small sources | Wave board top 3: 5 / 3 / 2 per wave per player; beast beaten without a capture (flashlight stagger, "Cansarla"): 3 once per wave; first registration of a species: 10 once per species. All capped; none is a farm |

## 3. Loop 3, the spine: the skill tree

### 3.1 Shape and the cost formula

Four branches, five tiers each, twenty nodes. Tiers unlock in order inside a branch; branches are independent. No node is needed to finish any route, no node cancels a beast, lowers a telegraph under 0.8 s, reads camera or gaze, or affects another player.

```text
esencia(t) = round10(40 x 2.5^(t - 1))        t = 1..5, the tier inside a branch
materials(t): common 20 / 30 / 50 / 80 / 120, uncommon 10 / 20 / 30 / 50 / 80, rare 0 / 3 / 5 / 8 / 12
```

| Tier | Esencia | Materials (common, uncommon, rare) | Minutes to afford the Esencia alone at 6 / 9 / 12 per minute | Cumulative per branch |
| --- | ---: | --- | --- | ---: |
| 1 | 40 | 20, 10, 0 | 7 / 4 / 3 | 40 |
| 2 | 100 | 30, 20, 3 | 17 / 11 / 8 | 140 |
| 3 | 250 | 50, 30, 5 | 42 / 28 / 21 | 390 |
| 4 | 620 | 80, 50, 8 | 1 h 43 / 1 h 09 / 52 | 1,010 |
| 5 | 1,560 | 120, 80, 12 | 4 h 20 / 2 h 53 / 2 h 10 | 2,570 |

Whole tree: 10,280 Esencia. Tiers 1 and 2 are the eight nodes that exist today, with their ids and costs unchanged, so `WildboundEconomyConfig.luau` grows and nothing already built moves. Why 2.5: tier 1 is one trip, tier 2 one session, tier 3 one evening, tier 4 a week of sessions, tier 5 the long tail. A child always has a next node within reach; a tier-5 capstone is a goal, not a wall, because nothing below needs it. The tree has **no Robux row at all** (section 6.1 rule 3), so its ratio can be steep without ever looking like a sales curve.

### 3.2 The twenty nodes

Names are neutral Spanish player strings; ids keep the existing `explorer_`, `capturer_`, `survivor_`, `occultist_` prefixes so the config and the `Learn` action stay as they are. "Rule it must keep" is the contract the simulator or a Studio suite asserts.

**Rastreo** (`explorer_*`): finding things.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Olfato de senda (exists, Trail Sense) | Compass shows gather nodes within 60 studs | Capture slots stay unmarked |
| 2 | Nariz nocturna (exists, Night Nose) | Rare material shown within 100 studs (Nightbloom at Night; Espora Brillante inside her ground) | Night or beast ground only |
| 3 | Lectura del rastro | The compass tags egg and cría spawns within 80 studs with their rarity icon | Icon only; never the beast's position, never another player's |
| 4 | Brújula de ola | For 5 s after a wave starts, an arrow to the nearest Épica or better spawn | Arrow only, once per wave; the spawn itself is unchanged and shared |
| 5 | Instinto de refugio | The nearest active Refugio is always marked on the compass | Refugios are shared and already visible; this is distance information |

**Captura** (`capturer_*`): stealing cleanly.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Manos firmes (exists, Steady Hands) | `calmRequired` 4.5 to 4.0 | Stationary maximum (about 3.6) stays below it |
| 2 | Paso suave (exists, Soft Approach) | Retry cooldown 6 to 3 s | Others' reservation unchanged |
| 3 | Anillo amplio | Server ring radius 5.0 to 5.5 | **Simulator gate:** `stationary_calm_max` with radius 5.5 must stay below 4.0; if it does not, the node becomes "ring shown 0.2 s earlier", as the Pradera's "Ojo de sol" |
| 4 | Segunda intención | Once per encounter, a failed capture adds nothing to the parents' wake meter | Parents still wake from light and noise; the fair strike is untouched |
| 5 | Abrazo firme | You may sprint 2 s with a carried cría before it slips (today it slips at once) | `carrySpeed > 8`; the chase still catches a tired sprinter |

**Aguante** (`survivor_*`): lasting longer.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Carga ligera (exists, Light Load) | Egg walk speed +1, cap 16 | `carrySpeed > 8` |
| 2 | Descanso rápido (exists, Quick Rest) | Mark clears in 2 s instead of 5 | Safe zone only |
| 3 | Pulmones | Sprint pool 100 to 120 | Speed cap 24 and the 5 studs/s escape margin unchanged; the 12 / 15 / 18 s chase limit still ends a chase |
| 4 | Piel dura | Defeat loss 20 % to 15 % (1,500 basis points; 750 with the Reinforced Pack) | Integer rounding rule unchanged; bag items still lost unless warded |
| 5 | Segundo aliento | Once per expedition, when your mark clears, stamina refills | Never during a chase; never prevents a strike |

**Ocultismo** (`occultist_*`): reading the dark and shaping totems.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Leer las señales (exists, Read the Signs) | "Algo se movió en la niebla" 5 s after an ambush move, no location | No camera or gaze input |
| 2 | Luz larga (exists, Long Reveal) | Flashlight reveal 5 s instead of 4 | Overlaps take the max |
| 3 | Tallador | Every totem recipe needs one rare material less (never below 1) | Totem effects unchanged; Esencia cost unchanged |
| 4 | Sombra | Beast memory of you x0.75; hide-spot entry 0.5 s faster | Memory per hunter and per quarry; telegraph untouched; stacks multiplicatively with Amuleto, floor 2 s |
| 5 | Pacto | Bond XP cap per expedition 40 to 60; pulse cooldown -2 s (floor 23) | XP still banks only at extraction |

### 3.3 Why the tree first

A tier-1 node costs 40 and changes a rule for the rest of the session: that is the cheapest, most legible progress in the game and the reason to walk back to the hub. The branches name the four things the game asks of a child (find, steal, last, read), so the tree is also the tutorial of what the game is about. And because the tree is never sold, every other sale is easy to read beside it: "you may buy the gloves sooner; you cannot buy being better at the game."

### 3.4 The Pradera nodes

The Pradera document's three nodes ("Pies de nube", "Ojo de sol", "Bolsillo de espora") become east-side variants rather than a fifth branch: `survivor_1` grants +1 walk speed with an egg on the west **and** "Pies de nube" (walk 17 in the Pradera, she stays 14) on the east; `capturer_3` becomes "Ojo de sol" if the ring-radius gate fails; `survivor_3` grants "Bolsillo de espora" (bag +1 in the Pradera) beside the sprint pool. One tree for both sides, so a child never sees two trees.

## 4. Loop 2: the corral

Adopted from the Pradera synthesis and the idle concept so the three documents agree; restated so this one stands alone.

| Rule | Decision |
| --- | --- |
| Who produces | Only creatures placed in the owner's pens at the hub Corral; the camp and the outpost have no pens |
| Pens | 4 free; pens 5 to 8 at 60 / 150 / 350 / 800 Esencia |
| Fed first | Hold "Dar de comer" with one common or uncommon material to open a 20-minute window per creature. One gathered material, one server-observed action, one window |
| Storage | At most 20 minutes of output per creature ("Lleno"). Nothing is credited until the owner holds "Recoger Esencia" (1.5 s) at the pen |
| When | Only while the owner is in the server and alive. **Nothing accrues offline.** When saved progress exists, only the stored, uncollected output (at most 20 minutes' worth) survives to the next session |
| Rates | Común 0.5, Rara 1.0, Épica 2.0, Legendaria 4.0 Esencia per minute |
| Duplicates | Second creature of the same species and rarity earns half; third and later a quarter |
| **Cap** | The corral never pays more than **1.0 Esencia per minute per owned pen** (4 pens: 4, 8 pens: 8). This differs from `idle.md` (flat 12): the cap grows with the pen ladder so every pen is worth buying, and a 4-pen corral stays under the active rate |
| Trophies | Never pay Esencia |
| Display | Every pen shows the creature hovering, its owner and its rate; the plaque says "Lleno" when storage is full |

Why this is still "no AFK" in spirit: a window starts only from a gathered material, output is capped, and nothing banks without a hold. It does amend AFK-1 and AFK-2 as written (a fed creature's `stored` value grows for 20 minutes), and section 11 names the test that changes.

## 5. Loop 3, the rest: equipment, totems, pens, incubator

### 5.1 Equipment pieces: multipliers hung on the tree

Four pieces, one of each, worn until removed, three levels. **A piece multiplies a rate on the branch it belongs to; it never changes a rule.** Level I is bought on the equipment ladder below. Level II of a piece requires **tier 3 of its branch**, level III requires **tier 5**, so the multipliers only ever amplify what the tree taught, and since the tree is not sold, levels II and III cannot be bought with Robux by construction.

| Piece (player name) | Branch | Level I | Level II (needs tier 3) | Level III (needs tier 5) | Rule it must keep |
| --- | --- | --- | --- | --- | --- |
| **Guantes de ladrón** | Captura | Parents' wake input (light and noise) while you hold a capture x0.8 | x0.7 | x0.6, and retry cooldown -1 s (floor 2) | Does **not** touch the calm meter. A calm-fill multiplier was ruled out: 4.0 / 1.2 = 3.33 s is under the 3.6 s stationary maximum, so standing still would capture. The plan's "+30 % calm" cannot be built as written |
| **Botas ligeras** | Rastreo | Sprint drain x0.8 (5 s of sprint) | x0.7 (5.7 s) | x0.6 (6.7 s) | Speed cap 24 and the 5 studs/s margin unchanged; the chase limit still ends a chase |
| **Chaleco acolchado** | Aguante | Once per expedition, the strike that would defeat you marks you instead and drops the newest bag item | Also material loss on that expedition's defeat x0.75 | x0.5 | Telegraph, dwell gate and strike untouched; a second such strike defeats as usual |
| **Amuleto de calma** | Ocultismo | Heartbeat and fear vignette muted; beast memory of you x0.75 | x0.5 | x0.5, and Refugio stamina regen x3 instead of x2 | Memory floor 2 s after every multiplier; telegraph untouched |

Items never affect another player: hunters are per player (F2) and there is no player-versus-player surface.

### 5.2 The equipment ladder: the geometric free path and its 10-step table

Every equipment level, any piece, any order, is one step on **one ladder**:

```text
cost(n) = round5(60 x 1.5^(n - 1))        n = 1..12, the number of equipment levels you already own plus one
```

plus materials by level (I: 20 common + 10 uncommon; II: 40 + 20 + 2 rare; III: 60 + 40 + 5 rare). The rule a child can repeat: "cada mejora de equipo cuesta más que la anterior." Minutes assume Esencia alone at three total incomes (6 per minute is a free player in session 1, 9 a free player with six fed pens, 12 a mature corral plus active play):

| Step | Cost | Cumulative | At 6 / min | At 9 / min | At 12 / min | What it is for a player who buys level I of all four first |
| ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | 60 | 60 | 10 min | 7 min | 5 min | Guantes I, first session |
| 2 | 90 | 150 | 15 min | 10 min | 8 min | Botas I, second session |
| 3 | 135 | 285 | 23 min | 15 min | 11 min | Chaleco I |
| 4 | 200 | 485 | 33 min | 22 min | 17 min | Amuleto I. **First step at which a Robux offer may appear** (section 6) |
| 5 | 305 | 790 | 51 min | 34 min | 25 min | Guantes II (needs Captura tier 3) |
| 6 | 455 | 1,245 | 1 h 16 | 51 min | 38 min | Botas II (Rastreo tier 3) |
| 7 | 685 | 1,930 | 1 h 54 | 1 h 16 | 57 min | Chaleco II (Aguante tier 3) |
| 8 | 1,025 | 2,955 | 2 h 51 | 1 h 54 | 1 h 25 | Amuleto II (Ocultismo tier 3) |
| 9 | 1,540 | 4,495 | 4 h 17 | 2 h 51 | 2 h 08 | Guantes III (Captura tier 5) |
| 10 | 2,305 | 6,800 | 6 h 24 | 4 h 16 | 3 h 12 | Botas III (Rastreo tier 5) |
| 11, 12 | 3,460; 5,190 | 15,450 | 9 h 36; 14 h 25 | | | Chaleco III, Amuleto III: the long tail, gated by tier 5 anyway |

Why 1.5 and not 2.5: the tree's ratio can be steep because the tree has five steps and no sale; the equipment ladder has twelve steps and one sold rung, so it must stay climbable. The table shows the shape the user asked for: steps 1 to 4 fit in the first hour, step 5 is "a session of saving", and from step 6 a flat 79-Robux price beside a 455-Esencia step is a fair question rather than a nag. Steps 9 to 12 are gated by tier 5 of the branch, which no one reaches in the first evening, so the ladder never reads as a wall in the window where the offer exists.

**Robux and the ladder.** A piece bought for Robux fills the step the player is on, exactly as if it had been paid with Esencia: the ladder is a function of levels owned, never of how they were paid, so paying never changes the price a free player sees, and the paying player's later free steps are the same steps everyone climbs (simulator check K5). The flat Robux price against the rising step is the whole incentive, which is why the offer is shown only from step 4 (200 Esencia): below that the free step is minutes away and selling it would be dishonest.

### 5.3 Totems: consumables that bend one roll

Crafted at the hub Taller or the forest camp, hold 1 each, one active per player, **never sold** (section 6.1 rule 4). Ocultismo tier 3 (Tallador) takes one rare material off each recipe.

| Totem | Cost (Esencia + common / uncommon / rare) | Effect | Downside | Why it stays crafted |
| --- | --- | --- | --- | --- |
| **Tótem del último aliento** (exists) | 20 + 0 / 12 / 2 | Wards one extra item on defeat | Detection +6 studs; ambush anchors x2 within 60 | As today |
| **Tótem de la suerte** (plan I2) | 20 + 0 / 12 / 2 | Placed, 60 s, radius 40: the next egg or cría spawn inside rolls one rarity tier up | Hums: noise as a landing (90-stud radius), so the beast hears it | A luck modifier on a random roll; sold for Robux it would be a paid random item needing odds disclosure |
| **Tótem de eco** (new) | 15 + 10 / 0 / 1 | Placed: the beast's next acquisition within 30 s prefers the totem's position for 4 s, once | Loud; it pulls her toward you, so it is a decoy, not a shield | Same rule; and it changes nothing about her speed, telegraph or strike |

### 5.4 Pens and incubator

| Upgrade | Free path | What it does | Sold for Robux |
| --- | --- | --- | --- |
| Pens 5 to 8 | 60 / 150 / 350 / 800 Esencia | One more producing, visible creature each; the corral cap rises by 1 per minute | Yes, from the 150 step (section 6) |
| Nido cálido I to III | 50 / 125 / 300 Esencia (ratio 2.5) | Hatch time x0.8 per level (90 s to 72 / 58 / 46; the 300 s event egg to 240 / 192 / 154). Never below half the base, so the biome event stays a shared beat | No |
| Segunda incubadora | 250 Esencia | Two eggs at once | Yes |
| Bolsa grande (Reinforced Pack) | 120 Esencia + 60 common + 30 uncommon, as today | Bag 4, pouch 45, loss 10 % | Yes |

## 6. Robux offers (design only, nothing implemented)

### 6.1 Rules every offer keeps

1. **Esencia is never sold**, alone or in a bundle. It keeps the luck totem and every random spawn outside the paid-random-items rules and keeps the Tablero honest.
2. **Every offer prints its free path and a time estimate** from the player's own income over the last 20 minutes: "O consíguelo jugando: ~45 min". Free line first and bigger.
3. **The tree is never sold.** No node, no tier skip, no respec token. Equipment levels II and III cannot be sold because they need tree tiers.
4. **Nothing random, no totems.** Deterministic items only.
5. **Same item, earlier.** Nothing sold is stronger, rarer or exclusive except cosmetics, which do nothing.
6. **Kids-safe surfacing.** No offer in the first 10 minutes of a first session; an offer appears once at the moment its free step becomes visible, with a plain "No, gracias"; at most one offer per 15 minutes; never while marked, chased, inside a beast's ground or on the defeat fade; no countdowns, no flashing, no strike-through prices, no character asking. Robux price on the button; Roblox's own purchase prompt is the only confirmation.
7. **Server-granted, idempotent, persisted.** `ProcessReceipt` grants on the server inside the same save transaction and records the `PurchaseId`; a grant that cannot be saved is not granted. `PolicyService.GetPolicyInfoForPlayerAsync` is read at join and gates the Puesto. None of this exists while DataStore is forbidden, so the Puesto stays a marker.
8. **A ceiling.** Everything purchasable adds up to about 500 Robux; beyond it only cosmetics exist.

### 6.2 The offers

Time saved is the free step's Esencia at the income a free player has when the offer appears (about 7 to 9 per minute after the first session). Prices are placeholders.

| Offer (player name) | What | When it appears | ~Robux | Free path | Time saved | Why it is honest and policy-safe for kids |
| --- | --- | --- | --- | --- | --- | --- |
| **Equipo del explorador** | One piece of the buyer's choice at level I, filling the current ladder step | The current equipment step costs 200 or more **and** a trigger moment: first failed capture (Guantes), first exhausted sprint (Botas), first marked hit (Chaleco), first ambush (Amuleto) | 79 | Step 4 onward: 200 / 305 / 455 / 685 Esencia + materials | 25 min / 40 min / 1 h / 1 h 30 | Identical to the crafted piece; levels II and III are earned by everyone through the tree; the offer never exists while the free step is minutes away |
| **Un corral más** | The next pen, whichever step | Pens full and the next step is 150 or more | 49 | 150 / 350 / 800 | 20 min / 45 min / 1 h 40 | The same pen; the cap rises the same way; a pen holds a creature the player already stole |
| **Bolsa grande** | The Reinforced Pack | First "Bolsa llena" or "Zurrón lleno" notice after minute 10 | 99 | 120 Esencia + 60 common + 30 uncommon | About 35 min | The same pack the P0 economy already sells for Esencia; loss 10 % is a comfort, not power over the beast |
| **Segunda incubadora** | A second incubator slot | First time a second egg is banked while one incubates | 79 | 250 Esencia | About 35 min | Convenience; hatch speed is never sold, and the event egg keeps its floor |
| **Cintas y sombreros** | Cosmetics for corral creatures and pen plaques; some ribbons are also earned by milestones | The corral tab, from the second session | 49 to 149 | Milestone ribbons | None | Cosmetic only, visible in the corral, which is the honest "show off" motive for kids |

Not offered, on purpose: Esencia packs; any tree node, tier or respec; any totem; any level II or III; hatch skips per use (impulse buys on a timer are the wrong habit for kids); a 2x income pass (a paid multiplier on the corral teaches not playing; `offers.md` proposes one and section 10 leaves it to the user); anything random; anything in the first ten minutes.

### 6.3 Where the incentive comes from

The free price of the next equipment level or pen rises by half or more at each step while the Robux price stays flat, so the shortcut's value grows with the player's investment in the game, not with frustration: at step 1 nobody should buy gloves and the game does not ask; at step 6 the 79-Robux gloves beside a 455-Esencia step are a fair, visible question. Meanwhile the tree, the thing the child is actually building, has no price tag at all, which is what lets a parent read the Puesto and see conveniences rather than a power shop.

## 7. Timelines

From a scratch model (6-minute cycles after a 2-minute first steal; 28 Esencia of active income per cycle, +2 with Guantes I, +1 with Botas I, +1 with Rastreo tier 1, +3 with the Pack; one creature home per cycle on the rarity script Común, Común, Rara, Común, Común, Rara, Común, Épica, Común, Rara, Común, Común, Rara, Legendaria at about 1:20, then Común, Común, Rara, Épica, Común, Rara; corral rates, duplicates and the per-pen cap of section 4; 3 rare materials every third cycle; a fixed purchase priority: Farol, Rastreo 1, Captura 1, equipment step, pen, Aguante 1, Captura 2, step, pen, Rastreo 2, step, Captura 3, Ocultismo 1, Nido I, Aguante 2, Rastreo 3, Segunda incubadora, pen, Aguante 3, Ocultismo 2). **These are arithmetic, not play, and the simulator's numbers replace them.**

### 7.1 Free player, first 20 minutes

| Time | What happens | Esencia in hand |
| --- | --- | --- |
| 0:00 | Spawns facing east; the gate sign and the meadow | 0 |
| 0:45 to 1:30 | Steals a Chispín (Común) at Prado de los Brotes, registers: 6 + 4 first steal + 4 base. Pen 1, "Dar de comer" with one Pelusa from a node on the way; the card says "Común: 0,5 de Esencia por minuto" | 14 |
| 2:00 | Farol tapado (10) | 4 |
| 2:00 to 8:00 | Cycle 2: a Musgón (Común), nodes. Collect 3 from the pen; +28 | 35 |
| 8:00 to 14:00 | Cycle 3: an Esponjín (Rara) under her shadow. Collect 6; +28. **Rastreo tier 1, Olfato de senda (40 + 20 Pelusa + 10 Espora)** at the Árbol | 29 |
| 14:00 to 20:00 | Cycle 4, first Night on the west or her ground on the east: 3 rare. Collect 6; +29. **Captura tier 1, Manos firmes (40)**. Pens 1 to 4 full at 20:00 | 27 |

Session 1 ends with two tier-1 nodes, four creatures producing 2.5 per minute, Farol, 3 rare materials and the first equipment step (Guantes I, 60) as the next visible goal, about 6 minutes away. Earned: 99 active, 18 corral. **No offer was shown**: none is eligible before minute 10 and no step reached its threshold.

### 7.2 Paying player, first 20 minutes

Identical to 7.1 except for one moment: at about 14:30 the bag fills for the first time after minute 10 ("Bolsa llena"), and the card shows the free line first ("Bolsa grande: 120 de Esencia + 60 Pelusa + 30 Espora, ~35 min") and under it "Bolsa grande, 99 Robux". If they buy, cycle 4 pays about 3 more and session 1 ends with the same two nodes, the Pack, and about 30 Esencia. Nothing else differs; the paying player's first session is the free player's first session.

### 7.3 Free player, two hours

| Time | Milestone | Earned so far (active + corral) |
| --- | --- | --- |
| 0:26 | Guantes I (step 1, 60) | 130 |
| 0:32 | Aguante tier 1 (40) | 160 |
| 0:38 | Pen 5 (60) | 190 + 63 |
| 0:50 | Botas I (step 2, 90) | |
| 1:02 | Chaleco I (step 3, 135) | 316 + 165 |
| 1:14 | **Captura tier 2, Paso suave** (100 + 3 rare): **session 4** with this priority; about 0:34, session 2, when saving for it | |
| 1:20 | Legendaria from the biome event egg hatched and placed | |
| 1:26 | Pen 6 (150) | |
| 1:38 | Rastreo tier 2 (100 + 3 rare) | |
| 1:56 | Amuleto I (step 4, 200): all four pieces at level I | |
| 2:00 | 6 pens at the cap of 6 per minute, 21 creatures in the collection, 5 nodes, 4 pieces, about 110 Esencia in hand | 636 + 501 = 1,137 (corral share 44 %) |
| 2:20 | Captura tier 3 (250 + 5 rare): the first tier 3 | |
| 2:50 | Guantes II (step 5, 305), unlocked by Captura 3 | |
| 3:20 | Rastreo tier 3; 3:44 Segunda incubadora; past 4:00 pen 7 and Aguante 3 | 1,276 + 1,221 at 4:00 |

### 7.4 Paying player, two hours (Bolsa grande at 0:14, pens 6 to 8 at 0:38 / 0:44 / 0:50, Amuleto I at 1:14: about 325 Robux)

| Time | Milestone | Earned so far |
| --- | --- | --- |
| 0:14 | Bolsa grande (Robux) | |
| 0:26 | Guantes I (60); 0:32 pen 5 (60, the 60 step is never sold) | |
| 0:38 to 0:50 | "Un corral más" three times as each pen fills: 8 pens, cap 8 per minute, fed by 0:50 (free: pen 6 at 1:26, pen 7 past 4:00) | |
| 0:56 | Captura tier 2: **18 minutes earlier than free** | |
| 1:14 | Amuleto I (Robux, step 4): the 200 Esencia goes to Rastreo tier 2 the same cycle | |
| 1:38 | Captura tier 3: 42 minutes earlier; 1:56 Guantes II: 54 minutes earlier | |
| 2:00 | Everything the free player has plus Captura 3, Ocultismo 1, Nido I, Aguante 2, Guantes II and two more pens; about 25 Esencia in hand | 698 + 646 = 1,344 (1.18 x free; corral share 48 %) |
| 2:26 | Rastreo tier 3; 2:44 Segunda incubadora; 3:02 Aguante tier 3 | 1,418 + 1,606 at 4:00 (1.21 x free) |

What the money bought: about **one hour of progress over the first three hours** (the free player reaches the payer's 2:00 state at about 3:00), a full corral from the first hour, the same tree at the same prices, and the same ceiling. The free player's two-hour income is 85 % of the payer's. If the simulator finds a gap much bigger than this, the ladders or the corral cap are wrong, not the offers; if much smaller, the pens are too cheap to sell honestly and "Un corral más" should start at the 350 step.

## 8. Numbers a simulator must check

`tools/simulate_economy.py` gains the `tree`, `equipment`, `corral` and `offers` inputs of section 9 (offers as income and purchase modifiers, never as purchases) and these assertions in the style of its `check_invariants`. Bracketed figures are this design's expectations from the scratch model; the simulator's numbers replace them.

| # | Check | Threshold |
| --- | --- | --- |
| K1 | Free balanced player reaches any tier-2 node | p50 within **4 sessions** of 20 minutes with the cheapest-first policy [1:14], within **2 sessions** when saving for it [0:34]; p90 within 5. The 3 rare materials reachable without a Night on the east and through fog beyond the leash on the west |
| K2 | Free balanced player reaches a tier-3 node | p50 within **3 hours** [2:20]; all four level-I pieces within **2 h 30** [1:56] |
| K3 | Paying player (Bolsa + 3 pens + 1 piece, about 325 Robux) against free, same archetype and seed, to the free player's 2-hour state | Saves **45 to 75 minutes** [about 60]; under 30 means the offers are weak, over 90 means the free path is too slow |
| K4 | Paying advantage is bounded | Esencia earned at 2 hours at most **1.3 x** free [1.18]; at 4 hours the free player owns every permanent item the payer owns except at most two pens and one equipment step |
| K5 | Paying never changes free prices | `cost(n)` depends only on levels or pens owned; the price sequence a free player meets is identical with and without any offer in the run |
| K6 | No offer is required to finish any loop; the tree is never sold | Every `offers` row has a non-null `freePath` and grants no skill id; a free balanced player owns tier 3 in every branch, all level-I pieces, 8 pens and the second incubator within **8 hours**; the whole tree and every level III within **60 hours** (reported as the long tail, not a target) |
| K7 | Corral share and cap | Corral at most **45 %** of total income at 2 hours for free [44 %], **50 %** for paying [48 %]; never above 1.0 per minute per pen; 8 identical Legendaria pay no more than 8 varied creatures |
| K8 | AFK bound | An idle hour at the hub with a fed corral credits at most 20 minutes x rate once; 0 with no feeding; 0 while dead or disconnected |
| K9 | Expedition floor | Greedy median at least **180 s** with Guantes III, Botas III, Captura 1 to 5 and Aguante 1 to 5 modelled; perturbation floor 150 s holds; greedy defeat rate with Chaleco stays above 10 % |
| K10 | Capture invariant | `stationary_calm_max` stays below `calmRequired` 4.0 with ring radius 5.5 (Anillo amplio); if not, the node is replaced as section 3.2 says. Guantes never touch the calm meter |
| K11 | Escape invariant | Sprint cap 24 and the 5 studs/s margin unchanged by Botas and Pulmones; a chase still ends within its limit against a sprinter with pool 120 and drain x0.6 |
| K12 | Ladders | Tree tiers strictly increasing with ratio 2.5; equipment steps with ratio in [1.4, 1.6]; pens 60 / 150 / 350 / 800; the equipment offer is never eligible below a 200 step; the pen offer never below a 150 step |
| K13 | Policy shape | No `offers` row has `random: true`; `currency.purchasable` is false; no row grants a tree node, a totem, or a level above I; `firstOfferMinute` at least 10; at most one offer per 15 minutes; total Robux of non-cosmetic rows at most 500 |
| K14 | Totems | Tallador never takes a rare cost below 1; every totem has `sold: false`; the luck totem's noise radius reaches the beast's detection range at its placement |
| K15 | First minute | First Esencia within 90 s and first producing creature within 2 minutes from both spawn directions |

## 9. Tuning block (proposal)

For a later `tools/simulate_economy.py` reader and `tools/export_economy_config_luau.py`. This is **not** the P0 `json economy-tuning` block and is read by no tool today; it is the shape a writer would merge into it. `monetization` stays `"none"` and `offers` are design rows, not products. Tiers 1 and 2 of each branch are the existing eight nodes and keep their costs.

```json economy-skills
{
  "schema": "wildbound.economy.skills",
  "schemaVersion": 1,
  "status": "hypothesis",
  "monetization": "none",
  "currency": { "id": "ember", "playerName": "Esencia", "lostOnDefeat": false, "purchasable": false },
  "materialRoles": {
    "common": ["fogbark", "pelusa"], "uncommon": ["glowmoss", "espora"], "rare": ["nightbloom", "esporaBrillante"],
    "crossSideUnitForUnit": true
  },
  "rarity": {
    "bandsByDistance": { "Legendaria": [0, 45], "Epica": [45, 80], "Rara": [80, 120], "Comun": [120, null] },
    "fromRiskTier": { "Safe": "Comun", "Fog": "Comun", "FogFar": "Rara", "Territory": "Epica", "Heart": "Legendaria" }
  },
  "tree": {
    "branches": { "explorer": "Rastreo", "capturer": "Captura", "survivor": "Aguante", "occultist": "Ocultismo" },
    "tiers": 5,
    "esenciaLadder": { "base": 40, "ratio": 2.5, "round": 10 },
    "esenciaByTier": [40, 100, 250, 620, 1560],
    "materialsByTier": { "common": [20, 30, 50, 80, 120], "uncommon": [10, 20, 30, 50, 80], "rare": [0, 3, 5, 8, 12] },
    "sold": false,
    "respec": false,
    "nodes": {
      "explorer_3": { "effects": { "spawnRarityIconRange": 80 } },
      "explorer_4": { "effects": { "waveArrowSeconds": 5, "waveArrowMinRarity": "Epica" } },
      "explorer_5": { "effects": { "nearestRefugioMarked": true } },
      "capturer_3": { "effects": { "ringRadiusServer": 5.5 }, "gate": "stationary_calm_max < calmRequired", "fallback": { "ringShownEarlierSeconds": 0.2 } },
      "capturer_4": { "effects": { "failedCaptureWakeFree": 1 } },
      "capturer_5": { "effects": { "sprintWithCriaSeconds": 2 } },
      "survivor_3": { "effects": { "sprintPool": 120, "praderaBagBonus": 1 } },
      "survivor_4": { "effects": { "lossBasisPoints": 1500, "lossBasisPointsReinforced": 750 } },
      "survivor_5": { "effects": { "staminaRefillOnMarkClear": 1 } },
      "occultist_3": { "effects": { "totemRareDiscount": 1, "totemRareFloor": 1 } },
      "occultist_4": { "effects": { "beastMemoryScale": 0.75, "hideEntryDelta": -0.5, "memoryFloorSeconds": 2 } },
      "occultist_5": { "effects": { "bondXpCap": 60, "pulseCooldownDelta": -2, "pulseCooldownFloor": 23 } }
    }
  },
  "equipment": {
    "ladder": { "base": 60, "ratio": 1.5, "round": 5, "steps": 12, "stepCounts": "levelsOwnedAnyPiece", "paidStepsCount": true },
    "costs": [60, 90, 135, 200, 305, 455, 685, 1025, 1540, 2305, 3460, 5190],
    "materialsByLevel": { "I": { "common": 20, "uncommon": 10 }, "II": { "common": 40, "uncommon": 20, "rare": 2 }, "III": { "common": 60, "uncommon": 40, "rare": 5 } },
    "levelGates": { "II": { "branchTier": 3 }, "III": { "branchTier": 5 } },
    "pieces": {
      "guantes": { "branch": "capturer", "I": { "captureWakeInputScale": 0.8 }, "II": { "captureWakeInputScale": 0.7 }, "III": { "captureWakeInputScale": 0.6, "retryCooldownDelta": -1, "retryCooldownFloor": 2 }, "calmMeter": "untouched" },
      "botas": { "branch": "explorer", "I": { "sprintDrainScale": 0.8 }, "II": { "sprintDrainScale": 0.7 }, "III": { "sprintDrainScale": 0.6 }, "speedCap": "untouched" },
      "chaleco": { "branch": "survivor", "I": { "markedHitsSurvived": 1 }, "II": { "defeatLossScale": 0.75 }, "III": { "defeatLossScale": 0.5 } },
      "amuleto": { "branch": "occultist", "I": { "fearMuted": true, "beastMemoryScale": 0.75 }, "II": { "beastMemoryScale": 0.5 }, "III": { "beastMemoryScale": 0.5, "refugioRegenScale": 3 }, "memoryFloorSeconds": 2 }
    },
    "soldLevels": ["I"]
  },
  "totems": {
    "ultimoAliento": { "cost": { "ember": 20, "uncommon": 12, "rare": 2 }, "sold": false },
    "suerte": { "cost": { "ember": 20, "uncommon": 12, "rare": 2 }, "seconds": 60, "radius": 40, "tierUp": 1, "noiseRadius": 90, "sold": false },
    "eco": { "cost": { "ember": 15, "common": 10, "rare": 1 }, "windowSeconds": 30, "decoySeconds": 4, "sold": false }
  },
  "corral": {
    "freeSlots": 4, "maxSlots": 8, "slotLadder": [60, 150, 350, 800],
    "ratePerMinute": { "Comun": 0.5, "Rara": 1.0, "Epica": 2.0, "Legendaria": 4.0 },
    "duplicateFactors": [1.0, 0.5, 0.25], "duplicateKey": "species_and_rarity",
    "capPerMinutePerSlot": 1.0,
    "feed": { "roles": ["common", "uncommon"], "units": 1, "windowMinutes": 20, "holdSeconds": 1 },
    "storageMinutes": 20, "collectHoldSeconds": 1.5,
    "accruesWhile": "owner_in_server_and_alive", "offline": "nothing_accrues; stored output survives once persistence exists",
    "trophiesPayEsencia": false
  },
  "incubator": { "nidoCalido": { "costs": [50, 125, 300], "hatchScalePerLevel": 0.8, "minHatchScale": 0.5 }, "secondSlot": 250, "hatchSkipsSold": false },
  "smallSources": { "waveBoardTop3": [5, 3, 2], "beastBeatenNoCapture": 3, "firstSpeciesRegistered": 10 },
  "offers": [
    { "id": "equipoExplorador", "grants": "oneEquipmentPieceLevelI", "robuxApprox": 79, "freePath": "equipment.ladder", "minFreeStepCost": 200, "random": false },
    { "id": "unCorralMas", "grants": "nextCorralSlot", "robuxApprox": 49, "freePath": "corral.slotLadder", "minFreeStepCost": 150, "random": false },
    { "id": "bolsaGrande", "grants": "reinforcedPack", "robuxApprox": 99, "freePath": "upgrades.reinforcedPack", "random": false },
    { "id": "segundaIncubadora", "grants": "incubatorSlot2", "robuxApprox": 79, "freePath": "incubator.secondSlot", "random": false },
    { "id": "cintasYSombreros", "grants": "cosmetic", "robuxApprox": [49, 149], "freePath": "milestoneRibbons", "random": false }
  ],
  "offerRules": { "firstOfferMinute": 10, "minMinutesBetweenOffers": 15, "countdowns": false, "showFreePathEstimate": true, "neverDuringDanger": true, "nonCosmeticCeilingRobux": 500 },
  "simulatorInputs": {
    "cycleMinutes": 6, "firstCycleMinutes": 2, "activeEsenciaPerCycle": 28,
    "activeBonusPerCycle": { "guantes1": 2, "botas1": 1, "explorer_1": 1, "reinforcedPack": 3 },
    "rarityScript": ["Comun", "Comun", "Rara", "Comun", "Comun", "Rara", "Comun", "Epica", "Comun", "Rara", "Comun", "Comun", "Rara", "Legendaria", "Comun", "Comun", "Rara", "Epica", "Comun", "Rara"],
    "rarePerThirdCycle": 3,
    "payingPurchases": [{ "minute": 14, "offer": "bolsaGrande" }, { "minute": 38, "offer": "unCorralMas" }, { "minute": 44, "offer": "unCorralMas" }, { "minute": 50, "offer": "unCorralMas" }, { "minute": 74, "offer": "equipoExplorador" }]
  }
}
```

## 10. Decisions for the user (one at a time, later)

| ID | Decision | Recommendation |
| --- | --- | --- |
| T1 | The tree is never sold, no node, no skip, no respec token | Yes; it is the rule that makes every offer easy to read |
| T2 | Five tiers per branch at 40 / 100 / 250 / 620 / 1,560 (ratio 2.5), the twenty nodes of 3.2 | Yes; tiers 1 and 2 are the eight nodes that exist; the simulator gates Anillo amplio |
| T3 | Equipment on one 12-step ladder (60 x 1.5^(n-1)); level II needs tier 3 of its branch, level III tier 5 | Yes; it is what makes equipment "multipliers hung on the tree" and keeps II and III unsellable by construction |
| T4 | Guantes do not touch the calm meter (the plan's +30 % calm cannot keep the stationary rule) | Yes; the wake-input multiplier is the honest replacement |
| T5 | Corral cap 1.0 per minute per pen instead of a flat 12 (`idle.md`) | Yes; it keeps every pen worth buying and a 4-pen corral under the active rate |
| T6 | Offers: the five rows of 6.2, about 500 Robux, no Esencia, no 2x pass, no hatch skips | Yes; `offers.md` proposes a 2x pass and per-use hatches, so this is a real fork for the user |
| T7 | Equipment offer only from a 200 step, pen offer only from a 150 step | Yes |
| T8 | Esencia never sold | Keep |

## 11. Code implications (not authorizations)

For a later writer, after the user's decisions and, for anything in section 6, after persistence exists.

| Where | What |
| --- | --- |
| `docs/mechanics/wildbound-economy-p0.md` tuning block, then `tools/export_economy_config_luau.py` | Twelve new skill rows with the existing shape (`branch`, `tier`, `effectLive`, `requires`, `cost`, `effects`); `effectLive = false` until each effect is wired, as the P0 tree did; equipment, totems, corral and incubator blocks; `monetization` stays `"none"` |
| `WildboundState` | `rarity` on pending and registered entries; `equipment = { guantes = 0, ... }`; `corral = { pens, fedUntil, stored }`; `Learn` keeps its refusals; new `Upgrade` ids for equipment levels with `NeedsBranchTier` |
| New `WildboundCorral.luau` (pure) | Rate by rarity, duplicates, per-pen cap, storage, feeding window, in-server rule; contracts for K7 and K8; the AFK-2 contract text amended to "an idle hour with no feeding changes nothing" |
| `WildboundWorldRules`, `WildboundStamina`, capture rule, fair strike | Multipliers read from the learner's own skills and equipment at the moment of use, as `capturer_1` is read today at capture start; every floor (`calmRequired` > stationary max, cap 24, memory floor 2, telegraph 0.8) asserted in the suites |
| `WildboundTuningSchema.luau` | Every new constant with a default equal to the module's value |
| `tools/simulate_economy.py` | The `tree`, `equipment`, `corral` and `offers` inputs; K1 to K15; a `--paying` policy; `check_invariants` keeps refusing any `monetization` other than `"none"` |
| HUD and camp views | Tree kiosk with four branches and five tiers phone-sized; pen plaques; the offer card with the free line first; strings in `WildboundText` |
| Nothing | `MarketplaceService`, `ProcessReceipt`, product ids, prices: not until Creator Hub, saved progress and the user's explicit approval exist |

## 12. Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| A child reads the tree as "what the game is about" and names a next node | Testers cannot say what a branch does, or never return to the kiosk after the first node |
| Equipment reads as "my gloves make my Captura better", not as a second shop | Testers buy a level-II piece and cannot say which branch unlocked it |
| 2.5 per tier reads as a goal, not a wall | Testers name tier 3 as the next goal; nobody complains about tier 5 |
| The flat Robux price beside a rising step reads as a shortcut | Testers who decline keep playing; a tester calls an offer "the only way" |
| "The tree is never sold" is noticed and trusted | A parent or tester asks whether skills can be bought, after reading the Puesto |
| The per-pen cap keeps pens worth buying without the corral beating play | Logs show the corral above 45 % of free income at 2 hours, or players stop buying pens at 6 |

## 13. Unverified

Everything: no number has met `tools/simulate_economy.py`, a child, a phone or a Studio build. The scratch model behind section 7 is straight arithmetic with a fixed rarity script, a fixed purchase order and no defeats after the first session; the Robux prices are placeholders; the Anillo amplio ring radius has not been checked against `stationary_calm_max`; the Roblox policy text was read through `docs/wildbound-roadmap.md:415` on 2026-11-07 and must be re-read before any product exists.
