extends AnimatedSprite2D


signal liters_updated

@export var liters: int = 600:
	set(value):
		liters = max(value, 0)
		liters_updated.emit(liters)

func init(initial_global_position):
	global_position = initial_global_position

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
