# Wildbound

**Nest Heist with horror**, for Roblox. Sneak out of a bright, safe hub into a dark, misty forest, steal a creature egg from a guarded nest, and carry it home in your arms while its parents charge, La Silueta stalks you and other players try to knock it loose with a bat. Hatch it into a glowing companion that lights your way. Risk lives in the trip; what is banked at home is never lost.

Audience: Roblox players roughly 8 to 14 who like light horror (dark forest, a tall silent stalker, no gore). Player strings are Spanish; code and docs are English. The game is **unpublished** and runs only in a Studio test place. Nothing is purchasable.

Source of truth for everything below: [docs/wildbound-game-overview.md](docs/wildbound-game-overview.md) (snapshot 2026-11-10). Where an older doc disagrees, the overview wins.

## Core loop

1. Leave the hub (no PvP, beasts or strikes inside it).
2. Find a nest: a fixed island nest (five islands, rising risk) or a random spawn tagged Común, Rara, Épica or Legendaria.
3. Steal the egg with a short hold. The parents wake, chase and charge with a visible tell.
4. Carry the egg in your arms. Escape with sprint, Burst ("Impulso"), hiding spots and Refugios while La Silueta, Viper, Pouncer and other players' bats threaten you.
5. Deliver at your base's pedestal or incubator. Earn Esencia, the only currency.
6. Incubate (90 s, continues offline). The hatchling joins your collection and follows you as a light-carrying companion.
7. Spend Esencia on gloves, upgrades, seals, skills and totems. Progress is saved.

Details: overview sections 1 to 7.

## Current status

Status words follow the overview:

- **Done**: wired into the running game, its Studio suites passed and a **solo** Studio Play check recorded it. Never means tested with two players or on a phone.
- **Prepared**: code or geometry exists in the repository but is **not wired** into the game, and its Luau suites have **not run** in Studio (built, not verified).
- **Design only**: written in a design doc, no code.

### Done (solo Studio Play only)

| Area | Features |
| --- | --- |
| World | Fog forest map, fog, relief and kit art; 720 s day cycle; random world, spawn clock, 5-minute waves, 20-minute biome event, forest variants |
| La Silueta | Per-player stalker, fair-strike rule, mark-then-defeat, lunge, fake retreat, glare, scream, stalk sightings. Damage runs only in private test mode |
| Counterplay | Flashlight, companion pulse and reveal, hiding spots, Refugios, sprint with stamina, Burst "Impulso" (to be replaced) |
| Heist | Islands with parents (wake, chase, charge, 0.8 s tell); fast steal with server-measured hold; egg in arms, drop, pickup, death drop |
| PvP and beasts | Bat PvP (12 s, stumble); beast director with Viper and Pouncer |
| Progression | Saved progress (schema 3, session lock; memory store in Studio only); 90 s incubation, companion and light; random-stat gloves; skill tree (8 nodes, 5 live), upgrades, seals, capsule, ward totem, luck totem |
| Hub v1 | 8 personal bases, assignment, delivery, incubator, display, glove bench, treadmill, safe disc, spawn pads. The treadmill gives nothing today (walk cap 16) |

### Prepared (in the repo, not wired, suites not run in Studio)

- Five new mechanics as pure modules: Arrullo (rare-egg minigame), Esquiva perfecta (replaces Burst), bat knockback, luck totem persistence (schema 4), dusk warnings. See [docs/mechanics/wildbound-new-mechanics.md](docs/mechanics/wildbound-new-mechanics.md).
- Hub v2-r90 geometry (showcases, shop circles, chest stations, bank zones, two cradles, 35 lights) with no gameplay rules.
- Open-world biome placement and roads; Pradera Arcoíris builder; primitive builders for Pantano, Cementerio, Abismo, Montañas Heladas, Tierras Volcánicas and Cuevas de Roca.

### Design only

- Gargoyle and Mire (config only), Pradera beasts and species (La Nube Gruñona, La Abeja Reina).
- Hub ambience, shops on ground circles, chest roulette, glove recycling, auto-banking, hatch ladder, second cradle, showcase rules.
- Corral, trophies, breeder level, daily gift, cosmetics.
- Robux offers. Nothing is purchasable; `monetization = "none"`.

### Not started

