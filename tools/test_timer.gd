extends SceneTree
## Mission timer test: (1) the countdown reaches zero -> lose panel shows,
## Mimi can no longer move, game_over is set; (2) Try Again (_reset_game)
## restores the toys, the counter and a fresh 40 seconds.

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _lose_ok: bool = false
var _retry_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if _stage == 0 and _t >= 0.2:
		_main._on_play_pressed()
		print("TIMER start: time_left=", _main.time_left, " label='", _main.timer_label.text, "' visible=", _main.timer_label.visible)
		_main.time_left = 1.5  # fast-forward: time almost up
		_stage = 1
	elif _stage == 1 and _t >= 2.2:
		_lose_ok = _main.game_over and _main.lose_panel.visible and not _main.mimi.move_enabled and _main.time_left == 0.0
		print("TIMER lose check: game_over=", _main.game_over, " panel=", _main.lose_panel.visible, " move=", _main.mimi.move_enabled, " time_left=", _main.time_left)
		_main._reset_game()  # what the Try Again button calls
		_stage = 2
	elif _stage == 2 and _t >= 2.6:
		# On Normal only the classic 8 come back (the 7 extra stay hidden)
		var first_toy: Dictionary = _main.toys[0]
		var toys_back: bool = first_toy.taken == false and first_toy.root.visible
		_retry_ok = toys_back and _main.collected == 0 and _main.time_left > 39.0 and _main.mimi.move_enabled and not _main.lose_panel.visible and not _main.game_over
		print("TIMER retry check: toys_back=", toys_back, " collected=", _main.collected, " time_left=", _main.time_left, " move=", _main.mimi.move_enabled)
		print("TIMER RESULT lose=", _lose_ok, " retry=", _retry_ok)
		return true
	return false
