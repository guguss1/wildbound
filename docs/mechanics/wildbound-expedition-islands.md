# Wildbound expedition islands: relief, sleeping nests and the first minute (design)

Status: design only, nothing built. Every number is a hypothesis to tune in play, in the same sense as `wildbound-guardian.md` and `wildbound-delivery-d.md`. Player-facing words are neutral Spanish and will live in `ReplicatedStorage.WildboundText`; code, docs and commits stay English. Coordinates are studs, origin at the map centre, x east, z south, as in `forest-layout-v1.json`.

Sources read: `odd/tasks/wildbound-capture-extraction-horror.md` (deliveries A to D, the dread pass), `docs/mechanics/wildbound-delivery-d.md`, `wildbound-extraction.md`, `wildbound-guardian.md`, `wildbound-economy-p0.md`, `wildbound-capture.md` (spawn slots, egg carry), `wildbound-world.md`, `wildbound-creature-night-profiles.md`, `docs/maps/wildbound-p0.md`, `assets/maps/forest-layout/forest-layout-v1.json` and `hide-spots-v1.json`, `tools/build-wildbound-p0-map.luau`, `tools/build-species-rigs.py` (species list), and in `src/wildbound`: `WildboundLumipolWild.luau` (slots), `WildboundAmbush.luau` (anchors), `WildboundTutorial.luau`, `WildboundWorld.server.luau` (guardian height and movement), `WildboundServer.server.luau` (creature ground height), `WildboundCaptureSession.luau`. The shared knowledge index (`roblox-codex-starter/knowledge/INDEX.md`) holds one video note (DLWYPHMGfMs); its "first minute: reward early, show an upgrade, show the promise" advice is used here as a hypothesis to test, not a requirement.

## What the user asked for

"Add some relief to the map, not too much. More fun, more of an expedition: you walk and find different islands of creatures that are sleeping, and you steal their baby creatures, which is scarier. La Silueta should look big, chase you and scare you. Right from the start there should be a reward that makes you stay." Earlier direction still holds: Steal-an-Egg-like clarity, live capture 70 % and eggs 30 %, La Silueta can kill, near-blind foggy nights, a giant Silueta, sprint with a cost, one carried creature at a time back to camp.

## The loop in one paragraph

Leave camp, follow the lit lanterns, crest a low rim and look down into an island: a flat hollow with a glowing nest, a cría in it, and its parents asleep around it. Walk in without running and without shining your light in their faces, lull the cría with the calm ring and take it with the seal tap. Carry it home in the capsule: sprinting frightens it, and a frightened cría cries. If the parents wake, their scream carries through the forest and, near La Silueta's territory, brings it. Register the cría at the refuge: it is yours forever, it goes on display, and the board shows the next, deeper island and its rarer species.

## Decisions for user review

| ID | Decision |
| --- | --- |
| EI-1 | Relief is built from anchored parts (ridge segments: two `WedgePart` slopes, one `Part` crest, wedge end caps) in a new `WildboundP0.Relief` folder, not from Roblox Terrain. See section 1 and open question 3. |
| EI-2 | Relief is low: at most 10 studs above the floor outside the guardian's territory, at most 6 inside it; walkable everywhere (at most 20 degrees); the route at most 6 degrees; island floors, camp, hide spots and slots flat. |
| EI-3 | Five islands at rising risk (section 2). They replace the wandering `L1` to `L4` slots and the egg slots `E1` to `E3`: each island nest holds a cría (70 %) or an egg (30 %). Live capture becomes "lull and take the cría"; the egg becomes the nest's other content. The `S0a`/`S0b` clearing becomes island 1. |
| EI-4 | Waking is decided by one shared sleep meter per island ("inquietud"), fed by sprint, proximity, light on faces at night and capture mistakes. Walking is silent, as in DD-5. |
| EI-5 | Default wake response (a): the adult screams; the scream is a guardian noise (`scream`) that brings La Silueta inside its territory and makes it stalk the territory edge outside it. Adults never hurt anyone. Alternative (b) in section 2. Open question 1. |
| EI-6 | A carried cría cries when its capsule mood is `afraid` (B-6) or in the 6 s after its island woke: a `cry` noise every 6 s. This deliberately changes B-6 and D-D1 ("carrying adds nothing to what La Silueta senses"). |
| EI-7 | No new currency. The first-minute reward is paid in Ember (existing), plus the first creature on display (existing), plus one cheap first upgrade ("Farol tapado"). |
| EI-8 | La Silueta's territory, leash (80 around (0, -85)), clamp, fair-strike gates and camp safety are unchanged. Islands 4 and 5 are inside the territory; islands 1 to 3 are not, so La Silueta can only be seen, heard or stalk the edge there. |
| EI-9 | One scripted-feeling but fair first sighting: La Silueta walks to a crest inside its territory, 51 studs from island 2 (69 since IW-5 moved the island), stands, looks, and walks down out of sight. It is a patrol variant: it never attacks from it and acquires only by the normal rules. |
| EI-10 | New species for islands 2 to 5 use the existing exported rigs (`assets/exports/species`, not uploaded). Until an upload is approved they are primitive stand-ins with the species' colours and name (H4 pattern). Lumipol stays the tutorial species. |

## 1. Terrain relief

### Numbers

