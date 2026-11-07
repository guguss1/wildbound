#!/usr/bin/env python3
"""Reproducible top-down placement plan for the Wildbound fog forest.

This is a plan only: it writes JSON, SVG and (when Pillow is importable) PNG
files and never touches the Luau map builder, Studio or Blender. Python
standard library only; Pillow is optional.

    python tools/plan_forest_layout.py [--seed N] [--out-dir DIR]

Conventions (all lengths in studs, origin at the map centre):
    x grows east (right on the plan), z grows south (down on the plan).
    rotation_y_deg is CFrame.Angles(0, math.rad(r), 0): local +X maps to
    (cos r, -sin r) and local +Z to (sin r, cos r) in (x, z).

Prop sizes are the measured Blender kit values (assets/blender/forest-kit/
forest-kit-report.json and forest-kit-geometry.json, read-only inputs). Each
prop has a ground footprint ("reach", including roots) and a solid body
("core" trunk at eye height); the Blender Y axis sign is not assumed, so the
envelopes are symmetric about the pivot.
"""

import argparse
import functools
import json
import math
import random
import sys
from pathlib import Path
from typing import NamedTuple

DEFAULT_SEED = 20261107
LAYOUT_NAME = "forest-layout-v1"
DEFAULT_OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "maps" / "forest-layout"

# ---- Spec inputs -----------------------------------------------------------
MAP_SIZE = 400.0
EDGE_MARGIN = 5.0
LIMIT = MAP_SIZE / 2 - EDGE_MARGIN  # bases (roots included) must stay within +/-195

ROUTE_NODES = (
    ("camp", (-140.0, 140.0)),
    ("clearing", (-95.0, 75.0)),
    ("ruin", (0.0, -85.0)),
    ("nest", (35.0, -99.0)),
    ("marsh", (115.0, 15.0)),
    ("shelter", (105.0, 125.0)),
)
ROUTE = [p for _, p in ROUTE_NODES]
NEST = ROUTE[3]
ROUTE_WIDTH = 14.0
CLEAR_RADIUS = 10.0  # 14-stud corridor (half 7) plus 3 studs

HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)  # xmin, xmax, zmin, zmax
SAFE_CIRCLES = (((-140.0, 140.0), 35.0), ((105.0, 125.0), 22.0))
# Real patrol waypoints (src/wildbound/WildboundWorld.server.luau:90-93): a diamond on the axes
# around home, visited in this order. +Z is south on the plan.
PATROL = {"E": (16.0, -85.0), "S": (0.0, -69.0), "W": (-16.0, -85.0), "N": (0.0, -101.0)}
PATROL_LOOP = list(PATROL.values())
PILLARS = ((-10.0, -92.0), (10.0, -92.0), (10.0, -77.0), (-10.0, -77.0))
PILLAR_HALF = 1.5
OLD_NEST = (110.0, -130.0)
NEST_RING_RADIUS, STONE_R = 9.0, 2.0
POOL_CENTRE, POOL_HALF = (128.0, 15.0), (16.0, 12.0)  # existing MarshPool part

EYE_HEIGHT = 3.7
DETECTION_RANGE = {"day": 28.0, "night": 38.0}

# Design thresholds chosen by this plan.
BASE_GAP = 1.0         # minimum gap between solid bases, and from roots to other solids
NODE_CLEAR = 12.0      # every anchor stays this far from route nodes
NODE_REACH_CLEAR = 6.0  # roots and bases stay this far from route nodes
PATROL_CLEAR = 4.0     # solid bodies keep the guardian's patrol loop walkable
POOL_CLEAR = 2.0
LANE_MARGIN = 1.5      # extra clearance around reserved sight lanes
COVER_BAND = (13.0, 26.0)
LANTERN_OFFSET = 10.5  # inside the 9-11 request and outside the 10-stud clear rule

ARCH_BEFORE_RUIN = 55.5    # along the clearing -> ruin leg (rule: about 55 to 75)
DOORWAY_AFTER_NEST = 20.0  # along the nest -> marsh leg

LANTERN_OUT = (40.0, 55.0, 47.5)  # lo, hi, ideal spacing outside the territory
LANTERN_IN = (62.0, 78.0, 70.0)   # inside the guardian territory ("about 70")
RANGE_MARGIN = 0.25
START_STRIDE = 12

MAX_INSTANCES, MAX_TRIANGLES = 220, 95000

# Measured kit values. "roots_r" = farthest ground vertex from the pivot, "core_r" = trunk
# radius between eye height and 6 studs, "half" = symmetric X/Y bound of the measured bbox,
# "gap" = measured inner clearance edges along local X, "clear_h" = clearance height.
PROPS = {
    "FK_Evergreen": {"tris": 370, "height": 30.0, "roots_r": 8.0, "core_r": 2.5, "canopy_r": 10.4,
                     "scale": (0.9, 1.15)},
    "FK_DeadTree": {"tris": 338, "height": 22.0, "roots_r": 8.0, "core_r": 3.4, "scale": (0.9, 1.15)},
    "FK_FallenLog": {"tris": 346, "height": 7.6, "half": (8.544, 3.0111), "scale": (0.85, 1.15)},
    "FK_RootArch": {"tris": 664, "height": 18.5028, "half": (15.805, 8.0776),
                    "gap": (-8.1239, 8.2108), "clear_h": 11.2395},
    "FK_RuinDoorway": {"tris": 586, "height": 18.7153, "half": (18.0036, 4.9535),
                       "gap": (-9.3104, 9.3213), "clear_h": 11.6446},
    "FK_LanternMarker": {"tris": 348, "height": 9.0, "base_r": 2.2},
}
TREES = ("FK_Evergreen", "FK_DeadTree")
FOREST = ("FK_Evergreen", "FK_DeadTree", "FK_FallenLog")
LANDMARKS = ("FK_RootArch", "FK_RuinDoorway")
LANTERN = "FK_LanternMarker"

# Targets per region. Cover trunks near the nest are placed first and count here.
FOG_COUNTS = (("FK_DeadTree", 38), ("FK_FallenLog", 14), ("FK_Evergreen", 68))
OUTSIDE_COUNTS = (("FK_Evergreen", "edge", 34), ("FK_Evergreen", "scatter", 28),
                  ("FK_DeadTree", "scatter", 4), ("FK_FallenLog", "scatter", 3))
COVER_SEQUENCE = ("FK_Evergreen", "FK_DeadTree", "FK_Evergreen", "FK_DeadTree")
EDGE_RING_MIN = 168.0  # |x| or |z| beyond this belongs to the edge wall region
LANE_WAYPOINTS = ("E", "N")  # the two waypoints inside night detection range (E 23.6, N 35.1)


# ---- Geometry --------------------------------------------------------------
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
    return min(point_seg_dist(a, c, d), point_seg_dist(b, c, d),
               point_seg_dist(c, a, b), point_seg_dist(d, a, b))


def _edges(pts):
    return [(pts[i], pts[(i + 1) % len(pts)]) for i in range(len(pts))]


def _poly_contains(pts, p):
    signs = [_cross(a, b, p) for a, b in _edges(pts)]
    return all(s >= -1e-12 for s in signs) or all(s <= 1e-12 for s in signs)


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
    if _poly_contains(shape.pts, p):
        return 0.0
    return min(point_seg_dist(p, a, b) for a, b in _edges(shape.pts))


def shape_segment_dist(shape, a, b):
    if isinstance(shape, Circle):
        return max(0.0, point_seg_dist((shape.x, shape.z), a, b) - shape.r)
    if _poly_contains(shape.pts, a) or _poly_contains(shape.pts, b):
        return 0.0
    return min(seg_seg_dist(a, b, c, d) for c, d in _edges(shape.pts))


def shape_polyline_dist(shape, pts, closed=False):
    segs = list(zip(pts, pts[1:])) + ([(pts[-1], pts[0])] if closed else [])
    return min(shape_segment_dist(shape, a, b) for a, b in segs)


def segment_hits_shape(a, b, shape):
    return shape_segment_dist(shape, a, b) <= 1e-12


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
    """Smallest distance between two bases; 0 when they touch or overlap."""
    if isinstance(s1, Circle) and isinstance(s2, Circle):
        return max(0.0, math.hypot(s1.x - s2.x, s1.z - s2.z) - s1.r - s2.r)
    if isinstance(s1, Circle):
        return max(0.0, shape_point_dist(s2, (s1.x, s1.z)) - s1.r)
    if isinstance(s2, Circle):
        return max(0.0, shape_point_dist(s1, (s2.x, s2.z)) - s2.r)
    if not _separated(s1.pts, s2.pts):
        return 0.0
    return min(seg_seg_dist(a, b, c, d) for a, b in _edges(s1.pts) for c, d in _edges(s2.pts))


# ---- Route and zones -------------------------------------------------------
SEGMENTS = [(ROUTE[i], ROUTE[(i + 1) % len(ROUTE)]) for i in range(len(ROUTE))]
SEG_LEN = [math.dist(a, b) for a, b in SEGMENTS]
CUM = [sum(SEG_LEN[:i]) for i in range(len(SEGMENTS))]
LOOP = sum(SEG_LEN)


