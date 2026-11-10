# Wildbound incubator (delivery E)

Delivery E in `odd/tasks/wildbound-capture-extraction-horror.md`: an egg stolen from a nest is carried home, incubated with a timer and hatches into a creature in the player's collection. No earlier design existed beyond that line, so this is the small, server-authoritative version built in the next batch (NB4).

## Flow

1. **Steal.** Unchanged: "Tomar el huevo" on an island nest puts the egg in the bag (`pending`), loud enough to wake the parents (`GRAB`).
2. **Bank.** Unchanged: the camp chest ("Guardar en el cofre") moves bag eggs to `bankedEggs`. A defeat on the way still loses an unwarded egg.
3. **Incubate.** At the incubator (`IncubatorMarker`, -136, 158) the prompt "Incubar huevo" (key R, the old hatch key) puts the first banked egg in the incubator; the Bag tab's "Incubar" button does the same for a chosen egg. Both need the player alive and within 12 studs of the incubator. One egg incubates at a time per player (`SLOTS` 1).
4. **Hatch.** After `HATCH_SECONDS` (90 s by default) the server hatches it on its own, wherever the player is: the creature joins the registered collection (same species as the egg), the notice "¡Tu huevo eclosionó! ..." shows and the presentation card opens. Hatching pays nothing (the economy doc keeps it free), so the economy floors are untouched.

The old instant "Incubar el primer huevo" at `HatchMarker` is gone: every egg now goes through the incubator.

## Rules (server authority)

| Rule | Where |
| --- | --- |
| The client only names an egg uid; the server checks ownership, life, distance and a free slot | `WildboundState:incubate` |
| The clock is the server's (`GetServerTimeNow`); the client never sends a time | `WildboundServer`, 1 Hz hatch step |
| A ready egg hatches exactly once, even if the step runs twice | `WildboundState:hatchReady` removes it before registering |
| An incubating egg is safe from defeat (it is in camp) and counts toward the 100-creature session limit | `WildboundState:defeat` leaves it; `collectionSize` counts it |
| Refusals: `NotOwnedEgg`, `InvalidContext` (dead or too far), `IncubatorFull` | `Text.NOTICES` |

## Persistence

Saved since Nest Heist Phase 3 (NS2, NS3, 2026-11-10): the incubating egg is in the record (`incubating`, schema 2 and later) with its start and ready times in server Unix time (`GetServerTimeNow`), so it keeps incubating while the player is away and hatches on the server's first 1 s step after the next join, with the usual notice and card. A hatch with no companion out makes the newborn the companion at once ("...y ahora te acompaña."); the card's Equipar button and the Bag rows (Equipar, Guardar) swap or store it. Before NS2 it was session only (the W10 text above is historical).

## Tuning

`Incubator.HATCH_SECONDS` (Incubadora system in the dev tuning schema): default 90, range 10 to 900, step 5. `WildboundIncubator.CONSTANTS` is the source of truth; a running incubation keeps the time it started with.

## Not in this delivery

Eggs of rarer tiers with longer timers, a visible egg in the dome, sounds, two players sharing one incubator view, and paying to speed a hatch (never: no Robux).
