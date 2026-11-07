"""Contracts for the fog-forest top-down placement plan.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_forest_layout.py

The spec inputs are restated here on purpose: the tests pin the design numbers
independently of the generator, and re-derive each rule from the saved
(rounded) instance data instead of trusting the generator's own report.
Prop sizes are the measured Blender kit values (forest-kit-report.json).
"""

import json
import math
import re
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

import plan_forest_layout as plan

try:  # Pillow is optional; the PNG is only checked when it can be produced.
    import PIL  # noqa: F401
    HAVE_PILLOW = True
except ImportError:
    HAVE_PILLOW = False

REPO = Path(__file__).resolve().parent.parent
KIT_REPORT = REPO / "assets/blender/forest-kit/forest-kit-report.json"

# ---- Spec inputs, restated independently of the module under test ----------
ROUTE = [(-140, 140), (-95, 75), (0, -85), (35, -99), (115, 15), (105, 125)]
SEGS = [(ROUTE[i], ROUTE[(i + 1) % len(ROUTE)]) for i in range(len(ROUTE))]
SEG_LEN = [math.dist(a, b) for a, b in SEGS]
CUM = [sum(SEG_LEN[:i]) for i in range(len(SEGS))]
LOOP = sum(SEG_LEN)
CAMP, CLEARING, RUIN, NEST, MARSH, SHELTER = ROUTE
HOME, LEASH = (0, -85), 80
FOG = (-45, 165, -165, 35)  # xmin, xmax, zmin, zmax
SAFE = [((-140, 140), 35), ((105, 125), 22)]
PILLARS = [(-10, -92), (10, -92), (10, -77), (-10, -77)]
# Real patrol waypoints (WildboundWorld.server.luau:90-93): a diamond on the axes, visited E, S, W, N.
PATROL = {"E": (16, -85), "S": (0, -69), "W": (-16, -85), "N": (0, -101)}
EYE = 3.7
TREES = ("FK_Evergreen", "FK_DeadTree")
FOREST = ("FK_Evergreen", "FK_DeadTree", "FK_FallenLog")

# Measured from the Blender kit (assets/blender/forest-kit/forest-kit-report.json).
TRIS = {"FK_Evergreen": 370, "FK_DeadTree": 338, "FK_FallenLog": 346,
        "FK_RootArch": 664, "FK_RuinDoorway": 586, "FK_LanternMarker": 348}
ROOTS_R = 8.0                                         # ground root flare of trees (scale 1)
CORE_R = {"FK_Evergreen": 2.5, "FK_DeadTree": 3.4}    # trunk at eye height (scale 1)
LOG_HALF, ARCH_HALF, DOOR_HALF = (8.544, 3.0111), (15.805, 8.0776), (18.0036, 4.9535)
ARCH_GAP, DOOR_GAP = (-8.1239, 8.2108), (-9.3104, 9.3213)  # inner clearance edges on local X
LANTERN_R = 2.2
FOG_AREA = (FOG[1] - FOG[0]) * (FOG[3] - FOG[2])
OUT_AREA = 400 * 400 - FOG_AREA
ALT_SEEDS = (11, 4242)


# ---- Tiny independent geometry ----------------------------------------------
def seg_dist(p, a, b):
    dx, dz = b[0] - a[0], b[1] - a[1]
    t = ((p[0] - a[0]) * dx + (p[1] - a[1]) * dz) / (dx * dx + dz * dz)
    t = max(0.0, min(1.0, t))
    return math.hypot(p[0] - (a[0] + t * dx), p[1] - (a[1] + t * dz))


def route_dist(p):
    return min(seg_dist(p, a, b) for a, b in SEGS)


def project(p):
    """Nearest segment index, arc position along the closed loop, signed lateral."""
    best = None
    for i, (a, b) in enumerate(SEGS):
        d = seg_dist(p, a, b)
        if best is None or d < best[0]:
            best = (d, i)
    i = best[1]
    a, b = SEGS[i]
    dx, dz = (b[0] - a[0]) / SEG_LEN[i], (b[1] - a[1]) / SEG_LEN[i]
    along = (p[0] - a[0]) * dx + (p[1] - a[1]) * dz
    lateral = (p[0] - a[0]) * -dz + (p[1] - a[1]) * dx
    return i, CUM[i] + along, lateral


def in_fog(x, z):
    return FOG[0] <= x <= FOG[1] and FOG[2] <= z <= FOG[3]


