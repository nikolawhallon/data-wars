extends CharacterBody2D


const SPEED = 300.0

@export var team_path: NodePath
@export var target_path: NodePath
@export var target_position = Vector2.ZERO
@export var mining := false:
	set(value):
		if mining == value:
			return
		mining = value
		update_animation()

var mine_at = null

func init(initial_team_path, initial_position):
	team_path = initial_team_path
	global_position = initial_position

func _ready():
	update_animation()
	apply_team_palette()

func apply_team_palette():
	var team = get_node(team_path)

	if not team.inverted:
		return

	$AnimatedSprite2D.material = $AnimatedSprite2D.material.duplicate()
	var mat := $AnimatedSprite2D.material as ShaderMaterial
	mat.set_shader_parameter("pal0", Color("#edb4a1"))
	mat.set_shader_parameter("pal1", Color("#a96868"))
	mat.set_shader_parameter("pal2", Color("#764462"))
	mat.set_shader_parameter("pal3", Color("#2c2137"))

func update_animation() -> void:
	if mining:
		$AnimatedSprite2D.play("mining")
	else:
		$AnimatedSprite2D.play("default")

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
		for mine in NodeUtils.get_nodes_in_group_for_node(arena, "Mine"):
			var distance = global_position.distance_to(mine.global_position)
			if distance < 256:
				target_path = mine.get_path()
				actual_target_position = mine.global_position
			if distance < 16:
				target_path = NodePath()
				actual_target_position = null
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
		target_path = NodePath()
		target_position = Vector2.ZERO

func _on_area_2d_area_entered(area: Area2D) -> void:
	if not multiplayer.is_server():
		return

	if area.is_in_group("Mine"):
		mine_at = area
		mining = true

func _on_area_2d_area_exited(area: Area2D) -> void:
	if not multiplayer.is_server():
		return

	if area == mine_at:
		mine_at = null
		mining = false

func _on_mine_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	if mine_at == null:
		return

	var team = get_node(team_path)
	team.minerals += 1
