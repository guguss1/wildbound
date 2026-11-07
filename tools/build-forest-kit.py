"""Build the original six-prop low-poly forest kit in a fresh headless Blender scene.

Run: "D:/blender/blender.exe" --background --factory-startup --python tools/build-forest-kit.py
Set FOREST_KIT_MODE=verify-fbx to re-import the exports in fresh scenes instead.

1 Blender unit = 1 stud. Each prop is an Empty root at the ground-level pivot with one
mesh child per material, because a Roblox MeshPart holds a single colour and material.
All geometry is authored here; no third-party assets are used.
"""

import json
import math
import os
import random
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
KIT_DIR = ROOT / "assets/blender/forest-kit"
EXPORT_DIR = ROOT / "assets/exports/forest-kit"
BLEND = KIT_DIR / "forest-kit-v1.blend"
REPORT = KIT_DIR / "forest-kit-report.json"
GEOMETRY = KIT_DIR / "forest-kit-geometry.json"
ROUNDTRIP = KIT_DIR / "fbx-roundtrip.json"
SHEET = KIT_DIR / "forest-kit-sheet.png"
LINEUP = KIT_DIR / "forest-kit-scale.png"

PROP_ORDER = ("FK_Evergreen", "FK_DeadTree", "FK_FallenLog",
              "FK_RootArch", "FK_RuinDoorway", "FK_LanternMarker")
CLEARANCE_PROBES = {"FK_RootArch": (16.0, 11.0), "FK_RuinDoorway": (18.0, 11.0)}
SCALE_BLOCK_HEIGHT = 5.0
GLASS_EMISSION = 0.75

# name: (sRGB hex, emission strength)
PALETTE = {
    "Pine": ("FK_Pine", "2B4034", 0.0),
    "Bark": ("FK_Bark", "4C3226", 0.0),
    "Moss": ("FK_Moss", "6B7036", 0.0),
    "Charcoal": ("FK_Charcoal", "55585D", 0.0),
    "Pale": ("FK_PaleWood", "BE9C70", 0.0),
    "Fungus": ("FK_Fungus", "A06A3A", 0.0),
    "Rope": ("FK_Rope", "9C8152", 0.0),
    "Iron": ("FK_Iron", "2C2D30", 0.0),
    "Glass": ("FK_Neon_LanternGlass", "F08C2E", GLASS_EMISSION),
}


# ---------------------------------------------------------------------------
# Geometry helpers: plain vertex and face lists, turned into meshes at the end.
# ---------------------------------------------------------------------------

class Part:
    def __init__(self, label, material):
        self.label, self.material = label, material
        self.vertices, self.faces = [], []

    def add(self, vertices, faces):
        start = len(self.vertices)
        self.vertices.extend(tuple(v) for v in vertices)
        self.faces.extend(tuple(start + i for i in face) for face in faces)


class Prop:
    def __init__(self, name):
        self.name, self.parts = name, {}

    def part(self, label, material):
        if label not in self.parts:
            self.parts[label] = Part(label, material)
        return self.parts[label]


def vec(*values):
    return Vector(values)


def loft(part, rings, start="cap", end="cap"):
    """Close a stack of same-sized rings. A cap is an n-gon; a Vector end is a fan to a tip."""
    sides = len(rings[0])
    vertices = [v for ring in rings for v in ring]
    faces = []
    for row in range(len(rings) - 1):
        for i in range(sides):
            j = (i + 1) % sides
            a, b = row * sides + i, row * sides + j
            faces.append((a, b, b + sides, a + sides))
    if isinstance(start, Vector):
        index = len(vertices)
        vertices.append(start)
        faces.extend((index, (i + 1) % sides, i) for i in range(sides))
    else:
        faces.append(tuple(reversed(range(sides))))
    last = (len(rings) - 1) * sides
    if isinstance(end, Vector):
        index = len(vertices)
        vertices.append(end)
        faces.extend((last + i, last + (i + 1) % sides, index) for i in range(sides))
    else:
        faces.append(tuple(last + i for i in range(sides)))
    part.add(vertices, faces)


def path_frames(points, reference=None):
    """Parallel-transport frames, so twist comes only from the caller."""
    tangent = (points[1] - points[0]).normalized()
    if reference is None:
        reference = vec(0, 0, 1) if abs(tangent.z) < 0.85 else vec(1, 0, 0)
    side = reference.cross(tangent).normalized()
    frames = []
    for index in range(len(points)):
        tangent = (points[min(index + 1, len(points) - 1)] - points[max(index - 1, 0)]).normalized()
        side = (side - tangent * side.dot(tangent)).normalized()
        frames.append((side, tangent.cross(side), tangent))
    return frames


def tube(part, rng, points, radii, sides=6, rough=0.1, twist=0.0, squash=1.0, phase=None,
         flutes=0.0, reference=None):
    """Faceted limb. A radius of 0 at either end makes that end a sharp point."""
    points = [Vector(p) for p in points]
    frames = path_frames(points, reference)
    phase = rng.uniform(0, math.tau) if phase is None else phase
    # Flutes persist along the limb and follow the twist, which reads as twisted grain.
    groove = [1.0 + flutes * (rng.uniform(0.2, 1.0) if k % 2 else -rng.uniform(0.2, 1.0))
              for k in range(sides)]
    rings, start, end = [], "cap", "cap"
    for index, (point, radius) in enumerate(zip(points, radii)):
        if radius <= 0.0:
            if index == 0:
                start = point
            else:
                end = point
            continue
        side, normal, _ = frames[index]
        ring = []
        for k in range(sides):
            angle = phase + twist * index + math.tau * k / sides
            amount = radius * groove[k] * (1.0 + rng.uniform(-rough, rough))
            ring.append(point + side * math.cos(angle) * amount * squash
                        + normal * math.sin(angle) * amount)
        rings.append(ring)
    loft(part, rings, start, end)


def resample(points, count):
    """Evenly spaced points along a polyline."""
    points = [Vector(p) for p in points]
    lengths = [(b - a).length for a, b in zip(points, points[1:])]
    total, out = sum(lengths), []
    for index in range(count):
        target, walked = total * index / (count - 1), 0.0
        for segment, length in enumerate(lengths):
            if walked + length >= target - 1e-6 or segment == len(lengths) - 1:
                t = min(1.0, (target - walked) / max(length, 1e-6))
                out.append(points[segment].lerp(points[segment + 1], t))
                break
            walked += length
    return out


