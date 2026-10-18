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


func test_every_sheet_frame_fits_its_image() -> void:
	for id in ["barracks", "combat_drone"]:
		var s: SpriteSheet = _get_db().unit(id).sprite
		var tex: Texture2D = s.textures["SE"]
		var frames := 4 if id == "barracks" else 2
		var rows := int(ceil(float(frames) / s.columns))
		assert_eq(tex.get_size(), Vector2(s.frame_size.x * s.columns, s.frame_size.y * rows), "%s sheet size" % id)


func test_every_mission_has_command_bunker_core_art() -> void:
	for id in _get_db().missions.keys():
		assert_eq(_get_db().missions[id].core_scenery_id, "hq_bunker", id)


func test_field_entity_sprites_exist() -> void:
	for path in ["res://assets/sprites/field_mine/se.png", "res://assets/sprites/field_beacon/se.png"]:
		assert_true(ResourceLoader.exists(path), path)
	assert_true(FieldEntityView.MINE_TEX != null and FieldEntityView.BEACON_TEX != null)
