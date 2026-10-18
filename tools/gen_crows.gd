extends SceneTree
## Dev tool (not a test). A crow in flight for the daytime sky (docs/specs/art-more.md, N.7): two frames of a black bird, wings up and
## wings down, 14 x 10 art pixels each, side by side in assets/fx/crow.png (28 x 10). The bird flies to the right; SkyLife mirrors it.
## Run: godot --headless --path . --script tools/gen_crows.gd   (then --import)

const BODY := Color("17171c")
const LIGHT := Color("34343d")
const BEAK := Color("c8a24a")


func _init() -> void:
	var c := PixelCanvas.new(28, 10)
	for f in 2:
		var o := f * 14
		# the body and the head, a short beak
		c.ellipse(float(o) + 6.5, 5.5, 3.6, 1.9, BODY)
		c.ellipse(float(o) + 10.0, 4.6, 1.7, 1.5, BODY)
		c.px(o + 12, 5, BEAK)
		c.px(o + 13, 5, BEAK)
		c.px(o + 3, 6, BODY)  # the tail
		c.px(o + 2, 6, BODY)
		c.px(o + 2, 7, BODY)
		c.px(o + 6, 4, LIGHT)
		if f == 0:  # wings raised in a V
			c.line(Vector2(o + 6.0, 4.0), Vector2(o + 3.0, 0.5), BODY, 1.5)
			c.line(Vector2(o + 7.0, 4.0), Vector2(o + 9.0, 0.5), BODY, 1.5)
			c.px(o + 3, 0, BODY)
			c.px(o + 9, 0, BODY)
		else:  # wings pushed down
			c.line(Vector2(o + 6.0, 6.0), Vector2(o + 2.0, 9.0), BODY, 1.5)
			c.line(Vector2(o + 7.0, 6.0), Vector2(o + 10.0, 9.0), BODY, 1.5)
	c.save("res://assets/fx/crow.png")
	print("wrote assets/fx/crow.png")
	quit()
