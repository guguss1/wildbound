"""Spec tests for the Rock and Caves kit (expansion bible 5.1, 5.2 and 5.5).

Run with: python -I -B -m unittest discover -s tools -p "test_rock_caves_kit.py"

Standard library only. Artifacts come from tools/build-rock-caves-kit.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-rock-caves-kit.py
  ROCK_CAVES_KIT_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-rock-caves-kit.py

The table below is the contract, copied from the bible, not from the builder. Sizes, clearances, snap
rings, radial clearance, floor and occluder boxes are recomputed from the geometry dump. Every value is
unvalidated: nothing was imported into Roblox, so scale there and phone cost stay unmeasured.

Known conflict, recorded instead of worked around: the shared W1 test (biome_kit_spec) asks for a walk
SURFACE under the walk box, and the bible forbids a floor mesh in the tunnels ("a floor would fail
clear_width"). The tunnels therefore carry `floor` instead of `walk`, and TunnelFloorAndSight below
checks the floor boxes directly. Measured: top_height at (0, 0) of a tunnel is None, so W1 cannot hold.
"""

import math
import unittest

from biome_kit_spec import BiomeKitMixin, top_height
from kit_spec_common import ROOT, asset_triangles, bounds, load_json, part_triangles

KIT_DIR = ROOT / "assets/blender/rock-caves-kit"
EXPORT_DIR = ROOT / "assets/exports/rock-caves-kit"

# Shared tunnel profile, copied from bible 5.5. Inner and outer outline in (x, z).
PROFILE_LOOP = [(-7.0, 0.0), (-7.0, 10.0), (-5.0, 12.0), (5.0, 12.0), (7.0, 10.0), (7.0, 0.0),
                (12.0, 0.0), (12.0, 12.0), (7.0, 18.0), (-7.0, 18.0), (-12.0, 12.0), (-12.0, 0.0)]
SNAP_TOLERANCE = 0.02
ARC_CENTRE = (15.0, -15.0)

# size is (x, y, z) in studs, tris the budget, parts map label to (hex, part budget).
SPECS = {
    "RC_TunnelStraight": {
        "size": (24.0, 24.0, 18.0), "tris": 420,
        "parts": {"Rock": ("3F3D3B", 360), "Stain": ("7D5A42", 60)},
        "clear": (14.0, 10.0), "occluder": 12.0, "floor": True,
    },
    "RC_TunnelBend": {
        "size": (30.0, 30.0, 18.0), "tris": 480,
        "parts": {"Rock": ("3F3D3B", 410), "Stain": ("7D5A42", 70)},
        "occluder": 12.0, "floor": True,
    },
}


class RockCavesKit(BiomeKitMixin, unittest.TestCase):
    SPECS = SPECS
    REPORT = KIT_DIR / "rock-caves-kit-report.json"
    GEOMETRY = KIT_DIR / "rock-caves-kit-geometry.json"
    ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
    BLEND = KIT_DIR / "rock-caves-kit-v1.blend"
    RENDER_DIR = KIT_DIR
    EXPORT_DIR = EXPORT_DIR


