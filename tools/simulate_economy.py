"""Wildbound P0 economy simulator.

Reads the fenced ```json economy-tuning block of docs/mechanics/wildbound-economy-p0.md
at run time (nothing in it is copied here), checks the document's own invariants,
then simulates expeditions for a few simple player policies and reports income per
expedition, time to every upgrade, and numbers that look unreachable, trivial or
that make a stay-or-return choice meaningless.

THIS MODELS MATH ONLY. It says nothing about fun or balance, and the policies are
the document's invented archetypes, not players.

SIMULATOR ASSUMPTIONS (not game data; every one is printed in the report):
  * solo play; straight-line walking at 16 studs/s between nodes, nearest first;
  * a capture takes 5.5 s, an egg pickup 0.25 s (capture document);
  * carrying eggs slows the walk home to 11, 10, 9 studs/s for 1, 2, 3+ eggs;
  * nodes: the active count for one player, then a claimed node respawns after the
    document's respawn time; the player never waits for a node;
  * a trip is entirely Day or entirely Night (nightShare is the chance it is Night);
  * the defeat roll happens once, after all loot is gathered (maximum exposure);
  * Safe-tier captures use the first Safe slot and only before any creature is
    registered (the first-capture rule); eggs use the first egg slot;
  * at camp the player buys, cheapest first, every upgrade and skill that is
    affordable. Consumables are not bought, so only their first-extraction grant
    appears, and no Ward Seal is used on defeat.

Usage (from the project root):

    python -I -B tools/simulate_economy.py [--runs N] [--trips N] [--seed N]
"""

import argparse
import copy
import json
import math
import random
import re
import statistics
import sys
from dataclasses import dataclass
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:  # `python -I` does not put the script folder on the path
    sys.path.insert(0, _HERE)

import simulate_silueta_pressure as world_rules  # noqa: E402  (single parser for zones)

REPO = Path(__file__).resolve().parent.parent
DOC = REPO / "docs/mechanics/wildbound-economy-p0.md"
CAPTURE_DOC = "docs/mechanics/wildbound-capture.md"
LAYOUT = "assets/maps/forest-layout/forest-layout-v1.json"

WALK_SPEED = 16.0
CAPTURE_SECONDS = 5.5
EGG_PICKUP_SECONDS = 0.25
EGG_CARRY_SPEED = {0: 16.0, 1: 11.0, 2: 10.0}   # 3 or more eggs: 9
EGG_CARRY_SPEED_MANY = 9.0
FENCE = re.compile(r"^```json economy-tuning[ \t]*\n(.*?)^```[ \t]*$", re.M | re.S)
ALL_ZONES = ("outside", "fog", "territory")
TRIVIAL_TRIP = 1
UNREACHABLE_BELOW = 0.5


class TuningError(Exception):
    """The economy tuning block is missing, malformed, or violates its schema."""


# ---- Reading the document ---------------------------------------------------
def extract_tuning(text):
    blocks = FENCE.findall(text)
    if len(blocks) != 1:
        raise TuningError(f"expected exactly one ```json economy-tuning block, found {len(blocks)}")
    try:
        tuning = json.loads(blocks[0])
    except json.JSONDecodeError as error:
        raise TuningError(f"economy-tuning block is not valid JSON: {error}") from error
    if tuning.get("schema") != "wildbound.economy.tuning":
        raise TuningError(f"unexpected schema {tuning.get('schema')!r}")
    if tuning.get("schemaVersion") != 1:
        raise TuningError(f"unsupported schemaVersion {tuning.get('schemaVersion')!r} (this tool reads 1)")
    if tuning.get("monetization") != "none":
        raise TuningError("monetization is not 'none'; this tool does not model paid items")
    return tuning


def load_tuning(path=DOC):
    try:
        text = Path(path).read_text(encoding="utf-8")
    except OSError as error:
        raise TuningError(f"cannot read {path}: {error}") from error
    return extract_tuning(text)


@dataclass
class Context:
    camp: tuple
    map_size: tuple
    world: object
    spots: dict
    eggs: list
    ring: dict
    loss_rows: list


def _capture_ring(text):
    def number(pattern, label):
        found = re.search(pattern, text)
        if not found:
            raise world_rules.ParseError(f"{CAPTURE_DOC}: {label} not found")
        return found

    ring = {
        "radius_server": float(number(r"`RING_RADIUS_SERVER`\s*\|\s*(\d+(?:\.\d+)?) studs", "RING_RADIUS_SERVER").group(1)),
        "speed": float(number(r"`RING_SPEED`\s*\|\s*(\d+(?:\.\d+)?) studs/s", "RING_SPEED").group(1)),
        "calm_required": float(number(r"`CALM_REQUIRED`\s*\|\s*(\d+(?:\.\d+)?) s", "CALM_REQUIRED").group(1)),
    }
    orbit = number(r"`ORBIT_MIN`, `ORBIT_MAX`\s*\|\s*(\d+(?:\.\d+)?), (\d+(?:\.\d+)?) studs", "ORBIT_MIN/ORBIT_MAX")
    ring["orbit_min"], ring["orbit_max"] = float(orbit.group(1)), float(orbit.group(2))
    return ring


