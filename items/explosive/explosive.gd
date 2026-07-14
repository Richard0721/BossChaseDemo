class_name AreaExplosive
extends Node3D

var fuse_time := 2.0
var damage := 50.0
var radius := 6.0
var explosive_color := Color(1.0, 0.12, 0.02, 1)
var knockback_force := 0.0
var vertical_force := 0.0
var tumble_duration := 0.0
var source_owner: Node
var _exploded := false

@onready var body_mesh: MeshInstance3D = $Body
@onready var countdown_label: Label3D = $Countdown


func configure(
	new_fuse: float,
	new_damage: float,
	new_radius: float,
	new_color := Color(1.0, 0.12, 0.02, 1),
	new_knockback_force := 0.0,
	new_vertical_force := 0.0,
	new_tumble_duration := 0.0
) -> void:
	fuse_time = new_fuse
	damage = new_damage
	radius = new_radius
	explosive_color = new_color
	knockback_force = new_knockback_force
	vertical_force = new_vertical_force
	tumble_duration = new_tumble_duration


func set_source_owner(new_source_owner: Node) -> void:
	source_owner = new_source_owner


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = explosive_color
	material.emission_enabled = true
	material.emission = explosive_color.darkened(0.25)
	body_mesh.material_override = material


func _process(delta: float) -> void:
	if _exploded:
		return
	fuse_time -= delta
	countdown_label.text = "%.1f" % maxf(0.0, fuse_time)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.018) * 0.12
	body_mesh.scale = Vector3.ONE * pulse
	if fuse_time <= 0.0:
		explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	AudioManager.play_explosion()
	body_mesh.visible = false
	countdown_label.visible = false
	for target in _collect_targets(radius):
		_apply_blast_to_target(target)
	_spawn_explosion_visual()
	call_deferred("queue_free")


func _collect_targets(blast_radius: float) -> Array[Node3D]:
	var targets: Array[Node3D] = []
	var affected: Dictionary = {}
	var scene := get_tree().current_scene
	if scene != null:
		for node_name in ["Player", "Boss"]:
			var direct_target := scene.get_node_or_null(node_name)
			if direct_target is Node3D and global_position.distance_to(direct_target.global_position) <= blast_radius:
				affected[direct_target.get_instance_id()] = true
				targets.append(direct_target)
	for group_name in ["players", "ai_teammates", "lock_targets"]:
		for target in get_tree().get_nodes_in_group(group_name):
			if not target is Node3D or affected.has(target.get_instance_id()):
				continue
			if global_position.distance_to(target.global_position) <= blast_radius:
				affected[target.get_instance_id()] = true
				targets.append(target)
	return targets


func _apply_blast_to_target(target: Node3D) -> void:
	if target.has_method("apply_blast_effect"):
		target.apply_blast_effect(damage, global_position, knockback_force, vertical_force, maxf(tumble_duration, 0.85), source_owner)
		return
	if target.has_method("apply_damage"):
		target.apply_damage(damage, source_owner)
	if knockback_force > 0.0 and target.has_method("apply_knockback"):
		target.apply_knockback(global_position, knockback_force, vertical_force)
	if tumble_duration > 0.0 and target.has_method("apply_tumble"):
		target.apply_tumble(tumble_duration)


func _spawn_explosion_visual() -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(explosive_color.r, explosive_color.g, explosive_color.b, 0.45)
	material.emission_enabled = true
	material.emission = explosive_color
	material.emission_energy_multiplier = 4.0
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = material
	visual.global_position = global_position
	get_tree().current_scene.add_child(visual)
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.25, 0.18)
	tween.parallel().tween_property(material, "albedo_color", Color(explosive_color.r, explosive_color.g, explosive_color.b, 0.0), 0.18)
	tween.tween_callback(visual.queue_free)