def components(part):
    """Number of vertex-connected shells in one dumped part."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    return len({find(i) for t in part["triangles"] for i in t})


def segment_distance(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    span = dx * dx + dz * dz
    t = 0.0 if span == 0 else max(0.0, min(1.0, ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / span))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dz))


def ring_report(local):
    """S1: every profile corner has a vertex within reach, and every ring vertex lies on the outline."""
    edges = [(PROFILE_LOOP[k], PROFILE_LOOP[(k + 1) % 12]) for k in range(12)]
    corner = max(min(math.dist(c, p) for p in local) for c in PROFILE_LOOP)
    stray = max(min(segment_distance(p, a, b) for a, b in edges) for p in local)
    return corner, stray


def inside_rotated_box(box, x, y, z):
    """Is (x, y, z) inside a collision or occluder box that may be turned about Z?"""
    cx, cy, cz = box["center"]
    yaw = math.radians(box.get("yaw_deg", 0.0))
    dx, dy = x - cx, y - cy
    lx = dx * math.cos(yaw) + dy * math.sin(yaw)
    ly = -dx * math.sin(yaw) + dy * math.cos(yaw)
    sx, sy, sz = (s / 2 for s in box["size"])
    return abs(lx) <= sx and abs(ly) <= sy and abs(z - cz) <= sz


def box_corners_xy(box):
    cx, cy, _ = box["center"]
    yaw = math.radians(box.get("yaw_deg", 0.0))
    sx, sy = box["size"][0] / 2, box["size"][1] / 2
    return [(cx + a * math.cos(yaw) - b * math.sin(yaw), cy + a * math.sin(yaw) + b * math.cos(yaw))
            for a in (-sx, sx) for b in (-sy, sy)]


class TunnelSnap(unittest.TestCase):
    """S1 and the recorded end centres for both tunnel modules, recomputed from the dump."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(RockCavesKit.GEOMETRY)
        cls.report = load_json(RockCavesKit.REPORT)["props"]

    def vertices(self, asset):
        return [v for t in asset_triangles(self.geometry[asset]) for v in t]

    def test_straight_end_rings_match_the_shared_profile(self):
        points = self.vertices("RC_TunnelStraight")
        for plane in (-12.0, 12.0):
            ring = [(v[0], v[2]) for v in points if abs(v[1] - plane) < 1e-3]
            self.assertGreaterEqual(len(ring), 12, f"end ring at y={plane} is incomplete")
            corner, stray = ring_report(ring)
            self.assertLessEqual(corner, SNAP_TOLERANCE, f"a corner at y={plane} is {corner:.4f} off the profile")
            self.assertLessEqual(stray, SNAP_TOLERANCE, f"a vertex at y={plane} is {stray:.4f} off the outline")

    def test_bend_end_rings_match_the_shared_profile(self):
        points = self.vertices("RC_TunnelBend")
        ends = {"A": [(v[0] + 3.0, v[2]) for v in points if abs(v[1] + 15.0) < 1e-3],
                "B": [(v[1] - 3.0, v[2]) for v in points if abs(v[0] - 15.0) < 1e-3]}
        for label, ring in ends.items():
            self.assertGreaterEqual(len(ring), 12, f"end {label} ring is incomplete")
            corner, stray = ring_report(ring)
            self.assertLessEqual(corner, SNAP_TOLERANCE, f"end {label} corner {corner:.4f} off the profile")
            self.assertLessEqual(stray, SNAP_TOLERANCE, f"end {label} vertex {stray:.4f} off the outline")

    def test_end_centres_are_recorded_and_true(self):
        wanted = {"RC_TunnelStraight": {"A": ([0.0, -12.0], [0.0, -1.0]), "B": ([0.0, 12.0], [0.0, 1.0])},
                  "RC_TunnelBend": {"A": ([-3.0, -15.0], [0.0, -1.0]), "B": ([15.0, 3.0], [1.0, 0.0])}}
        for name, ends in wanted.items():
            for label, (centre, facing) in ends.items():
                recorded = self.report[name]["ends"][label]
                self.assertEqual(recorded["center"], centre, f"{name} end {label}")
                self.assertEqual(recorded["facing"], facing, f"{name} end {label}")
        points = self.vertices("RC_TunnelBend")
        ring_a = [v[0] for v in points if abs(v[1] + 15.0) < 1e-3]
        ring_b = [v[1] for v in points if abs(v[0] - 15.0) < 1e-3]
        self.assertAlmostEqual((min(ring_a) + max(ring_a)) / 2, -3.0, delta=SNAP_TOLERANCE)
        self.assertAlmostEqual((min(ring_b) + max(ring_b)) / 2, 3.0, delta=SNAP_TOLERANCE)

    def test_report_names_the_shared_profile(self):
        for name in SPECS:
            loop = self.report[name]["snap"]["profile_loop"]
            self.assertEqual([tuple(p) for p in loop], PROFILE_LOOP)
            self.assertEqual(self.report[name]["snap"]["tolerance"], SNAP_TOLERANCE)

    def test_bend_has_six_segments(self):
        """Seven rings at 15 degree steps from End A at 180 degrees to End B at 90 degrees."""
        rock = self.geometry["RC_TunnelBend"]["parts"]["RC_TunnelBend_Rock"]["vertices"]
        angles = {}
        for x, y, z in rock:
            r = math.hypot(x - ARC_CENTRE[0], y - ARC_CENTRE[1])
            if 5.5 <= r <= 31.0:
                key = round(math.degrees(math.atan2(y - ARC_CENTRE[1], x - ARC_CENTRE[0])) / 15.0) * 15
                if abs(math.degrees(math.atan2(y - ARC_CENTRE[1], x - ARC_CENTRE[0])) - key) < 0.01:
                    angles[key] = angles.get(key, 0) + 1
        self.assertEqual(sorted(angles), [90, 105, 120, 135, 150, 165, 180])
        self.assertTrue(all(count >= 16 for count in angles.values()), angles)


