extends Node3D

const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师",
	"快乐的本科生",
	"神秘兜帽人",
	"潇洒的男子 Lulu",
]
const BACKGROUND_SCENES: Array[PackedScene] = [
	preload("res://menus/backgrounds/rune_sanctum.tscn"),
	preload("res://menus/backgrounds/campus_roof.tscn"),
	preload("res://menus/backgrounds/hooded_ruins.tscn"),
	preload("res://menus/backgrounds/lulu_skyway.tscn"),
]
const UI_BACKGROUND_PATH := "res://assets/ui/main_menu/main_menu_background.png"
const UI_BUTTON_START_PATH := "res://assets/ui/main_menu/button_start_transparent.png"
const UI_BUTTON_RULES_PATH := "res://assets/ui/main_menu/button_rules_transparent.png"
const UI_BUTTON_SETTINGS_PATH := "res://assets/ui/main_menu/button_settings_transparent.png"
const UI_BUTTON_QUIT_PATH := "res://assets/ui/main_menu/button_quit_transparent.png"

@onready var camera: Camera3D = $MenuCamera
@onready var display_character: Node3D = $DisplayCharacter
@onready var character_head: Node3D = $DisplayCharacter/HeadPivot
@onready var happy_student: HappyStudentModel = $DisplayCharacter/HappyStudent
@onready var fashi: FashiModel = $DisplayCharacter/Fashi
@onready var lulu: LuluModel = $DisplayCharacter/Lulu
@onready var doumaoren: DoumaorenModel = $DisplayCharacter/Doumaoren
@onready var background_slot: Node3D = $BackgroundSlot
@onready var character_name_label: Label = $MainMenuUI/CharacterName

@onready var main_panel: Control = $MainMenuUI/MainPanel
@onready var selection_panel: Control = $MainMenuUI/SelectionPanel
@onready var rules_panel: Control = $MainMenuUI/RulesPanel
@onready var settings_panel: Control = $MainMenuUI/SettingsPanel

@onready var boss_option: OptionButton = $MainMenuUI/SelectionPanel/Content/BossOption
@onready var map_option: OptionButton = $MainMenuUI/SelectionPanel/Content/MapOption
@onready var character_option: OptionButton = $MainMenuUI/SelectionPanel/Content/CharacterOption
@onready var fullscreen_toggle: CheckButton = $MainMenuUI/SettingsPanel/Content/Fullscreen
@onready var volume_slider: HSlider = $MainMenuUI/SettingsPanel/Content/Volume

var _display_character_index := 0


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_menu_music()
	AudioManager.connect_button_tree(self)
	_apply_main_menu_art_direction()
	_display_character_index = randi_range(0, CHARACTER_NAMES.size() - 1)
	_load_character_showcase(_display_character_index)
	_populate_selection_options()
	_connect_buttons()
	fullscreen_toggle.button_pressed = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	var master_bus := AudioServer.get_bus_index("Master")
	volume_slider.value = db_to_linear(AudioServer.get_bus_volume_db(master_bus)) * 100.0


func _apply_main_menu_art_direction() -> void:
	background_slot.visible = false
	$Sun.light_energy = 0.55
	$RimLight.light_energy = 4.5
	camera.fov = 48.0
	display_character.position = Vector3(3.35, 1.45, 0.0)
	display_character.scale = Vector3.ONE * 0.92
	var ui_layer := $MainMenuUI
	var background := TextureRect.new()
	background.name = "ImportedBackground"
	background.texture = load(UI_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(background)
	ui_layer.move_child(background, 0)
	var shade := $MainMenuUI/Shade
	var shade_style := StyleBoxFlat.new()
	shade_style.bg_color = Color(0.005, 0.012, 0.03, 0.34)
	shade.add_theme_stylebox_override("panel", shade_style)
	_style_main_title()
	_style_main_panel_buttons()
	_style_character_name()


func _style_main_title() -> void:
	var title := $MainMenuUI/GameTitle as Label
	title.offset_left = 62.0
	title.offset_top = 52.0
	title.offset_right = 760.0
	title.offset_bottom = 118.0
	title.text = "BOSS CHASE //\n追击协议"
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color(0.92, 0.98, 1.0, 1.0))
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.08, 0.18, 0.95))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	var subtitle := $MainMenuUI/SubTitle as Label
	subtitle.offset_left = 66.0
	subtitle.offset_top = 158.0
	subtitle.offset_right = 560.0
	subtitle.offset_bottom = 190.0
	subtitle.text = "LAN THIRD-PERSON ACTION DEMO"
	subtitle.add_theme_font_size_override("font_size", 19)
	subtitle.add_theme_color_override("font_color", Color(0.12, 0.72, 1.0, 1.0))


