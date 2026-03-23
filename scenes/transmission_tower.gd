extends Area2D


@export var net_id = -1

func init(initial_net_id, initial_global_position):
	net_id = initial_net_id
	global_position = initial_global_position

func _ready():
	var app = get_node("/root/App")
	app.register_net_node(net_id, self)

	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if not body.is_in_group("SpamBot"):
		return
	
	var team = get_node("/root/App").get_node_for_net_id(body.team_net_id)
	team.clicks += 1
	body.queue_free()
