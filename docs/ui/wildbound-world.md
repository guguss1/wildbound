# Wildbound world presentation

The local controller uses `WildboundNetwork.WorldAction` and `WorldState`. It sends only `RequestSnapshot`, `Flashlight`, or `LumipolPulse`, with no target, position, or eligibility arguments. Full server snapshots provide the shared phase, cooldown deadlines, fog/safe status, threat/reveal state, and verified equipped Lumipol eligibility. The server remains authoritative; the local companion is decorative only.

The phase and warning panel sits below the inventory HUD; the panel and the action buttons hide while `WildboundUI.InventoryPanel` is open, but the awareness chip (below) does not, and F and Q keep working with the inventory open. F and Q respect processed input and focused text boxes. Reduced effects default on; neither setting uses screen flashes or camera shake. Fog and lighting transitions are local and smoothed; an existing Atmosphere is restored on cleanup, or a controller-owned Atmosphere is removed. This assumes one world controller owns these local Lighting properties: simultaneous unrelated Lighting controllers require integration testing. Visual intensity has not been measured. Guardian visuals are server-owned, with an explicit attack warning and text cues independent of audio. Stale world state disables actions and displays an unavailable status.

## Night lighting pass (2026-11-07, task T7)

Values live in `src/wildbound/WildboundWorld.client.luau` (Studio copy `StarterPlayer.StarterPlayerScripts.WildboundWorldClient`, byte-equal by length and two hashes). Only the colour targets changed; Day targets, fog distances, atmosphere density, haze, Brightness, the clock schedule, Bloom and Sky are untouched. Studio's saved Lighting properties were not edited; the controller changes them locally at runtime and restores them on cleanup.

| Property (target) | Old | New |
| --- | --- | --- |
| Night `Ambient` | RGB 44, 56, 58 | RGB 34, 46, 76 |
| Night `OutdoorAmbient` | RGB 49, 60, 65 | RGB 40, 54, 86 |
| Night `FogColor` in the fog zone | RGB 96, 110, 105 (shared with Day) | RGB 40, 54, 72 |
| Night `Atmosphere.Color` in the fog zone | RGB 140, 153, 145 (shared with Day) | RGB 78, 94, 116 |
| Day fog and atmosphere colours | RGB 96, 110, 105 and 140, 153, 145 | unchanged |

With Reduced effects On (default) the targets blend 45% from the place's own values. Readback at night: Ambient 54, 59, 73; OutdoorAmbient 56, 63, 77; FogStart 45; FogEnd 180; atmosphere density 0.35, haze 0.5.

Lantern lights: each of the 16 `FK_LanternMarker` glass parts carries one `PointLight` (Brightness 1.0, Range 18, RGB 255, 165, 85, Shadows off), added by `tools/dress-wildbound-forest.luau` and mirrored on the live models. A first try at Brightness 1.6, Range 20 tinted the whole path orange and was reduced. The glass stays Neon RGB 205, 92, 18. Other Lights in the place: the camp fire glow and the two Lumipol and egg glows.

Evidence: Studio Play captures at night (clock about 21 and 2) and by day, desktop and Device Simulator iPhone 17 Pro. In the night desktop capture the path is 1.8 to 2.5 times brighter than the ground beside it, the lantern glass 14 times brighter than its surround, and the avatar silhouette 2.4 times darker than the path, so legibility does not rely on hue alone. These are single-capture pixel samples. Phone emulation is not a real phone, and real-device frame rate is unmeasured.

Known layout issue found in the phone capture: with the default centered camera on a 750 x 381 landscape viewport, the world panel and action buttons cover the avatar (`assets/exports/forest-kit/captures/final-day-phone-hud-overlap.jpg`). This pass did not change the HUD. Wave W3b fixed it; see "Awareness chip and compact HUD" below.

Placement: the LocalScript lives in StarterPlayerScripts alongside the inventory controller, deployed from 2026-11-05. Do not run or deploy this source through an alternate context. The bounded initial snapshot retry does not claim connectivity on failure.

