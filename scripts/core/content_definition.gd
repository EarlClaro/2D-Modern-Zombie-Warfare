class_name ContentDefinition
extends Resource
## Base for all data-driven definitions. Definitions are immutable at runtime; runtime state lives elsewhere.
## `validate()` returns human-readable errors (empty = valid). Subclasses call `super.validate()` first.

const ID_PATTERN: String = "^[a-z][a-z0-9_]*$"

@export var id: String = ""


## Short noun used in error messages (e.g. "weapon").
func kind() -> String:
	return "definition"


func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	var re := RegEx.create_from_string(ID_PATTERN)
	if id.is_empty():
		errs.append("%s: id is empty" % kind())
	elif re.search(id) == null:
		errs.append("%s '%s': id must be lowercase snake_case (a-z, 0-9, _)" % [kind(), id])
	return errs


func _err(msg: String) -> String:
	return "%s '%s': %s" % [kind(), id, msg]
