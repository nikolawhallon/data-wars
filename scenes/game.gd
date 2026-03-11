extends Node2D


# CONTEXT LIMIT seems to be only about 3000 characters...
# at about 100 characters per object, that's only ~30 objects worth
# retrieval can be done via a function:
# * key, e.g. skunk_works, extractors, etc
# * cell (optional), e.g. A1, C6, etc

# Tuesday:
# minerals + mining
# initial extractors
# function calls
# * build buildings
# * build units
# * move units
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

var rng = RandomNumberGenerator.new()

# TODO: use this, so that we can destroy and remake as needed
# will require checking for null before using the object
# and setting up signals
var deepgram = null

var map_origin: Vector2
var map_size: Vector2

var tts_generator := AudioStreamGenerator.new()
var tts_playback: AudioStreamGeneratorPlayback

var just_injected_count = 0

func _ready() -> void:
	rng.randomize()

	$CellLabels.init($RandomMap/Walls)
	map_origin = $RandomMap/Walls.get_used_rect().position * $RandomMap/Walls.tile_set.tile_size
	map_size = $RandomMap/Walls.get_used_rect().size * $RandomMap/Walls.tile_set.tile_size
	$CellLabels.spawn_cell_labels()

	$Camera2D.limit_left   = int(map_origin.x)
	$Camera2D.limit_top    = int(map_origin.y)
	$Camera2D.limit_right  = int(map_origin.x + map_size.x)
	$Camera2D.limit_bottom = int(map_origin.y + map_size.y)

	tts_generator.mix_rate = AudioServer.get_mix_rate()
	tts_generator.buffer_length = 60.0
	$TtsPlayer.stream = tts_generator
	$TtsPlayer.play()
	tts_playback = $TtsPlayer.get_stream_playback()

	var extractors_to_spawn = 4
	while extractors_to_spawn > 0:
		var extractor = load("res://scenes/extractor.tscn").instantiate()
		extractor.team = $Player
		var x = randf_range(64.0, 256.0)
		var y = randf_range(64.0, 256.0)
		extractor.global_position = Vector2(x, y)
		add_child(extractor)
		
		extractors_to_spawn -= 1
	
	$Deepgram.initialize("asdf")

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

	if Input.is_action_just_pressed("test"):
		pass

	if Input.is_action_just_pressed("debug"):
		for debug in get_tree().get_nodes_in_group("Debug"):
			debug.visible = !debug.visible

	if Input.is_action_just_pressed("info"):
		for info in get_tree().get_nodes_in_group("Info"):
			info.visible = !info.visible

	if Input.is_action_just_pressed("palette"):
		$PaletteSwapCanvas/PaletteSwap.next_palette()

