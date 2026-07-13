class_name CombatProjectile
extends Node3D

var direction := Vector3.FORWARD
var speed := 20.0
var damage := 1.0
var lifetime := 6.0
var owner_body: CollisionObject3D
var projectile_color := Color.WHITE
var size_multiplier := 1.0
var ai_damage_multiplier := 1.0
var pierces_players := false
var _pierced_targets: Array[RID] = []

@onready var projectile_mesh: MeshInstance3D = $Mesh
@onready var trail_mesh: MeshInstance3D = $Trail


func configure(
	new_direction: Vector3,
	new_speed: float,
	new_damage: float,
	new_owner: CollisionObject3D,
	new_color: Color,
	new_size := 1.0,
	new_ai_damage_multiplier := 1.0,
	new_pierces_players := false
) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	owner_body = new_owner
	projectile_color = new_color
	size_multiplier = new_size
	ai_damage_multiplier = new_ai_damage_multiplier
	pierces_players = new_pierces_players


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 4.0
	projectile_mesh.material_override = material
	trail_mesh.material_override = material
	scale = Vector3.ONE * size_multiplier
	look_at(global_position + direction, Vector3.UP)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + direction * speed * delta
	var query := PhysicsRayQueryParameters3D.create(from, to)
	var excluded_rids: Array[RID] = _pierced_targets.duplicate()
	if is_instance_valid(owner_body):
		excluded_rids.append(owner_body.get_rid())
	query.exclude = excluded_rids
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		_spawn_impact(hit["position"])
		var collider: Object = hit["collider"]
		if collider != null and collider.has_method("apply_damage"):
			var applied_damage := damage
			if collider is Node and collider.is_in_group("ai_teammates"):
				applied_damage *= ai_damage_multiplier
			collider.apply_damage(applied_damage, owner_body)
			if pierces_players and collider is CollisionObject3D and collider.is_in_group("players"):
				_pierced_targets.append(collider.get_rid())
				global_position = to
				return
		queue_free()
		return
	global_position = to


func _spawn_impact(at_position: Vector3) -> void:
	var impact_mesh := SphereMesh.new()
	impact_mesh.radius = 0.28 * size_multiplier
	impact_mesh.height = 0.56 * size_multiplier
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(projectile_color.r, projectile_color.g, projectile_color.b, 0.72)
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 4.5
	var impact := MeshInstance3D.new()
	impact.mesh = impact_mesh
	impact.material_override = material
	impact.global_position = at_position
	get_tree().current_scene.add_child(impact)
	get_tree().create_timer(0.13).timeout.connect(impact.queue_free)
