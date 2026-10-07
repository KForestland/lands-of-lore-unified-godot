extends SceneTree
const Conditions = preload("res://scripts/lol2/hive_player_conditions.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var vectors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_conditions_native.json"))
	for row in vectors:
		var original: Dictionary = row.context.duplicate(true)
		var result := Conditions.evaluate(row.context)
		assert(not result.has("error") and not result.complete)
		assert(result.evaluated.size() == 24 and result.conditions.size() == row.conditions.size())
		for i in range(result.conditions.size()): assert(result.conditions[i] == row.conditions[i])
		assert(row.context == original)
		assert(not (12 in result.conditions and 13 in result.conditions))
		assert(not (32 in result.conditions and 33 in result.conditions))
		assert((34 in result.conditions) != (35 in result.conditions))
		assert((36 in result.conditions) != (37 in result.conditions))
	var context: Dictionary = vectors[0].context.duplicate(true)
	for field in context:
		var invalid := context.duplicate(true);invalid.erase(field)
		assert(Conditions.evaluate(invalid).has("error"))
	for pair in [["angle",128],["threshold",true],["engaged",1],["attack_modifier",-129],["action_flags",4294967296],["attack_parts",[1,2,3]],["defense_parts",[0,0,NAN]]]:
		var invalid := context.duplicate(true);invalid[pair[0]] = pair[1]
		assert(Conditions.evaluate(invalid).has("error"))
	print("PASS: 1024 native player-condition sets; thresholds, wrapping and context validation")
	quit(0)
