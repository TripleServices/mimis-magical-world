extends SceneTree
## Captures the School (level 2) and the Gym (level 3) for a visual check.

var _main: Node
var _frames: int = 0
var _shot_dir: String

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_shot_dir = ProjectSettings.globalize_path("res://tools/shots")

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_shot_dir + "/" + name)
	print("SHOT saved ", name)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		_main._on_play_pressed()
		_main.mouse_active = false
	if _frames == 14:
		_main.level = 2
		_main._reset_game()
	if _frames == 80:
		_shot("shot-school.png")
	if _frames == 90:
		_main.level = 3
		_main._reset_game()
	if _frames == 160:
		_shot("shot-gym.png")
		print("WORLDS SHOTS DONE")
		return true
	return false
