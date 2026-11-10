"""Contracts for the Pradera Arcoiris top-down placement plan (DRAFT, unvalidated).

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p test_plan_pradera_layout.py

The spec numbers are restated here on purpose (docs/design/wildbound-biome-pradera.md): the tests
pin the design independently of the generator and re-derive each rule from the saved, rounded
instance data instead of trusting the generator's own report. Nothing here was imported into
Roblox, played or measured on a device.
"""

import json
import math
import tempfile
import unittest
from pathlib import Path

import layout_geometry as g
import plan_pradera_layout as plan

# ---- Spec inputs, restated independently of the module under test ----------
MAP_SIZE, LIMIT = 400.0, 195.0
MAX_INSTANCES, MAX_PARTS = 220, 1700
MIX = {"PA_GiantMushroom": 48, "PA_PuffTree": 30, "PA_MushroomRing": 12, "PA_PuffFlower": 40,
       "PA_SunflowerPost": 32, "PA_HillBoulder": 20, "PA_RainbowGate": 1, "PA_Pinwheel": 16, "PA_SetaTrueno": 1}
PARTS = {"PA_GiantMushroom": 8, "PA_PuffTree": 5, "PA_MushroomRing": 12, "PA_PuffFlower": 4, "PA_SunflowerPost": 4,
         "PA_HillBoulder": 1, "PA_RainbowGate": 23, "PA_Pinwheel": 6, "PA_SetaTrueno": 17}
HOME, POND_RADIUS, TORMENTA_RADIUS, LEASH = (150.0, 0.0), 28.0, 110.0, 90.0
GATE, GATE_SUN, PLAZA, SUN_RADIUS = (-186.0, 0.0), 25.0, (-40.0, 14.0), 12.0
ROUTE = [(-195.0, 0.0), (-140.0, 6.0), (-40.0, 14.0), (45.0, 4.0), (118.0, -4.0)]
CORRIDOR_HALF, BASE_GAP, WALK_SPEED = 7.0, 1.0, 16.0
WORLD_OFFSET = (300.0, 0.0)
BANDS = {"Legendaria": (0.0, 45.0), "Epica": (45.0, 80.0), "Rara": (80.0, 120.0), "Comun": (120.0, math.inf)}
SPECIES = {"Chispin": "Comun", "Musgon": "Comun", "Esponjin": "Rara", "Hongolin": "Epica", "Relampino": "Legendaria"}
STEM_R, CAP_R, TRUNK_R, CROWN_R = 2.5, 9.0, 1.2, 5.0
RING_R, FLOWER_R, POST_R, BOULDER_R, PINWHEEL_R = 3.5, 2.0, 1.5, 3.0, 1.0
GATE_HALF, SETA_STEM_R, SETA_CAP_R, SETA_CAP_TOP = (15.0, 3.0), 3.5, 13.0, 26.0
ROOF_REACH, MAX_SLOPE_DEG, NEST_RADIUS = 25.0, 25.0, 8.0
# La Abeja Reina, the event beast (user decision 2026-11-10): her ground never meets la Nube's.
HIVE, HIVE_CLEAR = (-75.0, 75.0), 10.0
ABEJA_GUARD, ABEJA_LEASH, ABEJA_WAKE, ABEJA_PATROL = 35.0, 45.0, 70.0, 18.0
ABEJA_BEAST_GAP, ABEJA_SUN_GAP, ABEJA_ROUTE_GAP = 15.0, 5.0, 3.0
EVENT_CLOCK = {"first_seconds": 300.0, "period_seconds": 1200.0, "window_seconds": 300.0}
FAIR_TELEGRAPH_FLOOR, PLAYER_WALK = 0.8, 16.0
ALT_SEEDS = (11, 4242)


def xz(inst):
    return (inst["x"], inst["z"])


def by_name(layout, *names):
    return [i for i in layout["instances"] if i["name"] in names]