- Beast animations in game (the four beast models are uploaded).
- Two- and three-player tests, phone tests and performance capture.
- Real DataStore test (Studio API access is off).
- Gate F1, the human fun test ([docs/testing/wildbound-f1-test-kit.md](docs/testing/wildbound-f1-test-kit.md) is prepared, never run).
- Publishing (needs explicit approval).

### Changes recorded after the overview snapshot

These come from the last sections of [odd/tasks/wildbound-capture-extraction-horror.md](odd/tasks/wildbound-capture-extraction-horror.md) (EV-W2 to EV-W5 and LG1 to LG4, 2026-11-10). They were checked in solo Studio Play only, and the place was **not saved** by those sessions.

- The hub v2-r90 geometry, Pradera, the six biomes and the roads were built in Edit and seen in Play (EV-W1, EV-W2). The overview still lists them as Prepared; they persist only if the place is saved.
- The uploaded Viper and Pouncer models now appear next to their proxies, in rest pose with no animations (EV-W3).
- HUD wording points to the base instead of the camp; some bag, capture and registration lines still name the camp (EV-W4).
- Hub spawns face west toward the forest, and the first wave's common egg is forced near the forest edge by the hub (EV-W5).
- A generated Lumipol parent and egg model replace the blocked MeshGen1 art, and a new trail nest sits near the hub's west trail (LG1 to LG4).
- Last recorded counts: 70 Studio suites, 1454 passed, 0 failed (the five new-mechanics suites skipped); Python 1223 run, 1 known failure, 28 skipped.

## Open decisions

From overview section 14.2. Only the owner can answer these.

| # | Decision |
| --- | --- |
| D1 | Treadmill: retarget it or remove it (walk cap 16 makes it useless) |
| D2 | Hub radius: stay at 90 or grow |
| D3 | Second incubator cradle: free or 250 Esencia |
| D4 | Chest price, odds and pity |
| D5 | Where the shared camp stations go in the hub |
| D6 | HUD objective text now that players start at the hub |
| D7 | Bat hit on a non-carrier; pickup delay for the attacker |
| D8 | Beast hits before the first paid trip; Dusk as night; Silueta hunt ending a beast |
| D9 | "Intentar de nuevo" after a failed load |
| D10 | Which rare eggs get the Arrullo |
| D11 | Pradera scope |
| D12 | Robux offers: none approved; the offer list must be redone first |

## What's next

Owner actions (overview 14.1):

1. Save the place and keep a downloaded backup copy. Edit-built geometry and the new Lumipol templates exist only in the open place until then.
2. Enable Studio Access to API Services so the real DataStore can be tested.
3. Run a two- or three-player Studio test, then a phone or Device Simulator test.
4. Set the place's `MaxPlayers` to 8 in Game Settings (it cannot be set from scripts).
5. Decide whether to import beast animations (25 clips, not uploaded).

Agent work once the owner allows it: wire and run the five prepared mechanics in Studio with observed RED and GREEN, then run the F1 fun test with real people. The F2 kit (wave W16) is pending, and integrating the expansion in Studio (W17) needs upload consent ([odd/tasks/wildbound-waves.md](odd/tasks/wildbound-waves.md)). The roadmap's gates still frame release: people must find the core fun (F1) before beta and release; agents never mark F1 passed.

Known risks (overview 14.3): every PvP and per-player system is verified solo only; no phone performance capture; `WildboundServer.server.luau` is at Luau's 200-local limit; the economy simulator does not model eggs, islands, PvP or beasts; an unsaved place can lose Edit-only geometry.

## Documentation map

Read in this order: overview, then the roadmap for gates and history, then the ODD task file for the feature, then its design doc. Design docs are **proposals** unless the overview marks the feature as Done.

**Outdated** = flagged in overview section 16. **Stale header** = the doc's own status line is older than the overview's status.

### Start here

| Doc | What it is |
| --- | --- |
| [docs/wildbound-game-overview.md](docs/wildbound-game-overview.md) | Master overview: game, loop, world, mechanics, economy, architecture, status matrix (13), open decisions (14), glossary (15), outdated docs (16) |
| [docs/wildbound-roadmap.md](docs/wildbound-roadmap.md) | Milestones M0 to M11, gates F1 and F2, blockers, owner decisions. **Outdated** (2026-11-07, predates Nest Heist and saved progress) |
| [docs/wildbound-readiness.md](docs/wildbound-readiness.md) | Early setup audit of references and skill sources. **Outdated** (marked superseded) |
| [docs/agent-routing.md](docs/agent-routing.md) | Model and effort routing for agents |
| [docs/skill-packs.md](docs/skill-packs.md) | The four guarded project skills and their source packs |

