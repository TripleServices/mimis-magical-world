extends Control
## Big friendly jump button for touch and mouse. Emits `pressed` once per tap.

signal pressed

var _is_down: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _input(event: InputEvent) -> void:
	var inside := get_global_rect().grow(16).has_point(_event_pos(event))
	if event is InputEventScreenTouch:
		if event.pressed and inside and not _is_down:
			_is_down = true
			pressed.emit()
			queue_redraw()
		elif not event.pressed:
			_is_down = false
			queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and inside and not _is_down:
			_is_down = true
			pressed.emit()
			queue_redraw()
		elif not event.pressed:
			_is_down = false
			queue_redraw()

func _event_pos(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		return event.position
	return Vector2(-9999, -9999)

func _draw() -> void:
	var center := size * 0.5
	var radius: float = minf(size.x, size.y) * 0.46
	var fill := Color(1, 0.62, 0.78, 0.85) if _is_down else Color(1, 0.62, 0.78, 0.6)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0, TAU, 48, Color(1, 1, 1, 0.8), 4.0)
	# Up arrow (jump!)
	var w := radius * 0.42
	var h := radius * 0.30
	var arrow := PackedVector2Array([
		center + Vector2(0, -h),
		center + Vector2(w, h * 0.55),
		center + Vector2(w * 0.38, h * 0.55),
		center + Vector2(w * 0.38, h),
		center + Vector2(-w * 0.38, h),
		center + Vector2(-w * 0.38, h * 0.55),
		center + Vector2(-w, h * 0.55),
	])
	draw_colored_polygon(arrow, Color(1, 1, 1, 0.95))
