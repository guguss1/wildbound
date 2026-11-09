# PI-1: steal a creature from La Silueta (design proposal)

Status: **design proposed, awaiting user approval.** Nothing here is built. Parked idea PI-1 in `docs/design/wildbound-parked-ideas.md` (user, 2026-11-08). This page answers its five open questions with options and one recommendation each, and lists what building it would take.

## The pitch in one line

At the center of her territory La Silueta keeps a captive cría in a bramble cage; when she wanders off on patrol you can sneak in and take it, and from that moment she hunts you, and only you, all the way home.

## Facts it has to fit (as built today)

| Fact | Value | Source |
| --- | --- | --- |
| Her home, territory and pursuit leash | home (0, -85); territory 80 studs; the chase may follow to 100 from home | `WildboundWorldRules` |
| Memory after losing sight; give-up distance | Day 4 s, Dusk and Dawn 5 s, Night 6 s; 100 studs | `WildboundGuardianBrain`, NB1 |
| Strikes | a 0.9 s telegraph (never under 0.8 s), only inside the territory, never on island 1 to 3 floors, at camp or on the spawn pad; damage only in private mode and after the first paid trip | `docs/mechanics/wildbound-fair-strike.md` |
| Escape | a rested sprinter outruns every hunt by at least 5 studs/s; hiding unseen breaks the chase | chase pass CP-D2 |
| Nearest island to her home | I4 Ruinas del Nido (35, -99), I5 Corazón de la Niebla (60, -135); camp (-140, 140) is about 270 studs from her home | `WildboundIslandLayout` |
| Economy floors | greedy expedition median at least 180 s, perturbation floor 150 s | `tools/simulate_economy.py` |

## The five questions

### 1. What she keeps, and where

| Option | For | Against |
| --- | --- | --- |
| A. A captive cría in a bramble cage at her home (0, -85) | Reads instantly ("she took one too"); the home point already exists and is inside the territory, so strikes stay fair; she returns there to retreat, so the cage is guarded by her routine | Her home is near the patrol diamond: tight timing |
| B. A creature in the Corazón de la Niebla (I5) | Uses the deepest island; feels like a final level | I5 already has four sleeping adults and its own wake rules; two threats at once blur who is chasing |
| C. She carries it (a glowing shape in her hand) | Spectacular | She is a 22-stud art model over a small gameplay body; "carried" needs new art and a hit-to-drop rule, and taking it means touching her: a contact rule the fair-strike contract does not have |

**Recommendation: A**, a cage at her home, one per server, refilled at dawn.

### 2. How the theft starts

| Option | For | Against |
| --- | --- | --- |
| A. Sneak in while she patrols the far side of her diamond | Uses what exists: patrol, sight radius, hiding spots, noise | Can feel like waiting |
| B. Lure her with noise (a thrown lure, or a capture or sprint noise elsewhere) | Players plan; the noise system already moves her (Investigate) | A new thrown item is new input and new UI |
| C. A timed window at dawn (she sleeps) | Clear and fair | Removes the tension the idea is about |

**Recommendation: A, with B as the skill path using existing noise only**: a sprint or a capture far from the cage already pulls her away (Investigate, up to 14 s), so a two-player team can lure while the other steals, and a solo player can time her patrol. Opening the cage is a 2 s hold ("Abrir la jaula"), loud like an egg grab (the island `GRAB` 45 idea): she hears it within her hearing radius.

### 3. What happens after

| Option | For | Against |
| --- | --- | --- |
| A. A full-speed chase to camp | The adrenaline the user asked for | 270 studs: she gives up at 100 anyway, so it would need a longer leash and a bigger give-up distance only for this |
| B. A chase that ends only at a hide spot | Uses hiding | Hiding then feels mandatory and dull |
| C. A "marked thief" chase: she hunts at once (no Alert wind-up), keeps her normal leash and give-up distance, but her memory of the thief is doubled while the cría cries; leaving the leash or hiding unseen ends it as today | Keeps every fairness rule; the cría's cry (the existing carried-cría cry, 18 noise) tells her where you went; escape stays possible by sprinting out of the leash or hiding | Needs one new rule (the thief mark) and its tests |

**Recommendation: C.** The theft is the scariest moment of the game, but the rules that make a death fair do not change: the 0.9 s telegraph, strikes only inside the territory, no strike at camp or on island 1 to 3 floors. A sprint (and its cost: the carried cría may slip) or a hide spot ends it.

### 4. The reward

| Option | For | Against |
| --- | --- | --- |
| A. A unique species ("Sombrilla", a pale cría that dims La Silueta's eyes when equipped) | A collection goal players talk about; no economy change if it pays the normal creature Esencia | Needs a species stand-in, a card blurb and an island-less entry |
| B. A large Esencia payout | Simple | Moves the economy floors; invites farming |
| C. A collection milestone (badge) | Cheap | Weak payoff for the hardest act in the game |

**Recommendation: A**, registered at the refuge like any creature, paying the creature's normal Esencia, once per player per session for the species entry (later thefts register a copy with no first-time bonus). No Robux, no purchase, no MarketplaceService: it is earned only by play.

### 5. Fair strike and the economy floors

- Fair strike: the cage is inside the territory, so the existing gates apply unchanged. The thief mark only removes the Alert wind-up before the chase (her telegraph before a strike stays 0.9 s, floor 0.8 s) and doubles memory; tests must pin that no strike lands at camp, on the spawn pad or on island 1 to 3 floors during a thief chase, and that the telegraph floor holds.
- First paid trip: a player who has never brought anything home cannot open the cage (the same `Eligibility` gate as lethal damage), so new players never meet a lethal chase in their first minutes.
- Economy: the simulator models neither islands nor this. The theft pays one creature's normal Esencia (no new payout), so it adds no new income source to balance; a simulator run is still part of the build, and the floors must hold.

## Building it (if approved)

1. Pure rules in a new `WildboundSiluetaCage` module: the cage state (full, opened, refill at dawn), the open hold, the thief mark and its memory multiplier. Tuning: `CAGE_HOLD` 2 s (1 to 5), `THIEF_MEMORY_SCALE` 2 (1 to 3), `CAGE_NOISE` 45 (0 to 100).
2. World server: no Alert for a marked thief, memory scaled, the mark cleared on loss, death or registration.
3. Inventory server: the cage prompt (server-validated: alive, in reach, eligible, cage full), the stolen cría into the carry slot, registration at the refuge.
4. Text in neutral Spanish ("Abrir la jaula", "¡La Silueta te vio robar!"), the species stand-in and its card.
5. Strict TDD, fresh-clone suites, the simulator run, and a Play check of a sneak theft, a lured theft and an escape by hiding.

About three work units (rules, wiring, content). Open for the user: whether one cage per server is right in co-op (first come), and the species' name and look.
