"""Compose reference-vs-model comparison sheets (run headless with Blender's Python)."""
import os
import sys

import bpy
import numpy as np

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..'))
REFS = os.path.join(ROOT, 'docs', 'design', 'beast-pack', 'refs')
PREV = os.path.join(ROOT, 'assets', 'models', 'beasts', 'previews')
H = 512


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)
    # nearest-neighbour resize to height H
    nw = int(w * H / h)
    ys = (np.arange(H) * h / H).astype(int)
    xs = (np.arange(nw) * w / nw).astype(int)
    return a[ys][:, xs]


def sheet(name, ref, ours):
    tiles = [load(os.path.join(REFS, ref))] + [load(os.path.join(PREV, o)) for o in ours]
    gap = np.zeros((H, 8, 4), dtype=np.float32)
    gap[..., 3] = 1
    row = []
    for t in tiles:
        row += [t, gap]
    out = np.concatenate(row[:-1], axis=1)
    img = bpy.data.images.new(name, out.shape[1], out.shape[0])
    img.pixels = out.ravel()
    img.filepath_raw = os.path.join(PREV, name + '.png')
    img.file_format = 'PNG'
    img.save()


sheet('viper-vs-reference', 'VIPER_render.png', ['viper-34.png', 'viper-front.png'])
sheet('pouncer-vs-reference', 'POUNCER_render.png', ['pouncer-34.png', 'pouncer-front.png'])
sheet('gargoyle-vs-reference', 'GARGOYLE_render.png',
      ['gargoyle-three-quarter.png', 'gargoyle-front.png', 'gargoyle-statue.png'])
sheet('mire-vs-reference', 'MIRE_render.png', ['mire-three-quarter.png', 'mire-front.png', 'mire-submerged.png'])
print('SHEETS_OK')
