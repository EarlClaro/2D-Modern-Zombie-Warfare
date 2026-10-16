class_name CutawayPlayer
extends CanvasLayer
## Plays the strike cutaways (docs/specs/strike-cutaways.md): when the battle asks for a clip it freezes the
## simulation, draws letterbox bars, the scene recipe and a name banner for the clip's length, then lets the
## battle run again. Space, Esc or a click skips; C switches cutaways on or off. Presentation only: the freeze
## just stops simulation ticks, so a battle plays out identically with or without clips.

const LAYER: int = 8  # above the HUD and hand, below the result panel
const BAR_SHARE: float = 0.12  # each letterbox bar, as a share of the screen height
const BAR_SLIDE_S: float = 0.12
const BANNER_FONT_SIZE: int = 34
const HINT_FONT_SIZE: int = 13

var plan: CutawayPlan = CutawayPlan.new()

var _battle: BattleController
var _sfx: SfxService
var _canvas: Control
var _scene: CutawayScene


## `sfx` is the battle's sound service (null = silent clips).
func bind(battle: BattleController, sfx: SfxService = null) -> void:
	_battle = battle
	_sfx = sfx
	layer = LAYER
	name = "Cutaways"
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_clip)
	_canvas.visible = false
	add_child(_canvas)
	battle.cutaway_requested.connect(_on_requested)
	battle.battle_started.connect(_on_battle_started)
	set_process(true)


func is_playing() -> bool:
	return plan.is_playing()


## Starts the clip for `cutaway_id` (what `cutaway_requested` does). Returns the mode chosen.
func play(cutaway_id: String) -> CutawayPlan.Mode:
	var def := _battle.db.cutaway(cutaway_id) if _battle != null and _battle.db != null else null
	var mode := plan.request(def)
	if mode == CutawayPlan.Mode.NONE:
		return mode
	_scene = CutawayScenes.build(def.scene)
	_battle.frozen = true
	_canvas.visible = true
	_canvas.queue_redraw()
	if _sfx != null and not def.sound.is_empty():
		_sfx.play(def.sound, 0.0)
	return mode


func skip() -> void:
	if plan.is_playing():
		plan.skip()
		_end()


func _on_requested(cutaway_id: String) -> void:
	play(cutaway_id)


func _on_battle_started() -> void:
	plan.reset()  # a restart cancels any clip and forgets which supports were seen
	_end()


func _end() -> void:
	if _battle != null:
		_battle.frozen = false
	if _canvas != null:
		_canvas.visible = false
	_scene = null


func _process(delta: float) -> void:
	if plan.tick(delta):  # also clears the "ended this tick" flag every frame
		_end()
	elif plan.is_playing():
		_canvas.queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		plan.enabled = not plan.enabled
		if not plan.enabled:
			skip()
		get_viewport().set_input_as_handled()
		return
	if not plan.is_playing():
		return
	var key := event as InputEventKey
	var click := event as InputEventMouseButton
	if key != null and key.pressed and not key.echo and (key.keycode == KEY_SPACE or key.keycode == KEY_ESCAPE):
		skip()
		get_viewport().set_input_as_handled()
	elif click != null and click.pressed:
		skip()
		get_viewport().set_input_as_handled()
	elif key != null and key.keycode == KEY_R:
		return  # a restart still goes through (it cancels the clip itself)
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()  # nothing but "skip" reaches the battle while it is frozen


func _draw_clip() -> void:
	var def := plan.current()
	if def == null or _scene == null:
		return
	var size := _canvas.size
	var length := plan.duration()
	var t := plan.elapsed()
	var slide := clampf(t / BAR_SLIDE_S, 0.0, 1.0)
	var bar := size.y * BAR_SHARE * slide
	var rect := Rect2(0.0, bar, size.x, size.y - bar * 2.0)
	_canvas.draw_set_transform(_scene.shake(t, length), 0.0, Vector2.ONE)
	_scene.draw(_canvas, rect, t, length)
	_canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_canvas.draw_rect(Rect2(0.0, 0.0, size.x, bar), Color.BLACK)
	_canvas.draw_rect(Rect2(0.0, size.y - bar, size.x, bar), Color.BLACK)
	var font := ThemeDB.fallback_font
	var title := def.display_name.to_upper()
	var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT_SIZE).x
	var fade := clampf(t / 0.2, 0.0, 1.0) * clampf((length - t) / 0.15, 0.0, 1.0)
	var by := size.y - bar - 24.0
	_canvas.draw_rect(Rect2(size.x * 0.06 - 12.0, by - BANNER_FONT_SIZE, tw + 24.0, BANNER_FONT_SIZE + 12.0), Color(0, 0, 0, 0.55 * fade))
	_canvas.draw_string(font, Vector2(size.x * 0.06, by), title, HORIZONTAL_ALIGNMENT_LEFT, -1, BANNER_FONT_SIZE, Color(1.0, 0.9, 0.65, fade))
	if plan.mode() == CutawayPlan.Mode.FULL:
		_canvas.draw_string(font, Vector2(size.x - 190.0, size.y - bar * 0.4), "SPACE: skip   C: clips off", HORIZONTAL_ALIGNMENT_LEFT, -1, HINT_FONT_SIZE, Color(1, 1, 1, 0.55))