def route_point(s):
    """Point, unit direction and segment index at arc position s on the loop."""
    s %= LOOP
    for i, (a, b) in enumerate(SEGMENTS):
        if s <= CUM[i] + SEG_LEN[i] or i == len(SEGMENTS) - 1:
            t = (s - CUM[i]) / SEG_LEN[i]
            d = ((b[0] - a[0]) / SEG_LEN[i], (b[1] - a[1]) / SEG_LEN[i])
            return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), d, i
    raise AssertionError("unreachable")


def route_distance(p):
    return min(point_seg_dist(p, a, b) for a, b in SEGMENTS)


def in_fog(x, z):
    return FOG[0] <= x <= FOG[1] and FOG[2] <= z <= FOG[3]


def in_safe(x, z):
    return any(math.hypot(x - c[0], z - c[1]) <= r for c, r in SAFE_CIRCLES)


def in_territory(x, z):
    """Same rule as WildboundWorldRules.inTerritory."""
    return in_fog(x, z) and not in_safe(x, z) and math.hypot(x - HOME[0], z - HOME[1]) <= LEASH


def heading_deg(dx, dz):
    return math.degrees(math.atan2(dx, dz)) % 360.0


FIXED_SHAPES = tuple(
    [rect_poly(px, pz, PILLAR_HALF, PILLAR_HALF, 0) for px, pz in PILLARS]
    + [Circle(NEST[0] + NEST_RING_RADIUS * math.cos(k * math.pi / 4),
              NEST[1] + NEST_RING_RADIUS * math.sin(k * math.pi / 4), STONE_R) for k in range(1, 9)])
POOL_SHAPE = rect_poly(POOL_CENTRE[0], POOL_CENTRE[1], POOL_HALF[0], POOL_HALF[1], 0)


# ---- Instances and footprints ---------------------------------------------
def r3(value):
    return round(float(value), 3) + 0.0


def make_instance(name, x, z, yaw, scale):
    yaw = r3(yaw % 360.0)
    return {"name": name, "x": r3(x), "z": r3(z), "rotation_y_deg": 0.0 if yaw >= 360.0 else yaw,
            "scale": r3(scale)}


def footprint(inst):
    """Ground footprint ("reach"): tree roots, log and landmark envelopes, lantern base."""
    name, x, z, yaw, s = inst["name"], inst["x"], inst["z"], inst["rotation_y_deg"], inst["scale"]
    spec = PROPS[name]
    if name in TREES:
        return [Circle(x, z, spec["roots_r"] * s)]
    if name == LANTERN:
        return [Circle(x, z, spec["base_r"] * s)]
    scale = s if name == "FK_FallenLog" else 1.0
    return [rect_poly(x, z, spec["half"][0] * scale, spec["half"][1] * scale, yaw)]


def body(inst):
    """Solid body: the trunk core of a tree; everything else is its own footprint."""
    if inst["name"] in TREES:
        return [Circle(inst["x"], inst["z"], PROPS[inst["name"]]["core_r"] * inst["scale"])]
    return footprint(inst)


class Placer:
    """Collects accepted instances and answers 'may this one go here?'."""

    def __init__(self):
        self.items = []

    def add(self, inst):
        reach = footprint(inst)
        self.items.append((inst, body(inst), reach, [shape_bound(s) for s in reach]))

    def valid(self, inst):
        name = inst["name"]
        reach, solid = footprint(inst), body(inst)
        anchor = (inst["x"], inst["z"])
        for s in reach:
            x0, z0, x1, z1 = shape_bbox(s)
            if x0 < -LIMIT or z0 < -LIMIT or x1 > LIMIT or z1 > LIMIT:
                return False
        if any(math.dist(anchor, node) < NODE_CLEAR for node in ROUTE):
            return False
        for s in reach:
            if any(shape_point_dist(s, node) < NODE_REACH_CLEAR for node in ROUTE):
                return False
            if name in FOREST:
                if any(shape_point_dist(s, c) < r + BASE_GAP for c, r in SAFE_CIRCLES):
                    return False
                if shape_polyline_dist(s, ROUTE, closed=True) < CLEAR_RADIUS:
                    return False
            elif name == LANTERN and shape_polyline_dist(s, ROUTE, closed=True) < ROUTE_WIDTH / 2:
                return False
            if shape_gap(s, POOL_SHAPE) < POOL_CLEAR:
                return False
            if any(shape_gap(s, fixed) < BASE_GAP for fixed in FIXED_SHAPES):
                return False
        if name == LANTERN and route_distance(anchor) < CLEAR_RADIUS:
            return False
        for s in solid:
            if shape_polyline_dist(s, PATROL_LOOP, closed=True) < PATROL_CLEAR:
                return False
            if name not in LANDMARKS and any(
                    shape_segment_dist(s, PATROL[w], NEST) < LANE_MARGIN for w in LANE_WAYPOINTS):
                return False
        for other, o_solid, o_reach, o_bounds in self.items:
            on = other["name"]
            if not self._near(reach, o_reach, o_bounds):
                continue
            if any(shape_gap(s, t) < BASE_GAP for s in solid for t in o_solid):
                return False
            # Roots keep other solids out; logs may rest on roots.
            if name in TREES and on != "FK_FallenLog" and \
                    any(shape_gap(r, t) < BASE_GAP for r in reach for t in o_solid):
                return False
            if on in TREES and name != "FK_FallenLog" and \
                    any(shape_gap(s, t) < BASE_GAP for s in solid for t in o_reach):
                return False
        return True

    @staticmethod
    def _near(reach, o_reach, o_bounds):
        for s in reach:
            cx, cz, rad = shape_bound(s)
            for (bx, bz, br) in o_bounds:
                if math.hypot(cx - bx, cz - bz) - rad - br < BASE_GAP:
                    return True
        return False

    def nearest_forest(self, inst):
        best = 100.0
        for other, _, _, _ in self.items:
            if other["name"] in FOREST:
                best = min(best, math.hypot(inst["x"] - other["x"], inst["z"] - other["z"]))
        return best


# ---- Landmarks and lanterns (independent of the seed) ---------------------
@functools.lru_cache(maxsize=1)
def build_landmarks():
    (ax, az), (bx, bz) = SEGMENTS[1]  # clearing -> ruin
    dx, dz = (bx - ax) / SEG_LEN[1], (bz - az) / SEG_LEN[1]
    arch = make_instance("FK_RootArch", bx - dx * ARCH_BEFORE_RUIN, bz - dz * ARCH_BEFORE_RUIN,
                         heading_deg(dx, dz), 1.0)
    (cx, cz), (ex, ez) = SEGMENTS[3]  # nest -> marsh
    dx, dz = (ex - cx) / SEG_LEN[3], (ez - cz) / SEG_LEN[3]
    door = make_instance("FK_RuinDoorway", cx + dx * DOORWAY_AFTER_NEST, cz + dz * DOORWAY_AFTER_NEST,
                         heading_deg(dx, dz), 1.0)
    placer = Placer()
    for inst in (arch, door):
        if not placer.valid(inst):
            raise RuntimeError("landmark placement invalid: %s" % inst["name"])
        placer.add(inst)
    return (arch, door)


def _gap_spec(territory):
    return LANTERN_IN if territory else LANTERN_OUT


@functools.lru_cache(maxsize=1)
def build_lanterns():
    """Pick lantern arc positions with a cyclic DP so every rule closes the loop.

    Gaps ending outside the territory are 40-55 studs, gaps ending inside are
    62-78 (about 70), sides alternate (so the count is even), and the position
    set only contains spots that are valid for the whole plan.
    """
    placer = Placer()
    for lm in build_landmarks():
        placer.add(lm)
    m = round(LOOP)
    step = LOOP / m
    table = [[None, None] for _ in range(m)]
    for i in range(m):
        pt, d, seg = route_point(i * step)
        normal = (-d[1], d[0])
        for k, side in enumerate((1, -1)):
            x, z = pt[0] + side * LANTERN_OFFSET * normal[0], pt[1] + side * LANTERN_OFFSET * normal[1]
            yaw = heading_deg(-side * normal[0], -side * normal[1])  # cage opening faces the route
            inst = make_instance(LANTERN, x, z, yaw, 1.0)
            if not placer.valid(inst):
                continue
            anchor = (inst["x"], inst["z"])
            if any(point_seg_dist(anchor, *SEGMENTS[j]) < LANTERN_OFFSET + 0.25
                   for j in range(len(SEGMENTS)) if j != seg):
                continue
            table[i][k] = (inst, in_territory(*anchor), i * step, side)
    inf = float("inf")
    best = None
    for p0 in range(0, m, START_STRIDE):
        if table[p0][0] is None:
            continue
        dp = [[inf, inf] for _ in range(m)]
        prev = [[None, None] for _ in range(m)]
        dp[0][0] = 0.0
        for r2 in range(1, m):
            p = (p0 + r2) % m
            for k2 in (0, 1):
                cell = table[p][k2]
                if cell is None:
                    continue
                lo, hi, ideal = _gap_spec(cell[1])
                for di in range(math.ceil((lo + RANGE_MARGIN) / step), math.floor((hi - RANGE_MARGIN) / step) + 1):
                    r1 = r2 - di
                    if r1 < 0:
                        break
                    base = dp[r1][1 - k2]
                    if base == inf:
                        continue
                    cost = base + (di * step - ideal) ** 2
                    if cost < dp[r2][k2]:
                        dp[r2][k2], prev[r2][k2] = cost, (r1, 1 - k2)
        lo, hi, ideal = _gap_spec(table[p0][0][1])
        for r in range(1, m):
            stud = (m - r) * step
            if dp[r][1] == inf or not (lo + RANGE_MARGIN <= stud <= hi - RANGE_MARGIN):
                continue
            total = dp[r][1] + (stud - ideal) ** 2
            if best is None or total < best[0]:
                chain, node = [], (r, 1)
                while node is not None:
                    chain.append(node)
                    node = prev[node[0]][node[1]]
                best = (total, p0, chain[::-1])
    if best is None:
        raise RuntimeError("no lantern rhythm satisfies the spacing rules")
    _, p0, chain = best
    return tuple(table[(p0 + r) % m][k] for r, k in chain)


