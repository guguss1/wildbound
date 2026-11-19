# Pueblo Gatito 600 x 1200: parent decisions (GL-PD1..GL-PD11, 2026-11-19)

Owner's words:
- 2026-11-18: "que todos los biomas tengan el mismo tamaño, pero ahora hacelos mas largos aun"
- 2026-11-19: "hace el mapa bastante mas largo y si hace falta colocar mas bichos de distintas zonas hazlo"

The owner asked for no questions: decide and record. The numbers come from the research files in this folder, and the critic's open questions (research-critic.md D1..D11) are answered below.

## Decisions

- **GL-PD1. Frame.** ORIGIN (282, 600), YAW -90 and HALF 260 stay. New `Area.GROWTH = 600` and `Area.FAR = HALF + GROWTH = 860`, with `Area.VERSION = 3`. This follows the Caramelo v9 pattern, and every existing world literal keeps its value.
- **GL-PD2. Arm.**
  - The big4 south arm becomes x -3..597, z 337..1537.
  - The Studio-only big4 copies get hand patches: the AREAS_BIG4 CandyEast row in WildboundBiomes and WildboundBiomeLight, and Big4Map_Test, BeastSight_Test and BiomeLight_Test.
  - The repo copies' classic ARM literals also go to 1537 where they exist.
- **GL-PD3. Ground and edges, with no void.**
  - The single `Ground.Floor` grows to cover the whole arm: x -3..597, z 337..1537, so 600 x 1200 centred at (297, 937).
  - Today's 25, 55 and 77-stud open margins disappear.
  - A separate `Ground.Approach` slab, x 272..292, z 324..337, closes the grey gap between the road end (z 324.5) and the floor.
  - Invisible solid walls stand at x -3, at x 597 (both along z 937..1537) and at z 1537. This is the same idea as Caramelo's side and end walls, past the baseplate.
  - A soft border runs along all three outer edges: a low hedge of green ball puffs, the "hedge or cloud border" from the park's look queue.
- **GL-PD4. Content in the new half (local x 260..860).**
  - About Caramelo's density. PART_CAP goes from 1400 to 2800, and the dry run must report the estimate.
  - A second themed area: "Jardín de Ovillos", a yarn-ball garden with toy piles, scratch towers, paths, trees, lanterns and scatter, all from the park's own existing recipes.
  - The main path continues to local (800, 0).
- **GL-PD5. Far-end goal.** TowerPlaza, the Torre Gato Vigía and its 4 lit lanterns move to the far end, around local x 815. The gate-side plaza stays as it is.
- **GL-PD6. Nests deepen.**
  - Add 8 nests, GatitoK9..GatitoK16, for 16 in total.
  - Rarity is re-spread by depth: Comun near the gate, Rara in the middle, Epica in the far half (K-D8 species unchanged).
  - The count pins change, with "Deliberately changed (GL-PD6)" notes.
  - The CandyNests_Test fixture named "K9" must not clash with the new ids. Check and rename the fixture if needed.
- **GL-PD7. More creatures.**
  - The 4 kittens get 8 more posts deeper in, 2 each, for 16 posts. Their existing posts stay.
  - "Bichos de distintas zonas": add up to 2 visiting candy critters (for example Mochimiau and Mielita) on far-half posts, but only if the director, biome and NO_GLOBAL_BIOMES rules allow it without touching the Caramelo rules. Otherwise kittens only, recorded as such. Other-zone creatures then go into the later Bosque and Montañas arms.
- **GL-PD8. A second portal station** at the far end, "parque2", "Portal del Jardín", so a player without an egg can go home. Egg carriers are still refused (CG2).
- **GL-PD9. A one-shot grow tool** on the move/v9 pattern:
  - dry run, then backup `WildboundMapArchive.GatitoGrowBackup`, then one recording;
  - the floor is conformed in place;
  - `Park.build` lays the new content, and anything the new plan drops is archived to `GatitoGrowArchived`;
  - the root mark becomes `PuebloGatito = 3`;
  - it is idempotent;
  - it refuses if SistemaSonriente parts meet the arm or the estimate exceeds PART_CAP.
- **GL-PD10. Apron_Volcanic** is left alone. The new floor covers the arm, so only its outer margins show.
- **GL-PD11. Balance.** The walk home from the far end is about 1460 studs. This is recorded as a risk; a playtest decides.
