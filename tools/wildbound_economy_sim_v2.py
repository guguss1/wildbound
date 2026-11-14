"""Wildbound 2.0 economy simulator (T05b of odd/tasks/wildbound-2-0.md).

A MODEL, NOT MEASURED BALANCE. It reads the live economy numbers from
src/wildbound/WildboundEconomyConfig.luau and the proposed, unwired 2.0 numbers from
src/wildbound/WildboundBalance.luau, then plays three invented player profiles (beginner,
intermediate, advanced) through 10, 30 and 60 minute sessions: steal eggs (egg in the backpack,
carry speed), lose the carried load to beasts, PvP or a bat hit, bank Esencia, incubate, farm or
sell the hatched creature, collect the farm and buy upgrades. Every profile field and every rate
the code does not define (PvP, bat, beast loss per trip) is ASSUMED and listed in the output.

It replaces tools/simulate_economy.py (P0 materials), retired on 2026-11-14; its tuning reader now
lives in tools/economy_tuning.py. tools/simulate_hub_economy.py stays as it is.
The old 183-208 s expedition numbers are not used.

Simplifications (also printed in the report):
  * losses are rolled once per trip at a combined rate, not from the Beast Director's 20 s ticks;
  * the carried leg is ASSUMED to be half of the trip; egg weight slows that half by 16 / carry speed,
    the treadmill speeds up the unloaded half by 16 / walk speed;
  * egg Esencia on banking uses the live eggEmberByTier through the SpawnClock REWARD map
    (Comun -> Fog, Rara -> FogFar, Epica -> Territory, Legendaria -> Heart), an ASSUMED mapping;
  * a hatched creature is placed or sold at the moment it hatches; the player collects the farm on
    a hub visit once collect_interval_s has passed, and once more when the session ends;
  * farm mode `fresh` (ASSUMED): every session is a fresh account with an empty farm, the 10 s first egg,
    the first-steal bonus and the free spin, and the farm is worth nothing after the session ends;
    farm mode `carry` (ASSUMED): a returning account whose farm starts pre-filled with the profile's
    carry_farm, whose first-time bonuses are spent, and which values a farmed creature for
    CARRY_FUTURE_MINUTES past the session end; upgrade levels still start at 0 in both modes;
  * the roulette is modelled by category weights with PLACEHOLDER values; exact prizes and pity are T09a.

Usage (from the project root):

    python -I -B tools/wildbound_economy_sim_v2.py --profile all --minutes 10,30,60 --seed 7 --runs 200         --farm-mode both --md
"""

import argparse
import json
import math
import random
import re
import statistics
import sys
from dataclasses import dataclass, fields, asdict
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:  # `python -I` does not put the script folder on the path
    sys.path.insert(0, _HERE)

REPO = Path(__file__).resolve().parent.parent
ECONOMY_CONFIG = "src/wildbound/WildboundEconomyConfig.luau"
BALANCE = "src/wildbound/WildboundBalance.luau"
TRAINING = "src/wildbound/WildboundTraining.luau"
INCUBATOR = "src/wildbound/WildboundIncubator.luau"
SPAWN_CLOCK = "src/wildbound/WildboundSpawnClock.luau"
WAVE_CLOCK = "src/wildbound/WildboundWaveClock.luau"
WORLD_RULES = "src/wildbound/WildboundWorldRules.luau"
EGG_CARRY = "src/wildbound/WildboundEggCarry.luau"
LUMIPOL_WILD = "src/wildbound/WildboundLumipolWild.luau"
BEAST_CONFIG = "src/wildbound/WildboundBeastConfig.luau"  # read only: another agent edits it
ISLAND = "src/wildbound/WildboundIsland.luau"

RARITIES = ("Comun", "Rara", "Epica", "Legendaria")
BASE_WALK = 16.0
CARRY_LEG_SHARE = 0.5  # ASSUMED: the loaded leg is half of the trip
STALL_SECONDS = 300  # the spec's stall rule: more than 5 min with nothing affordable
LADDER_SESSION_MULTIPLE = 3  # ASSUMED: flag a next step that needs more than 3 sessions of income
LADDER_GROWTH_THRESHOLD = 2.5  # ASSUMED: flag a ladder whose mean cost growth per level exceeds this
LADDER_TOP_SESSIONS = 20  # ASSUMED: flag a ladder whose top level needs more than this many sessions
HARD_LOCKOUT_INCOME_FLOOR = 1.0  # ASSUMED: Esencia per hour treated as "income near zero"
CARRY_FUTURE_MINUTES = 60  # ASSUMED: carry mode values a farmed creature this long past the session end
CARRY_PREVIOUS_HATCHES = 2  # carry mode: the first and second egg timers were used in earlier sessions
FARM_MODES = ("fresh", "carry")
DISCLAIMER = "Model, not measured balance; ASSUMED fields listed below."
PLACEHOLDER = "PLACEHOLDER - exact prizes are T09a"
ROULETTE_PLACEHOLDER_VALUES = {
    "esencia": 60, "materials": 10, "gloves": 20, "incubationBoosters": 15, "consumables": 30, "specialEgg": 150,
}


class NumbersUnavailable(Exception):
    """A source file is missing or a value could not be parsed. There is no silent fallback."""


# ---- Parsing --------------------------------------------------------------------------------------
TOKEN = re.compile(r'\s*(?:("(?:\\.|[^"\\])*")|(-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?)|([A-Za-z_][A-Za-z0-9_.]*)|(\S))')


def strip_comments(text):
    """Remove Luau `--` line comments (block comments are not used in the parsed literals)."""
    out = []
    for line in text.split("\n"):
        in_string, index = False, 0
        while index < len(line):
            ch = line[index]
            if ch == '"' and (index == 0 or line[index - 1] != "\\"):
                in_string = not in_string
            elif not in_string and line.startswith("--", index):
                line = line[:index]
                break
            index += 1
        out.append(line)
    return "\n".join(out)


def _tokens(text):
    out = []
    for string, number, name, other in TOKEN.findall(text):
        if string:
            out.append(("str", re.sub(r"\\(.)", r"\1", string[1:-1])))
        elif number:
            out.append(("num", float(number) if any(c in number for c in ".eE") else int(number)))
        elif name:
            out.append(("name", name))
        elif other:
            out.append(("op", other))
    return out


def parse_balance_literal(text):
    """Parse one Luau table literal, optionally wrapped in freeze( ... ), into Python values.

    Accepts `name = v`, `["s"] = v` and `[5] = v` keys, arrays, strings, numbers and booleans.
    A call such as `Config.perRoll(0.20)` is not accepted (it raises ValueError).
    """
    tokens = _tokens(strip_comments(text))
    if len(tokens) >= 2 and tokens[0] == ("name", "freeze") and tokens[1] == ("op", "("):
        if tokens[-1] != ("op", ")"):
            raise ValueError("unbalanced freeze(")
        tokens = tokens[2:-1]
    pos = [0]

    def peek(offset=0):
        index = pos[0] + offset
        return tokens[index] if index < len(tokens) else ("eof", None)

    def take(kind=None, value=None):
        token = peek()
        if (kind and token[0] != kind) or (value is not None and token[1] != value):
            raise ValueError(f"unexpected {token!r}")
        pos[0] += 1
        return token

    def parse_value():
        kind, value = peek()
        if (kind, value) == ("op", "{"):
            return parse_table()
        take()
        if kind in ("str", "num"):
            return value
        if kind == "name" and value in ("true", "false"):
            return value == "true"
        if kind == "op" and value == "-" and peek()[0] == "num":
            return -take()[1]
        raise ValueError(f"unexpected {value!r}")

    def parse_table():
        take("op", "{")
        keyed, items = {}, []
        while peek() != ("op", "}"):
            if peek() == ("op", "["):
                take()
                key = take()[1]
                take("op", "]")
                take("op", "=")
                keyed[key] = parse_value()
            elif peek()[0] == "name" and peek(1) == ("op", "="):
                key = take()[1]
                take()
                keyed[key] = parse_value()
            else:
                items.append(parse_value())
            if peek() in (("op", ","), ("op", ";")):
                take()
        take("op", "}")
        if keyed and items:
            raise ValueError("mixed table")
        return keyed if keyed else items

    result = parse_value()
    if pos[0] != len(tokens):
        raise ValueError("trailing tokens")
    return result


def _assignment_literal(text, marker):
    """The `freeze({ ... })` literal assigned after `marker`, by brace matching."""
    start = text.find(marker)
    if start < 0:
        raise ValueError(f"{marker!r} not found")
    open_at = text.index("{", start)
    depth, index, in_string = 0, open_at, False
    clean = strip_comments(text[open_at:])
    for index, ch in enumerate(clean):
        if ch == '"':
            in_string = not in_string
        elif not in_string and ch == "{":
            depth += 1
        elif not in_string and ch == "}":
            depth -= 1
            if depth == 0:
                return clean[: index + 1]
    raise ValueError(f"{marker!r}: unbalanced braces")