func _unhandled_input(event):
	# move the camera
	if event is InputEventMouseButton and event.is_pressed():
		var step = 60.0

		if "factor" in event:
			step *= float(event.factor)

		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				$Camera2D.position += Vector2(0, -step)
			MOUSE_BUTTON_WHEEL_DOWN:
				$Camera2D.position += Vector2(0, step)
			MOUSE_BUTTON_WHEEL_LEFT:
				$Camera2D.position += Vector2(-step, 0)
			MOUSE_BUTTON_WHEEL_RIGHT:
				$Camera2D.position += Vector2(step, 0)

	# clamp the camera
	var viewport_size = get_viewport().get_visible_rect().size
	var half_w = viewport_size.x * 0.5 * $Camera2D.zoom.x
	var half_h = viewport_size.y * 0.5 * $Camera2D.zoom.y
	var x = clamp($Camera2D.global_position.x, float($Camera2D.limit_left)+half_w, float($Camera2D.limit_right)-half_w)
	var y = clamp($Camera2D.global_position.y, float($Camera2D.limit_top)+half_h, float($Camera2D.limit_bottom)-half_h)
	$Camera2D.global_position = Vector2(x, y)

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
			"id": int(extractor.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
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
	$UICanvas/MarginContainer/HBoxContainer/Data.text = str($Player.data)

func _on_player_clicks_updated():
	$UICanvas/MarginContainer2/VBoxContainer/HBoxContainer/Clicks.text = str($Player.clicks)

func _on_player_minerals_updated() -> void:
	$UICanvas/MarginContainer/HBoxContainer/Minerals.text = str($Player.minerals)

func build_building(site_id, building_type):
	var site = instance_from_id(site_id)
	if site == null:
		return "No Site with site_id " + str(site_id)

	if not site.is_in_group("Site"):
		return "No Site with site_id " + str(site_id)

	if $Player.minerals < 100:
		return "Buildings cost 100 minerals, Team does not have enough"

	var water = site.get_parent()
	if building_type == "skunk_works":
		var skunk_works = load("res://scenes/skunk_works.tscn").instantiate()
		water.add_child(skunk_works)
		skunk_works.team = $Player
		skunk_works.global_position = site.global_position
		site.queue_free()
	elif building_type == "data_center":
		var data_center = load("res://scenes/data_center.tscn").instantiate()
		water.add_child(data_center)
		data_center.team = $Player
		data_center.global_position = site.global_position
		site.queue_free()
	else:
		return "Invalid building_type"

	$Player.minerals -= 100
	$Player.emit_signal("minerals_updated")

	return "Successfully constructed building"

func build_unit(building_id, unit_type):
	var building = instance_from_id(building_id)
	if building == null:
		return "No building with building_id " + str(building_id)

	if not building.is_in_group("SkunkWorks") and not building.is_in_group("DataCenter"):
		return "No building with building_id " + str(building_id)

	return building.spawn_unit(unit_type)

func set_target(unit_id, target):
	var unit = instance_from_id(unit_id)
	if unit == null:
		return "No unit with unit_id"
	if not unit.is_in_group("Unit"):
		return "No unit with unit_id"

	if target.has("x") and target.has("y"):
		unit.target = Vector2(target["x"], target["y"])
	elif target.has("cell"):
		if not $CellLabels.cell_label_to_pos(target["cell"]):
			return "Invalid cell"
		unit.target = $CellLabels.cell_label_to_pos(target["cell"])
	elif target.has("target_id"):
		var object = instance_from_id(target["target_id"])
		if object == null:
			return "No object with target_id"
		unit.target = object
	else:
		return "No valid target specified"
	
	return "Successfully set the target of the unit"

func _on_deepgram_message_received(message) -> void:
	var data = JSON.parse_string(message)
	
	if not (data is Dictionary):
		return

	if data == null:
		return

	if data.has("type") and data["type"] == "FunctionCallRequest":
		for function in data["functions"]:
			if function["name"] == "build_building":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_building(arguments["site_id"], arguments["building_type"])
				$Deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "build_unit":
				var arguments = JSON.parse_string(function["arguments"])
				var result = build_unit(arguments["building_id"], arguments["unit_type"])
				$Deepgram.send_function_call_response(function["name"], result, function["id"])
			elif function["name"] == "set_target":
				var arguments = JSON.parse_string(function["arguments"])
				var result = set_target(arguments["unit_id"], arguments["target"])
				$Deepgram.send_function_call_response(function["name"], result, function["id"])
	elif data.has("type") and data.has("role") and data.has("content"):
		# we don't want to print the enormous World State
		# that Deepgame will spit back out at us
		# which is in JSON format
		var content = data["content"]
		var result = JSON.new().parse(content)
		if result != OK:
			print(data)
			if data["type"] == "ConversationText":
				$ChatCanvas/Label8.text += str(data["role"], ":")
				$ChatCanvas/Label8.text += "\n"
				$ChatCanvas/Label8.text += str(data["content"])
				$ChatCanvas/Label8.text += "\n"
				$ChatCanvas/Label8.text += "\n"
				var total_lines = $ChatCanvas/Label8.get_line_count()
				var max_lines_visible = $ChatCanvas/Label8.max_lines_visible
				if total_lines > max_lines_visible:
					$ChatCanvas/Label8.lines_skipped = total_lines - max_lines_visible
	else:
		print(data)
	
	if data.get("type") == "UserStartedSpeaking":
		var world_state = get_world_state()
		print("Prompt characters: ", $Deepgram.prompt.length())
		print("World State characters: ", JSON.stringify(world_state).length())
		#if just_injected_count == 0:
		#	$Deepgram.inject_user_message($Deepgram.prompt)
		#	just_injected_count += 1
		#else:
		#	just_injected_count -= 1
		$Deepgram.replace_prompt(JSON.stringify(world_state))

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
func _on_deepgram_binary_packet_received(audio) -> void:
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
