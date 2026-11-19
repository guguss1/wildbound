# Owner task queue (from 2026-11-19)

Tasks the owner gave on 2026-11-19, to start on 2026-11-20, one at a time. This file records each task in the owner's words. It does not authorize anything beyond them.

Owner's words (verbatim): "te doy tareas para mañana, anotalas y resolvelas mañana. quiero que las nubes sean mas realistas, no una foto estirada, que la reina de caramelo se enoje y no te deje de perseguir cuando robas el huevo, que haya daño de caida desde esa torre y de otras torres altas hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas zonas hazlo, dame distintas propuestas para ela vance del juego cosa que vaya avanzando la dificultad a medida que avanza y que usuario tenga que comprar o ganar dash o alguna mecanica ocmo velocidad, dame propuestas del juego"

## Queue

| ID | Task | Notes | Status |
|---|---|---|---|
| OQ1 | **More realistic clouds**, "no una foto estirada" | The likely target is the cloud wall between biomes (Caramelo's east edge, `Candy_Este_v1.CloudWall`: Veil and puffs) and any sky cloud that is a stretched image. Make them volumetric: many soft parts or particles, layered, and moving slowly. Uploads need separate approval, so use primitives or particles first. | Not started |
| OQ2 | **The Caramelo queen (La Duquesa) gets angry and never stops chasing** once you steal her egg | This reverses V7-D6, where she lets go past her zone margin. The service's flight clamp (`Smarts.outsideWall`) and the "Vanish" rule change too. RC6 in `WildboundCandyDuquesa_Test` is a deliberate change. Decide how the chase ends: the base, dropping the egg, being caught, or a long timeout. | Not started |
| OQ3 | **Fall damage** from the Gran Torta's tower and other tall towers | This is new. Damage stays off outside the private test place, so it is a flag that is on here. It applies to tall towers in every biome; list them first. | Not started |
| OQ4 | **A much longer map**, with more creatures from different zones if needed | This builds on PD1: every big4 arm 600 x 1200, with Caramelo already done (v9). "Bastante más largo" may mean longer than 1200: decide and record. Pueblo Gatito is next. Its research workflow was started and stopped on 2026-11-19, with nothing written. Then Bosque and Montañas. Add creatures to the new space where it feels empty. | In progress (Caramelo done) |
| OQ5 | **Proposals for game progression**: difficulty rising as you advance; the player has to buy or earn a dash or another mechanic, such as speed | The deliverable is proposals, not code: several options. Note in the proposals that buying with Robux is design only. Nothing is purchasable (`monetization = "none"`) without the owner's explicit approval. In-game currency or earned unlocks are fine to propose. Read `docs/design/wildbound-combined-plan.md` §6, `docs/design/wildbound-economy-and-offers.md` and the overview first. | Done 2026-11-19: `docs/design/wildbound-progression-proposals.md` (A Sellos, B Nivel + tienda, C Rango; recommended B with grafts). Waiting on the owner's choice. |

## Order decided for the owner

1. OQ5 proposals (no Studio).
2. OQ2, the queen.
3. OQ3, fall damage.
4. OQ1, clouds.
5. OQ4, the longer arms, one per task.

The proposals go first so the owner can read them while the code tasks run. OQ2 and OQ3 are small and in Caramelo, which was just changed. OQ4 is the largest.

## Decisions taken for the user

- **OQ2 is built now, on its own, as the owner asked.** It does not wait for the rank system from OQ5. The queen chases with no time limit and no zone margin. The chase ends only when:
  - the thief reaches a safe zone or the base;
  - the thief goes through a portal;
  - the thief drops the egg;
  - the thief is defeated.

  This is the end rule proposal B suggests (the "recommended" section).
- **OQ2 details**, code committed, not yet in Studio:
  - **Hiding no longer loses her.** She circles the hide spot or the grass until the thief comes out, and the spot's own time limit pushes the thief out.
  - **A portal end is the portal service's server stamp only** (`WildboundPortalReadyAt`). The thief's client moves their own body, so a body jump does not count. Egg carriers still cannot use a portal (CG2), so in practice the end is the safe hub.
  - **A second thief is remembered.** Someone who stole her egg inside the plot while she chased another thief is chased afterwards, even outside the plot.
  - **Picking her egg up again after dropping it does not restart the chase.** Dropping the egg ends it, as recorded above.
  - The ends, in the order they are checked: Gone (left or no character), Dead, Portal, Safe, Dropped (after `CALM_SECONDS`).