def _read(repo, relpath, paths=None):
    path = Path(paths[relpath]) if paths and relpath in paths else Path(repo) / relpath
    try:
        return path.read_text(encoding="utf-8").replace("\r\n", "\n")
    except OSError as error:
        raise NumbersUnavailable(f"{relpath}: cannot read ({error})") from error


def _number(text, relpath, pattern):
    found = re.search(pattern, text, re.M)
    if not found:
        raise NumbersUnavailable(f"{relpath}: {pattern!r} not found")
    value = found.group(1)
    return float(value) if "." in value else int(value)


# ---- Mirrors: values the simulator copies, each re-read from its source by check_drift ------------
# Each value is found by a pattern, not by line number, so no line numbers are kept here.
MIRRORED = {
    "egg_carry_speeds": {
        "value": {0: 16, 1: 11, 2: 10, 3: 9}, "source": LUMIPOL_WILD,
        "note": "walk by eggs in the bag (0, 1, 2, 3 or more)",
    },
    "island_tier_distances": {
        "value": {"Legendaria": 45, "Epica": 80, "Rara": 120}, "source": SPAWN_CLOCK,
        "note": "SpawnClock.tierOf: under 45 Legendaria, under 80 Epica, up to 120 Rara, else Comun",
    },
    "beast_tick_seconds": {"value": 20, "source": BEAST_CONFIG, "note": "Beast Director roll interval"},
    "beast_per_roll_cap_10s": {"value": 0.20, "source": BEAST_CONFIG, "note": "MAX_CHANCE = perRoll(0.20)"},
    "beast_global_cooldown": {"value": 15, "source": BEAST_CONFIG, "note": "seconds after an encounter"},
    "eggs_per_nest": {"value": 3, "source": ISLAND, "note": "caps eggs_per_trip_target"},
    "egg_share": {"value": 0.4, "source": SPAWN_CLOCK,
                  "note": "EGG_SHARE 0.4 and every bough spawn is an egg; the trip model still counts nest eggs only"},
}


def _read_mirror(name, text, relpath):
    if name == "egg_carry_speeds":
        walk = _number(text, relpath, r"^\s*WALK_SPEED = (\d+(?:\.\d+)?)")
        found = re.search(r"local function eggSpeed\(eggs\).*?if eggs < 2 then return (\d+) end\s*"
                          r"if eggs < 3 then return (\d+) end\s*return (\d+)", text, re.S)
        if not found:
            raise NumbersUnavailable(f"{relpath}: eggSpeed not found")
        return {0: walk, 1: int(found.group(1)), 2: int(found.group(2)), 3: int(found.group(3))}
    if name == "island_tier_distances":
        found = re.search(r'distance < (\d+) then return "Legendaria".*?distance < (\d+) then return "Epica"'
                          r'.*?distance <= (\d+) then return "Rara"', text, re.S)
        if not found:
            raise NumbersUnavailable(f"{relpath}: tierOf not found")
        return {"Legendaria": int(found.group(1)), "Epica": int(found.group(2)), "Rara": int(found.group(3))}
    if name == "beast_tick_seconds":
        return _number(text, relpath, r"^local TICK_SECONDS = (\d+)")
    if name == "beast_per_roll_cap_10s":
        return _number(text, relpath, r"MAX_CHANCE = Config\.perRoll\(([0-9.]+)\)")
    if name == "beast_global_cooldown":
        return _number(text, relpath, r"^\s*GLOBAL_COOLDOWN = (\d+)")
    if name == "eggs_per_nest":
        return _number(text, relpath, r"^\s*EGGS_PER_NEST = (\d+)")
    if name == "egg_share":
        return _number(text, relpath, r"EGG_SHARE = ([0-9.]+)")
    raise KeyError(name)


def check_drift(repo=REPO, paths=None):
    """Re-read every MIRRORED value from its source; return one line per mismatch (empty when all match)."""
    problems = []
    for name, entry in MIRRORED.items():
        text = _read(repo, entry["source"], paths)
        actual = _read_mirror(name, text, entry["source"])
        if actual != entry["value"]:
            key = "EGG_SHARE" if name == "egg_share" else name
            problems.append(f"{key}: mirrored {entry['value']!r}, {entry['source']} has {actual!r}")
    return problems


# ---- Loading the numbers ----------------------------------------------------------------------------
def load_numbers(repo=REPO, source="live", balance="proposed"):
    """Every number the model uses, read from the repo files. Raises NumbersUnavailable on any failure."""
    repo = Path(repo)
    if source == "live":
        text = _read(repo, ECONOMY_CONFIG)
        try:
            import export_economy_config_luau as exporter
            economy = exporter.parse_luau(text)
        except Exception as error:  # noqa: BLE001 - any parse failure is fatal and named
            raise NumbersUnavailable(f"{ECONOMY_CONFIG}: cannot parse ({error})") from error
    elif source == "doc":
        try:
            import economy_tuning as eco
            economy = eco.load_tuning()
        except Exception as error:  # noqa: BLE001
            raise NumbersUnavailable(f"docs/mechanics/wildbound-economy-p0.md: cannot load ({error})") from error
    else:
        raise ValueError(f"unknown source {source!r}")
    if balance not in ("proposed", "live"):
        raise ValueError(f"unknown balance {balance!r}")
    try:
        earn = economy["earn"]
        creature = dict(earn["creatureEmberByTier"])
        egg = dict(earn["eggEmberByTier"])
        first_steal, extract_base = earn["firstStealBonus"], earn["extractBaseEmber"]
        extract_min = earn["baseRequires"]["minExpeditionSeconds"]
    except (KeyError, TypeError) as error:
        raise NumbersUnavailable(f"{ECONOMY_CONFIG}: missing earn value ({error})") from error

    balance_text = _read(repo, BALANCE)
    try:
        constants = parse_balance_literal(_assignment_literal(balance_text, "Balance.CONSTANTS = freeze("))
        live = parse_balance_literal(_assignment_literal(balance_text, "Balance.LIVE = freeze("))
    except ValueError as error:
        raise NumbersUnavailable(f"{BALANCE}: cannot parse ({error})") from error

    training_text = _read(repo, TRAINING)
    training = {key: _number(training_text, TRAINING, r"^\s*" + key + r" = ([0-9.]+)")
                for key in ("WALK_STEP", "MAX_LEVEL", "WALK_CAP", "BASE_COST", "COST_GROWTH")}
    incubator_text = _read(repo, INCUBATOR)
    incubator = {key: _number(incubator_text, INCUBATOR, key + r" = ([0-9.]+)") for key in ("HATCH_SECONDS", "SLOTS")}
    try:
        incubator["RARITY_MULTIPLIER"] = parse_balance_literal(
            _assignment_literal(incubator_text, "Incubator.RARITY_MULTIPLIER = freeze("))
    except ValueError as error:
        raise NumbersUnavailable(f"{INCUBATOR}: RARITY_MULTIPLIER ({error})") from error
    spawn_text = _read(repo, SPAWN_CLOCK)
    spawn = {f"{kind}_{r.upper()}": _number(spawn_text, SPAWN_CLOCK, rf"{kind}_{r.upper()} = (\d+)")
             for kind in ("RESPAWN", "MAX") for r in RARITIES}
    spawn["EGG_SHARE"] = _number(spawn_text, SPAWN_CLOCK, r"EGG_SHARE = ([0-9.]+)")
    try:
        reward = parse_balance_literal(_assignment_literal(spawn_text, "SpawnClock.REWARD = freeze("))
    except ValueError as error:
        raise NumbersUnavailable(f"{SPAWN_CLOCK}: REWARD ({error})") from error
    wave_text = _read(repo, WAVE_CLOCK)
    wave = {key: _number(wave_text, WAVE_CLOCK, key + r" = (\d+)") for key in ("WAVE_SECONDS", "EVENT_FIRST", "EVENT_EVERY")}
    world_text = _read(repo, WORLD_RULES)
    phases = {name: int(seconds) for name, seconds in re.findall(r'name = "(\w+)", seconds = (\d+)', world_text)}
    if set(phases) != {"Day", "Dusk", "Night", "Dawn"}:
        raise NumbersUnavailable(f"{WORLD_RULES}: phase seconds not found")
    carry_text = _read(repo, EGG_CARRY)
    holds = {key: _number(carry_text, EGG_CARRY, r"^\s*" + key + r" = ([0-9.]+)")
             for key in ("STEAL_HOLD", "RARE_HOLD", "PICKUP_HOLD")}
    mirrors = {name: _read_mirror(name, _read(repo, e["source"]), e["source"]) for name, e in MIRRORED.items()}

    try:
        farm = constants["farm"]
        slot_costs = {int(k): v for k, v in farm["slotCosts"].items()}
        for slot in range(farm["startSlots"] + 1, farm["maxSlots"] + 1):
            slot_costs.setdefault(slot, None)  # TBD in Balance
        numbers = {
            "source": source,
            "balance_mode": balance,
            "creature_esencia": creature,
            "egg_esencia": egg,
            "first_steal_bonus": first_steal,
            "extract_base": extract_base,
            "extract_min_seconds": extract_min,
            "reward_tier": reward,
            "constants": constants,
            "live": live,
            "treadmill_speeds": list(constants["treadmill"]["speeds"]),
            "treadmill_cost_ladder": list(constants["treadmill"]["costs"]),
            "incubation": constants["incubation"],
            "farm_start_slots": farm["startSlots"],
            "farm_slot_costs": dict(sorted(slot_costs.items())),
            "farm_income": dict(farm["incomePerMinute"]),
            "farm_cap_minutes": farm["uncollectedCapMinutes"],
            "sell_price": dict(constants["sell"]["price"]),
            "roulette": constants["roulette"],
            "training": training,
            "incubator": incubator,
            "spawn_clock": spawn,
            "wave_clock": wave,
            "world_phases": phases,
            "holds": holds,
            "mirrors": mirrors,
            "drift": check_drift(repo),
        }
    except (KeyError, TypeError) as error:
        raise NumbersUnavailable(f"{BALANCE}: missing value ({error})") from error
    return numbers


