# Wildbound roadmap: from working tech slice to a publishable game

Audit date: 2026-11-07. Source of the audit: repository files, the brief and session context supplied by the user, and Roblox documentation read on that date. No Studio, Blender or Play session was run for this audit. Only the three local Python suites were rerun (15, 31 and 6 tests, all OK).

**Verdict:** the technical foundation is real, but the game is not fun yet. Eight of the 16 P0 criteria are verified, all session-only and all from agent-driven desktop runs. The current loop has no stakes, nothing to earn and no skill in capture. There is no recorded test with a human player.

## Quick path

| Order | Do this | Why now | Done when |
| --- | --- | --- | --- |
| 1 | Protect the work: commit it in the slices in section 6 | All game code is untracked; `git ls-files src tests` returns nothing | Slices committed, no `.rbxl` staged |
| 2 | Answer decisions D1 to D6 in section 5 | They unblock the fair-damage and capture designs | Answers recorded in the task document |
| 3 | Rebuild the baseline in Studio (M1): reconfirm the target, rerun 80 contracts, move the nest, import the forest | Everything later is measured against this | M1 exit test passes |
| 4 | Make Silueta readable (M2) | Damage is unfair until players can tell who is hunted | Nine scenes and five-pair test pass |
| 5 | Add skill capture, then fair damage (M3, M4) | Capture creates the exposure that makes Silueta dangerous | Testers report close calls, none report unfair deaths |
| 6 | Add materials, upgrades and working protections (M5) | This creates the reason to go back out | **Fun gate F1** |
| 7 | Only after F1: persistence, co-op, polish, beta, publish (M6 to M10) | Polish cannot rescue an unproven loop | Publishing needs explicit user approval |
| 8 | Only after F2: new biomes, guardians and species (M11) | The brief puts expansion after a satisfying first loop | Gate F2 passed |

**Status words:** Verified = an executed test or observed run. Built but unverified = code exists, never run for this purpose. Partial = some of it is proven or some of it exists. Missing = nothing exists.

## 1. Where the game stands

### 1.1 The 16 P0 success criteria

Tally: 8 Verified, 6 Partial, 1 Built but unverified, 1 Missing.

| # | Criterion | Status | Evidence (date) | What is still not true |
| --- | --- | --- | --- | --- |
| 1 | Open in Studio | Verified | `odd/tasks/wildbound-first-playable.md:105`, `:222` (11-05, 11-06) | Target must be reconfirmed each session; Studio MCP is not connected in this one |
| 2 | Run Play | Verified | `wildbound-first-playable.md:113`, `:211`, `:219` (11-05, 11-06) | Latest Play predates any new work |
| 3 | Walk the Fog Forest | Partial | `docs/testing/silueta-encounter-phase-report.md:28` (11-05): six segments at night by scripted navigation | No human wayfinding; temporary follow camera; greybox, kit not imported |
| 4 | Find a creature | Verified | `wildbound-first-playable.md:113` (11-05) | Fixed marker, 79 studs from camp, beside a beacon (`tools/build-wildbound-p0-map.luau:99`, `:112`). No searching involved |
| 5 | Capture Lumipol | Partial | Pickup works (`:113`). Capture is a 0.25 s hold (`src/wildbound/WildboundServer.server.luau:91`, `:173`) | Brief requires skill, never a single press. No capture mechanic exists |
| 6 | Find an egg | Verified | `wildbound-first-playable.md:113` (11-05) | Nest is outside Silueta's reach until moved (`odd/tasks/fog-forest-visual-kit.md:9`) |
| 7 | Encounter Silueta | Partial | State sequence and animations observed (`docs/testing/silueta-animation-runtime.md:9`, about 11-06); report checks 5 to 7 | Controlled positioning; no natural encounter measured; no consequence; state not legible |
| 8 | See day and night | Partial | All four phases at temporary offsets (report check 9, 11-05) | Natural 20-minute cycle never observed; first Night is 720 s after server start; only Reduced On captured |
| 9 | Extract rewards | Verified | Real held-E extraction, seal awarded (`wildbound-first-playable.md:113`, 11-05) | Session-only, solo, and rewards are only the same creature |
| 10 | Hatch | Verified | `wildbound-first-playable.md:113` (11-05) | Instant; no reveal moment |
| 11 | Equip Lumipol | Verified | `wildbound-first-playable.md:113`; report check 2 (11-05) | Companion is a local green ball that only its owner sees (`src/wildbound/WildboundWorld.client.luau:95-102`) |
| 12 | Use its ability | Verified | Real Q returned Revealed at 8.7 studs (report check 2, 11-05) | No visual effect on the pet or pulse; reveal changes no outcome |
| 13 | Die and see correct losses | Partial | Scripted Humanoid defeat, with and without seal (`wildbound-first-playable.md:118`, 11-05); contract "death preserves one sealed item" (`tests/WildboundState_Test.luau:201`) | Silueta cannot cause it (damage off). Resources and currency do not exist, so that half of the rule is untestable |
| 14 | Leave and return keeping companions | Missing | `WildboundServer.server.luau:263` and `src/wildbound/WildboundState.luau:62-67` discard the profile; no DataStore calls in `src/wildbound` (searched 11-07) | No persistence at all |
| 15 | Play with mobile controls | Built but unverified | Touch buttons (`WildboundWorld.client.luau:43-44`), prompts; matrix pending (`docs/testing/wildbound-next-verification.md:32-36`) | No Wildbound phone or emulator run recorded |
| 16 | Play with another person | Partial | Two local clients saw shared deadlines and poses (`silueta-animation-runtime.md:13`), and a retarget (`docs/mechanics/wildbound-creature-night-profiles.md:21`) | C1 to C7 co-op loop not run; no two humans; no real network |

### 1.2 Brief sections

