# Wildbound economy and offers: one currency, one tree, honest shortcuts

**Status: design only. Nothing here is built, priced in Creator Hub, played or tested on a phone.** Written 2026-11-09 as the synthesis of the three economy concepts in `docs/design/economy-concepts/` (`skills.md` as the base, with grafts from `idle.md` and `offers.md`), then revised the same day against three refutations (section 17 records every decision). It is the economy of record for the open world: hub in the centre, La Silueta's forest to the west, the kids' Pradera to the east. Every number is a hypothesis. The offline simulator `tools/simulate_hub_economy.py` reads the fenced block of Appendix B at run time and asserts the targets of section 12; its current output is quoted in section 11. Design and code in English; in-game names and player strings in neutral Spanish.

**No purchase is implemented or authorized by this document.** `monetization` stays `"none"` until the user sets up Creator Hub, the purchase handlers and saved progress; DataStore is currently forbidden, so no offer can exist yet (section 10). Robux prices are placeholders from one stated anchor (section 8.3), to discuss, never a price list.

## Quick path

| You are | Read |
| --- | --- |
| The user | Section 1 (the picture), 4 (the tree), 8 (offers), 9 (what is not sold), 11 (simulated timelines), 14 (decisions) |
| The simulator writer | Sections 3, 5, 6, 7, 12 and Appendix B; run `python -I -B tools/simulate_hub_economy.py` |
| A later Studio writer | Section 10 (what must exist first), 13 (code implications) and Appendix A; nothing here authorizes code |
| A reviewer | Section 2 (what was taken from each concept) and section 17 (refutations addressed) |

## 0. Facts this design rests on

| Fact | Source | Why it matters here |
| --- | --- | --- |
| Currency is Esencia in player text, `ember` in code; never lost on defeat; `purchasable = false` | `src/wildbound/WildboundEconomyConfig.luau:31`; `WildboundCampView.luau:23-24` | Section 3 keeps both flags |
| Active income, simulated solo: 19.5 / 23.7 / 22.9 Esencia per trip of 208 / 203 / 190 s; greedy median must stay at or above 180 s | `docs/mechanics/wildbound-economy-p0.md:448-452`; `tools/simulate_economy.py` | About 5 to 6 Esencia per minute of session time once hub turnaround is added; the hub simulator uses 28 per 6-minute cycle |
| Skill tree today: 4 branches x 2 tiers; tier 1 is 40 Esencia + 20 Fogbark + 10 Glowmoss, tier 2 is 100 + 30 + 20 + 3 Nightbloom | `WildboundEconomyConfig.luau:170-235`; `wildbound-economy-p0.md:372-387` | Tiers 1 and 2 keep their ids and totals; the hub simulator cross-checks them against the P0 tuning block |
| `Economy.canPay`, `pay` and `validate` accept only `ember` and material ids listed in `config.materials` | `src/wildbound/WildboundEconomy.luau:155-179` | Role-based costs (`common`, `uncommon`, `rare`) need a code change (section 13) |
| Capture rule: `CALM_REQUIRED` 4.5 s, 4.0 with Steady Hands; stationary maximum about 3.6 s | `docs/mechanics/wildbound-capture.md:53`; `simulate_economy.py:875-941` | No item touches the calm meter |
| Sprint: pool 100, drain 25 per second, multiplier 1.45, cap 24; 5 studs/s margin over the fastest hunt | `src/wildbound/WildboundStamina.luau`; `simulate_economy.py:83-87` | Botas change drain only |
| La Silueta: hunt 13 / 15 / 17, memory 4 / 5 / 6 s, one hunter per player | `src/wildbound/WildboundTuningSchema.luau:42-61` | Amuleto and Ocultismo tier 4 scale memory only |
| The fear client already has a free reduced mode: the world interface's `Reduced` attribute removes the shake and halves the rest | `src/wildbound/WildboundFear.client.luau:10`, `:217` | Fear relief is a free setting ("Modo tranquilo"), never an item (section 6.1) |
| AFK contract: no grant on a timer (AFK-1 source check on Heartbeat, `task.delay`, `task.wait`); an idle hour changes nothing (AFK-2); config `antiAfk.timeBasedGrants = 0`, `idleHourExpectedDelta = 0` | `wildbound-economy-p0.md:415-416`; `WildboundEconomyConfig.luau:252-257` | The corral accrues lazily from timestamps, so AFK-1 stays true as written; AFK-2 and the config block are amended (section 5.2) |
| Leaving discards the profile: `Players.PlayerRemoving` calls `state:removePlayer`; the live server does not require `WildboundPersistence` | `src/wildbound/WildboundServer.server.luau:1890-1906`; `docs/mechanics/wildbound-persistence.md` | Every ladder past the first hour is unreachable today; section 4 to 7 mark each row, and the simulator measures it (`--persistence off`) |
| The proposed record has no equipment, corral, rarity or purchase fields; `TIERS` is `{Safe, Fog, Territory}`; the ledger keeps the newest 64 entries by count | `src/wildbound/WildboundRecord.luau:8`, `:12`, `:14-19`, `:72-76` | Record schema 2 (section 13) adds them, widens `TIERS` and keeps purchases in a list that is never trimmed by count |
| Hub plan: Corral with 8 pens, Incubadora, Tablero, Árbol kiosk, 5 trophy plinths, a Puesto marker with nothing for sale | `docs/design/wildbound-open-world-hub.md:37-50` | Where everything below is shown |
| Pradera corral proposal: 4 free pens, pens 5 to 8 at 60 / 150 / 350 / 800, fed first, 20-minute storage, collect by hold; the beast's leash ends about 246 studs short of the east gate | `docs/design/wildbound-biome-pradera.md:263-282` | The pen ladder is kept; the working rule keys on expedition events, not on position, so the beast-free strip pays no more than the hub (section 5.1) |
| Rarity bands by distance to the beast's home: Común beyond 120 studs, Rara 80 to 120, Épica 45 to 80, Legendaria under 45 | Plan W2; `wildbound-open-world-hub.md:139` | The corral rate keys on it |
| Hatch time 90 s; paying to speed a hatch was ruled out | `docs/mechanics/wildbound-incubator.md:30`, `:34` | No hatch skip is sold |
| Roblox paid random items need odds disclosure; `PolicyService` exposes `ArePaidRandomItemsRestricted` and `IsEligibleToPurchaseCommerceProduct`; no field restricts Developer Products or Game Passes | `docs/wildbound-roadmap.md:415` (read 2026-11-07); refutation of 2026-11-09; **not re-read first-hand** | PolicyService protects nothing here; child protection rests on the surfacing rules, Roblox's own prompt and parental controls (section 10) |
| Experience guidelines: "Mild" fear (pounding heart, creepy NPCs, jump scares) admits the youngest Roblox audience; "Moderate" does not | Refutation of 2026-11-09; **not re-read first-hand** | One open world gets one maturity label; La Silueta decides whether the Pradera's audience can enter at all (decision E11) |

## 1. The economy in one picture

Three loops, one currency, one place to spend it. The ceiling is the same for everyone; Robux buys *when*, never *what*, and never a node of the tree.

| Loop | What the player does | What it yields | Where it goes |
| --- | --- | --- | --- |
| **Steal and extract** (active) | Leave the hub, steal crías and eggs, gather, come back alive | Esencia at extraction, materials, the creature with its rarity | The Árbol first, then the Taller, the Corral and the Incubadora |
| **Corral income** (while you explore) | Place a creature in a pen, feed it one material, go out again, collect on return | Esencia per minute by rarity, at full rate for 3 minutes after each thing you do out there, a quarter otherwise, never more than the corral cap | The same stations |
| **Spend** | Tree nodes, equipment levels, totems, pens, incubator upgrades, breeder levels, cosmetics | Rules bent in your favour (tree), rates multiplied (equipment), one roll bent (totems), a bigger collection (pens), a show (cosmetics, breeder) | Back into the first two loops |

The order a child learns it: the first steal pays the first node; the first node makes the next trip better; the corral keeps paying while you go out, and it can never pay more than a share of what you earn exploring. **What the Puesto says to a parent, and it is true: "Nada de lo que se vende es exclusivo: todo se consigue jugando, y el Árbol nunca se vende."** A level-I piece bought for Robux is the same piece a free player earns, earlier; the card says so (section 8.1 rule 5). The design does not claim that nothing sold helps: an earlier Guantes I helps, which is why only three level-I pieces, pen 6, the Bag and the second incubator are ever sold, why survival (Chaleco) and fear relief are never sold, and why every card waits for the second session.

## 2. What this synthesis took from each concept, and what it dropped

Two independent judgments chose `skills.md` as the base. This section is the audit trail; section 17 records what the refutations changed after it.

| From | Kept here | Why |
| --- | --- | --- |
| `skills.md` (base) | Four branches x five tiers at ratio 2.5, never sold; one 12-step equipment ladder at ratio 1.5; level II needs branch tier 3, level III tier 5; offer thresholds at a 200 Esencia equipment step and a 150 pen step; Guantes as a wake-input multiplier, never the calm meter; a non-cosmetic ceiling | Power is unsellable by construction; the only concept that checked the Guantes invariant |
| `idle.md` | The working rule (now keyed on expedition events, section 5.1); the Nivel de criador as the one unsold 10-step ladder (now prestige only); the explicit "no character begging, no last chance" list; "not alone, not in a bundle, not as a starter pack" | Makes idle income a reason to go out; gives late-game Esencia a sink without selling anything |
| `offers.md` | The Robux-per-hour anchor printed per row; the daily gift table bounded under one session (now 80 Esencia); the cap of two contextual cards per 20 minutes; "what must exist before any purchase"; the kids policy checklist; "no strike-through price unless real"; leaderboards by units banked; corral bounds C1 and C2 | Live-ops instrumentation and the pre-implementation gate the other two lacked |

