extends SceneTree
## End-to-end smoke test v2: visits kitchen, bedroom and garden for screenshots,
## then teleports Mimi onto each toy and verifies the mission completes.

var _main: Node
var _frames: int = 0
var _toy_idx: int = 0
var _shot_dir: String
var _win_seen: bool = false
var _max_collected: int = 0
var _reached_lvl2: bool = false

func _initialize() -> void:
	_shot_dir = ProjectSettings.globalize_path("res://tools/shots")
	DirAccess.make_dir_recursive_absolute(_shot_dir)
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_shot_dir + "/" + name)

func _teleport(pos: Vector3) -> void:
	_main.mimi.velocity = Vector3.ZERO
	_main.mimi.global_position = pos

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_main.difficulty = 3  # Impossible: all 15 toys active, so the sweep covers every toy
		_main._on_play_pressed()
		_main.time_left = 9999.0  # smoke test: keep the mission timer from cutting the run
		_main.mouse_active = false  # and park the mouse so he can't steal mid-test
	if _frames == 20:
		_shot("shot-living.png")
	if _frames == 24:
		_teleport(Vector3(12.5, 0.1, 1.0))
	if _frames == 44:
		_shot("shot-kitchen.png")
	if _frames == 48:
		_teleport(Vector3(-13.5, 0.1, 1.2))
	if _frames == 68:
		_shot("shot-bedroom.png")
	if _frames == 72:
		_teleport(Vector3(0.5, 0.1, 9.5))
	if _frames == 92:
		_shot("shot-garden.png")
	if _frames >= 110 and _toy_idx < _main.toys.size() and (_frames - 110) % 22 == 0:
		var toy: Dictionary = _main.toys[_toy_idx]
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = (toy.root as Node3D).global_position + Vector3(0, 0.05, 0)
		print("Teleported to toy ", _toy_idx, " at ", (toy.root as Node3D).global_position)
		_toy_idx += 1
	# The win panel celebrates ~3.5 s, then the game returns to the menu by
	# itself — record that it appeared instead of expecting it at the end.
	_max_collected = maxi(_max_collected, _main.collected)
	if _main.win_panel.visible and not _win_seen:
		_win_seen = true
		_shot("shot-win.png")
	# Winning level 1 now advances to level 2 instead of going to the menu
	if _win_seen and _main.level == 2:
		_reached_lvl2 = true
	# The win celebration runs on a real-time 3.5 s timer; headless frames
	# are not wall-clock, so wait until the advance actually lands (with a
	# generous frame cap) instead of assuming a fixed frame count.
	if _frames >= 700 and (_reached_lvl2 or _frames >= 3000):
		_main._back_to_menu()
		print("TEST RESULT collected=", _max_collected, "/", _main.toys.size(), " win_seen=", _win_seen, " advanced_to_level2=", _reached_lvl2, " back_at_menu=", _main.start_overlay.visible and not _main.win_panel.visible, " coco_visible=", _main.coco.visible)
		return true
	return false