| Brief section | Status | Evidence | Gap |
| --- | --- | --- | --- |
| Original IP, stylized low-poly direction | Partial | Original Blender sources (`docs/assets/silueta-rig.md`, `assets/blender/forest-kit/`) | Concept images are image-generated references; pack provenance unverified (`docs/wildbound-readiness.md:16`) |
| Loop: camp preparation, progression, new expedition | Missing | No preparation step or progression code in `src/wildbound` | Second trip gives only the same creature |
| Loop: expedition, extraction | Partial | Extraction verified (`:113`) | No expedition state, no extraction state |
| Loop: stay-or-return decision | Missing | Bag of 3 is the only pressure (`WildboundState.luau:4`) | No value difference between staying and leaving |
| Biomes (7 planned) | Partial | One Fog Forest sector only, as the brief asks to start | Six biomes rightly not started |
| 400x400 Fog Forest sector | Partial | Greybox tested (map 5/5). Kit and plan exist: 207 instances, 74,996 triangles (`assets/maps/forest-layout/forest-layout-v1.json`) | Kit not imported; scale, axes and Neon unverified (`fog-forest-visual-kit.md:53`); no boundary walls (`docs/maps/wildbound-p0.md:23`) |
| Hand-built points of interest | Partial | Six route nodes (`build-wildbound-p0-map.luau:15-22`) | Primitive stand-ins |
| Seeded procedural spawns, weather, events | Missing | Fixed markers; decoration seed only (`build-wildbound-p0-map.luau:131`) | No spawn system, weather or events |
| Day/night cycle, never fully black | Partial | Check 9 to 12 pass (11-05) | Natural run and unreduced effects unverified |
| Night raises danger | Partial | Speed 6 to 8, detect 28 to 38 in fog (`src/wildbound/WildboundWorldRules.luau:77-78`), observed (check 11) | Effect is small; see B2 |
| Night raises reward | Missing | `nightRewardsEnabled=false` (`src/wildbound/WildboundWorld.server.luau:34`, `:195`) | No reward exists |
| Spawn tables with normalized weights | Missing | No RNG in Wildbound source | Single deterministic species |
| Modular creature data | Partial | One guardian profile (`WildboundWorldRules.luau:74-80`, 23 world contracts, 11-06) | Lumipol is hardcoded (`WildboundState.luau:102`); no species data |
| Roles (six), rare not simply better | Missing | Only the revealer exists in practice | Pack catalog is a proposal |
| One active plus two reserves | Missing | One equipped slot (`WildboundState.luau:145`) | Pack allows deferring reserves in P0 (`docs/wildbound-readiness.md:70`) |
| Eggs carried, hatched at camp | Verified | `:113`; 17 state contracts | Session-only; hatch has no ceremony |
| Direct skill-based capture | Missing | Hold 0.25 s (`WildboundServer.server.luau:91`) | Core promise absent |
| Confirmed risk rule: loot lost | Partial | State contracts; scripted defeat (`:118`) | No real cause of death in play |
| Risk rule: resources and currency | Missing | Neither exists | Blocks half the rule |
| Risk rule: registered companions kept | Verified | Contract and scripted defeat (`:118`) | Session scope only |
| Seal protection | Partial | Works in contracts and test (`:118`) | Design flaw, B8 |
| Idempotent extraction and saves | Partial | Session contracts cover repeats (`tests/WildboundState_Test.luau:109`, `:226`) | No durable operation IDs |
| La Silueta | Partial | Rig, four clips, FSM, reveal, retarget verified (`silueta-animation-runtime.md`, `wildbound-first-playable.md:219-221`) | Damage off; not legible; movement smoothness unmeasured |
| Free flashlight counterplay | Partial | Check 1 to 4 pass (11-05) | No beam or sound (no Beam, SpotLight or Sound in `src/wildbound`, searched 11-07); payoff unclear |
| El Vigia, Yeti | Missing | Correctly out of P0 | Keep behind gate |
| Tools, consumables, skill tree, bond, totem, backpack upgrades, extraction tools | Missing | None | |
| No AFK progress | Partial | Holds only because no progress exists | Must stay true when added |
| Replayability systems | Missing | None | Correctly later |
| Camp UI | Partial | Collection, hatch and equip as an inventory list (`src/wildbound/WildboundClient.client.luau:113-136`) | Tools, crafting, skills and upgrades missing; not a camp experience |
| Start screen, quick bar, team UI | Missing | Two fixed buttons only | |
| Inventory | Partial | Observed working on desktop (`:113`) | Touch unverified |
| Cooldowns, day/night, extraction and protection state | Partial | Cooldowns and phase as text (`WildboundWorld.client.luau:140`, `:155-156`); bag and seal only inside inventory | Hidden when inventory is open; not on HUD |
| Graphics, audio, accessibility settings | Partial | One Reduced toggle, default On, not saved (`WildboundWorld.client.luau:45`) | No settings screen; muted check BLOCKED (report check 13) |
| Sound identity | Missing | No Sound instances in `src/wildbound` (searched 11-07) | Horror with no audio |
| Art: Silueta | Partial | Imported, animated; head accents and eye emission not recovered (`docs/assets/silueta-studio-import.md:29`) | Design not declared final |
| Art: Lumipol | Partial | Blender blockout only, no rig or import (`docs/assets/wildbound-creature-visual-studies-v1.md:19`) | In-game creature is primitive parts (`WildboundServer.server.luau:147-164`) |
| Art: forest kit | Built but unverified | 15 kit tests OK (rerun 11-07); FBX exported | Not imported; render approval pending (`fog-forest-visual-kit.md:55`) |
| Modular services | Partial | Pure modules plus two large adapters | No shared service layer |
| Server authority, validated remotes, duplication and race protection | Partial | Source and spam check (report check 4); state contracts | Inventory remote abuse and real two-client race (C1 to C4) pending |
| Official persistence, versions, recovery | Missing | Design notes only (`wildbound-first-playable.md:194`, `wildbound-next-verification.md:53-67`) | Nothing built |
| Monetization: none now | Verified | No MarketplaceService or PolicyService in `src/wildbound` (searched 11-07) | Correct |
| Testing | Partial | 80 contracts, last run 11-06 (`:221`) | No human, phone, or real-network runs |
| Optimization | Missing | No device measurement anywhere | |

### 1.3 Stale documents reconciled

Later evidence wins. These banners should be corrected (see section 4, unit 6).

| Document | Says | Current truth |
| --- | --- | --- |
| `docs/testing/wildbound-p0.md:3`, `docs/testing/wildbound-world.md:3`, `docs/mechanics/wildbound-state.md:5`, `docs/mechanics/wildbound-world.md:3`, `docs/ui/wildbound-p0.md:7`, `docs/ui/wildbound-world.md:9` | Not deployed, not run | Deployed and run from 11-05 (`wildbound-first-playable.md:111-113`) |
| `docs/testing/silueta-visual-adapter.md:3`, `:24` | Not deployed, IDs absent | IDs exist, deployed (`docs/testing/silueta-animation-assets.md:9-12`, `silueta-animation-runtime.md:7`) |
| `docs/assets/silueta-rig.md:3` | Import blocked | Imported (`silueta-studio-import.md:9`) |
| `docs/wildbound-readiness.md:1-3`, `:89`, `:94` | Stops before gameplay; target `newPlace1` | Superseded (`wildbound-first-playable.md:4`, `:105`) |
| `docs/testing/wildbound-next-verification.md:8` | Manifest absent | Present (`docs/assets/silueta-animation-upload-manifest.json`) |
| `docs/mechanics/wildbound-world.md:66` and others | 19 world cases, 41 total | 23 world, 80 total (`wildbound-first-playable.md:219-221`); case counts in test files agree |