| Dropped, on purpose | From | Why |
| --- | --- | --- |
| Pase Doble Esencia | `offers.md` | Sells Esencia at half price forever |
| Eclosión al instante, extended hatch times, incubator speed ladder | `offers.md` | A manufactured wait sold back as an impulse buy |
| Pack de bienvenida | `offers.md` | A bundle as a child's first offer, with a luck modifier inside |
| Corral ampliado (pens 5 to 8 as a bundle) | `idle.md` | Bundles pen 5, eight minutes of play |
| Flat corral cap of 12 per minute; pooled per-pen cap of 0.75 | `idle.md`; first synthesis | The first is two to three times active income; the second sat under a single Rara's rate, so rarity stopped paying while plaques promised it (section 17, R2.1) |
| Guantes with a calm-fill multiplier | `idle.md`, `offers.md`, plan I1 | 4.0 / 1.2 = 3.33 s is under the 3.6 s stationary maximum |
| Daily streak with restart | `offers.md` | A loss-aversion hook aimed at kids |
| Equipment offers at the first failed capture or marked hit | `skills.md`, `idle.md` | Selling at a failure moment |

## 3. Currency, materials, rarity and small sources

| Thing | Rule |
| --- | --- |
| **Esencia** (`ember`) | Earned at extraction, at the corral and from the capped small sources below. Never lost on defeat. **Never purchasable with Robux: not alone, not in a bundle, not as a starter pack.** |
| Materials, west | Fogbark, Glowmoss (pouch), Nightbloom (Night only, bag item), as today |
| Materials, east | Pelusa, Espora (pouch), Espora Brillante (rare, bag item) in the same three roles |
| Cross-side recipes | Every recipe asks for roles (`common`, `uncommon`, `rare`), resolved through `materialRoles`: both sides' units count together for `canPay`, and payment spends the biome the player stands in first. This is a new cost shape; section 13 lists the code that changes. A forest player never needs the Pradera and the other way round; no ladder needs a Night |
| Rarity on the item | Stored at the steal from the W2 band of the spawn and saved on the record (schema 2). Today's island tiers map Safe and Fog to Común, FogFar to Rara, Territory to Épica, Heart to Legendaria; a migrated schema-1 entry takes its rarity from `riskTier`, else Común. The PI-1 cría and every biome-event hatchling are Legendaria |
| Extraction payout | Unchanged, so the 180 s floor is untouched |
| Small sources (all capped) | Wave board top 3: 5 / 3 / 2 per wave; beast beaten without a capture: 3 once per wave; first registration of a species: 10 once per species; the daily gift of section 7.3 once persistence exists |
| Leaderboards | Rank by **units banked**, never by Esencia, so no offer can touch a shared board |

## 4. The spine: the skill tree (never sold)

### 4.1 Shape and cost formula

Four branches, five tiers each, twenty nodes. Tiers unlock in order inside a branch; branches are independent. No node is needed to finish any route, cancels a beast, lowers a telegraph under 0.8 s, reads camera or gaze, or affects another player. **The tree has no Robux row**: no node, no tier skip, no respec token.

```text
esencia(t) = round10(40 x 2.5^(t - 1))        t = 1..5, the tier inside a branch
materials(t): common 20 / 30 / 50 / 80 / 120, uncommon 10 / 20 / 30 / 50 / 80, rare 0 / 3 / 5 / 8 / 12
```

| Tier | Esencia | Materials (common, uncommon, rare) | First node of the tier, simulated free balanced player, p50 | Reachable today (no saved progress) |
| --- | ---: | --- | --- | --- |
| 1 | 40 | 20, 10, 0 | 0:15 (Rastreo), 0:20 (Captura) | Yes: two nodes in one 20-minute session |
| 2 | 100 | 30, 20, 3 | 0:55 (p90 1:00), third session | Yes, in one 60-minute sitting (Captura 2) |
| 3 | 250 | 50, 30, 5 | 3:00; all four branches at 7:40 | **Needs saved progress** |
| 4 | 620 | 80, 50, 8 | Not within 10 hours with this purchase order | Needs saved progress |
| 5 | 1,560 | 120, 80, 12 | The long tail | Needs saved progress |

Whole tree: 10,280 Esencia. Tiers 1 and 2 are the eight nodes that exist today. **Through tier 3, a child always has a next node within a session or two**; tier 4 is days of play, and the bridge between tier 3 and tier 4 of a branch is that branch's equipment level II (it needs tier 3, section 6.1), which the kiosk shows as the next goal. Tier 5 is a goal, not a wall: nothing needs it.

### 4.2 The twenty nodes

Names are neutral Spanish player strings; ids keep the existing prefixes. "Rule it must keep" is what the simulator or a Studio suite asserts.

**Rastreo** (`explorer_*`): finding things.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Olfato de senda (exists) | Compass shows gather nodes within 60 studs; on the east also "Pies de nube" (walk 17 in the Pradera, her beast stays 14) | Capture slots stay unmarked |
| 2 | Nariz nocturna (exists) | Rare material shown within 100 studs (Nightbloom at Night; Espora Brillante inside her ground) | Night or beast ground only |
| 3 | Lectura del rastro | The compass tags egg and cría spawns within 80 studs with their rarity icon | Icon only; never the beast's or another player's position |
| 4 | Brújula de ola | For 5 s after a wave starts, an arrow to the nearest Épica or better spawn | Once per wave; the spawn is unchanged and shared |
| 5 | Instinto de refugio | The nearest active Refugio is always marked | Distance information only |

**Captura** (`capturer_*`): stealing cleanly.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Manos firmes (exists) | `calmRequired` 4.5 to 4.0 | Stationary maximum (about 3.6) stays below it |
| 2 | Paso suave (exists) | Retry cooldown 6 to 3 s | Others' reservation unchanged |
| 3 | Anillo amplio | Server ring radius 5.0 to 5.5 | **Gate:** `stationary_calm_max` with radius 5.5 stays below 4.0, else the node becomes "Ojo de sol" (ring shown 0.2 s earlier) |
| 4 | Segunda intención | Once per encounter, a failed capture adds nothing to the parents' wake meter | Parents still wake from light and noise |
| 5 | Abrazo firme | Sprint 2 s with a carried cría before it slips | `carrySpeed > 8` |

**Aguante** (`survivor_*`): lasting longer.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Carga ligera (exists) | Egg walk speed +1, cap 16 | `carrySpeed > 8` |
| 2 | Descanso rápido (exists) | Mark clears in 2 s instead of 5 | Safe zone only |
| 3 | Pulmones | Sprint pool 100 to 120; on the east also "Bolsillo de espora" (bag +1 in the Pradera) | Cap 24 and the 5 studs/s margin unchanged |
| 4 | Piel dura | Defeat loss 20 % to 15 % (750 bp with the Reinforced Pack) | Integer rounding unchanged |
| 5 | Segundo aliento | Once per expedition, when your mark clears, stamina refills | Never during a chase |

**Ocultismo** (`occultist_*`): reading the dark and shaping totems.

| Tier | Node | Effect | Rule it must keep |
| --- | --- | --- | --- |
| 1 | Leer las señales (exists) | "Algo se movió en la niebla" 5 s after an ambush move | No camera or gaze input |
| 2 | Luz larga (exists) | Flashlight reveal 5 s instead of 4 | Overlaps take the max |
| 3 | Tallador | Every totem recipe needs one rare material less, never below 1 | Totem effects unchanged |
| 4 | Sombra | Beast memory of you x0.75; hide-spot entry 0.5 s faster | Telegraph untouched; stacks with Amuleto, floor 2 s |
| 5 | Pacto | Bond XP cap per expedition 40 to 60; pulse cooldown -2 s (floor 23) | XP banks only at extraction |

The Pradera's three proposed nodes fold into this tree as east-side variants, so a child never sees two trees.

## 5. The corral

### 5.1 Rules

| Rule | Decision |
| --- | --- |
| Who produces | Only creatures placed in the owner's pens at the hub Corral |
| Pens | 4 free; pens 5 to 8 at 60 / 150 / 350 / 800 Esencia. Pen 5 is reachable in one sitting today; pens 6 to 8 need saved progress |
| Fed first | Hold "Dar de comer" (1 s) with one common or uncommon material to open a 20-minute window. **A creature can be fed again only after an expedition event since its last feed**, so idle re-feeding at the hub earns nothing new |
| Storage | At most 20 minutes of credited output per creature ("Lleno"). Nothing is credited until the owner holds "Recoger Esencia" (1.5 s) |
| Rates | Común 0.5, Rara 0.75, Épica 1.0, Legendaria 1.5 Esencia per minute. The best realistic mix (4 Común, 2 Rara, Épica, Legendaria) is 6.0 |
| Duplicates | Second creature of the same species and rarity earns half; third and later a quarter |
| **The corral cap** | The corral never credits more than **0.4 x the owner's own extraction income over the last 20 minutes of play, plus 0.3 per filled pen past the four free ones**. There is no pooled per-pen cap. When the cap binds, every creature's rate is scaled by the same factor, so a rarer creature always pays proportionally more and every bought pen raises the cap by 0.3 |
| **The working rule** | **Full rate for 3 minutes after each server-observed expedition event** (a capture, a gather, an extraction, a wave survived), **a quarter rate otherwise while alive in the server**, zero while dead or disconnected. Position does not matter, so standing one stud outside a safe circle, including the beast-free prado strip past the sun circle, pays the quarter rate like the hub. "Tus criaturas trabajan mientras tú exploras" |
| Accrual | **Lazy, never on a timer.** `stored` is computed when the owner feeds, collects, removes or the pen is displayed, from three timestamps per pen and the owner's event log; no Heartbeat, `task.delay` or `task.wait` path writes the economy (AFK-1 holds as written) |
| Offline | Nothing accrues offline. Once saved progress exists, only the stored, uncollected output survives |
| Removing a creature | Free, any time; stored output is collected first |
| Trophies | Never pay Esencia |
| **Display** | Each plaque shows the creature, its owner and the rate **it is crediting now** ("0,6 por minuto · tope del corral" when the cap binds), never a nominal rate. The registration card shows the rate the new creature would credit in this corral now. The Corral sign shows the cap ("Tu corral paga hasta 3,4 por minuto: crece cuando exploras y con cada cercado"). Check: the rate shown on any plaque equals the rate credited over the next minute |

