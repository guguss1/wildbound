"""Build the Caramelo v3 buildings and raft (CV3_) in a fresh headless Blender scene.

Run (Blender 5.0, from the repo root):
  "C:/Program Files/Blender Foundation/Blender 5.0/blender.exe" -b --factory-startup -P tools/build-caramelo-v3-buildings-kit.py
It builds, exports one FBX per asset, renders (exterior, interior cutaway, sheet, scale lineup), saves the .blend,
writes the report and geometry dump, then re-imports every FBX in a fresh scene (fbx-roundtrip.json).
Set CARAMELO_V3_BUILDINGS_MODE=verify-fbx to only re-import. Under plain Python this file does a dry run: it
counts triangles and checks closure, doorways and rooms without Blender.

Pieces (owner's sheets in assets/reference/caramelo-v3/):
  01 CV3_SweetHouse    Valentine gingerbread house: pink heart roof, icing, mint frames, picket fence.
  11 CV3_ChocoHouse    tiered chocolate cake house: glaze drips, cream bands, waffle cones, cookie rolls.
  03 CV3_CaramelTower  pink-and-white swirl tower, cream mushroom cap and strawberry, spiral stair, balcony.
  02 CV3_BananaRaft    rideable banana split raft: hull, seat (SeatAnchor empty), scoops, sauce, cherries.

1 Blender unit = 1 stud. Each asset is an Empty root at the pivot (ground centre; the raft: waterline centre)
with one mesh child per colour, because a Roblox MeshPart holds one colour. Collision is data, not mesh: the
report and README list simple boxes for invisible anchored Parts, and the visual meshes import non-colliding.
Contract and measurements: tools/caramelo_v3_buildings_spec.py. Nothing is downloaded or uploaded; everything is
unvalidated until a real Roblox import. No rig: nothing here is alive.
"""

import math
import os
import sys
from pathlib import Path

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import biome_kit_common as bk  # noqa: E402
import caramelo_v3_buildings_spec as cs  # noqa: E402
import kit_common as kc  # noqa: E402
from biome_kit_common import no_weight as W  # noqa: E402

GENERATOR = "tools/build-caramelo-v3-buildings-kit.py"
MODE_VARIABLE = "CARAMELO_V3_BUILDINGS_MODE"
X, Y, Z = (1.0, 0.0, 0.0), (0.0, 1.0, 0.0), (0.0, 0.0, 1.0)


# ---------------------------------------------------------------------------
# Small shapes
# ---------------------------------------------------------------------------

def rad(a):
    return math.radians(a)


def polar(r, a_deg, z):
    return (r * math.cos(rad(a_deg)), r * math.sin(rad(a_deg)), z)


def obox(part, center, size, rot=(0.0, 0.0, 0.0), taper=1.0):
    """Box turned by a Blender XYZ Euler (degrees); taper < 1 narrows the top face."""
    axes = cs.box_axes({"rot_deg": rot})
    h = [s / 2 for s in size]
    ring = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    corners = []
    for sz, scale in ((-1, 1.0), (1, taper)):
        for sx, sy in ring:
            corners.append(tuple(center[i] + axes[0][i] * sx * h[0] * scale + axes[1][i] * sy * h[1] * scale
                                 + axes[2][i] * sz * h[2] for i in range(3)))
    kc.hexahedron(part, corners, W)


def zbox(part, x, y, z0, z1, sx, sy, yaw=0.0, taper=1.0):
    """Upright box from z0 to z1, turned yaw degrees about Z."""
    obox(part, (x, y, (z0 + z1) / 2), (sx, sy, z1 - z0), (0.0, 0.0, yaw), taper)


def panel(part, r_in, r_out, a0, a1, z0, z1):
    """One segment of a round wall between two angles (degrees)."""
    corners = [polar(r, a, z) for z in (z0, z1) for r, a in ((r_in, a0), (r_out, a0), (r_out, a1), (r_in, a1))]
    kc.hexahedron(part, corners, W)


def disc(part, center, radius, height, sides=12, frame=kc.Z_UP):
    kc.lathe(part, [(radius, 0.0), (radius, height)], sides, W, center=center, frame=frame)


def cone(part, center, radius, height, sides=8, top=0.0, frame=kc.Z_UP, phase=0.0):
    profile = [(radius, 0.0), (top, height)] if top > 0 else [(radius, 0.0), (0.0, height)]
    kc.lathe(part, profile, sides, W, center=center, frame=frame, phase=phase)


def ball(part, center, radius, sides=8, rings=4, squash=1.0):
    kc.lathe(part, kc.arc_profile(radius, radius * squash, rings), sides, W, center=center)


def tube(part, points, radius, sides=6):
    kc.tube(part, points, [radius] * len(points), sides, W)


def arc_points(center, u, v, radius, a0, a1, count):
    return [kc.add(center, kc.add(kc.mul(u, radius * math.cos(rad(a0 + (a1 - a0) * i / (count - 1)))),
                                  kc.mul(v, radius * math.sin(rad(a0 + (a1 - a0) * i / (count - 1))))))
            for i in range(count)]


def heart_outline(size):
    shape = [(0.0, -1.0), (0.75, -0.15), (0.85, 0.35), (0.5, 0.75), (0.0, 0.4), (-0.5, 0.75), (-0.85, 0.35),
             (-0.75, -0.15)]
    return [(a * size, b * size) for a, b in shape]


def heart(part, origin, u, v, normal, size, thickness=0.25):
    kc.slab(part, heart_outline(size), origin, u, v, normal, thickness, W)


def semicircle(part, origin, u, v, normal, radius, thickness, count=7):
    outline = [(radius * math.cos(math.pi * i / (count - 1)), radius * math.sin(math.pi * i / (count - 1)))
               for i in range(count)]
    kc.slab(part, outline, origin, u, v, normal, thickness, W)


def ring_tube(part, center, radius, minor, segments=16, sides=5):
    kc.torus(part, center, X, Y, radius, minor, segments, sides, W)


def arc_tube(part, center_z, radius, minor, a0, a1, count=12, sides=5):
    tube(part, [polar(radius, a0 + (a1 - a0) * i / (count - 1), center_z) for i in range(count)], minor, sides)


def collide(a, name, center, size, rot=(0.0, 0.0, 0.0)):
    a.collision.append({"name": name, "center": [round(c, 4) + 0.0 for c in center],
                        "size": [round(s, 4) for s in size], "rot_deg": [round(r, 3) + 0.0 for r in rot]})


def zcollide(a, name, x, y, z0, z1, sx, sy, yaw=0.0):
    collide(a, name, (x, y, (z0 + z1) / 2), (sx, sy, z1 - z0), (0.0, 0.0, yaw))


def disc_collision(a, prefix, radius, z0, z1, suffixes="ABCD"):
    """A round slab as four rectangles turned 0, 45, 90 and 135 degrees, each inside the circle."""
    half_long, half_short = radius * math.cos(rad(22.5)), radius * math.sin(rad(22.5))
    for k, suffix in enumerate(suffixes):
        zcollide(a, f"{prefix}_{suffix}", 0.0, 0.0, z0, z1, 2 * half_long, 2 * half_short, 45.0 * k)


def round_wall(a, part, prefix, r_in, r_out, sides, z0, z1, openings):
    """Panels of a round wall. openings maps panel index -> z where the panel restarts above the opening."""
    step = 360.0 / sides
    chord = 2 * r_out * math.sin(rad(step / 2)) + 0.05
    for k in range(sides):
        a0, a1, mid = k * step, (k + 1) * step, (k + 0.5) * step
        centre = polar((r_in + r_out) / 2 * math.cos(rad(step / 2)), mid, 0.0)
        bottom = openings.get(k, z0)
        panel(part, r_in, r_out, a0, a1, bottom, z1)
        name = f"{prefix}_{k:02d}" + ("_Top" if k in openings else "")
        zcollide(a, name, centre[0], centre[1], bottom, z1, r_out - r_in, chord, mid)


def window_flat(a, center, right, out, frame_part="Accent", pane_part="Icing", shutter_part="Trim",
                width=3.2, height=4.6, inner=None):
    """Arched window on a flat wall: frame, pane, cross bars, shutters; optional inner pane on the room side."""
    yaw = math.degrees(math.atan2(right[1], right[0]))
    up = Z

    def at(dr, do, dz):
        return tuple(center[i] + right[i] * dr + out[i] * do + up[i] * dz for i in range(3))

    obox(a.part(frame_part), at(0, 0.15, 0), (width, 0.3, height), (0, 0, yaw))
    semicircle(a.part(frame_part), at(0, 0.0, height / 2), right, up, out, width / 2, 0.3)
    obox(a.part(pane_part), at(0, 0.3, 0), (width - 0.8, 0.12, height - 0.8), (0, 0, yaw))
    semicircle(a.part(pane_part), at(0, 0.2, height / 2 - 0.4), right, up, out, width / 2 - 0.4, 0.22)
    obox(a.part(frame_part), at(0, 0.45, 0), (0.25, 0.15, height - 0.8), (0, 0, yaw))
    obox(a.part(frame_part), at(0, 0.45, 0.4), (width - 0.8, 0.15, 0.25), (0, 0, yaw))
    obox(a.part(frame_part), at(0, 0.45, -height / 2 - 0.1), (width + 0.6, 0.6, 0.35), (0, 0, yaw))
    if shutter_part:
        for side in (-1, 1):
            obox(a.part(shutter_part), at(side * (width / 2 + 0.65), 0.15, 0), (1.0, 0.3, height - 0.2),
                 (0, 0, yaw))
    if inner is not None:
        obox(a.part(pane_part), tuple(inner[i] for i in range(3)), (width - 0.6, 0.1, height - 0.6), (0, 0, yaw))


