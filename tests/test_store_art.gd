extends TestCase
## The window icon and the loading screen (docs/specs/art-more.md, N.8).


func test_the_project_icon_is_set_and_is_a_256_px_picture() -> void:
	var path: String = ProjectSettings.get_setting("application/config/icon", "")
	assert_eq(path, "res://assets/icon/icon.png")
	var tex := load(path) as Texture2D
	assert_true(tex != null)
	assert_eq(tex.get_size(), Vector2(256, 256))


func test_the_ico_file_holds_five_sizes_as_png() -> void:
	var f := FileAccess.open("res://assets/icon/icon.ico", FileAccess.READ)
	assert_true(f != null, "icon.ico exists")
	var bytes := f.get_buffer(f.get_length())
	f.close()
	assert_eq(bytes.decode_u16(0), 0, "reserved")
	assert_eq(bytes.decode_u16(2), 1, "an icon file")
	assert_eq(bytes.decode_u16(4), 5, "five pictures")
	var sizes: Array[int] = []
	for i in 5:
		var e := 6 + 16 * i
		var w := bytes.decode_u8(e)
		sizes.append(256 if w == 0 else w)
		var offset := bytes.decode_u32(e + 12)
		assert_eq(bytes.decode_u8(offset + 1), 0x50, "a PNG starts here (P)")
		assert_eq(bytes.decode_u8(offset + 2), 0x4E, "N")
		assert_eq(bytes.decode_u8(offset + 3), 0x47, "G")
	assert_eq(sizes, [16, 32, 64, 128, 256])


func test_the_loading_screen_builds_the_logo_a_bar_and_a_label() -> void:
	var ls := LoadingScreen.new()
	tree.root.add_child(ls)  # _ready builds it
	assert_true(ls.find_child("Logo", true, false) is TextureRect)
	var found_label := false
	for l in ls.find_children("*", "Label", true, false):
		found_label = found_label or (l as Label).text.begins_with("Loading")
	assert_true(found_label, "says Loading")
	assert_true(ls.layer >= 100, "above everything")
	ls.free()


func test_the_dots_count_up_and_start_over() -> void:
	assert_eq(LoadingScreen.dots(0.0), "")
	assert_eq(LoadingScreen.dots(0.4), ".")
	assert_eq(LoadingScreen.dots(0.7), "..")
	assert_eq(LoadingScreen.dots(1.0), "...")
	assert_eq(LoadingScreen.dots(1.4), "", "and round again")


func test_the_bar_never_runs_ahead_of_the_minimum_show_time() -> void:
	var ls := LoadingScreen.new()
	tree.root.add_child(ls)
	assert_eq(ls.progress_now(), 0.0, "nothing at first")
	ls._t = LoadingScreen.MIN_SHOW_S * 0.5
	assert_near(ls.progress_now(), 0.5, 1e-4, "half way through the minimum time")
	ls._t = 5.0
	assert_eq(ls.progress_now(), 1.0)
	ls.free()
