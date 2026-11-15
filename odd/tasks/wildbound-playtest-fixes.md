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
- [x] PF3 Creature hotbar:
  - own pad only;
  - rebuild tools on respawn;
  - a creature deposited in the farm stops following (unequip);
  - a Lumipol icon placeholder, until an icon upload is approved.
  - Route: direct inline (one module plus small additive server wiring; the module was read in full first). Strict TDD
    on, runner: fresh loader in Edit with the `tools/studio-fresh-runner.luau` SPECS.
  - Pulled first: Studio's `WildboundText` was ahead by the two Flanfuria beast lines (separate commit
    `chore(sync): pull the live Flanfuria beast lines into WildboundText`). Server, Toolbar, State and the
    Incubator suite matched the repo before any write (Server 207220 11fe5162, Toolbar 7221 b56766e2).
  - `WildboundCreatureToolbar`: deposit only on the player's own pad (the any-pad-within-20-studs fallback is
    gone) and only for a registered creature; `depositInFarm` calls the injected `unequip`; new `pickUp` (back to
    the hotbar, never equips), `stow` (newborn) and `respawn` (waits for the new Backpack); `syncPlayer` keeps one
    tool per creature and removes duplicates and tools of creatures no longer owned or in the farm. Words moved to
    `Text.FARM` (neutral Spanish; the old "Entrá..." literal is gone). `tagged`/`players` deps for the fakes.
  - `WildboundServer` (lock zone, additive): an `unequip` dep (`state:unequip`, clears the companion attributes,
    `syncCompanion`); the hatch step stows a newborn the State made the companion (`born.equipped`) and the notice is
    `Text.LOOP.hatchTitle` + `Text.LOOP.hatchStored`; a new character calls `creatureToolbar:respawn`.
    `WildboundState` is unchanged (its NS3 still equips the newborn; the server puts it back).
  - Icon: no Lumipol icon image exists in the place (no ImageLabel/ImageButton/Decal/Tool with a Lumipol or icon
    image; the repo ids next to Lumipol are mesh UV textures, not icons). `TextureId` stays empty, Name "Lumipol",
    ToolTip from `Text.FARM.toolTip`. An icon upload (candidate `assets/blender/lumipol-forest-sprite-v2-front.png`)
    needs the user's approval.
  - Tests: new `tests/WildboundCreatureToolbar_Test.luau` (CT-1..CT-10, fakes only), added to
    `tools/deploy_manifest.py`, `tools/test_deploy_manifest.py` and the runner SPECS; `tests/WildboundIncubator_Test.luau`
    NS3 re-pinned to PF3 (the newborn goes to the hotbar; deliberately changed).
  - RED (tests written, sources unchanged): CreatureToolbar_Test 1 passed, 9 failed; Incubator_Test 6 passed, 1
    failed. GREEN: CreatureToolbar_Test 10/0; Incubator_Test 7/0; Text_Test 19/0; MechanicsWiring_Test 9/1 (the
    known W1 `maxCarry` drift, unchanged); Hub_Test 22/1 (the known HB-T3, unchanged).
  - Fingerprints (repo = Studio after the write, LF, trailing newlines stripped, bytes + Adler-32):
    WildboundCreatureToolbar 9557 9c35a497, WildboundServer 207961 bcbc47b1 (compiles), WildboundText 34242 ad48cf82,
    WildboundCreatureToolbar_Test 10662 2d8e96df, WildboundIncubator_Test 6465 7524302a.
  - Play (lock "PF3", cleared after; Play stopped): IslandProbe "egg" banked one egg; at the own base it
    incubated and hatched: one "Lumipol" tool in the Backpack, no companion out (stowed). Equipped through the Action
    remote: one companion follows. Tool activated on the own pad: a `WildboundFarmCreature` in Base1, companion gone,
    no creature tool. Prompt "Guardar en la barra": back to one tool, not equipped. `LoadCharacter`: exactly one tool
    in the new Backpack. Activated on another base's pad: refused, tool kept. No script errors; saves in memory mode.
    Nothing saved or published.
  - Python: 1186 tests, 1 failure (known `test_lumipol_v2` V1IsKept).
  - Open: the farm is still memory-only (PF4); the icon upload waits for approval.
