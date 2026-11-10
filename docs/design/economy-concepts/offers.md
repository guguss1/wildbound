# Hub economy concept, angle "offer design first": the free path and the Robux shortcuts

**Status: design only. Nothing here is implemented, priced in Creator Hub, simulated or played.** Written 2026-11-09 from the user's direction of that day: one open world with a permanent safe hub in the centre (incubator, corral, trophies, shop and skill tree), La Silueta's forest to the west, a bright biome for kids to the east; creatures earn Esencia for their owner; Esencia buys the skill tree and upgrades; equipment items and totems give faster advantages; the free path always exists but each step costs more; Robux offers shorten the path in the Steal-an-Egg manner, as convenience and never as a wall. Every number is a hypothesis for the tuning JSON and for `tools/simulate_economy.py`. Design and code are English; in-game names and player strings are neutral Spanish.

**No purchase is implemented or authorized by this document.** `monetization` stays `"none"` in the tuning JSON. Developer Products and Game Passes need the user's Creator Hub setup, `MarketplaceService.ProcessReceipt` on the server and saved progress; DataStore is currently forbidden, so nothing permanent can be sold yet (section 9). Robux prices below are ranges to discuss, not a price list.

## Quick path

| You are | Read |
| --- | --- |
| The user | Sections 2, 6 and 7 (the ladder, the offers, the timelines), then section 11 (decisions) |
| The simulator writer | Sections 3, 4, 5 and 8 (the loops, the ladder formula, items, the numbers to check) |
| A later Studio writer | Section 9 (what must exist before any purchase) and section 10 (policy checklist) |

## 1. Facts this design rests on (verified in the repo)

| Fact | Where | Why it matters here |
| --- | --- | --- |
| Players call the currency Esencia; the code id is `ember`; it is never lost on defeat and `purchasable = false` | `src/wildbound/WildboundCampView.luau:23-24`; `WildboundEconomyConfig.luau:31` | Every price below is in Esencia; section 6 keeps Esencia unsold |
| Active income, simulated solo: about 23 Esencia per expedition with a median of 190 to 208 s, defeats 1 to 30 % by archetype | `docs/mechanics/wildbound-economy-p0.md:444-452` | The "6 Esencia per minute of session" assumption in section 3.1 comes from this plus hub turnaround |
| Skill tree: four branches, tier 1 costs 40 Esencia + 20 Fogbark + 10 Glowmoss, tier 2 costs 100 Esencia + 30 Fogbark + 20 Glowmoss + 3 Nightbloom and needs tier 1; no skill is needed to finish a route | `wildbound-economy-p0.md:372-387`; `WildboundEconomyConfig.luau:170-235` | The ladder in section 4 continues this curve (40, 100, 220 is a 2.3 ratio) |
| Sinks today: Ward Seal, Last Breath Totem (20 Esencia, 12 Glowmoss, 2 Nightbloom; downside: detection +6 studs, ambush anchors x2), Extraction Capsule, Reinforced Pack (120 Esencia, 60 Fogbark, 30 Glowmoss; once) | `wildbound-economy-p0.md:331-342`; `WildboundEconomyConfig.luau:138-167` | Section 5 adds items beside them without changing them |
| No AFK path: no quantity grows from time alone; rewards need a server-observed action; bond banks only on extraction | `WildboundEconomyConfig.luau:252-257`; `wildbound-economy-p0.md:409-422` | The corral loop (section 3.2) keeps the feed and collect actions from the Pradera synthesis |
| Corral proposal: produce only while the owner is in the server and after feeding one Pelusa (20-minute window), cap 20 minutes of output, collect by hand; 0.5 / 0.5 / 1.0 / 2.0 / 4.0 Esencia per minute by rarity; 4 free slots, slots 5 to 8 at 60 / 150 / 350 / 800 Esencia | `docs/design/wildbound-biome-pradera.md:269-282` | Adopted as is; this document prices the shortcuts around it |
| Incubator: one egg at a time per player, 90 s hatch, hatching pays nothing; "paying to speed a hatch (never: no Robux)" was that delivery's rule | `docs/mechanics/wildbound-incubator.md:9-10`, `:34` | The user's direction reopens it; section 6 bounds it (Pradera decision S5) |
| Plan Part 4: Guantes de captura (calm meter +30 %), Botas (sprint drain -30 %), Chaleco (survive a marked hit once), Amuleto (fear suppression, Silueta memory -1 s), one of each, no stacking; Tótem de la suerte 60 s, radius 40, next spawn one tier up, emits noise | `C:/Users/Jesus/.claude/plans/enchanted-jingling-mccarthy.md`, Part 4 | Section 5 prices them and names the rules each must keep |
| Sprint: pool 100 drains 25 per second (about 4 s) at a 1.45 multiplier; the rested sprint must outrun La Silueta's fastest hunt by 5 studs/s | `tools/simulate_economy.py:67-80` (reads `WildboundStamina.luau`) | Botas change drain only, never the escape margin |
| Hub: a "Puesto" is reserved where a convenience offer could stand, and a Tablero shows Esencia; the hub prices nothing | `docs/design/wildbound-open-world-hub.md`, section 2.3 | Offers live at the Puesto and in two contextual cards (section 6.3), nowhere else |
| Roblox paid random items need full odds disclosure and `PolicyService` checks; rewards earned only through play need none | `docs/wildbound-roadmap.md:415` | Section 6 sells nothing random; section 10 lists the checks |
| Sessions are measured as 20 minutes of expedition time; a 12-minute day cycle gives a first Night after a median 253 s | `wildbound-economy-p0.md:129`, `:285` | The timelines in section 7 use 20-minute sessions and assume one Night per session |

