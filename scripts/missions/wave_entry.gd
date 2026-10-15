class_name WaveEntry
extends Resource
## `count` enemies of `enemy_id`, the first at `start_s` seconds into the mission and then one every
## `interval_s` seconds, all at spawn point `spawn_index` of the mission.

@export var start_s: float = 0.0
@export var enemy_id: String = ""
@export var count: int = 1
@export var interval_s: float = 1.0
@export var spawn_index: int = 0


## Time of the last enemy of this entry.
func last_spawn_s() -> float:
	return start_s + maxi(count - 1, 0) * interval_s
