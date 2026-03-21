extends Sprite2D


@export var water_path: NodePath


func init(match_peer_ids, initial_water_path, initial_global_position):
	$MatchVisibility.init(match_peer_ids)
	water_path = initial_water_path
	global_position = initial_global_position