## 2. The idea in one paragraph

Three loops feed one another. You **steal and extract** (active, about 6 Esencia per minute), your creatures **earn in the corral** while you play (pocket money, 1 to 4 Esencia per minute for a full starter corral), and you **spend** on a few ladders whose steps grow geometrically: skills, corral slots, incubator speed and slots, equipment and totems. The first steps of every ladder are minutes; the last steps are hours. That curve is the incentive: a player who sees that slot 8 is two hours away, or that a Legendaria egg takes ten minutes to hatch, is offered the same slot or the same hatch for Robux. Nothing sold is stronger than what is earned, nothing sold is random, Esencia itself is never sold, and no offer is needed to finish any loop. The paying player saves time; the free player loses nothing but time.

## 3. The three loops

### 3.1 Loop A: steal and extract (active income)

Unchanged from `wildbound-economy-p0.md` and the Pradera synthesis: leave the hub, steal crías and eggs, gather, come back, extract. Esencia per unit by tier stays `creatureEmberByTier` (6 / 10 / 12 / 14 / 22) and `eggEmberByTier` (8 / 10 / 11 / 14), the completed-trip 4 and the first-steal 4.

Design assumption for every table below, to be replaced by the simulator: **6 Esencia per minute of session time** for a balanced solo player. Derivation: 23.7 Esencia per 203 s expedition (simulated) plus about 40 s of hub turnaround (walk through the 60-stud hub, register, spend, walk out) gives 23.7 / 4.05 min, about 5.9 per minute. Cautious players earn about the same per trip over longer trips; greedy players earn more per minute and lose more to defeats. This number says nothing about fun.

### 3.2 Loop B: corral income (creatures earn for their owner)

Adopted from `wildbound-biome-pradera.md` section 9, restated so this document stands alone, with one extension: the Pradera text feeds with Pelusa only ("Dar pelusa"); here a forest material (Fogbark) also feeds, under one prompt "Dar de comer", so a forest-only player can run the corral too.

| Rule | Value |
| --- | --- |
| Who produces | Creatures placed in the owner's corral at the hub, from either biome |
| When | Only while the owner is in the server and alive; nothing offline (and DataStore is forbidden today) |
| Fed first | One Pelusa (Pradera material) or one Fogbark (forest material) at the prompt "Dar de comer" opens a 20-minute window per creature. One server-observed action, one window |
| Cap | 20 minutes of output stored per creature ("Lleno"). Collect with the hold "Recoger Esencia"; nothing banks without it |
| Rate per minute | Común 0.5, Rara 1.0, Épica 2.0, Legendaria 4.0 (forest Lumipol counts as Común; Silueta-stolen creatures by their tier) |
| Slots | 4 free. Slots 5 to 8 on the slot ladder (section 4.2) |
| Display | The corral is the show: visitors see every placed creature; the trophy display holds the rarest of each biome |

Why this is still "no AFK": a creature produces only inside a window a gathered material opened, and only while its owner plays. Standing still at the hub earns nothing after the window closes, and the owner must act to bank. The simulator must still confirm that the corral never beats active play (section 8, C2).

### 3.3 Loop C: spend

