"""Contract and measurements for the Caramelo v3 buildings and raft (tools/build-caramelo-v3-buildings-kit.py).

Standard library only, so the tests run under plain `python`. Nothing here imports Blender.

The owner's reference pack (assets/reference/caramelo-v3/, sheets 01, 02, 03 and 11) asks for three enterable
candy buildings and one rideable raft. SPECS below is the contract: sizes, triangle budgets, per-part colours,
doorways, rooms, collision box names and the raft seat. The builder reads the layout numbers from here (so the
door and the seat sit where the contract says) and the test recomputes every claim from the geometry dump.

Frames. Blender: 1 unit = 1 stud, Z up, buildings face -Y (front door) and the raft drives toward -Y. Roblox local
frame, as tools/biome_map_builder.py kit_point uses it: (x, y, z)_roblox = (-x, z, y)_blender, so the front faces -Z.

Collision follows the kit convention: the FBX holds visual meshes only (import them with CanCollide off) and
every collision box is data (report and README) for anchored invisible Parts. A box is
{"name", "center", "size", "rot_deg": [rx, ry, rz]} in Blender axes, rotation as a Blender XYZ Euler with at
most one non-zero angle. Everything is unvalidated until a real Roblox import.
"""

import math
from pathlib import Path

from biome_kit_spec import clear_height, clear_width, clip_axis, top_height

ROOT = Path(__file__).resolve().parents[1]
SLUG = "caramelo-v3-buildings"
BLEND_DIR = ROOT / "assets/blender/caramelo-v3-buildings"
EXPORT_DIR = ROOT / "assets/exports/caramelo-v3/buildings"
REPORT = BLEND_DIR / "caramelo-v3-buildings-report.json"
GEOMETRY = BLEND_DIR / "caramelo-v3-buildings-geometry.json"
ROUNDTRIP = BLEND_DIR / "fbx-roundtrip.json"
BLEND = BLEND_DIR / "caramelo-v3-buildings-v1.blend"
SHEET = BLEND_DIR / "caramelo-v3-buildings-sheet.png"
LINEUP = BLEND_DIR / "caramelo-v3-buildings-scale.png"
README = EXPORT_DIR / "README.md"

# Avatar rules from the request: doorway at least 6 x 9, ceiling at least 12, room to stand on the stairs.
DOOR_MIN_WIDTH = 6.0
DOOR_MIN_HEIGHT = 9.0
CEILING_MIN = 12.0
STAIR_HEADROOM = 5.5
MAX_STEP_RISE = 1.05
SEAT_HEADROOM = 5.0
BUILDING_TRIS = 8000
RAFT_TRIS = 4000

# Prefixes of collision boxes that may stand inside a room (fit-out): everything else is shell.
FITOUT_PREFIXES = ("Prop_", "Stair_", "Newel", "Rail_", "Door_")

