"""Contracts for the Wildbound P0 economy simulator.

Run from the project root (isolated mode, no bytecode written):

    python -I -B -m unittest discover -s tools -p "test_simulate_*.py"

The simulator reads the fenced `json economy-tuning` block of
docs/mechanics/wildbound-economy-p0.md at run time. These tests therefore
restate hand-derived numbers (the loss table, hand-measured tours) and pin
them against the document, instead of importing the numbers from the module.

They model math only. They say nothing about fun or balance.
"""

import contextlib
import copy
import io
import math
import re
import unittest
from pathlib import Path

import simulate_economy as eco

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/mechanics/wildbound-economy-p0.md"

_CACHE = {}


def tuning():
    if "t" not in _CACHE:
        _CACHE["t"] = eco.load_tuning(DOC)
    return copy.deepcopy(_CACHE["t"])


def context():
    if "c" not in _CACHE:
        _CACHE["c"] = eco.load_context(REPO)
    return _CACHE["c"]


def idle_policy(**overrides):
    policy = {"zones": {"outside": 0, "fog": 0, "territory": 0}, "captureTier": None,
              "captureRate": 0.0, "eggRate": 0.0, "defeatChance": 0.0, "nightShare": 0.0}
    policy.update(overrides)
    return policy


class TuningBlock(unittest.TestCase):
    def test_block_is_read_from_the_document(self):
        t = tuning()
        self.assertEqual(t["schema"], "wildbound.economy.tuning")
        self.assertEqual(t["schemaVersion"], 1)
        self.assertEqual(t["monetization"], "none")
        self.assertIn("```json economy-tuning", DOC.read_text(encoding="utf-8"))

    def test_numbers_are_consumed_not_copied(self):
        # Change the rate inside the document text; the simulator must follow it.
        text = DOC.read_text(encoding="utf-8").replace('"rateBasisPoints": 1200', '"rateBasisPoints": 1000')
        t = eco.extract_tuning(text)
        state = eco.new_state(t)
        state["carried"]["fogbark"] = 100
        eco.apply_defeat(t, state)
        self.assertEqual(state["carried"]["fogbark"], 90)

    def test_missing_duplicate_or_bad_block_fails_loudly(self):
        good = DOC.read_text(encoding="utf-8")
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning("# nothing here")
        block = re.search(r"```json economy-tuning\n.*?```", good, re.S).group(0)
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good + "\n" + block)
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"schemaVersion": 1', '"schemaVersion": 2'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"schema": "wildbound.economy.tuning"', '"schema": "other"'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"monetization": "none",', '"monetization": "none"  oops'))
        with self.assertRaises(eco.TuningError):
            eco.extract_tuning(good.replace('"monetization": "none"', '"monetization": "robux"'))


