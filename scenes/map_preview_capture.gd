extends Node3D

const SHOT_DURATION := 3.0
const TOTAL_DURATION := 12.0

@onready var arena: Node3D = $PrototypeArena
@onready var preview_camera: Camera3D = $PreviewCamera

var elapsed := 0.0


func _ready() -> void:
	preview_camera.current = true
	var player := arena.get_node_or_null("Player")
	if player != null and player.has_method("set_camera_active"):
		player.set_camera_active(false)
	for ui_name in ["HUD", "PauseUI", "DeathUI"]:
		var ui_node := arena.get_node_or_null(ui_name)
		if ui_node != null:
			ui_node.visible = false
	_update_camera(0.0)


func _process(delta: float) -> void:
	elapsed = minf(TOTAL_DURATION, elapsed + delta)
	_update_camera(elapsed)
	if elapsed >= TOTAL_DURATION:
		get_tree().quit()


func _update_camera(time: float) -> void:
	var shot_index := mini(int(time / SHOT_DURATION), 3)
	var local_time := fmod(time, SHOT_DURATION) / SHOT_DURATION
	var eased_time := local_time * local_time * (3.0 - 2.0 * local_time)
	match shot_index:
		0:
			# Aerial establishing shot over the full arena and vertical layers.
			_move_camera(
				Vector3(-78, 72, 104), Vector3(62, 52, 42),
				Vector3(0, 0, -8), Vector3(5, 2, 18), eased_time
			)
		1:
			# Low dolly through the B1 basin and under the traversal ramps.
			_move_camera(
				Vector3(-28, -4.2, 72), Vector3(24, -3.4, 38),
				Vector3(-8, -4.5, 48), Vector3(34, 0, 18), eased_time
			)
		2:
			# Lateral ridge shot showing the high platform and long sightlines.
			_move_camera(
				Vector3(108, 18, -74), Vector3(34, 15, -24),
				Vector3(68, 8, -42), Vector3(2, 2, -12), eased_time
			)
		3:
			# Ground-level chase shot aimed from the player side toward the Boss.
			var player := arena.get_node_or_null("Player") as Node3D
			var boss := arena.get_node_or_null("Boss") as Node3D
			var player_position := player.global_position if player != null else Vector3(0, 1, 10)
			var boss_position := boss.global_position if boss != null else Vector3(0, 1, -26)
			var sideways := Vector3(9, 0, 0)
			var start_position := player_position + Vector3(0, 4.0, 10.0)
			var end_position := player_position + sideways + Vector3(0, 3.0, 2.0)
			_move_camera(start_position, end_position, boss_position + Vector3.UP, boss_position + Vector3.UP * 1.5, eased_time)


func _move_camera(
	start_position: Vector3,
	end_position: Vector3,
	start_target: Vector3,
	end_target: Vector3,
	weight: float
) -> void:
	preview_camera.global_position = start_position.lerp(end_position, weight)
	var look_target := start_target.lerp(end_target, weight)
	preview_camera.look_at(look_target, Vector3.UP)

