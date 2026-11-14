# Wildbound 2.0 saved-record plan

Status: **plan only**. Nothing here is implemented, wired or approved. The numbers it refers to live in the unwired `src/wildbound/WildboundBalance.luau` (T01). Tasks: `odd/tasks/wildbound-2-0.md`.

## 1. New fields

| Field | Contents |
| --- | --- |
| `hotbar` | `{uid...}`, at most 9 |
| `farm` | `{[slot] = {uid, lastCollectUnix}}` |
| `farmSlotsOwned` | count, default 4 |
| `hatchCount` | count of the account's hatches (0 for a new account; it is `previousHatches` in `Balance.incubationSeconds`) |
| `incubating[i].durationSeconds` | the duration of each incubation |
| `incubatorLevel` | 0..3 |
| `cradles` | 1..2 |
| `roulette` | `{freeSpinUsed, pending = {}}` |
| `discovered` | `{regions = {}, portals = {}}` |
| `training.walk` | kept; the maximum level becomes 5 |

## 2. Version step (user decision)

- **Recommended:** a separate `MIGRATIONS[4]` step, 4 to 5, in a new unlocked module `WildboundRecord2` (`FROM` 4, `SCHEMA` 5). It reuses `TotemRecord.ladder()` unchanged, so the luck totems stay shippable on their own.
- **Alternative:** merge everything into the unwired 3-to-4 step. This is allowed only while no store has ever held schema 4. It means fewer versions, but a larger change to a module that is already tested.

The user chooses.

## 3. Step rules

The step fills what is missing and invents no items.

- `hotbar = {}`, `farm = {}`, `farmSlotsOwned = 4`, `incubatorLevel = 0`, `cradles = 1`.
- `roulette = {freeSpinUsed = false, pending = {}}`: existing accounts get the one free spin.
- `discovered = {regions = {}, portals = {}}`.
- `hatchCount = #collection.registered`, so veterans skip the 10 s and 20 s first-egg times. There is no hatch stat today: the record `STATS` are `tripsOpened`, `extractions`, `defeats` and `firstPlayedDay` (`WildboundRecord.luau`). `#collection.registered` also counts captured creatures, and it would shrink once selling exists, so it is only a seed: from the step on, `hatchCount` is counted by `hatch` itself and is never re-derived. If an exact hatch count is wanted, add a `stats.hatches` field in the same step (it starts from the same seed).
- `durationSeconds = max(0, readyAtUnix - startedAtUnix)` for each existing saved incubation (the record stores `startedAtUnix` / `readyAtUnix`; the live profile maps them to `startedAt` / `readyAt`).
- The `training.walk` level is kept. There is no refund for the old cost curve.

## 4. Failed-load guard

The existing claim, lock, migrate, validate and TooNew rules apply unchanged. New validate rules:

- Hotbar and farm uids must be registered and mapped through `durableView`; otherwise they are dropped as at-risk.
- `lastCollectUnix` must be finite and is clamped to now on load.
- Accrual is capped at 15 minutes (`farm.uncollectedCapMinutes`).
- A pending roulette prize mints nothing until claimed, and the claim carries an idempotent claim id.
- Every count is finite and at least 0.

Tests: the RT-13 ladder, plus TR2-style checks that the old steps are reused as they are.

## 5. Steps that need the locked `WildboundState`

These wait until the teammate's stage 1 is done:

- the `addPlayer` blank shape (RT-2 parity);
- `incubate` (`durationSeconds`, `cradles`);
- `hatch` / `hatchReady` (`hatchCount`);
- `train` (the Balance levels);
- the `WildboundServer` incubator wiring (`:457-465`);
- new mutators for the hotbar, farm and roulette. These can live in new unlocked modules that own their own subtables.
