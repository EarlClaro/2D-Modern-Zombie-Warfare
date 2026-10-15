class_name SfxFactory
extends RefCounted
## Generates the placeholder sound effects in code (no audio files, no licensing; replace in Milestone 7).
## 16-bit mono at MIX_RATE. Noise uses a fixed seed so streams are identical on every run.

const MIX_RATE: int = 22050
const PEAK: float = 0.9
const SHOT_SOUNDS: Array[String] = ["shot_rifle", "shot_mg"]
const ALL_SOUNDS: Array[String] = ["shot_rifle", "shot_mg", "impact", "death", "alert", "blast"]

## Per sound: mixer category (see SfxVoicePool) and base volume in dB.
const SETTINGS: Dictionary = {
	"shot_rifle": {"category": "shot", "volume_db": -7.0},
	"shot_mg": {"category": "shot", "volume_db": -9.0},
	"impact": {"category": "impact", "volume_db": -14.0},
	"death": {"category": "death", "volume_db": -8.0},
	"alert": {"category": "alert", "volume_db": -5.0},
	"blast": {"category": "blast", "volume_db": -6.0},
}


static func is_shot_sound(sound: String) -> bool:
	return SHOT_SOUNDS.has(sound)


## All sounds as {name: AudioStreamWAV}.
static func build_library() -> Dictionary:
	return {
		"shot_rifle": _noise_burst(0.16, 26.0, 110.0, 38.0, 0.45, 11),
		"shot_mg": _noise_burst(0.075, 52.0, 170.0, 70.0, 0.6, 12),
		"impact": _noise_burst(0.06, 75.0, 0.0, 1.0, 0.35, 13),
		"death": _thud(150.0, 55.0, 0.26, 9.0, 0.3, 14),
		"alert": _beeps([880.0, 660.0], 0.14),
		"blast": _noise_burst(0.5, 8.0, 52.0, 9.0, 0.16, 15),
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
