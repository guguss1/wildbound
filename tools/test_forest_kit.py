"""Spec tests for the forest kit, read from the artifacts tools/build-forest-kit.py writes.

Run with: python tools/test_forest_kit.py

Standard library only. The report holds values measured inside Blender. The geometry
dump holds every evaluated triangle, so sizes and clearances are recomputed here in
plain Python instead of trusting the report's own arithmetic.
"""

import json
import struct
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
KIT_DIR = ROOT / "assets/blender/forest-kit"
EXPORT_DIR = ROOT / "assets/exports/forest-kit"
REPORT = KIT_DIR / "forest-kit-report.json"
GEOMETRY = KIT_DIR / "forest-kit-geometry.json"
ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
BLEND = KIT_DIR / "forest-kit-v1.blend"

BUDGETS = {
    "FK_Evergreen": 500,
    "FK_DeadTree": 400,
    "FK_FallenLog": 350,
    "FK_RootArch": 700,
    "FK_RuinDoorway": 600,
    "FK_LanternMarker": 350,
}
HEIGHTS = {"FK_Evergreen": 30.0, "FK_DeadTree": 22.0, "FK_LanternMarker": 9.0}
LOG_LENGTH = 16.0
PASSAGES = {
    "FK_RootArch": {"clear_width": 16.0, "clear_height": 11.0, "max_width": 32.0, "max_depth": 16.0},
    "FK_RuinDoorway": {"clear_width": 18.0, "clear_height": 11.0, "max_width": 36.0, "max_depth": 16.0},
}
PATH_WIDTH = 14.0
AVATAR_HEIGHT = 5.0
PIVOT_Z_TOLERANCE = 0.05
LOW_BAND_FRACTION = 0.1


def load_json(path):
    if not path.exists():
        raise AssertionError(f"missing artifact: {path.relative_to(ROOT).as_posix()}")
    return json.loads(path.read_text(encoding="utf-8"))


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
    """Free X gap around the pivot, for all geometry between ground and height.

    Every triangle is projected along Y, the walking direction, so a root at any depth
    counts as blocking the corridor. Returns (gap_low, gap_high).
    """
    spans = []
    for triangle in triangles:
        kept = clip_axis([(v[0], v[2]) for v in triangle], 1, 0.0, height)
        if kept:
            xs = [p[0] for p in kept]
            spans.append((min(xs), max(xs)))
    low, high = float("-inf"), float("inf")
    for span_low, span_high in spans:
        if span_low <= 0.0 <= span_high:
            return 0.0, 0.0
        if span_high < 0.0:
            low = max(low, span_high)
        else:
            high = min(high, span_low)
    return low, high


def clear_height(triangles, half_width):
    """Lowest geometry over the band |x| <= half_width, projected along Y."""
    lowest = float("inf")
    for triangle in triangles:
        kept = clip_axis([(v[0], v[2]) for v in triangle], 0, -half_width, half_width)
        if kept:
            lowest = min(lowest, min(p[1] for p in kept))
    return lowest


def bounds(triangles):
    points = [vertex for triangle in triangles for vertex in triangle]
    return ([min(p[i] for p in points) for i in range(3)],
            [max(p[i] for p in points) for i in range(3)])


def png_size(path):
    with path.open("rb") as handle:
        header = handle.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"not a PNG: {path}")
    return struct.unpack(">II", header[16:24])


