extends Node3D

enum Stage { BOSS, MAP, CHARACTER, POSE }

const BOSS_NAMES: Array[String] = ["追猎者"]
const MAP_NAMES: Array[String] = ["高地试验场", "峡谷回廊"]
const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师",
	"快乐的本科生",
	"神秘兜帽人",
	"潇洒的男子 Lulu",
]
const CHARACTER_LINES: Array[String] = [
	"符文在呼唤我——希望它也能治头痛。",
	"锤子带了吗？那就出发！",
	"再收集一点，我就能解开秘密。",
	"跟得上我的速度吗？",
]
const CHARACTER_COLORS: Array[Color] = [
	Color(0.08, 0.9, 0.65, 1),
	Color(1.0, 0.58, 0.1, 1),
	Color(0.48, 0.16, 0.9, 1),
	Color(0.05, 0.58, 1.0, 1),
]
const HAPPY_STUDENT_SCENE := preload("res://assets/characters/happy_student/happy_student_model.tscn")
const FASHI_SCENE := preload("res://assets/characters/fashi/fashi_model.tscn")
const LULU_SCENE := preload("res://assets/characters/lulu/lulu_model.tscn")
const DOUMAOREN_SCENE := preload("res://assets/characters/doumaoren/doumaoren_model.tscn")
const BOSS_LOBBY_SHOWCASE_SCENE := preload("res://assets/boss/boss_lobby_showcase.tscn")
const BOSS_SELECTION_CARD_SCENE := preload("res://menus/boss_selection_card.tscn")

@onready var boss_showcase: Node3D = $BossShowcase
@onready var map_showcase: Node3D = $MapShowcase
@onready var character_showcase: Node3D = $CharacterShowcase
@onready var showcase_camera: Camera3D = $Camera3D
@onready var stage_label: Label = $UI/StageLabel
@onready var title_label: Label = $UI/Title
@onready var instruction_label: Label = $UI/Instruction
@onready var cards: HBoxContainer = $UI/CardContainer
@onready var boss_card_title: Label = $UI/BossCardTitle
@onready var map_previous_button: Button = $UI/MapPrevious
@onready var map_next_button: Button = $UI/MapNext
@onready var preview_frame: Panel = $UI/MapPreview
@onready var video_player: VideoStreamPlayer = $UI/MapPreview/VideoStreamPlayer
@onready var video_placeholder: ColorRect = $UI/MapPreview/VideoPlaceholder
@onready var dialogue_label: Label = $UI/Dialogue
@onready var next_button: Button = $UI/Next
@onready var back_button: Button = $UI/Back
@onready var party_size_label: Label = $UI/PartySizeLabel
@onready var party_size_option: OptionButton = $UI/PartySize
@onready var difficulty_label: Label = $UI/DifficultyLabel
@onready var difficulty_option: OptionButton = $UI/Difficulty

var stage := Stage.BOSS
var selected_boss := 0
var selected_map := 0
var selected_character := 0
var _card_buttons: Array[Button] = []
var _character_models: Array[Node3D] = []
var _character_spotlights: Array[SpotLight3D] = []
var _character_start_positions: Array[Vector3] = []
var _preview_tween: Tween
const PREVIEW_SMALL := Rect2(-404.0, 100.0, 364.0, 205.0)
const PREVIEW_LARGE := Rect2(-824.0, 148.0, 784.0, 441.0)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_create_boss_showcase()
	_create_map_showcase()
	_create_character_showcase()
	for size in range(1, 5):
		party_size_option.add_item("%d人挑战" % size, size)
	party_size_option.select(0)
	for difficulty_name in ["简单", "普通", "困难"]:
		difficulty_option.add_item(difficulty_name)
	difficulty_option.select(1)
	get_viewport().size_changed.connect(_on_viewport_size_changed)
	next_button.pressed.connect(_on_next_pressed)
	back_button.pressed.connect(_on_back_pressed)
	map_previous_button.pressed.connect(_change_map.bind(-1))
	map_next_button.pressed.connect(_change_map.bind(1))
	preview_frame.mouse_entered.connect(_on_preview_hovered.bind(true))
	preview_frame.mouse_exited.connect(_on_preview_hovered.bind(false))
	_show_stage(Stage.BOSS)


