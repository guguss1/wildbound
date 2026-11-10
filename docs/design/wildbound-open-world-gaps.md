# Wildbound open world: gaps, contradictions and build order

**Status: review of design documents only. Nothing was built, edited in Studio or played.** Written 2026-11-10 by a completeness critic. It reads four documents against the user's direction of 2026-11-09 and lists what is missing or contradictory. The four documents are `docs/design/wildbound-open-world-hub.md` (OW), `docs/design/wildbound-biome-pradera.md` (PA), `docs/design/wildbound-economy-and-offers.md` (EC) and `docs/mechanics/wildbound-hub-systems.md` (HS). It also cross-checks the approved plan `enchanted-jingling-mccarthy.md` (items W1 to W5, F2, G1, G2, I1, I2), the two layout JSON files and the current source. It then gives an ordered build plan for the Studio writer workflows that come next. Design and code are in English; in-game names stay in neutral Spanish.

## Quick path

| You are | Read |
| --- | --- |
| The user | Section 1 (the top five), then section 5 (decisions that block the build) |
| The next Studio writer | Section 4 (build order). Do not start a step until its "Blocked by" column is clear |
| A design writer fixing the documents | Sections 2 and 3. Each row names the document and the line or section that has to change |

## 0. Baseline checked for this review

| Check | Result |
| --- | --- |
| `python -I -B -m unittest discover -s tools -p "test_*.py"` (2026-11-10) | **1014 tests ran, 1 failure, 28 skipped.** The one failure is the known `test_lumipol_v2.V1IsKept.test_v1_files_are_unchanged` (the `lumipol-roblox-blockout-v1.blend` hash, a file modified in the working tree) |
| Per-player Silueta (F2) | **Exists in code**: `src/wildbound/WildboundHunters.luau`, `Rules.MAX_HUNTERS = 8` (tunable 1 to 16) |
| Wave clock (G1), spawn graph and spawn clock (W1, W2), random Refugios (W4), biome event (W3), corral, trophies, equipment, hub geometry | **Not in code.** `WildboundSpawn.luau` handles gather nodes only, and `Spawn.EVENTS` is `{ None }`. `WildboundRefuge.luau` is the registration hut, not a random safe zone |
| Open-world layout `assets/maps/open-world/layout-v1.json` | Pradera home **(400, -60)**, leash 80, chase leash 100, roam rectangle x 300..495, z -165..60 |
| Pradera kit `assets/maps/pradera-layout/pradera-layout-v1.json` | Nube home sector (150, 0) = world **(450, 0)**, leash 90, strike zone radius 110. Gate sun circle at sector -186 = world (114, 0), radius 25 |

## 1. The top five gaps