def round_window(a, angle, z, radius, r_wall_out, r_wall_in, frame_part="WindowFrame", glass_part="Glass"):
    """Porthole through a round wall: a caramel ring outside and a glass disc running through the wall."""
    out = (math.cos(rad(angle)), math.sin(rad(angle)), 0.0)
    tangent = (-out[1], out[0], 0.0)
    centre = polar(r_wall_out + 0.15, angle, z)
    kc.torus(a.part(frame_part), centre, tangent, Z, radius, 0.32, 12, 5, W)
    for k in range(4):  # the cross bars of the sheet's round window
        ang = 45.0 + 90.0 * k
        tip = kc.add(centre, kc.add(kc.mul(tangent, radius * math.cos(rad(ang))), kc.mul(Z, radius * math.sin(rad(ang)))))
        tube(a.part(frame_part), [centre, tip], 0.12, 4)
    kc.lathe(a.part(glass_part), [(radius, 0.0), (radius, r_wall_out - r_wall_in + 0.25)], 10, W,
             center=polar(r_wall_in - 0.1, angle, z), frame=(tangent, Z, out))


# ---------------------------------------------------------------------------
# Interior fit-out shared by the buildings
# ---------------------------------------------------------------------------

def table(a, x, y, floor, radius=2.2, height=3.0, name="Prop_Table", top="Furniture", treat=None):
    disc(a.part("Furniture"), (x, y, floor), radius * 0.45, 0.2)
    disc(a.part("Furniture"), (x, y, floor + 0.2), 0.35, height - 0.6, sides=6)
    disc(a.part(top), (x, y, floor + height - 0.4), radius, 0.4, sides=12)
    if treat:
        cone(a.part(treat), (x, y, floor + height), 0.7, 0.8, sides=6, top=0.9)
        ball(a.part("Cushion"), (x, y, floor + height + 1.2), 0.55, sides=6, rings=3)
    zcollide(a, name, x, y, floor, floor + height, 2 * radius, 2 * radius)


def chair(a, name, x, y, floor, facing_deg, back=True):
    """Stool or chair: cushion seat, four legs and a backrest on the far side from facing_deg."""
    zbox(a.part("Cushion"), x, y, floor + 1.6, floor + 2.0, 1.8, 1.8, facing_deg)
    for sx in (-0.65, 0.65):
        for sy in (-0.65, 0.65):
            c, s = math.cos(rad(facing_deg)), math.sin(rad(facing_deg))
            zbox(a.part("Furniture"), x + sx * c - sy * s, y + sx * s + sy * c, floor, floor + 1.6, 0.3, 0.3,
                 facing_deg)
    top = floor + 2.0
    if back:
        bx, by = x - 0.8 * math.cos(rad(facing_deg)), y - 0.8 * math.sin(rad(facing_deg))
        zbox(a.part("Furniture"), bx, by, floor + 2.0, floor + 4.2, 0.3, 1.8, facing_deg)
        top = floor + 4.2
    zcollide(a, name, x, y, floor, top, 1.9, 1.9, facing_deg)


def shelf(a, name, x, y, floor, yaw, width=5.0, depth=1.2, height=6.0, candies=("CandyLemon", "CandyMint")):
    """Open shelf: back, two sides, three boards; candy jars and gumdrops on the boards. Local +X faces the room."""
    c, s = math.cos(rad(yaw)), math.sin(rad(yaw))

    def at(dx, dy):
        return x + dx * c - dy * s, y + dx * s + dy * c

    part = a.part("Furniture")
    bx, by = at(-depth / 2 + 0.15, 0.0)
    zbox(part, bx, by, floor, floor + height, 0.3, width, yaw)
    for side in (-1, 1):
        sx, sy = at(0.0, side * (width / 2 - 0.15))
        zbox(part, sx, sy, floor, floor + height, depth, 0.3, yaw)
    for k, z in enumerate((0.4, height * 0.45, height * 0.85)):
        zbox(part, x, y, floor + z, floor + z + 0.25, depth, width - 0.1, yaw)
        if k == 2:
            continue
        for j, dy in enumerate((-1.4, 0.0, 1.4)):
            jx, jy = at(0.1, dy)
            candy = a.part(candies[(j + k) % len(candies)])
            if j == 1:
                cone(candy, (jx, jy, floor + z + 0.25), 0.45, 0.8, sides=6, top=0.25)
            else:
                disc(candy, (jx, jy, floor + z + 0.25), 0.4, 1.2, sides=6)
    zcollide(a, name, x, y, floor, floor + height, depth, width, yaw)


def lollipop(a, x, y, z0, stick_part, disc_part, swirl_part, height=4.0, radius=1.2, facing=-90.0):
    tube(a.part(stick_part), [(x, y, z0), (x, y, z0 + height)], 0.15, 4)
    out = (math.cos(rad(facing)), math.sin(rad(facing)), 0.0)
    tangent = (-out[1], out[0], 0.0)
    centre = (x - out[0] * 0.2, y - out[1] * 0.2, z0 + height + radius * 0.8)
    kc.lathe(a.part(disc_part), [(radius, 0.0), (radius, 0.4)], 10, W, center=centre, frame=(tangent, Z, out))
    kc.torus(a.part(swirl_part), kc.madd(centre, out, 0.45), tangent, Z, radius * 0.55, 0.14, 10, 4, W)


# ---------------------------------------------------------------------------
# 01 CV3_SweetHouse
# ---------------------------------------------------------------------------

