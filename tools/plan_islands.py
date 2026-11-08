"""Creature islands for the Wildbound expedition map (docs/mechanics/wildbound-expedition-islands.md section 2, I1).

Five islands of sleeping creatures at rising risk. Each is a flat floor (the relief planner already keeps its ridges
off it) with a nest at the centre and its adults asleep around it. This planner fixes, from the existing layouts:

- the floor radius: the design's 14 to 18 studs, shrunk (never under 14) until no trunk core or relief footprint
  reaches it; a layout tree whose core still reaches a 14-stud floor is listed in `removedTrees`;
- the nest and adult points (adults 6 studs from the nest, facing out, 3 studs clear of every core);
- entrances: the directions where the ground just past the floor stays flat (no rim);
- the hide spot 25 to 45 studs away (islands 2 to 5) and the show crest on "Cresta de la Vigia" (EI-9);
- the rule numbers each island carries: zone tier (noise, capture windows), reward tier (Ember), species,
  adult count and wake radius (day; night is 1.25 times).

It writes the JSON and the generated Luau module that the servers and the map builder read.

    python -I -B tools/plan_islands.py            # prints JSON, writes nothing
    python -I -B tools/plan_islands.py --write    # writes islands-v1.json and src/wildbound/WildboundIslandLayout.luau
"""

import argparse
import json
import math
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
LAYOUT = REPO / "assets/maps/forest-layout/forest-layout-v1.json"
HIDE = REPO / "assets/maps/forest-layout/hide-spots-v1.json"
RELIEF = REPO / "assets/maps/forest-layout/relief-v1.json"
OUTPUT = REPO / "assets/maps/forest-layout/islands-v1.json"
LUAU = REPO / "src/wildbound/WildboundIslandLayout.luau"

HOME, LEASH = (0.0, -85.0), 80.0
FOG = (-45.0, 165.0, -165.0, 35.0)
CORE = {"FK_Evergreen": 2.5 * 1.6, "FK_DeadTree": 3.4 * 1.4}  # tools/dress-wildbound-forest.luau, grown (DP6)
FLOOR_MIN = 14.0
ADULT_RING = 6.0
ADULT_CLEAR = 3.0
NIGHT_RADIUS = 1.25
ENTRANCE_PROBE = 6.0  # studs past the floor edge where an entrance must still be flat

# id, key, centre, design floor radius, zone tier, reward tier, species, adults, wake radius by day
ISLANDS = (
    ("I1", "claro", (-95.0, 75.0), 14.0, "Safe", "Safe", "Lumipol", 2, 12.0),
    ("I2", "hondonada", (-27.0, 0.0), 16.0, "Fog", "Fog", "Cortezon", 2, 16.0),
    ("I3", "pantano", (115.0, 15.0), 16.0, "Fog", "FogFar", "Cestillo", 3, 18.0),
    ("I4", "ruinas", (35.0, -99.0), 16.0, "Territory", "Territory", "Polvilla", 3, 20.0),
    ("I5", "corazon", (60.0, -135.0), 16.0, "Territory", "Heart", "Tizoncillo", 4, 22.0),
)


def zone(x, z):
    x0, x1, z0, z1 = FOG
    if not (x0 <= x <= x1 and z0 <= z <= z1):
        return "outside"
    return "territory" if math.dist((x, z), HOME) <= LEASH else "fog"


def segment_point_distance(ax, az, bx, bz, px, pz):
    dx, dz = bx - ax, bz - az
    length2 = dx * dx + dz * dz
    t = 0.0 if length2 == 0 else max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / length2))
    return math.dist((ax + t * dx, az + t * dz), (px, pz))


def relief_reach(segment):
    run = segment["height"] / math.tan(math.radians(segment["slopeDeg"]))
    return segment["crestWidth"] / 2 + run


def relief_clearance(segments, x, z):
    best = math.inf
    for s in segments:
        (ax, az), (bx, bz) = s["a"], s["b"]
        best = min(best, segment_point_distance(ax, az, bx, bz, x, z) - relief_reach(s))
    return best


