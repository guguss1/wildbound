# Wildbound: master game overview

**Snapshot:** 2026-11-15, branch `codex/wildbound-first-playable` at `df0d0bb` (previous snapshot 2026-11-10 at `6edfa21`). Written offline from the repository only: no Studio, Play or device session was run for this document. Where code and an older document disagree, this document follows the code and says so (section 16). Anything not checked against code or a recorded Play result is marked **(unverified)**.

**Status words used everywhere below**

| Word | Meaning |
| --- | --- |
| **Done** | Code exists, is wired into the running game, its Studio suites passed and a solo Studio Play check recorded it (`odd/tasks/*.md`). Never means "tested with two players" or "tested on a phone" unless stated |
| **Prepared** | Code or geometry exists in the repository (pure module, builder, suite) but is **not wired** into the running game, and its Luau suites have **not run** |
| **Design only** | Written in a design document; no code |
| **Not started** | Neither design detail nor code |

Every **Done** below is **solo Play only** unless a row says otherwise: no two-player session, no phone or Device Simulator and no real DataStore has been recorded for any feature. A row that says "wired, suites passed, no Play recorded" is code that runs in the game but has no solo Play record of its own, so it is not Done yet.

## Changes since the last snapshot (2026-11-10 to 2026-11-15)

Sources: `git log 6edfa21..df0d0bb` (the work since 2026-11-14 starts after `5e93621`) and the feature docs `odd/tasks/wildbound-2-0.md`, `wildbound-suite-repair.md`, `wildbound-playtest-fixes.md`, `wildbound-scuttler.md`, `wildbound-kids-beasts.md`, `wildbound-caramelo.md`.

- **Studio sync (`34eab83`, `d71b87f`, `ad569e9`):** the teammate's live Studio scripts were pulled into the repo. They brought work no feature doc of ours records: the five "prepared" mechanics are now **wired** (Esquiva perfecta replaces the Burst, bat knockback 5 s / 1.2 s ragdoll / 3 s immunity, Arrullo, luck-totem persistence, Dusk), four wave-2 beasts (Streamer, Root, Gaze, Lurker), Gomibu, faster steals (0.5 s / 0.75 s), several eggs per bag, bag 12, new Esencia tables and a 15 s incubator scaled by rarity.
- **Stale-suite repair:** live retunes pinned; owner decisions restored the parent chase 19, wind-up 0.4, bough eggs and the collection limit 100, showed the tutorial card again and kept the wave board, event banner and safe banner hidden.
- **Beasts:** shared beast visibility (SC0) and the **Scuttler** (SC1 to SC8); **La Nube Gruñona** and **La Abeja Reina**; global beasts have **no biome preference**.
- **Playtest fixes:** one backpack, only while carrying an egg; a large treadmill walk (16 to 50); creature hotbar, own-pad farm, farm wander and a Lumipol icon; the farm saved (**schema 5**); a **hub roulette** with saved pity (**schema 6**).
- **Caramelo:** the biome's beasts (Gomibu, Flanfuria, Tortidragon) and the boss **Don Glaseon**; 11 stealable candy nests; farm-only Caramelo pets with icons; candy egg looks; two return portals.
- **World clock:** the global day/night cycle is gone (CA4): 300 s egg waves with a 10 s Warning and fixed light per biome; since CF1 each place keeps its own rules (the forest plays by night rules).
- **Still owed by the owner:** publish 22 clips to group 465694015, share or re-upload 4 icons, save the place, set `MaxPlayers` (14.1).

## Quick path

| You are | Read |
| --- | --- |
| The user | 1, 2, 13 (status matrix), 14 (what you must do) |
| A Studio writer | 4, 12, 13, then the detailed doc each row links |
| A designer or economist | 4 to 7, 11 |
| A reviewer | 13, 14, 16 (doc/code contradictions) |

---

## 1. What the game is

| Item | Description |
| --- | --- |
| Name | **Wildbound** (Roblox, one experience, Spanish player strings, English code and docs) |
| Pitch | **Nest Heist with horror.** Sneak out of a bright, safe hub into a dark, misty forest, steal a creature egg from a guarded nest, carry it home in your arms while its parents charge, La Silueta stalks you and other players try to knock it loose with a bat, then hatch it into a glowing companion that lights your way |
| Core fantasy | Daring theft, a tense run home, a cute reward. Risk lives in the trip; what is banked at home is never lost |
| Audience | Roblox players roughly 8 to 14 who like light horror (dark forest, a tall silent stalker, no gore), plus a planned bright kids' biome (Pradera Arcoíris) with "half the tension" (`docs/design/wildbound-biome-pradera.md`) |
| Tone | Contrast: the forest is foggy, dark, quiet and frightening (stalk sightings, heartbeat, red edge), the hub is warm, lit and social. **99 Nights in the Forest is an aesthetic reference only** (low-poly trees, palette, campfire warmth), not its night ladder (`docs/design/wildbound-biome-2-proposal.md:34`); the night ladder was removed by the user ("no mechanic is gated by nights survived", `odd/tasks/wildbound-capture-extraction-horror.md:677`) |
| Session shape | Short expeditions (simulated median 183 to 208 s, floor 180 s) from a persistent base; no day/night cycle since CA4 (2026-11-15): fixed light per biome; 5-minute egg waves; a 20-minute biome event |
| Players | Server target 8 (user decision Q5, `docs/design/wildbound-combined-plan.md:69`); 8 personal bases; the place's `MaxPlayers` is still 60 (HB-W8, open) |
| Test place | `Experiencia sin título`, PlaceId `122652861404212`, GameId `10774749224` (`odd/tasks/wildbound-first-playable.md:105`). Unpublished |

---

## 2. Player journey

### 2.1 First minute (as built)

| Second | What happens | Evidence |
| --- | --- | --- |
| 0 | Start screen (`WildboundStartView`, tutorial `WildboundTutorial`); the player spawns on a hub spawn pad of their base slot, facing east, inside the safe disc | HF-T3 Play: root (298, 3.9, -3), look (1, 0, 0) |
| 0 | A free base is assigned and signed "Base de <nombre>"; HUD shows "Mochila", stamina, threat chip, wave board | HB-T2 |
| ~7 to 12 | Walk out through the NW/W gate; the forest floor starts at x 182 | HF-T3 Play: NW gate 7.4 s, forest floor 12.2 s |
| ~25 to 40 | First catch: island 1 "Claro de los Lumipol" (sleeping Lumipol nest, gentle ring) or the wave-1 common egg placed within 70 studs of the **camp** | `docs/mechanics/wildbound-expedition-islands.md` section 2; RW3 |
| — | **Risk:** the first-minute hook (island 1 at (-95, 75), wave-1 egg near camp (-140, 140)) was designed around the old camp spawn; from the new hub spawn (282, -3) both are roughly 380 to 430 studs away (about 25 s of walking). Not measured in Play | Arithmetic from `WildboundWorldRules.luau` and the islands doc **(unverified in Play)** |

### 2.2 One full loop

1. Leave the hub (safe: no PvP, beasts, strikes or chases inside radius 90).
2. Find a nest: a fixed island nest (5 islands, rising risk) or a random spawn (rarity-tagged glow, "Común/Rara/Épica/Legendaria").
3. Steal: hold the prompt 0.8 s (normal egg) or 1 s (Épica, Legendaria, event egg). A cría (baby creature) is taken with the calm-ring capture minigame instead.
4. The parents wake at once (no meter) and chase at 19 studs/s; within 12 studs they rear up for a 0.8 s tell, then charge.
5. Carry the egg in your arms (walk 11 while carrying). Escape with sprint (x1.45, 4 s of stamina), the perfect dodge ("Esquiva perfecta"), hiding spots, Refugios, or a return portal after 5 s of calm.
6. Survive La Silueta (in the fog territory), Viper and Pouncer (anywhere outside safe zones), and other players' bats.
7. Deliver at your own base's pedestal ("Entregar huevo", E) or incubator ("Incubar huevo", R), or at the old camp chest/incubator. Pays Esencia by tier plus a trip base.
8. Incubate (15 s x rarity: 15 / 45 / 60 / 75 s, one slot, server Unix time, continues offline). The hatchling joins your collection and goes to your creature hotbar; equip it as a companion (a Lumipol gives light) or place it in your base farm (Caramelo species are farm-only).
9. Spend Esencia: gloves, treadmill, seals, upgrades, skills, luck totem, the hub roulette. Saved progress keeps everything banked.

### 2.3 Session goals

| Goal | Source |
| --- | --- |
| Steal before the egg refresh | Each 300 s wave refreshes the unclaimed eggs; the last 10 s refuse new steals (CA4) |
| Top the wave board (Esencia gained this wave, top 3, resets each 300 s) | RW3, RW7 |
| Claim the 20-minute biome event egg (Tizoncillo, Legendaria, one claimant per server) | RW5 |
| Contest other players' eggs with the bat | NP3 to NP5 |

### 2.4 Long-term progression

| Track | State |
| --- | --- |
| Collection: five species, four rarities, up to 100 registered creatures | Done (session cap `collectionLimit` 100, saved) |
| Companion bond levels (XP thresholds 0, 40, 100, 180, 280) | Done in state (saved `bond`) |
| Gloves with random stats (best rolls Legendaria) | Done |
| Skill tree: 4 branches x 2 tiers (8 nodes, 5 with live effects) | Done |
| Walk-speed training | Done (PF2, BP1, BP2): 17 levels of +2 studs/s, walk 16 to 50; a carrier keeps its carry share of at most a 24 walk and never walks past 16.5 (one egg 16.5; a carried creature too) |
| Hub roulette (45 Esencia, one free spin, Rara+ pity every 10, saved) | Done (PF5, schema 6) |
| Creature hotbar and base farm (4 slots, a fifth and sixth for 400 and 900 Esencia since BP4c; saved, creatures wander) | Done (PF3, PF4 schema 5, PF6, BP4c); no farm income |
| Recycling, shops, showcases, hatch ladder, second cradle, base chest stations | Prepared (geometry) / Design only (rules) |
| Corral that pays Esencia over time, trophies, breeder level, daily gift | Design only (`docs/mechanics/wildbound-hub-systems.md`) |
| New biomes with their own beasts | Caramelo (in the Meadow square, replacing the Pradera): playable, see 3.4; six others: primitive builders only |

---

## 3. World map

One open world. Coordinates are place studs (x east, z south). Source of truth: `src/wildbound/WildboundWorldRules.luau` and `assets/maps/open-world/biome-placement-v1.json` (regenerated for the hub at (282, -3), radius 90).

### 3.1 Overview

| Area | Centre (x, z) | Size | Yaw | Root model | Status |
| --- | --- | --- | ---: | --- | --- |
| **Hub (Plaza central)** | (282, -3) | safe disc r 90 | 0 | `WildboundHub` | **Done** (v1 features); v2-r90 geometry built (see 3.2) |
| **Bosque de la Silueta** (forest) | (-18, -3) measured | 400 x 400 | 0 | `WildboundP0` | **Done, the only playable biome** |
| **Caramelo** (candy biome, Meadow square x 412 to 812) | (620, -7) | 430 x 463 | 0 | `Candy_Bioma_v1` (attribute `Replaces = PraderaArcoiris`) | **Playable (solo Play):** 4 beasts + boss, 11 nests, a return portal; see 3.4 |
| Pradera Arcoíris | (612, -3) | 400 | 0 | `WildboundPradera` | Builder + full design; its square is now Caramelo's; Nube and Abeja still summon at its sector offsets (5.5) |
| Pantano (living forest) | (282, -443) | 400 | 90 | `WildboundLivingForest` | Prepared: primitive-part builder only |
| Cementerio (cryptic ruins) | (282, 387) | 300 | 180 | `WildboundCrypticRuins` | Prepared: primitive-part builder only |
| Abismo (demon abyss) | (-108, -393) | 300 | 90 | `WildboundDemonAbyss` | Prepared: primitive-part builder only |
| Montañas Heladas (frozen mountains) | (772, -493) | 500 | 0 | `WildboundFrozenMountains` | Prepared: primitive-part builder only |
| Tierras Volcánicas (volcanic lands) | (-108, 437) | 400 | 180 | `WildboundVolcanicLands` | Prepared: primitive-part builder only |
| Cuevas de Roca (rock caves) | (622, 387) | 300 | 270 | `WildboundRockCaves` | Prepared: primitive-part builder only |
| Open-world roads | from the hub's E, N, S gate trail ends | 14 studs wide, 7 roads, 19 slabs, 8 gate markers | — | `WildboundOpenWorldRoads` | Prepared (`tools/build-wildbound-open-world-roads.luau`, EV-W2) |

Roads: E gate to Pradera (30 studs); N trunk for Pantano, Abismo and Montañas Heladas; S trunk for Cementerio, Tierras Volcánicas and Cuevas de Roca. The forest has no road: the hub's W gate trail reaches its east edge at (182, 17). Details: `docs/maps/wildbound-open-world-biomes.md`.

### 3.2 The hub

