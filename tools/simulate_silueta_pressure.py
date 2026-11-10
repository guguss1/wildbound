"""Silueta pressure simulator: how long can a still player stay at an objective?

For each objective (nest, Lumipol marker, capture and egg spots from the capture
document) this answers: if a player stands perfectly still, how long until
Silueta has detected them, walked up and struck, by day and by night, across
every patrol phase it could be in when the player arrived.

It models GEOMETRY AND TIMING ONLY. It says nothing about fun or balance.

What is modelled (all constants are parsed from the sources, never copied):
  * attack range, telegraph, leash, fog rectangle and safe circles from
    src/wildbound/WildboundWorldRules.luau;
  * since delivery C, detection range and chase speed by day and by night, and
    the Day alert time, patrol speed and chase limit, from the profiles in
    src/wildbound/WildboundGuardianBrain.luau (the world script reads them);
  * patrol waypoints and the 0.2 s step from src/wildbound/WildboundWorld.server.luau;
  * the layout JSON is cross-checked against both and must agree;
  * capture and egg coordinates and CALM_REQUIRED from the capture document;
  * the Lumipol marker from tools/build-wildbound-p0-map.luau.
Any parse failure or disagreement raises and exits non-zero.

What is NOT modelled:
  * routing around the solid trunk cores (delivery C2: the server follows
    PathfindingService routes, so real approaches are longer than the straight
    line used here, which is the worst case for the player);
  * Night's own patrol speed, alert time and chase limit (the Day values are
    used for both phases; Night only changes speed and detection here);
  * suspicion, capture noise and searching (delivery C1);
  * line of sight: in play trunks block acquisition, so detection here is the
    worst case for the player;
  * the 60 Hz Heartbeat granularity of the 0.2 s step (real steps are 0.2 s to
    about 0.217 s, which would only make strikes slightly later), players
    moving, several players, the Y-difference check, and the 1 Hz snapshot lag
    in what a player can see.

Usage (from the project root):

    python -I -B tools/simulate_silueta_pressure.py [--phases N]
"""

import argparse
import json
import math
import re
import sys
from collections import namedtuple
from dataclasses import dataclass
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
RULES_PATH = "src/wildbound/WildboundWorldRules.luau"
SERVER_PATH = "src/wildbound/WildboundWorld.server.luau"
BRAIN_PATH = "src/wildbound/WildboundGuardianBrain.luau"
LAYOUT_PATH = "assets/maps/forest-layout/forest-layout-v1.json"
CAPTURE_PATH = "docs/mechanics/wildbound-capture.md"
BUILDER_PATH = "tools/build-wildbound-p0-map.luau"

EPS = 1e-9
HOLDS = (4.0, None, 6.0)  # None stands for CALM_REQUIRED, parsed from the capture document
NUM = r"(-?\d+(?:\.\d+)?)"


class ParseError(Exception):
    """A source no longer has the shape this tool depends on."""


class ConsistencyError(Exception):
    """Two sources that must agree do not."""


Model = namedtuple("Model", "step_s patrol_speed alert_s telegraph_s attack_range max_chase_s")
Speeds = namedtuple("Speeds", "speed detection_range")
Result = namedtuple("Result", "reason detect_s telegraph_s strike_s detect_distance")
Spot = namedtuple("Spot", "slot x z doc_share")
Objective = namedtuple("Objective", "name x z doc_share")


@dataclass
class World:
    home_x: float
    home_z: float
    leash: float
    fog: tuple
    safe: list
    patrol: list
    day: Speeds
    night: Speeds
    model: Model
    objectives: list
    calm_required: float


# ---- Parsing --------------------------------------------------------------
def _number(text):
    value = float(text)
    return int(value) if value == int(value) and "." not in text else value


