extends Node

const MAX_TEAMS := 2
const MAX_MATCHES := 5

var rng := RandomNumberGenerator.new()

var waiting_peer_ids: Array[int] = []
var next_match_id := 1
var pending_matches := {} # match_id -> {"type_id_pairs": Array, "seed": int, "ready_peer_ids": Array[int]}

func _ready() -> void:
	rng.randomize()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print(DisplayServer.get_name())

	if DisplayServer.get_name() == "headless":
		# TODO: get the port from some command-line argument or environment variable
		host_game(8000)

func _process(_delta: float) -> void:
	if DisplayServer.get_name() == "headless":
		return

	if Input.is_action_just_pressed("host"):
		# TODO: allow player to input port
		host_game(8000)

	if Input.is_action_just_pressed("connect"):
		# TODO: allow player to input ip and port
		connect_game("127.0.0.1", 8000)

	if Input.is_action_just_pressed("single_player"):
		var match_id := next_match_id
		next_match_id += 1

		var type_id_pairs = []
		type_id_pairs.append({"type": "human", "id": 1})
		type_id_pairs.append({"type": "computer", "id": 2})

		var seed = rng.randi()
		pending_matches[match_id] = {
			"type_id_pairs": type_id_pairs,
			"seed": seed,
			"ready_peer_ids": []
		}

		announce_start_match.rpc_id(1, match_id, type_id_pairs)
		announce_begin_match.rpc_id(1, match_id, seed)

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

func host_game(port: int) -> bool:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		# if not headless, it's possible the player triggered "host" more than once
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

	# if not headless, the host is also a waiting player
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

# start multiplayer matches by pulling pairs of peers off waiting_peer_ids
func try_match_making() -> void:
	while waiting_peer_ids.size() >= MAX_TEAMS:
		var match_id := next_match_id
		next_match_id += 1

		var type_id_pairs = []
		for i in MAX_TEAMS:
			type_id_pairs.append({"type": "human", "id": waiting_peer_ids.pop_front()})

		var seed := rng.randi()
		pending_matches[match_id] = {
			"type_id_pairs": type_id_pairs,
			"seed": seed,
			"ready_peer_ids": []
		}

		if DisplayServer.get_name() == "headless":
			announce_start_match.rpc_id(1, match_id, type_id_pairs)

		for type_id_pair in type_id_pairs:
			announce_start_match.rpc_id(type_id_pair["id"], match_id, type_id_pairs)

@rpc("call_local", "reliable")
func announce_start_match(match_id: int, type_id_pairs) -> void:
	print("announce_start_match for peer: ", multiplayer.get_unique_id())

	var arena = load("res://scenes/arena.tscn").instantiate()
	arena.name = "Arena_%d" % match_id
	$Matches.add_child(arena, true)

	for type_id_pair in type_id_pairs:
		arena.announce_team(type_id_pair["type"], type_id_pair["id"])

	# Whoever just created the arena is now ready.
	if multiplayer.is_server():
		_report_match_ready(match_id, multiplayer.get_unique_id())
	else:
		report_match_ready.rpc_id(1, match_id)

@rpc("any_peer", "reliable")
func report_match_ready(match_id: int) -> void:
	if not multiplayer.is_server():
		return

	_report_match_ready(match_id, multiplayer.get_remote_sender_id())

func _report_match_ready(match_id: int, peer_id: int) -> void:
	if not pending_matches.has(match_id):
		return

	var ready_peer_ids = pending_matches[match_id]["ready_peer_ids"]
	if ready_peer_ids.has(peer_id):
		return

	ready_peer_ids.append(peer_id)

	if ready_peer_ids.size() < MAX_TEAMS:
		return

	var seed: int = pending_matches[match_id]["seed"]
	var type_id_pairs = pending_matches[match_id]["type_id_pairs"]

	# In headless mode, peer 1 is the authoritative server arena.
	if DisplayServer.get_name() == "headless":
		announce_begin_match.rpc_id(1, match_id, seed)

	for type_id_pair in type_id_pairs:
		announce_begin_match.rpc_id(type_id_pair["id"], match_id, seed)

	pending_matches.erase(match_id)

@rpc("call_local", "reliable")
func announce_begin_match(match_id: int, seed: int) -> void:
	print("announce_begin_match for peer: ", multiplayer.get_unique_id())

	var arena = $Matches.get_node("Arena_%d" % match_id)
	arena.announce_play_game(seed)
