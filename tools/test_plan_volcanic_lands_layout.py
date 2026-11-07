"""Contracts for the Volcanic Lands top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_volcanic_lands_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. Prop sizes are the measured Blender kit values
(assets/blender/volcanic-lands-kit). Nothing here was imported into Roblox, played or measured
on a device.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_volcanic_lands_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_DIR = REPO / "assets/blender/volcanic-lands-kit"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 400.0, 195.0
MAX_INSTANCES, MAX_TRIANGLES = 210, 30000
MIX = {"VL_BasaltColumn": 60, "VL_Vent": 14, "VL_CoolStone": 40, "VL_CharredTree": 36, "VL_AshShrine": 2,
       "VL_CrustPlate": 20, "VL_ObsidianShard": 18}
BUDGET_TRIS = {"VL_BasaltColumn": 120, "VL_Vent": 160, "VL_CoolStone": 80, "VL_CharredTree": 220,
               "VL_AshShrine": 480, "VL_CrustPlate": 120, "VL_ObsidianShard": 90}
MEASURED_TRIS = {"VL_BasaltColumn": 116, "VL_Vent": 156, "VL_CoolStone": 58, "VL_CharredTree": 178,
                 "VL_AshShrine": 418, "VL_CrustPlate": 98, "VL_ObsidianShard": 82}
PARTS = {"VL_BasaltColumn": 1, "VL_Vent": 2, "VL_CoolStone": 1, "VL_CharredTree": 2, "VL_AshShrine": 2,
         "VL_CrustPlate": 2, "VL_ObsidianShard": 2}
ROUTE = [(-190, 130), (-90, 130), (-10, 50), (100, 50), (150, -60), (150, -150), (190, -190)]
CORRIDOR_HALF = 7.0
WALK_SPEED = 16.0
BASE_GAP = 1.0
# Hazard rule (bible section 2): 6 s calm, 2.5 s glow and ground ring, 3 s eruption, radius 10.
CALM, GLOW, ERUPT, RADIUS = 6.0, 2.5, 3.0, 10.0
CYCLE = CALM + GLOW + ERUPT
ROUTE_VENTS, FLANK_VENTS = 8, 6
# Measured kit footprints at scale 1: bounding circles of the ground and branches.
COLUMN_R, VENT_R, STONE_R, TREE_R, PLATE_R, SHARD_R = 5.2, 5.8, 3.3, 8.7, 11.0, 3.1
SHRINE_HALF = (14.3, 7.7)
SHRINE_PASSAGE = (-7.447, 7.4521)
SHARD_GATHER = -2.5
SIGHT_LEAD = 40.0
ALT_SEEDS = (11, 4242)


# ---- Independent helpers -----------------------------------------------------
def route_dist(p):
    return g.project_to_polyline(ROUTE, p)[0]


def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def xz(inst):
    return (inst["x"], inst["z"])


def reach(inst):
    n, x, z, yaw, s = inst["name"], inst["x"], inst["z"], inst["rotation_y_deg"], inst["scale"]
    if n == "VL_AshShrine":
        return g.rect_poly(x, z, SHRINE_HALF[0], SHRINE_HALF[1], yaw)
    radius = {"VL_BasaltColumn": COLUMN_R, "VL_Vent": VENT_R, "VL_CoolStone": STONE_R, "VL_CharredTree": TREE_R,
              "VL_CrustPlate": PLATE_R, "VL_ObsidianShard": SHARD_R}[n]
    return g.Circle(x, z, radius * s)


def seg_heading(index):
    (ax, az), (bx, bz) = ROUTE[index], ROUTE[index + 1]
    return g.heading_deg(bx - ax, bz - az)


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def local_to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def gather_point(inst):
    return local_to_world(inst, 0.0, SHARD_GATHER * inst["scale"])


def route_vents(layout):
    return sorted([v for v in layout["hazards"]["vents"] if v["role"] == "route"], key=lambda v: v["route_arc"])


def vent_inst(layout, vent):
    return next(i for i in layout["instances"] if i["id"] == vent["id"])


def erupt_window(phase):
    return (phase + CALM + GLOW, phase + CYCLE)


def windows_clear(p1, p2, margin):
    a0, a1 = erupt_window(p1)
    for shift in (-CYCLE, 0.0, CYCLE):
        b0, b1 = erupt_window(p2)
        b0, b1 = b0 + shift, b1 + shift
        if b0 < a1 + margin and a0 < b1 + margin:
            return False
    return True


class RuleChecks:
    layout = None

    def solids(self):
        return [i for i in self.layout["instances"] if i["name"] != "VL_Vent"]

    def discs(self):
        return [g.Circle(i["x"], i["z"], RADIUS) for i in by_name(self.layout, "VL_Vent")]

    def check_schema(self):
        layout = self.layout
        for key in ("name", "status", "seed", "instances", "totals", "route", "caps", "hazards", "density",
                    "decisions"):
            self.assertIn(key, layout)
        self.assertIn("unvalidated", layout["status"])
        self.assertIn("draft", layout["status"])
        ids = [i["id"] for i in layout["instances"]]
        self.assertEqual(len(ids), len(set(ids)))
        for inst in layout["instances"]:
            for key in ("id", "name", "x", "z", "rotation_y_deg", "scale"):
                self.assertIn(key, inst)
            self.assertIn(inst["name"], MIX)
            self.assertTrue(all(math.isfinite(inst[k]) for k in ("x", "z", "rotation_y_deg", "scale")))
        self.assertGreaterEqual(len(layout["decisions"]), 5)

    def check_counts_and_budgets(self):
        names = [i["name"] for i in self.layout["instances"]]
        for name, count in MIX.items():
            self.assertEqual(names.count(name), count, name)
        total = len(names)
        self.assertEqual(total, 190)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], sum(PARTS[n] for n in names))
        self.assertEqual(totals["mesh_parts"], 280)
        self.assertEqual(budget, 25540)
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
        for vent in self.layout["hazards"]["vents"]:
            self.assertLessEqual(max(abs(vent["x"]), abs(vent["z"])) + RADIUS, 200.0, vent["id"])

    def check_route(self):
        route = self.layout["route"]
        self.assertEqual([tuple(p) for p in route["nodes"]], ROUTE)
        self.assertEqual(len(route["names"]), len(ROUTE))
        length = g.polyline_length(ROUTE)
        self.assertAlmostEqual(route["length"], length, delta=0.5)
        self.assertAlmostEqual(route["walk_seconds"], length / WALK_SPEED, delta=0.1)
        self.assertEqual(route["corridor_width"], 14.0)
        self.assertGreaterEqual(length, 500.0)
        for node in (ROUTE[0], ROUTE[-1]):
            self.assertGreaterEqual(max(abs(node[0]), abs(node[1])), 190.0)

    def check_corridor_clearance(self):
        for inst in self.solids():
            if inst["name"] == "VL_AshShrine":
                continue
            gap = g.shape_polyline_dist(reach(inst), ROUTE)
            self.assertGreaterEqual(gap, CORRIDOR_HALF + BASE_GAP - 1e-6, inst["id"])

    def check_shrines_straddle_the_route(self):
        shrines = by_name(self.layout, "VL_AshShrine")
        self.assertEqual(len(shrines), 2)
        self.assertLessEqual(SHRINE_PASSAGE[0], -CORRIDOR_HALF)
        self.assertGreaterEqual(SHRINE_PASSAGE[1], CORRIDOR_HALF)
        self.assertLess(abs(SHRINE_PASSAGE[0] + SHRINE_PASSAGE[1]) / 2, 0.5, "measured gap is centred on the pivot")
        for inst in shrines:
            distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005)
            self.assertEqual(inst["scale"], 1)
            a, b = ROUTE[index], ROUTE[index + 1]
            self.assertGreaterEqual(min(math.dist(xz(inst), a), math.dist(xz(inst), b)), SHRINE_HALF[1] + 1.0)
        arcs = sorted(g.project_to_polyline(ROUTE, xz(s))[1] for s in shrines)
        self.assertLessEqual(arcs[0], 60.0, "one shrine near the entry gate")
        self.assertGreaterEqual(arcs[1], g.polyline_length(ROUTE) - 60.0, "one shrine near the exit gate")

    def check_vent_cycle(self):
        cycle = self.layout["hazards"]["vent_cycle"]
        self.assertEqual((cycle["calm_s"], cycle["glow_s"], cycle["erupt_s"], cycle["radius"]),
                         (CALM, GLOW, ERUPT, RADIUS))
        self.assertAlmostEqual(cycle["cycle_s"], CYCLE)
        self.assertGreaterEqual(GLOW, 2 * RADIUS / WALK_SPEED, "a glow is long enough to cross the whole disc")

    def check_vents(self):
        vents = self.layout["hazards"]["vents"]
        self.assertEqual(len(vents), 14)
        insts = by_name(self.layout, "VL_Vent")
        self.assertEqual({v["id"] for v in vents}, {i["id"] for i in insts})
        self.assertEqual(len(route_vents(self.layout)), ROUTE_VENTS)
        self.assertEqual(len([v for v in vents if v["role"] == "flank"]), FLANK_VENTS)
        for inst in insts:
            self.assertEqual(inst["scale"], 1, "tiny: the vent stays at its measured 3.0 height (N1)")
        nodes_arc = [0.0]
        for a, b in zip(ROUTE, ROUTE[1:]):
            nodes_arc.append(nodes_arc[-1] + math.dist(a, b))
        for v in vents:
            inst = vent_inst(self.layout, v)
            distance, arc, _, lateral = g.project_to_polyline(ROUTE, xz(inst))
            self.assertEqual(v["phase_s"] % 0.25, 0.0)
            self.assertGreaterEqual(v["phase_s"], 0.0)
            self.assertLess(v["phase_s"], CYCLE)
            if v["role"] == "route":
                self.assertLessEqual(abs(lateral), 4.0, v["id"])
                self.assertAlmostEqual(v["route_arc"], arc, delta=0.05)
                for node_arc in nodes_arc:
                    self.assertGreaterEqual(abs(arc - node_arc), RADIUS + 2.0, "whole disc on a straight stretch")
            else:
                self.assertGreaterEqual(distance, CORRIDOR_HALF + RADIUS + BASE_GAP - 1e-6, "flank disc never reaches the trail")
        rv = route_vents(self.layout)
        for a, b in zip(rv, rv[1:]):
            self.assertGreaterEqual(b["route_arc"] - a["route_arc"], 2 * RADIUS + 16.0, "16 studs of clear route between discs")
            self.assertTrue(windows_clear(a["phase_s"], b["phase_s"], 1.0),
                            "neighbouring route vents never erupt together: %s %s" % (a["id"], b["id"]))
        all_vents = by_name(self.layout, "VL_Vent")
        for i, a in enumerate(all_vents):
            for b in all_vents[i + 1:]:
                self.assertGreaterEqual(math.dist(xz(a), xz(b)), 2 * RADIUS + 2.0, f"{a['id']} {b['id']}")

    def check_disc_keepout(self):
        for solid in self.solids():
            for disc in self.discs():
                self.assertGreaterEqual(g.shape_gap(reach(solid), disc), BASE_GAP - 1e-6, solid["id"])

    def check_refuges(self):
        stones = by_name(self.layout, "VL_CoolStone")
        self.assertEqual(len(stones), 40)
        for v in route_vents(self.layout):
            near = []
            for s in stones:
                _, arc, _, lateral = g.project_to_polyline(ROUTE, xz(s))
                if 14.5 <= abs(arc - v["route_arc"]) <= 21.0 and 10.5 <= abs(lateral) <= 13.5:
                    near.append((arc - v["route_arc"], lateral))
            self.assertEqual(len(near), 4, "four refuge stones per route vent: " + v["id"])
            self.assertEqual({(a > 0, l > 0) for a, l in near}, {(True, True), (True, False), (False, True),
                                                                  (False, False)})
        for s in stones:
            self.assertEqual(s["scale"], 1)

    def check_sight_lanes(self):
        occluders = [reach(i) for i in by_name(self.layout, "VL_BasaltColumn", "VL_CharredTree", "VL_AshShrine")]
        lanes = self.layout["hazards"]["sight_lanes"]
        self.assertEqual(len(lanes), ROUTE_VENTS)
        for v in route_vents(self.layout):
            start = g.polyline_point(ROUTE, max(0.0, v["route_arc"] - SIGHT_LEAD))[0]
            for shape in occluders:
                self.assertGreaterEqual(g.shape_segment_dist(shape, start, (v["x"], v["z"])), 1.0 - 1e-6, v["id"])
        self.assertEqual(self.layout["density"]["route_vents_in_clear_view"], ROUTE_VENTS)

    def check_columns_trees_plates(self):
        for inst in by_name(self.layout, "VL_BasaltColumn"):
            self.assertGreaterEqual(inst["scale"], 0.85 - 1e-9)
            self.assertLessEqual(inst["scale"], 1.15 + 1e-9)
        self.assertEqual(len(by_name(self.layout, "VL_CharredTree")), 36)
        plates = by_name(self.layout, "VL_CrustPlate")
        self.assertEqual(len(plates), 20)
        for inst in plates:
            self.assertEqual(inst["scale"], 1)
            self.assertGreaterEqual(route_dist(xz(inst)), 30.0, "crust fields sit away from the trail")

    def check_shards(self):
        shards = by_name(self.layout, "VL_ObsidianShard")
        self.assertEqual(len(shards), 18)
        flank = [xz(vent_inst(self.layout, v)) for v in self.layout["hazards"]["vents"] if v["role"] == "flank"]
        edge = route_side = 0
        for inst in shards:
            point = gather_point(inst)
            for solid in self.solids():
                if solid["id"] != inst["id"]:
                    self.assertGreater(g.shape_point_dist(reach(solid), point), 0.0, f"{inst['id']} / {solid['id']}")
            if min(math.dist(point, c) for c in flank) <= 13.0:
                edge += 1
                self.assertGreaterEqual(min(math.dist(point, c) for c in flank), 10.5, "gathering never stands in a disc")
            else:
                route_side += 1
                distance = route_dist(point)
                self.assertGreaterEqual(distance, 8.0, inst["id"])
                self.assertLessEqual(distance, 40.0, inst["id"])
                self.assertLess(distance, route_dist(xz(inst)), "the gather side faces the trail")
            for disc in self.discs():
                self.assertGreaterEqual(g.shape_point_dist(disc, point), 0.5)
        self.assertEqual(edge, 6, "six risk shards beside the flank vents")
        self.assertEqual(route_side, 12)

    def check_no_solid_overlaps(self):
        solids = self.solids()
        shapes = {i["id"]: reach(i) for i in solids}
        for a_index, a in enumerate(solids):
            for b in solids[a_index + 1:]:
                needed = 0.5 if a["name"] == b["name"] == "VL_CrustPlate" else BASE_GAP
                self.assertGreaterEqual(g.shape_gap(shapes[a["id"]], shapes[b["id"]]), needed - 1e-6,
                                        f"{a['id']} and {b['id']}")

    def check_everything(self):
        self.check_schema()
        self.check_counts_and_budgets()
        self.check_inside_the_sector()
        self.check_route()
        self.check_corridor_clearance()
        self.check_shrines_straddle_the_route()
        self.check_vent_cycle()
        self.check_vents()
        self.check_disc_keepout()
        self.check_refuges()
        self.check_sight_lanes()
        self.check_columns_trees_plates()
        self.check_shards()
        self.check_no_solid_overlaps()


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

    def test_corridor_clearance(self):
        self.check_corridor_clearance()

    def test_shrines_straddle_the_route(self):
        self.check_shrines_straddle_the_route()

    def test_vent_cycle(self):
        self.check_vent_cycle()

    def test_vents(self):
        self.check_vents()

    def test_disc_keepout(self):
        self.check_disc_keepout()

    def test_refuges(self):
        self.check_refuges()

    def test_sight_lanes(self):
        self.check_sight_lanes()

    def test_columns_trees_plates(self):
        self.check_columns_trees_plates()

    def test_shards(self):
        self.check_shards()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_measured_values_match_the_kit_report_and_geometry(self):
        report_path = KIT_DIR / "volcanic-lands-kit-report.json"
        geometry_path = KIT_DIR / "volcanic-lands-kit-geometry.json"
        if not (report_path.exists() and geometry_path.exists()):
            self.skipTest("kit artifacts not built")
        props = json.loads(report_path.read_text(encoding="utf-8"))["props"]
        dump = json.loads(geometry_path.read_text(encoding="utf-8"))
        for name, tris in MEASURED_TRIS.items():
            self.assertEqual(props[name]["triangles"], tris, name)
            self.assertEqual(len(props[name]["parts"]), PARTS[name], name)
            self.assertLessEqual(tris, BUDGET_TRIS[name])

        def points(name):
            return [v for part in dump[name]["parts"].values() for v in part["vertices"]]

        for name, wanted in (("VL_BasaltColumn", COLUMN_R), ("VL_Vent", VENT_R), ("VL_CoolStone", STONE_R),
                             ("VL_CharredTree", TREE_R), ("VL_CrustPlate", PLATE_R), ("VL_ObsidianShard", SHARD_R)):
            self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in points(name)), wanted, name)
        shrine = points("VL_AshShrine")
        self.assertLessEqual(max(abs(v[0]) for v in shrine), SHRINE_HALF[0])
        self.assertLessEqual(max(abs(v[1]) for v in shrine), SHRINE_HALF[1])
        clearance = props["VL_AshShrine"]["clearance"]
        self.assertAlmostEqual(clearance["gap_low_x"], SHRINE_PASSAGE[0], delta=0.01)
        self.assertAlmostEqual(clearance["gap_high_x"], SHRINE_PASSAGE[1], delta=0.01)
        self.assertEqual(props["VL_ObsidianShard"]["gather_point"][1], SHARD_GATHER)
        self.assertLessEqual(props["VL_Vent"]["size"][2] * 1.0, 3.3, "tiny (N1)")

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 190)
        self.assertLessEqual(totals["triangles_measured"], MAX_TRIANGLES)
        self.assertEqual(totals["triangles_measured"], 22144)
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
            self.assertIn("DRAFT", Path(tmp, plan.LAYOUT_NAME + ".svg").read_text(encoding="utf-8"))


class AlternateSeeds(RuleChecks, unittest.TestCase):
    def test_every_rule_holds_for_other_seeds(self):
        for seed in ALT_SEEDS:
            with self.subTest(seed=seed):
                self.layout = json.loads(plan.to_json(plan.generate(seed)))
                self.check_everything()


if __name__ == "__main__":
    unittest.main()