def parse_rules(text):
    """Constants from WildboundWorldRules.luau. Raises ParseError if any is missing."""
    out = {}
    for name in ("TELEGRAPH_SECONDS", "ATTACK_COOLDOWN", "ATTACK_RANGE", "HOME_LEASH",
                 "CHASE_RANGE", "MAX_CHASE_SECONDS"):
        found = re.search(rf"^Rules\.{name} = {NUM}\s*$", text, re.M)
        if not found:
            raise ParseError(f"{RULES_PATH}: constant Rules.{name} not found")
        out[name] = _number(found.group(1))
    home = re.search(rf"^Rules\.HOME_X, Rules\.HOME_Z = {NUM}, {NUM}\s*$", text, re.M)
    if not home:
        raise ParseError(f"{RULES_PATH}: Rules.HOME_X, Rules.HOME_Z not found")
    out["HOME_X"], out["HOME_Z"] = _number(home.group(1)), _number(home.group(2))
    fog = re.search(rf"x >= {NUM} and x <= {NUM} and z >= {NUM} and z <= {NUM}", text)
    if not fog:
        raise ParseError(f"{RULES_PATH}: fog rectangle in Rules.zone not found")
    out["FOG"] = tuple(_number(g) for g in fog.groups())
    circles = re.findall(rf"Rules\.distance\(x, z, {NUM}, {NUM}\) <= {NUM}", text)
    if len(circles) != 2:
        raise ParseError(f"{RULES_PATH}: expected 2 safe circles in Rules.zone, found {len(circles)}")
    out["SAFE"] = [tuple(_number(v) for v in c) for c in circles]
    base = re.search(rf"base = table\.freeze\(\{{ speed = {NUM}, detectionRange = {NUM} \}}\)", text)
    night = re.search(
        rf'night = table\.freeze\(\{{ scope = "(\w+)", speed = {NUM}, detectionRange = {NUM} \}}\)', text)
    if not base or not night:
        raise ParseError(f"{RULES_PATH}: Silueta base/night profile not found")
    if night.group(1) != "Fog":
        raise ParseError(f"{RULES_PATH}: night scope is {night.group(1)!r}, this model assumes 'Fog'")
    if 'phase == "Night"' not in text:
        raise ParseError(f"{RULES_PATH}: night profile is no longer selected by phase == \"Night\"")
    out["BASE"] = Speeds(_number(base.group(1)), _number(base.group(2)))
    out["NIGHT"] = Speeds(_number(night.group(2)), _number(night.group(3)))
    return out


STEERING_CHECKS = (
    # Fix pass (FP2): every hunter is `h`; the patterns name it.
    ("steering", r"navigate\(h, decision\.destination, parameters\.speed, dt",
     "Hunt steering no longer moves at parameters.speed"),
    ("hunt profile", r"local parameters = \{ speed = profile\.hunt, detectionRange = profile\.detection \}",
     "hunt speed and detection no longer come from the brain profile"),
    ("telegraph", r"telegraphEndsAt = now \+ Rules\.TELEGRAPH_SECONDS",
     "telegraph length is no longer Rules.TELEGRAPH_SECONDS"),
    ("attack trigger", r"candidate\.distance <= Rules\.ATTACK_RANGE",
     "telegraph is no longer started by Rules.ATTACK_RANGE"),
    ("chase limit", r"Brain\.chaseExpired\(chaseStartedAt, now, phase\)",
     "chase limit is no longer the brain profile's chaseSeconds"),
    ("alert", r"alertEndsAt = now \+ Brain\.engage\(brain, now, phase\)",
     "alert time is no longer the brain profile's alertSeconds"),
    ("patrol speed", r"navigate\(h, patrol\[patrolIndex\], profile\.patrol, dt, now\)",
     "patrol speed is no longer the brain profile's patrol speed"),
)