def load_context(repo=REPO, doc_text=None):
    repo = Path(repo)
    world = world_rules.load_world(repo)
    capture_text = (repo / CAPTURE_DOC).read_text(encoding="utf-8")
    layout = json.loads((repo / LAYOUT).read_text(encoding="utf-8"))
    spots = world_rules.parse_capture(capture_text)
    tiers = dict(re.findall(r"^\|\s*`(\w+)`\s*\|.*\|\s*(Safe|Fog|Territory)[^|]*\|\s*$", capture_text, re.M))
    by_tier = {"Safe": [], "Fog": [], "Territory": []}
    eggs = []
    for spot in spots:
        if spot.slot in tiers:
            by_tier[tiers[spot.slot]].append((spot.x, spot.z))
        elif spot.slot.startswith("E"):
            eggs.append((spot.x, spot.z))
    if not all(by_tier.values()) or not eggs:
        raise world_rules.ParseError(f"{CAPTURE_DOC}: need Safe, Fog and Territory spots and at least one egg slot")
    by_tier["Safe"] = by_tier["Safe"][:1]      # solo play: first Safe slot only
    eggs = eggs[:1]                            # solo play: first egg slot only
    if doc_text is None:
        doc_text = (repo / "docs/mechanics/wildbound-economy-p0.md").read_text(encoding="utf-8")
    rows = [(int(a), int(b), int(c)) for a, b, c in re.findall(r"^\| (\d+) \| (\d+) \| (\d+) \|$", doc_text, re.M)]
    camp = tuple(float(v) for v in layout["inputs"]["route_nodes"]["camp"])
    return Context(camp, tuple(layout["inputs"]["map_size"]), world, by_tier, eggs, _capture_ring(capture_text), rows)


# ---- Loss rule, weights, yields ---------------------------------------------
def lost(quantity, basis_points):
    """Nearest unit, halves up, integer arithmetic only."""
    return (quantity * basis_points + 5000) // 10000


def normalize(weights):
    if not weights:
        raise TuningError("empty weight table")
    total = 0.0
    for key, value in weights.items():
        if not isinstance(value, (int, float)) or isinstance(value, bool) or value != value or value < 0 or value == math.inf:
            raise TuningError(f"invalid weight {key}={value!r}")
        total += value
    if total <= 0:
        raise TuningError("weights sum to zero")
    return {key: value / total for key, value in weights.items()}


def spawn_probabilities(tuning, zone, phase):
    try:
        table = tuning["spawnWeights"][zone][phase]
    except KeyError as error:
        raise TuningError(f"no spawn table for {zone}/{phase}") from error
    return normalize(table)


def draw_material(tuning, zone, phase, rng):
    probabilities = spawn_probabilities(tuning, zone, phase)
    roll, acc, last = rng.random(), 0.0, None
    for material in sorted(probabilities):
        if probabilities[material] <= 0:
            continue
        acc += probabilities[material]
        last = material
        if roll < acc:
            return material
    return last


def draw_yield(tuning, zone, material, rng):
    low, high = tuning["yields"][zone][material]
    return rng.randint(low, high)


def expected_units(tuning, zone, phase):
    total = 0.0
    for material, p in spawn_probabilities(tuning, zone, phase).items():
        low, high = tuning["yields"][zone][material]
        total += p * (low + high) / 2.0
    return total


# ---- State ------------------------------------------------------------------
def new_state(tuning):
    materials = {m: 0 for m in tuning["materials"]}
    return {
        "carried": dict(materials), "banked": dict(materials), "ember": 0, "bag": [],
        "registered": [], "bankedEggs": [],
        "consumables": {name: 0 for name in tuning["capacity"]["consumableCaps"]},
        "upgrades": {name: False for name in tuning["upgrades"]},
        "skills": {}, "bond": {}, "firstExtractionDone": False, "appliedOps": [],
    }


def _owned_effects(tuning, state, key):
    values = [spec["effects"][key] for name, spec in tuning["upgrades"].items()
              if state["upgrades"].get(name) and key in spec["effects"]]
    return values


def pouch_capacity(tuning, state):
    values = _owned_effects(tuning, state, "pouchUnits")
    return max(values) if values else tuning["capacity"]["pouchUnits"]


def bag_capacity(tuning, state):
    values = _owned_effects(tuning, state, "bagItems")
    return max(values) if values else tuning["capacity"]["bagItems"]


def loss_basis_points(tuning, state):
    values = _owned_effects(tuning, state, "lossBasisPoints")
    return min(values) if values else tuning["loss"]["rateBasisPoints"]


def apply_defeat(tuning, state, operation_id=None, use_seal=False):
    """One defeat. Bag items go unless a seal saves the newest; each carried stack loses `lost()`."""
    if operation_id is not None and operation_id in state["appliedOps"]:
        return {"duplicate": True, "lost_items": 0, "lost_units": {}, "kept_items": len(state["bag"])}
    bag = state["bag"]
    kept = []
    if use_seal and state["consumables"].get("seal", 0) > 0 and bag:
        kept = [bag[-1]]
        state["consumables"]["seal"] -= 1
    lost_items = len(bag) - len(kept)
    state["bag"] = kept
    basis = loss_basis_points(tuning, state)
    lost_units = {}
    for material, quantity in state["carried"].items():
        loss = lost(quantity, basis)
        state["carried"][material] = quantity - loss
        lost_units[material] = loss
    if operation_id is not None:
        state["appliedOps"].append(operation_id)
    return {"duplicate": False, "lost_items": lost_items, "lost_units": lost_units, "kept_items": len(kept)}


