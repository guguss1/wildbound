# Wildbound expansion bible v1 (wave W11)

**Status: proposal only. Nothing here is approved, built or played.** Every biome, species, guardian, number and name stays unvalidated until the user approves it and humans play it. Written 2026-11-07, ahead of gates F1 and F2, with rework risk accepted by the user (`odd/tasks/wildbound-waves.md:14`).

## Quick path

| You are | Read | Then |
| --- | --- | --- |
| The user | Section 8 (decisions), then the biome and species tables | Answer X1 to X10 |
| Blender writer, W12 | Sections 5.1, 5.2 and 5.9, then section 6 | Build only the unit you were given. Invent nothing; report gaps |
| Blender writer, W13 | Sections 4, 5.1, 5.2 and 5.10 | Same |
| Blender writer, W14 and W15 | Sections 2, 5.1, 5.2 and that biome's table in 5.3 to 5.8 | Same |
| Gameplay designer | Sections 3, 4 and 7 | Nothing here authorizes code |

**Reading the labels:** section 1 holds what was verified, with file and line. Everything else is a proposal. All values are hypotheses to test, including budgets, speeds, cooldowns and sizes.

**Out of scope on purpose:** monetization (none), AFK progress (none), uploads, Studio edits, publishing. Guardians cannot be captured.

## 1. Verified facts this design rests on

Later evidence wins: the roadmap says the forest kit is not imported (`docs/wildbound-roadmap.md:56`), but it was imported later the same day (`odd/tasks/fog-forest-visual-kit.md:62-67`).

