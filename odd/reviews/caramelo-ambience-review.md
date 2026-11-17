# Caramelo ambience: code review (read-only)

Scope: uncommitted `src/wildbound/WildboundCandyAmbience.luau`, `src/wildbound/WildboundCandyAmbience.client.luau`,
`tests/WildboundCandyAmbience_Test.luau`; diffs of `WildboundAudioMix.luau`, `WildboundAudio.client.luau`,
`WildboundAudioCatalog.luau` (comment), and the ambience rows in `tools/studio-fresh-runner.luau`, `tools/deploy_manifest.py`,
`tools/test_deploy_manifest.py`. Nothing was executed (Luau runs only in Studio); every trace below is by hand.

Verdict: **no BLOCKER found.** One MAJOR (most sparkles are emitted from inside opaque meshes), several MINOR. The
suites AM1-AM11 should pass for the right reasons, the SPECS row matches the suite signature, and every existing
audio pin still matches.

## Findings

### MAJOR 1: sparkles (and some lights) spawn inside opaque meshes, so many are never seen
`WildboundCandyAmbience.client.luau:98-109` (descriptors) and `:153` (`locate`).
The emitter attachment is placed at the piece's **centre** plus a small lift:
- cotton tree: `CrownA` centre + 3. The crown is 6-14 studs tall (more after `growTree`, plus `Fluff_*` balls), so the
  spot is deep inside the canopy. Glitter lives about 2 s at 0.6-1.6 studs/s: it never leaves the crown.
- cookie tree: `Crown` centre + 1, crown about 7.7 studs tall: same.
- lollipop: `Hub` centre + 0, i.e. the middle of the vertical disc (radius 4.2+ studs, about 1.1 thick). Particles go
  up roughly in the disc's plane and die near its edge; only those drifting sideways out of the thin disc show.
