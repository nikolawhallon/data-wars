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

var zoom := 1

var physics_space := RID()

func get_local_human_team():
	for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
		if team.peer_id == multiplayer.get_unique_id() and team.type == "human":
			return team
	return null

func _ready() -> void:
	rng.randomize()

	if multiplayer.is_server():
		physics_space = PhysicsServer2D.space_create()
		PhysicsServer2D.space_set_active(physics_space, true)
		get_tree().node_added.connect(_on_node_added)

func _exit_tree() -> void:
	get_window().content_scale_factor = 1

	if physics_space.is_valid():
		PhysicsServer2D.free_rid(physics_space)

func _on_node_added(node: Node) -> void:
	if not node is CollisionObject2D or not is_ancestor_of(node):
		return

	if node is Area2D:
		PhysicsServer2D.area_set_space(node.get_rid(), physics_space)
	else:
		PhysicsServer2D.body_set_space(node.get_rid(), physics_space)

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
		$Camera2D.global_position += dir * speed * delta / zoom

	if state == State.PLAYING and Input.is_action_just_pressed("zoom"):
		if zoom == 1:
			zoom = 2
		else:
			zoom = 1
		get_window().content_scale_factor = zoom

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

	if state == State.PLAYING and multiplayer.is_server():
		spawn_missing_extractors()

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

@rpc("authority", "reliable")
func announce_start_game(random_seed, proto_teams):
	state = State.STARTING
	print("announce_start_game for peer id: ", multiplayer.get_unique_id())
	$Map.init(random_seed)
	$CellLabels.init($Map/Walls)
	$CellLabels.spawn_cell_labels()

	if multiplayer.is_server():
		assert(len(proto_teams) == 2)

		var non_inverted_team = load("res://scenes/team.tscn").instantiate()
		non_inverted_team.init(proto_teams[0]["peer_id"], proto_teams[0]["type"], false)
		$Replicated.add_child(non_inverted_team, true)
		var inverted_team = load("res://scenes/team.tscn").instantiate()
		inverted_team.init(proto_teams[1]["peer_id"], proto_teams[1]["type"], true)
		$Replicated.add_child(inverted_team, true)

		$Landmarks.init(random_seed, $Map, $Replicated)

@rpc("authority", "reliable")
func announce_game_over(winner_team_paths):
	print("announce_game_over")
	state = State.GAME_OVER
	var local_team = get_local_human_team()
	var won = local_team != null and winner_team_paths.has(local_team.get_path())
	$UI.show_game_over(won)

func spawn_missing_extractors():
	assert(multiplayer.is_server())
	for team in NodeUtils.get_nodes_in_group_for_node(self, "Team"):
		var extractor_number = 0
		for extractor in NodeUtils.get_nodes_in_group_for_node(self, "Extractor"):
			if extractor.team_path == team.get_path():
				extractor_number += 1

		var cell_label = "A1"
		if team.inverted:
			cell_label = "D4"

		for i in 4 - extractor_number:
			var extractor = load("res://scenes/extractor.tscn").instantiate()
			extractor.init(team.get_path(), $CellLabels.cell_label_to_pos(cell_label))
			$Replicated.add_child(extractor, true)

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

	var team = get_node_or_null(team_path)
	if team == null or team.peer_id != multiplayer.get_remote_sender_id():
		return

	construct_building_for_team(team_path)

func construct_building_for_team(team_path):
	assert(multiplayer.is_server())
	var team = get_node(team_path)
	if team.minerals < 100:
		return

	var site = NodeUtils.get_nodes_in_group_for_node(self, "Site").pick_random()
	if site == null:
		return

	var building_type = ["data_center", "skunk_works"].pick_random()
	var building = load("res://scenes/%s.tscn" % building_type).instantiate()
	building.init(team_path, site.water_path, site.global_position)
	$Replicated.add_child(building, true)
	site.queue_free()
	team.minerals -= 100

@rpc("any_peer", "reliable")
func request_produce_unit(team_path):
	if not multiplayer.is_server():
		return

	var team = get_node_or_null(team_path)
	if team == null or team.peer_id != multiplayer.get_remote_sender_id():
		return

	produce_unit_for_team(team_path)

func produce_unit_for_team(team_path):
	assert(multiplayer.is_server())
	var idle_buildings = []
	for building in NodeUtils.get_nodes_in_group_for_node(self, "Building"):
		if building.team_path != team_path:
			continue
		if building.producing != "":
			continue
		idle_buildings.append(building)

	var building = idle_buildings.pick_random()
	if building == null:
		return

	if building.is_in_group("DataCenter"):
		building.produce_unit("spam_bot")
	else:
		building.produce_unit(["skunk_drone", "data_drone"].pick_random())

@rpc("any_peer", "reliable")
func request_target(team_path):
	if not multiplayer.is_server():
		return

	var team = get_node_or_null(team_path)
	if team == null or team.peer_id != multiplayer.get_remote_sender_id():
		return

	target_for_team(team_path)

func target_for_team(team_path):
	assert(multiplayer.is_server())
	var idle_units = []
	for unit in NodeUtils.get_nodes_in_group_for_node(self, "Unit"):
		if unit.team_path != team_path:
			continue
		if unit.target_path != NodePath() or unit.target_position != Vector2.ZERO:
			continue
		if get_targets_for_unit(unit).is_empty():
			continue
		idle_units.append(unit)

	var unit = idle_units.pick_random()
	if unit == null:
		return

	var targets = get_targets_for_unit(unit)
	var target = targets.pick_random()
	unit.target_path = target.get_path()

func get_targets_for_unit(unit):
	var targets = []

	if unit.is_in_group("SpamBot"):
		targets = NodeUtils.get_nodes_in_group_for_node(self, "TransmissionTower")
	elif unit.is_in_group("Extractor"):
		targets = NodeUtils.get_nodes_in_group_for_node(self, "Mine")
	elif unit.is_in_group("DataDrone"):
		for data_center in NodeUtils.get_nodes_in_group_for_node(self, "DataCenter"):
			if data_center.team_path == unit.team_path:
				continue
			targets.append(data_center)
	elif unit.is_in_group("SkunkDrone"):
		for other_unit in NodeUtils.get_nodes_in_group_for_node(self, "Unit"):
			if other_unit.team_path == unit.team_path:
				continue
			targets.append(other_unit)

	return targets
