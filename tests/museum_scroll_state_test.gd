extends SceneTree
const S = preload("res://scripts/lol2/museum_scroll_state.gd")
func _initialize() -> void:
	var s := S.initial()
	var carried: Array = []
	assert(S.validate(null,carried).is_empty())
	assert(S.take(s,carried,0) and S.take(s,carried,1))
	assert(carried.size()==2 and carried[0]!=carried[1])
	assert(not S.take(s,carried,0))
	assert(S.record_consumption(s,carried,0))
	assert(not S.take(s,carried,0) and not S.record_consumption(s,carried,0))
	var loaded = JSON.parse_string(JSON.stringify(s))
	assert(S.validate(loaded,carried).is_empty())
	var restored := S.canonical(loaded)
	assert(restored.taken[0] and restored.consumed[0] and not S.take(restored,carried,0))
	var before := JSON.stringify(restored)
	for malformed in [{}, {"version":true,"taken":s.taken,"consumed":s.consumed}, {"version":1,"taken":[true],"consumed":s.consumed}]:
		assert(not S.validate(malformed,carried).is_empty())
	assert(JSON.stringify(restored)==before)
	var duplicate := carried.duplicate(); duplicate.append(carried[0])
	assert(not S.validate(restored,duplicate).is_empty())
	var impossible := S.initial(); impossible.consumed[2]=true
	assert(not S.validate(impossible,[]).is_empty())
	print("PASS Museum scroll duplicate identities, consumption persistence, legacy and malformed receipts")
	quit()
