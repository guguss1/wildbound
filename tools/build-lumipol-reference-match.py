"""Reconstruct the six-view Lumipol reference in an isolated Blender process.

Blender: --background --factory-startup --python-exit-code 1 --python <this file>
Blender: --background --factory-startup <output blend> --python-exit-code 1 --python <this file> -- --verify
Python (Pillow/NumPy): <this file> --compare <directory containing the six screenshots>
"""
from __future__ import annotations

import hashlib
import json
import math as m
from pathlib import Path
import sys


OUT = Path(__file__).resolve().parents[1] / "assets/blender/lumipol-reference-match"
BLEND = OUT / "Lumipol_Reference_Match.blend"
# name, screenshot key, size, silhouette pixel bounds, UI exclusion, view direction, up, distance
VIEWS = (
    ("front", "cf432446", (446, 350), (53, 28, 414, 333), (107, 94), (0, -1, .085), (0, 0, 1), 16),
    ("side", "d0bec6c6", (306, 360), (45, 36, 303, 337), (51, 107), (1, -.215, .12), (0, 0, 1), 13),
    ("back", "43726cf0", (373, 327), (9, 19, 369, 307), (67, 86), (.092, 1, .12), (0, 0, 1), 15),
    ("underneath", "c5d9e350", (395, 402), (66, 34, 342, 390), (85, 141), (.015, .055, -1), (-1, 0, 0), 13),
    ("low-front", "d4a901b5", (376, 327), (18, 22, 375, 311), (66, 91), (0, -1, -.61), (0, 0, 1), 12),
    ("top", "54d10115", (401, 302), (21, 24, 388, 284), (77, 101), (.05, -.045, 1), (0, 1, 0), 14),
)
HEAD_X, HEAD_Y, HEAD_Z = 1.255, 1.25, 1.03
HEAD_Y0, HEAD_Z0 = -.13, 2.47
TAU = 2 * m.pi
CHEEK_SPECKLES = (
    (.98, 2.09, .036), (1.061, 2.15, .036), (1.12, 2.20, .031), (1.16, 2.13, .035),
    (1.022, 2.01, .029), (1.081, 2.054, .036), (1.13, 2.087, .026),
    (.986, 1.976, .023), (1.046, 1.956, .023), (1.15, 2.02, .028), (1.18, 2.06, .023),
)


def clamp(value):
    return min(1.0, max(0.0, value))


def ease(start, stop, value):
    t = clamp((value - start) / (stop - start))
    return t * t * (3 - 2 * t)


