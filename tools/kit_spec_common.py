"""Shared spec-test helpers for Blender-built assets (species now, kits and guardians later).

Standard library only, so tests run under plain `python`. Nothing here imports Blender.
Geometry dumps hold per-part vertices, triangle indices and skin weights, so every
size, volume, edge and weight rule is recomputed here instead of trusting a report.

AssetSpecMixin implements the generic rules G1 to G14 of the expansion bible (5.2).
A test case supplies SPECS and the artifact paths, then adds its own rig rules.
"""

import json
import math
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AVATAR_HEIGHT = 5.0
PIVOT_Z_TOLERANCE = 0.05
LOW_BAND_FRACTION = 0.1
SIZE_TOLERANCE = 0.10
MIN_BUDGET_FRACTION = 0.4


def load_json(path):
    if not path.exists():
        raise AssertionError(f"missing artifact: {path.relative_to(ROOT).as_posix()}")
    return json.loads(path.read_text(encoding="utf-8"))


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


def part_triangles(part):
    """Expand one dumped part (vertices plus index triples) into coordinate triangles."""
    vertices = part["vertices"]
    return [[vertices[i] for i in triple] for triple in part["triangles"]]


def asset_triangles(asset):
    return [triangle for part in asset["parts"].values() for triangle in part_triangles(part)]


def signed_volume(triangles):
    """Positive when faces point outward. Sums the tetrahedra to the origin."""
    total = 0.0
    for a, b, c in triangles:
        total += (a[0] * (b[1] * c[2] - b[2] * c[1])
                  - a[1] * (b[0] * c[2] - b[2] * c[0])
                  + a[2] * (b[0] * c[1] - b[1] * c[0])) / 6.0
    return total


def open_edge_count(part):
    """Edges not shared by exactly two triangles, recomputed from vertex indices."""
    counts = {}
    for triple in part["triangles"]:
        for k in range(3):
            edge = tuple(sorted((triple[k], triple[(k + 1) % 3])))
            counts[edge] = counts.get(edge, 0) + 1
    return sum(1 for n in counts.values() if n != 2)