# ---- Profiles ---------------------------------------------------------------------------------------
@dataclass(frozen=True)
class Profile:
    """An invented player archetype. Every field is ASSUMED."""
    name: str
    trip_seconds: float
    steal_success: float
    eggs_per_trip_target: int
    beast_loss_per_trip: float
    pvp_loss_per_trip: float
    bat_drop_per_trip: float
    rarity_mix: tuple
    sell_policy: str
    upgrade_policy: str
    collect_interval_s: float
    creature_items_per_trip: int
    sell_roi_threshold: float = 1.0
    carry_farm: tuple = ()  # carry farm mode: the creatures already on the farm at session start

    FIELDS = ("trip_seconds", "steal_success", "eggs_per_trip_target", "beast_loss_per_trip", "pvp_loss_per_trip",
              "bat_drop_per_trip", "rarity_mix", "sell_policy", "upgrade_policy", "collect_interval_s",
              "creature_items_per_trip", "sell_roi_threshold", "carry_farm")


def default_profiles():
    return {
        "beginner": Profile("beginner", 150, 0.55, 1, 0.25, 0.05, 0.05, (0.75, 0.20, 0.05, 0.0),
                            "never", "cheapest_first", 600, 1, carry_farm=("Rara", "Comun", "Comun", "Comun")),
        "intermediate": Profile("intermediate", 110, 0.75, 2, 0.15, 0.10, 0.04, (0.55, 0.30, 0.12, 0.03),
                                "sell_rara_plus_when_farm_full", "treadmill_then_incubator", 420, 2,
                                carry_farm=("Epica", "Rara", "Rara", "Comun")),
        "advanced": Profile("advanced", 85, 0.9, 3, 0.08, 0.12, 0.03, (0.35, 0.35, 0.22, 0.08),
                            "sell_legendary_if_roi<X", "roi_greedy", 300, 3,
                            carry_farm=("Legendaria", "Epica", "Epica", "Rara")),
    }


def load_profile_file(path):
    data = json.loads(Path(path).read_text(encoding="utf-8"))
    out = {}
    for name, values in data.items():
        values = dict(values, name=name)
        values["rarity_mix"] = tuple(values["rarity_mix"])
        values["carry_farm"] = tuple(values.get("carry_farm", ()))
        out[name] = Profile(**values)
    return out


# ---- Pure rules -------------------------------------------------------------------------------------
def treadmill_costs(numbers):
    return list(numbers["treadmill_cost_ladder"])


def training_costs(numbers):
    """The live Training ladder: Training.cost(level) = floor(BASE_COST * COST_GROWTH ^ level + 0.5)."""
    t = numbers["training"]
    return [math.floor(t["BASE_COST"] * t["COST_GROWTH"] ** level + 0.5) for level in range(int(t["MAX_LEVEL"]))]


def incubation_seconds(numbers, rarity, previous_hatches, upgrade_level, booster=1.0):
    """Seconds to hatch. proposed: Balance.incubationSeconds; live: HATCH_SECONDS x RARITY_MULTIPLIER."""
    if numbers["balance_mode"] == "live":
        inc = numbers["incubator"]
        return inc["HATCH_SECONDS"] * inc["RARITY_MULTIPLIER"][rarity]
    inc = numbers["incubation"]
    if previous_hatches == 0:
        return inc["firstEggSeconds"]
    if previous_hatches == 1:
        return inc["secondEggSeconds"]
    factors = inc["upgradeFactors"]
    factor = factors[max(0, min(int(upgrade_level), len(factors) - 1))]
    return max(inc["minSeconds"][rarity], inc["baseSeconds"][rarity] * factor * booster)


def carry_speed(numbers, eggs, walk):
    speeds = numbers["mirrors"]["egg_carry_speeds"]
    if eggs <= 0:
        return walk
    return min(walk, speeds[min(eggs, 3)])


def break_even_minutes(numbers, rarity):
    """Minutes of farm income that equal the sell price (before the uncollected cap)."""
    return numbers["sell_price"][rarity] / numbers["farm_income"][rarity]


def idle_farm_esencia_per_hour(numbers, rarities, collect_every_minutes=15):
    """Farm-only Esencia per hour: no exploring, the farm collected every collect_every_minutes."""
    cap = numbers["farm_cap_minutes"]
    per_collect = sum(numbers["farm_income"][r] * min(collect_every_minutes, cap) for r in rarities)
    return per_collect * 60.0 / collect_every_minutes


def roulette_ev(weights, category_value, spin_cost=45):
    """Expected value of one spin by category weight (percent). The money loop exists when EV >= spin_cost."""
    total = float(sum(weights.values()))
    share = {k: w / total for k, w in weights.items()}
    ev = sum(share[k] * category_value.get(k, 0) for k in share)
    others = ev - share.get("esencia", 0) * category_value.get("esencia", 0)
    w_esencia = share.get("esencia", 0)
    break_even = (spin_cost - others) / w_esencia if w_esencia > 0 else math.inf
    return {"ev": ev, "spin_cost": spin_cost, "break_even_esencia_value": break_even,
            "esencia_share": w_esencia,
            "esencia_only_ev": w_esencia * category_value.get("esencia", 0),
            "esencia_only_break_even": spin_cost / w_esencia if w_esencia > 0 else math.inf,
            "infinite_money_risk": ev >= spin_cost, "values": dict(category_value), "label": PLACEHOLDER}


def roulette_cost(numbers, spins):
    """Esencia paid for `spins` spins; the account's first spin is free when freeFirstSpin is set."""
    free = 1 if numbers["roulette"].get("freeFirstSpin") else 0
    return max(0, spins - free) * numbers["roulette"]["spinCost"]


def stall_flag(income_per_hour, cheapest_remaining_cost, stall_seconds):
    """Slow progress (the spec's stall rule): over 5 min with no affordable upgrade, earning under the
    cheapest remaining cost per 10 min. A stall is not a lockout: the player still earns and catches up."""
    if cheapest_remaining_cost is None:
        return False
    return stall_seconds > STALL_SECONDS and income_per_hour / 6.0 < cheapest_remaining_cost


def hard_lockout_flag(esencia, income_per_hour, cheapest_remaining_cost, stall_seconds, session_hours):
    """A real dead end: stalled over 5 min and either the income is near zero (ASSUMED floor) or the Esencia on
    hand plus one whole session of income at this rate still cannot pay the cheapest remaining upgrade.
    The simulator calls it once at session end with the session's mean income (check_hard_lockout)."""
    if cheapest_remaining_cost is None or stall_seconds <= STALL_SECONDS:
        return False
    if income_per_hour < HARD_LOCKOUT_INCOME_FLOOR:
        return True
    return esencia + income_per_hour * session_hours < cheapest_remaining_cost


def ladder_indicator(costs, income_per_hour=None, session_minutes=None, owned_levels=0):
    """Exponential-ladder check for one cost ladder at one income and owned level.

    growth_flag: the geometric mean cost ratio exceeds LADDER_GROWTH_THRESHOLD (ASSUMED).
    step_flag: the next step (after owned_levels) needs more than LADDER_SESSION_MULTIPLE sessions of income.
    top_flag: the remaining levels up to the top need more than LADDER_TOP_SESSIONS sessions of income.
    """
    paid = [c for c in costs if c]
    ratios = [paid[i + 1] / paid[i] for i in range(len(paid) - 1)]
    growth = math.exp(statistics.fmean(math.log(r) for r in ratios)) if ratios else None
    growth_flag = growth is not None and growth > LADDER_GROWTH_THRESHOLD
    out = {"costs": list(costs), "ratios": [round(r, 3) for r in ratios], "growth": growth,
           "growth_flag": growth_flag, "owned_levels": owned_levels, "hours_for_next": None,
           "hours_to_top": None, "sessions_to_top": None, "step_flag": False, "top_flag": False}
    remaining = paid[owned_levels:] if owned_levels < len(paid) else []
    if income_per_hour:
        out["hours_to_top"] = sum(remaining) / income_per_hour
        if remaining:
            out["hours_for_next"] = remaining[0] / income_per_hour
        if session_minutes:
            session_hours = session_minutes / 60.0
            out["sessions_to_top"] = out["hours_to_top"] / session_hours
            out["step_flag"] = out["hours_for_next"] is not None and \
                out["hours_for_next"] > session_hours * LADDER_SESSION_MULTIPLE
            out["top_flag"] = out["sessions_to_top"] > LADDER_TOP_SESSIONS
    out["flag"] = growth_flag or out["step_flag"] or out["top_flag"]
    return out


