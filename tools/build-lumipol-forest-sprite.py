import bpy, math, os, json, hashlib, bmesh
from mathutils import Vector
from math import sin, cos, pi

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BASE = os.path.join(ROOT, 'assets', 'blender', 'lumipol-forest-sprite-v2')
BLEND, REPORT = BASE + '.blend', BASE + '-report.json'
outputs = [BLEND, REPORT] + [BASE + '-' + s + '.png' for s in ('preview','front','side','back')]
if any(os.path.exists(p) for p in outputs):
    raise RuntimeError('Output collision: refusing to overwrite existing artifacts')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
model = bpy.data.collections.new('Lumipol editable parts'); scene.collection.children.link(model)
preview = bpy.data.collections.new('Preview only'); scene.collection.children.link(preview)
def move(o, collection=model):
    for c in list(o.users_collection): c.objects.unlink(o)
    collection.objects.link(o)
    return o

def material(name, color, rough=.38, metallic=0, emission=0):
    m = bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough; p.inputs['Metallic'].default_value=metallic
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m

def gradient(name, bottom, top):
    m=material(name,top); n=m.node_tree.nodes; l=m.node_tree.links; p=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexCoord'); sep=n.new('ShaderNodeSeparateXYZ'); ramp=n.new('ShaderNodeValToRGB')
    ramp.color_ramp.elements[0].color=(*bottom,1); ramp.color_ramp.elements[1].color=(*top,1)
    l.new(tex.outputs['Generated'],sep.inputs[0]); l.new(sep.outputs['Z'],ramp.inputs[0]); l.new(ramp.outputs[0],p.inputs['Base Color'])
    return m
body=gradient('Body - blue teal gradient',(.075,.20,.37),(.15,.57,.57))
head=gradient('Face - aqua gradient',(.08,.32,.40),(.24,.68,.66))
capmat=gradient('Mantle - mint to blue',(.24,.75,.59),(.035,.19,.33))
pawmat=gradient('Paws - mint toes',(.31,.76,.59),(.13,.35,.50))
petalmat=gradient('Petals - lavender teal',(.19,.24,.58),(.20,.67,.72))
vein=material('Petal veins',(.40,.86,.90),.35,emission=.16)
stalk=gradient('Antenna blue',(.12,.30,.52),(.31,.60,.80))
cyan=material('Cyan luminous tips',(.26,1,.92),.22,emission=1.4)
spot=material('Mint markings',(.34,.94,.70),.34,emission=.14)
eyeouter=material('Eye rim',(.018,.045,.12),.2)
eye=gradient('Iris blue',(.025,.55,.78),(.015,.05,.27))
pupil=material('Pupil deep blue',(.008,.025,.10),.12)
white=material('Eye glints',(.9,1,1),.08,emission=.3)
mouth=material('Mouth',(.18,.045,.10),.4)
tongue=material('Mouth pink',(.83,.23,.30),.4)
gem=material('Chest crystal',(.15,.95,.75),.15,metallic=.2,emission=.65)
ground=material('Preview ground',(.17,.18,.21),.9)

def sphere(name, loc, scale, mat, segments=40, rings=24):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    o=move(bpy.context.object); o.name=name; o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    for p in o.data.polygons: p.use_smooth=True
    return o

def tube(name, coords, radius, mat, collection=model):
    curve=bpy.data.curves.new(name,'CURVE'); curve.dimensions='3D'; curve.resolution_u=24
    curve.bevel_depth=radius; curve.bevel_resolution=4; curve.use_fill_caps=True
    spline=curve.splines.new('BEZIER'); spline.bezier_points.add(len(coords)-1)
    for b, co in zip(spline.bezier_points,coords): b.co=co; b.handle_left_type='AUTO'; b.handle_right_type='AUTO'
    obj=bpy.data.objects.new(name,curve); collection.objects.link(obj); obj.data.materials.append(mat)
    return obj

# Forward is -Y; all pieces remain editable and have local origins.
sphere('Torso',(0,.30,.92),(.72,1.05,.59),body)
sphere('Chest',(0,-.44,1.05),(.49,.40,.55),head)
sphere('Neck',(0,-.40,1.48),(.39,.38,.40),head)
for x in (-.58,.58):
    for y in (-.43,.62):
        sphere('Leg bridge',(x,y,.56),(.32,.34,.43),body)
        sphere('Paw', (x,y,.27),(.40,.45,.29),pawmat)
        for dx in (-.18,0,.18):
            sphere('Toe',(x+dx,y-.29,.15),(.11,.13,.12),pawmat,24,16)
sphere('Head',(0,-.30,2.10),(1.02,.76,.74),head)
# Eye sockets, glossy irises, pupils and physical catchlights.
for x in (-.48,.48):
    sphere('Eye socket',(x,-.91,2.22),(.285,.075,.36),eyeouter)
    sphere('Eye iris',(x,-.973,2.23),(.238,.045,.305),eye)
    sphere('Eye pupil',(x,-1.013,2.27),(.165,.025,.235),pupil)
    sphere('Eye highlight',(x-.065,-1.037,2.40),(.068,.014,.075),white,24,16)
    sphere('Eye glimmer',(x+.075,-1.035,2.11),(.035,.012,.035),white,20,12)
