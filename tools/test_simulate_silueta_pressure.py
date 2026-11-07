"""Contracts for the Silueta pressure simulator.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p "test_simulate_*.py"

Two kinds of test live here, on purpose:

* Hand-computed cases on tiny synthetic worlds. Every expected number below is
  derived in a comment from the source rules (0.2 s step, 1.2 s alert, 7 stud
  attack range, 1.4 s telegraph), not copied from the module's own output.
* Pins against the real source files. Spec numbers are restated here so a
  change in `WildboundWorldRules.luau`, the server script, the layout JSON or
  the capture document either moves the simulator (parsed) or fails a test.

These model geometry only. They say nothing about fun or balance.
"""

import contextlib
import copy
import io
import json
import math
import unittest
from pathlib import Path

import simulate_silueta_pressure as sp

REPO = Path(__file__).resolve().parent.parent
RULES = REPO / "src/wildbound/WildboundWorldRules.luau"
SERVER = REPO / "src/wildbound/WildboundWorld.server.luau"
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
CAPTURE = REPO / "docs/mechanics/wildbound-capture.md"
BUILDER = REPO / "tools/build-wildbound-p0-map.luau"

# ---- Spec numbers restated independently of the module under test ----------
HOME, LEASH = (0, -85), 80
FOG = (-45, 165, -165, 35)
SAFE = [((-140, 140), 35), ((105, 125), 22)]
PATROL = [(16, -85), (0, -69), (-16, -85), (0, -101)]  # E, S, W, N
DAY, NIGHT = (8, 26), (11, 38)                         # (hunt speed, detection) from the brain, delivery C

# One simple model used by the hand cases: 0.2 s step, 1.2 s alert, 1.4 s
# telegraph, attack range 7, chase limit 10 s, patrol speed 3.
MODEL = sp.Model(step_s=0.2, patrol_speed=3.0, alert_s=1.2, telegraph_s=1.4,
                 attack_range=7.0, max_chase_s=10.0)
STILL = sp.Model(step_s=0.2, patrol_speed=0.0, alert_s=1.2, telegraph_s=1.4,
                 attack_range=7.0, max_chase_s=10.0)
POINT = [(0.0, 0.0)] * 4  # a guardian that never moves


def texts():
    return {
        "rules": RULES.read_text(encoding="utf-8"),
        "server": SERVER.read_text(encoding="utf-8"),
        "layout": json.loads(LAYOUT.read_text(encoding="utf-8")),
        "capture": CAPTURE.read_text(encoding="utf-8"),
        "builder": BUILDER.read_text(encoding="utf-8"),
    }


