class_name ItemBoxManager
extends Node3D

const ITEM_BOX_SCENE := preload("res://items/item_box/item_box.tscn")

@export var spawn_interval := 30.0
@export var maximum_boxes := 15
@export_group("Ground Placement")
@export_range(0.0, 2.0, 0.05) var ground_clearance := 0.25
@export_range(1.0, 100.0, 1.0) var ground_probe_height := 30.0
@export_range(1.0, 150.0, 1.0) var ground_probe_depth := 80.0
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
	await get_tree().physics_frame
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
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(box)
	box.global_position = _get_grounded_position(point.global_position)


func _get_grounded_position(marker_position: Vector3) -> Vector3:
	var ray_start := marker_position + Vector3.UP * ground_probe_height
	var ray_end := marker_position - Vector3.UP * ground_probe_depth
	var excluded: Array[RID] = []
	for _attempt in 8:
		var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end, 1, excluded)
		query.collide_with_areas = false
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider") as Object
		if collider is StaticBody3D:
			return Vector3(marker_position.x, float(hit["position"].y) + ground_clearance, marker_position.z)
		if collider is CollisionObject3D:
			excluded.append((collider as CollisionObject3D).get_rid())
		else:
			break
	return marker_position + Vector3.UP * ground_clearance


func _is_host_or_single_player() -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()