### 5.2 Why this is still "no AFK" in spirit, and what it amends

A window starts only from a gathered material and re-opens only after an expedition event; the full rate needs a recent expedition event; the cap is a share of active income; nothing banks without a hold. It amends, in the same later change: **AFK-2** text to "an idle hour with no feeding changes nothing; with a fed corral, at most the quarter rate for one feeding window"; the config block to `antiAfk.timeBasedGrants = "corralStoredOnly"` and `idleHourExpectedDelta = "quarterRate x one window with a fed corral, else 0"`. **AFK-1** stays as written because accrual is lazy. K8 and K8b assert both (section 12).

### 5.3 Why the cap is a share of active income

The first synthesis capped the corral at 0.75 per pen; a single Rara (1.0) already exceeded it, so rarity paid nothing past the first Rara and the plaques lied. A cap tied to the owner's own extraction income makes three things true at once: the corral can never exceed active play (at 8 filled pens and 6 Esencia per minute of extraction, the cap is 3.6, so the corral is at most about 37 % of income even in the worst case), going out raises what the corral may pay, and every pen still raises the cap. The simulator puts the free corral share at **24 % at 2 hours, 26 % at 4 and 29 % at 8**, under the 35 % target at every horizon (C2). The first lever if it ever comes in over is the 0.4 share, not the rarity rates.

## 6. Equipment, totems: the faster advantages

### 6.1 Equipment pieces: multipliers hung on the tree

Four pieces, three levels. **A piece multiplies a rate on its branch; it never changes a rule, no item touches the calm meter, and no item mutes fear.** Level II needs **tier 3 of its branch**, level III **tier 5**, so levels II and III cannot be bought with Robux by construction.

| Piece (player name) | Branch | Level I | Level II (needs tier 3) | Level III (needs tier 5) | Rule it must keep | Sold for Robux |
| --- | --- | --- | --- | --- | --- | --- |
| **Guantes de ladrón** | Captura | Parents' wake input while you hold a capture x0.8 | x0.7 | x0.6, retry cooldown -1 s (floor 2) | Does not touch the calm meter | Level I only |
| **Botas ligeras** | Rastreo | Sprint drain x0.8 | x0.7 | x0.6 | Cap 24 and the margin unchanged | Level I only |
| **Chaleco acolchado** | Aguante | Once per expedition, the strike that would defeat you marks you instead and drops the newest bag item | Material loss on that defeat x0.75 | x0.5 | Telegraph and strike untouched | **Never** (survival is not sold; decision E10) |
| **Amuleto de calma** | Ocultismo | Beast memory of you x0.75 | x0.5 | x0.5, Refugio stamina regen x3 | Memory floor 2 s; telegraph untouched | Level I only |

**Modo tranquilo (free, never sold).** Fear relief is an accessibility setting in the HUD for everyone: it extends the existing `Reduced` attribute of the world interface to a full mute of the heartbeat and the fear vignette, and removes the shake. No item carries `fearMuted` or any accessibility key; K13 asserts it.

### 6.2 The equipment ladder: one geometric free path

Every equipment level, any piece, any order, is one step on one ladder:

```text
cost(n) = round5(60 x 1.5^(n - 1))        n = 1..12, equipment levels already owned plus one
```

plus materials by level (I: 20 common + 10 uncommon; II: 40 + 20 + 2 rare; III: 60 + 40 + 5 rare). "Cada mejora de equipo cuesta más que la anterior."

| Step | Cost | Cumulative | Free balanced player (simulated, p50) | Reachable today |
| ---: | ---: | ---: | --- | --- |
| 1 | 60 | 60 | Guantes I inside the first hour | Yes (one sitting) |
| 2 | 90 | 150 | Botas I | Needs saved progress |
| 3 | 135 | 285 | Chaleco I | Needs saved progress |
| 4 | 200 | 485 | Amuleto I; all four level-I pieces at 2:29. **First step at which an equipment card may appear** | Needs saved progress |
| 5 to 8 | 305 / 455 / 685 / 1,025 | 2,955 | Level II pieces, each after its branch's tier 3 | Needs saved progress |
| 9 to 12 | 1,540 / 2,305 / 3,460 / 5,190 | 15,450 | Level III pieces, gated by tier 5: the long tail | Needs saved progress |

**Robux and the ladder.** A piece bought for Robux fills the step the player is on, exactly as if paid with Esencia: the ladder is a function of levels owned, so paying never changes the price a free player meets (K5), and the card says so (rule 9).

### 6.3 Totems: consumables that bend one roll, never sold

Crafted at the hub Taller or the forest camp, hold 1 each, one active per player.

| Totem | Cost | Effect | Downside | Why it stays crafted |
| --- | --- | --- | --- | --- |
| **Tótem del último aliento** (exists) | 20 Esencia + 12 uncommon + 2 rare | Wards one extra item on defeat | Detection +6 studs; ambush anchors x2 within 60 | As today |
| **Tótem de la suerte** (plan I2) | **Materials only**: 10 common + 12 uncommon + 2 rare, no Esencia | Placed, 60 s, radius 40: the next egg or cría spawn inside rolls one rarity tier up | Hums: noise as a landing (90 studs) | A luck modifier on a random roll; costing no Esencia, no value that Robux could influence (a Robux-bought pen produces Esencia) ever reaches the roll |
| **Tótem de eco** (new) | 15 Esencia + 10 common + 1 rare | The beast's next acquisition within 30 s prefers the totem for 4 s, once | Loud; a decoy, not a shield | Changes nothing about her speed, telegraph or strike |

## 7. Pens, incubator, breeder levels, daily gift, cosmetics

### 7.1 Pens and incubator

| Upgrade | Free path | What it does | Sold for Robux | Reachable today |
| --- | --- | --- | --- | --- |
| Pen 5 | 60 Esencia | One more producing creature; cap +0.3 | No (minutes away) | Yes (one sitting, about 0:43) |
| Pen 6 | 150 | Same | **Yes, 29 Robux** (section 8) | Needs saved progress (about 1:43) |
| Pens 7, 8 | 350 / 800 | Same; collection room | No: the cap means each adds at most 0.3 per minute, too little to sell honestly | Needs saved progress (pen 7 about 4:49; pen 8 the long tail) |
| Nido cálido I to III | 50 / 125 / 300 | Hatch time x0.8 per level, never below half the base | **No**; hatch speed is never sold | Needs saved progress |
| Segunda incubadora | 250 | Two eggs at once | Yes, 39 | Needs saved progress (about 4:03) |
| Bolsa grande (Reinforced Pack) | 120 Esencia + 60 common + 30 uncommon | Bag 4, pouch 45, loss 10 % | Yes, 49 | Needs saved progress |

### 7.2 Nivel de criador: prestige, never sold

A 10-level account ladder, Esencia only, never sold, never required: `cost(n) = round10(40 x 1.6^(n - 1))`, 40 / 60 / 100 / 160 / 260 / 420 / 670 / 1,070 / 1,720 / 2,750, total 7,250. **It is prestige, and the player text says so**: "Nivel de criador: cintas, plintos y tu nombre en el Corral". Each level grants one pen cosmetic; every second level one more trophy plinth. **It pays no Esencia bonus** (the first synthesis sold "+5 % de corral", which never paid back; section 17, R2.8). It needs saved progress.

### 7.3 Trophy milestones and the daily gift

**Trophies** (5 plinths at the hub, more from breeder levels): first Rara, first Épica, first Legendaria, first biome-event hatchling, the PI-1 theft. Each grants a ribbon and a plaque with owner and date. **Trophies never pay Esencia.** Plaques need saved progress to outlive a session.

**Daily gift** (free, needs saved progress): claimed **at the Tablero** with a hold, never at the Puesto, so the daily habit never ends at a shop. The index counts gifts **claimed**, cycling 1 to 7; a missed day loses nothing.

| Gift | What |
| --- | --- |
| 1 | 5 Esencia |
| 2 | 10 Esencia |
| 3 | 1 common + 1 uncommon material |
| 4 | 15 Esencia |
| 5 | 1 Sello de guarda |
| 6 | 20 Esencia |
| 7 | 30 Esencia + a pen ribbon |

Seven gifts total 80 Esencia, under one simulated first session (111), so showing up never beats playing (D1).

### 7.4 Cosmetics: priced by desire, not by time

Ribbons, hats for corral creatures, pen plaques and pedestal skins. Every cosmetic is buyable for **Esencia** (150 / 400 / 1,000 by tier) and the same item for Robux (49 / 99 / 149); milestone ribbons are earned only. **Cosmetics are priced by desire, not by time saved, and this design says so plainly**: they do nothing, but the Corral shows owner names, so the social-comparison motive is real. Three limits follow: another player's cosmetic never shows a price, only "Se consigue jugando o en el Puesto"; a per-account soft ceiling of 300 Robux of cosmetics per 30 days, after which the Robux column hides and the Esencia column stays; and the whole Robux cosmetic column stays hidden until the maturity label (E11) and whether that audience can transact are confirmed first-hand. Cosmetics are never a card.

