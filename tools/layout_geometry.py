"""2D helpers shared by the biome layout plans. Standard library only.

Adapted from the shape helpers in tools/plan_forest_layout.py, which stays untouched and is
not imported. Conventions match that plan: lengths in studs, x grows east, z grows south, and
rotation_y_deg is CFrame.Angles(0, math.rad(r), 0): local +X maps to (cos r, -sin r) and local
+Z (the Blender +Y walking axis) to (sin r, cos r) in (x, z).
"""

import math
from typing import NamedTuple


class Circle(NamedTuple):
    x: float
    z: float
    r: float


class Poly(NamedTuple):
    pts: tuple


def local_axes(yaw_deg):
    a = math.radians(yaw_deg)
    return (math.cos(a), -math.sin(a)), (math.sin(a), math.cos(a))


def rect_poly(cx, cz, hx, hz, yaw_deg):
    """Rectangle with half extents hx along local X and hz along local Z."""
    ex, ez = local_axes(yaw_deg)
    return Poly(tuple((cx + sx * hx * ex[0] + sz * hz * ez[0], cz + sx * hx * ex[1] + sz * hz * ez[1])
                      for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))))


def heading_deg(dx, dz):
    """Yaw whose local +Z axis points along (dx, dz)."""
    return math.degrees(math.atan2(dx, dz)) % 360.0


def point_seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    length2 = dx * dx + dz * dz
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / length2))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dz))


def _cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def _segments_cross(a, b, c, d):
    d1, d2, d3, d4 = _cross(c, d, a), _cross(c, d, b), _cross(a, b, c), _cross(a, b, d)
    return ((d1 > 0) != (d2 > 0)) and ((d3 > 0) != (d4 > 0)) and d1 != 0 and d2 != 0 and d3 != 0 and d4 != 0


def seg_seg_dist(a, b, c, d):
    if _segments_cross(a, b, c, d):
        return 0.0
    return min(point_seg_dist(a, c, d), point_seg_dist(b, c, d), point_seg_dist(c, a, b), point_seg_dist(d, a, b))


def _edges(pts):
    return [(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts))]


def poly_contains(pts, p):
    """Point in a convex polygon of either winding."""
    signs = [_cross(a, b, p) for a, b in _edges(pts)]
    return all(s >= -1e-12 for s in signs) or all(s <= 1e-12 for s in signs)


def point_in_polygon(pts, p):
    """Point in any simple polygon (ray casting)."""
    inside = False
    for a, b in _edges(pts):
        if (a[1] > p[1]) != (b[1] > p[1]) and p[0] < (b[0] - a[0]) * (p[1] - a[1]) / (b[1] - a[1]) + a[0]:
            inside = not inside
    return inside


def shape_bbox(shape):
    if isinstance(shape, Circle):
        return (shape.x - shape.r, shape.z - shape.r, shape.x + shape.r, shape.z + shape.r)
    xs, zs = [p[0] for p in shape.pts], [p[1] for p in shape.pts]
    return (min(xs), min(zs), max(xs), max(zs))


def shape_bound(shape):
    """Bounding circle (cx, cz, R), used only to skip exact tests."""
    if isinstance(shape, Circle):
        return (shape.x, shape.z, shape.r)
    cx = sum(p[0] for p in shape.pts) / len(shape.pts)
    cz = sum(p[1] for p in shape.pts) / len(shape.pts)
    return (cx, cz, max(math.hypot(p[0] - cx, p[1] - cz) for p in shape.pts))


def shape_point_dist(shape, p):
    if isinstance(shape, Circle):
        return max(0.0, math.hypot(p[0] - shape.x, p[1] - shape.z) - shape.r)
    if poly_contains(shape.pts, p):
        return 0.0
    return min(point_seg_dist(p, a, b) for a, b in _edges(shape.pts))


def shape_segment_dist(shape, a, b):
    if isinstance(shape, Circle):
        return max(0.0, point_seg_dist((shape.x, shape.z), a, b) - shape.r)
    if poly_contains(shape.pts, a) or poly_contains(shape.pts, b):
        return 0.0
    return min(seg_seg_dist(a, b, c, d) for c, d in _edges(shape.pts))


def shape_polyline_dist(shape, pts, closed=False):
    segs = list(zip(pts, pts[1:])) + ([(pts[-1], pts[0])] if closed else [])
    return min(shape_segment_dist(shape, a, b) for a, b in segs)


def _separated(p1, p2):
    for pts in (p1, p2):
        for a, b in _edges(pts):
            nx, nz = b[1] - a[1], a[0] - b[0]
            q1 = [nx * p[0] + nz * p[1] for p in p1]
            q2 = [nx * p[0] + nz * p[1] for p in p2]
            if max(q1) < min(q2) or max(q2) < min(q1):
                return True
    return False