# Palette: (palette name, hex). Read off the sheets' colour strips and renders.
PALETTE = {
    "Cookie": ("CV3_Cookie", "D98E3F"), "Gingerbread": ("CV3_Gingerbread", "E3A869"),
    "RoofPink": ("CV3_RoofPink", "F7A8C4"), "HeartPink": ("CV3_HeartPink", "EC5E8E"),
    "Icing": ("CV3_Icing", "FFF6F0"), "Mint": ("CV3_Mint", "9ED8D2"), "ShutterPink": ("CV3_ShutterPink", "F58FB3"),
    "BlushFloor": ("CV3_BlushFloor", "F9DCE6"), "CookieWood": ("CV3_CookieWood", "C47A43"),
    "Cushion": ("CV3_Cushion", "F7B6CB"), "Lemon": ("CV3_Lemon", "F5D76E"), "Lavender": ("CV3_Lavender", "C3A8EC"),
    "MintCandy": ("CV3_MintCandy", "A8E0B5"),
    "DarkChoc": ("CV3_DarkChoc", "45231A"), "MilkChoc": ("CV3_MilkChoc", "8A4B2A"), "Cream": ("CV3_Cream", "F3DDB5"),
    "Waffle": ("CV3_Waffle", "E8B062"), "Caramel": ("CV3_Caramel", "C97A36"), "ChocDoor": ("CV3_ChocDoor", "5A2E1C"),
    "WaffleFloor": ("CV3_WaffleFloor", "E9C48E"),
    "TowerPink": ("CV3_TowerPink", "F6A9C4"), "Swirl": ("CV3_Swirl", "FFF4F2"), "WhipCream": ("CV3_WhipCream", "FCEBD5"),
    "BandPink": ("CV3_BandPink", "E9558A"), "Strawberry": ("CV3_Strawberry", "D9283E"), "Leaf": ("CV3_Leaf", "5DBB63"),
    "WoodDoor": ("CV3_WoodDoor", "8C5A3C"), "WindowFrame": ("CV3_WindowFrame", "E7A24F"),
    "Glass": ("CV3_Glass", "CFE8F5"), "StairCaramel": ("CV3_StairCaramel", "E39A4E"), "TrimPink": ("CV3_TrimPink", "EF7FA6"),
    "Banana": ("CV3_Banana", "F5D97A"), "BananaTip": ("CV3_BananaTip", "6B4A2A"), "SeatPink": ("CV3_SeatPink", "F7A1C0"),
    "ScoopPink": ("CV3_ScoopPink", "F49AC1"), "ScoopVanilla": ("CV3_ScoopVanilla", "F7E3A1"),
    "Cherry": ("CV3_Cherry", "D7192F"), "Stem": ("CV3_Stem", "4E7D2E"), "Sprinkle": ("CV3_Sprinkle", "8FD3F4"),
}


def colors(table):
    """Builder colour table: part label -> (palette name, hex)."""
    return {label: PALETTE[key] for label, key in table.items()}


SWEET_COLORS = {"Base": "Cookie", "Walls": "Gingerbread", "Roof": "RoofPink", "Hearts": "HeartPink",
                "Icing": "Icing", "Accent": "Mint", "Trim": "ShutterPink", "Door": "ShutterPink",
                "Floor": "BlushFloor", "Furniture": "CookieWood", "Cushion": "Cushion", "CandyLemon": "Lemon",
                "CandyLavender": "Lavender", "CandyMint": "MintCandy"}
CHOCO_COLORS = {"Puddle": "DarkChoc", "Plinth": "Caramel", "Cake": "MilkChoc", "Glaze": "DarkChoc",
                "Cream": "Cream", "Waffle": "Waffle", "Rolls": "Caramel", "Door": "ChocDoor", "DoorBar": "MilkChoc",
                "Floor": "WaffleFloor", "Furniture": "CookieWood", "Cushion": "Cushion", "CandyPink": "RoofPink",
                "CandyMint": "MintCandy"}
TOWER_COLORS = {"Base": "WhipCream", "Walls": "TowerPink", "Stripes": "Swirl", "Ledge": "WhipCream",
                "Cap": "WhipCream", "CapBand": "BandPink", "Strawberry": "Strawberry", "Leaf": "Leaf",
                "Door": "WoodDoor", "WindowFrame": "WindowFrame", "Glass": "Glass", "Trim": "TrimPink",
                "Floor": "BlushFloor", "Stairs": "StairCaramel", "Newel": "Swirl", "NewelBand": "BandPink", "Furniture": "CookieWood",
                "Cushion": "Cushion", "CandyLemon": "Lemon"}
RAFT_COLORS = {"Hull": "Banana", "Tips": "BananaTip", "Choc": "DarkChoc", "Seat": "SeatPink",
               "Floaters": "Cushion", "Hearts": "HeartPink", "ScoopPink": "ScoopPink",
               "ScoopVanilla": "ScoopVanilla", "Cream": "Icing", "Cherry": "Cherry", "Stem": "Stem",
               "Sprinkles": "Sprinkle"}

# ---------------------------------------------------------------------------
# Layout numbers the builder places geometry by (studs, Blender axes)
# ---------------------------------------------------------------------------

SWEET = {"floor": 0.6, "half_x": 13.0, "half_y": 11.0, "wall": 1.0, "eave": 14.6, "ridge": 24.0,
         "door_w": 7.0, "door_h": 9.5}
