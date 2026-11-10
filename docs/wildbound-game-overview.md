# Wildbound: master game overview

**Snapshot:** 2026-11-10, branch `codex/wildbound-first-playable` at `6edfa21`. Written offline from the repository only: no Studio, Play or device session was run for this document. Where code and an older document disagree, this document follows the code and says so (section 16). Anything not checked against code or a recorded Play result is marked **(unverified)**.

**Status words used everywhere below**

| Word | Meaning |
| --- | --- |
| **Done** | Code exists, is wired into the running game, its Studio suites passed and a solo Studio Play check recorded it (`odd/tasks/*.md`). Never means "tested with two players" or "tested on a phone" unless stated |
| **Prepared** | Code or geometry exists in the repository (pure module, builder, suite) but is **not wired** into the running game, and its Luau suites have **not run** |
| **Design only** | Written in a design document; no code |
| **Not started** | Neither design detail nor code |

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
| Session shape | Short expeditions (simulated median 183 to 208 s, floor 180 s) from a persistent base; a 12-minute day cycle; 5-minute waves; a 20-minute biome event |
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
5. Carry the egg in your arms (walk 11 while carrying). Escape with sprint (x1.45, 4 s of stamina), Burst ("Impulso"), hiding spots, Refugios.
6. Survive La Silueta (in the fog territory), Viper and Pouncer (anywhere outside safe zones), and other players' bats.
7. Deliver at your own base's pedestal ("Entregar huevo", E) or incubator ("Incubar huevo", R), or at the old camp chest/incubator. Pays Esencia by tier plus a trip base.
8. Incubate (90 s, one slot, server Unix time, continues offline). The hatchling joins your collection and follows you as a companion with a light if none is out.
9. Spend Esencia: gloves, treadmill, seals, upgrades, skills, luck totem. Saved progress keeps everything banked.

### 2.3 Session goals

| Goal | Source |
| --- | --- |
| Bank eggs and creatures before dusk/night | Day cycle 720 s; Night is when La Silueta is fastest (17) |
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
| Walk-speed training | Built but gives nothing today (walk cap 16 = base walk; open decision) |
| Chest roulette, recycling, shops, showcases, hatch ladder, second cradle | Prepared (geometry) / Design only (rules) |
| Corral that pays Esencia over time, trophies, breeder level, daily gift | Design only (`docs/mechanics/wildbound-hub-systems.md`) |
| New biomes with their own beasts | Pradera: builder + full design; six others: primitive builders only |

---

## 3. World map

One open world. Coordinates are place studs (x east, z south). Source of truth: `src/wildbound/WildboundWorldRules.luau` and `assets/maps/open-world/biome-placement-v1.json` (regenerated for the hub at (282, -3), radius 90).

### 3.1 Overview

| Area | Centre (x, z) | Size | Yaw | Root model | Status |
| --- | --- | --- | ---: | --- | --- |
| **Hub (Plaza central)** | (282, -3) | safe disc r 90 | 0 | `WildboundHub` | **Done** (v1 features); v2-r90 geometry built (see 3.2) |
| **Bosque de la Silueta** (forest) | (-18, -3) measured | 400 x 400 | 0 | `WildboundP0` | **Done, the only playable biome** |
| Pradera Arcoíris | (612, -3) | 400 | 0 | `WildboundPradera` | Builder + full design; no gameplay code |
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
| Beast | La Silueta (per player), plus the global Viper and Pouncer |
| Biome variants | Niebla, Escarcha, Ceniza, Floración rotate every wave (colour, fog scale, spawn weights, ambient bed; no gameplay numbers) |

### 3.4 The other biomes

| Biome | Look (kit/design) | Beast | Species | Status |
| --- | --- | --- | --- | --- |
| Pradera Arcoíris | Pastel meadow, giant mushroom roofs, sun circles, pond, La Colmena glade; `PA_` primitive parts | **La Nube Gruñona** (permanent: sky-ray sight 40, chase 14, fixed 6-stud lightning ring, 1.0 s telegraph, kids rule: no damage, no stack loss); **La Abeja Reina** (20-minute event only: wakes for the Huevo Real, guards it 5 minutes, sleeps) | Chispín (Común), Musgón (Común), Esponjín (Rara), Hongolín (Épica), Relampino (Legendaria, event only) | Builder `tools/build-wildbound-pradera-map.luau` + complete design; **no gameplay code** |
| Pantano (living forest) | Swamp, stream (WalkSpeed 10 as data only) | Mire (2 points, 1/80, damage 40) | None defined | Builder only; Mire is config only |
| Cementerio (cryptic ruins) | Ruins, glyphs, stairs | Gargoyle (2 points, 1/100, damage 25) | None defined | Builder only; Gargoyle is config only |
| Abismo | Chasms, 10-stud drop floor with no way back | None | None | Builder only |
| Montañas Heladas | Overhangs, `YetiHomeMarker` | None defined | None | Builder only |
| Tierras Volcánicas | Vents (data only) | None | None | Builder only |
| Cuevas de Roca | 26 tunnel modules, rockfall lanes (data only), El Vigía chain markers | None defined | None | Builder only |

The six non-forest kits were **never uploaded**; their builders draw primitive fallbacks and pick up templates from `ServerStorage.WildboundAssets.<Kit>` if one ever exists. No game code reads the biome tags yet; zones are still decided by `Rules.zone` only.