func _process(delta: float) -> void:
	map_showcase.rotation.y += delta * 0.16
	if video_player.stream == null:
		video_placeholder.color = Color(0.025, 0.09 + sin(Time.get_ticks_msec() * 0.0015) * 0.018, 0.15, 0.9)
	if stage == Stage.POSE and selected_character < _character_models.size():
		var actor := _character_models[selected_character]
		if selected_character in [0, 1, 2, 3]:
			return
		var time := Time.get_ticks_msec() * 0.001
		actor.position.y = sin(time * 3.2) * 0.08
		actor.rotation.y = sin(time * 1.9) * 0.24
		var head := actor.get_node("HeadPivot") as Node3D
		head.rotation.z = sin(time * 2.7) * 0.12


func _unhandled_input(event: InputEvent) -> void:
	if stage == Stage.MAP and event.is_action_pressed("ui_left"):
		_change_map(-1)
		get_viewport().set_input_as_handled()
		return
	if stage == Stage.MAP and event.is_action_pressed("ui_right"):
		_change_map(1)
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _show_stage(next_stage: Stage) -> void:
	stage = next_stage
	if video_player.is_playing():
		video_player.stop()
	_restore_character_showcase()
	dialogue_label.visible = false
	preview_frame.visible = false
	party_size_label.visible = false
	party_size_option.visible = false
	difficulty_label.visible = false
	difficulty_option.visible = false
	map_previous_button.visible = false
	map_next_button.visible = false
	boss_card_title.visible = false
	cards.offset_left = 140.0
	cards.offset_right = -140.0
	boss_showcase.visible = false
	map_showcase.visible = false
	character_showcase.visible = false
	match stage:
		Stage.BOSS:
			stage_label.text = "STEP 1 / 3"
			title_label.text = "选择 Boss"
			instruction_label.text = "确认本次追击目标"
			boss_showcase.visible = true
			boss_card_title.text = BOSS_NAMES[selected_boss]
			boss_card_title.visible = true
			party_size_label.visible = true
			party_size_option.visible = true
			difficulty_label.visible = true
			difficulty_option.visible = true
			_build_cards(BOSS_NAMES, selected_boss)
			next_button.text = "下一步  >"
		Stage.MAP:
			stage_label.text = "STEP 2 / 3"
			title_label.text = "选择地图"
			instruction_label.text = "预览战场并确认部署区域"
			map_showcase.visible = true
			preview_frame.visible = true
			_set_preview_rect(PREVIEW_SMALL)
			video_placeholder.visible = video_player.stream == null
			if video_player.stream != null:
				video_player.play()
			map_previous_button.visible = true
			map_next_button.visible = true
			cards.offset_left = 100.0
			cards.offset_right = -470.0
			_build_map_page()
			next_button.text = "下一步  >"
		Stage.CHARACTER:
			stage_label.text = "STEP 3 / 3"
			title_label.text = "选择角色"
			instruction_label.text = "将光标移到角色上查看聚光灯，确认后播放互动Pose"
			character_showcase.visible = true
			_build_cards(CHARACTER_NAMES, selected_character, true)
			next_button.text = "确认角色"
		Stage.POSE:
			stage_label.text = "DEPLOY READY"
			title_label.text = CHARACTER_NAMES[selected_character]
			instruction_label.text = "角色已回应，准备进入战斗"
			character_showcase.visible = true
			_show_selected_character_pose()
			_clear_cards()
			dialogue_label.visible = true
			dialogue_label.text = "“%s”" % CHARACTER_LINES[selected_character]
			next_button.text = "进入战斗  >"
	back_button.text = "返回"


func _build_cards(names: Array[String], selected_index: int, character_cards := false) -> void:
	_clear_cards()
	for index in names.size():
		var button: Button
		var card_item: Control
		if stage == Stage.BOSS and not character_cards:
			card_item = BOSS_SELECTION_CARD_SCENE.instantiate() as Control
			button = card_item.get_node("Button") as Button
		else:
			button = Button.new()
			card_item = button
			button.custom_minimum_size = Vector2(230, 285 if character_cards else 120)
			button.text = names[index]
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_BOTTOM
		button.add_theme_font_size_override("font_size", 18)
		button.add_theme_stylebox_override("normal", _make_card_style(Color(0.025, 0.06, 0.11, 0.22), Color(0.1, 0.38, 0.62, 0.7), 1))
		button.add_theme_stylebox_override("hover", _make_card_style(Color(0.04, 0.16, 0.27, 0.5), Color(0.2, 0.78, 1.0, 1), 3))
		button.add_theme_stylebox_override("pressed", _make_card_style(Color(0.08, 0.3, 0.42, 0.6), Color(1.0, 0.78, 0.24, 1), 4))
		button.pressed.connect(_on_card_selected.bind(index))
		if character_cards:
			button.mouse_entered.connect(_on_character_hovered.bind(index, true))
			button.mouse_exited.connect(_on_character_hovered.bind(index, false))
		cards.add_child(card_item)
		_card_buttons.append(button)
	_refresh_card_selection(selected_index)
	if character_cards:
		_align_character_models_to_cards.call_deferred()


