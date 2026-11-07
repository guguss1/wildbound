# Wildbound world presentation

The local controller uses `WildboundNetwork.WorldAction` and `WorldState`. It sends only `RequestSnapshot`, `Flashlight`, or `LumipolPulse`, with no target, position, or eligibility arguments. Full server snapshots provide the shared phase, cooldown deadlines, fog/safe status, threat/reveal state, and verified equipped Lumipol eligibility. The server remains authoritative; the local companion is decorative only.

The phase and warning panel sits below the inventory HUD; the panel and two 44-pixel action buttons hide while `WildboundUI.InventoryPanel` is open. F and Q respect processed input and focused text boxes. Reduced effects default on; neither setting uses screen flashes or camera shake. Fog and lighting transitions are local and smoothed; an existing Atmosphere is restored on cleanup, or a controller-owned Atmosphere is removed. This assumes one world controller owns these local Lighting properties: simultaneous unrelated Lighting controllers require integration testing. Visual intensity has not been measured. Guardian visuals are server-owned, with an explicit attack warning and text cues independent of audio. Stale world state disables actions and displays an unavailable status.

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

Known layout issue found in the phone capture: with the default centered camera on a 750 x 381 landscape viewport, the world panel and action buttons cover the avatar (`assets/exports/forest-kit/captures/final-day-phone-hud-overlap.jpg`). This pass did not change the HUD.

Placement: the LocalScript lives in StarterPlayerScripts alongside the inventory controller, deployed from 2026-11-05. Do not run or deploy this source through an alternate context. The bounded initial snapshot retry does not claim connectivity on failure.

Solo Studio runtime checks ran on 11-05, including F and Q inputs with cooldowns and the accelerated phase boundaries and dusk warning (`odd/tasks/wildbound-first-playable.md:119`, `:132`). Pending: server/client and respawn lifecycle, reconnect/stale state, overlapping Lighting ownership, touch interactions, small screens and safe areas, Device Emulator, physical mobile devices, and performance measurements. Accessibility and device verification have not been performed.

