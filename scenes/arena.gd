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

func _ready() -> void:
	rng.randomize()

func get_local_human_team_net_id():
	for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
		if team.peer_id == multiplayer.get_unique_id() and team.type == "human":
			return team.net_id
	return null

func _process(_delta: float) -> void:
	# Transition from STARTING to PLAYING once teams are spawned
	if state == State.STARTING:
		var teams = NodeUtils.get_nodes_in_group_for_node(self, "Team")
		if teams.size() >= 2:
			var non_inverted_team = null
			var inverted_team = null
			for team in teams:
				if team.inverted:
					inverted_team = team
				else:
					non_inverted_team = team

			if non_inverted_team != null and inverted_team != null:
				$UI.init(non_inverted_team, inverted_team)
				state = State.PLAYING

	if Input.is_action_just_pressed("leave"):
		emit_signal("leave_requested")

	if state == State.PLAYING and Input.is_action_just_pressed("building"):
		var team_net_id = get_local_human_team_net_id()
		if team_net_id != null:
			if multiplayer.is_server():
				construct_building_for_team(team_net_id)
			else:
				request_construct_building.rpc_id(1, team_net_id)
		else:
			print("WARN - no local human team found for building action")

	if state == State.PLAYING and Input.is_action_just_pressed("unit"):
		var team_net_id = get_local_human_team_net_id()
		if team_net_id != null:
			if multiplayer.is_server():
				produce_unit_for_team(team_net_id)
			else:
				request_produce_unit.rpc_id(1, team_net_id)
		else:
			print("WARN - no local human team found for unit action")

	if state == State.PLAYING and Input.is_action_just_pressed("target"):
		var team_net_id = get_local_human_team_net_id()
		if team_net_id != null:
			if multiplayer.is_server():
				target_for_team(team_net_id)
			else:
				request_target.rpc_id(1, team_net_id)
		else:
			print("WARN - no local human team found for target action")

	var liters := 0
	for water in NodeUtils.get_nodes_in_group_for_node(self, "Water"):
		liters += water.liters

	if state == State.PLAYING and multiplayer.is_server() and liters == 0:
		var most_clicks := -1
		var winner_net_ids := []

		for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
			if team.clicks > most_clicks:
				most_clicks = team.clicks
				winner_net_ids = [team.net_id]
			elif team.clicks == most_clicks:
				winner_net_ids.append(team.net_id)

		if DisplayServer.get_name() == "headless":
			announce_game_over.rpc_id(1, winner_net_ids)
		for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
			announce_game_over.rpc_id(team.peer_id, winner_net_ids)
 
	if state == State.GAME_OVER and multiplayer.is_server():
		# yes, this blows everything up all the time, if state is GAME_OVER, this is on purpose
		blow_everything_up()

func create_team(type, peer_id, net_id):
	var num_teams = len(NodeUtils.get_nodes_in_group_for_node(self, "Team"))

	var team = load("res://scenes/team.tscn").instantiate()
	var inverted = false
	if num_teams % 2 == 1:
		inverted = true
	team.init(net_id, peer_id, type, inverted)
	print("Adding team")
	$Replicated.add_child(team, true)

@rpc("call_local", "reliable")
func announce_start_game(random_seed, proto_teams):
	print("announce_start_game for peer id: ", multiplayer.get_unique_id())
	$Map.init(random_seed)
	state = State.STARTING

	if multiplayer.is_server():
		for proto_team in proto_teams:
			create_team(proto_team["type"], proto_team["peer_id"], proto_team["net_id"])
		$Landmarks.init(random_seed, $Map, $Replicated)

	# UI will be initialized when teams are ready (see _process)
	# On server, teams exist immediately; on clients, they're replicated by MultiplayerSpawner

@rpc("call_local", "reliable")
func announce_game_over(winner_net_ids):
	print("announce_game_over")
	state = State.GAME_OVER
	var local_team_net_id = get_local_human_team_net_id()
	var won = local_team_net_id != null and winner_net_ids.has(local_team_net_id)
	$UI.show_game_over(won)

func blow_everything_up():
	for unit in NodeUtils.get_nodes_in_group_for_node(self, "Unit"):
		var explosion = load("res://scenes/explosion.tscn").instantiate()
		explosion.init(get_node("/root/App").get_new_net_id(), unit.global_position)
		$Replicated.add_child(explosion, true)
		unit.queue_free()

	for building in NodeUtils.get_nodes_in_group_for_node(self, "Building"):
		var site = load("res://scenes/site.tscn").instantiate()
		site.init(get_node("/root/App").get_new_net_id(), building.water_net_id, building.global_position)
		$Replicated.add_child(site, true)

		for i in 10:
			var explosion = load("res://scenes/explosion.tscn").instantiate()
			var pos = building.global_position + Vector2(
				randf_range(-24.0, 24.0),
				randf_range(-24.0, 24.0)
			)
			explosion.init(get_node("/root/App").get_new_net_id(), pos)
			$Replicated.add_child(explosion, true)

		building.queue_free()

@rpc("any_peer", "reliable")
func request_construct_building(team_net_id):
	if not multiplayer.is_server():
		return

	construct_building_for_team(team_net_id)

func construct_building_for_team(team_net_id):
	var team = get_node("/root/App").get_node_for_net_id(team_net_id)

	if team == null:
		print("ERROR - no team for net_id: ", team_net_id)
		return

	for site in NodeUtils.get_nodes_in_group_for_node(self, "Site"):
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		data_center.init(get_node("/root/App").get_new_net_id(), team.net_id, site.water_net_id, site.global_position)
		$Replicated.add_child(data_center, true)
		site.queue_free()
		break

@rpc("any_peer", "reliable")
func request_produce_unit(team_net_id):
	if not multiplayer.is_server():
		return

	produce_unit_for_team(team_net_id)

func produce_unit_for_team(team_net_id):
	var team = get_node("/root/App").get_node_for_net_id(team_net_id)

	if team == null:
		print("ERROR - no team for net_id: ", team_net_id)
		return

	for data_center in NodeUtils.get_nodes_in_group_for_node(self, "DataCenter"):
		if team != get_node("/root/App").get_node_for_net_id(data_center.team_net_id):
			continue
		if data_center.producing != "":
			continue
		data_center.produce_unit("spam_bot")
		break

@rpc("any_peer", "reliable")
func request_target(team_net_id):
	if not multiplayer.is_server():
		return

	target_for_team(team_net_id)

func target_for_team(team_net_id):
	var team = get_node("/root/App").get_node_for_net_id(team_net_id)

	if team == null:
		print("ERROR - no team for net_id: ", team_net_id)
		return

	for spam_bot in NodeUtils.get_nodes_in_group_for_node(self, "SpamBot"):
		if team != get_node("/root/App").get_node_for_net_id(spam_bot.team_net_id):
			continue
		if spam_bot.target_net_id != -1 or spam_bot.target_position != Vector2.ZERO:
			continue

		var transmission_towers = NodeUtils.get_nodes_in_group_for_node(self, "TransmissionTower")
		var transmission_tower = transmission_towers.pick_random()
		if transmission_tower == null:
			return

		spam_bot.target_net_id = transmission_tower.net_id
		break
