# Biome 2: a bright, cute biome with its own beast (design proposal)

Status: **design proposed, awaiting user decisions. Nothing here is built, inserted or approved.** Written 2026-11-09 for Part 5 of the approved plan (PH "Noches y oleadas"): a second biome that is bright, colorful and cute for kids, reachable from camp like the forest, with its own beast. Every number is a hypothesis. No asset ID below is invented: all come from a `search_asset` run on 2026-11-09 against the Studio instance for place `122652861404212` (read-only; nothing was inserted and Play was not started).

Spanish appears only in player-facing names and text. Names have had no trademark search (see decision X5 in `docs/design/wildbound-expansion-bible.md`).

## Quick path

| You are | Read |
| --- | --- |
| The user | Section 7 (recommendation and decisions), then section 2 (the two biomes) and section 5 (the beasts), then section 8 (toolbox pictures) |
| Writer of the atmosphere or species data | Sections 2, 3 and 4 |
| Writer of the beast | Sections 1, 5 and 6 |

## 1. Facts this design rests on

| Fact | Value | Source |
| --- | --- | --- |
| La Silueta | base 6 studs/s, detection 28; night 8 / 38, Fog scope only; visual 1.3x | `src/wildbound/WildboundWorldRules.luau:148-154`, `docs/mechanics/wildbound-creature-night-profiles.md` |
| Strike telegraph | 0.9 s, never under 0.8 s; warning lead 0.8 s; staged strike: first hit marks and drops one bag item, second defeats; damage only in private mode | `WildboundWorldRules.luau:17`, `docs/mechanics/wildbound-fair-strike.md` |
| Fair-strike gates | persistent model, dwell, target-only warning with acknowledgement, staged consequence, preload; every failed gate cancels the strike | `docs/mechanics/wildbound-fair-strike.md` |
| Player speeds | walk 16, sprint cap 24 for about 4 s (pool 100, drain 25/s) | plan context; `WildboundStamina.luau` |
| Chase after fix F3 (planned) | hunt speed above 16 and below 24 (17 at night), chase limit 12/15/18 s, memory 4-6 s, ends on safe zone, hide spot or leash | `~/.claude/plans/enchanted-jingling-mccarthy.md`, F3 |
| Per-player hunter (planned F2) | one hunter per player, bound to its owner; others see it faint; `MAX_HUNTERS` 8 | plan, F2 |
| Rarity by distance (planned W2) | Comun > 120 studs from the beast's home, Rara 80-120, Epica 45-80, Legendaria < 45 | plan, W2 |
| Wave clock and events (planned) | 5-minute waves reroll spawns and Refugios; a biome event every 20 minutes shows a special egg for 5 minutes near the beast's home | plan, W3, W5, G1 |
| Species data shape | `name`, `size` (studs), `body`, `accent`, `eye`, `glow`, `rig`, `asset`; cria scale 0.55 | `src/wildbound/WildboundSpecies.luau:21-35` |
| Pet height | at or under 5 studs so a pet never hides its owner; Lumipol is 3 x 2 x 2.4 | `wildbound-expansion-bible.md` 5.9; `WildboundSpecies.luau:22` |
| Atmosphere data shape | per zone and time of day: `density, offset, haze, fogStart, fogEnd`; per time of day: atmosphere, fog, ambient and outdoor colours, `ambientWeight`, `brightness`, `exposure`, flashlight | `src/wildbound/WildboundAtmosphere.luau:8-22` |
| Atmosphere floors | `fogStart` 15, `fogEnd` 45, ramp 3, density 0.9, haze 6.5 | `WildboundAtmosphere.luau:26` |
| Asset rules | 1 Blender unit = 1 stud; one mesh, one material; Neon parts separate; CanQuery only on trunks | `wildbound-expansion-bible.md` 5.1 |
| User direction for the forest | 99 Nights in the Forest is a reference for the forest's look only (first map: stylized low-poly trees, palette, campfire warmth), not its night ladder; Wildbound adds its own look so it is not a copy | user, 2026-11-09; plan Part 7 |

**How biome 2 relates to the forest.** The forest stays the dark biome and the horror. Biome 2 is its deliberate opposite: wide sightlines, pastel light, a night that glows instead of going black. The two share the same low-poly, flat-shaded, one-material-per-part build so they read as one game, and the same rules (per-player hunter, fair strike, wave clock, rarity bands). The forest aesthetic reference (plan Part 7) is a separate document; nothing here changes the forest.

## 2. Two biome candidates

