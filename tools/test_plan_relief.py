"""Contracts for the expedition relief layout (docs/mechanics/wildbound-expedition-islands.md section 1, task R1).

    python -I -B -m unittest discover -s tools -p test_plan_relief.py

The rules are restated here and re-derived from the saved JSON with this file's own height rule, not from the
planner's report. The Luau module `src/wildbound/WildboundRelief.luau` must match the same golden samples.
"""

import json
import math
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
SAVED = REPO / "assets/maps/forest-layout/relief-v1.json"
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
HIDE = REPO / "assets/maps/forest-layout/hide-spots-v1.json"

FLOOR_TOP = 0.5
ROUTE = [(-140.0, 140.0), (-95.0, 75.0), (0.0, -85.0), (35.0, -99.0), (115.0, 15.0), (105.0, 125.0)]
ROUTE_HALF = 7.0
SAFE = (((-140.0, 140.0), 35.0), ((105.0, 125.0), 22.0))
HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)
ISLANDS = {"claro": ((-95.0, 75.0), 14.0), "hondonada": ((-27.0, 0.0), 16.0), "pantano": ((115.0, 15.0), 16.0),
           "ruinas": ((35.0, -99.0), 16.0), "corazon": ((60.0, -135.0), 16.0)}
# WildboundLumipolWild slots (S0a to E3) and the economy gather slots are read where they live; the Lumipol slots
# are restated because they live in Luau. tests/WildboundLumipolWild_Test.luau checks the same flatness in Studio.
LUMIPOL_SLOTS = [(-95, 75), (-112, 92), (-10, -60), (30, -105), (65, -60), (110, 5), (35, -99), (-38, -85),
                 (60, -125)]
SPAWN, EYE = (-140.0, 150.0), 3.7
NEST, LANES = (35.0, -99.0), [(16.0, -85.0), (0.0, -101.0)]


def height_at(segments, x, z):
    best = 0.0
    for s in segments:
        (ax, az), (bx, bz) = s["a"], s["b"]
        length = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / length, (bz - az) / length
        mx, mz = (ax + bx) / 2, (az + bz) / 2
        t = (x - mx) * ux + (z - mz) * uz
        d = -(x - mx) * uz + (z - mz) * ux
        run = s["height"] / math.tan(math.radians(s["slopeDeg"]))
        cross = min(1.0, max(0.0, (s["crestWidth"] / 2 + run - abs(d)) / run))
        along = min(1.0, max(0.0, (length / 2 + run - abs(t)) / run))
        best = max(best, s["height"] * min(cross, along))
    return FLOOR_TOP + best


def slope_deg(segments, x, z, step=0.25):
    """Steepest one-sided rise over 16 directions: exact for the piecewise-planar relief, no crease overshoot."""
    here = height_at(segments, x, z)
    worst = 0.0
    for k in range(16):
        angle = math.pi * k / 8
        rise = abs(height_at(segments, x + step * math.cos(angle), z + step * math.sin(angle)) - here)
        worst = max(worst, rise / step)
    return math.degrees(math.atan(worst))


def in_territory(x, z):
    in_fog = FOG[0] <= x <= FOG[1] and FOG[2] <= z <= FOG[3]
    safe = any(math.hypot(x - c[0], z - c[1]) <= r for c, r in SAFE)
    return in_fog and not safe and math.hypot(x - HOME[0], z - HOME[1]) <= LEASH


def footprint_points(s, step=2.0):
    (ax, az), (bx, bz) = s["a"], s["b"]
    length = math.hypot(bx - ax, bz - az)
    ux, uz = (bx - ax) / length, (bz - az) / length
    mx, mz = (ax + bx) / 2, (az + bz) / 2
    run = s["height"] / math.tan(math.radians(s["slopeDeg"]))
    half_t, half_d = length / 2 + run, s["crestWidth"] / 2 + run
    t = -half_t
    while t <= half_t + 1e-9:
        d = -half_d
        while d <= half_d + 1e-9:
            yield mx + t * ux - d * uz, mz + t * uz + d * ux
            d += step
        t += step