---

## 4. Core mechanics

Numbers are code defaults (most are live-tunable through the Studio dev tuning panel, `WildboundTuningSchema.luau`, `docs/testing/wildbound-tuning.md`).

| # | Mechanic | Rule and key numbers | Code | Status |
| --- | --- | --- | --- | --- |
| 4.1 | **Steal** | Hold the egg prompt: normal (Común, Rara) `STEAL_HOLD` 0.8 s (0.6 to 1); Épica, Legendaria, event egg `RARE_HOLD` 1 s. The **server measures the hold** (`EggCarry.holdComplete`): continuous, begun at most 3 s ago, at least the effective hold minus `HOLD_ALLOWANCE` 0.35 s (0.05 to 0.5). Refusal: "Mantén presionado un poco más." Glove "Robo rápido" shortens it, floor 0.6 s | `WildboundEggCarry.luau`, `WildboundServer.server.luau` | Done (NH1, HB-T7, HF-T2) |
| 4.2 | **Carry** | One `EggCarry` record per egg, states `InNest`, `Carried`, `Dropped`, `Secured`, `Despawning`; one egg per player ("Ya llevas un huevo en brazos."); a 1.2 x 1.6 x 1.2 egg welded 1.4 studs in front of the root (massless, no collision); walk 11 while carrying | `WildboundEggCarry.luau` | Done (NH2) |
| 4.3 | **Parents** | A steal wakes the island at once. Chase 19 studs/s, 14 s, leash 35. Charge: after 1 s of chase, within 12 studs, a **0.8 s** tell ("¡Va a embestir! Sal de su línea."), dash 40 studs/s to 4 studs past (max 18), hit within 3 studs; a miss leaves it exposed 1 s ("¡Falló! Aprovecha y huye."); 6 s between charges. Close swing wind-up raised 0.45 to **0.8 s** (Q1). A parent re-targets a new carrier only within 24 studs. A taken nest refills only after the chase ends | `WildboundIsland.luau` | Done (NH3, NH8, HF-T4) |
| 4.4 | **Dodge** | Today: **Burst "Impulso"** (Z / R3 / touch button): 0.8 s at walk x1.7, cap 28, cooldown 6 s, server-validated. Decided replacement **"Esquiva perfecta"**: press in the last 0.35 s of a parent, Viper, Pouncer or Silueta telegraph (never shorter than 0.8 s) to cancel that hit and get a 1 s x1.35 boost (cap 26); early/late/empty press 1.2 s cooldown; 4 presses in 1 s lock 2 s | `WildboundStamina.luau` (Burst, live); `WildboundDodge.luau` | Burst: Done. Esquiva perfecta: **Prepared** (not wired, suite unrun) |
| 4.5 | **Bat (PvP)** | Everyone has a bat (left click, DPadRight, "Bate" touch). Server picks the target: 6 studs flat, 60 degrees either side, 4 studs height, clear chest-to-chest ray. Live: cooldown **12 s** (spent on a miss), carrier stumbles 0.45 s at speed 2 and **drops the egg** (anyone may take it after 0.4 s), non-carrier 0.2 s tap, immunity **6 s**; no damage. Decided (Q4, Q4b): cooldown 5 s, 1.2 s ragdoll, push 45 + lift 20 (max flight 24 studs), immunity 3 s | `WildboundBat.luau` (live), `WildboundBatKnock.luau` | Live bat: Done (solo only). Knockback: **Prepared** |
| 4.6 | **Drop and pickup** | `Heist.dropEgg` reasons Death, Hit, Strike, Leave, Bat. Lands 2 studs behind on the ground; pickable after 0.4 s with a 0.4 s hold within 10 studs; first valid request wins; abandoned 30 s then fades ("Tu huevo se perdió en el bosque."). Parents fetch a loose egg home inside their leash. In a safe zone only death or leaving drops it | `WildboundEggCarry.luau` | Done (NH5); two-player race unit-tested only |
| 4.7 | **Death** | The carried egg falls where you died (for anyone) before the defeat. Banked eggs, registered creatures, Esencia, upgrades, skills, gloves are never lost. The older expedition rule still applies to the rest of the trip: unwarded bag items are lost and pouch materials lose 20 % (`loss.rateBasisPoints` 2000, 10 % with the reinforced pack) | `WildboundState.luau`, `WildboundEconomyConfig.luau` | Done (NH7) |
| 4.8 | **Banking / delivery** | Own base pedestal or own base incubator (server range 8 + 2), or the camp chest/incubator. Banks the whole bag with the egg, secures the egg once, pays `eggEmberByTier` (Fog 8, FogFar 10, Territory 11, Heart 14) plus the trip base (4 Esencia when the trip lasted 45 s, reached 60 studs from camp and found something). Notice: "¡Huevo a salvo en tu base! ... +8 de Esencia." | `WildboundHubStations.luau`, `WildboundServer.server.luau` | Done (NH6, HB-T3) |
| 4.9 | **Auto-banking zone** | Walk into your own base: egg into a free cradle, bag banked, big banner "¡Estás a salvo!" (2.5 s), hysteresis 2 studs, 4 Hz server step | `docs/design/wildbound-hub-expansion.md` section 7 | Zones built as geometry (v2-r90); rule **Design only** |
| 4.10 | **Incubation** | One slot, 90 s (`Incubator.HATCH_SECONDS`, tunable 10 to 900), 12-stud range, server Unix time (hatches after rejoin). A hatch with no companion out equips the newborn ("...y ahora te acompaña."). Planned: hatch ladder 10 / 20 s for the first two eggs, then Común 40, Rara 75, Épica 150, Legendaria 300; second cradle | `WildboundIncubator.luau` | 90 s single slot: Done. Ladder, 2 slots: Design only |
| 4.11 | **Companions** | One companion out; follows without collisions; PointLight 1.2 brightness, 12 range (tunable); "Guardar"/"Equipar" in the Mochila. Lumipol pulse (Q) reveals La Silueta (see 4.15) | `WildboundRefuge.luau`, `WildboundWorld.client.luau` | Done (NS4) |
| 4.12 | **Cría capture** | A cría (or a wild Lumipol) uses the calm ring: stay inside a 4.5-stud ring (server 5) that orbits, fill calm 4.5 s (floor 4 s), then a seal tap in a moving band (X / R2). Capture is noisy (ring 32, seal 48 hearing radius) | `WildboundCaptureSession.luau` | Done |
| 4.13 | **Arrullo** (rare-egg minigame, Q2b) | Hold to raise / release to drop a marker inside a drifting calm zone on a vertical bar; progress starts 35, win at 100, lose at 0 or after 18 s. Zone Rara 0.30, Épica 0.24, Legendaria 0.18 of the bar. Server simulates; client sends only "hold"/"release" (20/s max). Replaces the ring for rare eggs | `WildboundArrullo.luau` | **Prepared** |
| 4.14 | **Day cycle, dusk, night** | 720 s: Day 360, Dusk 72, Night 216, Dawn 72; a server never opens in Night. Night raises La Silueta's speed and senses in the fog only, and doubles beast odds. Planned **Dusk rule** (Q11): two warnings ("Está anocheciendo..." and "La noche llega en 20 s.") and a small beast buff during Dusk only (speed x1.08, odds x1.25, detection x1.1) | `WildboundWorldRules.luau`, `WildboundDusk.luau` | Cycle: Done. Dusk rule: **Prepared** |
| 4.15 | **Fog, flashlight, pulse** | Fog rectangle; client atmosphere per phase and biome variant; free flashlight (F, 12 s cooldown) needs facing; registered companion pulse (Q, 30 s) does not; reveal 4 s, range 55, LOS; reveals are shared and non-additive | `WildboundAtmosphere.luau`, `WildboundWorldRules.tryAbility` | Done |
| 4.16 | **Stalk sightings** | Client-only glimpses of La Silueta behind a trunk at dusk, night, dawn: every ~50 s (x0.6 carrying, x0.8 far from home, x2 with "Efectos suaves"), at most 3 per evening, 18 to 36 studs away, gone when looked at, approached, after 4 s or when the real one hunts. Never in the camp or hub (+10 studs) | `WildboundHudView.luau`, `WildboundFear.client.luau` | Done (SS1 to SS3, HF-T1) |
| 4.17 | **Sprint and stamina** | Walk 16; sprint x1.45 (cap 24), pool 100, drain 25/s (4 s), regen 10/s moving, 15/s still, x2 in a Refugio. Sprint is loud (hearing 30) | `WildboundStamina.luau` | Done |
| 4.18 | **Hiding spots** | H to hide; a hidden player is never acquired; rustle noise 10 | `WildboundHide.luau` | Done |
| 4.19 | **Random world** | Spawns live 300 s then move; respawn 90/150/240/360 s by rarity; at most 4/3/2/1; 40 % eggs; a held prompt pins its spawn | `WildboundSpawnClock.luau` | Done (RW2) |
| 4.20 | **Waves, Refugios, event** | Wave 300 s: reroll spawns, 2 to 3 random Refugios (r 12, stamina x2, chases end), board reset. Event: first at 300 s, then every 1200 s, 300 s window, one Legendaria Tizoncillo egg within 45 studs of La Silueta's home, one claimant | `WildboundWaveClock.luau` | Done (RW3 to RW5) |
| 4.21 | **Luck totem** | Crafted (15 Esencia, 6 Fogbark, 6 Glowmoss, hold 1), placed 30+ studs from camp for 60 s, radius 40: the next spawn inside rolls one tier up (and one spawn is lured in). Single use. Today it is **session-only**; Q10 persistence (schema 4, cap 5) | `WildboundGear.luau`, `WildboundTotemRecord.luau` | Totem: Done. Persistence: **Prepared** |
| 4.22 | **Gathering** | 24 gather slots (outside, fog, territory; hold 3/4/6/9 s), Fogbark, Glowmoss, Nightbloom (night only, fog/territory) | `WildboundGatherField.luau`, `WildboundGather.server.luau` | Done |

