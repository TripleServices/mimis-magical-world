extends SceneTree

# Close-up inspection shots: park Mimi near each new model and let the
# game's own follow camera frame the scene.

var _main: Node
var _frames: int = 0
var _shot_dir: String

const VIEWS := [
	["cu-bed", Vector3(-14.2, 0.1, -1.4)],
	["cu-kitchen", Vector3(11.0, 0.1, -1.0)],
	["cu-sofa", Vector3(-3.4, 0.1, -0.7)],
	["cu-oak", Vector3(-4.2, 0.1, 14.8)],
	["cu-lulu", Vector3(-5.9, 0.1, 11.2)],
	["cu-desk", Vector3(-11.8, 0.1, -1.0)],
	["cu-garden-wide", Vector3(0.0, 0.1, 13.8)],
]

func _initialize() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://tools/shots")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 4:
		_main._on_play_pressed()
	if _frames >= 8:
		var step := (_frames - 8) / 22
		var phase := (_frames - 8) % 22
		if step < VIEWS.size():
			if phase == 0:
				_main.mimi.velocity = Vector3.ZERO
				_main.mimi.global_position = VIEWS[step][1]
			if phase == 20:
				var img := root.get_texture().get_image()
				img.save_png(_shot_dir + "/" + VIEWS[step][0] + ".png")
				print("CU SAVED ", VIEWS[step][0])
		else:
			return true
	return false
