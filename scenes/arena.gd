extends Node2D

var rng := RandomNumberGenerator.new()

enum State {
	PLAYING,
	GAME_OVER
}

var state := State.PLAYING

func _ready() -> void:
	rng.randomize()

func _process(_delta: float) -> void:
	if state == State.PLAYING and Input.is_action_just_pressed("building"):
		if multiplayer.is_server():
			construct_building_for_peer(multiplayer.get_unique_id())
		else:
			request_construct_building.rpc_id(1)

	if state == State.PLAYING and Input.is_action_just_pressed("unit"):
		if multiplayer.is_server():
			produce_unit_for_peer(multiplayer.get_unique_id())
		else:
			request_produce_unit.rpc_id(1)

	if state == State.PLAYING and Input.is_action_just_pressed("target"):
		if multiplayer.is_server():
			target_for_peer(multiplayer.get_unique_id())
		else:
			request_target.rpc_id(1)

	var liters := 0
	for water in get_tree().get_nodes_in_group("Water"):
		liters += water.liters

	if state == State.PLAYING and multiplayer.is_server() and liters == 0:
		var most_clicks := -1
		var winner_ids := []

		for team in get_tree().get_nodes_in_group("Team"):
			if team.clicks > most_clicks:
				most_clicks = team.clicks
				winner_ids = [team.id]
			elif team.clicks == most_clicks:
				winner_ids.append(team.id)

		rpc("announce_game_over", winner_ids)

	if state == State.GAME_OVER and multiplayer.is_server():
		blow_everything_up()

@rpc("call_local", "reliable")
func announce_team(type: String, id: int) -> void:
	for child in get_children():
		if child.has_method("get") and child.get("id") == id:
			return

	var num_teams = len(get_tree().get_nodes_in_group("Team"))

	var team = load("res://scenes/team.tscn").instantiate()
	team.type = type
	team.id = id
	if num_teams % 2 == 1:
		team.inverted = true
	add_child(team)

@rpc("call_local", "reliable")
func announce_play_game(seed: int) -> void:
	print("announce_play_game")
	$Map.init(seed)
	state = State.PLAYING

	if multiplayer.is_server():
		$Landmarks.init(seed, $Map, $Replicated)

	var non_inverted_team = null
	var inverted_team = null
	for team in get_tree().get_nodes_in_group("Team"):
		if team.inverted:
			inverted_team = team
		else:
			non_inverted_team = team

	if non_inverted_team == null or inverted_team == null:
		print("ERROR - somehow we don't have two teams")

	$UI.init(non_inverted_team, inverted_team)

@rpc("call_local", "reliable")
func announce_game_over(winner_ids) -> void:
	print("announce_game_over")
	state = State.GAME_OVER
	var won = winner_ids.has(multiplayer.get_unique_id())
	$UI.show_game_over(won)

func blow_everything_up() -> void:
	for unit in get_tree().get_nodes_in_group("Unit"):
		var explosion = load("res://scenes/explosion.tscn").instantiate()
		explosion.global_position = unit.global_position
		$Replicated.add_child(explosion, true)
		unit.queue_free()

	for building in get_tree().get_nodes_in_group("Building"):
		var site = load("res://scenes/site.tscn").instantiate()
		site.water_path = building.water_path
		site.global_position = building.global_position
		$Replicated.add_child(site, true)

		for i in 10:
			var explosion = load("res://scenes/explosion.tscn").instantiate()
			explosion.global_position = building.global_position + Vector2(
				randf_range(-24.0, 24.0),
				randf_range(-24.0, 24.0)
			)
			$Replicated.add_child(explosion, true)

		building.queue_free()

@rpc("any_peer", "reliable")
func request_construct_building() -> void:
	if not multiplayer.is_server():
		return

	construct_building_for_peer(multiplayer.get_remote_sender_id())

func construct_building_for_peer(peer_id: int) -> void:
	var team = null
	for candidate in get_tree().get_nodes_in_group("Team"):
		if candidate.id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for site in get_tree().get_nodes_in_group("Site"):
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		data_center.init(team.get_path(), site.global_position, site.water_path)
		$Replicated.add_child(data_center, true)
		site.queue_free()
		break

@rpc("any_peer", "reliable")
func request_produce_unit() -> void:
	if not multiplayer.is_server():
		return

	produce_unit_for_peer(multiplayer.get_remote_sender_id())

func produce_unit_for_peer(peer_id: int) -> void:
	var team = null
	for candidate in get_tree().get_nodes_in_group("Team"):
		if candidate.id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for data_center in get_tree().get_nodes_in_group("DataCenter"):
		if team != get_node(data_center.team_path):
			continue
		if data_center.producing != "":
			continue
		data_center.produce_unit("spam_bot")
		break

@rpc("any_peer", "reliable")
func request_target() -> void:
	if not multiplayer.is_server():
		return

	target_for_peer(multiplayer.get_remote_sender_id())

func target_for_peer(peer_id: int) -> void:
	var team = null
	for candidate in get_tree().get_nodes_in_group("Team"):
		if candidate.id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for spam_bot in get_tree().get_nodes_in_group("SpamBot"):
		if team != get_node(spam_bot.team_path):
			continue
		if spam_bot.target != null:
			continue

		var transmission_towers = get_tree().get_nodes_in_group("TransmissionTower")
		var transmission_tower = transmission_towers.pick_random()
		if transmission_tower == null:
			return

		spam_bot.target = transmission_tower
		break
