"""Export the Caramelo v3 kit contracts to a Luau table (tools/WildboundCandyV3KitSpec.luau).

Run from the project root (isolated mode, no bytecode written):

    python -I -B tools/export_caramelo_v3_kit_spec.py           # writes the Luau file
    python -I -B tools/export_caramelo_v3_kit_spec.py --check   # exit 1 when the file is stale

Sources (written by the Blender kit builders, read only here):
  assets/exports/caramelo-v3/decor/caramelo-v3-decor-spec.json      (trees, mountains, licorice, cake, cookies)
  assets/blender/caramelo-v3-buildings/caramelo-v3-buildings-report.json  (houses, tower, raft)

Everything is converted to the Roblox local frame of the kit model (pivot at the ground centre of the base, front
-Z): (X, Y, Z) = (-x, z, y) of Blender. A collider is { name, shape ("block" or "cylinder"), pos, size, orient }:
pos and size in studs, Roblox axes (a cylinder's size is { height, diameter, diameter }, its axis is turned upright by
the builder), orient = { rx, ry, rz } degrees for CFrame.fromOrientation. The meshes never collide; the builder
(WildboundCandyV3Builder) makes these invisible anchored parts. Pieces carry the mesh object name, colour and role
(visual, sway, water, or the buildings' part label).
"""

import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DECOR = ROOT / "assets/exports/caramelo-v3/decor/caramelo-v3-decor-spec.json"
BUILDINGS = ROOT / "assets/blender/caramelo-v3-buildings/caramelo-v3-buildings-report.json"
OUT = ROOT / "tools/WildboundCandyV3KitSpec.luau"


def r(v):
    v = round(float(v), 4)
    return 0.0 if v == 0 else v


def point(b):
    """Blender (x, y, z) -> Roblox local (X, Y, Z) = (-x, z, y)."""
    return [r(-b[0]), r(b[2]), r(b[1])]


def decor_collider(c):
    size = c["size"]
    if c["shape"] == "cylinder":
        rsize = [r(size[2]), r(size[0]), r(size[1])]
    else:
        rsize = [r(size[0]), r(size[2]), r(size[1])]
    # a Blender yaw about z is the same angle about Roblox Y; a Blender pitch about x is the opposite angle about
    # Roblox X (see the module doc of WildboundCandyV3KitSpec)
    return {"name": c["name"], "shape": c["shape"], "pos": point(c["center"]), "size": rsize,
            "orient": [r(-c.get("pitch_deg", 0.0)), r(c.get("yaw_deg", 0.0)), 0.0]}


def decor_asset(name, a):
    out = {"size": [r(a["size"][0]), r(a["size"][2]), r(a["size"][1])],
           "colliders": [decor_collider(c) for c in a["collision"]],
           "pieces": {k: {"object": v["object"], "color": v["color"].lstrip("#"), "role": v["role"]}
                      for k, v in sorted(a["pieces"].items())}}
    if "sway" in a:
        out["sway"] = {"objects": list(a["sway"]["objects"]), "pivot": point(a["sway"]["pivot"])}
    if "water" in a:
        w = a["water"]
        out["water"] = {"ledge": r(w["ledge_z"]), "surface": r(w["pool_surface_z"]), "poolCentre": point(w["pool_center"]),
                        "poolRadius": r(w["pool_radius"]), "outlet": point(w["outlet"]), "river": w["river"],
                        "waterfall": w["waterfall"], "pool": w["pool"], "poolLip": w["pool_lip"]}
    if "snap" in a:
        out["sockets"] = {k: point(v) for k, v in sorted(a["snap"]["sockets"].items())}
    return out


def building_asset(name, a):
    out = {"size": [r(a["size"][0]), r(a["size"][2]), r(a["size"][1])],
           "colliders": [{"name": "Collision_" + c["name"], "shape": "block", "pos": [r(v) for v in c["position"]],
                          "size": [r(v) for v in c["size"]], "orient": [r(v) for v in c["orientation"]]}
                         for c in a["collision_roblox"]],
           "pieces": {p["object"].split(name + "_", 1)[-1]: {"object": p["object"], "color": p["color_hex"].lstrip("#"),
                                                             "role": "visual"} for p in a["parts"]}}
    seat = a.get("seat_anchor")
    if seat:
        out["seat"] = {"pos": [r(v) for v in seat["roblox"]], "forward": [r(v) for v in seat["forward_roblox"]]}
    return out


def lua(value, indent=1):
    pad = "\t" * indent
    if isinstance(value, dict):
        if not value:
            return "{}"
        items = []
        for k in sorted(value):
            key = k if k.isidentifier() else '["%s"]' % k
            items.append("%s%s = %s," % (pad, key, lua(value[k], indent + 1)))
        return "{\n" + "\n".join(items) + "\n" + "\t" * (indent - 1) + "}"
    if isinstance(value, list):
        if all(not isinstance(v, (dict, list)) for v in value):
            return "{ " + ", ".join(lua(v) for v in value) + " }"
        return "{\n" + "\n".join("%s%s," % (pad, lua(v, indent + 1)) for v in value) + "\n" + "\t" * (indent - 1) + "}"
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, (int, float)):
        return repr(r(value))
    return '"%s"' % str(value).replace("\\", "\\\\").replace('"', '\\"')


def render():
    decor = json.loads(DECOR.read_text(encoding="utf-8"))
    assets = {name: decor_asset(name, a) for name, a in decor["assets"].items()}
    if BUILDINGS.exists():
        report = json.loads(BUILDINGS.read_text(encoding="utf-8"))
        for name, a in report["props"].items():
            assets[name] = building_asset(name, a)
    head = ("-- GENERATED by tools/export_caramelo_v3_kit_spec.py from the Caramelo v3 kit contracts; do not edit by hand.\n"
            "-- Roblox local frame of each kit Model (pivot at the ground centre of the base, front -Z): (X, Y, Z) = (-x, z, y)\n"
            "-- of Blender. A collider: shape, pos, size (a cylinder's size is { height, diameter, diameter }, axis turned\n"
            "-- upright by the builder), orient = { rx, ry, rz } degrees for CFrame.fromOrientation. The meshes never collide.\n"
            "-- Status: unvalidated until a real Roblox import (both kits say so).\n")
    return head + "return table.freeze(" + lua(assets) + ")\n"


def main(argv):
    text = render()
    if "--check" in argv:
        current = OUT.read_text(encoding="utf-8") if OUT.exists() else ""
        if current.replace("\r\n", "\n") != text:
            print("stale: run python -I -B tools/export_caramelo_v3_kit_spec.py")
            return 1
        print("up to date")
        return 0
    OUT.write_text(text, encoding="utf-8", newline="\n")
    print("wrote", OUT.relative_to(ROOT))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
