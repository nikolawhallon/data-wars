extends Node


signal minerals_updated
signal data_updated
signal clicks_updated

var type = ""
var id = -1
var inverted = false

@export var minerals := 0:
	set(value):
		if minerals == value:
			return
		minerals = value
		minerals_updated.emit(minerals)

@export var data := 0:
	set(value):
		if data == value:
			return
		data = value
		data_updated.emit(data)

@export var clicks := 0:
	set(value):
		if clicks == value:
			return
		clicks = value
		clicks_updated.emit(clicks)

func _ready() -> void:
	if is_local_human():
		$Camera2D.make_current()

func _process(delta: float) -> void:
	if not is_local_human():
		return

	var speed = 1000.0
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	$Camera2D.global_position += dir * speed * delta

func is_local_human():
	return type == "human" and id == multiplayer.get_unique_id()
