extends Node2D

const PORT := 8000
const MAX_CLIENTS := 2

var rng = RandomNumberGenerator.new()

enum State {
	LOBBY,
	PENDING,
	PLAYING
}

var state := State.LOBBY

func _ready() -> void:
	rng.randomize()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(delta: float) -> void:
	if state == State.LOBBY and Input.is_action_just_pressed("host"):
		print("host pressed")
		if host_game():
			print("Changing state to PENDING")
			state = State.PENDING
	if state == State.LOBBY and Input.is_action_just_pressed("join"):
		print("join pressed")
		if join_game("127.0.0.1"):
			print("Changing state to PENDING")
			state = State.PENDING

	# once all players connect, immediately generate the world for all players
	# this is a tad clunky, but seems perfectly reasonable for now?
	if state == State.PENDING and multiplayer.is_server() and len(get_tree().get_nodes_in_group("Team")) == MAX_CLIENTS:
		var seed = rng.randi()
		rpc("start_game", seed)

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

func host_game() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, MAX_CLIENTS)
	if err != OK:
		print("Failed to host: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", PORT)

	create_team_for_peer(1)
	return true

func join_game(ip: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		print("Failed to join: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Joining ", ip, ":", PORT)
	return true

func _on_connected_to_server() -> void:
	print("Connected to server")

func _on_connection_failed() -> void:
	print("Connection failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if not multiplayer.is_server():
		return

	# when a peer connects, create a team for them
	create_team_for_peer(peer_id)

# server-only - creates a team for a new peer, and broadcasts it to all peers
func create_team_for_peer(peer_id: int) -> void:
	# create the team
	spawn_team("human", peer_id)
	# tell all peers about all teams
	for team in get_tree().get_nodes_in_group("Team"):
		rpc("announce_team", team.type, team.id)

@rpc("call_local", "reliable")
func announce_team(type: String, id: int) -> void:
	# because this runs for all teams/peers
	# everytime a new peer connects, it must be idempotent
	var has_team = false
	for child in get_children():
		if child.has_method("get") and child.get("id") == id:
			has_team = true
	if has_team:
		return

	spawn_team(type, id)

func spawn_team(type: String, id: int) -> void:
	var team = load("res://scenes/team.tscn").instantiate()
	team.type = type
	team.id = id
	add_child(team)

	if team.is_local_human():
		$UI.init(team)

@rpc("call_local", "reliable")
func start_game(seed: int) -> void:
	$Map.init(seed)
	state = State.PLAYING

	if multiplayer.is_server():
		$Landmarks.init(seed, $Map, $Replicated)

@rpc("call_local", "reliable")
func announce_queue_free_node(path: NodePath) -> void:
	var node = get_node_or_null(path)
	if node != null:
		node.queue_free()

@rpc("any_peer", "reliable")
func request_construct_building() -> void:
	print("request_construct_building")
	
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	construct_building_for_peer(peer_id)

func construct_building_for_peer(peer_id: int) -> void:
	print("construct_building_for_peer")
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
		data_center.position = site.position
		data_center.init(team.get_path(), site.global_position, site.water_path)
		$Replicated.add_child(data_center, true)
		announce_queue_free_node.rpc(site.get_path())
		break

@rpc("any_peer", "reliable")
func request_produce_unit() -> void:
	print("request_produce_unit")
	
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	produce_unit_for_peer(peer_id)

func produce_unit_for_peer(peer_id: int) -> void:
	print("produce_unit_for_peer")
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
		data_center.produce_unit("spam_bot")
		break

@rpc("any_peer", "reliable")
func request_target() -> void:
	print("request_target")

	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()
	target_for_peer(peer_id)

func target_for_peer(peer_id: int) -> void:
	print("target_for_peer")
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

		var transmission_towers = get_tree().get_nodes_in_group("TransmissionTower")
		var transmission_tower = transmission_towers.pick_random()
		if transmission_tower == null:
			return
		spam_bot.target = transmission_tower
		break
