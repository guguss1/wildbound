# Wildbound: beast spawn by Risk and threat budget

Status: **Design, approved by the owner on 2026-11-11.** Nothing here is wired yet. It replaces the proposal "Sistema de aparición de bestias por Risk y Difficulty Capacity" (owner's file `wildbound_mecanica_aparicion_bestias.md`, not in the repo) by turning it into a tune of the existing beast director instead of a new system.

## Quick path

- The proposal's core is **already built** in `src/wildbound/WildboundBeastDirector.luau`. Do not add a second scheduler, a `PlayerThreatState` or a per-beast timer loop: the director says so itself (line 2, "no second scheduler").
- Beasts split into **three categories**: A guardian, B biome beast, C global beast. Each global beast has **one readable trigger**.
- Owner decisions: Risk grows while carrying an egg; the pacing limits stay; global beasts never enter Pradera; five new beast cards approved below.
- Open: roll interval (10 s today vs 20 s proposed), exact numbers for the new beasts, egg Risk step value.

## 1. What the proposal asked and where it already lives

| Proposal rule | Existing implementation | Evidence |
| --- | --- | --- |
| Independent roll per player and beast | One roll per eligible beast and living player every `TICK_SECONDS` | `WildboundBeastConfig.luau` `DIRECTOR.TICK_SECONDS`; `Director.tick` |
| Capacity 3 points per player, shared by all beasts | `MAX_POINTS = 3`, one budget per player | `WildboundBeastConfig.luau` `DIRECTOR.MAX_POINTS` |
| Points configurable per beast | `points` per beast (Viper 1, Pouncer 1, Gargoyle 2, Mire 2) | `Config.BEASTS` |
| Re-validate and reserve atomically on success | `Director.reserve` checks and reserves in one call with no yield | `WildboundBeastDirector.luau:79` |
| A chasing beast does not roll again for that player | Refused as `AlreadyActive` | `WildboundBeastDirector.luau:101` |
| Not enough capacity, no spawn | Refused as `Budget` | `WildboundBeastDirector.luau:105` |
| Points return when the chase ends, only once | `Director.release` is idempotent | `WildboundBeastDirector.luau:118` |
| No queued or retroactive rolls | A refused win is logged and dropped | `WildboundBeastDirector.luau:5` |
| Clean state when a player leaves | `Director.forget` | `WildboundBeastDirector.luau:164` |
| Biome beasts only in their biome | `biome` field filters the roll | `Config.BEASTS`; `Director.tick` |
| Risk and Risk Modifier | Condition multipliers (night x2, far from base x1.2, dangerous zone x1.5, long expedition x1.3), product capped at x4, chance capped at 0.20 | `DIRECTOR.MULTIPLIERS`, `MAX_MULTIPLIER`, `MAX_CHANCE` |

Real differences with the code:

| Topic | Proposal | Code today | Decision |
| --- | --- | --- | --- |
| Roll interval | 20 s | 10 s | **Open.** Doubling it without raising base chances roughly halves encounters; a median expedition (about 200 s) could see no beast. Retune chances if it changes |
| Offset between beasts | 1 s stagger | Order shuffled inside each tick | **Dropped.** Atomic reserve already prevents the double spend the stagger was meant to avoid |
| Concurrency and cooldowns | Not mentioned; points return instantly | Max 2 encounters, 15 s global cooldown, 35 to 60 s per species | **Keep** (decision 2). Points still return instantly |
| Risk growth | Undefined | No growth | **Grows with the egg** (decision 1) |

## 2. Taxonomy

| Category | Rule | Members |
| --- | --- | --- |
| **A. Biome guardian** | One per biome and player. Outside the point budget. It is the biome's identity. While it is engaging the player, no budget beast starts | La Silueta (Bosque), Nube Gruñona (Pradera), El Vigía (Cementerio / Ruinas), Yeti (Montañas) |
| **B. Biome beast** | Uses the budget. Rolls only while the player stands in a zone tagged with its biome. Part of the biome's ecology and loot | Mire, Root (Pantano); Gargoyle (Cementerio) |
| **C. Global beast** | Uses the budget. Can appear anywhere except safe zones and Pradera. Its chance is driven by **one signature trigger** from the player's state, so players learn "if I do X, Y comes" | Viper, Pouncer, Streamer, Lurker, Graso |
| Nest and event creatures | Not run by the director | Nest parents; Abeja Reina (Pradera event) |

Rules that come from existing docs:

- Only El Vigía may read camera or gaze (`docs/design/wildbound-expansion-bible.md:42`, `:220`). That is why Gaze is merged into El Vigía.
- Pradera has a no-damage rule (`docs/design/wildbound-biome-pradera.md`). That is why global beasts are excluded there (decision 3).
- Every attack needs a tell of at least 0.8 s (`Config.MIN_TELL`, `docs/mechanics/wildbound-fair-strike.md`).

## 3. Beast cards

Approved by the owner. Point costs are approved; chances, cooldowns and timings are to be tuned and must not be invented when implementing.

| Beast | Category | Signature trigger | Tell (0.8 s minimum) | Escape | Points | State |
| --- | --- | --- | --- | --- | --- | --- |
| Viper | C | Night | Red lane on the ground | Step out of the lane | 1 | Live |
| Pouncer | C | Noise: sprint or Burst | Red circle under the player | Side dodge | 1 | Live |
| Streamer | C | Carrying an egg | Wind whistle and a light streak crossing the path | Perfect dodge (`WildboundDodge`). A hit knocks the egg loose, no damage | 1 | Card only |
| Lurker | C | Hiding or standing still too long (anti-camping) | Eyes open in the bush or shadow next to the player, plus breathing | Leave the hiding spot before the tell ends | 1 | Card only |
| Graso | C | Long expedition far from base | Ground rumble; it surfaces at a distance, slow | Route around it or reach a Refugio. Slow but persistent | 2 | Card only |
| Mire | B, Pantano | Half-submerged stalker in swamp water | See `beast-pack/04_MIRE.md` | See `beast-pack/04_MIRE.md` | 2 | Config only |
| Root | B, Pantano | Standing still in mud | Bubbles and a creak under the feet | Move or jump. If it grabs, it holds for 1.5 s | 2 | Card only |
| Gargoyle | B, Cementerio | Statue that wakes | See `beast-pack/03_GARGOYLE.md` | See `beast-pack/03_GARGOYLE.md` | 2 | Config only |
| Gaze | Merged into El Vigía (A) | Its staring-eyes idea becomes an El Vigía move | | | | Merged |

## 4. Owner decisions (2026-11-11)

1. **Risk grows with the egg.** While the player carries an egg, the condition product gains a soft step (around x1.2, to be tuned), still under `MAX_MULTIPLIER`. Combined with Streamer, carrying an egg is the moment of peak tension. If the two-player test feels unfair, remove the x1.2 step first.
2. **Pacing limits stay.** Points return instantly when a chase ends, but `MAX_ACTIVE = 2`, the 15 s global cooldown and the per-species cooldowns remain.
3. **Global beasts never appear in Pradera** or in safe zones.
4. **Beast cards** for Streamer, Lurker, Graso and Root as in section 3; Gaze merged into El Vigía.

## 5. Integration plan

P0, no new beasts:

- `WildboundBeastConfig`: add `category` (`"Guardian"`, `"Biome"`, `"Global"`) and `riskModifier = 1` per beast; add an `egg` multiplier entry.
- `WildboundBeastDirector` / `WildboundBeasts.server.luau`: pass `carryingEgg` in the roll context and apply the egg step.
- Exclude global beasts from Pradera and safe zones in the eligibility check.
- Wire `WildboundDusk` (prepared, x1.25 at dusk).
- Decide 10 s vs 20 s and retune base chances to match.

P1:

- Biome tags in `WildboundWorldRules` so `ctx.biomes` is filled (today it is `{}` at `WildboundBeasts.server.luau:178`, so no biome beast can roll).
- Mire behaviour; signature triggers per beast (`noise`, `stillSeconds`), reusing the hearing radii in `WildboundStamina` and `WildboundCaptureSession`.
- Two-player test of the whole director.

P2:

- Gargoyle behaviour; Streamer, Lurker, Graso and Root behaviours from their cards, one at a time, each with its tell, model and tests.

Dropped or parked: the 1 s stagger, a separate `PlayerThreatState`, Gaze as a global beast, Risk growth by anything other than the egg.

## 6. Test cases kept from the proposal

The proposal's cases 1 to 14 remain the acceptance list. Most already map to director suites; add the new ones:

- Carrying an egg raises the effective chance by the egg step and never past `MAX_MULTIPLIER` or `MAX_CHANCE`.
- No global beast rolls while the player is in Pradera or a safe zone.
- A biome beast never rolls without its biome tag in `ctx.biomes`.
- While a category A guardian engages the player, no budget beast starts.