## 2. Blocking problems, ranked

### Is the current loop fun?

**No, and more polish would not change that.** This is judged from source and test records, not from a human session, because none is recorded.

A first session today: walk five seconds, hold E, walk five seconds back, hold E, hatch and equip within minutes. After that, more Lumipols do nothing. The creature sits outside the danger area and returns every 20 seconds. Silueta can be walked away from, and cannot hurt you. Night arrives 12 minutes into a server, longer than the whole content takes, and pays nothing.

What is promising: Silueta's animated model, phase lighting, reliable server rules, and a good skeleton for the extract-or-lose idea. None of that has been tried on players.

### Ranked blockers

| Rank | Problem | Why it stops the game | Evidence | Fixed in |
| --- | --- | --- | --- | --- |
| B1 | Nothing to earn | No materials, currency, tools, upgrades or skills. Duplicates are useless. No reason for a second trip | `WildboundState.luau:113-119`; section 1.2 | M5 |
| B2 | Dying has no real cause | Damage is off under streaming, **and** Silueta would still rarely kill anyone if it were on | `WildboundWorld.server.luau:32`; calculation below | M3, M4 |
| B3 | Capture is a button press | Violates the brief and removes the moment the game is named for | `WildboundServer.server.luau:91`, `:173` | M3 |
| B4 | Objectives avoid the danger | Lumipol is 186 studs from Silueta's home, outside the fog. Old nest is 118.85 studs against an 80 leash. Only the ruin overlaps. Free farming: 5 s walk, 20 s respawn, no risk | `build-wildbound-p0-map.luau:99`, `:101`; `WildboundWorldRules.luau:51`, `:57`; `WildboundServer.server.luau:184` | M1 (nest), M3 (creature) |
| B5 | Players cannot read Silueta | See legibility table below. Damage would feel random even if it were fair | `WildboundWorld.server.luau:193-194`, `:283-285`, `:369` | M2 |
| B6 | Nothing is saved | Leaving erases everything. Blocks publishing and retention | Criterion 14 | M6 |
| B7 | Time scale does not fit | Full route is 798 studs, about 50 s at 16 studs/s. Nest is about 19 s from camp. A fresh server stays in Day for 600 s and reaches Night at 720 s. Night is usually never seen | `forest-layout-v1.json` lanterns; `WildboundWorldRules.luau:31-36` | M5, D5 |
| B8 | The seal is pointless | Protect only works within 12 studs of camp, on an item already in the bag. At camp you would simply extract it. Only one seal per server session | `WildboundServer.server.luau:104-110`; `WildboundState.luau:121-124` | M5 |
| B9 | No human, phone or real-network test | All verified criteria are agent-driven desktop runs in one local server | Section 1.1 | M1, then every milestone |
| B10 | Work could be lost and Studio can drift | Game source is untracked. Deployment is manual; no Rojo (no `default.project.json`). Local source may differ from Studio | `git ls-files`; `wildbound-first-playable.md:11` | M0, M1 |
| B11 | No sound or effects | No Sound, Beam, SpotLight or ParticleEmitter in `src/wildbound`. The flashlight has no beam | Search on 11-07 | M4 (minimum), M8 |
| B12 | It still looks like a greybox | Forest not imported, Lumipol is a ball and primitives, others cannot see your pet | Section 1.2 | M1, M3, M7 |
| B13 | Co-op competes for one creature | One creature and one egg per server; the loser waits 20 s. Co-op has no shared goal | `WildboundServer.server.luau:189-190`; `docs/wildbound-readiness.md:74` | D4, M7 |
| B14 | No first-time experience, and the HUD may crowd phones | No start screen or tutorial. Calculated, not measured: stacked panels reach y=192, half of a 750x381 landscape screen, up to 430 px wide | `WildboundClient.client.luau:49-53`, `WildboundWorld.client.luau:21-23` | M1 (measure), M8 |
| B15 | "Almost invisible" may be undone | Outline and pale ground disc are always on, so the flashlight may add little. Reveal does not change any outcome | `WildboundWorld.server.luau:51-60`, `:282-285` | M2 |
| B16 | Guardian movement may look choppy | Server moves an anchored model every 0.2 s. Clients may see stepping; never measured. No pathfinding, so colliding props would break steering | `WildboundWorld.server.luau:172-173`, `:354` | M1, M2 |
| B17 | Durable IDs would collide | `wb:N` restarts each server | `WildboundState.luau:41-44` | M6 |
| B18 | Known test failures remain | Direct world script deletion left objects behind. Cold Telegraph sample differed by about 0.41 s between server and client | `silueta-animation-runtime.md:15`, `:19` | M4, M9 |
| B19 | Map has no edge | Players can leave and fall; falling would count as defeat | `docs/maps/wildbound-p0.md:23` | M1 |

### Why Silueta would not kill anyone even with damage on

Calculated from source constants. Not observed, because damage is off.

| Fact | Value | Source | Consequence |
| --- | --- | --- | --- |
| Walk speed compared with Silueta | 16 against 6 (8 at fog night) | `docs/mechanics/wildbound-world.md:31`; `WildboundWorldRules.luau:77-78` | Slow by design. Correct, so the fix is not speed |
| Distance walked during wind-up | 22.4 studs in 1.4 s | `WildboundWorldRules.luau:7` | Far beyond the range below |
| Attack range | 7 studs | `WildboundWorldRules.luau:9` | Any moving player escapes in under 0.5 s |
| Damage per strike | 20 | `WildboundWorldRules.luau:14` | Five strikes needed; default Health regeneration also applies unless changed (not verified in this place) |
| After every strike | Silueta returns home, at least 3 s | `WildboundWorld.server.luau:152-155`, `:219-220` | About 8 s per strike at 20 studs from home |
| Time to die | About 40 s standing still | Derived | Only an idle player can die |

Most stakes must therefore come from forcing players to stop and choose, not from a faster monster.

| Lever (all keep Silueta slow) | How it creates danger | Test as |
| --- | --- | --- |
| Capture requires holding still in a ring | Exposure the player chooses | M3.2 |
| Objectives inside territory, with cover | Nest at about (35,-99): 37.7 studs from home, detectable from 18% of patrol by day, 46% by night (`fog-forest-visual-kit.md:15`) | M1.2 |
| Carrying an egg slows the player, still above 8 studs/s | Getting home becomes the risk | M3.5 |
| Ambush: quiet relocation near objectives on a server timer, with no camera or gaze input | Surprise without becoming El Vigia | M4.7 |
| Fewer strikes to defeat, and no regeneration in fog | A hit matters | M4.6 |
| Flashlight has a cost, such as drawing search toward the user | Counterplay becomes a decision. Stays free | M2.5 |