def build_sweet_house(a):
    L = cs.SWEET
    F, hx, hy, t, eave, ridge = L["floor"], L["half_x"], L["half_y"], L["wall"], L["eave"], L["ridge"]
    dw, door_top = L["door_w"] / 2, L["floor"] + L["door_h"]
    walls, roof, icing = a.part("Walls"), a.part("Roof"), a.part("Icing")

    # Cookie base with an icing lip, and the blush floor inside.
    zbox(a.part("Base"), 0, 0, 0.0, 0.5, 30.0, 26.0, taper=0.985)
    zbox(a.part("Floor"), 0, 0, 0.5, F, 2 * (hx - t), 2 * (hy - t))
    for sx, sy, w, d in ((0, -12.85, 29.4, 0.3), (0, 12.85, 29.4, 0.3), (-14.85, 0, 0.3, 25.4), (14.85, 0, 0.3, 25.4)):
        zbox(icing, sx, sy, 0.3, 0.75, w, d)
    collide(a, "Floor", (0, 0, F / 2), (30.0, 26.0, F))

    # Walls: back, sides, front split around the door. All thin boxes, same as their collision.
    pieces = (("Wall_Back", 0, hy - t / 2, 0.5, eave, 2 * hx, t),
              ("Wall_Left", -hx + t / 2, 0, 0.5, eave, t, 2 * (hy - t)),
              ("Wall_Right", hx - t / 2, 0, 0.5, eave, t, 2 * (hy - t)),
              ("Wall_Front_L", -(hx + dw) / 2, -hy + t / 2, 0.5, eave, hx - dw, t),
              ("Wall_Front_R", (hx + dw) / 2, -hy + t / 2, 0.5, eave, hx - dw, t),
              ("Wall_Front_Top", 0, -hy + t / 2, door_top, eave, 2 * dw, t))
    for name, x, y, z0, z1, sx, sy in pieces:
        zbox(walls, x, y, z0, z1, sx, sy)
        zcollide(a, name, x, y, z0, z1, sx, sy)
    for name, y0 in (("Gable_Front", -hy), ("Gable_Back", hy - t)):
        kc.slab(walls, [(-hx, eave), (hx, eave), (0.0, ridge)], (0.0, y0, 0.0), X, Z, Y, t, W)
        collide(a, name, (0.0, y0 + t / 2, eave + (ridge - eave) * 0.3), (hx, t, (ridge - eave) * 0.6))

    # Roof: two pitched slabs over the gables, with heart tiles on top.
    slope = math.atan2(ridge - eave, hx)
    thick, over = 1.2, 1.6
    s1 = (hx + over) / math.cos(slope)
    for side in (-1, 1):
        d = (side * math.cos(slope), 0.0, -math.sin(slope))
        n = (side * math.sin(slope), 0.0, math.cos(slope))
        top = (0.0, 0.0, ridge)
        corners = []
        for k in (0.0, thick):
            for s, y in ((-0.9, -hy - over), (s1, -hy - over), (s1, hy + over), (-0.9, hy + over)):
                p = kc.madd(kc.madd(top, d, s), n, k)
                corners.append((p[0], y, p[2]))
        kc.hexahedron(roof, corners, W)
        mid_s = (s1 - 0.9) / 2
        centre = kc.madd(kc.madd(top, d, mid_s), n, thick / 2)
        collide(a, "Roof_" + ("L" if side < 0 else "R"), centre, (s1 + 0.9, 2 * (hy + over), thick),
                (0.0, side * math.degrees(slope), 0.0))
        up_slope = kc.mul(d, -1.0)
        for row in range(5):
            s = 1.8 + row * (s1 - 3.0) / 4.4
            for col in range(7):
                y = -hy + 0.4 + col * (2 * hy - 0.8) / 6 + (0.9 if row % 2 else 0.0)
                if y > hy + 0.6:
                    continue
                base = kc.madd(kc.madd(top, d, s), n, thick)
                heart(a.part("Hearts"), (base[0], y, base[2]), Y, up_slope, n, 0.95, 0.22)
        # Eave icing roll with drips, and candy beads along it.
        eave_pt = kc.madd(kc.madd(top, d, s1), n, thick * 0.6)
        tube(icing, [(eave_pt[0], -hy - over, eave_pt[2]), (eave_pt[0], hy + over, eave_pt[2])], 0.6, 6)
        for k in range(12):
            y = -hy - over + 0.8 + k * (2 * (hy + over) - 1.6) / 11
            length = 0.9 + 0.6 * ((k * 7) % 3)
            zbox(icing, eave_pt[0] + side * 0.2, y, eave_pt[2] - length, eave_pt[2], 0.5, 0.7, taper=0.6)
        # Bargeboard icing along the front and back gable edges, studded with candy beads.
        for y in (-hy - over + 0.2, hy + over - 0.2):
            ridge_pt = kc.madd(top, n, thick + 0.2)
            tube(icing, [(eave_pt[0], y, eave_pt[2]), (ridge_pt[0], y, ridge_pt[2])], 0.55, 6)
            for k in range(8):
                p = kc.lerp((eave_pt[0], y, eave_pt[2]), (ridge_pt[0], y, ridge_pt[2]), (k + 0.5) / 8)
                bead = ("CandyLemon", "CandyLavender", "CandyMint", "Hearts")[k % 4]
                ball(a.part(bead), kc.add(p, (0.0, 0.0, 0.55)), 0.45, sides=6, rings=3)
    tube(icing, [(0.0, -hy - over, ridge + thick + 0.1), (0.0, hy + over, ridge + thick + 0.1)], 0.75, 6)

    # Lollipop topper on the front of the ridge, with mint leaves.
    lollipop(a, 0.0, -hy + 0.2, ridge + thick, "Icing", "Hearts", "Icing", height=1.4, radius=1.9)
    for side in (-1, 1):
        kc.slab(a.part("CandyMint"), [(0.0, 0.0), (1.4, 0.5), (2.0, 0.0), (1.4, -0.5)],
                (side * 0.3, -hy - 0.3, ridge + thick + 1.5), (side * 1.0, 0.0, 0.0), Z, (0.0, -1.0, 0.0), 0.2, W)

    # Door: mint arched frame with icing beads, pink leaf swung open outward (to the left), heart on it.
    accent = a.part("Accent")
    for side in (-1, 1):
        zbox(accent, side * (dw + 0.5), -hy - 0.3, 0.5, door_top, 0.7, 0.6)
    tube(accent, arc_points((0.0, -hy - 0.3, door_top), X, Z, dw + 0.5, 0.0, 180.0, 10), 0.35, 6)
    for k in range(11):
        p = arc_points((0.0, -hy - 0.6, door_top), X, Z, dw + 1.2, 0.0, 180.0, 11)[k]
        ball(icing, p, 0.35, sides=6, rings=3)
    # The leaf stands swung inward against the left jamb, clear of the doorway.
    leaf_x, leaf_y, leaf_len = -dw - 0.15, -hy + t + 0.05 + (2 * dw - 0.2) / 2, 2 * dw - 0.2
    zbox(a.part("Door"), leaf_x, leaf_y, F, door_top - 0.1, 0.3, leaf_len)
    heart(a.part("CandyLavender"), (leaf_x + 0.15, leaf_y, 6.5), Y, Z, X, 0.9)
    zcollide(a, "Door_Leaf", leaf_x, leaf_y, F, door_top - 0.1, 0.3, leaf_len)

    # Windows: two beside the door, one on each side wall, two on the back wall; panes repeat inside.
    for x in (-8.3, 8.3):
        window_flat(a, (x, -hy, 7.2), X, (0.0, -1.0, 0.0), inner=(x, -hy + t + 0.05, 7.2))
        window_flat(a, (x, hy, 7.2), (-1.0, 0.0, 0.0), Y, inner=(x, hy - t - 0.05, 7.2))
    for side in (-1, 1):
        window_flat(a, (side * hx, 0.0, 7.2), (0.0, side * 1.0, 0.0), (side * 1.0, 0.0, 0.0),
                    inner=(side * (hx - t - 0.05), 0.0, 7.2))
    # Hearts on the back wall, as on the sheet's rear view.
    for x, size in ((-3.0, 0.8), (0.0, 1.2), (3.0, 0.8)):
        heart(a.part("Hearts"), (x, hy, 3.4), (-1.0, 0.0, 0.0), Z, Y, size)

    # Picket fence along the front, cupcakes by the door, gumdrops on the corners.
    for side in (-1, 1):
        for k in range(8):
            zbox(icing, side * (6.6 + k * 1.1), -12.45, 0.5, 2.1, 0.55, 0.3, taper=0.7)
        zbox(icing, side * 10.45, -12.45, 1.1, 1.45, 8.4, 0.25)
        zcollide(a, "Fence_" + ("L" if side < 0 else "R"), side * 10.45, -12.45, 0.5, 2.1, 8.6, 0.6)
        cx = side * 5.3
        cone(a.part("CandyLavender"), (cx, -12.1, 0.5), 0.75, 1.1, sides=8, top=0.95)
        kc.lathe(icing, [(1.0, 0.0), (0.9, 0.4), (0.55, 0.75), (0.25, 1.1), (0.0, 1.35)], 8, W,
                 center=(cx, -12.1, 1.6))
        ball(a.part("Hearts"), (cx, -12.1, 3.1), 0.32, sides=6, rings=3)
    for (x, y), candy in zip(((-14.0, -12.0), (14.0, -12.0), (-14.0, 12.0), (14.0, 12.0)),
                             ("CandyLemon", "CandyMint", "CandyLavender", "CandyLemon")):
        cone(a.part(candy), (x, y, 0.5), 0.7, 0.9, sides=7, top=0.35)

    # Interior: table with a cupcake, two chairs, a candy shelf, a standing lollipop and gumdrops.
    table(a, 4.0, 2.0, F, treat="CandyLavender")
    chair(a, "Prop_Chair_1", 4.0, -1.4, F, 90.0)
    chair(a, "Prop_Chair_2", 4.0, 5.4, F, -90.0)
    shelf(a, "Prop_Shelf", -hx + t + 0.6, 3.0, F, 0.0, candies=("CandyLemon", "CandyMint", "CandyLavender"))
    lollipop(a, 10.6, 8.6, F, "Cushion", "CandyLavender", "CandyMint", height=3.6, radius=1.1, facing=-135.0)
    for k, (x, y) in enumerate(((-10.0, -8.0), (-8.6, -8.4), (-9.3, -7.0))):
        cone(a.part(("CandyLemon", "CandyMint", "CandyLavender")[k]), (x, y, F), 0.6, 0.8, sides=7, top=0.3)


# ---------------------------------------------------------------------------
# 11 CV3_ChocoHouse
# ---------------------------------------------------------------------------

def drips(part, rng, radius, z_top, count, skip=None, width=1.1):
    """Chocolate tongues hanging from a rim, hugging a round wall."""
    for k in range(count):
        angle = (k + 0.5) * 360.0 / count + rng.uniform(-4, 4)
        if skip and skip[0] <= angle % 360.0 <= skip[1]:
            continue
        length = rng.uniform(1.2, 2.8)
        p = polar(radius + 0.12, angle, 0.0)
        zbox(part, p[0], p[1], z_top - length, z_top, 0.3, width, angle, taper=0.55)


