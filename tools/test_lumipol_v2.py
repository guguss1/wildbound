"""Spec tests for Lumipol v2 (roadmap M3.6, rank 8; expansion bible 5.1, 5.2 and 5.9 rig rules).

Run with: python -I -B -m unittest discover -s tools -p "test_lumipol_v2.py"

Standard library only. Artifacts come from tools/build-lumipol-v2.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-lumipol-v2.py
  LUMIPOL_V2_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-lumipol-v2.py

The table below is the contract, written before the builder. Geometry, weights and per-frame
samples are recomputed here from the dumps, not read from the report's own arithmetic.
Lumipol v2 is a local art prototype: never imported into Roblox, so scale there, skinning in
Studio and mobile readability stay unverified. v1 (the blockout) is kept and checked untouched.
"""

import hashlib
import math
import unittest

import lumipol_motion_v2 as lumipol_motion
from kit_spec_common import (ROOT, AssetSpecMixin, asset_triangles, load_json, part_triangles)

V2_DIR = ROOT / "assets/blender/lumipol-roblox-v2"
EXPORT_DIR = ROOT / "assets/exports/species"
V1_BASE = ROOT / "assets/blender/lumipol-roblox-blockout-v1"
NAME = "SP_Lumipol"
FPS = 30
CLIPS = {"Idle": (3.0, 91), "Move": (2.0, 61)}  # seconds, frames at 30 fps (1 to N)
AVATAR_HEIGHT = 5.0
RUNTIME_PLACEHOLDER_FOOTPRINT = (3.0, 2.4)  # WildboundServer.server.luau:150, the body block of the stand-in

# size is (x, y, z) in studs; tris is the ceiling; parts map label to (hex, part ceiling).
SPECS = {
    NAME: {
        "size": (2.6, 2.4, 2.7), "tris": 900,
        "parts": {"Body": ("EBDDB8", 140), "Petals": ("FAF1D8", 300), "Dark": ("34363E", 230),
                  "Leaves": ("62B67F", 230), "Neon_Eye": ("4FE3EE", 40)},
        "bones": ("Root", "Body", "Tuft", "LeafL", "LeafR", "Tail", "FootFL", "FootFR", "FootBL", "FootBR"),
    },
}


def shells(part):
    """Vertex-connected shells of one dumped part, each as a list of coordinate triangles."""
    parent = list(range(len(part["vertices"])))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for triple in part["triangles"]:
        for other in triple[1:]:
            parent[find(other)] = find(triple[0])
    grouped = {}
    for triple in part["triangles"]:
        grouped.setdefault(find(triple[0]), []).append([part["vertices"][i] for i in triple])
    return list(grouped.values())


def shell_points(shell):
    return sorted({tuple(v) for triangle in shell for v in triangle})


def centroid(points):
    return tuple(sum(p[i] for p in points) / len(points) for i in range(3))


def directions(count=160):
    golden = math.pi * (3.0 - math.sqrt(5.0))
    out = []
    for k in range(count):
        z = 1.0 - 2.0 * (k + 0.5) / count
        r = math.sqrt(1.0 - z * z)
        out.append((r * math.cos(golden * k), r * math.sin(golden * k), z))
    return out


DIRECTIONS = directions()


def thickness_and_diameter(points):
    """Thinnest width over many directions, and the longest distance between two points."""
    thin = min(max(sum(p[i] * d[i] for i in range(3)) for p in points)
               - min(sum(p[i] * d[i] for i in range(3)) for p in points) for d in DIRECTIONS)
    diameter = max(math.dist(a, b) for a in points for b in points)
    return thin, diameter