class LossRule(unittest.TestCase):
    # Hand computed: (q * bp + 5000) // 10000, i.e. nearest, halves up.
    #   100: 12.00 -> 12, 8.00 -> 8     25: 3.00 -> 3, 2.00 -> 2
    #   12: 1.44 -> 1, 0.96 -> 1        5: 0.60 -> 1, 0.40 -> 0
    #   4: 0.48 -> 0, 0.32 -> 0         1: 0.12 -> 0, 0.08 -> 0
    TABLE = {100: (12, 8), 25: (3, 2), 12: (1, 1), 5: (1, 0), 4: (0, 0), 1: (0, 0), 0: (0, 0)}

    def test_rounding_table_for_both_rates(self):
        for quantity, (at12, at8) in self.TABLE.items():
            self.assertEqual(eco.lost(quantity, 1200), at12, quantity)
            self.assertEqual(eco.lost(quantity, 800), at8, quantity)

    def test_half_rounds_up_exactly(self):
        # 50 * 1000 bp = exactly 5.0 -> 5; 25 * 200 bp = 0.5 exactly -> 1; 24 * 200 bp = 0.48 -> 0.
        self.assertEqual(eco.lost(25, 200), 1)
        self.assertEqual(eco.lost(24, 200), 0)
        self.assertEqual(eco.lost(50, 1000), 5)

    def test_integer_arithmetic_has_no_float_error(self):
        big = 10 ** 18
        self.assertEqual(eco.lost(big, 1200), 12 * 10 ** 16)
        self.assertIsInstance(eco.lost(7, 1200), int)

    def test_document_table_agrees_with_the_rule(self):
        text = DOC.read_text(encoding="utf-8")
        rows = re.findall(r"^\| (\d+) \| (\d+) \| (\d+) \|$", text, re.M)
        self.assertGreaterEqual(len(rows), 6)
        for quantity, at12, at8 in rows:
            self.assertEqual(eco.lost(int(quantity), 1200), int(at12), quantity)
            self.assertEqual(eco.lost(int(quantity), 800), int(at8), quantity)

    def test_defeat_with_100_fogbark_and_three_items(self):
        t = tuning()
        s = eco.new_state(t)
        s["carried"]["fogbark"] = 100
        s["ember"] = 30
        s["bag"] = [{"kind": "creature", "tier": "Territory"}, {"kind": "egg", "tier": "Territory"},
                    {"kind": "creature", "tier": "Fog"}]
        summary = eco.apply_defeat(t, s)
        self.assertEqual(s["carried"]["fogbark"], 88)
        self.assertEqual(s["bag"], [])
        self.assertEqual(s["ember"], 30)
        self.assertEqual(summary["lost_items"], 3)
        self.assertEqual(summary["lost_units"]["fogbark"], 12)

    def test_loss_is_per_stack_not_on_the_total(self):
        # Three stacks of 5 lose 1 each (3). Rounding the 15-unit total at 12% would give 2.
        t = tuning()
        s = eco.new_state(t)
        s["carried"].update({"fogbark": 5, "glowmoss": 5, "nightbloom": 5})
        eco.apply_defeat(t, s)
        self.assertEqual(s["carried"], {"fogbark": 4, "glowmoss": 4, "nightbloom": 4})

    def test_reinforced_pack_lowers_the_rate(self):
        t = tuning()
        s = eco.new_state(t)
        s["upgrades"]["reinforcedPack"] = True
        s["carried"]["fogbark"] = 100
        eco.apply_defeat(t, s)
        self.assertEqual(s["carried"]["fogbark"], 92)

    def test_everything_listed_as_never_lost_is_untouched(self):
        t = tuning()
        s = eco.new_state(t)
        s["ember"] = 77
        s["banked"].update({"fogbark": 50, "glowmoss": 20, "nightbloom": 3})
        s["registered"] = [{"kind": "creature", "tier": "Fog"}]
        s["bankedEggs"] = [{"kind": "egg", "tier": "Territory"}]
        s["consumables"].update({"seal": 2, "capsule": 1, "totem": 1})
        s["upgrades"]["reinforcedPack"] = True
        s["skills"].update({"explorer_1": True})
        s["bond"] = {"pet-1": {"xp": 40, "level": 2}}
        s["carried"]["fogbark"] = 30
        s["bag"] = [{"kind": "egg", "tier": "Territory"}]
        before = copy.deepcopy(s)
        for key in t["loss"]["neverLost"]:
            self.assertIn(key, s, "state does not model neverLost entry " + key)
        eco.apply_defeat(t, s)
        for key in t["loss"]["neverLost"]:
            self.assertEqual(s[key], before[key], key)

    def test_same_operation_twice_loses_once(self):
        t = tuning()
        s = eco.new_state(t)
        s["carried"]["fogbark"] = 100
        eco.apply_defeat(t, s, operation_id="op-1")
        self.assertEqual(s["carried"]["fogbark"], 88)
        again = eco.apply_defeat(t, s, operation_id="op-1")
        self.assertEqual(s["carried"]["fogbark"], 88)
        self.assertTrue(again["duplicate"])

    def test_seal_spent_only_when_it_saves_an_item(self):
        t = tuning()
        s = eco.new_state(t)
        s["consumables"]["seal"] = 1
        eco.apply_defeat(t, s, use_seal=True)          # nothing in the bag: nothing to save
        self.assertEqual(s["consumables"]["seal"], 1)
        s["bag"] = [{"kind": "creature", "tier": "Fog"}, {"kind": "egg", "tier": "Territory"}]
        summary = eco.apply_defeat(t, s, use_seal=True)
        self.assertEqual(s["consumables"]["seal"], 0)
        self.assertEqual(len(s["bag"]), 1)
        self.assertEqual(summary["lost_items"], 1)
        self.assertEqual(s["bag"][0]["kind"], "egg")  # the newest item is the warded one

    def test_night_does_not_change_the_rate(self):
        self.assertIs(tuning()["loss"]["nightChangesRate"], False)


