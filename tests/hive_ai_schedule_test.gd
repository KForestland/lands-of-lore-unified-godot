extends SceneTree
const Schedule = preload("res://scripts/lol2/hive_ai_schedule.gd")
func actor(active_region: bool = false) -> Dictionary:
	return {"allocated":true,"a8":6,"b5":0,"actor70":3,"region_present":true,"region_flags":4 if active_region else 0,"object_flags":0}
func _initialize() -> void:
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_schedule_native.json"))
	for fixture in cases:
		var snapshot: Array = []
		for i in fixture.pattern.size():
			var p: Array = fixture.pattern[i]
			snapshot.append({"allocated":bool(p[0]),"a8":p[1],"b5":fixture.initial_b5[i],"actor70":fixture.actor70[i],"region_present":bool(p[2]),"region_flags":4 if p[3] else 0,"object_flags":32 if p[4] else 0})
		var state: Dictionary = Schedule.begin(snapshot.size(),[fixture.cursor,fixture.cursor]).state
		var calls: Array = []
		for n in range(snapshot.size()+3):
			var before := snapshot.duplicate(true)
			var step := Schedule.next_action(state,snapshot)
			assert(not step.has("error") and snapshot == before)
			state = JSON.parse_string(JSON.stringify(step.state))
			if step.get("done",false): break
			var action: Dictionary = step.action
			var site := 0xab203 if action.pass == 0 else (0xab2cb if action.type == "decision" else (0xab2d6 if snapshot[action.index].region_present else 0xab2ec))
			calls.append([site,action.index])
			if action.has("set_b5"): snapshot[action.index].b5 = action.set_b5
		if JSON.parse_string(JSON.stringify(calls)) != fixture.calls or state.cursors != fixture.cursors:
			printerr("Mismatch: ",fixture," actual calls=",calls," cursors=",state.cursors)
			quit(1);return
		assert(Schedule.next_action(state,snapshot).get("done",false))
		for i in snapshot.size(): assert(snapshot[i].b5 == fixture.final_b5[i])
	# Decision changes made by the caller must affect the second pass.
	var snapshot := [actor(),actor(true),actor()]
	var start: Dictionary = Schedule.begin(3,[0,0]).state
	var first := Schedule.next_action(start,snapshot)
	assert(first.action.index == 1 and first.action.set_b5 == 12)
	snapshot[1].region_flags = 0
	var second := Schedule.next_action(first.state,snapshot)
	assert(second.action.index == 1 and second.action.pass == 1)
	# Cleanup can deallocate the next candidate before that slot is examined.
	snapshot = [actor(),actor(),actor()];snapshot[1].region_present = false
	first = Schedule.next_action(start,snapshot)
	assert(first.action.type == "cleanup" and first.action.index == 1)
	snapshot[2] = {"allocated":false}
	second = Schedule.next_action(first.state,snapshot)
	assert(second.action.type == "decision" and second.action.index == 0)
	assert(Schedule.next_action(Schedule.begin(3,[-1,-1]).state,snapshot).done)
	assert(Schedule.next_action(Schedule.begin(0,[0,0]).state,[]).done)
	assert(Schedule.begin(3,[0,3]).has("error"))
	assert(Schedule.begin(3,[false,0]).has("error"))
	assert(Schedule.next_action(start,[]).has("error"))
	var invalid := start.duplicate(true);invalid.pass = 3
	assert(Schedule.next_action(invalid,snapshot).has("error"))
	print("PASS: native AI scan fixtures, cursor serialization, mode writes and interleaved caller mutations")
	quit(0)
