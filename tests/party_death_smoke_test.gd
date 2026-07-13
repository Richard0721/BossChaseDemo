extends SceneTree

const UI_MANAGER_SCRIPT := preload("res://autoload/ui_manager.gd")
const ARENA_SCENE := preload("res://scenes/prototype_arena.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui_manager := UI_MANAGER_SCRIPT.new()
	ui_manager.name = "UIManager"
	ui_manager.party_size = 4
	ui_manager.selected_character = "头疼的符文大师"
	root.add_child(ui_manager)
	var arena := ARENA_SCENE.instantiate()
	root.add_child(arena)
	await process_frame
	var ai_members := get_nodes_in_group("ai_teammates")
	assert(ai_members.size() == 3)
	assert(is_equal_approx(arena.boss.max_health, 250.0))
	assert(is_equal_approx(arena.boss._damage_for_target(ai_members[0], 10.0), 12.0))
	print("PARTY SIZE OK: 1 HUMAN + ", ai_members.size(), " AI")
	print("BOSS SCALE OK: HP=", arena.boss.max_health, " NORMAL AI DAMAGE=150%")
	var player := get_first_node_in_group("players") as ThirdPersonPlayer
	player.apply_damage(9999.0)
	await process_frame
	assert(arena.player_respawn_time > 14.0)
	print("SPECTATOR RESPAWN OK: ", arena.player_respawn_time)
	for ai in ai_members:
		ai.apply_damage(9999.0)
	await process_frame
	assert(arena.match_finished)
	print("TEAM WIPE OK")
	quit()
