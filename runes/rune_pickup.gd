@tool
class_name RunePickup
extends Area3D

const RUNE_COLORS := {
	&"Heal": Color(0.08, 1.0, 0.35, 1.0),
	&"Speed": Color(0.05, 0.42, 1.0, 1.0),
	&"Attack": Color(1.0, 0.08, 0.06, 1.0),
	&"Defense": Color(1.0, 0.92, 0.58, 1.0),
}
const RUNE_LABELS := {
	&"Heal": "HEAL RUNE",
	&"Speed": "SPEED RUNE",
	&"Attack": "ATTACK RUNE",
	&"Defense": "DEFENSE RUNE",
}
const RUNE_MODELS := {
	&"Heal": preload("res://assets/items/runes/source/Fuwen1/Fuwengreen.fbx"),
	&"Speed": preload("res://assets/items/runes/source/Fuwen2/FuwenBlue.fbx"),
	&"Attack": preload("res://assets/items/runes/source/Fuwen3/FuwenRed.fbx"),
	&"Defense": preload("res://assets/items/runes/source/Fuwen4/Fuwenyellow.fbx"),
}
const RUNE_SETTINGS := {
	&"Heal": preload("res://assets/items/runes/heal_rune_settings.tres"),
	&"Speed": preload("res://assets/items/runes/speed_rune_settings.tres"),
	&"Attack": preload("res://assets/items/runes/attack_rune_settings.tres"),
	&"Defense": preload("res://assets/items/runes/defense_rune_settings.tres"),
}

@export_enum("Heal", "Speed", "Attack", "Defense") var rune_type := "Heal"
@export var lifetime := 60.0

var _model_instance: Node3D
var _settings: RuneModelSettings


func configure(new_type: StringName, new_lifetime: float) -> void:
	rune_type = String(new_type)
	lifetime = new_lifetime


func _ready() -> void:
	add_to_group("rune_pickups")
	if not Engine.is_editor_hint() and not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	_build_model()
	_apply_appearance()


func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		lifetime -= delta
		if lifetime <= 0.0:
			queue_free()
			return
		rotation.y += delta * 1.2
	_apply_visual_settings()
	if not Engine.is_editor_hint() and _settings != null:
		$ModelPivot.position.y += sin(Time.get_ticks_msec() * 0.0035) * 0.12


func _build_model() -> void:
	var rune_key := StringName(rune_type)
	_settings = RUNE_SETTINGS.get(rune_key) as RuneModelSettings
	if is_instance_valid(_model_instance):
		_model_instance.queue_free()
	var packed := RUNE_MODELS.get(rune_key) as PackedScene
	if packed == null:
		return
	_model_instance = packed.instantiate()
	$ModelPivot.add_child(_model_instance)
	_reduce_model_emission()


func _apply_appearance() -> void:
	var rune_key := StringName(rune_type)
	$Label3D.text = RUNE_LABELS.get(rune_key, "RUNE")
	var color: Color = RUNE_COLORS.get(rune_key, Color.WHITE)
	var halo_material := StandardMaterial3D.new()
	halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	halo_material.albedo_color = Color(color.r, color.g, color.b, 0.075)
	halo_material.emission_enabled = true
	halo_material.emission = Color(color.r, color.g, color.b, 1.0)
	halo_material.emission_energy_multiplier = 0.3
	$Halo.material_override = halo_material
	$OmniLight3D.light_color = color
	_apply_visual_settings()


func _apply_visual_settings() -> void:
	if _settings == null:
		return
	$ModelPivot.position = _settings.model_position
	$ModelPivot.rotation_degrees = _settings.model_rotation_degrees
	$ModelPivot.scale = Vector3.ONE * _settings.model_scale
	$Halo.position = _settings.model_position
	$Halo.scale = Vector3.ONE * _settings.halo_scale
	$OmniLight3D.position = _settings.model_position
	$OmniLight3D.light_energy = _settings.light_energy
	$OmniLight3D.omni_range = _settings.light_range
	$Label3D.position = _settings.model_position + Vector3.UP * 1.25


func _reduce_model_emission() -> void:
	if not is_instance_valid(_model_instance) or _settings == null:
		return
	for mesh_node in _model_instance.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface_index in mesh_instance.mesh.get_surface_count():
			var source_material := mesh_instance.get_surface_override_material(surface_index)
			if source_material == null:
				source_material = mesh_instance.mesh.surface_get_material(surface_index)
			if source_material is StandardMaterial3D:
				var material := source_material.duplicate(true) as StandardMaterial3D
				material.emission_energy_multiplier = _settings.model_emission_energy
				mesh_instance.set_surface_override_material(surface_index, material)


func _on_body_entered(body: Node3D) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()):
		return
	if body.has_method("apply_rune"):
		body.apply_rune(StringName(rune_type))
		queue_free()