sphere('Mouth',(0,-1.066,1.85),(.085,.035,.07),mouth,24,16)
sphere('Tongue',(0,-1.098,1.826),(.05,.014,.025),tongue,20,12)
for side in (-1,1):
    for i in range(7):
        x=side*(.68+.055*(i%3)); z=1.94+.065*(i//3)
        sphere('Cheek fleck',(x,-.90+(.05*(i%3)),z),(.028,.018,.028),spot,16,10)
# Rounded closed scalloped mantle with a radial dome and underside.
verts=[]; faces=[]; N=96; R=18
for j in range(R+1):
    t=j/R
    for i in range(N):
        a=2*pi*i/N; scallop=1+.055*cos(8*a)
        r=t*scallop
        verts.append((1.12*r*cos(a),-.29+.84*r*sin(a),2.52+.53*(1-t*t)-.075*t*cos(8*a)))
for j in range(R):
    for i in range(N):
        a=j*N+i; b=j*N+(i+1)%N; faces.append((a,b,b+N,a+N))
verts.append((0,-.29,2.48)); center=len(verts)-1
for i in range(N): faces.append((center,R*N+(i+1)%N,R*N+i))
mesh=bpy.data.meshes.new('Scalloped mantle mesh'); mesh.from_pydata(verts,[],faces); mesh.update()
bm=bmesh.new(); bm.from_mesh(mesh); bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00001); bm.to_mesh(mesh); bm.free()
o=bpy.data.objects.new('Scalloped mantle',mesh); model.objects.link(o); o.data.materials.append(capmat)
for p in mesh.polygons: p.use_smooth=True
# Markings conform approximately to the curved cap.
for x,y,s in [(-.34,-.37,.11),(.02,-.43,.13),(.37,-.30,.10),(-.18,.02,.09),(.22,.10,.12),(.0,.32,.08),(-.49,.10,.07)]:
    t=min(.95, math.sqrt((x/1.12)**2+((y+.29)/.84)**2)); z=2.52+.53*(1-t*t)
    sphere('Mantle spot',(x,y,z+.018),(s,s*.72,.025),spot,24,14)
# Six thick lens-shaped leaves; each is closed geometry rather than a plane.
def leaf(name, base, tip, width):
    base=Vector(base); tip=Vector(tip); axis=tip-base
    side=Vector((0,0,1))-axis.normalized()*axis.normalized().dot(Vector((0,0,1)))
    side.normalize(); normal=axis.cross(side).normalized()
    if normal.y > 0: normal.negate()
    verts=[]; faces=[]; steps=20; around=16
    for j in range(steps+1):
        t=j/steps; center=base+axis*t+normal*(.09*sin(pi*t)); w=width*sin(pi*t)**.8
        for i in range(around):
            a=2*pi*i/around; v=center+side*(w*cos(a))+normal*(.045*sin(pi*t)*sin(a)); verts.append(v-base)
    for j in range(steps):
        for i in range(around):
            a=j*around+i; b=j*around+(i+1)%around; faces.append((a,b,b+around,a+around))
    faces += [tuple(reversed(tuple(range(around)))),tuple(steps*around+i for i in range(around))]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update()
    obj=bpy.data.objects.new(name,mesh); model.objects.link(obj); obj.location=base; obj.data.materials.append(petalmat)
    for p in mesh.polygons: p.use_smooth=True
    # Veins follow the raised face, with branches in physical curve geometry.
    def pos(t, lateral=0): return base+axis*t+normal*(.09*sin(pi*t)+.049*sin(pi*t)+.008)+side*(width*sin(pi*t)**.8*lateral)
    tube(name+' midrib',[pos(.08),pos(.4),pos(.78),pos(.96)],.009,vein)
    for t in (.32,.55,.72):
        for sign in (-1,1): tube(name+' branch',[pos(t),pos(t+.12,sign*.65)],.0045,vein)
for side in (-1,1):
    for i,(z,tx,tz) in enumerate([(2.35,1.75,2.65),(2.12,1.92,2.17),(1.94,1.65,1.72)]):
        leaf('Petal %s %s'%(side,i),(side*.81,-.12,z),(side*tx,-.02,tz),.25)
for side in (-1,1):
    coords=[(side*.39,-.20,2.92),(side*.47,-.19,3.32),(side*.70,-.19,3.48),(side*.91,-.20,3.34)]
    tube('Antenna stalk',coords,.067,stalk)
    sphere('Antenna glowing tip',(side*.93,-.20,3.29),(.14,.13,.18),cyan,32,20)
# Faceted jewel, kept separate for editing.
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(0,-.835,1.13)); o=move(bpy.context.object); o.name='Faceted chest gem'; o.scale=(.18,.11,.30); bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); o.data.materials.append(gem)
sphere('Tail stem',(0,1.04,1.20),(.26,.37,.26),body)
bud=sphere('Tail leaf bud',(0,1.46,1.43),(.42,.40,.50),capmat)
# Narrow the upper end into a soft leaf-bud tip and lean it away from the body.
for v in bud.data.vertices:
    t=max(0.0,(v.co.z/.50+1)/2); v.co.x*=1-.58*t; v.co.y*=1-.42*t
