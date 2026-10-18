class_name MusicFactory
extends RefCounted
## Music written in code (docs/specs/art-gaps.md, G.4), like the sound effects: no audio files, no licences. A tiny tracker: square,
## triangle and noise voices placed on a 16th-note grid, mixed into 16-bit mono at MIX_RATE and normalised. Two loops (the menu and
## the battle) and two short stings (win, lose). Deterministic: the same bytes on every run.

const MIX_RATE: int = 22050
const PEAK: float = 0.8
const TRACKS: Array[String] = ["menu", "battle", "victory", "defeat"]


## {name: AudioStreamWAV}. The two loops loop; the stings do not.
static func build_library() -> Dictionary:
	var lib := {}
	for t in TRACKS:
		lib[t] = build(t)
	return lib


## One track by name ("menu", "battle", "victory", "defeat"); null for an unknown name. Takes about a second for a loop.
static func build(track: String) -> AudioStreamWAV:
	match track:
		"menu":
			return _menu()
		"battle":
			return _battle()
		"victory":
			return _victory()
		"defeat":
			return _defeat()
	return null


static func midi_hz(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


# --- voices -----------------------------------------------------------------------------------------------------------

## A pitched note into `buf`: `wave` is "sq" (pulse, `duty` wide), "tri" or "sine"; `attack` and `release` in seconds, `decay` is an
## exponential fall per second (0 = sustained).
static func _note(buf: PackedFloat32Array, start_s: float, dur_s: float, midi: int, vol: float, wave: String, duty: float = 0.5, decay: float = 0.0, attack: float = 0.004, release: float = 0.05) -> void:
	var f := midi_hz(midi)
	var s0 := int(start_s * MIX_RATE)
	var n := int((dur_s + release) * MIX_RATE)
	var phase := 0.0
	var step := f / MIX_RATE
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		var env := minf(1.0, t / attack) * exp(-t * decay)
		if t > dur_s:
			env *= maxf(0.0, 1.0 - (t - dur_s) / release)
		phase += step
		phase -= floorf(phase)
		var w := 0.0
		match wave:
			"sq":
				w = 1.0 if phase < duty else -1.0
			"tri":
				w = 4.0 * absf(phase - 0.5) - 1.0
			_:
				w = sin(TAU * phase)
		buf[idx] += w * env * vol


## A burst of low-passed noise (hats and snares); `bright` 0..1 sets the filter.
static func _noise(buf: PackedFloat32Array, start_s: float, dur_s: float, vol: float, bright: float, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var s0 := int(start_s * MIX_RATE)
	var n := int(dur_s * MIX_RATE)
	var lp := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		lp += (rng.randf_range(-1.0, 1.0) - lp) * bright
		buf[idx] += lp * vol * exp(-float(i) / float(n) * 6.0)


## A kick drum: a sine that falls from 140 to 45 Hz.
static func _kick(buf: PackedFloat32Array, start_s: float, vol: float) -> void:
	var s0 := int(start_s * MIX_RATE)
	var n := int(0.22 * MIX_RATE)
	var phase := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= buf.size():
			break
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(140.0, 45.0, minf(t / 0.12, 1.0)) / MIX_RATE
		buf[idx] += sin(phase) * vol * exp(-t * 14.0)


static func _to_stream(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var peak := 0.0001
	for s in buf:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] / peak * PEAK, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = buf.size()
	return wav


static func _buffer(seconds: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(seconds * MIX_RATE))
	return b


# --- the menu loop: A minor, slow, a soft arpeggio over a bass and a pad (8 bars, about 25 s) ------------------------------

static func _menu() -> AudioStreamWAV:
	var bpm := 78.0
	var step := 60.0 / bpm / 4.0
	var bars := 8
	var buf := _buffer(step * 16.0 * float(bars))
	# Am, F, C, G, two bars each... played as Am F C G Am F C G
	var roots := [45, 41, 48, 43, 45, 41, 48, 43]
	var chords := [[57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62], [57, 60, 64], [53, 57, 60], [60, 64, 67], [55, 59, 62]]
	# the lead: [step in bar, note, length in steps]
	var lead := [
		[[0, 76, 8], [8, 72, 4], [12, 74, 4]], [[0, 72, 8], [8, 69, 8]], [[0, 76, 6], [8, 79, 4], [12, 76, 4]], [[0, 74, 8], [8, 71, 4], [12, 74, 4]],
		[[0, 69, 4], [4, 72, 4], [8, 76, 8]], [[0, 77, 6], [8, 76, 4], [12, 72, 4]], [[0, 79, 4], [4, 76, 4], [8, 72, 8]], [[0, 74, 6], [8, 71, 8]],
	]
	for b in bars:
		var t0 := float(b) * 16.0 * step
		_note(buf, t0, step * 6.0, roots[b], 0.5, "tri", 0.5, 1.2)  # bass on the 1 and the 3
		_note(buf, t0 + 8.0 * step, step * 6.0, roots[b], 0.42, "tri", 0.5, 1.2)
		for k in 3:  # the pad: the chord held for the bar
			_note(buf, t0, step * 15.0, chords[b][k] - 12, 0.07, "tri", 0.5, 0.0, 0.35, 0.4)
		for s in range(0, 16, 2):  # the arpeggio on the 8th notes
			var tone: int = chords[b][(s / 2) % 3] + (12 if (s / 2) % 4 == 3 else 0)
			_note(buf, t0 + float(s) * step, step * 1.6, tone, 0.1, "sq", 0.25, 5.0)
		for n in lead[b]:
			_note(buf, t0 + float(n[0]) * step, float(n[2]) * step, n[1], 0.11, "sq", 0.5, 0.6, 0.02, 0.12)
	return _to_stream(buf, true)


# --- the battle loop: D minor, a driving pulse with drums (8 bars, about 18 s) ------------------------------------------------

static func _battle() -> AudioStreamWAV:
	var bpm := 104.0
	var step := 60.0 / bpm / 4.0
	var bars := 8
	var buf := _buffer(step * 16.0 * float(bars))
	var roots := [50, 50, 46, 46, 43, 43, 45, 45]  # Dm Dm Bb Bb Gm Gm A A
	var chords := [[62, 65, 69], [62, 65, 69], [58, 62, 65], [58, 62, 65], [55, 58, 62], [55, 58, 62], [57, 61, 64], [57, 61, 64]]
	var motif := [[0, 74, 3], [4, 77, 3], [8, 76, 3], [12, 74, 4]]  # played on every second bar
	for b in bars:
		var t0 := float(b) * 16.0 * step
		for s in range(0, 16, 2):  # the pulse
			var accent := 1.0 if s % 8 == 0 else 0.75
			_note(buf, t0 + float(s) * step, step * 1.4, roots[b], 0.2 * accent, "sq", 0.5, 7.0)
		for s in [0, 8, 10]:
			_kick(buf, t0 + float(s) * step, 0.5)
		for s in [4, 12]:
			_noise(buf, t0 + float(s) * step, 0.14, 0.3, 0.5, 100 + b * 4 + s)
		for s in [2, 6, 10, 14]:
			_noise(buf, t0 + float(s) * step, 0.05, 0.1, 0.9, 200 + b * 4 + s)
		for s in [0, 10]:  # short chord stabs
			for k in 3:
				_note(buf, t0 + float(s) * step, step * 2.0, chords[b][k], 0.05, "sq", 0.125, 4.0)
		if b % 2 == 0:
			for n in motif:
				_note(buf, t0 + float(n[0]) * step, float(n[2]) * step, n[1] + (0 if b < 4 else -2), 0.1, "sq", 0.25, 1.5, 0.01, 0.08)
	return _to_stream(buf, true)


# --- the stings -------------------------------------------------------------------------------------------------------------

static func _victory() -> AudioStreamWAV:
	var buf := _buffer(2.6)
	var notes := [72, 76, 79, 84]
	for i in notes.size():
		_note(buf, float(i) * 0.13, 0.2, notes[i], 0.3, "sq", 0.25, 2.0)
	for n in [72, 76, 79, 84]:
		_note(buf, 0.55, 1.6, n, 0.12, "tri", 0.5, 1.4, 0.01, 0.4)
	_note(buf, 0.55, 1.6, 48, 0.3, "tri", 0.5, 1.2, 0.01, 0.4)
	return _to_stream(buf, false)


static func _defeat() -> AudioStreamWAV:
	var buf := _buffer(3.2)
	var notes := [69, 65, 62, 57]
	for i in notes.size():
		_note(buf, float(i) * 0.32, 0.5, notes[i], 0.28, "sq", 0.5, 2.5, 0.01, 0.15)
	_note(buf, 0.0, 2.8, 45, 0.3, "tri", 0.5, 0.6, 0.05, 0.6)
	_note(buf, 1.3, 1.6, 57, 0.1, "tri", 0.5, 1.0, 0.05, 0.6)
	_note(buf, 1.3, 1.6, 60, 0.1, "tri", 0.5, 1.0, 0.05, 0.6)
	return _to_stream(buf, false)
