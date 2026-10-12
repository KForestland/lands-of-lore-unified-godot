extends SceneTree
const Goals = preload("res://scripts/lol2/hive_ai_goal_choice.gd")
const Actions = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")

func table(columns: int, winner: int) -> Dictionary:
	var weights: Array = [];var goals: Array = []
	for i in range(30):
		var row: Array = [];row.resize(columns);row.fill(0);weights.append(row)
	for i in range(14):
		var row: Array = [];row.resize(columns);row.fill(0);goals.append(row)
	weights[0][winner] = 1
	return {"weights":weights,"goals":goals}

func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_goal_choice_native.json"))
	assert(fixture.choices.size()==640 and fixture.admissions.size()==256)
	var goals := Goals.new();var actions := Actions.new()
	assert(goals.configure_source().is_empty())
	for row in fixture.choices:
		if row.has("table"): assert(goals.configure(row.table).is_empty())
		var result := goals.choose(row.stats,row.previous_goal)
		assert(result.goal == int(row.expected.goal))
		for i in range(14):
			assert(result.scores[i] == int(row.expected.scores[i]))
			assert(result.contributors[i] == int(row.expected.contributors[i]))
	var stats: Array = [];stats.resize(30);stats.fill(1)
	for row in fixture.admissions:
		assert(goals.configure(table(14,int(row.chosen_goal))).is_empty())
		var action_table := table(15,int(row.chosen_action))
		# Distinct biases prove action selection receives the updated goal.
		for i in range(14): action_table.goals[i][int(row.chosen_action)] = i
		assert(actions.configure(action_table).is_empty())
		var saved := {"b5":row.b5,"a9":row.a9,"ab":row.ab}
		var before := saved.duplicate(true)
		var goal_result := goals.update_pending(saved,stats)
		var action_result := actions.update_pending(goal_result.state,stats)
		assert(goal_result.chosen == row.goal_enabled and action_result.chosen == row.action_enabled)
		var expected_goal := int(row.chosen_goal if row.goal_enabled else row.a9)
		assert(int(action_result.state.a9)==expected_goal)
		assert(int(action_result.state.ab)==int(row.chosen_action if row.action_enabled else row.ab))
		if row.action_enabled:
			assert(action_result.choice == actions.choose(stats,expected_goal))
		assert(saved==before)
	assert(goals.configure_source().is_empty() and actions.configure_source().is_empty())
	var actor := {"ac":1,"ad":0,"b4":0,"b5":12,"b7":1,"b9":0,"target":0,"a8":7,"a9":7,"aa":1,"ab":1,"b8":0x30,"ba":0,"bb":0}
	for row in fixture.choices.slice(0,32):
		var owner := Owner.new()
		assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
		var expected_goal := goals.choose(row.stats,7)
		var expected_action := actions.choose(row.stats,expected_goal.goal)
		var result := owner.choose_pending_ai(row.stats)
		assert(result.state.a9==expected_goal.goal and result.state.ab==expected_action.action)
		assert(result.state.a8==7 and result.state.aa==1)
		var saved := owner.checkpoint();var restored := Owner.new()
		assert(restored.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
		assert(restored.checkpoint()==saved)
		assert(owner.choose_pending_ai([]).has("error") and owner.checkpoint()==saved)
		assert(owner.commit_ai_decision(1).state.aa==expected_action.action)
	var baseline := goals.choose(stats,7)
	assert(not goals.configure(table(15,0)).is_empty())
	assert(goals.choose(stats,7)==baseline)
	for invalid in [null,true,-1,14,0.5]: assert(goals.choose(stats,invalid).has("error"))
	print("PASS:640 native goal choices,256 ordered gates,32 owner/checkpoint compositions")
	quit()
