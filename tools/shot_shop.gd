extends SceneTree
## Captures the shop open with Mimi wearing the crown, glasses and pearls.

var _main: Node
var _frames: int = 0
var _shot_dir: String

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)
	_shot_dir = ProjectSettings.globalize_path("res://tools/shots")

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 8:
		_main._add_coins(500)
		_main._on_shop_buy("crown")
		_main._on_shop_buy("star_glasses")
		_main._on_shop_buy("pearls")
		_main._open_shop()
	if _frames == 45:
		var img := root.get_texture().get_image()
		img.save_png(_shot_dir + "/shot-shop.png")
		print("SHOP SHOT DONE coins=", _main.coins)
		return true
	return false
