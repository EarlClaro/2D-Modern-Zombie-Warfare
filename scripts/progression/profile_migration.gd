class_name ProfileMigration
extends RefCounted
## Upgrades an older profile file to the current layout, one version step at a time (docs/specs/progression.md).
## Works on the parsed dictionary so a step can rename, move or add fields before PlayerProfile reads it. A file with
## no `version` counts as version 0. A file from a newer game is never changed (the store keeps it read-only).


class Outcome:
	extends RefCounted
	var data: Dictionary = {}
	var from_version: int = 0
	var to_version: int = 0
	## True when the file is newer than this game understands: `data` is the original, untouched.
	var too_new: bool = false

	func migrated() -> bool:
		return not too_new and to_version != from_version


## The step that turns a version-N file into version N + 1 sits at index N. Tests pass their own list.
static func default_steps() -> Array[Callable]:
	return [ProfileMigration._v0_to_v1]


static func version_of(data: Dictionary) -> int:
	var v: Variant = data.get("version")
	if (v is int) or (v is float and is_finite(v)):
		return maxi(int(v), 0)
	return 0


## Applies every step from the file's version up to `target`. A missing step (a gap in the chain) stops the walk at the
## last version it could reach, so a bad chain never produces a half-converted file labelled as current.
static func upgrade(data: Dictionary, target: int = PlayerProfile.CURRENT_VERSION, steps: Array[Callable] = []) -> Outcome:
	var out := Outcome.new()
	out.from_version = version_of(data)
	out.data = data.duplicate(true)
	out.to_version = out.from_version
	if out.from_version > target:
		out.too_new = true
		return out
	var chain: Array[Callable] = steps if not steps.is_empty() else default_steps()
	var v := out.from_version
	while v < target:
		if v >= chain.size() or not chain[v].is_valid():
			break
		out.data = chain[v].call(out.data)
		v += 1
		out.data["version"] = v
	out.to_version = v
	return out


## Version 0 had no version field and may lack any of today's fields: it is today's layout without the stamp, so the step
## only makes sure the containers exist (PlayerProfile.from_dict fills in whatever else is missing).
static func _v0_to_v1(data: Dictionary) -> Dictionary:
	var d := data.duplicate(true)
	for key in ["collection", "deck", "doctrines"]:
		if not (d.get(key) is Array):
			d[key] = []
	for key in ["missions", "rewards"]:
		if not (d.get(key) is Dictionary):
			d[key] = {}
	return d
