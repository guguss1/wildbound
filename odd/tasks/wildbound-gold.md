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
