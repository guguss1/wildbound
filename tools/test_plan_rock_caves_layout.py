"""Contracts for the Rock and Caves top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_rock_caves_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. In particular the tunnel chain is re-walked from the
measured end rings: every joint must meet within the 0.02 snap tolerance with opposite facings.
Prop sizes are the measured Blender kit values (assets/blender/rock-caves-kit). Nothing here was
imported into Roblox, played or measured on a device. Kit frame to plan frame: local x = -Blender
x, local z = Blender y.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_rock_caves_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_DIR = REPO / "assets/blender/rock-caves-kit"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 300.0, 145.0
MAX_INSTANCES, MAX_TRIANGLES = 130, 28000
MIX = {"RC_CaveMouth": 3, "RC_TunnelStraight": 18, "RC_TunnelBend": 8, "RC_Stalagmite": 40, "RC_CrystalCluster": 16,
       "RC_OreVein": 14, "RC_Burrow": 12}
BUDGET_TRIS = {"RC_CaveMouth": 640, "RC_TunnelStraight": 420, "RC_TunnelBend": 480, "RC_Stalagmite": 90,
               "RC_CrystalCluster": 140, "RC_OreVein": 180, "RC_Burrow": 120}
MEASURED_TRIS = {"RC_CaveMouth": 526, "RC_TunnelStraight": 406, "RC_TunnelBend": 406, "RC_Stalagmite": 90,
                 "RC_CrystalCluster": 134, "RC_OreVein": 160, "RC_Burrow": 92}
PARTS = {"RC_CaveMouth": 3, "RC_TunnelStraight": 2, "RC_TunnelBend": 2, "RC_Stalagmite": 1, "RC_CrystalCluster": 2,
         "RC_OreVein": 2, "RC_Burrow": 2}
OCCLUDER_COUNT = {"RC_CaveMouth": 2, "RC_TunnelStraight": 2, "RC_TunnelBend": 24}
COLLISION_COUNT = {"RC_TunnelStraight": 1, "RC_TunnelBend": 24}
TUNNELS = {"A": {"string": "SSSLSSSLSRRSS", "start": (-92.0, 100.0), "dir": (1.0, 0.0)},
           "B": {"string": "RSSSRSSLLSSSS", "start": (96.0, -44.0), "dir": (1.0, 0.0)}}
CORRIDOR_HALF = 7.0
WALK_SPEED = 16.0
BASE_GAP = 1.0
SNAP_TOLERANCE = 0.02
# Measured end rings in Blender axes: centre and outward facing; shared tunnel profile (bible 5.5).
ENDS = {"RC_TunnelStraight": {"A": ((0.0, -12.0), (0.0, -1.0)), "B": ((0.0, 12.0), (0.0, 1.0))},
        "RC_TunnelBend": {"A": ((-3.0, -15.0), (0.0, -1.0)), "B": ((15.0, 3.0), (1.0, 0.0))}}
PROFILE = [(-7.0, 0.0), (-7.0, 10.0), (-5.0, 12.0), (5.0, 12.0), (7.0, 10.0), (7.0, 0.0), (12.0, 0.0), (12.0, 12.0),
           (7.0, 18.0), (-7.0, 18.0), (-12.0, 12.0), (-12.0, 0.0)]
BEND_CENTRE_LOCAL, BEND_RADIUS = (-15.0, -15.0), 18.0
STRAIGHT_HALF = (12.83, 12.0)
BEND_WEDGE = (5.7, 31.0 / math.cos(math.radians(7.5)))
MOUTH_BACK, MOUTH_FRONT = 7.7733, 7.4867
MOUTH_HALF_X = 18.1
MOUTH_PASSAGE = (-8.1, 8.1)
# Rockfall (bible section 2): dust 3 s, then rocks land in a strip 10 studs wide for 2 s.
DUST_S, IMPACT_S, STRIP = 3.0, 2.0, 10.0
LANES = 4
RADIUS = {"RC_Stalagmite": 3.3, "RC_CrystalCluster": 3.6, "RC_OreVein": 4.1, "RC_Burrow": 3.8}
GATHER_LOCAL = {"RC_CrystalCluster": -3.0, "RC_OreVein": -2.5}
SCALE_RANGE = {"RC_Stalagmite": (0.9, 1.15), "RC_CrystalCluster": (0.9, 1.2), "RC_OreVein": (0.9, 1.15),
               "RC_Burrow": (0.9, 1.1)}
ALT_SEEDS = (11, 4242)


# ---- Independent helpers -----------------------------------------------------
def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def xz(inst):
    return (inst["x"], inst["z"])


def to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def vec_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (local_x * math.cos(r) + local_z * math.sin(r), -local_x * math.sin(r) + local_z * math.cos(r))


def end_world(inst, end):
    centre, facing = ENDS[inst["name"]][end]
    return to_world(inst, -centre[0], centre[1]), vec_world(inst, -facing[0], facing[1])


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def pieces(inst):
    """Convex pieces of a module or mouth, built from the restated measured numbers."""
    name = inst["name"]
    if name == "RC_TunnelStraight":
        return [g.rect_poly(inst["x"], inst["z"], STRAIGHT_HALF[0], STRAIGHT_HALF[1], inst["rotation_y_deg"])]
    if name == "RC_CaveMouth":
        return [g.Poly(tuple(to_world(inst, sx * MOUTH_HALF_X, sz) for sx, sz in
                             ((-1, -MOUTH_FRONT - 0.05), (1, -MOUTH_FRONT - 0.05), (1, MOUTH_BACK + 0.03),
                              (-1, MOUTH_BACK + 0.03))))]
    out = []
    ri, ro = BEND_WEDGE
    cx, cz = BEND_CENTRE_LOCAL
    for k in range(6):
        a0, a1 = math.radians(15 * k), math.radians(15 * (k + 1))
        pts = [(cx + ri * math.cos(a0), cz + ri * math.sin(a0)), (cx + ro * math.cos(a0), cz + ro * math.sin(a0)),
               (cx + ro * math.cos(a1), cz + ro * math.sin(a1)), (cx + ri * math.cos(a1), cz + ri * math.sin(a1))]
        out.append(g.Poly(tuple(to_world(inst, *p) for p in pts)))
    return out


def piece_gap(a, b):
    return min(g.shape_gap(p, q) for p in pieces(a) for q in pieces(b))


def reach(inst):
    return g.Circle(inst["x"], inst["z"], RADIUS[inst["name"]] * inst["scale"])


def gather_point(inst):
    return to_world(inst, 0.0, GATHER_LOCAL[inst["name"]] * inst["scale"])


def walk_chain(layout, key):
    """Re-walk one tunnel from its start joint along the saved modules; return (letters, exit point, exit dir)."""
    by_id = {i["id"]: i for i in layout["instances"]}
    point, direction = TUNNELS[key]["start"], TUNNELS[key]["dir"]
    letters = []
    for module_id in next(t for t in layout["tunnels"] if t["name"] == key)["module_ids"]:
        inst = by_id[module_id]
        entry = None
        for end in ("A", "B"):
            pos, facing = end_world(inst, end)
            if math.dist(pos, point) <= SNAP_TOLERANCE and facing[0] * -direction[0] + facing[1] * -direction[1] > 0.999:
                entry = end
        assert entry, f"{module_id} does not snap to the previous joint"
        exit_end = "B" if entry == "A" else "A"
        exit_pos, exit_facing = end_world(inst, exit_end)
        if inst["name"] == "RC_TunnelStraight":
            letters.append("S")
        else:
            cross = direction[0] * exit_facing[1] - direction[1] * exit_facing[0]
            turn = "R" if cross > 0 else "L"
            assert turn == ("R" if entry == "A" else "L"), module_id
            letters.append(turn)
        point, direction = exit_pos, exit_facing
    return "".join(letters), point, direction


class RuleChecks:
    layout = None

    def route(self):
        return [tuple(p) for p in self.layout["route"]["nodes"]]

    def modules(self):
        return by_name(self.layout, "RC_TunnelStraight", "RC_TunnelBend")

    def mouths(self):
        return by_name(self.layout, "RC_CaveMouth")

    def props(self):
        return by_name(self.layout, "RC_Stalagmite", "RC_CrystalCluster", "RC_OreVein", "RC_Burrow")

    def structures(self):
        return self.modules() + self.mouths()

    def check_schema(self):
        layout = self.layout
        for key in ("name", "status", "seed", "instances", "totals", "route", "caps", "tunnels", "mouths",
                    "rockfall", "surface_routes", "points_of_interest", "density", "decisions"):
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
        self.assertGreaterEqual(len(layout["decisions"]), 6)

    def check_counts_and_budgets(self):
        names = [i["name"] for i in self.layout["instances"]]
        for name, count in MIX.items():
            self.assertEqual(names.count(name), count, name)
        total = len(names)
        self.assertEqual(total, 111)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], sum(PARTS[n] for n in names))
        self.assertEqual(totals["mesh_parts"], 185)
        self.assertEqual(budget, 23120)
        self.assertLessEqual(measured, budget)
        self.assertLessEqual(budget, MAX_TRIANGLES)
        self.assertEqual(totals["collision_boxes"], sum(COLLISION_COUNT.get(n, 0) for n in names))
        self.assertEqual(totals["occluder_boxes"], sum(OCCLUDER_COUNT.get(n, 0) for n in names))
        for name, entry in totals["by_name"].items():
            self.assertEqual(entry["count"], MIX[name])
            self.assertEqual(entry["triangles"], MIX[name] * MEASURED_TRIS[name])

    def check_inside_the_sector(self):
        for inst in self.structures():
            for poly in pieces(inst):
                x0, z0, x1, z1 = g.shape_bbox(poly)
                self.assertGreaterEqual(min(x0, z0), -LIMIT - 0.05, inst["id"])
                self.assertLessEqual(max(x1, z1), LIMIT + 0.05, inst["id"])
        for inst in self.props():
            x0, z0, x1, z1 = g.shape_bbox(reach(inst))
            self.assertGreaterEqual(min(x0, z0), -LIMIT, inst["id"])
            self.assertLessEqual(max(x1, z1), LIMIT, inst["id"])

    def check_tunnels_snap(self):
        """Both chains re-walked from the measured end rings: joints within 0.02, opposite facings."""
        results = {}
        for key in ("A", "B"):
            letters, point, direction = walk_chain(self.layout, key)
            self.assertEqual(letters, TUNNELS[key]["string"], key)
            results[key] = (point, direction)
            record = next(t for t in self.layout["tunnels"] if t["name"] == key)
            self.assertEqual(record["string"], letters)
            self.assertEqual(record["straights"], letters.count("S"))
            self.assertEqual(record["bends"], len(letters) - letters.count("S"))
            self.assertLessEqual(record["max_joint_error"], SNAP_TOLERANCE)
        self.assertEqual(sum(len(t["module_ids"]) for t in self.layout["tunnels"]), 26)
        self.assertEqual(len(by_name(self.layout, "RC_TunnelStraight")), 18)
        self.assertEqual(len(by_name(self.layout, "RC_TunnelBend")), 8)
        # Tunnel A leaves toward the clearing; tunnel B leaves through the east edge.
        point_b, dir_b = results["B"]
        self.assertGreaterEqual(point_b[0], 139.9)
        self.assertGreater(dir_b[0], 0.999)
        for key in ("A", "B"):
            self.assertTrue(all(g.shape_gap(p, q) >= 2.0 - 1e-6
                                for (a_index, a) in enumerate(self._chain(key))
                                for b in self._chain(key)[a_index + 2:]
                                for p in pieces(a) for q in pieces(b)), "non-adjacent modules stay apart")
        modules_a, modules_b = self._chain("A"), self._chain("B")
        for a in modules_a:
            for b in modules_b:
                self.assertGreaterEqual(piece_gap(a, b), 2.0 - 1e-6, f"{a['id']} {b['id']}")

    def _chain(self, key):
        by_id = {i["id"]: i for i in self.layout["instances"]}
        return [by_id[m] for m in next(t for t in self.layout["tunnels"] if t["name"] == key)["module_ids"]]

    def check_mouths(self):
        mouths = self.mouths()
        self.assertEqual(len(mouths), 3)
        self.assertEqual(len(self.layout["mouths"]), 3)
        self.assertLessEqual(MOUTH_PASSAGE[0], -CORRIDOR_HALF)
        self.assertGreaterEqual(MOUTH_PASSAGE[1], CORRIDOR_HALF)
        expectations = {"west": ("A", "start"), "exit": ("A", "end"), "east": ("B", "start")}
        route = self.route()
        by_id = {m["id"]: m for m in mouths}
        walked = {k: walk_chain(self.layout, k) for k in ("A", "B")}
        roles = set()
        for record in self.layout["mouths"]:
            inst = by_id[record["id"]]
            roles.add(record["role"])
            key, joint = expectations[record["role"]]
            inward = (math.sin(math.radians(inst["rotation_y_deg"])), math.cos(math.radians(inst["rotation_y_deg"])))
            rear = (inst["x"] + MOUTH_BACK * inward[0], inst["z"] + MOUTH_BACK * inward[1])
            if joint == "start":
                expected = TUNNELS[key]["start"]
                self.assertGreater(inward[0] * TUNNELS[key]["dir"][0] + inward[1] * TUNNELS[key]["dir"][1], 0.999)
            else:
                expected, direction = walked[key][1], walked[key][2]
                self.assertGreater(inward[0] * -direction[0] + inward[1] * -direction[1], 0.999)
            self.assertLessEqual(math.dist(rear, expected), SNAP_TOLERANCE + 0.01, record["role"])
            distance, arc, index, _ = g.project_to_polyline(route, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            a, b = route[index], route[index + 1]
            heading = g.heading_deg(b[0] - a[0], b[1] - a[1])
            self.assertTrue(angle_diff(inst["rotation_y_deg"], heading) < 0.01 or
                            angle_diff(inst["rotation_y_deg"], heading + 180.0) < 0.01, inst["id"])
            self.assertEqual(inst["scale"], 1)
        self.assertEqual(roles, set(expectations))

    def check_route(self):
        route = self.route()
        info = self.layout["route"]
        length = g.polyline_length(route)
        self.assertAlmostEqual(info["length"], length, delta=0.5)
        self.assertAlmostEqual(info["walk_seconds"], length / WALK_SPEED, delta=0.1)
        self.assertEqual(info["corridor_width"], 14.0)
        self.assertGreaterEqual(length, 700.0)
        self.assertGreaterEqual(max(abs(route[0][0]), abs(route[0][1])), 135.0)
        self.assertGreaterEqual(max(abs(route[-1][0]), abs(route[-1][1])), 139.0)
        for inst in self.modules():
            if inst["name"] == "RC_TunnelStraight":
                self.assertLess(g.project_to_polyline(route, xz(inst))[0], 0.05, inst["id"])
            else:
                cx, cz = BEND_CENTRE_LOCAL
                for k in range(7):
                    phi = math.radians(15 * k)
                    point = to_world(inst, cx + BEND_RADIUS * math.cos(phi), cz + BEND_RADIUS * math.sin(phi))
                    self.assertLess(g.project_to_polyline(route, point)[0], 0.05, f"{inst['id']} arc {k}")
        for surface in self.layout["surface_routes"]:
            for node in surface["nodes"]:
                self.assertLess(g.project_to_polyline(route, tuple(node))[0], 0.01)
        self.assertEqual(len(self.layout["surface_routes"]), 2)
        names = [p["name"] for p in self.layout["points_of_interest"]]
        for wanted in ("gate_west", "mouth_west", "mouth_exit", "crystal_hollow", "mouth_east", "gate_east"):
            self.assertIn(wanted, names)

    def check_rockfall(self):
        rockfall = self.layout["rockfall"]
        self.assertEqual((rockfall["dust_s"], rockfall["impact_s"], rockfall["strip_width"]), (DUST_S, IMPACT_S, STRIP))
        lanes = rockfall["lanes"]
        self.assertEqual(len(lanes), LANES)
        by_id = {i["id"]: i for i in self.layout["instances"]}
        centres = []
        for lane in lanes:
            module = by_id[lane["module"]]
            self.assertEqual(module["name"], "RC_TunnelStraight")
            self.assertEqual(lane["size"], [14.0, STRIP], "10 along the tunnel, the whole 14 stud floor across")
            self.assertAlmostEqual(lane["center"][0], module["x"], delta=0.01)
            self.assertAlmostEqual(lane["center"][1], module["z"], delta=0.01)
            polygon = g.rect_poly(lane["center"][0], lane["center"][1], 7.0, STRIP / 2, module["rotation_y_deg"])
            for p in polygon.pts:
                self.assertTrue(g.poly_contains(pieces(module)[0].pts, p), "the strip lies inside its module")
            self.assertAlmostEqual(lane["exit_from_center_s"], (STRIP / 2) / WALK_SPEED, delta=0.005)
            self.assertLessEqual(lane["exit_from_center_s"], 0.35)
            self.assertAlmostEqual(lane["cycle_s"], DUST_S + IMPACT_S)
            centres.append(xz(module))
        for i, a in enumerate(centres):
            for b in centres[i + 1:]:
                self.assertGreaterEqual(math.dist(a, b), 50.0, "rockfall lanes are far apart")
        in_a = [l for l in lanes if l["module"] in {m["id"] for m in self._chain("A")}]
        self.assertEqual(len(in_a), 2)

    def check_surface_props(self):
        route = self.route()
        for inst in self.props():
            shape = reach(inst)
            self.assertGreaterEqual(g.shape_polyline_dist(shape, route), CORRIDOR_HALF + BASE_GAP - 1e-6, inst["id"])
            lo, hi = SCALE_RANGE[inst["name"]]
            self.assertGreaterEqual(inst["scale"], lo - 1e-9)
            self.assertLessEqual(inst["scale"], hi + 1e-9)
            for structure in self.structures():
                for piece in pieces(structure):
                    self.assertGreaterEqual(g.shape_gap(shape, piece), BASE_GAP - 1e-6, f"{inst['id']} / {structure['id']}")
        for inst in by_name(self.layout, "RC_Burrow"):
            self.assertLessEqual(1.5 * inst["scale"], 1.7 + 1e-6, "tiny (N1)")

    def check_gatherables(self):
        surface = [[tuple(n) for n in s["nodes"]] for s in self.layout["surface_routes"]]

        def dist(p):
            return min(g.project_to_polyline(poly, p)[0] for poly in surface)

        gatherables = by_name(self.layout, "RC_CrystalCluster", "RC_OreVein")
        self.assertEqual(len(gatherables), 30)
        solids = self.props() + [None]
        for inst in gatherables:
            point = gather_point(inst)
            self.assertGreaterEqual(dist(point), 8.0, inst["id"])
            self.assertLessEqual(dist(point), 40.0, inst["id"])
            self.assertLess(dist(point), dist(xz(inst)), "the gather side faces the trail")
            for other in self.props():
                if other["id"] != inst["id"]:
                    self.assertGreater(g.shape_point_dist(reach(other), point), 0.0, f"{inst['id']} / {other['id']}")
            for structure in self.structures():
                for piece in pieces(structure):
                    self.assertGreater(g.shape_point_dist(piece, point), 0.0, f"{inst['id']} / {structure['id']}")

    def check_no_overlaps(self):
        props = self.props()
        for a_index, a in enumerate(props):
            for b in props[a_index + 1:]:
                self.assertGreaterEqual(g.shape_gap(reach(a), reach(b)), BASE_GAP - 1e-6, f"{a['id']} and {b['id']}")
        structures = self.structures()
        for a_index, a in enumerate(structures):
            for b in structures[a_index + 1:]:
                if a["name"] == "RC_CaveMouth" or b["name"] == "RC_CaveMouth":
                    continue
                if a in self._chain("A") and b in self._chain("A") or a in self._chain("B") and b in self._chain("B"):
                    continue
                self.assertGreaterEqual(piece_gap(a, b), 2.0 - 1e-6, f"{a['id']} and {b['id']}")
        for mouth in self.mouths():
            for other in self.modules():
                joined = piece_gap(mouth, other) < 0.2
                if not joined:
                    self.assertGreaterEqual(piece_gap(mouth, other), BASE_GAP - 1e-6, f"{mouth['id']} / {other['id']}")
        for a_index, a in enumerate(self.mouths()):
            for b in self.mouths()[a_index + 1:]:
                self.assertGreaterEqual(piece_gap(a, b), BASE_GAP)

    def check_everything(self):
        self.check_schema()
        self.check_counts_and_budgets()
        self.check_inside_the_sector()
        self.check_tunnels_snap()
        self.check_mouths()
        self.check_route()
        self.check_rockfall()
        self.check_surface_props()
        self.check_gatherables()
        self.check_no_overlaps()


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

    def test_tunnels_snap(self):
        self.check_tunnels_snap()

    def test_mouths(self):
        self.check_mouths()

    def test_route(self):
        self.check_route()

    def test_rockfall(self):
        self.check_rockfall()

    def test_surface_props(self):
        self.check_surface_props()

    def test_gatherables(self):
        self.check_gatherables()

    def test_no_overlaps(self):
        self.check_no_overlaps()

    def test_measured_values_match_the_kit_report_and_geometry(self):
        report_path = KIT_DIR / "rock-caves-kit-report.json"
        geometry_path = KIT_DIR / "rock-caves-kit-geometry.json"
        if not (report_path.exists() and geometry_path.exists()):
            self.skipTest("kit artifacts not built")
        props = json.loads(report_path.read_text(encoding="utf-8"))["props"]
        dump = json.loads(geometry_path.read_text(encoding="utf-8"))
        for name, tris in MEASURED_TRIS.items():
            self.assertEqual(props[name]["triangles"], tris, name)
            self.assertEqual(len(props[name]["parts"]), PARTS[name], name)
            self.assertLessEqual(tris, BUDGET_TRIS[name])
        for name, count in OCCLUDER_COUNT.items():
            self.assertEqual(len(props[name]["occluders"]), count, name)
        for name, count in COLLISION_COUNT.items():
            self.assertEqual(len(props[name]["collision_boxes"]), count, name)
        for name, ends in ENDS.items():
            for end, (centre, facing) in ends.items():
                self.assertEqual(props[name]["ends"][end]["center"], list(centre), name)
                self.assertEqual(props[name]["ends"][end]["facing"], list(facing), name)
            loop = props[name]["snap"]["profile_loop"]
            self.assertEqual([tuple(p) for p in loop], PROFILE, name)
            self.assertLessEqual(props[name]["snap"]["tolerance"], SNAP_TOLERANCE)
        self.assertEqual(props["RC_TunnelBend"]["arc"], {"center": [15.0, -15.0], "radius": 18.0, "segments": 6})
        clearance = props["RC_CaveMouth"]["clearance"]
        self.assertAlmostEqual(clearance["gap_low_x"], MOUTH_PASSAGE[0], delta=0.01)
        self.assertAlmostEqual(clearance["gap_high_x"], MOUTH_PASSAGE[1], delta=0.01)
        # The saved end ring of each module is built from the shared profile, within 0.02.
        for name, plane in (("RC_TunnelStraight", lambda v, c, f: abs(v[1] - c[1]) < 0.02),
                            ("RC_TunnelBend", lambda v, c, f: abs((v[1] - c[1]) * f[1] + (v[0] - c[0]) * f[0]) < 0.02)):
            vertices = [v for part in dump[name]["parts"].values() for v in part["vertices"]]
            for end, (centre, facing) in ENDS[name].items():
                ring = [v for v in vertices if plane(v, centre, facing)]
                across = (facing[1], -facing[0]) if facing != (0.0, 1.0) and facing != (0.0, -1.0) else (1.0, 0.0)
                for px, pz in PROFILE:
                    wanted = (centre[0] + px * across[0], centre[1] + px * across[1], pz)
                    near = min(math.dist(wanted, v) for v in ring)
                    self.assertLessEqual(near, SNAP_TOLERANCE, f"{name} end {end} ring vertex {(px, pz)}")
        for name, wanted in (("RC_Stalagmite", RADIUS["RC_Stalagmite"]), ("RC_CrystalCluster", RADIUS["RC_CrystalCluster"]),
                             ("RC_OreVein", RADIUS["RC_OreVein"]), ("RC_Burrow", RADIUS["RC_Burrow"])):
            points = [v for part in dump[name]["parts"].values() for v in part["vertices"]]
            self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in points), wanted, name)
        self.assertEqual(props["RC_CrystalCluster"]["gather_point"][1], GATHER_LOCAL["RC_CrystalCluster"])
        self.assertEqual(props["RC_OreVein"]["gather_point"][1], GATHER_LOCAL["RC_OreVein"])

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 111)
        self.assertLessEqual(totals["triangles_measured"], MAX_TRIANGLES)
        self.assertEqual(totals["triangles_measured"], 21222)
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
