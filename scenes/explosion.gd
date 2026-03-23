extends AnimatedSprite2D


@export var net_id = -1

func init(initial_net_id, initial_global_position):
	net_id = initial_net_id
	global_position = initial_global_position

func _ready() -> void:
	var app = get_node("/root/App")
	app.register_net_node(net_id, self)

	play("default")

func _on_animation_finished() -> void:
	if not multiplayer.is_server():
		return

	queue_free()
