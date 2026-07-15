@tool
class_name RuneRuntimeScaleHandle
extends Node3D

@export var runtime_settings: RuneModelSettings

var _initialized := false
var _last_uniform_scale := 0.06


func _ready() -> void:
	_load_runtime_scale()
	_reduce_preview_emission()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	if not _initialized:
		_load_runtime_scale()
		return
	var differences := Vector3(
		absf(scale.x - _last_uniform_scale),
		absf(scale.y - _last_uniform_scale),
		absf(scale.z - _last_uniform_scale)
	)
	var greatest_difference := maxf(differences.x, maxf(differences.y, differences.z))
	if greatest_difference > 0.000001:
		var new_scale := scale.x
		if differences.y >= differences.x and differences.y >= differences.z:
			new_scale = scale.y
		elif differences.z >= differences.x and differences.z >= differences.y:
			new_scale = scale.z
		new_scale = clampf(absf(new_scale), 0.005, 2.0)
		scale = Vector3.ONE * new_scale
		_last_uniform_scale = new_scale
		_save_runtime_scale(new_scale)
	elif runtime_settings != null and not is_equal_approx(runtime_settings.model_scale, _last_uniform_scale):
		_load_runtime_scale()


func _load_runtime_scale() -> void:
	if runtime_settings == null:
		return
	_last_uniform_scale = runtime_settings.model_scale
	scale = Vector3.ONE * _last_uniform_scale
	_initialized = true


func _save_runtime_scale(new_scale: float) -> void:
	if runtime_settings == null or is_equal_approx(runtime_settings.model_scale, new_scale):
		return
	runtime_settings.model_scale = new_scale
	runtime_settings.emit_changed()
	if not runtime_settings.resource_path.is_empty():
		ResourceSaver.save(runtime_settings, runtime_settings.resource_path)


func _reduce_preview_emission() -> void:
	if runtime_settings == null:
		return
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate(true) as StandardMaterial3D
				material.emission_energy_multiplier = runtime_settings.model_emission_energy
				mesh_instance.set_surface_override_material(surface_index, material)
