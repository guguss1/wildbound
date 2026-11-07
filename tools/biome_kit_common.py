"""Build pipeline shared by the biome kit builders (Living Forest, Frozen Mountains).

Layered on tools/kit_common.py, which it imports and never edits. A builder passes a KIT
table: asset name -> {"size", "colors", "build", "tags"}; this module fits, measures, exports,
renders and reports it. Under plain Python it does a dry run that counts triangles and checks
closure without Blender. 1 Blender unit = 1 stud. Original scripted geometry only. Every asset
is unvalidated: never imported into Roblox.
"""

import math
import os
import sys
from collections import Counter
from pathlib import Path

try:
    import bpy
except ImportError:  # plain Python: dry run only
    bpy = None

TOOLS = Path(__file__).resolve().parent
if str(TOOLS) not in sys.path:
    sys.path.insert(0, str(TOOLS))

import biome_kit_spec as spec  # noqa: E402
import kit_common as kc  # noqa: E402

ROOT = TOOLS.parent
SHEET_SIZE = spec.SHEET_SIZE
FBX_KIT_SCALE = "FBX_SCALE_ALL"  # bible 5.1: kits use FBX_SCALE_ALL, rigs use FBX_SCALE_UNITS


def no_weight(vertex):
    """Kits have no skin; every kit_common primitive still asks for a weighting."""
    return {}


class Kit:
    """Paths and names for one biome kit."""

    def __init__(self, slug, prefix, generator, table, mode_variable):
        self.slug, self.prefix, self.generator = slug, prefix, generator
        self.table, self.order = table, list(table)
        self.mode_variable = mode_variable
        self.out_dir = ROOT / f"assets/blender/{slug}-kit"
        self.export_dir = ROOT / f"assets/exports/{slug}-kit"
        self.blend = self.out_dir / f"{slug}-kit-v1.blend"
        self.report = self.out_dir / f"{slug}-kit-report.json"
        self.geometry = self.out_dir / f"{slug}-kit-geometry.json"
        self.roundtrip = self.out_dir / "fbx-roundtrip.json"
        self.sheet = self.out_dir / f"{slug}-kit-sheet.png"
        self.lineup = self.out_dir / f"{slug}-kit-scale.png"

    def rel(self, path):
        return Path(path).relative_to(ROOT).as_posix()


# ---------------------------------------------------------------------------
# Pure Python stage
# ---------------------------------------------------------------------------

def author(kit, name):
    """Build one asset, fit it to its spec size and return (asset, tags)."""
    entry = kit.table[name]
    asset = kc.Asset(name, seed=entry.get("seed", 1))
    entry["build"](asset)
    kc.fit_asset(asset, entry["size"])
    tags = entry["tags"](asset) if entry.get("tags") else {}
    return asset, tags


def open_edges(part):
    """Edges not shared by exactly two faces, from the authored faces."""
    counts = Counter()
    for face in part.faces:
        for k in range(len(face)):
            counts[tuple(sorted((face[k], face[(k + 1) % len(face)])))] += 1
    return sum(1 for n in counts.values() if n != 2)


def dry_run(kit):
    for name in kit.order:
        asset, tags = author(kit, name)
        low, high = asset.bbox()
        counts = {label: part.triangles for label, part in asset.parts.items()}
        closed = {label: open_edges(part) for label, part in asset.parts.items()}
        print(name, "tris", asset.triangles, counts, "size", [round(b - a, 2) for a, b in zip(low, high)],
              "fit", [round(s, 3) for s in asset.fit], "open", sum(closed.values()))
        probe = kit.table[name].get("clear")
        if probe:
            triangles = [[part.vertices[i] for i in tri] for part in asset.parts.values()
                         for tri in triangulate(part)]
            found = spec.measure_clearance(triangles, *probe)
            print("   clearance", {k: round(v, 3) for k, v in found.items() if isinstance(v, float)})


def triangulate(part):
    for face in part.faces:
        for k in range(1, len(face) - 1):
            yield (face[0], face[k], face[k + 1])


# ---------------------------------------------------------------------------
# Blender stage
# ---------------------------------------------------------------------------

def is_identity(obj):
    from mathutils import Matrix
    return all(abs(a - b) < 1e-6 for row_a, row_b in zip(obj.matrix_world, Matrix.Identity(4))
               for a, b in zip(row_a, row_b))


def round_list(values, places=4):
    return [round(float(v), places) for v in values]


def assemble(kit, name, asset, materials, scene):
    collection = bpy.data.collections.new(name)
    scene.collection.children.link(collection)
    root = bpy.data.objects.new(name, None)
    root.empty_display_size = 1.0
    collection.objects.link(root)
    meshes = []
    for label, part in asset.parts.items():
        obj = kc.make_mesh_object(name, part, materials[f"{name}_{label}"], collection)
        obj.parent = root
        meshes.append(obj)
    return collection, root, meshes


