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
