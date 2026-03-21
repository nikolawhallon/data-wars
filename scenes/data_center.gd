extends Area2D


var rng = RandomNumberGenerator.new()

@export var team_path: NodePath
@export var producing := "":
	set(value):
		if producing == value:
			return
		producing = value
		update_animation()
@export var water_path: NodePath

func init(initial_team_path, initial_position, initial_water_path):
	team_path = initial_team_path
	global_position = initial_position
	water_path = initial_water_path

func _ready() -> void:
	rng.randomize()
	update_animation()
	apply_team_palette()

func apply_team_palette():
	if team_path.is_empty():
		return

	var team = get_node_or_null(team_path)
	if team == null:
		return

	if not team.inverted:
		return

	$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()
	var mat := $AnimatedSprite2D.material as ShaderMaterial
	mat.set_shader_parameter("pal0", Color("#edb4a1"))
	mat.set_shader_parameter("pal1", Color("#a96868"))
	mat.set_shader_parameter("pal2", Color("#764462"))
	mat.set_shader_parameter("pal3", Color("#2c2137"))

func update_animation() -> void:
	if producing == "":
		$AnimatedSprite2D.play("default")
	else:
		$AnimatedSprite2D.play("producing")

func _on_water_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	var water = get_node(water_path)
	var team = get_node(team_path)

	var consumed = water.decrement(1)
	if consumed <= 0:
		return

	team.data += consumed

func _on_unit_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	if producing == "spam_bot":
		var spam_bot = load("res://scenes/spam_bot.tscn").instantiate()
		spam_bot.init(team_path, global_position + Vector2(
			rng.randf_range(-64.0, 64.0),
			rng.randf_range(-64.0, 64.0)
		))
		get_parent().add_child(spam_bot, true)

	producing = ""

func produce_unit(type):
	if not multiplayer.is_server():
		return "Server only"

	if producing:
		print("WARN - this Data Center is already producing a unit: ", producing)
		return "Unable to build unit: Data Center alreading producing a unit"
	if type != "spam_bot":
		return "Unable to build unit: Data Centers can only produce Spam Bots (spam_bot)"

	var team = get_node(team_path)

	if team.data < 20:
		return "Spam Bots require 20 Data to build, Team does not have enough Data"

	team.data -= 20
	producing = type
	$UnitTimer.start()
	
	return "Successfully started building unit"
