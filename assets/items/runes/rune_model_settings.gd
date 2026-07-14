@tool
class_name RuneModelSettings
extends Resource

@export_category("符文模型调整")
@export var model_position := Vector3(0.0, 1.0, 0.0)
@export var model_rotation_degrees := Vector3.ZERO
@export_range(0.005, 2.0, 0.005) var model_scale := 0.06
@export_category("柔和发光")
@export_range(0.0, 2.0, 0.05) var model_emission_energy := 0.45
@export_range(0.0, 4.0, 0.05) var light_energy := 1.25
@export_range(1.0, 10.0, 0.1) var light_range := 4.5
@export_range(0.5, 2.0, 0.05) var halo_scale := 1.0
