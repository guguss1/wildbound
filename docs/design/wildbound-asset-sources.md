# Wildbound asset sources (research, read-only)

Date: 2026-11-10. Status: research. Nothing here was downloaded, inserted, uploaded, purchased, imported or committed. Answers section 16.1 of the master prompt: Roblox-compatible low/mid-poly dark-fantasy forest models, with real links, licence evidence and format notes.

Companion docs: `docs/design/wildbound-forest-aesthetic-reference.md` (look and our own FK_ kit; its section 5 already lists a Creator Store shortlist, summarised in section 9 here so it is not duplicated) and `docs/design/wildbound-combined-plan.md`.

## 0. How to read this note

- **Licence column** is what the source page itself said on 2026-11-10 (fetched as text). "CC0" means the page or the per-model page showed the CC0 1.0 mark and link `https://creativecommons.org/publicdomain/zero/1.0/`. Where a bundle page only showed a bundle-level licence, the cell says so.
- **Tri count** is "n/s" (not stated) almost everywhere: none of Quaternius, Kenney, KayKit or Poly Pizza pages publish triangle counts in text. Quaternius, Kenney and KayKit describe the meshes as "low poly"; KayKit says "optimised for ... mobile" (see 1.3). Measure after import; the Roblox hard limit is 20,000 triangles per mesh (verified, section 1.2).
- **Style fit (1-5)** is an estimate from the pack descriptions and model names. This agent did not view thumbnails or models, so every score is a hypothesis for the user to check in a screenshot. 5 = matches the faceted, flat-colour, silhouette-first kit direction; 3 = usable after a recolour; 1 = off-style.
- Anything the research could not confirm is marked **UNVERIFIED**.
- Per `AGENTS.md`: no uploads, no monetisation, no Studio edits. Importing any of this into Roblox is a later, user-approved step.

## 1. Cross-cutting findings

### 1.1 Licences (what is safe)

| Source | Licence found | Attribution | Evidence (licence page) |
| --- | --- | --- | --- |
| Quaternius packs (all pack pages fetched) | CC0 on every pack page fetched. Stylized Nature MegaKit wording: "Free to use in personal, educational and commercial projects. (CC0 License)". | Not required (CC0). | Each pack page links the CC0 deed, for example `https://quaternius.com/packs/stylizednaturemegakit.html`; deed `https://creativecommons.org/publicdomain/zero/1.0/`. quaternius.com's own front page and its "License" menu item stated no terms in the fetched text, so the per-pack pages are the evidence. |
| Kenney (Nature Kit, Survival Kit, Graveyard Kit, Fantasy Town Kit pages) | CC0. Kenney: "all game assets on the asset pages are public domain licensed (CC0)", commercial use allowed. | Not required; crediting "Kenney" is optional, the logo is reserved. | `https://kenney.nl/support` (statement), asset pages show "Creative Commons CC0", `https://kenney-assets.itch.io/survival-kit` ("CC0 1.0 Universal ... credit is optional"). |
| KayKit (Kay Lousberg) Halloween Bits and Forest Nature Pack, itch.io | CC0 1.0. "Free for personal and commercial use". Asks not to resell unmodified copies or claim as your own. | Not required. | `https://kaylousberg.itch.io/halloween-bits`, `https://kaylousberg.itch.io/kaykit-forest`. |
| Poly Pizza (aggregator) | Per model, one of CC0 or CC BY 3.0 (the site has a licence filter). Verified individually below. The site's front page and API docs fetched as text did not state licence terms; the model pages did. | CC0: no. **CC BY 3.0: yes**, creator credit, link to the licence, note changes. The model page shows no ready-made credit text. | Per-model page, for example `https://poly.pizza/m/mxDOl0n6zt` (CC0) and `https://poly.pizza/m/9uT74BMpRrl` (CC BY 3.0, `https://creativecommons.org/licenses/by/3.0/`). |
| Roblox Creator Store | Per-asset, set by each uploader; the docs page fetched does not state commercial-use or attribution terms and points to the Terms of Use, Community Rules and IP guidelines (`https://create.roblox.com/docs/production/publishing/creator-store`). | UNVERIFIED for any given asset. | The Roblox Creator Terms were not fetched; the official position on CC-BY content and in-experience credits is **UNVERIFIED**. |