def max_material_loss(tuning, capacity, basis_points):
    """Largest total a defeat can take from `capacity` units split across the material stacks."""
    stacks = len(tuning["materials"])
    best = [0] * (capacity + 1)                      # best[u]: max loss using up to u units, k stacks
    for _ in range(stacks):
        best = [max(lost(x, basis_points) + best[u - x] for x in range(u + 1)) for u in range(capacity + 1)]
    return best[capacity]


# ---- Sinks ------------------------------------------------------------------
def _can_pay(state, cost):
    for key, amount in cost.items():
        have = state["ember"] if key == "ember" else state["banked"][key]
        if have < amount:
            return False
    return True


def _pay(state, cost):
    for key, amount in cost.items():
        if key == "ember":
            state["ember"] -= amount
        else:
            state["banked"][key] -= amount


def craft(tuning, state, recipe):
    if recipe not in tuning["recipes"]:
        return False, "UnknownRecipe"
    if state["consumables"][recipe] >= tuning["capacity"]["consumableCaps"][recipe]:
        return False, "AtLimit"
    cost = tuning["recipes"][recipe]["cost"]
    if not _can_pay(state, cost):
        return False, "CannotAfford"
    _pay(state, cost)
    state["consumables"][recipe] += 1
    return True, "ok"


def upgrade(tuning, state, name):
    if name not in tuning["upgrades"]:
        return False, "UnknownUpgrade"
    if state["upgrades"][name]:
        return False, "AlreadyOwned"
    cost = tuning["upgrades"][name]["cost"]
    if not _can_pay(state, cost):
        return False, "CannotAfford"
    _pay(state, cost)
    state["upgrades"][name] = True
    return True, "ok"


def learn(tuning, state, skill):
    if skill not in tuning["skills"]:
        return False, "UnknownSkill"
    if state["skills"].get(skill):
        return False, "AlreadyOwned"
    spec = tuning["skills"][skill]
    if any(not state["skills"].get(required) for required in spec["requires"]):
        return False, "NeedsPrerequisite"
    if not _can_pay(state, spec["cost"]):
        return False, "CannotAfford"
    _pay(state, spec["cost"])
    state["skills"][skill] = True
    return True, "ok"


def buy_affordable(tuning, state):
    """Repeatedly buy the cheapest affordable upgrade or skill (ties by id). Returns ids in order."""
    bought = []
    while True:
        options = []
        for name, spec in tuning["upgrades"].items():
            if not state["upgrades"][name] and _can_pay(state, spec["cost"]):
                options.append((sum(spec["cost"].values()), name, "upgrade"))
        for name, spec in tuning["skills"].items():
            if (not state["skills"].get(name) and all(state["skills"].get(r) for r in spec["requires"])
                    and _can_pay(state, spec["cost"])):
                options.append((sum(spec["cost"].values()), name, "skill"))
        if not options:
            return bought
        _, name, kind = min(options)
        (upgrade if kind == "upgrade" else learn)(tuning, state, name)
        bought.append(name)


# ---- Earning ----------------------------------------------------------------
def base_ember(tuning, seconds, distance, new_units):
    need = tuning["earn"]["baseRequires"]
    if (seconds >= need["minExpeditionSeconds"] and distance >= need["minDistanceFromCamp"]
            and new_units >= need["minNewUnitsOrItems"]):
        return tuning["earn"]["extractBaseEmber"]
    return 0


def extraction_ember(tuning, bag, seconds, distance, units_carried):
    total = base_ember(tuning, seconds, distance, units_carried + len(bag))
    for item in bag:
        table = tuning["earn"]["creatureEmberByTier" if item["kind"] == "creature" else "eggEmberByTier"]
        total += table.get(item["tier"], 0)
    return total


def advance_idle(tuning, state, seconds):
    """Time passing with no player action. Nothing in the economy grows from time alone."""
    if seconds < 0:
        raise ValueError("seconds must not be negative")
    return state


# ---- Expeditions ------------------------------------------------------------
def _egg_speed(eggs):
    return EGG_CARRY_SPEED.get(eggs, EGG_CARRY_SPEED_MANY)


def _active_counts(tuning, players):
    rows = [row for row in tuning["gather"]["activeByPlayers"] if row["minPlayers"] <= players]
    return max(rows, key=lambda row: row["minPlayers"])