---

## 5. Beasts and La Silueta

### 5.1 La Silueta (the forest's stalker)

| Item | Value | Source |
| --- | --- | --- |
| One per player | Each player has their own hunter (cap `MAX_HUNTERS` 8); it only ever targets its owner; others see it faint | `WildboundHunters.luau`, `WildboundWorld.server.luau` |
| Where | Only in the fog territory: home (0, -85), territory leash 80, chase leash 100, give-up distance 100 | `WildboundWorldRules.luau` |
| States | Patrol, Suspicious, Investigate, Search, Retreat (brain); Alert, Hunt, Telegraph (fight) | `WildboundGuardianBrain.luau` |
| Speed by phase | Hunt: Day 13, Dusk/Dawn 15, **Night 17**; detection 21 / 26 / 30; chase 12 / 15 / 18 s | `Brain.PROFILES` |
| Walk vs her | Walk capped at 16 (Q9) so walking never outruns a night hunt; sprint 23.2 always does | `WildboundTraining.WALK_CAP`, `WildboundStamina` |
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
| Multipliers | Night x2, far from base (over 150 studs from both camp and hub) x1.2, dangerous zone (fog or territory) x1.5, long expedition (180 s outside safety) x1.3, storm x1 (no weather) |
| Cooldowns | Global 15 s after any encounter; respawn grace 10 s; per species (Viper 35 s, Pouncer 40 s) |
| La Silueta | Outside the budget; no beast starts while that player's Silueta hunts or telegraphs (`SiluetaActive`) |
| Release | Exactly once per encounter (death, safe zone, escape, end, error) |
| Visibility | Each beast and its telegraph are drawn **only on the target's client** (`BeastEvent:FireClient`); the server never listens to that remote |

