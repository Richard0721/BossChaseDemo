class_name BluePurpleSmoke
extends Node3D

@export_range(0.2, 4.0, 0.05) var effect_size := 1.0
@export var blue_color := Color(0.18, 0.48, 1.0, 0.78)
@export var purple_color := Color(0.58, 0.18, 1.0, 0.72)
@export_range(3, 20, 1) var puff_count := 9


func _ready() -> void:
	for index in puff_count:
		_create_puff(index)
	get_tree().create_timer(1.0).timeout.connect(queue_free)


func _create_puff(index: int) -> void:
	var puff := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	puff.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mix_weight := float(index) / maxf(float(puff_count - 1), 1.0)
	var color := blue_color.lerp(purple_color, mix_weight)
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.8
	puff.material_override = material
	var angle := TAU * float(index) / float(puff_count) + randf_range(-0.24, 0.24)
	var radius := randf_range(0.06, 0.24) * effect_size
	puff.position = Vector3(cos(angle) * radius, randf_range(-0.04, 0.12), sin(angle) * radius)
	puff.scale = Vector3.ONE * randf_range(0.45, 0.75) * effect_size
	add_child(puff)
	var duration := randf_range(0.55, 0.88)
	var target_position := puff.position + Vector3(cos(angle) * randf_range(0.25, 0.55), randf_range(0.35, 0.8), sin(angle) * randf_range(0.25, 0.55)) * effect_size
	var tween := create_tween().set_parallel(true)
	tween.tween_property(puff, "position", target_position, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(puff, "scale", Vector3.ONE * randf_range(1.2, 1.8) * effect_size, duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color", Color(color.r, color.g, color.b, 0.0), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
