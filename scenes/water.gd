extends Sprite2D


var liters = 2000

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

	$Label8.text = str(liters)
	$Label8.global_position = global_position - $Label8.get_minimum_size() * 0.5

	return consumed
