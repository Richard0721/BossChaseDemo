class_name CombatProjectile
extends Node3D

const HAPPY_STUDENT_IMPACT_SCENE := preload("res://assets/effects/fx03_impact/fx03_impact.tscn")
const FASHI_IMPACT_SCENE := preload("res://assets/effects/blue_purple_smoke/blue_purple_smoke.tscn")

var direction := Vector3.FORWARD
var speed := 20.0
var damage := 1.0
var lifetime := 6.0
var owner_body: CollisionObject3D
var projectile_color := Color.WHITE
var size_multiplier := 1.0
var ai_damage_multiplier := 1.0
var pierces_players := false
var use_happy_student_visual := false
var use_fashi_visual := false
var use_lulu_visual := false
var use_doumaoren_visual := false
var use_boss_visual := false
var _pierced_targets: Array[RID] = []

@onready var default_mesh: MeshInstance3D = $DefaultMesh
@onready var bullet_model: Node3D = $BulletModel
@onready var boss_bullet_model: Node3D = $BossBulletModel
@onready var trail_mesh: MeshInstance3D = $Trail


func configure(
	new_direction: Vector3,
	new_speed: float,
	new_damage: float,
	new_owner: CollisionObject3D,
	new_color: Color,
	new_size := 1.0,
	new_ai_damage_multiplier := 1.0,
	new_pierces_players := false,
	new_use_happy_student_visual := false,
	new_use_fashi_visual := false,
	new_use_lulu_visual := false,
	new_use_doumaoren_visual := false,
	new_use_boss_visual := false
) -> void:
	direction = new_direction.normalized()
	speed = new_speed
	damage = new_damage
	owner_body = new_owner
	projectile_color = new_color
	size_multiplier = new_size
	ai_damage_multiplier = new_ai_damage_multiplier
	pierces_players = new_pierces_players
	use_happy_student_visual = new_use_happy_student_visual
	use_fashi_visual = new_use_fashi_visual
	use_lulu_visual = new_use_lulu_visual
	use_doumaoren_visual = new_use_doumaoren_visual
	use_boss_visual = new_use_boss_visual


func _ready() -> void:
	var uses_imported_bullet := use_happy_student_visual or use_fashi_visual or use_lulu_visual or use_doumaoren_visual or use_boss_visual
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = projectile_color
	material.emission_enabled = true
	material.emission = projectile_color
	material.emission_energy_multiplier = 4.0
	default_mesh.visible = not uses_imported_bullet
	bullet_model.visible = uses_imported_bullet and not use_boss_visual
	boss_bullet_model.visible = use_boss_visual
	trail_mesh.visible = not uses_imported_bullet and not use_boss_visual
	if not uses_imported_bullet:
		default_mesh.material_override = material
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
	var excluded_rids: Array[RID] = _pierced_targets.duplicate()
	if is_instance_valid(owner_body):
		excluded_rids.append(owner_body.get_rid())
	var hit := _intersect_projectile_path(from, to, excluded_rids)
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		_spawn_impact(hit["position"], collider != null and collider.has_method("apply_damage"))
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


func _intersect_projectile_path(from: Vector3, to: Vector3, excluded_rids: Array[RID]) -> Dictionary:
	var offsets: Array[Vector3] = [Vector3.ZERO]
	if use_happy_student_visual or use_fashi_visual or use_lulu_visual or use_doumaoren_visual or use_boss_visual:
		# Match the slightly wider imported projectile without turning it into a
		# large area attack. The center ray remains authoritative for walls.
		var hit_radius := 0.16
		var side := direction.cross(Vector3.UP)
		if side.length_squared() < 0.001:
			side = direction.cross(Vector3.RIGHT)
		side = side.normalized()
		var vertical := side.cross(direction).normalized()
		offsets.append_array([side * hit_radius, -side * hit_radius, vertical * hit_radius, -vertical * hit_radius])
	var nearest_hit: Dictionary = {}
	var nearest_distance_squared := INF
	for offset in offsets:
		var query := PhysicsRayQueryParameters3D.create(from + offset, to + offset)
		query.exclude = excluded_rids
		var candidate := get_world_3d().direct_space_state.intersect_ray(query)
		if candidate.is_empty():
			continue
		var distance_squared: float = from.distance_squared_to(candidate["position"])
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_hit = candidate
	return nearest_hit


func _spawn_impact(at_position: Vector3, hit_damageable_target := false) -> void:
	if use_boss_visual:
		if not hit_damageable_target:
			return
		var boss_impact: BluePurpleSmoke = FASHI_IMPACT_SCENE.instantiate()
		boss_impact.blue_color = Color(1.0, 0.04, 0.02, 0.84)
		boss_impact.purple_color = Color(0.46, 0.0, 0.015, 0.78)
		boss_impact.effect_size = 1.35
		var boss_scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		boss_scene_root.add_child(boss_impact)
		boss_impact.global_position = at_position
		return
	if use_doumaoren_visual:
		if not hit_damageable_target:
			return
		var doumaoren_impact: BluePurpleSmoke = FASHI_IMPACT_SCENE.instantiate()
		doumaoren_impact.blue_color = Color(0.08, 1.0, 0.3, 0.82)
		doumaoren_impact.purple_color = Color(0.0, 0.42, 0.12, 0.76)
		var doumaoren_scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		doumaoren_scene_root.add_child(doumaoren_impact)
		doumaoren_impact.global_position = at_position
		return
	if use_lulu_visual:
		if not hit_damageable_target:
			return
		var lulu_impact: BluePurpleSmoke = FASHI_IMPACT_SCENE.instantiate()
		lulu_impact.blue_color = Color(1.0, 0.06, 0.03, 0.82)
		lulu_impact.purple_color = Color(0.52, 0.0, 0.02, 0.76)
		var lulu_scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		lulu_scene_root.add_child(lulu_impact)
		lulu_impact.global_position = at_position
		return
	if use_fashi_visual:
		if not hit_damageable_target:
			return
		var fashi_impact: BluePurpleSmoke = FASHI_IMPACT_SCENE.instantiate()
		var fashi_scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		fashi_scene_root.add_child(fashi_impact)
		fashi_impact.global_position = at_position
		return
	if use_happy_student_visual:
		if not hit_damageable_target:
			return
		var student_impact: Fx03Impact = HAPPY_STUDENT_IMPACT_SCENE.instantiate()
		var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
		scene_root.add_child(student_impact)
		student_impact.global_position = at_position
		return
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
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(impact)
	impact.global_position = at_position
	get_tree().create_timer(0.13).timeout.connect(impact.queue_free)
