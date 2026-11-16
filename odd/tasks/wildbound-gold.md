# Wildbound: Oro (gold currency)

## Objective

Owner request (2026-11-16): creatures and the treadmill ("caminadora") give gold, and gold can also buy more farm places and treadmill upgrades, in addition to their current Esencia prices.

## Scope

- New saved currency **Oro** with a HUD counter ("Oro: N", top right) and a batched "+N oro" popup.
- Income: farm creatures over time while the owner is in the game; a bonus per tamed or hatched creature; treadmill laps with a per-minute cap.
- Sinks: `farmSlot5`, `farmSlot6` (keeping the "requires" order) and the next treadmill level, bought with gold from the camp screen ("Taller" tab), server-authoritative.
- Out of scope: offline income, Robux, any change to Esencia prices or income.

## Checklist

- [x] GD-1..GD-6 pure rules (`src/wildbound/WildboundGold.luau`): farm rate by rarity, accrual, lap gold and anti-AFK cap, prices, pacing, popup batching. Suite `tests/WildboundGold_Test.luau` RED (module missing) then GREEN 12/12.
- [x] GD-7..GD-9 State: `addGold`, `upgradeWithGold`, `trainWithGold`, `snapshot.gold`; saved and restored through `WildboundRecord` (round trip in GD-7).
- [x] GD-10 camp screen rows: both prices on the upgrade row ("400 de Esencia o 60 de oro"), a separate "Usar oro" row per farm place, and a treadmill row ("Precio: 30 de oro o 20 de Esencia en la caminadora"); reasons when disabled.
- [x] GD-11 wiring: server `BuyGold` action, tame/hatch bonus, lap gold, service start; client panel and HUD script.
- [x] Walked Play check (solo, Studio, big4 map).
- [x] Economy doc updated (`docs/mechanics/wildbound-economy-p0.md`, section "No AFK path", Oro exception and value table).

## Values

| Source or sink | Value |
| --- | --- |
| Farm creature | Común 2/min, Rara 3/min, Épica 5/min, Legendaria 8/min; unknown species (candy critters) count as Común |
| Tame (refuge registration) or hatch | +5 |
| Treadmill lap (8 s) | 1 + floor(level/4), cap 6 per minute |
| Quinto lugar de granja | 60 oro (or 400 Esencia) |
| Sexto lugar de granja | 150 oro (or 900 Esencia), needs the fifth |
| Treadmill level L+1 | round(30 × 1.15^L): 30, 35, 40, 46, 52 … 281 (or the Esencia price at the treadmill) |

Pacing (GD-5): early play with two common creatures in the farm (4/min), one minute in five on the treadmill (1.2/min) and a tame every ten minutes (0.5/min) earns 5.7 gold/min, so the first gold purchase (treadmill level 1, 30 oro) takes about 5.3 minutes; a full four-creature farm buys the fifth place (60) in about 6.5 minutes.

## Decisions taken for the user

1. Gold is a new currency "Oro"; no gold/coin currency existed (Esencia is the internal `ember`).
2. Gold is saved as the `gold` count inside the saved `training` map (same trick as `walkLaps`), so no record schema step was needed and old saves load unchanged.
3. Farm income needs the owner in the game but not near the farm; no offline income.
4. Tame bonus = 5 for a refuge registration or an incubator hatch. Rarity for farm income comes from `WildboundSpecies.LOOKS`; species not listed there count as Común.
5. Treadmill anti-AFK: at most 6 gold per minute from laps (about 7.5 laps fit in a minute). Farm income is passive by design, which is an explicit exception to the economy's AFK-1 rule (recorded in the economy doc).
6. Only the farm places and treadmill levels sell for gold; other upgrades stay Esencia-only.
7. Gold purchases are accepted at the camp or at the own base's glove bench or treadmill (the places where the camp screen opens), measured on the server.
8. The camp screen shows each gold option as its own row with a "Usar oro" button under the Esencia row (simpler than two buttons in one row, and it keeps the compact phone layout). The treadmill's Esencia price stays at the treadmill itself; its camp row shows both prices.
9. The popup shows earned gold at most once every 4 s ("+N oro"), under the counter.
10. The open "Taller" tab rebuilds when the gold balance changes, so prices and buttons follow the live balance.

