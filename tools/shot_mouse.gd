extends SceneTree
## Screenshot: Mimi meets the Mouse in the garden, Coco watching from his doghouse.

var _main: Node
var _t: float = 0.0
var _started: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if not _started and _t >= 0.25:
		_main._on_play_pressed()
		_main.mouse_active = false  # freeze the mouse for the photo
		_main.mimi.global_position = Vector3(6.2, 0.1, 10.4)
		_main.mice[0].body.global_position = Vector3(5.1, 0.1, 9.7)
		_main.mice[0].body.rotation.y = 2.6  # face Mimi / the camera
		_started = true
	elif _started and _t >= 1.2:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/shot-mouse.png"))
		print("MOUSE SHOT SAVED")
		return true
	return false