Both are about 300 x 300 studs (walk across in about 19 s), flat with gentle mounds, reached from camp by a visible path opposite the fog. Both keep camp as the permanent safe zone and add 2-3 wave-clock Refugios. The beast's home sits at the far end, with its ground (territory, 60 studs) marking the Epica and Legendaria bands.

### 2.1 Pradera Luminosa (pastel meadows, giant mushrooms, fireflies)

| Item | Proposal |
| --- | --- |
| Identity | A sunlit meadow of soft hills, giant spotted mushrooms you can walk under, flower drifts, a shallow stream with stepping stones. At night the meadow does not go dark: mushrooms glow, fireflies rise, the sky turns violet-blue. "La noche brilla" |
| What kids read first | Round shapes, no spikes; the only tall things are mushrooms, which are shelters, not threats. Danger always has its own colour (section 5) |
| Palette (prefix `PL_`) | `PL_Grass A8E06A`, `PL_GrassLight CFEF9A`, `PL_Soil C89A6B`, `PL_CapRed F2726B`, `PL_CapPink F4A6C8`, `PL_CapBlue 7FB8E8`, `PL_Spot FFF7E6`, `PL_Stem F1E6D2`, `PL_Petal FFD166`, `PL_PetalLilac C9A7F0`, `PL_Water 9FE3E0`, `PL_Stone B9C2B4`, `PL_Neon_Glow FFF2A8` (firefly and gill glow, own part, emission 0.75) |
| Props (8) | `PL_GiantMushroom` (24 x 24 x 22, cap is a roof with `clear` 14 x 9 under it: hide spot and rain roof), `PL_MushroomCluster` (6 x 6 x 5, `gather` point), `PL_FlowerDrift` (8 x 8 x 2, `tiny`), `PL_RoundTree` (16 x 16 x 20, lollipop crown of 3 lobes), `PL_StreamStone` (5 x 4 x 1, `walk`), `PL_PollenPuff` (4 x 4 x 4 bush that puffs when touched: noise cue), `PL_FireflyJar` (lantern on a stick, 3 x 3 x 7, Neon: Refugio marker), `PL_HollowLog` (6 x 14 x 5, crawl-through, `clear` 4 x 4: second hide spot) |
| Day | Warm high sun, long soft shadows, fog nearly absent |
| Dusk | Peach and lilac sky, first fireflies |
| Night | Violet-blue, brightness 0.7 (forest night is 0.4), mushroom gills and fireflies as the main light, flashlight weak. Still fully navigable with no flashlight: that is the point of a kids' biome |
| Sound | Birds and bees by day, crickets and a soft chime loop at night. Danger has its own sound (section 5) |
| Resources | Pollen (from `PL_PollenPuff`, loud) and Dew (from `PL_MushroomCluster`, quiet). Uses wait for the economy pass; no new currency |

### 2.2 Bosque Caramelo (candy trees, syrup rivers)

| Item | Proposal |
| --- | --- |
| Identity | Cotton-candy trees in pink and mint, gumdrop bushes, a slow river of amber syrup with wafer bridges, lollipop signposts. Night is a sugar-glaze blue with candy-cane lanterns |
| What kids read first | Everything is food-shaped and friendly; the beast is the one thing that is not edible-looking |
| Palette (prefix `BC_`) | `BC_Cotton F7A8D8`, `BC_CottonMint A9EBD3`, `BC_Trunk 8C5A3C` (chocolate), `BC_Gumdrop E8554E`, `BC_GumdropLime B5E550`, `BC_Syrup E09A2F`, `BC_Wafer E9C98A`, `BC_Sugar FFFFFF`, `BC_Cane D7263D`, `BC_Neon_Glaze 9FD8FF` |
| Props (8) | `BC_CottonTree` (18 x 18 x 24), `BC_GumdropBush` (5 x 5 x 4, `gather`), `BC_WaferBridge` (5 x 16 x 2, `walk`), `BC_SyrupBank` (river edge, `walk` top; syrup slows walking to 10, like the Living Forest stream rule), `BC_LollipopPost` (3 x 3 x 8, Refugio marker, Neon), `BC_CaneArch` (28 x 8 x 16, `clear` 14 x 11), `BC_CookieRock` (6 x 5 x 3), `BC_JellyDome` (10 x 10 x 8, translucent dome you can step inside: hide spot) |
| Day | Bright pink-tinted sun, high saturation |
| Night | Blue glaze, lanterns and the syrup river glow |
| Sound | Pops and bubbles, a music-box loop |
| Resources | Syrup (river banks) and Sugar (gumdrop bushes) |

### 2.3 Side by side

