"""Spec-test helpers for biome kits (expansion bible 5.2 conditional tests).

Standard library only. Builds on kit_spec_common.AssetSpecMixin (G1 to G14) and adds the
conditional rules P1, P2, W1, O1, R1, N1 plus the per-part rules the kit tables name.
Everything is recomputed from the geometry dump, never from the report's own arithmetic.
The builders import the measurement functions too, so one definition serves both sides.

A SPECS entry may carry these optional keys (all sizes in studs, Blender axes):
  clear (w, h)        passage: free width below h and free height over |x| <= w / 2
  limit (x, y)        footprint ceiling for a passage
  walk z              walkable top height; report lists collision_boxes
  ramps n             number of tilted end ramps among the collision boxes
  occluder h          sight blockers, each at least h tall, listed in the report
  gather (x, y, z)    gather point
  tiny h              height ceiling; the prop never blocks a camera or path
  clear_box (lo, hi)  box that no triangle may enter
  no_track            report lists no_track_rects that sit under a surface
  part_min_z {p: z}   every vertex of part p is at z or higher
  part_top_above {p: z}   part p reaches above z
  match_tops (a, b, d)    max Z of part a equals max Z of part b within d
All values are hypotheses, unvalidated until a real Roblox import.
"""

import math
import unittest

from kit_spec_common import (AssetSpecMixin, asset_triangles, bounds, part_triangles,
                             png_size)

PATH_WIDTH = 14.0
AVATAR_HEIGHT = 5.0
BOX_TOLERANCE = 0.5
SHEET_SIZE = (2000, 1000)
MAX_RAMP_DEGREES = 30.0


# ---------------------------------------------------------------------------
# Measurements (pure Python, shared with the builders)
# ---------------------------------------------------------------------------

def clip_axis(polygon, axis, low, high):
    """Clip a polygon to low <= p[axis] <= high (Sutherland-Hodgman, two planes)."""
    def clip(points, inside, boundary):
        out = []
        for index, current in enumerate(points):
            previous = points[index - 1]
            if inside(current) != inside(previous):
                t = (boundary - previous[axis]) / (current[axis] - previous[axis])
                out.append(tuple(p + (c - p) * t for p, c in zip(previous, current)))
            if inside(current):
                out.append(current)
        return out

    kept = clip(polygon, lambda p: p[axis] >= low, low)
    return clip(kept, lambda p: p[axis] <= high, high) if kept else []


def clear_width(triangles, height):
    """Free X gap around the pivot for geometry between ground and height, seen along Y."""
    low, high = float("-inf"), float("inf")
    for triangle in triangles:
        kept = clip_axis([(v[0], v[2]) for v in triangle], 1, 0.0, height)
        if not kept:
            continue
        xs = [p[0] for p in kept]
        if min(xs) <= 0.0 <= max(xs):
            return 0.0, 0.0
        if max(xs) < 0.0:
            low = max(low, max(xs))
        else:
            high = min(high, min(xs))
    return low, high


def clear_height(triangles, half_width):
    """Lowest geometry over the band |x| <= half_width, seen along Y."""
    lowest = float("inf")
    for triangle in triangles:
        kept = clip_axis([(v[0], v[2]) for v in triangle], 0, -half_width, half_width)
        if kept:
            lowest = min(lowest, min(p[1] for p in kept))
    return lowest


def measure_clearance(triangles, width, height):
    low, high = clear_width(triangles, height)
    return {"method": "triangles projected along Y", "width": high - low, "gap_low_x": low,
            "gap_high_x": high, "height": clear_height(triangles, width / 2),
            "width_probe_height": height, "height_probe_width": width}