### 5.4 The four beasts

| Beast | Points / odds | Behaviour and telegraph | Hit | Status |
| --- | --- | --- | --- | --- |
| **Viper** (global) | 1 / 1:45 | Spawns 35 to 70 studs out, stalks to 18 to 30, sidesteps up to 1.5 s for a clear lane, windup 1.15 s with a red lane (4.5 x 32) that follows 0.7 s then locks; dash 60 studs/s; walls cut the dash; up to 3 attacks, 32 s; "¡Una víbora va a embestir! Sal de la línea roja." | 35 | **Done** (Part proxy, 38 parts) |
| **Pouncer** (global) | 1 / 1:55 | Hunts to 20 to 34, red circle r 6.5 at your predicted spot, follows 0.25 s then freezes; telegraph 1.3 s; leap 0.75 s; 2 jumps (cap 3); "¡Una araña va a saltar! Sal del círculo rojo." | 40 | **Done** (Part proxy, 36 parts) |
| **Gargoyle** (Cementerio) | 2 / 1:100, cooldown 60 | Statue that awakens (clips exist) | 25 | Config only (`PLAYABLE` excludes it; biome refused) |
| **Mire** (Pantano) | 2 / 1:80, cooldown 50 | Submerged swamp ambusher | 40 | Config only |

A beast hit knocks the carried egg loose; health drops only in private damage mode after the first paid trip (NB-W2). The parents (4.3) and La Silueta are separate from the director.

### 5.5 Kids biome beasts (design only)

La Nube Gruñona and La Abeja Reina: see 3.4 and `docs/design/wildbound-biome-pradera.md` sections 5 and 6. Their consequence is the "kids rule": no damage even in private mode, no defeat screen, a hit parks one item for 120 s, a second hit is a 3 s gust back to the gate.

---

## 6. Creatures and collection

| Species | Rarity | Where | Look (stand-in) | Art |
| --- | --- | --- | --- | --- |
| **Lumipol** | Común | Island 1, random spawns, the tutorial | Mint glowing blob, 3 x 2 x 2.4 | MeshGen1 template (`ServerStorage.WildboundAssets.LumipolMeshGen`); **meshes refused** ("Requester does not have permission for Asset") so the primitive look shows |
| **Cortezón** | Común | Island 2, random | Mossy bark shell | Primitive; rig exported (`assets/exports/species/SP_Cortezon`), not uploaded |
| **Cestillo** | Rara | Island 3, random | Long-necked wader | Primitive; rig exported |
| **Polvilla** | Épica | Island 4, random | Dusty moth | Primitive; rig exported |
| **Tizoncillo** | Legendaria | Island 5, the biome event egg | Glowing ember log | Primitive; rig exported |

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
| Trip base (extraction) | 4, if the trip lasted 45 s, reached 60 studs from camp and found at least one new item |
| Creature by tier | Safe 6, Fog 10, FogFar 12, Territory 14, Heart 22 |
| Egg by tier (delivery) | Fog 8, FogFar 10, Territory 11, Heart 14 |
| First steal bonus | 4 |
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
| Treadmill levels 1 to 4 | 30, 48, 77, 123 Esencia (base 30, growth 1.6) | +0.25 walk per level, **capped at 16 = no gain today** |

### 7.3 Gloves (random stats)

Rarity weights Común 60, Rara 28, Épica 10, Legendaria 2; 1 to 4 distinct stats within a share of each cap (Común 25 to 50 %, Rara 35 to 60 %, Épica 50 to 80 %, Legendaria 70 to 100 %). One worn at a time ("Ponerte"). No special abilities (the old Chaleco and Amuleto were removed).