def build_choco_house(a):
    L = cs.CHOCO
    F, r_in, r_out, top, sides = L["floor"], L["r_in"], L["r_out"], L["wall_top"], L["sides"]
    door_top = F + L["door_h"]
    rng = a.rng
    cake, glaze, cream, waffle = a.part("Cake"), a.part("Glaze"), a.part("Cream"), a.part("Waffle")

    # Puddle, plinth, floor.
    outline = [(14.6 + 0.7 * math.sin(5 * rad(360 * k / 20) + 0.6) + rng.uniform(-0.2, 0.2), 360 * k / 20)
               for k in range(20)]
    rings = [[polar(r * s, ang, z) for r, ang in outline] for s, z in ((1.0, 0.0), (0.97, 0.25))]
    kc.loft(a.part("Puddle"), rings, W)
    disc(a.part("Plinth"), (0, 0, 0), 12.8, 0.6, sides=16)
    disc(a.part("Floor"), (0, 0, 0.6), r_in + 0.2, F - 0.6, sides=16)
    disc_collision(a, "Floor", 12.6, 0.0, F)

    # Tier 1: the enterable room. Door between panels 11 and 12 (247.5 to 292.5 degrees, facing -Y).
    round_wall(a, cake, "Wall", r_in, r_out, sides, 0.6, top, {11: door_top, 12: door_top})
    disc(cake, (0, 0, top), r_out + 0.2, 1.0, sides=16)
    disc_collision(a, "Ceiling", r_out, top, top + 1.0)
    disc(glaze, (0, 0, top + 1.0), r_out + 0.45, 0.3, sides=16)
    drips(glaze, rng, r_out, top + 1.2, 22, skip=(250.0, 290.0))
    for z in (4.2, 8.6):
        arc_tube(cream, z, r_out + 0.15, 0.35, 296.0, 244.0 + 360.0, count=14)
    ring_tube(cream, (0, 0, 12.4), r_out + 0.15, 0.35)

    # Tiers 2 and 3, turret and its waffle cone.
    z = top + 1.3
    for radius, height, name in ((9.4, 5.6, "Tier2"), (6.3, 4.4, "Tier3")):
        disc(cake, (0, 0, z), radius, height, sides=16)
        disc(glaze, (0, 0, z + height), radius + 0.3, 0.3, sides=16)
        drips(glaze, rng, radius, z + height + 0.2, 14 if radius > 8 else 10)
        ring_tube(cream, (0, 0, z + height * 0.45), radius + 0.12, 0.32, segments=16)
        disc_collision(a, name, radius, z, z + height, suffixes="AB")
        z += height + 0.3
    disc(cake, (0, 0, z), 2.7, 5.2, sides=10)
    zcollide(a, "Turret", 0, 0, z, z + 5.2, 3.8, 3.8)
    for angle in (-90.0, 30.0, 150.0):
        p = polar(2.7, angle, 0.0)
        zbox(glaze, p[0], p[1], z + 1.8, z + 3.4, 0.3, 1.1, angle)
    ring_tube(cream, (0, 0, z + 5.2), 2.8, 0.4, segments=12)
    cone(waffle, (0, 0, z + 5.2), 3.3, 7.2, sides=10)
    for frac in (0.25, 0.5, 0.72):
        ring_tube(a.part("Rolls"), (0, 0, z + 5.2 + 7.2 * frac), 3.3 * (1 - frac) + 0.05, 0.14, segments=10, sides=4)
    ball(cream, (0, 0, z + 12.4), 0.5, sides=6, rings=3)

    # Waffle-cone turrets on the sides, a rolled wafer column with a cookie swirl, a back turret.
    for name, angle, radius, height, cone_h in (("Tower_L", 212.0, 1.7, 15.0, 6.5), ("Tower_Back", 75.0, 1.5, 12.0, 5.5)):
        x, y, _ = polar(13.4, angle, 0.0)
        disc(cake, (x, y, 0.0), radius, height, sides=8)
        for zz in (4.5, 9.0, height - 0.6):
            ring_tube(cream, (x, y, zz), radius + 0.1, 0.25, segments=8, sides=4)
        cone(waffle, (x, y, height), radius + 0.5, cone_h, sides=8)
        zcollide(a, name, x, y, 0.0, height, 2 * radius, 2 * radius)
    x, y, _ = polar(13.4, 328.0, 0.0)
    disc(a.part("Rolls"), (x, y, 0.0), 1.5, 14.0, sides=8)
    for k in range(6):  # cream spiral on the wafer column
        tube(cream, [(x + 1.55 * math.cos(rad(k * 70 + j * 35)), y + 1.55 * math.sin(rad(k * 70 + j * 35)),
                      1.0 + k * 2.2 + j * 1.1) for j in range(3)], 0.22, 4)
    out = (0.0, -1.0, 0.0)
    kc.lathe(a.part("Rolls"), [(2.3, 0.0), (2.3, 0.8)], 12, W, center=(x, y + 0.4, 16.0), frame=(X, Z, out))
    kc.torus(cream, (x, y - 0.45, 16.0), X, Z, 1.3, 0.22, 12, 4, W)
    kc.torus(cream, (x, y - 0.45, 16.0), X, Z, 0.6, 0.18, 8, 4, W)
    zcollide(a, "Tower_R", x, y, 0.0, 14.0, 3.0, 3.0)

    # Cookie rolls and truffles around the base, leaving the door path free.
    for k in range(12):
        angle = 15.0 + 30.0 * k
        if 235.0 <= angle <= 305.0 or abs(angle - 212.0) < 12 or abs(angle - 328.0) < 12 or abs(angle - 75) < 12:
            continue
        outward = (math.cos(rad(angle)), math.sin(rad(angle)), 0.0)
        tangent = (-outward[1], outward[0], 0.0)
        centre = polar(14.0, angle, 1.15)
        kc.lathe(a.part("Rolls"), [(1.15, 0.0), (1.15, 0.9)], 10, W, center=kc.madd(centre, outward, -0.45),
                 frame=(tangent, Z, outward))
        kc.torus(cream, kc.madd(centre, outward, 0.5), tangent, Z, 0.6, 0.15, 8, 4, W)
        ball(glaze, polar(14.6, angle + 13.0, 0.57), 0.7, sides=6, rings=3, squash=0.8)

    # Door: cream arch frame, chocolate-bar leaf swung open outward, waffle ramp.
    dw = 3.6
    for side in (-1, 1):
        zbox(cream, side * 4.55, -r_out - 0.35, 0.6, door_top, 0.9, 0.7)
    tube(cream, arc_points((0.0, -r_out - 0.35, door_top), X, Z, 4.55, 0.0, 180.0, 10), 0.45, 6)
    # Chocolate-bar leaf swung inward against the left jamb, its segments facing the room.
    leaf_x, leaf_y = -4.1, -r_in * math.cos(rad(22.5)) + 0.15 + dw
    zbox(a.part("Door"), leaf_x, leaf_y, F, door_top - 0.2, 0.35, 2 * dw)
    for row in range(3):
        for col in (-1, 1):
            zbox(a.part("DoorBar"), leaf_x + 0.2, leaf_y + col * 1.6, F + 0.8 + row * 2.9, F + 3.2 + row * 2.9,
                 0.15, 2.6)
    zcollide(a, "Door_Leaf", leaf_x, leaf_y, F, door_top - 0.2, 0.35, 2 * dw)
    ramp = [(-4.0, -15.6, 0.0), (4.0, -15.6, 0.0), (4.0, -12.5, 0.0), (-4.0, -12.5, 0.0),
            (-4.0, -15.6, 0.12), (4.0, -15.6, 0.12), (4.0, -12.5, F), (-4.0, -12.5, F)]
    kc.hexahedron(waffle, ramp, W)
    for k in range(3):
        y0 = -15.1 + k * 1.0
        h = 0.12 + (F - 0.12) * (y0 + 15.6) / 3.1
        zbox(a.part("Rolls"), 0.0, y0, h - 0.02, h + 0.06, 7.6, 0.18)
    pitch = math.degrees(math.atan2(F - 0.12, 3.1))
    collide(a, "Ramp", (0.0, -14.05, (F + 0.12) / 2 - 0.2), (8.0, 3.2, 0.5), (pitch, 0.0, 0.0))

    # Interior: round table with treats, three stools, a candy shelf on the back wall, a big lollipop.
    table(a, 4.0, 2.5, F, top="Cushion", treat="CandyPink")
    chair(a, "Prop_Chair_1", 7.0, 2.5, F, 180.0)
    chair(a, "Prop_Chair_2", 4.0, 5.5, F, -90.0, back=False)
    chair(a, "Prop_Chair_3", 1.0, 2.5, F, 0.0, back=False)
    shelf(a, "Prop_Shelf", 0.0, 9.6, F, -90.0, width=6.0, candies=("CandyPink", "CandyMint"))
    lollipop(a, -7.0, 4.0, F, "Furniture", "CandyPink", "CandyMint", height=3.8, radius=1.3, facing=-30.0)
    for k, (x, y) in enumerate(((-6.5, -5.5), (-5.4, -6.4), (-7.2, -6.6))):
        ball(a.part(("CandyMint", "CandyPink", "Cushion")[k]), (x, y, F + 0.55), 0.6, sides=6, rings=3, squash=0.9)


# ---------------------------------------------------------------------------
# 03 CV3_CaramelTower
# ---------------------------------------------------------------------------

def helix_stripes(part, r, z0, z1, phases, skip):
    """Swirl ribbons on a round wall: slanted segments one wall panel wide, skipping the openings."""
    step, rise, band = 22.5, 1.5, 1.3
    for phase in phases:
        k = 0
        while True:
            za = z0 + k * rise
            if za + rise + band > z1:
                break
            a0 = phase + k * step
            start = a0 % 360.0
            if not any(za < top and (start < hi and start + step > lo or start - 360.0 < hi and start + step - 360.0 > lo)
                       for lo, hi, top in skip):
                corners = []
                for dz in (0.0, band):
                    for rr, a, zz in ((r, a0, za), (r + 0.18, a0, za), (r + 0.18, a0 + step, za + rise),
                                      (r, a0 + step, za + rise)):
                        corners.append(polar(rr, a, zz + dz))
                kc.hexahedron(part, corners, W)
            k += 1