def in_safe(x, z):
    return any(math.dist((x, z), c) <= r for c, r in SAFE)


def in_territory(x, z):
    return in_fog(x, z) and not in_safe(x, z) and math.dist((x, z), HOME) <= LEASH


def segment_hits_circle(a, b, c, r):
    return seg_dist(c, a, b) < r


def segment_hits_box(a, b, centre, half):
    """Slab test of segment a-b against an axis-aligned square."""
    t0, t1 = 0.0, 1.0
    for axis in (0, 1):
        d = b[axis] - a[axis]
        lo, hi = centre[axis] - half, centre[axis] + half
        if abs(d) < 1e-12:
            if a[axis] < lo or a[axis] > hi:
                return False
            continue
        ta, tb = (lo - a[axis]) / d, (hi - a[axis]) / d
        t0, t1 = max(t0, min(ta, tb)), min(t1, max(ta, tb))
        if t0 > t1:
            return False
    return True


def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def xz(inst):
    return (inst["x"], inst["z"])


def heading_deg(a, b):
    """Yaw whose local +Z axis points from a to b (Roblox Angles(0, yaw, 0))."""
    return math.degrees(math.atan2(b[0] - a[0], b[1] - a[1])) % 360


def angle_diff(a, b):
    return abs((a - b + 180) % 360 - 180)


