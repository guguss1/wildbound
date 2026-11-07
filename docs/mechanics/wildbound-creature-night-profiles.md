# Creature profiles and Silueta horror direction

## Implemented first slice

`WildboundWorldRules.resolveCreatureProfile(creatureId, phase, inFog)` resolves a server-owned creature definition into a detached snapshot. A profile declares base stats, optional night overrides with an explicit scope, an art scale, and a stable behavior identifier. The behavior identifier is metadata, not a universal AI implementation. Unknown creatures do not silently inherit Silueta's values.

| Creature | Base speed / detection | Night speed / detection | Night scope | Visual scale |
| --- | --- | --- | --- | --- |
| Silueta | 6 studs/s / 28 studs | 8 studs/s / 38 studs | Fog only | 1.30× the staged visual template |

The creature is not night-only; phase affects its stats, not spawning. No existing collectible or companion was changed. `guardianParameters` remains the Silueta compatibility entry point. New creature profiles should explicitly select their eligible night zones, limits and special behavior rather than receiving implicit global bonuses.

The visual clone scales around the feet without moving the authoritative Body or enlarging hit geometry. Actual Studio Play measured nine meshes, height 11.14 studs, feet Y=0.5, and a real two-second Locomotion track. Streaming was enabled and damage stayed off. Fresh isolated contracts: 23 world, 26 visual, 5 map and 17 inventory state, all passing.

## Implemented Hunt pilot

Patrol still acquires the closest visible eligible player. During Hunt, visible challengers are considered at most every 0.4 seconds. A challenger must stay at least four studs and 20% closer across samples for at least 0.6 seconds. Switches have a one-second cooldown and do not reset the original pursuit limit. An active Telegraph cannot transfer to another player or a replacement character life.

On loss of sight during Hunt, the guardian can inspect only the last observed point for up to 1.5 seconds. It cannot attack from memory, read a hidden player's location for steering, or traverse a blocked memory step. Current-life, safe-zone, leash, height and range invalidations still end pursuit. A controlled solo Play wall test held zero lateral displacement after the hidden player moved sideways; the guardian advanced toward the prior sighting and then retreated. Nine Hunt policy contracts passed in Studio after the observed RED, for **80/80** isolated contracts including the existing suites.

In a controlled native two-client test (distinct local UserIds `-1` and `-2`), A entered first and acquired Alert. B entered visible at 9 studs while A was 27.62 studs away. Hunt initially moved toward A, then turned after about 0.98 seconds; B's distance fell from 9.79 to 6.19 while A's increased from 22.82 to 24.50, followed by Telegraph. This is observed steering evidence of the switch, not direct inspection of the private target or a full co-op playthrough. Streaming stayed enabled and damage stayed off.

## Design hypotheses for the next iterations

1. **Make the search readable.** Give the player a distinct visual tell when the guardian loses sight and briefly investigates the last observed location. The pilot already separates search from attacking internally, but does not give searching a new visual cue. Measure comprehension and escape opportunities, not just detection range.
2. **A visual counterplay payoff.** Free flashlight and equipped Lumipol already reveal the guardian, not defeat or stun it. Prototype a clear reveal-and-escape objective first; tune a stronger reward such as briefly disrupting the search only after demonstrating that reveal plus route choice is insufficient. Never lock mandatory counterplay behind a pet or purchase.
3. **Night pacing and readability.** Add periods of quiet after pressure, zone-local silhouettes and fog, readable landmarks back to camp, and pre-warning visual changes paired with optional sounds. Do not rely on audio, color alone, flashing, or darkness that obscures controls and escape routes. The fog bonus is a tunable hypothesis, not a reason to strengthen every stat at once.

References: [Creative Assembly, Building Fear in Alien: Isolation](https://www.gdcvault.com/play/1021852/Building-Fear-in-Aliens) for the role of behavior and presentation in fear; [Valve, The AI Systems of Left 4 Dead](https://cdn.cloudflare.steamstatic.com/apps/valve/2009/ai_systems_of_l4d_mike_booth.pdf) for tension/recovery pacing (not a prescribed difficulty system); [Roblox pathfinding guidance](https://create.roblox.com/docs/characters/pathfinding) for blocked paths and streaming constraints. The shared video notes inform mobile/readability hypotheses; they are not game requirements.

## Acceptance after integration

- Use two independently observed clients to test target retention, a substantially closer visible challenger, lost sight, cover, safe zones and character replacement. Compare the same behavior in Day and fog Night.
- Use real player input and record visible tells, target decisions and recovery. Check mobile and muted/reduced effects. No real-damage or persistence claim until separately verified.
