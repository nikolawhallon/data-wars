extends CanvasLayer


func connect_signals(teams):
	print("Connecting team data/minerals/clicks update signals to the UI")
	
	assert(len(teams) == 2)

	var inverted_team = null
	var non_inverted_team = null

	if teams[0].inverted:
		inverted_team = teams[0]
		non_inverted_team = teams[1]
	else:
		inverted_team = teams[1]
		non_inverted_team = teams[0]

	var local_human_team = null

	if non_inverted_team.type == "human" and non_inverted_team.peer_id == multiplayer.get_unique_id():
		local_human_team = non_inverted_team
	elif inverted_team.type == "human" and inverted_team.peer_id == multiplayer.get_unique_id():
		local_human_team = inverted_team
	else:
		# expected on a headless server, which has no team of its own
		print("WARN - no local human team")

	if local_human_team != null:
		local_human_team.data_updated.connect(_on_local_human_team_data_updated)
		_on_local_human_team_data_updated(local_human_team.data)
		local_human_team.minerals_updated.connect(_on_local_human_team_minerals_updated)
		_on_local_human_team_minerals_updated(local_human_team.minerals)

	non_inverted_team.clicks_updated.connect(_on_non_inverted_team_clicks_updated)
	inverted_team.clicks_updated.connect(_on_inverted_team_clicks_updated)
	_on_non_inverted_team_clicks_updated(non_inverted_team.clicks)
	_on_inverted_team_clicks_updated(inverted_team.clicks)

func _on_local_human_team_data_updated(value) -> void:
	$LeftMarginContainer/VBoxContainer/HBoxContainer/DataLabel.text = str(value)

func _on_local_human_team_minerals_updated(value) -> void:
	$LeftMarginContainer/VBoxContainer/HBoxContainer/MineralsLabel.text = str(value)

func _on_non_inverted_team_clicks_updated(value) -> void:
	$RightMarginContainer/VBoxContainer/NonInvertedTeam/ClicksLabel.text = str(value)

func _on_inverted_team_clicks_updated(value) -> void:
	$RightMarginContainer/VBoxContainer/InvertedTeam/ClicksLabel.text = str(value)

func show_game_over(won):
	if won:
		$GameOverLabel.text += "\n\nYOU WIN"
	else:
		$GameOverLabel.text += "\n\nYOU LOSE"
	$GameOverLabel.visible = true
