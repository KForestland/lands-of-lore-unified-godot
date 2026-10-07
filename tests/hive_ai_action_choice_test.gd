extends SceneTree
const Choice = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
const Conditions = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_action_choice_native.json"))
	assert(fixture.size() == 640)
	var chooser := Choice.new()
	assert(chooser.configure_source().is_empty())
	for row in fixture:
		if row.has("table"): assert(chooser.configure(row.table).is_empty())
		var before: Array = row.stats.duplicate()
		var result := chooser.choose(row.stats,row.goal)
		assert(result.action == int(row.expected.action))
		for i in range(15):
			assert(result.scores[i] == int(row.expected.scores[i]))
			assert(result.contributors[i] == int(row.expected.contributors[i]))
		assert(row.stats == before)
	assert(chooser.configure_source().is_empty())
	var live = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_choice_live.json"))
	assert(live.executioner.size()==43)
	for row in live.executioner:
		var result := chooser.choose(row.stats,row.goal)
		assert(result.action==int(row.result) and result.action==1)
		var pending := chooser.update_pending(row.actor_state,row.stats)
		assert(pending.chosen and pending.state.ab==1)
		assert(Choice.commit_postdecision(pending.state,1).state.aa==1)
	var actors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_actor_conditions_native.json"))
	var players = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_player_conditions_native.json"))
	var others = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_remaining_conditions_native.json"))
	var conditions := Conditions.new()
	for i in range(32):
		var actor: Dictionary = actors[i]
		var effective := conditions.evaluate(actor.stats,i%14,actor,players[i].context,others[i].context)
		assert(not effective.has("error") and effective.predicate_coverage_complete)
		assert(not chooser.choose(effective.stats,i%14).has("error"))
	var baseline := chooser.choose(fixture[0].stats,0)
	assert(not chooser.configure({"weights":[],"goals":[]}).is_empty())
	assert(chooser.choose(fixture[0].stats,0) == baseline)
	for goal in [null,true,-1,14,255,0.5]: assert(chooser.choose(fixture[0].stats,goal).has("error"))
	assert(chooser.choose([],0).has("error"))
	var bad: Array = fixture[0].stats.duplicate();bad[0] = true
	assert(chooser.choose(bad,0).has("error"))
	var control = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_commit_native.json"))
	assert(control.commits.size()==1024 and control.admissions.size()==256)
	for row in control.commits:
		var before: Dictionary = row.state.duplicate(true)
		var result := Choice.commit_postdecision(row.state,row.mode)
		for field in row.expected: assert(int(result.state[field]) == int(row.expected[field]))
		assert(row.state == before)
	var weights: Array = [];var goals: Array = []
	for i in range(30):
		var line: Array = [];line.resize(15);line.fill(0);weights.append(line)
	for i in range(14):
		var line: Array = [];line.resize(15);line.fill(0);goals.append(line)
	var stats: Array = [];stats.resize(30);stats.fill(1)
	for row in control.admissions:
		weights[0].fill(0);weights[0][int(row.chosen)] = 1
		assert(chooser.configure({"weights":weights,"goals":goals}).is_empty())
		var state := {"b5":row.b5,"a9":row.a9,"ab":row.ab}
		var result := chooser.update_pending(state,stats)
		assert(result.chosen == row.admitted)
		assert(int(result.state.ab) == (int(row.chosen) if row.admitted else int(row.ab)))
	var selected: Dictionary = {}
	for row in fixture:
		if not row.has("table") and int(row.expected.action)==2:
			selected = row;break
	assert(not selected.is_empty())
	var actor := {"ac":1,"ad":0,"b4":0,"b5":8,"b7":1,"b9":0,"target":0,"a8":selected.goal,"a9":selected.goal,"aa":1,"ab":1,"b8":0x30,"ba":0,"bb":0}
	var owner := Owner.new()
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	assert(owner.decide({},{}).has("error"))
	var pending := owner.choose_pending_action(selected.stats)
	assert(pending.chosen and pending.state.ab==2 and pending.state.aa==1)
	assert(owner.commit_ai_decision(0).state.aa==1)
	assert(owner.commit_ai_decision(1).state.aa==2)
	var saved := owner.checkpoint();var restored := Owner.new()
	assert(restored.restore(saved).is_empty() and restored.checkpoint()==saved)
	var invalid := saved.duplicate(true);invalid.actor.erase("bb")
	assert(not restored.restore(invalid).is_empty() and restored.checkpoint()==saved)
	var attack_context := {"action":0,"terminal":true,"spatial":{"z":0,"height":35,"target_z":0,"target_height":46}}
	var helpers := {"random":func(_s,_m):return 0,"behavior":func(_s):pass}
	var admitted := restored.decide(attack_context,helpers)
	assert(not admitted.has("error") and restored.checkpoint().pose==12)
	print("PASS:640 native AI action choices,1024 commits,256 admission gates and persisted owner composition")
	quit(0)