## 8. Robux offers (design only, nothing implemented)

### 8.1 Rules every offer keeps

1. **Esencia is never sold**, alone, in a bundle or as a starter pack.
2. **Every offer prints its free path, Esencia and materials, with a time that is true for a typical player.** The time is the simulator's balanced-archetype median for that row (section 8.2), revalidated whenever tuning moves; the player's own figure is shown only when it is lower, based on at least 5 minutes of data, at a floor of 4 Esencia per minute. Never inflated for a struggling player. "Gratis jugando: 200 de Esencia + 20 Pelusa + 10 Espora · ~36 min". Free line first and bigger.
3. **The tree is never sold.** Levels II and III need tree tiers, so they cannot be sold. Breeder levels are never sold.
4. **Nothing random, no totems, no multipliers, no hatch speed, no survival, no fear relief, no accessibility.**
5. **Same item, earlier, said on the card.** Nothing sold is exclusive or stronger than its earned copy; the equipment card states "Es la misma pieza que se gana jugando".
6. **Kids-safe surfacing.** **No Robux card or Puesto row before the player's second session and at least 30 minutes of total play**, and none in the first 5 minutes of any session. A card appears only at the hub in calm, when its free step is visible and meets its threshold, with a plain "No, gracias"; **once per step per session** (a declined card does not return until the step changes or the next session); at most one card per 15 minutes and two per 20-minute session; **never within 60 seconds of a refused action or a notice**; never while marked, chased, inside a beast's ground, on the defeat fade or during a capture. No countdowns, flashing, "last chance", character asking or fake strike-through. **The Puesto shows a Robux row only when that row's card would be eligible**; otherwise it shows the free path alone. Roblox's own purchase prompt is the only confirmation.
7. **Permanent items are Game Passes**, one per item ("Guantes I", "Botas I", "Amuleto I", "Cercado 6", "Bolsa grande", "Segunda incubadora"). The server checks ownership at join and on `PromptGamePassPurchaseFinished`, **refuses to prompt an item the player already owns by any path**, and grants by ownership, so a second purchase of the same item is impossible. The buyer's choice of piece is which pass is prompted; nothing is chosen after payment. No Developer Product (consumable) is used. A failed or timed-out `PolicyService` read caches "restricted" for the session (no cards, free lines only), retried once after 60 s.
8. **A ceiling.** Everything non-cosmetic adds up to **166 Robux, or 215 if a player buys a level-II piece before the fourth level I** (the equipment card needs a 200 step, so at most one or two pieces can ever be sold).
9. **The card says what the purchase does to the ladder**: "Cuenta como un paso del equipo: tu siguiente mejora costará X de Esencia".
10. **One price anchor, printed.** About 60 to 90 Robux per hour of Esencia time per row, band 50 to 135, plus the basket's Robux per hour of progress saved (P1, section 8.3).
11. **Descriptive purchase copy.** The paid line is a noun phrase with the price ("Guantes I · 49 Robux"): never an imperative, never second-person urging, never "solo", "ya", "ahora", "rápido", "última". The simulator lints the `strings` block (K13).

### 8.2 The offers

Times are the simulator's medians for a free balanced player at the moment the card first appears (section 11).

| Offer (player name) | What | Where and when it appears | ~Robux | Free path | Time to earn it (simulated) | Robux per hour | Why it is honest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| **Equipo del explorador** | Guantes I, Botas I or Amuleto I (one pass each), filling the current ladder step | At the hub Taller in calm when the current step costs 200 or more; first seen about 1:40 | 49 | Step 4 onward: 200 Esencia + 20 common + 10 uncommon | ~36 min | 81 | Identical to the crafted piece; Chaleco is never sold; level II and III are earned by everyone |
| **Un cercado más** | Pen 6 | The next calm hub visit after a pen placement was refused, at least 60 s later, with the creature already safe in the collection; first seen about 0:55 | 29 | 150 Esencia | ~28 min | 62 | The same pen; the cap rises by the same 0.3; pens 7 and 8 are not sold |
| **Bolsa grande** | The Reinforced Pack | The calm hub return after two "Bolsa llena" notices in one session, from the second session on; first seen about 0:45 | 49 | 120 Esencia + 60 common + 30 uncommon | ~25 min | 118 (small ticket) | The same pack the P0 economy sells for Esencia |
| **Segunda incubadora** | A second incubator slot | At the Incubadora the first time a second egg is banked while one incubates | 39 | 250 Esencia | Not triggered by the simulator's one-creature-per-cycle model | n/a | Convenience; hatch speed is never sold |
| **Cintas y sombreros** | Cosmetics | The Corral tab, never a card; hidden until E11 is decided (section 7.4) | 49 / 99 / 149 | 150 / 400 / 1,000 Esencia | Priced by desire | n/a | Do nothing; another player's price is never shown |

### 8.3 Where the prices come from

Each permanent price is the row's simulated time to earn, times the anchor, rounded. The per-row figure is **time to earn the Esencia and materials**, not progress saved, and the card says "Gratis jugando: … · ~N min", never "ahorras". The progress a payer actually gains is measured separately (K3): the realistic basket (Bolsa grande, pen 6 and one piece, 127 Robux) brings the payer to a point the free player reaches **60 minutes later**, so the basket costs about **127 Robux per hour of progress saved**, above the 60 to 90 anchor but inside the 50 to 135 band. If the user wants the basket inside the anchor, the first lever is Bolsa grande at 29 (decision E6).

### 8.4 Where the incentive comes from

The free price of the next equipment level rises by half at each step while the Robux price stays flat, so the shortcut's value grows with the player's investment, not with frustration. The incentive is deliberately modest: the payer's two-hour Esencia income is 1.06x the free player's and the free-price value of everything a card granted brings the two-hour comparison to 1.62x (K4, K4b). The tree, the thing the child is building, has no price tag.

## 9. What is NOT sold, and the free-path guarantee

| Never sold | Why |
| --- | --- |
| Esencia, in any form | Rule 1 |
| Any tree node, tier skip or respec | The tree is the power ladder |
| Equipment level II or III; Chaleco at any level | Gated by tree tiers; survival is not sold (E10) |
| **Fear relief or any comfort or accessibility setting** | Modo tranquilo is free; selling the thing that makes a horror game less frightening would monetize distress |
| Any totem | Crafted only; the luck totem costs no Esencia |
| A 2x or any income multiplier | Teaches not playing |
| Hatch skips, hatch speed, extended hatch times | Manufactured waits |
| Pen 5, pens 7 and 8, any step under its threshold | Minutes away, or worth too little under the cap to sell honestly |
| Nivel de criador | Prestige stays earned |
| Anything random, any bundle, any starter pack, anything in the first session | Rules 1, 4, 6 |

**The free-path guarantee**, asserted by the simulator: every `offers` row has a free path and grants no tree, totem, multiplier, hatch or level above I; a free balanced player with saved progress owns tier 3 in every branch (7:40), all four level-I pieces (2:29), pen 7 (4:49) and the second incubator (4:03) within **8 hours** (K6); the whole tree, every level III, pen 8 and breeder level 10 are the long tail. Nothing a payer owns is unreachable, and neither player's beasts behave differently.

## 10. What must exist before any purchase (pre-implementation gate)

| Need | Why | Status |
| --- | --- | --- |
| **Maturity label decided (E11)**: complete Roblox's experience questionnaire and confirm the resulting label admits the intended audience; confirm first-hand whether that account type can buy Game Passes and under what parental approval | One open world gets one label. La Silueta's grin, defeat flow and any blood decide whether the Pradera's youngest players can enter at all; the kids checklist below is conditional on that answer | Not done |
| Saved progress (persistence, record schema 2) | Offers need the session index, cumulative minutes and "once per step" across sessions; a ladder step bought into a session-only profile vanishes. Game Pass ownership itself is held by Roblox and re-checked at join, so a pass survives without DataStore (unverified first-hand), but the progress around it does not | `docs/mechanics/wildbound-persistence.md` is a proposal; DataStore is forbidden today |
| Game Pass handling: ownership checked at join and on `PromptGamePassPurchaseFinished`; prompt refused server-side when owned by any path; grant inside the profile; a pass bought while the item was somehow owned grants nothing and is logged for manual refund | Server-authoritative; a second charge for an owned item must be impossible | Not written |
| If a Developer Product is ever proposed: `ProcessReceipt` returns `NotProcessedYet` until the record containing the `PurchaseId` is committed; a `PurchaseId` already in `purchases[]` returns `PurchaseGranted` without re-granting; `purchases[]` is never trimmed by count | Roblox may redeliver a receipt late; the 64-entry ledger could have rolled it off | Not proposed; Game Passes are the design |
| `PolicyService.GetPolicyInfoForPlayerAsync`: `ArePaidRandomItemsRestricted` is kept only as a tripwire in case a random item is ever proposed; it gates nothing today. A failed read caches "restricted" for the session (free lines only), retried once after 60 s | PolicyService exposes no field that restricts Game Passes or Developer Products; it is not child protection here | Not written |
| Creator Hub: passes created and priced by the user | Only the user can; needs explicit approval per `AGENTS.md` | Not done |
| Tuning: `monetization` becomes `"convenience"`; the simulators' refusal of anything but `"none"` is replaced by the checks of section 12 | Prices and time claims live in one checked place | Not done |
| Player strings in neutral Spanish, linted (rule 11) | Rules 2, 6, 11 | Proposed in Appendix B `strings` |
| First-hand re-read of Roblox's paid random items, Game Pass, Developer Product, experience guidelines and PolicyService pages | Every economy document so far relies on secondary summaries | Not done |

### Policy checklist for kids (conditional on E11)