def run_expedition(tuning, ctx, state, policy, rng, players=1):
    pouch, bag_cap = pouch_capacity(tuning, state), bag_capacity(tuning, state)
    hold, respawn = tuning["gather"]["holdSeconds"], tuning["gather"]["respawnSeconds"]
    camp = ctx.camp
    phase = "Night" if rng.random() < policy["nightShare"] else "Day"
    slots_by_zone = {z: sorted((s for s in tuning["gather"]["slots"] if s["zone"] == z), key=lambda s: s["id"])
                     for z in ALL_ZONES}
    active_row = _active_counts(tuning, players)
    active = {z: {s["id"] for s in rng.sample(slots_by_zone[z], min(active_row[z], len(slots_by_zone[z])))}
              for z in ALL_ZONES}
    by_id = {s["id"]: s for z in ALL_ZONES for s in slots_by_zone[z]}
    wanted = {z: policy["zones"].get(z, 0) for z in ALL_ZONES}
    gathered = {z: 0 for z in ALL_ZONES}
    claims = {z: [] for z in ALL_ZONES}          # [claim time, respawned]
    visited = set()
    position, clock, max_distance = camp, 0.0, 0.0
    units_gathered = units_wasted = 0
    pouch_full = False

    def walk(to, speed=WALK_SPEED):
        nonlocal position, clock, max_distance
        clock += math.dist(position, to) / speed
        position = to
        max_distance = max(max_distance, math.dist(camp, to))

    while True:
        for z in ALL_ZONES:
            for claim in claims[z]:
                if not claim[1] and clock >= claim[0] + respawn:
                    free = [s["id"] for s in slots_by_zone[z] if s["id"] not in active[z] and s["id"] not in visited]
                    if free:
                        active[z].add(rng.choice(free))
                    claim[1] = True
        if sum(state["carried"].values()) >= pouch:
            pouch_full = True
            break
        candidates = [by_id[i] for z in ALL_ZONES if gathered[z] < wanted[z] for i in sorted(active[z])
                      if i not in visited]
        if not candidates:
            break
        node = min(candidates, key=lambda s: (math.dist(position, (s["x"], s["z"])), s["id"]))
        walk((node["x"], node["z"]))
        clock += hold
        material = draw_material(tuning, node["zone"], phase, rng)
        units = draw_yield(tuning, node["zone"], material, rng)
        space = pouch - sum(state["carried"].values())
        taken = min(units, space)
        state["carried"][material] += taken
        units_gathered += units
        units_wasted += units - taken
        visited.add(node["id"])
        active[node["zone"]].discard(node["id"])
        gathered[node["zone"]] += 1
        claims[node["zone"]].append([clock, False])

    captured = egg_taken = False
    tier = policy.get("captureTier")
    if tier is not None:
        first_capture_ok = tier != "Safe" or not (state["registered"] or any(i["kind"] == "creature" for i in state["bag"]))
        if first_capture_ok and ctx.spots.get(tier):
            spot = min(ctx.spots[tier], key=lambda s: math.dist(position, s))
            walk(spot)
            clock += CAPTURE_SECONDS
            if rng.random() < policy["captureRate"] and len(state["bag"]) < bag_cap:
                state["bag"].append({"kind": "creature", "tier": tier})
                captured = True
    if policy["eggRate"] > 0 and rng.random() < policy["eggRate"] and ctx.eggs:
        spot = min(ctx.eggs, key=lambda s: math.dist(position, s))
        walk(spot)
        clock += EGG_PICKUP_SECONDS
        if len(state["bag"]) < bag_cap:
            state["bag"].append({"kind": "egg", "tier": "Territory"})
            egg_taken = True

    new_units = units_gathered - units_wasted
    trip = {
        "phase": phase, "seconds": clock, "max_distance": max_distance, "ember_gained": 0,
        "units_gathered": units_gathered, "units_wasted": units_wasted, "units_carried": new_units,
        "pouch_capacity": pouch, "bag_capacity": bag_cap, "bag_items": len(state["bag"]),
        "nodes_gathered": sum(gathered.values()), "nodes_wanted": sum(wanted.values()),
        "pouch_full": pouch_full or sum(state["carried"].values()) >= pouch,
        "bag_full": len(state["bag"]) >= bag_cap, "captured": captured, "egg": egg_taken,
        "outcome": "empty", "banked_units": 0,
    }
    if not state["bag"] and sum(state["carried"].values()) == 0:
        return trip
    if rng.random() < policy["defeatChance"]:
        apply_defeat(tuning, state)
        trip["outcome"] = "defeated"
        return trip
    eggs = sum(1 for i in state["bag"] if i["kind"] == "egg")
    walk(camp, _egg_speed(eggs))
    trip["seconds"] = clock
    ember = extraction_ember(tuning, state["bag"], clock, max_distance, new_units)
    state["ember"] += ember
    trip["ember_gained"] = ember
    trip["banked_units"] = sum(state["carried"].values())
    for material, quantity in state["carried"].items():
        state["banked"][material] += quantity
        state["carried"][material] = 0
    for item in state["bag"]:
        (state["registered"] if item["kind"] == "creature" else state["bankedEggs"]).append(item)
    state["bag"] = []
    if not state["firstExtractionDone"]:
        state["firstExtractionDone"] = True
        cap = tuning["capacity"]["consumableCaps"]["seal"]
        state["consumables"]["seal"] = min(cap, state["consumables"]["seal"] + tuning["earn"]["firstExtractionSeal"])
    trip["outcome"] = "extracted"
    return trip


@dataclass
class Run:
    name: str
    trips: list
    state: dict
    purchases: list      # (trip number, cumulative minutes, id)
    standalone: dict     # id -> first trip whose lifetime income alone covers its cost
    lifetime: dict       # gross materials banked and Ember paid over the whole run