CHOCO = {"floor": 0.7, "r_in": 11.0, "r_out": 12.0, "wall_top": 14.6, "door_h": 9.5, "sides": 16}
TOWER = {"floor": 0.6, "r1_in": 10.0, "r1_out": 11.0, "upper": 16.6, "r2_in": 8.5, "r2_out": 9.5,
         "ceiling": 31.0, "door_h": 9.5, "sides": 16, "steps": 16, "step_in": 1.0, "step_out": 6.0,
         "step_width": 2.4}
RAFT = {"draft": 1.25, "seat": (0.0, 1.6, 1.2)}


def _door_band_round(r_in, r_out, sides, facing):
    """Wall band of a round wall at the door: from the outer radius to the inner chord ends of the opening."""
    inner = r_in * math.cos(math.radians(2 * 360.0 / sides))
    return (-r_out, -inner) if facing == "-Y" else (inner, r_out)


def _round_door_width(r_in, sides):
    return 2 * r_in * math.sin(math.radians(2 * 360.0 / sides))


SPECS = {
    "CV3_SweetHouse": {
        "sheet": "01_Casita_Dulce_San_Valentin.png",
        "size": (31.0, 26.0, 30.0), "tris": BUILDING_TRIS, "min_z": 0.0, "kind": "building",
        "parts": {"Base": ("D98E3F", 50), "Walls": ("E3A869", 120), "Roof": ("F7A8C4", 50),
                  "Hearts": ("EC5E8E", 2900), "Icing": ("FFF6F0", 1850), "Accent": ("9ED8D2", 720),
                  "Trim": ("F58FB3", 200), "Door": ("F58FB3", 50), "Floor": ("F9DCE6", 50),
                  "Furniture": ("C47A43", 400), "Cushion": ("F7B6CB", 100), "CandyLemon": ("F5D76E", 400),
                  "CandyLavender": ("C3A8EC", 550), "CandyMint": ("A8E0B5", 500)},
        "shell": ("Base", "Walls", "Roof", "Hearts", "Icing", "Accent", "Trim", "Floor"),
        "doors": [{"name": "Front", "facing": "-Y", "center_x": 0.0, "band_y": (-11.0, -10.0), "floor": 0.6,
                   "width": 7.0, "height": 9.5}],
        "rooms": [{"name": "Ground", "floor": 0.6, "rect": ((-11.8, -9.8), (11.8, 9.8))}],
        "collision": ("Floor", "Wall_Back", "Wall_Left", "Wall_Right", "Wall_Front_L", "Wall_Front_R",
                      "Wall_Front_Top", "Gable_Front", "Gable_Back", "Roof_L", "Roof_R", "Door_Leaf",
                      "Fence_L", "Fence_R", "Prop_Table", "Prop_Chair_1", "Prop_Chair_2", "Prop_Shelf"),
    },
    "CV3_ChocoHouse": {
        "sheet": "11_Casita_Chocolate.png",
        "size": (30.5, 31.0, 39.5), "tris": BUILDING_TRIS, "min_z": 0.0, "kind": "building",
        "parts": {"Puddle": ("45231A", 100), "Plinth": ("C97A36", 100), "Cake": ("8A4B2A", 600),
                  "Glaze": ("45231A", 1200), "Cream": ("F3DDB5", 2850), "Waffle": ("E8B062", 100),
                  "Rolls": ("C97A36", 850), "Door": ("5A2E1C", 50), "DoorBar": ("8A4B2A", 100),
                  "Floor": ("E9C48E", 100), "Furniture": ("C47A43", 400), "Cushion": ("F7B6CB", 200),
                  "CandyPink": ("F7A8C4", 200), "CandyMint": ("A8E0B5", 250)},
        "shell": ("Puddle", "Plinth", "Cake", "Glaze", "Cream", "Waffle", "Rolls", "Floor"),
        "doors": [{"name": "Front", "facing": "-Y", "center_x": 0.0,
                   "band_y": _door_band_round(CHOCO["r_in"], CHOCO["r_out"], CHOCO["sides"], "-Y"),
                   "floor": 0.7, "width": 7.0, "height": 9.5}],
        "rooms": [{"name": "Ground", "floor": 0.7, "rect": ((-7.5, -7.5), (7.5, 7.5))}],
        "collision": ("Floor_A", "Floor_B", "Floor_C", "Floor_D", "Ramp", "Ceiling_A", "Ceiling_B", "Ceiling_C",
                      "Ceiling_D", "Wall_00", "Wall_10", "Wall_11_Top", "Wall_12_Top", "Wall_13", "Tier2_A",
                      "Tier3_A", "Turret", "Tower_L", "Tower_R", "Tower_Back", "Door_Leaf", "Prop_Table",
                      "Prop_Chair_1", "Prop_Chair_2", "Prop_Chair_3", "Prop_Shelf"),
    },
    "CV3_CaramelTower": {
        "sheet": "03_Torre_Caramelo.png",
        "size": (26.5, 27.5, 49.0), "tris": BUILDING_TRIS, "min_z": 0.0, "kind": "building",
        "parts": {"Base": ("FCEBD5", 600), "Walls": ("F6A9C4", 500), "Stripes": ("FFF4F2", 650),
                  "Ledge": ("FCEBD5", 600), "Cap": ("FCEBD5", 800), "CapBand": ("E9558A", 700),
                  "Strawberry": ("D9283E", 350), "Leaf": ("5DBB63", 150), "Door": ("8C5A3C", 50),
                  "WindowFrame": ("E7A24F", 1050), "Glass": ("CFE8F5", 250), "Trim": ("EF7FA6", 400),
                  "Floor": ("F9DCE6", 150), "Stairs": ("E39A4E", 250), "Newel": ("FFF4F2", 50),
                  "NewelBand": ("E9558A", 400), "Furniture": ("C47A43", 650), "Cushion": ("F7B6CB", 300),
                  "CandyLemon": ("F5D76E", 200)},
        "shell": ("Base", "Walls", "Stripes", "Ledge", "Cap", "CapBand", "Strawberry", "Leaf",
                  "WindowFrame", "Glass", "Trim", "Floor"),
        "doors": [{"name": "Front", "facing": "-Y", "center_x": 0.0,
                   "band_y": _door_band_round(TOWER["r1_in"], TOWER["r1_out"], TOWER["sides"], "-Y"),
                   "floor": 0.6, "width": 7.0, "height": 9.5},
                  {"name": "Balcony", "facing": "+Y", "center_x": 0.0,
                   "band_y": _door_band_round(TOWER["r2_in"], TOWER["r2_out"], TOWER["sides"], "+Y"),
                   "floor": 16.6, "width": 6.0, "height": 9.5}],
        "rooms": [{"name": "Ground", "floor": 0.6, "rect": ((-6.5, -6.5), (6.5, 6.5))},
                  {"name": "Upper", "floor": 16.6, "rect": ((-5.5, 0.5), (5.5, 6.0))}],
        "stairs": 16,
        "collision": ("Floor_A", "Ledge_00", "Upper_Floor_0", "Ceiling_A", "Wall1_00", "Wall1_11_Top",
                      "Wall2_00", "Wall2_03_Top", "Newel", "Stair_00", "Stair_15", "Rail_Upper_L", "Rail_Upper_R",
                      "Balcony_Floor", "Rail_Balcony_F", "Rail_Balcony_L", "Rail_Balcony_R", "Door_Leaf",
                      "Prop_Table", "Prop_Chair_1", "Prop_Chair_2", "Prop_Shelf", "Prop_Upper_Table",
                      "Prop_Upper_Chair", "Prop_Upper_Shelf"),
    },
    "CV3_BananaRaft": {
        "sheet": "02_Balsa_Banana_Split_V2_Montable.png",
        "size": (8.6, 14.2, 7.9), "tris": RAFT_TRIS, "min_z": -RAFT["draft"], "kind": "vehicle",
        "parts": {"Hull": ("F5D97A", 550), "Tips": ("6B4A2A", 60), "Choc": ("45231A", 720),
                  "Seat": ("F7A1C0", 80), "Floaters": ("F7B6CB", 200), "Hearts": ("EC5E8E", 150),
                  "ScoopPink": ("F49AC1", 200), "ScoopVanilla": ("F7E3A1", 100), "Cream": ("FFF6F0", 160),
                  "Cherry": ("D7192F", 250), "Stem": ("4E7D2E", 100), "Sprinkles": ("8FD3F4", 250)},
        "hull_parts": ("Hull", "Tips", "Seat"),
        "seat": {"position": RAFT["seat"], "forward": (0.0, -1.0, 0.0),
                 "headroom": ((-1.5, -0.6, 1.25), (1.5, 3.1, 1.25 + SEAT_HEADROOM))},
        "collision": ("Hull", "Gunwale_L", "Gunwale_R", "Gunwale_Bow", "Gunwale_Stern", "Seat_Base", "Backrest",
                      "Bow_Scoops"),
    },
}

