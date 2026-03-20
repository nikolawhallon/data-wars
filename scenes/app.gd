extends Node

const MAX_TEAMS := 2
const MAX_MATCHES := 5

var rng := RandomNumberGenerator.new()

var waiting_peer_ids: Array[int] = []

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
		var type_id_pairs = []
		type_id_pairs.append({"type": "human", "id": 1})
		type_id_pairs.append({"type": "computer", "id": 2})
		announce_start_match.rpc_id(1, type_id_pairs, rng.randi())

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if not multiplayer.is_server():
		return

	if waiting_peer_ids.has(peer_id):
		return

	waiting_peer_ids.append(peer_id)
	# every time a peer connects, check if we can start a new match 
	try_match_making()

func _on_connected_to_server() -> void:
	print("Connected to server")

func _on_connection_failed() -> void:
	print("Connection failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")

func host_game(port) -> bool:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		# if not headless, it's possible the player triggered "host" more than once
		return true

	var max_connections = MAX_TEAMS
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
		var type_id_pairs = []
		for i in MAX_TEAMS:
			type_id_pairs.append({"type": "human", "id": waiting_peer_ids.pop_front()})

		var seed = rng.randi()
		if DisplayServer.get_name() == "headless":
			announce_start_match.rpc_id(1, type_id_pairs, seed)
		for type_id_pair in type_id_pairs:
			announce_start_match.rpc_id(type_id_pair["id"], type_id_pairs, seed)

@rpc("call_local", "reliable")
func announce_start_match(type_id_pairs, seed: int) -> void:
	var arena = load("res://scenes/arena.tscn").instantiate()
	$Matches.add_child(arena, true)

	for type_id_pair in type_id_pairs:
		arena.announce_team(type_id_pair["type"], type_id_pair["id"])

	arena.announce_play_game(seed)
