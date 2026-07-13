class_name PauseUI
extends CanvasLayer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	AudioManager.connect_button_tree(self)
	$Shade/Panel/Content/Resume.pressed.connect(resume_game)
	$Shade/Panel/Content/MainMenu.pressed.connect(return_to_main_menu)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back"):
		if visible:
			resume_game()
		else:
			pause_game()
		get_viewport().set_input_as_handled()


func pause_game() -> void:
	AudioManager.play_pause_toggle()
	visible = true
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func resume_game() -> void:
	AudioManager.play_pause_toggle()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func return_to_main_menu() -> void:
	AudioManager.play_ui_back()
	visible = false
	get_tree().paused = false
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.open_main_menu()
