# Pueblo Gatito (its own biome)

## Objective

Pueblo Gatito is the kitten park the owner asked for on 2026-11-17. Since 2026-11-18 it is a biome of its own, not "phase 2 of Reino Caramelo".

Owner's words, 2026-11-18: "es mejor mantener esto en el bioma reino de caramelo o hacer uno aparte? ... dale, hacelo bioma aparte".

## Scope and order

The owner approved this order:

1. Separate it as its own biome: PG-D1 to PG-D9 in `docs/design/wildbound-pueblo-gatito-biome-plan.md`.
2. Move it to its own side of the hub.
3. Fix its look.
4. The micro-phases.

Queued after step 1, on the owner's later message: a longer Caramelo with a river 5 times wider, so the raft can sail it.

The park was built by `docs/design/wildbound-kitten-park-plan.md` (K-D1 to K-D21). Its build log follows below; it was moved here from `wildbound-caramelo-v2.md`.

## Checklist, step 1: its own biome (2026-11-18)

| ID | Task | Status |
|---|---|---|
| PG-D1 | Its own biome in every name, text, sound and doc. The internal tag `CandyEast` stays | Done (51debba, Studio) |
| PG-D2 | Park nests as their own island entries (`GatitoK1`..`GatitoK8`, `gatito_k<n>`, biome `PuebloGatito`). Key `pueblo-gatito` | Done (51debba, Studio, solo Play) |
| PG-D3 | The return portal is named "Portal de Pueblo Gatito" | Done (solo Play) |
| PG-D4 | The four kittens have warning and hit lines | Done (solo Play, Gatito Guerrero) |
| PG-D5 | The border is the cloud: kitten music from inside the band, Caramelo music, lights and life off in the park | Done (solo Play walk) |
| PG-D6 | The cloud is pink from Caramelo, white and sky blue from the park | Done (solo Play, camera both sides) |
| PG-D7 | The Gomibu card no longer says "del bioma Caramelo" | Done (suite) |
| PG-D8 | The Balance record knows the Gatuno preset | Done (suite) |
| PG-D9 | Own task file, overview rows, kitten-plan note | Done |

### Decisions taken for the user (step 1, after the plan)

- **The border keeps Caramelo's own hysteresis.** Both Caramelo clients (ambience and life) keep the plot's enter/leave state (`nearCandy`) apart from the gated result (`inCandy = nearCandy and not kittenOn()`). A reviewer found that writing the gated value back would leave a strip at the north and south corners where neither biome's ambience is on.
- **One name for the kitten flag.** The Caramelo clients read the flag name from `WildboundCandyKittens.GUI_ATTRIBUTE`, so a rename cannot break the border silently.
- **A K-D9 test needle fixed.** WildboundCandyHouseNests_Test pinned `and m.house ~= true then`. Since K-D9 the bind line goes on with `and m.park ~= true then`, so this case had failed since the park deploy (not caused by step 1).
- **Not done:** the ambience and life clients still poll every 0.5 s, so the switch can lag the kitten flag by up to half a second. The reviewer rated it low.

### Evidence (step 1, 2026-11-18)