# ---------------------------------------------------------------------------
# Box maths (shared by builder and test)
# ---------------------------------------------------------------------------


def rotation(rot_deg):
    """3 x 3 matrix of a Blender XYZ Euler (R = Rz Ry Rx)."""
    rx, ry, rz = (math.radians(a) for a in rot_deg)
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    x = ((1, 0, 0), (0, cx, -sx), (0, sx, cx))
    y = ((cy, 0, sy), (0, 1, 0), (-sy, 0, cy))
    z = ((cz, -sz, 0), (sz, cz, 0), (0, 0, 1))

    def mm(a, b):
        return tuple(tuple(sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)) for i in range(3))

    return mm(z, mm(y, x))


def box_axes(box):
    """World directions of the box's local X, Y and Z (columns of its rotation)."""
    r = rotation(box.get("rot_deg", (0.0, 0.0, 0.0)))
    return [tuple(r[i][j] for i in range(3)) for j in range(3)]


def box_corners(box):
    axes, c, h = box_axes(box), box["center"], [s / 2 for s in box["size"]]
    out = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (-1, 1):
                out.append(tuple(c[i] + axes[0][i] * sx * h[0] + axes[1][i] * sy * h[1] + axes[2][i] * sz * h[2]
                                 for i in range(3)))
    return out


