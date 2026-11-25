extends AnimatedSprite2D


var rng = RandomNumberGenerator.new()

@export var team_path: NodePath
@export var producing := "":
	set(value):
		if producing == value:
			return
		producing = value
		update_animation()
@export var water_path: NodePath

func init(initial_team_path, initial_water_path, initial_position):
	team_path = initial_team_path
	water_path = initial_water_path
	global_position = initial_position

func _ready() -> void:
	rng.randomize()

	update_animation()
	apply_team_palette()

func apply_team_palette():
	var team = get_node(team_path)

	if not team.inverted:
		return

	material = material.duplicate()
	var mat := material as ShaderMaterial
	mat.set_shader_parameter("pal0", Color("#edb4a1"))
	mat.set_shader_parameter("pal1", Color("#a96868"))
	mat.set_shader_parameter("pal2", Color("#764462"))
	mat.set_shader_parameter("pal3", Color("#2c2137"))

func update_animation() -> void:
	if producing == "":
		play("default")
	else:
		play("producing")

func _on_water_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	var water = get_node(water_path)
	var _consumed = water.decrement(1)

func _on_unit_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	if producing == "skunk_drone":
		var skunk_drone = load("res://scenes/skunk_drone.tscn").instantiate()
		skunk_drone.init(team_path, global_position + Vector2(
			rng.randf_range(-64.0, 64.0),
			rng.randf_range(-64.0, 64.0)
		))
		get_parent().add_child(skunk_drone, true)
	elif producing == "data_drone":
		var data_drone = load("res://scenes/data_drone.tscn").instantiate()
		data_drone.init(team_path, global_position + Vector2(
			rng.randf_range(-64.0, 64.0),
			rng.randf_range(-64.0, 64.0)
		))
		get_parent().add_child(data_drone, true)

	producing = ""

func produce_unit(type):
	if not multiplayer.is_server():
		return "Server only"

	if producing:
		print("WARN - this Skunk Works is already producing a unit: ", producing)
		return "Unable to build unit: Skunk Works already producing a unit"
	if type != "skunk_drone" and type != "data_drone":
		return "Unable to build unit: Skunk Works can only produce Skunk Drones (skunk_drone) and Data Drones (data_drone)"

	var team = get_node(team_path)
	var arena = NodeUtils.get_first_ancestor_in_group_for_node(self, "Arena")
	var cost = 100 + arena.get_unit_mineral_tax(team_path, "SkunkWorks")

	if team.minerals < cost:
		return "Drones require %d Minerals including the Mineral tax, Team does not have enough Minerals" % cost

	team.minerals -= cost
	producing = type
	$UnitTimer.start()

	return "Successfully started building unit"
