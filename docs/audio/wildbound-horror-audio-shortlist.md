# Wildbound horror audio shortlist (delivery D)

Status: research only. Nothing here has been inserted, auditioned in Studio, or wired into the game. Every
candidate is a hypothesis to audition by ear before use.

## How this list was built

- Tool: Roblox Studio MCP `search_asset`, `scope=creator_store`, `assetType=Audio`, run on 2026-11-07.
- Studio instance: the `studio_id` in the brief (`81631061-...`) was no longer connected. The only connected
  instance (`7a269979-...`, place `122652861404212`) was used for read-only searches. No inserts, no edits,
  no Play, no uploads.
- Every asset id below was returned by `search_asset` with `isFree=true`. No id was invented or recalled
  from memory. Each candidate is marked "verified via search_asset".
- Not verified: that an id inserts or plays in this experience (the search tool warns some Creator Store
  assets may be restricted), the exact license text, loop seams, and loudness. The search result exposes
  none of these.
- Duration: taken from the result description when present. "not reported" means the search result gave no
  duration. The `verifiedCreatorsOnly` filter did not appear to filter (community uploads still came back),
  so creator trust is judged by name below.
- Source quality notes:
  - `ProSoundEffects` ("Courtesy of Pro Sound Effects") and `APMOfficial` ("Courtesy of APM Music") are
    professional libraries, published as free Creator Store audio. They are the preferred sources.
  - `DistrokidOfficial` is a music distributor account. Tracks are full songs with no duration reported and
    no descriptions. Not shortlisted for mood-critical layers.
  - Many community uploads are rips from other games or media (for example SCP, Alien Isolation, Half-Life,
    FNAF, Dead by Daylight, S.T.A.L.K.E.R.). They were excluded as a copyright risk.
  - "Loops" below means the description says "Loop" or the creator says loopable. Otherwise it is "not
    stated", and the seam must be checked by ear.

## Layer 1. Safe exploration

Soft wind, leaves, insects, mysterious ambient music.

### Wind and leaves

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9112777807 | Farmland Presence 1 (SFX) | ProSoundEffects | 36.0 s | Yes (description says Loop) | Evening wind through vines with light insects. Soft, bed-friendly. | Description lists "very distant traffic". Audition for a traffic hum and cut with EQ if audible. Siblings 9112777914 (36.0 s) and 9112778045 (42.3 s). Verified via search_asset. |
| 9112806209 | Jungle Dawn 2 (SFX) | ProSoundEffects | 46.0 s | Yes | Wind, rustling leaves, distant forest. Closest to "leaves" in this search. | Contains birds, frogs and a dove (daytime). Use at low volume or only in the neutral biome. Sibling 9112805925 (56.0 s). Verified via search_asset. |
| 8202539690 | Wind Ambience | s_onadow | not reported | not stated | Plain wind recording from a window. | Community upload. Verified via search_asset. |
| 159798309 | Nature Breeze | Stickmasterluke | not reported | not stated | Description: windy day, rustling leaves. | Old community asset. Verified via search_asset. |

### Insects

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9112810042 | Jungle Insects 1 (SFX) | ProSoundEffects | 56.0 s | Yes | Night ambience, constant buzz, light wind, distant birds. | The buzz is thick. Keep low in the mix. Siblings 9112810051 (56.0 s) and 9112810388 (99.9 s). Verified via search_asset. |
| 9117114084 | Night Jungle 6 (SFX) | ProSoundEffects | 36.0 s | not stated | Night jungle with crickets and a dense insect bed. | Distant animal calls are in the bed. Verified via search_asset. |
| 9114894498 | Jungle Insects 1 (SFX) | ProSoundEffects | 46.0 s | not stated | Close-up insects with a mild breeze, continuous. | Verified via search_asset. |

