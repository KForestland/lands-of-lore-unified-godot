extends SceneTree
const Runtime=preload("res://scripts/lol2/hive_attack_runtime.gd")
const Choice=preload("res://scripts/lol2/hive_ai_action_choice.gd")
func _initialize() -> void:
	var profile: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_adjustments.json"))
	var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_effective_stats_native.json"))
	var core=Runtime.new({"version":1,"clips":[]})
	assert(core.configure_ai_adjustments(profile).is_empty())
	for row in fixtures:
		var order: Array=row.conditions.duplicate();order.reverse()
		var result: Dictionary=core.executioner_effective_stats(row.stats,row.goal,order)
		assert(not result.has("error"))
		for i in range(30): assert(result.stats[i]==row.expected[i])
	var choice: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_choice_native.json"))
	var bank: Array=choice.base_stats
	assert(bank[4]==255 and bank[9]==150 and bank[21]==200)
	assert(core.executioner_effective_stats(bank,14,[]).stats==bank)
	var scorer=Choice.new()
	assert(scorer.configure(choice.contracts.goals,14).is_empty())
	assert(scorer.choose(bank,14).action==6)
	assert(scorer.configure(choice.contracts.actions).is_empty())
	assert(scorer.choose(bank,6).action==0)
	var before: Dictionary=core.executioner_effective_stats(bank,6,[0,1,48])
	var bad: Dictionary=profile.duplicate(true);bad.conditions[48][29]=128
	assert(not core.configure_ai_adjustments(bad).is_empty())
	assert(core.executioner_effective_stats(bank,6,[48,1,0])==before)
	profile.conditions[0][0]=127
	assert(core.executioner_effective_stats(bank,6,[0,1,48])==before)
	print("PASS:512 native Roach effective banks, source initial wander/idle choice, unsigned stats, ordering, profile isolation and invalid-update rollback")
	quit()
