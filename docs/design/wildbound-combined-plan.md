# Wildbound combined plan: Nest Heist core, beast pack and current build

Date: 2026-11-10. Sources: the user's master prompt "WILDBOUND — PROMPT MAESTRO DEFINITIVO (Nest Heist)" (pasted in chat on 2026-11-10), the four-beast pack in `docs/design/beast-pack/` (Viper, Pouncer, Gargoyle, Mire, with reference images in `refs/`), and what the game already has on `codex/wildbound-first-playable`.

## 1. What the user's direction now is

Steal an egg from a guarded nest, carry it visibly in your arms, escape the parent with movement skill (sprint plus a new **Burst**), survive beasts and other players (a **bat** knocks the egg loose; anyone can pick it up), and deliver it to your **personal base** around a safe central lobby to incubate a Lumipol companion. Progression: random-stat gloves, a training station, coins. Horror stays: La Silueta (two hits), a per-player threat budget for global beasts (Viper, Pouncer) and biome beasts (Gargoyle in Cementerio, Mire in Pantano).

## 2. Reuse map (what exists vs what is new)

| Master-prompt need | Already in the game | Work |
| --- | --- | --- |
| Nests with a guarding adult, wake, chase, telegraphed attack | Island nests, wake meter, chase 19 for 14 s, pounce, egg recovery, sleep cycle (`WildboundIsland.luau`) | Add the "charge with tell, exposed on miss" pattern; remove any idle fear wait |
| Dynamic nest positions, never moving mid-chase | Spawn graph + 300 s relocation by rarity tier (`WildboundSpawnClock`, wave clock) | Guard: no relocation while a nest is in an interaction or chase |
| Fast steal (0.6-1 s) | Ring + calm + seal capture minigame (`WildboundCaptureSession.luau`) | Fast steal for normal eggs; keep the ring only for rare/special eggs |
| Egg visible in arms, `InNest/Carried/Dropped/Secured/Despawning`, unique id | Eggs bank at the camp chest; carried Lumipol has a fear meter | New server `EggCarry` state machine with ids, arm weld, drop, pickup race |
| Burst 0.8 s x1.7, cooldown 6 s; perfect dodge later | Sprint with stamina (`WildboundStamina.luau`) | New Burst on top of sprint, server-validated |
| Bat PvP (12 s cooldown, 0.45 s stagger, 6 s immunity, no PvP in lobby) | Nothing | New `PvP` service, touch button, server hitbox |
| Lobby with personal bases, delivery station, incubator, collection | Camp + incubator; hub/corral designs (`docs/design/wildbound-open-world-hub.md`, `docs/mechanics/wildbound-hub-systems.md`) | Build bases around the hub; delivery validation; incubator per base |
| Lumipol companions with light | Equip companion, incubator hatch; MeshGen1 Lumipol model in progress | Follow + light + store |
| Random-stat gloves, no special powers | Fixed-effect Guantes/Botas/Chaleco/Amuleto + luck totem (`WildboundGear`) | Replace with rolled stat gloves (decision D2) |
| Training station, coins | Esencia currency, skill tree | Treadmill-style speed training with caps |
| Threat director: per-player rolls every 10 s, 3 points, 2 encounters | Per-player Silueta (`WildboundHunters.luau`), noise/guardian brain | New `BeastDirector` reusing hunters; Viper and Pouncer first |
| Persistent inventory, no data overwrite | Session-only by rule (DataStore forbidden so far) | Needs user approval (decision D1) |
| Biomes Pantano and Cementerio | Offline biome planners exist; Pradera (kids) designed | Plan only for now (Phase 5) |

## 3. Decisions the user must make (asked one at a time)

- **D1 Persistence.** The master prompt needs a persistent inventory (eggs, Lumipols, gloves, upgrades). Until now DataStore use is forbidden. Approve a safe save system (session locking, never overwrite on a failed load)?
- **D2 Gloves.** The master prompt bans special-ability gloves. Today's Chaleco (survive a hit) and Amuleto (fear relief) are special abilities. Replace all four items with random-stat gloves?
- **D3 Kids biome.** Pradera Arcoíris (Nube Gruñona, Abeja Reina event) is not in the master prompt; its next biomes are Pantano and Cementerio. Keep Pradera on the east side, or pause it?
- **D4 Capture minigame.** Fast steal for normal eggs and the ring only for rare eggs (master-prompt preference)?

## 4. Phases (from the master prompt, adapted)

