extends Node2D


# CONTEXT LIMIT seems to be only about 3000 characters...
# at about 100 characters per object, that's only ~30 objects worth
# retrieval can be done via a function:
# * key, e.g. skunk_works, extractors, etc
# * cell (optional), e.g. A1, C6, etc

# Tuesday:
# phone input?

# Wednesday:
# resource management
# animations
# sound effects?
# enemy AI?

# Thursday
# testing, testing, testing
# stretch goals?
# produce video

# Monday:
# Nikola:
# Teams

# Sam:
# minerals (48x48)
# spam bots
# data drones
# minerals (icon)
# data (icon)
# clicks (icon)

# big tasks
# base game
# * including functions to retrieve parts of state
#   because the full state is too big
# text-only mode
# enemy AI using... AI + VA
# phone input
# networked multiplayer
# planning
# better look-ups (not the full world state)

var muted_texture  := preload("res://assets/muted.png")
var unmuted_texture  := preload("res://assets/unmuted.png")

var rng = RandomNumberGenerator.new()

const DEEPGRAM_API_KEY = "asdf"
var player_deepgram = null
var enemy_deepgram = null

var map_origin: Vector2
var map_size: Vector2

var tts_generator := AudioStreamGenerator.new()
var tts_playback: AudioStreamGeneratorPlayback

func _ready() -> void:
	rng.randomize()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

	$CellLabels.init($RandomMap/Walls)
	map_origin = $RandomMap/Walls.get_used_rect().position * $RandomMap/Walls.tile_set.tile_size
	map_size = $RandomMap/Walls.get_used_rect().size * $RandomMap/Walls.tile_set.tile_size
	$CellLabels.spawn_cell_labels()

	$Camera2D.limit_left   = int(map_origin.x - 120.0)
	$Camera2D.limit_top    = int(map_origin.y - 120.0)
	$Camera2D.limit_right  = int(map_origin.x + map_size.x + 120.0)
	$Camera2D.limit_bottom = int(map_origin.y + map_size.y + 120.0)

	tts_generator.mix_rate = AudioServer.get_mix_rate()
	tts_generator.buffer_length = 60.0
	$TtsPlayer.stream = tts_generator
	$TtsPlayer.play()
	tts_playback = $TtsPlayer.get_stream_playback()

	var extractors_to_spawn = 4
	while extractors_to_spawn > 0:
		var player_extractor = load("res://scenes/extractor.tscn").instantiate()
		player_extractor.init($Player, Vector2(randf_range(64.0, 256.0), randf_range(64.0, 256.0)))
		add_child(player_extractor)
		var enemy_extractor = load("res://scenes/extractor.tscn").instantiate()
		enemy_extractor.init($Enemy, Vector2(randf_range(512.0, 1024.0), randf_range(512.0, 1024.0)))
		add_child(enemy_extractor)
		
		extractors_to_spawn -= 1

	player_deepgram = load("res://scenes/deepgram.tscn").instantiate()
	player_deepgram.initialize(DEEPGRAM_API_KEY, "player")
	player_deepgram.connect("binary_packet_received", _on_player_deepgram_binary_packet_received)
	player_deepgram.connect("message_received", _on_player_deepgram_message_received)
	add_child(player_deepgram)

	enemy_deepgram = load("res://scenes/deepgram.tscn").instantiate()
	enemy_deepgram.initialize(DEEPGRAM_API_KEY, "enemy")
	enemy_deepgram.connect("message_received", _on_enemy_deepgram_message_received)
	add_child(enemy_deepgram)

	if OS.get_name() != "Web":
		var microphone = load("res://scenes/microphone.tscn").instantiate()
		microphone.connect("audio_captured", _on_microphone_audio_captured)
		microphone.recording = true
		add_child(microphone)

