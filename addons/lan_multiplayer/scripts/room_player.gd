extends Label

var playername = "player"
var namepath = "user://name.dat"
var hostnamepath = "user://hostname.dat"

func _ready():
	var rooms = get_parent().get_children()
	for rom in rooms:
		if rom.is_network_master():
			if rom.has_method("changename"):
				rom.changename()
	
func changename():
	playername = global.nameo
	rpc("cname", playername)

sync func cname(nameo):
	playername = nameo
	text = nameo
