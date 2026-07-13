extends Node

signal status_changed(message: String)
signal lobby_changed(players: Dictionary)
signal deployment_requested

const DEFAULT_PORT := 7000
const MAX_CONNECTIONS := 4

var peer: ENetMultiplayerPeer
var players: Dictionary = {}
var network_active := false
var hosting := false


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func start_offline() -> void:
	disconnect_session()
	network_active = false
	hosting = true
	players = {1: {"name": "Player 1"}}
	lobby_changed.emit(players)
	status_changed.emit("离线Host模式")


func host_session(port := DEFAULT_PORT) -> Error:
	disconnect_session()
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_server(port, MAX_CONNECTIONS - 1)
	if result != OK:
		status_changed.emit("建房失败：%s" % error_string(result))
		return result
	multiplayer.multiplayer_peer = peer
	network_active = true
	hosting = true
	players = {1: {"name": "Host"}}
	lobby_changed.emit(players)
	status_changed.emit("Host已创建，端口 %d" % port)
	return OK


func join_session(address: String, port := DEFAULT_PORT) -> Error:
	disconnect_session()
	peer = ENetMultiplayerPeer.new()
	var result := peer.create_client(address, port)
	if result != OK:
		status_changed.emit("连接失败：%s" % error_string(result))
		return result
	multiplayer.multiplayer_peer = peer
	network_active = true
	hosting = false
	status_changed.emit("正在连接 %s:%d..." % [address, port])
	return OK


func disconnect_session() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	peer = null
	players.clear()
	network_active = false
	hosting = false


func begin_deployment() -> void:
	if network_active and multiplayer.is_server():
		_open_deployment.rpc()
	else:
		_open_deployment()


@rpc("authority", "call_local", "reliable")
func _open_deployment() -> void:
	deployment_requested.emit()
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null:
		ui_manager.open_deployment()


@rpc("any_peer", "reliable")
func _register_player(player_name: String) -> void:
	if not multiplayer.is_server():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	players[sender_id] = {"name": player_name}
	_broadcast_lobby()


@rpc("authority", "call_remote", "reliable")
func _receive_lobby(updated_players: Dictionary) -> void:
	players = updated_players
	lobby_changed.emit(players)


func _broadcast_lobby() -> void:
	lobby_changed.emit(players)
	_receive_lobby.rpc(players)


func _on_peer_connected(peer_id: int) -> void:
	if multiplayer.is_server():
		status_changed.emit("玩家 %d 已连接" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	players.erase(peer_id)
	if multiplayer.is_server():
		_broadcast_lobby()
	status_changed.emit("玩家 %d 已离开" % peer_id)


func _on_connected_to_server() -> void:
	status_changed.emit("已连接Host，等待开始")
	_register_player.rpc_id(1, "Player %d" % multiplayer.get_unique_id())


func _on_connection_failed() -> void:
	status_changed.emit("无法连接Host")
	disconnect_session()


func _on_server_disconnected() -> void:
	status_changed.emit("Host已断开")
	disconnect_session()

