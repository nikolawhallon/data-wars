extends Sprite2D


@export var water_path: NodePath

var match_peer_ids = []

func init(initial_match_peer_ids, initial_water_path, initial_global_position):
	match_peer_ids = initial_match_peer_ids
	water_path = initial_water_path
	global_position = initial_global_position

func _is_visible_to_peer(peer_id: int) -> bool:
	return match_peer_ids.has(peer_id)

func _ready():
	$MultiplayerSynchronizer.add_visibility_filter(_is_visible_to_peer)
	$MultiplayerSynchronizer.update_visibility()
