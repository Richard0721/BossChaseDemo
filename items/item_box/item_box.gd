@tool
class_name ItemBox
extends Area3D

const EXPLOSIVE_SCENE := preload("res://items/explosive/explosive.tscn")
const RANDOM_REWARDS: Array[StringName] = [
	&"Hammer",
	&"Propeller",
	&"RapidGun",
	&"Shield",
	&"Landmine",
	&"Bomb",
]

@export_group("道具箱模型调整")
@export_range(1.0, 200.0, 0.5) var model_scale := 80.0:
	set(value):
		model_scale = value
		_apply_model_adjustments()
@export var model_position := Vector3(0.0, -0.38, 0.0):
	set(value):
		model_position = value
		_apply_model_adjustments()
@export var model_rotation_degrees := Vector3.ZERO:
	set(value):
		model_rotation_degrees = value
		_apply_model_adjustments()
var spawn_index := -1
var rolled_reward: StringName = &""


func _ready() -> void:
	_apply_model_adjustments()
	if Engine.is_editor_hint():
		return
	if rolled_reward.is_empty():
		rolled_reward = RANDOM_REWARDS.pick_random()
	add_to_group("interactables")
	add_to_group("item_boxes")


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	$Visuals.rotation.y += delta * 0.7


func _apply_model_adjustments() -> void:
	var adjustment := get_node_or_null("Visuals/ModelSizeAdjustment__在这里调大小") as Node3D
	if adjustment == null:
		return
	adjustment.scale = Vector3.ONE * model_scale
	adjustment.position = model_position
	adjustment.rotation_degrees = model_rotation_degrees


func interact(player: Node3D) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()):
		return
	if rolled_reward.is_empty():
		rolled_reward = RANDOM_REWARDS.pick_random()
	var reward := _select_reward_for_player(player)
	if reward.is_empty():
		return
	rolled_reward = reward
	if reward == &"Bomb":
		_spawn_bomb()
		queue_free()
		return
	if player.has_method("receive_item") and player.receive_item(reward):
		queue_free()


func _select_reward_for_player(player: Node3D) -> StringName:
	if _can_player_receive_reward(player, rolled_reward):
		return rolled_reward
	if player.has_method("has_inventory_item") and player.has_inventory_item():
		return &""
	var candidates: Array[StringName] = RANDOM_REWARDS.duplicate()
	candidates.shuffle()
	for candidate in candidates:
		if _can_player_receive_reward(player, candidate):
			return candidate
	return &""


func _can_player_receive_reward(player: Node3D, reward: StringName) -> bool:
	if reward == &"Bomb":
		return true
	if player.has_method("can_receive_item"):
		return player.can_receive_item(reward)
	return player.has_method("receive_item")


func _spawn_bomb() -> void:
	var bomb: AreaExplosive = EXPLOSIVE_SCENE.instantiate()
	bomb.configure(2.0, 50.0, 6.0, Color(1.0, 0.05, 0.02, 1), 26.0, 5.5, 0.0)
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(bomb)
	bomb.global_position = global_position + Vector3.UP * 0.6
