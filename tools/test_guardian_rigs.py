"""Spec tests for the Wildbound guardian rigs (expansion bible 5.1, 5.2 and 5.10).

Run with: python -I -B -m unittest discover -s tools -p "test_guardian_rigs.py"

Standard library only. Artifacts come from tools/build-guardian-rigs.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-guardian-rigs.py
  GUARDIAN_RIGS_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-guardian-rigs.py

The guardian table below is the contract, copied from the bible, not from the builder.
Geometry, weights and per-frame samples are recomputed here from the dumps.
Every guardian is labelled unvalidated: nothing was imported into Roblox, and the scale
in Roblox stays unverified until a real import.
"""

import math
import unittest

import guardian_motion
from kit_spec_common import (ROOT, AssetSpecMixin, asset_triangles, bounds, load_json, part_triangles)

GUARDIAN_DIR = ROOT / "assets/blender/guardians"
EXPORT_DIR = ROOT / "assets/exports/guardians"
FPS = 30

YETI_BONES = ("Root", "Pelvis", "Spine", "Chest", "Neck", "Head",
              "UpperArm.L", "Forearm.L", "Hand.L", "UpperArm.R", "Forearm.R", "Hand.R",
              "Thigh.L", "Shin.L", "Foot.L", "Thigh.R", "Shin.R", "Foot.R")

# size is (x, y, z) in studs; tris is the budget; parts map label to (hex, part budget).
# clips map name to (seconds, frames at 30 fps from 1 to N, loops).
SPECS = {
    "GD_Yeti": {
        "size": (11.0, 9.0, 11.0), "tris": 1500,
        "parts": {"Hide": ("3D3A3E", 760), "Ice": ("9CCBE0", 340), "Mask": ("3F4247", 180),
                  "Hands": ("2B2A2E", 180), "Neon_Eye": ("7FB8C9", 40)},
        "bones": YETI_BONES,
        "clips": {"Idle": (3.0, 91, True), "Stalk": (2.0, 61, True), "Sniff": (3.0, 91, True),
                  "Telegraph": (1.8, 55, False), "Charge": (1.0, 31, True), "Recover": (2.0, 61, False)},
        "strike_clip": "Charge",
    },
}


def clip_table(name):
    return {clip: (seconds, frames) for clip, (seconds, frames, _) in SPECS[name]["clips"].items()}


def loop_clips(name):
    return [clip for clip, (_, _, loops) in SPECS[name]["clips"].items() if loops]


class GuardianAssets(AssetSpecMixin, unittest.TestCase):
    SPECS = SPECS
    ASSET_KEY = "guardians"
    REPORT = GUARDIAN_DIR / "guardian-report.json"
    GEOMETRY = GUARDIAN_DIR / "guardian-geometry.json"
    ROUNDTRIP = GUARDIAN_DIR / "fbx-roundtrip.json"
    BLEND = GUARDIAN_DIR / "guardians-v1.blend"
    RENDER_DIR = GUARDIAN_DIR
    EXPORT_DIR = EXPORT_DIR
    HEIGHT_CAP = None  # guardians may stand above 5 studs (bible 5.10)


