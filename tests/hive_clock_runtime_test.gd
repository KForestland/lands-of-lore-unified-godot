extends SceneTree
const Clock = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var vectors = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_clock_step_native.json"))
	var core = Attack.new()
	for row in vectors:
		var original: Dictionary = row.before.duplicate(true)
		var step := Clock.advance_native(row.before,row.elapsed_ticks)
		assert(not step.has("error"))
		assert(row.before == original)
		var paused := Clock.advance_native(row.before,row.elapsed_ticks,false)
		assert(not paused.advanced and paused.state == row.before)
		assert(paused.delta == 0 and not paused.status_gate)
		paused.state.samples[0] = -1
		assert(row.before == original)
		for field in row.result: assert(step[field] == row.result[field])
		for field in ["cursor","fraction8","fraction16","status_accum","seconds"]:
			assert(step.state[field] == row.after[field])
		for i in range(4): assert(step.state.samples[i] == row.after.samples[i])
		# The recovered bounded delta is accepted by the existing attack core.
		assert(not core.advance_native(step.delta).has("error"))
	var state := Clock.initial_state()
	for invalid in [null,true,"8",-1,0.5,INF,NAN,2147483648]:
		assert(Clock.advance_native(state,invalid).has("error"))
	assert(Clock.advance_native({},8).has("error"))
	var bad := state.duplicate(true);bad.samples[0] = 481
	assert(Clock.advance_native(bad,8).has("error"))
	# Integer time conversion is invariant under partitioning before sampling.
	var phase := 0
	var count := 0
	for us in [16667,16666,16667,950000]:
		var converted := Clock.advance_reference_time(state,us,phase)
		assert(not converted.has("error"))
		phase = converted.phase;count += converted.counter_ticks
	var whole := Clock.advance_reference_time(state,1000000,0)
	assert(count == whole.counter_ticks and phase == whole.phase)
	assert(count == 480)
	# Warm history, pause for30 seconds, then resume at a normal frame interval.
	for i in range(20): state = Clock.advance_native(state,8).state
	var frozen := state.duplicate(true)
	var paused := Clock.advance_reference_time(state,30000000,phase,false)
	assert(not paused.advanced and paused.state == frozen)
	var resumed := Clock.advance_reference_time(paused.state,16667,paused.phase)
	assert(resumed.advanced and resumed.counter_ticks <= 9 and resumed.delta <= 264)
	var expected := Clock.advance_native(frozen,resumed.counter_ticks)
	assert(resumed.state == expected.state and resumed.delta == expected.delta)
	for field in ["cursor","fraction8","fraction16","status_accum","seconds"]:
		var invalid_state := frozen.duplicate(true);invalid_state[field] = -1
		assert(Clock.advance_reference_time(invalid_state,1,0,false).has("error"))
	assert(Clock.advance_reference_time(state,-1,0).has("error"))
	assert(Clock.advance_reference_time(state,1,2485000000).has("error"))
	print("PASS: 1280 native clock vectors, attack delta composition and invalid input checks")
	quit(0)