| Rule | How this design keeps it |
| --- | --- |
| Clear prices before purchase | Robux price on the button, free path with true time first; Roblox's prompt is the only confirmation |
| No deception, no false urgency | No countdowns, flashing, fake strike-through, character asking, "last chance", bundle or starter pack; descriptive copy only (rule 11); the Puesto headline is true (section 1) |
| No paid randomness | Nothing sold is random; totems are crafted; the luck totem costs no Esencia. **Claim to confirm first-hand:** a Robux-bought pen is an income generator, not a purchasable currency, and Esencia itself is never sold, so play-earned Esencia spent elsewhere is not "currency Robux can buy"; the materials-only luck totem makes the argument unnecessary for random rolls |
| Convenience over pay-to-win | Three level-I pieces, pen 6, the Bag and the second incubator, each the earned item earlier; survival, fear relief, the tree, levels II and III, totems and breeder levels never sold |
| Free path viable | K1, K2, K6; paying bounded by K3, K4 and K4b |
| Respect for a child's attention | Nothing before the second session and 30 minutes; 5 quiet minutes every session; one card per 15 minutes, two per session, once per step per session; never within 60 s of a refusal or notice; never in danger |
| No loss-aversion hooks | Daily gift counts claims, at the Tablero; nothing lost by not logging in; nothing accrues offline |
| Fear is not monetized | Modo tranquilo is free for everyone |
| Protection does not rest on PolicyService | It rests on the surfacing rules, Roblox's prompt and parental spend controls |

## 11. Timelines (simulated, not played)

From `python -I -B tools/simulate_hub_economy.py --sessions 30` on 2026-11-09 (30 seeded runs, persistence on unless stated). The model: 20-minute sessions of a 2-minute first steal, then 6-minute cycles of 5 minutes out and 1 at the hub; 28 Esencia per cycle plus the bonuses of Appendix B; 12 common and 6 uncommon materials per cycle and 3 rare every third cycle; one creature home per cycle on a fixed rarity script; the corral rules of section 5; the free priority of Appendix B, then cheapest first. No defeats, beasts, totems or time of day: those belong to `tools/simulate_economy.py`.

### 11.1 Free player

| Time | Owned (p50) | Earned so far: active + corral (share) |
| --- | --- | --- |
| 0:03 | Farol tapado | |
| 0:15 / 0:20 | Rastreo 1, Captura 1; four pens filled | 0:20: 99 + 12 (11 %) |
| 0:43 | Pen 5 | |
| 0:55 | First tier-2 node (Captura 2), third session | 1:00: 311 + 80 (20 %) |
| 1:43 | Pen 6 | 2:00: 640 + 200 (24 %) |
| 2:29 | All four level-I pieces | |
| 3:00 | First tier-3 node | |
| 4:03 / 4:49 | Second incubator; pen 7 | 4:00: 1,300 + 468 (26 %) |
| 7:40 | Tier 3 in every branch | 8:00: 2,671 + 1,065 (29 %) |

### 11.2 Paying player (accepts every card the rules allow)

The first session is identical to the free one: no card exists before the second session and 30 minutes. Cards appear first at about 0:45 (Bolsa grande), 0:55 (pen 6) and 1:40 (equipment step 4); the minimum gap is 15 minutes, never more than one per session in these runs, no step shown twice. Robux spent: 127. At 2:00 the payer has earned 674 + 221 (1.06x free) and owns 1,145 Esencia-equivalent of progress against the free player's 825; the free player reaches it 60 minutes later.

### 11.3 What the game can do today (persistence off)

| Horizon | Owned by at least half the runs |
| --- | --- |
| One 20-minute session | Farol tapado, Rastreo 1, Captura 1, four pens filled |
| One 60-minute sitting | Also Aguante 1, Captura 2, Guantes I, pen 5 |

Everything else in sections 4 to 8 needs saved progress, and every offer does. This is decision E12.

## 12. What the simulator checks

`tools/simulate_hub_economy.py` reads Appendix B, refuses any `monetization` other than `"none"`, models offers only as purchase modifiers in a paying policy, and exits non-zero when a check fails. `tools/simulate_economy.py` is unchanged; the hub simulator imports it for the P0 tuning and shared helpers. Results are from the run of section 11.

