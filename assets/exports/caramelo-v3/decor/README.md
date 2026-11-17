# Caramelo v3 decor kit (CV3_)

Built by `tools/build-caramelo-v3-decor-kit.py` from the owner's reference sheets 04 to 10 in
`assets/reference/caramelo-v3/`. Contract: `tools/caramelo_v3_decor_spec.py`; tests:
`tools/test_caramelo_v3_decor_kit.py`. Status: **unvalidated**, never imported into Roblox.

## Conventions

- 1 Blender unit = 1 stud, `FBX_SCALE_ALL`, like the other biome kits. Pivot (an Empty root named
  after the asset) at the ground centre of the base. Front is Blender -Y (Roblox -Z).
- One mesh per colour, named `<Asset>_<Part>`, flat-shaded, one matte material named like the mesh.
  Colour travels as the material colour; the importer sets `MeshPart.Color` from
  `caramelo-v3-decor-spec.json` (same plan as `WildboundCandyKit.luau`).
- **No mesh collides.** Each asset lists simple `Collision_*` parts (blocks and upright cylinders,
  Blender axes, cylinder size = diameter, diameter, height) in `caramelo-v3-decor-spec.json` and in
  `assets/blender/caramelo-v3-decor/caramelo-v3-decor-report.json`. Blender to Roblox: X = -x, Y = z, Z = y.
- Sizes below are bounding boxes in studs (x by y by z, z up). Triangle counts are the exported totals.

## Files

| FBX | Size (studs) | Tris | Visual meshes | Collision parts |
| --- | --- | --- | --- | --- |
| `CV3_TreeCotton.fbx` | 16.8 x 16.6 x 25.8 | 1266 | Trunk, Stripe, **Crown** | Collision_Trunk (cylinder 2.5 wide) |
| `CV3_TreeIceCream.fbx` | 18.4 x 17.6 x 26.8 | 1282 | Trunk, **Crown, CrownChips, CrownCherry** | Collision_Trunk (cylinder 2.8 wide) |
| `CV3_TreeCaramelApple.fbx` | 15.4 x 15.8 x 24.0 | 492 | Trunk, **Crown** (glaze), **CrownApple** | Collision_Trunk (cylinder 2.4 wide) |
| `CV3_IceCreamMountain_L.fbx` | 103.4 x 99.6 x 90.4 | 2696 | Base, Rocks, Fudge, Sauce, Scoop, Berries, Cherry, CherryStem, *River, Waterfall, Pool, PoolLip* | Core, Upper, Summit, Scoop cylinders; 10 Skirt blocks (none in the waterfall notch) |
| `CV3_IceCreamMountain_M.fbx` | 68.8 x 64.5 x 60.3 | 2696 | same parts as L | same plan as L |
| `CV3_LicoriceArch.fbx` | 77.8 x 12.7 x 33.7 | 2984 | Pink, Orange, Yellow, Green, Blue, Purple (stripes), Clouds | 4 foot blocks where the ribbon meets the ground |
| `CV3_CakeBase.fbx` | 44.3 x 45.0 x 14.8 | 2292 | Body, Band, Frosting, Cookies | Collision_Body (cylinder 40 x 12) |
| `CV3_CakeRamp.fbx` | 10.4 x 28.0 x 12.6 | 96 | Sponge, Cream, Icing | Collision_walk_landing, Collision_ramp (pitched 26.6 deg about X) |
| `CV3_CakeTop.fbx` | 27.8 x 31.7 x 15.0 | 1758 | Body, Band, Frosting, Candles, Neon_Flames | Collision_Body (cylinder 26 x 9) |
| `CV3_CookieS.fbx` | 7.7 x 7.8 x 1.75 | 206 | Dough, Chips | Collision_Slab (cylinder, top at 1.6) |
| `CV3_CookieM.fbx` | 13.5 x 13.3 x 2.15 | 302 | Dough, Chips | Collision_Slab (cylinder, top at 2.0) |
| `CV3_CookieL.fbx` | 23.3 x 23.3 x 2.75 | 478 | Dough, Chips | Collision_Slab (cylinder, top at 2.6) |

`caramelo-v3-decor-spec.json` (next to the FBX files) holds, per asset: size, each piece's object
name, colour and role (`visual`, `sway` or `water`), the `Collision_*` parts, and the extra data below.

## Trees (sway)

The bold meshes are the crown. Weld them together and sway them about `sway.pivot` (the crown base
on the trunk axis) by script; there is no rig. Trunk colliders run from the ground to the crown base.

## Ice-cream mountains: chocolate river and waterfall

A channel runs down the -Y face from under the fudge to a ledge; below the ledge the mountain is cut
back to a vertical cliff, and the waterfall drops from the ledge lip into a pool at the foot. The water
pieces are separate, non-colliding meshes so they can be animated or made transparent:

| Role | L object | M object |
| --- | --- | --- |
| River (channel flow down to the ledge) | `CV3_IceCreamMountain_L_River` | `CV3_IceCreamMountain_M_River` |
| Waterfall sheet (ledge to pool) | `CV3_IceCreamMountain_L_Waterfall` | `CV3_IceCreamMountain_M_Waterfall` |
| Pool surface (top at Z 1.3) | `CV3_IceCreamMountain_L_Pool` | `CV3_IceCreamMountain_M_Pool` |
| Pool lip (rocky rim, two arcs) | `CV3_IceCreamMountain_L_PoolLip` | `CV3_IceCreamMountain_M_PoolLip` |

The pool lip leaves a gap on the -Y side: that is the outlet where the big chocolate river leaves the
mountain (`water.outlet` in the spec JSON gives the point). `water.ledge_z`, `water.pool_center` and
`water.pool_radius` are listed too. No collider covers the pool, the falling water or the outlet.

## Cake modules (snap)

`CV3_CakeBase` top is flat and walkable at Z 12. `CV3_CakeTop` pivot goes on the base's `top_tier`
socket (0, 0, 12). A `CV3_CakeRamp` climbs along its +Y from the ground to Z 12 (pitch 26.6 deg); put
its `high_end` socket against one of the base's `ramp_front/right/back/left` sockets with its +Y facing
the cake centre, so the landing meets the tier top. The top tier is walkable at Z 9 inside its candles.

## Cookie platforms

Flat tops at the walk height (chips rise 0.15 at most), one cylinder collider each, sized for the
chocolate lake: about 8, 14 and 24 studs across.
