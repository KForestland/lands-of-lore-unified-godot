extends SceneTree
const Conditions = preload("res://scripts/lol2/hive_remaining_conditions.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var evaluator := Conditions.new()
	var vectors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_remaining_conditions_native.json"))
	for row in vectors:
		var original: Dictionary = row.context.duplicate(true)
		var result := evaluator.evaluate(row.context)
		assert(not result.has("error") and not result.complete)
		assert(result.evaluated.size() == 6 and result.conditions.size() == row.conditions.size())
		for i in range(result.conditions.size()): assert(result.conditions[i] == row.conditions[i])
		assert(row.context == original)
	var context: Dictionary = vectors[0].context.duplicate(true)
	for field in context:
		var invalid := context.duplicate(true);invalid.erase(field)
		assert(evaluator.evaluate(invalid).has("error"))
	for pair in [["health_max",0],["secondary_max",0],["health_current",-1],["selected",1],["effect_id",256],["distance9",2147483648],["distance41",NAN],["radius41",true]]:
		var invalid := context.duplicate(true);invalid[pair[0]] = pair[1]
		assert(evaluator.evaluate(invalid).has("error"))
	print("PASS: 1024 native remaining-condition sets; boundaries, overflow, effect flags and invalid contexts")
	quit(0)
