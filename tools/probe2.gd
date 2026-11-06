extends SceneTree

# Correct size probe: accumulates LOCAL transforms down the scene tree
# (global_transform is unreliable before the first frame in a script run).

func _walk(n: Node, gt: Transform3D, acc: Dictionary) -> void:
	var local: Transform3D = gt
	if n is Node3D:
		local = gt * n.transform
	if n is MeshInstance3D:
		var world: AABB = local * n.get_aabb()
		if acc.count > 0:
			acc.box = acc.box.merge(world)
		else:
			acc.box = world
		acc.count += 1
	for c in n.get_children():
		_walk(c, local, acc)

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
			print("PROBE2 ", f.get_file(), " LOAD_FAIL")
			continue
		var inst := ps.instantiate()
		var acc := {"box": AABB(), "count": 0}
		_walk(inst, Transform3D.IDENTITY, acc)
		var sz: Vector3 = acc.box.size
		var ctr: Vector3 = acc.box.get_center()
		print("PROBE2 %s size=%.2f,%.2f,%.2f center=%.2f,%.2f,%.2f miny=%.2f" % [f.get_file(), sz.x, sz.y, sz.z, ctr.x, ctr.y, ctr.z, acc.box.position.y])
	print("PROBE2 DONE")
	quit()