# ---- Placement -------------------------------------------------------------
def sample_point(rng, region):
    if region == "fog":
        return rng.uniform(FOG[0], FOG[1]), rng.uniform(FOG[2], FOG[3])
    return rng.uniform(-LIMIT, LIMIT), rng.uniform(-LIMIT, LIMIT)


def region_accepts(region, x, z, roll):
    if region == "fog":
        return in_fog(x, z)
    if in_fog(x, z):
        return False
    edge = max(abs(x), abs(z)) >= EDGE_RING_MIN
    if region == "edge":
        return edge
    if edge:
        return False
    # Scatter hugs the trail a little so the outside still frames the route.
    return roll < (1.0 if route_distance((x, z)) <= 45.0 else 0.5)


def candidate(rng, name, region):
    x, z = sample_point(rng, region)
    roll = rng.random()
    lo, hi = PROPS[name]["scale"]
    scale = rng.uniform(lo, hi)
    yaw = rng.uniform(0.0, 360.0)
    if not region_accepts(region, x, z, roll):
        return None
    return make_instance(name, x, z, yaw, scale)


def place_many(placer, rng, name, region, count, tries=4000, keep=5):
    for _ in range(count):
        best, found = None, 0
        for _ in range(tries):
            inst = candidate(rng, name, region)
            if inst is None or not placer.valid(inst):
                continue
            score = placer.nearest_forest(inst)
            if best is None or score > best[0]:
                best = (score, inst)
            found += 1
            if found >= keep:
                break
        if best is None:
            raise RuntimeError("cannot place %s in %s" % (name, region))
        placer.add(best[1])


def place_cover(placer, rng):
    """Trunks 13-26 studs from the nest, spread around it, never blocking reserved lanes."""
    angles = []
    for name in COVER_SEQUENCE:
        best, found = None, 0
        for _ in range(6000):
            ang = rng.uniform(0.0, 2 * math.pi)
            rad = rng.uniform(19.0, 25.5)
            lo, hi = PROPS[name]["scale"]
            scale, yaw = rng.uniform(lo, hi), rng.uniform(0.0, 360.0)
            inst = make_instance(name, NEST[0] + rad * math.cos(ang), NEST[1] + rad * math.sin(ang), yaw, scale)
            if not placer.valid(inst):
                continue
            sep = min([abs((ang - a + math.pi) % (2 * math.pi) - math.pi) for a in angles] or [math.pi])
            if best is None or sep > best[0]:
                best = (sep, inst, ang)
            found += 1
            if found >= 12:
                break
        if best is None:
            raise RuntimeError("cannot place nest cover")
        angles.append(best[2])
        placer.add(best[1])


# ---- Reports ---------------------------------------------------------------
def sight_blockers(instances):
    """Trunks (circles) and pillars (boxes) that can block a ray at eye height."""
    blockers = [("pillar", shape) for shape in FIXED_SHAPES[:len(PILLARS)]]
    for inst in instances:
        if inst["name"] in TREES:
            blockers.append((inst["id"], body(inst)[0]))
    return blockers


def loop_fraction_within(loop, centre, radius):
    """Exact share of a closed polyline's length that lies within radius of centre."""
    inside = total = 0.0
    for i, a in enumerate(loop):
        b = loop[(i + 1) % len(loop)]
        dx, dz = b[0] - a[0], b[1] - a[1]
        fx, fz = a[0] - centre[0], a[1] - centre[1]
        qa, qb, qc = dx * dx + dz * dz, 2 * (fx * dx + fz * dz), fx * fx + fz * fz - radius * radius
        length = math.sqrt(qa)
        total += length
        disc = qb * qb - 4 * qa * qc
        if disc <= 0:
            continue
        root = math.sqrt(disc)
        t1, t2 = max(0.0, (-qb - root) / (2 * qa)), min(1.0, (-qb + root) / (2 * qa))
        if t2 > t1:
            inside += (t2 - t1) * length
    return inside / total


def nest_report(instances):
    blockers = sight_blockers(instances)
    sight, seeing = {}, 0
    for name, wp in PATROL.items():
        hits = sorted(ident for ident, shape in blockers if segment_hits_shape(wp, NEST, shape))
        seeing += not hits
        dist = math.dist(wp, NEST)
        sight[name] = {"waypoint": [wp[0], wp[1]], "distance": r3(dist), "blocked": bool(hits),
                       "blockers": hits, "within_detection_range_day": dist <= DETECTION_RANGE["day"],
                       "within_detection_range_night": dist <= DETECTION_RANGE["night"]}
    cover = [i for i in instances if i["name"] in TREES
             and COVER_BAND[0] <= math.dist((i["x"], i["z"]), NEST) <= COVER_BAND[1]]
    return {
        "nest": [NEST[0], NEST[1]], "band": list(COVER_BAND), "eye_height": EYE_HEIGHT,
        "cover_trunk_count": len(cover), "cover_trunk_ids": [i["id"] for i in cover],
        "cover_trunk_distances": {i["id"]: r3(math.dist((i["x"], i["z"]), NEST)) for i in cover},
        "doorway_distance": r3(math.dist(_instance_xz(instances, "FK_RuinDoorway"), NEST)),
        "sight": sight, "waypoints_seeing_nest": seeing,
        "patrol_loop_within_range": {
            "perimeter": r3(sum(math.dist(PATROL_LOOP[i], PATROL_LOOP[(i + 1) % 4]) for i in range(4))),
            "day_28": round(loop_fraction_within(PATROL_LOOP, NEST, DETECTION_RANGE["day"]), 4),
            "night_38": round(loop_fraction_within(PATROL_LOOP, NEST, DETECTION_RANGE["night"]), 4)},
        "note": "sight is tested against tree trunk cores (radius 2.5 evergreen, 3.4 dead, x scale) and "
                "pillars only; the plan also asserts the arch, doorway and logs do not cross these four rays",
    }


def _instance_xz(instances, name):
    inst = next(i for i in instances if i["name"] == name)
    return (inst["x"], inst["z"])


def canopy_cover(instances):
    covered = set()
    for inst in instances:
        if inst["name"] != "FK_Evergreen":
            continue
        radius = PROPS["FK_Evergreen"]["canopy_r"] * inst["scale"]
        for i in range(math.floor(inst["x"] - radius), math.ceil(inst["x"] + radius)):
            for j in range(math.floor(inst["z"] - radius), math.ceil(inst["z"] + radius)):
                if math.hypot(i + 0.5 - inst["x"], j + 0.5 - inst["z"]) <= radius:
                    covered.add((i, j))
    fog_cells = sum(1 for (i, j) in covered if in_fog(i + 0.5, j + 0.5))
    return fog_cells, len(covered) - fog_cells


def density_report(instances):
    fog_area = (FOG[1] - FOG[0]) * (FOG[3] - FOG[2])
    out_area = MAP_SIZE * MAP_SIZE - fog_area
    zones = {"fog": {"forest_props": 0, "trees": 0, "all_instances": 0},
             "outside": {"forest_props": 0, "trees": 0, "all_instances": 0}}
    for inst in instances:
        zone = zones[inst["zone"]]
        zone["all_instances"] += 1
        zone["forest_props"] += inst["name"] in FOREST
        zone["trees"] += inst["name"] in TREES
    area = {"fog": fog_area, "outside": out_area}
    per = {z: {k: r3(v / area[z] * 1000) for k, v in zones[z].items()} for z in zones}
    ratio = {k: r3(zones["fog"][k] / fog_area / (zones["outside"][k] / out_area)) for k in ("forest_props", "trees")}
    fog_cells, out_cells = canopy_cover(instances)
    dead = [i for i in instances if i["name"] in ("FK_DeadTree", "FK_FallenLog")]
    return {
        "area_sq_studs": {"fog": int(fog_area), "outside": int(out_area)},
        "counts": zones,
        "per_1000_sq_studs": per,
        "fog_to_outside_ratio": ratio,
        "canopy_cover_fraction": {"fog": round(fog_cells / fog_area, 4), "outside": round(out_cells / out_area, 4)},
        "dead_trees_and_logs": {"total": len(dead), "in_fog": sum(i["zone"] == "fog" for i in dead),
                                "share_in_fog": r3(sum(i["zone"] == "fog" for i in dead) / len(dead))},
        "note": "density = instances per 1000 sq studs of gross zone area; forest_props = evergreen + dead tree + "
                "log; canopy cover = share of cells under an evergreen canopy (r10.4 x scale), the shade proxy",
    }


