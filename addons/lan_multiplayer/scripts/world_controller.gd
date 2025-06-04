extends Node

#Functions for you: show_leaderboard(bool), 
#func_and_sync()

export var player_scene: PackedScene
export var spawn_path: NodePath
export var spawn_position: Vector2
var colnum = 1
var cache = "user://cache.dat"
var connected_players = []
var time = 0

#Server & Players
signal player_spawned(id) ## Server and players receive this signal.
signal player_left(id, connected_players) ## Server and players receive this signal.
signal game_started ## Server and players receive this signal.
signal time_ended ## Server and players receive this signal.

#Players
signal server_ended ## Players receive this signal.

#DO NOT USE
signal update_for_new_player() ## THIS IS USED IN SCRIPT, DO NOT TOUCH!

func _enter_tree():
	#AUTHORITY
	set_network_master(get_tree().network_peer.get_unique_id())

func _ready():
	get_tree().connect("network_peer_disconnected", self, "_on_player_disconnected")
	get_tree().connect("server_disconnected", self, "_on_server_disconnected")
	start()
	
	if not is_network_master():
		for i in Nodes.size():
			if get_node(Nodes[i]).has_method("_process"):
				get_node(Nodes[i]).call_deferred("set_process", false)
			if get_node(Nodes[i]).has_method("_physics_process"):
				get_node(Nodes[i]).call_deferred("set_physics_process", false)

func _on_player_disconnected(id):
	connected_players.erase(id)
	remove_player(id)
	emit_signal("player_left", id, connected_players)

func _on_server_disconnected():
	get_tree().change_scene("res://scenes/lobby.tscn")
	get_tree().network_peer = null
	remove_all_players()
	emit_signal("server_ended")

#Player tools

func start():
	connected_players = global.connected_players
	
	for id in connected_players.size():
		add_player(connected_players[id])
		add_room_player(connected_players[id])
	if get_tree().is_network_server():
		rpc("processed_player")
		
	

sync func processed_player():
	call_deferred("emit_signal", "game_started")

func add_player(id):
	var player = player_scene.instance()
	var thecol
	player.name = str(id)
	if colnum ==1:
		thecol = "ff0000"
	elif colnum ==2:
		thecol = "4632ff"
	elif colnum ==3:
		thecol = "34e533"
	elif colnum ==4:
		thecol = "fff00c"
	player.modulate = thecol
	
	colnum += 1
	if get_node(spawn_path).has_method("get_position"):
		player.position = spawn_position + Vector2((randi() % 20) + 10, 0)
	connect("game_started", player.get_node("player_controller"), "_on_update_for_new_player")
	connect("server_ended", player.get_node("player_controller"), "_on_server_disconnected")
	get_node(spawn_path).call_deferred("add_child", player)
	if get_node(spawn_path).get_child_count() >= 2:
		call_deferred("emit_signal", "update_for_new_player")
	emit_signal("player_spawned", id)

func remove_all_players():
	for id in connected_players.size():
		remove_player(connected_players[id])

func remove_player(id):
	if get_node(spawn_path).get_node_or_null(str(id)):
		get_node(spawn_path).get_node(str(id)).queue_free()

#SYNC FUNCTIONS
export(Array, NodePath) var Nodes
export(Array, String) var functions

#FUNCTIONS SYNC
func func_and_sync(function_name, v1=null, v2=null, v3=null, v4=null, v5=null, v6=null, v7=null, v8=null):
	if get_parent().is_network_master():
		rpc("function", function_name, v1, v2, v3, v4, v5, v6, v7, v8)

sync func function(function_name, v1=null, v2=null, v3=null, v4=null, v5=null, v6=null, v7=null, v8=null):
	var array = []
	for i in [v1, v2, v3, v4, v5, v6, v7, v8]:
		if i != null:
			array.append(i)
	for i in functions.size():
		if functions[i] == function_name:
			get_node(Nodes[i]).callv(function_name, array)

#LEADERBOARD
func show_leaderboard(yes):
	if yes:
		$leaderboard.show()
	else:
		$leaderboard.hide()

func add_room_player(id):
	var room_player = preload("res://addons/lan_multiplayer/scenes/room_player.tscn").instance()
	room_player.name = str(id)
	connect("game_started", room_player.get_node("player_controller"), "_on_update_for_new_player")
	connect("server_ended", room_player.get_node("player_controller"), "_on_server_disconnected")
	$leaderboard/room.add_child(room_player)

func remove_all_room_players():
	for i in connected_players.size():
		remove_room_player(connected_players[i])

func remove_room_player(id):
	if $leaderboard/room.get_node_or_null(str(id)):
		$leaderboard/room.get_node(str(id)).queue_free()
