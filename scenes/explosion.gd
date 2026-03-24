extends AnimatedSprite2D


func init(initial_global_position):
	global_position = initial_global_position

func _ready() -> void:
	play("default")

func _on_animation_finished() -> void:
	if not multiplayer.is_server():
		return

	queue_free()