def moss_drape(part, rng, path, radius, rings=5, drip=0.55, spread=1.2, box=None, outward=None):
    """Closed moss shell over a limb or block, with a jagged hem that drips down the sides.

    Round mode wraps a limb of the given radius, so the hem stays on the surface. Box mode
    takes (half_width, height) over a flat block top and lets the hem hang down its faces.
    Hem depth alternates per ring for the toothed edge, and both ends pinch.
    """
    points = resample(path, rings)
    built = []
    for index, point in enumerate(points):
        tangent = (points[min(index + 1, rings - 1)] - points[max(index - 1, 0)]).normalized()
        direction = outward(point) if outward else vec(0, 0, 1)
        up = (direction - tangent * direction.dot(tangent)).normalized()
        side = tangent.cross(up).normalized()
        pinch = index in (0, rings - 1)
        scale = 0.42 if pinch else 1.0

        def tooth():
            long_tooth = index % 2 == 1
            return drip * (rng.uniform(0.7, 1.25) if long_tooth else rng.uniform(0.05, 0.3)) * scale

        if box:
            half_width, height = box
            width = half_width * (0.7 if pinch else 1.0)
            ring = [point + up * (height - 0.5),
                    point + side * width * 1.03 + up * (height - 0.12 - tooth()),
                    point + side * width * 0.84 + up * (height + 0.08),
                    point + up * (height + rng.uniform(0.12, 0.2)) + side * width * rng.uniform(-0.2, 0.2),
                    point - side * width * 0.84 + up * (height + 0.08),
                    point - side * width * 1.03 + up * (height - 0.12 - tooth())]
        else:
            lift = radius * (0.96 if pinch else 1.08)
            hem_a, hem_b = (spread * scale + tooth() for _ in range(2))

            def on_surface(angle, grow=1.0):
                return point + (up * math.cos(angle) + side * math.sin(angle)) * lift * grow

            ring = [point + up * radius * 0.1,
                    on_surface(hem_a),
                    on_surface(hem_a * 0.5, 1.03),
                    on_surface(rng.uniform(-0.12, 0.12), 1.06),
                    on_surface(-hem_b * 0.5, 1.03),
                    on_surface(-hem_b)]
        built.append(ring)
    loft(part, built)


