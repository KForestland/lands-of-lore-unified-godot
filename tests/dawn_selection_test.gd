extends SceneTree
const Selection=preload("res://scripts/lol2/dawn_spell_selection.gd")
func equivalent(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size():return false
		for k in a:
			if not b.has(k) or not equivalent(a[k],b[k]):return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size():return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]):return false
		return true
	return a==b
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_selection_native.json"))
	var profile=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_selection_scores.json"))
	assert(data.rows.size()==588)
	for row in data.rows:
		var context={"w88":800,"mana":row.resource,"check_cost":1,"target":0x22574,"seen":1,"b7":0,"b8":row.flags,"distance":0,"exclusive":row.exclusive,"active":[],"write_reason":1,"previous_reason":0}
		var before: Dictionary=context.duplicate(true)
		var result:=Selection.scan(context,profile.scores,profile.max_score,50,row.previous,row.rng)
		assert(not result.has("error"),str(result))
		assert(result.stored_choice==row.stored_choice and result.b8==row.updated_flags and equivalent(result.attempts,row.attempts) and equivalent(result.candidates,row.candidates),str(row,result))
		assert(result.accepted==row.attempts.any(func(a): return a.admitted))
		assert(context==before)
	var dynamic=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_selection_dynamic_native.json"))
	assert(dynamic.rows.size()==480)
	for row in dynamic.rows:
		var context={"w88":800,"mana":row.resource,"check_cost":1,"target":0x22574,"seen":1,"b7":0,"b8":row.flags,"distance":0,"exclusive":row.exclusive,"active":[],"write_reason":1,"previous_reason":0}
		var result:=Selection.scan(context,row.scores,row.maximum,50,row.previous,row.rng,row.input_candidates)
		assert(not result.has("error"),str(result))
		assert(result.stored_choice==row.stored_choice and result.b8==row.updated_flags and equivalent(result.attempts,row.attempts) and equivalent(result.candidates,row.candidates),str(row,result))
		assert(result.accepted==row.attempts.any(func(a): return a.admitted))
		assert(Selection.scan(context,row.scores,row.maximum,50,row.previous,row.input_candidates.size()*32,row.input_candidates).has("error"))
	print("PASS:588 six-candidate and480 dynamic native scans; changing candidate count and RNG range")
	quit()
