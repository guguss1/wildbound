"""Spec tests for the Wildbound species rigs (expansion bible 5.1, 5.2 and 5.9).

Run with: python -I -B -m unittest discover -s tools -p "test_species_rigs.py"

Standard library only. Artifacts come from tools/build-species-rigs.py, run headless:
  "D:/blender/blender.exe" --background --factory-startup --python tools/build-species-rigs.py
  SPECIES_RIGS_MODE=verify-fbx "D:/blender/blender.exe" --background --factory-startup --python tools/build-species-rigs.py

The species table below is the contract, copied from the bible, not from the builder.
Geometry, weights and per-frame samples are recomputed here from the dumps.
All species are labelled unvalidated: nothing was imported into Roblox.
"""

import math
import unittest
from pathlib import Path

import species_motion
from kit_spec_common import (ROOT, AssetSpecMixin, asset_triangles, load_json, part_triangles)

SPECIES_DIR = ROOT / "assets/blender/species"
EXPORT_DIR = ROOT / "assets/exports/species"
FPS = 30
CLIPS = {"Idle": (3.0, 91), "Move": (2.0, 61)}  # seconds, frames at 30 fps (1 to N)

# size is (x, y, z) in studs; tris is the budget; parts map label to (hex, part budget).
SPECS = {
    "SP_Soplillo": {
        "size": (2.8, 3.4, 2.6), "tris": 450,
        "parts": {"Body": ("E6EFF4", 300), "Tail": ("9CCBE0", 110), "Neon_Eye": ("4E7CC2", 40)},
        "bones": ("Root", "Body", "TailA", "TailB"),
    },
    "SP_Cortezon": {
        "size": (3.6, 4.0, 2.4), "tris": 600,
        "parts": {"Shell": ("5B4630", 340), "Legs": ("3A2E22", 140), "Moss": ("7E9440", 80),
                  "Neon_Eye": ("E8D25A", 40)},
        "bones": ("Root", "Body", "Head", "LegFL", "LegFR", "LegBL", "LegBR"),
    },
    "SP_Cestillo": {
        "size": (2.6, 2.8, 4.0), "tris": 650,
        "parts": {"Basket": ("B98E55", 300), "Neck": ("7E8C47", 120), "Beak": ("5E9A3C", 70),
                  "Legs": ("6B4A2F", 130), "Neon_Eye": ("F2F0C8", 30)},
        "bones": ("Root", "Basket", "Neck", "Head", "LegL", "LegR"),
    },
}


class SpeciesAssets(AssetSpecMixin, unittest.TestCase):
    SPECS = SPECS
    ASSET_KEY = "species"
    REPORT = SPECIES_DIR / "species-report.json"
    GEOMETRY = SPECIES_DIR / "species-geometry.json"
    ROUNDTRIP = SPECIES_DIR / "fbx-roundtrip.json"
    BLEND = SPECIES_DIR / "species-v1.blend"
    RENDER_DIR = SPECIES_DIR
    EXPORT_DIR = EXPORT_DIR
    HEIGHT_CAP = 5.0


