"""Irregular-shape helpers shared by the W15 biome kits (Rock and Caves, Volcanic Lands, Cryptic
Ruins, Demon Abyss).

Pure Python on top of tools/kit_common.py, which it imports and never edits. The point of the module
is the lesson of the W14d art pass: shapes that pass every spec test can still read as tables, domes
and wands. Each helper therefore breaks the regular form on purpose, with seeded jitter, low harmonics
on the outline, taper, lean and bend. All randomness comes from the caller's random.Random, so a build
is repeatable. Every shape is unvalidated: nothing here was imported into Roblox.
"""

import math

import kit_common as kc
from biome_kit_common import no_weight as W
from kit_common import add, loft, madd, mul, path_frames

TAU = math.tau


def harmonic_scale(rng, wobble):
    """A function of angle that returns a radius multiplier around 1, built from three harmonics."""
    shape = [(amplitude, rng.uniform(0.0, TAU)) for amplitude in (0.7, 0.5, 0.35)]
    return lambda theta: 1.0 + wobble * sum(a * math.sin((order + 1) * theta + p)
                                            for order, (a, p) in enumerate(shape))


def irregular_ring(center, u, v, rx, ry, sides, rng, wobble=0.15, jitter=0.05, phase=0.0):
    """A closed ring of points in the plane of u and v: harmonics, then per-vertex jitter."""
    scale = harmonic_scale(rng, wobble)
    step = TAU / sides
    angular = min(0.3, jitter * 3.0) * step
    ring = []
    for k in range(sides):
        theta = phase + step * k + (rng.uniform(-angular, angular) if angular else 0.0)
        amount = scale(theta - phase) * (1.0 + (rng.uniform(-jitter, jitter) if jitter else 0.0))
        ring.append(add(center, add(mul(u, math.cos(theta) * rx * amount), mul(v, math.sin(theta) * ry * amount))))
    return ring


def outline_points(rng, count, rx, ry, wobble=0.15, jitter=0.05):
    """An irregular 2D outline, counter-clockwise from just past angle 0."""
    ring = irregular_ring((0.0, 0.0, 0.0), (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), rx, ry, count, rng, wobble, jitter,
                          phase=0.5 * TAU / count)
    return [(p[0], p[1]) for p in ring]


def rock_blob(part, rng, center, rx, ry, height, rings=3, sides=7, wobble=0.18, jitter=0.07, lean=(0.0, 0.0),
              flat_top=False, shoulder=0.0):
    """A faceted boulder on a flat base: irregular rings that narrow and lean, then a tip or a flat top.

    Ring 0 sits exactly on the base height, the tip (or the flat top) exactly at base + height.
    shoulder pushes the middle rings out, which makes a barrel instead of a dome.
    """
    count = rings
    ring_list = []
    for i in range(count):
        fraction = i / (count - 1) if flat_top else i / rings
        if flat_top:
            factor = 1.0 - 0.38 * fraction ** 1.2
        else:
            factor = math.cos(math.asin(min(0.999, fraction)))
        factor *= 1.0 + shoulder * math.sin(math.pi * fraction)
        z = center[2] + height * fraction
        if i > 0 and not (flat_top and i == count - 1):  # base and flat top keep their exact heights
            z += rng.uniform(-jitter, jitter) * height * 0.35
        drift = fraction ** 1.5
        ring_center = (center[0] + lean[0] * drift, center[1] + lean[1] * drift, z)
        ring_list.append(irregular_ring(ring_center, (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), rx * factor, ry * factor,
                                        sides, rng, wobble, jitter if i else jitter * 0.6, rng.uniform(0.0, 1.2)))
    if flat_top:
        top_z = center[2] + height
        ring_list[-1] = [(x, y, top_z) for x, y, _ in ring_list[-1]]
        loft(part, ring_list, W)
    else:
        tip = (center[0] + lean[0], center[1] + lean[1], center[2] + height)
        loft(part, ring_list, W, end=tip)


def rough_tube(part, rng, points, radii, sides, rough=0.07, flutes=0.0, twist=0.0, phase=None, reference=None,
               floor=None):
    """Faceted limb, trunk or column: jitter per vertex, grooves that persist along the length, a slow spiral.

    A radius of 0 at either end makes a sharp tip. floor sinks any vertex below it onto it.
    """
    frames = path_frames(points, reference)
    phase = rng.uniform(0.0, TAU) if phase is None else phase
    groove = [1.0 + flutes * (rng.uniform(0.3, 1.0) if k % 2 else -rng.uniform(0.3, 1.0)) for k in range(sides)]
    rings, start, end = [], "cap", "cap"
    for index, (point, radius) in enumerate(zip(points, radii)):
        if radius <= 0.0:
            if index == 0:
                start = point
            else:
                end = point
            continue
        side, normal, _ = frames[index]
        ring = []
        for k in range(sides):
            angle = phase + twist * index + TAU * k / sides
            amount = radius * groove[k] * (1.0 + rng.uniform(-rough, rough))
            vertex = add(point, add(mul(side, math.cos(angle) * amount), mul(normal, math.sin(angle) * amount)))
            ring.append(vertex if floor is None else (vertex[0], vertex[1], max(vertex[2], floor)))
        rings.append(ring)
    loft(part, rings, W, start, end)


