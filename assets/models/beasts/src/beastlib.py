"""Shared helpers for the Wildbound beast builders (headless Blender 5.x).

Units: 1 Blender unit = 1 metre = 1 Roblox stud. Creatures face -Y, pivot at the
world origin on the ground plane (Z = 0).
"""
import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector


# --------------------------------------------------------------------------
# Scene
# --------------------------------------------------------------------------

def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = 'METRIC'
    scene.unit_settings.scale_length = 1.0
    return scene


def hex_rgb(h):
    h = h.lstrip('#')
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]

    def lin(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return tuple(lin(c) for c in srgb)


# --------------------------------------------------------------------------
# Mesh builder: faces carry a palette index, vertices carry bone weights
# --------------------------------------------------------------------------

class MeshBuilder:
    def __init__(self, seed=1, jitter=0.0):
        self.verts = []
        self.weights = []
        self.faces = []
        self.fcol = []
        self.rng = random.Random(seed)
        self.jitter = jitter

    def v(self, co, w, jitter=None):
        j = self.jitter if jitter is None else jitter
        co = Vector(co)
        if j:
            co = co + Vector((self.rng.uniform(-j, j), self.rng.uniform(-j, j), self.rng.uniform(-j, j)))
        self.verts.append(co)
        self.weights.append(dict(w) if isinstance(w, dict) else {w: 1.0})
        return len(self.verts) - 1

    def f(self, idx, col):
        self.faces.append(list(idx))
        self.fcol.append(col)

    def loft(self, rings, col, w, cap_start=True, cap_end=True, jitter=None):
        """rings: list of lists of points (same length) or single points (apex).
        col: int or fn(ring_i, side_i, n) -> palette index.
        w: bone name / weight dict, or fn(ring_i) -> weights."""
        cf = col if callable(col) else (lambda i, k, n, c=col: c)
        wf = w if callable(w) else (lambda i, ww=w: ww)
        idx = []
        for i, ring in enumerate(rings):
            if isinstance(ring, Vector) or (len(ring) == 3 and not hasattr(ring[0], '__len__')):
                idx.append([self.v(ring, wf(i), jitter)])
            else:
                idx.append([self.v(p, wf(i), jitter) for p in ring])
        for i in range(len(idx) - 1):
            a, b = idx[i], idx[i + 1]
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                n = len(b)
                for k in range(n):
                    self.f([a[0], b[(k + 1) % n], b[k]], cf(i, k, n))
            elif len(b) == 1:
                n = len(a)
                for k in range(n):
                    self.f([a[k], a[(k + 1) % n], b[0]], cf(i, k, n))
            else:
                n = len(a)
                for k in range(n):
                    self.f([a[k], a[(k + 1) % n], b[(k + 1) % n], b[k]], cf(i, k, n))
        if cap_start and len(idx[0]) > 2:
            self.f(list(reversed(idx[0])), cf(-1, 0, len(idx[0])))
        if cap_end and len(idx[-1]) > 2:
            self.f(idx[-1], cf(len(idx), 0, len(idx[-1])))
        return idx

    def blob(self, center, radii, col, w, subdiv=1, rot=None, col_fn=None):
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=1.0)
        base = len(self.verts)
        R = rot if rot is not None else Matrix.Identity(3)
        for vert in bm.verts:
            p = Vector((vert.co.x * radii[0], vert.co.y * radii[1], vert.co.z * radii[2]))
            self.v(Vector(center) + R @ p, w)
        for face in bm.faces:
            c = col
            if col_fn:
                fc = sum((v.co for v in face.verts), Vector()) / len(face.verts)
                c = col_fn(fc)
            self.f([base + v.index for v in face.verts], c)
        bm.free()

    def prism(self, a, b, r0, r1, sides, col, w, up=Vector((0, 0, 1)), mid=None, apex=False, twist=0.0):
        """Tapered prism from a to b; mid=(t, scale) adds a bulge ring; apex closes at b."""
        a, b = Vector(a), Vector(b)
        d = (b - a).normalized()
        x = d.cross(up)
        if x.length < 1e-4:
            x = d.cross(Vector((1, 0, 0)))
        x.normalize()
        y = x.cross(d).normalized()

        def ring(c, r):
            pts = []
            for k in range(sides):
                ang = twist + 2 * math.pi * k / sides
                pts.append(c + (x * math.cos(ang) + y * math.sin(ang)) * r)
            return pts
        rings = [ring(a, r0)]
        if mid:
            t, s = mid
            rings.append(ring(a.lerp(b, t), (r0 + (r1 - r0) * t) * s))
        rings.append(b if apex else ring(b, r1))
        return self.loft(rings, col, w)

    def pyramid(self, base_pts, apex, col, w):
        return self.loft([base_pts, Vector(apex)], col, w)


def frame_from(fwd, up):
    f = Vector(fwd).normalized()
    x = f.cross(Vector(up)).normalized()
    u = x.cross(f).normalized()
    return x, f, u


