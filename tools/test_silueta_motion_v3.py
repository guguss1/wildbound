"""Focused motion contracts; run with python tools/test_silueta_motion_v3.py."""

import math
import unittest

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


if __name__ == "__main__":
    unittest.main(verbosity=2)
