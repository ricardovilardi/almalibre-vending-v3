# Blender 4.1 — rotating Almalibre açaí cup (turntable, transparent background).
# Usage: Blender -b -P scripts/cup_scene.py -- <texture.png> <out_prefix> [frame_start frame_end] [--samples N] [--save scene.blend]
import bpy, bmesh, math, sys, os
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:]
TEX, OUT = argv[0], argv[1]
rest = argv[2:]
def opt(name, default):
    if name in rest:
        i = rest.index(name); v = rest[i + 1]; del rest[i:i + 2]; return v
    return default
SAMPLES = int(opt("--samples", "128"))
SAVE = opt("--save", None)
FRAMES = int(opt("--frames", "192"))          # frames for one full 360° turn
F0, F1 = (int(rest[0]), int(rest[1])) if len(rest) >= 2 else (1, 1)

R_TOP, R_BOT, H = 1.0, 0.85, 1.48
U_LOGO = 0.2125                                  # logo centre in the texture (u)

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ---------- materials ----------
def principled(name, color=None, rough=0.5, coat=0.0):
    m = bpy.data.materials.new(name); m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    if color: b.inputs["Base Color"].default_value = (*color, 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Coat Weight"].default_value = coat
    return m, b

TEXCO = []                                      # texture-coordinate nodes, bound to the turntable below
def node(nt, kind, **inputs):
    n = nt.nodes.new(kind)
    for k, v in inputs.items(): n.inputs[k].default_value = v
    return n
def coords(nt):
    tc = nt.nodes.new("ShaderNodeTexCoord"); TEXCO.append(tc); return tc.outputs["Object"]

def paper_bump(nt, strength):
    """fine paper fibre + very soft unevenness"""
    co = coords(nt)
    fib = node(nt, "ShaderNodeTexNoise", Scale=420.0, Detail=8.0, Roughness=0.7)
    fib.noise_dimensions = "3D"; nt.links.new(co, fib.inputs["Vector"])
    soft = node(nt, "ShaderNodeTexNoise", Scale=9.0, Detail=2.0)
    nt.links.new(co, soft.inputs["Vector"])
    b1 = node(nt, "ShaderNodeBump", Strength=strength, Distance=0.002)
    nt.links.new(fib.outputs["Fac"], b1.inputs["Height"])
    b2 = node(nt, "ShaderNodeBump", Strength=0.04, Distance=0.01)
    nt.links.new(soft.outputs["Fac"], b2.inputs["Height"]); nt.links.new(b1.outputs["Normal"], b2.inputs["Normal"])
    return b2.outputs["Normal"]

# printed paper: matte ink with a faint satin varnish, paper fibre
m_print, b = principled("cup_print", rough=0.52, coat=0.08)
nt = m_print.node_tree
img = nt.nodes.new("ShaderNodeTexImage"); img.image = bpy.data.images.load(TEX)
img.interpolation = "Cubic"
nt.links.new(img.outputs["Color"], b.inputs["Base Color"])
nt.links.new(paper_bump(nt, 0.05), b.inputs["Normal"])
b.inputs["Coat Roughness"].default_value = 0.35

# plain paper (inside, rim, bottom): warm off-white, matte
m_paper, bp = principled("cup_paper", (0.88, 0.86, 0.82), rough=0.68)
bp.inputs["Subsurface Weight"].default_value = 0.05
m_paper.node_tree.links.new(paper_bump(m_paper.node_tree, 0.06), bp.inputs["Normal"])

# açaí sorbet: dense, slightly grainy, wet satin highlights, colour variation
m_acai, ba = principled("acai", rough=0.3, coat=0.3)
nta = m_acai.node_tree; co = coords(nta)
ba.inputs["Coat Roughness"].default_value = 0.14
ba.inputs["Subsurface Weight"].default_value = 0.18
ba.inputs["Subsurface Radius"].default_value = (0.45, 0.04, 0.3)
ba.inputs["Subsurface Scale"].default_value = 0.04
# colour: deep violet with magenta-ish patches
var = node(nta, "ShaderNodeTexNoise", Scale=5.0, Detail=3.0); nta.links.new(co, var.inputs["Vector"])
ramp = nta.nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].position = 0.35; ramp.color_ramp.elements[0].color = (0.065, 0.005, 0.034, 1)
ramp.color_ramp.elements[1].position = 0.7;  ramp.color_ramp.elements[1].color = (0.15, 0.012, 0.07, 1)
nta.links.new(var.outputs["Fac"], ramp.inputs["Fac"]); nta.links.new(ramp.outputs["Color"], ba.inputs["Base Color"])
# micro grain + tiny pores (sorbet texture)
grain = node(nta, "ShaderNodeTexNoise", Scale=170.0, Detail=12.0, Roughness=0.72); nta.links.new(co, grain.inputs["Vector"])
pores = node(nta, "ShaderNodeTexVoronoi", Scale=85.0); nta.links.new(co, pores.inputs["Vector"])
pr = nta.nodes.new("ShaderNodeMapRange")                     # small pits where the cell distance is tiny
pr.inputs["From Min"].default_value = 0.0; pr.inputs["From Max"].default_value = 0.14
nta.links.new(pores.outputs["Distance"], pr.inputs["Value"])
pores2 = node(nta, "ShaderNodeTexVoronoi", Scale=190.0); nta.links.new(co, pores2.inputs["Vector"])
pr2 = nta.nodes.new("ShaderNodeMapRange")
pr2.inputs["From Min"].default_value = 0.0; pr2.inputs["From Max"].default_value = 0.12
nta.links.new(pores2.outputs["Distance"], pr2.inputs["Value"])
bg = node(nta, "ShaderNodeBump", Strength=0.45, Distance=0.01); nta.links.new(grain.outputs["Fac"], bg.inputs["Height"])
bpz = node(nta, "ShaderNodeBump", Strength=0.55, Distance=0.006); nta.links.new(pr.outputs["Result"], bpz.inputs["Height"])
bpz2 = node(nta, "ShaderNodeBump", Strength=0.4, Distance=0.004); nta.links.new(pr2.outputs["Result"], bpz2.inputs["Height"])
nta.links.new(bg.outputs["Normal"], bpz.inputs["Normal"]); nta.links.new(bpz.outputs["Normal"], bpz2.inputs["Normal"])
nta.links.new(bpz2.outputs["Normal"], ba.inputs["Normal"])
# roughness breaks the highlights up into glints
rr = nta.nodes.new("ShaderNodeMapRange")
rr.inputs["To Min"].default_value = 0.16; rr.inputs["To Max"].default_value = 0.5
nta.links.new(grain.outputs["Fac"], rr.inputs["Value"]); nta.links.new(rr.outputs["Result"], ba.inputs["Roughness"])

