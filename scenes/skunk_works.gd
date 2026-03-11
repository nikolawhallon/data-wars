extends Sprite2D


var rng = RandomNumberGenerator.new()

var team = null
var producing = null

func _ready() -> void:
	rng.randomize()

func init(initial_team, initial_position):
	global_position = initial_position
	team = initial_team
	
	$Sprite2D.material = $Sprite2D.material.duplicate()
	var mat := $Sprite2D.material as ShaderMaterial

	if team.team == "player":
		mat.set_shader_parameter("pal0", Color("#2c2137"))
		mat.set_shader_parameter("pal1", Color("#764462"))
		mat.set_shader_parameter("pal2", Color("#a96868"))
		mat.set_shader_parameter("pal3", Color("#edb4a1"))

	if team.team == "enemy":
		mat.set_shader_parameter("pal0", Color("#edb4a1"))
		mat.set_shader_parameter("pal1", Color("#a96868"))
		mat.set_shader_parameter("pal2", Color("#764462"))
		mat.set_shader_parameter("pal3", Color("#2c2137"))

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
		skunk_drone.init(team, global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0)))
		get_tree().get_current_scene().add_child(skunk_drone)
	elif producing == "data_drone":
		var data_drone = load("res://scenes/data_drone.tscn").instantiate()
		data_drone.init(team, global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0)))
		get_tree().get_current_scene().add_child(data_drone)
		
	producing = null