def aabb_box(low, high, name="aabb"):
    return {"name": name, "center": [(a + b) / 2 for a, b in zip(low, high)],
            "size": [b - a for a, b in zip(low, high)], "rot_deg": [0.0, 0.0, 0.0]}


def boxes_overlap(a, b, eps=1e-4):
    """Separating-axis test for two oriented boxes. Touching faces do not count as overlap."""
    axes_a, axes_b = box_axes(a), box_axes(b)
    candidates = list(axes_a) + list(axes_b)
    for u in axes_a:
        for v in axes_b:
            c = (u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0])
            if math.sqrt(sum(x * x for x in c)) > 1e-6:
                candidates.append(c)
    ca, cb = box_corners(a), box_corners(b)
    for axis in candidates:
        pa = [sum(p[i] * axis[i] for i in range(3)) for p in ca]
        pb = [sum(p[i] * axis[i] for i in range(3)) for p in cb]
        size = math.sqrt(sum(x * x for x in axis))
        if min(pa) >= max(pb) - eps * size or min(pb) >= max(pa) - eps * size:
            return False
    return True


def box_contains_xy(box, x, y):
    """Whether the vertical line at (x, y) passes through a box turned about Z only."""
    c, h = box["center"], box["size"]
    yaw = math.radians(box.get("rot_deg", (0, 0, 0))[2])
    dx, dy = x - c[0], y - c[1]
    lx, ly = dx * math.cos(yaw) + dy * math.sin(yaw), -dx * math.sin(yaw) + dy * math.cos(yaw)
    return abs(lx) <= h[0] / 2 and abs(ly) <= h[1] / 2


def box_z_range(box):
    zs = [p[2] for p in box_corners(box)]
    return min(zs), max(zs)


def is_fitout(name):
    return name.startswith(FITOUT_PREFIXES)


# ---------------------------------------------------------------------------
# Geometry measurements (triangles are lists of three (x, y, z) points)
# ---------------------------------------------------------------------------