class Weights(unittest.TestCase):
    def test_normalize(self):
        self.assertEqual(eco.normalize({"a": 3, "b": 1}), {"a": 0.75, "b": 0.25})
        self.assertEqual(eco.normalize({"a": 5}), {"a": 1.0})
        self.assertEqual(eco.normalize({"a": 0, "b": 2}), {"a": 0.0, "b": 1.0})

    def test_bad_weights_are_rejected(self):
        for bad in ({}, {"a": 0}, {"a": -1, "b": 3}, {"a": float("nan")}):
            with self.assertRaises(eco.TuningError):
                eco.normalize(bad)

    def test_every_table_normalizes_to_one(self):
        t = tuning()
        for zone, phases in t["spawnWeights"].items():
            for phase in t["cycle"]["phaseOrder"]:
                probabilities = eco.spawn_probabilities(t, zone, phase)
                self.assertAlmostEqual(sum(probabilities.values()), 1.0, places=12, msg=(zone, phase))

    def test_night_only_materials_appear_only_at_night(self):
        t = tuning()
        for zone in t["spawnWeights"]:
            for phase in t["cycle"]["phaseOrder"]:
                probabilities = eco.spawn_probabilities(t, zone, phase)
                for material, spec in t["materials"].items():
                    if spec["nightOnly"] and phase != "Night":
                        self.assertEqual(probabilities.get(material, 0.0), 0.0, (zone, phase))

    def test_document_percentages_agree_with_the_json(self):
        text = DOC.read_text(encoding="utf-8")
        rows = re.findall(
            r"^\| (Outside, any|Fog, not Night|Fog, Night|Territory, not Night|Territory, Night)"
            r" \| ([\d.]+)% \| ([\d.]+)% \| ([\d.]+%|0) \|$", text, re.M)
        self.assertEqual(len(rows), 5)
        t = tuning()
        for label, fogbark, glowmoss, nightbloom in rows:
            zone = label.split(",")[0].lower()
            phase = "Night" if label.endswith("Night") and "not" not in label else "Day"
            p = eco.spawn_probabilities(t, zone, phase)
            self.assertAlmostEqual(100 * p["fogbark"], float(fogbark), places=6, msg=label)
            self.assertAlmostEqual(100 * p["glowmoss"], float(glowmoss), places=6, msg=label)
            expected = 0.0 if nightbloom == "0" else float(nightbloom.rstrip("%"))
            self.assertAlmostEqual(100 * p.get("nightbloom", 0.0), expected, places=6, msg=label)

    def test_seeded_draws_follow_the_table_and_repeat(self):
        t = tuning()
        expected = eco.spawn_probabilities(t, "territory", "Night")   # 25 / 40 / 35
        import random
        counts = {m: 0 for m in expected}
        rng = random.Random(7)
        for _ in range(100000):
            counts[eco.draw_material(t, "territory", "Night", rng)] += 1
        for material, p in expected.items():
            self.assertAlmostEqual(counts[material] / 100000, p, delta=0.01, msg=material)
        a = [eco.draw_material(t, "fog", "Night", random.Random(3)) for _ in range(5)]
        b = [eco.draw_material(t, "fog", "Night", random.Random(3)) for _ in range(5)]
        self.assertEqual(a, b)

    def test_yields_are_inclusive_ranges(self):
        t = tuning()
        import random
        rng = random.Random(1)
        seen = {eco.draw_yield(t, "territory", "fogbark", rng) for _ in range(200)}
        self.assertEqual(seen, {4, 5})   # [4, 5] inclusive
        seen = {eco.draw_yield(t, "fog", "glowmoss", rng) for _ in range(50)}
        self.assertEqual(seen, {2})      # [2, 2]


