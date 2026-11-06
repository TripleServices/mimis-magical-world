extends SceneTree

# Lays the candidate Kenney models in a grid and screenshots them,
# so I can check colors, facing direction and looks before integrating.

const MODELS: Array[String] = [
	"nature/tree_oak", "nature/tree_default", "nature/tree_detailed", "nature/tree_fat",
	"nature/tree_pineRoundA", "nature/tree_cone", "nature/plant_bushDetailed", "nature/plant_bush",
	"nature/flower_redA", "nature/grass", "nature/rock_largeB", "nature/mushroom_redGroup",
	"furniture/loungeSofa", "furniture/loungeChair", "furniture/tableCoffee", "furniture/televisionModern",
	"furniture/bookcaseOpen", "furniture/pottedPlant", "furniture/lampRoundFloor", "furniture/kitchenCabinet",
	"furniture/kitchenFridge", "furniture/kitchenStove", "furniture/kitchenSink", "furniture/tableRound",
	"furniture/chairRounded", "furniture/bedDouble", "furniture/desk", "furniture/pillow",
]

func _aabb_of(n: Node, gt: Transform3D, acc: Dictionary) -> void:
	var local: Transform3D = gt * (n as Node3D).transform if n is Node3D else gt
	if n is MeshInstance3D:
		var world: AABB = local * n.get_aabb()
		acc.box = world if acc.count > 0 else world
		if acc.count > 0:
			acc.box = acc.box.merge(world)
		acc.count += 1
	for c in n.get_children():
		_aabb_of(c, local, acc)

func _init() -> void:
	var world := Node3D.new()
	get_root().add_child(world)

	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.60, 0.81, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.96, 1.0)
	env.ambient_light_energy = 0.25
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 1.05
	sun.shadow_enabled = true
	world.add_child(sun)

	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 20)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.78, 0.45)
	floor_mi.material_override = fm
	world.add_child(floor_mi)

	var cols := 7
	var spacing := 1.7
	for i in MODELS.size():
		var path := "res://assets/" + MODELS[i] + ".glb"
		var ps := load(path) as PackedScene
		if ps == null:
			print("PARADE MISSING ", path)
			continue
		var inst := ps.instantiate() as Node3D
		var acc := {"box": AABB(), "count": 0}
		_aabb_of(inst, Transform3D.IDENTITY, acc)
		var h: float = max(acc.box.size.y, 0.05)
		var s: float = 1.05 / h
		inst.scale = Vector3.ONE * s
		var col := i % cols
		var row := i / cols
		inst.position = Vector3((float(col) - float(cols - 1) / 2.0) * spacing, -acc.box.position.y * s, (float(row) - 1.5) * spacing)
		world.add_child(inst)
		print("PARADE cell ", i, " = ", MODELS[i])

	var cam := Camera3D.new()
	cam.position = Vector3(0, 6.4, 8.6)
	world.add_child(cam)
	cam.look_at(Vector3(0, 0.2, -0.4), Vector3.UP)
	cam.current = true

	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://tools/shots/parade.png")
	print("PARADE SAVED")
	quit()
