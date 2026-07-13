extends SceneTree

const NETWORK_SCRIPT := preload("res://autoload/network_manager.gd")


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var manager := NETWORK_SCRIPT.new()
	manager.name = "NetworkManager"
	root.add_child(manager)
	assert(manager.host_session(7117) == OK)
	for frame in 1200:
		if manager.players.size() >= 2:
			print("LAN HOST OK: ", manager.players)
			quit()
			return
		await process_frame
	printerr("LAN HOST TIMEOUT")
	quit(1)