def shard(part, rng, base, direction, radius, height, sides=5, bend=0.0, belly=1.0, rough=0.08, stages=3):
    """A crystal or thorn along a direction: swollen belly, a tapered upper third, a bent, off-axis tip.

    stages=2 drops the middle ring: one swollen band and a tip, for tight triangle budgets.
    """
    u, v, w = kc.basis(direction)
    side = mul(u, bend * height * 0.5)
    lift = madd(base, w, height)
    if stages == 2:
        points = [base, madd(add(base, mul(side, 0.25)), w, height * 0.45), add(lift, side)]
        radii = [radius, radius * belly, 0.0]
    else:
        points = [base, madd(add(base, mul(side, 0.12)), w, height * 0.38),
                  madd(add(base, mul(side, 0.45)), w, height * 0.74), add(lift, side)]
        radii = [radius, radius * belly, radius * 0.55 * belly, 0.0]
    rough_tube(part, rng, points, radii, sides, rough=rough, phase=rng.uniform(0.0, 1.0))


def slab_between(part, top, low):
    """Close two matching grids of points (rows x cols) into one thin slab: a top skin, a bottom skin, a rim."""
    rows, cols = len(top), len(top[0])
    vertices = [p for grid in (top, low) for row in grid for p in row]

    def at(layer, i, j):
        return layer * rows * cols + i * cols + j

    faces = []
    for i in range(rows - 1):
        for j in range(cols - 1):
            faces.append((at(0, i, j), at(0, i, j + 1), at(0, i + 1, j + 1), at(0, i + 1, j)))
            faces.append((at(1, i + 1, j), at(1, i + 1, j + 1), at(1, i, j + 1), at(1, i, j)))
    edges = [[(at(0, 0, j), at(0, 0, j + 1)) for j in range(cols - 1)],
             [(at(0, i, cols - 1), at(0, i + 1, cols - 1)) for i in range(rows - 1)],
             [(at(0, rows - 1, j + 1), at(0, rows - 1, j)) for j in range(cols - 2, -1, -1)],
             [(at(0, i + 1, 0), at(0, i, 0)) for i in range(rows - 2, -1, -1)]]
    for side in edges:
        for p, q in side:
            faces.append((p, q, q + rows * cols, p + rows * cols))
    part.add(vertices, faces, W)


def grid_normals(rings, centre_xy):
    """Outward unit normals for a grid of rings (closed around, open between rings)."""
    rows = []
    for r, ring in enumerate(rings):
        before, after = rings[max(r - 1, 0)], rings[min(r + 1, len(rings) - 1)]
        row = []
        for k, point in enumerate(ring):
            along = kc.sub(ring[(k + 1) % len(ring)], ring[k - 1])
            across = kc.sub(after[k], before[k])
            normal = kc.cross(along, across)
            if kc.length(normal) < 1e-12:
                normal = (0.0, 0.0, 1.0)
            normal = kc.unit(normal)
            outward = (point[0] - centre_xy[0], point[1] - centre_xy[1], 0.0)
            flat = kc.length(outward) > 1e-6
            if (flat and kc.dot(normal, outward) < 0.0) or (not flat and normal[2] < 0.0):
                normal = mul(normal, -1.0)
            row.append(normal)
        rows.append(row)
    return rows


def _ribbon(part, rng, edges, fraction, half, lift, sink):
    """A ribbon across a run of surface edges (a, b, normal_a, normal_b): it swells and thins along its length."""
    top, low = [], []
    for a, b, na, nb in edges:
        centre = fraction + rng.uniform(-0.17, 0.17)
        width = half * rng.uniform(0.4, 1.45)
        row_top, row_low = [], []
        for f in (centre - width, centre + width):
            point, normal = kc.lerp(a, b, f), kc.unit(kc.lerp(na, nb, f))
            row_top.append(add(point, mul(normal, lift * rng.uniform(0.8, 1.3))))
            row_low.append(add(point, mul(normal, -sink)))
        top.append(row_top)
        low.append(row_low)
    slab_between(part, top, low)


def ribbon_along(part, rng, rings, normals, first, last, k, fraction, half, lift=0.14, sink=0.2):
    """A vein that runs across rings first..last, between vertex column k and column k + 1."""
    edges = [(rings[s][k], rings[s][k + 1], normals[s][k], normals[s][k + 1]) for s in range(first, last + 1)]
    _ribbon(part, rng, edges, fraction, half, lift, sink)


def band_around(part, rng, rings, normals, r, first, last, fraction, half, lift=0.14, sink=0.2):
    """A band that runs around the grid through vertices first..last, between ring r and ring r + 1."""
    edges = [(rings[r][k], rings[r + 1][k], normals[r][k], normals[r + 1][k]) for k in range(first, last + 1)]
    _ribbon(part, rng, edges, fraction, half, lift, sink)


def enable_neon_materials():
    """Give every material whose name holds _Neon_ the shared kit emission. The shared biome builder asks for
    plain matte materials, so a kit with a glowing part calls this once before it builds."""
    inner = kc.make_material

    def make(name, hex_color, emission=0.0):
        return inner(name, hex_color, kc.NEON_EMISSION if "_Neon_" in name else emission)

    kc.make_material = make


def jittered_block(part, rng, center, size, jitter=0.1, yaw=0.0, taper=1.0):
    """A six-sided block whose corners are moved by seeded jitter: a hewn stone, not a box."""
    sx, sy, sz = (s / 2 for s in size)
    cos_y, sin_y = math.cos(yaw), math.sin(yaw)

    def corner(x, y, z, scale):
        x, y = x * scale, y * scale
        x, y = x * cos_y - y * sin_y, x * sin_y + y * cos_y
        return (center[0] + x + rng.uniform(-jitter, jitter), center[1] + y + rng.uniform(-jitter, jitter),
                center[2] + z + rng.uniform(-jitter, jitter) * 0.6)

    ring = [(-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)]
    kc.hexahedron(part, [corner(x, y, -sz, 1.0) for x, y in ring] + [corner(x, y, sz, taper) for x, y in ring], W)
