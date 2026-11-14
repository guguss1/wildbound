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

- [ ] PF0 Pull the live lock-zone scripts into the repo, read-only on Studio: WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock, WildboundWorldClient and their suites.
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

Created 2026-11-14 after the diagnosis. Next step: PF0 (needs Studio in Edit mode).
