# Silueta forest — visual exploration v1

Two image-generated art references for a modular Roblox forest. They are not screenshots of the running place, a scale drawing, a new map layout, or finished Blender models.

| Reference | Use |
| --- | --- |
| [Day/night comparison](../../assets/concepts/silueta-forest/silueta-forest-day-night-v1.png) | Use the same trail and props for both states. In daylight, canopy shadow and gray fog establish the threat; at night, far landmarks disappear and the nearest amber marker and path edge remain readable. |
| [Blender kit sheet](../../assets/concepts/silueta-forest/silueta-forest-blender-kit-v1.png) | Six independent modeling references: crooked evergreen, dead tree, snapped log, root arch, ruined doorway, and lantern/cage marker. The two arches are separate assets. |

## First modeling pass

- Start with two tree silhouettes and the route marker. Use separate trunk/canopy pieces and a ground-level pivot; rotate and vary instances rather than modeling every tree separately.
- Keep dense trunks and deadwood off the existing walkable corridor. The P0 loop uses a 14-stud route; fit the roots and masonry around that corridor rather than narrowing it in the concept pass. Leave collision decisions for a Studio check; use simple proxies where needed.
- Make the root arch the first major landmark. Use the lantern to reveal the next decision point, not the whole forest. Check the actual night scene on touch displays before tuning fog. Silueta's scale in the art is illustrative; keep the existing gameplay proxy unchanged.
- Use the existing map as layout authority. This concept does not change the place, import assets, alter combat, or approve the final art.

## Generation prompts (built-in ImageGen)

### Day/night

```text
Use case: stylized-concept. Create ONE wide, polished landscape split-screen production concept for Wildbound, two equal side-by-side 4:3 gameplay views of the EXACT SAME spot, camera and geometry, dark foggy daytime on the left and exceptionally low visibility midnight on the right. Original Roblox Studio in-game screenshot aesthetic (not logos or branded UI), third-person standard elevated follow camera behind the same small blocky R15-like explorer, squared limbs and simple orange backpack, 11-stud-tall antlered Silueta partially hidden among trees for scale. This must look realistically achievable in a Roblox game, not an Unreal render, glossy cinematic key art, drawing, Minecraft voxel blocks, or photorealism. Simple faceted low-poly modular parts, matte grass and muddy paths, clean edges, plausible lighting. Both halves show a broad playable winding 14-stud dirt trail, tall repeated crooked timber trunks and layered angular dark evergreen crowns, clear walking corridor, low flat ferns, exposed root arch crossing the trail at mid-distance, small charcoal broken masonry gate with only two posts, fallen snapped trunk at the side, small rust cage dangling from one crooked tree and amber lantern stakes along the trail as restrained navigational cues. Silueta is an ORIGINAL dark forest guardian with long thin arms, wide ragged twig shoulders, branching antler crown and two small muted purple eyes, reads as silhouette, no gore and no attack pose. DAY side: occluded canopy and dense bluish gray fog even in daylight, soft pale sky visible only through gaps, black-green understory with separation between trunks, enough contrast to see the path and gate from further away. NIGHT side: deep navy-black and heavy ground haze, very short sight distance; distant trees and ruin disappear entirely into mist, only avatar, foreground path edge and one low amber route marker readable; Silueta a vague outline at the edge of the fog, no neon glow. Same visible world assets in both panels, lighting and fog only change. Hard clean thin vertical divider, no caption labels, no text, no HUD, no watermark. Wide format. Deliver a useful visual reference for actual level building, not marketing art.
```

### Blender kit

```text
Use case: stylized-concept. Create a single landscape environment asset modeling reference sheet for Wildbound's Roblox fog forest, arranged as EXACTLY six clearly isolated numbered-free tiles in a tidy 3 columns by 2 rows grid against neutral matte light gray; each tile shows one separate game asset in a clear orthographic three-quarter view, no contact between tiles, soft consistent lighting, faint aligned base grid, same scale where practical. Models should look actually usable in Roblox: chunky low-poly geometry built from a small number of facets, sharp silhouette, matte solid materials, simple flat colors, no high-detail surface noise. Top row left to right: (1) tall dark evergreen tree with crooked polygonal trunk, root flare, three simple layered irregular angular canopy tiers, (2) dead forked tree with twisted trunk, a few asymmetric broken pointed branches and bare exposed roots, (3) fallen trunk with a clearly modeled snapped splintered end and a modest cluster of three shelf fungi. Bottom row left to right: (4) paired-root tunnel arch with generous player clearance, bony curved roots but unmistakably wood, (5) ruined modular charcoal stone doorway with two low broken wings and moss patches in muted olive, (6) eerie trail marker, narrow leaning wood stake with simple amber lantern and tiny empty hanging iron cage. For tall tree tiles show the full trunk from roots to top without cropping. Use a forest palette of dark pine, desaturated moss, cool charcoal stone, bark brown and small subdued amber highlights; no fog or darkness in this technical sheet, prioritize edges and readable construction. Each object visually clean enough to recreate from primitives in Blender. No text, humans, effects, logos, title, perspective distortion, scenery, blood, weapons, terrain, or realistic materials. Product-quality low-poly reference sheet, landscape.
```

