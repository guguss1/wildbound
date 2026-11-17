"""Build the Caramelo v3 decor kit (CV3_) in a fresh headless Blender scene.

Run (build, export, render, then re-import every FBX for the round-trip report):
  "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup -P tools/build-caramelo-v3-decor-kit.py
Set CARAMELO_V3_DECOR_MODE=build-only to skip the round trip, or verify-fbx to run only the round trip.
Under plain Python this file does a dry run: it counts triangles and checks closure.

Pieces from the owner's reference sheets (assets/reference/caramelo-v3, 04 to 10): three trees that
replace every tree of the candy biome, two ice-cream mountains with a chocolate waterfall, a rainbow
licorice arch, a modular cake (base tier, ramp, top tier) and three cookie platforms for the lake.

Conventions are the biome kits' (tools/biome_kit_common.py, never edited): 1 Blender unit = 1 stud,
an Empty root at the ground-centre pivot, one closed flat-shaded mesh per colour named
<Asset>_<Part>, one matte material per mesh, FBX_SCALE_ALL. No mesh is meant to collide in Roblox:
the report lists simple Collision_* parts (blocks and upright cylinders) for the importer to build,
the same plan as WildboundCandyKit.luau. Tree crowns are their own meshes so a script can sway them;
the mountain's River, Waterfall and Pool are their own meshes so they can scroll or turn transparent.
All geometry is scripted here; nothing is downloaded or uploaded. Every value is unvalidated.
"""

import math
import os
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import biome_kit_common as bk  # noqa: E402
import caramelo_v3_decor_spec as cs  # noqa: E402
import kit_common as kc  # noqa: E402
from biome_kit_common import no_weight as W  # noqa: E402
from kit_common import add, arc_profile, lathe, loft, loft_closed, tube  # noqa: E402

TAU = math.tau
FRONT = -math.pi / 2  # -Y, the asset front (Roblox -Z)


# ---------------------------------------------------------------------------
# Small geometry helpers
# ---------------------------------------------------------------------------

def polar(radius, angle, z, center=(0.0, 0.0)):
    return (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), z)


def wrap_deg(angle):
    """Signed degrees in (-180, 180]."""
    value = math.degrees(angle) % 360.0
    return value - 360.0 if value > 180.0 else value


