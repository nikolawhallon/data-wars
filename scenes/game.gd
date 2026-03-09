extends Node2D


# CONTEXT LIMIT seems to be only about 3000 characters...
# at about 100 characters per object, that's only ~30 objects worth
# retrieval can be done via a function:
# * key, e.g. skunk_works, extractors, etc
# * cell (optional), e.g. A1, C6, etc

# Tuesday:
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
# have skunk works produce the skunk drones on a timer (no queues yet)
# * producing
# * time_remaining
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
		var sites = get_tree().get_nodes_in_group("Site")
		for site in sites:
			var water = site.get_parent()
			if rng.randf() < 0.5:
				var skunk_works = load("res://scenes/skunk_works.tscn").instantiate()
				water.add_child(skunk_works)
				skunk_works.global_position = site.global_position
				site.queue_free()
			else:
				var data_center = load("res://scenes/data_center.tscn").instantiate()
				water.add_child(data_center)
				data_center.global_position = site.global_position
				site.queue_free()
			#break

		var all_skunk_works = get_tree().get_nodes_in_group("SkunkWorks")
		for skunk_works in all_skunk_works:
			var skunk_drone = load("res://scenes/skunk_drone.tscn").instantiate()
			skunk_drone.global_position = skunk_works.global_position
			skunk_drone.target = $CellLabels.cell_label_to_pos("B2")
			add_child(skunk_drone)

			var data_drone = load("res://scenes/data_drone.tscn").instantiate()
			data_drone.global_position = skunk_works.global_position
			data_drone.target = $CellLabels.cell_label_to_pos("C3")
			add_child(data_drone)

		var data_centers = get_tree().get_nodes_in_group("DataCenter")
		for data_center in data_centers:
			var spam_bot = load("res://scenes/spam_bot.tscn").instantiate()
			spam_bot.global_position = data_center.global_position
			spam_bot.target = Vector2(-128.0, -128.0)
			add_child(spam_bot)

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
	var water_array: Array = []
	var sites_array: Array = []
	var skunk_works_array: Array = []
	var data_center_array: Array = []
	var skunk_drone_array: Array = []

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
		sites_array.append({
			"id": int(site.get_instance_id()),
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
			"cell": $CellLabels.pos_to_cell_label(p)
		})

	for data_center in get_tree().get_nodes_in_group("DataCenter"):
		var p: Vector2 = data_center.global_position
		data_center_array.append({
			"id": int(data_center.get_instance_id()),
			"position": {
				"x": p.x,
				"y": p.y
			},
			"cell": $CellLabels.pos_to_cell_label(p)
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
		"waters": water_array,
		"sites": sites_array,
		"skunk_works": skunk_works_array,
		"data_centers": data_center_array,
		"skunk_drones": skunk_drone_array
	}

	return world_state

func _on_deepgram_message_received(message) -> void:
	var data = JSON.parse_string(message)

	if not (data is Dictionary):
		return

	if data == null:
		return

	# we don't want to print the enormous World State
	# that Deepgame will spit back out at us
	if data.has("type") and data.has("role") and data.has("content"):
		var content = data["content"]
		var result = JSON.new().parse(content)
		if result != OK:
			print(data)
			if data["type"] == "ConversationText":
				# TODO: this is really "debug" while
				# most other labels are more "info"
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
		if just_injected_count == 0:
			var world_state = get_world_state()
			print("Prompt characters: ", $Deepgram.prompt.length())
			print("World State characters: ", JSON.stringify(world_state).length())

			$Deepgram.inject_user_message(JSON.stringify(world_state))
			just_injected_count += 1

			# the following shows how I might extract just pieces of the world state, eventually
			# in fact, I might want to inject just the world state keys,
			# and have the LLM decide which info it wants to retrieve
			#for key in world_state.keys():
			#	var sub_state = { key: world_state[key] }
			#	print(key, " characters: ", JSON.stringify(sub_state).length())
			#	$Deepgram.inject_user_message(JSON.stringify(sub_state))
			#	just_injected_count += 1
		else:
			just_injected_count -= 1
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
