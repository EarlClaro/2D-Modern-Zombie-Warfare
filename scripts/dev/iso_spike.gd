extends Node2D
## Milestone 0.5 spike scene: placeholder map, pan/zoom camera, hover highlight, a movable unit, tall
## structures that fade, an orbiting flyer, and an AoE ellipse. Dev-only; not game architecture.
##
## Layer order (bottom -> top): Ground, Decals, Shadows, Entities (y-sorted), Air (y-sorted), HUD.

const MAP_SIZE: int = 16
const AOE_MIN: float = 0.5
const AOE_MAX: float = 8.0
const AOE_STEP: float = 0.5

var _ground: TileMapLayer
var _decals: Node2D
var _shadows: Node2D
var _entities: Node2D
var _air: Node2D
var _highlight: IsoCellHighlight
var _aoe: IsoAoeIndicator
var _unit: PlaceholderUnit
var _flyer: PlaceholderFlyer
var _camera: IsoCamera
var _label: Label
var _structures: Array[PlaceholderStructure] = []
var _blocked: Dictionary = {}  # Vector2i -> true, cells covered by structures


func _ready() -> void:
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	_ground.tile_set = IsoTileSet.build()
	_ground.position = IsoProjection.TILEMAP_LAYER_OFFSET
	add_child(_ground)
	_fill_map()

	_decals = _add_layer("Decals", false)
	_shadows = _add_layer("Shadows", false)
	_entities = _add_layer("Entities", true)
	_air = _add_layer("Air", true)

	_add_axis(Vector2(3, 0), Color.RED)
	_add_axis(Vector2(0, 3), Color.LIME)
	_highlight = IsoCellHighlight.new()
	_highlight.name = "HoverHighlight"
	_decals.add_child(_highlight)
	_aoe = IsoAoeIndicator.new()
	_aoe.name = "AoeIndicator"
	_aoe.radius = 3.0
	_decals.add_child(_aoe)

	_add_structure(Vector2i(9, 5), Vector2i(2, 2), 3.0)
	_add_structure(Vector2i(4, 9), Vector2i(1, 1), 2.0)

	_unit = PlaceholderUnit.new()
	_unit.name = "Unit"
	_unit.ground_pos = Vector2(2.5, 6.5)
	_entities.add_child(_unit)
	_add_shadow(_unit, 0.4)

	_flyer = PlaceholderFlyer.new()
	_flyer.name = "Flyer"
	_flyer.orbit_center = Vector2(MAP_SIZE, MAP_SIZE) * 0.5
	_air.add_child(_flyer)
	_add_shadow(_flyer, 0.55)

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


func _process(delta: float) -> void:
	var ground := IsoPicking.ground_under_mouse(self)
	var cell := IsoProjection.cell_of(ground)
	var in_map := _in_map(cell)
	_highlight.visible = in_map
	_highlight.cell = cell
	_aoe.ground_pos = ground

	_update_occlusion(delta, cell, in_map)

	var terrain := "outside map"
	if in_map:
		var data := _ground.get_cell_tile_data(cell)
		terrain = "walkable=%s buildable=%s%s" % [data.get_custom_data("walkable"), data.get_custom_data("buildable"), " (structure)" if _blocked.has(cell) else ""]
	var faded := 0
	for s in _structures:
		if s.modulate.a < 0.99:
			faded += 1
	_label.text = "ground (%.2f, %.2f)  cell %s  %s\nunit facing %s%s   AoE radius %.1f   faded structures %d   zoom %.2f\nLMB move unit | Q/E AoE radius | WASD pan | wheel zoom | MMB drag | red=+X green=+Y" % [
		ground.x, ground.y, str(cell), terrain,
		IsoProjection.facing_name(_unit.facing), " (moving)" if _unit.is_moving() else "",
		_aoe.radius, faded, _camera.zoom.x]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := IsoPicking.cell_under_mouse(self)
		if _is_walkable(cell):
			_unit.move_to(IsoProjection.cell_center(cell))
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Q:
			_aoe.radius = maxf(AOE_MIN, _aoe.radius - AOE_STEP)
		elif event.keycode == KEY_E:
			_aoe.radius = minf(AOE_MAX, _aoe.radius + AOE_STEP)


func _update_occlusion(delta: float, hover_cell: Vector2i, hover_valid: bool) -> void:
	# Subjects that must stay readable: the unit and the hovered cell (stand-in for a placement preview).
	for s in _structures:
		var faded := IsoOcclusion.is_occluding(s.ground_pos, s.world_rect(), _unit.ground_pos, _unit.world_rect())
		if not faded and hover_valid:
			faded = IsoOcclusion.is_occluding(s.ground_pos, s.world_rect(), IsoProjection.cell_center(hover_cell), IsoProjection.cell_screen_rect(hover_cell))
		s.update_fade(faded, delta)


func _in_map(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < MAP_SIZE and cell.y < MAP_SIZE


func _is_walkable(cell: Vector2i) -> bool:
	if not _in_map(cell) or _blocked.has(cell):
		return false
	return _ground.get_cell_tile_data(cell).get_custom_data("walkable")


func _add_layer(layer_name: String, y_sorted: bool) -> Node2D:
	var layer := Node2D.new()
	layer.name = layer_name
	layer.y_sort_enabled = y_sorted
	add_child(layer)
	return layer


func _add_shadow(target: IsoEntity, radius_tiles: float) -> void:
	var shadow := IsoShadow.new()
	shadow.target = target
	shadow.radius_tiles = radius_tiles
	_shadows.add_child(shadow)


func _add_structure(origin: Vector2i, size: Vector2i, height_units: float) -> void:
	var s := PlaceholderStructure.new()
	s.name = "Structure%d" % _structures.size()
	s.setup(origin, size, height_units)
	_entities.add_child(s)
	_structures.append(s)
	for c in s.covered_cells():
		_blocked[c] = true


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
	_decals.add_child(line)
