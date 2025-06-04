extends KinematicBody2D

var speed = 300


func _ready():
	set_network_master(name.to_int())
	if is_network_master():
		yield(get_tree().create_timer(0.2),"timeout")
		rpc("update_name",global.nameo)
sync func update_name(nameo):
	$Label.text = nameo

func _process(delta):
	if is_network_master():
		var input = Input.get_vector("ui_left","ui_right","ui_up","ui_down")
		move_and_slide(input*speed ,Vector2.ZERO)
		rpc_unreliable("update_position",global_position)
		

sync func update_position(pos):
	global_position = pos
