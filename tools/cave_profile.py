"""Shared Rock and Caves tunnel profile, relief and extrusion (expansion bible 5.5).

Pure Python, no Blender. The tunnel is a closed C-shape in (x, z), swept along a straight line or
along the bend's quarter arc. Both modules end on the exact profile, so they snap together (S1).
Between the ends the rock gets seeded relief that obeys three rules:
  * inner walls may only recess, so the 14 x 10 corridor stays free (the flat ceiling may hang down
    by at most CEILING_DROP, which keeps 10.8 of headroom),
  * outer rock near the floor may only recess, so the footprint and the base centre never change;
    higher up it may swell by OUTER_BULGE, which breaks the silhouette (the builder fits the size to
    what it measures, and the spec size tolerance is 10%),
  * points on the floor never move.
Every value is unvalidated: nothing here was imported into Roblox.
"""

import math
import random  # noqa: F401  (callers pass a random.Random)

INNER = ((-7.0, 0.0), (-7.0, 10.0), (-5.0, 12.0), (5.0, 12.0), (7.0, 10.0), (7.0, 0.0))
OUTER = ((-12.0, 0.0), (-12.0, 12.0), (-7.0, 18.0), (7.0, 18.0), (12.0, 12.0), (12.0, 0.0))

CLEAR_MARGIN = 0.01
CEILING_DROP = 1.2
OUTER_RECESS = 2.0
OUTER_BULGE = 1.0
INNER_RECESS = 1.2

BEND_CENTRE = (15.0, -15.0)
BEND_RADIUS = 18.0
BEND_END_A = (-3.0, -15.0)
BEND_END_B = (15.0, 3.0)
BEND_START_DEGREES = 180.0
BEND_END_DEGREES = 90.0


class Profile:
    """The closed loop of (x, z) points with what the relief needs to know about each one."""

    def __init__(self, points, kinds, corner):
        self.points, self.kinds, self.corner = points, kinds, corner
        self.pinned = [p[1] == 0.0 for p in points]
        self.normals = _normals(points)
        self.limits = [self._limit(p, k, pin) for p, k, pin in zip(points, kinds, self.pinned)]

    @staticmethod
    def _limit(point, kind, pinned):
        if pinned:
            return (0.0, 0.0)
        if kind == "outer":
            return (-OUTER_RECESS, OUTER_BULGE if point[1] >= 5.9 else 0.0)
        if point[1] >= 11.99:
            return (-INNER_RECESS, CEILING_DROP)
        return (-INNER_RECESS, 0.0)


def _refine(chain, step):
    points, flags = [chain[0]], [True]
    for a, b in zip(chain, chain[1:]):
        pieces = 1 if step is None else max(1, math.ceil(math.dist(a, b) / step - 1e-9))
        for i in range(1, pieces):
            t = i / pieces
            points.append((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t))
            flags.append(False)
        points.append(b)
        flags.append(True)
    return points, flags


def _normals(points):
    """Unit normal at each vertex, pointing out of the solid."""
    count = len(points)
    area = sum(points[k][0] * points[(k + 1) % count][1] - points[(k + 1) % count][0] * points[k][1]
               for k in range(count))
    sign = 1.0 if area > 0 else -1.0  # counter-clockwise: the solid is on the left, outward is on the right

    def edge(a, b):
        dx, dz = b[0] - a[0], b[1] - a[1]
        size = math.hypot(dx, dz)
        return (sign * dz / size, -sign * dx / size)

    out = []
    for k in range(count):
        before = edge(points[k - 1], points[k])
        after = edge(points[k], points[(k + 1) % count])
        nx, nz = before[0] + after[0], before[1] + after[1]
        size = math.hypot(nx, nz)
        out.append((nx / size, nz / size))
    return out


def tunnel_profile(inner_step=6.0, outer_step=6.5, margin=CLEAR_MARGIN):
    """The shared C-shape, optionally refined with points that lie on the original edges.

    margin pushes the inner side walls (|x| = 7) that far outward. The spec test measures the free gap
    with a band that includes x = +-7 itself, so a wall built exactly on 7.0 would read as blocking.
    0.01 is half the S1 snap tolerance, and both tunnel modules use the same value, so they still join.
    """
    chain = [(x + math.copysign(margin, x), z) if abs(x) == 7.0 else (x, z) for x, z in INNER]
    inner, inner_flags = _refine(chain, inner_step)
    outer, outer_flags = _refine(list(reversed(OUTER)), outer_step)
    return Profile(inner + outer, ["inner"] * len(inner) + ["outer"] * len(outer), inner_flags + outer_flags)


# ---------------------------------------------------------------------------
# Relief
# ---------------------------------------------------------------------------

