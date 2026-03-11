extends Sprite2D


var rng = RandomNumberGenerator.new()

var team = null
var producing = null

func _ready() -> void:
	rng.randomize()

func spawn_unit(type):
	if producing:
		print("WARN - this Skunk Works is already producing a ", producing)
		return "Unable to build unit: Data Center alreading producing a unit"

	if type != "skunk_drone" and type != "data_drone":
		return "Unable to built unit: Skunk Works can only produce Skunk Drones (skunk_drone) and Data Drones (data_drone)"

	if team == null:
		return "Unable to build unit: this Skunk Works is not associated with a Team!"

	if team.minerals < 50:
		return "Drones require 50 Minerals to build, Team does not have enough Minerals"

	team.minerals -= 50
	team.minerals_updated.emit()

	producing = type
	$UnitTimer.start()
	return "Successfully building unit"

func _on_unit_timer_timeout() -> void:
	if producing == "skunk_drone":
		var skunk_drone = load("res://scenes/skunk_drone.tscn").instantiate()
		skunk_drone.team = team
		skunk_drone.global_position = global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0))
		get_tree().get_current_scene().add_child(skunk_drone)
	elif producing == "data_drone":
		var data_drone = load("res://scenes/data_drone.tscn").instantiate()
		data_drone.team = team
		data_drone.global_position = global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0))
		get_tree().get_current_scene().add_child(data_drone)
		
	producing = null
