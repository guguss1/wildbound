# Wildbound dread assets shortlist (giant antlered stalker)

Status: research only. Nothing here has been auditioned, inserted, previewed in Studio, or wired into the game.
Every candidate is a hypothesis to test by ear (audio) or by eye and part count (models) before use.

Brief: a giant (about 3x player height) antlered stalker in a dense misty low-poly forest. Players should hear it
approaching before they see it. This list extends `wildbound-horror-audio-shortlist.md` (same vetting rules) and
supports `docs/mechanics/wildbound-delivery-d.md`.

## How this list was built

- Tool: Roblox Studio MCP `search_asset`, `scope=creator_store`, `priceFilter=free`, run on 2026-11-07.
  Audio searches used `assetType=Audio`; tree searches used `assetType=Model`.
- Studio instance: `b18079a2-5d41-4f4e-968f-08afa716e5a4`, place 122652861404212. Read-only searches only.
  No `insert_asset`, no `execute_luau`, no edits, no Play, no uploads, no purchases.
- Every id below was returned by `search_asset` with `isFree=true`. No id was invented or recalled from memory.
- Vetting rules, same as the existing shortlist: prefer `ProSoundEffects` ("Courtesy of Pro Sound Effects") and
  `APMOfficial`. Anything that looks ripped from a game or media is excluded (SCP: Containment Breach, RE3
  Nemesis/Tyrant, Pillar Chase, FNAF/"Chica", Deepwoken, "Seek" and similar).
- Not verified for any entry: that the id inserts or plays in this experience (the tool warns some Creator Store
  assets are restricted), the exact license text, loop seams, loudness, mesh quality, and for models what the
  thumbnail looks like. The search result exposes none of these.
- Model facts (part count, studs, scripts) come only from the listing text, which is uploader-written. "No
  scripts" is a claim in the description, not something the tool checked. Re-check with an Explorer scan for
  `Script`, `LocalScript` and `ModuleScript` before any insert. Where the listing is silent, it says "not stated".
- Creator trust: the tool exposes no verified-creator or asset-count data (the `verifiedCreatorsOnly` filter did
  not filter reliably in the earlier pass, and it was not relied on here). "Prefer creators with many verified
  assets" could not be confirmed. The only fully trustworthy sources are the two professional audio libraries. For
  models, trust is a guess from the listing.
- License: Creator Store assets fall under the Creator Store terms. No per-asset license text is visible in search
  results. "Courtesy of Pro Sound Effects" and "Courtesy of APM Music" are attribution lines in the listing text,
  not license terms. Nothing here is a legal reading.

## 1. Audio

Design intent: the player hears the stalker first. Use one heavy step one-shot or sequence parented to the
stalker as a 3D `Sound` (long rolloff), play creaks and wood cracks at random positions between the player and the
stalker, and keep breathing or groans for the near band. For running, shorten the step interval and raise
`PlaybackSpeed` a little. No professional running-giant asset was found (see gaps).

### 1.1 Heavy footsteps (walk)

| Asset id | Name | Creator | Duration | Why it fits | Notes |
|---|---|---|---|---|---|
| 9125404769 | Boomy Footsteps Giant Thumpy Dinosaur Footsteps 1 (SFX) | ProSoundEffects | 4.6 s | "Boomy Footstep, Giant, Thumpy". Plural title and 4.6 s suggest several steps in one file, a ready slow-walk loop. | Description also lists "Explosion", so audition for a low blast layer. Verified via search_asset. |
| 9125404774 | Boomy Footsteps Giant Thumpy Dinosaur Footsteps 2 (SFX) | ProSoundEffects | 4.4 s | Same set, same use. A second variation to avoid obvious repetition. | Verified via search_asset. |
| 9125404796 | Boomy Footsteps Giant Thumpy Dinosaur Footsteps 3 (SFX) | ProSoundEffects | 9.3 s | Longest in the set; best candidate for a seamless-feeling approach bed. | Number of steps inside is not known; audition. Verified via search_asset. |
| 9114080709 | Dinosaur Footsteps Boomy Thumps 16 (SFX) | ProSoundEffects | 2.8 s | Already in the first shortlist: boomy thump on a leafy surface. Fits a forest floor. | Single-step one-shot. Siblings 9114079718 (2.1 s), 9114081009 (2.1 s), 9114078783 (2.3 s). Verified in the earlier pass. |

