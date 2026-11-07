# Wildbound start screen, tutorial, settings and wave W9 fixes

Wave W9, written 2026-11-07 by the single Studio writer while the user slept ("take decisions, record them, keep advancing"). Every decision below is a hypothesis for the user to review. Nothing here is persisted: no DataStore, settings live in memory for the session only.

## Part A. Fixes carried over from W5 to W7

### A2. The wrong prompt near camp (found in W3b)

Reproduction (live markers, read in Studio): `ExtractionMarker` (-146, 140), `HatchMarker` (-135, 146) and `ProtectionMarker` (-135, 134) each carried a 12 stud prompt on the same key E. Prompts on one key show only the nearest, so a player standing at about (-135, 140) had Hatch or the protection hint on E while the extraction marker, 11 studs away, was hidden: E did the wrong thing. This is the same mechanism fixed for gathering in W7.

Fix: `src/wildbound/WildboundPromptKeys.luau` (pure data, `ServerScriptService.WildboundPromptKeys`) gives each camp prompt its own keyboard key, gamepad button and screen offset: Extract E / ButtonX (unchanged), Hatch R / ButtonB, Protection hint T / ButtonL1, offsets 0, -56 and -112 pixels so touch buttons do not stack. Gather stays G / ButtonY. Lumipol and drop prompts keep E (they are never in the camp's range together). `WildboundServer.server.luau` reads the table. Contracts `tests/WildboundPromptKeys_Test.luau`: RED 4 passed 1 failed (the server script did not use the module), GREEN 5 passed 0 failed.