class GuardianRigs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = load_json(GuardianAssets.REPORT)
        cls.geometry = load_json(GuardianAssets.GEOMETRY)
        cls.motion = load_json(GUARDIAN_DIR / "guardian-motion.json")
        cls.roundtrip = load_json(GuardianAssets.ROUNDTRIP)

    def each_guardian(self):
        for name, spec in SPECS.items():
            with self.subTest(guardian=name):
                yield name, spec

    def test_bones_exact_and_in_order(self):
        for name, spec in self.each_guardian():
            self.assertEqual(tuple(self.geometry[name]["bones"]), spec["bones"])
            self.assertEqual(tuple(self.report["guardians"][name]["bones"]), spec["bones"])
            self.assertEqual(spec["bones"][0], "Root")
            self.assertEqual(len(set(spec["bones"])), len(spec["bones"]))

    def test_every_vertex_weighted_normalized_with_two_influences_at_most(self):
        for name, spec in self.each_guardian():
            bones = set(spec["bones"])
            for object_name, part in self.geometry[name]["parts"].items():
                self.assertEqual(len(part["weights"]), len(part["vertices"]), object_name)
                for index, influences in enumerate(part["weights"]):
                    where = f"{object_name} vertex {index}"
                    self.assertTrue(1 <= len(influences) <= 2, where)
                    self.assertAlmostEqual(sum(w for _, w in influences), 1.0, delta=1e-3, msg=where)
                    for bone, weight in influences:
                        self.assertIn(bone, bones, where)
                        self.assertGreater(weight, 0.0, where)

    def test_every_triangle_references_valid_vertices(self):
        for name, spec in self.each_guardian():
            for object_name, part in self.geometry[name]["parts"].items():
                count = len(part["vertices"])
                for triple in part["triangles"]:
                    self.assertEqual(len(set(triple)), 3, f"{object_name} degenerate triangle")
                    self.assertTrue(all(0 <= i < count for i in triple), object_name)

    def test_clips_listed_with_exact_timing(self):
        for name, spec in self.each_guardian():
            clips = self.report["guardians"][name]["clips"]
            self.assertEqual(sorted(clips), sorted(spec["clips"]))
            for clip, (seconds, frames) in clip_table(name).items():
                info = clips[clip]
                self.assertEqual(info["fps"], FPS)
                self.assertEqual((info["frame_start"], info["frame_end"]), (1, frames))
                self.assertAlmostEqual(info["duration_seconds"], seconds, places=6)
                self.assertEqual(info["action"], f"{name}_{clip}")
                self.assertEqual(info["loops"], spec["clips"][clip][2], clip)

    def test_every_frame_sampled_with_finite_transforms(self):
        for name, spec in self.each_guardian():
            for clip, (_, frames) in clip_table(name).items():
                data = self.motion[name][clip]
                self.assertEqual(len(data["frames"]), frames, f"{clip} must be sampled on every frame")
                self.assertEqual(data["bones"], list(spec["bones"]))
                for index, frame in enumerate(data["frames"]):
                    self.assertEqual(len(frame), len(spec["bones"]))
                    for row in frame:
                        self.assertEqual(len(row), 6)
                        self.assertTrue(all(math.isfinite(v) for v in row), f"{clip} frame {index + 1}")
                for object_name, box in data["mesh_bbox"].items():
                    self.assertEqual(len(box), frames, object_name)
                    self.assertTrue(all(math.isfinite(v) for pair in box for corner in pair for v in corner))

    def test_root_is_stationary_in_every_frame(self):
        for name, spec in self.each_guardian():
            expected = self.geometry[name]["rest_bones"]["Root"]
            wanted = list(expected["head"]) + list(expected["tail"])
            for clip in spec["clips"]:
                for index, frame in enumerate(self.motion[name][clip]["frames"]):
                    for got, want in zip(frame[0], wanted):
                        self.assertAlmostEqual(got, want, delta=1e-4, msg=f"{clip} frame {index + 1}")

    def test_bones_keep_their_length_so_nothing_scales(self):
        for name, spec in self.each_guardian():
            for clip in spec["clips"]:
                lengths = None
                for frame in self.motion[name][clip]["frames"]:
                    now = [math.dist(row[:3], row[3:]) for row in frame]
                    lengths = lengths or now
                    for before, after in zip(lengths, now):
                        self.assertAlmostEqual(before, after, delta=2e-3)

    def test_loop_clips_have_matching_endpoints_recomputed_from_dump(self):
        for name, spec in self.each_guardian():
            for clip in loop_clips(name):
                samples = self.motion[name][clip]["mesh_samples"]
                worst = 0.0
                for object_name, first in samples["first"].items():
                    last = samples["last"][object_name]
                    self.assertEqual(len(first), len(last))
                    worst = max([worst] + [abs(a - b) for u, v in zip(first, last) for a, b in zip(u, v)])
                self.assertLessEqual(worst, 1e-5, f"{clip} loop endpoints differ")
                self.assertLessEqual(self.report["guardians"][name]["clips"][clip]["loop_endpoint_error"], 1e-5)

    def test_one_shot_clips_really_start_and_end_differently(self):
        for name, spec in self.each_guardian():
            for clip, (_, _, loops) in spec["clips"].items():
                if loops:
                    continue
                samples = self.motion[name][clip]["mesh_samples"]
                moved = max(abs(a - b) for object_name, first in samples["first"].items()
                            for u, v in zip(first, samples["last"][object_name]) for a, b in zip(u, v))
                self.assertGreater(moved, 0.05, f"{clip} would not change the pose")

    def test_clips_really_deform_the_mesh(self):
        for name, spec in self.each_guardian():
            for clip in spec["clips"]:
                samples = self.motion[name][clip]["mesh_samples"]
                moved = 0.0
                for object_name, first in samples["first"].items():
                    for key in ("offbeat", "quarter", "middle", "last"):
                        other = samples[key][object_name]
                        moved = max([moved] + [abs(a - b) for u, v in zip(first, other) for a, b in zip(u, v)])
                self.assertGreater(moved, 0.02, f"{clip} barely moves the mesh")

    def test_clips_keep_the_guardian_above_the_floor(self):
        for name, spec in self.each_guardian():
            for clip in spec["clips"]:
                lowest = min(corner[0][2] for box in self.motion[name][clip]["mesh_bbox"].values()
                             for corner in box)
                self.assertGreaterEqual(lowest, -0.15, f"{clip} sinks into the ground")

    def test_model_and_clips_are_separate_fbx_files(self):
        for name, spec in self.each_guardian():
            files = self.report["guardians"][name]["fbx"]
            self.assertEqual(sorted(files), sorted(["model", *spec["clips"]]))
            self.assertEqual(files["model"], f"assets/exports/guardians/{name}.fbx")
            for clip in spec["clips"]:
                self.assertEqual(files[clip], f"assets/exports/guardians/{name}_{clip}.fbx")

    def test_fbx_round_trip_keeps_bones_and_clip_duration(self):
        for name, spec in self.each_guardian():
            entry = self.roundtrip["guardians"][name]
            self.assertEqual(sorted(entry["model"]["bones"]), sorted(spec["bones"]),
                             "bones lost or leaf bones added")
            self.assertEqual(entry["model"]["actions"], [], "the model FBX must carry no baked clip")
            for clip, (seconds, frames) in clip_table(name).items():
                imported = entry["clips"][clip]
                self.assertEqual(sorted(imported["bones"]), sorted(spec["bones"]))
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
        self.assertFalse(self.report["roblox_scale_verified"],
                         "scale in Roblox is unverified until a real import")
        for name, spec in self.each_guardian():
            self.assertEqual(self.report["guardians"][name]["status"], "unvalidated")

    def test_exactly_one_neon_part_per_guardian(self):
        for name, spec in self.each_guardian():
            neon = [label for label in spec["parts"] if label.startswith("Neon_")]
            self.assertEqual(len(neon), 1, name)
            glowing = [p for p in self.report["guardians"][name]["parts"] if p["emission_strength"] > 0]
            self.assertEqual([p["object"] for p in glowing], [f"{name}_{neon[0]}"])

    def test_telegraph_is_long_enough_to_warn_and_leads_into_the_strike_pose(self):
        for name, spec in self.each_guardian():
            seconds, frames = clip_table(name)["Telegraph"]
            self.assertGreaterEqual(seconds, 1.4, "existing minimum, WildboundWorldRules.luau:7")
            strike = spec["strike_clip"]
            first = self.motion[name][strike]["frames"][0]
            last = self.motion[name]["Telegraph"]["frames"][-1]
            for a, b in zip(first, last):
                for x, y in zip(a, b):
                    self.assertAlmostEqual(x, y, delta=1e-4, msg=f"{name} Telegraph end vs {strike} start")
            samples_a = self.motion[name]["Telegraph"]["mesh_samples"]["last"]
            samples_b = self.motion[name][strike]["mesh_samples"]["first"]
            worst = max(abs(a - b) for key in samples_a
                        for u, v in zip(samples_a[key], samples_b[key]) for a, b in zip(u, v))
            self.assertLessEqual(worst, 1e-5, "meshes must meet at the hand-over")


