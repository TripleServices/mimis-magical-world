extends SceneTree
## Beach (level 4) test: four worlds exist, the beach timer is 105s, the
## gym win flows into the beach, mouse 2 is always on at level 4, winning
## the beach ends the game at the menu — and collision isolation holds both
## ways: school/gym furniture spots are FREE while the beach is active, and
## beach-only obstacles block ONLY while the beach is active (the level-3
## invisible-walls bug must never come back).

var _main: Node
var _t: float = 0.0
var _stage: int = 0
var _r := {}

# Points inside school/gym furniture (solid in their own worlds)
const SCHOOL_DESK := Vector3(-16.5, 0.5, -2.6)
const GYM_STAGE := Vector3(0, 0.5, -5.3)
# Beach-only obstacles: the lifeguard chair block and Lulu's palm trunk
const BEACH_CHAIR := Vector3(11, 0.6, 7.5)
const BEACH_PALM := Vector3(-15.95, 1.0, 11.9)

func _initialize() -> void:
	var packed: PackedScene = load("res://scenes/main.tscn")
	_main = packed.instantiate()
	root.add_child(_main)

func _blocked(pos: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = pos
	q.collision_mask = 1
	var hits := root.get_world_3d().direct_space_state.intersect_point(q)
	for h in hits:
		if h["collider"] is StaticBody3D:
			return true
	return false

func _process(delta: float) -> bool:
	_t += delta
	match _stage:
		0:
			if _t >= 0.5:
				_r["worlds"] = _main.world_roots.size() == 4 and _main.world_roots[3].name == "BeachWorld"
				_r["time105"] = _main.LEVEL_TIMES.size() == 4 and absf(_main.LEVEL_TIMES[3] - 105.0) < 0.01
				_main._set_world(3)  # activate the beach, probe after it settles
				_stage = 1
				_t = 0.0
		1:
			if _t >= 0.5:
				_r["iso_school_free"] = not _blocked(SCHOOL_DESK)
				_r["iso_gym_free"] = not _blocked(GYM_STAGE)
				_r["chair_blocked"] = _blocked(BEACH_CHAIR)
				_r["palm_blocked"] = _blocked(BEACH_PALM)
				_main._set_world(0)  # back in the house, probe for leaks
				_stage = 2
				_t = 0.0
		2:
			if _t >= 0.5:
				_r["no_leak_chair"] = not _blocked(BEACH_CHAIR)
				_r["no_leak_palm"] = not _blocked(BEACH_PALM)
				_r["house_desk_free"] = not _blocked(SCHOOL_DESK)
				# Level flow: winning the gym (3) must land on the beach (4)
				_main._on_play_pressed()
				_main.mouse_active = false
				_main.level = 3
				_main._show_win()
				_main._advance_after_win()
				_r["flow"] = _main.level == 4 and _main.world_roots[3].visible \
					and absf(_main.time_left - 105.0) < 0.5 \
					and _main.level_label.text.contains("Beach")
				_main.difficulty = 0
				_main._apply_mice()
				_r["mouse2"] = _main.mice[1].active
				# Winning the beach is the final win: back to the menu
				_main._show_win()
				_main._advance_after_win()
				_r["final"] = _main.start_overlay.visible and not _main.game_started
				print("BEACH RESULT worlds=", _r["worlds"], " time105=", _r["time105"],
					" iso_school_free=", _r["iso_school_free"], " iso_gym_free=", _r["iso_gym_free"],
					" chair_blocked=", _r["chair_blocked"], " palm_blocked=", _r["palm_blocked"],
					" no_leak_chair=", _r["no_leak_chair"], " no_leak_palm=", _r["no_leak_palm"],
					" house_desk_free=", _r["house_desk_free"], " flow=", _r["flow"],
					" mouse2=", _r["mouse2"], " final=", _r["final"])
				return true
	return false
