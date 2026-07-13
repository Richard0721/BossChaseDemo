class_name ChaseBoss
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal died
signal damaged(amount: float, source: Node)

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")

enum State {
	TAUNT,
	WANDER,
	MOVE_RANGED,
	RANGED_CHARGE,
	TRIPLE_BURST,
	MELEE_CHARGE,
	CHARGED_ATTACK,
	CHARGE_WINDUP,
	CHARGING,
	CHARGE_RECOVER,
	LASER_WINDUP,
	LASER_SWEEP,
	RETREAT,
	JUMP_CHARGE,
	JUMP_REPOSITION,
	STUNNED,
	DEAD,
}

enum Difficulty { EASY, NORMAL, HARD }

@export_category("Stats")
@export var max_health := 200.0
@export var ranged_damage := 10.0
@export var melee_damage := 30.0
@export var charged_damage := 60.0
@export var gravity := 20.0
@export var ranged_projectile_speed := 29.12
@export var charged_projectile_speed := 20.8
@export var attack_speed_multiplier := 1.5

@export_category("AI Frequency")
@export_range(0.5, 5.0, 0.1) var jump_cooldown_multiplier := 2.0

@export_category("Movement")
@export var wander_speed := 3.2
@export var combat_move_speed := 5.0
@export var retreat_speed := 12.0
@export var jump_speed := 32.0
@export var charge_speed := 38.0
@export var arena_radius := 112.0

@export_category("Decision Ranges")
@export var detection_distance := 180.0
@export var melee_distance := 8.0
@export var ranged_distance := 18.0

@onready var boss_label: Label3D = $BossLabel
@onready var boss_model: BossModel = $BossModel
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

var health := 200.0
var state := State.TAUNT
var _state_time := 0.0
var _stun_remaining := 0.0
var _close_time := 0.0
var _not_close_time := 0.0
var _ranged_cooldown := 1.0
var _jump_cooldown := 10.0
var _wander_time := 0.0
var _wander_direction := Vector3.ZERO
var _retreat_direction := Vector3.ZERO
var _triple_cooldown := 2.0
var _charge_cooldown := 4.0
var _laser_cooldown := 6.0
var _burst_shots_remaining := 0
var _burst_shot_timer := 0.0
var _charge_direction := Vector3.ZERO
var _charge_hit_targets: Dictionary = {}
var _laser_base_direction := Vector3.FORWARD
var _laser_hit_targets: Dictionary = {}
var _laser_visual: MeshInstance3D
var difficulty := Difficulty.NORMAL
var damage_multiplier := 0.8
var ai_damage_multiplier := 1.5
var explosion_knockback_time := 0.0
var tumble_time := 0.0