def triangle_overlaps_box(triangle, low, high, eps=1e-6):
    """Separating-axis test. A triangle that only touches the box surface does not overlap."""
    centre = [(low[i] + high[i]) / 2 for i in range(3)]
    half = [(high[i] - low[i]) / 2 for i in range(3)]
    v = [[p[i] - centre[i] for i in range(3)] for p in triangle]
    for i in range(3):
        if min(p[i] for p in v) >= half[i] - eps or max(p[i] for p in v) <= -half[i] + eps:
            return False
    edges = [[v[(k + 1) % 3][i] - v[k][i] for i in range(3)] for k in range(3)]
    unit = ((1, 0, 0), (0, 1, 0), (0, 0, 1))

    def separated(axis):
        size = math.sqrt(sum(a * a for a in axis))
        if size < 1e-12:
            return False
        projected = [sum(p[i] * axis[i] for i in range(3)) for p in v]
        radius = sum(half[i] * abs(axis[i]) for i in range(3))
        return min(projected) >= radius - eps * size or max(projected) <= -radius + eps * size

    for edge in edges:
        for axis in unit:
            if separated((edge[1] * axis[2] - edge[2] * axis[1],
                          edge[2] * axis[0] - edge[0] * axis[2],
                          edge[0] * axis[1] - edge[1] * axis[0])):
                return False
    normal = (edges[0][1] * edges[1][2] - edges[0][2] * edges[1][1],
              edges[0][2] * edges[1][0] - edges[0][0] * edges[1][2],
              edges[0][0] * edges[1][1] - edges[0][1] * edges[1][0])
    return not separated(normal)


def top_height(triangles, x, y):
    """Highest upward-facing surface above (x, y), or None when nothing covers the point."""
    best = None
    for a, b, c in triangles:
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / det
        l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / det
        l3 = 1.0 - l1 - l2
        if min(l1, l2, l3) < -1e-9 or det < 0:  # det < 0 is a downward-facing triangle
            continue
        z = l1 * a[2] + l2 * b[2] + l3 * c[2]
        best = z if best is None else max(best, z)
    return best


def box_extent(box):
    """Axis-aligned half extents of a collision box that may be pitched about X."""
    sx, sy, sz = (s / 2 for s in box["size"])
    angle = math.radians(box.get("pitch_deg", 0.0))
    return (sx, abs(math.cos(angle)) * sy + abs(math.sin(angle)) * sz,
            abs(math.sin(angle)) * sy + abs(math.cos(angle)) * sz)


def inside_bbox(low, high, centre, extent, tolerance=BOX_TOLERANCE):
    return all(low[i] - tolerance <= centre[i] - extent[i] and centre[i] + extent[i] <= high[i] + tolerance
               for i in range(3))


# ---------------------------------------------------------------------------
# Conditional tests
# ---------------------------------------------------------------------------

