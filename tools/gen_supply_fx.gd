extends SceneTree
## Dev tool (not a test). The pictures for the Supply Drop falling onto the field (docs/specs/art-more.md, N.4), written to
## assets/fx/: chute.png (an open red and white canopy with its lines, 64 x 40, the lines meeting at the bottom middle), chute_down.png
## (the same canopy lying crumpled on the ground, 40 x 12) and crate.png (a wooden crate with a red cross, 18 x 16). Deterministic.
## Run: godot --headless --path . --script tools/gen_supply_fx.gd   (then --import)

const WOOD: Array = [Color("e6bd7c"), Color("c68f4c"), Color("94622f"), Color("5e3b1c")]
const SILK_RED: Array = [Color("ee6a52"), Color("c8402f"), Color("8c2a22")]
const SILK_WHITE: Array = [Color("fffaee"), Color("e3dccb"), Color("b0a994")]
const LINE := Color("d8d2c0")


func _init() -> void:
	_chute()
	_chute_down()
	_crate()
	print("wrote assets/fx/{chute,chute_down,crate}.png")
	quit()


func _hash(x: int, y: int, seed_v: int) -> float:
	var n := x * 374761393 + y * 668265263 + seed_v * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


func _chute() -> void:
	var c := PixelCanvas.new(64, 40)
	var cx := 31.5
	var cy := 14.0
	var rx := 30.0
	var ry := 13.0
	for y in range(int(cy - ry) - 1, int(cy) + 3):
		for x in 64:
			var dx := (float(x) + 0.5 - cx) / rx
			var dy := (float(y) + 0.5 - cy) / ry
			if dx * dx + dy * dy > 1.0 or y > int(cy) + 1:
				continue
			var gore := int(floorf((dx + 1.0) * 3.5))
			var ramp: Array = SILK_RED if gore % 2 == 0 else SILK_WHITE
			var shade := 0 if dx < -0.35 else (1 if dx < 0.45 else 2)
			if dy > 0.7:
				shade = mini(shade + 1, 2)
			c.px(x, y, ramp[shade])
	for i in 6:  # the scalloped skirt
		c.ellipse(5.0 + float(i) * 10.4, cy + 2.5, 5.2, 2.6, SILK_RED[2] if i % 2 == 0 else SILK_WHITE[2])
	for x in [4.0, 19.0, 44.0, 59.0]:  # the lines down to the crate
		c.line(Vector2(x, cy + 4.0), Vector2(31.5, 38.0), LINE, 1.0)
	c.outline()
	c.save("res://assets/fx/chute.png")


func _chute_down() -> void:
	var c := PixelCanvas.new(40, 12)
	for y in 12:
		for x in 40:
			var dx := (float(x) + 0.5 - 20.0) / 18.0
			var dy := (float(y) + 0.5 - 6.5) / 4.6
			var lump := 1.0 + 0.3 * sin(float(x) * 0.7) + (_hash(x, 0, 5) - 0.5) * 0.3
			if dx * dx + dy * dy <= lump * 0.8:
				var band := (x / 5) % 2
				var ramp: Array = SILK_RED if band == 0 else SILK_WHITE
				c.px(x, y, ramp[0 if y < 5 else (1 if y < 8 else 2)])
	c.outline()
	c.save("res://assets/fx/chute_down.png")


func _crate() -> void:
	var c := PixelCanvas.new(18, 16)
	c.rect(2, 2, 14, 12, WOOD[1])
	c.rect(2, 2, 14, 2, WOOD[0])
	c.rect(2, 12, 14, 2, WOOD[2])
	c.rect(2, 2, 2, 12, WOOD[0])
	c.rect(14, 2, 2, 12, WOOD[3])
	c.line(Vector2(4.0, 4.0), Vector2(14.0, 12.0), WOOD[3], 1.0)
	c.line(Vector2(14.0, 4.0), Vector2(4.0, 12.0), WOOD[3], 1.0)
	c.rect(7, 5, 4, 4, Color("e24a3a"))
	c.rect(8, 4, 2, 6, Color("fff6dc"))
	c.rect(6, 6, 6, 2, Color("fff6dc"))
	c.outline()
	c.save("res://assets/fx/crate.png")
