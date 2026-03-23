extends Node


func _ready():
	if multiplayer.is_server():
		# MatchVisibility assumed to always be sibling of MultiplayerSynchronizer
		var sync = get_parent().get_node("MultiplayerSynchronizer")
		sync.add_visibility_filter(_is_visible_to_peer)
		sync.update_visibility()

func _is_visible_to_peer(peer_id):
	var app = get_node("/root/App")
	var arena = NodeUtils.get_first_ancestor_in_group_for_node(self, "Arena")
	var match_peer_ids = app.get_peer_ids_for_match(arena.match_id)
	return match_peer_ids.has(peer_id)
