class_name GameplayBGM
extends AudioStreamPlayer

const SETTINGS := preload("res://assets/audio/gameplay_bgm/gameplay_audio_settings.tres")


func _ready() -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	volume_db = SETTINGS.volume_db
	play()
