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

## Checklist, step 2: its own side of the hub (2026-11-18)

Owner's words: "Sí, movelo". Plan: PGM-D1 to PGM-D9 in `docs/design/wildbound-pueblo-gatito-move-plan.md`. Code commit 6831632.

| ID | Task | Status |
|---|---|---|
| PGM-D1 | One park frame, `WildboundGatitoArea`: origin (282, 600), yaw -90, floor x 22..542, z 340..860 | Done (6831632, Studio, suite) |
| PGM-D2 | Its own root `Workspace.PuebloGatito_v1` with its own grass floor | Done (Studio move) |
| PGM-D3 | The biome square is the big4 south arm (x -3..597, z 337..937), first row; in big4 it replaces Volcán | Done (Studio, suites) |
| PGM-D4 | Every park position park-local: paths, village, nests, posts, chests, portal, arrival, music rectangle | Done (solo Play) |
| PGM-D5 | Caramelo's cloud wall closes: one whole Collider, no gate, the floor under the band only, pink | Done (solo Play rays) |
| PGM-D6 | The big4 volcanic decor is archived whole | Done (`WildboundMapArchive.GatitoSouthVolcanic`) |
| PGM-D7 | The one-shot move tool, dry run first | Done (dry run, then the real run) |
| PGM-D8 | What stays: the creature wall clamp, the old-frame archive helpers | Done (suites) |
| PGM-D9 | Docs: this file, overview rows | Done |

### Decisions taken for the user (step 2)

- **Two Studio-only big4 suites updated.** WildboundBeastSight_Test (big4 copy) and WildboundBig4Map_Test still expected a Volcán square in the south arm. They now read Pueblo Gatito (`CandyEast`) there, and the "parque" station is checked in its own biome. Both exist only in Studio, so the repo has no copy to change.
- **The 16-stud gap between the big4 road and the park floor is left as grey baseplate.** The road ends at z 324.5 and the park floor starts at z 340. It is walkable (heights 0.62, 0, 0.5). It is noted for step 3, the look.
- **The music check stays partly open.** In this automated Play every music layer read volume 0, Caramelo's too, so the silence is not from the move. The switches themselves were checked: the kitten flag is on in the park and off at the hub, and the Caramelo flag is on in the plot.

### Evidence (step 2, 2026-11-18)

- **Deploy.**
  - 3 new scripts were created: WildboundGatitoArea, WildboundGatitoArea_Test, WildboundPuebloGatitoMove (disabled).
  - Hunks were applied to 15 changed scripts. All 18 matched HEAD 6831632 by fingerprint.
  - Hand patches went into the Studio-only big4 copies WildboundBiomes, WildboundBiomeLight and WildboundBiomeLight_Test.
- **Move tool.**
  - The dry run listed 1378 park parts, 8 nests (16 parts) and 440 volcanic parts, with no warnings.
  - The real run made the backup `WildboundMapArchive.GatitoMoveBackup`.
  - It moved Park and Nests into `PuebloGatito_v1` and laid `Ground.Floor` (520 x 520 at (282, 600), top 0.5).
  - It archived the volcanic decor to `GatitoSouthVolcanic` and ColliderSouth to `GatitoGate`.
  - A rebuild check after the move changed 0 parts. The root has attributes `PuebloGatito = 2` and `Key = pueblo-gatito`.
- **Suites, fresh Play server VM:**
  - GatitoArea 4/0, KittenPark 13/0, CandyKittens 7/0, CandyKittenArt 5/0, CandyEast 10/0;
  - Portal 12/0, PortalService 15/0, BiomeLight (big4 copy) 12/0, CandySky 4/0, CandyNests 26/0;
  - CandySmarts 26/0, CandyV3Layout 18/0, BeastDirector 53/0, BeastWiring 53/0, CandyAmbience 14/0;
  - CandyHouseNests 5/0, CandyLife 9/0, BeastSight (big4) 8/0 and Big4Map 20/0, after the updates above.