| Stat (Spanish) | Cap | Effect |
| --- | --- | --- |
| Velocidad | 3 % | Walk, but under the walk cap 16 (so no effect today) |
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
| Cofre del explorador (chest roulette at each base) | 45 Esencia; gloves 72 % (Común 36, Rara 24, Épica 9, Legendaria 3), materials 15, seal 8, luck totem 5; odds shown before paying; **pity at 10** (an Épica+ glove); 4.5 s roulette, "Saltar" after 1.5 s; refuses before charging when gloves are full; no Esencia reward; Esencia only | Chest circles built as geometry; rules **Design only** (`docs/design/wildbound-hub-expansion.md` section 6; the `chests` block is not in the economy config yet) |
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
| Modules | `WildboundRecord` (schema **3**), `WildboundPersistence` (session lock), `WildboundSave` (joins state and store), `WildboundStoreRoblox` (the only module naming `DataStoreService`) | Done (NS1, NS2) |
| Lock | Session lock in key metadata, taken in the same `UpdateAsync` that reads and migrates; stale after 300 s; 3 attempts with 1, 2, 4 s backoff plus jitter | Done |
| Failed or locked load | Plays a fresh profile that is **never written**; notice "No pudimos cargar tu progreso. Tus datos están a salvo. Juegas sin guardar..." | Done (Play: stored value byte-equal) |
| Saves | Autosave about every 60 s only when the saved fields changed, waits while the request budget is under 4; on leave; `BindToClose`; key list snapshotted before saving (join/leave mid-save safe) | Done |
| Saved | Banked eggs, registered creatures, companion, Esencia, banked materials, consumables, upgrades, skills, bond, incubator (Unix times), training levels, gloves | Done |
| Never saved | The bag, the pouch, an egg in the arms, a carried or dropped creature, the trip, the luck totem (today) | Done |
| Schema 4 (luck totems) | `WildboundTotemRecord.luau` | Prepared |
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
| Burst "Impulso" | Z | R3 | "Impulso" button (also the ready indicator: "Impulso 6") |
| Bat "Bate" | Left click (never on UI) | DPadRight | "Bate" button ("Bate 12") |
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
| Wave board and event banner | "Oleada 3 · 4:00", "Huevo especial: Tizoncillo · 4:51"; compact banners on phones |
| Mochila panel | Pending, banked and registered sections; Equipar/Guardar; Incubar |
| Camp/board screen | Upgrades, skills, gloves ("Ponerte"), crafts; opened by the base glove bench too |
| Save line | "Progreso guardado." or "Solo esta sesión." |
| Fear presentation | Heartbeat, vignette, FOV kick, red flash (client tunables in "Cámara y sensaciones") |
| Known text issue | The objective still reads **"Roba y vuelve al campamento."** although players spawn and deliver at the hub (`WildboundText.luau:350`, open HF question 3) |
| Planned | Inventory tabs (Guantes, Objetos, Materiales), shop bottom sheets, chest roulette, "¡Estás a salvo!" banner, Arrullo bar, "Esquivar" button: design or prepared only |

Phones: layouts are designed for 375 x 667 portrait and 667 x 375 landscape with 44 px targets, but **no phone or Device Simulator test has been recorded** for the Nest Heist features.

---

## 10. Art and assets

| Asset | Kind | In game today | Ids / files |
| --- | --- | --- | --- |
| Forest kit | Real meshes (six Model packages) | Yes | `assets/exports/forest-kit/forest-kit-upload-manifest.json` |
| La Silueta v3 | Real rigged model + 4 animations | Yes | Model 123768633946912; animations listed in 5.1; `docs/assets/silueta-animation-upload-manifest.json` |
| Lumipol (MeshGen1) | User's AI-generated model | Template present, **meshes refused by asset permissions**; primitive fallback shows | `assets/exports/lumipol-meshgen1-spec.json` |
| Viper, Pouncer, Gargoyle, Mire | Rigged FBX, 25 clips in all | **Models uploaded, not in the game**: no code or place references the ids; Viper and Pouncer show as Part proxies; an imported model named exactly `Viper` or `Pouncer` in `ReplicatedStorage.WildboundBeasts.Models` replaces a proxy with no code change | Viper 77139866631513, Pouncer 87204464156490, Gargoyle 113241144174504, Mire 105993486058377 (`assets/models/beasts/uploaded-assets.json`, moderation Approved) |
| Beast animations | 25 FBX clips | **Not uploaded** | `assets/models/beasts/*_anim_*.fbx` |
| Other species (Cortezón, Cestillo, Polvilla, Tizoncillo) | Rigs exported | Primitive stand-ins | `assets/exports/species/` |
| Hub, camp, bat, egg, Refugios, totems | Primitive parts by design | Yes | Builders in `tools/` |
| Pradera and six other biome kits | FBX exported; primitive Luau fallbacks | Not built in the place **(unverified)** | `assets/exports/<biome>-kit/` |
| Sounds | Existing catalogue ids only (`WildboundAudioCatalog`), reused slots for beasts, bat and burst | Yes | — |