def _cost_of(tuning, name):
    if name in tuning["upgrades"]:
        return tuning["upgrades"][name]["cost"]
    return tuning["skills"][name]["cost"]


def simulate_policy(tuning, ctx, name, policy, seed, trips, players=1):
    rng = random.Random(seed)
    state = new_state(tuning)
    log, purchases = [], []
    lifetime = {key: 0 for key in list(tuning["materials"]) + ["ember"]}
    standalone = {key: None for key in list(tuning["upgrades"]) + list(tuning["skills"])}
    minutes = 0.0
    for number in range(1, trips + 1):
        banked_before = dict(state["banked"])
        ember_before = state["ember"]
        trip = run_expedition(tuning, ctx, state, policy, rng, players)
        log.append(trip)
        minutes += trip["seconds"] / 60.0
        for material in tuning["materials"]:
            lifetime[material] += state["banked"][material] - banked_before[material]
        lifetime["ember"] += state["ember"] - ember_before
        for item in standalone:
            if standalone[item] is None and all(lifetime[k] >= v for k, v in _cost_of(tuning, item).items()):
                standalone[item] = number
        for item in buy_affordable(tuning, state):
            purchases.append((number, minutes, item))
    return Run(name, log, state, purchases, standalone, lifetime)


# ---- Invariants -------------------------------------------------------------
def stationary_calm_seconds(ring, orbit):
    """Seconds a never-moving player stays inside the ring (ring centre leaves radius R)."""
    return (2 * orbit / ring["speed"]) * math.asin(min(1.0, ring["radius_server"] / (2 * orbit)))


def stationary_calm_max(ring, samples=1000):
    low, high = ring["orbit_min"], ring["orbit_max"]
    return max(stationary_calm_seconds(ring, low + (high - low) * i / samples) for i in range(samples + 1))


def check_invariants(tuning, ctx):
    problems = []
    cycle = tuning["cycle"]
    if sum(cycle["phases"].values()) != cycle["seconds"]:
        problems.append(f"cycle phases sum to {sum(cycle['phases'].values())}, not cycle.seconds {cycle['seconds']}")
    if set(cycle["phaseOrder"]) != set(cycle["phases"]):
        problems.append("cycle phaseOrder and phases name different phases")
    night_only = {m for m, spec in tuning["materials"].items() if spec["nightOnly"]}
    for zone, phases in tuning["spawnWeights"].items():
        for phase in cycle["phaseOrder"]:
            table = phases.get(phase)
            if table is None:
                problems.append(f"spawn table {zone}/{phase} missing")
                continue
            try:
                normalize(table)
            except TuningError as error:
                problems.append(f"spawn table {zone}/{phase}: {error}")
                continue
            for material, weight in table.items():
                if material not in tuning["materials"]:
                    problems.append(f"spawn table {zone}/{phase} lists unknown material {material}")
                elif weight > 0 and material in night_only and phase != "Night":
                    problems.append(f"night-only {material} has weight {weight} in the {zone}/{phase} table")
                elif weight > 0 and material not in tuning["yields"].get(zone, {}):
                    problems.append(f"{material} can spawn in {zone}/{phase} but has no yield")
    width, height = ctx.map_size
    for slot in tuning["gather"]["slots"]:
        actual = world_rules.zone_of(ctx.world, slot["x"], slot["z"])
        if actual == "safe":
            problems.append(f"slot {slot['id']} sits inside a safe circle")
        if actual != slot["zone"]:
            problems.append(f"slot {slot['id']}: declared zone {slot['zone']} but the world rules say {actual}")
        if abs(slot["x"]) > width / 2 or abs(slot["z"]) > height / 2:
            problems.append(f"slot {slot['id']} is outside the {width:g} x {height:g} map")
    for name, spec in tuning["skills"].items():
        if spec["tier"] >= 2:
            ok = bool(spec["requires"]) and all(
                tuning["skills"].get(r, {}).get("tier") == spec["tier"] - 1
                and tuning["skills"][r]["branch"] == spec["branch"] for r in spec["requires"])
            if not ok:
                problems.append(f"skill {name}: tier {spec['tier']} lacks a tier {spec['tier'] - 1} prerequisite in its branch")
    cheap_zones = [z for z in ("outside", "fog")]
    for material in tuning["recipes"]["seal"]["cost"]:
        if material == "ember":
            problems.append("recipe seal costs Ember; a seal must be affordable from materials")
            continue
        obtainable = tuning["materials"].get(material) and not tuning["materials"][material]["nightOnly"] and any(
            tuning["spawnWeights"][z].get("Day", {}).get(material, 0) > 0 for z in cheap_zones)
        if not obtainable:
            problems.append(f"recipe seal needs {material}, which outside and fog do not supply by day")
    ceiling = stationary_calm_max(ctx.ring)
    calms = [("base CALM_REQUIRED", ctx.ring["calm_required"])] + [
        (f"skill {n}", s["effects"]["calmRequired"]) for n, s in tuning["skills"].items() if "calmRequired" in s["effects"]]
    for label, value in calms:
        if value <= ceiling:
            problems.append(f"{label}: calmRequired {value:g} s <= stationary maximum {ceiling:.2f} s, so standing still would fill the meter")
    if tuning["loss"]["rounding"] != "nearest_half_up_per_stack":
        problems.append(f"loss rounding is {tuning['loss']['rounding']!r}; this tool implements nearest_half_up_per_stack")
    for name, spec in tuning["upgrades"].items():
        if "lossBasisPoints" in spec["effects"] and spec["effects"]["lossBasisPoints"] != tuning["loss"]["rateBasisPointsReinforced"]:
            problems.append(f"upgrade {name}: loss {spec['effects']['lossBasisPoints']} bp differs from loss.rateBasisPointsReinforced")
    if not ctx.loss_rows:
        problems.append("no loss rounding table rows found in the document")
    for quantity, at_normal, at_reinforced in ctx.loss_rows:
        if lost(quantity, tuning["loss"]["rateBasisPoints"]) != at_normal:
            problems.append(f"document loss table: {quantity} -> {at_normal} but the JSON rate gives {lost(quantity, tuning['loss']['rateBasisPoints'])}")
        if lost(quantity, tuning["loss"]["rateBasisPointsReinforced"]) != at_reinforced:
            problems.append(f"document loss table: {quantity} -> {at_reinforced} (reinforced) but the JSON rate gives {lost(quantity, tuning['loss']['rateBasisPointsReinforced'])}")
    if tuning["antiAfk"]["timeBasedGrants"] != 0 or tuning["antiAfk"]["idleHourExpectedDelta"] != 0:
        problems.append("antiAfk block allows time-based grants")
    return problems