Solo Studio runtime checks ran on 11-05, including F and Q inputs with cooldowns and the accelerated phase boundaries and dusk warning (`odd/tasks/wildbound-first-playable.md:119`, `:132`). Pending: server/client and respawn lifecycle, reconnect/stale state, overlapping Lighting ownership, touch interactions, small screens and safe areas, Device Emulator, physical mobile devices, and performance measurements. Accessibility and device verification have not been performed.

## Guardian smoothing (M2.6, wave W3b)

The baseline measured Silueta moving in 0.6 stud (patrol) and 1.2 stud (hunt) jumps every 0.2 s with no interpolation (`docs/testing/wildbound-baseline-m1.md`, guardian smoothness). The client now slides the visible art and the ground cue between the last two server poses.

- Pure rule: `src/wildbound/WildboundGuardianSmoothing.luau` (Explorer `ReplicatedStorage.WildboundGuardianSmoothing`), 23 contracts in `tests/WildboundGuardianSmoothing_Test.luau`. Numbers only, clock injected.
- Applied in `WildboundWorld.client.luau`, bound last in the render step. It reads `Body.CFrame`, never writes it, and never touches the server: position, detection and strike checks use the real Body. The art model (`SiluetaVisual`) and `GroundCue` are moved locally, using their offsets from Body measured once while the pose has held still for 0.3 s.
- The shown pose trails the server by one step (0.2 s, about 1.2 studs at day hunt speed 6 and 1.6 at night speed 8). That is the price of a slide with no overshoot. A jump above 6 studs snaps. A pause settles exactly on the last pose.
- Without art (static fallback) the primitive Body and Head stay unsmoothed, because they are the authoritative parts.
- Hypothesis: whether the slide reads as smooth on a real device is for people to judge. Measured numbers are in the table below.
- Measurement hook: `WildboundWorldUI:SetAttribute("GuardianSmoothing", false)` on a client shows the raw steps again.

| Client view, 15.1 frames/s, Studio Server and Clients | Step per visible change | Interval between visible changes |
| --- | --- | --- |
| Patrol, before (raw server steps) | 0.600 studs, every change | median 0.200 s, p95 0.267 s, max 0.267 s; the art moved on 32% of frames |
| Patrol, after | 0.202 studs per frame (max 0.217) | 0.067 s, every frame (98% of frames) |
| Hunt at night speed 8, before | 1.600 studs | median 0.200 s, p95 0.267 s |
| Hunt at night speed 8, after | 0.521 studs per frame (max 0.571) | 0.067 s |
| Server Body as a client reads it, either way | 0.600 and 1.600 studs | 0.200 s: unchanged, so server authority is untouched |

The shown art trailed the server Body by a median 1.07 studs, p95 1.74, max 1.83 during a night hunt (one step is 1.6). Three Studio processes on one machine; this is not a display-rate or phone measurement.

## Awareness chip and compact HUD (M2.3, W3b)

Pure rules: `src/wildbound/WildboundHudView.luau` (`ReplicatedStorage.WildboundHudView`, 29 contracts) and `src/wildbound/WildboundHudLayout.luau` (`ReplicatedStorage.WildboundHudLayout`, 23 contracts). Both controllers apply them; nothing else decides layout.

- **Chip.** `WildboundWorldUI.AwarenessChip` is outside `WorldPanel`, so it never hides with the inventory, and `WildboundWorldUI` has `DisplayOrder` 10 so it draws over the inventory panel. It is driven by `guardian.awareness.state` only, never by `threat`. Each state has words and a shape, with colour as a redundant cue:

| State | Shape | Words (desktop, phone) | Tone |
| --- | --- | --- | --- |
| seen | diamond | "Silueta sees you" | amber |
| seen, attack deadline in the future | square, thick border | "ATTACK! Move away!", "ATTACK! Move!" | red, white text |
| searching | ring | "Silueta is searching 1.4s", "Searching 1.4s" | amber ring on dark |
| ally | dot | "Silueta hunts a friend", "Friend hunted" | blue |
| none | dash | "No hunt nearby" | muted. Shown on purpose: an absent chip cannot be told from a broken HUD |
| stale world state | dash | "Waiting for server", "No signal" | muted |

  Every tone has at least 4.5:1 text contrast (contract). No sound is used anywhere. A genuinely muted client could not be run (see below).