class TunnelFloorAndSight(unittest.TestCase):
    """Floor boxes, occluder boxes and the bend's radial clearance (bible 5.5, W1 and O1 variants)."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(RockCavesKit.GEOMETRY)
        cls.report = load_json(RockCavesKit.REPORT)["props"]

    def test_floor_boxes_sit_at_ground_inside_the_bbox_and_span_the_corridor(self):
        for name in SPECS:
            with self.subTest(asset=name):
                low, high = bounds(asset_triangles(self.geometry[name]))
                boxes = self.report[name]["collision_boxes"]
                self.assertTrue(boxes)
                for box in boxes:
                    self.assertTrue(box["name"].startswith("walk_floor"), box["name"])
                    self.assertAlmostEqual(box["center"][2] + box["size"][2] / 2, 0.0, delta=0.01)
                    self.assertGreaterEqual(box["size"][0], 13.9, "the floor must span the 14 wide corridor")
                    for x, y in box_corners_xy(box):
                        self.assertGreaterEqual(x, low[0] - 0.5)
                        self.assertLessEqual(x, high[0] + 0.5)
                        self.assertGreaterEqual(y, low[1] - 0.5)
                        self.assertLessEqual(y, high[1] + 0.5)
                self.assertTrue(all(abs(b.get("pitch_deg", 0.0)) == 0.0 for b in boxes))

    def test_straight_floor_covers_the_whole_corridor_floor(self):
        boxes = self.report["RC_TunnelStraight"]["collision_boxes"]
        for x in (-6.9, 0.0, 6.9):
            for y in (-11.9, -6.0, 0.0, 6.0, 11.9):
                self.assertTrue(any(inside_rotated_box(b, x, y, -0.05) for b in boxes), f"hole at ({x}, {y})")

    def test_bend_floor_follows_the_arc(self):
        boxes = self.report["RC_TunnelBend"]["collision_boxes"]
        for step in range(0, 25):
            angle = math.radians(180.0 - 90.0 * step / 24)
            for radius in (11.5, 18.0, 24.5):
                x, y = ARC_CENTRE[0] + radius * math.cos(angle), ARC_CENTRE[1] + radius * math.sin(angle)
                self.assertTrue(any(inside_rotated_box(b, x, y, -0.05) for b in boxes),
                                f"floor hole at radius {radius}, {math.degrees(angle):.1f} degrees")

    def test_occluders_cover_both_walls_and_never_the_corridor_straight(self):
        boxes = self.report["RC_TunnelStraight"]["occluders"]
        for side in (-1, 1):
            for y in (-11.5, -6.0, 0.0, 6.0, 11.5):
                for z in (0.5, 2.5, 5.0, 8.0, 11.5):
                    self.assertTrue(any(inside_rotated_box(b, side * 9.5, y, z) for b in boxes),
                                    f"wall at x={side * 9.5}, y={y}, z={z} is not an occluder")
        for x in (-6.9, -3.0, 0.0, 3.0, 6.9):
            for y in (-11.9, 0.0, 11.9):
                for z in (0.5, 2.5, 5.0):
                    self.assertFalse(any(inside_rotated_box(b, x, y, z) for b in boxes),
                                     f"an occluder blocks the corridor at ({x}, {y}, {z})")

    def test_occluders_cover_both_walls_and_never_the_corridor_bend(self):
        boxes = self.report["RC_TunnelBend"]["occluders"]
        for step in range(1, 24):
            angle = math.radians(180.0 - 90.0 * step / 24)
            for radius, wanted in ((9.5, True), (26.3, True), (11.6, False), (14.0, False), (18.0, False),
                                   (22.0, False), (24.4, False)):
                for z in (0.5, 2.5, 5.0, 11.5 if wanted else 2.5):
                    x, y = ARC_CENTRE[0] + radius * math.cos(angle), ARC_CENTRE[1] + radius * math.sin(angle)
                    found = any(inside_rotated_box(b, x, y, z) for b in boxes)
                    self.assertEqual(found, wanted, f"radius {radius} at {math.degrees(angle):.1f} deg, z={z}")

    def test_rotated_boxes_stay_inside_the_bbox_within_half_a_stud(self):
        """The shared O1 test reads unrotated half extents; this checks the real turned corners."""
        for name in SPECS:
            low, high = bounds(asset_triangles(self.geometry[name]))
            for key in ("collision_boxes", "occluders"):
                for box in self.report[name][key]:
                    for x, y in box_corners_xy(box):
                        self.assertGreaterEqual(x, low[0] - 0.5, f"{name} {box['name']}")
                        self.assertLessEqual(x, high[0] + 0.5, f"{name} {box['name']}")
                        self.assertGreaterEqual(y, low[1] - 0.5, f"{name} {box['name']}")
                        self.assertLessEqual(y, high[1] + 0.5, f"{name} {box['name']}")

    def test_bend_keeps_the_radial_corridor_free_below_z_10(self):
        """No vertex between radius 11 and 25 of the arc centre below Z 10, within 0.3 (bible 5.5)."""
        inside = []
        for part in self.geometry["RC_TunnelBend"]["parts"].values():
            for x, y, z in part["vertices"]:
                r = math.hypot(x - ARC_CENTRE[0], y - ARC_CENTRE[1])
                if z < 10.0 - 1e-9 and 11.3 < r < 24.7:
                    inside.append((round(r, 3), round(z, 3)))
        self.assertEqual(inside, [], f"{len(inside)} vertices stand in the corridor, first {inside[:3]}")

    def test_bend_chords_do_not_cut_into_the_corridor(self):
        """The polygonal arc must not pinch the corridor between rings: edges sampled, same 0.3 allowance."""
        worst_inner, worst_outer = 0.0, float("inf")
        for part in self.geometry["RC_TunnelBend"]["parts"].values():
            for a, b, c in part_triangles(part):
                for p, q in ((a, b), (b, c), (c, a)):
                    for i in range(9):
                        t = i / 8
                        x, y, z = (p[k] + (q[k] - p[k]) * t for k in range(3))
                        if z >= 10.0:
                            continue
                        r = math.hypot(x - ARC_CENTRE[0], y - ARC_CENTRE[1])
                        if r <= 18.0:
                            worst_inner = max(worst_inner, r)
                        else:
                            worst_outer = min(worst_outer, r)
        self.assertLessEqual(worst_inner, 11.3, f"inner wall reaches radius {worst_inner:.3f}")
        self.assertGreaterEqual(worst_outer, 24.7, f"outer wall reaches radius {worst_outer:.3f}")


class TunnelReads(unittest.TestCase):
    """Visual reads from the W14d lessons. A first extrusion passes every rule above and reads as a pipe."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(RockCavesKit.GEOMETRY)

    def part(self, asset, label):
        return self.geometry[asset]["parts"][f"{asset}_{label}"]

    def inner_wall_reach(self, asset, centre, bend):
        """For each cross-section station, how far the inner wall stands from the corridor axis (low Z)."""
        reach = {}
        for x, y, z in self.part(asset, "Rock")["vertices"]:
            if not 0.5 < z < 9.5:
                continue
            if bend:
                r = math.hypot(x - ARC_CENTRE[0], y - ARC_CENTRE[1])
                if not 5.0 < r < 11.5 and not 24.5 < r < 31.0:
                    continue
                station = round(math.degrees(math.atan2(y - ARC_CENTRE[1], x - ARC_CENTRE[0])))
                reach.setdefault(station, []).append(abs(r - 18.0))
            else:
                if not 6.9 < abs(x) < 9.0:
                    continue
                reach.setdefault(round(y, 1), []).append(abs(x))
        return {k: min(v) for k, v in reach.items()}

    def test_straight_walls_wander_between_the_ends(self):
        reach = self.inner_wall_reach("RC_TunnelStraight", None, False)
        self.assertGreaterEqual(max(reach.values()) - min(reach.values()), 0.35,
                                "inner walls must recess unevenly, a straight extrusion reads as a pipe")

    def test_bend_walls_wander_between_the_ends(self):
        reach = self.inner_wall_reach("RC_TunnelBend", ARC_CENTRE, True)
        self.assertGreaterEqual(max(reach.values()) - min(reach.values()), 0.35)

    def test_straight_ceiling_has_hanging_rock(self):
        heights = [v[2] for v in self.part("RC_TunnelStraight", "Rock")["vertices"]
                   if abs(v[0]) < 6.0 and 10.5 < v[2] < 12.5 and abs(v[1]) < 11.5]
        self.assertTrue(heights)
        self.assertLessEqual(min(heights), 11.7, "the ceiling must not be one flat plane")
        self.assertGreaterEqual(min(heights), 10.5, "hanging rock may not eat the headroom")

    def test_outer_silhouette_is_not_a_flat_ridge(self):
        for asset in ("RC_TunnelStraight", "RC_TunnelBend"):
            tops = [v[2] for v in self.part(asset, "Rock")["vertices"] if v[2] > 15.0]
            self.assertLessEqual(min(tops), 17.4, f"{asset}: the roof must dip and rise between the ends")

    def test_rock_carries_boulders_besides_the_shell(self):
        for asset in ("RC_TunnelStraight", "RC_TunnelBend"):
            self.assertGreaterEqual(components(self.part(asset, "Rock")), 3, asset)

    def test_stain_is_separate_veins_inside_the_envelope(self):
        for asset in ("RC_TunnelStraight", "RC_TunnelBend"):
            stain = self.part(asset, "Stain")
            self.assertGreaterEqual(components(stain), 2, asset)
            s_low, s_high = bounds(part_triangles(stain))
            r_low, r_high = bounds(asset_triangles(self.geometry[asset]))
            for axis in range(3):
                self.assertGreaterEqual(s_low[axis], r_low[axis] - 1e-6)
                self.assertLessEqual(s_high[axis], r_high[axis] + 1e-6)


if __name__ == "__main__":
    unittest.main()
