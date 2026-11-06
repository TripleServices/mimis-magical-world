extends SceneTree
## Diagnostic: raycast east across the x=8 divider at several z lanes to map
## where the doorway is really open, and what blocks z=0.2.

var _main: Node
var _t: float = 0.0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if _t >= 0.5:
		var space = _main.get_world_3d().direct_space_state
		for z in [-1.4, -0.8, -0.2, 0.2, 0.4, 1.0, 1.6, 2.2]:
			var q := PhysicsRayQueryParameters3D.new()
			q.from = Vector3(5.0, 1.0, z)
			q.to = Vector3(13.0, 1.0, z)
			var hit = space.intersect_ray(q)
			if hit.is_empty():
				print("LANE z=", z, " CLEAR")
			else:
				print("LANE z=", z, " HIT at x=", (hit.position as Vector3).x, " collider=", hit.collider)
		return true
	return false
