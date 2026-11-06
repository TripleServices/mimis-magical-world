extends SceneTree
## Roblox-style camera test: (1) a touch drag on free screen space orbits the
## camera, as does a right-mouse drag; (2) with the camera orbited 90 degrees,
## pushing the joystick "up" walks Mimi away from the camera (toward -X);
## (3) the camera physically sits at the orbited offset around Mimi.

class StubJoy:
	extends RefCounted
	var value := Vector2.ZERO

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _joy := StubJoy.new()
var _drag_ok: bool = false
var _move_ok: bool = false
var _pos_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if _stage == 0 and _t >= 0.2:
		_main._on_play_pressed()
		_main.mimi.joystick = _joy
		# --- synthetic touch drag on free space (top-center of the screen)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.pressed = true
		press.position = Vector2(640, 200)
		_main._input(press)
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = Vector2(690, 200)
		drag.relative = Vector2(50, 0)
		_main._input(drag)
		var after_touch: float = _main.cam_yaw
		var release := InputEventScreenTouch.new()
		release.index = 0
		release.pressed = false
		release.position = Vector2(690, 200)
		_main._input(release)
		# --- synthetic right-mouse drag
		var mm := InputEventMouseMotion.new()
		mm.button_mask = MOUSE_BUTTON_MASK_RIGHT
		mm.relative = Vector2(25, 0)
		_main._input(mm)
		_drag_ok = abs(after_touch - (-0.4)) < 0.05 and abs(_main.cam_yaw - (-0.6)) < 0.05
		print("CAMERA drag check: after_touch_yaw=", after_touch, " after_mouse_yaw=", _main.cam_yaw)
		# --- orbit 90 degrees and push "up": Mimi must head toward -X
		_main.cam_yaw = PI / 2.0
		_joy.value = Vector2(0, -1)
		_stage = 1
	elif _stage == 1 and _t >= 1.3:
		var v: Vector3 = _main.mimi.velocity
		_move_ok = v.x < -2.0 and abs(v.z) < 0.8
		var off: Vector3 = _main.camera.global_position - _main.mimi.global_position
		_pos_ok = off.x > 4.0 and abs(off.z) < 1.5
		print("CAMERA move check: vel=", v, " cam_offset=", off)
		print("CAMERA RESULT drag=", _drag_ok, " move=", _move_ok, " pos=", _pos_ok)
		return true
	return false
