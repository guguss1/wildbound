# Owner task queue (from 2026-11-19)

Tasks the owner gave on 2026-11-19, to start on 2026-11-20, one at a time. This file records each task in the owner's words. It does not authorize anything beyond them.

Owner's words (verbatim): "te doy tareas para mañana, anotalas y resolvelas mañana. quiero que las nubes sean mas realistas, no una foto estirada, que la reina de caramelo se enoje y no te deje de perseguir cuando robas el huevo, que haya daño de caida desde esa torre y de otras torres altas hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas zonas hazlo, dame distintas propuestas para ela vance del juego cosa que vaya avanzando la dificultad a medida que avanza y que usuario tenga que comprar o ganar dash o alguna mecanica ocmo velocidad, dame propuestas del juego"

## Queue

| ID | Task | Notes | Status |
|---|---|---|---|
| OQ1 | **More realistic clouds**, "no una foto estirada" | The likely target is the cloud wall between biomes (Caramelo's east edge, `Candy_Este_v1.CloudWall`: Veil and puffs) and any sky cloud that is a stretched image. Make them volumetric: many soft parts or particles, layered, and moving slowly. Uploads need separate approval, so use primitives or particles first. **2026-11-19, repo only (not in Studio, not in Play):** the wall's Veil is no longer a ForceField texture (transparent); the client lays 72 soft puffs (36 with "Efectos suaves") in three overlapping layers, inside the band's length, plus fewer particles; the wall keeps Caramelo's pink face from both sides (the face follows the camera's biome). The sky uses real 3D Clouds in Caramelo and Pueblo Gatito only, with a slow local wind; the pink skybox picture is no longer swapped in, and the candy and park haze is raised. **Known limit:** the place's own photo Sky (`Lighting.Sky`, SkyboxUp 6412503613) is unchanged in every biome; only the haze and the 3D cloud cover hide it. The only other sky in the place, the pink skybox, is also a painted photo, and a new sky image needs an upload approval. **Hard gate before Done:** in solo Play, look straight up and at 45 degrees in Caramelo and in Pueblo Gatito (around 282, 600). If Caramelo's sky overhead reads blue, or the photo shows between the clouds in either biome, it is not fixed. Fallbacks in order: Caramelo cover 0.72 -> 0.85, Gatuno cover 0.58 -> 0.75, and last Caramelo `skybox = true` (the V7-D3 pink sky back). Report the result to the owner as it is. | In Studio 2026-11-19 (`d91afab`, suites, solo Play numbers); the look is the owner's call (captures render white) |
| OQ2 | **The Caramelo queen (La Duquesa) gets angry and never stops chasing** once you steal her egg | This reverses V7-D6, where she lets go past her zone margin. The service's flight clamp (`Smarts.outsideWall`) and the "Vanish" rule change too. RC6 in `WildboundCandyDuquesa_Test` is a deliberate change. Decide how the chase ends: the base, dropping the egg, being caught, or a long timeout. | Done 2026-11-19 (`d69dfac`, Studio, suites). A live chase in Play was not staged. |
| OQ3 | **Fall damage** from the Gran Torta's tower and other tall towers | This is new. Damage stays off outside the private test place, so it is a flag that is on here. It applies to tall towers in every biome; list them first. | Done 2026-11-19 (`f0f2873`, Studio, suites, solo Play fall) |
| OQ4 | **A much longer map**, with more creatures from different zones if needed | This builds on PD1: every big4 arm 600 x 1200, with Caramelo already done (v9). "Bastante más largo" may mean longer than 1200: decide and record. Pueblo Gatito is next. Its research workflow was started and stopped on 2026-11-19, with nothing written. Then Bosque and Montañas. Add creatures to the new space where it feels empty. | In progress (Caramelo done 2026-11-18, Pueblo Gatito done 2026-11-20 `d1a86c1`; Bosque and Montañas next) |
| OQ5 | **Proposals for game progression**: difficulty rising as you advance; the player has to buy or earn a dash or another mechanic, such as speed | The deliverable is proposals, not code: several options. Note in the proposals that buying with Robux is design only. Nothing is purchasable (`monetization = "none"`) without the owner's explicit approval. In-game currency or earned unlocks are fine to propose. Read `docs/design/wildbound-combined-plan.md` §6, `docs/design/wildbound-economy-and-offers.md` and the overview first. | Done 2026-11-19: `docs/design/wildbound-progression-proposals.md` (A Sellos, B Nivel + tienda, C Rango; recommended B with grafts). Waiting on the owner's choice. |

## Order decided for the owner

1. OQ5 proposals (no Studio).
2. OQ2, the queen.
3. OQ3, fall damage.
4. OQ1, clouds.
5. OQ4, the longer arms, one per task.

The proposals go first so the owner can read them while the code tasks run. OQ2 and OQ3 are small and in Caramelo, which was just changed. OQ4 is the largest.

## Decisions taken for the user

- **OQ2 is built now, on its own, as the owner asked.** It does not wait for the rank system from OQ5. The queen chases with no time limit and no zone margin. The chase ends only when:
  - the thief reaches a safe zone or the base;
  - the thief goes through a portal;
  - the thief drops the egg;
  - the thief is defeated.

  This is the end rule proposal B suggests (the "recommended" section).
- **OQ2 details**, code committed, not yet in Studio:
  - **Hiding no longer loses her.** She circles the hide spot or the grass until the thief comes out, and the spot's own time limit pushes the thief out.
  - **A portal end is the portal service's server stamp only** (`WildboundPortalReadyAt`). The thief's client moves their own body, so a body jump does not count. Egg carriers still cannot use a portal (CG2), so in practice the end is the safe hub.
  - **A second thief is remembered.** Someone who stole her egg inside the plot while she chased another thief is chased afterwards, even outside the plot.
  - **Picking her egg up again after dropping it does not restart the chase.** Dropping the egg ends it, as recorded above.
  - The ends, in the order they are checked: Gone (left or no character), Dead, Portal, Safe, Dropped (after `CALM_SECONDS`).
- **OQ3, fall damage**, code committed, not yet in Studio:
  - **Height rule.** A drop of 20 studs or less, from the takeoff standing height to the landing, never hurts. That covers jumping off bridges, ledges, kitten toys and one cake tier.
  - **Damage.** It is floor((drop − 20) × 1.5), capped at 40, the hardest creature hit. So a fall never kills from full health, and a second fall can defeat a hurt player.
  - **Same switch as creature damage.** It goes through the existing BeastHit path, so it is on only on the private test place.
  - **The egg is kept** on a fall.
  - **One warning per player per session.** The first fall that would hurt only shows "¡Cuidado! Caer de tan alto duele." with no damage, to keep the "todos avisan antes" rule. Later ones show "¡Auch! Caíste de muy alto.".
  - **No damage** after a portal or teleport, respawn, seat or raft, hide spot, ragdoll, a creature push or hit (1.5 s), a crumbling cookie bridge, a landing in chocolate, or a slow descent.
  - **Pradera falls hurt too,** for example the Seta Trueno at 26 studs → 9.
  - No warning sign at the stair for now.

## Evidence (OQ2 and OQ3, 2026-11-19)

- **Deploy.**
  - Before writing, Studio matched `fc55760` for the Duquesa files.
  - WildboundServer and WildboundText are mixed copies, so they got their one hunk each. They grew by the exact repo delta (Server 228954 → 229139, Text 45197 → 45630) and both compile.
  - Six scripts matched `f0f2873` by fingerprint: Duquesa, DuquesaService, Duquesa_Test, and the new WildboundFallDamage, WildboundFallDamage_Test and WildboundFallDamageService (enabled).
- **Suites, fresh Play server VM:** CandyDuquesa 35/0, FallDamage 18/0, BeastWiring 53/0, CandySmarts 26/0, CandyHideSpots 16/0, CandyGrass 12/0, CandyTraps 12/0, CandyEast 13/0, PortalService 15/0, CandyNests 27/0.
- **Play, solo.** The character walked off a temporary platform at y 60, which existed for this Play only. Each fall measured a 60.5-stud drop.
  - The first fall only warned: `Fall_warned` 1, no fall damage.
  - The second fall took 40, and health regenerated from 60 afterwards. `Fall_damage` was 40 in total.
  - The other health losses in that session were forest creature hits (`Beast_hits` 4), not falls.
- **Not seen in Play:**
  - a live Duquesa chase out of the plot;
  - the warning and hit lines on screen;
  - a fall from the real Gran Torta summit.

## Evidence (OQ1, 2026-11-19)

- **Deploy.** Before writing, 7 scripts matched `f45d163`. After the hunks, all 7 matched `d91afab`.
- **Live Veil.** It went from ForceField with transparency 0 to SmoothPlastic with transparency 1, in one recording. The Collider still collides.
- **Suites, fresh Play server VM:** CandySky 6/0, Atmosphere 14/0, CandyEast 15/0, BiomeLight (big4) 12/0, KittenPark 13/0, CandyV9Migrate 6/0.
- **Play, solo, client readings:**
  - **Caramelo (1300, 0):** 3D clouds on, cover 0.72, density 0.60, pink. Wind (3, 0, 1), 72 wall puffs, haze 3.0, pink decay.
  - **Pueblo Gatito (282, 600):** clouds on, cover 0.58, density 0.62, white. Haze 1.8, sky-blue decay.
  - **Hub:** clouds off, wind 0.
  - The place's Sky is unchanged (6444884337).
- **Not judged:** whether the painted sky photo still shows between the clouds, and whether Caramelo reads pink enough. The fallbacks are in the commit's studioOnly notes: Caramelo cover 0.85, then Gatuno cover 0.75, then the Caramelo pink skybox back on.

## Toolbox look pass (TB-1..TB-3, 2026-11-20)

Owner's words (2026-11-20): "quiero que investigues cosas de la toolbox para mejorar texturas, etc. Que el cielo sea como ese objeto de la toolbox u otro si queda raro que tenga color rosa, que el agua marron sea de la toolbox tambien, no se si se puede cambiar los colores, el pasto del mundo gatito tambien y que tenga otra musica".

### Decisions taken for the user
- **Sky.** Creator Store "Obby Sky" (127719608807122, by SaturunSnow) is applied to Lighting.Sky in Studio for the whole map.
  - The old ids are kept as Was* attributes on the Sky.
  - Caramelo keeps its pink 3D clouds; there is no pink skybox swap.
- **A pink cartoon skybox (97128825470015) was rejected.** It carried hidden scripts (a "BloomEffect" Runtime Script and an overlay-building LocalScript), and its creator account is deleted. It was destroyed before use.
- **Grass.** Creator Store "Stylized Grass Material" (11314842253) is in MaterialService as "WildboundGatitoGrass". The park floor and Approach use it, tinted 170/224/128 (`bbf427f`).
- **Chocolate.**
  - A client-only scrolling Texture uses Creator Store image 82311877461867, tinted from the part colour, at transparency 0.3.
  - It goes on the river blocks, the pool and the MouthSheet.
  - Joints and lake discs stay plain, so overlaps do not flicker.
- **Music.** Pueblo Gatito's bed is APM "Cute Cat" (1839661368), with APM "Merry Kids" as the fallback.

### Evidence
- **Deploy.** Before writing, 4 scripts matched `1766a06`. After the hunks they matched `bbf427f`, plus 3 new scripts: WildboundCandyChocoLook, WildboundCandyChocoLookClient and WildboundCandyChocoLook_Test.
- **Floor.** `Park.buildGround` changed 4 properties on the first run and 0 on the second.
- **Suites:** CandyChocoLook 11/0, AudioMix 14/0, KittenPark 22/0, CandySky 6/0.
- **Play, solo, client readings.**
  - 17 chocolate textures: 16 on a Top face and 1 on a Right face.
  - Choco_River_3's offset changes every second.
  - gatitoMusic 1839661368 is loaded and playing at volume 0.18 in the park, 95 s long and looped.
- **Not judged:** the scroll direction on screen, how the tint looks, and whether the sky looks right at night in the Bosque. 3D captures render white, so these are for the owner.
## P0.1, the store-style UI kit (2026-11-20)

Owner's words (2026-11-20): "Quiero que la estetica sea asi de la ui, con esa tipografia".
- Plan: `docs/design/wildbound-fun-build-plan.md` (Paso 0).
- Reference: `docs/design/refs/store-ui-reference.png`.
- Code: `4f556ce`.

### Evidence
- **Deploy.** Before writing, 3 scripts matched `48d4a3e`. After the hunks they matched `4f556ce`, plus the new `WildboundUiKit_Test`.
- **Suites, fresh Play server VM:** UiKit 18/0, RouletteService 10/0.
- **Play, solo.**
  - The roulette opened through its prompt.
  - The window shows the blue frame, the FredokaOne title with a thick outline, the red LuckiestGuy X, the cyan sunburst card, the coloured odds rows, and the green Girar and red Cerrar buttons.
  - The rays turned (rotation 34 → 50 in 1 s).
  - Screenshot: `docs/design/refs/roulette-p01-2026-11-20.jpg`.
- **Seen for later:**
  - On a wide screen the left column has empty space between the card and the buttons.
  - The rays are faint on the cyan card.
  - Both are left for the owner's eye.