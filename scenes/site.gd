extends Sprite2D


@export var water_path: NodePath

func init(initial_water_path, initial_global_position):
	water_path = initial_water_path
	global_position = initial_global_position
