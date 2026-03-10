extends Sprite2D


var team = null
var producing = null

func spawn_unit(type):
	if producing:
		print("WARN - this Skunk Works is already producing a ", producing)
		return

	producing = type
	$UnitTimer.start()

func _on_unit_timer_timeout() -> void:
	if producing == "skunk_drone":
		var skunk_drone = load("res://scenes/skunk_drone.tscn").instantiate()
		skunk_drone.team = team
		skunk_drone.global_position = global_position
		skunk_drone.target = get_tree().get_current_scene().get_node("CellLabels").cell_label_to_pos("B2")
		get_tree().get_current_scene().add_child(skunk_drone)
	elif producing == "data_drone":
		var data_drone = load("res://scenes/data_drone.tscn").instantiate()
		data_drone.team = team
		data_drone.global_position = global_position
		data_drone.target = get_tree().get_current_scene().get_node("CellLabels").cell_label_to_pos("C3")
		get_tree().get_current_scene().add_child(data_drone)
		
	producing = null
