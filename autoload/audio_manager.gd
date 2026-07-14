extends Node

const BGM_MENU := preload("res://assets/audio/bgm_menu.mp3")
const BGM_BATTLE := preload("res://assets/audio/bgm_battle_5min.ogg")
const BGM_WIN := preload("res://assets/audio/win.mp3")

const SFX_UI_HOVER := preload("res://assets/audio/ui_hover.mp3")
const SFX_UI_CONFIRM := preload("res://assets/audio/ui_confirm.mp3")
const SFX_BOSS_SHOOT := preload("res://assets/audio/boss shoot.mp3")
const SFX_HAMMER_ATTACK := preload("res://assets/audio/hammer_attack.mp3")
const SFX_PROPELLER_LOOP := preload("res://assets/audio/propeller_loop.mp3")
const SFX_EXPLOSION := preload("res://assets/audio/explosion.mp3")
const SFX_LANDMINE_PLACE := preload("res://assets/audio/landmine.mp3")

var _music_player: AudioStreamPlayer
var _propeller_player: AudioStreamPlayer
var _current_music: AudioStream


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)

	_propeller_player = AudioStreamPlayer.new()
	_propeller_player.name = "PropellerLoopPlayer"
	_propeller_player.stream = SFX_PROPELLER_LOOP
	_propeller_player.volume_db = -8.0
	add_child(_propeller_player)


func play_menu_music() -> void:
	_play_music(BGM_MENU, -8.0)


func play_deployment_music() -> void:
	_play_music(BGM_MENU, -8.0)


func play_combat_music() -> void:
	_play_music(BGM_BATTLE, -6.0)


func play_victory_music() -> void:
	_play_music(BGM_WIN, -5.0, false)


func play_defeat_music() -> void:
	_music_player.stop()
	_current_music = null
	play_ui_back()


func stop_music() -> void:
	_music_player.stop()
	_current_music = null


func play_ui_hover() -> void:
	_play_sfx(SFX_UI_HOVER, -12.0)


func play_ui_confirm() -> void:
	_play_sfx(SFX_UI_CONFIRM, -9.0)


func play_ui_back() -> void:
	_play_sfx(SFX_UI_CONFIRM, -13.0, 0.88)


func play_pause_toggle() -> void:
	_play_sfx(SFX_UI_CONFIRM, -12.0, 0.75)


func play_victory_stinger() -> void:
	play_victory_music()


func play_player_shoot() -> void:
	_play_sfx(SFX_BOSS_SHOOT, -15.0, 1.18)


func play_boss_shoot() -> void:
	_play_sfx(SFX_BOSS_SHOOT, -7.0, 0.92)


func play_hammer_attack() -> void:
	_play_sfx(SFX_HAMMER_ATTACK, -5.5)


func play_landmine_place() -> void:
	_play_sfx(SFX_LANDMINE_PLACE, -6.0)


func play_explosion() -> void:
	_play_sfx(SFX_EXPLOSION, -3.0)


func play_propeller_loop() -> void:
	if not _propeller_player.playing:
		_propeller_player.play()


func stop_propeller_loop() -> void:
	if _propeller_player.playing:
		_propeller_player.stop()


func connect_button_tree(root: Node) -> void:
	if root == null:
		return
	_connect_buttons_recursive(root)


func _connect_buttons_recursive(node: Node) -> void:
	if node is BaseButton and not node.has_meta("audio_manager_connected"):
		node.set_meta("audio_manager_connected", true)
		node.mouse_entered.connect(play_ui_hover)
		node.pressed.connect(play_ui_confirm)
	for child in node.get_children():
		_connect_buttons_recursive(child)


func _play_music(stream: AudioStream, volume_db := -6.0, loop := true) -> void:
	if _music_player == null:
		return
	if _current_music == stream and _music_player.playing:
		return
	_current_music = stream
	if "loop" in stream:
		stream.loop = loop
	_music_player.stream = stream
	_music_player.volume_db = volume_db
	_music_player.play()


func _play_sfx(stream: AudioStream, volume_db := -8.0, pitch_scale := 1.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
