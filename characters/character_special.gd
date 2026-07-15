class_name CharacterSpecial
extends Node

enum CharacterId { RUNE_MASTER, HAMMER_STUDENT, HOODED_COLLECTOR, LULU }

const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师",
	"快乐的本科生",
	"神秘兜帽人",
	"潇洒的男子 Lulu",
]
const HAMMER_STUDENT_AWAKEN_REQUIRED := 9
const LULU_AWAKEN_REQUIRED := 4
const HOODED_AWAKEN_REQUIRED := 4
const RUNE_MASTER_AWAKEN_REQUIRED := 4

var player: ThirdPersonPlayer
var character_id := CharacterId.RUNE_MASTER
var awakening_progress := 0
var awakened := false


func _ready() -> void:
	player = get_parent() as ThirdPersonPlayer
	var ui_manager := get_node_or_null("/root/UIManager")
	var selected_name := String(ui_manager.selected_character) if ui_manager != null else CHARACTER_NAMES[0]
	configure(selected_name)


func _process(delta: float) -> void:
	pass


func configure(character_name: String) -> void:
	var found_index := CHARACTER_NAMES.find(character_name)
	character_id = found_index if found_index >= 0 else CharacterId.RUNE_MASTER


func get_character_name() -> String:
	return CHARACTER_NAMES[character_id]


func get_move_multiplier() -> float:
	return 1.0


func get_ranged_attack_speed_multiplier() -> float:
	return 1.0


func get_ranged_damage_multiplier() -> float:
	return 1.3 if character_id == CharacterId.HOODED_COLLECTOR and awakened else 1.0


func get_melee_attack_speed_multiplier() -> float:
	return 1.0


func get_melee_damage_multiplier() -> float:
	return 1.0


func get_base_jump_count() -> int:
	return 2 if character_id == CharacterId.LULU and awakened else 1


func get_rune_duration_multiplier(rune_type: StringName) -> float:
	return 1.0


func get_jump_count_with_speed_rune(speed_rune_active: bool) -> int:
	if character_id == CharacterId.LULU:
		return 2 if awakened or speed_rune_active else 1
	return 2 if speed_rune_active else 1


func on_rune_touched(_rune_type: StringName) -> void:
	if character_id == CharacterId.RUNE_MASTER:
		_add_awakening_progress(1)


func record_item(_item_type: StringName) -> void:
	# Kept for compatibility with older calls. Hooded Collector now unlocks by
	# actual item-use count, not by collecting every item type once.
	return


func record_item_use(_item_type: StringName) -> void:
	match character_id:
		CharacterId.HOODED_COLLECTOR:
			if _item_type == &"RapidGun":
				_add_awakening_progress(1)
		CharacterId.LULU:
			if _item_type == &"Propeller":
				_add_awakening_progress(1)


func has_infinite_items() -> bool:
	return false


func get_item_use_count() -> int:
	return awakening_progress


func get_required_item_use_count() -> int:
	return get_awakening_required()


func is_hammer_specialist() -> bool:
	return character_id == CharacterId.HAMMER_STUDENT and awakened


func has_infinite_stamina() -> bool:
	return character_id == CharacterId.RUNE_MASTER and awakened


func record_hammer_melee_use() -> void:
	if character_id == CharacterId.HAMMER_STUDENT:
		_add_awakening_progress(1)


func get_awakening_required() -> int:
	match character_id:
		CharacterId.HAMMER_STUDENT:
			return HAMMER_STUDENT_AWAKEN_REQUIRED
		CharacterId.LULU:
			return LULU_AWAKEN_REQUIRED
		CharacterId.HOODED_COLLECTOR:
			return HOODED_AWAKEN_REQUIRED
		CharacterId.RUNE_MASTER:
			return RUNE_MASTER_AWAKEN_REQUIRED
	return 1


func is_awakened() -> bool:
	return awakened


func _add_awakening_progress(amount: int) -> void:
	if awakened:
		return
	awakening_progress += amount
	awakened = awakening_progress >= get_awakening_required()