def to_world(origin, X, F, U):
    o = Vector(origin)

    def tw(p):
        return o + X * p[0] + F * p[1] + U * p[2]
    return tw


# --------------------------------------------------------------------------
# Object creation
# --------------------------------------------------------------------------

def palette_image(name, colors, path):
    n = len(colors)
    img = bpy.data.images.new(name, width=n * 4, height=4, alpha=False)
    px = []
    for _row in range(4):
        for i in range(n):
            c = colors[i]
            for _k in range(4):
                px.extend([c[0], c[1], c[2], 1.0])
    img.pixels = px
    img.filepath_raw = path
    img.file_format = 'PNG'
    img.save()
    return img


def palette_material(name, img):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Roughness'].default_value = 1.5
    tex = nt.nodes.new('ShaderNodeTexImage')
    tex.image = img
    tex.interpolation = 'Closest'
    nt.links.new(tex.outputs['Color'], bsdf.inputs['Base Color'])
    return mat


def emissive_material(name, rgb, strength=6.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Emission Color'].default_value = (*rgb, 1)
    bsdf.inputs['Emission Strength'].default_value = strength
    mat.diffuse_color = (*rgb, 1)
    return mat


def flat_material(name, rgb, rough=0.9):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = next(n for n in mat.node_tree.nodes if n.type == 'BSDF_PRINCIPLED')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = rough
    mat.diffuse_color = (*rgb, 1)
    return mat


def build_object(mb, name, palette, material, collection=None):
    """palette: list of linear RGB; face palette index -> UV swatch + colour attribute."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(v) for v in mb.verts], [], mb.faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    (collection or bpy.context.scene.collection).objects.link(obj)

    n = len(palette)
    uv = mesh.uv_layers.new(name='UVMap')
    col = mesh.color_attributes.new('Col', 'BYTE_COLOR', 'CORNER')
    for poly in mesh.polygons:
        ci = mb.fcol[poly.index]
        u = (ci + 0.5) / n
        c = palette[ci]
        for li in poly.loop_indices:
            uv.data[li].uv = (u, 0.5)
            col.data[li].color = (c[0], c[1], c[2], 1.0)
    mesh.materials.append(material)

    # vertex groups
    groups = {}
    for vi, wd in enumerate(mb.weights):
        for bone, wt in wd.items():
            if wt <= 0:
                continue
            g = groups.get(bone)
            if g is None:
                g = obj.vertex_groups.new(name=bone)
                groups[bone] = g
            g.add([vi], wt, 'REPLACE')

    clean_mesh(obj)
    return obj


def clean_mesh(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.triangulate(bm, faces=bm.faces)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(obj.data)
    bm.free()
    for p in obj.data.polygons:
        p.use_smooth = False
    obj.data.update()


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def make_armature(name, bones, collection=None):
    """bones: list of (name, head, tail, parent, up_vector)."""
    arm = bpy.data.armatures.new(name + '_Rig')
    obj = bpy.data.objects.new(name + '_Rig', arm)
    (collection or bpy.context.scene.collection).objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT')
    eb = {}
    for bname, head, tail, parent, up in bones:
        b = arm.edit_bones.new(bname)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if up is not None:
            b.align_roll(Vector(up))
        if parent:
            b.parent = eb[parent]
            b.use_connect = False
        eb[bname] = b
    bpy.ops.object.mode_set(mode='OBJECT')
    arm.display_type = 'STICK'
    return obj


def bind(mesh_obj, arm_obj):
    mesh_obj.parent = arm_obj
    mod = mesh_obj.modifiers.new('Armature', 'ARMATURE')
    mod.object = arm_obj


# --------------------------------------------------------------------------
# Poses / actions
# --------------------------------------------------------------------------

def set_pose(arm_obj, pose):
    """pose: {bone: (rx, ry, rz) degrees or {'rot':(..), 'loc':(..)}}"""
    for pb in arm_obj.pose.bones:
        pb.rotation_mode = 'XYZ'
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)
    for bname, val in pose.items():
        pb = arm_obj.pose.bones[bname]
        if isinstance(val, dict):
            rot = val.get('rot', (0, 0, 0))
            pb.location = val.get('loc', (0, 0, 0))
        else:
            rot = val
        pb.rotation_euler = tuple(math.radians(a) for a in rot)


def make_action(arm_obj, name, keys):
    """keys: list of (frame, pose dict). Creates a fake-user action."""
    ad = arm_obj.animation_data or arm_obj.animation_data_create()
    ad.action = None
    for frame, pose in keys:
        set_pose(arm_obj, pose)
        for pb in arm_obj.pose.bones:
            pb.keyframe_insert('rotation_euler', frame=frame)
            pb.keyframe_insert('location', frame=frame)
    act = ad.action
    act.name = name
    act.use_fake_user = True
    return act


# --------------------------------------------------------------------------
# Export
# --------------------------------------------------------------------------

def select_only(objs):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def export_fbx(path, objs, anim=False):
    select_only(objs)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={'ARMATURE', 'MESH'},
        apply_unit_scale=True,
        apply_scale_options='FBX_SCALE_ALL',
        mesh_smooth_type='FACE',
        use_mesh_modifiers=False,
        add_leaf_bones=False,
        primary_bone_axis='Y',
        secondary_bone_axis='X',
        armature_nodetype='NULL',
        bake_anim=anim,
        bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=True,
        path_mode='COPY',
        embed_textures=True,
    )


def static_copy(objs, name, collection):
    """Join evaluated copies (current pose) into one rigless mesh."""
    dg = bpy.context.evaluated_depsgraph_get()
    bm = bmesh.new()
    mats = []
    for o in objs:
        eo = o.evaluated_get(dg)
        me = bpy.data.meshes.new_from_object(eo, depsgraph=dg)
        me.transform(o.matrix_world)
        off = len(mats)
        for m in me.materials:
            mats.append(m)
        tmp = bmesh.new()
        tmp.from_mesh(me)
        for f in tmp.faces:
            f.material_index += off
        tmp_me = bpy.data.meshes.new('tmp')
        tmp.to_mesh(tmp_me)
        tmp.free()
        bm.from_mesh(tmp_me)
        bpy.data.meshes.remove(tmp_me)
        bpy.data.meshes.remove(me)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = False
    ob = bpy.data.objects.new(name, me)
    collection.objects.link(ob)
    return ob


# --------------------------------------------------------------------------
# Preview rendering
# --------------------------------------------------------------------------

def setup_render(scene, res=(1000, 760)):
    for eng in ('BLENDER_EEVEE', 'BLENDER_EEVEE_NEXT'):
        try:
            scene.render.engine = eng
            break
        except TypeError:
            continue
    scene.render.resolution_x, scene.render.resolution_y = res
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    try:
        scene.eevee.taa_render_samples = 32
    except AttributeError:
        pass
    try:
        scene.view_settings.view_transform = 'Standard'
    except TypeError:
        pass
    world = bpy.data.worlds.new('PreviewWorld')
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == 'BACKGROUND')
    bg.inputs['Color'].default_value = (*hex_rgb('#3a3a42'), 1)
    bg.inputs['Strength'].default_value = 2.1

    col = bpy.data.collections.new('Preview')
    scene.collection.children.link(col)
    # ground
    me = bpy.data.meshes.new('PreviewGround')
    s = 40
    me.from_pydata([(-s, -s, 0), (s, -s, 0), (s, s, 0), (-s, s, 0)], [], [(0, 1, 2, 3)])
    g = bpy.data.objects.new('PreviewGround', me)
    g.data.materials.append(flat_material('PreviewGroundMat', hex_rgb('#2c2c33')))
    col.objects.link(g)
    # lights
    sun = bpy.data.lights.new('KeySun', 'SUN')
    sun.energy = 4.5
    sun.angle = math.radians(8)
    so = bpy.data.objects.new('KeySun', sun)
    so.rotation_euler = (Vector((0, 0, 0)) - Vector((-9, -14, 15))).to_track_quat('-Z', 'Y').to_euler()
    col.objects.link(so)
    fill = bpy.data.lights.new('FillSun', 'SUN')
    fill.energy = 1.8
    fo = bpy.data.objects.new('FillSun', fill)
    fo.rotation_euler = (Vector((0, 0, 0)) - Vector((14, 6, 8))).to_track_quat('-Z', 'Y').to_euler()
    col.objects.link(fo)
    cam = bpy.data.cameras.new('PreviewCam')
    cam.lens = 50
    co = bpy.data.objects.new('PreviewCam', cam)
    col.objects.link(co)
    scene.camera = co
    return col, co


def aim_camera(cam_obj, location, target):
    cam_obj.location = Vector(location)
    d = Vector(target) - Vector(location)
    cam_obj.rotation_euler = d.to_track_quat('-Z', 'Y').to_euler()


def render_to(scene, path):
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


def avatar_block(collection, location):
    """5-stud tall avatar-height reference block (2 x 1 x 5)."""
    me = bpy.data.meshes.new('AvatarRef5Studs')
    w, d, h = 1.0, 0.5, 5.0
    vs = [(-w, -d, 0), (w, -d, 0), (w, d, 0), (-w, d, 0), (-w, -d, h), (w, -d, h), (w, d, h), (-w, d, h)]
    fs = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    me.from_pydata(vs, [], fs)
    ob = bpy.data.objects.new('AvatarRef5Studs', me)
    ob.location = location
    ob.data.materials.append(flat_material('AvatarRefMat', hex_rgb('#8fb3d9')))
    collection.objects.link(ob)
    return ob


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)
