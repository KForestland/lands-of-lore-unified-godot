extends SceneTree
const Timing = preload("res://scripts/lol2/hive_timing_state.gd")
const Clock = preload("res://scripts/lol2/hive_clock_runtime.gd")
func _initialize() -> void:
	var clock := {"samples":[8,7,9,8],"cursor":3,"fraction8":127,"fraction16":65500,"status_accum":3932159,"seconds":59}
	var original := clock.duplicate(true)
	var state: Dictionary = Timing.checkpoint(clock,123456789,15).checkpoint
	assert(clock == original)
	var restored := Timing.restore(JSON.parse_string(JSON.stringify(state)))
	assert(not restored.has("error") and restored.checkpoint == state)
	assert(restored.checkpoint.phase is int and restored.checkpoint.executioner_a3 is int)
	for value in restored.checkpoint.clock.samples: assert(value is int)
	# A saved interval just before the status/minute boundary keeps exactly its phase.
	var direct := Clock.advance_reference_time(state.clock,16667,state.phase)
	var resumed := Clock.advance_reference_time(restored.checkpoint.clock,16667,restored.checkpoint.phase)
	assert(direct == resumed and resumed.status_gate and resumed.minute_gate)
	assert(restored.checkpoint.executioner_a3 == 15)
	# Suspend without accumulating controller catch-up; preserve the resulting phase.
	var paused := Clock.advance_reference_time(state.clock,30000000,state.phase,false)
	var pause_save: Dictionary = Timing.checkpoint(paused.state,paused.phase,15).checkpoint
	var pause_load: Dictionary = Timing.restore(JSON.parse_string(JSON.stringify(pause_save))).checkpoint
	assert(pause_load.clock == state.clock and pause_load.phase == paused.phase)
	assert(Clock.advance_reference_time(pause_save.clock,16667,pause_save.phase) == Clock.advance_reference_time(pause_load.clock,16667,pause_load.phase))
	# Compare a run interrupted by repeated serialization with an uninterrupted one.
	var reference := state.duplicate(true)
	var interrupted := state.duplicate(true)
	for i in range(240):
		var running := i % 17 != 0
		var a := Clock.advance_reference_time(reference.clock,16666+i%3,reference.phase,running)
		var b := Clock.advance_reference_time(interrupted.clock,16666+i%3,interrupted.phase,running)
		assert(a == b)
		reference = Timing.checkpoint(a.state,a.phase,reference.executioner_a3).checkpoint
		interrupted = Timing.restore(JSON.parse_string(JSON.stringify(Timing.checkpoint(b.state,b.phase,interrupted.executioner_a3).checkpoint))).checkpoint
		assert(reference == interrupted)
	for field in ["version","clock","phase","executioner_a3"]:
		var missing := state.duplicate(true);missing.erase(field)
		assert(Timing.restore(missing).has("error"))
	for invalid in [null,true,"15",-1,256,0.5,INF,NAN]:
		assert(Timing.checkpoint(clock,0,invalid).has("error"))
	for invalid in [-1,2485000000,0.5,null,true]:
		assert(Timing.checkpoint(clock,invalid,15).has("error"))
	var bad := state.duplicate(true);bad.clock.samples[0] = 481
	assert(Timing.restore(bad).has("error"))
	bad = state.duplicate(true);bad.clock.erase("fraction16")
	assert(Timing.restore(bad).has("error"))
	restored.checkpoint.clock.samples[0] = 480
	assert(state.clock == original and clock == original)
	print("PASS: Hive A3/clock checkpoints, exact boundary continuation, pause,240 serialized steps and invalid input rejection")
	quit(0)
