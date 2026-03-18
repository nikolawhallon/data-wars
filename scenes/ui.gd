extends CanvasLayer


func init(first_team, second_team) -> void:
	print("Connecting team data/minerals/clicks update signals to the UI")
	
	var local_human_team = null
	
	if first_team.is_local_human():
		local_human_team = first_team
	elif second_team.is_local_human():
		local_human_team = second_team
	else:
		print("ERROR - no local human team")

	local_human_team.data_updated.connect(_on_local_human_team_data_updated)
	_on_local_human_team_data_updated(local_human_team.data)

	first_team.clicks_updated.connect(_on_first_team_clicks_updated)
	second_team.clicks_updated.connect(_on_second_team_clicks_updated)
	_on_first_team_clicks_updated(first_team.data)
	_on_second_team_clicks_updated(second_team.data)

func _on_local_human_team_data_updated(value) -> void:
	$LeftMarginContainer/VBoxContainer/HBoxContainer/DataLabel.text = str(value)

func _on_first_team_clicks_updated(value) -> void:
	$RightMarginContainer/VBoxContainer/FirstTeam/ClicksLabel.text = str(value)

func _on_second_team_clicks_updated(value) -> void:
	$RightMarginContainer/VBoxContainer/SecondTeam/ClicksLabel.text = str(value)
