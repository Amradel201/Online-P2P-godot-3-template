extends Control

#Functions for you: host(), join(ip_address), start(), leave()

export(PackedScene) var travel_to_scene
export var testing: bool
var playername

var upnp
export var online :bool


func _process(delta):
	pass
#LOBBY INTEGRATION
#1.1 Host & Join Signals
func _on_host_button_pressed():
	if online:
		var result = global.enupnp()
		if result.is_valid_hex_number():
			$host/ip_address.text = result
		else:
			show_join_error(result)
			return
	reset_buttons()
	hide_host_and_join_buttons()
	$host/ip_address.show()
	$room.show()
	$room/copy.show()
	$host/waiting_text.show()
	host($settings/max_players.value)

func _on_join_button_pressed():
	
	hide_host_and_join_buttons()
	$join/waiting_text.show()
	$room.show()
	$room/copy.hide()
	join($join/ip_address.text)

func _on_settings_pressed():
	hide_host_and_join_buttons()
	$settings.show()

func _on_back_button_pressed():
	reset_buttons()
	leave()

func _on_safe_back_button_pressed():
	reset_buttons()

#1.2 Host Signals
func _on_start_button_pressed():
	start()

#2 UI Help Functions
func reset_buttons():
	hide_host_and_join_buttons()
	$room.hide()
	$settings.hide()
	$host/host_button.show()
	$host/start_button.hide()
	$host/settings.show()
	$join/join_button.show()
	$join/ip_address.show()
	$join/error_text.show()
	$join/name.show()
	$join/paste.show()
	$host/online.show()

func hide_host_and_join_buttons():
	for i in get_node("host").get_child_count():
		get_node("host").get_child(i).hide()
	for i in get_node("join").get_child_count():
		get_node("join").get_child(i).hide()

func show_join_error(error_text):
	reset_buttons()
	$join/error_text.text = error_text
	if error_text == "Error: Full Room":
		$join/error_text/AnimationPlayer.play("full")
	elif error_text == "Error: Invalid IP Address":
		$join/error_text/AnimationPlayer.play("invalid")
	else:
		$join/error_text/AnimationPlayer.play("invalid")

var cache = "user://cache.dat"
var caches = "user://caches.dat"
var namepath = "user://name.dat"
var hostnamepath = "user://hostname.dat"
var max_players = 2
var port = 6777
var peer = NetworkedMultiplayerENet.new()
var connected_players = []
var lastip: String = "192.168.43.1"
#Server
signal server_started(host_id) ## Server receives this signal.

#Server & Players
signal player_connected(id) ## Server & players receive this signal.
signal player_disconnected(id, connected_players) ## Server & players receive this signal.

#Players
signal server_ended ## Players receive this signal.

#DO NOT USE
signal update_for_new_player() ## THIS IS USED IN SCRIPT, DO NOT TOUCH!
var aes = AESContext.new()



func _ready():
	load_data()
	if online:
		$host/online.pressed = true
	if testing:
		$host/ip_address.text = "127.0.0.1"
		$join/ip_address.text = "127.0.0.1"
	else:
		$join/ip_address.text = lastip
		for ip in IP.get_local_addresses():
			if "192." in ip:
				$host/ip_address.text = ip
				pass
	get_tree().connect("network_peer_connected", self, "_on_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("server_disconnected", self, "_on_server_disconnected")

#Signals for Server and Players
#Runs on other players once with the new player id
#and runs on the new player with the other players ids
func _on_player_connected(id):
	if get_tree().is_network_server():
		test_if_allowed_on_server(id)
		
	
	connected_players.append(id)
	add_room_player(id)
	
	if get_tree().is_network_server():
		$host/waiting_text.hide()
		$host/start_button.show()
	emit_signal("player_connected", id)

#Player Process
func test_if_allowed_on_server(id):
	if connected_players.size() == max_players:
		rpc_id(id, "process_kick", "Error: Full Room")
	else:
		rpc("processed_player")

mastersync func processed_player():
	call_deferred("emit_signal", "update_for_new_player")

#Kick Process
remote func process_kick(reason):
	show_join_error(reason)
	leave()

func _on_player_disconnected(id):
	connected_players.erase(id)
	remove_room_player(id)
	
	if get_tree().is_network_server():
		if connected_players.size() < 2:
			$host/start_button.hide()
			$host/waiting_text.show()
	emit_signal("player_disconnected", id, connected_players)

func _on_server_disconnected():
	get_tree().network_peer = null
	remove_all_room_players()
	reset_buttons()
	emit_signal("server_ended")

#Player tools
func start():
	rpc("start_scene", connected_players)

func leave():
	
	get_tree().network_peer.close_connection()
	remove_all_room_players()
	connected_players.clear()
	global.delmapping()

sync func start_scene(connected_players):
	global.connected_players =connected_players
	get_tree().change_scene_to(travel_to_scene)



func savedata():
	var file = File.new()
	file.open(caches, File.WRITE)
	file.store_var(lastip)
	global.nameo = $join/name.text
	file.store_var(global.nameo)
	file.close()



func add_room_player(id):
	var room_player = preload("res://addons/lan_multiplayer/scenes/room_player.tscn").instance()
	room_player.name = str(id)
	connect("update_for_new_player", room_player.get_node("player_controller"), "_on_update_for_new_player")
	connect("server_ended", room_player.get_node("player_controller"), "_on_server_disconnected")
	$room/room.add_child(room_player)

func remove_all_room_players():
	for i in connected_players.size():
		remove_room_player(connected_players[i])

func remove_room_player(id):
	if $room/room.get_node_or_null(str(id)):
		$room/room.get_node(str(id)).queue_free()

#Server tools
func host(maxi):
	max_players = maxi
	peer.create_server(port, max_players)
	get_tree().network_peer = peer
	connected_players.append(1)
	savedata()
	add_room_player(1)
	
	emit_signal("server_started", 1)

func join(fip):
	var ip = fip
	if !ip.is_valid_ip_address():
		var key = "ThereIsNoKeyHere"
		
		
		var hex = fip
		var unhex = PoolByteArray()
		for b in range(0 ,hex.length(), 2):
			var hexby = hex.substr(b,2)
			unhex.append(("0x"+hexby).hex_to_int())
		
		# Decrypt ECB
		aes.start(AESContext.MODE_ECB_DECRYPT, key.to_utf8())
		var decrypted = aes.update(unhex)
		aes.finish()
		var ftext = decrypted.get_string_from_utf8()
		while " " in ftext:
			ftext.erase(ftext.find(" "),1)
		ip = ftext
		print(ip)
	if not ip.is_valid_ip_address():
		show_join_error("Error: Invalid IP Address")
	else:
		lastip = fip
		savedata()
		peer.create_client(ip, port)
		get_tree().network_peer = peer
		connected_players.append(get_tree().get_network_unique_id())
		add_room_player(get_tree().get_network_unique_id())

func load_data():
	var file = File.new()
	if file.file_exists(caches):
		file.open(caches, File.READ)
		lastip = file.get_var()
		$join/ip_address.text = lastip
		$join/name.text = file.get_var()
		file.close()


func _on_online_toggled(val):
	online = val
	$host/online.release_focus()
	pass # Replace with function body.


func _on_paste_pressed():
	$join/ip_address.text = OS.get_clipboard()
	pass # Replace with function body.


func _on_copy_pressed():
	OS.set_clipboard($host/ip_address.text)
	pass # Replace with function body.
