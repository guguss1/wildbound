# Steal-loop plan: portals, showroom base, base raids (2026-11-16)

Status: **Design only**, approved as direction by the owner ("jugable y bien similar a steal an egg con portales y las cosas que le agregamos nosotros"). Produced by a read-only multi-agent pass (3 code readers, genre research, 3 independent plans, 1 judge). Genre mechanics only: no names, characters, art or levels from any other game.

## Summary

Read-only review. I read docs/handoff/HANDOFF-2026-11-16.md and spot-checked the key claims. The HUD hard-hides are real: WildboundClient.client.luau lines 104, 119, 251 and 252 (the hud frame and the 'open' Mochila button). WildboundPortal.luau has Portal.CARRY = "refuse" at line 28 and a single STATIONS table at line 34. The Caramelo portal and nests depend on the Enabled attribute on Candy_Bioma_v1 (WildboundPortalService.luau lines 313 and 330, WildboundCandyNests.luau line 150).

SCORES (1 to 5 for playability / genre loop / identity and additions / safety and saves / feasibility):
- Plan 1, Playable-first: 5/4/5/4/4 = 22. Best first-5-minutes work: toast, nest guide, tutorial, camp retirement, touch path. It has the cleanest pure-then-wired portal split. Weak points: no feature flag on theft, and big4 comes before theft.
- Plan 2, Genre-feel-first: 4/5/5/3/3 = 20. Strongest on genre feel: visible income, collect chest, incubator slots back, leaderboard, a timed event portal to the Legendaria nest L1. Its M2 and M4 are each too large for one agent. Big4 comes last. Save safety is only a footnote.
- Plan 3, Risk-first: 4/4/5/5/4 = 22, and it wins the tie on safety. It first locks in what exists only in the unsaved Studio session. It fixes the 14 stale WildboundState_Test cases before touching State. Every PvP feature sits behind an off-by-default flag. It respects the teammate's lock-zone scripts. Weak points: the big4 merge is placed before portals, which blocks solo-playable work on an owner decision. There is no guide to the first nest and no showroom.

FINAL PLAN: Plan 3's safety skeleton, with Plan 1's solo-first ordering and Plan 2's showroom and social milestones grafted in.
- Milestones F1 to F8 can all be built and verified in solo Studio Play.
- F9 to F11 add stealing between bases behind a flag (WildboundFlags.baseRaid = false) until the owner runs a two-player test.
- F12 and F13 (big4) are owner-gated and can float earlier as soon as O8/O9 is approved. The forest and Caramelo stayed in place in big4 (handoff B7), so the W/E portals do not depend on the merge.
- F14 is the owner's release gate.

