class_name MissionThumbnail
extends RefCounted
## A small picture of a mission's map for the mission list (docs/specs/art-gaps.md, G.3): every cell is a 4 x 1 px block in the
## 2:1 isometric layout, coloured by its terrain, with the core and the enemy spawns marked. Made when asked and kept, so there are
## no files to keep in step with the maps. Presentation only.

const CORE_COLOR := Color("5ab4ff")
const SPAWN_COLOR := Color("ff5a4a")

static var _cache: Dictionary = {}  # mission id -> ImageTexture


static func texture(mission: MissionDefinition) -> ImageTexture:
	if mission == null or mission.map == null:
		return null
	if not _cache.has(mission.id):
		_cache[mission.id] = ImageTexture.create_from_image(render(mission))
	return _cache[mission.id]


static func size_of(map: MapDefinition) -> Vector2i:
	return Vector2i((map.width() + map.height()) * 2 + 4, map.width() + map.height() + 2)


static func render(mission: MissionDefinition) -> Image:
	var map := mission.map
	var img := Image.create(size_of(map).x, size_of(map).y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var colors := {}
	for e in TerrainCatalog.ALL:
		colors[e["ch"]] = e["color"]
	for y in map.height():
		for x in map.width():
			var ch := map.terrain_char(Vector2i(x, y))
			var c: Color = colors.get(ch, Color(0.3, 0.3, 0.3))
			# light from the top left: the west edge a little brighter, the south-east a little darker
			c = c.lightened(0.06) if (x + y) % 2 == 0 else c.darkened(0.04)
			_cell(img, map, x, y, c)
	for s in mission.spawn_cells:
		_mark(img, map, s, SPAWN_COLOR, 1)
	_mark(img, map, mission.core_cell, CORE_COLOR, 2)
	return img


static func _origin(map: MapDefinition, cell: Vector2i) -> Vector2i:
	return Vector2i((cell.x - cell.y + map.height()) * 2 + 2, cell.x + cell.y + 1)


static func _cell(img: Image, map: MapDefinition, x: int, y: int, c: Color) -> void:
	var o := _origin(map, Vector2i(x, y))
	for i in 4:
		img.set_pixel(o.x - 2 + i, o.y, c)


static func _mark(img: Image, map: MapDefinition, cell: Vector2i, c: Color, r: int) -> void:
	var o := _origin(map, cell)
	for dy in range(-r, r + 1):
		for dx in range(-r * 2 - 1, r * 2 + 3):
			var p := Vector2i(o.x + dx, o.y + dy)
			if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height():
				img.set_pixel(p.x, p.y, c)
