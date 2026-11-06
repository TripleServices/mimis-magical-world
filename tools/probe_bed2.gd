extends SceneTree

func _walk(n: Node, gt: Transform3D, depth: int) -> void:
	var local: Transform3D = gt
	if n is Node3D:
		local = gt * n.transform
		var pad := ""
		for i in depth:
			pad += "  "
		print(pad, n.get_class(), " ", n.name, " pos=", n.position, " scale=", n.scale, " rotY=", snapped(n.rotation_degrees.y, 0.1))
		if n is MeshInstance3D:
			var world: AABB = local * n.get_aabb()
			print(pad, "   MESH aabb pos=", world.position, " size=", world.size)
	for c in n.get_children():
		_walk(c, local, depth + 1)

func _init() -> void:
	# Visual ground truth: bed at scale 1 next to a 1m reference cube
	var world := Node3D.new()
	get_root().add_child(world)
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.8, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_energy = 0.4
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	world.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(14, 14)
	floor_mi.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.55, 0.78, 0.45)
	floor_mi.material_override = fm
	world.add_child(floor_mi)

	var ps := load("res://assets/furniture/bedDouble.glb") as PackedScene
	var inst := ps.instantiate()
	world.add_child(inst)
	print("=== bedDouble transforms:")
	_walk(inst, Transform3D.IDENTITY, 0)

	var cube := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE
	cube.mesh = bm
	var cm := StandardMaterial3D.new()
	cm.albedo_color = Color(0.95, 0.3, 0.3)
	cube.material_override = cm
	cube.position = Vector3(1.6, 0.5, 0)
	world.add_child(cube)

	var cam := Camera3D.new()
	cam.position = Vector3(0.5, 2.6, 4.6)
	world.add_child(cam)
	cam.look_at(Vector3(0.5, 0.3, 0), Vector3.UP)
	cam.current = true
	await process_frame
	await process_frame
	await process_frame
	var img := get_root().get_texture().get_image()
	img.save_png("res://tools/shots/probe-bed.png")
	print("PROBE BED2 SAVED")
	quit()
