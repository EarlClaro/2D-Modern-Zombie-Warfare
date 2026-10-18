class_name MissionThumbnail
extends RefCounted
## A small picture of a mission's map for the mission list (docs/specs/art-gaps.md, G.3; docs/specs/art-polish.md, P.3): the map in
## the game's own 2:1 isometric view, one 8 x 4 px diamond per cell. Terrain tiles have light and a little grain, rock stands up as
## blocks, water has glints, the scenery the map places (trees, walls, buildings) is drawn as small blocks and blobs in the colour of
## its art, the core is a blue-roofed bunker with a flag and each enemy spawn a red post on a red tile. Drawn back to front, then
## outlined. Made when asked and kept, so there are no files to keep in step with the maps. Presentation only.

const CORE_COLOR := Color("5ab4ff")
const SPAWN_COLOR := Color("ff5a3a")
const TILE_W := 8
const TILE_H := 4
const TOP := 20  # room above the back corner for tall pieces
const MARGIN := 4
const ROCK_HEIGHT := 3
const HEIGHT_PER_UNIT := 4.0  # a piece 1 tile tall is this many px tall (the tile is 8 px wide here, 64 in the game)

static var _cache: Dictionary = {}  # mission id -> ImageTexture
static var _avg: Dictionary = {}  # scenery id -> its art's average colour


static func texture(mission: MissionDefinition, db: ContentDb = null) -> ImageTexture:
	if mission == null or mission.map == null:
		return null
	if not _cache.has(mission.id):
		_cache[mission.id] = ImageTexture.create_from_image(render(mission, db))
	return _cache[mission.id]


static func size_of(map: MapDefinition) -> Vector2i:
	var n := map.width() + map.height()
	return Vector2i(n * TILE_W / 2 + MARGIN * 2, n * TILE_H / 2 + TOP + MARGIN * 2)


## The screen point of the ground point (gx, gy), in cell units: x runs down-right, y down-left.
static func _p(map: MapDefinition, gx: float, gy: float) -> Vector2:
	return Vector2((gx - gy + float(map.height())) * float(TILE_W) * 0.5 + float(MARGIN), (gx + gy) * float(TILE_H) * 0.5 + float(TOP + MARGIN))


static func render(mission: MissionDefinition, db: ContentDb = null) -> Image:
	var map := mission.map
	var size := size_of(map)
	var c := PixelCanvas.new(size.x, size.y)
	var colors := {}
	for e in TerrainCatalog.ALL:
		colors[e["ch"]] = e["color"]
	# scenery by the cell in front of its footprint, so it is drawn after everything behind it
	var by_cell := {}
	if db != null:
		for pl in map.placements():
			var def := db.scenery(pl.scenery_id)
			if def == null:
				continue
			var front := pl.cell + def.footprint - Vector2i.ONE
			if not by_cell.has(front):
				by_cell[front] = []
			by_cell[front].append([pl, def])
	for s in map.width() + map.height() - 1:
		for cx in range(maxi(0, s - map.height() + 1), mini(map.width() - 1, s) + 1):
			var cy := s - cx
			var cell := Vector2i(cx, cy)
			var ch := map.terrain_char(cell)
			var col: Color = colors.get(ch, Color(0.3, 0.3, 0.3))
			if ch == "#":
				_block(c, map, cx, cy, 1, 1, ROCK_HEIGHT, col, true)
			else:
				_tile(c, map, cell, ch, col)
			if by_cell.has(cell):
				for item in by_cell[cell]:
					_scenery(c, map, item[0] as SceneryPlacement, item[1] as SceneryDefinition)
			if mission.spawn_cells.has(cell):
				_spawn(c, map, cell)
			if cell == mission.core_cell:
				_core(c, map, cell)
	c.outline(Color("0b0f0d"))
	return c.img


static func _hash(x: int, y: int) -> int:
	var n := x * 374761393 + y * 668265263
	n = (n ^ (n >> 13)) * 1274126177
	return (n ^ (n >> 16)) & 0xFFFF


static func _diamond(map: MapDefinition, cx: int, cy: int, lift: float = 0.0, x1: int = -1, y1: int = -1) -> PackedVector2Array:
	var ex := cx + 1 if x1 < 0 else x1
	var ey := cy + 1 if y1 < 0 else y1
	var up := Vector2(0.0, -lift)
	return PackedVector2Array([_p(map, cx, cy) + up, _p(map, ex, cy) + up, _p(map, ex, ey) + up, _p(map, cx, ey) + up])


static func _tile(c: PixelCanvas, map: MapDefinition, cell: Vector2i, ch: String, base: Color) -> void:
	var shade := base.lightened(0.06) if (cell.x + cell.y) % 2 == 0 else base.darkened(0.03)
	var water := ch == "w" or ch == "~"
	c.poly_fn(_diamond(map, cell.x, cell.y), func(x: int, y: int) -> Color:
		var n := _hash(x + cell.x * 7, y + cell.y * 13)
		var col := shade
		if water:
			col = shade.lightened(0.28) if n % 17 == 0 and y % 2 == 0 else shade
		elif n % 11 == 0:
			col = shade.darkened(0.14)
		elif n % 13 == 0:
			col = shade.lightened(0.12)
		return col)
	# light from the top left: the two upper edges catch it, the two lower ones fall off
	var top := _p(map, cell.x, cell.y)
	c.px(int(top.x) - 1, int(top.y) + 1, shade.lightened(0.18))
	c.px(int(top.x), int(top.y), shade.lightened(0.18))