| Rule | Value | Why |
| --- | --- | --- |
| Highest crest, outside the territory | 10 studs above the floor top (Y 0.5 to 10.5) | Twice the 4.9-stud avatar: a crest hides a whole player and the next lantern, not the 17-stud Silueta |
| Highest crest, inside the territory | 6 studs | The world server refuses a target more than 8 studs above or below the guardian (`targetContext`, `math.abs(position.Y - guardianPosition.Y) > 8`). With ground at most 6 apart, relief alone never trips that gate; it stays a "different floor" rule |
| Typical ridge | 4 to 8 studs | Hides a player (eye height 3.7) from a player or guardian at the same base height |
| Hummocks | 2 to 3 studs | Texture, cover for a crouching cría, not a sight wall |
| Steepest walkable slope | 20 degrees (run at least 2.75 studs per stud of rise) | Players and the guardian walk everything; no cliffs, no traps, no fall damage |
| Route grade along the centerline | at most 6 degrees (a 4-stud rise needs 38 studs of run) | Keeps the carry and egg speeds honest; the economy simulator's distances barely change (cos 6 degrees = 0.995) |
| Route cross slope | at most 3 degrees across its 14-stud width | The path parts stay readable and no one slides off the edge |
| Island floors | flat within the floor radius (at most 3 degrees, at most 0.5 stud of rise) | The capture ring, the 8-stud vertical cancel (`TOO_FAR_VERTICAL`) and the client ring's ground raycast (2.5-stud tolerance) assume flat ground |
| Camp and shelter safe circles (35 and 22 studs) | flat, no relief part inside plus 3 studs | Spawn clearance, station bases and the camp map test stay valid |
| Hide spots, gather, egg and nest slots | flat within 5 studs | Hide anchoring and discovery are horizontal rules |
| Relief part budget | at most 250 parts | The dread pass took workspace parts from 812 to 962; a triangulated heightfield would cost 600 to 1,400 wedges |

There are no hollows below the floor: the `Floor` part is 1 stud thick with its top at Y 0.5, and digging would need Terrain or a new floor. A "hollow" here is a flat floor ringed by raised rims, which reads the same from the inside.

### How it is built (EI-1)

The map is part-based, built detached by `tools/build-wildbound-p0-map.luau`, and its rules say the builder "never alters Terrain". So relief follows the same pattern as `buildCamp` and `buildHideSpots`:

