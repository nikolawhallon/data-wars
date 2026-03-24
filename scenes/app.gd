extends Node

const MAX_TEAMS = 2
const MAX_MATCHES = 5

var rng = RandomNumberGenerator.new()

var waiting_peer_ids = []

var matches = {}

# I use net ids because eventually I need clients to be able to say:
# "I want THIS Spam Bot to target THAT Transmission Tower"
# and I need the server, and all clients, to understand this
var net_nodes = {}

# server-only
func get_new_net_id():
	var net_id = rng.randi()
	# ensure no net_id collisions
	while net_nodes.has(net_id):
		net_id = rng.randi()

	return net_id

func register_net_node(net_id, node):
	var arena = NodeUtils.get_first_ancestor_in_group_for_node(node, "Arena")
	net_nodes[net_id] = {
		"match_id": arena.match_id,
		"node": node
	}

func get_node_for_net_id(net_id):
	return net_nodes[net_id]["node"]

func erase_net_nodes_in_match(match_id):
	var net_nodes_to_remove = []

	for net_id in net_nodes:
		if net_nodes[net_id]["match_id"] == match_id:
			net_nodes_to_remove.append(net_id)

	for net_id in net_nodes_to_remove:
		net_nodes.erase(net_id)

func get_arena_for_peer(peer_id):
	for arena in $Matches.get_children():
		for team in NodeUtils.get_nodes_in_group_for_node(arena, "Team"):
			if team.peer_id == peer_id:
				return arena
	return null

func get_arena_by_match_id(match_id):
	for arena in $Matches.get_children():
		if arena.match_id == match_id:
			return arena
	return null

func get_peer_ids_for_match(match_id):
	var peer_ids = []
	if !matches.has(match_id):
		return peer_ids

	for proto_team in matches[match_id]["proto_teams"]:
		peer_ids.append(proto_team["peer_id"])

	return peer_ids

func _ready():
	rng.randomize()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print(DisplayServer.get_name())

	if DisplayServer.get_name() == "headless":
		host_game(8000)

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return

	if Input.is_action_just_pressed("host"):
		host_game(8000)

	if Input.is_action_just_pressed("connect"):
		connect_game("127.0.0.1", 8000)

	if Input.is_action_just_pressed("single_player"):
		var proto_teams = [
			{"type": "human", "peer_id": 1, "ready": false, "net_id": get_new_net_id()},
			{"type": "computer", "peer_id": 1, "ready": true, "net_id": get_new_net_id()},
		]

		var match_id = rng.randi()
		var random_seed = rng.randi()

		matches[match_id] = {
			"state": "pending",
			"proto_teams": proto_teams,
			"seed": random_seed,
		}

		announce_boot_arena.rpc_id(1, match_id)

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if not multiplayer.is_server():
		return

	if waiting_peer_ids.has(peer_id):
		return

	waiting_peer_ids.append(peer_id)
	try_match_making()

func _on_connected_to_server() -> void:
	print("Connected to server")

func _on_connection_failed() -> void:
	print("Connection failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")

	for arena in $Matches.get_children():
		arena.queue_free()

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

func host_game(port):
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return true

	var max_connections = MAX_TEAMS
	if DisplayServer.get_name() == "headless":
		max_connections = MAX_MATCHES * MAX_TEAMS + 1

	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_server(port, max_connections)
	if result != OK:
		print("Failed to host: ", result)
		return false

	multiplayer.multiplayer_peer = peer
	print("Hosting on port: ", port)

	if DisplayServer.get_name() != "headless" and not waiting_peer_ids.has(1):
		waiting_peer_ids.append(1)

	return true

func connect_game(ip, port):
	var peer = ENetMultiplayerPeer.new()
	var result = peer.create_client(ip, port)
	if result != OK:
		print("Failed to connect: ", result)
		return false

	multiplayer.multiplayer_peer = peer
	print("Connected to: ", ip, ":", port)

	return true

func try_match_making():
	while waiting_peer_ids.size() >= MAX_TEAMS:
		var proto_teams = []
		for i in MAX_TEAMS:
			proto_teams.append({
				"type": "human",
				"peer_id": waiting_peer_ids.pop_front(),
				"ready": false,
				"net_id": get_new_net_id(),
			})

		var match_id = rng.randi()
		# ensure no match_id collisions
		while matches.has(match_id):
			match_id = rng.randi()
		var random_seed = rng.randi()

		matches[match_id] = {
			"state": "pending",
			"proto_teams": proto_teams,
			"seed": random_seed,
		}

		if DisplayServer.get_name() == "headless":
			announce_boot_arena.rpc_id(1, match_id)

		for proto_team in proto_teams:
			announce_boot_arena.rpc_id(proto_team["peer_id"], match_id)

@rpc("call_local", "reliable")
func announce_boot_arena(match_id):
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.match_id = match_id
	$Matches.add_child(arena, true)
	arena.leave_requested.connect(_on_arena_leave_requested.bind(arena))

	if multiplayer.is_server():
		mark_match_ready_for_peer(multiplayer.get_unique_id(), match_id)
	else:
		request_mark_match_ready.rpc_id(1, match_id)

@rpc("any_peer", "reliable")
func request_mark_match_ready(match_id):
	if not multiplayer.is_server():
		return

	mark_match_ready_for_peer(multiplayer.get_remote_sender_id(), match_id)

func mark_match_ready_for_peer(peer_id, match_id):
	if not matches.has(match_id):
		print("WARN - matches does not have this match_id: ", match_id)
		return

	var proto_teams = matches[match_id]["proto_teams"]

	for proto_team in proto_teams:
		if proto_team["peer_id"] == peer_id:
			proto_team["ready"] = true
			break

	for proto_team in proto_teams:
		if not proto_team["ready"]:
			return

	var random_seed = matches[match_id]["seed"]
	matches[match_id]["state"] = "playing"

	var arena = get_arena_by_match_id(match_id)

	# Collect unique peer_ids to avoid duplicate RPCs
	var peer_ids = []
	for proto_team in proto_teams:
		if not peer_ids.has(proto_team["peer_id"]):
			peer_ids.append(proto_team["peer_id"])

	if DisplayServer.get_name() == "headless":
		arena.announce_start_game.rpc_id(1, random_seed, proto_teams)

	for id in peer_ids:
		arena.announce_start_game.rpc_id(id, random_seed, proto_teams)

func _on_arena_leave_requested(arena):
	if multiplayer.is_server():
		leave_match_for_peer(arena.match_id)
	else:
		request_leave_match.rpc_id(1, arena.match_id)

@rpc("any_peer", "reliable")
func request_leave_match(match_id):
	if not multiplayer.is_server():
		return

	leave_match_for_peer(match_id)

func leave_match_for_peer(match_id):
	var arena = get_arena_by_match_id(match_id)
	if arena == null:
		print("ERROR - arena does not exist for match_id: ", match_id)
		return

	var peer_ids = []
	for team in NodeUtils.get_nodes_in_group_for_node(arena, "Team"):
		peer_ids.append(team.peer_id)

	if DisplayServer.get_name() == "headless":
		announce_leave_match.rpc_id(1, match_id)

	for id in peer_ids:
		announce_leave_match.rpc_id(id, match_id)

@rpc("call_local", "reliable")
func announce_leave_match(match_id):
	var arena = get_arena_by_match_id(match_id)
	if arena == null:
		print("ERROR - arena does not exist for match_id: ", match_id)
		return

	print("Freeing arena for peer id: ", multiplayer.get_unique_id())
	matches.erase(match_id)
	erase_net_nodes_in_match(match_id)
	arena.queue_free()

	if DisplayServer.get_name() != "headless":
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
