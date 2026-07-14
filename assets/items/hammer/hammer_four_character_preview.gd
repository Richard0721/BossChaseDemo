@tool
extends Node3D

@export_category("预览动画")
@export_enum("hammer_standing", "hammer_walk", "hammer_attack", "hammer_throw", "standing") var preview_animation := "hammer_standing"

@export_category("符文法师右手锤子")
@export var rune_mage_position := Vector3.ZERO
@export var rune_mage_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var rune_mage_scale := 55.0

@export_category("快乐的大学生右手锤子")
@export var happy_student_position := Vector3.ZERO
@export var happy_student_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var happy_student_scale := 55.0

@export_category("潇洒的LULU右手锤子")
@export var lulu_position := Vector3.ZERO
@export var lulu_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var lulu_scale := 55.0

@export_category("神秘兜帽人右手锤子")
@export var hooded_position := Vector3.ZERO
@export var hooded_rotation_degrees := Vector3.ZERO
@export_range(5.0, 120.0, 0.5) var hooded_scale := 55.0

@export_category("运行时使用的挂载资源")
@export var rune_mage_settings: HammerMountSettings
@export var happy_student_settings: HammerMountSettings
@export var lulu_settings: HammerMountSettings
@export var hooded_settings: HammerMountSettings

var _settings_loaded := false


func _ready() -> void:
	_load_fields_from_settings()
	_update_preview(0.0)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if not _settings_loaded:
			_load_fields_from_settings()
		_update_preview(delta)


func _load_fields_from_settings() -> void:
	if rune_mage_settings == null or happy_student_settings == null or lulu_settings == null or hooded_settings == null:
		return
	rune_mage_position = rune_mage_settings.model_position
	rune_mage_rotation_degrees = rune_mage_settings.model_rotation_degrees
	rune_mage_scale = rune_mage_settings.model_scale
	happy_student_position = happy_student_settings.model_position
	happy_student_rotation_degrees = happy_student_settings.model_rotation_degrees
	happy_student_scale = happy_student_settings.model_scale
	lulu_position = lulu_settings.model_position
	lulu_rotation_degrees = lulu_settings.model_rotation_degrees
	lulu_scale = lulu_settings.model_scale
	hooded_position = hooded_settings.model_position
	hooded_rotation_degrees = hooded_settings.model_rotation_degrees
	hooded_scale = hooded_settings.model_scale
	_settings_loaded = true


func _update_preview(delta: float) -> void:
	_sync_settings(rune_mage_settings, rune_mage_position, rune_mage_rotation_degrees, rune_mage_scale)
	_sync_settings(happy_student_settings, happy_student_position, happy_student_rotation_degrees, happy_student_scale)
	_sync_settings(lulu_settings, lulu_position, lulu_rotation_degrees, lulu_scale)
	_sync_settings(hooded_settings, hooded_position, hooded_rotation_degrees, hooded_scale)
	for character_name in ["RuneMage", "HappyStudent", "Lulu", "Hooded"]:
		var character := get_node_or_null(character_name)
		if character == null:
			continue
		if character.has_method("set_weapon_visible"):
			character.set_weapon_visible(false)
		if character.has_method("set_hammer_visible"):
			character.set_hammer_visible(true)
		_force_editor_animation(character, delta)


func _force_editor_animation(character: Node, delta: float) -> void:
	var animation_player := character.get_node_or_null("Rig/AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return
	var animation_name := StringName(preview_animation)
	if not animation_player.has_animation(animation_name) and character.has_method("_install_animation_library"):
		character.call("_install_animation_library")
	if not animation_player.has_animation(animation_name):
		return
	if animation_player.current_animation != animation_name or not animation_player.is_playing():
		animation_player.play(animation_name, 0.12)
	# AnimationPlayer does not always advance tool-script animations in the 3D
	# editor viewport. Advancing it here forces the selected hammer pose onto
	# the skeleton while the mount values are being edited.
	animation_player.advance(maxf(delta, 0.0))


func _sync_settings(settings: HammerMountSettings, new_position: Vector3, new_rotation: Vector3, new_scale: float) -> void:
	if settings == null:
		return
	var changed := settings.model_position != new_position or settings.model_rotation_degrees != new_rotation or not is_equal_approx(settings.model_scale, new_scale)
	if not changed:
		return
	settings.model_position = new_position
	settings.model_rotation_degrees = new_rotation
	settings.model_scale = new_scale
	settings.emit_changed()
	if Engine.is_editor_hint() and not settings.resource_path.is_empty():
		ResourceSaver.save(settings, settings.resource_path)
