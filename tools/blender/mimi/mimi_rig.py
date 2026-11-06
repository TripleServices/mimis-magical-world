# Mimi the Kitty RIGGEADA para el juego (Godot 4.3).
# Igual que mimi_ejemplo.py (mismo diseño oficial, mismas medidas) pero SIN unir:
# cada parte queda como objeto propio bajo pivotes (Empty) llamados LegFL,
# LegFR, LegBL, LegBR, Tail y Head, para que mimi.gd los gire al caminar,
# menee la cola y mueva la cabeza, igual que hacía con el modelo procedural.
# Exporta mimi-blender.glb + preview estática + preview en pose de caminata.
import bpy
import math
from mathutils import Vector

OUT_DIR = "/home/hatch/workspace/mimis-magical-world/tools/blender/mimi/"
GLB_PATH = OUT_DIR + "mimi-blender.glb"
PREVIEW_PATH = OUT_DIR + "mimi-preview.png"
POSE_PATH = OUT_DIR + "mimi-pose-caminata.png"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def mat(name, rgb, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

WHITE = mat("White", (0.88, 0.88, 0.88), 0.85)
PINK = mat("Pink", (1.0, 0.17, 0.40), 0.6)
PINK_SOFT = mat("PinkSoft", (1.0, 0.48, 0.67), 0.7)
PINK_TINT = mat("PinkTint", (0.78, 0.07, 0.20), 0.5)
DARK = mat("Dark", (0.015, 0.010, 0.012), 0.4)
GOLD = mat("Gold", (0.85, 0.42, 0.02), 0.35)
SPARKLE = mat("Sparkle", (1.0, 1.0, 1.0), 0.2)
GREY = mat("Grey", (0.45, 0.45, 0.45), 0.7)

def P(x, y_up, z_fwd):
    """Godot (x, alto=Y, frente=Z) -> Blender (x, -Z, Y). Lineal: P(a-b)=P(a)-P(b)."""
    return (x, -z_fwd, y_up)

def S(sx, sy_up, sz_fwd):
    return (sx, sz_fwd, sy_up)

PIVOTS = {}  # nombre -> (empty, loc_godot)

def make_pivot(name, godot_loc):
    bpy.ops.object.empty_add(type="PLAIN_AXES", location=P(*godot_loc))
    e = bpy.context.active_object
    e.name = name
    PIVOTS[name] = (e, godot_loc)
    return e

def _place(obj, godot_loc, pivot_name):
    """Ubica el objeto en coords locales de su pivote (pivote sin rotación)."""
    px, py, pz = PIVOTS[pivot_name][1]
    gx, gy, gz = godot_loc
    obj.location = P(gx - px, gy - py, gz - pz)
    obj.parent = PIVOTS[pivot_name][0]

def sphere(name, loc, scale, material, pivot, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    o.scale = S(*scale)
    o.rotation_euler = rot
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    _place(o, loc, pivot)
    return o

def cone(name, loc, radius, height, material, pivot, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius, radius2=0.0,
                                    depth=height, location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    _place(o, loc, pivot)
    return o

def cylinder(name, loc, radius, depth, material, pivot, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth,
                                        location=(0, 0, 0))
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(material)
    _place(o, loc, pivot)
    return o

# --- pivotes (mismas posiciones que mimi.gd) ---
make_pivot("Mimi", (0, 0, 0))          # raíz
make_pivot("LegFL", (-0.15, 0.30, 0.16))
make_pivot("LegFR", (0.15, 0.30, 0.16))
make_pivot("LegBL", (-0.15, 0.30, -0.16))
make_pivot("LegBR", (0.15, 0.30, -0.16))
make_pivot("Tail", (0, 0.52, -0.27))
make_pivot("Head", (0, 0.82, 0))
for p in ("LegFL", "LegFR", "LegBL", "LegBR", "Tail", "Head"):
    PIVOTS[p][0].parent = PIVOTS["Mimi"][0]

# --- patas + almohadillas rosas ---
for side_x, side_z, tag in ((-1, 1, "FL"), (1, 1, "FR"), (-1, -1, "BL"), (1, -1, "BR")):
    sphere(f"Leg{tag}Mesh", (0.15 * side_x, 0.18, 0.16 * side_z),
           (0.085, 0.18, 0.085), WHITE, f"Leg{tag}")
    sphere(f"Pad{tag}", (0.15 * side_x, 0.045, 0.245 * side_z),
           (0.05, 0.03, 0.02), PINK_SOFT, f"Leg{tag}")
# --- cuerpo ---
sphere("Body", (0, 0.48, 0), (0.31, 0.325, 0.305), WHITE, "Mimi")
# --- cola curvada hacia arriba ---
for i, (loc, r) in enumerate([((0, 0.55, -0.30), 0.075), ((0, 0.64, -0.40), 0.068),
                              ((0, 0.75, -0.45), 0.060), ((0, 0.85, -0.43), 0.052),
                              ((0, 0.92, -0.38), 0.045)]):
    sphere(f"TailSeg{i+1}", loc, (r, r, r), WHITE, "Tail")
# --- cabeza ---
sphere("HeadMesh", (0, 0.98, 0), (0.335, 0.335, 0.335), WHITE, "Head")
cone("Tuft1", (0, 1.30, 0.02), 0.035, 0.09, WHITE, "Head", (0.15, 0, 0))
cone("Tuft2", (0.045, 1.29, 0.0), 0.028, 0.07, WHITE, "Head", (0.15, 0, -0.35))
for side in (-1, 1):
    cone(f"Ear{side}", (0.185 * side, 1.29, 0), 0.115, 0.26, WHITE, "Head",
         (0, 0, -0.16 * side))
    cone(f"EarInner{side}", (0.175 * side, 1.27, 0.055), 0.062, 0.17, PINK_SOFT,
         "Head", (0, 0, -0.16 * side))
for side in (-1, 1):
    sphere(f"Iris{side}", (0.125 * side, 1.02, 0.290), (0.058, 0.072, 0.030),
           PINK_TINT, "Head")
    sphere(f"Pupil{side}", (0.125 * side, 1.02, 0.300), (0.048, 0.060, 0.028),
           DARK, "Head")
    sphere(f"Sparkle{side}", (0.125 * side + 0.018, 1.065, 0.322),
           (0.016, 0.016, 0.010), SPARKLE, "Head")
    cone(f"Lash1_{side}", (0.185 * side, 1.06, 0.285), 0.008, 0.05, DARK, "Head",
         (0, 0, -0.9 * side))
    cone(f"Lash2_{side}", (0.195 * side, 1.02, 0.285), 0.008, 0.045, DARK, "Head",
         (0, 0, -1.3 * side))
sphere("Nose", (0, 0.935, 0.325), (0.034, 0.023, 0.018), PINK, "Head")
for side in (-1, 1):
    sphere(f"Cheek{side}", (0.215 * side, 0.905, 0.255), (0.052, 0.042, 0.018),
           PINK_SOFT, "Head")
for side in (-1, 1):
    for i, (dy, tilt) in enumerate([(0.03, 0.15), (0.0, 0.0), (-0.03, -0.15)]):
        cylinder(f"Whisker{side}_{i}", (0.30 * side, 0.95 + dy, 0.28),
                 0.0025, 0.12, GREY, "Head", (0, math.pi / 2 - tilt * side, 0))
# --- collar rosa + dije corazón dorado "MIMI" ---
bpy.ops.mesh.primitive_torus_add(major_radius=0.24, minor_radius=0.035,
                                 major_segments=32, minor_segments=12, location=(0, 0, 0))
collar = bpy.context.active_object
collar.name = "Collar"
collar.rotation_euler = (math.pi / 2, 0, 0)
collar.data.materials.append(PINK)
_place(collar, (0, 0.72, 0), "Mimi")
sphere("HeartL", (-0.032, 0.66, 0.245), (0.036, 0.036, 0.02), GOLD, "Mimi")
sphere("HeartR", (0.032, 0.66, 0.245), (0.036, 0.036, 0.02), GOLD, "Mimi")
cone("HeartTip", (0, 0.625, 0.245), 0.048, 0.07, GOLD, "Mimi", (math.pi, 0, 0))
bpy.ops.object.text_add(location=(0, -0.27, 0.66))
txt = bpy.context.active_object
txt.name = "MIMI"
txt.data.body = "MIMI"
txt.data.size = 0.024
txt.data.extrude = 0.004
txt.data.align_x = "CENTER"
txt.data.align_y = "CENTER"
txt.rotation_euler = (math.pi / 2, 0, 0)
txt.data.materials.append(GOLD)
txt.parent = PIVOTS["Mimi"][0]

bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_yup=True)
print("GLB exportado:", GLB_PATH)

# --- renders: cámara + luces + Cycles CPU ---
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.render.resolution_x = 640
scene.render.resolution_y = 640
scene.render.filepath = PREVIEW_PATH
scene.render.film_transparent = False
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.93, 0.95, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

bpy.ops.object.camera_add(location=(0.45, -2.3, 1.05))
cam = bpy.context.active_object
cam.name = "Camera"
scene.camera = cam
direction = Vector((0, 0, 0.62)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Z").to_euler()

bpy.ops.object.light_add(type="SUN", location=(1, -1, 2))
sun = bpy.context.active_object
sun.data.energy = 1.6
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
bpy.ops.object.light_add(type="AREA", location=(-0.8, -0.6, 0.9))
fill = bpy.context.active_object
fill.data.energy = 50
fill.data.shape = "DISK"
fill.data.size = 1.0

bpy.ops.render.render(write_still=True)
print("Preview renderizado:", PREVIEW_PATH)

# --- pose de caminata: patas en vaivén, cola meneada, cabeza ladeada ---
# (giros en coords Blender: balanceo de pata = eje X; meneo de cola = eje Z;
#  ladeo de cabeza = eje Y)
PIVOTS["LegFL"][0].rotation_euler = (0.55, 0, 0)
PIVOTS["LegBR"][0].rotation_euler = (0.55, 0, 0)
PIVOTS["LegFR"][0].rotation_euler = (-0.55, 0, 0)
PIVOTS["LegBL"][0].rotation_euler = (-0.55, 0, 0)
PIVOTS["Tail"][0].rotation_euler = (0, 0, 0.35)
PIVOTS["Head"][0].rotation_euler = (0, 0.06, 0)
scene.render.filepath = POSE_PATH
bpy.ops.render.render(write_still=True)
print("Pose renderizada:", POSE_PATH)

# --- misma pose, vista de LADO (el balanceo va en profundidad desde el frente) ---
cam.location = (2.3, -0.35, 0.62)
direction = Vector((0, 0, 0.55)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Z").to_euler()
scene.render.filepath = OUT_DIR + "mimi-pose-lado.png"
bpy.ops.render.render(write_still=True)
print("Pose de lado renderizada:", OUT_DIR + "mimi-pose-lado.png")
print("DONE")
