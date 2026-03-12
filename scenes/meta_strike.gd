extends Node

signal message_received

var client = WebSocketPeer.new()
var ws_connected = false

var URL = "wss://data-wars.deepgram.com/game"

func _ready():
	var err = client.connect_to_url(URL)
	if err != OK:
		print("Unable to connect")
		emit_signal("message_received", "unable to connect to meta-strike;")
		set_process(false)
	print("MetaStrike ready!")

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	emit_signal("message_received", "connection to meta-strike closed;")
	set_process(false)

func _connected(_proto):
	print("Connected to MetaStrike!")
	ws_connected = true	
	
func _on_data():
	var packet = client.get_packet()
	if client.was_string_packet():
		var message = packet.get_string_from_utf8()
		emit_signal("message_received", message)

func _process(_delta):
	client.poll()

	if client.get_ready_state() == WebSocketPeer.STATE_OPEN and !ws_connected:
		_connected("")

	while client.get_available_packet_count() > 0:
		_on_data()

	if client.get_ready_state() == WebSocketPeer.STATE_CLOSED and ws_connected:
		_closed(false)
