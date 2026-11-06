extends SceneTree
## Shop test: earning coins (level win, Lulu), buying, equipping, swapping,
## unequipping, the can't-afford guard, and save-file persistence.

var _main: Node
var _frames: int = 0
var _panel_ok: bool = false
var _buy_ok: bool = false
var _swap_ok: bool = false
var _afford_ok: bool = false
var _unequip_ok: bool = false
var _persist_ok: bool = false
var _earn_ok: bool = false
var _lulu_ok: bool = false

func _initialize() -> void:
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/mimi_shop.cfg")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		_main._open_shop()
		_panel_ok = _main.shop_panel.visible and not _main.start_overlay.visible
		_main._add_coins(100)
		_main._on_shop_buy("crown")  # costs 200: must refuse
		_afford_ok = _main.coins == 100 and not _main.owned.has("crown")
		_main._on_shop_buy("red_cap")   # 30 -> 70 left, auto-worn
		_main._on_shop_buy("gold_bell") # 40 -> 30 left
		_buy_ok = _main.coins == 30 and _main.owned.has("red_cap") and _main.owned.has("gold_bell") \
			and _main.equipped.head == "red_cap" and _main.acc_nodes.red_cap.visible \
			and _main.acc_nodes.gold_bell.visible
	if _frames == 12:
		_main._add_coins(200)
		_main._on_shop_buy("crown")  # 200 -> 30 left; replaces the cap in the head slot
		_swap_ok = _main.coins == 30 and _main.equipped.head == "crown" \
			and _main.acc_nodes.crown.visible and not _main.acc_nodes.red_cap.visible
		_main._on_shop_unequip("head")
		_unequip_ok = _main.equipped.head == "" and not _main.acc_nodes.crown.visible
		_main._on_shop_equip("red_cap")
	if _frames == 16:
		var saved_coins: int = _main.coins
		_main.coins = 0
		_main.owned = []
		_main.equipped.head = ""
		_main._load_game()
		_persist_ok = _main.coins == saved_coins and _main.owned.has("crown") and _main.equipped.head == "red_cap"
	if _frames == 20:
		var before: int = _main.coins
		_main.level = 1
		_main.game_started = true
		_main._show_win()
		_earn_ok = _main.coins == before + 20 and _main.win_coins.text == "+20 coins!"
	if _frames == 24:
		_main.game_won = false
		_main.game_over = false
		_main.lulu_found = false
		var b2: int = _main.coins
		_main._found_lulu()
		_lulu_ok = _main.coins == b2 + 10
		print("SHOP RESULT panel=", _panel_ok, " buy=", _buy_ok, " swap=", _swap_ok,
			" afford=", _afford_ok, " unequip=", _unequip_ok, " persist=", _persist_ok,
			" earn=", _earn_ok, " lulu=", _lulu_ok)
		return true
	return false