func _process(delta: float) -> void:
	# move the camera
	var speed = 1000.0
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	$Camera2D.global_position += dir * speed * delta

	# clamp the camera
	var viewport_size = get_viewport().get_visible_rect().size
	var half_w = viewport_size.x * 0.5 * $Camera2D.zoom.x
	var half_h = viewport_size.y * 0.5 * $Camera2D.zoom.y
	var x = clamp($Camera2D.global_position.x, float($Camera2D.limit_left)+half_w, float($Camera2D.limit_right)-half_w)
	var y = clamp($Camera2D.global_position.y, float($Camera2D.limit_top)+half_h, float($Camera2D.limit_bottom)-half_h)
	$Camera2D.global_position = Vector2(x, y)

	if Input.is_action_just_pressed("mute"):
		player_deepgram.muted = !player_deepgram.muted
		if player_deepgram.muted:
			$UICanvas/MarginContainer/VBoxContainer/HBoxContainer/TextureRect.texture = muted_texture
		else:
			$UICanvas/MarginContainer/VBoxContainer/HBoxContainer/TextureRect.texture = unmuted_texture

	if Input.is_action_just_pressed("debug"):
		for debug in get_tree().get_nodes_in_group("Debug"):
			debug.visible = !debug.visible

	if Input.is_action_just_pressed("info"):
		for info in get_tree().get_nodes_in_group("Info"):
			info.visible = !info.visible

	if Input.is_action_just_pressed("palette"):
		$PaletteSwapCanvas/PaletteSwap.next_palette()

	if Input.is_action_just_pressed("reconnect"):
		if is_instance_valid(player_deepgram):
			player_deepgram.queue_free()
			player_deepgram = null

		player_deepgram = load("res://scenes/deepgram.tscn").instantiate()
		player_deepgram.initialize(DEEPGRAM_API_KEY, "player")
		player_deepgram.connect("binary_packet_received", _on_player_deepgram_binary_packet_received)
		player_deepgram.connect("message_received", _on_player_deepgram_message_received)
		add_child(player_deepgram)

		if is_instance_valid(enemy_deepgram):
			enemy_deepgram.queue_free()
			enemy_deepgram = null

		enemy_deepgram = load("res://scenes/deepgram.tscn").instantiate()
		enemy_deepgram.initialize(DEEPGRAM_API_KEY, "enemy")
		enemy_deepgram.connect("message_received", _on_enemy_deepgram_message_received)
		add_child(enemy_deepgram)

	var player_extractor_number = 0
	for extractor in get_tree().get_nodes_in_group("Extractor"):
		if extractor.team != $Player:
			continue
		player_extractor_number += 1
	
	var extractors_to_spawn = 4 - player_extractor_number
	while extractors_to_spawn > 0:
		var extractor = load("res://scenes/extractor.tscn").instantiate()
		extractor.init($Player, Vector2(randf_range(64.0, 256.0), randf_range(64.0, 256.0)))
		add_child(extractor)
		extractors_to_spawn -= 1