### Mysterious ambient music

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9046399990 | Elixir | APMOfficial | 131 s | not stated | "Instrumental ambient mix", shimmering guitar atmosphere. Calm and mysterious without a melody. | APM Bruton library (documentary and nature). Audition the loop point. Verified via search_asset. |
| 9114228148 | Eerie Tone Metallic Swirling Tone Tubular 2 (SFX) | ProSoundEffects | 83.7 s | not stated | Hollow, resonant tone. Works as a quiet mystery pad. | Leans creepy rather than safe. Better as a low-volume under-bed. Verified via search_asset. |
| 9043359885 | DARK DRONE 13 | APMOfficial | 49 s | not stated | Dark hanging drone, steady. | Darker than "safe". Use very low for the neutral biome. APM Epic Score, Horror Tools. Verified via search_asset. |

Found for this layer: 3 wind and leaves, 3 insects, 3 music.

## Layer 2. Distant threat

Branches snapping, occasional whispers, unsettling music.

### Branch snaps (one-shots, play at random intervals with spatial position)

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9120259118 | Tree Branches Breaking Snapping Cracking 1 (SFX) | ProSoundEffects | 1.5 s | No (one-shot) | Exactly the brief: breaking, snapping branches. | Best match found. Verified via search_asset. |
| 9114518080 | Foliage Movement 13 (SFX) | ProSoundEffects | 1.4 s | No | Light branch drop onto dirt, foliage rustle. A softer alternate. | Verified via search_asset. |
| 9113437465 | Big Thuds Wall Impact 1 (SFX) | ProSoundEffects | 1.0 s | No | Big thud on a large tree branch. A heavier "something is close" cue. | Verified via search_asset. |

### Whispers

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9125440130 | Choral Wind Eerie Vocal Whisper Wind Ghosts (SFX) | ProSoundEffects | 18.0 s | description says "Constant" | Eerie vocal, whisper wind. The best whisper-like asset found. | Sibling 9125440141 (18.0 s). Not clear speech, which suits the brief. Verified via search_asset. |
| 9125637123 | Magic Growl Eerie Tonal Swells Sporadic Rattle 5 (SFX) | ProSoundEffects | 20.1 s | not stated | Reverberant ghost and spirit swells. | Verified via search_asset. |

### Unsettling music

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9043359270 | DARK DRONE 06 | APMOfficial | 69 s | not stated | Dark hanging drone. Steady, no melody. | Verified via search_asset. |
| 9043360237 | METALLIC DRONE 03 | APMOfficial | 273 s | not stated | Metallic grinding drone. Long, so loop seams are rare. | Larger and harsher. Check for sustained high-frequency energy. Verified via search_asset. |
| 9114353534 | Evil Drone Deep Unsetting Rumbly Keening 2 (SFX) | ProSoundEffects | 18.5 s | not stated | Deep unsettling keening drone. | Short. Needs a crossfade loop. Verified via search_asset. |

Found for this layer: 3 branch snaps, 2 whispers, 3 music.

## Layer 3. Near threat

Strange breathing, monster footsteps, spatial sounds.

### Strange breathing

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9113586909 | Breathing Tone Eerie Soft 2 (SFX) | ProSoundEffects | 36.0 s | not stated | Soft, constant hollow exhales, pitched up, nightmarish. Non-human breathing. | Best match. Attach to the guardian as a 3D sound. Verified via search_asset. |

Gap: no second professional breathing asset was found. The remaining results were community uploads without
durations or clear provenance (for example 8258601662 "Breathing_Sound_Heavy" by Tipic_faker, 134336321560595
"breathing" by Aleidia). Several others were game rips and were excluded.

### Monster footsteps

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9114080709 | Dinosaur Footsteps Boomy Thumps 16 (SFX) | ProSoundEffects | 2.8 s | No | Boomy thump on a leafy surface, with debris rustle. Fits a forest. | Sequence several as step one-shots. Verified via search_asset. |
| 9114079718 | Dinosaur Footsteps Boomy Thumps 2 (SFX) | ProSoundEffects | 2.1 s | No | Quaking stomp, drier. | Others in the set: 9114081009 (2.1 s), 9114078783 (2.3 s). Verified via search_asset. |
| 9118239601 | Robot Footsteps 14 (SFX) | ProSoundEffects | 0.8 s | No | "Big thuds, steady walking, beast". Short and clean for a tight step rhythm. | Named "Robot", so audition for a mechanical tone. Verified via search_asset. |