class Sinks(unittest.TestCase):
    def funded(self, **banked):
        t = tuning()
        s = eco.new_state(t)
        s["banked"].update({k: v for k, v in banked.items() if k != "ember"})
        s["ember"] = banked.get("ember", 0)
        return t, s

    def test_craft_pays_exactly_the_cost(self):
        t, s = self.funded(fogbark=8, glowmoss=4)
        self.assertEqual(eco.craft(t, s, "seal"), (True, "ok"))
        self.assertEqual(s["banked"], {"fogbark": 0, "glowmoss": 0, "nightbloom": 0})
        self.assertEqual(s["consumables"]["seal"], 1)

    def test_one_short_is_refused_and_changes_nothing(self):
        t, s = self.funded(fogbark=8, glowmoss=3)
        before = copy.deepcopy(s)
        self.assertEqual(eco.craft(t, s, "seal"), (False, "CannotAfford"))
        self.assertEqual(s, before)

    def test_cap_and_unknown_recipe(self):
        t, s = self.funded(fogbark=100, glowmoss=100)
        for _ in range(3):
            self.assertTrue(eco.craft(t, s, "seal")[0])
        before = copy.deepcopy(s)
        self.assertEqual(eco.craft(t, s, "seal"), (False, "AtLimit"))
        self.assertEqual(eco.craft(t, s, "nonsense"), (False, "UnknownRecipe"))
        self.assertEqual(s, before)

    def test_ember_is_a_cost_and_never_goes_negative(self):
        t, s = self.funded(fogbark=8, glowmoss=5, nightbloom=1, ember=11)
        self.assertEqual(eco.craft(t, s, "capsule"), (False, "CannotAfford"))
        s["ember"] = 12
        self.assertEqual(eco.craft(t, s, "capsule"), (True, "ok"))
        self.assertEqual(s["ember"], 0)

    def test_reinforced_pack_once_and_it_changes_capacity(self):
        t, s = self.funded(fogbark=60, glowmoss=30, ember=80)
        self.assertEqual((eco.pouch_capacity(t, s), eco.bag_capacity(t, s)), (30, 3))
        self.assertEqual(eco.upgrade(t, s, "reinforcedPack"), (True, "ok"))
        self.assertEqual((eco.pouch_capacity(t, s), eco.bag_capacity(t, s)), (45, 4))
        self.assertEqual(eco.loss_basis_points(t, s), 800)
        self.assertEqual(eco.upgrade(t, s, "reinforcedPack"), (False, "AlreadyOwned"))
        self.assertEqual((s["banked"]["fogbark"], s["banked"]["glowmoss"], s["ember"]), (30, 15, 40))

    def test_skill_prerequisites_and_repeat(self):
        t, s = self.funded(glowmoss=40, nightbloom=4, ember=200)
        self.assertEqual(eco.learn(t, s, "explorer_2"), (False, "NeedsPrerequisite"))
        self.assertEqual(eco.learn(t, s, "explorer_1"), (True, "ok"))
        self.assertEqual(eco.learn(t, s, "explorer_1"), (False, "AlreadyOwned"))
        self.assertEqual(eco.learn(t, s, "explorer_2"), (True, "ok"))
        self.assertEqual(eco.learn(t, s, "no_such_skill"), (False, "UnknownSkill"))
        self.assertEqual((s["ember"], s["banked"]["glowmoss"], s["banked"]["nightbloom"]), (200 - 15 - 40, 40 - 4 - 6, 4 - 2))

    def test_buy_affordable_takes_cheapest_first_and_repeats(self):
        # 15 Ember + 4 Glowmoss buys exactly one tier 1 skill. All four cost the same, so the
        # tie breaks on id, and capturer_1 sorts first.
        t, s = self.funded(glowmoss=4, ember=15)
        self.assertEqual(eco.buy_affordable(t, s), ["capturer_1"])
        # Rich enough for everything: all 8 skills plus the pack, tier 1 before tier 2.
        t, s = self.funded(fogbark=500, glowmoss=500, nightbloom=50, ember=1000)
        bought = eco.buy_affordable(t, s)
        self.assertEqual(len(bought), 9)
        self.assertEqual(set(bought), set(t["skills"]) | set(t["upgrades"]))
        for skill_id, spec in t["skills"].items():
            for required in spec["requires"]:
                self.assertLess(bought.index(required), bought.index(skill_id))


