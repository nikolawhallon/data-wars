extends Node2D

var rng := RandomNumberGenerator.new()
# these must be set from the init method
# if they aren't set, then other method calls
# will break the game
var map_origin = null
var map_size = null

var cols := ["A","B","C","D"]
var rows := [1,2,3,4]

var grid_dash_length := 6.0
var grid_gap_length := 4.0
var grid_width := 1.0
var grid_color := Color("#edb4a1")

func _ready():
	rng.randomize()

func init(map: TileMapLayer):
	map_origin = Vector2(map.get_used_rect().position * map.tile_set.tile_size)
	map_size = Vector2(map.get_used_rect().size * map.tile_set.tile_size)

func _draw() -> void:
	if map_origin == null or map_size == null:
		return

	draw_dotted_grid()

func draw_dotted_grid() -> void:	
	var cell_size = Vector2(map_size.x / cols.size(), map_size.y / rows.size())

	# Vertical boundaries
	for i in range(cols.size() + 1):
		var x = map_origin.x + i * cell_size.x
		if i == 0:
			x += 1
		var from = Vector2(x, map_origin.y)
		var to = Vector2(x, map_origin.y + map_size.y)
		draw_dotted_line(from, to, grid_color, grid_width, grid_dash_length, grid_gap_length)

	# Horizontal boundaries
	for j in range(rows.size() + 1):
		var y = map_origin.y + j * cell_size.y
		if j == 0:
			y += 1
		var from = Vector2(map_origin.x, y)
		var to = Vector2(map_origin.x + map_size.x, y)
		draw_dotted_line(from, to, grid_color, grid_width, grid_dash_length, grid_gap_length)

func draw_dotted_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0, dash_len: float = 6.0, gap_len: float = 4.0) -> void:
	var segment = to - from
	var total_length = segment.length()

	if total_length <= 0.0:
		return

	var dir = segment / total_length
	var step = dash_len + gap_len
	var distance = 0.0

	while distance < total_length:
		var dash_start = from + dir * distance
		var dash_end = from + dir * min(distance + dash_len, total_length)
		draw_line(dash_start, dash_end, color, width)
		distance += step

func spawn_cell_labels():
	var cell_size = Vector2(map_size.x / cols.size(), map_size.y / rows.size())

	for col_idx in cols.size():
		for row_idx in rows.size():
			var col_name = cols[col_idx]
			var row_name = rows[row_idx]
			var cell_name = "%s%d" % [col_name, row_name]

			var center = map_origin + Vector2((col_idx + 0.5) * cell_size.x, (row_idx + 0.5) * cell_size.y)

			var label = load("res://scenes/label_8.tscn").instantiate()
			label.text = cell_name
			label.size = label.get_minimum_size()
			label.position = center - label.get_minimum_size() * 0.5
			add_child(label)

func pos_to_cell_label(pos: Vector2) -> String:
	var cell_size = Vector2(map_size.x / cols.size(), map_size.y / rows.size())

	var local = pos - map_origin

	var col_idx := int(floor(local.x / cell_size.x))
	var row_idx := int(floor(local.y / cell_size.y))

	if col_idx < 0 or col_idx >= cols.size():
		return ""
	if row_idx < 0 or row_idx >= rows.size():
		return ""

	return "%s%d" % [cols[col_idx], rows[row_idx]]

func cell_label_to_pos(label):
	if label.length() < 2:
		print("Bad label length")
		return null

	var col_label = label[0]
	var row_label = int(label.substr(1, label.length() - 1))
	
	var col_idx = cols.find(col_label)
	var row_idx = rows.find(row_label)
	if col_idx == -1:
		print("Couldn't find col_idx")
		return null
	if row_idx == -1:
		print("Couldn't find row_idx")
		return null

	var cell_size = Vector2(map_size.x / cols.size(), map_size.y / rows.size())

	var cell_origin = map_origin + Vector2(
		col_idx * cell_size.x + cell_size.x / 2,
		row_idx * cell_size.y + cell_size.y / 2
	)

	var x = rng.randf_range(cell_origin.x - cell_size.x / 2, cell_origin.x + cell_size.x / 2)
	var y = rng.randf_range(cell_origin.y - cell_size.y / 2, cell_origin.y + cell_size.y / 2)
	return Vector2(x, y)
