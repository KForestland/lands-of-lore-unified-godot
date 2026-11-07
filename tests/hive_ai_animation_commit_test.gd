extends SceneTree
const Choice = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Context = preload("res://scripts/lol2/hive_ai_animation_context.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")

func _initialize() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_animation_commit_native.json"))
	assert(fixture.commits.size()==1024 and fixture.contexts.size()==4096)
	for row in fixture.commits:
		var before: Dictionary = row.state.duplicate(true)
		var result := Choice.commit_animation_boundary(row.state,row.mode)
		for field in row.expected: assert(int(result.state[field])==int(row.expected[field]))
		assert(result.committed == (int(row.mode)==2))
		assert(row.state==before)
	for row in fixture.contexts:
		var result := Context.evaluate(row)
		assert(result.action==int(row.expected.action) and result.terminal==row.expected.terminal)
		assert(result.mode==int(row.expected.mode) and result.behavior==int(row.expected.behavior))
	for invalid in [null,{}, {"action":5,"frame":true,"last":16,"b4":0}]: assert(Context.evaluate(invalid).has("error"))
	var actor := {"ac":1,"ad":0,"b4":0,"b5":8,"b7":1,"b9":0x30,"target":0,"a8":7,"a9":4,"aa":1,"ab":2,"b8":0x31,"ba":9,"bb":7}
	var owner := Owner.new()
	assert(owner.initialize_pose(actor,2,15,true,0).is_empty())
	assert(not owner.commit_ai_decision(2).committed)
	var saved := owner.checkpoint();var restored := Owner.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
	assert(not restored.commit_ai_animation_boundary(1).committed)
	assert(restored.checkpoint()==saved)
	var committed := restored.commit_ai_animation_boundary(2)
	assert(committed.committed and committed.state.a8==4 and committed.state.aa==2)
	assert(committed.state.b8==1 and committed.state.b9==0 and committed.state.ba==0 and committed.state.bb==0)
	var after := restored.checkpoint()
	assert(restored.commit_ai_animation_boundary(true).has("error") and restored.checkpoint()==after)
	print("PASS:1024 animation commits,4096 contexts and deferred owner/save continuation")
	quit()
