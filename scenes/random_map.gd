extends Node2D

@export var map_w            = 2 * 200 / 4
@export var map_h            = 2 * 120 / 4
@export var ground_seed      = 0.7
@export var wall_condition   = 4
@export var ground_condition = 4

enum Tiles { GROUND, WALL }

var GROUND = Vector2i(10, 1)
var WALL = Vector2i(12, 0)
var BLACK = Vector2i(9, 2)

var TW_LW_BW = Vector2i(0, 0)
var TW_LW_BRC = Vector2i(1, 0)
var TW_BLC_BRC = Vector2i(2, 0)
var TW_RW_BLC = Vector2i(3, 0)
var TRC_BLC_BRC = Vector2i(4, 0)
var TW_BLC = Vector2i(5, 0)
var TW_BRC = Vector2i(6, 0)
var TLC_BLC_BRC = Vector2i(7, 0)
var TW_LW = Vector2i(8, 0)
var TLC_TRC = Vector2i(9, 0)
var TW = Vector2i(10, 0)
var TW_RW = Vector2i(11, 0)

var LW_RW = Vector2i(0, 1)
var LW_TRC_BRC = Vector2i(1, 1)
var TLC_TRC_BLC_BRC = Vector2i(2, 1)
var RW_TLC_BLC = Vector2i(3, 1)
var LW_TRC = Vector2i(4, 1)
var TLC = Vector2i(5, 1)
var TRC = Vector2i(6, 1)
var RW_TLC = Vector2i(7, 1)
var LW = Vector2i(8, 1)
var TLC_BRC = Vector2i(9, 1)
var TRC_BRC = Vector2i(11, 1)

var BW_LW_RW = Vector2i(0, 2)
var BW_LW_TRC = Vector2i(1, 2)
var BW_TLC_TRC = Vector2i(2, 2)
var BW_RW_TLC = Vector2i(3, 2)
var LW_BRC = Vector2i(4, 2)
var BLC = Vector2i(5, 2)
var BRC = Vector2i(6, 2)
var RW_BLC = Vector2i(7, 2)
var TLC_BLC = Vector2i(8, 2)
var TRC_BLC = Vector2i(10, 2)
var RW = Vector2i(11, 2)

var TW_BW_LW_RW = Vector2i(0, 3)
var TW_BW_LW = Vector2i(1, 3)
var TW_BW = Vector2i(2, 3)
var TW_BW_RW = Vector2i(3, 3)
var TLC_TRC_BRC = Vector2i(4, 3)
var BW_TLC = Vector2i(5, 3)
var BW_TRC = Vector2i(6, 3)
var TLC_TRW_BLC = Vector2i(7, 3)
var BW_LW = Vector2i(8, 3)
var BW = Vector2i(9, 3)
var BLC_BRC = Vector2i(10, 3)
var BW_RW = Vector2i(11, 3)

var FACE = WALL

var tiles = []

var biggest_cave

var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	
	for _x in range(0, map_w):
		var column = []
		column.resize(map_h)
		tiles.append(column)

	print("Generating map")
	generate()

