extends SceneTree
const State=preload("res://scripts/lol2/museum_ivory_state.gd")
func _initialize() -> void:
	var state:=State.initial();var ids: Array=[]
	assert(State.validate(state,ids).is_empty())
	assert(not State.hit(state,-1,1) and not State.hit(state,2,1) and not State.hit(state,0,0))
	assert(not State.take(state,0,ids,2))
	assert(State.hit(state,0,1) and not State.hit(state,0,1))
	assert(not State.take(state,0,ids,0) and state.stages==[1,0] and ids.is_empty())
	assert(State.take(state,0,ids,2) and not State.take(state,0,ids,2))
	assert(State.hit(state,1,8) and State.take(state,1,ids,2))
	assert(ids==State.IDS and State.validate(state,ids).is_empty())
	for bad in [null,{}, {"version":true,"stages":[0,0]}, {"version":1,"stages":[true,0]}, {"version":1,"stages":[NAN,0]}, {"version":1,"stages":[INF,0]}, {"version":1,"stages":[0.5,0]}, {"version":1,"stages":[3,0]}, {"version":1,"stages":[0]}, {"version":1,"stages":[0,0],"extra":0}]:
		assert(not State.validate(bad).is_empty())
	assert(not State.validate(state,[]).is_empty())
	assert(not State.validate(State.initial(),ids).is_empty())
	assert(not State.validate(state,ids+[ids[0]]).is_empty())
	assert(State.validate(JSON.parse_string(JSON.stringify(state)),ids).is_empty())
	print("PASS museum_ivory_state: separate identities, hit threshold adapter, duplicate/full-inventory refusal, malformed/nonfinite/forged receipts and JSON roundtrip")
	quit()
