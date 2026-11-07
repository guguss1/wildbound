# Silueta encounter and phase verification

**2026-11-05: 10 PASS, 3 BLOCKED, 0 FAIL across the 13 requested checks.** Fresh contract regression: **41 passed, 0 failed** (map 5, state 17, world 19). No production source fix was needed. Damage and damage-avoidance remain unverified because the required streaming guard correctly disables damage.

## Target and method

- User-confirmed private test place: `122652861404212`, GameId `10774749224`, Studio instance `dfda4f65-05a7-459a-b38f-a054490feece`. Reverified before testing. Final state: **Edit, Play stopped**.
- Existing P0 backup retained: `wildbound-p0-studio-20261105.rbxl`, 119,337 bytes, SHA-256 `03428E4F87CE390632CCE1B2AEB6184B429771361F40EC5083C07FCAE73F3EAB` (prior verified backup; not rewritten in this test).
- Keyboard F/Q, held-E prompts and an actual inventory mouse click exercised normal client controls. Server character positioning/anchoring was controlled setup, not natural walking. Live remote spam deliberately exercised the server boundary. Read-only client listeners captured authoritative snapshots and displayed cues.
- Phase boundaries used fresh Play sessions with **temporary server-source origin offsets** 590, 710, 1070 and 1190 seconds. These are accelerated boundary tests, **not a naturally elapsed 20-minute cycle**. A separate offset 730 session exercised all six night paths.
- Streaming stayed **true** throughout. No damage guard, permission, global production configuration, publication, DataStore, cloud save, paid asset or upload change occurred.

## Requested checks

| # | Check | Result | Observed evidence and limitation |
| --- | --- | --- | --- |
| 1 | Free flashlight hit, server facing/range/LOS | **PASS** | Without a pet, selected a ray-clear controlled setup with server facing dot approximately 1. Real keyboard F returned `Revealed`, distance 34.994 studs, reveal deadline `1793911992.056967` from server time `1793911988.057079` (approximately 4 seconds), cooldown deadline `1793912000.056967` (12 seconds). An earlier uncontrolled line missed; the clear-ray test, not that miss, proves the hit. |
| 2 | Registered/equipped Lumipol pulse hit | **PASS** | Actual held-E collection at clearing, held-E extraction at camp, scrolling inventory and clicking Equip. Server `Eligibility:Invoke(player, "LumipolPulse")` became true. Real Q later returned `Revealed` at 8.701 studs, server time `1793912223.332024`, expiry `1793912227.331838`, cooldown `1793912253.331838`. Before equip, Q was rejected with `NotEquipped` notice and pulse deadline remained zero. |
| 3 | Wall occlusion and greater-than-55 rejection | **PASS** | Owned temporary 80x30x3 occlusion wall between player and guardian: accepted use at 12.353 studs returned Miss, old reveal deadline unchanged. Wall removed. Separate live remote use returned Miss at 75.377 studs, reveal deadline zero. Valid misses consume the normal cooldown by design; they do not reveal. |
| 4 | Spam and respawn cooldown retention | **PASS** | Burst of 100 live remote requests admitted at most one valid use; subsequent accepted response was Cooldown and the deadline stayed `1793912051.672259`, without additive extension. For pulse, real Q set `1793912195.900566`; controlled Humanoid death and actual respawn retained registered eligibility and the **same** deadline. Q at `1793912176.899919` was rejected as cooling down. Initial flashlight-only respawn attempt completed after its shorter cooldown, so that attempt alone is not retention evidence. |
| 5 | Actual stationary telegraphed damaging attack | **BLOCKED** | Alert -> Hunt -> Telegraph -> Retreat observed. During Telegraph from `1793912203.282901` through `1793912204.615842`, guardian stayed exactly at `(-1.120165, 3.7, -99.837807)`, distance 5, deadline `1793912204.632559`. Health stayed 100 through resolution. Telegraph/stationarity PASS; **damaging strike cannot pass with StreamingEnabled=true and DamageEnabled=false**. No bypass attempted. |
| 6 | Escape avoids strike | **BLOCKED** | During actual Telegraph at `1793912238.631222`, deadline `1793912239.148551`, controlled repositioning moved the player 25 studs away. Two seconds later state was Retreat, distance 21.427, health 100. Escape/state handling observed, but absence of damage cannot be attributed to escape while damage is globally guarded off. Physical movement timing and damaging counterfactual remain pending. |
| 7 | Bounded chase, safe camp and shelter | **PASS** | Controlled moving target held approximately 22 studs ahead: Alert/Hunt ended in Retreat after approximately 10 seconds; sampled guardian leash reached 48 studs, remained in territory, then decreased toward home. At camp `(-140,140)` and shelter `(105,125)`, no threat/damage, health 100 and guardian Retreat/Patrol. This is a bounded runtime sample plus passing edge contracts, not exhaustive traversal of every 80-stud boundary point. |
| 8 | Streaming safety remains enabled | **PASS** | Every observed snapshot reported `damageEnabled=false`; runtime attribute false with Workspace StreamingEnabled true. Close-range stationary Telegraph resolved with health unchanged. Final Edit still has StreamingEnabled true. No loaded-guardian receipt protocol exists or was added. |
| 9 | Four phases and transitions | **PASS** | Actual authoritative snapshots: Day 599.946585 -> Dusk 600.947506; Dusk 719.787968 -> Night 720.803625; Night 1079.732097 -> Dawn 1080.749594; Dawn 1199.750318 -> Day 0.766728 after wrap. Fresh isolated offsets only; no natural 20-minute claim and no co-op shared-clock claim. |
| 10 | Dusk warning | **PASS** | Actual client HUD displayed `Dusk: night is approaching.` after Day/Dusk crossing. Visually inspected MCP capture `SiluetaDuskWarning`, with Reduced On and readable route/camp lighting. |
| 11 | Fog-only night boost | **PASS** | Night fog sample: Atmosphere density 0.349999, haze 0.499997, FogEnd 180.701. After shelter exit from fog: density 0.202570, haze 0.008567 and FogEnd 98289.633 trending toward original values, no threat. Day Hunt moved 1.2 studs per configured step; Night Hunt 1.6 (actual sampled positions), with targeting limited to fog territory. Passing rules contracts cover night/non-fog parameter distinction. No resource/reward implementation is inferred. |
| 12 | Paths remain legible at night | **PASS** | Actual speed-1 character navigation traversed all six connected segments: camp -> clearing -> ruin -> nest -> marsh -> shelter -> camp. All navigation calls succeeded, no teleport between waypoints; final root `(-139.286,3.696,139.537)`, health 100. Six inspected captures show tan path versus dark ground and landmark silhouettes in Night/Reduced On; fog sections also traversed. Used a temporary ordinary-height third-person follow camera aimed down the route, not a natural unaided wayfinding study. Mobile and unreduced-effects usability remain pending. |
| 13 | Muted-audio and reduced-effects cues | **BLOCKED** | Reduced On observed throughout. Actual warning text `Attack incoming: move away!` captured and visually inspected in `SiluetaTelegraphReduced`; client text logs recorded warning before deadline. Thus reduced-effects/audio-independent textual cue PASS. No playing Sound instances were found. **Literal mute verification is blocked**: supported probe to read/write UserGameSettings MasterVolume was denied (`lacking capability RobloxScript`); no alternate privileged execution or permission change attempted. A genuine muted-client test remains pending. |

