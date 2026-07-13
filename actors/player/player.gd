class_name ThirdPersonPlayer
extends CharacterBody3D

signal health_changed(current: float, maximum: float)
signal aim_changed(is_aiming: bool)
signal active_item_changed(item_name: String)
signal stamina_changed(current: float, maximum: float, exhausted: bool)
signal ammo_changed(current: int, maximum: int)
signal died(member: ThirdPersonPlayer)

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")
const HAMMER_PROJECTILE_SCENE := preload("res://items/hammer/hammer_projectile.tscn")
const LANDMINE_SCENE := preload("res://items/landmine/landmine.tscn")

@export_category("Movement")
@export var walk_speed := 7.0
@export var sprint_speed := 21.45
@export var acceleration := 28.0
@export var air_acceleration := 8.0
@export var jump_velocity := 10.5
@export var gravity := 20.0
@export var max_stamina := 100.0
@export var stamina_drain_per_second := 28.0
@export var stamina_recovery_per_second := 33.34

@export_category("Combat")
@export var max_health := 100.0
@export var ranged_damage := 1.0
@export var melee_damage := 1.0
@export var ranged_interval := 0.25
@export var melee_interval := 1.0 / 3.0
@export var projectile_speed := 48.0
@export var hammer_damage := 20.0
@export var magazine_size := 50
@export var starting_reserve_ammo := 300

@export_category("Camera")
@export var mouse_sensitivity := 0.0025
@export var lock_distance := 40.0
@export var default_camera_distance := 5.2
@export var aim_camera_distance := 3.0
@export var aim_shoulder_offset := 0.85
@export var default_fov := 72.0
@export var aim_fov := 50.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/SpringArm3D/Camera3D
@onready var visuals: Node3D = $Visuals
@onready var muzzle: Marker3D = $Visuals/Muzzle
@onready var character_special: CharacterSpecial = $CharacterSpecial
@onready var buff_component: BuffComponent = $BuffComponent
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var gun_visual: MeshInstance3D = $Visuals/Gun
@onready var held_item_visual: MeshInstance3D = $Visuals/HeldItem
@onready var left_hand_visual: MeshInstance3D = $Visuals/LeftHand
@onready var right_hand_visual: MeshInstance3D = $Visuals/RightHand

var health := 100.0
var _pitch := -0.18
var _ranged_cooldown := 0.0
var _melee_cooldown := 0.0
var _lock_target: Node3D
var _is_aiming := false
var _item_slots: Array[StringName] = [&"Ranged"]
var _active_item_index := 0
var stamina := 100.0
var _stamina_exhausted := false
var _stamina_recovery_delay := 0.0
var _hammer_charge_remaining := -1.0
var ammo := 50
var reserve_ammo := 300
var inventory_item: StringName = &""
var rapid_ammo := 0
var shield_durability := 0.0
var reload_remaining := -1.0
var propeller_time := 0.0
var propeller_fall_active := false
var third_jump_airborne := false
var knockback_lock_time := 0.0
var tumble_time := 0.0
var _jumps_remaining := 1
var is_dead := false
var invincible_remaining := 0.0
var spawn_position := Vector3.ZERO


func _ready() -> void:
	add_to_group("players")
	spawn_position = global_position
	health = max_health
	camera_pivot.rotation.x = _pitch
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	health_changed.emit(health, max_health)
	stamina = max_stamina
	ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	stamina_changed.emit(stamina, max_stamina, _stamina_exhausted)
	ammo_changed.emit(ammo, reserve_ammo)
	active_item_changed.emit(get_active_item_name())
	_jumps_remaining = get_allowed_jump_count()
	_apply_selected_character_appearance()
	_update_equipment_visual()


