extends Node


func _enter_tree() -> void:
	_add_key_action("move_forward", KEY_W)
	_add_key_action("move_backward", KEY_S)
	_add_key_action("move_left", KEY_A)
	_add_key_action("move_right", KEY_D)
	_add_key_action("sprint", KEY_SHIFT)
	_add_key_action("jump", KEY_SPACE)
	_add_key_action("toggle_lock", KEY_Q)
	_add_key_action("interact", KEY_F)
	_add_key_action("discard_item", KEY_G)
	_add_key_action("toggle_scoreboard", KEY_TAB)
	_add_key_action("reload", KEY_R)
	_add_key_action("fly_down", KEY_CTRL)
	_add_key_action("spectate_previous", KEY_Q)
	_add_key_action("spectate_next", KEY_E)
	_add_mouse_action("ranged_attack", MOUSE_BUTTON_LEFT)
	_add_mouse_action("aim", MOUSE_BUTTON_RIGHT)
	_add_joy_button_action("controller_confirm", JOY_BUTTON_B)
	_add_joy_button_action("controller_back", JOY_BUTTON_A)
	_add_joy_button_action("spectate_previous", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy_button_action("spectate_next", JOY_BUTTON_RIGHT_SHOULDER)


func _add_key_action(action_name: StringName, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action_name, event)


func _add_mouse_action(action_name: StringName, button: MouseButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	if not InputMap.action_get_events(action_name).is_empty():
		return
	var event := InputEventMouseButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)


func _add_joy_button_action(action_name: StringName, button: JoyButton) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for existing_event in InputMap.action_get_events(action_name):
		if existing_event is InputEventJoypadButton and existing_event.button_index == button:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button
	InputMap.action_add_event(action_name, event)
