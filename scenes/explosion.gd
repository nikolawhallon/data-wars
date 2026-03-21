extends AnimatedSprite2D

var match_peer_ids = []

func init(initial_match_peer_ids, initial_global_position):
	match_peer_ids = initial_match_peer_ids
	global_position = initial_global_position

func _is_visible_to_peer(peer_id: int) -> bool:
	return match_peer_ids.has(peer_id)

func _ready() -> void:
	$MultiplayerSynchronizer.add_visibility_filter(_is_visible_to_peer)
	$MultiplayerSynchronizer.update_visibility()

	play("default")

func _on_animation_finished() -> void:
	if not multiplayer.is_server():
		return

	queue_free()
