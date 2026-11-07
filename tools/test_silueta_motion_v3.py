"""Focused motion contracts; run with python tools/test_silueta_motion_v3.py."""

import hashlib
import json
import math
import unittest
from pathlib import Path

import silueta_motion_v3
from silueta_motion_v3 import BONES, DURATIONS, FPS, pose


class MotionContracts(unittest.TestCase):
    def test_every_profile_is_finite_bounded_and_root_stationary(self):
        for action in DURATIONS:
            for i in range(101):
                sample = pose(action, i / 100)
                self.assertEqual(set(sample), set(BONES))
                self.assertEqual(sample["Root"], (0, 0, 0))
                self.assertTrue(all(math.isfinite(v) and abs(v) <= 1.6
                                    for angles in sample.values() for v in angles))

    def test_loop_endpoints_match(self):
        for action in ("Idle", "Locomotion"):
            for bone in BONES:
                for start, end in zip(pose(action, 0)[bone], pose(action, 1)[bone]):
                    self.assertAlmostEqual(start, end, places=10)

    def test_telegraph_is_exactly_1_4_seconds_and_holds_readable_pose(self):
        self.assertEqual(DURATIONS["Telegraph"], 1.4)
        self.assertEqual(round(DURATIONS["Telegraph"] * FPS), 42)
        self.assertEqual(pose("Telegraph", .5), pose("Telegraph", 1))
        self.assertGreater(abs(pose("Telegraph", 1)["UpperArm.L"][0]), .4)

    def test_telegraph_attack_and_recovery_are_continuous(self):
        self.assertEqual(pose("Telegraph", 1), pose("Attack", 0))
        self.assertEqual(pose("Attack", 1), pose("Idle", 0))

    def test_required_regions_actually_move(self):
        for bone in ("Head", "Spine", "Chest", "UpperArm.L", "Forearm.R", "Thigh.L", "Shin.R"):
            self.assertTrue(any(max(abs(v) for v in pose(action, t)[bone]) > .01
                                for action in DURATIONS for t in (.17, .25, .6)))

    def test_invalid_inputs_fail_closed(self):
        for action, progress in (("Missing", 0), ("Idle", -.01), ("Idle", 1.01),
                                 ("Idle", float("nan")), ("Idle", "0")):
            with self.assertRaises(ValueError):
                pose(action, progress)


# ---------------------------------------------------------------------------
# Search_v1: the optional distinct search pose (roadmap M2.4, rank 10).
# It is a new versioned clip beside the four original ones. Everything above this line is the
# original contract and stays as it was; the checks below prove the four clips did not change.
# The digests were computed from the original module before Search_v1 existed.
# ---------------------------------------------------------------------------

ROOT = Path(__file__).resolve().parents[1]
ORIGINAL_DURATIONS = {"Idle": 3.0, "Locomotion": 2.0, "Telegraph": 1.4, "Attack": 1.0}
ORIGINAL_POSE_DIGEST = {
    "Idle": "88622c0ab6efde4dafda6d727765a5b54b4ead14609a315b504aff49f9c2db4a",
    "Locomotion": "3862465ffa7e02a2bb6b5f84ce9b7e33bd464ec7d91c25be316ad2ce6688f2b9",
    "Telegraph": "9d575dd27fd4e82a3ca7af81e0394b35839cdaf4fa5c9c449cf408444cbaa661",
    "Attack": "db63e0031c42911337219ea0c0c18cfa73ba82721d839d86ab96d675b538ae02",
}
ORIGINAL_ALL_DIGEST = "185036df978c8a6a5e392f0e2cf01f4b51c4b6fd803419b74aa41a1539b2573c"
SEARCH = "Search_v1"
SEARCH_SECONDS, SEARCH_FRAMES = 2.4, 73
BLENDER_DIR = ROOT / "assets/blender"
EXPORT_DIR = ROOT / "assets/exports"
ORIGINAL_REPORT = BLENDER_DIR / "silueta-horror-rig-v3-report.json"
SEARCH_REPORT = BLENDER_DIR / "silueta-horror-rig-v3-search-v1-report.json"
SEARCH_FBX = EXPORT_DIR / "silueta-horror-rig-v3-search-v1.fbx"
SEARCH_BLEND = BLENDER_DIR / "silueta-horror-rig-v3-search-v1.blend"
SEARCH_QA = BLENDER_DIR / "silueta-horror-rig-v3-search-v1-qa.png"
ORIGINAL_FILES = ("silueta-horror-rig-v3.blend", "silueta-horror-rig-v3.glb", "silueta-horror-rig-v3-model.fbx",
                  "silueta-horror-rig-v3-idle.fbx", "silueta-horror-rig-v3-locomotion.fbx",
                  "silueta-horror-rig-v3-telegraph.fbx", "silueta-horror-rig-v3-attack.fbx")


