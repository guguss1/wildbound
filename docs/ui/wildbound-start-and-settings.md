# Wildbound start screen, tutorial, settings and wave W9 fixes

Wave W9, written 2026-11-07 by the single Studio writer while the user slept ("take decisions, record them, keep advancing"). Every decision below is a hypothesis for the user to review. Nothing here is persisted: no DataStore, settings live in memory for the session only.

## Part A. Fixes carried over from W5 to W7

### A2. The wrong prompt near camp (found in W3b)

Reproduction (live markers, read in Studio): `ExtractionMarker` (-146, 140), `HatchMarker` (-135, 146) and `ProtectionMarker` (-135, 134) each carried a 12 stud prompt on the same key E. Prompts on one key show only the nearest, so a player standing at about (-135, 140) had Hatch or the protection hint on E while the extraction marker, 11 studs away, was hidden: E did the wrong thing. This is the same mechanism fixed for gathering in W7.

Fix: `src/wildbound/WildboundPromptKeys.luau` (pure data, `ServerScriptService.WildboundPromptKeys`) gives each camp prompt its own keyboard key, gamepad button and screen offset: Extract E / ButtonX (unchanged), Hatch R / ButtonB, Protection hint T / ButtonL1, offsets 0, -56 and -112 pixels so touch buttons do not stack. Gather stays G / ButtonY. Lumipol and drop prompts keep E (they are never in the camp's range together). `WildboundServer.server.luau` reads the table. Contracts `tests/WildboundPromptKeys_Test.luau`: RED 4 passed 1 failed (the server script did not use the module), GREEN 5 passed 0 failed.

### A3. World script cleanup never ran on destroy (found in W6)

Measured, not assumed: a probe Script in Play connected to its own `Destroying`, to a `Heartbeat` loop and to an owned folder, then was destroyed from the server. Result: the `Destroying` handler never ran, the loop stopped (485 ticks before and after), the folder stayed. When a Script is destroyed every connection it made dies with it, so no cleanup written inside the script can run (`script.Destroying:Connect(cleanup)` at the end of `WildboundWorld.server.luau` was dead code for this case; it still helps when only the runtime folder or network is removed).

Fix: `WildboundOwnership` (`claim` tags, `sweep` destroys by the tag `WildboundWorldOwned`) and `WildboundWorldGuard` (a separate Script that watches `WildboundWorld` and sweeps when it is destroyed or removed from the game). The world script tags only its own `WildboundWorldRuntime` folder (the guardian and its art live inside it) and the seven remotes it creates. Contracts `tests/WildboundOwnership_Test.luau`: RED 5 passed 2 failed, GREEN 7 passed 0 failed.

Play check (server, damage off): before destroying `WildboundWorld`: runtime present, 7 remotes, 8 tagged objects, 18 children in `WildboundNetwork`, 7 in the map. One second after: runtime gone, 0 of the 7 remotes, 0 tagged, 11 children in the network (the inventory's `Action` and `State` untouched), 6 in the map. Only the script's own objects were removed. Costs one more Script in `ServerScriptService`; if both are deleted nothing is swept.

### A5. Camp list on a sideways phone (found in W7)

The list showed about 1.5 rows on a Galaxy A06 held sideways (interface 705 x 280): each row carried a long sentence beside a 98 pixel button and a tab note took another line. Decision: the compact layout applies only to a phone held sideways (`View.sideways`: wider than tall and short side 500 or less). Two columns were rejected: a row needs its text beside a 44 pixel button, and at 409 pixels of panel width a column is about 190, which leaves under 80 for words. What changed instead:

- Rows use a short wording, `Title: price.` or `Title: reason.`, where a missing price reads "Short 8 Fogbark, 4 Glowmoss" instead of "Need 8 more Fogbark and 4 more Glowmoss". The effect sentence ("saves one bag item...") is not shown in this layout; portrait phones and desktop still show it. That is a real loss of information on sideways phones.
- A compact row may be 48 high (a 44 button plus 2 each side) instead of 56.
- The tab note is hidden on a sideways phone (`View.listArea`), so "Session only" is not repeated on the Bag tab there. The start screen, the how-to-play text and the Settings panel say it instead.
- Result by calculation, panel height 218 on the A06 interface: list height 162 (was 140) and three rows of 48 with gaps (was 1.8 rows of 76). iPhone 17 Pro sideways (750 x 323): list height 205, 3.8 rows.

Contracts `tests/WildboundCampView_Test.luau` (CV-C1 to CV-C6): RED 15 passed 4 failed, GREEN 19 passed 0 failed. Phone captures are listed in Part C once taken.

### A4. The dropped-item notice was cut off (found in W6)

Cause: on a first strike the world script sent one long sentence, "Silueta marked you! Next hit defeats you. Dropped: Lumipol egg. Grab it within 30 s. Rest at camp or shelter to clear the mark." (about 130 characters), and the world client showed `payload.notice` directly. On a phone the HUD cuts text at the last whole sentence that fits, which left only "Silueta marked you!": the drop and its 30 s were lost.

Fix: `FairStrike.strikeNotice(effect, dropped)` returns the unchanged full sentence plus a short form, "Marked! Grab your dropped Lumipol egg within 30 s." (49 characters, "Marked! Next hit defeats you. Rest at camp." when nothing dropped). The resolved payload carries `noticeShort` and the client uses `View.pickNotice(payload, compact)`, as the snapshot notices already did. Contracts FS-N1 to FS-N3 in `tests/WildboundFairStrike_Test.luau`: RED 36 passed 3 failed, GREEN 39 passed 0 failed. The phone capture is listed in Part C.

## Part B. Start screen, tutorial and settings (M8.5, M8.6)

### B1. Decisions taken (all for the user to review)

| # | Decision | Why |
| --- | --- | --- |
| W9-1 | The start screen appears at every join (the session is the first run: nothing is saved). Play closes it. The game keeps running behind it; the camp is a safe area, so nothing was frozen. | No persistence is allowed, so "first start" can only mean "this session". |
| W9-2 | D11 is applied: Reduced effects starts Off (the world client default changed from On to Off) and has its own toggle button on the start screen. | Roadmap D11. |
| W9-3 | Settings are two toggles: Reduced effects and Tutorial hints. Graphics quality and audio sliders were not built: the game has no sounds and no quality knobs to control, and a slider that changes nothing would be dishonest. Text size was not built either, because scaling text breaks the pixel budgets the layouts are checked against. These stay open for M8.6. | Only controls that do something. |
| W9-4 | The quick bar already exists: the HUD button column (Inventory, Flashlight, Pulse, Reduced) plus the Bag tab quick rows (Seal newest, Arm). No new bar was added; X10 (contextual phone buttons) stands. | A fifth button does not fit the 280 pixel tall sideways layout. |
| W9-5 | Reaching Settings again: a Menu button in the inventory panel header (and the M key). | The HUD column has no room for a fifth button on a sideways phone. |
| W9-6 | The tutorial has three steps: gather, extract, then open the Camp tab. Crafting is not required because the first recipe costs more (8 Fogbark, 4 Glowmoss) than one trip pays. | The roadmap's "gather, extract, craft" cannot be completed on the first trip. |
| W9-7 | The tutorial reads only the player's own state snapshot. It never changes game state, never calls the server and never blocks play. Skip ends it for the session; Replay tutorial in Settings restarts it. Tutorial hints Off hides the card. | Tutorials must not be a gate. |
| W9-8 | The tutorial card hides while the inventory panel is open and during a capture, because both occupy the same space. | Collisions found by the layout contracts. |
| W9-9 | Strings are plain English, and "Progress is not saved." is said on the start screen. | Session only. |

### B2. Pure modules and contracts

| Module (Explorer path) | Role | Contracts | RED | GREEN |
| --- | --- | --- | --- | --- |
| `WildboundSettings` (`ReplicatedStorage`) | Defaults, validated set and toggle, labels | `tests/WildboundSettings_Test.luau`, 8 | 1 passed, 7 failed (against a stub) | 8 passed, 0 failed |
| `WildboundTutorial` (`ReplicatedStorage`) | Ordered steps, facts from a snapshot, skip and restart | `tests/WildboundTutorial_Test.luau`, 12 | 1 passed, 11 failed (stub) | 12 passed, 0 failed |
| `WildboundStartView` (`ReplicatedStorage`) | Rectangles and words for the start screen, Settings, How to play and the card, on nine viewports | `tests/WildboundStartView_Test.luau`, 8 | 1 passed, 7 failed (stub) | 8 passed, 0 failed |

The first RED of each pure unit is against an empty module, so the one passing case is the purity check on the stub's source. One test defect was found by the run: the purity check searched for the word `tick` and matched `thumbstick`; it now searches `tick(`.

The start-view contracts check, on 750x323, 705x280, 401x720, 359x660, 1069x501, 1280x720, 640x360, 320x568 and 1920x1080: every panel inside the region; on phones no overlap with the thumbstick or jump zones; every button and toggle 44 pixels or more in both directions; no two elements overlap; every text fits its rectangle by the same 0.6 character-width estimate the HUD tests use. The tutorial card has three places: beside the Inventory button on desktop (`side`), in the band under the avatar keep-out on a phone held sideways (`bottom`), and over the HUD objective line on a phone held upright (`hud`), because the keep-out leaves under 50 pixels there (26 on the Galaxy A06). In `hud` mode the objective line is covered on purpose while the tutorial runs.

### B3. Controller and wiring

`src/wildbound/WildboundStart.client.luau` (`StarterPlayerScripts.WildboundStartClient`, `WildboundStartUI`, `DisplayOrder` 30, above the capture screen at 20 and below the loss summary at 50). It builds the screens from `WildboundStartView`, keeps session-only state in `WildboundSettings` and `WildboundTutorial`, reads the player's own state snapshot from the existing `State` remote, and never fires a remote. If a shared module is missing it warns and the game starts without it.

- Reduced effects: the world controller still owns the value (attribute `Reduced` on `WildboundWorldUI`). The start screen sets it and follows it, so the HUD button, the start screen and Settings always agree. The world controller now starts Off (D11); the HUD button reads "Reduced: Off" at join.
- The inventory header has four buttons (Bag, Camp, Menu, Close), each at least 44 wide; on a narrow panel they shrink and their text drops to 13. Menu closes the panel and opens Settings. `M` opens and closes Settings from the keyboard. The inventory publishes the open tab as the attribute `PanelTab` on `WildboundUI`; the tutorial reads it.
- Test seams, all local to the client and changing nothing on the server: attribute `Screen` on `WildboundStartUI` ("start", "settings", "howto", "closed"), `TestAction` (plays a button handler by name and clears itself so it can repeat), and `TestSnapshot` (a JSON snapshot for the tutorial). Needed because mouse and key input from the tooling do not reach the Play window, as in earlier waves.
- `tests/WildboundStartWiring_Test.luau` (9 contracts) checks the wiring at source level. WIRE-8 and WIRE-9 were written after the code they check (a TDD gap, recorded); their RED was not observed. RED for WIRE-1 to WIRE-7 was 0 passed 7 failed, GREEN 7 passed 0 failed, then 9 of 9.

### B4. Known limits of this build

- Replay tutorial restarts the state machine, but the tutorial reads the real snapshot, so a player who already has banked stock resumes at the first step not yet met (observed: "camp" after Replay). A baseline snapshot would fix it; not built.
- The start screen sits over a running game. Silueta cannot reach the camp (a safe area), but a player who walks off before pressing Play is not frozen.
- Settings has two toggles only (W9-3). No audio or graphics controls exist because nothing in the game uses them yet.

## Part C. Play results and captures (Studio, Device Simulator, damage off)

Studio instance `81631061-9001-4c69-be21-f79a34aaa1d8`, place `122652861404212`, confirmed before the first edit. Device Simulator profiles (as listed by `GetDeviceListAsync` in this Studio): iPhone 17 Pro, interface 750 x 323 sideways and 401 x 720 upright; Samsung Galaxy A06, 705 x 280 sideways and 359 x 660 upright. Emulation, not phones.

| Check | Result |
| --- | --- |
| Start screen at join, all four phone views, Play closes it | PASS. Captures below. Panels 331 x 260 and 304 x 260 sideways, 360 x 260 and 343 x 260 upright; clear of the thumbstick and jump button in the captures |
| Reduced effects off at join; start-screen toggle flips it; HUD button and attribute follow; toggle repeats | PASS (HUD "Reduced: Off" at join; toggled to On and back through the seam, button text, attribute and start screen text agreed each time) |
| How to play and Settings screens | PASS (captured on iPhone 17 Pro sideways) |
| Tutorial with real gameplay: gather by a real prompt hold, extract by a real prompt hold at camp, open the Camp tab | PASS: card went 1/3, 2/3, 3/3, then "That is the loop: gather, extract, craft." for 5 s, then hidden. The first extraction attempt, 11.2 studs from the marker (inside the 12 stud prompt range), did not extract; a second at 3 studs did. The first attempt was not investigated further |
| Tutorial with injected snapshots, Skip, Replay, Tutorial hints toggle, card hidden with hints off | PASS through `TestSnapshot` and `TestAction` |
| Prompt keys at camp (A2) | PASS in the client: Hatch R, Extract E, Protection T, offsets 0/-56/-112, gather 18 prompts on G. Not run: pressing the keys, which cannot be sent |
| World script destroy (A3) | PASS, numbers in A3 |
| Dropped-item notice (A4) | PASS: the server fired a real `AttackResolved` payload built by `FairStrike.strikeNotice`; Galaxy A06 sideways shows both lines, "Marked! Grab your dropped Lumipol egg within 30 s." (text bounds 203 x 25.6 in a 223 x 31 box); upright shows it on one line |
| Camp list on a sideways phone (A5) | PASS: Galaxy A06 sideways, 164 high list, three rows fully visible (stock, Ward Seal, Last Breath Totem) and the fourth cut by the scroll area (before: two rows and two section titles) |
| Capture ring stillness (A1) | Contract only (108 passed). Not run live: a live shuffle needs a script that follows the ring |
| Studio left in Edit mode, no device emulation, no leftover `W9` objects | PASS (read back) |

Captures, `assets/exports/forest-kit/captures/`: `ui-start-iphone17pro-landscape.jpg`, `ui-start-iphone17pro-portrait.jpg`, `ui-start-galaxya06-landscape-reduced-on.jpg`, `ui-start-galaxya06-portrait.jpg`, `ui-settings-iphone17pro-landscape.jpg`, `ui-howto-iphone17pro-landscape.jpg`, `ui-camp-galaxya06-landscape-three-rows.jpg`, `ui-camp-galaxya06-landscape-before-headers-removed.jpg` (the state after the first fix, two rows and two titles), `ui-notice-and-tutorial-galaxya06-landscape.jpg`, `ui-notice-and-tutorial-galaxya06-portrait.jpg`, and `ui-tutorial-card-iphone17pro-portrait-before-opaque.jpg` (the card was translucent and the objective line showed through; now opaque). Each was looked at: text fits, nothing touches the thumbstick or jump button, and the sideways panels leave the avatar side visible.

Not verified: any tap on a phone or in the emulator (input does not reach the Play window), a real phone, a muted client, two clients, the Menu button's click (the same Settings screen was opened through the `Screen` seam), keys R and T, a live capture with the new stillness rule, and whether people understand the tutorial without help.

### Where earlier documents were wrong or silent

| Document | Point | Correction |
| --- | --- | --- |
| `odd/tasks/wildbound-waves.md` W6 | "cleanup never runs on destroy" | Measured: it is worse, every connection of a destroyed Script dies, including its own `Destroying` handler (A3) |
| `docs/ui/wildbound-world.md` | "Reduced effects default on" | Default is now off (D11) |
| `docs/mechanics/wildbound-economy-p0.md` | "prompts on one key show only the nearest ... camp prompts keep E" | The three camp prompts shared E and one could hide another; now separate keys (A2) |
| `docs/wildbound-roadmap.md` M8.5 (read only, not edited) | "gather, extract, craft" | The first recipe cannot be afforded after one trip, so the tutorial's third step is looking at the Camp tab (W9-6) |
| Text estimate | The 0.6 character-width estimate used by every view | Measured in Studio: Gotham at 13 px averages about 5.6 pixels per character, about 0.43 of the size. The estimate is safe but wastes room (rows come out taller than their text needs) |