### The Silueta legibility review (session finding, confirmed in source)

| Finding | Source |
| --- | --- |
| Searching and seen are both mode Hunt | `WildboundWorld.server.luau:230-262` |
| Snapshot has no target identity | `:193-194` |
| `telegraphEndsAt` and state are global, so a non-target sees "Attack incoming" | `:194`; `WildboundWorld.client.luau:142-143` |
| Threat is distance-only, even during Retreat | `:193` |
| Ground disc stays pale during Hunt | `:283-285` |
| Snapshots are 1 Hz against a 1.5 s search and a 1.4 s telegraph, and no push on state change | `:369`; `src/wildbound/WildboundSiluetaHunt.luau:23`; `WildboundWorldRules.luau:7` |
| HUD hides when inventory opens | `WildboundWorld.client.luau:128-130` |
| Other players' bodies can block the sight ray | `WildboundWorld.server.luau:120` |
| A visible ally is ignored during search | `:234` |

The proposed fix is milestone M2.

### Damage under streaming: the top design problem

**The problem has three layers, and Roblox only helps with the first.**

| Layer | Can the server know? | Documented help |
| --- | --- | --- |
| The Silueta instance reached the client | Partly | Streaming modes and radii (below). No dedicated API tells a server a client received an instance |
| Mesh and animation assets finished loading | No, client report only | Client-side preloading (exact behavior for animations not checked) |
| The player saw and understood the warning | Never | None. Design and human testing only |

