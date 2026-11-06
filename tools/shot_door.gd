extends SceneTree
## Screenshot: Mimi in the living room looking toward the kitchen doorway
## (wide open, door panel flat against the wall).

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
		_main._on_play_pressed()
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = Vector3(4.6, 0.1, 0.2)
		_main.mimi.rotation.y = -PI / 2.0
		_main.cam_yaw = -PI / 2.0 + 0.25
	if _t >= 1.1:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/shot-door.png"))
		print("DOOR SHOT SAVED")
		return true
	return false