def ladder_runs(costs, runs, level_key, minutes):
    """ladder_indicator evaluated per run, at that run's own owned level and Esencia/h; then aggregated.

    level_key None means the ladder is not simulated (owned level 0 in every run)."""
    hours = minutes / 60.0
    per = [ladder_indicator(costs, r["esencia_total"] / hours, minutes, int(r[level_key]) if level_key else 0)
           for r in runs]
    base = ladder_indicator(costs)

    def mean_of(key):
        got = [p[key] for p in per if p[key] is not None]
        return statistics.fmean(got) if got else None

    def share(key):
        return statistics.fmean(1.0 if p[key] else 0.0 for p in per) if per else 0.0
    return {"costs": base["costs"], "ratios": base["ratios"], "growth": base["growth"],
            "growth_flag": base["growth_flag"], "level_key": level_key,
            "owned_level_mean": statistics.fmean(p["owned_levels"] for p in per) if per else 0.0,
            "hours_for_next_mean": mean_of("hours_for_next"), "hours_to_top_mean": mean_of("hours_to_top"),
            "sessions_to_top_mean": mean_of("sessions_to_top"), "step_flag_share": share("step_flag"),
            "top_flag_share": share("top_flag"), "flag_share": share("flag"),
            "flag": any(p["flag"] for p in per)}


# ---- Session state ----------------------------------------------------------------------------------
class SessionState:
    def __init__(self, numbers, profile, session_seconds, farm_mode="fresh"):
        if farm_mode not in FARM_MODES:
            raise ValueError(f"unknown farm mode {farm_mode!r}")
        carry = farm_mode == "carry"
        self.profile = profile
        self.farm_mode = farm_mode
        self.session_seconds = session_seconds
        self.esencia = 0.0
        self.split = {"expedition": 0.0, "farm": 0.0, "sale": 0.0, "roulette": 0.0}
        self.spin_spend = 0.0
        self.treadmill_level = 0
        self.incubator_level = 0
        self.cradle_free = [0.0]  # time each cradle is free
        self.farm_slots = numbers["farm_start_slots"]
        self.slot_level = numbers["farm_start_slots"]
        self.farm = [[r, 0.0] for r in profile.carry_farm[:self.farm_slots]] if carry else []  # [rarity, since]
        self.storage = []
        self.queue = []  # [rarity, queued_at]
        self.active = []  # [end, rarity]
        self.previous_hatches = CARRY_PREVIOUS_HATCHES if carry else 0  # hatches finished before this session
        self.hatch_times = []
        self.purchases = {}  # upgrade -> time, bought during play
        self.end_purchases = {}  # upgrade -> time, bought at the session-end shop (not a time-to-upgrade)
        self.first_egg_s = None
        self.first_hatch_s = None
        self.first_steal_paid = carry
        self.free_spin_used = carry
        self.eggs_stolen = self.eggs_banked = self.eggs_lost = self.trips = self.losses = 0
        self.sold = {r: 0 for r in RARITIES}
        self.hatched = {r: 0 for r in RARITIES}
        self.spins = 0
        self.spin_prizes = {}
        self.last_collect = 0.0
        self.stall_start = None
        self.max_stall = 0.0
        self.stall = False
        self.hard_lockout = False
        self.sell_mandatory = False
        self.history = [(0.0, 0.0)]  # (t, cumulative earned)

    def earned(self):
        return sum(self.split.values())

    def add(self, kind, amount):
        self.esencia += amount
        self.split[kind] += amount

    def queue_egg(self, rarity, t):
        self.queue.append([rarity, float(t)])

    def add_to_farm(self, rarity, t):
        self.farm.append([rarity, float(t)])

    def advance_incubator(self, numbers, to_t, on_hatch=None):
        """Start queued eggs on free cradles and hatch every egg that ends by to_t, in time order."""
        # A start depends only on when a cradle frees (its end time), never on the hatch callback, so every start is
        # placed first and the due hatches are then resolved in time order.
        while self.queue:
            index = min(range(len(self.cradle_free)), key=lambda i: self.cradle_free[i])
            rarity, queued_at = self.queue[0]
            start = max(self.cradle_free[index], queued_at)
            if start > to_t:
                break
            self.queue.pop(0)
            # Balance's previousHatches is the number of hatches already FINISHED when this egg starts.
            finished = self.previous_hatches + len(self.hatch_times) + sum(1 for a in self.active if a[0] <= start)
            seconds = incubation_seconds(numbers, rarity, finished, self.incubator_level)
            self.cradle_free[index] = start + seconds
            self.active.append([start + seconds, rarity])
        for item in sorted(a for a in self.active if a[0] <= to_t):
            end, rarity = item
            self.active.remove(item)
            self.hatch_times.append(end)
            self.hatched[rarity] += 1
            if self.first_hatch_s is None:
                self.first_hatch_s = end
            if on_hatch:
                on_hatch(rarity, end)


def new_state(numbers, profile, session_seconds, farm_mode="fresh"):
    return SessionState(numbers, profile, session_seconds, farm_mode)


def collect_farm(state, numbers, t):
    """Collect every farm creature; each accrues at most farm_cap_minutes since its last collection."""
    cap = numbers["farm_cap_minutes"]
    gained = 0.0
    for entry in state.farm:
        minutes = min(max(0.0, (t - entry[1]) / 60.0), cap)
        gained += numbers["farm_income"][entry[0]] * minutes
        entry[1] = t
    state.add("farm", gained)
    state.last_collect = t
    return gained


def bank_trip(state, numbers, t_end, duration, eggs, creatures, lost):
    """Resolve one trip at t_end. A loss drops every carried egg and creature item; banked Esencia is never lost."""
    state.trips += 1
    state.eggs_stolen += len(eggs)
    if lost:
        state.losses += 1
        state.eggs_lost += len(eggs)
        return 0.0
    reward = numbers["reward_tier"]
    gained = sum(numbers["creature_esencia"][reward[r]] for r in creatures)
    gained += sum(numbers["egg_esencia"][reward[r]] for r in eggs)  # ASSUMED egg price mapping
    if (eggs or creatures) and duration >= numbers["extract_min_seconds"]:
        gained += numbers["extract_base"]
    if eggs and not state.first_steal_paid:
        gained += numbers["first_steal_bonus"]
        state.first_steal_paid = True
    if eggs and state.first_egg_s is None:
        state.first_egg_s = t_end
    state.eggs_banked += len(eggs)
    for rarity in eggs:
        state.queue_egg(rarity, t_end)
    state.add("expedition", gained)
    return gained


# ---- Upgrades ---------------------------------------------------------------------------------------
def available_upgrades(state, numbers):
    """(id, cost) of every next upgrade; cost None means TBD in Balance."""
    out = []
    ladder = numbers["treadmill_cost_ladder"]
    if state.treadmill_level + 1 < len(ladder):
        out.append((f"treadmill_{state.treadmill_level + 1}", ladder[state.treadmill_level + 1]))
    inc = numbers["incubation"]["upgradeCosts"]
    if state.incubator_level + 1 < len(inc):
        out.append((f"incubator_{state.incubator_level + 1}", inc[state.incubator_level + 1]))
    if len(state.cradle_free) < 2:
        out.append(("cradle_2", numbers["incubation"]["secondCradleCost"]))
    next_slot = state.slot_level + 1
    if next_slot in numbers["farm_slot_costs"]:
        out.append((f"farm_slot_{next_slot}", numbers["farm_slot_costs"][next_slot]))
    return out


def all_upgrade_ids(numbers):
    ids = [f"treadmill_{i}" for i in range(1, len(numbers["treadmill_cost_ladder"]))]
    ids += [f"incubator_{i}" for i in range(1, len(numbers["incubation"]["upgradeCosts"]))]
    ids.append("cradle_2")
    ids += [f"farm_slot_{s}" for s in numbers["farm_slot_costs"]]
    return ids


def walk_speed(state, numbers):
    speeds = numbers["treadmill_speeds"]
    return float(speeds[min(state.treadmill_level, len(speeds) - 1)])


def trip_walk_seconds(profile, walk, carried_speed):
    """The unloaded half scales by 16 / walk, the loaded half by 16 / carry speed (ASSUMED 50/50 split)."""
    half = profile.trip_seconds * CARRY_LEG_SHARE
    return half * BASE_WALK / walk + (profile.trip_seconds - half) * BASE_WALK / carried_speed