## Evidence (2026-11-16, Studio place 122652861404212)

- Fresh loader (temporary ServerStorage StringValue, lock respected, destroyed after): Gold 12/0, CampView 24/0, Record 30/0, Training 13/0, Save 23/0, Gear 15/0, Text 22/0, Incubator 7/0, Refuge 15/0, CreatureToolbar 22/0, MechanicsWiring 10/0, PromptKeys 7/0, StartWiring 9/0. Known pre-existing reds only: State_Test 14 (bag size drift), Economy ECO-20, EggLoop EL12, Hub HB-T3, IslandWiring I6 (7 RemoteEvent constructors at HEAD already).
- Walked Play check: on the own base treadmill, gold rose 0 → 6 in the first minute and stopped at the cap (7th lap paid 0), popups "+1 oro", "+2 oro" seen, counter "Oro: 11". A stolen egg (HeistProbe steal) walked home hatched a Gomibú (+5 bonus); placed in the farm with its hotbar tool, the farm paid 17 → 19 in 61 s. With 100 test gold granted by the Studio-only `WildboundGoldProbe` (server, used only for the purchase test), clicking "Usar oro" bought the fifth farm place (100 → 40, row now "comprado") and the next treadmill level (40 → 10). A short-of-gold attempt for the sixth place was refused with "Te faltan 41 de oro." and changed nothing.
- Found during the walk and fixed: the camp rows used the last snapshot's gold (stale); they now read the live attribute and rebuild on change.

## Next step

Owner: try it in Play and say if the prices or rates feel right; values are in `WildboundGold.luau`.

## Owner feedback 3 (2026-11-16)

Owner asked: hide the base UI that lists gloves, chest, incubator and the like (none of it is useful yet); creatures pay too little gold; add a way to sell creatures for more gold.

Checklist:

- [x] OF3-1 Base UI cleanup behind one data flag, `WildboundCampView.HIDDEN` (systems, saves and server rules untouched).
- [x] OF3-2 More gold (values below).
- [x] OF3-3 "Vender" a creature for gold, server-authoritative, two taps.
- [x] OF3-4 Tests first (GD-1, GD-3, GD-5 updated; GD-13..GD-17 new) and a walked Play check.

Values, old -> new (`WildboundGold.luau`):

| Value | Old | New |
|---|---|---|
| Farm gold/min Común, Rara, Épica, Legendaria | 2, 3, 5, 8 | 7, 10, 18, 30 |
| Tame/hatch bonus | 5 | 20 |
| Gold per treadmill lap (levels 0..3; +1 per 4 levels) | 1 | 2 |
| Treadmill anti-AFK cap per minute | 6 | 10 |
| Sale price Común, Rara, Épica, Legendaria (bond level 1) | none | 25, 60, 150, 400 |
| Sale bonus per bond level above 1 (cap level 10) | none | +20% |

Prices of gold purchases are unchanged (fifth farm place 60, sixth 150, treadmill level 1 is 30), so the first purchase now comes after about 1.7 minutes of early play instead of about 5.

What is hidden (`View.HIDDEN`, applied by the client through `Camp.visibleRows` and the flag checks):

- Taller tab sections Craft (seal, capsule, totem crafts, seal arming, totem), Gear (gloves and the luck totem) and Skills; the incubator upgrades `incubatorSlot2`, `incubatorSlot3`, `fastIncubator`.
- The Huevos tab (cofre de huevos and incubadora): the header shows Bolsa, Taller, Menú, Cerrar; any request to open it shows the Bolsa tab.
- The Bolsa tab's two seal buttons (they belong to the crafts).
- Base prompts `chest` ("Guardar huevos / Abrir cofre"), `incubator` ("Incubar huevo") and `glove` ("Ver guantes"), and the chest's billboard. The client loop used to re-enable every own-base prompt each second, overriding the server's disabled state.
- Still shown: stock and Esencia line, Farol tapado and the two packs, farm places (Esencia and gold), the treadmill level for gold, the bond line, the treadmill prompts, "Entregar huevo", the cradle sign over the incubator, and the stored eggs and creatures in the Bolsa tab.

