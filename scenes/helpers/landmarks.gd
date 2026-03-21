extends Node


var rng = RandomNumberGenerator.new()

@rpc("call_local")
func init(seed, map, parent, match_peer_ids):
	rng.seed = seed

	var map_origin = map.get_map_origin()
	var tile_size = map.get_tile_size()

	var mine_number = 3
	var mines = []
	while mine_number > 0:
		var mine = load("res://scenes/mine.tscn").instantiate()

		while true:
			var x = rng.randi_range(1, map.map_w - 1)
			var y = rng.randi_range(1, map.map_h - 1)
			if !map.is_ground_block(x, y, 1):
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
				
			mine.init(match_peer_ids, pos)
			parent.add_child(mine, true)
			break
			
		mine_number -= 1
		mines.append(mine)

	var water_number = 6
	var waters = []
	while water_number > 0:
		var water = load("res://scenes/water.tscn").instantiate()

		while true:
			var x = rng.randi_range(1, map.map_w - 1)
			var y = rng.randi_range(1, map.map_h - 1)
			if !map.is_ground_block(x, y, 1):
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

			water.init(match_peer_ids, pos)
			# TODO: it's possible this could get called more than once
			parent.add_child(water, true)

			var site_number = 0
			if map.is_ground_block(x - 3, y, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				site.init(match_peer_ids, water.get_path(), map_origin + tile_size / 2 + Vector2(x - 3, y) * tile_size)
				parent.add_child(site, true)
				site_number += 1
			if map.is_ground_block(x + 3, y, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				site.init(match_peer_ids, water.get_path(), map_origin + tile_size / 2 + Vector2(x + 3, y) * tile_size)
				parent.add_child(site, true)
				site_number += 1
			if map.is_ground_block(x, y - 3, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				site.init(match_peer_ids, water.get_path(), map_origin + tile_size / 2 + Vector2(x, y - 3) * tile_size)
				parent.add_child(site, true)
				site_number += 1
			if map.is_ground_block(x, y + 3, 1):
				var site = load("res://scenes/site.tscn").instantiate()
				site.init(match_peer_ids, water.get_path(), map_origin + tile_size / 2 + Vector2(x, y + 3) * tile_size)
				parent.add_child(site, true)
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

		while true:
			var x = rng.randi_range(1, map.map_w - 1)
			var y = rng.randi_range(1, map.map_h - 1)
			if !map.is_black(x, y):
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

			transmission_tower.init(match_peer_ids, pos)
			parent.add_child(transmission_tower, true)
			break
			
		transmission_tower_number = transmission_tower_number - 1
		transmission_towers.append(transmission_tower)
