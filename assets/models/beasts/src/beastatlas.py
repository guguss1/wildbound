"""Palette atlas with painted detail tiles for the Wildbound beasts (headless Blender 5.x).

The beasts keep the flat palette approach: one small texture per creature, every face's
UVs pointing at a flat colour swatch. This module adds a row of *painted tiles* to that
texture (thin crack lines and vein accents on a plate colour). Faces that use a detail
palette entry get planar UVs inside one tile, so the line is painted on the face instead
of the face being a solid accent colour.

Layout (1024 x 256 px, Blender pixel rows start at the bottom):
- top band, 64 px tall: one flat swatch per palette entry, evenly spread across the width
- bottom band, 192 px tall: up to five 192 x 192 painted tiles
"""
import math
import random

import bpy
import numpy as np
from mathutils import Vector

W, H = 1024, 256
SW_H = 64
TILE = 192
MARGIN = 8


def _stamp(img, x, y, r, rgb):
    h, w = img.shape[:2]
    x0, x1 = max(0, int(x - r - 1)), min(w, int(x + r + 2))
    y0, y1 = max(0, int(y - r - 1)), min(h, int(y + r + 2))
    if x0 >= x1 or y0 >= y1:
        return
    yy, xx = np.mgrid[y0:y1, x0:x1]
    m = (xx - x) ** 2 + (yy - y) ** 2 <= r * r
    img[y0:y1, x0:x1][m] = rgb


def _walk(rng, size, start, ang, length, wobble, step=2.0):
    pts = [start]
    x, y = start
    travelled = 0.0
    while travelled < length:
        ang += rng.uniform(-wobble, wobble)
        x += math.cos(ang) * step
        y += math.sin(ang) * step
        travelled += step
        pts.append((x, y))
        if not (-10 < x < size + 10 and -10 < y < size + 10):
            break
    return pts


