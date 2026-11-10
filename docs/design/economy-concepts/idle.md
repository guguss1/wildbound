# Economy concept: creature income first (the corral as an idle engine)

**Status: design only, unvalidated. Nothing here is built, priced in Creator Hub, played or simulated by `tools/simulate_economy.py` yet.** Written 2026-11-09 for the user's direction of that day: one open world with a permanent safe hub in the centre, La Silueta's forest to the west and the kids' Pradera to the east; creatures earn Esencia for their owner; Esencia buys the skill tree and upgrades; equipment and totems are the faster advantages; the free path always exists and grows more expensive; Robux offers shorten it in the Steal-an-Egg manner. Every number is a hypothesis for the tuning panel and the simulator. Design and code in English; in-game names and player strings in neutral Spanish. **No monetization is implemented or authorized by this document**: `monetization` stays `"none"` in the tuning JSON until the user sets up Creator Hub, `ProcessReceipt` and saved progress, and DataStore is currently forbidden.

The angle of this concept: the corral is the engine. Creatures you steal are not only trophies and companions; placed in your pens at the hub they produce Esencia while you keep playing, which is why a child wants the next, rarer creature, why a bigger corral is the first thing worth saving for, and why a flat Robux price next to a rising Esencia price reads as a shortcut rather than a wall.

## Quick path

| You are | Read |
| --- | --- |
| The user | Sections 1, 6 (offers) and 10 (decisions), then the timelines in 7 |
| The simulator writer | Sections 4, 5, 8 and the tuning block in 9 |
| The Studio writer (later, after approval) | Sections 3 to 5 and the code implications in 11; nothing here authorizes code |
| The Pradera or hub writer | Section 4 (what the corral shows) and `docs/design/wildbound-open-world-hub.md` section 2 |

## 0. Facts this design rests on

| Fact | Source | Why it matters here |
| --- | --- | --- |
| The currency is Esencia in player text, `ember` in code; never lost on defeat, never purchasable | `src/wildbound/WildboundEconomyConfig.luau:31`; `WildboundCampView.luau:23-24` | Section 2 keeps both flags; section 6 explains why "never purchasable" is load-bearing |
| Active income today: 19.5 / 23.7 / 22.9 Esencia per trip of 208 / 203 / 190 s for cautious / balanced / greedy, plus 30 s of camp time; greedy expedition median must stay at or above 180 s | `docs/mechanics/wildbound-economy-p0.md:448-452`; `tools/simulate_economy.py` | About 5 to 6 Esencia per minute of session time is the active rate every idle number is measured against |
| Payouts by risk tier: creature Safe 6, Fog 10, FogFar 12, Territory 14, Heart 22; egg 8 / 10 / 11 / 14; base trip 4; first steal bonus 4 | `WildboundEconomyConfig.luau:130-137` | Unchanged. The corral adds a second use for the same creature, not a second payout at extraction |
| Skill tree: 4 branches, tier 1 at 40 Esencia + 20 Fogbark + 10 Glowmoss; tier 2 at 100 + 30 + 20 + 3 Nightbloom | `WildboundEconomyConfig.luau:170-235` | Section 5 keeps these two tiers and adds a third |
| Reinforced Pack 120 Esencia + 60 Fogbark + 30 Glowmoss; totem 20 Esencia + 12 Glowmoss + 2 Nightbloom; seal and capsule recipes | `WildboundEconomyConfig.luau:138-159` | The free path for "Bolsa grande" already exists |
| AFK contract: no quantity grows from time alone; an idle hour changes nothing (AFK-1, AFK-2) | `wildbound-economy-p0.md:409-422` | Section 4 amends it deliberately and narrowly, and says so |
| Hub plan: Corral with 8 pens, Incubadora, Tablero de Esencia, Árbol de habilidades, 5 trophy plinths, a Puesto marker with nothing for sale | `docs/design/wildbound-open-world-hub.md:39-50` | Where every loop below is shown and bought |
| Pradera corral proposal: 0.5 / 0.5 / 1.0 / 2.0 / 4.0 Esencia per minute by species; 4 free slots, slots 5 to 8 at 60 / 150 / 350 / 800; fed first; 20-minute storage; collect by hold | `docs/design/wildbound-biome-pradera.md:269-282` | Adopted here as the base rates and the first ladder, so the two documents agree |
| Rarity bands by distance to the beast's home: Común beyond 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria under 45 | Plan W2; `wildbound-open-world-hub.md:139` | The corral rate keys on this rarity, recorded on the item at the steal |
| Hatch time 90 s today; the incubator document ruled out paying to speed a hatch, and the Pradera document reopens it as S5 | `docs/mechanics/wildbound-incubator.md:30`, `:34`; `wildbound-biome-pradera.md:362` | Section 6 recommends a second slot, not a speed-up |
| PI-1: a creature stolen from La Silueta pays a creature's normal Esencia; no new payout | `docs/design/wildbound-pi1-steal-from-silueta.md:60` | It becomes a Legendaria in the corral, which is reward enough |
| Roblox paid random items: eggs, chests, draws, mutations and **luck or pity modifiers** bought with Robux **or with a currency that can be bought with Robux** need full odds disclosure and `PolicyService` checks; rewards earned only by play do not | `resources/skill-packs/wildbound-codex-addon/knowledge/wildbound/ECONOMY_POLICY.md` (sources listed there, read 2026-11-07); `docs/wildbound-roadmap.md:415` | The reason Esencia is never sold: the luck totem is a luck modifier, and it stays a play-earned item only while nothing that buys it can be bought |
| Everything is session-only; leaving discards the profile | `wildbound-economy-p0.md:159` | Nothing may be sold until progress persists: a purchase that vanishes on leave is deception |

