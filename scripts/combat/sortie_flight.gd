class_name SortieFlight
extends RefCounted
## The life cycle of one sortie aircraft: flying in, holding station for a set time, flying out, done.
## Pure state machine: the caller says whether the aircraft is still moving, and issues the move orders.

enum Phase { ENTERING, ON_STATION, LEAVING, DONE }

const EPS: float = 1e-6  # a 12 s station ticked in small steps must end at 12 s, not one float-error later

var phase: Phase = Phase.ENTERING
var station_left: float


func _init(station_time_s: float) -> void:
	station_left = station_time_s


## Advances the state; returns the (possibly new) phase. `moving` = the aircraft is still flying toward its
## current order. ENTERING ends on arrival, ON_STATION after the station time, LEAVING on reaching the exit.
func update(delta: float, moving: bool) -> Phase:
	match phase:
		Phase.ENTERING:
			if not moving:
				phase = Phase.ON_STATION
		Phase.ON_STATION:
			station_left -= maxf(delta, 0.0)
			if station_left <= EPS:
				phase = Phase.LEAVING
		Phase.LEAVING:
			if not moving:
				phase = Phase.DONE
	return phase
