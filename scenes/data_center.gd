extends Sprite2D


func _on_timer_timeout() -> void:
	var water = get_parent()
	var consumed = water.decrement(1)
	# TODO: have a reference to a Team here
	# and increase the Team's data by "consumed" amount