### Spatial cues

No new asset needed. Reuse the branch snaps (Layer 2) and 9114106242 "Dirt Impacts 22 (SFX)", 2.3 s, ProSoundEffects
(dirt and wood hits with distant birds; verified via search_asset), positioned in 3D around the player.

Found for this layer: 1 breathing, 3 footsteps, 1 extra spatial one-shot.

## Layer 4. Chase

Intense music, fast steps, a signature Silueta sound.

### Intense music

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 1847568713 | Lurk In The Dark | APMOfficial | 96 s | No | "Dark dramatic timpani with escalation at 1:23". Percussive and rising. | Not a seamless loop. Start it from the top when the chase begins and fade out when it ends. Same title appears on other APM ids that report no description (1846266539 and others); this id is the one with a reported duration. Verified via search_asset. |
| 9114504259 | Flutter Pulse Constant 2 (SFX) | ProSoundEffects | 35.3 s | description says "Constant" | Rapid rhythmic pulse that can sit under music as a tension bed. | Sci-fi flavor. Use as a layer, not as the main track. Verified via search_asset. |

Gap: the search found no seamless horror chase loop. The APM titles "Tension Repeat Drones 29/30/23/12"
(1843867314, 1843867286, 1843866957, 1843736138) and "Deliberate Pain (Fast Bass)" (1837843534) have no
description or duration, so their length is unknown. They are listed as leads only, not as shortlist
entries, and need an audition.

### Fast steps

Gap: no professional-library fast footsteps were found. The community candidates below return no duration and
no provenance and are leads only.

| Asset id | Name | Creator | Duration | Loops | Notes |
|---|---|---|---|---|---|
| 74037897871795 | Footsteps Dirt Running Loop | Zeroolen83 | not reported | Name says Loop | Community upload. Verified via search_asset. |
| 135952279207329 | run_dirt | Regole_CKC | not reported | not stated | Community upload. Verified via search_asset. |

Alternative that needs no new asset: play the Layer 3 monster step one-shots at a shorter interval and a
higher pitch during chase.

### Signature Silueta sound

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9125440130 | Choral Wind Eerie Vocal Whisper Wind Ghosts (SFX) | ProSoundEffects | 18.0 s | description says "Constant" | An eerie vocal wind that reads as a presence. Choose a short slice. | Same asset as the whisper in Layer 2. Reusing it ties the signature to the whispers and keeps the sound identifiable. Verified via search_asset. |
| 9113586909 | Breathing Tone Eerie Soft 2 (SFX) | ProSoundEffects | 36.0 s | not stated | A hollow breathing tone, pitched. Distinct from every other sound in the game. | Alternative signature. Verified via search_asset. |
| 9125637123 | Magic Growl Eerie Tonal Swells Sporadic Rattle 5 (SFX) | ProSoundEffects | 20.1 s | not stated | Reverberant swells. | Verified via search_asset. |

Recommendation: pick one of these and use it only for Silueta, so the player learns it.

Found for this layer: 2 music, 0 confirmed fast steps (2 leads), 3 signature candidates.

## Layer 5. Hit and death

Short impact, an eerie stinger for a controlled jumpscare (no strobe, no volume spikes).

### Short impact

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9113525391 | Body Impact 1 (SFX) | ProSoundEffects | 1.6 s | No | Dull body slam. Reads as a hit without a sharp transient. | Verified via search_asset. |
| 9113551773 | Boom Thump Rattling Impacts Light Crunch 1 (SFX) | ProSoundEffects | 1.7 s | No | Low boom with a light crunch. | Verified via search_asset. |
| 9113437465 | Big Thuds Wall Impact 1 (SFX) | ProSoundEffects | 1.0 s | No | Short, heavy thud. | Verified via search_asset. |