To turn something back on, remove it from `View.HIDDEN` (or set `eggsTab = false`). No other change is needed.

Selling: `State:sellCreature(key, uid, alive, price)`, `WildboundGoldService:sell`, and the server action `SellCreature`. The price comes from the server's own species rarity and the creature's bond level. The uid from the client is untrusted. A refusal changes nothing and replies in Spanish. A sale pays at once, shows the "+N oro" popup right away (outside the 4 s batching), and also shows "Vendiste a X. +N de oro." The hotbar re-syncs after a sale.

### Decisions taken for the user

1. Hide, don't delete: one data table (`WildboundCampView.HIDDEN`) drives every hidden piece; `View.campRows` still builds every row, so older suites and the systems are unaffected.
2. The incubator keeps working: eggs go into it on their own when you reach your base (`Heist.autoIncubate`), so only its UI is hidden (Huevos tab, its prompt and its upgrades). The cradle sign over it stays, because it is the only in-world sign of the hatch countdown.
3. Crafts, gloves, luck totem and skills are hidden with them ("etc."), because none affects the current loop (steal, farm, treadmill, gold). Farol tapado and the packs stay, because they still work.
4. "Entregar huevo" stays visible (out of scope; it is not one of the named items).
5. Sale rules: never the companion (store it first), never a creature in the farm (take it out first, instead of auto-removing it), never the last creature. Any other creature can be sold, not only a duplicate. The species stays discovered, and its bond is dropped.
6. Sale prices: Común 25, Rara 60, Épica 150, Legendaria 400, +20% per bond level above 1 (capped at level 10). A Común sells for about 3.5 minutes of its farm income, and a Legendaria for about 13 minutes.
7. Sell is allowed anywhere (like "Liberar"), from the Bolsa tab's creature list, with a two-tap confirm that expires after 5 s.
8. The Studio-only `WildboundGoldProbe` gained op "creature" (never in a live server). The walked check used it to give two test creatures, only to test a sale.

### Evidence (2026-11-16, Studio place 122652861404212)

- Fingerprints: before writing, Studio matched the repo HEAD for all 8 touched scripts. After writing, Studio matched the repo for each one (length + Adler-32).
- Fresh loader (loadstring+setfenv, `WildboundFreshRunnerLock` set and cleared):
  - RED first: Gold 9/8.
  - GREEN: Gold 17/0; CampView 24/0, Text 22/0, CreatureToolbar 22/0.
  - Known pre-existing reds only, the same as in the first gold evidence: State_Test 14, Economy ECO-20, Hub HB-T3, Bat NP4 (remote count). These were not touched here.
  - MechanicsWiring could not load in this small loader (its Tuning token).
- Walked Play (`WildboundPlayLock = "gold-fb3"`, both locks nil before, cleared after, map untouched in big4 mode, character_navigation only):
  - In the base, the Huevos tab is gone (an "eggs" open request showed Bolsa). The Taller tab lists only stock, Farol, the packs, the farm places with their gold rows and the treadmill gold row.
  - At Base1 the prompts "Incubar huevo", "Ver guantes" and "Guardar huevos / Abrir cofre" are disabled. "Entrenar", "Subirse a la caminadora" and "Entregar huevo" stay on.
  - The probe gave two test creatures (Lumipol, Cestillo) for the sale test. The Bolsa tab showed "Vender a Lumipol por 25 de oro." and "Vender a Cestillo por 60 de oro.".
  - A stray first click equipped Cestillo, after which its Vender row correctly disappeared (it was now the companion).
  - Vender on Lumipol showed "¿Vender a Lumipol por 25 de oro? No se puede deshacer." Confirmar then gave the notice "Vendiste a Lumipol. +25 de oro.", the counter "Oro: 25" and the popup "+25 oro". Cestillo, now the companion and the last creature, had no Vender row.

