extends Control

@onready var address: LineEdit = $Panel/Content/Address
@onready var port: SpinBox = $Panel/Content/Port
@onready var status: Label = $Panel/Content/Status
@onready var player_list: Label = $Panel/Content/Players
@onready var continue_button: Button = $Panel/Content/Continue


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	AudioManager.play_menu_music()
	AudioManager.connect_button_tree(self)
	$Panel/Content/Offline.pressed.connect(_start_offline)
	$Panel/Content/Host.pressed.connect(_host)
	$Panel/Content/Join.pressed.connect(_join)
	$Panel/Content/Back.pressed.connect(_back)
	continue_button.pressed.connect(NetworkManager.begin_deployment)
	NetworkManager.status_changed.connect(_on_status_changed)
	NetworkManager.lobby_changed.connect(_on_lobby_changed)
	continue_button.visible = false
	_on_status_changed("选择离线测试、Host建房或加入LAN房间")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("controller_back"):
		AudioManager.play_ui_back()
		_back()


func _start_offline() -> void:
	NetworkManager.start_offline()
	UIManager.open_deployment()


func _host() -> void:
	if NetworkManager.host_session(int(port.value)) == OK:
		continue_button.visible = true


func _join() -> void:
	continue_button.visible = false
	NetworkManager.join_session(address.text.strip_edges(), int(port.value))


func _back() -> void:
	NetworkManager.disconnect_session()
	UIManager.open_main_menu()


func _on_status_changed(message: String) -> void:
	status.text = message


func _on_lobby_changed(players: Dictionary) -> void:
	var lines: Array[String] = []
	for peer_id in players:
		lines.append("• %s  [Peer %s]" % [players[peer_id].get("name", "Player"), peer_id])
	player_list.text = "房间成员 %d / 4\n%s" % [players.size(), "\n".join(lines)]