# ---------- turntable root ----------
root = bpy.data.objects.new("turntable", None); sc.collection.objects.link(root)
for tc in TEXCO: tc.object = root

def link(obj):
    sc.collection.objects.link(obj); obj.parent = root; return obj

# ---------- cup wall (truncated cone with UVs) ----------
N, M = 256, 24
U0, U1 = 1 / 6144, 6143 / 6144                  # skip anti-aliased edge columns of the texture
off = -math.pi / 2 - 2 * math.pi * U_LOGO
me = bpy.data.meshes.new("cup_wall"); bm = bmesh.new()
grid = []
for j in range(M + 1):
    v = j / M; z = v * H; r = R_BOT + (R_TOP - R_BOT) * v
    row = []
    for i in range(N + 1):
        th = 2 * math.pi * i / N + off
        row.append(bm.verts.new((r * math.cos(th), r * math.sin(th), z)))
    grid.append(row)
uv = bm.loops.layers.uv.new("UVMap")
for j in range(M):
    for i in range(N):
        f = bm.faces.new((grid[j][i], grid[j][i + 1], grid[j + 1][i + 1], grid[j + 1][i]))
        for lp, (a, c) in zip(f.loops, ((i, j), (i + 1, j), (i + 1, j + 1), (i, j + 1))):
            lp[uv].uv = (U0 + (U1 - U0) * a / N, c / M)
        f.smooth = True
