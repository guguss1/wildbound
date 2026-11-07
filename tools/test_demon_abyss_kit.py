"""Spec tests for the Demon Abyss kit (expansion bible 5.1, 5.2 and 5.8). The name stays internal (decision X8).

Run with: python -I -B -m unittest discover -s tools -p "test_demon_abyss_kit.py"

Standard library only. Artifacts come from tools/build-demon-abyss-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-demon-abyss-kit.py
  DEMON_ABYSS_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-demon-abyss-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances, walk surfaces,
gather points and occluders are recomputed from the geometry dump. Every value is unvalidated: nothing was
imported into Roblox, so scale there and phone cost stay unmeasured.

Content rules from the bible apply to every asset: no gore, skulls, bones or religious symbols, minerals only.
Glowing parts are labelled Neon_Rift and Neon_Rune (the bible calls them Rift, Crack and Rune): the shared G8 and
G9 tests recognise glow by a Neon_ label. Six props, so the sheet is three columns by two rows, 1500 x 1000.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin, top_height
from kit_spec_common import ROOT, asset_triangles, bounds, load_json, part_triangles

KIT_DIR = ROOT / "assets/blender/demon-abyss-kit"
EXPORT_DIR = ROOT / "assets/exports/demon-abyss-kit"

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "DA_FissureLip": {
        "size": (20.0, 10.0, 6.0), "tris": 240,
        "parts": {"Rock": ("4A4650", 190), "Neon_Rift": ("C23A4F", 50)},
        "walk": 6.0,
    },
    "DA_FloatRock": {
        "size": (12.0, 12.0, 6.0), "tris": 180,
        "parts": {"Rock": ("4A4650", 150), "Crust": ("7A1F2C", 30)},
        "walk": 6.0,
    },
    "DA_ThornSpire": {
        "size": (8.0, 8.0, 18.0), "tris": 200,
        "parts": {"Spire": ("15111B", 200)},
    },
    "DA_RiftGate": {
        "size": (28.0, 8.0, 18.0), "tris": 560,
        "parts": {"Stone": ("4A4650", 440), "Neon_Rift": ("C23A4F", 120)},
        "clear": (14.0, 11.0), "limit": (30.0, 16.0), "occluder": 11.0,
    },
    "DA_RiftShard": {
        "size": (5.0, 5.0, 5.0), "tris": 100,
        "parts": {"Neon_Rift": ("C23A4F", 70), "Base": ("15111B", 30)},
        "gather": (0.0, -2.5, 1.5),
    },
    "DA_CalmStone": {
        "size": (6.0, 6.0, 6.0), "tris": 140,
        "parts": {"Stone": ("BFB6A6", 100), "Neon_Rune": ("6FB7C9", 40)},
    },
}


class DemonAbyssKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    SHEET_SIZE = (1500, 1000)
    REPORT = KIT_DIR / "demon-abyss-kit-report.json"
    GEOMETRY = KIT_DIR / "demon-abyss-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "demon-abyss-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


def shells(part):
    """Vertex lists of each vertex-connected shell of one dumped part."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    groups = {}
    for i in {i for t in part["triangles"] for i in t}:
        groups.setdefault(find(i), []).append(part["vertices"][i])
    return list(groups.values())


def inside_box(box, x, y, z):
    cx, cy, cz = box["center"]
    sx, sy, sz = (s / 2 for s in box["size"])
    return abs(x - cx) <= sx and abs(y - cy) <= sy and abs(z - cz) <= sz


def section_width(triangles, z, axis=0):
    """Extent along an axis of the section through the triangles at height z."""
    cuts = []
    for tri in triangles:
        for p, q in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
            if (p[2] - z) * (q[2] - z) < 0:
                cuts.append(p[axis] + (z - p[2]) / (q[2] - p[2]) * (q[axis] - p[axis]))
    return (max(cuts) - min(cuts)) if cuts else 0.0