def _mean_income_per_min(numbers, mix):
    return sum(w * numbers["farm_income"][r] for w, r in zip(mix, RARITIES))


def _buy(state, numbers, upgrade_id, cost, t, final=False):
    state.esencia -= cost
    (state.end_purchases if final else state.purchases)[upgrade_id] = t
    kind = upgrade_id.rsplit("_", 1)
    if upgrade_id.startswith("treadmill_"):
        state.treadmill_level += 1
    elif upgrade_id.startswith("incubator_"):
        state.incubator_level += 1
    elif upgrade_id == "cradle_2":
        state.cradle_free.append(float(t))
    elif upgrade_id.startswith("farm_slot_"):
        state.slot_level = int(kind[1])
        state.farm_slots += 1
        if state.storage:
            best = max(state.storage, key=lambda r: numbers["farm_income"][r])
            state.storage.remove(best)
            state.add_to_farm(best, t)


def _choose(state, numbers, options, t):
    """The upgrade the policy wants next (it may be unaffordable: the player then saves)."""
    policy = state.profile.upgrade_policy
    if not options:
        return None
    if policy == "cheapest_first":
        return min(options, key=lambda o: o[1])
    if policy == "treadmill_then_incubator":
        order = ("treadmill_", "incubator_", "cradle_2", "farm_slot_")
        return min(options, key=lambda o: next(i for i, p in enumerate(order) if o[0].startswith(p)))
    if policy == "roi_greedy":
        mean_income = _mean_income_per_min(numbers, state.profile.rarity_mix) * 60.0
        active_rate = state.split["expedition"] / max(t, 60.0) * 3600.0
        scored = []
        for upgrade_id, cost in options:
            if upgrade_id.startswith("treadmill_"):
                walk = walk_speed(state, numbers)
                nxt = numbers["treadmill_speeds"][state.treadmill_level + 1]
                old = trip_walk_seconds(state.profile, walk, carry_speed(numbers, 1, walk))
                new = trip_walk_seconds(state.profile, nxt, carry_speed(numbers, 1, nxt))
                gain = active_rate * (old / new - 1.0)
            elif upgrade_id.startswith("farm_slot_"):
                if state.storage:
                    gain = max(numbers["farm_income"][r] for r in state.storage) * 60.0
                else:
                    gain = mean_income * (0.5 if len(state.farm) >= state.farm_slots else 0.0)
            elif upgrade_id == "cradle_2":
                gain = mean_income * (1.0 if len(state.queue) >= 1 else 0.25)
            else:
                gain = mean_income * 0.2 * (1.0 if state.queue else 0.25)
            scored.append((gain / cost, upgrade_id, cost))
        best = max(scored)
        if best[0] <= 0:
            return min(options, key=lambda o: o[1])
        return (best[1], best[2])
    raise ValueError(f"unknown upgrade policy {policy!r}")


def shop(state, numbers, t, final=False):
    """Buy what the policy wants while affordable; track stalls (hard lockouts are checked at session end).

    final marks the session-end shop: its purchases are kept apart from the time-to-upgrade figures."""
    bought = False
    while True:
        options = [o for o in available_upgrades(state, numbers) if o[1] is not None]
        choice = _choose(state, numbers, options, t)
        if choice is None or state.esencia + 1e-9 < choice[1]:
            break
        _buy(state, numbers, choice[0], choice[1], t, final)
        bought = True
    options = [o for o in available_upgrades(state, numbers) if o[1] is not None]
    cheapest = min((o[1] for o in options), default=None)
    if bought or cheapest is None or state.esencia >= cheapest:
        state.stall_start = None
        return
    if state.stall_start is None:
        state.stall_start = t
    stall = t - state.stall_start
    state.max_stall = max(state.max_stall, stall)
    window_start = max(0.0, t - 600.0)
    before = next((e for (tt, e) in reversed(state.history) if tt <= window_start), 0.0)
    window = max(t - window_start, 1.0)
    income_per_hour = (state.earned() - before) / window * 3600.0
    if stall_flag(income_per_hour, cheapest, stall):
        state.stall = True


def check_hard_lockout(state, numbers):
    """At session end: stalled, and the session's MEAN income (not a noisy 10 min window) cannot pay the cheapest
    remaining upgrade within one more whole session. Sets sell_mandatory when only a Legendaria sale would clear it."""
    options = [o for o in available_upgrades(state, numbers) if o[1] is not None]
    cheapest = min((o[1] for o in options), default=None)
    session_hours = state.session_seconds / 3600.0
    stall = state.session_seconds - state.stall_start if state.stall_start is not None else 0.0
    rate = state.earned() / session_hours if session_hours else 0.0
    if hard_lockout_flag(state.esencia, rate, cheapest, stall, session_hours):
        state.hard_lockout = True
        legendaries = sum(1 for r, _ in state.farm if r == "Legendaria") + state.storage.count("Legendaria")
        if legendaries and state.esencia + numbers["sell_price"]["Legendaria"] >= cheapest:
            state.sell_mandatory = True


def place_hatch(state, numbers, rarity, t):
    """Farm or sell a hatched creature, by the profile's sell policy."""
    policy = state.profile.sell_policy
    income = numbers["farm_income"]
    price = numbers["sell_price"]
    if policy == "sell_legendary_if_roi<X" and rarity == "Legendaria":
        # fresh: the farm is worth nothing after the session (ASSUMED); carry: it keeps paying for a while after.
        remaining_min = max(0.0, (state.session_seconds - t) / 60.0)
        if state.farm_mode == "carry":
            remaining_min += CARRY_FUTURE_MINUTES
        if remaining_min * income[rarity] < price[rarity] * state.profile.sell_roi_threshold:
            state.sold[rarity] += 1
            state.add("sale", price[rarity])
            return
    if len(state.farm) < state.farm_slots:
        state.add_to_farm(rarity, t)
        return
    lowest = min(state.farm, key=lambda e: income[e[0]])
    loser = rarity
    if income[rarity] > income[lowest[0]]:
        cap = numbers["farm_cap_minutes"]
        accrued = income[lowest[0]] * min(max(0.0, (t - lowest[1]) / 60.0), cap)
        state.add("farm", accrued)  # collected on removal
        state.farm.remove(lowest)
        state.add_to_farm(rarity, t)
        loser = lowest[0]
    sells = policy == "sell_legendary_if_roi<X" or (
        policy == "sell_rara_plus_when_farm_full" and loser != "Comun")
    if sells:
        state.sold[loser] += 1
        state.add("sale", price[loser])
    else:
        state.storage.append(loser)


def spin(state, numbers, rng, values):
    weights = numbers["roulette"]["weights"]
    categories = sorted(weights)
    category = rng.choices(categories, weights=[weights[c] for c in categories])[0]
    state.spins += 1
    state.spin_prizes[category] = state.spin_prizes.get(category, 0) + 1
    if category == "esencia":
        state.add("roulette", values["esencia"])