Rule used for this note: CC0 only goes in the starter set. CC BY 3.0 items are listed but flagged, and each would need a visible credit (an in-experience credits panel or the experience description is the usual place; Roblox's exact expectation is UNVERIFIED) plus a credits file in the repo.

Poly Pizza hosts the same Quaternius, Kenney and Kay Lousberg models (CC0) next to CC BY 3.0 models from other creators (J-Toastie's "Small Camping Bundle" is CC BY 3.0; "Poly by Google" models are CC BY 3.0). Always read the licence on the individual model page, not the bundle name.

### 1.2 Formats and Roblox import

- Roblox Studio 3D Importer accepts `.fbx`, `.obj` and `.gltf` (and `.glb` in its glTF hierarchy section). `.fbx` and `.gltf` support vertex colours and basic or PBR textures; the page does not say the same for `.obj`. Scale unit defaults to studs. Source: `https://create.roblox.com/docs/art/modeling/3d-importer`.
- Hard limit: "Individual meshes can not exceed 20,000 triangles"; meshes must be watertight, with no exposed holes or backfaces. Source: `https://create.roblox.com/docs/art/modeling/specifications`. This page does not list accepted formats or file size limits.
- Quaternius packs: FBX, OBJ, glTF, plus Blend on several (page text, per pack). Kenney: his knowledge base says GLB is the distributed glTF form, FBX and GLB have the same features, and OBJ is discouraged (`https://kenney.nl/knowledge-base/game-assets-3d/importing-3d-models-into-game-engines`); the Nature, Survival and Graveyard asset pages did not list formats in text, the Survival Kit itch page lists OBJ, FBX and glTF. KayKit: OBJ, FBX, glTF. Poly Pizza model pages: FBX and GLTF for Quaternius, Kay Lousberg and Kenney bundles; OBJ and GLTF for Kenney and Poly by Google single models.
- **Blender optimisation: recommended for all of it, not optional**, because Wildbound's kit rules (`tools/build-forest-kit.py`: one mesh per material, pivot at ground level, 1 unit = 1 stud, palette `2B4034 4C3226 6B7036 ...`, no textures) differ from every pack here. Expected passes per prop: set scale to studs, ground-level pivot, merge to one mesh per material, recolour to the Wildbound palette (or keep the pack's gradient atlas and tint in Roblox), check face normals and watertightness against the 20k limit, delete tiny floating detail (nothing under 2 studs, per the readability rule in the aesthetic reference), then FBX export. Quaternius's Stylized Nature MegaKit is "textured" with switchable leaf variants; KayKit uses one 1024x1024 gradient atlas that "can be downsampled to 128x128". Both therefore need a texture-or-vertex-colour decision at import.
- The Quaternius "Standard" tier is free (itch.io caption: 81 assets; pack page: about 60-70 percent of the pack). "Pro" and "Source" tiers are paid. Only Standard is needed here.

### 1.3 Security note

Models from the Creator Store can carry scripts and obfuscated loaders. Roblox's own docs warn: "Assets that may look useful on the surface could load another 'virus' asset at runtime", and recommend Disable Scripts in Explorer. Pack downloads from Quaternius, Kenney and KayKit contain mesh files only (no Luau), which is the main reason to prefer them over Creator Store models. Never insert a Creator Store model without opening it, deleting every Script, LocalScript, ModuleScript and `require(` or `loadstring` use, and reading the licence text.

## 2. Forest trees (2-3 families)

Targets from the aesthetic reference: Pino Velador (tall narrow spruce), Roble Encorvado (short wide oak), Abedul Palido (thin pale birch), plus the existing `FK_Evergreen` and `FK_DeadTree`. These are stand-ins or silhouette references; the direction there is still our own kit.

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stylized Nature MegaKit (Standard tier): Tree, Dead Tree, Pine, Twisted Tree, Bush, Fern | https://quaternius.com/packs/stylizednaturemegakit.html ; model list at https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm | Quaternius | CC0, https://quaternius.com/packs/stylizednaturemegakit.html | No | FBX, OBJ, glTF (+ Blend in Source tier) | n/s | 4 | 116 models total per the page (40 trees, 35 plants/flowers, 27 rocks). Ghibli-style, textured, switchable leaf colours. "Twisted Tree" suits the leaning forest. The Poly Pizza listing names only a subset (Standard), so which of the 40 trees are free is **UNVERIFIED**. |
| Ultimate Stylized Nature Pack: Birch Trees, Trees, Maple Trees, Dead Trees (two sets), Pine Trees, Bushes, Rocks | https://quaternius.com/packs/ultimatestylizednature.html ; https://poly.pizza/bundle/Ultimate-Stylized-Nature-Pack-zyIyYd9yGr | Quaternius | CC0 (both pages) | No | FBX, OBJ, Blend, glTF (pack page); FBX + GLTF on Poly Pizza | n/s | 4 | 63 models on the page. Birch set is the stand-in for Abedul Palido; Pine set for Pino Velador. Textured with normal maps per the page, so strip or bake before import. |
| KayKit Forest Nature Pack (free tier) | https://kaylousberg.itch.io/kaykit-forest | Kay Lousberg | CC0 1.0, same page | No | FBX, glTF, OBJ | n/s ("low-poly and optimised for games of all scales, including mobile") | 4 | 100+ free models of trees, rocks, bushes, grass; paid Extra adds recolours. One 1024x1024 gradient atlas, so tinting to the Wildbound palette is a UV-offset job, not a texture rebuild. The page mentions Roblox among supported engines. |
| Halloween Bits: Autumn pine x6, Dead tree x4, Small dead tree, Tree Dead Large Deco | https://kaylousberg.itch.io/halloween-bits ; list at https://poly.pizza/bundle/Halloween-Bits-5J1jHdy21M | Kay Lousberg | CC0 (itch page and Poly Pizza bundle: "Public Domain (CC0)", all 63 models CC0) | No | OBJ, FBX, glTF (itch); FBX + GLTF (Poly Pizza) | n/s | 5 | The "Dead tree" and "Tree Dead Large Deco" silhouettes are a direct Ceniza-variant reference. Poly Pizza single pages: https://poly.pizza/m/68VK0NzgEZ (Dead tree, CC0 verified), https://poly.pizza/m/ZuvSMavX9P (Tree Dead Large Deco, licence not individually opened). |
| Kenney Nature Kit | https://kenney.nl/assets/nature-kit | Kenney | CC0, same page (v1.0, 2020) | No | Not stated on the page; Kenney kits ship GLB/FBX per the knowledge base. **UNVERIFIED for this kit** | n/s | 4 | 330 files. Page tags: nature, tree, rock, foliage. A third-party listing says it also has camping equipment and plants; file-level contents were not confirmed. Kenney's flat-colour look needs the least recolouring. |
| Quaternius Ultimate Nature Pack | https://quaternius.com/packs/ultimatenature.html | Quaternius | CC0 (page) | No | FBX, OBJ, Blend | n/s | 3 | 150 models, 2019. Untextured and unanimated per the page icons. Contents not itemised on the page. |
| Quaternius Stylized Tree Pack | https://quaternius.com/packs/stylizedtree.html | Quaternius | CC0 (page) | No | FBX, OBJ, Blend | n/s | 2 | 45 "animal crossing style" trees: friendly, round canopies. Off-tone for the fog forest, fits Floracion/the kids' meadow. |
| Roblox Creator Store low-poly pine and dead-tree sets | see the existing shortlist in section 9 (assetIds 8559395722, 8973577087, 137855240779954) | various | per-asset, **UNVERIFIED** | **UNVERIFIED** | Roblox models | n/s | 3 | Already shortlisted in `assets/exports/toolbox-candidates/` with thumbnails; not duplicated here. |

## 3. Rocks, logs and stumps

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Stylized Nature MegaKit rocks: Rock Medium, Rock Path (square/round, small/thin/wide), Pebble Round, Pebble Square | https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm | Quaternius | CC0 (bundle and each listed model) | No | FBX, GLTF | n/s | 4 | 27 rocks in the full pack. Moss-boulder stand-in. No logs or stumps are itemised in the pack text or the Poly Pizza list. |
| Kenney Survival Kit: Rock, Rock Flat, Rock Flat Grass, Resource Stone, Tree Fall, Tree Fall Large, Twig | https://kenney.nl/assets/survival-kit ; https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH | Kenney | CC0 (asset page, itch page, all 43 Poly Pizza models) | No | OBJ, FBX, glTF (itch page: "over 70" models; asset page says 80 files) | n/s | 4 | Fallen trees are the closest verified "log" source in the CC0 set. Counts differ between pages (43, 70+, 80). |
| Quaternius Wood Log | https://poly.pizza/m/L4E32Wee6C | Quaternius | CC0, https://creativecommons.org/publicdomain/zero/1.0/ (model page) | No | FBX, GLTF | n/s | 4 | Also in Survival Pack. Plain log for wood piles. |
| KayKit Halloween Bits: Rocks | https://poly.pizza/bundle/Halloween-Bits-5J1jHdy21M | Kay Lousberg | CC0 | No | FBX, GLTF | n/s | 4 | One model named "Rocks" in the bundle. |
| Poly Pizza tree stumps (Jarlan Perez https://poly.pizza/m/2ohXf_yaPki , Poly by Google https://poly.pizza/m/cnDk3EzC3Gs) | as listed | Poly Pizza | **UNVERIFIED** (licence not opened per model; Poly by Google models seen elsewhere were CC BY 3.0) | assume yes until verified | OBJ/GLTF/FBX | n/s | 2 | Only if no CC0 stump is found; authoring `FK_AxeStump` (already planned) is the better route. |
| Kenney Nature Kit | https://kenney.nl/assets/nature-kit | Kenney | CC0 | No | see section 2 | n/s | 4 | Likely holds logs and stumps in its 330 files; **UNVERIFIED** (no itemised list found). |

## 4. Mushrooms and glowing plants

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Mushroom Laetiporus (shelf fungus) | https://poly.pizza/m/mxDOl0n6zt | Quaternius (Stylized Nature MegaKit) | CC0, https://creativecommons.org/publicdomain/zero/1.0/ | No | FBX, GLTF | n/s | 5 | Bracket fungus: right shape for the `FK_FallenLog` shelf fungi and `FK_LanternFungus` clusters. |
| Mushroom (also in the MegaKit) | https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm | Quaternius | CC0 (bundle, each model) | No | FBX, GLTF | n/s | 4 | Quaternius's own page does not mention mushrooms; the Poly Pizza list does. Treat as present but confirm in the downloaded Standard zip. |
| Kenney Mushroom, Mushroom Half | https://poly.pizza/m/A2rwQyfqYG (Mushroom, CC0 verified), https://poly.pizza/m/Rya1QwSsEE (Half, licence not individually opened) | Kenney | CC0 (first one verified) | No | OBJ, GLTF | n/s | 4 | Simple flat-colour caps. |
| Quaternius single mushrooms: https://poly.pizza/m/db1tjMhmiA , https://poly.pizza/m/aOW08oSrd4 , https://poly.pizza/m/uJm9Hgz0fG | as listed | Quaternius | CC0 expected (same creator, same pattern) but **UNVERIFIED per model** | No (if CC0) | FBX, GLTF | n/s | 4 | Names only seen in search results. |
| log with fungus | https://poly.pizza/m/32czhZtc7oY | sirkitree | CC BY 3.0, https://creativecommons.org/licenses/by/3.0/ | **Yes** | OBJ, GLTF | n/s | 3 | Nice combined prop but needs a credit. Prefer building a log plus fungus ourselves. |
| Glow caps | none found in a CC0 pack | n/a | n/a | n/a | n/a | n/a | n/a | Glowing is an emission colour (`3FB8A6`, emission 0.35) plus a PointLight, not a mesh property. Take any CC0 mushroom, recolour caps in Blender, keep a separate material for the glow. |
| Bushes, ferns, flowers (for berry thicket and Floracion) | https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm (Bush, Bush with Flowers, Plant, Plant Big, Fern, Clover, Flower Group) | Quaternius | CC0 | No | FBX, GLTF | n/s | 4 | Existing toolbox candidates for mushrooms and foliage are in section 9. |

## 5. Camp and lobby props (campfire, tents, fences, lanterns, crates, training device)

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Kenney Survival Kit: Campfire, Tent, Tent Half, Tent Frame, Bedroll, Fence Fortified, Fence Frame, Signpost, Barrel, Box, Chest, Workbench, Workbench Grind, Workbench Anvil, Structure/Roof/Cloth | https://kenney.nl/assets/survival-kit ; per-model list at https://poly.pizza/bundle/Survival-Kit-yGnSPFp2lH | Kenney | CC0 (all 43 listed models CC0) | No | OBJ, FBX, glTF | n/s | 4 | Best single camp source: campfire, tents, fences, crates, a hut frame and workbenches in one CC0 pack. "Workbench Grind" is a grindstone: a possible base for a crank/training device, **UNVERIFIED** (not viewed). |
| Quaternius Survival Pack: Tent, Bonfire, Wood Log, Torch, Wooden Torch, Backpack, Axe, Bear Trap, Pot | https://quaternius.com/packs/survival.html ; list at https://poly.pizza/bundle/Survival-Pack-XzvQPP0yWB | Quaternius | CC0 (both) | No | FBX, OBJ, Blend (pack page); FBX + GLB on Poly Pizza | n/s | 4 | 53 models on the page, 32 on Poly Pizza. Single model pages verified CC0: Tent https://poly.pizza/m/5Q7qIrfDxA , Bonfire https://poly.pizza/m/Azj9hJwwwG , Torch https://poly.pizza/m/WGsvr4KOZd . |
| Quaternius Medieval Village Pack: Fence, Crate, Barrel, Well, Cart, Hay, Bags, Bench x2, Bonfire, Cauldron, Market Stand | https://poly.pizza/bundle/Medieval-Village-Pack-NsHhjhlrfY ; https://quaternius.com/packs/medievalvillage.html | Quaternius | CC0 (Poly Pizza bundle: "Public Domain (CC0)"); the quaternius.com pack page was not itself fetched, so its wording is **UNVERIFIED** | No | FBX + GLB/GLTF | n/s | 3 | Good wooden dressing for the camp and the shelter. No lantern or tent in this pack. The buildings are brighter than the fog palette, recolour needed. |
| KayKit Halloween Bits: Lantern, Hanging Lantern, Post Lantern, Candle(s), Post, Fence, Bench | https://poly.pizza/bundle/Halloween-Bits-5J1jHdy21M ; lantern https://poly.pizza/m/CtHBJ1ufeW | Kay Lousberg | CC0 (Lantern model page verified) | No | FBX, GLTF | n/s | 5 | The lantern and post-lantern shapes are the closest verified match to `FK_LanternMarker`; they carry no glass or light, which we add (emission `F08C2E` plus PointLight). |
| Quaternius Fantasy Props MegaKit | https://quaternius.com/packs/fantasypropsmegakit.html | Quaternius | CC0 (page) | No | FBX, OBJ, glTF | n/s | 3 | 211 models: weapons, tools, potions, market stalls, chests, furniture. The page does not list campfire, tents, lanterns, crates or fences. |
| Small Camping Bundle (Fire, Campfire, Log W/ Axe, Log, Rock, Tent, Tree, Island) | https://poly.pizza/bundle/Small-Camping-Bundle-zN9HrtTray | J-Toastie | **CC BY 3.0** | **Yes** | per model page | n/s | 3 | Not recommended: same roles are covered by CC0 packs above. |
| Training device / treadmill | none found in a CC0 pack | n/a | n/a | n/a | n/a | n/a | n/a | No verified CC0 treadmill or running wheel on Quaternius, Kenney, KayKit or Poly Pizza searches. Recommendation: author a running wheel or crank stand from primitives (the sandbox-friendly option) rather than a Creator Store treadmill. See section 9 for what the Creator Store returned. |

## 6. Nest and egg props

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Egg | https://poly.pizza/m/ngjyRi84lk | Quaternius | CC0, https://creativecommons.org/publicdomain/zero/1.0/ | No | FBX, GLTF | n/s | 3 | Plain egg. Wildbound's eggs carry rarity (normal, rare, special) and will be our own meshes; this is a placeholder for greybox and a proportion reference. |
| Birds nest | https://poly.pizza/m/fq_bAKD1Khg | Poly by Google | **CC BY 3.0**, https://creativecommons.org/licenses/by/3.0/ | **Yes** | OBJ, GLTF | n/s | 3 | The only nest model that surfaced; needs credit. Our own faceted nest is simpler and avoids the credit. |
| Hay (Medieval Village Pack) | https://poly.pizza/bundle/Medieval-Village-Pack-NsHhjhlrfY | Quaternius | CC0 (bundle) | No | FBX, GLB | n/s | 3 | Base for a straw nest bed. |
| Creator Store "Robins Nest" and egg-nest uploads | see section 9 | various | **UNVERIFIED** | **UNVERIFIED** | Roblox models | n/s | 2 | Several search hits are tag-spam listings. Do not use without inspection. |

## 7. Ambient wildlife (small animals, birds, fireflies)

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Bird | https://poly.pizza/m/gYYC0gYMnw | Quaternius | CC0 (verified on model page) | No | FBX, GLTF | n/s | 4 | Animation not stated on the page. Also on Poly Pizza from Quaternius: Pigeon https://poly.pizza/m/9NGlBTpDEr , Chicken https://poly.pizza/m/ineV9pU5VL , Bat https://poly.pizza/m/hNO9XvjlKa , Armabee https://poly.pizza/m/42djT5zJnx (those four licences not individually opened, **UNVERIFIED**, expected CC0). |
| Frog | https://poly.pizza/m/9Z2V8fpazF | Quaternius | CC0 (verified); tagged Animated | No | FBX, GLTF | n/s | 4 | Swamp ambience. |
| Ultimate Animated Animal Pack (12: Cow, Donkey, Deer, Alpaca, Bull, Fox, Shiba Inu, Stag, Husky, Wolf, White Horse, Horse; 12+ animations each) | https://quaternius.com/packs/ultimateanimatedanimals.html ; https://poly.pizza/bundle/Animated-Animal-Pack-ILAPXeUYiS | Quaternius | CC0 (both) | No | FBX, OBJ, Blend, glTF | n/s | 3 | Medium-size fauna (Deer, Fox, Wolf, Stag) for far-field ambience or a non-aggressive herd; not "small animals". Rigged, so check Roblox animation import limits (**UNVERIFIED**). |
| Farm Animal Pack | https://quaternius.com/packs/farmanimal.html | Quaternius | page not fetched, **UNVERIFIED** (Quaternius pattern is CC0) | **UNVERIFIED** | n/s | n/s | 2 | Farm animals; wrong biome for fog forest, fine for the meadow biome. |
| Fireflies | none found | n/a | n/a | n/a | n/a | n/a | n/a | Not worth a mesh: ParticleEmitter with a small emissive sprite or a handful of Neon parts with slow Heartbeat drift, tinted `3FB8A6` or warm `F08C2E`. The existing toolbox candidates `props-luciernagas-*` are in section 9. Poly Pizza searches for "firefly" returned flies, dragonflies and moths from CC BY creators only (Dragonfly, Lil' Moth). |

## 8. Swamp and cemetery props (later biomes)

| Name | URL | Source | Licence (page) | Attribution | Formats | Tri count | Fit | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Halloween Bits cemetery set: Gravestone x2, Grave x2, Damaged Grave, Grave Marker, Gravemarker, Coffin x2, Crypt, Shrine x2, Arch, Arch Gate, Iron Fence, Damaged Iron fence, Fence Gate, Pillar, Plaque, Bone x4, Skull, Ribcage, Candles, Path, Dirt tiles | https://kaylousberg.itch.io/halloween-bits ; list at https://poly.pizza/bundle/Halloween-Bits-5J1jHdy21M | Kay Lousberg | CC0 (itch page and Poly Pizza bundle, all 63 CC0) | No | OBJ, FBX, glTF | n/s | 5 | Best match for the cemetery biome and the `FK_BonePile`, `FK_ColdCamp` accent props (bones, skull, ribcage; the aesthetic reference says never deer or human, so keep to "unknown animal" bones and skip the human-looking skull). 1024x1024 gradient atlas. |
| Kenney Graveyard Kit | https://kenney.nl/assets/graveyard-kit ; https://kenney-assets.itch.io/graveyard-kit | Kenney | CC0 ("CC0 1.0 Universal ... commercial ... attribution not required, though appreciated") | No | The itch page does not list formats; OpenGameArt snippet says FBX, OBJ, glTF. **UNVERIFIED on kenney.nl** | n/s | 4 | Tags: graveyard, halloween, horror, monster, spooky. Model count conflicts (80 on itch.io, 90 on kenney.nl); includes animated characters (some may be monsters, check before use, the Wildbound brief forbids gore). |
| Quaternius Ultimate Modular Ruins Pack | https://quaternius.com/packs/ultimatemodularruins.html | Quaternius | CC0 (page) | No | FBX, OBJ, Blend | n/s | 3 | 90 models: modular ruins, dungeons, props, one animated character. Graveyard contents not confirmed. Reference for the ruined doorway. |
| Quaternius Lilypad | https://poly.pizza/m/TI6ukUlsLh | Quaternius | CC0 (verified) | No | FBX, GLTF | n/s | 4 | Marsh water decoration. |
| Cattail, Lily pad, Water lilies | https://poly.pizza/m/9uT74BMpRrl (Cattail verified CC BY 3.0); https://poly.pizza/m/0-_GjMekeob , https://poly.pizza/m/birD7XV2A44 (not opened) | Poly by Google | **CC BY 3.0** (Cattail verified) | **Yes** | OBJ, GLTF | n/s | 3 | Only reeds/cattails found; either accept a credit or build reeds from cylinders. |
| Dead trees and Twisted Tree (marsh trunks) | see section 2 (Stylized Nature MegaKit, Halloween Bits) | Quaternius, Kay Lousberg | CC0 | No | see section 2 | n/s | 4 | Reuse the same sets; recolour grey-green. |
| Swamp props (Creator Store) | see section 9 | various | **UNVERIFIED** | **UNVERIFIED** | Roblox models | n/s | 2 | Results are tag-stuffed re-uploads; avoid. |

## 9. Roblox Creator Store (read-only `search_asset`) and the existing shortlist

Searched 2026-11-10 with `search_asset` (scope `creator_store`, free only, Model) on the Studio instance named "Experiencia sin titulo (placeId 122652861404212)"; one instance listed. No `insert_asset`, no `execute_luau`, no DataModel change.

**Already shortlisted (do not duplicate):** `docs/design/wildbound-forest-aesthetic-reference.md` section 5 and the thumbnails in `assets/exports/toolbox-candidates/` (trees 8559395722, 8973577087, 137855240779954; rocks 2128776869, 85389927254160, 5273429987; mushrooms 5345641987, 4644085527, 13411585468; camp 11319964899, 3632483829, 14963743762; plus the `props-luciernagas-*`, `pradera-*` and `beast-*` sets). That list stands; nothing below replaces it.

New results this pass, for completeness only (none opened, none inserted, licence and scripts **UNVERIFIED** for every one; no recommendation):

| Role | assetId and URL | Name | Creator | Note |
| --- | --- | --- | --- | --- |
| Training device | 15920820978, https://create.roblox.com/store/asset/15920820978 | Treadmill ("Working treadmill") | Shadowgames854 | Description implies scripts. Inspect before any look. |
| Training device | 15157317646, https://create.roblox.com/store/asset/15157317646 | Treadmill | rekzanres210 | Same caution. |
| Nest | 455248296, https://create.roblox.com/store/asset/455248296 | Robins Nest | Glistreal | Old upload, unclear contents. |
| Swamp | 12553874955, https://create.roblox.com/store/asset/12553874955 | Low Poly Swamp | whitety | Plain title, unclear contents; the other "swamp" hits (for example 140376397842141, 107358222245709) carry tag-stuffed titles from generated-looking accounts. |
| Graveyard | 93229905315733, https://create.roblox.com/store/asset/93229905315733 | Low Poly Zombie Spawn Graveyard Tombstone | BaseplateUpl0ader | Description is keyword spam ("Trending Tags - [IGNORE]"). |

Overall: for graveyard, swamp, nest and treadmill the Creator Store returned mostly low-quality, tag-spam or script-risk uploads. The pack route (CC0 meshes imported through the 3D Importer, no scripts) is safer and has clearer licences, at the cost of a Blender pass and a user-approved upload.

## 10. Recommended starter set (12 picks, all CC0)

| # | Pick | URL | Licence | Why |
| --- | --- | --- | --- | --- |
| 1 | Quaternius Stylized Nature MegaKit (Standard tier): trees, Twisted Tree, Pine, rocks, Mushroom Laetiporus, bushes | https://quaternius.com/packs/stylizednaturemegakit.html (list: https://poly.pizza/bundle/Stylized-Nature-MegaKit-T34GZFA0fm) | CC0 | One pack covers three tree silhouettes, ground rocks, shelf fungus and bushes; textured and recolourable; licence line is explicit. |
| 2 | KayKit Forest Nature Pack (free tier) | https://kaylousberg.itch.io/kaykit-forest | CC0 1.0 | 100+ trees, rocks, bushes and grass on one gradient atlas: cheapest to recolour to the Wildbound palette and light for phones. |
| 3 | KayKit Halloween Bits | https://kaylousberg.itch.io/halloween-bits | CC0 1.0 | The cemetery biome, lanterns, bones, dead trees and fences in one pack; mentions Roblox. |
| 4 | Kenney Survival Kit | https://kenney.nl/assets/survival-kit | CC0 | Campfire, tents, fences, barrels, chests, fallen trees and workbenches for the camp hub; clearest CC0 statement of the major sources. |
| 5 | Kenney Nature Kit | https://kenney.nl/assets/nature-kit | CC0 | 330 files for flat-colour trees and rocks; fills gaps. File list **UNVERIFIED**. |
| 6 | Quaternius Ultimate Stylized Nature Pack (birch, pine, dead trees) | https://quaternius.com/packs/ultimatestylizednature.html | CC0 | Birch stand-in for Abedul Palido and a second pine set. |
| 7 | Quaternius Survival Pack (Tent, Bonfire, Wood Log, Torch, Backpack, Bear Trap) | https://quaternius.com/packs/survival.html | CC0 | Second camp source; Bear Trap and Backpack are cheap story dressing for abandoned camps. |
| 8 | Quaternius Medieval Village Pack (Fence, Crate, Barrel, Well, Cart, Hay) | https://poly.pizza/bundle/Medieval-Village-Pack-NsHhjhlrfY | CC0 | Wooden dressing for camp and shelter; Hay doubles as nest bedding. |
| 9 | KayKit Lantern (and Post Lantern, Hanging Lantern) | https://poly.pizza/m/CtHBJ1ufeW | CC0 | Faceted lantern shape to compare with `FK_LanternMarker`. |
| 10 | Quaternius Mushroom Laetiporus | https://poly.pizza/m/mxDOl0n6zt | CC0 | Bracket fungus for logs and the teal fungus breadcrumbs. |
| 11 | Quaternius Bird, Frog, Lilypad | https://poly.pizza/m/gYYC0gYMnw , https://poly.pizza/m/9Z2V8fpazF , https://poly.pizza/m/TI6ukUlsLh | CC0 | Ambient wildlife and marsh dressing; the Frog is tagged animated. |
| 12 | Quaternius Egg | https://poly.pizza/m/ngjyRi84lk | CC0 | Greybox egg for nest layout; final eggs stay our own. |

Why this set: it is CC0 end to end (no credit file, no CC BY risk), mesh-only (no Luau to audit), covers every role except fireflies and the training device (author those), and keeps to three sources whose licence statements were read on 2026-11-10. Suggested use: scout in Blender first, convert to the FK_ conventions, and keep `FK_` kit geometry for the hero silhouettes (Pino Velador, hunched oak, claw marks) where the pack meshes do not fit the readability rules.

## 11. Things to avoid

- **Creator Store models you have not opened.** Tag-stuffed titles ("Low Poly Swamp Crocodile In Wooden Crate Box"), "Trending Tags - [IGNORE]" descriptions, uploads by "Content Deleted" creators (provenance and licence cannot be checked), "Uploaded by DependencyInjector" re-uploads, and any model containing Scripts, obfuscated code, `require(<assetId>)` or `loadstring`. Roblox's own docs warn such assets can load another model at runtime.
- **CC BY 3.0 models without a credit plan**: J-Toastie's Small Camping Bundle, all "Poly by Google" models (Cattail, Lily pad, Birds nest, Tent, Campfire), NicolasBrueckner's Tree Collection, sirkitree's "log with fungus", the Witch cottage bundle's CC BY entries. Usable only with visible credit; Roblox's expectation for that credit is UNVERIFIED.
- **Fan recreations of 99 Nights in the Forest** (the Sketchfab CC BY sets mentioned in the aesthetic reference): derivative of a specific game's assets and not needed.
- **The Fab "Stylized Nature Mega Bundle" (NinjaFroggy) and other third-party bundles with similar names**: different creators and licences from Quaternius's MegaKit.
- **Quaternius "Pro" and "Source" tiers**: paid (Pro from $9.99, Source from $14.99 per the itch.io page); the Standard tier is enough, and the Source tier's Unity/Unreal/Godot projects are irrelevant to Roblox.
- **Unity Asset Store packs surfaced by Poly Pizza (for example Synty POLYGON Swamp Marshland)**: different licence, UNVERIFIED for Roblox use.
- **Rigged or animated packs** unless animation import is tested: the Animated Animal Pack and Kenney Graveyard Kit characters bring skeletons and clips whose Roblox import is UNVERIFIED.
- **Anything with gore** (the brief is kids plus horror, "no gore"), including human-looking skulls and ribcages.
- **Importing OBJ when FBX or glTF exists**: Kenney discourages OBJ and the importer docs do not list vertex-colour or PBR support for it.
- **Pre-baked textures with lighting**: any pack texture with baked shadows will fight the fog and flashlight; use gradient atlases or vertex colours only.

## 12. What could not be verified

- Triangle counts: no source page states them (Poly Pizza model pages show none). All "n/s".
- Style fit scores: estimated from text; thumbnails and models were not viewed.
- Itemised contents of Kenney Nature Kit (stumps, logs, mushrooms, tents) and of Quaternius Ultimate Nature Pack; the file formats listed on the Nature, Graveyard and Fantasy Town asset pages (not stated in text).
- Which Stylized Nature MegaKit models are in the free Standard tier (pack page: about 60-70 percent; itch.io caption: 81 assets; counts of 110, 116 and 118 all appear on the same pages).
- Quaternius pack pages for Medieval Village Pack, Farm Animal Pack and the individual Quaternius single-model licences not opened (Bird, Egg, Wood Log, Bonfire, Torch, Tent, Frog, Lilypad, Dead Tree and Mushroom Laetiporus were opened and are CC0; Pigeon, Chicken, Bat, Armabee and the other single mushrooms were not).
- Roblox's official position on in-experience credits for CC BY content and on third-party uploaded meshes; the Creator Terms were not fetched.
- Whether the Roblox 3D Importer handles Kenney GLB files and rigged animal packs cleanly (importer docs list glTF and FBX; not tested).
- Per-asset licence and script contents of every Creator Store result in section 9.
- Quaternius, Kenney and KayKit pages could change; all statements are as fetched on 2026-11-10. Poly Pizza's front page and API docs fetched as text showed no licence terms; per-model pages did.
- Blocked in this pass: OpenGameArt pages (HTTP 403) and `https://kenney-assets.itch.io/nature-kit` (404).