def reach(inst):
    n, x, z, yaw, s = inst["name"], inst["x"], inst["z"], inst["rotation_y_deg"], inst["scale"]
    radius = {"PA_GiantMushroom": STEM_R, "PA_PuffTree": TRUNK_R, "PA_MushroomRing": RING_R, "PA_PuffFlower": FLOWER_R,
              "PA_SunflowerPost": POST_R, "PA_HillBoulder": BOULDER_R, "PA_Pinwheel": PINWHEEL_R,
              "PA_SetaTrueno": SETA_STEM_R}
    if n in radius:
        return g.Circle(x, z, radius[n] * s)
    return g.rect_poly(x, z, GATE_HALF[0], GATE_HALF[1], yaw)


def canopy(inst):
    return {"PA_GiantMushroom": CAP_R, "PA_PuffTree": CROWN_R, "PA_SetaTrueno": SETA_CAP_R}.get(inst["name"], 0.0) \
        * inst["scale"]


def hill_height(hills, x, z):
    best = 0.0
    for hill in hills:
        r, c = hill["sphere_radius"], hill["cap_height"]
        d = math.hypot(x - hill["x"], z - hill["z"])
        foot = math.sqrt(2 * r * c - c * c)
        if d < foot:
            best = max(best, (c - r) + math.sqrt(r * r - d * d))
    return best


def zone_of(x, z):
    if math.dist((x, z), GATE) <= GATE_SUN or math.dist((x, z), PLAZA) <= SUN_RADIUS:
        return "sol"
    return "tormenta" if math.dist((x, z), HOME) <= TORMENTA_RADIUS else "prado"


