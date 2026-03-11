extends Area2D


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

func _on_water_timer_timeout() -> void:
	var water = get_parent()
	var consumed = water.decrement(1)
	team.data += consumed
	team.data_updated.emit()

func _on_unit_timer_timeout() -> void:
	if producing == "spam_bot":
		var spam_bot = load("res://scenes/spam_bot.tscn").instantiate()
		spam_bot.init(team, global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0)))
		get_tree().get_current_scene().add_child(spam_bot)

	producing = null

func spawn_unit(type):
	if producing:
		print("WARN - this Data Center is already producing a ", producing)
		return "Unable to build unit: Data Center alreading producing a unit"

	if type != "spam_bot":
		return "Unable to build unit: Data Centers can only produce Spam Bots (spam_bot)"

	if team.data < 20:
		return "Spam Bots require 20 Data to build, Team does not have enough Data"

	team.data -= 20
	team.data_updated.emit()

	producing = type
	$UnitTimer.start()
	return "Successfully started building unit"
