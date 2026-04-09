extends Node2D

signal leave_requested

var rng := RandomNumberGenerator.new()

var match_id = null

enum State {
	VOID,
	STARTING,
	PLAYING,
	GAME_OVER
}

var state := State.VOID

func get_local_human_team():
	for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
		if team.peer_id == multiplayer.get_unique_id() and team.type == "human":
			return team
	return null
	
func _ready() -> void:
	rng.randomize()

func _process(delta: float) -> void:
	if state == State.STARTING:
		var teams = NodeUtils.get_nodes_in_group_for_node(self, "Team")
		if len(teams) == 2:
			$UI.connect_signals(teams)
			state = State.PLAYING

	if Input.is_action_just_pressed("leave"):
		emit_signal("leave_requested")

	if state == State.PLAYING:
		var speed = 1000.0
		var dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		$Camera2D.global_position += dir * speed * delta

	if state == State.PLAYING and Input.is_action_just_pressed("building"):
		var team = get_local_human_team()
		if team:
			if multiplayer.is_server():
				construct_building_for_team(team.get_path())
			else:
				request_construct_building.rpc_id(1, team.get_path())

	if state == State.PLAYING and Input.is_action_just_pressed("unit"):
		var team = get_local_human_team()
		if team:
			if multiplayer.is_server():
				produce_unit_for_team(team.get_path())
			else:
				request_produce_unit.rpc_id(1, team.get_path())

	if state == State.PLAYING and Input.is_action_just_pressed("target"):
		var team = get_local_human_team()
		if team:
			if multiplayer.is_server():
				target_for_team(team.get_path())
			else:
				request_target.rpc_id(1, team.get_path())

	var liters := 0
	for water in NodeUtils.get_nodes_in_group_for_node(self, "Water"):
		liters += water.liters

	if state == State.PLAYING and multiplayer.is_server() and liters == 0:
		var most_clicks := -1
		var winner_team_paths := []

		for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
			if team.clicks > most_clicks:
				most_clicks = team.clicks
				winner_team_paths = [team.get_path()]
			elif team.clicks == most_clicks:
				winner_team_paths.append(team.get_path())

		for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
			if team.peer_id == 1:
				continue
			announce_game_over.rpc_id(team.peer_id, winner_team_paths)

		announce_game_over(winner_team_paths)
 
	if state == State.GAME_OVER and multiplayer.is_server():
		# yes, this blows everything up all the time, if state is GAME_OVER, this is on purpose
		blow_everything_up()

@rpc("any_peer", "reliable")
func announce_start_game(random_seed, proto_teams):
	state = State.STARTING
	print("announce_start_game for peer id: ", multiplayer.get_unique_id())
	$Map.init(random_seed)

	if multiplayer.is_server():
		assert(len(proto_teams) == 2)

		var non_inverted_team = load("res://scenes/team.tscn").instantiate()
		non_inverted_team.init(proto_teams[0]["peer_id"], proto_teams[0]["type"], false)
		$Replicated.add_child(non_inverted_team, true)
		var inverted_team = load("res://scenes/team.tscn").instantiate()
		inverted_team.init(proto_teams[1]["peer_id"], proto_teams[1]["type"], true)
		$Replicated.add_child(inverted_team, true)

		$Landmarks.init(random_seed, $Map, $Replicated)

@rpc("any_peer", "reliable")
func announce_game_over(winner_team_paths):
	print("announce_game_over")
	state = State.GAME_OVER
	var local_team = get_local_human_team()
	var won = local_team != null and winner_team_paths.has(local_team.get_path())
	$UI.show_game_over(won)

func blow_everything_up():
	assert(multiplayer.is_server())
	for unit in NodeUtils.get_nodes_in_group_for_node(self, "Unit"):
		var explosion = load("res://scenes/explosion.tscn").instantiate()
		explosion.init(unit.global_position)
		$Replicated.add_child(explosion, true)
		unit.queue_free()

	for building in NodeUtils.get_nodes_in_group_for_node(self, "Building"):
		var site = load("res://scenes/site.tscn").instantiate()
		site.init(building.water_path, building.global_position)
		$Replicated.add_child(site, true)

		for i in 8:
			var explosion = load("res://scenes/explosion.tscn").instantiate()
			var pos = building.global_position + Vector2(
				randf_range(-24.0, 24.0),
				randf_range(-24.0, 24.0)
			)
			explosion.init(pos)
			$Replicated.add_child(explosion, true)

		building.queue_free()

@rpc("any_peer", "reliable")
func request_construct_building(team_path):
	if not multiplayer.is_server():
		return

	construct_building_for_team(team_path)

func construct_building_for_team(team_path):
	assert(multiplayer.is_server())
	for site in NodeUtils.get_nodes_in_group_for_node(self, "Site"):
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		data_center.init(team_path, site.water_path, site.global_position)
		$Replicated.add_child(data_center, true)
		site.queue_free()
		break

@rpc("any_peer", "reliable")
func request_produce_unit(team_path):
	if not multiplayer.is_server():
		return

	produce_unit_for_team(team_path)

func produce_unit_for_team(team_path):
	assert(multiplayer.is_server())
	for data_center in NodeUtils.get_nodes_in_group_for_node(self, "DataCenter"):
		if data_center.team_path != team_path:
			continue
		if data_center.producing != "":
			continue
		data_center.produce_unit("spam_bot")
		break

@rpc("any_peer", "reliable")
func request_target(team_path):
	if not multiplayer.is_server():
		return

	target_for_team(team_path)

func target_for_team(team_path):
	assert(multiplayer.is_server())
	for spam_bot in NodeUtils.get_nodes_in_group_for_node(self, "SpamBot"):
		if spam_bot.team_path != team_path:
			continue
		if spam_bot.target_path != NodePath() or spam_bot.target_position != Vector2.ZERO:
			continue

		var transmission_towers = NodeUtils.get_nodes_in_group_for_node(self, "TransmissionTower")
		var transmission_tower = transmission_towers.pick_random()
		if transmission_tower == null:
			return

		spam_bot.target_path = transmission_tower.get_path()
		break
