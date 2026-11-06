# Osito Teddy de ejemplo para Mimi's Magical World (Godot 4.3).
# Hecho 100% en Blender por script: primitivas + materiales, origen en la base
# (pies en y=0) y ~0.45 unidades de alto, igual que el teddy actual del juego
# (que hoy son esferas sueltas en código). Exporta GLB + render de vista previa.
import bpy
import math
from mathutils import Vector

OUT_DIR = "/home/hatch/workspace/mimis-magical-world/tools/blender/teddy/"
GLB_PATH = OUT_DIR + "teddy-blender.glb"
PREVIEW_PATH = OUT_DIR + "teddy-preview.png"

# --- limpiar escena ---
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for coll in (bpy.data.meshes, bpy.data.curves, bpy.data.cameras, bpy.data.lights):
    pass

# --- materiales (colores vivos estilo juego, niños 3-6) ---
def mat(name, rgb, rough=0.6):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m

# Blender trabaja en lineal: estos valores equivalen al marrón/tan/rosa del juego
BROWN = mat("Brown", (0.28, 0.12, 0.05))
TAN = mat("Tan", (0.72, 0.52, 0.32))
DARK = mat("Dark", (0.01, 0.01, 0.01))
PINK = mat("Pink", (0.85, 0.22, 0.30))

# --- helpers ---
# Las medidas se escriben estilo Godot (x, alto=Y, frente=Z) y se convierten
# a Blender (Z arriba, frente=-Y): (x, y, z) -> (x, -z, y).
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

parts = []
# piernas
parts.append(sphere("Leg.L", (-0.07, 0.06, 0.02), (0.09, 0.07, 0.11), BROWN))
parts.append(sphere("Leg.R", (0.07, 0.06, 0.02), (0.09, 0.07, 0.11), BROWN))
# cuerpo + pancita
parts.append(sphere("Body", (0, 0.20, 0), (0.16, 0.18, 0.13), BROWN))
parts.append(sphere("Belly", (0, 0.18, 0.09), (0.11, 0.13, 0.06), TAN))
# brazos (levantados, saludando): giro en Y de Blender = inclinación lateral
parts.append(sphere("Arm.L", (-0.17, 0.24, 0.02), (0.06, 0.10, 0.06), BROWN, (0, 0.5, 0)))
parts.append(sphere("Arm.R", (0.17, 0.24, 0.02), (0.06, 0.10, 0.06), BROWN, (0, -0.5, 0)))
# cabeza
parts.append(sphere("Head", (0, 0.42, 0), (0.13, 0.13, 0.13), BROWN))
# orejas + interior rosa
parts.append(sphere("Ear.L", (-0.10, 0.52, 0), (0.055, 0.055, 0.04), BROWN))
parts.append(sphere("Ear.R", (0.10, 0.52, 0), (0.055, 0.055, 0.04), BROWN))
parts.append(sphere("EarInner.L", (-0.10, 0.52, 0.03), (0.032, 0.032, 0.02), PINK))
parts.append(sphere("EarInner.R", (0.10, 0.52, 0.03), (0.032, 0.032, 0.02), PINK))
# hocico + nariz + ojos (frente = +Z estilo Godot -> -Y de Blender, hacia la cámara)
parts.append(sphere("Snout", (0, 0.39, 0.11), (0.07, 0.05, 0.05), TAN))
parts.append(sphere("Nose", (0, 0.41, 0.16), (0.03, 0.02, 0.02), DARK))
parts.append(sphere("Eye.L", (-0.05, 0.45, 0.11), (0.018, 0.018, 0.018), DARK))
parts.append(sphere("Eye.R", (0.05, 0.45, 0.11), (0.018, 0.018, 0.018), DARK))
# moño rosa en el cuello
parts.append(sphere("Bow.L", (-0.045, 0.315, 0.13), (0.04, 0.03, 0.02), PINK, (0, 0.4, 0)))
parts.append(sphere("Bow.R", (0.045, 0.315, 0.13), (0.04, 0.03, 0.02), PINK, (0, -0.4, 0)))
parts.append(sphere("Bow.Knot", (0, 0.315, 0.14), (0.02, 0.02, 0.02), PINK))

# --- unir todo en un solo objeto "Teddy" ---
bpy.ops.object.select_all(action="DESELECT")
for p in parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
teddy = bpy.context.active_object
teddy.name = "Teddy"
# origen en la base (0,0,0): los pies ya tocan y=0
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
teddy.location = (0, 0, 0)

# --- exportar GLB ---
bpy.ops.export_scene.gltf(filepath=GLB_PATH, export_format="GLB", export_yup=True)
print("GLB exportado:", GLB_PATH)

# --- vista previa: cámara + luces + Cycles CPU ---
scene = bpy.context.scene
scene.render.engine = "CYCLES"
scene.cycles.device = "CPU"
scene.cycles.samples = 64
scene.render.resolution_x = 512
scene.render.resolution_y = 512
scene.render.filepath = PREVIEW_PATH
scene.render.film_transparent = False
world = bpy.data.worlds.new("World")
scene.world = world
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (1.0, 0.93, 0.95, 1.0)
world.node_tree.nodes["Background"].inputs[1].default_value = 0.6

bpy.ops.object.camera_add(location=(0.0, -1.6, 0.55))
cam = bpy.context.active_object
cam.name = "Camera"
scene.camera = cam
# apuntar cámara al centro del osito (coords Blender: Z arriba)
direction = Vector((0, 0, 0.28)) - cam.location
cam.rotation_euler = direction.to_track_quat("-Z", "Z").to_euler()

bpy.ops.object.light_add(type="SUN", location=(1, -1, 2))
sun = bpy.context.active_object
sun.data.energy = 1.6
sun.rotation_euler = (math.radians(50), 0, math.radians(30))
bpy.ops.object.light_add(type="AREA", location=(-0.8, -0.6, 0.8))
fill = bpy.context.active_object
fill.data.energy = 50
fill.data.shape = "DISK"
fill.data.size = 1.0

bpy.ops.render.render(write_still=True)
print("Preview renderizado:", PREVIEW_PATH)
print("DONE")
