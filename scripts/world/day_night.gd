class_name DayNight
extends RefCounted
## Pure functions for the look of the time of day and the weather. `t` is the time of day in 0..1 (0 = midnight,
## 0.25 = sunrise, 0.5 = noon, 0.75 = sunset). Nothing here touches the simulation.

const WEATHER: Array[String] = ["clear", "rain", "fog", "dust", "snow"]

## Colour the whole scene is multiplied by (white = full daylight), as [t, colour] keyframes; the last wraps to the first.
## Night is a clear moonlit blue that still shows the colours of the ground (the lamps then light pools into it);
## a tint darker or greyer than this turns every sprite to mud.
const _KEYS: Array = [
	[0.00, Color(0.38, 0.47, 0.72)],
	[0.20, Color(0.46, 0.52, 0.74)],
	[0.27, Color(0.97, 0.74, 0.60)],
	[0.35, Color(1.00, 0.97, 0.90)],
	[0.50, Color(1.00, 1.00, 1.00)],
	[0.68, Color(1.00, 0.96, 0.88)],
	[0.76, Color(0.98, 0.64, 0.48)],
	[0.84, Color(0.56, 0.46, 0.66)],
	[0.92, Color(0.40, 0.48, 0.72)],
	[1.00, Color(0.38, 0.47, 0.72)],
]
const _DAY_LUM: float = 0.95
const _NIGHT_LUM: float = 0.52


## Time of day after `elapsed_s` of a mission that starts at `start` and whose day lasts `day_length_s`
## (0 = the time never changes).
static func time_at(start: float, day_length_s: float, elapsed_s: float) -> float:
	if day_length_s <= 0.0:
		return fposmod(start, 1.0)
	return fposmod(start + elapsed_s / day_length_s, 1.0)


static func tint_at(t: float) -> Color:
	var x := fposmod(t, 1.0)
	for i in range(_KEYS.size() - 1):
		var a: Array = _KEYS[i]
		var b: Array = _KEYS[i + 1]
		if x >= float(a[0]) and x <= float(b[0]):
			var f := (x - float(a[0])) / (float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1] as Color, f)
	return _KEYS[0][1]


## 0 in full daylight, 1 in deep night: how strongly lamps and fires should glow.
static func darkness_at(t: float) -> float:
	var c := tint_at(t)
	var lum := (c.r + c.g + c.b) / 3.0
	return clampf((_DAY_LUM - lum) / (_DAY_LUM - _NIGHT_LUM), 0.0, 1.0)


## Colour of the sky and of the distance haze (also the viewport clear colour, so nothing outside the map is grey):
## pale blue by day, warm at the horizon at dawn and dusk, a dark navy mist at night.
const _SKY_KEYS: Array = [
	[0.00, Color(0.035, 0.06, 0.12)],
	[0.20, Color(0.06, 0.09, 0.17)],
	[0.27, Color(0.62, 0.48, 0.46)],
	[0.35, Color(0.60, 0.72, 0.86)],
	[0.50, Color(0.58, 0.72, 0.90)],
	[0.68, Color(0.62, 0.70, 0.82)],
	[0.76, Color(0.62, 0.40, 0.36)],
	[0.84, Color(0.14, 0.12, 0.22)],
	[0.92, Color(0.05, 0.07, 0.14)],
	[1.00, Color(0.035, 0.06, 0.12)],
]
## Length of the sun's shadows relative to the noon length: long when the sun is low, short at noon; the moon
## casts them at a steady medium length.
const _SHADOW_KEYS: Array = [
	[0.00, 1.0], [0.20, 1.0], [0.27, 2.0], [0.35, 1.25], [0.50, 0.6], [0.68, 1.25], [0.76, 2.0], [0.84, 1.3], [0.92, 1.0], [1.00, 1.0],
]


static func _keyed(keys: Array, t: float) -> Variant:
	var x := fposmod(t, 1.0)
	for i in range(keys.size() - 1):
		var a: Array = keys[i]
		var b: Array = keys[i + 1]
		if x >= float(a[0]) and x <= float(b[0]):
			var f := (x - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerp(a[1], b[1], f)
	return keys[0][1]


static func sky_at(t: float) -> Color:
	return _keyed(_SKY_KEYS, t) as Color


static func shadow_scale_at(t: float) -> float:
	return float(_keyed(_SHADOW_KEYS, t))


## Extra multiplier a weather type puts on the daylight tint (overcast, dusty haze).
static func weather_tint(weather: String) -> Color:
	match weather:
		"rain":
			return Color(0.86, 0.89, 0.95)
		"fog":
			return Color(0.88, 0.9, 0.92)
		"dust":
			return Color(1.0, 0.9, 0.74)
		"snow":
			return Color(0.92, 0.95, 1.0)
	return Color.WHITE


static func is_weather(weather: String) -> bool:
	return WEATHER.has(weather)
