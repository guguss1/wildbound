# Wildbound world presentation

The local controller uses `WildboundNetwork.WorldAction` and `WorldState`. It sends only `RequestSnapshot`, `Flashlight`, or `LumipolPulse`, with no target, position, or eligibility arguments. Full server snapshots provide the shared phase, cooldown deadlines, fog/safe status, threat/reveal state, and verified equipped Lumipol eligibility. The server remains authoritative; the local companion is decorative only.

The phase and warning panel sits below the inventory HUD; the panel and two 44-pixel action buttons hide while `WildboundUI.InventoryPanel` is open. F and Q respect processed input and focused text boxes. Reduced effects default on; neither setting uses screen flashes or camera shake. Fog and lighting transitions are local and smoothed; an existing Atmosphere is restored on cleanup, or a controller-owned Atmosphere is removed. This assumes one world controller owns these local Lighting properties: simultaneous unrelated Lighting controllers require integration testing. Visual intensity has not been measured. Guardian visuals are server-owned, with an explicit attack warning and text cues independent of audio. Stale world state disables actions and displays an unavailable status.

Placement: the LocalScript lives in StarterPlayerScripts alongside the inventory controller, deployed from 2026-11-05. Do not run or deploy this source through an alternate context. The bounded initial snapshot retry does not claim connectivity on failure.

Solo Studio runtime checks ran on 11-05, including F and Q inputs with cooldowns and the accelerated phase boundaries and dusk warning (`odd/tasks/wildbound-first-playable.md:119`, `:132`). Pending: server/client and respawn lifecycle, reconnect/stale state, overlapping Lighting ownership, touch interactions, small screens and safe areas, Device Emulator, physical mobile devices, and performance measurements. Accessibility and device verification have not been performed.