def doorway_clearance(triangles, door):
    """Free width and height of a doorway, from the triangles inside the wall band seen along Y.

    Triangles are clipped to the band (the wall thickness at the door), shifted so the door centre is x 0 and
    the floor is z 0, then measured with the passage helpers biome_kit_spec uses for arches.
    """
    y_low, y_high = door["band_y"]
    base = door["floor"] + 0.05
    clipped = []
    for triangle in triangles:
        polygon = clip_axis([tuple(v) for v in triangle], 1, y_low, y_high)
        if len(polygon) >= 3:
            clipped.append([(p[0] - door["center_x"], p[1], p[2] - base) for p in polygon])
    low, high = clear_width(clipped, DOOR_MIN_HEIGHT)
    above = [p for p in (clip_axis(poly, 2, 0.0, 1.0e6) for poly in clipped) if len(p) >= 3]
    height = clear_height(above, DOOR_MIN_WIDTH / 2)
    return {"width": high - low, "gap_low_x": low + door["center_x"], "gap_high_x": high + door["center_x"],
            "height": height + 0.05, "band_y": list(door["band_y"])}


def door_volume(door, width=None):
    """The box an avatar walks through: door width x band x door height, just above the floor."""
    half = (width or door["width"]) / 2 - 0.01
    y_low, y_high = door["band_y"]
    return aabb_box((door["center_x"] - half, y_low, door["floor"] + 0.05),
                    (door["center_x"] + half, y_high, door["floor"] + door["height"] - 0.01), "door")


def room_volume(room, height=CEILING_MIN):
    (x0, y0), (x1, y1) = room["rect"]
    return aabb_box((x0, y0, room["floor"] + 0.05), (x1, y1, room["floor"] + height), "room")


def ceiling_over(triangles, x, y, z_from):
    """Lowest triangle surface straight above (x, y) and higher than z_from, or None."""
    best = None
    for a, b, c in triangles:
        det = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(det) < 1e-12:
            continue
        l1 = ((b[1] - c[1]) * (x - c[0]) + (c[0] - b[0]) * (y - c[1])) / det
        l2 = ((c[1] - a[1]) * (x - c[0]) + (a[0] - c[0]) * (y - c[1])) / det
        l3 = 1.0 - l1 - l2
        if min(l1, l2, l3) < -1e-9:
            continue
        z = l1 * a[2] + l2 * b[2] + l3 * c[2]
        if z > z_from and (best is None or z < best):
            best = z
    return best


def grid(rect, count=5):
    (x0, y0), (x1, y1) = rect
    return [(x0 + (x1 - x0) * (i + 0.5) / count, y0 + (y1 - y0) * (j + 0.5) / count)
            for i in range(count) for j in range(count)]


def room_ceiling(triangles, room):
    """Smallest free height over a grid of the room, measured up from the floor."""
    heights = [ceiling_over(triangles, x, y, room["floor"] + 0.5) for x, y in grid(room["rect"])]
    return min(h for h in heights if h is not None) - room["floor"] if any(h is not None for h in heights) else None


def floor_levels(floor_triangles, room):
    """Top of the floor part at each grid point of the room (only the slab at this floor's level)."""
    near = [t for t in floor_triangles if all(room["floor"] - 1.5 <= v[2] <= room["floor"] + 0.5 for v in t)]
    return [top_height(near, x, y) for x, y in grid(room["rect"])]


# ---------------------------------------------------------------------------
# Roblox frame
# ---------------------------------------------------------------------------


def to_roblox(point):
    """Blender (x, y, z) to the Roblox local frame used by biome_map_builder.kit_point: (-x, z, y)."""
    return [round(-point[0], 4) + 0.0, round(point[2], 4) + 0.0, round(point[1], 4) + 0.0]


def to_roblox_size(size):
    return [round(size[0], 4), round(size[2], 4), round(size[1], 4)]


def to_roblox_orientation(rot_deg):
    """Single-axis Blender rotation to a Roblox Orientation (degrees). The frame map is a proper rotation:
    Blender X -> Roblox -X, Blender Y -> Roblox Z, Blender Z -> Roblox Y."""
    rx, ry, rz = rot_deg
    return [round(-rx, 3) + 0.0, round(rz, 3) + 0.0, round(ry, 3) + 0.0]


def roblox_box(box):
    return {"name": box["name"], "position": to_roblox(box["center"]), "size": to_roblox_size(box["size"]),
            "orientation": to_roblox_orientation(box.get("rot_deg", (0.0, 0.0, 0.0)))}
