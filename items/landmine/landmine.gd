extends Node3D

const EXPLOSIVE_SCENE := preload("res://items/explosive/explosive.tscn")

var activation_time := 1.0
var armed := false
var source_owner: Node
var triggered := false
var damage := 40.0
var blast_radius := 5.0
var horizontal_force := 0.0
var vertical_force := 26.0
var tumble_duration := 1.35


func set_source_owner(new_source_owner: Node) -> void:
	source_owner = new_source_owner


func _process(delta: float) -> void:
	if triggered:
		return
	if not armed:
		activation_time -= delta
		$Status.text = "ARMING %.1f" % maxf(0.0, activation_time)
		if activation_time <= 0.0:
			armed = true
			$Status.text = "ARMED"
			$OmniLight3D.light_color = Color(1, 0.05, 0.02, 1)
		return
	for group_name in ["players", "lock_targets"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if target is Node3D and global_position.distance_to(target.global_position) <= 2.2:
				_trigger()
				return


func _trigger() -> void:
	if triggered:
		return
	triggered = true
	for target in _collect_targets(blast_radius):
		if target.has_method("apply_blast_effect"):
			target.apply_blast_effect(damage, global_position, horizontal_force, vertical_force, tumble_duration, source_owner)
			continue
		if target.has_method("apply_damage"):
			target.apply_damage(damage, source_owner)
		if target.has_method("apply_knockback"):
			target.apply_knockback(global_position, horizontal_force, vertical_force)
		if target.has_method("apply_tumble"):
			target.apply_tumble(tumble_duration)
	_spawn_blast_visual()
	call_deferred("queue_free")


func _collect_targets(check_radius: float) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var affected: Dictionary = {}
	var scene := get_tree().current_scene
	if scene != null:
		for node_name in ["Player", "Boss"]:
			var direct_target := scene.get_node_or_null(node_name)
			if direct_target is Node3D and global_position.distance_to(direct_target.global_position) <= check_radius:
				affected[direct_target.get_instance_id()] = true
				targets.append(direct_target)
	for group_name in ["players", "ai_teammates", "lock_targets"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if not target is Node3D or affected.has(target.get_instance_id()):
				continue
			if global_position.distance_to(target.global_position) <= check_radius:
				affected[target.get_instance_id()] = true
				targets.append(target)
	return targets


func _spawn_blast_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = blast_radius
	mesh.height = blast_radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.32, 0.02, 0.42)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.16, 0.02, 1.0)
	material.emission_energy_multiplier = 4.0
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(visual)
	visual.global_position = global_position
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.25, 0.18)
	tween.parallel().tween_property(material, "albedo_color", Color(1.0, 0.32, 0.02, 0.0), 0.18)
	tween.tween_callback(visual.queue_free)