1. **Core:** fast steal, egg in arms with ids, parent charge with tell and exposure, Burst, drop and pickup, delivery to base, death loses the carried egg.
2. **Multiplayer chaos:** bat for everyone, stagger, drop, pickup race, carrier change and parent retargeting, safe-zone protection, anti-chain immunity, three-client test.
3. **Collection and progression:** incubation per base, companions with light, gloves, training, coins, persistence (after D1).
4. **Horror and dynamic world:** alert levels from steals, `BeastDirector`, Viper and Pouncer, La Silueta integration, nests guarded against mid-chase moves, refugios.
5. **Expansion (plan only):** Pantano (Mire, Root), Cementerio (Gargoyle), more species and beasts.

Beast art runs in parallel offline: stylized low-poly models of the four beasts in Blender from `docs/design/beast-pack/refs/`, exported as FBX; entering the game needs either the user's upload approval or the user importing them with the Studio 3D importer.

## 5. Agent roster proposed to the user

| Agent | Model | Why that model | Runs |
| --- | --- | --- | --- |
| Studio writer (phases 1, 2, 4 in order) | Opus 5.5 medium | Multi-system server code, security and TDD | One at a time, after the MeshGen1 agent |
| Blender modeler A: Viper + Pouncer | Opus 5.5 medium | 3D form, rig and export need judgment | Parallel, offline |
| Blender modeler B: Gargoyle + Mire | Opus 5.5 medium | Same | Parallel, offline |
| Phase verifier (read-only) | Sonnet 5.5 high | Mechanical checks: tests, commits, Studio hash match | After each phase |
| Asset and licence researcher | Sonnet 5.5 high | Link and licence collection (Quaternius, Kenney, Poly Pizza, Creator Store) | After a modeler finishes (3-agent cap) |

Cap: at most three agents at once and one Studio writer, per `AGENTS.md`.

## 6. User decisions and open items (2026-11-10, second round)

| # | Topic | Decision or status |
| --- | --- | --- |
| Q1 | Parents' close swing telegraph | Raise 0.45 s to 0.8 s (fair-strike rule). Assigned to the current Studio writer |
| Q2 | Rare-egg minigame | Open: the user wants a new, more fun minigame proposal instead of the ring |
| Q3 | Burst | Open: the user is not convinced; alternatives proposed (timed dodge/parry, vault, slide, decoy) |
| Q4 | Bat | Faster cooldown (Steal-an-Egg feel) and a ragdoll knockback that sends the target flying away from the attacker. Proposal: cooldown 5 s, short ragdoll about 1.2 s, egg drops, immunity 4 s against chain stuns, no PvP in the hub |
| Q5 | MaxPlayers | 8 for now |
| Q6 | Gloves screen | An inventory panel. Plus a chest zone at the base: pay local currency (Esencia), roulette animation reveals the reward, odds shown, prices in the economy config. Esencia only, no Robux |
| Q7 | Pedestal and bag | Open: the user asked what the bag is (the uncommitted expedition materials and items that a defeat partly loses) |
| Q8 | Unwanted gloves | Recycle for a small amount of Esencia |
| Q9 | Walk speed | Lower walk 17.5 to 16 (La Silueta 17): escapes need sprint, dodge or other skills. Assigned to the current Studio writer |
| Q10 | Luck totem | Persisted when bought or earned; single use |
| Q11 | Dusk | A pre-night stage that warns players and gives beasts a small buff |
| V1 | Visibility | The hub, bases, Pradera and beast spawn markers must be visible in Edit mode; runtime builders reuse what exists. Next Studio writer after the current one |
| Q4b | Bat immunity | 3 s instead of 4 s |
| H1 | Hub | Brighter and larger: it is the place to show off creatures |
| H2 | Shops | Small shop spots marked with a circle on the ground; standing on one opens the shop UI |
| P1 | Priority | Finish adding the existing maps (Pradera and the offline layouts: frozen mountains, volcanic lands, rock caves, cryptic ruins, living forest, demon abyss) and the global beasts before new features |
| Q7b | Banking | Entering your own base banks everything (carried egg and bag) and shows a large "Estás a salvo" message |
| Q2b | Rare-egg minigame | "Arrullo": keep the egg inside a moving zone on a bar by holding and releasing (fishing-bar style, original art and naming); replaces the ring for rare eggs |
| Q3b | Burst replacement | "Esquiva perfecta": press during a beast or parent attack telegraph to dodge and gain a short speed boost; replaces Burst |
| U1 | Beast uploads | User authorized uploading the beast FBX models as private assets to their account (no publishing) |
| H3 | Hub size and light | Clearly larger, and well lit even at night |
| H4 | Auto incubation | Walking into your base with an egg places it in a free incubator slot automatically; it hatches on a timer; the first eggs are very fast, later and rarer ones slower |
