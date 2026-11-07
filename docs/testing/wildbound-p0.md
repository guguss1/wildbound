# Wildbound P0 local verification guide

**Status: deployed and run in Studio on 11-05; the 41 contract cases passed and a first solo session was observed (`odd/tasks/wildbound-first-playable.md:111-118`). Co-op, mobile, rewards and isolated persistence remain PENDING.** This guide records a future authorized workflow; it is not evidence of compilation, RED/GREEN, or gameplay verification. Studio testing was resumed under later authorization (`odd/tasks/wildbound-first-playable.md:108`). Do not work around Studio MCP permission controls through Play, another execution surface, APIs, or HTTP.

## Source-to-Explorer mapping

After a future Studio session's target is reverified and the user confirms it, and the Studio MCP capability issue is resolved through its supported permission flow, deploy only these reviewed sources:

| Local source | Explorer destination | Behavior |
| --- | --- | --- |
| `tools/build-wildbound-p0-map.luau` | `ServerStorage.WildboundP0MapBuilder` (`ModuleScript`) | Manual builder only; it exports `build(parent)` and does not auto-run. |
| `src/wildbound/WildboundState.luau` | `ServerScriptService.WildboundState` (`ModuleScript`) | Pure, session-only authoritative state used by the server script. |
| `src/wildbound/WildboundServer.server.luau` | `ServerScriptService.WildboundServer` (`Script`) | Server-owned interactions and remotes. It creates `ReplicatedStorage.WildboundNetwork` with `Action` and `State` `RemoteEvent`s. Client action names are `RequestSnapshot`, `Equip`, `Protect`, and `Hatch`; action UIDs are strings. State events carry `{ snapshot, notice, action, ok }`. |
| `src/wildbound/WildboundClient.client.luau` | `StarterPlayer.StarterPlayerScripts.WildboundClient` (`LocalScript`) | Client presentation; sends actions and renders server snapshots/notices. |
| `tests/WildboundState_Test.luau` | `ServerStorage.WildboundState_Test` (`ModuleScript`) | Contract suite; call with a freshly cloned State ModuleScript. |
| `tests/WildboundP0Map_Test.luau` | `ServerStorage.WildboundP0Map_Test` (`ModuleScript`) | Detached map-builder contract suite; call with a freshly cloned builder ModuleScript. |

These destinations are a manual mapping, not an import/sync configuration. Keep the existing Rescue scripts untouched. Nothing in the source automatically builds the map: when the user resumes Studio testing after the MCP permission gate is resolved and the target is reverified/confirmed, require the builder and explicitly call `build(workspace)` from the authorized Studio MCP Edit workflow. It creates `Workspace.WildboundP0` and rejects an existing root; inspect the target first and never remove unrelated objects. Leave the existing `Workspace.SpawnLocation` untouched; its exact position was not remeasured here. Any future relocation to camp requires a backup and user confirmation of the target/change.

## Fresh-clone test procedure (future only)

Use an authorized Studio MCP Edit workflow only, after the permission gate is resolved. Keep the legacy `ServerStorage.UnitTest` harness and its contents intact. For the new standalone suites, clone both the test ModuleScript and its dependency for each run, require the clones, and pass the dependency module into the suite; this avoids Roblox's `require` cache hiding changes between runs:

```lua
local storage = game:GetService("ServerStorage")
local serverScripts = game:GetService("ServerScriptService")
local temp = Instance.new("Folder")
temp.Name = "WildboundP0TestClones"
temp.Parent = storage
local stateModule = serverScripts.WildboundState:Clone()
stateModule.Parent = temp
local stateTest = storage.WildboundState_Test:Clone()
stateTest.Parent = temp
local stateResult = require(stateTest)(require(stateModule))

local builderModule = storage.WildboundP0MapBuilder:Clone()
builderModule.Parent = temp
local mapTest = storage.WildboundP0Map_Test:Clone()
mapTest.Parent = temp
local mapResult = require(mapTest)(require(builderModule))
temp:Destroy()
```

Record each returned `passed`/`failed` count and all failure details as observed; destroy the temporary clones afterward. The state contract covers ownership, validation, capacity, extraction, hatch, protection/death, and detached snapshots; the map contract checks bounded anchored geometry, markers, route/decorations, and duplicate-build protection. Neither suite has been run here. Do not report GREEN or syntax/compilation success without direct evidence from the authorized environment.

## Runtime and visual checklist (still pending)

When the user resumes runtime testing after the MCP permission gate is resolved, and only after the standalone contracts are verified, check and record actual results:

- **Shared claim:** two clients race for one encounter; exactly one wins, and the loser cannot claim it later even if the winner is defeated.
- **Server validation:** distant, dead, unknown-player/encounter, malformed, NaN/infinite-distance, and repeated requests are rejected without unintended claims or mutation.
- **Bag/economy invariants:** capacity stops at 3; a fourth encounter remains available; extraction registers creatures and banks eggs; repeat extraction/hatch cannot duplicate rewards; hatch is free and owner-only; sealing requires an earned charge and protects only the selected pending item; defeat drops only unprotected pending items, preserves sealed/banked/registered items, and a repeated death operation is idempotent.
- **Lifecycle:** respawn retains session state; leaving/server stop loses it. Confirm all UI copy describes session-only behavior. No DataStore persistence is implemented or claimed.
- **UI/device:** exercise every action and notice, inventory reopening, and readable HUD/inventory in portrait and landscape touch layouts plus desktop. Measure actual interaction and layout results; don't infer mobile usability from source alone.
- **Map:** walk camp-to-clearing-to-ruin-to-nest-to-marsh-to-shelter-to-camp; inspect joins, bounds, camp clearance, collisions, landmark readability, and actual device performance. The greybox does not create boundary walls or set global fog.

No publishing, DataStore setup, monetization, global lighting change, or production-data operation is authorized by this guide.

## World source continuation
See [world integration and verification](wildbound-world.md) for the separately authored Silueta, flashlight, registered Lumipol pulse, local decorative follower and shared day/night source. The inventory adapter now places each current, living new character near CampCenter after guarded root readiness; the existing SpawnLocation instance itself is untouched. This runtime behavior was deployed and run from 2026-11-05 (`odd/tasks/wildbound-first-playable.md:111-113`). Touch, co-op and real-device tests remain pending.