### Economy simulation (owner item O7, 2026-11-16)

- [x] O7-1 Gold model `tools/wildbound_gold_sim.py` (tests `tools/test_wildbound_gold_sim.py`, 14/0) over the live session model; results, risks and proposals in `docs/balance/wildbound-2-0-economy-sim.md`, section "Gold (Oro) results". Full Python suite 1232 run: only `test_lumipol_v2.V1IsKept` (known) and `test_studio_fresh_runner` spec tokens (scripts other agents have not deployed yet) fail.
- Main finding: every gold sink (2164 gold) is bought within 17 to 43 min, then gold piles up with nothing to buy; a full farm pays about as much idle as an active session. Proposals only; no game value was changed.

Decisions taken for the user:

1. Gold is modelled as a replay of the live model's sessions (hatch and lap logs), not a new trip model, so gold and Esencia use the same sessions.
2. Assumed behaviour: beginner never sells, intermediate sells duplicates, advanced sells every spare; cheapest gold purchase first, bought as soon as affordable; the first hatch is the companion and stays out of the farm.
3. A seller runs with no collection limit (a sale frees the place).
4. The simulator's broken inputs were fixed from the code (per-rarity steal holds, beast cooldown 10) instead of pinning old values; the older Esencia tables were not regenerated, to keep their hand-written balance-pass notes.

### Walked income and phone layout (handoff B1, B2; 2026-11-16, place 122652861404212)

- [x] GW-1 Farm income walked at the new rate. Play with `WildboundPlayLock = "b5-play-checks-20261116"` (both locks nil
  before, cleared after, map left in big4, place not saved). The Studio probe gave one test Lumipol (Común); after a
  respawn its hotbar tool appeared; the client equipped it on the own Base1 pad and `Tool:Activate()` placed it in the
  farm (the tool was consumed). The server read the player attribute `WildboundGold` every 2.5 s: 12 at 0.0 s, 19 at
  60.2 s (+1 about every 8.6 s), i.e. exactly 7 per minute.
- [x] GW-2 Treadmill laps walked. The walker stood on the own belt and was mounted on its own; the client logged the
  Treadmill remote's "lap" events: one every 8.0 s; laps 1 to 5 paid 2 each (balance 23, 26, 29, 32, 35, with the farm
  still adding), laps 6 to 8 paid 0 (the cap of 10 in the 60 s window), and the first lap after the window reset paid
  2 again; at training level 4 a lap paid 3 (2 + 1 per 4 levels), as designed. The walk speed rose to 24 from those laps.
- [x] GW-3 Bolsa tab Vender/Liberar rows at phone size: COMPUTED, not seen on a phone (Studio's Play viewport cannot be
  resized from here). In the Play client, with the game's own `WildboundHudLayout.compute` (touch), `WildboundCampView`
  panel/listArea/rowHeight and the client's row geometry (98 x 44 button, description width = row - 118), each row text
  was measured with `TextService:GetTextSize` (Gotham) for every species name and the four row texts (Liberar,
  its Confirmar, Vender at 400 oro, its Confirmar):
  - 375 x 812 (upright): panel 359 x 429 at (8, 54), compact rows, text size 13, text width 200. Every row fits; the
    tightest ("¿Vender a Lumipol Violeta por 400 de oro? No se puede deshacer.") needs 43 px of a 60 px row. About 5.6
    sell rows show without scrolling. Buttons: the widest label ("Confirmar") is 66 of 98 px.
  - 812 x 375 (sideways): panel 470 x 313 at (171, 54), compact rows, text width 311. Every row fits (tightest 30 px of
    48). About 5 rows show. The panel stays inside the screen in both.

Decisions taken for the user:

1. The farm check used the Studio-only probe creature (as the sale check did) instead of stealing and hatching an egg,
   because the egg route needs a full heist and the income rule does not depend on how the creature was gained.
2. The phone check is computed from the live modules and real text measurement rather than skipped, and is marked as
   computed; a real phone stays with the owner (handoff O5).

### Not done

- A real phone (or a resized viewport) for the Bolsa tab; two players.
