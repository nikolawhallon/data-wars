extends Node

const PORT := 8000
const MAX_TEAMS := 2

enum State {
	LOBBY,
	PENDING,
	PLAYING,
}

var state := State.LOBBY
var arena = null
var rng := RandomNumberGenerator.new()

# server-side only
var waiting_peer_ids: Array[int] = []

func _ready() -> void:
	rng.randomize()

	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	print(DisplayServer.get_name())

	if DisplayServer.get_name() == "headless":
		if host_game():
			print("Headless hosting")
			state = State.PENDING

func _process(_delta: float) -> void:
	if state == State.LOBBY and Input.is_action_just_pressed("host"):
		if host_game():
			state = State.PENDING

	if state == State.LOBBY and Input.is_action_just_pressed("connect"):
		if connect_game("127.0.0.1"):
			state = State.PENDING

	if state == State.LOBBY and Input.is_action_just_pressed("single_player"):
		start_single_player()

	if state == State.PENDING and multiplayer.is_server() and waiting_peer_ids.size() == MAX_TEAMS:
		start_multiplayer(waiting_peer_ids)
		state = State.PLAYING

func max_connections() -> int:
	if DisplayServer.get_name() == "headless":
		return MAX_TEAMS + 1
	return MAX_TEAMS

func host_game() -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, max_connections())
	if err != OK:
		print("Failed to host: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Hosting on port ", PORT)

	waiting_peer_ids.clear()

	# listen server: host is also player 1
	if DisplayServer.get_name() != "headless":
		waiting_peer_ids.append(1)

	return true

func connect_game(ip: String) -> bool:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		print("Failed to connect: ", err)
		return false

	multiplayer.multiplayer_peer = peer
	print("Connecting ", ip, ":", PORT)
	return true

func start_single_player() -> void:
	create_arena()
	arena.create_team_for_peer("human", 1)
	arena.create_team_for_peer("computer", 2)

	var seed := rng.randi()
	arena.rpc("announce_play_game", seed)
	state = State.PLAYING

func start_multiplayer(peer_ids: Array[int]) -> void:
	create_arena()

	for peer_id in peer_ids:
		arena.create_team_for_peer("human", peer_id)

	var seed := rng.randi()
	arena.rpc("announce_play_game", seed)

func create_arena() -> void:
	if arena != null:
		return

	arena = load("res://scenes/arena.tscn").instantiate()
	$Matches.add_child(arena)

func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)

	if not multiplayer.is_server():
		return

	if state != State.PENDING:
		return

	if waiting_peer_ids.has(peer_id):
		return

	waiting_peer_ids.append(peer_id)

func _on_connected_to_server() -> void:
	print("Connected to server")

func _on_connection_failed() -> void:
	print("Connection failed")

func _on_server_disconnected() -> void:
	print("Server disconnected")
