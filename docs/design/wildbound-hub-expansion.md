# Wildbound hub expansion: larger, brighter, shops, chest, inventory, auto-banking

**Status (2026-11-10): design, offline only.** Nothing here was built in Studio, played, or measured on a device. The geometry is generated and tested (`tools/plan_hub_bases.py --variant v2`, `tools/build-hub-map.py`); the mechanics are specified for the next Studio writer. Every number is a hypothesis for playtests. Esencia only: no Robux, no `MarketplaceService`, nothing bought with real money.

User requests covered (combined plan section 6: H1, H2, Q6, Q8, plus the 2026-11-10 follow-up): a clearly larger and brighter hub that stays lit at night, where players show off creatures; shop circles on the ground that open a shop; a chest zone in each base with a roulette, visible odds and prices in the economy config; an inventory panel with glove recycling; no PvP in the hub; walking into your own base banks everything, places a carried egg in the incubator and says "Estás a salvo"; a hatch timer ladder by rarity.

## Quick path

| You are | Read |
| --- | --- |
| The user | Section 1 (what changes), section 12 (open questions) |
| The Studio writer | Section 11 (task list), then the system you build |
| A reviewer | Sections 2, 6, 10 (radius limit, chest authority, simulator results) |

## 1. What changes, in one table

| Area | v1 (built today) | v2 (this design) |
| --- | --- | --- |
| Safe radius / wall / floor | 90 / 88 / 92 | **100 / 98 / 102** |
| Plaza, promenade | r 30; ring 46 to 54 | r 34; ring 50 to 58 |
| Bases | 26 x 22 at r 68 | **29 x 24 at r 77**, plus a chest zone and an invisible bank zone |
| Incubator | 1 cradle | 2 cradles (`Slots` 2); logic in section 7 |
| Showcase | Display (3 slots) inside the fence | Plus a public **Vitrina** plinth in front of every base |
| Shops | Camp board only | **4 shop circles** on the lawn ring |
| Lights | 19 PointLights, brightness 0.8 to 1.6 | **35**, brightness 0.9 to 2.0, warm, shadowless; a hub ambience row |
| Parts | 390 | 474 (budget raised on purpose, measure on a phone) |

Files: `assets/maps/hub-layout/hub-bases-v2.json`, `tools/build-wildbound-hub-map-v2.luau` (90 KB generated module), `assets/maps/hub-layout/hub-kit-report-v2.json`. v1 files are byte-identical; Studio keeps building v1 until the writer switches.

## 2. Radius: why 100, and why not more yet

| Constraint (layout-v1 frame) | Limit on radius r |
| --- | --- |
| Region squares start at x -100 (forest) and x 100 (Pradera) | r <= 100 |
| West first-steal hook at 129.7 studs must stay 20 clear | r < 109.7 |
| Refugio candidate FA2 (-120, -20) must stay 20 clear of the disc | r <= 93.7, **unless FA2 moves** |
| Every Pradera kit prop must stay off the floor | floor < 111 |
| Beasts' reach plus 10 | r < 200 |

So 100 is the largest disc the current open world allows, with one change: **move Refugio candidate FA2 from (-120, -20) to (-120, -45)**, computed by the planner (`open_world_changes`) and checked against every Refugio rule (beast margin, 15 from roads, 9 from props, 60 from its set, outside fog and safe circles). The open-world planner owns that edit; this plan only declares it.

Growth: +11 % radius, **+23 % floor area**, +22 % base pad area. The parallel biome-placement work (`tools/plan_open_world_layout.py`, biomes placed from `Rules.HUB_RADIUS` with 40-stud transitions) would let the hub grow further; a 120 disc (+78 % area) becomes possible once that lands, not before (open question 1).