class SourceParsing(unittest.TestCase):
    def test_world_matches_the_restated_spec(self):
        world = sp.load_world(REPO)
        self.assertEqual((world.home_x, world.home_z), HOME)
        self.assertEqual(world.leash, LEASH)
        self.assertEqual(tuple(world.fog), FOG)
        self.assertEqual([((x, z), r) for x, z, r in world.safe], SAFE)
        self.assertEqual(world.patrol, PATROL)
        self.assertEqual((world.day.speed, world.day.detection_range), DAY)
        self.assertEqual((world.night.speed, world.night.detection_range), NIGHT)
        m = world.model
        self.assertEqual((m.step_s, m.patrol_speed, m.alert_s), (0.2, 4.0, 1.2))
        self.assertEqual((m.telegraph_s, m.attack_range, m.max_chase_s), (1.4, 7.0, 10.0))

    def test_objectives_come_from_the_sources(self):
        world = sp.load_world(REPO)
        names = {o.name: (o.x, o.z) for o in world.objectives}
        self.assertEqual(names["nest"], (35.0, -99.0))
        self.assertEqual(names["old nest"], (110.0, -130.0))
        self.assertEqual(names["lumipol marker"], (-95.0, 75.0))
        for slot, xz in {"S0a": (-95, 75), "L1": (-10, -60), "L2": (30, -105),
                         "L4": (110, 5), "E1": (35, -99), "E3": (60, -125)}.items():
            self.assertEqual(names["capture " + slot], (float(xz[0]), float(xz[1])), slot)

    def test_capture_hold_is_parsed_from_the_document(self):
        self.assertEqual(sp.load_world(REPO).calm_required, 4.5)

    def test_missing_rule_constant_fails_loudly(self):
        t = texts()
        broken = t["rules"].replace("Rules.ATTACK_RANGE = 7", "-- gone")
        with self.assertRaisesRegex(sp.ParseError, "ATTACK_RANGE"):
            sp.parse_rules(broken)

    def test_empty_inputs_fail_loudly(self):
        with self.assertRaises(sp.ParseError):
            sp.parse_rules("")
        with self.assertRaises(sp.ParseError):
            sp.parse_server("")
        with self.assertRaises(sp.ParseError):
            sp.parse_capture("| nothing | here |")
        with self.assertRaises(sp.ParseError):
            sp.parse_lumipol_marker("")

    def test_changed_steering_assumption_fails_loudly(self):
        t = texts()
        broken = t["server"].replace("navigate(decision.destination, parameters.speed, dt",
                                     "navigate(decision.destination, 99, dt")
        with self.assertRaisesRegex(sp.ParseError, "steering"):
            sp.parse_server(broken)

    def test_night_scope_other_than_fog_fails_loudly(self):
        t = texts()
        broken = t["rules"].replace('scope = "Fog"', 'scope = "Everywhere"')
        with self.assertRaisesRegex(sp.ParseError, "scope"):
            sp.parse_rules(broken)

    def test_layout_drift_fails_loudly(self):
        t = texts()
        for mutate in (
            lambda d: d["inputs"]["guardian"].__setitem__("leash", 81.0),
            lambda d: d["inputs"]["guardian"]["home"].__setitem__(0, 1.0),
            lambda d: d["inputs"]["guardian"]["patrol_loop"].__setitem__("E", [17.0, -85.0]),
            lambda d: d["inputs"]["safe_circles"]["camp"].__setitem__("r", 30.0),
        ):
            layout = copy.deepcopy(t["layout"])
            mutate(layout)
            with self.assertRaises(sp.ConsistencyError):
                sp.build_world(t["rules"], t["server"], layout, t["capture"], t["builder"])

    def test_capture_rows_parse_and_carry_documented_patrol_shares(self):
        spots = {s.slot: s for s in sp.parse_capture(texts()["capture"])}
        self.assertEqual(spots["L1"].doc_share, (0.46, 0.83))
        self.assertEqual(spots["S0a"].doc_share, (0.0, 0.0))
        self.assertEqual(spots["E1"].doc_share, (0.18, 0.46))
        self.assertEqual(spots["L3"].doc_share, (0.0, 0.0))


