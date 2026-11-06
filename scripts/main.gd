extends Node3D
## Mimi's Magical World — first version: Mimi's living room.
## Free exploration for kids 3-6: find the 5 lost toys, earn 5 stars,
## and Coco shows up to celebrate. Everything is built from primitives.

const MIMI_SCRIPT := preload("res://scripts/mimi.gd")
const JOYSTICK_SCRIPT := preload("res://scripts/joystick.gd")
const JUMP_SCRIPT := preload("res://scripts/jump_button.gd")

var mimi  # CharacterBody3D with the mimi.gd script attached
var camera: Camera3D
var joystick: Control
var toys: Array = []  # {root, pivot, base_y, phase, taken}
var collected: int = 0
var star_label: Label
var banner_label: Label
var win_panel: Control
var start_overlay: Control
var coco: Node3D
var coco_tail: Node3D
var burst: CPUParticles3D
var float_star: Label3D
var chime_player: AudioStreamPlayer
var win_player: AudioStreamPlayer
var meow_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var time: float = 0.0
var game_started: bool = false
var butterfly: Node3D
var butterfly_wing_l: Node3D
var butterfly_wing_r: Node3D
var lulu: Node3D
var lulu_visual: Node3D
var lulu_label: Label3D
var lulu_found: bool = false

var cam_yaw: float = 0.0  # Roblox-style orbit: the camera circles Mimi
var _cam_touch_index: int = -1
var _cam_touch_ok: bool = false

const TIME_LIMIT := 60.0  # seconds to find all the toys before time runs out
var time_left: float = TIME_LIMIT
var timer_label: Label
var lose_panel: Control
var game_won: bool = false
var game_over: bool = false
var timeout_player: AudioStreamPlayer

# The Mouse: a sneaky little enemy. If he bumps into Mimi he snatches her
# latest toy and runs; Coco (who now lives by his doghouse) chases him until
# he drops it, and Mimi can pick it up again.
# Per-mouse state dictionaries (body, visual, tail, label, carry, target,
# stuck, last_pos, flee, cooldown, active, spawn). mice[1] only plays on
# Impossible — two thieves at once.
var mice: Array = []
var collection_order: Array = []
var mouse_active := true  # smoke tests park the mouse
var mouse_waypoints: Array = [Vector3(0, 0, 2.5), Vector3(13, 0, 2), Vector3(-14, 0, 1), Vector3(0, 0, 11), Vector3(-6, 0, -3.5), Vector3(16.5, 0, -3), Vector3(-17, 0, -3.5), Vector3(5, 0, 9), Vector3(-11, 0, 12), Vector3(18, 0, 3)]
var coco_state := "idle"
var coco_home := Vector3(7.0, 0, 15.15)
var squeak_player: AudioStreamPlayer

# Mouse difficulty levels, chosen on the start screen. Mimi walks at 3.4 and
# runs at 5.8: Easy hunts slower than her walk, Impossible almost at her run.
const DIFFS := [
	{"name": "Easy", "hunt": 2.6, "wander": 2.2, "flee": 3.6, "coco": 5.1, "range": 6.0, "cooldown": 8.0, "lead": 0.0},
	{"name": "Normal", "hunt": 3.4, "wander": 3.0, "flee": 4.2, "coco": 5.1, "range": 10.0, "cooldown": 5.0, "lead": 0.0},
	{"name": "Hard", "hunt": 4.3, "wander": 3.4, "flee": 4.8, "coco": 5.3, "range": 16.0, "cooldown": 3.0, "lead": 0.15},
	{"name": "Impossible", "hunt": 5.4, "wander": 3.8, "flee": 5.4, "coco": 5.6, "range": 999.0, "cooldown": 1.5, "lead": 0.35},
]
var difficulty := 1  # Normal
var diff_buttons: Array = []
var active_toys := 8  # 8 on Easy/Normal/Hard, all 15 on Impossible
var mission_label: Label
var menu_btn: Button

# Levels: beat a level to unlock the next; beating the last one (the
# beach) wins the game and returns to the menu. Each level hides the toys
# in new spots, allows more time, and the higher levels wake the second
# mouse sooner.
const LEVEL_TIMES := [60.0, 75.0, 90.0, 105.0]
var level := 1
# One world per level: the house, the school, the gym, the beach. Only the active world
# is visible and solid; Mimi, Coco, Lulu, the mice and the toys move between
# them (spawns, hiding spots and hangouts come from this table).
var world_roots: Array = []
const SCEN := [
	{"name": "Mimi's House", "short": "House", "coco_home": Vector3(7.0, 0, 15.15), "lulu_pos": Vector3(-6.05, 0, 13.05), "lulu_rot": 0.55, "mouse_spawns": [Vector3(17.8, 0.1, -4.6), Vector3(-17.5, 0.1, 3.2)]},
	{"name": "the School", "short": "School", "coco_home": Vector3(5.5, 0, 14.8), "lulu_pos": Vector3(-6.05, 0, 13.05), "lulu_rot": 0.55, "mouse_spawns": [Vector3(18.5, 0.1, -4.6), Vector3(-18.5, 0.1, 3.5)]},
	{"name": "the Gym", "short": "Gym", "coco_home": Vector3(16.5, 0, 5.2), "lulu_pos": Vector3(-16.2, 0, 5.35), "lulu_rot": -0.5, "mouse_spawns": [Vector3(-19.0, 0.1, -4.3), Vector3(19.0, 0.1, 4.6)]},
	{"name": "the Beach", "short": "Beach", "coco_home": Vector3(14.0, 0, 13.2), "lulu_pos": Vector3(-15.5, 0, 12.9), "lulu_rot": 0.55, "mouse_spawns": [Vector3(18.5, 0.1, -4.8), Vector3(-18.5, 0.1, 10.5)]},
]

# ------------------------------------------------------------------ coins & shop
# Shop phase 1: coins are earned in the game (win a level +20, clear the
# final level +50 extra, find Lulu +10) and spent in Mimi's Shop on hats,
# necklaces and glasses that Mimi actually wears. Coins, owned items and
# what she is wearing are saved to user://, so they survive between sessions.
# Store economy (user decision, 2026-11-01): on Android (the Google Play
# build) coins are ONLY bought with real money, so gameplay never grants
# them — buy_only turns every grant off. The web/itch.io demo keeps the
# phase-1 earning mode. Real purchases use Google Play Billing (v1.2, see
# the "Play Billing" section below); purchases credit coins directly, not
# through _add_coins.
const SAVE_PATH := "user://mimi_shop.cfg"
const SHOP_ITEMS := [
	{"id": "red_cap", "name": "Red Cap", "slot": "head", "price": 30},
	{"id": "party_hat", "name": "Party Hat", "slot": "head", "price": 60},
	{"id": "flower_crown", "name": "Flower Crown", "slot": "head", "price": 90},
	{"id": "crown", "name": "Golden Crown", "slot": "head", "price": 200},
	{"id": "gold_bell", "name": "Gold Bell", "slot": "neck", "price": 40},
	{"id": "rainbow_scarf", "name": "Rainbow Scarf", "slot": "neck", "price": 80},
	{"id": "pearls", "name": "Pearl Necklace", "slot": "neck", "price": 120},
	{"id": "star_glasses", "name": "Star Glasses", "slot": "face", "price": 70},
	{"id": "heart_glasses", "name": "Heart Glasses", "slot": "face", "price": 110},
]
var coins := 0
var buy_only: bool = OS.has_feature("android")
var owned: Array = []
var equipped := {"head": "", "neck": "", "face": ""}
var acc_nodes := {}
var coin_label: Label
var start_coin_label: Label
var shop_panel: Control
var shop_coins_label: Label
var shop_hint: Label
var shop_rows: VBoxContainer
var win_coins: Label

func _save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("shop", "coins", coins)
	cfg.set_value("shop", "owned", owned)
	cfg.set_value("shop", "eq_head", equipped.head)
	cfg.set_value("shop", "eq_neck", equipped.neck)
	cfg.set_value("shop", "eq_face", equipped.face)
	# Pending Play Billing records (purchase_token -> {product_id, state});
	# written here too because this overwrites the whole save file.
	cfg.set_value("billing", "pending", _pending_tokens)
	cfg.save(SAVE_PATH)

func _load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	coins = int(cfg.get_value("shop", "coins", 0))
	owned = cfg.get_value("shop", "owned", [])
	equipped.head = String(cfg.get_value("shop", "eq_head", ""))
	equipped.neck = String(cfg.get_value("shop", "eq_neck", ""))
	equipped.face = String(cfg.get_value("shop", "eq_face", ""))
	var pend = cfg.get_value("billing", "pending", {})
	if pend is Dictionary:
		_pending_tokens = pend.duplicate(true)

func _update_coin_labels() -> void:
	if coin_label != null:
		coin_label.text = "Coins: %d" % coins
	if start_coin_label != null:
		start_coin_label.text = "Coins: %d" % coins
	if shop_coins_label != null:
		shop_coins_label.text = "Coins: %d" % coins

func _add_coins(n: int) -> void:
	if buy_only:
		return  # Play build: coins come only from purchased packs
	coins += n
	_update_coin_labels()
	_save_game()

func _shop_item(id: String) -> Dictionary:
	for it in SHOP_ITEMS:
		if it.id == id:
			return it
	return {}

func _torus(parent: Node, pos: Vector3, inner: float, outer: float, color: Color, rot_x: float = 0.0, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = inner
	tor.outer_radius = outer
	mi.mesh = tor
	mi.material_override = _mat(color, 0.7, emission)
	mi.position = pos
	mi.rotation.x = rot_x
	parent.add_child(mi)
	return mi

func _build_accessories() -> void:
	var hp: Node3D = mimi._head_pivot
	# --- head slot (children of the head pivot, so they follow her head)
	var cap := Node3D.new()
	cap.position = Vector3(0, 0.40, 0.01)
	hp.add_child(cap)
	_sphere(cap, Vector3.ZERO, 0.30, Color(0.88, 0.25, 0.22), Vector3(1, 0.58, 1))
	_box(Vector3(0, -0.02, 0.30), Vector3(0.36, 0.035, 0.20), Color(0.78, 0.18, 0.16), false, cap)
	_sphere(cap, Vector3(0, 0.17, 0), 0.055, Color(1, 0.85, 0.3))
	acc_nodes.red_cap = cap
	var party := Node3D.new()
	party.position = Vector3(0, 0.44, 0)
	hp.add_child(party)
	_cone_at(party, Vector3(0, 0.21, 0), 0.21, 0.42, Color(0.98, 0.55, 0.75))
	_cylinder(party, Vector3(0, 0.03, 0), 0.215, 0.225, 0.07, Color(1, 0.80, 0.25))
	_sphere(party, Vector3(0, 0.46, 0), 0.07, Color(1, 1, 1))
	acc_nodes.party_hat = party
	var flowers := Node3D.new()
	flowers.position = Vector3(0, 0.42, 0)
	hp.add_child(flowers)
	_torus(flowers, Vector3.ZERO, 0.235, 0.295, Color(0.40, 0.72, 0.38))
	var flower_cols := [Color(0.98, 0.55, 0.75), Color(1, 0.85, 0.35), Color(1, 1, 1), Color(1, 0.70, 0.45), Color(0.85, 0.60, 0.95)]
	for i in range(5):
		var a := i * TAU / 5.0
		_sphere(flowers, Vector3(cos(a) * 0.265, 0.05, sin(a) * 0.265), 0.055, flower_cols[i])
	acc_nodes.flower_crown = flowers
	var crown := Node3D.new()
	crown.position = Vector3(0, 0.46, 0)
	hp.add_child(crown)
	_cylinder(crown, Vector3(0, 0.08, 0), 0.185, 0.20, 0.16, Color(1, 0.80, 0.25), 0.25)
	for i in range(3):
		var a2 := i * TAU / 3.0
		_cone_at(crown, Vector3(cos(a2) * 0.17, 0.21, sin(a2) * 0.17), 0.045, 0.10, Color(1, 0.80, 0.25))
	_sphere(crown, Vector3(0, 0.08, 0.19), 0.04, Color(0.92, 0.24, 0.30), Vector3.ONE, 0.3)
	acc_nodes.crown = crown
	# --- face slot (glasses in front of her eyes)
	acc_nodes.star_glasses = _acc_glasses(hp, Color(1, 0.80, 0.25), Color(0.25, 0.35, 0.60))
	acc_nodes.heart_glasses = _acc_glasses(hp, Color(0.98, 0.55, 0.68), Color(0.98, 0.70, 0.80))
	# --- neck slot (children of the body, by her collar)
	var bell := Node3D.new()
	bell.position = Vector3(0, 0.70, 0.26)
	mimi.add_child(bell)
	_sphere(bell, Vector3.ZERO, 0.075, Color(1, 0.80, 0.25), Vector3.ONE, 0.3)
	_box(Vector3(0, -0.03, 0.06), Vector3(0.07, 0.015, 0.02), Color(0.55, 0.40, 0.10), false, bell)
	acc_nodes.gold_bell = bell
	var scarf := Node3D.new()
	scarf.position = Vector3(0, 0.80, 0)
	mimi.add_child(scarf)
	_torus(scarf, Vector3.ZERO, 0.145, 0.205, Color(0.95, 0.50, 0.25), 0.12)
	_box(Vector3(0.15, -0.18, 0.20), Vector3(0.10, 0.24, 0.035), Color(0.30, 0.70, 0.75), false, scarf)
	acc_nodes.rainbow_scarf = scarf
	var pearls := Node3D.new()
	pearls.position = Vector3(0, 0.78, 0.02)
	mimi.add_child(pearls)
	_torus(pearls, Vector3.ZERO, 0.15, 0.182, Color(0.97, 0.95, 0.92), 0.30)
	acc_nodes.pearls = pearls
	_apply_accessories()

func _acc_glasses(hp: Node3D, frame_col: Color, lens_col: Color) -> Node3D:
	var g := Node3D.new()
	g.position = Vector3(0, 0.20, 0.335)
	hp.add_child(g)
	for side in [-1.0, 1.0]:
		_torus(g, Vector3(0.125 * side, 0, 0), 0.072, 0.098, frame_col, PI / 2.0)
		_sphere(g, Vector3(0.125 * side, 0, -0.005), 0.072, lens_col, Vector3(1, 1, 0.35))
	_box(Vector3(0, 0.01, 0), Vector3(0.10, 0.02, 0.02), frame_col, false, g)
	return g

func _apply_accessories() -> void:
	for it in SHOP_ITEMS:
		var n: Node3D = acc_nodes.get(it.id)
		if n != null:
			n.visible = equipped[it.slot] == it.id

func _build_shop(layer: CanvasLayer) -> void:
	shop_panel = Control.new()
	shop_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(shop_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.15, 0.08, 0.18, 0.30)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	shop_panel.add_child(dim)
	var panel := ColorRect.new()
	panel.color = Color(0.13, 0.10, 0.22, 0.95)
	panel.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	panel.offset_left = -580
	panel.offset_right = 0
	panel.offset_top = -360
	panel.offset_bottom = 360
	shop_panel.add_child(panel)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24
	vbox.offset_right = -24
	vbox.offset_top = 20
	vbox.offset_bottom = -20
	panel.add_child(vbox)
	vbox.add_child(_big_label("Mimi's Shop", 44, Color(1, 0.85, 0.92)))
	shop_coins_label = _big_label("Coins: 0", 30, Color(1, 0.85, 0.3))
	vbox.add_child(shop_coins_label)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	shop_rows = VBoxContainer.new()
	shop_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(shop_rows)
	if buy_only:
		var buy_btn := Button.new()
		buy_btn.text = "Buy Coins"
		buy_btn.custom_minimum_size = Vector2(260, 60)
		buy_btn.add_theme_font_size_override("font_size", 28)
		buy_btn.pressed.connect(_on_buy_coins)
		var bc := CenterContainer.new()
		bc.add_child(buy_btn)
		vbox.add_child(bc)
	# The gate + pack buttons are built always (hidden) so the shop layout
	# is the same on every platform; only the "Buy Coins" button above is
	# Android-only. They only ever become visible after the parent gate.
	_build_gate_and_packs(vbox)
	shop_hint = _big_label("Get coin packs to dress Mimi up!" if buy_only else "Win levels and find Lulu to earn coins!", 20, Color(1, 1, 1))
	vbox.add_child(shop_hint)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.custom_minimum_size = Vector2(200, 60)
	close_btn.add_theme_font_size_override("font_size", 28)
	close_btn.pressed.connect(_close_shop)
	var cc := CenterContainer.new()
	cc.add_child(close_btn)
	vbox.add_child(cc)
	shop_panel.visible = false

func _refresh_shop() -> void:
	for c in shop_rows.get_children():
		c.queue_free()
	var slot_names := {"head": "— Hats —", "neck": "— Necklaces & Scarves —", "face": "— Glasses —"}
	for slot in ["head", "neck", "face"]:
		var h := Label.new()
		h.text = slot_names[slot]
		h.add_theme_font_size_override("font_size", 22)
		h.add_theme_color_override("font_color", Color(1, 0.85, 0.92))
		shop_rows.add_child(h)
		for it in SHOP_ITEMS:
			if it.slot != slot:
				continue
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 10)
			shop_rows.add_child(row)
			var nm := Label.new()
			nm.text = it.name
			nm.custom_minimum_size = Vector2(215, 44)
			nm.add_theme_font_size_override("font_size", 24)
			row.add_child(nm)
			var b := Button.new()
			b.custom_minimum_size = Vector2(170, 48)
			b.add_theme_font_size_override("font_size", 22)
			if equipped[slot] == it.id:
				b.text = "Take off"
				b.pressed.connect(_on_shop_unequip.bind(slot))
			elif owned.has(it.id):
				b.text = "Wear"
				b.pressed.connect(_on_shop_equip.bind(it.id))
			else:
				b.text = "Buy · %d" % it.price
				b.disabled = coins < it.price
				b.pressed.connect(_on_shop_buy.bind(it.id))
			row.add_child(b)
			var st := Label.new()
			st.add_theme_font_size_override("font_size", 20)
			if equipped[slot] == it.id:
				st.text = "wearing"
				st.add_theme_color_override("font_color", Color(1, 0.70, 0.82))
			elif owned.has(it.id):
				st.text = "owned"
				st.add_theme_color_override("font_color", Color(0.75, 0.95, 0.75))
			else:
				st.text = "%d coins" % it.price
				st.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			row.add_child(st)
	_update_coin_labels()

func _on_shop_buy(id: String) -> void:
	var it := _shop_item(id)
	if it.is_empty() or owned.has(id) or coins < it.price:
		return
	coins -= it.price
	owned.append(id)
	equipped[it.slot] = id
	_apply_accessories()
	_update_coin_labels()
	_save_game()
	_refresh_shop()
	_play(chime_player)

func _on_shop_equip(id: String) -> void:
	var it := _shop_item(id)
	if it.is_empty() or not owned.has(id):
		return
	equipped[it.slot] = id
	_apply_accessories()
	_save_game()
	_refresh_shop()
	_play(meow_player)

func _on_shop_unequip(slot: String) -> void:
	equipped[slot] = ""
	_apply_accessories()
	_save_game()
	_refresh_shop()
	_play(meow_player)

func _open_shop() -> void:
	start_overlay.visible = false
	shop_panel.visible = true
	# Fresh gate every time the shop opens: prices stay hidden until a
	# grown-up answers the maths question again.
	if _gate_box != null:
		_gate_box.visible = false
	if _packs_box != null:
		_packs_box.visible = false
	# The v2.0.0 wrapper does not forward the billing_resume signal, so
	# re-query purchases whenever the shop opens (also retries a consume
	# left pending by a crash, via reconciliation).
	if buy_only and _billing != null:
		if _billing.is_ready():
			_billing.query_purchases(_PRODUCT_TYPE_INAPP)
		else:
			_billing.start_connection()
	_refresh_shop()

# ------------------------------------------------------------------ Play Billing (v1.2)
# Google Play Billing, Android only, via the official GodotGooglePlayBilling
# v2.0.0 plugin (BillingClient autoload). On web/desktop the native
# singleton is absent, so _init_billing() returns early and the shop keeps
# the phase-1 earning mode (buy_only is false there anyway).
# Products are consumable coin packs; prices always come from the store,
# never hardcoded. A parent gate (simple maths question) must be passed
# before any price or the Play purchase sheet is shown — the game targets
# kids 5 and under.
# Purchase safety: a PURCHASED purchase is recorded in the save file as
# "seen" BEFORE granting, then coins are granted, the record becomes
# "granted", and only then is the purchase consumed (consume also
# acknowledges it). Re-querying purchases on connect/shop-open reconciles
# any record left behind by a crash, so coins are never lost or granted
# twice. PENDING purchases grant nothing.
const COIN_PACKS := {"coins_100": 100, "coins_350": 350, "coins_850": 850}
const _PRODUCT_TYPE_INAPP := 0  # BillingClient.ProductType.INAPP
const _BILLING_OK := 0  # BillingClient.BillingResponseCode.OK
const _BILLING_USER_CANCELED := 1
var _billing: Node = null
var _billing_ready := false
var _pack_prices := {}  # product_id -> localized price string from the store
var _pending_tokens := {}  # purchase_token -> {"product_id": String, "state": "seen"|"granted"}
var _consuming_tokens := {}  # purchase_token -> true (consume requested, awaiting response)
var _gate_answer := 0
var _gate_box: VBoxContainer
var _gate_question: Label
var _gate_buttons: Array = []
var _packs_box: VBoxContainer
var _pack_buttons := {}  # product_id -> Button

