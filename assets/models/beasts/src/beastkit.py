"""Shared helpers for building faceted low-poly Wildbound beasts in headless Blender.

Units: 1 Blender metre = 1 Roblox stud. Z is up, creatures face -Y.
Every part is rigidly skinned (weight 1.0) to exactly one bone, which suits the
"stacked stone / rock" construction and keeps Roblox skinning at one influence.
"""

import math
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector


# --------------------------------------------------------------------------- scene


def reset_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.unit_settings.system = "METRIC"
    scene.unit_settings.scale_length = 1.0
    return scene


def get_collection(name, parent=None):
    col = bpy.data.collections.get(name)
    if col is None:
        col = bpy.data.collections.new(name)
        (parent or bpy.context.scene.collection).children.link(col)
    return col


# --------------------------------------------------------------------------- mesh builder


class Builder:
    """Accumulates rigid parts into one bmesh with deform weights and palette colour ids."""

    def __init__(self, palette, seed=7):
        self.bm = bmesh.new()
        self.dl = self.bm.verts.layers.deform.verify()
        self.cl = self.bm.faces.layers.int.new("color_id")
        self.palette = palette  # list of (name, (r,g,b) sRGB, emissive bool)
        self.color_index = {name: i for i, (name, _c, _e) in enumerate(palette)}
        self.groups = []
        self.rng = random.Random(seed)
        self.parts = 0

    def _group(self, bone):
        if bone not in self.groups:
            self.groups.append(bone)
        return self.groups.index(bone)

    def _append(self, tmp, color, bone):
        gi = self._group(bone)
        ci = self.color_index[color]
        vmap = {}
        for v in tmp.verts:
            nv = self.bm.verts.new(v.co)
            nv[self.dl][gi] = 1.0
            vmap[v] = nv
        for f in tmp.faces:
            try:
                nf = self.bm.faces.new([vmap[v] for v in f.verts])
            except ValueError:
                continue
            nf[self.cl] = ci
        tmp.free()
        self.parts += 1

    def _jitter(self, tmp, amount):
        if amount <= 0:
            return
        for v in tmp.verts:
            v.co += Vector(
                (
                    self.rng.uniform(-amount, amount),
                    self.rng.uniform(-amount, amount),
                    self.rng.uniform(-amount, amount),
                )
            )

    # -- primitives ----------------------------------------------------------

    def rock(self, center, size, color, bone, rot=(0, 0, 0), bevel=0.14, jitter=0.06, taper=(1.0, 1.0)):
        """Chamfered, jittered box: the basic faceted stone block."""
        t = bmesh.new()
        bmesh.ops.create_cube(t, size=1.0)
        for v in t.verts:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y *= taper[1]
        if bevel > 0:
            bmesh.ops.bevel(
                t,
                geom=list(t.edges),
                offset=bevel,
                offset_type="OFFSET",
                segments=1,
                profile=0.5,
                affect="EDGES",
                clamp_overlap=True,
            )
        self._jitter(t, jitter)
        m = (
            Matrix.Translation(Vector(center))
            @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4()
            @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0)))
        )
        bmesh.ops.transform(t, matrix=m, verts=t.verts)
        self._append(t, color, bone)

    def prism(self, p0, p1, r0, r1, color, bone, sides=6, jitter=0.04, twist=0.0):
        """Tapered faceted limb segment from p0 to p1 (r1 == 0 gives a spike)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        length = d.length
        t = bmesh.new()
        bmesh.ops.create_cone(
            t,
            cap_ends=True,
            cap_tris=False,
            segments=sides,
            radius1=r0,
            radius2=max(r1, 0.0),
            depth=1.0,
        )
        if r1 <= 0.0:
            bmesh.ops.remove_doubles(t, verts=t.verts, dist=1e-5)
        # jitter in normalised space (scaled by radius so spikes stay sharp)
        for v in t.verts:
            if abs(v.co.x) + abs(v.co.y) > 1e-6:
                v.co.x += self.rng.uniform(-jitter, jitter)
                v.co.y += self.rng.uniform(-jitter, jitter)
        m = (
            Matrix.Translation((p0 + p1) * 0.5)
            @ Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
            @ Matrix.Rotation(math.radians(twist), 4, "Z")
            @ Matrix.Diagonal(Vector((1.0, 1.0, length, 1.0)))
        )
        bmesh.ops.transform(t, matrix=m, verts=t.verts)
        self._append(t, color, bone)

    def plate(self, points, thickness, color, bone, normal=None, jitter=0.0):
        """Thick polygonal slab (wing membranes, flat moss, algae sheets)."""
        pts = [Vector(p) for p in points]
        if normal is None:
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0]).normalized()
        normal = Vector(normal).normalized()
        half = normal * (thickness * 0.5)
        t = bmesh.new()
        top = [t.verts.new(p + half) for p in pts]
        bot = [t.verts.new(p - half) for p in pts]
        t.faces.new(top)
        t.faces.new(list(reversed(bot)))
        n = len(pts)
        for i in range(n):
            j = (i + 1) % n
            t.faces.new([top[i], bot[i], bot[j], top[j]])
        self._jitter(t, jitter)
        self._append(t, color, bone)

    def arched_plate(self, points, thickness, bow, color, bone, normal=None, scallop=(), depth=0.0, segs=3, jitter=0.0):
        """Thick slab that bows out between its corners (an arched wing panel).

        points: polygon corners. normal: the side the panel bows toward. bow: how far the
        middle bulges (studs). scallop: indices i of edges (points[i] -> points[i + 1]) that
        curve inward by `depth` x edge length, like the scalloped trailing edge of a wing.
        """
        pts = [Vector(p) for p in points]
        n = len(pts)
        if normal is None:
            normal = (pts[1] - pts[0]).cross(pts[2] - pts[0])
        normal = Vector(normal).normalized()
        c = sum(pts, Vector()) / n
        rim = []
        for i in range(n):
            a, b = pts[i], pts[(i + 1) % n]
            for s in range(segs):
                t = s / segs
                p = a.lerp(b, t)
                if i in scallop and s > 0:
                    p = p + (c - p).normalized() * (math.sin(math.pi * t) * depth * (b - a).length)
                rim.append(p)
        m = len(rim)
        ring = [c.lerp(p, 0.55) for p in rim]

        def lift(p, r):
            return p + normal * (bow * (1.0 - r * r))
        t = bmesh.new()
        half = normal * (thickness * 0.5)
        layers = []
        for sgn in (1, -1):
            layers.append((
                [t.verts.new(lift(p, 1.0) + half * sgn) for p in rim],
                [t.verts.new(lift(p, 0.55) + half * sgn) for p in ring],
                t.verts.new(lift(c, 0.0) + half * sgn),
            ))
        for li, (r0, r1, cv) in enumerate(layers):
            for i in range(m):
                j = (i + 1) % m
                quad = [r0[i], r0[j], r1[j], r1[i]]
                tri = [r1[i], r1[j], cv]
                if li == 1:
                    quad.reverse()
                    tri.reverse()
                t.faces.new(quad)
                t.faces.new(tri)
        top, bot = layers[0][0], layers[1][0]
        for i in range(m):
            j = (i + 1) % m
            t.faces.new([top[j], top[i], bot[i], bot[j]])
        self._jitter(t, jitter)
        self._append(t, color, bone)

    def mirror(self, fn, **kwargs):
        """Call a primitive (keyword args only) for the left side (+X) and mirrored (-X).

        Mirrors center/p0/p1/points/normal positions, rot eulers and "_L" bone names.
        """
        fn(**kwargs)
        fn(**{k: _mirror_value(v, k) for k, v in kwargs.items()})

    # -- finish ----------------------------------------------------------------

    def to_object(self, name, collection):
        bm = self.bm
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bmesh.ops.triangulate(bm, faces=bm.faces)
        me = bpy.data.meshes.new(name)
        uv = bm.loops.layers.uv.new("UVMap")
        n = len(self.palette)
        for f in bm.faces:
            ci = f[self.cl]
            u = (ci + 0.5) / n
            for loop in f.loops:
                loop[uv].uv = (u, 0.5)
            f.material_index = 1 if self.palette[ci][2] else 0
            f.smooth = False
        bm.to_mesh(me)
        bm.free()
        obj = bpy.data.objects.new(name, me)
        collection.objects.link(obj)
        for g in self.groups:
            obj.vertex_groups.new(name=g)
        return obj


def _mirror_value(v, key):
    if key == "bone":
        return v.replace("_L_", "_R_") if "_L_" in v else (v[:-2] + "_R" if v.endswith("_L") else v)
    if key == "rot":
        return (v[0], -v[1], -v[2])
    if key in ("center", "p0", "p1", "normal"):
        return (-v[0], v[1], v[2])
    if key == "points":
        return [(-p[0], p[1], p[2]) for p in v]
    return v


# --------------------------------------------------------------------------- palette + materials


def make_palette_materials(prefix, palette, out_png):
    """One palette texture (flat swatches) + one emissive material for glowing parts."""
    n = len(palette)
    w, h = n * 8, 8
    img = bpy.data.images.new(f"{prefix}_Palette", width=w, height=h, alpha=False)
    px = []
    for _y in range(h):
        for x in range(w):
            r, g, b = palette[x // 8][1]
            px.extend((r, g, b, 1.0))
    img.pixels[:] = px
    img.filepath_raw = out_png
    img.file_format = "PNG"
    img.save()
    img.filepath = out_png

    mat = bpy.data.materials.new(f"{prefix}_Palette")
    mat.use_nodes = True
    nt = mat.node_tree
    bsdf = next(nd for nd in nt.nodes if nd.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = 0.95
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Closest"
    nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    mat.diffuse_color = (*palette[0][1], 1.0)

    glow_rgb = next(c for (_n, c, e) in palette if e)
    glow = bpy.data.materials.new(f"{prefix}_EyeGlow")
    glow.use_nodes = True
    gb = next(nd for nd in glow.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
    gb.inputs["Base Color"].default_value = (*srgb_to_linear(glow_rgb), 1.0)
    gb.inputs["Emission Color"].default_value = (*srgb_to_linear(glow_rgb), 1.0)
    gb.inputs["Emission Strength"].default_value = 6.0
    glow.diffuse_color = (*glow_rgb, 1.0)
    return mat, glow


def srgb_to_linear(c):
    def f(x):
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4

    return tuple(f(x) for x in c)


def flat_material(name, rgb, alpha=1.0, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    b = next(nd for nd in mat.node_tree.nodes if nd.type == "BSDF_PRINCIPLED")
    b.inputs["Base Color"].default_value = (*srgb_to_linear(rgb), 1.0)
    b.inputs["Roughness"].default_value = 0.9
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
    if emission:
        b.inputs["Emission Color"].default_value = (*srgb_to_linear(rgb), 1.0)
        b.inputs["Emission Strength"].default_value = emission
    mat.diffuse_color = (*rgb, alpha)
    return mat


# --------------------------------------------------------------------------- armature


def build_armature(name, bones, collection):
    """bones: list of (name, head, tail, parent or None, connected)."""
    arm = bpy.data.armatures.new(name)
    obj = bpy.data.objects.new(name, arm)
    collection.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    for bname, head, tail, parent, connect in bones:
        eb = arm.edit_bones.new(bname)
        eb.head = head
        eb.tail = tail
        eb.roll = 0.0
        if parent:
            eb.parent = arm.edit_bones[parent]
            eb.use_connect = connect
    bpy.ops.object.mode_set(mode="OBJECT")
    obj.show_in_front = True
    for pb in obj.pose.bones:
        pb.rotation_mode = "QUATERNION"
    return obj


def skin(mesh_obj, arm_obj):
    mesh_obj.parent = arm_obj
    mod = mesh_obj.modifiers.new("Armature", "ARMATURE")
    mod.object = arm_obj


def world_rot(arm_obj, bone_name, axis, deg):
    """Quaternion for a pose bone that rotates `deg` about a WORLD axis (rest frame)."""
    bone = arm_obj.data.bones[bone_name]
    local_axis = bone.matrix_local.to_3x3().inverted() @ Vector(axis)
    return Quaternion(local_axis.normalized(), math.radians(deg))


def apply_pose(arm_obj, pose):
    """pose: {bone: {"rot": [(axis, deg), ...], "loc": (x,y,z) world offset}}."""
    for pb in arm_obj.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = Vector()
    for bname, spec in pose.items():
        pb = arm_obj.pose.bones[bname]
        q = Quaternion()
        for axis, deg in spec.get("rot", []):
            q = world_rot(arm_obj, bname, axis, deg) @ q
        pb.rotation_quaternion = q
        if "loc" in spec:
            bone = arm_obj.data.bones[bname]
            pb.location = bone.matrix_local.to_3x3().inverted() @ Vector(spec["loc"])
    bpy.context.view_layer.update()


def make_action(arm_obj, action_name, keys, fps=30):
    """keys: list of (frame, pose_dict). Creates a fake-user action and leaves it unassigned."""
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    arm_obj.animation_data.action = None
    for frame, pose in keys:
        apply_pose(arm_obj, pose)
        for pb in arm_obj.pose.bones:
            pb.keyframe_insert("rotation_quaternion", frame=frame)
            pb.keyframe_insert("location", frame=frame)
    act = arm_obj.animation_data.action
    act.name = action_name
    act.use_fake_user = True
    arm_obj.animation_data.action = None
    apply_pose(arm_obj, {})
    return act


def set_action(arm_obj, act, frame):
    if arm_obj.animation_data is None:
        arm_obj.animation_data_create()
    arm_obj.animation_data.action = act
    if act is None:
        apply_pose(arm_obj, {})
    else:
        try:
            if arm_obj.animation_data.action_slot is None and len(act.slots):
                arm_obj.animation_data.action_slot = act.slots[0]
        except AttributeError:
            pass
    bpy.context.scene.frame_set(frame)
    bpy.context.view_layer.update()


# --------------------------------------------------------------------------- utilities


def tri_count(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def world_bbox(obj, depsgraph=None):
    depsgraph = depsgraph or bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(depsgraph)
    me = ev.to_mesh()
    mw = obj.matrix_world
    pts = [mw @ v.co for v in me.vertices]
    ev.to_mesh_clear()
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return mn, mx


def collision_proxy(name, boxes, collection):
    """boxes: list of (center, size). Returns one joined low-poly mesh (12 tris per box)."""
    bm = bmesh.new()
    for center, size in boxes:
        t = bmesh.ops.create_cube(bm, size=1.0)
        m = Matrix.Translation(Vector(center)) @ Matrix.Diagonal(Vector((*size, 1.0)))
        bmesh.ops.transform(bm, matrix=m, verts=t["verts"])
    bmesh.ops.triangulate(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    collection.objects.link(obj)
    obj.display_type = "WIRE"
    obj.hide_render = True
    return obj


# --------------------------------------------------------------------------- preview rendering


def setup_preview(scene, preview_col, ground=True, ground_rgb=(0.16, 0.15, 0.18)):
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 800
    scene.render.film_transparent = False
    try:
        scene.view_settings.view_transform = "Standard"
    except TypeError:
        pass
    world = bpy.data.worlds.new("PreviewWorld")
    scene.world = world
    world.use_nodes = True
    bg = next(nd for nd in world.node_tree.nodes if nd.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.035, 0.033, 0.042, 1.0)
    bg.inputs["Strength"].default_value = 1.0

    sun = bpy.data.lights.new("Preview_Key", "SUN")
    sun.energy = 3.2
    sun.angle = math.radians(8)
    so = bpy.data.objects.new("Preview_Key", sun)
    so.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)))
    preview_col.objects.link(so)
    fill = bpy.data.lights.new("Preview_Fill", "SUN")
    fill.energy = 0.9
    fo = bpy.data.objects.new("Preview_Fill", fill)
    fo.rotation_euler = Euler((math.radians(65), 0, math.radians(150)))
    preview_col.objects.link(fo)
    rim = bpy.data.lights.new("Preview_Rim", "SUN")
    rim.energy = 1.2
    ro = bpy.data.objects.new("Preview_Rim", rim)
    ro.rotation_euler = Euler((math.radians(-60), 0, math.radians(10)))
    preview_col.objects.link(ro)

    if ground:
        bpy.ops.mesh.primitive_plane_add(size=80, location=(0, 0, 0))
        g = bpy.context.active_object
        g.name = "Preview_Ground"
        for c in g.users_collection:
            c.objects.unlink(g)
        preview_col.objects.link(g)
        g.data.materials.append(flat_material("Preview_GroundMat", ground_rgb))

    cam_data = bpy.data.cameras.new("Preview_Cam")
    cam_data.lens = 50
    cam = bpy.data.objects.new("Preview_Cam", cam_data)
    preview_col.objects.link(cam)
    scene.camera = cam
    return cam


def avatar_block(preview_col, location):
    """A 5-stud-tall Roblox-avatar-sized reference block (2 x 1 x 5)."""
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=(location[0], location[1], 2.5))
    b = bpy.context.active_object
    b.name = "Preview_AvatarRef_5stud"
    b.scale = (2.0, 1.0, 5.0)
    for c in b.users_collection:
        c.objects.unlink(b)
    preview_col.objects.link(b)
    b.data.materials.append(flat_material("Preview_AvatarMat", (0.85, 0.62, 0.30)))
    return b


def shoot(scene, cam, target, direction, distance, path, lens=50, ortho=None):
    target = Vector(target)
    d = Vector(direction).normalized()
    cam.location = target + d * distance
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.data.lens = lens
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
    scene.render.filepath = path
    bpy.ops.render.render(write_still=True)


# --------------------------------------------------------------------------- export


def select_only(objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.hide_set(False)
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]


def export_anim_fbx(path, arm_obj, mesh_obj, act):
    """Rig + skinned mesh with exactly one baked action (for Roblox's FBX animation import)."""
    set_action(arm_obj, act, int(act.frame_range[0]))
    scene = bpy.context.scene
    scene.frame_start, scene.frame_end = int(act.frame_range[0]), int(act.frame_range[1])
    select_only([arm_obj, mesh_obj])
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=False,
        add_leaf_bones=False,
        bake_anim=True,
        bake_anim_use_all_actions=False,
        bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=True,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
    )
    set_action(arm_obj, None, 1)


def export_fbx(path, objs, animated, bake=None):
    """animated=True keeps the armature deform live; bake=False exports the rig with no animation."""
    bake = animated if bake is None else bake
    select_only(objs)
    bpy.ops.export_scene.fbx(
        filepath=path,
        use_selection=True,
        object_types={"ARMATURE", "MESH"},
        apply_unit_scale=True,
        apply_scale_options="FBX_SCALE_NONE",
        mesh_smooth_type="FACE",
        use_mesh_modifiers=not animated,
        add_leaf_bones=False,
        bake_anim=bake,
        bake_anim_use_all_actions=bake,
        bake_anim_use_nla_strips=False,
        bake_anim_force_startend_keying=True,
        path_mode="COPY",
        embed_textures=True,
        axis_forward="-Z",
        axis_up="Y",
    )


def static_copy(mesh_obj, name, collection):
    """Evaluated (posed) copy of a skinned mesh with no armature dependency."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = mesh_obj.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev, preserve_all_data_layers=True, depsgraph=dg)
    obj = bpy.data.objects.new(name, me)
    obj.matrix_world = mesh_obj.matrix_world.copy()
    collection.objects.link(obj)
    return obj
