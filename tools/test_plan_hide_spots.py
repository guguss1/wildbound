"""Contracts for the delivery D7 hiding-spot layout (docs/mechanics/wildbound-delivery-d.md section 3).

    python -I -B -m unittest discover -s tools -p test_plan_hide_spots.py

The rules are restated here and re-derived from the saved JSON, not from the planner's own report.
"""

import json
import math
import unittest
from pathlib import Path

import plan_forest_layout as forest
import plan_hide_spots as hide

REPO = Path(__file__).resolve().parent.parent
SAVED = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
CORES = {"FK_Evergreen": 2.5, "FK_DeadTree": 3.4}
SAFE = (((-140.0, 140.0), 35.0), ((105.0, 125.0), 22.0))
ROUTE = [(-140.0, 140.0), (-95.0, 75.0), (0.0, -85.0), (35.0, -99.0), (115.0, 15.0), (105.0, 125.0)]


def seg_dist(p, a, b):
    ax, az, bx, bz = a[0], a[1], b[0], b[1]
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (az + t * dz))


def route_distance(p):
    return min(seg_dist(p, ROUTE[i], ROUTE[(i + 1) % len(ROUTE)]) for i in range(len(ROUTE)))


_CACHE = {}


def saved():
    if "s" not in _CACHE:
        _CACHE["s"] = json.loads(SAVED.read_text(encoding="utf-8"))
    return _CACHE["s"]


def layout():
    if "l" not in _CACHE:
        _CACHE["l"] = json.loads(LAYOUT.read_text(encoding="utf-8"))
    return _CACHE["l"]


class HideSpotLayout(unittest.TestCase):
    def test_d7_ten_spots_six_bushes_four_logs_with_ids(self):
        spots = saved()["spots"]
        self.assertEqual(len(spots), 10)
        self.assertEqual(sum(1 for s in spots if s["kind"] == "bush"), 6)
        self.assertEqual(sum(1 for s in spots if s["kind"] == "log"), 4)
        self.assertEqual([s["id"] for s in spots], [f"H{i:02d}" for i in range(1, 11)])

    def test_d7_none_in_a_safe_circle_and_at_least_25_apart(self):
        spots = saved()["spots"]
        for s in spots:
            for centre, radius in SAFE:
                self.assertGreater(math.hypot(s["x"] - centre[0], s["z"] - centre[1]), radius, s["id"])
        for i, a in enumerate(spots):
            for b in spots[i + 1:]:
                self.assertGreaterEqual(math.hypot(a["x"] - b["x"], a["z"] - b["z"]), 25.0, (a["id"], b["id"]))

    def test_d7_route_band_and_trunk_cores(self):
        cores = [(i["x"], i["z"], CORES[i["name"]] * i["scale"]) for i in layout()["instances"] if i["name"] in CORES]
        for s in saved()["spots"]:
            distance = route_distance((s["x"], s["z"]))
            if s["kind"] == "bush":
                self.assertTrue(8.0 <= distance <= 14.0, (s["id"], distance))
            else:
                self.assertTrue(15.0 <= distance <= 32.0, (s["id"], distance))
            gap = min(math.hypot(s["x"] - x, s["z"] - z) - r for x, z, r in cores)
            self.assertGreaterEqual(gap, 10.0, s["id"])

    def test_d7_no_spot_on_the_guardian_patrol_diamond(self):
        loop = [(16.0, -85.0), (0.0, -69.0), (-16.0, -85.0), (0.0, -101.0)]
        for s in saved()["spots"]:
            gap = min(seg_dist((s["x"], s["z"]), loop[i], loop[(i + 1) % 4]) for i in range(4))
            self.assertGreaterEqual(gap, 12.0, s["id"])

    def test_d7_logs_are_existing_fallen_logs_in_place(self):
        by_id = {i["id"]: i for i in layout()["instances"]}
        for s in saved()["spots"]:
            if s["kind"] == "log":
                log = by_id[s["log_id"]]
                self.assertEqual(log["name"], "FK_FallenLog")
                self.assertEqual((s["x"], s["z"]), (log["x"], log["z"]))

    def test_d7_objective_coverage(self):
        spots = saved()["spots"]

        def near(target, low, high):
            return any(low <= math.hypot(s["x"] - target[0], s["z"] - target[1]) <= high for s in spots)
        for name, target in {"nest": (35.0, -99.0), "ruin": (0.0, -85.0), "marsh": (115.0, 15.0)}.items():
            self.assertTrue(near(target, 25.0, 45.0), name)
        self.assertTrue(near((-95.0, 75.0), 0.0, 45.0), "clearing")

    def test_d7_map_builder_carries_the_saved_spots(self):
        import re
        source = (REPO / "tools/build-wildbound-p0-map.luau").read_text(encoding="utf-8")
        rows = re.findall(r"\{ id = '(H\d\d)', kind = '(\w+)', x = ([-\d.]+), z = ([-\d.]+), yaw = ([-\d.]+), "
                          r"scale = ([-\d.]+) \}", source)
        expected = [(s["id"], s["kind"], s["x"], s["z"], s["yaw"], s["scale"]) for s in saved()["spots"]]
        self.assertEqual([(a, b, float(c), float(d), float(e), float(f)) for a, b, c, d, e, f in rows], expected)

    def test_d7_saved_file_matches_the_planner(self):
        self.assertEqual(hide.render(hide.plan(layout())), SAVED.read_text(encoding="utf-8"))

    def test_d7_planner_route_matches_the_forest_plan(self):
        self.assertEqual([tuple(p) for p in forest.ROUTE], ROUTE)

    def test_hide_spots_on_flat_relief(self):
        relief = json.loads((REPO / "assets/maps/forest-layout/relief-v1.json").read_text(encoding="utf-8"))["segments"]
        for s in saved()["spots"]:
            self.assertTrue(hide.relief_flat((s["x"], s["z"]), relief), s["id"])
        crest = relief[0]
        middle = ((crest["a"][0] + crest["b"][0]) / 2, (crest["a"][1] + crest["b"][1]) / 2)
        self.assertFalse(hide.relief_flat(middle, relief), "a crest is not a hiding place")
        self.assertFalse(hide.bush_ok(middle, layout(), hide.cores(layout()), [], relief), "the bush rule reads the relief")


if __name__ == "__main__":
    unittest.main()
