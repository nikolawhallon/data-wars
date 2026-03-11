extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null

func _physics_process(delta: float) -> void:
	var target_position = null

	if target == null:
		for data_center in get_tree().get_nodes_in_group("DataCenter"):
			if data_center.team == team:
				continue
			var distance = global_position.distance_to(data_center.global_position)
			if distance < 256:
				target = data_center
			if distance < 16:
				target = null
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
