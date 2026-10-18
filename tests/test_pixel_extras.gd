extends TestCase
## Pixel cursor and health bars (docs/specs/art-gaps.md, G.5).


func test_cursor_picture_exists_in_whole_art_pixels() -> void:
	var tex := load(UiCursor.PATH) as Texture2D
	assert_true(tex != null)
	assert_eq(tex.get_size(), Vector2(24, 36))


func test_cursor_apply_is_harmless_without_a_window() -> void:
	UiCursor.apply()
	assert_true(true)


func test_health_bar_default_fill_is_the_documented_green() -> void:
	assert_eq(BattleDraw.DEFAULT_FILL, Color(0.35, 0.9, 0.4))