func _style_main_panel_buttons() -> void:
	main_panel.offset_left = 50.0
	main_panel.offset_top = 230.0
	main_panel.offset_right = 550.0
	main_panel.offset_bottom = 680.0
	main_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content := $MainMenuUI/MainPanel/Content as VBoxContainer
	content.offset_left = 0.0
	content.offset_top = 0.0
	content.offset_right = 0.0
	content.offset_bottom = 0.0
	content.add_theme_constant_override("separation", 8)
	$MainMenuUI/MainPanel/Content/MenuLabel.visible = false
	$MainMenuUI/MainPanel/Content/Spacer.custom_minimum_size = Vector2(0, 0)
	_apply_image_button($MainMenuUI/MainPanel/Content/Start, load(UI_BUTTON_START_PATH), Vector2(500, 112))
	_apply_image_button($MainMenuUI/MainPanel/Content/Rules, load(UI_BUTTON_RULES_PATH), Vector2(500, 88))
	_apply_image_button($MainMenuUI/MainPanel/Content/Settings, load(UI_BUTTON_SETTINGS_PATH), Vector2(500, 88))
	_apply_image_button($MainMenuUI/MainPanel/Content/Quit, load(UI_BUTTON_QUIT_PATH), Vector2(500, 88))


func _apply_image_button(button: Button, texture: Texture2D, minimum_size: Vector2) -> void:
	button.text = ""
	button.icon = texture
	button.expand_icon = true
	button.custom_minimum_size = minimum_size
	button.focus_mode = Control.FOCUS_ALL
	button.flat = true
	var empty := StyleBoxEmpty.new()
	button.add_theme_stylebox_override("normal", empty)
	button.add_theme_stylebox_override("hover", empty)
	button.add_theme_stylebox_override("pressed", empty)
	button.add_theme_stylebox_override("focus", empty)
	button.mouse_entered.connect(_on_menu_button_hovered.bind(button))
	button.mouse_exited.connect(_on_menu_button_unhovered.bind(button))


func _on_menu_button_hovered(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2(1.035, 1.035), 0.08)


func _on_menu_button_unhovered(button: Button) -> void:
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, 0.08)


func _style_character_name() -> void:
	character_name_label.offset_left = -430.0
	character_name_label.offset_top = -88.0
	character_name_label.offset_right = -54.0
	character_name_label.offset_bottom = -44.0
	character_name_label.add_theme_font_size_override("font_size", 25)
	character_name_label.add_theme_color_override("font_color", Color(0.35, 0.72, 1.0, 1.0))