def parse_server(text):
    """Patrol waypoints and step from the server script; the steering checks pin where speeds come from."""
    out = {}
    patterns = {
        "STEP": rf"if accumulator >= {NUM} then",
    }
    for key, pattern in patterns.items():
        found = re.search(pattern, text)
        if not found:
            raise ParseError(f"{SERVER_PATH}: {key} pattern not found ({pattern})")
        out[key] = float(found.group(1))
    block = re.search(r"local patrol = \{(.*?)\n\}", text, re.S)
    offsets = re.findall(rf"home \+ Vector3\.new\({NUM}, 0, {NUM}\)", block.group(1)) if block else []
    if len(offsets) != 4:
        raise ParseError(f"{SERVER_PATH}: expected 4 patrol waypoints, found {len(offsets)}")
    out["PATROL_OFFSETS"] = [(float(a), float(b)) for a, b in offsets]
    for label, pattern, message in STEERING_CHECKS:
        if not re.search(pattern, text):
            raise ParseError(f"{SERVER_PATH}: {label} assumption broken: {message}")
    return out


def parse_capture(text):
    """Coordinate rows of the capture document (spawn slots and egg slots)."""
    spots, seen = [], {}
    row = re.compile(rf"^\|\s*`([A-Za-z0-9_]+)`\s*\|\s*\({NUM},\s*{NUM}\)\s*\|(.*)$", re.M)
    for match in row.finditer(text):
        slot, x, z, rest = match.group(1), float(match.group(2)), float(match.group(3)), match.group(4)
        share = re.search(r"\|\s*(\d+)%?\s*/\s*(\d+)%?", "|" + rest)
        doc_share = (int(share.group(1)) / 100.0, int(share.group(2)) / 100.0) if share else None
        if slot in seen and seen[slot] != (x, z):
            raise ParseError(f"{CAPTURE_PATH}: slot {slot} has two different coordinates")
        if slot not in seen:
            seen[slot] = (x, z)
            spots.append(Spot(slot, x, z, doc_share))
    if not spots:
        raise ParseError(f"{CAPTURE_PATH}: no coordinate rows like | `L1` | (x, z) | found")
    return spots


def parse_calm_required(text):
    found = re.search(r"`CALM_REQUIRED`\s*\|\s*(\d+(?:\.\d+)?)\s*s", text)
    if not found:
        raise ParseError(f"{CAPTURE_PATH}: CALM_REQUIRED row not found")
    return float(found.group(1))


def parse_lumipol_marker(text):
    found = re.search(rf"addMarker\(markers, 'LumipolMarker', {NUM}, {NUM}\)", text)
    if not found:
        raise ParseError(f"{BUILDER_PATH}: LumipolMarker not found")
    return float(found.group(1)), float(found.group(2))


PROFILE_KEYS = ("patrol", "hunt", "chaseSeconds", "alertSeconds", "detection")


def parse_brain(text):
    """Day and Night profiles from WildboundGuardianBrain.luau. Raises ParseError if any is missing."""
    out = {}
    for name, pattern in (("Day", r"local DAY = \{(.*?)\}"), ("Night", r"\bNight = \{(.*?)\}")):
        block = re.search(pattern, text, re.S)
        if not block:
            raise ParseError(f"{BRAIN_PATH}: {name} profile not found")
        values = {}
        for key in PROFILE_KEYS:
            found = re.search(rf"\b{key} = {NUM}", block.group(1))
            if not found:
                raise ParseError(f"{BRAIN_PATH}: {name}.{key} not found")
            values[key] = float(found.group(1))
        out[name] = values
    return out


