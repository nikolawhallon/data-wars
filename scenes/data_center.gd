extends Sprite2D


signal data_updated

var rng = RandomNumberGenerator.new()

var team = null
var producing = null

func _ready() -> void:
	rng.randomize()

func _on_water_timer_timeout() -> void:
	var water = get_parent()
	var consumed = water.decrement(1)
	team.data += consumed
	data_updated.emit(team)

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

	if team.data < 10:
		return "Unable to build unit: not enough Data available - try again later"

	team.data -= 10
	data_updated.emit(team)
	
	producing = type
	$UnitTimer.start()
	return "Successfully building unit"
