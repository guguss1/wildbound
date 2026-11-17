"""Spec tests for the Caramelo v3 buildings and raft (owner sheets 01, 02, 03, 11).

Run from the repo root (isolated mode, no bytecode written):
  python -I -B -m unittest discover -s tools -p "test_caramelo_v3_buildings_kit.py"

Artifacts come from tools/build-caramelo-v3-buildings-kit.py, run headless in Blender 5.0:
  "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup -P tools/build-caramelo-v3-buildings-kit.py

The contract is tools/caramelo_v3_buildings_spec.py. The shared rules G1 to G14 (kit_spec_common) cover names,
budgets, sizes, closed outward meshes, one matte material per part and the part colours; the raft's pivot sits at
the waterline, so G4 and G13 read the spec's min_z instead of 0. The rest is recomputed from the geometry dump and
the collision data: doorways at least 6 x 9, flat floors, ceilings at least 12, rooms free of shell geometry and
shell collision, walls that stop an avatar in every direction but the door, a climbable spiral stair with
headroom, and a raft seat with a SeatAnchor and free room for the rider. Everything is unvalidated: nothing was
imported into Roblox.
"""

import math
import unittest

import caramelo_v3_buildings_spec as cs
from biome_kit_spec import top_height, triangle_overlaps_box
from kit_spec_common import (PIVOT_Z_TOLERANCE, AssetSpecMixin, asset_triangles, bounds, load_json,
                             part_triangles, png_size)

BUILDINGS = [n for n, s in cs.SPECS.items() if s["kind"] == "building"]
RAFT = "CV3_BananaRaft"


def box_contains(box, point):
    axes, c, h = cs.box_axes(box), box["center"], box["size"]
    d = [point[i] - c[i] for i in range(3)]
    return all(abs(sum(d[i] * axes[k][i] for i in range(3))) <= h[k] / 2 + 1e-6 for k in range(3))


class CarameloV3Kit(AssetSpecMixin, unittest.TestCase):
    SPECS = cs.SPECS
    ASSET_KEY = "props"
    REPORT, GEOMETRY, ROUNDTRIP, BLEND = cs.REPORT, cs.GEOMETRY, cs.ROUNDTRIP, cs.BLEND
    RENDER_DIR, EXPORT_DIR = cs.BLEND_DIR, cs.EXPORT_DIR

    # The raft floats: its pivot is the waterline centre, so the hull reaches below z 0 by its draft.
    def test_g4_pivot_at_ground_and_base_centre(self):
        for name, asset, dump in self.each_asset():
            triangles = asset_triangles(dump)
            low, high = bounds(triangles)
            self.assertAlmostEqual(low[2], self.SPECS[name]["min_z"], delta=PIVOT_Z_TOLERANCE)
            band = low[2] + (high[2] - low[2]) * 0.1
            base = [v for t in triangles for v in t if v[2] <= band]
            for axis in (0, 1):
                values = [v[axis] for v in base]
                self.assertLessEqual(abs((min(values) + max(values)) / 2), 1.0, f"axis {axis} base off the pivot")

    def test_g13_fbx_round_trip_keeps_triangles_size_and_floor(self):
        roundtrip = load_json(self.ROUNDTRIP)
        for name, asset, _ in self.each_asset():
            imported = roundtrip[self.ASSET_KEY][name]["model"]
            self.assertEqual(imported["triangles"], asset["triangles"])
            for measured, expected in zip(imported["size"], asset["size"]):
                self.assertAlmostEqual(measured, expected, delta=0.02)
            self.assertAlmostEqual(imported["min_z"], self.SPECS[name]["min_z"], delta=PIVOT_Z_TOLERANCE)
            self.assertIn(name, imported["objects"], "the Empty root survives the round trip")


