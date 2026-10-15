class_name TestCase
extends RefCounted
## Base class for test scripts. Subclasses define `test_*` methods and use the assert helpers.

var failures: Array[String] = []
var _current: String = ""


func begin(test_name: String) -> void:
	_current = test_name


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		_fail("expected true. %s" % msg)


func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if actual != expected:
		_fail("expected %s, got %s. %s" % [str(expected), str(actual), msg])


func assert_near(actual: float, expected: float, eps: float = 1e-4, msg: String = "") -> void:
	if absf(actual - expected) > eps:
		_fail("expected %s ±%s, got %s. %s" % [str(expected), str(eps), str(actual), msg])


func assert_vec_near(actual: Vector2, expected: Vector2, eps: float = 1e-4, msg: String = "") -> void:
	if not actual.is_equal_approx(expected) and actual.distance_to(expected) > eps:
		_fail("expected %s ±%s, got %s. %s" % [str(expected), str(eps), str(actual), msg])


func _fail(detail: String) -> void:
	failures.append("%s: %s" % [_current, detail])
