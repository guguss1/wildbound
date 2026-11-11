"""Spawn graph for the random world (plan Part 3, task RW1).

Every place an egg or a cria may appear on the forest map, read from the existing layouts so the points follow the
trees, logs, ruins, relief and trail that are really there:

- `treeBase`: beside each standing trunk (just outside its solid core, on the side facing the map centre);
- `canopy`: an evergreen's low bough (height tagged; the prompt reaches it from the ground);
- `root`: the two legs of the root arch; `log`: beside each fallen log; `rock`: the ruin doorway legs, the four
  ruin pillars and the crests of the long ridges;
- `nest`: the five island nests, kept as guaranteed points so their parents still guard them;
- `trail`: both edges of the route, every 24 studs.

Each point carries `distanceToHome` (La Silueta's home, (0, -85)), `zone` (the zone rule of WildboundWorldRules:
territory, fog or outside), `tier` (Comun beyond 120, Rara 80 to 120, Epica 45 to 80, Legendaria under 45), the
relief `ground` height and `height` above it. No point lies inside the camp or shelter circles; wild points stay off
island floors and out of trunk cores. `refugeCandidates` are trail and rock points well outside the territory, 35
studs apart, for the random Refugios (RW4).

    python -I -B tools/plan_spawn_graph.py            # prints JSON, writes nothing
    python -I -B tools/plan_spawn_graph.py --write    # writes spawn-graph-v1.json and src/wildbound/WildboundSpawnGraph.luau
"""

import argparse
import json
import math
import sys
from pathlib import Path

_HERE = str(Path(__file__).resolve().parent)
if _HERE not in sys.path:  # `python -I` does not put the script folder on the path
    sys.path.insert(0, _HERE)

import plan_relief as relief_rule  # noqa: E402  (the one height rule, mirrored in WildboundRelief.luau)

REPO = Path(__file__).resolve().parent.parent
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
ISLANDS = REPO / "assets/maps/forest-layout/islands-v1.json"
RELIEF = REPO / "assets/maps/forest-layout/relief-v1.json"
OUTPUT = REPO / "assets/maps/forest-layout/spawn-graph-v1.json"
LUAU = REPO / "src/wildbound/WildboundSpawnGraph.luau"

HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)
SAFE = (((-140.0, 140.0), 35.0), ((105.0, 125.0), 22.0))
SAFE_MARGIN = 3.0
SPAWN_PAD, SPAWN_PAD_RADIUS = (0.0, 0.0), 9.0
CORE = {"FK_Evergreen": 2.5 * 1.6, "FK_DeadTree": 3.4 * 1.4}  # trunk core per unit scale, grown (DP6)
BASE_GAP = 1.5  # a tree base point sits this far outside its own core
CORE_CLEAR = 1.0  # and at least this far from any other core
CANOPY_HEIGHT = 6.0  # a low bough the 10-stud prompt reaches from the ground
ISLAND_MARGIN = 3.0
LIMIT = 190.0
MAX_SLOPE = 30.0
POOL = (112.0, 144.0, 3.0, 27.0)  # MarshPool, xmin xmax zmin zmax
TRAIL_STEP, TRAIL_OFFSET = 24.0, 9.0  # route width 14: 2 studs past the edge
ROUTE = ((-140.0, 140.0), (-95.0, 75.0), (0.0, -85.0), (35.0, -99.0), (115.0, 15.0), (105.0, 125.0))
REFUGE_HOME_MIN = LEASH + 15.0
REFUGE_SAFE_GAP = 10.0
REFUGE_SPACING = 35.0
TIER_BANDS = (("Legendaria", 45.0), ("Epica", 80.0), ("Rara", 120.0))


def zone(x, z):
    x0, x1, z0, z1 = FOG
    if not (x0 <= x <= x1 and z0 <= z <= z1):
        return "outside"
    return "territory" if math.dist((x, z), HOME) <= LEASH else "fog"


def tier(distance):
    for name, upper in TIER_BANDS:
        if distance < upper or (name == "Rara" and distance <= upper):
            return name
    return "Comun"


def _rotate(local_x, local_z, degrees):
    r = math.radians(degrees)
    return local_x * math.cos(r) + local_z * math.sin(r), -local_x * math.sin(r) + local_z * math.cos(r)


