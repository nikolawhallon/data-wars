extends Sprite2D


signal data_generated

var team = null
var producing = null

func _on_water_timer_timeout() -> void:
	var water = get_parent()
	var consumed = water.decrement(1)
	data_generated.emit(team, consumed)
	# TODO: have a reference to a Team here
	# and increase the Team's data by "consumed" amount

func _on_unit_timer_timeout() -> void:
	if producing == "spam_bot":
		var spam_bot = load("res://scenes/spam_bot.tscn").instantiate()
		spam_bot.team = team
		spam_bot.global_position = global_position
		spam_bot.target = get_tree().get_current_scene().get_node("CellLabels").cell_label_to_pos("A1")
		get_tree().get_current_scene().add_child(spam_bot)

	producing = null

func spawn_unit(type):
	if producing:
		print("WARN - this Data Center is already producing a ", producing)
		return

	producing = type
	$UnitTimer.start()