# ---- Analysis ---------------------------------------------------------------
def stay_or_return(tuning):
    """Per zone: expected units one more node pays vs the most a defeat can take from a full pouch."""
    worst_trip = max(a["defeatChance"] for a in tuning["simulatorInputs"]["archetypes"].values())
    loss = max_material_loss(tuning, tuning["capacity"]["pouchUnits"], tuning["loss"]["rateBasisPoints"])
    reinforced_loss = max_material_loss(tuning, tuning["upgrades"]["reinforcedPack"]["effects"]["pouchUnits"],
                                        tuning["loss"]["rateBasisPointsReinforced"])
    out = {}
    for zone in ALL_ZONES:
        day, night = expected_units(tuning, zone, "Day"), expected_units(tuning, zone, "Night")
        breakeven = day / loss
        out[zone] = {
            "expected_units_day": day, "expected_units_night": night,
            "max_loss_full_pouch": loss, "max_loss_full_reinforced_pouch": reinforced_loss,
            "breakeven_hazard": breakeven, "worst_trip_defeat_chance": worst_trip,
            "materials_never_justify_returning": breakeven > worst_trip,
        }
    return out


def pack_loss_comparison(tuning):
    """Expected units lost on defeat with a full pouch, base against Reinforced Pack."""
    pack = tuning["upgrades"]["reinforcedPack"]["effects"]
    base_cap, base_bp = tuning["capacity"]["pouchUnits"], tuning["loss"]["rateBasisPoints"]
    pack_cap, pack_bp = pack["pouchUnits"], tuning["loss"]["rateBasisPointsReinforced"]
    base_expected, pack_expected = base_cap * base_bp / 10000.0, pack_cap * pack_bp / 10000.0
    return {
        "base_capacity": base_cap, "base_expected": base_expected,
        "base_worst": max_material_loss(tuning, base_cap, base_bp),
        "reinforced_capacity": pack_cap, "reinforced_expected": pack_expected,
        "reinforced_worst": max_material_loss(tuning, pack_cap, pack_bp),
        "rate_cancelled_by_capacity": pack_expected >= base_expected - 1e-9,
    }


def classify_upgrade(row):
    if row["reached_share"] < UNREACHABLE_BELOW:
        return "UNREACHABLE"
    if row["median_trip"] is not None and row["median_trip"] <= TRIVIAL_TRIP:
        return "TRIVIAL"
    return "ok"


def _median(values):
    return statistics.median(values) if values else None