| Fact | Source | Why it matters here |
| --- | --- | --- |
| Fog Forest plan is 207 prop instances and 74,996 triangles. **Never measured on any device** | `assets/maps/forest-layout/forest-layout-v1.json`; `docs/wildbound-roadmap.md:471` | The only scale data we have. No budget in this document is measured |
| That plan is 512 MeshParts: 130 evergreens, 42 dead trees, 17 logs, 16 lanterns, 1 arch, 1 doorway | Calculated from the layout JSON and `forest-kit-report.json` | Instance count hides the true part count |
| Measured kit props are 338 to 664 triangles | `assets/blender/forest-kit/forest-kit-report.json` | Sets the prop budget range |
| Measured creatures: Silueta 1,288 triangles and 18 bones; Lumipol blockout 1,392 triangles, no rig | `docs/assets/silueta-rig.md:28`, `:33`; `docs/assets/wildbound-creature-visual-studies-v1.md:19` | Sets the creature budget range |
| Imported kit: 1 Blender unit = 1 stud. Frame is Blender `(x, y, z)` to Studio `(-x, z, y)` | `odd/tasks/fog-forest-visual-kit.md:63` | Author at true size |
| All imported MeshParts arrive default gray and unanchored; colors and safety flags are repaired after import | `fog-forest-visual-kit.md:64`; `docs/assets/silueta-studio-import.md:27` | The report must carry each part's color |
| A mesh with two materials lost one: Silueta's Head came back as one MeshPart with no accents | `silueta-studio-import.md:29` | One object, one material, always |
| Rigged Silueta arrived 2.4 studs tall and was rescaled by hand to 8.57 | `silueta-studio-import.md:23` | Author rigs at final stud height; no rescale step |
| Neon hex shifts: `F08C2E` rendered yellow, so the template uses RGB 205, 92, 18 | `fog-forest-visual-kit.md:65` | Neon hex values below are starting points; check in a capture |
| Kit meshes are CanCollide and CanTouch false. CanQuery is false except on tree trunks: `FK_Evergreen_Trunk` and `FK_DeadTree_Wood` block sight with `PreciseConvexDecomposition`, measured in Studio | `docs/maps/wildbound-p0.md:29-30` | Roblox documents that CanQuery false parts are exempt from raycast hits ([raycasting](https://create.roblox.com/docs/workspace/raycasting), read 2026-11-07). Tree trunks in new kits follow the same rule, keeping trunks as their own part. Built architecture uses the occluder boxes below |
| Line of sight is a server raycast from guardian body to player root | `src/wildbound/WildboundWorld.server.luau:115-123` | Occluders need their own query parts |
| Steering is straight-line, not pathfinding | `WildboundWorld.server.luau:172` | New guardians need node graphs or walked paths |
| One guardian profile exists: `name`, `specialBehaviorId`, `visualScale`, `base`, `night` | `src/wildbound/WildboundWorldRules.luau:74-80` | New profiles follow this shape |
| Night scope only recognizes `"Fog"`; one home; one fog rectangle | `WildboundWorldRules.luau:87`, `:10-11`, `:48-53` | New guardians need rule changes, not just data |
| Abilities are limited to `Flashlight` and `LumipolPulse` | `WildboundWorldRules.luau:118` | Every new ability needs code |
| Damage is off under streaming | `WildboundWorld.server.luau:32` | All guardians below stay harmless until M4 exits |
| Fair-warning principle: layers A + B + C + D + E, each failed gate cancels the strike and counts it; zero strikes without a delivered warning | `docs/wildbound-roadmap.md:217`, `:219`, `:303` | Every guardian inherits it |
| Silueta's ambush must never read camera or gaze | `docs/wildbound-roadmap.md:162`, `:299` | Gaze belongs to El Vigia alone |
| Player walk speed 16 is documented, not rechecked here | `docs/wildbound-roadmap.md:148`, `:481` | Crossing times below assume it |

**Video advice** in the shared library (first minute, mobile first) is used as a hypothesis only: `C:/Users/Jesus/Documents/Roblox/roblox-codex-starter/knowledge/youtube/DLWYPHMGfMs/notes.md:15-18`.

**Pack material** (`resources/skill-packs/.../knowledge/wildbound/WORLD_BIOMES.md`, `MONSTERS.md`, `CREATURES.md`, `GUARDIAN_PET_MATRIX.md`) informed themes and the six roles. Its provenance is unverified (`docs/wildbound-readiness.md:16`), so species names here are new and do not reuse the pack roster.

## 2. Six biomes

**Budget warning:** no budget has been measured on a device. The only known data is the unmeasured Fog Forest plan of 207 instances and 74,996 triangles. The caps below sit under that plan on purpose and must be replaced by M9.2 measurements.

**Night rule (proposal, from the pack's night note):** only Fog Forest, Cryptic Ruins and Demon Abyss get hostile night changes and night-only rewards. Other biomes change light only. See X6.

**Resource ties** are names and intended uses only. Amounts wait for the economy proposal (W4a). The deepest biome's reward is deliberately not stronger: Rift Shard buys collection goals only.

### Overview

| Biome | Prefix | Mood against fog | Sector (studs) | Walk across | Instance cap | Triangle cap | Planned mix |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Living Forest | `LF_` | Neutral relief: warm, long sightlines, no fog | 400 x 400 | 25 s | 180 | 40,000 | 162 / 36,000 |
| Frozen Mountains | `FM_` | Bright danger: you see far until the storm | 500 x 500 | 31 s | 170 | 40,000 | 148 / 34,600 |
| Rock and Caves | `RC_` | Closed dark, clear air, glowing crystal | 300 x 300 | 19 s | 130 | 28,000 | 111 / 23,120 |
| Volcanic Lands | `VL_` | Danger you can see and time, at your own pace | 400 x 400 | 25 s | 210 | 30,000 | 190 / 25,540 |
| Cryptic Ruins | `CR_` | Clear air and hard lines, because sight is the game | 300 x 300 | 19 s | 120 | 30,000 | 102 / 25,520 |
| Demon Abyss | `DA_` | Hostile ground, crimson on black, sinking footing | 300 x 300 | 19 s | 120 | 25,000 | 106 / 20,520 |

**If all seven lived in one place:** 1,026 prop instances, 240,296 triangles and 2,007 MeshParts, before creatures. Calculated from the plans. This feeds section 7.

### Living Forest

| Item | Proposal |
| --- | --- |
| Identity | First neutral contrast. Tall broadleaf canopy, open floor, streams. Teaches reading the ground with no threat |
| Palette | `LF_Bark 6B4A2F`, `LF_Leaf 5E9A3C`, `LF_MossBright 8DB04A`, `LF_PaleWood C9A876`, `LF_Petal F2C14E`, `LF_Resin D98A1F`, `LF_Stone 8C8A7E`, `LF_Ribbon D9482B` |
| Props (7) | `LF_Broadleaf`, `LF_ResinStump`, `LF_FlowerClump`, `LF_StreamStone`, `LF_HollowArch`, `LF_TrailPost`, `LF_LogBridge` |
| Traversal rule | Stream water slows walking to 10 studs/s. Stepping stones and log bridges keep full speed. No damage |
| Day | Warm sun, soft shadows, clear distance |
| Night | Cool moonlight, path still readable. No hostile change |
| Resource and reward | Resin, gathered from stumps. Intended use: seal crafting. Low yield, low risk |
| Plan mix | 46 broadleaf, 10 stumps, 60 flowers, 24 stones, 2 arches, 16 posts, 4 bridges |

### Frozen Mountains

| Item | Proposal |
| --- | --- |
| Identity | Wide white slopes where you can see the threat coming, until a storm takes that away. Your own footprints betray you |
| Palette | `FM_Snow E6EFF4`, `FM_Ice 9CCBE0`, `FM_Granite 566069`, `FM_Bark 4A3B33`, `FM_Pine 2F5450`, `FM_Ribbon E0602A` |
| Props (7) | `FM_SnowPine`, `FM_IceSpire`, `FM_RockOverhang`, `FM_ScourShelf`, `FM_Cairn`, `FM_SnowMound`, `FM_IcePass` |
| Traversal rule | Snow records tracks and rock shelves do not. A storm, announced 10 s ahead, whites out for 45 s and wipes all tracks. See Yeti in section 4 |
| Day | Hard bright light and long views |
| Night | Blue dusk light and a pale sky band. Same Yeti, no hostile change |
| Resource and reward | Hoarfrost, scraped from ice spires. Intended use: temporary shelter kits |
| Plan mix | 60 pines, 18 spires, 8 overhangs, 24 shelves, 16 cairns, 20 mounds, 2 passes |

### Rock and Caves

| Item | Proposal |
| --- | --- |
| Identity | Enclosed tunnels. Darkness comes from walls, not air, so crystal light carries far. Fog hides distance; here corners do |
| Palette | `RC_Shale 3F3D3B`, `RC_Limestone 8F8879`, `RC_Clay 7D5A42`, `RC_Ore B0772E`, `RC_Void 121214`, `RC_Neon_Crystal 3FBFA8` |
| Props (7) | `RC_CaveMouth`, `RC_TunnelStraight`, `RC_TunnelBend`, `RC_Stalagmite`, `RC_CrystalCluster`, `RC_OreVein`, `RC_Burrow` |
| Hazard rule | Fixed rockfall lanes. Dust falls for 3 s, then rocks land in a marked strip 10 studs wide for 2 s. Leaving from the center takes about 0.3 s at walking speed |
| Day | Surface bright, tunnels unchanged |
| Night | Surface dark, tunnels unchanged. Caves become the calm place at night |
| Resource and reward | Ore (backpack upgrades) and Crystal (capture tools). Gathering is loud, which matters only if a guardian is added here |
| Plan mix | 3 mouths, 18 straights, 8 bends, 40 stalagmites, 16 crystals, 14 veins, 12 burrows |

### Volcanic Lands

| Item | Proposal |
| --- | --- |
| Identity | Everything dangerous is visible and on a schedule. The opposite of fog: no hiding, only reading the pattern |
| Palette | `VL_Basalt 2E2B2C`, `VL_Ash 6F6863`, `VL_CoolGrey 6C7A85`, `VL_Char 241F1D`, `VL_Ochre A8692C`, `VL_Obsidian 1A1A24`, `VL_Neon_Magma C8481A` |
| Props (7) | `VL_BasaltColumn`, `VL_Vent`, `VL_CoolStone`, `VL_CharredTree`, `VL_AshShrine`, `VL_CrustPlate`, `VL_ObsidianShard` |
| Hazard rule | Vents cycle: 6 s calm, 2.5 s glow and ground ring, 3 s eruption, radius 10. A hit pushes the player out and applies the staged consequence, behind `damageMode` |
| Day | Hazy orange sky, ash fall |
| Night | Dark sky makes glow read farther. Same vent timing, no hostile change |
| Resource and reward | Obsidian. Intended use: totems with a downside |
| Plan mix | 60 columns, 14 vents, 40 cool stones, 36 trees, 2 shrines, 20 plates, 18 shards |

### Cryptic Ruins

| Item | Proposal |
| --- | --- |
| Identity | Silent stone courts. Clean air and straight lines, so you always can look, and looking is the whole contest |
| Palette | `CR_Slab 77717F`, `CR_DeepViolet 3B2F50`, `CR_DrySage 6C7452`, `CR_Neon_Glyph C9A24A` |
| Props (7) | `CR_Colonnade`, `CR_BrokenWall`, `CR_Plinth`, `CR_Archway`, `CR_Reliquary`, `CR_GlyphStone`, `CR_StairRun` |
| Traversal rule | Walls block sight, and sight decides whether El Vigia moves. Plinths show its route. See section 4 |
| Day | Flat gray light, long shadows, no ambience sound |
| Night | Violet dark, glyphs brighter. **Hostile change:** El Vigia waits less and strides faster. Night-only Glyph Shards appear |
| Resource and reward | Glyph Shard. Intended use: skill tree nodes |
| Plan mix | 14 colonnades, 40 walls, 14 plinths, 6 arches, 8 reliquaries, 12 glyph stones, 8 stairs |

### Demon Abyss

| Item | Proposal |
| --- | --- |
| Identity | Broken ground over a dark drop. No gore, no religious imagery. Calm stones are the only rest. See X8 on the name |
| Palette | `DA_Ash 4A4650`, `DA_Void 15111B`, `DA_Crimson 7A1F2C`, `DA_Pale BFB6A6`, `DA_Neon_Rift C23A4F`, `DA_Neon_Calm 6FB7C9` |
| Props (6) | `DA_FissureLip`, `DA_FloatRock`, `DA_ThornSpire`, `DA_RiftGate`, `DA_RiftShard`, `DA_CalmStone` |
| Traversal rule | Floating rocks sink 1 stud/s while occupied, for up to 6 s, then rise. Falling returns you to the last solid ground and drops one bag item, never an instant defeat (see B19, `docs/wildbound-roadmap.md:140`) |
| Day | Crimson overcast, readable |
| Night | Near black with rift glow. **Hostile change:** rocks sink at 1.5 studs/s. Night-only Rift Shards appear |
| Resource and reward | Rift Shard. Collection goals and camp trophies only, never power |
| Plan mix | 24 lips, 30 rocks, 30 spires, 2 gates, 14 shards, 6 calm stones |

## 3. Creature roster: 11 new species

Lumipol stays the revealer for Silueta. Roles are the six in the pack: explorer, protector, revealer, distractor, capturer, gatherer. Rig tier: R1 is 4 to 7 bones, R2 is 8 to 10 bones. See 5.9 for exact bones.

**Depends on D3 and M3:** none of these capture methods exist. `CaptureSession` is not built (`docs/wildbound-roadmap.md:280`).

### Identity and capture

Every method works with one thumb. "Window" is the shortest moment that must be hit; none needs sub-frame timing, and all clues show in text and shape as well as color and sound.

| Species | Biome | Role | Rarity | Silhouette | Capture method | Window | Night variant | Rig |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Cortezon | Living Forest | Protector | Common | Low wide dome of bark plates on four stubs | **Patience:** drop bait, walk 12 studs away, stand still until it eats, return and tap | 12 s | None | R1 |
| Cestillo | Living Forest | Gatherer | Common | Walking basket on two legs, bent reed neck, leaf beak | **Offering:** watch what it pecks, then choose that of three items. A wrong choice makes it flee | No timer | None | R1 |
| Zancanieve | Frozen Mountains | Explorer | Uncommon | Thin stilt-legged wader with a fan of ice plates | **Tail it:** walk in its tracks, staying 6 to 14 studs behind for 6 s in total | 6 s, band 8 studs wide | None | R2 |
| Soplillo | Frozen Mountains | Distractor | Common | Six-sided snow puff with one long whip tail | **Dig:** of five mounds, the real one puffs every 4 s. Walk to it and tap. Two wrong digs end it | 4 s repeat | None | R1 |
| Aldabon | Rock and Caves | Capturer | Common | Upright stone block on two stumps with a large iron ring in front | **Plug burrows:** walk to two of three burrows and tap to plug them, then wait at the third | No timer, 30 s session | None | R1 |
| Vetilla | Rock and Caves | Gatherer | Rare | Flat long lizard with a row of crystals down its back | **Herd with light:** it shuns light. Tap crystal clusters on, so the only dark spot is where you wait | No timer, 30 s session | None | R2 |
| Tizoncillo | Volcanic Lands | Protector | Uncommon | Charred log on four stumps, ember cracks | **Escort:** it follows only while you stand on cool stones. Lead it along four stones to a pool | Own pace, vents add risk | None | R1 |
| Humarel | Volcanic Lands | Explorer | Rare | Upright hopper with long feet and a smoke-ring tail | **Windbreak:** stay in the marked 60 degree shelter arc for 6 s. The arc drifts at most 15 degrees/s | 6 s | None | R2 |
| Tinajuelo | Cryptic Ruins | Distractor | Uncommon | Faceless clay jar with lid and two tiny arms | **Look away:** turn your camera from it. It shuffles closer. Tap when it reaches you | 4 s; server minimum 6 s of approach | Violet eyes, moves faster, drops Glyph Shard | R1 |
| Polvilla | Cryptic Ruins | Revealer | Rare | Two huge folded dry wings on a tiny peg body, hovering | **Match glyphs:** tap three glyph stones in the order its wing spots show. Walk at your own pace | No timer, 25 s session | Spots brighter, order is one longer | R1 |
| Espejuelo | Demon Abyss | Capturer | Rare | Flat tilted diamond slab on two thin legs | **Find the true one:** three copies stand, and only one has a marked ground ring. Tap it. Two tries | No timer | Copies become five | R1 |

**Why ground ring, not real shadow:** phones on low graphics may not draw shadows. Clues must be authored parts. Whether that is true on target phones is unverified.

**Server rule for every method:** the server issues a capture token, sets the time limit, reserves the creature and checks distance and life, as M3.2 proposes. The client only reports taps. Look away is the one method that uses a camera hint; the server's minimum approach time caps what a false hint can gain.

### Abilities

| Species | Ability | Effect | Duration and cooldown | Downside | Does not solve |
| --- | --- | --- | --- | --- | --- |
| Cortezon | Bark Guard | Next strike's first stage is absorbed, per D6 | One hit, 90 s | Slows owner 10% while armed | A second strike |
| Cestillo | Extra Peck | +1 material on each gather **while the owner is gathering** within 12 studs | 30 s, 60 s | Bag fills faster, raising loss exposure | Never gathers alone, so no AFK path |
| Zancanieve | Safe Footing | Marks track-free shelves and overhangs within 30 studs | 6 s, 30 s | Owner cannot soft step while it runs | Does not hide tracks |
| Soplillo | Far Puff | Noise pulse at a spot 30 studs away | Instant, 45 s | Your own tracks stay | Yeti still follows fresh tracks |
| Aldabon | Hold Fast | Adds 2 s to any capture session | Once per capture, 120 s | Very loud: noise as a landing | Not usable on guardians |
| Vetilla | Vein Sense | Shows ore and crystal within 40 studs | 8 s, 45 s | Glow makes owner visible at range | Shows nothing about danger |
| Tizoncillo | Heat Ward | Ignores scald ground, not eruptions | 8 s, 60 s | Glows: doubles detection range during ward | An eruption hit |
| Humarel | Burst | +20% walk speed | 6 s, 40 s | Leaves an ash trail; tired for 5 s after, at -20% | Never outruns a Yeti charge |
| Tinajuelo | Decoy Jar | Next El Vigia stride prefers the jar's nearest plinth | One stride, 60 s | Jar is lost if touched | Does not stop El Vigia |
| Polvilla | Route Dust | Shows El Vigia's next two plinths | 5 s, 40 s | Owner hovers a glow, seen by all | Cannot reveal Silueta. Lumipol stays needed |
| Espejuelo | Mirror Copy | Target creature stares at a copy: capture timer pauses 3 s | Once per capture, 90 s | Works only in low light (night, fog, Abyss) | Daylight captures |

### Why rare is not simply better

| Pair | Common or cheaper one | Rare one | Who wins |
| --- | --- | --- | --- |
| Capturers | Aldabon: works anywhere, adds 2 s, loud | Espejuelo: silent, low light only, pauses 3 s | Aldabon by day and in caves. Espejuelo at night near a guardian |
| Gatherers | Cestillo: more materials now | Vetilla: finds nodes, gives no extra | Cestillo on known routes. Vetilla on a new route |
| Explorers | Zancanieve: free route info in snow only | Humarel: speed anywhere, with a trail and a crash | Zancanieve in Frozen Mountains |
| Revealers | Lumipol: the only one that reveals Silueta | Polvilla: Ruins route only | Lumipol in fog, always |
| Protectors | Cortezon: blocks one guardian stage | Tizoncillo: blocks scald only | Cortezon against guardians. Tizoncillo in vents |

**Loadout note:** reserves are still decision D14. Nothing above assumes them.

## 4. Guardians

**Applies to every guardian, without exception:**

- Damage stays off until M4 exits (`docs/wildbound-roadmap.md:219`). No guardian may strike outside the same gates: persistent model (A), dwell gate (B), target-only warning with attack ID and acknowledgement (C), staged consequence (D), preload (E).
- Each failed gate cancels the strike and counts it.
- Every warning works muted and on a phone. Each guardian gets a state chip, built on M2's awareness design, which is not built yet.
- Each has at least one free counterplay needing no pet. No guardian spawns inside a shelter.

### How the three differ

| | La Silueta (exists) | El Vigia | Yeti |
| --- | --- | --- | --- |
| Where | Fog Forest only | Cryptic Ruins only | Frozen Mountains only |
| Can you see it | Almost invisible | Always plainly visible, pale stone | Visible, and its tracks arrive first |
| What it senses | Range and sight (`WildboundWorldRules.luau:77-78`) | Whether anyone is watching | Noise and your tracks |
| Camera or gaze input | **Never** | **Only this one** | Never |
| What you do | Reveal with light, keep moving | Keep eyes on it, plan who watches | Walk softly, cross rock, sidestep |
| Flashlight | Reveals it | No effect | No effect |
| Movement | Slow steady glide, 6 to 8 studs/s | Strides between plinths, frozen when watched | Slow stalk, one straight charge |

### El Vigia: the surveyor

**Originality check:** "only moves when unseen" is a common horror idea, known from general knowledge in works such as Weeping Angels and SCP-173. This design must not copy those looks or moves. So there is no statue, no angel, no blink, no neck break, no lights flickering, no teleport and no sudden appearance. See X4.

**Own idea:** a walking surveying instrument that measures the ruins. It travels only along a visible chain of stone plinths, like a piece on a board, so players can read and plan its route.

**Look:** three long stone-and-timber stilt legs, a hub, and a ring-shaped head with one horizontal shutter slit. Two folding measuring-rod arms. Pale gray stone, unlike Silueta's dark bark, green mantle and antlers. No face, no antlers, no horns, no siren.

| Rule | Proposal |
| --- | --- |
| Route | 14 plinths, 24 to 40 studs apart, in a graph authored per map. It stands on a plinth or is mid-stride between two |
| Sighting | A player sights it when alive, within 70 studs, with a clear server ray from player head to its head, **and** with a valid client hint under 0.6 s old |
| Stride | No sighting for 2.0 s (night 1.5 s): the next plinth's glyph lights, 1 s later it strides there at 12 studs/s (night 14) |
| Halt | Any valid sighting stops it where it stands, for everyone |
| Strike | From within 7 studs and unseen: telegraph 1.8 s with shutter opening and arms unfolding |
| Flinch | Sighted during telegraph: cancels the strike, steps back one plinth, 6 s cooldown |
| After a strike | Retreats two plinths, 8 s recovery |
| Hold limit | One player's continuous sighting counts for 20 s, then not for 6 s. Chip shows it. Partners can swap |
| Group rule | Any one nearby living player's valid sighting holds it. This gives co-op a real job |

**Honest counterplay, all free:**

- Keep moving: 12 is below walking speed 16, so it cannot catch someone who keeps walking.
- Watch it while backing away. **Look lock** button: one tap aims the camera at it while in range and in sight, so one thumb steers (see X10).
- Read the lit plinth and break line of sight on purpose, or step around a wall to choose when it moves.
- In co-op, one watches and one loots. The hold limit stops this being permanent.

**Fair warning:** chip shows `Held by you`, `Held by ally`, `Moving`, `Moving to you`. Next plinth glows 1 s before any stride. Grinding stone sound with a visible dust plume while moving. Telegraph is target-only with acknowledgement. It never enters shelters, jumps or teleports.

**Network limits**

| Limit | Fact or calculation | Design response |
| --- | --- | --- |
| The server cannot see the camera | Camera page labels the class "Not Replicated" ([Camera](https://create.roblox.com/docs/reference/engine/classes/Camera), read 2026-11-07). Implied, not stated outright | Client sends a hint. It is never trusted alone |
| Character facing cannot stand in for gaze | Proposal reasoning: with default controls a character faces where it walks, so facing would make backing away impossible. Not tested | Use the hint, checked by range and ray |
| A forged hint | Worst case equals a perfect watcher with true line of sight and range. Capped by the hold limit. Forging "not looking" hurts only the cheater | Accept this bounded gain. Log the hint rate |
| Hint rate | Sent on change, at most 2 per second, only within 90 studs. Server rate-limits | Up to 4 players at 2 Hz is 8 hints/s |
| Server rays | Recheck holders at 5 Hz: at most 20 rays/s for four players. Calculated, cost unmeasured | Measure in the private place |
| Seen moving after you look | Creep = speed x (server step + round trip). With today's 0.2 s step (`docs/wildbound-roadmap.md:137`): 3.6 studs at 100 ms, 4.8 at 200 ms, 7.2 at 400 ms. Calculated | Stride reads as a lurch that settles. Measure with Network Simulator; if testers call it cheating, lower the speed |
| Lag must not punish | A stale hint keeps counting for 0.6 s | Grace favors the player |
| Telegraph must fit a round trip | 1.8 s, against Silueta's 1.4 s (`WildboundWorldRules.luau:7`) | Latest look-back still lands |
| Model not on the client | Streaming may withhold it; a client ray can miss unstreamed parts ([raycasting](https://create.roblox.com/docs/workspace/raycasting)) | All rays run on the server. Model is Persistent per candidate A. If unseen because unsent, gates B and C cancel the strike |
| Decorative walls do not block rays | Section 1, CanQuery false | Each occluding prop declares occluder boxes (5.2). Studio builds invisible query parts from them |
| API behavior for on-screen check | `WorldToViewportPoint` is listed on the Camera page; behavior not tested | Test first in the private place |

**Not verifiable from documentation:** real creep on phones, the hint's real round trip, and whether players understand the rule. All need the N1 to N4 runs and humans.

### Yeti: noise and tracks

**Look:** low, wide, knuckle-walking mass of dark matted hide crusted with ice plates, with a flat shale plate for a face. Not white, no horns, no cartoon fangs. Height 11 studs at the shoulder hump. Heavy, turning slowly.

| Rule | Proposal |
| --- | --- |
| Noise (server, from position samples at 5 Hz) | Still 0, soft step 15-stud radius, walk 45, landing or failed capture 90 |
| Soft step | HUD toggle: server sets walk speed to 8 |
| Tracks | Server records a point every 6 studs on snow. Up to 24 per player, each lasting 90 s. None on rock or ice shelves |
| Stalk | At 9 studs/s toward the last heard point, then along the freshest track chain within 40 studs |
| Trail end | Stops and sniffs for 3 s, then gives up after 6 s more with no noise |
| Choice it forces | Stalk at 9 is faster than soft step at 8. Once it is on your tracks, walking away is safe but loud |
| Charge | From 12 to 40 studs with clear ground: telegraph 1.8 s, marked lane 8 studs wide, then straight at 22 studs/s for up to 40 studs. Cannot turn |
| After a charge | Skids and recovers for 5 s, wide open |
| Storm | Wipes all tracks. Also hides the Yeti, with chip warning 10 s ahead |

**Why this avoids pathfinding:** track chains are walked ground, so steering stays valid on complex terrain, as long as the player did not jump a gap. Jumps get a break in the chain.

**Honest counterplay, all free:** soft step, cross scoured shelves to break the chain, sidestep the marked lane, hide under `FM_RockOverhang` (no tracks, blocks sight, no spawning inside), and wait for a storm. Leaving a 4-stud half lane takes 0.25 s at walking speed, against a 1.8 s telegraph. Calculated.

**Fair warning:** noise rings on the HUD, muted-safe. Chip: `Heard you`, `On your tracks`, `Charging`. Large Yeti prints show where it walked. Lane is drawn on the ground for all. Target-only warning with acknowledgement.

**Network:** noise uses server position samples, never a client report. Tracks are about 11 points/s for four walking players, roughly 130 bytes/s of data if batched (calculated, overhead excluded). Each client pools at most 126 track marks (4 x 24 + 30 Yeti). Cost unmeasured.

### Profile shape

Follows `WildboundWorldRules.luau:74-80`. Extra keys and new scopes need rule changes and contracts first. `scope = "None"` means no night change.

```lua
ElVigia = table.freeze({
	name = "ElVigia", specialBehaviorId = "Vigia", visualScale = 1,
	base = table.freeze({ speed = 12, detectionRange = 70 }),
	night = table.freeze({ scope = "Ruins", speed = 14, detectionRange = 70 }),
}),
Yeti = table.freeze({
	name = "Yeti", specialBehaviorId = "Yeti", visualScale = 1,
	base = table.freeze({ speed = 9, detectionRange = 45 }),
	night = table.freeze({ scope = "None", speed = 9, detectionRange = 45 }),
}),
```

### Further guardian ideas: optional

**All optional. No specs, no waves.** Each needs X7 before any work.

| Name | Biome | Idea | Free counterplay | Fair warning | Limit |
| --- | --- | --- | --- | --- | --- |
| Zarzamadre | Living Forest | A thicket that creeps between clearings; rare exception in a calm biome | Walk around or cross water | Flowers wilt in a ring 20 s before | Slow, no chase, day only |
| La Tapiadora | Rock and Caves | Seals tunnels instead of hunting. Pressure is on the way home | Take the other route | Dust trail and sound 4 s before a wall closes | Always leaves one open route; never traps |
| El Fuelle | Volcanic Lands | Huge bellows creature that exhales a hot cone from vent to vent | Stand behind basalt columns | Inhales for 2.5 s, cone marked on the ground | Fixed vents, no chase |
| Pastor de Ecos | Demon Abyss | Echoes walk your last 20 s of route and hurt on touch. Punishes retracing during extraction | Do not retrace; loop wide | Echoes visible and pale, 3 s delay | Echoes expire; none near calm stones |

## 5. Asset specs

### 5.1 Rules for every asset

| Rule | Value | Source |
| --- | --- | --- |
| Scale | 1 Blender unit = 1 stud. Author at final size. Never rescale after import | `fog-forest-visual-kit.md:63`; `silueta-studio-import.md:23` |
| Up and facing | Z up. Creatures face -Y, which arrives as Studio -Z | `silueta-rig.md:31`; `silueta-studio-import.md:24`, `:39` |
| Walking axis | Passages are walked along Y, centered on X = 0 | `tools/test_forest_kit.py:66-86` |
| Pivot | Empty root at ground level at the base center. Min Z = 0 within 0.05 | `tools/build-forest-kit.py:6`; `test_forest_kit.py:145-156` |
| Parts | **One mesh object, one material.** Name `<Asset>_<Part>`, parented to the root. Never multi-material | `silueta-studio-import.md:29`; `build-forest-kit.py:6-7` |
| Shading | Triangulated, flat, identity transforms | `build-forest-kit.py:718-734` |
| Materials | Principled, roughness 0.92, specular 0.2, metallic 0 | `build-forest-kit.py:699-715` |
| Glowing parts | Own part, material name contains `Neon`, emission 0.75. No other emission | `build-forest-kit.py:48`; `test_forest_kit.py:199-203` |
| Export (kits) | FBX, forward -Z, up Y, `FBX_SCALE_ALL`, no leaf bones, no animation | `build-forest-kit.py:856-867` |
| Export (rigs) | Model FBX with no baked action, one clip per FBX, `FBX_SCALE_UNITS`, no leaf bones | `silueta-rig.md:63` |
| Build run | `"D:/blender/blender.exe" --background --factory-startup --python <script>` | `build-forest-kit.py:3` |
| Sources | Original geometry only. No downloads, no generators | `build-forest-kit.py:8` |
| Arrival state | Gray and unanchored. So the report must list each part's color, and importers apply it | `fog-forest-visual-kit.md:64` |

**File layout**

| What | Path |
| --- | --- |
| Shared helpers, new | `tools/kit_common.py`, `tools/kit_spec_common.py`. Copy helpers from the forest kit; `build-forest-kit.py` runs on import (`:1120-1123`) and has a hyphen in its name, so it cannot be imported. **Do not edit the forest kit** |
| Kits | `tools/build-<biome>-kit.py`, `tools/test_<biome>_kit.py`, `assets/blender/<biome>-kit/`, `assets/exports/<biome>-kit/` |
| Species | `tools/build-species-rigs.py`, `tools/test_species_rigs.py`, `assets/blender/species/`, `assets/exports/species/` |
| Guardians | `tools/build-guardian-rigs.py`, `tools/test_guardian_rigs.py`, `assets/blender/guardians/`, `assets/exports/guardians/` |
| Biome names | `living-forest`, `frozen-mountains`, `rock-caves`, `volcanic-lands`, `cryptic-ruins`, `demon-abyss` |

### 5.2 Required spec tests

Follow `tools/test_forest_kit.py`: standard library only, read the report and geometry dump, and recompute sizes from triangles instead of trusting the report. Observe RED before building.

| ID | Assertion | Source or status |
| --- | --- | --- |
| G1 | All named assets present in report and dump, and no extras | `test_forest_kit.py:125-127` |
| G2 | Triangles at or under budget. Report count equals dump count | `:129-132` |
| G3 | Reported size matches recomputed within 0.01. Height and longest footprint side within 10% of spec | `:134-143` |
| G4 | Min Z within 0.05. Base center within max(0.5, 10% of footprint) | `:145-156` |
| G5 | Identity transforms, flat shaded | `:158-161` |
| G6 | Non-manifold count reported, part sum matches, **and equals 0** | `:163-168`; zero is new, and all six forest props measure 0 |
| G7 | Exact part object names, as in the table | `:195-197`, widened |
| G8 | Every part has exactly one material and that exact name | New, from `silueta-studio-import.md:29` |
| G9 | Neon parts match the table; emission above 0. All others have emission 0 | `:199-203`, widened |
| G10 | Roughness at least 0.8 | `:205-208` |
| G11 | `.blend` and each FBX exist; FBX starts with `Kaydara FBX Binary` | `:210-216` |
| G12 | Each asset PNG is 800 x 800. Sheet exists. Scale lineup has a 5-stud block | `:218-231`. 6 props: 1500 x 1000. 7 props: 4 columns by 2 rows, 2000 x 1000 |
| G13 | FBX round trip in a fresh scene keeps triangles, size within 0.02, min Z | `:233-240` |
| G14 | Each part's `color_hex` in the report equals the table | New |

**Conditional tests, used where a table names them:**

| ID | Applies to | Assertion |
| --- | --- | --- |
| P1 | Passage (`clear W x H`) | `clear_width` and `clear_height` from `test_forest_kit.py:66-96`: gap at least W and centered on the pivot, height at least H, at least 14 wide and above 5. Report clearance matches within 0.01 |
| P2 | Footprint limit | Bounding box at or under the stated limits, `:188-193` |
| W1 | `walk` | Report lists `collision_boxes` (center and size in Blender axes), each inside the bbox within 0.5. Top vertices within 0.2 of the stated walk height over the walk area |
| O1 | `occluder` | Report lists `occluders` boxes, inside the bbox within 0.5, at least the stated height. Studio builds invisible, CanQuery true parts from them |
| R1 | `gather` | Report lists `gather_point`, within 1 stud of the bbox and at most 5 above ground |
| S1 | `snap` | End ring vertices match the shared tunnel profile within 0.02 |
| N1 | `tiny` | Height at most the stated value, so it never blocks a camera or path. Stays non-colliding |

**Collision rule:** meshes stay non-colliding and Box fidelity, as the forest templates are (`fog-forest-visual-kit.md:64`). Walls and floors come from boxes in the report, built as Parts in W17. Whether this feels right in play is unverified.

### 5.3 Living Forest kit

Parts show `Part: material (triangles)`. Size is X x Y x Z in studs.

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `LF_Broadleaf` | 24 x 24 x 32 | 480 | Trunk: LF_Bark (170); Crown: LF_Leaf (310) | Straight thick trunk, three limbs, crown of four faceted lobes. Short surface roots. Upright, unlike crooked `FK_Evergreen` | Crown min Z 12 | Crown vertices all at Z 12 or higher |
| `LF_ResinStump` | 6 x 6 x 6 | 180 | Stump: LF_Bark (130); Resin: LF_Resin (50) | Cut stump, amber beads running down the -Y side | `gather` at (0, -3, 2.5) | R1 |
| `LF_FlowerClump` | 5 x 5 x 2.5 | 90 | Stems: LF_Leaf (40); Petals: LF_Petal (50) | Five low stalks with four-point flat flowers | `tiny` 3 | N1 |
| `LF_StreamStone` | 5 x 4 x 1 | 80 | Stone: LF_Stone (60); Moss: LF_MossBright (20) | Flat-topped river stone, moss on one edge | `walk` top Z 1 | W1 |
| `LF_HollowArch` | 30 x 14 x 18 | 520 | Wood: LF_Bark (400); Leaf: LF_Leaf (120) | Two living trunks grown together over the path, leafy top. No exposed roots, unlike `FK_RootArch` | clear 16 x 11; limit 32 x 16 | P1, P2 |
| `LF_TrailPost` | 3 x 3 x 7 | 160 | Post: LF_PaleWood (90); Ribbon: LF_Ribbon (40); Stones: LF_Stone (30) | Straight pale post, red ribbon tied near the top, stones at the foot. No light, unlike `FK_LanternMarker` | None | Ribbon top above Z 5 |
| `LF_LogBridge` | 5 x 18 x 2.2 | 300 | Bark: LF_Bark (230); Moss: LF_MossBright (70) | Fallen log along Y, flattened top, moss at both ends | `walk` top Z 2.2, width 4, two end ramps | W1; ramps are boxes tilted at most 30 degrees |

### 5.4 Frozen Mountains kit

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `FM_SnowPine` | 18 x 18 x 26 | 360 | Trunk: FM_Bark (110); Canopy: FM_Pine (170); Snow: FM_Snow (80) | Straight narrow trunk, three short tiers, snow caps on tier tops | None | Snow max Z equals canopy max Z within 0.5 |
| `FM_IceSpire` | 7 x 7 x 14 | 180 | Ice: FM_Ice (140); Base: FM_Granite (40) | Leaning faceted shard, rock collar. Not Neon | `gather` at (0, -3, 2) | R1 |
| `FM_RockOverhang` | 20 x 12 x 9 | 340 | Rock: FM_Granite (250); Snow: FM_Snow (90) | Slanted rock roof on a back wall, open to -Y. Shelter | clear 12 x 6, depth 8; `occluder` height 6; no-track rect in report | Clear box free of triangles; O1 |
| `FM_ScourShelf` | 16 x 16 x 1 | 120 | Rock: FM_Granite (120) | Wind-bare flat rock plate, uneven outline | `walk` top Z 1; no-track rect | W1 |
| `FM_Cairn` | 4 x 4 x 6 | 120 | Stones: FM_Granite (90); Ribbon: FM_Ribbon (30) | Five stacked stones, orange ribbon on a short stick | None | Ribbon top above Z 5 |
| `FM_SnowMound` | 6 x 6 x 3 | 60 | Mound: FM_Snow (60) | Low round faceted hump | `tiny` 3.3 | N1 |
| `FM_IcePass` | 30 x 14 x 18 | 520 | Ice: FM_Ice (320); Rock: FM_Granite (200) | Two rock legs with an ice lintel across | clear 16 x 11; limit 32 x 16 | P1, P2 |

### 5.5 Rock and Caves kit

**Shared tunnel profile.** Closed C-shape extruded along the path, in X and Z. Inner: (-7, 0), (-7, 10), (-5, 12), (5, 12), (7, 10), (7, 0). Outer: (-12, 0), (-12, 12), (-7, 18), (7, 18), (12, 12), (12, 0). The solid has flat faces at both ends and on the bottom strips. **No floor mesh:** a floor would fail `clear_width`. The floor is a collision box in the report.

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `RC_CaveMouth` | 36 x 16 x 20 | 640 | Rock: RC_Shale (480); Clay: RC_Clay (110); Crystal: RC_Neon_Crystal (50) | Rough rock face with an opening, small crystals beside it to read at a distance | clear 16 x 11; limit 38 x 18; `occluder` height 11 | P1, P2, O1 |
| `RC_TunnelStraight` | 24 x 24 x 18 | 420 | Rock: RC_Shale (360); Stain: RC_Clay (60) | Profile extruded along Y from -12 to 12 | clear 14 x 10; `snap`; `walk` floor box; `occluder` height 12 | P1, S1, W1, O1 |
| `RC_TunnelBend` | 30 x 30 x 18 | 480 | Rock: RC_Shale (410); Stain: RC_Clay (70) | Same profile, six segments around arc center (15, -15), radius 18. End A at (-3, -15) facing -Y. End B at (15, 3) facing +X. Both ends need their center offset recorded in the report | Below Z 10, no vertex between radius 11 and 25 of the arc center, within 0.3; `snap`; `walk` floor boxes; `occluder` height 12 | Radial clearance test; S1, W1, O1 |
| `RC_Stalagmite` | 5 x 5 x 9 | 90 | Rock: RC_Limestone (90) | Stepped cone, off-center tip | None | None |
| `RC_CrystalCluster` | 6 x 6 x 5 | 140 | Base: RC_Shale (50); Crystal: RC_Neon_Crystal (90) | Five angled shards from a rock base | `gather` at (0, -3, 1.5) | R1 |
| `RC_OreVein` | 8 x 5 x 6 | 180 | Rock: RC_Shale (130); Ore: RC_Ore (50) | Boulder with raised copper-colored bands on -Y | `gather` at (0, -2.5, 2.5) | R1 |
| `RC_Burrow` | 7 x 7 x 1.5 | 120 | Rim: RC_Clay (90); Hole: RC_Void (30) | Low rim of dirt around a thin dark disc | `tiny` 1.7 | N1 |

### 5.6 Volcanic Lands kit

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `VL_BasaltColumn` | 8 x 8 x 12 | 120 | Rock: VL_Basalt (120) | Three joined six-sided columns at different heights | `occluder` height 10 | O1 |
| `VL_Vent` | 10 x 10 x 3 | 160 | Cone: VL_Ash (110); Glow: VL_Neon_Magma (50) | Low broken cone with glowing throat | `tiny` 3.3 | N1 |
| `VL_CoolStone` | 6 x 5 x 1 | 80 | Stone: VL_CoolGrey (80) | Flat bluish slab, clearly unlike basalt | `walk` top Z 1 | W1 |
| `VL_CharredTree` | 12 x 12 x 16 | 220 | Wood: VL_Char (190); Ember: VL_Neon_Magma (30) | Burned trunk with two stubs, ember seams | None | None |
| `VL_AshShrine` | 28 x 14 x 16 | 480 | Stone: VL_Ash (380); Trim: VL_Ochre (100) | Squat stepped gate with an ochre band | clear 14 x 11; limit 30 x 16; `occluder` height 11 | P1, P2, O1 |
| `VL_CrustPlate` | 20 x 20 x 0.5 | 120 | Crust: VL_Basalt (90); Crack: VL_Neon_Magma (30) | Flat plate with raised glowing seams. Crust and Crack stay separate parts | `walk` top Z 0.5 | W1 |
| `VL_ObsidianShard` | 5 x 5 x 4 | 90 | Shard: VL_Obsidian (70); Base: VL_Ash (20) | Three black glassy fins | `gather` at (0, -2.5, 1.5) | R1 |

### 5.7 Cryptic Ruins kit

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `CR_Colonnade` | 24 x 5 x 14 | 420 | Stone: CR_Slab (360); Trim: CR_DeepViolet (60) | Three square columns, 10 studs apart along X, with a cracked beam on top | `occluder`: one box per column, height 11 | O1; gaps between columns stay at least 6 wide |
| `CR_BrokenWall` | 14 x 3 x 9 | 260 | Stone: CR_Slab (220); Moss: CR_DrySage (40) | Block wall with a stepped broken top | `occluder` 14 x 3, height 7 | O1; occluder at least 5 tall across its full width |
| `CR_Plinth` | 6 x 6 x 2 | 100 | Stone: CR_Slab (70); Glyph: CR_Neon_Glyph (30) | Square step with one inset glyph on the top face | `walk` top Z 2; `tiny` 2.2 | W1, N1; Neon part is exactly Glyph |
| `CR_Archway` | 28 x 8 x 18 | 560 | Stone: CR_Slab (460); Trim: CR_DeepViolet (100) | Flat lintel gate with a thick frame. Must differ from the curved `FK_RuinDoorway` | clear 14 x 11; limit 30 x 16; `occluder` height 11 | P1, P2, O1 |
| `CR_Reliquary` | 8 x 4 x 4 | 200 | Stone: CR_Slab (150); Trim: CR_DeepViolet (50) | Waist-high stone box with a shallow top recess. Holds eggs. Not a coffin shape | `gather` at (0, 0, 4) | R1 |
| `CR_GlyphStone` | 4 x 3 x 5 | 120 | Stone: CR_Slab (90); Glyph: CR_Neon_Glyph (30) | Short standing stone with a raised plate on -Y. Symbols appear on a runtime billboard, not in the mesh | None | Neon part is exactly Glyph |
| `CR_StairRun` | 16 x 12 x 6 | 180 | Stone: CR_Slab (180) | Six steps along Y, 2 long and 1 high each | `walk` top Z 6; one ramp box | W1; step count 6 |

### 5.8 Demon Abyss kit

No gore, skulls, bones or religious symbols in any asset.

| Asset | Size | Tris | Parts | Form | Clearance and tags | Extra tests |
| --- | --- | --- | --- | --- | --- | --- |
| `DA_FissureLip` | 20 x 10 x 6 | 240 | Rock: DA_Ash (190); Crack: DA_Neon_Rift (50) | Ground edge that breaks away on +Y, glowing seam on the lip | `walk` top Z 6 | W1 |
| `DA_FloatRock` | 12 x 12 x 6 | 180 | Rock: DA_Ash (150); Crust: DA_Crimson (30) | Flat top, pointed underside. Pivot under the tip, which is Z 0 | `walk` top Z 6 | W1 |
| `DA_ThornSpire` | 8 x 8 x 18 | 200 | Spire: DA_Void (200) | Curved rock thorn with three side spikes. Mineral, not body parts | None | None |
| `DA_RiftGate` | 28 x 8 x 18 | 560 | Stone: DA_Ash (440); Rift: DA_Neon_Rift (120) | Jagged leaning gate with a glowing inner edge outside the corridor | clear 14 x 11; limit 30 x 16; `occluder` height 11 | P1, P2, O1 |
| `DA_RiftShard` | 5 x 5 x 5 | 100 | Shard: DA_Neon_Rift (70); Base: DA_Void (30) | Single jagged crystal | `gather` at (0, -2.5, 1.5) | R1 |
| `DA_CalmStone` | 6 x 6 x 6 | 140 | Stone: DA_Pale (100); Rune: DA_Neon_Calm (40) | Smooth pale standing stone with a cool band. The only cool color in this biome | None | Neon part is exactly Rune |

### 5.9 Species specs

**Rig rules, from `docs/assets/silueta-rig.md:33-37`, `:43-47`, `:54`:** one armature, every vertex weighted and normalized, at most two influences, stationary Root, feet at Z 0. Clips run at 30 fps: `Idle` 3.0 s (frames 1 to 91), `Move` 2.0 s (frames 1 to 61), both with matching loop endpoints and no root motion. Materials are named `SP_<Species>_<Part>`, and the Neon part `SP_<Species>_Neon_<Part>`.

**Species tests, on top of G1 to G14:** bone names and count exact; every clip sampled on every frame with finite transforms; Root fixed; loop endpoint mesh error 0; FBX round trip keeps bones and clip duration, noting the one-frame reimport offset (`silueta-rig.md:57`). Render a lineup next to a 5-stud block. **Height stays at or under 5**, so a pet never hides its owner.

| Asset | Size | Tris | Parts, with hex | Bones | Form |
| --- | --- | --- | --- | --- | --- |
| `SP_Cortezon` | 3.6 x 4 x 2.4 | 600 | Shell 5B4630 (340); Legs 3A2E22 (140); Moss 7E9440 (80); Neon_Eye E8D25A (40) | 7: Root, Body, Head, LegFL, LegFR, LegBL, LegBR | Dome of seven overlapping bark plates. Eyes in a low slot at the front |
| `SP_Cestillo` | 2.6 x 2.8 x 4 | 650 | Basket B98E55 (300); Neck 7E8C47 (120); Beak 5E9A3C (70); Legs 6B4A2F (130); Neon_Eye F2F0C8 (30) | 6: Root, Basket, Neck, Head, LegL, LegR | Open-top woven basket body with faceted bands. Reed neck bends forward |
| `SP_Zancanieve` | 2.6 x 3.8 x 4.5 | 700 | Body C7D6DF (250); Legs 4A5560 (150); Tail 9CCBE0 (240); Neon_Eye 7FE0F0 (60) | 10: Root, Body, Neck, Head, ThighL, ShinL, ThighR, ShinR, TailA, TailB | Small body high on stilts. Fan of five ice plates. Long neck |
| `SP_Soplillo` | 2.8 x 3.4 x 2.6 | 450 | Body E6EFF4 (300); Tail 9CCBE0 (110); Neon_Eye 4E7CC2 (40) | 4: Root, Body, TailA, TailB | Six-sided puff with chamfered edges. Tail curves up behind |
| `SP_Aldabon` | 3.4 x 3 x 3.8 | 550 | Block 6E6A64 (270); Ring 2C2D30 (150); Legs 4D4A46 (90); Neon_Eye E2A23B (40) | 5: Root, Body, Ring, LegL, LegR | Standing stone block. Heavy ring swings from a front bracket |
| `SP_Vetilla` | 1.8 x 5 x 1.6 | 600 | Body 4E4A48 (340); Neon_Crystal 3FBFA8 (260) | 10: Root, Body, Head, TailA, TailB, TailC, LegFL, LegFR, LegBL, LegBR | Flat and long. Five crystal fins along the spine. No separate eyes |
| `SP_Tizoncillo` | 3 x 5 x 2.6 | 550 | Log 241F1D (340); Legs 3A3330 (130); Neon_Ember C8481A (80) | 6: Root, Body, LegFL, LegFR, LegBL, LegBR | Blunt charred log, cracks along the sides, two ember eyes in the same Neon part |
| `SP_Humarel` | 2.4 x 3 x 3.8 | 600 | Body 6F6863 (280); Feet 2E2B2C (130); Tail A8A29C (140); Neon_Eye E2803B (50) | 8: Root, Body, Head, ShinL, FootL, ShinR, FootR, Tail | Upright with oversized flat feet. Tail ends in an open faceted ring |
| `SP_Tinajuelo` | 2.6 x 2.6 x 3.4 | 500 | Jar A0694A (300); Lid 7C5038 (100); Arms 6B4632 (70); Neon_NightEye 8E5BD6 (30) | 5: Root, Jar, Lid, ArmL, ArmR | Round-shouldered jar, no face. NightEye part is hidden by default, shown for the night variant |
| `SP_Polvilla` | 4.4 x 1.6 x 4 | 450 | Wings B9AE98 (280); Body 5A5560 (110); Neon_Spots C9A24A (60) | 4: Root, Body, WingL, WingR | Two large folded flat wings with torn edges, on a peg. Hover height is built in, with feet point at Z 0 |
| `SP_Espejuelo` | 2.8 x 1 x 4.2 | 400 | Slab C9CFD6 (180); Frame 3B3440 (130); Legs 2A2630 (90) | 4: Root, Slab, LegL, LegR | Tilted diamond plate, dark frame, thin legs. Flat pale color, no reflection |

### 5.10 Guardian specs

Same rig rules as 5.9, with **height allowed above 5**. Visuals stay non-colliding, and a server body proxy owns gameplay, as with Silueta (`silueta-rig.md:69`). No root motion. Nothing here is imported.

| Asset | Size | Tris | Parts, with hex | Bones | Clips at 30 fps |
| --- | --- | --- | --- | --- | --- |
| `GD_ElVigia` | 13 x 13 x 15 | 1,400 | Legs 8F8A85 (480); Hub 6E6A64 (260); Head 77717F (260); Shutter 3B2F50 (120); Arms 8B7A5E (240); Neon_Slit C9A24A (40) | 17: Root, Hub, Neck, Head, Shutter, LegA1, LegA2, LegB1, LegB2, LegC1, LegC2, ArmL1, ArmL2, ArmL3, ArmR1, ArmR2, ArmR3 | `Hold` 3.0 s, `Stride` 2.0 s, `Flinch` 1.0 s, `Telegraph` 1.8 s, `Strike` 1.0 s |
| `GD_Yeti` | 11 x 9 x 11 | 1,500 | Hide 3D3A3E (760); Ice 9CCBE0 (340); Mask 3F4247 (180); Hands 2B2A2E (180); Neon_Eye 7FB8C9 (40) | 18, the Silueta set: Root, Pelvis, Spine, Chest, Neck, Head; UpperArm, Forearm, Hand, Thigh, Shin, Foot on each side | `Idle` 3.0 s, `Stalk` 2.0 s, `Sniff` 3.0 s, `Telegraph` 1.8 s, `Charge` 1.0 s, `Recover` 2.0 s |

**Form notes**

| Asset | Must read as | Must not read as |
| --- | --- | --- |
| `GD_ElVigia` | Three legs evenly spaced at 120 degrees. Head is a flat ring with a slit, seen clearly at 70 studs. Arms fold flat along the hub at rest | A person, statue, angel, antlered creature or anything siren-headed |
| `GD_Yeti` | Knuckle walker, head below the shoulder hump, ice plates on back and forearms, face a flat plate | A white furry ape, horned beast or Silueta-like thin figure |

**Extra guardian tests:** each loop clip has matching endpoints. `Telegraph` lasts at least 1.4 s, the existing minimum (`WildboundWorldRules.luau:7`). Its last pose equals `Strike` first pose, or `Charge` first pose for the Yeti. `GD_ElVigia` leg feet stay at Z 0 within 0.1 in `Hold`, since it must look frozen. Neon part count is exactly 1.

**Rig scripts were not read for this document.** The contract above comes from `docs/assets/silueta-rig.md`. W13 must read `tools/build-silueta-rig-v3.py` and `tools/test_silueta_motion_v3.py` first.

## 6. Build order, W12 to W15

Local only: editable source, FBX export, spec tests, a render a person can open (`odd/tasks/wildbound-waves.md:60`). **No uploads, Studio or Roblox import.** Everything is labelled unvalidated. Each row is one work unit with observed RED and GREEN. Run `python tools/test_<name>.py` per unit and the full `python -I -B -m unittest discover -s tools -p "test_*.py"` at wave close.

| Wave | Unit | Build | Why this order | Stop and ask if |
| --- | --- | --- | --- | --- |
| W12 | a | `tools/kit_common.py`, `tools/kit_spec_common.py`, and `SP_Soplillo` | Smallest full proof: 4 bones, 450 triangles, one Neon part, all rig tests | Round trip loses bones or clips |
| W12 | b | `SP_Cortezon`, `SP_Cestillo` | Living Forest pair; four and two legs | Budget missed by over 10% |
| W12 | c | `SP_Zancanieve` | Hardest early rig, and pairs with the Yeti's tracks | Stilt legs break at the joints |
| W12 | d | Remaining seven, one unit each: Polvilla, Espejuelo, Aldabon, Tinajuelo, Tizoncillo, Humarel, Vetilla | **Only after the user sees W12 renders.** M11 itself begins with two species (`docs/wildbound-roadmap.md:407`) | User has not approved |
| W13 | a | `GD_Yeti` | Reuses the known 18-bone naming, so least new risk | Silhouette reads like Silueta |
| W13 | b | `GD_ElVigia` | New tripod rig. Needs X4 first | X4 unanswered, or frozen `Hold` shows foot slide |
| W14 | a | `LF_TrailPost`, `LF_FlowerClump` | Two cheapest props to prove the kit script | Report fields do not fit |
| W14 | b | Rest of Living Forest, sheet, scale lineup, layout plan in the style of `tools/plan_forest_layout.py` | First neutral contrast (`docs/wildbound-roadmap.md:410`) | Plan exceeds its cap |
| W14 | c | Frozen Mountains kit, including no-track rects, and layout plan | Needed by the Yeti (`docs/wildbound-roadmap.md:411`) | Same |
| W15 | a | `RC_TunnelStraight`, `RC_TunnelBend`, snap test | Riskiest geometry in the document; prove modules join before anything else | Snap test fails |
| W15 | b | Rest of Rock and Caves | Roadmap order, `docs/wildbound-roadmap.md:412` | Same |
| W15 | c | Volcanic Lands kit | Simplest hazard art | Same |
| W15 | d | Cryptic Ruins kit, occluder boxes tested | Needed by El Vigia | Occluders do not cover avatar height |
| W15 | e | Demon Abyss kit | Last, and depends on X8 | X8 unanswered |

**Delivery:** expected to exceed about 400 authored lines per wave, so keep work-unit commits small. The parent commits; `.rbxl` never staged. W17 (import) stays blocked on upload consent and X2.

**What these waves prove:** geometry, budget and export only. Not scale in Roblox, phone cost, readability or fun.

## 7. Technical question: one place with sectors, or one place per biome

**Read 2026-11-07 through a summarizing fetch tool, so quotes are not independently checked against the page:** [streaming](https://create.roblox.com/docs/workspace/streaming) and [teleport](https://create.roblox.com/docs/projects/teleport).

| Documented fact | Source |
| --- | --- |
| Default target radius 1024, minimum radius 64. No maximum map size stated | Streaming |
| `StreamOutBehavior` default LowMemory; Opportunistic can remove regions beyond target radius without memory pressure and is recommended | Streaming |
| `TeleportAsync` runs only from server scripts and takes a player array | Teleport |
| Teleports discard local data. Use DataStores or MemoryStores; teleport data is visible to the client | Teleport |
| Teleports can throw, and can fail silently at the last moment, firing `TeleportInitFailed`. Retry with `pcall` | Teleport |
| Players see a loading screen. No load time or reliability figure is given | Teleport |
| Reserved servers are available through `TeleportOptions` | Teleport |

**Calculated:** at the default radius, a player near the middle of a packed world of these sectors is within 1024 studs of nearly everything, about 240,000 triangles (section 2). So one place needs a lower target radius or spread-out sectors.

**Unverified, all of it:** phone memory for any option, real teleport time, how Lighting changes feel between regions, whether radii are changeable per region (not expected), and teleport testing in Studio. The testing modes page does not mention teleports, and the likely testing guide URL returned 404.

| | A: one place, sectors | B: one place per biome | C: hybrid (recommended) |
| --- | --- | --- | --- |
| Layout | All seven in one place | Camp hub plus six places | Start place holds camp, Fog Forest and Living Forest. Other biomes are one place each |
| Identity | Best: walk from warm to fog, as the design reference asks (`AGENTS.md`, design references) | Weak: a loading screen between biomes | Keeps the key fog-to-neutral contrast seamless |
| Memory | Highest risk: about 240,000 triangles reachable | Lowest per place | About 111,000 triangles in the start place (calculated), and low elsewhere |
| Streaming and fair strike | Fog rules now depend on a far larger world. Radius cuts affect every guardian | Each place tunes its own. Candidate F (streaming off) stays possible (`docs/wildbound-roadmap.md:212`) | Same as B for hard biomes. Start place stays small |
| Lighting | Client-side regions, extending `WildboundWorld.client.luau:163-176` | Set per place | Both, in small scale |
| Code now | `Rules.zone` and home are single values (`WildboundWorldRules.luau:10-11`, `:48-53`). Needs a sector table | Same rules per place, shared modules | Needs both, for a small sector table |
| Persistence | Works session-only for testing | **Blocked by M6:** teleports discard local data | Living Forest can be tested before M6; the rest wait |
| Co-op | Natural | Must move groups with reserved servers. Silent failure must be handled | Same as B, later |
| Failure | One bad biome hurts all | Failed teleport must never lose an expedition | Same as B, later |
| Deployment | One place | Six more to sync by hand, with no Rojo (B10). Strongly favors D9 | Grows gradually |

**Recommendation: C.** Prove Living Forest beside Fog Forest first, measure on a real phone, then add one separate place only after M6, using Frozen Mountains. If the phone numbers are good, later biomes can still join the start place. This is a decision for the user, X2.

## 8. Decisions for the user

Each is one choice. On 2026-11-07 the user asked the parent to decide overnight and review later. The recommendations below were taken for that purpose, recorded in `odd/tasks/wildbound-waves.md`, and can be reversed. W12d proceeds on that basis instead of waiting for renders. Nothing here authorizes an upload.

| ID | Decision | Recommendation | Blocks |
| --- | --- | --- | --- |
| X1 | Approve this as design direction, in whole or part? | Approve Living Forest, Frozen Mountains, Yeti and the first species batch. Hold the rest as drafts | W12 to W15 |
| X2 | One place with sectors, one per biome, or hybrid? | Hybrid, re-decided after phone measurement | W17 |
| X3 | Which species come first? | Soplillo, Cortezon, Cestillo, Zancanieve. See the rest after renders | W12d |
| X4 | Keep El Vigia's "moves only unseen" rule, given it is a known horror idea? | Keep, with the plinth and surveyor changes, plus an IP check at M10.2 | W13b |
| X5 | Keep Spanish names, and these exact names? No trademark search was done | Keep for now, search before any release. Ties to D13 | Final naming |
| X6 | Limit hostile night to Fog Forest, Ruins and Abyss? | Yes. Calm biomes stay a relief | Biome rules |
| X7 | Build any optional guardian? | Not yet. Prefer La Tapiadora first, since it is the least like the others | Optional only |
| X8 | Keep the name "Demon Abyss" for players? | Keep internally. Decide with the maturity questionnaire before M10.2 (`docs/wildbound-roadmap.md:394`) | W15e |
| X9 | Accept these caps until M9.2 replaces them? | Yes, as ceilings, never as promises | W14, W15 |
| X10 | Accept extra buttons on phones (Look lock, Soft step), given HUD crowding in B14? | Yes, shown only in the biome that needs them | Vigia, Yeti |

**Open decisions this depends on, unchanged:** D2 and D6 (fair strike and lethality), D3 (capture), D5 (cycle length and night reward), D9 (Rojo), D14 (reserves).

## 9. Risks and limits of this document

| Risk | Response |
| --- | --- |
| Content built before the loop is proven fun may need rework | Accepted by the user. Keep W12d and W15 behind checkpoints |
| El Vigia rests on an untrusted hint, and visible creep may read as cheating | Measure early with Network Simulator; drop speed or redesign |
| 240,000 triangles of plans, while 74,996 has never been measured on a phone | Measure Fog Forest in M1.5 before trusting any cap |
| Eleven capture methods with no capture system proven | Build M3 with Lumipol first. Expect to cut methods |
| More HUD on phones already at risk (B14) | Contextual buttons only |

**Not read or not available:**

- Studio, Blender and Play were not used.
- `tools/plan_forest_layout.py` and the Silueta rig scripts were not read.
- Pack skills and other pack documents, beyond the four notes cited in section 1 and `ART_DIRECTION.md`, were not read.
- The Workspace and BasePart reference pages returned no property descriptions through the fetch tool.
- The teleport testing guide returned 404.
- Concepts `lumipol-roblox-field-v1.png` and `silueta-search-reveal-v1.png` were not opened.
