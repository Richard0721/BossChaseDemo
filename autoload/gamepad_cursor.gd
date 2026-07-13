extends Node

@export var cursor_speed := 920.0
@export var stick_deadzone := 0.18

func _process(delta: float) -> void:
	var joypads := Input.get_connected_joypads()
	if joypads.is_empty():
		return
	var joypad_id: int = joypads[0]
	var stick := Vector2(
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(joypad_id, JOY_AXIS_LEFT_Y)
	)
	if stick.length() >= stick_deadzone:
		var viewport_size := get_viewport().get_visible_rect().size
		var next_position := get_viewport().get_mouse_position() + stick * cursor_speed * delta
		next_position.x = clampf(next_position.x, 1.0, viewport_size.x - 1.0)
		next_position.y = clampf(next_position.y, 1.0, viewport_size.y - 1.0)
		Input.warp_mouse(next_position)
	if Input.is_action_just_pressed("controller_confirm"):
		_emit_mouse_button(true)
		_emit_mouse_button.bind(false).call_deferred()


func _emit_mouse_button(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = get_viewport().get_mouse_position()
	event.global_position = event.position
	Input.parse_input_event(event)