func _apply_selected_character_appearance() -> void:
	var colors := {
		"头疼的符文大师": Color(0.08, 0.9, 0.65, 1),
		"快乐的本科生": Color(1.0, 0.58, 0.1, 1),
		"神秘兜帽人": Color(0.48, 0.16, 0.9, 1),
		"潇洒的男子 Lulu": Color(0.05, 0.58, 1.0, 1),
	}
	var selected_color: Color = colors.get(get_character_name(), Color(0.15, 0.55, 1, 1))
	var material := StandardMaterial3D.new()
	material.albedo_color = selected_color
	material.metallic = 0.15
	material.roughness = 0.42
	$Visuals/Body.material_override = material
	$Visuals/Head.material_override = material


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not is_instance_valid(_lock_target):
		camera_pivot.rotate_y(-event.relative.x * mouse_sensitivity)
		_pitch = clampf(_pitch - event.relative.y * mouse_sensitivity, -1.15, 0.65)
		camera_pivot.rotation.x = _pitch
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_cycle_item(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_cycle_item(1)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	invincible_remaining = maxf(0.0, invincible_remaining - delta)
	_ranged_cooldown = maxf(0.0, _ranged_cooldown - delta)
	_melee_cooldown = maxf(0.0, _melee_cooldown - delta)
	_update_reload(delta)
	_update_propeller(delta)
	_update_tumble(delta)

	if Input.is_action_just_pressed("toggle_lock"):
		_toggle_camera_lock()
	_update_camera_lock(delta)
	_update_aim_camera(delta)
	_update_hammer_charge(delta)
	_update_movement(delta)
	_update_combat()
	move_and_slide()


func _update_aim_camera(delta: float) -> void:
	var active_mode := get_active_item_name()
	var wants_to_aim := Input.is_action_pressed("aim") and active_mode in ["Ranged", "Hammer", "RapidGun"]
	if wants_to_aim != _is_aiming:
		_is_aiming = wants_to_aim
		aim_changed.emit(_is_aiming)
	var spring_arm: SpringArm3D = $CameraPivot/SpringArm3D
	var target_distance := aim_camera_distance if _is_aiming else default_camera_distance
	var target_offset := aim_shoulder_offset if _is_aiming else 0.0
	var target_fov := aim_fov if _is_aiming else default_fov
	spring_arm.spring_length = lerpf(spring_arm.spring_length, target_distance, 10.0 * delta)
	spring_arm.position.x = lerpf(spring_arm.position.x, target_offset, 10.0 * delta)
	camera.fov = lerpf(camera.fov, target_fov, 10.0 * delta)


func _update_movement(delta: float) -> void:
	if propeller_time > 0.0:
		if Input.is_action_pressed("jump"):
			velocity.y = move_toward(velocity.y, 8.0, 22.0 * delta)
		elif Input.is_action_pressed("fly_down"):
			velocity.y = move_toward(velocity.y, -6.0, 22.0 * delta)
		else:
			velocity.y = move_toward(velocity.y, 0.0, 16.0 * delta)
	elif not is_on_floor():
		var slow_fall := Input.is_action_pressed("aim") and (third_jump_airborne or propeller_fall_active)
		velocity.y -= gravity * (0.25 if slow_fall else 1.0) * delta
	else:
		_jumps_remaining = get_allowed_jump_count()
		third_jump_airborne = false
		propeller_fall_active = false
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			_jumps_remaining = get_allowed_jump_count() - 1
		elif _jumps_remaining > 0:
			if get_allowed_jump_count() >= 3 and _jumps_remaining == 1:
				third_jump_airborne = true
			velocity.y = jump_velocity
			_jumps_remaining -= 1
	if knockback_lock_time > 0.0:
		knockback_lock_time = maxf(0.0, knockback_lock_time - delta)
		return

	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var camera_forward := -camera_pivot.global_basis.z
	var camera_right := camera_pivot.global_basis.x
	camera_forward.y = 0.0
	camera_right.y = 0.0
	var direction := (camera_right.normalized() * input_vector.x + camera_forward.normalized() * -input_vector.y).normalized()
	var sprinting := Input.is_action_pressed("sprint") and direction.length_squared() > 0.01 and not _stamina_exhausted and stamina > 0.0
	_update_stamina(delta, sprinting)
	var move_multiplier := character_special.get_move_multiplier() * buff_component.get_move_multiplier()
	var target_speed := (sprint_speed if sprinting else walk_speed) * move_multiplier
	var target_velocity := direction * target_speed
	var current_acceleration := acceleration if is_on_floor() else air_acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, current_acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, current_acceleration * delta)

	if direction.length_squared() > 0.01:
		# Rotate only the visible character. Rotating the CharacterBody would also
		# rotate its child camera rig and feed the new camera direction back into
		# movement, which makes held WASD input spiral in circles.
		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(direction.x, direction.z), 10.0 * delta)