Eight bases need the ring: a 30.2-stud-wide base on r 77 keeps more than 2 studs from its neighbours (even with the bank zone's exit margin) and 6.4 studs from the promenade, which is the room the showcase takes. Walk time at 16 studs/s (straight lines, a lower bound):

| Walk | v1 | v2 |
| --- | ---: | ---: |
| Spawn pad to a gate | 4.5 s | 5.1 s |
| Spawn pad to a base's delivery pedestal | 3.0 s | 3.5 s |
| Half the promenade (show-off stroll) | 9.8 s | 10.6 s |

A trip gains about 0.6 s of walking each way: the "quick first action" stays quick, and longer trips only move the expedition median up, away from the 180 s floor.

## 3. Lighting: bright hub, dark forest

| Layer | Plan |
| --- | --- |
| Lamps (35, all `Shadows = false`, range <= 30) | Campfire 2.0 / 30; 8 plaza lanterns at r 30, 1.1 / 18; 6 gate lamps 1.0 / 16; 8 base lanterns 1.0 / 16; 8 showcase footlights 0.9 / 12 (paler 255, 214, 150 so creature colours read); 4 shop awnings 1.0 / 14 |
| Palette | Warm light only (red >= green >= blue, tested). Ground lighter than v1 (`#8DBB63` grass, `#E6D7BA` plaza, `#ECDDC2` paths). Neon rings on shops, chests and showcases |
| Ambience (client only) | `WildboundAtmosphere` gains a `hub` zone row. The world client blends to it inside `inside_radius` 100 over `blend_studs` 20, so the forest outside stays as dark as today |
| Hub rows | Day density 0.42, fog 60 to 380, colour 214, 196, 168. Dusk 0.50, 40 to 260. **Night 0.56, fog 30 to 180, colour 150, 118, 90, ambient 96, 80, 64** (the forest night is 0.82, fog 15 to 60, ambient 22, 28, 46). Tint +0.05 brightness, +0.1 saturation |
| Night | `night_lamp_scale` 1.25 multiplies hub lamp brightness on the client at Dusk and Night (capped so no lamp passes 2.5). The flashlight is not needed inside the hub; the existing night flashlight stays as it is |
| Floors kept | fogStart >= 15 and fogEnd >= 45 (the `Atmosphere.FLOORS` contract) in every row |

Cost: 35 shadowless PointLights in an always-loaded model is the main frame-time risk on phones; measure with the MicroProfiler and 8 players before accepting (task T10).

## 4. Showcase per base ("Vitrina")

A round plinth (r 2, 1.6 high) outside each base's front fence, 9 studs to the right of the entrance walk, 1 stud off the base rim and 2 studs off the promenade, with a base-coloured neon footlight ring and a plate "Vitrina de {DisplayName}" facing the lobby. Tag `WildboundShowcase`, attributes `SlotIndex`, `Slots` 1, `HoverHeight` 3.5.

- The owner picks one registered creature for it from the collection display or the inventory ("Poner en la vitrina"); default is the rarest registered creature, newest first.
- The server writes `ShowcaseSpecies`, `ShowcaseRarity` and `ShowcaseUid` attributes on the plinth; each client draws the hovering model locally (same pattern as the display slots, no replicated physics). A free base shows an empty plinth.
- A creature on the vitrina still counts for the corral rules as "shown", not penned; it can be the companion at the same time (it is a picture, not a second creature).

## 5. Shop circles

| Shop (sign) | Bearing | Sells (economy config ids) | Server action reused |
| --- | ---: | --- | --- |
| Taller de guantes | 45 (SE) | `gear.guantes` | `CraftGear` |
| Mejoras | 157.5 (SW) | `upgrades.farolTapado`, `upgrades.reinforcedPack` | `Upgrade` |
| Suministros | 202.5 (W, on the way to the forest) | `recipes.seal`, `recipes.capsule`, `recipes.totem`, `gear.totemSuerte` | `Craft`, `CraftGear` |
| Árbol de habilidades | 315 (NE) | the 8 live `skills` | `Learn` |

Geometry: circle r 4 at r 41 on the lawn ring, a stall (counter, two posts, coloured awning with the light, sign) behind it at r 47; at least 2 studs from every gate path; centres at least 31 studs apart, so two shops never open together. Tag `WildboundShopSpot`, attributes `ShopId`, `Label`, `TriggerRadius` 4, `CloseRadius` 5.5, `Range` 6.

Flow:

1. The client checks its own root part against every `WildboundShopSpot` 10 times a second (2D distance and |dy| <= 6; never `Touched`). Inside `TriggerRadius` with no panel open: open that shop's panel and play a soft chime.
2. The panel closes when the root leaves `CloseRadius` (1.5 studs of hysteresis) or on "Cerrar". After a manual close it reopens only after the player leaves and re-enters.
3. Each buy button sends the existing action and id. The server measures the distance itself: it accepts the camp (as today) **or** the shop spot that sells that id within `Range` 6 (1.5 studs of latency tolerance on top of the circle; also the own glove bench for gloves, as today). The client never sends a position, price or amount.
4. Refusals reply with notices: existing `CannotAfford`, `AtLimit`, `GlovesFull`, `EffectPending`; new `NotAtStation` ("Acércate a la tienda"), never `NotAtCamp` in the hub.

| | Phone (375 x 667 portrait / 667 x 375 landscape) | PC |
| --- | --- | --- |
| Panel | Bottom sheet 60 % height in portrait; right panel 50 % width in landscape; inside the safe area; never covers the joystick or jump button | Right panel 420 px wide, the world stays visible on the left |
| Rows | Icon, name, one-line effect, cost line "45 de Esencia · 14 Fogbark · 8 Glowmoss", 44 px "Comprar" button; rows in a vertical `ScrollingFrame` | Same rows; hover highlight; Enter buys the selected row |
| Disabled | Button grey with the reason: "Te faltan 12 de Esencia", "Ya lo tienes", "Aún no disponible" | Same |
| Header | Shop name and the balance "Tienes 87 de Esencia" pinned above the scroll | Same; Esc closes |
| Text | 14 px body, 18 px headings, `TextWrapped`, decimal comma | Same |

## 6. Chest zone and roulette ("Cofre del explorador")

Each base has a chest circle (r 2) at local (0, 7.5), the back middle of the pad, with the chest prop behind it. Tag `WildboundChestStation`, attributes `SlotIndex`, `TriggerRadius` 2, `CloseRadius` 3, `Range` 3.5. Standing on the owner's own circle opens the chest panel (same detection as the shops); other owners' circles do nothing.

**Price and rewards** live in the economy-tuning block of `docs/mechanics/wildbound-economy-p0.md` (exported to `WildboundEconomyConfig.chests` and `.recycle` by `tools/export_economy_config_luau.py`):

```json
"chests": { "cofreExplorador": {
  "cost": { "ember": 45 }, "revealSeconds": 4.5, "skipAfterSeconds": 1.5, "lockSeconds": 5,
  "pity": { "every": 10, "minRarity": "Epica" },
  "rewards": [
    { "id": "guanteComun", "kind": "glove", "rarity": "Comun", "weight": 36 },
    { "id": "guanteRaro", "kind": "glove", "rarity": "Rara", "weight": 24 },
    { "id": "guanteEpico", "kind": "glove", "rarity": "Epica", "weight": 9 },
    { "id": "guanteLegendario", "kind": "glove", "rarity": "Legendaria", "weight": 3 },
    { "id": "materiales", "kind": "materials", "grant": { "fogbark": 10, "glowmoss": 5 }, "weight": 15 },
    { "id": "sello", "kind": "consumable", "grant": { "seal": 1 }, "weight": 8, "atCap": "materiales" },
    { "id": "totemSuerte", "kind": "gear", "grant": { "totemSuerte": 1 }, "weight": 5, "atCap": "materiales" }
  ] } },
"recycle": { "gloves": { "Comun": 3, "Rara": 6, "Epica": 12, "Legendaria": 25 }, "neverEquipped": true, "confirmAbove": "Rara" }
```

| Rule | Value |
| --- | --- |
| Odds | Weights sum to 100 and are the displayed percentages. A glove reward rolls its stats with `WildboundGear.roll(random, rarity)` (the rarity is fixed by the chest, the stats are rolled as for a crafted glove) |
| Pity | The 10th chest in a row without an Épica or Legendaria glove gives one (Épica 9 : Legendaria 3). The counter resets on any Épica or better, is shown ("Garantía: en 4 cofres más, un guante Épico o mejor"), and is saved with the gloves (record schema field `chestPity`; session-only until saved progress is approved) |
| Duplicates | Gloves never duplicate (rolled stats). A seal at its cap (3) or a luck totem already held (cap 1) becomes the `materiales` reward, and the reveal says so ("Ya tenías el máximo: te damos materiales") |
| Full inventory | 12 gloves (`GLOVE_LIMIT`): the chest refuses **before** charging, "Tu inventario de guantes está lleno: recicla uno" |
| Never | No Esencia reward (a paid draw that pays currency feels like gambling), no Robux, no countdown, no "almost won" near-miss slowing on purpose |

Server authority (action `OpenChest`, argument the literal chest id, else dropped):

1. Known id; alive; the player owns a base; the server-measured distance from the live root to **their own** `WildboundChestStation` is within `Range`.
2. Not locked: `now >= chestLockUntil` (the lock is `lockSeconds` 5 after each open, longer than the reveal, so the next open never cuts an animation; the 0.3 s same-action limit stays).
3. Room for the worst case (a glove): refuse `GlovesFull` before paying.
4. `State:openChest(key, id, alive, distance, roll, now)` checks `canPay`, pays, applies pity and `atCap`, grants, sets the lock, all in one call with no yield; `roll` comes from the server's `Random`, chosen by weight first and passed in, like `craftGear`.
5. The reply carries the reward id and the glove (if any); the snapshot gains `chest = { pity, lockUntil, last }`. The server picks the result before the animation starts.

Roulette (client only): a horizontal strip of about 30 reward cards spins and slows over `revealSeconds` 4.5 (ease-out), stopping centred on the server's reward, then the card pops (0.4 s scale) with its rarity colour and the glove's stats. "Saltar" appears after 1.5 s. With "Efectos suaves" on, it is a 1.2 s fade. The strip's filler is drawn from the same weights so it never shows a false "nearly". The odds table ("Probabilidades") is visible on the panel before paying, in the same order as above, with the pity line; price button "Abrir · 45 de Esencia".

Policy note: the chest is a random reward bought with play-earned currency only. Esencia is not purchasable (`currency.purchasable = false`) and no Robux row may ever produce Esencia while the chest exists; if a Robux pen that produces Esencia is ever approved (economy doc section 8), the chest must be re-reviewed against Roblox's paid random items rules first (open question 3).

## 7. Base zone: walk in, bank everything, "Estás a salvo"

Each base has an invisible `BaseZone` box (tag `WildboundBaseZone`) equal to the base rim (30.2 x 25.2, 12 high), with `ExitMargin` 2.

| Rule | Value |
| --- | --- |
| Detection | Server step at 4 Hz for players inside the hub disc only: the live root's position in the zone's local frame, inside half extents and height. Leaving needs the half extents plus `ExitMargin` (hysteresis). Never `Touched` |
| Whose | Only the owner's own zone acts. Another player's zone does nothing (and the hub has no PvP) |
| On entry, in order | 1) A carried egg (EggCarry `Carried`, carrier is this player) goes into a free incubator slot of this base and starts its timer (`State:incubate` with the zone as the distance check). No free slot: it is banked (`bankedEggs`) with "Tu incubadora está llena: guardamos el huevo". 2) The bag and pouch are banked as the chest `extract` does today (ends the trip, pays the base Ember once). 3) A big centred banner **"¡Estás a salvo!"** for 2.5 s, with a line under it of what was saved ("Huevo en la incubadora · 3 objetos guardados") |
| Banner limits | Once per entry, at most every 10 s; nothing is banked twice (`extract` refuses an empty bag) |
| Kept | The delivery pedestal and its prompt still work; the zone just makes them unnecessary |