### Design (`docs/design/`)

| Doc | What it is |
| --- | --- |
| [wildbound-combined-plan.md](docs/design/wildbound-combined-plan.md) | Current direction: Nest Heist core, beast pack, phases, user decisions (section 6). Sections 1 to 5 **outdated** where section 6 decides |
| [wildbound-expansion-bible.md](docs/design/wildbound-expansion-bible.md) | Expansion proposal: biomes, species, guardians, Blender specs |
| [wildbound-beast-spawn.md](docs/design/wildbound-beast-spawn.md) | Beast spawn by Risk and threat budget as a tune of the existing director; guardian / biome / global taxonomy, beast cards and owner decisions (approved 2026-11-11) |
| [wildbound-biome-pradera.md](docs/design/wildbound-biome-pradera.md) | Pradera Arcoíris, the kids' east biome, with La Nube Gruñona (chosen 2026-11-10) |
| [wildbound-biome-2-proposal.md](docs/design/wildbound-biome-2-proposal.md) | Earlier second-biome proposal; its recommendation was replaced by the Pradera decision |
| [wildbound-open-world-hub.md](docs/design/wildbound-open-world-hub.md) | One open world: hub in the centre, forest west, Pradera east |
| [wildbound-open-world-gaps.md](docs/design/wildbound-open-world-gaps.md) | Gaps, contradictions and build order across the open-world docs |
| [wildbound-hub-expansion.md](docs/design/wildbound-hub-expansion.md) | Larger hub, shops, chest, auto-banking. **Outdated** (plans radius 100; built geometry is r90) |
| [wildbound-economy-and-offers.md](docs/design/wildbound-economy-and-offers.md) | Economy synthesis and Robux offer design. **Outdated** (assumes no DataStore, old equipment, 20-node tree) |
| [wildbound-integration-plan.md](docs/design/wildbound-integration-plan.md) | Plan for importing expansion assets (wave W17) |
| [wildbound-asset-sources.md](docs/design/wildbound-asset-sources.md) | Research on Roblox-compatible forest assets and licences |
| [wildbound-forest-aesthetic-reference.md](docs/design/wildbound-forest-aesthetic-reference.md) | Forest look reference (99 Nights is aesthetic only) |
| [wildbound-parked-ideas.md](docs/design/wildbound-parked-ideas.md) | Ideas parked for later, not approved |
| [wildbound-pi1-steal-from-silueta.md](docs/design/wildbound-pi1-steal-from-silueta.md) | Proposal for parked idea PI-1, awaiting approval |
| [economy-concepts/skills.md](docs/design/economy-concepts/skills.md) | Economy concept: skill tree first (input to the synthesis) |
| [economy-concepts/idle.md](docs/design/economy-concepts/idle.md) | Economy concept: corral as idle income |
| [economy-concepts/offers.md](docs/design/economy-concepts/offers.md) | Economy concept: offer design first |
| [kids-biome-concepts/bee.md](docs/design/kids-biome-concepts/bee.md) | Kids' biome concept with La Abeja Reina (now the biome event beast) |
| [kids-biome-concepts/mimo.md](docs/design/kids-biome-concepts/mimo.md) | Candidate kids' biome: Bosque Golosina (not chosen) |
| [kids-biome-concepts/storm.md](docs/design/kids-biome-concepts/storm.md) | Candidate kids' biome: Lomas Pompón (not chosen) |

#### Beast pack (`docs/design/beast-pack/`, Spanish)

Source pack for the four beasts. Viper and Pouncer are built; Gargoyle and Mire are config only (overview section 13).

