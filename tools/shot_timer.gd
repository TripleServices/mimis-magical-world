extends SceneTree
## One screenshot right after Play! so the HUD shows the 0:40 mission timer.

var _main: Node
var _t: float = 0.0
var _done: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if not _done and _t >= 0.25:
		_main._on_play_pressed()
		_done = true
	elif _done and _t >= 0.9:
		var img := root.get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/shot-timer.png"))
		print("TIMER SHOT SAVED")
		return true
	return false