func _update_combat() -> void:
	if Input.is_action_just_pressed("interact"):
		_try_interact()
	if Input.is_action_just_pressed("discard_item"):
		_discard_inventory_item()
	var active_mode := get_active_item_name()
	if active_mode == "Hammer":
		if Input.is_action_just_pressed("ranged_attack") and _hammer_charge_remaining < 0.0 and _melee_cooldown <= 0.0:
			if Input.is_action_pressed("aim"):
				_throw_hammer()
			else:
				_hammer_charge_remaining = 1.0 / get_total_attack_speed(true)
	elif active_mode == "RapidGun":
		if Input.is_action_pressed("aim") and Input.is_action_pressed("ranged_attack") and _ranged_cooldown <= 0.0 and rapid_ammo > 0:
			_ranged_cooldown = ranged_interval / 3.0 / get_total_attack_speed(false)
			rapid_ammo -= 1
			ammo_changed.emit(rapid_ammo, 0)
			_fire_projectile(ranged_damage * 2.0)
			if rapid_ammo <= 0:
				_remove_inventory_item()
	elif active_mode == "Ranged":
		if Input.is_action_just_pressed("reload"):
			_start_reload()
		if Input.is_action_pressed("aim") and Input.is_action_pressed("ranged_attack") and _ranged_cooldown <= 0.0 and ammo > 0 and reload_remaining < 0.0:
			_ranged_cooldown = ranged_interval / get_total_attack_speed(false)
			ammo -= 1
			ammo_changed.emit(ammo, reserve_ammo)
			_fire_projectile(ranged_damage)
		elif not Input.is_action_pressed("aim") and Input.is_action_pressed("ranged_attack") and _melee_cooldown <= 0.0:
			_melee_cooldown = melee_interval / get_total_attack_speed(true)
			_perform_basic_melee()
	elif active_mode in ["Propeller", "Shield", "Landmine"]:
		if Input.is_action_just_pressed("ranged_attack"):
			_use_inventory_item(active_mode)


func _fire_projectile(base_damage: float) -> void:
	var ray_from := camera.global_position
	var ray_to := ray_from + -camera.global_basis.z * 160.0
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var aim_position := ray_to
	if not hit.is_empty():
		aim_position = hit["position"]
	var projectile: CombatProjectile = PROJECTILE_SCENE.instantiate()
	var projectile_direction := (aim_position - muzzle.global_position).normalized()
	projectile.configure(projectile_direction, projectile_speed, base_damage * buff_component.get_attack_multiplier(), self, Color(1.0, 0.76, 0.12, 1.0), 1.0)
	projectile.global_position = muzzle.global_position + projectile_direction * 0.55
	get_tree().current_scene.add_child(projectile)
	_spawn_muzzle_flash()
	_pitch = clampf(_pitch - 0.018, -1.15, 0.65)
	camera_pivot.rotation.x = _pitch


func _perform_basic_melee() -> void:
	var ray_from := global_position + Vector3.UP * 0.45
	var attack_direction := -camera.global_basis.z
	attack_direction.y = 0.0
	attack_direction = attack_direction.normalized()
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_from + attack_direction * 3.2)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit["collider"]
	if collider != null and collider.has_method("apply_damage"):
		collider.apply_damage(melee_damage * buff_component.get_attack_multiplier(), self)
	_spawn_basic_melee_feedback(attack_direction)


func _spawn_basic_melee_feedback(direction: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.4, 0.18, 1.8)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.6, 0.88, 1.0, 0.38)
	material.emission_enabled = true
	material.emission = Color(0.25, 0.65, 1.0, 1.0)
	var slash := MeshInstance3D.new()
	slash.mesh = mesh
	slash.material_override = material
	slash.global_position = global_position + Vector3.UP * 0.55 + direction * 1.4
	slash.rotation.y = atan2(direction.x, direction.z)
	get_tree().current_scene.add_child(slash)
	get_tree().create_timer(0.1).timeout.connect(slash.queue_free)


func _spawn_muzzle_flash() -> void:
	var tracer_material := StandardMaterial3D.new()
	tracer_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer_material.albedo_color = Color(1.0, 0.82, 0.2, 1.0)
	tracer_material.emission_enabled = true
	tracer_material.emission = Color(1.0, 0.45, 0.03, 1.0)

	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.11
	flash_mesh.height = 0.22
	var flash := MeshInstance3D.new()
	flash.mesh = flash_mesh
	flash.material_override = tracer_material
	flash.global_position = muzzle.global_position
	get_tree().current_scene.add_child(flash)
	get_tree().create_timer(0.055).timeout.connect(flash.queue_free)