| Doc | What it is |
| --- | --- |
| [00_LEEME_PRIMERO.md](docs/design/beast-pack/00_LEEME_PRIMERO.md) | Read first: what the pack contains and the order to use it |
| [00_INTEGRACION_DE_BESTIAS.md](docs/design/beast-pack/00_INTEGRACION_DE_BESTIAS.md) | Master integration prompt for all four beasts |
| [01_VIPER.md](docs/design/beast-pack/01_VIPER.md) | Viper: telegraphed charge |
| [02_POUNCER.md](docs/design/beast-pack/02_POUNCER.md) | Pouncer: leap and impact zone |
| [03_GARGOYLE.md](docs/design/beast-pack/03_GARGOYLE.md) | Gargoyle: living statue of the Cementerio |
| [04_MIRE.md](docs/design/beast-pack/04_MIRE.md) | Mire: half-submerged stalker of the Pantano |
| [PLAN_DE_PRUEBAS.md](docs/design/beast-pack/PLAN_DE_PRUEBAS.md) | QA plan (multi-client tests) |
| [CONFIG_INICIAL.json](docs/design/beast-pack/CONFIG_INICIAL.json) | Initial beast config values |
| [COMO_USAR_ESTAS_IMAGENES.md](docs/design/beast-pack/COMO_USAR_ESTAS_IMAGENES.md) | How to use the generated reference images in `refs/` |
| [REFERENCIAS_ROBLOX.md](docs/design/beast-pack/REFERENCIAS_ROBLOX.md) | Official Roblox docs links used for implementation |
| [REFERENCIAS_VISUALES_REALES_ROBLOX.md](docs/design/beast-pack/REFERENCIAS_VISUALES_REALES_ROBLOX.md) | Style research on existing Roblox games (do not copy) |
| `*_PROMPT_IA_MODELO_3D.txt` | Text prompts for generating each beast's 3D model |

### Mechanics (`docs/mechanics/`)

| Doc | What it is |
| --- | --- |
| [wildbound-capture.md](docs/mechanics/wildbound-capture.md) | Lumipol capture minigame (ring, calm, seal) |
| [wildbound-extraction.md](docs/mechanics/wildbound-extraction.md) | Carry slot, registration and companion (delivery B) |
| [wildbound-guardian.md](docs/mechanics/wildbound-guardian.md) | La Silueta: senses, moves, strikes and defeat costs (delivery C) |
| [wildbound-fair-strike.md](docs/mechanics/wildbound-fair-strike.md) | Fair-strike decision record; damage off outside a private test |
| [wildbound-awareness.md](docs/mechanics/wildbound-awareness.md) | Awareness rule: who La Silueta is after |
| [wildbound-delivery-d.md](docs/mechanics/wildbound-delivery-d.md) | Fog, horror audio, stamina and hiding |
| [wildbound-expedition-islands.md](docs/mechanics/wildbound-expedition-islands.md) | Islands, sleeping nests, first minute. **Stale header** (says nothing built; overview: Done) |
| [wildbound-beasts.md](docs/mechanics/wildbound-beasts.md) | Beast director, Viper and Pouncer |
| [wildbound-incubator.md](docs/mechanics/wildbound-incubator.md) | Egg incubation (delivery E) |
| [wildbound-persistence.md](docs/mechanics/wildbound-persistence.md) | Saved progress: schema, session lock, live saving |
| [wildbound-economy-p0.md](docs/mechanics/wildbound-economy-p0.md) | Esencia economy, upgrades, skill tree |
| [wildbound-hub-systems.md](docs/mechanics/wildbound-hub-systems.md) | Spec for corral, trophies, kiosk, workshop (nothing built) |
| [wildbound-new-mechanics.md](docs/mechanics/wildbound-new-mechanics.md) | Five prepared modules and their wiring plan. **Outdated** as status (none wired) |
| [wildbound-state.md](docs/mechanics/wildbound-state.md) | Original P0 session loot contract (2026-11-05 status) |
| [wildbound-world.md](docs/mechanics/wildbound-world.md) | Original P0 world rules and Silueta (2026-11-05 status) |
| [wildbound-creature-night-profiles.md](docs/mechanics/wildbound-creature-night-profiles.md) | Creature profiles and Silueta horror direction |

### Maps (`docs/maps/`)

| Doc | What it is |
| --- | --- |
| [wildbound-p0.md](docs/maps/wildbound-p0.md) | Original 400 x 400 Fog Forest greybox |
| [wildbound-hub.md](docs/maps/wildbound-hub.md) | Hub with personal bases. Sections 2 and 5 **outdated** (preview hub) |
| [wildbound-open-world-biomes.md](docs/maps/wildbound-open-world-biomes.md) | Biome placement and Edit-mode builders. Section 4 "Order" **outdated** |
| [silueta-forest-concept-v1.md](docs/maps/silueta-forest-concept-v1.md) | Image references for the forest kit |

