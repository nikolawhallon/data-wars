extends CharacterBody2D


const SPEED = 100.0

@export var team_path: NodePath
var target = null

func init(initial_team_path, initial_position):
	team_path = initial_team_path
	global_position = initial_position

func _ready():
	$AnimatedSprite2D.play("default")
	apply_team_palette()

func apply_team_palette():
	if team_path.is_empty():
		return

	var team = get_node_or_null(team_path)
	if team == null:
		return

	if not team.inverted:
		return

	$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()
	var mat := $AnimatedSprite2D.material as ShaderMaterial
	mat.set_shader_parameter("pal0", Color("#edb4a1"))
	mat.set_shader_parameter("pal1", Color("#a96868"))
	mat.set_shader_parameter("pal2", Color("#764462"))
	mat.set_shader_parameter("pal3", Color("#2c2137"))

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return

	var target_position = null

	if target == null:
		var arena = NodeUtils.get_first_ancestor_in_group_for_node(self, "Arena")
		var transmission_towers = NodeUtils.get_nodes_in_group_for_node(arena, "TransmissionTower")
		for transmission_tower in transmission_towers:
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
