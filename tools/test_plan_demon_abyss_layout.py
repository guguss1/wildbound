"""Contracts for the Demon Abyss top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_demon_abyss_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. Prop sizes are the measured Blender kit values
(assets/blender/demon-abyss-kit). Nothing here was imported into Roblox, played or measured on a
device. Kit frame to plan frame: local x = -Blender x, local z = Blender y.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_demon_abyss_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_DIR = REPO / "assets/blender/demon-abyss-kit"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 300.0, 145.0
MAX_INSTANCES, MAX_TRIANGLES = 120, 25000
MIX = {"DA_FissureLip": 24, "DA_FloatRock": 30, "DA_ThornSpire": 30, "DA_RiftGate": 2, "DA_RiftShard": 14,
       "DA_CalmStone": 6}
BUDGET_TRIS = {"DA_FissureLip": 240, "DA_FloatRock": 180, "DA_ThornSpire": 200, "DA_RiftGate": 560,
               "DA_RiftShard": 100, "DA_CalmStone": 140}
MEASURED_TRIS = {"DA_FissureLip": 210, "DA_FloatRock": 124, "DA_ThornSpire": 182, "DA_RiftGate": 406,
                 "DA_RiftShard": 88, "DA_CalmStone": 108}
PARTS = {"DA_FissureLip": 2, "DA_FloatRock": 2, "DA_ThornSpire": 1, "DA_RiftGate": 2, "DA_RiftShard": 2,
         "DA_CalmStone": 2}
ROUTE = [(-140, 125), (10, 125), (130, 10), (-10, -60), (-50, -142)]
CORRIDOR_HALF = 7.0
WALK_SPEED = 16.0
BASE_GAP = 1.0
# Traversal rule (bible section 2): rocks sink 1 stud/s while occupied, up to 6 s (night 1.5 studs/s).
SINK_DAY, SINK_NIGHT, SINK_MAX_S = 1.0, 1.5, 6.0
CHASMS, ROCKS_PER_CHASM = 3, 6
ROCK_STEP = 13.0
ROCK_HULL = ((-5.2, 2.86), (-5.1, -1.81), (-3.12, -5.1), (1.64, -5.15), (3.93, -3.38), (5.74, -1.51), (6.8, 0.11),
             (5.39, 4.58), (2.09, 6.85), (-3.18, 5.82))
ROCK_WALK_BOX = 6.96
LIP_BOX = ((-9.8, -5.35), (10.1, -5.35), (10.1, 4.85), (-9.8, 4.85))
GATE_HALF = (14.5, 4.05)
GATE_PASSAGE = (-8.4074, 7.3572)
SPIRE_R, SHARD_R, CALM_R = 5.4, 3.5, 3.3
SHARD_GATHER = -2.5
NIGHT_ONLY_SHARDS = 6
ALT_SEEDS = (11, 4242)


# ---- Independent helpers -----------------------------------------------------
def route_dist(p):
    return g.project_to_polyline(ROUTE, p)[0]


def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def xz(inst):
    return (inst["x"], inst["z"])


def to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def reach(inst):
    n, s = inst["name"], inst["scale"]
    if n == "DA_FloatRock":
        return g.Poly(tuple(to_world(inst, a, b) for a, b in ROCK_HULL))
    if n == "DA_FissureLip":
        return g.Poly(tuple(to_world(inst, a, b) for a, b in LIP_BOX))
    if n == "DA_RiftGate":
        return g.rect_poly(inst["x"], inst["z"], GATE_HALF[0], GATE_HALF[1], inst["rotation_y_deg"])
    radius = {"DA_ThornSpire": SPIRE_R, "DA_RiftShard": SHARD_R, "DA_CalmStone": CALM_R}[n]
    return g.Circle(inst["x"], inst["z"], radius * s)


def seg_heading(index):
    (ax, az), (bx, bz) = ROUTE[index], ROUTE[index + 1]
    return g.heading_deg(bx - ax, bz - az)


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def gather_point(inst):
    return to_world(inst, 0.0, SHARD_GATHER * inst["scale"])


def chasm_poly(chasm):
    return g.Poly(tuple(map(tuple, chasm["polygon"])))


class RuleChecks:
    layout = None

    def solids(self):
        return [i for i in self.layout["instances"]]

    def chasms(self):
        return self.layout["hazards"]["chasms"]

    def route_rocks(self):
        ids = {r for c in self.chasms() for r in c["route_rock_ids"]}
        return [i for i in by_name(self.layout, "DA_FloatRock") if i["id"] in ids]

    def decoy_rocks(self):
        ids = {r for c in self.chasms() for r in c["route_rock_ids"]}
        return [i for i in by_name(self.layout, "DA_FloatRock") if i["id"] not in ids]

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
        self.assertEqual(total, 106)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], sum(PARTS[n] for n in names))
        self.assertEqual(totals["mesh_parts"], 182)
        self.assertEqual(budget, 20520)
        self.assertLessEqual(measured, budget)
        self.assertLessEqual(budget, MAX_TRIANGLES)
        for name, entry in totals["by_name"].items():
            self.assertEqual(entry["count"], MIX[name])
            self.assertEqual(entry["triangles"], MIX[name] * MEASURED_TRIS[name])

    def check_inside_the_sector(self):
        for inst in self.layout["instances"]:
            x0, z0, x1, z1 = g.shape_bbox(reach(inst))
            self.assertGreaterEqual(min(x0, z0), -LIMIT - 1e-6, inst["id"])
            self.assertLessEqual(max(x1, z1), LIMIT + 1e-6, inst["id"])
        for chasm in self.chasms():
            for x, z in chasm["polygon"]:
                self.assertLessEqual(max(abs(x), abs(z)), LIMIT + 0.01)

    def check_route(self):
        route = self.layout["route"]
        self.assertEqual([tuple(p) for p in route["nodes"]], ROUTE)
        self.assertEqual(len(route["names"]), len(ROUTE))
        length = g.polyline_length(ROUTE)
        self.assertAlmostEqual(route["length"], length, delta=0.5)
        self.assertAlmostEqual(route["walk_seconds"], length / WALK_SPEED, delta=0.1)
        self.assertEqual(route["corridor_width"], 14.0)
        self.assertGreaterEqual(length, 450.0)
        for node in (ROUTE[0], ROUTE[-1]):
            self.assertGreaterEqual(max(abs(node[0]), abs(node[1])), 140.0)

    def check_chasms(self):
        chasms = self.chasms()
        self.assertEqual(len(chasms), CHASMS)
        arcs = []
        for chasm in chasms:
            poly = chasm_poly(chasm)
            self.assertEqual(len(poly.pts), 4)
            centre, direction, index = g.polyline_point(ROUTE, chasm["route_arc"])
            self.assertTrue(g.point_in_polygon(poly.pts, centre))
            along = chasm["along_length"]
            self.assertGreaterEqual(along, (ROCKS_PER_CHASM - 1) * ROCK_STEP + 12.0 + 6.0)
            for sign in (-1, 1):
                end = g.polyline_point(ROUTE, chasm["route_arc"] + sign * along / 2)
                self.assertEqual(end[2], index, "the crossing lies on one straight stretch")
                self.assertTrue(g.point_in_polygon(poly.pts, (end[0][0] - sign * direction[0] * 0.5,
                                                              end[0][1] - sign * direction[1] * 0.5)))
            self.assertGreaterEqual(chasm["lateral_min"], -200.0)
            self.assertLessEqual(chasm["lateral_min"], -CORRIDOR_HALF - 12.0)
            self.assertGreaterEqual(chasm["lateral_max"], CORRIDOR_HALF + 12.0)
            arcs.append(chasm["route_arc"])
        arcs.sort()
        self.assertTrue(all(b - a >= 120.0 for a, b in zip(arcs, arcs[1:])))
        polys = [chasm_poly(c) for c in chasms]
        for i, a in enumerate(polys):
            for b in polys[i + 1:]:
                self.assertGreaterEqual(g.shape_gap(a, b), 6.0, "chasms never run into each other")

    def check_route_rocks(self):
        rocks = self.route_rocks()
        self.assertEqual(len(rocks), CHASMS * ROCKS_PER_CHASM)
        for chasm in self.chasms():
            chain = [i for i in rocks if i["id"] in chasm["route_rock_ids"]]
            self.assertEqual(len(chain), ROCKS_PER_CHASM)
            poly = chasm_poly(chasm)
            arcs = []
            for inst in chain:
                distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
                self.assertLess(distance, 0.01, inst["id"])
                self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005, inst["id"])
                self.assertEqual(inst["scale"], 1)
                for p in reach(inst).pts:
                    self.assertTrue(g.point_in_polygon(poly.pts, p), inst["id"] + " stays inside the chasm")
                arcs.append(arc)
            arcs.sort()
            steps = [b - a for a, b in zip(arcs, arcs[1:])]
            self.assertTrue(all(abs(s - ROCK_STEP) < 0.01 for s in steps), steps)
            self.assertLessEqual(ROCK_STEP - ROCK_WALK_BOX, 6.5, "the hop between walk boxes stays short")
            self.assertAlmostEqual(chasm["hop_gap"], ROCK_STEP - ROCK_WALK_BOX, delta=0.01)
            self.assertAlmostEqual(arcs[0] + (arcs[-1] - arcs[0]) / 2, chasm["route_arc"], delta=0.05)

    def check_decoy_rocks(self):
        decoys = self.decoy_rocks()
        self.assertEqual(len(decoys), 12)
        polys = [chasm_poly(c) for c in self.chasms()]
        for inst in decoys:
            shape = reach(inst)
            self.assertGreaterEqual(g.shape_polyline_dist(shape, ROUTE), CORRIDOR_HALF + BASE_GAP - 1e-6, inst["id"])
            self.assertTrue(any(all(g.point_in_polygon(p.pts, q) for q in shape.pts) for p in polys), inst["id"])

    def check_sinking(self):
        sink = self.layout["hazards"]["rock_sink"]
        self.assertEqual((sink["rate_day"], sink["rate_night"], sink["max_occupied_s"]), (SINK_DAY, SINK_NIGHT, SINK_MAX_S))
        dwell = ROCK_STEP / WALK_SPEED
        self.assertAlmostEqual(sink["dwell_s_walking"], dwell, delta=0.01)
        self.assertLess(dwell * SINK_NIGHT, 0.25 * 6.0, "a walker sinks under a quarter of the rock height at night")
        self.assertAlmostEqual(sink["night_depth_per_rock"], dwell * SINK_NIGHT, delta=0.01)

    def check_corridor_clearance(self):
        route_rocks = {i["id"] for i in self.route_rocks()}
        for inst in self.solids():
            if inst["name"] == "DA_RiftGate" or inst["id"] in route_rocks:
                continue
            gap = g.shape_polyline_dist(reach(inst), ROUTE)
            self.assertGreaterEqual(gap, CORRIDOR_HALF + BASE_GAP - 1e-6, inst["id"])

    def check_gates_straddle_the_route(self):
        gates = by_name(self.layout, "DA_RiftGate")
        self.assertEqual(len(gates), 2)
        self.assertLessEqual(GATE_PASSAGE[0], -CORRIDOR_HALF)
        self.assertGreaterEqual(GATE_PASSAGE[1], CORRIDOR_HALF)
        for inst in gates:
            distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005)
            self.assertEqual(inst["scale"], 1)
            a, b = ROUTE[index], ROUTE[index + 1]
            self.assertGreaterEqual(min(math.dist(xz(inst), a), math.dist(xz(inst), b)), GATE_HALF[1] + 1.0)
        arcs = sorted(g.project_to_polyline(ROUTE, xz(s))[1] for s in gates)
        self.assertLessEqual(arcs[0], 30.0, "one gate near the entry")
        self.assertGreaterEqual(arcs[1], g.polyline_length(ROUTE) - 30.0, "one gate near the exit")

    def check_lips(self):
        lips = by_name(self.layout, "DA_FissureLip")
        self.assertEqual(len(lips), 24)
        polys = [chasm_poly(c) for c in self.chasms()]
        for inst in lips:
            shape = reach(inst)
            gaps = [g.shape_gap(shape, p) for p in polys]
            self.assertGreaterEqual(min(gaps), 0.0)
            front_edge = to_world(inst, 0.0, 4.85)
            rim_distances = []
            for poly in polys:
                for a, b in ((poly.pts[3], poly.pts[0]), (poly.pts[1], poly.pts[2])):
                    length = math.dist(a, b)
                    rim_distances.append(abs((b[0] - a[0]) * (a[1] - front_edge[1]) - (a[0] - front_edge[0]) * (b[1] - a[1])) / length)
            self.assertLessEqual(min(rim_distances), 0.5, "a lip stands on the rim line, which the bank edge continues")
            self.assertTrue(all(not g.point_in_polygon(p.pts, q) for p in polys for q in shape.pts),
                            "the lip body stays on the bank")
            # The breaking edge (local +Z) faces the chasm centre.
            chasm = polys[gaps.index(min(gaps))]
            front = to_world(inst, 0.0, 6.0)
            back = to_world(inst, 0.0, -6.0)
            self.assertLess(g.shape_point_dist(chasm, front), g.shape_point_dist(chasm, back), inst["id"])
        per = {}
        for chasm in self.chasms():
            for lip_id in chasm["lip_ids"]:
                per[lip_id] = per.get(lip_id, 0) + 1
            self.assertGreaterEqual(len(chasm["lip_ids"]), 6, "each chasm keeps most of its eight")
            self.assertLessEqual(len(chasm["lip_ids"]), 10)
        self.assertEqual(sorted(per), sorted(i["id"] for i in lips))

    def check_calm_stones(self):
        calm = by_name(self.layout, "DA_CalmStone")
        self.assertEqual(len(calm), 6)
        for chasm in self.chasms():
            poly = chasm_poly(chasm)
            before = after = 0
            for inst in calm:
                _, arc, _, lateral = g.project_to_polyline(ROUTE, xz(inst))
                offset = arc - chasm["route_arc"]
                half = chasm["along_length"] / 2
                if half + 6.0 <= offset <= half + 24.0 and 9.0 <= abs(lateral) <= 14.0:
                    after += 1
                if -(half + 24.0) <= offset <= -(half + 6.0) and 9.0 <= abs(lateral) <= 14.0:
                    before += 1
            self.assertEqual((before, after), (1, 1), "one rest stone on each bank")
            for inst in calm:
                self.assertFalse(g.point_in_polygon(poly.pts, xz(inst)))

    def check_spires(self):
        spires = by_name(self.layout, "DA_ThornSpire")
        self.assertEqual(len(spires), 30)
        polys = [chasm_poly(c) for c in self.chasms()]
        inside = [s for s in spires if any(g.point_in_polygon(p.pts, xz(s)) for p in polys)]
        self.assertGreaterEqual(len(inside), 10, "thorns rise out of the drop")
        for inst in spires:
            self.assertGreaterEqual(inst["scale"], 0.9 - 1e-9)
            self.assertLessEqual(inst["scale"], 1.15 + 1e-9)

    def check_shards(self):
        shards = by_name(self.layout, "DA_RiftShard")
        self.assertEqual(len(shards), 14)
        polys = [chasm_poly(c) for c in self.chasms()]
        night = [i for i in shards if i.get("night_only")]
        self.assertEqual(len(night), NIGHT_ONLY_SHARDS)
        for inst in shards:
            point = gather_point(inst)
            distance = route_dist(point)
            self.assertGreaterEqual(distance, 8.0, inst["id"])
            self.assertLessEqual(distance, 40.0, inst["id"])
            self.assertLess(distance, route_dist(xz(inst)), "the gather side faces the trail")
            for solid in self.solids():
                if solid["id"] != inst["id"]:
                    self.assertGreater(g.shape_point_dist(reach(solid), point), 0.0, f"{inst['id']} / {solid['id']}")
            self.assertFalse(any(g.point_in_polygon(p.pts, point) for p in polys), "a shard stands on solid ground")

    def check_no_solid_overlaps(self):
        solids = self.solids()
        shapes = {i["id"]: reach(i) for i in solids}
        for a_index, a in enumerate(solids):
            for b in solids[a_index + 1:]:
                self.assertGreaterEqual(g.shape_gap(shapes[a["id"]], shapes[b["id"]]), BASE_GAP - 1e-6,
                                        f"{a['id']} and {b['id']}")

    def check_everything(self):
        self.check_schema()
        self.check_counts_and_budgets()
        self.check_inside_the_sector()
        self.check_route()
        self.check_chasms()
        self.check_route_rocks()
        self.check_decoy_rocks()
        self.check_sinking()
        self.check_corridor_clearance()
        self.check_gates_straddle_the_route()
        self.check_lips()
        self.check_calm_stones()
        self.check_spires()
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

    def test_chasms(self):
        self.check_chasms()

    def test_route_rocks(self):
        self.check_route_rocks()

    def test_decoy_rocks(self):
        self.check_decoy_rocks()

    def test_sinking(self):
        self.check_sinking()

    def test_corridor_clearance(self):
        self.check_corridor_clearance()

    def test_gates_straddle_the_route(self):
        self.check_gates_straddle_the_route()

    def test_lips(self):
        self.check_lips()

    def test_calm_stones(self):
        self.check_calm_stones()

    def test_spires(self):
        self.check_spires()

    def test_shards(self):
        self.check_shards()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_measured_values_match_the_kit_report_and_geometry(self):
        report_path = KIT_DIR / "demon-abyss-kit-report.json"
        geometry_path = KIT_DIR / "demon-abyss-kit-geometry.json"
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

        for name, wanted in (("DA_ThornSpire", SPIRE_R), ("DA_RiftShard", SHARD_R), ("DA_CalmStone", CALM_R)):
            self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in points(name)), wanted, name)
        gate = points("DA_RiftGate")
        self.assertLessEqual(max(abs(v[0]) for v in gate), GATE_HALF[0])
        self.assertLessEqual(max(abs(v[1]) for v in gate), GATE_HALF[1])
        clearance = props["DA_RiftGate"]["clearance"]
        self.assertAlmostEqual(clearance["gap_low_x"], GATE_PASSAGE[0], delta=0.01)
        self.assertAlmostEqual(clearance["gap_high_x"], GATE_PASSAGE[1], delta=0.01)
        self.assertEqual(props["DA_RiftShard"]["gather_point"][1], SHARD_GATHER)
        # The float-rock hull is rebuilt from the vertices: every vertex lies inside it.
        hull = g.Poly(ROCK_HULL)
        for v in points("DA_FloatRock"):
            self.assertLessEqual(g.shape_point_dist(hull, (-v[0], v[1])), 0.011)
        walk = props["DA_FloatRock"]["collision_boxes"][0]
        self.assertAlmostEqual(walk["size"][0], ROCK_WALK_BOX, delta=0.01)
        lip = points("DA_FissureLip")
        self.assertLessEqual(max(abs(-v[0] - 0.15) for v in lip), (LIP_BOX[1][0] - LIP_BOX[0][0]) / 2 + 0.01)
        self.assertGreaterEqual(min(v[1] for v in lip), LIP_BOX[0][1])
        self.assertLessEqual(max(v[1] for v in lip), LIP_BOX[2][1])

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 106)
        self.assertLessEqual(totals["triangles_measured"], MAX_TRIANGLES)
        self.assertEqual(totals["triangles_measured"], 16912)
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
            svg = Path(tmp, plan.LAYOUT_NAME + ".svg").read_text(encoding="utf-8")
            self.assertIn("<svg", svg)
            self.assertIn("DRAFT", svg)


class AlternateSeeds(RuleChecks, unittest.TestCase):
    def test_every_rule_holds_for_other_seeds(self):
        for seed in ALT_SEEDS:
            with self.subTest(seed=seed):
                self.layout = json.loads(plan.to_json(plan.generate(seed)))
                self.check_everything()


if __name__ == "__main__":
    unittest.main()
