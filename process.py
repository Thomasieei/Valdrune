# blender -b --factory-startup -P process.py -- <asset_dir> <out_dir> <id> <kind> <cap> <texmax>
import bpy, sys, os, json, math, glob, re
from mathutils import Vector

a = sys.argv[sys.argv.index('--') + 1:]
ADIR, OUT, AID, KIND, CAP, TEXMAX = a[0], a[1], a[2], a[3], int(a[4]), int(a[5])
NORM = float(a[6]) if len(a) > 6 else 0.0
import numpy as np
rep = {'id': AID, 'kind': KIND}

def pick_main(d):
    files = [f for f in glob.glob(d + '/**/*', recursive=True) if os.path.isfile(f) and '__MACOSX' not in f]
    for ext in ('.glb', '.gltf', '.fbx', '.blend', '.obj', '.dae'):
        c = [f for f in files if f.lower().endswith(ext)]
        if c: return max(c, key=os.path.getsize)
    return None

def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)

def imp(p):
    e = p.lower().rsplit('.', 1)[-1]
    if e in ('glb', 'gltf'): bpy.ops.import_scene.gltf(filepath=p)
    elif e == 'fbx': bpy.ops.import_scene.fbx(filepath=p, use_anim=True, ignore_leaf_bones=True, automatic_bone_orientation=False)
    elif e == 'obj': bpy.ops.wm.obj_import(filepath=p)
    elif e == 'dae': bpy.ops.wm.collada_import(filepath=p)
    elif e == 'blend':
        bpy.ops.wm.open_mainfile(filepath=p)
        # keep only objects of the active scene
        sc = bpy.context.scene
        for s in list(bpy.data.scenes):
            if s != sc: bpy.data.scenes.remove(s)

def tris(objs):
    t = 0
    for o in objs:
        if o.type == 'MESH':
            for p in o.data.polygons: t += len(p.vertices) - 2
    return t

src = pick_main(ADIR); rep['source'] = os.path.relpath(src, ADIR) if src else None
if not src:
    rep['error'] = 'no model'; print('REPORT', json.dumps(rep)); sys.exit(0)
clear(); imp(src)
scene = bpy.context.scene
# drop non-geometry clutter (cameras/lights) and hidden helper meshes
for o in list(scene.objects):
    if o.type in ('CAMERA', 'LIGHT'): bpy.data.objects.remove(o, do_unlink=True)
JUNK = ('shadow', 'ground', 'vignette', 'floor', 'plane', 'pedestal', 'backdrop', 'sky')
for o in list(scene.objects):
    if o.type == 'MESH' and len(o.data.polygons) <= 60 and any(k in o.name.lower() or k in o.data.name.lower() for k in JUNK):
        bpy.data.objects.remove(o, do_unlink=True); rep['junk'] = rep.get('junk', 0) + 1
    elif o.type == 'MESH' and len(o.data.polygons) <= 2:
        bpy.data.objects.remove(o, do_unlink=True); rep['junk'] = rep.get('junk', 0) + 1
for o in scene.objects:
    if o.type == 'ARMATURE': o.data.pose_position = 'REST'
meshes = [o for o in scene.objects if o.type == 'MESH']
arms = [o for o in scene.objects if o.type == 'ARMATURE']
rep['tris_in'] = tris(meshes); rep['bones'] = sum(len(o.data.bones) for o in arms)

# ---- relink missing textures by basename
texfiles = [f for f in glob.glob(ADIR + '/**/*', recursive=True) if f.lower().endswith(('.png', '.jpg', '.jpeg', '.tga', '.bmp', '.tif', '.tiff', '.dds', '.webp'))]
def norm(s): return re.sub(r'\.(png|jpe?g|tga|bmp|tiff?|dds|webp)$', '', os.path.basename(s).lower().replace('\\', '/').split('/')[-1])
bykey = {}
for f in texfiles: bykey.setdefault(norm(f), f)
missing = 0
for im in bpy.data.images:
    if im.source != 'FILE' or im.packed_file: continue
    p = bpy.path.abspath(im.filepath)
    if not os.path.isfile(p):
        k = norm(im.filepath.replace('\\', '/'))
        cand = bykey.get(k) or next((v for kk, v in bykey.items() if k and (k in kk or kk in k)), None)
        if cand: im.filepath = cand; im.reload()
        else: missing += 1
rep['tex_missing'] = missing
def ok(im):
    try: return im is not None and im.has_data or (im is not None and im.size[0] > 0)
    except Exception: return False
nondds = [f for f in texfiles if not f.lower().endswith('.dds')]
for m in bpy.data.materials:
    if not m.use_nodes: continue
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type == 'TEX_IMAGE' and n.image is not None and not ok(n.image):
            isn = n.image.colorspace_settings.name == 'Non-Color' or 'norm' in n.image.name.lower()
            c = None
            if len(nondds) == 1 and not isn: c = nondds[0]
            if c: n.image = bpy.data.images.load(c, check_existing=True); rep['tex_fallback'] = rep.get('tex_fallback', 0) + 1
            else: nt.nodes.remove(n); rep['tex_dropped'] = rep.get('tex_dropped', 0) + 1