def tip_ratio(points):
    """Width of the last 15% of a shell over its widest width, both measured off its long axis.

    The long axis runs from the centroid to the farthest vertex. A round blob scores about 0.53
    and a pointed petal or leaf scores well under 0.4.
    """
    middle = centroid(points)
    tip = max(points, key=lambda p: math.dist(p, middle))
    reach = math.dist(tip, middle)
    axis = tuple((tip[i] - middle[i]) / reach for i in range(3))

    def across(p):
        rel = tuple(p[i] - middle[i] for i in range(3))
        along = sum(rel[i] * axis[i] for i in range(3))
        return math.sqrt(max(0.0, sum(c * c for c in rel) - along * along)), along

    widths = [across(p) for p in points]
    widest = max(w for w, _ in widths)
    near_tip = max(w for w, along in widths if along >= 0.85 * reach)
    return near_tip / widest


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def hex_to_rgb(hex_color):
    return tuple(int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))


class LumipolAsset(AssetSpecMixin, unittest.TestCase):
    """G1 to G14 from the bible, for the one asset."""

    SPECS = SPECS
    ASSET_KEY = "species"
    REPORT = V2_DIR / "lumipol-roblox-v2-report.json"
    GEOMETRY = V2_DIR / "lumipol-roblox-v2-geometry.json"
    ROUNDTRIP = V2_DIR / "lumipol-roblox-v2-roundtrip.json"
    BLEND = V2_DIR / "lumipol-roblox-v2.blend"
    RENDER_DIR = V2_DIR
    EXPORT_DIR = EXPORT_DIR
    HEIGHT_CAP = AVATAR_HEIGHT


