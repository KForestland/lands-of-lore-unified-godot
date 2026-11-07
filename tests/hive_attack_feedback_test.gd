extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
var assertions := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, context: String) -> void:
	assertions += 1
	if not ok:
		push_error(context)
		quit(1)
		assert(ok,context)
func same(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	return a == b
func initial(vector: Dictionary) -> Dictionary:
	var state = vector.initial.duplicate(true)
	state.version = Runtime.SAVE_VERSION
	state.result_total = vector.result_total
	state.result_count = vector.result_count
	return state
func totals(core, expected: Dictionary) -> void:
	var state = core.checkpoint()
	check(state.result_total == expected.result_total and state.result_count == expected.result_count,"native result counters")
func run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_attack_feedback_native.json"))
	var core = Runtime.new()
	for i in fixture.vectors.size():
		var vector = fixture.vectors[i]
		check(core.restore(initial(vector)).is_empty(),"vector setup")
		var resolver := func(_event): return vector.reply
		check(same(core.advance_native(vector.delta,resolver),vector.expected),"native feedback mismatch %d" % i)
		totals(core,vector.feedback)
	for sequence in fixture.sequences:
		check(core.restore(initial(sequence)).is_empty(),"sequence setup")
		for step in sequence.steps:
			var restored = Runtime.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(core.checkpoint()))).is_empty(),"feedback JSON restore")
			var resolver := func(_event): return sequence.reply
			var actual = core.advance_native(step.delta,resolver)
			check(same(actual,step.expected),"native feedback sequence")
			check(same(restored.advance_native(step.delta,resolver),actual),"resume event ordering")
			totals(core,step.feedback)
			totals(restored,step.feedback)
	# Version1 contained no result counters; migrate without altering attack timing.
	var legacy = core.checkpoint()
	legacy.version = 1
	legacy.erase("result_total");legacy.erase("result_count")
	check(core.restore(legacy).is_empty(),"legacy restore")
	var migrated = core.checkpoint()
	check(migrated.version == 2 and migrated.result_total == 0 and migrated.result_count == 0,"legacy counter defaults")
	check(migrated.frame == legacy.frame and migrated.timer == legacy.timer and migrated.flags == legacy.flags,"legacy timing changed")
	# A large update crosses both hits. Reject a bad second reply atomically.
	var baseline = migrated.duplicate(true)
	baseline.selector = 12;baseline.frame = 6;baseline.timer = 0
	baseline.flags = 1;baseline.base = 100;baseline.gate = true;baseline.frozen = false
	check(core.restore(baseline).is_empty(),"rollback setup")
	var calls := [0]
	var bad_second := func(_event):
		calls[0] += 1
		return {"loss":17,"remaining":83,"percentage":17} if calls[0] == 1 else {"loss":17,"remaining":0,"percentage":17}
	var rejected = core.advance_native(8192,bad_second)
	check(calls[0] == 2 and rejected.has("error") and rejected.events.is_empty(),"invalid second reply")
	check(same(core.checkpoint(),baseline),"failed feedback changed state")
	for key in ["loss","remaining","percentage"]:
		for value in [null,true,"17",-1,0.5,INF,NAN,4294967296]:
			var reply := {"loss":17,"remaining":83,"percentage":17}
			reply[key] = value
			var invalid := func(_event): return reply
			check(core.advance_native(1,invalid).has("error"),"invalid feedback field "+key)
			check(same(core.checkpoint(),baseline),"invalid reply mutated state")
		var missing := {"loss":17,"remaining":83,"percentage":17}
		missing.erase(key)
		check(not Runtime.validate_feedback(missing).is_empty(),"accepted missing reply field")
	# Callbacks cannot restore, select, recurse or save transient negative timers.
	var guarded := func(event):
		check(not core.restore(baseline).is_empty(),"reentrant restore")
		check(not core.select_attack(11),"reentrant selection")
		check(core.advance_native(1).has("error"),"reentrant advance")
		check(core.checkpoint().is_empty(),"transient snapshot escaped")
		event.amount = 9999
		return {"loss":17,"remaining":83,"percentage":17}
	var valid = core.advance_native(1,guarded)
	check(not valid.has("error") and valid.events[0].amount == 50,"callback modified emitted event")
	check(core.checkpoint().flags == 9 and core.checkpoint().result_count == 1,"immediate feedback not applied")
	print("PASS: Hive synchronous attack feedback; ",fixture.vectors.size()," native cases, 4 resumed sequences, ",assertions," assertions")
	quit(0)