# ---- materials without any image: try to wire textures folder (base/normal)
def find_tex(words):
    for f in texfiles:
        n = os.path.basename(f).lower()
        if any(w in n for w in words) and not f.lower().endswith('.dds'): return f
    return None
for m in bpy.data.materials:
    if not m.use_nodes: continue
    nt = m.node_tree
    bsdf = next((n for n in nt.nodes if n.type == 'BSDF_PRINCIPLED'), None)
    if not bsdf: continue
    if bsdf.inputs['Base Color'].is_linked: continue
    base = find_tex(['basecolor', 'base_color', 'albedo', 'diffuse', '_co.', 'color', 'difuse', 'alb'])
    if not base and len([f for f in texfiles if not f.lower().endswith('.dds')]) == 1:
        base = [f for f in texfiles if not f.lower().endswith('.dds')][0]
    if base:
        t = nt.nodes.new('ShaderNodeTexImage'); t.image = bpy.data.images.load(base, check_existing=True)
        nt.links.new(t.outputs['Color'], bsdf.inputs['Base Color'])
        nrm = find_tex(['normal', '_nm.', '_n.'])
        if nrm:
            t2 = nt.nodes.new('ShaderNodeTexImage'); t2.image = bpy.data.images.load(nrm, check_existing=True); t2.image.colorspace_settings.name = 'Non-Color'
            nm = nt.nodes.new('ShaderNodeNormalMap'); nt.links.new(t2.outputs['Color'], nm.inputs['Color']); nt.links.new(nm.outputs['Normal'], bsdf.inputs['Normal'])
        rep['tex_autowired'] = rep.get('tex_autowired', 0) + 1

# ---- single-user + remove shape keys (needed to apply modifiers)
for o in meshes:
    if o.data.users > 1: o.data = o.data.copy()
    if o.data.shape_keys:
        o.shape_key_clear()

# ---- apply generative modifiers (array/mirror/subsurf...) on static meshes
for o in [o for o in scene.objects if o.type == 'MESH']:
    if any(m.type == 'ARMATURE' for m in o.modifiers): continue
    bpy.context.view_layer.objects.active = o
    for m in list(o.modifiers):
        try: bpy.ops.object.modifier_apply(modifier=m.name)
        except Exception: o.modifiers.remove(m)
meshes = [o for o in scene.objects if o.type == 'MESH']
# ---- join environment meshes
if KIND == 'env':
    bpy.ops.object.select_all(action='DESELECT')
    for o in scene.objects: o.hide_set(False); o.hide_viewport = False
    for o in meshes: o.select_set(True)
    if meshes:
        bpy.context.view_layer.objects.active = meshes[0]
        bpy.ops.object.parent_clear(type='CLEAR_KEEP_TRANSFORM')
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        bpy.ops.object.join()
        for o in list(scene.objects):
            if o.type == 'EMPTY' and not o.children: bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in scene.objects if o.type == 'MESH']

# ---- decimate
t0 = tris(meshes)
if CAP and t0 > CAP:
    r = max(CAP / t0, 0.002)
    for o in meshes:
        if len(o.data.polygons) < 40: continue
        bpy.context.view_layer.objects.active = o
        mod = o.modifiers.new('dec', 'DECIMATE'); mod.ratio = r; mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_move_to_index(modifier='dec', index=0)
        try: bpy.ops.object.modifier_apply(modifier='dec')
        except Exception as e: rep['dec_err'] = str(e)[:120]; o.modifiers.remove(mod)
rep['tris_out'] = tris([o for o in scene.objects if o.type == 'MESH'])

# ---- textures resize + recompress (saved to disk so the exporter uses them)
TD = os.path.join(ADIR, '_tex'); os.makedirs(TD, exist_ok=True)
for i, im in enumerate(list(bpy.data.images)):
    try:
        if im.size[0] == 0: continue
        w, h = im.size; sc_ = min(1.0, TEXMAX / max(w, h))
        if sc_ < 1: im.scale(max(1, int(w * sc_)), max(1, int(h * sc_)))
        data = im.colorspace_settings.name == 'Non-Color' or 'norm' in im.name.lower()
        alpha = False
        if im.channels == 4:
            px = np.empty(len(im.pixels), np.float32); im.pixels.foreach_get(px); alpha = bool(px[3::4].min() < 0.99)
        fmt, ext = ('PNG', '.png') if (data or alpha) else ('JPEG', '.jpg')
        dst = os.path.join(TD, f'{i}{ext}')
        im.filepath_raw = dst; im.file_format = fmt
        bpy.context.scene.render.image_settings.quality = 88
        im.save(); 
        if im.packed_file: im.unpack(method='REMOVE')
        im.filepath = dst; im.reload()
    except Exception as e: rep['tex_err'] = str(e)[:100]