Hatch timer ladder (pure `WildboundIncubator`, server clock, no skip, never sold):

| Egg | Seconds |
| --- | ---: |
| The player's 1st egg ever | 10 |
| 2nd egg | 20 |
| Común | 40 |
| Rara | 75 |
| Épica | 150 |
| Legendaria | 300 |

Slots: the incubator model has **2 cradles**. Recommendation: slot 1 is free; slot 2 is the existing Esencia step `secondIncubator` (250 Esencia in the economy document), never Robux. The economy document drops "extended hatch times sold back"; this ladder only lengthens rarer eggs and is never sold or skipped, so it keeps that rule. Hatched creatures appear with the existing hatch card wherever the player is.

## 8. Inventory panel

Extends the existing inventory screen (bag and banked stock shown apart) with a tab row: **Guantes**, **Objetos**, **Materiales**. Opens from the HUD bag button anywhere; recycling works only inside the hub disc or the camp.

| | Phone portrait | Phone landscape and PC |
| --- | --- | --- |
| Guantes tab | Header "Guantes 7/12"; a 3-column grid of 96 px cards (rarity colour band, glove icon, up to 4 stat lines "+4,7% Velocidad", "Puesto" badge on the equipped one) in a `ScrollingFrame`; tapping a card opens a detail sheet | 4-column grid on the left, detail pane on the right |
| Detail | Stats in full, rarity, buttons "Equipar" and "Reciclar · +6 de Esencia" (44 px). Épica and Legendaria need a 1 s hold on "Reciclar" plus "¿Seguro? No se puede deshacer" | Same; Enter equips, Delete starts the recycle hold |
| Objetos | Seals, capsule, totem, luck totem with counts and caps | Same |
| Materiales | Banked and carried apart (Fogbark, Glowmoss, Nightbloom) | Same |

