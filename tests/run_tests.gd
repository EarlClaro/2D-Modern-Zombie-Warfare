extends SceneTree
## Headless test runner. Usage:
##   godot --headless --path . --script tests/run_tests.gd
## Discovers res://tests/test_*.gd (not test_case.gd), runs every `test_*` method, exits non-zero on failure.

const TESTS_DIR := "res://tests"


func _init() -> void:
	var total := 0
	var failed := 0
	var files: Array[String] = _discover()
	for path in files:
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			# e.g. a parse error: report it as a failure instead of crashing the runner (which would hang).
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
		for method in script.get_script_method_list():
			var mname: String = method["name"]
			if not mname.begins_with("test_"):
				continue
			total += 1
			var before := tc.failures.size()
			tc.begin("%s::%s" % [path.get_file(), mname])
			tc.call(mname)
			if tc.failures.size() > before:
				failed += 1
				for i in range(before, tc.failures.size()):
					printerr("FAIL " + tc.failures[i])
			else:
				print("ok   %s::%s" % [path.get_file(), mname])
	print("---- %d tests, %d failed ----" % [total, failed])
	quit(1 if failed > 0 else 0)


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
