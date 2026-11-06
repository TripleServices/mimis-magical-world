extends SceneTree
## Screenshot of the start screen (with the new mouse difficulty selector).

var _main: Node
var _t: float = 0.0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if _t >= 1.0:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/shot-start.png"))
		print("START SHOT SAVED")
		return true
	return false
