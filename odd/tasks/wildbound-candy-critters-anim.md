# Wildbound: candy critters, live animation without published assets

Companion to `odd/tasks/wildbound-candy-critters.md` (that file belongs to the session that built the brains, posts and model service; it is left untouched). This file covers only the animation layer.

## Objective

Make the six new Caramelo creatures (Duquesa Burbuja v2, Mochimiau, Canelin, Flanin, Mielita, Gato Repartidor) move in the game **without any published Animation asset**, straight from their Blender clip data. Also prepare the KeyframeSequences so the owner can publish them to the group later.

Background: the game is owned by a group, and Roblox only plays Animation assets owned by that group. Uploads from this machine are user-owned, so until the owner publishes, the Animator path leaves the creatures in their rest pose. This layer writes `Bone.Transform` on the client instead, the same approach `WildboundBeastAnim` already uses for the wave-2 beasts.

## Files (all new)

| Repo path | Studio location | Role |
|---|---|---|
| `src/wildbound/WildboundCandyClipKit.luau` | `ReplicatedStorage.WildboundCandyClipKit` | `Kit.define` (the clip-module API: ORDER, CLIPS, IDS, animationId, build), `Kit.sample`, `Kit.transform`, `Kit.ease`, `Kit.localTime` |
| `src/wildbound/WildboundCandyCritterClips<Name>.luau` (×6) | `ReplicatedStorage.WildboundCandyCritterClips<Name>` | Generated clip data, `return require(script.Parent:WaitForChild("WildboundCandyClipKit")).define({...})` |
| `tools/generate_candy_critter_clips.py` | – | JSON → Luau generator. Runs in Blender's Python or any Python 3 |
| `src/wildbound/WildboundCandyCritterAnimSpec.luau` | `ReplicatedStorage.WildboundCandyCritterAnimSpec` | Which clip plays: the per-creature idle / extras / PHASE maps, `clipFor`, `publishedId`, `critterName`, FADE / FAR (moved out of the client so the suite can test it) |
| `src/wildbound/WildboundCandyCritterAnim.client.luau` | `StarterPlayer.StarterPlayerScripts.WildboundCandyCritterAnim` (LocalScript) | The player: live Bone.Transform path, and the Animator path for published ids |
| `tests/WildboundCandyClipKit_Test.luau` | `ServerStorage.WildboundCandyClipKit_Test` | Suite, 11 cases (kit, spec vs the six data modules, client wiring) |

Regenerate the data modules with:
`& "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" --background --factory-startup --python tools/generate_candy_critter_clips.py`.
The Duquesa module comes from `duquesa-burbuja/duquesa-burbuja-v2-clips.json`, the others from `<slug>/<slug>-clips.json`.

## How the live animation works

