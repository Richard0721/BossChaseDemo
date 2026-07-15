@tool
class_name RapidGunMountSettings
extends Resource

@export_category("右手快速枪调整")
@export var model_position := Vector3.ZERO
@export var model_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var model_scale := 55.0

