class_name SfxFactory
extends RefCounted
## Generates the placeholder sound effects in code (no audio files, no licensing; replace in Milestone 7).
## 16-bit mono at MIX_RATE. Noise uses a fixed seed so streams are identical on every run.

const MIX_RATE: int = 22050
const PEAK: float = 0.9
const SHOT_SOUNDS: Array[String] = ["shot_rifle", "shot_mg", "missile"]
const STRIKE_SOUNDS: Array[String] = ["strike_artillery", "strike_naval", "strike_air", "strike_missile", "strike_hypersonic", "strike_nuclear", "strike_laser"]
const ALL_SOUNDS: Array[String] = ["shot_rifle", "shot_mg", "missile", "impact", "death", "alert", "blast", "explosion", "strike_artillery", "strike_naval", "strike_air", "strike_missile", "strike_hypersonic", "strike_nuclear", "strike_laser", "thunder"]

## Per sound: mixer category (see SfxVoicePool) and base volume in dB.
const SETTINGS: Dictionary = {
	"shot_rifle": {"category": "shot", "volume_db": -7.0},
	"shot_mg": {"category": "shot", "volume_db": -9.0},
	"missile": {"category": "shot", "volume_db": -8.0},
	"impact": {"category": "impact", "volume_db": -14.0},
	"death": {"category": "death", "volume_db": -8.0},
	"alert": {"category": "alert", "volume_db": -5.0},
	"blast": {"category": "blast", "volume_db": -6.0},
	"explosion": {"category": "blast", "volume_db": -3.0},
	"strike_artillery": {"category": "strike", "volume_db": -6.0},
	"strike_naval": {"category": "strike", "volume_db": -4.0},
	"strike_air": {"category": "strike", "volume_db": -6.0},
	"strike_missile": {"category": "strike", "volume_db": -6.0},
	"strike_hypersonic": {"category": "strike", "volume_db": -5.0},
	"strike_nuclear": {"category": "strike", "volume_db": -3.0},
	"strike_laser": {"category": "strike", "volume_db": -7.0},
	"thunder": {"category": "blast", "volume_db": -7.0},
}


static func is_shot_sound(sound: String) -> bool:
	return SHOT_SOUNDS.has(sound)


## All sounds as {name: AudioStreamWAV}.
static func build_library() -> Dictionary:
	return {
		"shot_rifle": _noise_burst(0.16, 26.0, 110.0, 38.0, 0.45, 11),
		"shot_mg": _noise_burst(0.075, 52.0, 170.0, 70.0, 0.6, 12),
		"missile": _noise_burst(0.45, 5.5, 85.0, 4.5, 0.5, 16),
		"impact": _noise_burst(0.06, 75.0, 0.0, 1.0, 0.35, 13),
		"death": _thud(150.0, 55.0, 0.26, 9.0, 0.3, 14),
		"alert": _beeps([880.0, 660.0], 0.14),
		"blast": _noise_burst(0.5, 8.0, 52.0, 9.0, 0.16, 15),
		"explosion": _explosion(),
		"strike_artillery": _strike_artillery(),
		"strike_naval": _strike_naval(),
		"strike_air": _strike_air(),
		"strike_missile": _strike_missile(),
		"strike_hypersonic": _strike_hypersonic(),
		"strike_nuclear": _strike_nuclear(),
		"strike_laser": _strike_laser(),
		"thunder": _noise_burst(2.6, 1.3, 36.0, 0.8, 0.045, 21),
	}