- **Discovery.** The script watches `Workspace.WildboundNewCandyPreview` (scenery) and `Workspace.WildboundBeastsLocal` (the beast client's live clones). It picks up a model named after one of the six, or one with the attribute `WildboundCritter = <name>`.
- **Rest pose.** Each bone's rest rotation is read once per model, relative to `model:GetPivot()`. It comes from the bone `CFrame` chain, so a Transform already written does not affect it. The result is equal to `pivot:ToObjectSpace(bone.WorldCFrame).Rotation` taken at rest, which is the value `Clips.build` uses.
- **Each Heartbeat.**
  - `Kit.sample(clip, t)` gives the pose. Loops wrap and one-shots clamp. Keys ease Cubic InOut, or Linear when `clip.easing == "Linear"`.
  - A clip change cross-fades over 0.15 s from the pose last written (a frozen snapshot), so a chain of changes less than 0.15 s apart blends instead of snapping.
  - The script writes `bone.Transform = Kit.transform(rest, v, restInv)`, i.e. `rest:Inverse() * (CFrame.new(d) * CFrame.Angles(r)) * rest` (the same function `build` uses; no inline copy).
  - It reuses its buffers and writes nothing for bones at rest.
- **Published ids (Animator path).** If the model has a non-empty string attribute `Clip_<current clip>` and an `Animator` (under its AnimationController or Humanoid), this script itself loads that Animation on the Animator (once per clip, `Looped` from the clip data), plays it with a 0.15 s fade, stops it on the next clip change or when the model is dropped, and puts the bones back to rest. Clips without an id stay on the live path, so a partly published set mixes both. Without an Animator the live path runs even if an id exists. No other script plays `Clip_` ids for these six.
- **Skips and clean-up.** Models more than 250 studs from the camera skip the live path. Models that leave the DataModel are dropped (track stopped). A Heartbeat error warns, stops the track, resets the bones to rest, drops the model and sets it up again after 2 s (at most 3 retries per model).
- **Preview models.** They play a default loop: Duquesa `SitIdle`, Mielita `Fly`, the others `Idle`. Every 5–9 s they play one short clip, then return to the loop: Mochimiau Bounce, Canelin Alert, Flanin Wave, Gato Call, Mielita Pollen, Duquesa Surprised.
- **Live clones.** The clip follows `BeastPhase` through `Spec.clipFor` and the per-creature `PHASE` map in `WildboundCandyCritterAnimSpec`:
  - Calm phases (Spawn, Calm, Dormant, Patrol, Guard, Wake, Return, Disengage, Ended, GiveUp, Recover) → idle (Mielita `Fly`).
  - Notice → an alert clip.
  - Chase → Mochimiau Trot, Canelin/Flanin Walk, Mielita Patrol, Gato Run, Duquesa Glide.
  - Telegraph → Charge. Mielita uses Pollen and Gato uses Call, because they have no Charge clip.
  - Release/Strike → the attack clip: Mochimiau Bounce, Canelin Spin, Flanin Jump/Land, Mielita Dash, Gato Throw, Duquesa Whip.
  - Duquesa Recover → its own Recover clip.
  - Unknown phase → idle.
  - These cover every phase the shared brain `WildboundBeastCandyCritter` emits.
- **QA attribute.** The script sets the client-local attribute `WildboundCritterClip` to the current clip on each model.

## How to publish later

1. In Edit, `ServerStorage.WildboundPublishClips` now holds one folder per creature: DuquesaBurbuja 9, Mochimiau 7, Canelin 7, Flanin 8, Mielita 7, GatoRepartidor 8. That is 46 KeyframeSequences, next to the existing Tortidragon 11 and DonGlaseon 11.
   - They were built by `WildboundCandyClipPublish.build(ServerStorage, sets)` from the prefabs in `ServerStorage.WildboundNewCandyImports`.
   - That module was not edited.
   - The folder lives in the open session only, until the place is saved.
2. For each sequence: right-click, Save to Roblox, Creator = the group.
3. Paste the ids where the `Clip_` attributes come from: the `CLIPS[<name>].IDS = { Clip = id, ... }` table in `src/wildbound/WildboundCandyCritterService.server.luau` (lines 16-22). That service is the only reader; it never reads the data modules, so ids pasted into a `WildboundCandyCritterClips<Name>` module do nothing for the game (they only feed `Clips.animationId` and `Publish.pending`). The service belongs to the other session, so this change is theirs (or the owner's) to make.
4. On the next Play the service sets `Clip_<clip>` on the model it parks in `ReplicatedStorage.WildboundBeasts.Models`, the beast client's clone carries it, and `WildboundCandyCritterAnim` plays that Animation on the clone's Animator (checked in Play with a probe id, see Evidence). Clips still without an id keep the live path.
5. Duquesa Burbuja has no path for ids: she is scenery in `Workspace.WildboundNewCandyPreview`, with no service and no Animator, so she stays on the live path until something sets `Clip_<clip>` on her and gives her an Animator.
6. Known gap: `Publish.README` still says "Tortidragon y Don Glaseon … 11 … 22 ids". It is a shared file and was not edited, so the README text is wrong for the six new creatures.

## Evidence (2026-11-16, Studio place 122652861404212)

- **Fingerprints.** Studio Source equals the repo file after CRLF→LF and stripping trailing newlines (length / Adler-32):

  | File | Length | Adler-32 |
  |---|---|---|
  | ClipKit | 6423 | 2871266590 |
  | CritterAnim | 9552 | 1247692646 |
  | ClipKit_Test | 9600 | 3170465017 |
  | ClipsCanelin | 12939 | 254751946 |
  | ClipsDuquesaBurbuja | 28946 | 4078424838 |
  | ClipsFlanin | 19933 | 4213114951 |
  | ClipsGatoRepartidor | 29418 | 1126010488 |
  | ClipsMielita | 37589 | 2768998801 |
  | ClipsMochimiau | 17141 | 2750466337 |

- **Suite.** Fresh loader (loadstring of every Source, `WildboundFreshRunnerLock` respected), run `4874f7d0`: `WildboundCandyClipKit_Test` 8 passed, 0 failed. Called with `(Kit, ServerStorage.WildboundNewCandyImports.Canelin, CanelinClips)`.
- **Bone check.** Every posed bone exists in its prefab and no clip poses Root:

  | Creature | Clips | Keys |
  |---|---|---|
  | Duquesa | 9 | 45 |
  | Mochimiau | 7 | 44 |
  | Canelin | 7 | 38 |
  | Flanin | 8 | 57 |
  | Mielita | 7 | 70 |
  | Gato | 8 | 44 |

- **Publish.build.** Built 46 sequences. Tortidragon and DonGlaseon folders are still present. Every new clip is pending (no ids). Duquesa SitIdle has 5 keyframes, Loop true, priority Idle.
- **Play check.**
  - Run under `WildboundPlayLock = "critter-anim"`, then cleared. Results are from the Client datamodel, with two samples 0.5 s apart.
  - The five small creatures appear as live beasts in `WildboundBeastsLocal` (the beast client clones the rigs `WildboundCandyCritterService` parks in `ReplicatedStorage.WildboundBeasts.Models`). Their preview copies are not removed at runtime: the saved place's `Workspace.WildboundNewCandyPreview` already holds only DuquesaBurbuja in Edit, so they were removed in Edit by the session that built the brains (its record, `wildbound-candy-critters.md`, lists "the removed preview copies" among the unsaved Studio changes). (The first version of this line wrongly said the service removes them.)

  | Model | Phase | Clip | Bones non-identity | Bones changed in 0.5 s |
  |---|---|---|---|---|
  | DuquesaBurbuja (preview) | – | SitIdle | 21/23 | 21 |
  | GatoRepartidor | Patrol | Idle | 11/19 | 11 |
  | Mochimiau | Telegraph | Charge | 8/13 | 10 |
  | Canelin | Patrol | Idle | 10/15 | 10 |
  | Flanin | Patrol | Idle | 10/12 | 10 |
  | Mielita | Telegraph | Pollen | 15/16 | 15 |

  - With the camera about 613 studs away (the default start-screen camera), Duquesa correctly stayed unwritten: the 250-stud skip works.
  - Console: no errors or warnings from `WildboundCandyCritterAnim`.

## Review fixes (2026-11-16, second pass)

An independent review of e50c03b found six defects; all were fixed:

- [x] **R1** Animator hand-off went to nobody: the client now plays `Clip_<clip>` itself on the model's Animator (load, Looped, play, stop on change and drop).
- [x] **R2** Publish steps pointed at the data modules: they now point at the service's `IDS` table, and say Duquesa has no id path.
- [x] **R3** Wrong cause given for the missing preview copies: reworded (removed from the saved place, not by the service).
- [x] **R4** Tests did not cover the client: the spec moved into `WildboundCandyCritterAnimSpec`; CK9 walks it against the six data modules and the brain phases, CK10 covers `clipFor` fallback, `critterName` and the `Clip_` rule, CK11 checks the client uses the spec, `Kit.transform` and the Animator path; CK7 now also asserts the round-trip rotation. The client calls `Kit.transform` (new optional `restInv` argument) instead of an inline copy.
- [x] **R5** No clean-up after an error: bones reset and track stopped before the drop, then re-setup after 2 s (max 3).
- [x] **R6** Quick clip chains snapped: the fade now starts from the pose last written.

Evidence:

- **Fingerprints** (Studio Source == repo after CRLF→LF and trailing newlines stripped, length / Adler-32): Spec 3618 / 2236191062, ClipKit 6552 / 1383479734, ClipKit_Test 13910 / 1412948901, CritterAnim 9913 / 1618538305. The six data modules are unchanged.
- **Suite.** Fresh loader (loadstring + setfenv over clones in a temporary `ServerStorage.WildboundFreshRunner_<id>` folder, `WildboundFreshRunnerLock` taken and cleared, folder destroyed), run `76ade1a7`: `WildboundCandyClipKit_Test` 11 passed, 0 failed.
- **Play** (`WildboundPlayLock = "critter-anim"`, cleared after; Client datamodel, two samples 0.5 s apart):
  - Duquesa (preview, camera moved next to her): SitIdle, 22/23 bones off rest, 14 changed.
  - Mochimiau (live, Patrol): Idle, 10/13 off rest, 10 changed.
  - Animator path on Mochimiau: with a client-local probe `Clip_Idle = "rbxassetid://1"` the script started 1 looped track on its Animator and the bones went to rest (0/13); with the attribute cleared the track stopped and the live path resumed (10/13). The id does not exist, so Roblox logged "Failed to load animation" for it; nothing else from the script.
  - Console: no warnings or errors from `WildboundCandyCritterAnim`.

## Not checked

- No screenshot: `screen_capture` timed out three times, in Play and in Edit. Look at the plaza in Studio by hand.
- How the deformation looks (direction of the poses on screen, Duquesa seated on the cake with Hips −3.3) was not checked by eye.
- The Release/Strike and cross-fade transitions were seen only through sampled numbers, not visually.
- Not tested on a phone or with two players.
- The Animator path was checked only with a probe id that does not load (`rbxassetid://1`), so a real group-owned clip has not been seen playing on these rigs.
- The cross-fade from a snapshot during quick phase chains is checked by reading the code, not in Play (the server drives BeastPhase).
- Only Mochimiau and Duquesa were sampled in the second Play check (the others were out of the beast client's range from where the character stood).

## Decisions taken for the user

- The PHASE maps above, including Telegraph → Pollen for Mielita and Telegraph → Call for Gato, since neither has a Charge clip.
- The data modules live in ReplicatedStorage, because the client needs them. The clip-module API is unchanged, so `Publish` and `Pets` can use them.
- This doc is a separate file because `wildbound-candy-critters.md` already exists and belongs to the other session.
