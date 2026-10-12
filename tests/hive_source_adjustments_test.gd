extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_source_adjustments_native.json"))
	var core = Runtime.new()
	for vector in data.vectors:
		var before := JSON.stringify(vector)
		var result = core.apply_executioner_adjustments(vector.stats,vector.events)
		assert(not result.has("error"))
		assert(result.stats.size() == 30)
		for i in range(30): assert(result.stats[i] == vector.expected[i],"Source-row native mismatch")
		assert(JSON.stringify(vector) == before)
		# Altering a returned bank cannot change cached source rows or future calls.
		result.stats[0] = -999
		assert(core.apply_executioner_adjustments(vector.stats,vector.events).stats[0] == vector.expected[0])
	assert(core.apply_executioner_adjustments([],[]).has("error"))
	print("PASS: Original EXEC adjustment rows; ",data.vectors.size()," native attack cases and cached-row isolation")
	quit(0)