### UI (`docs/ui/`)

| Doc | What it is |
| --- | --- |
| [wildbound-world.md](docs/ui/wildbound-world.md) | World presentation: phases, warnings, awareness chip, atmosphere |
| [wildbound-start-and-settings.md](docs/ui/wildbound-start-and-settings.md) | Start screen, tutorial, settings (wave W9) |
| [wildbound-p0.md](docs/ui/wildbound-p0.md) | Original P0 inventory HUD |

### Testing (`docs/testing/`)

| Doc | What it is |
| --- | --- |
| [wildbound-next-verification.md](docs/testing/wildbound-next-verification.md) | Co-op, mobile and device checklist (not executed) |
| [wildbound-f1-test-kit.md](docs/testing/wildbound-f1-test-kit.md) | Human fun test for gate F1 (not run) |
| [wildbound-f2-plan.md](docs/testing/wildbound-f2-plan.md) | Gate F2 and private beta proposal |
| [wildbound-baseline-m1.md](docs/testing/wildbound-baseline-m1.md) | M1 baseline: what really ran on 2026-11-07 |
| [wildbound-tuning.md](docs/testing/wildbound-tuning.md) | Live dev tuning panel |
| [wildbound-p0.md](docs/testing/wildbound-p0.md) | Original P0 verification guide |
| [wildbound-world.md](docs/testing/wildbound-world.md) | Original P0 world verification guide |
| [silueta-encounter-phase-report.md](docs/testing/silueta-encounter-phase-report.md) | Silueta encounter and phase checks (2026-11-05) |
| [silueta-visual-adapter.md](docs/testing/silueta-visual-adapter.md) | Silueta visual adapter verification |
| [silueta-animation-assets.md](docs/testing/silueta-animation-assets.md) | The four Silueta animation assets |
| [silueta-animation-runtime.md](docs/testing/silueta-animation-runtime.md) | Silueta animation runtime check |
| [silueta-native-idle.md](docs/testing/silueta-native-idle.md) | Silueta native animation import check |

### Audio and assets

| Doc | What it is |
| --- | --- |
| [audio/wildbound-horror-audio-shortlist.md](docs/audio/wildbound-horror-audio-shortlist.md) | Horror audio candidates (research) |
| [audio/wildbound-dread-assets-shortlist.md](docs/audio/wildbound-dread-assets-shortlist.md) | Dread-pass audio and model candidates (research) |
| [assets/silueta-prototype.md](docs/assets/silueta-prototype.md) | Original static Silueta Blender prototype |
| [assets/silueta-rig.md](docs/assets/silueta-rig.md) | Silueta rig v3 sources and exports |
| [assets/silueta-studio-import.md](docs/assets/silueta-studio-import.md) | Silueta v3 native rig import |
| [assets/wildbound-creature-visual-studies-v1.md](docs/assets/wildbound-creature-visual-studies-v1.md) | Creature concept images and prompts |
| `docs/assets/*-manifest.json` | Silueta model and animation upload manifests |
| [assets/models/beasts/README.md](assets/models/beasts/README.md) | Beast models, rigs and clips. **Outdated** (says nothing uploaded; four models are uploaded) |

### Legacy

| Doc | What it is |
| --- | --- |
| [docs/legacy/horror-map-and-rescue-prototype.md](docs/legacy/horror-map-and-rescue-prototype.md) | Pre-Wildbound horror map blockout and session rescue prototype, with the Lighting rollback snippet |

### ODD task files (`odd/tasks/`)

Each file is one feature: objective, scope, a checklist with task IDs, evidence and the next step. Checkboxes are updated only after an observed result.

