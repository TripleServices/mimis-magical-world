extends SceneTree

# Loads every downloaded Kenney GLB, reports its AABB size and texture use.

func _count_textured(mi: MeshInstance3D) -> bool:
	var mesh := mi.mesh
	if mesh == null:
		return false
	for s in mesh.get_surface_count():
		var m := mesh.surface_get_material(s)
		if m is StandardMaterial3D and m.albedo_texture != null:
			return true
	return false

func _walk(n: Node, acc: Dictionary) -> void:
	if n is MeshInstance3D:
		var aabb: AABB = n.get_aabb()
		var gt: Transform3D = n.global_transform
		var world: AABB = gt * aabb
		if acc.count == 0:
			acc.box = world
		else:
			acc.box = acc.box.merge(world)
		acc.count += 1
		if _count_textured(n):
			acc.textured = true
	for c in n.get_children():
		_walk(c, acc)

func _init() -> void:
	var files: Array[String] = []
	for dir in ["res://assets/nature", "res://assets/furniture"]:
		var d := DirAccess.open(dir)
		d.list_dir_begin()
		var fn := d.get_next()
		while fn != "":
			if fn.ends_with(".glb"):
				files.append(dir + "/" + fn)
			fn = d.get_next()
		d.list_dir_end()
	files.sort()
	for f in files:
		var ps := load(f) as PackedScene
		if ps == null:
			print("PROBE ", f.get_file(), " LOAD_FAIL")
			continue
		var inst := ps.instantiate()
		var root := Node3D.new()
		root.add_child(inst)
		get_root().add_child(root)
		var acc := {"box": AABB(), "count": 0, "textured": false}
		_walk(inst, acc)
		var sz: Vector3 = acc.box.size
		print("PROBE %s size=%.2f,%.2f,%.2f meshes=%d textured=%s" % [f.get_file(), sz.x, sz.y, sz.z, acc.count, str(acc.textured)])
		root.queue_free()
	print("PROBE DONE")
	quit()
