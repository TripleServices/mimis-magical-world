# Mimi the Kitty en Blender — diseño OFICIAL (PERSONAJE.md + hoja de referencia).
# Gatita blanca, orejas SIEMPRE arriba con interior rosa, ojos grandes oscuros
# con tinte rosa, nariz rosa pequeña, almohadillas rosas, collar rosa con
# dije de corazón dorado grabado "MIMI", cola curvada hacia arriba.
# Medidas estilo Godot (x, alto=Y, frente=Z), convertidas a Blender (Z arriba,
# frente=-Y). Escala del juego: ~1.25 u de alto, origen en los pies.
# Exporta GLB + render de vista previa 3/4.
import bpy
import math
from mathutils import Vector

OUT_DIR = "/home/hatch/workspace/mimis-magical-world/tools/blender/mimi/"
GLB_PATH = OUT_DIR + "mimi-blender.glb"
PREVIEW_PATH = OUT_DIR + "mimi-preview.png"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def mat(name, rgb, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

# Colores en lineal (equivalentes sRGB del diseño oficial)
WHITE = mat("White", (0.88, 0.88, 0.88), 0.85)
PINK = mat("Pink", (1.0, 0.17, 0.40), 0.6)        # collar rosa fuerte
PINK_SOFT = mat("PinkSoft", (1.0, 0.48, 0.67), 0.7)  # interior orejas, mejillas
PINK_TINT = mat("PinkTint", (0.78, 0.07, 0.20), 0.5) # tinte rosa de los ojos
DARK = mat("Dark", (0.015, 0.010, 0.012), 0.4)     # ojos oscuros
GOLD = mat("Gold", (0.85, 0.42, 0.02), 0.35)        # dije dorado
SPARKLE = mat("Sparkle", (1.0, 1.0, 1.0), 0.2)
GREY = mat("Grey", (0.45, 0.45, 0.45), 0.7)        # bigotes

def P(x, y_up, z_fwd):
    return (x, -z_fwd, y_up)

def S(sx, sy_up, sz_fwd):
    return (sx, sz_fwd, sy_up)

def sphere(name, loc, scale, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=16, location=P(*loc))
    o = bpy.context.active_object
    o.name = name
    o.scale = S(*scale)
    o.rotation_euler = rot
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def cone(name, loc, radius, height, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(vertices=24, radius1=radius, radius2=0.0,
                                    depth=height, location=P(*loc))
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(material)
    for p in o.data.polygons:
        p.use_smooth = True
    return o

def cylinder(name, loc, radius, depth, material, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=radius, depth=depth,
                                        location=P(*loc))
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = rot
    o.data.materials.append(material)
    return o

parts = []
# --- patas (4) + almohadillas rosas ---
for sx in (-1, 1):
    for sz in (1, -1):
        parts.append(sphere(f"Leg.{sx}.{sz}", (0.15 * sx, 0.18, 0.16 * sz),
                            (0.085, 0.18, 0.085), WHITE))
        parts.append(sphere(f"Pad.{sx}.{sz}", (0.15 * sx, 0.045, 0.245 * sz),
                            (0.05, 0.03, 0.02), PINK_SOFT))
# --- cuerpo ---
parts.append(sphere("Body", (0, 0.48, 0), (0.31, 0.325, 0.305), WHITE))
# --- cola curvada hacia arriba (esferas decrecientes) ---
for loc, r in [((0, 0.55, -0.30), 0.075), ((0, 0.64, -0.40), 0.068),
               ((0, 0.75, -0.45), 0.060), ((0, 0.85, -0.43), 0.052),
               ((0, 0.92, -0.38), 0.045)]:
    parts.append(sphere("Tail", loc, (r, r, r), WHITE))
# --- cabeza ---
parts.append(sphere("Head", (0, 0.98, 0), (0.335, 0.335, 0.335), WHITE))
# mechón de pelo entre las orejas
parts.append(cone("Tuft.1", (0, 1.30, 0.02), 0.035, 0.09, WHITE, (0.15, 0, 0)))
parts.append(cone("Tuft.2", (0.045, 1.29, 0.0), 0.028, 0.07, WHITE, (0.15, 0, -0.35)))
# --- orejas SIEMPRE arriba + interior rosa ---
for side in (-1, 1):
    parts.append(cone(f"Ear.{side}", (0.185 * side, 1.29, 0), 0.115, 0.26, WHITE,
                      (0, 0, -0.16 * side)))
    parts.append(cone(f"EarInner.{side}", (0.175 * side, 1.27, 0.055), 0.062, 0.17,
                      PINK_SOFT, (0, 0, -0.16 * side)))
# --- ojos grandes oscuros con tinte rosa + brillo ---
for side in (-1, 1):
    parts.append(sphere(f"Iris.{side}", (0.125 * side, 1.02, 0.290),
                        (0.058, 0.072, 0.030), PINK_TINT))
    parts.append(sphere(f"Pupil.{side}", (0.125 * side, 1.02, 0.300),
                        (0.048, 0.060, 0.028), DARK))
    parts.append(sphere(f"Sparkle.{side}", (0.125 * side + 0.018, 1.065, 0.322),
                        (0.016, 0.016, 0.010), SPARKLE))
    # pestañas: 2 piquitos en la esquina exterior de cada ojo
    parts.append(cone(f"Lash1.{side}", (0.185 * side, 1.06, 0.285), 0.008, 0.05,
                      DARK, (0, 0, -0.9 * side)))
    parts.append(cone(f"Lash2.{side}", (0.195 * side, 1.02, 0.285), 0.008, 0.045,
                      DARK, (0, 0, -1.3 * side)))
# --- nariz rosa pequeña + mejillas ---
parts.append(sphere("Nose", (0, 0.935, 0.325), (0.034, 0.023, 0.018), PINK))
for side in (-1, 1):
    parts.append(sphere(f"Cheek.{side}", (0.215 * side, 0.905, 0.255),
                        (0.052, 0.042, 0.018), PINK_SOFT))
# --- bigotes (gris claro, 3 por lado) ---
for side in (-1, 1):
    for i, (dy, dz, tilt) in enumerate([(0.03, 0.0, 0.15), (0.0, 0.0, 0.0), (-0.03, 0.0, -0.15)]):
        parts.append(cylinder(f"Whisker.{side}.{i}", (0.29 * side, 0.95 + dy, 0.28),
                              0.0025, 0.12, GREY, (0, math.pi / 2 - tilt * side, 0)))
# --- collar rosa (toro horizontal sobre los hombros) ---
# A y 0.80 el anillo quedaba enterrado entre cabeza y cuerpo; a 0.72 con
# radio mayor 0.24 asoma por fuera de ambos, como en la hoja de referencia.
bpy.ops.mesh.primitive_torus_add(major_radius=0.24, minor_radius=0.035,
                                 major_segments=32, minor_segments=12,
                                 location=P(0, 0.72, 0))
collar = bpy.context.active_object
collar.name = "Collar"
collar.rotation_euler = (math.pi / 2, 0, 0)
collar.data.materials.append(PINK)
parts.append(collar)
# --- dije corazón dorado (colgando del frente del collar) ---
parts.append(sphere("Heart.L", (-0.032, 0.66, 0.245), (0.036, 0.036, 0.02), GOLD))
parts.append(sphere("Heart.R", (0.032, 0.66, 0.245), (0.036, 0.036, 0.02), GOLD))
parts.append(cone("Heart.Tip", (0, 0.625, 0.245), 0.048, 0.07, GOLD, (math.pi, 0, 0)))
# --- texto "MIMI" grabado en el dije ---
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
parts.append(txt)

# --- unir todo en un solo objeto "Mimi" ---
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
mimi = bpy.context.active_object
mimi.name = "Mimi"
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
mimi.location = (0, 0, 0)

bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_yup=True)
print("GLB exportado:", GLB_PATH)

# --- vista previa 3/4: cámara + luces + Cycles CPU ---
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

# --- segundo render: primer plano del collar y el dije "MIMI" ---
cam.location = (0.0, -0.55, 0.75)
direction = Vector((0, 0, 0.66)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Z").to_euler()
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.filepath = OUT_DIR + "mimi-collar-closeup.png"
bpy.ops.render.render(write_still=True)
print("Closeup renderizado:", OUT_DIR + "mimi-collar-closeup.png")
print("DONE")
