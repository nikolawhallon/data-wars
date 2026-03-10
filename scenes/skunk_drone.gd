extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null

func _physics_process(delta: float) -> void:
	if target == null:
		return

	var direction = (target - position).normalized()
	velocity = direction * SPEED

	move_and_slide()
	
	if global_position.distance_to(target) < 32:
		target = null

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		return

	body.queue_free()
	queue_free()