func _init_billing() -> void:
	if not buy_only:
		return  # web/itch.io demo: coins are earned, no store
	if not OS.has_feature("android"):
		return
	if not Engine.has_singleton("GodotGooglePlayBilling"):
		return
	# Resolved at runtime (not the bare autoload name) so this script still
	# compiles if the addon is ever removed from the project.
	_billing = get_node_or_null("/root/BillingClient")
	if _billing == null:
		return
	_billing.connected.connect(_on_billing_connected)
	_billing.disconnected.connect(_on_billing_disconnected)
	_billing.connect_error.connect(_on_billing_connect_error)
	_billing.query_product_details_response.connect(_on_billing_product_details)
	_billing.query_purchases_response.connect(_on_billing_purchases)
	_billing.on_purchase_updated.connect(_on_billing_purchase_updated)
	_billing.consume_purchase_response.connect(_on_billing_consume_response)
	_billing.start_connection()

func _on_billing_connected() -> void:
	_billing_ready = true
	if _billing != null:
		_billing.query_product_details(PackedStringArray(COIN_PACKS.keys()), _PRODUCT_TYPE_INAPP)

func _on_billing_disconnected() -> void:
	_billing_ready = false

func _on_billing_connect_error(response_code: int, _debug_message: String) -> void:
	_billing_ready = false
	if response_code != _BILLING_USER_CANCELED and shop_hint != null:
		shop_hint.text = "Couldn't connect to the store. Try again."

func _on_billing_product_details(response: Dictionary) -> void:
	var details: Array = response.get("product_details", response.get("result_array", []))
	for p in details:
		if p is Dictionary:
			var pid := String(p.get("product_id", ""))
			var price := String(p.get("price", ""))
			if pid != "" and COIN_PACKS.has(pid) and price != "":
				_pack_prices[pid] = price
	_refresh_pack_buttons()
	if _billing != null:
		_billing.query_purchases(_PRODUCT_TYPE_INAPP)

func _on_billing_purchases(response: Dictionary) -> void:
	_handle_purchase_list(response)

func _on_billing_purchase_updated(response: Dictionary) -> void:
	var code := int(response.get("response_code", _BILLING_OK))
	var purchases: Array = response.get("purchases", response.get("result_array", []))
	if purchases.is_empty() and code != _BILLING_OK and code != _BILLING_USER_CANCELED:
		if shop_hint != null:
			shop_hint.text = "Couldn't complete the purchase. Try again."
		return
	_handle_purchase_list(response)

func _handle_purchase_list(response: Dictionary) -> void:
	var purchases: Array = response.get("purchases", response.get("result_array", []))
	for p in purchases:
		if p is Dictionary:
			_reconcile_purchase(p)

func _purchase_state(p: Dictionary) -> String:
	var st = p.get("purchase_state", 0)
	if st is String:
		return String(st).to_upper()
	match int(st):
		1:  # BillingClient.PurchaseState.PURCHASED
			return "PURCHASED"
		2:  # BillingClient.PurchaseState.PENDING
			return "PENDING"
	return "UNKNOWN"

func _reconcile_purchase(p: Dictionary) -> void:
	var pid := String(p.get("product_id", ""))
	var token := String(p.get("purchase_token", ""))
	if pid == "" or token == "" or not COIN_PACKS.has(pid):
		return
	var state := _purchase_state(p)
	if state == "PENDING":
		if shop_hint != null:
			shop_hint.text = "Payment pending — check Play Store."
		return
	if state != "PURCHASED":
		return
	var rec: Dictionary = _pending_tokens.get(token, {})
	var rec_state := String(rec.get("state", ""))
	if rec_state == "":
		_pending_tokens[token] = {"product_id": pid, "state": "seen"}
		_save_game()
	if rec_state != "granted":
		_grant_pack_coins(pid)
		_pending_tokens[token] = {"product_id": pid, "state": "granted"}
		_save_game()
	_consume_token(token)

func _grant_pack_coins(pid: String) -> void:
	# Purchases credit coins directly — never through _add_coins, which is
	# blocked when buy_only is true.
	coins += int(COIN_PACKS[pid])
	_update_coin_labels()
	_save_game()
	if shop_rows != null:
		_refresh_shop()
	if shop_hint != null:
		shop_hint.text = "Coins added! Thank you!"

func _consume_token(token: String) -> void:
	if _billing == null:
		return
	_consuming_tokens[token] = true
	_billing.consume_purchase(token)

func _on_billing_consume_response(response: Dictionary) -> void:
	var code := int(response.get("response_code", _BILLING_OK))
	if code != _BILLING_OK:
		return  # record stays "granted"; the next re-query retries the consume
	var token := String(response.get("purchase_token", ""))
	if token != "" and _consuming_tokens.has(token):
		_consuming_tokens.erase(token)
		_pending_tokens.erase(token)
		_save_game()
	elif _consuming_tokens.size() == 1:
		# Response carried no token: only safe to clear when a single
		# consume was outstanding.
		var only: String = _consuming_tokens.keys()[0]
		_consuming_tokens.erase(only)
		_pending_tokens.erase(only)
		_save_game()

func _build_gate_and_packs(vbox: VBoxContainer) -> void:
	# Parent gate: a simple maths question. Prices and the Play purchase
	# sheet stay hidden until a grown-up answers it right.
	_gate_box = VBoxContainer.new()
	_gate_box.add_theme_constant_override("separation", 8)
	_gate_box.visible = false
	vbox.add_child(_gate_box)
	_gate_box.add_child(_big_label("Grown-ups only!", 30, Color(1, 0.85, 0.92)))
	_gate_question = _big_label("", 26, Color(1, 1, 1))
	_gate_box.add_child(_gate_question)
	var answers := HBoxContainer.new()
	answers.alignment = BoxContainer.ALIGNMENT_CENTER
	answers.add_theme_constant_override("separation", 12)
	_gate_box.add_child(answers)
	for i in range(3):
		var b := Button.new()
		b.custom_minimum_size = Vector2(120, 56)
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(_on_gate_answer.bind(b))
		answers.add_child(b)
		_gate_buttons.append(b)
	# Coin packs: prices come from the store, so the buttons start disabled
	# with "Loading…" until product details arrive.
	_packs_box = VBoxContainer.new()
	_packs_box.add_theme_constant_override("separation", 8)
	_packs_box.visible = false
	vbox.add_child(_packs_box)
	_packs_box.add_child(_big_label("Coin packs", 26, Color(1, 0.85, 0.3)))
	for pid in COIN_PACKS.keys():
		var pb := Button.new()
		pb.custom_minimum_size = Vector2(420, 56)
		pb.add_theme_font_size_override("font_size", 24)
		pb.text = "%d coins — Loading…" % COIN_PACKS[pid]
		pb.disabled = true
		pb.pressed.connect(_on_pack_buy.bind(pid))
		_packs_box.add_child(pb)
		_pack_buttons[pid] = pb

func _show_gate() -> void:
	_gate_box.visible = true
	_packs_box.visible = false
	_reshuffle_gate()

func _reshuffle_gate() -> void:
	var a := randi_range(11, 29)
	var b := randi_range(12, 28)
	_gate_answer = a + b
	_gate_question.text = "What is %d + %d?" % [a, b]
	var wrong1 := _gate_answer + randi_range(1, 9)
	var wrong2 := _gate_answer - randi_range(1, 9)
	while wrong2 <= 0 or wrong2 == wrong1:
		wrong2 = _gate_answer + randi_range(10, 19)
	var options: Array = [_gate_answer, wrong1, wrong2]
	options.shuffle()
	for i in range(3):
		_gate_buttons[i].text = str(options[i])
		_gate_buttons[i].set_meta("correct", int(options[i]) == _gate_answer)

func _on_gate_answer(btn: Button) -> void:
	if bool(btn.get_meta("correct", false)):
		_gate_box.visible = false
		_packs_box.visible = true
		_refresh_pack_buttons()
		if shop_hint != null:
			shop_hint.text = "Choose a coin pack!"
	else:
		_reshuffle_gate()
		if shop_hint != null:
			shop_hint.text = "Try again!"

func _refresh_pack_buttons() -> void:
	if _packs_box == null:
		return
	for pid in COIN_PACKS.keys():
		var b: Button = _pack_buttons.get(pid)
		if b == null:
			continue
		var price: String = _pack_prices.get(pid, "")
		if price == "":
			b.text = "%d coins — Loading…" % COIN_PACKS[pid]
			b.disabled = true
		else:
			b.text = "%d coins — %s" % [COIN_PACKS[pid], price]
			b.disabled = not _billing_ready

func _on_pack_buy(pid: String) -> void:
	if _billing == null or not _billing_ready:
		if shop_hint != null:
			shop_hint.text = "Connecting to the store… try again in a moment."
		if _billing != null:
			_billing.start_connection()
		return
	var result: Dictionary = _billing.purchase(pid)
	var code := int(result.get("response_code", _BILLING_OK))
	if code != _BILLING_OK and code != _BILLING_USER_CANCELED:
		if shop_hint != null:
			shop_hint.text = "Couldn't start the purchase. Try again."

func _on_buy_coins() -> void:
	if not buy_only:
		return
	if _billing == null:
		if shop_hint != null:
			shop_hint.text = "Coin packs are not available on this device."
		return
	_show_gate()

func _close_shop() -> void:
	shop_panel.visible = false
	start_overlay.visible = true

# ------------------------------------------------------------------ mini-games
# Learning mini-games on the start screen: ABC letters, counting stars and
# simple sums. Five rounds each; a right tap earns a star and a cheer, a
# wrong tap just says "Try again!". They NEVER grant coins — stars and
# praise only, in the web earn mode and the Android buy-only mode alike.
const MG_ROUNDS := 5
const MG_PRAISE := ["Great!", "Well done!", "Super!", "Yay!", "Bravo!"]
var mg_panel: Control
var mg_game_panel: Control
var mg_play_box: VBoxContainer
var mg_finish_box: VBoxContainer
var mg_prompt: Label
var mg_display: Label
var mg_progress: Label
var mg_feedback: Label
var mg_finish_stars: Label
var mg_choices: HBoxContainer
var mg_kind := ""
var mg_round := 0
var mg_stars := 0
var mg_correct_idx := -1
var mg_session := 0
var mg_abc_start := 0
var mg_finished := false

func _mg_stars_str(n: int) -> String:
	var s := ""
	for i in range(n):
		s += "★"
	return s

func _build_minigames(layer: CanvasLayer) -> void:
	# --- the picker panel: three big friendly buttons + Back
	mg_panel = Control.new()
	mg_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mg_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.10, 0.22, 0.30, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_panel.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	vbox.add_child(_big_label("Mini Games", 60, Color(1, 0.88, 0.55)))
	vbox.add_child(_big_label("Learn and play with Mimi!", 28, Color(1, 1, 1)))
	for entry in [["ABC Letters", "abc"], ["Numbers", "numbers"], ["Sums", "sums"]]:
		var b := Button.new()
		b.text = entry[0]
		b.custom_minimum_size = Vector2(300, 76)
		b.add_theme_font_size_override("font_size", 36)
		b.pressed.connect(_mg_start.bind(entry[1]))
		var bc := CenterContainer.new()
		bc.add_child(b)
		vbox.add_child(bc)
	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(200, 60)
	back_btn.add_theme_font_size_override("font_size", 28)
	back_btn.pressed.connect(_close_mini_games)
	var bkc := CenterContainer.new()
	bkc.add_child(back_btn)
	vbox.add_child(bkc)
	mg_panel.visible = false
	# --- the game panel: prompt, star display, three big choices, feedback
	mg_game_panel = Control.new()
	mg_game_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(mg_game_panel)
	var dim2 := ColorRect.new()
	dim2.color = Color(0.16, 0.14, 0.34, 0.55)
	dim2.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_game_panel.add_child(dim2)
	var quit_btn := Button.new()
	quit_btn.text = "Back"
	quit_btn.custom_minimum_size = Vector2(140, 56)
	quit_btn.add_theme_font_size_override("font_size", 26)
	quit_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	quit_btn.offset_left = 18
	quit_btn.offset_top = 14
	quit_btn.pressed.connect(_mg_quit_to_picker)
	mg_game_panel.add_child(quit_btn)
	var center2 := CenterContainer.new()
	center2.set_anchors_preset(Control.PRESET_FULL_RECT)
	mg_game_panel.add_child(center2)
	mg_play_box = VBoxContainer.new()
	mg_play_box.add_theme_constant_override("separation", 18)
	center2.add_child(mg_play_box)
	mg_progress = _big_label("★ 0/5", 36, Color(1, 0.85, 0.3))
	mg_play_box.add_child(mg_progress)
	mg_prompt = _big_label("", 60, Color(1, 1, 1))
	mg_play_box.add_child(mg_prompt)
	mg_display = _big_label("", 56, Color(1, 0.85, 0.3))
	mg_display.custom_minimum_size = Vector2(0, 76)
	mg_play_box.add_child(mg_display)
	mg_choices = HBoxContainer.new()
	mg_choices.alignment = BoxContainer.ALIGNMENT_CENTER
	mg_choices.add_theme_constant_override("separation", 18)
	mg_play_box.add_child(mg_choices)
	mg_feedback = _big_label("", 42, Color(0.75, 1.0, 0.80))
	mg_play_box.add_child(mg_feedback)
	# --- the finish box (inside the same panel): party + Play Again / Menu
	mg_finish_box = VBoxContainer.new()
	mg_finish_box.add_theme_constant_override("separation", 18)
	center2.add_child(mg_finish_box)
	mg_finish_box.add_child(_big_label("You did it!", 68, Color(1, 0.88, 0.55)))
	mg_finish_stars = _big_label("★ ★ ★ ★ ★", 56, Color(1, 0.85, 0.3))
	mg_finish_box.add_child(mg_finish_stars)
	var again_btn := Button.new()
	again_btn.text = "Play Again"
	again_btn.custom_minimum_size = Vector2(280, 76)
	again_btn.add_theme_font_size_override("font_size", 34)
	again_btn.pressed.connect(func() -> void: _mg_start(mg_kind))
	var ac := CenterContainer.new()
	ac.add_child(again_btn)
	mg_finish_box.add_child(ac)
	var menu_btn2 := Button.new()
	menu_btn2.text = "Menu"
	menu_btn2.custom_minimum_size = Vector2(220, 64)
	menu_btn2.add_theme_font_size_override("font_size", 30)
	menu_btn2.pressed.connect(_mg_quit_to_picker)
	var mc := CenterContainer.new()
	mc.add_child(menu_btn2)
	mg_finish_box.add_child(mc)
	mg_finish_box.visible = false
	mg_game_panel.visible = false

func _open_mini_games() -> void:
	start_overlay.visible = false
	if shop_panel != null:
		shop_panel.visible = false
	mg_panel.visible = true

func _close_mini_games() -> void:
	mg_session += 1  # cancel any pending round advance
	mg_panel.visible = false
	mg_game_panel.visible = false
	start_overlay.visible = true

func _mg_quit_to_picker() -> void:
	mg_session += 1
	mg_game_panel.visible = false
	mg_panel.visible = true

func _mg_start(kind: String) -> void:
	mg_kind = kind
	mg_round = 0
	mg_stars = 0
	mg_finished = false
	mg_session += 1
	if kind == "abc":
		mg_abc_start = randi() % 26
	mg_panel.visible = false
	mg_game_panel.visible = true
	mg_finish_box.visible = false
	mg_play_box.visible = true
	_mg_new_round()

func _mg_make_choices(correct: String, others: Array) -> void:
	var opts: Array = [[correct, true]]
	for o in others:
		opts.append([o, false])
	opts.shuffle()
	for c in mg_choices.get_children():
		c.queue_free()
	mg_correct_idx = -1
	for i in range(opts.size()):
		if opts[i][1]:
			mg_correct_idx = i
		var b := Button.new()
		b.text = opts[i][0]
		b.custom_minimum_size = Vector2(170, 150)
		b.add_theme_font_size_override("font_size", 64)
		b.pressed.connect(_mg_press_choice.bind(i))
		mg_choices.add_child(b)

func _mg_near_values(n: int, lo: int, hi: int) -> Array:
	var cands: Array = []
	for d in [1, -1, 2, -2, 3]:
		var v: int = n + d
		if v >= lo and v <= hi and v != n and not cands.has(v):
			cands.append(v)
	cands.shuffle()
	return [str(cands[0]), str(cands[1])]

func _mg_new_round() -> void:
	mg_feedback.text = ""
	mg_progress.text = "★ %d/%d" % [mg_stars, MG_ROUNDS]
	match mg_kind:
		"abc":
			var li: int = (mg_abc_start + mg_round) % 26
			var letter := String.chr(65 + li)
			mg_prompt.text = "Tap the letter %s!" % letter
			mg_display.text = ""
			var others: Array = []
			while others.size() < 2:
				var o := String.chr(65 + randi() % 26)
				if o != letter and not others.has(o):
					others.append(o)
			_mg_make_choices(letter, others)
		"numbers":
			var n: int = 1 + randi() % 10
			mg_prompt.text = "How many stars?"
			mg_display.text = _mg_stars_str(n)
			_mg_make_choices(str(n), _mg_near_values(n, 1, 12))
		"sums":
			var a: int = 1 + randi() % 4
			var b: int = 1 + randi() % 4
			mg_prompt.text = "%d + %d = ?" % [a, b]
			mg_display.text = _mg_stars_str(a) + "  +  " + _mg_stars_str(b)
			_mg_make_choices(str(a + b), _mg_near_values(a + b, 0, 12))

func _mg_press_choice(i: int) -> void:
	if mg_finished or not mg_game_panel.visible:
		return
	if i == mg_correct_idx:
		mg_stars += 1
		mg_progress.text = "★ %d/%d" % [mg_stars, MG_ROUNDS]
		mg_feedback.add_theme_color_override("font_color", Color(0.75, 1.0, 0.80))
		mg_feedback.text = MG_PRAISE[randi() % MG_PRAISE.size()]
		_play(chime_player)
		for c in mg_choices.get_children():
			(c as Button).disabled = true
		var s := mg_session
		await get_tree().create_timer(0.85).timeout
		if s != mg_session or not mg_game_panel.visible:
			return
		mg_round += 1
		if mg_round >= MG_ROUNDS:
			_mg_finish()
		else:
			_mg_new_round()
	else:
		mg_feedback.add_theme_color_override("font_color", Color(1.0, 0.80, 0.70))
		mg_feedback.text = "Try again!"
		_play(squeak_player)

func _mg_finish() -> void:
	mg_finished = true
	mg_play_box.visible = false
	var stars_line := ""
	for i in range(MG_ROUNDS):
		stars_line += "★ " if i < mg_stars else "☆ "
	mg_finish_stars.text = stars_line.strip_edges()
	mg_finish_box.visible = true
	_play(win_player)

func _set_world(idx: int) -> void:
	for i in world_roots.size():
		var on := i == idx
		(world_roots[i] as Node3D).visible = on
		_toggle_colliders(world_roots[i], on)

func _toggle_colliders(n: Node, on: bool) -> void:
	if n is PhysicsBody3D:
		(n as PhysicsBody3D).set_collision_layer_value(1, on)
		(n as PhysicsBody3D).set_collision_mask_value(1, on)
	for c in n.get_children():
		_toggle_colliders(c, on)
var level_label: Label
var win_title: Label
var win_sub: Label

func _diff() -> Dictionary:
	return DIFFS[difficulty]

# ------------------------------------------------------------------ helpers

