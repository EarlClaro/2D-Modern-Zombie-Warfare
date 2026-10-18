extends TestCase
## The pixel theme (docs/specs/pixel-ui.md, increment U.2): the project theme is the generated one, uses the pixel font,
## and every control the UI builds picks up pixel pieces.

const THEME_PATH: String = "res://assets/ui/theme.tres"


func _theme() -> Theme:
	return load(THEME_PATH) as Theme


func test_the_project_uses_the_generated_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH)
	assert_true(_theme() != null)


func test_theme_font_is_the_pixel_font() -> void:
	assert_eq(_theme().default_font.resource_path, PixelFont.PATH)
	assert_eq(_theme().default_font_size, 16)


func test_buttons_panels_lists_and_checkboxes_are_pixel_textures() -> void:
	var t := _theme()
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		assert_true(t.get_stylebox(state, "Button") is StyleBoxTexture, "Button/%s" % state)
	assert_true(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture)
	assert_true(t.get_stylebox("panel", "ItemList") is StyleBoxTexture)
	assert_true(t.get_stylebox("selected", "ItemList") is StyleBoxTexture)
	assert_true(t.get_icon("checked", "CheckButton") != null)
	assert_true(t.get_icon("grabber", "HSlider") != null)


func test_pixel_pieces_are_whole_pixel_multiples() -> void:
	var t := _theme()
	var sb := t.get_stylebox("normal", "Button") as StyleBoxTexture
	assert_eq(int(sb.texture_margin_left) % 2, 0, "margins are whole art pixels (2 screen px each)")
	assert_eq(sb.texture.get_width() % 2, 0)


func test_uikit_builds_controls_that_inherit_the_theme() -> void:
	var b := UiKit.button("Play")
	var p := UiKit.panel()
	# no per-control box overrides: they take the theme
	assert_true(not b.has_theme_stylebox_override("normal"))
	assert_true(not p.has_theme_stylebox_override("panel"))
	b.free()
	p.free()
