extends SceneTree
## Collision map of the gym (level 3): scans a 1 m grid with a sphere at
## Mimi's body height (y 0.6) and head height (y 1.0), reporting only
## StaticBody3D hits — any blocked cell that is not a known visible obstacle
## is an invisible wall.

var _main: Node
var _frames: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _scan(y: float) -> void:
	var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
	var shape := SphereShape3D.new()
	shape.radius = 0.35
	print("--- gym collision map at y=", y, " (x -19..19 left→right, z -5..15 top→bottom)")
	for gz in range(-5, 16):
		var row := ""
		for gx in range(-19, 20):
			var params := PhysicsShapeQueryParameters3D.new()
			params.shape = shape
			params.transform = Transform3D(Basis(), Vector3(gx, y, gz))
			params.collision_mask = 1
			var hits := space.intersect_shape(params, 6)
			var blocked := false
			for h in hits:
				if h.collider is StaticBody3D:
					blocked = true
			row += "#" if blocked else "."
		print(row)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_main._on_play_pressed()
		_main.mouse_active = false
	if _frames == 10:
		_main.level = 3
		_main._reset_game()
	if _frames == 16:
		_scan(0.6)
		_scan(1.0)
		print("DIAG DONE")
		return true
	return false