class ForestKitReport(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = load_json(REPORT)
        cls.geometry = load_json(GEOMETRY)
        cls.props = cls.report["props"]

    def each_prop(self):
        for name in BUDGETS:
            with self.subTest(prop=name):
                yield name, self.props[name], self.geometry[name]["triangles"]

    def test_all_six_props_present(self):
        self.assertEqual(sorted(self.props), sorted(BUDGETS))
        self.assertEqual(sorted(self.geometry), sorted(BUDGETS))

    def test_triangle_budgets(self):
        for name, prop, triangles in self.each_prop():
            self.assertEqual(prop["triangles"], len(triangles), "report disagrees with dump")
            self.assertLessEqual(len(triangles), BUDGETS[name])

    def test_target_sizes_within_ten_percent(self):
        for name, prop, triangles in self.each_prop():
            low, high = bounds(triangles)
            size = [b - a for a, b in zip(low, high)]
            for reported, measured in zip(prop["size"], size):
                self.assertAlmostEqual(reported, measured, delta=0.01)
            if name in HEIGHTS:
                self.assertLessEqual(abs(size[2] - HEIGHTS[name]) / HEIGHTS[name], 0.10)
            if name == "FK_FallenLog":
                self.assertLessEqual(abs(max(size[:2]) - LOG_LENGTH) / LOG_LENGTH, 0.10)

    def test_pivot_at_ground_and_base_centre(self):
        for name, prop, triangles in self.each_prop():
            low, high = bounds(triangles)
            self.assertLessEqual(abs(low[2]), PIVOT_Z_TOLERANCE, "min Z must sit on the ground")
            band = low[2] + (high[2] - low[2]) * LOW_BAND_FRACTION
            base = [v for t in triangles for v in t if v[2] <= band]
            footprint = max(high[0] - low[0], high[1] - low[1])
            tolerance = max(0.5, footprint * 0.10)
            for axis in (0, 1):
                values = [v[axis] for v in base]
                centre = (min(values) + max(values)) / 2
                self.assertLessEqual(abs(centre), tolerance, f"axis {axis} base centre off origin")

    def test_transforms_applied_and_flat_shaded(self):
        for name, prop, _ in self.each_prop():
            self.assertTrue(prop["transforms_applied"], "objects must carry identity transforms")
            self.assertTrue(prop["flat_shaded"])

    def test_non_manifold_count_reported(self):
        for name, prop, _ in self.each_prop():
            self.assertIsInstance(prop["non_manifold_edges"], int)
            self.assertGreaterEqual(prop["non_manifold_edges"], 0)
            total = sum(part["non_manifold_edges"] for part in prop["parts"])
            self.assertEqual(prop["non_manifold_edges"], total)

    def test_passage_clearances_measured_from_geometry(self):
        for name, limits in PASSAGES.items():
            with self.subTest(prop=name):
                triangles = self.geometry[name]["triangles"]
                half = limits["clear_width"] / 2
                gap_low, gap_high = clear_width(triangles, limits["clear_height"])
                height = clear_height(triangles, half)
                self.assertGreaterEqual(gap_high - gap_low, limits["clear_width"])
                self.assertLessEqual(gap_low, -half, "gap must be centred on the pivot")
                self.assertGreaterEqual(gap_high, half, "gap must be centred on the pivot")
                self.assertGreaterEqual(height, limits["clear_height"])
                self.assertLessEqual(gap_low, -PATH_WIDTH / 2)
                self.assertGreaterEqual(gap_high, PATH_WIDTH / 2)
                self.assertGreater(height, AVATAR_HEIGHT)
                reported = self.props[name]["clearance"]
                self.assertAlmostEqual(reported["width"], gap_high - gap_low, delta=0.01)
                self.assertAlmostEqual(reported["height"], height, delta=0.01)

    def test_passage_footprints_fit_their_limits(self):
        for name, limits in PASSAGES.items():
            with self.subTest(prop=name):
                low, high = bounds(self.geometry[name]["triangles"])
                self.assertLessEqual(high[0] - low[0], limits["max_width"])
                self.assertLessEqual(high[1] - low[1], limits["max_depth"])

    def test_canopy_and_trunk_are_separate_pieces(self):
        objects = {part["object"] for part in self.props["FK_Evergreen"]["parts"]}
        self.assertEqual(objects, {"FK_Evergreen_Trunk", "FK_Evergreen_Canopy"})

    def test_lantern_glass_is_named_and_emissive_in_its_own_part(self):
        glass = [part for part in self.props["FK_LanternMarker"]["parts"]
                 if "neon" in part["material"].lower()]
        self.assertEqual(len(glass), 1, "glass needs one own part so it can be Neon in Roblox")
        self.assertGreater(glass[0]["emission_strength"], 0.0)

    def test_every_material_is_matte(self):
        for name, prop, _ in self.each_prop():
            for part in prop["parts"]:
                self.assertGreaterEqual(part["roughness"], 0.8, part["material"])

    def test_blend_and_exports_exist_and_are_non_empty(self):
        self.assertGreater(BLEND.stat().st_size, 0)
        for name in BUDGETS:
            with self.subTest(prop=name):
                path = EXPORT_DIR / f"{name}.fbx"
                self.assertGreater(path.stat().st_size, 0)
                self.assertTrue(path.read_bytes().startswith(b"Kaydara FBX Binary"))

    def test_renders_exist_at_requested_sizes(self):
        expected = {f"{name}.png": (800, 800) for name in BUDGETS}
        expected["forest-kit-sheet.png"] = (1500, 1000)
        for filename, size in expected.items():
            with self.subTest(render=filename):
                path = KIT_DIR / filename
                self.assertGreater(path.stat().st_size, 0)
                self.assertEqual(png_size(path), size)
        lineup = KIT_DIR / "forest-kit-scale.png"
        self.assertGreater(lineup.stat().st_size, 0)
        self.assertGreater(png_size(lineup)[0], 800)

    def test_scale_reference_block_is_five_studs(self):
        self.assertAlmostEqual(self.report["scale_block_height"], AVATAR_HEIGHT, delta=0.01)

    def test_fbx_round_trip_keeps_scale_and_triangles(self):
        roundtrip = load_json(ROUNDTRIP)
        for name, prop, _ in self.each_prop():
            imported = roundtrip["props"][name]
            self.assertEqual(imported["triangles"], prop["triangles"])
            for measured, expected in zip(imported["size"], prop["size"]):
                self.assertAlmostEqual(measured, expected, delta=0.02)
            self.assertLessEqual(abs(imported["min_z"]), PIVOT_Z_TOLERANCE)


if __name__ == "__main__":
    unittest.main()