class DemonAbyssReads(unittest.TestCase):
    """Visual reads. Each fails on the bare primitive it replaces: a slab, a cone, a pole, a goalpost, a cube."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(DemonAbyssKit.GEOMETRY)
        cls.report = load_json(DemonAbyssKit.REPORT)["props"]

    def part(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]

    # -- DA_FissureLip ---------------------------------------------------
    def test_lip_breaks_away_on_plus_y_with_chunks_and_a_glowing_seam(self):
        rock = self.part("DA_FissureLip", "Rock")
        back = [max((v[1] for v in rock["vertices"] if abs(v[0] - x) < 1.3 and v[2] > 5.9), default=None)
                for x in range(-8, 9, 2)]
        back = [y for y in back if y is not None]
        self.assertGreaterEqual(max(back) - min(back), 1.4, f"the +Y edge is a straight cut: {back}")
        chunks = [s for s in shells(rock) if max(v[2] for v in s) < 5.0 and min(v[1] for v in s) > 1.0]
        self.assertGreaterEqual(len(chunks), 3, "chunks that have broken away lie lower on +Y")
        seam = self.part("DA_FissureLip", "Neon_Rift")["vertices"]
        self.assertGreaterEqual(sum(v[1] for v in seam) / len(seam), 1.0, "the seam runs along the +Y lip")
        self.assertGreaterEqual(max(v[2] for v in seam), max(v[2] for v in rock["vertices"]) + 0.03)

    def test_lip_front_is_not_a_straight_wall(self):
        rock = self.part("DA_FissureLip", "Rock")["vertices"]
        front = [min(v[1] for v in rock if abs(v[0] - x) < 1.6 and v[2] > 5.9) for x in (-6, -2, 2, 6)]
        self.assertGreaterEqual(max(front) - min(front), 0.2)

    # -- DA_FloatRock ----------------------------------------------------
    def test_float_rock_hangs_from_one_point_and_widens_to_a_flat_top(self):
        rock = self.part("DA_FloatRock", "Rock")
        low = [v for v in rock["vertices"] if v[2] < 0.5]
        self.assertEqual(len(low), 1, "one tip on the ground and nothing else near it")
        triangles = part_triangles(rock)
        self.assertLessEqual(section_width(triangles, 1.0), 2.8)
        self.assertGreaterEqual(section_width(triangles, 5.5), 8.5)
        top = [v[2] for v in rock["vertices"] if v[2] > 5.8]
        self.assertGreaterEqual(len(top), 8)
        self.assertLessEqual(max(top) - min(top), 0.03, "the top is one flat level")

    def test_float_rock_underside_is_uneven_with_hanging_shards(self):
        rock = self.part("DA_FloatRock", "Rock")
        self.assertGreaterEqual(len(shells(rock)), 4, "the body and three shards under it")
        triangles = part_triangles(rock)
        widths = [section_width(triangles, 3.6, axis) for axis in (0, 1)]
        self.assertGreaterEqual(abs(widths[0] - widths[1]), 0.3, "not turned on a lathe")
        crust = self.part("DA_FloatRock", "Crust")["vertices"]
        self.assertGreaterEqual(min(v[2] for v in crust), 5.8)

    # -- DA_ThornSpire ---------------------------------------------------
    def test_spire_curves_narrows_and_carries_three_side_spikes(self):
        spire = self.part("DA_ThornSpire", "Spire")
        found = shells(spire)
        self.assertGreaterEqual(len(found), 4, "the thorn and three side spikes")
        main = max(found, key=len)
        tip = max(main, key=lambda v: v[2])
        base = [v for v in main if v[2] < 0.5]
        cx, cy = sum(v[0] for v in base) / len(base), sum(v[1] for v in base) / len(base)
        self.assertGreaterEqual(math.hypot(tip[0] - cx, tip[1] - cy), 2.5, "a curved thorn, not a pole")
        triangles = part_triangles({"vertices": spire["vertices"], "triangles": spire["triangles"]})
        self.assertGreaterEqual(section_width(triangles, 2.0) / max(section_width(triangles, 14.0), 0.1), 1.6)
        reach = sorted((max(math.hypot(v[0] - cx, v[1] - cy) for v in s) for s in found if s is not main), reverse=True)
        self.assertGreaterEqual(reach[2], 1.2, "three spikes stand out from the trunk")

    # -- DA_RiftGate -----------------------------------------------------
    def test_gate_leans_unevenly_and_its_lintel_is_jagged_and_spiked(self):
        stone = self.part("DA_RiftGate", "Stone")
        triangles = part_triangles(stone)
        shifts = []
        for side in (-1, 1):
            def inner_edge(z):
                cuts = []
                for tri in triangles:
                    for p, q in ((tri[0], tri[1]), (tri[1], tri[2]), (tri[2], tri[0])):
                        if (p[2] - z) * (q[2] - z) < 0:
                            x = p[0] + (z - p[2]) / (q[2] - p[2]) * (q[0] - p[0])
                            if x * side > 6.0:
                                cuts.append(abs(x))
                return min(cuts)

            shifts.append(inner_edge(9.5) - inner_edge(1.5))
        self.assertGreaterEqual(abs(shifts[0] - shifts[1]), 0.5, f"piers lean the same way: {shifts}")
        under = [v[2] for v in stone["vertices"] if abs(v[0]) < 6.5 and 11.0 <= v[2] <= 13.0]
        self.assertTrue(under)
        self.assertGreaterEqual(max(under) - min(under), 0.45, "a broken lintel underside is not flat")
        self.assertGreaterEqual(len(shells(stone)), 10)

    def test_gate_glow_stays_outside_the_corridor_and_marks_the_inner_edges(self):
        glow = self.part("DA_RiftGate", "Neon_Rift")["vertices"]
        low = [v for v in glow if v[2] < 10.8]
        self.assertTrue(low)
        self.assertGreaterEqual(min(abs(v[0]) for v in low), 7.0, "glow inside the 14 wide corridor")
        self.assertTrue(any(v[0] < 0 for v in low) and any(v[0] > 0 for v in low), "an edge on each pier")
        self.assertGreaterEqual(len(shells(self.part("DA_RiftGate", "Neon_Rift"))), 3)

    def test_gate_occluders_cover_each_pier_and_leave_the_gateway_open(self):
        boxes = self.report["DA_RiftGate"]["occluders"]
        for side in (-1, 1):
            for y in (-2.5, 0.0, 2.5):
                for z in (1.0, 5.0, 10.0):
                    self.assertTrue(any(inside_box(b, side * 9.5, y, z) for b in boxes), f"pier {side * 9.5}, {z}")
        for x in (-6.5, -3.0, 0.0, 3.0, 6.5):
            for z in (1.0, 5.0, 10.5):
                self.assertFalse(any(inside_box(b, x, 0.0, z) for b in boxes), f"blocks ({x}, 0, {z})")

    # -- DA_RiftShard ----------------------------------------------------
    def test_shard_is_a_jagged_leaning_crystal_with_a_second_one_beside_it(self):
        crystal = self.part("DA_RiftShard", "Neon_Rift")
        found = shells(crystal)
        self.assertEqual(len(found), 2)
        main = max(found, key=lambda s: max(v[2] for v in s))
        tip = max(main, key=lambda v: v[2])
        base = [v for v in main if v[2] < tip[2] - 0.8]
        lean = math.hypot(tip[0] - sum(v[0] for v in base) / len(base), tip[1] - sum(v[1] for v in base) / len(base))
        self.assertGreaterEqual(lean, 0.5)
        levels = sorted({round(v[2], 2) for v in main})
        widths = [max(math.hypot(v[0], v[1]) for v in main if round(v[2], 2) == z) for z in levels[:-1]]
        self.assertGreater(max(widths), widths[0] + 0.15, "the belly is wider than the foot")
        self.assertGreaterEqual(len(shells(self.part("DA_RiftShard", "Base"))), 2)

    # -- DA_CalmStone ----------------------------------------------------
    def test_calm_stone_is_smooth_leans_narrows_and_wears_a_band_on_one_side(self):
        stone = self.part("DA_CalmStone", "Stone")
        body = max(shells(stone), key=len)
        triangles = part_triangles({"vertices": stone["vertices"], "triangles": stone["triangles"]})
        self.assertGreaterEqual(section_width(triangles, 2.8) / section_width(triangles, 5.5), 1.3, "narrows to the top")
        rings = {}
        for v in body:
            rings.setdefault(round(v[2], 1), []).append(v)
        spread = 0.0
        for z, ring in rings.items():
            if len(ring) >= 6:  # radii about the ring's own centre, since the stone leans and fitting shifts it
                cx, cy = sum(v[0] for v in ring) / len(ring), sum(v[1] for v in ring) / len(ring)
                radii = [math.hypot(v[0] - cx, v[1] - cy) for v in ring]
                if min(radii) > 0.8:
                    spread = max(spread, max(radii) / min(radii))
        self.assertLessEqual(spread, 1.3, "smooth: no ring is lumpy")
        low = [v for v in body if v[2] < 0.3]
        high = [v for v in body if v[2] > 5.5]
        self.assertGreaterEqual(math.hypot(sum(v[0] for v in high) / len(high) - sum(v[0] for v in low) / len(low),
                                           sum(v[1] for v in high) / len(high) - sum(v[1] for v in low) / len(low)),
                                0.2, "a standing stone that does not lean is a post")
        rune = self.part("DA_CalmStone", "Neon_Rune")["vertices"]
        self.assertTrue(1.6 <= sum(v[2] for v in rune) / len(rune) <= 4.4, "a band at mid height")
        xs = [v[0] for v in rune]
        self.assertGreaterEqual(max(xs) - min(xs), 2.5)
        self.assertLessEqual(max(v[1] for v in rune), 0.5, "on the -Y side, facing the player")


if __name__ == "__main__":
    unittest.main()