class Geometry(unittest.TestCase):
    def test_zone_classification(self):
        world = sp.load_world(REPO)
        self.assertEqual(sp.zone_of(world, 35, -99), "territory")  # 37.7 from home
        self.assertEqual(sp.zone_of(world, 0, -85), "territory")
        self.assertEqual(sp.zone_of(world, -95, 75), "outside")    # z=75 is past fog z<=35
        self.assertEqual(sp.zone_of(world, 110, -130), "fog")      # in rect, 118.85 > leash 80
        self.assertEqual(sp.zone_of(world, -140, 140), "safe")
        self.assertEqual(sp.zone_of(world, 105, 125), "safe")

    def test_patrol_diamond_perimeter_and_positions(self):
        # Each edge is 16*sqrt(2) long, so the loop is 64*sqrt(2).
        self.assertAlmostEqual(sp.loop_length(PATROL), 64 * math.sqrt(2), places=9)
        edge = 16 * math.sqrt(2)
        x, z = sp.patrol_position(PATROL, 0.0)
        self.assertAlmostEqual(x, 16, places=9); self.assertAlmostEqual(z, -85, places=9)
        x, z = sp.patrol_position(PATROL, edge)
        self.assertAlmostEqual(x, 0, places=9); self.assertAlmostEqual(z, -69, places=9)
        x, z = sp.patrol_position(PATROL, edge / 2)       # midpoint of E -> S
        self.assertAlmostEqual(x, 8, places=9); self.assertAlmostEqual(z, -77, places=9)
        x, z = sp.patrol_position(PATROL, 64 * math.sqrt(2) + edge)  # wraps once
        self.assertAlmostEqual(x, 0, places=9); self.assertAlmostEqual(z, -69, places=9)

    def test_patrol_share_hand_cases(self):
        # Player at the centre of the diamond. Edge midpoint is 16/sqrt(2) = 11.31 away.
        centre = (0, -85)
        self.assertEqual(sp.patrol_share(PATROL, centre, 11.0), 0.0)
        self.assertEqual(sp.patrol_share(PATROL, centre, 16.0), 1.0)
        # R=12: per edge d^2 = 128 + u^2 <= 144, so |u| <= 4, covering 8 of 16*sqrt(2).
        self.assertAlmostEqual(sp.patrol_share(PATROL, centre, 12.0), 8 / (16 * math.sqrt(2)), places=9)
        # Player 28 east of E waypoint (44 east of home), R=30. On both edges meeting at E
        # the distance^2 is (28+a)^2 + a^2 with a = u/sqrt(2), so a^2+28a-58 <= 0,
        # a <= -14 + sqrt(254), u = a*sqrt(2). Two edges are covered.
        a = -14 + math.sqrt(254)
        expected = 2 * a * math.sqrt(2) / (64 * math.sqrt(2))
        self.assertAlmostEqual(sp.patrol_share(PATROL, (44, -85), 30.0), expected, places=9)
        self.assertEqual(sp.patrol_share(PATROL, (0, 100), 28.0), 0.0)

    def test_nest_share_agrees_with_the_layout_json(self):
        # Independent generator (plan_forest_layout.py) recorded these for the nest.
        recorded = texts()["layout"]["nest_cover"]["patrol_loop_within_range"]
        world = sp.load_world(REPO)
        nest = (35.0, -99.0)
        self.assertAlmostEqual(sp.patrol_share(world.patrol, nest, 28), recorded["day_28"], delta=0.002)
        self.assertAlmostEqual(sp.patrol_share(world.patrol, nest, 38), recorded["night_38"], delta=0.002)


