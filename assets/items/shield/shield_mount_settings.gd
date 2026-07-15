@tool
class_name ShieldMountSettings
extends Resource

@export_category("左前臂盾牌调整")
@export var model_position := Vector3(0.0, 0.18, 0.0)
@export var model_rotation_degrees := Vector3.ZERO
@export_range(0.05, 1.5, 0.01) var model_scale := 0.45