## A box standing on cells (cx, cy) .. (cx + fw - 1, cy + fh - 1), `h` px tall: a lit top, a lit left face, a shaded right face.
static func _block(c: PixelCanvas, map: MapDefinition, cx: int, cy: int, fw: int, fh: int, h: float, col: Color, rough: bool = false) -> void:
	var x1 := cx + fw
	var y1 := cy + fh
	var up := Vector2(0.0, -h)
	var left := PackedVector2Array([_p(map, cx, y1), _p(map, x1, y1), _p(map, x1, y1) + up, _p(map, cx, y1) + up])
	var right := PackedVector2Array([_p(map, x1, cy), _p(map, x1, y1), _p(map, x1, y1) + up, _p(map, x1, cy) + up])
	c.poly(left, col.darkened(0.12))
	c.poly(right, col.darkened(0.32))
	var topface := _diamond(map, cx, cy, h, x1, y1)
	c.poly_fn(topface, func(x: int, y: int) -> Color:
		if rough and _hash(x, y) % 5 == 0:
			return col.lightened(0.04)
		return col.lightened(0.14))


static func _avg_color(def: SceneryDefinition) -> Color:
	if _avg.has(def.id):
		return _avg[def.id]
	var out := Color("8a8a84")
	if def.sprite != null and not def.sprite.textures.is_empty():
		var tex: Texture2D = def.sprite.textures.values()[0]
		var img := tex.get_image() if tex != null else null
		if img != null:
			if img.is_compressed():
				img.decompress()
			img.convert(Image.FORMAT_RGBA8)
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var n := 0.0
			var step := maxi(1, img.get_width() / 24)
			for y in range(0, img.get_height(), step):
				for x in range(0, img.get_width(), step):
					var px := img.get_pixel(x, y)
					if px.a > 0.5:
						r += px.r
						g += px.g
						b += px.b
						n += 1.0
			if n > 0.0:
				out = Color(r / n, g / n, b / n)
	_avg[def.id] = out
	return out


static func _scenery(c: PixelCanvas, map: MapDefinition, pl: SceneryPlacement, def: SceneryDefinition) -> void:
	var col := _avg_color(def)
	var h := clampf(def.shadow_height() * HEIGHT_PER_UNIT, 1.0, 16.0)
	if def.sway >= 0.5:  # a tree or a bush: a blob on a short trunk
		var foot := _p(map, float(pl.cell.x) + float(def.footprint.x) * 0.5, float(pl.cell.y) + float(def.footprint.y) * 0.5)
		var r := clampf(h * 0.5, 2.0, 5.0)
		c.rect(int(foot.x), int(foot.y) - int(h * 0.4), 1, int(h * 0.4) + 1, Color("4a3524"))
		c.ellipse(foot.x, foot.y - h * 0.65, r, r * 0.9, col.darkened(0.2))
		c.ellipse(foot.x - 0.8, foot.y - h * 0.65 - 0.8, r * 0.7, r * 0.65, col.lightened(0.1))
		return
	_block(c, map, pl.cell.x, pl.cell.y, def.footprint.x, def.footprint.y, h, col)


static func _post(c: PixelCanvas, map: MapDefinition, cell: Vector2i, flag: Color, height: int) -> void:
	var foot := _p(map, float(cell.x) + 0.5, float(cell.y) + 0.5)
	var x := int(foot.x)
	var y := int(foot.y)
	c.rect(x, y - height, 1, height + 1, Color("2b2f33"))
	c.rect(x + 1, y - height, 4, 3, flag)
	c.rect(x + 1, y - height, 4, 1, flag.lightened(0.3))


static func _spawn(c: PixelCanvas, map: MapDefinition, cell: Vector2i) -> void:
	c.poly(_diamond(map, cell.x, cell.y), SPAWN_COLOR.darkened(0.25))
	var mid := _p(map, float(cell.x) + 0.5, float(cell.y) + 0.5)
	c.rect(int(mid.x) - 2, int(mid.y) - 1, 4, 2, SPAWN_COLOR.darkened(0.1))
	_post(c, map, cell, SPAWN_COLOR, 7)


static func _core(c: PixelCanvas, map: MapDefinition, cell: Vector2i) -> void:
	c.poly(_diamond(map, cell.x, cell.y), CORE_COLOR.darkened(0.45))
	_block(c, map, cell.x, cell.y, 1, 1, 4.0, Color("6d7b84"))
	var roof := _diamond(map, cell.x, cell.y, 4.0)
	c.poly(roof, CORE_COLOR)
	_post(c, map, cell, CORE_COLOR, 11)