bmesh.ops.remove_doubles(bm, verts=[r[0] for r in grid] + [r[-1] for r in grid], dist=1e-6)
bm.to_mesh(me); bm.free()
wall = link(bpy.data.objects.new("cup_wall", me))
me.materials.append(m_print); me.materials.append(m_paper)
sol = wall.modifiers.new("solid", "SOLIDIFY")
sol.thickness = 0.012; sol.offset = -1; sol.material_offset = 1; sol.material_offset_rim = 1

# bottom
bpy.ops.mesh.primitive_circle_add(vertices=128, radius=R_BOT, fill_type="NGON", location=(0, 0, 0.004))
bot = bpy.context.object; bot.data.materials.append(m_paper); bot.parent = root

# rolled rim
bpy.ops.mesh.primitive_torus_add(major_radius=R_TOP + 0.012, minor_radius=0.032, major_segments=192,
                                 minor_segments=24, location=(0, 0, H + 0.006))
rim = bpy.context.object; rim.data.materials.append(m_paper); rim.parent = root
bpy.ops.object.shade_smooth()

# ---------- açaí ----------
# açaí surface at ~60% of the cup height
bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1, location=(0, 0, H - 0.06))
FILL = 0.60 * H                                  # açaí level inside the cup
r_fill = R_BOT + (R_TOP - R_BOT) * 0.60 - 0.02
mound = bpy.context.object; mound.location.z = FILL + 0.02; mound.scale = (r_fill, r_fill, 0.12)
mound.data.materials.append(m_acai); mound.parent = root; bpy.ops.object.shade_smooth()

# soft-serve swirl piped through a 6-point star nozzle: twisted star tube on a rising spiral
prof = bpy.data.curves.new("star_profile", "CURVE"); prof.dimensions = "2D"
# 5-point star nozzle: straight flanks, slightly rounded tips, soft concave inner corners
R_OUT, R_IN, F_TIP, F_IN = 1.0, 0.64, 0.24, 0.18
verts = []
for k in range(10):
    a = math.pi / 2 + k * math.pi / 5
    rr = R_OUT if k % 2 == 0 else R_IN
    verts.append(Vector((rr * math.cos(a), rr * math.sin(a), 0)))
outline = []
for k, P in enumerate(verts):
    A, B = verts[k - 1], verts[(k + 1) % 10]
    u, v = (A - P).normalized(), (B - P).normalized()
    half = u.angle(v) / 2; rf = F_TIP if k % 2 == 0 else F_IN
    d = rf / math.tan(half); C = P + (u + v).normalized() * (rf / math.sin(half))
    T1, T2 = P + u * d, P + v * d
    a1, a2 = math.atan2((T1 - C).y, (T1 - C).x), math.atan2((T2 - C).y, (T2 - C).x)
    da = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
    for j in range(13):
        a = a1 + da * j / 12
        outline.append(C + Vector((math.cos(a), math.sin(a), 0)) * rf)
    # straight flank to the next corner, densified so the subdivision keeps it straight
    Bn = verts[(k + 1) % 10]; un = (P - Bn).normalized(); vn = (verts[(k + 2) % 10] - Bn).normalized()
    hn = un.angle(vn) / 2; rn = F_TIP if (k + 1) % 2 == 0 else F_IN
    Tn = Bn + un * (rn / math.tan(hn))
    for j in range(1, 6):
        outline.append(T2 + (Tn - T2) * j / 6)
ps = prof.splines.new("POLY"); ps.points.add(len(outline) - 1); ps.use_cyclic_u = True
for pt, q in zip(ps.points, outline):
    pt.co = (q.x, q.y, 0, 1)
