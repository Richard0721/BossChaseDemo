extends SceneTree

const UI_MANAGER_SCRIPT := preload("res://autoload/ui_manager.gd")
const ARENA_SCENE := preload("res://scenes/prototype_arena.tscn")
const EXPLOSIVE_SCENE := preload("res://items/explosive/explosive.tscn")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui_manager := UI_MANAGER_SCRIPT.new()
	ui_manager.name = "UIManager"
	ui_manager.selected_character = "快乐的本科生"
	root.add_child(ui_manager)
	var arena := ARENA_SCENE.instantiate()
	root.add_child(arena)
	await process_frame
	await process_frame
	assert(get_nodes_in_group("item_boxes").size() == 15)
	var player := get_first_node_in_group("players") as ThirdPersonPlayer
	player.ammo = 0
	player.reserve_ammo = 300
	player._start_reload()
	player._update_reload(1.6)
	assert(player.ammo == 50 and player.reserve_ammo == 250)
	assert(player.receive_item(&"RapidGun"))
	assert(player.rapid_ammo == 100)
	player._discard_inventory_item()
	assert(player.inventory_item.is_empty() and player.get_active_item_name() == "Ranged")
	assert(player.receive_item(&"RapidGun"))
	player._remove_inventory_item()
	assert(player.receive_item(&"Shield"))
	var health_before := player.health
	player.apply_damage(30.0)
	assert(is_equal_approx(player.health, health_before))
	assert(is_equal_approx(player.shield_durability, 70.0))
	assert(player.inventory_item.is_empty() and player.get_active_item_name() == "Ranged")
	player.apply_damage(70.0)
	assert(is_equal_approx(player.health, health_before))
	assert(is_equal_approx(player.shield_durability, 0.0))
	assert(player.receive_item(&"Propeller"))
	player._use_inventory_item("Propeller")
	player.apply_damage(1.0)
	assert(player.inventory_item.is_empty() and player.propeller_fall_active)
	assert(player.receive_item(&"Hammer"))
	assert(is_equal_approx(1.0 / player.get_total_attack_speed(true), 0.5))
	player._remove_inventory_item()
	assert(player.receive_item(&"Landmine"))
	player._use_inventory_item("Landmine")
	var player_blast: AreaExplosive = EXPLOSIVE_SCENE.instantiate()
	player_blast.configure(0.0, 40.0, 5.0, Color.RED, 22.0, 16.0, 1.2)
	player_blast.global_position = player.global_position
	arena.add_child(player_blast)
	player_blast.explode()
	assert(player.velocity.y >= 15.9 and player.tumble_time > 1.0)
	var boss_blast: AreaExplosive = EXPLOSIVE_SCENE.instantiate()
	boss_blast.configure(0.0, 40.0, 5.0, Color.RED, 22.0, 16.0, 1.2)
	boss_blast.global_position = arena.boss.global_position
	arena.add_child(boss_blast)
	boss_blast.explode()
	assert(arena.boss.velocity.y >= 15.9 and arena.boss.tumble_time > 1.0)
	print("ITEM SYSTEM OK")
	quit()