func _process(delta: float) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var mouse_position := get_viewport().get_mouse_position()
	var normalized_mouse := Vector2.ZERO
	if viewport_size.x > 0.0 and viewport_size.y > 0.0:
		normalized_mouse = mouse_position / viewport_size * 2.0 - Vector2.ONE
	var target_head_rotation := Vector3(
		clampf(normalized_mouse.y * 0.22, -0.22, 0.22),
		clampf(normalized_mouse.x * 0.48, -0.48, 0.48),
		0.0
	)
	character_head.rotation = character_head.rotation.lerp(target_head_rotation, 7.0 * delta)
	display_character.rotation.y = lerp_angle(display_character.rotation.y, normalized_mouse.x * 0.08, 2.5 * delta)
	var active_model := _get_active_display_model()
	if active_model != null:
		_apply_model_head_look(active_model, target_head_rotation)
		active_model.rotation.y = lerp_angle(active_model.rotation.y, clampf(normalized_mouse.x * 0.12, -0.12, 0.12), 6.0 * delta)
	camera.position.x = lerpf(camera.position.x, normalized_mouse.x * 0.28, 1.8 * delta)
	camera.position.y = lerpf(camera.position.y, 3.1 - normalized_mouse.y * 0.12, 1.8 * delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back"):
		AudioManager.play_ui_back()
		_show_main_panel()


func _load_character_showcase(character_index: int) -> void:
	for child in background_slot.get_children():
		child.queue_free()
	var background := BACKGROUND_SCENES[character_index].instantiate()
	background_slot.add_child(background)
	character_name_label.text = CHARACTER_NAMES[character_index]
	var is_happy_student := character_index == 1
	var is_fashi := character_index == 0
	var is_lulu := character_index == 3
	var is_doumaoren := character_index == 2
	$DisplayCharacter/Body.visible = not is_happy_student and not is_fashi and not is_lulu and not is_doumaoren
	$DisplayCharacter/HeadPivot.visible = not is_happy_student and not is_fashi and not is_lulu and not is_doumaoren
	happy_student.visible = is_happy_student
	fashi.visible = is_fashi
	lulu.visible = is_lulu
	doumaoren.visible = is_doumaoren
	if is_happy_student:
		happy_student.set_weapon_visible(false)
		happy_student.play_animation(&"standing", 0.0, 1.0, true)
	elif is_fashi:
		fashi.set_weapon_visible(false)
		fashi.play_animation(&"standing", 0.0, 1.0, true)
	elif is_lulu:
		lulu.set_weapon_visible(false)
		lulu.play_animation(&"standing", 0.0, 1.0, true)
	elif is_doumaoren:
		doumaoren.set_weapon_visible(false)
		doumaoren.play_animation(&"standing", 0.0, 1.0, true)
	for model in [happy_student, fashi, lulu, doumaoren]:
		model.rotation = Vector3.ZERO
		_freeze_display_model(model)
	var character_colors := [
		Color(0.1, 0.85, 0.65, 1),
		Color(1.0, 0.58, 0.12, 1),
		Color(0.48, 0.2, 0.9, 1),
		Color(0.08, 0.58, 1.0, 1),
	]
	var material := StandardMaterial3D.new()
	material.albedo_color = character_colors[character_index]
	material.metallic = 0.15
	material.roughness = 0.42
	$DisplayCharacter/Body.material_override = material
	$DisplayCharacter/HeadPivot/Head.material_override = material


func _populate_selection_options() -> void:
	boss_option.add_item("追猎者")
	map_option.add_item("高地试验场")
	for character_name in CHARACTER_NAMES:
		character_option.add_item(character_name)
	character_option.select(_display_character_index)
	character_option.item_selected.connect(_on_character_selected)


func _connect_buttons() -> void:
	$MainMenuUI/MainPanel/Content/Start.pressed.connect(_open_deployment_flow)
	$MainMenuUI/MainPanel/Content/Rules.pressed.connect(_show_rules_panel)
	$MainMenuUI/MainPanel/Content/Settings.pressed.connect(_show_settings_panel)
	$MainMenuUI/MainPanel/Content/Quit.pressed.connect(UIManager.quit_game)
	$MainMenuUI/SelectionPanel/Content/Deploy.pressed.connect(_deploy_game)
	$MainMenuUI/SelectionPanel/Content/Back.pressed.connect(_show_main_panel)
	$MainMenuUI/RulesPanel/Content/Back.pressed.connect(_show_main_panel)
	$MainMenuUI/SettingsPanel/Content/Back.pressed.connect(_show_main_panel)
	fullscreen_toggle.toggled.connect(_on_fullscreen_toggled)
	volume_slider.value_changed.connect(_on_volume_changed)


func _show_only(panel: Control) -> void:
	main_panel.visible = panel == main_panel
	selection_panel.visible = panel == selection_panel
	rules_panel.visible = panel == rules_panel
	settings_panel.visible = panel == settings_panel


func _show_main_panel() -> void:
	_show_only(main_panel)


func _show_selection_panel() -> void:
	_show_only(selection_panel)


func _open_deployment_flow() -> void:
	UIManager.open_lobby()


func _show_rules_panel() -> void:
	_show_only(rules_panel)


func _show_settings_panel() -> void:
	_show_only(settings_panel)


func _on_character_selected(index: int) -> void:
	AudioManager.play_ui_confirm()
	_display_character_index = index
	_load_character_showcase(index)


func _deploy_game() -> void:
	UIManager.start_game(
		boss_option.get_item_text(boss_option.selected),
		map_option.get_item_text(map_option.selected),
		character_option.get_item_text(character_option.selected)
	)


func _on_fullscreen_toggled(enabled: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)


func _on_volume_changed(value: float) -> void:
	var master_bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(master_bus, linear_to_db(maxf(value / 100.0, 0.001)))


func _get_active_display_model() -> Node3D:
	if happy_student.visible:
		return happy_student
	if fashi.visible:
		return fashi
	if lulu.visible:
		return lulu
	if doumaoren.visible:
		return doumaoren
	return null


func _freeze_display_model(model: Node3D) -> void:
	var animation_player := model.get_node_or_null("Rig/AnimationPlayer") as AnimationPlayer
	if animation_player == null:
		return
	animation_player.advance(0.0)
	animation_player.pause()


func _apply_model_head_look(model: Node3D, target_rotation: Vector3) -> void:
	var skeleton := model.get_node_or_null("Rig/Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	var head_bone := _find_bone_by_suffix(skeleton, "Head")
	if head_bone < 0:
		head_bone = _find_bone_by_suffix(skeleton, "Neck")
	if head_bone < 0:
		return
	var current_pose := skeleton.get_bone_pose_rotation(head_bone)
	var target_pose := Quaternion.from_euler(Vector3(target_rotation.x * 0.55, target_rotation.y * 0.7, 0.0))
	skeleton.set_bone_pose_rotation(head_bone, current_pose.slerp(target_pose, 0.18))


func _find_bone_by_suffix(skeleton: Skeleton3D, suffix: String) -> int:
	for bone_index in skeleton.get_bone_count():
		var bone_name := skeleton.get_bone_name(bone_index)
		if bone_name == suffix or bone_name.ends_with("_" + suffix) or bone_name.ends_with(suffix):
			return bone_index
	return -1
