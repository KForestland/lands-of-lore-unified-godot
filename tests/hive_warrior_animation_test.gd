extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void:
	var evidence: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-warrior-animation-checks.json"))
	var core=Runtime.new({"version":1,"clips":evidence.clips})
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_warrior_animation_native.json"))
	for row in cases:
		var saved: Dictionary=row.initial.duplicate(true)
		saved.merge({"version":2,"flags":1,"base":100,"gate":true,"result_total":0,"result_count":0})
		assert(core.restore(saved).is_empty())
		var result: Dictionary=core.advance_native(row.delta)
		assert(not result.has("error"))
		for key in ["selector","frame","timer","flags"]:
			assert(result.state[key]==row.expected.state[key],"Native warrior state mismatch: "+str(row))
		assert(result.events.size()==row.expected.events.size())
		for index in range(result.events.size()):
			var actual: Dictionary=result.events[index]
			var expected: Dictionary=row.expected.events[index]
			assert(actual.size()==expected.size())
			for key in expected: assert(actual.has(key) and actual[key]==expected[key],"Native warrior event mismatch")
	var before: Dictionary=core.checkpoint()
	var invalid: Dictionary=before.duplicate(true)
	invalid.selector=255
	assert(not core.restore(invalid).is_empty() and core.checkpoint()==before)
	print("PASS ",cases.size()," warrior native frame updates and unknown-selector rollback")
	quit()
