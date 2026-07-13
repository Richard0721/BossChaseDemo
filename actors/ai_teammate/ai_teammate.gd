class_name AITeammate
extends CharacterBody3D

signal died(member: AITeammate)
signal health_changed(current: float, maximum: float)

const PROJECTILE_SCENE := preload("res://combat/projectile.tscn")

@export var gravity := 20.0
@export var move_speed := 8.0
@export var projectile_speed := 48.0
@export var attack_interval := 0.7
@export var attack_distance := 62.0

var character_name := "AI"
var max_health := 100.0
var health := 100.0
var is_dead := false
var invincible_remaining := 0.0
var _attack_cooldown := 0.0
var spawn_position := Vector3.ZERO
var knockback_lock_time := 0.0
var tumble_time := 0.0

@onready var visuals: Node3D = $Visuals
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var muzzle: Marker3D = $Visuals/Muzzle
@onready var name_label: Label3D = $NameLabel
@onready var happy_student: HappyStudentModel = $Visuals/HappyStudent
@onready var fashi: FashiModel = $Visuals/Fashi
@onready var lulu: LuluModel = $Visuals/Lulu
@onready var doumaoren: DoumaorenModel = $Visuals/Doumaoren


func setup(new_character_name: String, new_spawn_position: Vector3) -> void:
	character_name = new_character_name
	spawn_position = new_spawn_position
	position = new_spawn_position
	if character_name == "快乐的本科生":
		max_health = 150.0
	if character_name == "潇洒的男子 Lulu":
		move_speed *= 1.2
	health = max_health


func _ready() -> void:
	add_to_group("players")
	add_to_group("ai_teammates")
	name_label.text = "%s [AI]" % character_name
	_apply_appearance()
	health_changed.emit(health, max_health)


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	invincible_remaining = maxf(0.0, invincible_remaining - delta)
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	_update_character_animation()
	if not is_on_floor():
		velocity.y -= gravity * delta
	_update_tumble(delta)
	if knockback_lock_time > 0.0:
		knockback_lock_time = maxf(0.0, knockback_lock_time - delta)
		move_and_slide()
		return
	var boss := _find_boss()
	if boss == null:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		move_and_slide()
		return
	var to_boss := boss.global_position - global_position
	var distance := to_boss.length()
	var flat_direction := Vector3(to_boss.x, 0.0, to_boss.z).normalized()
	if distance > 18.0:
		velocity.x = move_toward(velocity.x, flat_direction.x * move_speed, 20.0 * delta)
		velocity.z = move_toward(velocity.z, flat_direction.z * move_speed, 20.0 * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
	if flat_direction.length_squared() > 0.01:
		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(flat_direction.x, flat_direction.z), 8.0 * delta)
	if distance <= attack_distance and _attack_cooldown <= 0.0:
		_attack_cooldown = attack_interval
		_fire_at_boss(boss)
	move_and_slide()


func _find_boss() -> Node3D:
	var targets := get_tree().get_nodes_in_group("lock_targets")
	if targets.is_empty():
		return null
	return targets[0] as Node3D


func _fire_at_boss(boss: Node3D) -> void:
	var direction := (boss.global_position + Vector3.UP * 0.5 - muzzle.global_position).normalized()
	var projectile: CombatProjectile = PROJECTILE_SCENE.instantiate()
	projectile.configure(direction, projectile_speed, 1.0, self, Color(0.35, 0.9, 1.0, 1), 0.9, 1.0, false, character_name == "快乐的本科生", character_name == "头疼的符文大师", character_name == "潇洒的男子 Lulu", character_name == "神秘兜帽人")
	var scene_root := get_tree().current_scene if get_tree().current_scene != null else get_tree().root
	scene_root.add_child(projectile)
	projectile.global_position = muzzle.global_position + direction * 0.6


func apply_damage(amount: float, _source: Node = null) -> void:
	if is_dead or invincible_remaining > 0.0:
		return
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


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(max_health, health + amount)
	health_changed.emit(health, max_health)