| | Pradera Luminosa | Bosque Caramelo |
| --- | --- | --- |
| Distance from the forest's look | Same world, different light: trees, stones, logs and water are shared vocabulary, recoloured | A different world: food shapes clash with the forest's bark, antlers and fog |
| Readability on phones | High: large flat colour fields, few saturated accents, danger colour (storm grey or black-and-yellow) stands out against pastel | Lower: everything is saturated, so a warning colour competes with the scenery |
| Creature fit | Round animals and sprouts belong in a meadow | Creatures must be candy too, or they look pasted on |
| Build cost | 8 props, 3 reuse forest geometry (`StreamStone`, log, lantern stick) | 8 new props; translucent domes and syrup need material work |
| Toolbox supply (section 8) | Good: many free low-poly trees, mushrooms, flowers, fireflies | Thin: the free candy trees found are cube-blossom trees, not candy |
| Risk | May read as "generic low-poly meadow" unless the giant mushrooms and night glow carry the identity | Sugar themes are common in kids' Roblox games; harder to own |

## 3. Atmosphere rows (in the shape of `WildboundAtmosphere`)

Proposed values for the `ROWS` and `LIGHT` tables, for Pradera Luminosa. `meadow` is the open biome, `heart` the beast's ground, `refuge` a Refugio. They do not replace the forest rows; adding a biome key to the atmosphere module is code work outside this proposal. Every value is above the module floors.

| Zone | Day `{density, offset, haze, fogStart, fogEnd}` | Dusk | Night |
| --- | --- | --- | --- |
| `meadow` | `{ 0.22, 0.12, 1.2, 90, 700 }` | `{ 0.32, 0.06, 1.6, 70, 450 }` | `{ 0.42, 0.02, 2.0, 50, 280 }` |
| `heart` | `{ 0.30, 0.08, 1.5, 70, 500 }` | `{ 0.40, 0.04, 1.9, 55, 320 }` | `{ 0.50, 0.01, 2.4, 40, 200 }` |
| `refuge` | `{ 0.18, 0.15, 1.0, 100, 800 }` | `{ 0.26, 0.08, 1.4, 80, 520 }` | `{ 0.34, 0.03, 1.8, 60, 340 }` |

| Time | atmosphere | fog | ambient | outdoor | ambientWeight | brightness | exposure | flashlight `{brightness, range, angle}` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Day | `{ 232, 214, 236 }` | `{ 244, 230, 240 }` | `{ 150, 142, 160 }` | `{ 172, 162, 182 }` | 0 | 1.0 | 0.1 | `{ 0, 55, 60 }` |
| Dusk | `{ 250, 186, 150 }` | `{ 238, 182, 176 }` | `{ 118, 100, 132 }` | `{ 140, 112, 144 }` | 1 | 0.85 | 0 | `{ 1.5, 55, 60 }` |
| Night | `{ 92, 100, 164 }` | `{ 72, 82, 134 }` | `{ 72, 82, 122 }` | `{ 84, 94, 134 }` | 1 | 0.7 | -0.15 | `{ 2.5, 55, 60 }` |

Bosque Caramelo would use the same rows with the Day atmosphere colour shifted to `{ 246, 206, 228 }` and Night fog to `{ 96, 136, 176 }`.

Why the night stays bright: in the forest the flashlight is the main light at night (brightness 5). Here the flashlight is a comfort, not a need, so a child who never finds the button still sees the path, the Refugio lanterns and the beast.

## 4. Creature concepts (five, in the shape of `WildboundSpecies.LOOKS`)

All round, big-eyed, Lumipol scale, at or under 5 studs tall, one material per part, Neon glow as its own part. Rarity follows the W2 distance bands from the beast's home. Capture uses the existing calm ring and carry; no new capture method is proposed here.

