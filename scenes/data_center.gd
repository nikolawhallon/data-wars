extends Sprite2D


var rng = RandomNumberGenerator.new()

var team = null
var producing = null

func _ready() -> void:
	rng.randomize()

func _on_water_timer_timeout() -> void:
	var water = get_parent()
	var consumed = water.decrement(1)
	team.data += consumed
	team.data_updated.emit()

func _on_unit_timer_timeout() -> void:
	if producing == "spam_bot":
		var spam_bot = load("res://scenes/spam_bot.tscn").instantiate()
		spam_bot.team = team
		spam_bot.global_position = global_position + Vector2(rng.randf_range(-64.0, 64.0), rng.randf_range(-64.0, 64.0))
		get_tree().get_current_scene().add_child(spam_bot)

	producing = null

func spawn_unit(type):
	if producing:
		print("WARN - this Data Center is already producing a ", producing)
		return "Unable to build unit: Data Center alreading producing a unit"

	if type != "spam_bot":
		return "Unable to build unit: Data Centers can only produce Spam Bots (spam_bot)"

	if team.data < 10:
		return "Spam Bots require 10 Data to build, Team does not have enough Data"

	team.data -= 10
	team.data_updated.emit()
	
	producing = type
	$UnitTimer.start()
	return "Successfully started building unit"
