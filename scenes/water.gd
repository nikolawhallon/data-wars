extends AnimatedSprite2D


var liters = 800

func _ready():
	$Label8.text = str(liters)
	$Label8.global_position = global_position - $Label8.get_minimum_size() * 0.5

func decrement(amount) -> int:
	var consumed = amount
	if liters - amount < 0:
		consumed = liters
		liters = 0
	else:
		liters = liters - amount
		if liters == 0:
			frame = 3
		elif liters < 200:
			frame = 2
		elif liters < 400:
			frame = 1

	$Label8.text = str(liters)
	$Label8.global_position = global_position - $Label8.get_minimum_size() * 0.5

	return consumed
