extends SceneTree
## Levels test (Normal difficulty, 8 toys per level): sweep each level's toys
## and verify the progression 1 → 2 → 3 → 4 → back at the menu, with per-level
## hiding spots, time budgets and the second mouse joining on levels 3 and 4.

var _main: Node
var _frames: int = 0
var _sweep_idx: int = 0
var _sweep_cool: int = 0
var _lvl_time_ok: Array = [false, false, false, false]
var _lvl_spots_ok: Array = [false, false, false, false]
var _lvl2_mouse_off: bool = false
var _lvl3_mouse_on: bool = false
var _lvl4_mouse_on: bool = false
var _world_ok: Array = [false, false, false, false]
var _wins_seen: int = 0
var _win_counted: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _active_toys() -> Array:
	var out: Array = []
	for toy in _main.toys:
		if toy.active:
			out.append(toy)
	return out

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_main._on_play_pressed()  # Normal
		_main.mouse_active = false  # mice parked: progression is what is tested here
		_lvl_time_ok[0] = _main.time_left > 55.0 and _main.time_left <= 60.0
		_lvl_spots_ok[0] = true  # level-1 homes are the classic ones (covered by test_game)
		_world_ok[0] = _main.world_roots[0].visible and not _main.world_roots[1].visible and not _main.world_roots[2].visible and not _main.world_roots[3].visible
	if _frames < 20:
		return false
	# Count win panels (one per level)
	if _main.win_panel.visible and not _win_counted:
		_win_counted = true
		_wins_seen += 1
	if not _main.win_panel.visible:
		_win_counted = false
	# The moment a new level starts, check its budget and hiding spots
	if _main.game_started and not _main.win_panel.visible and not _main.game_over:
		var li: int = _main.level - 1
		if li >= 1 and not _lvl_spots_ok[li]:
			var act := _active_toys()
			var toy0: Dictionary = act[0]
			_lvl_spots_ok[li] = (toy0.root as Node3D).global_position.distance_to(toy0.homes[li]) < 0.05
			_lvl_time_ok[li] = _main.time_left > _main.LEVEL_TIMES[li] - 6.0
			_world_ok[li] = _main.world_roots[li].visible and not _main.world_roots[(li + 1) % 4].visible and not _main.world_roots[(li + 2) % 4].visible
			if li == 1:
				_lvl2_mouse_off = not _main.mice[1].active
			if li == 2:
				_lvl3_mouse_on = _main.mice[1].active
			if li == 3:
				_lvl4_mouse_on = _main.mice[1].active
			_sweep_idx = 0
			_sweep_cool = 0
	# After the level-4 win, the game should land back at the menu by itself
	if _wins_seen >= 4 and _main.start_overlay.visible:
		print("LEVELS RESULT wins=", _wins_seen,
			" time_ok=", _lvl_time_ok,
			" spots_ok=", _lvl_spots_ok,
			" world_ok=", _world_ok,
			" lvl2_mouse_off=", _lvl2_mouse_off,
			" lvl3_mouse_on=", _lvl3_mouse_on,
			" lvl4_mouse_on=", _lvl4_mouse_on,
			" back_at_menu=true")
		return true
	# Sweep: teleport Mimi onto the active toys, one by one
	if _main.game_started and not _main.win_panel.visible and not _main.game_over and not _main.game_won:
		_sweep_cool -= 1
		if _sweep_cool <= 0:
			var act2 := _active_toys()
			if _sweep_idx < act2.size():
				var toy: Dictionary = act2[_sweep_idx]
				_main.mimi.velocity = Vector3.ZERO
				_main.mimi.global_position = (toy.root as Node3D).global_position + Vector3(0, 0.05, 0)
				_sweep_idx += 1
				_sweep_cool = 20
	if _frames > 6000:
		print("LEVELS RESULT TIMEOUT wins=", _wins_seen, " level=", _main.level, " time_ok=", _lvl_time_ok, " spots_ok=", _lvl_spots_ok, " lvl3_mouse_on=", _lvl3_mouse_on, " lvl4_mouse_on=", _lvl4_mouse_on)
		return true
	return false