| # | Gap | Why it blocks |
| --- | --- | --- |
| 1 | **The two documents describe two different east biomes.** OW drew its east half from the older biome-2 proposal: "Pradera Luminosa" with La Abeja Reina, home (400, -60), a rectangle, outpost (330, 130) and the tutorial nest "Prado de los Brotes" (150, -45) with no species. PA and its generated kit describe "Pradera Arcoíris" with La Nube Gruñona: home (450, 0), a 110-stud strike circle, leash 90, the gate sun circle at (114, 0), the Plaza del Molino, and Chispín's nest at world (175, -30). Nothing reconciles them | Every zone rule, Refugio candidate, rarity seed and road check on the east side was computed against a beast that the PA kit does not build (section 2.1 lists the concrete breaks) |
| 2 | **No document specifies the random spawn clock (W1, W2) or the wave clock (G1).** OW supplies seeds only. Undefined: how many eggs and crías are live per tier, the 300 s lifetime and relocation, the 90 / 150 / 240 / 360 s respawns, whether a spawn is shared or per player, the first-wave guaranteed egg (the plan puts it "near camp", but players now spawn at the hub), the wave board's scope, the "wave survived" event, and the biome-variant rotation (W5) | The corral working rule, the rarity of every creature, the Refugio reroll, Rastreo 3 and 4, the luck totem and the wave board all hang on a clock nobody has designed |
| 3 | **Refugios have three incompatible definitions, and their name collides with a hub station.** OW: radius 8, 2 to 3 per side, never inside a territory (at least 110 studs from home). PA: sun circles of radius 12, six candidates with three inside the Tormenta zone, at least 60 studs from home, two permanent. Plan W4: a "glowing circle with a totem pole". At the same time, the hub's registration hut is also called "Refugio" (`WildboundRefuge`). There is no rule for a Refugio that rerolls away under a player who is being chased or telegraphed | Players cannot read "Refugio" safely, and the safety contract is unfair at the reroll instant |
| 4 | **PA section 10 contradicts EC, the economy of record, on monetization, and the user's own words differ from EC.** PA still lists: Guantes as a calm meter +30 % (EC dropped this because it breaks the 3.6 s stationary invariant), a Robux Molinillo 5-pack (a consumable that would need a Developer Product, which EC forbids), a Robux hatch speed-up S5 (EC says hatch speed is never sold), Robux corral slots 5 to 8 (EC sells pen 6 only) and Pradera nodes at 40 / 100 / 220 (EC folds them into the tree at 40 / 100 / 250). The user's direction names Developer Products; EC chose Game Passes only. The user also asked for a "strong" incentive, but EC keeps it deliberately modest (166 to 215 Robux non-cosmetic, payer 1.06x at 2 h) | A writer following PA would build something the economy of record forbids. The incentive strength is an unconfirmed user decision |
| 5 | **Almost everything the user described needs saved progress, and DataStore is forbidden** (EC E12). Pens 6 to 8, tier 3 and beyond, equipment levels II and III, the rising ladder past the first hour, trophies that outlive a session, the daily gift, breeder levels and every Robux offer all need it. Without persistence, the playable slice is one sitting: tier 1, Captura 2, Guantes I, pen 5. In addition, nobody has decided the single maturity label for a world that puts a horror forest next to a kids' biome (EC E11), and that label gates every offer | The user's "progressively more expensive free path plus Robux shortcut" cannot be experienced or tested yet. These are user decisions, not writer work |

## 2. Contradictions between the documents

### 2.1 East biome geometry (gap 1 in detail)

| Item | OW | PA (and its kit JSON) | Consequence |
| --- | --- | --- | --- |
| Name and beast | Pradera Luminosa, La Abeja Reina (pending B1) | Pradera Arcoíris, La Nube Gruñona | Signs and `WildboundText` strings differ (OW §11 row 8) |
| Beast home | (400, -60) | (450, 0) | OW's tier bands and leash bands use the wrong centre |
| Beast ground | Rectangle x 300..495, z -165..60; territory 80, chase 100 | Circle of radius 110 around (450, 0); leash 90 | PA's circle reaches x 560, past the 500 edge of the region square |
| **Ring road** | "Every sample beyond both chase leashes, more than 100 studs from both homes" (OW §5) | The ring at x 510 is **60 studs** from (450, 0), inside the 110 strike zone | The ring road's "free world" promise breaks on the east leg |
| **Refugio PB2** (480, 20) | "Roam, beyond the leash" | **36 studs** from the Nube's home, inside her strike zone and against PA's "never within 60 studs of home" | An OW candidate is illegal under PA |
| East seeds | 4 Legendaria, 14 Épica (OW §8) | "Legendaria only from the event egg" (PA §4) | Spawn tiers contradict the species table |
| Gate | (100, 0), at the end of a 40-stud transition | (114, 0), a 25-radius sun circle that "overlaps the hub's safe zone" | False: the hub radius is 60, so the ground from 60 to 89 is covered by neither. PA also calls the hub a "200-stud disc" (radius 100) |
| Tutorial nest | "Prado de los Brotes" (150, -45), 67 studs from the gate, species pending | Chispín N1 at world (175, -30), "68 studs from the gate" | Two first-catch hooks |
| East shelter | Outpost safe circle at (330, 130), r 22, capsule banking | Plaza del Molino, a sun circle at world (260, 14), no banking stated | It is unclear where an east player banks before walking home |
| West gate | (-60, 0), threshold road to the shelter | "A dead-tree arch at (-100, 0) and the camp's safe circle" | The camp is at (-440, 140), 380 studs away |
| Leash value | Decision OW6: 80 or 60 | 90 | Three candidate values |

**Fix (offline, before any Studio step):** `tools/plan_open_world_layout.py` should read the beast home, strike radius, leash, gate, nests and sun circles from `pradera-layout-v1.json`, so the east half is not drafted twice. It should then re-run `check_ring_road`, `check_leash_bands`, the Refugio rules and the seed tiers. If the ring road must stay beast-free, the Nube's home moves west (to x at most about 390) or the ring moves out. PA §8 must be rewritten to the hub radius of 60 and the OW gates.