def build_caramel_tower(a):
    L = cs.TOWER
    F, r1i, r1o, U, r2i, r2o, ceil = (L["floor"], L["r1_in"], L["r1_out"], L["upper"], L["r2_in"], L["r2_out"],
                                      L["ceiling"])
    sides, door_top = L["sides"], L["floor"] + L["door_h"]
    balcony_top = U + L["door_h"]
    rng = a.rng
    walls, cream, trim = a.part("Walls"), a.part("Cap"), a.part("Trim")

    # Base: whipped cream disc and cloud puffs, floor inside.
    disc(a.part("Base"), (0, 0, 0), r1o + 0.6, 0.5, sides=16)
    for k in range(18):
        angle = k * 20.0 + 10.0
        if 240.0 <= angle <= 300.0:
            continue
        size = rng.uniform(1.1, 1.6)
        ball(a.part("Base"), polar(r1o + 0.5, angle, size * 0.75), size, sides=7, rings=3, squash=0.75)
    disc(a.part("Floor"), (0, 0, 0.5), r1i + 0.1, F - 0.5, sides=16)
    disc_collision(a, "Floor", r1o + 0.4, 0.0, F)

    # Lower tier (door between panels 11 and 12), cream ledge with the upper floor, upper tier with the balcony
    # opening between panels 3 and 4, then the ceiling disc under the cap.
    round_wall(a, walls, "Wall1", r1i, r1o, sides, 0.5, U - 1.0, {11: door_top, 12: door_top})
    for k in range(sides):
        panel(a.part("Ledge"), r2i, r1o + 0.5, k * 22.5, (k + 1) * 22.5, U - 1.0, U)
        c = polar((r2i + r1o + 0.5) / 2, (k + 0.5) * 22.5, 0.0)
        zcollide(a, f"Ledge_{k:02d}", c[0], c[1], U - 1.0, U, r1o + 0.5 - r2i, 2 * (r1o + 0.5) * math.sin(rad(11.25)) + 0.05,
                 (k + 0.5) * 22.5)
    arc_tube(a.part("Ledge"), U - 0.2, r1o + 0.5, 0.55, 118.0, 62.0 + 360.0, count=18)
    round_wall(a, walls, "Wall2", r2i, r2o, sides, U, ceil, {3: balcony_top, 4: balcony_top})
    disc(cream, (0, 0, ceil), r2o + 0.1, 1.0, sides=16)
    disc_collision(a, "Ceiling", r2o, ceil, ceil + 1.0)

    # Upper floor: the back half (y >= 0); the front half stays open over the stair.
    semicircle(a.part("Floor"), (0.0, 0.0, U - 1.0), X, Y, Z, r2i + 0.5, 1.0, count=13)
    strips = (0.0, 3.0, 5.5, 7.2, 8.4)
    for k in range(len(strips) - 1):
        y0, y1 = strips[k], strips[k + 1]
        half = math.sqrt(max(0.0, (r2i + 0.5) ** 2 - y1 ** 2)) if y1 < r2i + 0.5 else 0.0
        zcollide(a, f"Upper_Floor_{k}", 0.0, (y0 + y1) / 2, U - 1.0, U, 2 * max(half, 2.0), y1 - y0)

    # Swirl stripes, dormer roofs, round windows.
    helix_stripes(a.part("Stripes"), r1o, 0.6, U - 1.0, (0.0, 120.0, 240.0), ((247.5, 292.5, door_top + 1.0),))
    helix_stripes(a.part("Stripes"), r2o, U, ceil, (60.0, 180.0, 300.0), ((67.5, 112.5, balcony_top + 1.0),))
    for angle, r, z in ((205.0, r1o, 11.8), (335.0, r1o, 11.8), (20.0, r2o, 27.5)):
        p = polar(r + 0.9, angle, z)
        cone(trim, p, 2.0, 1.8, sides=4, phase=rad(angle + 45.0))
        disc(a.part("Ledge"), p, 1.6, 0.25, sides=8)
    for angle, z, size, r_out, r_in in ((300.0, 7.5, 1.3, r1o, r1i), (125.0, 6.5, 1.2, r1o, r1i),
                                         (250.0, 22.0, 1.3, r2o, r2i), (330.0, 24.0, 1.1, r2o, r2i),
                                         (165.0, 23.0, 1.2, r2o, r2i)):
        round_window(a, angle, z, size, r_out, r_in)

    # Cap: stacked whipped-cream rolls with pink bands, a strawberry and leaves, cherries on the rim.
    profile = [(r2o + 0.2, ceil + 0.5), (12.6, ceil + 1.4), (13.3, ceil + 2.8), (13.0, ceil + 4.0),
               (11.9, ceil + 4.6), (12.3, ceil + 5.6), (11.6, ceil + 6.8), (9.6, ceil + 7.5), (10.1, ceil + 8.4),
               (9.0, ceil + 9.6), (6.8, ceil + 10.3), (7.0, ceil + 11.0), (5.2, ceil + 12.0), (2.6, ceil + 12.8),
               (0.0, ceil + 13.1)]
    kc.lathe(cream, profile, 16, W, phase=rad(5.0))
    band = a.part("CapBand")
    ring_tube(band, (0, 0, ceil + 4.25), 12.55, 0.55, segments=20, sides=6)
    ring_tube(band, (0, 0, ceil + 7.9), 9.95, 0.42, segments=16, sides=5)
    ring_tube(band, (0, 0, ceil + 10.6), 7.0, 0.35, segments=14, sides=5)
    sb = ceil + 12.7
    kc.lathe(a.part("Strawberry"), [(1.2, sb), (2.3, sb + 1.2), (2.4, sb + 2.4), (1.7, sb + 3.8), (0.0, sb + 4.9)],
             8, W)
    star = [(math.cos(rad(36 * k)) * (1.7 if k % 2 == 0 else 0.6), math.sin(rad(36 * k)) * (1.7 if k % 2 == 0 else 0.6))
            for k in range(10)]
    kc.slab(a.part("Leaf"), star, (0.0, 0.0, sb + 4.4), X, Y, Z, 0.25, W)
    tube(a.part("Leaf"), [(0.0, 0.0, sb + 4.6), (0.3, 0.0, sb + 5.4)], 0.2, 4)
    for angle in (150.0, 30.0):
        hang = polar(12.4, angle, ceil + 0.8)
        for k, dx in enumerate((-0.9, 0.9)):
            t = (-math.sin(rad(angle)), math.cos(rad(angle)), 0.0)
            berry = kc.add(polar(12.6, angle, ceil - 2.8 - 0.4 * k), kc.mul(t, dx))
            tube(a.part("Leaf"), [hang, kc.add(berry, (0.0, 0.0, 0.6))], 0.1, 4)
            ball(a.part("Strawberry"), berry, 0.75, sides=8, rings=4)

    # Door: frosting arch, wooden arched leaf swung open outward.
    for side in (-1, 1):
        zbox(cream, side * 4.45, -r1o - 0.3, 0.5, door_top, 0.9, 0.7)
    tube(cream, arc_points((0.0, -r1o - 0.3, door_top), X, Z, 4.45, 0.0, 180.0, 10), 0.5, 6)
    # Wooden leaf swung inward against the left jamb, kept under the lowest stair step above it.
    leaf_x, leaf_y = -3.85, -r1i * math.cos(rad(22.5)) + 0.15 + 3.4
    zbox(a.part("Door"), leaf_x, leaf_y, F, door_top - 0.6, 0.35, 6.8)
    for k in (-2, 0, 2):
        zbox(a.part("Furniture"), leaf_x + 0.22, leaf_y + k * 1.1, F + 0.4, door_top - 1.0, 0.12, 0.25)
    zcollide(a, "Door_Leaf", leaf_x, leaf_y, F, door_top - 0.6, 0.35, 6.8)

    # Spiral stair around a candy-cane newel: 16 steps of 1 stud, a full turn, the top step flush with the
    # upper floor. Steps 0-7 run under the upper floor (y > 0), steps 8-15 rise through the open front half.
    zbox(a.part("Newel"), 0.0, 0.0, F, U + 2.0, 1.8, 1.8, 0.0)
    for k in range(9):
        disc(a.part("NewelBand"), (0.0, 0.0, F + 1.0 + k * 1.9), 1.0, 0.45, sides=8)
    ball(a.part("NewelBand"), (0.0, 0.0, U + 2.4), 0.8, sides=8, rings=4)
    zcollide(a, "Newel", 0.0, 0.0, F, U + 2.0, 1.8, 1.8)
    inner, outer, width = L["step_in"], L["step_out"], L["step_width"]
    for i in range(L["steps"]):
        angle = 11.25 + 22.5 * i
        c = polar((inner + outer) / 2, angle, 0.0)
        top = F + (i + 1) * 1.0
        zbox(a.part("Stairs"), c[0], c[1], top - 1.0, top, outer - inner, width, angle)
        zcollide(a, f"Stair_{i:02d}", c[0], c[1], top - 1.0, top, outer - inner, width, angle)

    # Railings: along the open edge of the upper floor (leaving the stair exit free) and round the balcony.
    def rail(name, x0, x1, y0, y1):
        length = math.hypot(x1 - x0, y1 - y0)
        yaw = math.degrees(math.atan2(y1 - y0, x1 - x0))
        count = max(2, int(length / 1.8) + 1)
        for k in range(count):
            px, py = x0 + (x1 - x0) * k / (count - 1), y0 + (y1 - y0) * k / (count - 1)
            zbox(trim, px, py, U, U + 3.0, 0.35, 0.35, yaw)
        zbox(trim, (x0 + x1) / 2, (y0 + y1) / 2, U + 2.7, U + 3.15, length + 0.35, 0.4, yaw)
        zcollide(a, name, (x0 + x1) / 2, (y0 + y1) / 2, U, U + 3.15, length + 0.35, 0.4, yaw)

    rail("Rail_Upper_L", -r2i + 0.2, -1.2, 0.0, 0.0)
    rail("Rail_Upper_R", outer + 0.5, r2i - 0.2, 0.0, 0.0)
    zbox(a.part("Ledge"), 0.0, 11.5, U - 1.0, U, 9.2, 5.6)
    zcollide(a, "Balcony_Floor", 0.0, 11.5, U - 1.0, U, 9.2, 5.6)
    rail("Rail_Balcony_F", -4.4, 4.4, 14.1, 14.1)
    rail("Rail_Balcony_L", -4.4, -4.4, 9.4, 14.1)
    rail("Rail_Balcony_R", 4.4, 4.4, 9.4, 14.1)

    # Interior: ground floor table, two stools and a shelf around the stair; upper floor table, stool, shelf.
    table(a, -7.4, -2.8, F, radius=1.6, treat="CandyLemon")
    chair(a, "Prop_Chair_1", -8.0, 0.8, F, -80.0, back=False)
    chair(a, "Prop_Chair_2", -5.9, -6.3, F, 50.0, back=False)
    shelf(a, "Prop_Shelf", *polar(8.9, 135.0, 0.0)[:2], F, -45.0, width=4.0, height=5.0,
          candies=("CandyLemon", "Cushion"))
    table(a, -4.6, 4.4, U, radius=1.5, name="Prop_Upper_Table", top="Cushion")
    chair(a, "Prop_Upper_Chair", -6.9, 2.6, U, 40.0)
    shelf(a, "Prop_Upper_Shelf", *polar(7.4, 32.0, 0.0)[:2], U, 212.0, width=3.6, height=5.0,
          candies=("CandyLemon", "Cushion"))