def plan(layout, hide, relief):
    segments = relief["segments"]
    trees = [(i["id"], i["x"], i["z"], CORE[i["name"]] * i["scale"]) for i in layout["instances"] if i["name"] in CORE
             and i["id"] not in set(relief["removedTrees"])]
    removed, islands = [], []
    for ident, key, (cx, cz), design, tier, reward, species, adults, wake in ISLANDS:
        relief_room = relief_clearance(segments, cx, cz)
        if relief_room < FLOOR_MIN:
            raise SystemExit(f"{ident}: relief reaches {relief_room:.1f} studs from the nest")
        radius = min(design, math.floor(relief_room * 10) / 10)
        tree_room = min((math.dist((x, z), (cx, cz)) - core for _, x, z, core in trees), default=math.inf)
        if tree_room < radius:
            radius = max(FLOOR_MIN, math.floor(tree_room * 10) / 10)
        for tree_id, x, z, core in trees:
            if math.dist((x, z), (cx, cz)) - core < radius and tree_id not in removed:
                removed.append(tree_id)
        live = [t for t in trees if t[0] not in removed]
        points = []
        for k in range(adults):
            base = math.radians(90.0 + 360.0 * k / adults)
            for nudge in range(12):
                angle = base + math.radians(15.0 * nudge * (1 if nudge % 2 else -1))
                x, z = cx + ADULT_RING * math.cos(angle), cz + ADULT_RING * math.sin(angle)
                if all(math.dist((x, z), (tx, tz)) - core >= ADULT_CLEAR for _, tx, tz, core in live):
                    points.append({"x": round(x, 3), "z": round(z, 3), "faceX": round(math.cos(angle), 4),
                                   "faceZ": round(math.sin(angle), 4)})
                    break
            else:
                raise SystemExit(f"{ident}: no room for adult {k + 1}")
        entrances = []
        for k in range(16):
            angle = 2 * math.pi * k / 16
            px, pz = cx + (radius + ENTRANCE_PROBE) * math.cos(angle), cz + (radius + ENTRANCE_PROBE) * math.sin(angle)
            if relief_clearance(segments, px, pz) > 0:
                entrances.append(round(math.degrees(angle)))
        near = sorted((math.dist((s["x"], s["z"]), (cx, cz)), s["id"]) for s in hide["spots"]
                      if 25 <= math.dist((s["x"], s["z"]), (cx, cz)) <= 45)
        islands.append({
            "id": ident, "key": key, "centre": [cx, cz], "floorRadius": radius, "zone": zone(cx, cz), "tier": tier,
            "rewardTier": reward, "species": species, "adults": adults,
            "wakeRadius": {"day": wake, "night": wake * NIGHT_RADIUS},
            "nest": {"x": cx, "z": cz}, "adultPoints": points, "entrances": entrances,
            "rimSegments": [s["id"] for s in segments if s.get("feature") == "rim-" + key],
            "hideSpot": near[0][1] if near else None,
        })
    vigia = next(s for s in segments if s.get("feature") == "cresta-vigia")
    (ax, az), (bx, bz) = vigia["a"], vigia["b"]
    crest = {"segment": vigia["id"], "x": round((ax + bx) / 2, 3), "z": round((az + bz) / 2, 3),
             "y": round(0.5 + vigia["height"], 3)}
    return {
        "name": "islands-v1",
        "source": "tools/plan_islands.py; docs/mechanics/wildbound-expedition-islands.md section 2",
        "conventions": "studs, origin at the map centre, x east, z south; wake radius night = day x 1.25",
        "islands": islands, "showCrest": crest, "removedTrees": sorted(removed),
    }


def luau(data):
    def num(value):
        return repr(round(float(value), 4)).rstrip("0").rstrip(".") if value != int(value) else str(int(value))

    lines = ["-- generated by tools/plan_islands.py from assets/maps/forest-layout/islands-v1.json; do not edit.",
             "-- Creature islands (docs/mechanics/wildbound-expedition-islands.md section 2): where each island is and",
             "-- the numbers it carries. Pure data, read by the servers (WildboundIsland) and the map builder.",
             "return table.freeze({", "\tislands = table.freeze({"]
    for i in data["islands"]:
        adults = ", ".join(f"table.freeze({{ x = {num(p['x'])}, z = {num(p['z'])}, faceX = {num(p['faceX'])}, "
                           f"faceZ = {num(p['faceZ'])} }})" for p in i["adultPoints"])
        lines += [
            "\t\ttable.freeze({",
            f'\t\t\tid = "{i["id"]}", key = "{i["key"]}", x = {num(i["centre"][0])}, z = {num(i["centre"][1])},',
            f'\t\t\tfloorRadius = {num(i["floorRadius"])}, zone = "{i["zone"]}", tier = "{i["tier"]}",',
            f'\t\t\trewardTier = "{i["rewardTier"]}", species = "{i["species"]}", adults = {i["adults"]},',
            f'\t\t\twakeDay = {num(i["wakeRadius"]["day"])}, wakeNight = {num(i["wakeRadius"]["night"])},',
            f'\t\t\thideSpot = {json.dumps(i["hideSpot"]) if i["hideSpot"] else "nil"},',
            f"\t\t\tadultPoints = table.freeze({{ {adults} }}),",
            "\t\t}),",
        ]
    crest = data["showCrest"]
    lines += ["\t}),",
              f'\tshowCrest = table.freeze({{ segment = "{crest["segment"]}", x = {num(crest["x"])}, '
              f'z = {num(crest["z"])}, y = {num(crest["y"])} }}),',
              "})", ""]
    return "\n".join(lines)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args(argv)
    read = lambda path: json.loads(path.read_text(encoding="utf-8"))  # noqa: E731
    data = plan(read(LAYOUT), read(HIDE), read(RELIEF))
    text = json.dumps(data, indent=2) + "\n"
    if args.write:
        OUTPUT.write_text(text, encoding="utf-8", newline="\n")
        LUAU.write_text(luau(data), encoding="utf-8", newline="\n")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