class Buildings(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = load_json(cs.REPORT)["props"]
        cls.geometry = load_json(cs.GEOMETRY)

    def parts(self, name):
        return {obj[len(name) + 1:]: part_triangles(p) for obj, p in self.geometry[name]["parts"].items()}

    def each(self):
        for name in BUILDINGS:
            with self.subTest(asset=name):
                yield name, cs.SPECS[name], self.report[name], self.parts(name)

    def test_budget_and_footprint(self):
        for name, spec, entry, _ in self.each():
            self.assertLessEqual(entry["triangles"], cs.BUILDING_TRIS)
            footprint = sorted(entry["size"][:2])
            if name == "CV3_CaramelTower":
                self.assertLessEqual(footprint[1], 28.0, "tower about 20 wide (its cap overhangs)")
                self.assertGreaterEqual(entry["size"][2], 45.0, "tower about 50 tall")
            else:
                self.assertGreaterEqual(footprint[0], 24.0)
                self.assertLessEqual(footprint[1], 32.0)

    def test_doorways_are_at_least_6_wide_and_9_tall(self):
        for name, spec, entry, parts in self.each():
            every = [t for tris in parts.values() for t in tris]
            self.assertEqual(len(entry["doors"]), len(spec["doors"]))
            for door, reported in zip(spec["doors"], entry["doors"]):
                found = cs.doorway_clearance(every, door)
                self.assertGreaterEqual(found["width"], cs.DOOR_MIN_WIDTH, door["name"])
                self.assertGreaterEqual(found["width"], door["width"] - 0.01, door["name"])
                self.assertGreaterEqual(found["height"], cs.DOOR_MIN_HEIGHT, door["name"])
                self.assertGreaterEqual(found["height"], door["height"] - 0.01, door["name"])
                self.assertLessEqual(found["gap_low_x"], door["center_x"] - cs.DOOR_MIN_WIDTH / 2)
                self.assertGreaterEqual(found["gap_high_x"], door["center_x"] + cs.DOOR_MIN_WIDTH / 2)
                self.assertAlmostEqual(reported["measured"]["width"], found["width"], delta=0.01)
                self.assertAlmostEqual(reported["measured"]["height"], found["height"], delta=0.01)

    def test_no_collision_box_blocks_a_doorway(self):
        for name, spec, entry, _ in self.each():
            for door in spec["doors"]:
                volume = cs.door_volume(door)
                blocking = [b["name"] for b in entry["collision_boxes"] if cs.boxes_overlap(b, volume)]
                self.assertEqual(blocking, [], door["name"])

    def test_floors_are_flat_and_collide_at_floor_height(self):
        for name, spec, entry, parts in self.each():
            for room in spec["rooms"]:
                levels = cs.floor_levels(parts["Floor"], room)
                self.assertNotIn(None, levels, f"{room['name']}: hole in the floor")
                for level in levels:
                    self.assertAlmostEqual(level, room["floor"], delta=0.01, msg=room["name"])
                tops = []
                for x, y in cs.grid(room["rect"]):
                    under = [cs.box_z_range(b)[1] for b in entry["collision_boxes"]
                             if not cs.is_fitout(b["name"]) and cs.box_contains_xy(b, x, y)
                             and cs.box_z_range(b)[1] <= room["floor"] + 0.01]
                    tops.append(max(under) if under else None)
                self.assertNotIn(None, tops, f"{room['name']}: no floor collision under part of the room")
                for top in tops:
                    self.assertAlmostEqual(top, room["floor"], delta=0.01)

    def test_ceilings_are_at_least_12(self):
        for name, spec, entry, parts in self.each():
            shell = [t for label in spec["shell"] for t in parts[label]]
            for room, reported in zip(spec["rooms"], entry["rooms"]):
                ceiling = cs.room_ceiling(shell, room)
                self.assertGreaterEqual(ceiling, cs.CEILING_MIN, room["name"])
                self.assertAlmostEqual(reported["ceiling_measured"], ceiling, delta=0.01)

    def test_rooms_hold_no_shell_geometry_or_shell_collision(self):
        for name, spec, entry, parts in self.each():
            for room in spec["rooms"]:
                box = cs.room_volume(room)
                low = [box["center"][i] - box["size"][i] / 2 for i in range(3)]
                high = [box["center"][i] + box["size"][i] / 2 for i in range(3)]
                for label in spec["shell"]:
                    hits = [t for t in parts[label] if triangle_overlaps_box(t, low, high)]
                    self.assertEqual(len(hits), 0, f"{room['name']}: {label} enters the room")
                inside = [b["name"] for b in entry["collision_boxes"]
                          if not cs.is_fitout(b["name"]) and cs.boxes_overlap(b, box)]
                self.assertEqual(inside, [], room["name"])

    def test_walls_stop_the_avatar_everywhere_but_the_doors(self):
        """Walk out from each room centre in 24 directions at knee height: a wall, gable or rail box must stop
        every walk except one that leaves through a doorway (and every room must have such a way out)."""
        for name, spec, entry, _ in self.each():
            barriers = [b for b in entry["collision_boxes"]
                        if not cs.is_fitout(b["name"]) or b["name"].startswith("Rail_")]
            doors = [cs.door_volume(d) for d in spec["doors"]]
            for room in spec["rooms"]:
                (x0, y0), (x1, y1) = room["rect"]
                start = ((x0 + x1) / 2, (y0 + y1) / 2, room["floor"] + 2.0)
                exits = 0
                for k in range(24):
                    angle = math.radians(15.0 * k)
                    direction = (math.cos(angle), math.sin(angle))
                    stopped = through_door = False
                    for step in range(1, 120):
                        p = (start[0] + direction[0] * 0.25 * step, start[1] + direction[1] * 0.25 * step, start[2])
                        if any(box_contains(d, p) for d in doors):
                            through_door = True
                            break
                        if any(box_contains(b, p) for b in barriers):
                            stopped = True
                            break
                    exits += through_door
                    self.assertTrue(stopped or through_door, f"{room['name']}: an avatar walks out at {15 * k} deg")
                self.assertGreaterEqual(exits, 1, f"{room['name']}: no walk leaves through a door")

    def test_collision_boxes_are_named_simple_and_inside_the_model(self):
        for name, spec, entry, parts in self.each():
            boxes = entry["collision_boxes"]
            names = [b["name"] for b in boxes]
            self.assertEqual(len(names), len(set(names)), "collision names are unique")
            for required in spec["collision"]:
                self.assertIn(required, names)
            self.assertGreaterEqual(sum(1 for n in names if n.startswith(("Wall", "Gable"))), 4)
            low, high = bounds([t for tris in parts.values() for t in tris])
            for box in boxes:
                self.assertEqual(sum(1 for r in box["rot_deg"] if abs(r) > 1e-9) <= 1, True, box["name"])
                self.assertTrue(all(s > 0 for s in box["size"]), box["name"])
                for corner in cs.box_corners(box):
                    for axis in range(3):
                        self.assertGreaterEqual(corner[axis], low[axis] - 0.6, box["name"])
                        self.assertLessEqual(corner[axis], high[axis] + 0.6, box["name"])

    def test_every_room_has_furniture(self):
        for name, spec, entry, _ in self.each():
            names = [b["name"] for b in entry["collision_boxes"]]
            props = [n for n in names if n.startswith("Prop_")]
            self.assertGreaterEqual(len(props), 4)
            self.assertTrue(any("Table" in n for n in props))
            self.assertGreaterEqual(sum(1 for n in props if "Chair" in n), 1 if name == "CV3_CaramelTower" else 2)
            self.assertTrue(any("Shelf" in n for n in props))
            for label in ("Furniture", "Cushion"):
                self.assertIn(f"{name}_{label}", self.geometry[name]["parts"])
            for room in spec["rooms"]:
                inside = [b for b in entry["collision_boxes"] if b["name"].startswith("Prop_")
                          and abs(cs.box_z_range(b)[0] - room["floor"]) < 0.01]
                self.assertGreaterEqual(len(inside), 2, f"{room['name']} needs furniture")

    def test_roblox_frame_matches_the_blender_boxes(self):
        for name, spec, entry, _ in self.each():
            for box, rb in zip(entry["collision_boxes"], entry["collision_roblox"]):
                self.assertEqual(rb, cs.roblox_box(box))
                self.assertEqual(rb["position"], [-box["center"][0], box["center"][2], box["center"][1]])


class Tower(unittest.TestCase):
    """The tower's upper floor is reached by a spiral stair; the balcony door opens off the upper room."""

    @classmethod
    def setUpClass(cls):
        cls.entry = load_json(cs.REPORT)["props"]["CV3_CaramelTower"]
        cls.boxes = {b["name"]: b for b in cls.entry["collision_boxes"]}
        cls.steps = [cls.boxes[f"Stair_{i:02d}"] for i in range(cs.SPECS["CV3_CaramelTower"]["stairs"])]
        cls.geometry = load_json(cs.GEOMETRY)["CV3_CaramelTower"]

    def test_steps_climb_from_the_floor_to_the_upper_floor(self):
        tops = [cs.box_z_range(s)[1] for s in self.steps]
        self.assertLessEqual(tops[0] - cs.TOWER["floor"], cs.MAX_STEP_RISE)
        for a, b in zip(tops, tops[1:]):
            self.assertGreater(b, a)
            self.assertLessEqual(b - a, cs.MAX_STEP_RISE)
        self.assertAlmostEqual(tops[-1], cs.TOWER["upper"], delta=0.01, msg="top step flush with the upper floor")
        upper = [b for n, b in self.boxes.items() if n.startswith("Upper_Floor")]
        self.assertTrue(upper)
        for box in upper:
            self.assertAlmostEqual(cs.box_z_range(box)[1], cs.TOWER["upper"], delta=0.01)

    def test_steps_are_wide_enough_and_turn_round_the_newel(self):
        for step in self.steps:
            self.assertGreaterEqual(step["size"][0], 4.5, "radial tread length")
            self.assertGreaterEqual(step["size"][1], 2.0, "tangential tread width")
        yaws = [s["rot_deg"][2] for s in self.steps]
        self.assertAlmostEqual(yaws[-1] - yaws[0], 337.5, delta=0.01)

    def test_headroom_over_every_step(self):
        for i, step in enumerate(self.steps):
            x, y = step["center"][:2]
            top = cs.box_z_range(step)[1]
            skip = {f"Stair_{j:02d}" for j in (i - 1, i, i + 1)} | {"Newel"}
            for name, box in self.boxes.items():
                if name in skip or not cs.box_contains_xy(box, x, y):
                    continue
                bottom = cs.box_z_range(box)[0]
                if bottom >= top - 0.01:
                    self.assertGreaterEqual(bottom - top, cs.STAIR_HEADROOM, f"{name} over step {i}")

    def test_stair_exit_meets_the_upper_floor_and_the_rails_leave_it_open(self):
        last = self.steps[-1]
        exit_point = (cs.TOWER["step_out"] - 1.0, 0.6)
        self.assertTrue(any(cs.box_contains_xy(b, *exit_point) for n, b in self.boxes.items()
                            if n.startswith("Upper_Floor")), "floor just past the last step")
        for name in ("Rail_Upper_L", "Rail_Upper_R"):
            self.assertFalse(cs.boxes_overlap(self.boxes[name], last), name)
            self.assertFalse(cs.box_contains_xy(self.boxes[name], *exit_point), name)

    def test_balcony_has_floor_and_three_rails(self):
        floor = self.boxes["Balcony_Floor"]
        self.assertAlmostEqual(cs.box_z_range(floor)[1], cs.TOWER["upper"], delta=0.01)
        self.assertGreater(floor["center"][1] + floor["size"][1] / 2, cs.TOWER["r1_out"], "outside the wall")
        for name in ("Rail_Balcony_F", "Rail_Balcony_L", "Rail_Balcony_R"):
            low, high = cs.box_z_range(self.boxes[name])
            self.assertGreaterEqual(high - cs.TOWER["upper"], 3.0, name)


class Raft(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.spec = cs.SPECS[RAFT]
        cls.entry = load_json(cs.REPORT)["props"][RAFT]
        cls.geometry = load_json(cs.GEOMETRY)[RAFT]
        cls.roundtrip = load_json(cs.ROUNDTRIP)["props"][RAFT]["model"]
        cls.parts = {obj[len(RAFT) + 1:]: part_triangles(p) for obj, p in cls.geometry["parts"].items()}

    def test_budget_and_size(self):
        self.assertLessEqual(self.entry["triangles"], cs.RAFT_TRIS)
        width, length = self.entry["size"][:2]
        self.assertAlmostEqual(length, 14.0, delta=1.0)
        self.assertAlmostEqual(width, 8.0, delta=1.0)

    def test_seat_anchor_is_exported_at_the_seat_and_faces_forward(self):
        anchor = self.entry["seat_anchor"]
        self.assertEqual(anchor["name"], "SeatAnchor")
        self.assertEqual(self.entry["anchors"]["SeatAnchor"], list(self.spec["seat"]["position"]))
        self.assertEqual(anchor["roblox"], cs.to_roblox(self.spec["seat"]["position"]))
        self.assertEqual(anchor["forward_roblox"], [0.0, 0.0, -1.0])
        self.assertIn("SeatAnchor", self.roundtrip["objects"], "the Empty survives the FBX round trip")
        x, y, z = self.spec["seat"]["position"]
        self.assertAlmostEqual(top_height(self.parts["Seat"], x, y), z, delta=0.01, msg="anchor on the cushion top")
        self.assertLess(abs(x), 0.01, "seat on the centre line")

    def test_rider_headroom_is_free_of_every_triangle(self):
        low, high = self.spec["seat"]["headroom"]
        for label, triangles in self.parts.items():
            hits = [t for t in triangles if triangle_overlaps_box(t, low, high)]
            self.assertEqual(len(hits), 0, f"{label} in the rider's space")
        box = cs.aabb_box(low, high)
        for b in self.entry["collision_boxes"]:
            self.assertFalse(cs.boxes_overlap(b, box), b["name"])

    def test_hull_floats_at_the_waterline_and_decorations_are_separate(self):
        hull_low = min(v[2] for t in self.parts["Hull"] for v in t)
        self.assertAlmostEqual(hull_low, -cs.RAFT["draft"], delta=0.05)
        self.assertLess(hull_low, 0.0)
        for label in ("ScoopPink", "ScoopVanilla", "Cream", "Cherry", "Stem", "Sprinkles"):
            self.assertIn(label, self.parts)
            self.assertGreater(min(v[2] for t in self.parts[label] for v in t), 0.5, f"{label} sits on the deck")
        scoops = [v for label in ("ScoopPink", "ScoopVanilla") for t in self.parts[label] for v in t]
        self.assertLess(max(v[1] for v in scoops), self.spec["seat"]["headroom"][0][1], "scoops ride at the bow")

    def test_collision_is_a_few_simple_boxes(self):
        names = [b["name"] for b in self.entry["collision_boxes"]]
        self.assertEqual(sorted(names), sorted(self.spec["collision"]))
        hull = next(b for b in self.entry["collision_boxes"] if b["name"] == "Hull")
        self.assertAlmostEqual(cs.box_z_range(hull)[0], -cs.RAFT["draft"], delta=0.05)
        seat = next(b for b in self.entry["collision_boxes"] if b["name"] == "Seat_Base")
        self.assertAlmostEqual(cs.box_z_range(seat)[1], self.spec["seat"]["position"][2], delta=0.01)


class Outputs(unittest.TestCase):
    def test_cutaway_renders_exist(self):
        for name in cs.SPECS:
            with self.subTest(asset=name):
                self.assertEqual(png_size(cs.BLEND_DIR / f"{name}_cutaway.png"), (800, 800))

    def test_one_fbx_per_asset_and_readme_lists_them(self):
        fbx = sorted(p.name for p in cs.EXPORT_DIR.glob("*.fbx"))
        self.assertEqual(fbx, sorted(f"{name}.fbx" for name in cs.SPECS))
        text = cs.README.read_text(encoding="utf-8")
        entries = load_json(cs.REPORT)["props"]
        for name, spec in cs.SPECS.items():
            self.assertIn(f"{name}.fbx", text)
            for box in spec["collision"]:
                self.assertIn(box, text, f"{name}: README lists {box}")
            for door in entries[name].get("doors", []):
                self.assertIn(f"{door['name']} door", text)
        self.assertIn("SeatAnchor", text)


if __name__ == "__main__":
    unittest.main()
