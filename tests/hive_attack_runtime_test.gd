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
func saved(initial: Dictionary) -> Dictionary:
	var result := initial.duplicate(true)
	result.version = Runtime.SAVE_VERSION
	result.result_total = 0
	result.result_count = 0
	return result
func equivalent(a: Variant, b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size() != b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size() != b.size(): return false
		for i in a.size():
			if not equivalent(a[i],b[i]): return false
		return true
	return a == b
func run() -> void:
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_attack_native.json"))
	var core = Runtime.new()
	for i in fixture.vectors.size():
		var vector = fixture.vectors[i]
		check(core.restore(saved(vector.initial)).is_empty(),"fixture restore %d" % i)
		var actual = core.advance_native(vector.delta)
		check(equivalent(actual,vector.expected),"native tick mismatch %d: %s != %s" % [i,actual,vector.expected])
	for sequence in fixture.sequences:
		check(core.restore(saved(sequence.initial)).is_empty(),"sequence setup")
		for step in sequence.steps:
			# Save through JSON on every frame, including after either damage event.
			var restored = Runtime.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(core.checkpoint()))).is_empty(),"JSON resume")
			var actual = core.advance_native(step.delta)
			check(equivalent(actual,step.expected),"native sequence mismatch")
			check(equivalent(restored.advance_native(step.delta),actual),"resume changed events")
	for mode in range(4):
		for mask in range(256):
			var effective := 1 if mode > 1 else mask
			check(Runtime.action_selector(mask,mode) == (12 if effective & 1 and not effective & 6 else 11),"selector mismatch")
	# Every invalid restore is atomic; unknown/fractional/nonfinite fields are rejected.
	var baseline = core.checkpoint()
	for key in baseline:
		for invalid in [null,"bad",[],{},INF,NAN,-1,0.5,999999]:
			var corrupt = baseline.duplicate(true)
			corrupt[key] = invalid
			check(not core.restore(corrupt).is_empty(),"accepted invalid "+key)
			check(equivalent(core.checkpoint(),baseline),"invalid restore mutated "+key)
		var missing = baseline.duplicate(true)
		missing.erase(key)
		check(not core.restore(missing).is_empty(),"accepted missing "+key)
	for invalid in [-1,32768,INF,NAN,0.5,"1",true,null]:
		check(core.advance_native(invalid).has("error"),"accepted invalid delta")
		check(equivalent(core.checkpoint(),baseline),"invalid delta mutated state")
	for old in [11,12]:
		for next in [11,12]:
			for frame in [0,7,16]:
				for timer in [0,1,1023]:
					var state = baseline.duplicate(true)
					state.selector = old; state.frame = frame; state.timer = timer
					check(core.restore(state).is_empty(),"setter setup")
					check(core.select_attack(next) == (old != next),"setter return")
					var after = core.checkpoint()
					check(after.frame == (0 if old != next else frame) and after.timer == (0 if old != next else timer),"setter reset")
	var copy = core.checkpoint()
	copy.frame = 123
	check(core.checkpoint().frame != 123,"checkpoint aliases live state")
	var before = core.checkpoint()
	check(not core.select_attack(999) and equivalent(before,core.checkpoint()),"invalid selection mutated")
	print("PASS: Hive attack runtime; ",fixture.vectors.size()," native vectors, 4 resumed sequences, ",assertions," assertions")
	quit(0)
