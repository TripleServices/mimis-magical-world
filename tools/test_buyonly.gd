extends SceneTree
## Buy-only store economy (Google Play build): with buy_only on, gameplay
## grants NO coins (level wins, Lulu), the win panel shows no coin text and
## Lulu's sign drops the coins line. With it off, phase-1 earning works.

var _main: Node
var _frames: int = 0

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 6:
		_main.buy_only = true
		_main._on_play_pressed()
		_main.mouse_active = false
	if _frames == 10:
		var start_coins: int = _main.coins  # balance may persist from other tests
		_main._add_coins(50)
		var grants_blocked: bool = _main.coins == start_coins
		_main._found_lulu()
		var lulu_ok: bool = _main.coins == start_coins and _main.lulu_label.text == "Lulu! +40s"
		_main._show_win()
		var win_ok: bool = _main.coins == start_coins and _main.win_coins.text == ""
		_main.buy_only = false
		_main._add_coins(10)
		var earn_ok: bool = _main.coins == start_coins + 10
		print("BUYONLY RESULT grants_blocked=", grants_blocked, " lulu=", lulu_ok,
			" win=", win_ok, " earn_mode=", earn_ok)
		return true
	return false
