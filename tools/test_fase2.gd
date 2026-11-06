extends SceneTree
## Fase 2 functional test: (1) Mimi breaks into a run after ~1.1 s of walking,
## (2) collecting a toy triggers her happy hop (upward velocity right after),
## (3) walking up to Lulu behind the oak marks her as found and shows her label.

class StubJoy:
	extends RefCounted
	var value := Vector2.ZERO

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _joy := StubJoy.new()
var _run_ok: bool = false
var _run_speed: float = 0.0
var _hop_max_vy: float = 0.0
var _hop_ok: bool = false
var _lulu_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _process(delta: float) -> bool:
	_t += delta
	if _stage == 0 and _t >= 0.2:
		_main._on_play_pressed()
		_main.mimi.joystick = _joy
		_joy.value = Vector2(0, 1)  # hold "south" toward the garden: a long open run
		_stage = 1
	elif _stage == 1 and _t >= 2.4:
		var v: Vector3 = _main.mimi.velocity
		_run_speed = Vector2(v.x, v.z).length()
		_run_ok = _main.mimi.running and _run_speed > 4.5
		print("FASE2 run check: running=", _main.mimi.running, " speed=", _run_speed)
		_joy.value = Vector2.ZERO
		_stage = 2
	elif _stage == 2 and _t >= 2.8:
		# Teleport onto the ball toy and watch for the happy hop
		var toy: Dictionary = _main.toys[0]
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = (toy.root as Node3D).global_position + Vector3(0, 0.05, 0)
		_stage = 3
	elif _stage == 3:
		if _main.collected >= 1:
			_hop_max_vy = max(_hop_max_vy, _main.mimi.velocity.y)
			if _t >= 3.6:
				_hop_ok = _hop_max_vy > 2.0
				print("FASE2 hop check: collected=", _main.collected, " max_vy=", _hop_max_vy)
				# Now go meet Lulu behind the oak, with 20 s left on the clock:
				# finding her must grant +40 s (so the clock should jump to ~59)
				_main.time_left = 20.0
				_main.mimi.velocity = Vector3.ZERO
				_main.mimi.global_position = Vector3(-5.3, 0.1, 12.3)
				_stage = 4
	elif _stage == 4 and _t >= 4.4:
		_lulu_ok = _main.lulu_found and _main.lulu_label.visible and _main.time_left > 55.0
		print("FASE2 lulu check: found=", _main.lulu_found, " label=", _main.lulu_label.visible, " text='", _main.lulu_label.text, "' time_left=", _main.time_left)
		print("FASE2 RESULT run=", _run_ok, " hop=", _hop_ok, " lulu=", _lulu_ok)
		return true
	return false
