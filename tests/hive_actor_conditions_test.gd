extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var vectors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_conditions_native.json"))
	for row in vectors:
		var before: Array = row.stats.duplicate()
		var result = Runtime.executioner_actor_conditions(row.stats,row.feedback,row.target_flags,row.group,row.flags_b8,row.flags_b4)
		assert(not result.has("error") and not result.complete)
		assert(result.evaluated.size() == 19 and result.conditions.size() == row.conditions.size())
		for i in range(result.conditions.size()): assert(result.conditions[i] == row.conditions[i])
		assert(row.stats == before)
		var health_matches := 0;var second_matches := 0
		for index in result.conditions:
			if index >= 5 and index <= 8: health_matches += 1
			if index >= 45 and index <= 48: second_matches += 1
		assert(health_matches == 1 and second_matches == 1)
	var bank: Array = [];bank.resize(30);bank.fill(0)
	assert(Runtime.executioner_actor_conditions(bank,65536,0,0,0,0).has("error"))
	assert(Runtime.executioner_actor_conditions(bank,0,256,0,0,0).has("error"))
	assert(Runtime.executioner_actor_conditions(bank,0,0,-1,0,0).has("error"))
	assert(Runtime.executioner_actor_conditions(bank,0,0,0,4294967296,0).has("error"))
	assert(Runtime.executioner_actor_conditions(bank,0,0,0,0,true).has("error"))
	assert(Runtime.executioner_actor_conditions([],0,0,0,0,0).has("error"))
	print("PASS: 512 native actor-condition sets; exclusive bands and signed feedback boundaries")
	quit(0)
