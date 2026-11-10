# Wildbound hub systems: corral, trophies, incubator, tree kiosk, workshop and the Puesto mock

**Status: implementation spec, nothing built.** Written 2026-11-09 for a later Studio writer; revised 2026-11-10 after an adversarial review (section 16 lists every refutation and where it is fixed). It turns three design documents into modules, remotes, tests and tuning rows: the economy of record `docs/design/wildbound-economy-and-offers.md` (the numbers), the open-world layout `docs/design/wildbound-open-world-hub.md` (where things stand) and the incubator delivery `docs/mechanics/wildbound-incubator.md` (the behaviour that moves). Where this spec and the economy document disagree on a number, the economy document wins and this spec is the bug. No Studio edit, no purchase, no `MarketplaceService`, no DataStore is authorized by this document; `AGENTS.md` still requires verifying the Studio instance and place and getting the user's confirmation before any edit.

Design and code in English; every in-game name and player string below is neutral Spanish and belongs in `WildboundText`.

## Quick path

| You are | Read |
| --- | --- |
| The Studio writer | Sections 1 (order of work), 2 (module map), then the system you are building (3 to 8), 9 (remotes), 11 (tests, RED first) and 12 (tuning) |
| A reviewer | Sections 3.4 (accrual timing), 9 (server authority), 10 (session state and the saved-record fields), 15 (what is unverified) and 16 (refutations addressed) |
| The user | Section 14 (decisions); everything else is mechanics |

## 0. Facts this spec rests on (read 2026-11-09 and 2026-11-10)