Lower-trust leads (community uploads, no duration, generic descriptions, not shortlisted): 124499547710959 "Giant
Footstep" (RustedHumanBeing, description "Giantssssss"), 76174354777172 "The Giant's Footsteps" (kakanekoJP,
"heavy footsteps mean a giant is approaching"), 95508100822503 and 118246141731799 "Giant Footsteps" (VulpesJFS),
18769416860 and 2006700168 "Giant Footstep" (ironhammer7, SuperEvilAzmil). Provenance and loudness unknown. Audition
only if the ProSoundEffects set sounds wrong. Excluded as likely rips or unsuitable: "Giant Robot/Pyro/Soldier
Footstep" (NickySergal, game-style), "Tyrant N T-type Footsteps (RE3 Remake)", "Pillar Chase II ... Footstep",
"Mutant_Walking_Loop" (godiguard, unclear source).

### 1.2 Running variant

Gap: none of the results for the running and heavy-footstep searches was a professional-library giant run. Options that need
no new asset, to test:

- Play the 9125404769 / 9125404774 steps at about 60 percent of the walk interval with `PlaybackSpeed` 1.1 to 1.25,
  and add more of the single one-shot 9114080709 for rhythm.
- Add a camera-free cue (branch crashes, below) so the run reads as "something heavy crashing through the forest".

### 1.3 Wood and branch cracks under weight

| Asset id | Name | Creator | Duration | Why it fits | Notes |
|---|---|---|---|---|---|
| 9126239755 | Wood Crack Thick Splintering Bursts Creaking 11 (SFX) | ProSoundEffects | 5.8 s | "Deep Crunchy Snaps, Clunking, Booming, Light Rumbling, Slowed Down". Reads as a heavy limb or trunk taking weight. | Best single match. Verified via search_asset. |
| 9126238892 | Wood Crack Thick Splintering Bursts Creaking 7 (SFX) | ProSoundEffects | 5.8 s | Same family: deep crunchy snaps, clunks, slowed down. | Verified via search_asset. |
| 9126240840 | Wood Crack Thick Splintering Bursts Creaking 3 (SFX) | ProSoundEffects | 3.0 s | Short, crisper snaps. Good for random "close" cracks. | Not slowed down, so less heavy. Verified via search_asset. |
| 9120827701 | Wood Crack Thick Splintering Popping 2 (SFX) | ProSoundEffects | 12.5 s | "Massive Crashing Bursts, Breaking". A whole tree or large branch failing. | Loud and long. Use for a rare event cue, cap the volume. Verified via search_asset. |

Earlier-pass alternates: 9120259118 (Tree Branches Breaking Snapping Cracking 1, 1.5 s) for light snaps.

### 1.4 Deep breathing and groans

| Asset id | Name | Creator | Duration | Why it fits | Notes |
|---|---|---|---|---|---|
| 9114628321 | Goliath Vocal Deep Growling Voice 17 (SFX) | ProSoundEffects | 2.2 s | "Deep Growling Voice, Mumbling Nonsense, Throaty Rumbling". A huge, slow, non-human voice. | Filed under "Robots - Voice"; audition for a robotic timbre and lower `PlaybackSpeed` to 0.6 to 0.8 for scale. Siblings 9114628818 (2.6 s), 9114630281 (3.0 s), 9114628620 (2.7 s). Verified via search_asset. |
| 9113973128 | Creature Growls Lion 8 (SFX) | ProSoundEffects | 1.6 s | "Deep Quiet Breathy Vocalizations, Rumbling, Throaty, Gurgling Groan". Closest to a low, breathy groan. | Lion source; pitch down to hide it. Siblings 9113971433 (2.2 s), 9113973119 (1.4 s). Verified via search_asset. |
| 9125470784 | Creature Growls Lion Deep Guttural Rumbling 18 (SFX) | ProSoundEffects | 2.6 s | "Calm, Very Throaty", deep rumble. Lower-aggression idle sound. | Another variant 9125470786 (2.6 s). Variant 9125467848 ends in "aggressive bursts", avoid for idle. Verified via search_asset. |
| 9113586909 | Breathing Tone Eerie Soft 2 (SFX) | ProSoundEffects | 36.0 s | Already in the first shortlist: soft hollow exhale bed, non-human. | Attach to the stalker as a 3D sound. Verified in the earlier pass. |