class ExtractionAndAfk(unittest.TestCase):
    def test_base_ember_conditions(self):
        t = tuning()
        paid = lambda secs, dist, units: eco.base_ember(t, secs, dist, units)
        self.assertEqual(paid(45.0, 60.0, 1), 4)
        self.assertEqual(paid(44.9, 60.0, 1), 0)
        self.assertEqual(paid(45.0, 59.9, 1), 0)
        self.assertEqual(paid(45.0, 60.0, 0), 0)

    def test_extraction_ember_exact_payout(self):
        t = tuning()
        both = [{"kind": "creature", "tier": "Territory"}, {"kind": "egg", "tier": "Territory"}]
        self.assertEqual(eco.extraction_ember(t, both, 60.0, 70.0, 5), 4 + 14 + 10)
        self.assertEqual(eco.extraction_ember(t, [{"kind": "creature", "tier": "Fog"}], 44.0, 70.0, 1), 8)
        self.assertEqual(eco.extraction_ember(t, [{"kind": "creature", "tier": "Safe"}], 90.0, 70.0, 1), 4 + 6)
        self.assertEqual(eco.extraction_ember(t, [], 90.0, 70.0, 3), 4)   # materials-only trip
        self.assertEqual(eco.extraction_ember(t, [], 90.0, 70.0, 0), 0)   # empty trip

    def test_idle_hour_changes_nothing(self):
        t = tuning()
        s = eco.new_state(t)
        s["banked"]["fogbark"], s["ember"], s["carried"]["glowmoss"] = 9, 5, 2
        before = copy.deepcopy(s)
        eco.advance_idle(t, s, 3600.0)
        self.assertEqual(s, before)

    def test_staying_home_earns_nothing(self):
        t, ctx = tuning(), context()
        run = eco.simulate_policy(t, ctx, "idle", idle_policy(), seed=1, trips=60)
        self.assertEqual(run.state, eco.new_state(t))
        self.assertTrue(all(trip["outcome"] == "empty" for trip in run.trips))
        self.assertEqual(sum(trip["ember_gained"] for trip in run.trips), 0)

    def test_antiafk_block_is_zero(self):
        a = tuning()["antiAfk"]
        self.assertEqual((a["timeBasedGrants"], a["idleHourExpectedDelta"]), (0, 0))


class Expeditions(unittest.TestCase):
    def mini(self, slots=("O1", "O2")):
        t = tuning()
        t["gather"]["slots"] = [s for s in t["gather"]["slots"] if s["id"] in slots]
        t["spawnWeights"]["outside"] = {p: {"fogbark": 100} for p in t["cycle"]["phaseOrder"]}
        t["yields"]["outside"] = {"fogbark": [3, 3]}
        return t

    def test_two_outside_nodes_hand_tour(self):
        # Camp (-140,140) -> O1 (-120,110): 36.056; O1 -> O2 (-70,40): 86.023; O2 -> camp: 122.066.
        # 244.145 studs at 16 studs/s = 15.259 s, plus two 1.0 s holds = 17.259 s (under 45 s: no base Ember).
        t, ctx = self.mini(), context()
        run = eco.simulate_policy(t, ctx, "mini", idle_policy(zones={"outside": 2, "fog": 0, "territory": 0}),
                                  seed=5, trips=1)
        trip = run.trips[0]
        walk = (math.dist((-140, 140), (-120, 110)) + math.dist((-120, 110), (-70, 40))
                + math.dist((-70, 40), (-140, 140)))
        self.assertAlmostEqual(trip["seconds"], walk / 16.0 + 2.0, places=6)
        self.assertEqual(run.state["banked"]["fogbark"], 6)    # 2 nodes x 3
        self.assertEqual(run.state["ember"], 0)
        self.assertEqual(trip["outcome"], "extracted")
        self.assertAlmostEqual(trip["max_distance"], math.dist((-140, 140), (-70, 40)), places=6)

    def test_safe_capture_hand_trip(self):
        # S0a (-95,75) is 79.06 studs from camp; out and back at 16 studs/s plus a 5.5 s capture
        # is 15.4 s: too short for the base 4, so only the Safe creature's 6 Ember pays.
        t, ctx = tuning(), context()
        policy = idle_policy(captureTier="Safe", captureRate=1.0)
        run = eco.simulate_policy(t, ctx, "safe", policy, seed=1, trips=1)
        d = math.dist((-140, 140), (-95, 75))
        self.assertAlmostEqual(run.trips[0]["seconds"], 2 * d / 16.0 + 5.5, places=6)
        self.assertEqual(run.state["ember"], 6)
        self.assertEqual(len(run.state["registered"]), 1)
        self.assertEqual(run.state["consumables"]["seal"], 1)   # first-extraction seal

    def test_first_extraction_seal_is_granted_once_and_capped(self):
        t, ctx = tuning(), context()
        policy = idle_policy(captureTier="Safe", captureRate=1.0)
        run = eco.simulate_policy(t, ctx, "safe", policy, seed=1, trips=3)
        self.assertEqual(run.state["consumables"]["seal"], 1)

    def test_runs_are_deterministic_and_seeds_differ(self):
        t, ctx = tuning(), context()
        policy = t["simulatorInputs"]["archetypes"]["balanced"]
        a = eco.simulate_policy(t, ctx, "balanced", policy, seed=11, trips=20)
        b = eco.simulate_policy(t, ctx, "balanced", policy, seed=11, trips=20)
        c = eco.simulate_policy(t, ctx, "balanced", policy, seed=12, trips=20)
        self.assertEqual(a.trips, b.trips)
        self.assertEqual(a.state, b.state)
        self.assertNotEqual(a.trips, c.trips)

    def test_capacity_is_never_exceeded_and_units_balance(self):
        t, ctx = tuning(), context()
        for name, policy in t["simulatorInputs"]["archetypes"].items():
            run = eco.simulate_policy(t, ctx, name, policy, seed=3, trips=40)
            for trip in run.trips:
                self.assertLessEqual(trip["units_carried"], trip["pouch_capacity"], name)
                self.assertLessEqual(trip["bag_items"], trip["bag_capacity"], name)
                self.assertEqual(trip["units_gathered"], trip["units_carried"] + trip["units_wasted"], name)

    def test_solo_supply_limits_nodes_without_waiting(self):
        # Only 2 outside nodes are active for one player, so a plan for 4 gathers 2 unless
        # a claimed node has respawned (75 s) by the time the player is ready for another.
        t = self.mini(slots=("O1", "O2", "O3", "O4"))
        t["gather"]["respawnSeconds"] = 10 ** 9
        ctx = context()
        run = eco.simulate_policy(t, ctx, "greedy-outside", idle_policy(zones={"outside": 4, "fog": 0, "territory": 0}),
                                  seed=2, trips=1)
        self.assertEqual(run.trips[0]["nodes_gathered"], 2)
        self.assertEqual(run.trips[0]["nodes_wanted"], 4)

    def test_defeat_applies_the_loss_rule_to_the_trip(self):
        t, ctx = self.mini(), context()
        policy = idle_policy(zones={"outside": 2, "fog": 0, "territory": 0}, defeatChance=1.0)
        run = eco.simulate_policy(t, ctx, "doomed", policy, seed=4, trips=1)
        # 6 fogbark in one stack: lost(6) = (6*1200+5000)//10000 = 1, so 5 stay carried.
        self.assertEqual(run.trips[0]["outcome"], "defeated")
        self.assertEqual(run.state["carried"]["fogbark"], 5)
        self.assertEqual(run.state["banked"]["fogbark"], 0)
        self.assertEqual(run.state["ember"], 0)


