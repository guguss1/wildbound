# Wildbound kids beasts: La Nube Gruñona and La Abeja Reina

## Objective

Put the two kids-biome beasts of the Pradera into the game: La Nube Gruñona (a summoned guardian at the pond) and
La Abeja Reina (an event creature at La Colmena). They must appear in Play, deal no damage, and leave the forest beasts
out of the Pradera.

## Problem and why

The overview listed both as "Design only", and the Pradera had no beasts. The owner asked for both on 2026-11-14. In
the same request the owner asked that every global beast spawn at random with no preferred biome. The previous writer
had already done that (`Config.BIOME_PREFERENCE = false`, covered by the BIOME-OFF cases). This feature keeps that
change as it is.

## Scope

- New pure server modules: `WildboundBeastNube`, `WildboundBeastAbeja` and `WildboundPraderaSites`. The sites module
  holds the sector offsets, the origin, `wants`, `noiseRadius` and `eventOpen`.
- Changed: `WildboundBeastConfig` (both beasts, `SUMMONED`, `CATEGORIES.Event`, `WAVE2`).
  `WildboundBeastDirector` (`summon`; no global cooldown for summoned beasts; `endCooldowns`).
  `WildboundBeastEncounters` (accepts summoned beasts). `WildboundBeasts.server` (registration, summon pass, target
  extras, Pradera close, damage 0 in Meadow, Pegajoso, mark, BiomeEvent watcher, Studio `ForceAbejaEvent`).
  `WildboundBeastProxies` (two proxies). `WildboundBeasts.client` (yellow and honey tells, kids sounds, the Abeja hum,
  hit lines, a gentle bob). `WildboundText` (`BEAST.NubeGrunona`, `BEAST.AbejaReina`).
  `tools/deploy_manifest.py` and its pin.
- Out of scope (see the spec):
  - the Pradera map build
  - the Huevo Real and its spawn (lock zone)
  - parking a bag item and the real 3 s carry
  - Molinillo, Relampino, the Huevo de Cera, the rainbow, the Épica x2 spawn
  - sun circles as safe zones, per-guardian zones
  - Fear.client changes, rigs, monetization

## Constraints

- Lock zone untouched: WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock, WildboundWorldClient,
  their suites, SistemaSonriente.
- The parallel writer's files untouched: WildboundBalance, its suite, `odd/tasks/wildbound-2-0.md`, the overview,
  `tools/studio-fresh-runner.luau`.
- Damage 0 always. BeastHit is invoked with 0, which only knocks a carried egg loose.
- No Workspace edits, no save or publish, no uploads.
- Procedural Part proxies only.
- `BiomeEvent` is read only.
- Every number is PROPUESTA, taken from the design docs `wildbound-biome-pradera.md` s5 and s6 and from
  `wildbound-beast-spawn.md` s2.

## TDD

- **Mode:** Strict TDD, on. The source is the task brief.
- **Runner:** the Studio suites in ServerStorage, called on fresh clones in Edit mode.
- **Clone patching:** Edit-mode `require` returned a stale cached `WildboundBeastConfig`, so `homeBiome` was nil. The
  harness therefore clones each module under test into a temporary `ServerStorage.KidsBeastsTestClones` folder and
  points that clone's Config and Attack requires at fresh clones in the same folder. The folder is removed after the
  run, and the purity cases read the original sources.
- **Python:** `python -I -B -m unittest discover -s tools -p "test_*.py"`.

## Checklist

- [x] KB-0: Studio sources of every touched script equal the repo pre-edit text (length and Adler-32). Done 2026-11-14.
- [x] KB-1: Director summon. No global cooldown for summoned beasts, Yawn nap cooldown, Meadow home, points 0 but
  MAX_ACTIVE counts. RED 34/39, GREEN 39/39.
- [x] KB-2: Nube behaviour and its suite (11 cases). RED: the module was missing. GREEN 11/11.
- [x] KB-3: Abeja behaviour, the sites module and its suite (10 cases). RED: the module was missing. GREEN 10/10.
- [x] KB-4: server wiring, proxies and client, with the Wiring suite updated (counts 8 and 10, the new start line).
  RED 29/37, GREEN 37/37.
- [x] KB-5: Text keys. RED (KB-5 failed), GREEN (KB-5 passes).
- [x] KB-6: deploy manifest and pins. `test_deploy_manifest` 25/25.
- [x] KB-7: Studio deploy and read-back. 15 scripts match the repo (length and Adler-32, CRLF to LF, trailing
  newlines trimmed). Every source compiles (`loadstring` ok).
- [x] KB-8: solo Play check, Studio, the place's own WildboundPradera map.
  - Teleported to 16 studs from the pond. After the respawn grace a Nube was summoned by presence (no force).
  - Nube phases: Calm, Notice, Chase, Telegraph. It struck twice and both hit. Health stayed 100/100,
    BeastHitDamage stayed 0, and the mark attribute was set.
  - `ForceAbejaEvent(true)` then a walk near La Colmena summoned an Abeja. Phases: Wake, Guard, Heard, Search,
    Telegraph, After. Two dives missed while walking.
  - The Nube ended `GiveUp` (the target was more than 60 studs away after the teleport).
  - `ForceAbejaEvent(false)` ended the Abeja with `EventEnded`.
  - Beast errors 0. No beast-script error lines in the console.
- [ ] KB-9: a Pegajoso sting and a Ráfaga push seen in Play. Suites only so far: the Play dives missed, and the
  second Nube hit was not inspected.
- [ ] KB-10: client view check (proxies visible, yellow and honey tells, hum). Not observed. No screenshot was taken.

## Evidence

- Studio suites in Edit, after deploy:

  | Suite | Result |
  |---|---|
  | Director | 39/39 |
  | Encounters | 24/24 |
  | Attack | 9/9 |
  | Streamer | 8/8 |
  | Root | 9/9 |
  | Gaze | 7/7 |
  | Lurker | 7/7 |
  | Nube | 11/11 |
  | Abeja | 10/10 |
  | Wiring | 37/37 |
  | Text | 17/18 |

  The Text failure is NB3, "source inventory missing". It also fails before this change: the harness does not pass the
  inventory, world and HUD sources that the case needs.
- Python: 1225 tests, 5 failures, all known before this change: test_lumipol_v2 v1 files, 3 economy-config export
  tests, and 1 audio-catalog test from the treadmill client.
- Nothing is committed.

## Next step

1. Observe KB-9 and KB-10 in Play: a sticky sting, a gust, and the client view.
2. Tune the PROPUESTA numbers with the owner.
3. Decide the Abeja window offset (an open gap in the design doc).