def analyse_policies(tuning, ctx, runs, trips, seed, players=1):
    names = list(tuning["upgrades"]) + list(tuning["skills"])
    summary = {}
    for name, policy in tuning["simulatorInputs"]["archetypes"].items():
        sims = [simulate_policy(tuning, ctx, name, policy, seed * 1000 + i, trips, players) for i in range(runs)]
        all_trips = [t for r in sims for t in r.trips]
        real = [t for t in all_trips if t["outcome"] != "empty"]
        upgrades = {}
        for item in names:
            first = [next((n for n, _, i in r.purchases if i == item), None) for r in sims]
            minutes = [next((m for _, m, i in r.purchases if i == item), None) for r in sims]
            alone = [r.standalone[item] for r in sims]
            reached = [f for f in first if f is not None]
            row = {
                "reached_share": len(reached) / len(sims),
                "median_trip": _median(reached),
                "median_minutes": _median([m for m in minutes if m is not None]),
                "standalone_share": sum(a is not None for a in alone) / len(sims),
                "standalone_median_trip": _median([a for a in alone if a is not None]),
            }
            row["class"] = classify_upgrade(row)
            upgrades[item] = row
        n = float(len(all_trips))
        finished = []
        for r in sims:
            firsts = [next(((t, m) for t, m, i in r.purchases if i == item), None) for item in names]
            if all(f is not None for f in firsts):
                finished.append((max(f[0] for f in firsts), max(f[1] for f in firsts)))
        never = sorted(m for m in tuning["materials"] if sum(r.lifetime[m] for r in sims) == 0)
        blocked = sorted(rec for rec, spec in tuning["recipes"].items() if any(m in spec["cost"] for m in never))
        summary[name] = {
            "completion": {"reached_share": len(finished) / len(sims),
                           "median_trip": _median([f[0] for f in finished]),
                           "median_minutes": _median([f[1] for f in finished])},
            "never_earned": never, "blocked_recipes": blocked,
            "ember_per_trip": sum(t["ember_gained"] for t in all_trips) / n,
            "units_per_trip": sum(t["banked_units"] for t in all_trips) / n,
            "seconds_median": _median([t["seconds"] for t in real]),
            "defeat_rate": sum(t["outcome"] == "defeated" for t in all_trips) / n,
            "pouch_full_share": sum(t["pouch_full"] for t in all_trips) / n,
            "bag_full_share": sum(t["bag_full"] for t in all_trips) / n,
            "bag_max": max(t["bag_items"] for t in all_trips),
            "nodes_wanted": sum(t["nodes_wanted"] for t in all_trips) / n,
            "nodes_gathered": sum(t["nodes_gathered"] for t in all_trips) / n,
            "wasted_per_trip": sum(t["units_wasted"] for t in all_trips) / n,
            "upgrades": upgrades,
            "unreachable": [i for i, row in upgrades.items() if row["class"] == "UNREACHABLE"],
            "trivial": [i for i, row in upgrades.items() if row["class"] == "TRIVIAL"],
        }
    return summary


# ---- Report -----------------------------------------------------------------
HEADER = """\
WILDBOUND P0 ECONOMY SIMULATOR - math only
This models math only. It says nothing about fun or balance, and the policies are the
document's invented archetypes, not players. Numbers come from the economy-tuning block of
{doc} at run time; the assumptions below are the simulator's, not game data."""


def _fmt(value, spec="6.1f"):
    return "     -" if value is None else format(value, spec)


