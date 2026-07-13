class_name RuneManager
extends Node3D

signal round_spawned(round_number: int)

const RUNE_SCENE := preload("res://runes/rune_pickup.tscn")
const RUNE_TYPES: Array[StringName] = [&"Heal", &"Speed", &"Attack", &"Defense"]

@export var refresh_interval := 60.0
@export var rune_lifetime := 60.0

var time_to_next_round := 60.0
var round_number := 0


func _ready() -> void:
	_create_point_markers()
	if _is_host_or_single_player():
		spawn_round.call_deferred()


func _process(delta: float) -> void:
	if not _is_host_or_single_player():
		return
	time_to_next_round -= delta
	if time_to_next_round <= 0.0:
		spawn_round()


func spawn_round() -> void:
	for old_rune in get_tree().get_nodes_in_group("rune_pickups"):
		old_rune.queue_free()
	var points := get_children().filter(func(child: Node) -> bool: return child is Marker3D)
	var point_indices := range(points.size())
	point_indices.shuffle()
	for selection in 2:
		var point: Marker3D = points[point_indices[selection]]
		var rune: RunePickup = RUNE_SCENE.instantiate()
		rune.configure(RUNE_TYPES.pick_random(), rune_lifetime)
		var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		scene_root.add_child(rune)
		rune.global_position = point.global_position
	round_number += 1
	time_to_next_round = refresh_interval
	round_spawned.emit(round_number)


func get_active_rune_count() -> int:
	return get_tree().get_nodes_in_group("rune_pickups").size()


func _is_host_or_single_player() -> bool:
	return multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()


func _create_point_markers() -> void:
	for child in get_children():
		if not child is Marker3D:
			continue
		var pedestal_mesh := CylinderMesh.new()
		pedestal_mesh.top_radius = 1.45
		pedestal_mesh.bottom_radius = 1.65
		pedestal_mesh.height = 0.22
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.12, 0.2, 0.3, 1)
		material.metallic = 0.5
		material.emission_enabled = true
		material.emission = Color(0.02, 0.16, 0.28, 1)
		var pedestal := MeshInstance3D.new()
		pedestal.mesh = pedestal_mesh
		pedestal.material_override = material
		child.add_child(pedestal)
