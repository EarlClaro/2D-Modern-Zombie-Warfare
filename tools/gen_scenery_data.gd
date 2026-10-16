extends SceneTree
## Dev tool (not a test). Writes data/scenery/<id>.tres for every decoration from the table below and the
## frame.json files that tools/gen_sprites.gd leaves next to the art. Run after (re)rendering the scenery sprites:
##   godot --headless --path . --script tools/gen_scenery_data.gd
## Orientation variants (`_y`) use the art rendered facing SW (the long side along ground y) with a swapped footprint.
## The sets of the theme packs (tools/sprite_packs/pack_*.gd) need no table: their definitions come from each pack's
## specs() and the frame.json that tools/gen_sprites.gd wrote (frame, origin, footprint, height).

# id, display name, sprite dir, art file (se / sw), footprint x, footprint y, fades
const TABLE: Array = [
	["oak_tree", "Oak Tree", "oak_tree", "se", 1, 1, true],
	["oak_tree_b", "Broad Oak", "oak_tree_b", "se", 1, 1, true],
	["pine_tree", "Pine Tree", "pine_tree", "se", 1, 1, true],
	["dead_tree", "Dead Tree", "dead_tree", "se", 1, 1, true],
	["bush", "Bush", "bush", "se", 1, 1, false],
	["boulder", "Boulder", "boulder", "se", 1, 1, false],
	["rock_pile", "Rock Pile", "rock_pile", "se", 1, 1, false],
	["fallen_log", "Fallen Log", "fallen_log", "se", 2, 1, false],
	["fallen_log_y", "Fallen Log (along y)", "fallen_log", "sw", 1, 2, false],
	["trash_pile", "Trash Pile", "trash_pile", "se", 1, 1, false],
	["dumpster", "Dumpster", "dumpster", "se", 1, 1, false],
	["dumpster_y", "Dumpster (along y)", "dumpster", "sw", 1, 1, false],
	["tire_stack", "Tyre Stack", "tire_stack", "se", 1, 1, false],
	["scrap_pile", "Scrap Pile", "scrap_pile", "se", 1, 1, false],
	["street_lamp", "Street Lamp", "street_lamp", "se", 1, 1, true],
	["street_lamp_y", "Street Lamp (along y)", "street_lamp", "sw", 1, 1, true],
	["road_sign", "Road Sign", "road_sign", "se", 1, 1, false],
	["road_sign_y", "Road Sign (along y)", "road_sign", "sw", 1, 1, false],
	["bench", "Bench", "bench", "se", 1, 1, false],
	["bench_y", "Bench (along y)", "bench", "sw", 1, 1, false],
	["house_small", "Small House", "house_small", "se", 3, 3, true],
	["house_small_brick", "Brick House", "house_small_brick", "se", 3, 3, true],
	["house_large", "Large House", "house_large", "se", 4, 3, true],
	["house_large_y", "Large House (along y)", "house_large", "sw", 3, 4, true],
	["house_ruin", "Ruined House", "house_ruin", "se", 3, 3, true],
	["house_burnt", "Burnt House", "house_burnt", "se", 3, 3, true],
	["shop", "Shop", "shop", "se", 4, 3, true],
	["shop_y", "Shop (along y)", "shop", "sw", 3, 4, true],
	["shop_ruin", "Ruined Shop", "shop_ruin", "se", 4, 3, true],
	["shop_ruin_y", "Ruined Shop (along y)", "shop_ruin", "sw", 3, 4, true],
	["apartment", "Apartment Block", "apartment", "se", 4, 4, true],
	["apartment_ruin", "Ruined Apartment Block", "apartment_ruin", "se", 4, 4, true],
	["apartment_burnt", "Burning Apartment Block", "apartment_burnt", "se", 4, 4, true],
	["warehouse", "Warehouse", "warehouse", "se", 5, 3, true],
	["warehouse_y", "Warehouse (along y)", "warehouse", "sw", 3, 5, true],
	["warehouse_ruin", "Ruined Warehouse", "warehouse_ruin", "se", 5, 3, true],
	["warehouse_ruin_y", "Ruined Warehouse (along y)", "warehouse_ruin", "sw", 3, 5, true],
	["wall_ruin", "Broken Wall", "wall_ruin", "se", 2, 1, false],
	["wall_ruin_y", "Broken Wall (along y)", "wall_ruin", "sw", 1, 2, false],
	["rubble_heap", "Rubble Heap", "rubble_heap", "se", 1, 1, false],
	["rubble_field", "Rubble Field", "rubble_field", "se", 3, 3, false],
	["hq_bunker", "Command Bunker", "hq_bunker", "se", 1, 1, true],
	["concrete_wall", "Concrete Wall", "concrete_wall", "se", 2, 1, false],
	["concrete_wall_y", "Concrete Wall (along y)", "concrete_wall", "sw", 1, 2, false],
	["chain_fence", "Chain-link Fence", "chain_fence", "se", 2, 1, false],
	["chain_fence_y", "Chain-link Fence (along y)", "chain_fence", "sw", 1, 2, false],
	["sandbag_line", "Sandbag Line", "sandbag_line", "se", 2, 1, false],
	["sandbag_line_y", "Sandbag Line (along y)", "sandbag_line", "sw", 1, 2, false],
	["gate_post", "Gate Post", "gate_post", "se", 1, 1, true],
	["boom_gate", "Boom Gate", "boom_gate", "se", 1, 1, true],
	["boom_gate_y", "Boom Gate (along y)", "boom_gate", "sw", 1, 1, true],
	["watchtower", "Watchtower", "watchtower", "se", 1, 1, true],
	["floodlight", "Floodlight Tower", "floodlight", "se", 1, 1, true],
	["tent", "Army Tent", "tent", "se", 3, 2, true],
	["tent_y", "Army Tent (along y)", "tent", "sw", 2, 3, true],
	["generator", "Generator", "generator", "se", 1, 1, false],
	["generator_y", "Generator (along y)", "generator", "sw", 1, 1, false],
	["fuel_tank", "Fuel Tank", "fuel_tank", "se", 1, 1, false],
	["container_red", "Red Container", "container_red", "se", 3, 2, false],
	["container_red_y", "Red Container (along y)", "container_red", "sw", 2, 3, false],
	["container_blue", "Blue Container", "container_blue", "se", 3, 2, false],
	["container_blue_y", "Blue Container (along y)", "container_blue", "sw", 2, 3, false],
	["container_green", "Green Container", "container_green", "se", 3, 2, false],
	["container_green_y", "Green Container (along y)", "container_green", "sw", 2, 3, false],
	["radar_mast", "Radar Mast", "radar_mast", "se", 1, 1, true],
	["flag_pole", "Flag Pole", "flag_pole", "se", 1, 1, true],
	["helipad", "Helipad", "helipad", "se", 3, 3, false],
	["barracks", "Barracks", "barracks", "se", 4, 2, true],
	["barracks_y", "Barracks (along y)", "barracks", "sw", 2, 4, true],
	["barracks_ruin", "Ruined Barracks", "barracks_ruin", "se", 4, 2, true],
	["barracks_ruin_y", "Ruined Barracks (along y)", "barracks_ruin", "sw", 2, 4, true],
]


