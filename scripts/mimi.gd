extends CharacterBody3D
## Mimi the Kitty: a chibi 3D cat built from primitives (white fur, upright ears,
## dark eyes with a pink tint, pink collar with a gold heart tag).
## Moves with keyboard (WASD/arrows + Space) or the virtual joystick + jump button.

const SPEED := 3.4
const RUN_SPEED := 5.8
const RUN_AFTER := 1.1  # seconds of nonstop walking before she breaks into a run
const JUMP_VELOCITY := 5.4
const GRAVITY := 14.0

var joystick = null  # the virtual joystick control; has a `value: Vector2`
var move_enabled: bool = false
var camera_yaw: float = 0.0  # set by main.gd; movement is relative to the camera

var _visual: Node3D
var _leg_fl: Node3D
var _leg_fr: Node3D
var _leg_bl: Node3D
var _leg_br: Node3D
var _tail_pivot: Node3D
var _head_pivot: Node3D
var _walk_phase: float = 0.0
var _idle_time: float = 0.0
var _facing: float = 0.0  # y rotation, model faces +Z
var _walk_time: float = 0.0
var _speed_now: float = SPEED
var _lean: float = 0.0
var _hop_pending: bool = false
var running: bool = false

func _ready() -> void:
	add_to_group("player")
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.30
	capsule.height = 0.85
	shape.shape = capsule
	shape.position.y = 0.45
	add_child(shape)
	floor_snap_length = 0.3
	_build_model()

# ---------------------------------------------------------------- model building

# Mimi ahora es el modelo de Blender (tools/blender/mimi/mimi_rig.py):
# un GLB con pivotes separados (LegFL/FR/BL/BR, Tail, Head) que se animan
# igual que el modelo procedural anterior. La cara mira +Z, como antes.
func _build_model() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var packed := load("res://assets/mimi/mimi-blender.glb") as PackedScene
	var inst := packed.instantiate() as Node3D
	_visual.add_child(inst)
	_leg_fl = inst.find_child("LegFL", true, false)
	_leg_fr = inst.find_child("LegFR", true, false)
	_leg_bl = inst.find_child("LegBL", true, false)
	_leg_br = inst.find_child("LegBR", true, false)
	_tail_pivot = inst.find_child("Tail", true, false)
	_head_pivot = inst.find_child("Head", true, false)

# ---------------------------------------------------------------- movement

func try_jump() -> void:
	if move_enabled and is_on_floor():
		velocity.y = JUMP_VELOCITY

func celebrate_hop() -> void:
	# Little hop of joy (used when she finds a toy or a friend). If she is
	# mid-jump when it triggers, the hop waits until she lands.
	if is_on_floor():
		velocity.y = 4.6
	else:
		_hop_pending = true

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			try_jump()

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if move_enabled:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			input_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			input_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			input_dir.y -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			input_dir.y += 1.0
		if joystick != null and joystick.value.length() > 0.12:
			input_dir = joystick.value
		if input_dir.length() > 1.0:
			input_dir = input_dir.normalized()

	# Movement is relative to the camera: screen-up (input y<0) means
	# "away from the camera", whichever way the player has orbited it.
	var dir3 := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, camera_yaw)
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var moving := dir3.length() > 0.05
	if moving:
		_walk_time += delta
	else:
		_walk_time = 0.0
	running = moving and _walk_time >= RUN_AFTER
	var target_speed := RUN_SPEED if running else SPEED
	_speed_now = move_toward(_speed_now, target_speed, delta * 5.0)
	if moving:
		velocity.x = dir3.x * _speed_now
		velocity.z = dir3.z * _speed_now
		var target_facing := atan2(dir3.x, dir3.z)
		_facing = lerp_angle(_facing, target_facing, 1.0 - pow(0.0001, delta))
	else:
		velocity.x = move_toward(velocity.x, 0.0, _speed_now * delta * 8.0)
		velocity.z = move_toward(velocity.z, 0.0, _speed_now * delta * 8.0)
	move_and_slide()
	if _hop_pending and is_on_floor():
		_hop_pending = false
		velocity.y = 4.6
	# Stay inside the whole house + garden
	position.x = clamp(position.x, -19.35, 19.35)
	position.z = clamp(position.z, -5.35, 15.75)
	_visual.rotation.y = _facing
	_animate(delta, moving)

func _animate(delta: float, walking: bool) -> void:
	_idle_time += delta
	if walking:
		var rate := 17.0 if running else 11.0
		_walk_phase += delta * rate
		var swing := sin(_walk_phase) * (0.72 if running else 0.55)
		_set_leg_rot(_leg_fl, swing)
		_set_leg_rot(_leg_br, swing)
		_set_leg_rot(_leg_fr, -swing)
		_set_leg_rot(_leg_bl, -swing)
		_visual.position.y = abs(sin(_walk_phase)) * (0.07 if running else 0.045)
		_tail_pivot.rotation.y = sin(_walk_phase * 0.7) * 0.35
		_head_pivot.rotation.z = sin(_walk_phase) * 0.03
		# She leans into the run
		_lean = move_toward(_lean, 0.13 if running else 0.0, delta * 0.8)
		_visual.rotation.x = _lean
	else:
		_walk_phase = 0.0
		_lean = move_toward(_lean, 0.0, delta * 0.8)
		_visual.rotation.x = _lean
		for leg in [_leg_fl, _leg_fr, _leg_bl, _leg_br]:
			_set_leg_rot(leg, 0.0)
		# Gentle breathing + happy tail wag
		_visual.position.y = sin(_idle_time * 2.0) * 0.012
		_tail_pivot.rotation.y = sin(_idle_time * 2.6) * 0.22
		_head_pivot.rotation.z = sin(_idle_time * 1.3) * 0.02
	if not is_on_floor():
		_visual.position.y = 0.02

func _set_leg_rot(leg: Node3D, rot_x: float) -> void:
	leg.rotation.x = rot_x