def pose_digest(clips):
    """SHA-256 over 1001 samples of each clip, in a fixed canonical text form."""
    hasher = hashlib.sha256()
    for clip in clips:
        hasher.update(clip.encode())
        hasher.update(repr(silueta_motion_v3.DURATIONS[clip]).encode())
        for i in range(1001):
            sample = silueta_motion_v3.pose(clip, i / 1000)
            for bone in silueta_motion_v3.BONES:
                hasher.update(bone.encode())
                hasher.update(",".join(repr(float(v)) for v in sample[bone]).encode())
    return hasher.hexdigest()


def load(path):
    if not path.exists():
        raise AssertionError(f"missing artifact: {path.relative_to(ROOT).as_posix()}")
    return json.loads(path.read_text(encoding="utf-8"))


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class FourOriginalClipsAreUnchanged(unittest.TestCase):
    def test_registry_of_the_four_original_clips_is_exact(self):
        self.assertEqual(dict(silueta_motion_v3.DURATIONS), ORIGINAL_DURATIONS)
        self.assertEqual(list(silueta_motion_v3.DURATIONS), list(ORIGINAL_DURATIONS))
        self.assertNotIn(SEARCH, silueta_motion_v3.DURATIONS,
                         "the rig builder loops DURATIONS, so Search_v1 must live elsewhere")

    def test_pose_data_of_each_original_clip_hashes_to_the_pre_change_digest(self):
        for clip, wanted in ORIGINAL_POSE_DIGEST.items():
            with self.subTest(clip=clip):
                self.assertEqual(pose_digest([clip]), wanted)
        self.assertEqual(pose_digest(list(ORIGINAL_DURATIONS)), ORIGINAL_ALL_DIGEST)

    def test_bones_and_fps_are_unchanged(self):
        self.assertEqual(silueta_motion_v3.FPS, 30)
        self.assertEqual(len(BONES), 18)
        self.assertEqual(BONES[0], "Root")
        self.assertEqual(BONES[-1], "Foot.R")


class SearchClipPose(unittest.TestCase):
    def test_registered_separately_with_exact_timing(self):
        self.assertEqual(dict(silueta_motion_v3.EXTRA_CLIPS), {SEARCH: SEARCH_SECONDS})
        self.assertEqual(round(SEARCH_SECONDS * FPS) + 1, SEARCH_FRAMES)

    def test_every_sample_is_finite_bounded_with_a_stationary_root(self):
        for i in range(101):
            sample = pose(SEARCH, i / 100)
            self.assertEqual(set(sample), set(BONES))
            self.assertEqual(sample["Root"], (0, 0, 0))
            for angles in sample.values():
                self.assertEqual(len(angles), 3)
                self.assertTrue(all(math.isfinite(v) and abs(v) <= 0.9 for v in angles))

    def test_it_loops_exactly(self):
        for bone in BONES:
            for start, end in zip(pose(SEARCH, 0)[bone], pose(SEARCH, 1)[bone]):
                self.assertAlmostEqual(start, end, places=10)

    def test_it_reads_as_a_low_tilted_scan_with_the_arms_kept_in(self):
        heads = [pose(SEARCH, i / 100)["Head"] for i in range(101)]
        self.assertGreaterEqual(min(h[2] for h in heads), 0.2, "head stays tilted to one side")
        self.assertGreaterEqual(max(h[1] for h in heads) - min(h[1] for h in heads), 0.8, "head sweeps side to side")
        for i in range(101):
            sample = pose(SEARCH, i / 100)
            self.assertGreaterEqual(sample["Spine"][0], 0.15, "stooped forward")
            self.assertGreaterEqual(sample["Chest"][0], 0.1)
            for bone in ("UpperArm.L", "UpperArm.R"):
                self.assertLessEqual(abs(sample[bone][2]), 0.25, "arms are not spread wide")

    def test_it_is_clearly_different_from_the_held_warning_pose(self):
        hold = pose("Telegraph", 1)
        for i in range(101):
            sample = pose(SEARCH, i / 100)
            distance = math.sqrt(sum((a - b) ** 2 for bone in BONES for a, b in zip(sample[bone], hold[bone])))
            self.assertGreaterEqual(distance, 1.0, f"too close to the Telegraph hold at {i / 100}")

    def test_it_moves_the_regions_a_search_needs(self):
        for bone in ("Head", "Neck", "Chest", "Spine", "UpperArm.L", "Forearm.L", "Forearm.R"):
            motion = max(abs(pose(SEARCH, i / 100)[bone][k] - pose(SEARCH, 0)[bone][k])
                         for i in range(101) for k in range(3))
            self.assertGreater(motion, 0.02, f"{bone} never moves")

    def test_invalid_inputs_fail_closed(self):
        for action, progress in ((SEARCH, -0.01), (SEARCH, 1.01), (SEARCH, float("nan")), (SEARCH, "0"),
                                 ("Search_v2", 0)):
            with self.assertRaises(ValueError):
                pose(action, progress)


