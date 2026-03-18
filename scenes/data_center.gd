extends Area2D


var rng = RandomNumberGenerator.new()

@export var team_path: NodePath
@export var producing: String
@export var water_path: NodePath

func _ready() -> void:
	rng.randomize()

func init(initial_team_path, initial_position, initial_water_path):
	team_path = initial_team_path
	global_position = initial_position
	water_path = initial_water_path

func _on_water_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	var water = get_node(water_path)
	var team = get_node(team_path)

	var consumed = water.decrement(1)
	if consumed <= 0:
		return

	print("adding " + str(consumed) + " data to some team")
	team.data += consumed

func _on_unit_timer_timeout() -> void:
	pass

func produce_unit(type):
	pass
