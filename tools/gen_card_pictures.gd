extends SceneTree
## Dev tool (not a test). Card pictures (docs/specs/card-loop.md "Card faces"): no new drawing, only art the game already has, cropped
## and scaled into a 96x72 picture: the unit's own sprite (SE, idle frame) for a deployment card, a cutaway image for a strike.
## Cards with neither get no file; their card face draws a small emblem in code (ui/card_art.gd). Files go to assets/cards/<card id>.png.
## Run: godot --headless --path . --script tools/gen_card_pictures.gd   (then --import)

const W := 96
const H := 72
## Cards whose picture is not a unit sprite: a cutaway image, or another unit's sprite.
const CUTAWAY: Dictionary = {
	"artillery_strike": "res://assets/cutaways/howitzer_body.png",
	"close_air_support": "res://assets/cutaways/f15e.png",
	"missile_strike": "res://assets/cutaways/missile.png",
	"naval_gunfire": "res://assets/cutaways/battleship.png",
	"nuclear_bomb": "res://assets/cutaways/nuke.png",
	"satellite_laser": "res://assets/cutaways/satellite.png",
	"hypersonic_missile": "res://assets/cutaways/hypersonic.png",
}
const UNIT_OF: Dictionary = {"convoy": "supply_truck"}


func _initialize() -> void:
	var db := ContentDb.load_from()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/cards"))
	var made := 0
	for id in db.cards.keys():
		var img: Image = null
		if CUTAWAY.has(id):
			img = Image.load_from_file(ProjectSettings.globalize_path(CUTAWAY[id]))
		else:
			var card: CardDefinition = db.cards[id]
			var uid: String = UNIT_OF.get(id, card.unit_id)
			var unit: UnitDefinition = db.unit(uid) if uid != "" else null
			var sheet: SpriteSheet = unit.sprite if unit != null else null
			if sheet != null and sheet.textures.has("SE"):
				var tex: Texture2D = sheet.textures["SE"]
				var whole := Image.load_from_file(ProjectSettings.globalize_path(tex.resource_path))
				img = whole.get_region(Rect2i(sheet.frame_region(sheet.idle_frame)))
		if img == null:
			continue
		img.convert(Image.FORMAT_RGBA8)
		var used := img.get_used_rect()
		if used.size.x == 0:
			continue
		img = img.get_region(used)
		var k := minf(float(W - 4) / img.get_width(), float(H - 4) / img.get_height())
		if k >= 1.0:
			k = floorf(k)  # whole pixels when it can be scaled up
			img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_NEAREST)
		else:
			img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_BILINEAR)
		var out := Image.create(W, H, false, Image.FORMAT_RGBA8)
		out.blit_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i((W - img.get_width()) / 2, (H - img.get_height()) / 2))
		out.save_png(ProjectSettings.globalize_path("res://assets/cards/%s.png" % id))
		made += 1
	print("wrote ", made, " card pictures")
	quit()