What needs the user: fix MeshGen1 permissions; approve and import the beast models into the place (3D importer or by id) and later the 25 clips; approve any upload of the six biome kits.

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
| `ServerScriptService` | `WildboundServer` (inventory, heist, hub stations wiring; at the 200-local limit: new helpers go in the `Heist` table), `WildboundWorld` (La Silueta, fair strike, cycle), `WildboundBeasts` (director and encounters), `WildboundHub`, `WildboundGather`, `WildboundTuning`, `WildboundWorldGuard`; pure modules (`WildboundState`, `WildboundEggCarry`, `WildboundBat`, `WildboundIsland`, `WildboundWorldRules`, `WildboundFairStrike`, `WildboundBeastDirector`, `WildboundPersistence`, `WildboundSave`, `WildboundStoreRoblox`, ...) |
| `ReplicatedStorage` | Shared pure modules (`WildboundText`, `WildboundBeastConfig`, `WildboundWaveClock`, `WildboundStamina`, `WildboundGear`, `WildboundHudView`, ...), `WildboundNetwork`, `WildboundBeasts.Models` |
| `StarterPlayerScripts` | `WildboundClient`, `WildboundWorld.client`, `WildboundCapture.client`, `WildboundFear.client`, `WildboundAudio.client`, `WildboundBeasts.client`, `WildboundTuning.client`, `WildboundStart.client` |
| `ServerStorage` | `WildboundHubBuilder`, `WildboundAssets` (ForestKit, SiluetaV3, LumipolMeshGen), test suites, Studio-only probes |

Source: `src/wildbound/` (84 Luau files), tests `tests/` (81 files), generators and Python tests `tools/`.

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
| Studio suites | 70 suites, **1442 passed, 0 failed** on fresh module clones (HF-T5, the last Studio run). Runner: a temporary `ServerStorage.WildboundFreshRunnerTmp`, removed after each session |
| Unrun suites | `WildboundArrullo_Test`, `WildboundDodge_Test`, `WildboundBatKnock_Test`, `WildboundTotemRecord_Test`, `WildboundDusk_Test` (no offline Luau runtime; RED/GREEN pending Studio) |
| Python | `python -I -B -m unittest discover -s tools -p "test_*.py"`: 1153 run, 1 known failure (`test_lumipol_v2.test_v1_files_are_unchanged`), 28 skipped (last recorded); later EV-W1/EV-W2 commits added placement and builder tests (50/0 placement, 26/0 builder suites recorded) |
| Deploy manifest | `tools/deploy_manifest.py` maps each repo file to its Explorer path (pinned by `tools/test_deploy_manifest.py`); every Studio deploy is checked by Adler-32 and length against the repo; the five new mechanics modules are mapped but **not deployed** |
| Mode | Strict TDD; one Studio writer at a time; verify the Studio instance and place and get the user's confirmation before any edit (`AGENTS.md`) |
| Play checks | Solo Studio Play only, in the background (no two-client session, no Device Simulator); see each phase's table in `odd/tasks/wildbound-capture-extraction-horror.md` |
| Place state | Recent sessions did **not save the place**; the hub, link removal and tree removal happen at server start, so the place can be rebuilt from git plus the deployed sources |

---

## 13. Status matrix

| Feature | Status | Detailed doc |
| --- | --- | --- |
| Forest map, fog, relief, kit art | Done | `docs/maps/wildbound-p0.md`, `docs/maps/silueta-forest-concept-v1.md` |
| Day cycle 720 s | Done | `docs/mechanics/wildbound-world.md` |
| La Silueta per player, fair strike, mark-then-defeat | Done (damage path blocked by the streaming gate in older checks; private mode only) | `docs/mechanics/wildbound-fair-strike.md`, `docs/mechanics/wildbound-guardian.md` |
| La Silueta moves (lunge, fake retreat, glare, scream) | Done | `docs/mechanics/wildbound-guardian.md` |
| Flashlight, companion pulse, reveal | Done | `docs/mechanics/wildbound-awareness.md` |
| Stalk sightings | Done | `odd/tasks/wildbound-capture-extraction-horror.md` (Stalk sightings) |
| Hiding spots, Refugios | Done | `docs/mechanics/wildbound-delivery-d.md` |
| Islands and parents (wake, chase, charge, 0.8 s swing) | Done | `docs/mechanics/wildbound-expedition-islands.md` |
| Random world, spawn clock, waves, biome event, variants | Done | Same odd doc (Random world) |
| Fast steal, server-measured hold, egg in arms, drop/pickup, death drop | Done | `docs/mechanics/wildbound-capture.md`, odd doc Nest Heist Phase 1 |
| Burst "Impulso" | Done (to be replaced) | odd doc NH4 |
| Bat PvP (12 s, stumble) | Done (solo-verified) | odd doc Phase 2 |
| Beast director, Viper, Pouncer (proxies) | Done | `docs/mechanics/wildbound-beasts.md` |
| Gargoyle, Mire | Design only (config) | `docs/design/beast-pack/` |
| Persistence (schema 3, session lock) | Done (memory store in Studio) | `docs/mechanics/wildbound-persistence.md` |
| Incubation 90 s, companion, light | Done | `docs/mechanics/wildbound-incubator.md` |
| Gloves with random stats | Done | odd doc NS7 |
| Treadmill | Done but no effect (walk cap 16) | odd doc NS5, HF-T4 |
| Skill tree (8 nodes, 5 live), upgrades, seals, capsule, ward totem, luck totem | Done | `docs/mechanics/wildbound-economy-p0.md` |
| Hub v1: 8 bases, assignment, delivery, incubator, display, glove bench, treadmill, safe disc, spawn pads | Done | `docs/maps/wildbound-hub.md` |
| Hub v2-r90 geometry (showcases, shop circles, chest stations, bank zones, 2 cradles, 35 lights) | Prepared (built per `b45bdba`, no rules) | `docs/design/wildbound-hub-expansion.md` |
| Hub ambience and night lamp scale | Design only | Same |
| Shops on ground circles | Design only | Same, section 5 |
| Chest roulette (45 Esencia, odds shown, pity 10) | Design only | Same, section 6 |
| Glove recycling | Design only | Same, section 8 |
| Auto-banking "¡Estás a salvo!" and auto incubation | Design only | Same, section 7 |
| Hatch timer ladder, second cradle | Design only | Same, section 7 |
| Vitrina (showcase) rules | Design only | Same, section 4 |
| Arrullo | Prepared | `docs/mechanics/wildbound-new-mechanics.md` |
| Esquiva perfecta | Prepared | Same |
| Bat knockback (5 s, ragdoll, 3 s immunity) | Prepared | Same |
| Luck totem persistence (schema 4) | Prepared | Same |
| Dusk warnings and buff | Prepared | Same |
| Open-world placement and roads | Prepared | `docs/maps/wildbound-open-world-biomes.md` |
| Pradera Arcoíris map | Prepared (builder) | `docs/design/wildbound-biome-pradera.md` |
| La Nube Gruñona, La Abeja Reina, Pradera species | Design only | Same |
| Pantano, Cementerio, Abismo, Montañas Heladas, Tierras Volcánicas, Cuevas de Roca | Prepared (primitive builders) | `docs/maps/wildbound-open-world-biomes.md` |
| Corral, trophies, breeder level, daily gift, cosmetics | Design only | `docs/mechanics/wildbound-hub-systems.md` |
| Robux offers | Design only (nothing purchasable) | `docs/design/wildbound-economy-and-offers.md` |
| Beast mesh import and animations | Not started in game (models uploaded) | `assets/models/beasts/README.md` |
| Lumipol MeshGen1 art | Blocked (asset permissions) | odd doc MeshGen1 |
| Two-player and three-player tests | Not started | `docs/testing/wildbound-next-verification.md` |
| Phone tests and performance capture | Not started | Same |
| Real DataStore test | Not started (Studio API access off) | `docs/mechanics/wildbound-persistence.md` |
| Publishing | Not started (needs explicit approval) | — |

