extends CharacterBody2D


const SPEED = 100.0

@export var net_id = -1
@export var team_net_id = -1
@export var target_net_id = -1
@export var target_position = Vector2.ZERO

func init(initial_net_id, initial_team_net_id, initial_position):
	net_id = initial_net_id
	team_net_id = initial_team_net_id
	global_position = initial_position

func _ready():
	var app = get_node("/root/App")
	app.register_net_node(net_id, self)

	$AnimatedSprite2D.play("default")
	apply_team_palette()

func apply_team_palette():
	var app = get_node("/root/App")
	var team = app.get_node_for_net_id(team_net_id)

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

	var actual_target_position = null

	if target_net_id != -1:
		var target_node = get_node("/root/App").get_node_for_net_id(target_net_id)
		if is_instance_valid(target_node):
			actual_target_position = target_node.global_position
		else:
			# the target node was likely destroyed
			target_net_id = -1

	if actual_target_position == null and target_position != Vector2.ZERO:
		actual_target_position = target_position

	if actual_target_position == null:
		var arena = NodeUtils.get_first_ancestor_in_group_for_node(self, "Arena")
		var transmission_towers = NodeUtils.get_nodes_in_group_for_node(arena, "TransmissionTower")
		for transmission_tower in transmission_towers:
			var distance = global_position.distance_to(transmission_tower.global_position)
			if distance < 256:
				target_net_id = transmission_tower.net_id
				actual_target_position = transmission_tower.global_position
				break

	if actual_target_position == null:
		return

	var direction = (actual_target_position - position).normalized()
	velocity = direction * SPEED

	move_and_slide()

	if velocity.x > 0:
		$AnimatedSprite2D.flip_h = true
	elif velocity.x < 0:
		$AnimatedSprite2D.flip_h = false

	if global_position.distance_to(actual_target_position) < 16:
		target_net_id = -1
		target_position = Vector2.ZERO