### 2.2 Corral

| Item | EC §5 (record) and HS §3 | PA §9 |
| --- | --- | --- |
| Rates | By rarity: 0.5 / 0.75 / 1.0 / 1.5 | By species: 0.5 / 0.5 / 1.0 / 2.0 / 4.0 (Esponjín Rara at 1.0, Hongolín Épica at 2.0, Relampino 4.0) |
| Feed | 1 common or uncommon of any side, re-feed only after an expedition event | 1 Pelusa only, no expedition rule |
| Accrual | Working rule (full rate 3 min after an event, then a quarter) and a cap at 0.4 x own extraction plus 0.3 per extra pen | Full rate while alive, with no cap |
| Trophy display | Each viewer sees their own trophies, built client-local (HS §4.2) | "Holds the rarest one of each biome" |
| Physical pens | HS: 8 parcels, one per player present (decision HS1) | OW §11 row 7: 8 pens, one creature per owner, newest first |

PA §9 should be marked superseded by EC §5 and HS §3, and HS1 needs the user's answer. **No document sets the place's `MaxPlayers`.** The parcels (8), `MAX_HUNTERS` (8) and the 8-parcel cost assumptions all need it to be 8. A ninth player is handled for parcels (HS §3.1) but not for hunters, so they would get no Silueta and no Nube.

### 2.3 Items, totems and the tree

| Item | Conflict |
| --- | --- |
| Guantes | Plan I1 and PA §10 use the calm meter +30 %. EC §6.1 and HS §7 use a wake-input multiplier x0.8 that never touches the calm meter. EC is right because of the invariant; PA §10 and plan I1 are stale |
| Amuleto | Plan I1: fear and heartbeat suppression. EC: beast memory only, and fear relief is the free "Modo tranquilo". Plan I1 is stale. No writer step covers Modo tranquilo (EC §13 row "WildboundFear.client") |
| Pradera nodes | PA §10 lists separate nodes at 40 / 100 / 220. EC §4.2 makes them east variants inside the tier 1 and tier 3 nodes (Pies de nube, Bolsillo de espora) and turns "Ojo de sol" into Captura 3's fallback. PA should point to EC |
| Molinillo | PA: crafted for 8 Pelusa + 1 Espora Brillante + 6 Esencia, or found. It is not in EC's totem table or in the Appendix B recipes, and its sale (a 5-pack) is forbidden by EC rule 4 |
| Totems at the hub | EC §6.3 says they are crafted at the "hub Taller". HS §7.2 adds `Craft` at the Árbol as a second place, but the HS §9 remote table has no `Craft` row with the hub range |

### 2.4 Materials and the "each side stands alone" promise

EC §3 gives the east three roles: Pelusa (common), Espora (uncommon) and Espora Brillante (rare). PA §3 builds only two: Pelusa from puff flowers and Espora Brillante from mushrooms in the Tormenta zone. **No Pradera prop yields Espora**, so a player who stays east cannot pay the 10 uncommon of tier 1. That breaks EC's "a forest player never needs the Pradera and the other way round". The Pradera kit needs an Espora source (for example, small mushroom rings in the Prado).

### 2.5 Biome event timing

Plan W3 says "every 20 min, first at 5". PA §6 puts the Huevo de Tormenta at minute 5, offset 10 minutes from the forest event. Both cannot start at minute 5. The forest event has no document among the four: no location, egg, species, hatch time or name. PA's egg hatches in 300 s, but the incubator has one global `HATCH_SECONDS` 90 and one slot (HS §5), so there is no per-egg hatch time, and an event egg would block a player's only slot for 5 minutes. With per-player beasts, every hunter whose owner goes for the event egg converges on one Legendaria point. Up to `MAX_HUNTERS` beasts near one pedestal has not been addressed for fairness or pathing cost.

## 3. Missing pieces (no document covers them)