def totals_report(instances):
    by_name = {}
    for name, spec in PROPS.items():
        n = sum(i["name"] == name for i in instances)
        by_name[name] = {"count": n, "triangles": n * spec["tris"]}
    return {"instances": len(instances), "triangles": sum(v["triangles"] for v in by_name.values()),
            "by_name": by_name, "budget": {"max_instances": MAX_INSTANCES, "max_triangles": MAX_TRIANGLES}}


def landmark_report(instances):
    arch = next(i for i in instances if i["name"] == "FK_RootArch")
    door = next(i for i in instances if i["name"] == "FK_RuinDoorway")
    pillar_gap = min(shape_gap(rect, pillar) for rect in footprint(door) for pillar in FIXED_SHAPES[:len(PILLARS)])
    overshoot = max(max(FOG[0] - x, x - FOG[1], FOG[2] - z, z - FOG[3], 0.0) for x, z in footprint(arch)[0].pts)
    margins = {}
    for inst in (arch, door):
        lo, hi = PROPS[inst["name"]]["gap"]
        margins[inst["id"]] = {"left": r3(-lo - ROUTE_WIDTH / 2), "right": r3(hi - ROUTE_WIDTH / 2)}
    return {
        "root_arch": {"id": arch["id"], "leg": "clearing->ruin", "studs_before_ruin": ARCH_BEFORE_RUIN,
                      "anchor_in_fog_zone": in_fog(arch["x"], arch["z"]),
                      "footprint_overshoot_past_fog_edge": r3(overshoot),
                      "distance_to_guardian_home": r3(math.dist((arch["x"], arch["z"]), HOME))},
        "ruin_doorway": {"id": door["id"], "leg": "nest->marsh", "studs_after_nest": DOORWAY_AFTER_NEST,
                         "in_territory": in_territory(door["x"], door["z"]),
                         "distance_to_guardian_home": r3(math.dist((door["x"], door["z"]), HOME)),
                         "gap_to_nearest_pillar": r3(pillar_gap)},
        "corridor_margin_each_side_of_14_studs": margins,
    }


def lantern_report(instances):
    items = []
    cells = build_lanterns()
    for k, cell in enumerate(cells):
        prev = cells[k - 1]
        items.append({"arc": r3(cell[2]), "side": cell[3], "in_territory": cell[1],
                      "gap_from_previous": r3((cell[2] - prev[2]) % LOOP)})
    return {"count": len(cells), "route_length": r3(LOOP), "offset": LANTERN_OFFSET,
            "spacing_outside_territory": [LANTERN_OUT[0], LANTERN_OUT[1]],
            "spacing_inside_territory": [LANTERN_IN[0], LANTERN_IN[1]], "sides_alternate": True,
            "reading_of_rule": "lantern i+2 is always >= 80 studs of route away, so no lantern reveals more than the next",
            "items": items}


def inputs_report():
    return {
        "map_size": [MAP_SIZE, MAP_SIZE], "edge_margin": EDGE_MARGIN, "route_width": ROUTE_WIDTH,
        "route_clear_radius": CLEAR_RADIUS,
        "route_nodes": {name: [p[0], p[1]] for name, p in ROUTE_NODES},
        "guardian": {"home": list(HOME), "leash": LEASH,
                     "fog_zone": {"x": [FOG[0], FOG[1]], "z": [FOG[2], FOG[3]]},
                     "patrol_loop": {k: list(v) for k, v in PATROL.items()}},
        "safe_circles": {"camp": {"centre": [-140.0, 140.0], "r": 35.0}, "shelter": {"centre": [105.0, 125.0], "r": 22.0}},
        "pillars": [list(p) for p in PILLARS], "nest_stone_ring_radius": NEST_RING_RADIUS,
        "old_nest": list(OLD_NEST), "new_nest": list(NEST),
        "marsh_pool": {"centre": list(POOL_CENTRE), "size": [POOL_HALF[0] * 2, POOL_HALF[1] * 2]},
        "design_thresholds": {"base_gap": BASE_GAP, "node_clear": NODE_CLEAR, "node_reach_clear": NODE_REACH_CLEAR,
                              "patrol_clear": PATROL_CLEAR, "pool_clear": POOL_CLEAR,
                              "sight_lanes_reserved_for": list(LANE_WAYPOINTS)},
        "props_measured_from": "assets/blender/forest-kit/forest-kit-report.json (+ forest-kit-geometry.json)",
        "props": {name: {k: (list(v) if isinstance(v, tuple) else v) for k, v in spec.items() if k != "scale"}
                  for name, spec in PROPS.items()},
        "scale_range": {name: list(spec["scale"]) for name, spec in PROPS.items() if "scale" in spec},
    }


CONVENTIONS = {
    "units": "studs, origin at the map centre",
    "axes": "x east (right on the plan), z south (down on the plan)",
    "rotation_y_deg": "same as CFrame.Angles(0, math.rad(r), 0); local +X -> (cos r, -sin r), "
                      "local +Z -> (sin r, cos r) in (x, z)",
    "pivot": "kit origin placed at x, z on the ground; scale is uniform (1 for arch, doorway, lantern)",
    "footprints": "trees: root flare circle r8 x scale (reach) and trunk core 2.5/3.4 x scale (solid); logs, arch "
                  "and doorway: symmetric rectangle bound of the measured bbox; Blender Y sign is not assumed",
    "authoring_axes": {
        "FK_FallenLog": "long axis along local X",
        "FK_RootArch": "span (inner clearance 16.3) along local X, route direction along local Z",
        "FK_RuinDoorway": "span (inner clearance 18.6) along local X, route direction along local Z",
        "FK_LanternMarker": "local +Z faces the route centreline",
    },
}


# ---- Generation ------------------------------------------------------------
def generate(seed=DEFAULT_SEED):
    rng = random.Random(seed)
    placer = Placer()
    for lm in build_landmarks():
        placer.add(lm)
    for cell in build_lanterns():
        placer.add(cell[0])
    place_cover(placer, rng)
    cover_counts = {name: sum(1 for n in COVER_SEQUENCE if n == name) for name in TREES}
    for name, count in FOG_COUNTS:
        place_many(placer, rng, name, "fog", count - cover_counts.get(name, 0))
    for name, region, count in OUTSIDE_COUNTS:
        place_many(placer, rng, name, region, count)

    order = list(PROPS)
    instances = [dict(inst) for inst, _, _, _ in sorted(placer.items, key=lambda it: order.index(it[0]["name"]))]
    counters = {}
    for inst in instances:
        counters[inst["name"]] = counters.get(inst["name"], 0) + 1
        inst["id"] = "%s_%03d" % (inst["name"], counters[inst["name"]])
        inst["zone"] = "fog" if in_fog(inst["x"], inst["z"]) else "outside"
    instances = [{k: inst[k] for k in ("id", "name", "x", "z", "rotation_y_deg", "scale", "zone")}
                 for inst in instances]

    for inst in instances:  # landmarks and logs must not cross the reserved rays either
        if inst["name"] in LANDMARKS or inst["name"] == "FK_FallenLog":
            for shape in footprint(inst):
                for wp in PATROL.values():
                    if segment_hits_shape(wp, NEST, shape):
                        raise RuntimeError("%s crosses a patrol sight ray" % inst["id"])

    totals = totals_report(instances)
    if totals["instances"] > MAX_INSTANCES or totals["triangles"] > MAX_TRIANGLES:
        raise RuntimeError("budget exceeded: %s" % totals)
    return {
        "name": LAYOUT_NAME,
        "seed": seed,
        "conventions": CONVENTIONS,
        "inputs": inputs_report(),
        "instances": instances,
        "totals": totals,
        "density": density_report(instances),
        "landmarks": landmark_report(instances),
        "lanterns": lantern_report(instances),
        "nest_cover": nest_report(instances),
    }


def to_json(layout):
    """Deterministic JSON text: stable key order, one instance per line, LF newlines."""
    parts = []
    for key, value in layout.items():
        if key == "instances":
            rows = ",\n".join("    " + json.dumps(row) for row in value)
            parts.append('  "instances": [\n%s\n  ]' % rows)
        else:
            parts.append("  %s: %s" % (json.dumps(key), json.dumps(value, indent=2).replace("\n", "\n  ")))
    return "{\n" + ",\n".join(parts) + "\n}\n"


# ---- Rendering -------------------------------------------------------------
CANVAS_W, CANVAS_H = 1500, 1370
MAP_SCALE, MAP_X0, MAP_Y0 = 2.4, 70.0, 80.0
LEGEND_X = 1062.0
INSET_RECT = (1050.0, 975.0, 440.0, 380.0)  # x, y, w, h of the detail panel
INSET_WINDOW = (-25.0, -133.0)               # world corner shown at the panel's top-left
INSET_SCALE = 440.0 / 105.0

