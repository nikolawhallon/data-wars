extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null
var mine = null

func _physics_process(delta: float) -> void:
	var target_position = null

	if target == null:
		for mine in get_tree().get_nodes_in_group("Mine"):
			var distance = global_position.distance_to(mine.global_position)
			if distance < 256:
				target = mine
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

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("Mine"):
		mine = area

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area == mine:
		mine = null

func _on_mine_timer_timeout() -> void:
	if mine != null:
		var consumed = mine.decrement(1)
		if team != null:
			team.minerals += consumed
			team.minerals_updated.emit()
