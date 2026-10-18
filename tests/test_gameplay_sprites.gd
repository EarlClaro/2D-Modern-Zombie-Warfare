extends TestCase
## Art for the pieces that used to be code-drawn placeholders (docs/specs/art-gaps.md): the Barracks and Combat Drone have
## sprite sheets, every mission shows the command bunker as its core, and the mine and beacon sprites exist.

var _db: ContentDb


func _get_db() -> ContentDb:
	if _db == null:
		_db = ContentDb.load_from()
	return _db


func test_barracks_and_combat_drone_have_sprite_sheets() -> void:
	for id in ["barracks", "combat_drone"]:
		var u := _get_db().unit(id)
		assert_true(u.sprite != null, "%s has a sprite sheet" % id)
		assert_true(u.sprite.textures.size() >= 4, "%s has at least four facings" % id)
		assert_true(u.sprite.texture_for(IsoProjection.Facing.SE) != null)


func test_combat_drone_animates_its_rotors_without_moving() -> void:
	var s: SpriteSheet = _get_db().unit("combat_drone").sprite
	assert_true(s.always_animate)
	assert_true(s.walk_count >= 2)
	var seen := {}
	for i in 8:
		seen[s.walk_frame(float(i) * 0.05)] = true
	assert_true(seen.size() >= 2, "the rotor frames alternate")


func test_barracks_flutters_while_alive_and_burns_when_destroyed() -> void:
	var s: SpriteSheet = _get_db().unit("barracks").sprite
	assert_true(s.always_animate, "the flag and the smoke move without the barracks moving")
	var seen := {}
	for i in 12:
		seen[s.walk_frame(float(i) / s.walk_fps)] = true
	assert_eq(seen.size(), 4, "four alive frames in the loop")
	assert_true(s.has_death())
	assert_true(s.death_first >= s.walk_first + s.walk_count, "the death frames are not the alive frames")
	assert_true(s.death_first + s.death_count <= 8, "the death frames are inside the sheet")
	assert_true(s.death_count >= 4, "damaged, two burning poses, rubble")


func test_combat_drone_light_blinks() -> void:
	var s: SpriteSheet = _get_db().unit("combat_drone").sprite
	assert_eq(s.walk_count, 8)
	var img: Image = (s.textures["SE"] as Texture2D).get_image()
	var on := Image.create(s.frame_size.x, s.frame_size.y, false, Image.FORMAT_RGBA8)
	var off := on.duplicate() as Image
	on.blit_rect(img, Rect2i(s.frame_region(0)), Vector2i.ZERO)
	off.blit_rect(img, Rect2i(s.frame_region(4)), Vector2i.ZERO)
	assert_true(on.get_data() != off.get_data(), "the status light differs between frame 0 and 4")


func test_every_sheet_frame_fits_its_image() -> void:
	for id in ["barracks", "combat_drone"]:
		var s: SpriteSheet = _get_db().unit(id).sprite
		var tex: Texture2D = s.textures["SE"]
		var frames := 8
		var rows := int(ceil(float(frames) / s.columns))
		assert_eq(tex.get_size(), Vector2(s.frame_size.x * s.columns, s.frame_size.y * rows), "%s sheet size" % id)


func test_every_mission_has_command_bunker_core_art() -> void:
	for id in _get_db().missions.keys():
		assert_eq(_get_db().missions[id].core_scenery_id, "hq_bunker", id)


func test_field_entity_sprites_exist() -> void:
	for path in ["res://assets/sprites/field_mine/se.png", "res://assets/sprites/field_beacon/se.png"]:
		assert_true(ResourceLoader.exists(path), path)
	assert_true(FieldEntityView.MINE_TEX != null and FieldEntityView.BEACON_TEX != null)