1. `tools/plan_relief.py` (new) writes `assets/maps/forest-layout/relief-v1.json`: a list of ridge segments, each `{id, a: [x, z], b: [x, z], height, crestWidth, slopeDeg, capA, capB}`. A ridge is a straight trapezoid prism; a curved ridge or an island rim is a chain of segments. The planner owns every rule in the table above and reads the route, safe circles, slots, hide spots, trunk cores and island floors from the existing JSON.
2. One shared height rule: `heightAt(x, z)` is the maximum, over segments, of the trapezoid profile at that point (0.5 outside every segment). It is written twice, in Python (planner) and in a pure Luau module `src/wildbound/WildboundRelief.luau`, and the planner exports 64 golden sample points that the Luau test must match within 0.01 studs.
3. `Builder.buildRelief(root)` builds `WildboundP0.Relief` from an exported `ServerStorage.WildboundReliefLayout` (generated by a new `tools/export_relief_luau.py`, same pattern as the forest layout). Each segment is two `WedgePart`s (the slopes), one `Part` (the crest) and up to two wedge end caps: about 3 to 5 parts per segment. Anchored, `CanCollide` on, `CanQuery` on (so ridges block La Silueta's sight ray, which raycasts against everything queryable), `CanTouch` off, grass material and the ground palette, wedges overlapping by 0.05 stud so no seam catches a foot. It refuses a second build and patches a dressed live map once.

Alternative, Roblox Terrain (`Terrain:FillBlock` or `WriteVoxels` from the same height rule): smoother, cheaper in instance count, and the navmesh treats it natively; but it breaks the builder's "never alters Terrain" contract and its detached, removable-root pattern, is not part of the `WildboundP0` model that backups and exports carry, reads less low-poly than the forest kit, and is harder to assert in fresh-clone tests (voxel reads instead of part properties). Open question 3.

### Where the relief goes (candidates the planner moves to meet the rules)

| Feature | Centre (x, z) | Height | Role |
| --- | --- | ---: | --- |
| Rim of island 1, "Loma del Claro" | ring around (-95, 75), floor radius 14 | 3 | The reveal: you crest it and look down into the sleeping nest |
| "Loma Larga" | (-10, 70), 60 long, east to west | 10 | Outside the territory, between the east and west routes: the camp to shelter walk loses its sight lines |
| Rim of island 2 | ring around (-20, 15) (IW-5; was (-27, 0)), floor radius 16, wholly outside the territory | 4 | Hollow next to the fog edge |
| "Cresta de la Vigía" | (5, -40), 40 long, east to west | 6 | Inside the territory (45 from home), 51 from island 2 (69 since IW-5): the first-sighting crest (section 4) |
| Hummocks of the marsh | around (115, 15) | 2 to 3 | Low cover around island 3 |
| Rim of island 4, around the ruin pillars | ring around (35, -99), floor radius 16 | 5 | Two entrances, on the route |
| Rim of island 5 | ring around (60, -135), floor radius 16 | 6 | One entrance only: one way in, one way out |
| Saddle on the clearing to ruin leg | around (-35, -25) | 4 | The route climbs at 6 degrees and drops into the fog |

### What must be re-checked, and how

| Item | Today | With relief | Check |
| --- | --- | --- | --- |
| Route walkability | Flat 14-stud path parts at Y 0.55 | Path parts follow the ground: one part per run of constant grade | Planner: grade and cross slope; Play: walk the loop at 16, 14 and 11 studs/s |
| Trunk cores (D-C1) | 14-stud cylinders based at Y 0.5 | Based at `heightAt` minus 1 at the tree's pivot, still 14 above local ground; trees on a slope over 12 degrees are moved or removed by the planner | Dress test: every pivot within 0.2 of `heightAt`; cores reach 14 above ground; route clear 14 studs |
| Prop pivots | `(x, 0.5, z)` | `(x, heightAt(x, z), z)`; logs only where the slope is at most 6 degrees | Dress test |
| Hide spots | 10 spots, flat ground | Must stay on flat ground; the one spot already 9.0 studs from a grown core (DP-7) is re-checked | `tools/test_plan_hide_spots.py` |
| Guardian movement | Anchored model moved at constant `home.Y`; each step sphere-casts against colliding parts and slides when blocked | Each step sets Y from `heightAt` plus the body offset, and the obstacle cast excludes the `Relief` folder (a rising slope would read as a wall) | Path test: step height follows relief; Play: repeat the C2 measurement (14 investigate legs, stalls 0) |
| Guardian navmesh | `PathfindingService` (agent radius 2, height 7, no jump, no climb) over the floor and trunk cores | Relief parts collide, so the navmesh includes them | Play: plan a path from home to every island floor and crest; status `Success`, waypoints rise with the ground. Navmesh slope limits are not measured here and must be read in Play |
| Creature placement | One `groundY` from the clearing marker for every creature | Each creature, nest and egg at `heightAt` of its own position | LumipolWild and island tests |
| Capture ring | Ground raycast within 2.5 studs of the expected height | Island floors flat | Island planner: floor flatness |
| Camp | Flat disc, stations, spawn clearance | No relief inside the circle plus 3 studs | P0Map test unchanged and green |
| Nest sight lines | E and N open, S and W blocked by pillars, eye height 3.7 | Eye height measured from local ground; the island 4 rim must not block E and N | ForestDress sight contract re-run |
| Lanterns | "No lantern reveals more than the next" | A crest can hide the next lit lantern | Planner: the camp-exit lantern `FK_LanternMarker_012` visible from spawn at eye height |
| Economy simulator | Straight distances | Nearly unchanged (grades at most 6 degrees) | Full Python run, invariants unchanged |

### How relief adds dread

- Sight lines break over crests. A ridge of 4 to 8 studs hides a player completely from anyone at the same base height, so cover is everywhere without more trees, and La Silueta loses you over a crest (its sight ray hits a queryable ridge, which the hunt already reads as `Brain.lostSight` and Search).
- La Silueta is silhouetted on crests. Its art is 17.1 studs tall; standing on a 6-stud crest it rises 23 studs above an island floor. By day the mist hides trees from about 60 to 80 studs and the giant from about 110 to 140, so a crest at 50 to 70 studs is the sweet spot: a dark shape against pale mist. At night only its pale eyes show past about 48 studs.
- Footsteps come over the hill. Roblox sound has no occlusion by default, so the giant steps (roll-off to 150 studs) are heard from behind a crest before anything is seen; this is the "heard, not seen" effect of DP5 with a reason for it.
- Rims make arrivals readable. Cresting a rim is the moment you see the nest, and the moment the adults could see you if they woke.
- One-entrance hollows (island 5) mean the way out is the way you came in.

## 2. Creature islands

### The five islands

Path distances are measured along the route from the spawn point (-140, 150) at 16 studs/s, plus the off-route walk; the route is about 798 studs in a loop.

| # | Name (player-facing) | Theme | Centre | Zone, tier | From spawn | Species (stand-in until approved) | Adults asleep | Wake radius day / night |
| --- | --- | --- | --- | --- | --- | --- | ---: | --- |
| 1 | Claro de los Lumipol | Sunny clearing, soft glow, the tutorial | (-95, 75), existing `S0a` | Outside the fog, Safe | 88 studs, about 6 s | Lumipol (existing) | 2 | 12 / 15 |
| 2 | Hondonada del Musgo | Mossy hollow at the fog edge | (-20, 15) (IW-5; was (-27, 0)) | Fog, outside the leash (102 from home; the floor keeps leash + ATTACK_RANGE, 87) | about 206 studs, 13 s | Cortezón (mossy shell) | 2 | 16 / 20 |
| 3 | Pantano de los Juncos | Reed marsh, pale water, no Silueta | (115, 15), near `L4` | Fog, outside the leash (158 from home) | about 366 studs east, 23 s (450 west) | Cestillo (long-necked wader) | 3 | 18 / 22.5 |
| 4 | Ruinas del Nido | Ruin pillars around the old nest | (35, -99), the nest `E1` | Territory, 37.7 from home | about 311 studs west, 19.5 s | Polvilla (dusty moth) | 3 | 20 / 25 |
| 5 | Corazón de la Niebla | Deepest bowl, ember glow | (60, -135), near `E3` | Territory, 78 from home | about 355 studs, 22 s | Tizoncillo (glowing ember log) | 4 | 22 / 27.5 |

Islands 3 and 4 are a route choice, not a strict order: the marsh is the long road with no Silueta, the ruins are the short road through its territory. That is the expedition decision the old map lacked. Island 5 sits at the leash edge, so it is the deepest and most exposed.

Each island floor is cleared of trees by the island planner (listed tree ids are removed from the dress layout, the same way `thicken` keeps avoid circles), keeps 14 to 18 studs of flat floor, and has a hide spot 25 to 45 studs away (islands 4 and 5 already have H01 and H07 in range).

### Anatomy of an island

- A nest at the centre: a glowing bed with the cría (or an egg) in it, visible from the rim. Clarity first: the cría glows teal, the egg pale gold.
- Adults asleep 5 to 8 studs around the nest, facing out, with "Zzz" over the island (one shared readout, not one per adult).
- One sleep meter per island, "inquietud", 0 to 100, server-owned. Shown over the nest as three Z pips that turn amber at 40 and an "!" at 100, visible from the wake radius plus 20 studs.
- Nest content by player count: 1 cría or egg per nest (2 nests at islands 3 to 5 with 3 or more players). Respawn 45 s (30 s with 5 or more players), eggs 60 s (40 s), as the slots today.

### The stealing loop

1. **Approach.** Walking is silent. Inside the wake radius, these raise the meter:

| Input | Meter | Notes |
| --- | ---: | --- |
| Walking within 6 studs of a sleeping adult | +6 per s | You can pass, not linger |
| Sprinting inside the wake radius | +45 per s | About 2 s from asleep to awake |
| A `sprint` noise event (every 1.2 s, DP1) whose radius reaches the island centre | +25 per event | So sprinting nearby wakes it too |
| Facing a sleeping adult within 12 studs at Dusk or Night (server forward vector, dot at least 0.85), the flashlight on its face | +10 per s, +5 with "Farol tapado" | You need light to see; light disturbs them. No camera or gaze input, as the reveal ability |
| Lulling the cría (calm ring active) | +3 per s | |
| Leaving the ring (`LeftRing`) or a failed session | +25 once | |
| Missing the seal (`SealMissed`) | +35 once | The cría squeaks |
| Taking an egg, or a granted cría capture (fear pass, `GRAB`) | +45 once (an egg was +30; a cría added nothing) | The grab itself is loud: a careful thief on a calm island keeps it asleep, a sloppy one (mistakes, lingering by an adult) wakes the parents the moment the cría is lifted |
| Entering a hide spot inside the radius (`rustle`) | +10 once | |
| Decay | -8 per s after 2 s with no input; -20 per s with nobody inside the radius | |

At 40 the island stirs: an adult lifts its head, the pips go amber, a sigh plays, and the HUD says "Shh... se están despertando." At 100 it wakes. Island 1 halves every input and, during a player's first steal, cannot pass 95 unless that player sprints (safe-ish, but sprint still teaches its cost).

Worked cases: a careful approach and a clean 5 s lull add about 6 x 3 + 3 x 5 = 33 (asleep); one ring mistake and a clean retry about 73 (stirs, then decays); two mistakes, or 3 s of light in a face at night plus one mistake, wake it; sprinting in wakes it in about 2 s.

2. **Take.** The prompt "Tomar la cría" (10 studs, the capture keys) starts the existing capture session on the cría: the calm ring (H1, A-4 windows; island 1 uses the Gentle windows) and the seal tap. A failed lull makes the cría run behind the nearest adult (the A1 flee and hide, with the adult as cover) for the 6 s retry wait. The egg prompt is "Tomar el huevo" (hold 1 s, no ring, the existing egg pickup).

3. **When an adult wakes, default (a), EI-5.** The adults stand and one screams for 1.5 s (visible cue: head up, mouth open, ring of dust; sound from the catalog's creature cues until a scream is chosen). The island is "Alerta" for 30 s: the nest closes (prompt hidden, "El nido está vigilado. Vuelve más tarde."), the cría sits between the adults, then they lie down again with the meter at 30. The scream is a guardian noise, kind `scream`, base radius 70, times the zone tier and the phase's hearing like every other noise (territory at night 70 x 1.4 x 1.3 = 127 studs; fog by day 70 x 1.0 x 0.8 = 56):
   - Inside the territory (islands 4 and 5): full strength within half the radius, so La Silueta investigates the island, and hunts whoever it sees there.
   - Outside the territory (islands 2 and 3): its goal is clamped to the territory, so it walks to the nearest territory edge point toward the island and stalks there for 10 s, visible on the crest or at the fog line, and cannot cross. That is a scare with no strike.
   - Island 1: too far (186 studs from home); the adults only shoo you and the nest reopens after 8 s.
   - If you already carry the cría when they wake, the scream still fires at the island and your cría cries for 6 s (EI-6).
   - Adults never chase, strike or take anything. A strike can still only come from La Silueta, through every fair-strike gate.

   Alternative (b): the woken adult itself chases you (a short sprint, a telegraphed lunge) and takes the cría back on a hit, with no damage. Pros: immediate, local and readable; works on islands where La Silueta cannot reach. Cons: a second hostile AI per species with its own pathing, telegraph and fair-strike path; it competes with La Silueta as "the scary thing"; it makes the species you collect into enemies; more server cost per island. (a) reuses the noise pipeline (`GuardianNoise`, `Brain.NOISE`) and keeps one killer.

4. **Carry.** The cría rides in the existing carry slot (B1): one at a time, capsule on the back, carry speed 14, ward rules unchanged, lost on defeat unless warded. Sprinting frightens it until it slips free (DP1, unchanged). It cries (EI-6): a `cry` noise, base 18, every 6 s while its capsule mood is `afraid` (La Silueta hunting within 40 in the fog) and for 6 s after its island woke; the capsule shakes and the HUD says "La cría llora. ¡Algo la escucha!". Hiding with a crying cría widens the discover radius by 2 studs (this answers delivery D's open question 1). Eggs do not cry; they slow you more (egg speeds 11, 10, 9).

5. **Extract.** Unchanged from delivery B: register at the refuge ("Registrar criatura", key V), card, Ember, display spot, equip. The card's first line becomes "¡Nueva criatura!" or "¡Nueva especie!" the first time a species is registered. Eggs go to the chest and then the incubator (delivery E, unchanged).

### Relation to live Lumipol capture and planned eggs (EI-3): merge

| Today | After |
| --- | --- |
| Wandering adult Lumipol at `S0a`, `S0b` (Safe, first capture only) | Island 1 nest. The first-capture rule stays: the clearing gives only your first cría ("En el claro solo se toma la primera cría. Busca más adentro."), which pushes you deeper |
| Wandering Lumipol at `L1` to `L4` with the A1 brain | Retired as spawn slots; the A1 brain is reused for the cría's flee and hide during a failed lull |
| Calm ring plus seal (H1) | Unchanged; it is now the lull. Capturer skills (H2) still apply |
| Egg slots `E1` to `E3`, egg pickup | Retired as slots; an egg is the other nest content |
| 70 % live / 30 % eggs (user) | Each nest respawn rolls cría 70, egg 30 by one server `Random` (one weight table, no stacked multiplier, as the spawn rules). Island 1 always holds a cría. Rewards earned only through play need no odds disclosure (economy doc); recheck if that changes |
| Delivery E (special egg and incubator) | Unchanged in shape; its egg now comes from a nest |

### Reward per island tier

Ember is paid at the refuge (crías) or the chest (eggs), once, by the tier stored on the item at the steal, as today. These replace the Lumipol rows of the economy table and must pass `tools/simulate_economy.py` (180 to 480 s targets) before they are real.

| Island | Tier | Cría | Egg | Also |
| --- | --- | ---: | ---: | --- |
| 1 Claro | Safe | 6 Ember, plus 4 once for the first steal | none | First creature on display, first-extraction seal (existing) |
| 2 Hondonada | Fog | 10 | 8 | New species entry (Cortezón) |
| 3 Pantano | Fog, far | 12 | 10 | New species entry (Cestillo) |
| 4 Ruinas | Territory | 16 | 12 | New species entry (Polvilla) |
| 5 Corazón | Territory, heart | 22 | 14 | New species entry (Tizoncillo); its cría spawns only at Dusk and Night (an egg by day). A spawn rule, not a reward multiplier |

Duplicates pay the same, as today. A new species registration is the progression beat: entry, display, and the board naming the next island.

## 3. First-minute hook

### Timeline (targets to measure, not promises)

| Time from Play | What happens | Built on |
| --- | --- | --- |
| 0 to 5 s | Start screen "Jugar"; spawn at (-140, 150) facing the camp exit; the lit lantern `FK_LanternMarker_012` (26 studs away) and island 1's nest glow beyond it | Start screen, DP3 lanterns |
| 5 to 15 s | Tutorial card "1/3 Sigue los faroles hasta el claro."; walk 88 studs (about 6 s) | `WildboundTutorial` |
| about 15 s | Crest the 3-stud rim: two sleeping Lumipol and a glowing cría below. Card "2/3 Acércate sin correr y toma la cría." | Relief, island 1 |
| 15 to 45 s | Walk in, lull (Gentle windows, about 4.5 s) and seal: the first cría is in the capsule | Capture session (H1) |
| 45 to 60 s | Walk 88 studs back at 14 (about 6 s) while one adult sighs and rolls over behind you (it cannot wake); card "3/3 Llévala al refugio y regístrala." | Island 1 cap at 95 |
| 60 to 90 s | Register: "¡Nueva criatura!", +6 Ember, +4 "por tu primera cría", the cría appears on display spot 1, "Equipar" | Refuge card, display (B3, B4) |
| 90 to 120 s | The board glows: first upgrade "Farol tapado" for 10 Ember (affordable now): "Tu linterna molesta menos a las criaturas dormidas." The card's last line teases: "Próxima isla: Hondonada del Musgo. Allí duermen los Cortezón." | Board (B4), economy |

First steal by 30 to 45 s, first registration under 2 minutes, a first purchase right after, and a named, deeper promise. The first trip is also what turns lethality on (D-C3: no one can be killed before their first paid trip home), so the first sighting on island 2 happens just after the game becomes dangerous.

### Changes to the current start flow

- `WildboundTutorial.STEPS` today is English gather, extract, craft. It becomes the three Spanish steps above (deliberately changed pins in `WildboundTutorial_Test`), with "¡Es tuya! Más adentro duermen criaturas más raras." as the done text. Gathering moves to the board's later hints.
- The refuge card gains a "next island" line (the next island whose species the player has not registered).
- Analytics gain `first_steal` and `island_reached`; the funnel gains "first steal within 60 s" and "first registration within 120 s" so the hook is measured, not assumed.
- "Farol tapado": 10 Ember, no materials, once, halves the light input (and lowers the local beam slightly). It must be added to the economy JSON and pass the simulator.

## 4. La Silueta on the expedition

### Moments

| Moment | Rule | Fairness |
| --- | --- | --- |
| Footsteps before sight | Unchanged DP5: steps from Distant (within 120 studs), roll-off 150; over a crest you hear before you see | Information, never a strike |
| First sighting on a crest (EI-9) | When a player who has registered at least one creature comes within 60 studs of island 2, La Silueta is in Patrol, and nobody was hunted in the last 20 s: it walks (investigate speed) to the crest point (5, -40) of "Cresta de la Vigía", stands 3 s facing the player, then walks down the far side, out of sight. Once per player per session; later, 25 % per island 2 visit by Day or Dusk | The crest is 51 studs from island 2 (69 since IW-5), beyond every detection radius (26, 32, 38), and it acquires only by the normal sight rules. No attack from a show; threat level Distant |
| Edge stalk | A scream at islands 2 or 3 clamps its goal to the territory edge; it stands visible for 10 s, then returns | It cannot cross the clamp |
| The hunt | Islands 4 and 5: a scream brings an investigation, then the normal Alert, Hunt, Telegraph | All fair-strike gates; hunt speeds 7 to 10 stay under the carry speed 14 |
| Relief | A chase breaks over a crest (queryable ridge), then Search 6, 9 or 12 s | Existing `lostSight` and Search |
| Quiet after pressure | No show for 20 s after a Retreat | Tension and recovery pacing |

### Scaling with depth and night

| Island | La Silueta | Night |
| --- | --- | --- |
| 1 | Never present (186 studs from home) | Wake radius x 1.25; nothing else |
| 2 | First sighting; scream: edge stalk | Only its eyes show on the crest |
| 3 | Out of reach; distant steps may carry from the territory | Adults sleep lighter (radius x 1.25); a long walk home with a crying cría |
| 4 | Patrol passes 37.7 from the nest; scream: investigation and hunt | Hearing x 1.3 already; detection 38 |
| 5 | Ambush anchors `NestSide` (40, -125) and `SouthGrove` (40, -140) are within 25 studs; scream: investigation, then Search | Crías only at Dusk and Night; the deepest reward costs the darkest walk |

Nothing here raises La Silueta's speeds, detection, damage or leash, so the delivery C economy and fair-strike results stand.

## 5. Tasks (strict TDD)

Each task: write the test, run it against an empty stub (Luau in a temporary `ServerStorage` folder; Python with no output file) to observe RED, implement to GREEN, add Luau pairs to `tools/deploy_manifest.py` and its test, run the full fresh-clone Studio suite and `python -I -B -m unittest discover -s tools -p "test_*.py"` (the one known failure allowed), commit by exact path. Luau tests follow `tests/WildboundXxx_Test.luau` with `case("Rn: ...")`. Studio edits need the instance and place verified read-only and confirmed first. About 400 authored changed lines per task is a planning heuristic only.

### Relief first

- **R1 Relief planner.** `tools/plan_relief.py` writes `relief-v1.json`. `tools/test_plan_relief.py`: `test_crest_at_most_10_outside_and_6_inside_territory`, `test_every_slope_at_most_20_degrees`, `test_route_grade_at_most_6_and_cross_slope_at_most_3`, `test_island_floors_flat`, `test_no_relief_in_safe_circles_plus_3`, `test_hide_spots_and_slots_on_flat_ground`, `test_part_budget_at_most_250`, `test_camp_exit_lantern_visible_from_spawn`, `test_golden_samples_written`.
- **R2 Height rule.** `src/wildbound/WildboundRelief.luau` (`heightAt`, `slopeAt`) and `tools/export_relief_luau.py` (with `tools/test_export_relief_luau.py`: `test_export_round_trips_segments`). `tests/WildboundRelief_Test.luau`: "R2: heightAt matches the planner's 64 golden samples within 0.01", "R2: outside every segment is the floor top 0.5", "R2: overlapping segments take the maximum", "R2: no sample is steeper than 20 degrees", "R2: NaN, nil and huge input return 0.5".
- **R3 Builder.** `Builder.buildRelief(root)`. `tests/WildboundP0Map_Test.luau` additions: "R3: relief parts are anchored, collide and query, never touch", "R3: part count within 250", "R3: a downward ray hits each crest at heightAt within 0.1 (parked folder)", "R3: a second relief build is refused", "R3: camp stations still clear of every relief part".
- **R4 Dress and hide spots on relief.** `dress-wildbound-forest.luau` pivots and trunk cores at local ground; `plan_forest_layout.py` and `plan_hide_spots.py` read the relief. `tests/WildboundForestDress_Test.luau`: "R4: every prop pivot sits on heightAt within 0.2", "R4: trunk cores reach 14 studs above local ground", "R4: nest sight E and N still open and S and W still blocked at eye height above ground". Python: `test_trees_steeper_than_12_degrees_are_moved`, `test_logs_only_on_slopes_at_most_6`, `test_hide_spots_on_flat_relief`.
- **R5 Ground follow.** Guardian step Y from `heightAt`, the obstacle cast ignoring `Relief`; creature and nest visuals at their own ground. `tests/WildboundGuardianPath_Test.luau`: "R5: a step's height follows the relief", "R5: a rising slope is not a blocked step". A source contract (in a new `tests/WildboundReliefWiring_Test.luau`): "R5: guardian movement no longer uses home.Y", "R5: creature visuals no longer share one groundY". `tests/WildboundLumipolWild_Test.luau`: "R5: slot ground comes from the relief".
- **R6 Relief Play check.** Walk the loop at 16, 14 and 11; repeat the C2 navigation measurement (14 legs; stalls, failed plans, blocked steps); a path to every island floor and crest; a chase lost over a crest; frame time on desktop. Phones remain BLOCKED unless the Device Simulator can be switched.

### Then islands

- **I1 Island planner.** `tools/plan_islands.py` writes `assets/maps/forest-layout/islands-v1.json` (centre, floor radius, rim segments for R1, entrances, nest and adult positions, show crest, removed tree ids). `tools/test_plan_islands.py`: `test_five_islands_in_tier_order`, `test_island_one_within_100_studs_of_spawn_along_the_route`, `test_zones_match_world_rules` (1 outside the fog, 2 and 3 fog outside the leash, 4 and 5 territory), `test_floors_clear_of_trunk_cores_and_flat`, `test_hide_spot_within_25_to_45_of_each_island_past_the_first`, `test_show_crest_in_territory_and_45_to_60_from_island_2`, `test_show_crest_sight_corridor_has_no_trunk`, `test_removed_trees_listed_and_layout_under_95000_triangles`.
- **I2 Island rule.** Pure `src/wildbound/WildboundIsland.luau`: the meter inputs, stir and wake thresholds, decay, Alerta window, nest content roll with an injected random, respawn, the island 1 cap. `tests/WildboundIsland_Test.luau`: "I2: walking far from adults adds nothing", "I2: lingering by an adult adds 6 per second", "I2: sprinting inside the radius wakes within 2.5 s", "I2: light on a face counts only at Dusk and Night and is halved with the upgrade", "I2: a clean lull stays asleep", "I2: two mistakes wake it", "I2: decay starts after 2 s", "I2: stir at 40 and wake at 100, once", "I2: Alerta closes the nest for 30 s and resets to 30", "I2: island 1 never passes 95 for a first steal without sprint", "I2: nest roll is 70 cría and 30 egg over 10,000 seeded rolls within 1 %", "I2: island 1 always holds a cría", "I2: island 5 cría only at Dusk and Night", "I2: bad input changes nothing".
- **I3 Steal session.** The capture session takes a cría target; slots move to island nests. `tests/WildboundCaptureSession_Test.luau`: "I3: a cría session uses the island's windows", "I3: LeftRing and SealMissed report the meter penalty". `tests/WildboundLumipolWild_Test.luau`: "I3: active nests scale with players" and the deliberately changed `L1` to `L4` and `E1` to `E3` pins.
- **I4 Guardian noises and the show.** `Brain.NOISE` gains `scream` 70 and `cry` 18; a non-hostile `Show` goal. `tests/WildboundGuardianBrain_Test.luau`: "I4: scream radius is 70 x tier x hearing", "I4: a scream outside the territory clamps to the edge and stalks 10 s", "I4: cry radius", "I4: a show never enters Telegraph", "I4: a show is refused within 20 s of a Retreat".
- **I5 Carried cría.** `WildboundState` keeps a species and `stage = "Cria"` on the carried item; `WildboundCarry` gains the cry rule. `tests/WildboundCarry_Test.luau`: "I5: an afraid cría cries every 6 s", "I5: a calm cría is silent", "I5: a cría cries 6 s after its island woke". `tests/WildboundHide_Test.luau`: "I5: a crying cría widens discovery by 2". `tests/WildboundState_Test.luau`: "I5: species and stage survive register".
- **I6 Server wiring.** Island nests, meter, prompts, scream and cry into `GuardianNoise`, the show trigger. `tests/WildboundIslandWiring_Test.luau` (source contracts plus a Studio-only server probe like A-8): "I6: the meter is never read from a client", "I6: one player's noise wakes the island for everyone", "I6: the nest prompt hides while Alerta", "I6: the facing input uses the server forward vector only".
- **I7 Economy.** Island rows and "Farol tapado" in the economy JSON, regenerated `WildboundEconomyConfig`. `tools/test_simulate_economy.py`: `test_island_tiers_keep_expedition_targets`, `test_first_trip_pays_at_least_10_ember`. `tests/WildboundEconomy_Test.luau`: "I7: island tier Ember by tier", "I7: Farol tapado costs 10 Ember once".
- **I8 Island builder and words.** `Builder.buildIslands(root)` (nests, adult and cría stand-ins, sign keys); `WildboundText.ISLAND`. `tests/WildboundP0Map_Test.luau`: "I8: five nests at the planned centres on flat ground", "I8: island parts never query except the rims". `tests/WildboundText_Test.luau`: "I8: island words exist and are Spanish".
- **I9 Islands Play check.** Sleep, stir, wake, scream to edge stalk (island 2), scream to hunt (island 4), cry while hiding, carry and register a new species, two-player waking (probe).

### Then the hook

- **K1 Tutorial.** `tests/WildboundTutorial_Test.luau`: "K1: three Spanish steps claro, cría, refugio" (deliberately changed pins), "K1: step 2 completes on a carried cría", "K1: step 3 completes on the first registration".
- **K2 First reward and tease.** First-steal bonus and the refuge card's next-island line. `tests/WildboundRefuge_Test.luau`: "K2: the first card names the next unregistered island", "K2: the first-steal bonus is paid once".
- **K3 Measurement.** `first_steal` and `island_reached` events. `tests/WildboundAnalytics_Test.luau` and `tests/WildboundAnalyticsWiring_Test.luau`: "K3: first_steal once per session"; `tests/WildboundFunnel_Test.luau`: "K3: steal within 60 s and register within 120 s are funnel steps".
- **K4 Hook Play check.** Time from Play to the first steal, the first registration and the first purchase, measured three times from a fresh session.

## 6. Spanish words (neutral, for `WildboundText`)

| Key | Text |
| --- | --- |
| ISLAND.names | Claro de los Lumipol; Hondonada del Musgo; Pantano de los Juncos; Ruinas del Nido; Corazón de la Niebla |
| ISLAND.takeCria | Tomar la cría |
| ISLAND.takeEgg | Tomar el huevo |
| ISLAND.stir | Shh... se están despertando. |
| ISLAND.woke | ¡Te descubrieron! Su grito resuena en el bosque. |
| ISLAND.guarded | El nido está vigilado. Vuelve más tarde. |
| ISLAND.firstOnly | En el claro solo se toma la primera cría. Busca más adentro. |
| CARRY.cry | La cría llora. ¡Algo la escucha! |
| CARD.newSpecies | ¡Nueva especie! |
| CARD.next | Próxima isla: %s. Allí duermen los %s. |
| CARD.firstBonus | +4 Ember por tu primera cría |
| TUTORIAL.steps | 1/3 Sigue los faroles hasta el claro. / 2/3 Acércate sin correr y toma la cría. / 3/3 Llévala al refugio y regístrala. |
| TUTORIAL.done | ¡Es tuya! Más adentro duermen criaturas más raras. |
| UPGRADE.farol | Farol tapado: tu linterna molesta menos a las criaturas dormidas. |

## 7. Open questions (with the recommended default)

1. **When an adult wakes: (a) its scream calls La Silueta, or (b) the adult itself chases you?** Default (a): one killer, reuses the noise pipeline and the fair-strike path, and the creatures you collect stay creatures, not enemies.
2. **May the four existing species rigs (Cortezón, Cestillo, Polvilla, Tizoncillo, already exported in `assets/exports/species`) be uploaded for islands 2 to 5?** Default: yes, after you approve the upload; until then primitive stand-ins with each species' colours and name, so the islands can be built and tested now.
3. **Relief from parts (ridge segments) or from Roblox Terrain?** Default: parts, so the map stays one removable `WildboundP0` model built and tested like the camp and hide spots, with a 250-part budget and the low-poly look of the kit.

## 8. Not verified

Everything. No relief, island or hook exists. Not measured: the navmesh on slopes, wedge seams under a real character, frame cost of the relief on phones, whether 6-stud crests are enough to lose La Silueta in practice, whether the crest sighting reads at 51 studs in the day mist, the meter numbers' feel, the 30 to 45 s and 2 minute hook times, and the economy effect of the island rewards until the simulator runs them.

## Chase pass: lethal adults (2026-11-08)

User: "you can steal from the parents and they chase you and can kill you". This replaces the non-lethal part of decision EI-2 (the touch that only dropped the cria) and answers IW-4 (no wind-up). `WildboundIsland` and the inventory server; decisions CP-D5 and CP-A1 to CP-A3 in `odd/tasks/wildbound-capture-extraction-horror.md`.

| Step | Rule |
| --- | --- |
| Wake | The island screams as before; the nearest adult stands up for 0.6 s (`WAKE_WINDUP`) before it moves |
| Chase | 17 studs/s (was 16): faster than a walker (16) and a carrier (14), slower than a carrying sprinter (20.3); 10 s (was 7), leashed 35 studs from the nest |
| Swing | Within 3.5 studs it stops and rears for 0.8 s (`STRIKE_WINDUP`, 0.45 s until HF-T4): it rises and leans back, its eyes turn red, a crack sounds on it (catalog `crack`, played by the audio client from the adult's `Swing` attribute) and the thief reads "¡Va a golpearte! Apártate." |
| Hit | Lands only if the thief is still within 5 studs; then 1.2 s before the next swing, and the chase goes on |
| Effect | The cria drops and runs back to its nest ("¡Te alcanzó! La cría volvió a su nido."); 35 damage, so three hits kill; later hits read "¡Otro golpe! Aléjate del nido." |
| Gates | Damage only where La Silueta's strikes are real: `damageMode = "private"` on place 122652861404212 (`FairStrike.effectiveMode`) and a player past the first paid trip (`FairStrike.lethal`). Anywhere else, or before the first paid trip, a hit only drops the cria |
| Death | Through the ordinary defeat flow (`Humanoid.Died`): the carried creature is lost and the Spanish defeat summary shows |
| Island 1 | Unchanged first-steal cap (95, halved inputs): the first steal never wakes island 1, and a first-time player is never lethal anyway |

## Fear pass: faster parents and a loud grab (2026-11-08)

User: "scarier, faster; capturing must be an adrenaline rush; the parents chase you and hit you". `WildboundIsland` and the inventory server; task FA2 and the decisions in `odd/tasks/wildbound-capture-extraction-horror.md` ("Fear and adrenaline pass"). Every value is in the dev tuning panel (Islands).

| Step | Was (chase pass) | Now |
| --- | --- | --- |
| The grab (`GRAB`) | An egg +30; a granted cría capture added nothing | Both +45 once; island 1's first-steal cap (95) still holds |
| Wake (`WAKE_WINDUP`) | 0.6 s | 0.4 s |
| Chase (`CHASE_SPEED`, `CHASE_SECONDS`) | 17 studs/s for 10 s | 19 studs/s for 14 s: a walker (16) or a walking carrier (14) is caught; a carrying sprinter (20.3) gains 1.3 studs/s, and a sprint scares the carried cría (slip at about 3.4 s) |
| Swing, hit, leash, damage | 0.45 s tell, 5-stud hit, 35 studs, 35 damage | Unchanged (fairness floor 0.35 s) |

What a player now sees and hears is in the feature document (FA3): the shouts, the red edge, the hit's push and flash, the heartbeat and the roar.

## Fix pass FP5: the parents (2026-11-09)

Pure rules in `src/wildbound/WildboundIsland.luau`, wired in the inventory server; each has a tuning toggle (1 on, 0 off, all on by default) under Islas y adultos. Damage (35) and the leash (35) are unchanged.

| Behaviour | Rule |
| --- | --- |
| Pack call | The adults of an island share one sleep meter, so when one wakes the whole pack wakes at the same instant (`PACK_CALL_SECONDS` 0; the plan allows up to 10 s). Whether the pack should also join the chase is an open question for the user |
| Pounce | A thief within 8 studs (and outside the 3.5-stud strike reach) after 1 s of chase: the adult rears for 0.5 s (the swing's pose, eye colour and crack, plus "¡Va a saltarte encima! Esquívalo."), then leaps to the strike reach, never past the leash; the ordinary 0.45 s strike wind-up follows, so the leap itself never hits. Cooldown 6 s |
| Egg recovery | An egg dropped inside the leash (a first strike drops the newest bag item) is fetched by the nearest adult at return speed (8) and carried to the nest; when the adult picks it up the thief loses it ("Un adulto devolvió tu huevo a su nido."), and the nest takes it back if its slot is free. Never during a chase |
| Sleep cycle | Sleeping adults breathe on every client (0.15 studs, once per 3 s; 4.5 s in deep sleep). From 11:00 to 13:00 of the day cycle every wake input is x0.7 (the server marks the adults `Deep`) |

