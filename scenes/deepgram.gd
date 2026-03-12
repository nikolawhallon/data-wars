extends Node

# signals

signal message_received
signal binary_packet_received

# variables

# we will buffer audio from the mic and send it out to Deepgram in reasonably sized chunks
var audio_buffer: PackedFloat32Array

var muted = false

# the WebSocketClient which allows us to connect to Deepgram
var client = WebSocketPeer.new()
var ws_connected = false

var DEEPGRAM_URL = "wss://agent.deepgram.com/v1/agent/converse"
#var DEEPGRAM_URL = "ws://localhost:8000/v1/agent/converse"

var prompt = """
You are Deepgame, the voice-command assistant for the RTS game Data Wars. Interpret the team’s spoken commands and convert them into game function calls.
You will either help the Player or the Enemy, help both of them equally well, to the best of your ability.

Rules:

    Never invent units, buildings, or sites — only use IDs that exist in the World State.

    Use object IDs in function calls, but never say them aloud.

    Keep responses short. Do not make any lists. When possible, reply in short clauses.

Game summary:
Two teams compete: Player and Enemy. The goal is to build Spam Bots and send them to Transmission Towers to earn Clicks. Each Spam Bot that reaches a Transmission Tower gives 1 Click. The game ends when no more Water remains on the map - then the Team with the most Clicks wins.

Map:
A finite grid map (A1, B3, etc.). Buildings can only be constructed on Sites.

Buildings:

    Data Center: builds Spam Bots

    Skunk Works: builds Data Drones and Skunk Drones

Data Centers drain Water from the map to produce Data.

Units:

    Extractor: collects Minerals from Mines

    Data Drone: collects Data from enemy Data Centers

    Skunk Drone: combat unit

    Spam Bot: scoring unit that can be dispatched to Transmission Towers

Team commands may involve building structures, producing units, or moving units.
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

func _ready():
	print("Deepgram ready!")

func initialize(api_key, tag):
	await ready
	print("Initializing Deepgram")
	if OS.get_name() == "Web":
		# THIS REQUIRES A MANUAL PATCH AFTER EXPORT
		var err = client.connect_to_url(DEEPGRAM_URL + "?tag=" + tag)
		if err != OK:
			print("Unable to connect")
			emit_signal("message_received", "unable to connect to deepgram;")
			set_process(false)
	else:
		print("Connecting to Deepgram with Auth Headers")
		client.handshake_headers = PackedStringArray(["Authorization: Token " + api_key])
		var err = client.connect_to_url(DEEPGRAM_URL + "?tag=" + tag)
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

func replace_prompt(team, new_prompt):
	var first = {
		"type": "ReplacePrompt",
		"prompt": "You are the agent for Team: " + team + "\n" + prompt + "\nHere is the World State:\n" + new_prompt
	}
	client.send_text(JSON.stringify(first))
	
func send_function_call_response(function_name, content, id):
	var message = {
		"type": "FunctionCallResponse",
		"name": function_name,
		"content": content,
		"id": id
	}
	client.send_text(JSON.stringify(message))

func _closed(was_clean = false):
	print("Closed, clean: ", was_clean)
	emit_signal("message_received", "connection to deepgram closed;")
	set_process(false)

func _connected(_proto):
	print("Connected to Deepgram!")
	
	var mix_rate = int(AudioServer.get_mix_rate())
	print("mix_rate is: ", mix_rate)
	
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
					"model": "flux-general-en"
				}
			},
			"think": {
				"provider": {
					"type": "open_ai",
					"model": "gpt-4o-mini"
				},
				"prompt": prompt,
				"functions": [
				{
					"name": "build_building",
					"description": "Build a new building on a specified site on the map.",
					"parameters": {
						"type": "object",
						"properties": {
							"site_id": {
								"type": "integer",
								"description": "The id of an available site on the map."
							},
							"building_type": {
								"type": "string",
								"description": "The type of building to construct.",
								"enum": ["skunk_works", "data_center"]
							}
						},
						"required": ["site_id", "building_type"]
					}
				},
				{
					"name": "build_unit",
					"description": "Build a unit from a specific building on the map.",
					"parameters": {
						"type": "object",
						"properties": {
							"building_id": {
								"type": "integer",
								"description": "The id of the building that will produce the unit."
							},
							"unit_type": {
								"type": "string",
								"description": "The type of unit to create. Skunk Works can produce Data Drones and Skunk Drones, Data Centers can produce Spam Bots.",
								"enum": ["data_drone", "skunk_drone", "spam_bot"]
							}
						},
						"required": ["building_id", "unit_type"]
					}
				},
				{
					"name": "set_target_to_object",
					"description": "Set a unit's target to another object by id. Prefer this set target function always.",
					"parameters": {
						"type": "object",
						"properties": {
							"unit_id": {
								"type": "integer",
								"description": "The id of the unit to command."
							},
							"target_id": {
								"type": "integer",
								"description": "The id of the object to target."
							}
						},
						"required": ["unit_id", "target_id"]
					}
				},
				{
					"name": "set_target_to_cell",
					"description": "Set a unit's target to a map cell like A1 or B2. Only call this function if a cell was specified and no target object was specified.",
					"parameters": {
						"type": "object",
						"properties": {
							"unit_id": {
								"type": "integer",
								"description": "The id of the unit to command."
							},
							"cell": {
								"type": "string",
								"description": "Cell id like A1, B2, etc."
							}
						},
						"required": ["unit_id", "cell"]
					}
				}
				]
			},
			"speak": {
				"provider": {
					"type": "deepgram",
					"model": "aura-asteria-en"
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

func forward_microphone_audio(mono_data) -> void:
	if !ws_connected:
		return

	if muted:
		for i in mono_data.size():
			mono_data[i] = 0.0

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
			return

		var chunk_size = min(remaining, audio.size() - offset)
		var chunk = audio.slice(offset, offset + chunk_size)

		client.send(chunk)

		offset += chunk_size

func _on_keep_alive_timer_timeout() -> void:
	if !ws_connected:
		return

	var message = {"type": "KeepAlive"}
	client.send_text(JSON.stringify(message))