| # | Missing | Needed by | Owner of the fix |
| --- | --- | --- | --- |
| M1 | **Spawn and wave design document**: wave clock (`WAVE_SECONDS` 300), live egg and cría counts per tier and side, lifetime, relocation, respawn per tier, shared or per player, despawn while carried, first-wave egg near the **hub** gates (the camp is now 380+ studs away), wave board scope and data, the "wave survived" expedition event, the W5 variant rotation (does Floración apply east, and do Niebla, Escarcha and Ceniza touch the Pradera?), and the `WorldEvent` remote payload | Corral working rule, rarity, Refugios, events, Rastreo 3 and 4, luck totem, Tablero | Design writer, offline, before Studio step S4 |
| M2 | **Refugio contract**: one radius, one count, one candidate rule per side, the name (suggestion: "Refugio temporal" in the world, and rename the hub hut "Registro"), the visual, how it replicates, `Rules.setRefugios`, and a **reroll grace rule** (a Refugio that disappears keeps protecting anyone inside it for N seconds, and a strike already telegraphed into a Refugio cancels) | W4, Amuleto III, Rastreo 5 | Design writer |
| M3 | **Forest biome event**: location, egg look and tell, Legendaria species, window, claimant, beast behaviour while it is active, minute offset | W3, trophies `event:forest` | Design writer |
| M4 | **Species roster per side and tier**: the PA species are not in `WildboundSpecies`. There is no `rarity` or `BIOME` field yet (HS H1). The forest has no Rara, Épica or Legendaria species defined. The OW east tutorial species is "pending" | Rarity, corral rates, trophies, biome completion | Design writer, then Studio step S3 |
| M5 | **Hunter lifecycle by region**: whether each player's Silueta (and Nube) exists while the owner stands in the hub or the other biome, or spawns on entry and despawns on leaving. Also the shared `MAX_HUNTERS` across two beast kinds (PA §13 flags it, nothing decides it) and what the ninth player gets | Performance with 16 beasts, fairness | Design writer, then S6 and S8 |
| M6 | **Per-region consequence switch**: PA's kids rule (no defeat, damage off even in private damage mode, Ráfaga back to the gate) next to the forest's loss rule, with Fear effects off east. No module boundary or `Rules.region` hook is specified beyond a table row | Pradera build | Studio step S8 |
| M7 | **Kids' entry to the forest**: players spawn facing east, but nothing stops a young player walking 60 studs west into horror. There is no gate prompt, warning sign copy or Modo tranquilo hint at the west gate. This ties to E11 | Kids-audience policy | User (E11), then design |
| M8 | **East extraction payouts**: EC keeps "extraction payout unchanged", but the payout table is keyed to forest risk tiers. East species and sun-circle banking have no rows, apart from the event egg's "Heart egg row (14)" | Simulator, corral cap (it reads extraction income) | Economy writer |
| M9 | **HUD budget for the new surfaces**: the wave board, event banner, Refugio marker, offer cards, Modo tranquilo toggle and corral notices on a 375 x 667 phone. HS §13 covers only the hub panels; plan G2 has no layout | Phone readability | UI writer, with S4 |
| M10 | **Dawn key and region lighting**: PA needs a real Dawn row, and OW wants lighting by `Rules.region` with 40-stud interpolation. Neither the atmosphere floors for the Pradera nor the transition audio crossfade has a test plan | S9 | Studio step S9 |
| M11 | **Offline tooling not yet written**: `tools/export_open_world_luau.py`, `tools/plan_spawn_graph.py`, the Luau/Python parity test for the corral and ladders (HS §11), and a `simulate_hub_economy.py` run with east income and per-player beasts | Every Studio step that reads generated data | Offline writer, before the Studio steps that consume it |

## 4. Ordered build plan for the Studio writer workflows

Rules for every step: verify the Studio instance and place and get the user's confirmation of that target first (`AGENTS.md`); write and observe RED tests before GREEN; keep exactly one Studio writer; put every new constant in `WildboundTuningSchema` with a default equal to the module's value; play-check the step before moving on; no `MarketplaceService` and no DataStore. "Offline" steps touch only files and need no Studio access.

