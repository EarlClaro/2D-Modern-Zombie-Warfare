extends TestCase
## Guards the generated humanoid, howitzer and prop sprite sheets: every facing exists, has the documented size, and has visible art in every frame.
## Layout per unit: [frame_w, frame_h, columns, frames] (see docs/ASSETS.md).

const FACINGS: Array[String] = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const SHEETS: Dictionary = {
	"runner": [72, 72, 3, 10],
	"brute": [80, 72, 3, 10],
	"rpg_soldier": [124, 76, 3, 10],
	"howitzer": [128, 104, 3, 6],
	"rifle_soldier": [88, 72, 3, 10],
	"shambler": [72, 72, 3, 10],
	"spitter": [88, 72, 3, 10],
	"sandbag_wall": [80, 64, 2, 4],
	"concrete_barrier": [80, 64, 2, 4],
	"crate_stack": [64, 56, 2, 4],
	"oil_drums": [64, 56, 2, 4],
	"tank_trap": [64, 56, 2, 4],
	"jeep": [80, 60, 3, 5],
	"supply_truck": [112, 76, 3, 5],
	"wrecked_car": [80, 56, 1, 1],
}


func _frame_has_art(img: Image, rect: Rect2i) -> bool:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if img.get_pixel(x, y).a > 0.5:
				return true
	return false


func _edge_touches_art(img: Image, rect: Rect2i) -> bool:
	for x in range(rect.position.x, rect.end.x):
		if img.get_pixel(x, rect.position.y).a > 0.5 or img.get_pixel(x, rect.end.y - 1).a > 0.5:
			return true
	for y in range(rect.position.y, rect.end.y):
		if img.get_pixel(rect.position.x, y).a > 0.5 or img.get_pixel(rect.end.x - 1, y).a > 0.5:
			return true
	return false


func test_every_new_sheet_exists_for_all_eight_facings_at_the_documented_size() -> void:
	for unit in SHEETS:
		var spec: Array = SHEETS[unit]
		var rows := ceili(float(spec[3]) / spec[2])
		for f in FACINGS:
			var tex: Texture2D = load("res://assets/sprites/%s/%s.png" % [unit, f])
			assert_true(tex != null, "%s/%s.png loads" % [unit, f])
			if tex == null:
				continue
			assert_eq(tex.get_size(), Vector2(spec[0] * spec[2], spec[1] * rows), "%s/%s size" % [unit, f])


func test_every_frame_has_art_and_none_is_clipped_by_the_frame_edge() -> void:
	for unit in SHEETS:
		var spec: Array = SHEETS[unit]
		for f in FACINGS:
			var tex: Texture2D = load("res://assets/sprites/%s/%s.png" % [unit, f])
			if tex == null:
				continue
			var img := tex.get_image()
			for k in spec[3]:
				var rect := Rect2i(Vector2i((k % spec[2]) * spec[0], (k / spec[2]) * spec[1]), Vector2i(spec[0], spec[1]))
				assert_true(_frame_has_art(img, rect), "%s/%s frame %d is not empty" % [unit, f, k])
				assert_true(not _edge_touches_art(img, rect), "%s/%s frame %d is not clipped by its frame" % [unit, f, k])