class SearchClipArtifacts(unittest.TestCase):
    """Built by tools/build-silueta-search-v1.py; unvalidated, never imported into Roblox."""

    @classmethod
    def setUpClass(cls):
        cls.report = load(SEARCH_REPORT)
        cls.original = load(ORIGINAL_REPORT)

    def test_the_original_seven_files_still_match_the_hashes_recorded_when_they_shipped(self):
        for name in ORIGINAL_FILES:
            path = (EXPORT_DIR if name.endswith((".fbx", ".glb")) else BLENDER_DIR) / name
            self.assertEqual(sha256(path), self.original["exports"][name]["sha256"], name)

    def test_the_search_report_records_those_hashes_before_and_after_the_build(self):
        proof = self.report["original_files"]
        for name in ORIGINAL_FILES:
            self.assertEqual(proof["before"][name], proof["after"][name], name)
            self.assertEqual(proof["after"][name], self.original["exports"][name]["sha256"], name)
        self.assertTrue(proof["unchanged"])

    def test_new_files_exist_and_the_fbx_is_binary_fbx(self):
        for path in (SEARCH_FBX, SEARCH_BLEND, SEARCH_QA):
            self.assertGreater(path.stat().st_size, 0, path.name)
        self.assertTrue(SEARCH_FBX.read_bytes().startswith(b"Kaydara FBX Binary"))
        self.assertNotIn(SEARCH_FBX.name, ORIGINAL_FILES)

    def test_every_frame_was_sampled_with_finite_values_and_a_fixed_root(self):
        action = self.report["action"]
        self.assertEqual(action["name"], "SiluetaV3_Search_v1")
        self.assertEqual((action["frame_start"], action["frame_end"]), (1, SEARCH_FRAMES))
        self.assertAlmostEqual(action["duration_seconds"], SEARCH_SECONDS, places=6)
        self.assertEqual(action["sampled_frames"], SEARCH_FRAMES)
        self.assertTrue(action["finite"])
        self.assertLess(action["root_max_error"], 1e-6)
        self.assertLessEqual(action["endpoint_mesh_error_m"], 1e-5, "it must loop")
        self.assertTrue(action["loop"])

    def test_the_clip_really_deforms_head_and_arms(self):
        moved = self.report["action"]["max_world_vertex_displacement_m"]
        self.assertGreater(moved["SiluetaV3_Head"], 0.05)
        self.assertGreater(moved["SiluetaV3_ArmLeft"], 0.05)
        self.assertGreater(moved["SiluetaV3_Body"], 0.02)

    def test_the_fbx_round_trip_keeps_eighteen_bones_one_clip_and_its_duration(self):
        trip = self.report["roundtrip"]
        self.assertEqual(trip["bones"], 18)
        self.assertEqual(trip["meshes"], 9)
        self.assertEqual(trip["triangles"], 1288)
        self.assertEqual(trip["vertices_without_weights"], 0)
        self.assertAlmostEqual(trip["dimensions_m"][2], 2.4, delta=1e-3)
        self.assertGreater(trip["animated_channels"], 0)
        self.assertEqual(trip["keyed_frames"], SEARCH_FRAMES)
        self.assertAlmostEqual(trip["duration_seconds"], SEARCH_SECONDS, delta=1.0 / FPS)

    def test_the_model_was_not_edited_and_the_status_is_labelled(self):
        self.assertEqual(self.report["status"], "unvalidated")
        self.assertFalse(self.report["uploaded"])
        self.assertFalse(self.report["design_changed"])
        self.assertEqual(self.report["new_rig_triangles"], self.original["triangles"])
        self.assertIn("in-game", self.report["not_verified"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
