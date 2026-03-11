extends CharacterBody2D


const SPEED = 100.0

var team = null
var target = null

func _ready():
	$AnimatedSprite2D.play("default")

func init(initial_team, initial_position):
	global_position = initial_position
	team = initial_team
	
	if team.team == "enemy":
		var mat := $AnimatedSprite2D.material as ShaderMaterial

		mat.set_shader_parameter("pal0", Color("#edb4a1"))
		mat.set_shader_parameter("pal1", Color("#a96868"))
		mat.set_shader_parameter("pal2", Color("#764462"))
		mat.set_shader_parameter("pal3", Color("#2c2137"))

func _physics_process(delta: float) -> void:
	var target_position = null

	if target == null:
		for transmission_tower in get_tree().get_nodes_in_group("TransmissionTower"):
			var distance = global_position.distance_to(transmission_tower.global_position)
			if distance < 256:
				target = transmission_tower
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
	
	if global_position.distance_to(target_position) < 16:
		target = null
