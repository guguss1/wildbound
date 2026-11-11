# Wildbound beasts (Nest Heist phase 4a)

Viper and Pouncer, the two global beasts of the beast pack (`docs/design/beast-pack/`), with one director. Built on 2026-11-10; tasks NB1 to NB7 in `odd/tasks/wildbound-capture-extraction-horror.md`. Gargoyle and Mire exist as config only until Cementerio and Pantano exist.

## Where things live

| Piece | Source | Studio |
| --- | --- | --- |
| Numbers and shared geometry (lane, circle, arc) | `src/wildbound/WildboundBeastConfig.luau` | `ReplicatedStorage.WildboundBeastConfig` |
| Director: rolls, multipliers, budget, cooldowns, release | `src/wildbound/WildboundBeastDirector.luau` | `ServerScriptService.WildboundBeastDirector` |
| Viper and Pouncer state machines and hit checks | `src/wildbound/WildboundBeastEncounters.luau` | `ServerScriptService.WildboundBeastEncounters` |
| Part proxies | `src/wildbound/WildboundBeastProxies.luau` | `ServerScriptService.WildboundBeastProxies` builds `ReplicatedStorage.WildboundBeasts.Models` at start |
| The one scheduler, world adapter, target-only events | `src/wildbound/WildboundBeasts.server.luau` | `ServerScriptService.WildboundBeasts` |
| The target's visuals, tells, sounds, warning line | `src/wildbound/WildboundBeasts.client.luau` | `StarterPlayer.StarterPlayerScripts.WildboundBeastsClient` |
| A landed hit (egg drop, damage) | `BeastHit` in `src/wildbound/WildboundServer.server.luau` | `ReplicatedStorage.WildboundNetwork.BeastHit` (server to server) |

## Rules

- Every 10 s, for each living player outside a safe zone, each beast whose biome holds rolls once: `pEff = clamp(pBase x product, 0, 0.20)`, product capped at x4. Multipliers: night x2, more than 150 studs from the camp centre x1.2, fog or La Silueta's territory x1.5, 180 s or more continuously outside a safe zone x1.3, storm x1 (no weather yet).
- Budget per player: 3 points, 2 encounters; Viper 1, Pouncer 1 (Gargoyle 2, Mire 2). Booked in one call with no yield; a refused win is logged and dropped, never queued. Released exactly once on any end: death, escape, timeout, safe zone, leave, error, no spawn point. Global cooldown 15 s, Viper 35 s, Pouncer 40 s, none within 10 s of a respawn.
- La Silueta stays outside the budget. No beast starts while that player's own Silueta hunts or telegraphs.
- Only the target sees and hears its beast and only the target can be hit. The server simulates positions, tells and hits; the client draws a local clone and never reports anything.
- A hit drops the egg in the arms through `Heist.dropEgg(player, "Hit")` and deals damage only in the private damage mode after a paid trip (the parents' rule); a defeat is the ordinary `Died` flow.

| | Viper | Pouncer |
| --- | --- | --- |
| Spawn | 35 to 70 studs, 0.75 s | 35 to 75 studs, 0.8 s |
| Approach | 14 studs/s into 18 to 30 studs; sidesteps up to 1.5 s for a clear lane | 16 studs/s into 20 to 34 studs; sidesteps between refused tries |
| Tell | Red lane 32 x 4.5 studs, 1.15 s; follows for 0.7 s, then locked 0.45 s | Red circle radius 6.5, 1.3 s, centre frozen after 0.25 s, then a 0.75 s leap |
| Attack | Dash at 60 studs/s along the ground, swept hit, a wall cuts it | Server parabola 10 studs high, one distance check at landing |
| Damage | 35, once per dash | 40, once per jump |
| Recovery | 1.25 s (1.8 s after a wall) | 1.2 s |
| Limits | 3 attacks, 32 s, escape over 100 studs for 4 s | 2 jumps (cap 3), 33 s, escape over 105 studs for 4 s |

Tuning: edit `WildboundBeastConfig` (one table). In Studio Edit, a changed config must be re-parented as a fresh instance before running the suites, because modules that require the original instance keep the cached copy.

## Debug (Studio only, server only)

`ServerStorage.WildboundTelemetry.ForceSpawnBeast:Invoke(name, player)` books through the director with the timers skipped (budget, concurrency, biome, safe zone and Silueta still apply) and returns `ok, encounterId or reason`. `BeastProbe:Invoke(op, value)`: `read` (encounters, budget, the director's log, the last events with server times, counters), `clear`, `end` (an encounter id), `context` (a player's director context). Counters: `Beast_*` attributes on `WildboundTelemetry`, `BeastHitDamage`.

## Replacing a proxy with the real mesh

The meshes in `assets/models/beasts/` need an upload or a manual import first; nothing in the game uploads them.

1. In Studio, Avatar tab, Import 3D: `assets/models/beasts/viper.fbx` (or `viper_static.fbx`), and likewise `pouncer.fbx`. Check the preview size (Viper about 10 studs long, Pouncer about 9 wide); fix the unit or scale once if needed.
2. Set the eye MeshPart's `Material` to `Neon` and colour amber `#FF7A0A` (Viper) or magenta `#FF3FC0` (Pouncer).
3. Make it one Model named exactly `Viper` (or `Pouncer`) with a `PrimaryPart` on the ground under the creature, the head facing that part's LookVector (-Z). Rotate 180 degrees around Y if it faces backwards.
4. Every part: `Anchored` on, `CanCollide`, `CanQuery` and `CanTouch` off. The hitboxes live in the server, not in the model.
5. Put it in `ReplicatedStorage.WildboundBeasts.Models` (start Play once to create the folder, or create `WildboundBeasts/Models` by hand) and save the place. The client always prefers `Models.Viper` over `Models.ViperProxy`; the server never replaces an existing model. Nothing else changes.
6. The red lane and circle are drawn by the client and are never part of the model.

## Not verified

Two or three players (S01, S08 and the "B neither sees nor hears it" rows): one Studio client only; covered by fake-player unit tests and the source contracts (target-only `FireClient`, no server handler on `BeastEvent`). By eye and ear: Studio renders no 3D frame in the background, so the tells were checked by part sizes, positions and the warning text on the client, not by screenshots. Phones, Efectos suaves by hand, a slow network, natural (unforced) spawns at the real odds over a long session.