def disk(centre, radius, step=1.0):
    n = int(radius // step)
    for i in range(-n, n + 1):
        for j in range(-n, n + 1):
            if math.hypot(i * step, j * step) <= radius:
                yield centre[0] + i * step, centre[1] + j * step


_CACHE = {}


def saved():
    if "s" not in _CACHE:
        _CACHE["s"] = json.loads(SAVED.read_text(encoding="utf-8"))
    return _CACHE["s"]


def segs():
    return saved()["segments"]


def forest():
    if "f" not in _CACHE:
        _CACHE["f"] = json.loads(LAYOUT.read_text(encoding="utf-8"))
    return _CACHE["f"]


class ReliefLayout(unittest.TestCase):
    def test_crest_at_most_10_outside_and_6_inside_territory(self):
        self.assertGreater(len(segs()), 0)
        for s in segs():
            self.assertLessEqual(s["height"], 10.0, s["id"])
            for x, z in footprint_points(s):
                h = height_at(segs(), x, z) - FLOOR_TOP
                self.assertLessEqual(h, 10.0 + 1e-6, s["id"])
                if in_territory(x, z):
                    self.assertLessEqual(h, 6.0 + 1e-6, f"{s['id']} at {x:.1f}, {z:.1f} in the territory")

    def test_every_slope_at_most_20_degrees(self):
        for s in segs():
            self.assertLessEqual(s["slopeDeg"], 20.0, s["id"])
            for x, z in footprint_points(s, 1.5):
                self.assertLessEqual(slope_deg(segs(), x, z), 20.0 + 1e-6, f"{s['id']} at {x:.1f}, {z:.1f}")

    def test_route_grade_at_most_6_and_cross_slope_at_most_3(self):
        for i, a in enumerate(ROUTE):
            b = ROUTE[(i + 1) % len(ROUTE)]
            length = math.dist(a, b)
            ux, uz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
            previous = None
            for k in range(int(length) + 1):
                x, z = a[0] + ux * k, a[1] + uz * k
                h = height_at(segs(), x, z)
                if previous is not None:
                    self.assertLessEqual(math.degrees(math.atan(abs(h - previous))), 6.0, f"leg {i} at {k}")
                previous = h
                for side in (-ROUTE_HALF, ROUTE_HALF):
                    edge = height_at(segs(), x - uz * side, z + ux * side)
                    self.assertLessEqual(math.degrees(math.atan(abs(edge - h) / ROUTE_HALF)), 3.0, f"leg {i} at {k}")

    def test_island_floors_flat(self):
        for name, (centre, radius) in ISLANDS.items():
            heights = [height_at(segs(), x, z) for x, z in disk(centre, radius)]
            self.assertLessEqual(max(heights) - min(heights), 0.5, name)
            for x, z in disk(centre, radius, 2.0):
                self.assertLessEqual(slope_deg(segs(), x, z), 3.0, name)

    def test_no_relief_in_safe_circles_plus_3(self):
        for centre, radius in SAFE:
            for x, z in disk(centre, radius + 3.0):
                self.assertEqual(height_at(segs(), x, z), FLOOR_TOP, f"relief at {x}, {z}")

    def test_hide_spots_and_slots_on_flat_ground(self):
        points = [(s["x"], s["z"]) for s in json.loads(HIDE.read_text(encoding="utf-8"))["spots"]]
        points += LUMIPOL_SLOTS
        import simulate_economy as eco  # the one reader of the economy tuning block
        points += [(s["x"], s["z"]) for s in eco.load_tuning()["gather"]["slots"]]
        self.assertGreater(len(points), 40)
        for p in points:
            for x, z in disk(p, 5.0):
                self.assertEqual(height_at(segs(), x, z), FLOOR_TOP, f"slot {p} not flat at {x}, {z}")

    def test_default_spawn_pad_stays_flat(self):
        # Found in the R6 Play check: the place keeps Roblox's default SpawnLocation, a 12 by 12 pad at the origin;
        # characters appear on it before the inventory server moves them to camp, so it must not sit in a ridge.
        for x, z in disk((0.0, 0.0), 6.0 * math.sqrt(2) + 3.0):
            self.assertEqual(height_at(segs(), x, z), FLOOR_TOP, f"relief over the spawn pad at {x}, {z}")

    def test_part_budget_at_most_250(self):
        totals = saved()["totals"]
        self.assertEqual(totals["segments"], len(segs()))
        self.assertEqual(totals["parts"], len(segs()) * saved()["partsPerSegment"])
        self.assertEqual(saved()["partsPerSegment"], 9)
        self.assertLessEqual(totals["parts"], 250)

    def test_camp_exit_lantern_visible_from_spawn(self):
        lantern = next(i for i in forest()["instances"] if i["id"] == "FK_LanternMarker_012")
        for k in range(101):
            t = k / 100
            x, z = SPAWN[0] + (lantern["x"] - SPAWN[0]) * t, SPAWN[1] + (lantern["z"] - SPAWN[1]) * t
            self.assertLess(height_at(segs(), x, z), FLOOR_TOP + EYE)

    def test_golden_samples_written(self):
        samples = saved()["samples"]
        self.assertEqual(len(samples), 64)
        self.assertGreater(sum(1 for s in samples if s["y"] > FLOOR_TOP + 1), 16, "samples must cover the relief")
        for s in samples:
            self.assertAlmostEqual(height_at(segs(), s["x"], s["z"]), s["y"], delta=0.01)

    def test_trees_steeper_than_12_degrees_are_moved(self):
        removed = set(saved()["removedTrees"])
        self.assertLessEqual(len(removed), 30, "at most 30 of the 172 layout trees make way")
        by_id = {item["id"]: item for item in forest()["instances"]}
        for tree_id in removed:
            item = by_id[tree_id]
            self.assertIn(item["name"], ("FK_Evergreen", "FK_DeadTree"))
            self.assertGreater(slope_deg(segs(), item["x"], item["z"]), 12.0, f"{tree_id} need not go")
            self.assertGreaterEqual(math.dist((item["x"], item["z"]), NEST), 27.0, "the nest cover band stays")
        for item in forest()["instances"]:
            if item["name"] in ("FK_Evergreen", "FK_DeadTree") and item["id"] not in removed:
                self.assertLessEqual(slope_deg(segs(), item["x"], item["z"]), 12.0 + 1e-6, item["id"])

    def test_logs_only_on_slopes_at_most_6(self):
        for item in forest()["instances"]:
            if item["name"] == "FK_FallenLog":
                reach = 8.5 * item["scale"]
                for x, z in disk((item["x"], item["z"]), reach, 1.5):
                    self.assertLessEqual(slope_deg(segs(), x, z), 6.0, item["id"])

    def test_nest_sight_lanes_stay_open(self):
        for lane in LANES:
            for k in range(101):
                t = k / 100
                x, z = NEST[0] + (lane[0] - NEST[0]) * t, NEST[1] + (lane[1] - NEST[1]) * t
                self.assertEqual(height_at(segs(), x, z), FLOOR_TOP, f"lane to {lane} at {t}")

    def test_design_features_present(self):
        features = {s["feature"] for s in segs()}
        for name in ("rim-claro", "loma-larga", "rim-hondonada", "cresta-vigia", "rim-ruinas", "rim-corazon"):
            self.assertIn(name, features)
        vigia = [s for s in segs() if s["feature"] == "cresta-vigia"]
        self.assertTrue(all(in_territory(*[(s["a"][0] + s["b"][0]) / 2, (s["a"][1] + s["b"][1]) / 2]) for s in vigia))
        self.assertTrue(max(s["height"] for s in segs() if s["feature"] == "loma-larga") >= 8.0, "Loma Larga is the tall one")

    def test_planner_reproduces_the_saved_file(self):
        import plan_relief
        self.assertEqual(plan_relief.render(plan_relief.plan()), SAVED.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