def hexahedron(part, corners):
    """Six-sided block from eight corners: bottom four, then top four."""
    faces = [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    part.add(corners, faces)


def stone(part, rng, center, size, jitter=0.1, yaw=0.0, chamfer=0.0):
    """Hand-cut masonry block, optionally with a chamfered top edge that catches light."""
    cx, cy, cz = center
    sx, sy, sz = (s / 2 for s in size)
    cos_y, sin_y = math.cos(yaw), math.sin(yaw)

    def place(x, y, z):
        jx, jy, jz = (rng.uniform(-jitter, jitter) for _ in range(3))
        x, y = x + jx, y + jy
        return vec(cx + x * cos_y - y * sin_y, cy + x * sin_y + y * cos_y, cz + z + jz)

    corners = [(-sx, -sy), (sx, -sy), (sx, sy), (-sx, sy)]
    bottom = [place(x, y, -sz) for x, y in corners]
    if chamfer <= 0.0:
        hexahedron(part, bottom + [place(x, y, sz) for x, y in corners])
        return
    # Non-uniform inset on purpose: even chamfers read as a machined primitive.
    upper = [place(x, y, sz - chamfer * rng.uniform(0.7, 1.3)) for x, y in corners]
    top = [place(x - math.copysign(chamfer * rng.uniform(0.7, 1.3), x),
                 y - math.copysign(chamfer * rng.uniform(0.7, 1.3), y), sz)
           for x, y in corners]
    loft(part, [bottom, upper, top])


def rock(part, rng, center, radii, sides=5, tall=True):
    cx, cy, cz = center
    rx, ry, rz = radii
    phase = rng.uniform(0, math.tau)

    def ring(scale, height):
        out = []
        for k in range(sides):
            angle = phase + math.tau * k / sides + rng.uniform(-0.2, 0.2)
            amount = scale * rng.uniform(0.82, 1.15)
            out.append(vec(cx + math.cos(angle) * rx * amount,
                           cy + math.sin(angle) * ry * amount,
                           cz + rz * height * rng.uniform(0.85, 1.15)))
        return out

    stack = [ring(1.0, 0.0), ring(0.92, 0.55), ring(0.45, 1.0)] if tall else [ring(1.0, 0.0), ring(0.68, 1.0)]
    loft(part, stack)


def diamond(part, center, rx, ry, rz):
    cx, cy, cz = center
    part.add([(cx + rx, cy, cz), (cx, cy + ry, cz), (cx - rx, cy, cz), (cx, cy - ry, cz),
              (cx, cy, cz + rz), (cx, cy, cz - rz)],
             [(0, 1, 4), (1, 2, 4), (2, 3, 4), (3, 0, 4), (1, 0, 5), (2, 1, 5), (3, 2, 5), (0, 3, 5)])


def root_limb(part, rng, azimuth, reach, width, start_height, start_radial=0.2, sides=4,
              origin=(0.0, 0.0), kink=0.4, prong=False, rings=4):
    """Buttress root: rises inside the trunk, swells, plunges, then snakes to a point."""
    ox, oy = origin

    def at(distance, height, drift=0.0):
        angle = azimuth + drift
        return vec(ox + math.cos(angle) * distance, oy + math.sin(angle) * distance, height)

    drift = rng.uniform(-kink, kink)
    if rings == 4:
        points = [at(start_radial, start_height),
                  at(reach * 0.36, start_height * 0.36, drift * 0.4),
                  at(reach * 0.7, width * 0.36, drift),
                  at(reach, 0.0, drift * rng.uniform(0.3, 1.5))]
        radii = [width * 0.55, width, width * 0.5, 0.0]
    else:
        points = [at(start_radial, start_height),
                  at(reach * 0.5, start_height * 0.22, drift * 0.6),
                  at(reach, 0.0, drift * rng.uniform(0.3, 1.5))]
        radii = [width, width * 0.62, 0.0]
    tube(part, rng, points, radii, sides=sides, rough=0.1, squash=0.78)
    if prong:
        fork = points[-2]
        angle = azimuth + drift + rng.choice((-1, 1)) * rng.uniform(0.6, 0.95)
        tip = fork + vec(math.cos(angle), math.sin(angle), 0.0) * reach * 0.36
        tip.z = 0.0
        tube(part, rng, [fork + vec(0, 0, 0.1), tip], [width * 0.34, 0.0], sides=3, rough=0.05)


def canopy_tier(part, rng, axis, apex_z, hem_z, radius, tips, phase):
    """Spruce skirt: a steep cone that flares into broad points with tucked valleys."""
    ax, ay = axis
    height = apex_z - hem_z
    mid_ring, hem_ring = [], []
    for k in range(tips * 2):
        is_tip = k % 2 == 0
        angle = phase + math.pi * k / tips + rng.uniform(-0.12, 0.12)
        if is_tip:
            # Mixed long and short boughs break the regular star outline.
            reach = radius * rng.choice((rng.uniform(0.76, 0.88), rng.uniform(0.98, 1.14)))
            hem_height = hem_z - rng.uniform(0.0, height * 0.05)
            mid_reach, mid_height = reach * 0.4, apex_z - height * 0.66
        else:
            reach = radius * rng.uniform(0.58, 0.68)
            hem_height = hem_z + height * rng.uniform(0.1, 0.2)
            mid_reach, mid_height = reach * 0.46, apex_z - height * 0.62
        mid_ring.append(vec(ax + math.cos(angle) * mid_reach, ay + math.sin(angle) * mid_reach,
                            mid_height + rng.uniform(-0.25, 0.25)))
        hem_ring.append(vec(ax + math.cos(angle) * reach, ay + math.sin(angle) * reach, hem_height))
    apex = vec(ax + rng.uniform(-0.25, 0.25), ay + rng.uniform(-0.25, 0.25), apex_z)
    underside = vec(ax, ay, hem_z + height * 0.34)
    loft(part, [mid_ring, hem_ring], start=apex, end=underside)


# ---------------------------------------------------------------------------
# The six props
# ---------------------------------------------------------------------------

def build_evergreen():
    rng = random.Random(4117)
    prop = Prop("FK_Evergreen")
    trunk = prop.part("Trunk", "Bark")
    canopy = prop.part("Canopy", "Pine")
    spine = [(0.0, 0.0, 0.0), (0.25, 0.1, 1.8), (1.1, -0.3, 4.2), (1.0, -0.5, 6.6),
             (0.0, -0.2, 9.4), (-0.4, 0.2, 13.0), (0.05, 0.25, 18.0)]
    tube(trunk, rng, spine, [2.2, 1.75, 1.42, 1.3, 1.12, 0.8, 0.42], sides=6, rough=0.07,
         twist=0.26, flutes=0.14)
    for azimuth, reach, width, prong in ((0.35, 7.6, 1.3, True), (1.55, 5.6, 1.1, False),
                                         (2.55, 8.0, 1.35, True), (3.75, 6.2, 1.15, False),
                                         (4.9, 7.4, 1.3, True)):
        root_limb(trunk, rng, azimuth, reach, width, 3.3, sides=4, prong=prong)
    # Tiers shift with the crooked spine, so the crown leans as one with the trunk.
    canopy_tier(canopy, rng, (-0.1, -0.15), 19.5, 9.0, 10.4, 8, 0.3)
    canopy_tier(canopy, rng, (-0.45, 0.2), 25.0, 15.0, 7.8, 7, 1.0)
    canopy_tier(canopy, rng, (-0.1, 0.3), 30.0, 20.6, 5.2, 6, 0.1)
    return prop


def build_dead_tree():
    rng = random.Random(902)
    prop = Prop("FK_DeadTree")
    bark = prop.part("Wood", "Bark")
    pale = prop.part("Splinter", "Pale")
    spine = [(0.0, 0.0, 0.0), (-0.45, 0.25, 2.1), (-1.5, 0.45, 4.8), (-0.2, -0.25, 7.5),
             (1.45, -0.55, 10.0), (0.75, -0.25, 12.7), (-0.5, 0.15, 15.6), (-1.1, 0.35, 18.3)]
    tube(bark, rng, spine, [2.5, 1.95, 1.62, 1.42, 1.3, 1.02, 0.62, 0.38], sides=6, rough=0.05,
         twist=0.55, flutes=0.2)
    # Crown fork: the taller prong sets the height, the shorter one hooks away.
    tube(bark, rng, [(-1.1, 0.35, 18.0), (-0.55, 0.2, 20.1), (-0.95, 0.3, 22.0)],
         [0.36, 0.2, 0.0], sides=4, rough=0.05)
    tube(bark, rng, [(-1.1, 0.35, 18.1), (-2.2, 0.5, 19.3), (-3.5, 0.5, 19.7)],
         [0.28, 0.16, 0.0], sides=3, rough=0.05)
    # Long horizontal spike on the leader.
    tube(bark, rng, [(-0.4, 0.1, 15.3), (-2.5, 0.3, 16.9), (-5.6, 0.5, 17.2)],
         [0.46, 0.22, 0.0], sides=4, rough=0.05)
    # Big right limb that ends in the snapped pale tip.
    limb = [(0.9, -0.3, 11.0), (3.2, -0.7, 12.9), (5.6, -1.0, 13.8), (6.8, -1.15, 16.0)]
    tube(bark, rng, limb, [0.62, 0.72, 0.5, 0.4], sides=5, rough=0.06, twist=0.3)
    tube(bark, rng, [(5.6, -1.0, 13.8), (7.1, -1.2, 14.1), (9.2, -1.3, 13.5)],
         [0.26, 0.14, 0.0], sides=3, rough=0.05)
    end = Vector(limb[-1])
    for dx, dy, dz in ((0.75, 0.05, 2.5), (-0.4, 0.25, 1.9), (0.3, -0.42, 1.45), (0.8, 0.42, 1.15)):
        tube(pale, rng, [end + vec(0, 0, -0.3), end + vec(dx, dy, dz)], [0.32, 0.0], sides=3,
             rough=0.1)
    # Lower left limb, a thin twig, and a broken stub pointing toward the back.
    tube(bark, rng, [(-0.9, 0.35, 6.2), (-3.0, 0.7, 8.1), (-4.2, 0.7, 8.9), (-5.2, 1.0, 11.4)],
         [0.76, 0.42, 0.26, 0.0], sides=4, rough=0.06)
    tube(bark, rng, [(-3.2, 0.7, 8.3), (-4.6, 0.3, 7.7), (-6.4, 0.2, 8.0)],
         [0.2, 0.12, 0.0], sides=3, rough=0.05)
    tube(bark, rng, [(0.9, 0.0, 12.0), (1.3, 2.0, 14.2), (1.0, 3.4, 16.6)],
         [0.56, 0.28, 0.0], sides=4, rough=0.06)
    for azimuth, reach, width, prong in ((0.1, 7.6, 1.25, True), (1.2, 5.2, 1.0, False),
                                         (2.15, 6.8, 1.1, True), (3.3, 8.0, 1.25, True),
                                         (4.35, 5.4, 1.0, False), (5.3, 6.9, 1.15, True)):
        root_limb(bark, rng, azimuth, reach, width, 3.4, sides=4, prong=prong, kink=0.5, rings=3)
    return prop


def bark_with_zigzag_end(part, rng, points, radii, sides, swing):
    """Log body whose broken end alternates forward and back: torn bark, not a saw cut."""
    points = [Vector(p) for p in points]
    frames = path_frames(points, vec(0, 0, 1))
    phase = rng.uniform(0, math.tau)
    rings = []
    for index, (point, radius) in enumerate(zip(points, radii)):
        side, normal, tangent = frames[index]
        ring = []
        for k in range(sides):
            angle = phase + math.tau * k / sides + 0.1 * index
            amount = radius * (1.0 + rng.uniform(-0.1, 0.1))
            vertex = point + side * math.cos(angle) * amount + normal * math.sin(angle) * amount
            if index == 0:
                vertex += tangent * ((0.34 if k % 2 else -0.26) + (vertex - point).dot(normal) * 0.16)
            if index == len(points) - 1:
                vertex += tangent * (swing if k % 2 else -swing * 0.8) * rng.uniform(0.7, 1.3)
            ring.append(vertex)
        rings.append(ring)
    loft(part, rings)


def splinter_crown(part, rng, base, axis, radius, spikes, length):
    """Pale torn wood: long uneven spikes around a recessed heart."""
    axis = Vector(axis).normalized()
    side = axis.cross(vec(0, 0, 1)).normalized()
    normal = side.cross(axis).normalized()
    base_ring, crown_ring = [], []
    for k in range(spikes * 2):
        angle = math.pi * k / spikes + rng.uniform(-0.1, 0.1)
        radial = side * math.cos(angle) + normal * math.sin(angle)
        base_ring.append(base + radial * radius * 0.96)
        if k % 2 == 0:
            distance = length * rng.uniform(0.56, 1.0)
            crown_ring.append(base + axis * distance + radial * radius * rng.uniform(0.55, 1.08))
        else:
            distance = length * rng.uniform(0.2, 0.36)
            crown_ring.append(base + axis * distance + radial * radius * rng.uniform(0.74, 0.92))
    heart = base + axis * length * 0.14
    loft(part, [base_ring, crown_ring], start=base - axis * 0.3, end=heart)


def bracket_fungus(part, rng, center, facing, radius):
    """Shelf fungus: a flat, wide plate half sunk into the bark, with a low stepped top."""
    cx, cy, cz = center
    facing = math.radians(facing)
    inner, rim = [], []
    for k in range(7):
        angle = math.tau * k / 7 + rng.uniform(-0.1, 0.1)
        along = math.cos(angle) * 0.95
        across = math.sin(angle) * 1.25
        x = along * math.cos(facing) - across * math.sin(facing)
        y = along * math.sin(facing) + across * math.cos(facing)
        rim.append(vec(cx + x * radius, cy + y * radius, cz + rng.uniform(-0.03, 0.03)))
        inner.append(vec(cx + x * radius * 0.62, cy + y * radius * 0.62, cz + radius * 0.24))
    loft(part, [inner, rim], start=vec(cx, cy, cz + radius * 0.34), end=vec(cx, cy, cz - radius * 0.14))


def build_fallen_log():
    rng = random.Random(77)
    prop = Prop("FK_FallenLog")
    bark = prop.part("Bark", "Bark")
    pale = prop.part("Splinter", "Pale")
    moss = prop.part("Moss", "Moss")
    fungus = prop.part("Fungus", "Fungus")
    spine = [(-7.7, 0.2, 2.42), (-7.1, 0.05, 2.5), (-4.6, 0.2, 2.2), (-1.8, 0.0, 2.0), (0.8, 0.1, 1.84), (3.0, -0.05, 1.7)]
    radii = [2.42, 2.5, 2.1, 2.0, 1.85, 1.78]
    bark_with_zigzag_end(bark, rng, spine, radii, 8, 0.8)
    axis = vec(1.0, -0.02, -0.04)
    splinter_crown(pale, rng, Vector(spine[-1]) - axis * 0.5, axis, 1.5, 6, 5.5)
    # Heavy wedge under the butt end, so the log rests on something instead of a tangent.
    tube(bark, rng, [(-6.2, -1.4, 1.0), (-4.2, -1.75, 0.55), (-2.6, -1.9, 0.0)],
         [0.95, 0.62, 0.0], sides=4, rough=0.1)
    # Two branch stubs, snapped at different lengths.
    tube(bark, rng, [(-1.5, 0.35, 3.1), (-2.2, 0.6, 5.2), (-1.5, 0.7, 6.4), (-1.9, 0.75, 7.6)],
         [0.8, 0.55, 0.3, 0.0], sides=4, rough=0.08)
    tube(bark, rng, [(1.3, 0.5, 2.9), (3.6, 1.35, 4.5)], [0.56, 0.0], sides=4, rough=0.08)
    # Fungi climb the camera side of the trunk.
    bracket_fungus(fungus, rng, (-0.6, -1.92, 2.35), -90, 1.15)
    bracket_fungus(fungus, rng, (0.7, -1.95, 1.55), -84, 0.95)
    bracket_fungus(fungus, rng, (1.85, -1.68, 0.86), -72, 0.76)
    moss_drape(moss, rng, [(-5.6, 0.1, 2.32), (-4.2, 0.15, 2.2), (-2.5, 0.05, 2.05)], 2.26,
               rings=7, drip=0.6, spread=0.85)
    return prop


def twisted_strand(direction, half_width, crown, rings):
    """Rib between two knees that wraps around its partner while crossing the corridor."""
    points = []
    for index in range(rings):
        t = index / (rings - 1)
        angle = math.pi * (1 - t)
        x = math.copysign(abs(math.cos(angle)) ** 0.62, math.cos(angle)) * half_width
        z = abs(math.sin(angle)) ** 0.62 * crown
        wrap = 3 * math.pi * t
        y = direction * (3.4 * math.cos(math.pi * t) ** 3 + 0.9 * math.cos(wrap))
        z += direction * 1.0 * math.sin(wrap) * math.sin(math.pi * t)
        points.append(vec(x, y, z))
    # The ends stop at knee height, where each leg divides into separate tapering roots.
    points[0] = vec(points[1].x * 1.0, points[1].y * 1.04, 3.0)
    points[-1] = vec(points[-2].x * 1.0, points[-2].y * 1.04, 3.0)
    return points


def split_root(part, rng, knee, azimuth, reach, width):
    """One branch of a divided leg: thick at the knee, tapering to a stubby tip on the ground."""
    bend = rng.uniform(-0.18, 0.18)

    def at(distance, height, angle):
        return vec(knee.x + math.cos(angle) * distance, knee.y + math.sin(angle) * distance, height)

    tube(part, rng, [knee + vec(0, 0, 0.5), at(reach * 0.52, 1.75, azimuth + bend),
                     at(reach, 0.32, azimuth + bend * 1.7)],
         [width, width * 0.82, width * 0.4], sides=4, rough=0.08)


def build_root_arch():
    rng = random.Random(23)
    prop = Prop("FK_RootArch")
    wood = prop.part("Wood", "Bark")
    moss = prop.part("Moss", "Moss")
    # Two thick ribs twist around each other over the corridor, swelling at the shoulders
    # where the legs gather.
    rib_a = twisted_strand(1, 11.8, 16.0, 11)
    rib_b = twisted_strand(-1, 11.7, 15.8, 11)
    radii_a = [1.8, 1.9, 2.0, 1.72, 1.58, 1.5, 1.58, 1.72, 2.0, 1.9, 1.8]
    radii_b = [1.72, 1.82, 1.92, 1.66, 1.52, 1.45, 1.52, 1.66, 1.92, 1.82, 1.72]
    tube(wood, rng, rib_a, radii_a, sides=5, rough=0.06, twist=0.3, flutes=0.08)
    tube(wood, rng, rib_b, radii_b, sides=5, rough=0.06, twist=-0.26, flutes=0.08)
    # The third root of each side leaves a shoulder, bows outward and lands between the legs.
    tube(wood, rng, [rib_a[2] + vec(0.2, -0.6, 0.2), vec(-13.5, -0.7, 8.0), vec(-14.5, -0.3, 4.2), vec(-15.1, -0.7, 0.0)],
         [1.55, 1.5, 1.3, 0.62], sides=5, rough=0.07, twist=0.3)
    tube(wood, rng, [rib_b[8] + vec(-0.2, 0.6, 0.2), vec(13.4, 0.9, 8.2), vec(14.4, 0.5, 4.4), vec(15.0, 0.9, 0.0)],
         [1.5, 1.45, 1.25, 0.6], sides=5, rough=0.07, twist=-0.3)
    # A short root ties the outer root to the near leg on each side, so the legs merge as well as split.
    tube(wood, rng, [vec(-14.0, -0.5, 6.0), vec(-12.0, -2.8, 4.4)], [0.92, 0.82], sides=4, rough=0.08)
    tube(wood, rng, [vec(13.9, 0.7, 6.2), vec(11.7, -2.6, 4.6)], [0.9, 0.8], sides=4, rough=0.08)
    # Each knee divides into fat tapering roots that spread outward and along the path.
    for knee, azimuths in ((rib_a[0], (1.6, 2.55)), (rib_b[0], (2.55, 3.55, 4.5)),
                           (rib_a[-1], (-1.5, -0.55, 0.4)), (rib_b[-1], (0.6, 1.55))):
        for azimuth in azimuths:
            split_root(wood, rng, knee, azimuth, rng.uniform(3.7, 4.3), rng.uniform(1.32, 1.5))

    def away_from_center(point):
        return vec(point.x * 0.7, 0.0, point.z - 5.0).normalized()

    # A broad saddle over the upper rib at the crown, and patches on two shoulders.
    moss_drape(moss, rng, rib_b[3:7], 1.75, rings=5, drip=0.9, spread=0.9, outward=away_from_center)
    moss_drape(moss, rng, rib_a[7:10], 2.05, rings=5, drip=0.85, spread=0.75, outward=away_from_center)
    moss_drape(moss, rng, rib_b[1:3], 2.05, rings=4, drip=0.85, spread=0.8, outward=away_from_center)
    return prop


def voussoir(part, rng, inner_a, inner_b, thickness, spring, angle_a, angle_b, depth, shift=(0, 0, 0)):
    """Wedge block of an elliptical arch, with a chamfered face toward the viewer side."""
    def point(angle, grow, y):
        x = math.cos(angle) * (inner_a + grow) + shift[0]
        z = spring + math.sin(angle) * (inner_b + grow) + shift[2]
        return vec(x + rng.uniform(-0.05, 0.05), y + shift[1], z + rng.uniform(-0.05, 0.05))

    half = depth / 2
    back = [point(angle_a, 0, half), point(angle_b, 0, half),
            point(angle_b, thickness, half), point(angle_a, thickness, half)]
    edge = [point(angle_a, 0, -half + 0.42), point(angle_b, 0, -half + 0.42),
            point(angle_b, thickness, -half + 0.42), point(angle_a, thickness, -half + 0.42)]
    inset_a, inset_b = angle_a - 0.035, angle_b + 0.035
    front = [point(inset_a, 0.3, -half), point(inset_b, 0.3, -half),
             point(inset_b, thickness - 0.3, -half), point(inset_a, thickness - 0.3, -half)]
    loft(part, [back, edge, front])


def build_ruin_doorway():
    rng = random.Random(58)
    prop = Prop("FK_RuinDoorway")
    stones = prop.part("Stone", "Charcoal")
    moss = prop.part("Moss", "Moss")
    depth = 3.9
    pillar_inner, pillar_width = 9.8, 3.9
    capital_inner, capital_width, capital_height = 9.35, 4.8, 1.65
    pillar_top = 9.6
    # Square pillars of stacked chunky blocks, each block slightly off the one below.
    for side, heights, drift in ((-1, (3.5, 3.1, 3.0), (0.0, 0.14, -0.08)),
                                 (1, (3.2, 3.3, 3.1), (0.1, -0.08, 0.1))):
        z = 0.0
        for height, offset in zip(heights, drift):
            center_x = side * (pillar_inner + pillar_width / 2) + offset * 0.5
            stone(stones, rng, (center_x, offset, z + height / 2),
                  (pillar_width, depth, height - 0.06), 0.04, 0.0, chamfer=0.34)
            z += height
        stone(stones, rng, (side * (capital_inner + capital_width / 2), 0.0, pillar_top + capital_height / 2),
              (capital_width, depth + 0.9, capital_height), 0.04, 0.0, chamfer=0.3)
    # Shallow arch sitting on the capitals: five big wedges, a proud keystone, one slipped block.
    spring = pillar_top + capital_height
    inner_a, inner_b, thickness = 9.4, 3.3, 3.6
    breaks = [0.0, 0.8, 1.36, 1.84, 2.4, math.pi]
    for index in range(len(breaks) - 1):
        shift, extra = (0.0, rng.uniform(-0.14, 0.14), 0.0), rng.uniform(-0.15, 0.15)
        if index == 2:
            extra = 0.7
        if index == 3:
            shift = (-0.1, -0.34, 0.1)
        voussoir(stones, rng, inner_a, inner_b, thickness + extra, spring + 0.02,
                 breaks[index] + 0.03, breaks[index + 1] - 0.03, depth - rng.uniform(0.0, 0.25), shift)
    # Broken wings: two stepped courses reaching about a third of the pillar stack.
    for center, size, yaw in (((-15.05, -0.1, 1.15), (2.7, 3.6, 2.3), 0.02),
                              ((-17.0, -0.2, 0.85), (1.75, 3.2, 1.7), -0.05),
                              ((-14.95, 0.05, 3.1), (2.5, 3.2, 1.6), -0.04),
                              ((-16.9, 0.1, 2.15), (1.4, 2.5, 0.9), 0.1)):
        stone(stones, rng, center, size, 0.07, yaw)
    for center, size, yaw in (((15.05, 0.1, 1.05), (2.7, 3.6, 2.1), -0.03),
                              ((16.95, 0.25, 0.8), (1.8, 3.1, 1.6), 0.07),
                              ((14.95, -0.1, 2.85), (2.5, 3.1, 1.5), 0.05),
                              ((16.7, -0.1, 1.95), (1.25, 2.1, 0.75), -0.14)):
        stone(stones, rng, center, size, 0.07, yaw)
    # Rubble by the threshold, kept outside the corridor.
    rock(stones, rng, (-12.4, -3.9, 0.0), (1.45, 1.05, 1.15), sides=5)
    rock(stones, rng, (11.9, -3.6, 0.0), (1.15, 0.9, 0.85), sides=5, tall=False)

    def arch_point(angle, grow):
        return vec(math.cos(angle) * (inner_a + grow), 0.0, spring + math.sin(angle) * (inner_b + grow))

    def radial(point):
        return vec(point.x / (inner_a + thickness) ** 2, 0.0,
                   (point.z - spring) / (inner_b + thickness) ** 2).normalized()

    def arc_path(start, end):
        return [arch_point(start + (end - start) * i / 4, thickness - 0.1) for i in range(5)]

    # Moss hangs down the arch faces at both haunches and sits on both broken wings.
    moss_drape(moss, rng, arc_path(2.2, 2.92), None, rings=5, drip=1.7, box=(2.08, 0.1), outward=radial)
    moss_drape(moss, rng, arc_path(0.3, 0.8), None, rings=5, drip=1.7, box=(2.08, 0.1), outward=radial)
    moss_drape(moss, rng, [(-16.3, 0.05, 3.9), (-13.7, 0.05, 3.9)], None, rings=4, drip=0.6, box=(1.66, 0.0))
    moss_drape(moss, rng, [(13.7, -0.1, 3.6), (16.2, -0.1, 3.6)], None, rings=3, drip=0.55, box=(1.6, 0.0))
    return prop


def build_lantern_marker():
    rng = random.Random(305)
    prop = Prop("FK_LanternMarker")
    wood = prop.part("Wood", "Bark")
    rope = prop.part("Rope", "Rope")
    iron = prop.part("Iron", "Iron")
    glass = prop.part("Glass", "Glass")
    stones = prop.part("Stones", "Charcoal")
    moss = prop.part("Moss", "Moss")

    spine = [vec(0.0, 0.0, 0.0), vec(0.2, 0.02, 2.4), vec(0.22, 0.05, 4.8), vec(0.72, 0.1, 7.6), vec(1.32, 0.16, 9.0)]
    tube(wood, rng, spine, [0.46, 0.36, 0.34, 0.27, 0.0], sides=5, rough=0.07, twist=0.18)

    # Crossarm notched through the stake, drooping toward the lantern.
    arm_left, arm_right = vec(-2.1, 0.08, 6.85), vec(3.0, 0.08, 7.65)
    arm_mid = arm_left.lerp(arm_right, 0.46) + vec(0.0, 0.04, 0.2)
    tube(wood, rng, [arm_left, arm_mid, arm_right], [0.2, 0.27, 0.14], sides=4, rough=0.1, phase=0.5)

    def collar(center, tilt, radius, height):
        center = Vector(center)
        axis = Vector(tilt).normalized()
        tube(rope, rng, [center - axis * height, center + axis * height], [radius, radius],
             sides=4, rough=0.03)

    # Lashing around the arm joint, and a low wrap so the stake does not read bare.
    collar((0.66, 0.08, 7.5), (0.5, 0.0, 1.0), 0.4, 0.18)
    collar((0.6, 0.08, 7.08), (-0.45, 0.0, 1.0), 0.42, 0.17)
    collar((0.2, 0.02, 2.25), (0.22, 0.0, 1.0), 0.47, 0.2)

    # Lantern, hanging from the low end of the arm.
    lx, ly = -1.6, 0.08
    diamond(iron, (lx, ly, 6.48), 0.09, 0.12, 0.24)
    diamond(iron, (lx, ly, 6.06), 0.12, 0.05, 0.24)
    roof_top, body_top, body_low = 5.9, 5.2, 3.9

    def square(half, z):
        return [vec(lx + x * half, ly + y * half, z) for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1))]

    loft(iron, [square(0.6, body_top - 0.06), square(0.68, body_top + 0.08)], end=vec(lx, ly, roof_top))
    loft(iron, [square(0.64, body_low - 0.18), square(0.6, body_low)])
    loft(glass, [square(0.44, body_low), square(0.47, body_top - 0.04)])
    for x, y in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        px, py = lx + x * 0.5, ly + y * 0.5
        tube(iron, rng, [(px, py, body_low), (px, py, body_top)], [0.075, 0.075], sides=3, rough=0.0)

    # Empty cage on the high end of the arm: open bars, closed floor.
    cx, cy = 2.62, 0.08
    diamond(iron, (cx, cy, 7.02), 0.12, 0.06, 0.34)
    cage_top, cage_low, cage_radius = 6.6, 4.86, 0.56
    tube(iron, rng, [(cx, cy, cage_low - 0.08), (cx, cy, cage_low + 0.04)],
         [cage_radius * 1.1, cage_radius * 1.1], sides=5, rough=0.0, phase=0.3)
    tube(iron, rng, [(cx, cy, cage_top - 0.24), (cx, cy, cage_top)], [0.3, 0.14], sides=4, rough=0.0, phase=0.3)
    for k in range(4):
        angle = 0.7 + math.tau * k / 4
        rx, ry = math.cos(angle), math.sin(angle)
        tube(iron, rng, [(cx + rx * cage_radius, cy + ry * cage_radius, cage_low),
                         (cx + rx * cage_radius, cy + ry * cage_radius, cage_low + 1.1),
                         (cx + rx * 0.2, cy + ry * 0.2, cage_top - 0.12)],
             [0.06, 0.06, 0.06], sides=3, rough=0.0)

    rock(stones, rng, (-0.82, -0.5, 0.0), (1.1, 0.85, 0.62), sides=5, tall=False)
    rock(stones, rng, (0.88, -0.25, 0.0), (0.95, 1.0, 0.52), sides=5, tall=False)
    rock(stones, rng, (-0.05, 0.95, 0.0), (0.8, 0.62, 0.42), sides=4, tall=False)
    moss_drape(moss, rng, [(-1.45, -0.55, 0.58), (-0.3, -0.5, 0.58)], None, rings=3, drip=0.38, box=(0.72, 0.14))
    return prop