func _build_map_page() -> void:
	_clear_cards()
	var map_label := Label.new()
	map_label.custom_minimum_size = Vector2(420, 90)
	map_label.text = "%s\n%d / %d" % [MAP_NAMES[selected_map], selected_map + 1, MAP_NAMES.size()]
	map_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42, 1.0))
	map_label.add_theme_font_size_override("font_size", 22)
	map_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	map_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_child(map_label)


func _change_map(direction: int) -> void:
	if stage != Stage.MAP or MAP_NAMES.is_empty():
		return
	selected_map = wrapi(selected_map + direction, 0, MAP_NAMES.size())
	_build_map_page()
	_update_map_showcase()
	if video_player.stream != null:
		video_player.stop()
		video_player.play()


func _update_map_showcase() -> void:
	for index in map_showcase.get_child_count():
		var block := map_showcase.get_child(index) as MeshInstance3D
		if block == null:
			continue
		if selected_map == 0:
			block.position.y = (block.mesh as BoxMesh).size.y * 0.5 - 0.5
			block.material_override = _make_material(Color(0.08, 0.45 + float(index % 3) * 0.09, 0.62, 1))
		else:
			block.position.y = float(index % 4) * 0.42 - 0.45
			block.material_override = _make_material(Color(0.48 + float(index % 3) * 0.07, 0.22, 0.09, 1))


func _clear_cards() -> void:
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	_card_buttons.clear()


func _on_card_selected(index: int) -> void:
	match stage:
		Stage.BOSS:
			selected_boss = index
			boss_card_title.text = BOSS_NAMES[selected_boss]
		Stage.MAP:
			selected_map = index
		Stage.CHARACTER:
			selected_character = index
	_refresh_card_selection(index)


func _refresh_card_selection(selected_index: int) -> void:
	for index in _card_buttons.size():
		var selected := index == selected_index
		var button := _card_buttons[index]
		if button.get_parent().name == "BossSelectionCard":
			button.modulate = Color.WHITE
			var card_background := Color(0.035, 0.12, 0.15, 0.34) if selected else Color(0.025, 0.06, 0.11, 0.22)
			var card_border := Color(0.12, 1.0, 0.58, 1.0) if selected else Color(0.1, 0.38, 0.62, 0.7)
			button.add_theme_stylebox_override("normal", _make_card_style(card_background, card_border, 3 if selected else 1))
		else:
			button.modulate = Color(1.0, 0.86, 0.45, 1.0) if selected else Color(0.68, 0.78, 0.88, 0.8)
		button.scale = Vector2(1.025, 1.025) if selected else Vector2.ONE


func _on_character_hovered(index: int, hovered: bool) -> void:
	if stage != Stage.CHARACTER or index >= _character_spotlights.size():
		return
	_character_spotlights[index].visible = hovered


func _on_preview_hovered(hovered: bool) -> void:
	if stage != Stage.MAP:
		return
	if _preview_tween != null:
		_preview_tween.kill()
	_preview_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var target := PREVIEW_LARGE if hovered else PREVIEW_SMALL
	_preview_tween.tween_property(preview_frame, "offset_left", target.position.x, 0.2)
	_preview_tween.tween_property(preview_frame, "offset_top", target.position.y, 0.2)
	_preview_tween.tween_property(preview_frame, "offset_right", target.end.x, 0.2)
	_preview_tween.tween_property(preview_frame, "offset_bottom", target.end.y, 0.2)
	preview_frame.move_to_front()


func _set_preview_rect(rect: Rect2) -> void:
	preview_frame.offset_left = rect.position.x
	preview_frame.offset_top = rect.position.y
	preview_frame.offset_right = rect.end.x
	preview_frame.offset_bottom = rect.end.y


func _align_character_models_to_cards() -> void:
	if stage != Stage.CHARACTER or _card_buttons.size() != _character_models.size():
		return
	for index in _card_buttons.size():
		var card_center := _card_buttons[index].get_global_rect().get_center()
		var ray_origin := showcase_camera.project_ray_origin(card_center)
		var ray_direction := showcase_camera.project_ray_normal(card_center)
		if absf(ray_direction.z) <= 0.0001:
			continue
		var distance_to_showcase_plane := (character_showcase.global_position.z - ray_origin.z) / ray_direction.z
		var world_position := ray_origin + ray_direction * distance_to_showcase_plane
		var local_position := character_showcase.to_local(world_position)
		_character_models[index].position.x = local_position.x
		_character_start_positions[index].x = local_position.x


