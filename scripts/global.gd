extends Node

var connected_players = []
var nameo = ""
var upnp = UPNP.new()
var port = 6777
var aes = AESContext.new()
var opened = false
# Declare member variables here. Examples:
# var a = 2
# var b =
func enupnp():
	upnp = UPNP.new()
	var err = upnp.discover()
	if err != OK:
		
		return "can't find valid device"
	
	if upnp.get_gateway() and upnp.get_gateway().is_valid_gateway():
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "UDP")
		upnp.add_port_mapping(port, port, ProjectSettings.get_setting("application/config/name"), "TCP")
		
		var key = "ThereIsNoKeyHere"
		var data = upnp.query_external_address()
		print(data)
		while data.length() <16:
			data+= " "
		aes.start(AESContext.MODE_ECB_ENCRYPT, key.to_utf8())
		var encrypted = aes.update(data.to_utf8())
		aes.finish()
		var hex = encrypted.hex_encode()
		opened = true
		return hex
	else:
		return "can't find a valid gateaway"

# Called when the node enters the scene tree for the first time.
func _ready():
	pass

func _exit_tree():
	delmapping()

func delmapping():
	
	if opened:
		upnp.delete_port_mapping(port,"UDP")
		upnp.delete_port_mapping(port,"TCP")
		print("del from global")
		opened = false
	pass
# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta):
#	pass
