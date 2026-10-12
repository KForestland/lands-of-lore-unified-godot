extends SceneTree
const Scoring=preload("res://scripts/lol2/hive_ai_action_choice.gd")
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/cave_roach_ai_choice_native.json"))
	var scorers: Dictionary={}
	for key in fixture.contracts:
		var scorer=Scoring.new()
		assert(scorer.configure(fixture.contracts[key],14 if key=="goals" else 15).is_empty())
		scorers[key]=scorer
	for row in fixture.cases:
		var actual: Dictionary=scorers[row.helper].choose(row.stats,row.goal)
		assert(actual.action==row.expected.action)
		for key in ["scores","contributors"]:
			for i in actual[key].size(): assert(actual[key][i]==row.expected[key][i],"Roach native scoring mismatch")
	var basic: Dictionary=fixture.contracts.goals.duplicate(true)
	basic.erase("initial_goal_bias")
	var scorer=Scoring.new()
	assert(scorer.configure(basic,14).is_empty())
	assert(scorer.choose(fixture.cases[0].stats,14).has("error"))
	assert(scorer.configure(fixture.contracts.goals,14).is_empty())
	var before: Dictionary=scorer.choose(fixture.cases[0].stats,14)
	var bad: Dictionary=fixture.contracts.goals.duplicate(true)
	bad.initial_goal_bias[0]=128
	assert(not scorer.configure(bad,14).is_empty())
	assert(scorer.choose(fixture.cases[0].stats,14)==before)
	assert(scorer.configure(basic,14).is_empty())
	assert(scorer.choose(fixture.cases[0].stats,14).has("error"))
	print("PASS:480 native Roach goal/action choices, explicit initial-goal14 bias, rejected malformed profile and safe reconfiguration")
	quit()
