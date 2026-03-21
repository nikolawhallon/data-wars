extends AnimatedSprite2D


signal liters_updated

@export var liters: int = 600:
	set(value):
		liters = max(value, 0)
		liters_updated.emit(liters)

var match_peer_ids = []

func init(initial_match_peer_ids, initial_global_position):
	match_peer_ids = initial_match_peer_ids
	global_position = initial_global_position

func _is_visible_to_peer(peer_id: int) -> bool:
	return match_peer_ids.has(peer_id)

func _ready():
	$MultiplayerSynchronizer.add_visibility_filter(_is_visible_to_peer)
	$MultiplayerSynchronizer.update_visibility()

func decrement(amount):
	var consumed = min(liters, amount)
	liters -= consumed

	if liters == 0:
		frame = 3
	elif liters < 200:
		frame = 2
	elif liters < 400:
		frame = 1
			
	return consumed
