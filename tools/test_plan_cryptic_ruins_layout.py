"""Contracts for the Cryptic Ruins top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_cryptic_ruins_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers independently of
the generator, and re-derive each rule from the saved (rounded) instance data instead of
trusting the generator's own report. Prop sizes and occluder boxes are the measured Blender kit
values (assets/blender/cryptic-ruins-kit). Nothing here was imported into Roblox, played or
measured on a device. Kit frame to plan frame: local x = -Blender x, local z = Blender y.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_cryptic_ruins_layout as plan

REPO = Path(__file__).resolve().parent.parent
KIT_DIR = REPO / "assets/blender/cryptic-ruins-kit"

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 300.0, 145.0
MAX_INSTANCES, MAX_TRIANGLES = 120, 30000
MIX = {"CR_Colonnade": 14, "CR_BrokenWall": 40, "CR_Plinth": 14, "CR_Archway": 6, "CR_Reliquary": 8,
       "CR_GlyphStone": 12, "CR_StairRun": 8}
BUDGET_TRIS = {"CR_Colonnade": 420, "CR_BrokenWall": 260, "CR_Plinth": 100, "CR_Archway": 560, "CR_Reliquary": 200,
               "CR_GlyphStone": 120, "CR_StairRun": 180}
MEASURED_TRIS = {"CR_Colonnade": 384, "CR_BrokenWall": 228, "CR_Plinth": 96, "CR_Archway": 396, "CR_Reliquary": 164,
                 "CR_GlyphStone": 96, "CR_StairRun": 108}
PARTS = {"CR_Colonnade": 2, "CR_BrokenWall": 2, "CR_Plinth": 2, "CR_Archway": 2, "CR_Reliquary": 2,
         "CR_GlyphStone": 2, "CR_StairRun": 1}
ROUTE = [(-120, 140), (-120, 70), (-30, 70), (-30, -20), (70, -20), (70, -90), (-60, -90), (-60, -140)]
# El Vigia's chain of 14 plinths (bible section 4: 24 to 40 studs apart), authored for this draft.
VIGIA = [(-80, 125), (-70, 95), (-60, 57), (-60, 25), (-60, -14), (-45, -45), (-20, -65), (10, -55), (40, -45),
         (40, -6), (70, 12), (95, -10), (100, -45), (97, -80)]
CORRIDOR_HALF = 7.0
WALK_SPEED = 16.0
BASE_GAP = 1.0
SIGHT_RANGE = 70.0
# Measured kit footprints as (half extent along local X, half extent along local Z), scale 1.
HALF = {"CR_Colonnade": (12.7, 2.6), "CR_BrokenWall": (7.1, 1.7), "CR_Plinth": (3.0, 3.0), "CR_Archway": (14.25, 4.2),
        "CR_Reliquary": (4.05, 2.05), "CR_GlyphStone": (2.05, 1.6), "CR_StairRun": (8.0, 6.05)}
ARCH_PASSAGE = (-7.4145, 7.2338)
# Occluder boxes in Blender axes: (centre x, y, z), (size x, y, z); local x = -x, local z = y.
OCCLUDERS = {
    "CR_Colonnade": [((-10.3, 0.0, 5.5), (3.9, 4.6, 11.0)), ((0.0, 0.0, 5.5), (3.9, 4.6, 11.0)),
                     ((10.3, 0.0, 5.5), (3.9, 4.6, 11.0))],
    "CR_BrokenWall": [((0.0, 0.0, 3.5), (14.3, 3.0, 7.0))],
    "CR_Archway": [((-10.8, 0.0, 5.5), (6.4, 6.8, 11.0)), ((10.8, 0.0, 5.5), (6.4, 6.8, 11.0))],
}
AVATAR_HEIGHT = 6.0      # the occluder must be taller than a standing avatar
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
    half = HALF[inst["name"]]
    return g.rect_poly(inst["x"], inst["z"], half[0], half[1], inst["rotation_y_deg"])


def seg_heading(index):
    (ax, az), (bx, bz) = ROUTE[index], ROUTE[index + 1]
    return g.heading_deg(bx - ax, bz - az)


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


def occluder_polys(layout):
    polys = []
    for inst in layout["instances"]:
        for (cx, cy, cz), (sx, sy, sz) in OCCLUDERS.get(inst["name"], []):
            centre = to_world(inst, -cx, cy)
            polys.append(g.rect_poly(centre[0], centre[1], sx / 2, sy / 2, inst["rotation_y_deg"]))
    return polys


def clear_sight(polys, a, b):
    return all(g.shape_segment_dist(p, a, b) > 0.0 for p in polys)


def route_samples(step):
    length = g.polyline_length(ROUTE)
    return [g.polyline_point(ROUTE, k * step)[0] for k in range(int(length / step) + 1)]


class RuleChecks:
    layout = None

    def solids(self):
        return list(self.layout["instances"])

    def check_schema(self):
        layout = self.layout
        for key in ("name", "status", "seed", "instances", "totals", "route", "caps", "vigia", "alcoves",
                    "overlooks", "density", "decisions"):
            self.assertIn(key, layout)
        self.assertIn("unvalidated", layout["status"])
        self.assertIn("draft", layout["status"])
        ids = [i["id"] for i in layout["instances"]]
        self.assertEqual(len(ids), len(set(ids)))
        for inst in layout["instances"]:
            for key in ("id", "name", "x", "z", "rotation_y_deg", "scale"):
                self.assertIn(key, inst)
            self.assertIn(inst["name"], MIX)
            self.assertEqual(inst["scale"], 1)
            self.assertTrue(all(math.isfinite(inst[k]) for k in ("x", "z", "rotation_y_deg", "scale")))
        self.assertGreaterEqual(len(layout["decisions"]), 5)

    def check_counts_and_budgets(self):
        names = [i["name"] for i in self.layout["instances"]]
        for name, count in MIX.items():
            self.assertEqual(names.count(name), count, name)
        total = len(names)
        self.assertEqual(total, 102)
        self.assertLessEqual(total, MAX_INSTANCES)
        totals = self.layout["totals"]
        measured = sum(MEASURED_TRIS[n] for n in names)
        budget = sum(BUDGET_TRIS[n] for n in names)
        self.assertEqual(totals["instances"], total)
        self.assertEqual(totals["triangles_measured"], measured)
        self.assertEqual(totals["triangles_budget"], budget)
        self.assertEqual(totals["mesh_parts"], sum(PARTS[n] for n in names))
        self.assertEqual(totals["mesh_parts"], 196)
        self.assertEqual(budget, 25520)
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
        self.assertEqual(len(route["names"]), len(ROUTE))
        length = g.polyline_length(ROUTE)
        self.assertAlmostEqual(route["length"], length, delta=0.5)
        self.assertAlmostEqual(route["walk_seconds"], length / WALK_SPEED, delta=0.1)
        self.assertEqual(route["corridor_width"], 14.0)
        self.assertGreaterEqual(length, 500.0)
        for node in (ROUTE[0], ROUTE[-1]):
            self.assertGreaterEqual(max(abs(node[0]), abs(node[1])), 140.0)

    def check_corridor_clearance(self):
        for inst in self.solids():
            if inst["name"] == "CR_Archway":
                continue
            gap = g.shape_polyline_dist(reach(inst), ROUTE)
            self.assertGreaterEqual(gap, CORRIDOR_HALF + BASE_GAP - 1e-6, inst["id"])

    def check_archways_straddle_the_route(self):
        arches = by_name(self.layout, "CR_Archway")
        self.assertEqual(len(arches), 6)
        self.assertLessEqual(ARCH_PASSAGE[0], -CORRIDOR_HALF)
        self.assertGreaterEqual(ARCH_PASSAGE[1], CORRIDOR_HALF)
        self.assertLess(abs(ARCH_PASSAGE[0] + ARCH_PASSAGE[1]) / 2, 0.5, "measured gap is centred on the pivot")
        legs = set()
        for inst in arches:
            distance, arc, index, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertLess(distance, 0.002, inst["id"])
            self.assertLess(angle_diff(inst["rotation_y_deg"], seg_heading(index)), 0.005)
            a, b = ROUTE[index], ROUTE[index + 1]
            self.assertGreaterEqual(min(math.dist(xz(inst), a), math.dist(xz(inst), b)), HALF["CR_Archway"][1] + 1.0)
            legs.add(index)
        self.assertEqual(len(legs), 6, "one archway on each of six different legs")

    def check_occluders(self):
        total = 0
        for inst in self.layout["instances"]:
            boxes = OCCLUDERS.get(inst["name"])
            if boxes is None:
                self.assertNotIn("occluders", inst)
                continue
            self.assertEqual(len(inst["occluders"]), len(boxes), inst["id"])
            for record, ((cx, cy, cz), (sx, sy, sz)) in zip(inst["occluders"], boxes):
                centre = to_world(inst, -cx, cy)
                self.assertAlmostEqual(record["center"][0], centre[0], delta=0.01)
                self.assertAlmostEqual(record["center"][1], centre[1], delta=0.01)
                self.assertEqual(record["size"], [sx, sy])
                self.assertEqual(record["height"], sz)
                self.assertEqual(record["base"], r3(cz - sz / 2))
                self.assertAlmostEqual(record["rotation_y_deg"], inst["rotation_y_deg"], delta=0.001)
                self.assertGreater(record["height"], AVATAR_HEIGHT, "an occluder must cover an avatar")
                total += 1
        self.assertEqual(total, 14 * 3 + 40 + 6 * 2)
        self.assertEqual(self.layout["totals"]["occluder_boxes"], total)
        for inst in by_name(self.layout, "CR_Colonnade"):
            columns = sorted(inst["occluders"], key=lambda o: math.dist(o["center"], xz(inst)))
            for a_index, a in enumerate(inst["occluders"]):
                for b in inst["occluders"][a_index + 1:]:
                    self.assertGreaterEqual(math.dist(a["center"], b["center"]) - 3.9, 6.0, "gaps stay at least 6 wide")

    def check_vigia_chain(self):
        vigia = self.layout["vigia"]
        plinths = by_name(self.layout, "CR_Plinth")
        self.assertEqual(len(plinths), 14)
        self.assertEqual([tuple(p) for p in vigia["chain"]], VIGIA)
        self.assertEqual(vigia["plinth_ids"], sorted(p["id"] for p in plinths))
        by_id = {p["id"]: p for p in plinths}
        for point, plinth_id in zip(VIGIA, vigia["plinth_ids"]):
            self.assertAlmostEqual(by_id[plinth_id]["x"], point[0], delta=0.01)
            self.assertAlmostEqual(by_id[plinth_id]["z"], point[1], delta=0.01)
        spacings = [math.dist(a, b) for a, b in zip(VIGIA, VIGIA[1:])]
        self.assertTrue(all(24.0 <= s <= 40.0 for s in spacings), spacings)
        self.assertEqual(vigia["spacing_range"], [round(min(spacings), 3), round(max(spacings), 3)])
        crossings = g.crossings(ROUTE, VIGIA)
        self.assertGreaterEqual(len(crossings), 2, "the chain crosses the trail, so the contest happens on it")
        self.assertEqual(len(vigia["route_crossings"]), len(crossings))
        for record, c in zip(vigia["route_crossings"], sorted(crossings, key=lambda c: c["first_arc"])):
            self.assertAlmostEqual(record["route_arc"], c["first_arc"], delta=0.05)

    def check_exposure(self):
        polys = occluder_polys(self.layout)
        pairs = clear = 0
        for sample in route_samples(8.0):
            for plinth in VIGIA:
                if math.dist(sample, plinth) <= SIGHT_RANGE:
                    pairs += 1
                    clear += clear_sight(polys, plinth, sample)
        fraction = clear / pairs
        self.assertGreaterEqual(fraction, 0.2, "some of the trail must be in plain view of the plinths")
        self.assertLessEqual(fraction, 0.7, "and enough of it hidden to break sight on purpose")
        self.assertAlmostEqual(self.layout["density"]["route_sight_exposure"], fraction, delta=0.02)

    def check_alcoves(self):
        reliquaries = by_name(self.layout, "CR_Reliquary")
        self.assertEqual(len(reliquaries), 8)
        alcoves = self.layout["alcoves"]
        self.assertEqual(len(alcoves), 8)
        polys = occluder_polys(self.layout)
        solids = {i["id"]: i for i in self.solids()}
        walls_used = set()
        for alcove in alcoves:
            reliquary = solids[alcove["reliquary"]]
            self.assertEqual(len(alcove["wall_ids"]), 3)
            walls_used.update(alcove["wall_ids"])
            gather = xz(reliquary)
            distance, arc, index, _ = g.project_to_polyline(ROUTE, gather)
            self.assertGreaterEqual(distance, 14.0)
            self.assertLessEqual(distance, 45.0)
            foot = g.polyline_point(ROUTE, arc)[0]
            for solid in self.solids():
                if solid["id"] != reliquary["id"]:
                    self.assertGreater(g.shape_segment_dist(reach(solid), gather, foot), 0.3,
                                       f"{reliquary['id']} is reachable past {solid['id']}")
            exposed = sum(1 for p in VIGIA if math.dist(p, gather) <= SIGHT_RANGE and clear_sight(polys, p, gather))
            self.assertLessEqual(exposed, 2, f"{reliquary['id']} hides from most plinths")
            self.assertEqual(alcove["exposed_plinths"], exposed)
            for wall_id in alcove["wall_ids"]:
                self.assertLessEqual(math.dist(xz(solids[wall_id]), gather), 12.0)
        self.assertEqual(len(walls_used), 24)

    def check_screens_and_walls(self):
        walls = by_name(self.layout, "CR_BrokenWall")
        self.assertEqual(len(walls), 40)
        alcove_walls = {w for a in self.layout["alcoves"] for w in a["wall_ids"]}
        screens = [w for w in walls if w["id"] not in alcove_walls]
        self.assertEqual(len(screens), 16)
        for wall in screens:
            nearest = min(VIGIA, key=lambda p: math.dist(p, xz(wall)))
            direction = (nearest[0] - wall["x"], nearest[1] - wall["z"])
            ex = (math.cos(math.radians(wall["rotation_y_deg"])), -math.sin(math.radians(wall["rotation_y_deg"])))
            norm = math.hypot(*direction)
            self.assertLess(abs(ex[0] * direction[0] + ex[1] * direction[1]) / norm, 0.3, "a screen faces the nearest plinth")

    def check_colonnades(self):
        colonnades = by_name(self.layout, "CR_Colonnade")
        self.assertEqual(len(colonnades), 14)
        flank = 0
        for inst in colonnades:
            distance, arc, index, lateral = g.project_to_polyline(ROUTE, xz(inst))
            along = (math.cos(math.radians(inst["rotation_y_deg"])), -math.sin(math.radians(inst["rotation_y_deg"])))
            heading = seg_heading(index)
            direction = (math.sin(math.radians(heading)), math.cos(math.radians(heading)))
            if abs(along[0] * direction[0] + along[1] * direction[1]) > 0.999 and 10.5 <= abs(lateral) <= 13.0:
                flank += 1
        self.assertGreaterEqual(flank, 8, "four colonnade pairs line the trail")

    def check_glyph_stones(self):
        stones = by_name(self.layout, "CR_GlyphStone")
        self.assertEqual(len(stones), 12)
        arcs = []
        for inst in stones:
            distance, arc, _, _ = g.project_to_polyline(ROUTE, xz(inst))
            self.assertGreaterEqual(distance, 9.0)
            self.assertLessEqual(distance, 13.5)
            front = to_world(inst, 0.0, -4.0)
            back = to_world(inst, 0.0, 4.0)
            self.assertLess(route_dist(front), route_dist(back), "the raised plate faces the trail")
            arcs.append(arc)
        arcs.sort()
        self.assertTrue(all(b - a >= 30.0 for a, b in zip(arcs, arcs[1:])))

    def check_overlooks(self):
        stairs = by_name(self.layout, "CR_StairRun")
        self.assertEqual(len(stairs), 8)
        overlooks = self.layout["overlooks"]
        self.assertEqual(len(overlooks), 4)
        by_id = {i["id"]: i for i in stairs}
        used = set()
        for pair in overlooks:
            a, b = (by_id[pair["stairs"][0]], by_id[pair["stairs"][1]])
            used.update(pair["stairs"])
            self.assertLess(angle_diff(a["rotation_y_deg"], b["rotation_y_deg"] + 180.0), 0.01, "back to back")
            top_a, top_b = to_world(a, 0.0, 5.0), to_world(b, 0.0, 5.0)
            self.assertLess(math.dist(top_a, top_b), 2.0 * 5.0 - 6.0, "the landings meet in the middle")
            centre = ((a["x"] + b["x"]) / 2, (a["z"] + b["z"]) / 2)
            distance, _, index, lateral = g.project_to_polyline(ROUTE, centre)
            self.assertGreaterEqual(abs(lateral), 15.0)
            self.assertLessEqual(abs(lateral), 24.0)
            ridge = (b["x"] - a["x"], b["z"] - a["z"])
            heading = seg_heading(index)
            direction = (math.sin(math.radians(heading)), math.cos(math.radians(heading)))
            self.assertGreater(abs(ridge[0] * direction[0] + ridge[1] * direction[1]) / math.hypot(*ridge), 0.99,
                               "the ridge runs along the trail")
        self.assertEqual(used, set(by_id))

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
        self.check_corridor_clearance()
        self.check_archways_straddle_the_route()
        self.check_occluders()
        self.check_vigia_chain()
        self.check_exposure()
        self.check_alcoves()
        self.check_screens_and_walls()
        self.check_colonnades()
        self.check_glyph_stones()
        self.check_overlooks()
        self.check_no_solid_overlaps()


def r3(value):
    return round(float(value), 3) + 0.0


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

    def test_archways_straddle_the_route(self):
        self.check_archways_straddle_the_route()

    def test_occluders(self):
        self.check_occluders()

    def test_vigia_chain(self):
        self.check_vigia_chain()

    def test_exposure(self):
        self.check_exposure()

    def test_alcoves(self):
        self.check_alcoves()

    def test_screens_and_walls(self):
        self.check_screens_and_walls()

    def test_colonnades(self):
        self.check_colonnades()

    def test_glyph_stones(self):
        self.check_glyph_stones()

    def test_overlooks(self):
        self.check_overlooks()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_measured_values_match_the_kit_report_and_geometry(self):
        report_path = KIT_DIR / "cryptic-ruins-kit-report.json"
        geometry_path = KIT_DIR / "cryptic-ruins-kit-geometry.json"
        if not (report_path.exists() and geometry_path.exists()):
            self.skipTest("kit artifacts not built")
        props = json.loads(report_path.read_text(encoding="utf-8"))["props"]
        dump = json.loads(geometry_path.read_text(encoding="utf-8"))
        for name, tris in MEASURED_TRIS.items():
            self.assertEqual(props[name]["triangles"], tris, name)
            self.assertEqual(len(props[name]["parts"]), PARTS[name], name)
            self.assertLessEqual(tris, BUDGET_TRIS[name])
        for name, boxes in OCCLUDERS.items():
            reported = props[name]["occluders"]
            self.assertEqual(len(reported), len(boxes), name)
            for record, (centre, size) in zip(reported, boxes):
                for got, want in zip(record["center"], centre):
                    self.assertAlmostEqual(got, want, delta=0.01)
                for got, want in zip(record["size"], size):
                    self.assertAlmostEqual(got, want, delta=0.01)
        for name, (hx, hz) in HALF.items():
            points = [v for part in dump[name]["parts"].values() for v in part["vertices"]]
            self.assertLessEqual(max(abs(v[0]) for v in points), hx, name)
            self.assertLessEqual(max(abs(v[1]) for v in points), hz, name)
        clearance = props["CR_Archway"]["clearance"]
        self.assertAlmostEqual(clearance["gap_low_x"], ARCH_PASSAGE[0], delta=0.01)
        self.assertAlmostEqual(clearance["gap_high_x"], ARCH_PASSAGE[1], delta=0.01)
        stairs = props["CR_StairRun"]
        self.assertAlmostEqual(stairs["collision_boxes"][0]["center"][1], 5.0, delta=0.01)

    def test_wave_budget_reporting(self):
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], 102)
        self.assertLessEqual(totals["triangles_measured"], MAX_TRIANGLES)
        self.assertEqual(totals["triangles_measured"], 21544)
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