class AssetSpecMixin:
    """Generic rules G1 to G14. Subclasses set the class attributes below.

    SPECS maps asset name to {"size": (x, y, z), "tris": int,
    "parts": {label: (hex, tris)}}. A label starting with "Neon_" is the glowing part.
    """

    SPECS = {}
    ASSET_KEY = "species"
    REPORT = GEOMETRY = ROUNDTRIP = BLEND = None
    RENDER_DIR = EXPORT_DIR = None
    HEIGHT_CAP = None
    NEON_PREFIX = "Neon_"

    @classmethod
    def setUpClass(cls):
        cls.report = load_json(cls.REPORT)
        cls.geometry = load_json(cls.GEOMETRY)
        cls.assets = cls.report[cls.ASSET_KEY]

    def each_asset(self):
        for name in self.SPECS:
            with self.subTest(asset=name):
                yield name, self.assets[name], self.geometry[name]

    def object_name(self, asset, label):
        return f"{asset}_{label}"

    def test_g1_all_assets_present_and_no_extras(self):
        self.assertEqual(sorted(self.assets), sorted(self.SPECS))
        self.assertEqual(sorted(self.geometry), sorted(self.SPECS))

    def test_g2_triangle_budgets(self):
        for name, asset, dump in self.each_asset():
            spec = self.SPECS[name]
            triangles = asset_triangles(dump)
            self.assertEqual(asset["triangles"], len(triangles), "report disagrees with dump")
            self.assertLessEqual(len(triangles), spec["tris"])
            self.assertGreaterEqual(len(triangles), spec["tris"] * MIN_BUDGET_FRACTION,
                                    "a near-empty model would pass a ceiling alone")
            for label, (_, part_budget) in spec["parts"].items():
                count = len(part_triangles(dump["parts"][self.object_name(name, label)]))
                self.assertLessEqual(count, part_budget, f"{label} over its part budget")

    def test_g3_sizes_match_dump_and_spec(self):
        for name, asset, dump in self.each_asset():
            low, high = bounds(asset_triangles(dump))
            size = [b - a for a, b in zip(low, high)]
            for reported, measured in zip(asset["size"], size):
                self.assertAlmostEqual(reported, measured, delta=0.01)
            for axis, (measured, wanted) in enumerate(zip(size, self.SPECS[name]["size"])):
                self.assertLessEqual(abs(measured - wanted) / wanted, SIZE_TOLERANCE,
                                     f"axis {axis}: measured {measured:.3f}, spec {wanted}")
            if self.HEIGHT_CAP is not None:
                self.assertLessEqual(size[2], self.HEIGHT_CAP)

    def test_g4_pivot_at_ground_and_base_centre(self):
        for name, asset, dump in self.each_asset():
            triangles = asset_triangles(dump)
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

    def test_g5_identity_transforms_and_flat_shading(self):
        for name, asset, _ in self.each_asset():
            self.assertTrue(asset["transforms_applied"], "objects must carry identity transforms")
            self.assertTrue(asset["flat_shaded"])

    def test_g6_meshes_are_closed_with_outward_faces(self):
        for name, asset, dump in self.each_asset():
            self.assertEqual(asset["non_manifold_edges"], 0)
            self.assertEqual(asset["non_manifold_edges"],
                             sum(p["non_manifold_edges"] for p in asset["parts"]))
            for object_name, part in dump["parts"].items():
                self.assertEqual(open_edge_count(part), 0, f"{object_name} has open edges")
                volume = signed_volume(part_triangles(part))
                self.assertGreater(volume, 0.0, f"{object_name} faces point inward")

    def test_g7_exact_part_object_names(self):
        for name, asset, dump in self.each_asset():
            expected = {self.object_name(name, label) for label in self.SPECS[name]["parts"]}
            self.assertEqual({p["object"] for p in asset["parts"]}, expected)
            self.assertEqual(set(dump["parts"]), expected)

    def test_g8_one_material_per_part_named_like_its_part(self):
        for name, asset, _ in self.each_asset():
            for part in asset["parts"]:
                self.assertEqual(part["material_count"], 1, part["object"])
                self.assertEqual(part["material"], part["object"])

    def test_g9_only_neon_parts_glow(self):
        for name, asset, _ in self.each_asset():
            for label in self.SPECS[name]["parts"]:
                part = next(p for p in asset["parts"] if p["object"] == self.object_name(name, label))
                if label.startswith(self.NEON_PREFIX):
                    self.assertGreater(part["emission_strength"], 0.0, label)
                else:
                    self.assertEqual(part["emission_strength"], 0.0, label)
            neon = [p for p in asset["parts"] if "_Neon_" in p["material"]]
            self.assertEqual(len(neon), sum(1 for label in self.SPECS[name]["parts"]
                                            if label.startswith(self.NEON_PREFIX)))

    def test_g10_every_material_is_matte(self):
        for name, asset, _ in self.each_asset():
            for part in asset["parts"]:
                self.assertGreaterEqual(part["roughness"], 0.8, part["material"])

    def test_g11_blend_and_fbx_exist(self):
        self.assertGreater(self.BLEND.stat().st_size, 0)
        for name, asset, _ in self.each_asset():
            for kind, relative in asset["fbx"].items():
                path = ROOT / relative
                self.assertGreater(path.stat().st_size, 0, f"{kind} {relative}")
                self.assertTrue(path.read_bytes().startswith(b"Kaydara FBX Binary"), relative)

    def test_g12_renders_exist_at_requested_sizes(self):
        for name in self.SPECS:
            with self.subTest(render=name):
                path = self.RENDER_DIR / f"{name}.png"
                self.assertGreater(path.stat().st_size, 0)
                self.assertEqual(png_size(path), (800, 800))
        sheet = self.RENDER_DIR / self.report["sheet_file"]
        self.assertGreater(png_size(sheet)[0], 800)
        lineup = self.RENDER_DIR / self.report["lineup_file"]
        self.assertGreater(png_size(lineup)[0], 800)
        self.assertAlmostEqual(self.report["scale_block_height"], AVATAR_HEIGHT, delta=0.01)

    def test_g13_fbx_round_trip_keeps_triangles_size_and_floor(self):
        roundtrip = load_json(self.ROUNDTRIP)
        for name, asset, _ in self.each_asset():
            imported = roundtrip[self.ASSET_KEY][name]["model"]
            self.assertEqual(imported["triangles"], asset["triangles"])
            for measured, expected in zip(imported["size"], asset["size"]):
                self.assertAlmostEqual(measured, expected, delta=0.02)
            self.assertLessEqual(abs(imported["min_z"]), PIVOT_Z_TOLERANCE)

    def test_g14_part_colours_match_the_table(self):
        for name, asset, _ in self.each_asset():
            for label, (colour, _) in self.SPECS[name]["parts"].items():
                part = next(p for p in asset["parts"] if p["object"] == self.object_name(name, label))
                self.assertEqual(part["color_hex"].upper(), colour.upper(), label)
