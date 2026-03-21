extends Node


var match_peer_ids = []
var test = []

func init(initial_match_peer_ids):
	match_peer_ids = initial_match_peer_ids

func _ready():
	test = match_peer_ids
	if multiplayer.is_server():
		# MatchVisibility assumed to always be sibling of MultiplayerSynchronizer
		var sync = get_parent().get_node("MultiplayerSynchronizer")
		sync.add_visibility_filter(_is_visible_to_peer)
		sync.update_visibility()

func _is_visible_to_peer(peer_id):
	return test.has(peer_id)