- gumdrop `DropsA` centre + 1 on a 2.5-3 stud drop: borderline (Transparency 0.25 helps).
Cherry, Cap, nests and portal are fine (small pieces or a flat ring with +5).
Lights are less affected (Shadows = false lights the surroundings), but the prop that "glows" is not lit itself.
Fix (lift above the piece's top instead of its centre), in `locate`:
```lua
-- old
if piece and piece:IsA("BasePart") then return piece.Position + Vector3.new(0, c.lift or 0, 0) end
-- new
if piece and piece:IsA("BasePart") then
	local cf, half = piece.CFrame, piece.Size / 2
	local top = math.abs(cf.RightVector.Y) * half.X + math.abs(cf.UpVector.Y) * half.Y + math.abs(cf.LookVector.Y) * half.Z
	return piece.Position + Vector3.new(0, top + (c.lift or 0), 0)
end
```
and lower the lifts to match (lollipop 0 -> 0.3, cotton 3 -> 0.5, gumdrop 1 -> 0.3, sweet 1 -> 0.3; portal 5 can stay
since `ReturnRing` is flat). Confirm in Studio Play.

### MINOR 2: once the biome reference is lost it is never searched again
`WildboundCandyAmbience.client.luau:297-299` and `:395-398`.
If `WaitForChild(ROOT_NAME, 120)` times out (slow phone join), or the biome is replaced and `FindFirstChild` returns
nil at that moment, `biome` stays nil for the session: no lights, sparkles or Caramelo music. (Under StreamingEnabled
the Model container normally arrives at join, so this is unlikely today, but the fix is one token.)
```lua
-- old
if biome and biome.Parent == nil then
-- new
if not biome or biome.Parent == nil then
```
(Harmless when absent: `dirty` only triggers a rebuild while `inCandy`, which needs a biome.)

### MINOR 3: the Caramelo bed is much louder at dusk and night, not "slightly louder"
`WildboundAudioMix.luau:113-114`. `t.safeMusic = Mix.CANDY.safeMusic * calm` ignores time of day: Safe Night
0.08 -> 0.20 (x2.5, on top of nightBed 0.08), Dusk 0.12 -> 0.20, Day 0.15 -> 0.20. If the intent is "a bit louder"
at every hour:
```lua
-- old
t.safeMusic = Mix.CANDY.safeMusic * calm
-- new
t.safeMusic = t.safeMusic * (Mix.CANDY.safeMusic / 0.15)
```
(Day Safe still 0.2, Distant 0.107, Near/Chase 0; AM8 still passes within 1e-6.) If the flat 0.2 is intended, say so
in the comment. Outside Caramelo the mix is unchanged (traced below).

### MINOR 4: egg detection only sees Gomibu nest eggs
`WildboundCandyAmbience.client.luau:31, 317-323, 330`. `WildboundCandyEggArt.BOB_TAG` is added only when
`species == "Gomibu" and context == "nest"` (`WildboundCandyEggArt.luau:178-179`). So: with no Gomibu egg, every
live nest twinkles (intended fallback); as soon as one Gomibu egg exists, `anyEggsKnown` is true and every nest
holding any other species loses its twinkle. Minimal fix: do not treat the partial tag as complete knowledge:
```lua
-- old
kind = Ambience.nestKind(Ambience.nearEgg(pos.X, pos.Z, eggs, Ambience.EGG_RADIUS), #eggs > 0,
-- new
kind = Ambience.nestKind(Ambience.nearEgg(pos.X, pos.Z, eggs, Ambience.EGG_RADIUS), false,
```

### MINOR 5: egg-nest twinkle is warm, not lemon
`WildboundCandyAmbience.luau:103` + client `:236`. `colorName` prefers `light.color` over `sparkle.color`, so the
eggNest sparkle (`color = "lemon"`) is drawn "warm"; the sparkle colour of any kind with a light colour is dead.
```lua
-- old (client:236)
emitter = newEmitter(spec.style, Ambience.colorName(rec.kind, rec.id), node)
-- new
emitter = newEmitter(spec.style, spec.color or Ambience.colorName(rec.kind, rec.id), node)
```

### MINOR 6: lights and sparkles drop to the ground when the piece is streamed out
`WildboundCandyAmbience.client.luau:154-155`. If `Hub`/`CrownA`/... is streamed out, `locate` falls back to the
model pivot (the stick's foot), so a light or sparkle sits on the floor until the part streams back. Light reach is
120 studs and StreamingMinRadius is 64, so it can happen on the far picks. Fix: skip instead:
```lua
-- insert before `local ok, pivot = pcall(model.GetPivot, model)`
if c.piece then return nil end
```

### MINOR 7: a sway entry whose parts streamed out never recovers while it stays picked
`WildboundCandyAmbience.client.luau:373` (keep is a no-op). A streamed-back part is a new instance; the entry keeps
the dead ones (`Parent == nil`, skipped) so that lollipop stops wobbling until it leaves the pick. Fix:
```lua
-- old
reconcile(sways, Ambience.pick(records, eye, budget.sway, "sway"), newSway, function() end, restoreSway)
-- new
reconcile(sways, Ambience.pick(records, eye, budget.sway, "sway"), newSway, function(entry, rec)
	if entry.parts[1].part.Parent == nil then sways[rec.id] = newSway(rec) end
end, restoreSway)
```

### MINOR 8: a failing `animate` silently rebuilds everything every 0.5 s
`WildboundCandyAmbience.client.luau:413-414`. `teardown()` runs but `inCandy` stays true, so the next refresh
recreates all helpers and the next frame fails again, with no warning. At least warn once:
```lua
-- old
local ok = pcall(animate, os.clock())
if not ok then teardown() end
-- new
local ok, message = pcall(animate, os.clock())
if not ok then
	teardown()
	if not warned then warned = true warn("Wildbound candy ambience: " .. tostring(message)) end
end
```

### MINOR 9 (latent): the pitch tween ignores the catalog pitch of safeMusic
`WildboundAudio.client.luau:227`. Outside Caramelo every new safeMusic layer is tweened to PlaybackSpeed 1. Today the
catalog pitch is 1 (`slot()` default), so nothing changes; if someone sets `pitch` on safeMusic it would be silently
overridden outside Caramelo too.
```lua
-- old
TweenService:Create(bed, TweenInfo.new(Mix.CANDY.pitchSeconds), { PlaybackSpeed = musicPitch }):Play()
-- new
TweenService:Create(bed, TweenInfo.new(Mix.CANDY.pitchSeconds), { PlaybackSpeed = Catalog.SOUNDS.safeMusic.pitch * musicPitch }):Play()
```

### MINOR 10 (design check): the "sway" spins the disc in its own plane
`WildboundCandyAmbience.client.luau:256-258, 388`. The rotation axis is the disc's thinnest axis, i.e. its face
normal, through the hub: a +-5 degree in-plane spin. On the two-colour disc it shows only as a slight swirl turn, not
a sway/wobble. If a tilt is wanted, use an in-plane horizontal axis, e.g.
`axis = Vector3.yAxis:Cross(normal)` (fall back to `frame.RightVector` if near zero). Confirm by eye in Play.

### MINOR 11 (phone/desktop perf, optional)
`animate` (client:381-386) writes `Brightness` on up to 12 lights and, for cake lights, allocates a table and a
Color3 every frame. Desktop only (`pulse` is false on touch/soft), and small, but light property writes can force
lighting updates each frame; throttling the pulse to about 10 Hz would be cheaper and look the same at a 3 s period.

## Hand traces

### `Mix.targets` callers
All callers (grep of the repo): `WildboundAudio.client.luau:210` (5 args, new); `tests/WildboundAudioMix_Test.luau`
lines 22-146 (3 args); `tests/WildboundCandyAmbience_Test.luau` (3 or 5 args). No other caller.
- 3 args (`candy`, `candyTrack` nil): `candyTrack == true` false, `candy == true` false -> table identical to HEAD, no
  `carameloMusic` key. D9 invariants (catalog keys, music <= 0.35, guardian cues >= music) unchanged.
- candy, no track: only `safeMusic` changes (0.2 / 0.1 / 0 / 0 by level), no new key; cap 0.35 holds.
- track, not candy: `carameloMusic = 0` (a 0 target never creates a Sound). Track + candy: `carameloMusic` 0.18 / 0.09
  / 0 / 0, `safeMusic` 0.
- Ducking: `master.Volume` duck (`DUCK.scale`) and the hidden muffle are untouched; Near/Chase silence both beds.
- Outside Caramelo in the live client: `candy` false -> same volumes as HEAD; `musicPitch` 1 -> tween to 1, equal to
  the catalog pitch 1, so no audible change.

### AM1-AM11 (all expected to pass for the right reason)
- AM1: budgets 12/10/60/8 desktop; touch 6, rate 30 = 60/2, emitters 5, sway 4, no pulse; soft 6/0/0/0, no
  fireflies; `budget(true,true)` returns the same frozen soft row; ranges <= 16, brightness <= 2.2.
- AM2: scores L1 10, G0 20, G1 20 (tie by id), Nest 45 x 0.6 = 27, L2 30, L9 out of reach -> "L1,G0,G1,Nest_A";
  5 light picks; sparkle top is cotton (5); limit 0, NaN eye, unknown kind -> empty; sway only lollipops.
- AM3: sum 25 <= 60 unchanged; 20 -> scale 0.8; 0 -> zeros; worst case 10 x 8 = 80 -> 60 / touch 30.
- AM4: palette ints; nest/eggNest warm, portal sky; hash of ids differing in the last byte gives consecutive values,
  so Lollipop_1..4 use all four colours.
- AM5: bounds 412..812 / -203..197; distance 12; enter at 7, not at 20; stay at 20 when in; leave at 33; nil and
  NaN off; BiomeLight Meadow -> Caramelo gives the same square.
- AM6: pulse in [0.75, 1], sway within 5 degrees; cakeColor(0) pink, (2) mint (u = 1 exactly), (8) pink;
  thinAxis cases Z / X / Y.
- AM7: egg at distance sqrt 2 in, 50,50 out; nestKind table; weights 0.6 and 0.5.
- AM8: traced above; Distant 0.18 x 0.5 == 0.18 / 2 bit-exact; `fadeSeconds("carameloMusic")` 4 via BEDS; catalog
  entry absent so only the last loop runs, over keys already in the catalog.
- AM9: no 7-digit number, `rbxasset`, `.Texture`, `Instance.new("Sound")` or `SoundId` in the client; audio has
  `Catalog.SOUNDS.carameloMusic ~= nil`.
- AM10: every needle present; the cleanup pin `if not inCandy then\n\t\tteardown()` matches (file is LF, tab
  indented, verified by byte scan); banned words absent (the comment avoids the word RenderStepped).
- AM11: all three audio needles present verbatim.

### Runner and manifest
- SPECS `WildboundCandyAmbience_Test` supplies 4 `mod:` tokens + `{ client, audio }` in the order of
  `function(Ambience, Mix, Catalog, BiomeLight, sources)`; `src:WildboundAudioClient` is the name used by other rows.
- deploy_manifest and test_deploy_manifest rows are identical pairs (ReplicatedStorage module, StarterPlayerScripts
  `WildboundCandyAmbienceClient`, ServerStorage test). (The Flyers rows in the same diff were not reviewed.)

## Checked and fine
- Existing audio pins: AudioWiring (2 `Instance.new("Sound")`, no 7-digit ids, pcall/cleanup needles), Settings
  (`worldGui:GetAttribute("Reduced") == true`), Fear (heartbeat/roar/call/FearCueAt), Hunter (`Owner` pick) all
  still match; no test pins the old `Mix.targets(level, phase, reduced)` line.
- `tools/test_wildbound_audio_catalog.py` scans the SOUNDS body for 7+ digit numbers: the new comment has none.
- Luau syntax: `..=`, `+=`, `*=`, multiple assignment, no comment swallowing code on any line (all trailing `--` follow
  complete statements).
- API usage: ParticleEmitter (Color ColorSequence of two Color3, Size/Transparency NumberSequence of keypoints,
  Lifetime/Speed/Rotation/RotSpeed NumberRange, SpreadAngle Vector2, Acceleration, LightEmission/LightInfluence,
  Rate), PointLight (Shadows, Range <= 60, Brightness, Color), Attachment.WorldPosition after parenting, Part
  properties incl. Massless/CanQuery/CanTouch, `CollectionService:GetTagged`, attribute reads/writes, `Model:GetPivot`.
- Kit names: `Collision_Tier1..4` (14-char prefix) are X-axis cylinders so `RightVector` is up and Size.Y/Z the
  diameter; `Hub`, `DiscA`, `DiscB` are anchored MeshParts with CanCollide/CanQuery/CanTouch false (eligible to sway,
  no gameplay effect); `CrownA`, `DropsA`, `Cherry`, `Crown`, `Cap`, `ReturnRing`, `Ground.Floor`, `Syrup_*`
  (cylinders, Size.Y/Z diameter), `GiantLollipop_*`, `TreeCream/TreeCookie/CreamMushroom_*` prefixes all match the
  builder.
- No runtime writer moves lollipop parts (tree-resize is an Edit-mode tool asserting `not RunService:IsRunning()`;
  no server script touches them), so the sway base is not stale; restore runs on drop, leave, teardown and Destroying.
- Infinite yields: optional modules use 10 s timeouts and both exist in ReplicatedStorage; the biome wait has 120 s;
  `WildboundWorldUI` is looked up each tick and is `ResetOnSpawn = false`.
- Budgets: lights <= budget.lights, emitters = sparkle picks + 1 fireflies <= budget.emitters, total rate scaled
  to budget.rate, soft drops every emitter, sway and the fireflies; everything lives under one camera folder and is
  destroyed on leave; watched-container connections are disconnected when the container goes and on Destroying.
- Hysteresis 8 / 32 studs with `was` = previous state: no flapping on the edge; respawn (no root) falls back to the
  camera focus; nothing is sent to the server.
- Phone: 2 Hz refresh over about 150 candidates with FindFirstChild only, no GetDescendants; per frame only the
  fireflies part, up to 4 swaying heads (3 CFrame writes each) on touch, no pulse on touch; 30 particles/s on touch.
