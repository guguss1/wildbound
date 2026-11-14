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
- [ ] PF1 Backpack:
  - remove the strap and shell from the creature capsule, keeping the invisible model that audio, fear and pose read;
  - put one back pack on the egg carrier;
  - re-pin the EggCarry and Carry suites.
- [ ] PF2 Treadmill:
  - a large trained walk speed, from 16 up to a high cap, with tuning bounds widened;
  - restore the walk speed on dismount;
  - re-pin the Training, Balance, Tuning and Gear suites.
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

Created 2026-11-14 after the diagnosis. PF0 done 2026-11-14 (commit `chore(sync): pull the live lock-zone scripts into the repo`). Next step: PF1.
