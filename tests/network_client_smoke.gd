extends SceneTree

const NETWORK_SCRIPT := preload("res://autoload/network_manager.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := NETWORK_SCRIPT.new()
	manager.name = "NetworkManager"
	root.add_child(manager)
	assert(manager.join_session("127.0.0.1", 7117) == OK)
	for frame in 1200:
		if manager.players.size() >= 2:
			print("LAN CLIENT OK: ", manager.players)
			quit()
			return
		await process_frame
	printerr("LAN CLIENT TIMEOUT")
	quit(1)