| Step | Kind | Delivers | Source spec | Blocked by |
| --- | --- | --- | --- | --- |
| O1 | Offline | Reconcile the east half: OW planner reads the PA kit JSON, regenerate `layout-v1.json`, fix PB2, the ring road and seed tiers; rewrite PA §8 to the hub radius of 60 and the OW gates; mark PA §9 and §10 superseded by EC and HS | Sections 2.1 to 2.3 here | User: name and beast (OW6, S6, B1) |
| O2 | Offline | Spawn and wave design (M1), the Refugio contract (M2), the forest event (M3), the species roster (M4) and hunter lifecycle (M5) as one mechanics document with tunables and tests; add an Espora source to the Pradera kit (2.4) | Plan W1 to W5, G1 | O1 |
| O3 | Offline | `tools/export_open_world_luau.py`, `tools/plan_spawn_graph.py` (forest first), parity tests, simulator runs with the spawn clock and east income | OW §11 rows 11 and 12, HS §11 Python row | O1, O2 |
| S1 | Studio | World rules and the forest translation: `Rules.BEASTS`, `Rules.region`, the hub circle, safe circles, `Rules.toWorld`, the forest root `PivotTo` by (-300, 0, 0), ambush and island coordinates through `toWorld`, and place properties (`StreamingTargetRadius` 420, `StreamOutBehavior` Opportunistic, **`MaxPlayers` 8**) | OW §11 rows 1 to 6, 10 and 13 | OW1, O1 |
| S2 | Studio | Hub geometry and station markers (H0), spawn pads facing east, gate signs, tagged incubator markers | OW §2, §11 rows 7, 8 and 11; HS H0, H2 | S1, O3 |
| S3 | Studio | Rarity on every entry, `Species.BIOME` and `rarity`, the named expedition-event writers (H1) | HS §3.4, §10.1 | O2 (roster) |
| S4 | Studio | `WildboundWaveClock`, the spawn graph and spawn clock (forest side), the `WorldEvent` remote, wave board and banner HUD | O2, plan G1, G2, W1, W2 | S1, S3, O3 |
| S5 | Studio | Random Refugios, forest side, with the reroll grace rule | O2 (M2) | S4 |
| S6 | Studio | The forest biome event, and the hunter lifecycle by region for the existing per-player Silueta | O2 (M3, M5) | S4, S5 |
| S7 | Studio | Hub systems in HS order: H3 corral, H4 trophies, H5 tree kiosk, H6 equipment level I, H7 Puesto mock (private place and developers only), plus Modo tranquilo (EC §6.1) | HS §1 to §13 | S2, S3; H3 also needs S4 for the "wave survived" event |
| S8 | Studio | The Pradera: kit module built detached then attached, its zones, La Nube as a per-player beast (sky-ray sense, fixed-ring strike, kids consequence, sleep), the five species, sun circles as Refugios, the Huevo de Tormenta with a per-egg hatch time | PA §3 to §7, O1, O2 | S1 to S6 |
| S9 | Studio | Lighting and audio by region with the Dawn key, streaming persistent models, a phone MicroProfiler capture of the hub with 8 parcels and of each biome edge | OW §10, PA §2, HS §3.3 | S8 |
| S10 | Studio, gated | Persistence (record schema 2) | EC §13, HS §10.2 | User approval of DataStore (E12) |
| S11 | Studio, gated | Offers (Game Passes) | EC §8, §10 | S10, E11 label, Creator Hub setup by the user, explicit approval |

S1 to S9 can be played in one session-only sitting. S10 and S11 must not start without the user's explicit approval.

## 5. Decisions that block the build (one at a time, in this order)

| # | Decision | Blocks | Recommendation |
| --- | --- | --- | --- |
| D1 | East biome: Pradera Arcoíris with La Nube Gruñona (PA, which has a kit) or Pradera Luminosa with La Abeja Reina (OW draft) | O1 and everything east | PA: its kit, tests and toolbox candidates exist |
| D2 | OW1: translate the forest by (-300, 0), hub radius 60 | S1 | Yes |
| D3 | Refugio name and radius (M2); rename the hub hut | O2, S5 | Hut "Registro", world "Refugio temporal", one radius per side |
| D4 | HS1: parcels per player or pens per owner | S7 | Parcels |
| D5 | Offers: Game Passes only (EC) or also Developer Products (the user's words), and whether the modest EC incentive is strong enough | S11 | EC's Game Passes, revisited after E11 |
| D6 | E11: one maturity label for the whole world, and whether young players get a warning at the forest gate (M7) | S11, kids policy | Decide before any offer |
| D7 | E12: approve saved progress later, or accept a session-only design for now | S10, most of the ladder | Session-only for S1 to S9, decide before S10 |

## 6. What this review did not verify

It did not open Studio, run the Luau suites, play, or measure anything on a phone. The JSON values in section 0 were read from the committed layout files, and the distances in section 2.1 were computed from them by hand. Whether the user prefers PA's beast or OW's draft is unknown. The policy facts EC marks "not re-read first-hand" remain unverified.
