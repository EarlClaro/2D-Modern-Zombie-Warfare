class_name UiCursor
extends RefCounted
## The pixel mouse arrow (assets/ui/cursor.png, made by tools/gen_ui_kit.gd): set once for the whole game. Presentation only.

const PATH: String = "res://assets/ui/cursor.png"


## Makes the arrow the system cursor's picture. Safe to call repeatedly; does nothing without a window or without the file.
static func apply() -> void:
	if DisplayServer.get_name() == "headless" or not ResourceLoader.exists(PATH):
		return
	Input.set_custom_mouse_cursor(load(PATH) as Texture2D, Input.CURSOR_ARROW, Vector2.ZERO)
