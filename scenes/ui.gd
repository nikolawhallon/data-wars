extends CanvasLayer


func init(team) -> void:
	print("Connecting data_updated signal to the UI")
	team.data_updated.connect(_on_team_data_updated)
	_on_team_data_updated(team.data)

func _on_team_data_updated(value) -> void:
	$LeftMarginContainer/VBoxContainer/HBoxContainer/DataLabel.text = str(value)
