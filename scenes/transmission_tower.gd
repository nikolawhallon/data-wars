extends Area2D


var match_peer_ids = []

func init(match_peer_ids, initial_global_position):
	$MatchVisibility.init(match_peer_ids)
	global_position = initial_global_position

func _ready():
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if not body.is_in_group("SpamBot"):
		return
	
	var team = get_node(body.team_path)
	team.clicks += 1
	body.queue_free()