def measure(kit, name, asset, tags, root, meshes, depsgraph):
    parts, dump_parts, triangles, applied, flat_all = [], {}, [], is_identity(root), True
    for obj in meshes:
        vertices, triples, open_count, flat = kc.evaluated_triangles(obj, depsgraph)
        applied, flat_all = applied and is_identity(obj), flat_all and flat
        material = obj.data.materials[0]
        shader = next(n for n in material.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
        label = obj.name[len(name) + 1:]
        dump_parts[obj.name] = {"vertices": [round_list(v) for v in vertices],
                                "triangles": [list(t) for t in triples]}
        triangles.extend([vertices[i] for i in t] for t in triples)
        parts.append({
            "object": obj.name, "material": material.name, "material_count": len(obj.material_slots),
            "palette_name": kit.table[name]["colors"][label][0],
            "triangles": len(triples), "non_manifold_edges": open_count,
            "roughness": round(shader.inputs["Roughness"].default_value, 3),
            "emission_strength": round(shader.inputs["Emission Strength"].default_value, 3),
            "color_hex": kc.linear_to_hex(shader.inputs["Base Color"].default_value),
        })
    points = [v for t in triangles for v in t]
    low = [min(p[i] for p in points) for i in range(3)]
    high = [max(p[i] for p in points) for i in range(3)]
    band = low[2] + (high[2] - low[2]) * 0.1
    base = [p for p in points if p[2] <= band]
    entry = {
        "status": "unvalidated",
        "triangles": len(triangles),
        "size": round_list([b - a for a, b in zip(low, high)]),
        "bbox_min": round_list(low), "bbox_max": round_list(high),
        "base_center": round_list([(min(p[i] for p in base) + max(p[i] for p in base)) / 2 for i in (0, 1)]),
        "non_manifold_edges": sum(p["non_manifold_edges"] for p in parts),
        "flat_shaded": flat_all, "transforms_applied": applied,
        "fit_scale": round_list(asset.fit),
        "parts": parts,
        "fbx": {"model": f"assets/exports/{kit.slug}-kit/{name}.fbx"},
        "render": f"assets/blender/{kit.slug}-kit/{name}.png",
    }
    entry.update(tags)
    probe = kit.table[name].get("clear")
    if probe:
        found = spec.measure_clearance(triangles, *probe)
        entry["clearance"] = {k: round(v, 4) if isinstance(v, float) else v for k, v in found.items()}
    return entry, {"parts": dump_parts}


def export_fbx(collection, root, path):
    view_layer = bpy.context.view_layer
    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.objects:
        obj.select_set(True, view_layer=view_layer)
    view_layer.objects.active = root
    bpy.ops.export_scene.fbx(
        filepath=str(path), use_selection=True, object_types={"EMPTY", "MESH"},
        global_scale=1.0, apply_unit_scale=True, apply_scale_options=FBX_KIT_SCALE,
        axis_forward=kc.FBX_SETTINGS["axis_forward"], axis_up=kc.FBX_SETTINGS["axis_up"],
        use_space_transform=True, bake_space_transform=False, use_mesh_modifiers=True,
        mesh_smooth_type="FACE", use_tspace=False, add_leaf_bones=False, bake_anim=False,
        path_mode="AUTO", use_custom_props=False)
    bpy.ops.object.select_all(action="DESELECT")


def render_assets(kit, collections, dumps):
    from mathutils import Vector
    scene = bpy.data.scenes.new(f"{kit.prefix}_Preview")
    kc.set_render_engine(scene)
    camera = kc.add_studio(scene, kit.prefix)
    for collection in collections.values():
        scene.collection.children.link(collection)
    for name in collections:
        for other, collection in collections.items():
            collection.hide_render = other != name
        points = [Vector(v) for part in dumps[name]["parts"].values() for v in part["vertices"]]
        kc.frame_camera(camera, points, 800, 800)
        kc.render_to(scene, kit.out_dir / f"{name}.png", 800, 800)
    for collection in collections.values():
        collection.hide_render = False
        scene.collection.children.unlink(collection)


def render_lineup(kit, collections, report, dumps):
    from mathutils import Vector
    scene = bpy.data.scenes.new(f"{kit.prefix}_Lineup")
    kc.set_render_engine(scene)
    camera = kc.add_studio(scene, kit.prefix)
    block, corners, half = kc.make_scale_block(scene, kit.prefix)
    points = [Vector(c) for c in corners]
    cursor, gap = half + 3.0, 3.0
    for name in collections:
        info = report[name]
        offset = cursor - info["bbox_min"][0]
        instance = bpy.data.objects.new(f"{name}_Lineup", None)
        instance.instance_type = "COLLECTION"
        instance.instance_collection = collections[name]
        instance.location = (offset, 0.0, 0.0)
        scene.collection.objects.link(instance)
        points.extend(Vector(v) + Vector((offset, 0.0, 0.0))
                      for part in dumps[name]["parts"].values() for v in part["vertices"])
        cursor = offset + info["bbox_max"][0] + gap
    kc.frame_camera(camera, points, 2400, 800, margin=1.05)
    kc.render_to(scene, kit.lineup, 2400, 800)


def compose_sheet(kit, columns=4, rows=2, tile=484, gap=12):
    """Paste the per-asset renders into a 4 x 2 sheet of exactly SHEET_SIZE."""
    import numpy as np
    width, height = SHEET_SIZE
    canvas = np.full((height, width, 4), 0.86, dtype=np.float32)
    canvas[:, :, 3] = 1.0
    left0 = (width - columns * tile - (columns - 1) * gap) // 2
    top0 = (height - rows * tile - (rows - 1) * gap) // 2
    for index, name in enumerate(kit.order[:columns * rows]):
        image = bpy.data.images.load(str(kit.out_dir / f"{name}.png"))
        image.scale(tile, tile)
        pixels = np.empty(tile * tile * 4, dtype=np.float32)
        image.pixels.foreach_get(pixels)
        column, row = index % columns, index // columns
        left = left0 + column * (tile + gap)
        bottom = height - (top0 + row * (tile + gap)) - tile  # Blender rows run bottom-up
        canvas[bottom:bottom + tile, left:left + tile] = pixels.reshape(tile, tile, 4)
        bpy.data.images.remove(image)
    sheet = bpy.data.images.new(f"{kit.prefix}_Sheet", width, height, alpha=False)
    sheet.pixels.foreach_set(canvas.ravel())
    sheet.filepath_raw = str(kit.sheet)
    sheet.file_format = "PNG"
    sheet.save()
    bpy.data.images.remove(sheet)


def build(kit, scale_note):
    kit.out_dir.mkdir(parents=True, exist_ok=True)
    kit.export_dir.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.name = f"{kit.prefix}Kit"
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    scene["studs_per_blender_unit"] = 1.0
    scene["status"] = "unvalidated: never imported into Roblox"

    authored = {name: author(kit, name) for name in kit.order}
    materials = {}
    for name, (asset, _) in authored.items():
        for label in asset.parts:
            materials[f"{name}_{label}"] = kc.make_material(f"{name}_{label}", kit.table[name]["colors"][label][1])
    built = {name: assemble(kit, name, asset, materials, scene) for name, (asset, _) in authored.items()}
    bpy.context.view_layer.update()
    depsgraph = bpy.context.evaluated_depsgraph_get()

    report, dumps = {}, {}
    for name, (asset, tags) in authored.items():
        collection, root, meshes = built[name]
        report[name], dumps[name] = measure(kit, name, asset, tags, root, meshes, depsgraph)
        export_fbx(collection, root, kit.export_dir / f"{name}.fbx")
    collections = {name: b[0] for name, b in built.items()}
    render_assets(kit, collections, dumps)
    compose_sheet(kit)
    render_lineup(kit, collections, report, dumps)

    try:
        bpy.context.window.scene = scene
    except AttributeError:
        pass
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(kit.blend), check_existing=False)
    kc.dump_json(kit.report, {
        "generator": kit.generator,
        "blender_version": bpy.app.version_string,
        "unvalidated": True,
        "studs_per_blender_unit": 1.0,
        "fbx_settings": {**kc.FBX_SETTINGS, "apply_scale_options": FBX_KIT_SCALE},
        "roblox_scale_verified": False,
        "scale_note": scale_note,
        "scale_block_height": kc.SCALE_BLOCK_HEIGHT,
        "sheet_file": kit.sheet.name, "lineup_file": kit.lineup.name,
        "blend": kit.rel(kit.blend),
        "props": report,
    }, indent=2)
    kc.dump_json(kit.geometry, dumps)
    for name in kit.order:
        e = report[name]
        print(name, e["triangles"], e["size"], "open", e["non_manifold_edges"], "fit", e["fit_scale"],
              [(p["object"][len(name) + 1:], p["triangles"]) for p in e["parts"]], e.get("clearance", {}).get("width", ""))


