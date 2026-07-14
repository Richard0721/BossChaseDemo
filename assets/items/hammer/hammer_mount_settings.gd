@tool
class_name HammerMountSettings
extends Resource

@export_category("右手锤子调整")
@export var model_position := Vector3.ZERO
@export var model_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var model_scale := 55.0

