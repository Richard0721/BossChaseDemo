extends Node3D

@onready var idle_model: HappyStudentModel = $IdleModel
@onready var pointing_model: HappyStudentModel = $PointingModel


func _ready() -> void:
	idle_model.play_animation(&"idle")
	pointing_model.play_animation(&"pointing")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