# ---- evaluated robust bbox + normalisation
def ebbox(objs):
    dg = bpy.context.evaluated_depsgraph_get(); pts = []
    for o in objs:
        oe = o.evaluated_get(dg); me = oe.to_mesh()
        n = len(me.vertices)
        if n:
            co = np.empty(n * 3, np.float32); me.vertices.foreach_get('co', co); co = co.reshape(-1, 3)
            M = np.array(oe.matrix_world); co = co @ M[:3, :3].T + M[:3, 3]; pts.append(co)
        oe.to_mesh_clear()
    if not pts: return np.zeros(3), np.ones(3)
    P = np.concatenate(pts); return np.percentile(P, 0.3, 0), np.percentile(P, 99.7, 0)
ms_ = [o for o in scene.objects if o.type == 'MESH']
mn, mx = ebbox(ms_)
if NORM > 0 and KIND == 'char' and (mx - mn)[1] > 1.3 * (mx - mn)[2]:
    rt = bpy.data.objects.new('Upright', None); scene.collection.objects.link(rt)
    for o in list(scene.objects):
        if o is not rt and o.parent is None:
            mw = o.matrix_world.copy(); o.parent = rt; o.matrix_world = mw
    rt.rotation_euler = (math.radians(90), 0, 0); bpy.context.view_layer.update(); mn, mx = ebbox(ms_)
    if (mx - mn)[2] < 0: pass
    rep['uprighted'] = True
if NORM and KIND != 'env' and KIND != 'kit':
    ext_ = mx - mn; cur = ext_[2] if NORM > 0 else ext_.max(); s_ = abs(NORM) / max(cur, 1e-6)
    root = bpy.data.objects.new('Root', None); scene.collection.objects.link(root)
    for o in list(scene.objects):
        if o is not root and o.parent is None:
            mw = o.matrix_world.copy(); o.parent = root; o.matrix_world = mw
    root.scale = (s_, s_, s_)
    c_ = (mn + mx) / 2
    root.location = (-c_[0] * s_, -c_[1] * s_, -mn[2] * s_)
    bpy.context.view_layer.update(); mn, mx = ebbox(ms_); rep['scale'] = round(float(s_), 5)
rep['size_m'] = [round(float(x), 2) for x in (mx - mn)]
acts = [ac.name for ac in bpy.data.actions]
rep['anims'] = len(acts); rep['anim_names'] = acts[:50]

for o in scene.objects:
    if o.type == 'ARMATURE': o.data.pose_position = 'POSE'
os.makedirs(OUT, exist_ok=True)
out = os.path.join(OUT, AID + '.glb')
kw = dict(filepath=out, export_format='GLB', export_image_format='AUTO', export_apply=True, export_animations=bool(arms) or bool(acts), export_yup=True)
try: bpy.ops.export_scene.gltf(export_animation_mode='ACTIONS', **kw)
except TypeError: bpy.ops.export_scene.gltf(**kw)
rep['mb_out'] = round(os.path.getsize(out) / 1e6, 2)

# ---- verify by reimport + preview render
clear(); bpy.ops.import_scene.gltf(filepath=out)
sc = bpy.context.scene
ms = [o for o in sc.objects if o.type == 'MESH']
for o in sc.objects:
    if o.type == 'ARMATURE': o.data.pose_position = 'REST'
rep['verify_tris'] = tris(ms); rep['verify_anims'] = len(bpy.data.actions)
rep['verify_skinned'] = any(m.type == 'ARMATURE' for o in ms for m in o.modifiers)
mn, mx = ebbox(ms); mn = Vector(mn.tolist()); mx = Vector(mx.tolist())
ctr = (mn + mx) / 2; rad = max((mx - mn).length / 2, 1e-3)
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam')); sc.collection.objects.link(cam); sc.camera = cam
cam.data.lens = 50
d = rad / math.tan(cam.data.angle / 2) * 1.05
dirv = Vector((0.55, -1.0, 0.35)).normalized()
cam.location = ctr + dirv * d
cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
cam.data.clip_end = d * 10; cam.data.clip_start = d / 1000
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN')); sun.data.energy = 3; sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(50), math.radians(10), math.radians(30))
w = bpy.data.worlds.new('w'); sc.world = w; w.use_nodes = True; w.node_tree.nodes['Background'].inputs[0].default_value = (0.35, 0.37, 0.42, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 1.0
sc.render.engine = 'CYCLES'; sc.cycles.samples = 12; sc.cycles.device = 'CPU'
try: sc.cycles.use_denoising = False
except Exception: pass
sc.render.resolution_x = sc.render.resolution_y = 360
sc.render.filepath = os.path.join(OUT, AID + '.png')
try: bpy.ops.render.render(write_still=True); rep['preview'] = True
except Exception as e: rep['preview_err'] = str(e)[:120]
print('REPORT', json.dumps(rep))