func _die() -> void:
	is_dead = true
	velocity = Vector3.ZERO
	visuals.visible = true
	if happy_student.visible:
		happy_student.play_animation(&"death", 0.08, 1.0, true)
	elif fashi.visible:
		fashi.play_animation(&"death", 0.08, 1.0, true)
	elif lulu.visible:
		lulu.play_animation(&"death", 0.08, 1.0, true)
	elif doumaoren.visible:
		doumaoren.play_animation(&"death", 0.08, 1.0, true)
	else:
		var death_tween := create_tween().set_parallel(true)
		death_tween.tween_property(visuals, "rotation_degrees:z", 88.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		death_tween.tween_property(visuals, "position:y", -0.65, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	name_label.visible = false
	collision_shape.set_deferred("disabled", true)
	died.emit(self)


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector3.ZERO
	health = max_health
	is_dead = false
	invincible_remaining = 3.0
	visuals.visible = true
	visuals.position = Vector3.ZERO
	visuals.rotation = Vector3.ZERO
	if happy_student.visible:
		happy_student.play_animation(&"standing", 0.0, 1.0, true)
	elif fashi.visible:
		fashi.play_animation(&"standing", 0.0, 1.0, true)
	elif lulu.visible:
		lulu.play_animation(&"standing", 0.0, 1.0, true)
	elif doumaoren.visible:
		doumaoren.play_animation(&"standing", 0.0, 1.0, true)
	name_label.visible = true
	collision_shape.set_deferred("disabled", false)
	health_changed.emit(health, max_health)


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
	else:
		visuals.rotation.x = lerp_angle(visuals.rotation.x, 0.0, 10.0 * delta)
		visuals.rotation.z = lerp_angle(visuals.rotation.z, 0.0, 10.0 * delta)


func _apply_appearance() -> void:
	var colors := {
		"头疼的符文大师": Color(0.08, 0.9, 0.65, 1),
		"快乐的本科生": Color(1.0, 0.58, 0.1, 1),
		"神秘兜帽人": Color(0.48, 0.16, 0.9, 1),
		"潇洒的男子 Lulu": Color(0.05, 0.58, 1.0, 1),
	}
	var material := StandardMaterial3D.new()
	material.albedo_color = colors.get(character_name, Color(0.5, 0.7, 1, 1))
	material.metallic = 0.15
	material.roughness = 0.42
	$Visuals/Body.material_override = material
	$Visuals/Head.material_override = material
	var is_happy_student := character_name == "快乐的本科生"
	var is_fashi := character_name == "头疼的符文大师"
	var is_lulu := character_name == "潇洒的男子 Lulu"
	var is_doumaoren := character_name == "神秘兜帽人"
	$Visuals/Body.visible = not is_happy_student and not is_fashi and not is_lulu and not is_doumaoren
	$Visuals/Head.visible = not is_happy_student and not is_fashi and not is_lulu and not is_doumaoren
	$Visuals/Gun.visible = not is_happy_student and not is_fashi and not is_lulu and not is_doumaoren
	happy_student.visible = is_happy_student
	fashi.visible = is_fashi
	lulu.visible = is_lulu
	doumaoren.visible = is_doumaoren
	if is_happy_student:
		happy_student.play_animation(&"standing")
	elif is_fashi:
		fashi.play_animation(&"standing")
	elif is_lulu:
		lulu.play_animation(&"standing")
	elif is_doumaoren:
		doumaoren.play_animation(&"standing")


func _update_character_animation() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if happy_student.visible:
		happy_student.play_animation(&"walk_rifle" if horizontal_speed > 0.35 else &"standing", 0.14, clampf(horizontal_speed / maxf(move_speed, 0.01), 0.75, 2.0))
	elif fashi.visible:
		fashi.play_animation(&"walk_rifle" if horizontal_speed > 0.35 else &"standing", 0.14, clampf(horizontal_speed / maxf(move_speed, 0.01), 0.75, 2.0))
	elif lulu.visible:
		lulu.play_animation(&"walk_rifle" if horizontal_speed > 0.35 else &"standing", 0.14, clampf(horizontal_speed / maxf(move_speed, 0.01), 0.75, 2.0))
	elif doumaoren.visible:
		doumaoren.play_animation(&"walk_rifle" if horizontal_speed > 0.35 else &"standing", 0.14, clampf(horizontal_speed / maxf(move_speed, 0.01), 0.75, 2.0))
