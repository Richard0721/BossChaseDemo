class_name ItemBox
extends Area3D

const EXPLOSIVE_SCENE := preload("res://items/explosive/explosive.tscn")

var spawn_index := -1


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("item_boxes")


func _process(delta: float) -> void:
	$Visuals.rotation.y += delta * 0.7


func interact(player: Node3D) -> void:
	if not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer or multiplayer.is_server()):
		return
	var roll := randi_range(0, 99)
	if roll < 10:
		_spawn_bomb()
		queue_free()
		return
	var item_type: StringName
	if roll < 30:
		item_type = &"Hammer"
	elif roll < 50:
		item_type = &"Propeller"
	elif roll < 70:
		item_type = &"RapidGun"
	elif roll < 90:
		item_type = &"Shield"
	else:
		item_type = &"Landmine"
	if player.has_method("receive_item") and player.receive_item(item_type):
		queue_free()


func _spawn_bomb() -> void:
	var bomb: AreaExplosive = EXPLOSIVE_SCENE.instantiate()
	bomb.configure(2.0, 50.0, 6.0, Color(1.0, 0.05, 0.02, 1), 26.0, 5.5, 0.0)
	bomb.global_position = global_position + Vector3.UP * 0.6
	get_tree().current_scene.add_child(bomb)