func _ready() -> void:
	add_to_group("lock_targets")
	health = max_health
	health_changed.emit(health, max_health)
	_play_state_animation(state)
	_update_state_label()


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta
	_ranged_cooldown = maxf(0.0, _ranged_cooldown - delta)
	_jump_cooldown = maxf(0.0, _jump_cooldown - delta)
	_triple_cooldown = maxf(0.0, _triple_cooldown - delta)
	_charge_cooldown = maxf(0.0, _charge_cooldown - delta)
	_laser_cooldown = maxf(0.0, _laser_cooldown - delta)
	_update_tumble(delta)

	var target: Node3D = _nearest_player()
	if _stun_remaining > 0.0:
		_clear_laser_visual()
		_stun_remaining -= delta
		state = State.STUNNED
		_play_state_animation(State.STUNNED)
		_stop_horizontal(delta)
		_update_state_label(_stun_remaining)
		_finish_frame()
		return
	if explosion_knockback_time > 0.0:
		explosion_knockback_time = maxf(0.0, explosion_knockback_time - delta)
		state = State.STUNNED
		_play_state_animation(State.STUNNED)
		_update_state_label(explosion_knockback_time)
		_finish_frame()
		return

	if _process_committed_state(target, delta):
		_finish_frame()
		return

	if target == null:
		_set_state(State.TAUNT)
		_stop_horizontal(delta)
		_finish_frame()
		return

	var distance_to_player := global_position.distance_to(target.global_position)
	if distance_to_player > detection_distance:
		_set_state(State.TAUNT)
		_close_time = 0.0
		_not_close_time = 0.0
		_stop_horizontal(delta)
		_finish_frame()
		return

	_update_combat_timers(distance_to_player, delta)
	if difficulty == Difficulty.HARD and _laser_cooldown <= 0.0 and distance_to_player <= 80.0:
		_begin_timed_state(State.LASER_WINDUP, 1.5)
	elif difficulty >= Difficulty.NORMAL and _charge_cooldown <= 0.0 and distance_to_player > 7.0 and distance_to_player <= 55.0:
		_begin_timed_state(State.CHARGE_WINDUP, 1.0)
	elif difficulty >= Difficulty.NORMAL and _triple_cooldown <= 0.0 and distance_to_player >= 10.0:
		_burst_shots_remaining = 3
		_burst_shot_timer = 0.0
		_set_state(State.TRIPLE_BURST)
	elif _jump_cooldown <= 0.0:
		_jump_cooldown = _next_jump_cooldown()
		_begin_timed_state(State.JUMP_CHARGE, 0.7)
	elif _close_time >= 6.0:
		_close_time = 0.0
		_begin_timed_state(State.MELEE_CHARGE, 1.5 / attack_speed_multiplier)
	elif difficulty >= Difficulty.NORMAL and _not_close_time >= 10.0:
		_not_close_time = 0.0
		_begin_timed_state(State.CHARGED_ATTACK, 3.0 / attack_speed_multiplier)
	elif distance_to_player >= ranged_distance:
		_set_state(State.MOVE_RANGED)
		_move_and_strafe(target, delta)
		if _ranged_cooldown <= 0.0:
			_ranged_cooldown = 1.1 / attack_speed_multiplier
			_begin_timed_state(State.RANGED_CHARGE, 0.45 / attack_speed_multiplier)
	else:
		_set_state(State.WANDER)
		_update_wander(delta)

	_finish_frame()


