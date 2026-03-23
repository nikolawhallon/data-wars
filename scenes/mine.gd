extends Area2D


@export var net_id = -1

func init(initial_net_id, initial_global_position):
	net_id = initial_net_id
	global_position = initial_global_position

func _ready():
	var app = get_node("/root/App")
	app.register_net_node(net_id, self)
