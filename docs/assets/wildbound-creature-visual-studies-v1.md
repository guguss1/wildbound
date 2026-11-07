# Wildbound creature visual studies v1

These are concept images from built-in ImageGen, not screenshots or exact engineering orthographics. The current Studio rigs, mechanics and collision are unchanged.

| Image | Modeling or playtest use |
| --- | --- |
| [Silueta turnaround](../../assets/concepts/creatures/silueta-turnaround-v1.png) | Front/side/back reference for elongated bark mask, shoulder plates and a crown that blends into the trees. Match the broad silhouette, not image-generated joint coordinates. |
| [Silueta search and reveal](../../assets/concepts/creatures/silueta-search-reveal-v1.png) | Proposed contrast between a low, tilted search pose and an open-arm warning. The screenshot-like layout is not a shipped search tell; the guardian scale and flashlight beam are illustrative. |
| [Lumipol turnaround](../../assets/concepts/creatures/lumipol-turnaround-v1.png) | Square-beveled body, flat dark mask, cyan eyes, cream petals and two folded mint leaves. Reference only; interpret overlaps to make four feet and keep the leaf tail small. |
| [Lumipol forest scale](../../assets/concepts/creatures/lumipol-roblox-field-v1.png) | Shows the first-pass game-camera contrast: small, approachable companion at a player's feet in forest fog. No new illumination mechanic is implied. |

## Modeling priorities

- **Silueta:** first try a detached appearance variant with a simple wood mask, a few large shoulder plates and restrained eyes. Preserve the feet origin, 18-bone skeleton, four animation clips and gameplay Body. Verify skinning and all four actions before replacing anything in Studio.
- **Lumipol:** make the beveled body, leaf ears and face readable before adding small detail. Use detached parts and simple materials; preview at small scale. A model is a local art prototype until import and mobile readability are measured.

## Editable Lumipol blockout

[Blender source](../../assets/blender/lumipol-roblox-blockout-v1.blend) · [Rendered preview](../../assets/blender/lumipol-roblox-blockout-v1-preview.png) · [Measured report](../../assets/blender/lumipol-roblox-blockout-v1-report.json). Built from original primitives in an isolated background Blender process. The 18 creature meshes have 1,392 triangles, zero measured non-manifold edges, and a grounded Z=0 stance. Dimensions are 2.658 × 2.230 × 2.510 Blender units; stud conversion was not verified. This deliberately rounded first pass is not a precise reconstruction of the image: the petal edges can be sharpened and unified asset and leaf pivots should be established before rigging or import. No rig, Studio import, or gameplay change.

## Generation prompts

### Silueta turnaround

```text
Use case: stylized-concept. Production turnaround reference for Blender, a single original Roblox horror creature named La Silueta. A wide landscape art sheet, exactly three matched full-body orthographic views left to right front, right side, rear, on uniform mid-gray studio background with a faint common floor line. Same neutral A pose, mesh, scale and posture in all three, full crown and feet uncropped, generous gutters. Use a geometry-first faceted low-poly Roblox mesh look, deliberately simple matte materials and large planes; game-ready art target, not realistic sculpture. Design improves an existing rig: keep an asymmetric tree-branch antler crown, very long hanging forearms, hunch, two slim legs, two pin-small muted violet eye shapes sunk deep in a nearly blank charcoal wood mask. Broader shoulder shadow from 5–7 long angular overlapping torn-bark mantle plates (not countless twigs or hair), tapered torso with 3 bold flat bark slits and a tight angular rib texture, simple 3-pronged fingers like broken roots. Narrow neck and silhouette negative spaces clearly visible in all views. The character should read as a walking dead tree and look taller/gaunter than a blocky player without being a deer or an armor knight. Dark graphite wood, muted pine-green ragged mantle, cool gray cuts, small subdued violet eyes only. Readable side lighting sufficient to model, no fog or heavy bloom. No accessories, lettering, human scale dummy, technical diagram text, UI, logos, photoreal detail, gore, guns, cropping. Aim for a credible shape reference with repeatable part boundaries and clean rig joints, not a promise of a mesh.
```

### Silueta forest readability

```text
Use case: stylized-concept. Two-panel same forest location gameplay concept for Wildbound, screen-like third-person Roblox viewport look, same elevated camera behind a tiny squared-limbed explorer with orange backpack on a muddy trail, roots and dead trees in dense blue-gray fog beneath dark simple faceted conifers. Left panel: the 11-stud-tall original horror creature La Silueta is half hidden next to a trunk in gray shaded daytime, its antler crown blends with bare branches, head slowly tilted sideways and right forearm low, as if searching the last spot it saw the player. Right panel: same shot moments later when the player's narrow flashlight reveals the creature's head turned towards them, pin-small muted violet eyes, hunched long thin arms, broad shoulder silhouette of 5–7 large ragged black bark plates, feet in place, arms starting to spread so an attack warning is unmistakably different from the search pose. Not a lunge or gore. Main focus is the distinct silhouette and two readable posture cues. Low-poly modular Roblox forms, harsh matte faceted geometry with credible simple ambient fog and an amber wayfinding lantern at trail edge, muted charcoal/green and blue fog, not photoreal or cinematic Unreal. Same geometry, player, path and lighting otherwise, sharp vertical separator. No UI, text, logos, watermarks, horror blood, polished armor or real human proportions.
```

### Lumipol turnaround

```text
Use case: stylized-concept. Make a friendly low-poly plant companion modeling sheet, three aligned views: front, side, rear. Wide landscape with light gray background and a common ground line. The same compact garden sprite in each view: a beveled cream cube body with broad simple petal plates, four small charcoal feet, charcoal rounded-square face panel, two small cyan oval eyes, two mint folded leaves on top (one angled, one upright) and a short mint leaf tail. A cream three-petal tuft frames the face. Show the complete body and leaves with clean empty gutters. Use an understated blocky game-mesh aesthetic and flat matte materials; simple enough to rebuild by hand in Blender. No text or logos.
```

### Lumipol at gameplay scale

```text
Use case: stylized-concept. A landscape production image of a cute original collectible companion in a realistically achievable stylized Roblox forest game, not a glossy game ad or film render. Two clean side-by-side views: left, daytime high-visibility three-quarter close-up on a mossy flat stone; right, wide third-person player camera from behind a simple blocky Roblox-like explorer, the exact same tiny companion beside the boot with dense night fog and faint path lantern beyond. Character Lumipol: squat rounded beveled cube, chunky cream petal collar and three-point cream forelock, charcoal rounded-square face and two tiny oval cyan eyes, four stubby dark feet, two asymmetric folded mint leaves for ears (one broad angled, one upright), one short mint leaf tail. Clean broad polygon surfaces, flat colors, minimal mesh complexity. At night cyan accents remain readable without lighting the whole forest; optional tiny close soft glow from eyes only, no bubble beams, no large sparkles, no implication of combat or light as a new mechanic. Place the pet at about knee-height of the blocky character, clear side silhouette in real game camera. Matte pine/moss ground, repeated simple low-poly trunks and foggy background. No text, UI, logos, fake buttons, realistic fur, extra limbs, oversized designer eyes or mouths.
```
