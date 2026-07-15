extends Node3D

const AI_TEAMMATE_SCENE := preload("res://actors/ai_teammate/ai_teammate.tscn")
const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师", "快乐的本科生", "神秘兜帽人", "潇洒的男子 Lulu",
]

@onready var player: ThirdPersonPlayer = $Player
@onready var boss: ChaseBoss = $Boss
@onready var boss_bar: ProgressBar = $HUD/BossBar
@onready var status_label: Label = $HUD/Status
@onready var timer_label: Label = $HUD/Timer
@onready var crosshair: Label = $HUD/Crosshair
@onready var player_health: ProgressBar = $HUD/PlayerHealth
@onready var player_health_label: Label = $HUD/PlayerHealthLabel
@onready var active_item_label: Label = $HUD/ActiveItem
@onready var stamina_bar: ProgressBar = $HUD/Stamina
@onready var stamina_label: Label = $HUD/StaminaLabel
@onready var hammer_charge_label: Label = $HUD/HammerCharge
@onready var ammo_label: Label = $HUD/Ammo
@onready var rune_manager: RuneManager = $RuneManager
@onready var rune_status_label: Label = $HUD/RuneStatus
@onready var character_status_label: Label = $HUD/CharacterStatus
@onready var spectator_camera: Camera3D = $SpectatorCamera
@onready var death_ui: CanvasLayer = $DeathUI
@onready var death_status: Label = $DeathUI/Shade/Status

var scoreboard_panel: Panel
var scoreboard_rows: Dictionary = {}
var result_ui: CanvasLayer
var result_label: Label
var crown: Node3D
var crown_material: StandardMaterial3D
var score_by_id: Dictionary = {}
var actor_by_id: Dictionary = {}
var name_by_id: Dictionary = {}
var first_reached_by_id: Dictionary = {}
var score_sequence := 0
var current_leader_id := 0
var scoreboard_visible := true
var match_time := 300.0
var match_finished := false
var victory_sequence_active := false
var ai_teammates: Array[AITeammate] = []
var player_respawn_time := -1.0
var spectator_target: Node3D
var spectator_target_index := 0


func _ready() -> void:
	AudioManager.play_combat_music()
	death_ui.visible = false
	player_respawn_time = -1.0
	_create_arena_geometry()
	var ui_manager := get_node_or_null("/root/UIManager")
	var configured_party_size := clampi(int(ui_manager.party_size), 1, 4) if ui_manager != null else 1
	var configured_difficulty := clampi(int(ui_manager.selected_difficulty), 0, 2) if ui_manager != null else 1
	boss.configure_for_match(configured_party_size, configured_difficulty)
	boss_bar.max_value = boss.max_health
	boss_bar.value = boss.health
	boss.health_changed.connect(_on_boss_health_changed)
	boss.died.connect(_on_boss_died)
	boss.damaged.connect(_on_boss_damaged)
	player.died.connect(_on_party_member_died)
	player.health_changed.connect(_on_player_health_changed)
	player.aim_changed.connect(_on_player_aim_changed)
	player.active_item_changed.connect(_on_active_item_changed)
	player.stamina_changed.connect(_on_player_stamina_changed)
	player.ammo_changed.connect(_on_player_ammo_changed)
	crosshair.visible = false
	player_health.max_value = player.max_health
	player_health.value = player.health
	stamina_bar.max_value = player.max_stamina
	stamina_bar.value = player.stamina
	_on_player_stamina_changed(player.stamina, player.max_stamina, false)
	_on_player_ammo_changed(player.ammo, player.reserve_ammo)
	_on_active_item_changed(player.get_active_item_name())
	character_status_label.text = "CHARACTER: %s" % player.get_character_name()
	_spawn_ai_party()
	_create_scoreboard_ui()
	_create_result_ui()
	_create_crown()
	_register_score_actor(player, player.get_character_name())
	for teammate in ai_teammates:
		_register_score_actor(teammate, "%s [AI]" % teammate.character_name)
	_update_scoreboard(true)
	death_ui.visible = false