bud.rotation_euler.x=.24
for side in (-1,1):
    tube('Tail bud vein',[(0,1.82,1.17),(side*.19,1.82,1.40),(side*.17,1.72,1.63),(0,1.54,1.90)],.012,vein)
# Preview setup is isolated and can be hidden without affecting the asset.
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.03)); floor=move(bpy.context.object,preview); floor.name='Preview floor'; floor.data.materials.append(ground)
def light(name,loc,power,size,color):
    bpy.ops.object.light_add(type='AREA',location=loc); o=move(bpy.context.object,preview); o.name=name; o.data.energy=power; o.data.shape='DISK'; o.data.size=size; o.data.color=color
    o.rotation_euler=(Vector((0,0,1.7))-o.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-4,-6,7),650,5,(.8,.94,1)); light('Fill',(4,-4,4),390,4,(.65,1,.95)); light('Rim',(1,4,6),600,3,(.40,.75,1))
world=scene.world; world.color=(.19,.19,.19)
bpy.ops.object.camera_add(); camera=move(bpy.context.object,preview); camera.name='Preview camera'; camera.data.type='ORTHO'; camera.data.ortho_scale=4.5; scene.camera=camera
scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.cycles.use_denoising=True
scene.render.resolution_x=700; scene.render.resolution_y=700; scene.render.resolution_percentage=100; scene.render.image_settings.file_format='PNG'
scene.view_settings.view_transform='AgX'
# Blender 5 uses a compositor node group rather than scene.node_tree.
scene.use_nodes=True
compositor=bpy.data.node_groups.new('Preview gentle glow','CompositorNodeTree')
compositor.interface.new_socket(name='Image',in_out='OUTPUT',socket_type='NodeSocketColor')
scene.compositing_node_group=compositor
rl=compositor.nodes.new('CompositorNodeRLayers'); glare=compositor.nodes.new('CompositorNodeGlare')
glare.inputs['Type'].default_value='Fog Glow'; glare.inputs['Quality'].default_value='High'
glare.inputs['Threshold'].default_value=1.2; glare.inputs['Strength'].default_value=.15
out=compositor.nodes.new('NodeGroupOutput')
compositor.links.new(rl.outputs['Image'],glare.inputs['Image']); compositor.links.new(glare.outputs['Image'],out.inputs['Image'])
# Report evaluated geometry, including curve conversion, and world bounds.
bpy.context.view_layer.update(); deps=bpy.context.evaluated_depsgraph_get(); objects=[]; bounds=[]
for obj in model.objects:
    evaluated=obj.evaluated_get(deps); mesh=evaluated.to_mesh(); mesh.calc_loop_triangles()
    bm=bmesh.new(); bm.from_mesh(mesh); nonmanifold=sum(not e.is_manifold for e in bm.edges); bm.free()
    bounds.extend(obj.matrix_world @ Vector(c) for c in obj.bound_box)
    objects.append({'name':obj.name,'type':obj.type,'vertices':len(mesh.vertices),'triangles':len(mesh.loop_triangles),'non_manifold_edges':nonmanifold,'origin':list(obj.location)})
    evaluated.to_mesh_clear()
mins=[min(v[i] for v in bounds) for i in range(3)]; maxs=[max(v[i] for v in bounds) for i in range(3)]
report={'forward':'-Y','units':'Blender units; Roblox conversion unverified','dimensions':[maxs[i]-mins[i] for i in range(3)],'triangles_total':sum(o['triangles'] for o in objects),'non_manifold_edges_total':sum(o['non_manifold_edges'] for o in objects),'objects':objects,'notes':'Static layered editable model; no rig, import, Studio test, or game effect. Overlapping parts are not unioned. Procedural materials may not transfer.'}
views={'preview':(-7,-5,4.0),'front':(0,-8,2.7),'side':(-8,0,2.7),'back':(0,8,2.7)}
for name,loc in views.items():
    camera.location=loc; camera.rotation_euler=(Vector((0,0,1.75))-camera.location).to_track_quat('-Z','Y').to_euler(); scene.render.filepath=BASE+'-'+name+'.png'
    bpy.ops.render.render(write_still=True)
camera.location=views['preview']; camera.rotation_euler=(Vector((0,0,1.75))-camera.location).to_track_quat('-Z','Y').to_euler(); scene.render.filepath=BASE+'-preview.png'
bpy.ops.wm.save_as_mainfile(filepath=BLEND)
for path in outputs:
    if os.path.exists(path):
        with open(path,'rb') as f: report[os.path.basename(path)+'_sha256']=hashlib.sha256(f.read()).hexdigest()
with open(REPORT,'w',encoding='utf-8') as f: json.dump(report,f,indent=2)
print('REPORT',json.dumps({'dimensions':report['dimensions'],'triangles':report['triangles_total'],'non_manifold':report['non_manifold_edges_total'],'objects':len(objects)}))
