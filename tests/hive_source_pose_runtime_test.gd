extends SceneTree
const Pose = preload("res://scripts/lol2/hive_source_pose_runtime.gd")
const Owner = preload("res://scripts/lol2/hive_executioner_runtime.gd")
const Outcome = preload("res://scripts/lol2/hive_outcome_pose_runtime.gd")
func _initialize() -> void:
	var outcome_fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_outcome_animation_native.json"))
	assert(outcome_fixture.size()==600)
	for row in outcome_fixture:
		var pose := Outcome.new()
		assert(pose.restore(row.initial).is_empty())
		var result := pose.advance(row.delta,8 if row.initial.reverse else 0,2 if row.initial.frozen else 0)
		for key in ["selector","frame","timer"]: assert(int(result.state[key])==int(row.expected.state[key]))
		assert(result.events.size()==row.expected.events.size())
		for i in range(result.events.size()):
			for key in result.events[i]: assert(result.events[i][key]==row.expected.events[i][key],str(row))
		var saved := pose.checkpoint()
		var restored := Outcome.new()
		assert(restored.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
		assert(restored.advance(1024,0,0)==pose.advance(1024,0,0))
		var before := restored.checkpoint()
		assert(not restored.restore({"selector":0,"frame":0,"timer":0}).is_empty())
		assert(restored.checkpoint()==before)
		assert(restored.animation_context(0).action==(14 if int(row.initial.selector) in [17,18] else 15))
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_source_pose_runtime_native.json"))
	assert(fixture.size()==600)
	for row in fixture:
		var pose := Pose.new()
		assert(pose.restore(row.initial).is_empty())
		var result := pose.advance(row.delta,8 if row.initial.reverse else 0,2 if row.initial.frozen else 0)
		for key in ["selector","frame","timer"]: assert(int(result.state[key])==int(row.expected.state[key]))
		assert(result.events.size()==row.expected.events.size())
		for i in range(result.events.size()):
			assert(result.events[i].size()==row.expected.events[i].size())
			for key in result.events[i]: assert(result.events[i][key]==row.expected.events[i][key],str(row))
		var before := pose.checkpoint()
		assert(pose.advance(-1,0,0).has("error") and pose.checkpoint()==before)
	var actor := {"ac":1,"ad":0,"b4":0,"b5":0,"b7":1,"b9":0,"target":0}
	for selector in [17,18,19,20]:
		var seed := Owner.new()
		assert(seed.initialize_pose(actor,0,15,true,0).is_empty())
		var saved := seed.checkpoint()
		saved.pose=selector;saved.source_pose={"selector":selector,"frame":0,"timer":0}
		assert(seed.restore(saved).is_empty())
		assert(not seed.advance(6145).has("error"))
		var restored := Owner.new()
		assert(restored.restore(JSON.parse_string(JSON.stringify(seed.checkpoint()))).is_empty())
		assert(restored.advance(8192)==seed.advance(8192))
		var before := restored.checkpoint()
		assert(restored.decide({},{}).has("error") and restored.checkpoint()==before)
		var bad := before.duplicate(true);bad.attack.frame=1
		assert(not restored.restore(bad).is_empty() and restored.checkpoint()==before)
		bad=before.duplicate(true);bad.source_pose.selector=0
		assert(not restored.restore(bad).is_empty() and restored.checkpoint()==before)
		bad=before.duplicate(true);bad.version=2
		assert(not restored.restore(bad).is_empty() and restored.checkpoint()==before)
	for selector in [0,2]:
		var owner := Owner.new()
		assert(owner.initialize_pose(actor,selector,15,true,0).is_empty())
		assert(owner.advance(6145).state.frame==7)
		var saved := owner.checkpoint();var restored := Owner.new()
		assert(restored.restore(JSON.parse_string(JSON.stringify(saved))).is_empty())
		assert(restored.checkpoint()==saved)
		assert(restored.advance(8192)==owner.advance(8192))
		assert(restored.checkpoint()==owner.checkpoint())
		var before := restored.checkpoint()
		var bad := saved.duplicate(true);bad.source_pose.frame=16
		assert(not restored.restore(bad).is_empty() and restored.checkpoint()==before)
		bad=saved.duplicate(true);bad.source_pose.selector=2 if selector==0 else 0
		assert(not restored.restore(bad).is_empty() and restored.checkpoint()==before)
		var legacy := saved.duplicate(true);legacy.version=2;legacy.erase("source_pose")
		assert(restored.restore(legacy).is_empty())
		assert(restored.checkpoint().source_pose.frame==0 and restored.checkpoint().source_pose.timer==0)
	print("PASS:1200 native source/outcome pose steps, checkpoint continuation, invalid/legacy restore")
	quit()