class BiomeKitMixin(AssetSpecMixin):
    """G1 to G14 plus the conditional rules. Subclasses add SPECS and the artifact paths."""

    ASSET_KEY = "props"
    SHEET_SIZE = SHEET_SIZE

    def having(self, key):
        found = [(n, self.assets[n], self.geometry[n]) for n in self.SPECS if key in self.SPECS[n]]
        if not found:
            self.skipTest(f"no asset in this unit carries {key}")
        for name, asset, dump in found:
            with self.subTest(asset=name):
                yield name, self.SPECS[name], asset, dump

    def part_points(self, dump, name, label):
        points = [v for t in part_triangles(dump["parts"][self.object_name(name, label)]) for v in t]
        self.assertTrue(points, f"{label} has no geometry")
        return points

    # -- identity ---------------------------------------------------------
    def test_unvalidated_labels(self):
        self.assertTrue(self.report["unvalidated"])
        self.assertFalse(self.report["roblox_scale_verified"])
        for name, asset, _ in self.each_asset():
            self.assertEqual(asset["status"], "unvalidated")

    def test_sheet_is_four_columns_by_two_rows(self):
        self.assertEqual(png_size(self.RENDER_DIR / self.report["sheet_file"]), self.SHEET_SIZE)

    def test_every_part_stays_inside_the_asset_prefix(self):
        for name, asset, dump in self.each_asset():
            for object_name in dump["parts"]:
                self.assertTrue(object_name.startswith(name + "_"), object_name)

    # -- per-part rules ---------------------------------------------------
    def test_part_min_z(self):
        for name, spec, asset, dump in self.having("part_min_z"):
            for label, wanted in spec["part_min_z"].items():
                lowest = min(v[2] for v in self.part_points(dump, name, label))
                self.assertGreaterEqual(lowest, wanted - 0.01, f"{label} dips to {lowest:.3f}")

    def test_part_top_above(self):
        for name, spec, asset, dump in self.having("part_top_above"):
            for label, wanted in spec["part_top_above"].items():
                top = max(v[2] for v in self.part_points(dump, name, label))
                self.assertGreater(top, wanted, f"{label} tops out at {top:.3f}")

    def test_match_tops(self):
        for name, spec, asset, dump in self.having("match_tops"):
            first, second, delta = spec["match_tops"]
            top_a = max(v[2] for v in self.part_points(dump, name, first))
            top_b = max(v[2] for v in self.part_points(dump, name, second))
            self.assertAlmostEqual(top_a, top_b, delta=delta)

    # -- P1, P2 -----------------------------------------------------------
    def test_p1_passage_clearance_recomputed_from_geometry(self):
        for name, spec, asset, dump in self.having("clear"):
            width, height = spec["clear"]
            triangles = asset_triangles(dump)
            gap_low, gap_high = clear_width(triangles, height)
            free_height = clear_height(triangles, width / 2)
            self.assertGreaterEqual(gap_high - gap_low, width)
            self.assertLessEqual(gap_low, -width / 2, "gap must be centred on the pivot")
            self.assertGreaterEqual(gap_high, width / 2, "gap must be centred on the pivot")
            self.assertGreaterEqual(free_height, height)
            self.assertLessEqual(gap_low, -PATH_WIDTH / 2)
            self.assertGreaterEqual(gap_high, PATH_WIDTH / 2)
            self.assertGreater(free_height, AVATAR_HEIGHT)
            reported = asset["clearance"]
            self.assertAlmostEqual(reported["width"], gap_high - gap_low, delta=0.01)
            self.assertAlmostEqual(reported["height"], free_height, delta=0.01)

    def test_p2_footprint_fits_its_limit(self):
        for name, spec, asset, dump in self.having("limit"):
            low, high = bounds(asset_triangles(dump))
            self.assertLessEqual(high[0] - low[0], spec["limit"][0])
            self.assertLessEqual(high[1] - low[1], spec["limit"][1])

    # -- W1 ---------------------------------------------------------------
    def test_w1_walkable_top_and_collision_boxes(self):
        for name, spec, asset, dump in self.having("walk"):
            triangles = asset_triangles(dump)
            low, high = bounds(triangles)
            boxes = asset["collision_boxes"]
            self.assertTrue(boxes)
            ramps = [b for b in boxes if not b["name"].startswith("walk")]
            self.assertEqual(len(ramps), spec.get("ramps", 0))
            for box in boxes:
                self.assertTrue(inside_bbox(low, high, box["center"], box_extent(box)), box["name"])
            for box in ramps:
                self.assertLessEqual(abs(box["pitch_deg"]), MAX_RAMP_DEGREES, box["name"])
            walks = [b for b in boxes if b["name"].startswith("walk")]
            self.assertTrue(walks)
            for box in walks:
                self.assertAlmostEqual(box["center"][2] + box["size"][2] / 2, spec["walk"], delta=0.01)
                cx, cy = box["center"][:2]
                hx, hy = box["size"][0] / 2, box["size"][1] / 2
                tops = [v[2] for v in (v for t in triangles for v in t)
                        if abs(v[0] - cx) <= hx and abs(v[1] - cy) <= hy]
                self.assertTrue(tops, "no vertex over the walk area")
                self.assertAlmostEqual(max(tops), spec["walk"], delta=0.2)
                for i in range(7):  # the surface itself must carry the player along the box
                    y = cy - hy + 2 * hy * (i + 0.5) / 7
                    surface = top_height(triangles, cx, y)
                    self.assertIsNotNone(surface, f"hole in the walk surface at y={y:.2f}")
                    self.assertAlmostEqual(surface, spec["walk"], delta=0.25)

    # -- O1 ---------------------------------------------------------------
    def test_o1_occluder_boxes(self):
        for name, spec, asset, dump in self.having("occluder"):
            low, high = bounds(asset_triangles(dump))
            boxes = asset["occluders"]
            self.assertTrue(boxes)
            for box in boxes:
                self.assertTrue(inside_bbox(low, high, box["center"], [s / 2 for s in box["size"]]),
                                box["name"])
                self.assertGreaterEqual(box["size"][2], spec["occluder"], box["name"])
            if "clear_box" in spec:
                c_low, c_high = spec["clear_box"]
                for box in boxes:
                    half = [s / 2 for s in box["size"]]
                    inside = all(box["center"][i] - half[i] < c_high[i] - 0.01
                                 and box["center"][i] + half[i] > c_low[i] + 0.01 for i in range(3))
                    self.assertFalse(inside, f"{box['name']} blocks the shelter")

    # -- R1 ---------------------------------------------------------------
    def test_r1_gather_point(self):
        for name, spec, asset, dump in self.having("gather"):
            low, high = bounds(asset_triangles(dump))
            point = asset["gather_point"]
            for measured, wanted in zip(point, spec["gather"]):
                self.assertAlmostEqual(measured, wanted, delta=0.01)
            for axis in range(3):
                self.assertGreaterEqual(point[axis], low[axis] - 1.0)
                self.assertLessEqual(point[axis], high[axis] + 1.0)
            self.assertLessEqual(point[2], 5.0)

    # -- N1 ---------------------------------------------------------------
    def test_n1_tiny_props_never_block(self):
        for name, spec, asset, dump in self.having("tiny"):
            low, high = bounds(asset_triangles(dump))
            self.assertLessEqual(high[2], spec["tiny"] + 1e-6)
            self.assertTrue(asset["tiny"])
            self.assertNotIn("collision_boxes", asset)

    # -- shelter box and no-track rectangles --------------------------------
    def test_clear_box_holds_no_triangles(self):
        for name, spec, asset, dump in self.having("clear_box"):
            low, high = spec["clear_box"]
            hits = [t for t in asset_triangles(dump) if triangle_overlaps_box(t, low, high)]
            self.assertEqual(len(hits), 0, f"{len(hits)} triangles enter the clear box")
            self.assertEqual(asset["clear_box"]["min"], list(low))
            self.assertEqual(asset["clear_box"]["max"], list(high))

    def test_no_track_rectangles_sit_under_a_surface(self):
        for name, spec, asset, dump in self.having("no_track"):
            triangles = asset_triangles(dump)
            low, high = bounds(triangles)
            rects = asset["no_track_rects"]
            self.assertTrue(rects)
            for rect in rects:
                self.assertTrue(inside_bbox(low, high, [*rect["center"], low[2]],
                                            [rect["size"][0] / 2, rect["size"][1] / 2, 0.0]), "rect leaves the asset")
                hx, hy = rect["size"][0] / 2, rect["size"][1] / 2
                covered = total = 0
                for i in range(6):
                    for j in range(6):
                        x = rect["center"][0] - hx + 2 * hx * (i + 0.5) / 6
                        y = rect["center"][1] - hy + 2 * hy * (j + 0.5) / 6
                        total += 1
                        covered += top_height(triangles, x, y) is not None
                self.assertGreaterEqual(covered / total, 0.95, "no-track rect not under the asset")


if __name__ == "__main__":
    unittest.main()