| Feature | Value | Status |
| --- | --- | --- |
| Position | `Rules.HUB_X, HUB_Z, HUB_RADIUS = 282, -3, 90`; the disc spans x 192 to 372, 10 studs east of the forest floor (x 182) | Done (HF-T3) |
| Safe zone | `Rules.zone` safe within 90: no bat, no beast rolls or reservations, no La Silueta strikes, chases end, a carried egg drops only on death or leave | Done (HB-T6) |
| Bases | 8 personal bases (`Bases.SLOTS`), assigned on join (lowest free slot), released on leave; a ninth player has none and uses the camp | Done (HB-T2) |
| Per base | Delivery pedestal ("Entregar huevo", E), incubator ("Incubar huevo", R), collection display (3 hovering creatures, companion first), glove bench ("Ver guantes", B), treadmill ("Entrenar", N). Server refuses other owners ("Esta no es tu base.") and range (8 + 2 studs) | Done (HB-T3 to HB-T5) |
| Spawn | 4 hub spawn pads; pad = slot modulo 4; camp is the fallback | Done (HB6, HF-W4) |
| Builder | `tools/build-wildbound-hub-map-v2-r90.luau` deployed as `ServerStorage.WildboundHubBuilder`; the hub script reuses a hub saved in the place while its `DataAdler32` matches (`Bases.hubCurrent`), else rebuilds once at server start | Done in code (EV-W1, `b45bdba`) |
| v2-r90 geometry | v1 disc (r 90) with v2 bases, a showcase ("Vitrina") plinth per base, 4 shop circles, 8 chest stations, bank zones, 2 cradles per incubator, 35 warm shadowless lights, about 470 parts | Built per commit `b45bdba` **(unverified here; not re-read in Studio)**. **No code uses** the shops, chests, bank zones, showcases or second cradle |
| Lighting/ambience row for the hub, night lamp scale | Planned in `docs/design/wildbound-hub-expansion.md` section 3 | Design only |
| Shared camp stations moved into the hub (HB2) | Registration, chest, skill tree board, trophies still at the old camp | Not started (open question) |

