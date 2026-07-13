extends Node

enum MusicMode { NONE, MENU, DEPLOYMENT, COMBAT, VICTORY, DEFEAT }

const MIX_RATE := 22050.0
const MASTER_VOLUME := 0.32

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _music_mode := MusicMode.NONE
var _music_time := 0.0
var _phase_a := 0.0
var _phase_b := 0.0
var _sfx_events: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = MIX_RATE
	stream.buffer_length = 0.35
	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralAudioOutput"
	_player.stream = stream
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback()


func _process(_delta: float) -> void:
	if _playback == null:
		return
	var available := _playback.get_frames_available()
	for _index in available:
		var sample := _render_music_frame() + _render_sfx_frame()
		sample = clampf(sample * MASTER_VOLUME, -0.9, 0.9)
		_playback.push_frame(Vector2(sample, sample))


func play_menu_music() -> void:
	_set_music_mode(MusicMode.MENU)


func play_deployment_music() -> void:
	_set_music_mode(MusicMode.DEPLOYMENT)


func play_combat_music() -> void:
	_set_music_mode(MusicMode.COMBAT)


func play_victory_music() -> void:
	_set_music_mode(MusicMode.VICTORY)
	play_victory_stinger()


func play_defeat_music() -> void:
	_set_music_mode(MusicMode.DEFEAT)
	_add_sfx("defeat")


func stop_music() -> void:
	_set_music_mode(MusicMode.NONE)


func play_ui_hover() -> void:
	_add_sfx("hover")


func play_ui_confirm() -> void:
	_add_sfx("confirm")


func play_ui_back() -> void:
	_add_sfx("back")


func play_pause_toggle() -> void:
	_add_sfx("pause")


func play_victory_stinger() -> void:
	_add_sfx("victory")


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


func _set_music_mode(next_mode: int) -> void:
	if _music_mode == next_mode:
		return
	_music_mode = next_mode
	_music_time = 0.0
	_phase_a = 0.0
	_phase_b = 0.0


func _render_music_frame() -> float:
	if _music_mode == MusicMode.NONE:
		return 0.0
	var profile := _get_music_profile(_music_mode)
	var freqs: Array = profile["freqs"]
	var bass: Array = profile["bass"]
	var step_time: float = profile["step"]
	var volume: float = profile["volume"]
	var step := int(_music_time / step_time) % freqs.size()
	var local_t := fmod(_music_time, step_time) / step_time
	var envelope := smoothstep(1.0, 0.0, local_t)
	var freq: float = freqs[step]
	var bass_freq: float = bass[step % bass.size()]
	_phase_a = fmod(_phase_a + TAU * freq / MIX_RATE, TAU)
	_phase_b = fmod(_phase_b + TAU * bass_freq / MIX_RATE, TAU)
	_music_time += 1.0 / MIX_RATE
	return (sin(_phase_a) * 0.72 * envelope + sin(_phase_b) * 0.28) * volume


func _get_music_profile(mode: int) -> Dictionary:
	match mode:
		MusicMode.MENU:
			return {
				"freqs": [261.63, 329.63, 392.0, 523.25, 392.0, 329.63],
				"bass": [130.81, 130.81, 196.0],
				"step": 0.32,
				"volume": 0.11,
			}
		MusicMode.DEPLOYMENT:
			return {
				"freqs": [293.66, 349.23, 440.0, 587.33, 440.0, 349.23],
				"bass": [146.83, 174.61, 220.0],
				"step": 0.22,
				"volume": 0.12,
			}
		MusicMode.COMBAT:
			return {
				"freqs": [220.0, 261.63, 329.63, 392.0, 329.63, 261.63],
				"bass": [110.0, 110.0, 164.81, 196.0],
				"step": 0.15,
				"volume": 0.14,
			}
		MusicMode.VICTORY:
			return {
				"freqs": [392.0, 493.88, 587.33, 783.99, 987.77, 783.99],
				"bass": [196.0, 246.94, 293.66],
				"step": 0.2,
				"volume": 0.13,
			}
		MusicMode.DEFEAT:
			return {
				"freqs": [220.0, 207.65, 196.0, 174.61],
				"bass": [110.0, 98.0],
				"step": 0.38,
				"volume": 0.1,
			}
	return {"freqs": [440.0], "bass": [110.0], "step": 0.25, "volume": 0.0}


func _add_sfx(kind: String) -> void:
	for event in _sfx_events:
		if String(event["kind"]) == kind and float(event["time"]) < 0.025:
			return
	_sfx_events.append({"kind": kind, "time": 0.0, "duration": _get_sfx_duration(kind)})


func _get_sfx_duration(kind: String) -> float:
	match kind:
		"hover":
			return 0.045
		"confirm":
			return 0.09
		"back":
			return 0.13
		"pause":
			return 0.1
		"victory":
			return 0.55
		"defeat":
			return 0.55
	return 0.08


func _render_sfx_frame() -> float:
	var output := 0.0
	var dt := 1.0 / MIX_RATE
	for index in range(_sfx_events.size() - 1, -1, -1):
		var event := _sfx_events[index]
		var time: float = event["time"]
		var duration: float = event["duration"]
		if time >= duration:
			_sfx_events.remove_at(index)
			continue
		output += _sample_sfx(String(event["kind"]), time, duration)
		event["time"] = time + dt
		_sfx_events[index] = event
	return output


func _sample_sfx(kind: String, time: float, duration: float) -> float:
	var progress := clampf(time / maxf(duration, 0.001), 0.0, 1.0)
	var decay := 1.0 - progress
	match kind:
		"hover":
			return sin(TAU * 740.0 * time) * 0.12 * decay
		"confirm":
			return (sin(TAU * 880.0 * time) + sin(TAU * 1320.0 * time) * 0.4) * 0.18 * decay
		"back":
			return sin(TAU * lerpf(420.0, 180.0, progress) * time) * 0.16 * decay
		"pause":
			return sin(TAU * 520.0 * time) * 0.14 * decay
		"victory":
			return sin(TAU * lerpf(520.0, 1040.0, progress) * time) * 0.22 * decay
		"defeat":
			return sin(TAU * lerpf(220.0, 90.0, progress) * time) * 0.2 * decay
	return 0.0