## 1. The economy in one picture

Three loops, one currency, one place to spend it.

| Loop | What the player does | What it yields | Where it is spent |
| --- | --- | --- | --- |
| **Steal and extract** (active) | Leave the hub, steal crías and eggs, gather materials, come back alive | Esencia at extraction (as today), materials, the creature itself with its rarity | The hub stations |
| **Corral income** (idle, online) | Place a registered creature in a pen, feed it one material, go out again, collect on return | Esencia per minute by rarity, stored up to 20 minutes, banked by a hold at the pen | The hub stations |
| **Spend** | Skill tree, equipment pieces, totems, corral slots, incubator upgrades, Nivel de criador | Faster steals, safer trips, a bigger engine | Back into the first two loops |

The flow: the active loop seeds the corral (a creature per trip), the corral pays for the ladders (a third of income at two hours, never more than half), and the ladders make the active loop pay more (rarer creatures, which make the corral pay more). The ceiling is the same for everyone: 8 pens, 4 equipment pieces, 3 skill tiers, 10 breeder levels. Robux buys when, never what.

## 2. Currency, materials and rarity

| Thing | Rule |
| --- | --- |
| **Esencia** (`ember`) | Earned at extraction, at the corral, and from three small sources below. Never lost on defeat. **Never purchasable with Robux, directly or through any bundle.** No second currency: one number on the Tablero |
| Materials, west | Fogbark, Glowmoss (pouch), Nightbloom (Night only, bag item), as today |
| Materials, east | Pelusa, Espora (pouch), Espora Brillante (rare, from the Pradera's rings and her ground), in the same roles; the Pradera planner sets slots and weights |
| Cross-side recipes | Any recipe that asks for a rare material accepts **either** Nightbloom or Espora Brillante, unit for unit. A child who never enters the forest can finish every ladder; a forest player never needs the Pradera |
| Rarity on the item | At the steal the server stores `rarity` from the W2 band of the spawn (Común, Rara, Épica, Legendaria). Today's island tiers map Safe and Fog to Común, FogFar to Rara, Territory to Épica, Heart to Legendaria. The PI-1 cría and every biome-event hatchling are Legendaria |
| Extraction payout | Unchanged: by risk tier, so the 180 s floor is untouched. Duplicates pay the same (P0 choice 12) |
| Small Esencia sources | Wave board top 3: 5 / 3 / 2 per wave, once per wave per player. Beating a beast without a capture (La Nube's "Cansarla", a Silueta flashlight stagger): 3, once per wave. First registration of a species: 10, once per species per session. None of these is a farm: all are capped per wave or per species |

## 3. Loop 1: steal and extract, what changes in the open world

Nothing in the P0 loss, carry or payout rules changes. What changes is geometry and bookkeeping.

| Change | Detail |
| --- | --- |
| Trips start and end at the hub | Hub gate to Prado de los Brotes 67 studs, to Claro del Umbral 81 studs, to the forest shelter 186 studs, to the Pradera outpost 300 studs (`wildbound-open-world-hub.md:29`). A median cycle (out, steal, back, register, feed, collect, spend) is **about 6 minutes**: the 3 to 4 minute trip plus hub time. The timelines below use 6 |
| Hub time is not dead time | The corral visit (collect 1.5 s hold, feed 1 s hold per creature) is part of every return and is where the Tablero shows what each creature earned since the last visit |
| The creature carries its rarity | Shown on the card at registration ("Rara: 1 Esencia por minuto en el corral") so the child learns the rule at the first steal |
| First minute | Spawn facing east, steal a Chispín (Común) by about 0:45, register at 1:30: 6 + 4 first steal + 4 base = 14 Esencia and the first creature in pen 1, producing 0.5 per minute once fed |

## 4. Loop 2: the corral

### 4.1 Rules

| Rule | Decision | Why |
| --- | --- | --- |
| Who produces | Only creatures placed in the owner's pens at the hub Corral (the camp and the outpost have no pens) | One engine, one place to look at it, visible to everyone |
| Slots | 4 free. Slots 5 to 8 on the Esencia ladder of section 5 | The 8 pens of OW7 |
| Fed first | A creature produces only inside a feeding window: hold "Dar de comer" with one material (Pelusa or Fogbark; Glowmoss or Espora also accepted) to open a **20-minute window**. One gathered material, one server-observed action, one window | Keeps the spirit of AFK-1: nothing starts from time alone, and the material comes only from gathering |
| Storage | A creature holds at most **20 minutes** of output ("Lleno"). Nothing is credited until the owner holds "Recoger Esencia" (1.5 s) at the pen | Nothing accrues forever; the owner must come back, which is the rhythm of the game anyway |
| The working rule | **Full rate while the owner has an expedition open** (outside every safe circle). **A quarter rate while the owner is inside the hub or any safe circle.** Zero while dead or disconnected | "Tus criaturas trabajan mientras tú exploras": the engine rewards going out, not standing on the plaza |
| Rates | Común 0.5, Rara 1.0, Épica 2.0, Legendaria 4.0 Esencia per minute | Doubles per step, so a rarer creature is visibly worth more; matches the Pradera document |
| Duplicates | The second creature of the **same species and rarity** earns half; the third and later earn a quarter | Variety across both biomes beats eight copies of one farmable nest, and the corral stays worth visiting as a show |
| Cap | The corral never pays more than **12 Esencia per minute** before the Nivel de criador bonus, 18 after | About twice the active rate at most; the active loop stays the main income for anyone who plays |
| Offline | **Nothing accrues offline.** Session-only today. When saved progress exists, the stored, uncollected output (at most 20 minutes' worth) survives to the next session and nothing else | A child returns to something waiting, not to a wall of free money; no "log in to collect" habit |
| Removing a creature | Free, any time, at the pen; the stored output is collected first | Pens are a choice, not a trap |
| Display | Every pen shows the creature hovering, its owner and its rate; the plaque says "Lleno" when storage is full so visitors can tell a working corral from a parked one | Social proof is the point of the hub |
| Trophies | The 5 plinths show the rarest creature per biome, event eggs, the PI-1 theft. **Trophies never pay Esencia** | A trophy that pays becomes a farm |

### 4.2 What a corral earns

Per minute, while the owner is out, before the cap and the breeder bonus:

| Corral | Composition | Rate | Per 6-minute cycle (5 out, 1 in hub) |
| --- | --- | --- | --- |
| Session 1 end | Común, Común (dup), Rara, Común (dup) | 1.9 | 10 |
| 2 hours, free | plus Rara (dup), Épica | 4.4 | 23 |
| 2 hours, paying | plus Común (dup), Rara (dup) in slots 7 and 8 | 4.8 | 25 |
| Mature, 8 varied | 2 Común, 3 Rara (two species), 2 Épica (two species), 1 Legendaria | 11.3 | 59 |
| Theoretical, 8 Legendaria of one species | 4 + 2 + 1 + 1 + 1 + 1 + 1 + 1 | 12 (cap) | 63 |

Against the active rate of about 5 to 6 per minute, a mature corral doubles income; getting there takes every biome, the event egg and about 4 hours, and the simulator must confirm that order of magnitude.

### 4.3 Nivel de criador

A 10-level account ladder, Esencia only, never sold, never required. Each level: +5 % corral output (max +50 %), and every second level one more trophy plinth or pen cosmetic. It is the long tail for players who have finished everything else, and it is the only ladder here with 10 steps; see section 5.1 for why.

## 5. Loop 3: spending

### 5.1 The free-path formula

Every permanent thing is bought on a ladder:

```text
cost(n) = round10(base × ratio^(n − 1))      n = 1, 2, …, steps
```

`round10` rounds to the nearest 10 so prices read well. Ladders that are **also sold for Robux stop at 3 or 4 steps**; the one 10-step ladder (Nivel de criador) is never sold and uses the softest ratio. Why: the table below shows what a geometric ladder does to time. By step 5 a flat Robux price next to it looks like a bargain, which is the incentive the user asked for; by step 8 the free path is a wall, which the user does not want. So the sold ladders end before the wall, and the long tail belongs only to prestige.

Canonical 10-step table, `base 40, ratio 2`, minutes to afford each step alone at three total income rates (6 per minute is a free player in session 1, 9 a free player with a six-pen corral, 12 a mature corral plus active play):

| Step | Cost | Cumulative | At 6 per minute | At 9 per minute | At 12 per minute |
| --- | --- | --- | --- | --- | --- |
| 1 | 40 | 40 | 7 min | 4 min | 3 min |
| 2 | 80 | 120 | 13 min | 9 min | 7 min |
| 3 | 160 | 280 | 27 min | 18 min | 13 min |
| 4 | 320 | 600 | 53 min | 36 min | 27 min |
| 5 | 640 | 1,240 | 1 h 47 | 1 h 11 | 53 min |
| 6 | 1,280 | 2,520 | 3 h 33 | 2 h 22 | 1 h 47 |
| 7 | 2,560 | 5,080 | 7 h 07 | 4 h 44 | 3 h 33 |
| 8 | 5,120 | 10,200 | 14 h 13 | 9 h 29 | 7 h 07 |
| 9 | 10,240 | 20,440 | 28 h 27 | 18 h 58 | 14 h 13 |
| 10 | 20,480 | 40,920 | 56 h 53 | 37 h 56 | 28 h 27 |

The concrete ladders:

| Ladder | base, ratio, steps | Prices | Also sold for Robux |
| --- | --- | --- | --- |
| Corral slots 5 to 8 | 60, 2.35, 4 (published rounded up) | 60 / 150 / 350 / 800 | Yes (section 6) |
| Equipment pieces, 1st to 4th owned, any order | 80, 2.5, 4 | 80 / 200 / 500 / 1,250, plus materials | Yes |
| Skill tier per branch | 40, 2.5, 3 | 40 / 100 / 250, plus materials | **Never** |
| Nido cálido (incubator) | 50, 2.5, 3 (published rounded: the formula gives 50 / 125 / 312.5) | 50 / 125 / 300 | No; the second incubator slot is (section 6) |
| Nivel de criador | 40, 1.6, 10 | 40 / 60 / 100 / 160 / 260 / 420 / 670 / 1,070 / 1,720 / 2,750; total 7,250 | **Never** |

### 5.2 Skill tree

The four P0 branches (Explorer, Capturer, Survivor, Occultist) keep their tier 1 and 2 nodes and costs, and gain the Pradera's three nodes ("Pies de nube", "Ojo de sol", "Bolsillo de espora") as a fifth branch at 40 / 100 / 220 as that document proposes. A third tier per branch at 250 Esencia + 50 common + 30 uncommon + 5 rare (either side) is reserved for the next design pass, with one rule already fixed: **no skill cancels a beast, lowers a telegraph under 0.8 s, or is needed to finish any route.** Skills are earned only.

### 5.3 Equipment pieces (the faster advantages)

Four pieces, one of each, no stacking, worn until removed. Each has three levels; **level I is most of the value**, II and III are refinements, and only level I is ever sold. The Esencia price of a piece is the next step of the piece ladder whatever the piece; levels II and III cost a flat 150 and 400 Esencia plus materials for everyone.

| Piece (player name) | Level I | Level II | Level III | Rule it must keep |
| --- | --- | --- | --- | --- |
| **Guantes de captura** | Calm meter fills 20 % faster; ring tolerance +0.5 stud | +10 % | +10 %, retry cooldown −1 s | Standing still must still fail: stationary maximum (about 3.6 s) stays under every `calmRequired`; the simulator asserts it at level III |
| **Botas ligeras** | Sprint drain −20 % | −30 % | −30 % and walk +1 while loaded (cap 16) | `carrySpeed > 8`; the chase stays escapable by a rested sprinter, never trivial for a tired one |
| **Chaleco** | Survive one marked hit per expedition: the strike drops the newest bag item instead of defeating | Also keeps the mark from doubling the next loss | Also halves the material loss of that defeat if a second strike lands | Never prevents the strike or the telegraph; the fair-strike contract is untouched |
| **Amuleto** | Heartbeat and fear effects muted; beast memory of you −1 s | −2 s | −2 s and the "Something moved" notice 5 s after an ambush move | Never reads camera or gaze; never shortens a telegraph |

Why pieces are the faster advantage: Guantes I at 80 Esencia changes the first ten minutes of every session (fewer failed captures, so more creatures per trip, so a fuller corral sooner), while a skill tier at 40 changes one number. That is the gap the user named, and it is why a piece is also what a Robux offer sells.

### 5.4 Totems

| Totem | Cost (crafted, hold 1 each) | Effect | Downside | Why it is not sold |
| --- | --- | --- | --- | --- |
| **Tótem de la suerte** | 20 Esencia + 12 Glowmoss or Espora + 2 rare | Placed, 60 s, radius 40: the next spawn in radius rolls one rarity tier up. Consumed | Emits noise; the beast of that side hears it | It is a luck modifier. Earned only by play it needs no odds disclosure; sold for Robux, or bought with a currency that Robux can buy, it becomes a paid random item |
| **Tótem de abundancia** | 30 Esencia + 2 rare | Placed in your corral: +25 % output for 20 minutes | Costs more than it returns below a 6-per-minute corral (0.25 × 6 × 20 = 30): a decision, not an auto-buy | Same rule: never sold, so the corral never has a paid multiplier |
| **Last Breath Totem** | As today | Wards one extra item; detection +6 | As today | As today |

### 5.5 Corral slots and incubator

| Upgrade | Free path | What it does |
| --- | --- | --- |
| Pens 5 to 8 | 60 / 150 / 350 / 800 Esencia | One more producing, visible creature each |
| Nido cálido I to III | 50 / 125 / 300 Esencia | Hatch time −20 % per level (90 → 72 → 58 → 46 s; the 300 s event egg → 240 → 192 → 154). Never below half the base, so the biome event stays a shared beat |
| Segunda incubadora | 250 Esencia | Two eggs at once |
| Bolsa grande (Reinforced Pack) | 120 Esencia + 60 Fogbark + 30 Glowmoss, as today | Bag 4, pouch 45, loss 10 % |

## 6. Robux offers (design only, nothing implemented)

### 6.1 The rules every offer keeps

1. **Esencia is never sold.** Not alone, not in a bundle, not as a "starter pack". This keeps the luck totem and every random spawn outside the paid-random-items rules, and keeps the Tablero honest: every Esencia on it was played for.
2. **Every offer has a free path**, printed on the offer itself: "O consíguelo jugando: ~25 min". The estimate comes from the player's own income over the last 20 minutes, never from a marketing number.
3. **Same item, earlier.** Nothing sold is stronger, rarer or exclusive. Level I only; levels II and III, skills, totems and the Nivel de criador are earned by everyone.
4. **Deterministic.** No eggs, chests, draws, luck boosts or "mystery" anything for Robux. Nothing to disclose because nothing is random.
5. **Kids-safe surfacing.** No offer in the first 10 minutes of a first session. An offer appears only at the moment its free step becomes visible (the fourth pen fills, the first marked hit, the first failed capture), once, with a plain "No, gracias"; at most one offer per 15 minutes; no countdowns, no flashing, no "last chance", no character begging. Price in Robux on the button. Roblox's own purchase prompt is the only confirmation.
6. **Server-granted, idempotent, persisted.** `ProcessReceipt` grants on the server and records the receipt before returning `PurchaseGranted`; a grant that cannot be saved is not granted and the receipt is left pending. None of this is possible while DataStore is forbidden, which is why the Puesto stays a marker.
7. **A ceiling.** Everything purchasable adds up to about 700 Robux; after that only cosmetics exist. There is no funnel past the ceiling by design.

### 6.2 The offers

Time saved is computed at the moment the offer appears, from the income a free player has then (about 7 to 8 Esencia per minute after the first session). Prices are approximate placeholders for the user to set in Creator Hub.

| Offer (player name) | What | When it appears | ~Robux | Free path | Time saved | Why it is honest |
| --- | --- | --- | --- | --- | --- | --- |
| **Un corral más** | The next pen, whichever step the ladder is on | The moment the current pens are full and the next step costs 150 or more | 49 | 150 / 350 / 800 | 20 min / 45 min / 1 h 40 | Same pen; flat price against a rising one is the whole incentive, and the free step is on screen beside it |
| **Corral ampliado** | Pens 5 to 8 at once (less any already owned) | When the fourth pen fills, from the second session | 199 | 1,360 total | About 5 hours to the eighth pen (model: free reaches pen 7 at 2 h 38, pen 8 past 4 h; paying has 8 pens fed by 0:44) | The eighth pen is the only thing that comes "much later" on the free path, and it is a pen, not power |
| **Equipo del explorador** | One equipment piece of the buyer's choice at level I | At the trigger of that piece: first failed capture (Guantes), first exhausted sprint (Botas), first marked hit (Chaleco), first ambush (Amuleto) | 79 each | 80 / 200 / 500 / 1,250 by piece order | 10 min / 25 min / 1 h / 2 h 40 | Identical to the crafted piece; levels II and III are earned by everyone; buying the fourth piece saves the most, which is where the flat price is meant to shine |
| **Bolsa grande** | The Reinforced Pack | First "Bolsa llena" or "Zurrón lleno" notice | 99 | 120 Esencia + 60 Fogbark + 30 Glowmoss | About 35 min | The same pack the P0 economy already sells for Esencia |
| **Segunda incubadora** | A second incubator slot | First time a second egg is banked while one incubates | 79 | 250 Esencia | About 35 min | Convenience; hatch speed itself is not sold (S5 stays "no" by default) |
| **Cintas y sombreros** | Cosmetics for corral creatures and pen plaques; a few ribbons are also earned by play | The corral tab, from the second session | 49 to 149 | Some by play, most not needed | None | Cosmetic only, the roadmap's E7 first step |

Not offered, on purpose: Esencia packs (section 6.1 rule 1), totems and luck of any kind, skill nodes, hatch skips per use (impulse buys on a timer are the wrong habit for kids), x2 corral boosts (a paid multiplier on idle income teaches not playing), any item at level II or III, any offer in the first ten minutes.

### 6.3 Where the incentive comes from

A free player's prices double or better at each step while Robux prices stay flat, so the shortcut's value grows with the player's investment in the game rather than with their frustration: pen 5 is eight minutes of play and nobody should buy it; pen 8 is a long evening and the 49-Robux "Un corral más" beside it is a fair question. The steps that would turn into walls are the ones the ladders never reach. That is the Steal-an-Egg lesson in the user's words, with the two things that game does and this one must not: no paid currency and no paid randomness.

## 7. Timelines

From the scratch model in this design (6-minute cycles after a 2-minute first steal; 30 Esencia of active income per cycle; one creature home per cycle with the rarity script Común, Común, Rara, Común, Rara, Épica, Común, Rara, Épica, Común, Rara, Legendaria at 72 minutes, then Épica, Rara, Común, Épica…; corral at full rate 5 of every 6 minutes; cheapest useful purchase first; duplicates counted species by rarity as a worst case). **These are arithmetic, not play.**

### 7.1 Free player, first 20 minutes

| Time | What happens | Esencia in hand |
| --- | --- | --- |
| 0:00 | Spawns facing east; the gate sign and the meadow | 0 |
| 0:45 to 1:30 | Steals a Chispín at Prado de los Brotes, registers at the Refugio: +14. Pen 1, "Dar de comer" with one Pelusa from a node on the way | 14 |
| 2:00 | Buys the starter upgrade (10). The card says "Común: 0,5 de Esencia por minuto" | 4 |
| 2:00 to 8:00 | Cycle 2: Musgón (Común), nodes. Back: collect 2 from the pen, +26 active | 32 |
| 8:00 to 14:00 | Cycle 3: Esponjín (Rara) near her ground. Collect 4; +30 | 66 → buys skill tier 1 (40) at 14:00 | 26 |
| 14:00 to 20:00 | Cycle 4: Lumipol from Claro del Umbral (Común). Collect 9 (Común 0.5 + Común duplicate 0.25 + Rara 1.0, five minutes out); +26. Pens 1 to 4 are full: the plaque says "Corral lleno: pen 5 cuesta 60" | 61 → buys pen 5 (60) at 20:00 | 1 |

Session 1 ends with 4 creatures producing 1.9 per minute, one skill, the starter upgrade, and the fifth pen bought as the session closes. Total earned: 96 active, 15 corral.

### 7.2 Paying player, first 20 minutes

Identical until 20:00: no offer is shown before minute 10, and the first trigger (four full pens) happens at the end of the session. At 20:00 the "Corral lleno" plaque shows the free step (60) and, beside it, **Corral ampliado** for 199 Robux with "O consíguelo jugando: pen 5 en ~8 min, los cuatro en ~3 h". If they buy, session 1 ends with 8 pens (4 empty) and 61 Esencia unspent instead of 1.

### 7.3 Free player, two hours

| Time | Milestone | Esencia earned so far (active + corral) |
| --- | --- | --- |
| 0:20 | Pen 5 | 111 |
| 0:32 | Guantes I crafted (80) | 190 |
| 0:50 | Skill tier 2 (100 + 3 rare): **session 3** with the cheapest-first policy; session 2 if the player saves for it | 310 |
| 1:08 | Pen 6 (150) | 440 |
| 1:12 | Legendaria from the biome event egg hatched and placed | |
| 1:32 | Second equipment piece (200) | 620 |
| 2:00 | Skill tier 3 (250). 6 pens, corral 4.4 per minute, 21 creatures in the collection, 2 pieces, 3 skill tiers, 37 Esencia in hand | 927 (626 + 301; corral share 32 %) |
| 2:38 | Pen 7 (350) | |
| 3:32 | Third piece (500) | |
| past 4:00 | Pen 8 (800) and the fourth piece (1,250) | 2,003 at 4:00 |

### 7.4 Paying player, two hours (Corral ampliado at 0:20 and Guantes I at 0:26, about 278 Robux)

| Time | Milestone | Esencia earned so far |
| --- | --- | --- |
| 0:20 | 8 pens (Robux) | 112 |
| 0:26 | Guantes I (Robux); the 80 Esencia it would have cost goes to the next step | 150 |
| 0:38 | Skill tier 2: 12 minutes earlier than free | 250 |
| 0:44 | 8 pens full and fed: **about 5 hours earlier than free** | |
| 1:02 | Second equipment piece | 450 |
| 1:26 | Skill tier 3: 34 minutes earlier than free | 700 |
| 2:00 | Same items and skills as the free player, 2 more pens producing, 347 Esencia in hand against 37 | 1,027 (626 + 401; corral share 39 %) |
| 2:20 | Third piece, 1 h 12 earlier than free | |
| 4:00 | Fourth piece; the free player has everything but pen 8 and that piece | 2,125 against 2,003 |

What the money bought: about 45 minutes of progress per two hours, a full corral from the first hour, and the same ceiling. The free player's two-hour income is 90 % of the payer's; by four hours it is 94 %. If the simulator finds a bigger gap, the corral rates or the ladders are wrong, not the offers.

## 8. What the simulator must check

`tools/simulate_economy.py` gains a `corral` input and the ladders; every number below is an assertion to add, in the style of its `check_invariants`. The figures in brackets are this design's expectations from the scratch model; the simulator's numbers replace them.

| # | Check | Threshold |
| --- | --- | --- |
| S1 | Free balanced player reaches a tier-2 skill node | p50 within **3 sessions** of 20 minutes with the cheapest-first policy, within 2 when saving for it; p90 within 4. The 3 rare materials must be reachable from either side within the same sessions |
| S2 | Paying player (Corral ampliado + one piece) saves time to "8 pens full and fed" | **≥ 90 minutes** earlier than free [model: 0:44 against past 4:00] |
| S3 | Paying advantage is bounded | Total Esencia earned at 2 hours ≤ **1.25 ×** the free player's [1.11 ×]; at 4 hours the free player owns every permanent item the payer owns except at most two ladder steps |
| S4 | No offer is required to finish any loop | Every row in `offers` has a non-null `freePath`; a free balanced player owns every permanent item within **6 hours**; every recipe is payable without entering the other biome |
| S5 | Corral share | Corral ≤ **50 %** of total income at 2 hours for free [32 %], ≤ 60 % for paying [39 %]; a mature 8-pen corral never exceeds 12 per minute before the breeder bonus |
| S6 | AFK bound | An idle hour at the hub with a fed corral credits at most 25 % × rate × 20 minutes once (the storage cap), and 0 with no feeding or no expedition ever opened; nothing accrues while dead or disconnected |
| S7 | Expedition floor | Greedy median ≥ **180 s** with Botas III and Guantes III modelled; perturbation floor 150 s holds |
| S8 | Ladders | Every ladder is strictly increasing; `cost(n+1) / cost(n)` within [1.5, 2.6]; sold ladders have ≤ 4 steps; unsold ones may have 10 |
| S9 | Policy shape | No `offers` row has `random: true`; `currency.purchasable` is false; no row grants a level above I; no offer appears before minute 10 |
| S10 | Capture invariant | Stationary calm maximum < `calmRequired` with Guantes III and every `capturer` skill |
| S11 | Duplicates | A corral of 8 identical Legendaria pays 12 per minute; 8 varied creatures pay more than 8 copies of the same Rara |
| S12 | First minute | First Esencia within 90 s and first producing creature within 2 minutes for both spawn directions |

## 9. Tuning block (proposal)

For a later `tools/simulate_economy.py` reader and `tools/export_economy_config_luau.py`. This is **not** the P0 `json economy-tuning` block and is not read by any tool today; it is the shape the writer would merge into it. `monetization` stays `"none"` and `offers` are design rows, not products.

```json economy-idle
{
  "schema": "wildbound.economy.idle",
  "schemaVersion": 1,
  "status": "hypothesis",
  "monetization": "none",
  "currency": { "id": "ember", "playerName": "Esencia", "lostOnDefeat": false, "purchasable": false },
  "rarity": {
    "bandsByDistance": { "Legendaria": [0, 45], "Epica": [45, 80], "Rara": [80, 120], "Comun": [120, null] },
    "fromRiskTier": { "Safe": "Comun", "Fog": "Comun", "FogFar": "Rara", "Territory": "Epica", "Heart": "Legendaria" }
  },
  "corral": {
    "freeSlots": 4,
    "maxSlots": 8,
    "slotLadder": [60, 150, 350, 800],
    "ratePerMinute": { "Comun": 0.5, "Rara": 1.0, "Epica": 2.0, "Legendaria": 4.0 },
    "duplicateFactors": [1.0, 0.5, 0.25],
    "duplicateKey": "species_and_rarity",
    "maxPerMinute": 12,
    "feed": { "materials": ["pelusa", "fogbark", "glowmoss", "espora"], "units": 1, "windowMinutes": 20, "holdSeconds": 1 },
    "storageMinutes": 20,
    "collectHoldSeconds": 1.5,
    "rateShare": { "expeditionOpen": 1.0, "inSafeZone": 0.25, "deadOrAway": 0.0 },
    "offline": "nothing_accrues; stored output survives once persistence exists",
    "trophiesPayEsencia": false
  },
  "breederLevel": { "base": 40, "ratio": 1.6, "steps": 10, "outputBonusPerLevel": 0.05, "sold": false },
  "ladders": {
    "equipmentPiece": { "base": 80, "ratio": 2.5, "steps": 4, "sold": "levelIOnly" },
    "skillTier": { "base": 40, "ratio": 2.5, "steps": 3, "sold": false },
    "nidoCalido": { "base": 50, "ratio": 2.5, "steps": 3, "sold": false, "hatchScalePerLevel": 0.8, "minHatchScale": 0.5 },
    "equipmentLevelII": 150,
    "equipmentLevelIII": 400,
    "secondIncubator": 250
  },
  "equipment": {
    "guantes": { "I": { "calmFillBonus": 0.2, "ringTolerance": 0.5 }, "II": { "calmFillBonus": 0.3 }, "III": { "calmFillBonus": 0.4, "retryCooldownDelta": -1 } },
    "botas": { "I": { "sprintDrainScale": 0.8 }, "II": { "sprintDrainScale": 0.7 }, "III": { "sprintDrainScale": 0.7, "loadedWalkBonus": 1 } },
    "chaleco": { "I": { "markedHitsSurvived": 1 }, "II": { "markNoDoubleLoss": true }, "III": { "secondStrikeLossScale": 0.5 } },
    "amuleto": { "I": { "beastMemoryDelta": -1, "fearMuted": true }, "II": { "beastMemoryDelta": -2 }, "III": { "beastMemoryDelta": -2, "relocationNotice": true } }
  },
  "totems": {
    "suerte": { "cost": { "ember": 20, "glowmossOrEspora": 12, "rare": 2 }, "seconds": 60, "radius": 40, "tierUp": 1, "noise": true, "sold": false },
    "abundancia": { "cost": { "ember": 30, "rare": 2 }, "minutes": 20, "outputScale": 1.25, "sold": false }
  },
  "smallSources": { "waveBoardTop3": [5, 3, 2], "beastBeatenNoCapture": 3, "firstSpeciesRegistered": 10 },
  "offers": [
    { "id": "unCorralMas", "grants": "nextCorralSlot", "robuxApprox": 49, "freePath": "corral.slotLadder", "random": false, "showAfterMinute": 10 },
    { "id": "corralAmpliado", "grants": "corralSlots5to8", "robuxApprox": 199, "freePath": "corral.slotLadder", "random": false, "showAfterMinute": 10 },
    { "id": "equipoExplorador", "grants": "oneEquipmentPieceLevelI", "robuxApprox": 79, "freePath": "ladders.equipmentPiece", "random": false, "showAfterMinute": 10 },
    { "id": "bolsaGrande", "grants": "reinforcedPack", "robuxApprox": 99, "freePath": "upgrades.reinforcedPack", "random": false, "showAfterMinute": 10 },
    { "id": "segundaIncubadora", "grants": "incubatorSlot2", "robuxApprox": 79, "freePath": "ladders.secondIncubator", "random": false, "showAfterMinute": 10 },
    { "id": "cintasYSombreros", "grants": "cosmetic", "robuxApprox": [49, 149], "freePath": "someByPlay", "random": false, "showAfterMinute": 10 }
  ],
  "offerRules": { "firstOfferMinute": 10, "minMinutesBetweenOffers": 15, "countdowns": false, "showFreePathEstimate": true },
  "simulatorInputs": {
    "cycleMinutes": 6,
    "firstCycleMinutes": 2,
    "activeEsenciaPerCycle": 30,
    "hubShareOfCycle": 0.1667,
    "rarityScript": ["Comun", "Comun", "Rara", "Comun", "Rara", "Epica", "Comun", "Rara", "Epica", "Comun", "Rara", "Legendaria"],
    "payingPurchases": [{ "minute": 20, "offer": "corralAmpliado" }, { "minute": 26, "offer": "equipoExplorador" }]
  }
}
```

## 10. Decisions for the user

| ID | Decision | Recommendation |
| --- | --- | --- |
| E1 | Esencia never sold for Robux, so totems and random spawns stay outside the paid-random-items rules | Yes. It is the one rule that keeps every other row simple |
| E2 | Corral rates 0.5 / 1 / 2 / 4 with duplicates at half and a quarter, cap 12 | Yes; simulate before changing |
| E3 | The working rule: full rate out, a quarter in safe zones, zero offline | Yes. If the user wants a pure idle corral instead, AFK-1 and AFK-2 and their tests change, and this document must say so |
| E4 | Sold ladders stop at 4 steps; only the Nivel de criador runs 10 | Yes |
| E5 | Equipment: level I sold, II and III earned; the piece ladder counts pieces, not levels | Yes |
| E6 | Offers: the six rows of 6.2, about 700 Robux in all, no Esencia, no randomness, no hatch skips | Yes; prices are placeholders |
| E7 | Second incubator slot instead of hatch speed-ups (keeps S5 at "no") | Yes |
| E8 | Surfacing rules for kids: first offer at minute 10, one per 15 minutes, no timers | Yes |

## 11. Code implications (not authorizations)

For a later writer, after the user's decisions and after persistence exists for anything in section 6.

| Where | What |
| --- | --- |
| `WildboundState` | `rarity` on pending and registered entries; `corral = { pens = {}, fedUntil = {}, stored = {} }`; `equipment`, `breederLevel`; the AFK contract text and AFK-2 test amended to the working rule |
| New `WildboundCorral.luau` (pure) | Rate by rarity, duplicate factors, cap, storage, feeding window, the working rule from the expedition state; contracts for S5, S6, S11 |
| `WildboundServer.server.luau` | Pen prompts "Dar de comer" and "Recoger Esencia"; `Action` entries `PlacePen`, `RemovePen`, `BuySlot`, `Craft` piece, `Upgrade` level; the 1 Hz corral tick writes only to `stored`, never to `ember` |
| `WildboundEconomyConfig.luau` | Generated from the merged tuning JSON; `tools/export_economy_config_luau.py` and its drift test stay the only route |
| `tools/simulate_economy.py` | The `corral` input, the ladders, S1 to S12, a `--paying` policy |
| HUD and camp views | Pen plaques, "Lleno", the Tablero rows per creature, the offer card with the free-path line; neutral Spanish strings in `WildboundText` |
| Nothing | `MarketplaceService`, `ProcessReceipt`, product ids, prices: not until Creator Hub, saved progress and the user's explicit approval exist |

## 12. Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| A child understands "the creature earns while I explore" from the card and the plaque | Testers cannot say why the number on the Tablero grew, or never return to the pens |
| The corral is pocket money that makes rarity matter, not a reason to stop playing | Testers park at the hub and wait, or corral share passes 50 % in the logs for free players |
| Doubling prices read as a goal, not a wall | Testers name pen 5 or 6 as the next goal; nobody names pen 8 and nobody complains about it |
| The offers read as shortcuts | Testers who decline keep playing; a tester calls an offer "the only way" |
| The free-path estimate on the offer is believed | Estimates are off by more than 50 % against the player's actual time |
| Duplicates at half keep the show varied | Corrals in the logs hold at most 3 copies of one species and rarity |
| Equipment pieces feel like the faster advantage | Players buy a piece before a second skill tier, and say why |

## 13. Unverified

Everything: no number has met the simulator, a child, a phone or a Studio build. The scratch model behind section 7 is straight arithmetic with a fixed rarity script and a single purchase order; it has no defeats after the first session, no Night, no second player, no fun. The Robux prices are placeholders. Roblox policy text was read from the pack's summary of 2026-11-07, not re-read today; recheck the paid-random-items and Developer Products pages before any product exists.
