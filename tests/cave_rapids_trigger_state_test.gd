extends SceneTree
const Trigger=preload("res://scripts/lol2/cave_rapids_trigger_state.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_hit_native.json"))
	assert(source.passed and source.cases.size()==96)
	for row in source.cases:
		for local7 in [0,1]:
			var state:=Trigger.initial()
			var result:=Trigger.hit(state,int(row.mask0),int(row.mask2),int(row.amount),local7)
			assert(result.accepted==row.admitted and result.released==(row.admitted and local7==0))
			assert(Trigger.validate(state).is_empty())
			var saved: Dictionary=JSON.parse_string(JSON.stringify(state))
			assert(Trigger.validate(saved).is_empty() and Trigger.canonical(saved)==state)
			if row.admitted:
				var before:=JSON.stringify(state)
				assert(not Trigger.hit(state,1,1,255,0).accepted and JSON.stringify(state)==before)
				assert(state.control_flags==(0x0431 if local7==0 else 0x04b1))
	var bad:=Trigger.initial();bad.control_flags=0x431;assert(not Trigger.validate(bad).is_empty())
	var state:=Trigger.initial();var before:=JSON.stringify(state)
	assert(not Trigger.hit(state,-1,0,1,0).accepted and JSON.stringify(state)==before)
	print("PASS 96 native hit fixtures x2 local7 contexts: wildcard masks, positive threshold, consumed one-shot on predicate refusal, source property flags, selector callback latch and JSON. World/audio effects remain caller-owned.")
	quit()