func _mat(color: Color, roughness: float = 0.85, emission: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

var _tex_cache: Dictionary = {}

func _tex_mat(path: String, repeat_scale: float = 1.0, tint: Color = Color(1, 1, 1), roughness: float = 0.8) -> StandardMaterial3D:
	var key := path + "|" + str(repeat_scale) + "|" + str(tint)
	if _tex_cache.has(key):
		return _tex_cache[key]
	var m := StandardMaterial3D.new()
	var tex: Texture2D = load(path)
	if tex != null:
		m.albedo_texture = tex
	m.albedo_color = tint
	m.roughness = roughness
	if repeat_scale != 1.0:
		m.texture_repeat = 1  # TEXTURE_REPEAT_ENABLED
		m.uv1_scale = Vector3(repeat_scale, repeat_scale, 1.0)
	_tex_cache[key] = m
	return m

func _box(pos: Vector3, size: Vector3, color: Color, collide: bool = true, parent: Node = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		shape.shape = bs
		body.add_child(shape)
		body.position = pos
		parent.add_child(body)
	return mi

func _sphere(parent: Node, pos: Vector3, radius: float, color: Color, scale_: Vector3 = Vector3.ONE, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 24
	sm.rings = 12
	mi.mesh = sm
	mi.material_override = _mat(color, 0.85, emission)
	mi.position = pos
	mi.scale = scale_
	parent.add_child(mi)
	return mi

func _cylinder(parent: Node, pos: Vector3, top_r: float, bottom_r: float, height: float, color: Color, emission: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bottom_r
	cm.height = height
	cm.radial_segments = 20
	mi.mesh = cm
	mi.material_override = _mat(color, 0.85, emission)
	mi.position = pos
	parent.add_child(mi)
	return mi

# ------------------------------------------------------------------ setup

func _ready() -> void:
	_load_game()
	_build_lights_and_sky()
	# The house is built the classic way (straight into the scene), then all
	# of its pieces are gathered under one root so worlds can be swapped.
	var marker := get_child_count()
	_build_room()
	var movers: Array = []
	for i in range(marker, get_child_count()):
		movers.append(get_child(i))
	var house_root := Node3D.new()
	house_root.name = "HouseWorld"
	add_child(house_root)
	for c in movers:
		remove_child(c)
		house_root.add_child(c)
	world_roots.append(house_root)
	var school_root := Node3D.new()
	school_root.name = "SchoolWorld"
	add_child(school_root)
	_build_school(school_root)
	world_roots.append(school_root)
	var gym_root := Node3D.new()
	gym_root.name = "GymWorld"
	add_child(gym_root)
	_build_gym(gym_root)
	world_roots.append(gym_root)
	var beach_root := Node3D.new()
	beach_root.name = "BeachWorld"
	add_child(beach_root)
	_build_beach(beach_root)
	world_roots.append(beach_root)
	_set_world(0)
	_build_mimi()
	_build_accessories()
	_build_toys()
	_build_coco()
	_build_lulu()
	_build_mice()
	_build_effects()
	_build_audio()
	_build_hud()
	camera.global_position = mimi.global_position + Vector3(0, 4.9, 5.7)
	camera.look_at(mimi.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	_update_coin_labels()
	_init_billing()

func _input(event: InputEvent) -> void:
	# Roblox-style camera orbit: right-mouse drag on desktop, one-finger drag
	# on empty screen space on touch devices, or the Q / E keys.
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		cam_yaw -= event.relative.x * 0.008
	elif event is InputEventScreenTouch:
		if event.pressed:
			_cam_touch_index = event.index
			_cam_touch_ok = _is_free_touch(event.position)
		elif event.index == _cam_touch_index:
			_cam_touch_index = -1
	elif event is InputEventScreenDrag and event.index == _cam_touch_index and _cam_touch_ok:
		cam_yaw -= event.relative.x * 0.008
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			cam_yaw += 0.35
		elif event.keycode == KEY_E:
			cam_yaw -= 0.35
		elif event.keycode == KEY_ESCAPE and game_started:
			_back_to_menu()

func _is_free_touch(pos: Vector2) -> bool:
	# Drags that start on the joystick (bottom-left) or the jump button
	# (bottom-right) drive those controls instead of the camera.
	var vs := get_viewport().get_visible_rect().size
	if pos.x < 300.0 and pos.y > vs.y - 300.0:
		return false
	if pos.x > vs.x - 260.0 and pos.y > vs.y - 260.0:
		return false
	return true

func _process(delta: float) -> void:
	time += delta
	# Mission countdown: find all the toys before the 40 seconds run out
	if game_started and not game_won and not game_over:
		time_left -= delta
		if time_left <= 0.0:
			time_left = 0.0
			_update_timer_label()
			_on_time_up()
		else:
			_update_timer_label()
	# Camera: smooth follow, orbiting Mimi at the player's chosen angle
	var cam_offset := Vector3(0, 4.9, 5.7).rotated(Vector3.UP, cam_yaw)
	var target: Vector3 = mimi.global_position + cam_offset
	camera.global_position = camera.global_position.lerp(target, 1.0 - pow(0.001, delta))
	camera.look_at(mimi.global_position + Vector3(0, 0.4, 0), Vector3.UP)
	mimi.camera_yaw = cam_yaw
	# Toys bob and spin gently
	for toy in toys:
		if not toy.taken:
			toy.pivot.rotation.y += delta * 1.4
			toy.root.position.y = toy.base_y + sin(time * 2.0 + toy.phase) * 0.05
	# Coco wags his tail while he waits/celebrates
	if coco.visible and coco_tail != null:
		coco_tail.rotation.y = sin(time * 10.0) * 0.4
	# The garden butterfly flutters around the flowers
	if butterfly != null:
		butterfly.position = Vector3(-2.0 + sin(time * 0.45) * 3.4, 1.25 + sin(time * 1.6) * 0.22, 11.0 + cos(time * 0.32) * 2.0)
		var flap := 0.35 + sin(time * 16.0) * 0.55
		if butterfly_wing_l != null:
			butterfly_wing_l.rotation.z = flap
			butterfly_wing_r.rotation.z = -flap
	# Lulu bobs gently behind the oak tree; walking up to her triggers her party
	if lulu != null:
		lulu_visual.position.y = sin(time * 2.2) * 0.02
		if game_started and not lulu_found:
			var dl: Vector3 = mimi.global_position - lulu.global_position
			dl.y = 0.0
			if dl.length() < 1.7:
				_found_lulu()
	# The mice scurry: bobbing bodies and swaying tails while they move
	for m in mice:
		if not m.active:
			continue
		var mbody: CharacterBody3D = m.body
		var spd := Vector2(mbody.velocity.x, mbody.velocity.z).length()
		if spd > 0.3:
			(m.visual as Node3D).position.y = abs(sin(time * 14.0)) * 0.03
			(m.tail as Node3D).rotation.y = sin(time * 10.0) * 0.4
		# A stolen toy rides on his head while Coco chases him
		if m.carry != null:
			(m.carry.root as Node3D).global_position = mbody.global_position + Vector3(0, 0.95, 0)
		# If he bumps into Mimi, he snatches her latest toy
		if mouse_active and game_started and not game_won and not game_over and m.carry == null and m.cooldown <= 0.0 and collected > 0:
			var dm: Vector3 = mimi.global_position - mbody.global_position
			dm.y = 0.0
			if dm.length() < 0.8:
				_mouse_steals(m)
	_update_coco(delta)

func _build_lights_and_sky() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.42, 0.69, 0.92)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 1.0)
	env.ambient_light_energy = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.93
	env.adjustment_contrast = 1.16
	env.adjustment_saturation = 1.26
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -30, 0)
	sun.light_color = Color(1, 0.94, 0.84)
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 55.0
	add_child(camera)

func _build_mimi() -> void:
	mimi = MIMI_SCRIPT.new()
	mimi.position = Vector3(0, 0.05, 2.6)
	mimi.scale = Vector3.ONE * 1.15
	add_child(mimi)

# ------------------------------------------------------------------ the room

func _build_room() -> void:
	var wood := Color(0.72, 0.48, 0.30)
	var wood_light := Color(0.85, 0.64, 0.42)
	var wall_col := Color(0.87, 0.72, 0.55)
	# Floor + rug
	var living_floor := _box(Vector3(0, -0.1, 0), Vector3(16, 0.2, 12), wood)
	living_floor.material_override = _tex_mat("res://textures/wood.png", 2.0, Color(0.80, 0.70, 0.60))
	var rug_outer := _cylinder(self, Vector3(0, 0.015, 0.6), 2.3, 2.3, 0.03, Color(0.93, 0.50, 0.62), 0.0)
	rug_outer.material_override = _tex_mat("res://textures/rug.png")
	_cylinder(self, Vector3(0, 0.02, 0.6), 1.6, 1.6, 0.03, Color(0.97, 0.68, 0.74), 0.0)
	# Back wall only: the sides are the room dividers (with real open
	# doorways) built by _build_house_shell — full side walls here used to
	# seal the kitchen and bedroom shut behind the door frames.
	_box(Vector3(0, 2.25, -6), Vector3(16, 4.5, 0.3), wall_col)
	# Window on the back wall, with curtains
	_box(Vector3(-4.6, 2.7, -5.82), Vector3(2.6, 1.9, 0.06), Color(0.75, 0.90, 1.0), false)
	_box(Vector3(-4.6, 3.68, -5.80), Vector3(2.8, 0.14, 0.08), Color(1, 1, 1), false)
	_box(Vector3(-4.6, 1.72, -5.80), Vector3(2.8, 0.14, 0.08), Color(1, 1, 1), false)
	_box(Vector3(-5.95, 2.7, -5.80), Vector3(0.14, 2.1, 0.08), Color(1, 1, 1), false)
	_box(Vector3(-3.25, 2.7, -5.80), Vector3(0.14, 2.1, 0.08), Color(1, 1, 1), false)
	_box(Vector3(-6.25, 2.7, -5.78), Vector3(0.5, 2.2, 0.06), Color(1, 0.62, 0.75), false)
	_box(Vector3(-2.95, 2.7, -5.78), Vector3(0.5, 2.2, 0.06), Color(1, 0.62, 0.75), false)
	# THE shelf (la repisa!) with plant, books and a bunny plush
	var shelf := _box(Vector3(3.4, 2.15, -5.55), Vector3(4.2, 0.14, 0.85), wood_light)
	shelf.material_override = _tex_mat("res://textures/wood.png")
	# The famous teacup + a little framed picture on the shelf
	_cylinder(self, Vector3(2.62, 2.30, -5.45), 0.055, 0.045, 0.11, Color(1, 1, 1), 0.0)
	_box(Vector3(4.02, 2.44, -5.62), Vector3(0.36, 0.44, 0.04), Color(0.55, 0.38, 0.22), false)
	_box(Vector3(4.02, 2.44, -5.59), Vector3(0.27, 0.35, 0.02), Color(0.65, 0.85, 0.95), false)
	_box(Vector3(1.7, 1.92, -5.55), Vector3(0.16, 0.34, 0.6), wood_light, false)
	_box(Vector3(5.1, 1.92, -5.55), Vector3(0.16, 0.34, 0.6), wood_light, false)
	_cylinder(self, Vector3(2.0, 2.36, -5.55), 0.13, 0.17, 0.28, Color(0.85, 0.45, 0.30), 0.0)
	_sphere(self, Vector3(2.0, 2.66, -5.55), 0.24, Color(0.45, 0.75, 0.40))
	_box(Vector3(3.15, 2.36, -5.55), Vector3(0.16, 0.28, 0.5), Color(0.55, 0.75, 0.95), false)
	_box(Vector3(3.35, 2.36, -5.55), Vector3(0.16, 0.24, 0.46), Color(0.98, 0.70, 0.45), false)
	_box(Vector3(3.55, 2.36, -5.55), Vector3(0.16, 0.30, 0.52), Color(0.65, 0.85, 0.60), false)
	_build_bunny(Vector3(4.6, 2.22, -5.55))
	# Sofa + coffee table: real Kenney Furniture Kit models (CC0)
	_model("res://assets/furniture/loungeSofa.glb", Vector3(-3.5, 0, -4.60), 2.35)
	_model_collider(Vector3(-3.5, 0.5, -4.60), Vector3(2.35, 1.0, 1.0))
	var mpillow1 := _model("res://assets/furniture/pillow.glb", Vector3(-4.55, 0.52, -4.85), 2.2, 0.3)
	mpillow1.rotation.x = -0.35
	mpillow1.rotation.z = 0.22
	var mpillow2 := _model("res://assets/furniture/pillow.glb", Vector3(-2.45, 0.52, -4.85), 2.2, -0.3)
	mpillow2.rotation.x = -0.35
	mpillow2.rotation.z = -0.22
	_model("res://assets/furniture/tableCoffee.glb", Vector3(-3.5, 0, -3.05), 2.27)
	_model_collider(Vector3(-3.5, 0.26, -3.05), Vector3(1.5, 0.52, 0.9))
	# A storybook on the coffee table
	_box(Vector3(-3.8, 0.545, -3.0), Vector3(0.52, 0.05, 0.38), Color(0.30, 0.65, 0.70), false)
	_box(Vector3(-3.8, 0.575, -3.0), Vector3(0.46, 0.02, 0.32), Color(1, 0.98, 0.94), false)
	# Armchair angled toward the rug + a TV on the divider wall
	_model("res://assets/furniture/loungeChair.glb", Vector3(6.6, 0, -2.7), 2.24, -0.7)  # kept clear of the kitchen doorway
	_model_collider(Vector3(6.7, 0.5, -1.6), Vector3(1.1, 1.0, 1.0))
	_model("res://assets/furniture/televisionModern.glb", Vector3(7.80, 1.05, -3.6), 2.0, -PI / 2.0)
	_cylinder(self, Vector3(5.9, 0.30, -4.7), 0.09, 0.13, 0.58, wood, 0.0)
	_cylinder(self, Vector3(5.9, 0.60, -4.7), 0.48, 0.48, 0.06, wood_light, 0.0)
	var side_body := StaticBody3D.new()
	var side_shape := CollisionShape3D.new()
	var side_box := BoxShape3D.new()
	side_box.size = Vector3(0.9, 0.63, 0.9)
	side_shape.shape = side_box
	side_body.add_child(side_shape)
	side_body.position = Vector3(5.9, 0.315, -4.7)
	add_child(side_body)
	# Plants in the corners (Kenney potted plants)
	_model("res://assets/furniture/pottedPlant.glb", Vector3(-7.0, 0, -5.1), 1.75)
	_model_collider(Vector3(-7.0, 0.45, -5.1), Vector3(0.55, 0.9, 0.55))
	_model("res://assets/furniture/pottedPlant.glb", Vector3(7.1, 0, -5.2), 1.5)
	_model_collider(Vector3(7.1, 0.4, -5.2), Vector3(0.5, 0.8, 0.5))
	_model("res://assets/furniture/pottedPlant.glb", Vector3(-7.2, 0, 3.8), 1.35)
	_model_collider(Vector3(-7.2, 0.35, 3.8), Vector3(0.45, 0.7, 0.45))
	# Floor cushions + a basket + a stack of books
	_sphere(self, Vector3(2.8, 0.10, 3.4), 0.42, Color(0.60, 0.80, 0.95), Vector3(1, 0.42, 1))
	_sphere(self, Vector3(3.7, 0.10, 2.9), 0.38, Color(0.98, 0.80, 0.45), Vector3(1, 0.42, 1))
	_cylinder(self, Vector3(-6.2, 0.22, 1.8), 0.42, 0.34, 0.44, Color(0.85, 0.65, 0.42), 0.0)
	_box(Vector3(-6.0, 0.10, -1.8), Vector3(0.55, 0.12, 0.4), Color(0.55, 0.75, 0.95), false)
	_box(Vector3(-6.0, 0.21, -1.8), Vector3(0.5, 0.10, 0.36), Color(0.98, 0.70, 0.45), false)
	# Floor lamp by the sofa (Kenney lamp + warm glow ball) + picture frames
	_model("res://assets/furniture/lampRoundFloor.glb", Vector3(-6.4, 0, -3.6), 1.95)
	_model_collider(Vector3(-6.4, 0.6, -3.6), Vector3(0.36, 1.2, 0.36))
	_sphere(self, Vector3(-6.4, 1.48, -3.6), 0.09, Color(1, 0.92, 0.66), Vector3.ONE, 1.1)
	_box(Vector3(-0.9, 2.75, -5.83), Vector3(1.15, 0.9, 0.05), Color(0.55, 0.38, 0.22), false)
	_box(Vector3(-0.9, 2.75, -5.80), Vector3(0.95, 0.7, 0.03), Color(0.98, 0.70, 0.45), false)
	_box(Vector3(0.75, 2.6, -5.83), Vector3(0.8, 0.65, 0.05), Color(0.55, 0.38, 0.22), false)
	_box(Vector3(0.75, 2.6, -5.80), Vector3(0.62, 0.47, 0.03), Color(0.60, 0.80, 0.95), false)
	# The rest of the house: kitchen (right), bedroom (left), garden (front)
	_build_house_shell()
	_build_kitchen()
	_build_bedroom()
	_build_garden()

func _build_bunny(pos: Vector3) -> void:
	# Little lavender bunny plush sitting on the shelf (a Lulu cameo)
	var b := Node3D.new()
	b.position = pos
	add_child(b)
	var lav := Color(0.78, 0.72, 0.92)
	_sphere(b, Vector3(0, 0.14, 0), 0.13, lav, Vector3(1, 1.1, 0.9))
	_sphere(b, Vector3(0, 0.33, 0), 0.105, lav)
	for side in [-1.0, 1.0]:
		_sphere(b, Vector3(0.055 * side, 0.52, 0), 0.045, lav, Vector3(0.75, 2.1, 0.5))
		_sphere(b, Vector3(0.05 * side, 0.33, 0.085), 0.020, Color(0.15, 0.12, 0.14))

func _build_plant(pos: Vector3, s: float) -> void:
	_cylinder(self, pos + Vector3(0, 0.22 * s, 0), 0.30 * s, 0.24 * s, 0.44 * s, Color(0.85, 0.45, 0.30), 0.0)
	_sphere(self, pos + Vector3(0, 0.62 * s, 0), 0.34 * s, Color(0.38, 0.68, 0.34))
	_sphere(self, pos + Vector3(0.22 * s, 0.50 * s, 0.10 * s), 0.24 * s, Color(0.45, 0.74, 0.38))
	_sphere(self, pos + Vector3(-0.20 * s, 0.52 * s, -0.08 * s), 0.22 * s, Color(0.32, 0.62, 0.30))
	_sphere(self, pos + Vector3(0.02 * s, 0.82 * s, 0.05 * s), 0.20 * s, Color(0.48, 0.78, 0.42))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.32 * s
	cs.height = 0.9 * s
	shape.shape = cs
	body.add_child(shape)
	body.position = pos + Vector3(0, 0.45 * s, 0)
	add_child(body)

# ------------------------------------------------------------------ toys & mission

func _make_toy(homes: Array, kind: String, ring_ys: Array, imp_only := false) -> void:
	var pos: Vector3 = homes[0]
	var ring_y: float = ring_ys[0]
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var pivot := Node3D.new()
	root.add_child(pivot)
	# Golden glow ring on the surface under the toy so little kids spot it
	var ring := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.20
	tor.outer_radius = 0.30
	tor.rings = 24
	tor.ring_segments = 8
	ring.mesh = tor
	ring.material_override = _mat(Color(1, 0.82, 0.30), 0.5, 0.7)
	ring.position = Vector3(pos.x, ring_y, pos.z)
	add_child(ring)
	match kind:
		"ball":
			_sphere(pivot, Vector3.ZERO, 0.17, Color(0.95, 0.30, 0.30))
			_sphere(pivot, Vector3(0, 0.10, 0.10), 0.07, Color(1, 1, 1))
		"fish":
			_sphere(pivot, Vector3.ZERO, 0.16, Color(1, 0.60, 0.25), Vector3(1.35, 0.85, 0.55))
			var tail := _cone_at(pivot, Vector3(-0.24, 0, 0), 0.10, 0.16, Color(1, 0.50, 0.20))
			tail.rotation.z = -PI / 2.0
			_sphere(pivot, Vector3(0.10, 0.05, 0.085), 0.025, Color(0.15, 0.12, 0.14))
			_sphere(pivot, Vector3(0.10, 0.05, -0.085), 0.025, Color(0.15, 0.12, 0.14))
		"mouse":
			_sphere(pivot, Vector3.ZERO, 0.14, Color(0.65, 0.65, 0.72), Vector3(1.25, 0.85, 0.85))
			_sphere(pivot, Vector3(-0.05, 0.13, 0.07), 0.05, Color(0.65, 0.65, 0.72))
			_sphere(pivot, Vector3(-0.05, 0.13, -0.07), 0.05, Color(0.65, 0.65, 0.72))
			_sphere(pivot, Vector3(0.17, 0.0, 0), 0.03, Color(1, 0.55, 0.65))
		"wand":
			var stick := _cylinder(pivot, Vector3(0, -0.05, 0), 0.022, 0.022, 0.42, Color(0.70, 0.45, 0.25), 0.0)
			stick.rotation.z = 0.5
			var star_pos := Vector3(0.10, 0.16, 0)
			_sphere(pivot, star_pos, 0.075, Color(1, 0.80, 0.25), Vector3.ONE, 0.8)
			# Four sparkle spikes: up, down, left, right
			_cone_at(pivot, star_pos, 0.035, 0.34, Color(1, 0.80, 0.25))
			var down := _cone_at(pivot, star_pos, 0.035, 0.34, Color(1, 0.80, 0.25))
			down.rotation.x = PI
			var right := _cone_at(pivot, star_pos, 0.035, 0.34, Color(1, 0.80, 0.25))
			right.rotation.z = -PI / 2.0
			var left := _cone_at(pivot, star_pos, 0.035, 0.34, Color(1, 0.80, 0.25))
			left.rotation.z = PI / 2.0
		"duck":
			_sphere(pivot, Vector3.ZERO, 0.15, Color(1, 0.85, 0.30), Vector3(1.15, 0.9, 0.9))
			_sphere(pivot, Vector3(0.10, 0.14, 0), 0.095, Color(1, 0.85, 0.30))
			var beak := _cone_at(pivot, Vector3(0.20, 0.12, 0), 0.045, 0.10, Color(1, 0.55, 0.15))
			beak.rotation.z = -PI / 2.0
			_sphere(pivot, Vector3(0.13, 0.18, 0.055), 0.018, Color(0.15, 0.12, 0.14))
			_sphere(pivot, Vector3(0.13, 0.18, -0.055), 0.018, Color(0.15, 0.12, 0.14))
		"teddy":
			# Osito modelado en Blender (tools/blender/teddy/): un solo GLB con
			# orejas, hocico, moño rosa y pancita; base en el piso, escala del juego.
			_model("res://assets/toys/teddy-blender.glb",
				Vector3(0, ring_y - pos.y - 0.02, 0), 0.9, 0.0, Color(1, 1, 1), pivot)
		"boat":
			_box(Vector3(0, -0.04, 0), Vector3(0.42, 0.12, 0.20), Color(0.90, 0.35, 0.30), false, pivot)
			_cylinder(pivot, Vector3(0, 0.12, 0), 0.018, 0.018, 0.34, Color(0.60, 0.42, 0.26), 0.0)
			_sphere(pivot, Vector3(0.02, 0.20, 0), 0.16, Color(1, 1, 1), Vector3(0.25, 1.1, 1.4))
			_sphere(pivot, Vector3(0, 0.02, 0), 0.05, Color(1, 0.80, 0.25), Vector3.ONE, 0.6)
		"beachball":
			_sphere(pivot, Vector3.ZERO, 0.23, Color(0.98, 0.45, 0.45))
			var band_cols := [Color(1, 1, 1), Color(0.40, 0.65, 0.98), Color(1, 0.82, 0.30)]
			var band_rots := [Vector3.ZERO, Vector3(1.1, 0, 0.4), Vector3(0.4, 0, 1.1)]
			for i in range(3):
				var band := MeshInstance3D.new()
				var bt := TorusMesh.new()
				bt.inner_radius = 0.205
				bt.outer_radius = 0.245
				bt.rings = 24
				bt.ring_segments = 8
				band.mesh = bt
				band.material_override = _mat(band_cols[i])
				band.rotation = band_rots[i]
				pivot.add_child(band)
			_sphere(pivot, Vector3(0, 0.20, 0), 0.06, Color(1, 1, 1), Vector3(1, 0.6, 1))
		"star":
			_sphere(pivot, Vector3.ZERO, 0.11, Color(1, 0.80, 0.25), Vector3.ONE, 0.8)
			_cone_at(pivot, Vector3.ZERO, 0.05, 0.46, Color(1, 0.80, 0.25))
			var sdown := _cone_at(pivot, Vector3.ZERO, 0.05, 0.46, Color(1, 0.80, 0.25))
			sdown.rotation.x = PI
			var sright := _cone_at(pivot, Vector3.ZERO, 0.05, 0.46, Color(1, 0.80, 0.25))
			sright.rotation.z = -PI / 2.0
			var sleft := _cone_at(pivot, Vector3.ZERO, 0.05, 0.46, Color(1, 0.80, 0.25))
			sleft.rotation.z = PI / 2.0
		"car":
			_box(Vector3(0, 0.02, 0), Vector3(0.48, 0.14, 0.24), Color(0.92, 0.30, 0.28), false, pivot)
			_box(Vector3(-0.02, 0.14, 0), Vector3(0.24, 0.12, 0.22), Color(0.45, 0.70, 0.95), false, pivot)
			for wx in [-0.16, 0.16]:
				for wz in [-0.12, 0.12]:
					var wheel := _cylinder(pivot, Vector3(wx, -0.06, wz), 0.055, 0.055, 0.04, Color(0.15, 0.13, 0.15), 0.0)
					wheel.rotation.x = PI / 2.0
		"apple":
			_sphere(pivot, Vector3.ZERO, 0.15, Color(0.90, 0.22, 0.22))
			_cylinder(pivot, Vector3(0, 0.17, 0), 0.016, 0.02, 0.10, Color(0.45, 0.30, 0.18), 0.0)
			_sphere(pivot, Vector3(0.075, 0.20, 0), 0.055, Color(0.40, 0.75, 0.35), Vector3(1.4, 0.30, 0.7))
		"cupcake":
			var wrap := _cone_at(pivot, Vector3(0, -0.05, 0), 0.13, 0.16, Color(0.85, 0.55, 0.35))
			wrap.rotation.x = PI
			_sphere(pivot, Vector3(0, 0.08, 0), 0.14, Color(1, 0.62, 0.78), Vector3(1, 0.75, 1))
			_sphere(pivot, Vector3(0, 0.21, 0), 0.05, Color(0.92, 0.20, 0.25))
		"rocket":
			_cylinder(pivot, Vector3(0, 0.05, 0), 0.09, 0.09, 0.34, Color(0.95, 0.95, 0.97), 0.0)
			_cone_at(pivot, Vector3(0, 0.31, 0), 0.09, 0.18, Color(0.92, 0.30, 0.28))
			_sphere(pivot, Vector3(0, 0.10, 0.07), 0.042, Color(0.55, 0.85, 1.0), Vector3.ONE, 0.4)
			for fx in [-0.11, 0.11]:
				var fin := _box(Vector3(fx, -0.10, 0), Vector3(0.03, 0.17, 0.10), Color(0.92, 0.30, 0.28), false, pivot)
				fin.rotation.z = -0.3 * sign(fx)
			var finb := _box(Vector3(0, -0.10, -0.11), Vector3(0.10, 0.17, 0.03), Color(0.92, 0.30, 0.28), false, pivot)
			finb.rotation.x = 0.3
		"gem":
			_cone_at(pivot, Vector3(0, 0.02, 0), 0.13, 0.22, Color(0.45, 0.90, 0.95))
			var gdown := _cone_at(pivot, Vector3(0, -0.02, 0), 0.13, 0.22, Color(0.35, 0.80, 0.90))
			gdown.rotation.x = PI
			_sphere(pivot, Vector3.ZERO, 0.05, Color(0.75, 0.98, 1.0), Vector3.ONE, 0.6)
		"balloon":
			_sphere(pivot, Vector3(0, 0.10, 0), 0.17, Color(0.95, 0.35, 0.75), Vector3(1, 1.18, 1))
			var knot := _cone_at(pivot, Vector3(0, -0.11, 0), 0.035, 0.06, Color(0.85, 0.25, 0.60))
			knot.rotation.x = PI
			_cylinder(pivot, Vector3(0, -0.28, 0), 0.004, 0.004, 0.28, Color(0.60, 0.58, 0.60), 0.0)
	var area := Area3D.new()
	var shape := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = 0.55
	shape.shape = ss
	area.add_child(shape)
	root.add_child(area)
	var idx := toys.size()
	area.body_entered.connect(_on_toy_body_entered.bind(idx))
	toys.append({"root": root, "pivot": pivot, "base_y": pos.y, "phase": randf() * TAU, "taken": false, "area": area, "ring": ring, "home": pos, "ring_home": ring.position, "stolen": false, "imp_only": imp_only, "active": true, "homes": homes, "ring_ys": ring_ys})

var _model_cache: Dictionary = {}
var _tinted_paths: Dictionary = {}

func _scene_aabb(n: Node, gt: Transform3D, acc: Dictionary) -> void:
	var local: Transform3D = gt * (n as Node3D).transform if n is Node3D else gt
	if n is MeshInstance3D:
		var world: AABB = local * n.get_aabb()
		if acc.count > 0:
			acc.box = acc.box.merge(world)
		else:
			acc.box = world
		acc.count += 1
	for c in n.get_children():
		_scene_aabb(c, local, acc)

func _tint_tree(n: Node, tint: Color) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mesh: Mesh = n.mesh
		for s in mesh.get_surface_count():
			var m: Material = mesh.surface_get_material(s)
			if m is StandardMaterial3D:
				var dup := m.duplicate() as StandardMaterial3D
				var a: Color = dup.albedo_color
				dup.albedo_color = Color(a.r * tint.r, a.g * tint.g, a.b * tint.b, a.a)
				mesh.surface_set_material(s, dup)
	for c in n.get_children():
		_tint_tree(c, tint)

func _model(path: String, pos: Vector3, scl: float, rot_y: float = 0.0, tint: Color = Color(1, 1, 1), parent: Node = null) -> Node3D:
	# Instance a downloaded Kenney CC0 model, recentered so its origin sits at
	# the center of its footprint on the floor (the raw GLB origins are offset).
	if not _model_cache.has(path):
		_model_cache[path] = load(path) as PackedScene
	var inst := (_model_cache[path] as PackedScene).instantiate() as Node3D
	if tint != Color(1, 1, 1) and not _tinted_paths.has(path):
		_tinted_paths[path] = true
		_tint_tree(inst, tint)
	var acc := {"box": AABB(), "count": 0}
	_scene_aabb(inst, Transform3D.IDENTITY, acc)
	var c: Vector3 = acc.box.get_center()
	inst.position = Vector3(-c.x, -acc.box.position.y, -c.z)
	var wrap := Node3D.new()
	wrap.add_child(inst)
	wrap.position = pos
	wrap.scale = Vector3.ONE * scl
	wrap.rotation.y = rot_y
	(parent if parent != null else self).add_child(wrap)
	return wrap

func _model_collider(pos: Vector3, size: Vector3, parent: Node = null) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.position = pos
	(parent if parent != null else self).add_child(body)

func _cone_at(parent: Node, pos: Vector3, base_radius: float, height: float, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = base_radius
	cm.height = height
	cm.radial_segments = 14
	mi.mesh = cm
	mi.material_override = _mat(color)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _build_toys() -> void:
	# Each toy has one hiding spot per world: [the House, the School, the Gym, the Beach]
	_make_toy([Vector3(4.6, 0.18, 1.8), Vector3(-15.5, 0.82, -2.6), Vector3(0, 0.24, 0), Vector3(-3.8, 0.18, 4.6)], "ball", [0.04, 0.78, 0.04, 0.04])
	_make_toy([Vector3(-3.5, 0.66, -3.05), Vector3(13.5, 0.80, 0.5), Vector3(-6.0, 0.55, -4.75), Vector3(10.55, 1.33, 7.6)], "fish", [0.54, 0.74, 0.42, 1.22])
	_make_toy([Vector3(-6.55, 0.16, -4.35), Vector3(0.5, 0.16, -4.6), Vector3(-17.5, 0.16, -1.5), Vector3(4.0, 0.16, -3.4)], "mouse", [0.04, 0.04, 0.04, 0.04])
	_make_toy([Vector3(-4.45, 0.60, -4.5), Vector3(-18.3, 0.85, -4.4), Vector3(19.35, 0.98, -2.0), Vector3(-6.5, 1.38, 3.0)], "wand", [0.50, 0.80, 0.93, 1.27])
	_make_toy([Vector3(5.9, 0.80, -4.7), Vector3(-12.0, 0.30, 11.0), Vector3(8.5, 0.22, 3.8), Vector3(-10.2, 0.18, 5.0)], "duck", [0.66, 0.22, 0.16, 0.04])
	_make_toy([Vector3(-16.8, 0.74, -4.05), Vector3(17.8, 0.95, -5.2), Vector3(3.0, 0.95, -5.45), Vector3(3.1, 0.16, 1.6)], "teddy", [0.60, 0.90, 0.82, 0.04])
	_make_toy([Vector3(16.0, 0.80, 1.5), Vector3(14.2, 0.85, 9.2), Vector3(18.8, 0.30, 5.3), Vector3(5.0, 0.14, 13.3)], "boat", [0.72, 0.80, 0.04, 0.04])
	_make_toy([Vector3(-3.2, 0.25, 10.6), Vector3(2.0, 0.25, 12.5), Vector3(-8.0, 0.25, 10.0), Vector3(6.5, 0.25, 10.5)], "beachball", [0.04, 0.04, 0.04, 0.04])
	# Seven more, only in play on Impossible (15 toys in total)
	_make_toy([Vector3(-8.62, 0.88, -3.4), Vector3(-19.0, 0.35, 3.5), Vector3(-18.9, 1.02, 3.6), Vector3(11.5, 1.33, 7.9)], "star", [0.80, 0.04, 0.94, 1.22], true)
	_make_toy([Vector3(6.3, 0.16, 0.9), Vector3(5.5, 0.16, 2.5), Vector3(12.0, 0.16, 5.6), Vector3(-16.0, 0.16, -2.0)], "car", [0.04, 0.04, 0.04, 0.04], true)
	_make_toy([Vector3(-4.6, 0.18, 14.2), Vector3(18.5, 0.80, -2.5), Vector3(10.0, 0.55, -4.75), Vector3(17.6, 0.18, 7.3)], "apple", [0.04, 0.74, 0.42, 0.04], true)
	_make_toy([Vector3(-13.9, 0.72, -5.2), Vector3(-11.5, 0.82, 0.8), Vector3(-17.5, 0.68, 4.6), Vector3(-1.5, 0.19, 8.2)], "cupcake", [0.64, 0.78, 0.58, 0.07], true)
	_make_toy([Vector3(15.6, 0.30, -3.6), Vector3(0.8, 0.30, 9.3), Vector3(16.0, 0.30, 10.0), Vector3(0.5, 0.30, -4.8)], "rocket", [0.04, 0.04, 0.04, 0.04], true)
	_make_toy([Vector3(11.6, 0.22, 13.1), Vector3(-3.3, 0.55, 10.5), Vector3(17.5, 0.22, 0.8), Vector3(-4.0, 0.16, 13.4)], "gem", [0.04, 0.50, 0.04, 0.02], true)
	_make_toy([Vector3(7.2, 0.95, -5.0), Vector3(10.5, 1.10, 11.6), Vector3(-17.5, 1.15, 1.2), Vector3(14.8, 0.95, -0.5)], "balloon", [0.04, 0.04, 0.04, 0.04], true)

func _on_toy_body_entered(body: Node3D, idx: int) -> void:
	if not game_started:
		return
	if not body.is_in_group("player"):
		return
	var toy: Dictionary = toys[idx]
	if toy.taken:
		return
	toy.taken = true
	collection_order.append(toy)
	toy.root.visible = false
	toy.ring.visible = false
	(toy.area as Area3D).monitoring = false
	collected += 1
	_update_star_label()
	_play(chime_player)
	mimi.celebrate_hop()
	# Star burst + floating star at the toy
	burst.global_position = toy.root.global_position + Vector3(0, 0.25, 0)
	burst.restart()
	float_star.global_position = toy.root.global_position + Vector3(0, 0.3, 0)
	float_star.visible = true
	float_star.modulate = Color(1, 0.85, 0.3, 1)
	var tw := create_tween()
	tw.tween_property(float_star, "position:y", float_star.position.y + 1.1, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(float_star, "modulate:a", 0.0, 0.9)
	tw.tween_callback(func() -> void: float_star.visible = false)
	if collected >= active_toys:
		get_tree().create_timer(0.8).timeout.connect(_show_win)

func _update_star_label() -> void:
	star_label.text = "★ Toys: %d / %d" % [collected, active_toys]

func _apply_difficulty_toys() -> void:
	# Easy/Normal/Hard play the classic 8; Impossible plays all 15.
	active_toys = 15 if difficulty == 3 else 8
	for toy in toys:
		var on: bool = not toy.imp_only or difficulty == 3
		toy.active = on
		if on:
			toy.taken = false  # switching up from a lower difficulty must un-hide them fully
			toy.root.visible = true
			toy.ring.visible = true
			(toy.area as Area3D).monitoring = true
		else:
			toy.taken = true
			toy.root.visible = false
			toy.ring.visible = false
			(toy.area as Area3D).monitoring = false
	_update_star_label()

func _update_mission_label() -> void:
	if mission_label != null:
		var count := 15 if difficulty == 3 else 8
		mission_label.text = "Help Mimi find her %d lost toys — beat all 4 levels!" % count

# ------------------------------------------------------------------ Coco

func _build_coco() -> void:
	coco = Node3D.new()
	coco.position = coco_home  # he lives by his doghouse in the garden now
	coco.rotation.y = PI  # facing the garden and the house
	add_child(coco)
	var gold := Color(0.92, 0.66, 0.30)
	var gold_dark := Color(0.72, 0.47, 0.22)
	var cream := Color(1, 0.90, 0.75)
	# legs
	for dx in [-0.15, 0.15]:
		for dz in [-0.15, 0.15]:
			_cylinder(coco, Vector3(dx, 0.14, dz), 0.07, 0.07, 0.28, gold, 0.0)
	_sphere(coco, Vector3(0, 0.50, 0), 0.32, gold, Vector3(1, 1.0, 1.05))
	# head
	_sphere(coco, Vector3(0, 0.92, 0.10), 0.27, gold)
	_sphere(coco, Vector3(0, 0.84, 0.32), 0.13, cream, Vector3(1, 0.8, 0.9))
	_sphere(coco, Vector3(0, 0.90, 0.43), 0.045, Color(0.20, 0.14, 0.12))
	for side in [-1.0, 1.0]:
		# floppy ears
		_sphere(coco, Vector3(0.24 * side, 0.86, 0.08), 0.11, gold_dark, Vector3(0.55, 1.5, 0.9))
		_sphere(coco, Vector3(0.11 * side, 0.98, 0.30), 0.035, Color(0.15, 0.12, 0.12), Vector3(1, 1.2, 0.5))
	# sky-blue bandana (solid light blue, Coco's signature)
	_cylinder(coco, Vector3(0, 0.70, 0.08), 0.13, 0.26, 0.16, Color(0.50, 0.78, 0.89), 0.0)
	# tail
	coco_tail = Node3D.new()
	coco_tail.position = Vector3(0, 0.58, -0.30)
	coco.add_child(coco_tail)
	var tail := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.055
	tm.height = 0.4
	tail.mesh = tm
	tail.material_override = _mat(gold)
	tail.position = Vector3(0, 0.10, -0.08)
	tail.rotation.x = -0.8
	coco_tail.add_child(tail)
	coco.visible = true

# ------------------------------------------------------------------ Lulu

func _build_lulu() -> void:
	# Lulu the Bunny hides behind the big oak in the garden: light lavender fur,
	# big violet eyes, pink nose and cheeks, and her purple bow on her RIGHT ear.
	lulu = Node3D.new()
	lulu.position = Vector3(-6.05, 0, 13.05)
	lulu.rotation.y = 0.55  # facing the stone path (and the camera side) as she peeks out
	add_child(lulu)
	lulu_visual = Node3D.new()
	lulu.add_child(lulu_visual)
	var lav := Color(0.80, 0.71, 0.93)
	var lav_light := Color(0.93, 0.88, 0.99)
	var pink := Color(1, 0.55, 0.70)
	var pink_soft := Color(1, 0.74, 0.85)
	var purple := Color(0.60, 0.40, 0.85)
	var violet := Color(0.44, 0.29, 0.78)
	# Feet, body and tummy
	for side in [-1.0, 1.0]:
		_sphere(lulu_visual, Vector3(0.11 * side, 0.05, 0.07), 0.09, lav_light, Vector3(1, 0.5, 1.5))
	_sphere(lulu_visual, Vector3(0, 0.34, 0), 0.26, lav, Vector3(1, 1.1, 0.95))
	_sphere(lulu_visual, Vector3(0, 0.32, 0.13), 0.17, lav_light, Vector3(1, 1.15, 0.55))
	# Little arms
	for side in [-1.0, 1.0]:
		var arm := _sphere(lulu_visual, Vector3(0.26 * side, 0.38, 0.02), 0.07, lav, Vector3(0.6, 1.35, 0.6))
		arm.rotation.z = -0.25 * side
	# Fluffy tail
	_sphere(lulu_visual, Vector3(0, 0.24, -0.25), 0.095, lav_light)
	# Head
	var head := Node3D.new()
	head.position = Vector3(0, 0.66, 0)
	lulu_visual.add_child(head)
	_sphere(head, Vector3.ZERO, 0.24, lav)
	# Long ears with pink insides
	for side in [-1.0, 1.0]:
		var ear := _sphere(head, Vector3(0.125 * side, 0.36, 0), 0.10, lav, Vector3(0.55, 2.25, 0.30))
		ear.rotation.z = -0.10 * side
		var inner := _sphere(head, Vector3(0.12 * side, 0.36, 0.045), 0.06, pink_soft, Vector3(0.5, 1.9, 0.25))
		inner.rotation.z = -0.10 * side
	# Her signature purple bow, at the base of her RIGHT ear (she faces +Z, so her right is -X)
	var bow := Node3D.new()
	bow.position = Vector3(-0.155, 0.19, 0.06)
	bow.rotation.z = 0.25
	head.add_child(bow)
	_sphere(bow, Vector3(-0.05, 0, 0), 0.046, purple, Vector3(1.25, 0.8, 0.55))
	_sphere(bow, Vector3(0.05, 0, 0), 0.046, purple, Vector3(1.25, 0.8, 0.55))
	_sphere(bow, Vector3(0, 0, 0.01), 0.028, purple)
	# Big violet eyes with a sparkle
	for side in [-1.0, 1.0]:
		_sphere(head, Vector3(0.095 * side, 0.03, 0.205), 0.042, violet, Vector3(1, 1.3, 0.5))
		_sphere(head, Vector3(0.095 * side + 0.013, 0.055, 0.228), 0.014, Color(1, 1, 1))
	# Pink triangular nose (cone pointing down) and rosy cheeks
	var nose := _cone_at(head, Vector3(0, -0.025, 0.225), 0.030, 0.038, pink)
	nose.rotation.x = PI
	for side in [-1.0, 1.0]:
		_sphere(head, Vector3(0.15 * side, -0.05, 0.185), 0.045, pink_soft, Vector3(1, 0.75, 0.3))
	# Name label that pops up when Mimi finds her
	lulu_label = Label3D.new()
	lulu_label.text = "Lulu!"
	lulu_label.font_size = 150
	lulu_label.pixel_size = 0.008
	lulu_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lulu_label.modulate = Color(0.85, 0.65, 1, 1)
	lulu_label.outline_size = 14
	lulu_label.outline_modulate = Color(0.45, 0.25, 0.75, 1)
	lulu_label.position = Vector3(0, 1.55, 0)
	lulu_label.visible = false
	lulu.add_child(lulu_label)

func _found_lulu() -> void:
	lulu_found = true
	# She turns to face Mimi and hops with joy while the stars burst
	var d: Vector3 = mimi.global_position - lulu.global_position
	lulu.rotation.y = atan2(d.x, d.z)
	# Finding her grants +40 seconds to keep searching for the toys
	if not game_won and not game_over:
		time_left += 40.0
		_update_timer_label()
		lulu_label.text = "Lulu! +40s" if buy_only else "Lulu! +40s\n+10 coins"
		_add_coins(10)
	_play(win_player)
	burst.global_position = lulu.global_position + Vector3(0, 0.5, 0)
	burst.restart()
	lulu_label.visible = true
	var tw := create_tween().set_loops(3)
	tw.tween_property(lulu, "position:y", 0.30, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lulu, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

# ------------------------------------------------------------------ The Mouse & Coco's chase

func _build_mice() -> void:
	# Mouse 1 lives in the kitchen; mouse 2 (Impossible only) in the bedroom
	mice.append(_make_mouse(Vector3(17.8, 0.1, -4.6), Color(0.58, 0.58, 0.64), Color(0.45, 0.45, 0.52)))
	mice.append(_make_mouse(Vector3(-17.5, 0.1, 3.2), Color(0.47, 0.43, 0.45), Color(0.36, 0.33, 0.36)))
	_apply_mice()

func _apply_mice() -> void:
	# The second mouse only joins the game on Impossible difficulty.
	for i in mice.size():
		var m: Dictionary = mice[i]
		# Mouse 2 joins on Impossible, on Hard from level 2, and always on levels 3-4
		var on: bool = i == 0 or difficulty == 3 or level >= 3 or (level == 2 and difficulty >= 2)
		m.active = on
		(m.body as CharacterBody3D).visible = on
		(m.body as CharacterBody3D).set_collision_layer_value(1, on)
		(m.body as CharacterBody3D).set_collision_mask_value(1, on)

func _make_mouse(spawn: Vector3, gray: Color, gray_dark: Color) -> Dictionary:
	var mouse_body := CharacterBody3D.new()
	mouse_body.position = spawn
	add_child(mouse_body)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.20
	capsule.height = 0.55
	shape.shape = capsule
	shape.position.y = 0.30
	mouse_body.add_child(shape)
	mouse_body.floor_snap_length = 0.3
	var mouse_visual := Node3D.new()
	mouse_body.add_child(mouse_visual)
	var cream := Color(0.93, 0.91, 0.89)
	var pink := Color(1, 0.55, 0.66)
	var pink_soft := Color(1, 0.74, 0.82)
	# Body and tummy
	_sphere(mouse_visual, Vector3(0, 0.34, 0), 0.26, gray, Vector3(1, 0.95, 1.12))
	_sphere(mouse_visual, Vector3(0, 0.30, 0.13), 0.16, cream, Vector3(1, 1.05, 0.55))
	# Feet
	for side in [-1.0, 1.0]:
		_sphere(mouse_visual, Vector3(0.11 * side, 0.045, 0.10), 0.075, gray_dark, Vector3(1, 0.5, 1.5))
	# Head
	_sphere(mouse_visual, Vector3(0, 0.58,  0.08), 0.20, gray)
	# Big round ears with pink insides
	for side in [-1.0, 1.0]:
		_sphere(mouse_visual, Vector3(0.14 * side, 0.76, 0.04), 0.095, gray, Vector3(1, 1, 0.38))
		_sphere(mouse_visual, Vector3(0.14 * side, 0.76, 0.085), 0.058, pink_soft, Vector3(1, 1, 0.3))
	# Snout, pink nose and bead eyes
	_sphere(mouse_visual, Vector3(0, 0.52, 0.24), 0.10, cream, Vector3(1, 0.8, 1.1))
	_sphere(mouse_visual, Vector3(0, 0.54, 0.345), 0.034, pink)
	for side in [-1.0, 1.0]:
		_sphere(mouse_visual, Vector3(0.082 * side, 0.63, 0.225), 0.028, Color(0.12, 0.10, 0.12), Vector3(1, 1.15, 0.6))
	# Long tail on a swaying pivot
	var mouse_tail := Node3D.new()
	mouse_tail.position = Vector3(0, 0.30, -0.26)
	mouse_visual.add_child(mouse_tail)
	var tail := MeshInstance3D.new()
	var tm := CapsuleMesh.new()
	tm.radius = 0.020
	tm.height = 0.55
	tail.mesh = tm
	tail.material_override = _mat(Color(0.88, 0.66, 0.66))
	tail.position = Vector3(0, 0.10, -0.16)
	tail.rotation.x = -1.1
	mouse_tail.add_child(tail)
	# Golden "!" that pops when he snatches a toy
	var mouse_label := Label3D.new()
	mouse_label.text = "!"
	mouse_label.font_size = 170
	mouse_label.pixel_size = 0.008
	mouse_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mouse_label.modulate = Color(1, 0.85, 0.3, 1)
	mouse_label.outline_size = 16
	mouse_label.outline_modulate = Color(0.85, 0.55, 0.1, 1)
	mouse_label.position = Vector3(0, 1.05, 0)
	mouse_label.visible = false
	mouse_body.add_child(mouse_label)
	var m := {"body": mouse_body, "visual": mouse_visual, "tail": mouse_tail, "label": mouse_label, "carry": null, "target": Vector3(12, 0, 2), "stuck": 0.0, "last_pos": mouse_body.position, "flee": 0.0, "cooldown": 0.0, "active": true, "spawn": spawn}
	_pick_mouse_target(m)
	return m

func _pick_mouse_target(m: Dictionary) -> void:
	m.target = mouse_waypoints[randi() % mouse_waypoints.size()]

func _dist2d(a: Vector3, b: Vector3) -> float:
	var d := a - b
	d.y = 0.0
	return d.length()

func _physics_process(delta: float) -> void:
	for m in mice:
		if m.active:
			_physics_mouse(m, delta)

func _physics_mouse(m: Dictionary, delta: float) -> void:
	var body: CharacterBody3D = m.body
	var vel := body.velocity
	if body.is_on_floor():
		vel.y = 0.0
	else:
		vel.y -= 14.0 * delta
	var move_dir := Vector3.ZERO
	var speed := 0.0
	if mouse_active and game_started:
		m.cooldown = max(0.0, float(m.cooldown) - delta)
		m.flee = max(0.0, float(m.flee) - delta)
		var d := _diff()
		var mp := body.global_position
		if m.carry != null:
			# Run away from Mimi, and dodge Coco who is chasing him
			var away: Vector3 = mp - mimi.global_position
			away.y = 0.0
			away = away.normalized()
			var from_coco: Vector3 = mp - coco.global_position
			from_coco.y = 0.0
			var coco_dist := from_coco.length()
			if coco_dist < 3.0 and coco_dist > 0.01:
				away = (away + from_coco.normalized() * 1.2).normalized()
			move_dir = away
			speed = (float(d.flee) + 0.4) if coco_dist < 2.5 else float(d.flee)
		elif float(m.flee) > 0.0:
			var away2: Vector3 = mp - coco.global_position
			away2.y = 0.0
			move_dir = away2.normalized() if away2.length() > 0.01 else Vector3(0, 0, -1)
			speed = 5.2
		elif collected > 0 and not game_won and not game_over and _dist2d(mp, mimi.global_position) < float(d.range):
			# HUNTING: he comes straight for Mimi to snatch a toy. Higher
			# levels even aim where she is heading, not where she is.
			var aim: Vector3 = mimi.global_position + mimi.velocity * float(d.lead)
			var to_aim: Vector3 = aim - mp
			to_aim.y = 0.0
			if to_aim.length() > 0.05:
				move_dir = to_aim.normalized()
				speed = float(d.hunt)
		else:
			var to: Vector3 = m.target - mp
			to.y = 0.0
			if to.length() < 0.7:
				_pick_mouse_target(m)
			else:
				move_dir = to.normalized()
				speed = float(d.wander)
			if mp.distance_to(m.last_pos) < 0.05:
				m.stuck = float(m.stuck) + delta
				if float(m.stuck) > 2.2:
					_pick_mouse_target(m)
					m.stuck = 0.0
			else:
				m.stuck = 0.0
			m.last_pos = mp
	if move_dir != Vector3.ZERO:
		vel.x = move_dir.x * speed
		vel.z = move_dir.z * speed
		body.rotation.y = lerp_angle(body.rotation.y, atan2(move_dir.x, move_dir.z), 1.0 - pow(0.001, delta))
	else:
		vel.x = move_toward(vel.x, 0.0, 20.0 * delta)
		vel.z = move_toward(vel.z, 0.0, 20.0 * delta)
	body.velocity = vel
	body.move_and_slide()
	body.position.x = clamp(body.position.x, -19.3, 19.3)
	body.position.z = clamp(body.position.z, -5.3, 15.7)

func _mouse_steals(m: Dictionary) -> void:
	var toy: Dictionary = collection_order.pop_back()
	m.carry = toy
	toy.stolen = true
	toy.root.visible = true  # it rides on his head while he runs
	collected -= 1
	_update_star_label()
	_play(squeak_player)
	var lbl: Label3D = m.label
	lbl.visible = true
	get_tree().create_timer(1.0).timeout.connect(func() -> void: lbl.visible = false)
	banner_label.text = "The mouse stole a toy! Coco is after him!"
	banner_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(2.4)
	tw.tween_property(banner_label, "modulate:a", 0.0, 1.0)
	if coco_state == "idle" or coco_state == "return":
		coco_state = "chase"

func _carrier_mouse():
	# The mouse Coco should chase: the nearest one carrying a toy, or null
	var best = null
	var best_d := 1e9
	for m in mice:
		if m.active and m.carry != null:
			var dd := _dist2d(coco.global_position, (m.body as Node3D).global_position)
			if dd < best_d:
				best_d = dd
				best = m
	return best

func _coco_catches(m: Dictionary) -> void:
	# The mouse drops the toy right where Coco caught him
	var toy: Dictionary = m.carry
	m.carry = null
	m.flee = 2.2
	m.cooldown = float(_diff().cooldown)
	toy.stolen = false
	toy.taken = false
	var drop := (m.body as Node3D).global_position
	toy.root.position = Vector3(drop.x, 0.2, drop.z)
	toy.base_y = 0.2
	toy.root.visible = true
	toy.ring.position = Vector3(drop.x, 0.04, drop.z)
	toy.ring.visible = true
	(toy.area as Area3D).monitoring = true
	_play(chime_player)
	burst.global_position = drop + Vector3(0, 0.4, 0)
	burst.restart()
	coco_state = "return"
	var tw := create_tween().set_loops(2)
	tw.tween_property(coco, "position:y", 0.3, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(coco, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _coco_move_toward(target: Vector3, speed: float, delta: float) -> bool:
	var pos := coco.global_position
	var d: Vector3 = target - pos
	d.y = 0.0
	if d.length() < 0.25:
		return true
	var step: Vector3 = d.normalized() * min(speed * delta, d.length())
	pos.x = clamp(pos.x + step.x, -19.3, 19.3)
	pos.z = clamp(pos.z + step.z, -5.3, 15.7)
	coco.global_position = pos
	coco.rotation.y = lerp_angle(coco.rotation.y, atan2(d.x, d.z), 1.0 - pow(0.0001, delta))
	return d.length() < 0.6

func _update_coco(_delta: float) -> void:
	if coco == null or not coco.visible:
		return
	var carrier = _carrier_mouse()
	# A second thief may still be running with a toy: Coco goes back to work
	if carrier != null and not game_over and (coco_state == "idle" or coco_state == "return"):
		coco_state = "chase"
	if coco_state == "chase" and carrier != null and not game_over:
		var thief_pos: Vector3 = (carrier.body as Node3D).global_position
		var d: Vector3 = thief_pos - coco.global_position
		d.y = 0.0
		if d.length() < 0.8:
			_coco_catches(carrier)
			return
		_coco_move_toward(thief_pos, float(_diff().coco), _delta)
	elif coco_state == "return" and not game_over:
		if _coco_move_toward(coco_home, 3.6, _delta):
			coco.rotation.y = PI
			coco_state = "idle"

func _show_win() -> void:
	game_won = true  # stops the mission countdown
	coco_state = "celebrate"
	# Coco runs up next to Mimi, wherever she is, to celebrate with her
	var mp: Vector3 = mimi.global_position
	coco.global_position = Vector3(clamp(mp.x + 1.5, -18.5, 18.5), 0.0, clamp(mp.z + 1.3, -5.0, 14.8))
	coco.rotation.y = 0.6
	coco.visible = true
	_play(win_player)
	_play(meow_player)
	var tw := create_tween().set_loops(4)
	tw.tween_property(coco, "position:y", 0.35, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(coco, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var reward := 20 + (50 if level == 4 else 0)
	_add_coins(reward)
	win_coins.text = "" if buy_only else "+%d coins!" % reward
	if level < 4:
		win_title.text = "Level %d complete!" % level
		win_sub.text = "Next stop: %s!" % SCEN[level].name
	else:
		win_title.text = "You found all the toys!"
		win_sub.text = "Bravo, Mimi! You beat all 4 levels!"
	win_panel.visible = true
	# Celebrate for a few seconds, then move on: next level, or the menu
	get_tree().create_timer(3.5).timeout.connect(_advance_after_win)

func _advance_after_win() -> void:
	if not game_won:
		return  # the player bailed to the menu during the celebration
	if level < 4:
		level += 1
		_reset_game()
		banner_label.text = "Level %d — %s! Find the %d lost toys!" % [level, SCEN[level - 1].name, active_toys]
		banner_label.modulate.a = 1.0
		var tw := create_tween()
		tw.tween_interval(4.0)
		tw.tween_property(banner_label, "modulate:a", 0.0, 1.2)
	else:
		_back_to_menu()

# ------------------------------------------------------------------ effects & audio

func _build_effects() -> void:
	burst = CPUParticles3D.new()
	burst.amount = 16
	burst.lifetime = 0.7
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.direction = Vector3(0, 1, 0)
	burst.spread = 40.0
	burst.initial_velocity_min = 1.8
	burst.initial_velocity_max = 3.2
	burst.gravity = Vector3(0, -4.5, 0)
	burst.scale_amount_min = 0.7
	burst.scale_amount_max = 1.3
	burst.emitting = false
	var sm := SphereMesh.new()
	sm.radius = 0.05
	sm.height = 0.10
	sm.radial_segments = 10
	sm.rings = 6
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(1, 0.82, 0.30)
	pm.emission_enabled = true
	pm.emission = Color(1, 0.82, 0.30)
	pm.emission_energy_multiplier = 1.2
	sm.material = pm
	burst.mesh = sm
	add_child(burst)
	float_star = Label3D.new()
	float_star.text = "★"
	float_star.font_size = 180
	float_star.pixel_size = 0.008
	float_star.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	float_star.modulate = Color(1, 0.85, 0.3, 1)
	float_star.outline_size = 16
	float_star.outline_modulate = Color(0.85, 0.55, 0.1, 1)
	float_star.visible = false
	add_child(float_star)

func _make_player(path: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var stream: AudioStream = load(path)
	if stream != null:
		p.stream = stream
	p.volume_db = vol_db
	add_child(p)
	return p

func _build_audio() -> void:
	timeout_player = _make_player("res://audio/timeout.wav", -6.0)
	squeak_player = _make_player("res://audio/squeak.wav", -5.0)
	chime_player = _make_player("res://audio/chime.wav", -6.0)
	win_player = _make_player("res://audio/win.wav", -6.0)
	meow_player = _make_player("res://audio/meow.wav", -8.0)
	music_player = _make_player("res://audio/music.wav", -20.0)
	music_player.finished.connect(func() -> void: music_player.play())

func _play(p: AudioStreamPlayer) -> void:
	if p != null and p.stream != null:
		p.play()

# ------------------------------------------------------------------ HUD & overlays

func _big_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.35))
	l.add_theme_constant_override("shadow_offset_x", 3)
	l.add_theme_constant_override("shadow_offset_y", 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	# Star counter, top-left
	star_label = _big_label("", 40, Color(1, 0.85, 0.3))
	_update_star_label()
	star_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	star_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	star_label.offset_left = 22
	star_label.offset_top = 14
	layer.add_child(star_label)
	# Current level, under the counter
	level_label = _big_label("Level 1 / 4", 26, Color(1, 1, 1))
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	level_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	level_label.offset_left = 24
	level_label.offset_top = 62
	layer.add_child(level_label)
	# Coin balance, under the level label
	coin_label = _big_label("Coins: 0", 26, Color(1, 0.85, 0.3))
	coin_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	coin_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	coin_label.offset_left = 24
	coin_label.offset_top = 100
	layer.add_child(coin_label)
	# Mission banner, top-center (fades out)
	banner_label = _big_label("Find the %d lost toys!" % toys.size(), 44, Color(1, 1, 1))
	banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_label.offset_left = -320
	banner_label.offset_right = 320
	banner_label.offset_top = 16
	banner_label.modulate.a = 0.0
	layer.add_child(banner_label)
	# Mission countdown, top-right (turns red and pulses under 10 seconds)
	timer_label = _big_label("", 40, Color(1, 1, 1))
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.offset_left = -240
	timer_label.offset_right = -22
	timer_label.offset_top = 14
	timer_label.visible = false
	layer.add_child(timer_label)
	# Joystick bottom-left, jump button bottom-right
	joystick = JOYSTICK_SCRIPT.new()
	joystick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	joystick.offset_left = 26
	joystick.offset_right = 266
	joystick.offset_top = -266
	joystick.offset_bottom = -26
	layer.add_child(joystick)
	mimi.joystick = joystick
	var jump_btn: Control = JUMP_SCRIPT.new()
	jump_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump_btn.offset_left = -226
	jump_btn.offset_right = -26
	jump_btn.offset_top = -226
	jump_btn.offset_bottom = -26
	layer.add_child(jump_btn)
	jump_btn.pressed.connect(func() -> void: mimi.try_jump())
	# Menu button (bottom-center): back to the start screen to change difficulty
	menu_btn = Button.new()
	menu_btn.text = "Menu"
	menu_btn.custom_minimum_size = Vector2(130, 54)
	menu_btn.add_theme_font_size_override("font_size", 24)
	menu_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	menu_btn.offset_left = -65
	menu_btn.offset_right = 65
	menu_btn.offset_top = -84
	menu_btn.offset_bottom = -30
	menu_btn.pressed.connect(_back_to_menu)
	menu_btn.visible = false
	layer.add_child(menu_btn)
	_build_start_overlay(layer)
	_build_shop(layer)
	_build_minigames(layer)
	_build_win_panel(layer)
	_build_lose_panel(layer)

func _build_start_overlay(layer: CanvasLayer) -> void:
	start_overlay = Control.new()
	start_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(start_overlay)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.10, 0.20, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	start_overlay.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	center.add_child(vbox)
	var title := _big_label("Mimi's Magical World", 72, Color(1, 0.85, 0.92))
	vbox.add_child(title)
	var sub := _big_label("Mimi's House", 40, Color(1, 1, 1))
	vbox.add_child(sub)
	mission_label = _big_label("", 34, Color(1, 0.95, 0.80))
	vbox.add_child(mission_label)
	_update_mission_label()
	# Mouse difficulty selector
	vbox.add_child(_big_label("How sneaky is the mouse?", 26, Color(1, 1, 1)))
	var diff_row := HBoxContainer.new()
	diff_row.alignment = BoxContainer.ALIGNMENT_CENTER
	diff_row.add_theme_constant_override("separation", 10)
	vbox.add_child(diff_row)
	diff_buttons.clear()
	for i in DIFFS.size():
		var b := Button.new()
		b.text = DIFFS[i].name
		b.custom_minimum_size = Vector2(158, 56)
		b.add_theme_font_size_override("font_size", 25)
		b.pressed.connect(_on_difficulty_pressed.bind(i))
		diff_row.add_child(b)
		diff_buttons.append(b)
	_update_diff_buttons()
	var play_btn := Button.new()
	play_btn.text = "Play!"
	play_btn.custom_minimum_size = Vector2(280, 84)
	play_btn.add_theme_font_size_override("font_size", 42)
	play_btn.pressed.connect(_on_play_pressed)
	var btn_center := CenterContainer.new()
	btn_center.add_child(play_btn)
	vbox.add_child(btn_center)
	start_coin_label = _big_label("Coins: 0", 28, Color(1, 0.85, 0.3))
	vbox.add_child(start_coin_label)
	var shop_btn := Button.new()
	shop_btn.text = "Shop"
	shop_btn.custom_minimum_size = Vector2(220, 64)
	shop_btn.add_theme_font_size_override("font_size", 32)
	shop_btn.pressed.connect(_open_shop)
	var shop_center := CenterContainer.new()
	shop_center.add_child(shop_btn)
	vbox.add_child(shop_center)
	var mg_btn := Button.new()
	mg_btn.text = "Mini Games"
	mg_btn.custom_minimum_size = Vector2(280, 64)
	mg_btn.add_theme_font_size_override("font_size", 32)
	mg_btn.pressed.connect(_open_mini_games)
	var mg_center := CenterContainer.new()
	mg_center.add_child(mg_btn)
	vbox.add_child(mg_center)
	var hint := _big_label("Move: joystick / WASD  •  Jump: pink button / Space  •  Camera: drag the screen", 22, Color(1, 1, 1))
	vbox.add_child(hint)

func _on_difficulty_pressed(i: int) -> void:
	difficulty = i
	_update_diff_buttons()
	_update_mission_label()
	_play(chime_player)

func _update_diff_buttons() -> void:
	for i in diff_buttons.size():
		var b: Button = diff_buttons[i]
		if i == difficulty:
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1, 0.78, 0.25)
			sb.set_corner_radius_all(12)
			sb.set_border_width_all(3)
			sb.border_color = Color(0.85, 0.55, 0.1)
			b.add_theme_stylebox_override("normal", sb)
			b.add_theme_stylebox_override("hover", sb)
			b.add_theme_stylebox_override("pressed", sb)
			b.add_theme_color_override("font_color", Color(0.25, 0.15, 0.0))
		else:
			b.remove_theme_stylebox_override("normal")
			b.remove_theme_stylebox_override("hover")
			b.remove_theme_stylebox_override("pressed")
			b.remove_theme_color_override("font_color")

func _back_to_menu() -> void:
	# Bail out of the current run and land back on the start screen, where the
	# difficulty can be changed before pressing Play! again.
	level = 1
	_reset_game()
	game_started = false
	mimi.move_enabled = false
	timer_label.visible = false
	menu_btn.visible = false
	win_panel.visible = false
	lose_panel.visible = false
	if mg_panel != null:
		mg_panel.visible = false
	if mg_game_panel != null:
		mg_game_panel.visible = false
	start_overlay.visible = true
	music_player.stop()

func _on_play_pressed() -> void:
	start_overlay.visible = false
	if shop_panel != null:
		shop_panel.visible = false
	if mg_panel != null:
		mg_panel.visible = false
	if mg_game_panel != null:
		mg_game_panel.visible = false
	level = 1
	_apply_difficulty_toys()
	_apply_mice()
	game_started = true
	mimi.move_enabled = true
	time_left = LEVEL_TIMES[0]
	game_won = false
	game_over = false
	timer_label.visible = true
	menu_btn.visible = true
	level_label.text = "Level 1 / 4 · House"
	_update_timer_label()
	banner_label.text = "Level 1 — Mimi's House! Find the %d lost toys!" % active_toys
	_play(music_player)
	banner_label.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(4.0)
	tw.tween_property(banner_label, "modulate:a", 0.0, 1.2)

func _update_timer_label() -> void:
	var s := int(ceil(time_left))
	timer_label.text = "%d:%02d" % [s / 60, s % 60]
	if time_left <= 10.0:
		timer_label.add_theme_color_override("font_color", Color(1, 0.35, 0.30))
		var p := 1.0 + sin(time * 10.0) * 0.06
		timer_label.scale = Vector2(p, p)
	else:
		timer_label.add_theme_color_override("font_color", Color(1, 1, 1))
		timer_label.scale = Vector2.ONE

func _on_time_up() -> void:
	game_over = true
	mimi.move_enabled = false
	_play(timeout_player)
	lose_panel.visible = true

func _build_lose_panel(layer: CanvasLayer) -> void:
	lose_panel = Control.new()
	lose_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(lose_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.12, 0.15, 0.30, 0.40)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	lose_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	lose_panel.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	vbox.add_child(_big_label("Time's Up!", 52, Color(1, 1, 1)))
	vbox.add_child(_big_label("So close! The toys are hiding again.", 30, Color(1, 0.95, 0.85)))
	var retry_btn := Button.new()
	retry_btn.text = "Try Again"
	retry_btn.custom_minimum_size = Vector2(280, 76)
	retry_btn.add_theme_font_size_override("font_size", 36)
	retry_btn.pressed.connect(_reset_game)
	var btn_center := CenterContainer.new()
	btn_center.add_child(retry_btn)
	vbox.add_child(btn_center)
	lose_panel.visible = false

func _build_win_panel(layer: CanvasLayer) -> void:
	win_panel = Control.new()
	win_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(win_panel)
	var dim := ColorRect.new()
	dim.color = Color(0.25, 0.15, 0.05, 0.40)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	win_panel.add_child(center)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	center.add_child(vbox)
	vbox.add_child(_big_label("★ ★ ★ ★ ★", 54, Color(1, 0.85, 0.3)))
	win_title = _big_label("You found all the toys!", 52, Color(1, 1, 1))
	vbox.add_child(win_title)
	win_sub = _big_label("Bravo, Mimi! Coco is so happy!", 32, Color(1, 0.95, 0.85))
	vbox.add_child(win_sub)
	win_coins = _big_label("", 30, Color(1, 0.85, 0.3))
	vbox.add_child(win_coins)
	win_panel.visible = false

func _reset_game() -> void:
	win_panel.visible = false
	lose_panel.visible = false
	# Swap to this level's world and its hangouts
	_set_world(level - 1)
	coco_home = SCEN[level - 1].coco_home
	# Coco trots back to his spot
	coco_state = "idle"
	coco.global_position = coco_home
	coco.rotation.y = PI
	coco.visible = true
	collected = 0
	_update_star_label()
	for toy in toys:
		toy.taken = false
		toy.stolen = false
		var home: Vector3 = toy.homes[level - 1]
		toy.root.position = home
		toy.base_y = home.y
		toy.root.visible = true
		toy.ring.position = Vector3(home.x, toy.ring_ys[level - 1], home.z)
		toy.ring.visible = true
		(toy.area as Area3D).monitoring = true
	mimi.position = Vector3(0, 0.05, 2.6)
	mimi.velocity = Vector3.ZERO
	_apply_difficulty_toys()
	menu_btn.visible = true
	if level_label != null:
		level_label.text = "Level %d / 4 · %s" % [level, SCEN[level - 1].short]
	# Fresh time for the new try (more on the higher levels)
	time_left = LEVEL_TIMES[level - 1]
	game_won = false
	game_over = false
	game_started = true
	mimi.move_enabled = true
	timer_label.visible = true
	_update_timer_label()
	# Lulu hides again, so her +40 s bonus can be earned on the new try too
	lulu_found = false
	lulu_label.visible = false
	lulu_label.text = "Lulu!"
	lulu.global_position = SCEN[level - 1].lulu_pos
	lulu.rotation.y = SCEN[level - 1].lulu_rot
	# The mice run back to their corners and let go of anything they held
	collection_order.clear()
	for i in mice.size():
		var m: Dictionary = mice[i]
		m.carry = null
		m.cooldown = 0.0
		m.flee = 0.0
		m.spawn = SCEN[level - 1].mouse_spawns[i]
		(m.body as CharacterBody3D).position = m.spawn
		(m.body as CharacterBody3D).velocity = Vector3.ZERO
		_pick_mouse_target(m)
	_apply_mice()

# ------------------------------------------------------------------ more rooms

func _divider_wall(x: float) -> void:
	# Wall between rooms with a WIDE OPEN doorway at z in [-1.6, 2.0], wood
	# trim, and the door panel itself swung fully open against the wall.
	var wall_col := Color(0.87, 0.72, 0.55)
	var trim := Color(0.72, 0.48, 0.30)
	_box(Vector3(x, 2.25, -3.8), Vector3(0.3, 4.5, 4.4), wall_col)
	_box(Vector3(x, 2.25, 4.0), Vector3(0.3, 4.5, 4.0), wall_col)
	_box(Vector3(x, 1.35, -1.68), Vector3(0.4, 2.7, 0.18), trim, false)
	_box(Vector3(x, 1.35, 2.08), Vector3(0.4, 2.7, 0.18), trim, false)
	_box(Vector3(x, 2.78, 0.2), Vector3(0.4, 0.22, 3.96), trim, false)
	# The open door: flat against the wall on the far room's side, with a knob
	var side := 1.0 if x > 0.0 else -1.0
	_box(Vector3(x + side * 0.21, 1.3, -2.4), Vector3(0.07, 2.6, 1.5), Color(0.80, 0.58, 0.38))
	_sphere(self, Vector3(x + side * 0.28, 1.3, -1.78), 0.05, Color(1, 0.80, 0.25), Vector3.ONE, 0.5)

func _simple_window(cx: float) -> void:
	# A window on the back wall (z = -6), same style as the living room one
	_box(Vector3(cx, 2.7, -5.82), Vector3(2.2, 1.7, 0.06), Color(0.75, 0.90, 1.0), false)
	_box(Vector3(cx, 3.58, -5.80), Vector3(2.4, 0.12, 0.08), Color(1, 1, 1), false)
	_box(Vector3(cx, 1.82, -5.80), Vector3(2.4, 0.12, 0.08), Color(1, 1, 1), false)
	_box(Vector3(cx - 1.14, 2.7, -5.80), Vector3(0.12, 1.9, 0.08), Color(1, 1, 1), false)
	_box(Vector3(cx + 1.14, 2.7, -5.80), Vector3(0.12, 1.9, 0.08), Color(1, 1, 1), false)
	_box(Vector3(cx, 2.7, -5.80), Vector3(0.10, 1.7, 0.08), Color(1, 1, 1), false)

func _build_house_shell() -> void:
	var wall_col := Color(0.87, 0.72, 0.55)
	# Floors: kitchen tile (right), bedroom soft wood (left), garden grass (front)
	var kitchen_floor := _box(Vector3(14, -0.1, 0), Vector3(12, 0.2, 12), Color(0.52, 0.76, 0.68))
	kitchen_floor.material_override = _tex_mat("res://textures/tile.png", 2.0, Color(0.56, 0.72, 0.66))
	var bedroom_floor := _box(Vector3(-14, -0.1, 0), Vector3(12, 0.2, 12), Color(0.70, 0.50, 0.64))
	bedroom_floor.material_override = _tex_mat("res://textures/wood_pink.png", 2.0, Color(0.84, 0.70, 0.76))
	var garden_floor := _box(Vector3(0, -0.1, 11.2), Vector3(40, 0.2, 10.4), Color(0.36, 0.68, 0.33))
	garden_floor.material_override = _tex_mat("res://textures/grass.png", 10.0, Color(0.66, 0.85, 0.66))
	# Back walls continue; outer side walls
	_box(Vector3(14, 2.25, -6), Vector3(12, 4.5, 0.3), wall_col)
	_box(Vector3(-14, 2.25, -6), Vector3(12, 4.5, 0.3), wall_col)
	_box(Vector3(20, 2.25, 0), Vector3(0.3, 4.5, 12), wall_col)
	_box(Vector3(-20, 2.25, 0), Vector3(0.3, 4.5, 12), wall_col)
	# Dividers with doorways
	_divider_wall(8.0)
	_divider_wall(-8.0)
	# Garden fence: front and sides (low white fence + collision)
	_box(Vector3(0, 0.38, 16.35), Vector3(40, 0.75, 0.14), Color(0.97, 0.95, 0.92))
	_box(Vector3(20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92))
	_box(Vector3(-20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92))
	for fx in range(-19, 20, 2):
		_box(Vector3(fx, 0.88, 16.35), Vector3(0.22, 0.28, 0.10), Color(0.97, 0.95, 0.92), false)

func _build_kitchen() -> void:
	_simple_window(11.0)
	# Counter run along the back wall: real Kenney Furniture Kit units (CC0)
	var units := ["kitchenCabinetDrawer", "kitchenCabinet", "kitchenSink", "kitchenCabinet", "kitchenCabinetDrawer"]
	for i in range(units.size()):
		_model("res://assets/furniture/" + units[i] + ".glb", Vector3(8.65 + i * 0.88, 0, -5.42), 2.0)
	_model_collider(Vector3(10.41, 0.45, -5.42), Vector3(4.5, 0.9, 0.96))
	# Upper cabinets over the counter
	_model("res://assets/furniture/kitchenCabinetUpper.glb", Vector3(9.53, 1.52, -5.62), 2.0)
	_model("res://assets/furniture/kitchenCabinetUpper.glb", Vector3(11.29, 1.52, -5.62), 2.0)
	# Faucet over the sink unit (center unit, x = 10.41)
	_cylinder(self, Vector3(10.41, 1.25, -5.80), 0.035, 0.035, 0.5, Color(0.75, 0.78, 0.82), 0.0)
	var faucet := _cylinder(self, Vector3(10.41, 1.48, -5.62), 0.03, 0.03, 0.4, Color(0.75, 0.78, 0.82), 0.0)
	faucet.rotation.x = PI / 2.0
	# Fruit bowl on the counter + a little plant at the end
	_cylinder(self, Vector3(9.2, 1.06, -5.45), 0.16, 0.28, 0.14, Color(0.95, 0.55, 0.45), 0.0)
	_sphere(self, Vector3(9.05, 1.20, -5.45), 0.085, Color(1, 0.55, 0.20))
	_sphere(self, Vector3(9.35, 1.20, -5.40), 0.085, Color(0.90, 0.25, 0.25))
	_sphere(self, Vector3(9.20, 1.27, -5.52), 0.085, Color(1, 0.80, 0.25))
	_model("res://assets/furniture/plantSmall1.glb", Vector3(12.17, 0.90, -5.45), 2.6)
	# Two stoves side by side, with burner rings on top
	_model("res://assets/furniture/kitchenStove.glb", Vector3(14.85, 0, -5.42), 2.0)
	_model("res://assets/furniture/kitchenStoveElectric.glb", Vector3(15.75, 0, -5.42), 2.0)
	_model_collider(Vector3(15.3, 0.45, -5.42), Vector3(1.85, 0.9, 0.96))
	for sx in [14.85, 15.75]:
		for dx in [-0.22, 0.22]:
			for dz in [-0.20, 0.20]:
				_cylinder(self, Vector3(sx + dx, 0.915, -5.42 + dz), 0.13, 0.13, 0.02, Color(0.20, 0.20, 0.22), 0.0)
	# Fridge (Kenney model)
	_model("res://assets/furniture/kitchenFridge.glb", Vector3(18.6, 0, -5.40), 2.6)
	_model_collider(Vector3(18.6, 1.2, -5.40), Vector3(1.12, 2.4, 0.85))
	# Wall shelf with plates
	_box(Vector3(13.2, 2.2, -5.7), Vector3(2.2, 0.08, 0.5), Color(0.85, 0.64, 0.42), false)
	for i in range(3):
		var plate := _cylinder(self, Vector3(12.5 + i * 0.65, 2.42, -5.7), 0.19, 0.19, 0.03, Color(1, 1, 1), 0.0)
		plate.rotation.x = 0.35
	# Dining table + three chairs (Kenney) + pendant lamp
	_model("res://assets/furniture/tableRound.glb", Vector3(16.0, 0, 1.5), 1.9)
	_model_collider(Vector3(16.0, 0.35, 1.5), Vector3(1.7, 0.7, 1.7))
	_model("res://assets/furniture/chairRounded.glb", Vector3(14.35, 0, 1.5), 2.0, PI / 2.0)
	_model("res://assets/furniture/chairRounded.glb", Vector3(17.65, 0, 1.5), 2.0, -PI / 2.0)
	_model("res://assets/furniture/chairRounded.glb", Vector3(16.0, 0, 3.15), 2.0, PI)
	_cylinder(self, Vector3(16.0, 3.6, 1.5), 0.02, 0.02, 1.4, Color(0.4, 0.4, 0.4), 0.0)
	_cylinder(self, Vector3(16.0, 2.78, 1.5), 0.13, 0.44, 0.42, Color(1, 0.75, 0.40), 0.0)
	_sphere(self, Vector3(16.0, 2.52, 1.5), 0.10, Color(1, 0.90, 0.60), Vector3.ONE, 1.2)

func _build_bedroom() -> void:
	_simple_window(-14.0)
	# Bed: real Kenney Furniture Kit bed (CC0) against the back wall
	_model("res://assets/furniture/bedDouble.glb", Vector3(-16.8, 0, -4.35), 2.2)
	_model_collider(Vector3(-16.8, 0.42, -4.35), Vector3(2.11, 0.84, 2.46))
	# Nightstand + table lamp (Kenney)
	_model("res://assets/furniture/cabinetBedDrawerTable.glb", Vector3(-13.9, 0, -5.3), 2.4)
	_model_collider(Vector3(-13.9, 0.31, -5.3), Vector3(0.65, 0.62, 0.55))
	_model("res://assets/furniture/lampRoundTable.glb", Vector3(-13.9, 0.62, -5.3), 2.0)
	_sphere(self, Vector3(-13.9, 1.07, -5.3), 0.09, Color(1, 0.90, 0.62), Vector3.ONE, 0.9)
	# Little desk + chair + books against the divider wall
	_model("res://assets/furniture/desk.glb", Vector3(-8.62, 0, -3.4), 1.8, PI / 2.0)
	_model_collider(Vector3(-8.62, 0.34, -3.4), Vector3(1.0, 0.68, 1.35))
	_model("res://assets/furniture/chairDesk.glb", Vector3(-9.55, 0, -3.4), 1.8, PI / 2.0)
	_model("res://assets/furniture/books.glb", Vector3(-8.62, 0.69, -3.85), 1.8)
	# Wardrobe
	_box(Vector3(-10.3, 1.3, -5.35), Vector3(2.4, 2.6, 0.95), Color(0.80, 0.58, 0.38))
	_box(Vector3(-10.3, 1.3, -4.86), Vector3(0.05, 2.2, 0.04), Color(0.60, 0.42, 0.26), false)
	_sphere(self, Vector3(-10.55, 1.3, -4.84), 0.045, Color(1, 0.80, 0.30))
	_sphere(self, Vector3(-10.05, 1.3, -4.84), 0.045, Color(1, 0.80, 0.30))
	# Bookshelf against the left wall, full of colorful books
	_box(Vector3(-19.5, 1.1, -0.5), Vector3(0.7, 2.2, 3.0), Color(0.85, 0.64, 0.42))
	var book_cols := [Color(0.90, 0.35, 0.35), Color(0.35, 0.60, 0.95), Color(0.45, 0.80, 0.45), Color(0.98, 0.75, 0.30), Color(0.70, 0.50, 0.90)]
	for shelf_i in range(3):
		var sy := 0.55 + shelf_i * 0.62
		_box(Vector3(-19.42, sy, -0.5), Vector3(0.10, 0.06, 2.8), Color(0.72, 0.50, 0.30), false)
		for book_i in range(4):
			_box(Vector3(-19.42, sy + 0.20, -1.55 + book_i * 0.68), Vector3(0.28, 0.34, 0.16), book_cols[(shelf_i + book_i) % book_cols.size()], false)
	# Round rug + toy box with balls
	_cylinder(self, Vector3(-14.0, 0.015, 0.6), 1.9, 1.9, 0.03, Color(0.72, 0.55, 0.92), 0.0)
	_box(Vector3(-10.8, 0.28, 3.6), Vector3(1.3, 0.56, 0.9), Color(0.70, 0.48, 0.28))
	_sphere(self, Vector3(-11.1, 0.62, 3.5), 0.16, Color(0.95, 0.40, 0.40))
	_sphere(self, Vector3(-10.5, 0.62, 3.75), 0.16, Color(0.40, 0.65, 0.98))
	# Wall stars + a crescent moon over the bed
	for i in range(4):
		_sphere(self, Vector3(-18.6 + i * 1.5, 3.3, -5.80), 0.11, Color(1, 0.82, 0.30), Vector3(1, 1, 0.25), 0.7)
	_sphere(self, Vector3(-13.2, 3.45, -5.80), 0.20, Color(1, 0.92, 0.60), Vector3(0.8, 1, 0.25), 0.7)

func _make_tree(pos: Vector3, s: float, apples: bool) -> void:
	# A nicer tree: tapered trunk, angled branches, layered two-tone foliage
	var bark := Color(0.48, 0.33, 0.20)
	_cylinder(self, pos + Vector3(0, 0.95 * s, 0), 0.13 * s, 0.27 * s, 1.9 * s, bark, 0.0)
	var branch_data := [[-0.55, 0.5], [0.5, 0.9], [0.1, -0.55]]
	for bd in branch_data:
		var br := _cylinder(self, pos + Vector3(bd[0] * 0.45 * s, 2.05 * s, bd[1] * 0.4 * s), 0.045 * s, 0.075 * s, 1.05 * s, bark, 0.0)
		br.rotation.z = -bd[0] * 0.85
		br.rotation.x = bd[1] * 0.7
	var greens := [Color(0.22, 0.55, 0.24), Color(0.28, 0.63, 0.28), Color(0.35, 0.70, 0.32), Color(0.42, 0.76, 0.36)]
	var blobs := [
		[0.0, 3.05, 0.0, 1.18], [-0.85, 2.5, 0.25, 0.85], [0.8, 2.6, -0.2, 0.88],
		[0.1, 3.55, 0.3, 0.78], [-0.35, 2.35, -0.55, 0.68], [0.55, 2.3, 0.55, 0.66],
		[-0.15, 2.85, 0.75, 0.6],
	]
	for i in range(blobs.size()):
		var b: Array = blobs[i]
		_sphere(self, pos + Vector3(b[0] * s, b[1] * s, b[2] * s), b[3] * s, greens[i % greens.size()])
	if apples:
		var apple_spots := [[-0.9, 2.2, 0.9], [0.7, 2.9, 0.8], [-0.2, 1.95, 1.0], [1.0, 2.3, 0.3], [0.2, 3.3, 0.95], [-0.7, 3.0, 0.75]]
		for a in apple_spots:
			_sphere(self, pos + Vector3(a[0] * s, a[1] * s, a[2] * s), 0.105 * s, Color(0.92, 0.24, 0.24))
	var tree_body := StaticBody3D.new()
	var tree_shape := CollisionShape3D.new()
	var tree_cyl := CylinderShape3D.new()
	tree_cyl.radius = 0.30 * s
	tree_cyl.height = 2.0 * s
	tree_shape.shape = tree_cyl
	tree_body.add_child(tree_shape)
	tree_body.position = pos + Vector3(0, 1.0 * s, 0)
	add_child(tree_body)

const NATURE_TINT := Color(1.35, 1.6, 1.05)

func _garden_tree(path: String, pos: Vector3, scl: float, trunk_r: float) -> void:
	_model(path, pos, scl, randf() * TAU, NATURE_TINT)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = trunk_r
	cyl.height = 2.0
	shape.shape = cyl
	body.add_child(shape)
	body.position = pos + Vector3(0, 1.0, 0)
	add_child(body)

func _school_divider(R: Node3D, x: float, wall: Color, trim: Color) -> void:
	# Same wide open doorway as the house dividers, in school colors, with
	# the door panel swung fully open against the wall.
	_box(Vector3(x, 2.25, -3.8), Vector3(0.3, 4.5, 4.4), wall, true, R)
	_box(Vector3(x, 2.25, 4.0), Vector3(0.3, 4.5, 4.0), wall, true, R)
	_box(Vector3(x, 1.35, -1.68), Vector3(0.4, 2.7, 0.18), trim, false, R)
	_box(Vector3(x, 1.35, 2.08), Vector3(0.4, 2.7, 0.18), trim, false, R)
	_box(Vector3(x, 2.78, 0.2), Vector3(0.4, 0.22, 3.96), trim, false, R)
	var side := 1.0 if x > 0.0 else -1.0
	_box(Vector3(x + side * 0.21, 1.3, -2.4), Vector3(0.07, 2.6, 1.5), Color(0.62, 0.72, 0.90), true, R)
	_sphere(R, Vector3(x + side * 0.28, 1.3, -1.78), 0.05, Color(1, 0.80, 0.25), Vector3.ONE, 0.5)

func _build_school(R: Node3D) -> void:
	# LEVEL 2 WORLD — the School: classroom (left), hallway with lockers
	# (center), cafeteria + library (right), and the schoolyard out front.
	var wall := Color(0.90, 0.86, 0.74)
	var trim := Color(0.55, 0.65, 0.85)
	var f1 := _box(Vector3(-14, -0.1, 0), Vector3(12, 0.2, 12), Color(0.75, 0.78, 0.85), true, R)
	f1.material_override = _tex_mat("res://textures/tile.png", 2.0, Color(0.78, 0.82, 0.92))
	var f2 := _box(Vector3(0, -0.1, 0), Vector3(16, 0.2, 12), Color(0.85, 0.72, 0.52), true, R)
	f2.material_override = _tex_mat("res://textures/wood.png", 2.0, Color(0.88, 0.74, 0.55))
	var f3 := _box(Vector3(14, -0.1, 0), Vector3(12, 0.2, 12), Color(0.62, 0.78, 0.66), true, R)
	f3.material_override = _tex_mat("res://textures/tile.png", 2.0, Color(0.66, 0.80, 0.68))
	var yard := _box(Vector3(0, -0.1, 11.2), Vector3(40, 0.2, 10.4), Color(0.36, 0.68, 0.33), true, R)
	yard.material_override = _tex_mat("res://textures/grass.png", 10.0, Color(0.66, 0.85, 0.66))
	_box(Vector3(0, 2.25, -6), Vector3(40, 4.5, 0.3), wall, true, R)
	_box(Vector3(20, 2.25, 0), Vector3(0.3, 4.5, 12), wall, true, R)
	_box(Vector3(-20, 2.25, 0), Vector3(0.3, 4.5, 12), wall, true, R)
	_school_divider(R, -8.0, wall, trim)
	_school_divider(R, 8.0, wall, trim)
	_box(Vector3(0, 0.38, 16.35), Vector3(40, 0.75, 0.14), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(-20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92), true, R)
	# --- Classroom: blackboard with chalk writing
	_box(Vector3(-14, 2.6, -5.82), Vector3(6.6, 2.4, 0.07), Color(0.96, 0.94, 0.88), false, R)
	_box(Vector3(-14, 2.6, -5.80), Vector3(6.2, 2.1, 0.08), Color(0.15, 0.30, 0.24), false, R)
	var board_label := Label3D.new()
	board_label.text = "ABC · 123"
	board_label.font_size = 200
	board_label.pixel_size = 0.0055
	board_label.modulate = Color(0.95, 0.97, 0.95)
	board_label.position = Vector3(-14, 2.65, -5.70)
	R.add_child(board_label)
	# Pupil desks (2 rows of 3) with little chairs
	var desk_cols := [Color(0.85, 0.45, 0.40), Color(0.40, 0.60, 0.85), Color(0.45, 0.75, 0.45)]
	var di := 0
	for dz in [-2.6, 0.8]:
		for dx in [-15.5, -13.5, -11.5]:
			_box(Vector3(dx, 0.36, dz), Vector3(1.1, 0.72, 0.7), Color(0.80, 0.66, 0.48), true, R)
			_box(Vector3(dx, 0.76, dz), Vector3(1.25, 0.07, 0.85), Color(0.68, 0.52, 0.36), false, R)
			_box(Vector3(dx, 0.25, dz + 0.72), Vector3(0.55, 0.5, 0.45), desk_cols[di % 3], true, R)
			_box(Vector3(dx, 0.72, dz + 0.92), Vector3(0.55, 0.55, 0.08), desk_cols[di % 3], false, R)
			di += 1
	# Teacher's desk + a globe in the corner
	_box(Vector3(-18.3, 0.40, -4.4), Vector3(1.9, 0.8, 0.85), Color(0.55, 0.40, 0.28), true, R)
	_box(Vector3(-18.3, 0.84, -4.4), Vector3(2.05, 0.07, 1.0), Color(0.45, 0.32, 0.22), false, R)
	_cylinder(R, Vector3(-10.3, 0.5, -4.9), 0.05, 0.07, 1.0, Color(0.45, 0.32, 0.22))
	_sphere(R, Vector3(-10.3, 1.22, -4.9), 0.34, Color(0.35, 0.60, 0.90))
	_sphere(R, Vector3(-10.15, 1.32, -4.72), 0.16, Color(0.40, 0.75, 0.45))
	# Reading corner: a big round cushion (the star toy hides here)
	_cylinder(R, Vector3(-19.0, 0.16, 3.5), 0.85, 0.95, 0.32, Color(0.95, 0.55, 0.65))
	# --- Hallway: a row of rainbow lockers + bulletin board
	var locker_cols := [Color(0.88, 0.36, 0.32), Color(0.92, 0.58, 0.25), Color(0.95, 0.80, 0.30), Color(0.42, 0.75, 0.42), Color(0.36, 0.58, 0.90), Color(0.62, 0.45, 0.85)]
	for i in range(6):
		var lx := -2.75 + i * 1.1
		_box(Vector3(lx, 0.95, -5.68), Vector3(1.0, 1.9, 0.35), locker_cols[i], true, R)
		_box(Vector3(lx, 1.0, -5.48), Vector3(0.8, 1.6, 0.04), locker_cols[i] * 0.82, false, R)
		_sphere(R, Vector3(lx + 0.28, 1.0, -5.45), 0.045, Color(0.95, 0.95, 0.95))
	_box(Vector3(5.8, 2.2, -5.83), Vector3(2.7, 1.6, 0.06), Color(0.85, 0.70, 0.50), false, R)
	for p in range(4):
		var pc: Color = [Color(1, 1, 1), Color(0.95, 0.65, 0.70), Color(0.65, 0.85, 1), Color(1, 0.92, 0.60)][p]
		_box(Vector3(5.15 + (p % 2) * 1.3, 2.55 - (p / 2) * 0.7, -5.78), Vector3(0.95, 0.55, 0.03), pc, false, R)
	# --- Cafeteria + library: round tables and bookshelves
	_model("res://assets/furniture/tableRound.glb", Vector3(13.5, 0, 0.5), 1.9, 0.0, Color(1, 1, 1), R)
	_model_collider(Vector3(13.5, 0.4, 0.5), Vector3(1.6, 0.8, 1.6), R)
	_model("res://assets/furniture/tableRound.glb", Vector3(18.5, 0, -2.5), 1.9, 0.0, Color(1, 1, 1), R)
	_model_collider(Vector3(18.5, 0.4, -2.5), Vector3(1.6, 0.8, 1.6), R)
	_model("res://assets/furniture/chairRounded.glb", Vector3(12.2, 0, 0.5), 1.9, PI / 2.0, Color(1, 1, 1), R)
	_model("res://assets/furniture/chairRounded.glb", Vector3(19.8, 0, -2.5), 1.9, -PI / 2.0, Color(1, 1, 1), R)
	for sx in [15.9, 18.1]:
		_box(Vector3(sx, 0.95, -5.5), Vector3(1.9, 1.9, 0.45), Color(0.62, 0.48, 0.35), true, R)
		_box(Vector3(sx, 0.90, -5.42), Vector3(1.7, 0.06, 0.5), Color(0.50, 0.38, 0.27), false, R)
		_model("res://assets/furniture/books.glb", Vector3(sx - 0.4, 0.93, -5.45), 1.7, 0.0, Color(1, 1, 1), R)
		_model("res://assets/furniture/books.glb", Vector3(sx + 0.35, 1.55, -5.45), 1.7, 0.3, Color(1, 1, 1), R)
	# --- Schoolyard: the big oak (Lulu hides behind it, same as at home)
	_model("res://assets/nature/tree_oak.glb", Vector3(-5.5, 0, 12.3), 3.6, 0.7, NATURE_TINT, R)
	var trunk := StaticBody3D.new()
	var tshape := CollisionShape3D.new()
	var tcyl := CylinderShape3D.new()
	tcyl.radius = 0.38
	tcyl.height = 2.0
	tshape.shape = tcyl
	trunk.add_child(tshape)
	trunk.position = Vector3(-5.5, 1.0, 12.3)
	R.add_child(trunk)
	_model("res://assets/nature/tree_default.glb", Vector3(17.5, 0, 7.6), 2.6, 1.9, NATURE_TINT, R)
	# Slide: a platform Mimi can hop onto, with a shiny chute
	_box(Vector3(14.2, 0.4, 9.2), Vector3(1.5, 0.8, 1.5), Color(0.90, 0.45, 0.40), true, R)
	var chute := _box(Vector3(14.2, 0.42, 11.3), Vector3(0.95, 0.07, 3.4), Color(0.45, 0.70, 0.95), false, R)
	chute.rotation.x = 0.38
	_box(Vector3(13.65, 0.55, 11.3), Vector3(0.07, 0.3, 3.4), Color(0.35, 0.58, 0.85), false, R).rotation.x = 0.38
	_box(Vector3(14.75, 0.55, 11.3), Vector3(0.07, 0.3, 3.4), Color(0.35, 0.58, 0.85), false, R).rotation.x = 0.38
	# Swings: A-frame, top bar, two seats (the gem hides on one)
	for sx2 in [-4.4, -0.6]:
		var leg := _cylinder(R, Vector3(sx2, 1.15, 10.5), 0.05, 0.05, 2.5, Color(0.55, 0.58, 0.62))
		leg.rotation.z = 0.18 if sx2 < -2.5 else -0.18
	var bar := _cylinder(R, Vector3(-2.5, 2.32, 10.5), 0.05, 0.05, 4.0, Color(0.55, 0.58, 0.62))
	bar.rotation.z = PI / 2.0
	for seat_x in [-3.3, -1.7]:
		_cylinder(R, Vector3(seat_x - 0.22, 1.4, 10.5), 0.015, 0.015, 1.8, Color(0.4, 0.4, 0.45))
		_cylinder(R, Vector3(seat_x + 0.22, 1.4, 10.5), 0.015, 0.015, 1.8, Color(0.4, 0.4, 0.45))
		_box(Vector3(seat_x, 0.5, 10.5), Vector3(0.55, 0.05, 0.28), Color(0.85, 0.40, 0.35), true, R)
	# Sandbox with a sand floor (the duck hides here)
	_box(Vector3(-12, 0.09, 11), Vector3(3.2, 0.18, 3.2), Color(0.93, 0.84, 0.62), true, R)
	_box(Vector3(-12, 0.16, 9.32), Vector3(3.5, 0.32, 0.18), Color(0.72, 0.52, 0.35), true, R)
	_box(Vector3(-12, 0.16, 12.68), Vector3(3.5, 0.32, 0.18), Color(0.72, 0.52, 0.35), true, R)
	_box(Vector3(-13.68, 0.16, 11), Vector3(0.18, 0.32, 3.5), Color(0.72, 0.52, 0.35), true, R)
	_box(Vector3(-10.32, 0.16, 11), Vector3(0.18, 0.32, 3.5), Color(0.72, 0.52, 0.35), true, R)
	# Flag pole by the path (the rocket hides beside it)
	_cylinder(R, Vector3(0, 2.3, 9), 0.05, 0.06, 4.6, Color(0.75, 0.77, 0.80))
	_box(Vector3(0.58, 4.15, 9), Vector3(1.15, 0.65, 0.04), Color(0.90, 0.30, 0.30), false, R)
	_sphere(R, Vector3(0, 4.68, 9), 0.09, Color(1, 0.80, 0.25), Vector3.ONE, 0.4)
	# The school bus, parked along the front fence
	_box(Vector3(10.5, 1.05, 14.1), Vector3(6.8, 1.7, 2.3), Color(0.98, 0.75, 0.20), true, R)
	_box(Vector3(10.5, 2.0, 14.1), Vector3(6.9, 0.25, 2.35), Color(0.97, 0.95, 0.90), false, R)
	_box(Vector3(10.5, 1.45, 12.93), Vector3(6.2, 0.55, 0.05), Color(0.25, 0.35, 0.50), false, R)
	_box(Vector3(13.65, 1.05, 12.93), Vector3(0.7, 1.5, 0.05), Color(0.30, 0.30, 0.35), false, R)
	for wx in [8.2, 12.8]:
		for wz in [12.9, 15.3]:
			var wheel := _cylinder(R, Vector3(wx, 0.42, wz), 0.42, 0.42, 0.25, Color(0.16, 0.16, 0.18))
			wheel.rotation.x = PI / 2.0
	# Coco's corner: a bench and his rug by the fence
	_box(Vector3(5.5, 0.28, 15.3), Vector3(1.8, 0.1, 0.5), Color(0.62, 0.48, 0.35), true, R)
	_box(Vector3(5.5, 0.75, 15.55), Vector3(1.8, 0.5, 0.09), Color(0.62, 0.48, 0.35), false, R)
	_cylinder(R, Vector3(5.5, 0.03, 14.8), 0.9, 0.9, 0.05, Color(0.88, 0.45, 0.45))

func _build_gym(R: Node3D) -> void:
	# LEVEL 3 WORLD — the Gym: one big court with hoops and bleachers,
	# mats and cones, trophy shelf, and a running track out front.
	var wall := Color(0.90, 0.88, 0.80)
	var court := _box(Vector3(0, -0.1, 0), Vector3(40, 0.2, 12), Color(0.85, 0.70, 0.52), true, R)
	court.material_override = _tex_mat("res://textures/wood.png", 3.0, Color(0.95, 0.82, 0.62))
	var strip := _box(Vector3(0, -0.1, 6.5), Vector3(40, 0.2, 1.0), Color(0.36, 0.68, 0.33), true, R)
	strip.material_override = _tex_mat("res://textures/grass.png", 10.0, Color(0.66, 0.85, 0.66))
	_box(Vector3(0, -0.08, 10.5), Vector3(40, 0.24, 7.0), Color(0.72, 0.38, 0.30), true, R)
	for lz in [8.6, 10.4, 12.2]:
		_box(Vector3(0, 0.05, lz), Vector3(40, 0.02, 0.12), Color(0.97, 0.95, 0.92), false, R)
	var strip2 := _box(Vector3(0, -0.1, 15.2), Vector3(40, 0.2, 2.4), Color(0.36, 0.68, 0.33), true, R)
	strip2.material_override = _tex_mat("res://textures/grass.png", 10.0, Color(0.66, 0.85, 0.66))
	_box(Vector3(0, 2.25, -6), Vector3(40, 4.5, 0.3), wall, true, R)
	_box(Vector3(20, 2.25, 0), Vector3(0.3, 4.5, 12), wall, true, R)
	_box(Vector3(-20, 2.25, 0), Vector3(0.3, 4.5, 12), wall, true, R)
	_box(Vector3(0, 1.15, -5.82), Vector3(40, 0.5, 0.06), Color(0.30, 0.50, 0.85), false, R)
	for wx in [-13.5, -4.5, 4.5, 13.5]:
		_box(Vector3(wx, 3.5, -5.82), Vector3(3.6, 1.1, 0.06), Color(0.75, 0.87, 0.97), false, R)
	_box(Vector3(0, 0.38, 16.35), Vector3(40, 0.75, 0.14), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(-20, 0.38, 11.2), Vector3(0.14, 0.75, 10.4), Color(0.97, 0.95, 0.92), true, R)
	# Scoreboard with a cheer
	_box(Vector3(0, 3.35, -5.80), Vector3(3.6, 1.15, 0.08), Color(0.13, 0.13, 0.18), false, R)
	var go_label := Label3D.new()
	go_label.text = "GO MIMI!"
	go_label.font_size = 200
	go_label.pixel_size = 0.0055
	go_label.modulate = Color(1, 0.72, 0.25)
	go_label.position = Vector3(0, 3.35, -5.70)
	R.add_child(go_label)
	# Court markings: center line + center circle
	_box(Vector3(0, 0.012, 0), Vector3(0.18, 0.024, 12), Color(0.97, 0.95, 0.92), false, R)
	var circle := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 1.58
	tor.outer_radius = 1.78
	circle.mesh = tor
	circle.material_override = _mat(Color(0.97, 0.95, 0.92))
	circle.position = Vector3(0, 0.03, 0)
	R.add_child(circle)
	# Bleachers along the back wall (two steps Mimi can hop up)
	_box(Vector3(-2, 0.2, -4.75), Vector3(26, 0.4, 0.7), Color(0.72, 0.58, 0.42), true, R)
	_box(Vector3(-2, 0.4, -5.45), Vector3(26, 0.8, 0.7), Color(0.65, 0.51, 0.37), true, R)
	# Basketball hoops at both ends
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 17.5, 1.7, 0), Vector3(0.16, 3.4, 0.16), Color(0.45, 0.47, 0.52), true, R)
		_box(Vector3(side * 17.0, 3.32, 0), Vector3(1.0, 0.12, 0.12), Color(0.45, 0.47, 0.52), false, R)
		_box(Vector3(side * 16.45, 3.15, 0), Vector3(0.06, 1.05, 1.6), Color(0.97, 0.96, 0.94), false, R)
		_box(Vector3(side * 16.45, 3.15, 0), Vector3(0.07, 0.55, 0.85), Color(0.95, 0.55, 0.25), false, R)
		var rim := MeshInstance3D.new()
		var rtor := TorusMesh.new()
		rtor.inner_radius = 0.19
		rtor.outer_radius = 0.26
		rim.mesh = rtor
		rim.material_override = _mat(Color(0.95, 0.45, 0.20))
		rim.position = Vector3(side * 15.95, 2.95, 0)
		R.add_child(rim)
	# Exercise mats: a stack (the cupcake hides on top) + two singles
	var mat_cols := [Color(0.35, 0.55, 0.90), Color(0.90, 0.42, 0.38), Color(0.42, 0.78, 0.45)]
	for i in range(3):
		_box(Vector3(-17.5, 0.09 + i * 0.18, 4.6), Vector3(2.2, 0.18, 1.4), mat_cols[i], true, R)
	_box(Vector3(8.5, 0.06, 3.8), Vector3(2.4, 0.12, 1.5), Color(0.90, 0.42, 0.38), true, R)
	_box(Vector3(-8.0, 0.06, 4.2), Vector3(2.4, 0.12, 1.5), Color(0.35, 0.55, 0.90), true, R)
	# Cones on the court
	for cp in [Vector3(-5, 0, -2), Vector3(5, 0, 2), Vector3(-11, 0, 3), Vector3(11, 0, -3), Vector3(0, 0, 5)]:
		_cylinder(R, cp + Vector3(0, 0.21, 0), 0.02, 0.16, 0.42, Color(0.96, 0.55, 0.18))
	# Ball rack with basketballs (the star hides on top)
	_box(Vector3(-18.9, 0.45, 3.6), Vector3(0.9, 0.9, 1.6), Color(0.40, 0.42, 0.48), true, R)
	_sphere(R, Vector3(-18.7, 0.24, 5.3), 0.24, Color(0.92, 0.52, 0.22))
	_sphere(R, Vector3(-18.2, 0.24, 1.9), 0.24, Color(0.45, 0.65, 0.95))
	# Trophy shelf on the east wall (the wand hides here)
	_box(Vector3(19.5, 0.9, -2.0), Vector3(0.6, 0.07, 2.4), Color(0.62, 0.48, 0.35), true, R)
	for tz in [-2.7, -2.0, -1.3]:
		_cylinder(R, Vector3(19.5, 1.06, tz), 0.06, 0.09, 0.22, Color(1, 0.80, 0.25), 0.3)
		_cone_at(R, Vector3(19.5, 1.28, tz), 0.10, 0.22, Color(1, 0.80, 0.25))
	# Coco's rug by the east hoop
	_cylinder(R, Vector3(16.5, 0.03, 5.2), 0.9, 0.9, 0.05, Color(0.35, 0.55, 0.90))

func _beach_palm(R: Node3D, pos: Vector3, lean: float) -> void:
	# A palm tree from primitives: a leaning trunk in three segments, a ring
	# of droopy fronds on top and two coconuts. Trunk collider belongs to R.
	var bark := Color(0.55, 0.40, 0.24)
	var leaf := Color(0.30, 0.68, 0.32)
	var leaf2 := Color(0.38, 0.76, 0.38)
	var top := pos
	for i in range(3):
		var seg := _cylinder(R, pos + Vector3(lean * (0.22 + i * 0.30), 0.55 + i * 1.02, 0), 0.085 - i * 0.012, 0.13 - i * 0.012, 1.15, bark)
		seg.rotation.z = -lean * 0.30
		top = pos + Vector3(lean * (0.52 + i * 0.30), 1.05 + i * 1.02, 0)
	for i in range(6):
		var a := i * TAU / 6.0 + lean
		var frond := _sphere(R, top + Vector3(cos(a) * 0.55, 0.16 - abs(sin(a)) * 0.05, sin(a) * 0.55), 0.62, leaf if i % 2 == 0 else leaf2, Vector3(1.5, 0.16, 0.42))
		frond.rotation.y = -a
	_sphere(R, top + Vector3(0, 0.10, 0), 0.30, leaf2, Vector3(1, 0.7, 1))
	_sphere(R, top + Vector3(0.14, -0.16, 0.06), 0.09, Color(0.45, 0.32, 0.18))
	_sphere(R, top + Vector3(-0.10, -0.18, -0.08), 0.085, Color(0.45, 0.32, 0.18))
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.22
	cyl.height = 3.0
	shape.shape = cyl
	body.add_child(shape)
	body.position = pos + Vector3(lean * 0.35, 1.5, 0)
	R.add_child(body)

func _beach_umbrella(R: Node3D, pos: Vector3, color: Color) -> void:
	# A beach umbrella: tilted pole + big cone canopy. Only the pole is solid.
	var pole := _cylinder(R, pos + Vector3(0, 1.0, 0), 0.035, 0.045, 2.0, Color(0.92, 0.90, 0.86))
	pole.rotation.z = 0.10
	var canopy := _cone_at(R, pos + Vector3(0.10, 2.02, 0), 1.18, 0.52, color)
	canopy.rotation.z = 0.10
	_sphere(R, pos + Vector3(0.16, 2.34, 0), 0.06, color)
	_model_collider(pos + Vector3(0, 0.9, 0), Vector3(0.18, 1.8, 0.18), R)

func _build_beach(R: Node3D) -> void:
	# LEVEL 4 WORLD — the Beach: warm sand, palm trees, umbrellas, a
	# sandcastle, a lifeguard chair, and the ocean lapping at the front.
	var sand := Color(0.93, 0.84, 0.62)
	# Sand floor, plus a lower wet-sand strip under the shallow water
	_box(Vector3(0, -0.1, 4.0), Vector3(40, 0.2, 20), sand, true, R)
	_box(Vector3(0, -0.16, 15.2), Vector3(40, 0.2, 2.6), Color(0.85, 0.74, 0.52), true, R)
	# The ocean: a blue sheet over the front strip, with white foam lines
	_box(Vector3(0, -0.04, 15.25), Vector3(40, 0.1, 2.9), Color(0.20, 0.55, 0.95), false, R)
	_box(Vector3(0, 0.015, 13.95), Vector3(40, 0.03, 0.4), Color(0.99, 0.99, 0.97), false, R)
	_box(Vector3(0, 0.008, 14.75), Vector3(40, 0.02, 0.18), Color(0.82, 0.93, 1.0), false, R)
	# Low fences on the back and sides (the ocean closes the front)
	_box(Vector3(0, 0.38, -5.9), Vector3(40, 0.75, 0.14), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(20, 0.38, 4.0), Vector3(0.14, 0.75, 20), Color(0.97, 0.95, 0.92), true, R)
	_box(Vector3(-20, 0.38, 4.0), Vector3(0.14, 0.75, 20), Color(0.97, 0.95, 0.92), true, R)
	# A welcome sign across the back of the beach
	_box(Vector3(-1.9, 1.0, -5.55), Vector3(0.16, 2.0, 0.16), Color(0.62, 0.46, 0.30), true, R)
	_box(Vector3(1.9, 1.0, -5.55), Vector3(0.16, 2.0, 0.16), Color(0.62, 0.46, 0.30), true, R)
	_box(Vector3(0, 1.95, -5.55), Vector3(4.6, 1.05, 0.10), Color(0.85, 0.64, 0.42), false, R)
	var sign_label := Label3D.new()
	sign_label.text = "MIMI'S BEACH!"
	sign_label.font_size = 190
	sign_label.pixel_size = 0.0055
	sign_label.modulate = Color(0.98, 0.50, 0.55)
	sign_label.position = Vector3(0, 1.95, -5.46)
	R.add_child(sign_label)
	# Two candy-colored beach huts along the back fence
	for hx in [-14.5, 13.5]:
		var hut_col := Color(0.35, 0.75, 0.80) if hx < 0.0 else Color(0.98, 0.55, 0.45)
		_box(Vector3(hx, 1.0, -5.15), Vector3(3.4, 2.0, 1.3), hut_col, true, R)
		var roof := _box(Vector3(hx, 2.12, -5.15), Vector3(3.9, 0.12, 1.8), Color(0.97, 0.95, 0.90), false, R)
		roof.rotation.z = 0.10
		_box(Vector3(hx, 0.85, -4.46), Vector3(0.9, 1.7, 0.06), Color(0.40, 0.30, 0.22), false, R)
	# Palm trees: Lulu's palm at the water's edge, plus shade around the sand
	_beach_palm(R, Vector3(-16.2, 0, 11.9), 0.7)
	_beach_palm(R, Vector3(4.5, 0, -4.4), -0.6)
	_beach_palm(R, Vector3(17.0, 0, 6.2), 0.8)
	_beach_palm(R, Vector3(-7.5, 0, -4.2), -0.8)
	_beach_palm(R, Vector3(-1.5, 0, 12.6), 0.5)
	_model("res://assets/nature/plant_bushLarge.glb", Vector3(-17.6, 0, 10.2), 2.2, 0.4, NATURE_TINT, R)
	# Umbrellas with towels spread underneath
	_beach_umbrella(R, Vector3(-11.0, 0, 5.2), Color(0.98, 0.50, 0.62))
	_box(Vector3(-10.2, 0.025, 5.0), Vector3(1.7, 0.05, 2.3), Color(0.98, 0.80, 0.35), false, R)
	_beach_umbrella(R, Vector3(2.5, 0, 0.8), Color(0.30, 0.75, 0.80))
	_box(Vector3(3.1, 0.025, 1.9), Vector3(1.7, 0.05, 2.3), Color(0.55, 0.85, 0.95), false, R)
	_beach_umbrella(R, Vector3(15.5, 0, -1.5), Color(0.98, 0.62, 0.28))
	_box(Vector3(14.6, 0.025, -0.4), Vector3(1.7, 0.05, 2.3), Color(0.98, 0.60, 0.70), false, R)
	# Coco's towel, right by the water (his hangout on this level)
	_box(Vector3(14.0, 0.03, 13.2), Vector3(1.9, 0.05, 1.3), Color(0.95, 0.45, 0.45), false, R)
	# A picnic blanket (the cupcake hides here)
	_box(Vector3(-1.5, 0.035, 8.2), Vector3(2.0, 0.07, 1.6), Color(0.95, 0.55, 0.60), false, R)
	# Sandcastle: a stout base she can hop on, corner towers, and a keep
	_box(Vector3(-6.5, 0.375, 3.0), Vector3(2.4, 0.75, 2.4), Color(0.90, 0.78, 0.55), true, R)
	for cx in [-0.85, 0.85]:
		for cz in [-0.85, 0.85]:
			_cylinder(R, Vector3(-6.5 + cx, 0.5, 3.0 + cz), 0.30, 0.34, 1.0, Color(0.92, 0.80, 0.57))
			_cone_at(R, Vector3(-6.5 + cx, 1.14, 3.0 + cz), 0.42, 0.30, Color(0.98, 0.55, 0.45))
	_box(Vector3(-6.5, 1.0, 3.0), Vector3(1.0, 0.5, 1.0), Color(0.92, 0.80, 0.57), true, R)
	_cone_at(R, Vector3(-6.5, 1.38, 3.0), 0.30, 0.26, Color(0.98, 0.55, 0.45))
	# A bucket and spade abandoned by the castle
	_cylinder(R, Vector3(-4.8, 0.14, 4.4), 0.15, 0.12, 0.28, Color(0.98, 0.45, 0.55))
	_box(Vector3(-4.45, 0.05, 4.15), Vector3(0.08, 0.05, 0.3), Color(0.35, 0.75, 0.85), false, R)
	# Lifeguard chair: steps up the back, a wide seat on top (fish + star)
	_box(Vector3(11, 0.6, 7.5), Vector3(1.7, 1.2, 1.2), Color(0.92, 0.90, 0.86), true, R)
	_box(Vector3(11, 0.2, 6.5), Vector3(1.4, 0.4, 0.6), Color(0.85, 0.83, 0.78), true, R)
	_box(Vector3(11, 0.4, 6.95), Vector3(1.4, 0.8, 0.5), Color(0.88, 0.86, 0.81), true, R)
	_box(Vector3(11, 1.16, 7.5), Vector3(1.9, 0.08, 1.4), Color(0.98, 0.50, 0.45), true, R)
	_box(Vector3(11, 1.75, 8.14), Vector3(1.9, 1.1, 0.08), Color(0.98, 0.50, 0.45), false, R)
	_cylinder(R, Vector3(11, 2.62, 7.5), 0.04, 0.04, 0.85, Color(0.92, 0.90, 0.86))
	_cone_at(R, Vector3(11, 3.25, 7.5), 1.05, 0.45, Color(0.98, 0.85, 0.30))
	# Rocks at the waterline and two buoys bobbing in the shallows
	_model("res://assets/nature/rock_smallA.glb", Vector3(18.8, 0, 12.6), 1.8, 0.3, Color(1.15, 1.15, 1.15), R)
	_model("res://assets/nature/rock_smallC.glb", Vector3(-18.9, 0, 14.6), 1.7, 1.2, Color(1.15, 1.15, 1.15), R)
	for bx in [-8.0, 9.0]:
		_sphere(R, Vector3(bx, 0.05, 15.4), 0.28, Color(0.95, 0.30, 0.28))
		_torus(R, Vector3(bx, 0.05, 15.4), 0.20, 0.30, Color(1, 1, 1))
	# Shells and starfish scattered on the sand
	var shell_spots := [Vector3(-3.0, 0.05, 12.8), Vector3(7.8, 0.05, 12.2), Vector3(-13.5, 0.05, 8.6), Vector3(12.5, 0.05, 10.8), Vector3(1.8, 0.05, -2.2), Vector3(-9.5, 0.05, -1.0)]
	for i in range(shell_spots.size()):
		_sphere(R, shell_spots[i], 0.10, Color(1, 0.88, 0.90) if i % 2 == 0 else Color(0.98, 0.78, 0.65), Vector3(1, 0.4, 1))
	for sp in [Vector3(-5.2, 0.04, 9.6), Vector3(9.8, 0.04, 3.4), Vector3(-14.8, 0.04, 1.8)]:
		_sphere(R, sp, 0.15, Color(0.98, 0.60, 0.25), Vector3(1, 0.30, 1))
		_sphere(R, sp + Vector3(0, 0.03, 0), 0.06, Color(1, 0.72, 0.35))

func _build_garden() -> void:
	# Trees: real Kenney Nature Kit models (CC0). The hero oak keeps its apples.
	_garden_tree("res://assets/nature/tree_oak.glb", Vector3(-5.5, 0, 12.3), 3.6, 0.38)
	var apple_spots := [Vector3(-6.35, 3.05, 13.05), Vector3(-4.75, 3.45, 13.15), Vector3(-5.65, 2.75, 13.45), Vector3(-4.55, 2.95, 12.55), Vector3(-6.25, 3.55, 12.45), Vector3(-5.15, 3.85, 13.25)]
	for a in apple_spots:
		_sphere(self, a, 0.12, Color(0.92, 0.24, 0.24))
	_garden_tree("res://assets/nature/tree_default.glb", Vector3(16.5, 0, 13.0), 2.6, 0.34)
	_garden_tree("res://assets/nature/tree_fat.glb", Vector3(-16.5, 0, 13.5), 3.0, 0.36)
	_garden_tree("res://assets/nature/tree_pineRoundA.glb", Vector3(18.2, 0, 8.8), 2.5, 0.30)
	_garden_tree("res://assets/nature/tree_cone.glb", Vector3(-18.4, 0, 10.8), 2.4, 0.28)
	_garden_tree("res://assets/nature/tree_small.glb", Vector3(11.5, 0, 14.8), 2.1, 0.20)
	_garden_tree("res://assets/nature/tree_small.glb", Vector3(-11.8, 0, 7.3), 2.1, 0.20)
	# Grass tufts scattered around (Kenney grass models; not on the path or toy spots)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in range(46):
		var tx := rng.randf_range(-19.0, 19.0)
		var tz := rng.randf_range(6.6, 15.8)
		if abs(tx) < 1.2 and tz < 13.5:
			continue  # keep the path clear
		if Vector2(tx, tz).distance_to(Vector2(-3.2, 10.6)) < 1.2:
			continue  # keep the beach ball spot clear
		var gpath := "res://assets/nature/grass.glb" if i % 3 != 0 else "res://assets/nature/grass_leafs.glb"
		_model(gpath, Vector3(tx, 0, tz), rng.randf_range(1.5, 2.1), rng.randf() * TAU, NATURE_TINT)
	# Flowers (Kenney models) sprinkled around the garden
	var flower_kinds := ["flower_redA", "flower_purpleA", "flower_yellowA", "flower_redB", "flower_purpleB", "flower_yellowC"]
	var flower_spots := [Vector3(2.2, 0, 8.2), Vector3(-2.4, 0, 13.8), Vector3(6.5, 0, 10.5), Vector3(-8.5, 0, 14.8), Vector3(-9, 0, 8), Vector3(-11, 0, 12), Vector3(9.5, 0, 9), Vector3(12, 0, 13.5), Vector3(3.5, 0, 14.5), Vector3(-14, 0, 9.5), Vector3(15, 0, 8.5), Vector3(-2.5, 0, 15.2)]
	for i in range(flower_spots.size()):
		_model("res://assets/nature/" + flower_kinds[i % flower_kinds.size()] + ".glb", flower_spots[i], 1.8, rng.randf() * TAU)
	# Stepping-stone path (Kenney stone slabs)
	for i in range(4):
		_model("res://assets/nature/path_stone.glb", Vector3(0.0, 0.01, 7.0 + i * 1.55), 1.6, (0.12 if i % 2 == 0 else -0.12))
	# Bushes: by the fence, flanking the doghouse, along the house wall
	_model("res://assets/nature/plant_bushDetailed.glb", Vector3(18.6, 0, 15.2), 2.3, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushDetailed.glb", Vector3(-18.6, 0, 15.2), 2.3, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushDetailed.glb", Vector3(-18.8, 0, 7.2), 2.0, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushLarge.glb", Vector3(5.5, 0, 14.9), 2.2, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushLarge.glb", Vector3(8.5, 0, 14.9), 2.2, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushSmall.glb", Vector3(-4.5, 0, 6.4), 1.9, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushSmall.glb", Vector3(3.2, 0, 6.4), 1.9, 0.0, NATURE_TINT)
	_model("res://assets/nature/plant_bushSmall.glb", Vector3(13.5, 0, 6.4), 1.9, 0.0, NATURE_TINT)
	# Rocks, mushrooms, a stump and a log for exploring corners
	_model("res://assets/nature/rock_smallA.glb", Vector3(14.2, 0, 15.3), 1.8, 0.0, Color(1.15, 1.15, 1.15))
	_model("res://assets/nature/rock_smallC.glb", Vector3(-13.8, 0, 15.6), 1.8, 0.0, Color(1.15, 1.15, 1.15))
	_model("res://assets/nature/rock_largeB.glb", Vector3(-18.3, 0, 15.5), 1.35, 0.0, Color(1.15, 1.15, 1.15))
	_model("res://assets/nature/mushroom_redGroup.glb", Vector3(-4.3, 0, 13.6), 1.9, 0.0, NATURE_TINT)
	_model("res://assets/nature/mushroom_red.glb", Vector3(15.3, 0, 14.3), 1.9, 0.0, NATURE_TINT)
	_model("res://assets/nature/stump_round.glb", Vector3(10.8, 0, 12.6), 1.9)
	_model("res://assets/nature/log.glb", Vector3(12.1, 0, 13.4), 1.9, 0.8)
	# Coco's doghouse
	_box(Vector3(7.0, 0.45, 13.8), Vector3(1.5, 0.9, 1.4), Color(0.80, 0.45, 0.30))
	_box(Vector3(7.0, 0.35, 14.52), Vector3(0.8, 0.7, 0.05), Color(0.30, 0.20, 0.15), false)
	var roof_l := _box(Vector3(6.62, 1.15, 13.8), Vector3(1.05, 0.08, 1.6), Color(0.55, 0.30, 0.22), false)
	roof_l.rotation.z = 0.6
	var roof_r := _box(Vector3(7.38, 1.15, 13.8), Vector3(1.05, 0.08, 1.6), Color(0.55, 0.30, 0.22), false)
	roof_r.rotation.z = -0.6
	# Butterfly (animated in _process; wings flap around body pivots)
	butterfly = Node3D.new()
	butterfly.position = Vector3(-2.0, 1.25, 11.0)
	add_child(butterfly)
	_sphere(butterfly, Vector3.ZERO, 0.045, Color(0.30, 0.22, 0.30), Vector3(1, 1, 1.8))
	var pivot_l := Node3D.new()
	butterfly.add_child(pivot_l)
	_sphere(pivot_l, Vector3(-0.11, 0.02, 0), 0.10, Color(1, 0.60, 0.80), Vector3(1.3, 0.25, 1))
	butterfly_wing_l = pivot_l
	var pivot_r := Node3D.new()
	butterfly.add_child(pivot_r)
	_sphere(pivot_r, Vector3(0.11, 0.02, 0), 0.10, Color(1, 0.60, 0.80), Vector3(1.3, 0.25, 1))
	butterfly_wing_r = pivot_r