### Eerie stinger

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9126006341 | Sting Striking Metal Spoke Rattling Clanking (SFX) | ProSoundEffects | 3.1 s | No | Stings category. Deep boom with reverberant decay, not a high-pitched screech. | Siblings 9126007790 (3.0 s) and 9126008048 (3.1 s). "Very Active" in the description of this one, so audition for a sharp peak. Verified via search_asset. |
| 9119640924 | Sting Striking Metal Spoke Rattling 1 (SFX) | ProSoundEffects | 3.0 s | No | Same family with a plainer description (no "very active"). | Verified via search_asset. |
| 9043355570 | ONE SHOT-LOW DRONE 05 | APMOfficial | 7 s | No | Low drone burst. Soft attack, long tail. | Lowest-risk stinger for the reduced-horror option. Verified via search_asset. |
| 9117318772 | Piano Rub Sting String Friction 2 (SFX) | ProSoundEffects | 16.5 s | No | Ghostly string friction. A slow, uncanny sting. | Long. Fade it out early. Verified via search_asset. |

Death/stinger safety: none of these have loudness data. Normalize each to a fixed peak, apply a fade-in of at
least 80 ms, and never layer more than one stinger at once.

Found for this layer: 3 impacts, 4 stingers.

## Layer 6. Creature

Small Lumipol chirps, plus a fear whimper.

### Chirps

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9118057295 | Rat Squeaks 8 (SFX) | ProSoundEffects | 1.9 s | No | Small, relaxed squeaks. Raise the pitch for a light chirp. | Pitch with `PlaybackSpeed` 1.3 to 1.6 or an equalizer. Verified via search_asset. |
| 9118057636 | Rat Squeaks 12 (SFX) | ProSoundEffects | 2.1 s | No | Same family, a calmer variant. | Verified via search_asset. |
| 88900663843974 | chirp chirp | DARKCLAW1203 | not reported | not stated | Literal chirp, description "something for an oc". | Community upload with no stated source. Verified via search_asset. |

### Fear whimper

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9118050871 | Rat Squeaks 6 (SFX) | ProSoundEffects | 1.6 s | No | Whining squeals; the tail turns loud and panicked. | Trim off the harsh screech at the tail. Verified via search_asset. |
| 9113717973 | Capucine Monkey 16 (SFX) | ProSoundEffects | 3.4 s | No | High-pitch distressed squeaks and squeals. | Reads as a monkey at normal pitch. Lower pitch or keep it quiet. Verified via search_asset. |

Gap: no clean "whimper" asset was found. The dog and puppy search returned monkey and horse-imitation sounds
only. Both candidates above are approximations. Do not use the tails marked "intense" and "screams".

Found for this layer: 3 chirps, 2 whimpers (approximate).

## Layer 7. UI and camp

Registration chime, campfire crackle, seal success and failure.

### Registration chime

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9116163448 | Key Dings Metal Clinking 9 (SFX) | ProSoundEffects | 1.7 s | No | Light metal jingle; description says "possible use: wind chimes". | Verified via search_asset. |
| 9116164628 | Key Dings Metal Clinking 6 (SFX) | ProSoundEffects | 4.2 s | No | Longer chime with more ring. | Verified via search_asset. |
| 1841772016 | Close to the Harp (sting) | APMOfficial | not reported (search filter confirmed 10 s or less) | No | Harp sting; warm and pleasant for a "registered" moment. | Verified via search_asset. |

### Campfire crackle

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9112780193 | Fireplace Constant Burning Flame 1 (SFX) | ProSoundEffects | 36.0 s | Yes (description says Loop) | Crackly, constant burning flame. | Fireplace rather than outdoor campfire, but crackle is close. Siblings 9112780438 (36.0 s) and 9112780462 (42.8 s). Verified via search_asset. |
| 236387093 | Fireplace Crackle | Jontizm | not reported | Yes (creator: loops perfectly, OGG) | Simple crackle bed. | Community upload from 2015 or earlier. Verified via search_asset. |

