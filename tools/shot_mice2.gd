extends SceneTree
## Screenshot: both mice near Mimi in the garden (Impossible mode).

var _main: Node
var _t: float = 0.0
var _placed: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if not _placed and _t >= 0.3:
		_placed = true
		_main.difficulty = 3  # Impossible: both mice play
		_main._on_play_pressed()
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = Vector3(0.5, 0.1, 10.6)
		_main.mimi.rotation.y = 2.6
		_main.cam_yaw = 0.5
		_main.mice[0].body.global_position = Vector3(1.6, 0.1, 9.6)
		_main.mice[0].body.rotation.y = -2.2
		_main.mice[1].body.global_position = Vector3(-0.7, 0.1, 9.4)
		_main.mice[1].body.rotation.y = 2.9
	if _t >= 1.2:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/shot-mice2.png"))
		print("MICE2 SHOT SAVED")
		return true
	return false