class Invariants(unittest.TestCase):
    def check(self, mutate):
        t = tuning()
        mutate(t)
        return eco.check_invariants(t, context())

    def test_real_tuning_passes(self):
        self.assertEqual(eco.check_invariants(tuning(), context()), [])

    def test_phases_must_sum_to_the_cycle(self):
        problems = self.check(lambda t: t["cycle"]["phases"].__setitem__("Day", 361))
        self.assertTrue(any("phases" in p for p in problems), problems)

    def test_night_only_material_in_a_day_table_is_caught(self):
        problems = self.check(lambda t: t["spawnWeights"]["fog"]["Day"].__setitem__("nightbloom", 5))
        self.assertTrue(any("nightbloom" in p for p in problems), problems)

    def test_empty_weight_table_is_caught(self):
        problems = self.check(lambda t: t["spawnWeights"]["outside"].__setitem__("Day", {"fogbark": 0}))
        self.assertTrue(problems)

    def test_slot_in_the_wrong_zone_is_caught(self):
        problems = self.check(lambda t: t["gather"]["slots"][0].__setitem__("zone", "territory"))
        self.assertTrue(any("O1" in p and "zone" in p for p in problems), problems)

    def test_slot_in_a_safe_circle_or_off_the_map_is_caught(self):
        problems = self.check(lambda t: t["gather"]["slots"][0].update(x=-140, z=140))
        self.assertTrue(any("O1" in p for p in problems), problems)
        problems = self.check(lambda t: t["gather"]["slots"][0].update(x=250))
        self.assertTrue(any("O1" in p and "map" in p for p in problems), problems)

    def test_tier2_without_a_tier1_prerequisite_is_caught(self):
        problems = self.check(lambda t: t["skills"]["explorer_2"].__setitem__("requires", []))
        self.assertTrue(any("explorer_2" in p for p in problems), problems)

    def test_seal_must_be_affordable_from_outside_and_fog(self):
        problems = self.check(lambda t: t["recipes"]["seal"]["cost"].__setitem__("nightbloom", 1))
        self.assertTrue(any("seal" in p for p in problems), problems)

    def test_standing_still_must_stay_below_calm_required(self):
        # Stationary maximum is about 3.6 s: a calmRequired of 3.5 would let standing still win.
        problems = self.check(lambda t: t["skills"]["capturer_1"]["effects"].__setitem__("calmRequired", 3.5))
        self.assertTrue(any("calm" in p.lower() for p in problems), problems)

    def test_reinforced_loss_must_match_the_loss_block(self):
        problems = self.check(lambda t: t["upgrades"]["reinforcedPack"]["effects"].__setitem__("lossBasisPoints", 700))
        self.assertTrue(any("loss" in p.lower() for p in problems), problems)

    def test_stationary_calm_hand_values(self):
        # Ring centre is 2 r sin(w t / 2) from a still player, w = speed / r. It leaves the
        # server radius R when sin(w t / 2) = R / (2 r): t = (2 r / speed) * asin(R / (2 r)).
        ring = context().ring
        for r in (4.0, 9.0):
            expected = (2 * r / ring["speed"]) * math.asin(ring["radius_server"] / (2 * r))
            self.assertAlmostEqual(eco.stationary_calm_seconds(ring, r), expected, places=9)
        # r=4: (2*4/1.5) * asin(5/8) = 5.3333 * 0.67513 = 3.6007 s, the document's "about 3.6".
        self.assertAlmostEqual(eco.stationary_calm_seconds(ring, 4.0), 3.6007, delta=0.001)
        self.assertAlmostEqual(eco.stationary_calm_max(ring), 3.6007, delta=0.001)
        self.assertEqual(ring["radius_server"], 5.0)


