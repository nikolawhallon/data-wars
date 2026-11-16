extends CharacterBody2D


const SPEED = 300.0

@export var team_path: NodePath
@export var target_path: NodePath
@export var target_position = Vector2.ZERO

func init(initial_team_path, initial_position):
	team_path = initial_team_path
	global_position = initial_position

func _ready():
	apply_team_palette()

func apply_team_palette():
	var team = get_node(team_path)

	if not team.inverted:
		return

	$Sprite2D.material = $Sprite2D.material.duplicate()
	var mat := $Sprite2D.material as ShaderMaterial
	mat.set_shader_parameter("pal0", Color("#edb4a1"))
	mat.set_shader_parameter("pal1", Color("#a96868"))
	mat.set_shader_parameter("pal2", Color("#764462"))
	mat.set_shader_parameter("pal3", Color("#2c2137"))

func _physics_process(_delta: float) -> void:
	if not multiplayer.is_server():
		return

	var actual_target_position = null

	if target_path != NodePath():
		var target_node = get_node(target_path)
		if is_instance_valid(target_node):
			actual_target_position = target_node.global_position
		else:
			# the target node was likely destroyed
			target_path = NodePath()

	if actual_target_position == null and target_position != Vector2.ZERO:
		actual_target_position = target_position

	if actual_target_position == null:
		var arena = NodeUtils.get_first_ancestor_in_group_for_node(self, "Arena")
		for unit in NodeUtils.get_nodes_in_group_for_node(arena, "Unit"):
			if unit.team_path == team_path:
				continue
			var distance = global_position.distance_to(unit.global_position)
			if distance < 256:
				target_path = unit.get_path()
				actual_target_position = unit.global_position
				break

	if actual_target_position == null:
		return

	var direction = (actual_target_position - position).normalized()
	velocity = direction * SPEED

	move_and_slide()

	if velocity.x > 0:
		$Sprite2D.flip_h = true
	elif velocity.x < 0:
		$Sprite2D.flip_h = false

	if global_position.distance_to(actual_target_position) < 16:
		target_path = NodePath()
		target_position = Vector2.ZERO

func _on_area_2d_body_entered(body: Node2D) -> void:
	if not multiplayer.is_server():
		return

	if body == self or is_queued_for_deletion():
		return

	if not body.is_in_group("Unit") or body.team_path == team_path:
		return

	for pos in [global_position, body.global_position]:
		var explosion = load("res://scenes/explosion.tscn").instantiate()
		explosion.init(pos)
		get_parent().add_child(explosion, true)

	body.queue_free()
	queue_free()