- **Inventory.** The chip and the attack warning stay readable with the inventory open (captures below). F and Q also work with it open; the buttons are hidden then, so on a phone the inventory must be closed to tap them. That is a decision, not a measurement of touch use.
- **Layout.** Compact mode applies when the device is touch-first, the short side is 500 or less, or the width is under 1000. Desktop keeps the old geometry plus the chip between the panels and the Inventory button. The Roblox interface is the viewport minus a top inset (58 px on the phone profiles), so the layout is computed from `ScreenGui.AbsoluteSize`, not from the viewport. Avatar keep-out, thumbstick and jump zones are hypotheses taken from the default controls and checked against the live `TouchGui` frames.
- **Collapsed text.** On a phone the long lines are shortened, not shrunk: the objective is one line, a notice takes the message slot (short form from the server, else cut at a sentence), and 13 px is the smallest size. `Reduced` moves to a second column on very short screens.
- **Notices expire** after 6 s (`View.currentNotice`). An attack warning always wins the slot.
- **Companion.** The local Lumipol is `SmoothPlastic` (it was `Neon` and bloomed to a white disc), 1.4 studs, and fades to 0.9 transparency when the camera is within 3 studs. Read back: 0.10 at 15 studs, 0.90 at 2.3 studs. It was not seen up close in a capture.
- Developer wording removed: "Night rewards are not implemented in this P0." is now "Connected to the shared world clock."

Live interface rectangles (x, y, w, h in interface pixels) and the layout check run on them; all four phone views report no rule broken and no text that does not fit:

| View (interface size) | Hud + panel reach | Chip | Buttons (44 px high) | Zones |
| --- | --- | --- | --- | --- |
| iPhone 17 Pro landscape (750 x 323) | 35% of width, bottom y 92 | 269, 8, 212 x 40 | one column at x 632, y 8 to 202 | thumbstick x -100 to 300 from y 107; jump 655 to 725, y 233 to 303 |
| Galaxy A06 landscape (705 x 280) | 35%, bottom y 92 | 253, 8, 199 x 40 | column at x 587 for Inventory, Flashlight, Pulse; Reduced at x 471 | thumbstick from y 93; jump 610 to 680, y 190 to 260 |
| iPhone 17 Pro portrait (401 x 720) | full width, bottom y 146 | 40, 8, 320 x 40 | one row at y 150, 91 px wide each | thumbstick from y 432; jump y 630 to 700 |
| Galaxy A06 portrait (359 x 660) | full width, bottom y 146 | 19, 8, 320 x 40 | one row at y 150, 81 px wide each | thumbstick from y 396; jump y 570 to 640 |

Before (baseline, `docs/testing/wildbound-baseline-m1.md`): panels reached 57% of the width and hid the avatar, and the controls overlapped the thumbstick zone by 1,716 to 4,840 px squared. A first live check of this layout found the Galaxy A06 text block 9 px into the thumbstick zone, because the contracts used viewport heights; the block was tightened and the real interface sizes were added to the contracts.

Captures, in `assets/exports/forest-kit/captures/`: `hud-iphone17pro-landscape-seen.jpg`, `hud-iphone17pro-landscape-seen-inventory-open.jpg`, `hud-iphone17pro-landscape-attack-inventory-open.jpg`, `hud-iphone17pro-portrait-seen.jpg`, `hud-galaxya06-landscape-ally.jpg`, `hud-galaxya06-portrait-ally.jpg`, and desktop `hud-desktop-none-day.jpg`, `hud-desktop-none-inventory-open.jpg`, `hud-desktop-seen-inventory-open.jpg`, `hud-desktop-seen-amber-disc-companion.jpg`.