---

## 14. Open decisions, known risks and what the user must do

### 14.1 What the user must do

| # | Action | Why |
| --- | --- | --- |
| U1 | **Save the place** (File > Save, plus a downloaded backup copy) once the current Studio writer finishes | Several sessions ended without saving; Edit-built geometry (hub v2-r90, any biome builds) lives only in the open place |
| U2 | **Fix MeshGen1 asset permissions** (check the meshes' and textures' permissions in Creator Hub, or re-create them under your account) | Every Lumipol shows the primitive fallback ("Requester does not have permission for Asset") |
| U3 | **Enable Game Settings > Security > Enable Studio Access to API Services** | Lets the real data store be tested; today Studio falls back to memory |
| U4 | **Run a two-player (or three-player) Studio test** ("Clients and Servers") | Bat hits, pickup races, re-targeting, other bases refusing, per-player beasts and Siluetas are only unit-tested |
| U5 | **Test on a phone** (or Device Simulator) | Touch buttons (Impulso, Bate), layouts, frame time with ~470 hub parts and 35 lights are unmeasured |
| U6 | **Push to GitHub** (private repo `guguss1/wildbound`) | `origin/codex/wildbound-first-playable` last points at `06a4c99` (2026-11-09, per the local remote-tracking ref); **112 local commits are not pushed**; the branch has no upstream configured |
| U7 | Set the place's `MaxPlayers` to 8 (decision Q5) | It is still 60 (HB-W8) |
| U8 | Decide whether to import the four uploaded beast models into the place (and later upload the 25 clips) | Proxies are used until then |

### 14.2 Open decisions

| # | Decision |
| --- | --- |
| D1 | Treadmill: retarget (sprint, stamina, steal, Dodge recovery) or remove, since walk cap 16 makes it and the glove's Velocidad stat useless |
| D2 | Hub radius: stay at 90 (v2-r90) or grow (100 needs Refugio FA2 moved; 120 after placement work) |
| D3 | Second incubator cradle: free or the 250 Esencia step |
| D4 | Chest price and content (45 Esencia, odds, pity 10) |
| D5 | HB2: where the shared camp stations (registration, chest, skill tree, trophies) go in the hub |
| D6 | The HUD objective text now that players start at the hub |
| D7 | Non-carrier bat hit: keep the 0.2 s tap or do nothing (NP-W1); whether the attacker waits longer to pick up the egg they knocked loose |
| D8 | Beast hits before the first paid trip (NB-W2); Dusk counting as night (NB-W3, now partly answered by the prepared Dusk rule); a Silueta hunt ending a running beast (NB-W1) |
| D9 | Failed load: offer "Intentar de nuevo" at camp (NS-W2) |
| D10 | Rare eggs: the Arrullo replaces the 1 s hold for Épica/Legendaria/event eggs, but the code has no ring on eggs today (NH-W1); confirm which eggs get Arrullo |
| D11 | Pradera scope (D3 in the combined plan): its open questions in section 14 of its doc |
| D12 | Robux offers: none are approved; the offer list must be redone for gloves before any discussion |