def build_world(rules_text, server_text, layout, capture_text, builder_text, brain_text=None):
    rules = parse_rules(rules_text)
    server = parse_server(server_text)
    if brain_text is None:
        try:
            brain_text = (REPO / BRAIN_PATH).read_text(encoding="utf-8")
        except OSError as error:
            raise ParseError(f"cannot read {BRAIN_PATH}: {error}") from error
    brain = parse_brain(brain_text)
    day_profile, night_profile = brain["Day"], brain["Night"]
    spots = parse_capture(capture_text)
    calm = parse_calm_required(capture_text)
    marker = parse_lumipol_marker(builder_text)

    home = (float(rules["HOME_X"]), float(rules["HOME_Z"]))
    patrol = [(home[0] + dx, home[1] + dz) for dx, dz in server["PATROL_OFFSETS"]]
    fog = tuple(float(v) for v in rules["FOG"])
    safe = [(float(x), float(z), float(r)) for x, z, r in rules["SAFE"]]

    # The layout JSON was generated independently; it must still describe the same world.
    problems = []
    try:
        guardian, circles = layout["inputs"]["guardian"], layout["inputs"]["safe_circles"]
        if tuple(guardian["home"]) != home:
            problems.append(f"home: rules {home} vs layout {tuple(guardian['home'])}")
        if float(guardian["leash"]) != float(rules["HOME_LEASH"]):
            problems.append(f"leash: rules {rules['HOME_LEASH']} vs layout {guardian['leash']}")
        zone = guardian["fog_zone"]
        layout_fog = (zone["x"][0], zone["x"][1], zone["z"][0], zone["z"][1])
        if tuple(float(v) for v in layout_fog) != fog:
            problems.append(f"fog zone: rules {fog} vs layout {layout_fog}")
        layout_patrol = [tuple(guardian["patrol_loop"][k]) for k in ("E", "S", "W", "N")]
        if layout_patrol != patrol:
            problems.append(f"patrol: server {patrol} vs layout {layout_patrol}")
        layout_safe = sorted((c["centre"][0], c["centre"][1], c["r"]) for c in circles.values())
        if layout_safe != sorted(safe):
            problems.append(f"safe circles: rules {sorted(safe)} vs layout {layout_safe}")
        nest, old_nest = tuple(layout["inputs"]["new_nest"]), tuple(layout["inputs"]["old_nest"])
    except (KeyError, TypeError, IndexError) as error:
        raise ParseError(f"{LAYOUT_PATH}: expected structure missing ({error!r})") from error
    if problems:
        raise ConsistencyError("; ".join(problems))

    model = Model(server["STEP"], day_profile["patrol"], day_profile["alertSeconds"],
                  float(rules["TELEGRAPH_SECONDS"]), float(rules["ATTACK_RANGE"]),
                  day_profile["chaseSeconds"])
    objectives = [
        Objective("nest", float(nest[0]), float(nest[1]), None),
        Objective("old nest", float(old_nest[0]), float(old_nest[1]), None),
        Objective("lumipol marker", marker[0], marker[1], None),
    ] + [Objective("capture " + s.slot, s.x, s.z, s.doc_share) for s in spots]
    return World(home[0], home[1], float(rules["HOME_LEASH"]), fog, safe, patrol,
                 Speeds(day_profile["hunt"], day_profile["detection"]),
                 Speeds(night_profile["hunt"], night_profile["detection"]),
                 model, objectives, calm)


def load_world(repo=REPO):
    repo = Path(repo)

    def read(rel):
        try:
            return (repo / rel).read_text(encoding="utf-8")
        except OSError as error:
            raise ParseError(f"cannot read {rel}: {error}") from error

    layout = json.loads(read(LAYOUT_PATH))
    return build_world(read(RULES_PATH), read(SERVER_PATH), layout, read(CAPTURE_PATH), read(BUILDER_PATH),
                       read(BRAIN_PATH))


# ---- Geometry -------------------------------------------------------------
def zone_of(world, x, z):
    """'safe', 'territory' (Silueta can target), 'fog' (fog but beyond the leash) or 'outside'."""
    for cx, cz, r in world.safe:
        if math.hypot(x - cx, z - cz) <= r:
            return "safe"
    x0, x1, z0, z1 = world.fog
    if not (x0 <= x <= x1 and z0 <= z <= z1):
        return "outside"
    if math.hypot(x - world.home_x, z - world.home_z) <= world.leash:
        return "territory"
    return "fog"


def _edges(waypoints):
    count = len(waypoints)
    for i in range(count):
        a, b = waypoints[i], waypoints[(i + 1) % count]
        length = math.hypot(b[0] - a[0], b[1] - a[1])
        if length > 0:
            yield a, b, length


def loop_length(waypoints):
    return sum(length for _, _, length in _edges(waypoints))