def rgb(hex_color):
    srgb = [int(hex_color[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(v / 12.92 if v < .04045 else ((v + .055) / 1.055) ** 2.4 for v in srgb)


def mix(a, b, t):
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def gauss(value):
    return m.exp(-value * value)


def profile(points, t):
    """Cubic Hermite interpolation through the measured control sections."""
    i = min(len(points) - 2, int(t * (len(points) - 1)))
    u = t * (len(points) - 1) - i
    a, b = points[i], points[i + 1]
    left, right = points[max(0, i - 1)], points[min(len(points) - 1, i + 2)]
    return tuple(
        (2*u**3 - 3*u*u + 1)*x + (u**3 - 2*u*u + u)*(y-l)*.5
        + (-2*u**3 + 3*u*u)*y + (u**3-u*u)*(r-x)*.5
        for l, x, y, r in zip(left, a, b, right)
    )


def material(name, roughness, *, coat=0, scatter=0, glow=0, transmission=0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    shader = mat.node_tree.nodes.get("Principled BSDF")
    ink = mat.node_tree.nodes.new("ShaderNodeVertexColor")
    ink.layer_name = "Pigment"
    for key, value in {
        "Roughness": roughness, "Coat Weight": coat, "Coat Roughness": .15,
        "Subsurface Weight": scatter, "Subsurface Radius": (.22, .34, .42),
        "Emission Strength": glow, "Transmission Weight": transmission,
    }.items():
        shader.inputs[key].default_value = value
    for socket in ("Base Color", "Emission Color"):
        mat.node_tree.links.new(ink.outputs["Color"], shader.inputs[socket])
    return mat


def paint(mesh, pigments):
    ink = mesh.color_attributes.new(name="Pigment", type="FLOAT_COLOR", domain="POINT")
    ink.data.foreach_set("color", [value for color in pigments for value in (*color, 1.0)])


def surface(name, fn, mat=None, rows=50, columns=64):
    """Create an editable, closed longitudinal surface from position/color samples."""
    samples = [
        fn(.0004 + .9992 * i / rows, TAU * j / columns)
        for i in range(rows + 1) for j in range(columns)
    ]
    quads = [
        (i*columns+j, i*columns+(j+1) % columns, (i+1)*columns+(j+1) % columns, (i+1)*columns+j)
        for i in range(rows) for j in range(columns)
    ]
    end = rows * columns
    quads.extend((tuple(reversed(range(columns))), tuple(range(end, end + columns))))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([point for point, _ in samples], [], quads)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    character.objects.link(obj)
    if mat:
        mesh.materials.append(mat)
        paint(mesh, (pigment for _, pigment in samples))
    for poly in mesh.polygons:
        poly.use_smooth = True
    return obj


def face_y(x, z):
    height = (z - HEAD_Z0) / HEAD_Z
    for _ in range(4):
        height = (z - HEAD_Z0 + .24*ease(.25, 1, height)) / HEAD_Z
    width = HEAD_X * (1 - .095*height)
    return HEAD_Y0 - HEAD_Y * m.sqrt(max(0.002, 1 - height*height - (x/width)**2))


def ellipsoid(name, center, dims, *, shaped_head=False, flatten=False):
    def point(t, a):
        h = -m.cos(m.pi*t)
        r = m.sin(m.pi*t)
        x = center[0] + dims[0]*r*m.cos(a)*(1-.095*h if shaped_head else 1)
        y = center[1] + dims[1]*r*m.sin(a)
        z = center[2] + dims[2]*h
        if shaped_head:
            z -= .24*ease(.25, 1, h)
            # A shallow lip cavity lives in the skin, not as a freestanding disc.
            y += .078*gauss(x/.090)*gauss((z-1.885)/.074)*ease(-.88, -1.08, y)
        if flatten:
            z = max(z, .108 + .012*(y-center[1]))
        return (x, y, z), None
    return surface(name, point, rows=36)


def union_skin(mat):
    hulls = [
        ellipsoid("Cranium", (0, HEAD_Y0, HEAD_Z0), (HEAD_X, HEAD_Y, HEAD_Z), shaped_head=True),
        ellipsoid("Pear torso", (0, .09, .84), (.70, .94, .64)),
        ellipsoid("Throat", (0, -.33, 1.41), (.44, .48, .65)),
        ellipsoid("Rounded bib", (0, -.58, 1.04), (.47, .38, .53)),
    ]
    feet = []
    for side in (-1, 1):
        for rear, y in ((False, -.67), (True, .62)):
            x = side*(.64 if rear else .60)
            feet.append((x, y))
            hulls.append(ellipsoid("Hamstring" if rear else "Foreleg",
                                  (x*.85, y+.083, .60 if rear else .67),
                                  (.33, .41 if rear else .32, .55)))
            hulls.append(ellipsoid("Flattened paw", (x, y-.055, .35),
                                  (.36, .39, .31), flatten=True))
            for j in (-1, 0, 1):
                hulls.append(ellipsoid("Sculpted toe", (x+j*.199, y-.454+.047*abs(j), .230),
                                      (.122, .187-.026*abs(j), .173-.020*abs(j)), flatten=True))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in hulls:
        obj.select_set(True)
    skin = hulls[0]
    bpy.context.view_layer.objects.active = skin
    bpy.ops.object.join()
    skin.name = "01 • Continuous skin — head, torso, four paws"
    skin.data.remesh_voxel_size = .022
    bpy.ops.object.voxel_remesh()
    smooth = skin.modifiers.new("Blend anatomical junctions", "SMOOTH")
    smooth.factor, smooth.iterations = .87, 12
    bpy.ops.object.modifier_apply(modifier=smooth.name)
    sub = skin.modifiers.new("Silhouette polish", "SUBSURF")
    sub.levels = sub.render_levels = 1
    skin.data.materials.append(mat)
    for poly in skin.data.polygons:
        poly.use_smooth = True

    base, shaded, muzzle = map(rgb, ("366f85", "134961", "aedfce"))
    bib, mint, outsole, freckle = map(rgb, ("a8e4a0", "b3fab9", "78a895", "caf4d1"))
    cheek_spots = [(sx, face_y(sx, sz), sz, r) for sx, sz, r in CHEEK_SPECKLES]
    rump_spots = [
        (.00, .61, 1.43, .075), (.15, .64, 1.40, .085), (-.15, .66, 1.36, .076),
        (.23, .72, 1.29, .09), (.31, .77, 1.22, .057), (.02, .78, 1.33, .069),
        (-.29, .72, 1.27, .078), (-.41, .66, 1.24, .061), (.45, .73, 1.12, .055),
        (-.49, .60, 1.15, .049), (.44, .86, 1.04, .032), (-.21, .83, 1.23, .055),
        (.06, .86, 1.22, .046), (-.40, .83, 1.11, .035), (.20, .88, 1.19, .031),
    ]

    def skin_color(vertex):
        x, y, z = vertex.co
        col = mix(base, shaded, .72*ease(-.62, .87, y))
        front = ease(-.30, -1.12, y)
        cheek = gauss((z-2.02)/.49) * front
        col = mix(col, muzzle, cheek*.95)
        chest = gauss(x/.48)**1.45 * ease(-.28, -.74, y) * ease(1.82, 1.43, z)
        col = mix(col, bib, chest*.94)
        for fx, fy in feet:
            zone = ease(fy-.22, fy-.49, y) * ease(.58, .27, z) * gauss((x-fx)/.45)
            toes = max(gauss((x-fx-.199*j)/.113) for j in (-1, 0, 1))
            col = mix(col, mint, clamp(zone*(.48 + .94*toes)))
        col = mix(col, outsole, .78*ease(.178, .108, z))
        if y < 0 and 1.88 < z < 2.27 and abs(x) > .90:
            point = (abs(x), y, z)
            spot = max(ease(1.17, .39, m.dist(point, (sx, sy, sz))/r) for sx, sy, sz, r in cheek_spots)
            col = mix(col, freckle, spot*.95)
        if y > .35 and .88 < z < 1.62:
            spot = max(ease(1, .68, m.dist((x, y, z), (sx, sy, sz))/r) for sx, sy, sz, r in rump_spots)
            col = mix(col, mint, spot*.88)
        return col

    paint(skin.data, map(skin_color, skin.data.vertices))
    return skin


def hood(mat):
    teal, ridge, rim, spot = map(rgb, ("2b6079", "538996", "aadfa0", "a3f6ba"))
    spots = (
        (0, -1.20, .11), (-.15, -.98, .067), (.14, -.98, .076), (.25, -.86, .092),
        (-.25, -.82, .09), (-.12, -.79, .067), (.08, -.73, .070),
        (0, -.58, .178), (-.42, -.34, .071), (.43, -.31, .075),
        (-.25, -.09, .211), (.23, -.07, .227), (.04, .16, .080),
        (-.25, .29, .132), (.31, .33, .09), (-.08, .42, .151), (.19, .46, .09),
        (.40, .47, .059), (-.43, .35, .053), (-.29, .57, .047), (.10, .59, .04),
        (.0, .70, .059), (.26, .64, .033), (-.12, .75, .034),
        (-.82, -.89, .070), (.86, -.90, .072), (-.95, -.75, .047), (.98, -.75, .048),
    )

    def point(t, a):
        wave = (.5+.5*m.cos(10*a))**1.65
        front = (.5+.5*m.cos(a))**3
        rear = (.5-.5*m.cos(a))**1.3
        if t < .68:
            r = top_r = .94*t/.68
            drop = 0
        elif t < .79:
            roll = m.pi*(t-.68)/.11
            r, top_r = .94 + .060*m.sin(roll), .94
            drop = .076*(1-m.cos(roll))
        else:
            r = top_r = .94*(1-t)/.21
            drop = .152 + .68*(1-r/.94)
        x = m.sin(a)*r*(1.43 + .15*wave*r**5)
        y = -.06 - m.cos(a)*r*(1.32 + .14*wave*r**5 + .11*front*r**5)
        z = 3.54 - .76*top_r**1.47 - (.145*wave+.055*front)*top_r**5 - drop
        z += (.067*front - .24*rear)*top_r**3.4
        z -= .049*front*gauss(m.sin(a)/.25)*top_r**5
        z += .066*m.cos(10*a)*top_r**2*(1-.58*top_r) + .048*m.sin(m.pi*top_r)
        margin = ease(.64, .995, r) * (.27 + .73*front)
        color = mix(teal, ridge, .10 + .35*r + .29*wave*r)
        color = mix(color, rim, margin)
        fleck = max(ease(1.07, .68, m.hypot((x-sx)/w, (y-sy)/(w*1.13))) for sx, sy, w in spots)
        return (x, y, z), mix(color, spot, fleck * (t < .71) * .98)

    return surface("02 • Scalloped crown with mint dorsal freckles", point, mat, 166, 236)


def face_patch(project, name, center, radii, mat, pigment, relief, tilt=0.0, rows=38, columns=84):
    def point(s, a):
        outer = .79
        t = s/outer if s <= outer else (1-s)/(1-outer)
        u, v = t*m.cos(a), t*m.sin(a)
        x = center[0] + radii[0]*(u + tilt*v)
        z = center[1] + radii[1]*v
        backing = .075*ease(outer, .92, s)
        return (x, project(x, z)-relief(t, u, v)+backing, z), pigment(t, u, v)
    return surface(name, point, mat, rows, columns)


def face(skin, skin_mat, eye_mat, mouth_mat):
    from mathutils.bvhtree import BVHTree

    mesh = BVHTree.FromObject(skin, bpy.context.evaluated_depsgraph_get())

    def project(x, z):
        hit, _, _, _ = mesh.ray_cast((x, -4, z), (0, 1, 0), 5.0)
        return hit.y if hit is not None else face_y(x, z)

    navy, ink, blue, aqua, white = map(rgb, ("101337", "191952", "1e56ae", "3bdefb", "fff9ff"))
    liner, lip, recess, tongue = map(rgb, ("3c6872", "badbc4", "43182e", "fa7888"))
    for side, label in ((-1, "L"), (1, "R")):
        x, z = side*.685, 2.315
        face_patch(project, "Inset eyelid • "+label, (x, z), (.358, .420), skin_mat,
                   lambda t, u, v: mix(mix(liner, lip, .85*ease(.33, -.64, v)), liner, ease(.83, 1, t)),
                   lambda t, u, v: .069*(1-t*t)-.007, -.15*side)

        def iris(t, u, v):
            color = mix(ink, blue, ease(-.02, -.82, v))
            color = mix(color, aqua, ease(-.33, -.98, v)*.94)
            color = mix(color, navy, ease(.80, 1.01, t)*.80)
            for su, sv, rx, ry, alpha in ((-.30, .49, .145, .184, .97), (-.08, .38, .069, .075, .86),
                                         (.38, .51, .07, .051, .52), (.44, -.14, .085, .14, .23)):
                color = mix(color, white, alpha*ease(1.15, .70, m.hypot((u-su)/rx, (v-sv)/ry)))
            return color

        face_patch(project, "Deep glossy iris • "+label, (x, z), (.320, .386), eye_mat, iris,
                   lambda t, u, v: .134*(1-t*t)+.017, -.15*side, 68, 108)
        face_patch(project, "Low brow • "+label, (side*.60, 2.748), (.155, .046), skin_mat,
                   lambda t, u, v: mix(liner, rgb("659297"), .4+.45*t),
                   lambda t, u, v: .030*(1-t*t)-.010, .29*side, 18, 48)
        face_patch(project, "Nostril • "+label, (side*.073, 2.074), (.045, .016), skin_mat,
                   lambda t, u, v: mix(rgb("7899a3"), rgb("a2c9c5"), t),
                   lambda t, u, v: .007-.009*t*t, -.8*side, 12, 38)

    face_patch(project, "Tiny open mouth", (0, 1.885), (.088, .070), mouth_mat,
               lambda t, u, v: mix(mix(recess, tongue, ease(.10, -.70, v)), rgb("a3c9b6"), ease(.83, 1, t)),
               lambda t, u, v: .009-.010*t*t, rows=38, columns=76)


def petal(name, mat, start, end, width, seed, *, tail=False):
    a, b = Vector(start), Vector(end)
    axis = (b-a).normalized()
    basis = Vector((1, 0, 0) if tail else (0, -.70, .71))
    across = (basis-axis*basis.dot(axis)).normalized()
    depth = axis.cross(across).normalized()
    if not tail and depth.y > 0:
        depth.negate()
    teal, mint, violet, veins = map(rgb, ("276a7b", "67c8ba", "a889fa", "c8dcfd"))

    def point(t, theta):
        u, v = m.cos(theta), m.sin(theta)
        tip = (1-ease(.70, 1, t))**(.15 if tail else .32)
        blade = m.sin(m.pi*t)**(.61 if tail else .78) * (.67+.71*t) * tip
        arc = .11 if tail else .040
        center = a.lerp(b, t) + Vector((0, 0, arc*m.sin(m.pi*t))) + depth*(.055*m.sin(m.pi*t))
        flutes = (1+.048*m.cos(6*theta)) if tail else 1
        x = blade*width*u
        if tail:
            x *= 1-.26*max(0, v)+.08*max(0, -v)
        thickness = (.45 if tail else .061)*blade*v*flutes
        p = center + across*x*flutes + depth*(thickness + x*x*.43 + .035*x*m.sin(TAU*t+seed))
        color = mix(teal, mint, ease(.11, .89, t)*.80 + .16*abs(u))
        color = mix(color, violet, ease(.38, .96, t)*(.48 if tail else .63)
                    + ease(.63, 1, abs(u))*(.08 if tail else .54))
        if tail:
            vein = ease(.92, .999, m.cos(6*theta)) * ease(.17, .46, t) * ease(1, .91, t)
        else:
            vein = .75*gauss(u/.028)
            for k in (.26, .43, .59, .73):
                growth = (t-k)/.22
                if 0 < growth < 1:
                    f = growth**.83
                    vein = max(vein, .61*gauss((abs(u)-f)/.058)*m.sin(m.pi*growth)**.39)
        color = mix(color, veins, .66*vein*ease(.04, .30, t))
        return p, color

    return surface(name, point, mat, 92, 132)


def antenna(side, mat):
    teal, blue, lilac, mint = map(rgb, ("347d8f", "6599be", "aea3ed", "a1f7e4"))
    path = (
        (.43, -.63, 3.115, .088), (.46, -.64, 3.49, .075), (.54, -.65, 3.80, .070),
        (.68, -.63, 3.941, .059), (.89, -.61, 4.018, .063), (1.11, -.59, 3.974, .070),
        (1.29, -.57, 3.835, .105), (1.42, -.56, 3.691, .232), (1.43, -.55, 3.531, .166),
        (1.40, -.54, 3.423, .007),
    )

    def point(t, a):
        x, y, z, r = profile(path, t)
        left, right = profile(path, max(0, t-.001)), profile(path, min(1, t+.001))
        tangent = Vector((side*(right[0]-left[0]), right[1]-left[1], right[2]-left[2])).normalized()
        tangent = tangent.lerp(Vector((side*.29, 0, -.958)), ease(.66, .83, t)).normalized()
        width = tangent.cross(Vector((0, 1, 0))).normalized()
        depth = width.cross(tangent).normalized()
        p = Vector((side*x, y, z)) + r*(width*m.cos(a) + depth*m.sin(a)*.85)
        col = mix(teal, blue, ease(0, .45, t))
        col = mix(col, lilac, ease(.20, .57, t))
        col = mix(col, mint, ease(.62, .84, t)*.96)
        return p, col

    return surface("Luminous curved antenna • " + ("L" if side < 0 else "R"), point, mat, 110)


def crystal(mat):
    green, bright, core = map(rgb, ("2fa994", "80f9c9", "ffeedf"))

    def point(t, a):
        h = -m.cos(m.pi*t)
        taper = m.sin(m.pi*t)**1.17 * (1+.13*h)
        facet = 1+.10*m.cos(6*a)
        x = .23*taper*m.cos(a)*facet
        y = -.935 + .112*taper*m.sin(a)*facet
        z = 1.08+.300*h
        flash = (.5+.5*m.cos(6*a))*ease(.10, .35, t)
        color = mix(green, bright, .31+.44*flash)
        color = mix(color, core, .91*gauss((t-.29)/.092)*ease(.60, 1, -m.sin(a)))
        return (x, y, z), color

    return surface("Inset chest crystal • six curved facets", point, mat, 46, 48)


def studio_light(name, xyz, target, power, color, size):
    data = bpy.data.lights.new(name, "AREA")
    data.energy, data.shape, data.size, data.color = power, "DISK", size, color
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = xyz
    obj.rotation_euler = (Vector(target)-obj.location).to_track_quat("-Z", "Y").to_euler()


def camera(spec, scene, vertices):
    name, _, dims, target, _, direction, up, distance = spec
    forward = -Vector(direction).normalized()
    right = forward.cross(Vector(up)).normalized()
    real_up = right.cross(forward)
    origin = Vector((0, 0, 2.1)) - forward*distance
    data = bpy.data.cameras.new(name)
    data.lens = 47
    obj = bpy.data.objects.new(name, data)
    studio.objects.link(obj)
    obj.location = origin
    obj.rotation_euler = Matrix((right, real_up, -forward)).transposed().to_euler()
    obj["Reference render width"] = dims[0] * 2
    obj["Reference render height"] = dims[1] * 2
    scene.render.resolution_x, scene.render.resolution_y = dims

    def bounds():
        bpy.context.view_layer.update()
        projection = obj.calc_matrix_camera(bpy.context.evaluated_depsgraph_get(), x=dims[0], y=dims[1])
        transform = projection @ obj.matrix_world.inverted()
        projected = [transform @ p.to_4d() for p in vertices]
        x = [(1+p.x/p.w)*dims[0]/2 for p in projected]
        y = [(1-p.y/p.w)*dims[1]/2 for p in projected]
        return min(x), min(y), max(x), max(y)

    x0, y0, x1, y1 = bounds()
    l, t, r, b = target
    data.lens *= m.sqrt(((r-l)/(x1-x0))*((b-t)/(y1-y0)))
    x0, y0, x1, y1 = bounds()
    data.shift_x = (x0+x1-l-r) / (2*max(dims))
    data.shift_y = -(y0+y1-t-b) / (2*max(dims))
    return obj


def build(draft):
    global character, studio
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    scene = bpy.context.scene
    character = bpy.data.collections.new("Lumipol • editable geometry")
    studio = bpy.data.collections.new("Comparison cameras and studio lights")
    scene.collection.children.link(character)
    scene.collection.children.link(studio)
    skin = material("Living teal skin", .49, coat=.09, scatter=.085)
    crown = material("Scalloped leaf crown", .40, coat=.15, scatter=.12)
    eye = material("Glossy dark iris and cyan caustic", .22, coat=.44, glow=.055)
    mouth = material("Mouth interior", .44)
    leaf = material("Cupped petal • blue, lilac, fine veins", .34, coat=.13, scatter=.11, glow=.16, transmission=.12)
    lamp = material("Luminous antenna tissue", .28, coat=.23, scatter=.12, glow=.22)
    gem = material("Glowing heart crystal", .25, coat=.20, scatter=.07, glow=.68, transmission=.11)
    body = union_skin(skin)
    hood(crown)
    face(body, skin, eye, mouth)
    for s, label in ((-1, "L"), (1, "R")):
        for i, (start, end, width) in enumerate((
            ((1.00, -.27, 2.62), (2.28, .19, 3.005), .45),
            ((1.07, -.28, 2.34), (2.59, .12, 2.401), .49),
            ((1.02, -.27, 2.07), (2.02, .00, 1.704), .39),
        ), 1):
            petal(f"Petal {label}{i} • cupped veined blade", leaf,
                  (s*start[0], *start[1:]), (s*end[0], *end[1:]), width, i*.81)
        antenna(s, lamp)
    petal("Lobed tail bud • radiating veins", leaf, (-.02, .79, .59), (-.20, 2.09, 1.23), .54, .3, tail=True)
    crystal(gem)
    world = bpy.data.worlds.new("Soft blue environment")
    world.use_nodes = True
    world.node_tree.nodes.get("Background").inputs[0].default_value = (.31, .38, .45, 1)
    world.node_tree.nodes.get("Background").inputs[1].default_value = .52
    scene.world = world
    studio_light("Softbox key", (-4, -6, 7), (0, 0, 2), 560, (1.0, .95, .85), 4.8)
    studio_light("Cool broad fill", (4, -3, 4), (0, 0, 2), 265, (.76, .90, 1.0), 5.4)
    studio_light("Lilac edge", (2, 3.5, 6), (0, 0, 2), 400, (.72, .76, 1.0), 5.1)
    studio_light("Mint rear fill", (-4, 3.8, 3), (0, 0, 2), 310, (.78, 1.0, .92), 5.3)
    studio_light("Underbody bounce", (0, -2, -4), (0, 0, 1), 150, (.73, .91, .92), 6.4)
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8 if draft else 22
    scene.cycles.adaptive_min_samples = 6
    scene.cycles.adaptive_threshold = .032
    scene.cycles.use_denoising = True
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.render.resolution_percentage = 100 if draft else 200
    scene.render.threads_mode = "FIXED"
    scene.render.threads = 14
    # Frame against a representative sample of the actual shared geometry, not the references.
    vertices = [o.matrix_world @ v.co for o in character.objects for v in o.data.vertices]
    cameras = [camera(spec, scene, vertices) for spec in VIEWS]
    scene.camera = cameras[0]
    notes = bpy.data.texts.new("READ ME — Lumipol")
    notes.write(
        "Single editable character built from six supplied visual references.\n"
        "The head, torso, legs, and paw lobes share one closed, continuous skin mesh.\n"
        "The hood, eyes, gem, antennae, petals and bud remain independently editable.\n"
        "Surface colors live in the Pigment point-color attribute; there are no linked images.\n"
        "Six calibrated cameras are grouped with lighting. Use each camera's custom properties\n"
        "for the intended width and height at 100% render scale, or keep front as opened.\n"
        "This asset is not rigged or export-optimized; the source viewpoints were estimated.\n"
    )
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                region = area.spaces.active.region_3d
                region.view_perspective = "CAMERA"
                area.spaces.active.shading.color_type = "VERTEX"
    OUT.mkdir(parents=True, exist_ok=True)
    if not draft:
        scene.render.resolution_x, scene.render.resolution_y = VIEWS[0][2]
        scene.render.filepath = "//front.png"
        bpy.ops.wm.save_as_mainfile(filepath=str(BLEND), compress=True)
    for spec, cam in zip(VIEWS, cameras):
        name, _, dims, *_ = spec
        scene.camera = cam
        scene.render.resolution_x, scene.render.resolution_y = dims
        scene.render.filepath = str(OUT / (("draft-" if draft else "") + name + ".png"))
        bpy.ops.render.render(write_still=True)


def verify():
    from mathutils.bvhtree import BVHTree

    assert Path(bpy.data.filepath).resolve() == BLEND
    scene = bpy.context.scene
    models = bpy.data.collections["Lumipol • editable geometry"].objects
    skin = next(o for o in models if o.name.startswith("01"))
    assert sum("Petal " in o.name for o in models) == 6
    assert sum("antenna " in o.name for o in models) == 2
    assert scene.camera.name == "front" and all(bpy.data.objects[n].type == "CAMERA" for n, *_ in VIEWS)
    assert all(o.type == "MESH" and o.data.color_attributes.get("Pigment") for o in models)
    assert not bpy.data.libraries and not any(i.source == "FILE" for i in bpy.data.images)
    bm = bmesh.new()
    bm.from_mesh(skin.data)
    assert all(e.is_manifold for e in bm.edges), "Open edges in the continuous skin"
    unseen = set(bm.verts)
    pending = [unseen.pop()]
    while pending:
        v = pending.pop()
        for e in v.link_edges:
            neighbor = e.other_vert(v)
            if neighbor in unseen:
                unseen.remove(neighbor)
                pending.append(neighbor)
    bm.free()
    assert not unseen, "Disconnected islands in the continuous skin"
    depsgraph = bpy.context.evaluated_depsgraph_get()
    body_bvh = BVHTree.FromObject(skin, depsgraph)
    hood = next(o for o in models if o.name.startswith("02"))
    hood_bvh = BVHTree.FromObject(hood, depsgraph)
    for obj in models:
        if obj.name.startswith(("Petal ", "Lobed tail bud", "Inset chest crystal", "Luminous curved antenna")):
            anchor = hood_bvh if "antenna" in obj.name else body_bvh
            assert anchor.overlap(BVHTree.FromObject(obj, depsgraph)), f"Floating feature: {obj.name}"
    print(f"REOPEN VERIFIED: {bpy.app.version_string}, {len(models)} editable meshes, "
          f"{len(skin.data.vertices)} contiguous skin vertices, six cameras, attached appendages, no external assets")


def compare(source, draft=False):
    from PIL import Image, ImageDraw, ImageFont, ImageFilter
    import numpy as np

    title = ImageFont.truetype("arialbd.ttf", 23)
    small = ImageFont.truetype("arial.ttf", 15)
    grid = Image.new("RGB", (1696, 1178), "#171c26")
    canvas = ImageDraw.Draw(grid)
    canvas.text((24, 16), "LUMIPOL  /  SIX-VIEW RECONSTRUCTION", fill="#eef1ff", font=title)
    canvas.text((24, 49), "Reference (left)   /   Blender render (middle)   /   silhouette overlap (right)", fill="#aab5cb", font=small)
    stats = {}
    for i, (name, key, dims, _, (ui_x, ui_y), *_) in enumerate(VIEWS):
        ref_file, = source.glob(f"codex-clipboard-{key}*.png")
        ref = Image.open(ref_file).convert("RGB")
        assert ref.size == dims
        render_file = OUT / (("draft-" if draft else "") + name + ".png")
        rendered = Image.open(render_file).convert("RGBA")
        assert rendered.size == tuple(d*(1 if draft else 2) for d in dims)
        assert rendered.getextrema()[3] == (0, 255)
        layer = rendered.resize(dims, Image.Resampling.LANCZOS)
        rgba = np.asarray(layer)
        arr = np.asarray(ref, dtype=np.int16)
        rm = (arr.max(2)-arr.min(2) > 17) & (arr.max(2) > 54)
        rm[:ui_y, :ui_x] = False
        rm = np.asarray(Image.fromarray(rm).convert("L").filter(ImageFilter.MaxFilter(3))
                        .filter(ImageFilter.MinFilter(3))) > 0
        mm = rgba[:, :, 3] > 126
        union, both = rm | mm, rm & mm
        agreement = np.count_nonzero(both) / np.count_nonzero(union)
        stats[name] = {"silhouette_iou": round(agreement, 3), "reference_sha256": hashlib.sha256(ref_file.read_bytes()).hexdigest(),
                       "render_sha256": hashlib.sha256(render_file.read_bytes()).hexdigest()}
        matte = Image.new("RGBA", dims, (37, 38, 43, 255))
        display = Image.alpha_composite(matte, layer).convert("RGB")
        diag = np.full_like(arr, [37, 38, 43])
        diag[rm & ~mm], diag[mm & ~rm], diag[both] = [197, 128, 219], [89, 213, 190], [128, 147, 179]
        tiles = [ref, display, Image.fromarray(diag.astype("uint8"))]
        x, y = 24 + (i % 2)*834, 85 + (i // 2)*355
        canvas.text((x, y), f"{name.upper()}   /   {agreement:.0%} silhouette overlap", fill="#dceaff", font=small)
        for j, (label, tile) in enumerate(zip(("REFERENCE", "RENDER", "OVERLAP"), tiles)):
            px = x + j*271
            canvas.rectangle((px, y+27, px+266, y+326), fill="#25262b")
            tile.thumbnail((266, 299), Image.Resampling.LANCZOS)
            grid.paste(tile, (px+(266-tile.width)//2, y+27+(299-tile.height)//2))
            canvas.text((px+7, y+329), label, fill="#aab5cb", font=small)
    canvas.text((24, 1151), "Overlap: lavender = reference only, mint = render only, slate = both. Viewer controls excluded from mask.", fill="#aab5cb", font=small)
    grid.save(OUT / ("draft-comparison.png" if draft else "comparison.png"))
    if not draft:
        (OUT / "comparison-metrics.json").write_text(json.dumps(stats, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({n: d["silhouette_iou"] for n, d in stats.items()}))


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    if args[:1] == ["--compare"]:
        compare(Path(args[1]), "--draft" in args)
    else:
        import bmesh
        import bpy
        from mathutils import Matrix, Vector

        verify() if "--verify" in args else build("--draft" in args)
