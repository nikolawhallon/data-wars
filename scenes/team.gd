extends Node


signal minerals_updated
signal data_updated
signal clicks_updated

@export var type = ""
@export var peer_id = -1
@export var inverted = false

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

func init(initial_peer_id, initial_type, initial_inverted):
	peer_id = initial_peer_id
	type = initial_type
	inverted = initial_inverted