class LumipolRig(unittest.TestCase):
    """Rig rules from bible 5.9: every vertex weighted, two influences at most, Root fixed."""

    @classmethod
    def setUpClass(cls):
        cls.report = load_json(LumipolAsset.REPORT)
        cls.geometry = load_json(LumipolAsset.GEOMETRY)[NAME]
        cls.motion = load_json(V2_DIR / "lumipol-roblox-v2-motion.json")[NAME]
        cls.roundtrip = load_json(LumipolAsset.ROUNDTRIP)["species"][NAME]
        cls.entry = cls.report["species"][NAME]
        cls.bones = SPECS[NAME]["bones"]

    def test_bones_exact_and_in_order(self):
        self.assertEqual(tuple(self.geometry["bones"]), self.bones)
        self.assertEqual(tuple(self.entry["bones"]), self.bones)
        self.assertEqual(self.bones[0], "Root")
        self.assertEqual(len(set(self.bones)), len(self.bones))
        self.assertLessEqual(len(self.bones), 10, "R2 rig tier is 8 to 10 bones")

    def test_every_vertex_weighted_normalized_with_two_influences_at_most(self):
        for object_name, part in self.geometry["parts"].items():
            self.assertEqual(len(part["weights"]), len(part["vertices"]), object_name)
            for index, influences in enumerate(part["weights"]):
                where = f"{object_name} vertex {index}"
                self.assertTrue(1 <= len(influences) <= 2, where)
                self.assertAlmostEqual(sum(w for _, w in influences), 1.0, delta=1e-3, msg=where)
                for bone, weight in influences:
                    self.assertIn(bone, self.bones, where)
                    self.assertGreater(weight, 0.0, where)

    def test_every_triangle_references_valid_vertices(self):
        for object_name, part in self.geometry["parts"].items():
            count = len(part["vertices"])
            for triple in part["triangles"]:
                self.assertEqual(len(set(triple)), 3, f"{object_name} degenerate triangle")
                self.assertTrue(all(0 <= i < count for i in triple), object_name)

    def test_clips_listed_with_exact_timing(self):
        clips = self.entry["clips"]
        self.assertEqual(sorted(clips), sorted(CLIPS))
        for clip, (seconds, frames) in CLIPS.items():
            info = clips[clip]
            self.assertEqual(info["fps"], FPS)
            self.assertEqual((info["frame_start"], info["frame_end"]), (1, frames))
            self.assertAlmostEqual(info["duration_seconds"], seconds, places=6)
            self.assertEqual(info["action"], f"{NAME}_{clip}")

    def test_every_frame_sampled_with_finite_transforms(self):
        for clip, (_, frames) in CLIPS.items():
            data = self.motion[clip]
            self.assertEqual(len(data["frames"]), frames, f"{clip} must be sampled on every frame")
            self.assertEqual(data["bones"], list(self.bones))
            for index, frame in enumerate(data["frames"]):
                self.assertEqual(len(frame), len(self.bones))
                for row in frame:
                    self.assertEqual(len(row), 6)
                    self.assertTrue(all(math.isfinite(v) for v in row), f"{clip} frame {index + 1}")
            for object_name, box in data["mesh_bbox"].items():
                self.assertEqual(len(box), frames, object_name)
                self.assertTrue(all(math.isfinite(v) for pair in box for corner in pair for v in corner))

    def test_root_is_stationary_in_every_frame(self):
        expected = self.geometry["rest_bones"]["Root"]
        wanted = list(expected["head"]) + list(expected["tail"])
        for clip in CLIPS:
            for index, frame in enumerate(self.motion[clip]["frames"]):
                for got, want in zip(frame[0], wanted):
                    self.assertAlmostEqual(got, want, delta=1e-4, msg=f"{clip} frame {index + 1}")

    def test_bones_keep_their_length_so_nothing_scales(self):
        for clip in CLIPS:
            lengths = None
            for frame in self.motion[clip]["frames"]:
                now = [math.dist(row[:3], row[3:]) for row in frame]
                lengths = lengths or now
                for before, after in zip(lengths, now):
                    self.assertAlmostEqual(before, after, delta=2e-3)

    def test_loop_endpoint_mesh_error_is_zero_recomputed_from_dump(self):
        for clip in CLIPS:
            samples = self.motion[clip]["mesh_samples"]
            worst = 0.0
            for object_name, first in samples["first"].items():
                last = samples["last"][object_name]
                self.assertEqual(len(first), len(last))
                worst = max([worst] + [abs(a - b) for u, v in zip(first, last) for a, b in zip(u, v)])
            self.assertLessEqual(worst, 1e-5, f"{clip} loop endpoints differ")
            self.assertLessEqual(self.entry["clips"][clip]["loop_endpoint_error"], 1e-5)

    def test_clips_really_deform_the_mesh(self):
        for clip in CLIPS:
            samples = self.motion[clip]["mesh_samples"]
            moved = 0.0
            for object_name, first in samples["first"].items():
                for key in ("offbeat", "quarter", "middle"):
                    other = samples[key][object_name]
                    moved = max([moved] + [abs(a - b) for u, v in zip(first, other) for a, b in zip(u, v)])
            self.assertGreater(moved, 0.02, f"{clip} barely moves the mesh")

    def test_move_is_clearly_bigger_than_idle(self):
        def reach(clip):
            samples = self.motion[clip]["mesh_samples"]
            return max(abs(a - b) for name, first in samples["first"].items()
                       for key in ("offbeat", "quarter", "middle") for u, v in zip(first, samples[key][name])
                       for a, b in zip(u, v))

        self.assertGreater(reach("Move"), 2.0 * reach("Idle"))

    def test_clips_keep_the_creature_above_the_floor(self):
        for clip in CLIPS:
            lowest = min(corner[0][2] for box in self.motion[clip]["mesh_bbox"].values() for corner in box)
            self.assertGreaterEqual(lowest, -0.15, f"{clip} sinks into the ground")

    def test_model_and_clips_are_separate_fbx_files(self):
        files = self.entry["fbx"]
        self.assertEqual(sorted(files), ["Idle", "Move", "model"])
        self.assertEqual(files["model"], "assets/exports/species/SP_Lumipol_v2.fbx")
        for clip in CLIPS:
            self.assertEqual(files[clip], f"assets/exports/species/SP_Lumipol_v2_{clip}.fbx")

    def test_fbx_round_trip_keeps_bones_and_clip_duration(self):
        entry = self.roundtrip
        self.assertEqual(sorted(entry["model"]["bones"]), sorted(self.bones), "bones lost or leaf bones added")
        self.assertEqual(entry["model"]["actions"], [], "the model FBX must carry no baked clip")
        for clip, (seconds, frames) in CLIPS.items():
            imported = entry["clips"][clip]
            self.assertEqual(sorted(imported["bones"]), sorted(self.bones))
            self.assertGreater(imported["animated_channels"], 0)
            # Blender shifts an imported take by one frame (docs/assets/silueta-rig.md:57).
            self.assertAlmostEqual(imported["duration_seconds"], seconds, delta=1.0 / FPS)
            self.assertEqual(imported["keyed_frames"], frames)

    def test_everything_is_labelled_unvalidated_with_units_recorded(self):
        self.assertTrue(self.report["unvalidated"])
        self.assertEqual(self.report["studs_per_blender_unit"], 1.0)
        settings = self.report["fbx_settings"]
        self.assertEqual(settings["apply_scale_options"], "FBX_SCALE_UNITS")
        self.assertFalse(settings["add_leaf_bones"])
        self.assertEqual((settings["axis_forward"], settings["axis_up"]), ("-Z", "Y"))
        self.assertFalse(self.report["roblox_scale_verified"], "scale in Roblox is unverified until a real import")
        self.assertEqual(self.entry["status"], "unvalidated")


