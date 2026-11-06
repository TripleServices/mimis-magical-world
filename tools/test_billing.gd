extends SceneTree
## Billing v1.2 test (headless, no Android): parent gate flow, pack buttons,
## store-response simulation (product details, PURCHASED / PENDING), the
## pending-record state machine (no double grant, consume clears it),
## persistence, and the web earn mode staying untouched.

var _main: Node
var _frames: int = 0
var _gate_ok := false
var _packs_ok := false
var _grant_ok := false
var _pending_ok := false
var _consume_ok := false
var _web_ok := false

func _initialize() -> void:
	DirAccess.remove_absolute(OS.get_user_data_dir() + "/mimi_shop.cfg")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		# Android mode, but no store on desktop: Buy Coins reports the
		# packs are unavailable and keeps the gate hidden.
		_main.buy_only = true
		_main._open_shop()
		_main._on_buy_coins()
		_gate_ok = _main.shop_hint.text == "Coin packs are not available on this device." and not _main._gate_box.visible
		# Gate flow itself (UI only, no store needed).
		_main._show_gate()
		var correct := 0
		for b in _main._gate_buttons:
			if bool(b.get_meta("correct", false)):
				correct += 1
		_gate_ok = _gate_ok and _main._gate_box.visible and correct == 1
		# Answer wrong first: gate stays, packs stay hidden, new question.
		for b in _main._gate_buttons:
			if not bool(b.get_meta("correct", false)):
				_main._on_gate_answer(b)
				break
		_gate_ok = _gate_ok and _main._gate_box.visible and not _main._packs_box.visible and _main.shop_hint.text == "Try again!"
		# Then answer right: packs open.
		for b in _main._gate_buttons:
			if bool(b.get_meta("correct", false)):
				_main._on_gate_answer(b)
				break
		_packs_ok = not _main._gate_box.visible and _main._packs_box.visible
	if _frames == 12:
		# Store prices arrive (simulated): buttons show store prices,
		# still disabled because the store is not connected.
		_main._on_billing_product_details({"product_details": [
			{"product_id": "coins_100", "price": "$0.99"},
			{"product_id": "coins_350", "price": "$1.99"},
			{"product_id": "coins_850", "price": "$3.99"},
		]})
		var b100: Button = _main._pack_buttons["coins_100"]
		var b850: Button = _main._pack_buttons["coins_850"]
		_packs_ok = _packs_ok and b100.text == "100 coins — $0.99" and b850.text == "850 coins — $3.99" and b100.disabled
		# Simulate a PURCHASED purchase (store callback): coins granted once.
		var before: int = _main.coins
		_main._reconcile_purchase({"product_id": "coins_350", "purchase_token": "tok_test_1", "purchase_state": 1})
		var rec: Dictionary = _main._pending_tokens.get("tok_test_1", {})
		_grant_ok = _main.coins == before + 350 and String(rec.get("state", "")) == "granted"
		# Re-delivering the same purchase must NOT grant twice.
		_main._reconcile_purchase({"product_id": "coins_350", "purchase_token": "tok_test_1", "purchase_state": 1})
		_grant_ok = _grant_ok and _main.coins == before + 350
		# PENDING grants nothing and shows the pending hint.
		_main._reconcile_purchase({"product_id": "coins_100", "purchase_token": "tok_test_2", "purchase_state": 2})
		_pending_ok = _main.coins == before + 350 and not _main._pending_tokens.has("tok_test_2") and _main.shop_hint.text == "Payment pending — check Play Store."
		# Unknown product id is ignored.
		_main._reconcile_purchase({"product_id": "coins_999", "purchase_token": "tok_test_3", "purchase_state": 1})
		_pending_ok = _pending_ok and _main.coins == before + 350 and not _main._pending_tokens.has("tok_test_3")
	if _frames == 16:
		# Consume response clears the granted record; coins survive a reload.
		_main._consuming_tokens["tok_test_1"] = true
		_main._on_billing_consume_response({"response_code": 0, "purchase_token": "tok_test_1"})
		var saved: int = _main.coins
		_consume_ok = not _main._pending_tokens.has("tok_test_1")
		_main.coins = 0
		_main._pending_tokens = {}
		_main._load_game()
		_consume_ok = _consume_ok and _main.coins == saved
	if _frames == 20:
		# Web earn mode: no billing, coins still earned by playing.
		_main.buy_only = false
		_main._init_billing()
		var b2: int = _main.coins
		_main._add_coins(10)
		_web_ok = _main._billing == null and _main.coins == b2 + 10
		print("BILLING RESULT gate=", _gate_ok, " packs=", _packs_ok, " grant=", _grant_ok,
			" pending=", _pending_ok, " consume=", _consume_ok, " web=", _web_ok)
		return true
	return false
