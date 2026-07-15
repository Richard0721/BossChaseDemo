@tool
extends Node3D

@export_category("四角色独立盾牌挂载设置")
@export var rune_mage_settings: ShieldMountSettings
@export var happy_student_settings: ShieldMountSettings
@export var lulu_settings: ShieldMountSettings
@export var hooded_settings: ShieldMountSettings


func _ready() -> void:
	_show_all_shields()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		_show_all_shields()


func _show_all_shields() -> void:
	for character_name in ["RuneMage", "HappyStudent", "Lulu", "Hooded"]:
		var character := get_node_or_null(character_name)
		if character != null and character.has_method("set_shield_visible"):
			character.set_shield_visible(true)

