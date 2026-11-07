extends SceneTree
const Mitigation = preload("res://scripts/lol2/player_mitigation.gd")
const Calculation = preload("res://scripts/lol2/hive_damage_calculation.gd")

func equivalent(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not equivalent(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in range(a.size()):
			if not equivalent(a[i],b[i]): return false
		return true
	return a==b

func _initialize() -> void:
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/player_mitigation_native.json"))
	assert(rows.size()==2048)
	for row in rows:
		var before: Dictionary=row.context.duplicate(true)
		var built := Mitigation.build(row.context)
		assert(equivalent(built,row.expected),str(row.context,built,row.expected))
		assert(row.context==before)
		var request: Dictionary=built.duplicate(true)
		request.merge({"amount":10,"signature":4,"current":1000,"damage_mask":256,"request_kind":2,"request_tag":32,"caster_factor":10,"player_magic_level":5})
		assert(equivalent(Calculation.calculate(request),row.spell_result),str(row.context))
	for field in ["form","ui_mode","boosted","optional","bypass","slots","defense_parts"]:
		var bad: Dictionary=rows[0].context.duplicate(true);bad.erase(field)
		assert(Mitigation.build(bad).has("error"))
	var bad: Dictionary=rows[0].context.duplicate(true)
	bad.slots=[[[true,0,0]],null,null,null,null,null]
	assert(Mitigation.build(bad).has("error"))
	bad.slots=[[],null,null,null,null,null]
	var built:=Mitigation.build(bad)
	built.descriptors[0].append([5,0,4])
	assert(bad.slots[0].is_empty())
	print("PASS:2048 native player mitigation lists and spell damage compositions; malformed inputs and ownership")
	quit()