func _process(delta: float) -> void:
	if not match_finished:
		match_time = maxf(0.0, match_time - delta)
		if match_time <= 0.0:
			_finish_defeat("TIME UP - DEFEAT")
	if is_instance_valid(boss) and not match_finished:
		status_label.text = "追猎者：%s | HP %.0f / %.0f" % [boss.get_state_name(), boss.health, boss.max_health]
	var minutes := int(match_time) / 60
	var seconds := int(match_time) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]
	_update_respawn_and_spectator(delta)
	var hammer_charge := player.get_hammer_charge_remaining()
	hammer_charge_label.visible = hammer_charge >= 0.0
	if hammer_charge >= 0.0:
		hammer_charge_label.text = "HAMMER CHARGE  %.1f" % hammer_charge
	if player.reload_remaining >= 0.0:
		ammo_label.text = "RELOADING  %.1f" % player.reload_remaining
	if victory_sequence_active:
		_update_mvp_camera(delta)
	var buff_text := player.get_buff_status_text()
	rune_status_label.text = "RUNES: %d ACTIVE  |  NEXT %02ds%s" % [
		rune_manager.get_active_rune_count(),
		ceili(rune_manager.time_to_next_round),
		"  |  " + buff_text if not buff_text.is_empty() else "",
	]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_scoreboard"):
		scoreboard_visible = not scoreboard_visible
		if scoreboard_panel != null:
			scoreboard_panel.visible = scoreboard_visible
		get_viewport().set_input_as_handled()
		return
	if not player.is_dead or match_finished:
		return
	if event.is_action_pressed("spectate_previous") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP):
		_cycle_spectator(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("spectate_next") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN):
		_cycle_spectator(1)
		get_viewport().set_input_as_handled()


func _on_boss_health_changed(current: float, maximum: float) -> void:
	boss_bar.max_value = maximum
	boss_bar.value = current


func _on_boss_damaged(amount: float, source: Node) -> void:
	_add_score(source, amount)


func _on_boss_died() -> void:
	match_finished = true
	status_label.text = "追猎者已击败 - 胜利"
	boss_bar.value = 0.0
	AudioManager.play_victory_music()
	_start_victory_sequence()


func _create_scoreboard_ui() -> void:
	scoreboard_panel = Panel.new()
	scoreboard_panel.name = "Scoreboard"
	scoreboard_panel.offset_left = 24.0
	scoreboard_panel.offset_top = 214.0
	scoreboard_panel.offset_right = 304.0
	scoreboard_panel.offset_bottom = 390.0
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.02, 0.045, 0.075, 0.72)
	panel_style.border_color = Color(0.1, 0.55, 1.0, 0.8)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	scoreboard_panel.add_theme_stylebox_override("panel", panel_style)
	$HUD.add_child(scoreboard_panel)

	var title := Label.new()
	title.offset_left = 14.0
	title.offset_top = 10.0
	title.offset_right = 250.0
	title.offset_bottom = 34.0
	title.text = "SCORE RANKING   [TAB]"
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.28, 1.0))
	title.add_theme_font_size_override("font_size", 16)
	scoreboard_panel.add_child(title)


func _create_result_ui() -> void:
	result_ui = CanvasLayer.new()
	result_ui.name = "ResultUI"
	result_ui.visible = false
	add_child(result_ui)

	var shade := ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.68)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	result_ui.add_child(shade)

	result_label = Label.new()
	result_label.set_anchors_preset(Control.PRESET_CENTER)
	result_label.offset_left = -260.0
	result_label.offset_top = -150.0
	result_label.offset_right = 260.0
	result_label.offset_bottom = 190.0
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result_label.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
	result_label.add_theme_font_size_override("font_size", 24)
	shade.add_child(result_label)


