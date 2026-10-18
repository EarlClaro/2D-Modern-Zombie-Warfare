extends SceneTree
## Dev tool (not a test). Pixel-art frame strips for the combat effects (docs/specs/art-gaps.md, G.2): a fireball that swells and
## cools into smoke, a rising smoke puff, a muzzle flash. Painted pixel by pixel from a lumpy radius, a hard colour ramp and an
## ordered-dither rim; deterministic (fixed seeds). Writes assets/fx/{explosion,smoke,flash}.png, square frames side by side.
## Run: godot --headless --path . --script tools/gen_fx_sheets.gd

const BAYER: Array = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# fire ramp, hot to cool
const FIRE: Array = [Color("fff6c8"), Color("ffd45a"), Color("f58a1f"), Color("c8401a"), Color("6e2012")]
const SMOKE: Array = [Color("8d8a85"), Color("6c6a67"), Color("4c4b49"), Color("302f2e")]
const OUTLINE := Color("1a0f0c")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/fx"))
	_explosion()
	_smoke()
	_flash()
	print("wrote assets/fx/{explosion,smoke,flash}.png")
	quit()


func _hash(x: int, y: int, seed_v: int) -> float:
	var n := x * 374761393 + y * 668265263 + seed_v * 2147483647
	n = (n ^ (n >> 13)) * 1274126177
	n = n ^ (n >> 16)
	return float(n & 0xFFFF) / 65535.0


## Lumpy radius around a blob: a few smooth bumps by angle.
func _lump(angle: float, seed_v: int, amount: float) -> float:
	var v := 0.0
	for k in [2, 3, 5]:
		v += sin(angle * float(k) + _hash(k, seed_v, 7) * TAU) * (1.0 / float(k))
	return 1.0 + v * amount


## Paints one blob into `img` (frame at column `col`, square frames of `fw` px): centre (cx, cy), radius r, colours by distance.
func _blob(img: Image, col: int, fw: int, cx: float, cy: float, r: float, ramp: Array, seed_v: int, lumpy: float, squash: float = 0.9, edge: Color = Color(0, 0, 0, 0)) -> void:
	for y in fw:
		for x in fw:
			var dx := float(x) + 0.5 - cx
			var dy := (float(y) + 0.5 - cy) / squash
			var d := sqrt(dx * dx + dy * dy)
			var rr := r * _lump(atan2(dy, dx), seed_v, lumpy)
			if d > rr:
				continue
			var t := d / rr  # 0 centre, 1 rim
			var idx := clampi(int(t * float(ramp.size())), 0, ramp.size() - 1)
			# ordered dither between two neighbouring colours near each band edge
			var band := t * float(ramp.size()) - float(idx)
			if idx < ramp.size() - 1 and band > 0.7 and (BAYER[(y % 4) * 4 + (x % 4)] as int) / 16.0 < (band - 0.7) / 0.3 * 0.9:
				idx += 1
			var c: Color = ramp[idx]
			if edge.a > 0.0 and t > 0.9:
				c = edge
			img.set_pixel(col * fw + x, y, c)


func _explosion() -> void:
	var fw := 64
	var frames := 8
	var img := Image.create(fw * frames, fw, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# frames 0..4: the fireball swells (hot core shrinks relative to it); 5..7: it cools to dark smoke
	var radii := [8.0, 16.0, 23.0, 27.0, 28.0, 27.0, 26.0, 24.0]
	for f in frames:
		var cx := 32.0
		var cy := 36.0 - float(f) * 0.8
		if f < 5:
			var ramp: Array = FIRE.slice(maxi(0, f - 2), FIRE.size())  # the hottest colours drop out as it ages
			_blob(img, f, fw, cx, cy, radii[f], ramp, 11 + f, 0.16, 0.9, OUTLINE)
			if f >= 2:
				_blob(img, f, fw, cx - 6.0, cy + 5.0, radii[f] * 0.45, ramp, 31 + f, 0.2, 0.9)  # a side lobe
		else:
			var k := f - 5
			_blob(img, f, fw, cx, cy - 2.0, radii[f], [FIRE[3], FIRE[4], SMOKE[2], SMOKE[3]].slice(mini(k, 1), 4), 41 + f, 0.2, 0.9, OUTLINE)
			_blob(img, f, fw, cx + 7.0, cy - 8.0, radii[f] * 0.5, SMOKE.slice(1, 4), 51 + f, 0.2, 0.9)
	img.save_png(ProjectSettings.globalize_path("res://assets/fx/explosion.png"))


func _smoke() -> void:
	var fw := 32
	var frames := 6
	var img := Image.create(fw * frames, fw, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in frames:
		var r := 7.0 + float(f) * 1.6
		var cy := 22.0 - float(f) * 2.0
		var ramp: Array = SMOKE.slice(0, 4) if f < 3 else SMOKE.slice(1, 4)
		_blob(img, f, fw, 16.0, cy, r, ramp, 61 + f, 0.18, 0.85)
		if f >= 1:
			_blob(img, f, fw, 11.0, cy + 3.0, r * 0.6, ramp, 71 + f, 0.2, 0.85)
	img.save_png(ProjectSettings.globalize_path("res://assets/fx/smoke.png"))


func _flash() -> void:
	var fw := 32
	var frames := 4
	var img := Image.create(fw * frames, fw, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for f in frames:
		var len_px: float = [15.0, 13.0, 9.0, 5.0][f]
		var wid: float = [5.0, 4.0, 3.0, 2.0][f]
		# a star-shaped puff pointing to the right (+x); the origin of the shot is the frame centre-left
		for y in fw:
			for x in fw:
				var dx := float(x) + 0.5 - 8.0
				var dy := float(y) + 0.5 - 16.0
				var along: float = dx / len_px
				var across: float = absf(dy) / wid
				var in_cone: bool = along > -0.2 and along < 1.0 and across < (1.0 - maxf(along, 0.0)) * 1.2
				var in_core: bool = sqrt(dx * dx + dy * dy) < wid * 1.1
				if in_cone or in_core:
					var t := clampf(maxf(along, 0.0) * 0.8 + across * 0.4, 0.0, 1.0)
					var c: Color = FIRE[clampi(int(t * 3.0), 0, 2)]
					if in_core and sqrt(dx * dx + dy * dy) < wid * 0.6:
						c = FIRE[0]
					img.set_pixel(f * fw + x, y, c)
	img.save_png(ProjectSettings.globalize_path("res://assets/fx/flash.png"))
