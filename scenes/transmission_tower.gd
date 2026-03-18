extends Area2D


func _ready():
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if not body.is_in_group("SpamBot"):
		return
	
	var team = get_node(body.team_path)
	team.clicks += 1
	get_tree().get_current_scene().announce_queue_free_node.rpc(body.get_path())
