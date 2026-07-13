extends Area3D


func _ready() -> void:
	add_to_group("interactables")
	add_to_group("hammer_pickups")


func _process(delta: float) -> void:
	rotation.y += delta * 1.8
	$Visuals.position.y = sin(Time.get_ticks_msec() * 0.003) * 0.12


func interact(player: Node3D) -> void:
	if player.has_method("receive_item") and player.receive_item(&"Hammer"):
		queue_free()