def relief_stations(profile, rng, count, amplitude, reserved=()):
    """Per-station, per-vertex relief along the normal: positive grows, negative recesses.

    The first and last station are zero, so the end rings stay on the shared profile. reserved is a
    set of (station, vertex) pairs forced to recess by at least 0.3, which is where stain patches sit.
    """
    waves = [(rng.uniform(0.6, 1.6), rng.uniform(0.0, math.tau), rng.random() < 0.45) for _ in profile.points]
    ceiling = [k for k, (low, high) in enumerate(profile.limits) if high > 0.0 and profile.kinds[k] == "inner"]
    for k in ceiling:  # most of the flat ceiling hangs, and at least one point always does
        waves[k] = (waves[k][0], waves[k][1], rng.random() < 0.8)
    if ceiling and not any(waves[k][2] for k in ceiling):
        k = ceiling[int(rng.random() * len(ceiling))]
        waves[k] = (waves[k][0], waves[k][1], True)
    stations = []
    for s in range(count):
        if s in (0, count - 1):
            stations.append([0.0] * len(profile.points))
            continue
        t = s / (count - 1)
        row = []
        for k, (frequency, phase, hangs) in enumerate(waves):
            low, high = profile.limits[k]
            if low == 0.0 and high == 0.0:
                row.append(0.0)
                continue
            raw = 0.5 + 0.5 * math.sin(math.tau * frequency * t * 1.7 + phase)
            raw = raw ** 1.4 * (0.55 + 0.45 * rng.random())
            if high > 0.0 and hangs:
                value = min(high, high * raw * 0.95)
            else:
                value = max(low, -amplitude * raw)
            if (s, k) in reserved:
                value = min(value, -0.3)
            row.append(value)
        stations.append(row)
    return stations


def displaced(profile, amounts):
    """The ring after relief: each point moves along its normal by its amount."""
    return [(x + nx * a, z + nz * a) for (x, z), (nx, nz), a in zip(profile.points, profile.normals, amounts)]


# ---------------------------------------------------------------------------
# Extrusion
# ---------------------------------------------------------------------------

def straight_rings(profile, rng, segments, length, amplitude, reserved=()):
    """Rings along Y from -length / 2 to length / 2, as lists of (x, y, z)."""
    count = segments + 1
    stations = relief_stations(profile, rng, count, amplitude, reserved)
    spacing = length / segments
    rings = []
    for s, amounts in enumerate(stations):
        y = -length / 2 + spacing * s
        if 0 < s < segments:
            y += rng.uniform(-0.18, 0.18) * spacing
        rings.append([(x, y, z) for x, z in displaced(profile, amounts)])
    return rings


def bend_rings(profile, rng, segments, amplitude, reserved=()):
    """Rings around the quarter arc from End A (180 degrees) to End B (90 degrees)."""
    count = segments + 1
    stations = relief_stations(profile, rng, count, amplitude, reserved)
    step = (BEND_START_DEGREES - BEND_END_DEGREES) / segments
    chord = 1.0 / math.cos(math.radians(step / 2))
    rings = []
    for s, amounts in enumerate(stations):
        angle = math.radians(BEND_START_DEGREES - step * s)
        cos_a, sin_a = math.cos(angle), math.sin(angle)
        ring = []
        for x, z in displaced(profile, amounts):
            radius = BEND_RADIUS + x
            if 0 < s < segments and x > 0.0:  # chords between rings stay outside the 25-radius wall line
                radius = (BEND_RADIUS + x) * chord
            ring.append((BEND_CENTRE[0] + radius * cos_a, BEND_CENTRE[1] + radius * sin_a, z))
        rings.append(ring)
    return rings


def ring_centre(ring, centre_xy, axis):
    """Middle of the ring's extent along a horizontal axis, measured from centre_xy."""
    values = [(v[0] - centre_xy[0]) * axis[0] + (v[1] - centre_xy[1]) * axis[1] for v in ring]
    return (min(values) + max(values)) / 2


# ---------------------------------------------------------------------------
# Measurements shared with the tests
# ---------------------------------------------------------------------------

def _segment_distance(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    span = dx * dx + dz * dz
    t = 0.0 if span == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / span))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dz))


def ring_matches_profile(points, tolerance):
    """Compare an end ring, as (lateral, z) pairs, with the shared profile (S1).

    Every corner of the profile needs a vertex within tolerance, and every vertex must lie on the
    profile outline within tolerance, so refinement points are fine and stray points are not.
    """
    loop = list(INNER) + list(reversed(OUTER))
    edges = [(loop[k], loop[(k + 1) % len(loop)]) for k in range(len(loop))]
    worst_corner = max(min(math.dist(corner, p) for p in points) for corner in loop)
    worst_stray = max(min(_segment_distance(p, a, b) for a, b in edges) for p in points)
    return {"ok": worst_corner <= tolerance and worst_stray <= tolerance,
            "worst_corner": worst_corner, "worst_stray": worst_stray}


def _radius(vertex, centre):
    return math.hypot(vertex[0] - centre[0], vertex[1] - centre[1])


def radial_violations(vertices, centre, below_z, low_radius, high_radius, tolerance):
    """Vertices under below_z whose distance from the arc centre falls inside the free band."""
    return [v for v in vertices
            if v[2] < below_z - 1e-9 and low_radius + tolerance < _radius(v, centre) < high_radius - tolerance]


def free_radial_band(triangles, centre, below_z, samples=8):
    """Narrowest free band around the path radius, from points sampled along the triangle edges.

    Returns (largest radius at or inside the path radius, smallest radius outside it), for geometry
    under below_z. Sampling the edges catches chords that cut across the corridor between rings.
    """
    low, high = 0.0, float("inf")
    for triangle in triangles:
        for k in range(3):
            a, b = triangle[k], triangle[(k + 1) % 3]
            for i in range(samples + 1):
                t = i / samples
                p = (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t)
                if p[2] >= below_z:
                    continue
                r = _radius(p, centre)
                if r <= BEND_RADIUS:
                    low = max(low, r)
                else:
                    high = min(high, r)
    return low, high