def patrol_position(waypoints, distance):
    """Position after walking `distance` studs along the closed patrol loop from waypoint 0."""
    total = loop_length(waypoints)
    if total == 0:
        return float(waypoints[0][0]), float(waypoints[0][1])
    left = distance % total
    last = None
    for a, b, length in _edges(waypoints):
        last = (a, b, length)
        if left <= length:
            t = left / length
            return a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t
        left -= length
    a, b, _ = last
    return float(b[0]), float(b[1])


def patrol_share(waypoints, player, radius):
    """Exact share of the patrol loop that lies within `radius` of `player`."""
    total = loop_length(waypoints)
    if total == 0:
        return 1.0 if math.hypot(waypoints[0][0] - player[0], waypoints[0][1] - player[1]) <= radius + EPS else 0.0
    covered = 0.0
    r2 = (radius + EPS) ** 2
    for a, b, length in _edges(waypoints):
        dx, dz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        wx, wz = a[0] - player[0], a[1] - player[1]
        half = wx * dx + wz * dz                    # t^2 + 2*half*t + c <= 0
        c = wx * wx + wz * wz - r2
        disc = half * half - c
        if disc < 0:
            continue
        root = math.sqrt(disc)
        lo, hi = max(0.0, -half - root), min(length, -half + root)
        if hi > lo:
            covered += hi - lo
    return covered / total


# ---- Simulation -----------------------------------------------------------
def _ticks(seconds, step):
    return int(math.ceil(seconds / step - EPS))


def simulate_stationary(model, waypoints, player, phase, chase_speed, detection_range):
    """One still player against one patrol phase, tick by tick as the server steps.

    Tick 0 is the moment the player stops. Patrol: the guardian walks its loop at
    `patrol_speed`; the first tick with the player inside `detection_range` sets
    Alert (no movement that tick). Alert holds still, flips to Hunt on the tick
    at `alert_s`, and Hunt acts from the next tick: a straight move of
    chase_speed*step per tick until within `attack_range`, whose tick sets
    Telegraph; the strike resolves on the tick `telegraph_s` later. Chase limit
    cancels everything once `max_chase_s` has passed since detection.
    """
    step = model.step_s
    total = loop_length(waypoints)
    horizon = 1 if (model.patrol_speed <= 0 or total == 0) else _ticks(total / (model.patrol_speed * step), 1) + 2
    for j in range(horizon):
        gx, gz = patrol_position(waypoints, phase + model.patrol_speed * step * j)
        distance = math.hypot(player[0] - gx, player[1] - gz)
        if distance > detection_range + EPS:
            continue
        need = distance - model.attack_range
        walk = 0 if need <= EPS else _ticks(need / (chase_speed * step), 1)
        hunt_tick = j + _ticks(model.alert_s, step) + 1
        telegraph_tick = hunt_tick + walk
        strike_tick = telegraph_tick + _ticks(model.telegraph_s, step)
        detect_s = j * step
        telegraph_s = telegraph_tick * step
        if (strike_tick - j) * step >= model.max_chase_s - EPS:
            return Result("chase_timeout", detect_s, telegraph_s, None, distance)
        return Result("strike", detect_s, telegraph_s, strike_tick * step, distance)
    return Result("never_detected", None, None, None, None)


@dataclass
class Sweep:
    results: list
    share_detected: float
    share_struck: float
    share_never: float
    strike_min: object
    strike_median: object
    strike_max: object
    detect_min: object