# ---- Rule checks, shared by the default seed and the alternate seeds -------
class RuleChecks:
    """check_* methods only need self.layout; test classes decide which seed."""

    layout = None

    # Structure
    def check_schema(self):
        layout = self.layout
        for key in ("name", "seed", "instances", "totals", "density", "nest_cover"):
            self.assertIn(key, layout)
        for inst in layout["instances"]:
            for key in ("id", "name", "x", "z", "rotation_y_deg", "scale", "zone"):
                self.assertIn(key, inst)
            self.assertIn(inst["name"], TRIS)
            self.assertTrue(all(math.isfinite(inst[k]) for k in ("x", "z", "rotation_y_deg", "scale")))
            self.assertEqual(inst["zone"], "fog" if in_fog(inst["x"], inst["z"]) else "outside")
        ids = [i["id"] for i in layout["instances"]]
        self.assertEqual(len(ids), len(set(ids)))

    # Rule 2
    def check_corridor_clear(self):
        for inst in self.layout["instances"]:
            if inst["name"] in ("FK_RootArch", "FK_RuinDoorway"):
                continue
            self.assertGreaterEqual(route_dist(xz(inst)), 10.0 - 1e-6, inst["id"])
            gap = min(plan.shape_polyline_dist(s, ROUTE, closed=True) for s in plan.footprint(inst))
            if inst["name"] in FOREST:  # base AND roots keep 10 studs from the centreline
                self.assertGreaterEqual(gap, 10.0 - 1e-6, inst["id"])
            else:  # lantern: anchor sits 10+ out, its whole base stays off the 14-stud corridor
                self.assertGreaterEqual(gap, 7.0, inst["id"])

    def check_arch_and_doorway_straddle_route(self):
        for name, gap in (("FK_RootArch", ARCH_GAP), ("FK_RuinDoorway", DOOR_GAP)):
            (inst,) = by_name(self.layout, name)
            seg = min(range(len(SEGS)), key=lambda i: seg_dist(xz(inst), *SEGS[i]))
            a, b = SEGS[seg]
            lateral_error = seg_dist(xz(inst), a, b)
            self.assertLess(lateral_error, 0.002, name)
            self.assertLess(angle_diff(inst["rotation_y_deg"], heading_deg(a, b)), 0.005, name)
            self.assertEqual(inst["scale"], 1)
            # The measured inner clearance covers the 14-stud corridor with margin on both sides.
            self.assertGreaterEqual(-gap[0] - 7.0 - lateral_error, 1.1, name)
            self.assertGreaterEqual(gap[1] - 7.0 - lateral_error, 1.1, name)

    def check_landmark_footprints_are_reserved(self):
        for name in ("FK_RootArch", "FK_RuinDoorway"):
            (landmark,) = by_name(self.layout, name)
            (rect,) = plan.footprint(landmark)
            for inst in self.layout["instances"]:
                if inst is landmark:
                    continue
                for shape in plan.footprint(inst):
                    self.assertGreaterEqual(plan.shape_gap(shape, rect), plan.BASE_GAP - 1e-6,
                                            (name, inst["id"]))

    # Rule 3
    def check_inside_map_edge(self):
        for inst in self.layout["instances"]:
            for shape in plan.footprint(inst):
                x0, z0, x1, z1 = plan.shape_bbox(shape)
                self.assertGreaterEqual(min(x0, z0), -195 - 1e-6, inst["id"])
                self.assertLessEqual(max(x1, z1), 195 + 1e-6, inst["id"])

    # Rule 4
    def check_safe_circles_have_no_trees(self):
        for inst in by_name(self.layout, *FOREST):
            self.assertFalse(in_safe(*xz(inst)), inst["id"])
            for centre, radius in SAFE:
                for shape in plan.footprint(inst):
                    self.assertGreater(plan.shape_point_dist(shape, centre), radius, inst["id"])

    def check_nest_and_clearing_stay_reachable(self):
        for inst in self.layout["instances"]:
            self.assertGreaterEqual(math.dist(xz(inst), NEST), 12.0, inst["id"])
            self.assertGreaterEqual(math.dist(xz(inst), CLEARING), 12.0, inst["id"])

    def check_roots_keep_off_route_nodes(self):
        for inst in self.layout["instances"]:
            for shape in plan.footprint(inst):
                for node in ROUTE:
                    self.assertGreaterEqual(plan.shape_point_dist(shape, node), 6.0 - 1e-6, inst["id"])

    def check_no_overlaps(self):
        gap_min = plan.BASE_GAP
        self.assertGreaterEqual(gap_min, 1.0)
        fixed = [plan.rect_poly(px, pz, 1.5, 1.5, 0) for px, pz in PILLARS]
        fixed += [plan.Circle(35 + 9 * math.cos(k * math.pi / 4), -99 + 9 * math.sin(k * math.pi / 4), 2.0)
                  for k in range(1, 9)]
        insts = self.layout["instances"]
        for inst in insts:  # roots and bases stay off pillars and stones
            for shape in plan.footprint(inst):
                for obstacle in fixed:
                    self.assertGreaterEqual(plan.shape_gap(shape, obstacle), gap_min - 1e-6, inst["id"])
        for i in range(len(insts)):
            for j in range(i + 1, len(insts)):
                a, b = insts[i], insts[j]
                for sa in plan.body(a):
                    for sb in plan.body(b):  # solid bodies never touch
                        self.assertGreaterEqual(plan.shape_gap(sa, sb), gap_min - 1e-6, (a["id"], b["id"]))
                for tree, other in ((a, b), (b, a)):  # roots keep other solids out; logs may rest on roots
                    if tree["name"] in TREES and other["name"] != "FK_FallenLog":
                        for roots in plan.footprint(tree):
                            for solid in plan.body(other):
                                self.assertGreaterEqual(plan.shape_gap(roots, solid), gap_min - 1e-6,
                                                        (tree["id"], other["id"]))

    # Rule 5
    def check_fog_is_denser_and_darker(self):
        d = self.layout["density"]
        self.assertEqual(d["area_sq_studs"], {"fog": FOG_AREA, "outside": OUT_AREA})
        counts = {"fog": {"forest_props": 0, "trees": 0, "all_instances": 0},
                  "outside": {"forest_props": 0, "trees": 0, "all_instances": 0}}
        for inst in self.layout["instances"]:
            zone = "fog" if in_fog(*xz(inst)) else "outside"
            counts[zone]["all_instances"] += 1
            counts[zone]["forest_props"] += inst["name"] in FOREST
            counts[zone]["trees"] += inst["name"] in TREES
        area = {"fog": FOG_AREA, "outside": OUT_AREA}
        for zone in ("fog", "outside"):
            for key, n in counts[zone].items():
                self.assertAlmostEqual(d["per_1000_sq_studs"][zone][key], n / area[zone] * 1000, delta=0.001)
        for key in ("forest_props", "trees"):
            fog, out = d["per_1000_sq_studs"]["fog"][key], d["per_1000_sq_studs"]["outside"][key]
            self.assertGreater(out, 0, key)
            self.assertGreaterEqual(fog, 2 * out, key)
            self.assertGreaterEqual(d["fog_to_outside_ratio"][key], 2.0)
        # "Darker": evergreen canopy shades a clearly larger share of the fog zone.
        cover = d["canopy_cover_fraction"]
        self.assertGreaterEqual(cover["fog"], 1.5 * cover["outside"])

    def check_deadwood_concentrates_in_fog(self):
        dead = by_name(self.layout, "FK_DeadTree", "FK_FallenLog")
        in_fog_count = sum(in_fog(*xz(i)) for i in dead)
        self.assertGreaterEqual(in_fog_count / len(dead), 0.75)
        fog_density = in_fog_count / FOG_AREA
        out_density = (len(dead) - in_fog_count) / OUT_AREA
        self.assertGreaterEqual(fog_density, 4 * out_density)

    # Rule 6
    def check_single_root_arch_is_first_landmark(self):
        (arch,) = by_name(self.layout, "FK_RootArch")
        a, b = SEGS[1]  # clearing -> ruin
        self.assertLess(seg_dist(xz(arch), a, b), 0.01)
        before_ruin = math.dist(xz(arch), RUIN)
        self.assertTrue(55 <= before_ruin <= 75, before_ruin)
        self.assertTrue(in_fog(*xz(arch)))
        # The passage (inner +/-9 wide, full depth) is inside the fog zone; the measured root
        # footprint (31.6 x 16.2) may overshoot the west fog edge by at most 2 studs.
        yaw = math.radians(arch["rotation_y_deg"])
        ex, ez = (math.cos(yaw), -math.sin(yaw)), (math.sin(yaw), math.cos(yaw))
        for half_x, limit in ((9.0, 0.0), (ARCH_HALF[0], 2.0)):
            for sgx in (-1, 1):
                for sgz in (-1, 1):
                    px = arch["x"] + sgx * half_x * ex[0] + sgz * ARCH_HALF[1] * ez[0]
                    pz = arch["z"] + sgx * half_x * ex[1] + sgz * ARCH_HALF[1] * ez[1]
                    over = max(FOG[0] - px, px - FOG[1], FOG[2] - pz, pz - FOG[3], 0.0)
                    self.assertLessEqual(over, limit, (px, pz))
        # First big landmark when travelling camp -> clearing -> ruin -> nest ...
        (door,) = by_name(self.layout, "FK_RuinDoorway")
        arch_arc, door_arc = project(xz(arch))[1], project(xz(door))[1]
        self.assertLess(arch_arc, door_arc)
        self.assertLess(arch_arc, CUM[2])  # before the ruin node itself

    def check_single_doorway_near_territory(self):
        (door,) = by_name(self.layout, "FK_RuinDoorway")
        seg = project(xz(door))[0]
        self.assertIn(seg, (2, 3))  # ruin -> nest or nest -> marsh
        self.assertTrue(in_territory(*xz(door)))
        pillar_shapes = [plan.rect_poly(px, pz, 1.5, 1.5, 0) for px, pz in PILLARS]
        for post in plan.footprint(door):
            for pillar in pillar_shapes:
                self.assertGreaterEqual(plan.shape_gap(post, pillar), 6.0)

    # Rule 7
    def lantern_data(self):
        lanterns = []
        for inst in by_name(self.layout, "FK_LanternMarker"):
            seg, arc, lateral = project(xz(inst))
            lanterns.append({"inst": inst, "arc": arc, "side": 1 if lateral > 0 else -1,
                             "offset": route_dist(xz(inst)), "seg": seg,
                             "territory": in_territory(*xz(inst))})
        lanterns.sort(key=lambda item: item["arc"])
        return lanterns

    def check_lanterns_follow_route_rhythm(self):
        lanterns = self.lantern_data()
        n = len(lanterns)
        self.assertGreaterEqual(n, 10)
        self.assertEqual(n % 2, 0, "alternation must close around the loop")
        for k, item in enumerate(lanterns):
            self.assertTrue(10.0 - 1e-6 <= item["offset"] <= 11.0 + 1e-6, item["inst"]["id"])
            prev = lanterns[k - 1]
            self.assertNotEqual(item["side"], prev["side"], item["inst"]["id"])
            gap = (item["arc"] - prev["arc"]) % LOOP
            if item["territory"]:
                self.assertTrue(60 <= gap <= 80, (item["inst"]["id"], gap))
            else:
                self.assertTrue(40 - 0.05 <= gap <= 55 + 0.05, (item["inst"]["id"], gap))
        self.assertTrue(any(item["territory"] for item in lanterns))
        # No lantern reveals more than the next one: lantern i+2 is always >= 80 away.
        for k in range(n):
            ahead = (lanterns[(k + 2) % n]["arc"] - lanterns[k]["arc"]) % LOOP
            self.assertGreaterEqual(ahead, 80 - 0.1)

    # Rule 8
    def trunks_and_pillars(self):
        blockers = [("pillar", p, 1.5, True) for p in PILLARS]
        for inst in by_name(self.layout, *TREES):
            blockers.append((inst["id"], xz(inst), CORE_R[inst["name"]] * inst["scale"], False))
        return blockers

    def independent_sight(self, wp):
        blocked = []
        for ident, centre, size, is_box in self.trunks_and_pillars():
            hit = segment_hits_box(wp, NEST, centre, size) if is_box else segment_hits_circle(wp, NEST, centre, size)
            if hit:
                blocked.append(ident)
        return blocked

    def check_nest_cover_and_patrol_sight(self):
        cover = [i for i in by_name(self.layout, *TREES)
                 if 13 <= math.dist(xz(i), NEST) <= 26]
        self.assertGreaterEqual(len(cover), 3)
        for inst in cover:
            self.assertGreaterEqual(route_dist(xz(inst)), 10.0 - 1e-6)
        report = self.layout["nest_cover"]
        self.assertEqual(report["eye_height"], EYE)
        self.assertGreaterEqual(report["cover_trunk_count"], 3)
        self.assertEqual(sorted(report["cover_trunk_ids"]), sorted(i["id"] for i in cover))
        seeing = 0
        for name, wp in PATROL.items():
            entry = report["sight"][name]
            self.assertEqual(tuple(entry["waypoint"]), wp)
            blockers = self.independent_sight(wp)
            self.assertEqual(entry["blocked"], bool(blockers), name)
            self.assertEqual(sorted(entry["blockers"]), sorted(blockers), name)
            self.assertAlmostEqual(entry["distance"], math.dist(wp, NEST), delta=0.01)
            seeing += not blockers
        self.assertGreaterEqual(seeing, 2)
        self.assertEqual(report["waypoints_seeing_nest"], seeing)
        # Every waypoint inside the night detection range (38) must see the nest: E by day and
        # night (23.6), N at night (35.1). S (46.1) and W (52.9) are out of range.
        for name, wp in PATROL.items():
            if math.dist(wp, NEST) <= 38:
                self.assertFalse(report["sight"][name]["blocked"], name)
        self.assertFalse(report["sight"]["E"]["blocked"])
        self.assertFalse(report["sight"]["N"]["blocked"])

    # Patrol loop
    def check_patrol_loop_stays_walkable(self):
        loop = list(PATROL.values())
        for inst in self.layout["instances"]:
            for shape in plan.body(inst):
                gap = plan.shape_polyline_dist(shape, loop, closed=True)
                self.assertGreaterEqual(gap, 4.0 - 1e-6, inst["id"])

    def check_patrol_loop_range_fractions(self):
        loop = list(PATROL.values())
        report = self.layout["nest_cover"]["patrol_loop_within_range"]
        total = inside28 = inside38 = 0
        for i, a in enumerate(loop):  # four equal edges, so sample fraction = length fraction
            b = loop[(i + 1) % len(loop)]
            for k in range(5000):
                t = (k + 0.5) / 5000
                d = math.dist((a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t), NEST)
                total += 1
                inside28 += d <= 28
                inside38 += d <= 38
        self.assertAlmostEqual(report["day_28"], inside28 / total, delta=0.003)
        self.assertAlmostEqual(report["night_38"], inside38 / total, delta=0.003)
        self.assertGreater(report["night_38"], report["day_28"])

    # Rule 9
    def check_budget(self):
        insts = self.layout["instances"]
        total = sum(TRIS[i["name"]] for i in insts)
        totals = self.layout["totals"]
        self.assertLessEqual(len(insts), 220)
        self.assertLessEqual(total, 95000)
        self.assertEqual(totals["instances"], len(insts))
        self.assertEqual(totals["triangles"], total)
        for name, tri in TRIS.items():
            n = len(by_name(self.layout, name))
            self.assertEqual(totals["by_name"][name], {"count": n, "triangles": n * tri})
        self.assertEqual(totals["budget"], {"max_instances": 220, "max_triangles": 95000})