class LumipolDesign(unittest.TestCase):
    """What makes it Lumipol and what v2 fixes over the v1 blockout."""

    @classmethod
    def setUpClass(cls):
        cls.report = load_json(LumipolAsset.REPORT)
        cls.geometry = load_json(LumipolAsset.GEOMETRY)[NAME]
        cls.entry = cls.report["species"][NAME]

    def part(self, label):
        return self.geometry["parts"][f"{NAME}_{label}"]

    def test_petals_are_five_flat_pointed_plates(self):
        petals = shells(self.part("Petals"))
        self.assertEqual(len(petals), 5, "two collar petals plus a forelock of three")
        for shell in petals:
            points = shell_points(shell)
            thin, diameter = thickness_and_diameter(points)
            self.assertLessEqual(thin, 0.30 * diameter, "a petal is a plate, not a ball")
            self.assertLessEqual(tip_ratio(points), 0.42, "a petal ends in a point")

    def test_leaves_are_two_ears_and_a_tail_each_pointed(self):
        leaves = shells(self.part("Leaves"))
        self.assertEqual(len(leaves), 3)
        for shell in leaves:
            self.assertLessEqual(tip_ratio(shell_points(shell)), 0.42)
        tops = sorted(max(v[2] for t in shell for v in t) for shell in leaves)
        ears = [shell for shell in leaves if centroid(shell_points(shell))[2] > 1.4]
        tail = [shell for shell in leaves if centroid(shell_points(shell))[2] <= 1.4]
        self.assertEqual((len(ears), len(tail)), (2, 1), f"two ears above the body, one low tail; tops {tops}")
        self.assertGreater(centroid(shell_points(tail[0]))[1], 0.4, "the tail is behind the body (+Y)")
        heights = sorted(max(v[2] for t in shell for v in t) for shell in ears)
        self.assertGreater(heights[1] - heights[0], 0.25, "one ear angled and one upright, as in the studies")

    def test_four_feet_and_one_face_panel_share_the_dark_part(self):
        dark = shells(self.part("Dark"))
        self.assertEqual(len(dark), 5)
        feet = [s for s in dark if max(v[2] for t in s for v in t) < 0.9]
        face = [s for s in dark if s not in feet]
        self.assertEqual((len(feet), len(face)), (4, 1))
        for shell in feet:
            self.assertLessEqual(min(v[2] for t in shell for v in t), 0.05, "every foot stands on Z 0")
        xs = sorted(round(centroid(shell_points(s))[0], 2) for s in feet)
        self.assertLess(xs[1], 0.0)
        self.assertGreater(xs[2], 0.0)
        for shell in face:
            self.assertLess(centroid(shell_points(shell))[1], -0.4, "the face is on the front, which is -Y")

    def test_two_cyan_eyes_on_the_front_face(self):
        eyes = shells(self.part("Neon_Eye"))
        self.assertEqual(len(eyes), 2)
        centres = sorted(centroid(shell_points(s)) for s in eyes)
        self.assertLess(centres[0][0], 0.0)
        self.assertGreater(centres[1][0], 0.0)
        for centre in centres:
            self.assertLess(centre[1], -0.6)
            self.assertGreater(centre[2], 1.0)
        self.assertAlmostEqual(centres[0][2], centres[1][2], delta=0.1)
        red, green, blue = hex_to_rgb(SPECS[NAME]["parts"]["Neon_Eye"][0])
        self.assertTrue(blue > red and green > red, "cyan")

    def test_palette_keeps_the_studied_identity(self):
        cream, petals, dark, mint, cyan = (hex_to_rgb(SPECS[NAME]["parts"][k][0])
                                           for k in ("Body", "Petals", "Dark", "Leaves", "Neon_Eye"))
        for colour in (cream, petals):
            self.assertTrue(colour[0] >= colour[1] >= colour[2] and sum(colour) / 3 > 0.7, "cream")
        self.assertLess(sum(dark) / 3, 0.3, "charcoal")
        self.assertTrue(mint[1] > mint[0] and mint[1] > mint[2], "mint leaves are green-led")
        self.assertGreater(petals[0] + petals[1] + petals[2], cream[0] + cream[1] + cream[2],
                           "the petals read lighter than the body")

    def test_true_stud_scale_for_a_companion_at_the_players_feet(self):
        size = self.entry["size"]
        self.assertEqual(self.report["studs_per_blender_unit"], 1.0)
        self.assertGreaterEqual(size[2] / AVATAR_HEIGHT, 0.4)
        self.assertLessEqual(size[2] / AVATAR_HEIGHT, 0.65, "a pet never hides its owner")
        self.assertLessEqual(size[0], RUNTIME_PLACEHOLDER_FOOTPRINT[0])
        self.assertLessEqual(size[1], RUNTIME_PLACEHOLDER_FOOTPRINT[1])

    def test_unified_pivots(self):
        rest = self.geometry["rest_bones"]
        self.assertEqual(rest["Root"]["head"], [0.0, 0.0, 0.0], "one root pivot on the ground")
        self.assertTrue(self.entry["transforms_applied"])
        owned = {bone: [] for bone in SPECS[NAME]["bones"][1:]}
        for part in self.geometry["parts"].values():
            for vertex, influences in zip(part["vertices"], part["weights"]):
                for bone, weight in influences:
                    if weight >= 0.5 and bone in owned:
                        owned[bone].append(vertex)
        for bone, points in owned.items():
            self.assertTrue(points, f"{bone} owns no vertex")
            head = rest[bone]["head"]
            nearest = min(math.dist(head, p) for p in points)
            self.assertLessEqual(nearest, 0.6, f"{bone} pivot is far from the part it moves")

    def test_one_mesh_object_per_material_with_no_shared_materials(self):
        parts = self.entry["parts"]
        self.assertEqual(len(parts), len(SPECS[NAME]["parts"]))
        self.assertEqual(len({p["material"] for p in parts}), len(parts))

    def test_triangle_count_drops_below_the_v1_blockout(self):
        v1 = load_json(V1_BASE.with_name(V1_BASE.name + "-report.json"))
        self.assertLess(self.entry["triangles"], v1["triangles_total"])
        self.assertGreater(self.entry["triangles"], 0.4 * SPECS[NAME]["tris"])

    def test_every_part_is_a_set_of_closed_hand_faceted_shells(self):
        for label in SPECS[NAME]["parts"]:
            triangles = part_triangles(self.part(label))
            self.assertGreater(len(triangles), 20, label)
        self.assertEqual(len(asset_triangles(self.geometry)), self.entry["triangles"])


