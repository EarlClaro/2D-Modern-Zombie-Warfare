extends SceneTree
## Dev tool (not a test). Builds the inspection map `showcase` and the mission `dev_showcase`: every terrain in a
## chip (all four look-variants show up across it) and every scenery definition on shelves, grouped by category, so
## the whole catalogue can be looked at in the real renderer: `godot --path . -- --mission=dev_showcase`.
## The mission is a dev scene (one lone shambler after 50 minutes), not a level.
## Run: godot --headless --path . --script tools/gen_showcase.gd

const CHIP := Vector2i(10, 6)
const CHIP_PITCH := Vector2i(11, 7)
const CHIP_COLUMNS := 6
const LEFT := 4  # columns 0..3 stay clear for the core, the spawn and the path
const WIDTH := 100

var _lines: PackedStringArray = PackedStringArray()


func _initialize() -> void:
	var groups := _groups()
	var chip_rows := ceili(float(TerrainCatalog.count()) / CHIP_COLUMNS)
	var shelf_top := 2 + chip_rows * CHIP_PITCH.y + 1
	var y := shelf_top
	var x := LEFT
	var row_h := 0
	for g in groups:
		if x > LEFT:  # every category starts on a fresh shelf
			y += row_h + 1
			x = LEFT
			row_h = 0
		for def in g["defs"]:
			var fp: Vector2i = def.footprint
			if x + fp.x > WIDTH - 1:
				y += row_h + 1
				x = LEFT
				row_h = 0
			_lines.append("%s %d %d" % [def.id, x, y])
			x += fp.x + 1
			row_h = maxi(row_h, fp.y)
	var height := y + row_h + 2
	var rows := PackedStringArray()
	for yy in height:
		rows.append(".".repeat(WIDTH))
	for i in TerrainCatalog.count():
		var ox := LEFT + (i % CHIP_COLUMNS) * CHIP_PITCH.x
		var oy := 2 + floori(float(i) / CHIP_COLUMNS) * CHIP_PITCH.y
		var ch: String = TerrainCatalog.ALL[i]["ch"]
		for cy in CHIP.y:
			rows[oy + cy] = rows[oy + cy].substr(0, ox) + ch.repeat(CHIP.x) + rows[oy + cy].substr(ox + CHIP.x)
	var map := MapDefinition.new()
	map.id = "showcase"
	map.rows = rows
	map.scenery = _lines
	var err := ResourceSaver.save(map, "res://data/maps/showcase.tres")
	if err != OK:
		push_error("saving the map failed (%d)" % err)
		quit(1)
		return
	var saved := load("res://data/maps/showcase.tres") as MapDefinition
	var m := MissionDefinition.new()
	m.id = "dev_showcase"
	m.display_name = "Showcase (dev)"
	m.map = saved
	m.core_cell = Vector2i(1, 1)
	m.core_health = 1000.0
	m.duration_s = 3600.0
	m.spawn_cells = [Vector2i(1, 8)]
	m.path_cells = [Vector2i(1, 1)]
	m.deploy_radius = 6.0
	m.deck_id = "fortified"
	m.time_of_day = 0.5
	var w := WaveEntry.new()
	w.start_s = 3000.0
	w.enemy_id = "shambler"
	w.count = 1
	w.interval_s = 0.0
	w.spawn_index = 0
	m.waves = [w]
	err = ResourceSaver.save(m, "res://data/missions/dev_showcase.tres")
	if err != OK:
		push_error("saving the mission failed (%d)" % err)
		quit(1)
		return
	print("showcase: %dx%d, %d terrains, %d scenery definitions in %d groups" % [WIDTH, height, TerrainCatalog.count(), _lines.size(), groups.size()])
	quit()


## Scenery definitions grouped by category: the sets of each theme pack under their `cat`, the rest as "classic".
func _groups() -> Array:
	var cat_of: Dictionary = {}  # scenery id -> category
	var order: PackedStringArray = []
	var dir := DirAccess.open("res://tools/sprite_packs")
	var files := Array(dir.get_files()) if dir != null else []
	files.sort()
	for f in files:
		if not (f.begins_with("pack_") and f.ends_with(".gd")):
			continue
		var pk: GDScript = load("res://tools/sprite_packs/%s" % f)
		for spec in pk.specs():
			var cat: String = spec["cat"]
			cat_of[spec["dir"]] = cat
			cat_of[str(spec["dir"]) + "_y"] = cat
			if cat not in order:
				order.append(cat)
	order.append("classic")
	var by_cat: Dictionary = {}
	for c in order:
		by_cat[c] = []
	var ids := Array(DirAccess.get_files_at("res://data/scenery"))
	ids.sort()
	for f in ids:
		if not f.ends_with(".tres"):
			continue
		var def := load("res://data/scenery/" + f) as SceneryDefinition
		if def == null or def.id == "hq_bunker":
			continue
		by_cat[cat_of.get(def.id, "classic")].append(def)
	var out: Array = []
	for c in order:
		if not by_cat[c].is_empty():
			out.append({"cat": c, "defs": by_cat[c]})
	return out
