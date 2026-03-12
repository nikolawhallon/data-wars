extends Area2D


#var minerals = 2000

func _ready():
	$Label8.text = "inf"
	$Label8.global_position = global_position - $Label8.get_minimum_size() * 0.5

func decrement(amount) -> int:
	var consumed = amount
	#if minerals - amount < 0:
	#	consumed = minerals
	#	minerals = 0
	#else:
	#	minerals = minerals - amount

	$Label8.text = "inf"
	$Label8.global_position = global_position - $Label8.get_minimum_size() * 0.5

	return consumed