C_PAGE, C_MAP = "#f7f5ef", "#e4dfd0"
C_FOG, C_FOG_EDGE = "#4b5d73", "#243447"
C_EVER, C_DEAD, C_LOG = "#1f6b3a", "#3d2610", "#8a5a2b"
C_LANTERN, C_LANTERN_EDGE = "#f5a623", "#6e4300"
C_ARCH, C_DOOR = "#8e44ad", "#2f4a63"
C_TERR, C_SAFE, C_PATROL = "#c0392b", "#27ae60", "#e67e22"
C_BAND, C_CORRIDOR = "#d9ccaa", "#bfa66c"
C_OK, C_BLOCKED, C_COVER = "#1e8449", "#c0392b", "#0b8fa8"
SYM_EVER, SYM_DEAD, SYM_LANTERN, SYM_RING = 8.0, 6.2, 7.0, 11.5  # symbol sizes in pixels


class World:
    """Maps world studs to pixels for one drawing (main map or detail panel)."""

    def __init__(self, scale, ox, oy, wx0=-200.0, wz0=-200.0):
        self.s, self.ox, self.oy, self.wx0, self.wz0 = scale, ox, oy, wx0, wz0

    def px(self, x):
        return self.ox + (x - self.wx0) * self.s

    def py(self, z):
        return self.oy + (z - self.wz0) * self.s


class Scene:
    """Primitive list rendered to SVG always and PNG when Pillow exists."""

    def __init__(self, width, height):
        self.w, self.h, self.items = width, height, []

    def rect(self, x, y, w, h, **style):
        self.items.append(("poly", [(x, y), (x + w, y), (x + w, y + h), (x, y + h)], style, True))

    def poly(self, pts, closed=True, **style):
        self.items.append(("poly", list(pts), style, closed))

    def circle(self, cx, cy, r, **style):
        self.items.append(("circle", (cx, cy, r), style, True))

    def line(self, pts, **style):
        self.items.append(("poly", list(pts), dict(style, fill=None), False))

    def text(self, x, y, s, size=13, fill="#1d2530", anchor="start", bold=False, halo=True):
        self.items.append(("text", (x, y, s), {"size": size, "fill": fill, "anchor": anchor,
                                              "bold": bold, "halo": halo}, True))

    def inset(self, x, y, sub):
        self.items.append(("scene", (x, y, sub), {}, True))

    # -- SVG --
    @staticmethod
    def _style(st):
        out = []
        fill = st.get("fill")
        out.append('fill="%s"' % fill if fill else 'fill="none"')
        if fill and st.get("fo", 1) != 1:
            out.append('fill-opacity="%s"' % st["fo"])
        if st.get("stroke"):
            out.append('stroke="%s" stroke-width="%s" stroke-linejoin="round" stroke-linecap="%s"'
                       % (st["stroke"], st.get("sw", 1), "butt" if st.get("dash") else "round"))
            if st.get("so", 1) != 1:
                out.append('stroke-opacity="%s"' % st["so"])
            if st.get("dash"):
                out.append('stroke-dasharray="%s"' % " ".join(str(d) for d in st["dash"]))
        return " ".join(out)

    def _svg_rows(self, rows):
        for kind, data, st, closed in self.items:
            if kind == "scene":
                x, y, sub = data
                rows.append('<svg x="%.2f" y="%.2f" width="%d" height="%d" viewBox="0 0 %d %d" overflow="hidden">'
                            % (x, y, sub.w, sub.h, sub.w, sub.h))
                sub._svg_rows(rows)
                rows.append("</svg>")
            elif kind == "circle":
                rows.append('<circle cx="%.2f" cy="%.2f" r="%.2f" %s/>' % (data + (self._style(st),)))
            elif kind == "poly":
                pts = " ".join("%.2f,%.2f" % p for p in data)
                rows.append('<%s points="%s" %s/>' % ("polygon" if closed else "polyline", pts, self._style(st)))
            else:
                x, y, s = data
                esc = s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                halo = ' stroke="#ffffff" stroke-width="3.5" stroke-linejoin="round" paint-order="stroke"' if st["halo"] else ""
                rows.append('<text x="%.2f" y="%.2f" font-size="%s" fill="%s" text-anchor="%s"%s%s>%s</text>'
                            % (x, y, st["size"], st["fill"], st["anchor"],
                               ' font-weight="bold"' if st["bold"] else "", halo, esc))

    def to_svg(self):
        rows = ['<?xml version="1.0" encoding="UTF-8"?>',
                '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d" '
                'font-family="Segoe UI, Arial, sans-serif">' % (self.w, self.h, self.w, self.h),
                "<title>Fog forest placement plan v1</title>",
                "<desc>Top-down plan view; north (-z) is up. Prop symbols are enlarged for readability.</desc>"]
        self._svg_rows(rows)
        rows.append("</svg>")
        return "\n".join(rows) + "\n"

    # -- PNG --
    def _render(self, ss):
        from PIL import Image, ImageDraw, ImageFont

        def rgba(color, alpha=1.0):
            return (int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16), round(255 * alpha))

        fonts = {}

        def font(size, bold):
            key = (size, bold)
            if key not in fonts:
                names = ("segoeuib.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf") if bold else \
                    ("segoeui.ttf", "arial.ttf", "DejaVuSans.ttf")
                for name in names:
                    try:
                        fonts[key] = ImageFont.truetype(name, round(size * ss))
                        break
                    except OSError:
                        continue
                else:
                    fonts[key] = ImageFont.load_default(round(size * ss))
            return fonts[key]

        def dashed(points, dash):
            on, off = dash[0] * ss, dash[1] * ss
            for (x1, y1), (x2, y2) in zip(points, points[1:]):
                length = math.hypot(x2 - x1, y2 - y1)
                pos = 0.0
                while pos < length:
                    end = min(pos + on, length)
                    yield ((x1 + (x2 - x1) * pos / length, y1 + (y2 - y1) * pos / length),
                           (x1 + (x2 - x1) * end / length, y1 + (y2 - y1) * end / length))
                    pos += on + off

        image = Image.new("RGB", (self.w * ss, self.h * ss), "#ffffff")
        draw = ImageDraw.Draw(image, "RGBA")
        for kind, data, st, closed in self.items:
            if kind == "scene":
                x, y, sub = data
                image.paste(sub._render(ss), (round(x * ss), round(y * ss)))
                continue
            if kind == "text":
                x, y, s = data
                kwargs = {"stroke_width": round(2.2 * ss), "stroke_fill": (255, 255, 255, 255)} if st["halo"] else {}
                draw.text((x * ss, y * ss), s, font=font(st["size"], st["bold"]), fill=rgba(st["fill"]),
                          anchor={"start": "ls", "middle": "ms", "end": "rs"}[st["anchor"]], **kwargs)
                continue
            if kind == "circle":
                cx, cy, r = data
                pts = [(cx + r * math.cos(a * math.pi / 90), cy + r * math.sin(a * math.pi / 90)) for a in range(181)]
                closed = True
            else:
                pts = data
            scaled = [(x * ss, y * ss) for x, y in pts]
            if st.get("fill") and closed:
                draw.polygon(scaled, fill=rgba(st["fill"], st.get("fo", 1)))
            if st.get("stroke"):
                outline = scaled + [scaled[0]] if closed else scaled
                color, width = rgba(st["stroke"], st.get("so", 1)), max(1, round(st.get("sw", 1) * ss))
                if st.get("dash"):
                    for a, b in dashed(outline, st["dash"]):
                        draw.line([a, b], fill=color, width=width)
                else:
                    draw.line(outline, fill=color, width=width, joint="curve")
                    if width > 3:  # round the line ends like the SVG caps
                        for p in (outline[0], outline[-1]):
                            draw.ellipse([p[0] - width / 2, p[1] - width / 2, p[0] + width / 2, p[1] + width / 2],
                                         fill=color)
        return image

    def to_png(self, path, ss=2):
        from PIL import Image
        image = self._render(ss).resize((self.w, self.h), Image.Resampling.LANCZOS)
        image.save(path, optimize=True)


def _clip_circle_to_fog(cx, cz, r, steps=180):
    """Territory area: leash circle clipped to the fog rectangle (Sutherland-Hodgman)."""
    pts = [(cx + r * math.cos(2 * math.pi * k / steps), cz + r * math.sin(2 * math.pi * k / steps))
           for k in range(steps)]
    for axis, bound, keep_less in ((0, FOG[0], False), (0, FOG[1], True), (1, FOG[2], False), (1, FOG[3], True)):
        def inside(p):
            return p[axis] <= bound if keep_less else p[axis] >= bound
        out = []
        for i, cur in enumerate(pts):
            prv = pts[i - 1]
            if inside(cur) != inside(prv):
                t = (bound - prv[axis]) / (cur[axis] - prv[axis])
                out.append((prv[0] + (cur[0] - prv[0]) * t, prv[1] + (cur[1] - prv[1]) * t))
            if inside(cur):
                out.append(cur)
        pts = out
    return pts


