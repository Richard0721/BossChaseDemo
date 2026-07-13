extends Control

const SETTINGS_PATH := "res://assets/audio/gameplay_bgm/gameplay_audio_settings.tres"
const SETTINGS := preload(SETTINGS_PATH)

@onready var bgm: GameplayBGM = $GameplayBGM
@onready var volume_slider: HSlider = $Panel/Margin/Content/VolumeSlider
@onready var volume_value: Label = $Panel/Margin/Content/VolumeValue
@onready var play_button: Button = $Panel/Margin/Content/Buttons/PlayPause
@onready var save_status: Label = $Panel/Margin/Content/SaveStatus


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	volume_slider.value = SETTINGS.volume_db
	volume_slider.value_changed.connect(_on_volume_changed)
	play_button.pressed.connect(_on_play_pause_pressed)
	$Panel/Margin/Content/Buttons/Restart.pressed.connect(_on_restart_pressed)
	_update_volume_text(SETTINGS.volume_db)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _on_volume_changed(value: float) -> void:
	bgm.volume_db = value
	SETTINGS.volume_db = value
	var save_error := ResourceSaver.save(SETTINGS, SETTINGS_PATH)
	save_status.text = "已保存到游戏设置" if save_error == OK else "保存失败：%s" % error_string(save_error)
	_update_volume_text(value)


func _on_play_pause_pressed() -> void:
	if bgm.playing:
		bgm.stream_paused = not bgm.stream_paused
	else:
		bgm.play()
	play_button.text = "继续播放" if bgm.stream_paused else "暂停"


func _on_restart_pressed() -> void:
	bgm.play(0.0)
	bgm.stream_paused = false
	play_button.text = "暂停"


func _update_volume_text(value: float) -> void:
	volume_value.text = "当前音量：%.1f dB" % value
