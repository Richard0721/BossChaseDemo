@tool
extends Node3D

@export_category("绿色治疗符文")
@export_range(0.005, 2.0, 0.005) var heal_rune_scale := 0.06
@export_category("蓝色速度符文")
@export_range(0.005, 2.0, 0.005) var speed_rune_scale := 0.06
@export_category("红色攻击符文")
@export_range(0.005, 2.0, 0.005) var attack_rune_scale := 0.06
@export_category("黄色防御符文")
@export_range(0.005, 2.0, 0.005) var defense_rune_scale := 0.06

@export_category("运行时符文资源")
@export var heal_settings: RuneModelSettings
@export var speed_settings: RuneModelSettings
@export var attack_settings: RuneModelSettings
@export var defense_settings: RuneModelSettings

var _settings_loaded := false
var _last_heal_scale := 0.06
var _last_speed_scale := 0.06
var _last_attack_scale := 0.06
var _last_defense_scale := 0.06


func _ready() -> void:
	_load_settings()
	_sync_settings()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not _settings_loaded:
			_load_settings()
		_sync_settings()


func _load_settings() -> void:
	if heal_settings == null or speed_settings == null or attack_settings == null or defense_settings == null:
		return
	heal_rune_scale = heal_settings.model_scale
	speed_rune_scale = speed_settings.model_scale
	attack_rune_scale = attack_settings.model_scale
	defense_rune_scale = defense_settings.model_scale
	_last_heal_scale = heal_rune_scale
	_last_speed_scale = speed_rune_scale
	_last_attack_scale = attack_rune_scale
	_last_defense_scale = defense_rune_scale
	_settings_loaded = true


func _sync_settings() -> void:
	var heal_result := _sync_scale(heal_settings, heal_rune_scale, _last_heal_scale)
	heal_rune_scale = heal_result.x
	_last_heal_scale = heal_result.y
	var speed_result := _sync_scale(speed_settings, speed_rune_scale, _last_speed_scale)
	speed_rune_scale = speed_result.x
	_last_speed_scale = speed_result.y
	var attack_result := _sync_scale(attack_settings, attack_rune_scale, _last_attack_scale)
	attack_rune_scale = attack_result.x
	_last_attack_scale = attack_result.y
	var defense_result := _sync_scale(defense_settings, defense_rune_scale, _last_defense_scale)
	defense_rune_scale = defense_result.x
	_last_defense_scale = defense_result.y


func _sync_scale(settings: RuneModelSettings, editor_value: float, previous_editor_value: float) -> Vector2:
	if settings == null:
		return Vector2(editor_value, editor_value)
	if not is_equal_approx(editor_value, previous_editor_value):
		_save_scale(settings, editor_value)
		return Vector2(editor_value, editor_value)
	if not is_equal_approx(settings.model_scale, editor_value):
		return Vector2(settings.model_scale, settings.model_scale)
	return Vector2(editor_value, editor_value)


func _save_scale(settings: RuneModelSettings, new_scale: float) -> void:
	if settings == null or is_equal_approx(settings.model_scale, new_scale):
		return
	settings.model_scale = new_scale
	settings.emit_changed()
	if Engine.is_editor_hint() and not settings.resource_path.is_empty():
		ResourceSaver.save(settings, settings.resource_path)
