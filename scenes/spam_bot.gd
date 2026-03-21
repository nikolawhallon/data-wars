extends CharacterBody2D


const SPEED = 100.0

@export var team_path: NodePath
# only the server will have this set correctly
# as only the server needs to move units
var target = null

# TODO: extract this into some utils
func get_arena() -> Node:
	var candidate: Node = self
	while candidate != null:
		if candidate.is_in_group("Arena"):
			return candidate
		candidate = candidate.get_parent()
	return null

var match_peer_ids = []

func _is_visible_to_peer(peer_id: int) -> bool:
	return match_peer_ids.has(peer_id)

func init(initial_match_peer_ids, initial_team_path, initial_position):
	match_peer_ids = initial_match_peer_ids
	team_path = initial_team_path
	global_position = initial_position

func _ready():
	$MultiplayerSynchronizer.add_visibility_filter(_is_visible_to_peer)
	$MultiplayerSynchronizer.update_visibility()
	$AnimatedSprite2D.play("default")
	apply_team_palette()

func apply_team_palette() -> void:
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
		for transmission_tower in get_arena().find_in_subtree("TransmissionTower"):
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
