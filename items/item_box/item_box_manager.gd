class_name ItemBoxManager
extends Node3D

const ITEM_BOX_SCENE := preload("res://items/item_box/item_box.tscn")

@export var spawn_interval := 30.0
@export var maximum_boxes := 15
var time_until_spawn := 30.0


func _ready() -> void:
	if _is_host_or_single_player():
		_spawn_initial_boxes.call_deferred()


func _process(delta: float) -> void:
	if not _is_host_or_single_player():
		return
	time_until_spawn -= delta
	if time_until_spawn <= 0.0:
		time_until_spawn = spawn_interval
		if get_tree().get_nodes_in_group("item_boxes").size() < maximum_boxes:
			_spawn_one_at_free_point()


func _spawn_initial_boxes() -> void:
	for index in mini(maximum_boxes, get_child_count()):
		_spawn_box(index)


func _spawn_one_at_free_point() -> void:
	var occupied: Dictionary = {}
	for box in get_tree().get_nodes_in_group("item_boxes"):
		occupied[box.spawn_index] = true
	var free_indices: Array[int] = []
	for index in get_child_count():
		if not occupied.has(index):
			free_indices.append(index)
	if not free_indices.is_empty():
		_spawn_box(free_indices.pick_random())


func _spawn_box(point_index: int) -> void:
	var point := get_child(point_index) as Marker3D
	var box: ItemBox = ITEM_BOX_SCENE.instantiate()
	box.spawn_index = point_index
	box.global_position = point.global_position
	get_tree().current_scene.add_child(box)


func _is_host_or_single_player() -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()
