"""Contracts for the Living Forest top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_living_forest_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. Prop sizes are the measured Blender kit values
(assets/blender/living-forest-kit/living-forest-kit-report.json). Nothing here was imported
into Roblox, played or measured on a device.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_living_forest_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_REPORT = REPO / "assets/blender/living-forest-kit/living-forest-kit-report.json"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 400.0, 195.0
MAX_INSTANCES, MAX_TRIANGLES = 180, 40000
MIX = {"LF_Broadleaf": 46, "LF_ResinStump": 10, "LF_FlowerClump": 60, "LF_StreamStone": 24,
       "LF_HollowArch": 2, "LF_TrailPost": 16, "LF_LogBridge": 4}
BUDGET_TRIS = {"LF_Broadleaf": 480, "LF_ResinStump": 180, "LF_FlowerClump": 90, "LF_StreamStone": 80,
               "LF_HollowArch": 520, "LF_TrailPost": 160, "LF_LogBridge": 300}
PARTS = {"LF_Broadleaf": 2, "LF_ResinStump": 2, "LF_FlowerClump": 2, "LF_StreamStone": 2,
         "LF_HollowArch": 2, "LF_TrailPost": 3, "LF_LogBridge": 2}
MEASURED_TRIS = {"LF_Broadleaf": 428, "LF_ResinStump": 164, "LF_FlowerClump": 80, "LF_StreamStone": 76,
                 "LF_HollowArch": 494, "LF_TrailPost": 146, "LF_LogBridge": 240}
ROUTE = [(-185, 70), (-125, 30), (-70, -25), (-5, -75), (55, -20), (115, 35), (160, 110), (185, 165)]
STREAMS = {
    "S1": [(-195, -110), (-140, -45), (-80, 22), (-55, 50), (-28, 52), (-8, 28), (8, -12), (40, -70),
           (58, -110), (62, -195)],
    "S2": [(30, 100), (52, 62), (104, -8), (122, -38), (150, -52), (186, -30), (190, 22), (168, 50),
           (120, 98), (100, 128), (95, 150), (90, 195)],
}
WATER_HALF = 6.0          # 12-stud water, slows walking to 10 studs/s
CORRIDOR_HALF = 7.0       # 14-stud route corridor
WALK_SPEED = 16.0
BASE_GAP = 1.0
# Footprints from the measured kit (ground reach, trunk core, canopy), scale 1.
ROOTS_R, CORE_R, CANOPY_R = 4.7, 2.5, 13.8
STUMP_R, FLOWER_R, POST_R = 3.2, 2.7, 1.85
STONE_HALF, ARCH_HALF, BRIDGE_HALF = (2.85, 2.05), (15.1, 7.05), (2.6, 9.15)
ARCH_PASSAGE = (-8.617, 8.617)
GATHER_LOCAL = -3.0       # Blender (0, -3, 2.5): 3 studs along local -Z
ALT_SEEDS = (11, 4242)


# ---- Independent helpers -----------------------------------------------------
def stream_dist(p, name=None):
    names = [name] if name else list(STREAMS)
    return min(g.project_to_polyline(STREAMS[n], p)[0] for n in names)


def route_dist(p):
    return g.project_to_polyline(ROUTE, p)[0]


def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def xz(inst):
    return (inst["x"], inst["z"])


def reach(inst):
    """Ground footprint (roots, base, rectangle) of one instance."""
    n, x, z, yaw, s = inst["name"], inst["x"], inst["z"], inst["rotation_y_deg"], inst["scale"]
    if n == "LF_Broadleaf":
        return g.Circle(x, z, ROOTS_R * s)
    if n == "LF_ResinStump":
        return g.Circle(x, z, STUMP_R * s)
    if n == "LF_FlowerClump":
        return g.Circle(x, z, FLOWER_R * s)
    if n == "LF_TrailPost":
        return g.Circle(x, z, POST_R)
    half = {"LF_StreamStone": STONE_HALF, "LF_HollowArch": ARCH_HALF, "LF_LogBridge": BRIDGE_HALF}[n]
    return g.rect_poly(x, z, half[0], half[1], yaw)


def seg_heading(index):
    (ax, az), (bx, bz) = ROUTE[index], ROUTE[index + 1]
    return g.heading_deg(bx - ax, bz - az)


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def gather_point(inst):
    r = math.radians(inst["rotation_y_deg"])
    offset = GATHER_LOCAL * inst["scale"]
    return (inst["x"] + offset * math.sin(r), inst["z"] + offset * math.cos(r))


class RuleChecks:
    """check_* methods only need self.layout; test classes decide which seed."""

    layout = None

    def solids(self):
        return [i for i in self.layout["instances"] if i["name"] != "LF_FlowerClump"]

    def check_schema(self):
        layout = self.layout
        for key in ("name", "status", "seed", "instances", "totals", "route", "streams", "crossings",
                    "chains", "density", "caps"):
            self.assertIn(key, layout)
        self.assertIn("unvalidated", layout["status"])
        ids = [i["id"] for i in layout["instances"]]
        self.assertEqual(len(ids), len(set(ids)))
        for inst in layout["instances"]:
            for key in ("id", "name", "x", "z", "rotation_y_deg", "scale"):
                self.assertIn(key, inst)
            self.assertIn(inst["name"], MIX)
            self.assertTrue(all(math.isfinite(inst[k]) for k in ("x", "z", "rotation_y_deg", "scale")))

    def check_counts_and_budgets(self):
        names = [i["name"] for i in self.layout["instances"]]
        for name, count in MIX.items():
            self.assertEqual(names.count(name), count, name)
        total = len(names)
        self.assertEqual(total, 162)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        parts = sum(PARTS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], parts)
        self.assertEqual(budget, 36000)
        self.assertLessEqual(measured, budget)
        self.assertLessEqual(budget, MAX_TRIANGLES)
        for name, entry in totals["by_name"].items():
            self.assertEqual(entry["count"], MIX[name])
            self.assertEqual(entry["triangles"], MIX[name] * MEASURED_TRIS[name])

    def check_inside_the_sector(self):
        for inst in self.layout["instances"]:
            x0, z0, x1, z1 = g.shape_bbox(reach(inst))
            self.assertGreaterEqual(min(x0, z0), -LIMIT, inst["id"])
            self.assertLessEqual(max(x1, z1), LIMIT, inst["id"])

    def check_route(self):
        route = self.layout["route"]
        self.assertEqual([tuple(p) for p in route["nodes"]], ROUTE)
        length = g.polyline_length(ROUTE)
        self.assertAlmostEqual(route["length"], length, delta=0.5)
        self.assertAlmostEqual(route["walk_seconds"], length / WALK_SPEED, delta=0.1)
        self.assertGreaterEqual(length, 400.0)
        for node in (ROUTE[0], ROUTE[-1]):  # the two gates sit near the sector edge
            self.assertGreaterEqual(max(abs(node[0]), abs(node[1])), 165.0)

    def check_corridor_and_water_clearance(self):
        for inst in self.solids():
            n, shape = inst["name"], reach(inst)
            if n in ("LF_HollowArch", "LF_LogBridge", "LF_StreamStone"):
                continue
            gap = g.shape_polyline_dist(shape, ROUTE)
            self.assertGreaterEqual(gap, CORRIDOR_HALF + (0.2 if n == "LF_TrailPost" else BASE_GAP) - 1e-6,
                                    inst["id"])
            if n != "LF_TrailPost":
                self.assertGreaterEqual(route_dist(xz(inst)), 12.0 - 1e-6, inst["id"])
            for stream in STREAMS.values():
                self.assertGreaterEqual(g.shape_polyline_dist(shape, stream), WATER_HALF + BASE_GAP - 1e-6,
                                        inst["id"])
        for inst in by_name(self.layout, "LF_HollowArch"):
            for stream in STREAMS.values():
                self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), stream), WATER_HALF + BASE_GAP, inst["id"])
        for inst in by_name(self.layout, "LF_FlowerClump"):
            self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), ROUTE), 4.0 - 1e-6, inst["id"])
            for stream in STREAMS.values():
                self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), stream), WATER_HALF + 0.5 - 1e-6,
                                        inst["id"])

    def check_bridges_sit_on_crossings(self):
        found = []
        for name, nodes in STREAMS.items():
            for c in g.crossings(ROUTE, nodes):
                found.append((name, c))
        bridges = by_name(self.layout, "LF_LogBridge")
        self.assertEqual(len(found), 4, "the plan is built around four route/stream crossings")
        self.assertEqual(len(bridges), 4)
        for name, c in found:
            near = min(bridges, key=lambda b: math.dist(xz(b), c["point"]))
            self.assertLess(math.dist(xz(near), c["point"]), 0.01, name)
            self.assertLess(angle_diff(near["rotation_y_deg"], seg_heading(c["first_index"])), 0.01)
            self.assertEqual(near["scale"], 1)
            self.assertGreaterEqual(c["angle_deg"], 55.0)
            chord = 2 * WATER_HALF / math.sin(math.radians(c["angle_deg"]))
            self.assertLessEqual(chord, 15.0, "the water must fit under the 10.8-stud flat plus two ramps")
            self.assertGreaterEqual(min(math.dist(c["point"], v) for v in ROUTE), 10.0)
            self.assertGreaterEqual(min(math.dist(c["point"], v) for v in STREAMS[name]), 10.0)
        self.assertEqual(len(self.layout["crossings"]), 4)

    def check_route_never_stands_in_water_without_a_bridge(self):
        bridges = [reach(b) for b in by_name(self.layout, "LF_LogBridge")]
        length = g.polyline_length(ROUTE)
        steps = int(length / 0.5)
        for k in range(steps + 1):
            point = g.polyline_point(ROUTE, length * k / steps)[0]
            if stream_dist(point) < WATER_HALF:
                self.assertTrue(any(g.shape_point_dist(b, point) == 0.0 for b in bridges),
                                f"route stands in water at {point}")

    def check_stone_chains(self):
        stones = by_name(self.layout, "LF_StreamStone")
        chains = self.layout["chains"]
        self.assertEqual(len(chains), 8)
        self.assertEqual(sorted(i for c in chains for i in c["stone_ids"]), sorted(s["id"] for s in stones))
        bridges = by_name(self.layout, "LF_LogBridge")
        for chain in chains:
            members = [next(s for s in stones if s["id"] == i) for i in chain["stone_ids"]]
            self.assertEqual(len(members), 3)
            stream = STREAMS[chain["stream"]]
            centre = chain["center"]
            distance, arc, index, _ = g.project_to_polyline(stream, centre)
            self.assertLess(distance, 0.05, "chain centre lies on the stream")
            _, tangent, _ = g.polyline_point(stream, arc)
            normal = (-tangent[1], tangent[0])
            spots = sorted(((m["x"] - centre[0]) * normal[0] + (m["z"] - centre[1]) * normal[1]) for m in members)
            for m in members:
                self.assertEqual(m["scale"], 1)
                self.assertLess(angle_diff(m["rotation_y_deg"], g.heading_deg(*tangent)), 0.5)
            gaps = [(b - a) - 5.0 for a, b in zip(spots, spots[1:])]  # stone length along the chain is 5
            self.assertTrue(all(0.5 <= gap <= 1.5 for gap in gaps), gaps)
            self.assertLess(spots[0] - 2.5, -WATER_HALF, "chain reaches one bank")
            self.assertGreater(spots[-1] + 2.5, WATER_HALF, "chain reaches the other bank")
            self.assertGreaterEqual(min(math.dist(centre, xz(b)) for b in bridges), 30.0)
            self.assertGreaterEqual(route_dist(centre), 18.0)
            self.assertGreaterEqual(min(math.dist(centre, v) for v in stream), 8.0, "stream is straight here")

    def check_arches_straddle_the_route(self):
        arches = by_name(self.layout, "LF_HollowArch")
        self.assertEqual(len(arches), 2)
        for inst in arches:
            distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005)
            self.assertEqual(inst["scale"], 1)
            a, b = ROUTE[index], ROUTE[index + 1]
            self.assertGreaterEqual(min(math.dist(xz(inst), a), math.dist(xz(inst), b)), ARCH_HALF[1] + 1.0,
                                    "route must stay straight through the arch")
            self.assertLessEqual(ARCH_PASSAGE[0], -CORRIDOR_HALF)
            self.assertGreaterEqual(ARCH_PASSAGE[1], CORRIDOR_HALF)

    def check_posts(self):
        posts = by_name(self.layout, "LF_TrailPost")
        self.assertEqual(len(posts), 16)
        arcs = []
        for post in posts:
            distance, arc, _, _ = g.project_to_polyline(ROUTE, xz(post))
            self.assertGreaterEqual(distance, 8.9, post["id"])
            self.assertLessEqual(distance, 11.0, post["id"])
            arcs.append(arc)
        arcs.sort()
        self.assertTrue(all(b - a >= 20.0 for a, b in zip(arcs, arcs[1:])), "posts spread along the route")
        self.assertLessEqual(arcs[0], 40.0)
        self.assertGreaterEqual(arcs[-1], g.polyline_length(ROUTE) - 40.0)

    def check_no_solid_overlaps(self):
        solids = self.solids()
        shapes = {i["id"]: reach(i) for i in solids}
        chain_of = {i: n for n, c in enumerate(self.layout["chains"]) for i in c["stone_ids"]}
        for a_index, a in enumerate(solids):
            for b in solids[a_index + 1:]:
                if a["name"] == b["name"] == "LF_StreamStone" and chain_of[a["id"]] == chain_of[b["id"]]:
                    continue
                if a["name"] == "LF_StreamStone" and b["name"] == "LF_LogBridge" or \
                        b["name"] == "LF_StreamStone" and a["name"] == "LF_LogBridge":
                    needed = 3.0
                else:
                    needed = BASE_GAP
                gap = g.shape_gap(shapes[a["id"]], shapes[b["id"]])
                self.assertGreaterEqual(gap, needed - 1e-6, f"{a['id']} and {b['id']}")
        for flower in by_name(self.layout, "LF_FlowerClump"):
            for solid in solids:
                self.assertGreaterEqual(g.shape_gap(reach(flower), shapes[solid["id"]]), 0.0)
                self.assertGreater(g.shape_gap(reach(flower), shapes[solid["id"]]) + 1e-9, 0.0,
                                   f"{flower['id']} sits inside {solid['id']}")

    def check_broadleaf_spacing(self):
        trees = by_name(self.layout, "LF_Broadleaf")
        for a_index, a in enumerate(trees):
            for b in trees[a_index + 1:]:
                self.assertGreaterEqual(math.dist(xz(a), xz(b)), 16.0 - 1e-6, f"{a['id']} {b['id']}")
            self.assertGreaterEqual(a["scale"], 0.9)
            self.assertLessEqual(a["scale"], 1.15)

    def check_resin_stumps_face_the_trail(self):
        for stump in by_name(self.layout, "LF_ResinStump"):
            point = gather_point(stump)
            distance = route_dist(point)
            self.assertGreaterEqual(distance, 8.0, stump["id"])
            self.assertLessEqual(distance, 50.0, stump["id"])
            self.assertLess(distance, route_dist(xz(stump)), "the gather side faces the trail")
            for stream in STREAMS.values():
                self.assertGreater(g.project_to_polyline(stream, point)[0], WATER_HALF, stump["id"])
            for solid in self.solids():
                if solid["id"] != stump["id"]:
                    self.assertGreater(g.shape_point_dist(reach(solid), point), 0.0, f"{stump['id']} / {solid['id']}")

    def check_open_floor(self):
        canopy = [(i["x"], i["z"], CANOPY_R * i["scale"]) for i in by_name(self.layout, "LF_Broadleaf")]
        covered = total = 0
        for ix in range(-195, 196, 5):
            for iz in range(-195, 196, 5):
                total += 1
                covered += any(math.hypot(ix - x, iz - z) <= r for x, z, r in canopy)
        fraction = covered / total
        self.assertAlmostEqual(self.layout["density"]["canopy_cover_fraction"], fraction, delta=0.02)
        self.assertGreaterEqual(fraction, 0.08)
        self.assertLessEqual(fraction, 0.30, "the floor must stay open")

    def check_flowers_gather_in_patches(self):
        flowers = by_name(self.layout, "LF_FlowerClump")
        self.assertEqual(len(flowers), 60)
        for inst in flowers:
            self.assertLessEqual(inst["scale"], 1.2 + 1e-9)  # height 2.5 x scale stays at or under 3 (N1)
            self.assertGreaterEqual(inst["scale"], 0.8 - 1e-9)
        patches = self.layout["density"]["flower_patches"]
        self.assertEqual(sum(patches), 60)
        self.assertGreaterEqual(len(patches), 8)

    def check_everything(self):
        self.check_schema()
        self.check_counts_and_budgets()
        self.check_inside_the_sector()
        self.check_route()
        self.check_corridor_and_water_clearance()
        self.check_bridges_sit_on_crossings()
        self.check_route_never_stands_in_water_without_a_bridge()
        self.check_stone_chains()
        self.check_arches_straddle_the_route()
        self.check_posts()
        self.check_no_solid_overlaps()
        self.check_broadleaf_spacing()
        self.check_resin_stumps_face_the_trail()
        self.check_open_floor()
        self.check_flowers_gather_in_patches()


class DefaultSeed(RuleChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads(plan.to_json(plan.generate(plan.DEFAULT_SEED)))

    def test_schema(self):
        self.check_schema()

    def test_counts_and_budgets(self):
        self.check_counts_and_budgets()

    def test_inside_the_sector(self):
        self.check_inside_the_sector()

    def test_route(self):
        self.check_route()

    def test_corridor_and_water_clearance(self):
        self.check_corridor_and_water_clearance()

    def test_bridges_sit_on_crossings(self):
        self.check_bridges_sit_on_crossings()

    def test_route_never_stands_in_water_without_a_bridge(self):
        self.check_route_never_stands_in_water_without_a_bridge()

    def test_stone_chains(self):
        self.check_stone_chains()

    def test_arches_straddle_the_route(self):
        self.check_arches_straddle_the_route()

    def test_posts(self):
        self.check_posts()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_broadleaf_spacing(self):
        self.check_broadleaf_spacing()

    def test_resin_stumps_face_the_trail(self):
        self.check_resin_stumps_face_the_trail()

    def test_open_floor(self):
        self.check_open_floor()

    def test_flowers_gather_in_patches(self):
        self.check_flowers_gather_in_patches()

    def test_measured_triangles_match_the_kit_report(self):
        if not KIT_REPORT.exists():
            self.skipTest("kit report not built")
        props = json.loads(KIT_REPORT.read_text(encoding="utf-8"))["props"]
        for name, tris in MEASURED_TRIS.items():
            self.assertEqual(props[name]["triangles"], tris, name)
            self.assertEqual(len(props[name]["parts"]), PARTS[name], name)
            self.assertLessEqual(tris, BUDGET_TRIS[name])

    def test_footprints_cover_the_measured_kit_geometry(self):
        geometry_path = REPO / "assets/blender/living-forest-kit/living-forest-kit-geometry.json"
        if not geometry_path.exists():
            self.skipTest("kit geometry not built")
        dump = json.loads(geometry_path.read_text(encoding="utf-8"))

        def points(name, label=None):
            return [v for obj, part in dump[name]["parts"].items() if label is None or obj.endswith("_" + label)
                    for v in part["vertices"]]

        def ground(name):
            return [v for v in points(name) if v[2] <= 0.6]

        radius = {"LF_Broadleaf": ROOTS_R, "LF_ResinStump": STUMP_R, "LF_FlowerClump": FLOWER_R,
                  "LF_TrailPost": POST_R}
        for name, wanted in radius.items():
            self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in ground(name)), wanted, name)
        half = {"LF_StreamStone": STONE_HALF, "LF_HollowArch": ARCH_HALF, "LF_LogBridge": BRIDGE_HALF}
        for name, (half_x, half_y) in half.items():
            pts = points(name)
            self.assertLessEqual(max(abs(v[0]) for v in pts), half_x, name)
            self.assertLessEqual(max(abs(v[1]) for v in pts), half_y, name)
        trunk = [v for v in points("LF_Broadleaf", "Trunk") if 3.0 <= v[2] <= 12.0]
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in trunk), CORE_R)
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in points("LF_Broadleaf", "Crown")), CANOPY_R)

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 162)
        self.assertLessEqual(totals["triangles_measured"], MAX_TRIANGLES)
        self.assertEqual(self.layout["caps"], {"instances": MAX_INSTANCES, "triangles": MAX_TRIANGLES})

    def test_generation_is_deterministic(self):
        self.assertEqual(plan.to_json(plan.generate(plan.DEFAULT_SEED)), plan.to_json(plan.generate(plan.DEFAULT_SEED)))

    def test_outputs_are_written(self):
        with tempfile.TemporaryDirectory() as tmp:
            written = plan.write_outputs(plan.generate(plan.DEFAULT_SEED), tmp)
            suffixes = {p.suffix for p in written}
            self.assertTrue({".json", ".svg"} <= suffixes)
            for path in written:
                self.assertGreater(path.stat().st_size, 0)
            self.assertIn("<svg", Path(tmp, plan.LAYOUT_NAME + ".svg").read_text(encoding="utf-8"))


class AlternateSeeds(RuleChecks, unittest.TestCase):
    def test_every_rule_holds_for_other_seeds(self):
        for seed in ALT_SEEDS:
            with self.subTest(seed=seed):
                self.layout = json.loads(plan.to_json(plan.generate(seed)))
                self.check_everything()


if __name__ == "__main__":
    unittest.main()