# Symbols take pixel coordinates so the map and the legend share them.
def sym_evergreen(sc, cx, cy, r):
    sc.poly([(cx, cy - 1.15 * r), (cx - r, cy + 0.8 * r), (cx + r, cy + 0.8 * r)], fill=C_EVER, stroke="#ffffff", sw=0.9)


def sym_dead(sc, cx, cy, r):
    sc.line([(cx - r, cy - r), (cx + r, cy + r)], stroke=C_DEAD, sw=2.4)
    sc.line([(cx - r, cy + r), (cx + r, cy - r)], stroke=C_DEAD, sw=2.4)


def sym_lantern(sc, cx, cy, r):
    sc.poly([(cx, cy - r), (cx + 0.8 * r, cy), (cx, cy + r), (cx - 0.8 * r, cy)], fill=C_LANTERN, stroke=C_LANTERN_EDGE, sw=1.2)


def sym_log(sc, cx, cy, w, h):
    sc.rect(cx - w / 2, cy - h / 2, w, h, fill=C_LOG, stroke=C_DEAD, sw=1)


def sym_wings(sc, cx, cy, color):
    sc.rect(cx - 15, cy - 6, 8, 12, fill=color, stroke="#111111", sw=1)
    sc.rect(cx + 7, cy - 6, 8, 12, fill=color, stroke="#111111", sw=1)
    sc.line([(cx - 7, cy), (cx + 7, cy)], stroke=color, sw=1.6, dash=(3, 2))


def draw_world(sc, layout, w, detail):
    """Draw the plan with transform w. detail=True is the zoomed nest panel (extra labels)."""
    s, px, py = w.s, w.px, w.py
    labels = []

    def label(x, y, text, size=13, bold=True, fill="#1d2530", anchor="start"):
        labels.append((x, y, text, size, bold, fill, anchor))

    nest_report_ = layout["nest_cover"]
    by = {name: [i for i in layout["instances"] if i["name"] == name] for name in PROPS}

    sc.rect(px(-200), py(-200), 400 * s, 400 * s, fill=C_MAP, stroke="#222222", sw=2)
    step = 10 if detail else 50
    for v in range(-200, 201, step):
        sc.line([(px(v), py(-200)), (px(v), py(200))], stroke="#000000", sw=0.8, so=0.10)
        sc.line([(px(-200), py(v)), (px(200), py(v))], stroke="#000000", sw=0.8, so=0.10)
        if not detail:
            sc.text(px(v), py(200) + 22, str(v), size=12, fill="#555555", anchor="middle", halo=False)
            sc.text(px(-200) - 8, py(v) + 4, str(v), size=12, fill="#555555", anchor="end", halo=False)
        elif v % 20 == 0:
            if INSET_WINDOW[0] <= v <= INSET_WINDOW[0] + 105:
                label(px(v), 14, str(v), size=11, bold=False, fill="#555555", anchor="middle")
            if INSET_WINDOW[1] <= v <= INSET_WINDOW[1] + 91:
                label(4, py(v) + 4, str(v), size=11, bold=False, fill="#555555")
    if not detail:
        sc.text(px(0), py(200) + 42, "x studs (east is right) | z studs (south is down, north = -z is up)",
                size=13, fill="#555555", anchor="middle", halo=False)

    # Zones
    sc.rect(px(FOG[0]), py(FOG[2]), (FOG[1] - FOG[0]) * s, (FOG[3] - FOG[2]) * s,
            fill=C_FOG, fo=0.30, stroke=C_FOG_EDGE, sw=2.2, dash=(10, 6))
    sc.poly([(px(x), py(z)) for x, z in _clip_circle_to_fog(HOME[0], HOME[1], LEASH)], fill=C_TERR, fo=0.13)
    sc.circle(px(HOME[0]), py(HOME[1]), LEASH * s, stroke=C_TERR, sw=2.2, dash=(9, 6))
    for centre, radius in SAFE_CIRCLES:
        sc.circle(px(centre[0]), py(centre[1]), radius * s, fill=C_SAFE, fo=0.16, stroke="#1e8449", sw=2, dash=(7, 4))
    sc.rect(px(POOL_CENTRE[0] - POOL_HALF[0]), py(POOL_CENTRE[1] - POOL_HALF[1]), POOL_HALF[0] * 2 * s,
            POOL_HALF[1] * 2 * s, fill="#2e9aa0", fo=0.40, stroke="#1d6f75", sw=1.2)
    for inst in by["FK_Evergreen"]:  # canopy shade, drawn beneath the trail
        sc.circle(px(inst["x"]), py(inst["z"]), PROPS["FK_Evergreen"]["canopy_r"] * inst["scale"] * s,
                  fill="#14532d", fo=0.14)

    # Route corridor: 20-stud clear band, 14-stud walkable corridor, centreline.
    loop = [(px(x), py(z)) for x, z in ROUTE + [ROUTE[0]]]
    sc.line(loop, stroke=C_BAND, sw=2 * CLEAR_RADIUS * s)
    sc.line(loop, stroke=C_CORRIDOR, sw=ROUTE_WIDTH * s)
    sc.line(loop, stroke="#5a4520", sw=1.3, dash=(8, 6))

    if detail:  # root flares: the footprint that must stay 10 studs off the centreline
        for inst in by["FK_Evergreen"] + by["FK_DeadTree"]:
            sc.circle(px(inst["x"]), py(inst["z"]), PROPS[inst["name"]]["roots_r"] * inst["scale"] * s,
                      stroke="#2d6a4f", sw=1.2, dash=(4, 4), so=0.8)
            sc.circle(px(inst["x"]), py(inst["z"]), PROPS[inst["name"]]["core_r"] * inst["scale"] * s,
                      fill=C_DEAD if inst["name"] == "FK_DeadTree" else "#0f3d22", fo=0.9)

    # Guardian patrol loop, sight rays.
    sc.poly([(px(x), py(z)) for x, z in PATROL_LOOP], stroke=C_PATROL, sw=2.6, dash=(9, 5))
    for name, wp in PATROL.items():
        entry = nest_report_["sight"][name]
        sc.line([(px(wp[0]), py(wp[1])), (px(NEST[0]), py(NEST[1]))],
                stroke=C_BLOCKED if entry["blocked"] else C_OK, sw=1.8, dash=(6, 4) if entry["blocked"] else None)
    for name, wp in PATROL.items():
        sc.circle(px(wp[0]), py(wp[1]), 4.4, fill=C_PATROL, stroke="#7a3e00", sw=1)
        if detail:
            dx, dy, anchor = {"E": (10, 5, "start"), "S": (0, 22, "middle"),
                              "W": (-8, -10, "start"), "N": (0, -10, "middle")}[name]
            label(px(wp[0]) + dx, py(wp[1]) + dy, "%s (%d,%d)" % (name, wp[0], wp[1]), size=13,
                  fill="#7a3e00", anchor=anchor)
    hx, hy = px(HOME[0]), py(HOME[1])
    sc.circle(hx, hy, 6, fill="#ffffff", stroke=C_TERR, sw=2)
    sc.line([(hx - 4, hy), (hx + 4, hy)], stroke=C_TERR, sw=2)
    sc.line([(hx, hy - 4), (hx, hy + 4)], stroke=C_TERR, sw=2)
    if detail:
        label(hx, hy + 34, "ruin node = Guardian home (0,-85)", size=12, fill="#8e2a1f", anchor="middle")

    # Pillars, nest stones, nests.
    for shape in FIXED_SHAPES[:len(PILLARS)]:
        sc.poly([(px(x), py(z)) for x, z in shape.pts], fill="#6b7280", stroke="#111827", sw=1)
    for shape in FIXED_SHAPES[len(PILLARS):]:
        sc.circle(px(shape.x), py(shape.z), shape.r * s, fill="#9ca3af", stroke="#374151", sw=1)
    for r in COVER_BAND:
        sc.circle(px(NEST[0]), py(NEST[1]), r * s, stroke=C_COVER, sw=1.6, dash=(3, 5))
        if detail:
            label(px(NEST[0]), py(NEST[1]) - r * s - 3, "%d" % r, size=11, bold=False, fill=C_COVER, anchor="middle")
    ox, oy = px(OLD_NEST[0]), py(OLD_NEST[1])
    if not detail:
        sc.circle(ox, oy, NEST_RING_RADIUS * s, stroke="#6b7280", sw=2, dash=(5, 4))
        sc.line([(ox - 12, oy - 12), (ox + 12, oy + 12)], stroke="#6b7280", sw=3)
        sc.line([(ox - 12, oy + 12), (ox + 12, oy - 12)], stroke="#6b7280", sw=3)
        label(ox, oy - 34, "OLD nest (110,-130)", size=13, fill="#4b5563", anchor="middle")
        label(ox, oy - 19, "superseded, 118.9 from home", size=12, bold=False, fill="#4b5563", anchor="middle")
    nx, ny = px(NEST[0]), py(NEST[1])
    star = []
    for k in range(10):
        rad = 11 if k % 2 == 0 else 5
        ang = -math.pi / 2 + k * math.pi / 5
        star.append((nx + rad * math.cos(ang), ny + rad * math.sin(ang)))
    sc.poly(star, fill="#ffd23f", stroke="#7a5b00", sw=1.6)
    if detail:
        label(nx + 3, ny + 25, "NEW nest (35,-99)", size=13, fill="#6a4a00")
    else:
        label(nx, ny - 26 * s - 12, "NEW nest (35,-99)", size=14, fill="#6a4a00", anchor="middle")

    # Route nodes.
    offsets = {"camp": (14, -50, "start"), "clearing": (16, 4, "start"), "ruin": (-96, 36, "start"),
               "marsh": (-16, -30, "end"), "shelter": (-30, -36, "end")}
    for name, (x, z) in ROUTE_NODES:
        if name == "nest":
            continue
        sc.circle(px(x), py(z), 5, fill="#ffffff", stroke="#3a2f12", sw=2)
        if not detail:
            dx, dy, anchor = offsets[name]
            label(px(x) + dx, py(z) + dy, "%s (%d,%d)" % (name, x, z), size=13, fill="#3a2f12", anchor=anchor)

    # Props.
    for inst in by["FK_FallenLog"]:
        sc.poly([(px(x), py(z)) for x, z in footprint(inst)[0].pts], fill=C_LOG, stroke=C_DEAD, sw=1)
    for inst in by["FK_Evergreen"]:
        sym_evergreen(sc, px(inst["x"]), py(inst["z"]), SYM_EVER)
    for inst in by["FK_DeadTree"]:
        sym_dead(sc, px(inst["x"]), py(inst["z"]), SYM_DEAD)
    ids = {i["id"]: i for i in layout["instances"]}
    for ident in nest_report_["cover_trunk_ids"]:
        found = ids[ident]
        sc.circle(px(found["x"]), py(found["z"]), SYM_RING, stroke=C_COVER, sw=2.4)
        if detail:
            label(px(found["x"]) + 14, py(found["z"]) - 12, "%.1f" % nest_report_["cover_trunk_distances"][ident],
                  size=12, fill=C_COVER)
    for inst in by["FK_LanternMarker"]:
        sym_lantern(sc, px(inst["x"]), py(inst["z"]), SYM_LANTERN)
    for name, color, tag in (("FK_RootArch", C_ARCH, "ROOT ARCH (first landmark)"),
                             ("FK_RuinDoorway", C_DOOR, "RUINED DOORWAY")):
        inst, spec = by[name][0], PROPS[name]
        (rect,) = footprint(inst)
        sc.poly([(px(x), py(z)) for x, z in rect.pts], fill=color, fo=0.20, stroke="#111111", sw=1.4)
        ex, _ = local_axes(inst["rotation_y_deg"])
        _, ez = local_axes(inst["rotation_y_deg"])
        for edge in spec["gap"]:  # measured inner clearance edges across the full depth
            cx, cz = inst["x"] + edge * ex[0], inst["z"] + edge * ex[1]
            sc.line([(px(cx - spec["half"][1] * ez[0]), py(cz - spec["half"][1] * ez[1])),
                     (px(cx + spec["half"][1] * ez[0]), py(cz + spec["half"][1] * ez[1]))],
                    stroke=color, sw=2.4)
        if name == "FK_RootArch" and not detail:
            label(px(inst["x"]) - 4, py(inst["z"]) + 34 * s / 2.4 - 8, tag, size=13, fill=color, anchor="end")
        elif name == "FK_RuinDoorway":
            label(px(inst["x"]) + (22 if detail else 42), py(inst["z"]) + (-4 if detail else 4),
                  "DOORWAY" if detail else tag, size=13, fill=color)
    if detail:
        for shape in FIXED_SHAPES[:1]:
            label(px(-10) - 8, py(-92) - 8, "pillars", size=12, fill="#374151", anchor="end")

    for x, y, text, size, bold, fill, anchor in labels:  # labels last so nothing covers them
        sc.text(x, y, text, size=size, bold=bold, fill=fill, anchor=anchor)