func _create_crown() -> void:
	crown = Node3D.new()
	crown.name = "LeaderCrown"
	crown.visible = false
	crown_material = StandardMaterial3D.new()
	crown_material.albedo_color = Color(1.0, 0.76, 0.08, 1.0)
	crown_material.emission_enabled = true
	crown_material.emission = Color(1.0, 0.55, 0.05, 1.0)
	crown_material.emission_energy_multiplier = 1.8

	var band_mesh := CylinderMesh.new()
	band_mesh.top_radius = 0.34
	band_mesh.bottom_radius = 0.34
	band_mesh.height = 0.1
	var band := MeshInstance3D.new()
	band.mesh = band_mesh
	band.material_override = crown_material
	crown.add_child(band)

	for index in range(5):
		var point_mesh := CylinderMesh.new()
		point_mesh.top_radius = 0.0
		point_mesh.bottom_radius = 0.075
		point_mesh.height = 0.26
		var point := MeshInstance3D.new()
		point.mesh = point_mesh
		point.material_override = crown_material
		var angle := TAU * float(index) / 5.0
		point.position = Vector3(cos(angle) * 0.26, 0.16, sin(angle) * 0.26)
		crown.add_child(point)

	add_child(crown)


func _register_score_actor(actor: Node, display_name: String) -> void:
	if actor == null:
		return
	var actor_id := actor.get_instance_id()
	actor_by_id[actor_id] = actor
	name_by_id[actor_id] = display_name
	score_by_id[actor_id] = 0.0
	first_reached_by_id[actor_id] = score_sequence


func _add_score(source: Node, amount: float) -> void:
	if source == null:
		return
	var actor_id := source.get_instance_id()
	if not score_by_id.has(actor_id):
		return
	score_by_id[actor_id] = float(score_by_id[actor_id]) + amount
	score_sequence += 1
	first_reached_by_id[actor_id] = score_sequence
	_update_scoreboard()


func _get_sorted_score_ids() -> Array[int]:
	var ids: Array[int] = []
	for key in score_by_id.keys():
		ids.append(int(key))
	ids.sort_custom(func(a: int, b: int) -> bool:
		var score_a := float(score_by_id[a])
		var score_b := float(score_by_id[b])
		if not is_equal_approx(score_a, score_b):
			return score_a > score_b
		return int(first_reached_by_id[a]) < int(first_reached_by_id[b])
	)
	return ids


