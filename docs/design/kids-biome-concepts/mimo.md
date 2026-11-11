# Bosque Golosina: the east biome for kids, with El Mimo as its beast

**Status: concept only. Nothing here is approved, built, simulated or played.** Written 2026-11-09 for the one-world direction of that day: a permanent safe hub in the centre, La Silueta's Fog Forest to the west, and this bright biome to the east, joined by a gate, not a portal. Every number is a hypothesis to tune in play; every Spanish word is a proposal. The angle of this concept is **trick-first**: the beast is a danger you walk up to by choice, because it looks like the thing you came to catch.

## Quick path

| You are | Read | Then |
| --- | --- | --- |
| The user | Section 1, section 4 (El Mimo), section 9 (decisions) | Pick or reject the name, the beast and the hug rule |
| Map planner | Sections 2, 3 and 8 | Plan `tools/plan_golosina_layout.py` the way `tools/plan_forest_layout.py` works; nothing here authorizes a Studio edit |
| Creature or beast artist | Sections 3.3 and 4.1 | Primitive stand-ins first, like `WildboundSpecies.LOOKS`; no uploads |
| Economy | Sections 3.4 and 7 | Extend `tools/simulate_economy.py` before any corral number becomes a rule |

## 1. The biome in one table

| Question | Answer |
| --- | --- |
| Name | **Bosque Golosina** (candy-and-toy forest). Sub-areas: Pradera Grageas (sprinkle meadow, entry), Bosque de Piruletas (lollipop trees), Río de Jarabe (syrup stream), Colina Pastel (cake hill), Campo de Regalos (gift boxes), **Jardín de Peluche** (the plush garden, the beast's heart) |
| Audience read | A toy box that grew into a forest. Everything is round, soft and edible-looking. No bones, no teeth, no red, no black, no screams, no fog you cannot see through |
| Beast | **El Mimo**: a patchwork plush the size of two players that wanders the biome and sits down disguised as one of its creatures. It grabs you in a hug when you try to capture the copy. It never hurts: it shakes a carried thing out of your bag and, if it catches you twice, carries you to the nearest Quiosco |
| Creatures | Five, bright and round at Lumipol scale: Gomilín, Pompón (Común), Chispiruela (Rara), Nubecín (Épica), Caramelux (Legendaria) |
| What you do here | Walk east through the gate, catch creatures with the same one-thumb Calm ring as the forest, read the tells that separate a real creature from El Mimo's copy, bring creatures back to the hub corral, where they earn Esencia |
| Danger shape | Chosen, not ambushed. El Mimo begins every hunt from a copy you can see; La Silueta begins hers from fog. Loss is an item, never health, never a death screen |
| Clock | Shares the 720 s cycle (Day 360, Dusk 72, Night 216, Dawn 72, `WildboundEconomyConfig.cycle`). Night here is cozy blue with lanterns, not dark |
| Joins the hub | Through **Puerta Golosina**, a candy-cane arch on the hub's east edge, with a 40-stud blend band (section 8) |

**Originality check.** No character, name or prop is taken from an existing game. The "plush that copies a creature" idea is ours; the closest common tropes (mimic chests, living dolls) are avoided on purpose: no chest with teeth, no doll with a cracked face, no eyes that follow you, no music that distorts.

## 2. Palette ramps

Row style of `src/wildbound/WildboundAtmosphere.luau`: `ROWS[zone][time] = { density, offset, haze, fogStart, fogEnd }` and `LIGHT[time] = { atmosphere, fog, ambient, outdoor, ambientWeight, brightness, exposure, flashlight }`. The forest rows blend Day → Dusk → Night → Dawn on the same keyframes; Dawn is written out here because the kids' dawn is its own warm colour, not the dusk row replayed.

**Readability contract (new, for this biome only):** no ambient or outdoor channel under 70 at any time; `fogEnd` never under 300; `density` never over 0.45. The forest floors (`Atmosphere.FLOORS`) still apply and are far looser, so a shared test can assert the kids' rows are strictly brighter and clearer than every forest row at the same time of day.

### 2.1 Fog rows (`ROWS`)

| Zone | Day | Dusk | Night | Dawn |
| --- | --- | --- | --- | --- |
| `golosina` (the biome) | `{ 0.22, 0.10, 1.2, 120, 900 }` | `{ 0.30, 0.06, 1.6, 90, 600 }` | `{ 0.40, 0.03, 2.0, 60, 320 }` | `{ 0.28, 0.08, 1.4, 100, 700 }` |
| `peluche` (Jardín de Peluche, the heart) | `{ 0.28, 0.08, 1.5, 90, 600 }` | `{ 0.34, 0.05, 1.8, 70, 450 }` | `{ 0.45, 0.02, 2.3, 50, 300 }` | `{ 0.32, 0.06, 1.6, 80, 520 }` |
| `gateEast` (blend band) | lerp of `camp` and `golosina` by position in the band | | | |

Compare the forest open Night `{ 0.82, 0, 5.0, 15, 60 }`: a child at night in Bosque Golosina still sees 320 studs; in the forest, 60.

### 2.2 Colour and light (`LIGHT`)

| Time | atmosphere | fog | ambient | outdoor | ambientWeight | brightness | exposure | flashlight |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Day | `{ 255, 214, 232 }` pink cream | `{ 250, 228, 240 }` | `{ 150, 142, 160 }` | `{ 172, 162, 182 }` | 1 | 2.0 | 0.15 | `{ 0, 55, 60 }` off |
| Dusk | `{ 255, 184, 122 }` orange sherbet | `{ 242, 176, 156 }` | `{ 132, 104, 132 }` | `{ 160, 122, 152 }` | 1 | 1.4 | 0 | `{ 0, 55, 60 }` off |
| Night | `{ 92, 122, 212 }` cozy blue | `{ 72, 98, 172 }` | `{ 74, 88, 142 }` | `{ 88, 104, 164 }` | 1 | 0.9 | -0.1 | `{ 1.5, 40, 60 }` soft, optional |
| Dawn | `{ 255, 222, 172 }` butter | `{ 250, 216, 192 }` | `{ 142, 130, 142 }` | `{ 170, 152, 152 }` | 1 | 1.6 | 0.1 | `{ 0, 55, 60 }` off |

Night is carried by props, not by the player's light: music-box lanterns (`Farolitos`, warm `{ 255, 214, 150 }`, Range 22, shadowless) every 25 to 35 studs along routes, and every creature has a soft glow (section 3.3). The flashlight exists so the control scheme stays the same as the forest, but a child who never finds it loses nothing here.

### 2.3 Surface palette (for the kit, not Lighting)

| Role | Day colour | Note |
| --- | --- | --- |
| Grass | `{ 168, 232, 160 }` sorbet green, with `{ 255, 170, 196 }` strawberry patches | Flat colour, no texture |
| Routes | `{ 244, 226, 190 }` wafer | 14 studs wide, like the forest route |
| Water (Río de Jarabe) | `{ 232, 168, 72 }` glossy amber | Walkable, slows to 13 studs/s (same step as a 40% pouch) |
| Lollipop canopies | 5 swirls: `{ 255, 120, 150 }`, `{ 120, 200, 255 }`, `{ 255, 220, 100 }`, `{ 170, 230, 120 }`, `{ 210, 160, 255 }` | Two colours per canopy, spiral stripe |
| Plush (El Mimo and copies) | Real creature colour x0.82 saturation, plus seam `{ 120, 90, 80 }` | The desaturation is a tell (section 4.2) |

## 3. Terrain, props and creatures

### 3.1 Terrain vocabulary

| Area | Shape | Gameplay role | Distance to the Baúl (rarity band, W2) |
| --- | --- | --- | --- |
| Pradera Grageas | Open rolling meadow, sprinkle dots, Quiosco 1 at the gate | First creature in 15 s: a guaranteed Gomilín or Pompón near Quiosco 1 | > 120 studs: Común |
| Bosque de Piruletas | Lollipop trees in clusters, wafer paths | Cover: lollipop sticks collide and block sight like forest trunks | > 120 to 80: Común, Rara |
| Río de Jarabe | A slow amber stream crossing the biome north to south, cookie stepping stones | Wading slows you; the stones are the fast way and the loud way (crunch noise) | Crosses the 80 to 120 band |
| Colina Pastel | A layered cake hill with frosting ledges, Quiosco 2 on top | High ground to spot copies and El Mimo wandering; Nubecín floats here at dusk and night | 45 to 80: Épica |
| Campo de Regalos | Gift boxes of three sizes with lids | Hide spots (lid closes), decoy candy spawns, the way in to the heart | 45 to 80 |
| Jardín de Peluche | A ring of plush flowers and toy blocks around **El Baúl**, El Mimo's toy chest; Quiosco 3 at its edge, outside the ring | El Mimo's home anchor and the event site; Caramelux spawns only here | < 45: Legendaria |

Scale: a 400 x 400 stud square like the forest plan, so the instance and triangle budgets of `assets/maps/forest-layout/forest-layout-v1.json` (207 instances, 74,996 triangles, never measured on a device) are the ceiling to plan under. The heart ring has a radius of 45 studs to match the Legendaria band.

### 3.2 Prop vocabulary (kit units)

| Prop | Sizes | Collides | Blocks sight (`CanQuery`) | Note |
| --- | --- | --- | --- | --- |
| Piruleta (lollipop tree) | S 9, M 14, L 20 studs tall | Stick core only, like `FK_TrunkCore` | Stick only | Canopy is a flat disc with a spiral; never a sphere, so phones read it at distance |
| Bastón (candy-cane post) | 6 studs | Yes | No | Route markers, every 30 studs |
| Gominola (gumdrop bush) | 3 to 5 studs | No | No | Hide spot: step in, the dome tints you out. Reuses the forest bush hide rule |
| Caja de regalo (gift box) | 4, 6, 8 studs | Yes | Yes (walls) | Hide spot with a lid prompt; some hold a Caramelo señuelo |
| Galleta (cookie stepping stone) | 3 studs | Yes | No | Crunch noise on step, radius 20 |
| Malvavisco (marshmallow boulder) | 4 to 7 studs | Yes | Yes | Soft shape for cover; sits in groups of three |
| Hongo de gominola | 3 to 6 studs | No | No | Glow at night, bounce pad (small hop, not a launcher) |
| Bloque de juguete | 4 studs | Yes | Yes | Stacked in the heart; letters avoided (no reading needed) |
| Farolito (music-box lantern) | 5 studs | No | No | Warm light at night, faint music-box chime within 8 studs |
| Quiosco (teacup gazebo) | 16 studs across | Base only | No | Safe zone, 3 per biome, radius 14 |
| El Baúl (toy chest) | 10 x 7 x 7 | Yes | Yes | El Mimo's home anchor; the event egg appears on its lid |

Rules carried over from the forest: anchored, `CanTouch` off on every decoration, only named cores collide and block sight, pivots at least 7 studs from route centrelines, hide spots never inside the heart ring (so the Legendaria carry cannot be made safe by hiding at the chest).

### 3.3 Five creatures

Scale is Lumipol's: adult about 3 x 2 x 2.4 studs (`WildboundSpecies.LOOKS.Lumipol.size`), cría at 0.55. Each is a primitive stand-in first (body, accent, two eyes, glow), in the `Species.LOOKS` shape. All use the Calm ring capture of `docs/mechanics/wildbound-capture.md`; the twist per species is in the behaviour, not in a new input.

| Name | Rarity | Look (body, accent, eye, glow) | Silhouette | Behaviour (one sentence) | Corral earn per minute |
| --- | --- | --- | --- | --- | --- |
| **Gomilín** | Común | `{ 255, 128, 160 }`, `{ 255, 190, 210 }`, `{ 60, 40, 70 }`, `{ 255, 200, 220 }` | A translucent jelly drop with four stubby feet and a dimple on top | Hops along the Río de Jarabe in threes and freezes mid-wobble when you walk slowly toward it, so a calm approach is the whole trick | 0.5 |
| **Pompón** | Común | `{ 200, 230, 255 }`, `{ 255, 240, 250 }`, `{ 40, 50, 80 }`, `{ 220, 240, 255 }` | A cotton-candy puff on two bird feet, as wide as it is tall | Drifts with the wind toward the nearest Piruleta and peeks out from behind the stick, so you catch it by waiting on the far side of the tree | 0.5 |
| **Chispiruela** | Rara | `{ 255, 214, 80 }`, `{ 255, 110, 90 }`, `{ 80, 40, 40 }`, `{ 255, 236, 150 }` | A striped candy ball with a paper propeller on top | Zips between gift boxes in short dashes and spins in place for 4 s after each dash, which is your capture window | 1 |
| **Nubecín** | Épica | `{ 245, 245, 255 }`, `{ 180, 200, 255 }`, `{ 70, 70, 120 }`, `{ 200, 215, 255 }` | A small marshmallow cloud that floats at a child's head height with two dangling mitten feet | Floats over Colina Pastel at dusk and night and rains sprinkles when a player stands still underneath, which is also how it tells you it is calm enough to catch | 2 |
| **Caramelux** | Legendaria | `{ 255, 140, 60 }`, `{ 255, 230, 120 }`, `{ 60, 30, 20 }`, `{ 255, 190, 90 }` | A wrapped candy with its two wrapper twists spread as glowing wings | Lives only in the Jardín de Peluche and comes out of the Huevo Piñata (section 5); it circles El Baúl and lands when El Mimo is asleep or away, so the Legendaria catch is a timing read on the beast | 4 |

Why the real ones read as real: every creature blinks (eyes close for 0.1 s every 3 to 5 s), breathes (body scale 1.0 to 1.04 loop) and keeps a saturated colour. El Mimo's copies do none of these (section 4.2). A 7-year-old learns "the still one is the toy" in one or two encounters.

### 3.4 Corral earnings (design, not a rule yet)

| Rule | Value | Why |
| --- | --- | --- |
| Where | The hub corral only; a creature in your bag or the biome earns nothing | Earning needs the trip home, so the loop stays "go out, bring back" |
| When | Only while the owner is in the server; a 60 s tick adds to banked Esencia (`neverLost`) | DataStore is forbidden today and AFK progress is not wanted: nothing accrues offline |
| Slots | 8 at start | Enough for a visible pen; more slots are a skill-tree purchase in the economy design |
| Ceiling | A full starting corral of Común earns 4 per minute; the greedy median active expedition pays about 5 to 8 per minute today (creature 6 to 22 plus extract 4 over 180 to 480 s) | Passive income stays under half of active income, so playing beats parking |
| Check | Add a `corral` input to `tools/simulate_economy.py` and keep the 180 s greedy median floor | Numbers above are guesses until that run exists |

## 4. El Mimo

### 4.1 Look and feel

| Trait | Rule |
| --- | --- |
| Body | A patchwork plush about twice the avatar (10 studs) when revealed; round head, no neck, mitten hands, a zipper line down the back, one loose thread trailing 2 studs behind |
| Face | Two flat button eyes and a stitched smile that never changes. No teeth, no glow, no eye tracking |
| Colours | Pastel patchwork in the biome's own canopy colours, desaturated x0.82, with a `{ 120, 90, 80 }` seam |
| Sound | Squeaky toy on each step, a zipper on the telegraph, a wind-up music box when it naps. Never a growl or a scream |
| Idea | A toy that wants to play catch and does not know its own size. The grab is a hug. Players lose a thing, not a life |

### 4.2 The trick: copies and tells

El Mimo spends most of its time **posed**: it shrinks to a creature's size plus 15% and sits at a creature spawn candidate, in that creature's colours, for 60 to 120 s. Tells, at least two always present, chosen per pose:

| Tell | Channel | Read at |
| --- | --- | --- |
| A seam or zipper line down the back | Shape | 25 studs |
| Button eyes, not glossy eyes | Shape | 15 studs |
| It never blinks and never breathes | Motion | 15 studs, after 3 to 5 s of watching |
| Colour is a little grey next to a real one | Colour | 25 studs, only if a real one is near |
| A faint music-box hum | Sound | 12 studs |
| Awareness chip reads "Algo no cuadra…" | Text | 10 studs, works muted and colour-blind |

The copy picks the creature of its band: in the Común band it copies Gomilín or Pompón, in the heart it copies Caramelux or the event egg. The better the prize, the better it pays to read the tells.

### 4.3 Hunt rule (per-player, fair)

Like La Silueta after F2: **one El Mimo per player** (cap `MAX_MIMOS` 8), bound to its owner, faint to others (default, user decision open), its hug resolving server-side for the owner only. Everything below reuses the fair-strike gates (`docs/mechanics/wildbound-fair-strike.md`): dwell, target-only warning with attack id, acknowledgement, stall cancel. The consequence changes; the gates do not.

| State | What happens | Numbers |
| --- | --- | --- |
| Wander | Walks toy paths between pose candidates, squeaking | 4 studs/s, visible from 300 studs by day |
| Pose | Sits as a copy (4.2) | 60 to 120 s, then wanders to another candidate |
| Trigger | The owner starts a Calm ring on the copy (the main trick), or sprints within 10 studs of it, or stands within 6 studs for 3 s | Never triggered by sight at range: it does not notice you walking by |
| **Unzip** (telegraph) | The zipper opens with the sound, the copy inflates to full size with a wobble, the ground ring turns yellow, the chip shows a yellow "!" and "¡Es El Mimo! ¡Salta fuera!" | **1.0 s standing still, warning lead 0.9 s** (floor 0.8 s). Leaving 7 studs or stepping out of the ring makes the hug miss: "Falló el abrazo", then 2 s of confused sitting |
| **Hug** | Holds the owner 2 s (character lifted, no camera shake) and shakes **one carried thing** out (creature, egg or candy), which lands 6 studs away, owner-only, recoverable for 30 s, like the Silueta drop | Range 7 studs, same as `ATTACK_RANGE`. No health change ever. Reduced effects: hold 1 s |
| Nap | Satisfied, it sits and plays its music box | 6 s, then Chase if the owner is within 20 studs and visible, else Wander. Picking the item back up near the napping Mimo is the tense bit |
| Chase | Follows the owner, squeaking faster | Hunt 12 / 13 / 14 studs/s (Day / Dusk / Night), chase limit 10 / 12 / 14 s, memory 3 s, give-up 70 studs, hug cooldown 2.5 s, telegraph before every hug |
| Second hug in one chase | Carries the owner to the nearest Quiosco: "El Mimo te llevó al Quiosco" | A 3 s ride, nothing else lost. The soft equivalent of mark then defeat |
| Juggle | Distracted by a Caramelo señuelo or by another creature it decides to copy | 4 s, ends the chase |
| Deflated | Its thread was pulled (4.5) | Walks back to El Baúl, 90 s away |
| Leash | Never enters a Quiosco, the gate band or the hub; clamped like `clampTerritory` | Hunt leash 100 from El Baúl, else 80 |

Speeds against the player: a walker (16) outruns every hunt; a carrier (14) ties at night; a loaded pouch (11 to 13) must hide, distract or drop. A sprint (23.2) always escapes. This keeps "run away works" for a child by day and makes night a decision, not a punishment.

### 4.4 How a 7-year-old reads it without horror

| Moment | What they see and hear | What the game never does here |
| --- | --- | --- |
| Before | A creature that sits a bit too still, with buttons for eyes | Nothing hides in fog; nothing watches from behind |
| Telegraph | A toy unzipping and puffing up, a yellow "!", a zip sound, big Spanish words "¡Salta fuera!" | No red, no screen flash, no heartbeat, no scream |
| Hit | A hug, confetti, your candy bouncing away with an arrow on it | No damage number, no blood, no fall, no death screen |
| Worst case | A ride on a plush to a teacup gazebo, "El Mimo te llevó al Quiosco" | No respawn, no loss summary beyond the one dropped item |
| After | The plush sits and plays music; you can walk back for your candy | No stalking, no return from nowhere |

Three channels every time (shape, sound, text) and colour as a fourth, so the muted phone and the colour-blind child read the same thing. The chip reuses the awareness design and `WildboundHudView` budgets, in Spanish.

### 4.5 Escape, counterplay and the brave kid's win

| Way out | How | Result |
| --- | --- | --- |
| Hide | Step into a Gominola bush or close a Caja de regalo lid (prompt 0.25 s) | Lost at once; El Mimo searches 8 s around the last spot, then poses again |
| Safe zone | Reach any Quiosco (radius 14) or the gate band | It stops at the edge and waves; the chase ends |
| Distraction | Throw a **Caramelo señuelo** (consumable, found in gift boxes or crafted at the hub for materials, cap 3 like seals) | It runs to the candy and juggles 4 s; the chase ends. Once per chase |
| Lure | Lead it within 8 studs of a real biome creature | It copies that creature and sits down; the chase ends. The creature flees (`SPOOK_SECONDS`) |
| Deflate (the win) | During Nap or Juggle, reach its back and hold the thread prompt 1.5 s: "Tirar del hilo" | "El Mimo se desinfló": it walks home for 90 s, every pose in the biome drops, and the puller gets 3 Esencia, once per 5-minute wave. The back is the risky side, so it is a choice |

It cannot be captured, damaged or killed, like every guardian. The free counterplay needing no item is hide or Quiosco; the lure and the thread are for players who have learned it.

## 5. The biome egg event: Huevo Piñata

| Rule | Value |
| --- | --- |
| Clock | Every 20 min, first at minute 5 (W3's biome event), one per server, one claimant |
| Banner | "¡Huevo Piñata en el Bosque Golosina!" with Caramelux's name, plus a distant party-horn call heard anywhere in the biome |
| Where | On the lid of El Baúl, inside the Legendaria ring, visible 5 min then gone |
| The trick | **Two eggs sit on the lid.** One is the Huevo Piñata (striped, glossy, gently rocking). The other is El Mimo posed as an egg: a seam down the shell, matte, perfectly still, humming. Pick the wrong one and you get the Unzip telegraph at point-blank range |
| The carry | Egg carry speed (`eggSpeeds`, slower of the two). Taking the right egg wakes every El Mimo copy in the heart: the owner's Mimo chases for the whole carry, with hugs still telegraphed; a hug shakes the egg out (recoverable 30 s) |
| Payoff | Hatch at the hub incubator into **Caramelux** (Legendaria, 4 Esencia per minute in the corral). The banner names the claimant to the server: "¡Nombre consiguió el Huevo Piñata!" |
| Fairness | Exactly as a normal Mimo encounter; the only difference is where you stand when you misread. Hide spots are absent inside the ring (3.2), so the carry out of the ring is the real test |

## 6. Zones and rules

| Zone | `Rules.zone` result | Who can act |
| --- | --- | --- |
| Hub (centre) | `safe = true`, `fog = false` | Nobody hunts; corral, incubator, trophies, shops |
| Gate bands (east and west) | `safe = true` | Blend of atmosphere and ground; the beasts stop here |
| `golosina` | new flag `kids = true`, `fog = false` | El Mimo poses and chases; La Silueta never |
| Quioscos | `safe = true` | 3 circles of radius 14 |
| `peluche` heart | `kids = true`, Legendaria band | Event site, no hide spots |

The west rule stays: La Silueta's territory and fog rectangle are hers; the two beasts never share a zone, so a child who wants no horror can stay east all session and still progress.

## 7. Economy hooks (design only, no purchases)

The user's direction is "a strong, honest incentive, not a wall". This biome offers these hooks to the economy design, nothing is implemented:

| Hook | Free path | Convenience candidate (Robux, later, only with Creator Hub, receipts and saved progress) |
| --- | --- | --- |
| Corral slots | 8, more from the skill tree with Esencia | None proposed: the pen is the collection, and paying for it would read as a wall |
| Caramelo señuelo | Found in gift boxes, crafted at the hub (materials, cap 3) | A pack of señuelos, clearly priced, same item, no stat change |
| Guantes de peluche | Crafted (I1 gloves): calm meter +30% here too | Same glove, bought earlier; never stronger than the crafted one |
| Event banner | Everyone sees it | Nothing: the event must stay shared |

Rules kept: clear prices, no paid randomness, no loot boxes, pay for time not for power, the free path always viable.

## 8. Joining the hub: Puerta Golosina (east gate)

| Element | Rule |
| --- | --- |
| Position | On the hub's east edge, on the hub's own route width (14 studs). With the hub centre at H, the arch stands at H + (60, 0); the biome's 400 x 400 square runs from x = H + 60 to H + 460; El Baúl at about H + (330, -40) |
| The arch | Two candy-cane posts and a striped bow, 16 studs tall, with a Pompón weather vane; a sign with a lollipop icon and the word "Bosque Golosina" (icon first, so a child who cannot read yet still knows) |
| Blend band | 40 studs east of the arch: ground lerps from hub stone to wafer and sorbet grass, sprinkles increase, `gateEast` atmosphere lerps `camp` → `golosina` by x; ambient audio crossfades from the hub's fire to music-box chimes |
| First sight | Quiosco 1 is 25 studs inside the band and a guaranteed Común spawn stands 15 studs beyond it, so the first catch and the first safe spot are both visible from the arch |
| Beast boundary | El Mimo's leash never reaches the band; La Silueta is clamped to the west. Both stop and turn at their edge, visibly |
| Streaming | Fits StreamingEnabled with the same dwell gate; the biome is a region of the one place, not a separate place |
| Offline pattern | `tools/plan_golosina_layout.py` with `tools/test_plan_golosina_layout.py` (seeded JSON, SVG, optional PNG, like `plan_forest_layout.py`), `tools/build-golosina-kit.py` for the Blender kit, an exporter like `export_forest_layout_luau.py`, and a dress script like `tools/dress-wildbound-forest.luau`. Species stand-ins join `WildboundSpecies.LOOKS` the way the island species did |

## 9. Decisions for the user

1. Name: **Bosque Golosina**, or another candy-and-toy name.
2. El Mimo's hug: shakes out one carried item (proposed), or only candy and never a creature or egg.
3. Other players see your El Mimo faint (default, as F2), or not at all.
4. Corral earning only while online (proposed) and the 0.5 / 1 / 2 / 4 per minute ladder, pending the simulator.
5. Whether the thread pull pays Esencia (3, once per wave) or only clears the poses.

## 10. Risks and limits

- Nothing is measured: no device budget, no phone, no child has seen a copy's tells. The "two tells at 15 to 25 studs" claim is the first thing to playtest with a real 7-year-old.
- The corral is passive income; even online-only and capped, it can pull players out of the biomes. The simulator run in 3.4 decides, not this document.
- Per-player beasts double the pathing load when both biomes are full; stagger replans as F2 plans.
- The hug "carries you to the Quiosco" moves a character server-side; it must use the same gates and the same no-catch-up rule as a strike, or it becomes a griefing tool on a stalled server.