# ---------------------------------------------------------------------------
# 02 CV3_BananaRaft
# ---------------------------------------------------------------------------

SECTION = [(1.0, 0.0), (0.8, -0.7), (0.35, -1.0), (-0.35, -1.0), (-0.8, -0.7), (-1.0, 0.0), (-0.85, 0.55),
           (0.85, 0.55)]
HULL_LENGTH = 6.5


def hull_ring(y, scale=1.0):
    t = y / HULL_LENGTH
    w = 3.5 * max(0.05, 1.0 - t ** 4) ** 0.5
    zc = 0.9 * t ** 4
    h = 1.25 * (1.0 - 0.4 * t * t)
    return [(fx * w * scale, y, zc + fz * h * scale) for fx, fz in SECTION]


def build_banana_raft(a):
    hull, choc = a.part("Hull"), a.part("Choc")
    stations = (-5.9, -5.0, -3.6, -1.8, 0.0, 1.8, 3.6, 5.0, 5.9)
    kc.loft(hull, [hull_ring(y) for y in stations], W, start=(0.0, -HULL_LENGTH, 1.15), end=(0.0, HULL_LENGTH, 1.15))
    # Gunwale: a closed banana-peel roll round the deck, curling up at the ends.
    rings = []
    count, rx, ry, minor = 24, 3.2, 5.85, 0.72
    for i in range(count):
        s = math.tau * i / count
        p = (rx * math.cos(s), ry * math.sin(s), 0.0)
        p = (p[0], p[1], 0.75 + 0.95 * (p[1] / HULL_LENGTH) ** 4)
        outward = kc.unit((math.cos(s) / rx, math.sin(s) / ry, 0.0))
        rings.append([kc.add(p, kc.add(kc.mul(outward, minor * math.cos(kc.TAU * k / 6)),
                                        (0.0, 0.0, minor * math.sin(kc.TAU * k / 6)))) for k in range(6)])
    kc.loft_closed(hull, rings, W)
    # Brown banana ends.
    for sign in (-1, 1):
        kc.lathe(a.part("Tips"), [(0.55, 0.0), (0.4, 0.5), (0.0, 0.75)], 6, W,
                 center=(0.0, sign * (HULL_LENGTH - 0.15), 1.25), frame=(X, Z, (0.0, sign * 1.0, 0.0)))
    # Chocolate straps round the hull.
    for y in (-2.2, 4.4):
        kc.loft(choc, [hull_ring(y - 0.3, 1.05), hull_ring(y + 0.3, 1.05)], W)
        for side in (-1, 1):  # the strap wraps over the peel roll too
            gx = side * 3.2 * math.sqrt(max(0.0, 1.0 - (y / 5.85) ** 2))
            zbox(choc, gx, y, 0.0, 1.62 + 0.95 * (y / HULL_LENGTH) ** 4, 1.75, 0.6)
    # Floaters: chocolate rims with pink faces and hearts, two per side.
    for side in (-1, 1):
        for y in (-3.4, 3.0):
            out = (side * 1.0, 0.0, 0.0)
            frame = (Y, Z, out)
            kc.lathe(choc, [(1.0, 0.0), (1.0, 0.35)], 10, W, center=(side * 3.75, y, 0.25), frame=frame)
            kc.lathe(a.part("Floaters"), [(0.72, 0.0), (0.72, 0.18)], 10, W, center=(side * 4.08, y, 0.25), frame=frame)
            heart(a.part("Hearts"), (side * 4.24, y, 0.25), (0.0, -side * 1.0, 0.0), Z, out, 0.38, 0.08)
    # Seat: pink quilted cushion and backrest. The rider faces -Y.
    sx, sy, sz = cs.RAFT["seat"]
    zbox(a.part("Seat"), sx, sy, 0.6, sz, 3.0, 3.0)
    for dx in (-0.75, 0.75):
        zbox(a.part("Seat"), sx + dx, sy, sz - 0.05, sz + 0.0, 1.3, 2.7)
    zbox(a.part("Seat"), sx, 3.45, sz - 0.1, 2.9, 3.2, 0.6, taper=0.92)
    collide(a, "Hull", (0.0, 0.0, -0.28), (7.0, 12.4, 1.94))
    collide(a, "Gunwale_L", (-3.2, 0.0, 0.9), (1.5, 9.6, 1.5))
    collide(a, "Gunwale_R", (3.2, 0.0, 0.9), (1.5, 9.6, 1.5))
    collide(a, "Gunwale_Bow", (0.0, -5.8, 1.1), (5.2, 1.5, 1.5))
    collide(a, "Gunwale_Stern", (0.0, 5.8, 1.1), (5.2, 1.5, 1.5))
    zcollide(a, "Seat_Base", sx, sy, 0.6, sz, 3.0, 3.0)
    zcollide(a, "Backrest", sx, 3.45, sz - 0.1, 2.9, 3.2, 0.6)
    # Bow: three scoops (pink, vanilla, pink) with chocolate sauce, whipped cream, cherries and sprinkles.
    scoops = ((-1.95, -3.9, 1.85, "ScoopPink"), (0.0, -4.35, 2.15, "ScoopVanilla"), (1.95, -3.9, 1.85, "ScoopPink"))
    rng = a.rng
    for x, y, z, part in scoops:
        ball(a.part(part), (x, y, z), 1.3, sides=10, rings=5, squash=0.92)
        kc.lathe(choc, [(1.2, 0.62), (0.95, 0.98), (0.5, 1.19), (0.0, 1.24)], 10, W, center=(x, y, z))
        for k in range(4):
            ang = 40.0 + 90.0 * k + rng.uniform(-15, 15)
            p = (x + 1.12 * math.cos(rad(ang)), y + 1.12 * math.sin(rad(ang)), z)
            zbox(choc, p[0], p[1], z + 0.7 - rng.uniform(0.6, 1.0), z + 0.7, 0.35, 0.35, ang, taper=0.6)
        for k in range(5):
            ang = rng.uniform(0, 360)
            p = (x + 0.6 * math.cos(rad(ang)), y + 0.6 * math.sin(rad(ang)), z + 1.13)
            zbox(a.part("Sprinkles"), p[0], p[1], p[2] - 0.08, p[2] + 0.08, 0.45, 0.14, ang)
    vx, vy, vz = scoops[1][:3]
    whip = [(1.0, 0.0), (0.92, 0.35), (0.62, 0.55), (0.7, 0.85), (0.38, 1.15), (0.0, 1.55)]
    kc.lathe(a.part("Cream"), whip, 8, W, center=(vx, vy, vz + 1.2), phase=rad(22.5))
    for x, y, z in ((-1.95, -3.9, 1.85 + 1.75), (1.95, -3.9, 1.85 + 1.75), (vx, vy, vz + 2.95)):
        ball(a.part("Cherry"), (x, y, z), 0.55, sides=8, rings=4)
        tube(a.part("Stem"), [(x, y, z + 0.4), (x + 0.15, y + 0.1, z + 1.0), (x + 0.45, y + 0.25, z + 1.5)], 0.08, 4)
    # Stern: a small whipped-cream dollop with a cherry.
    kc.lathe(a.part("Cream"), [(0.85, 0.0), (0.75, 0.3), (0.45, 0.55), (0.0, 0.9)], 8, W, center=(0.0, 5.0, 0.8))
    ball(a.part("Cherry"), (0.0, 5.0, 2.05), 0.45, sides=8, rings=4)
    tube(a.part("Stem"), [(0.0, 5.0, 2.4), (0.2, 5.15, 3.0)], 0.07, 4)
    collide(a, "Bow_Scoops", (0.0, -4.0, 2.2), (6.6, 3.0, 3.0))
    a.anchors["SeatAnchor"] = (sx, sy, sz)


