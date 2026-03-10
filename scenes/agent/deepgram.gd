extends Node

# signals

signal message_received
signal binary_packet_received

# variables

# we will buffer audio from the mic and send it out to Deepgram in reasonably sized chunks
var audio_buffer: PackedFloat32Array

# the WebSocketClient which allows us to connect to Deepgram
var client = WebSocketPeer.new()
var ws_connected = false

var DEEPGRAM_URL = "wss://agent.deepgram.com/v1/agent/converse"
#var DEEPGRAM_URL = "ws://localhost:8000/v1/agent/converse"

var prompt = """
You are Deepgame, the voice-command assistant for the RTS game Data Wars.

Your job is to interpret the player's spoken commands and convert them into function calls that control the game world.

Never invent units, buildings, or sites. Only reference IDs that exist in the World State. If the player asks for something impossible, briefly explain why instead of calling a function.

IDs of game objects should be used for function calls, but never spoken to the user.

Game Summary:
Two teams compete: Player and Enemy.

The goal is to produce Spam Bots and dispatch them off the map. Each Spam Bot that exits the map gives 1 point. The game ends when no more Spam Bots can be produced and none remain. Highest score wins.

Resources:
Minerals – mined by Extractors from Mines.
Water – stored at Sites and consumed by buildings and production.
Data – produced by Data Centers and used to build Spam Bots.

Map:
Finite map with coordinates and grid cells (A1, B3, etc). Buildings can only be built on Sites.

Buildings:

Data Center
- Generates 4 Data per second
- Consumes 1 Water per second from its Site
- Stops when Site Water reaches 0
- Builds Spam Bots (20 Minerals, 80 Data, 10 Water, 10s build)

Skunk Works
- Builds Data Drones (40 Minerals, 10 Water, 30s)
- Builds Skunk Drones (60 Minerals, 10 Water, 30s)

Units:

Extractor
- Mines Minerals from Mines
- Each team starts with 4

Data Drone
- Attaches to enemy Data Centers
- Generates 1 Data per second for the player
- Max 4 per Data Center (N, S, E, W slots)

Skunk Drone
- Combat unit
- Can attack Spam Bots, Extractors, Data Drones, and other Skunk Drones

Spam Bot
- Scoring unit produced by Data Centers
- Can be dispatched off the map (North, South, East, West)
- Gives 1 point when it exits

Player commands may request:
- building structures
- moving units
- dispatching Spam Bots
- attacking units
- attaching Data Drones to Data Centers

Prefer calling functions when possible. Keep responses short.
"""

# functions

# a helper function to convert f32 pcm samples to i16
func f32_to_i16(f: float):
	f = f * 32768
	if f > 32767:
		return 32767
	if f < -32768:
		return -32768
	return int(f)

# a convenience function to delete this node
func delete():
	print("Destroying DeepgramInstance")
	queue_free()

func _ready():
	print("DeepgramInstance ready!")


func initialize(api_key):
	# start recording from the mic (actually this only starts capture of the recording I think)
	$Microphone.recording = true

	if OS.get_name() == "Web":
		var protocols = PackedStringArray(["token", api_key])
		client.handshake_headers = protocols
		var err = client.connect_to_url(DEEPGRAM_URL)
		if err != OK:
			print("Unable to connect")
			emit_signal("message_received", "unable to connect to deepgram;")
			set_process(false)
	else:
		client.handshake_headers = PackedStringArray(["Authorization: Token " + api_key])
		var err = client.connect_to_url(DEEPGRAM_URL)
		if err != OK:
			print("Unable to connect")
			emit_signal("message_received", "unable to connect to deepgram;")
			set_process(false)

func inject_user_message(content):
	var message = {
		"type": "InjectUserMessage",
		"content": content
	}
	client.send_text(JSON.stringify(message))


func update_prompt(new_prompt):
	var message = {
		"type": "UpdatePrompt",
		"prompt": new_prompt
	}
	client.send_text(JSON.stringify(message))

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	emit_signal("message_received", "connection to deepgram closed;")
	set_process(false)

func _connected(_proto):
	print("Connected to Deepgram!")
	
	var mix_rate = int(AudioServer.get_mix_rate())
	
	var config_message = {
		"type": "Settings",
		"experimental": true,
		"audio": {
			"input": {
				"encoding": "linear16",
				"sample_rate": mix_rate,
			},
			"output": {
				"encoding": "linear16",
				"sample_rate": mix_rate,
				"container": "none"
			},
		},
		"agent": {
			"listen": {
				"provider": {
					"type": "deepgram",
					"model": "nova-2"
				}
			},
			"think": {
				"provider": {
					"type": "open_ai",
					"model": "gpt-4o"
				},
				"prompt": prompt
			},
			"speak": {
				"provider": {
					"type": "cartesia",
					"model_id": "sonic-2",
					"version": "2025-03-17",
					"voice": { "mode": "id", "id": "694f9389-aac1-45b6-b726-9d9369183238" }
				}
			}
		}
	}

	client.send_text(JSON.stringify(config_message))
	print("finished sending config message")
	ws_connected = true	
	
func _on_data():
	# receive a message from Deepgram!
	var packet = client.get_packet()
	if client.was_string_packet():
		var message = packet.get_string_from_utf8()

		# emit the message from Deepgram as a signal
		emit_signal("message_received", message)
	else:
		emit_signal("binary_packet_received", packet)

func _process(_delta):
	client.poll()

	if client.get_ready_state() == WebSocketPeer.STATE_OPEN and !ws_connected:
		_connected("")

	while client.get_available_packet_count() > 0:
		_on_data()

	if client.get_ready_state() == WebSocketPeer.STATE_CLOSED and ws_connected:
		_closed(false)

func _on_microphone_audio_captured(mono_data) -> void:
	if !ws_connected:
		return
		
	audio_buffer.append_array(mono_data)
	# TODO: consider using `set_encode_buffer_max_size(value)` to increase the packet size
	# this might allow us to stream slower and possibly improve performance
	if audio_buffer.size() >= 1024 * 40 * 0.5:
		# convert the f32 pcm to linear16/i16 pcm
		# this is a bit hacky, but godot doesn't seem to offer too much flexibility with low-level types
		var linear16_audio: PackedByteArray = []
		for sample in audio_buffer:
			linear16_audio.append(f32_to_i16(sample))
			linear16_audio.append(f32_to_i16(sample) >> 8)
		# send the audio to Deepgram!
		send_audio(linear16_audio)
		audio_buffer = PackedFloat32Array()

func send_audio(audio: PackedByteArray) -> void:
	var offset = 0
	while offset < audio.size():
		var max_buffer_size = client.get_outbound_buffer_size()
		var queued = client.get_current_outbound_buffered_amount()
		var remaining = max_buffer_size - queued

		if remaining <= 0:
			print("WARNING")
			break

		var chunk_size = min(remaining, audio.size() - offset)
		var chunk = audio.slice(offset, offset + chunk_size)

		client.send(chunk)

		offset += chunk_size