func _update_hammer_charge(delta: float) -> void:
	if _hammer_charge_remaining < 0.0:
		return
	_hammer_charge_remaining -= delta
	if _hammer_charge_remaining <= 0.0:
		_hammer_charge_remaining = -1.0
		_melee_cooldown = melee_interval
		_release_hammer_slam()


func _release_hammer_slam() -> void:
	var attack_radius := 6.0
	for target in get_tree().get_nodes_in_group("lock_targets"):
		if target is Node3D and global_position.distance_to(target.global_position) <= attack_radius:
			if target.has_method("apply_damage"):
				target.apply_damage(hammer_damage * character_special.get_melee_damage_multiplier() * buff_component.get_attack_multiplier(), self)
	for teammate in get_tree().get_nodes_in_group("players"):
		if teammate == self or not teammate is Node3D:
			continue
		if global_position.distance_to(teammate.global_position) <= attack_radius:
			if teammate.has_method("apply_damage"):
				teammate.apply_damage(hammer_damage * character_special.get_melee_damage_multiplier() * buff_component.get_attack_multiplier())
			if teammate.has_method("apply_knockback"):
				teammate.apply_knockback(global_position, 17.0, 7.5)
	_spawn_hammer_slam_feedback(attack_radius)


func _spawn_hammer_slam_feedback(radius: float) -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.55, 0.05, 0.32)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.18, 0.01, 1.0)
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 0.5
	var effect := MeshInstance3D.new()
	effect.mesh = sphere_mesh
	effect.material_override = material
	effect.global_position = global_position
	get_tree().current_scene.add_child(effect)
	get_tree().create_timer(0.16).timeout.connect(effect.queue_free)


func _throw_hammer() -> void:
	var throw_direction := -camera.global_basis.z
	var hammer: ThrownHammer = HAMMER_PROJECTILE_SCENE.instantiate()
	hammer.configure(throw_direction, self, 0.0)
	hammer.global_position = global_position + Vector3.UP * 0.65 + throw_direction * 1.1
	get_tree().current_scene.add_child(hammer)
	_remove_hammer()


func _try_interact() -> void:
	var nearest_interactable: Node3D
	var nearest_distance := 3.2
	for candidate in get_tree().get_nodes_in_group("interactables"):
		if not candidate is Node3D:
			continue
		var distance_to_candidate := global_position.distance_to(candidate.global_position)
		if distance_to_candidate < nearest_distance:
			nearest_distance = distance_to_candidate
			nearest_interactable = candidate
	if nearest_interactable != null and nearest_interactable.has_method("interact"):
		nearest_interactable.interact(self)


func add_hammer() -> void:
	receive_item(&"Hammer")


func receive_item(item_type: StringName) -> bool:
	if not inventory_item.is_empty():
		return false
	inventory_item = item_type
	character_special.record_item(item_type)
	match item_type:
		&"RapidGun":
			rapid_ammo = 100
		&"Shield":
			shield_durability = 100.0
	_rebuild_item_slots()
	return true


func has_inventory_item() -> bool:
	return not inventory_item.is_empty()


func _rebuild_item_slots() -> void:
	_item_slots = [&"Ranged"]
	if not inventory_item.is_empty():
		_item_slots.append(inventory_item)
	_active_item_index = _item_slots.size() - 1
	reload_remaining = -1.0
	active_item_changed.emit(get_active_item_name())
	_emit_current_ammo()
	_update_equipment_visual()


func _remove_hammer() -> void:
	_remove_inventory_item()


func _discard_inventory_item() -> void:
	if inventory_item.is_empty():
		return
	_hammer_charge_remaining = -1.0
	reload_remaining = -1.0
	_remove_inventory_item()


func _remove_inventory_item() -> void:
	inventory_item = &""
	rapid_ammo = 0
	shield_durability = 0.0
	propeller_time = 0.0
	_rebuild_item_slots()


func _start_reload() -> void:
	if reload_remaining >= 0.0 or ammo >= magazine_size or reserve_ammo <= 0:
		return
	reload_remaining = 1.5


func _update_reload(delta: float) -> void:
	if reload_remaining < 0.0:
		return
	reload_remaining -= delta
	if reload_remaining <= 0.0:
		var rounds_needed := magazine_size - ammo
		var loaded := mini(rounds_needed, reserve_ammo)
		ammo += loaded
		reserve_ammo -= loaded
		reload_remaining = -1.0
		ammo_changed.emit(ammo, reserve_ammo)


