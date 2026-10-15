extends TestCase
## Launch-option parsing (`godot --path . -- --mission=<id> --seed=<n>`).


func test_mission_and_seed_are_parsed() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--mission=s1_stress_horde", "--seed=42"]))
	assert_eq(r["mission"], "s1_stress_horde")
	assert_eq(r["seed"], 42)


func test_only_given_keys_are_returned() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--mission=m1_hold_the_crossing"]))
	assert_true(r.has("mission"))
	assert_true(not r.has("seed"))
	assert_eq(BattleController.parse_user_args(PackedStringArray()).size(), 0)


func test_unknown_and_malformed_options_are_ignored() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--verbose", "mission=x", "--seed=abc", "--seed=", "--mission=", "--other=1"]))
	assert_eq(r.size(), 0, "nothing valid in there: %s" % str(r))


func test_negative_seed_and_last_value_wins() -> void:
	var r := BattleController.parse_user_args(PackedStringArray(["--seed=-7", "--seed=9", "--mission=a", "--mission=b"]))
	assert_eq(r["seed"], 9)
	assert_eq(r["mission"], "b")
	assert_eq(BattleController.parse_user_args(PackedStringArray(["--seed=-7"]))["seed"], -7)