func _process_committed_state(target: Node3D, delta: float) -> bool:
	match state:
		State.RANGED_CHARGE:
			_state_time -= delta
			_stop_horizontal(delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				if target != null:
					_fire_remote_attack(target, ranged_damage, false)
				_set_state(State.WANDER)
			return true
		State.TRIPLE_BURST:
			_stop_horizontal(delta)
			_face_target(target, delta)
			_burst_shot_timer -= delta
			_update_state_label(float(_burst_shots_remaining))
			if _burst_shot_timer <= 0.0 and _burst_shots_remaining > 0:
				if target != null:
					_fire_remote_attack(target, ranged_damage, false)
				_burst_shots_remaining -= 1
				_burst_shot_timer = 0.15
			if _burst_shots_remaining <= 0:
				_triple_cooldown = 3.0
				_set_state(State.WANDER)
			return true
		State.MELEE_CHARGE:
			_state_time -= delta
			_stop_horizontal(delta)
			_face_target(target, delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_deal_melee_attack()
				_begin_retreat(target)
			return true
		State.CHARGED_ATTACK:
			_state_time -= delta
			_stop_horizontal(delta)
			_face_target(target, delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				if target != null:
					_fire_remote_attack(target, charged_damage, true)
				_ranged_cooldown = 3.5 / attack_speed_multiplier
				_set_state(State.WANDER)
			return true
		State.CHARGE_WINDUP:
			_state_time -= delta
			_stop_horizontal(delta)
			_face_target(target, delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_charge_direction = _direction_toward(target)
				_charge_hit_targets.clear()
				_begin_timed_state(State.CHARGING, 3.0)
			return true
		State.CHARGING:
			_state_time -= delta
			velocity.x = _charge_direction.x * charge_speed
			velocity.z = _charge_direction.z * charge_speed
			_deal_charge_contacts()
			_update_state_label(_state_time)
			if _state_time <= 0.0 or is_on_wall() or absf(global_position.x) >= arena_radius - 1.0 or absf(global_position.z) >= arena_radius - 1.0:
				velocity.x = 0.0
				velocity.z = 0.0
				_charge_cooldown = 6.0
				_begin_timed_state(State.CHARGE_RECOVER, 0.65)
			return true
		State.CHARGE_RECOVER:
			_state_time -= delta
			_stop_horizontal(delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_set_state(State.WANDER)
			return true
		State.LASER_WINDUP:
			_state_time -= delta
			_stop_horizontal(delta)
			_face_target(target, delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_laser_base_direction = _direction_toward(target)
				_laser_hit_targets.clear()
				_begin_timed_state(State.LASER_SWEEP, 1.2)
			return true
		State.LASER_SWEEP:
			_state_time -= delta
			_stop_horizontal(delta)
			var sweep_progress := clampf(1.0 - _state_time / 1.2, 0.0, 1.0)
			var sweep_angle := deg_to_rad(lerpf(-60.0, 60.0, sweep_progress))
			var sweep_direction := _laser_base_direction.rotated(Vector3.UP, sweep_angle).normalized()
			_update_laser_visual(sweep_direction)
			_deal_laser_damage(sweep_direction)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_clear_laser_visual()
				_laser_cooldown = 8.0
				_set_state(State.WANDER)
			return true
		State.RETREAT:
			_state_time -= delta
			_move_in_direction(_retreat_direction, retreat_speed, delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_set_state(State.WANDER)
			return true
		State.JUMP_CHARGE:
			_state_time -= delta
			_stop_horizontal(delta)
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				var jump_direction := _direction_to_high_ground(target) if difficulty == Difficulty.HARD else _direction_away_from(target)
				velocity.x = jump_direction.x * jump_speed
				velocity.z = jump_direction.z * jump_speed
				velocity.y = _jump_vertical_velocity()
				_begin_timed_state(State.JUMP_REPOSITION, 1.8)
			return true
		State.JUMP_REPOSITION:
			_state_time -= delta
			_update_state_label(_state_time)
			if _state_time <= 0.0:
				_set_state(State.WANDER)
			return true
	return false


func _update_combat_timers(distance_to_player: float, delta: float) -> void:
	if distance_to_player <= melee_distance:
		_close_time += delta
	else:
		_close_time = 0.0
	if distance_to_player > melee_distance + 4.0:
		_not_close_time += delta
	else:
		_not_close_time = 0.0


func _move_and_strafe(target: Node3D, delta: float) -> void:
	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var tangent := Vector3(-to_target.z, 0.0, to_target.x).normalized()
	var distance_weight := clampf((to_target.length() - 24.0) / 12.0, -1.0, 1.0)
	var direction := (tangent + to_target.normalized() * distance_weight * 0.6).normalized()
	_move_in_direction(direction, combat_move_speed, delta)
	_face_target(target, delta)


func _update_wander(delta: float) -> void:
	_wander_time -= delta
	if _wander_time <= 0.0:
		_wander_time = randf_range(1.2, 2.8)
		var angle := randf_range(-PI, PI)
		_wander_direction = Vector3(sin(angle), 0.0, cos(angle))
	_move_in_direction(_wander_direction, wander_speed, delta)


func _begin_retreat(target: Node3D) -> void:
	_retreat_direction = _direction_away_from(target)
	_begin_timed_state(State.RETREAT, 1.6)


func _direction_away_from(target: Node3D) -> Vector3:
	if target == null:
		return Vector3(sin(rotation.y), 0.0, cos(rotation.y)).normalized()
	var away := global_position - target.global_position
	away.y = 0.0
	return away.normalized()


func _deal_melee_attack() -> void:
	_spawn_attack_flash(Color(1.0, 0.18, 0.05, 1.0), 2.8)
	for player in get_tree().get_nodes_in_group("players"):
		if player is Node3D and global_position.distance_to(player.global_position) <= melee_distance + 1.5:
			if player.has_method("apply_damage"):
				player.apply_damage(_damage_for_target(player, melee_damage))


func _fire_remote_attack(target: Node3D, damage: float, charged: bool) -> void:
	var spawn_position := global_position + Vector3.UP * 0.8
	var target_position := target.global_position + Vector3.UP * 0.3
	var projectile_direction := (target_position - spawn_position).normalized()
	var projectile: CombatProjectile = PROJECTILE_SCENE.instantiate()
	var projectile_speed := charged_projectile_speed if charged else ranged_projectile_speed
	var projectile_color := Color(1.0, 0.05, 0.12, 1.0) if charged else Color(1.0, 0.35, 0.08, 1.0)
	projectile.configure(projectile_direction, projectile_speed, damage * damage_multiplier, self, projectile_color, 8.8 if charged else 5.4, ai_damage_multiplier, charged, false, false, false, false, true)
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(projectile)
	projectile.global_position = spawn_position + projectile_direction * 1.25


func _spawn_attack_flash(color: Color, radius: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color.r, color.g, color.b, 0.55)
	material.emission_enabled = true
	material.emission = color
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	var flash := MeshInstance3D.new()
	flash.mesh = sphere_mesh
	flash.material_override = material
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(flash)
	flash.global_position = global_position
	get_tree().create_timer(0.14).timeout.connect(flash.queue_free)


func _direction_toward(target: Node3D) -> Vector3:
	if target == null:
		return -global_basis.z
	var direction := target.global_position - global_position
	direction.y = 0.0
	return direction.normalized()


func _deal_charge_contacts() -> void:
	for target in get_tree().get_nodes_in_group("players"):
		if not target is Node3D or (target.has_method("is_alive") and not target.is_alive()):
			continue
		if global_position.distance_to(target.global_position) > 2.4:
			continue
		var target_id := target.get_instance_id()
		if _charge_hit_targets.has(target_id):
			continue
		_charge_hit_targets[target_id] = true
		if target.has_method("apply_damage"):
			target.apply_damage(_damage_for_target(target, 40.0))
		if target.has_method("apply_knockback"):
			target.apply_knockback(global_position, 24.0, 10.0)


func _direction_to_high_ground(target: Node3D) -> Vector3:
	var high_points := [
		Vector3(-72, 7.2, 5),
		Vector3(68, 10.2, -42),
		Vector3(-8, 4.0, -65),
	]
	var chosen_point: Vector3 = high_points[0]
	var best_score := INF
	for point in high_points:
		var height_bonus := -maxf(0.0, point.y - global_position.y) * 12.0
		var score := global_position.distance_to(point) + height_bonus
		if score < best_score:
			best_score = score
			chosen_point = point
	var direction := chosen_point - global_position
	direction.y = 0.0
	if direction.length_squared() <= 0.01:
		return _direction_away_from(target)
	return direction.normalized()


func _deal_laser_damage(direction: Vector3) -> void:
	var start := global_position + Vector3.UP * 0.7
	var segment := direction * 110.0
	var segment_length_squared := segment.length_squared()
	for target in get_tree().get_nodes_in_group("players"):
		if not target is Node3D or (target.has_method("is_alive") and not target.is_alive()):
			continue
		var target_node := target as Node3D
		var target_id := target.get_instance_id()
		if _laser_hit_targets.has(target_id):
			continue
		var target_position: Vector3 = target_node.global_position + Vector3.UP * 0.5
		var along := clampf((target_position - start).dot(segment) / segment_length_squared, 0.0, 1.0)
		var closest_point := start + segment * along
		if closest_point.distance_to(target_position) <= 2.0:
			_laser_hit_targets[target_id] = true
			if target.has_method("apply_damage"):
				target.apply_damage(_damage_for_target(target, 30.0))


func _update_laser_visual(direction: Vector3) -> void:
	if not is_instance_valid(_laser_visual):
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.32
		mesh.bottom_radius = 0.32
		mesh.height = 110.0
		mesh.radial_segments = 10
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1.0, 0.015, 0.025, 0.92)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.0, 0.015, 1.0)
		material.emission_energy_multiplier = 5.0
		_laser_visual = MeshInstance3D.new()
		_laser_visual.mesh = mesh
		_laser_visual.material_override = material
		(get_tree().current_scene if get_tree().current_scene != null else get_tree().root).add_child(_laser_visual)
	var start := global_position + Vector3.UP * 0.7
	_laser_visual.global_transform = Transform3D(_basis_with_y_axis(direction), start + direction * 55.0)


func _basis_with_y_axis(y_axis: Vector3) -> Basis:
	var helper := Vector3.UP
	if absf(y_axis.dot(helper)) > 0.98:
		helper = Vector3.RIGHT
	var x_axis := helper.cross(y_axis).normalized()
	var z_axis := x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


func _clear_laser_visual() -> void:
	if is_instance_valid(_laser_visual):
		_laser_visual.queue_free()
	_laser_visual = null


func _nearest_player() -> Node3D:
	var result: Node3D
	var nearest := INF
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Node3D:
			continue
		if player.has_method("is_alive") and not player.is_alive():
			continue
		var distance_to_player := global_position.distance_squared_to(player.global_position)
		if distance_to_player < nearest:
			nearest = distance_to_player
			result = player
	return result


func _face_target(target: Node3D, delta: float) -> void:
	if target == null:
		return
	var direction := target.global_position - global_position
	direction.y = 0.0
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 7.0 * delta)


func _move_in_direction(direction: Vector3, speed: float, delta: float) -> void:
	velocity.x = move_toward(velocity.x, direction.x * speed, 18.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, 18.0 * delta)
	if direction.length_squared() > 0.01:
		rotation.y = lerp_angle(rotation.y, atan2(direction.x, direction.z), 6.0 * delta)


func _stop_horizontal(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)


func _begin_timed_state(next_state: State, duration: float) -> void:
	state = next_state
	_state_time = duration
	_play_state_animation(next_state)
	_update_state_label(duration)


func _set_state(next_state: State) -> void:
	if state != next_state:
		state = next_state
		_play_state_animation(next_state)
		_update_state_label()


func _play_state_animation(next_state: State) -> void:
	match next_state:
		State.TAUNT:
			boss_model.play_animation(&"taunt")
		State.WANDER, State.MOVE_RANGED, State.RETREAT:
			boss_model.play_animation(&"walk")
		State.RANGED_CHARGE, State.TRIPLE_BURST, State.CHARGED_ATTACK, State.LASER_WINDUP, State.LASER_SWEEP, State.JUMP_CHARGE:
			boss_model.play_animation(&"taunt")
		State.MELEE_CHARGE:
			boss_model.play_animation(&"melee", 0.1, 1.0, true)
		State.CHARGE_WINDUP, State.CHARGING:
			boss_model.play_animation(&"charge")
		State.CHARGE_RECOVER:
			boss_model.play_animation(&"charge_impact", 0.08, 1.0, true)
		State.JUMP_REPOSITION:
			boss_model.play_animation(&"jump", 0.1, 1.0, true)
		State.STUNNED:
			boss_model.play_animation(&"stunned")


func _finish_frame() -> void:
	move_and_slide()
	global_position.x = clampf(global_position.x, -arena_radius, arena_radius)
	global_position.z = clampf(global_position.z, -arena_radius, arena_radius)


func apply_damage(amount: float, source: Node = null) -> void:
	if state == State.DEAD:
		return
	var previous_health := health
	health = maxf(0.0, health - amount)
	var actual_damage := previous_health - health
	if actual_damage > 0.0:
		damaged.emit(actual_damage, source)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_clear_laser_visual()
		state = State.DEAD
		velocity = Vector3.ZERO
		collision_shape.set_deferred("disabled", true)
		boss_label.visible = false
		boss_model.play_animation(&"death", 0.08, 1.0, true)
		died.emit()
		get_tree().create_timer(boss_model.get_animation_length(&"death") + 0.1).timeout.connect(queue_free)


func apply_blast_effect(amount: float, origin: Vector3, horizontal_force: float, vertical_force: float, duration: float, source: Node = null) -> void:
	if state == State.DEAD:
		return
	apply_damage(amount, source)
	if state == State.DEAD:
		return
	var away := global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -global_basis.z
		away.y = 0.0
	away = away.normalized()
	velocity.x = away.x * horizontal_force
	velocity.z = away.z * horizontal_force
	velocity.y = vertical_force
	explosion_knockback_time = maxf(explosion_knockback_time, duration)
	tumble_time = maxf(tumble_time, duration)
	_clear_laser_visual()


func apply_stun_damage(amount: float, duration: float, source: Node = null) -> void:
	if state == State.DEAD:
		return
	_stun_remaining = maxf(_stun_remaining, duration)
	apply_damage(amount, source)


func apply_knockback(origin: Vector3, horizontal_force: float, vertical_force: float) -> void:
	var away := global_position - origin
	away.y = 0.0
	away = away.normalized()
	velocity.x = away.x * horizontal_force
	velocity.z = away.z * horizontal_force
	velocity.y = vertical_force
	explosion_knockback_time = maxf(explosion_knockback_time, 0.85)
	_clear_laser_visual()


func apply_tumble(duration: float) -> void:
	tumble_time = maxf(tumble_time, duration)


func _update_tumble(delta: float) -> void:
	if tumble_time > 0.0:
		tumble_time -= delta
		boss_model.rotation.x += delta * 11.0
		boss_model.rotation.z += delta * 7.0
	else:
		boss_model.rotation.x = lerp_angle(boss_model.rotation.x, 0.0, 10.0 * delta)
		boss_model.rotation.z = lerp_angle(boss_model.rotation.z, 0.0, 10.0 * delta)


func configure_for_match(party_size: int, selected_difficulty: int) -> void:
	var clamped_party_size := clampi(party_size, 1, 4)
	difficulty = clampi(selected_difficulty, Difficulty.EASY, Difficulty.HARD)
	max_health = 100.0 + 50.0 * float(clamped_party_size - 1)
	match difficulty:
		Difficulty.EASY:
			damage_multiplier = 0.6
			ai_damage_multiplier = 1.0
			_jump_cooldown = 8.0 * jump_cooldown_multiplier
		Difficulty.NORMAL:
			damage_multiplier = 0.8
			ai_damage_multiplier = 1.5
			_jump_cooldown = 5.0 * jump_cooldown_multiplier
		Difficulty.HARD:
			damage_multiplier = 1.0
			ai_damage_multiplier = 2.0
			_jump_cooldown = 3.0 * jump_cooldown_multiplier
	health = max_health
	health_changed.emit(health, max_health)


func configure_for_party_size(party_size: int) -> void:
	configure_for_match(party_size, Difficulty.NORMAL)


func _damage_for_target(target: Node, base_damage: float) -> float:
	var result := base_damage * damage_multiplier
	if target.is_in_group("ai_teammates"):
		result *= ai_damage_multiplier
	return result


func _next_jump_cooldown() -> float:
	match difficulty:
		Difficulty.EASY:
			return randf_range(8.0, 10.0) * jump_cooldown_multiplier
		Difficulty.NORMAL:
			return randf_range(5.0, 7.0) * jump_cooldown_multiplier
		_:
			return randf_range(3.0, 4.5) * jump_cooldown_multiplier


func _jump_vertical_velocity() -> float:
	match difficulty:
		Difficulty.EASY:
			return 8.5
		Difficulty.NORMAL:
			return 12.0
		_:
			return 17.0


func get_state_name() -> String:
	return State.keys()[state].capitalize()


func _update_state_label(countdown := -1.0) -> void:
	if countdown >= 0.0:
		boss_label.text = "%s  %.1f" % [get_state_name(), maxf(0.0, countdown)]
	else:
		boss_label.text = get_state_name()