def paint_tile(base, line, rim=None, core=None, seed=1, cracks=3, width=1.6, branch=0.5, size=TILE):
    """A size x size tile: base colour with jagged thin crack lines.

    base/line/rim/core are linear RGB. rim is a darker edge drawn under the line, core a
    lighter centre (a faint glow for veins).
    """
    rng = random.Random(seed)
    img = np.zeros((size, size, 3), dtype=np.float32)
    img[...] = base
    # subtle facet noise so large faces do not read as pure flat colour
    noise = np.random.RandomState(seed).uniform(-0.012, 0.012, (size // 16 + 1, size // 16 + 1, 1))
    noise = np.kron(noise, np.ones((16, 16, 1)))[:size, :size]
    img = np.clip(img * (1.0 + noise * 6.0), 0, 1).astype(np.float32)
    paths = []
    for c in range(cracks):
        # start on an edge, head across the tile
        edge = rng.randrange(4)
        t = rng.uniform(0.15, 0.85) * size
        start, ang = {
            0: ((t, 0.0), math.pi / 2),
            1: ((size, t), math.pi),
            2: ((t, size), -math.pi / 2),
            3: ((0.0, t), 0.0),
        }[edge]
        ang += rng.uniform(-0.6, 0.6)
        main = _walk(rng, size, start, ang, size * rng.uniform(0.9, 1.3), 0.45)
        paths.append((main, width))
        for k in range(2, len(main) - 4, 9):
            if rng.random() < branch * 0.25:
                bx, by = main[k]
                bang = ang + rng.choice((-1, 1)) * rng.uniform(0.5, 1.1)
                paths.append((_walk(rng, size, (bx, by), bang, size * rng.uniform(0.15, 0.35), 0.5), width * 0.7))
    if rim is not None:
        for pts, wd in paths:
            for i in range(len(pts) - 1):
                (x0, y0), (x1, y1) = pts[i], pts[i + 1]
                for s in np.linspace(0, 1, 3):
                    _stamp(img, x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, wd + 1.4, rim)
    for pts, wd in paths:
        for i in range(len(pts) - 1):
            (x0, y0), (x1, y1) = pts[i], pts[i + 1]
            for s in np.linspace(0, 1, 3):
                _stamp(img, x0 + (x1 - x0) * s, y0 + (y1 - y0) * s, wd, line)
    if core is not None:
        for pts, wd in paths:
            if wd < width * 0.9:
                continue
            for i in range(len(pts) - 1):
                (x0, y0), (x1, y1) = pts[i], pts[i + 1]
                _stamp(img, (x0 + x1) * 0.5, (y0 + y1) * 0.5, max(0.5, wd * 0.45), core)
    return img


def build_atlas(name, swatches, tiles, path):
    """swatches: list of linear RGB (one per palette index). tiles: list of HxWx3 arrays."""
    assert len(tiles) <= W // TILE
    pix = np.zeros((H, W, 4), dtype=np.float32)
    pix[..., 3] = 1.0
    n = len(swatches)
    for i, c in enumerate(swatches):
        x0, x1 = i * W // n, (i + 1) * W // n
        pix[H - SW_H:H, x0:x1, :3] = c
    for k, t in enumerate(tiles):
        pix[0:TILE, k * TILE:(k + 1) * TILE, :3] = t
    # the unused strip right of the tiles repeats swatch 0 so nothing reads as black
    pix[0:TILE, len(tiles) * TILE:W, :3] = swatches[0]
    img = bpy.data.images.new(name, width=W, height=H, alpha=False)
    img.pixels.foreach_set(pix.ravel())
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    img.filepath = path
    return img


def swatch_uv(i, n):
    x0, x1 = i * W // n, (i + 1) * W // n
    return ((x0 + x1) * 0.5 / W, (H - SW_H * 0.5) / H)


def apply_uvs(obj, n_swatches, tile_of, world_per_tile=1.5, seed=5):
    """Rewrite UVs for the atlas layout.

    The current UVs are the flat-palette ones (u = (index + 0.5) / n). Faces whose palette
    index is a key of tile_of get planar UVs inside that tile. Coplanar neighbouring faces of
    the same tile share one projection, so a line runs across a whole facet.
    """
    rng = random.Random(seed)
    me = obj.data
    uv = me.uv_layers.active.data
    polys = me.polygons
    ci = [min(n_swatches - 1, int(uv[p.loop_start].uv[0] * n_swatches)) for p in polys]

    # flat swatches
    for p in polys:
        if ci[p.index] not in tile_of:
            u, v = swatch_uv(ci[p.index], n_swatches)
            for li in p.loop_indices:
                uv[li].uv = (u, v)

    # group coplanar neighbours of the same detail tile
    edge_faces = {}
    for p in polys:
        if ci[p.index] in tile_of:
            for ek in p.edge_keys:
                edge_faces.setdefault(ek, []).append(p.index)
    seen = set()
    verts = me.vertices
    for p in polys:
        if ci[p.index] not in tile_of or p.index in seen:
            continue
        group, stack = [], [p.index]
        seen.add(p.index)
        n0 = p.normal.copy()
        while stack:
            fi = stack.pop()
            group.append(fi)
            for ek in polys[fi].edge_keys:
                for nb in edge_faces.get(ek, ()):
                    if nb in seen or ci[nb] != ci[fi]:
                        continue
                    if polys[nb].normal.dot(n0) < 0.97:
                        continue
                    seen.add(nb)
                    stack.append(nb)
        nrm = Vector((0, 0, 0))
        for fi in group:
            nrm += polys[fi].normal * polys[fi].area
        nrm = nrm.normalized() if nrm.length > 1e-9 else Vector((0, 0, 1))
        ref = Vector((0, 0, 1)) if abs(nrm.z) < 0.9 else Vector((1, 0, 0))
        t = ref.cross(nrm).normalized()
        b = nrm.cross(t).normalized()
        ang = rng.uniform(0, 2 * math.pi)
        ca, sa = math.cos(ang), math.sin(ang)
        loops = [li for fi in group for li in polys[fi].loop_indices]
        pts = {}
        for li in loops:
            co = verts[me.loops[li].vertex_index].co
            x, y = co.dot(t) / world_per_tile, co.dot(b) / world_per_tile
            pts[li] = (x * ca - y * sa, x * sa + y * ca)
        xs = [q[0] for q in pts.values()]
        ys = [q[1] for q in pts.values()]
        span = max(max(xs) - min(xs), max(ys) - min(ys), 1e-6)
        inner = (TILE - 2 * MARGIN) / TILE
        scale = min(1.0, inner / span)
        sx = (max(xs) - min(xs)) * scale
        sy = (max(ys) - min(ys)) * scale
        ox = rng.uniform(0, max(0.0, inner - sx))
        oy = rng.uniform(0, max(0.0, inner - sy))
        k = tile_of[ci[group[0]]]
        for li, (x, y) in pts.items():
            tu = MARGIN / TILE + ox + (x - min(xs)) * scale
            tv = MARGIN / TILE + oy + (y - min(ys)) * scale
            uv[li].uv = ((k * TILE + tu * TILE) / W, (tv * TILE) / H)
    me.update()


def set_material_image(mat, img):
    tex = next(nd for nd in mat.node_tree.nodes if nd.type == 'TEX_IMAGE')
    tex.image = img
    tex.interpolation = 'Closest'