# ---- One session ------------------------------------------------------------------------------------
def simulate_session(numbers, profile, minutes, seed, roulette_policy="free", roulette_values=None,
                     farm_mode="fresh"):
    """One deterministic session of `minutes` of play. All randomness comes from random.Random(seed)."""
    rng = random.Random(seed)
    values = dict(ROULETTE_PLACEHOLDER_VALUES, **(roulette_values or {}))
    session = int(minutes * 60)
    state = new_state(numbers, profile, session, farm_mode)
    holds = numbers["holds"]
    slots = min(profile.eggs_per_trip_target, numbers["mirrors"]["eggs_per_nest"])
    loss = 1 - (1 - profile.beast_loss_per_trip) * (1 - profile.pvp_loss_per_trip) * (1 - profile.bat_drop_per_trip)
    cost = numbers["roulette"]["spinCost"]
    t = 0

    def hatch(rarity, at):
        place_hatch(state, numbers, rarity, at)

    while t < session:
        # At the hub.
        state.advance_incubator(numbers, t, hatch)
        if t == 0 or t - state.last_collect >= profile.collect_interval_s:
            collect_farm(state, numbers, t)
        if not state.free_spin_used and numbers["roulette"].get("freeFirstSpin"):
            state.free_spin_used = True
            spin(state, numbers, rng, values)
        shop(state, numbers, t)
        while roulette_policy == "spend" and state.esencia >= cost:
            state.esencia -= cost
            state.spin_spend += cost
            spin(state, numbers, rng, values)
        state.history.append((float(t), state.earned()))
        # The trip.
        eggs = []
        hold = 0.0
        for _ in range(slots):
            rarity = rng.choices(RARITIES, weights=profile.rarity_mix)[0]
            if rng.random() < profile.steal_success:
                eggs.append(rarity)
                hold += (holds["STEAL_HOLD"] if rarity in ("Comun", "Rara") else holds["RARE_HOLD"]) + holds["PICKUP_HOLD"]
        creatures = [rng.choices(RARITIES, weights=profile.rarity_mix)[0] for _ in range(profile.creature_items_per_trip)]
        walk = walk_speed(state, numbers)
        duration = max(1, int(round(trip_walk_seconds(profile, walk, carry_speed(numbers, len(eggs), walk)) + hold)))
        lost = rng.random() < loss
        if t + duration > session:
            t = session  # the session ends mid-trip; nothing from it is banked
            break
        t += duration
        bank_trip(state, numbers, t, duration, eggs, creatures, lost)
    state.advance_incubator(numbers, session, hatch)
    collect_farm(state, numbers, session)  # ASSUMED: the player ends the session at the hub and collects
    shop(state, numbers, session, final=True)
    check_hard_lockout(state, numbers)

    remaining = [o for o in available_upgrades(state, numbers) if o[1] is not None]
    return {
        "minutes": minutes,
        "farm_mode": farm_mode,
        "esencia_total": round(state.earned() - state.spin_spend, 6),  # net of Esencia paid for spins
        "split": {k: round(v, 6) for k, v in state.split.items()},
        "spin_spend": round(state.spin_spend, 6),
        "esencia_end": round(state.esencia, 6),
        "eggs_stolen": state.eggs_stolen,
        "eggs_banked": state.eggs_banked,
        "eggs_lost": state.eggs_lost,
        "hatches": len(state.hatch_times),
        "hatched": dict(state.hatched),
        "sold": dict(state.sold),
        "trips": state.trips,
        "losses": state.losses,
        "first_egg_s": state.first_egg_s,
        "first_hatch_s": state.first_hatch_s,
        "purchases": dict(state.purchases),
        "end_purchases": dict(state.end_purchases),
        "affordable_at_end": [u for u, c in remaining if c <= state.esencia],
        "farm": sorted(r for r, _ in state.farm),
        "farm_slots": state.farm_slots,
        "storage": sorted(state.storage),
        "spins": state.spins,
        "spin_prizes": dict(state.spin_prizes),
        "max_stall_s": state.max_stall,
        "stall": state.stall,
        "hard_lockout": state.hard_lockout,
        "sell_mandatory": state.sell_mandatory,
        "treadmill_level": state.treadmill_level,
        "incubator_level": state.incubator_level,
        "cradles": len(state.cradle_free),
        "slot_level": state.slot_level,
        "farm_slots_bought": state.slot_level - numbers["farm_start_slots"],
    }


# ---- Aggregation ------------------------------------------------------------------------------------
def _stats(values):
    values = sorted(values)
    if not values:
        return {"mean": None, "p10": None, "p90": None}

    def pct(q):
        index = q * (len(values) - 1)
        lo, hi = math.floor(index), math.ceil(index)
        return values[lo] + (values[hi] - values[lo]) * (index - lo)
    return {"mean": statistics.fmean(values), "p10": pct(0.1), "p90": pct(0.9)}


def aggregate(runs, minutes, numbers=None):
    hours = minutes / 60.0
    per_hour = lambda key: _stats([r[key] / hours for r in runs])  # noqa: E731
    split = {part: _stats([r["split"][part] / hours for r in runs]) for part in ("expedition", "farm", "sale", "roulette")}
    cell = {
        "minutes": minutes,
        "runs": len(runs),
        "esencia_per_hour": dict(total=_stats([r["esencia_total"] / hours for r in runs]), **split),
        "eggs_per_hour": {"stolen": per_hour("eggs_stolen"), "banked": per_hour("eggs_banked"), "lost": per_hour("eggs_lost")},
        "hatches": _stats([r["hatches"] for r in runs]),  # per session
        "spin_spend_per_hour": per_hour("spin_spend"),
        "passive_share": _stats([r["split"]["farm"] / sum(r["split"].values()) if sum(r["split"].values()) else 0.0
                                 for r in runs]),
        "sale_share": _stats([r["split"]["sale"] / sum(r["split"].values()) if sum(r["split"].values()) else 0.0
                              for r in runs]),
        "first_egg_s": _reach([r["first_egg_s"] for r in runs]),
        "first_hatch_s": _reach([r["first_hatch_s"] for r in runs]),
        "stall_share": statistics.fmean(1.0 if r["stall"] else 0.0 for r in runs),
        "hard_lockout_share": statistics.fmean(1.0 if r["hard_lockout"] else 0.0 for r in runs),
        "max_stall_s": _stats([r["max_stall_s"] for r in runs]),
        "sold_legendary_share": statistics.fmean(1.0 if r["sold"]["Legendaria"] else 0.0 for r in runs),
        "hatched_legendary_share": statistics.fmean(1.0 if r["hatched"]["Legendaria"] else 0.0 for r in runs),
    }
    if numbers is not None:
        ids = all_upgrade_ids(numbers)
        ttu = {}
        for upgrade_id in ids:
            slot = upgrade_id.startswith("farm_slot_") and numbers["farm_slot_costs"].get(int(upgrade_id.rsplit("_", 1)[1]))
            if upgrade_id.startswith("farm_slot_") and slot is None:
                ttu[upgrade_id] = "TBD"
                continue
            reach = _reach([r["purchases"].get(upgrade_id) for r in runs])
            ttu[upgrade_id] = reach if reach["share"] > 0 else "not reached"
        cell["time_to_upgrade"] = ttu
        counts = {}
        for r in runs:
            for upgrade_id in r["affordable_at_end"]:
                counts[upgrade_id] = counts.get(upgrade_id, 0) + 1
        cell["viable_options"] = {u: c / len(runs) for u, c in sorted(counts.items())}
        cell["roi_per_rarity"] = {
            rarity: {
                "farm_esencia_session": numbers["farm_income"][rarity] * minutes,
                "sell_price": numbers["sell_price"][rarity],
                "farm_over_sell": numbers["farm_income"][rarity] * minutes / numbers["sell_price"][rarity],
                "break_even_min": break_even_minutes(numbers, rarity),
            } for rarity in RARITIES
        }
    return cell


def _reach(values):
    got = [v for v in values if v is not None]
    out = _stats(got)
    out["share"] = len(got) / len(values) if values else 0.0
    return out


def indicators(cell, runs, numbers, minutes):
    active = (cell["esencia_per_hour"]["expedition"]["mean"] or 0.0)
    idle_rates = [idle_farm_esencia_per_hour(numbers, r["farm"], 15) for r in runs]
    idle = statistics.fmean(idle_rates) if idle_rates else 0.0
    ladders = {  # each run at its own owned level and its own Esencia/h
        "treadmill_proposed": ladder_runs(numbers["treadmill_cost_ladder"], runs, "treadmill_level", minutes),
        "incubator_proposed": ladder_runs(numbers["incubation"]["upgradeCosts"], runs, "incubator_level", minutes),
        "farm_slots_proposed": ladder_runs([c for c in numbers["farm_slot_costs"].values() if c], runs,
                                           "farm_slots_bought", minutes),
        "training_live": ladder_runs(training_costs(numbers), runs, None, minutes),  # not simulated: level 0
    }
    legend_income = numbers["farm_income"]["Legendaria"]
    legend_price = numbers["sell_price"]["Legendaria"]
    return {
        "stall": cell["stall_share"] > 0,
        "stall_share": cell["stall_share"],
        "hard_lockout": cell["hard_lockout_share"] > 0,
        "hard_lockout_share": cell["hard_lockout_share"],
        "max_stall_s_mean": cell["max_stall_s"]["mean"],
        "exponential_ladder": ladders,
        "idle_farm_esencia_per_hour": idle,
        "idle_farm_ratio": idle / active if active else None,
        "idle_farm_flag": bool(active) and idle / active >= 1.0,
        "idle_farm_4_legendaria_per_hour": idle_farm_esencia_per_hour(numbers, ["Legendaria"] * 4, 15),
        "legendary_sell_attractive": minutes * legend_income < legend_price,
        "legendary_break_even_min": legend_price / legend_income,
        "legendary_sell_mandatory": statistics.fmean(1.0 if r["sell_mandatory"] else 0.0 for r in runs) > 0,
        "legendary_sell_mandatory_share": statistics.fmean(1.0 if r["sell_mandatory"] else 0.0 for r in runs),
    }


