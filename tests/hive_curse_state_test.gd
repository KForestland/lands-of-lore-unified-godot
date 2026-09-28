extends SceneTree
const State = preload("res://scripts/lol2/hive_curse_state.gd")
func _initialize() -> void:
	var state := State.initial()
	assert(State.validate(state).is_empty())
	assert(State.validate(JSON.parse_string(JSON.stringify(state))).is_empty())
	State.enter(state,392)
	assert(state.running and state.enabled and state.remaining >= 120 and state.remaining <= 255)
	var before := state.duplicate(true)
	State.enter(state,392)
	assert(state == before,"Staying in a region must not reset its timer")
	State.enter(state,391)
	assert(not state.running and state.remaining == before.remaining)
	State.enter(state,389)
	assert(state.running and state.remaining == before.remaining)
	assert(State.enter(state,393,0,2))
	assert(not state.running and not state.enabled)
	State.enter(state,-1)
	State.enter(state,392)
	assert(state.running and state.enabled and state.seed != before.seed)
	# Source predicate73 is the existing translation flag, not a new latch.
	var fixtures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-curse-gates.json"))
	for row in fixtures.cases:
		var gate := State.initial()
		assert(not State.enter(gate,812,int(row.shared14)))
		assert(gate.enabled == row.accepted)
		assert(gate.seed != 324508639 if row.accepted else gate.seed == 324508639)
		gate.running = true
		gate.enabled = true
		assert(not State.enter(gate,818,int(row.shared14)),"Already-human entry must not consume command04")
		assert(gate.running == not row.accepted and gate.enabled == not row.accepted)
		assert(State.validate(JSON.parse_string(JSON.stringify(gate))).is_empty())
	for region in [391,818,1259,1260]:
		var gate := State.initial()
		gate.enabled = true
		assert(not State.enter(gate,region,0,0))
		assert(gate.human_return_used.is_empty())
		State.enter(gate,-1)
		gate.enabled = true
		assert(State.enter(gate,region,0,2))
		assert(gate.human_return_used == [region])
		State.enter(gate,-1)
		gate.enabled = true
		assert(not State.enter(gate,region,0,1),"Command04 is one-shot per source record")
		assert(State.validate(JSON.parse_string(JSON.stringify(gate))).is_empty())
	var repeated := State.initial()
	assert(not State.enter(repeated,393,0,2),"Disabled admission must not force human")
	State.enter(repeated,-1)
	repeated.enabled = true
	assert(State.enter(repeated,393,0,2) and repeated.human_return_used.is_empty())
	State.enter(repeated,-1)
	repeated.enabled = true
	assert(State.enter(repeated,393,0,2),"Command3c remains repeatable")
	var gated := State.initial()
	gated.enabled = true
	assert(not State.enter(gated,818,1,2) and gated.human_return_used.is_empty())
	assert(gated.enabled and gated.running)
	for bad in [null,true,[391,391],[392],[818.5],[NAN],["391"]]:
		var invalid := State.initial()
		invalid.human_return_used = bad
		assert(not State.validate(invalid).is_empty())
	for key in ["remaining","region","seed"]:
		for bad in [NAN,INF,"0",true,null]:
			var invalid := state.duplicate(true)
			invalid[key] = bad
			assert(not State.validate(invalid).is_empty())
	for bad in [-2,390,392.5]:
		var invalid := state.duplicate(true)
		invalid.region = bad
		assert(not State.validate(invalid).is_empty())
	print("PASS: Hive curse gate start/stop/reset, admission, JSON roundtrip and invalid-state rejection")
	quit()