func _use_inventory_item(active_mode: String) -> void:
	match active_mode:
		"Propeller":
			if propeller_time <= 0.0:
				propeller_time = 10.0
		"Landmine":
			var mine := LANDMINE_SCENE.instantiate()
			var forward := -camera.global_basis.z
			forward.y = 0.0
			mine.global_position = global_position + forward.normalized() * 1.8 + Vector3.UP * 0.15
			if mine.has_method("set_source_owner"):
				mine.set_source_owner(self)
			get_tree().current_scene.add_child(mine)
			_remove_inventory_item()
		"Shield":
			pass


func _update_propeller(delta: float) -> void:
	if propeller_time <= 0.0:
		return
	propeller_time -= delta
	if propeller_time <= 0.0:
		propeller_fall_active = true
		_remove_inventory_item()


func reset_shield_durability() -> void:
	if inventory_item == &"Shield":
		shield_durability = 100.0


func _emit_current_ammo() -> void:
	if get_active_item_name() == "RapidGun":
		ammo_changed.emit(rapid_ammo, 0)
	else:
		ammo_changed.emit(ammo, reserve_ammo)


func _update_stamina(delta: float, sprinting: bool) -> void:
	var previous_stamina := stamina
	var previous_exhausted := _stamina_exhausted
	if sprinting:
		stamina = maxf(0.0, stamina - stamina_drain_per_second * delta)
		_stamina_recovery_delay = 0.5
		if stamina <= 0.0:
			_stamina_exhausted = true
	else:
		if _stamina_exhausted:
			stamina = minf(max_stamina, stamina + stamina_recovery_per_second * delta)
		else:
			_stamina_recovery_delay = maxf(0.0, _stamina_recovery_delay - delta)
			if _stamina_recovery_delay <= 0.0:
				stamina = minf(max_stamina, stamina + stamina_recovery_per_second * delta)
		if _stamina_exhausted and stamina >= max_stamina:
			_stamina_exhausted = false
	if not is_equal_approx(previous_stamina, stamina) or previous_exhausted != _stamina_exhausted:
		stamina_changed.emit(stamina, max_stamina, _stamina_exhausted)


func _cycle_item(direction: int) -> void:
	if _item_slots.is_empty():
		return
	_active_item_index = wrapi(_active_item_index + direction, 0, _item_slots.size())
	reload_remaining = -1.0
	active_item_changed.emit(get_active_item_name())
	_emit_current_ammo()
	_update_equipment_visual()


func _update_equipment_visual() -> void:
	if not is_node_ready():
		return
	var active_mode := get_active_item_name()
	gun_visual.visible = active_mode in ["Ranged", "RapidGun"]
	var holding_item := active_mode not in ["Ranged", "RapidGun"]
	held_item_visual.visible = holding_item
	left_hand_visual.visible = holding_item
	right_hand_visual.visible = holding_item
	if holding_item:
		var colors := {
			"Hammer": Color(1.0, 0.55, 0.04, 1),
			"Propeller": Color(0.15, 0.85, 1.0, 1),
			"Shield": Color(0.85, 0.9, 1.0, 1),
			"Landmine": Color(0.18, 0.2, 0.22, 1),
		}
		var material := StandardMaterial3D.new()
		material.albedo_color = colors.get(active_mode, Color(0.5, 0.7, 1, 1))
		material.metallic = 0.45
		held_item_visual.material_override = material


func get_active_item_name() -> String:
	if _item_slots.is_empty():
		return "None"
	return String(_item_slots[_active_item_index])


func _toggle_camera_lock() -> void:
	if is_instance_valid(_lock_target):
		_lock_target = null
		return
	var nearest_distance := lock_distance
	for candidate in get_tree().get_nodes_in_group("lock_targets"):
		if not candidate is Node3D:
			continue
		var distance_to_candidate := global_position.distance_to(candidate.global_position)
		if distance_to_candidate < nearest_distance:
			nearest_distance = distance_to_candidate
			_lock_target = candidate