class StationaryPlayer(unittest.TestCase):
    def run_one(self, model, waypoints, player, speed, rng, phase=0.0):
        return sp.simulate_stationary(model, waypoints, player, phase, speed, rng)

    def test_guardian_in_range_from_the_start(self):
        # Guardian fixed at the origin, player 19 away, detection 28, chase speed 6 (1.2 studs/tick).
        # Detect tick 0 (0 s). Alert flips to Hunt on tick 6; first Hunt tick is 7.
        # Moves 19 -> 7 take 12/1.2 = 10 ticks (ticks 7..16); tick 17 sees d=7 and starts
        # the telegraph (3.4 s). 1.4 s later = 7 ticks, strike on tick 24 = 4.8 s.
        r = self.run_one(STILL, POINT, (19.0, 0.0), 6.0, 28.0)
        self.assertEqual(r.reason, "strike")
        self.assertAlmostEqual(r.detect_s, 0.0, places=9)
        self.assertAlmostEqual(r.telegraph_s, 3.4, places=9)
        self.assertAlmostEqual(r.strike_s, 4.8, places=9)

    def test_player_right_next_to_the_guardian(self):
        # d=5 <= 7: no walking. Detect 0, first Hunt tick 7 (1.4 s) starts the telegraph,
        # strike 7 ticks later on tick 14 = 2.8 s.
        r = self.run_one(STILL, POINT, (5.0, 0.0), 6.0, 28.0)
        self.assertAlmostEqual(r.telegraph_s, 1.4, places=9)
        self.assertAlmostEqual(r.strike_s, 2.8, places=9)

    def test_night_range_catches_what_day_range_misses(self):
        # d=33: outside day range 28, inside night range 38.
        day = self.run_one(STILL, POINT, (33.0, 0.0), 6.0, 28.0)
        self.assertEqual(day.reason, "never_detected")
        self.assertIsNone(day.strike_s)
        # Night speed 8 = 1.6 studs/tick: ceil((33-7)/1.6) = ceil(16.25) = 17 moves.
        # Strike tick = 0 + 7 + 17 + 7 = 31 -> 6.2 s.
        night = self.run_one(STILL, POINT, (33.0, 0.0), 8.0, 38.0)
        self.assertAlmostEqual(night.strike_s, 6.2, places=9)

    def test_detection_boundary_is_inclusive(self):
        self.assertEqual(self.run_one(STILL, POINT, (28.0, 0.0), 6.0, 28.0).detect_s, 0.0)
        self.assertEqual(self.run_one(STILL, POINT, (28.001, 0.0), 6.0, 28.0).reason, "never_detected")

    def test_moving_guardian_walks_into_range(self):
        # Guardian goes (0,0) -> (60,0) and back at 3 studs/s = 0.6 studs/tick. Player at (50,0).
        # Tick j puts it at x = 0.6 j. Range 28 needs x >= 22: j=36 -> 21.6 (28.4 away), j=37 -> 22.2.
        # Detect on tick 37 = 7.4 s at d=27.8. Moves: ceil((27.8-7)/1.2) = ceil(17.33) = 18.
        # Telegraph starts tick 37+7+18 = 62 (12.4 s); strike tick 62+7 = 69 -> 13.8 s.
        r = self.run_one(MODEL, [(0, 0), (60, 0), (60, 0), (0, 0)], (50.0, 0.0), 6.0, 28.0)
        self.assertAlmostEqual(r.detect_s, 7.4, places=9)
        self.assertAlmostEqual(r.telegraph_s, 12.4, places=9)
        self.assertAlmostEqual(r.strike_s, 13.8, places=9)

    def test_phase_shifts_where_the_patrol_starts(self):
        # Same corridor, starting 30 studs along: x = 30 + 0.6 j, already within 28 of x=50 at j=0 (d=20).
        r = self.run_one(MODEL, [(0, 0), (60, 0), (60, 0), (0, 0)], (50.0, 0.0), 6.0, 28.0, phase=30.0)
        self.assertAlmostEqual(r.detect_s, 0.0, places=9)
        # d0=20: ceil(13/1.2) = ceil(10.83) = 11 moves; strike tick 7+11+7 = 25 -> 5.0 s.
        self.assertAlmostEqual(r.strike_s, 5.0, places=9)

    def test_chase_limit_cancels_the_strike(self):
        # Case 1 takes exactly 4.8 s from detection to strike. The server clears the
        # target when now - chaseStartedAt >= limit, checked before the strike.
        at_limit = sp.Model(0.2, 0.0, 1.2, 1.4, 7.0, 4.8)
        self.assertEqual(self.run_one(at_limit, POINT, (19.0, 0.0), 6.0, 28.0).reason, "chase_timeout")
        above = sp.Model(0.2, 0.0, 1.2, 1.4, 7.0, 5.0)
        self.assertEqual(self.run_one(above, POINT, (19.0, 0.0), 6.0, 28.0).reason, "strike")

    def test_tick_model_vs_the_capture_documents_formula(self):
        # The capture document says impact = alert + (d-7)/speed + telegraph = 1.2 + (d-7)/6 + 1.4.
        # The server flips Alert -> Hunt on the tick at 1.2 s but only acts on the next one (+0.2 s)
        # and rounds the walk up to whole ticks (+0 to 0.2 s). So the tick model is later by [0.2, 0.4).
        for d in (8.0, 10.0, 13.5, 19.0, 24.9, 28.0):
            r = self.run_one(STILL, POINT, (d, 0.0), 6.0, 28.0)
            formula = 1.2 + (d - 7) / 6.0 + 1.4
            self.assertGreaterEqual(r.strike_s - formula, 0.2 - 1e-9, d)
            self.assertLess(r.strike_s - formula, 0.4 + 1e-9, d)