| ID | Name shown | Rarity | Size (studs) | body | accent | eye | glow | Silhouette and behaviour |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `Pompin` | Pompín | Común | 2.4 x 2.2 x 2.4 | `F6F0DC` | `DCCB8A` | `3A2E3C` | `FFF4C2` | A dandelion puff with two stubby feet and a round face in the fluff. Drifts a few studs when startled; lands and shivers. Night: the puff glows faintly |
| `Setita` | Setita | Común | 2.6 x 3.0 x 2.6 | `F2726B` | `F1E6D2` | `2B2430` | `FFF7E6` | A toddling mushroom cap with big eyes under the brim and white spots. Hides by crouching: cap down, it looks like a prop. Lives at the feet of `PL_GiantMushroom` |
| `Lucita` | Lucita | Rara | 2.0 x 1.6 x 2.6 | `6E8F5A` | `B8D98A` | `1F2A1C` | `FFF2A8` | A round beetle with a lantern belly and tiny wings; bobs 2 studs off the ground. By day the belly is pale; at night it blinks in a 3-beat pattern that gives away its spot (night makes it easier to find, harder to approach: it flees light) |
| `Burbujo` | Burbujo | Épica | 3.2 x 3.2 x 3.2 | `BFEFF2` | `9FE3E0` | `2A3A4A` | `E6FFFF` | A translucent jelly sphere with a single flower floating inside and two dot eyes. Rolls slowly; splits a reflection ring on the ground when calm (capture ring reads inside it). Only near the stream |
| `Solecito` | Solecito | Legendaria | 3.4 x 4.6 x 3.4 | `FFD166` | `F4A6C8` | `3A2E3C` | `FFE9A0` | A sprout with a sun-shaped head of eight soft petals that open when calm and close when scared. Walks on two root feet. Spawns only inside the beast's ground; its open petals light a 12-stud circle at night, which the beast also sees |

For Bosque Caramelo the same five reskin: Pompín becomes a cotton-candy puff (`F7A8D8`), Setita a gumdrop (`E8554E` with `FFFFFF` sugar), Lucita a jelly bean with a glaze belly, Burbujo a bubble-gum bubble, Solecito a lollipop sprout.

Why five and not more: the forest registry already has Lumipol plus four rig species; five here keeps the collection book balanced between the two biomes and fits one Blender wave.

## 5. Four beast proposals

**Shared by all four, without exception.** The beast is per player (F2): one hunter bound to each player, visible faint or not at all to others (user decision, default faint). Every strike goes through the existing fair-strike gates unchanged: persistent model, dwell, target-only warning with acknowledgement, staged consequence, preload. Telegraph at least 1.0 s here (floor 0.8 s), longer than La Silueta's 0.9 s, because this biome's players are younger. Hunt speed above walk 16 and below sprint 24 (17), chase limit sized to the sprint (12/15/18 s), memory 4-6 s, a Refugio or a hide spot ends the chase (F3). Strikes only inside the beast's ground (60 studs around its home), never at camp, on a Refugio or in a hide spot. Each tell is shape plus colour plus sound plus a Spanish chip, so it works muted and on a phone. Each has at least one free counterplay needing no pet. No gore, no blood, no screaming faces: the fear is "it saw me", not injury.