class YetiForm(unittest.TestCase):
    """Silhouette rules from the bible's form notes: what the Yeti must and must not read as."""

    @classmethod
    def setUpClass(cls):
        cls.geometry = load_json(GuardianAssets.GEOMETRY)["GD_Yeti"]
        cls.report = load_json(GuardianAssets.REPORT)["guardians"]["GD_Yeti"]
        cls.parts = {name.split("_", 2)[2]: part for name, part in cls.geometry["parts"].items()}
        low, high = bounds(asset_triangles(cls.geometry))
        cls.low, cls.high = low, high
        cls.height = high[2] - low[2]

    def vertices(self, label):
        return self.parts[label]["vertices"]

    def dominant_bone(self, label, index):
        return max(self.parts[label]["weights"][index], key=lambda pair: pair[1])[0]

    def test_head_sits_below_the_shoulder_hump(self):
        hump = max(v[2] for v in self.vertices("Hide"))
        mask_top = max(v[2] for v in self.vertices("Mask"))
        eye_top = max(v[2] for v in self.vertices("Neon_Eye"))
        self.assertGreaterEqual(hump, self.high[2] - 0.05, "the hump is the tallest point")
        self.assertLessEqual(mask_top, hump - 2.0, "face must hang well below the hump")
        self.assertLessEqual(eye_top, hump - 2.0)

    def test_face_is_a_flat_plate_facing_forward(self):
        area = 0.0
        for a, b, c in part_triangles(self.parts["Mask"]):
            u = [b[i] - a[i] for i in range(3)]
            v = [c[i] - a[i] for i in range(3)]
            n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]]
            size = math.sqrt(sum(x * x for x in n))
            if size > 0 and -n[1] / size > 0.9:
                area += size / 2
        self.assertGreaterEqual(area, 5.0, "a flat shale plate: at least 5 square studs facing -Y")

    def test_ice_plates_lie_on_the_back_and_on_both_forearms(self):
        ice = self.parts["Ice"]
        owners = {self.dominant_bone("Ice", i) for i in range(len(ice["vertices"]))}
        self.assertIn("Forearm.L", owners)
        self.assertIn("Forearm.R", owners)
        self.assertTrue(owners & {"Spine", "Chest", "Pelvis"}, "ice on the back")
        upper = [v for v in ice["vertices"] if v[2] > 0.6 * self.height]
        self.assertGreater(len(upper), 20, "back plates rise toward the hump")
        self.assertLessEqual(max(v[2] for v in ice["vertices"]), self.high[2] - 0.2,
                             "ice plates never poke above the hump like horns")

    def test_dark_matted_hide_not_a_white_ape(self):
        def luminance(hex_color):
            r, g, b = (int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4))
            return 0.2126 * r + 0.7152 * g + 0.0722 * b
        for part in self.report["parts"]:
            if part["object"].endswith(("_Hide", "_Mask", "_Hands")):
                self.assertLess(luminance(part["color_hex"]), 0.3, part["object"])

    def test_heavy_wide_mass_not_a_thin_figure(self):
        size = [b - a for a, b in zip(self.low, self.high)]
        self.assertGreaterEqual(size[0], 0.9 * size[2], "as wide as it is tall")
        body = [v for v in self.vertices("Hide") if 5.5 <= v[2] <= 9.0]
        self.assertGreaterEqual(max(v[0] for v in body) - min(v[0] for v in body), 6.0,
                                "torso and shoulders are broad")

    def test_knuckle_walker_hands_rest_on_the_ground_far_below_the_shoulders(self):
        hands = self.vertices("Hands")
        self.assertLessEqual(min(v[2] for v in hands), 0.3, "knuckles touch the ground")
        self.assertLessEqual(max(v[2] for v in hands), 2.6)
        shoulders = [v for v in self.vertices("Hide") if v[2] > 0.75 * self.height]
        self.assertGreater(len(shoulders), 20)
        self.assertEqual({self.dominant_bone("Hands", i) for i in range(len(hands))}, {"Hand.L", "Hand.R"})

    def test_two_eye_slits_either_side_of_the_centre_line(self):
        xs = [v[0] for v in self.vertices("Neon_Eye")]
        self.assertLess(min(xs), -0.3)
        self.assertGreater(max(xs), 0.3)