**What Roblox documents, read 2026-11-07** ([streaming](https://create.roblox.com/docs/workspace/streaming), [techniques](https://create.roblox.com/docs/workspace/streaming/techniques), [Player](https://create.roblox.com/docs/reference/engine/classes/Player), [Workspace](https://create.roblox.com/docs/reference/engine/classes/Workspace), [testing modes](https://create.roblox.com/docs/studio/testing-modes)):

- Persistent models arrive as a unit after join and never stream out; overuse can hurt performance. PersistentPerPlayer applies this to chosen players, Atomic to others.
- Atomic models stream in all together, but atomicity covers initial replication.
- Inside the minimum radius (default 64) instances load at top priority and do not stream out. The target radius default is 1024.
- `Workspace.PersistentLoaded` takes a player parameter. Clients should wait for it before reading persistent content.
- A remote signal can arrive before the instance it refers to.
- `RequestStreamAroundAsync` is a server call that yields. A successful return means the minimum radius should be present. Timeout and failure behavior are not documented.
- `PauseOutsideLoadedArea`, `Player.GameplayPaused` and `GetNetworkPing` exist. Whether the server can rely on the last two is not stated.
- Studio's Network Simulator adds latency, jitter and loss. Server & Clients supports up to eight clients. The Device Simulator covers phones.

**Candidates**

| ID | Candidate | Solves | Tradeoff or risk | Verified? |
| --- | --- | --- | --- | --- |
| A | Make the Silueta model Persistent (or PersistentPerPlayer on fog entry) | Instance presence, and arrives as a unit | Memory cost is small for one model. Does not cover assets or attention | Modes documented. Runtime-created model under the map Model untested |
| B | Server dwell gate: strike only if the target stayed within the minimum radius of Silueta for N seconds, with a live warning issued | No client trust; exploit-proof | Radius is a priority rule, not an arrival time. Place setting not read | Radius documented. Timing must be measured |
| C | Target-only warning remote with attack ID, plus client acknowledgement. Missing acknowledgement cancels the strike, but only K times per life | Latency and missing cue; independent of the model | Exploiters gain at most K free cancels. Acknowledgement proves receipt, never sight | Design only |
| D | Staged consequence: first strike marks or drops an item, later strike defeats | Lowers the cost of any false positive; also fixes lethality | Changes the feel; design approval needed | Design only |
| E | Preload meshes and clips at camp before leaving | Asset layer; likely helps the cold Telegraph mismatch | Client-reported only; longer first load | Not checked; test |
| F | `StreamingEnabled=false` for the single-sector release | Removes the instance layer entirely | Reverses the standing guard; cues still need C; memory untested on phones; later biomes may need separate places | Setting exists; phone cost unknown. **User decision** |
| G | `RequestStreamAroundAsync` on Alert | Helps arrival | Yields; undocumented failure; forum reports of hangs (unverified) | Use only as an aid, never a gate |
| H | Pause rule: integrity mode pause cancels the strike | Handles clients outside loaded areas | Server readability unknown; pause interrupts mobile players | Test first |
| X | Client decides or reports hits | Nothing safe | Exploitable. **Rejected** | |

**Recommendation:** A + B + C + D + E, tested in that order, all behind a `damageMode` server flag defaulting to off. F is the measured fallback, used only if the user decides so. Every failed gate cancels the strike and increments a server counter, so false cancels can be measured.

**Do not enable damage until** the M4 exit test passes. This restates the existing rule at `wildbound-next-verification.md:42` and `:51`.

**Not verifiable from documentation:** whether Persistent works as described for a runtime-created model here, whether `PersistentLoaded` fires on the server, the real delay inside the minimum radius, and phone behavior under memory pressure. All are M4.2 or M4.8 measurements.

## 3. Milestones

**Tiers:** Opus high for design-heavy and sensitive work, Sonnet xhigh for bounded implementation, Haiku xhigh for reading. These are the user's requested tiers for this roadmap; `docs/agent-routing.md` lists a different model set, so confirm which applies per session.

**Rules for every milestone:** reconfirm the Studio target before edits. One writer per script set or live scene. Strict TDD with observed RED and GREEN on fresh clones. Damage stays off until M4 exits. Numbers below are hypotheses to test.

### M0: Safe ground
Goal: nothing can be lost and every status is honest.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M0.1 | Commit slices from section 6 | User go-ahead | Sonnet |
| M0.2 | Correct stale banners (section 1.3) | None | Haiku |
| M0.3 | Deployment manifest tool: maps source to Explorer path with SHA-256 | None | Sonnet |
| M0.4 | Map and layout contract test | None | Sonnet |

**Exit test:** `git status --short` shows only agreed exclusions. `python -I -B -m unittest discover -s tools -p "test_*.py"` passes. A search for "not deployed" finds no stale banner.

### M1: True baseline
Goal: know what really runs, and put the real forest in the game.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M1.1 | Reconfirm target; compare Studio source hashes with M0.3; rerun all 80 contracts; backup | Studio | Sonnet |
| M1.2 | Move nest to about (35,-99): update `tests/WildboundP0Map_Test.luau:57` first, observe RED, then `tools/build-wildbound-p0-map.luau:19`, `:101`, `:119` | Studio | Sonnet |
| M1.3 | After render approval and upload consent: upload and import kit, check scale, axes, Neon | Studio | Sonnet |
| M1.4 | Dress map from layout plan; decide trunk collision; add map edge treatment | Studio | Sonnet |
| M1.5 | Lighting pass, day and night captures, desktop and phone; let one natural 20-minute cycle run | Studio | Sonnet |
| M1.6 | Run C1 to C7 and M1 to M3 from `wildbound-next-verification.md` with native Server & Clients and Device Simulator; measure guardian smoothness | Studio | Sonnet |
| M1.7 | Baseline: three people play 15 minutes, no coaching; record confusion | Studio, humans | Opus (analysis) |

**Exit test:** 80 of 80 on fresh clones, hashes match, nest contract green. An avatar, path edge and nearest lantern are readable in a real night capture on a phone-sized view. C1 to C7 each record PASS, FAIL or BLOCKED. The baseline notes exist.

### M2: Silueta readable
Goal: each player can tell whether they are the one being hunted, muted, on a phone.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M2.1 | Pure awareness rule per player: seen, searching, ally, none; `searchEndsAt`; asymmetric debounce; contracts | Studio | Opus |
| M2.2 | Server: `guardian.awareness` per player; push snapshot on change; threat excludes Retreat; attack warning for target only; other bodies do not block sight | Studio | Sonnet |
| M2.3 | HUD chip outside the inventory-hidden panel; disc amber during seen | Studio | Sonnet |
| M2.4 | Optional: distinct search pose clip (`docs/assets/wildbound-creature-visual-studies-v1.md:8`); upload needs consent | Blender, Studio | Sonnet |
| M2.5 | Decide outline and disc visibility; add flashlight beam; test reveal payoff, including a cost for the flashlight | Studio, humans | Opus |
| M2.6 | Smooth client movement if M1.6 shows stepping | Studio | Sonnet |

**Exit test, two parts, both muted and phone-sized, each with and without the chip:**

1. Nine two-client scenes. The list below is proposed; replace it if the session review has its own.
   1. A seen, B far away. 2. A seen, B nearby, B shows ally. 3. A breaks sight, shows searching with countdown. 4. Search expires, none. 5. A targeted, only A gets the attack warning. 6. Inventory open while seen, chip stays. 7. Retarget from A to B, both chips flip. 8. B's body stands between Silueta and A. 9. Retreat nearby shows no threat.
2. Five pairs answer "is it after you, your friend, or nobody?" during play. Proposed pass: at least 80% correct with the chip, and clearly better than without.

### M3: Capture that takes skill
Goal: catching Lumipol is a touch-friendly skill moment that exposes the player.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M3.1 | Capture design document, with D3 answered | None | Opus |
| M3.2 | Pure `CaptureSession`: server token, time limit, creature reservation, distance and alive checks, cancel on leaving; contracts | Studio | Opus |
| M3.3 | Server wiring, remote validation, rate limits | Studio | Sonnet |
| M3.4 | Touch capture UI, large targets, no sub-frame timing, text and visual feedback | Studio, Device Simulator | Sonnet |
| M3.5 | Lumipol wild behavior; add spawn slots inside fog, keep one safe first-capture slot; egg carry cost | Studio | Sonnet |
| M3.6 | Lumipol v2 model, rig, idle and walk clips, upload after design approval | Blender, Studio | Sonnet |

**Exit test:** five new testers on phones or Device Simulator capture without coaching, and can fail for a reason they can state. Two clients racing yields one owner. Spam and leave-mid-capture produce no duplicate or stuck reservation. Measure typical capture exposure time inside territory.

### M4: Real, fair consequence
Goal: Silueta can defeat a player, and nobody feels cheated.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M4.1 | Fair-strike decision record from section 2 | None | Opus |
| M4.2 | Measure Atomic and Persistent on the guardian; check `PersistentLoaded`, `GameplayPaused` and `GetNetworkPing` on server | Studio | Opus |
| M4.3 | Pure dwell gate with contracts | Studio | Opus |
| M4.4 | Target warning with attack ID, acknowledgement and K rule, bound to target, life and guardian generation; contracts include forged, late, duplicate and prior-life cases | Studio | Opus |
| M4.5 | Preload at camp; re-measure cold Telegraph mismatch | Studio | Sonnet |
| M4.6 | Staged strike, regeneration rule, defeat flow, clear loss summary, behind `damageMode` | Studio | Opus |
| M4.7 | Ambush relocation. Contract proves no camera or gaze input | Studio | Opus |
| M4.8 | Run N1 to N4 under Network Simulator at three latency and loss levels; cold join, late join, stream out and back | Studio | Sonnet |
| M4.9 | Minimum audio set of about six cues and ambience, original or properly licensed. Every cue also visible | Studio | Sonnet |

**Exit test:** report checks 5, 6 and 13 move from BLOCKED to PASS, with a genuinely muted client. Across N4 scenes, zero strikes without a delivered warning. Two people on real phones over a real connection play 20 minutes: at least one real defeat or near miss, and zero "I died without warning". Damage is enabled only in the private test place until this passes.

### M5: A reason to go back
Goal: stay-or-return becomes a real choice. All values are hypotheses.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M5.1 | Economy sheet and simulator (section 4) | None | Opus |
| M5.2 | Materials and currency in pure state; loss rule (pack proposes 12%, rounded per stack) with contracts; currency and companions never lost | Studio | Opus |
| M5.3 | Gather nodes at points of interest; one night-only fog resource; turn on `nightRewardsEnabled` | Studio | Sonnet |
| M5.4 | One server spawn pipeline with normalized weights by biome, time, weather and event; a night variant if D5 approves | Studio | Opus |
| M5.5 | Fix protections: seal usable before leaving or in the field, crafted repeatedly at camp. Add totem with a downside, backpack upgrade, extraction capsule | Studio | Opus |
| M5.6 | Small skill tree: four branches, about two nodes each. Bond grows from active use only. No AFK path, with a contract | Studio | Sonnet |
| M5.7 | Tune cycle and expedition length per D5 | Studio, humans | Opus |
| M5.8 | Camp screen for crafting and upgrades, plain but usable. HUD shows what you would lose | Studio | Sonnet |

### Gate F1: the core is proven fun

**Nothing after this line starts until F1 passes.** Thresholds are proposals for the user to confirm.

| Measure | How | Proposed pass |
| --- | --- | --- |
| Voluntary return | 10 new testers, at least half on phones, 20 free minutes, no coaching | At least 60% start a third expedition unprompted |
| Understands stakes | Exit question: what do you lose if you die? | At least 70% correct |
| Real tension | Exit question: tell me about a tense moment | At least half describe one specifically |
| Fairness | Exit question and server logs | Zero unwarned-death reports |
| Expedition length | Server logs | Median 3 to 8 minutes (5 to 10 is the pack's hypothesis) |
| Stay-or-return | Observed | Testers visibly weigh leaving against staying |

**If it fails:** return to M2 to M5, using what testers said. Do not add content.

### M6: Saved progress
Goal: companions survive leaving, and failed loads can never overwrite data.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M6.1 | Schema: one versioned record, migration path, durable unique IDs (fixes B17) | None | Opus |
| M6.2 | Fake-store contracts F1 to F5 (`wildbound-next-verification.md:59-65`) | Studio | Opus |
| M6.3 | Session lock, failed-load guard, retries, per [Roblox player data guidance](https://create.roblox.com/docs/cloud-services/data-stores/player-data-purchasing); its sample code is not to be used untested | Studio | Opus |
| M6.4 | Idempotent operation IDs for extraction, hatch and protection use; never report success before confirmed save | Studio | Opus |
| M6.5 | Disconnect rule per D10; remove session-only copy only when true | Studio | Sonnet |
| M6.6 | Real test in a separate isolated experience, after D8 | Studio | Sonnet |

**Exit test:** rejoin restores registered creatures, eggs and materials. Forced load failure keeps the stored record byte-identical. Two servers cannot overwrite each other. Killing the server mid-extraction gives one award, not zero or two. Logging out to dodge death gains nothing.

### M7: Co-op and mobile complete
Goal: two people on phones have more fun together than alone.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M7.1 | Encounter slots per D4 | Studio | Sonnet |
| M7.2 | Companion visible to all players, one per player, no orphans | Studio | Sonnet |
| M7.3 | One co-op reason: for example, one player captures while the other watches with the light, or a rescue before defeat (needs design approval) | Studio, humans | Opus |
| M7.4 | Rerun C1 to C7 with 2 and 4 clients; test abilities do not stack into trivializing Silueta | Studio | Sonnet |
| M7.5 | Full touch pass in portrait and landscape; fix overlap (B14) | Studio, humans | Sonnet |

**Exit test:** two humans on two real phones complete three expeditions with no help. Repeat with four. Race, spam and simultaneous defeat tests show no duplicates or cross-player effects.

### M8: Art, sound and interface
Goal: looks and sounds like a game worth installing. Approve a small coherent library before making more.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M8.1 | Art review of Silueta, Lumipol, kit against one bible; user approves | Humans | Opus |
| M8.2 | Camp art, nest, shelter, creature details; keep source files | Blender, Studio | Sonnet |
| M8.3 | Effects: flashlight, pulse, hatch reveal, capture, extraction | Studio | Sonnet |
| M8.4 | Fog Forest sound identity, Silueta cues, license ledger | Studio | Sonnet |
| M8.5 | Start screen, first-minute tutorial, quick bar, team, collection, camp panels | Studio | Sonnet |
| M8.6 | Settings: graphics, audio, accessibility, saved; default for Reduced per D11 | Studio | Sonnet |

**Exit test:** five new testers reach their first capture without help, and describe the game accurately from the first three minutes. All warnings work muted. Every asset has a source file and a recorded license or original status.

### M9: Performance and hardening
Goal: runs on a low-end phone and survives abuse.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M9.1 | Pick target phones; record frame time, memory, load time at camp, forest and night | Studio, humans | Sonnet |
| M9.2 | Fix by measured impact; set budgets from measurements | Studio | Sonnet |
| M9.3 | Remote audit: every remote against malformed, spam and replay input | Studio | Opus |
| M9.4 | Fix lifecycle failure (B18), long-session and server-shutdown handling | Studio | Sonnet |
| M9.5 | Validated funnel analytics: first capture, first extract, first defeat, third expedition | Studio | Sonnet |

**Exit test:** recorded before-and-after numbers on target phones, meeting budgets chosen in M9.2. An abuse script finds no duplicate, reward or state change. A one-hour soak shows no memory growth trend.

### M10: Private beta, then first release
Goal: a publishable first release, on the user's approval only.

| Unit | Work | Needs | Tier |
| --- | --- | --- | --- |
| M10.1 | Private beta with 20 to 50 players; fix top issues | Humans | Opus for analysis |
| M10.2 | Compliance: maturity questionnaire, chat and policy check, IP check of every asset | User | Opus |
| M10.3 | Listing: icon, thumbnails, description, rollback and data migration plans. Then **the user approves publishing** | User | Sonnet |

**Exit test:** beta funnel measured, no data-loss or duplication report, no open critical bug, user signs off. No monetization in this release unless the user decides otherwise.

### Gate F2: ready to expand

Set numeric targets after the first beta baseline; no thresholds are invented here. Require measured retention and session length from Creator Analytics, players returning without prompting, and no open fairness or data issue.

### M11: Expansion, only after F2

| Order | Content | Notes | Needs | Tier |
| --- | --- | --- | --- | --- |
| E1 | Second and third species with distinct roles and capture methods; reserves | Proves that rare is not simply better | Blender, Studio | Opus |
| E2 | Special-condition creatures, night events, temporary shelters, collection goals | Add one at a time; retest fun | Studio | Sonnet |
| E3 | El Vigia | Gaze, occlusion and network limits make it a separate design; must not be confused with Silueta | Blender, Studio | Opus |
| E4 | Living Forest, as first neutral contrast | Check whether each biome should be its own place | Blender, Studio | Opus |
| E5 | Frozen Mountains with Yeti (noise and snow tracks) | | Blender, Studio | Opus |
| E6 | Rock and Caves, Volcanic Lands, Cryptic Ruins, Demon Abyss | Each gated on the last one's data | Blender, Studio | Opus |
| E7 | Cosmetic monetization | Needs explicit approval. Guaranteed-result cosmetics first. Never pay-to-win | User | Opus |

**Policy note, read 2026-11-07:** [Roblox paid random items rules](https://create.roblox.com/docs/production/monetization/paid-random-items) require full outcome and numeric odds disclosure, also for indirect purchases such as keys, plus `PolicyService` eligibility checks. Random rewards earned only through play need no odds disclosure. Recheck when implementing.

## 4. Doable right now without Studio

**Honest limit:** Luau tests run only through the Studio harness (`docs/testing/wildbound-p0.md:22`). `luau`, `luau-analyze`, `lune`, `rojo`, `selene` and `stylua` are not on PATH (checked 11-07). So Luau units can be written here but not compiled, run or marked done. Under strict TDD they stop at test plus stub until RED is observed. Python and headless Blender units can be fully verified.

| Rank | Unit | Exact files | How it is tested | Verified without Studio? |
| --- | --- | --- | --- | --- |
| 1 | Commit slices (after go-ahead) | Section 6 | `git status`, `git log --stat`, then `python -I -B -m unittest` on tools | **Yes** |
| 2 | Fair-strike and lethality decision record | New `docs/mechanics/wildbound-fair-strike.md` | User review. Lists the M4 test matrix | Document only; the design stays unproven until M4 |
| 3 | Silueta pressure simulator: how long can a player stand still at each objective before Silueta arrives, day and night, across patrol phases | New `tools/simulate_silueta_pressure.py`, `tools/test_simulate_silueta_pressure.py`. Parses constants from `src/wildbound/WildboundWorldRules.luau` and the layout JSON so they cannot drift | `unittest`, with hand-computed cases | **Yes for the math.** It says nothing about fun |
| 4 | Map and layout contract test | New `tools/test_map_layout_contract.py`; reads `tools/build-wildbound-p0-map.luau`, `tests/WildboundP0Map_Test.luau`, `forest-layout-v1.json` | Should fail today, since builder has (110,-130) and plan has (35,-99). That is a real local RED; it turns green with M1.2 | **Yes for the RED**; green needs the M1.2 source edit, which still needs Studio to prove |
| 5 | Deployment manifest | New `tools/deploy_manifest.py`, `tools/test_deploy_manifest.py`, mapping per `docs/testing/wildbound-p0.md:9-16` and `wildbound-world.md:7-11` | `unittest` on hashing and mapping | **Yes** locally; comparing against Studio needs M1.1 |
| 6 | Correct stale banners | Files in section 1.3 | `rg` for old phrases; read-back | **Yes** |
| 7 | Capture design and touch flow | New `docs/mechanics/wildbound-capture.md` | User review; M3 tests later | Document only |
| 8 | Lumipol v2 model: sharper petals, unified pivots, stud scale. Keep v1 | New `tools/build-lumipol-v2.py`, `tools/test_lumipol_v2.py`, `assets/blender/lumipol-roblox-v2*` | Headless Blender plus `unittest`, in the style of `tools/test_forest_kit.py`; render for the user | **Yes for geometry.** Import, scale in game and design approval are not |
| 9 | Economy sheet and simulator | New `docs/mechanics/wildbound-economy-p0.md`, `tools/simulate_economy.py`, test file | `unittest` for loss rule rounding and normalized weights | **Yes for the math**; not balance or fun |
| 10 | Silueta search pose clip | `tools/silueta_motion_v3.py` as a new versioned clip, `tools/test_silueta_motion_v3.py` | Existing `unittest` pattern, headless Blender, QA render | **Yes locally.** Upload and in-game check are not |
| 11 | Awareness contracts and stub | New `src/wildbound/WildboundSiluetaAwareness.luau`, `tests/WildboundSiluetaAwareness_Test.luau` | Static read only; RED and GREEN need Studio | **No** |

Coordinate with other agents first: `fog-forest-visual-kit.md` is active, and the forest and map files may be in use.

## 5. Decisions only the user can make

| ID | Decision | Recommendation |
| --- | --- | --- |
| D1 | Commit now, and which delivery chain (pending since `wildbound-first-playable.md:47`)? | Commit locally now on the current branch; pick `feature-branch-chain` so main stays untouched; no push yet |
| D2 | Which fair-damage approach, and may streaming ever be turned off? | Combine A + B + C + D + E; keep streaming on; allow F only if M4 measurements justify it |
| D3 | Which Lumipol capture method? | Hold still inside a slowly moving ring with a wide timing window, about 4 to 6 s, on one thumb |
| D4 | Shared or personal encounters in co-op? | Keep one-owner claims, but scale spawn slots with players so nobody waits |
| D5 | Cycle length, starting phase, target expedition length, night reward? | Test 12 minutes, starting at a random non-Night phase, 3 to 8 minute expeditions, one night-only resource |
| D6 | How lethal is Silueta? | First strike marks and drops one bag item, second defeats; no regeneration in fog |
| D7 | Approve the forest kit renders, and upload consent for six permanent assets? | Approve after review; upload folder must also be on the MCP allowlist (`fog-forest-visual-kit.md:56`) |
| D8 | Create a separate isolated experience and store for persistence tests? | Yes, before M6; never test in the main place |
| D9 | Install Rojo, `luau-analyze` and Lune? (Sensitive install) | Yes: sync prevents drift and local checks speed work; Studio remains the authority for pass or fail |
| D10 | Disconnect during an expedition? | Not a defeat, but pending loot expires if the player does not return within about three minutes, so leaving is never free extraction |
| D11 | Reduced effects default? | Off by default, offered on first start screen, because On mutes the horror |
| D12 | Who are the testers, on which phones? | Recruit at least ten people plus two real low-end phones before M2 needs five pairs |
| D13 | Languages for first release? | English and Spanish if testers need it; decide and add at M8 |
| D14 | Loadout for first release? | One active only; add two reserves with the second species |
| D15 | Are F1 thresholds right, and is Lumipol's and Silueta's design final? | Confirm thresholds before testing; do not declare designs final until M8.1 |
| D16 | Keep binaries in git or use LFS? | Git for now at 42 MB in `assets/`; move to LFS if it grows well past that |

## 6. Risks, unverified assumptions, and delivery

### Risks

| Risk | Likelihood | Impact | Response |
| --- | --- | --- | --- |
| Work lost, since game source is untracked and other agents are active | Medium | Severe | Commit first; one owner per slice |
| A `.rbxl` backup gets staged: `.gitignore` covers only `*.rbxl.lock` | High | Medium | Stage by exact path; add ignore rule with user consent |
| Studio differs from local source | Medium | High | Hash check before any test (M1.1) |
| Green contracts are mistaken for fun | High | Severe | F1 gate; humans from M1.7 onward |
| Fair damage has no perfect signal | Certain | High | Accept layers; fail closed; measure unfair deaths |
| Scope creep into biomes and creatures | High | Severe | F1 and F2 gates |
| Horror too intense for the audience, or maturity label limits reach | Medium | Medium | Questionnaire review before M10 |
| Forest kit fails on phones: 74,996 triangles was never measured on a device | Medium | High | Measure in M1.5 |
| Collision on the kit breaks flat steering (`WildboundWorld.server.luau:172`) | Medium | High | Decide in M1.4; pathfinding if required |
| Asset provenance: generated concepts and the pack have unverified rights | Low | High | Concepts are references only; pack stays local; license ledger |

### Unverified assumptions

| Assumption | Status | Settled by |
| --- | --- | --- |
| Local `src/wildbound` matches what is in Studio | Unverified: no Studio this session | M1.1 |
| The 80 contracts still pass | Last run 11-06 per the task document; not rerun | M1.1 |
| Default walk speed 16 and Health regeneration apply here | Stated in docs or assumed; regeneration not checked | M1.1 |
| Place streaming radii are defaults | Unread | M4.2 |
| Pack values (5 to 10 minutes, 12%, 4 s, 30 s) | Hypotheses | M5, F1 |
| Nest position (35,-99) | Geometry checked in the plan, not played | M1.2, M3 |
| No human playtest happened | No record found; the user may have played informally | Ask the user |

### Safe commit-slice plan (do not run until D1)

Stage by exact path only. Run the listed check before each commit. Use conventional commits without AI attribution, per the user's rule. Tests and docs travel with the behavior. Each Luau slice's evidence is its recorded Studio result, since these cannot be rerun now. Several slices exceed about 400 authored lines; that is a planning guide, so do not shrink them artificially.

| Order | Slice message | Paths | Check |
| --- | --- | --- | --- |
| 1 | `feat(wildbound): add session inventory state with contracts` | `src/wildbound/WildboundState.luau`, `tests/WildboundState_Test.luau`, `docs/mechanics/wildbound-state.md` | 17/17 recorded 11-06 |
| 2 | `feat(wildbound): add P0 fog forest greybox builder` | `tools/build-wildbound-p0-map.luau`, `tests/WildboundP0Map_Test.luau`, `docs/maps/wildbound-p0.md` | 5/5 recorded 11-06 |
| 3 | `feat(wildbound): connect pickups, extraction and inventory UI` | `src/wildbound/WildboundServer.server.luau`, `src/wildbound/WildboundClient.client.luau`, `docs/ui/wildbound-p0.md`, `docs/testing/wildbound-p0.md` | Solo run recorded 11-05 |
| 4 | `feat(wildbound): add Silueta, flashlight and shared day-night cycle` | `src/wildbound/WildboundWorldRules.luau`, `src/wildbound/WildboundSiluetaHunt.luau`, `src/wildbound/WildboundWorld.server.luau`, `src/wildbound/WildboundWorld.client.luau`, `tests/WildboundWorldRules_Test.luau`, `tests/WildboundSiluetaHunt_Test.luau`, `docs/mechanics/wildbound-world.md`, `docs/mechanics/wildbound-creature-night-profiles.md`, `docs/ui/wildbound-world.md`, `docs/testing/wildbound-world.md`, `docs/testing/silueta-encounter-phase-report.md` | 23 + 9 recorded. World requires Hunt, so they ship together |
| 5 | `feat(wildbound): add optional Silueta visual adapter` | `src/wildbound/WildboundSiluetaVisual.luau`, `tests/WildboundSiluetaVisual_Test.luau`, `docs/testing/silueta-visual-adapter.md`, `docs/testing/silueta-animation-runtime.md` | 26/26 recorded |
| 6 | `feat(assets): add original Silueta rig and animation sources` | `tools/build-silueta-asset.py`, `tools/build-silueta-rig-v3.py`, `tools/roundtrip-silueta-rig-v3.py`, `tools/silueta_motion_v3.py`, `tools/test_silueta_motion_v3.py`, `tools/verify-export-silueta-rig-v3.py`, Silueta files under `assets/blender/` and `assets/exports/` (not `.rbxl`), `docs/assets/silueta-*`, `docs/testing/silueta-animation-assets.md`, `docs/testing/silueta-native-idle.md` | `test_silueta_motion_v3` 6 OK on 11-07 |
| 7 | `feat(assets): add fog forest kit and layout plan` | `tools/build-forest-kit.py`, `tools/test_forest_kit.py`, `tools/plan_forest_layout.py`, `tools/test_plan_forest_layout.py`, `assets/blender/forest-kit/`, `assets/exports/forest-kit/`, `assets/maps/forest-layout/`, `assets/concepts/silueta-forest/`, `docs/maps/silueta-forest-concept-v1.md`, `odd/tasks/fog-forest-visual-kit.md` | 15 and 31 OK on 11-07. **Confirm that the owning agent has finished** |
| 8 | `feat(assets): add Lumipol blockout and creature studies` | `tools/build-lumipol-blockout.py`, Lumipol files in `assets/blender/`, `assets/concepts/creatures/`, `docs/assets/wildbound-creature-visual-studies-v1.md`, `odd/tasks/wildbound-creature-visual-studies.md` | File read-back |
| 9 | `docs(wildbound): record playable task history, test guide and roadmap` | `odd/tasks/wildbound-first-playable.md`, `docs/testing/wildbound-next-verification.md`, `docs/wildbound-roadmap.md` | Read-back |
| 10 | `feat(rescue): preserve earlier rescue prototype` | `src/client/`, `src/server/`, `tests/RescueState_Test.luau`, `tests/RunUnitTest.luau`, `tests/UnitTestRunner.server.luau`, `tests/ClientIntegration.luau`, `tests/GameplayIntegration.luau`, `odd/tasks/creature-rescue-inventory.md` | Recorded 15/15; optional slice, user may prefer another branch |
| Owner decides | `docs(tooling)` for existing edits | `.codex/agents/*`, `.gitignore`, `AGENTS.md`, `README.md`, `docs/agent-routing.md` | These modified files may belong to other agents; ask first |

**Leave out of git:** `tools/__pycache__/`, all `*.rbxl` at the root and in `assets/exports/`, and `resources/skill-packs/` (already ignored). Keep the `.rbxl` backups on disk, because they are the only full copies of the Studio state.

**Recovery:** the verified backups are `assets/exports/wildbound-h1-h2-retarget-20261106-unique-81631061.rbxl` (latest), `assets/exports/wildbound-closeout-20261106-2136-81631061.rbxl`, and `wildbound-p0-studio-20261105.rbxl`. Copy them somewhere outside the repository too.

## Next step

Answer D1, so the work can be committed, then D2 to D6. Next session: connect Studio MCP and start M1.1 after confirming the target.