| File | What it tracks |
| --- | --- |
| [wildbound-capture-extraction-horror.md](odd/tasks/wildbound-capture-extraction-horror.md) | **Main log.** Deliveries A to E, dread, chase and fear passes, Nest Heist phases 1 to 4a, hub, forest shift, Edit visibility pass, generated Lumipol. Some early checkboxes (D, D3, D4) were never ticked although later sections built stamina |
| [wildbound-first-playable.md](odd/tasks/wildbound-first-playable.md) | Original P0 first playable and Silueta rig work. Its P0-1 to P0-7 checklist was not updated after later features superseded it |
| [wildbound-waves.md](odd/tasks/wildbound-waves.md) | Delivery waves W0 to W17 toward F1, F2 and expansion |
| [wildbound-new-mechanics.md](odd/tasks/wildbound-new-mechanics.md) | The five prepared mechanics modules (RED/GREEN pending Studio) |
| [wildbound-open-world-biomes.md](odd/tasks/wildbound-open-world-biomes.md) | Biome placement, builders and roads (offline) |
| [fog-forest-visual-kit.md](odd/tasks/fog-forest-visual-kit.md) | Low-poly forest kit and nest move |
| [wildbound-creature-visual-studies.md](odd/tasks/wildbound-creature-visual-studies.md) | Creature concept studies and Lumipol blockout |
| [lumipol-forest-sprite.md](odd/tasks/lumipol-forest-sprite.md) | Lumipol forest sprite Blender model |
| [lumipol-reference-match.md](odd/tasks/lumipol-reference-match.md) | Lumipol six-view reference reconstruction |
| [wildbound-master-readiness.md](odd/tasks/wildbound-master-readiness.md) | Master-prompt readiness audit |
| [roblox-skill-pack-readiness.md](odd/tasks/roblox-skill-pack-readiness.md) | Local Roblox skill-pack preparation |
| [wildbound-agent-routing.md](odd/tasks/wildbound-agent-routing.md) | Agent routing configuration |
| [horror-map-blockout.md](odd/tasks/horror-map-blockout.md) | Pre-Wildbound horror map blockout (legacy) |
| [creature-rescue-inventory.md](odd/tasks/creature-rescue-inventory.md) | Pre-Wildbound rescue prototype (legacy) |

## Repository layout

| Path | Contents |
| --- | --- |
| `src/wildbound/` | Game source: server scripts, client scripts and pure Luau modules. Explorer paths come from `tools/deploy_manifest.py` |
| `src/server/`, `src/client/` | Legacy rescue prototype |
| `tests/` | Luau suites run in Studio (`*_Test.luau`), plus legacy rescue tests |
| `tools/` | Python planners, Blender kit and rig builders, economy and Silueta simulators, deploy manifest, Luau map and biome builders, and their Python tests (`test_*.py`) |
| `assets/blender/` | Blender sources for kits, guardians, species, La Silueta and Lumipol |
| `assets/exports/` | FBX and rbxmx exports, upload records, Play captures, and local `.rbxl` backups |
| `assets/maps/` | Generated layout data for the forest, hub, open world and each biome |
| `assets/models/beasts/` | Viper, Pouncer, Gargoyle and Mire models, clips and upload record |
| `assets/concepts/` | Concept images |
| `docs/` | Design, mechanics, maps, UI, testing, audio and asset docs (map above) |
| `odd/tasks/` | ODD feature task files |
| `evidence/` | Recorded Studio baseline |
| `.agents/skills/` | Project skills for agents |
| `resources/skill-packs/` | Original skill packs, local only (git-ignored) |
| `*.rbxl` (root) | Local place backups of the prototypes and early Wildbound states |

## Working with Studio and testing

Safety rules (from [AGENTS.md](AGENTS.md)):

- Before any Studio edit, verify the Studio instance and place, and get the owner's confirmation of that target.
- Save a local `.rbxl` backup of the place before editing.
- Never publish, upload assets, or change monetization without explicit approval. Damage stays off outside the private test place.
- One Studio writer at a time.

Checks:

- Luau suites run inside Studio on fresh module clones (no offline Luau runtime here). Every deploy is checked against the repo by Adler-32 and length, using [tools/deploy_manifest.py](tools/deploy_manifest.py).
- Python: `python -I -B -m unittest discover -s tools -p "test_*.py"`. One failure is known (`test_lumipol_v2.test_v1_files_are_unchanged`).
- Strict TDD: observe RED before GREEN.

Related docs: overview section 12.3, [docs/testing/wildbound-tuning.md](docs/testing/wildbound-tuning.md), [docs/testing/wildbound-next-verification.md](docs/testing/wildbound-next-verification.md), [docs/testing/wildbound-f1-test-kit.md](docs/testing/wildbound-f1-test-kit.md).

For agents: start with [AGENTS.md](AGENTS.md).