func _update_scoreboard(instant := false) -> void:
	var sorted_ids := _get_sorted_score_ids()
	for rank in sorted_ids.size():
		var actor_id := sorted_ids[rank]
		var row := _get_or_create_score_row(actor_id)
		row.text = "%d  %s    %03d" % [rank + 1, String(name_by_id[actor_id]), roundi(float(score_by_id[actor_id]))]
		row.add_theme_color_override("font_color", Color(1.0, 0.86, 0.28, 1.0) if rank == 0 else Color(0.78, 0.88, 1.0, 1.0))
		var target_position := Vector2(14.0, 42.0 + rank * 30.0)
		if instant:
			row.position = target_position
		else:
			var tween := create_tween()
			tween.tween_property(row, "position", target_position, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if not sorted_ids.is_empty():
		_set_leader(sorted_ids[0])


func _get_or_create_score_row(actor_id: int) -> Label:
	if scoreboard_rows.has(actor_id):
		return scoreboard_rows[actor_id]
	var row := Label.new()
	row.offset_left = 14.0
	row.offset_top = 42.0
	row.offset_right = 260.0
	row.offset_bottom = 68.0
	row.add_theme_font_size_override("font_size", 16)
	scoreboard_panel.add_child(row)
	scoreboard_rows[actor_id] = row
	return row


func _set_leader(actor_id: int) -> void:
	if current_leader_id == actor_id:
		return
	current_leader_id = actor_id
	var leader := actor_by_id.get(actor_id) as Node3D
	if leader == null or not is_instance_valid(leader):
		crown.visible = false
		return
	if crown.get_parent() != null:
		crown.get_parent().remove_child(crown)
	leader.add_child(crown)
	crown.position = Vector3(0, _get_crown_height(leader), 0)
	crown.rotation = Vector3.ZERO
	crown.visible = true


func _get_crown_height(actor: Node3D) -> float:
	if actor is ChaseBoss:
		return 3.2
	if actor is AITeammate:
		return 1.82
	return 1.9


func _start_victory_sequence() -> void:
	_update_scoreboard(true)
	_make_crown_victory_glow()
	victory_sequence_active = true
	player.set_camera_active(false)
	spectator_camera.current = true
	get_tree().create_timer(3.0).timeout.connect(_show_victory_result)


func _make_crown_victory_glow() -> void:
	if crown_material == null:
		return
	crown_material.emission_energy_multiplier = 7.5
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.85
	glow_mesh.height = 1.7
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(1.0, 0.86, 0.18, 0.26)
	glow_material.emission_enabled = true
	glow_material.emission = Color(1.0, 0.65, 0.05, 1.0)
	glow_material.emission_energy_multiplier = 5.0
	var glow := MeshInstance3D.new()
	glow.name = "VictoryCrownGlow"
	glow.mesh = glow_mesh
	glow.material_override = glow_material
	crown.add_child(glow)


func _update_mvp_camera(delta: float) -> void:
	var leader := actor_by_id.get(current_leader_id) as Node3D
	if leader == null or not is_instance_valid(leader):
		return
	var focus := leader.global_position + Vector3.UP * 1.1
	var desired_position := leader.global_position + Vector3(0.0, 2.7, 5.2)
	spectator_camera.global_position = spectator_camera.global_position.lerp(desired_position, 4.5 * delta)
	spectator_camera.look_at(focus)


func _show_victory_result() -> void:
	victory_sequence_active = false
	result_ui.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sorted_ids := _get_sorted_score_ids()
	var lines: Array[String] = ["追猎者已击败", "", "MVP: %s" % _leader_name(), "", "FINAL SCORE"]
	for rank in sorted_ids.size():
		var actor_id := sorted_ids[rank]
		lines.append("%d. %s  %d" % [rank + 1, String(name_by_id[actor_id]), roundi(float(score_by_id[actor_id]))])
	result_label.text = "\n".join(lines)


func _leader_name() -> String:
	if name_by_id.has(current_leader_id):
		return String(name_by_id[current_leader_id])
	return "NO SCORE"


func _finish_defeat(reason: String) -> void:
	if match_finished:
		return
	match_finished = true
	victory_sequence_active = false
	status_label.text = reason
	AudioManager.play_defeat_music()
	result_ui.visible = true
	death_ui.visible = false
	player.set_camera_active(false)
	spectator_camera.current = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var sorted_ids := _get_sorted_score_ids()
	var lines: Array[String] = [reason, "", "MISSION FAILED", "", "FINAL SCORE"]
	for rank in sorted_ids.size():
		var actor_id := sorted_ids[rank]
		lines.append("%d. %s  %d" % [rank + 1, String(name_by_id[actor_id]), roundi(float(score_by_id[actor_id]))])
	result_label.text = "\n".join(lines)


func _spawn_ai_party() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	var requested_party_size := clampi(int(ui_manager.party_size), 1, 4) if ui_manager != null else 1
	var selected_character := player.get_character_name()
	var available_characters := CHARACTER_NAMES.duplicate()
	available_characters.erase(selected_character)
	for index in requested_party_size - 1:
		var teammate: AITeammate = AI_TEAMMATE_SCENE.instantiate()
		var spawn_offset := Vector3((index + 1) * 2.0, 1.0, 10.0 + float(index % 2) * 2.0)
		teammate.setup(available_characters[index], spawn_offset)
		add_child(teammate)
		teammate.died.connect(_on_party_member_died)
		ai_teammates.append(teammate)


func _on_party_member_died(_member: Node3D) -> void:
	if match_finished:
		return
	if _all_party_members_dead():
		_finish_defeat("ALL TEAM MEMBERS DOWN - DEFEAT")
		return
		match_finished = true
		status_label.text = "ALL TEAM MEMBERS DOWN - DEFEAT"
		AudioManager.play_defeat_music()
		death_ui.visible = true
		death_status.text = "全队阵亡\n任务失败"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		return
	if player.is_dead:
		player_respawn_time = 15.0
		player.set_camera_active(false)
		spectator_target_index = 0
		spectator_target = _get_living_spectator_targets().front()
		spectator_camera.current = true
		death_ui.visible = true
	for teammate in ai_teammates:
		if teammate.is_dead:
			_schedule_ai_respawn(teammate)


func _schedule_ai_respawn(teammate: AITeammate) -> void:
	if teammate.has_meta("respawn_scheduled"):
		return
	teammate.set_meta("respawn_scheduled", true)
	get_tree().create_timer(15.0).timeout.connect(_respawn_ai.bind(teammate))


func _respawn_ai(teammate: AITeammate) -> void:
	if match_finished or not is_instance_valid(teammate):
		return
	teammate.remove_meta("respawn_scheduled")
	teammate.respawn()


func _update_respawn_and_spectator(delta: float) -> void:
	if player_respawn_time < 0.0 or match_finished:
		return
	player_respawn_time = maxf(0.0, player_respawn_time - delta)
	death_status.text = "观战中：%s\n%.1f秒后复活\nQ/E、滚轮或手柄肩键切换" % [_spectator_name(), player_respawn_time]
	if is_instance_valid(spectator_target) and spectator_target.has_method("is_alive") and spectator_target.is_alive():
		var desired_position := spectator_target.global_position + Vector3(0, 3.2, 6.2)
		spectator_camera.global_position = spectator_camera.global_position.lerp(desired_position, 5.0 * delta)
		spectator_camera.look_at(spectator_target.global_position + Vector3.UP * 0.7)
	else:
		spectator_target = _find_living_teammate()
	if player_respawn_time <= 0.0:
		player_respawn_time = -1.0
		death_ui.visible = false
		spectator_camera.current = false
		player.respawn()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _find_living_teammate() -> Node3D:
	for teammate in ai_teammates:
		if teammate.is_alive():
			return teammate
	return null


func _get_living_spectator_targets() -> Array[Node3D]:
	var targets: Array[Node3D] = []
	for member in get_tree().get_nodes_in_group("players"):
		if member == player or not member is Node3D:
			continue
		if member.has_method("is_alive") and member.is_alive():
			targets.append(member)
	return targets


func _cycle_spectator(direction: int) -> void:
	var targets := _get_living_spectator_targets()
	if targets.is_empty():
		return
	spectator_target_index = wrapi(spectator_target_index + direction, 0, targets.size())
	spectator_target = targets[spectator_target_index]


func _spectator_name() -> String:
	if spectator_target is AITeammate:
		return spectator_target.character_name
	return "队友"


func _all_party_members_dead() -> bool:
	if player.is_alive():
		return false
	for teammate in ai_teammates:
		if teammate.is_alive():
			return false
	return true


func _on_player_health_changed(current: float, maximum: float) -> void:
	player_health.max_value = maximum
	player_health.value = current
	player_health_label.text = "HP  %.0f / %.0f" % [current, maximum]


func _on_player_aim_changed(is_aiming: bool) -> void:
	crosshair.visible = is_aiming


func _on_active_item_changed(item_name: String) -> void:
	active_item_label.text = "ACTIVE: %s" % item_name.to_upper()


func _on_player_stamina_changed(current: float, maximum: float, exhausted: bool) -> void:
	stamina_bar.max_value = maximum
	stamina_bar.value = current
	stamina_label.text = "STAMINA  %.0f / %.0f%s" % [current, maximum, "  RECOVERING" if exhausted else ""]


func _on_player_ammo_changed(current: int, maximum: int) -> void:
	ammo_label.text = "AMMO  %03d / %03d" % [current, maximum]


func _create_arena_geometry() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.selected_map == "峡谷回廊":
		_create_canyon_geometry()
		return
	# Split the 240 x 240 ground into slabs so the southern central basin is a
	# real negative level instead of scenery placed on top of one solid floor.
	_create_static_box("NorthGround", Vector3(240.0, 1.0, 145.0), Vector3(0.0, -0.5, -47.5), Color(0.10, 0.14, 0.18))
	_create_static_box("SouthGround", Vector3(240.0, 1.0, 40.0), Vector3(0.0, -0.5, 100.0), Color(0.10, 0.14, 0.18))
	_create_static_box("WestGround", Vector3(85.0, 1.0, 55.0), Vector3(-77.5, -0.5, 52.5), Color(0.10, 0.14, 0.18))
	_create_static_box("EastGround", Vector3(85.0, 1.0, 55.0), Vector3(77.5, -0.5, 52.5), Color(0.10, 0.14, 0.18))

	# B1 basin: eight metres below ground, with two separated traversal ramps.
	_create_static_box("B1Floor", Vector3(70.0, 1.0, 55.0), Vector3(0.0, -8.5, 52.5), Color(0.055, 0.085, 0.12))
	_create_static_box("B1WestWall", Vector3(1.0, 8.0, 55.0), Vector3(-35.0, -4.0, 52.5), Color(0.16, 0.21, 0.27))
	_create_static_box("B1EastWall", Vector3(1.0, 8.0, 55.0), Vector3(35.0, -4.0, 52.5), Color(0.16, 0.21, 0.27))
	_create_static_box("B1NorthWallLeft", Vector3(8.0, 8.0, 1.0), Vector3(-31.0, -4.0, 25.0), Color(0.16, 0.21, 0.27))
	_create_static_box("B1NorthWallRight", Vector3(44.0, 8.0, 1.0), Vector3(13.0, -4.0, 25.0), Color(0.16, 0.21, 0.27))
	_create_static_box("B1SouthWallLeft", Vector3(44.0, 8.0, 1.0), Vector3(-13.0, -4.0, 80.0), Color(0.16, 0.21, 0.27))
	_create_static_box("B1SouthWallRight", Vector3(8.0, 8.0, 1.0), Vector3(31.0, -4.0, 80.0), Color(0.16, 0.21, 0.27))
	_create_static_box("B1NorthRamp", Vector3(18.0, 1.0, 40.0), Vector3(-18.0, -4.0, 43.0), Color(0.2, 0.29, 0.34), Vector3(12.0, 0, 0))
	_create_static_box("B1SouthRamp", Vector3(18.0, 1.0, 40.0), Vector3(18.0, -4.0, 62.0), Color(0.2, 0.29, 0.34), Vector3(-12.0, 0, 0))
	_create_static_box("NorthWall", Vector3(240.0, 5.0, 1.0), Vector3(0.0, 2.5, -120.0), Color(0.2, 0.24, 0.3))
	_create_static_box("SouthWall", Vector3(240.0, 5.0, 1.0), Vector3(0.0, 2.5, 120.0), Color(0.2, 0.24, 0.3))
	_create_static_box("WestWall", Vector3(1.0, 5.0, 240.0), Vector3(-120.0, 2.5, 0.0), Color(0.2, 0.24, 0.3))
	_create_static_box("EastWall", Vector3(1.0, 5.0, 240.0), Vector3(120.0, 2.5, 0.0), Color(0.2, 0.24, 0.3))

	# Western plateau and two approach slopes.
	_create_static_box("WestPlateau", Vector3(54.0, 1.0, 62.0), Vector3(-72.0, 6.0, 5.0), Color(0.19, 0.25, 0.29))
	_create_static_box("WestSlopeSouth", Vector3(34.0, 1.2, 18.0), Vector3(-39.5, 3.0, 20.0), Color(0.24, 0.31, 0.34), Vector3(0, 0, -10.5))
	_create_static_box("WestSlopeNorth", Vector3(34.0, 1.2, 18.0), Vector3(-39.5, 3.0, -12.0), Color(0.24, 0.31, 0.34), Vector3(0, 0, -10.5))

	# Eastern ridge reached from opposite-facing uphill/downhill ramps.
	_create_static_box("EastRidge", Vector3(48.0, 1.0, 46.0), Vector3(68.0, 9.0, -42.0), Color(0.22, 0.24, 0.31))
	_create_static_box("EastSlopeFront", Vector3(20.0, 1.2, 52.0), Vector3(68.0, 4.5, -5.0), Color(0.30, 0.28, 0.34), Vector3(-10.0, 0, 0))
	_create_static_box("EastSlopeSide", Vector3(48.0, 1.2, 20.0), Vector3(32.0, 4.5, -42.0), Color(0.30, 0.28, 0.34), Vector3(0, 0, 10.0))

	# Central rolling route: successive shallow ramps make a broad rise and descent.
	_create_static_box("CenterRiseA", Vector3(26.0, 1.0, 38.0), Vector3(-8.0, 1.6, -48.0), Color(0.18, 0.27, 0.25), Vector3(5.0, 0, 0))
	_create_static_box("CenterRiseB", Vector3(26.0, 1.0, 38.0), Vector3(-8.0, 1.6, -82.0), Color(0.18, 0.27, 0.25), Vector3(-5.0, 0, 0))

	for position in [
		Vector3(-18, 1.5, -12), Vector3(18, 2.0, 18), Vector3(-48, 8.0, 6),
		Vector3(72, 11.0, -45), Vector3(42, 1.5, 55), Vector3(-70, 2.0, 72),
		Vector3(84, 2.5, 74), Vector3(-90, 1.5, -72)
	]:
		_create_static_box("Cover", Vector3(5.0, 3.0, 5.0), position, Color(0.29, 0.34, 0.4))


func _create_canyon_geometry() -> void:
	_create_static_box("CanyonFloor", Vector3(180.0, 1.0, 240.0), Vector3(0, -4.5, 0), Color(0.18, 0.11, 0.075))
	_create_static_box("WestCliff", Vector3(52.0, 13.0, 240.0), Vector3(-66, 2.0, 0), Color(0.34, 0.19, 0.10))
	_create_static_box("EastCliff", Vector3(52.0, 19.0, 240.0), Vector3(66, 5.0, 0), Color(0.40, 0.23, 0.12))
	_create_static_box("WestRamp", Vector3(42.0, 1.2, 66.0), Vector3(-31, -1.0, -52), Color(0.45, 0.28, 0.16), Vector3(0, 0, -10))
	_create_static_box("EastRamp", Vector3(42.0, 1.2, 66.0), Vector3(31, 0.5, 54), Color(0.45, 0.28, 0.16), Vector3(0, 0, 13))
	_create_static_box("NorthWall", Vector3(180.0, 8.0, 1.0), Vector3(0, 0, -120), Color(0.28, 0.15, 0.09))
	_create_static_box("SouthWall", Vector3(180.0, 8.0, 1.0), Vector3(0, 0, 120), Color(0.28, 0.15, 0.09))
	_create_static_box("WestWall", Vector3(1.0, 8.0, 240.0), Vector3(-90, 0, 0), Color(0.28, 0.15, 0.09))
	_create_static_box("EastWall", Vector3(1.0, 8.0, 240.0), Vector3(90, 0, 0), Color(0.28, 0.15, 0.09))
	for position in [Vector3(-18, -2, -78), Vector3(20, -1, -28), Vector3(-12, 0, 24), Vector3(24, 1, 82)]:
		_create_static_box("CanyonPillar", Vector3(10, 8, 10), position, Color(0.38, 0.21, 0.12))


func _create_static_box(node_name: String, size: Vector3, position: Vector3, color: Color, box_rotation := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = position
	body.rotation_degrees = box_rotation
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	body.add_child(mesh_instance)
	add_child(body)
