@tool
class_name AreaExplosive
extends Node3D

@export_category("炸弹模型调整")
@export_range(0.05, 2.0, 0.01) var model_scale := 0.5
@export var model_position := Vector3.ZERO
@export var model_rotation_degrees := Vector3.ZERO

@export_category("爆炸前红光预警")
@export_range(0.1, 5.0, 0.1) var warning_start_time := 1.0
@export_range(0.0, 20.0, 0.5) var warning_min_light_energy := 1.0
@export_range(0.0, 40.0, 0.5) var warning_max_light_energy := 12.0
@export_range(1.0, 20.0, 0.5) var warning_flash_slow_hz := 3.0
@export_range(1.0, 30.0, 0.5) var warning_flash_fast_hz := 12.0
@export_range(0.0, 0.3, 0.01) var warning_model_pulse := 0.1

@export_category("倒计时文字调整")
@export var countdown_position := Vector3(0.0, 1.2, 0.0)
@export_range(20, 160, 1) var countdown_font_size := 72
@export_range(0, 32, 1) var countdown_outline_size := 16
@export_range(0.001, 0.02, 0.001) var countdown_pixel_size := 0.006

var fuse_time := 2.0
var damage := 50.0
var radius := 6.0
var explosive_color := Color(1.0, 0.12, 0.02, 1)
var knockback_force := 0.0
var vertical_force := 0.0
var tumble_duration := 0.0
var source_owner: Node
var _exploded := false

@onready var model_adjustment: Node3D = $ModelAdjustment__在这里调模型
@onready var warning_glow: MeshInstance3D = $WarningGlow
@onready var warning_light: OmniLight3D = $WarningLight
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
	_apply_editor_adjustments()
	if Engine.is_editor_hint():
		countdown_label.text = "0.8"


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_apply_editor_adjustments()
		var editor_flash := (sin(Time.get_ticks_msec() * 0.018) + 1.0) * 0.5
		_update_warning_visual(editor_flash, true)
		countdown_label.text = "0.8"
		return
	if _exploded:
		return
	fuse_time -= delta
	countdown_label.text = "%.1f" % maxf(0.0, fuse_time)
	if fuse_time <= warning_start_time:
		var warning_progress := 1.0 - clampf(fuse_time / maxf(warning_start_time, 0.01), 0.0, 1.0)
		var flash_frequency := lerpf(warning_flash_slow_hz, warning_flash_fast_hz, warning_progress)
		var flash := (sin(Time.get_ticks_msec() * 0.001 * TAU * flash_frequency) + 1.0) * 0.5
		_update_warning_visual(flash, true)
	else:
		_update_warning_visual(0.0, false)
	if fuse_time <= 0.0:
		explode()


func _apply_editor_adjustments() -> void:
	if not is_node_ready():
		return
	model_adjustment.position = model_position
	model_adjustment.rotation_degrees = model_rotation_degrees
	model_adjustment.scale = Vector3.ONE * model_scale
	countdown_label.position = countdown_position
	countdown_label.font_size = countdown_font_size
	countdown_label.outline_size = countdown_outline_size
	countdown_label.pixel_size = countdown_pixel_size


func _update_warning_visual(flash: float, active: bool) -> void:
	warning_glow.visible = active
	warning_light.visible = active
	model_adjustment.scale = Vector3.ONE * model_scale * (1.0 + flash * warning_model_pulse if active else 1.0)
	countdown_label.scale = Vector3.ONE * (1.0 + flash * 0.15 if active else 1.0)
	countdown_label.modulate = Color(1.0, lerpf(0.12, 0.72, 1.0 - flash), 0.04, 1.0) if active else Color.WHITE
	if not active:
		return
	warning_light.light_energy = lerpf(warning_min_light_energy, warning_max_light_energy, flash)
	var glow_material := warning_glow.material_override as StandardMaterial3D
	if glow_material != null:
		glow_material.albedo_color = Color(1.0, 0.01, 0.0, lerpf(0.04, 0.26, flash))
		glow_material.emission_energy_multiplier = lerpf(1.0, 6.0, flash)


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	AudioManager.play_explosion()
	model_adjustment.visible = false
	warning_glow.visible = false
	warning_light.visible = false
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
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(visual)
	visual.global_position = global_position
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale", Vector3.ONE * 1.25, 0.18)
	tween.parallel().tween_property(material, "albedo_color", Color(explosive_color.r, explosive_color.g, explosive_color.b, 0.0), 0.18)
	tween.tween_callback(visual.queue_free)
