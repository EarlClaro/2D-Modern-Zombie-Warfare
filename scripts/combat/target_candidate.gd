class_name TargetCandidate
extends RefCounted
## A snapshot of something that can be targeted: stable id, ground position (tiles), alive flag.
## Built by the battle each tick so TargetingService stays free of nodes.

var id: int
var pos: Vector2
var alive: bool


func _init(p_id: int, p_pos: Vector2, p_alive: bool = true) -> void:
	id = p_id
	pos = p_pos
	alive = p_alive
