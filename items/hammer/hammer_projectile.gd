class_name ThrownHammer
extends Node3D

const HAMMER_PICKUP_SCENE := preload("res://items/hammer/hammer_pickup.tscn")

var direction := Vector3.FORWARD
var speed := 26.0
var damage := 0.0
var stun_duration := 3.0
var gravity := 8.0
var vertical_velocity := 1.5
var lifetime := 6.0
var owner_body: CollisionObject3D
var _landed := false


func configure(new_direction: Vector3, new_owner: CollisionObject3D, new_damage := 0.0) -> void:
	direction = new_direction.normalized()
	owner_body = new_owner
	damage = new_damage


func _physics_process(delta: float) -> void:
	if _landed:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_drop_pickup(global_position)
		return
	rotate_x(delta * 10.0)
	vertical_velocity -= gravity * delta
	var motion := direction * speed * delta + Vector3.UP * vertical_velocity * delta
	var from := global_position
	var to := from + motion
	var query := PhysicsRayQueryParameters3D.create(from, to)
	if is_instance_valid(owner_body):
		query.exclude = [owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("apply_stun_damage"):
			collider.apply_stun_damage(damage, stun_duration, owner_body)
		_drop_pickup(hit["position"])
		return
	global_position = to


func _drop_pickup(at_position: Vector3) -> void:
	if _landed:
		return
	_landed = true
	var pickup: Area3D = HAMMER_PICKUP_SCENE.instantiate()
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(pickup)
	pickup.global_position = at_position + Vector3.UP * 0.7
	queue_free()