| # | Check | Threshold | Simulated |
| --- | --- | --- | --- |
| K1 | First tier-2 node, free | p50 within 3 sessions | 0:55 (session 3) |
| K2 | First tier-3 node; all level-I pieces | 3 h; 2 h 30 | 3:00; 2:29 |
| K3 | Minutes the free player needs to reach the payer's 2-hour progress | 30 to 90 | 60 |
| K4 | Payer's Esencia earned at 2 h / free | at most 1.3 | 1.06 |
| K4b | (Payer's earned + free price of everything a card granted) at 2 h / free earned | at most 1.65 (E13) | 1.62 |
| K5 | Paying never changes free prices | same price per step | holds |
| K6 | Tier 3 everywhere, all level-I pieces, pen 7, second incubator | within 8 h | all within 7:40 |
| C1 | Credited corral never exceeds the cap; best realistic nominal mix | cap; at most 6.0 | holds; 6.0 |
| C2 | Corral share, free and paying, at 2, 4 and 8 h | under 35 % free, 40 % paying | 24 / 26 / 29 %; 25 / 27 / 29 % |
| C3 | Working rule | quarter rate outside the active window, zero dead or away | holds (pure check) |
| K8 | Idle hour with a fed corral | at most the quarter rate for one window; re-feeding needs an expedition; zero unfed | holds (pure check) |
| K8b | Standing still outside every safe circle for 20 minutes | no more than the hub quarter rate | holds by construction (rate keys on events) |
| K12 | Ladders | tree 2.5, equipment 1.5, pens 60 / 150 / 350 / 800, breeder 1.6 and not sold; tiers 1 and 2 equal the P0 costs | holds |
| K13 | Policy shape | nothing random; currency not purchasable; every row a Game Pass with `needsPersistence`; no row grants a tree, totem, multiplier, hatch, Esencia or level above I; no accessibility key on any piece; Modo tranquilo free; no card before session 2 and 30 minutes; daily gift not at the shop; Puesto rows only when eligible; descriptive, linted copy; estimate from the design median with materials; ceiling printed equals the computed one and stays under 500; in the paying runs, 15 minutes between cards, at most 2 per session, no step repeated in a session | holds |
| K14 | Totems | none sold; luck totem materials only; Tallador floor 1 | holds |
| K15 | First Esencia and first producing creature | within 2 minutes at the model's one-minute resolution (the 90 s rule is a Studio check) | 2; 2 |
| P1 | Robux per hour of Esencia time per row; basket per hour of progress saved | 50 to 135 each | 62 / 81 / 118; 127 |
| D1 | Seven daily gifts under one first session's income | under | 80 < 111 |
| R1 | The "reachable today" partition of sections 4 to 7 | declared session and sitting items reached at p50 with persistence off; declared persistence items not reached in a 60-minute sitting | holds |

Not modelled, still owned by `tools/simulate_economy.py` or a Studio suite: K9 (expedition floor 180 s with the new pieces), K10 (calm invariant with Anillo amplio), K11 (escape invariant with Pulmones and Botas), N2 (leaderboards).

## 13. Code implications (not authorizations)

For a later writer, after the user's decisions and, for section 8, after section 10.

| Where | What |
| --- | --- |
| `docs/mechanics/wildbound-economy-p0.md` tuning block, `tools/export_economy_config_luau.py` and its test, `src/wildbound/WildboundEconomy.luau` (`canPay`, `pay`, `validate`), `tests/WildboundEconomy_Test.luau` | **Role-based cost shape**: `cost = { ember = 40, common = 20, uncommon = 10 }` resolved through `materialRoles`; `canPay` counts both sides' units together; `pay` spends the current biome's material first, then the other side; `validate` accepts role keys. The eight existing rows migrate to roles with the same ids and totals. Twelve new skill rows with `effectLive = false` until wired; `equipment`, `totems`, `corral`, `breeder`, `incubator`, `dailyGift`, `cosmetics` blocks; `monetization` stays `"none"` |
| `WildboundRecord.luau`: **record schema 2** | `collection.registered[].rarity` and `riskTier`; `equipment = { guantes, botas, chaleco, amuleto }`; `corral = { slots, pens[] = { uid, fedUntilUnix, lastAccrualUnix, storedEsencia } }`; `eventLog` reduced to the last active-window end; `breederLevel`; `cosmetics[]`; `giftClaims`; `offersShown[] = { row, step, sessionIndex }`; `sessionIndex`, `cumulativeMinutes`; `purchases[] = { purchaseId or passId, item, grantOp, atUnix }` kept outside `LEDGER_CAP` and never trimmed by count; `TIERS` widened to `FogFar` and `Heart`; migration 1 to 2 sets rarity from `rarity.fromRiskTier`, else Común |
| `WildboundState` | Rarity on pending and registered entries; equipment levels with `NeedsBranchTier`; the expedition-event timestamps the working rule reads (capture, gather, extraction, wave), set where `player.expedition` is set and cleared today; `Learn` keeps its refusals |
| New `WildboundCorral.luau` (pure) | Rates, duplicates, the cap from the owner's rolling extraction income and filled pens, proportional scaling, storage, feeding with the expedition-since-last-feed rule, the working rule from event timestamps, lazy accrual from unix times; contracts C1, C2, C3, K8, K8b and "plaque equals credited" |
| AFK contracts | AFK-1 unchanged (no timer writes); AFK-2 text and `antiAfk` config amended as in section 5.2, in the same change as `WildboundCorral` |
| `WildboundWorldRules`, tuning schema | The hub circle as a named zone constant (display only; the working rule does not key on position); every new constant of Appendix A under a new `Economía` system |
| `WildboundFear.client.luau` and the HUD | Modo tranquilo: a HUD toggle that sets the world interface's `Reduced` attribute and mutes heartbeat and vignette fully |
| HUD and hub views | Tree kiosk; pen plaques with the credited rate and "Lleno"; the Corral cap sign; the offer card with the free line first, the ladder sentence and descriptive copy; strings in `WildboundText` |
| `tools/simulate_hub_economy.py` | Exists; extend when the corral or offers change. Add defeats and a second-egg model if the incubator card must be exercised |
| Nothing | `MarketplaceService`, passes, prices: not until section 10 is met and the user approves explicitly |

## 14. Decisions for the user (one at a time, later)

| ID | Decision | Recommendation |
| --- | --- | --- |
| E1 | Esencia never sold, in any form | Keep |
| E2 | The tree is never sold; levels II and III gated by tree tiers | Keep |
| E3 | Corral: rates 0.5 / 0.75 / 1.0 / 1.5, duplicates at half and a quarter, **cap 0.4 x own extraction income + 0.3 per extra filled pen**, the event-keyed working rule, lazy accrual, plaques show the credited rate | Yes; simulated share 24 to 29 % |
| E4 | Nivel de criador as prestige only, no Esencia bonus | Yes |
| E5 | Offers: three level-I pieces, pen 6, Bolsa grande, Segunda incubadora; 166 to 215 Robux non-cosmetic; all Game Passes | Yes; prices are placeholders |
| E6 | Price anchor 60 to 90 Robux per hour of Esencia time; the basket lands at 127 per hour of progress saved | Keep the band 50 to 135; lower Bolsa grande to 29 if the basket should sit inside the anchor |
| E7 | Daily gift counted by claims, 80 Esencia per seven, at the Tablero, persistence-gated | Yes |
| E8 | Cosmetics for Esencia and Robux, priced by desire, 300 Robux soft ceiling per 30 days, never another player's price, Robux column hidden until E11 | Yes |
| E9 | Dropped: 2x pass, hatch skips, extended hatch times, welcome pack, Corral ampliado, pens 7 and 8 as offers | Confirm |
| E10 | Robux equipment row: Guantes I, Botas I, Amuleto I; Chaleco (survival) never sold | Yes; the alternative is to drop Amuleto too and accept that the equipment card rarely triggers |
| E11 | Target maturity label for the whole open world, which bounds La Silueta's grin, defeat flow and blood | Aim for the label that admits the Pradera's audience; complete the questionnaire before any offer |
| E12 | Accept a design whose mid-game (tier 3 onward, equipment steps 2 onward, pens 6 to 8, breeder, incubator upgrades, every offer) cannot be experienced until saved progress (D8 / M6) is approved | Yes, with the session-only rows (section 11.3) as the playtest target now |
| E13 | K4b bound: payer's earned plus granted value at 2 h at most 1.65x free (the refutation proposed 1.6; the realistic basket lands at 1.62) | Accept 1.65, or drop Bolsa grande from the basket to reach 1.6 |

## 15. Hypotheses and what would falsify them

| Hypothesis | Falsified by |
| --- | --- |
| A child reads the tree as "what the game is about" and names a next node | Testers cannot say what a branch does |
| "The creature earns while I explore" is understood from the plaque and the cap sign | Testers park at the hub, or corral share passes 35 % in logs |
| Equipment reads as "my gloves make my Captura better" | Testers cannot say which branch unlocked a level-II piece |
| 2.5 per tier reads as a goal through tier 3 | Testers stop naming a next node after tier 2 |
| A flat Robux price beside a rising free step reads as a shortcut | A tester calls an offer "the only way" |
| "Nada de lo que se vende es exclusivo" is noticed and trusted | A parent asks whether skills can be bought after reading the Puesto |
| The printed free-path time is true | Players' actual times run more than 30 % over the printed median |
| Offers only at calm hub moments convert honestly | Declines followed by quitting, or purchases clustered after defeats |
| Modo tranquilo is found by the children who need it | Testers who report fear never open the setting |

## 16. Unverified

No number has met a child, a phone or a Studio build. The section 11 numbers are a deterministic model with a fixed rarity script and no defeats; real income will vary and may be lower for young players. The Roblox policy facts in section 0 (PolicyService fields, maturity bands, Game Pass ownership surviving without DataStore, whether Roblox Kids accounts can buy passes) come from secondary summaries and the refutation, not a first-hand read. The Anillo amplio radius has not met `stationary_calm_max`. The second-incubator card is never triggered by the model. K9 to K11 and N2 are not run by the hub simulator.

## 17. Refutations addressed

Three refutations (R1 kids policy and honesty, R2 numbers, R3 buildability) were received on 2026-11-09. Every problem below was judged real; the decision and where it lives are listed. Nothing was rejected outright; two points (R1.11, R1.12) are resolved with a stated argument plus a fallback rather than a rule change alone.

| # | Problem | Decision | Where |
| --- | --- | --- | --- |
| R1.1 | Amuleto I sold fear relief | Fear muting is a free HUD setting (Modo tranquilo, extending `Reduced`); Amuleto I keeps only beast memory; no sold item carries an accessibility key (K13) | 6.1, 9, App. B `accessibility` |
| R1.2 | "Nothing that makes you better is sold" was false | Puesto headline rewritten to the true sentence; cards say "same piece, earlier"; Chaleco removed from sale (E10) | 1, 8.1 rule 5, 14 |
| R1.3 | Puesto browsable from minute 1; daily gift at the shop | Robux rows shown only when eligible, never in the first session; daily gift moved to the Tablero | 7.3, 8.1 rule 6 |
| R1.4 | First-session card at 0:20 contradicted 11.2 | `firstOfferMinute` replaced by session 2 and 30 cumulative minutes; timelines regenerated by the simulator | 8.1 rule 6, 11 |
| R1.5 | Estimate from own income pressured struggling players and omitted materials | Design median per row from the simulator; own figure only if lower; materials printed | 8.1 rule 2, 8.2 |
| R1.6 | Pen card at the refused-placement moment, three cards in 30 minutes | Next calm hub visit after the refusal, at least 60 s later, creature safe; only pen 6 is sold; once per step per session | 8.1 rule 6, 8.2 |
| R1.7 | PolicyService described a protection that does not exist | Rewritten: tripwire only; protection rests on the rules, Roblox's prompt and parental controls | 10 |
| R1.8 | No maturity-label gate | Questionnaire and label are the first row of section 10; E11; checklist made conditional | 0, 10, 14 |
| R1.9 | One-time items as consumable products could be charged twice | Every permanent item is a Game Pass; prompt refused when owned; choice is the pass prompted | 8.1 rule 7, 10 |
| R1.10 | No rule on purchase copy | Rule 11 and `offerRules.purchaseCopy = "descriptive"`; the simulator lints `strings` | 8.1, App. B |
| R1.11 | Paid-randomness argument unwritten | Argument written and marked to confirm; fallback adopted now: the luck totem is materials-only | 6.3, 10 checklist |
| R1.12 | Cosmetics above the anchor, social motive unaddressed | Stated as priced by desire; soft ceiling; others' prices hidden; Robux column gated by E11 | 7.4 |
| R2.1 | Pooled per-pen cap under a Rara's rate; plaques lied | No pooled cap; lower rates; cap scales every plaque proportionally; plaques show the credited rate | 5.1, 5.3 |
| R2.2 | Parked AFK income past the sun circle | Full rate keyed on expedition events, not position; K8b | 5.1, 12 |
| R2.3 | C1 contradicted itself; breeder bonus after the cap | Cap is a share of the owner's own extraction income; breeder pays no Esencia; C2 checked at 2, 4 and 8 h | 5.1, 7.2, 12 |
| R2.4 | Bolsa card had no threshold | Session 2 onward, after two "Bolsa llena" notices in a session | 8.2 |
| R2.5 | "Once per trigger" was a recurring nag | Once per step per session; K13 asserts no repeat | 8.1 rule 6, 12 |
| R2.6 | Anchor argued on Esencia time while the payer gets progress | Both printed: per-row time to earn and the basket's Robux per hour of progress saved (127) | 8.3, 12 P1 |
| R2.7 | K4 bounded income but not advantage | K4b added (earned plus free price of grants), 1.62 against 1.65 (E13) | 12, 14 |
| R2.8 | "+5 % corral" never paid back | Breeder ladder is prestige; no Esencia bonus | 7.2 |
| R2.9 | "Next node within one session" false for tier 4 | Scoped to tier 3; equipment level II named as the bridge | 4.1 |
| R2.10 | Printed ceiling unreachable | Computed ceiling 166 to 215, asserted equal to the printed one | 8.1 rule 8, 12 K13 |
| R2.11 | Own-income estimate had no floor | Design median; own figure only if lower, at least 5 minutes of data, floor 4 per minute | 8.1 rule 2 |
| R2.12 | Idle re-feeding every 20 minutes | Re-feeding needs an expedition event since the last feed; K8 bound is one window | 5.1, 12 |
| R3.P1 | Free ladders unreachable without persistence | "Reachable today" columns, R1 partition check, `--persistence off` report, E12 | 4.1, 6.2, 7, 11.3, 14 |
| R3.P2 | Record schema cannot carry the design | Record schema 2 with migration, widened `TIERS`, `purchases[]` outside `LEDGER_CAP` | 13 |
| R3.P3 | Cross-session surfacing rules with no fallback | Offers do not exist without saved progress, so the session rules are persistence-backed by construction; the per-session quiet minutes apply in every session; `offerRules.needsPersistence` lists them | 8.1, App. B |
| R3.P4 | Role costs not expressible in the current shape | Role cost shape specified with spend order and the code that changes | 3, 13 |
| R3.P5 | Corral accrual against AFK-1 and the config | Lazy accrual from timestamps; AFK-2 and `antiAfk` amended in the same change; hub circle as a named constant | 5.1, 5.2, 13 |
| R3.P6 | No simulator for the hub economy | `tools/simulate_hub_economy.py` with tests, sessions, corral, ladders, offers and `--persistence on/off/both` | 11, 12 |
| R3.P7 | PolicyService failure not fail-closed | Failed read caches "restricted" for the session, one retry after 60 s | 8.1 rule 7, 10 |

## Appendix A. Constants for `WildboundEconomyConfig.luau` and the tuning schema

Config paths are the keys a later `economy-tuning` block would carry; the tuning column proposes `WildboundTuningSchema.luau` entries under a new `Economía` system. Nothing here is written yet. Rows unchanged from the first synthesis (tree node effects, equipment ladder, totem timings, incubator) keep their values from Appendix B.

| Config path | Value | Tuning key (Spanish label; min, max, step) | Module that reads it |
| --- | --- | --- | --- |
| `currency.purchasable` | `false` | none (contract) | `WildboundEconomyConfig` |
| `materialRoles` | common fogbark / pelusa; uncommon glowmoss / espora; rare nightbloom / esporaBrillante; `costShape` roles; current biome spent first | none | `WildboundEconomy` |
| `rarity.bandsByDistance` | Legendaria [0, 45), Épica [45, 80), Rara [80, 120), Común beyond | `RARITY_LEGENDARIA` (Legendaria hasta (studs); 20, 80, 5), `RARITY_EPICA` (30, 120, 5), `RARITY_RARA` (60, 200, 5) | spawn graph |
| `accessibility.modoTranquilo` | free; mutes heartbeat, vignette and shake | none (contract) | `WildboundFear.client`, HUD |
| `tree.*` | as Appendix B; `sold` and `respec` false | as the first synthesis (`ICON_RANGE`, `WAVE_ARROW`, `RING_RADIUS_WIDE`, `CRIA_SPRINT`, `SPRINT_POOL_3`, `LOSS_BP_4`, `MEMORY_FLOOR`) | `WildboundEconomyConfig.skills` and the readers named in 4.2 |
| `equipment.soldPieces` / `soldLevels` | guantes, botas, amuleto / I | none (contract) | offers |
| `equipment.pieces.amuleto.I` | `beastMemoryScale` 0.75 only | `AMULETO_MEMORY_I` (Amuleto I: memoria de la bestia (x); 0.5, 1, 0.05) | `WildboundGuardianBrain` |
| `totems.suerte.cost` | 10 common + 12 uncommon + 2 rare, no Esencia | none | recipes |
| `corral.ratePerMinute` | Común 0.5, Rara 0.75, Épica 1.0, Legendaria 1.5 | `RATE_COMUN` (Común (Esencia/min); 0, 2, 0.05), `RATE_RARA`, `RATE_EPICA`, `RATE_LEGENDARIA` (0, 4, 0.05) | `WildboundCorral` |
| `corral.activeIncomeCap` | `share` 0.4, `perExtraPen` 0.3, `windowMinutes` 20 | `CORRAL_SHARE` (Tope: parte de lo que ganas explorando (x); 0.1, 1, 0.05), `CORRAL_PER_PEN` (Tope por cercado extra (Esencia/min); 0, 1, 0.05) | same |
| `corral.rateShare` / `activeWindow.minutesAfterEvent` | 1.0 / 0.25 / 0 ; 3 | `HUB_SHARE` (Ritmo sin explorar (x); 0, 1, 0.05), `ACTIVE_WINDOW` (Minutos de ritmo completo; 1, 10, 0.5) | same |
| `corral.feed` | 1 common or uncommon, 20-minute window, re-feed needs an expedition event | `FEED_WINDOW` (Ventana de comida (min); 5, 60, 1) | same |
| `corral.storageMinutes` | 20 | `STORAGE_MIN` (Almacena hasta (min); 5, 60, 1) | same |
| `breeder` | 1.6 ladder, no Esencia bonus, cosmetic every level, plinth every 2, not sold | none | hub views |
| `dailyGift` | 5, 10, materials, 15, seal, 20, 30 + ribbon; at the Tablero; needs persistence | none | Tablero (later) |
| `cosmetics` | 150 / 400 / 1,000 Esencia; 49 / 99 / 149 Robux; soft ceiling 300 per 30 days; others' prices hidden; Robux column gated by E11 | none | Corral tab |
| `policy` | Game Passes; ownership at join and on purchase finished; prompt refused when owned; PolicyService fail-closed | none (contract) | nothing today |
| `offerRules` | session 2 and 30 minutes; 5 quiet minutes per session; 15 minutes apart; 2 per session; once per step per session; 60 s after a refusal or notice; descriptive copy; design-median estimate with materials; ceiling 166 to 215 under 500 | none (contract, K13, P1) | nothing today |
| `monetization` | `"none"` | none | both simulators refuse anything else |

## Appendix B. Tuning block for the simulator

Read at run time by `tools/simulate_hub_economy.py` (schema version 2). It is not the P0 `json economy-tuning` block; a later writer merges the economy rows into it. `monetization` stays `"none"`; `offers` are design rows, not products. `simulatorInputs` are the simulator's assumptions, not game data.

```json economy-synthesis
{
  "schema": "wildbound.economy.synthesis",
  "schemaVersion": 2,
  "status": "hypothesis",
  "monetization": "none",
  "currency": { "id": "ember", "playerName": "Esencia", "lostOnDefeat": false, "purchasable": false },
  "materialRoles": {
    "common": ["fogbark", "pelusa"], "uncommon": ["glowmoss", "espora"], "rare": ["nightbloom", "esporaBrillante"],
    "crossSideUnitForUnit": true, "costShape": "roles", "spendOrder": "currentBiomeFirstThenOtherSide"
  },
  "rarity": {
    "bandsByDistance": { "Legendaria": [0, 45], "Epica": [45, 80], "Rara": [80, 120], "Comun": [120, null] },
    "fromRiskTier": { "Safe": "Comun", "Fog": "Comun", "FogFar": "Rara", "Territory": "Epica", "Heart": "Legendaria" },
    "storedOnRecord": true, "migrationDefault": "fromRiskTierElseComun"
  },
  "leaderboards": { "rankBy": "unitsBanked", "neverByEsencia": true },
  "accessibility": {
    "modoTranquilo": { "free": true, "sold": false, "surface": "hudSettings", "effects": { "heartbeatMuted": true, "vignetteMuted": true, "shakeMuted": true }, "extends": "WildboundFear Reduced attribute" }
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
    "ladder": { "base": 60, "ratio": 1.5, "round": 5, "steps": 12, "stepCounts": "levelsOwnedAnyPiece", "paidStepsCount": true, "cardStatesStep": true },
    "costs": [60, 90, 135, 200, 305, 455, 685, 1025, 1540, 2305, 3460, 5190],
    "materialsByLevel": { "I": { "common": 20, "uncommon": 10 }, "II": { "common": 40, "uncommon": 20, "rare": 2 }, "III": { "common": 60, "uncommon": 40, "rare": 5 } },
    "levelGates": { "II": { "branchTier": 3 }, "III": { "branchTier": 5 } },
    "pieces": {
      "guantes": { "branch": "capturer", "I": { "captureWakeInputScale": 0.8 }, "II": { "captureWakeInputScale": 0.7 }, "III": { "captureWakeInputScale": 0.6, "retryCooldownDelta": -1, "retryCooldownFloor": 2 } },
      "botas": { "branch": "explorer", "I": { "sprintDrainScale": 0.8 }, "II": { "sprintDrainScale": 0.7 }, "III": { "sprintDrainScale": 0.6 } },
      "chaleco": { "branch": "survivor", "I": { "markedHitsSurvived": 1 }, "II": { "defeatLossScale": 0.75 }, "III": { "defeatLossScale": 0.5 } },
      "amuleto": { "branch": "occultist", "I": { "beastMemoryScale": 0.75 }, "II": { "beastMemoryScale": 0.5 }, "III": { "beastMemoryScale": 0.5, "refugioRegenScale": 3 } }
    },
    "calmMeter": "untouched",
    "speedCap": "untouched",
    "memoryFloorSeconds": 2,
    "soldLevels": ["I"],
    "soldPieces": ["guantes", "botas", "amuleto"]
  },
  "totems": {
    "ultimoAliento": { "cost": { "ember": 20, "uncommon": 12, "rare": 2 }, "sold": false },
    "suerte": { "cost": { "ember": 0, "common": 10, "uncommon": 12, "rare": 2 }, "materialsOnly": true, "seconds": 60, "radius": 40, "tierUp": 1, "noiseRadius": 90, "sold": false },
    "eco": { "cost": { "ember": 15, "common": 10, "rare": 1 }, "windowSeconds": 30, "decoySeconds": 4, "sold": false }
  },
  "corral": {
    "freeSlots": 4, "maxSlots": 8, "slotLadder": [60, 150, 350, 800],
    "ratePerMinute": { "Comun": 0.5, "Rara": 0.75, "Epica": 1.0, "Legendaria": 1.5 },
    "duplicateFactors": [1.0, 0.5, 0.25], "duplicateKey": "species_and_rarity",
    "pooledCapPerSlot": null,
    "activeIncomeCap": { "share": 0.4, "perExtraPen": 0.3, "windowMinutes": 20, "appliesTo": "totalCredited", "scalesEveryPlaqueProportionally": true },
    "plaqueShowsCreditedRate": true,
    "rateShare": { "activeWindow": 1.0, "otherwiseAlive": 0.25, "deadOrAway": 0.0 },
    "activeWindow": { "minutesAfterEvent": 3, "events": ["stealBanked", "gatherBanked", "extraction", "waveBanked"], "safeCirclesIncludeBeastFreeStrip": true },
    "feed": { "roles": ["common", "uncommon"], "units": 1, "windowMinutes": 20, "holdSeconds": 1, "requiresExpeditionSinceLastFeed": true },
    "storageMinutes": 20, "collectHoldSeconds": 1.5,
    "accrual": "lazyFromTimestamps",
    "accruesWhile": "owner_in_server_and_alive",
    "offline": "nothing_accrues; stored output survives once persistence exists",
    "trophiesPayEsencia": false
  },
  "breeder": { "base": 40, "ratio": 1.6, "round": 10, "steps": 10, "costs": [40, 60, 100, 160, 260, 420, 670, 1070, 1720, 2750], "corralBonusPerLevel": 0, "extractionBonusPerLevel": 0, "playerText": "prestige", "cosmeticEveryLevels": 1, "plinthEveryLevels": 2, "sold": false },
  "incubator": { "hatchSeconds": 90, "eventEggSeconds": 300, "nidoCalido": { "costs": [50, 125, 300], "hatchScalePerLevel": 0.8, "minHatchScale": 0.5 }, "secondSlot": 250, "hatchSkipsSold": false, "hatchTimesExtended": false },
  "smallSources": { "waveBoardTop3": [5, 3, 2], "beastBeatenNoCapture": 3, "firstSpeciesRegistered": 10 },
  "dailyGift": { "needsPersistence": true, "consecutiveDays": false, "repairSold": false, "surface": "tablero",
    "byClaim": [{ "ember": 5 }, { "ember": 10 }, { "common": 1, "uncommon": 1 }, { "ember": 15 }, { "seal": 1 }, { "ember": 20 }, { "ember": 30, "ribbon": 1 }],
    "esenciaPerCycle": 80 },
  "cosmetics": { "esenciaByTier": [150, 400, 1000], "robuxByTier": [49, 99, 149], "milestoneRibbonsSold": false, "pricedBy": "desire",
    "robuxSoftCeilingPer30Days": 300, "showOthersCosmeticPrice": false, "robuxRowGatedBy": "E11" },
  "policy": {
    "products": "gamePass",
    "ownershipCheck": ["join", "PromptGamePassPurchaseFinished"],
    "promptRefusedWhenOwned": true,
    "policyService": { "fields": { "ArePaidRandomItemsRestricted": "tripwire only; nothing random is sold" }, "gatesOffers": false, "onFailure": "restrictedForSession", "retryAfterSeconds": 60, "maxRetries": 1 },
    "maturityLabel": { "decision": "E11", "questionnaireRequired": true, "kidsChecklistConditional": true }
  },
  "strings": {
    "offerButton": "Guantes I · 49 Robux",
    "freeLine": "Gratis jugando: {esencia} de Esencia + {materiales} · ~{minutos} min",
    "freeLineExample": "Gratis jugando: 200 de Esencia + 20 Pelusa + 10 Espora · ~36 min",
    "ladderSentence": "Cuenta como un paso del equipo: tu siguiente mejora costará {siguiente} de Esencia.",
    "decline": "No, gracias",
    "puestoHeadline": "Nada de lo que se vende es exclusivo: todo se consigue jugando, y el Árbol nunca se vende."
  },
  "offers": [
    { "id": "equipoExplorador", "grants": "oneEquipmentPieceLevelI", "pieces": ["guantes", "botas", "amuleto"], "choiceRecordedServerSideBeforePrompt": true, "robuxApprox": 49, "freePath": "equipment.ladder", "minFreeStepCost": 200, "surface": "taller", "product": "gamePass", "needsPersistence": true, "random": false },
    { "id": "unCorralMas", "grants": "nextCorralSlot", "robuxApproxBySlot": { "6": 29 }, "slotsSold": [6], "freePath": "corral.slotLadder", "minFreeStepCost": 150, "surface": "corral", "trigger": "nextCalmHubVisitAfterRefusedPlacement", "product": "gamePass", "needsPersistence": true, "random": false },
    { "id": "bolsaGrande", "grants": "reinforcedPack", "robuxApprox": 49, "freePath": "upgrades.reinforcedPack", "surface": "taller", "trigger": "calmHubVisitAfterTwoBagFullNoticesInSession", "product": "gamePass", "needsPersistence": true, "random": false },
    { "id": "segundaIncubadora", "grants": "incubatorSlot2", "robuxApprox": 39, "freePath": "incubator.secondSlot", "surface": "incubadora", "product": "gamePass", "needsPersistence": true, "random": false },
    { "id": "cintasYSombreros", "grants": "cosmetic", "robuxApprox": [49, 149], "freePath": "cosmetics.esenciaByTier", "surface": "corralTab", "card": false, "product": "gamePass", "needsPersistence": true, "random": false }
  ],
  "offerRules": {
    "minSessionIndex": 2, "minCumulativeMinutes": 30, "quietMinutesEachSession": 5,
    "minMinutesBetweenOffers": 15, "maxCardsPer20Minutes": 2, "oncePerStepPerSession": true, "hubOnly": true,
    "noCardWithinSecondsOfRefusalOrNotice": 60,
    "neverDuringDanger": true, "neverAtFailure": true, "countdowns": false, "strikeThrough": false, "characterAsks": false,
    "puestoShowsRobuxRowOnlyWhenEligible": true, "dailyGiftSurface": "tablero",
    "purchaseCopy": "descriptive",
    "forbiddenCopyTokens": ["¡", "cómpralo", "compra ya", "consíguelo ya", "ya", "ahora", "solo", "sólo", "rápido", "última", "no te lo pierdas"],
    "estimate": { "source": "designMedianBalanced", "ownFigureOnlyIfLower": true, "ownMinDataMinutes": 5, "ownFloorPerMinute": 4, "includesMaterials": true, "maxOverDesignMedian": 0.2 },
    "freeLineFirst": true, "ladderStepSentence": true,
    "nonCosmeticCeilingRobux": 500, "nonCosmeticTotalRobux": [166, 215],
    "anchorRobuxPerHour": [60, 90], "anchorBand": [50, 135],
    "needsPersistence": ["minSessionIndex", "minCumulativeMinutes", "oncePerAccount", "cosmeticsBrowse"]
  },
  "simulatorInputs": {
    "cycleMinutes": 6, "firstCycleMinutes": 2, "minutesOutPerCycle": 5, "activeEsenciaPerCycle": 28, "firstCycleEsencia": 14,
    "activeBonusPerCycle": { "explorer_1": 1, "guantes1": 2, "botas1": 1, "reinforcedPack": 3 },
    "materialsPerCycle": { "common": 12, "uncommon": 6 },
    "rarityScript": ["Comun", "Comun", "Rara", "Comun", "Comun", "Rara", "Comun", "Epica", "Comun", "Rara", "Comun", "Comun", "Rara", "Legendaria", "Comun", "Comun", "Rara", "Epica", "Comun", "Rara"],
    "speciesPerRarity": { "Comun": 6, "Rara": 4, "Epica": 3, "Legendaria": 2 },
    "rarePerThirdCycle": 3,
    "fullBagNoticeChancePerCycleWithoutPack": 0.35,
    "freePriority": ["farolTapado", "explorer_1", "capturer_1", "equipmentStep", "survivor_1", "slot5", "capturer_2", "equipmentStep", "explorer_2", "slot6", "equipmentStep", "equipmentStep", "capturer_3", "explorer_3", "secondIncubator", "slot7"],
    "thenCheapestFirst": true,
    "payingPolicy": { "acceptsEveryEligibleCard": true, "piecePreference": ["amuleto", "botas", "guantes"] },
    "sessionOnly": {
      "oneSittingMinutes": 60,
      "reachedInOneSession": ["farolTapado", "explorer_1", "capturer_1", "corral4Pens"],
      "reachedInOneSitting": ["farolTapado", "explorer_1", "capturer_1", "survivor_1", "capturer_2", "guantes1", "equipmentStep1", "slot5", "corral4Pens"],
      "needsPersistence": ["capturer_3", "explorer_3", "survivor_3", "occultist_3", "equipmentStep4", "allLevelI", "slot6", "slot7", "slot8", "secondIncubator", "reinforcedPack", "breeder3", "nido2"]
    },
    "targets": {
      "K1_tier2_sessions_p50": 3, "K2_tier3_hours_p50": 3, "K2_allLevelI_hours": 2.5,
      "K3_minutesSaved": [30, 90], "K4_payingIncomeRatioAt2h": 1.3, "K4b_payingAdvantageRatioAt2h": 1.65,
      "K6_coreOwnedHours": 8, "K6_corePens": 7, "K12_penLadder": [60, 150, 350, 800], "K6_everythingHours": 60,
      "C1_corralNominalMaxPerMinute": 6.0, "C2_freeCorralShare": 0.35, "C2_payingCorralShare": 0.40, "C2_hours": [2, 4, 8],
      "K8_idleHourCredit": "quarterRate x one feeding window; re-feeding needs an expedition",
      "K9_greedyMedianSeconds": 180, "K9_perturbationFloorSeconds": 150, "K9_greedyDefeatRateWithChaleco": 0.10,
      "K12_equipmentRatioBand": [1.4, 1.6], "K12_treeRatio": 2.5, "K12_breederRatio": 1.6,
      "K13_nonCosmeticCeilingRobux": 500, "K13_minMinutesBetweenPurchases": 15, "K13_maxPurchasesPer20Minutes": 2,
      "K15_firstEsenciaMinutes": 2, "K15_firstCreatureMinutes": 2,
      "P1_anchorBand": [50, 135], "P1_aggregateBand": [50, 135], "D1_dailyGiftUnderSessionIncome": true
    }
  }
}
```