| Fact | Source |
| --- | --- |
| All client requests go through one `RemoteEvent` named `Action` with `(action, uid)` and **no third argument** (`select("#", ...) > 0` drops the call); `uid` must be a non-empty string of at most 128 characters; an action not in the allow-list is ignored | `src/wildbound/WildboundServer.server.luau:1777-1806` |
| Per-player rate limit: any action at most every 0.08 s, the same action at most every 0.3 s | `WildboundServer.server.luau:297-304` (`allowed`) |
| `context(player, target)` returns `alive, distance` from the live character to a map marker; stations are map markers | `WildboundServer.server.luau:305-` |
| Sinks today (`Craft`, `Upgrade`, `Learn`, `ArmTotem`, `DisarmTotem`, `UseCapsule`) measure distance to `campCenter`; arguments are looked up in server tables and unknown ones are dropped silently | `WildboundServer.server.luau:1734-1775` |
| Every reply goes through `reply → send`, which pushes a fresh `state:snapshot` on the `State` remote; a reply carries a notice key, not a payload | `WildboundServer.server.luau:285-296` |
| The incubator marker is bound **once** by name: `incubatorMarker = map:FindFirstChild("IncubatorMarker", true)`; the hatch prompt, its `validPrompt` check and the hatch range check all use that one variable | `WildboundServer.server.luau:55-56`, `:340`, `:374-377` |
| `State:incubate(key, uid, alive, distance, now, seconds, slots)` checks 12 studs, ownership and a free slot; `State:hatchReady` hatches exactly once, wherever the player stands (the server's 1 Hz step calls it); registered entries are `{ uid, species }` (no rarity) | `src/wildbound/WildboundState.luau:484-522`; `WildboundServer.server.luau:390-398` |
| `State:equip(key, uid, alive)` checks only that `uid` is in `registered`, then sets `equippedUid` | `WildboundState.luau:524-531` |
| `State:learn` refuses a node whose `effectLive ~= true` with `EffectPending` | `WildboundState.luau:652-663` |
| Existing `NOTICES` keys used here: `InvalidContext`, `NotAtCamp` ("Hazlo en el campamento."), `CannotAfford`, `EffectPending`. There is **no** `NotEnoughEmber`, `NotEnoughMaterials` or `NotAvailable` | `src/wildbound/WildboundText.luau:32`, `:348-358` |
| Prompts sharing a key show only the nearest one (the W3b bug); `WildboundPromptKeys` gives each prompt that can be in reach together its own key, pad button and `UIOffset`, and `Keys.conflicts()` checks the groups. Taken keys: E, R, T, V, B, G, H, plus F, Q, X, C, I, M used by other controls | `src/wildbound/WildboundPromptKeys.luau:1-47`, `tests/WildboundPromptKeys_Test.luau` |
| The tuning panel's developer gate: the server sets `Schema.DEV_ATTRIBUTE` on a player from `Schema.isDeveloper(...)`, using the group rank only in the private place | `src/wildbound/WildboundTuning.server.luau:94-100`, `WildboundTuningSchema.luau:10` |
| `WildboundIncubator.CONSTANTS = { HATCH_SECONDS = 90, SLOTS = 1, RANGE = 12 }`, tunable `HATCH_SECONDS` | `src/wildbound/WildboundIncubator.luau:17` |
| Species have looks and sizes but no `rarity` and no `biome` field | `src/wildbound/WildboundSpecies.luau` |
| Tuning schema: systems of `value(key, label, module, target, default, min, max, step, side)`, module defaults are the source of truth, `Schema.MODULES` names the file to commit to | `src/wildbound/WildboundTuningSchema.luau:15-40` |
| HUD touch targets are at least 44 px; layout violations are a pure check | `src/wildbound/WildboundHudLayout.luau:7-13`, `:180-183` |
| Saved record is schema 1 with no corral, equipment, rarity, trophy or purchase fields; `TIERS = { Safe, Fog, Territory }`; ledger capped at 64 | `src/wildbound/WildboundRecord.luau:8-19` |
| Leaving the server discards the profile; persistence is a proposal; DataStore is forbidden today | `WildboundServer.server.luau:1890-1906`, `docs/mechanics/wildbound-persistence.md` |
| `StreamingEnabled` stays on for the world | `docs/wildbound-roadmap.md`, `docs/testing/wildbound-world.md` |
| Hub stations: Incubadora (-32.5, -32.5) r 6; Corral (36.6, -28.6) yaw 128, 22 x 13; Refugio (16.4, -45.1) r 5; Cofre (-15.7, -43.2) r 3; Puesto (-43.2, -15.7) r 4; Tablero (-23.0, 39.8) yaw 30, 8 x 3; Árbol (-39.8, 23.0) r 4.5, which holds `Learn` **and** `Upgrade`; Trofeos 1 to 5 on an arc r 50, bearings 15 to 75 degrees. The Incubadora is about 69 studs from the Corral | `docs/design/wildbound-open-world-hub.md:39-50` |
| Corral economy: 4 free pens, pens 5 to 8 at 60 / 150 / 350 / 800; rates Común 0.5, Rara 0.75, Épica 1.0, Legendaria 1.5 per minute; duplicates x0.5 then x0.25; cap `0.4 x own rolling extraction income per minute (20 min) + 0.3 per filled pen past 4`; working rule full rate 3 min after an expedition event, a quarter otherwise alive, zero dead or away; feed 1 common or uncommon for a 20-minute window, re-feed only after an expedition event; storage 20 minutes of nominal output; collect hold 1.5 s; lazy accrual, never on a timer | `docs/design/wildbound-economy-and-offers.md` section 5, Appendix B `corral`; formulas mirrored in `tools/simulate_hub_economy.py:185-232`, `:437-447` |

## 1. Order of work

Each step is its own work unit with RED tests first, then GREEN, then the Studio suites and a Play check. Persistence-dependent rows stay out until saved progress is approved (E12).

| Step | Delivers | Depends on |
| --- | --- | --- |
| H0 | Hub geometry and station markers built from the open-world layout (open-world doc section 11, rows 1 to 3, 7, 11) | User confirmation of the Studio target; OW1 |
| H1 | `rarity` on carried, banked, incubating and registered entries; `Species.BIOME`; the named event writers of section 3.4 | None |
| H2 | Incubator at the hub: tagged markers and the server rewrite of section 5 | H0 |
| H3 | `WildboundCorral` pure module, then corral wiring, parcels, wander and plaques (section 3); the `PetInCorral` guard on `State:equip` | H0, H1 |
| H4 | `WildboundTrophies` pure module, the plinths and `trophyFeed` in the snapshot (section 4) | H1 |
| H5 | Tree kiosk at the hub, tiers 1 and 2 live, tiers 3 to 5 shown honestly (section 6) | H0; role costs (economy section 13) for the east side |
| H6 | `WildboundEquipment` pure module, the Taller tab and the four slots, **level I only** (section 7) | H5 |
| H6b | Equipment levels II and III | Tier 3 and tier 5 nodes of the matching branch `effectLive = true` |
| H7 | Puesto mock, private place and developers only (section 8) | H0 |

## 2. Module map

New pure modules live in `src/wildbound/` and are shared through `ReplicatedStorage` like `WildboundIncubator`: no service reads, the clock is passed in, `CONSTANTS` frozen, `tunable()` / `tune(overrides)` / `live` as in `WildboundIncubator.luau:17-40`.

| Module | Kind | Owns |
| --- | --- | --- |
| `WildboundCorral.luau` | Pure, shared | Rates, duplicate factors, the cap, the working-rule share, the piecewise `integrate`, `projectStored`, storage, feed eligibility, slot ladder, plaque text inputs, wander path |
| `WildboundTrophies.luau` | Pure, shared | Milestone catalogue, `evaluate(profileView, event)` → new trophy ids, plinth priority |
| `WildboundEquipment.luau` | Pure, shared | Pieces, levels, the 12-step ladder as a literal table, material costs, tier gates, `levelAvailable`, effect lookups |
| `WildboundSkillTree.luau` | Pure, shared | Branch and tier layout for the kiosk, tier costs as a literal table, `effectLive` per node; the costs of tiers 1 and 2 stay in `WildboundEconomyConfig.skills` |
| `WildboundHubLayout.luau` | Data | Exported by `tools/export_open_world_luau.py` (open-world doc row 11): station centres, footprints, parcel rectangles, plinth positions |
| `WildboundPromptKeys.luau` | Existing | New group `Keys.HUB` (section 13) added to `Keys.conflicts()` |
| `WildboundState.luau` | Existing | New profile fields and methods of section 10; every economy write stays here |
| `WildboundServer.server.luau` | Existing | New actions in the `Action` allow-list and their dispatch (section 9); tagged incubator markers (section 5); `HubCorral` folder of parcel models |
| `WildboundHubView.luau` | New, client view | Corral panel, trophy panel, kiosk tabs, Puesto mock; pure layout helpers checked like `WildboundHudLayout` |
| `WildboundText.luau` | Existing | New tables `CORRAL`, `TROPHIES`, `KIOSK`, `TALLER`, `PUESTO` and the new `NOTICES` keys of section 9 |

## 3. Corral

### 3.1 Shape: parcels and pens

The economy document gives every player up to 8 **cercados** (pens: 4 free, 4 bought with Esencia); the open-world layout has one physical Corral of 22 x 13 studs with "8 pens". Both are kept by naming the physical part differently:

- The Corral holds **8 parcelas** (parcels), one per player present, assigned at join in join order and released at leave. A ninth player gets no parcel; their pens still earn and are shown in their panel and on the Tablero, and they get the first parcel freed (decision HS1).
- A parcel is a rectangle of about 5.5 x 6.5 studs (the 22 x 13 footprint split 4 x 2), fenced, with a plaque on its front face naming the owner ("Corral de {nombre}").
- Inside a parcel live the owner's **cercados**: each filled pen is one creature. Pens are logical, not fences.
- Visible models per parcel are capped at `VISIBLE_PER_PARCEL`, default **2** for phones (OW7, HS2). A parcel with more filled pens shows the highest-rarity creatures and "+N" on the plaque; every pen still earns. The value is raised only after a MicroProfiler measurement on a phone (section 3.3).
- Each parcel has **one** prompt, "Ver mi corral" (section 3.2). The prompt only opens the panel.

### 3.2 Placing a creature

| Step | Rule |
| --- | --- |
| Where | The Corral panel row "Al corral" next to a registered creature sends `CorralPlace(uid)`. The panel opens from the parcel prompt "Ver mi corral" (hold 0.5 s), so the player is at the Corral. No prompt ever acts on a creature uid |
| From the hatch card | The hatch card's "Al corral" button sends `CorralQueue(uid)` (section 5). The server never places remotely: when the player is within `CORRAL_RANGE` it acts as `CorralPlace`; otherwise it stores `pendingCorral = uid`, sets a client waypoint to the Corral and replies `CorralQueued` ("Ve al corral y abre tu parcela para dejarla allí"). The next time the owner triggers their parcel prompt, the server's `Triggered` handler re-runs every `CorralPlace` check (range included) on `pendingCorral`, places it if they pass, and clears the flag either way |
| Range | Within `CORRAL_RANGE` (default 14) studs of the Corral marker, alive. Out of range replies `NotAtStation` ("Acércate a la estación") |
| Who | Only a registered creature the player owns, not already in a pen, not equipped as the companion: refused with `PetIsCompanion` ("Tu compañero te acompaña; elige otra criatura") |
| Reverse guard | `State:equip` gains `if inPen(player, uid) then return false, "PetInCorral" end` before it sets `equippedUid`, with the notice "Esta criatura vive en el corral; sácala para que te acompañe". The card's `CardEquip` and the camp panel hide "Equipar" on penned creatures; the server guard holds even if a client sends it. A creature is never both the companion and in a pen |
| Room | A free pen (`filledPens < ownedPens`); otherwise `CorralFull`: "Tu corral está lleno. Libera un cercado o amplíalo con Esencia." No offer card is shown here (economy rule 6: never at a refused action) |
| Effect | Settle the corral (section 3.4), then the creature takes the pen with `placedAt = now`, `fedUntil = 0`, `stored = 0`. It earns nothing until fed (economy 5.1) |
| Duplicate | The panel shows the rate it would credit now, after duplicates and the cap ("Ganaría 0,25 por minuto: ya tienes uno igual") |

`CorralRemove(uid)` settles, collects the stored output (same path as `CorralCollect`), then empties the pen. Free, any time, same range.

### 3.3 Wandering inside the parcel

The server places one model per visible pen (looks from `WildboundSpecies.LOOKS`, adult scale x0.6) and **never moves it**. Each client animates the wander locally from a pure function, so no position is replicated:

```text
WildboundCorral.wander(uid, parcelRect, t) -> x, z, yaw, hover
seed = adler32(uid); waypoint k = seeded point inside parcelRect shrunk by 0.8 studs
segment of 4 to 7 s per waypoint (seeded), ease in-out, 1.5 s idle at each waypoint
hover = 0.25 x sin(2 pi t / 2.4 + seed) studs, like the companion hover
```

`t` is `workspace:GetServerTimeNow()`, so every client draws the same creature in the same place. The function is pure and tested (section 11).

Streaming and cost rules (streaming stays on):

| Rule | Value |
| --- | --- |
| Model shape | Each corral creature is one `Model` whose parts are welded to a `PrimaryPart`; the client pivots only that model with `PivotTo`, never part by part. Parts per model are capped by `CORRAL_PART_BUDGET` (default 12); a `LOOKS` entry over the budget is drawn with a simplified look, asserted by a test over every `LOOKS` entry |
| Streaming | Every corral creature model has `ModelStreamingMode = Atomic`, so it streams in or out whole. The client loop holds models in a table filled by `ChildAdded` / `ChildRemoved` on the parcel folder and skips any entry whose `Parent` is nil or whose `PrimaryPart` is nil; a re-streamed model resumes from `wander(uid, rect, now)` with no stored state |
| Rate | Full `RenderStepped` rate within `WANDER_FULL_RADIUS` (default 40) studs of the camera; about 20 Hz from there to `WANDER_DRAW_RADIUS` (default 90); frozen beyond. The loop allocates no tables per frame |
| Physics | `CanCollide`, `CanTouch` and `CanQuery` off, `Anchored` on |
| Measurement | Before raising `VISIBLE_PER_PARCEL` above 2, record a MicroProfiler capture on a phone with 8 full parcels in view; the result goes in `docs/testing/` |

### 3.4 Feeding, accrual, collecting

All amounts come from `WildboundCorral` with the economy numbers of section 0. **Accrual is lazy**: nothing on Heartbeat, `task.delay` or `task.wait` writes the economy (AFK-1). Two rules make the result independent of who asks and when:

1. **Settle only inside server writes.** `State:corralSettle(key, now)` integrates every pen of the player from `corral.settledAt` to `now` and writes `stored`; it is called only from the State methods listed in the settle-point table below. No read path writes: `State:snapshot`, the panel, the plaque and the Tablero use the pure `WildboundCorral.projectStored(corral, timeline, now)`, which returns what a settle at `now` would write and changes nothing.
2. **The integral is piecewise and exact.** `WildboundCorral.integrate(corral, timeline, from, to)` splits `[from, to]` at every breakpoint and applies the economy formula on each piece with the values that held on that piece. So `integrate(a, b) + integrate(b, c) == integrate(a, c)` for any `b`, and settling early or late gives the same Esencia.

Breakpoints inside `[from, to]`: each pen's `fedUntil`; the end of the active window (`activeUntil`); every extraction-log entry's `at + 20 min` (when it leaves the rolling window). Everything else that changes a rate (a death, a respawn, a new expedition event, a new extraction, a pen placed, removed or fed, leaving) happens at a settle point, so the integration never needs a record of it.

| Settle point (settle first, then write) | Writer |
| --- | --- |
| Pen placed, removed, fed; collect; pen bought | `State:corralPlace`, `corralRemove`, `corralFeed`, `corralCollect`, `corralBuyPen` |
| Expedition events | `State:extract` (kind `extraction`, also appends `extractionLog`), `State:register` (kind `extraction` for its receipt Esencia, also appends `extractionLog`), `State:gather` (kind `gatherBanked`), the wave bank method of W3 when it exists (kind `waveBanked`); the steal is banked through `extract`/`register`, so `stealBanked` is not a separate kind |
| Life changes | New `State:corralLife(key, alive, now)`, called by the server from `humanoid.Died` (`WildboundServer.server.luau:1869`) and from `bindCharacter` on `CharacterAdded` (`:1890`); it settles, then sets `corral.alive` |
| Leave | Player removal settles, then the profile is discarded (today) |

| Rule | Value |
| --- | --- |
| Share on a piece | 1.0 while `now < activeUntil` (`activeUntil = max(activeUntil, eventAt + ACTIVE_WINDOW x 60)` on every expedition event), `HUB_SHARE` (0.25) while `corral.alive` and in the server, 0 while dead. Only inside `[placedAt, fedUntil]` per pen |
| Cap on a piece | `cap = CORRAL_SHARE x rollingExtraction / 20 + CORRAL_PER_PEN x max(0, filledPens - 4)`; `scale = min(1, cap / sum(nominal of pens fed on that piece))`. `rollingExtraction` is the sum of `extractionLog` entries with `at` in `(pieceStart - 20 min, pieceStart]`, which is constant on the piece by construction. An extraction raises the cap **only from its own time forward** (its settle point comes before its append) |
| Credited | Per pen and piece: nominal (rarity x duplicate factor) x scale x share x piece length. Clamp `stored` to `STORAGE_MIN x nominal` |
| Retention | Records are pruned only inside a settle point, after the settle: `extractionLog` keeps entries with `at > settledAt - 20 min` (needed for the rolling window); `expeditionEvents` keeps the newest 32 for the feed rule; there is no `lives` list. Because every death and respawn is itself a settle point, a dead interval is integrated at share 0 when it ends, and no history the integral needs is pruned before it is used |
| `CorralFeed(uid)` | A panel button. The server picks the material: the cheapest common unit the player holds, else uncommon, current biome's material first (economy `spendOrder`). Refused with `NothingToFeed` ("Necesitas 1 material común o poco común para alimentarla") or `NeedsExpedition` ("Sal a explorar antes de volver a alimentarla") when no expedition event happened since this pen's last feed. Effect: settle, spend 1 unit, `fedUntil = now + FEED_WINDOW x 60`, `lastFedEventAt = latest expedition event time` |
| `CorralCollect("all")` | Panel button (hold 1.5 s on the button). Settles, credits `floor(sum stored)` to `ember`, keeps the fractional remainder in the pens proportionally, analytics `earned(key, "corral")`. Notice "+{n} de Esencia del corral". Refused with `NothingStored` ("Aún no hay Esencia que recoger") when the floor is 0 |
| Lleno | A pen at its storage limit (by `projectStored`) shows "Lleno" on the panel and the plaque |
| Offline / leave | Nothing accrues while away; leaving discards everything today (section 10) |

**Plaque and panel honesty.** A pen row shows the creature, its rarity, and the rate it is **crediting now**, computed by the same `WildboundCorral.creditedRates` the integral uses on the current piece ("0,6 por minuto · tope del corral" when `scale < 1`). The Corral sign shows the cap ("Tu corral paga hasta 3,4 por minuto: crece cuando exploras y con cada cercado"). A test asserts that the rate shown equals the rate credited over the next simulated minute when no breakpoint falls inside it.

### 3.5 Buying pens with Esencia

`CorralBuyPen("next")`: within range, alive; settle; the next pen's cost from `slotLadder` (60 / 150 / 350 / 800, a literal frozen table); `Economy.canPay` then `pay`; `ownedPens += 1` up to 8. Refusals `CannotAfford` (existing), `CorralMaxed` ("Ya tienes los 8 cercados"). Panel button "Ampliar corral · {costo} de Esencia". No Robux row exists anywhere (section 8).

### 3.6 Esencia board

The Tablero shows, per player in the server, the Esencia their corral credited this session (collected amounts, not projections) and the wave board top 3 when the wave clock exists. It is a `SurfaceGui` filled from a server-built summary attribute string (no remote), refreshed when any collect happens and at most once every 5 s.

## 4. Trophy display

### 4.1 Milestones

`WildboundTrophies.CATALOGUE` (data, frozen). **Trophies never pay Esencia** (economy 7.3); the 10 Esencia for a first species registration is a small source paid by `register`, not by the trophy.

| Id | Player name | Earned when | Plinth shows |
| --- | --- | --- | --- |
| `first:<Species>` | "Primer {especie}" | First registration or hatch of that species | That species' model |
| `rarity:Rara`, `rarity:Epica`, `rarity:Legendaria` | "Primera criatura Rara / Épica / Legendaria" | First registered creature of that rarity | The creature that earned it |
| `biome:forest`, `biome:pradera` | "Bosque completo", "Pradera completa" | Every species with `Species.BIOME[s] == biome` registered at least once | A small group of that biome's species (up to 3) |
| `event:<biome>` | "Huevo especial del bioma" | First biome-event hatchling (W3), when that exists | The hatchling |
| `pi1` | "El primer robo" | The PI-1 first-steal registration | Lumipol (or the east tutorial species) |

`evaluate(view, event)` takes a read-only view `{ registered = { {species, rarity} }, trophies = set }` and an event `{ kind = "registered" | "hatched" | "eventHatched" | "pi1", species, rarity }` and returns the list of newly earned ids, in catalogue order. Pure, idempotent: a trophy already in the set is never returned again. The writers are `State:register` and `State:hatchReady`, which call `evaluate` and store new ids.

### 4.2 Plinths

The hub has 5 plinths. Each player sees **their own** trophies on them: the server stores trophy ids in the profile and the snapshot; the client builds the plinth models locally from `WildboundSpecies.LOOKS` (no replicated models, no cross-player clutter). Priority when more than 5: biome completion, event, Legendaria, Épica, Rara, PI-1, then species firsts newest first. Each plinth has a small plaque "{trofeo} · {nombre} · {hora}" (session time today, date once saved). A plinth without a trophy shows a dim silhouette and "Por descubrir".

Other players' trophies are social through two surfaces only: a short server notice when someone earns a Legendaria, event or biome trophy ("{nombre} consiguió: Bosque completo"), at most one per 30 s per server, and the Trofeos panel, opened by the client-only prompt "Ver trofeos" on any plinth, which lists the viewer's own trophies and, below, the server's latest 5 trophy events. Those 5 events travel in the snapshot as `trophyFeed` (`{ name, trophyId, at }`, newest first, server-wide); there is no `TrophyView` action and no new reply payload.

## 5. Incubator at the hub

Behaviour is `docs/mechanics/wildbound-incubator.md` unchanged: `State:incubate`, `State:hatchReady`, the 1 Hz hatch step, `HATCH_SECONDS` 90, `SLOTS` 1, `RANGE` 12. What changes is **where**, and that needs a server rewrite, listed here in full:

| Change | Rule |
| --- | --- |
| Markers | No second part named `IncubatorMarker`. Each incubator part carries the CollectionService tag `WildboundIncubator` and an attribute `Site = "hub"` or `"camp"`. The camp part keeps its name for the transition but is found by tag (OW2 keeps the camp working) |
| Server binding | `WildboundServer.server.luau:55-56` is replaced by a list of tagged markers (`CollectionService:GetTagged("WildboundIncubator")` plus `GetInstanceAddedSignal`), filtered to `BasePart` with a valid `Site` |
| Prompt | One hatch prompt **per tagged marker** (replacing the single `hatchPrompt` at `:374`), each with its own `validPrompt(prompt, marker)` check and the `Keys.CAMP.hatch` or `Keys.HUB.incubator` key by `Site` |
| Hatch action | The `Hatch` action (`:340`) and the prompt handlers measure `context(player, nearestIncubator(player))`, where `nearestIncubator` returns the tagged marker closest to the live character; the 12-stud rule in State is unchanged |
| Camp panel path | The camp panel's incubate button keeps sending `Hatch`; it works at whichever tagged marker is nearest |
| Source test | No code in `src/wildbound/` calls `FindFirstChild("IncubatorMarker"`; every incubator lookup goes through the tag |
| Visible eggs | The hub dome has 3 egg cradles. Each client shows **its own** incubating egg in the first cradle with the progress ring from `Incubator.progress`; the other two cradles show other players' incubating eggs (species glow only, no names) from a server attribute list, so the station looks alive |
| Hatch card | The card opens wherever the egg hatches. It gains a second button "Al corral" that sends `CorralQueue(newUid)` (section 3.2): placed at once when the player is within `CORRAL_RANGE`, otherwise queued with a waypoint and the notice "Ve al corral y abre tu parcela para dejarla allí". It shows only when a pen is free, else the card says "Libera un cercado para verla en el corral" |
| Rarity | The hatched creature inherits the egg's rarity (H1); eggs from today's islands map through `rarity.fromRiskTier`, else Común |
| Not here | Nido cálido, the second incubator and any hatch speed: they need saved progress (economy 7.1); hatch speed is never sold |

## 6. Skill tree kiosk

The Árbol station (-39.8, 23.0) has a prompt "Ver el Árbol" that opens the kiosk panel with three tabs, **Árbol**, **Mejoras** and **Taller** (section 7) (decision HS3: no separate Taller footprint). `Learn(skillId)` and `Upgrade(id)` are existing actions; the only server change for both is the distance check, which accepts the hub Árbol marker within `KIOSK_RANGE` (default 12) or the camp as today. A request in neither place is refused with `NotAtStation` ("Acércate a la estación") when the player stands nearer the hub than the camp, and with the existing `NotAtCamp` otherwise, so a child at the hub is never told to go to the camp.

| Rule | Value |
| --- | --- |
| Branches | Rastreo (`explorer_*`), Captura (`capturer_*`), Aguante (`survivor_*`), Ocultismo (`occultist_*`), one branch at a time with a 4-button selector on every orientation |
| Tiers | 5 per branch, unlocked in order inside a branch |
| Esencia | Literal frozen table `TIER_ESENCIA = { 40, 100, 250, 620, 1560 }`. The economy document's `round10(40 x 2.5^(t - 1))` is the design origin only; code never evaluates it (Luau `math.round` rounds half up and would give 630 at tier 4) |
| Materials | common 20 / 30 / 50 / 80 / 120, uncommon 10 / 20 / 30 / 50 / 80, rare 0 / 3 / 5 / 8 / 12 (role costs; until the role cost shape lands, the kiosk resolves roles to Fogbark / Glowmoss / Nightbloom exactly as `WildboundEconomyConfig.skills` does for tiers 1 and 2) |
| Live nodes | Tiers 1 and 2 (the eight existing nodes, same ids and totals) |
| Not yet wired | Tiers 3 to 5 have config rows with `effectLive = false`; the kiosk shows them with name, effect and cost, and a disabled button "Aún no disponible". The server refuses `Learn` on them with the existing `EffectPending` even if a client sends the id |
| Card text | Each node: name, one-line effect, cost line "{esencia} de Esencia + {materiales}", state "Aprendida" / "Siguiente" / "Necesita {nodo anterior}" (only ever naming a live node) / "Aún no disponible" |
| Never | No Robux row, no tier skip, no respec (economy rule 3) |

## 7. Equipment crafting and equip slots

### 7.1 Pieces and slots

Four slots on the character sheet, one piece each: **Guantes de ladrón** (Captura), **Botas ligeras** (Rastreo), **Chaleco acolchado** (Aguante), **Amuleto de calma** (Ocultismo). Crafting a level fills its slot and replaces the previous level; there is no unequip and no stacking (decision HS4). Effects are multipliers on the existing modules, read by the server.

**Only level I ships in H6.** Levels II and III need branch tiers 3 and 5, which are not live (section 6). They are designed below so the ladder and the saved field are stable, but `WildboundEquipment.levelAvailable(piece, level, tree)` returns false for them until the matching tier node has `effectLive = true` (H6b).

| Piece | Level I (ships) | II (after tier 3 is live) | III (after tier 5 is live) | Reader |
| --- | --- | --- | --- | --- |
| Guantes | Parents' wake input during your capture x0.8 | x0.7 | x0.6, retry cooldown -1 s (floor 2) | `WildboundIsland` wake input |
| Botas | Sprint drain x0.8 | x0.7 | x0.6 | `WildboundStamina` drain, cap 24 unchanged |
| Chaleco | Once per expedition, a defeating strike marks you instead and drops the newest bag item | Defeat material loss x0.75 | x0.5 | `WildboundState:defeat`, `WildboundFairStrike` (telegraph untouched) |
| Amuleto | Beast memory of you x0.75 | x0.5 | x0.5, Refugio stamina regen x3 | `WildboundGuardianBrain` memory, floor 2 s |

No piece touches the calm meter, the speed cap, the telegraph or fear (Modo tranquilo is a free setting, economy 6.1).

### 7.2 Crafting

`Forge(pieceId)` on the Taller tab, within `KIOSK_RANGE` of the Árbol marker or inside the camp:

| Check, in order | Refusal (`NOTICES`) |
| --- | --- |
| `pieceId` is one of `guantes`, `botas`, `chaleco`, `amuleto` (else dropped silently) | none |
| Alive | `InvalidContext` (existing) |
| In range of the hub Árbol or the camp | `NotAtStation` (new) at the hub side, `NotAtCamp` (existing) otherwise, as in section 6 |
| Next level exists (I → II → III) | `PieceMaxed`: "Esta pieza ya está al máximo" |
| Next level available (`levelAvailable`) | `EffectPending` (existing). The Taller row never names a tree node for a level that cannot be reached; it shows "Aún no disponible" on a disabled button, as the tree does |
| Cost: `EQUIPMENT_LADDER[n]` with `n = levels owned across all pieces + 1`, plus materials by level (I: 20 common + 10 uncommon; II: 40 + 20 + 2 rare; III: 60 + 40 + 5 rare) | `CannotAfford` (existing) |

`EQUIPMENT_LADDER` is a literal frozen table `{ 60, 90, 135, 200, 305, 455, 685, 1025, 1540, 2305, 3460, 5190 }`; the economy document's `round5(60 x 1.5^(n - 1))` is the design origin only and code never evaluates it (Luau rounds 202.5 up to 205). With level I only, `n` runs 1 to 4: 60, 90, 135, 200.

Effect: pay, set `equipment[piece] = level`, push the snapshot. Notice "Forjaste {pieza} {nivel}". The Taller row shows the step sentence "Cada mejora de equipo cuesta más que la anterior: la siguiente costará {x} de Esencia".

Totems keep their existing recipe path (`Craft`) and gain the hub Taller as a second place; the luck totem is plan I2, not this spec.

## 8. Offer kiosk (Puesto): design mock only

**Nothing here may call `MarketplaceService`, prompt a purchase, read a Game Pass or show a Robux price.** The Puesto exists to test layout and wording with the user, and to make sure the free path is always printed first.

| Rule | Value |
| --- | --- |
| Visibility | The mock panel is built only when **both** `game.PlaceId == WildboundTuningSchema.PRIVATE_PLACE_ID` **and** the local player has `Schema.DEV_ATTRIBUTE` set true by `WildboundTuning.server.luau` (the tuning panel's own gate). Anyone else, in any place, gets the free-path panel only (below) and no "Próximamente" row |
| Headline | "Nada de lo que se vende es exclusivo: todo se consigue jugando, y el Árbol nunca se vende." |
| Rows (mock) | Equipo del explorador (Guantes I / Botas I / Amuleto I), Un cercado más (pen 6), Bolsa grande, Segunda incubadora. Each row: the free line first and larger, from live config ("Gratis jugando: 200 de Esencia + 20 Fogbark + 10 Glowmoss · ~36 min"), then a grey disabled button reading **"Próximamente"** with no price, no Robux icon, `Active = false`, `AutoButtonColor = false` |
| Free-path panel (public) | Same headline, same rows with the free line and a working button that walks the player to the station that earns it ("Ir al Árbol", "Ir al Corral"), which only sets a waypoint |
| Never | No countdown, no flashing, no strike-through, no character asking, no card pop-ups (cards are economy rule 6 and need saved progress), nothing in the first session once sessions exist |
| Server | **No remote.** The mock is client-only; the server sends nothing for it and dispatches nothing for it |

## 9. Server authority: every remote

All new requests reuse the `Action` `RemoteEvent` and its guards (string action at most 32 characters, no extra arguments, `uid` a string of 1 to 128 characters, `allowed` rate limit). New allow-list entries: `CorralPlace`, `CorralQueue`, `CorralRemove`, `CorralFeed`, `CorralCollect`, `CorralBuyPen`, `Forge`. `Learn`, `Upgrade`, `Equip` and `Hatch` are existing and change as stated.

| Action | Argument | Server checks (in order) | Writes | Idempotency |
| --- | --- | --- | --- | --- |
| `CorralPlace` | creature uid | alive; distance to `CorralMarker` <= `CORRAL_RANGE`; owned registered uid; not in a pen; not the companion; free pen | settle, pen entry | Placing a uid already in a pen returns ok with no change |
| `CorralQueue` | creature uid | alive; owned registered uid; not in a pen; not the companion; free pen; then in range → as `CorralPlace`, else set `pendingCorral` | pen entry or `pendingCorral` | A second queue replaces the flag; the flag is cleared by the next parcel prompt either way |
| `CorralRemove` | creature uid | alive; range; uid in one of the player's pens | settle, collect, empty the pen | Removing a uid not in a pen: `NotInCorral`, no change |
| `CorralFeed` | creature uid | alive; range; uid in a pen; expedition event since the last feed; owns 1 common or uncommon | settle, spend 1, `fedUntil` | A second feed in the same window is refused by the event rule |
| `CorralCollect` | literal `"all"` (else dropped) | alive; range | settle, credit `floor`, keep remainder | A repeat right after credits 0 and replies `NothingStored` |
| `CorralBuyPen` | literal `"next"` (else dropped) | alive; range; `ownedPens < 8`; can pay | settle, `ownedPens += 1`, spend | Two quick presses: the 0.3 s rate limit plus `canPay` of the second step; each press buys at most one pen and states its price in the reply |
| `Forge` | piece id | known id; alive; range; next level; `levelAvailable`; can pay | level, spend | One level per accepted request |
| `Learn` | skill id | existing checks plus hub range; `effectLive` must be true (`EffectPending`) | as today | as today |
| `Upgrade` | upgrade id | existing checks plus hub range | as today | as today |
| `Equip` | creature uid | existing checks plus `PetInCorral` | as today | as today |
| Parcel prompt (server `Triggered`, not an action) | none | the prompt's parcel belongs to the player; then, if `pendingCorral`, every `CorralPlace` check | pen entry or nothing | Clears `pendingCorral` |

New `NOTICES` keys: `NotAtStation`, `PetIsCompanion`, `PetInCorral`, `CorralFull`, `CorralMaxed`, `CorralQueued`, `NotInCorral`, `NothingToFeed`, `NeedsExpedition`, `NothingStored`, `PieceMaxed`. Reused keys: `InvalidContext`, `NotAtCamp`, `CannotAfford`, `EffectPending`. A test asserts every key this spec names exists in `WildboundText.NOTICES`.

Rules that hold for every row: the client never sends an amount, a time, a position, a material, a price or a rarity; every number is read on the server from config, state and the server clock (`workspace:GetServerTimeNow()`); every refusal replies through `reply` with a `NOTICES` key so the HUD can say why; unknown arguments are dropped silently like `economyAction`; parcel ownership is server state. Other players' parcel prompts are disabled on each client (the client sets `Enabled = false` locally on every parcel prompt not tagged with its own `UserId`), and the server's `Triggered` handler ignores a trigger on a parcel the player does not own. Analytics: `spent(key, "corralPen")`, `spent(key, "forge")`, `earned(key, "corral")`.

## 10. State: session-only now, saved fields later

### 10.1 New profile fields (session only, in `WildboundState`)

| Field | Shape | Notes |
| --- | --- | --- |
| `registered[i].rarity` | `"Comun" \| "Rara" \| "Epica" \| "Legendaria"` | Set at the steal from `rarity.fromRiskTier` today, from the W2 band once the spawn graph exists |
| `corral` | `{ ownedPens = 4, settledAt, alive, activeUntil, pendingCorral, pens = { { uid, placedAt, fedUntil, lastFedEventAt, stored } } }` | `stored` is a float; collect floors it; `settledAt` is shared by all pens because the cap couples them |
| `expeditionEvents` | list of `{ kind, at }`, newest 32; kinds `extraction`, `gatherBanked`, `waveBanked` | Written by the methods in the settle-point table (section 3.4); the feed rule reads it |
| `extractionLog` | list of `{ at, ember }`, pruned to `at > settledAt - 20 min` inside a settle point | Written by `State:extract` and `State:register`; the cap reads it |
| `trophies` | set of ids plus `{ id, at }` list | Written by `register` and `hatchReady` |
| `equipment` | `{ guantes = 0..3, botas = 0..3, chaleco = 0..3, amuleto = 0..3 }` | 0..1 reachable until H6b |
| `chalecoUsedTrip` | trip number | Once per expedition |

There is no `lives` list: deaths and respawns are settle points (section 3.4).

`State:snapshot` adds `corral` (each pen's credited rate, projected stored, `full` and the cap, all from `projectStored`; it writes nothing), `trophies`, `trophyFeed` (server-wide, last 5), `equipment` and the next forge cost, so the client never computes a price on its own.

### 10.2 Exact fields a future saved record needs (record schema 2)

These extend the schema-2 list of the economy document section 13; nothing is written today.

| Record path | Type and rule |
| --- | --- |
| `collection.registered[].rarity` | One of the four rarities; migration from schema 1 takes `rarity.fromRiskTier[riskTier]`, else `Comun` |
| `corral.ownedPens` | Integer 4..8 |
| `corral.pens[]` | `{ uid, fedUntilUnix, storedEsencia }`; `uid` must name a registered creature that is not the saved companion; at most `ownedPens` entries; `storedEsencia` finite, 0..`storage x nominal` |
| `corral.lastFeedEventUnix` per pen | Unix seconds of the expedition event that unlocked the last feed |
| `eventLog` | Only `activeUntil` (unix), not the full list |
| `trophies[]` | `{ id, atUnix }`, ids validated against the catalogue, no duplicates |
| `equipment` | `{ guantes, botas, chaleco, amuleto }`, integers 0..3, each above 1 consistent with the branch tier gate and `effectLive` |
| `skills` | Existing field; tiers 3 to 5 ids added |
| `sessionIndex`, `cumulativeMinutes` | Needed before any offer card can exist (economy rule 6) |
| `offersShown[]` | `{ row, step, sessionIndex }`; empty until offers are approved |
| `purchases[]` | Outside `LEDGER_CAP`, never trimmed by count; empty until purchases are approved |

On load, there is **no offline credit**: `settledAt = joinTime`, keeping only `storedEsencia` (economy 5.1, "Offline"). `pendingCorral` is never saved.

## 11. Tests to write (RED first)

Each test file follows the `tests/WildboundIncubator_Test.luau` shape (`return function(Module, source, sources)` with `case` / `equal` / `near`) and is registered in `tests/UnitTestRunner.server.luau`. Write and observe each RED before the module exists or before the wiring changes.

| File | Cases |
| --- | --- |
| `tests/WildboundCorral_Test.luau` | Defaults equal the economy numbers and are frozen; nominal rates by rarity; duplicates 1 / 0.5 / 0.25 by species and rarity; cap formula with 0 and 4 extra pens; proportional scaling keeps rarity order; working-rule share 1 within 3 minutes of an event, 0.25 after, 0 while dead; accrual only inside the fed window; storage clamps at 20 minutes of nominal; **no drift**: `integrate(a, b) + integrate(b, c) == integrate(a, c)` for 200 random `b`, with extraction-log entries whose `at + 20 min` falls inside both halves and a `fedUntil` inside the interval; **no retroactive cap**: an extraction at `t` leaves the credit of `[t - 10 min, t]` unchanged; **`projectStored` is pure**: calling it twice changes no field and equals what a settle at the same time writes; feed refused without an expedition since the last feed; idle hour with a fed corral credits at most quarter rate for one window (K8); idle hour unfed credits 0; standing still anywhere alive credits the quarter rate, not more (K8b); collect floors and keeps the remainder; plaque rate equals the credited rate over the next minute without a breakpoint; slot ladder 60 / 150 / 350 / 800; `wander` stays inside the shrunk rectangle for 1,000 sampled times and is identical for the same uid and time; every `LOOKS` entry fits `CORRAL_PART_BUDGET` or has a simplified corral look |
| `tests/WildboundCorralWiring_Test.luau` | Source checks on `WildboundServer`: the seven new actions are in the allow-list and `TrophyView` is not; no `Heartbeat`, `task.delay` or `task.wait` path calls a corral credit or `corralSettle` (AFK-1); `State:snapshot` and the reply path never call `corralSettle`; every corral handler calls `context` with the Corral marker; no handler reads an amount from the client; the parcel models have `CanCollide`, `CanTouch`, `CanQuery` false and `ModelStreamingMode` Atomic; one prompt per parcel; `Died` and `CharacterAdded` call `corralLife` |
| `tests/WildboundState_Test.luau` (extend) | `corralPlace` refuses not owned, companion, full, out of range; `equip` refuses a penned creature with `PetInCorral` and a placed companion is refused with `PetIsCompanion` (both directions); `corralQueue` out of range sets `pendingCorral` and places nothing, in range places; `corralRemove` collects first; `corralFeed` spends exactly one unit of the right role; `corralBuyPen` spends the ladder price and stops at 8; **one test per event writer**: `extract`, `register`, `gather` (and the wave bank when it exists) each settle, then append the right `expeditionEvents` kind, and `extract` / `register` append `extractionLog`; **dead time**: die at `t0`, feed was at `t0 - 1 min`, respawn at `t0 + 25 min`, settle at `t0 + 40 min`: the dead interval credited exactly 0; pruning never removes an `extractionLog` entry with `at > settledAt - 20 min`; `register` and `hatchReady` store rarity and trophies; `forge` order of checks, the ladder cost by levels owned, and `EffectPending` for II and III while tiers 3 and 5 are not live |
| `tests/WildboundTrophies_Test.luau` | Catalogue ids unique and frozen; first species, rarity firsts, biome completion when the last species of a biome registers, event and PI-1; never returned twice; plinth priority order; trophies carry no Esencia field; the snapshot's `trophyFeed` holds at most 5 entries, newest first |
| `tests/WildboundEquipment_Test.luau` | `EQUIPMENT_LADDER` is a frozen literal equal to 60, 90, 135, 200, 305, 455, 685, 1,025, 1,540, 2,305, 3,460, 5,190; materials by level; tier gates II = 3, III = 5; `levelAvailable` false for II and III when the gate node is not `effectLive` and true once it is; effect lookups; no key named like calm, fear, speed cap or telegraph; memory floor 2 s |
| `tests/WildboundSkillTree_Test.luau` | `TIER_ESENCIA` is a frozen literal 40 / 100 / 250 / 620 / 1,560; tiers 1 and 2 equal the current `WildboundEconomyConfig.skills` costs; tiers 3 to 5 `effectLive = false` until wired; server `Learn` refuses a not-live node with `EffectPending`; the module source contains no `^` power expression for costs |
| `tests/WildboundIncubator_Test.luau` (extend) | No source in `src/wildbound/` calls `FindFirstChild("IncubatorMarker"`; the server binds incubators by the `WildboundIncubator` tag; one prompt per tagged marker; `Hatch` measures the nearest tagged marker; the hatch card sends `CorralQueue`, and only with a free pen |
| `tests/WildboundPromptKeys_Test.luau` (extend) | `Keys.HUB` entries are in `Keys.conflicts()` and produce no conflict; the corral parcel prompt has its own key and offset |
| `tests/WildboundHubView_Test.luau` | Pure layout at 375 x 667 portrait and 667 x 375 landscape, **including the scroll content**: every button at least 44 x 44 inside its `ScrollingFrame` canvas, pinned buttons outside the scroll, panels inside the safe area, no overlap with the existing HUD elements of `WildboundHudLayout`; the kiosk shows one branch at a time on both orientations; the Puesto mock's buttons are disabled and read "Próximamente"; no Robux price string in the mock; the mock is built only when both the place id and the dev attribute hold |
| `tests/WildboundOfferGuard_Test.luau` | Source scan of every hub file (`WildboundCorral`, `WildboundTrophies`, `WildboundEquipment`, `WildboundSkillTree`, `WildboundHubView`, `WildboundServer`): no `MarketplaceService`, `PromptGamePassPurchase`, `PromptProductPurchase`, `ProcessReceipt`, `DataStoreService`; `WildboundEconomyConfig.monetization == "none"` |
| `tests/WildboundText_Test.luau` (extend) | Every new key of section 9 exists in `NOTICES` and every reused key still exists; Spanish; no forbidden copy tokens from `offerRules.forbiddenCopyTokens` |
| `tests/WildboundTuning_Test.luau` (extend) | Every row of section 12 exists with default equal to the module's `CONSTANTS` |
| Python (`tools/`) | If the corral numbers move, `tools/test_simulate_hub_economy.py` must still pass C1, C2, C3, K8 and K8b; add a parity test that the Luau `WildboundCorral.CONSTANTS` exported values match Appendix B (the same drift pattern as `tools/test_export_economy_config_luau.py`), and that the Luau literal ladders (`EQUIPMENT_LADDER`, `TIER_ESENCIA`, `slotLadder`) equal the Python values |

Play checks after GREEN (Studio, with the user's confirmation of the target): place a creature, see it wander, feed it, wait 3 minutes after a gather, collect and compare with the plaque; buy pen 5; earn a species trophy and see the plinth; incubate at the hub, press "Al corral" on the card, walk to the Corral and open the parcel; open the Puesto in the private place as a developer and confirm the buttons are inert; record the MicroProfiler capture of section 3.3. Two players and phones stay unverified unless the user tests.

## 12. Tuning schema entries

Two new systems in `WildboundTuningSchema.SYSTEMS` and two new `MODULES` (`Corral` → `WildboundCorral.luau (Corral.CONSTANTS)`, `Hub` → `WildboundHubView.luau (HubView.CONSTANTS)`). Defaults are the module's own and the contract compares them.

| System | Key | Label (Spanish) | Module.target | Default | Min | Max | Step | Side |
| --- | --- | --- | --- | ---: | ---: | ---: | ---: | --- |
| `Corral` "Corral" | `RATE_COMUN` | Común (Esencia/min) | Corral.RATE_COMUN | 0.5 | 0 | 2 | 0.05 | server |
| | `RATE_RARA` | Rara (Esencia/min) | Corral.RATE_RARA | 0.75 | 0 | 4 | 0.05 | server |
| | `RATE_EPICA` | Épica (Esencia/min) | Corral.RATE_EPICA | 1.0 | 0 | 4 | 0.05 | server |
| | `RATE_LEGENDARIA` | Legendaria (Esencia/min) | Corral.RATE_LEGENDARIA | 1.5 | 0 | 4 | 0.05 | server |
| | `CORRAL_SHARE` | Tope: parte de lo que ganas explorando (x) | Corral.CORRAL_SHARE | 0.4 | 0.1 | 1 | 0.05 | server |
| | `CORRAL_PER_PEN` | Tope por cercado extra (Esencia/min) | Corral.CORRAL_PER_PEN | 0.3 | 0 | 1 | 0.05 | server |
| | `HUB_SHARE` | Ritmo sin explorar (x) | Corral.HUB_SHARE | 0.25 | 0 | 1 | 0.05 | server |
| | `ACTIVE_WINDOW` | Minutos de ritmo completo | Corral.ACTIVE_WINDOW | 3 | 1 | 10 | 0.5 | server |
| | `FEED_WINDOW` | Ventana de comida (min) | Corral.FEED_WINDOW | 20 | 5 | 60 | 1 | server |
| | `STORAGE_MIN` | Almacena hasta (min) | Corral.STORAGE_MIN | 20 | 5 | 60 | 1 | server |
| | `CORRAL_RANGE` | Distancia al corral (studs) | Corral.RANGE | 14 | 6 | 30 | 1 | server |
| `Hub` "Plaza" | `VISIBLE_PER_PARCEL` | Criaturas visibles por parcela | HubView.VISIBLE_PER_PARCEL | 2 | 1 | 8 | 1 | client |
| | `WANDER_FULL_RADIUS` | Distancia de animación completa (studs) | HubView.WANDER_FULL_RADIUS | 40 | 10 | 120 | 5 | client |
| | `WANDER_DRAW_RADIUS` | Distancia para animar el corral (studs) | HubView.WANDER_DRAW_RADIUS | 90 | 30 | 200 | 10 | client |
| | `KIOSK_RANGE` | Distancia al Árbol y al Taller (studs) | HubView.KIOSK_RANGE | 12 | 6 | 30 | 1 | server |

Not tunable on purpose (contracts, asserted by tests): the slot ladder, the equipment ladder and its gates, the tree costs (all literal tables), `CORRAL_PART_BUDGET`, `monetization = "none"`, "trophies pay no Esencia".

## 13. Phone layout

Targets: 375 x 667 portrait and 667 x 375 landscape, 44 px minimum touch targets, safe-area insets respected, the existing HUD (`WildboundHudLayout.ELEMENTS`) never covered while a hub panel is closed.

| Surface | Portrait | Landscape |
| --- | --- | --- |
| Prompts | `ProximityPrompt` hold prompts, one per station (one per parcel at the Corral, only the viewer's own enabled), `RequiresLineOfSight = false`, max activation 10 studs. Keys come from a new `Keys.HUB` group (incubator, corral, árbol, trofeos, puesto, tablero), each with its own key, pad button and `UIOffset`, checked by `Keys.conflicts()`; the Incubadora and the Puesto are about 20 studs apart, so both can be in reach at once and must differ. The concrete keys are chosen against the taken list of section 0 when `Keys.HUB` is written | same |
| Corral panel | Bottom sheet, 70 % height. Pinned header "Tu corral · {lleno}/{cercados}" and the cap sentence; a vertical `ScrollingFrame` of pen rows (creature icon, name and rarity chip on line one, "0,6 por minuto" or "Lleno" on line two, buttons "Alimentar" and "Sacar" at 44 px on the right; a row is 96 px); pinned below the scroll, outside it, "Recoger {n} de Esencia" (primary, full width) and "Ampliar corral · {costo}" | Right-side panel at 52 % width (within 50 to 55 %), full safe height; same pinned header, scrolling rows (two-line text, the two buttons side by side) and pinned buttons |
| Trophy panel | Grid 3 columns of 96 px cards in a `ScrollingFrame`; server feed below | Grid 5 columns, same scroll |
| Kiosk | Tabs "Árbol", "Mejoras", "Taller" at the top; on the Árbol tab a branch selector (4 buttons, 44 px high) and **one branch at a time**: its 5 tier cards in a vertical `ScrollingFrame`, each card about 112 px (name, effect, cost line, state, 44 px button); on the Taller tab 4 slot cards in a `ScrollingFrame` | Same structure: selector on the left as a 44 px column, one branch's tiers in a vertical `ScrollingFrame` on the right; never four columns. Taller as a 2 x 2 grid in a `ScrollingFrame` |
| Puesto mock | Headline, then one row per offer in a `ScrollingFrame`: free line (16 px, primary text) above a disabled "Próximamente" button (grey, 44 px) | Two columns of rows, same scroll |
| Text | Minimum 14 px body, 18 px headings, `TextScaled` off with `TextWrapped` on, numbers with a decimal comma ("0,6") as neutral Spanish | same |
| Close | Every panel has a 44 px "Cerrar" button top-right and closes on leaving the station's range by 4 studs | same |

The pure checks (`WildboundHubView.layout(viewport, contentCounts)` returning rectangles for the frame, the scroll canvas and every child, plus `violations`) mirror `WildboundHudLayout` so the 44 px and no-overlap rules are tested without a device, with 8 pen rows and 5 tier cards as the worst case.

## 14. Decisions for the user (one at a time, later)

| ID | Decision | Recommendation |
| --- | --- | --- |
| HS1 | Physical Corral: 8 parcels, one per player present, pens as logical slots inside (this spec), or 8 shared pens with one creature per owner (open-world doc row 7) | Parcels: each player sees all their pens' worth, kids find "their" corral |
| HS2 | Visible creatures per parcel | 2 on phones, raised only after a MicroProfiler capture with 8 full parcels |
| HS3 | Taller as a tab of the Árbol kiosk (this spec) or a separate station | Tab: no new footprint in the station band |
| HS4 | Crafting a level auto-equips, no unequip | Yes; one of each piece, nothing to choose |
| HS5 | Trophy plinths show each viewer's own trophies (client-local) | Yes; others' trophies through the feed and notices |
| HS6 | Puesto mock visible only in the private place and only to developers | Yes; public players see the free paths only |

## 15. Unverified

Nothing here has run in Studio, on a phone or with two players. The corral rates and cap are the economy document's simulated hypotheses; the piecewise integral is specified but not yet checked against `tools/simulate_hub_economy.py`, which integrates per tick. The wander cost on a phone, the readability of "0,6 por minuto" for children, whether 2 visible creatures per parcel are enough, and the hub prompt keys are unmeasured or unchosen. Rarity today can only come from the island tier mapping until the spawn graph (W1, W2) exists. Biome completion needs `Species.BIOME` and the Pradera species, which do not exist yet. Equipment levels II and III wait for tiers 3 and 5. Every row of section 10.2 needs saved progress, which is a proposal while DataStore is forbidden.

## 16. Refutations addressed

Review of 2026-11-10. Each refutation, what changed, and where.

| # | Refutation | Fix | Where |
| --- | --- | --- | --- |
| R1 | Hatch card "Al corral" is always refused: the card opens wherever the egg hatches, about 69 studs from the Corral | The card sends `CorralQueue`: in range it places; otherwise it sets `pendingCorral`, a waypoint and the notice `CorralQueued`. The parcel prompt's server handler places it with every check, range included. Never placed remotely | 3.2, 5, 9, 10.1, 11 |
| R2 | A penned creature could be equipped, earning in the pen and as the companion | `State:equip` refuses with `PetInCorral`; UI hides "Equipar" on penned creatures; State tests in both directions | 3.2, 9, 11 |
| R3 | Cap applied retroactively, and client-driven reads triggered settles | Settle only at server settle points; snapshot, panel and plaque use pure `projectStored`; the integral is piecewise over breakpoints, so an extraction raises the cap only from its own time; the no-drift test uses interleaved extractions | 3.4, 10.1, 11 |
| R4 | Dead time leaked because `lives` and the extraction log were pruned before a late settle | Deaths, respawns, extractions and events are settle points (`corralLife`, `extract`, `register`, `gather`), so `lives` is gone; pruning happens only after a settle and keeps `at > settledAt - 20 min`; a test with a death long before the settle credits 0 | 3.4, 10.1, 11 |
| R5 | A second `IncubatorMarker` breaks the single binding at `WildboundServer.server.luau:55` | CollectionService tag `WildboundIncubator` with `Site`, one prompt per marker, `Hatch` uses the nearest tagged marker; the server rewrite is listed; a source test forbids `FindFirstChild("IncubatorMarker"` | 0, 5, 11 |
| R6 | Equipment II and III were unreachable dead ends with a misleading "Necesitas {nodo}" | H6 ships level I only; II and III show "Aún no disponible" and are refused with `EffectPending` until the gate node is live (`levelAvailable`, H6b) | 1, 7.1, 7.2, 11 |
| R7 | Refusal codes called "existing" did not exist; `NotAvailable` duplicated `EffectPending`; `NotAtCamp` was wrong at the hub | `CannotAfford` and `EffectPending` reused; new `NotAtStation` for hub stations; a test asserts every named key exists | 0, 3.5, 6, 7.2, 9, 11 |
| R8 | Ladder formulas round differently in Luau (205, 630) and Python (200, 620) | Both ladders and the slot ladder are literal frozen tables; formulas are design origin only; a Python/Luau parity test | 6, 7.2, 11, 12 |
| R9 | Phone layout overflowed: four kiosk columns in landscape, 8 corral rows in a fixed sheet | One branch at a time on both orientations with a vertical `ScrollingFrame`; corral rows in a `ScrollingFrame` with collect and expand pinned outside it; landscape corral at 52 % width; layout tests include the scroll content | 13, 11 |
| R10 | 24 prompts in the Corral with shared keys, contradicting "two visible", and no uid on prompts | One prompt per parcel, "Ver mi corral", which only opens the panel; others' parcel prompts disabled per client; feed, collect, place and remove are panel buttons; a `Keys.HUB` group checked by `Keys.conflicts()` | 3.1, 3.2, 9, 13, 11 |
| R11 | Wander under StreamingEnabled had no streaming mode, nil handling or part budget | `ModelStreamingMode = Atomic`, nil and re-stream guard, one welded model pivoted whole, `CORRAL_PART_BUDGET`, 20 Hz beyond `WANDER_FULL_RADIUS`, `VISIBLE_PER_PARCEL` 2 and a MicroProfiler capture before raising it | 3.1, 3.3, 12, 14 |
| R12 | Event writers unnamed; `TrophyView` had no payload path | The settle-point table names `extract`, `register`, `gather` and the wave bank, with one test per writer; the trophy feed travels in the snapshot as `trophyFeed` and `TrophyView` is removed | 3.4, 4.2, 9, 10.1, 11 |
| R13 | Puesto mock gate weaker than the tuning gate; `Upgrade` had no hub location | The mock needs the private place **and** the developer attribute; `Upgrade` gains the hub Árbol range as a "Mejoras" tab | 6, 8, 9, 14 |
