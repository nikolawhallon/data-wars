extends Node

const MAX_TEAMS := 2
const MAX_MATCHES := 5

var rng := RandomNumberGenerator.new()

var waiting_peer_ids: Array[int] = []

# match_id -> {
#   "proto_teams": Array[Dictionary], # {"type": String, "id": int, "ready": bool}
#   "seed": int
# }
var pending_matches := {}

func find_arena_for_peer(peer_id: int) -> Node:
	for arena in $Matches.get_children():
		for team in arena.find_in_subtree("Team"):
			if team.id == peer_id:
				return arena
	return null

func _ready() -> void:
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
			{"type": "human", "id": 1, "ready": false},
			{"type": "computer", "id": 2, "ready": true}, # this feels hacky
		]

		var match_id := rng.randi()
		var seed := rng.randi()

		pending_matches[match_id] = {
			"proto_teams": proto_teams,
			"seed": seed,
		}

		announce_boot_arena.rpc_id(1, match_id, proto_teams)

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

func host_game(port: int) -> bool:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		return true

	var max_connections := MAX_TEAMS
	if DisplayServer.get_name() == "headless":
		max_connections = MAX_MATCHES * MAX_TEAMS + 1

	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, max_connections)
	if err != OK:
		print("Failed to host: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", port)

	if DisplayServer.get_name() != "headless" and not waiting_peer_ids.has(1):
		waiting_peer_ids.append(1)

	return true

func connect_game(ip: String, port: int) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port)
	if err != OK:
		print("Failed to connect: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Connecting ", ip, ":", port)

	return true

func try_match_making() -> void:
	while waiting_peer_ids.size() >= MAX_TEAMS:
		var proto_teams := []
		for i in MAX_TEAMS:
			proto_teams.append({
				"type": "human",
				"id": waiting_peer_ids.pop_front(),
				"ready": false,
			})

		var match_id := rng.randi()
		# ensure no match_id collisions
		while pending_matches.has(match_id):
			match_id = rng.randi()
		var seed := rng.randi()

		pending_matches[match_id] = {
			"proto_teams": proto_teams,
			"seed": seed,
		}

		if DisplayServer.get_name() == "headless":
			announce_boot_arena.rpc_id(1, match_id, proto_teams)

		for proto_team in proto_teams:
			announce_boot_arena.rpc_id(proto_team["id"], match_id, proto_teams)

@rpc("call_local", "reliable")
func announce_boot_arena(match_id: int, proto_teams: Array) -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.name = "Arena_%d" % match_id
	$Matches.add_child(arena, true)
	arena.leave_requested.connect(_on_arena_leave_requested.bind(arena))

	for proto_team in proto_teams:
		arena.announce_team(proto_team["type"], proto_team["id"])

	if multiplayer.is_server():
		mark_match_ready_for_peer(multiplayer.get_unique_id(), match_id)
	else:
		request_mark_match_ready.rpc_id(1, match_id)

@rpc("any_peer", "reliable")
func request_mark_match_ready(match_id: int) -> void:
	if not multiplayer.is_server():
		return

	mark_match_ready_for_peer(multiplayer.get_remote_sender_id(), match_id)

func mark_match_ready_for_peer(peer_id: int, match_id: int) -> void:
	if not pending_matches.has(match_id):
		print("WARN - pending_matches does not have this match_id: ", match_id)
		return

	var proto_teams: Array = pending_matches[match_id]["proto_teams"]

	for proto_team in proto_teams:
		if proto_team["id"] == peer_id:
			proto_team["ready"] = true
			break

	for proto_team in proto_teams:
		if not proto_team["ready"]:
			return

	var seed: int = pending_matches[match_id]["seed"]

	if DisplayServer.get_name() == "headless":
		announce_start_match.rpc_id(1, match_id, seed)

	for proto_team in proto_teams:
		announce_start_match.rpc_id(proto_team["id"], match_id, seed)

	pending_matches.erase(match_id)

@rpc("call_local", "reliable")
func announce_start_match(match_id: int, seed: int) -> void:
	var arena = $Matches.get_node("Arena_%d" % match_id)
	arena.announce_play_game(seed)

func _on_arena_leave_requested(arena):
	if multiplayer.is_server():
		leave_match_for_peer(multiplayer.get_unique_id())
	else:
		request_leave_match.rpc_id(1)

@rpc("any_peer", "reliable")
func request_leave_match() -> void:
	if not multiplayer.is_server():
		return

	leave_match_for_peer(multiplayer.get_remote_sender_id())

func leave_match_for_peer(peer_id: int) -> void:
	var arena := find_arena_for_peer(peer_id)
	if arena == null:
		print("WARN - no arena for peer ", peer_id)
		return

	var peer_ids := []
	for team in arena.find_in_subtree("Team"):
		peer_ids.append(team.id)

	if DisplayServer.get_name() == "headless":
		announce_leave_match.rpc_id(1, arena.name)

	for id in peer_ids:
		announce_leave_match.rpc_id(id, arena.name)

	print("Freeing arena for: ", peer_id)
	arena.queue_free()

@rpc("call_local", "reliable")
func announce_leave_match(arena_name: String) -> void:
	print("Freeing arena for: ", multiplayer.get_unique_id())
	if $Matches.has_node(arena_name):
		$Matches.get_node(arena_name).queue_free()

	if DisplayServer.get_name() != "headless":
		multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