### Seal success and failure

| Asset id | Name | Creator | Duration | Loops | Why it fits | Notes |
|---|---|---|---|---|---|---|
| 9114826444 | Horse Harness Bells Small Metallic Ringing 1 (SFX) | ProSoundEffects | 5.5 s | No | Success: bright small bells. | Verified via search_asset. |
| 1841772016 | Close to the Harp (sting) | APMOfficial | not reported (10 s or less) | No | Success: a soft rising harp flourish. | Same asset as the registration chime option. Use a different one for registration if you want them distinct. Verified via search_asset. |
| 9043357191 | BASSBEND-Down 05 | APMOfficial | 7 s | No | Failure: a falling bass bend. Reads as "it slipped away" without a harsh buzz. | Verified via search_asset. |
| 9043355570 | ONE SHOT-LOW DRONE 05 | APMOfficial | 7 s | No | Failure: a soft low drone burst. | Verified via search_asset. |

Gap: no clearly-labeled UI success or fail sound from a professional library. Community UI results were
mostly rips from other games and were excluded.

Found for this layer: 3 chimes, 2 campfire, 2 success, 2 failure.

## Summary of coverage

| Layer | Needs | Found | Gaps |
|---|---|---|---|
| 1 Safe exploration | wind, leaves, insects, music | 9 | No dedicated "leaves" loop. Best is Jungle Dawn 2 with birds. |
| 2 Distant threat | branches, whispers, music | 8 | Whispers are an eerie vocal wind, not distinct whispering. |
| 3 Near threat | breathing, steps, spatial | 5 | Only one professional breathing asset. |
| 4 Chase | music, fast steps, Silueta signature | 5 | No seamless chase loop. No confirmed fast footsteps (two leads). |
| 5 Hit and death | impact, stinger | 7 | None. |
| 6 Creature | chirps, whimper | 5 | No true whimper. Both are approximations. |
| 7 UI and camp | chime, crackle, success, fail | 9 (3 reused) | No dedicated UI success or fail. |

## Mix plan

Design target: the player must always hear footsteps and the guardian cue before music. Music is a
supporting layer. All numbers below are starting points to tune by ear on phone speakers and headphones;
they are not measured. Volumes use Roblox `Sound.Volume` (0 to 1 scale, with 0.5 as a mid default) on a
single `SoundGroup` per layer so the whole layer can be ducked.

### Drivers by layer

| Layer | Driven by | Condition | Target volume | Behavior |
|---|---|---|---|---|
| 1 Safe exploration | Guardian state `Idle` or `Patrol`, distance beyond far range, no hit | Default | Wind 0.20, insects 0.12, music 0.15 | Looped beds, 4 s crossfade in and out. |
| 2 Distant threat | Guardian state `Alert`, or distance within far range and outside near range | Guardian roughly 60 to 120 studs away (tune to the map) | Music 0.20 (fades in as safe music fades to 0.08), snaps and whispers 0.25 | Snaps and whispers play at random 8 to 20 s intervals at a 3D position toward the guardian. |
| 3 Near threat | Distance within near range, guardian not yet chasing | Guardian roughly 20 to 60 studs away | Breathing 0.30, steps 0.35 (3D, rolloff 8 to 60 studs) | Breathing is parented to the guardian, so volume follows distance. |
| 4 Chase | Guardian state `Chase` (phase active) | Starts on chase begin, ends on loss of target | Music 0.35, fast steps 0.40, Silueta signature 0.30 once at chase start then every 12 to 20 s | Safe and distant music duck to 0 over 1.5 s. Chase music fades out over 3 s after the chase ends. |
| 5 Hit and death | Server-confirmed hit, then death | One-shot | Impact 0.40, stinger 0.35 | Stinger plays once per death with a 15 s cooldown. Duck all other layers 40% for 1.5 s. |
| 6 Creature | Server events for the equipped Lumipol (idle, scared, near guardian) | Idle chirps every 10 to 25 s, whimper when the guardian is in the near range | Chirp 0.20, whimper 0.20 (3D on the follower) | Whimper starts at the near range and stops on chase start so it does not stack with the Silueta cue. |
| 7 UI and camp | Registration, seal result, camp proximity | One-shots on UI events, crackle by camp distance | Chime 0.30, success 0.30, failure 0.25, crackle 0.25 (3D at the fire, rolloff 4 to 30 studs) | UI sounds are 2D. Crackle is silent outside the camp radius. |

