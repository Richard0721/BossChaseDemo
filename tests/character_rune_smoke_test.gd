extends SceneTree

const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const CHARACTER_NAMES: Array[String] = [
	"头疼的符文大师",
	"快乐的本科生",
	"神秘兜帽人",
	"潇洒的男子 Lulu",
]


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for character_name in CHARACTER_NAMES:
		var ui_manager := root.get_node_or_null("UIManager")
		if ui_manager != null:
			ui_manager.selected_character = character_name
		var player: ThirdPersonPlayer = PLAYER_SCENE.instantiate()
		root.add_child(player)
		await process_frame
		player.apply_rune(&"Heal")
		player.apply_rune(&"Speed")
		player.apply_rune(&"Attack")
		player.apply_rune(&"Defense")
		await process_frame
		print("SMOKE OK: ", player.get_character_name(), " HP=", player.health, " JUMPS=", player.get_allowed_jump_count())
		player.queue_free()
		await process_frame
	quit()
