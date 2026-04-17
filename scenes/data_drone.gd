extends CharacterBody2D


const SPEED = 300.0

var team = null
var target = null
var data_center_at = null

func init(initial_team, initial_position):
	global_position = initial_position
	team = initial_team

	$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()
	var mat := $AnimatedSprite2D.material as ShaderMaterial

	if team.team == "player":
		mat.set_shader_parameter("pal0", Color("#2c2137"))
		mat.set_shader_parameter("pal1", Color("#764462"))
		mat.set_shader_parameter("pal2", Color("#a96868"))
		mat.set_shader_parameter("pal3", Color("#edb4a1"))

	if team.team == "enemy":
		mat.set_shader_parameter("pal0", Color("#edb4a1"))
		mat.set_shader_parameter("pal1", Color("#a96868"))
		mat.set_shader_parameter("pal2", Color("#764462"))
		mat.set_shader_parameter("pal3", Color("#2c2137"))

func _physics_process(_delta: float) -> void:
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

	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = true
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = false

	if collecting():
		$AnimatedSprite2D.play("collecting")
	else:
		$AnimatedSprite2D.play("default")

	if global_position.distance_to(target_position) < 16:
		target = null

func collecting():
	if data_center_at:
		return true
	else:
		return false

func _on_area_2d_area_entered(area: Area2D) -> void:
	if area.is_in_group("DataCenter"):
		data_center_at = area

func _on_area_2d_area_exited(area: Area2D) -> void:
	if area == data_center_at:
		data_center_at = null

func _on_data_timer_timeout() -> void:
	if data_center_at != null:
		var water = data_center_at.get_parent()
		var consumed = water.decrement(1)
		if team != null:
			team.data += consumed
			team.data_updated.emit()
