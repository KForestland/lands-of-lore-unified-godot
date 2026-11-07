extends SceneTree
const S=preload("res://scripts/lol2/museum_aloe_state.gd")
func _initialize() -> void:
	var state:=S.initial();var carried: Array=[];var spent: Array=[]
	assert(S.validate(null,carried,spent).is_empty())
	assert(S.take(state,carried,0) and S.take(state,carried,1))
	assert(not S.take(state,carried,0))
	carried.erase(S.IDS[0]);spent.append(S.IDS[0])
	assert(S.validate(state,carried,spent).is_empty())
	var restored:=S.canonical(JSON.parse_string(JSON.stringify(state)))
	assert(S.validate(restored,carried,spent).is_empty() and not S.take(restored,carried,0))
	assert(not S.validate(null,carried,spent).is_empty())
	assert(not S.validate(state,carried+[S.IDS[0]],spent).is_empty())
	assert(not S.validate(state,carried,spent+spent).is_empty())
	assert(not S.validate(state,[],spent).is_empty())
	for bad in [{},{"version":true,"taken":[true,true]},{"version":1,"taken":[1,true]},{"version":1,"taken":[true]}]:
		assert(not S.validate(bad,carried,spent).is_empty())
	print("PASS Museum Aloe unique grants, shared spent conservation, malformed and legacy validation")
	quit()
