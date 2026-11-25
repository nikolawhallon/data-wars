extends CharacterBody2D


const SPEED = 300.0

@export var team_path: NodePath
@export var target_path: NodePath
@export var target_position = Vector2.ZERO
@export var collecting := false:
	set(value):
		if collecting == value:
			return
		collecting = value
		update_animation()

var data_center_at = null

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
	if collecting:
		$AnimatedSprite2D.play("collecting")
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
		for data_center in NodeUtils.get_nodes_in_group_for_node(arena, "DataCenter"):
			if data_center.team_path == team_path:
				continue
			var distance = global_position.distance_to(data_center.global_position)
			if distance < 256:
				target_path = data_center.get_path()
				actual_target_position = data_center.global_position
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

	if area.is_in_group("DataCenter") and area.team_path != team_path:
		data_center_at = area
		collecting = true
		_on_data_timer_timeout()
		$DataTimer.start()

func _on_area_2d_area_exited(area: Area2D) -> void:
	if not multiplayer.is_server():
		return

	if area == data_center_at:
		data_center_at = null
		collecting = false

func _on_data_timer_timeout() -> void:
	if not multiplayer.is_server():
		return

	if not is_instance_valid(data_center_at):
		return

	var water = get_node(data_center_at.water_path)
	if water.liters <= 0:
		return

	var team = get_node(team_path)
	var enemy_team = get_node(data_center_at.team_path)

	var stolen = min(enemy_team.data, 1)
	enemy_team.data -= stolen
	team.data += stolen