class V1IsKept(unittest.TestCase):
    """v1 stays exactly as shipped: its own report holds the hashes."""

    def test_v1_files_are_unchanged(self):
        report = load_json(V1_BASE.with_name(V1_BASE.name + "-report.json"))
        for suffix in (".blend", "-preview.png"):
            path = V1_BASE.with_name(V1_BASE.name + suffix)
            self.assertEqual(sha256(path), report[path.name + "_sha256"], path.name)

    def test_the_builder_for_v1_is_untouched_by_name(self):
        self.assertTrue((ROOT / "tools/build-lumipol-blockout.py").exists())
        self.assertNotEqual(V2_DIR, V1_BASE.parent)


class MotionProfiles(unittest.TestCase):
    """Pure pose profiles: no Blender needed."""

    bones = SPECS[NAME]["bones"]

    def test_registry_matches_the_spec_table(self):
        self.assertEqual(sorted(lumipol_motion.MOTION), [NAME])
        self.assertEqual(lumipol_motion.BONES[NAME], self.bones)

    def test_timing_constants(self):
        self.assertEqual(lumipol_motion.FPS, FPS)
        for clip, (seconds, frames) in CLIPS.items():
            self.assertEqual(lumipol_motion.DURATIONS[clip], seconds)
            self.assertEqual(lumipol_motion.frame_count(clip), frames)

    def test_every_profile_is_finite_bounded_and_root_stationary(self):
        for clip in CLIPS:
            for i in range(101):
                sample = lumipol_motion.pose(NAME, clip, i / 100)
                self.assertEqual(set(sample), set(self.bones))
                self.assertEqual(sample["Root"], (0.0,) * 6)
                for values in sample.values():
                    self.assertEqual(len(values), 6)
                    self.assertTrue(all(math.isfinite(v) for v in values))
                    self.assertTrue(all(abs(v) <= lumipol_motion.MAX_ANGLE for v in values[:3]))
                    self.assertTrue(all(abs(v) <= lumipol_motion.MAX_OFFSET for v in values[3:]))

    def test_loop_endpoints_match_exactly(self):
        for clip in CLIPS:
            self.assertEqual(lumipol_motion.pose(NAME, clip, 0), lumipol_motion.pose(NAME, clip, 1))

    def test_each_clip_moves_something_besides_root(self):
        for clip in CLIPS:
            strongest = max(abs(v) for t in (.13, .31, .62)
                            for bone, values in lumipol_motion.pose(NAME, clip, t).items()
                            if bone != "Root" for v in values)
            self.assertGreater(strongest, 0.03, clip)

    def test_move_walks_in_a_diagonal_gait(self):
        for t in (.1, .2, .3, .6, .8):
            pose = lumipol_motion.pose(NAME, "Move", t)
            self.assertAlmostEqual(pose["FootFL"][0], pose["FootBR"][0], places=9)
            self.assertAlmostEqual(pose["FootFR"][0], pose["FootBL"][0], places=9)
        pose = lumipol_motion.pose(NAME, "Move", .125)
        self.assertGreater(abs(pose["FootFL"][0] - pose["FootFR"][0]), 0.2, "diagonal pairs swing out of phase")

    def test_idle_stays_small_and_move_is_bigger(self):
        def biggest(clip):
            return max(abs(v) for i in range(101) for bone, values in lumipol_motion.pose(NAME, clip, i / 100).items()
                       for v in values[:3])

        self.assertLessEqual(biggest("Idle"), 0.3)
        self.assertGreater(biggest("Move"), biggest("Idle"))

    def test_invalid_inputs_fail_closed(self):
        for args in (("SP_Missing", "Idle", 0), (NAME, "Missing", 0), (NAME, "Idle", -.01), (NAME, "Idle", 1.01),
                     (NAME, "Idle", float("nan")), (NAME, "Idle", "0"), (NAME, "Idle", True)):
            with self.assertRaises(ValueError):
                lumipol_motion.pose(*args)


if __name__ == "__main__":
    unittest.main()
