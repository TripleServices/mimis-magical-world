extends SceneTree
## The Mouse cycle test: (1) he cannot steal while Mimi holds no toy;
## (2) bumping into Mimi snatches her latest toy and Coco starts chasing;
## (3) Coco catches him and the toy drops, pickable again; (4) Mimi re-collects it.

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _stage_t: float = 0.0
var _nosteel_ok: bool = false
var _steal_ok: bool = false
var _catch_ok: bool = false
var _recollect_ok: bool = false
var _hunt_ok: bool = false
var _imp_ok: bool = false
var _two_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _goto_mimi(body: Node3D, offset: Vector3) -> void:
	body.global_position = _main.mimi.global_position + offset
	if body is CharacterBody3D:
		(body as CharacterBody3D).velocity = Vector3.ZERO

func _process(delta: float) -> bool:
	_t += delta
	_stage_t += delta
	if _stage == 0 and _t >= 0.2:
		_main._on_play_pressed()
		_main.mimi.global_position = Vector3(0, 0.1, 11.5)  # open garden
		_goto_mimi(_main.mice[0].body, Vector3(0.5, 0, 0))
		_stage = 1
		_stage_t = 0.0
	elif _stage == 1 and _stage_t >= 1.0:
		_nosteel_ok = _main.mice[0].carry == null and _main.collected == 0
		print("MOUSE nosteel check: carry=", _main.mice[0].carry, " collected=", _main.collected)
		# Collect the beach ball (toy 7, in the garden)
		var toy: Dictionary = _main.toys[7]
		_main.mimi.velocity = Vector3.ZERO
		_main.mimi.global_position = (toy.root as Node3D).global_position + Vector3(0, 0.05, 0)
		_stage = 2
		_stage_t = 0.0
	elif _stage == 2:
		if _main.collected == 1:
			_goto_mimi(_main.mice[0].body, Vector3(0.4, 0, 0.3))
			_stage = 3
			_stage_t = 0.0
		elif _stage_t > 4.0:
			print("MOUSE RESULT collect-timeout")
			return true
	elif _stage == 3:
		if _main.mice[0].carry != null:
			_steal_ok = _main.collected == 0 and _main.coco_state == "chase"
			print("MOUSE steal check: collected=", _main.collected, " coco_state=", _main.coco_state)
			_stage = 4
			_stage_t = 0.0
		elif _stage_t > 3.0:
			print("MOUSE RESULT steal-timeout")
			return true
	elif _stage == 4:
		if _main.mice[0].carry == null:
			var toy: Dictionary = _main.toys[7]
			_catch_ok = toy.taken == false and (toy.area as Area3D).monitoring
			print("MOUSE catch check after ", _stage_t, "s: taken=", toy.taken, " monitoring=", (toy.area as Area3D).monitoring, " drop_pos=", (toy.root as Node3D).global_position)
			_main.mimi.velocity = Vector3.ZERO
			_main.mimi.global_position = (toy.root as Node3D).global_position + Vector3(0, 0.05, 0)
			_stage = 5
			_stage_t = 0.0
		elif _stage_t > 18.0:
			print("MOUSE RESULT catch-timeout coco_state=", _main.coco_state)
			return true
	elif _stage == 5:
		if _main.collected == 1:
			_recollect_ok = true
			# HUNT check: park the mouse 5 m away (grabs disabled via a long
			# cooldown); if he hunts, he should close to under 1.3 m by himself.
			_main.mice[0].cooldown = 999.0
			_main.mice[0].flee = 0.0  # he just got caught; cancel the panic so the hunt check is clean
			_goto_mimi(_main.mice[0].body, Vector3(0, 0, -5.0))
			_stage = 6
			_stage_t = 0.0
		elif _stage_t > 4.0:
			print("MOUSE RESULT recollect-timeout nosteel=", _nosteel_ok, " steal=", _steal_ok, " catch=", _catch_ok)
			return true
	elif _stage == 6 and _stage_t >= 2.2:
		var dh: Vector3 = _main.mimi.global_position - _main.mice[0].body.global_position
		dh.y = 0.0
		_hunt_ok = dh.length() < 1.3
		print("MOUSE hunt check: dist_after=", dh.length())
		# IMPOSSIBLE check: top speed toward Mimi across the open garden
		_main.difficulty = 3
		_main.mimi.global_position = Vector3(0, 0.1, 11.0)
		_main.mice[0].body.global_position = Vector3(0, 0.1, 4.5)
		_main.mice[0].body.velocity = Vector3.ZERO
		_stage = 7
		_stage_t = 0.0
	elif _stage == 7 and _stage_t >= 1.0:
		var v: Vector3 = _main.mice[0].body.velocity
		var spd := Vector2(v.x, v.z).length()
		_imp_ok = spd > 4.5
		print("MOUSE impossible check: hunt_speed=", spd, " difficulty=", _main.DIFFS[_main.difficulty].name)
		# TWO MICE check: still on Impossible, a fresh run must wake mouse 2,
		# and mouse 2 must be able to steal on his own.
		_main._reset_game()
		var m2: Dictionary = _main.mice[1]
		print("MOUSE two check: count=", _main.mice.size(), " m2_active=", m2.active, " m2_visible=", (m2.body as Node3D).visible)
		if _main.mice.size() == 2 and m2.active and (m2.body as Node3D).visible:
			var toy0: Dictionary = _main.toys[0]
			_main.mimi.velocity = Vector3.ZERO
			_main.mimi.global_position = (toy0.root as Node3D).global_position + Vector3(0, 0.05, 0)
			_stage = 8
		else:
			print("MOUSE RESULT nosteel=", _nosteel_ok, " steal=", _steal_ok, " catch=", _catch_ok, " recollect=", _recollect_ok, " hunt=", _hunt_ok, " impossible=", _imp_ok, " two=false (mouse 2 not active)")
			return true
		_stage_t = 0.0
	elif _stage == 8:
		if _main.collected >= 1:
			# Park mouse 1 far away with grabs disabled; bring mouse 2 to Mimi
			_main.mice[0].cooldown = 999.0
			_main.mice[0].body.global_position = Vector3(17.8, 0.1, -4.6)
			_main.mice[1].cooldown = 0.0
			_goto_mimi(_main.mice[1].body, Vector3(0.4, 0, 0.3))
			_stage = 9
			_stage_t = 0.0
		elif _stage_t > 5.0:
			print("MOUSE RESULT two=false (collect timeout in two-mice stage)")
			return true
	elif _stage == 9:
		if _main.mice[1].carry != null:
			_two_ok = true
			print("MOUSE RESULT nosteel=", _nosteel_ok, " steal=", _steal_ok, " catch=", _catch_ok, " recollect=", _recollect_ok, " hunt=", _hunt_ok, " impossible=", _imp_ok, " two=", _two_ok)
			return true
		elif _stage_t > 3.0:
			print("MOUSE RESULT nosteel=", _nosteel_ok, " steal=", _steal_ok, " catch=", _catch_ok, " recollect=", _recollect_ok, " hunt=", _hunt_ok, " impossible=", _imp_ok, " two=false (mouse 2 never stole)")
			return true
	return false