# id -> [authored model point (x, y, z), spec scale k, glow radius px, colour]; the point is in the model's own
# axes (+x forward), turned for the art that was rendered facing SW.
const GLOWS: Dictionary = {
	"street_lamp": [Vector3(0.27, 0, 1.11), 2.0, 46.0, Color(1.0, 0.85, 0.5)],
	"street_lamp_y": [Vector3(0.27, 0, 1.11), 2.0, 46.0, Color(1.0, 0.85, 0.5)],
	"floodlight": [Vector3(0.08, 0, 1.62), 1.7, 72.0, Color(1.0, 0.95, 0.8)],
	"watchtower": [Vector3(0.38, 0.2, 1.84), 1.5, 58.0, Color(1.0, 0.95, 0.7)],
	"gate_post": [Vector3(0, 0, 1.05), 1.6, 42.0, Color(1.0, 0.9, 0.6)],
	"boom_gate": [Vector3(0.1, 0, 0.2), 1.6, 20.0, Color(1.0, 0.8, 0.4)],
	"boom_gate_y": [Vector3(0.1, 0, 0.2), 1.6, 20.0, Color(1.0, 0.8, 0.4)],
	"house_burnt": [Vector3(-0.18, 0, 0.3), 1.45, 64.0, Color(1.0, 0.5, 0.15)],
	"apartment_burnt": [Vector3(0, 0, 0.4), 1.25, 96.0, Color(1.0, 0.5, 0.15)],
}


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://data/scenery")
	var written := 0
	for row in TABLE:
		var meta := _frame_info(row[2])
		if meta.is_empty():
			push_error("no frame.json for %s (render it with tools/gen_sprites.gd first)" % row[2])
			continue
		var tex := load("res://assets/sprites/%s/%s.png" % [row[2], row[3]]) as Texture2D
		if tex == null:
			push_error("missing texture %s/%s.png" % [row[2], row[3]])
			continue
		var sheet := SpriteSheet.new()
		sheet.textures = {"SE": tex}
		sheet.frame_size = Vector2i(int(meta["frame"][0]), int(meta["frame"][1]))
		sheet.columns = int(meta["columns"])
		sheet.origin = Vector2(float(meta["origin"][0]), float(meta["origin"][1]))
		var def := SceneryDefinition.new()
		def.id = row[0]
		def.display_name = row[1]
		def.sprite = sheet
		def.footprint = Vector2i(row[4], row[5])
		def.fades = row[6]
		def.height_units = float(meta.get("height", 0.0))
		if GLOWS.has(row[0]):
			var g: Array = GLOWS[row[0]]
			var p: Vector3 = g[0]
			var k: float = g[1]
			var ground := Vector2(p.x, p.y) * k if row[3] == "se" else Vector2(-p.y, p.x) * k
			def.glow_offset = IsoProjection.ground_to_screen_z(ground, p.z * k)
			def.glow_radius = g[2]
			def.glow_color = g[3]
		var err := ResourceSaver.save(def, "res://data/scenery/%s.tres" % row[0])
		if err != OK:
			push_error("could not save %s (%d)" % [row[0], err])
		else:
			written += 1
	_wrecked_car()
	written += 1
	written += _from_packs()
	print("wrote %d scenery definitions" % written)
	quit()