def assumptions(profiles, roulette_policy, farm_modes=("fresh",)):
    out = []
    for profile in profiles.values():
        for name in Profile.FIELDS:
            out.append({"field": name, "profile": profile.name, "value": getattr(profile, name), "assumed": True})
    out += [
        {"field": "carry_leg_share", "value": CARRY_LEG_SHARE, "assumed": True},
        {"field": "egg_price_mapping", "value": "SpawnClock.REWARD applied to eggEmberByTier", "assumed": True},
        {"field": "loss_roll", "value": "once per trip, combined beast+pvp+bat", "assumed": True},
        {"field": "session_end_collect", "value": True, "assumed": True},
        {"field": "roulette_category_values", "value": ROULETTE_PLACEHOLDER_VALUES, "assumed": True,
         "label": PLACEHOLDER},
        {"field": "roulette_policy", "value": roulette_policy, "assumed": True},
        {"field": "ladder_threshold_session_multiple", "value": LADDER_SESSION_MULTIPLE, "assumed": True},
        {"field": "ladder_growth_threshold", "value": LADDER_GROWTH_THRESHOLD, "assumed": True},
        {"field": "ladder_top_sessions", "value": LADDER_TOP_SESSIONS, "assumed": True},
        {"field": "hard_lockout_income_floor_per_hour", "value": HARD_LOCKOUT_INCOME_FLOOR, "assumed": True},
        {"field": "farm_mode", "value": ", ".join(farm_modes), "assumed": True,
         "label": "fresh: every session is a fresh account (empty farm, first-time bonuses, farm worthless after "
                  "the session); carry: pre-filled carry_farm, bonuses spent, farm valued "
                  f"{CARRY_FUTURE_MINUTES} min past the session; upgrade levels start at 0 in both"},
        {"field": "carry_future_minutes", "value": CARRY_FUTURE_MINUTES, "assumed": True},
        {"field": "carry_previous_hatches", "value": CARRY_PREVIOUS_HATCHES, "assumed": True},
    ]
    return out


def run_all(numbers, profiles, minutes_list, seed=7, runs=200, roulette_policy="free", roulette_values=None,
            farm_modes=("fresh",)):
    cells = []
    for name, profile in profiles.items():
        for mode in farm_modes:
            for minutes in minutes_list:
                results = [simulate_session(numbers, profile, minutes, seed + i, roulette_policy, roulette_values,
                                            mode) for i in range(runs)]
                cell = aggregate(results, minutes, numbers)
                cell["profile"] = name
                cell["farm_mode"] = mode
                cell["indicators"] = indicators(cell, results, numbers, minutes)
                cells.append(cell)
    values = dict(ROULETTE_PLACEHOLDER_VALUES, **(roulette_values or {}))
    rou = numbers["roulette"]
    return {
        "disclaimer": DISCLAIMER,
        "seed": seed,
        "runs": runs,
        "source": numbers["source"],
        "balance": numbers["balance_mode"],
        "cells": cells,
        "roulette": roulette_ev(rou["weights"], values, rou["spinCost"]),
        "break_even_min": {r: break_even_minutes(numbers, r) for r in RARITIES},
        "farm_slot_costs": {str(k): ("TBD" if v is None else v) for k, v in numbers["farm_slot_costs"].items()},
        "drift": numbers["drift"],
        "farm_modes": list(farm_modes),
        "mirrored": {k: {"value": numbers["mirrors"][k], "source": e["source"]} for k, e in MIRRORED.items()},
        "assumptions": assumptions(profiles, roulette_policy, farm_modes),
    }


# ---- Rendering --------------------------------------------------------------------------------------
def _fmt(value, digits=0):
    if value is None:
        return "-"
    if isinstance(value, str):
        return value
    return f"{value:.{digits}f}"


def _band(stats, digits=0):
    return f"{_fmt(stats['mean'], digits)} ({_fmt(stats['p10'], digits)}-{_fmt(stats['p90'], digits)})"


def _reach_text(value):
    if isinstance(value, str):
        return value
    text = f"{value['mean'] / 60:.1f} min" if value["mean"] is not None else "-"
    return text if value["share"] >= 0.995 else f"{text} ({value['share'] * 100:.0f}%)"