# ---------------------------------------------------------------------------
# Kit table and pipeline
# ---------------------------------------------------------------------------

KIT = {
    "CV3_SweetHouse": {"build": build_sweet_house, "seed": 11, "colors": cs.colors(cs.SWEET_COLORS)},
    "CV3_ChocoHouse": {"build": build_choco_house, "seed": 21, "colors": cs.colors(cs.CHOCO_COLORS)},
    "CV3_CaramelTower": {"build": build_caramel_tower, "seed": 31, "colors": cs.colors(cs.TOWER_COLORS)},
    "CV3_BananaRaft": {"build": build_banana_raft, "seed": 41, "colors": cs.colors(cs.RAFT_COLORS)},
}
for _name, _entry in KIT.items():
    _entry["size"] = cs.SPECS[_name]["size"]


def make_kit():
    kit = bk.Kit(cs.SLUG, "CV3", GENERATOR, KIT, MODE_VARIABLE)
    kit.out_dir, kit.export_dir = cs.BLEND_DIR, cs.EXPORT_DIR
    kit.blend, kit.report, kit.geometry, kit.roundtrip = cs.BLEND, cs.REPORT, cs.GEOMETRY, cs.ROUNDTRIP
    kit.sheet, kit.lineup = cs.SHEET, cs.LINEUP
    return kit


def author(name):
    """Build one asset at its authored size (no fitting: doors, floors and the seat are placed in studs)."""
    asset = kc.Asset(name, seed=KIT[name]["seed"])
    asset.collision, asset.anchors = [], {}
    KIT[name]["build"](asset)
    asset.fit = (1.0, 1.0, 1.0)
    return asset


def asset_triangle_lists(asset):
    """Coordinate triangles per part label, from the authored faces (dry run) ."""
    return {label: [[part.vertices[i] for i in tri] for tri in bk.triangulate(part)]
            for label, part in asset.parts.items()}


def checks(name, by_part, collision):
    """Doorway, room and seat measurements shared by the dry run and the report."""
    spec = cs.SPECS[name]
    every = [t for tris in by_part.values() for t in tris]
    out = {}
    if spec["kind"] == "building":
        shell = [t for label in spec["shell"] for t in by_part[label]]
        out["doors"] = []
        for door in spec["doors"]:
            found = cs.doorway_clearance(every, door)
            out["doors"].append({**{k: (list(v) if isinstance(v, tuple) else v) for k, v in door.items()},
                                 "measured": {k: round(v, 4) if isinstance(v, float) else v for k, v in found.items()},
                                 "roblox_center": cs.to_roblox((door["center_x"], sum(door["band_y"]) / 2,
                                                                door["floor"]))})
        out["rooms"] = []
        for room in spec["rooms"]:
            ceiling = cs.room_ceiling(shell, room)
            levels = cs.floor_levels(by_part["Floor"], room)
            out["rooms"].append({**{k: (list(map(list, v)) if k == "rect" else v) for k, v in room.items()},
                                 "ceiling_measured": round(ceiling, 4),
                                 "floor_measured": [round(min(levels), 4), round(max(levels), 4)]})
    else:
        seat = spec["seat"]
        out["seat_anchor"] = {"name": "SeatAnchor", "blender": list(seat["position"]),
                              "roblox": cs.to_roblox(seat["position"]),
                              "forward_blender": list(seat["forward"]), "forward_roblox": [0.0, 0.0, -1.0],
                              "headroom_box": [list(seat["headroom"][0]), list(seat["headroom"][1])]}
    out["collision_boxes"] = collision
    out["collision_roblox"] = [cs.roblox_box(b) for b in collision]
    return out


def dry_run():
    for name in KIT:
        asset = author(name)
        low, high = asset.bbox()
        by_part = asset_triangle_lists(asset)
        print(name, "tris", asset.triangles, "size", [round(b - a, 2) for a, b in zip(low, high)],
              "min", [round(v, 2) for v in low], "open", sum(bk.open_edges(p) for p in asset.parts.values()))
        print("   parts", {label: part.triangles for label, part in asset.parts.items()})
        found = checks(name, by_part, asset.collision)
        for door in found.get("doors", []):
            print("   door", door["name"], {k: door["measured"][k] for k in ("width", "height", "gap_low_x", "gap_high_x")})
        for room in found.get("rooms", []):
            print("   room", room["name"], "ceiling", room["ceiling_measured"], "floor", room["floor_measured"])
        print("   collision boxes", len(asset.collision))


# ---------------------------------------------------------------------------
# Blender stage
# ---------------------------------------------------------------------------

def brighter_studio():
    """The chocolate palette disappears in the shared studio light. Preview renders only."""
    shared = kc.add_studio

    def studio(scene, prefix="SP"):
        camera = shared(scene, prefix)
        bk.bpy.data.lights[f"{prefix}_Key"].energy = 3.6
        bk.bpy.data.lights[f"{prefix}_Fill"].energy = 1.4
        scene.world.node_tree.nodes["Background"].inputs[1].default_value = 1.3
        return camera

    kc.add_studio = studio


def collision_preview(name, boxes, scene):
    """Wire boxes of the collision data, in the .blend only (never exported, never rendered)."""
    bpy = bk.bpy
    collection = bpy.data.collections.new(f"{name}_CollisionPreview")
    scene.collection.children.link(collection)
    for box in boxes:
        part = kc.Part(box["name"])
        obox(part, box["center"], box["size"], box["rot_deg"])
        mesh = bpy.data.meshes.new(f"{name}_Col_{box['name']}")
        mesh.from_pydata(part.vertices, [], part.faces)
        obj = bpy.data.objects.new(f"{name}_Col_{box['name']}", mesh)
        obj.display_type = "WIRE"
        obj.hide_render = True
        collection.objects.link(obj)
    collection.hide_render = True


def render_cutaway(kit, name, collection, path, y_cut, elevation, avatar_at, hide=()):
    """Section view: every visual mesh cut at y = y_cut with the front removed, plus a 5-stud avatar block."""
    import bmesh
    bpy = bk.bpy
    scene = bpy.data.scenes.new(f"CV3_Cut_{name}")
    kc.set_render_engine(scene)
    camera = kc.add_studio(scene, f"CV3Cut{name[4:]}")
    points = []
    for obj in collection.objects:
        if obj.type != "MESH" or obj.name[len(name) + 1:] in hide:
            continue
        bm = bmesh.new()
        bm.from_mesh(obj.data)
        if y_cut is not None:
            geom = list(bm.verts) + list(bm.edges) + list(bm.faces)
            bmesh.ops.bisect_plane(bm, geom=geom, plane_co=(0.0, y_cut, 0.0), plane_no=(0.0, 1.0, 0.0),
                                   clear_inner=True)
        mesh = bpy.data.meshes.new(f"{obj.name}_Cut")
        bm.to_mesh(mesh)
        bm.free()
        mesh.materials.append(obj.data.materials[0])
        copy = bpy.data.objects.new(f"{obj.name}_Cut", mesh)
        scene.collection.objects.link(copy)
        points.extend(v.co.copy() for v in mesh.vertices)
    for k, spot in enumerate(avatar_at):
        block, _, _ = kc.make_scale_block(scene, f"CV3Cut{name[4:]}{k}")
        block.location = spot
    saved = kc.CAMERA_ELEVATION
    kc.CAMERA_ELEVATION = math.radians(elevation)
    try:
        kc.frame_camera(camera, points, 800, 800, margin=1.08)
    finally:
        kc.CAMERA_ELEVATION = saved
    kc.render_to(scene, path, 800, 800)


