# Wildbound playtest fixes (2026-11-14)

## Objective

Fix what the user found in a solo playtest on 2026-11-14, one task at a time:

- no roulette;
- two backpacks;
- a treadmill that does nothing;
- a hatched creature that should go to the hotbar with a Lumipol icon and can be placed in the base farm.

## Problem and evidence

A read-only diagnosis ran on 2026-11-14 (workflow `wf_0c08a4a4-6ff`, five Opus agents). Studio was in Play, so the live server source could not be read.

- **Roulette:** `WildboundRoulette` is unwired (T09b never built).
  - No station, remote, server path or UI exists.
  - Spending Esencia needs a new additive `State` method and a `WildboundServer` bindable.
  - Persistence needs a schema step.
- **Backpacks:**
  - A carried creature gets a back capsule: `WildboundServer` `buildCapsule` adds a strap and a glass shell on UpperTorso.
  - The egg rides in the arms (`Heist.syncEggArms`, `EggHold` on the root).
- **Treadmill:**
  - `WildboundTraining` `WALK_CAP = 16` equals the base walk, so training never adds speed.
  - The bonus is skipped while carrying.
  - `WildboundTreadmillService.dismount` does not restore `WalkSpeed`, which it sets to 0 while mounted.
  - The live onLap and onDismount are only in Studio's `WildboundServer`.
- **Hatch, hotbar and farm:**
  - `WildboundCreatureToolbar` is wired live (a `WildboundFarmCreature` was seen in Base1), but not in the repo's server.
  - Tools have no icon (no `TextureId`).
  - The farm is memory-only.
  - A deposited creature still follows as companion.
  - Tools are not rebuilt on respawn.
  - The deposit falls back to any pad within 20 studs.

## User decisions (2026-11-14)

- The teammate's lock zone may be touched for these fixes ("Sí, tocalos").
  - Changes stay small and additive.
  - Studio's live version is pulled into the repo before any edit.
- **Backpack:** exactly one, only while carrying an egg. It marks "I carry something that has not hatched yet". Carrying a creature shows no bag.
- **Treadmill:** speed gains must be large, "como Steal an Egg, muchísimo".
- **Farm:** a creature placed in the base farm stops following the player. It can be put back in the hotbar.
- **Roulette:** in the hub; pity Rara+ kept (research recommendation, `odd/tasks/wildbound-2-0.md` T09a).

## Scope and constraints

- One task per work unit, each with Strict TDD in Studio (RED then GREEN), a solo Play check where it applies, and one commit.
- Studio target: instance `cc66c65c-53d0-44ea-9fbf-199f725a7b85`, place 122652861404212.
- Never overwrite a Studio Source that differs from the repo before pulling it.
- No publish, no monetization.
- An asset upload (the Lumipol icon) needs separate explicit approval.
- A failed load must never overwrite saved data. Schema steps go through `WildboundRecord`.

## Checklist

- [x] PF0 Pull the live lock-zone scripts into the repo, read-only on Studio: WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock, WildboundWorldClient and their suites.
  - Route: direct inline (one mechanical sync; no Studio Source written). Studio was in Edit; no Play needed.
  - Pulled (Studio was ahead; fingerprints after the write, LF, trailing newlines stripped, bytes + Adler-32, repo = Studio):
    WildboundServer 207073 4f53130b, WildboundState 48395 798a1eea, WildboundEggCarry 14881 7ae344ee,
    WildboundWorldClient 63600 c6822723, WildboundEggCarry_Test 39209 a9356908, WildboundBat_Test 17721 3432072e,
    WildboundMechanicsWiring_Test 18689 85aad9da (new in the repo).
  - Already equal, not rewritten: WildboundBatKnock 7579 ce96d3b6, WildboundBatKnock_Test 7408 b023f099,
    WildboundTreadmillService 9436 cb93650c, WildboundCreatureToolbar 7221 b56766e2.
  - `tests/WildboundMechanicsWiring_Test.luau` added to `tools/deploy_manifest.py`, `tools/test_deploy_manifest.py` and the
    fresh runner's SPECS (`tools/test_studio_fresh_runner.py` and `test_deploy_manifest.py` pass).
  - Live baseline (fresh loader in Edit, before any PF edit): WildboundBat_Test 13/0; WildboundMechanicsWiring_Test 9 passed,
    1 failed; WildboundEggCarry_Test 29 passed, 9 failed. The failures are pre-existing Studio drift (multi-egg carry up to
    the bag capacity, `EggCarry.steal(..., maxCarry)`, STEAL_HOLD 0.5, PICKUP 0.25, the chest calls `Heist.secureAll`); the
    suites were not re-pinned in PF0.
  - Live wiring found: `WildboundTreadmillService` is required at server line 3937 and started with `onDismount` (calls
    `applyCarry`, which restores WalkSpeed because `dismount` clears `mounted` before the callback) and `onLap`
    (`State:trainByRunning`: +1 walk level up to `Training.live.MAX_LEVEL` and 5 Esencia per lap, sets
    `WildboundTreadmillBuffUntil` = now + 60). `applyCarry` forces 0 while mounted (line 397). `WildboundCreatureToolbar` is
    required at line 3969; `syncPlayer` runs on hatch (`stepIncubators`, line 574) and on every new character
    (`bindCharacter`, deferred, line 3459).
