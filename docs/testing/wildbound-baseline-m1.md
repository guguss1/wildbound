# Wildbound M1 baseline: what really runs

Measured 2026-11-07 by one Studio operator (roadmap M1.1, M1.5, M1.6). Agent-driven runs in Studio only. No real person played, and no real phone was used; M1.7 still needs both.

- Target: Studio `81631061-9001-4c69-be21-f79a34aaa1d8`, PlaceId 122652861404212, GameId 10774749224, verified before any edit. Nothing was published, uploaded or saved, and no DataStore was touched.
- Guards held before and after every run: `StreamingEnabled=true`, `DamageEnabled=false`, `NightRewardsEnabled=false`, session-only copy.
- The one Studio edit is in section 1. Edit mode is back to normal: device simulation `default`, simulator toolbar hidden, test clones and test clients removed.

## 1. Source comparison (M1.1)

Method: `python -I -B tools/deploy_manifest.py` against `Script.Source` read in Studio, with the same normalization (CRLF to LF, trailing newlines stripped). SHA-256 was computed in Luau; the implementation matched the `abc` test vector first.

| Result | Count | Entries |
| --- | --- | --- |
| match | 14 | State, WorldRules, Server, World, WorldClient, WildboundClient, SiluetaHunt, SiluetaVisual, P0MapBuilder, ForestDress, ForestDress_Test, P0Map_Test, State_Test, and `WorldRules_Test` after the fix |
| differ | 1 (fixed) | `ServerStorage.WildboundWorldRules_Test` |
| missing | 3 | `ServerScriptService.RescueServer`, `ServerScriptService.RescueState`, `StarterPlayerScripts.RescueClient` |

- **Drift fixed.** The Studio test was 173 lines (hash `bb37bc8d...`) and lacked the four creature-profile cases that the repo has (205 lines). The repo side is newer and a strict superset, so this was stale deployment. I inserted those four cases in Studio; the hash now equals the repo (`b3c0ab52...`). The stale copy would have reported 19 cases, not 23.
- **Rescue scripts** are not deployed in this place. That fits the optional "earlier prototype" slice, so I did not install them.
- **Not in the manifest.** `ServerStorage.WildboundTests.SiluetaHuntTest_Contract` and `SiluetaScaleContract` are byte-identical to `tests/WildboundSiluetaHunt_Test.luau` and `tests/WildboundSiluetaVisual_Test.luau`. `NightProfilesContract`, `H1_WildboundWorldRules`, `H1_WildboundSiluetaVisual` and `SiluetaHunt_RED` also match the repo. The older `*_RED` copies and `ServerStorage.WildboundForestLayout` were not compared.

## 2. Contract suites and place settings

Every suite ran on fresh clones, and the temporary clones were destroyed.

| Suite | Passed | Failed |
| --- | --- | --- |
| State | 17 | 0 |
| World rules | 23 | 0 |
| Hunt | 9 | 0 |
| Visual | 26 | 0 |
| Map | 6 | 0 |
| Dress | 25 | 0 |
| **Total** | **106** | **0** |

The roadmap's 80 was 17 + 23 + 9 + 26 + 5, before the nest test and the dress suite.

| Setting | Observed |
| --- | --- |
| Streaming | on; `StreamingMinRadius` 64, `StreamingTargetRadius` 1024 (Roblox defaults); integrity `PauseOutsideLoadedArea` |
| Walk speed | `StarterPlayer.CharacterWalkSpeed` 16, and 16 on both live Humanoids |
| Health regeneration | default Health script is present. From 50, health read 51, 53, 55, 57, 59.1, 61.1, 63.1 and 65.1 at 2 s steps: about 1 HP/s, so regeneration is on |
| Humanoid | MaxHealth 100, JumpPower 50 (`UseJumpPower` false, jump height 7.2), RespawnTime 3 |

## 3. Natural cycle (M1.5)

Method: Server & Clients, no offset. The server clock started at `CycleStartedAt`, and Play ran for more than one full 1200 s cycle. Phase changes were read from the client HUD label with 50 ms polling, as `Workspace:GetServerTimeNow() - CycleStartedAt`.

| Boundary | Rules (`WildboundWorldRules.luau`) | Observed |
| --- | --- | --- |
| Day to Dusk | 600 | 600.29 |
| Dusk to Night | 720 | 720.40 |
| Night to Dawn | 1080 | not sampled in a burst; Dawn first read at 1105 with 95 s left, consistent with 1080 |
| Dawn to Day (wrap) | 1200 | 1200.66 |