# ---------------------------------------------------------------------------
# Scene assembly
# ---------------------------------------------------------------------------

def srgb_to_linear(hex_color):
    channels = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels)


def make_materials():
    made = {}
    for key, (name, color, emission) in PALETTE.items():
        material = bpy.data.materials.new(name)
        linear = srgb_to_linear(color)
        material.use_nodes = True
        shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        shader.inputs["Base Color"].default_value = (*linear, 1)
        shader.inputs["Roughness"].default_value = 0.92
        shader.inputs["Metallic"].default_value = 0.0
        shader.inputs["Specular IOR Level"].default_value = 0.2
        if emission:
            shader.inputs["Emission Color"].default_value = (*linear, 1)
            shader.inputs["Emission Strength"].default_value = emission
        material.diffuse_color = (*linear, 1)
        made[key] = material
    return made


def make_mesh(name, part, material):
    data = bpy.data.meshes.new(name)
    # Nothing goes below the ground plane, so buried keels and root tips sit flat.
    grounded = [(x, y, max(z, 0.0)) for x, y, z in part.vertices]
    data.from_pydata(grounded, [], part.faces)
    data.update()
    bm = bmesh.new()
    bm.from_mesh(data)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    # Triangulated here so the render shows the exact facets a phone will draw.
    bmesh.ops.triangulate(bm, faces=list(bm.faces), quad_method="BEAUTY", ngon_method="BEAUTY")
    for face in bm.faces:
        face.smooth = False
    bm.to_mesh(data)
    bm.free()
    data.materials.append(material)
    return data


