extends SceneTree

func _walk(n: Node, gt: Transform3D, depth: int) -> void:
	var local: Transform3D = gt * (n as Node3D).transform if n is Node3D else gt
	var pad := ""
	for i in depth:
		pad += "  "
	if n is MeshInstance3D:
		var world: AABB = local * n.get_aabb()
		print(pad, "MESH ", n.name, " surfaces=", n.mesh.get_surface_count(), " aabb pos=", world.position, " size=", world.size)
	elif n is Node3D:
		print(pad, "NODE ", n.name, " pos=", n.position, " scale=", n.scale, " rot=", n.rotation_degrees)
	for c in n.get_children():
		_walk(c, local, depth + 1)

func _init() -> void:
	for path in ["res://assets/furniture/bedDouble.glb", "res://assets/furniture/loungeSofa.glb"]:
		print("=== ", path)
		var ps := load(path) as PackedScene
		var inst := ps.instantiate()
		_walk(inst, Transform3D.IDENTITY, 0)
	print("PROBE BED DONE")
	quit()