class RuleChecks:
    layout = None

    def solids(self):
        return [i for i in self.layout["instances"] if i["name"] != "PA_PuffFlower"]

    def check_schema(self):
        layout = self.layout
        for key in ("name", "biome", "status", "seed", "world", "caps", "totals", "route", "terrain", "zones",
                    "beast", "nests", "sun_circles", "abeja_event", "roof_coverage", "density", "instances"):
            self.assertIn(key, layout)
        self.assertIn("unvalidated", layout["status"])
        self.assertEqual(layout["biome"]["displayName"], "Pradera Arcoíris")
        self.assertEqual(layout["biome"]["beast"], "La Nube Gruñona")
        ids = [i["id"] for i in layout["instances"]]
        self.assertEqual(len(ids), len(set(ids)))
        for inst in layout["instances"]:
            for key in ("id", "name", "x", "y", "z", "rotation_y_deg", "scale", "zone"):
                self.assertIn(key, inst, inst.get("id"))
            self.assertIn(inst["name"], MIX)
            self.assertTrue(all(math.isfinite(inst[k]) for k in ("x", "y", "z", "rotation_y_deg", "scale")))
            self.assertIn(inst["zone"], ("sol", "prado", "tormenta"))

    def check_counts_and_budgets(self):
        names = [i["name"] for i in self.layout["instances"]]
        for name, count in MIX.items():
            self.assertEqual(names.count(name), count, name)
        self.assertEqual(len(names), 200)
        self.assertLessEqual(len(names), MAX_INSTANCES)
        totals = self.layout["totals"]
        self.assertEqual(totals["instances"], len(names))
        prop_parts = sum(PARTS[n] for n in names)
        self.assertGreaterEqual(totals["parts_estimate"], prop_parts)
        self.assertLessEqual(totals["parts_estimate"], MAX_PARTS)
        for name, entry in totals["by_name"].items():
            self.assertEqual(entry["count"], MIX[name])
            self.assertEqual(entry["parts"], MIX[name] * PARTS[name])
        self.assertEqual(self.layout["caps"], {"instances": MAX_INSTANCES, "parts": MAX_PARTS})

    def check_world_frame(self):
        world = self.layout["world"]
        self.assertEqual(tuple(world["offset"]), WORLD_OFFSET)
        self.assertEqual(world["sector_x"], [100.0, 500.0])
        self.assertAlmostEqual(world["gate_world"][0], GATE[0] + WORLD_OFFSET[0])
        self.assertLessEqual(world["gate_world"][0], 120.0, "the gate sits on the hub's east rim")
        self.assertGreaterEqual(world["gate_world"][0], 100.0)
        self.assertAlmostEqual(world["beast_home_world"][0], HOME[0] + WORLD_OFFSET[0])
        self.assertGreater(math.dist(HOME, GATE) - LEASH, 200.0, "her leash never comes near the gate")

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
        self.assertEqual(route["corridor_width"], 2 * CORRIDOR_HALF)
        self.assertLessEqual(ROUTE[0][0], -190.0, "the path starts at the gate on the west edge")
        self.assertGreater(math.dist(ROUTE[-1], HOME), POND_RADIUS + 2.0, "the path ends on the pond rim, dry")
        self.assertLess(math.dist(ROUTE[-1], HOME), POND_RADIUS + 8.0)

    def check_corridor_clearance(self):
        for inst in self.solids():
            if inst["name"] in ("PA_RainbowGate", "PA_SunflowerPost"):
                continue
            needed = CORRIDOR_HALF + (0.5 if inst["name"] == "PA_Pinwheel" else BASE_GAP)
            self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), ROUTE), needed - 1e-6, inst["id"])
        for inst in by_name(self.layout, "PA_PuffFlower"):
            self.assertGreaterEqual(g.shape_polyline_dist(reach(inst), ROUTE), 4.0 - 1e-6, inst["id"])

    def check_pond_is_clear_except_the_seta_trueno(self):
        for inst in self.layout["instances"]:
            if inst["name"] == "PA_SetaTrueno":
                continue
            self.assertGreater(math.dist(xz(inst), HOME), POND_RADIUS + g.shape_bound(reach(inst))[2], inst["id"])

    def check_gate(self):
        gate = by_name(self.layout, "PA_RainbowGate")[0]
        self.assertEqual(xz(gate), GATE)
        self.assertEqual(gate["scale"], 1)
        # The passage runs along +X (yaw 90): a child walks east through it from the hub.
        self.assertLess(abs(gate["rotation_y_deg"] - 90.0), 0.01)
        self.assertEqual(gate["zone"], "sol")
        # The arch clears 17.9 studs between its posts; the centreline passes within 1.5 studs of the pivot.
        self.assertLess(g.project_to_polyline(ROUTE, GATE)[0], 1.5, "the gate straddles the path")

    def check_sun_circles(self):
        circles = self.layout["sun_circles"]
        self.assertEqual(len(circles), 8)
        permanent = [c for c in circles if c["permanent"]]
        self.assertEqual([(c["x"], c["z"], c["radius"]) for c in permanent],
                         [(GATE[0], GATE[1], GATE_SUN), (PLAZA[0], PLAZA[1], SUN_RADIUS)])
        candidates = [c for c in circles if not c["permanent"]]
        self.assertEqual(len(candidates), 6)
        inside = 0
        for c in candidates:
            d = math.dist((c["x"], c["z"]), HOME)
            self.assertGreaterEqual(d, 60.0, c["id"])
            self.assertGreater(d, POND_RADIUS + SUN_RADIUS + 4.0, "never on the pond rim")
            self.assertEqual(c["radius"], SUN_RADIUS)
            self.assertLessEqual(max(abs(c["x"]), abs(c["z"])), LIMIT - SUN_RADIUS)
            self.assertGreaterEqual(g.shape_polyline_dist(g.Circle(c["x"], c["z"], SUN_RADIUS), ROUTE), 2.0 - 1e-6)
            self.assertEqual(hill_height(self.layout["terrain"]["hills"], c["x"], c["z"]), 0.0, "flat ground")
            inside += d <= TORMENTA_RADIUS
            for n in self.layout["nests"]:
                if not n["eventOnly"]:
                    self.assertGreaterEqual(math.dist((c["x"], c["z"]), (n["x"], n["z"])), SUN_RADIUS + NEST_RADIUS + 6 - 1e-6)
        self.assertGreaterEqual(inside, 2, "safety exists where she hunts")
        for a_index, a in enumerate(circles):
            for b in circles[a_index + 1:]:
                self.assertGreaterEqual(math.dist((a["x"], a["z"]), (b["x"], b["z"])), 35.0 + max(a["radius"], b["radius"])
                                        - SUN_RADIUS - 1e-6, f"{a['id']} {b['id']}")
        posts = by_name(self.layout, "PA_SunflowerPost")
        for c in circles:
            mine = [p for p in posts if p["sun_circle"] == c["id"]]
            self.assertEqual(len(mine), 4, c["id"])
            for p in mine:
                self.assertAlmostEqual(math.dist(xz(p), (c["x"], c["z"])), c["radius"] - 2.0, delta=0.01)

    def check_tormenta_roofs(self):
        roofs = [i for i in self.layout["instances"] if canopy(i) > 0.0]
        points = uncovered = 0
        v = -LIMIT
        while v <= LIMIT:
            w = -LIMIT
            while w <= LIMIT:
                if zone_of(v, w) == "tormenta" and math.dist((v, w), HOME) > POND_RADIUS:
                    points += 1
                    if not any(math.dist((v, w), xz(r)) <= canopy(r) + ROOF_REACH for r in roofs):
                        uncovered += 1
                w += 5.0
            v += 5.0
        self.assertGreater(points, 800)
        self.assertEqual(uncovered, 0, "every Tormenta point has a roof edge within 25 studs")
        self.assertEqual(self.layout["roof_coverage"]["uncovered"], 0)
        self.assertEqual(self.layout["roof_coverage"]["points"], points)

    def check_path_roofs(self):
        over = [m for m in by_name(self.layout, "PA_GiantMushroom")
                if g.project_to_polyline(ROUTE, xz(m))[0] <= 5.0 + canopy(m)]
        self.assertGreaterEqual(len(over), 4, "caps lean over the path so cover is taught on the way in")

    def check_mushrooms_grow_toward_the_pond(self):
        mushrooms = by_name(self.layout, "PA_GiantMushroom")
        for m in mushrooms:
            self.assertGreaterEqual(m["scale"], 0.8 - 1e-9)
            self.assertLessEqual(m["scale"], 1.3 + 1e-9)
            self.assertIn(m["cap"], ("Coral", "Sky", "Butter"))
        caps = [m["cap"] for m in mushrooms]
        self.assertEqual(sorted(caps.count(c) for c in ("Coral", "Sky", "Butter")), [16, 16, 16])
        tormenta = [m["scale"] for m in mushrooms if m["zone"] == "tormenta"]
        prado = [m["scale"] for m in mushrooms if m["zone"] == "prado"]
        self.assertGreaterEqual(len(tormenta), 8)
        self.assertGreater(sum(tormenta) / len(tormenta), sum(prado) / len(prado) + 0.1)
        for a_index, a in enumerate(mushrooms):
            for b in mushrooms[a_index + 1:]:
                self.assertGreaterEqual(math.dist(xz(a), xz(b)), 0.7 * (canopy(a) + canopy(b)) - 1e-6, f"{a['id']} {b['id']}")

    def check_trees(self):
        trees = by_name(self.layout, "PA_PuffTree")
        for a_index, a in enumerate(trees):
            self.assertGreaterEqual(math.dist(xz(a), HOME), 60.0, "trees stay out of the Legendaria heart")
            self.assertIn(a["puff"], ("Coral", "Sky", "Butter"))
            for b in trees[a_index + 1:]:
                self.assertGreaterEqual(math.dist(xz(a), xz(b)), 14.0 - 1e-6, f"{a['id']} {b['id']}")

    def check_nests(self):
        nests = self.layout["nests"]
        self.assertEqual([n["species"] for n in nests], list(SPECIES))
        for n in nests:
            self.assertEqual(n["rarity"], SPECIES[n["species"]])
            lo, hi = BANDS[n["rarity"]]
            d = math.dist((n["x"], n["z"]), HOME)
            if not n["eventOnly"]:  # the event egg is Legendaria by rule, wherever La Colmena stands
                self.assertTrue(lo <= d < hi, f"{n['species']} at {d:.1f} studs is not in the {n['rarity']} band")
            self.assertEqual(n["band"], n["rarity"])
            self.assertEqual(n["radius"], NEST_RADIUS)
            self.assertEqual(len(n["adultPoints"]), n["adults"])
            for p in n["adultPoints"]:
                self.assertAlmostEqual(math.dist((p["x"], p["z"]), (n["x"], n["z"])), 6.0, delta=0.01)
                self.assertAlmostEqual(math.hypot(p["faceX"], p["faceZ"]), 1.0, delta=0.01)
                self.assertGreater((p["x"] - n["x"]) * p["faceX"] + (p["z"] - n["z"]) * p["faceZ"], 0, "faces outward")
            for key in ("body", "accent", "eye", "glow"):
                self.assertRegex(n["colors"][key], r"^[0-9A-F]{6}$")
            if n["eventOnly"]:
                self.assertEqual(n["adults"], 0)
                self.assertEqual(n["species"], "Relampino")
                self.assertEqual((n["x"], n["z"]), HIVE, "the event nest sits at La Colmena, not on the Seta Trueno")
                self.assertEqual(n["y"], 0.0, "the egg pedestal stands on flat ground")
                self.assertGreater(math.dist((n["x"], n["z"]), HOME), TORMENTA_RADIUS, "outside la Nube's strike zone")
            else:
                self.assertGreaterEqual(n["adults"], 2)
                self.assertLessEqual(n["adults"], 3)
                self.assertEqual(n["y"], 0.0, "wild nests sit on flat ground")
                self.assertGreater(math.dist((n["x"], n["z"]), HOME), POND_RADIUS + NEST_RADIUS + 4.0)
                for solid in self.solids():
                    self.assertGreaterEqual(g.shape_point_dist(reach(solid), (n["x"], n["z"])), NEST_RADIUS + 2.0 - 1e-6,
                                            f"{solid['id']} crowds {n['id']}")
        first = nests[0]
        self.assertLessEqual(math.dist((first["x"], first["z"]), GATE), 80.0, "the first catch is visible from the arch")
        self.assertEqual(first["rarity"], "Comun")

    def check_hills(self):
        hills = self.layout["terrain"]["hills"]
        self.assertEqual(len(hills), 7)
        for hill in hills:
            r, c = hill["sphere_radius"], hill["cap_height"]
            foot = math.sqrt(2 * r * c - c * c)
            self.assertAlmostEqual(hill["footprint_radius"], foot, delta=0.01)
            self.assertLessEqual(math.degrees(math.acos((r - c) / r)), MAX_SLOPE_DEG, hill["id"])
            self.assertAlmostEqual(hill["slope_deg"], math.degrees(math.acos((r - c) / r)), delta=0.01)
            self.assertGreaterEqual(c, 6.0)
            self.assertLessEqual(c, 14.0)
            self.assertGreaterEqual(g.shape_polyline_dist(g.Circle(hill["x"], hill["z"], foot), ROUTE),
                                    CORRIDOR_HALF + 3.0, "the path stays flat")
            self.assertGreaterEqual(math.dist((hill["x"], hill["z"]), HOME) - foot, POND_RADIUS + 3.0)
            self.assertGreaterEqual(math.dist((hill["x"], hill["z"]), GATE) - foot, GATE_SUN + 2.0)
            self.assertGreaterEqual(math.dist((hill["x"], hill["z"]), PLAZA) - foot, SUN_RADIUS + 2.0)
            for n in self.layout["nests"]:
                self.assertGreaterEqual(math.dist((hill["x"], hill["z"]), (n["x"], n["z"])) - foot, NEST_RADIUS)
        for inst in self.layout["instances"]:
            expected = 0.0 if inst["name"] == "PA_SetaTrueno" else hill_height(hills, inst["x"], inst["z"])
            self.assertAlmostEqual(inst["y"], expected, delta=0.002, msg=inst["id"])
        self.assertGreater(sum(1 for b in by_name(self.layout, "PA_HillBoulder") if b["y"] > 0.5), 6,
                           "boulders perch on the hills")

    def check_no_solid_overlaps(self):
        solids = self.solids()
        shapes = {i["id"]: reach(i) for i in solids}
        for a_index, a in enumerate(solids):
            for b in solids[a_index + 1:]:
                self.assertGreaterEqual(g.shape_gap(shapes[a["id"]], shapes[b["id"]]), BASE_GAP - 1e-6,
                                        f"{a['id']} and {b['id']}")
        for flower in by_name(self.layout, "PA_PuffFlower"):
            for solid in solids:
                self.assertGreaterEqual(g.shape_gap(reach(flower), shapes[solid["id"]]), 0.3 - 1e-6,
                                        f"{flower['id']} sits inside {solid['id']}")

    def check_beast(self):
        beast = self.layout["beast"]
        self.assertEqual(tuple(beast["home"]), HOME)
        self.assertEqual(beast["leash"], LEASH)
        self.assertEqual(beast["strike_zone_radius"], TORMENTA_RADIUS)
        self.assertEqual(len(beast["waypoints"]), 6)
        for wp in beast["waypoints"]:
            self.assertAlmostEqual(math.dist(wp, HOME), 20.0, delta=0.01)
        seta = by_name(self.layout, "PA_SetaTrueno")[0]
        self.assertEqual(tuple(beast["seta_trueno"]), xz(seta))
        d = math.dist(xz(seta), HOME)
        self.assertGreater(d, 12.0)
        self.assertLess(d, POND_RADIUS - SETA_STEM_R, "the Seta Trueno stands in the shallows")
        self.assertEqual(self.layout["zones"]["bands"]["Epica"], [45.0, 80.0])

    def check_abeja_event(self):
        ev = self.layout["abeja_event"]
        self.assertEqual(ev["displayName"], "La Abeja Reina")
        self.assertEqual(tuple(ev["hive"]), HIVE)
        self.assertEqual(tuple(ev["hive_world"]), (HIVE[0] + WORLD_OFFSET[0], HIVE[1] + WORLD_OFFSET[1]))
        self.assertEqual((ev["patrol_radius"], ev["guard_radius"], ev["leash"], ev["wake_radius"]),
                         (ABEJA_PATROL, ABEJA_GUARD, ABEJA_LEASH, ABEJA_WAKE))
        self.assertLess(ev["patrol_radius"], ev["guard_radius"])
        self.assertLess(ev["guard_radius"], ev["leash"])
        self.assertLess(ev["leash"], ev["wake_radius"])
        self.assertEqual({k: ev["clock"][k] for k in EVENT_CLOCK}, EVENT_CLOCK)
        egg = next(n for n in self.layout["nests"] if n["eventOnly"])
        self.assertEqual(ev["egg_nest"], egg["id"])
        # Never two beasts on one player: her whole leash disc stays outside la Nube's strike zone, with a margin.
        self.assertGreaterEqual(math.dist(HIVE, HOME) - TORMENTA_RADIUS - ABEJA_LEASH, ABEJA_BEAST_GAP)
        # Safe places stay safe: no sun circle (permanent or candidate, the gate's included) touches her leash disc.
        for c in self.layout["sun_circles"]:
            self.assertGreaterEqual(math.dist(HIVE, (c["x"], c["z"])) - c["radius"] - ABEJA_LEASH, ABEJA_SUN_GAP, c["id"])
        self.assertGreater(math.dist(HIVE, GATE) - GATE_SUN - ABEJA_LEASH, 50.0, "far from the gate")
        # A child on the cream path is never inside her ground.
        self.assertGreaterEqual(g.project_to_polyline(ROUTE, HIVE)[0] - CORRIDOR_HALF - ABEJA_LEASH, ABEJA_ROUTE_GAP)
        self.assertLessEqual(max(abs(HIVE[0]), abs(HIVE[1])) + ABEJA_LEASH, LIMIT, "her leash stays in the sector")
        self.assertEqual(hill_height(self.layout["terrain"]["hills"], *HIVE), 0.0)
        for solid in self.solids():
            self.assertGreaterEqual(g.shape_point_dist(reach(solid), HIVE), HIVE_CLEAR - 1e-6, solid["id"])
        tuning = ev["tuning"]
        self.assertGreaterEqual(tuning["ABEJA_TELEGRAPH_SECONDS"], FAIR_TELEGRAPH_FLOOR)
        self.assertEqual(tuning["ABEJA_TELEGRAPH_FLOOR"], FAIR_TELEGRAPH_FLOOR)
        self.assertLess(tuning["ABEJA_CHASE_SPEED"], PLAYER_WALK, "walking away always works")
        self.assertGreater(tuning["ABEJA_STICKY_SPEED"], 8.0, "the shared carrySpeed > 8 contract holds")
        self.assertEqual(tuning["ABEJA_HEAR_STILL"], 0.0, "standing still is always silent")
        # Leaving the 6-stud lane from its centre at the honey speed beats the telegraph.
        self.assertLess((tuning["ABEJA_LANE_WIDTH"] / 2) / tuning["ABEJA_STICKY_SPEED"], tuning["ABEJA_TELEGRAPH_SECONDS"])

    def check_pinwheels_line_the_path(self):
        pinwheels = by_name(self.layout, "PA_Pinwheel")
        arcs = []
        for pw in pinwheels:
            distance, arc, _, _ = g.project_to_polyline(ROUTE, xz(pw))
            self.assertGreaterEqual(distance, 8.9, pw["id"])
            self.assertLessEqual(distance, 11.0, pw["id"])
            arcs.append(arc)
        arcs.sort()
        self.assertTrue(all(b - a >= 10.0 for a, b in zip(arcs, arcs[1:])), "pinwheels spread along the path")

    def check_flowers_gather_in_patches(self):
        flowers = by_name(self.layout, "PA_PuffFlower")
        patches = self.layout["density"]["flower_patches"]
        self.assertEqual(sum(patches), 40)
        self.assertGreaterEqual(len(patches), 6)
        self.assertGreaterEqual(sum(1 for f in flowers if f["zone"] == "tormenta"), 5, "Pelusa has a risky side too")

    def check_everything(self):
        for name in dir(self):
            if name.startswith("check_") and name != "check_everything":
                getattr(self, name)()


