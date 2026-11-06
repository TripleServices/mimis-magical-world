extends SceneTree
## Mini-games test: open the Mini Games panel from the start screen, play
## each game (ABC Letters, Numbers, Sums) answering all 5 rounds correctly
## through the real choice buttons, and check the finish box appears with
## 5 stars. One deliberate wrong tap first: it must cost nothing (no star,
## no advance, just "Try again!"). No coins may be granted by any game.

var _main: Node
var _t: float = 0.0
var _press_cd: float = 0.0
var _stage: int = 0
var _kinds := ["abc", "numbers", "sums"]
var _kind_i: int = 0
var _panel_ok := false
var _wrong_ok := false
var _wrong_done := false
var _all_ok := true
var _start_coins: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _press(idx: int) -> void:
	var btn := _main.mg_choices.get_child(idx) as Button
	if btn != null and not btn.disabled:
		btn.pressed.emit()

func _process(delta: float) -> bool:
	_t += delta
	_press_cd -= delta
	match _stage:
		0:
			if _t >= 0.3:
				_start_coins = _main.coins
				_main._open_mini_games()
				_panel_ok = _main.mg_panel.visible and not _main.start_overlay.visible
				_main._mg_start(_kinds[0])
				_stage = 1
		1:
			if _main.mg_finished:
				var ok: bool = _main.mg_stars == 5 and _main.mg_finish_box.visible \
					and _main.mg_finish_stars.text.count("★") == 5
				_all_ok = _all_ok and ok
				_kind_i += 1
				if _kind_i >= _kinds.size():
					_stage = 2
				else:
					_main._mg_quit_to_picker()
					_main._mg_start(_kinds[_kind_i])
			elif _press_cd <= 0.0 and _main.mg_choices.get_child_count() == 3 and _main.mg_correct_idx >= 0:
				_press_cd = 0.2
				if not _wrong_done and _main.mg_round == 0 and _main.mg_stars == 0:
					# One wrong tap: gentle "Try again!", no star, no advance
					_press((_main.mg_correct_idx + 1) % 3)
					_wrong_done = true
					_wrong_ok = _main.mg_stars == 0 and _main.mg_round == 0 \
						and _main.mg_feedback.text == "Try again!"
				else:
					_press(_main.mg_correct_idx)
			if _t > 150.0:
				print("MINIGAMES RESULT TIMEOUT kind=", _kind_i, " round=", _main.mg_round)
				return true
		2:
			_main._mg_quit_to_picker()
			_main._close_mini_games()
			var menu_ok: bool = _main.start_overlay.visible and not _main.mg_panel.visible \
				and not _main.mg_game_panel.visible
			var coins_ok: bool = _main.coins == _start_coins
			print("MINIGAMES RESULT panel=", _panel_ok, " wrong_gentle=", _wrong_ok,
				" all_games=", _all_ok, " menu=", menu_ok, " no_coins=", coins_ok)
			return true
	return false
