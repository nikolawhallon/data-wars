extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null

func _physics_process(delta: float) -> void:
	var target_position = null
	if target is Node:
		target_position = target.global_position
	elif typeof(target) == TYPE_VECTOR2:
		target_position = target
	else:
		return
		
	var direction = (target_position - position).normalized()
	velocity = direction * SPEED

	move_and_slide()
	
	if global_position.distance_to(target_position) < 16:
		target = null

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body == self:
		return

	body.queue_free()
	queue_free()