func _on_viewport_size_changed() -> void:
	if stage == Stage.CHARACTER:
		_align_character_models_to_cards.call_deferred()


func _on_next_pressed() -> void:
	match stage:
		Stage.BOSS:
			_show_stage(Stage.MAP)
		Stage.MAP:
			_show_stage(Stage.CHARACTER)
		Stage.CHARACTER:
			_show_stage(Stage.POSE)
		Stage.POSE:
			var ui_manager := get_node_or_null("/root/UIManager")
			if ui_manager != null:
				ui_manager.start_game(BOSS_NAMES[selected_boss], MAP_NAMES[selected_map], CHARACTER_NAMES[selected_character], party_size_option.get_selected_id(), difficulty_option.selected)


func _on_back_pressed() -> void:
	match stage:
		Stage.BOSS:
			var ui_manager := get_node_or_null("/root/UIManager")
			if ui_manager != null:
				ui_manager.open_main_menu()
		Stage.MAP:
			_show_stage(Stage.BOSS)
		Stage.CHARACTER:
			_show_stage(Stage.MAP)
		Stage.POSE:
			_show_stage(Stage.CHARACTER)


func _create_boss_showcase() -> void:
	var boss_display := BOSS_LOBBY_SHOWCASE_SCENE.instantiate() as Node3D
	boss_display.name = "ChaserBossDisplay"
	boss_showcase.add_child(boss_display)


func _create_map_showcase() -> void:
	for index in 11:
		var block := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.4 + float(index % 3), 0.3 + float(index % 4) * 0.35, 1.4 + float((index + 1) % 3))
		block.mesh = mesh
		block.position = Vector3(float(index % 4) * 2.3 - 3.5, mesh.size.y * 0.5 - 0.5, float(index / 4) * 2.4 - 3.0)
		block.material_override = _make_material(Color(0.08, 0.45 + float(index % 3) * 0.09, 0.62, 1))
		map_showcase.add_child(block)
	map_showcase.position = Vector3(0, 0.4, -0.5)


func _create_character_showcase() -> void:
	var x_positions := [-4.35, -1.45, 1.45, 4.35]
	for index in CHARACTER_NAMES.size():
		var actor: Node3D
		if index == 0:
			actor = _create_fashi_actor(character_showcase, Vector3(x_positions[index], 0, 0), 0.82)
		elif index == 1:
			actor = _create_happy_student_actor(character_showcase, Vector3(x_positions[index], 0, 0), 0.82)
		elif index == 2:
			actor = _create_doumaoren_actor(character_showcase, Vector3(x_positions[index], 0, 0), 0.82)
		elif index == 3:
			actor = _create_lulu_actor(character_showcase, Vector3(x_positions[index], 0, 0), 0.82)
		else:
			actor = _create_actor(character_showcase, Vector3(x_positions[index], 0, 0), CHARACTER_COLORS[index], 0.82)
		actor.name = "Character%d" % (index + 1)
		_character_models.append(actor)
		_character_start_positions.append(actor.position)
		var spotlight := SpotLight3D.new()
		spotlight.position = Vector3(0, 6.0, 0)
		spotlight.rotation_degrees.x = -90.0
		spotlight.light_color = CHARACTER_COLORS[index].lightened(0.35)
		spotlight.light_energy = 9.0
		spotlight.spot_range = 10.0
		spotlight.spot_angle = 22.0
		spotlight.shadow_enabled = true
		spotlight.visible = false
		actor.add_child(spotlight)
		_character_spotlights.append(spotlight)