def interp(profile, x):
    """Linear interpolation on sorted (x, y) pairs."""
    for (x0, y0), (x1, y1) in zip(profile, profile[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return profile[-1][1] if x > profile[-1][0] else profile[0][1]


def closed_sheet(part, grid, offset):
    """Closed slab from a grid of front points (rows x columns); the back is front + offset(i, j)."""
    rows, cols = len(grid), len(grid[0])
    n = rows * cols

    def idx(i, j):
        return i * cols + j

    front = [p for row in grid for p in row]
    back = [add(grid[i][j], offset(i, j)) for i in range(rows) for j in range(cols)]
    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            a, b, c, d = idx(i, j), idx(i, j + 1), idx(i + 1, j + 1), idx(i + 1, j)
            faces.append((a, b, c, d))
            faces.append((n + d, n + c, n + b, n + a))
    rim = ([idx(0, j) for j in range(cols)] + [idx(i, cols - 1) for i in range(1, rows)]
           + [idx(rows - 1, j) for j in range(cols - 2, -1, -1)] + [idx(i, 0) for i in range(rows - 2, 0, -1)])
    for k, a in enumerate(rim):
        b = rim[(k + 1) % len(rim)]
        faces.append((b, a, n + a, n + b))
    part.add(front + back, faces, W)


def puff(part, center, radius, height, sides, rng, jitter=0.08, steps=4):
    lathe(part, arc_profile(radius, height, steps), sides, W, center=center, jitter=jitter, rng=rng,
          phase=rng.uniform(0.0, 1.0))


def frustum(part, x, y, radius, height, sides, rng, top=0.6):
    """Low faceted boulder."""
    phase = rng.uniform(0.0, TAU)
    lower = [polar(radius * rng.uniform(0.85, 1.1), phase + TAU * k / sides, 0.0, (x, y)) for k in range(sides)]
    upper = [polar(radius * top * rng.uniform(0.8, 1.1), phase + 0.3 + TAU * k / sides, height * rng.uniform(0.85, 1.0),
                   (x, y)) for k in range(sides)]
    loft(part, [lower, upper], W)


def set_anchor(asset, label, meta):
    """Remember one authored vertex so tags can map authored coordinates through fit_asset."""
    asset.meta = meta
    asset.anchor = (label, asset.parts[label].vertices[0])


def mapper(asset):
    label, before = asset.anchor
    after = asset.parts[label].vertices[0]
    scale = asset.fit
    shift = [after[i] - before[i] * scale[i] for i in range(3)]

    def point(p):
        return [round(p[i] * scale[i] + shift[i], 4) for i in range(3)]

    def size(s):
        return [round(abs(s[i] * scale[i]), 4) for i in range(3)]

    return point, size


def collider(name, shape, center, size, yaw_deg=0.0, pitch_deg=0.0):
    return {"name": cs.COLLISION_PREFIX + name, "shape": shape, "center": center, "size": size,
            "yaw_deg": round(yaw_deg, 3), "pitch_deg": round(pitch_deg, 3)}


def walk_colliders(boxes):
    return [collider(b["name"], "block", b["center"], b["size"], 0.0, b["pitch_deg"]) for b in boxes]


# ---------------------------------------------------------------------------
# Trees (sheets 04, 05, 06): trunk collider 2-3 studs wide, crown meshes sway together
# ---------------------------------------------------------------------------

COTTON_TRUNK = [(1.25, 0.0), (1.16, 1.0), (1.06, 6.0), (0.96, 11.5), (0.9, 13.0)]


def build_tree_cotton(a):
    """Candy-cane trunk with two blue helical stripes; a pink cloud of puffs on top."""
    rng = a.rng
    trunk, stripe, crown = a.part("Trunk"), a.part("Stripe"), a.part("Crown")
    lathe(trunk, COTTON_TRUNK, 10, W)
    radius_at = [(z, r) for r, z in COTTON_TRUNK]
    for helix in range(2):
        rings, z, step = [], 0.65, 5.6 / 12
        while z <= 12.4:
            angle = helix * math.pi + TAU * z / 5.6
            r = interp(radius_at, z)
            rings.append([polar(r - 0.1, angle, z - 0.62), polar(r + 0.1, angle, z - 0.62),
                          polar(r + 0.1, angle, z + 0.62), polar(r - 0.1, angle, z + 0.62)])
            z += step
        loft(stripe, rings, W)
    # Crown: a broad cloud, bumpy along its lower edge, rounded on top. Lowest point near Z 10.5.
    puff(crown, (0.0, 0.0, 17.5), 6.6, 6.2, 10, rng)
    for k in range(7):
        angle = TAU * k / 7 + 0.2
        puff(crown, polar(4.9, angle, 14.6 + rng.uniform(-0.4, 0.4)), 3.6 + rng.uniform(-0.3, 0.4), 3.4, 9, rng)
    for k in range(5):
        angle = TAU * k / 5 + 0.7
        puff(crown, polar(3.7, angle, 19.8 + rng.uniform(-0.4, 0.4)), 3.6, 3.4, 9, rng)
    puff(crown, (0.3, -0.2, 22.6), 3.4, 3.2, 9, rng)
    set_anchor(a, "Trunk", {"trunk_radius": COTTON_TRUNK[0][0], "trunk_top": 11.0, "crown_base": 10.5})


def build_tree_ice_cream(a):
    """Twisted red trunk with two limbs; mint scoops with chocolate chips and a cherry."""
    rng = a.rng
    trunk, crown, chips, cherry = a.part("Trunk"), a.part("Crown"), a.part("CrownChips"), a.part("CrownCherry")
    lathe(trunk, [(1.4, 0.0), (1.22, 1.0), (1.02, 6.0), (0.92, 11.0), (0.86, 14.0)], 6, W, twist=0.45)
    for azimuth in (0.6, 3.6):
        c, s = math.cos(azimuth), math.sin(azimuth)
        tube(trunk, [(c * 0.5, s * 0.5, 8.0), (c * 2.6, s * 2.6, 10.6), (c * 4.4, s * 4.4, 12.8)], [0.55, 0.42, 0.3],
             5, W)
    scoops = [(polar(5.0, TAU * k / 5 + 0.3, 15.0 + rng.uniform(-0.3, 0.3)), 4.4) for k in range(5)]
    scoops += [((-1.9, 0.9, 19.4), 4.3), ((2.2, -0.8, 19.6), 4.2)]
    for center, radius in scoops:
        lathe(crown, arc_profile(radius, radius * 0.86, 5, bottom=-40.0), 10, W, center=center, jitter=0.05, rng=rng,
              phase=rng.uniform(0.0, 1.0))
        for _ in range(5):  # chocolate chips sunk into the scoop surface
            azimuth, elevation = rng.uniform(0.0, TAU), math.radians(rng.uniform(5.0, 65.0))
            spot = (center[0] + math.cos(azimuth) * math.cos(elevation) * radius * 0.98,
                    center[1] + math.sin(azimuth) * math.cos(elevation) * radius * 0.98,
                    center[2] + math.sin(elevation) * radius * 0.86 * 0.98)
            kc.box(chips, spot, (0.62, 0.3, 0.28), W, yaw=azimuth + 1.2)
    top = (2.2 + 0.9, -0.8 - 1.1, 19.6 + 4.2 * 0.86 * 0.86 + 0.7)
    lathe(cherry, arc_profile(1.35, 1.25, 4), 8, W, center=top)
    tube(chips, [(top[0], top[1], top[2] + 1.0), (top[0] + 0.3, top[1] + 0.2, top[2] + 2.4),
                 (top[0] + 1.2, top[1] + 0.4, top[2] + 3.3)], [0.18, 0.15, 0.12], 4, W)
    set_anchor(a, "Trunk", {"trunk_radius": 1.4, "trunk_top": 12.0, "crown_base": 11.0})


def build_tree_caramel_apple(a):
    """A stick with a big caramel apple: red glaze over the top, drips down onto the green apple."""
    rng = a.rng
    trunk, glaze, apple = a.part("Trunk"), a.part("Crown"), a.part("CrownApple")
    lathe(trunk, [(1.2, 0.0), (1.15, 6.0), (1.1, 12.0)], 8, W)
    cz, radius, squash = 16.6, 7.4, 0.93
    lathe(apple, arc_profile(radius, radius * squash, 8), 16, W, center=(0.0, 0.0, cz), jitter=0.02, rng=rng)
    sides, rings = 28, []
    outer = radius * 1.07
    for latitude in (62.0, 36.0, 14.0):
        lat = math.radians(latitude)
        rings.append([polar(outer * math.cos(lat), TAU * k / sides, cz + outer * squash * math.sin(lat))
                      for k in range(sides)])
    drips = []
    for k in range(sides):
        drip = 0.0 if k % 2 else rng.choice((6.0, 14.0, 24.0, 34.0))
        lat = math.radians(2.0 - drip)
        drips.append(polar(outer * math.cos(lat), TAU * k / sides,
                           cz + outer * squash * math.sin(lat)))
    rings.append(drips)
    loft(glaze, rings, W, start=(0.0, 0.0, cz + outer * squash), end=(0.0, 0.0, cz - 2.5))
    set_anchor(a, "Trunk", {"trunk_radius": 1.2, "trunk_top": cz - radius * squash, "crown_base": cz - radius})


def tags_tree(a):
    point, size = mapper(a)
    m = a.meta
    d = 2 * m["trunk_radius"]
    names = [f"{a.name}_{label}" for label in cs.SPECS[a.name]["sway"]]
    return {"collision": [collider("Trunk", "cylinder", point((0.0, 0.0, m["trunk_top"] / 2)),
                                   size((d, d, m["trunk_top"])))],
            "sway": {"objects": names, "pivot": point((0.0, 0.0, m["crown_base"])),
                     "note": "rotate these meshes together about the pivot; no rig"}}


# ---------------------------------------------------------------------------
# Ice-cream mountain (sheet 07) with the chocolate river, waterfall and pool
# ---------------------------------------------------------------------------

MOUNTAIN_PROFILE = [(0.0, 1.0), (0.06, 0.93), (0.18, 0.80), (0.30, 0.67), (0.40, 0.585), (0.52, 0.47),
                    (0.64, 0.36), (0.74, 0.24), (0.80, 0.0)]
LEDGE, SOURCE = 0.40, 0.58
CLIFF_DEG, GROOVE_DEG, RIVER_DEG = 30.0, 16.0, 15.0
NOTCH_OFFSETS = (-30.0, -23.0, -16.0, -8.0, 0.0, 8.0, 16.0, 23.0, 30.0)
MOUNTAIN_LEVELS = (0.0, 0.06, 0.18, 0.30, LEDGE - 0.0025, LEDGE, 0.52, SOURCE, 0.64, 0.74)
POOL_SURFACE = 1.3


def mountain_angles():
    offsets = list(NOTCH_OFFSETS) + [12.0 * k for k in range(3, 28)]  # 36 .. 324 degrees
    return [(wrap_deg(math.radians(o)), FRONT + math.radians(o)) for o in offsets]


def mountain_shape(H, R, depth):
    def rp(zf):
        return interp(MOUNTAIN_PROFILE, zf) * R

    rc = rp(LEDGE) - depth
    return rp, rc


def build_mountain(a, H, R, depth, pool_radius):
    rng = a.rng
    k = R / 50.0
    base, rocks = a.part("Base"), a.part("Rocks")
    fudge, sauce, scoop = a.part("Fudge"), a.part("Sauce"), a.part("Scoop")
    berries, cherry, stem = a.part("Berries"), a.part("Cherry"), a.part("CherryStem")
    river, fall, pool, lip = a.part("River"), a.part("Waterfall"), a.part("Pool"), a.part("PoolLip")
    rp, rc = mountain_shape(H, R, depth)
    angles = mountain_angles()

    # Base: a faceted cone. In the front sector it is cut back to a vertical cliff below the ledge, and a
    # groove (the river channel) runs from the source under the fudge down to the ledge lip.
    rings = []
    for level, zf in enumerate(MOUNTAIN_LEVELS):
        ring = []
        for off, angle in angles:
            r, z = rp(zf), zf * H
            notch = abs(off) <= CLIFF_DEG + 1e-6
            if notch and zf < LEDGE - 1e-9:
                r = min(r, rc)
            if abs(off) <= GROOVE_DEG + 1e-6 and LEDGE - 1e-9 <= zf <= SOURCE + 1e-9:
                r -= depth
            if not notch and level in (1, 2, 3):
                r *= 1.0 + rng.uniform(-0.045, 0.045)
                z += rng.uniform(-0.012, 0.012) * H
            elif not notch and level == 0:
                r *= 1.0 + rng.uniform(-0.03, 0.03)
            ring.append(polar(r, angle, z))
        rings.append(ring)
    loft(base, rings, W, end=(0.0, 0.0, 0.80 * H))

    def band(part, z_top, z_bottom, drip_range, thick, sides, phase, cave_bottom=None):
        rows = [[] for _ in range(5)]
        for i in range(sides):
            angle = FRONT + phase + TAU * i / sides
            off = abs(wrap_deg(angle - FRONT))
            zb = z_bottom
            if off < CLIFF_DEG + 6.0:
                if cave_bottom is not None and off <= GROOVE_DEG + 2.0:
                    zb = cave_bottom
            elif i % 2 == 0:
                zb -= rng.uniform(*drip_range)
            zm = (z_top + zb) / 2
            for row, (zz, extra) in enumerate(((z_top, thick), (zm, thick), (zb, thick * 0.8), (zb, -0.9 * k),
                                               (z_top, -0.9 * k))):
                rows[row].append(polar(rp(zz / H) + extra, angle, zz))
        loft_closed(part, rows, W)

    band(fudge, 0.605 * H, 0.52 * H, (0.04 * H, 0.15 * H), 1.3 * k, 40, 0.04, cave_bottom=(SOURCE + 0.01) * H)
    band(sauce, 0.665 * H, 0.60 * H, (0.02 * H, 0.07 * H), 2.0 * k, 36, 0.11)

    # Scoop: a lumpy dome with a rippled lip, strawberry chunks and a cherry on top.
    z0, rs = 0.615 * H, 0.40 * R
    lathe(scoop, [(rs * 0.92, 0.0), (rs * 1.04, 0.08 * H), (rs * 0.98, 0.16 * H), (rs * 0.80, 0.24 * H),
                  (rs * 0.50, 0.29 * H), (0.0, 0.31 * H)], 18, W, center=(0.0, 0.0, z0), jitter=0.04, rng=rng)
    for i in range(10):
        angle = TAU * i / 10 + 0.15
        puff(scoop, polar(rs * 1.0, angle, z0 + 0.02 * H), 3.2 * k, 2.6 * k, 6, rng, jitter=0.06, steps=3)
    for i in range(9):
        angle = TAU * i / 9 + rng.uniform(-0.2, 0.2)
        t = rng.uniform(0.07, 0.22) * H
        r = interp([(0.0, rs * 0.92), (0.08 * H, rs * 1.04), (0.16 * H, rs * 0.98), (0.24 * H, rs * 0.80)], t)
        lathe(berries, [(0.0, -1.2 * k), (1.5 * k, 0.0), (0.0, 1.2 * k)], 4, W,
              center=polar(r * 0.99, angle, z0 + t), frame=kc.basis((math.cos(angle), math.sin(angle), 0.5)),
              phase=rng.uniform(0.0, 1.0))
    top = z0 + 0.31 * H
    cherry_r = 0.05 * H
    lathe(cherry, arc_profile(cherry_r, cherry_r * 0.92, 4), 10, W, center=(0.0, 0.0, top + cherry_r * 0.75))
    stem_base = top + cherry_r * 1.5
    tube(stem, [(0.0, 0.0, stem_base - 0.3), (0.4 * k, 0.2 * k, stem_base + 3.0 * k),
                (2.0 * k, 0.5 * k, stem_base + 6.0 * k)], [0.45 * k, 0.38 * k, 0.28 * k], 4, W)

    # Pink rock boulders around the foot, clear of the waterfall notch.
    placed = 0
    while placed < 12:
        angle = rng.uniform(0.0, TAU)
        if abs(wrap_deg(angle - FRONT)) < CLIFF_DEG + 14.0:
            continue
        frustum(rocks, *polar(R * rng.uniform(0.86, 0.97), angle, 0.0)[:2], R * rng.uniform(0.07, 0.12),
                H * rng.uniform(0.05, 0.11), 6, rng)
        placed += 1

    # River: the chocolate flow in the groove, from under the fudge down to the ledge lip.
    stations = []
    for zf in (SOURCE + 0.005, 0.53, 0.48, 0.44, LEDGE + 0.004):
        floor = rp(zf) - depth
        z = zf * H
        half = math.radians(RIVER_DEG)
        stations.append([polar(floor + 0.05, FRONT - half, z), polar(floor + 0.05, FRONT + half, z),
                         polar(floor + 0.9 * k, FRONT + half, z + 0.35 * k),
                         polar(floor + 0.9 * k, FRONT - half, z + 0.35 * k)])
    lip_z = LEDGE * H
    stations.append([polar(rc + 1.4 * k, FRONT - half, lip_z - 0.9 * k), polar(rc + 1.4 * k, FRONT + half, lip_z - 0.9 * k),
                     polar(rc + 2.0 * k, FRONT + half, lip_z - 0.1 * k), polar(rc + 2.0 * k, FRONT - half, lip_z - 0.1 * k)])
    loft(river, stations, W)

    # Waterfall: one curved sheet that spills off the lip and falls into the pool.
    rows = []
    heights = [lip_z - 0.2 * k, lip_z - 2.5 * k] + [lip_z * f for f in (0.75, 0.5, 0.25)] + [POOL_SURFACE - 0.5]
    radii = [rc + 1.5 * k, rc + 1.3 * k, rc + 1.0 * k, rc + 0.95 * k, rc + 0.95 * k, rc + 1.0 * k]
    columns = [-RIVER_DEG, -RIVER_DEG / 2, 0.0, RIVER_DEG / 2, RIVER_DEG]
    for z, r, narrow in zip(heights, radii, (1.0, 1.0, 0.97, 0.93, 0.89, 0.85)):  # it narrows as it falls
        rows.append([polar(r, FRONT + math.radians(c * narrow), z) for c in columns])
    closed_sheet(fall, rows, lambda i, j: (0.0, -0.8 * k, 0.0))

    # Pool at the foot of the cliff (its back half tucks under the cliff) and a rocky lip in two arcs:
    # one gap opens onto the cliff, the other (-Y) is the outlet where the chocolate river leaves.
    pool_center = (0.0, -(rc + pool_radius - 3.0 * k))  # the back of the pool tucks under the cliff
    lathe(pool, [(pool_radius + 0.3 * k, 0.0), (pool_radius + 0.3 * k, POOL_SURFACE)], 20, W,
          center=(pool_center[0], pool_center[1], 0.0))
    for start, end in ((-62.0, 62.0), (118.0, 242.0)):
        ring_list = []
        count = 11
        for i in range(count):
            theta = math.radians(start + (end - start) * i / (count - 1))
            inner, outer = pool_radius - 0.2 * k, pool_radius + rng.uniform(2.0, 2.8) * k
            height = rng.uniform(1.9, 2.6) * k
            section = ((inner, 0.0), (outer, 0.0), (outer - 0.3 * k, height * 0.6), (inner + 1.2 * k, height),
                       (inner, height * 0.8))
            ring_list.append([polar(rho, theta, z, pool_center) for rho, z in section])
        loft(lip, ring_list, W)

    set_anchor(a, "Base", {"H": H, "R": R, "rc": rc, "depth": depth, "pool_center": pool_center,
                           "pool_radius": pool_radius, "ledge_z": lip_z, "scoop_base": z0, "scoop_radius": rs,
                           "rp": [(zf, rp(zf)) for zf, _ in MOUNTAIN_PROFILE]})


def tags_mountain(a):
    point, size = mapper(a)
    m = a.meta
    H, R, rc = m["H"], m["R"], m["rc"]

    def rp(zf):
        return interp(m["rp"], zf)

    groove_floor = rp(0.52) - m["depth"]
    found = [
        collider("Core", "cylinder", point((0.0, 0.0, m["ledge_z"] / 2)), size((2 * (rc - 0.6), 2 * (rc - 0.6),
                                                                                  m["ledge_z"]))),
        collider("Upper", "cylinder", point((0.0, 0.0, (LEDGE + 0.52) / 2 * H)),
                 size((2 * (groove_floor - 0.5), 2 * (groove_floor - 0.5), (0.52 - LEDGE) * H))),
        collider("Summit", "cylinder", point((0.0, 0.0, (0.52 + 0.62) / 2 * H)),
                 size((2 * (rp(0.64) - m["depth"] - 0.5), 2 * (rp(0.64) - m["depth"] - 0.5), 0.10 * H))),
        collider("Scoop", "cylinder", point((0.0, 0.0, m["scoop_base"] + 0.13 * H)),
                 size((2 * m["scoop_radius"] * 0.92, 2 * m["scoop_radius"] * 0.92, 0.26 * H))),
    ]
    # Skirt blocks fill the lower slope all round except the waterfall notch.
    for tier, (top_f, reach_f) in enumerate(((0.08, 0.90), (0.20, 0.76))):
        inner, outer = rc - 0.6, reach_f * R
        width = 2 * inner * math.tan(math.radians(30.0))
        for off in (60.0, 120.0, 180.0, 240.0, 300.0):
            angle = FRONT + math.radians(off)
            mid = (inner + outer) / 2
            found.append(collider(f"Skirt{tier}_{int(off)}", "block",
                                  point(polar(mid, angle, top_f * H / 2)), size((outer - inner, width, top_f * H)),
                                  yaw_deg=math.degrees(angle)))
    pool_center = m["pool_center"]
    obj = {role: f"{a.name}_{label}" for role, label in cs.SPECS[a.name]["water"].items()}
    water = dict(obj)
    water.update({
        "ledge_z": round(m["ledge_z"] * a.fit[2], 4),
        "pool_surface_z": round(POOL_SURFACE * a.fit[2], 4),
        "pool_center": point((pool_center[0], pool_center[1], POOL_SURFACE)),
        "pool_radius": round(m["pool_radius"] * a.fit[0], 4),
        "outlet": point((pool_center[0], pool_center[1] - m["pool_radius"] - 1.0, POOL_SURFACE)),
        "fall_direction": "down the -Y cliff; the outlet faces -Y (Roblox -Z)",
        "note": "non-colliding; River and Waterfall can scroll a texture, Pool can be semi-transparent",
    })
    return {"collision": found, "water": water}


def build_mountain_l(a):
    build_mountain(a, 84.3, 50.0, 3.0, 11.0)


def build_mountain_m(a):
    build_mountain(a, 56.2, 33.5, 2.2, 7.5)


# ---------------------------------------------------------------------------
# Rainbow licorice arch (sheet 08)
# ---------------------------------------------------------------------------

ARCH_HALF = [(0.0, 31.0), (9.0, 30.4), (15.0, 23.5), (16.6, 9.0), (17.8, 2.4), (19.4, 1.2), (22.0, 1.2),
             (23.4, 3.5), (25.0, 9.5), (28.8, 12.6), (32.6, 9.8), (34.6, 3.6), (35.2, 0.0)]
LICORICE = ("Pink", "Orange", "Yellow", "Green", "Blue", "Purple")  # stripes from -Y (front) to +Y
RIBBON_WIDTH, RIBBON_THICK = 8.4, 2.4


def chaikin(points, rounds):
    for _ in range(rounds):
        out = [points[0]]
        for p, q in zip(points, points[1:]):
            out.append((0.75 * p[0] + 0.25 * q[0], 0.75 * p[1] + 0.25 * q[1]))
            out.append((0.25 * p[0] + 0.75 * q[0], 0.25 * p[1] + 0.75 * q[1]))
        out.append(points[-1])
        points = out
    return points


def arch_path():
    control = [(-x, z) for x, z in reversed(ARCH_HALF[1:])] + ARCH_HALF
    smooth = chaikin(control, 2)
    return smooth[:1] + smooth[1:-1:2] + smooth[-1:]  # every other point keeps the curve and halves the cost


def build_licorice_arch(a):
    """Wavy rainbow ribbon: a tall arch in the middle, a low hump each side, sugar-cloud feet."""
    rng = a.rng
    path = arch_path()
    normals = []
    for i in range(len(path)):
        p, q = path[max(i - 1, 0)], path[min(i + 1, len(path) - 1)]
        tx, tz = q[0] - p[0], q[1] - p[1]
        size = math.hypot(tx, tz)
        normals.append((-tz / size, tx / size))
    strip = RIBBON_WIDTH / len(LICORICE)
    for index, label in enumerate(LICORICE):
        part = a.part(label)
        y0 = -RIBBON_WIDTH / 2 + index * strip
        y1 = y0 + strip
        rings = []
        for (x, z), (nx, nz) in zip(path, normals):
            h = RIBBON_THICK / 2
            rings.append([(x - nx * h, y0, z - nz * h), (x - nx * h, y1, z - nz * h),
                          (x + nx * h, y1, z + nz * h), (x + nx * h, y0, z + nz * h)])
        loft(part, rings, W)
    clouds = a.part("Clouds")
    for foot in (-35.2, -20.7, 20.7, 35.2):
        for dx, dy, r in ((-1.8, -3.8, 2.0), (1.6, -4.4, 1.7), (0.0, 4.6, 1.9), (-2.4, 3.6, 1.5), (2.6, -2.6, 1.4)):
            puff(clouds, (foot + dx, dy, 0.0), r * rng.uniform(0.9, 1.15), r * 0.85, 7, rng, steps=3)
    set_anchor(a, "Pink", {})


def tags_licorice_arch(a):
    """One block around each place where the ribbon meets the ground; overhead ribbon needs no collision."""
    points = [v for label in ("Pink", "Orange", "Yellow", "Green", "Blue", "Purple") for v in a.parts[label].vertices]
    low = [v for v in points if v[2] < 6.0]
    found = []
    for name, lo, hi in (("FootFarLeft", -99.0, -28.0), ("FootLeft", -28.0, 0.0), ("FootRight", 0.0, 28.0),
                         ("FootFarRight", 28.0, 99.0)):
        group = [v for v in low if lo <= v[0] < hi]
        xs, ys = [v[0] for v in group], [v[1] for v in group]
        top = max(v[2] for v in group)
        found.append(collider(name, "block", [round((min(xs) + max(xs)) / 2, 4), round((min(ys) + max(ys)) / 2, 4),
                                              round(top / 2, 4)],
                              [round(max(xs) - min(xs), 4), round(max(ys) - min(ys), 4), round(top, 4)]))
    return {"collision": found}


# ---------------------------------------------------------------------------
# Modular cake (sheet 09): base tier, ramp, top tier
# ---------------------------------------------------------------------------

def cake_tier(a, radius, height, sides, dollops, rng, cookie_count, candles=0):
    body, band, frost, deco = a.part("Body"), a.part("Band"), a.part("Frosting"), None
    lathe(body, [(radius, 0.0), (radius, height), (0.0, height)], sides, W)  # centre vertex: flat walkable fan
    # Lower pink band and the scalloped pink icing drape round the top edge.
    rows = [[] for _ in range(4)]
    for i in range(sides):
        angle = TAU * i / sides
        for row, (r, z) in enumerate(((radius - 0.3, 0.0), (radius + 0.45, 0.0), (radius + 0.45, height * 0.2),
                                      (radius - 0.3, height * 0.2))):
            rows[row].append(polar(r, angle, z))
    loft_closed(band, rows, W)
    rows = [[] for _ in range(5)]
    drape = height * 0.16
    for i in range(sides * 2):
        angle = TAU * i / (sides * 2)
        zb = height - drape - (height * 0.07 if i % 2 == 0 else 0.0)
        for row, (r, z) in enumerate(((radius - 1.4, height + 0.3), (radius + 0.4, height + 0.3), (radius + 0.5, zb),
                                      (radius - 0.3, zb), (radius - 1.4, height - 0.4))):
            rows[row].append(polar(r, angle, z))
    loft_closed(band, rows, W)
    # Whipped-cream dollops on the top rim and round the foot.
    for i in range(dollops):
        angle = TAU * i / dollops + (math.pi / dollops if candles else 0.0)
        lathe(frost, [(1.35, 0.0), (1.2, 0.7), (0.7, 1.5), (0.0, 2.5)], 6, W,
              center=polar(radius - 1.15, angle, height + 0.25), twist=0.4, phase=rng.uniform(0.0, 1.0))
    for i in range(dollops // 2):
        angle = TAU * (i + 0.5) / (dollops // 2)
        lathe(frost, [(1.6, 0.0), (1.4, 0.8), (0.8, 1.7), (0.0, 2.8)], 6, W, center=polar(radius + 1.3, angle, 0.0),
              twist=0.4, phase=rng.uniform(0.0, 1.0))
    cookies = a.part("Cookies") if "Cookies" in cs.SPECS[a.name]["parts"] else band
    for i in range(cookie_count):
        angle = TAU * (i + 0.25) / cookie_count
        axis = (math.cos(angle), math.sin(angle), 0.0)
        lathe(cookies, [(0.0, 0.0), (1.9, 0.0), (1.9, 0.5), (1.3, 0.8), (0.0, 0.85)], 10, W,
              center=polar(radius - 0.05, angle, height * 0.5), frame=kc.basis(axis))
    return deco


def build_cake_base(a):
    """Big round tier, cream with pink bands, dollops and cookie medallions; a flat walkable top at 12."""
    cake_tier(a, 20.0, 12.0, 28, 18, a.rng, 8)
    set_anchor(a, "Body", {"radius": 20.0, "height": 12.0})


def build_cake_top(a):
    """Smaller tier that sits on the base tier; candles with glowing flames ring its walkable top."""
    rng = a.rng
    radius, height = 13.0, 9.0
    cake_tier(a, radius, height, 22, 12, rng, 0, candles=6)
    candles, flames = a.part("Candles"), a.part("Neon_Flames")
    for i in range(6):
        angle = TAU * i / 6
        x, y, _ = polar(9.6, angle, 0.0)
        lathe(candles, [(0.6, height - 0.2), (0.6, height + 4.4), (0.45, height + 4.6)], 6, W, center=(x, y, 0.0),
              twist=0.25)
        lathe(flames, [(0.0, 0.0), (0.42, 0.45), (0.0, 1.4)], 5, W, center=(x, y, height + 4.6))
    medallions = a.part("Band")
    for i in range(6):
        angle = TAU * (i + 0.5) / 6
        lathe(medallions, [(0.0, 0.0), (1.5, 0.0), (1.5, 0.4), (0.0, 0.6)], 8, W,
              center=polar(radius - 0.05, angle, height * 0.55), frame=kc.basis((math.cos(angle), math.sin(angle), 0.0)))
    set_anchor(a, "Body", {"radius": radius, "height": height})


RAMP_RUN, RAMP_LANDING, RAMP_RISE, RAMP_WIDTH = 24.0, 4.0, 12.0, 10.0


def build_cake_ramp(a):
    """Sponge wedge that climbs along +Y from the ground to the base tier top; cream stripe, pink sides."""
    sponge, cream, icing = a.part("Sponge"), a.part("Cream"), a.part("Icing")
    half = (RAMP_RUN + RAMP_LANDING) / 2
    y_top = half - RAMP_LANDING
    outline = [(-half, 0.0), (half, 0.0), (half, RAMP_RISE), (y_top, RAMP_RISE)]
    kc.slab(sponge, outline, (-RAMP_WIDTH / 2, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0),
            RAMP_WIDTH, W)
    slope = RAMP_RISE / RAMP_RUN
    y0 = -half + 1.0
    stripe = [(y0, y0 * 0 + slope * 1.0 - 0.22), (y_top, RAMP_RISE - 0.22), (half, RAMP_RISE - 0.22),
              (half, RAMP_RISE + 0.08), (y_top, RAMP_RISE + 0.08), (y0, slope * 1.0 + 0.08)]
    kc.slab(cream, stripe, (-1.9, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0), (1.0, 0.0, 0.0), 3.8, W)
    for side in (-1, 1):
        rail = [(-half, 0.0), (y_top, RAMP_RISE - 0.1), (half, RAMP_RISE - 0.1), (half, RAMP_RISE + 0.6),
                (y_top, RAMP_RISE + 0.6), (-half + 0.6, 0.6)]
        x0 = side * RAMP_WIDTH / 2 + (0.0 if side > 0 else -0.2)
        kc.slab(icing, rail, (x0 - (0.2 if side > 0 else 0.0), 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
                (1.0, 0.0, 0.0), 0.4, W)
        panel = [(-half + 2.2, 0.4), (half - 0.4, 0.4), (half - 0.4, RAMP_RISE - 1.0), (y_top - 0.4, RAMP_RISE - 1.0)]
        kc.slab(icing, panel, (side * (RAMP_WIDTH / 2 + 0.06) - 0.06, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0),
                (1.0, 0.0, 0.0), 0.12, W)
    set_anchor(a, "Sponge", {})


def tags_cake_tier(a):
    point, size = mapper(a)
    m = a.meta
    r, h = m["radius"], m["height"]
    inner = 22.0 if r > 15 else 12.0
    boxes = [{"name": "walk_top", "center": point((0.0, 0.0, h / 2)), "size": size((inner, inner, h)),
              "pitch_deg": 0.0}]
    collision = [collider("Body", "cylinder", point((0.0, 0.0, h / 2)), size((2 * r, 2 * r, h)))]
    if a.name == "CV3_CakeBase":
        sockets = {"top_tier": point((0.0, 0.0, h))}
        for label, angle in (("ramp_front", FRONT), ("ramp_right", 0.0), ("ramp_back", math.pi / 2),
                             ("ramp_left", math.pi)):
            sockets[label] = point(polar(r, angle, 0.0))
        snap = {"sockets": sockets, "note": "CV3_CakeTop pivot goes on top_tier. A ramp's high (+Y) end butts a "
                                            "ramp_* socket with the ramp's +Y facing the cake centre."}
    else:
        snap = {"sockets": {"base": point((0.0, 0.0, 0.0))},
                "note": "pivot sits on CV3_CakeBase top_tier socket (Z 12)"}
    return {"collision_boxes": boxes, "collision": collision, "snap": snap}


def tags_cake_ramp(a):
    half = (RAMP_RUN + RAMP_LANDING) / 2
    y_top = half - RAMP_LANDING
    pitch = math.degrees(math.atan2(RAMP_RISE, RAMP_RUN))
    theta = math.radians(pitch)
    length, thick = 25.4, 0.8
    mid = ((-half + y_top) / 2, RAMP_RISE / 2)
    centre = [0.0, round(mid[0] + math.sin(theta) * thick / 2, 4), round(mid[1] - math.cos(theta) * thick / 2, 4)]
    boxes = [{"name": "walk_landing", "center": [0.0, round(half - RAMP_LANDING / 2, 4), RAMP_RISE / 2],
              "size": [8.0, RAMP_LANDING, RAMP_RISE], "pitch_deg": 0.0},
             {"name": "ramp", "center": centre, "size": [8.0, length, thick], "pitch_deg": round(pitch, 4)}]
    snap = {"sockets": {"high_end": [0.0, half, RAMP_RISE], "low_end": [0.0, -half, 0.0]},
            "note": "put high_end against a CV3_CakeBase ramp_* socket; the landing top matches the tier top (Z 12)"}
    return {"collision_boxes": boxes, "collision": walk_colliders(boxes), "snap": snap}


# ---------------------------------------------------------------------------
# Cookie platforms (sheet 10): flat walkable tops for the chocolate lake
# ---------------------------------------------------------------------------

def build_cookie(a, diameter, height, sides, chips):
    rng = a.rng
    dough, chip = a.part("Dough"), a.part("Chips")
    r = diameter / 2
    wobble = [1.0 + 0.035 * math.cos(7 * TAU * i / sides) + rng.uniform(-0.025, 0.0) for i in range(sides)]
    wobble = [w / max(wobble) for w in wobble]
    rings = []
    for scale, z in ((0.9, 0.0), (1.0, height * 0.45), (0.97, height * 0.82), (0.9, height)):
        rings.append([polar(r * scale * w, TAU * i / sides, z) for i, w in enumerate(wobble)])
    loft(dough, rings, W, end=(0.0, 0.0, height))  # the flat top ring fans to a centre vertex at walk height
    spots = []
    for _ in range(5000):
        if len(spots) == chips:
            break
        rho, angle = r * 0.72 * math.sqrt(rng.uniform(0.0, 1.0)), rng.uniform(0.0, TAU)
        spot = polar(rho, angle, 0.0)
        if all(math.dist(spot[:2], s[:2]) > diameter * 0.12 for s in spots):
            spots.append(spot)
    assert len(spots) == chips, "cookie chips do not fit"
    size = max(0.45, diameter * 0.04)
    for x, y, _ in spots:
        lathe(chip, [(size, height - 0.12), (size * 0.45, height + 0.15)], 5, W, center=(x, y, 0.0),
              phase=rng.uniform(0.0, 1.0))
    set_anchor(a, "Dough", {"diameter": diameter, "height": height})


def tags_cookie(a):
    point, size = mapper(a)
    d, h = a.meta["diameter"], a.meta["height"]
    inner = round(d * 0.62, 4)
    boxes = [{"name": "walk_top", "center": point((0.0, 0.0, h / 2)), "size": size((inner, inner, h)),
              "pitch_deg": 0.0}]
    return {"collision_boxes": boxes,
            "collision": [collider("Slab", "cylinder", point((0.0, 0.0, h / 2)), size((d * 0.92, d * 0.92, h)))]}


# ---------------------------------------------------------------------------
# Kit table and pipeline
# ---------------------------------------------------------------------------

BUILDERS = {
    "CV3_TreeCotton": (build_tree_cotton, tags_tree, 4),
    "CV3_TreeIceCream": (build_tree_ice_cream, tags_tree, 5),
    "CV3_TreeCaramelApple": (build_tree_caramel_apple, tags_tree, 6),
    "CV3_IceCreamMountain_L": (build_mountain_l, tags_mountain, 7),
    "CV3_IceCreamMountain_M": (build_mountain_m, tags_mountain, 17),
    "CV3_LicoriceArch": (build_licorice_arch, tags_licorice_arch, 8),
    "CV3_CakeBase": (build_cake_base, tags_cake_tier, 9),
    "CV3_CakeRamp": (build_cake_ramp, tags_cake_ramp, 19),
    "CV3_CakeTop": (build_cake_top, tags_cake_tier, 29),
    "CV3_CookieS": (lambda a: build_cookie(a, 8.0, 1.6, 16, 5), tags_cookie, 10),
    "CV3_CookieM": (lambda a: build_cookie(a, 14.0, 2.0, 20, 9), tags_cookie, 11),
    "CV3_CookieL": (lambda a: build_cookie(a, 24.0, 2.6, 28, 16), tags_cookie, 12),
}

KIT = {name: {"size": cs.SPECS[name]["size"], "seed": seed, "build": build, "tags": tags,
              "colors": cs.colors(name), **({"clear": cs.SPECS[name]["clear"]} if "clear" in cs.SPECS[name] else {})}
       for name, (build, tags, seed) in BUILDERS.items()}

KIT_PATHS = bk.Kit("caramelo-v3-decor", "CV3", "tools/build-caramelo-v3-decor-kit.py", KIT, "CARAMELO_V3_DECOR_MODE")
# The shared Kit names its folders <slug>-kit; this kit lives where the owner asked instead.
ROOT = bk.ROOT
KIT_PATHS.out_dir = ROOT / "assets/blender/caramelo-v3-decor"
KIT_PATHS.export_dir = ROOT / "assets/exports/caramelo-v3/decor"
KIT_PATHS.blend = KIT_PATHS.out_dir / "caramelo-v3-decor-v1.blend"
KIT_PATHS.report = KIT_PATHS.out_dir / "caramelo-v3-decor-report.json"
KIT_PATHS.geometry = KIT_PATHS.out_dir / "caramelo-v3-decor-geometry.json"
KIT_PATHS.roundtrip = KIT_PATHS.out_dir / "fbx-roundtrip.json"
KIT_PATHS.sheet = KIT_PATHS.out_dir / "caramelo-v3-decor-sheet.png"
KIT_PATHS.lineup = KIT_PATHS.out_dir / "caramelo-v3-decor-scale.png"
IMPORT_SPEC = KIT_PATHS.export_dir / "caramelo-v3-decor-spec.json"
SCALE_NOTE = ("Authored at 1 Blender unit = 1 stud with no rescale step, exported with FBX_SCALE_ALL like the other "
              "biome kits. Scale in Roblox stays unverified until a real import.")


def build(kit):
    import bpy
    kit.out_dir.mkdir(parents=True, exist_ok=True)
    kit.export_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = f"{kit.prefix}Kit"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["studs_per_blender_unit"] = 1.0
    scene["status"] = "unvalidated: never imported into Roblox"

    authored = {name: bk.author(kit, name) for name in kit.order}
    materials = {}
    for name, (asset, _) in authored.items():
        for label in asset.parts:
            emission = kc.NEON_EMISSION if label.startswith("Neon_") else 0.0
            materials[f"{name}_{label}"] = kc.make_material(f"{name}_{label}", kit.table[name]["colors"][label][1],
                                                            emission)
    built = {name: bk.assemble(kit, name, asset, materials, scene) for name, (asset, _) in authored.items()}
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()

    report, dumps = {}, {}
    for name, (asset, tags) in authored.items():
        collection, root, meshes = built[name]
        entry, dumps[name] = bk.measure(kit, name, asset, tags, root, meshes, depsgraph)
        entry["fbx"] = {"model": kit.rel(kit.export_dir / f"{name}.fbx")}
        entry["render"] = kit.rel(kit.out_dir / f"{name}.png")
        report[name] = entry
        bk.export_fbx(collection, root, kit.export_dir / f"{name}.fbx")
    collections = {name: b[0] for name, b in built.items()}
    bk.render_assets(kit, collections, dumps)
    bk.compose_sheet(kit, columns=6, rows=2, tile=320, gap=12)
    bk.render_lineup(kit, collections, report, dumps)

    try:
        bpy.context.window.scene = scene
    except AttributeError:
        pass
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(kit.blend), check_existing=False)
    kc.dump_json(kit.report, {
        "generator": kit.generator,
        "blender_version": bpy.app.version_string,
        "unvalidated": True,
        "studs_per_blender_unit": 1.0,
        "fbx_settings": {**kc.FBX_SETTINGS, "apply_scale_options": bk.FBX_KIT_SCALE},
        "roblox_scale_verified": False,
        "scale_note": SCALE_NOTE,
        "scale_block_height": kc.SCALE_BLOCK_HEIGHT,
        "sheet_file": kit.sheet.name, "lineup_file": kit.lineup.name,
        "blend": kit.rel(kit.blend),
        "props": report,
    }, indent=2)
    kc.dump_json(kit.geometry, dumps)
    write_import_spec(kit, report)
    for name in kit.order:
        e = report[name]
        print(name, e["triangles"], e["size"], "open", e["non_manifold_edges"], "fit", e["fit_scale"])


def write_import_spec(kit, report):
    """Compact table for a Roblox importer: per asset its size, pieces (object, colour, role) and Collision_ parts.

    Axes stay Blender's (Z up). Blender to Roblox, as in WildboundCandyKit.luau: X = -x, Y = z, Z = y.
    """
    out = {"axes": "Blender (Z up). Roblox: X = -x, Y = z, Z = y. Cylinder size is (diameter, diameter, height).",
           "status": "unvalidated", "assets": {}}
    for name in kit.order:
        e, spec = report[name], cs.SPECS[name]
        sway = set(spec.get("sway", []))
        water = set(spec.get("water", {}).values())
        pieces = {}
        for part in e["parts"]:
            label = part["object"][len(name) + 1:]
            role = "sway" if label in sway else "water" if label in water else "visual"
            pieces[label] = {"object": part["object"], "color": "#" + part["color_hex"], "role": role,
                             "collide": False, "neon": label.startswith("Neon_")}
        out["assets"][name] = {"fbx": e["fbx"]["model"], "size": e["size"], "triangles": e["triangles"],
                               "pieces": pieces, "collision": e["collision"],
                               **{key: e[key] for key in ("sway", "water", "snap", "collision_boxes") if key in e}}
    kc.dump_json(IMPORT_SPEC, out, indent=2)


def main():
    kit = KIT_PATHS
    if bk.bpy is None:
        bk.dry_run(kit)
        return
    mode = os.environ.get(kit.mode_variable, "")
    if mode != "verify-fbx":
        build(kit)
    if mode != "build-only":
        bk.verify_fbx(kit)


main()