`RecycleGlove(uid)` on the server: the uid must be one of this player's gloves, not the equipped one (`neverEquipped`), alive, inside the hub disc or the camp; pays `recycle.gloves[rarity]` once and removes it. Values: Común 3, Rara 6, Épica 12, Legendaria 25 Esencia (10 % of a crafted glove's 30 Esencia for a Común, so recycling never pays back a craft or a chest).

## 9. No PvP in the hub

Already true for the v1 disc (`Rules.zone` safe inside `HUB_RADIUS`, the bat refuses, beasts never enter). v2 only changes `Rules.HUB_RADIUS` from 90 to 100; every consumer follows. The bank zone and shops add no combat path.

## 10. Simulator results (2026-11-10, run offline)

| Run | Result |
| --- | --- |
| `simulate_economy.py` (P0, 200 runs x 90 trips), current doc | Invariants hold; median trip cautious 208 s, balanced 201 s, **greedy 183 s** (floor 180 kept); Ember per trip 23.4 / 24.6 / 22.8 |
| Same, on a scratch copy of the P0 doc with the `chests` and `recycle` block | Identical output: the block parses and changes no expedition (the chest is a sink, never a source of trip time) |
| `simulate_hub_economy.py` on the scratch P0 doc | Shape checks ok; output byte-identical to the current run (free balanced: tier 3 at 180 min, all level-I pieces at 149 min, second incubator at 243 min) |
| Chest math (scratch Monte Carlo, 20,000 runs) | Odds sum 100; gloves 72 %. Expected recycle value of a chest 4.35 Esencia, **10 % of its price**; of a crafted glove 5.18 against 30 Esencia plus materials, so no recycle loop. Épica-or-better rate 16.5 % with pity (12 % base); chests to the first Épica+: median 6, at most 10 |
| Chest cadence | One chest costs about 2 expeditions: about every 8 minutes of play (P0 policies) or 9.6 minutes (hub simulator's 28 Esencia per 6-minute cycle). Neither simulator spends on chests, so every chest bought delays the tree by 45 Esencia; the free-path timelines above are the no-chest case |
| Incubator ladder (scratch, the hub simulator's rarity script, mean hatch 74 s) | With 2 slots no egg waits at one egg per 2 to 6 minutes, 5 % wait at most 15 s at one egg a minute. With **1 slot**: no wait at 6-minute cycles, 5 % wait (max 60 s) at 4-minute loops, 25 % at 2-minute loops. So one free slot is enough for normal play; the second slot matters only for rapid egg chains |

Unverified: fun, kids' reading of the odds table, phone frame time with 35 lights and 474 parts, the 4 Hz zone step cost, two or more real players.

## 11. Task list for the Studio writer (RED first, one writer, verify the Studio target with the user before any edit)

| # | Task | Files | Tests to write first |
| --- | --- | --- | --- |
| T1 | Switch the build to v2: deploy `tools/build-wildbound-hub-map-v2.luau` as `ServerStorage.WildboundHubBuilder` (`tools/deploy_manifest.py` mapping), set `Rules.HUB_RADIUS` 90 to 100; expect 474 parts, 35 lights | `WildboundWorldRules.luau`, `deploy_manifest.py`, `WildboundHub.server.luau` | `WildboundWorldRules_Test`: every v2 base pad corner, chest zone and shop circle is safe; `WildboundHub_Test`: part count 474, new tag counts (4 shops, 8 chests, 8 showcases, 8 base zones) |
| T2 | Ask the open-world planner to apply FA2 to (-120, -45) | `tools/plan_open_world_layout.py` (its owner) | Its own Refugio tests |
| T3 | Hub ambience: a `hub` zone row in `WildboundAtmosphere` and the radius blend in the world client; night lamp scale | `WildboundAtmosphere.luau`, `WildboundWorld.client.luau` | Rows equal section 3; floors kept; `at(t, "hub")` brighter than `"open"` at every time |
| T4 | Shop circles: client detection with hysteresis, panel, server range for `Craft`, `Upgrade`, `Learn`, `CraftGear` accepting the matching shop spot | `WildboundServer.server.luau`, new `WildboundShops.luau` (pure: which shop sells which id, `inside(pos, spot)`), `WildboundHudView.luau`, `WildboundText.luau` | Shop-of-id table matches the plan; out-of-range refused with `NotAtStation`; a client position argument is ignored; layout at 375 x 667 and 667 x 375 with 44 px targets |
| T5 | Economy config: add `chests` and `recycle` to the P0 tuning block, re-export | `docs/mechanics/wildbound-economy-p0.md`, `WildboundEconomyConfig.luau` (generated) | `tools/test_export_economy_config_luau.py`; weights sum 100; recycle Común < 20 % of the glove's Esencia cost |
| T6 | Chest: `State:openChest`, `OpenChest` action, pity, lock, `atCap`, refuse-before-pay; roulette view | `WildboundState.luau`, `WildboundServer.server.luau`, new `WildboundChest.luau` (pure: pick, pity, atCap), `WildboundHudView.luau`, `WildboundText.luau` | Order of checks; full gloves refuses and charges nothing; pity at 10; lock blocks a second open within 5 s; another base's chest refused; no `MarketplaceService` (OfferGuard scan) |
| T7 | Inventory tabs and `RecycleGlove` | `WildboundState.luau`, `WildboundServer.server.luau`, `WildboundHudView.luau`, `WildboundText.luau` | Equipped glove refused; values by rarity; outside hub and camp refused; hold-to-confirm for Épica+ |
| T8 | Base zone banking: 4 Hz step, hysteresis, egg to incubator, `extract`, banner | `WildboundServer.server.luau`, `WildboundHubStations.luau`, `WildboundEggCarry.luau` (unchanged rules), `WildboundText.luau` | Enter with egg: incubating, carry cleared; full slot: banked; enter twice: banked once; another player's zone: nothing; no `Touched` in the source |
| T9 | Hatch ladder and 2 cradles (slot 2 behind `secondIncubator` if the user agrees) | `WildboundIncubator.luau`, `WildboundState.luau` | Ladder values; first and second egg 10 and 20 s per player; never below 10 s |
| T10 | Vitrina: owner choice, plinth attributes, client hover model | `WildboundHubStations.luau`, display client | Default pick is the rarest; a free base shows nothing; only the owner can set it |
| T11 | Play checks and a phone MicroProfiler capture with 8 players (frame time with 35 lights) | `docs/testing/` | n/a |

Dev tuning schema rows (`WildboundTuningSchema`, new system `HubExpansion` "Plaza"; defaults are the modules' `CONSTANTS`):

| Key | Label (Spanish) | Default | Min | Max | Step | Side |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| `SHOP_TRIGGER` | Radio de la tienda (studs) | 4 | 2 | 8 | 0.5 | client |
| `SHOP_CLOSE` | Radio para cerrar la tienda (studs) | 5.5 | 3 | 10 | 0.5 | client |
| `SHOP_RANGE` | Distancia de compra (studs) | 6 | 3 | 12 | 0.5 | server |
| `CHEST_REVEAL` | Duración de la ruleta (s) | 4.5 | 1.5 | 8 | 0.5 | client |
| `CHEST_LOCK` | Espera entre cofres (s) | 5 | 3 | 15 | 1 | server |
| `BANK_EXIT_MARGIN` | Margen para salir de la base (studs) | 2 | 0.5 | 6 | 0.5 | server |
| `BANK_STEP_HZ` | Revisiones de la base por segundo | 4 | 1 | 10 | 1 | server |
| `SAFE_BANNER_SECONDS` | Mensaje "Estás a salvo" (s) | 2.5 | 1 | 5 | 0.5 | client |
| `HATCH_FIRST`, `HATCH_SECOND` | Primer y segundo huevo (s) | 10, 20 | 5 | 60 | 1 | server |
| `HATCH_COMUN`, `HATCH_RARA`, `HATCH_EPICA`, `HATCH_LEGENDARIA` | Eclosión por rareza (s) | 40, 75, 150, 300 | 10 | 600 | 5 | server |
| `AMBIENCE_BLEND` | Transición de luz de la plaza (studs) | 20 | 5 | 60 | 5 | client |
| `NIGHT_LAMP_SCALE` | Brillo de faroles de noche (x) | 1.25 | 1 | 1.25 | 0.05 | client |

Not tunable (contracts): chest price, weights, pity count and recycle values (economy config), the geometry (regenerate the plan instead).

## 12. Open questions for the user (one at a time)

1. **Size**: accept 100 now (the most the current open world allows, +23 % area), or wait for the biome placement to grow the hub to 120 (+78 % area, longer walks: about 6.4 s spawn to gate)?
2. **Second incubator slot**: free for everyone (simplest), or the existing 250 Esencia step? The simulator shows one slot is enough unless eggs arrive less than 4 minutes apart.
3. **Chest price and content**: 45 Esencia with gloves 72 %, materials 15 %, a seal 8 %, a luck totem 5 % and a pity of 10; and the rule that the chest stays Esencia-only and no Robux row may ever produce Esencia while it exists.