func _frame_info(dir: String) -> Dictionary:
	var f := FileAccess.open("res://assets/sprites/%s/frame.json" % dir, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	return parsed if parsed is Dictionary else {}


## The burnt-out car reuses the unit art (all 8 facings, one static frame).
func _wrecked_car() -> void:
	var sheet := SpriteSheet.new()
	var texs := {}
	for f in ["e", "se", "s", "sw", "w", "nw", "n", "ne"]:
		texs[f.to_upper()] = load("res://assets/sprites/wrecked_car/%s.png" % f)
	sheet.textures = texs
	sheet.frame_size = Vector2i(80, 56)
	sheet.origin = Vector2(40, 38)
	var def := SceneryDefinition.new()
	def.id = "wrecked_car"
	def.display_name = "Wrecked Car"
	def.sprite = sheet
	def.footprint = Vector2i(1, 1)
	def.fades = false
	ResourceSaver.save(def, "res://data/scenery/wrecked_car.tres")


## Definitions of every pack spec: `<dir>` (art facing se, and nw when rendered) and, when the long side was also
## rendered along ground y, `<dir>_y` (art facing sw, and ne), footprint swapped. Returns how many were written.
func _from_packs() -> int:
	var dir := DirAccess.open("res://tools/sprite_packs")
	if dir == null:
		return 0
	var files := Array(dir.get_files())
	files.sort()
	var count := 0
	for f in files:
		if not (f.begins_with("pack_") and f.ends_with(".gd")):
			continue
		var pk: GDScript = load("res://tools/sprite_packs/%s" % f)
		for spec in pk.specs():
			count += _pack_set(spec)
	return count


func _pack_set(spec: Dictionary) -> int:
	var d: String = spec["dir"]
	var meta := _frame_info(d)
	if meta.is_empty():
		push_error("no frame.json for %s (render it with tools/gen_sprites.gd first)" % d)
		return 0
	var facings: Array = spec["facings"]
	var foot: Vector2i = spec.get("foot", Vector2i(int(meta["footprint"][0]), int(meta["footprint"][1])))
	var fades: bool = spec.get("fades", float(meta["height"]) >= 1.0)
	var count := 0
	for along_y in [false, true]:
		var pair: Array = ["sw", "ne"] if along_y else ["se", "nw"]
		var textures := {}
		for i in 2:
			if pair[i] in facings:
				var tex := load("res://assets/sprites/%s/%s.png" % [d, pair[i]]) as Texture2D
				if tex == null:
					push_error("missing texture %s/%s.png" % [d, pair[i]])
					return count
				textures["SE" if i == 0 else "NW"] = tex
		if textures.is_empty():
			continue
		var sheet := SpriteSheet.new()
		sheet.textures = textures
		sheet.frame_size = Vector2i(int(meta["frame"][0]), int(meta["frame"][1]))
		sheet.columns = int(meta["columns"])
		sheet.origin = Vector2(float(meta["origin"][0]), float(meta["origin"][1]))
		var def := SceneryDefinition.new()
		def.id = d + ("_y" if along_y else "")
		def.display_name = str(spec["name"]) + (" (along y)" if along_y else "")
		def.sprite = sheet
		def.footprint = Vector2i(foot.y, foot.x) if along_y else foot
		def.fades = fades
		def.height_units = float(meta.get("height", 0.0))
		if spec.has("glow"):
			var g: Array = spec["glow"]
			var p: Vector3 = g[0]
			var k: float = spec.get("k", 1.0)
			var ground := Vector2(-p.y, p.x) * k if along_y else Vector2(p.x, p.y) * k
			def.glow_offset = IsoProjection.ground_to_screen_z(ground, p.z * k)
			def.glow_radius = g[1]
			def.glow_color = g[2]
		var err := ResourceSaver.save(def, "res://data/scenery/%s.tres" % def.id)
		if err != OK:
			push_error("could not save %s (%d)" % [def.id, err])
		else:
			count += 1
	return count
