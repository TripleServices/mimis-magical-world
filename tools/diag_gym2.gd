extends SceneTree
## Names the actual blocking colliders at suspicious gym spots: prints each
## hit collider's scene path and its root's collision layer state.

var _main: Node
var _frames: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _probe(label: String, pos: Vector3) -> void:
	var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = pos
	params.collision_mask = 0xFFFFFFFF
	var hits := space.intersect_point(params, 8)
	print("PROBE ", label, " at ", pos, ":")
	if hits.is_empty():
		print("   (nothing)")
	for h in hits:
		var c: Object = h.collider
		if c is Node:
			print("   ", (c as Node).get_path(), " layer=", (c as CollisionObject3D).collision_layer if c is CollisionObject3D else "?")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_main._on_play_pressed()
		_main.mouse_active = false
	if _frames == 10:
		_main.level = 3
		_main._reset_game()
	if _frames == 16:
		print("world_roots: ", _main.world_roots)
		for i in _main.world_roots.size():
			var r: Node = _main.world_roots[i]
			print("root ", i, " name=", r.name, " visible=", (r as Node3D).visible, " children=", r.get_child_count())
		_probe("school desk spot", Vector3(-13.5, 0.6, -2.6))
		_probe("school bus spot", Vector3(10.5, 0.9, 14.1))
		_probe("school slide spot", Vector3(14.2, 0.6, 9.2))
		_probe("gym bleacher (control)", Vector3(-6, 0.6, -4.75))
		_probe("open court (control)", Vector3(0, 0.6, -2))
		print("DIAG2 DONE")
		return true
	return false