def assemble(prop, materials, scene):
    collection = bpy.data.collections.new(prop.name)
    scene.collection.children.link(collection)
    root = bpy.data.objects.new(prop.name, None)
    root.empty_display_size = 1.0
    collection.objects.link(root)
    for label, part in prop.parts.items():
        name = f"{prop.name}_{label}"
        obj = bpy.data.objects.new(name, make_mesh(name, part, materials[part.material]))
        collection.objects.link(obj)
        obj.parent = root
    return collection


def evaluated_triangles(obj, depsgraph):
    evaluated = obj.evaluated_get(depsgraph)
    mesh = evaluated.to_mesh()
    mesh.calc_loop_triangles()
    matrix = evaluated.matrix_world
    triangles = [[tuple(matrix @ mesh.vertices[i].co) for i in tri.vertices] for tri in mesh.loop_triangles]
    bm = bmesh.new()
    bm.from_mesh(mesh)
    open_edges = sum(1 for edge in bm.edges if len(edge.link_faces) != 2)
    bm.free()
    flat = not any(polygon.use_smooth for polygon in mesh.polygons)
    evaluated.to_mesh_clear()
    return triangles, open_edges, flat


def clip_axis(points, axis, low, high):
    def clip(polygon, inside, boundary):
        out = []
        for index, current in enumerate(polygon):
            previous = polygon[index - 1]
            if inside(current) != inside(previous):
                t = (boundary - previous[axis]) / (current[axis] - previous[axis])
                out.append(tuple(p + (c - p) * t for p, c in zip(previous, current)))
            if inside(current):
                out.append(current)
        return out

    kept = clip(points, lambda p: p[axis] >= low, low)
    return clip(kept, lambda p: p[axis] <= high, high) if kept else []


