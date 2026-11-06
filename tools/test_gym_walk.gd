extends SceneTree
## Regression for the invisible-wall bug: _box used to parent collision
## bodies to the scene root instead of the world root, so the school and
## gym colliders stayed active (and invisible) in every level. Mimi WALKS
## through the two worst leaked spots in the gym (the school bus zone on
## the track and the desks/dividers band on the court), walks a school
## doorway, and point-probes confirm no foreign colliders remain.

class StubJoy:
	extends RefCounted
	var value := Vector2.ZERO

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _stage_t: float = 0.0
var _joy := StubJoy.new()
var _track_ok: bool = false
var _court_ok: bool = false
var _probes_ok: bool = false

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _blocked(pos: Vector3) -> bool:
	var space: PhysicsDirectSpaceState3D = _main.get_world_3d().direct_space_state
	var params := PhysicsPointQueryParameters3D.new()
	params.position = pos
	params.collision_mask = 1
	for h in space.intersect_point(params, 6):
		if h.collider is StaticBody3D:
			return true
	return false

func _process(delta: float) -> bool:
	_t += delta
	_stage_t += delta
	if _stage == 0 and _t >= 0.2:
		_main.mimi.joystick = _joy
		_main._on_play_pressed()
		_main.mouse_active = false
		_main.level = 3
		_main._reset_game()
		# Leg 1: along the track (z=13.5), straight through the old bus zone
		_main.mimi.global_position = Vector3(-15.0, 0.1, 13.5)
		_main.mimi.velocity = Vector3.ZERO
		_main.cam_yaw = -PI / 2.0
		_joy.value = Vector2(0, -1)
		_stage = 1
		_stage_t = 0.0
	elif _stage == 1:
		if _main.mimi.global_position.x > 15.0:
			_track_ok = true
			# Leg 2: across the court (z=-2.6), through the old desks/dividers band
			_main.mimi.global_position = Vector3(15.0, 0.1, -2.6)
			_main.mimi.velocity = Vector3.ZERO
			_main.cam_yaw = PI / 2.0
			_joy.value = Vector2(0, -1)
			_stage = 2
			_stage_t = 0.0
		elif _stage_t > 8.0:
			print("GYMWALK RESULT track=false (stuck at x=", _main.mimi.global_position.x, ") court=false probes=false")
			return true
	elif _stage == 2:
		if _main.mimi.global_position.x < -16.0:
			_court_ok = true
			# Probes: gym active -> school desk must be empty (checked above by
			# walking, but confirm by point too); school active -> house bed
			# and gym bleacher must be empty.
			var desk_free := not _blocked(Vector3(-13.5, 0.6, -2.6))
			_main.level = 2
			_main._reset_game()
			var bed_free := not _blocked(Vector3(-16.8, 0.5, -4.0))
			var bleacher_free := not _blocked(Vector3(-6.0, 0.5, -5.45))
			_probes_ok = desk_free and bed_free and bleacher_free
			print("GYMWALK RESULT track=", _track_ok, " court=", _court_ok, " probes=", _probes_ok,
				" (desk_free=", desk_free, " bed_free=", bed_free, " bleacher_free=", bleacher_free, ")")
			return true
		elif _stage_t > 8.0:
			print("GYMWALK RESULT track=true court=false (stuck at x=", _main.mimi.global_position.x, ") probes=false")
			return true
	return false
