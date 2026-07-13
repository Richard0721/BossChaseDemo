class_name CharacterSpecial
extends Node

enum CharacterId { RUNE_MASTER, HAMMER_STUDENT, HOODED_COLLECTOR, LULU }

const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师",
	"快乐的本科生",
	"神秘兜帽人",
	"潇洒的男子 Lulu",
]
const REQUIRED_ITEMS: Array[StringName] = [
	&"RapidGun", &"Hammer", &"Propeller", &"Shield", &"Landmine", &"Bomb",
]

var player: ThirdPersonPlayer
var character_id := CharacterId.RUNE_MASTER
var collected_items: Dictionary = {}
var collector_unlocked := false


func _ready() -> void:
	player = get_parent() as ThirdPersonPlayer
	var ui_manager := get_node_or_null("/root/UIManager")
	var selected_name := String(ui_manager.selected_character) if ui_manager != null else CHARACTER_NAMES[0]
	configure(selected_name)


func _process(delta: float) -> void:
	if character_id == CharacterId.RUNE_MASTER and is_instance_valid(player) and player.health > 0.0:
		player.apply_health_drain(player.max_health * 0.02 * delta)


func configure(character_name: String) -> void:
	var found_index := CHARACTER_NAMES.find(character_name)
	character_id = found_index if found_index >= 0 else CharacterId.RUNE_MASTER
	if character_id == CharacterId.HAMMER_STUDENT:
		player.max_health += 50.0


func get_character_name() -> String:
	return CHARACTER_NAMES[character_id]


func get_move_multiplier() -> float:
	if character_id == CharacterId.LULU:
		return 1.2
	if character_id == CharacterId.RUNE_MASTER:
		var lost_health_ratio := 1.0 - player.health / maxf(player.max_health, 1.0)
		return 1.0 + clampf(lost_health_ratio, 0.0, 1.0) * 0.5
	return 1.0


func get_ranged_attack_speed_multiplier() -> float:
	if character_id != CharacterId.RUNE_MASTER:
		return 1.0
	var lost_health_percent := (1.0 - player.health / maxf(player.max_health, 1.0)) * 100.0
	return maxf(0.35, 1.3 - floorf(lost_health_percent / 2.0) * 0.01)


func get_melee_attack_speed_multiplier() -> float:
	return 2.0 if character_id == CharacterId.HAMMER_STUDENT else 1.0


func get_melee_damage_multiplier() -> float:
	return 2.0 if character_id == CharacterId.HAMMER_STUDENT else 1.0


func get_base_jump_count() -> int:
	return 2 if character_id == CharacterId.LULU else 1


func get_rune_duration_multiplier(rune_type: StringName) -> float:
	if character_id == CharacterId.RUNE_MASTER:
		return 2.0
	if character_id == CharacterId.LULU and rune_type == &"Speed":
		return 2.0
	return 1.0


func get_jump_count_with_speed_rune(speed_rune_active: bool) -> int:
	if character_id == CharacterId.LULU:
		return 3 if speed_rune_active else 2
	return 2 if speed_rune_active else 1


func on_rune_touched(_rune_type: StringName) -> void:
	if character_id == CharacterId.RUNE_MASTER:
		var missing_health := player.max_health - player.health
		player.heal(missing_health * 0.8)


func record_item(item_type: StringName) -> void:
	if character_id != CharacterId.HOODED_COLLECTOR:
		return
	collected_items[item_type] = true
	collector_unlocked = true
	for required_item in REQUIRED_ITEMS:
		if not collected_items.has(required_item):
			collector_unlocked = false
			break


func has_infinite_items() -> bool:
	return character_id == CharacterId.HOODED_COLLECTOR and collector_unlocked


func is_hammer_specialist() -> bool:
	return character_id == CharacterId.HAMMER_STUDENT

