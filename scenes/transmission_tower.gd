extends Area2D


func _ready():
	$AnimatedSprite2D.play("default")

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("SpamBot"):
		if body.team != null:
			body.team.clicks += 1
			body.team.clicks_updated.emit()
			body.queue_free()