Not verified: any tap on a phone button (Studio mouse clicks do not activate buttons under a phone profile, and the keyboard hides the touch controls), a real phone, safe areas on a physical notch (the profiles' inset is read, not a device), a genuinely muted client, and whether people read the chip correctly (the five-pair test).

## Capture screen (M3.4, wave W5)

Pure rules: `src/wildbound/WildboundCaptureView.luau` (`ReplicatedStorage.WildboundCaptureView`, 40 contracts). Controller: `src/wildbound/WildboundCapture.client.luau` (`StarterPlayerScripts.WildboundCaptureClient`, `WildboundCaptureUI`, `DisplayOrder` 20). It reads the owner-only `CaptureState` feed and sends only `CaptureCancel` with the token. Mechanics and results are in `docs/mechanics/wildbound-capture.md`.

- **World ring.** 32 thin neon parts made on this client only (nothing replicates, so streaming cannot hide it), placed at the ring centre for the server clock, on the ground by a short raycast with a fallback. Solid and green-white when you are inside, dashed and amber when outside. The pulse is off when Reduced is on (`WildboundWorldUI` attribute `Reduced`).
- **Panel.** One line of words, a meter bar, a glyph and, on panels 70 pixels tall or more, a second line. Each state has its own words and glyph, with colour only as a redundant cue (text contrast at least 4.5:1, meter at least 3:1, both contracts). Direction cue: a rotated arrow in the glyph slot, plus "Move right." and so on on the tall panels.

| State | Words (desktop, phone) | Glyph |
| --- | --- | --- |
| Inside and still | "Stay still..." | o |
| Moving too fast | "Slow down" | \|\| |
| Ring edge within a stud of you | "Step this way" | arrow |
| Outside | "Back into the ring 1.8s", "Back in! 1.8s" | arrow |
| No news from the server for 1 s | "Waiting for server...", "Waiting..." | ... |
| Caught | "Caught!" and "Lumipol is in your bag. Extract at camp to keep it." | OK |
| Failed or stopped | "You left the ring", "Too restless", "Too far from it", "Silueta struck you", "You were defeated", "You stopped", "Lumipol is gone", "Lost track of you", "Capture stopped" (short forms under 17 characters) | X, = |

  The result stays 3 s. The server's own sentence also goes to the status line, so the reason is stated twice. The awareness chip stays above everything, so a Silueta warning is never covered.
- **Placement.** `View.layout` searches for the largest panel (340 x 76 down to 190 x 40) and a 64 x 64 Stop button (56 at the least) that overlap no HUD rectangle, the avatar keep-out, the thumbstick or the jump zone, and the contracts repeat that on 13 viewports. Chosen on the tested interfaces: iPhone landscape 750 x 323, panel 304, 243, 340 x 76, Stop 442, 172. Galaxy A06 landscape 705 x 280, panel 286, 224, 300 x 52, Stop 418, 154. iPhone portrait 401 x 720, panel 52, 196, 300 x 52, Stop 268, 256. Galaxy A06 portrait 359 x 660 has no free band, so the panel is drawn over the objective line (343 x 42 at 8, 52) and Stop sits at 244, 196. Desktop 1069 x 501, panel 364, 421, 340 x 76, Stop 352, 352 (it touches the Flashlight button's margin but does not overlap).
- **Inventory.** Opening it is refused with "Finish calming the Lumipol first." while a session runs, and an open one closes. Keyboard players can press X to stop.
- **Captures** (`assets/exports/forest-kit/captures/capture-*.jpg`, Device Simulator, Play): the calm, outside, failed and caught states on iPhone 17 Pro landscape and portrait, the Galaxy A06 in both orientations, a night fog frame with Reduced on, and the desktop window with the attack chip showing. Looked at: the ring reads at night in fog, the panel and Stop do not touch the stick, the jump button or the avatar, and the text fits. One defect found and fixed from them: the first caught line was cut off at the panel edge (now two lines, and the leading "Caught!" is not repeated). The portrait Stop button can sit over the Lumipol itself.
- **Not verified:** a tap on any button under a phone profile (BLOCKED, same cause as above), a real phone, a muted client, Reduced off, whether people understand the ring without coaching (CAP-36), and the ring over other terrain than the one captured.