func generate():
	$Walls.clear()
	$Ground.clear()
	fill_wall()
	random_ground()
	double_vertically()
	dig_caves()
	get_biggest_cave()
	remove_vertical_singles()
	convert_tile_array_to_tilemap()

	var tile_size = Vector2($Walls.tile_set.tile_size)
	var map_origin = Vector2($Walls.get_used_rect().position) * tile_size
	#var map_size = Vector2($Walls.get_used_rect().size) * tile_size

	var mine_number = 3
	var mines = []
	while mine_number > 0:
		var mine = load("res://scenes/mine.tscn").instantiate()
		add_child(mine)

		while true:
			var x = rng.randi_range(1, map_w - 1)
			var y = rng.randi_range(1, map_h - 1)
			if !is_ground_block(x, y, 1):
				continue

			var pos = map_origin + tile_size / 2 + Vector2(x, y) * tile_size
			var collision = false
			for other_mine in mines:
				if other_mine != mine:
					if abs(other_mine.global_position.x - pos.x) < tile_size.x * 9:
						if abs(other_mine.global_position.y - pos.y) < tile_size.y * 9:
							collision = true
			if collision:
				continue
				
			mine.global_position = pos

			break
			
		mine_number -= 1
		mines.append(mine)

	var water_number = 6
	var waters = []
	while water_number > 0:
		var water = load("res://scenes/water.tscn").instantiate()
		add_child(water)

		while true:
			var x = rng.randi_range(1, map_w - 1)
			var y = rng.randi_range(1, map_h - 1)
			if !is_ground_block(x, y, 1):
				continue

			var pos = map_origin + tile_size / 2 + Vector2(x, y) * tile_size
			var collision = false
			for mine in mines:
				if abs(mine.global_position.x - pos.x) < tile_size.x * 9:
					if abs(mine.global_position.y - pos.y) < tile_size.y * 9:
							collision = true
			for other_water in waters:
				if other_water != water:
					if abs(other_water.global_position.x - pos.x) < tile_size.x * 9:
						if abs(other_water.global_position.y - pos.y) < tile_size.y * 9:
							collision = true
			if collision:
				continue

			water.global_position = pos

			var site_number = 0
			if is_ground_block(x - 3, y, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				water.add_child(site)
				site.global_position = map_origin + tile_size / 2 + Vector2(x - 3, y) * tile_size
				site_number += 1
			if is_ground_block(x + 3, y, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				water.add_child(site)
				site.global_position = map_origin + tile_size / 2 + Vector2(x + 3, y) * tile_size
				site_number += 1
			if is_ground_block(x, y - 3, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				water.add_child(site)
				site.global_position = map_origin + tile_size / 2 + Vector2(x, y - 3) * tile_size
				site_number += 1
			if is_ground_block(x, y + 3, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				water.add_child(site)
				site.global_position = map_origin + tile_size / 2 + Vector2(x, y + 3) * tile_size
				site_number += 1

			if site_number == 0:
				continue
			
			break
			
		water_number = water_number - 1
		waters.append(water)

	var transmission_tower_number = 4
	var transmission_towers = []
	while transmission_tower_number > 0:
		var transmission_tower = load("res://scenes/transmission_tower.tscn").instantiate()
		add_child(transmission_tower)

		while true:
			var x = rng.randi_range(1, map_w - 1)
			var y = rng.randi_range(1, map_h - 1)
			if !is_black(x, y):
				continue

			var pos = map_origin + tile_size / 2 + Vector2(x, y) * tile_size
			var collision = false
			for other_transmission_tower in transmission_towers:
				if other_transmission_tower != transmission_tower:
					if abs(other_transmission_tower.global_position.x - pos.x) < tile_size.x * 1:
						if abs(other_transmission_tower.global_position.y - pos.y) < tile_size.y * 1:
							collision = true
			if collision:
				continue
				
			transmission_tower.global_position = pos
			
			break
			
		transmission_tower_number = transmission_tower_number - 1
		transmission_towers.append(transmission_tower)
		
func fill_wall():
	for x in range(0, map_w):
		for y in range(0, map_h):
			tiles[x][y] = Tiles.WALL

func random_ground():
	for x in range(3, map_w - 3):
		for y in range(3, map_h - 3):
			if rng.randf() < ground_seed:
				tiles[x][y] = Tiles.GROUND

func double_vertically():
	for x in range(1, map_w - 1):
		for y in range(1, map_h - 1):
			if tiles[x][y] == Tiles.WALL:
				if tiles[x][y - 1] != Tiles.WALL and tiles[x][y + 1] != Tiles.WALL:
					tiles[x][y + 1] = Tiles.WALL

func remove_vertical_singles():
	for x in range(1, map_w - 1):
		for y in range(1, map_h - 1):
			if tiles[x][y] == Tiles.WALL:
				if tiles[x][y - 1] != Tiles.WALL and tiles[x][y + 1] != Tiles.WALL:
					tiles[x][y] = Tiles.GROUND

func dig_caves():
	for _i in range(10):
		for x in range(1, map_w - 1):
			for y in range(1, map_h - 1):
				if check_nearby_walls(x, y) > wall_condition:
					tiles[x][y] = Tiles.WALL
				elif check_nearby_walls(x, y) < ground_condition:
					tiles[x][y] = Tiles.GROUND

# check in 8 dirs to see how many tiles are walls
func check_nearby_walls(x, y):
	var count = 0
	if tiles[x][y - 1]    == Tiles.WALL:  count += 1
	if tiles[x][y + 1]    == Tiles.WALL:  count += 1
	if tiles[x - 1][y]    == Tiles.WALL:  count += 1
	if tiles[x + 1][y]    == Tiles.WALL:  count += 1
	if tiles[x + 1][y + 1] == Tiles.WALL:  count += 1
	if tiles[x + 1][y - 1] == Tiles.WALL:  count += 1
	if tiles[x - 1][y + 1] == Tiles.WALL:  count += 1
	if tiles[x - 1][y - 1] == Tiles.WALL:  count += 1
	return count

func get_biggest_cave():
	biggest_cave = []
	
	for x in range (0, map_w):
		for y in range (0, map_h):
			if tiles[x][y] == Tiles.GROUND:
				flood_fill(x, y)

	for tile in biggest_cave:
		tiles[tile.x][tile.y] = Tiles.GROUND

func flood_fill(x, y):
	var cave = []
	var to_fill = [Vector2(x, y)]
	while to_fill:
		var tile = to_fill.pop_back()

		if !cave.has(tile):
			cave.append(tile)
			tiles[tile.x][tile.y] = Tiles.WALL

			# check adjacent cells
			var north = Vector2(tile.x, tile.y - 1)
			var south = Vector2(tile.x, tile.y + 1)
			var east  = Vector2(tile.x + 1, tile.y)
			var west  = Vector2(tile.x - 1, tile.y)

			for neighbor in [north, south, east, west]:
				if tiles[neighbor.x][neighbor.y] == Tiles.GROUND:
					if !to_fill.has(neighbor) and !cave.has(neighbor):
						to_fill.append(neighbor)

	if cave.size() >= biggest_cave.size():
		biggest_cave = cave

func is_ground(x, y):
	if $Ground.get_cell_atlas_coords(Vector2i(x, y)) == GROUND:
		return true

	return false

func is_black(x, y):
	if $Walls.get_cell_atlas_coords(Vector2i(x, y)) == BLACK:
		return true

	return false

func is_ground_block(x, y, d):
	for i in range(x - d, x + d + 1):
		for j in range (y - d, y + d + 1):
			if !is_ground(i, j):
				return false
	return true

func convert_tile_array_to_tilemap():
	# this is part of a bit of a hacky way to get the borders of the level
	# we are basically guaranteed by the various logic in this script that the border
	# of the level will have walls at least 2 tiles thick,
	# so the very edge of the level can be safely filled with BLACK tiles
	# without needing to check neighboring tiles, some of which are non-existant (because it's the border)
	for x in range(0, map_w):
		for y in range(0, map_h):
			if x < 2 or y < 2 or x > map_w - 2 or y > map_h - 2:
				tiles[x][y] = Tiles.WALL
			if x == 0 or y == 0 or x == map_w - 1 or y == map_h - 1:
				$Walls.set_cell(Vector2i(x, y), 0, BLACK)

	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if tiles[x][y] == Tiles.GROUND:
				$Ground.set_cell(Vector2i(x, y), 0, GROUND)

	# this loop in particular is kinda hacky, in order to correctly fill in wall faces
	# this has the side effect of altering the tiles array to have GROUND where it should
	# really be marked as "WALL"
	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if tiles[x][y] == Tiles.WALL and tiles[x][y + 1] == Tiles.GROUND and $Walls.get_cell_atlas_coords(Vector2(x, y)) != FACE:
				tiles[x][y] = Tiles.GROUND
				$Walls.set_cell(Vector2i(x, y), 0, FACE)
				

	for y in range(1, map_h - 1):
		for x in range(1, map_w - 1):
			if tiles[x][y] != Tiles.GROUND:
				# first row
				if (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_LW_BW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_LW_BRC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BLC_BRC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_RW_BLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TRC_BLC_BRC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BLC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_BLC_BRC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_LW)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_TRC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_RW)

				# second row
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, LW_RW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, LW_TRC_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_TRC_BLC_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, RW_TLC_BLC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, LW_TRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, RW_TLC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, LW)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TRC_BRC)

				# third row
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_LW_RW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_LW_TRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_TLC_TRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_RW_TLC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, LW_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, RW_BLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_BLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BLACK)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TRC_BLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, RW)

				# fourth row
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BW_LW_RW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BW_LW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BW)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.GROUND and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TW_BW_RW)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_TRC_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_TLC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_TRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.GROUND and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.GROUND and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, TLC_TRW_BLC)
				elif (
					#tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.GROUND and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_LW)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.WALL and

					tiles[x - 1][y + 1] == Tiles.GROUND and
					tiles[x][y + 1] == Tiles.WALL and
					tiles[x + 1][y + 1] == Tiles.GROUND
				):
					$Walls.set_cell(Vector2i(x, y), 0, BLC_BRC)
				elif (
					tiles[x - 1][y - 1] == Tiles.WALL and
					tiles[x][y - 1] == Tiles.WALL and
					#tiles[x + 1][y - 1] == Tiles.WALL and

					tiles[x - 1][y] == Tiles.WALL and
					tiles[x + 1][y] == Tiles.GROUND and

					#tiles[x - 1][y + 1] == Tiles.WALL and
					tiles[x][y + 1] == Tiles.GROUND
					#tiles[x + 1][y + 1] == Tiles.WALL
				):
					$Walls.set_cell(Vector2i(x, y), 0, BW_RW)
