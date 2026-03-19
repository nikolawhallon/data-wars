extends AnimatedSprite2D


func _ready() -> void:
	play("default")

func _on_animation_finished() -> void:
	if not multiplayer.is_server():
		return

	queue_free()