| | La Abeja Reina | El Mimo | El Camaleón | La Nube Tormenta |
| --- | --- | --- | --- | --- |
| One line | A huge smiling bee that hunts by sound and leaves honey that slows you | A plush that pretends to be a creature and grabs the hand that reaches for it | A long lizard hidden in the flowers that opens two big eyes before its tongue shoots | A small private storm cloud that follows you and strikes where its shadow is |
| Look | Round striped body 9 studs long, four stubby legs, two round eyes, a fixed friendly smile that only widens when hunting (same trick as La Silueta's grin, head-locked); wings blur, no stinger shown | A 5-stud sitting plush shaped like a Setita or Pompín but slightly too big, button eyes, a stitched mouth; when it reveals, the mouth unzips into a dark pocket | 12 x 4 x 3 studs, flat, matte flower colours (`PL_PetalLilac`, `PL_Grass`), transparency 0.85 while still; eyes are two `Neon` discs 1.2 studs wide | A 10-stud fluffy cloud, slate grey against pastel, two sleepy eyes, hovers 18 studs up; its ground mark is an authored dark ring 6 studs wide, not a real shadow (low phones may not draw shadows) |
| Where | Home at the far end in a 14-stud hive mound; patrols the Epica band on a slow loop | Sits in creature spawn points inside the Epica and Legendaria bands; never patrols | Lies in flower drifts inside its ground; moves only between drifts, at night |
| | | | | Spawns above its owner when the owner enters the beast's ground; leaves when they leave |
| Senses | **Noise only** (reuses the existing noise and Investigate path: sprint, capture ring, pollen puff, totem). Does not see | Nothing until a capture ring starts on it | Sight in a 60-degree cone of 30 studs, but only while its eyes are open | Its owner's position, always. There is no hiding from it in the open: only roofs |
| Hunt rule | Hears a noise: flies to it at 17, hovers, and if the owner is within 20 studs starts the telegraph. A hunt lasts at most 15 s, then she returns to the hive | On ring start it rises 1.0 s (telegraph), then lunges 6 studs. Hit or miss, it chases 6 s at 17, then flops and is harmless for 20 s | Owner inside its cone: eyes open (telegraph 1.0 s, eyes glow, a low "tsk" sound), then the tongue reaches 10 studs and pulls the owner 6 studs toward it. It never leaves its drift during a strike | Drifts toward the owner at 9. Every 8 s inside the ground: the ring glows amber for 1.2 s (telegraph), then a bolt lands on the ring |
| Telegraph tell | She rises 3 studs, her stripes flash from black to amber twice, loud "ZZZ", chip `¡La Abeja te oyó!` | Button eyes turn to black, mouth unzips, a zipper sound, chip `¡Es El Mimo!` | Two big eyes light up in the flowers, chip `¡El Camaleón te ve!` | The ring fills amber, a rising hum, chip `¡Rayo!` |
| Hit | Staged strike as today: mark and drop one item. Her honey splash leaves a puddle for 6 s: walk speed 10 inside | Mark, drop the item the ring was for, and the Mimo keeps the stolen creature on its lap for 30 s (owner can take it back when it flops) | Mark and drop; the pull is 6 studs, never into a pit or out of the map | Mark and drop; a small dust ring, no fire |
| Free counterplay | Stand still or walk: noise 0 and 15; she cannot find a quiet player. Hide under a `PL_GiantMushroom` cap or in a `PL_HollowLog`. Cross the stream: she will not fly over water | Watch before you reach: real creatures blink and breathe, the Mimo does not; it also casts no capture-calm halo. The free flashlight makes its button eyes shine. After a flop, walk away | Read the ground: flowers around it are a shade paler. Do not stand still inside the cone. Walk sideways: the tongue only reaches straight ahead | Step out of the 6-stud ring (from the centre, 0.4 s at walk speed, against a 1.2 s telegraph). Stand under any giant mushroom cap or `PL_RoundTree` crown: roofed means no bolt. Leave the beast's ground: the cloud dissolves |
| Lumipol and tools | Lumipol pulse quiets your noise for 4 s (new effect, small) | Lumipol pulse reveals a Mimo within 20 studs: it blushes | Flashlight direct for 1.5 s makes it close its eyes for 2 s | Totem noise does nothing; the Amuleto (I1) extends the ring warning by 0.3 s |
| How it differs from La Silueta | Loud, visible, warm; hears instead of sees; hiding is standing still, not breaking line of sight; day and night the same | Ambush, not patrol. You walk into it by choice; the lesson is "look before you grab", which is the game's own verb turned against you | Static and territorial; the whole fight is reading the ground and the cone; it never chases out of its drift | Vertical. No ground chase, no sight, no hearing; the only question is "am I standing in the ring, and is there a roof" |
| How kids read the threat | Black-and-yellow stripes are the universal "careful" colour; the hum gets louder as she nears; the chip names her | The too-big creature that does not blink; the unzip is a clear "nope" moment; a 20 s flop gives a laugh and an escape | Two glowing eyes in flowers; paler flowers as a learnable clue; the pull is scary but short | A ring on the ground is the simplest tell in the game; the hum and the fill bar read muted |
| Per-player fit | Each player's bee hears only its owner; a loud friend does not bring your bee. Others see a faint bee | Each player's Mimo spawns only on points the owner has not yet captured; two players reaching for the same creature get their own result | One Camaleón per player, placed in a different drift per owner; others see it faint | Each player has their own cloud; roofs are shared; a friend's bolt cannot hit you |
| Risks and what would falsify | Noise-only hunting may feel random if the player does not know what made noise: the chip must name the noise (`Oyó tu carrera`). Falsified if testers cannot say why she came | A "gotcha" can feel unfair to younger kids. Falsified if testers rage at the first Mimo; mitigation: the first Mimo in a session is always revealed by a Pompín sneezing at it | Static beasts are easy to ignore; Legendaria spawns must sit inside its cone so the choice is real. Falsified if players never enter the cone | Flashing light and a hovering shape that never leaves can read as stress, not fun. Falsified if kids leave the ground within 20 s every time; reduced-effects mode replaces the flash with a ring fill |
| Build size (rough) | Medium: reuses noise and Investigate; new hover path, honey puddle, hive home | Medium: new ambush state on capture start, mimic look pick, flop timer | Medium-high: cone sight (new), transparency rule, tongue pull (physics on the character, must be tested) | Medium: ring telegraph is a new strike shape; roof check is a server raycast upward; no pathing at all |

### 5.1 Comparison

| Question | Abeja Reina | Mimo | Camaleón | Nube Tormenta |
| --- | --- | --- | --- | --- |
| Most different from La Silueta | Yes (hearing) | Yes (ambush) | Partly (still sight) | Yes (vertical, no senses) |
| Fairest to explain in one sentence | "Quiet players are safe" | "Look before you grab" | "Stay out of the eyes" | "Step out of the ring" |
| Cute and scary at once | Best fit for a kids' biome | Good; a bit mean | Harder to make cute | Good; very readable |
| Reuses existing code | Noise, Investigate, hunt and retreat | Capture session hooks | Little | Fair-strike gates, dwell, warning |
| Toolbox supply (section 8) | Good | Good (plush models) | Poor | Fair |
| Fits the 20-minute biome event | She leaves the hive to guard the special egg | A Mimo sits beside the special egg | The egg lies inside the cone | The event is a storm over the egg |

## 6. Economy and rules that must hold

- Biome 2 pays the same Esencia per tier as the forest; it must not be the easy farm. The lever is tier placement: Epica and Legendaria exist only inside the beast's ground, so the risk is the beast, not darkness. `tools/simulate_economy.py` must be run per biome once spawn tiers exist; the 180 s greedy median floor holds for the forest and should be measured here, not assumed.
- Rarity bands by distance (W2) and the 5-minute wave reroll apply unchanged. Whether biome 2 rotates variants on the wave clock is an open decision (section 7).
- Every new constant goes in the dev tuning schema: `MEADOW_TELEGRAPH` 1.0 (0.8-2.0), `MEADOW_HUNT_SPEED` 17 (16-23), `MEADOW_TERRITORY` 60 (40-100), beast-specific values (honey slow 10, Mimo flop 20 s, cone 60 degrees / 30 studs, ring radius 6 / period 8 s).
- Damage stays off outside the private place, as today. The staged strike (mark, then defeat) is kept so the rules are the same game-wide; a gentler biome 2 consequence (mark only, never defeat) is an open decision.

## 7. Recommendation and open decisions

**Recommendation: Pradera Luminosa with La Abeja Reina as the beast, and La Nube Tormenta kept as the biome event ("la tormenta") rather than a second beast.** Reasons: the meadow shares the forest's build vocabulary so the world reads as one game and the free toolbox supply is good; the bee is the clearest "cute but careful" shape for kids, its hunting reuses the noise and Investigate systems already built and tested, and "quiet players are safe" is a rule a six-year-old can state. The storm cloud is the most original of the four and the simplest to make fair, but a cloud that never leaves you can read as stress; as a 5-minute event over the special egg it is a highlight instead of a constant. El Mimo is the best second idea and fits the game's own verb; propose it later as the Legendaria guard. El Camaleón needs the most new code for the least cuteness.

Open decisions for the user, one at a time:

| # | Decision | Default if nothing is said |
| --- | --- | --- |
| B1 | Pradera Luminosa or Bosque Caramelo | Pradera Luminosa |
| B2 | Beast: Abeja Reina, Mimo, Camaleón or Nube Tormenta | Abeja Reina, with Nube Tormenta as the event |
| B3 | Keep the staged strike (mark then defeat) in biome 2, or mark only | Keep, same rules game-wide |
| B4 | Do other players see your beast faint, or not at all | Faint (same as the forest decision) |
| B5 | Does biome 2 rotate variants on the wave clock (for example Rocío, Polen, Arcoíris, Luciérnagas), or stay fixed | Fixed for the first build |
| B6 | Creature names and these five concepts | Keep; rename freely before any release |
| B7 | Which toolbox candidates (section 8) may be inserted into the place, if any; the alternative is building the kit in Blender like the forest | None inserted until chosen |

## 8. Free toolbox candidates

Found with `search_asset` (scope `creator_store`, `priceFilter` free, type Model) on 2026-11-09. **Nothing was inserted.** "Scripts" is only what the listing's own description said; a listing that says nothing is marked unknown and must be inspected after insertion, never trusted. "Content Deleted - 158552482" is the creator name Roblox shows for a deleted account; those assets still download but have no one to ask about licence or updates. Thumbnails are 420 x 420 PNGs saved under `assets/exports/toolbox-candidates/`; particle emitters render as near-blank thumbnails.

| Role | assetId | Name | Creator | Free | Scripts (per listing) | Image | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Trees (Pradera) | 89384936911598 | Low Poly Tree Cartoon Nature Plant Trees Pack | Content Deleted - 158552482 | Yes | "No scripts", 2 parts, 2 meshes, about 32 x 24 x 26 studs | `assets/exports/toolbox-candidates/trees-pradera-89384936911598.png` | Round three-lobe crown; closest to `PL_RoundTree`; deleted creator |
| Trees (Pradera) | 106015195336756 | Low Poly Tree - Cartoon Pack Forest Nature | brotherffa_7012 | Yes | Unknown | `assets/exports/toolbox-candidates/trees-pradera-106015195336756.png` | Same crown style, live creator |
| Trees (Pradera) | 82481220403211 | [UPD] low poly mushroom Tree Grass Rock | 1mecf | Yes | Listing tags say "No Scripts" (tag spam, unverified) | `assets/exports/toolbox-candidates/trees-pradera-82481220403211.png` | Kit: the thumbnail shows a red spotted mushroom pair with grass; closest to the `PL_GiantMushroom` and `PL_MushroomCluster` look |
| Giant mushrooms | 121960871109956 | Mushroom Mushroom Cute Colorful Low Poly | G0ld3nSkat3rLi0n2020 | Yes | Unknown | `assets/exports/toolbox-candidates/mushrooms-121960871109956.png` | Flat-shaded red cap with white spots; best match for the biome's silhouette |
| Giant mushrooms | 72742351050852 | Low Poly Mushrooms Aesthetic Mushroom Cute | GhostHyper9899 | Yes | Unknown | `assets/exports/toolbox-candidates/mushrooms-72742351050852.png` | Faceted red cap, a small one and a rock; reads well at distance |
| Giant mushrooms | 102521383871754 | Mushroom Cottagecore Mushroom Cute Low Poly | Sky150Block | Yes | Unknown | `assets/exports/toolbox-candidates/mushrooms-102521383871754.png` | Blue spotted cap with a glowing stem; a night variant |
| Trees (Caramelo) | 116184295289134 | Candy Tree Pink Sweet Lollipop Trees Land Cotton | Dufanibo16 | Yes | "No scripts", 34 parts, about 13 x 23 x 12 studs | `assets/exports/toolbox-candidates/trees-caramelo-116184295289134.png` | Pink cube-blossom tree, not really candy; 34 parts is heavy for a tree |
| Trees (Caramelo) | 106288267549013 | Candy Tree Sweet Forest Lollipop Gumdrop Decor | SkyCyber8478 | Yes | Unknown | `assets/exports/toolbox-candidates/trees-caramelo-106288267549013.png` | Same cube-blossom style |
| Cute creature | 75063500527379 | Low Poly Pastel Axolotl Cute Underwater Pet | CuanHoops92 | Yes | Unknown; description is tag spam | `assets/exports/toolbox-candidates/creature-75063500527379.png` | Pink cube axolotl with big eyes and blush: the exact "round, big eyes" read; a Burbujo or stream creature stand-in |
| Cute creature | 126032665700479 | Premium Slime Pack - 4 Cute Pets | Oquyomi | Yes | Unknown ("glowing eyes" suggests Neon parts, maybe scripts) | `assets/exports/toolbox-candidates/creature-126032665700479.png` | Four round slimes (purple with crown, blue, orange, green): a ready rarity ladder for Pompín-style blobs |
| Cute creature | 97061612529205 | Bunny | Dadandaub | Yes | Unknown | `assets/exports/toolbox-candidates/creature-97061612529205.png` | Faceted low-poly rabbit, tan and pink; good scale reference for a meadow animal |
| Cute creature | 77359736883287 | Low Poly Strawberry Elephant Cute Plush Pet | CuanHoops92 | Yes | Unknown | `assets/exports/toolbox-candidates/creature-77359736883287.png` | Voxel red elephant; weakest of the four, kept for comparison |
| Beast: La Abeja Reina | 9372187239 | Bee | arthur130909 | Yes | Unknown | `assets/exports/toolbox-candidates/beast-abeja-9372187239.png` | Cartoon bee with huge eyes and a tongue: the friendliest face; would need scaling to 9 studs and a wider smile |
| Beast: La Abeja Reina | 6073325695 | Giant Bee | Devins groupof funness | Yes | Unknown | `assets/exports/toolbox-candidates/beast-abeja-6073325695.png` | Simple yellow and black bee with legs, already larger than a player per the listing |
| Beast: La Abeja Reina | 10810591677 | Giant Bee Rig | MrPeelSlip | Yes | Unknown; "rig" suggests a Motor6D skeleton | `assets/exports/toolbox-candidates/beast-abeja-10810591677.png` | Olive green, "monstrous"; useful only as a rig reference |
| Beast: El Mimo | 93087855531014 | Cute Teddy Bear Plush Toy Decoration RP | b3ar_992003 | Yes | Unknown | `assets/exports/toolbox-candidates/beast-mimo-93087855531014.png` | Smooth white plush, seated; reads as "toy", the right wrongness |
| Beast: El Mimo | 70559110983836 | Big Teddy Bear Plush Toy Stuffed Animal Decor Cute | Content Deleted - 158552482 | Yes | "No scripts", 4 parts, 4 meshes, about 2.2 x 3.4 x 2.7 studs | `assets/exports/toolbox-candidates/beast-mimo-70559110983836.png` | Same idea with part counts stated; deleted creator |
| Beast: El Mimo | 93008628565422 | Bunny Toy Cute Kawaii Plushie Cuddle Carry Rp | Rexcr9049 | Yes | Unknown ("carry" may mean a tool script) | `assets/exports/toolbox-candidates/beast-mimo-93008628565422.png` | White round bunny plush; could double as a Pompín mimic |
| Beast: El Camaleón | 8174402372 | Chameleon | MaxxMer2 | Yes | Unknown | `assets/exports/toolbox-candidates/beast-camaleon-8174402372.png` | Textured blue chameleon, realistic style; clashes with flat shading |
| Beast: El Camaleón | 6938661046 | Chameleon | fa3_FaUTG | Yes | Unknown | `assets/exports/toolbox-candidates/beast-camaleon-6938661046.png` | Orange blocky lizard with curled tail; crude but flat-shaded |
| Beast: La Nube Tormenta | 134685504688203 | Low Poly Cloud Sky Weather Cartoon Fluffy | Pix_elNeon7354 | Yes | Unknown | `assets/exports/toolbox-candidates/beast-nube-134685504688203.png` | Faceted white cloud; recolour to slate and add eyes |
| Beast: La Nube Tormenta | 32485280 | ETPS Fire and Lightning Storm Cloud | Jumprocks | Yes | Unknown; old asset, likely scripted effects | `assets/exports/toolbox-candidates/beast-nube-32485280.png` | Soft blue cloud with a fire particle below |
| Beast: La Nube Tormenta | 406421918 | Lightning Storm Cloud | Mossbird | Yes | Unknown | `assets/exports/toolbox-candidates/beast-nube-406421918.png` | Flat dark cloud with a yellow bolt; reads as an icon |
| Props: flowers | 1353190583 | Low Poly Flower Bush | Catmen126 | Yes | Unknown | `assets/exports/toolbox-candidates/props-flores-1353190583.png` | Green faceted bush with orange and teal flowers; close to `PL_FlowerDrift` |
| Props: flowers | 136744769027061 | Low Poly Flower | slugischeryl | Yes | Unknown | `assets/exports/toolbox-candidates/props-flores-136744769027061.png` | Single pink faceted flower |
| Props: flowers | 72732931377898 | Low Poly Shaded Smooth Flower | AloneVenter | Yes | Unknown ("created in blender") | `assets/exports/toolbox-candidates/props-flores-72732931377898.png` | Flat five-petal pink flower; cheapest, scatters well |
| Props: fireflies | 94165975555042 | Fireflies Particle Sparkles Effect Pack Particles | Content Deleted - 158552482 | Yes | "No scripts", 1 part, 1 particle effect | `assets/exports/toolbox-candidates/props-luciernagas-94165975555042.png` | Thumbnail near blank (particle); deleted creator |
| Props: fireflies | 3347717118 | Fireflies Particle | KoiLeCobra | Yes | Unknown | `assets/exports/toolbox-candidates/props-luciernagas-3347717118.png` | Thumbnail shows faint yellow dots |
| Props: fireflies | 123418944961194 | Fire Flies Effect Fireflies Particle VFX Effects | Stortc7796 | Yes | "No scripts", 1 part, 1 particle effect | `assets/exports/toolbox-candidates/props-luciernagas-123418944961194.png` | Thumbnail renders blank; listing states no scripts |

Candidates looked at and dropped (no image kept): `8182031168`, `84548349`, `215464676` (mushrooms: thin brown clusters or textured realistic caps), `4474858129` (Queen Bee: spiky purple, not cute), `15614363343` (CUTE BEE: a character with a bee hat), `117963175` (Chameleon: blank thumbnail), `1763926712` (Storm Cloud: grey blank thumbnail, "for horror games"), `63259991` (Candyland: a whole baseplate scene, not a prop), `138453712227243` (Storm Cloud: a 77 x 86 stud sky with scripts and sounds).

**Before any insertion, still unverified for every row:** the real part and triangle counts, hidden scripts, licence and moderation state, and whether the model matches the thumbnail. The forest kit precedent (`odd/tasks/fog-forest-visual-kit.md`) is to build our own meshes; the toolbox rows are for the user to pick a look, or to use as blockout stand-ins behind the species `asset` field that is already reserved in `WildboundSpecies.luau`.
