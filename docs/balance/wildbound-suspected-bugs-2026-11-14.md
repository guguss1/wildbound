# Wildbound suspected bugs, 2026-11-14

Read-only diagnosis of three Studio suite failures that appeared after the Studio sync commit `34eab83` ("pull 97 live Studio scripts into the repo"). Nothing was changed in the repo or in Studio. Studio was read in Edit (placeId 122652861404212) with Source probes only; no suite was run and no Play was started.

Shared root cause: the sync brought live values that someone edited in Studio without updating the paired schema, test or document. The commits before the sync agree with each other; the sync commit is the only one that introduces each value below (`git log -S`).

## Summary

| Suite and case | What changed in `34eab83` | Verdict | Lock zone |
| --- | --- | --- | --- |
| `WildboundTuning_Test` DT1 parity, DT2 live 19 | `WildboundIsland` `WAKE_WINDUP` 0.4 to 0.35, `CHASE_SPEED` 19 to 23; schema still 0.4 / 19 | Design question (breaks a recorded fairness rule) | No |
| `WildboundRecord_Test` RT-17 | `WildboundEconomyConfig` `capacity.collectionLimit` 100 to 500 | Stale threshold, if 500 is intended (undocumented) | No |
| `WildboundSpawnClock_Test` RW2 first step | `EGG_SHARE` 0.4 to 0, and the line `if point.kind == "canopy" then kind = "Egg" end` removed | Design question; the removed line looks like a regression | No |

## 1. Island chase defaults (Tuning DT1, DT2)

Evidence:

- `src/wildbound/WildboundIsland.luau:45-46`: `WAKE_WINDUP = 0.35`, `CHASE_SPEED = 23`. The comment above (lines 43-44) still says "up in 0.4 s, 19 studs/s ... only a sprint outruns it, by 1.3 studs/s".
- `src/wildbound/WildboundTuningSchema.luau:149-150`: defaults 0.4 and 19.
- `tests/WildboundTuning_Test.luau:70-78` (DT1 parity) and `:272`, `:312` (DT2 expects `Island.live.CHASE_SPEED == 19`).
- `tests/WildboundIsland_Test.luau:291-292` CP4 requires `CHASE_SPEED <= 20.3 - 1` (19.3). The repo value 23 fails it too, so CP4 should also be failing, though it was not in the reported list. Unconfirmed: no suite was run.
- Recorded design (FA2, `odd/tasks/wildbound-capture-extraction-horror.md:481,486`; `docs/mechanics/wildbound-expedition-islands.md:316`): 19 studs/s, so a carrying sprinter (14 x 1.45 = 20.3) gains 1.3 studs/s and is the only way out. At 23 a carrying sprinter can never escape a woken parent; only an unloaded sprint (23.2) barely matches it. Nothing in the docs or task files records 23 or 0.35.
- Live Studio: the Edit-mode tuning folder `ReplicatedStorage.WildboundTuning.Islands` holds attributes `CHASE_SPEED = 19` and `WAKE_WINDUP = 0.4`. An Edit-mode attribute overrides the module default (`docs/testing/wildbound-tuning.md:48`), so in this place's Play the parents still run at 19 and stand up in 0.4 s. The module edit has no effect in Play here. It only shows up in the suites and in any place without the folder.

Verdict: a design question, not a confirmed code bug. Either someone sped the parents up on purpose and forgot the schema, the comment and two tests, or it was a temporary experiment. Either way, 23 breaks the recorded "a carrying sprint escapes" rule.

Minimal fix, by user answer:

- Keep FA2 (recommended unless the user asked for faster parents): restore `WAKE_WINDUP = 0.4`, `CHASE_SPEED = 19` in `WildboundIsland.luau`. One file, two lines, plus a redeploy to Studio. Risk: low; it matches what Play already does through the tuning folder.
- Adopt 23 / 0.35: change the schema defaults, the DT2 expectations, the CP4 range (it can no longer say "slower than a carrying sprinter"), the comment and the two docs, and reset the Edit-mode tuning attributes. Risk: medium; it removes the only escape while carrying.

## 2. Record size (Record RT-17)

Evidence:

- `tests/WildboundRecord_Test.luau:327-340` fills `Config.capacity.collectionLimit` entries plus a full ledger (`LEDGER_CAP` 64) and asserts the JSON is under 20,000 characters. The case name says "far below the 4,194,304 character limit".
- `src/wildbound/WildboundEconomyConfig.luau:35`: `collectionLimit = 500`, which was 100 before `34eab83`. Studio holds 500 too.
- Where 20 KB comes from: `docs/mechanics/wildbound-persistence.md:70` estimates the record "under 20 KB" for 100 entries (about 45 bytes each, bond about 30, ledger about 4 KB). It is a sizing estimate written for 100 companions, not a platform limit. The Roblox limit is 4,194,304 characters per key, pinned by `Record.MAX_CHARS` in the same case.
- Measured 27,051 characters at 500 entries. That is about 0.65% of the key limit; the 20 KB line was simply sized for 100.
- 500 is not documented anywhere: the overview (`docs/wildbound-game-overview.md:77,266`) and the economy source document (`docs/mechanics/wildbound-economy-p0.md:519`) still say 100. This is also why the Python economy-config export tests fail (the generated Luau no longer matches its source document).
- The totem schema-4 field added in the same sync adds at most a few bytes; it is not the cause.

