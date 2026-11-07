# Silueta visual adapter verification

**Status: initial strict-TDD RED 0/19 → GREEN 19/19 was observed in fresh Studio Edit ModuleScripts. The motion/readiness follow-up observed RED (16 passed / 7 failed) → GREEN 23/23, plus 41/41 refreshed baseline cases. The runtime adapter/World hooks are deployed, the four animation IDs exist, and Studio Play visual checks ran (`silueta-animation-runtime.md:5-15`); touch, muted-audio, latency and cold-timing cases remain open. The native package warning awaits user acknowledgement.**

## Scope and deployment

Deploy `src/wildbound/WildboundSiluetaVisual.luau` as `ServerScriptService.WildboundSiluetaVisual` beside `WildboundWorld`; deploy the bounded World source update only after authorized target verification. The parent owns Studio deployment and testing. No Rojo, client adapter, download, publishing or monetization change is involved.

The optional template is `ServerStorage.WildboundAssets.SiluetaV3`. The importer reported model asset `123768633946912` Approved, nine MeshParts / ten BaseParts / eighteen Bones / nine Motor6Ds, one AnimationController, no Animator or Animation objects, eighty-four InitialPoses CFrameValues and one PackageLink. These are importer handoff observations, not this adapter's playback evidence. Benign InitialPoses and PackageLink are retained; executable descendants and Humanoids are rejected. The original template is never modified.

The verified template pivot is the feet origin, face -Z. Its clone is aligned to the existing Body bottom (Y0.5 at home), preserving Body as guardian PrimaryPart and leaving the existing movement pivot, GroundCue and Highlight intact. Every cloned BasePart is anchored, non-colliding, non-touching and non-queryable. Imported package repairs must not be overwritten by blindly accepting package auto-updates. The currently observed package local-modification warning requires parent/user handling, not implicit acceptance by this code.

## Optional animation contract

Each template attribute must hold an actual, separately verified positive asset URI:

| Attribute | Loop | Authored duration |
| --- | --- | --- |
| `IdleAnimationId` | Yes | 3s |
| `LocomotionAnimationId` | Yes | 2s |
| `TelegraphAnimationId` | No | 1.4s |
| `AttackAnimationId` | No | 1s; strike pose at 0.23s |

**All four actual animation IDs now exist** (`silueta-animation-assets.md`) and loaded through a server Animator in Play (`silueta-animation-runtime.md:5`). Do not copy the synthetic test IDs onto the real template. Static imported art remains the fallback if a track set fails to load. No manual Bone animation fallback is implemented. With four valid IDs, the server creates/reuses an AnimationController and Animator on its clone before loading tracks. `animationReady` requires all four `Length` values to match the authored durations within one 30 fps frame plus floating-point tolerance. A zero length is polled without yielding for up to five seconds. Wrong lengths, timeout, and load/play errors discard the attempted track set and keep static art revealable; the adapter does not retry. Server readiness does not prove client replication, visible deformation, or mobile performance. Actual asset playback remains a separate live acceptance check.

Reveal transforms every cloned BasePart's original transparency using `baseline + (1 - baseline) * revealAlpha`, where hidden alpha is 0.86 and revealed alpha is 0.25. Invisible rig parts remain invisible and partially transparent art retains its baseline. Only validated art hides Body/Head. Missing/invalid templates keep the original primitive reveal behavior. Destroy restores both proxy baselines and removes only the owned clone/tracks.

## Timing and authority

Presentation reads the injected/server clock. Attack starts at `telegraphDeadline - 0.23`; late updates seek to elapsed Attack time on the server, and an entirely elapsed attack is not replayed. The server seek is not evidence of identical client playback positions. Telegraph has already settled into its warning hold before this switch. Repeated states do not restart the same track; a genuinely new warning deadline restarts the warning. Idle/Locomotion loop; Telegraph/Attack do not.

The existing 0.2-second gameplay loop, damage deadline, range/LOS/current-character checks, cooldowns, night parameters and streaming guard are unchanged. World samples actual horizontal Body displacement across each fixed gameplay step and retains that result between steps; rotation or movement intent alone cannot start Locomotion. Presentation steps each Heartbeat after the existing long-stall cancellation, so stationary Retreat idles unless still in Attack recovery. Explicit validated warning completion can retain the remaining Attack recovery during Retreat, including when streaming safety prevents damage. Abandonment, lost targets, long stalls and teardown cancel presentation. No animation event or client signal can grant damage.

## Fresh-module runner

Deploy exact local adapter and test sources into new isolated ModuleScripts under `ServerStorage.WildboundTests`; preserve older suites. Clone both for every execution to avoid require-cache false positives:

```luau
local folder = game.ServerStorage.WildboundTests
local adapter = folder.SiluetaVisual_Contract:Clone()
local tests = folder.SiluetaVisualTest_Contract:Clone()
adapter.Parent, tests.Parent = folder, folder
local ok, result = pcall(function() return require(tests)(require(adapter)) end)
adapter:Destroy()
tests:Destroy()
if not ok then error(result) end
print(game:GetService("HttpService"):JSONEncode(result))
```

Twenty-three cases use real Roblox Instances and isolated ServerStorage fixture roots, with deterministic clock/track-loader doubles. They cover fallback, unsafe-template rejection, clone preservation, helper/pivot stability, physical isolation, nested baseline reveal, missing/bad IDs, partial load cleanup, server Animator hierarchy, pending/wrong/timed-out track lengths, stationary and moving Retreat, loop/restart rules, strike alignment/catch-up, cancellation/followthrough, deadline replacement and idempotent teardown. They do not exercise real uploaded tracks or validate gameplay damage. No external/fake Luau runtime is an accepted substitute.

## Evidence and remaining checks

- **RED observed by parent:** Studio Edit, fresh clones, 0/19; every failure was the intentional stub error, not a compilation failure.
- **GREEN observed by parent:** Studio Edit, fresh adapter/test clones, 19 passed / 0 failed. An initial source replacement old-string mismatch came from normalized trailing newline; exact source readback/replacement succeeded. This was a deployment-text mismatch, not a code/test failure.
- **Motion/readiness RED observed by parent:** Studio Edit, fresh clones, 16 passed / 7 failed against the previous adapter: four behavior failures and three cases requiring the new movement input. No compilation failure.
- **Motion/readiness GREEN observed by parent:** Studio Edit, fresh clones, 23 passed / 0 failed. These contracts use injected clock and track doubles, not real uploaded clips.
- **Refreshed baseline observed by parent:** fresh map 5/5, state 17/17 and world 19/19; 41 passed / 0 failed total. This does not run the new World presentation hook in Play.
- **Local static checks:** writer source readback and whitespace inspection passed; actual Studio executions above were performed by the parent, not the source writer.
- **Runtime deployment and Play:** later units deployed the adapter and ran it in Play (`silueta-animation-runtime.md:5-15`). The GREEN suites here cover contracts only and do not establish that on their own.
- **Pending live checks:** touch, muted audio, latency and cold-timing cases. Inspect both server and client; synthetic track contracts alone do not establish replication or deformation.
- **Unchanged blocked checks:** damaging strike/causal escape while streaming protection remains active, prior literal muted-client check, co-op/mobile/performance and isolated persistence. Do not convert these into passes.

Rollback removes this new adapter/test/guide and reverts only the bounded World hooks; keep the original imported template, package, inventory, clients, map and unrelated work. No commit was made because the parent delivery-chain decision remains pending; native review remains OFF.
