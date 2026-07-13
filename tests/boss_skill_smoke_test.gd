extends SceneTree

const UI_MANAGER_SCRIPT := preload("res://autoload/ui_manager.gd")
const ARENA_SCENE := preload("res://scenes/prototype_arena.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui_manager := UI_MANAGER_SCRIPT.new()
	ui_manager.name = "UIManager"
	ui_manager.party_size = 4
	ui_manager.selected_difficulty = 2
	ui_manager.selected_character = "快乐的本科生"
	root.add_child(ui_manager)
	var arena := ARENA_SCENE.instantiate()
	root.add_child(arena)
	await process_frame
	var observed_states: Dictionary = {}
	for frame in 3600:
		if not is_instance_valid(arena.boss):
			break
		observed_states[arena.boss.get_state_name()] = true
		await physics_frame
	print("BOSS STATES: ", observed_states.keys())
	assert(observed_states.has("Triple Burst"))
	assert(observed_states.has("Charging"))
	assert(observed_states.has("Laser Sweep"))
	assert(observed_states.has("Jump Reposition"))
	quit()
