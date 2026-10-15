extends SceneTree
## Headless test runner. Usage:
##   godot --headless --path . --script tests/run_tests.gd
## Discovers res://tests/test_*.gd (not test_case.gd), runs every `test_*` method, exits non-zero on failure.
##
## Safety nets (a test must never "pass" while something is broken):
##  - a test script that fails to compile is reported as a failure;
##  - any engine/script error (type ERROR or SCRIPT, e.g. a null access inside a test or in the code it
##    calls, or push_error) logged while a test runs fails that test, even though GDScript would otherwise
##    abort the test function silently;
##  - the runner always reaches quit(): a crash inside the runner itself exits non-zero instead of hanging.

const TESTS_DIR := "res://tests"


## Collects error-level log output so it can be attributed to the test that was running.
class ErrorCollector:
	extends Logger
	var errors: Array[String] = []

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array[ScriptBacktrace]) -> void:
		# error_type: 0 = ERROR, 1 = WARNING, 2 = SCRIPT, 3 = SHADER. Warnings are not failures.
		if error_type == 1:
			return
		var text := rationale if not rationale.is_empty() else code
		errors.append("%s:%d in %s: %s" % [file.get_file(), line, function, text])


## Tests run inside the first frame callback: under `--script` the root window is not yet inside the tree
## in _init()/_initialize(), but it is in _process(). Tests that add nodes under `tree.root` (flashes,
## tweens, death collapse) need that live tree.
var _started: bool = false


func _process(_delta: float) -> bool:
	if _started:
		return true
	_started = true
	var ok = _run_all()
	# If _run_all itself hit a runtime error it returns null; treat that as failure rather than hanging.
	quit(0 if ok == true else 1)
	return false


func _run_all() -> bool:
	var total := 0
	var failed := 0
	var collector := ErrorCollector.new()
	OS.add_logger(collector)
	var files: Array[String] = _discover()
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			printerr("FAIL %s: script failed to load/compile (see errors above)" % path)
			total += 1
			failed += 1
			continue
		var instance: Variant = script.new()
		if not (instance is TestCase):
			printerr("FAIL %s does not extend TestCase" % path)
			failed += 1
			continue
		var tc: TestCase = instance
		tc.tree = self
		for method in script.get_script_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			var before := tc.failures.size()
			tc.begin("%s::%s" % [path.get_file(), mname])
			collector.errors.clear()
			tc.call(mname)
			if not collector.errors.is_empty():
				tc.failures.append("%s::%s: engine/script error(s) while running: %s" % [path.get_file(), mname, " | ".join(collector.errors)])
			if tc.failures.size() > before:
				failed += 1
				for i in range(before, tc.failures.size()):
					printerr("FAIL " + tc.failures[i])
			else:
				print("ok   %s::%s" % [path.get_file(), mname])
	OS.remove_logger(collector)
	print("---- %d tests, %d failed ----" % [total, failed])
	return failed == 0


func _discover() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd":
			out.append("%s/%s" % [TESTS_DIR, f])
	out.sort()
	return out
