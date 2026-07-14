class_name ThrownHammer
extends Node3D

var direction := Vector3.FORWARD
var speed := 26.0
var damage := 0.0
var stun_duration := 3.0
var gravity := 8.0
var vertical_velocity := 1.5
var lifetime := 6.0
var collision_radius := 0.32
var owner_body: CollisionObject3D
var _finished := false
var _hammer_transform := Transform3D.IDENTITY
var _model_adjustment_transform := Transform3D.IDENTITY
var _use_hand_visual_transform := false


func configure(
	new_direction: Vector3,
	new_owner: CollisionObject3D,
	new_damage := 0.0,
	hand_hammer_transform := Transform3D.IDENTITY,
	hand_model_adjustment_transform := Transform3D.IDENTITY,
	use_hand_visual_transform := false
) -> void:
	direction = new_direction.normalized()
	owner_body = new_owner
	damage = new_damage
	_hammer_transform = hand_hammer_transform
	_model_adjustment_transform = hand_model_adjustment_transform
	_use_hand_visual_transform = use_hand_visual_transform


func _ready() -> void:
	if not _use_hand_visual_transform:
		return
	var hammer_visual := get_node_or_null("Hammer") as Node3D
	if hammer_visual == null:
		return
	# The hand attachment's position is bone-local and should not offset the projectile.
	_hammer_transform.origin = Vector3.ZERO
	hammer_visual.transform = _hammer_transform
	var model_adjustment := hammer_visual.get_child(0) as Node3D
	if model_adjustment != null:
		model_adjustment.transform = _model_adjustment_transform


func _physics_process(delta: float) -> void:
	if _finished:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_disappear()
		return
	rotate_x(delta * 10.0)
	vertical_velocity -= gravity * delta
	var motion := direction * speed * delta + Vector3.UP * vertical_velocity * delta
	var from := global_position
	var to := from + motion
	var hit := _find_collision(from, to)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("apply_stun_damage"):
			collider.apply_stun_damage(damage, stun_duration, owner_body)
		_disappear()
		return
	global_position = to


func _find_collision(from: Vector3, to: Vector3) -> Dictionary:
	var shape := SphereShape3D.new()
	shape.radius = collision_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collide_with_bodies = true
	query.collide_with_areas = false
	query.exclude = _get_player_exclusions()
	var motion := to - from
	var step_length := maxf(collision_radius, 0.08)
	var step_count := maxi(1, ceili(motion.length() / step_length))
	for step in range(1, step_count + 1):
		var check_position := from + motion * (float(step) / float(step_count))
		query.transform = Transform3D(Basis.IDENTITY, check_position)
		var hits := get_world_3d().direct_space_state.intersect_shape(query, 8)
		if not hits.is_empty():
			return {
				"collider": hits[0].get("collider"),
				"position": check_position,
			}
	return {}


func _get_player_exclusions() -> Array[RID]:
	var exclusions: Array[RID] = []
	if is_instance_valid(owner_body):
		exclusions.append(owner_body.get_rid())
	# Every player body is excluded, so the hammer passes through teammates.
	for player_node: Node in get_tree().get_nodes_in_group("players"):
		var player_body := player_node as CollisionObject3D
		if player_body != null and is_instance_valid(player_body):
			var player_rid := player_body.get_rid()
			if not exclusions.has(player_rid):
				exclusions.append(player_rid)
	return exclusions


func _disappear() -> void:
	if _finished:
		return
	_finished = true
	queue_free()