def shape_gap(s1, s2):
    """Smallest distance between two convex bases; 0 when they touch or overlap."""
    if isinstance(s1, Circle) and isinstance(s2, Circle):
        return max(0.0, math.hypot(s1.x - s2.x, s1.z - s2.z) - s1.r - s2.r)
    if isinstance(s1, Circle):
        return max(0.0, shape_point_dist(s2, (s1.x, s1.z)) - s1.r)
    if isinstance(s2, Circle):
        return max(0.0, shape_point_dist(s1, (s2.x, s2.z)) - s2.r)
    if not _separated(s1.pts, s2.pts):
        return 0.0
    return min(seg_seg_dist(a, b, c, d) for a, b in _edges(s1.pts) for c, d in _edges(s2.pts))


# ---- Polylines --------------------------------------------------------------

def polyline_length(pts):
    return sum(math.dist(a, b) for a, b in zip(pts, pts[1:]))


def polyline_point(pts, s):
    """Point, unit direction and segment index at arc position s along an open polyline."""
    walked = 0.0
    for index, (a, b) in enumerate(zip(pts, pts[1:])):
        length = math.dist(a, b)
        if s <= walked + length or index == len(pts) - 2:
            t = (s - walked) / length
            return ((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t),
                    ((b[0] - a[0]) / length, (b[1] - a[1]) / length), index)
        walked += length
    raise AssertionError("unreachable")


def project_to_polyline(pts, p):
    """Nearest point on an open polyline: (distance, arc position, segment index, signed lateral)."""
    best, walked = None, 0.0
    for index, (a, b) in enumerate(zip(pts, pts[1:])):
        length = math.dist(a, b)
        dx, dz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        along = max(0.0, min(length, (p[0] - a[0]) * dx + (p[1] - a[1]) * dz))
        foot = (a[0] + dx * along, a[1] + dz * along)
        distance = math.dist(p, foot)
        if best is None or distance < best[0]:
            lateral = (p[0] - a[0]) * -dz + (p[1] - a[1]) * dx
            best = (distance, walked + along, index, lateral)
        walked += length
    return best


def segment_intersection(a, b, c, d):
    """Intersection point of two segments, or None (parallel and touching-only cases excluded)."""
    r = (b[0] - a[0], b[1] - a[1])
    s = (d[0] - c[0], d[1] - c[1])
    denominator = r[0] * s[1] - r[1] * s[0]
    if abs(denominator) < 1e-12:
        return None
    t = ((c[0] - a[0]) * s[1] - (c[1] - a[1]) * s[0]) / denominator
    u = ((c[0] - a[0]) * r[1] - (c[1] - a[1]) * r[0]) / denominator
    if 0.0 <= t <= 1.0 and 0.0 <= u <= 1.0:
        return (a[0] + r[0] * t, a[1] + r[1] * t)
    return None


def crossings(first, second):
    """Every crossing between two open polylines, in arc order along the first."""
    found, walked_a = [], 0.0
    for i, (a, b) in enumerate(zip(first, first[1:])):
        length_a, walked_b = math.dist(a, b), 0.0
        for j, (c, d) in enumerate(zip(second, second[1:])):
            length_b = math.dist(c, d)
            point = segment_intersection(a, b, c, d)
            if point is not None:
                da = ((b[0] - a[0]) / length_a, (b[1] - a[1]) / length_a)
                db = ((d[0] - c[0]) / length_b, (d[1] - c[1]) / length_b)
                cosine = abs(da[0] * db[0] + da[1] * db[1])
                found.append({"point": point, "first_index": i, "second_index": j,
                              "first_arc": walked_a + math.dist(a, point),
                              "second_arc": walked_b + math.dist(c, point), "first_dir": da, "second_dir": db,
                              "angle_deg": math.degrees(math.acos(min(1.0, cosine)))})
            walked_b += length_b
        walked_a += length_a
    return sorted(found, key=lambda c: c["first_arc"])


def inscribed_square_half(polygon, center=(0.0, 0.0)):
    """Half size of the largest axis-aligned square about center whose corners and edge midpoints
    lie inside the polygon (found by bisection)."""
    low, high = 0.0, max(math.hypot(p[0] - center[0], p[1] - center[1]) for p in polygon)
    for _ in range(40):
        half = (low + high) / 2
        samples = [(center[0] + sx * half * t, center[1] + sz * half * u)
                   for sx in (-1, 1) for sz in (-1, 1) for t, u in ((1, 1), (1, 0), (0, 1))]
        if all(point_in_polygon(polygon, p) for p in samples):
            low = half
        else:
            high = half
    return low
