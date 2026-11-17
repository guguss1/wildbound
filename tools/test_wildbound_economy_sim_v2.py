"""Tests for tools/wildbound_economy_sim_v2.py (T05b, Wildbound 2.0 economy model).

Run: python -I -B -m unittest discover -s tools -p "test_wildbound_economy_sim_v2.py"
"""

import contextlib
import copy
import io
import json
import shutil
import sys
import tempfile
import time
import unittest
from pathlib import Path
from unittest import mock

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:
    sys.path.insert(0, _HERE)

import wildbound_economy_sim_v2 as sim  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
SPAWN_CLOCK = "src/wildbound/WildboundSpawnClock.luau"


def numbers(balance="proposed"):
    return sim.load_numbers(balance=balance)


class LoadingTests(unittest.TestCase):
    def test_module_importable_and_cli_help(self):
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(SystemExit) as raised:
                sim.main(["--help"])
        self.assertEqual(raised.exception.code, 0)

    def test_loads_live_economy_config(self):
        n = numbers()
        self.assertEqual(n["creature_esencia"]["Fog"], 14)
        self.assertEqual(n["egg_esencia"]["Heart"], 36)
        self.assertEqual(n["first_steal_bonus"], 4)
        self.assertEqual(n["extract_base"], 4)

    def test_loads_balance_constants(self):
        n = numbers()
        self.assertEqual(tuple(n["sell_price"][r] for r in sim.RARITIES), (15, 60, 200, 650))
        self.assertEqual(n["farm_cap_minutes"], 15)
        self.assertEqual(n["roulette"]["spinCost"], 45)
        self.assertEqual(sum(n["roulette"]["weights"].values()), 100)

    def test_balance_parser_strips_comments_and_bracket_keys(self):
        self.assertEqual(sim.parse_balance_literal("freeze({ [5] = 200, -- x\n a = 1 })"), {5: 200, "a": 1})
        self.assertNotIn("x", sim.strip_comments("a = 1 -- x"))

    def test_mirror_drift_detected(self):
        self.assertEqual(sim.check_drift(), [])
        with tempfile.TemporaryDirectory() as tmp:
            patched = Path(tmp) / "WildboundSpawnClock.luau"
            text = (REPO / SPAWN_CLOCK).read_text(encoding="utf-8")
            self.assertIn("EGG_SHARE = 0.4,", text)
            patched.write_text(text.replace("EGG_SHARE = 0.4,", "EGG_SHARE = 0.5,"), encoding="utf-8")
            drift = sim.check_drift(paths={SPAWN_CLOCK: patched})
        self.assertTrue(any("EGG_SHARE" in line for line in drift), drift)

    def test_missing_source_raises_numbers_unavailable(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(sim.NumbersUnavailable) as raised:
                sim.load_numbers(repo=Path(tmp))
        self.assertIn("WildboundEconomyConfig", str(raised.exception))


class SessionTests(unittest.TestCase):
    def setUp(self):  # per test, so a missing implementation fails each case on its own
        self.n = numbers()
        self.profiles = sim.default_profiles()

    def test_deterministic_same_seed(self):
        p = self.profiles["intermediate"]
        a = sim.simulate_session(self.n, p, 30, seed=7)
        b = sim.simulate_session(self.n, p, 30, seed=7)
        c = sim.simulate_session(self.n, p, 30, seed=8)
        self.assertEqual(a, b)
        self.assertNotEqual(a, c)

    def test_no_wall_clock(self):
        def boom(*_a, **_k):
            raise AssertionError("wall clock used")
        with mock.patch.object(time, "time", boom), mock.patch.object(time, "monotonic", boom), \
                mock.patch.object(time, "perf_counter", boom):
            result = sim.simulate_session(self.n, self.profiles["beginner"], 10, seed=1)
        self.assertGreaterEqual(result["esencia_total"], 0)

    def test_first_and_second_hatch_timers(self):
        self.assertEqual(sim.incubation_seconds(self.n, "Legendaria", 0, 0), 10)
        self.assertEqual(sim.incubation_seconds(self.n, "Legendaria", 1, 0), 20)
        self.assertEqual(sim.incubation_seconds(self.n, "Rara", 2, 0), 75)
        self.assertAlmostEqual(sim.incubation_seconds(self.n, "Legendaria", 2, 3), 210)
        state = sim.new_state(self.n, self.profiles["beginner"], 600)
        state.queue_egg("Comun", 0)
        state.advance_incubator(self.n, 9)
        self.assertEqual(state.hatch_times, [])
        state.advance_incubator(self.n, 10)
        self.assertEqual(state.hatch_times, [10])
        state.queue_egg("Comun", 10)
        state.advance_incubator(self.n, 100)
        self.assertEqual(state.hatch_times, [10, 30])
        live = numbers("live")
        self.assertEqual(sim.incubation_seconds(live, "Comun", 0, 0), 15)
        self.assertEqual(sim.incubation_seconds(live, "Legendaria", 0, 0), 75)

    def test_farm_cap_15_minutes(self):
        state = sim.new_state(self.n, self.profiles["beginner"], 3600)
        state.add_to_farm("Comun", 0)
        gained = sim.collect_farm(state, self.n, 3600)
        self.assertAlmostEqual(gained, 15)

    def test_esencia_never_lost_on_defeat(self):
        state = sim.new_state(self.n, self.profiles["beginner"], 3600)
        sim.bank_trip(state, self.n, 100, 100, ["Comun"], ["Comun"], lost=False)
        banked = state.esencia
        self.assertGreater(banked, 0)
        sim.bank_trip(state, self.n, 250, 150, ["Rara", "Epica"], ["Rara"], lost=True)
        self.assertEqual(state.esencia, banked)
        self.assertEqual(state.eggs_lost, 2)
        self.assertEqual(state.eggs_banked, 1)

    def test_extract_base_requires_25s(self):
        # BP3 (2026-11-15): minExpeditionSeconds 45 -> 25. Edited without running (no Python on that machine).
        short = sim.new_state(self.n, self.profiles["beginner"], 3600)
        sim.bank_trip(short, self.n, 20, 20, [], ["Comun"], lost=False)
        long_ = sim.new_state(self.n, self.profiles["beginner"], 3600)
        sim.bank_trip(long_, self.n, 25, 25, [], ["Comun"], lost=False)
        self.assertEqual(short.esencia, self.n["creature_esencia"]["Fog"])
        self.assertEqual(long_.esencia, self.n["creature_esencia"]["Fog"] + self.n["extract_base"])

    def test_treadmill_cost_ladder_matches_balance(self):
        self.assertEqual(sim.treadmill_costs(self.n), [0, 30, 80, 200, 450, 900])

    def test_profiles_ordered(self):
        rates = []
        for name in ("beginner", "intermediate", "advanced"):
            runs = [sim.simulate_session(self.n, self.profiles[name], 30, seed=7 + i) for i in range(200)]
            rates.append(sim.aggregate(runs, 30)["esencia_per_hour"]["total"]["mean"])
        self.assertLess(rates[0], rates[1])
        self.assertLess(rates[1], rates[2])


class ReportTests(unittest.TestCase):
    _report = None

    def setUp(self):  # per test (cached), so a missing implementation fails each case on its own
        self.n = numbers()
        if ReportTests._report is None:
            ReportTests._report = sim.run_all(self.n, sim.default_profiles(), [10, 30, 60], seed=7, runs=20)
        self.report = ReportTests._report

    def test_outputs_have_all_cells(self):
        cells = self.report["cells"]
        self.assertEqual(len(cells), 9)
        self.assertEqual({(c["profile"], c["minutes"]) for c in cells},
                         {(p, m) for p in ("beginner", "intermediate", "advanced") for m in (10, 30, 60)})
        for cell in cells:
            for key in ("esencia_per_hour", "eggs_per_hour", "passive_share", "time_to_upgrade",
                        "first_egg_s", "first_hatch_s", "indicators"):
                self.assertIn(key, cell)
            for part in ("total", "expedition", "farm", "sale"):
                self.assertIn(part, cell["esencia_per_hour"])

    def test_idle_farm_ratio_computed(self):
        self.assertAlmostEqual(sim.idle_farm_esencia_per_hour(self.n, ["Comun"] * 4, 15), 240)
        self.assertAlmostEqual(sim.idle_farm_esencia_per_hour(self.n, ["Legendaria"] * 4, 15), 3600)
        for cell in self.report["cells"]:
            self.assertIn("idle_farm_ratio", cell["indicators"])

    def test_legendary_break_even_minutes(self):
        self.assertAlmostEqual(sim.break_even_minutes(self.n, "Legendaria"), 650 / 15)

    def test_roulette_break_even_esencia_value(self):
        weights = self.n["roulette"]["weights"]
        zero = {k: 0 for k in weights}
        result = sim.roulette_ev(weights, dict(zero, esencia=100), 45)
        self.assertAlmostEqual(result["break_even_esencia_value"], 45 / 0.35)
        self.assertFalse(result["infinite_money_risk"])
        self.assertTrue(sim.roulette_ev(weights, dict(zero, esencia=129), 45)["infinite_money_risk"])

    def test_roulette_free_first_spin_not_counted_as_cost(self):
        self.assertEqual(sim.roulette_cost(self.n, 1), 0)
        self.assertEqual(sim.roulette_cost(self.n, 3), 90)

    def test_stall_indicator_flags_synthetic_case(self):
        self.assertTrue(sim.stall_flag(1, 30, 600))
        self.assertFalse(sim.stall_flag(1, 30, 200))
        self.assertFalse(sim.stall_flag(600, 30, 600))
        self.assertFalse(hasattr(sim, "lockout_flag"))

    def test_hard_lockout_indicator_synthetic_case(self):
        # esencia, income per hour, cheapest cost, stall seconds, session hours
        self.assertTrue(sim.hard_lockout_flag(0, 0, 30, 600, 1.0))  # income near zero
        self.assertTrue(sim.hard_lockout_flag(10, 100, 500, 600, 1.0))  # 10 + 100 x 1 h < 500
        self.assertFalse(sim.hard_lockout_flag(10, 600, 500, 600, 1.0))  # one session of income pays it
        self.assertFalse(sim.hard_lockout_flag(0, 0, 30, 200, 1.0))  # not stalled long enough
        self.assertFalse(sim.hard_lockout_flag(0, 0, None, 600, 1.0))  # nothing left to buy

    def test_exponential_ladder_indicator(self):
        costs = sim.training_costs(self.n)
        self.assertEqual(costs[0], 20)  # BP1-D4 (2026-11-15): BASE_COST 30 -> 20
        self.assertEqual(len(costs), 17)  # PF2: 17 live walk levels
        self.assertAlmostEqual(sim.ladder_indicator(costs)["growth"], 1.1, delta=0.02)  # BP1-D4: COST_GROWTH 1.2 -> 1.1

    def test_crafted_100x_ladder_flags(self):
        out = sim.ladder_indicator([0, 30, 3000, 300000, 3e7], 500, 60)
        self.assertAlmostEqual(out["growth"], 100)
        self.assertTrue(out["growth_flag"])
        self.assertTrue(out["flag"])
        self.assertGreater(sim.LADDER_GROWTH_THRESHOLD, 1.6)
        treadmill = sim.ladder_indicator(sim.treadmill_costs(self.n), 3000, 60)
        self.assertFalse(treadmill["growth_flag"])  # 2.34 under the ASSUMED 2.5

    def test_ladder_hours_to_top_and_owned_level(self):
        out = sim.ladder_indicator([0, 30, 80, 200], 100, 60, owned_levels=1)
        self.assertAlmostEqual(out["hours_for_next"], 0.8)
        self.assertAlmostEqual(out["hours_to_top"], 2.8)
        self.assertAlmostEqual(out["sessions_to_top"], 2.8)
        self.assertFalse(out["top_flag"])
        far = sim.ladder_indicator([0, 30, 80, 200], 10, 10)  # 310 / 10 = 31 h = 186 ten-minute sessions
        self.assertTrue(far["top_flag"])
        self.assertTrue(far["flag"])
        done = sim.ladder_indicator([0, 30, 80, 200], 100, 60, owned_levels=3)
        self.assertIsNone(done["hours_for_next"])
        self.assertEqual(done["hours_to_top"], 0)
        self.assertFalse(done["top_flag"])

    def test_ladder_runs_use_each_runs_level(self):
        runs = [{"treadmill_level": 0, "esencia_total": 100}, {"treadmill_level": 2, "esencia_total": 100}]
        out = sim.ladder_runs([0, 30, 80, 200], runs, "treadmill_level", 60)
        self.assertAlmostEqual(out["hours_for_next_mean"], (0.3 + 2.0) / 2)
        self.assertAlmostEqual(out["owned_level_mean"], 1.0)
        self.assertEqual(out["ratios"], [2.667, 2.5])

    def test_roulette_esencia_share_from_weights(self):
        weights = dict(self.n["roulette"]["weights"])
        result = sim.roulette_ev(weights, sim.ROULETTE_PLACEHOLDER_VALUES, 45)
        self.assertAlmostEqual(result["esencia_share"], weights["esencia"] / sum(weights.values()))
        moved = dict(weights, esencia=weights["esencia"] + weights["materials"], materials=0)
        report = dict(self.report, roulette=sim.roulette_ev(moved, sim.ROULETTE_PLACEHOLDER_VALUES, 45))
        share = moved["esencia"] / 100
        text = sim.render_md(report)
        self.assertIn(f"Break-even with every other category at 0: {45 / share:.1f}.", text)
        self.assertIn(f"EV is {60 * share:.1f} per spin", text)

    def test_report_renames_and_mirror_lines(self):
        text = sim.render_md(self.report)
        self.assertIn("Hatches per session", text)
        self.assertNotIn("| Hatches |", text)
        self.assertIn("Stall runs %", text)
        self.assertIn("Hard lockout runs %", text)
        self.assertNotIn("Lockout runs %", text)
        for entry in sim.MIRRORED.values():
            self.assertNotIn("line", entry)
        self.assertNotIn("WildboundSpawnClock.luau:70", text)

    def test_fresh_account_assumption_labelled(self):
        data = json.loads(sim.render_json(self.report))
        modes = [a for a in data["assumptions"] if a["field"] == "farm_mode"]
        self.assertTrue(modes and modes[0]["assumed"])
        self.assertIn("fresh account", sim.render_md(self.report))

    def test_assumed_fields_labelled(self):
        data = json.loads(sim.render_json(self.report))
        fields = {a["field"] for a in data["assumptions"] if a.get("assumed")}
        for name in sim.Profile.FIELDS:
            self.assertIn(name, fields)

    def test_tbd_farm_slots_reported_not_crashing(self):
        for cell in self.report["cells"]:
            self.assertEqual(cell["time_to_upgrade"]["farm_slot_7"], "TBD")
            self.assertEqual(cell["time_to_upgrade"]["farm_slot_8"], "TBD")
        self.assertIn("TBD", sim.render_md(self.report))

    def test_markdown_header_disclaimer(self):
        text = sim.render_md(self.report)
        self.assertEqual(text.splitlines()[2], "Model, not measured balance; ASSUMED fields listed below.")


def crafted(n, **changes):
    """A deep copy of the numbers with crafted cost ladders."""
    out = copy.deepcopy(n)
    if "treadmill" in changes:
        out["treadmill_cost_ladder"] = list(changes["treadmill"])
    if "incubator" in changes:
        out["incubation"] = dict(out["incubation"], upgradeCosts=list(changes["incubator"]))
    if "cradle" in changes:
        out["incubation"] = dict(out["incubation"], secondCradleCost=changes["cradle"])
    if "slots" in changes:
        out["farm_slot_costs"] = dict(changes["slots"])
    return out


class CraftedConfigTests(unittest.TestCase):
    def setUp(self):
        self.n = numbers()
        self.profiles = sim.default_profiles()

    def test_unaffordable_config_sets_stall_and_hard_lockout(self):
        bad = crafted(self.n, treadmill=[0, 1e5, 1e5, 1e5, 1e5, 1e5], incubator=[0, 1e5, 1e5, 1e5],
                      cradle=1e5, slots={5: 1e5, 6: 1e5, 7: None, 8: None})
        result = sim.simulate_session(bad, self.profiles["beginner"], 60, seed=7)
        self.assertTrue(result["stall"])
        self.assertTrue(result["hard_lockout"])
        normal = sim.simulate_session(self.n, self.profiles["advanced"], 60, seed=7)
        self.assertFalse(normal["hard_lockout"])

    def test_crafted_exponential_ladder_sets_ladder_flag_end_to_end(self):
        bad = crafted(self.n, treadmill=[0, 30, 3000, 300000, 3e7, 3e9])
        report = sim.run_all(bad, {"beginner": self.profiles["beginner"]}, [30], seed=7, runs=5)
        ladder = report["cells"][0]["indicators"]["exponential_ladder"]["treadmill_proposed"]
        self.assertTrue(ladder["growth_flag"])
        self.assertEqual(ladder["flag_share"], 1.0)
        good = sim.run_all(self.n, {"advanced": self.profiles["advanced"]}, [60], seed=7, runs=5)
        self.assertFalse(good["cells"][0]["indicators"]["exponential_ladder"]["treadmill_proposed"]["growth_flag"])

    def test_invariants_for_all_runs(self):
        n = self.n
        maxima = {"treadmill_level": len(n["treadmill_cost_ladder"]) - 1,
                  "incubator_level": len(n["incubation"]["upgradeCosts"]) - 1,
                  "cradles": 2,
                  "slot_level": max(s for s, c in n["farm_slot_costs"].items() if c is not None)}
        for name, profile in self.profiles.items():
            for minutes in (10, 30, 60):
                for mode in ("fresh", "carry"):
                    for policy in ("free", "spend"):
                        for seed in range(5):
                            r = sim.simulate_session(n, profile, minutes, seed, policy, farm_mode=mode)
                            where = (name, minutes, mode, policy, seed)
                            self.assertGreaterEqual(r["esencia_end"], 0, where)
                            for key, top in maxima.items():
                                self.assertLessEqual(r[key], top, (key,) + where)
                            self.assertLessEqual(len(r["farm"]), r["farm_slots"], where)
                            self.assertTrue(all(v < minutes * 60 for v in r["purchases"].values()), where)
                            self.assertIn("end_purchases", r)

    def test_spend_mode_deducts_spin_spend(self):
        r = sim.simulate_session(self.n, self.profiles["advanced"], 30, 7, "spend")
        self.assertGreater(r["spins"], 1)
        self.assertEqual(r["spin_spend"], sim.roulette_cost(self.n, r["spins"]))
        self.assertAlmostEqual(r["esencia_total"], sum(r["split"].values()) - r["spin_spend"], places=4)
        free = sim.simulate_session(self.n, self.profiles["advanced"], 30, 7, "free")
        self.assertEqual(free["spin_spend"], 0)

    def test_hatch_timer_counts_finished_hatches(self):
        state = sim.new_state(self.n, self.profiles["beginner"], 600)
        state.cradle_free = [0.0, 0.0]
        state.queue_egg("Comun", 0)
        state.queue_egg("Comun", 0)  # starts before the first hatch finishes: 0 hatches done, so 10 s too
        state.queue_egg("Comun", 15)  # starts after both finished: the base Comun time
        state.advance_incubator(self.n, 200)
        self.assertEqual(state.hatch_times, [10, 10, 55])

    def test_place_hatch_sell_vs_farm(self):
        adv = self.profiles["advanced"]
        late = sim.new_state(self.n, adv, 3600)
        sim.place_hatch(late, self.n, "Legendaria", 3000)  # 10 min left: 150 < 650, sold
        self.assertEqual((late.sold["Legendaria"], late.farm), (1, []))
        early = sim.new_state(self.n, adv, 3600)
        sim.place_hatch(early, self.n, "Legendaria", 0)  # 60 min left: 900 >= 650, farmed
        self.assertEqual((early.sold["Legendaria"], [r for r, _ in early.farm]), (0, ["Legendaria"]))
        carry = sim.new_state(self.n, adv, 3600, farm_mode="carry")
        carry.farm = []
        sim.place_hatch(carry, self.n, "Legendaria", 3000)  # the farm persists: valued past the session end
        self.assertEqual(carry.sold["Legendaria"], 0)
        self.assertIn("Legendaria", [r for r, _ in carry.farm])
        mid = sim.new_state(self.n, self.profiles["intermediate"], 3600)
        for _ in range(4):
            mid.add_to_farm("Comun", 0)
        sim.place_hatch(mid, self.n, "Rara", 60)  # evicts a Comun, which is kept in storage (not Rara+)
        self.assertEqual(sorted(r for r, _ in mid.farm), ["Comun", "Comun", "Comun", "Rara"])
        self.assertEqual((mid.storage, mid.sold["Comun"]), (["Comun"], 0))
        sim.place_hatch(mid, self.n, "Rara", 120)  # evicts another Comun; still not sold
        sim.place_hatch(mid, self.n, "Comun", 180)  # the hatched Comun is the loser: stored
        self.assertEqual(mid.sold["Comun"], 0)
        for _ in range(2):
            sim.place_hatch(mid, self.n, "Epica", 240)
        sim.place_hatch(mid, self.n, "Rara", 300)  # the farm is now Rara x2 + Epica x2: the Rara loser is sold
        self.assertEqual(mid.sold["Rara"], 1)

    def test_carry_farm_mode(self):
        p = self.profiles["advanced"]
        state = sim.new_state(self.n, p, 600, farm_mode="carry")
        self.assertEqual(sorted(r for r, _ in state.farm), sorted(p.carry_farm))
        self.assertTrue(state.first_steal_paid)
        fresh = sim.simulate_session(self.n, p, 10, 7)
        carry = sim.simulate_session(self.n, p, 10, 7, farm_mode="carry")
        self.assertEqual(fresh["farm_mode"], "fresh")
        self.assertEqual(carry["farm_mode"], "carry")
        self.assertGreater(carry["split"]["farm"], fresh["split"]["farm"])
        self.assertEqual(carry["split"]["roulette"], 0)  # the free first spin was used in an earlier session
        report = sim.run_all(self.n, {"advanced": p}, [10], seed=7, runs=3, farm_modes=("fresh", "carry"))
        self.assertEqual([c["farm_mode"] for c in report["cells"]], ["fresh", "carry"])
        self.assertIn("| advanced | carry | 10 |", sim.render_md(report))

    def test_cli_farm_mode_both_is_deterministic(self):
        argv = ["--profile", "beginner", "--minutes", "10", "--runs", "3", "--farm-mode", "both", "--md"]
        outs = []
        for _ in range(2):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                sim.main(argv)
            outs.append(buf.getvalue())
        self.assertEqual(outs[0], outs[1])
        self.assertIn("--farm-mode both", outs[0])
        self.assertIn("| beginner | carry | 10 |", outs[0])



# ---- Live game model (2026-11-15) ---------------------------------------------------------------------------------
class LiveLoadingTests(unittest.TestCase):
    def setUp(self):
        self.live = sim.load_live_game()

    def test_live_mirrors_are_in_check_drift(self):
        for name in ("treadmill_lap_seconds", "treadmill_lap_esencia", "base_incubator_slots", "nightbloom_wilt_seconds",
                     "candy_nest_eggs", "farm_slots", "parent_chase_speed", "portal_carry", "egg_max_carry",
                     "wave_seconds"):
            self.assertIn(name, sim.MIRRORED)
        self.assertEqual(sim.check_drift(), [])

    def test_lap_esencia_drift_detected(self):
        server = sim.MIRRORED["treadmill_lap_esencia"]["source"]
        text = (REPO / server).read_text(encoding="utf-8")
        with tempfile.TemporaryDirectory() as tmp:
            patched = Path(tmp) / "server.luau"
            patched.write_text(text.replace("C.MAX_LEVEL, 5, need)", "C.MAX_LEVEL, 0, need)"), encoding="utf-8")
            drift = sim.check_drift(paths={server: patched})
        self.assertTrue(any("treadmill_lap_esencia" in line for line in drift), drift)

    def test_live_training_and_wave(self):
        live = self.live
        self.assertEqual(live["training"]["WALK_STEP"], 2)
        self.assertEqual(live["training"]["MAX_LEVEL"], 17)
        self.assertEqual(live["training"]["WALK_CAP"], 50)
        self.assertEqual(live["training"]["COST_GROWTH"], 1.1)  # BP1-D4 (2026-11-15), was 1.2
        self.assertEqual(live["training"]["BASE_COST"], 20)  # BP1-D4, was 30
        self.assertEqual(live["training"]["LAP_STEP"], 1)  # BP1: level L+1 needs L+1 laps
        self.assertEqual(live["wave_seconds"], 300)
        self.assertEqual(live["collection_limit"], 100)
        self.assertEqual(live["farm_slots"], 4)

    def test_live_caramelo_nests(self):
        nests = self.live["candy_nests"]
        self.assertEqual(len(nests), 19)  # CH3 (2026-11-16, "more eggs"): 11 -> 19
        by_rarity = {}
        for nest in nests:
            by_rarity[nest["rarity"]] = by_rarity.get(nest["rarity"], 0) + 1
        self.assertEqual(by_rarity, {"Comun": 10, "Rara": 7, "Epica": 2})  # CH3: was 5, 4, 2
        self.assertEqual({n["species"] for n in nests if n["rarity"] == "Comun"}, {"Gomibu"})
        self.assertEqual({n["species"] for n in nests if n["rarity"] == "Rara"}, {"Tortidragon"})
        self.assertEqual({n["species"] for n in nests if n["rarity"] == "Epica"}, {"Flanfuria"})
        self.assertEqual({n["rarity"]: n["esencia"] for n in nests}, {"Comun": 4, "Rara": 10, "Epica": 16})  # BP3: one tier lower
        self.assertEqual({n["rarity"]: n["hatch_s"] for n in nests}, {"Comun": 15, "Rara": 45, "Epica": 60})
        self.assertTrue(all(n["eggs"] == 1 for n in nests))

    def test_live_forest_islands(self):
        islands = self.live["forest_islands"]
        self.assertEqual([i["id"] for i in islands], ["I1", "I2", "I3", "I4", "I5"])
        self.assertTrue(all(i["eggs"] == 3 and i["adults"] >= 2 for i in islands))

    def test_live_roulette_table(self):
        rou = self.live["roulette"]
        self.assertEqual(rou["spinCost"], 45)
        self.assertTrue(rou["freeFirstSpin"])
        self.assertEqual(rou["pity"]["every"], 10)


class LiveRuleTests(unittest.TestCase):
    def setUp(self):
        self.live = sim.load_live_game()

    def test_trained_walk_and_carry_speed(self):
        self.assertEqual(sim.live_walk(self.live, 0), 16)
        self.assertEqual(sim.live_walk(self.live, 17), 50)
        self.assertEqual(sim.live_walk(self.live, 30), 50)
        self.assertAlmostEqual(sim.live_carry(self.live, 17, 1), 34.375)
        self.assertEqual(sim.live_carry(self.live, 0, 1), 11)
        self.assertAlmostEqual(sim.live_carry(self.live, 17, 5), 9 * 50 / 16)

    def test_treadmill_progression_table(self):
        rows = sim.treadmill_progression(self.live)
        self.assertEqual(len(rows), 18)
        # BP1 (2026-11-15): level L+1 needs L+1 laps (153 laps to the top) and only a level-up lap pays.
        self.assertEqual(rows[1]["lap_seconds_total"], 8)
        self.assertEqual(rows[2]["lap_seconds_total"], 3 * 8)
        self.assertEqual(rows[-1]["lap_seconds_total"], 153 * 8)
        self.assertEqual(rows[-1]["lap_esencia_total"], 17 * 5)
        self.assertEqual(rows[1]["console_cost"], 20)
        self.assertEqual(rows[-1]["console_cost"], 92)
        self.assertEqual(rows[-1]["console_total"], 811)

    def test_afk_treadmill_rate(self):
        # BP1: standing on the belt after the top pays nothing (was 37.5 Esencia/min).
        self.assertEqual(sim.afk_treadmill_esencia_per_minute(self.live), 0.0)

    def test_nightbloom_supply_now_beats_old_cycle(self):
        nb = sim.nightbloom_supply(self.live)
        self.assertGreater(nb["now_per_hour"], 0)
        self.assertAlmostEqual(nb["old_cycle_per_hour"], nb["now_per_hour"] * 300 / 720)
        self.assertEqual(nb["wilt_seconds"], 300)

    def test_roulette_sink(self):
        r = sim.live_roulette_summary(self.live)
        self.assertAlmostEqual(r["esencia_per_paid_spin"], 12.01, places=1)
        self.assertAlmostEqual(r["net_esencia_per_paid_spin"], r["esencia_per_paid_spin"] - 45)
        self.assertLess(r["net_esencia_per_paid_spin"], 0)


class LiveSessionTests(unittest.TestCase):
    def setUp(self):
        self.live = sim.load_live_game()
        self.profiles = sim.default_live_profiles()

    def test_deterministic(self):
        p = self.profiles["intermediate"]
        a = sim.simulate_live_session(self.live, p, "caramelo", 30, seed=3)
        b = sim.simulate_live_session(self.live, p, "caramelo", 30, seed=3)
        self.assertEqual(a, b)

    def test_invariants(self):
        for name, p in self.profiles.items():
            for route in sim.LIVE_ROUTES:
                r = sim.simulate_live_session(self.live, p, route, 30, seed=11)
                self.assertGreaterEqual(r["esencia_total"], 0)
                self.assertAlmostEqual(r["esencia_total"], sum(r["split"].values()), places=6)
                self.assertLessEqual(r["collection"], self.live["collection_limit"])
                self.assertLessEqual(r["walk_level"], 17)
                if r["first_hatch_s"] is not None:
                    self.assertGreater(r["first_hatch_s"], r["first_egg_s"])

    def test_caramelo_wave_cap(self):
        """One solo server: at most 19 Caramelo eggs per 300 s wave can be stolen (CH3: was 11)."""
        p = self.profiles["advanced"]
        r = sim.simulate_live_session(self.live, p, "caramelo", 10, seed=5)
        waves = 10 * 60 / 300 + 1
        self.assertLessEqual(r["eggs_stolen"], 19 * waves)

    def test_collection_limit_stops_steals(self):
        live = dict(self.live, collection_limit=5)
        r = sim.simulate_live_session(live, self.profiles["advanced"], "caramelo", 30, seed=1)
        self.assertEqual(r["collection"], 5)
        self.assertIsNotNone(r["collection_full_s"])

    def test_treadmill_laps_at_start_train_walk(self):
        # BP1: the beginner's 4 laps reach level 2 (1 + 2 laps, the 4th is progress) and pay two level-ups only.
        r = sim.simulate_live_session(self.live, self.profiles["beginner"], "forest", 10, seed=2)
        self.assertEqual(r["walk_level"], 2)
        self.assertEqual(r["split"]["treadmill"], 2 * 5)

    def test_idle_treadmill_is_not_an_income(self):
        # BP1: an hour on the belt reaches the top once (153 laps) and pays 85 Esencia in all, then nothing.
        live = dict(self.live, candy_nests=[], forest_islands=[])
        idle = sim.LiveProfile(**dict(sim.asdict(self.profiles["advanced"]), laps_at_start=0))
        r = sim.simulate_live_session(live, idle, "forest", 60, seed=1)
        self.assertEqual(r["walk_level"], 17)
        self.assertEqual(r["split"]["treadmill"], 85)
        # 153 laps of 8 s; the idle rides stop at each wave, so a few seconds of a lap are lost per wave.
        self.assertGreaterEqual(r["max_walk_s"], 153 * 8)
        self.assertLess(r["max_walk_s"], 153 * 8 + 60)

    def test_run_live_and_render(self):
        report = sim.run_live(self.live, self.profiles, [10, 30, 60], seed=7, runs=4)
        self.assertEqual(len(report["cells"]), 3 * len(sim.LIVE_ROUTES) * 3)
        text = sim.render_live_md(report)
        self.assertIn("Esencia/min", text)
        self.assertIn("Treadmill progression", text)
        self.assertIn("Nightbloom", text)
        self.assertIn("Roulette", text)
        self.assertIn("ASSUMED", text)



class LiveFindingsTests(unittest.TestCase):
    def setUp(self):
        self.live = sim.load_live_game()
        self.profiles = sim.default_live_profiles()

    def test_what_ifs_move_the_flagged_numbers(self):
        rows = sim.run_what_ifs(self.live, self.profiles, minutes=30, runs=5)
        by = {(r["case"], r["profile"], r["route"]): r for r in rows}
        self.assertNotIn(("lap Esencia only on a level-up lap", "advanced", "mixed"), by)  # BP1: applied, now as built
        # BP1: the intermediate profile's 17 laps now reach level 5 (walk 26), so the 24 cap is felt by the advanced
        # profile, which keeps training on the belt between waves.
        capped = by[("carrier share of at most a 24 walk", "advanced", "mixed")]
        # Deliberately changed (CH3, 2026-11-16: 19 Caramelo nests, faster guardians): with eight more nests the capped
        # carrier makes fewer trips, so its losses per hour now fall (64.8 vs 72.0) instead of rising; the what-if still
        # moves the number.
        self.assertNotEqual(capped["eggs_lost_per_hour"], by[("as built", "advanced", "mixed")]["eggs_lost_per_hour"])

    def test_carry_cap_what_if(self):
        capped = dict(self.live, carry_trained_cap=24)
        self.assertAlmostEqual(sim.live_carry(capped, 17, 1), 11 * 24 / 16)
        self.assertAlmostEqual(sim.live_carry(self.live, 17, 1), 34.375)

    def test_findings_section(self):
        report = sim.run_live(self.live, self.profiles, [10, 60], seed=7, runs=3)
        text = sim.render_live_findings(report, sim.run_what_ifs(self.live, self.profiles, minutes=10, runs=2))
        for words in ("## 2026-11-15 findings", "### Too easy", "### Too slow", "treadmill", "collection limit",
                      "Caramelo", "Suggest", "What-if"):
            self.assertIn(words, text)

    def test_cli_has_live_section_and_no_live_skips_it(self):
        def run(argv):
            buf = io.StringIO()
            with contextlib.redirect_stdout(buf):
                sim.main(argv)
            return buf.getvalue()
        base = ["--profile", "beginner", "--minutes", "10", "--runs", "2", "--md"]
        text = run(base)
        self.assertIn("## Live game model (2026-11-15)", text)
        self.assertIn("## 2026-11-15 findings", text)
        self.assertIn("## Proposed 2.0 balance model", text)
        self.assertEqual(text.splitlines()[2], sim.DISCLAIMER)
        self.assertNotIn("## Live game model", run(base + ["--no-live"]))

    def test_json_has_live_results(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp) / "r.json"
            with contextlib.redirect_stdout(io.StringIO()):
                sim.main(["--profile", "beginner", "--minutes", "10", "--runs", "2", "--json", str(out)])
            data = json.loads(out.read_text(encoding="utf-8"))
        self.assertIn("cells", data["live_model"])
        self.assertNotIn("live", data["live_model"])
        self.assertEqual(data["live_model"]["profiles"]["beginner"]["max_eggs_per_trip"], 1)


if __name__ == "__main__":
    unittest.main()