def render(tuning, ctx, problems, summary, runs, trips, seed):
    lines = [HEADER.format(doc="docs/mechanics/wildbound-economy-p0.md"), "",
             "Assumptions: solo play; walk 16 studs/s straight lines, nearest node first, no detours; "
             f"capture {CAPTURE_SECONDS:g} s, egg pickup {EGG_PICKUP_SECONDS:g} s; eggs slow the walk home to 11/10/9 studs/s; "
             "gather nodes: active count for 1 player, claimed nodes respawn after the document's respawn time, no waiting; "
             "a trip is all Day or all Night; defeat is rolled once after all loot is gathered; "
             "Safe captures use the first Safe slot and only before a creature is registered; eggs use the first egg slot; "
             "at camp the player buys every affordable upgrade or skill, cheapest first; no consumables are bought.",
             f"Run: {runs} seeded runs x {trips} expeditions per policy, base seed {seed}.", ""]
    lines.append(f"INVARIANTS: {'all hold' if not problems else str(len(problems)) + ' BROKEN'}")
    lines += [f"  - {p}" for p in problems]
    target = tuning["cycle"]["targetExpeditionSeconds"]
    lines += ["", f"1. Income per expedition (all expeditions, defeats count as zero; target length {target[0]} to {target[1]} s)",
              f"{'policy':<10}{'Ember':>8}{'units':>8}{'median s':>10}{'defeat':>8}{'nodes got/want':>16}{'wasted':>8}{'pouch full':>11}{'bag full':>9}{'length':>9}"]
    for name, s in summary.items():
        median = s["seconds_median"]
        length = "n/a" if median is None else ("BELOW" if median < target[0] else "ABOVE" if median > target[1] else "in")
        lines.append(f"{name:<10}{s['ember_per_trip']:8.1f}{s['units_per_trip']:8.1f}{_fmt(median, '10.0f'):>10}"
                     f"{100 * s['defeat_rate']:7.0f}%{s['nodes_gathered']:8.1f}/{s['nodes_wanted']:<7.1f}"
                     f"{s['wasted_per_trip']:8.1f}{100 * s['pouch_full_share']:10.0f}%{100 * s['bag_full_share']:8.0f}%{length:>9}")
    lines += ["", "2. Time to each upgrade (expedition number of the first purchase, median over runs that got there;"
                  " 'alone' = first expedition whose lifetime income alone covers the cost)"]
    for name, s in summary.items():
        lines += ["", f"  policy {name}", f"  {'upgrade':<17}{'reached':>8}{'trip':>7}{'minutes':>9}{'alone':>7}  flag"]
        for item, row in s["upgrades"].items():
            lines.append(f"  {item:<17}{100 * row['reached_share']:7.0f}%{_fmt(row['median_trip'], '7.1f')}"
                         f"{_fmt(row['median_minutes'], '9.1f')}{_fmt(row['standalone_median_trip'], '7.1f')}  "
                         f"{row['class'] if row['class'] != 'ok' else ''}")
    lines += ["", "3. stay-or-return: can the numbers make staying out one more node a real choice?",
              "   Expected units one more node pays vs the most a defeat can take from a full pouch (per-stack rounding)."]
    for zone, r in stay_or_return(tuning).items():
        verdict = ("MEANINGLESS for materials: even a defeat chance of " f"{100 * r['breakeven_hazard']:.0f}% per node would not make leaving better"
                   if r["materials_never_justify_returning"] else "a real tradeoff for materials")
        lines.append(f"   {zone:<10} node pays {r['expected_units_day']:.2f} units by day ({r['expected_units_night']:.2f} at night); "
                     f"full pouch loses at most {r['max_loss_full_pouch']} (reinforced: {r['max_loss_full_reinforced_pouch']}); "
                     f"break-even hazard {r['breakeven_hazard']:.2f} vs worst whole-trip defeat chance "
                     f"{r['worst_trip_defeat_chance']:.2f}: {verdict}")
    pack = pack_loss_comparison(tuning)
    lines += ["", "4. Reinforced Pack against the loss rule",
              f"   Full pouch, expected units lost on defeat: base {pack['base_capacity']} x "
              f"{tuning['loss']['rateBasisPoints'] / 100:g}% = {pack['base_expected']:.2f}; reinforced {pack['reinforced_capacity']} x "
              f"{tuning['loss']['rateBasisPointsReinforced'] / 100:g}% = {pack['reinforced_expected']:.2f}. "
              f"Worst case with per-stack rounding: {pack['base_worst']} against {pack['reinforced_worst']}."]
    lines += ["", "5. Flags"]
    flags = []
    for name, s in summary.items():
        if s["unreachable"]:
            flags.append(f"{name}: UNREACHABLE within {trips} expeditions: {', '.join(s['unreachable'])}")
        if s["blocked_recipes"]:
            flags.append(f"{name}: never earns {', '.join(s['never_earned'])}, so the recipes {', '.join(s['blocked_recipes'])} are out of reach")
        done = s["completion"]
        if done["median_trip"] is not None:
            flags.append(f"{name}: everything purchasable is owned by expedition {done['median_trip']:.0f} "
                         f"(about {done['median_minutes']:.0f} min of expeditions); after that income has no sink except consumables")
        if s["trivial"]:
            flags.append(f"{name}: TRIVIAL (bought after the first expedition): {', '.join(s['trivial'])}")
        capacity = tuning["capacity"]["bagItems"]
        if s["bag_full_share"] == 0:
            flags.append(f"{name}: bag never fills (most items held {s['bag_max']} of {capacity}), so the bag limit never forces a stay-or-return choice"
                         f" and the Reinforced Pack's extra bag slot is worth nothing for this policy")
        if s["pouch_full_share"] == 0:
            flags.append(f"{name}: pouch never fills, so the pouch limit never forces a return")
        elif s["pouch_full_share"] >= 0.5:
            flags.append(f"{name}: pouch is full on {100 * s['pouch_full_share']:.0f}% of expeditions, wasting {s['wasted_per_trip']:.1f} units per expedition")
        if s["nodes_gathered"] + 1e-9 < s["nodes_wanted"]:
            flags.append(f"{name}: plans {s['nodes_wanted']:.1f} nodes per expedition but supply allows {s['nodes_gathered']:.1f} for one player")
        median = s["seconds_median"]
        if median is not None and median < target[0]:
            flags.append(f"{name}: median expedition {median:.0f} s is below the {target[0]} s target")
    if pack["rate_cancelled_by_capacity"]:
        flags.append(f"Reinforced Pack: a full pouch loses {pack['reinforced_expected']:.2f} units on defeat against {pack['base_expected']:.2f} for the base pack"
                     f" (worst case {pack['reinforced_worst']} against {pack['base_worst']}), so the lower rate is cancelled by the bigger pouch"
                     " and only a partly filled pouch benefits")
    if all(r["materials_never_justify_returning"] for r in stay_or_return(tuning).values()):
        flags.append("stay-or-return: materials alone never justify returning in any zone; only bag items (lost entirely) carry stakes")
    lines += [f"  - {f}" for f in flags] if flags else ["  none"]
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Wildbound P0 economy simulator (math only).")
    parser.add_argument("--runs", type=int, default=200, help="seeded runs per policy (default 200)")
    parser.add_argument("--trips", type=int, default=60, help="expeditions per run (default 60)")
    parser.add_argument("--seed", type=int, default=2026, help="base seed (default 2026)")
    parser.add_argument("--doc", default=str(DOC), help="economy document")
    parser.add_argument("--repo", default=str(REPO), help="repository root")
    args = parser.parse_args(argv)
    if args.runs < 1 or args.trips < 1:
        parser.error("--runs and --trips must be at least 1")
    try:
        doc_text = Path(args.doc).read_text(encoding="utf-8")
        tuning = extract_tuning(doc_text)
        ctx = load_context(args.repo, doc_text)
    except (OSError, TuningError, world_rules.ParseError, world_rules.ConsistencyError) as error:
        print(f"ERROR: {type(error).__name__}: {error}", file=sys.stderr)
        return 2
    problems = check_invariants(tuning, ctx)
    summary = analyse_policies(tuning, ctx, args.runs, args.trips, args.seed)
    sys.stdout.write(render(tuning, ctx, problems, summary, args.runs, args.trips, args.seed))
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