def render_md(report, command=None):
    cells = report["cells"]
    modes = list(dict.fromkeys(c.get("farm_mode", "fresh") for c in cells))
    lines = [
        "# Wildbound 2.0 economy simulation (T05b)",
        "",
        DISCLAIMER,
        "",
        "Inputs are read from the repo (live WildboundEconomyConfig, proposed unwired WildboundBalance); every profile "
        "field, the PvP and bat rates and the roulette prize values are ASSUMED. This is not measured play data.",
        "",
    ]
    if command:
        lines += [f"Regenerate: `{command}`", ""]
    lines += [
        f"Seed {report['seed']}, {report['runs']} runs per cell (seeds seed..seed+runs-1), source `{report['source']}`, "
        f"incubation balance `{report['balance']}`, farm modes `{', '.join(modes)}`. Values are mean (p10-p90).",
        "",
        "Farm modes (both ASSUMED): `fresh` = every session is a fresh account (empty farm, the 10 s first egg, the "
        "first-steal bonus and the free spin; the farm is worth nothing after the session ends). `carry` = a returning "
        "account: the farm starts with the profile's `carry_farm`, the first-time bonuses are spent, and a farmed "
        f"creature is valued for {CARRY_FUTURE_MINUTES} min past the session end. Upgrade levels start at 0 in both.",
        "",
        "## Esencia and eggs per hour",
        "",
        "Esencia/h net is all income minus the Esencia paid for roulette spins (0 with `--roulette-policy free`). "
        "Hatches per session is a count per session, not per hour. First egg and first hatch are session minutes; "
        "the first and second egg timers count hatches already finished (Balance `previousHatches`).",
        "",
        "| Profile | Farm mode | Min | Esencia/h net | Expedition | Farm | Sale | Roulette | Spin spend/h | Passive % "
        "| Sale % | Eggs stolen/h | Eggs banked/h | Hatches per session | First egg | First hatch |",
        "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |",
    ]
    for c in cells:
        e = c["esencia_per_hour"]
        lines.append(
            f"| {c['profile']} | {c.get('farm_mode', 'fresh')} | {c['minutes']} | {_band(e['total'])} | "
            f"{_fmt(e['expedition']['mean'])} | {_fmt(e['farm']['mean'])} | {_fmt(e['sale']['mean'])} | "
            f"{_fmt(e['roulette']['mean'])} | {_fmt(c['spin_spend_per_hour']['mean'])} | "
            f"{_fmt(c['passive_share']['mean'] * 100)} | {_fmt(c['sale_share']['mean'] * 100)} | "
            f"{_fmt(c['eggs_per_hour']['stolen']['mean'], 1)} | {_fmt(c['eggs_per_hour']['banked']['mean'], 1)} | "
            f"{_fmt(c['hatches']['mean'], 1)} | {_reach_text(c['first_egg_s'])} | {_reach_text(c['first_hatch_s'])} |")
    ids = list(cells[0]["time_to_upgrade"]) if cells else []
    lines += ["", "## Time to each upgrade", "",
              "Minutes from session start, mean over the runs that bought it during play (share of runs when under "
              "100%). Purchases at the final session-end shop are excluded.", "",
              "| Profile | Farm mode | Min | " + " | ".join(ids) + " |",
              "| --- | --- | --- | " + " | ".join("---" for _ in ids) + " |"]
    for c in cells:
        lines.append(f"| {c['profile']} | {c.get('farm_mode', 'fresh')} | {c['minutes']} | " +
                     " | ".join(_reach_text(c["time_to_upgrade"][i]) for i in ids) + " |")
    lines += ["", "## Indicators", "",
              f"- Stall (slow progress, the spec's rule): more than {STALL_SECONDS} s with no affordable upgrade while "
              "earning under the cheapest remaining cost per 10 min. A stalled player still earns.",
              f"- Hard lockout (a dead end), checked at session end: stalled more than {STALL_SECONDS} s and either the "
              f"session's mean income is under {HARD_LOCKOUT_INCOME_FLOOR:g} Esencia/h (ASSUMED floor) or the Esencia on "
              "hand plus one more whole session at that mean income cannot pay the cheapest remaining upgrade.",
              f"- Ladder flags (each run at its own owned level and Esencia/h): growth above {LADDER_GROWTH_THRESHOLD} "
              f"per level, next step above {LADDER_SESSION_MULTIPLE} sessions of income, or the top level above "
              f"{LADDER_TOP_SESSIONS} sessions of income (all three thresholds ASSUMED). Training is not simulated, so "
              "it is read at level 0.",
              "",
              "| Profile | Farm mode | Min | Stall runs % | Hard lockout runs % | Longest stall s | Treadmill level "
              "| Treadmill hours for next | Treadmill sessions to top | Ladder flags (runs %) | Idle farm Esencia/h "
              "| Idle / expedition | Legendary sell attractive | Sell mandatory | Viable at end |",
              "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for c in cells:
        i = c["indicators"]
        tread = i["exponential_ladder"]["treadmill_proposed"]
        flags = ", ".join(f"{name} {lad['flag_share'] * 100:.0f}%" for name, lad in i["exponential_ladder"].items()
                          if lad["flag_share"] > 0) or "none"
        viable = ", ".join(f"{u} {s * 100:.0f}%" for u, s in c["viable_options"].items()) or "none"
        lines.append(
            f"| {c['profile']} | {c.get('farm_mode', 'fresh')} | {c['minutes']} | {i['stall_share'] * 100:.0f} | "
            f"{i['hard_lockout_share'] * 100:.0f} | {_fmt(i['max_stall_s_mean'])} | {_fmt(tread['owned_level_mean'], 1)} | "
            f"{_fmt(tread['hours_for_next_mean'], 2)} | {_fmt(tread['sessions_to_top_mean'], 1)} | {flags} | "
            f"{_fmt(i['idle_farm_esencia_per_hour'])} | {_fmt(i['idle_farm_ratio'], 2)} | "
            f"{i['legendary_sell_attractive']} | {i['legendary_sell_mandatory']} | {viable} |")
    if cells:
        lines += ["", "## Cost ladders", "",
                  "| Ladder | Paid costs | Ratios | Mean growth | Growth flag |", "| --- | --- | --- | --- | --- |"]
        for name, lad in cells[0]["indicators"]["exponential_ladder"].items():
            paid = "/".join(_fmt(x) for x in lad["costs"] if x)
            lines.append(f"| {name} | {paid} | {'/'.join(str(r) for r in lad['ratios'])} | "
                         f"{_fmt(lad['growth'], 2)} | {lad['growth_flag']} |")
    stalled = [c for c in cells if c["indicators"]["stall_share"] > 0 or c["indicators"]["hard_lockout_share"] > 0]
    lines += ["", "## Stalls and lockouts, stated plainly", ""]
    for c in stalled:
        i = c["indicators"]
        lines.append(f"- {c['profile']}, {c.get('farm_mode', 'fresh')}, {c['minutes']} min: stalled in "
                     f"{i['stall_share'] * 100:.0f}% of runs (longest stall {_fmt(i['max_stall_s_mean'])} s on average); "
                     f"hard lockout in {i['hard_lockout_share'] * 100:.0f}% of runs.")
    if not stalled:
        lines.append("- No run stalled or hit a hard lockout.")
    if len(modes) > 1:
        lines += ["", "## Sell vs farm by farm mode", "",
                  "Share of gross income (mean over runs), and the share of runs that sold at least one Legendaria.", "",
                  "| Profile | Min | " + " | ".join(f"Sale % {m} | Farm % {m} | Legendaria sold runs % {m}" for m in modes)
                  + " |", "| --- | --- | " + " | ".join("--- | --- | ---" for _ in modes) + " |"]
        keyed = {(c["profile"], c["minutes"], c.get("farm_mode", "fresh")): c for c in cells}
        for profile, minutes in dict.fromkeys((c["profile"], c["minutes"]) for c in cells):
            parts = []
            for m in modes:
                c = keyed.get((profile, minutes, m))
                parts.append("- | - | -" if c is None else
                             f"{c['sale_share']['mean'] * 100:.0f} | {c['passive_share']['mean'] * 100:.0f} | "
                             f"{c['sold_legendary_share'] * 100:.0f}")
            lines.append(f"| {profile} | {minutes} | " + " | ".join(parts) + " |")
    lines += ["", "## Creature ROI (farm vs sell)", "",
              "| Rarity | Farm Esencia/min | Sell price | Break-even min | Farm/sell over 10 / 30 / 60 min |",
              "| --- | --- | --- | --- | --- |"]
    first = (cells[0]["profile"], cells[0].get("farm_mode", "fresh")) if cells else None
    by_min = {c["minutes"]: c["roi_per_rarity"] for c in cells if (c["profile"], c.get("farm_mode", "fresh")) == first}
    for rarity in RARITIES:
        any_cell = next(iter(by_min.values()))[rarity]
        ratio = " / ".join(f"{by_min[m][rarity]['farm_over_sell']:.2f}" for m in sorted(by_min))
        lines.append(f"| {rarity} | {any_cell['farm_esencia_session'] / next(iter(by_min)):.0f} | {any_cell['sell_price']} | "
                     f"{any_cell['break_even_min']:.1f} | {ratio} |")
    rou = report["roulette"]
    lines += ["", "## Roulette (category model)", "",
              f"{rou['label']}. Values per category: " + ", ".join(f"{k} {v}" for k, v in rou["values"].items()) + ".", "",
              f"- Esencia category share (from Balance roulette.weights): {rou['esencia_share'] * 100:.1f}%.",
              f"- EV per spin: {rou['ev']:.1f} Esencia-equivalent against a spin cost of {rou['spin_cost']}.",
              f"- Break-even Esencia prize value (other categories as above): {rou['break_even_esencia_value']:.1f}.",
              f"- Break-even with every other category at 0: {rou['esencia_only_break_even']:.1f}.",
              f"- infinite_money_risk: {rou['infinite_money_risk']}.",
              f"- Only Esencia (or a prize sold back for Esencia) can pay the next spin: counting the esencia category "
              f"alone, EV is {rou['esencia_only_ev']:.1f} per spin.",
              "- No pity and no hub vs base distinction: both are T09a.",
              "", "## Farm slots", "",
              ", ".join(f"slot {k}: {v}" for k, v in report["farm_slot_costs"].items()) + ".",
              "", "## Mirrored values and drift", "",
              "Each value is re-read from its source by pattern (no line numbers are tracked).", ""]
    for name, entry in report["mirrored"].items():
        lines.append(f"- `{name}` = {entry['value']} ({entry['source']})")
    lines.append(f"- Drift: {'none' if not report['drift'] else '; '.join(report['drift'])}")
    lines += ["", "## ASSUMED fields", ""]
    seen = set()
    for a in report["assumptions"]:
        key = (a["field"], a.get("profile"))
        if key in seen:
            continue
        seen.add(key)
        who = f" ({a['profile']})" if a.get("profile") else ""
        label = f" ({a['label']})" if a.get("label") and a["field"] == "farm_mode" else ""
        lines.append(f"- `{a['field']}`{who}: {a['value']}{label}")
    lines += ["", "## Simplifications", "",
              "- Losses are rolled once per trip at a combined beast + PvP + bat rate, not from the Beast Director's 20 s ticks.",
              "- PvP and bat drop rates are invented; nothing in the code defines them.",
              "- The egg price uses the live eggEmberByTier through the SpawnClock REWARD map (ASSUMED).",
              "- `fresh` farm mode treats every session as a fresh account, which biases toward selling: the farm is "
              "worth nothing after the session. `carry` is the steady-state counterpart; neither carries upgrade levels.",
              "- WildboundBalance is `wired=false`: these results describe the proposed 2.0 economy, not the live game.",
              "- The treadmill walk 17-21 conflicts with Q9 (walk 16) and the live WALK_CAP 16; the model uses the proposed speeds.",
              "- No day/night, no material gathering, no consumables, no portals.", ""]
    return "\n".join(lines)


def render_json(report):
    return json.dumps(report, indent=2, sort_keys=True, default=str)


# ---- CLI --------------------------------------------------------------------------------------------
def main(argv=None):
    parser = argparse.ArgumentParser(description="Wildbound 2.0 economy simulator (T05b). A model, not measured data.")
    parser.add_argument("--profile", default="all")
    parser.add_argument("--minutes", default="10,30,60")
    parser.add_argument("--seed", type=int, default=7)
    parser.add_argument("--runs", type=int, default=200)
    parser.add_argument("--source", choices=("live", "doc"), default="live")
    parser.add_argument("--balance", choices=("proposed", "live"), default="proposed")
    parser.add_argument("--roulette-policy", choices=("free", "spend"), default="free")
    parser.add_argument("--roulette-values")
    parser.add_argument("--farm-mode", choices=FARM_MODES + ("both",), default="fresh",
                        help="fresh: every session is a new account (ASSUMED); carry: pre-filled farm; both")
    parser.add_argument("--profile-file")
    parser.add_argument("--json")
    parser.add_argument("--md", action="store_true", help="print the markdown report")
    args = parser.parse_args(argv)
    numbers = load_numbers(source=args.source, balance=args.balance)
    profiles = load_profile_file(args.profile_file) if args.profile_file else default_profiles()
    if args.profile != "all":
        profiles = {k: v for k, v in profiles.items() if k in args.profile.split(",")}
        if not profiles:
            parser.error(f"unknown profile {args.profile!r}")
    values = json.loads(Path(args.roulette_values).read_text(encoding="utf-8")) if args.roulette_values else None
    minutes = [int(m) for m in args.minutes.split(",")]
    modes = FARM_MODES if args.farm_mode == "both" else (args.farm_mode,)
    report = run_all(numbers, profiles, minutes, args.seed, args.runs, args.roulette_policy, values, modes)
    if args.json:
        Path(args.json).write_text(render_json(report), encoding="utf-8")
    if args.md or not args.json:
        command = ("python -I -B tools/wildbound_economy_sim_v2.py " + " ".join(argv if argv is not None else sys.argv[1:])).strip()
        text = render_md(report, command)
        buffer = getattr(sys.stdout, "buffer", None)
        if buffer is not None:  # LF bytes on every platform, so a rerun is byte-identical to the committed report
            sys.stdout.flush()
            buffer.write(text.encode("utf-8"))
            buffer.flush()
        else:
            sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