- [x] PF4 Persistent farm in State: farm list, slot cap from `Balance.farm.startSlots`, a schema step, and a rebuild on join.
  - Route: direct inline (State, Record, a new sibling step, Save, the toolbar and one Text line; every file read in
    full or around each edit first). Strict TDD on, runner: trimmed fresh loader in Edit (the
    `tools/studio-fresh-runner.luau` SPECS and SIBLINGS, held in a temporary ServerStorage ModuleScript, removed after).
  - Studio matched the repo before any write: State 48395 798a1eea, Record 26820 5e460b99, TotemRecord 4936 ba6f99c3,
    Save 15339 29773d1b, CreatureToolbar 9557 9c35a497, Text 34242 ad48cf82 and the six suites.
  - `WildboundState`: `State.FARM_SLOTS = 4` (the 2.0 balance's farm.startSlots; WildboundBalance stays unwired, so the
    new `tools/test_wildbound_farm_slots.py` keeps the two equal); the farm list is made on first use (RT-2 unchanged);
    `placeInFarm(key, uid, alive, slots)` (registered only, once, FarmFull at the cap, puts the companion down and says
    so), `takeFromFarm` (never equips), `equip` refuses `InFarm`; the snapshot carries `farm` (a copy) and `farmSlots`.
  - New `WildboundFarmRecord` (ServerScriptService, sibling of Record, TotemRecord pattern): schema 4 -> 5 step that
    only adds an empty farm, a frozen ladder, validation (a list of durable IDs, each registered, once, never the
    companion, at most CAP 12 = the top of the farm.maxSlots range) and the profile seam (no field for an empty farm; a
    session ID refuses the save). `WildboundRecord`: SCHEMA = FarmRecord.SCHEMA (5), `farm` known, blank `farm = {}`,
    validate, fromProfile/toProfile, `MIGRATIONS = FarmRecord.ladder(...)`. A malformed farm is never repaired: it
    fails validation, so the load is quarantined and nothing is written.
  - `WildboundSave`: the farm goes through the durable ID map (only registered creatures) and is part of the digest, so
    a place or a pickup marks the profile dirty.
  - `WildboundCreatureToolbar`: placing and pickup go through State (`placeInFarm` after the server's `unequip`,
    `takeFromFarm`); a full farm refuses before anything changes (`Text.FARM.farmFull`); `syncFarm` (run by every
    `syncPlayer`, so on join, hatch, pickup and respawn) rebuilds the saved farm on the own pad once, in a small grid,
    and removes models whose creature left the farm. The memory table only holds models now.
  - No farm income (the no-AFK-income rule; left for a later user decision). WildboundServer untouched.
  - Tools: `WildboundFarmRecord` in `tools/deploy_manifest.py` and `tools/test_deploy_manifest.py`; the runner's
    SIBLINGS lists it for WildboundRecord. Its cases live in WildboundRecord_Test (RT-26, RT-27).
  - Tests: State_Test PF4-S1/S2; Record_Test RT-1, RT-14, RT-24 re-pinned to schema 5 (deliberate) plus RT-26
    (migration, malformed farms, cap) and RT-27 (round trip, JSON, State load, session IDs); TotemRecord_Test TR1/TR3
    re-pinned (the record goes past schema 4); Save_Test SV-22 (durable IDs, dirty, rejoin, pickup saved);
    CreatureToolbar_Test CT-1 (farmFull) plus CT-11..13; MechanicsWiring_Test W4 re-pinned to `Record.SCHEMA =
    FarmRecord.SCHEMA`.
  - RED (suites written, sources unchanged): State 64/16 (2 PF4 + 14 pre-existing), Record 23/4, TotemRecord 6/1,
    Save 21/1, CreatureToolbar 9/4, MechanicsWiring 8/2 (W4 + the known W1), Persistence 31/0.
  - GREEN: State 66/14 (the 14 are pre-existing EconomyConfig drift: bag capacity 12, pay values; not PF4), Record 27/0,
    TotemRecord 7/0, Save 22/0, CreatureToolbar 13/0, MechanicsWiring 9/1 (the known W1), Persistence 31/0,
    Incubator 7/0, Text 19/0.
  - Fingerprints (repo = Studio after the write, every source compiles): WildboundFarmRecord 4296 771da357,
    WildboundRecord 28170 ef81d498, WildboundState 50577 9d000684, WildboundSave 15820 1a15da1c, WildboundText 34377
    63abfab2, WildboundCreatureToolbar 12469 553a7c47, WildboundState_Test 79661 21cc2a26, WildboundRecord_Test 29981
    d419e44d, WildboundTotemRecord_Test 7008 a65f1046, WildboundSave_Test 22146 85960d6b, WildboundCreatureToolbar_Test
    15018 08c71315, WildboundMechanicsWiring_Test 18769 8b59f3e1.
  - Solo Play (PlayLock `PF4`, cleared after; Play stopped): IslandProbe "egg" banked one egg; at the own base (Base1)
    it hatched into one "Lumipol" tool. Equipped and activated on the own pad: a `WildboundFarmCreature` (wb:2) in
    Base1, no creature tool, no companion attribute. The model was then destroyed by hand and the character respawned:
    the model came back (only State's farm list could rebuild it) and no tool. The prompt "Guardar en la barra" brought
    back one tool, no model, not equipped; a second respawn kept one tool and no model. No script errors; saves in
    memory mode. Leave and rejoin cannot be done in one Play: the record round trip is covered by RT-27 and SV-22.
  - Python: 1188 tests, 1 failure (known `test_lumipol_v2` V1IsKept).
- [x] PF5 Roulette in the hub:
  - station;
  - server roll and atomic Esencia spend;
  - prizes limited to the supported kinds;
  - persisted free spin and pity;
  - Spanish UI with odds.
  - Route: direct inline (a new service module, a new record step, a new LocalScript and small additive edits to
    State, Record, Save, Text, the Roulette table and the server). Strict TDD on, runner: trimmed fresh loader in Edit
    (the `tools/studio-fresh-runner.luau` SPECS and SIBLINGS for the PF5 suites, held in a temporary ServerStorage
    ModuleScript, removed after).
  - Studio matched the repo before any write: State 50577 9d000684, Server 207961 bcbc47b1, Record 28170 ef81d498,
    Text 34377 63abfab2, Save 15820 1a15da1c, Roulette 19762 bc6f4bda and the suites.
  - `WildboundRoulette`: status "wired"; CONFIG stays the 2.0 proposal (Balance mirror unchanged). New `Roulette.LIVE`,
    the wired hub table: Esencia and banked materials only (the economy has no roulette path for gloves, boosters,
    consumables or special eggs), re-weighted to Esencia 40 / materials 60, 11 prizes (new `nightbloom5` Epica and
    `forestChest` Legendaria), Comun 68 / Rara 22 / Epica 7 / Legendaria 3, same 45 Esencia, one free spin, Rara+ pity
    every 10, hub only. Esencia EV 12.01 per paid spin with pity (cap 30; scaling the 2.0 share up would pay about 35).
  - `WildboundState:spinRoulette(key, alive, distance, range, draw)`: check, pay 45 through the local purchase helper,
    grant (Esencia to `ember`, materials to `banked`), save the state; anything else is refused before paying
    (UnsupportedPrize). The state is made on first use (RT-2 unchanged); the snapshot carries `roulette`.
  - New `WildboundRouletteRecord` (schema 5 -> 6, sibling of Record): `roulette = { freeSpinUsed, pityCount,
    paidSpins }`, the unused state on migration, validation (exact fields, counts, pityCount <= paidSpins) that
    quarantines a malformed one, no profile field while unused. `WildboundRecord` SCHEMA 6; `WildboundSave` digest
    includes `roulette`.
  - New `WildboundRouletteService` (ServerScriptService), started by `WildboundServer` in a `do` block (no new
    top-level local) with `Random.new()`: builds one station at runtime at (HUB_X - 17, HUB_Z + 17) in the hub plaza,
    one ProximityPrompt "Ver la ruleta" with no owner gating; remote `WildboundNetwork.Roulette` reads only "open" or
    "spin"; one spin per 1.6 s, alive and within 12 studs of the server-side root, then the server roll through
    `State:spinRoulette`; the result refreshes the HUD through `send`.
  - New `WildboundRouletteClient` LocalScript: the panel lists every prize's odds (Spanish label, rarity, percent),
    the price or "Tirada gratis", the pity counter and the balance before any spin; "Girar" sends "spin", a short spin
    over the rows lands on the server's prize. `Text.ROULETTE` holds every word.
  - Tools: `tools/wildbound_roulette_sim.py` parses LIVE too; `docs/balance/wildbound-2-0-roulette.md` regenerated with
    a "Live hub table (PF5)" section (seed 7: chi-square 3.52, df 10). Manifest rows for the record step, the service,
    its suite and the client; the runner's SPECS and SIBLINGS.
  - Tests: new `tests/WildboundRouletteService_Test.luau` (RS-1..RS-9, fakes); Roulette_Test R1 re-pinned (wired) plus
    R16/R17; State_Test PF5-S1..S3; Record_Test RT-1, RT-14, RT-26 re-pinned to schema 6 (deliberate) plus RT-28/RT-29;
    Save_Test SV-23; MechanicsWiring_Test W4 re-pinned (`Record.SCHEMA = RouletteRecord.SCHEMA`, digest reads
    `view.roulette`); Text_Test PF5; Python LiveTableTests (7).
  - RED (suites written, sources unchanged): Roulette 14/3, State 66/17 (3 PF5 + 14 pre-existing), MechanicsWiring 8/2
    (W4 + the known W1), Text 19/1, Record, Save, Persistence and TotemRecord ERROR (sibling WildboundRouletteRecord
    missing), RouletteService ERROR (module missing); Python roulette sim 7 errors.
  - GREEN: Roulette 17/0, RouletteService 9/0, State 69/14 (the 14 pre-existing EconomyConfig drift), Record 29/0,
    Save 23/0, Persistence 31/0, TotemRecord 7/0, Text 20/0, MechanicsWiring 9/1 (the known W1), CreatureToolbar 13/0,
    Incubator 7/0, Balance 24/0.
  - Fingerprints (repo = Studio after the write, every source compiles): WildboundRoulette 22814 177902e1,
    WildboundText 35825 d14bb9df, WildboundRouletteRecord 4629 704e4511, WildboundRecord 29616 20dfcd56,
    WildboundSave 16001 788d1554, WildboundState 53376 ec12c43e, WildboundRouletteService 10600 055fe676,
    WildboundRouletteClient 7780 50dff463, WildboundServer 208864 cea678ec, WildboundRoulette_Test 23049 c2372c8a,
    WildboundRouletteService_Test 12374 1623bd4b, WildboundState_Test 84403 7c682fde, WildboundRecord_Test 34210
    da1f5410, WildboundSave_Test 23310 a99b8a49, WildboundMechanicsWiring_Test 19129 214d69a2, WildboundText_Test
    22740 e4550fde.
  - Solo Play (PlayLock `PF5`, cleared after; Play stopped): the station stood at (265, 14) with its prompt; "open"
    showed the panel with 11 odds rows, "Tirada gratis", the pity line (10) and 0 Esencia. The free spin through the
    remote gave 10 Fogbark (cost 0) and the panel switched to "Tirada: 45 de Esencia". A paid spin with 0 Esencia was
    refused ("Te faltan 45 de Esencia para girar.") and a second one inside 1.6 s was refused as busy. After the
    GearProbe "fund" (500 Esencia): a paid spin gave 45 de Esencia (Rara, pity counter stays 10) and the next one 25 de
    Esencia (480 left, counter 9). No script errors; saves in memory mode. The panel's DisplayOrder was raised to 35
    after Play (the base guide's tutorial card covered the buttons). Screenshot:
    `assets/exports/forest-kit/captures/pf5-roulette-hub-desktop.jpg`. Not checked in Play: the prompt's own trigger
    (the probe used the same server `open` path) and a rejoin (covered by RT-29 and SV-23).
  - Python: 1195 tests, 1 failure (known `test_lumipol_v2` V1IsKept).

## Checks

- Studio suites named in each task, run through the fresh-clone loader.
- `python -I -B -m unittest discover -s tools -p "test_*.py"`.
- A solo Play per task.

## Progress

Created 2026-11-14 after the diagnosis. PF0 done 2026-11-14 (commit `chore(sync): pull the live lock-zone scripts into the repo`). PF1 done 2026-11-14
(commit `fix(carry): one backpack, only while carrying an egg`). PF2 done 2026-11-14
(commit `feat(training): a large treadmill walk speed`). PF3 done 2026-11-14
(commit `feat(farm): own-pad farm and a hotbar home for creatures`). PF4 done 2026-11-14
(commit `feat(farm): save the base farm in the record (schema 5)`). PF5 done 2026-11-14
(commit `feat(roulette): a hub roulette with server rolls and saved pity (schema 6)`). All PF tasks are done; next step:
the user's open product questions.

## Review follow-up (2026-11-14)

Adversarial review of 6c3f4ec..3f8fb2a: no blocking findings. Fixed after it:

- `WildboundCreatureToolbar` places in the farm before unequipping, so a refused place leaves the companion unchanged.
- `Text.ROULETTE.oddsNote` no longer claims equal odds under pity.

Studio matches the repo for both (Toolbar 12504/3128789211, Text 35833/4249861137). CreatureToolbar 13/0, Text 20/0.

Open for the user:

- Decided 2026-11-14 ("Que valga con huevo"): the trained walk also applies while carrying. Kept as built in PF2.
- (was open) Whether the trained walk should also apply while carrying. It does now: about 34 at the top level, against La Silueta 17-18 and the parents 19.
- Retuning the threats.
- The Lumipol icon upload (needs approval).
