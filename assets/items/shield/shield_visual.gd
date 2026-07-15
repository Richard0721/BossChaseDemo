@tool
class_name ShieldVisual
extends Node3D

@export var mount_settings: ShieldMountSettings


func _ready() -> void:
	_apply_mount_settings()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_mount_settings()


func _apply_mount_settings() -> void:
	if mount_settings == null:
		return
	var adjustment := get_node_or_null("ModelAdjustment__在这里调") as Node3D
	if adjustment == null:
		return
	adjustment.position = mount_settings.model_position
	adjustment.rotation_degrees = mount_settings.model_rotation_degrees
	adjustment.scale = Vector3.ONE * mount_settings.model_scale