- **Deploy.**
  - 16 changed scripts matched base a24d1ef in Studio before the hunks, and matched HEAD 51debba after.
  - Hunks only for the mixed copies: WildboundText and WildboundText_Test (Studio's Text_Test carries 334 extra bytes from another branch), and the Studio-only big4 WildboundBiomes and WildboundBiomeLight (the key and a comment).
  - The live root attribute `Candy_Este_v1.Key` is now `pueblo-gatito`.
- **Suites, fresh Play server VM:**
  - CandyNests 26/0, CandyKittens 7/0, CandyKittenArt 5/0, CandyEast 10/0, CandyAmbience 14/0, CandyLife 9/0;
  - Balance 25/0 (B23 passes again), Portal 12/0, PortalService 15/0, BiomeLight (big4 copy) 12/0;
  - KittenPark 12/0, BeastWiring 53/0, CandySky 4/0, CandyIsland 10/0, Text 25/0;
  - CandyHouseNests 5/0, after the needle fix.
- **Play, solo:**
  - The server laid 8 park islands `Island_GatitoK1`..`K8`, and no `Island_CandyK*` remains.
  - The "parque" prompt reads "Portal de Pueblo Gatito" / "Volver a la base".
  - The 8 park nests show "Tomar el huevo".
  - Walking x 900 -> 1000 -> 900 at z -3: Caramelo music and decoration stay on to x 928. The kitten flag is on and Caramelo off from x 933. On the way back the kitten flag stays on to x 926, and Caramelo is back from x 922. No step had neither on.
  - With the camera set at x 880, the cloud puffs read 255,240,248 (pink face). At x 1000 they read 199,226,245 (park face).
  - Near post K1 the client showed "Gatito Guerrero te vio", "¡Gatito Guerrero te sigue!", "¡Carga de escudo! Sal de la franja por un lado" and "¡Escudazo!".
  - The console had no errors from the changed scripts. It did show permission errors for the Lumipol MeshGen meshes (Workspace.MeshGen1, ServerStorage.WildboundAssets.LumipolMeshGen); those predate this step.

## Next step

Step 2: move the park to its own side of the hub (the south arm is planned). Then the longer Caramelo with a river 5 times wider.

---

## The build log: the kitten park behind the cloud wall (2026-11-17/18)

Owner's words: "la segunda fase del bioma, la que va luego de la pared de nube es como el mundo de gatito. quiero que sea
un parque verde lindo con las criaturas gatitas esas que estan ahi, juguetes como rollos de papel, hisopos, papel,
bolsas, tiendas de gatitos como que es su village etc y otra cancion que tenga que ver mas con gatitos, tambien tiene que
haber huevos para robar". The plan and its decisions are in `docs/design/wildbound-kitten-park-plan.md`, K-D1 to K-D21.

| ID | Task | Status |
|---|---|---|
| K-D1, K-D2 | The gate: the Collider split (14-stud gap at z -10..4), the plot side kept clear | Done (fbcfb6f, Studio) |
| K-D3 | The "parque" return portal at (980, 40); a carrier is refused | Done (fbcfb6f, Studio) |
| K-D4 to K-D7 | The four kittens on the critter brain, zones of 60, eight posts | Done (fbcfb6f, Studio) |
| K-D8, K-D9 | Eight park nests K1..K8 (3 Comun, 3 Rara, 2 Epica), paid one tier more | Done (fbcfb6f, Studio) |
| K-D10, K-D11 | No Global beasts in the park; the park summons like the plot | Done (fbcfb6f, Studio) |
| K-D12 | Part-built kittens and their pose client | Done (fbcfb6f, Studio) |
| K-D13 | The kitten music (slot gatitoMusic) | Done (Studio); the owner must audition it |
| K-D14 | The Gatuno light: always day, light-blue air, white clouds | Done (fbcfb6f, Studio) |
| K-D15 to K-D18 | The green park, village, toys, trees and lanterns; the part budget | Done (Studio build) |

### Decisions taken for the user (after the plan)

- **The big4 copies again.** Studio's BiomeLight is the big4 copy. All of these were done as hunks:
  - the CandyEast row moved to the first row of both AREAS and AREAS_BIG4;
  - TAG_PRESET became `CandyEast = "Gatuno"`;
  - the Gatuno preset and its Day rule were added;
  - the Studio BiomeLight_Test got the repo's K-D14 case and expects Gatuno in its V8-D2 case.

  **The big4 branch needs the same lines when it merges.**
- **A V7-D6 test fix.** WildboundBeastCandyCritter_Test's RC1/RC3 and CC2 escape cases failed on Mochimiau (zone 80): the zone's edge ended the chase before the case's own check.
  - As with Grass and Traps, the home now follows the hunter during those chases.
  - RC1/RC3 then sets the hunter 10 studs from its real post for the hard-limit walk home.
  - This was not caused by the park.
- **The annex archive.** 91 annex props stood in the second space (the plan guessed about 70). All were decor in `Props`; no floor slab was moved.

### Evidence

- **Deploy.**
  - The 25 changed scripts matched base 834ca3a in Studio before the hunks were applied, and matched HEAD fbcfb6f afterwards.
  - The 9 new scripts were pasted in parts; all 9 match HEAD.
  - WildboundKittenParkBuild is a disabled Script.
  - The big4 BiomeLight and BiomeLight_Test were patched as hunks, so they have no repo copy to fingerprint against.
- **Build.** A dry run first, then the real run as one undo step ("KittenPark"):
  - backup in `ServerStorage.WildboundMapArchive.KittenParkBackup`;
  - 0 blocking pieces in the gate corridor;
  - 91 annex props archived to KittenParkAnnex;
  - the park laid: 1378 parts (Paths 254, Gate 8, Village 310, ToyPark 98, Toys 160, Chests 88, Trees 202, Lanterns 130, Scatter 128);
  - 8 nests (16 parts);
  - Candy_Este_v1 holds 1400 parts and is marked KittenPark = 1.
- **Suites, run in a fresh Play server VM.** Every suite passed:
  - KittenPark 12/0, CandyKittens 7/0, CandyKittenArt 5/0;
  - CandyEast 9/0, CandyLayout 24/0, CandyNests 26/0;
  - Portal 12/0, BeastDirector 53/0, CandySmarts 26/0;
  - BeastCandyCritter 33/0 (after the fix), BeastWiring 53/0;
  - CandyAmbience 13/0, AudioMix 14/0, Atmosphere 13/0, CandySky 4/0;
  - BiomeLight (big4 copy) 12/0, PortalService 15/0, V3Layout 18/0;
  - HideSpots 16/0, Grass 12/0, Traps 12/0, Flyers 23/0.
- **Light.** In big4 mode, presetAt gives Gatuno at (960, 0) and (1300, 0), and Caramelo at (900, 0).
- **Play, solo.**
  - A character walked from the plot (925, -3) through the gate to (964, -3).
  - The four kitten models (21-25 parts) were in WildboundBeasts.Models.
  - The 8 resting posts were published, and the client showed 8 resting kittens.
  - GatitoGuerrero was summoned near post K1, chased and hit once. The pose client reported no error.
  - In the park the client had GatitoAmbience true, preset Gatuno, ClockTime 13 and light-blue air.
  - gatitoMusic 108517170970006 loaded (187 s) and played at 0.18.
  - Each of the 8 park nests had an egg with a "Tomar el huevo" prompt, and the "parque" portal showed "Volver a la base".
  - The console showed no script errors from the park.
- **Not checked:**
  - a steal carried home from a park nest;
  - the portal refusing a carrier in Play (both are covered by suites);
  - whether the kitten music ducks during a chase;
  - how the park looks (screen captures of the 3D view render white).