func _update_camera_lock(delta: float) -> void:
	if not is_instance_valid(_lock_target):
		_lock_target = null
		return
	if global_position.distance_to(_lock_target.global_position) > lock_distance * 1.25:
		_lock_target = null
		return
	var flat_direction := _lock_target.global_position - global_position
	flat_direction.y = 0.0
	if flat_direction.length_squared() > 0.01:
		var target_yaw := atan2(-flat_direction.x, -flat_direction.z)
		camera_pivot.rotation.y = lerp_angle(camera_pivot.rotation.y, target_yaw, 8.0 * delta)
	var target_pitch := clampf(-0.12 - (_lock_target.global_position.y - global_position.y) * 0.025, -0.7, 0.35)
	_pitch = lerpf(_pitch, target_pitch, 5.0 * delta)
	camera_pivot.rotation.x = _pitch


func apply_damage(amount: float, _stun := false) -> void:
	if is_dead or invincible_remaining > 0.0:
		return
	if buff_component.try_block_damage():
		return
	if propeller_time > 0.0:
		propeller_fall_active = true
		_remove_inventory_item()
	if inventory_item == &"Shield" and get_active_item_name() == "Shield" and shield_durability > 0.0:
		var absorbed := minf(shield_durability, amount)
		shield_durability -= absorbed
		amount -= absorbed
		if shield_durability <= 0.0:
			_remove_inventory_item()
		if amount <= 0.0:
			return
	amount *= buff_component.get_damage_taken_multiplier()
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func apply_blast_effect(amount: float, origin: Vector3, horizontal_force: float, vertical_force: float, duration: float, _source: Node = null) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()
		return
	_apply_forced_blast_motion(origin, horizontal_force, vertical_force, duration)


func _apply_forced_blast_motion(origin: Vector3, horizontal_force: float, vertical_force: float, duration: float) -> void:
	var away := global_position - origin
	away.y = 0.0
	if away.length_squared() < 0.01:
		away = -visuals.global_basis.z
		away.y = 0.0
	away = away.normalized()
	velocity.x = away.x * horizontal_force
	velocity.z = away.z * horizontal_force
	velocity.y = vertical_force
	knockback_lock_time = maxf(knockback_lock_time, duration)
	tumble_time = maxf(tumble_time, duration)


func apply_health_drain(amount: float) -> void:
	if is_dead:
		return
	health = maxf(0.0, health - amount)
	health_changed.emit(health, max_health)
	if health <= 0.0:
		_die()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func apply_rune(rune_type: StringName) -> void:
	buff_component.apply_rune(rune_type)


func get_character_special() -> CharacterSpecial:
	return character_special


func get_allowed_jump_count() -> int:
	return character_special.get_jump_count_with_speed_rune(buff_component.has_speed_rune())


func get_total_attack_speed(melee: bool) -> float:
	var special_multiplier := character_special.get_melee_attack_speed_multiplier() if melee else character_special.get_ranged_attack_speed_multiplier()
	return special_multiplier * buff_component.get_attack_speed_multiplier()


func get_character_name() -> String:
	return character_special.get_character_name()


func get_buff_status_text() -> String:
	return buff_component.get_status_text()


func _die() -> void:
	if is_dead:
		return
	is_dead = true
	velocity = Vector3.ZERO
	visuals.visible = false
	collision_shape.set_deferred("disabled", true)
	died.emit(self)


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	is_dead = false
	invincible_remaining = 3.0
	visuals.visible = true
	collision_shape.set_deferred("disabled", false)
	health_changed.emit(health, max_health)
	set_camera_active(true)


func set_camera_active(active: bool) -> void:
	camera.current = active


func is_alive() -> bool:
	return not is_dead


func apply_knockback(origin: Vector3, horizontal_force: float, vertical_force: float) -> void:
	var away := global_position - origin
	away.y = 0.0
	away = away.normalized()
	velocity.x = away.x * horizontal_force
	velocity.z = away.z * horizontal_force
	velocity.y = vertical_force
	knockback_lock_time = maxf(knockback_lock_time, 0.85)


func apply_tumble(duration: float) -> void:
	tumble_time = maxf(tumble_time, duration)


func _update_tumble(delta: float) -> void:
	if tumble_time > 0.0:
		tumble_time -= delta
		visuals.rotation.x += delta * 11.0
		visuals.rotation.z += delta * 7.0
	elif absf(visuals.rotation.x) > 0.001 or absf(visuals.rotation.z) > 0.001:
		visuals.rotation.x = lerp_angle(visuals.rotation.x, 0.0, 10.0 * delta)
		visuals.rotation.z = lerp_angle(visuals.rotation.z, 0.0, 10.0 * delta)


func get_hammer_charge_remaining() -> float:
	return _hammer_charge_remaining


func is_aiming() -> bool:
	return _is_aiming