class SpeciesRigs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.report = load_json(SpeciesAssets.REPORT)
        cls.geometry = load_json(SpeciesAssets.GEOMETRY)
        cls.motion = load_json(SPECIES_DIR / "species-motion.json")
        cls.roundtrip = load_json(SpeciesAssets.ROUNDTRIP)

    def each_species(self):
        for name, spec in SPECS.items():
            with self.subTest(species=name):
                yield name, spec

    def test_bones_exact_and_in_order(self):
        for name, spec in self.each_species():
            self.assertEqual(tuple(self.geometry[name]["bones"]), spec["bones"])
            self.assertEqual(tuple(self.report["species"][name]["bones"]), spec["bones"])
            self.assertEqual(spec["bones"][0], "Root")
            self.assertEqual(len(set(spec["bones"])), len(spec["bones"]))

    def test_every_vertex_weighted_normalized_with_two_influences_at_most(self):
        for name, spec in self.each_species():
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
        for name, spec in self.each_species():
            for object_name, part in self.geometry[name]["parts"].items():
                count = len(part["vertices"])
                for triple in part["triangles"]:
                    self.assertEqual(len(set(triple)), 3, f"{object_name} degenerate triangle")
                    self.assertTrue(all(0 <= i < count for i in triple), object_name)

    def test_clips_listed_with_exact_timing(self):
        for name, spec in self.each_species():
            clips = self.report["species"][name]["clips"]
            self.assertEqual(sorted(clips), sorted(CLIPS))
            for clip, (seconds, frames) in CLIPS.items():
                info = clips[clip]
                self.assertEqual(info["fps"], FPS)
                self.assertEqual((info["frame_start"], info["frame_end"]), (1, frames))
                self.assertAlmostEqual(info["duration_seconds"], seconds, places=6)
                self.assertEqual(info["action"], f"{name}_{clip}")

    def test_every_frame_sampled_with_finite_transforms(self):
        for name, spec in self.each_species():
            for clip, (_, frames) in CLIPS.items():
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
        rest = self.geometry
        for name, spec in self.each_species():
            expected = rest[name]["rest_bones"]["Root"]
            wanted = list(expected["head"]) + list(expected["tail"])
            for clip in CLIPS:
                for index, frame in enumerate(self.motion[name][clip]["frames"]):
                    for got, want in zip(frame[0], wanted):
                        self.assertAlmostEqual(got, want, delta=1e-4, msg=f"{clip} frame {index + 1}")

    def test_bones_keep_their_length_so_nothing_scales(self):
        for name, spec in self.each_species():
            for clip in CLIPS:
                lengths = None
                for frame in self.motion[name][clip]["frames"]:
                    now = [math.dist(row[:3], row[3:]) for row in frame]
                    lengths = lengths or now
                    for before, after in zip(lengths, now):
                        self.assertAlmostEqual(before, after, delta=2e-3)

    def test_loop_endpoint_mesh_error_is_zero_recomputed_from_dump(self):
        for name, spec in self.each_species():
            for clip in CLIPS:
                samples = self.motion[name][clip]["mesh_samples"]
                worst = 0.0
                for object_name, first in samples["first"].items():
                    last = samples["last"][object_name]
                    self.assertEqual(len(first), len(last))
                    worst = max([worst] + [abs(a - b) for u, v in zip(first, last) for a, b in zip(u, v)])
                self.assertLessEqual(worst, 1e-5, f"{clip} loop endpoints differ")
                self.assertLessEqual(self.report["species"][name]["clips"][clip]["loop_endpoint_error"], 1e-5)

    def test_clips_really_deform_the_mesh(self):
        for name, spec in self.each_species():
            for clip in CLIPS:
                samples = self.motion[name][clip]["mesh_samples"]
                moved = 0.0
                for object_name, first in samples["first"].items():
                    middle = samples["middle"][object_name]
                    moved = max([moved] + [abs(a - b) for u, v in zip(first, middle) for a, b in zip(u, v)])
                self.assertGreater(moved, 0.02, f"{clip} barely moves the mesh")

    def test_clips_keep_the_creature_above_the_floor(self):
        for name, spec in self.each_species():
            for clip in CLIPS:
                lowest = min(corner[0][2] for box in self.motion[name][clip]["mesh_bbox"].values()
                             for corner in box)
                self.assertGreaterEqual(lowest, -0.15, f"{clip} sinks into the ground")

    def test_height_never_hides_the_owner(self):
        for name, spec in self.each_species():
            top = max(v[2] for v in (v for t in asset_triangles(self.geometry[name]) for v in t))
            self.assertLessEqual(top, 5.0)

    def test_model_and_clips_are_separate_fbx_files(self):
        for name, spec in self.each_species():
            files = self.report["species"][name]["fbx"]
            self.assertEqual(sorted(files), ["Idle", "Move", "model"])
            self.assertEqual(files["model"], f"assets/exports/species/{name}.fbx")
            for clip in CLIPS:
                self.assertEqual(files[clip], f"assets/exports/species/{name}_{clip}.fbx")

    def test_fbx_round_trip_keeps_bones_and_clip_duration(self):
        for name, spec in self.each_species():
            entry = self.roundtrip["species"][name]
            self.assertEqual(sorted(entry["model"]["bones"]), sorted(spec["bones"]),
                             "bones lost or leaf bones added")
            self.assertEqual(entry["model"]["actions"], [], "the model FBX must carry no baked clip")
            for clip, (seconds, frames) in CLIPS.items():
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
        for name, spec in self.each_species():
            self.assertEqual(self.report["species"][name]["status"], "unvalidated")


class MotionProfiles(unittest.TestCase):
    """Pure pose profiles: no Blender needed."""

    def test_registry_matches_the_spec_table(self):
        self.assertEqual(sorted(species_motion.MOTION), sorted(SPECS))
        for name, spec in SPECS.items():
            self.assertEqual(species_motion.BONES[name], spec["bones"])

    def test_timing_constants(self):
        self.assertEqual(species_motion.FPS, FPS)
        for clip, (seconds, frames) in CLIPS.items():
            self.assertEqual(species_motion.DURATIONS[clip], seconds)
            self.assertEqual(species_motion.frame_count(clip), frames)

    def test_every_profile_is_finite_bounded_and_root_stationary(self):
        for name in SPECS:
            for clip in CLIPS:
                for i in range(101):
                    sample = species_motion.pose(name, clip, i / 100)
                    self.assertEqual(set(sample), set(SPECS[name]["bones"]))
                    self.assertEqual(sample["Root"], (0.0,) * 6)
                    for values in sample.values():
                        self.assertEqual(len(values), 6)
                        self.assertTrue(all(math.isfinite(v) for v in values))
                        self.assertTrue(all(abs(v) <= species_motion.MAX_ANGLE for v in values[:3]))
                        self.assertTrue(all(abs(v) <= species_motion.MAX_OFFSET for v in values[3:]))

    def test_loop_endpoints_match_exactly(self):
        for name in SPECS:
            for clip in CLIPS:
                self.assertEqual(species_motion.pose(name, clip, 0), species_motion.pose(name, clip, 1))

    def test_each_clip_moves_something_besides_root(self):
        for name in SPECS:
            for clip in CLIPS:
                strongest = max(abs(v) for t in (.13, .31, .62)
                                for bone, values in species_motion.pose(name, clip, t).items()
                                if bone != "Root" for v in values)
                self.assertGreater(strongest, 0.03, f"{name} {clip}")

    def test_invalid_inputs_fail_closed(self):
        for args in (("SP_Missing", "Idle", 0), ("SP_Soplillo", "Missing", 0),
                     ("SP_Soplillo", "Idle", -.01), ("SP_Soplillo", "Idle", 1.01),
                     ("SP_Soplillo", "Idle", float("nan")), ("SP_Soplillo", "Idle", "0")):
            with self.assertRaises(ValueError):
                species_motion.pose(*args)


if __name__ == "__main__":
    unittest.main()