star = bpy.data.objects.new("star_profile", prof); sc.collection.objects.link(star)
star.hide_render = True; star.hide_viewport = True

pts = []
TURNS, STEPS = 2.45, 800
for k in range(int(STEPS * 0.9) + 1):          # stop before the coil gets too tight (avoids a knot)
    t = k / STEPS
    ang = 2 * math.pi * TURNS * t + 0.6
    rad = 0.57 * (1 - max(0.0, t - 0.16) / 0.84) ** 0.65   # first ~0.4 turn stays wide: full base ring                 # pyramid: wide base hugging the cup, narrowing up
    z = FILL + 0.12 + 0.88 * max(0.0, t - 0.16) / 0.84 + 0.05 * min(t, 0.16) / 0.16 - 0.25 * max(0.0, 1 - t / 0.05) ** 2
    thick = 0.37 * (1 - max(0.0, t - 0.16) / 0.84) ** 0.75 + 0.065
    tilt = 5.0 * math.pi * (t - 0.5 * t * t)   # twist eases to zero at the top                   # twists the ridges like piped cream
    # hand-piped irregularity: slow, uneven swelling of the bead and a wandering path
    wav = math.sin(t * 23.0 + 0.7) * 0.6 + math.sin(t * 41.0 + 2.1) * 0.4
    thick *= 1 + 0.10 * wav
    rad += 0.035 * math.sin(t * 17.0 + 1.3) * (1 - t)
    z += 0.024 * math.sin(t * 29.0 + 0.4)
    # keep the whole bead (star tips included) inside the cup wall, which narrows towards the bottom
    def wall(zz): return R_BOT + (R_TOP - R_BOT) * min(1.0, max(0.0, zz / H)) - 0.012 - 0.03
    lim = min(wall(z + thick * math.sin(f)) - thick * math.cos(f)
              for f in [math.radians(a) for a in range(-90, 91, 15)] if z + thick * math.sin(f) < H)  \
          if z - thick < H else rad
    if t < 0.08: rad = min(rad, lim)             # only the start that dives into the cup needs it
    pts.append(((rad * math.cos(ang), rad * math.sin(ang), z), thick, tilt))
# soft peak: from the last coil, rises in a gentle arc to the centre and tapers to a point
last = Vector(pts[-1][0]); th0 = pts[-1][1]; tl = pts[-1][2]
top = Vector((0.0, 0.0, last.z + 0.17))
prev_dir = (Vector(pts[-1][0]) - Vector(pts[-6][0])).normalized()
for j in range(1, 11):
    s_ = j / 10
    # quadratic Bézier: last -> (last + forward) -> top
    ctrl = last + prev_dir * 0.12 + Vector((0, 0, 0.05))
    p = (1 - s_) ** 2 * last + 2 * (1 - s_) * s_ * ctrl + s_ ** 2 * top
    pts.append(((p.x, p.y, p.z), th0 * (1 - s_) ** 1.3 + 0.002, tl))
cu = bpy.data.curves.new("swirl", "CURVE"); cu.dimensions = "3D"
cu.bevel_mode = "OBJECT"; cu.bevel_object = star; cu.use_fill_caps = True; cu.resolution_u = 8
cu.twist_mode = "MINIMUM"
sp = cu.splines.new("NURBS"); sp.points.add(len(pts) - 1)
for p, (co, th, tl) in zip(sp.points, pts):
    p.co = (*co, 1); p.radius = th; p.tilt = tl
