class_name BuffComponent
extends Node

const BASE_BUFF_DURATION := 30.0

var player: ThirdPersonPlayer
var speed_time := 0.0
var attack_time := 0.0
var defense_time := 0.0
var defense_hit_available := false
var _speed_visual: MeshInstance3D
var _attack_left_visual: MeshInstance3D
var _attack_right_visual: MeshInstance3D
var _defense_visual: MeshInstance3D


func _ready() -> void:
	player = get_parent() as ThirdPersonPlayer


func _process(delta: float) -> void:
	speed_time = maxf(0.0, speed_time - delta)
	attack_time = maxf(0.0, attack_time - delta)
	defense_time = maxf(0.0, defense_time - delta)
	if defense_time <= 0.0:
		defense_hit_available = false
	_update_visual_state()


func apply_rune(rune_type: StringName) -> void:
	var character_special: CharacterSpecial = player.get_character_special()
	character_special.on_rune_touched(rune_type)
	match rune_type:
		&"Heal":
			_apply_area_heal()
		&"Speed":
			speed_time = BASE_BUFF_DURATION * character_special.get_rune_duration_multiplier(rune_type)
			_ensure_speed_visual()
		&"Attack":
			attack_time = BASE_BUFF_DURATION * character_special.get_rune_duration_multiplier(rune_type)
			_ensure_attack_visuals()
		&"Defense":
			defense_time = BASE_BUFF_DURATION * character_special.get_rune_duration_multiplier(rune_type)
			defense_hit_available = true
			_ensure_defense_visual()
			if player.has_method("reset_shield_durability"):
				player.reset_shield_durability()


func get_move_multiplier() -> float:
	return 1.3 if speed_time > 0.0 else 1.0


func get_attack_multiplier() -> float:
	return 1.3 if attack_time > 0.0 else 1.0


func get_attack_speed_multiplier() -> float:
	return 1.3 if attack_time > 0.0 else 1.0


func has_speed_rune() -> bool:
	return speed_time > 0.0


func try_block_damage() -> bool:
	if defense_time > 0.0 and defense_hit_available:
		defense_hit_available = false
		_spawn_heal_or_block_flash(Color(1.0, 0.95, 0.62, 0.65), 1.7)
		return true
	return false


func get_damage_taken_multiplier() -> float:
	return 0.7 if defense_time > 0.0 else 1.0


func get_status_text() -> String:
	var entries: Array[String] = []
	if speed_time > 0.0:
		entries.append("SPD %.0fs" % speed_time)
	if attack_time > 0.0:
		entries.append("ATK %.0fs" % attack_time)
	if defense_time > 0.0:
		entries.append("SHIELD %.0fs" % defense_time)
	return "  |  ".join(entries)


func _apply_area_heal() -> void:
	for teammate in get_tree().get_nodes_in_group("players"):
		if teammate is Node3D and player.global_position.distance_to(teammate.global_position) <= 9.0:
			if teammate.has_method("heal"):
				teammate.heal(teammate.max_health * 0.5)
	_spawn_heal_or_block_flash(Color(0.1, 1.0, 0.38, 0.42), 4.2)


func _ensure_speed_visual() -> void:
	if is_instance_valid(_speed_visual):
		return
	_speed_visual = _create_sphere_visual(Color(0.05, 0.45, 1.0, 0.2), 1.05)


func _ensure_attack_visuals() -> void:
	if not is_instance_valid(_attack_left_visual):
		_attack_left_visual = _create_sphere_visual(Color(1.0, 0.05, 0.04, 0.5), 0.28, Vector3(-0.62, 0.25, 0))
	if not is_instance_valid(_attack_right_visual):
		_attack_right_visual = _create_sphere_visual(Color(1.0, 0.05, 0.04, 0.5), 0.28, Vector3(0.62, 0.25, 0))


func _ensure_defense_visual() -> void:
	if is_instance_valid(_defense_visual):
		return
	_defense_visual = _create_sphere_visual(Color(1.0, 0.94, 0.62, 0.18), 1.45)


func _update_visual_state() -> void:
	if is_instance_valid(_speed_visual):
		_speed_visual.visible = speed_time > 0.0
	if is_instance_valid(_attack_left_visual):
		_attack_left_visual.visible = attack_time > 0.0
	if is_instance_valid(_attack_right_visual):
		_attack_right_visual.visible = attack_time > 0.0
	if is_instance_valid(_defense_visual):
		_defense_visual.visible = defense_time > 0.0 and defense_hit_available


func _create_sphere_visual(color: Color, radius: float, offset := Vector3.ZERO) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0)
	material.emission_energy_multiplier = 1.8
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.position = offset
	player.add_child.call_deferred(visual)
	return visual


func _spawn_heal_or_block_flash(color: Color, radius: float) -> void:
	var effect := _create_sphere_visual(color, radius)
	get_tree().create_timer(0.3).timeout.connect(effect.queue_free)