Gap: no true slow, huge breathing loop. The Goliath and Lion sets are short vocal one-shots; loop them at random
intervals and combine with 9113586909 as the bed.

### 1.5 Distant tree creak and rumble ("it is near" cue)

| Asset id | Name | Creator | Duration | Why it fits | Notes |
|---|---|---|---|---|---|
| 9120262025 | Tree Creak 2 (SFX) | ProSoundEffects | 45.0 s | "Tree Creak, Twisting, Rope Tension". Long, slow creak bed. | Rope-tension description: audition for a rope or ship timbre. Verified via search_asset. |
| 9120261928 | Tree Creak 1 (SFX) | ProSoundEffects | 19.8 s | Same family, shorter. Use as a random one-shot. | Verified via search_asset. |
| 9119388187 | Spacecraft Hull Buckle 21 (SFX) | ProSoundEffects | 4.7 s | "Distant Metal Booms, Deep, Soft Impacts, Reverb". A low distant boom as a rumble layer. | Sci-fi name, metallic; low-pass it. Lead only. Verified via search_asset. |
| 9120014291 | Thunder Airy Whomps Calm Sudden Bursts 3 (SFX) | ProSoundEffects | 14.7 s | Soft, windy, swelling low whomps. A distant rumble that is not a storm crack. | Audition for an unwanted thunder identity. Lead only. Verified via search_asset. |

Optional bed for a wood-heavy "something large is near" cue: 9126239555 above, played at low volume.

### 1.6 Audio top picks