def plan(layout, islands, relief):
    segments = relief["segments"]
    removed = set(relief["removedTrees"]) | set(islands["removedTrees"])
    instances = [i for i in layout["instances"] if i["id"] not in removed]
    trees = [(i, CORE[i["name"]] * i["scale"]) for i in instances if i["name"] in CORE]
    floors = [(tuple(i["centre"]), i["floorRadius"]) for i in islands["islands"]]
    pillars = [tuple(p) for p in layout["inputs"]["pillars"]]

    def clear_of_cores(x, z):
        return all(math.dist((x, z), (t["x"], t["z"])) - core >= CORE_CLEAR for t, core in trees)

    def allowed(x, z, wild=True, trunk=True):
        if abs(x) > LIMIT or abs(z) > LIMIT:
            return False
        if any(math.dist((x, z), c) <= r + SAFE_MARGIN for c, r in SAFE):
            return False
        if math.dist((x, z), SPAWN_PAD) <= SPAWN_PAD_RADIUS:
            return False
        if POOL[0] <= x <= POOL[1] and POOL[2] <= z <= POOL[3]:
            return False
        if wild and any(math.dist((x, z), c) <= r + ISLAND_MARGIN for c, r in floors):
            return False
        if trunk and not clear_of_cores(x, z):
            return False
        return relief_rule.slope_deg(segments, x, z) <= MAX_SLOPE

    raw = []

    def add(kind, x, z, height=0.0, source=None, **extra):
        raw.append({"kind": kind, "x": round(x, 2), "z": round(z, 2), "height": height, "source": source, **extra})

    for t, core in trees:
        # The side of the trunk facing the map centre, so the point reads from the trail more often than not.
        dx, dz = -t["x"], -t["z"]
        length = math.hypot(dx, dz) or 1.0
        for turn in (0, 60, -60, 120, -120, 180):
            ux, uz = _rotate(dx / length, dz / length, turn)
            x, z = t["x"] + ux * (core + BASE_GAP), t["z"] + uz * (core + BASE_GAP)
            if allowed(x, z):
                add("treeBase", x, z, source=t["id"])
                if t["name"] == "FK_Evergreen":
                    add("canopy", x, z, CANOPY_HEIGHT, source=t["id"])
                break
    for i in instances:
        if i["name"] == "FK_RootArch":
            for side in (-12.0, 12.0):
                lx, lz = _rotate(side, 0.0, i["rotation_y_deg"])
                if allowed(i["x"] + lx, i["z"] + lz):
                    add("root", i["x"] + lx, i["z"] + lz, source=i["id"])
        elif i["name"] == "FK_FallenLog":
            for side in (4.0, -4.0):
                lx, lz = _rotate(0.0, side * i["scale"], i["rotation_y_deg"])
                if allowed(i["x"] + lx, i["z"] + lz):
                    add("log", i["x"] + lx, i["z"] + lz, source=i["id"])
                    break
        elif i["name"] == "FK_RuinDoorway":
            for side in (-14.0, 14.0):
                lx, lz = _rotate(side, 3.0, i["rotation_y_deg"])
                if allowed(i["x"] + lx, i["z"] + lz):
                    add("rock", i["x"] + lx, i["z"] + lz, source=i["id"])
    for k, (px, pz) in enumerate(pillars):
        dx, dz = px - HOME[0], pz - HOME[1]
        length = math.hypot(dx, dz) or 1.0
        x, z = px + dx / length * 3.0, pz + dz / length * 3.0
        if allowed(x, z):
            add("rock", x, z, source=f"pillar-{k + 1}")
    for seg in segments:
        if seg.get("feature") in ("loma-larga", "cresta-vigia"):
            (ax, az), (bx, bz) = seg["a"], seg["b"]
            for t in (0.25, 0.75):
                x, z = ax + (bx - ax) * t, az + (bz - az) * t
                if allowed(x, z):
                    add("rock", x, z, source=seg["id"])
    for island in islands["islands"]:
        cx, cz = island["centre"]
        add("nest", cx, cz, source=island["id"], island=island["id"], guaranteed=True)
    legs = list(zip(ROUTE, ROUTE[1:]))
    for (ax, az), (bx, bz) in legs:
        length = math.dist((ax, az), (bx, bz))
        ux, uz = (bx - ax) / length, (bz - az) / length
        steps = int(length // TRAIL_STEP)
        for s in range(1, steps + 1):
            t = s * TRAIL_STEP
            side = 1 if s % 2 else -1
            x, z = ax + ux * t - uz * TRAIL_OFFSET * side, az + uz * t + ux * TRAIL_OFFSET * side
            if allowed(x, z):
                add("trail", x, z, source="route")

    points = []
    counters = {}
    for p in raw:
        prefix = {"treeBase": "T", "canopy": "C", "root": "R", "log": "L", "rock": "K", "nest": "N", "trail": "P"}[p["kind"]]
        counters[prefix] = counters.get(prefix, 0) + 1
        d = math.dist((p["x"], p["z"]), HOME)
        point = {
            "id": f"{prefix}{counters[prefix]:03d}", "kind": p["kind"], "x": p["x"], "z": p["z"],
            "ground": round(relief_rule.height_at(segments, p["x"], p["z"]), 2), "height": p["height"],
            "distanceToHome": round(d, 2), "zone": zone(p["x"], p["z"]), "tier": tier(d), "source": p["source"],
        }
        if p["kind"] == "nest":
            point["island"], point["guaranteed"] = p["island"], True
        points.append(point)

    refuges = []
    for p in points:
        if p["kind"] not in ("trail", "rock") or p["distanceToHome"] < REFUGE_HOME_MIN:
            continue
        if any(math.dist((p["x"], p["z"]), c) <= r + REFUGE_SAFE_GAP for c, r in SAFE):
            continue
        if all(math.dist((p["x"], p["z"]), (q["x"], q["z"])) >= REFUGE_SPACING for q in refuges):
            refuges.append({"id": p["id"], "x": p["x"], "z": p["z"], "ground": p["ground"]})

    counts = {}
    for p in points:
        counts.setdefault(p["tier"], 0)
        counts[p["tier"]] += 1
    return {
        "name": "spawn-graph-v1",
        "source": "tools/plan_spawn_graph.py; plan Part 3 (RW1)",
        "conventions": "studs, origin at the map centre, x east, z south; ground is the relief top, height is above it",
        "home": list(HOME),
        "tiers": {"Legendaria": "< 45", "Epica": "45 to 80", "Rara": "80 to 120", "Comun": "> 120"},
        "counts": dict(sorted(counts.items())),
        "points": points,
        "refugeCandidates": refuges,
    }


def luau(data):
    def num(value):
        value = float(value)
        return str(int(value)) if value == int(value) else repr(round(value, 2))

    lines = [
        "-- generated by tools/plan_spawn_graph.py from assets/maps/forest-layout/spawn-graph-v1.json; do not edit.",
        "-- Random world (plan Part 3, RW1): every point where an egg or a cria may appear, with its kind, relief",
        "-- ground, height above it, distance to La Silueta's home, zone and rarity tier; and the Refugio candidates.",
        "-- Pure data, read by the inventory server (spawn clock) and the world server (Refugios, biome event).",
        "local points, refuges = {}, {}",
        "local function p(id, kind, x, z, ground, height, distanceToHome, zone, tier, island)",
        "\ttable.insert(points, table.freeze({ id = id, kind = kind, x = x, z = z, ground = ground, height = height,",
        "\t\tdistanceToHome = distanceToHome, zone = zone, tier = tier, island = island, guaranteed = island ~= nil }))",
        "end",
        "local function r(id, x, z, ground)",
        "\ttable.insert(refuges, table.freeze({ id = id, x = x, z = z, ground = ground }))",
        "end",
    ]
    for q in data["points"]:
        island = f', "{q["island"]}"' if q.get("island") else ""
        lines.append(f'\tp("{q["id"]}", "{q["kind"]}", {num(q["x"])}, {num(q["z"])}, {num(q["ground"])}, '
                     f'{num(q["height"])}, {num(q["distanceToHome"])}, "{q["zone"]}", "{q["tier"]}"{island})')
    for c in data["refugeCandidates"]:
        lines.append(f'\tr("{c["id"]}", {num(c["x"])}, {num(c["z"])}, {num(c["ground"])})')
    lines += [
        "return table.freeze({",
        f"\thome = table.freeze({{ x = {num(data['home'][0])}, z = {num(data['home'][1])} }}),",
        "\tpoints = table.freeze(points),",
        "\trefugeCandidates = table.freeze(refuges),",
        "})",
        "",
    ]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)
    read = lambda path: json.loads(path.read_text(encoding="utf-8"))  # noqa: E731
    data = plan(read(LAYOUT), read(ISLANDS), read(RELIEF))
    text = json.dumps(data, indent=1) + "\n"
    if args.write:
        OUTPUT.write_text(text, encoding="utf-8", newline="\n")
        LUAU.write_text(luau(data), encoding="utf-8", newline="\n")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
