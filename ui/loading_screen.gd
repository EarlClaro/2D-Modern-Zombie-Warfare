class_name LoadingScreen
extends CanvasLayer
## The picture shown while a mission loads (docs/specs/art-more.md, N.8): the title picture, the logo and a "Loading" line with a bar.
## `begin` puts it over the current scene, loads the battle scene on a thread, swaps to it once it is ready (the screen stays up for at
## least MIN_SHOW_S so it never flashes) and then fades out over the first frames of the battle. Presentation only.

const MIN_SHOW_S: float = 0.7
const FADE_DELAY_S: float = 0.25
const FADE_S: float = 0.5
const LOGO_PATH := "res://assets/ui/logo.png"

var _scene_path: String = ""
var _t: float = 0.0
var _swapped_at: float = -1.0
var _bar: ColorRect
var _bar_back: ColorRect
var _label: Label
var _root: Control


## Shows the screen over `tree`'s current scene and starts loading `scene_path`.
static func begin(tree: SceneTree, scene_path: String) -> LoadingScreen:
	var ls := LoadingScreen.new()
	ls._scene_path = scene_path
	ls.name = "LoadingScreen"
	ls.process_mode = Node.PROCESS_MODE_ALWAYS
	tree.root.add_child(ls)
	ResourceLoader.load_threaded_request(scene_path)
	return ls


## The dots after "Loading": none, one, two, three, round and round.
static func dots(t: float) -> String:
	return ".".repeat(int(floorf(t * 3.0)) % 4)


func _ready() -> void:
	layer = 100
	build()


## Builds the picture (also used by tests, without loading anything).
func build() -> void:
	if _root != null:
		return
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP  # clicks do not reach the menu behind
	add_child(_root)
	_root.add_child(UiKit.title_background())
	var logo_tex := load(LOGO_PATH) as Texture2D if ResourceLoader.exists(LOGO_PATH) else null
	if logo_tex != null:
		var logo := TextureRect.new()
		logo.name = "Logo"
		logo.texture = logo_tex
		logo.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		logo.stretch_mode = TextureRect.STRETCH_SCALE
		var size := logo_tex.get_size() * 4.0
		logo.custom_minimum_size = size
		logo.size = size
		logo.position = Vector2(960.0 - size.x * 0.5, 200.0)
		_root.add_child(logo)
	_bar_back = ColorRect.new()
	_bar_back.color = Color(0.05, 0.07, 0.08, 0.9)
	_bar_back.position = Vector2(660, 700)
	_bar_back.size = Vector2(600, 20)
	_root.add_child(_bar_back)
	_bar = ColorRect.new()
	_bar.color = UiKit.ACCENT
	_bar.position = Vector2(664, 704)
	_bar.size = Vector2(0, 12)
	_root.add_child(_bar)
	_label = UiKit.label("Loading", 28, UiKit.DIM)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.position = Vector2(660, 740)
	_label.size = Vector2(600, 40)
	_root.add_child(_label)


## 0..1 of how far along the bar is: the load's own progress, but never ahead of the minimum show time.
func progress_now() -> float:
	var arr: Array = []
	var status := ResourceLoader.load_threaded_get_status(_scene_path, arr) if not _scene_path.is_empty() else ResourceLoader.THREAD_LOAD_LOADED
	var loaded := 1.0 if status == ResourceLoader.THREAD_LOAD_LOADED else (float(arr[0]) if not arr.is_empty() else 0.0)
	return minf(loaded, clampf(_t / MIN_SHOW_S, 0.0, 1.0))


func _process(delta: float) -> void:
	_t += delta
	if _swapped_at >= 0.0:
		var f := (_t - _swapped_at - FADE_DELAY_S) / FADE_S
		_root.modulate.a = 1.0 - clampf(f, 0.0, 1.0)
		if f >= 1.0:
			queue_free()
		return
	if _bar != null:
		_bar.size.x = 592.0 * progress_now()
		_label.text = "Loading" + dots(_t)
	var status := ResourceLoader.load_threaded_get_status(_scene_path)
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		get_tree().change_scene_to_file(_scene_path)  # let the normal loader report what went wrong
		_swapped_at = _t
		return
	if status == ResourceLoader.THREAD_LOAD_LOADED and _t >= MIN_SHOW_S:
		var packed := ResourceLoader.load_threaded_get(_scene_path) as PackedScene
		get_tree().change_scene_to_packed(packed)
		_swapped_at = _t
		_bar.size.x = 592.0