def sweep(model, waypoints, player, chase_speed, detection_range, phases):
    total = loop_length(waypoints)
    results = [simulate_stationary(model, waypoints, player, total * i / phases, chase_speed, detection_range)
               for i in range(phases)]
    strikes = sorted(r.strike_s for r in results if r.strike_s is not None)
    detects = [r.detect_s for r in results if r.detect_s is not None]
    n = float(len(results))
    return Sweep(
        results=results,
        share_detected=sum(r.reason != "never_detected" for r in results) / n,
        share_struck=len(strikes) / n,
        share_never=sum(r.reason == "never_detected" for r in results) / n,
        strike_min=strikes[0] if strikes else None,
        strike_median=strikes[len(strikes) // 2] if strikes else None,
        strike_max=strikes[-1] if strikes else None,
        detect_min=min(detects) if detects else None,
    )


def exposure(result_sweep, hold):
    """(share warned, share struck) for a player who stays still for `hold` seconds."""
    n = float(len(result_sweep.results))
    warned = sum(r.detect_s is not None and r.detect_s <= hold + EPS for r in result_sweep.results)
    struck = sum(r.strike_s is not None and r.strike_s <= hold + EPS for r in result_sweep.results)
    return warned / n, struck / n


@dataclass
class Analysis:
    name: str
    x: float
    z: float
    zone: str
    home_distance: float
    targetable: bool
    share_day: float
    share_night: float
    doc_share: object
    day: object
    night: object


def analyse(world, objective, phases):
    zone = zone_of(world, objective.x, objective.z)
    player = (objective.x, objective.z)
    home_distance = math.hypot(objective.x - world.home_x, objective.z - world.home_z)
    share_day = patrol_share(world.patrol, player, world.day.detection_range)
    share_night = patrol_share(world.patrol, player, world.night.detection_range)
    targetable = zone == "territory"
    day = night = None
    if targetable:
        day = sweep(world.model, world.patrol, player, world.day.speed, world.day.detection_range, phases)
        night = sweep(world.model, world.patrol, player, world.night.speed, world.night.detection_range, phases)
    return Analysis(objective.name, objective.x, objective.z, zone, home_distance, targetable,
                    share_day, share_night, objective.doc_share, day, night)


# ---- Report ---------------------------------------------------------------
def _pct(value):
    return f"{100 * value:5.1f}%"


def _secs(value):
    return "    -" if value is None else f"{value:5.1f}"


def _doc_check(analysis):
    if analysis.doc_share is None:
        return ""
    day, night = analysis.doc_share
    ok = abs(analysis.share_day - day) <= 0.01 and abs(analysis.share_night - night) <= 0.01
    text = f"doc {100 * day:.0f}%/{100 * night:.0f}%"
    return text + (" ok" if ok else " MISMATCH")


HEADER = """\
SILUETA PRESSURE (stationary player) - geometry only
This models geometry and timing only. It says nothing about fun or balance.
Straight-line steering as in the server source. NOT modelled: trunks or props stopping
steering, line of sight (trunks block acquisition in play, so detection here is the worst
case for the player), moving players, several players, 60 Hz step jitter (real steps are
0.2 s to about 0.217 s, so real strikes are slightly later), snapshot lag.
Assumes Silueta is on patrol with its attack cooldown ready when the player stops, and
that the player arrives at a uniformly random patrol phase. 'Day' also covers Dusk and
Dawn (base stats); 'Night' uses the fog night stats."""


def render(world, phases):
    analyses = [analyse(world, o, phases) for o in world.objectives]
    holds = [world.calm_required if h is None else h for h in HOLDS]
    m, d, n = world.model, world.day, world.night
    lines = [HEADER, "",
             f"Parsed: home ({world.home_x:g}, {world.home_z:g}) leash {world.leash:g}; "
             f"day speed {d.speed:g} range {d.detection_range:g}; night speed {n.speed:g} range {n.detection_range:g}; "
             f"attack range {m.attack_range:g}; alert {m.alert_s:g} s; telegraph {m.telegraph_s:g} s; "
             f"chase limit {m.max_chase_s:g} s; patrol {m.patrol_speed:g} studs/s, loop {loop_length(world.patrol):.1f} studs "
             f"({loop_length(world.patrol) / m.patrol_speed:.1f} s); step {m.step_s:g} s; "
             f"{phases} patrol phases per case.", "",
             "1. Reach: zone, distance from home, share of the patrol loop within detection range",
             f"{'objective':<20}{'x':>6}{'z':>6}  {'zone':<10}{'home':>6}  {'day':>6} {'night':>6}  doc check"]
    for a in analyses:
        lines.append(f"{a.name:<20}{a.x:6g}{a.z:6g}  {a.zone:<10}{a.home_distance:6.1f}  "
                     f"{_pct(a.share_day)} {_pct(a.share_night)}  {_doc_check(a)}")
    lines += ["", "2. Seconds a still player has, from stopping to the strike landing "
                  "(targetable objectives only; 'never' = no patrol phase ever detects)",
              f"{'objective':<20}{'time':<6}{'detected':>9}{'never':>7}{'first warn':>11}{'min':>6}{'median':>7}{'max':>6}"]
    for a in analyses:
        if not a.targetable:
            continue
        for label, s in (("day", a.day), ("night", a.night)):
            lines.append(f"{a.name:<20}{label:<6}{_pct(s.share_detected):>9}{_pct(s.share_never):>7}"
                         f"{_secs(s.detect_min):>11}{_secs(s.strike_min):>6}{_secs(s.strike_median):>7}{_secs(s.strike_max):>6}")
    lines += ["", "3. Capture hold: share of patrol phases in which a still player is warned (Alert begins) /"
                  " struck (impact lands) before the hold ends"]
    lines.append(f"{'objective':<20}{'time':<6}" + "".join(f"{'hold ' + format(h, 'g') + ' s':>20}" for h in holds))
    verdicts = []
    for a in analyses:
        if not a.targetable:
            verdicts.append(f"  {a.name:<20} not targetable ({a.zone}): Silueta cannot target a player here, hold or not")
            continue
        worst = {}
        for label, s in (("day", a.day), ("night", a.night)):
            cells = []
            for h in holds:
                warned, struck = exposure(s, h)
                cells.append(f"{_pct(warned)} / {_pct(struck)}")
                worst[(label, h)] = (warned, struck)
            lines.append(f"{a.name:<20}{label:<6}" + "".join(f"{c:>20}" for c in cells))
        top = max(holds)
        for h in (holds[1],):
            struck = {label: worst[(label, h)][1] for label in ("day", "night")}
            warned = {label: worst[(label, h)][0] for label in ("day", "night")}
            if max(struck.values()) > 0:
                verdicts.append(f"  {a.name:<20} hold {h:g} s EXPOSES the player: struck in "
                                f"{100 * struck['day']:.1f}% (day) / {100 * struck['night']:.1f}% (night) of phases")
            elif max(warned.values()) > 0:
                verdicts.append(f"  {a.name:<20} hold {h:g} s warns only: Alert begins in "
                                f"{100 * warned['day']:.1f}% (day) / {100 * warned['night']:.1f}% (night) of phases, "
                                f"no strike lands (hold {top:g} s: struck "
                                f"{100 * worst[('day', top)][1]:.1f}% / {100 * worst[('night', top)][1]:.1f}%)")
            else:
                verdicts.append(f"  {a.name:<20} hold {h:g} s: no warning and no strike in any phase "
                                f"(hold {top:g} s: struck {100 * worst[('day', top)][1]:.1f}% / "
                                f"{100 * worst[('night', top)][1]:.1f}%)")
    lines += ["", f"4. Verdict at CALM_REQUIRED = {world.calm_required:g} s (hold {world.calm_required:g} "
                  "is the capture meter target; real captures run about 4.7 to 6 s)"] + verdicts
    return "\n".join(lines) + "\n"


def main(argv=None):
    parser = argparse.ArgumentParser(description="Silueta pressure simulator (geometry only).")
    parser.add_argument("--phases", type=int, default=720, help="patrol phases sampled per case (default 720)")
    parser.add_argument("--repo", default=str(REPO), help="repository root")
    args = parser.parse_args(argv)
    if args.phases < 1:
        parser.error("--phases must be at least 1")
    try:
        world = load_world(args.repo)
    except (ParseError, ConsistencyError) as error:
        print(f"ERROR: {type(error).__name__}: {error}", file=sys.stderr)
        return 2
    sys.stdout.write(render(world, args.phases))
    return 0


if __name__ == "__main__":
    sys.exit(main())