Global rules for every milestone:
- No new top-level locals in WildboundServer.server.luau. Use Heist fields, do-blocks or sibling modules.
- No new RemoteEvents (NP4 already fails). Use ProximityPrompts, attributes and the existing notice and PortalEvent channels.
- Confirm the Studio instance and place 122652861404212 before each sync. Use the fingerprint rule, one writer at a time, and respect the PlayLock, ImportLock and FreshRunnerLock.
- Pull the live Studio copy first before editing WildboundServer, WildboundState, WildboundEggCarry or WildboundBatKnock (the teammate's lock zone).
- Hide old features with flags; never delete them.
- The owner saves the place (O1) after each deploy.
- Borrow genre mechanics only. Every name stays Wildbound's own Spanish (Portales, Candado/Cerrar base, Cofre), and arches and barriers use Wildbound art (vines, candy, stone), not a copy of any game.

Extra risk not raised by any of the three plans: the live place is in big4 mode while this branch has no big4 code. The F1 fingerprint pass must check whether Studio's WildboundBiomes and WildboundBiomeLight come from agus/big4-map. If they do, never sync them from this branch before O9.

## Milestones (in order)

### F1. Lock in session-only state, check fingerprints, record the failing-test baseline

- **Why:** The place is unsaved, and the Caramelo nests and portal run only on the session attribute Enabled on Candy_Bioma_v1. A reopen can silently switch off half the loop. Every later milestone also needs a known red-test list and matching repo and Studio code. (Plan 3 M1, plus the Caramelo part of Plan 1 M4)
- **Size:** S. **Risk:** Low. It could switch on something a builder meant to keep off; the explicit-false override covers that.
- **Scope:**
  - CandyNests and PortalService treat the Caramelo nests (except event-only L1) and the Caramelo portal as on by default when the Enabled attribute is nil. An explicit false still switches them off.
  - Fingerprint every Wildbound* script and pull any Studio drift into the repo. Flag WildboundBiomes and BiomeLight if Studio holds the big4 versions, and do not overwrite them.
  - Settle the D19 hatch time on one value (module default 15 vs schema 5) and record it in the feature doc.
  - Record the known-red baseline in overview section 13: State_Test 14 cases, ECO-20, HB-T3, AN-3, BZ7, EL12, RW5, W1, NP4 and the clip-published cases.
- **Files:** `src/wildbound/WildboundCandyNests.luau`, `src/wildbound/WildboundPortalService.luau`, `src/wildbound/WildboundIncubator.luau`, `src/wildbound/WildboundTuningSchema.luau`, `docs/wildbound-game-overview.md`
- **Studio:** After the owner confirms the target, sync these 4 modules. Solo Play with the Enabled attribute cleared: the Caramelo nests can be stolen and the Caramelo arch sends the player home. The owner saves (O1).
- **Tests:** CandyNests and PortalService suites, with new cases for nil = on and false = off. Incubator suite for the hatch time. Run everything with tools/studio-fresh-runner.luau and compare to the baseline.

### F2. Show what the server says: notice toast, touch Mochila and camp access, Esencia counter, safe banner

- **Why:** This is the biggest playability blocker. Every refusal and confirmation (steal refused, 'Esta no es tu base', portal wait or cut, sold, farm full) goes to a hard-hidden HUD. Touch and gamepad players cannot open the Bolsa (equip, Vender, Liberar) or the gold buys. Every later milestone needs this channel. (Plan 1 M1 and M5, Plan 3 M2)
- **Size:** M. **Risk:** Low (client only). Clutter on phones is controlled by the queue and de-duplication. Unverified on a real phone until O5.
- **Scope:**
  - Move the hard-hides at WildboundClient.client.luau lines 104, 119, 251 and 252 into one flag table (CampView.HIDDEN.hud).
  - Feed showNotice into a slim, phone-safe toast at the top centre: max width about 360 px, 2 lines, fades out, one toast at a time with a queue, repeats de-duplicated.
  - Add an objective chip that reuses the objective text the HUD already computes.
  - Show a Mochila button on touch and gamepad: hit area of at least 48 px, clear of the jump button and the hotbar. Add a touch entry for the camp (C) gold purchases.
  - Show the Esencia counter next to 'Oro: N'.
  - Bring back '¡Estás a salvo!' as a short toast in BaseGuide showBanner, once per entry.
  - Show a one-time hint when a creature tool is first equipped: 'Toca/haz clic en tu base para ponerla en la granja'.
  - Keep the wave board, event banner and effects panel hidden (RW7).
- **Files:** `src/wildbound/WildboundClient.client.luau`, `src/wildbound/WildboundCampView.luau`, `src/wildbound/WildboundGold.client.luau`, `src/wildbound/WildboundBaseGuide.client.luau`, `src/wildbound/WildboundText.luau`
- **Studio:** Client scripts only, synced to StarterPlayerScripts after the target is confirmed. Solo Play: a refused steal, a portal refusal while carrying, and a sale each show a toast. The device emulator at 375x812: Mochila opens the Bolsa and the Vender and Liberar rows fit (closes B2). The owner saves.
- **Tests:** CampView suite: HIDDEN.hud filtering, and the toast target stays visible while the old HUD stays hidden. Button visibility per input type. Client wiring suites through the fresh runner, with no new reds.

### F3. One home and a first-minute guide: retire the camp stations, add the nest pointer and starter eggs, fix the collection display

- **Why:** The old camp at (-140,140) duplicates the base with live E/R/T/V/B/N prompts. Nothing points a new player from the hub to a nest; the first-egg hook was measured from the old camp spawn, about 400 studs away. This must be settled before portals change the routes. (Plan 1 M2 and M4, Plan 3 M3)
- **Size:** M. **Risk:** Low to medium. The camp feeds old tests and the 9th-player fallback; the flag keeps it reversible.
- **Scope:**
  - Disable the camp stations and board behind Rules.LEGACY_CAMP = false. Keep the geometry, the safe zone and the 9th-player fallback spawn.
  - Reuse the BaseGuide arrow and light column in reverse. When the player is not carrying, it points at the nearest stocked nest or wave egg (skipping emptied nests and nests in the last 10 s of a wave). While carrying, it switches to the existing home pointer. After the first bank it becomes an optional hint.
  - Use SpawnGraph data to place one low-rarity wave-1 egg near the forest entry (about (182,17)) and one near the Caramelo entry (about (412,-3)). Raycast the floor and keep them 64 studs or more from nests (decision 49).
  - Collection display: build the 3 hovering creatures in Stations:refreshDisplay, or correct HB-T5 in the overview.
- **Files:** `src/wildbound/WildboundWorldRules.luau`, `src/wildbound/WildboundServer.server.luau`, `src/wildbound/WildboundBaseGuide.client.luau`, `src/wildbound/WildboundSpawnGraph.luau`, `src/wildbound/WildboundWaveClock.luau`, `src/wildbound/WildboundHubStations.luau`, `docs/wildbound-game-overview.md`
- **Studio:** Pull the live WildboundServer first. Sync after the target is confirmed. Solo Play from a fresh profile: the camp shows no prompts, and the arrow leads to an egg in under 30 s. Record the time from the hub pad to the egg and back. The owner saves and sets Max Players to 8 (O6).
- **Tests:** A pure nearest-target picker test. A WorldRules test that no camp prompts are bound. SpawnGraph spacing and floor tests. Hub and MechanicsWiring suites with no new reds (HB-T3 is already red).

### F4. Portal rules v2 (pure): stations with direction and destination

- **Why:** Portal.destination always resolves to the player's own base. Hub-to-zone portals need data-driven stations before any arch is built. (Plan 1 M6, Plan 3 M5 rules)
- **Size:** S. **Risk:** Low (pure logic).
- **Scope:**
  - Give STATIONS entries { id, dir = 'out' | 'home', to = biomeId, arrival = Vector3, modes = {...}, active = optional window }. destination(player, station) returns the biome arrival for 'out' and the own base pad for 'home', which is unchanged.
  - Outbound from the safe hub: skip the 5 s calm, use about a 1 s channel, and keep the alive, ragdoll and cooldown checks.
  - Keep Portal.CARRY = 'refuse' in both directions (decision 47).
  - Arrival grace of about 4 s with no beast roll and no Silueta strike, as a RESPAWN_GRACE-style attribute that BeastDirector and FairStrike already read.
  - Add a mode filter hook (classic and big4 both list W/E; N/S only in big4 later) and an active-window field for F8's event portal.
- **Files:** `src/wildbound/WildboundPortal.luau`, `src/wildbound/WildboundWorldRules.luau`, `tests/WildboundPortal_Test.luau`
- **Studio:** Sync the modules and run the suites with the fresh runner. No Play change yet.
- **Tests:** Update the station-count pin in WildboundPortal_Test (about line 167). New cases: destination per direction, carrier refused both ways, outbound refused while ragdolled or on cooldown, grace expiry, mode filter, active window.

### F5. Hub portal ring: Bosque and Caramelo arches plus safe arrival pads

- **Why:** This is the owner's explicit 'con portales' and the genre hub feel. It works on the current branch without the big4 merge. (Plan 1 M7, Plan 2 M2, Plan 3 M5)
- **Size:** M. **Risk:** Medium: streaming fall-through, or arriving next to an engaged beast. Covered by the stream call, the grace and the refuge circle.
- **Scope:**
  - PortalService builds 2 outbound arches at runtime at hub-local radius 30 to 50, clear of the spawn pads at r16 and the bases at r72. Use buildStation with a Leads attribute and Wildbound-styled signs ('Ir al Bosque', 'Ir a Caramelo').
  - Arrival pads near the forest (about (150,17)) and Caramelo (about (430,-3)). Raycast them to the floor, keep them 64 studs or more from nests, outside the Silueta fog rectangle and outside HOME_LEASH, each with a small permanent Rules.setRefuges circle.
  - Before PivotTo, the server calls pcall(player.RequestStreamAroundAsync, player, dest).
  - New WildboundText.PORTAL wording for both directions. Reuse the phone-safe channel bar.
  - Wire inside the existing Heist block (about WildboundServer.server.luau lines 4240 to 4260) with no new locals.
  - Update the PortalProbe Studio tool.
- **Files:** `src/wildbound/WildboundPortalService.luau`, `src/wildbound/WildboundPortal.client.luau`, `src/wildbound/WildboundText.luau`, `src/wildbound/WildboundServer.server.luau`, `src/wildbound/WildboundWorldRules.luau`, `tests/WildboundPortalService_Test.luau`
- **Studio:** Pull the live WildboundServer first. Sync after the target is confirmed. Solo Play: hub to Bosque, steal, walk home; hub to Caramelo, then the Caramelo return arch. Verify the forest return arch for the first time. Check for no fall-through and no beast hit on arrival. The owner saves.
- **Tests:** PortalService suite: 4 prompts (2 out, 2 home), server range check, stream call stubbed, grace set. Hub and WorldRules suites with no new reds.

### F6. Tutorial for the hub and portal loop (5 steps driven by server events)

- **Why:** WildboundTutorial says only 'Busca un nido en el bosque y mantén E'. It does not teach portals, carrying home, floor hatching, the farm or gold. It goes after F5 so step 1 can name the portals. (Plan 1 M3, Plan 2 M3)
- **Size:** S. **Risk:** Low. Depends on F2, F3 and F5.
- **Scope:**
  - Steps confirmed by server events, not timers: 1 'Cruza un portal (Bosque o Caramelo)'. 2 'Mantén el botón sobre un huevo'. 3 'Llévalo a tu base, a tu marca brillante'. 4 'Espera que nazca' (show the floor timer). 5 'Pon la criatura en tu granja: la granja da oro'.
  - Use touch-neutral wording on phones (no key-only text).
  - Drive the F2 objective chip and toasts.
- **Files:** `src/wildbound/WildboundTutorial.luau`, `src/wildbound/WildboundStart.client.luau`, `src/wildbound/WildboundText.luau`, `src/wildbound/WildboundCreatureToolbar.luau`
- **Studio:** Sync after the target is confirmed. Solo Play with a fresh profile, timing the full loop from spawn to the first gold from the farm (target 5 minutes or less; first egg in hand under 60 s). The owner saves.
- **Tests:** Update the Tutorial tests for step order and event triggers. A text test for no key-only wording on touch.

### F7. Base as a showroom: visible income, Cofre collect pad, incubator slots back, floor spot per slot

- **Why:** The genre's main reward is watching your base earn money. Today the farm pays with no number on screen, only 1 floor slot hatches, and the base shows little. More eggs on the floor also give F11 something to steal. (Plan 2 M4, Plan 3 M10)
- **Size:** M. **Risk:** Medium: inflation from extra slots, so re-tune the slot prices. Needs owner options A and B (O4).
- **Scope:**
  - Option A: a billboard above each farm creature with its rate ('+N/min'). The economy stays per minute.
  - Option B-lite: a base 'Cofre' plate that collects accrued gold with the existing 15-minute uncollected cap. It is owner-only through Bases.mayUse and collected by the server only.
  - Remove incubatorSlot2 and incubatorSlot3 from CampView.HIDDEN.upgrades (fastIncubator only if O7 allows). Generalise Heist.flattenCradle and syncFloorEggs to N floor spots.
  - Use the Vitrina plinths for the rarest creature (optional).
- **Files:** `src/wildbound/WildboundGoldService.luau`, `src/wildbound/WildboundGold.luau`, `src/wildbound/WildboundHubStations.luau`, `src/wildbound/WildboundCampView.luau`, `src/wildbound/WildboundIncubator.luau`, `src/wildbound/WildboundServer.server.luau`, `odd/tasks/wildbound-gold.md`
- **Studio:** Pull the live WildboundServer first. Sync after the target is confirmed. Solo Play: place a Common creature, read '+7/min', wait, collect, and see Oro rise by the expected amount (closes B1). Buy slot 2 and see 2 eggs hatching on the floor. The owner saves.
- **Tests:** Gold accrual and collect tests (cap, owner-only, server-only). Incubator multi-slot tests. Run the economy sim with Blender's Python (-I -B) if the owner allows (O7).

### F8. Social layer: leaderstats, hub leaderboard board, timed event portal to the Caramelo L1 nest

- **Why:** Big public numbers and server-wide moments are the genre's pull to come back. L1 is currently event-only and never fires (B10). (Plan 2 M7, Plan 3 M10)
- **Size:** M. **Risk:** Low to medium. Watch L1's economic value.
- **Scope:**
  - Display-only leaderstats (Oro, Nacidos) read from state, plus a Wildbound-styled board in the hub. No schema change.
  - Every N waves, WaveClock opens a temporary event arch in the hub ring (an F4 station with an active window) to L1, announced to everyone with the F2 toast.
  - Add Robos to leaderstats later, once F11 is on.
- **Files:** `src/wildbound/WildboundWaveClock.luau`, `src/wildbound/WildboundCandyNests.luau`, `src/wildbound/WildboundPortal.luau`, `src/wildbound/WildboundPortalService.luau`, `src/wildbound/WildboundHub.server.luau`
- **Studio:** Sync after the target is confirmed. Solo Play: force the event with the Studio-only probe, take the arch, steal L1, return, and check leaderstats. The owner saves.
- **Tests:** Pure event schedule tests, station activation window tests, leaderstats update tests.

### F9. Save-safe egg transfer between players (pure plus State, flag off)

- **Why:** Stealing from bases is the core genre gap and the only part that can duplicate or lose eggs. The data path should be proven with no world exposure. (Plan 3 M7, Plan 1 M10)
- **Size:** M. **Risk:** High (save integrity), which is why it ships dark. Needs O4-G approval. A real-DataStore check needs separate isolated-persistence approval.
- **Scope:**
  - First bring the 14 stale WildboundState_Test cases up to date (bag 3 changed to 12).
  - state:stealEgg(ownerKey, uid, thiefKey) in one call: remove the egg from the owner's incubating or bankedEggs, create the thief's carried entry with a new session uid, and drop the owner's durable uid mapping in WildboundSave.
  - Refuse steals from an owner whose save is Unsaved, locked or failed. The thief cannot bank until the owner's checkpoint commits (Persistence:newOp/commit ledger, or a forced owner save).
  - Return to owner: a stolen egg left loose goes back to the owner's bankedEggs after N s if the owner is present.
  - Schema stays at 6. Eggs only. New WildboundFlags.luau with baseRaid = false.
- **Files:** `src/wildbound/WildboundState.luau`, `src/wildbound/WildboundSave.luau`, `src/wildbound/WildboundPersistence.luau`, `src/wildbound/WildboundRecord.luau`, `src/wildbound/WildboundFlags.luau (new)`, `odd/tasks/wildbound-caramelo-v2.md`
- **Studio:** Pull the live WildboundState first (teammate lock zone). Small additive sync. Solo smoke Play with the flag off shows no behaviour change.
- **Tests:** Total egg count kept across a steal; refusal when offline, Unsaved or locked; no duplicate after a simulated crash between the owner commit and the thief bank; return to owner; durable uid not reused; ledger ordering. State_Test drops from 14 red to 0 (or the count is documented).

### F10. Per-base raid zone and Candado base lock (flag off)

- **Why:** Stealing needs a carve-out from the hub safe disc and a defence that exists before theft is switched on. Building the lock first makes theft safe to ship. (Plan 3 M8, Plan 2 M5, Plan 1 M12)
- **Size:** M. **Risk:** High: it touches safe-zone semantics and the bat. Kept in a separate layer behind the flag.
- **Scope:**
  - New pure module WildboundRaid.luau: zoneFor(player, pos) returns 'raid' only inside another present player's BaseZone and only with the flag on. Rules.zone stays untouched, so beasts, strikes and Silueta never enter the hub.
  - Heist.stepBaseZones measures visitors against every occupied zone and sets an InBaseOf attribute (a Heist field, no new local).
  - 'Cerrar base' (Candado) is an owner-only prompt through Stations:measure and Bases.mayUse. Session-only lockedUntil and nextLockAt (hypothesis: 60 s lock, 150 s cooldown, free). The server pushes non-owners out to the rim. A cosmetic vine or candy barrier. A LockedUntil attribute drives a countdown on the 'Base de <nombre>' sign. The lock clears when the owner leaves.
  - Bat exception: inside their own base the owner may bat an intruder; it still does no damage.
- **Files:** `src/wildbound/WildboundRaid.luau (new)`, `src/wildbound/WildboundBaseZone.luau`, `src/wildbound/WildboundBases.luau`, `src/wildbound/WildboundHubStations.luau`, `src/wildbound/WildboundBatKnock.luau`, `src/wildbound/WildboundServer.server.luau`, `src/wildbound/WildboundHub.server.luau`
- **Studio:** Pull the live Server and BatKnock first. Sync after the target is confirmed. Solo Play with the flag on, Studio only: the lock prompt, the countdown, the cooldown and the barrier. The push-out and the bat need 2 clients (O5). The owner saves.
- **Tests:** Raid suite: zone classification and flag gating, Rules.zone unchanged for beasts and strikes, lock and cooldown timing, push-out target outside the rim, cleared on leave. BatKnock cases for the owner-only exception, with NP4 not worse.

### F11. Steal floor and banked eggs from other bases (flag on only after the 2-player test)

- **Why:** This is the genre loop: sneak into another base, grab an egg and run it home while the owner defends. It uses F9 for safety and F10 for the zone and lock.
- **Size:** M. **Risk:** High (PvP, exploits, duplication). Server-only trigger, atomic op and flag keep it reversible.
- **Scope:**
  - Server ProximityPrompt on WildboundFloorEgg (Heist.syncFloorEggs) shown to non-owners only, plus an optional display egg per base for banked eggs.
  - Server checks: not the owner, owner present, base not locked, thief alive, in measured range and under the bag cap, at most 1 steal per owner per 90 s, the owner's last egg protected. Hold time by rarity through EggCarry.holdFor (0.5/0.9/1.3/1.8 s).
  - On success: stealEgg, then EggCarry.pickup and syncEggArms. The thief banks through the normal enterBase and secureAll path. Toasts for both players ('¡Te robaron un huevo!').
  - A stolen egg that was incubating restarts its hatch time (recorded as a decision taken for the user). Portals still refuse carriers. Add Robos to leaderstats.
- **Files:** `src/wildbound/WildboundServer.server.luau`, `src/wildbound/WildboundEggCarry.luau`, `src/wildbound/WildboundRaid.luau`, `src/wildbound/WildboundText.luau`, `src/wildbound/WildboundClient.client.luau`
- **Studio:** Pull the live EggCarry and Server first. Ship with baseRaid = false. Solo Play only checks that the prompt is hidden from the owner and that the refusals work. The owner runs Test > Clients and Servers with 2 players (O5), then flips the flag.
- **Tests:** Every refusal reason, hold timing, egg count kept across steal and bank, notice sent, EggCarry suite still green. A written 2-player script: steal, owner bats, drop, re-grab, lock refuses, thief leaves, egg returns.

### F12. Merge big4 (owner-gated; can move earlier once O8/O9 is approved)

- **Why:** Montañas and Volcán content and portals need Biomes.mode() and AREAS_BIG4, which exist only on agus/big4-map. The live place already runs big4. (Plan 3 M4, Plan 1 M8 first half)
- **Size:** S. **Risk:** Medium (merge conflicts). No save risk.
- **Scope:**
  - After O8/O9, merge agus/big4-map (3 commits, 13 files) with GitHub Desktop's git. Fix conflicts in WildboundBiomes and BiomeLight.
  - Check that F4's mode filter now reads Biomes.mode(). Never run the map switch at runtime.
  - If the owner picks the classic map, skip F12 and F13.
- **Files:** `E:/juego roblox/wb-big4/src/wildbound/WildboundBiomes.luau`, `E:/juego roblox/wb-big4/tools/WildboundMapModeSwitch.luau`, `E:/juego roblox/wb-big4/tools/WildboundBig4Annex.luau`, `E:/juego roblox/wb-big4/tests/WildboundBig4Map_Test.luau`, `src/wildbound/WildboundBiomeLight.luau`
- **Studio:** Code sync only, after the target is confirmed. No map edit and no mode switch.
- **Tests:** Big4Map, BiomeLight, PlacePhase and BeastSight green, plus the F1 baseline unchanged. Big4Map_Test stations-inside-squares check with the hub arches excepted.

### F13. Montañas and Volcán: nests, eggs, and their portals

- **Why:** N/S biomes hold only scenery and are about 50 s away on foot against about 7 s for W and E (B7). Every zone needs something to steal, with better eggs further out. (Plan 1 M8 second half and M9, Plan 3 M6, Plan 2 M8)
- **Size:** L. **Risk:** Medium: nests floating or buried on scaled clone geometry, and beast tuning on new terrain. Needs a Play walk per nest.
- **Scope:**
  - 3 to 4 data-driven nests per biome in the WildboundIslandLayout style, spawned at runtime, with sleeping parents and guardians from existing beasts only (no new art). Add SpawnGraph wave-egg points inside the big4 squares.
  - Higher rarity weights there (option F, as data only).
  - 2 outbound arches in the hub ring and 2 return arches near (27,-415) and (582,442), gated by mode, with arrival pads, grace and streaming as in F5.
  - Restock stays in Heist.resetNestsForWave.
- **Files:** `src/wildbound/WildboundIslandLayout.luau`, `src/wildbound/WildboundIsland.luau`, `src/wildbound/WildboundSpawnGraph.luau`, `src/wildbound/WildboundBeastConfig.luau`, `src/wildbound/WildboundPortal.luau`, `src/wildbound/WildboundPortalService.luau`
- **Studio:** Sync after the target is confirmed. Solo Play: each new nest by portal, steal, walk home, plus all 4 outbound and 4 return arches. The owner saves.
- **Tests:** IslandLayout tests: inside the squares, 64 studs or more apart, raycast floor. Portal tests: 2 out and 2 home in classic, 4 and 4 in big4. A wave restock case.

### F14. Two-player and phone release gate

- **Why:** Nothing has been tested with 2 players or on a phone. Every PvP path and touch control must be seen before baseRaid is switched on or anything is published. (Plan 3 M11, Plan 2 M9)
- **Size:** S. **Risk:** No code risk. It depends on the owner's time.
- **Scope:**
  - The AI writes the checklist in odd/tasks/wildbound-2-0.md (T10): bat and pickup race, every portal both ways, simultaneous selling and farming, the F11 script, a save after a theft.
  - Phone pass: Mochila, toasts, the portal channel bar, Candado, Cofre, Vender and Liberar, big4 FPS (B7).
  - The AI fixes the reported bugs and updates overview section 13 with the observed results.
- **Files:** `odd/tasks/wildbound-2-0.md`, `docs/wildbound-game-overview.md`, `docs/handoff/HANDOFF-2026-11-16.md`
- **Studio:** Owner-run Test > Clients and Servers (2 to 3 players) and a real phone. The owner saves, sets Max Players to 8, and publishes only with an explicit OK.
- **Tests:** Manual multi-client and phone checks, recorded as evidence. Existing suites with no new reds.

## Needs the owner

- Confirm the Studio instance and place 122652861404212 before every sync (AGENTS.md rule).
- O1: save the place (Ctrl+S) before F1 and after every milestone deploy. AIs never save.
- O6: set Max Players to 8 (needed by F3, which retires the camp's role as a spawn).
- O4: approve option A (income labels) and option B (Cofre collect) for F7, option F (better eggs in far zones) for F13, and option G (stealing from bases) with its rules before F9 to F11: eggs only, incubating plus banked, 1 steal per owner per 90 s, last egg protected, 60 s lock and 150 s cooldown.
- Decision 47: re-confirm that egg carriers stay refused by portals in both directions under the new hub-portal design. All three plans and the final plan keep 'refuse'.
- O8/O9: approve the big4 map so F12 can merge agus/big4-map. If the owner says yes early, F12 can move right after F1. If the owner picks classic, skip F12 and F13.
- Approve a separate isolated-persistence experiment for testing the egg-transfer save ordering against real DataStore data (F9).
- O5: two-player (Clients and Servers) and real phone tests. Required before baseRaid is switched on (F10, F11) and before any publish (F14).
- Coordinate with the Team Create teammate before F9 to F11 touch their former lock-zone scripts (WildboundServer, WildboundState, WildboundEggCarry, WildboundBatKnock).
- O7: allow running the economy sim with Blender's bundled Python (-I -B) after F7 and F11 change the gold and egg flow.
- Any asset upload (new arch, sign or barrier meshes) and any publishing needs separate explicit approval. The plan uses primitive parts only.
- O10: merging into main stays the owner's call.

## Genre research (generic mechanics only)

- **Genre core loop (Steal-a-X family) and why it works:** The loop is: get a unit (buy it from a central conveyor, or steal it from a guarded spawn or zone), carry it home, place it on your own plot, and it earns money every second. You spend that money on better units and upgrades (speed, slots), steal from or defend against other players' bases, then rebirth for a permanent multiplier. Why it works for kids: (1) there is one verb and one goal, so it is readable in seconds. (2) Real players are the threat, so idle collecting turns into a social cat-and-mouse game, and thefts and rare reveals make shareable moments. (3) Big visible numbers and rare tiers give variable rewards. (4) Simple controls suit mobile. Critics call the loop thin (buy, wait, steal or defend, rebirth), so depth has to come from zones, events and rarity. Sources: medium.com/@emtertoszef/steal-a-brainrot-phenomenon-6af7b49081e0 ; realsport101.com/article/steal-a-brainrot-phenomenon-what-traditional-sports-can-learn-from-viral-gaming ; games.gg/roblox/guides/steal-a-brainrot-ultimate-beginners-guide/ ; allthings.how/steal-a-brainrot-roblox-efficient-stealing-events-and-rebirths ; games.gg/roblox/guides/steal-an-egg-beginner-guide/
  - Missing in Wildbound: Sources are fan or affiliate guides with conflicting numbers. Treat all numbers as hypotheses to tune in Wildbound's own economy sim.
- **Generic mechanics catalogue (mechanics only, nothing to copy):** M1 Plot per player in a shared hub: about 8 bases around a safe center, each with a sign showing the owner. M2 Unit source: either a central conveyor where units walk past and you buy them with a rarity-weighted spawn timer, with rarer units on longer timers announced to the server, or guarded nests in zones you steal from (the egg variant). M3 Zones and biomes gated by a stat (usually speed). Meeting the gate is not enough to escape while carrying, which pushes treadmill or speed upgrades (bloxodes.com/articles/steal-an-egg-beginners-guide ; bloxodes.com/wiki/steal-an-egg). M4 Portals and rifts: portals spawn at random or on events and lead to special eggs or bosses, and boss kills advance a mastery track (allthings.how/steal-an-egg-how-to-find-rifts-and-get-boss-tokens-fast/ ; bloxodes.com/articles/steal-an-egg-rift-event-guide). M5 Hatch on the base: place the egg on the plot, a visible timer counts down, then press hatch. Eggs keep hatching offline (allthings.how/?p=117906). M6 Income per second shown above each placed unit, collected by stepping on a pad or button. There is a cap or a stored-cash display (games.gg/roblox/guides/steal-an-egg-all-eggs-pets-and-income-rates/). M7 Offline income, often at a reduced rate. Sources conflict (earnaldo.com/blog/steal-an-egg-beginner-guide ; stealabrainrotcalculator-org.pages.dev/guides). M8 Stealing from other players' bases: walk in, grab a unit, carry it slowly back to your own base while the owner can hit you to make you drop it. M9 Base lock: a button closes the base with a laser or wall for a countdown. Guides report about 30 to 60 s, growing with rebirth. A big visible timer creates timing tension for both thief and owner (rblxguide.com/games/steal-a-brainrot/updates/steal-a-brainrot-base-defense-guide-2026 ; fictionhorizon.com/?p=384686). M10 Gear and tools: slap or knockback, traps, speed items, with timing around lock expiry (driffle.com/blog/how-to-steal-in-steal-a-brainrot/). M11 Rebirth: spend cash plus specific units for a permanent multiplier, more slots and a longer lock. Costs grow steeply (bloxodes.com/wiki/steal-a-brainrot/rebirths ; allthings.how/jump-to-steal-an-egg-biome-progression-and-rebirth-guide-roblox/). M12 Mutations and traits: a random modifier at spawn or hatch multiplies income and makes duplicates exciting (sportskeeda.com/roblox-news/all-mutations-effects-steal-brainrot). M13 Server-wide timed events with boosted rare odds (allthings.how/steal-a-brainrot-roblox-efficient-stealing-events-and-rebirths). M14 Leaderboards for cash or rebirths in the hub. No source detail found, but this is standard in the genre. M15 Index or collection book of all units (bloxodes.com/wiki/steal-an-egg). M16 Big mobile-friendly buttons: Lock, Collect, Sprint, Hatch.
  - Missing in Wildbound: No reliable source for leaderboards or exact lock and offline rules. The design must pick its own values.
- **Already in Wildbound:** Hub with 8 player bases, assignment, delivery, safe disc and spawn pads (Done, overview line 605). Steal eggs from guarded nests in zones, with rarity-based steal time on Caramelo (0.5 / 0.9 / 1.3 / 1.8 s). Carry the egg home past beasts, with a capped carrier speed. The bat knocks a carried egg loose so other players can take it in the field. Hatching via incubator on the server clock, which keeps running wherever the owner is, so it partly covers offline hatching. Farm: placed creatures earn Esencia and gold per minute, with an uncollected cap of 15 minutes (Balance farm.incomePerMinute). Gold for farm slots 5 and 6 and treadmill levels. A treadmill builds speed, and creatures scale to the player's training. Selling creatures and releasing duplicates. Four zones in the big4 map plus the classic map. Return portals from zones to the home base pad (calm 5 s, channel 2 s, cooldown 30 s, refused while carrying an egg). A boss, a tower with the best egg at the top, a wave clock and wave board (RW3), a roulette, and a collection or index (entries unlocked by hatching).
  - Missing in Wildbound: All of this is verified solo only. Nothing is tested with 2 players or on a phone (handoff O5).
- **Missing vs genre (ranked by impact on 'playable and genre-like'):** 1. Stealing from other players' bases (M8). It is only option G, deferred (handoff O4). Today the only player-vs-player play is the bat knock in the field. 2. Base lock with a visible countdown (M9). Not found: no lock code in src. 3. Hub-to-zone portals (M4). The existing portals only go zone to home and refuse egg carriers. There are no portals from the hub out to the four biomes, and no random or event portal leading to special eggs or a boss. 4. Income shown above each farmed creature, per second (M6). This is option A, not built, and income is per minute. 5. Hatching on the base floor as visible egg pads with a timer: the incubator is hidden in the UI (WildboundCampView.HIDDEN), so whether the floor hatch is visible needs checking. 6. Rebirth with a permanent multiplier (M11): not found in src. 7. Leaderboard or leaderstats (M14): none found in src (the wave board is session-only). 8. Mutations at hatch (M12): option C, not built. 9. Explicit offline income on rejoin (M7): farm accrual is capped at 15 minutes, and a payout after rejoining is not confirmed. 10. Server-wide timed events with boosted rare odds (M13): Caramelo L1 legendary nest event pending (B10). The wave clock could host it. 11. Mobile buttons such as Lock, Collect and Hatch (M16): not verified on a phone (O5, B2). 12. Collect pad or button with a stored-cash display above the base: depends on how the farm collection gather is presented.
  - Missing in Wildbound: Absence of a base lock, rebirth and leaderboard is based on a grep of src for rebirth, leaderstats, leaderboard, lock and offline terms. Studio-only scripts were not checked.; Owner decisions still needed: O4 (economy options A to G, which includes stealing from bases) and whether hub-to-zone portals should allow egg carriers (decision 47 currently refuses them on return portals).; Whether egg hatching is visible on the base floor was not confirmed in code.
