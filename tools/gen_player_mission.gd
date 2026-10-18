extends SceneTree
## Dev tool (not a test): writes data/missions/x12_open_orders.tres, the first mission that runs on the player's own deck
## (docs/specs/progression.md, increment 5.6). It reuses the Dead Highway map, defenders and wave list of
## x8_dead_highway and scales the waves by WAVE_SCALE, which was tuned with `tools/tune_cards.gd --sample=weak|balanced|strong`
## (docs/BALANCE.md "5.6"). Run: godot --headless --path . --script tools/gen_player_mission.gd

const SOURCE: String = "x8_dead_highway"
const ID: String = "x12_open_orders"
## Enemy-count multiplier on the source waves. Tuned by the bot sweeps.
const WAVE_SCALE: float = 1.25


func _init() -> void:
	var base := load("res://data/missions/%s.tres" % SOURCE) as MissionDefinition
	var m: MissionDefinition = base.duplicate()
	m.id = ID
	m.display_name = "Open Orders"
	m.deck_source = MissionDefinition.DeckSource.PLAYER
	m.deck_id = "starter"  # the deck for plain launches (tools, tests); the menu gives the player's own
	m.doctrines = PackedStringArray()
	var units: Array[StartUnit] = []
	for su in base.start_units:
		units.append(su.duplicate())
	m.start_units = units
	var waves: Array[WaveEntry] = []
	for w in base.waves:
		var c: WaveEntry = w.duplicate()
		c.count = maxi(1, int(round(float(w.count) * WAVE_SCALE)))
		c.interval_s = w.interval_s / WAVE_SCALE
		waves.append(c)
	m.waves = waves
	var errs := m.validate()
	for e in errs:
		push_error(e)
	var err := ResourceSaver.save(m, "res://data/missions/%s.tres" % ID)
	if err != OK:
		push_error("saving %s failed (%d)" % [ID, err])
		quit(1)
		return
	print("%s: %d enemies in %d waves, core %.0f, %.0f s" % [ID, m.total_enemies(), m.waves.size(), m.core_health, m.duration_s])
	quit(1 if not errs.is_empty() else 0)