| Sink | What it buys | Ladder (section 4) | Robux shortcut (section 6) |
| --- | --- | --- | --- |
| Skill tree | Permanent rules in the player's favour that never cancel a beast | Tier ladder: 40, 100, 220 Esencia + materials | **None.** Power is earned only |
| Corral slots 5 to 8 | A pen; more creatures earning and on show | Slot ladder: 60, 150, 350, 800 | The same slot, earlier |
| Incubator speed, levels 1 to 10 | Each level shortens every hatch by 7 % (level 10 halves it) | Level ladder, 10 steps | "Eclosión al instante" per egg, bounded |
| Incubator slot 2 | Two eggs at once | 500 Esencia (the slot ladder's step between 350 and 800) | The same slot, earlier |
| Equipment items | Guantes, Botas, Chaleco, Amuleto (section 5) | Fixed craft costs, 80 to 300 Esencia + materials | The same item, earlier (Guantes only in the welcome pack) |
| Totems | Last Breath Totem (exists), Tótem de la suerte (new) | Fixed craft costs, consumable | **None** (section 6.5) |
| Cosmetics | Ribbons, hats, pen plaques | Earned by milestones | Cosmetic shop, the one place where Robux buys something the free path does not have |

## 4. Costs that grow geometrically on the free path

### 4.1 The formula

Every ladder uses one rule: `cost(n) = round5(base * r^(n-1))`, where `n` is the step (1 is the first paid step), `base` is the first step's price, `r` is the ratio and `round5` rounds to the nearest 5 (nearest 10 above 1,000). Two ratios, so that short ladders bite fast and long ladders stay climbable:

| Ladder kind | `base` | `r` | Steps | Used by |
| --- | --- | --- | --- | --- |
| Slot ladder (few, big steps) | 60 | 2.3 | 4 | Corral slots 5 to 8, incubator slot 2 (between steps 3 and 4), skill tiers (base 40) |
| Level ladder (many, steady steps) | 60 | 1.5 | 10 | Incubator speed levels; any future "+1 level" item track |

Time to afford a step, free, is `cost / income`, with income 6 per minute active plus the corral. Cumulative time is what the player feels.

### 4.2 The 10-step table

Level ladder (incubator speed is the first user of it). Time assumes 6 Esencia per minute active, plus a corral growing from 1 to 3 Esencia per minute as the player fills it (section 7 uses the same growth).

| Step | Cost | Cumulative | Minutes at 6/min | Cumulative, with corral | What the player sees |
| --- | ---: | ---: | ---: | ---: | --- |
| 1 | 60 | 60 | 10 | 9 min | "Ya casi" |
| 2 | 90 | 150 | 15 | 22 min | Still one session |
| 3 | 135 | 285 | 23 | 41 min | Two sessions |
| 4 | 205 | 490 | 34 | 1 h 07 | Three to four sessions |
| 5 | 305 | 795 | 51 | 1 h 42 | Here the offer starts to look reasonable |
| 6 | 455 | 1,250 | 76 | 2 h 32 | |
| 7 | 685 | 1,935 | 114 | 3 h 48 | |
| 8 | 1,030 | 2,965 | 172 | 5 h 43 | |
| 9 | 1,540 | 4,505 | 257 | 8 h 34 | |
| 10 | 2,310 | 6,815 | 385 | 12 h 51 | The long tail for players who stay |

Worked rounding: step 4 is 60 x 1.5^3 = 202.5, rounded to 205; step 8 is 60 x 1.5^7 = 1,025.2, above 1,000 so rounded to the nearest 10, 1,030. The "with corral" column assumes corral income rising from 1 to 3 Esencia per minute over the first two hours and 3 per minute after (so 7 to 9 per minute in all); it is the model the timelines in section 7 use.

Slot ladder, for comparison, with the same income: slot 5 at 60 (10 min), slot 6 at 150 (25 min, cumulative 35), slot 7 at 350 (58 min, cumulative 1 h 33), slot 8 at 800 (2 h 13, cumulative 3 h 46). Skill tiers: tier 1 at 40 (7 min), tier 2 at 100 (17 min, plus 3 Nightbloom, which needs a Night), tier 3 (new, proposal) at 220 (37 min, plus 5 Nightbloom or 5 Espora Brillante).

Why these ratios: the first four steps of every ladder fit in the first hour so a child always has a next goal they will reach today; from step 5 the wait doubles per session and the shortcut becomes a real choice rather than a nag. A ratio under 1.4 makes the offer pointless; a ratio over 2.5 on a long ladder makes the free path read as a wall. The simulator must check both (section 8, L1 to L3).

## 5. Equipment items and totems: the faster advantages

All items are crafted at the hub Taller (or the forest camp, OW2) with Esencia plus materials, one of each, no stacking, and they keep every fair-strike and capture rule. Today they would be session-only, like everything else; they become permanent when persistence lands (section 9). The Robux version of an item is **the same item, with the same numbers, bought earlier**: nothing stronger is ever sold.

| Item (player name) | Effect | Rule it must keep | Craft cost | Minutes of free play it replaces | Why it is "faster" |
| --- | --- | --- | --- | --- | --- |
| **Guantes de captura** | Calm meter fills 30 % faster and the Calm ring tolerates one more slip per capture | Standing still must still fail: the stationary maximum (about 3.6) stays below every `calmRequired` | 80 Esencia, 20 Fogbark, 10 Glowmoss | about 15 | Shorter captures mean shorter holds under the beast, so fewer flees and more units per trip. Equivalent to Steady Hands plus Soft Approach on day one, without the Nightbloom |
| **Botas ligeras** | Sprint drains 30 % slower (25 to 17.5 per second, about 5.7 s of sprint instead of 4) | Sprint speed cap 24 unchanged; the escape margin over La Silueta's fastest hunt stays 5 studs/s; sprint noise unchanged | 120 Esencia, 30 Fogbark, 15 Glowmoss | about 22 | Longer sprints make the long hub walk and the first flee cheaper; nothing about the beast changes |
| **Chaleco acolchado** | Once per expedition, the strike that would defeat you marks you instead (the mark still drops the newest bag item) | The telegraph, dwell gate and loss rule are untouched; a second such strike defeats as usual | 200 Esencia, 40 Fogbark, 20 Glowmoss, 2 Nightbloom | about 40 | Turns the greedy archetype's 30 % defeat rate toward the balanced 7 % without touching her; the simulator must show the 180 s floor still holds (section 8, F1) |
| **Amuleto de calma** | Heartbeat and fear vignette softened; La Silueta's chase memory 1 s shorter for its wearer | Memory is per hunter and per quarry; other players' hunters unchanged; the 0.8 s warning lead untouched | 300 Esencia, 20 Glowmoss, 3 Nightbloom | about 55 | The quality-of-life item; it is last on purpose, so the free ladder ends with a convenience, not a necessity |

Items never affect another player: the beasts are per player (plan F2) and there is no player-versus-player surface.

**Totems** stay crafted and consumable, never sold (section 6.5):

| Totem | Effect | Downside | Cost | Hold |
| --- | --- | --- | --- | --- |
| Tótem del último aliento (exists) | Wards one extra item on defeat | Detection +6 studs, ambush anchors x2 within 60 | 20 Esencia, 12 Glowmoss, 2 Nightbloom | 1 |
| **Tótem de la suerte** (new, plan I2) | Placed, 60 s, radius 40: the next egg or cría spawn inside rolls one tier up | It hums: noise as a landing (90-stud radius), so the beast hears it | 25 Esencia, 10 Glowmoss, 1 Nightbloom or 1 Espora Brillante | 1, one active |

## 6. The Robux offers

### 6.1 Principles, before the list

1. **Sell time, never power, never Esencia.** Every offer is the same thing the free path gives, reached sooner. Esencia is not sold, because the corral's whole meaning is that creatures produce it, and because a sold currency makes the ladder a price list.
2. **The free option is always shown first, bigger, with its time.** "Esperar 4:30" above "Eclosión al instante, 29 Robux". A child must be able to read the free path before the paid one.
3. **Nothing random for money.** No eggs, totems or packs with random contents. This keeps the game outside the paid random items rules and makes odds disclosure moot.
4. **No false urgency.** No countdowns on offers in v1, no "was 199, now 99" unless the 199 price was real and shown. The welcome pack is a permanent first-purchase price, not a timer.
5. **One anchor for every price: about 60 to 90 Robux per hour of play saved.** Small starter items sit above it (small tickets always do); the big passes sit at it. The implied rate is printed in the table so the user can argue with it.
6. **No offer is ever required.** Every loop closes with Esencia and materials alone; the simulator must prove it (section 8, N1).

### 6.2 The offers

| Offer (player name) | Kind | What it gives | Free equivalent | Time it saves | Robux (range to discuss) | Implied Robux per hour saved | Why it is honest and policy-safe |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Pase Doble Esencia** | Game Pass, permanent | Esencia from extraction and from the corral is doubled for the owner | Playing twice as long | Half of every ladder: about 6.5 h over the full 10-step ladder (12 h 51 free, section 4.2), 20 min in the first 40 | 299 to 399 | about 55 | Affects only the owner's own income; the wave board counts units banked, never Esencia (section 8, N2); it changes no beast, capture or loss rule |
| **Corral: puesto extra** | Developer Product, one per slot, permanent | The next corral slot, identical to the free one | 60 / 150 / 350 / 800 Esencia | 10 min / 25 min / 58 min / 2 h 13 | Slot 5 not sold (too cheap to be honest); slot 6: 49; slot 7: 79; slot 8: 129 | about 120 / 80 / 58 | The slot is identical; it buys time, not output. Pradera decision S1 still applies: the user may keep slots free only |
| **Incubadora: segundo nido** | Developer Product, permanent | A second incubator slot | 500 Esencia | about 1 h 23 | 99 to 149 | about 70 to 110 | Same slot; hatching still pays nothing |
| **Eclosión al instante** | Developer Product, per use | Hatches the egg now | Waiting 90 / 180 / 300 / 600 s by tier (section 6.4), or the speed ladder | 1.5 to 10 min, and the walk back to check | 19 (Común, Rara) to 29 (Épica, Legendaria) | High per hour, by design: it is an impulse item for the moment a child does not want to wait | The egg, species and tier were already earned by play; only the clock moves. Bounded: the biome event eggs (Huevo de Tormenta, Silueta's egg) can only be **halved**, never instant, so the shared beat stays. Pradera decision S5 currently says "no" for the storm egg; this halve-only bound is the alternative put to the user in O3 |
| **Pack de bienvenida** | Developer Product, once per account | Guantes de captura + 1 Eclosión al instante + 1 Tótem de la suerte + a pen ribbon | Crafting the gloves (15 min) and the totem (5 min) | about 20 min | 79 to 99 | about 240 to 300 (small ticket, cosmetic included) | Shown once, after the first extraction and the first hatch (section 6.3), stays available with no timer; contents are fixed and listed; the gloves are the crafted gloves |
| **Botas ligeras / Chaleco / Amuleto** | Developer Product each, permanent | The same item as crafted | 22 / 40 / 55 min of play plus Nightbloom | as left | 39 to 49 / 79 / 99 | about 105 to 135 / 120 / 110 | Same numbers as the craft; the Nightbloom the craft needs is the only thing skipped, and Nightbloom has a safe path (fog beyond the leash) |
| **Cosméticos** | Developer Products and a cosmetic Game Pass | Ribbons and hats for corral creatures, pen plaques, trophy pedestal skins | Milestone ribbons (first Épica, first 8-slot corral, first Silueta theft) | None: the only place Robux buys something the free path does not | 49 to 199 | not applicable | Cosmetic only, visible in the corral where visitors see it, which is the honest "show off" motive for kids |

Not offered, and why: Esencia bags (section 6.1, rule 1); skill nodes (power is earned); totem packs (section 6.5); anything that changes a beast's rules, the telegraph, the strike or the loss rule; anything random.

### 6.3 When an offer appears

| Surface | When | Rule |
| --- | --- | --- |
| **El Puesto** at the hub (hub doc 2.3) | Always browsable; never pops | Shows every offer with its free equivalent and time beside it. The daily gift (6.6) stands here too, so the Puesto is first a place you get something free |
| **Contextual card: incubator** | The player tries to incubate while the slot is busy, or looks at an egg with more than 2 minutes left | Free line first ("Listo en 4:30" / "Nivel de incubadora 3: 135 de Esencia"), then "Eclosión al instante, 29 Robux". At most one card per 10 minutes |
| **Contextual card: corral** | The player tries to place a fifth or later creature with no free slot | Free line first ("Puesto 6: 150 de Esencia, tienes 95"), then the Robux line. Same cap |
| **Welcome pack** | Once, after the first extraction **and** the first hatch, at the hub, never earlier than minute 5 | No timer; dismiss keeps it in the Puesto |
| **Never** | While marked, chased or inside any beast's ground; on the defeat fade; in the first 5 minutes; on a phone-sized screen during a capture; more than 2 contextual cards per 20-minute session | Offers belong to calm moments at the hub |

### 6.4 Hatch times by tier (proposal, extends the built 90 s)

| Tier | Hatch | With speed level 10 | Eclosión al instante |
| --- | ---: | ---: | --- |
| Común | 90 s | 45 s | 19 Robux |
| Rara | 180 s | 90 s | 19 |
| Épica | 300 s | 150 s | 29 |
| Legendaria | 600 s | 300 s | 29 |
| Biome event egg | 300 s | 150 s | **Halve only** (29), never instant |

### 6.5 Why totems are not sold

The Tótem de la suerte raises the tier of a roll that is still random. Selling it for Robux would make it an indirect purchase of a random outcome, the exact shape the paid random items rules cover, and the odds disclosure they demand would be awkward and probably unwelcome for kids. Keeping totems crafted keeps the game clearly outside those rules. If the user wants a totem in the welcome pack (6.2), that single fixed consumable in a fixed-content pack is still a judgment call; the safe default is to drop it from the pack and keep the pack cosmetic plus gloves plus one hatch.

### 6.6 Daily rewards (free, needs persistence)

| Day in a row | Gift | Why |
| --- | --- | --- |
| 1 | 10 Esencia | Half a trip |
| 2 | 15 Esencia | |
| 3 | 1 Pelusa + 1 Fogbark (corral feed) | Teaches the corral window |
| 4 | 25 Esencia | |
| 5 | 1 Sello de guarda (Ward Seal) | Teaches the seal |
| 6 | 35 Esencia | |
| 7 | A pen ribbon (cosmetic) + 50 Esencia; the streak restarts | A visible trophy, the week's total is 135 Esencia, under one session's income, so logging in never beats playing (section 8, D1) |

Claimed at the Puesto with a hold, like every reward (server-observed action). No paid "streak repair" in v1: a missed day restarts the streak and that is all.

## 7. Timelines

Assumptions, all to be replaced by the simulator: 6 Esencia per minute active; a trip every 4 minutes; one Night per 20-minute session, yielding 2 to 3 Nightbloom to a balanced player; the corral fills by one creature per session from session 2; the paying player buys the Pase Doble Esencia (349) at minute 3 of session 1 and the welcome pack (99) at minute 6, about 450 Robux in total, and nothing else.

### 7.1 Twenty minutes, free player (first session)

| Minute | What happens | Esencia (banked) |
| --- | --- | --- |
| 0:45 | First steal at the east hook (hub doc section 9) | 0 |
| 1:30 | First extraction: 6 + 4 first steal + 4 trip | 14 |
| 1:45 | Buys Farol tapado (10) | 4 |
| 2:00 | Places the cría in the corral, feeds it a Pelusa: 0.5 per minute for 20 minutes | 4 |
| 6:00 | Second trip extracted (+23) | 27 |
| 6:30 | Skill tier 1 (40) not yet affordable; the card shows "te faltan 13" | 27 |
| 10:00 | Third trip (+23), corral collected (+4) | 54 |
| 10:30 | Learns a tier 1 skill (40, with materials) | 14 |
| 14:00 | Fourth trip, first Night: 2 Nightbloom, an egg (+27) | 41 |
| 14:30 | Egg into the incubator, 90 s | 41 |
| 18:00 | Fifth trip (+23), hatched cría placed and fed; corral now 1 per minute | 64 |
| 18:30 | Second tier 1 skill (40) | 24 |
| 20:00 | Session ends: 2 skills, 2 creatures in the corral, 2 Nightbloom toward tier 2 | about 30 |

### 7.2 Twenty minutes, paying player (first session)

| Minute | What happens | Esencia (banked) |
| --- | --- | --- |
| 0:45 to 1:45 | Same first steal, extraction and Farol | 4 |
| 3:00 | Buys Pase Doble Esencia at the Puesto (first calm hub moment after extraction) | 4 |
| 6:00 | Second trip doubled (+46) | 50 |
| 6:10 | Welcome pack appears after extraction and the first hatch (the first cría hatched from the 1:30 trip's egg, if any; otherwise at 10:00). Buys it: Guantes, 1 hatch, ribbon | 50 |
| 6:30 | Skill tier 1 (40) | 10 |
| 10:00 | Third trip, with gloves about 10 % shorter (+46), corral (+4) | 60 |
| 10:30 | Second tier 1 skill (40) | 20 |
| 14:00 | Fourth trip, Night, 3 Nightbloom (+54) | 74 |
| 14:10 | Egg hatched instantly, cría placed; corral 1 per minute, doubled to 2 | 74 |
| 18:00 | Fifth trip (+46), corral (+8) | 128 |
| 18:30 | Skill tier 2 (100 + 3 Nightbloom) | 28 |
| 20:00 | Session ends: 3 skills including a tier 2, gloves, 2 creatures | about 30 |

The paying player ends session 1 where the free player ends session 2: **about 20 minutes saved in the first 40**, and one impulse purchase (the hatch) spent on a wait of 90 s.

### 7.3 Two hours, free player (six sessions)

| Session | Income (active + corral) | Spent on | State at the end |
| --- | --- | --- | --- |
| 1 | 125 + 4 | Farol, 2 skills tier 1 | 2 creatures |
| 2 | 125 + 20 | Tier 2 (100 + 3 Nightbloom), corral slot 5 (60) | 3 creatures, tier 2 reached at about minute 32 |
| 3 | 125 + 35 | Guantes (80 + materials), third tier 1 (40) | 4 creatures |
| 4 | 125 + 45 | Botas (120), corral slot 6 (150) partly | 5 creatures, incubator level 1 (60) |
| 5 | 125 + 60 | Slot 6 completed, Reinforced Pack (120) | 6 creatures |
| 6 | 125 + 75 | Second tier 2 (100); saving toward incubator level 2 (90) | 7 creatures; about 990 Esencia earned in 2 hours, about 920 spent |

End of 2 hours, free: 4 of 8 skills, Guantes and Botas, Reinforced Pack, 6 corral slots, incubator level 1, 7 creatures, about 70 Esencia in hand. Next goals in sight: incubator level 2 (90, minutes away), slot 7 (350, about 50 minutes), Chaleco (200).

### 7.4 Two hours, paying player (six sessions, about 450 Robux spent)

| Session | Income (doubled) | Spent on | State at the end |
| --- | --- | --- | --- |
| 1 | 250 + 8 | Farol, 2 tier 1, 1 tier 2; gloves from the pack | 2 creatures |
| 2 | 250 + 40 | Slot 5 (60), Botas (120), third tier 1 (40) | 4 creatures |
| 3 | 250 + 70 | Slot 6 (150), Reinforced Pack (120) | 5 creatures |
| 4 | 250 + 90 | Second tier 2 (100), Chaleco (200) | 6 creatures |
| 5 | 250 + 120 | Slot 7 (350) | 7 creatures |
| 6 | 250 + 150 | Incubator levels 1 to 3 (285), fourth tier 1 (40) | 8 creatures; about 1,980 Esencia earned |

End of 2 hours, paying: 6 of 8 skills, three items, Reinforced Pack, 7 corral slots, incubator level 3, 8 creatures. The free player reaches this state at about hour 4: **the pass and the pack save about 2 hours over the first 4**, which is the 2x pass doing exactly what it says. Nothing the paying player owns is unreachable for the free player, and neither player's beasts behave differently.

## 8. Numbers a simulator must check

`tools/simulate_economy.py` reads the `economy-tuning` JSON of `wildbound-economy-p0.md` and refuses any `monetization` other than `"none"`. Before any price is written, it needs three new inputs (`corral`, `items`, `offers` as pure income modifiers, never as purchases) and these assertions. Each names its threshold so a failing run says which hypothesis broke.

| ID | Assertion | Threshold |
| --- | --- | --- |
| **T1** | A free balanced player reaches skill tier 2 (100 Esencia + 3 Nightbloom) | Median within **2 sessions** (40 minutes of session time); p90 within 3 |
| **T2** | A free balanced player finishes the first four steps of every ladder (skills tier 1 x 2, slot 5, incubator level 1) | Median within **1 hour** |
| **Y1** | Paying player (2x pass + welcome pack) versus free, same archetype and seed, to tier 2 | Saves **18 to 25 minutes** (about half); less than 15 means the pass is weak, more than 30 means the free path is too slow |
| **Y2** | Same pair, to the end-of-2-hours free state of 7.3 | Saves **100 to 140 minutes** |
| **N1** | Every ladder step and every item is reachable with Esencia and materials only; no step's cost exceeds 60 minutes of income at the player's current income | Zero unreachable steps; the Nightbloom path through fog beyond the leash stays sufficient for every recipe |
| **N2** | The wave board ranks by units banked; the 2x pass changes no rank | Rank identical with and without the pass over 200 seeded waves |
| **L1** | Ladder ratios | Every step at least 1.4 x the previous; no long-ladder step over 2.5 x |
| **L2** | The 10-step level ladder cumulative time | **8 to 16 hours** of free play at the simulated income with a full corral |
| **L3** | Slot 8 cumulative time, free | **3 to 5 hours** |
| **C1** | Full 8-slot corral of the best realistic mix (4 Común, 2 Rara, 1 Épica, 1 Legendaria) | **9 Esencia per minute at most** while fed, and never more than the owner's active income per minute averaged over a session |
| **C2** | Corral share of total income over 2 hours, free | **Under 35 %**; active play stays the main source |
| **C3** | A player who feeds and then stands still | Income stops at minute 20 of the window and nothing banks without the collect hold (AFK-1, AFK-2 kept) |
| **F1** | Greedy expedition median with Guantes, Botas and Chaleco equipped | **At least 180 s** (the existing floor), and the Chaleco defeat rate for greedy stays above 10 % so risk still exists |
| **F2** | Botas | Rested sprint still outruns the fastest hunt by at least 5 studs/s; sprint cap unchanged |
| **F3** | Guantes | Stationary calm maximum stays below every `calmRequired`, with and without Steady Hands |
| **D1** | Daily rewards, 7-day total | **Under one session's median income** (about 125 Esencia) |
| **H1** | Instant hatch | Saves at most 600 s per use; the biome event egg can save at most 150 s |
| **P1** | Price anchor | Every permanent offer's implied Robux per hour saved lies within **50 to 135**, except the welcome pack and the per-use hatch, which are reported, not bounded |

## 9. What must exist before any purchase

| Need | Why | Status |
| --- | --- | --- |
| Saved progress (persistence) | A permanent item or slot sold into a session-only profile vanishes on leaving, which is a refund case and a broken promise | `docs/mechanics/wildbound-persistence.md` is a proposal with a fake store; DataStore is forbidden today |
| `MarketplaceService.ProcessReceipt`, idempotent by `PurchaseId`, granting inside the same save transaction | Roblox's receipt contract; a receipt must never grant twice or be lost | Not written; must follow the persistence doc's per-key serial queue |
| Game Pass ownership checked on the server at join and on `PromptGamePassPurchaseFinished` | The 2x pass must be server-authoritative | Not written |
| `PolicyService.GetPolicyInfoForPlayerAsync` read at join | Even with nothing random, the result should gate the Puesto for players whose policy restricts paid items, and the result must be cached per player | Not written |
| Creator Hub: products and passes created by the user, prices set by the user | Only the user can create and price them | Not done; needs explicit approval per `AGENTS.md` |
| Tuning: `monetization` becomes `"convenience"` with an `offers` block mirroring section 6, exported by `tools/export_economy_config_luau.py` | Keeps prices and time-saved claims in one checked place; the simulator's refusal of non-`"none"` must be replaced by a check of the invariants in section 8 | Not done |
| Player strings in neutral Spanish, prices in Robux shown before any prompt | Rule 2 of 6.1 | Strings proposed in section 6 |

## 10. Policy checklist for kids

| Rule | How this design keeps it |
| --- | --- |
| Clear prices shown before purchase | Every card and the Puesto show the Robux price and the free equivalent with its time |
| No deception, no false urgency | No countdowns, no fake strike-through prices, the welcome pack has no timer |
| No paid randomness | Nothing sold has a random outcome; totems are crafted only (6.5) |
| Convenience over pay-to-win | Every sold thing is the earned thing, same numbers; skills and totems are never sold; beasts are per player and never change |
| Free path viable | Section 8 N1 and T1 to T2; the timelines show every milestone reached free |
| Respect for a child's attention | Offers never during danger, never in the first 5 minutes, at most 2 contextual cards per session |
| Roblox's rules on paid random items and `PolicyService` | Nothing random; the policy read still gates the Puesto. **Recheck the current Roblox monetization and experience guidelines at implementation**; this document read them only through `docs/wildbound-roadmap.md:415` (2026-11-07) |

## 11. Decisions for the user (one at a time, later)

| ID | Decision | Default if unanswered |
| --- | --- | --- |
| O1 | Sell the 2x income pass at all, or only one-shot conveniences | Sell it; it is the Steal-an-Egg incentive the user named and it touches no rule |
| O2 | Corral slots: free ladder only (Pradera S1) or also sold from slot 6 | Free only until the user says otherwise |
| O3 | Instant hatch: allowed for ordinary eggs, halve-only for event eggs (reopens the incubator doc's "never") | Yes, with the halve-only bound |
| O4 | Welcome pack contents: with or without the totem (6.5) | Without, to stay clearly outside the random-items rules |
| O5 | Price anchor: about 60 to 90 Robux per hour saved | Keep; adjust after the simulator's time estimates |
| O6 | Esencia never sold | Keep |

## 12. What is not verified

Everything. No number here was simulated: the 6 Esencia per minute assumption comes from a simulator that models the forest camp, not the hub walk or the Pradera; the corral rates are the Pradera synthesis's hypotheses; item effects on expedition time and defeat rate are guesses until `simulate_economy.py` models them; the Robux price ranges are design anchors, not market data; no child has read a card; no purchase flow exists; `PolicyService` behaviour for the target audience was not read first-hand. The Roblox policy claims rest on the roadmap's 2026-11-07 reading and must be rechecked at implementation.