class Sweeps(unittest.TestCase):
    def test_every_phase_at_the_diamond_centre_is_detected_and_struck(self):
        # Player at the centre: guardian is always 11.31..16 away, inside the day range 28.
        # d0 -> moves ceil((d0-7)/1.2): 11.31 -> 4 moves, 16 -> 8 moves (7.5 rounds up).
        # Strike tick = 7 + moves + 7: 18 ticks = 3.6 s at best, 22 ticks = 4.4 s at worst.
        sweep = sp.sweep(MODEL, PATROL, (0.0, -85.0), 6.0, 28.0, phases=720)
        self.assertEqual(len(sweep.results), 720)
        self.assertEqual(sweep.share_detected, 1.0)
        self.assertEqual(sweep.share_struck, 1.0)
        self.assertAlmostEqual(sweep.strike_min, 3.6, places=9)
        self.assertAlmostEqual(sweep.strike_max, 4.4, places=9)
        self.assertEqual(sweep.share_never, 0.0)

    def test_player_beyond_all_reach_is_never_detected(self):
        sweep = sp.sweep(MODEL, PATROL, (200.0, -85.0), 8.0, 38.0, phases=120)
        self.assertEqual(sweep.share_detected, 0.0)
        self.assertEqual(sweep.share_never, 1.0)
        self.assertIsNone(sweep.strike_min)

    def test_sweep_is_deterministic(self):
        a = sp.sweep(MODEL, PATROL, (35.0, -99.0), 6.0, 28.0, phases=360)
        b = sp.sweep(MODEL, PATROL, (35.0, -99.0), 6.0, 28.0, phases=360)
        self.assertEqual(a.results, b.results)

    def test_exposure_shares_use_inclusive_holds(self):
        # Stationary guardian 19 away: detect 0 s, strike 4.8 s, for every phase.
        sweep = sp.sweep(STILL, POINT, (19.0, 0.0), 6.0, 28.0, phases=10)
        self.assertEqual(sp.exposure(sweep, 4.5), (1.0, 0.0))   # warned, not struck by 4.5 s
        self.assertEqual(sp.exposure(sweep, 4.8), (1.0, 1.0))   # impact lands as the hold ends
        self.assertEqual(sp.exposure(sweep, 6.0), (1.0, 1.0))
        self.assertEqual(sp.exposure(sweep, 0.0), (1.0, 0.0))

    def test_exposure_when_never_detected(self):
        sweep = sp.sweep(STILL, POINT, (40.0, 0.0), 6.0, 28.0, phases=10)
        self.assertEqual(sp.exposure(sweep, 6.0), (0.0, 0.0))


class Analysis(unittest.TestCase):
    def test_objectives_outside_territory_are_not_targetable(self):
        world = sp.load_world(REPO)
        marker = sp.analyse(world, next(o for o in world.objectives if o.name == "lumipol marker"), phases=60)
        self.assertEqual(marker.zone, "outside")
        self.assertFalse(marker.targetable)
        old = sp.analyse(world, next(o for o in world.objectives if o.name == "old nest"), phases=60)
        self.assertEqual(old.zone, "fog")
        self.assertFalse(old.targetable)
        self.assertAlmostEqual(old.home_distance, math.hypot(110, 45), places=9)

    def test_nest_is_targetable_and_night_is_worse_than_day(self):
        world = sp.load_world(REPO)
        nest = sp.analyse(world, next(o for o in world.objectives if o.name == "nest"), phases=360)
        self.assertTrue(nest.targetable)
        self.assertEqual(nest.zone, "territory")
        # The patrol loop passes through detection range once per lap (30.2 s), so a still
        # player is eventually detected in every phase, but only some phases are quick.
        self.assertEqual(nest.day.share_never, 0.0)
        self.assertGreater(nest.day.strike_max, 20.0)
        warned_day, _ = sp.exposure(nest.day, 6.0)
        warned_night, _ = sp.exposure(nest.night, 6.0)
        self.assertGreater(warned_day, 0.0)
        self.assertGreater(warned_night, warned_day)
        self.assertLessEqual(nest.night.strike_min, nest.day.strike_min)


class Report(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = sp.main(argv)
        return code, out.getvalue()

    def test_header_states_the_limits(self):
        code, text = self.run_main(["--phases", "60"])
        self.assertEqual(code, 0)
        head = text[:1500].lower()
        for phrase in ("geometry only", "fun or balance", "trunks", "line of sight"):
            self.assertIn(phrase, head)

    def test_report_names_every_objective_and_the_hold(self):
        _, text = self.run_main(["--phases", "60"])
        for name in ("nest", "old nest", "lumipol marker", "capture L1", "capture E1", "capture S0a"):
            self.assertIn(name, text)
        self.assertIn("hold 4.5", text)
        self.assertIn("EXPOSES", text.upper())

    def test_report_is_deterministic(self):
        self.assertEqual(self.run_main(["--phases", "60"]), self.run_main(["--phases", "60"]))

    def test_bad_phase_count_is_rejected(self):
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                sp.main(["--phases", "0"])


if __name__ == "__main__":
    unittest.main()
