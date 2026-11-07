import bpy, math, json, os, hashlib, sys
from mathutils import Vector
import bmesh

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
BASE = os.path.join(ROOT, 'assets', 'blender', 'lumipol-roblox-blockout-v1')
BLEND, PREVIEW, REPORT = BASE+'.blend', BASE+'-preview.png', BASE+'-report.json'
if any(os.path.exists(p) for p in (BLEND, PREVIEW, REPORT)):
    raise RuntimeError('Output collision: refusing to overwrite existing artifact')
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def mat(name, color, emission=0):
    m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Roughness'].default_value=.82
    if emission:
        p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=emission
    return m
cream=mat('Cream',(.79,.72,.59)); dark=mat('Charcoal',(.045,.047,.055)); mint=mat('Mint',(.30,.62,.43)); glow=mat('Cyan eyes',(.05,.9,.94),1.5)

def finish(obj,name,material):
    obj.name=name; obj.data.materials.append(material); return obj

def box(name,loc,dim,material,bevel=.12):
    bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object; o.dimensions=dim
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    mod=o.modifiers.new('Soft bevel','BEVEL'); mod.width=bevel; mod.segments=2
    bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier=mod.name)
    return finish(o,name,material)

def ico(name,loc,scale,material,rotation=(0,0,0),sub=2):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=sub,radius=1,location=loc); o=bpy.context.object; o.scale=scale; o.rotation_euler=rotation
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True); return finish(o,name,material)

def leaf(name,points,material):
    # Four-point outline plus raised center: closed folded diamond, not a plane.
    a,b,c,d=[Vector(p) for p in points]; center=(a+b+c+d)/4; normal=(b-a).cross(d-a).normalized()*.055
    verts=[a,b,c,d,center+normal,center-normal]
    faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,0,5),(2,1,5),(3,2,5),(0,3,5)]
    mesh=bpy.data.meshes.new(name); mesh.from_pydata(verts,[],faces); mesh.update(); o=bpy.data.objects.new(name,mesh); bpy.context.collection.objects.link(o); return finish(o,name,material)

box('Body',(0,0,1.05),(1.65,1.35,1.22),cream,.23)
for x in (-.52,.52):
    for y in (-.43,.43): box('Foot', (x,y,.19),(.42,.43,.38),dark,.075)
# Forward is -Y.
box('Face mask',(0,-.704,1.18),(1.10,.18,.83),dark,.16)
for x in (-.28,.28): ico('Eye',(x,-.813,1.21),(.07,.04,.115),glow,sub=2)
# Broad distinct collar petals.
for x in (-.69,.69): ico('Side petal',(x,-.48,.84),(.39,.30,.24),cream,(0,-x*.65,0))
for x in (-.36,.36): ico('Front petal',(x,-.72,.72),(.35,.23,.30),cream,(0,x*.6,0))
for x in (-.43,0,.43): ico('Forelock',(x,-.69,1.65),(.29,.22,.29 if x else .37),cream,(0,-x*.45,0))
leaf('Wide leaf',[(-.35,.02,1.62),(-.90,.12,1.94),(-1.53,.18,1.74),(-.92,-.10,1.53)],mint)
leaf('Upright leaf',[(.38,.05,1.68),(.33,.13,2.12),(.60,.14,2.51),(.77,-.02,2.01)],mint)
leaf('Tail',[(0,.62,1.03),(-.17,.91,1.19),(0,1.28,1.26),(.16,.95,1.06)],mint)
meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
# Floor and lighting are preview-only and separate from the modeled meshes.
floor=mat('Backdrop',(.18,.23,.20)); box('Preview floor',(0,0,-.12),(200,200,.2),floor,.01)
world=bpy.context.scene.world; world.color=(.22,.22,.22)
def light(name,loc,power,size):
    bpy.ops.object.light_add(type='AREA',location=loc); o=bpy.context.object; o.name=name; o.data.energy=power; o.data.shape='DISK'; o.data.size=size; o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
light('Key',(-3,-5,7),550,5); light('Fill',(4,-3,4),300,4); light('Rim',(1,4,6),450,3)
bpy.ops.object.camera_add(location=(-4.4,-7.0,3.5)); cam=bpy.context.object; cam.rotation_euler=(Vector((-.15,0,1.16))-cam.location).to_track_quat('-Z','Y').to_euler(); cam.data.type='ORTHO'; cam.data.ortho_scale=4.25; bpy.context.scene.camera=cam
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=32; scene.render.resolution_x=900; scene.render.resolution_y=900; scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'; scene.render.filepath=PREVIEW
scene.view_settings.view_transform='AgX'
# Report actual evaluated geometry and world-space dimensions.
bpy.context.view_layer.update(); bounds=[o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
mins=[min(v[i] for v in bounds) for i in range(3)]; maxs=[max(v[i] for v in bounds) for i in range(3)]
objects=[]
for o in meshes:
    bm=bmesh.new(); bm.from_mesh(o.data); nonmanifold=sum(not e.is_manifold for e in bm.edges); bm.free(); o.data.calc_loop_triangles()
    objects.append({'name':o.name,'vertices':len(o.data.vertices),'faces':len(o.data.polygons),'triangles':len(o.data.loop_triangles),'non_manifold_edges':nonmanifold,'scale':list(o.scale),'origin':list(o.location)})
report={'units_assumption':'1 Blender unit = 1 Roblox stud; not validated by Studio import','forward':'-Y (Blender); Roblox axis conversion unverified','bounds_min':mins,'bounds_max':maxs,'dimensions':[maxs[i]-mins[i] for i in range(3)],'objects':objects,'triangles_total':sum(x['triangles'] for x in objects),'non_manifold_edges_total':sum(x['non_manifold_edges'] for x in objects),'studio_import':'not performed','rig':'none; static editable blockout','preview_only_objects':['Preview floor','Key','Fill','Rim','Camera']}
bpy.ops.wm.save_as_mainfile(filepath=BLEND); bpy.ops.render.render(write_still=True)
for path in (BLEND,PREVIEW):
    with open(path,'rb') as f: report[os.path.basename(path)+'_sha256']=hashlib.sha256(f.read()).hexdigest()
with open(REPORT,'w',encoding='utf-8') as f: json.dump(report,f,indent=2)
print('LUMIPOL_REPORT',json.dumps(report))