def measure_clearance(triangles, probe_width, probe_height):
    """Free corridor seen along Y: width below probe_height, height over the probe_width band."""
    low, high, lowest = float("-inf"), float("inf"), float("inf")
    half = probe_width / 2
    for triangle in triangles:
        flat = [(v[0], v[2]) for v in triangle]
        slab = clip_axis(flat, 1, 0.0, probe_height)
        if slab:
            xs = [p[0] for p in slab]
            if min(xs) <= 0.0 <= max(xs):
                low, high = 0.0, 0.0
            elif max(xs) < 0.0:
                low = max(low, max(xs))
            else:
                high = min(high, min(xs))
        band = clip_axis(flat, 0, -half, half)
        if band:
            lowest = min(lowest, min(p[1] for p in band))
    return {"method": "evaluated mesh triangles projected along Y",
            "width": high - low, "gap_low_x": low, "gap_high_x": high, "height": lowest,
            "width_probe_height": probe_height, "height_probe_width": probe_width}


def measure_props(collections, depsgraph):
    props, dump = {}, {}
    for name, collection in collections.items():
        triangles, parts, flat_all, applied = [], [], True, True
        for obj in sorted(collection.objects, key=lambda o: o.name):
            identity = all(abs(a - b) < 1e-6
                           for row_a, row_b in zip(obj.matrix_world, Matrix.Identity(4))
                           for a, b in zip(row_a, row_b))
            applied = applied and identity
            if obj.type != "MESH":
                continue
            found, open_edges, flat = evaluated_triangles(obj, depsgraph)
            triangles.extend(found)
            flat_all = flat_all and flat
            material = obj.data.materials[0]
            shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
            parts.append({
                "object": obj.name,
                "material": material.name,
                "triangles": len(found),
                "non_manifold_edges": open_edges,
                "roughness": round(shader.inputs["Roughness"].default_value, 3),
                "emission_strength": round(shader.inputs["Emission Strength"].default_value, 3),
            })
        points = [v for t in triangles for v in t]
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        band = low[2] + (high[2] - low[2]) * 0.1
        base = [v for t in triangles for v in t if v[2] <= band]
        entry = {
            "triangles": len(triangles),
            "size": [round(b - a, 4) for a, b in zip(low, high)],
            "bbox_min": [round(v, 4) for v in low],
            "bbox_max": [round(v, 4) for v in high],
            "base_center": [round((min(v[i] for v in base) + max(v[i] for v in base)) / 2, 4)
                            for i in (0, 1)],
            "non_manifold_edges": sum(p["non_manifold_edges"] for p in parts),
            "flat_shaded": flat_all,
            "transforms_applied": applied,
            "parts": parts,
            "fbx": f"assets/exports/forest-kit/{name}.fbx",
            "render": f"assets/blender/forest-kit/{name}.png",
        }
        if name in CLEARANCE_PROBES:
            entry["clearance"] = {k: round(v, 4) if isinstance(v, float) else v
                                  for k, v in measure_clearance(triangles, *CLEARANCE_PROBES[name]).items()}
        props[name] = entry
        dump[name] = {"triangles": [[[round(c, 4) for c in v] for v in t] for t in triangles]}
    return props, dump


