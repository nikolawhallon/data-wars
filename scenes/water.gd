extends AnimatedSprite2D


signal liters_updated

@export var net_id = -1
@export var liters: int = 600:
	set(value):
		liters = max(value, 0)
		liters_updated.emit(liters)

func init(initial_net_id, initial_global_position):
	net_id = initial_net_id
	global_position = initial_global_position

func _ready():
	var app = get_node("/root/App")
	app.register_net_node(net_id, self)

func decrement(amount):
	var consumed = min(liters, amount)
	liters -= consumed

	if liters == 0:
		frame = 3
	elif liters < 200:
		frame = 2
	elif liters < 400:
		frame = 1
			
	return consumed
