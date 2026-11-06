extends Control
## Virtual joystick for touch and mouse. Reads input anywhere inside its rect.
## `value` is a Vector2 in a unit circle: x = right, y = down (screen space).

var value: Vector2 = Vector2.ZERO
var _pointer_id: int = -999

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _center() -> Vector2:
	return size * 0.5

func _radius() -> float:
	return minf(size.x, size.y) * 0.42

func _input(event: InputEvent) -> void:
	var local_ok := get_global_rect().grow(30).has_point(_event_pos(event))
	if event is InputEventScreenTouch:
		if event.pressed and _pointer_id == -999 and local_ok:
			_pointer_id = event.index
			_update_value(event.position)
		elif not event.pressed and event.index == _pointer_id:
			_pointer_id = -999
			value = Vector2.ZERO
			queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == _pointer_id:
			_update_value(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _pointer_id == -999 and local_ok:
				_pointer_id = -1
				_update_value(event.position)
			elif not event.pressed and _pointer_id == -1:
				_pointer_id = -999
				value = Vector2.ZERO
				queue_redraw()
	elif event is InputEventMouseMotion:
		if _pointer_id == -1:
			_update_value(event.position)

func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch or event is InputEventScreenDrag or event is InputEventMouseButton or event is InputEventMouseMotion:
		return event.position
	return Vector2.ZERO

func _update_value(screen_pos: Vector2) -> void:
	var local := screen_pos - get_global_rect().position
	var radius := _radius()
	var offset := local - _center()
	if offset.length() > radius:
		offset = offset.normalized() * radius
	value = offset / radius if radius > 0.0 else Vector2.ZERO
	queue_redraw()

func _draw() -> void:
	var center := _center()
	var radius := _radius()
	if radius <= 0.0:
		return
	var base_col := Color(1, 1, 1, 0.25)
	var ring_col := Color(1, 1, 1, 0.55)
	var knob_col := Color(1, 1, 1, 0.75)
	draw_circle(center, radius, base_col)
	draw_arc(center, radius, 0, TAU, 48, ring_col, 4.0)
	draw_circle(center + value * radius * 0.62, radius * 0.42, knob_col)
