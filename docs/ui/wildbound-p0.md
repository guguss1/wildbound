# Wildbound P0 UI

The compact HUD keeps the objective and latest server notice visible. Inventory opens with **I** or the top-right touch button. It separates the three-slot pending bag, banked eggs, and registered creatures; Protect and Hatch must be used near their camp markers. Seal charges and the session-only loss warning are explicit. Equip, Protect, and Hatch send only the action and item UID; the server decides the result. The UI redraws from server snapshots rather than predicting success.

The panel uses a bounded, scrolling layout. It closes without losing state and survives character respawns. Initial snapshot requests are bounded; reopening inventory retries if no snapshot arrived. No gameplay or progress is owned by the client.

## Verification pending

No Studio runtime, client/server, touch, or device-emulator tests were run in this local-source stage. Check portrait and landscape safe areas, small-screen text, control overlap, scrolling, spawn/respawn duplication, server rejection notices, and two-client updates before considering the UI verified. Gamepad navigation and accessibility beyond the current text and layout have not been validated.

Static width check: with viewport widths of 360, 401, and 750 pixels, HUD widths are 192, 233, and 430 pixels respectively (430 maximum); its right edge remains left of the inventory button at x=216, 257, and 606. Pending entries have distinct current-list numbers for selecting protection. Action buttons are 44 pixels high. These calculations are not device tests.