class DefaultSeedRules(RuleChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = plan.generate(plan.DEFAULT_SEED)

    def test_schema(self):
        self.check_schema()

    def test_rule2_corridor_stays_clear(self):
        self.check_corridor_clear()

    def test_rule2_arch_and_doorway_are_centred_and_aligned(self):
        self.check_arch_and_doorway_straddle_route()

    def test_measured_arch_and_doorway_footprints_stay_reserved(self):
        self.check_landmark_footprints_are_reserved()

    def test_rule3_bases_stay_inside_the_map_edge(self):
        self.check_inside_map_edge()

    def test_rule4_no_trees_in_safe_circles(self):
        self.check_safe_circles_have_no_trees()

    def test_rule4_nest_and_clearing_stay_reachable(self):
        self.check_nest_and_clearing_stay_reachable()

    def test_rule4_roots_keep_off_route_nodes(self):
        self.check_roots_keep_off_route_nodes()

    def test_rule4_nothing_overlaps_pillars_stones_or_other_props(self):
        self.check_no_overlaps()

    def test_rule5_fog_is_denser_and_darker(self):
        self.check_fog_is_denser_and_darker()

    def test_rule5_deadwood_concentrates_in_fog(self):
        self.check_deadwood_concentrates_in_fog()

    def test_rule6_single_root_arch_is_the_first_landmark(self):
        self.check_single_root_arch_is_first_landmark()

    def test_rule6_single_doorway_near_territory_clear_of_pillars(self):
        self.check_single_doorway_near_territory()

    def test_rule7_lantern_rhythm(self):
        self.check_lanterns_follow_route_rhythm()

    def test_rule8_nest_cover_and_patrol_sight(self):
        self.check_nest_cover_and_patrol_sight()

    def test_rule8_patrol_loop_stays_walkable(self):
        self.check_patrol_loop_stays_walkable()

    def test_rule8_patrol_loop_range_fractions(self):
        self.check_patrol_loop_range_fractions()

    def test_rule9_budget(self):
        self.check_budget()


class AlternateSeeds(RuleChecks, unittest.TestCase):
    def test_every_rule_holds_for_other_seeds(self):
        checks = sorted(n for n in dir(RuleChecks) if n.startswith("check_"))
        self.assertGreaterEqual(len(checks), 18)
        for seed in ALT_SEEDS:
            self.layout = plan.generate(seed)
            for name in checks:
                with self.subTest(seed=seed, check=name):
                    getattr(self, name)()


class Reproducibility(unittest.TestCase):
    def test_rule1_same_seed_is_byte_identical(self):
        first = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        second = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        self.assertEqual(first, second)
        self.assertEqual(json.loads(first)["seed"], plan.DEFAULT_SEED)
        self.assertNotIn(b"\r", first)

    def test_rule1_different_seed_changes_the_forest(self):
        a = plan.generate(plan.DEFAULT_SEED)["instances"]
        b = plan.generate(ALT_SEEDS[0])["instances"]
        self.assertNotEqual([(i["x"], i["z"]) for i in a], [(i["x"], i["z"]) for i in b])

    def test_committed_json_matches_the_generator(self):
        path = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
        self.assertTrue(path.exists(), path)
        fresh = plan.to_json(plan.generate(plan.DEFAULT_SEED)).encode("utf-8")
        self.assertEqual(path.read_bytes(), fresh)


class Outputs(unittest.TestCase):
    def test_writes_json_svg_and_png_with_legend(self):
        layout = plan.generate(plan.DEFAULT_SEED)
        with tempfile.TemporaryDirectory() as tmp:
            paths = plan.write_outputs(layout, Path(tmp))
            names = sorted(p.name for p in paths)
            expected = ["forest-layout-v1.json", "forest-layout-v1.svg"]
            if HAVE_PILLOW:
                expected.append("forest-layout-v1.png")
            self.assertEqual(names, sorted(expected))
            svg = ET.parse(Path(tmp) / "forest-layout-v1.svg").getroot()
            self.assertTrue(svg.tag.endswith("svg"))
            text = " ".join("".join(el.itertext()) for el in svg.iter() if el.tag.endswith("text"))
            for needle in ("Legend", "FK_Evergreen", "FK_DeadTree", "FK_FallenLog", "FK_RootArch",
                           "FK_RuinDoorway", "FK_LanternMarker", "Fog zone", "territory",
                           "Safe circle", "Patrol loop (diamond", "OLD nest", "NEW nest", "Route corridor",
                           "Detail", "E (16,-85)", "N (0,-101)", "within 28", "within 38"):
                self.assertIn(needle, text)
            if HAVE_PILLOW:
                from PIL import Image
                with Image.open(Path(tmp) / "forest-layout-v1.png") as image:
                    self.assertGreaterEqual(image.size[0], 1400)
                    self.assertGreaterEqual(image.size[1], 900)


class GeometryAndSpec(unittest.TestCase):
    def test_prop_table_matches_measured_kit(self):
        self.assertEqual({k: v["tris"] for k, v in plan.PROPS.items()}, TRIS)
        self.assertEqual(plan.PROPS["FK_FallenLog"]["half"], LOG_HALF)
        self.assertEqual(plan.PROPS["FK_RootArch"]["half"], ARCH_HALF)
        self.assertEqual(plan.PROPS["FK_RuinDoorway"]["half"], DOOR_HALF)
        self.assertEqual(plan.PROPS["FK_RootArch"]["gap"], ARCH_GAP)
        self.assertEqual(plan.PROPS["FK_RuinDoorway"]["gap"], DOOR_GAP)
        for name in TREES:
            self.assertEqual(plan.PROPS[name]["roots_r"], ROOTS_R)
            self.assertEqual(plan.PROPS[name]["core_r"], CORE_R[name])
        self.assertEqual(plan.PROPS["FK_LanternMarker"]["base_r"], LANTERN_R)

    def test_prop_table_has_not_drifted_from_the_kit_report(self):
        if not KIT_REPORT.exists():
            self.skipTest("kit report not present")
        props = json.loads(KIT_REPORT.read_text(encoding="utf-8"))["props"]
        for name, spec in plan.PROPS.items():
            measured = props[name]
            self.assertEqual(spec["tris"], measured["triangles"], name)
            self.assertAlmostEqual(spec["height"], measured["size"][2], delta=0.01, msg=name)
            lo, hi = measured["bbox_min"], measured["bbox_max"]
            if "half" in spec:  # envelope is the symmetric bound of the measured X/Y bbox
                self.assertAlmostEqual(spec["half"][0], max(abs(lo[0]), abs(hi[0])), delta=0.001, msg=name)
                self.assertAlmostEqual(spec["half"][1], max(abs(lo[1]), abs(hi[1])), delta=0.001, msg=name)
            if "clearance" in measured:
                self.assertAlmostEqual(spec["gap"][0], measured["clearance"]["gap_low_x"], delta=0.001, msg=name)
                self.assertAlmostEqual(spec["gap"][1], measured["clearance"]["gap_high_x"], delta=0.001, msg=name)
                self.assertAlmostEqual(spec["clear_h"], measured["clearance"]["height"], delta=0.001, msg=name)

    def test_patrol_waypoints_are_the_games_diamond(self):
        expected = {"E": (16.0, -85.0), "S": (0.0, -69.0), "W": (-16.0, -85.0), "N": (0.0, -101.0)}
        self.assertEqual(list(plan.PATROL), ["E", "S", "W", "N"])  # visit order
        self.assertEqual(dict(plan.PATROL), expected)
        self.assertEqual(list(plan.PATROL_LOOP), list(expected.values()))
        self.assertEqual(plan.LANE_WAYPOINTS, ("E", "N"))
        self.assertEqual(PATROL, expected)
        for name, distance in (("E", 23.6), ("N", 35.1), ("S", 46.1), ("W", 52.9)):
            self.assertAlmostEqual(math.dist(expected[name], NEST), distance, delta=0.06, msg=name)

    def test_patrol_waypoints_match_the_luau_source(self):
        source = REPO / "src/wildbound/WildboundWorld.server.luau"
        if not source.exists():
            self.skipTest("WildboundWorld.server.luau not present")
        text = source.read_text(encoding="utf-8")
        block = text[text.index("local patrol = {"):]
        block = block[:block.index("}")]
        offsets = [(int(x), int(z)) for x, y, z in re.findall(r"home \+ Vector3\.new\((-?\d+), (-?\d+), (-?\d+)\)", block)]
        self.assertEqual(offsets, [(16, 0), (0, 16), (-16, 0), (0, -16)])
        self.assertEqual([(HOME[0] + dx, HOME[1] + dz) for dx, dz in offsets], list(PATROL.values()))

    def test_gaps_between_basic_shapes(self):
        c1, c2 = plan.Circle(0, 0, 1), plan.Circle(5, 0, 1)
        self.assertAlmostEqual(plan.shape_gap(c1, c2), 3.0)
        box = plan.rect_poly(0, 0, 1, 1, 0)
        self.assertAlmostEqual(plan.shape_gap(plan.Circle(5, 0, 1), box), 3.0)
        self.assertAlmostEqual(plan.shape_gap(box, plan.rect_poly(4, 0, 1, 1, 0)), 2.0)
        self.assertAlmostEqual(plan.shape_gap(box, plan.rect_poly(5, 0, 1, 1, 45)), 4 - math.sqrt(2), places=6)
        self.assertEqual(plan.shape_gap(box, plan.rect_poly(1, 1, 1, 1, 30)), 0.0)
        self.assertEqual(plan.shape_gap(c1, plan.Circle(1, 0, 1)), 0.0)

    def test_rotation_follows_the_roblox_yaw_convention(self):
        x0, z0, x1, z1 = plan.shape_bbox(plan.rect_poly(0, 0, 2, 1, 90))
        self.assertAlmostEqual(x0, -1)
        self.assertAlmostEqual(x1, 1)
        self.assertAlmostEqual(z0, -2)
        self.assertAlmostEqual(z1, 2)
        # Local +Z (depth axis) at yaw 90 points along world +X.
        ez = plan.local_axes(90)[1]
        self.assertAlmostEqual(ez[0], 1.0)
        self.assertAlmostEqual(ez[1], 0.0)

    def test_point_and_segment_distances(self):
        box = plan.rect_poly(0, 0, 1, 1, 0)
        self.assertAlmostEqual(plan.shape_point_dist(box, (4, 0)), 3.0)
        self.assertAlmostEqual(plan.shape_point_dist(box, (0.5, 0.5)), 0.0)
        self.assertAlmostEqual(plan.shape_segment_dist(plan.Circle(0, 5, 1), (-3, 0), (3, 0)), 4.0)
        self.assertEqual(plan.shape_segment_dist(box, (-3, 0), (3, 0)), 0.0)
        self.assertTrue(plan.segment_hits_shape((0, 0), (10, 0), plan.Circle(5, 0, 1)))
        self.assertFalse(plan.segment_hits_shape((0, 3), (10, 3), plan.Circle(5, 0, 1)))

    def test_footprints_use_measured_roots_and_envelopes(self):
        tree = {"name": "FK_Evergreen", "x": 10.0, "z": -4.0, "rotation_y_deg": 0.0, "scale": 1.5}
        (roots,) = plan.footprint(tree)
        (core,) = plan.body(tree)
        self.assertEqual((roots.x, roots.z), (10.0, -4.0))
        self.assertAlmostEqual(roots.r, ROOTS_R * 1.5)
        self.assertAlmostEqual(core.r, CORE_R["FK_Evergreen"] * 1.5)
        dead = dict(tree, name="FK_DeadTree", scale=1.0)
        self.assertAlmostEqual(plan.body(dead)[0].r, CORE_R["FK_DeadTree"])
        log = {"name": "FK_FallenLog", "x": 0.0, "z": 0.0, "rotation_y_deg": 90.0, "scale": 1.0}
        x0, z0, x1, z1 = plan.shape_bbox(plan.footprint(log)[0])
        self.assertAlmostEqual(z1 - z0, 2 * LOG_HALF[0], places=3)
        self.assertAlmostEqual(x1 - x0, 2 * LOG_HALF[1], places=3)
        for name, half in (("FK_RootArch", ARCH_HALF), ("FK_RuinDoorway", DOOR_HALF)):
            inst = {"name": name, "x": 0.0, "z": 0.0, "rotation_y_deg": 0.0, "scale": 1}
            shapes = plan.footprint(inst)
            self.assertEqual(len(shapes), 1)
            x0, z0, x1, z1 = plan.shape_bbox(shapes[0])
            self.assertAlmostEqual(x1 - x0, 2 * half[0], places=3)
            self.assertAlmostEqual(z1 - z0, 2 * half[1], places=3)
            self.assertEqual(plan.body(inst)[0], shapes[0])
        lantern = {"name": "FK_LanternMarker", "x": 1.0, "z": 2.0, "rotation_y_deg": 0.0, "scale": 1.0}
        self.assertAlmostEqual(plan.footprint(lantern)[0].r, LANTERN_R)


if __name__ == "__main__":
    unittest.main()