The label runs 0.3 to 0.7 s late, which matches the roughly 1 Hz snapshots. Client `ClockTime` followed the rules curve: 17.95 at 600.3 against 18.0, 5.98 at 1200.7 against 6.0.

Captures are in `assets/exports/forest-kit/captures/`: `natural-{day,dusk,night-early,midnight}-reduced-{on,off}.jpg`, plus `natural-dusk-reduced-off-companion-occludes.jpg`. There is no Dawn capture.

| Reduced | Midnight lighting (client, fog zone) |
| --- | --- |
| On | fog 45 to 180, atmosphere density 0.35, haze 0.50 |
| Off | fog 45 to 135, atmosphere density 0.39, haze 0.95 |

**Night is legible with Reduced Off.** Avatar, path edge and the nearest lantern read in the midnight capture, as with Reduced On. Off is slightly hazier at range and the difference is subtle at this framing. One framing, one viewport (1094 x 558) and Studio rendering only.

## 4. Co-op and devices (M1.6)

Setup: Prueba, Servidor y clientes, 2 clients. Studio started three processes, each with its own MCP id, so each client was driven independently (`execute_luau`, `user_keyboard_input`, `user_mouse_input`, `character_navigation`).

| Role | Studio id | Identity |
| --- | --- | --- |
| Server | `29d9f2b9...` | JobId all zeros (Studio session) |
| Client A | `8b4cf6df...` | Player1, UserId -1 |
| Client B | `1aacca72...` | Player2, UserId -2 |

Resets used the real Esc, R, Enter menu. No guardian damage was involved.

| Case | Result | Evidence |
| --- | --- | --- |
| C1 pickup race | PASS, limited | Trial 1: A won `Creature:1`, B had no prompt. Trial 2, roles reversed on fresh `Creature:3`: B pressed 65 ms before A and won; A's hold was cancelled when the model replicated away, so A got no Triggered event and its bag stayed 1/3. Calls are serialized, so this is not true simultaneity, and the server `AlreadyClaimed` branch was not reached by normal input |
| C2 retired encounter | PASS, partial | B had no prompt after A won `Creature:4`, so nothing transferred. After A's reset the replacement was `Creature:5` (IDs run 1, 3, 4, 5, 7). A retry on the retired ID itself needs an authorized probe: BLOCKED |
| C3 extract | PASS | A: Lumipol registered, seals 0 to 1. B: Lumipol registered plus one banked egg, seals 0 to 1. Repeat extraction: "Your bag is empty", seals unchanged. Near camp the nearest prompt wins: B's first E fired the protection hint |
| C4 hatch and equip | PASS, core | B hatched via the inventory button (free, "Lumipol hatched and registered"), egg consumed, 2 registered, equipped `wb:6`, Pulse became Ready. A unchanged. Repeat hatch and cross-owner attempts: BLOCKED, need an authorized probe |
| C5 reset | PASS | A's 2 unprotected pending items lost, back to 0/3 at camp, registered Lumipol kept, B untouched. Banked eggs surviving was not shown (A had none) |
| C6 protect | PASS | A: 2 pending, 1 seal, Protect on #1, reset. #1 survived and became Unprotected, seals 1 to 0, #2 lost. Second reset with no charge: item lost, seals 0. B unchanged. Duplicate death-callback: BLOCKED |
| C7 shared guardian | PASS, limited | Both clients read identical `RevealedUntil` (992.845) and State at the same moment. B's pulse gave exactly press+4 s. A's flashlight about 2.5 s earlier plus B's pulse produced B's press+4, not a sum. A's and B's Attack track sat at 0.63 and 0.70 s, 65 ms apart, at the same guardian position |

C7 animation: all four real clip IDs were seen playing on a client (Idle `90427760879990`, Locomotion `109004575414309`, Telegraph `106571946482274`, Attack `139759980248576`). Tool calls are serialized, so "time-aligned" means about 65 ms.

### Guardian smoothness as a client sees it

Sampled at `RenderStepped` on a client (15 FPS session, three Studio processes, so not a display-rate measure).

| State | Position updates | Step | Interval |
| --- | --- | --- | --- |
| Patrol (25 s, n=120) | 4.8 per s | 0.60 studs, every sample | median 0.200 s, p95 0.267 s, max 0.267 s |
| Hunt and Retreat (20 s) | every 0.2 s while moving | 1.20 studs, every sample | gaps up to 3.6 s are state pauses |

The client applies discrete 5 Hz server steps with no interpolation. A step is about 7% (patrol) or 14% (hunt) of the 8.57-stud body height. At night speed 8 the rules imply 1.6 studs, which was not measured. Whether this looks choppy to a person is for M1.7. This confirms the stepping that roadmap B16 and M2.6 anticipated.

