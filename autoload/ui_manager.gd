extends Node

const MAIN_MENU_SCENE := "res://menus/main_menu.tscn"
const DEPLOYMENT_SCENE := "res://menus/deployment_flow.tscn"
const LOBBY_SCENE := "res://menus/network_lobby.tscn"
const GAME_SCENE := "res://scenes/prototype_arena.tscn"

var selected_boss := "追猎者"
var selected_map := "高地试验场"
var selected_character := "头疼的符文大师"
var party_size := 1
var selected_difficulty := 1


func start_game(boss_name: String, map_name: String, character_name: String, selected_party_size := 1, difficulty := 1) -> void:
	selected_boss = boss_name
	selected_map = map_name
	selected_character = character_name
	party_size = clampi(selected_party_size, 1, 4)
	selected_difficulty = clampi(difficulty, 0, 2)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().change_scene_to_file(GAME_SCENE)


func open_deployment() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(DEPLOYMENT_SCENE)


func open_lobby() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_file(LOBBY_SCENE)


func open_main_menu() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func quit_game() -> void:
	get_tree().quit()