- **Play, solo:**
  - The 8 kittens stood at their new posts: K1 (325, 430) to K8 (174, 750). Gatito Guerrero woke and chased near K1.
  - The HUD read "Pueblo Gatito · siempre de día". The light at (282, 600) is Gatuno, and the biome there is CandyEast.
  - The 8 "Tomar el huevo" prompts stand on the new nests, (337, 430) to (162, 750).
  - The "parque" portal "Volver a la base" stands at (239, 372).
  - Ground rays at x 282 hit, in order: the big4 road to z 324, the baseplate z 326..338, the park floor from z 341, and the main path at z 360 and 600.
  - Wall rays from x 925 at z -250, -3, 0 and 100 hit the whole Collider at x 938. Nothing is open.

## Next step

The longer Caramelo with a river 5 times wider (queued). Then step 3, the park's look (the road-to-floor gap above, density, a border, hills).

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

## Pueblo Gatito 600 x 1200 (GL-D1..GL-D17, 2026-11-20)

The owner asked (2026-11-19): "hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas zonas hazlo".
- Plan: `docs/design/wildbound-pueblo-gatito-long-plan.md`.
- Parent decisions: `docs/handoff/gatito-long/decisions.md`.
- Code: `d1a86c1`.

### Decisions taken for the user (deploy)
- **Visiting candy critters: no** (GL-D12). Their home biome is Meadow, so the director and the summon landing refuse them in the park. Other-zone creatures go to the Bosque and Montañas arms later.
- **Studio-only hand patches.**
  - Biomes and BiomeLight: both CandyEast rows (`AREAS` and `AREAS_BIG4`) go to z 1537. The `replace_all` multi_edit reported success but did not stick; a direct Source rewrite of the row did.
  - BiomeLight_Test (big4): the five repo hunks, minus a comment phrase the Studio copy never had.
  - Big4Map_Test:
    - the south arm is 1200 long, to z 1537;
    - the volcanic clone check compares against the first 600;
    - "parque2" is tagged CandyEast.
  - WildboundText and WildboundText_Test: the parque2 hunk.

### Evidence
- **Deploy.**
  - Before writing, 12 scripts matched `437bb9c`.
  - After the hunks, all 12 matched `d1a86c1`, plus two new scripts: `WildboundPuebloGatitoGrow_Test` and `WildboundPuebloGatitoGrow` (disabled).
  - The mixed copies (Biomes, BiomeLight, BiomeLight_Test, Text, Text_Test, Big4Map_Test) were hand-patched; see the decisions above.
- **Suites, fresh Play server VM:**
  - GatitoArea 5/0, KittenPark 22/0, PuebloGatitoGrow 2/0, CandyKittens 8/0, CandyKittenArt 5/0, CandyNests 27/0;
  - Portal 13/0, PortalService 15/0, BiomeLight (big4) 13/0, Big4Map 20/0, BeastSight (big4) 8/0, Text 25/0;
  - CandySky 6/0, CandyEast 15/0.
- **Grow tool.**
  - The dry run estimated 2826 root parts against a cap of 3037, with no refusals.
  - The real run:
    - made the backup `WildboundMapArchive.GatitoGrowBackup`;
    - resized the floor from 520 x 520 at (282, 600) to 600 x 1200 at (297, 937), and added the Approach slab;
    - created 1679 park parts and 506 edge parts, and 12 nest parts;
    - left the root at 2826 parts, with mark `PuebloGatito = 3`.
  - A rebuild check changed 0 parts, and a second run reported "already".
  - Running the tool and polling in the same execute call fails: the call's own undo step stays open. Schedule the run in one call and read the summary attribute in the next.
- **Play, solo.**
  - Ground rays hit the Approach at (282, 330) and the Floor everywhere in the arm, out to (590, 1530) and (10, 1530). There is no void.
  - Wall rays hit SideWallWest at x -3, SideWallEast at x 597 and the EndWall at z 1537.
  - The park has 16 nests; 7 "Tomar el huevo" prompts stand beyond z 900. The far portal `WildboundPortal_parque2` is at (227, 1375).
  - The director tried to summon Gatito Guerrero at the new post kittenPostK9 (refused only because he was already active elsewhere).
- **Not seen:**
  - a kitten standing at a new post;
  - the far portal used;
  - the Jardín de Ovillos look (3D captures render white);
  - phone performance with about 2826 park parts and 2798 Caramelo parts.

### Next step
The owner plays the far half and saves the place. Then the Bosque and Montañas arms (OQ4).