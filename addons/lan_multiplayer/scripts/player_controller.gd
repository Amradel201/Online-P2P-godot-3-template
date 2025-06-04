extends Node

#Functions for you: func_and_sync()

export(NodePath) var camera_path

export(Array, NodePath) var nodes
export(Array, String) var properties
export(Array, bool) var sync_once

export(Array, NodePath) var Nodes
export(Array, String) var functions

#AUTHORITY AND CONNECTION CONTROL
func _enter_tree():
	get_parent().set_network_master(get_parent().name.to_int())

func _ready():
	set_process(false)
	
	if not get_parent().is_network_master():
		for i in Nodes.size():
			if get_node(Nodes[i]).has_method("_process"):
				get_node(Nodes[i]).call_deferred("set_process", false)
			if get_node(Nodes[i]).has_method("_physics_process"):
				get_node(Nodes[i]).call_deferred("set_physics_process", false)
		for i in nodes.size():
			if get_node(nodes[i]).has_method("_process"):
				get_node(nodes[i]).call_deferred("set_process", false)
			if get_node(nodes[i]).has_method("_physics_process"):
				get_node(nodes[i]).call_deferred("set_physics_process", false)
		if get_node_or_null(camera_path):
			get_node_or_null(camera_path).queue_free()

func _on_update_for_new_player():
	synchronize_once()
	set_process(true)

func _on_server_disconnected():
	set_process(false)

#PROPERTIES SYNC
func synchronize_once():
	if get_parent().is_network_master():
		for i in nodes.size():
			if sync_once[i] == true:
				rpc("reliable", nodes[i], properties[i], get_node(nodes[i])[properties[i]])

func _process(_delta):
	if get_parent().is_network_master():
		for i in nodes.size():
			if sync_once[i] == false:
				rpc("unreliable", nodes[i], properties[i], get_node(nodes[i])[properties[i]])

remote func reliable(node_path, property, value):
	get_node(node_path)[property] = value

remote func unreliable(node_path, property, value):
	get_node(node_path)[property] = value

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