func get_world_state() -> Dictionary:
	var mine_array: Array = []
	var water_array: Array = []
	var site_array: Array = []
	var transmission_tower_array: Array = []
	var skunk_works_array: Array = []
	var data_center_array: Array = []
	var skunk_drone_array: Array = []
	var data_drone_array: Array = []
	var spam_bot_array: Array = []
	var extractor_array: Array = []

	for mine in get_tree().get_nodes_in_group("Mine"):
		var p: Vector2 = mine.global_position
		mine_array.append({
			"id": int(mine.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})

	for water in get_tree().get_nodes_in_group("Water"):
		var p: Vector2 = water.global_position
		water_array.append({
			"id": int(water.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})
		
	for site in get_tree().get_nodes_in_group("Site"):
		var p: Vector2 = site.global_position
		site_array.append({
			"id": int(site.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})

	for transmission_tower in get_tree().get_nodes_in_group("TransmissionTower"):
		var p: Vector2 = transmission_tower.global_position
		transmission_tower_array.append({
			"id": int(transmission_tower.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})

	for skunk_works in get_tree().get_nodes_in_group("SkunkWorks"):
		var p: Vector2 = skunk_works.global_position
		skunk_works_array.append({
			"team": skunk_works.team.team,
			"id": int(skunk_works.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p),
			"producing": skunk_works.producing
		})

	for data_center in get_tree().get_nodes_in_group("DataCenter"):
		var p: Vector2 = data_center.global_position
		data_center_array.append({
			"team": data_center.team.team,
			"id": int(data_center.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p),
			"producing": data_center.producing
		})

	for skunk_drone in get_tree().get_nodes_in_group("SkunkDrone"):
		var p: Vector2 = skunk_drone.global_position
		skunk_drone_array.append({
			"team": skunk_drone.team.team,
			"id": int(skunk_drone.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})

	for data_drone in get_tree().get_nodes_in_group("DataDrone"):
		var p: Vector2 = data_drone.global_position
		data_drone_array.append({
			"team": data_drone.team.team,
			"id": int(data_drone.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})
	
	for spam_bot in get_tree().get_nodes_in_group("SpamBot"):
		var p: Vector2 = spam_bot.global_position
		spam_bot_array.append({
			"team": spam_bot.team.team,
			"id": int(spam_bot.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
		})
		
	for extractor in get_tree().get_nodes_in_group("Extractor"):
		var p: Vector2 = extractor.global_position
		extractor_array.append({
			"team": extractor.team.team,
			"id": int(extractor.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p),
			"mining": extractor.mining()
		})

	var world_state = {
		"world": {
			"origin": {"x": map_origin.x, "y": map_origin.y},
			"size": {"w": map_size.x, "h": map_size.y},
			"units": "pixels",
			"x_direction": "east",
			"y_direction": "south"
		},
		"grid": {
			"cols": $CellLabels.cols,
			"rows": $CellLabels.rows,
			"cell_anchor": "center"
		},
		"player_minerals": $Player.minerals,
		"player_data": $Player.data,
		"player_clicks": $Player.clicks,
		"enemy_minerals": $Enemy.minerals,
		"enemy_data": $Enemy.data,
		"enemy_clicks": $Enemy.clicks,
		"building_mineral_cost": 100,
		"spam_bot_data_cost": 20,
		"skunk_drone_mineral_cost": 50,
		"data_drone_mineral_cost": 50,
		"mines": mine_array,
		"waters": water_array,
		"sites": site_array,
		"transmission_towers": transmission_tower_array,
		"skunk_works": skunk_works_array,
		"data_centers": data_center_array,
		"skunk_drones": skunk_drone_array,
		"data_drones": data_drone_array,
		"spam_bots": spam_bot_array,
		"extractors": extractor_array
	}

	return world_state

func _on_player_data_updated():
	$UICanvas/MarginContainer/VBoxContainer/HBoxContainer/Data.text = str($Player.data)

func _on_player_clicks_updated():
	$UICanvas/ClicksMarginContainer/VBoxContainer/Player/Clicks.text = str($Player.clicks)

func _on_enemy_clicks_updated():
	$UICanvas/ClicksMarginContainer/VBoxContainer/Enemy/Clicks.text = str($Enemy.clicks)

func _on_player_minerals_updated() -> void:
	$UICanvas/MarginContainer/VBoxContainer/HBoxContainer/Minerals.text = str($Player.minerals)

func build_building(team, site_id, building_type):
	var site = instance_from_id(site_id)
	if site == null:
		return "No Site with site_id " + str(site_id)

	if not site.is_in_group("Site"):
		return "No Site with site_id " + str(site_id)

	if team.minerals < 100:
		return "Buildings cost 100 minerals, Team does not have enough"

	var water = site.get_parent()
	if building_type == "skunk_works":
		var skunk_works = load("res://scenes/skunk_works.tscn").instantiate()
		water.add_child(skunk_works)
		skunk_works.init(team, site.global_position)
		site.queue_free()
	elif building_type == "data_center":
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		water.add_child(data_center)
		data_center.init(team, site.global_position)
		site.queue_free()
	else:
		return "Invalid building_type"

	team.minerals -= 100
	if team == $Player:
		team.emit_signal("minerals_updated")

	return "Successfully constructed building"

func build_unit(team, building_id, unit_type):
	var building = instance_from_id(building_id)
	if building == null:
		return "No building with building_id " + str(building_id)

	if not building.is_in_group("SkunkWorks") and not building.is_in_group("DataCenter"):
		return "No building with building_id " + str(building_id)

	if team != building.team:
		return "That building belongs to a different Team"

	return building.spawn_unit(unit_type)

func set_target(team, arguments):
	var unit = instance_from_id(arguments["unit_id"])
	if unit == null:
		return "No unit with unit_id"
	if not unit.is_in_group("Unit"):
		return "No unit with unit_id"

	if team != unit.team:
		return "That unit belongs to a different Team"

	if arguments.has("x") and arguments.has("y"):
		unit.target = Vector2(arguments["x"], arguments["y"])
	elif arguments.has("cell"):
		if not $CellLabels.cell_label_to_pos(arguments["cell"]):
			return "Invalid cell"
		unit.target = $CellLabels.cell_label_to_pos(arguments["cell"])
	elif arguments.has("target_id"):
		var object = instance_from_id(arguments["target_id"])
		if object == null:
			return "No object with target_id"
		unit.target = object
	else:
		return "No valid target specified"
	
	return "Successfully set the target of the unit"

func _on_player_deepgram_message_received(message) -> void:
	var json := JSON.new()
	var err := json.parse(message)

	if err != OK:
		print("JSON parse failed:", message)
		print("Error:", json.get_error_message(), "at line", json.get_error_line())
		return

	var data = json.data
	
	if not (data is Dictionary):
		return

	if data == null:
		return

	if not data.has("type"):
		return

	print(data)
	
	if data["type"] == "FunctionCallRequest":
		for function in data["functions"]:
			if function["name"] == "build_building":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_building($Player, arguments["site_id"], arguments["building_type"])
				player_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "build_unit":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_unit($Player, arguments["building_id"], arguments["unit_type"])
				player_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "set_target_to_cell":
				var arguments = JSON.parse_string(function["arguments"])
				var result = set_target($Player, arguments)
				player_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "set_target_to_object":
				var arguments = JSON.parse_string(function["arguments"])
				var result = set_target($Player, arguments)
				player_deepgram.send_function_call_response(function["name"], result, function["id"])
	elif data["type"] == "AgentStartedSpeaking":
		$UICanvas/ClicksMarginContainer/VBoxContainer/Latencies.text = "LAG: " + "%6.2f" % data["total_latency"]
		$UICanvas/ClicksMarginContainer/VBoxContainer/Latencies.text += "\n"
		$UICanvas/ClicksMarginContainer/VBoxContainer/Latencies.text += "TTS: " + "%6.2f" % data["tts_latency"]
		$UICanvas/ClicksMarginContainer/VBoxContainer/Latencies.text += "\n"
		$UICanvas/ClicksMarginContainer/VBoxContainer/Latencies.text += "LLM: " + "%6.2f" % data["ttt_latency"]
	elif data["type"] == "ConversationText":
		$ChatCanvas/MarginContainer/HBoxContainer/Player.text += str(data["role"], ":")
		$ChatCanvas/MarginContainer/HBoxContainer/Player.text += "\n"
		$ChatCanvas/MarginContainer/HBoxContainer/Player.text += str(data["content"])
		$ChatCanvas/MarginContainer/HBoxContainer/Player.text += "\n"
		$ChatCanvas/MarginContainer/HBoxContainer/Player.text += "\n"
		var total_lines = $ChatCanvas/MarginContainer/HBoxContainer/Player.get_line_count()
		var max_lines_visible = $ChatCanvas/MarginContainer/HBoxContainer/Player.max_lines_visible
		if total_lines > max_lines_visible:
			$ChatCanvas/MarginContainer/HBoxContainer/Player.lines_skipped = total_lines - max_lines_visible
	elif data.get("type") == "UserStartedSpeaking":
		var world_state = get_world_state()
		player_deepgram.replace_prompt($Player.team, JSON.stringify(world_state))
		_clear_tts_audio()

func _clear_tts_audio() -> void:
	$TtsPlayer.stop()

	tts_generator = AudioStreamGenerator.new()
	tts_generator.mix_rate = int(AudioServer.get_mix_rate())
	tts_generator.buffer_length = 60.0

	$TtsPlayer.stream = tts_generator
	$TtsPlayer.play()

	tts_playback = $TtsPlayer.get_stream_playback()
	
# we assume audio is linear16 PCM, little-endian, mono
func _on_player_deepgram_binary_packet_received(audio) -> void:
	if tts_playback == null:
		return

	var n_samples = audio.size() / 2
	var i := 0
	for s in range(n_samples):
		var lo := int(audio[i])
		var hi := int(audio[i + 1])
		var v := (hi << 8) | lo
		if v >= 32768:
			v -= 65536 # to signed
		var f := float(v) / 32768.0

		# stereo frames; use same value on L/R
		tts_playback.push_frame(Vector2(f, f))
		i += 2

func _on_microphone_audio_captured(mono_data) -> void:
	if player_deepgram != null:
		player_deepgram.forward_microphone_audio(mono_data)

func _on_enemy_deepgram_message_received(message) -> void:
	print("Enemy Deepgram: " + message)

	var json := JSON.new()
	var err := json.parse(message)

	if err != OK:
		print("JSON parse failed:", message)
		print("Error:", json.get_error_message(), "at line", json.get_error_line())
		return

	var data = json.data
	
	if not (data is Dictionary):
		return

	if data == null:
		return

	if not data.has("type"):
		return
	
	if data["type"] == "FunctionCallRequest":
		for function in data["functions"]:
			if function["name"] == "build_building":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_building($Enemy, arguments["site_id"], arguments["building_type"])
				enemy_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "build_unit":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_unit($Enemy, arguments["building_id"], arguments["unit_type"])
				enemy_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "set_target_to_cell":
				var arguments = JSON.parse_string(function["arguments"])
				var result = set_target($Enemy, arguments)
				enemy_deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "set_target_to_object":
				var arguments = JSON.parse_string(function["arguments"])
				var result = set_target($Enemy, arguments)
				enemy_deepgram.send_function_call_response(function["name"], result, function["id"])
	elif data["type"] == "ConversationText":
		$ChatCanvas/MarginContainer/HBoxContainer/Enemy.text += str(data["role"], ":")
		$ChatCanvas/MarginContainer/HBoxContainer/Enemy.text += "\n"
		$ChatCanvas/MarginContainer/HBoxContainer/Enemy.text += str(data["content"])
		$ChatCanvas/MarginContainer/HBoxContainer/Enemy.text += "\n"
		$ChatCanvas/MarginContainer/HBoxContainer/Enemy.text += "\n"
		var total_lines = $ChatCanvas/MarginContainer/HBoxContainer/Enemy.get_line_count()
		var max_lines_visible = $ChatCanvas/MarginContainer/HBoxContainer/Enemy.max_lines_visible
		if total_lines > max_lines_visible:
			$ChatCanvas/MarginContainer/HBoxContainer/Enemy.lines_skipped = total_lines - max_lines_visible
		if data["role"] == "assistant":
			$EnemyDecider.push_assistant_message(data["content"])

func _on_enemy_timer_timeout() -> void:
	if enemy_deepgram:
		var world_state = get_world_state()
		$EnemyDecider.make_decision(world_state)

func _on_enemy_decider_decision_made(command: String) -> void:
	print("Enemy made a decision: " + command)
	if enemy_deepgram:
		var world_state = get_world_state()
		enemy_deepgram.replace_prompt($Enemy.team, JSON.stringify(world_state))
		enemy_deepgram.inject_user_message(command)

func _on_enemy_decider_decision_failed(error: String) -> void:
	print("Enemy failed to make a decision: " + error)
