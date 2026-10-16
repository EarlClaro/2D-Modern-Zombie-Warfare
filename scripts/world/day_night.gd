class_name DayNight
extends RefCounted
## Pure functions for the look of the time of day and the weather. `t` is the time of day in 0..1 (0 = midnight,
## 0.25 = sunrise, 0.5 = noon, 0.75 = sunset). Nothing here touches the simulation.

const WEATHER: Array[String] = ["clear", "rain", "fog", "dust"]

## Colour the whole scene is multiplied by (white = full daylight), as [t, colour] keyframes; the last wraps to the first.
const _KEYS: Array = [
	[0.00, Color(0.30, 0.36, 0.58)],
	[0.20, Color(0.42, 0.45, 0.64)],
	[0.27, Color(0.95, 0.72, 0.58)],
	[0.35, Color(1.00, 0.97, 0.90)],
	[0.50, Color(1.00, 1.00, 1.00)],
	[0.68, Color(1.00, 0.96, 0.88)],
	[0.76, Color(0.98, 0.62, 0.45)],
	[0.84, Color(0.50, 0.42, 0.60)],
	[0.92, Color(0.32, 0.37, 0.58)],
	[1.00, Color(0.30, 0.36, 0.58)],
]


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
	return clampf((0.95 - lum) / (0.95 - 0.41), 0.0, 1.0)


## Extra multiplier a weather type puts on the daylight tint (overcast, dusty haze).
static func weather_tint(weather: String) -> Color:
	match weather:
		"rain":
			return Color(0.78, 0.82, 0.9)
		"fog":
			return Color(0.88, 0.9, 0.92)
		"dust":
			return Color(1.0, 0.9, 0.74)
	return Color.WHITE


static func is_weather(weather: String) -> bool:
	return WEATHER.has(weather)