def export_fbx(scene, collection, path):
    view_layer = scene.view_layers[0]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True, view_layer=view_layer)
    view_layer.objects.active = next(o for o in collection.objects if o.type == "EMPTY")
    bpy.ops.export_scene.fbx(
        filepath=str(path), use_selection=True, object_types={"EMPTY", "MESH"},
        global_scale=1.0, apply_unit_scale=True, apply_scale_options="FBX_SCALE_ALL",
        axis_forward="-Z", axis_up="Y", use_space_transform=True, bake_space_transform=False,
        use_mesh_modifiers=True, mesh_smooth_type="FACE", use_tspace=False,
        add_leaf_bones=False, bake_anim=False, path_mode="AUTO", use_custom_props=False)
    bpy.ops.object.select_all(action="DESELECT")


# ---------------------------------------------------------------------------
# Renders
# ---------------------------------------------------------------------------

CAMERA_AZIMUTH = math.radians(28.0)
CAMERA_ELEVATION = math.radians(20.0)
GROUND_COLOR = (0.47, 0.47, 0.49)


def set_render_engine(scene):
    scene.render.engine = "BLENDER_EEVEE"
    scene.eevee.taa_render_samples = 48
    scene.eevee.use_shadows = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGB"


def add_studio(scene):
    world = bpy.data.worlds.new("FK_Studio")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (*GROUND_COLOR, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.6
    scene.world = world

    ground_mesh = bpy.data.meshes.new("FK_StudioGround")
    size = 1000.0
    ground_mesh.from_pydata([(-size, -size, -0.01), (size, -size, -0.01), (size, size, -0.01), (-size, size, -0.01)],
                            [], [(0, 1, 2, 3)])
    ground_material = bpy.data.materials.new("FK_StudioGround")
    ground_material.use_nodes = True
    shader = next(n for n in ground_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (*GROUND_COLOR, 1)
    shader.inputs["Roughness"].default_value = 1.0
    shader.inputs["Specular IOR Level"].default_value = 0.0
    ground_mesh.materials.append(ground_material)
    ground = bpy.data.objects.new("FK_StudioGround", ground_mesh)
    scene.collection.objects.link(ground)

    key_data = bpy.data.lights.new("FK_Key", "SUN")
    key_data.energy = 2.5
    key_data.angle = math.radians(18.0)
    key = bpy.data.objects.new("FK_Key", key_data)
    key.rotation_euler = (math.radians(36), math.radians(4), math.radians(-52))
    scene.collection.objects.link(key)

    fill_data = bpy.data.lights.new("FK_Fill", "SUN")
    fill_data.energy = 0.4
    fill_data.use_shadow = False
    fill = bpy.data.objects.new("FK_Fill", fill_data)
    fill.rotation_euler = (math.radians(70), 0, math.radians(120))
    scene.collection.objects.link(fill)

    camera_data = bpy.data.cameras.new("FK_Camera")
    camera_data.type = "ORTHO"
    camera_data.clip_start, camera_data.clip_end = 0.1, 2000.0
    camera = bpy.data.objects.new("FK_Camera", camera_data)
    scene.collection.objects.link(camera)
    scene.camera = camera
    return camera


def frame_camera(camera, points, width, height, margin=1.14):
    """Fit the ortho camera to real vertices from a fixed three-quarter direction."""
    backward = vec(math.sin(CAMERA_AZIMUTH) * math.cos(CAMERA_ELEVATION),
                   -math.cos(CAMERA_AZIMUTH) * math.cos(CAMERA_ELEVATION),
                   math.sin(CAMERA_ELEVATION))
    right = vec(math.cos(CAMERA_AZIMUTH), math.sin(CAMERA_AZIMUTH), 0.0)
    up = backward.cross(right)
    xs = [right.dot(p) for p in points]
    ys = [up.dot(p) for p in points]
    center = right * ((min(xs) + max(xs)) / 2) + up * ((min(ys) + max(ys)) / 2)
    extent_x = (max(xs) - min(xs)) * margin
    extent_y = (max(ys) - min(ys)) * margin
    # Blender's ortho scale spans the longer image side.
    aspect = width / height
    camera.data.ortho_scale = max(extent_x, extent_y * aspect) if aspect >= 1 else max(extent_x / aspect, extent_y)
    camera.location = center + backward * 500.0
    camera.rotation_euler = Matrix((right, up, backward)).transposed().to_euler()


def render_to(scene, path, width, height):
    scene.render.resolution_x, scene.render.resolution_y = width, height
    scene.render.resolution_percentage = 100
    scene.render.filepath = str(path)
    bpy.ops.render.render(write_still=True, scene=scene.name)


def render_props(collections, dump):
    scene = bpy.data.scenes.new("FK_Preview")
    set_render_engine(scene)
    camera = add_studio(scene)
    for collection in collections.values():
        scene.collection.children.link(collection)
    for name, collection in collections.items():
        for other in collections.values():
            other.hide_render = other is not collection
        points = [Vector(v) for t in dump[name]["triangles"] for v in t]
        frame_camera(camera, points, 800, 800)
        render_to(scene, KIT_DIR / f"{name}.png", 800, 800)
    for collection in collections.values():
        collection.hide_render = False
        scene.collection.children.unlink(collection)
    return scene


def render_lineup(collections, report_props, dump):
    scene = bpy.data.scenes.new("FK_ScaleLineup")
    set_render_engine(scene)
    camera = add_studio(scene)
    cursor, gap = 0.0, 4.0
    points = []

    # The 5-stud block stands first in line and is never exported.
    block_mesh = bpy.data.meshes.new("FK_ScaleBlock_5studs")
    half = 1.0
    block_mesh.from_pydata(
        [(x, y, z) for z in (0.0, SCALE_BLOCK_HEIGHT) for x, y in ((-half, -half), (half, -half), (half, half), (-half, half))],
        [], [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    block_material = bpy.data.materials.new("FK_ScaleBlock")
    block_material.use_nodes = True
    shader = next(n for n in block_material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value = (0.78, 0.2, 0.05, 1)
    block_mesh.materials.append(block_material)
    block = bpy.data.objects.new("FK_ScaleBlock_5studs", block_mesh)
    scene.collection.objects.link(block)
    points.extend(Vector(vertex.co) for vertex in block_mesh.vertices)
    cursor = half + gap
    for name in PROP_ORDER:
        info = report_props[name]
        offset_x = cursor - info["bbox_min"][0]
        instance = bpy.data.objects.new(f"{name}_Lineup", None)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = collections[name]
        instance.location = (offset_x, 0.0, 0.0)
        scene.collection.objects.link(instance)
        points.extend(Vector(v) + vec(offset_x, 0.0, 0.0) for t in dump[name]["triangles"] for v in t)
        cursor = offset_x + info["bbox_max"][0] + gap
    frame_camera(camera, points, 1800, 700, margin=1.05)
    render_to(scene, LINEUP, 1800, 700)
    return scene


def compose_sheet():
    """Paste the six renders into a 3 x 2 sheet."""
    width, height, tile, gap_x = 1500, 1000, 492, 6
    canvas = np.full((height, width, 4), 0.86, dtype=np.float32)
    canvas[:, :, 3] = 1.0
    gaps_y = (5, 503)
    for index, name in enumerate(PROP_ORDER):
        image = bpy.data.images.load(str(KIT_DIR / f"{name}.png"))
        image.scale(tile, tile)
        pixels = np.empty(tile * tile * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        pixels = pixels.reshape(tile, tile, 4)
        column, row = index % 3, index // 3
        left = gap_x + column * (tile + gap_x)
        # Blender stores rows bottom-up, so the first row of the sheet lands at the high end.
        bottom = height - gaps_y[row] - tile
        canvas[bottom:bottom + tile, left:left + tile] = pixels
        bpy.data.images.remove(image)
    sheet = bpy.data.images.new("FK_Sheet", width, height, alpha=False)
    sheet.pixels.foreach_set(canvas.ravel())
    sheet.filepath_raw = str(SHEET)
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)


# ---------------------------------------------------------------------------
# Entry points
# ---------------------------------------------------------------------------

def build():
    KIT_DIR.mkdir(parents=True, exist_ok=True)
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = "ForestKit"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["studs_per_blender_unit"] = 1.0

    materials = make_materials()
    builders = {"FK_Evergreen": build_evergreen, "FK_DeadTree": build_dead_tree,
                "FK_FallenLog": build_fallen_log, "FK_RootArch": build_root_arch,
                "FK_RuinDoorway": build_ruin_doorway, "FK_LanternMarker": build_lantern_marker}
    collections = {name: assemble(builders[name](), materials, scene) for name in PROP_ORDER}
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()
    props, dump = measure_props(collections, depsgraph)

    for name, collection in collections.items():
        export_fbx(scene, collection, EXPORT_DIR / f"{name}.fbx")

    render_props(collections, dump)
    render_lineup(collections, props, dump)
    compose_sheet()

    bpy.context.window.scene = scene
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), check_existing=False)
    report = {
        "generator": "tools/build-forest-kit.py",
        "blender_version": bpy.app.version_string,
        "studs_per_blender_unit": 1.0,
        "fbx_settings": {"axis_forward": "-Z", "axis_up": "Y", "apply_scale_options": "FBX_SCALE_ALL"},
        "scale_block_height": SCALE_BLOCK_HEIGHT,
        "props": props,
        "blend": "assets/blender/forest-kit/forest-kit-v1.blend",
        "sheet": "assets/blender/forest-kit/forest-kit-sheet.png",
        "scale": "assets/blender/forest-kit/forest-kit-scale.png",
    }
    REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    GEOMETRY.write_text(json.dumps(dump, separators=(",", ":")) + "\n", encoding="utf-8")
    for name in PROP_ORDER:
        print(name, props[name]["triangles"], props[name]["size"], "open", props[name]["non_manifold_edges"],
              props[name]["base_center"], props[name].get("clearance", ""))


def verify_fbx():
    """Re-import every FBX in a fresh empty scene and measure what actually came back."""
    results = {}
    for name in PROP_ORDER:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(EXPORT_DIR / f"{name}.fbx"))
        bpy.context.view_layer.update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        triangles, materials, names = [], set(), []
        for obj in bpy.data.objects:
            names.append(obj.name)
            if obj.type != "MESH":
                continue
            found, _, _ = evaluated_triangles(obj, depsgraph)
            triangles.extend(found)
            materials.update(m.name for m in obj.data.materials if m)
        points = [v for t in triangles for v in t]
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        results[name] = {"triangles": len(triangles),
                         "size": [round(b - a, 4) for a, b in zip(low, high)],
                         "min_z": round(low[2], 4),
                         "objects": sorted(names),
                         "materials": sorted(materials)}
        print(name, results[name])
    ROUNDTRIP.write_text(json.dumps({"props": results}, indent=2) + "\n", encoding="utf-8")


if os.environ.get("FOREST_KIT_MODE") == "verify-fbx":
    verify_fbx()
else:
    build()
