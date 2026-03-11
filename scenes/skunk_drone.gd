extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null

func _physics_process(delta: float) -> void:
	var target_position = null

	if target == null:
		for unit in get_tree().get_nodes_in_group("Unit"):
			if unit.team == team:
				continue
			var distance = global_position.distance_to(unit.global_position)
			if distance < 256:
				target = unit
				break

	if typeof(target) == TYPE_VECTOR2:
		target_position = target
	elif !is_instance_valid(target):
		target = null
		return
	elif target is Node:
		target_position = target.global_position
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
	if "team" in body and body.team == team:
		return

	body.queue_free()
	queue_free()
