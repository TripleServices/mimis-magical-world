extends SceneTree
## Play Store screenshots from the current build (Blender Mimi + teddy):
## house L1, school L2, gym L3, beach L4, and the shop in Android buy-only mode.
## Run under Xvfb (headless has no rendering):
##   xvfb-run -a godot --path . --resolution 1280x720 --script res://tools/shot_play.gd

var _main: Node
var _frames: int = 0
var _shot_dir: String

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_shot_dir = ProjectSettings.globalize_path("res://play-store/screenshots")

func _shot(name: String) -> void:
	var img := root.get_texture().get_image()
	img.save_png(_shot_dir + "/" + name)
	print("SHOT saved ", name)

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 10:
		_main._on_play_pressed()
		_main.mouse_active = false
	if _frames == 80:
		_shot("01-house-level1.png")
	if _frames == 90:
		_main.level = 2
		_main._reset_game()
	if _frames == 160:
		_shot("02-school-level2.png")
	if _frames == 170:
		_main.level = 3
		_main._reset_game()
	if _frames == 240:
		_shot("03-gym-level3.png")
	if _frames == 250:
		_main.level = 4
		_main._reset_game()
	if _frames == 320:
		_shot("04-beach-level4.png")
	if _frames == 330:
		_main.buy_only = true
		_main._open_shop()
		# La tienda se construyó al arrancar (buy_only=false en escritorio);
		# el texto de Android (buy_only=true) es este, así que se pone a mano.
		_main.shop_hint.text = "Get coin packs to dress Mimi up!"
	if _frames == 380:
		_shot("05-shop-buyonly.png")
		print("PLAY SHOTS DONE")
		return true
	return false
