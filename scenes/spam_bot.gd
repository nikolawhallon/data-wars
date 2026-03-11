extends CharacterBody2D


const SPEED = 100.0

var team = null
var target = null

func _physics_process(delta: float) -> void:
	var target_position = null

	if target == null:
		for transmission_tower in get_tree().get_nodes_in_group("TransmissionTower"):
			var distance = global_position.distance_to(transmission_tower.global_position)
			if distance < 256:
				target = transmission_tower
			if distance < 16:
				target = null
				break

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