### Mobile matrix (M1 to M3)

Method: `StudioDeviceSimulatorService` inside each Play client. Set the device first, then the orientation; orientation on the default device errors. Profiles: iPhone 17 Pro (viewport 750 x 381, portrait 401 x 778) and Samsung Galaxy A06 (705 x 338, portrait 359 x 718). These are emulator results, not phones. Captures: `baseline-m1-*.jpg` in the same folder.

| Case | Result | Evidence |
| --- | --- | --- |
| M1 layout | FAIL (phone landscape), partial | iPhone landscape: HUD panels reach 57% of the width and hide the avatar at default framing. Galaxy A06 landscape: Flashlight and Pulse (y 146 to 190) sit on top of the status text and cut it. Portrait notice "Silueta revealed for 4 seconds..." is truncated (`TextFits` false). Flashlight and Pulse overlap Roblox's dynamic thumbstick zone in every profile (1,716 to 4,840 px²). Inventory Close is 70 x 36, under 44 |
| M1 inventory | PASS, limited | Landscape iPhone panel is 500 x 243 with a 146 px scroll area, about 1.5 rows; the wheel reaches the last item. Rotating with it open keeps it open and Close stays on screen. Portrait panel is 352 x 520 and usable. Dismissing with the Close tap: BLOCKED (see below) |
| M2 warning, inventory closed | PASS, limited | Phone landscape, Reduced On, standing, 6 telegraphs: "Attack incoming: move away!" readable 0.07 to 0.77 s after the telegraph attribute, leaving 0.61 to 1.30 s of 1.4 s. The 3D telegraph track starts at +0.00 s |
| M2 warning, inventory open | **FAIL** | World HUD frame `Visible=false`; 4 telegraphs in 30 s with no on-screen text (capture confirms). Only the 3D pose remains. Abilities are also gated: `request()` ignores F and Q while the inventory is open (client A's first F did nothing for that reason) |
| M3 counterplay feedback | PASS, limited | Key to feedback 48 ms (notice) and 132 ms (cooldown text), local server. Flashlight miss shows "No Silueta revealed. Move within 55 studs; face it for flashlight." and a 12 s countdown. Pulse shows 30 s. Flashlight works with no pet (client A); pulse works with the registered pet (client B) |

BLOCKED, with the reason:

- Phone taps and mis-taps: MCP mouse clicks do not activate any `GuiButton` while a phone profile is active (3 attempts, including by instance path). Clicks work on the desktop viewport. Keyboard and mouse wheel still work. Injected keyboard input also hides Roblox's touch GUI in the simulator.
- Muted audio, M2 and M3: no safe mute control, and no privileged volume API was called.
- Night camp-return route on a phone: not run. The T7 Play walk was daytime and desktop.
- Moving-while-telegraph, N2 network simulation, and measured phone frame rate: not run. Frame time here was about 15 FPS from three Studio processes and says nothing about phones.
- Retired-ID retry, consumed-egg repeat, cross-owner hatch and equip, and duplicate death callback: they need a separately authorized probe.

## 5. Findings, ranked (nothing fixed except section 1)

1. **Inventory hides the telegraph warning and blocks abilities.** M2 fails with it open; the 3D cue alone remains.
2. **Phone HUD layout.** Panels hide the avatar, controls overlap status text on the small phone, text truncates in portrait, and controls sit in the thumbstick zone. Feeds W3b.
3. **Guardian steps at 5 Hz without interpolation** (0.6 to 1.2 studs). Feeds M2.6.
4. **Equipped Lumipol companion renders as a flat, blown-out white disc** and covers about a third of the view when the camera is close. See `natural-dusk-reduced-off-companion-occludes.jpg`.
5. Notice text never expires; a "revealed" or "no Silueta" line was still showing minutes later.
6. Prompt priority near camp can fire the wrong prompt (extract versus protection hint).
7. Housekeeping: Rescue scripts absent from the place; the manifest does not map the `WildboundTests.*` copies or `WildboundForestLayout`; `SiluetaVisual` carries `WildboundImportVerified=false` and `WildboundMaterialRepairIncomplete=true`.

## 6. Still unverified

- **M1.7:** no human baseline. Real people and real phones are needed for confusion, fun, touch accuracy, thumb reach and frame rate.
- Real-network behavior: Server & Clients ran on one machine, with no latency, jitter or loss.
- A Dawn capture and a Night to Dawn burst reading.
- All BLOCKED items in section 4.