class MotionProfiles(unittest.TestCase):
    """Pure pose profiles: no Blender needed."""

    def test_registry_matches_the_spec_table(self):
        self.assertEqual(sorted(guardian_motion.MOTION), sorted(SPECS))
        for name, spec in SPECS.items():
            self.assertEqual(guardian_motion.BONES[name], spec["bones"])
            self.assertEqual(sorted(guardian_motion.CLIPS[name]), sorted(spec["clips"]))
            self.assertEqual(sorted(guardian_motion.LOOPS[name]), sorted(loop_clips(name)))

    def test_timing_constants(self):
        self.assertEqual(guardian_motion.FPS, FPS)
        for name in SPECS:
            for clip, (seconds, frames) in clip_table(name).items():
                self.assertEqual(guardian_motion.DURATIONS[clip], seconds)
                self.assertEqual(guardian_motion.frame_count(clip), frames)

    def test_every_profile_is_finite_bounded_and_root_stationary(self):
        for name, spec in SPECS.items():
            for clip in spec["clips"]:
                for i in range(101):
                    sample = guardian_motion.pose(name, clip, i / 100)
                    self.assertEqual(set(sample), set(spec["bones"]))
                    self.assertEqual(sample["Root"], (0.0,) * 6)
                    for values in sample.values():
                        self.assertEqual(len(values), 6)
                        self.assertTrue(all(math.isfinite(v) for v in values))
                        self.assertTrue(all(abs(v) <= guardian_motion.MAX_ANGLE for v in values[:3]))
                        self.assertTrue(all(abs(v) <= guardian_motion.MAX_OFFSET for v in values[3:]))

    def test_loop_endpoints_match_exactly(self):
        for name in SPECS:
            for clip in loop_clips(name):
                self.assertEqual(guardian_motion.pose(name, clip, 0), guardian_motion.pose(name, clip, 1), clip)

    def test_telegraph_hands_over_to_the_strike_pose_exactly(self):
        for name, spec in SPECS.items():
            self.assertEqual(guardian_motion.pose(name, "Telegraph", 1),
                             guardian_motion.pose(name, spec["strike_clip"], 0))

    def test_telegraph_holds_a_readable_pose_for_the_last_part(self):
        for name in SPECS:
            self.assertEqual(guardian_motion.pose(name, "Telegraph", 0.8), guardian_motion.pose(name, "Telegraph", 1))

    def test_yeti_sequence_flows_telegraph_charge_recover_idle(self):
        yeti = "GD_Yeti"
        self.assertEqual(guardian_motion.pose(yeti, "Recover", 0), guardian_motion.pose(yeti, "Charge", 1))
        self.assertEqual(guardian_motion.pose(yeti, "Recover", 1), guardian_motion.pose(yeti, "Idle", 0))

    def test_each_clip_moves_something_besides_root(self):
        for name, spec in SPECS.items():
            for clip in spec["clips"]:
                strongest = max(abs(v) for t in (.13, .31, .62)
                                for bone, values in guardian_motion.pose(name, clip, t).items()
                                if bone != "Root" for v in values)
                self.assertGreater(strongest, 0.03, f"{name} {clip}")

    def test_axis_angle_helper_matches_plain_axis_rotations(self):
        for axis, index in (((1, 0, 0), 0), ((0, 1, 0), 1), ((0, 0, 1), 2)):
            euler = guardian_motion.euler_from_axis_angle(axis, 0.4)
            expected = [0.0, 0.0, 0.0]
            expected[index] = 0.4
            for got, want in zip(euler, expected):
                self.assertAlmostEqual(got, want, places=9)

    def test_axis_angle_helper_round_trips_a_tilted_axis(self):
        axis, angle = (0.6, -0.48, 0.64), 0.7
        rx, ry, rz = guardian_motion.euler_from_axis_angle(axis, angle)
        # Rebuild Rz @ Ry @ Rx and compare with Rodrigues' formula.
        cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
        built = [[cz * cy, cz * sy * sx - sz * cx, cz * sy * cx + sz * sx],
                 [sz * cy, sz * sy * sx + cz * cx, sz * sy * cx - cz * sx],
                 [-sy, cy * sx, cy * cx]]
        x, y, z = axis
        c, s, t = math.cos(angle), math.sin(angle), 1 - math.cos(angle)
        rodrigues = [[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
                     [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
                     [t * x * z - s * y, t * y * z + s * x, t * z * z + c]]
        for row_a, row_b in zip(built, rodrigues):
            for a, b in zip(row_a, row_b):
                self.assertAlmostEqual(a, b, places=9)

    def test_invalid_inputs_fail_closed(self):
        for args in (("GD_Missing", "Idle", 0), ("GD_Yeti", "Missing", 0),
                     ("GD_Yeti", "Idle", -.01), ("GD_Yeti", "Idle", 1.01),
                     ("GD_Yeti", "Idle", float("nan")), ("GD_Yeti", "Idle", "0"), ("GD_Yeti", "Idle", True)):
            with self.assertRaises(ValueError):
                guardian_motion.pose(*args)


if __name__ == "__main__":
    unittest.main()