def build_scene(layout):
    sc = Scene(CANVAS_W, CANVAS_H)
    sc.rect(0, 0, CANVAS_W, CANVAS_H, fill=C_PAGE)
    main = World(MAP_SCALE, MAP_X0, MAP_Y0)
    draw_world(sc, layout, main, detail=False)
    # Marker for the detail window on the main map.
    wx, wz = INSET_WINDOW
    ww, wh = INSET_RECT[2] / INSET_SCALE, INSET_RECT[3] / INSET_SCALE
    sc.rect(main.px(wx), main.py(wz), ww * MAP_SCALE, wh * MAP_SCALE, stroke="#111111", sw=1.8, dash=(5, 3))
    sc.text(main.px(wx) - 4, main.py(wz) - 6, "Detail inset window", size=12, bold=True, anchor="end")

    sc.text(MAP_X0, 36, "Fog forest placement plan v1 - top-down", size=24, bold=True, halo=False)
    sc.text(MAP_X0, 60, "seed %d | 400 x 400 studs | north (-z) is up | symbols enlarged, logs, arch and doorway "
            "drawn at measured footprint" % layout["seed"], size=14, fill="#444444", halo=False)

    # Detail panel (nest, ruin, patrol loop) as a clipped sub-scene.
    ix, iy, iw, ih = INSET_RECT
    sub = Scene(int(iw), int(ih))
    draw_world(sub, layout, World(INSET_SCALE, 0.0, 0.0, wx, wz), detail=True)
    sc.text(ix, iy - 10, "Detail: nest, ruin and patrol loop (x -25..80, z -133..-42)", size=15, bold=True,
            fill="#33415c", halo=False)
    sc.inset(ix, iy, sub)
    sc.rect(ix, iy, iw, ih, stroke="#111111", sw=1.6)

    draw_legend(sc, layout)
    draw_notes(sc, layout)
    return sc


def draw_notes(sc, layout):
    nest = layout["nest_cover"]["sight"]
    dens = layout["density"]
    arch = layout["landmarks"]["root_arch"]
    x, y = MAP_X0, 1118.0
    sc.text(x, y, "Reading notes", size=16, bold=True, fill="#33415c", halo=False)
    lines = [
        "Trees and logs keep roots and bases >= 10 studs off the route centreline; lanterns sit 10.5 out, alternating sides.",
        "Footprints are the measured Blender kit: tree roots flare to r8 (trunk core 2.5 / 3.4), arch %.1f x %.1f, doorway %.1f x %.1f."
        % (2 * PROPS["FK_RootArch"]["half"][0], 2 * PROPS["FK_RootArch"]["half"][1],
           2 * PROPS["FK_RuinDoorway"]["half"][0], 2 * PROPS["FK_RuinDoorway"]["half"][1]),
        "Arch and doorway footprints are reserved; their measured inner clearance (16.3 / 18.6) covers the 14-stud corridor.",
        "Arch footprint overshoots the west fog edge by %.1f studs; its passage and pivot are inside the fog zone." % arch["footprint_overshoot_past_fog_edge"],
        "Cover trunks (ringed) are 13-26 studs from the nest. The E and N sight lanes stay clear so the guardian can detect players.",
        "Patrol is a diamond E S W N. Detection range 28 by day, 38 by night: E (%.1f) by day, E and N (%.1f) at night; "
        "S and W are blocked by pillars." % (nest["E"]["distance"], nest["N"]["distance"]),
        "Patrol loop length within 28 of the nest: %.0f%%; within 38: %.0f%%."
        % (100 * layout["nest_cover"]["patrol_loop_within_range"]["day_28"],
           100 * layout["nest_cover"]["patrol_loop_within_range"]["night_38"]),
        "Lanterns: 40-55 studs apart outside the territory, 62-78 inside; lantern i+2 is always >= 80 studs of route away.",
        "Shade proxy: evergreen canopy r10.4 x scale covers %.0f%% of the fog zone and %.0f%% outside; dead trees are bare."
        % (100 * dens["canopy_cover_fraction"]["fog"], 100 * dens["canopy_cover_fraction"]["outside"]),
    ]
    for i, text in enumerate(lines):
        sc.text(x, y + 26 + i * 23, text, size=13, halo=False)