The guardian-state names above are placeholders. They must be mapped to the game's actual states when the
audio controller is written. Distance bands depend on the final map scale and guardian speed, so measure
them in the live game before fixing numbers.

### Rules to keep the mix safe

- Duck order when layers overlap: hit/death over chase over near over distant over safe. A higher layer
  ducks lower layers; layers never add up past a master ceiling.
- Never start two stingers within 15 s. Never play the death stinger during an active chase fade-out.
- No strobe and no sudden spikes: every one-shot gets a fade-in of 50 to 100 ms. Normalize each asset to a
  similar peak before comparing volumes, because the library gives no loudness data. Keep any one-shot's peak
  at or below the chase music level.
- Do not pair a flash or screen shake with the stinger. If a visual accompanies it, make it a slow fade.
- Server decides state (guardian state, hit, death, seal result). The client only plays sounds from
  replicated state, so audio cannot be used to read hidden information or to spam events.
- Rate-limit all random one-shots on the client and cap concurrent `Sound` instances per layer (suggest 2
  for branch snaps and whispers).

### Reduced-horror option

A player setting (stored with the player's settings, client-side, applied on the client). Hypothesis to test,
not a requirement.

- Master horror scale: 0.6 of every volume above.
- Replace the death stinger with the soft `ONE SHOT-LOW DRONE 05` (9043355570) at 0.25, or no stinger.
- Chase music capped at 0.20, Silueta signature at 0.15, and play it once per chase only.
- Whispers off, near-threat breathing at 0.15, branch snaps kept (they help the player locate the threat).
- Hit impact kept (it carries gameplay information) at 0.30.
- Safe layer unchanged, plus a 2 s fade-in on every layer.
- Footsteps and guardian cues stay audible: reduced horror lowers dread, not information.

## Audition (delivery D, 2026-11-07)

Studio instance `7a269979-...`, place 122652861404212. Every id used by `src/wildbound/WildboundAudioCatalog.luau` was loaded with `ContentProvider:PreloadAsync` in Edit and again in the Play client: all 23 report `IsLoaded` true and a positive `TimeLength` (wind 36.0 s, birds 46.0, insects 56.0 and 36.0, safe music 131.2, night bed 48.6, unsettling 69.1 and 18.6, snaps 1.4 and 1.3, dirt 2.1, whispers 18.0, breathing 36.0, steps 2.0 and 2.0, chase music 97.0, pulse 35.3, hit 1.6, stinger 3.1 and 3.0, soft stinger 7.2, chirp 1.5, whimper 0.9). None is rejected. Peak `PlaybackLoudness` over the first 1.6 s at Volume 0.5 is recorded in `odd/tasks/wildbound-capture-extraction-horror.md`; it is not a full-length reading and nobody has listened. Loops and seams were not checked by ear.

## Next steps (written before the audition)

1. The Studio writer auditions the shortlist in a throwaway place or panel and records for each id: plays or
   fails, loop seam, peak loudness. Mark failed ids as rejected here.
2. If an id fails to insert (the search tool warns some may be restricted), take the next candidate.
3. For the gaps (seamless chase loop, fast footsteps, a true whimper, dedicated UI success and fail), either
   accept the approximations or have the user upload their own licensed files. Uploading needs the user's
   consent, the right to use the files, and Roblox moderation. Do not upload anything on the user's behalf.
4. Build a small audio controller that reads replicated state and applies this mix. Test on a phone before
   fixing the numbers.