# Decaying noise (plus an optional low "thump" sine), one-pole low-passed by `smooth` (0..1, higher = brighter).
static func _noise_burst(duration: float, noise_decay: float, thump_hz: float, thump_decay: float, smooth: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		lp += (rng.randf_range(-1.0, 1.0) - lp) * smooth
		var s := lp * exp(-t * noise_decay)
		if thump_hz > 0.0:
			s += 0.9 * sin(TAU * thump_hz * t) * exp(-t * thump_decay)
		samples[i] = s
	return _to_wav(samples)


# A vehicle going up: a sharp crack, a deep falling boom, then a rumbling, crackling tail (~1.1 s).
static func _explosion() -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var duration := 1.1
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var lp := 0.0
	var rumble := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var white := rng.randf_range(-1.0, 1.0)
		lp += (white - lp) * 0.35
		rumble += (white - rumble) * 0.05
		var crack := lp * exp(-t * 38.0)
		var boom := sin(TAU * lerpf(70.0, 32.0, minf(t / 0.6, 1.0)) * t) * exp(-t * 3.2)
		var tail := rumble * 1.6 * exp(-t * 2.6)
		var crackle := 0.0
		if rng.randf() < 0.012 * exp(-t * 2.0):  # sparse late crackles
			crackle = rng.randf_range(-1.0, 1.0) * 0.8
		samples[i] = crack * 0.9 + boom * 1.1 + tail + crackle
	return _to_wav(samples)


# Falling-pitch thud with a little noise.
static func _thud(f_start: float, f_end: float, duration: float, decay: float, noise_amount: float, seed_value: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		var f := lerpf(f_start, f_end, t / duration)
		phase += TAU * f / MIX_RATE
		samples[i] = (sin(phase) + rng.randf_range(-1.0, 1.0) * noise_amount * exp(-t * 30.0)) * exp(-t * decay)
	return _to_wav(samples)


# Simple alternating square-ish beeps with a short attack/release.
static func _beeps(freqs: Array, each_s: float) -> AudioStreamWAV:
	var per := int(each_s * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(per * freqs.size())
	for k in freqs.size():
		var f: float = freqs[k]
		for i in per:
			var t := float(i) / MIX_RATE
			var env := minf(1.0, i / (0.01 * MIX_RATE)) * minf(1.0, (per - i) / (0.02 * MIX_RATE))
			var wave := signf(sin(TAU * f * t)) * 0.5 + sin(TAU * f * t) * 0.5
			samples[k * per + i] = wave * env
	return _to_wav(samples)


# --- the strike clips (one long sound per cutaway, plus the tail that rolls on over the battlefield) ----------------

## Renders `duration` seconds from a per-sample voice `voice(t, rng) -> float`; a seeded rng keeps every run identical.
static func _synth(duration: float, seed_value: int, voice: Callable) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var n := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(n)
	for i in n:
		samples[i] = voice.call(float(i) / MIX_RATE, rng)
	return _to_wav(samples)


## A volley: five guns going off a few hundredths apart, each a sharp crack on a deep thump, with a rolling echo.
static func _strike_artillery() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	var offsets := [0.0, 0.011, 0.023, 0.034, 0.046]
	return _synth(0.9, 31, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		lp[0] += (white - lp[0]) * 0.4
		lp[1] += (white - lp[1]) * 0.05
		var s := 0.0
		for o: float in offsets:
			if t >= o:
				s += lp[0] * exp(-(t - o) * 34.0) * 0.28 + sin(TAU * lerpf(95.0, 45.0, minf((t - o) / 0.3, 1.0)) * t) * exp(-(t - o) * 7.0) * 0.4
		return s + lp[1] * 1.3 * exp(-t * 3.4))


## A broadside: a huge low boom that falls in pitch, a second pulse as the blast rolls over the water, a long rumble.
static func _strike_naval() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return _synth(1.7, 32, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		lp[0] += (white - lp[0]) * 0.3
		lp[1] += (white - lp[1]) * 0.035
		var boom := sin(TAU * lerpf(58.0, 24.0, minf(t / 1.0, 1.0)) * t) * exp(-t * 2.1) * 1.2
		var late := maxf(t - 0.4, 0.0)
		var echo := 0.0
		if t > 0.4:
			echo = sin(TAU * lerpf(48.0, 22.0, minf(late / 1.0, 1.0)) * t) * exp(-late * 2.4) * 0.5
		return lp[0] * exp(-t * 22.0) * 0.9 + boom + echo + lp[1] * 1.7 * exp(-t * 1.5))


## Jets going over: a roar that swells and fades as they pass, with twelve sharp hisses as the missiles come off.
static func _strike_air() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return _synth(1.7, 33, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		var pass_env := pow(sin(PI * clampf(t / 1.5, 0.0, 1.0)), 2.0)
		lp[0] += (white - lp[0]) * lerpf(0.05, 0.22, pass_env)  # brighter as they come overhead
		lp[1] += (white - lp[1]) * 0.5
		var s: float = lp[0] * pass_env * 1.5 + sin(TAU * lerpf(90.0, 130.0, pass_env) * t) * pass_env * 0.25
		for k in 12:
			var o := 0.62 + float(k) * 0.045
			if t >= o:
				s += lp[1] * exp(-(t - o) * 30.0) * 0.35
		return s)


## A launch: a rising roar and rumble, the ignition crackle and a long fading tail.
static func _strike_missile() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return _synth(1.9, 34, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		lp[0] += (white - lp[0]) * 0.1
		lp[1] += (white - lp[1]) * 0.03
		var env := smoothstep(0.35, 0.8, t) * exp(-maxf(t - 1.0, 0.0) * 1.7)
		var crackle := 0.0
		if t > 0.6 and rng.randf() < 0.02:
			crackle = rng.randf_range(-1.0, 1.0) * 0.7 * env
		return lp[0] * env * 1.5 + lp[1] * env * 1.8 + sin(TAU * 52.0 * t) * env * 0.35 + crackle)


## A hypersonic missile: a rising whistle and tearing air, then a sharp crack and boom as it hits.
static func _strike_hypersonic() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return _synth(2.4, 35, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		var hit := 1.6
		var approach := clampf(t / hit, 0.0, 1.0)
		lp[0] += (white - lp[0]) * lerpf(0.08, 0.5, approach)
		lp[1] += (white - lp[1]) * 0.05
		var env := smoothstep(0.0, 0.5, approach) * (1.0 if t < hit else 0.0)
		var s: float = lp[0] * env * 0.9 + sin(TAU * lerpf(300.0, 2600.0, approach * approach) * t) * 0.22 * env
		if t >= hit:
			var a := t - hit
			s += lp[0] * exp(-a * 30.0) + sin(TAU * lerpf(85.0, 30.0, minf(a / 0.5, 1.0)) * a) * exp(-a * 3.5) * 1.2 + lp[1] * 1.4 * exp(-a * 2.4)
		return s)


## The bomb: a tense low hum that creeps up through the fall, a held breath, then an enormous boom and a very long rumble.
static func _strike_nuclear() -> AudioStreamWAV:
	var lp := [0.0, 0.0]
	return _synth(3.4, 36, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		lp[0] += (white - lp[0]) * 0.25
		lp[1] += (white - lp[1]) * 0.025
		var burst := 1.0
		if t < burst:
			var k := smoothstep(0.0, 0.85, t) * (1.0 - smoothstep(0.85, 0.99, t))  # drops to silence just before the flash
			return (sin(TAU * 38.0 * t) * 0.5 + sin(TAU * 57.0 * t) * 0.3) * k * 0.45
		var a := t - burst
		return lp[0] * exp(-a * 14.0) + sin(TAU * lerpf(62.0, 18.0, minf(a / 1.4, 1.0)) * a) * exp(-a * 1.1) * 1.4 + lp[1] * 2.0 * exp(-a * 0.8))


## The satellite laser: a charge whine rising in pitch, then a humming, buzzing beam that wavers while it sweeps and cuts off.
static func _strike_laser() -> AudioStreamWAV:
	var lp := [0.0]
	var phase := [0.0]
	return _synth(2.4, 37, func(t: float, rng: RandomNumberGenerator) -> float:
		var white := rng.randf_range(-1.0, 1.0)
		lp[0] += (white - lp[0]) * 0.3
		var fire := 0.68
		if t < fire:
			var k := t / fire
			phase[0] += TAU * lerpf(260.0, 2000.0, pow(k, 1.6)) / MIX_RATE
			return sin(phase[0]) * (0.1 + 0.5 * k) + lp[0] * 0.05 * k
		var a := t - fire
		var on := 1.0 - smoothstep(1.6, 1.75, a)
		phase[0] += TAU * 180.0 * (1.0 + 0.05 * sin(TAU * 4.0 * a)) / MIX_RATE
		var buzz := signf(sin(phase[0])) * 0.3 + sin(phase[0] * 2.0) * 0.25 + sin(phase[0] * 5.0) * 0.1
		return buzz * 0.7 * on + lp[0] * 0.12 * on + lp[0] * exp(-a * 18.0) * 0.8)


static func _to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.0001
	for s in samples:
		peak = maxf(peak, absf(s))
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		var v := clampf(samples[i] / peak * PEAK, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = bytes
	return wav