class StayOrReturn(unittest.TestCase):
    def test_expected_yield_hand_value(self):
        # Territory by day: 40% fogbark [4,5] avg 4.5, 60% glowmoss [2,3] avg 2.5 -> 1.8 + 1.5 = 3.3 units.
        self.assertAlmostEqual(eco.expected_units(tuning(), "territory", "Day"), 3.3, places=9)
        # Territory at night adds Nightbloom [1,2] avg 1.5 at 35%: .25*4.5 + .40*2.5 + .35*1.5 = 2.65.
        self.assertAlmostEqual(eco.expected_units(tuning(), "territory", "Night"), 2.65, places=9)

    def test_worst_loss_matches_a_brute_force_split(self):
        t, s = tuning(), eco.new_state(tuning())
        best = 0
        for a in range(31):
            for b in range(31 - a):
                best = max(best, eco.lost(a, 1200) + eco.lost(b, 1200) + eco.lost(30 - a - b, 1200))
        self.assertEqual(eco.max_material_loss(t, 30, 1200), best)
        self.assertGreaterEqual(best, eco.lost(30, 1200))

    def test_breakeven_hazard_uses_those_two_numbers(self):
        t = tuning()
        result = eco.stay_or_return(t)["territory"]
        loss = eco.max_material_loss(t, 30, 1200)
        self.assertAlmostEqual(result["breakeven_hazard"], result["expected_units_day"] / loss, places=9)
        # Even certain defeat on the next node loses less than one node pays in expectation
        # only if breakeven >= 1; the flag compares against the worst per-trip defeat chance.
        worst = max(a["defeatChance"] for a in t["simulatorInputs"]["archetypes"].values())
        self.assertEqual(result["materials_never_justify_returning"], result["breakeven_hazard"] > worst)