CUTAWAYS = {
    "CV3_SweetHouse": {"y_cut": -4.0, "elevation": 32.0, "avatar": [(0.0, -2.0, 0.6)], "hide": ()},
    "CV3_ChocoHouse": {"y_cut": -1.0, "elevation": 30.0, "avatar": [(-2.0, 1.0, 0.7)], "hide": ()},
    "CV3_CaramelTower": {"y_cut": -1.5, "elevation": 22.0, "avatar": [(-6.5, 3.5, 0.6), (2.0, 4.0, 16.6)],
                         "hide": ()},
    "CV3_BananaRaft": {"y_cut": None, "elevation": 55.0, "avatar": [], "hide": ()},
}


def build(kit):
    bpy = bk.bpy
    kit.out_dir.mkdir(parents=True, exist_ok=True)
    kit.export_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "CV3Kit"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["studs_per_blender_unit"] = 1.0
    scene["status"] = "unvalidated: never imported into Roblox"

    authored = {name: author(name) for name in kit.order}
    materials = {}
    for name, asset in authored.items():
        for label in asset.parts:
            materials[f"{name}_{label}"] = kc.make_material(f"{name}_{label}", KIT[name]["colors"][label][1])
    built = {}
    for name, asset in authored.items():
        collection, root, meshes = bk.assemble(kit, name, asset, materials, scene)
        for anchor, location in asset.anchors.items():
            empty = bpy.data.objects.new(anchor, None)
            empty.empty_display_type = "SINGLE_ARROW"
            empty.empty_display_size = 2.0
            empty.location = location  # identity rotation: the rider faces Blender -Y, Roblox -Z
            empty["forward"] = "-Y (Roblox -Z)"
            collection.objects.link(empty)
            empty.parent = root
        collision_preview(name, asset.collision, scene)
        built[name] = (collection, root, meshes)
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()

    report, dumps = {}, {}
    for name, asset in authored.items():
        collection, root, meshes = built[name]
        entry, dump = bk.measure(kit, name, asset, {}, root, meshes, depsgraph)
        entry["fbx"] = {"model": kit.rel(kit.export_dir / f"{name}.fbx")}
        entry["render"] = kit.rel(kit.out_dir / f"{name}.png")
        entry["cutaway"] = kit.rel(kit.out_dir / f"{name}_cutaway.png")
        entry["sheet"] = cs.SPECS[name]["sheet"]
        by_part = {p[len(name) + 1:]: [[d["vertices"][i] for i in t] for t in d["triangles"]]
                   for p, d in dump["parts"].items()}
        entry.update(checks(name, by_part, asset.collision))
        entry["anchors"] = {k: [round(c, 4) for c in v] for k, v in asset.anchors.items()}
        report[name], dumps[name] = entry, dump
        bk.export_fbx(collection, root, kit.export_dir / f"{name}.fbx")

    collections = {name: b[0] for name, b in built.items()}
    bk.render_assets(kit, collections, dumps)
    for name, collection in collections.items():
        cut = CUTAWAYS[name]
        render_cutaway(kit, name, collection, kit.out_dir / f"{name}_cutaway.png", cut["y_cut"], cut["elevation"],
                       cut["avatar"], cut["hide"])
    tiles = list(kit.order) + [f"{name}_cutaway" for name in kit.order]
    kc.compose_sheet(tiles, kit.out_dir, kit.sheet, tile=400, columns=4)
    bk.render_lineup(kit, collections, report, dumps)

    try:
        bpy.context.window.scene = scene
    except AttributeError:
        pass
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(kit.blend), check_existing=False)
    full = {
        "generator": kit.generator,
        "blender_version": bpy.app.version_string,
        "unvalidated": True,
        "studs_per_blender_unit": 1.0,
        "fbx_settings": {**kc.FBX_SETTINGS, "apply_scale_options": bk.FBX_KIT_SCALE},
        "roblox_scale_verified": False,
        "roblox_frame": "local (x, y, z) = (-x, z, y) of Blender, as tools/biome_map_builder.py kit_point; "
                        "fronts and the raft's forward face -Z",
        "collision": "data only: build anchored, invisible, CanCollide Parts from collision_boxes; "
                     "import the FBX meshes with CanCollide off",
        "scale_block_height": kc.SCALE_BLOCK_HEIGHT,
        "sheet_file": kit.sheet.name, "lineup_file": kit.lineup.name,
        "blend": kit.rel(kit.blend),
        "props": report,
    }
    kc.dump_json(kit.report, full, indent=2)
    kc.dump_json(kit.geometry, dumps)
    write_readme(full)
    for name in kit.order:
        e = report[name]
        print(name, e["triangles"], e["size"], "open", e["non_manifold_edges"],
              [(d["name"], d["measured"]["width"], d["measured"]["height"]) for d in e.get("doors", [])],
              [(r["name"], r["ceiling_measured"]) for r in e.get("rooms", [])])


def fmt(values):
    return "(" + ", ".join(f"{v:g}" for v in values) + ")"


def write_readme(report):
    """README next to the FBX files: sizes, doors, floors, collision boxes and the seat, from the report."""
    lines = [
        "# Caramelo v3 buildings and raft (FBX)",
        "",
        f"Generated by `{GENERATOR}` (Blender {report['blender_version']}); contract and checks in",
        "`tools/caramelo_v3_buildings_spec.py` and `tools/test_caramelo_v3_buildings_kit.py`. Previews, cutaways and",
        "the .blend are in `assets/blender/caramelo-v3-buildings/`. **Unvalidated: never imported into Roblox.**",
        "",
        "## Conventions",
        "",
        "- 1 Blender unit = 1 stud, FBX_SCALE_ALL, axis forward -Z, up Y (same as the other kits).",
        "- Each FBX is an Empty root (the pivot) with one mesh per colour, named `<Asset>_<Part>`, one material each",
        "  with the part colour (set each MeshPart's Color from the table in the report, as the other kits do).",
        "- Pivot: ground centre for the buildings, waterline centre for the raft (its hull reaches below 0).",
        "- Visual meshes carry no collision: import them with CanCollide off (CollisionFidelity Box is fine).",
        "  Collision is the box list below: make anchored, Transparency 1, CanCollide Parts from it.",
        "- Roblox numbers use the local frame of `tools/biome_map_builder.py` (`kit_point`): Roblox (x, y, z) =",
        "  Blender (-x, z, y). Fronts (doors) and the raft's forward face -Z. Orientation is degrees (X, Y, Z);",
        "  each box turns about one axis only. Left/Right in box names are as seen from the front in Blender;",
        "  the frame map mirrors X, so a `_L` box has a positive Roblox x.",
        "- Fit-out boxes (`Prop_`, `Stair_`, `Newel`, `Rail_`, `Door_Leaf`) stand inside rooms; every other box is",
        "  shell (floor, walls, ceilings, roof) and stays out of the rooms and doorways.",
        "",
        "## Assets",
        "",
        "| FBX | Sheet | Size X x Y(up) x Z, studs | Triangles | Visual parts |",
        "|---|---|---|---|---|",
    ]
    for name, e in report["props"].items():
        x, y, z = e["size"]
        lines.append(f"| `{name}.fbx` | {e['sheet']} | {x:.1f} x {z:.1f} x {y:.1f} | {e['triangles']} | "
                     f"{len(e['parts'])} |")
    for name, e in report["props"].items():
        lines += ["", f"## {name}", ""]
        for door in e.get("doors", []):
            m = door["measured"]
            lines.append(f"- {door['name']} door: centre (Roblox) {fmt(door['roblox_center'])}, facing "
                         f"{'-Z' if door['facing'] == '-Y' else '+Z'}, clear width {m['width']:.2f}, clear height "
                         f"{m['height']:.2f} above its floor at y {door['floor']:g}.")
        for room in e.get("rooms", []):
            lines.append(f"- {room['name']} floor: flat at y {room['floor']:g} (Roblox), free height "
                         f"{room['ceiling_measured']:.1f}.")
        if "seat_anchor" in e:
            s = e["seat_anchor"]
            lines.append(f"- SeatAnchor (Empty in the FBX): Roblox {fmt(s['roblox'])}, Blender {fmt(s['blender'])}, "
                         "facing -Z. Put a VehicleSeat there (top of the cushion); the rider's headroom box "
                         f"{fmt(s['headroom_box'][0])} to {fmt(s['headroom_box'][1])} (Blender) is free.")
            lines.append("- Hull, Tips and Seat are the vehicle body; scoops, sauce, cream, cherries, stems and "
                         "sprinkles are separate decoration meshes. Drive and buoyancy are not set up here.")
        lines += ["", "| Collision box | Position (Roblox) | Size (Roblox) | Orientation |", "|---|---|---|---|"]
        for box in e["collision_roblox"]:
            lines.append(f"| {box['name']} | {fmt(box['position'])} | {fmt(box['size'])} | {fmt(box['orientation'])} |")
    cs.README.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    kit = make_kit()
    if bk.bpy is None:
        dry_run()
        return
    if os.environ.get(MODE_VARIABLE) != "verify-fbx":
        brighter_studio()
        build(kit)
    bk.verify_fbx(kit)


main()
