extends Node2D

signal leave_requested

var rng := RandomNumberGenerator.new()

var match_id = null

enum State {
	PLAYING,
	GAME_OVER
}

var state := State.PLAYING

# TODO: extract this into some utils
func find_in_subtree(group_name):
	var out = []
	var stack = [self]

	while not stack.is_empty():
		var node: Node = stack.pop_back()
		for child in node.get_children():
			if child.is_in_group(group_name):
				out.append(child)
			stack.append(child)

	return out

func _ready() -> void:
	rng.randomize()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("leave"):
		emit_signal("leave_requested")

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
	for water in find_in_subtree("Water"):
		liters += water.liters

	if state == State.PLAYING and multiplayer.is_server() and liters == 0 and false:
		var most_clicks := -1
		var winner_ids := []

		for team in find_in_subtree("Team"):
			if team.clicks > most_clicks:
				most_clicks = team.clicks
				winner_ids = [team.peer_id]
			elif team.clicks == most_clicks:
				winner_ids.append(team.peer_id)

		if DisplayServer.get_name() == "headless":
			announce_game_over.rpc_id(1, winner_ids)
		for team in find_in_subtree("Team"):
			announce_game_over.rpc_id(team.peer_id, winner_ids)
 
	if state == State.GAME_OVER and multiplayer.is_server():
		# yes, this blows everything up all the time, if state is GAME_OVER, this is on purpose
		blow_everything_up()

@rpc("call_local", "reliable")
func announce_team(type, id):
	for child in get_children():
		if child.has_method("get") and child.get("id") == id:
			return

	var num_teams = len(find_in_subtree("Team"))

	var team = load("res://scenes/team.tscn").instantiate()
	var inverted = false
	if num_teams % 2 == 1:
		inverted = true
	team.init(type, id, inverted)
	print("Adding team")
	add_child(team, true)

@rpc("call_local", "reliable")
func announce_play_game(random_seed):
	print("announce_play_game for peer id: ", multiplayer.get_unique_id())
	$Map.init(random_seed)
	state = State.PLAYING

	if multiplayer.is_server():
		$Landmarks.init(random_seed, $Map, $Replicated)

	var non_inverted_team = null
	var inverted_team = null
	for team in find_in_subtree("Team"):
		if team.inverted:
			inverted_team = team
		else:
			non_inverted_team = team

	if non_inverted_team == null or inverted_team == null:
		print("ERROR - somehow we don't have two teams")

	$UI.init(non_inverted_team, inverted_team)

@rpc("call_local", "reliable")
func announce_game_over(winner_ids):
	print("announce_game_over")
	state = State.GAME_OVER
	var won = winner_ids.has(multiplayer.get_unique_id())
	$UI.show_game_over(won)

func blow_everything_up():
	for unit in find_in_subtree("Unit"):
		var explosion = load("res://scenes/explosion.tscn").instantiate()
		explosion.init(unit.global_position)
		$Replicated.add_child(explosion, true)
		unit.queue_free()

	for building in find_in_subtree("Building"):
		var site = load("res://scenes/site.tscn").instantiate()
		site.water_path = building.water_path
		site.global_position = building.global_position
		$Replicated.add_child(site, true)

		for i in 10:
			var explosion = load("res://scenes/explosion.tscn").instantiate()
			var pos = building.global_position + Vector2(
				randf_range(-24.0, 24.0),
				randf_range(-24.0, 24.0)
			)
			explosion.init(pos)
			$Replicated.add_child(explosion, true)

		building.queue_free()

@rpc("any_peer", "reliable")
func request_construct_building():
	if not multiplayer.is_server():
		return

	construct_building_for_peer(multiplayer.get_remote_sender_id())

func construct_building_for_peer(peer_id):
	var team = null
	for candidate in find_in_subtree("Team"):
		if candidate.peer_id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for site in find_in_subtree("Site"):
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		data_center.init(team.get_path(), site.global_position, site.water_path)
		$Replicated.add_child(data_center, true)
		site.queue_free()
		break

@rpc("any_peer", "reliable")
func request_produce_unit():
	if not multiplayer.is_server():
		return

	produce_unit_for_peer(multiplayer.get_remote_sender_id())

func produce_unit_for_peer(peer_id):
	var team = null
	for candidate in find_in_subtree("Team"):
		if candidate.peer_id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for data_center in find_in_subtree("DataCenter"):
		if team != get_node(data_center.team_path):
			continue
		if data_center.producing != "":
			continue
		data_center.produce_unit("spam_bot")
		break

@rpc("any_peer", "reliable")
func request_target():
	if not multiplayer.is_server():
		return

	target_for_peer(multiplayer.get_remote_sender_id())

func target_for_peer(peer_id):
	var team = null
	for candidate in find_in_subtree("Team"):
		if candidate.peer_id == peer_id:
			team = candidate
			break

	if team == null:
		print("No team for peer ", peer_id)
		return

	for spam_bot in find_in_subtree("SpamBot"):
		if team != get_node(spam_bot.team_path):
			continue
		if spam_bot.target != null:
			continue

		var transmission_towers = find_in_subtree("TransmissionTower")
		var transmission_tower = transmission_towers.pick_random()
		if transmission_tower == null:
			return

		spam_bot.target = transmission_tower
		break