**The old camp** (centre (-140, 140), safe radius 35, inside the forest's west side) still works: camp chest (extract, E), hatch/incubator (R), protect (T), creature refuge/registration (V), upgrade board (B), treadmill (N), skill tree. Players no longer spawn there.

### 3.3 The forest (Bosque de la Silueta)

| Item | Value |
| --- | --- |
| Floor | `WildboundP0.Floor` centred (-18, -3), 400 x 400 (x -218 to 182) |
| Art | The **only real kit**: six forest-kit Model packages uploaded and kept as templates in `ServerStorage.WildboundAssets.ForestKit`, dressed by `tools/dress-wildbound-forest.luau` |
| Fog rectangle | x -45 to 165, z -165 to 35 (`Rules.zone`) |
| La Silueta's territory | home (0, -85), leash 80; chase leash 100 |
| Shelter | (105, 125) r 22 (safe) |
| Islands | 1 Claro de los Lumipol (-95, 75) Safe, Lumipol, 2 adults; 2 Hondonada del Musgo (-20, 15) Fog, Cortezón, 2; 3 Pantano de los Juncos (115, 15) Fog, Cestillo, 3; 4 Ruinas del Nido (35, -99) Territory, Polvilla, 3; 5 Corazón de la Niebla (60, -135) Territory/Heart, Tizoncillo, 4 |
| Spawn graph | 291 points (Común 168, Rara 53, Épica 42, Legendaria 28), 7 Refugio candidates (`WildboundSpawnGraph.luau`, RW1) |
| Relief, hiding spots, gather nodes | Built (`WildboundRelief`, `WildboundHide`, 24 gather slots in `WildboundEconomyConfig.gather.slots`) |
| Beast | La Silueta (per player), plus the rolled global beasts (Viper, Pouncer, Streamer, Gaze, Lurker, Scuttler; 5.4); since CF1 the forest plays by night rules |
| Biome variants | Niebla, Escarcha, Ceniza, Floración rotate every wave (colour, fog scale, spawn weights, ambient bed; no gameplay numbers) |

### 3.4 The other biomes

| Biome | Look (kit/design) | Beast | Species | Status |
| --- | --- | --- | --- | --- |
| **Caramelo** | Candy kit (asset 139302047387424), pink floor, Gran Torta at (612, -3) (since CT1/CT2, 2026-11-16, a tower: a 42-step spiral stair to the summit and three lower tiers that turn slowly, alternating, carrying players; added by the Candy builder at server start; since CT3 the summit holds nest T1, a Legendaria that is not event-only and refills on the 300 s wave; since CT4 Frutillón guards it: a giant strawberry that rolls round the summit after a 0.8 s squash and floor line, bumping players off, and throws seeds down the stair; knockback only), boss territory r 62, portal arch at (772, -3); always day (CA4) | **Gomibu** (push, keeps the egg), **Flanfuria** (Onda de Caramelo: ring r2 to r11, slow x0.65 1.5 s, puddle x0.8), **Tortidragon** (Abanico de Confites: 55° fan, 3 candies, slow x0.85), boss **Don Glaseon** (Látigo de Regaliz: since DG1, 2026-11-16, a combo of three 22 x 5 lanes, left, right, centre, tell 0.8 s; a carrier drops the egg; since DG2 also Boca aspiradora, a 2 s pull toward him at 7 studs/s on a target kept out of reach, stopped by cover; since DG3 a ring of chocolate wall around a runner's route with a sideways exit (crack line 1 s, up 3 s); since DG5 an anger meter (10 s carrying an egg in his territory, plus dodges) that tints him red and, full, halves his cooldowns for 10 s; since DG4 three glaze puddles on his plaza where players skate (no slowdown, little grip) and a fast sharp turn (over 17 studs/s, 75 degrees) slips them into a 1 s ragdoll; since DG7 three decoy cakes on the routes, each with a slice (a 5 s sugar rush, x1.25 walk), one of them him in disguise while he sleeps (it breathes and drops crumbs; it springs within 5 studs or on a bite, a 0.8 s tell then a 12-stud push, and the decoys pop for 90 s); bat immune; one per server). All damage 0, never in safe zones. Since CF (2026-11-15) the three guardians cast faster: tell 0.8 s (the floor), cooldown Gomibu 3.5 s, Flanfuria 5 s, Tortidragon 4.5 s, shorter recoveries (solo Play measured all three); Don Glaseon's combo tell is 0.8 s (DG1) | Gomibu (Común), Tortidragon (Rara), Flanfuria (Épica; Legendaria nest L1 is event-only and off). Farm-only pets, never a companion | **Done (solo Play)** for Flanfuria, Tortidragon, Don Glaseon, nests, pets, portal, egg looks; Gomibu wired, suites passed, no Play recorded here. Tortidragon and Don Glaseon play **no animation** until the owner publishes their 22 clips (14.1) |
| Pradera Arcoíris | Pastel meadow, giant mushroom roofs, sun circles, pond, La Colmena glade; `PA_` primitive parts | **La Nube Gruñona** (permanent: sky-ray sight 40, chase 14, fixed 6-stud lightning ring, 1.0 s telegraph, kids rule: no damage, no stack loss); **La Abeja Reina** (20-minute event only: wakes for the Huevo Real, guards it 5 minutes, sleeps) | Chispín (Común), Musgón (Común), Esponjín (Rara), Hongolín (Épica), Relampino (Legendaria, event only) | Builder `tools/build-wildbound-pradera-map.luau` + complete design. **Nube and Abeja: Done (solo Play, KB-8)**, damage 0; the Pradera species and the Huevo Real: no gameplay code |
| Pantano (living forest) | Swamp, stream (WalkSpeed 10 as data only) | Mire (2 points, 1/80, damage 40) | None defined | Builder only; Mire is config only |
| Cementerio (cryptic ruins) | Ruins, glyphs, stairs | Gargoyle (2 points, 1/100, damage 25) | None defined | Builder only; Gargoyle is config only |
| Abismo | Chasms, 10-stud drop floor with no way back | None | None | Builder only |
| Montañas Heladas | Overhangs, `YetiHomeMarker` | None defined | None | Builder only |
| Tierras Volcánicas | Vents (data only) | None | None | Builder only |
| Cuevas de Roca | 26 tunnel modules, rockfall lanes (data only), El Vigía chain markers | None defined | None | Builder only |

The six non-forest kits were **never uploaded**; their builders draw primitive fallbacks and pick up templates from `ServerStorage.WildboundAssets.<Kit>` if one ever exists. Since CA4/CF1 the biome squares are read by game code: `WildboundBiomeLight` (a replicated copy of the `WildboundBiomes` squares) picks each client's light and each place's gameplay phase (4.14); safe zones are still decided by `Rules.zone`.

Caramelo session-only switches: the nests (`Layout.NESTS_ENABLED`, `Builder.syncNests`) and the portal (`Layout.PORTAL.enabled`, `Builder.syncPortal`) were switched on as attributes on the live `Candy_Bioma_v1`, and the clips folder `ServerStorage.WildboundPublishClips` was built, all **without a place save**; if the place is reopened unsaved, one builder call restores each (`odd/tasks/wildbound-caramelo.md` decisions 22, 28, 38).

---

## 4. Core mechanics

Numbers are code defaults (most are live-tunable through the Studio dev tuning panel, `WildboundTuningSchema.luau`, `docs/testing/wildbound-tuning.md`).

| # | Mechanic | Rule and key numbers | Code | Status |
| --- | --- | --- | --- | --- |
| 4.1 | **Steal** | By rarity since EC (user, 2026-11-15): **Común 0.5 s, Rara 0.9 s, Épica 1.3 s, Legendaria 1.8 s** (`STEAL_HOLD`, `RARA_HOLD`, `EPICA_HOLD`, `LEGENDARIA_HOLD`); the biome event's egg holds 1.8 s; glove floor 0.35 s. The Arrullo (4.13) is off since AR, so every egg takes a plain hold. The tuning schema now carries the same four values (before EC it applied 0.8 / 1 over the module's 0.5 / 0.75 in Play). Solo Play saw the four lengths on the live prompts. Since CF2 a hold that would end inside the wave's 10 s Warning is refused when it starts ("Los huevos se renuevan..."). Unchanged: the **server measures the hold** (`EggCarry.holdComplete`): continuous, begun at most 3 s ago, at least the effective hold minus `HOLD_ALLOWANCE` 0.35 s (0.05 to 0.5). Refusal: "Mantén presionado un poco más." Glove "Robo rápido" shortens it (the 0.6 s floor of NH1 is 0.35 s live) | `WildboundEggCarry.luau`, `WildboundServer.server.luau` | Done (NH1, HB-T7, HF-T2) |
| 4.2 | **Carry** | One `EggCarry` record per egg, states `InNest`, `Carried`, `Dropped`, `Secured`, `Despawning`. Live: **several eggs per player up to the bag capacity** (`maxCarry`, `EggCarry.MAX_CARRY` 12, bag 12); carry walk 16/11/10/9 by load. **One backpack** (`WildboundEggCarried` on UpperTorso, PF1), only while an egg is carried; a carried creature shows no bag. A trained walk keeps its carry share (PF2). A Caramelo egg rides in the pack with its candy look (CG1) | `WildboundEggCarry.luau`, `WildboundServer.server.luau` (`Heist.syncEggArms`) | Done (NH2, PF1 solo Play: two eggs, one pack) |
| 4.3 | **Parents** | A steal wakes the island at once. Chase 19 studs/s, 14 s, leash 35. Charge: after 1 s of chase, within 12 studs, a **0.8 s** tell ("¡Va a embestir! Sal de su línea."), dash 40 studs/s to 4 studs past (max 18), hit within 3 studs; a miss leaves it exposed 1 s ("¡Falló! Aprovecha y huye."); 6 s between charges. Close swing wind-up raised 0.45 to **0.8 s** (Q1). A parent re-targets a new carrier only within 24 studs. A taken nest refills only after the chase ends | `WildboundIsland.luau` | Done (NH3, NH8, HF-T4) |
| 4.4 | **Dodge** | The old **Burst "Impulso"** (0.8 s at walk x1.7, cap 28, cooldown 6 s) is retired. Live: **"Esquiva perfecta"** (Z): press in the last 0.35 s of a parent, Viper, Pouncer or Silueta telegraph (never shorter than 0.8 s) to cancel that hit and get a 1 s x1.35 boost (cap 26); early/late/empty press 1.2 s cooldown; 4 presses in 1 s lock 2 s | `WildboundStamina.luau`; `WildboundDodge.luau`, `WildboundDodgeService.luau` | **Esquiva perfecta is wired** (teammate, synced `ad569e9`): the client sends "dodge" on Z, the Burst's word is retired. Dodge 14/0; a live press moved `WildboundDash` in solo Play (SC1); Scuttler and Don Glaseon are registered sources. Done (solo Play) |
| 4.5 | **Bat (PvP)** | Everyone has a bat (left click, DPadRight, "Bate" touch). Server picks the target: 6 studs flat, 60 degrees either side, 4 studs height, clear chest-to-chest ray. Live since the sync (Q4, Q4b): cooldown **5 s** (spent on a miss), **1.2 s ragdoll**, push 45 + lift 20 (max flight 24 studs), a carrier **drops the egg** (anyone may take it), immunity **3 s**; no damage. The old bat (12 s, 0.45 s stumble, 6 s immunity) is gone | `WildboundBat.luau`, `WildboundBatKnock.luau` (`Heist.Knock`) | **Knockback is wired** (synced `ad569e9`): `Knock.knock` runs the decided cooldown 5 s, ragdoll 1.2 s, immunity 3 s. Bat immunity (Don Glaseon) enforced in both resolvers (CF3). Wired, suites passed; a landed hit needs two players, never recorded |
| 4.6 | **Drop and pickup** | `Heist.dropEgg` reasons Death, Hit, Strike, Leave, Bat. Lands 2 studs behind on the ground; pickable after 0.4 s with a 0.4 s hold within 10 studs; first valid request wins; abandoned 30 s then fades ("Tu huevo se perdió en el bosque."). Parents fetch a loose egg home inside their leash. In a safe zone only death or leaving drops it | `WildboundEggCarry.luau` | Done (NH5); two-player race unit-tested only |
| 4.7 | **Death** | The carried egg falls where you died (for anyone) before the defeat. Banked eggs, registered creatures, Esencia, upgrades, skills, gloves are never lost. The older expedition rule still applies to the rest of the trip: unwarded bag items are lost and pouch materials lose 20 % (`loss.rateBasisPoints` 2000, 10 % with the reinforced pack) | `WildboundState.luau`, `WildboundEconomyConfig.luau` | Done (NH7) |
| 4.8 | **Banking / delivery** | Own base pedestal or own base incubator (server range 8 + 2), or the camp chest/incubator. Banks the whole bag with the egg, secures the egg once, pays `eggEmberByTier` (Fog 8, FogFar 10, Territory 11, Heart 14) plus the trip base (4 Esencia when the trip lasted 25 s (BP3; was 45 s), reached 60 studs from camp and found something). Notice: "¡Huevo a salvo en tu base! ... +8 de Esencia." | `WildboundHubStations.luau`, `WildboundServer.server.luau` | Done (NH6, HB-T3) |
| 4.9 | **Auto-banking zone** | Walk into your own base: egg into a free cradle, bag banked, big banner "¡Estás a salvo!" (2.5 s), hysteresis 2 studs, 4 Hz server step | `docs/design/wildbound-hub-expansion.md` section 7; `WildboundBaseZone.luau`, `Heist.stepBaseZones` / `Heist.enterBase` in `WildboundServer` | **Wired by the teammate** (synced): the server steps the zones and banks, secures and auto-fills on entry (suite-repair ECO-20, BZ7, EL12 notes); the banner stays hidden (owner decision). No feature doc of ours records its Play check |
| 4.10 | **Incubation** | One slot, 90 s (`Incubator.HATCH_SECONDS`, tunable 10 to 900), 12-stud range, server Unix time (hatches after rejoin). A hatch with no companion out equips the newborn ("...y ahora te acompaña."). Planned: hatch ladder 10 / 20 s for the first two eggs, then Común 40, Rara 75, Épica 150, Legendaria 300; second cradle | `WildboundIncubator.luau` | Live (synced): `HATCH_SECONDS` **15** x rarity (Común 1, Rara 3, Épica 4, Legendaria 5: 15 / 45 / 60 / 75 s), one slot. Since PF3 a newborn goes to the creature hotbar instead of following (NS3 re-pinned). Single slot: Done. 2.0 ladder, 2 slots: Design only |
| 4.11 | **Companions** | One companion out; follows without collisions; PointLight 1.2 brightness, 12 range (tunable); "Guardar"/"Equipar" in the Mochila. Lumipol pulse (Q) reveals La Silueta (see 4.15) | `WildboundRefuge.luau`, `WildboundWorld.client.luau` | Done (NS4) |
| 4.12 | **Cría capture** | A cría (or a wild Lumipol) uses the calm ring: stay inside a 4.5-stud ring (server 5) that orbits, fill calm 4.5 s (floor 4 s), then a seal tap in a moving band (X / R2). Capture is noisy (ring 32, seal 48 hearing radius) | `WildboundCaptureSession.luau` | Done |
| 4.13 | **Arrullo** (rare-egg minigame, Q2b) | Hold to raise / release to drop a marker inside a drifting calm zone on a vertical bar; progress starts 35, win at 100, lose at 0 or after 18 s. Zone Rara 0.30, Épica 0.24, Legendaria 0.18 of the bar. Server simulates; client sends only "hold"/"release" (20/s max). Replaces the ring for rare eggs | `WildboundArrullo.luau`, `WildboundArrulloService.luau`, `WildboundArrullo.client.luau` | **Off** (AR, user 2026-11-15): `WildboundArrulloService.ENABLED = false`, so `qualifies` is false and Épica, Legendaria and the event egg take the plain steal hold (4.1). Kept, not deleted: the rule, the service, the remote, the client and the server path, for its return. No full Arrullo was ever recorded in Play |
| 4.14 | **No day/night cycle; fixed light per biome** | Since CA4 (user, 2026-11-15, Caramelo pack item 08; it reverses the 2026-11-14 decision to keep 300/60/300/60): the world has no cycle. Each client applies the preset of the biome it stands in, blending in about 1 s: Caramelo always day (pastel grading +0.08 saturation, +0.04 contrast, +0.03 brightness, long view), Bosque always night, Pantano and Cementerio a dusk, others their own; the wave variant never tints Caramelo. **Since CF1 each place plays by its own rules** (`BiomeLight.phaseAt(x, z)`, keyed by the position of the player or entity concerned): Bosque (incl. the I3 swamp island), Abismo and Cuevas = **Night** (La Silueta's night profile 8/38 and brain row, beast odds x2, islands' night wake, night ambush timer); Caramelo, hub, Montañas and the dusk-look biomes (Pantano, Cementerio, Volcán) = Day. No place resolves to Dusk or Dawn, so the Dusk warnings and buff are inert. Rules clock Night 0 / Day 14 (never the islands' 11:00 to 13:00 deep sleep). The forest keeps its night gather table; a Nightbloom node wilts 300 s after it appears (its income rises, not rebalanced). Presentation (stalk sightings, Night Nose, night audio) follows the local biome mood | `WildboundWorldRules.luau`, `WildboundBiomeLight.luau` (`phaseAt`, `RULES`), `WildboundWorld.client.luau` | Done (solo Play, CA4 and CF1; two clients in different biomes and a 15-minute Caramelo stay not tested) |
| 4.15 | **Fog, flashlight, pulse** | Fog rectangle; client atmosphere per phase and biome variant; free flashlight (F, 12 s cooldown) needs facing; registered companion pulse (Q, 30 s) does not; reveal 4 s, range 55, LOS; reveals are shared and non-additive | `WildboundAtmosphere.luau`, `WildboundWorldRules.tryAbility` | Done |
| 4.16 | **Stalk sightings** | Client-only glimpses of La Silueta behind a trunk at dusk, night, dawn: every ~50 s (x0.6 carrying, x0.8 far from home, x2 with "Efectos suaves"), at most 3 per evening, 18 to 36 studs away, gone when looked at, approached, after 4 s or when the real one hunts. Never in the camp or hub (+10 studs) | `WildboundHudView.luau`, `WildboundFear.client.luau` | Done (SS1 to SS3, HF-T1) |
| 4.17 | **Sprint and stamina** | Walk 16 untrained, up to 50 trained (PF2; a carrier keeps its carry share, about 34 with one egg at the top level); sprint and the dodge boost never slow a trained walk; sprint x1.45 (cap 24), pool 100, drain 25/s (4 s), regen 10/s moving, 15/s still, x2 in a Refugio. Sprint is loud (hearing 30) | `WildboundStamina.luau` | Done |
| 4.18 | **Hiding spots** | H to hide; a hidden player is never acquired; rustle noise 10 | `WildboundHide.luau` | Done |
| 4.19 | **Random world** | Spawns live 300 s then move; respawn 90/150/240/360 s by rarity; at most 4/3/2/1; 40 % eggs; a held prompt pins its spawn | `WildboundSpawnClock.luau` | Done (RW2) |
| 4.20 | **Waves, Refugios, event** | Wave 300 s, the only world clock (CA4): Collect 0 to 290 s, Warning the last 10 s (no new steal hold or Arrullo; a hold begun earlier resolves), countdown notices at 10/5/3/2/1 s; at the refresh: reroll the unheld random spawns, restock the island nests emptied last wave (once per wave id, pure core `Island.waveRefill` since CF2; carried, dropped and secured eggs untouched), random spawns live until their wave ends (no second timer; a held spawn gets the new wave's expiry), Refugios move (r 12, stamina x2, chases end), board reset (the board and event banner stay hidden, owner decision). The bound wave end (`waveEndsAt`) is the one truth, so a tuned `WAVE_SECONDS` applies from the next wave. Event: first at 300 s, then every 1200 s, 300 s window, one Legendaria Tizoncillo egg within 45 studs of La Silueta's home, one claimant | `WildboundWaveClock.luau` | Done (RW3 to RW5) |
| 4.21 | **Luck totem** | Crafted (15 Esencia, 6 Fogbark, 6 Glowmoss, hold 1), placed 30+ studs from camp for 60 s, radius 40: the next spawn inside rolls one tier up (and one spawn is lured in). Single use. Q10 persistence (schema 4, cap 5) is now the schema 4 rung of the record ladder and `WildboundSave` saves the held totems | `WildboundGear.luau`, `WildboundTotemRecord.luau` | Totem: Done. Persistence: wired, suites passed (TotemRecord 7/0), no saved-totem rejoin recorded |
| 4.22 | **Gathering** | 24 gather slots (outside, fog, territory; hold 3/4/6/9 s), Fogbark, Glowmoss, Nightbloom (the forest's night table; always rollable since CA4, the forest being always dark; since CF1 each node wilts 300 s after it appears, "se marchita pronto") | `WildboundGatherField.luau`, `WildboundGather.server.luau` | Done |

---

## 5. Beasts and La Silueta

### 5.1 La Silueta (the forest's stalker)

| Item | Value | Source |
| --- | --- | --- |
| One per player | Each player has their own hunter (cap `MAX_HUNTERS` 8); it only ever targets its owner; others see it faint | `WildboundHunters.luau`, `WildboundWorld.server.luau` |
| Where | Only in the fog territory: home (0, -85), territory leash 80, chase leash 100, give-up distance 100 | `WildboundWorldRules.luau` |
| States | Patrol, Suspicious, Investigate, Search, Retreat (brain); Alert, Hunt, Telegraph (fight) | `WildboundGuardianBrain.luau` |
| Speed by phase | Hunt: Day 13, Dusk/Dawn 15, Night 17; detection 21 / 26 / 30; chase 12 / 15 / 18 s. Since CF1 her own body's place decides: in the forest she reads the **Night** row (creature profile 8/38); her night hunt speed and sight in a chase were not measured in Play | `Brain.PROFILES`, `BiomeLight.phaseAt` |
| Walk vs her | Q9's walk cap 16 is gone: since PF2 a trained walk reaches 50 (about 34 carrying one egg), so a trained walker outruns her night hunt 17 and the parents' 19. Retuning the threats is an open product question (14.2) | `WildboundTraining.WALK_CAP` 50, `WildboundStamina` |
| Strike | Telegraph 0.9 s (target-only warning at least 0.8 s before impact), range 7, repeat 2.5 s | `Rules.TELEGRAPH_SECONDS` |
| Two hits | First landed strike marks the player (health pinned at 35, knocks the carried egg loose for anyone, drops a bag item); rest 5 s to clear the pin; a second strike while marked defeats | `WildboundFairStrike.luau`, `docs/mechanics/wildbound-fair-strike.md` |
| Extra moves (each tunable on/off) | Lunge after 3 s of hunt (0.5 s tell, 22 studs/s for 0.8 s, never strikes); fake retreat (25 %); flashlight glare stagger (held 1.5 s within 12 studs: 1 s, once per chase); scream reaches 70 studs and wakes islands | `WildboundSiluetaMoves.luau` |
| Look | Original horror rig v3 (asset 123768633946912, 18 bones, 4 animations: Idle 90427760879990, Locomotion 109004575414309, Telegraph 106571946482274, Attack 139759980248576), art scale 3.8 (about 32.6 studs tall), art only | `odd/tasks/wildbound-first-playable.md:161`, `:208`; `Rules.SILUETA_VISUAL_SCALE` |

### 5.2 Fair-strike rule

No attack may land unless the target could see it coming. The gates (`WildboundFairStrike.luau`):

| Gate | Value |
| --- | --- |
| Warning lead | The target-only warning must be sent at least **0.8 s** before impact (`WARNING_LEAD`); every new attack (parent charge, parent swing, Viper, Pouncer, planned Dodge window) uses 0.8 s as its floor (`BeastConfig.MIN_TELL`) |
| Acknowledgement | Client acknowledges within 1.0 s; K = 2 free cancels per life |
| Dwell | 3 s inside the dwell radius (min of `StreamingMinRadius` and 64) before a warning can lead to a strike (streaming safety) |
| Liveness | A `FieldPulse` within 3 s |
| Stall | A step gap over 0.5 s cancels |
| Damage mode | Real only when `WildboundFlags.damageMode = "private"` **and** the place is `122652861404212`; otherwise shadow mode (gates run, nobody is hurt) |
| First trip protection | Nobody is lethal before their first paid trip home (one registered creature, banked material or Esencia) |
| Safe zones | Never in the camp, shelter, Refugios, hub disc or within 9 studs of the old spawn pad |

### 5.3 Beast director

Per player, server-only (`WildboundBeastDirector.luau`, `WildboundBeasts.server.luau`, config `WildboundBeastConfig.luau`):

| Rule | Value |
| --- | --- |
| Tick | Every 10 s, one roll per eligible beast per living player outside a safe zone |
| Budget | 3 points per player, at most 2 encounters at once |
| Chance | clamp(base x product of multipliers, 0, 0.20); product capped x4 |
| Multipliers | Night x2 (since CF1: where the player stands is a Night place, i.e. the forest, Abismo or Cuevas), far from base (over 150 studs from both camp and hub) x1.2, dangerous zone (fog or territory) x1.5, long expedition (180 s outside safety) x1.3, storm x1 (no weather) |
| Cooldowns | Global 15 s after any encounter; respawn grace 10 s; per species (Viper 35 s, Pouncer 40 s) |
| La Silueta | Outside the budget; no beast starts while that player's Silueta hunts or telegraphs (`SiluetaActive`) |
| Release | Exactly once per encounter (death, safe zone, escape, end, error) |
| Visibility | Since SC0 (Q4) every player within 150 studs (kept to 165, at most 4 other players' beasts) sees every beast except La Silueta, as a quiet copy without effect fields; only the target is ever hit, slowed or knocked (`WildboundBeastAudience`). A viewer in a safe zone sees none; a viewer in the meadow sees only the summoned kids beasts. Solo Play only: the second viewer was simulated (SC0.6 open) |
| Biome preference | Global beasts have **no preferred biome** (`Config.BIOME_PREFERENCE = false`, `f9c7ef4`); the kids and Caramelo beasts are summoned by presence at their sites instead of rolled |

### 5.4 The rolled beasts

`Config.PLAYABLE` (the beasts the director rolls) is Viper, Pouncer, Streamer, Root, Gaze, Lurker and Scuttler; Gargoyle and Mire are config only.

| Beast | Points / odds | Behaviour and telegraph | Hit | Status |
| --- | --- | --- | --- | --- |
| **Scuttler** (global, threat 3) | 3 (fills the whole budget) / 1:60, cooldown 75 s | 13.65-stud crab (46-part proxy). Stalk 20 to 34, Ruta predictiva (intercept a straight run, never through a safe zone, the meadow or a wall), Finta de caza (outline-only feint lane, no sound), committed charge (red lane 8 wide, locks 0.3 s before), Snap sector, Pulso de pánico (slow 16 to 12 for 1.5 s; a second pulse inside its memory knocks the egg loose), overrun and fall (stars). Pulse cooldown 9 to 5 s is still the owner's call | 30 (private mode only) | **Done (solo Play, SC7, SC8)**; bystander view, a charge landing on a carrier and "Efectos suaves" not checked; no rig or clips (SC9, SC10 open) |
| **Streamer**, **Gaze**, **Lurker** (global) and **Root** (Pantano) | 2 each / Viper's odds | Wave-2 pack beasts (rush and scream; gaze-cone exposure zone; leap when unobserved; root traps and walls) | 28 / 18 / 24 / 22 | Wired, suites passed in every beast regression; built by the teammate in Studio and synced at `34eab83`; **no Play record and no feature doc** in this repo |
| **Viper** (global) | 1 / 1:45 | Spawns 35 to 70 studs out, stalks to 18 to 30, sidesteps up to 1.5 s for a clear lane, windup 1.15 s with a red lane (4.5 x 32) that follows 0.7 s then locks; dash 60 studs/s; walls cut the dash; up to 3 attacks, 32 s; "¡Una víbora va a embestir! Sal de la línea roja." | 35 | **Done** (Part proxy, 38 parts) |
| **Pouncer** (global) | 1 / 1:55 | Hunts to 20 to 34, red circle r 6.5 at your predicted spot, follows 0.25 s then freezes; telegraph 1.3 s; leap 0.75 s; 2 jumps (cap 3); "¡Una araña va a saltar! Sal del círculo rojo." | 40 | **Done** (Part proxy, 36 parts) |
| **Gargoyle** (Cementerio) | 2 / 1:100, cooldown 60 | Statue that awakens (clips exist) | 25 | Config only (`PLAYABLE` excludes it; biome refused) |
| **Mire** (Pantano) | 2 / 1:80, cooldown 50 | Submerged swamp ambusher | 40 | Config only |

A beast hit knocks the carried egg loose; health drops only in private damage mode after the first paid trip (NB-W2). The parents (4.3) and La Silueta are separate from the director.

### 5.5 Summoned beasts (kids and Caramelo)

Summoned by presence at their sites (`WildboundPraderaSites`, `Director.summon`), never rolled; no global cooldown; damage 0 always; never drawn for a forest viewer and no forest beast is drawn in the meadow.

| Beast | Where | Status |
| --- | --- | --- |
| **La Nube Gruñona** | The Pradera pond offset (150, 0) from the sector origin | **Done (solo Play, KB-8)**: Calm, Notice, Chase, Telegraph; two strikes hit, health 100/100. A Ráfaga push and the client view (KB-9, KB-10) not observed |
| **La Abeja Reina** | La Colmena (-75, 75), only while the biome event window is open | **Done (solo Play, KB-8)** with `ForceAbejaEvent`; a Pegajoso sting not observed |
| **Gomibu** | Caramelo, post `candyNest` (guards nest C1) | Wired, suites passed (BeastGomibu 9/0); synced from Studio at `d71b87f`; its build record (`odd/tasks/caramelo-bioma.md`) and Blender source are not in the repo |
| **Flanfuria** | Caramelo, post `candyNestR1` | Done (solo Play, CA1, `1de89f3`) |
| **Tortidragon** | Caramelo, post `candyNestC3` (510, -143) | Done (solo Play, CA2, `fed4228`); moves in its rest pose (clips unpublished) |
| **Don Glaseon** (boss) | BossHome (578, -3), territory r 62 around (612, -3); one per server, rare-egg carrier first | Done (solo Play, CA3, CF3); target switching needs two players; rest pose until the clips are published |
| **Mochimiau, Canelin, Flanin, Mielita, Gato Repartidor** (candy critters, one shared brain) | Caramelo posts beside free nests R2, R3, R4, C4, C2 | Done (solo Play, CC6, 2026-11-16): summoned, Notice, Chase, one telegraphed attack each (leap, dash, burst, lob, lob), slow and push seen, damage 0; tells still fall back to red (CC7); `odd/tasks/wildbound-candy-critters.md` |
| **Duquesa Burbuja** | Seated scenery on the Gran Torta top (`Workspace.WildboundNewCandyPreview`) | Design only as a creature: no brain, never summoned |

The kids rule from the design (a hit parks one item for 120 s, a second hit is a 3 s gust) is only partly built: a hit knocks a carried egg loose and sets a mark; parking a bag item is out of scope (`odd/tasks/wildbound-kids-beasts.md`).

---

## 6. Creatures and collection

| Species | Rarity | Where | Look (stand-in) | Art |
| --- | --- | --- | --- | --- |
| **Lumipol** | Común | Island 1, random spawns, the tutorial | Mint glowing blob, 3 x 2 x 2.4 | Generated parent and egg templates (`ServerStorage.WildboundAssets.Lumipol.Parent` and `.Egg`, LG pass `2e176d5`); their meshes load; they persist only if the place is saved. MeshGen1 is no longer used (its meshes are refused) |
| **Cortezón** | Común | Island 2, random | Mossy bark shell | Primitive; rig exported (`assets/exports/species/SP_Cortezon`), not uploaded |
| **Cestillo** | Rara | Island 3, random | Long-necked wader | Primitive; rig exported |
| **Polvilla** | Épica | Island 4, random | Dusty moth | Primitive; rig exported |
| **Tizoncillo** | Legendaria | Island 5, the biome event egg | Glowing ember log | Primitive; rig exported |
| **Gomibu** | Común | Caramelo nests C1 to C5 | Gummy egg (CG1); farm pet = scaled rig, 3 studs | Model 97819093908843 + 10 group clips; hotbar icon 130041727906990 (loads through `rbxthumb://` since IC, 2026-11-16) |
| **Tortidragon** | Rara | Caramelo nests R1 to R4 | Cake egg; farm pet 3.6 studs | Model 103052975067537; 11 clips unpublished; icon 85016154045779 (not loading) |
| **Flanfuria** | Épica (Legendaria nest L1 off) | Caramelo nests E1, E2 | Flan egg; farm pet 3.2 studs | Model 109182574821732 + 10 group clips; icon 106158128076232 (not loading) |

The three Caramelo species are **farm-only** (`Species.FARM_ONLY`): a hatch never makes them the companion and `equip` refuses ("...no te sigue."). Caramelo nests hold one egg each, have no sleeping parent and refill with the 300 s wave. Since PF3 every newborn goes to the **creature hotbar** (a Tool per creature, rebuilt on respawn); placing it on the own base pad moves it to the **farm** (4 slots, saved, schema 5), where it wanders (PF6) and stops following; "Guardar en la barra" brings it back. Lumipol tools carry icon 121561289565386 (PF7; loads through `rbxthumb://` since IC, 2026-11-16).

Pradera adds five designed species (Chispín, Musgón, Esponjín, Hongolín, Relampino) with one ability each: design only.

| Collection rule | Value |
| --- | --- |
| Forms | Egg (stolen, then incubated) or cría (captured with the ring); a cría is 0.55 of an adult |
| Registration | At the camp refuge (V) or by hatching; registered creatures are never lost |
| Limit | 100 registered (`capacity.collectionLimit`) |
| Companion | One out; light; Lumipol pulse; bond XP from pulse reveals in fog (5, max 4 per trip), extracting with it (10), pulse-then-dodge (5); bond 3 and 5 shorten the pulse cooldown to 27 / 25 s |
| Display | Base display shows up to 3 (companion first); camp display shows one |
| Durable IDs | Session IDs `wb:N` become saved IDs `uN` the first time they are saved |

---

## 7. Economy and progression

**One currency: Esencia** (code id `ember`). Never lost on defeat, never purchasable (`currency.purchasable = false`, `monetization = "none"` in `WildboundEconomyConfig.luau`). Materials: Fogbark (common), Glowmoss (uncommon), Nightbloom (rare, night only, carried as a bag item). The config is generated from `docs/mechanics/wildbound-economy-p0.md`; every number is a hypothesis.

### 7.1 Sources

| Source | Esencia |
| --- | --- |
| Trip base (extraction) | 4, if the trip lasted 25 s (BP3, 2026-11-15; was 45 s), reached 60 studs from camp and found at least one new item |
| Creature by tier | Live (synced `34eab83`): Safe 8, Fog 14, FogFar 20, Territory 28, Heart 42 (was 6/10/12/14/22) |
| Egg by tier (delivery) | Live: Safe 4, Fog 10, FogFar 16, Territory 24, Heart 36 (was Fog 8, FogFar 10, Territory 11, Heart 14); Caramelo nests pay one tier lower since BP3 (Comun Safe 4, Rara Fog 10, Epica FogFar 16) |
| Hub roulette | Esencia prizes (40 % of the live table), materials the rest (PF5) |
| First steal bonus | 4 |
| Releasing a duplicate creature ("Liberar", BP4a) | 4 per spare hatched creature, from the bag panel (two taps); never the companion, a farm creature or the last of its species |
| First extraction | 1 seal (item, not Esencia) |
| Hatching | 0 (contract, NS6) |
| Time-based grants | 0 (anti-AFK contract) |

### 7.2 Sinks and prices (live)

| Item | Cost | Effect |
| --- | --- | --- |
| Sello (seal) | 8 Fogbark, 4 Glowmoss | Protects one bag item from a defeat (cap 3) |
| Cápsula | 8 Fogbark, 5 Glowmoss, 1 Nightbloom, 12 Esencia | Secures one item at the shelter (cap 1) |
| Ward totem | 12 Glowmoss, 2 Nightbloom, 20 Esencia | Wards one extra item, +6 detection, draws ambushes (cap 1) |
| Farol tapado (starter upgrade) | 10 Esencia | Island light scale 0.5 |
| Mochila reforzada | 60 Fogbark, 30 Glowmoss, 120 Esencia | Bag 4, pouch 45, loss 10 % |
| Skill tier 1 (each of 4) | 40 Esencia, 20 Fogbark, 10 Glowmoss | See 7.4 |
| Skill tier 2 (each of 4) | 100 Esencia, 30 Fogbark, 20 Glowmoss, 3 Nightbloom | See 7.4 |
| Guantes (gloves) | 30 Esencia, 14 Fogbark, 8 Glowmoss (max 12 held) | Random stats, 7.3 |
| Tótem de la suerte | 15 Esencia, 6 Fogbark, 6 Glowmoss (cap 1) | 4.21 |
| Treadmill (PF2) | 17 levels, base 30, growth 1.2 (level 17 costs 555); the live belt also trains by running: each 8 s lap gives +1 level and 5 Esencia | +2 walk per level, 16 to the cap 50 |
| Hub roulette (PF5) | 45 Esencia per paid spin; one free spin | 11 prizes (Común 68, Rara 22, Épica 7, Legendaria 3 %), Esencia and banked materials only; Rara+ pity every 10; odds listed before any spin |

### 7.3 Gloves (random stats)

Rarity weights Común 60, Rara 28, Épica 10, Legendaria 2; 1 to 4 distinct stats within a share of each cap (Común 25 to 50 %, Rara 35 to 60 %, Épica 50 to 80 %, Legendaria 70 to 100 %). One worn at a time ("Ponerte"). No special abilities (the old Chaleco and Amuleto were removed).

| Stat (Spanish) | Cap | Effect |
| --- | --- | --- |
| Velocidad | 3 % | Walk, under the walk cap (50 since PF2) |
| Robo rápido | 15 % | Steal hold, floor 0.6 s |
| Recarga de impulso | 20 % | Burst cooldown (will need re-targeting when the Dodge replaces the Burst) |
| Aliento al correr | 30 % | Sprint drain |
| Calma | 30 % | Capture calm meter, floor 4 s |

### 7.4 Skill tree (live in code)

| Node | Tier | Effect | Live |
| --- | --- | --- | --- |
| explorer_1 | 1 | Node hint range 60 | Yes |
| explorer_2 | 2 | Nightbloom hint range 100 | Yes |
| capturer_1 | 1 | Calm required 4.0 s | Yes |
| capturer_2 | 2 | Retry cooldown 3 s | Yes |
| survivor_1 ("Carga ligera") | 1 | Carry speed +1 | Yes |
| survivor_2 | 2 | Rest 2 s | No |
| occultist_1 | 1 | Relocation notice | No |
| occultist_2 | 2 | Flashlight reveal 5 s | No |

The 20-node tree of `docs/design/wildbound-economy-and-offers.md` section 4 is design only.

### 7.5 Planned sinks (not wired)

| Item | Plan | Status |
| --- | --- | --- |
| Cofre del explorador (chest roulette at each base) | **Superseded:** the user put the roulette in the hub (2026-11-14) and it is built (7.2, PF5). The base-chest plan was: 45 Esencia; gloves 72 % (Común 36, Rara 24, Épica 9, Legendaria 3), materials 15, seal 8, luck totem 5; odds shown before paying; **pity at 10** (an Épica+ glove); 4.5 s roulette, "Saltar" after 1.5 s; refuses before charging when gloves are full; no Esencia reward; Esencia only | Chest circles built as geometry; rules **Design only** (`docs/design/wildbound-hub-expansion.md` section 6; the `chests` block is not in the economy config yet) |
| Glove recycling | Común 3, Rara 6, Épica 12, Legendaria 25 Esencia; never the worn one; hub or camp only; hold-to-confirm for Épica+ | Design only (section 8 of the same doc) |
| Shop circles (Taller de guantes, Mejoras, Suministros, Árbol de habilidades) | Stand on a ground circle (r 4) to open the shop; server range 6 | Geometry built; rules Design only |
| Second cradle | Free or the 250 Esencia step (open) | Geometry built; Design only |
| Corral income, trophies, breeder level, daily gift, cosmetics | `docs/mechanics/wildbound-hub-systems.md`, `docs/design/wildbound-economy-and-offers.md` | Design only |

### 7.6 Economy simulator floors

`python -I -B tools/simulate_economy.py` (200 runs x 90 trips): median expedition **cautious 208 s, balanced 201 s, greedy 183 s**; the contract floor is **180 s** (an expedition must never become a short farm loop). Fully trained with the best glove: 203.8 / 197.2 / 182.3 s. The simulator does not model the islands, random spawns, eggs in arms, Burst, PvP, beasts, hub or chests (recorded RW-W7, NH, NP, NB notes). `tools/simulate_hub_economy.py` covers the designed corral/tree timelines (free balanced: tier 3 at 180 min). `tools/simulate_silueta_pressure.py` covers La Silueta exposure.

---

## 8. Persistence and safety

| Item | Value | Status |
| --- | --- | --- |
| Approval | User approved permanent saving of progress on 2026-11-10 ("Sí, aprobalo") for this save only | — |
| Modules | `WildboundRecord` (schema **6**: 4 luck totems `WildboundTotemRecord`, 5 base farm `WildboundFarmRecord` (PF4), 6 roulette `{ freeSpinUsed, pityCount, paidSpins }` `WildboundRouletteRecord` (PF5); each step a sibling module, a malformed field fails validation so the load is quarantined and nothing is written), `WildboundPersistence` (session lock), `WildboundSave` (joins state and store), `WildboundStoreRoblox` (the only module naming `DataStoreService`) | Done (NS1, NS2) |
| Lock | Session lock in key metadata, taken in the same `UpdateAsync` that reads and migrates; stale after 300 s; 3 attempts with 1, 2, 4 s backoff plus jitter | Done |
| Failed or locked load | Plays a fresh profile that is **never written**; notice "No pudimos cargar tu progreso. Tus datos están a salvo. Juegas sin guardar..." | Done (Play: stored value byte-equal) |
| Saves | Autosave about every 60 s only when the saved fields changed, waits while the request budget is under 4; on leave; `BindToClose`; key list snapshotted before saving (join/leave mid-save safe) | Done |
| Saved | Banked eggs, registered creatures, companion, Esencia, banked materials, consumables, upgrades, skills, bond, incubator (Unix times), training levels, gloves, luck totems held, the base farm (durable IDs), the roulette's free spin and pity | Done in the memory store (solo Play); farm and roulette rejoins covered by RT-27, RT-29, SV-22, SV-23 only |
| Never saved | The bag, the pouch, an egg in the arms, a carried or dropped creature, the trip, a placed (active) totem | Done |
| Schemas 4 to 6 | Totem, farm, roulette steps | Wired; Record 29/0, Save 23/0, Persistence 31/0, TotemRecord 7/0 |
| Mode | `WildboundFlags.persistenceMode` "datastore" (default), "memory", "off" | Done |
| Studio | API access is off, so Studio uses the **memory store** and says so in the output; a real data store, two servers and a crash are **not verified** | — |
| Server authority | Clients send intents only ("bat", "sprint", "burst", action ids); the server measures distance, alive state, safe zone, hold time, ownership; rate limits per remote; no client position, price or amount is trusted | Done (security contracts in the suites) |
| Damage flag | Private damage only for the unpublished test place; publishing with it needs its own approval | Done |
| Analytics | `analyticsMode` "off"; no live sink | Done |
| Dev tools | Tuning panel (`WildboundTuningRequest` RemoteFunction, Studio developers only), probes in `ServerStorage` (never visible to clients) | Done |

Details: `docs/mechanics/wildbound-persistence.md` ("Live saving").

---

## 9. UI, HUD and controls

### 9.1 Controls

| Action | Keyboard / mouse | Gamepad | Touch |
| --- | --- | --- | --- |
| Move / jump | WASD, Space | Stick, A | Joystick, jump |
| Sprint | LeftShift | L3 | Sprint button |
| Steal, take cría, pick up egg, Lumipol prompts | E (hold) | ButtonX | Prompt |
| Capture seal tap | X | R2 | Button |
| Esquiva perfecta (the Burst "Impulso" is retired) | Z | **(unverified)** | **(unverified)** |
| Bat "Bate" | Left click (never on UI) | DPadRight | "Bate" button |
| Flashlight "Linterna" | F | — | Button |
| Pulse "Pulso" | Q | — | Button |
| Hide "Esconderse" | H | DPadUp | Prompt |
| Gather | G | ButtonY | Prompt |
| Mochila (inventory) | I or C | — | "Mochila" button |
| Menu | M | — | Button |
| Camp / base prompts | E chest or delivery, R hatch or incubator, T protect, V register, B board or glove bench, N train | X, B, L1, R1, L2, DPadLeft | Prompts with screen offsets |

Prompt-key conflicts are checked by `WildboundPromptKeys.conflicts()` (0 conflicts recorded). Gamepad inputs for F, Q, I and M are not listed in `PromptKeys` **(unverified)**.

### 9.2 HUD and screens

| Element | Notes |
| --- | --- |
| Start screen, tutorial, settings | `WildboundStartView`, `WildboundTutorial`, `WildboundSettings`; "Efectos suaves" (reduced effects) removes shakes, halves heartbeat/red edge/darkness, makes sightings rarer, makes the planned roulette a fade |
| Threat chip, attack warnings in text | Warnings are always readable without sound (fair-strike) |
| Wave board and event banner | **Hidden** (owner decision 2026-11-14, RW7 pins it); the wave countdown notices "Los huevos se renuevan en 10 s" ... 1 s show instead (CA4) |
| Roulette, portal, hotbar | Roulette panel with every prize's odds, price or "Tirada gratis", pity counter (PF5); portal prompt "Volver a la base", 2 s bar "Volviendo a tu base...", "Listo en N s" (CE3); creature tools in the Roblox hotbar (PF3) |
| Mochila panel | Pending, banked and registered sections; Equipar/Guardar; Incubar |
| Camp/board screen | Upgrades, skills, gloves ("Ponerte"), crafts; opened by the base glove bench too |
| Save line | "Progreso guardado." or "Solo esta sesión." |
| Fear presentation | Heartbeat, vignette, FOV kick, red flash (client tunables in "Cámara y sensaciones") |
| Known text issue | The objective still reads **"Roba y vuelve al campamento."** although players spawn and deliver at the hub (`WildboundText.luau:350`, open HF question 3) |
| Planned | Inventory tabs (Guantes, Objetos, Materiales), shop bottom sheets: design only. The "¡Estás a salvo!" banner stays hidden (owner decision, BZ8); the Arrullo bar and the dodge (Z) are live through the synced world client |

Phones: layouts are designed for 375 x 667 portrait and 667 x 375 landscape with 44 px targets, but **no phone or Device Simulator test has been recorded** for the Nest Heist features.

---

## 10. Art and assets

| Asset | Kind | In game today | Ids / files |
| --- | --- | --- | --- |
| Forest kit | Real meshes (six Model packages) | Yes | `assets/exports/forest-kit/forest-kit-upload-manifest.json` |
| La Silueta v3 | Real rigged model + 4 animations | Yes | Model 123768633946912; animations listed in 5.1; `docs/assets/silueta-animation-upload-manifest.json` |
| Lumipol (generated parent and egg, LG pass) | Roblox mesh generation, text prompts | Templates in `ServerStorage.WildboundAssets.Lumipol`; meshes load; kept only if the place is saved. MeshGen1 (meshes refused) is no longer used | `assets/exports/lumipol-generated-assets.json` |
| Viper, Pouncer, Gargoyle, Mire | Rigged FBX, 25 clips in all | **Models uploaded, not in the game**: no code or place references the ids; Viper and Pouncer show as Part proxies; an imported model named exactly `Viper` or `Pouncer` in `ReplicatedStorage.WildboundBeasts.Models` replaces a proxy with no code change | Viper 77139866631513, Pouncer 87204464156490, Gargoyle 113241144174504, Mire 105993486058377 (`assets/models/beasts/uploaded-assets.json`, moderation Approved) |
| Beast animations | 25 FBX clips | **Not uploaded** | `assets/models/beasts/*_anim_*.fbx` |
| Other species (Cortezón, Cestillo, Polvilla, Tizoncillo) | Rigs exported | Primitive stand-ins | `assets/exports/species/` |
| Hub, camp, bat, egg, Refugios, totems | Primitive parts by design | Yes | Builders in `tools/` |
| Pradera and six other biome kits | FBX exported; primitive Luau fallbacks | Not built in the place **(unverified)** | `assets/exports/<biome>-kit/` |
| Sounds | Existing catalogue ids only (`WildboundAudioCatalog`), reused slots for beasts, bat and burst | Yes | — |
| Caramelo creatures | Gomibu 97819093908843, Flanfuria 109182574821732 (v3), Tortidragon 103052975067537, Don Glaseon 91765062667935 (models); candy kit 139302047387424 | Yes (prefabs in `ServerStorage.WildboundAssets`) | Gomibu and Flanfuria: 10 group-owned clips each, playing. Tortidragon and Don Glaseon: 22 clips built as KeyframeSequences in `ServerStorage.WildboundPublishClips`, **not published** (user-owned uploads cannot load in the group universe); two user-owned Idle tests (115362506833585, 81874477774437) unused. Receipts `assets/exports/caramelo/upload-receipts.md` |
| Hotbar icons | 256 x 256 images | Load since IC (2026-11-16): `Toolbar.ICONS` is built from `Toolbar.ICON_IDS` as `rbxthumb://type=Asset&id=<id>&w=150&h=150` (the plain `rbxassetid` form failed with "Requester does not have permission for Asset"; Play showed the four hotbar slots loaded) | Lumipol 121561289565386, Gomibu 130041727906990, Flanfuria 106158128076232, Tortidragon 85016154045779; sources `assets/icons/` |
| Candy eggs | Primitive parts (`WildboundCandyEggArt`) | Yes (CG1) | — |

What needs the user: publish the 22 clips and share the 4 icons with group 465694015 (14.1); save the place so the generated Lumipol templates persist; approve and import the beast models into the place (3D importer or by id) and later the 25 clips; approve any upload of the six biome kits.

---

## 11. Monetization stance

| Rule | Source |
| --- | --- |
| **Nothing is purchasable.** `monetization = "none"`; no `MarketplaceService`, Developer Product or Game Pass exists; a contract test fails if a server script names `MarketplaceService` | `WildboundEconomyConfig.luau`, NS6 |
| Never change monetization without the user's explicit approval | `AGENTS.md` |
| Esencia is never sold, alone or bundled; the skill tree is never sold; survival and fear relief are never sold; totems are never sold | `docs/design/wildbound-economy-and-offers.md` sections 3, 4, 9 |
| The chest stays Esencia-only; if a Robux item that produces Esencia is ever approved, the chest must be re-reviewed against Roblox's paid random item rules first | `docs/design/wildbound-hub-expansion.md` section 6 |
| Designed Robux offers (placeholders only, outdated item list): Bolsa grande, pen 6, second incubator, three level-I equipment pieces; 166 to 215 Robux non-cosmetic ceiling; kids-safe surfacing (no card before the second session and 30 minutes, no countdowns, plain "No, gracias") | Same doc, section 8 (**Design only, partly outdated: the equipment pieces no longer exist**) |

---

## 12. Technical architecture

### 12.1 Layout

| Place location | Contents |
| --- | --- |
| `ServerScriptService` | `WildboundServer` (inventory, heist, hub stations wiring; at Luau's top-level local limit: new helpers and requires go in the `Heist` table, NH-W13 caught 226 locals in CG1), `WildboundWorld` (La Silueta, fair strike), `WildboundRouletteService`, `WildboundPortalService`, `WildboundCreatureToolbar`, `WildboundTreadmillService`, the `WildboundCandy*Service` scripts, `WildboundBeasts` (director and encounters), `WildboundHub`, `WildboundGather`, `WildboundTuning`, `WildboundWorldGuard`; pure modules (`WildboundState`, `WildboundEggCarry`, `WildboundBat`, `WildboundIsland`, `WildboundWorldRules`, `WildboundFairStrike`, `WildboundBeastDirector`, `WildboundPersistence`, `WildboundSave`, `WildboundStoreRoblox`, ...) |
| `ReplicatedStorage` | Shared pure modules (`WildboundText`, `WildboundBeastConfig`, `WildboundWaveClock`, `WildboundStamina`, `WildboundGear`, `WildboundHudView`, ...), `WildboundNetwork`, `WildboundBeasts.Models` |
| `StarterPlayerScripts` | `WildboundClient`, `WildboundWorld.client`, `WildboundCapture.client`, `WildboundFear.client`, `WildboundAudio.client`, `WildboundBeasts.client`, `WildboundTuning.client`, `WildboundStart.client` |
| `ServerStorage` | `WildboundHubBuilder`, `WildboundAssets` (ForestKit, SiluetaV3, LumipolMeshGen), test suites, Studio-only probes |

Source: `src/wildbound/` (115 Luau files after the `34eab83` sync of the live Studio scripts), tests `tests/` (95 files), generators and Python tests `tools/`.

### 12.2 Remotes

| Remote | Direction | Purpose |
| --- | --- | --- |
| `WildboundNetwork.Action` / `State` | client intent / server snapshot | Inventory, crafting, stations |
| `WildboundNetwork.CaptureState` | server to owner | Capture minigame feed |
| `WildboundNetwork.Stance` | client intent | "sprint", "walk", "burst", "bat" (8/s limit) |
| `WildboundNetwork.WorldEvent` | server to all only (client messages refused and counted) | Waves, Refugios, events, variants |
| `WorldAction`, `WorldState`, `AttackWarning`, `AttackResolved`, `AttackAck`, `ClientReady`, `FieldPulse` | World script | Flashlight/pulse, La Silueta state, fair-strike handshake |
| `BeastEvent` | server to target only; no server handler | Beasts |
| `WildboundTuningRequest` (RemoteFunction) | Studio developers | Dev tuning panel |
| Server-only BindableEvents/Functions | `CaptureStrike`, `TotemChanged`, `PulseHit`, `GuardianNoise`, `BeastHit`, `Eligibility`, gear events | Cross-script calls clients cannot reach |

### 12.3 Tests, deploy and verification

| Item | Value |
| --- | --- |
| Studio suites | 70 suites, **1454 passed, 0 failed** on fresh module clones (LG pass, the last comparable full run). A later full run (2.0 T01, rebuilt runner, 88 suites) found 62 failures in 23 suites; it is not comparable and the failures are not attributed. The reproducible runner is now `tools/studio-fresh-runner.luau` (it removes its temporary `ServerStorage.WildboundFreshRunner_Tmp`). Since 2026-11-14 each task runs the suites that read its touched sources (34 to 54 suites per task) instead of a full run; **no full run of every suite has been recorded since** |
| Remaining red suites (2026-11-15, CG1 regression) | **AN-3** (AnalyticsWiring), **BZ7** (BaseZone), **ECO-20** (Economy: the base-zone loop runs on a timer), **EL12** (EggLoop), **HB-T3** (Hub), ~~W1~~ (MechanicsWiring: the stale `canSteal` pin, fixed in AR 2026-11-15), **RW5** (WaveClock: the server's event-egg text). Also known: **DT1** (Tuning: since EC the steal holds match; still red on the pickup delay and hold, 0.4 vs 0.25, and the hatch time, 5 vs 15, D19), the **14 State_Test EconomyConfig drift cases** (bag 12 and pay values), and the "every clip is published" case in `WildboundCandyTortidragonClips_Test` and `WildboundCandyDonGlaseonClips_Test` (empty `Clips.IDS`). BZ7, EL12, HB-T3, RW5 read the teammate's `WildboundServer` (suite-repair decision 3) |
| Formerly unrun suites | Dusk 9/0, TotemRecord 7/0, Dodge 14/0 now run green; `WildboundArrullo_Test` and `WildboundBatKnock_Test` have no recorded result in these docs (BatKnock is covered by `WildboundBossRobustness_Test` 8/0) |
| Python | `python -I -B -m unittest discover -s tools -p "test_*.py"`: **1195 run, 1 failure** (2026-11-15, CG1): the known `test_lumipol_v2.test_v1_files_are_unchanged`. The count fell from 1298 when the old economy simulator was retired (`1e5985b`); the export and audio failures of 2026-11-14 are gone |
| Deploy manifest | `tools/deploy_manifest.py` maps each repo file to its Explorer path (pinned by `tools/test_deploy_manifest.py`, 25/25); every Studio deploy is checked by bytes and Adler-32 (CRLF to LF, trailing newlines trimmed) against the repo, and a Studio Source that differs from HEAD is pulled before any write |
| Mode | Strict TDD; one Studio writer at a time; verify the Studio instance and place and get the user's confirmation before any edit (`AGENTS.md`) |
| Play checks | Solo Studio Play only, in the background (no two-client session, no Device Simulator); see each phase's table in `odd/tasks/wildbound-capture-extraction-horror.md` |
| Place state | Recent sessions did **not save the place**; the hub, link removal and tree removal happen at server start, so the place can be rebuilt from git plus the deployed sources. Not rebuilt from git: the Caramelo session switches (3.4), the `WildboundPublishClips` folder and the uploaded prefabs in `ServerStorage.WildboundAssets` |

---

## 13. Status matrix

Every Done is **solo Play only** (no two-player, phone or real DataStore record exists for any row).

| Feature | Status | Detailed doc |
| --- | --- | --- |
| Forest map, fog, relief, kit art | Done | `docs/maps/wildbound-p0.md`, `docs/maps/silueta-forest-concept-v1.md` |
| Day cycle 720 s | Removed (CA4, 2026-11-15) | `odd/tasks/wildbound-caramelo.md` (CA4) |
| Fixed light per biome (Caramelo always day, Bosque always night), ~1 s blend, local client only | Done (solo Play, CA4); two clients in different biomes and a 15-minute Caramelo stay not tested | Same (CA4) |
| Per-place gameplay phase: the forest, Abismo and Cuevas play by night rules (La Silueta night row, beast odds x2, islands' night wake, Nightbloom with its own 300 s wilt) | Done (solo Play, CF1); La Silueta's night hunt speed in a chase not measured | Same (CF1) |
| La Silueta per player, fair strike, mark-then-defeat | Done (damage path blocked by the streaming gate in older checks; private mode only) | `docs/mechanics/wildbound-fair-strike.md`, `docs/mechanics/wildbound-guardian.md` |
| La Silueta moves: lunge, glare, scream | Done | `docs/mechanics/wildbound-guardian.md` |
| La Silueta search and fake retreat on a lost quarry | Removed in the live code; owner decision 2026-11-14 "que siga patrullando normal" (she resumes the patrol; suites re-pinned) | `odd/tasks/wildbound-suite-repair.md` |
| Flashlight, companion pulse, reveal | Done | `docs/mechanics/wildbound-awareness.md` |
| Stalk sightings | Done | `odd/tasks/wildbound-capture-extraction-horror.md` (Stalk sightings) |
| Hiding spots, Refugios | Done | `docs/mechanics/wildbound-delivery-d.md` |
| Islands and parents (wake, chase 19, wind-up 0.4 s, charge, 0.8 s swing); trail nest T1 at (176, 44) by the hub W gate | Done (chase 19 and wind-up 0.4 restored by owner decisions 2026-11-14) | `docs/mechanics/wildbound-expedition-islands.md`; `odd/tasks/wildbound-suite-repair.md` |
| Random world, spawn clock, bough eggs (`EGG_SHARE` 0.4), waves, biome event, variants | Done (bough eggs restored 2026-11-14) | odd doc (Random world); suite-repair |
| Egg waves: one 300 s clock, 10 s Warning, countdown 10/5/3/2/1, nest restock per wave id, hold refused if it would end in the Warning (CF2), bound wave end | Done (solo Play, CA4, CF2); the 0.25 s hold-bar cut through a real prompt not tested | `odd/tasks/wildbound-caramelo.md` (CA4, CF2) |
| Wave board and event banner | Hidden by owner decision (2026-11-14); RW7 pins it | `odd/tasks/wildbound-suite-repair.md` |
| Steal (by rarity since EC: Común 0.5, Rara 0.9, Épica 1.3, Legendaria 1.8 s), server-measured hold, eggs in the bag up to its capacity, drop/pickup, death drop | Done (live values pinned in PF1; EC solo Play 2026-11-15, `odd/tasks/wildbound-caramelo-v2.md`) | `docs/mechanics/wildbound-capture.md`; `odd/tasks/wildbound-playtest-fixes.md` (PF1) |
| One backpack, only while carrying an egg (no bag on a carried creature) | Done (solo Play, PF1) | `odd/tasks/wildbound-playtest-fixes.md` (PF1) |
| Esquiva perfecta (replaces the Burst "Impulso") | Done (solo Play: a live press, SC1); wired by the teammate, synced `ad569e9` | `docs/mechanics/wildbound-new-mechanics.md`; `odd/tasks/wildbound-scuttler.md` (SC1) |
| Bat knockback (5 s, 1.2 s ragdoll, 3 s immunity) | Wired (synced `ad569e9`), suites passed; a landed hit needs two players, not recorded | Same |
| Arrullo (Épica and Legendaria eggs) | Off for now (AR, user 2026-11-15): `WildboundArrulloService.ENABLED = false`, every egg takes the plain steal hold; the module, remote and server path are kept for its return. Solo Play: an Épica egg stolen with the hold, the Arrullo panel stayed closed | `odd/tasks/wildbound-caramelo-v2.md` (AR) |
| Luck totem persistence (schema 4) | Wired, TotemRecord 7/0; no saved-totem rejoin recorded | Same |
| Dusk warnings and buff | Wired but inert since CA4/CF1 (no place resolves to Dusk); code kept | Same; `odd/tasks/wildbound-caramelo.md` (CF1 decision 4) |
| Auto-banking base zone | Wired by the teammate (synced); banner hidden by owner decision; no Play record of ours | `docs/design/wildbound-hub-expansion.md` section 7; suite-repair |
| Beast director, Viper, Pouncer (proxies) | Done | `docs/mechanics/wildbound-beasts.md` |
| Shared beast visibility (SC0: nearby players see every beast but La Silueta) | Done for the target (solo Play); the bystander view is **not verified** (needs two players, SC0.6) | `odd/tasks/wildbound-scuttler.md` |
| Global beasts with no biome preference (`BIOME_PREFERENCE = false`) | Done (suites; `f9c7ef4`) | `odd/tasks/wildbound-kids-beasts.md` |
| Scuttler SC1 to SC8 (config, afflict, brain, feint, predictive route, panic pulse, wiring, client and proxy) | Done (solo Play, SC7, SC8; `c64db0d`) | `odd/tasks/wildbound-scuttler.md` |
| Scuttler SC9 to SC12 (Blender rig and 17 clips, upload, two-player playtest, mechanics doc) | Not started (SC12's overview part: this snapshot) | Same |
| Streamer, Root, Gaze, Lurker | Wired, suites passed; no Play record and no feature doc (teammate, synced `34eab83`) | `docs/design/beast-pack/` |
| La Nube Gruñona, La Abeja Reina (summoned, damage 0) | Done (solo Play, KB-8); sticky sting, gust and the client view not observed (KB-9, KB-10) | `odd/tasks/wildbound-kids-beasts.md` |
| Gargoyle, Mire | Design only (config) | `docs/design/beast-pack/` |
| Caramelo biome map (`Candy_Bioma_v1`, 736 parts, replaces the Pradera in the Meadow square) | Done as the playable map (solo Play); built by `ServerStorage.WildboundCandyBuilder`, place not saved | `odd/tasks/wildbound-caramelo.md` (CA0) |
| Gomibu | Wired, suites passed; no Play record in this repo (its record `odd/tasks/caramelo-bioma.md` is not in the repo) | Same (CA0) |
| Flanfuria | Done (solo Play, CA1) | Same (CA1) |
| Tortidragon | Done (solo Play, CA2) except its animation: 11 clips built, **not published** (owner action) | Same (CA2) |
| Don Glaseon (boss, one per server, bat immune, sleeping copy pass-through) | Done (solo Play, CA3, CF3) except its animation: 11 clips **not published**; target switching and the egg drop in his lane not seen in Play | Same (CA3, CF3) |
| Candy critters Mochimiau, Canelin, Flanin, Mielita, Gato Repartidor (shared brain `WildboundBeastCandyCritter`, model service `WildboundCandyCritterService`) | Done (solo Play, CC6) except tell colours (CC7) and text lines (CC8); live animation is another task; place not saved | `odd/tasks/wildbound-candy-critters.md` |
| Duquesa Burbuja | Seated scenery only (no brain) | Same |
| Caramelo nests (11 live: C1-C5 Gomibu, R1-R4 Tortidragon, E1-E2 Flanfuria; L1 event-only, off) | Done (solo Play, CE1); session-only switch, restore with `Builder.syncNests` if the place is reopened unsaved | Same (CE1) |
| Caramelo pets (farm-only, rarity hatch 15 / 45 / 60 s, scaled rig, FarmIdle and walk clips) | Done (solo Play with Gomibu, CE2); Flanfuria and Tortidragon farm models suite only | Same (CE2) |
| Candy egg looks (nest, backpack, cradle, Gomibu bob) | Done (solo Play, CG1); a Flanfuria egg in the pack or cradle and a dropped candy egg not seen in Play | Same (CG1) |
| Return portals (Caramelo arch (772, -3), forest arch (-28, -132); 5 s calm, 2 s channel, 30 s rest, the egg rides along) | Done (solo Play at the Caramelo arch, CE3); a full channel at the forest arch not seen | Same (CE3); `odd/tasks/wildbound-2-0.md` (T08a, T08b) |
| Persistence (schema 6, session lock) | Done in the memory store (Studio API access is off) | `docs/mechanics/wildbound-persistence.md`; `odd/tasks/wildbound-playtest-fixes.md` (PF4, PF5) |
| Persistent base farm (schema 5) | Done (solo Play rebuild on respawn, PF4); leave and rejoin covered by suites only | `odd/tasks/wildbound-playtest-fixes.md` (PF4) |
| Farm places 5 and 6 for sale (camp upgrades `farmSlot5` 400 and `farmSlot6` 900 Esencia, in order) | Done (solo Play: the purchases, BP4c); a fifth and sixth creature placed in the farm suite only | `odd/tasks/wildbound-balance-pass.md` (BP4c) |
| "Liberar": release a duplicate hatched creature for 4 Esencia (bag panel, two taps) | Done (solo Play, BP4a) | Same (BP4a) |
| Base incubation fills the bought slots only (1, then 2 and 3 with the upgrades), no longer a free eight | Done (solo Play with one slot, BP4b); two or three slots suite only | Same (BP4b) |
| Roulette state (schema 6: free spin, pity, paid spins) | Done (suites RT-29, SV-23; the counter seen in Play, PF5); rejoin suite only | Same (PF5) |
| Hub roulette (station at (265, 14), server roll, atomic spend, odds shown, Rara+ pity 10) | Done (solo Play, PF5); the prompt's own trigger not used (the probe called the same server path) | Same (PF5) |
| Creature hotbar (a Tool per creature, own-pad deposit, rebuild on respawn) | Done (solo Play, PF3) | Same (PF3) |
| Farm wander and pad lift | Done (solo Play with a stand-in model, PF6; the lift suite only); a hatched creature's real model wandering seen only for Gomibu (CE2) | Same (PF6, sunken-creature follow-up) |
| Creature hotbar icons (Lumipol + 3 Caramelo) | Done (IC, 2026-11-16): the thumbnail form loads the user-owned images; solo Play saw the four hotbar slots loaded | Same (PF7); `odd/tasks/wildbound-caramelo.md` (CE2) |
| Treadmill (17 levels, walk 16 to 50; level L+1 needs L+1 laps and only a level-up lap pays 5 Esencia (BP1); a carrier's share is taken of at most a 24 walk (BP2)) | Done (solo Play, PF2, BP1, BP2) | `odd/tasks/wildbound-playtest-fixes.md` (PF2); `odd/tasks/wildbound-balance-pass.md` (BP1, BP2) |
| Incubation (15 s x rarity, one slot), newborn to the hotbar | Done | `docs/mechanics/wildbound-incubator.md`; PF3 |
| Gloves with random stats | Done | odd doc NS7 |
| Skill tree (8 nodes, 5 live), upgrades, seals, capsule, ward totem, luck totem | Done | `docs/mechanics/wildbound-economy-p0.md` |
| Tutorial card | Done (shown again, owner decision 2026-11-14; solo Play) | `odd/tasks/wildbound-suite-repair.md` |
| Hub v1: 8 bases, assignment, delivery, incubator, glove bench, treadmill, safe disc, spawn pads | Done; the collection platform stays empty (HB-T5, owner decision) | `docs/maps/wildbound-hub.md` |
| Hub v2-r90 geometry (showcases, shop circles, chest stations, bank zones, 2 cradles, 35 lights) | Prepared (built per `b45bdba`, no rules) | `docs/design/wildbound-hub-expansion.md` |
| Hub ambience and night lamp scale | Design only | Same |
| Shops on ground circles | Design only | Same, section 5 |
| Base chest roulette | Superseded by the hub roulette (user decision 2026-11-14) | Same, section 6 |
| Glove recycling | Design only | Same, section 8 |
| Hatch timer ladder, second cradle | Design only | Same, section 7 |
| Vitrina (showcase) rules | Design only | Same, section 4 |
| Open-world placement and roads | Prepared | `docs/maps/wildbound-open-world-biomes.md` |
| Wildbound 2.0 balance config (`WildboundBalance`, T01) | Prepared (no live script requires it; its own suite ran, 25/0 after CF3) | `odd/tasks/wildbound-2-0.md` |
| 2.0 economy simulator (T05b) and roulette table (T09a) | Done as offline tools (`05afd5e`, `52bfb4d`); reports in `docs/balance/` | Same |
| Pradera Arcoíris map | Prepared (builder); its square now holds Caramelo | `docs/design/wildbound-biome-pradera.md` |
| Pradera species, Huevo Real, Molinillo, Relampino | Design only | Same |
| Pantano, Cementerio, Abismo, Montañas Heladas, Tierras Volcánicas, Cuevas de Roca | Prepared (primitive builders); their light presets and gameplay phase are live (CA4, CF1) | `docs/maps/wildbound-open-world-biomes.md` |
| Corral, trophies, breeder level, daily gift, cosmetics, farm income | Design only (no farm income: the no-AFK-income rule) | `docs/mechanics/wildbound-hub-systems.md` |
| Robux offers | Design only (nothing purchasable) | `docs/design/wildbound-economy-and-offers.md` |
| Viper, Pouncer, Gargoyle, Mire mesh import and animations | Not started in game (models uploaded) | `assets/models/beasts/README.md` |
| Lumipol generated art (parent and egg) | Done (templates kept only if the place is saved) | odd doc (Lumipol generated model, LG pass) |
| Two-player and three-player tests | Not started | `docs/testing/wildbound-next-verification.md` |
| Phone tests and performance capture | Not started | Same |
| Real DataStore test | Not started (Studio API access off) | `docs/mechanics/wildbound-persistence.md` |
| Publishing | Not started (needs explicit approval) | — |

---

## 14. Open decisions, known risks and what the user must do

### 14.1 What the user must do

| # | Action | Why |
| --- | --- | --- |
| U9 | **Publish the 22 Tortidragon and Don Glaseon clips to group 465694015**: in Edit, `ServerStorage.WildboundPublishClips.<Creature>.<Clip>`, right click > Save to Roblox, Creator = the group; give the 22 ids to the assistant (steps in Spanish in `odd/tasks/wildbound-caramelo.md`, "CE0: qué es publicar las animaciones"). Or grant the assistant group upload or the `asset-permissions:write` scope | The universe 10774749224 belongs to the group; user-owned animations cannot load there, so both creatures move in their rest pose. `Clips.IDS` is empty until then |
| U10 | **No longer needed for the hotbar (IC, 2026-11-16, the `rbxthumb://` form loads).** Optional, for a clean asset owner: share or re-upload the 4 hotbar icons for the group: 121561289565386 (Lumipol), 130041727906990 (Gomibu), 106158128076232 (Flanfuria), 85016154045779 (Tortidragon); either share each image with the experience / group 465694015 in the Creator Hub, or upload the PNGs in `assets/icons/` to the group and give the new ids | The client logs "Requester does not have permission for Asset"; the hotbar shows no image |
| U1 | **Save the place** (File > Save, plus a downloaded backup copy) once the current Studio writer finishes | Several sessions ended without saving. Unsaved and lost on close: Edit-built geometry, the Lumipol templates (U2), the Caramelo nest and portal switches, the clips folder for U9, the Tortidragon and Don Glaseon prefabs and raw imports in `ServerStorage` |
| U2 | Save the place so the generated Lumipol templates persist (same save as U1) | Until saved, a new session loses the templates and every Lumipol falls back to the primitive look |
| U7 | **Set `MaxPlayers` to 8 in Game Settings** (decision Q5) | It is still 60 (HB-W8); a ninth player has no base |
| U3 | Enable Game Settings > Security > Enable Studio Access to API Services | Lets the real data store be tested; today Studio falls back to memory |
| U4 | Run a two-player (or three-player) Studio test ("Clients and Servers") | Bat knockback, pickup races, re-targeting, other bases refusing, shared beast visibility (SC0.6), Don Glaseon's target switching and per-player Siluetas are only unit-tested |
| U5 | Test on a phone (or Device Simulator) | Touch buttons, the roulette panel, the portal bar, layouts and frame time are unmeasured |
| U6 | Push and set an upstream (`git push -u`), if wanted | `origin/codex/wildbound-first-playable` is still at `0be136d`; every later commit (all of 2026-11-14 and 2026-11-15) is local only; no upstream is configured |
| U8 | Decide whether to import the four uploaded beast models (Viper, Pouncer, Gargoyle, Mire) into the place (and later upload their 25 clips) | Proxies are used until then |

### 14.2 Decisions taken for the user, to review

On 2026-11-14 and 2026-11-15 the user asked agents not to stop for decisions. Each decision taken that way is listed, numbered, in its feature doc; review them there rather than here:

- `odd/tasks/wildbound-caramelo.md`, sections "Decisions taken for the user" (1 to 18: per-place phase, Dusk off, Nightbloom wilt, wave gate, bat immunity, the sleeping boss) and "(continued)" (19 to 39: clips folder, nest species and guardians, one egg per nest, farm-only pets, icons, portal threats and numbers, landing; 40 to 46: candy egg looks).
- `odd/tasks/wildbound-kids-beasts.md`: every Nube and Abeja number is PROPUESTA; the Abeja window offset is open.
- `odd/tasks/wildbound-scuttler.md`, "Design choices (SC0)" and the SC1 to SC8 correction (radius 150, cap 4, pulse cooldown 9 to 5 s).
- `odd/tasks/wildbound-playtest-fixes.md`, "Review follow-up" (the trained walk also applies while carrying, decided "Que valga con huevo") and PF5 (the live roulette table: Esencia 40 / materials 60, 11 prizes).
- `odd/tasks/wildbound-2-0.md`, T05b evidence (every ASSUMED simulator threshold) and the T03, T05b, T08a, T10 titles.

### 14.3 Open decisions

| # | Decision |
| --- | --- |
| D13 | Retune the threats for the trained walk: a walker reaches 50 (about 34 carrying), against La Silueta's night hunt 17 and the parents' 19 (PF2 follow-up) |
| D14 | Treadmill laps pay 5 Esencia each and level for free: confirm, since `antiAfk.timeBasedGrants = 0` forbids time-based grants (the same question as ECO-20, the base-zone loop on a timer) |
| D15 | Farm income: none today; the 2.0 simulator finds an idle farm pays as much as exploring (T04) |
| D16 | Scuttler `PulseCooldownSeconds` 5 (accept, or grow `PressureMemorySeconds` instead) |
| D17 | Caramelo event: the Legendaria nest L1 stays off while no Caramelo event exists; the Abeja window offset |
| D18 | Nube and Abeja inside Caramelo: their sites are Pradera offsets in the square Caramelo now fills; keep them there, move them or retire them |
| D19 | Tuning DT1: the steal holds were settled by EC (2026-11-15). Still open, a gameplay call: `Eggs.PICKUP_DELAY` and `Eggs.PICKUP_HOLD` (schema 0.4, applied in Play, vs module 0.25) and `Incubator.HATCH_SECONDS` (schema 5, applied in Play, vs module 15) |
| D20 | What a player loses on defeat (2.0 open decision; today carried eggs are lost, Esencia is not) |
| D21 | The 2.0 balance pack: wire `WildboundBalance` or retire the parts the live game decided otherwise (2.0 walk 21, 240/60/300/120 cycle, roulette weights) |
| D22 | Whether the 2.0 roulette's Esencia prizes stay (the old base-chest design excluded them; the live table pays 40 %) |
| D3 | Second incubator cradle: free or the 250 Esencia step |
| D5 | HB2: where the shared camp stations (registration, chest, skill tree, trophies) go in the hub |
| D2 | Hub radius: stay at 90 (v2-r90) or grow (100 needs Refugio FA2 moved; 120 after placement work) |
| D7 | Non-carrier bat hit and whether the attacker waits longer to pick up the egg they knocked loose (NP-W1; the knockback now ragdolls every target) |
| D8 | Beast hits before the first paid trip (NB-W2); a Silueta hunt ending a running beast (NB-W1) |
| D9 | Failed load: offer "Intentar de nuevo" at camp (NS-W2) |
| D11 | Pradera scope (D3 in the combined plan): its open questions in section 14 of its doc |
| D12 | Robux offers: none are approved; the offer list must be redone for gloves before any discussion |

Closed since the last snapshot: D1 (treadmill: the user chose large gains, PF2), D4 (chest price and content: the hub roulette, PF5; Rara+ pity kept), D10 (Arrullo eggs: Épica and Legendaria, wired), the day cycle split (superseded by CA4), the wave board, safe banner, tutorial card, collection limit, parent chase, wind-up and bough eggs (suite-repair decisions).

### 14.4 Known risks

| Risk | Note |
| --- | --- |
| Unsaved place | A Studio crash or close loses the Caramelo switches, the clips folder, the new prefabs and every Edit-only change (U1) |
| Animations | Tortidragon and Don Glaseon play no clip until U9; their tells are still drawn on the floor |
| First-minute distance | The wave-1 guaranteed egg is placed within 70 studs of (182, 17), the W trail's forest end (EV-W5); Play showed it 31 studs off; the trail nest T1 holds two eggs (LG4); island 1 is about 290 studs out; the "quick first action" hypothesis is still untested |
| Multiplayer | Every PvP, race, shared-visibility and per-player system is verified solo only |
| Trained speed | A trained walker outruns every chaser (D13) |
| Nightbloom income | Always rollable in the forest since CA4; a node wilts after 300 s; the economy effect is not measured (CF1 decision 7) |
| Damage under streaming | Earlier checks found real strikes blocked while `StreamingEnabled` is on (`odd/tasks/wildbound-first-playable.md:133`); the dwell gate is the current answer; not re-measured with two clients |
| Performance | Hub v2-r90 (35 lights), Caramelo (736 parts plus rigged beasts and farm pets), six biome builders, per-player Siluetas and beasts, 5 Hz bystander snapshots: no phone MicroProfiler capture |
| Script size | `WildboundServer.server.luau` sits at Luau's top-level local limit (NH-W13 caught 226 in a CG1 draft); new helpers and requires go in the `Heist` table |
| Teammate's lock zone | `WildboundServer`, `WildboundState`, `WildboundEggCarry` and the `SistemaSonriente` folders are shared with a teammate in Team Create; Studio-ahead edits keep appearing and must be pulled before any write |
| Lost sources | The Gomibu and Flanfuria Blender sources and their build record are not in the repo; a mesh fix would need a new source and upload |
| Simulator coverage | The 2.0 simulator uses ASSUMED profiles and thresholds; real play has not measured income |

---

## 15. Glossary (Spanish game terms)

| Term | Meaning |
| --- | --- |
| Esencia | The only currency (code `ember`) |
| Huevo / cría | Egg / baby creature |
| Común, Rara, Épica, Legendaria | Rarity tiers |
| Robar | To steal (an egg) |
| Entregar huevo | Deliver the egg (base pedestal) |
| Incubar / incubadora / eclosionar | Incubate / incubator / hatch |
| Compañero | Companion (the creature that follows you) |
| Mochila | Backpack / inventory (bag of trip items) |
| Bolsa / bolsita | Bag / pouch (trip loot; pouch holds materials) |
| Sello | Seal (protects one bag item; also the capture's final tap) |
| Cápsula | Capsule (secures one item at the shelter) |
| Tótem / Tótem de la suerte | Ward totem / luck totem (raises one spawn's rarity) |
| Guantes | Gloves (random-stat equipment) |
| Entrenamiento / Entrenar | Training / the treadmill |
| Impulso | Burst (short speed dash, retired: the dodge replaced it) |
| Esquiva perfecta | Perfect dodge (live, Z) |
| Bate | Bat (PvP knock) |
| Arrullo | Lullaby (rare-egg minigame; off since AR, 2026-11-15, returns later) |
| Ruleta / Tirada gratis | The hub roulette / the one free spin |
| Granja / barra | The base farm / the creature hotbar |
| Portal del Caramelo, "Volver a la base" | A return portal and its prompt |
| Caramelo; Gomibú, Flanfuria, Tortidragón, Don Glaseón | The candy biome; its three species and its boss |
| Linterna / Pulso | Flashlight / companion pulse |
| Esconderse | To hide |
| Refugio | Temporary safe circle (moves each wave) |
| Campamento | The old camp (west of the forest) |
| Plaza central / base | The hub / a personal base |
| Base libre / Base de <nombre> | Free base / <name>'s base |
| Vitrina | Showcase plinth (planned) |
| Cofre del explorador | Explorer's chest (the superseded base-chest roulette) |
| Garantía | Pity guarantee (the roulette's Rara+ every 10) |
| Reciclar | Recycle (planned, gloves) |
| Oleada | Wave (300 s) |
| Huevo especial | The 20-minute biome event egg |
| Atardecer / anochecer / noche / amanecer | Dusk / nightfall / night / dawn (code phases Day, Dusk, Night, Dawn) |
| Niebla, Escarcha, Ceniza, Floración | Forest variants: Mist, Frost, Ash, Bloom |
| Efectos suaves | Reduced effects setting |
| La Silueta | The forest's stalker |
| Víbora / Viper, Araña / Pouncer | The two global beasts (warnings call them "víbora" and "araña") |
| Gárgola / Gargoyle, Mire | Biome beasts for Cementerio and Pantano (config only) |
| La Nube Gruñona, La Abeja Reina | The Pradera's grumpy cloud and queen bee (design) |
| ¡Estás a salvo! | "You're safe!" (base banner, kept hidden by owner decision) |
| Fogbark, Glowmoss, Nightbloom | Materials (English names kept in code and strings) |

---

## 16. Outdated documents and doc/code contradictions

| Document | What is outdated |
| --- | --- |
| `docs/wildbound-roadmap.md` (2026-11-07) | Says all game code is untracked, the game is session-only, damage and DataStore are not built; its milestones predate Nest Heist. The night ladder it discusses was removed by the user; 99 Nights is an aesthetic reference only |
| `docs/wildbound-readiness.md` | Already marked superseded at its top; refers to `newPlace1` and a stop before gameplay |
| `docs/design/wildbound-combined-plan.md` sections 1 to 5 | Superseded where section 6 decides (Burst replaced, bat numbers, hub size, persistence approved) |
| `docs/design/wildbound-hub-expansion.md` | Plans radius 100 and 474 parts; the built variant is v2-r90 (radius 90, about 470 parts); "nothing built" is no longer true for the geometry; its base-chest roulette (section 6) is superseded by the hub roulette |
| `docs/maps/wildbound-hub.md` sections 2 and 5 | Describe the preview hub at (0, 0, 600) and the camp link (its header says so) |
| `docs/maps/wildbound-open-world-biomes.md` section 4 "Order" | Says the forest shift moves the forest to (-330, 600); HF-T3 kept the forest at (-18, -3) and moved the hub to (282, -3). It does not know the Meadow square is Caramelo now |
| `docs/design/wildbound-biome-pradera.md` | Still the Pradera's plan; the Meadow square holds `Candy_Bioma_v1` (`Replaces = PraderaArcoiris`) |
| `docs/design/wildbound-economy-and-offers.md` | Assumes DataStore is forbidden, four equipment pieces (Guantes I, Botas I, Chaleco, Amuleto) and a 20-node tree; code has saved progress, random-stat gloves and an 8-node tree |
| `docs/mechanics/wildbound-economy-p0.md` and `WildboundEconomyConfig.luau` | The live config (synced) has bag 12, creatures 8/14/20/28/42 and eggs 4/10/16/24/36 Esencia; the 14 State_Test drift cases and the old export tests still expect the document's values |
| `assets/models/beasts/README.md` | Says nothing has been imported or uploaded; `uploaded-assets.json` records the four models uploaded (still not imported into the place) |
| `docs/mechanics/wildbound-new-mechanics.md` and `odd/tasks/wildbound-new-mechanics.md` | Say the five mechanics are unwired with unrun suites; the teammate wired all five in Studio and the sync (`ad569e9`) brought them into the repo |
| NS-W4/NS-W5 in the odd doc | Say a maxed player walks 17 to 17.5; the walk cap is 50 since PF2 |

### Feature docs that contradict the code or each other

Recorded, not guessed; the code and the git log win.

1. **`odd/tasks/wildbound-scuttler.md`:** SC0 to SC8 each say "Not committed" and the next step says "Commit SC0 ... SC1 to SC7"; the work is committed (`9ca6f5a`, `b1364de` for SC0, `c64db0d` for SC1 to SC8). SC0 stays unticked only for the two-player check.
2. **`odd/tasks/wildbound-kids-beasts.md`:** "Nothing is committed"; Nube, Abeja and the biome-preference change are in `f9c7ef4`. It also says the kids beasts were checked in "the place's own WildboundPradera map"; that square is Caramelo now, and whether Nube and Abeja still fit it is open (D18).
3. **`odd/tasks/wildbound-2-0.md`:** T01.5, T05b.5 and T09a.5 say "Commit pending" / "Commits: none"; they are `2145d6c`, `05afd5e` and `52bfb4d`. T03 (hotbar), T04 (farm), T06 (treadmill) and T09b (roulette wiring) are listed as blocked on the teammate's stage 1, but PF2 to PF5 built them after the user allowed lock-zone edits ("Sí, tocalos"). T02 (240/60/300/120) is superseded by CA4. T09a still says the final pity confirmation is open; the playtest-fixes doc records the user's "pity Rara+ kept".
4. **`odd/tasks/wildbound-suite-repair.md`:** its "Cycle decision" (keep 300/60/300/60) is reversed by CA4. Its "Still open, not asked" list (K2, EL13, HB-T5, roulette pity and location) was answered in the same file and in PF5. Its DT1 line reads "EggCarry 0.8 vs schema 0.5"; the code has the reverse (`WildboundEggCarry.luau` `STEAL_HOLD = 0.5`, `WildboundTuningSchema.luau` default 0.8), as the PF2 and CF2 records say.
5. **`odd/tasks/wildbound-caramelo.md`:** CA4 says the Caramelo nests are `Enabled = false` and its next step says to enable them "when the user wants Caramelo eggs"; CE1 enabled them (`Layout.NESTS_ENABLED = true`, 11 live nests, session-only). CA5 (close: overview rows, commit) is unticked although CA1 to CA4 are committed; this snapshot covers its overview part.
6. **This overview before this snapshot:** called the five mechanics Prepared, the bat 12 s with a stumble, the Burst live, one egg per player, a 0.8 s steal, a 90 s hatch and walk cap 16; the live code differs on each (rows updated above).

### Code and a current decision disagree (code is what runs today)

1. **Death:** the Nest Heist brief says death loses only the carried egg; code also keeps the older trip rule (unwarded bag items lost, 20 % of pouch materials). Still open as D20.
2. **Hub radius:** the hub-expansion design says 100; `Rules.HUB_RADIUS` and the deployed builder use 90.
3. **Push status:** origin is at `0be136d`; nothing since is pushed and no upstream is configured.
4. **Steal hold:** decision NH1 and the tuning schema say 0.8 s; the live `EggCarry` runs 0.5 / 0.75 s (DT1, deferred).
5. **One egg in the arms:** the Nest Heist brief carries one egg; the live `EggCarry` lets a player carry several up to the bag capacity (12). The one-backpack fix (PF1) is a single pack visual, not a one-egg rule.
6. **Anti-AFK:** `antiAfk.timeBasedGrants = 0`, yet a treadmill lap pays 5 Esencia and the base-zone loop runs on a timer (ECO-20) (D14).
7. **Speed contract:** Q9 kept the walk under La Silueta's night hunt; PF2 (user: "como Steal an Egg, muchísimo") lets a trained walk reach 50 (D13).
8. **2.0 balance:** the proposed `WildboundBalance` uses treadmill walks 16 to 21 and a 240/60/300/120 day; the live game trains to 50 and has no day/night cycle since CA4 (2026-11-15); since CF3 `Balance.LIVE.dayCycle` describes that fixed world (a 300 s wave clock with a 10 s Warning window, and each biome's gameplay phase and light mood from `WildboundBiomeLight`). `Balance.conflicts()` lists each gap (`Balance.LIVE`). No live script requires `WildboundBalance`.