- [x] PF1 Backpack:
  - remove the strap and shell from the creature capsule, keeping the invisible model that audio, fear and pose read;
  - put one back pack on the egg carrier;
  - re-pin the EggCarry and Carry suites.
  - Route: direct inline (one server function plus two suites). TDD on (task method), runner: fresh loader in Edit (a
    trimmed copy of `tools/studio-fresh-runner.luau` with the same SPECS, held in a temporary ServerStorage StringValue,
    removed after).
  - Change: `buildCapsule` no longer builds the Strap or the Base ring; the Shell is an invisible SmoothPlastic mount
    (Transparency 1) moved to `back + 0.65`, so the creature sits on the back with no bag. The capsule model, its Uid,
    Species, Mood, SoundCue and Warded attributes, the Seat joint and the mood light stay. The egg pack
    (`Heist.syncEggArms`, `WildboundEggCarried`) was already the single live pack and is unchanged; its part names stay
    because SistemaSonriente's HuevoSonriente dresses them.
  - Suites re-pinned to live behaviour (pulled in PF0): steal hold 0.5 / rare 0.75 / floor 0.35, pickup 0.25, several
    eggs up to the bag capacity (`maxCarry`), the chest's `Heist.secureAll`, a second egg in the same bag in State.
  - RED (suites written to Studio, server unchanged): WildboundCarry_Test 12 passed, 1 failed (PF1 case);
    WildboundEggCarry_Test 38 passed, 1 failed (PF1 case; the 9 pre-existing failures now pass).
  - GREEN: WildboundCarry_Test 13/0, WildboundEggCarry_Test 39/0, WildboundBeastWiring_Test 49/0 (reads
    `WildboundEggCarried`), WildboundBaseZone_Test 8 passed, 1 failed (BZ7, pre-existing and unchanged).
  - Fingerprints (repo = Studio after the write): WildboundServer 206888 f1f3e4b9 (was 207073 4f53130b, checked just
    before writing), WildboundEggCarry_Test 41622 34ea7029, WildboundCarry_Test 10960 93e19195.
  - Solo Play (PlayLock `PF1`, cleared after): HeistProbe steal of Egg:20 gave exactly one `WildboundEggCarried` on the
    R15 character, `BackpackHold` on UpperTorso, egg art visible in the pack's top; a second steal (Egg:18, two eggs
    carried) still showed one pack. No server errors. Screenshot:
    `assets/exports/forest-kit/captures/pf1-egg-backpack-desktop.jpg`. Not checked in Play: a carried creature (the
    capture probe's seal accepts probe keys only), covered by the source suite.
  - Python: 1186 tests, 1 failure (known `test_lumipol_v2` V1IsKept).
  - Not re-pinned: WildboundMechanicsWiring_Test W1 (`canSteal` without `maxCarry`), outside PF1's suites.
- [x] PF2 Treadmill:
  - a large trained walk speed, from 16 up to a high cap, with tuning bounds widened;
  - restore the walk speed on dismount;
  - re-pin the Training, Balance, Tuning and Gear suites.
  - Route: direct inline (one rule module, its schema, two comment/record edits, one server hook, four suites). TDD on
    (task method), runner: trimmed fresh loader in Edit (same SPECS, held in a temporary ServerStorage StringValue,
    removed after).
  - Change: `WildboundTraining` WALK_STEP 0.25 -> 2, MAX_LEVEL 4 -> 17, WALK_CAP 16 -> 50, COST_GROWTH 1.6 -> 1.2
    (level 17 costs 555 instead of about 55,000). `walkSpeed` now also trains a carrier: a slowed walk keeps its carry
    share of the trained walk (one egg: 11/16, so 34.4 at the top level; untrained carriers are unchanged). Sprint and
    Burst never slow a trained walk (`Stamina.speed` keeps the faster). `WildboundTuningSchema` ranges: WALK_STEP 0..5,
    MAX_LEVEL 0..30, WALK_CAP 16..60. `WildboundBalance.LIVE.training` and the `treadmill.speeds` range (16..60) follow;
    the 2.0 pack's proposed treadmill ladder (16..21, six levels) is unchanged, so the economy simulator input stays.
  - Dismount: already restored live (`onDismount` -> `applyCarry`; `dismount` clears the mount first); now pinned by TR-8.
  - Lap: `onLap` still gives +1 level per 8 s lap up to MAX_LEVEL and 5 Esencia; a level-up lap now tells
    `Text.TRAINING.trained` (level and new walk speed) before the Esencia line. The HUD keeps the first sentence.
  - RED (suites written, sources unchanged): Training 3 passed, 5 failed; Balance 21/3; Gear 14/1; Tuning 14/2 (1 new);
    Hub 22/1 (HB-T3, pre-existing).
  - GREEN: Training 8/0, Balance 24/0 (B23 liveFrom matches the live modules), Gear 15/0, Tuning 15 passed, 1 failed
    (DT1 Eggs.STEAL_HOLD schema 0.8 vs module 0.5, pre-existing Studio drift), Hub 22 passed, 1 failed (HB-T3,
    pre-existing).
  - Fingerprints (repo = Studio after the write): WildboundTraining 4053 dbee4363, WildboundTuningSchema 41284 628a8faa,
    WildboundBalance 26840 e8ce415d, WildboundGear 7481 f4a07302, WildboundServer 207220 11fe5162 (was 206888 f1f3e4b9,
    checked just before writing; it compiles), WildboundTraining_Test 8626 a717f250, WildboundBalance_Test 19120
    2a24cbc2, WildboundTuning_Test 21369 1b343539, WildboundGear_Test 22034 94009980.
  - Solo Play (PlayLock `PF2`, cleared after): WalkSpeed 16 before; mounted the Base1 belt (WalkSpeed 0 while mounted,
    progress cycling every 8 s); dismounted by jumping: WalkSpeed 26, notice "Entrenamiento: nivel 5 de 17. Caminas a
    26,00 studs/s." No script errors. Studio saves were in memory mode.
  - Python: 1186 tests, 1 failure (known `test_lumipol_v2` V1IsKept); `test_wildbound_economy_sim_v2` re-pinned to the
    live COST_GROWTH 1.2 and 17 levels.
  - Not retuned: La Silueta and the parents' speeds; a trained walker outruns them (product question).
  - Seen, not pulled: Studio's `WildboundText` is ahead of the repo by the Flanfuria beast lines (not PF2's; left for the
    sync).
- [ ] PF3 Creature hotbar:
  - own pad only;
  - rebuild tools on respawn;
  - a creature deposited in the farm stops following (unequip);
  - a Lumipol icon placeholder, until an icon upload is approved.
- [ ] PF4 Persistent farm in State: farm list, slot cap from `Balance.farm.startSlots`, a schema step, and a rebuild on join.
- [ ] PF5 Roulette in the hub:
  - station;
  - server roll and atomic Esencia spend;
  - prizes limited to the supported kinds;
  - persisted free spin and pity;
  - Spanish UI with odds.

## Checks

- Studio suites named in each task, run through the fresh-clone loader.
- `python -I -B -m unittest discover -s tools -p "test_*.py"`.
- A solo Play per task.

## Progress

Created 2026-11-14 after the diagnosis. PF0 done 2026-11-14 (commit `chore(sync): pull the live lock-zone scripts into the repo`). PF1 done 2026-11-14
(commit `fix(carry): one backpack, only while carrying an egg`). PF2 done 2026-11-14
(commit `feat(training): a large treadmill walk speed`). Next step: PF3.