sp.order_u = 4; sp.use_endpoint_u = True; sp.resolution_u = 8
swirl = link(bpy.data.objects.new("swirl", cu))
cu.materials.append(m_acai)
sp.use_smooth = True
# organic irregularity: soft, low-frequency wobble so the piping is not machine-perfect
bpy.context.view_layer.objects.active = swirl
for o in bpy.context.view_layer.objects: o.select_set(o == swirl)
bpy.ops.object.convert(target="MESH")
swirl = bpy.context.view_layer.objects.active
wob = bpy.data.textures.new("acai_wobble", "CLOUDS"); wob.noise_scale = 0.35; wob.noise_depth = 1
dmod = swirl.modifiers.new("wobble", "DISPLACE"); dmod.texture = wob; dmod.strength = 0.022
dmod.mid_level = 0.5; dmod.texture_coords = "OBJECT"; dmod.texture_coords_object = root
wob2 = bpy.data.textures.new("acai_dents", "CLOUDS"); wob2.noise_scale = 0.12; wob2.noise_depth = 1
d2 = swirl.modifiers.new("dents", "DISPLACE"); d2.texture = wob2; d2.strength = 0.007
d2.mid_level = 0.5; d2.texture_coords = "OBJECT"; d2.texture_coords_object = root
swirl.modifiers.new("soften", "SMOOTH").factor = 0.5

# ---------- turntable animation (linear, seamless) ----------
root.rotation_euler = (0, 0, 0); root.keyframe_insert("rotation_euler", index=2, frame=1)
root.rotation_euler = (0, 0, 2 * math.pi); root.keyframe_insert("rotation_euler", index=2, frame=FRAMES + 1)
for fc in root.animation_data.action.fcurves:
    for kp in fc.keyframe_points: kp.interpolation = "LINEAR"

# ---------- camera ----------
cam_d = bpy.data.cameras.new("cam"); cam_d.lens = 85; cam_d.sensor_fit = "HORIZONTAL"
cam = bpy.data.objects.new("cam", cam_d); sc.collection.objects.link(cam); sc.camera = cam
target = Vector((0, 0, 1.0)); elev = math.radians(13); dist = 11.6
cam.location = target + Vector((0, -dist * math.cos(elev), dist * math.sin(elev)))
cam.rotation_euler = (target - cam.location).to_track_quat("-Z", "Y").to_euler()

# ---------- lights ----------
def area(name, loc, size, energy, color=(1, 1, 1)):
    d = bpy.data.lights.new(name, "AREA"); d.size = size; d.energy = energy; d.color = color
    o = bpy.data.objects.new(name, d); sc.collection.objects.link(o); o.location = loc
    o.rotation_euler = (Vector((0, 0, 1.2)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
key = area("key", (-5.5, -5.0, 5.5), 3.5, 850)
fill = area("fill", (6, -5, 2.0), 7, 70)
rimL = area("rim", (3, 6, 4.5), 2.5, 550, (1, 0.96, 0.98))
top = area("top", (0, -1, 8), 4, 80)

world = bpy.data.worlds.new("w"); sc.world = world; world.use_nodes = True
wn = world.node_tree.nodes; env = wn.new("ShaderNodeTexEnvironment")
env.image = bpy.data.images.load(os.path.join(bpy.utils.system_resource("DATAFILES"), "studiolights/world/studio.exr"))
world.node_tree.links.new(env.outputs["Color"], wn["Background"].inputs["Color"])
wn["Background"].inputs["Strength"].default_value = 0.25


# ---------- render ----------
sc.render.engine = "CYCLES"
prefs = bpy.context.preferences.addons["cycles"].preferences
prefs.compute_device_type = "METAL"; prefs.get_devices()
for d in prefs.devices: d.use = True
sc.cycles.device = "GPU"
sc.cycles.samples = SAMPLES; sc.cycles.use_denoising = True
sc.render.film_transparent = True
sc.render.resolution_x, sc.render.resolution_y = 1920, 1080
sc.render.image_settings.file_format = "PNG"; sc.render.image_settings.color_mode = "RGBA"
sc.view_settings.view_transform = "Standard"
sc.frame_start, sc.frame_end = F0, F1
sc.render.filepath = OUT
if SAVE: bpy.ops.wm.save_as_mainfile(filepath=SAVE)
bpy.ops.render.render(animation=True)
