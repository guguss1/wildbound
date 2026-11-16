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
| `src/wildbound/WildboundCandyCritterAnim.client.luau` | `StarterPlayer.StarterPlayerScripts.WildboundCandyCritterAnim` (LocalScript) | The live player |
| `tests/WildboundCandyClipKit_Test.luau` | `ServerStorage.WildboundCandyClipKit_Test` | Pure suite, 8 cases |

Regenerate the data modules with:
`& "C:\Program Files\Blender Foundation\Blender 5.0\blender.exe" --background --factory-startup --python tools/generate_candy_critter_clips.py`.
The Duquesa module comes from `duquesa-burbuja/duquesa-burbuja-v2-clips.json`, the others from `<slug>/<slug>-clips.json`.

## How the live animation works

- **Discovery.** The script watches `Workspace.WildboundNewCandyPreview` (scenery) and `Workspace.WildboundBeastsLocal` (the beast client's live clones). It picks up a model named after one of the six, or one with the attribute `WildboundCritter = <name>`.
- **Rest pose.** Each bone's rest rotation is read once per model, relative to `model:GetPivot()`. It comes from the bone `CFrame` chain, so a Transform already written does not affect it. The result is equal to `pivot:ToObjectSpace(bone.WorldCFrame).Rotation` taken at rest, which is the value `Clips.build` uses.
- **Each Heartbeat.**
  - `Kit.sample(clip, t)` gives the pose. Loops wrap and one-shots clamp. Keys ease Cubic InOut, or Linear when `clip.easing == "Linear"`.
  - Clips cross-fade over 0.15 s.
  - The script writes `bone.Transform = rest:Inverse() * (CFrame.new(d) * CFrame.Angles(r)) * rest`.
  - It reuses its buffers and writes nothing for bones at rest.
- **Skips and clean-up.** Models more than 250 studs from the camera are skipped. Models that leave the DataModel are dropped. If the model has a string attribute `Clip_<current clip>` (a published id), the script puts that model's bones back to rest and leaves the clip to the Animator, so a published id always wins.
- **Preview models.** They play a default loop: Duquesa `SitIdle`, Mielita `Fly`, the others `Idle`. Every 5–9 s they play one short clip, then return to the loop: Mochimiau Bounce, Canelin Alert, Flanin Wave, Gato Call, Mielita Pollen, Duquesa Surprised.
- **Live clones.** The clip follows `BeastPhase` through the per-creature `PHASE` map in the script:
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
3. Paste the ids into the creature's data as `IDS = { ... }` next to `ORDER`, in the generator output or by hand. `Publish.idsSource(Clips, ids)` produces the `Clips.IDS = {...}` line.
4. The model service sets `Clip_<name>` for every clip that has an id. From then on the Animator plays that clip and this script stops writing it.
5. Known gap: `Publish.README` still says "Tortidragon y Don Glaseon … 11 … 22 ids". It is a shared file and was not edited, so the README text is wrong for the six new creatures.

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
  - The five small creatures appear as live beasts in `WildboundBeastsLocal`, because the other session's `WildboundCandyCritterService` removes their preview copies. Only Duquesa remains in the preview folder.

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

## Not checked

- No screenshot: `screen_capture` timed out three times, in Play and in Edit. Look at the plaza in Studio by hand.
- How the deformation looks (direction of the poses on screen, Duquesa seated on the cake with Hips −3.3) was not checked by eye.
- The Release/Strike and cross-fade transitions were seen only through sampled numbers, not visually.
- Not tested on a phone or with two players.
- The Animator hand-off (`Clip_<name>`) is untested, because no ids exist yet.

## Decisions taken for the user

- The PHASE maps above, including Telegraph → Pollen for Mielita and Telegraph → Call for Gato, since neither has a Charge clip.
- The data modules live in ReplicatedStorage, because the client needs them. The clip-module API is unchanged, so `Publish` and `Pets` can use them.
- This doc is a separate file because `wildbound-candy-critters.md` already exists and belongs to the other session.