def draw_legend(sc, layout):
    totals, dens, nest = layout["totals"], layout["density"], layout["nest_cover"]
    x, y = LEGEND_X, 100.0
    sc.rect(x - 12, y - 30, CANVAS_W - x - 6, 880, fill="#ffffff", stroke="#c9c4b4", sw=1.2)
    sc.text(x, y, "Legend", size=20, bold=True, halo=False)
    y += 24
    sym_x = x + 22

    def row(label, symbol=None, step=22.0, size=13.5, bold=False):
        nonlocal y
        if symbol:
            symbol(sym_x, y - 4)
        sc.text(x + 56, y, label, size=size, bold=bold, halo=False)
        y += step

    def head(label):
        nonlocal y
        y += 5
        sc.text(x, y, label, size=15, bold=True, fill="#33415c", halo=False)
        y += 21

    by = totals["by_name"]
    head("Props (count x triangles each)")
    row("FK_Evergreen  %d x %d" % (by["FK_Evergreen"]["count"], PROPS["FK_Evergreen"]["tris"]), lambda cx, cy: sym_evergreen(sc, cx, cy, 8))
    row("FK_DeadTree  %d x %d" % (by["FK_DeadTree"]["count"], PROPS["FK_DeadTree"]["tris"]), lambda cx, cy: sym_dead(sc, cx, cy, 6.5))
    row("FK_FallenLog  %d x %d" % (by["FK_FallenLog"]["count"], PROPS["FK_FallenLog"]["tris"]), lambda cx, cy: sym_log(sc, cx, cy, 24, 8))
    row("FK_RootArch  %d x %d" % (by["FK_RootArch"]["count"], PROPS["FK_RootArch"]["tris"]), lambda cx, cy: sym_wings(sc, cx, cy, C_ARCH))
    row("FK_RuinDoorway  %d x %d" % (by["FK_RuinDoorway"]["count"], PROPS["FK_RuinDoorway"]["tris"]), lambda cx, cy: sym_wings(sc, cx, cy, C_DOOR))
    row("FK_LanternMarker  %d x %d" % (by["FK_LanternMarker"]["count"], PROPS["FK_LanternMarker"]["tris"]), lambda cx, cy: sym_lantern(sc, cx, cy, 7.5))
    row("Tree root flare r8 (detail panel only)", lambda cx, cy: sc.circle(cx, cy, 9, stroke="#2d6a4f", sw=1.4, dash=(3, 3)))

    head("Zones and route")
    row("Fog zone x[-45,165] z[-165,35]", lambda cx, cy: sc.rect(cx - 16, cy - 8, 32, 16, fill=C_FOG, fo=0.30, stroke=C_FOG_EDGE, sw=1.6, dash=(5, 3)))
    row("Guardian territory (80 leash, inside fog)", lambda cx, cy: sc.rect(cx - 16, cy - 8, 32, 16, fill=C_TERR, fo=0.20))
    row("Leash circle r80 around home", lambda cx, cy: sc.line([(cx - 16, cy), (cx + 16, cy)], stroke=C_TERR, sw=2.2, dash=(6, 4)))
    row("Safe circle (camp r35, shelter r22)", lambda cx, cy: sc.rect(cx - 16, cy - 8, 32, 16, fill=C_SAFE, fo=0.25, stroke="#1e8449", sw=1.6, dash=(5, 3)))
    row("Route corridor 14 studs + clear to 10", lambda cx, cy: (sc.rect(cx - 16, cy - 9, 32, 18, fill=C_BAND), sc.rect(cx - 16, cy - 5, 32, 10, fill=C_CORRIDOR)))
    row("Route centreline", lambda cx, cy: sc.line([(cx - 16, cy), (cx + 16, cy)], stroke="#5a4520", sw=1.5, dash=(7, 5)))
    row("Patrol loop (diamond E S W N, home +/-16)", lambda cx, cy: (sc.line([(cx - 16, cy), (cx + 16, cy)], stroke=C_PATROL, sw=2.6, dash=(8, 4)), sc.circle(cx, cy, 4, fill=C_PATROL)))
    row("Ruin pillars (3 x 3)", lambda cx, cy: sc.rect(cx - 5, cy - 5, 10, 10, fill="#6b7280", stroke="#111827", sw=1))
    row("Nest stones (ring r9)", lambda cx, cy: sc.circle(cx, cy, 5, fill="#9ca3af", stroke="#374151", sw=1))
    row("OLD nest (110,-130), superseded", lambda cx, cy: (sc.circle(cx, cy, 8, stroke="#6b7280", sw=1.8, dash=(4, 3)), sc.line([(cx - 6, cy - 6), (cx + 6, cy + 6)], stroke="#6b7280", sw=2.4), sc.line([(cx - 6, cy + 6), (cx + 6, cy - 6)], stroke="#6b7280", sw=2.4)))
    row("NEW nest (35,-99)", lambda cx, cy: sc.poly([(cx + (9 if k % 2 == 0 else 4) * math.cos(-math.pi / 2 + k * math.pi / 5), cy + (9 if k % 2 == 0 else 4) * math.sin(-math.pi / 2 + k * math.pi / 5)) for k in range(10)], fill="#ffd23f", stroke="#7a5b00", sw=1.4))
    row("Cover band 13-26 + ringed cover trunks", lambda cx, cy: sc.circle(cx, cy, 9, stroke=C_COVER, sw=2.2))
    row("Sight ray clear / blocked (eye 3.7)", lambda cx, cy: (sc.line([(cx - 16, cy - 3), (cx + 16, cy - 3)], stroke=C_OK, sw=2), sc.line([(cx - 16, cy + 5), (cx + 16, cy + 5)], stroke=C_BLOCKED, sw=2, dash=(5, 3))))

    head("Budget and density")
    row("Instances %d / %d   Triangles %s / %s" % (totals["instances"], MAX_INSTANCES,
                                                   format(totals["triangles"], ","), format(MAX_TRIANGLES, ",")), bold=True)
    per = dens["per_1000_sq_studs"]
    row("Forest props per 1000 sq studs: fog %.2f, outside %.2f" % (per["fog"]["forest_props"], per["outside"]["forest_props"]))
    row("Ratio fog:outside  forest %.1fx, trees %.1fx" % (dens["fog_to_outside_ratio"]["forest_props"], dens["fog_to_outside_ratio"]["trees"]))
    row("Canopy shade: fog %.0f%%, outside %.0f%%" % (100 * dens["canopy_cover_fraction"]["fog"], 100 * dens["canopy_cover_fraction"]["outside"]))
    row("Dead trees + logs in fog: %d of %d" % (dens["dead_trees_and_logs"]["in_fog"], dens["dead_trees_and_logs"]["total"]))

    head("Nest cover and patrol sight")
    row("Cover trunks 13-26 from nest: %d" % nest["cover_trunk_count"])
    for name, entry in nest["sight"].items():
        state = "BLOCKED by " + ", ".join(entry["blockers"]) if entry["blocked"] else "sees the nest"
        row("%s %5.1f studs: %s" % (name, entry["distance"], state))
    row("Waypoints seeing the nest: %d of 4" % nest["waypoints_seeing_nest"], bold=True)
    loop = nest["patrol_loop_within_range"]
    row("Patrol loop within 28 of nest: %.0f%%" % (100 * loop["day_28"]))
    row("Patrol loop within 38 of nest: %.0f%%" % (100 * loop["night_38"]))


# ---- Output ----------------------------------------------------------------
def write_outputs(layout, out_dir):
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    json_path = out_dir / (LAYOUT_NAME + ".json")
    json_path.write_bytes(to_json(layout).encode("utf-8"))
    written.append(json_path)
    scene = build_scene(layout)
    svg_path = out_dir / (LAYOUT_NAME + ".svg")
    svg_path.write_bytes(scene.to_svg().encode("utf-8"))
    written.append(svg_path)
    try:
        import PIL  # noqa: F401
    except ImportError:
        return written
    png_path = out_dir / (LAYOUT_NAME + ".png")
    scene.to_png(png_path)
    written.append(png_path)
    return written


def summary(layout):
    t, d, n, lm = layout["totals"], layout["density"], layout["nest_cover"], layout["landmarks"]
    lines = ["seed %d: %d instances, %d triangles (budget %d / %d)"
             % (layout["seed"], t["instances"], t["triangles"], MAX_INSTANCES, MAX_TRIANGLES)]
    lines += ["  %-18s x%-3d %6d tris" % (k, v["count"], v["triangles"]) for k, v in t["by_name"].items()]
    per = d["per_1000_sq_studs"]
    lines.append("density per 1000 sq studs, forest props: fog %.3f outside %.3f (ratio %.2f); trees: fog %.3f outside %.3f"
                 % (per["fog"]["forest_props"], per["outside"]["forest_props"], d["fog_to_outside_ratio"]["forest_props"],
                    per["fog"]["trees"], per["outside"]["trees"]))
    lines.append("canopy cover: fog %.1f%% outside %.1f%%" % (100 * d["canopy_cover_fraction"]["fog"],
                                                             100 * d["canopy_cover_fraction"]["outside"]))
    lines.append("nest cover trunks 13-26: %d %s" % (n["cover_trunk_count"], n["cover_trunk_distances"]))
    for name, entry in n["sight"].items():
        lines.append("  patrol %s %.1f studs: %s" % (name, entry["distance"],
                                                     "BLOCKED by %s" % entry["blockers"] if entry["blocked"] else "sees nest"))
    lines.append("waypoints seeing nest: %d of 4; patrol loop within 28: %.1f%%, within 38: %.1f%%"
                 % (n["waypoints_seeing_nest"], 100 * n["patrol_loop_within_range"]["day_28"],
                    100 * n["patrol_loop_within_range"]["night_38"]))
    lines.append("lanterns: %d; arch fog overshoot %.2f studs; corridor margins %s"
                 % (layout["lanterns"]["count"], lm["root_arch"]["footprint_overshoot_past_fog_edge"],
                    lm["corridor_margin_each_side_of_14_studs"]))
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)
    layout = generate(args.seed)
    for path in write_outputs(layout, args.out_dir):
        print("wrote", path)
    print(summary(layout))
    return 0


if __name__ == "__main__":
    sys.exit(main())
