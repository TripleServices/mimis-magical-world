extends SceneTree
## Door test: Mimi WALKS (joystick, no teleports) from the living room into
## the kitchen through the x=8 doorway, then from the living room into the
## bedroom through the x=-8 doorway.

class StubJoy:
	extends RefCounted
	var value := Vector2.ZERO

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _stage_t: float = 0.0
var _joy := StubJoy.new()
var _kitchen_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	_stage_t += delta
	if _stage == 0 and _t >= 0.2:
		_main.mimi.joystick = _joy
		_main._on_play_pressed()
		_main.mouse_active = false
		# Living room, facing the kitchen: with cam_yaw=-PI/2, joystick "up"
		# walks Mimi toward +X (test_camera established the mapping).
		_main.mimi.global_position = Vector3(5.0, 0.1, 0.2)
		_main.mimi.velocity = Vector3.ZERO
		_main.cam_yaw = -PI / 2.0
		_joy.value = Vector2(0, -1)
		_stage = 1
		_stage_t = 0.0
	elif _stage == 1:
		if _main.mimi.global_position.x > 9.5:
			_kitchen_ok = true
			print("DOORS kitchen: walked through, x=", _main.mimi.global_position.x)
			# Round two: living room to the bedroom through the x=-8 doorway
			_main.mimi.global_position = Vector3(-5.0, 0.1, 0.2)
			_main.mimi.velocity = Vector3.ZERO
			_main.cam_yaw = PI / 2.0
			_joy.value = Vector2(0, -1)
			_stage = 2
			_stage_t = 0.0
		elif _stage_t > 5.0:
			print("DOORS RESULT kitchen=false (stuck at x=", _main.mimi.global_position.x, ")")
			return true
	elif _stage == 2:
		if _main.mimi.global_position.x < -9.5:
			print("DOORS RESULT kitchen=true bedroom=true")
			return true
		elif _stage_t > 5.0:
			print("DOORS RESULT kitchen=true bedroom=false (stuck at x=", _main.mimi.global_position.x, ")")
			return true
	return false
