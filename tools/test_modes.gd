extends SceneTree
## Modes & menu test: (1) Normal starts with 8 active toys and the 7 extra
## hidden; (2) the Menu button flow returns to the start screen, frozen;
## (3) Impossible activates all 15, the mission text says 15, and one of the
## new toys (the balloon) can actually be collected.

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _stage_t: float = 0.0
var _eight_ok: bool = false
var _menu_ok: bool = false
var _fifteen_ok: bool = false
var _newtoy_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	_stage_t += delta
	if _stage == 0 and _t >= 0.2:
		_main._on_play_pressed()  # default difficulty: Normal
		var extra: Dictionary = _main.toys[14]
		_eight_ok = _main.active_toys == 8 and extra.taken and not extra.root.visible and _main.menu_btn.visible
		print("MODES eight check: active=", _main.active_toys, " extra_taken=", extra.taken, " extra_visible=", extra.root.visible, " label='", _main.star_label.text, "'")
		_main._back_to_menu()  # what the Menu button calls
		_stage = 1
		_stage_t = 0.0
	elif _stage == 1 and _stage_t >= 0.3:
		_menu_ok = not _main.game_started and _main.start_overlay.visible and not _main.mimi.move_enabled and not _main.menu_btn.visible and not _main.timer_label.visible
		print("MODES menu check: started=", _main.game_started, " overlay=", _main.start_overlay.visible, " move=", _main.mimi.move_enabled)
		_main._on_difficulty_pressed(3)  # Impossible
		_main._on_play_pressed()
		var extra2: Dictionary = _main.toys[14]
		_fifteen_ok = _main.active_toys == 15 and not extra2.taken and extra2.root.visible and _main.mission_label.text.contains("15")
		print("MODES fifteen check: active=", _main.active_toys, " mission='", _main.mission_label.text, "' label='", _main.star_label.text, "'")
		# Collect the balloon (toy 14, floating in the living room corner)
		_main.mouse_active = false
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = (extra2.root as Node3D).global_position + Vector3(0, 0.05, 0)
		_stage = 2
		_stage_t = 0.0
	elif _stage == 2:
		if _main.collected == 1:
			_newtoy_ok = true
			print("MODES RESULT eight=", _eight_ok, " menu=", _menu_ok, " fifteen=", _fifteen_ok, " newtoy=", _newtoy_ok)
			return true
		elif _stage_t > 5.0:
			print("MODES RESULT eight=", _eight_ok, " menu=", _menu_ok, " fifteen=", _fifteen_ok, " newtoy=false (collect timeout)")
			return true
	return false
