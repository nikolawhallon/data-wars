extends ColorRect


var palette_index = 0
var palettes = [
	[
		Color("#2c2137"),
		Color("#764462"),
		Color("#a96868"),
		Color("#edb4a1")
	],
	# https://lospec.com/palette-list/original-gameboy
	[
		Color("#0f380f"),
		Color("#306230"),
		Color("#8bac0f"),
		Color("#9bbc0f")
	],
	# https://lospec.com/palette-list/velvet-cherry-gb
	[
		Color("#2d162c"),
		Color("#412752"),
		Color("#683a68"),
		Color("#9775a6")
	],
	# https://lospec.com/palette-list/moon-crystal
	[
		Color("#755f9c"),
		Color("#8d89c7"),
		Color("#d9a7c6"),
		Color("#ffe2db")
	],
	# https://lospec.com/palette-list/hexpress4
	[
		Color("#553840"),
		Color("#9b6859"),
		Color("#bebc6a"),
		Color("#edf8c8")
	]
]

func next_palette():
	palette_index = (palette_index + 1) % palettes.size()
	swap_palette(palettes[palette_index])

func swap_palette(palette: Array):
	var mat := material as ShaderMaterial

	mat.set_shader_parameter("pal0", palette[0])
	mat.set_shader_parameter("pal1", palette[1])
	mat.set_shader_parameter("pal2", palette[2])
	mat.set_shader_parameter("pal3", palette[3])