def verify_fbx(kit):
    """Re-import every FBX in a fresh empty scene and measure what actually came back."""
    results = {}
    for name in kit.order:
        bpy.ops.wm.read_factory_settings(use_empty=True)
        bpy.ops.import_scene.fbx(filepath=str(kit.export_dir / f"{name}.fbx"))
        bpy.context.view_layer.update()
        depsgraph = bpy.context.evaluated_depsgraph_get()
        count, materials, objects, points = 0, set(), [], []
        for obj in bpy.data.objects:
            objects.append(obj.name)
            if obj.type != "MESH":
                continue
            vertices, triples, _, _ = kc.evaluated_triangles(obj, depsgraph)
            count += len(triples)
            points.extend(vertices[i] for t in triples for i in t)
            materials.update(m.name for m in obj.data.materials if m)
        low = [min(p[i] for p in points) for i in range(3)]
        high = [max(p[i] for p in points) for i in range(3)]
        results[name] = {"model": {"triangles": count, "size": round_list([b - a for a, b in zip(low, high)]),
                                   "min_z": round(low[2], 4), "objects": sorted(objects),
                                   "materials": sorted(materials)}}
        print(name, results[name]["model"]["triangles"], results[name]["model"]["size"], results[name]["model"]["min_z"])
    kc.dump_json(kit.roundtrip, {"props": results}, indent=2)


def main(kit, scale_note):
    if bpy is None:
        dry_run(kit)
    elif os.environ.get(kit.mode_variable) == "verify-fbx":
        verify_fbx(kit)
    else:
        build(kit, scale_note)