## Visual evidence

MCP `screen_capture` images were returned inline and inspected; no local image paths were returned or fabricated. These capture identifiers locate the evidence in the tool transcript:

- `SiluetaEquipScrollEnd`: actual registered Lumipol Equip button after scrolling.
- `SiluetaDuskWarning`: dusk warning and Reduced On.
- `SiluetaNightFogReduced`, `SiluetaNightSafeShelter`: fog versus safe-zone night presentation.
- `SiluetaTelegraphReduced`: actual attack warning visible with Reduced On.
- `SiluetaPath1Night` through `SiluetaPath6Night`: all six Night route landmarks, real speed-1 navigation. The screenshots are endpoint views; the navigation calls cover the connecting movement. The temporary follow-camera observer was disconnected and CameraType restored to Custom before stopping Play.

## Restoration and regression

- Original exact Studio World source equals local `src/wildbound/WildboundWorld.server.luau`: SHA-256 **`51E80EB9553DFBB96910DCF0C0FE98F8EC917AE3946DC0EFD46E4A6ED02EDADD`**. Original source stored before temporary edits; final returned source compared byte-for-byte equal after restoring both the boundary session and later night-path session. No debug clock, remotes, test offset or configuration remains.
- Owned occlusion wall removed. Play-only probes/camera listeners discarded with Play. Fresh test clones destroyed. Final map has **219 descendants**, no world runtime in Edit; original map preserved.
- Standalone fresh-clone regressions actually executed in Edit: map **5/0**, state **17/0**, world **19/0**. Console query returned empty output. These are current regression results, not retroactive RED evidence. No code defect was fixed and no TDD implementation cycle claimed.
- No source diff, commit, native review or publication. Native review remains OFF; existing delivery decision remains with parent/user.

## Next verification

Keep damaging attack and causal escape BLOCKED until a separately authorized fair-visibility solution can be tested without weakening streaming safety. Repeat cues on a genuinely muted client through supported user controls. Two-client, mobile/touch, network-lag, unreduced-effects and unaided-wayfinding checks remain outside this single-client desktop evidence.