Verdict: if 500 is intended, this is an intentional change with a stale threshold, not a bug. Whether 500 is intended is the open question, and it is shared with the economy-config export failures.

Minimal fix:

- If 500 is confirmed: scale the RT-17 budget with the limit, for example `size < 60000` (or about 55 bytes x limit + 8 KB), keep the 4,194,304 assertion, and update `wildbound-persistence.md:70`, the overview rows and `wildbound-economy-p0.md:519`, then regenerate the config. Risk: low. DataStore cost is negligible at about 27 KB; the larger collection may matter more for UI and snapshot size than for storage.
- If 100 was intended: restore `collectionLimit = 100`. Risk: low, and it also clears the export drift.

## 3. Bough spawns (SpawnClock RW2)

Evidence:

- `34eab83` changed `src/wildbound/WildboundSpawnClock.luau` in two ways: `EGG_SHARE = 0` (was 0.4), and it removed `if point.kind == "canopy" then kind = "Egg" end` from `make`. Studio holds the same (no `canopy` text in the live Source).
- The header comment (line 27) still says "a bough always holds an egg"; `docs/testing/wildbound-tuning.md:62` still says `EGG_SHARE` (0.4).
- `tests/WildboundSpawnClock_Test.luau:112` asserts that a canopy point holds an egg. The same sync edited this suite (the `Species.ONLY` Lumipol note, dated user 2026-11-11) but left this line, so the live test and the live module disagree in Studio as well.
- `EGG_SHARE = 0` is recognised elsewhere: `docs/balance/wildbound-2-0-economy-sim.md:165` and `odd/tasks/wildbound-2-0.md:96` mirror it as the live value. Wild spawns being creatures only looks deliberate, in line with the 2026-11-11 Nest Heist decisions (eggs live in the island nests: `EGGS_PER_NEST` 3).
- The removed canopy line is not explained anywhere. Without it, a bough point (105 of 291 graph points, a low bough 6 studs up, RW-W3) now spawns a cria floating beside the trunk at bough height, which the recorded design never intended.

Verdict: `EGG_SHARE = 0` is an intentional change. The removed canopy rule is a design question; most likely it was removed so that "no wild eggs" holds everywhere, but it leaves crias on boughs.

Minimal fix, by user answer:

- "No wild eggs at all": keep the module and change the RW2 assertion to `if spawn.point.kind == "canopy" then equal(spawn.kind, "Creature") end`, or drop it and mark it as a deliberately changed pin. Then decide whether boughs should still be offered to the clock: excluding `canopy` points from the wild pools avoids floating crias. That second change touches `SpawnClock.new` pools and RW2 "pools take every wild graph point" (`tests/WildboundSpawnClock_Test.luau:73`). Risk: low for the test edit; medium for the pool change (fewer Comun points per tier).
- "Boughs keep eggs": restore the one removed line. Then bough points still yield eggs although `EGG_SHARE` is 0. Risk: low; it brings back wild eggs on 105 points.
- Either way, update the header comment and `docs/testing/wildbound-tuning.md:62` (0.4 to 0).

## Lock zone

None of the fixes touches the lock zone (WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock, WildboundWorldClient, their three suites, SistemaSonriente). They touch `WildboundIsland`, `WildboundTuningSchema`, `WildboundEconomyConfig`, `WildboundSpawnClock`, their suites and docs. `WildboundState` reads `collectionLimit` but needs no change.

## Python check (this session)

`python -I -B -m unittest discover -s tools -p "test_*.py"`: 1279 run, 19 failures, 28 skipped. Besides the known failures (economy-config export, `test_lumipol_v2` v1 files, audio catalog d9), there are new `test_simulate_economy` failures and `test_studio_fresh_runner` "every suite has a spec or a skip". Other tracks were editing at the same time, which probably explains them. They were not investigated.

## Recommended next action

Ask the user three questions, one at a time: (1) are the parents meant to run at 23 now, or do they stay at 19 so a carrying sprint escapes; (2) is the 500-companion collection intended; (3) should boughs spawn nothing, crias or eggs. Then the owning track makes the matching minimal fix with RED/GREEN, redeploys with the Studio parity check, and resets the stale Edit-mode tuning attributes if the defaults change.
