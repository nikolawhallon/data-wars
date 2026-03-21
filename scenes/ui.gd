extends CanvasLayer


func init(non_inverted_team, inverted_team):
	print("Connecting team data/minerals/clicks update signals to the UI")
	
	var local_human_team = null

	if non_inverted_team.is_local_human():
		local_human_team = non_inverted_team
	elif inverted_team.is_local_human():
		local_human_team = inverted_team
	else:
		print("ERROR - no local human team")

	local_human_team.data_updated.connect(_on_local_human_team_data_updated)
	_on_local_human_team_data_updated(local_human_team.data)

	non_inverted_team.clicks_updated.connect(_on_non_inverted_team_clicks_updated)
	inverted_team.clicks_updated.connect(_on_inverted_team_clicks_updated)
	_on_non_inverted_team_clicks_updated(non_inverted_team.data)
	_on_inverted_team_clicks_updated(inverted_team.data)

func _on_local_human_team_data_updated(value) -> void:
	$LeftMarginContainer/VBoxContainer/HBoxContainer/DataLabel.text = str(value)

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