class PackAndSinks(unittest.TestCase):
    def test_pack_loss_comparison_hand_values(self):
        # Base pouch 30 at 12%: 3.6 expected units lost when full. Reinforced 45 at 8%: 3.6 as well,
        # so the lower rate is cancelled by the bigger pouch. Worst case with per-stack rounding is
        # 4 for the base and 5 for the reinforced pouch (checked against a brute force below).
        result = eco.pack_loss_comparison(tuning())
        self.assertAlmostEqual(result["base_expected"], 3.6, places=9)
        self.assertAlmostEqual(result["reinforced_expected"], 3.6, places=9)
        self.assertTrue(result["rate_cancelled_by_capacity"])
        self.assertEqual(result["base_worst"], eco.max_material_loss(tuning(), 30, 1200))
        self.assertEqual(result["reinforced_worst"], eco.max_material_loss(tuning(), 45, 800))

    def test_pack_that_really_helps_is_not_flagged(self):
        t = tuning()
        t["loss"]["rateBasisPointsReinforced"] = 500
        t["upgrades"]["reinforcedPack"]["effects"]["lossBasisPoints"] = 500
        result = eco.pack_loss_comparison(t)
        self.assertAlmostEqual(result["reinforced_expected"], 2.25, places=9)   # 45 * 5%
        self.assertFalse(result["rate_cancelled_by_capacity"])

    def test_materials_a_policy_never_earns_block_the_recipes_that_need_them(self):
        t, ctx = tuning(), context()
        summary = eco.analyse_policies(t, ctx, runs=10, trips=60, seed=77)
        self.assertEqual(summary["cautious"]["never_earned"], ["nightbloom"])
        self.assertEqual(summary["cautious"]["blocked_recipes"], ["capsule", "totem"])
        self.assertEqual(summary["balanced"]["never_earned"], [])
        self.assertEqual(summary["balanced"]["blocked_recipes"], [])

    def test_completion_is_when_everything_purchasable_is_owned(self):
        t, ctx = tuning(), context()
        summary = eco.analyse_policies(t, ctx, runs=10, trips=60, seed=77)
        self.assertEqual(summary["cautious"]["completion"]["reached_share"], 0.0)   # tier 2 needs Nightbloom
        self.assertIsNone(summary["cautious"]["completion"]["median_trip"])
        done = summary["balanced"]["completion"]
        self.assertEqual(done["reached_share"], 1.0)
        # Completion cannot come before the slowest single upgrade's own median first purchase.
        slowest = max(row["median_trip"] for row in summary["balanced"]["upgrades"].values())
        self.assertGreaterEqual(done["median_trip"], slowest)
        self.assertGreater(done["median_minutes"], 0)


class Analysis(unittest.TestCase):
    def test_policy_summary_and_flags(self):
        t, ctx = tuning(), context()
        summary = eco.analyse_policies(t, ctx, runs=12, trips=60, seed=2026)
        self.assertEqual(set(summary), set(t["simulatorInputs"]["archetypes"]))
        cautious = summary["cautious"]
        # Day-only, no territory: it never meets Nightbloom, so tier 2 skills (and the totem and
        # capsule recipes) are out of reach, exactly as the document says.
        self.assertIn("explorer_2", cautious["unreachable"])
        for key in ("ember_per_trip", "units_per_trip", "seconds_median", "defeat_rate",
                    "pouch_full_share", "bag_full_share", "upgrades"):
            self.assertIn(key, cautious)
        for upgrade, row in cautious["upgrades"].items():
            self.assertIn("reached_share", row)
            self.assertIn("median_trip", row)

    def test_summary_is_deterministic(self):
        t, ctx = tuning(), context()
        a = eco.analyse_policies(t, ctx, runs=6, trips=40, seed=5)
        b = eco.analyse_policies(t, ctx, runs=6, trips=40, seed=5)
        self.assertEqual(a, b)

    def test_trivial_and_unreachable_flags_follow_the_thresholds(self):
        row = {"reached_share": 1.0, "median_trip": 1}
        self.assertEqual(eco.classify_upgrade(row), "TRIVIAL")
        self.assertEqual(eco.classify_upgrade({"reached_share": 1.0, "median_trip": 2}), "ok")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.49, "median_trip": 50}), "UNREACHABLE")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.0, "median_trip": None}), "UNREACHABLE")
        self.assertEqual(eco.classify_upgrade({"reached_share": 0.5, "median_trip": 40}), "ok")


class Report(unittest.TestCase):
    def run_main(self, argv):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            code = eco.main(argv)
        return code, out.getvalue()

    def test_header_states_the_limits(self):
        code, text = self.run_main(["--runs", "6", "--trips", "30"])
        self.assertEqual(code, 0)
        head = text[:1500].lower()
        for phrase in ("math only", "fun or balance", "assumption"):
            self.assertIn(phrase, head)

    def test_report_covers_policies_upgrades_and_flags(self):
        _, text = self.run_main(["--runs", "6", "--trips", "30"])
        for name in ("cautious", "balanced", "greedy", "reinforcedPack", "explorer_1", "INVARIANTS", "stay-or-return"):
            self.assertIn(name, text)

    def test_report_is_deterministic(self):
        argv = ["--runs", "6", "--trips", "30", "--seed", "9"]
        self.assertEqual(self.run_main(argv), self.run_main(argv))

    def test_bad_arguments_are_rejected(self):
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                eco.main(["--runs", "0"])

    def test_broken_document_exits_nonzero(self):
        with contextlib.redirect_stderr(io.StringIO()):
            code = eco.main(["--doc", str(REPO / "README.md")])
        self.assertNotEqual(code, 0)


if __name__ == "__main__":
    unittest.main()