### 14.3 Known risks

| Risk | Note |
| --- | --- |
| First-minute distance | The new hub spawn is about 400 studs from island 1 and the wave-1 egg (2.1); the "quick first action" hypothesis is untested from the hub |
| Spawn facing | New characters face east (towards the Pradera, which has no gameplay), while the only playable biome is west **(unverified intent)** |
| Multiplayer | Every PvP, race and per-player system is verified solo only |
| Damage under streaming | Earlier checks found real strikes blocked while `StreamingEnabled` is on (`odd/tasks/wildbound-first-playable.md:133`); the dwell gate is the current answer; not re-measured with two clients |
| Performance | Hub v2-r90 (35 lights), six biome builders (about 3,300 parts with roads), per-player Siluetas and beasts: no phone MicroProfiler capture |
| Script size | `WildboundServer.server.luau` is at Luau's 200-local limit (NH-W13) |
| Simulator coverage | The economy simulator models neither eggs, islands, random spawns, PvP nor beasts; real income per trip is likely higher than modelled |
| Asset access | The Lumipol art depends on a permission fix the code cannot make |
| Lost place work | Unsaved place plus a single Studio writer means a Studio crash loses Edit-only geometry |

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
| Impulso | Burst (short speed dash, to be replaced) |
| Esquiva perfecta | Perfect dodge (planned replacement) |
| Bate | Bat (PvP knock) |
| Arrullo | Lullaby (planned rare-egg minigame) |
| Linterna / Pulso | Flashlight / companion pulse |
| Esconderse | To hide |
| Refugio | Temporary safe circle (moves each wave) |
| Campamento | The old camp (west of the forest) |
| Plaza central / base | The hub / a personal base |
| Base libre / Base de <nombre> | Free base / <name>'s base |
| Vitrina | Showcase plinth (planned) |
| Cofre del explorador | Explorer's chest (planned roulette) |
| Garantía | Pity guarantee (planned chest line) |
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
| ¡Estás a salvo! | "You're safe!" (planned base banner) |
| Fogbark, Glowmoss, Nightbloom | Materials (English names kept in code and strings) |

---

## 16. Outdated documents and doc/code contradictions

| Document | What is outdated |
| --- | --- |
| `docs/wildbound-roadmap.md` (2026-11-07) | Says all game code is untracked, the game is session-only, damage and DataStore are not built; its milestones predate Nest Heist. The night ladder it discusses was removed by the user; 99 Nights is an aesthetic reference only |
| `docs/wildbound-readiness.md` | Already marked superseded at its top; refers to `newPlace1` and a stop before gameplay |
| `docs/design/wildbound-combined-plan.md` sections 1 to 5 | Superseded where section 6 decides (Burst replaced, bat numbers, hub size, persistence approved) |
| `docs/design/wildbound-hub-expansion.md` | Plans radius 100 and 474 parts; the built variant is v2-r90 (radius 90, about 470 parts); "nothing built" is no longer true for the geometry |
| `docs/maps/wildbound-hub.md` sections 2 and 5 | Describe the preview hub at (0, 0, 600) and the camp link (its header says so) |
| `docs/maps/wildbound-open-world-biomes.md` section 4 "Order" | Says the forest shift moves the forest to (-330, 600); HF-T3 kept the forest at (-18, -3) and moved the hub to (282, -3) |
| `docs/design/wildbound-economy-and-offers.md` | Assumes DataStore is forbidden, four equipment pieces (Guantes I, Botas I, Chaleco, Amuleto) and a 20-node tree; code has saved progress, random-stat gloves and an 8-node tree |
| `assets/models/beasts/README.md` | Says nothing has been imported or uploaded; `uploaded-assets.json` records the four models uploaded (still not imported into the place) |
| `docs/mechanics/wildbound-new-mechanics.md` (wiring list) | Accurate as a plan; none of it is done |
| NS-W4/NS-W5 in the odd doc | Say a maxed player walks 17 to 17.5; HF-T4 lowered the walk cap to 16 |

Contradictions where code and a current decision disagree (code is what runs today):

1. **Bat:** decisions Q4/Q4b say cooldown 5 s, ragdoll, immunity 3 s; `WildboundBat.luau` runs 12 s, a 0.45 s stumble and 6 s immunity (`WildboundBatKnock.luau` is not wired).
2. **Burst:** Q3b replaces it with Esquiva perfecta; the Burst is still live (Z, "Impulso") and `WildboundDodge.luau` is not wired.
3. **Death:** the Nest Heist brief says death loses only the carried egg; code also keeps the older trip rule (unwarded bag items lost, 20 % of pouch materials).
4. **Hub radius:** the hub-expansion design says 100; `Rules.HUB_RADIUS` and the deployed builder use 90.
5. **Training:** the treadmill and the glove Velocidad stat still cost Esencia and roll, but the walk cap 16 equals the base walk, so they give nothing.
6. **First egg near camp:** `FIRST_EGG_RADIUS` 70 is measured from the camp, not from the hub where players now spawn.
7. **HUD objective:** "Roba y vuelve al campamento." while delivery is at the base.
8. **Push status:** the brief says nothing was pushed; the local remote-tracking ref shows `origin/codex/wildbound-first-playable` at `06a4c99` (2026-11-09), so an older state was pushed and the last 112 commits were not.
