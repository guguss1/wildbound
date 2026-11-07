"""Contracts for the Frozen Mountains top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_frozen_mountains_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. Prop sizes are the measured Blender kit values
(assets/blender/frozen-mountains-kit). Nothing here was imported into Roblox, played or
measured on a device.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_frozen_mountains_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_DIR = REPO / "assets/blender/frozen-mountains-kit"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 500.0, 245.0
MAX_INSTANCES, MAX_TRIANGLES = 170, 40000
MIX = {"FM_SnowPine": 60, "FM_IceSpire": 18, "FM_RockOverhang": 8, "FM_ScourShelf": 24, "FM_Cairn": 16,
       "FM_SnowMound": 20, "FM_IcePass": 2}
BUDGET_TRIS = {"FM_SnowPine": 360, "FM_IceSpire": 180, "FM_RockOverhang": 340, "FM_ScourShelf": 120,
               "FM_Cairn": 120, "FM_SnowMound": 60, "FM_IcePass": 520}
MEASURED_TRIS = {"FM_SnowPine": 298, "FM_IceSpire": 162, "FM_RockOverhang": 316, "FM_ScourShelf": 120,
                 "FM_Cairn": 100, "FM_SnowMound": 58, "FM_IcePass": 502}
PARTS = {"FM_SnowPine": 3, "FM_IceSpire": 2, "FM_RockOverhang": 2, "FM_ScourShelf": 1, "FM_Cairn": 2,
         "FM_SnowMound": 1, "FM_IcePass": 2}
ROUTE = [(-225, 190), (-140, 130), (-60, 140), (20, 70), (90, 10), (160, -60), (200, -130), (225, -195)]
YETI_HOME = (110, -150)
CORRIDOR_HALF = 7.0
WALK_SPEED = 16.0
BASE_GAP = 1.0
TRACK_SPACING = 6.0       # a Yeti track point every 6 studs on snow; none on rock (bible section 4)
MAX_TRACKS = 24           # at most 24 points per player, so a chain is at most 144 studs
# Measured kit footprints (scale 1).
PINE_R, PINE_CORE, PINE_CANOPY = 1.6, 1.0, 9.1
SPIRE_R, CAIRN_R, MOUND_R, SHELF_R = 3.6, 2.05, 3.2, 8.05
OVERHANG_HALF, PASS_HALF = (10.0, 6.05), (15.1, 7.15)
PASS_PASSAGE = (-8.5957, 8.429)
GATHER_LOCAL = -3.0
NO_TRACK = {"FM_ScourShelf": ((0.0, 0.0), (9.224, 9.224)), "FM_RockOverhang": ((0.0, -2.0), (12.0, 8.0))}
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
    if n == "FM_SnowPine":
        return g.Circle(x, z, PINE_R * s)
    if n == "FM_IceSpire":
        return g.Circle(x, z, SPIRE_R * s)
    if n == "FM_Cairn":
        return g.Circle(x, z, CAIRN_R)
    if n == "FM_SnowMound":
        return g.Circle(x, z, MOUND_R * s)
    if n == "FM_ScourShelf":
        return g.Circle(x, z, SHELF_R)
    half = {"FM_RockOverhang": OVERHANG_HALF, "FM_IcePass": PASS_HALF}[n]
    return g.rect_poly(x, z, half[0], half[1], yaw)


def seg_heading(index):
    (ax, az), (bx, bz) = ROUTE[index], ROUTE[index + 1]
    return g.heading_deg(bx - ax, bz - az)


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def local_to_world(inst, local_x, local_z):
    r = math.radians(inst["rotation_y_deg"])
    return (inst["x"] + local_x * math.cos(r) + local_z * math.sin(r),
            inst["z"] - local_x * math.sin(r) + local_z * math.cos(r))


def no_track_poly(inst):
    (cx, cz), (sx, sz) = NO_TRACK[inst["name"]]
    centre = local_to_world(inst, cx, cz)
    return g.rect_poly(centre[0], centre[1], sx / 2, sz / 2, inst["rotation_y_deg"]), centre


def gather_point(inst):
    return local_to_world(inst, 0.0, GATHER_LOCAL * inst["scale"])


def route_recorded_chain_lengths(layout):
    """Walk the route dropping a track point every 6 studs; rock records none. Return chain lengths."""
    rects = [no_track_poly(i)[0] for i in by_name(layout, "FM_ScourShelf", "FM_RockOverhang")]
    length = g.polyline_length(ROUTE)
    chains, run = [], 0
    for k in range(int(length / TRACK_SPACING) + 1):
        point = g.polyline_point(ROUTE, k * TRACK_SPACING)[0]
        if any(g.poly_contains(r.pts, point) for r in rects):
            if run:
                chains.append(run)
            run = 0
        else:
            run += 1
    chains.append(run)
    return chains


class RuleChecks:
    layout = None

    def solids(self):
        return [i for i in self.layout["instances"] if i["name"] != "FM_SnowMound"]

    def check_schema(self):
        layout = self.layout
        for key in ("name", "status", "seed", "instances", "totals", "route", "no_track_rects", "tracks",
                    "density", "caps", "yeti_home"):
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
        self.assertEqual(total, 148)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], sum(PARTS[n] for n in names))
        self.assertEqual(budget, 34600)
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
        self.assertGreaterEqual(length, 500.0)
        for node in (ROUTE[0], ROUTE[-1]):
            self.assertGreaterEqual(max(abs(node[0]), abs(node[1])), 190.0)
        self.assertEqual(tuple(self.layout["yeti_home"]), YETI_HOME)

    def check_corridor_clearance(self):
        for inst in self.solids():
            n = inst["name"]
            if n in ("FM_IcePass", "FM_ScourShelf"):
                continue
            gap = g.shape_polyline_dist(reach(inst), ROUTE)
            needed = CORRIDOR_HALF + (0.2 if n == "FM_Cairn" else BASE_GAP)
            self.assertGreaterEqual(gap, needed - 1e-6, inst["id"])
            if n == "FM_SnowPine":
                self.assertGreaterEqual(route_dist(xz(inst)), 14.0 - 1e-6, inst["id"])
        for inst in by_name(self.layout, "FM_SnowMound"):
            self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), ROUTE), 4.0 - 1e-6, inst["id"])

    def check_passes_straddle_the_route(self):
        passes = by_name(self.layout, "FM_IcePass")
        self.assertEqual(len(passes), 2)
        self.assertLessEqual(PASS_PASSAGE[0], -CORRIDOR_HALF)
        self.assertGreaterEqual(PASS_PASSAGE[1], CORRIDOR_HALF)
        for inst in passes:
            distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005)
            self.assertEqual(inst["scale"], 1)
            a, b = ROUTE[index], ROUTE[index + 1]
            self.assertGreaterEqual(min(math.dist(xz(inst), a), math.dist(xz(inst), b)), PASS_HALF[1] + 1.0)
        self.assertGreaterEqual(abs(passes[0]["x"] - passes[1]["x"]) + abs(passes[0]["z"] - passes[1]["z"]), 150.0)

    def check_shelves_break_the_track_chain(self):
        shelves = by_name(self.layout, "FM_ScourShelf")
        self.assertEqual(len(shelves), 24)
        on_route = [s for s in shelves if route_dist(xz(s)) <= 2.0]
        self.assertGreaterEqual(len(on_route), 8, "shelves laid across the trail break the Yeti's chain")
        for shelf in shelves:
            self.assertEqual(shelf["scale"], 1)
        chains = route_recorded_chain_lengths(self.layout)
        self.assertLessEqual(max(chains) * TRACK_SPACING, MAX_TRACKS * TRACK_SPACING - 2 * TRACK_SPACING,
                             "a chain must stay well under the 24-point limit")
        self.assertLessEqual(max(chains) * TRACK_SPACING, 110.0)
        self.assertGreaterEqual(len(chains), len(on_route), "each break shelf cuts the chain")
        self.assertEqual(self.layout["tracks"]["longest_chain_studs"], max(chains) * TRACK_SPACING)

    def check_no_track_rects(self):
        rects = self.layout["no_track_rects"]
        sources = by_name(self.layout, "FM_ScourShelf", "FM_RockOverhang")
        self.assertEqual(len(rects), len(sources))
        self.assertEqual(len(rects), 32)
        for source in sources:
            poly, centre = no_track_poly(source)
            entry = next(r for r in rects if r["source"] == source["id"])
            self.assertAlmostEqual(entry["center"][0], centre[0], delta=0.01)
            self.assertAlmostEqual(entry["center"][1], centre[1], delta=0.01)
            self.assertEqual(entry["size"], list(NO_TRACK[source["name"]][1]))
            for got, want in zip(sorted(map(tuple, entry["polygon"])), sorted(poly.pts)):
                self.assertAlmostEqual(got[0], want[0], delta=0.02)
                self.assertAlmostEqual(got[1], want[1], delta=0.02)

    def check_overhangs_shelter_and_stay_off_the_yeti_home(self):
        overhangs = by_name(self.layout, "FM_RockOverhang")
        self.assertEqual(len(overhangs), 8)
        for inst in overhangs:
            poly, centre = no_track_poly(inst)
            self.assertEqual(inst["scale"], 1)
            self.assertLess(route_dist(centre), route_dist(xz(inst)), "the open side faces the trail")
            self.assertGreaterEqual(route_dist(centre), 14.0)
            self.assertLessEqual(route_dist(centre), 50.0)
            self.assertGreaterEqual(g.shape_point_dist(poly, YETI_HOME), 40.0, "no spawning inside a shelter")

    def check_spires_face_the_trail(self):
        spires = by_name(self.layout, "FM_IceSpire")
        self.assertEqual(len(spires), 18)
        for inst in spires:
            point = gather_point(inst)
            distance = route_dist(point)
            self.assertGreaterEqual(distance, 8.0, inst["id"])
            self.assertLessEqual(distance, 55.0, inst["id"])
            self.assertLess(distance, route_dist(xz(inst)), "the gather side faces the trail")
            for solid in self.solids():
                if solid["id"] != inst["id"]:
                    self.assertGreater(g.shape_point_dist(reach(solid), point), 0.0, f"{inst['id']} / {solid['id']}")

    def check_cairns_mark_the_trail(self):
        cairns = by_name(self.layout, "FM_Cairn")
        self.assertEqual(len(cairns), 16)
        arcs = []
        for inst in cairns:
            distance, arc, _, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertGreaterEqual(distance, 8.9, inst["id"])
            self.assertLessEqual(distance, 11.5, inst["id"])
            arcs.append(arc)
        arcs.sort()
        self.assertTrue(all(b - a >= 25.0 for a, b in zip(arcs, arcs[1:])))
        self.assertLessEqual(arcs[0], 45.0)
        self.assertGreaterEqual(arcs[-1], g.polyline_length(ROUTE) - 45.0)

    def check_pines_and_mounds(self):
        pines = by_name(self.layout, "FM_SnowPine")
        self.assertEqual(len(pines), 60)
        for a_index, a in enumerate(pines):
            self.assertGreaterEqual(a["scale"], 0.9)
            self.assertLessEqual(a["scale"], 1.15)
            for b in pines[a_index + 1:]:
                self.assertGreaterEqual(math.dist(xz(a), xz(b)), 12.0 - 1e-6, f"{a['id']} {b['id']}")
        mounds = by_name(self.layout, "FM_SnowMound")
        self.assertEqual(len(mounds), 20)
        for inst in mounds:
            self.assertLessEqual(3.0 * inst["scale"], 3.3 + 1e-6, "tiny: never taller than 3.3 (N1)")
            self.assertGreaterEqual(inst["scale"], 0.85 - 1e-9)

    def check_no_solid_overlaps(self):
        solids = self.solids()
        shapes = {i["id"]: reach(i) for i in solids}
        for a_index, a in enumerate(solids):
            for b in solids[a_index + 1:]:
                self.assertGreaterEqual(g.shape_gap(shapes[a["id"]], shapes[b["id"]]), BASE_GAP - 1e-6,
                                        f"{a['id']} and {b['id']}")
        for mound in by_name(self.layout, "FM_SnowMound"):
            for solid in solids:
                self.assertGreater(g.shape_gap(reach(mound), shapes[solid["id"]]), 0.0, f"{mound['id']} / {solid['id']}")

    def check_open_slopes(self):
        blockers = [(i["x"], i["z"], 15.0) for i in by_name(self.layout, "FM_SnowPine")]
        blockers += [(*xz(i), 16.0) for i in by_name(self.layout, "FM_RockOverhang", "FM_IcePass")]
        near = total = 0
        for ix in range(-245, 246, 10):
            for iz in range(-245, 246, 10):
                total += 1
                near += any(math.hypot(ix - x, iz - z) <= r for x, z, r in blockers)
        fraction = near / total
        self.assertAlmostEqual(self.layout["density"]["near_sight_blocker_fraction"], fraction, delta=0.02)
        self.assertLessEqual(fraction, 0.40, "the slopes must stay open: you see the threat coming")

    def check_everything(self):
        self.check_schema()
        self.check_counts_and_budgets()
        self.check_inside_the_sector()
        self.check_route()
        self.check_corridor_clearance()
        self.check_passes_straddle_the_route()
        self.check_shelves_break_the_track_chain()
        self.check_no_track_rects()
        self.check_overhangs_shelter_and_stay_off_the_yeti_home()
        self.check_spires_face_the_trail()
        self.check_cairns_mark_the_trail()
        self.check_pines_and_mounds()
        self.check_no_solid_overlaps()
        self.check_open_slopes()


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

    def test_passes_straddle_the_route(self):
        self.check_passes_straddle_the_route()

    def test_shelves_break_the_track_chain(self):
        self.check_shelves_break_the_track_chain()

    def test_no_track_rects(self):
        self.check_no_track_rects()

    def test_overhangs_shelter_and_stay_off_the_yeti_home(self):
        self.check_overhangs_shelter_and_stay_off_the_yeti_home()

    def test_spires_face_the_trail(self):
        self.check_spires_face_the_trail()

    def test_cairns_mark_the_trail(self):
        self.check_cairns_mark_the_trail()

    def test_pines_and_mounds(self):
        self.check_pines_and_mounds()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_open_slopes(self):
        self.check_open_slopes()

    def test_measured_values_match_the_kit_report_and_geometry(self):
        report_path = KIT_DIR / "frozen-mountains-kit-report.json"
        geometry_path = KIT_DIR / "frozen-mountains-kit-geometry.json"
        if not (report_path.exists() and geometry_path.exists()):
            self.skipTest("kit artifacts not built")
        props = json.loads(report_path.read_text(encoding="utf-8"))["props"]
        dump = json.loads(geometry_path.read_text(encoding="utf-8"))
        for name, tris in MEASURED_TRIS.items():
            self.assertEqual(props[name]["triangles"], tris, name)
            self.assertEqual(len(props[name]["parts"]), PARTS[name], name)
            self.assertLessEqual(tris, BUDGET_TRIS[name])
        for name, (centre, size) in NO_TRACK.items():
            (rect,) = props[name]["no_track_rects"]
            self.assertEqual(rect["center"], list(centre), name)
            self.assertAlmostEqual(rect["size"][0], size[0], delta=0.01)
            self.assertAlmostEqual(rect["size"][1], size[1], delta=0.01)

        def points(name, label=None):
            return [v for obj, part in dump[name]["parts"].items() if label is None or obj.endswith("_" + label)
                    for v in part["vertices"]]

        def ground(name):
            return [v for v in points(name) if v[2] <= 0.6]

        for name, wanted in (("FM_SnowPine", PINE_R), ("FM_IceSpire", SPIRE_R), ("FM_Cairn", CAIRN_R),
                             ("FM_SnowMound", MOUND_R), ("FM_ScourShelf", SHELF_R)):
            self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in ground(name)), wanted, name)
        for name, (hx, hy) in (("FM_RockOverhang", OVERHANG_HALF), ("FM_IcePass", PASS_HALF)):
            pts = points(name)
            self.assertLessEqual(max(abs(v[0]) for v in pts), hx, name)
            self.assertLessEqual(max(abs(v[1]) for v in pts), hy, name)
        trunk = [v for v in points("FM_SnowPine", "Trunk") if v[2] > 3.0]
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in trunk), PINE_CORE)
        self.assertLessEqual(max(math.hypot(v[0], v[1]) for v in points("FM_SnowPine", "Canopy")), PINE_CANOPY)

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 148)
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
