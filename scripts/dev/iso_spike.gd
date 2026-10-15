extends Node2D
## Milestone 0.5 spike scene: 16x16 placeholder map, pan/zoom camera, hover highlight, debug readout.

const MAP_SIZE: int = 16

var _ground: TileMapLayer
var _highlight: IsoCellHighlight
var _camera: IsoCamera
var _label: Label


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = IsoTileSet.build()
	_ground.position = IsoProjection.TILEMAP_LAYER_OFFSET
	add_child(_ground)
	_fill_map()

	_add_axis(Vector2(3, 0), Color.RED)
	_add_axis(Vector2(0, 3), Color.LIME)

	_highlight = IsoCellHighlight.new()
	_highlight.name = "HoverHighlight"
	add_child(_highlight)

	_camera = IsoCamera.new()
	_camera.name = "Camera"
	_camera.position = IsoProjection.ground_to_screen(Vector2(MAP_SIZE, MAP_SIZE) * 0.5)
	add_child(_camera)
	_camera.make_current()

	var hud := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16, 16)
	_label.add_theme_font_size_override("font_size", 22)
	_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(_label)
	add_child(hud)


func _process(_delta: float) -> void:
	var ground := IsoPicking.ground_under_mouse(self)
	var cell := IsoProjection.cell_of(ground)
	var in_map := cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE and cell.y < MAP_SIZE
	_highlight.visible = in_map
	_highlight.cell = cell
	var terrain := "outside map"
	if in_map:
		var data := _ground.get_cell_tile_data(cell)
		terrain = "walkable=%s buildable=%s" % [data.get_custom_data("walkable"), data.get_custom_data("buildable")]
	_label.text = "ground (%.2f, %.2f)  cell %s  %s\nzoom %.2f   WASD/arrows pan, wheel zoom, MMB drag   red=+X green=+Y" % [
		ground.x, ground.y, str(cell), terrain, _camera.zoom.x]


func _fill_map() -> void:
	for y in MAP_SIZE:
		for x in MAP_SIZE:
			var terrain := IsoTileSet.TERRAIN_GRASS
			if x == y or x == y + 1:
				terrain = IsoTileSet.TERRAIN_ROAD  # diagonal road
			elif (x + y) % 11 == 5 and x % 3 == 0:
				terrain = IsoTileSet.TERRAIN_ROCK  # scattered blocked cells
			_ground.set_cell(Vector2i(x, y), IsoTileSet.SOURCE_ID, terrain)


func _add_axis(ground_end: Vector2, color: Color) -> void:
	var line := Line2D.new()
	line.width = 3.0
	line.default_color = color
	line.add_point(IsoProjection.ground_to_screen(Vector2.ZERO))
	line.add_point(IsoProjection.ground_to_screen(ground_end))
	add_child(line)
