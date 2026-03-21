extends Area2D


func init(match_peer_ids, initial_global_position):
	$MatchVisibility.init(match_peer_ids)
	global_position = initial_global_position
