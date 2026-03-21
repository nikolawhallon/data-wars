extends Area2D


var match_peer_ids = []

func init(initial_match_peer_ids, initial_global_position):
	match_peer_ids = initial_match_peer_ids
	global_position = initial_global_position

func _is_visible_to_peer(peer_id: int) -> bool:
	return match_peer_ids.has(peer_id)

func _ready():
	$MultiplayerSynchronizer.add_visibility_filter(_is_visible_to_peer)
	$MultiplayerSynchronizer.update_visibility()
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if not body.is_in_group("SpamBot"):
		return
	
	var team = get_node(body.team_path)
	team.clicks += 1
	body.queue_free()