func _create_happy_student_actor(parent: Node3D, actor_position: Vector3, size_scale: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = actor_position
	actor.scale = Vector3.ONE * size_scale
	parent.add_child(actor)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	actor.add_child(head_pivot)
	var model := HAPPY_STUDENT_SCENE.instantiate() as HappyStudentModel
	model.name = "HappyStudentModel"
	model.scale = Vector3.ONE * 2.2
	model.show_weapon = false
	actor.add_child(model)
	return actor


func _create_fashi_actor(parent: Node3D, actor_position: Vector3, size_scale: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = actor_position
	actor.scale = Vector3.ONE * size_scale
	parent.add_child(actor)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	actor.add_child(head_pivot)
	var model := FASHI_SCENE.instantiate() as FashiModel
	model.name = "FashiModel"
	model.scale = Vector3.ONE * 2.2
	model.show_weapon = false
	actor.add_child(model)
	return actor


func _create_lulu_actor(parent: Node3D, actor_position: Vector3, size_scale: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = actor_position
	actor.scale = Vector3.ONE * size_scale
	parent.add_child(actor)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	actor.add_child(head_pivot)
	var model := LULU_SCENE.instantiate() as LuluModel
	model.name = "LuluModel"
	model.scale = Vector3.ONE * 2.2
	model.show_weapon = false
	actor.add_child(model)
	return actor


func _create_doumaoren_actor(parent: Node3D, actor_position: Vector3, size_scale: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = actor_position
	actor.scale = Vector3.ONE * size_scale
	parent.add_child(actor)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	actor.add_child(head_pivot)
	var model := DOUMAOREN_SCENE.instantiate() as DoumaorenModel
	model.name = "DoumaorenModel"
	model.scale = Vector3.ONE * 2.2
	model.show_weapon = false
	actor.add_child(model)
	return actor


func _create_actor(parent: Node3D, actor_position: Vector3, color: Color, size_scale: float) -> Node3D:
	var actor := Node3D.new()
	actor.position = actor_position
	actor.scale = Vector3.ONE * size_scale
	parent.add_child(actor)
	var material := _make_material(color)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.65
	body_mesh.height = 2.8
	body.mesh = body_mesh
	body.material_override = material
	body.position.y = 1.4
	body.name = "Body"
	actor.add_child(body)
	var head_pivot := Node3D.new()
	head_pivot.name = "HeadPivot"
	head_pivot.position.y = 3.25
	actor.add_child(head_pivot)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.58
	head_mesh.height = 1.16
	head.mesh = head_mesh
	head.material_override = material
	head.name = "Head"
	head_pivot.add_child(head)
	for eye_x in [-0.2, 0.2]:
		var eye := MeshInstance3D.new()
		var eye_mesh := SphereMesh.new()
		eye_mesh.radius = 0.075
		eye_mesh.height = 0.15
		eye.mesh = eye_mesh
		eye.material_override = _make_material(Color(0.015, 0.025, 0.04, 1))
		eye.position = Vector3(eye_x, 0.08, 0.53)
		head_pivot.add_child(eye)
	return actor


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.15
	material.roughness = 0.42
	material.emission_enabled = true
	material.emission = color.darkened(0.76)
	return material


func _make_card_style(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(10)
	return style


func _show_selected_character_pose() -> void:
	for index in _character_models.size():
		var selected := index == selected_character
		_character_models[index].visible = selected
		_character_spotlights[index].visible = selected
	if selected_character < _character_models.size():
		_character_models[selected_character].position = Vector3(0, 0, 0)
		if selected_character == 0:
			var fashi_model := _character_models[selected_character].get_node("FashiModel") as FashiModel
			fashi_model.play_animation(&"pointing")
		elif selected_character == 1:
			var model := _character_models[selected_character].get_node("HappyStudentModel") as HappyStudentModel
			model.play_animation(&"pointing")
		elif selected_character == 3:
			var lulu_model := _character_models[selected_character].get_node("LuluModel") as LuluModel
			lulu_model.play_animation(&"pointing")
		elif selected_character == 2:
			var doumaoren_model := _character_models[selected_character].get_node("DoumaorenModel") as DoumaorenModel
			doumaoren_model.play_animation(&"pointing")


func _restore_character_showcase() -> void:
	for index in _character_models.size():
		_character_models[index].visible = true
		_character_models[index].position = _character_start_positions[index]
		_character_models[index].rotation = Vector3.ZERO
		_character_models[index].get_node("HeadPivot").rotation = Vector3.ZERO
		_character_spotlights[index].visible = false
		if index == 0:
			var fashi_model := _character_models[index].get_node("FashiModel") as FashiModel
			fashi_model.play_animation(&"idle")
		elif index == 1:
			var model := _character_models[index].get_node("HappyStudentModel") as HappyStudentModel
			model.play_animation(&"idle")
		elif index == 3:
			var lulu_model := _character_models[index].get_node("LuluModel") as LuluModel
			lulu_model.play_animation(&"idle")
		elif index == 2:
			var doumaoren_model := _character_models[index].get_node("DoumaorenModel") as DoumaorenModel
			doumaoren_model.play_animation(&"idle")