1. Footsteps: 9125404769, 9125404774, 9125404796 (all ProSoundEffects "Boomy Footsteps Giant Thumpy Dinosaur
   Footsteps" 1, 2, 3).
   - 9125404769: giant-scale boomy thumps, 4.6 s, likely several steps, the best first test.
   - 9125404774: same set, 4.4 s, a variation to alternate.
   - 9125404796: 9.3 s, the longest, best for a looping approach bed.
2. Also test the first-shortlist single-step 9114080709 for the step one-shot rhythm.

### 1.7 Fear pass: heartbeat (2026-11-08)

Found with Studio `search_asset` (Creator Store, Audio, free only), not uploaded. The roar and the distant call reuse
9113973128 and 9114628321 above.

| Id | Title | Creator | Length | Why it fits | Caution |
| --- | --- | --- | --- | --- | --- |
| 9043365842 | HEARTBEAT 02 96BPM | APMOfficial | 60 s | A steady 96 BPM heartbeat bed from the APM "Horror Tools" album, the same official library as the music beds. Loops for the threat heartbeat; faster `PlaybackSpeed` when close. | Free on the Creator Store; licence by Roblox's APM deal, like the other APM ids. Audition the loop seam. Sibling 9043365993 (HEARTBEAT 03). Verified via search_asset. |

## 2. Models: tall low-poly trees

Target: pine and conifer plus dead bare trees, ideally 40 to 80 studs tall or scalable, close to the existing
`FK_` forest kit look (low-poly, mesh-based). No model here has been inserted or previewed; heights come from
listing text where available. "Bounding box" below is the listing's overall size (width x height x depth). A
bounding box in a pack (several trees) is the whole pack, not one tree.

Scripts flag: only entries that say "No scripts" in their listing are marked as such. Entries that say "Includes
scripts" are listed under "Avoid" below. Anything not stated needs an Explorer scan before use.

| Asset id | Name | Creator | Kind | Parts / tris | Size (studs) | Scripts per listing | Notes |
|---|---|---|---|---|---|---|---|
| 85032028165678 | Low Poly Pine Tree Forest Nature Trees Pack Model | Content Deleted - 158552482 | Pine | 2 parts, 2 meshes; tris not stated | 25 x 45 x 25 | No scripts | Single tree about 45 tall. Closest to the 40 to 80 target without scaling. Uploader account appears to be a bulk uploader with SEO-style titles; trust is a guess. |
| 117054667558675 | Dead Tree Spooky Forest Low Poly Pack Trees Stump | Musevogo86 | Dead | 4 parts, 4 unions; tris not stated | 66 x 82 x 62 | No scripts | Tall (82), but 4 unions in a 66-wide box suggests a cluster or large tree. Unions can cost more than meshes. Check thumbnail and part count after insert. |
| 125645355453609 | Pine Tree Pack - PS2 Style Assets - Low-Poly | https_cosha | Pine | 8 trees plus 4 decorations; MeshParts; listing says 200 to 600 tris per tree | not stated | not stated | Best match for "low-poly, stylized". Textured with normal maps (512 and 256 px), so it may not match the flat FK_ look. Only entry with an explicit triangle count. Needs a scripts scan. |
| 124323230212501 | Dead Trees Mesh Low Poly Spooky Forest Leafless | Content Deleted - 158552482 | Dead | 1 part, 1 mesh; tris not stated | 63 x 61 x 55 | No scripts | 61 tall; the 63 x 55 base suggests a wide mesh or a grouped mesh. Likely a cluster. Check before placing singly. |
| 81427347755756 | Dead Tree Spooky Forest Low Poly Halloween Trees | Rezedada107 | Dead | 1 part, 1 mesh; tris not stated | 4 x 27 x 4 | No scripts | Slim, leafless; scale to 2x for about 54 tall. Thin silhouettes read well in fog. |
| 92463157390723 | Dead Tree Low Poly Spooky Forest Mesh Trees Rotten | Content Deleted - 158552482 | Dead | 1 part, 1 mesh; tris not stated | 10 x 31 x 3.4 | No scripts | Flat 3.4 depth suggests a flat or 2D-ish silhouette. Check from all angles. |
| 74121267491779 | Low poly dead tree model | Error201173548u | Dead | tris: "550 tris" per listing; parts not stated | not stated | not stated | Blender-made, 550 tris. Only other entry with a stated triangle count. Needs a scripts scan and a height check. |
| 121575291347417 | Low-Poly Pine Trees Asset Pack Forest Snow Polly | Sisifupi82 | Pine | 20 parts, 20 meshes (pack) | 59 x 31 x 30 for the pack | No scripts | Pack of low-poly pines at about 31 tall; scale about 1.5x to 2x for 45 to 60. |

### Avoid (listing says it includes scripts)

- 116730360103328 Dead Trees Forest Spooky Low Poly Pack Haunted: "Includes scripts."
- 79591979251582 Low Poly Dead Tree Grass Rock Island Spooky Forest: "Includes scripts."
- 99151290587074 Low Poly Nature Pack Forest Assets Tree Rock Pine: "Includes scripts."
- 77171732187032 Low Poly Tree Big Rocks Map Trees Palm Dead Pine: "Includes scripts."

Also not shortlisted: 98801006759675 "Scary Tree" (1368 parts, far too heavy), 98721725839496 "Realistic Tall Tree" (96
tall but realistic, not low-poly), and the many "Low Poly Dead Tree Grass Rock Island" copies (reuploads of the
scripted asset above).

### Model top picks

1. 85032028165678 (low poly pine, 2 parts, 25 x 45 x 25, no scripts): already in the target height range, minimal
   part count.
2. 125645355453609 (PS2 style pine pack, 200 to 600 tris per tree): the only stated tri budget for pines; check
   the textured look against the FK_ kit and scan for scripts.
3. 81427347755756 (slim dead tree, 1 mesh, no scripts): scalable to 54 studs, cheap bare-tree silhouette for fog.

Runner-up for dead trees: 74121267491779 (550 tris), once scripts and height are checked.

## 3. Gaps and cautions

- No professional running-giant footsteps. Use the shortened-interval workaround in section 1.2.
- No slow, huge breathing loop; the Goliath, Lion and Eerie Soft sets are short or soft. Layer them.
- Tree creak and rumble candidates are not forest-specific (rope tension, spacecraft hull, thunder). Audition.
- No model tri counts for most trees; only two entries report them. Measure after insert, with `Part` count and
  `MeshPart` triangle counts in Studio, before committing to a forest density.
- Several tree listings come from one bulk-uploader account (`Content Deleted - 158552482`). Re-scan every model
  for scripts, `Decal`s or `SurfaceAppearance` before use, even where the listing says "No scripts".

## 4. Next steps

1. Studio writer auditions the four audio groups in a throwaway place, records plays or fails, loop seam and peak
   loudness for each id, and marks failures rejected here.
2. Insert only the top three tree ids into a throwaway place, scan for scripts and part count, and compare the look
   against the FK_ kit under the delivery D fog. Delete the throwaway afterwards.
3. Tune stalker distance bands by measuring the live map; the numbers in `wildbound-delivery-d.md` are hypotheses.
4. If a gap is unacceptable, the user decides on uploading their own licensed files. Nothing has been uploaded on
   the user's behalf.