class DefaultSeed(RuleChecks, unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = json.loads(plan.to_json(plan.generate(plan.DEFAULT_SEED)))

    def test_schema(self):
        self.check_schema()

    def test_counts_and_budgets(self):
        self.check_counts_and_budgets()

    def test_world_frame(self):
        self.check_world_frame()

    def test_inside_the_sector(self):
        self.check_inside_the_sector()

    def test_route(self):
        self.check_route()

    def test_corridor_clearance(self):
        self.check_corridor_clearance()

    def test_pond_is_clear_except_the_seta_trueno(self):
        self.check_pond_is_clear_except_the_seta_trueno()

    def test_gate(self):
        self.check_gate()

    def test_sun_circles(self):
        self.check_sun_circles()

    def test_tormenta_roofs(self):
        self.check_tormenta_roofs()

    def test_path_roofs(self):
        self.check_path_roofs()

    def test_mushrooms_grow_toward_the_pond(self):
        self.check_mushrooms_grow_toward_the_pond()

    def test_trees(self):
        self.check_trees()

    def test_nests(self):
        self.check_nests()

    def test_hills(self):
        self.check_hills()

    def test_no_solid_overlaps(self):
        self.check_no_solid_overlaps()

    def test_beast(self):
        self.check_beast()

    def test_abeja_event(self):
        self.check_abeja_event()

    def test_pinwheels_line_the_path(self):
        self.check_pinwheels_line_the_path()

    def test_flowers_gather_in_patches(self):
        self.check_flowers_gather_in_patches()

    def test_generation_is_deterministic(self):
        self.assertEqual(plan.to_json(plan.generate(plan.DEFAULT_SEED)), plan.to_json(plan.generate(plan.DEFAULT_SEED)))

    def test_saved_layout_matches_the_default_seed(self):
        saved = plan.DEFAULT_OUT_DIR / (plan.LAYOUT_NAME + ".json")
        if not saved.exists():
            self.skipTest("layout not written yet")
        self.assertEqual(saved.read_text(encoding="utf-8"), plan.to_json(plan.generate(plan.DEFAULT_SEED)))

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
