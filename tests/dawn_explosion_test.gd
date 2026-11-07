extends SceneTree
const Preparation = preload("res://scripts/lol2/hive_damage_preparation.gd")
const Explosion = preload("res://scripts/lol2/dawn_explosion.gd")
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
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_explosion_first_pass_native.json"))
	assert(rows.size()==160)
	for row in rows:
		var target := {"id":1,"kind":row.target_kind,"flags":row.target_flags,"direct":row.direct_target,"distance":row.distance}
		var expected: Array = row.requests.duplicate(true)
		for request in expected: request.target=1
		var result := Explosion.first_pass(row.already_applied,[target])
		assert(equivalent(result,{"applied":true,"requests":expected}),str(row,result))
		var restored = JSON.parse_string(JSON.stringify(result))
		assert(Explosion.first_pass(restored.applied,[target]).requests.is_empty())
	var valid := {"id":1,"kind":1,"flags":0x4000,"direct":false,"distance":0}
	assert(Explosion.first_pass(false,[valid,{}]).has("error"))
	assert(Explosion.first_pass(false,[]).applied)
	assert(Explosion.first_pass(1,[valid]).has("error"))
	var calculations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_explosion_calculation_native.json"))
	var expected_calculations := {}
	for calculation in calculations:
		if calculation.scalar==5 and calculation.player_magic_level==5 and calculation.descriptors.is_empty():
			expected_calculations[str(int(calculation.amount))+":"+str(int(calculation.signature))]=calculation.expected
	var preparations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_explosion98_preparation_native.json"))
	assert(preparations.size()==5586)
	for row in preparations:
		assert(equivalent(Preparation.prepare(row),row.expected),str(row))
		var context: Dictionary = row.duplicate(true)
		context.merge({"scalar":5,"player_magic_level":5,"current":1000,"descriptors":[]},true)
		var request := {"mask":16,"signature":5,"kind":2,"effect":98,"amount":row.amount}
		var actual := Preparation.resolve_dawn_explosion(request,context)
		assert(equivalent(actual.prepared,row.expected))
		actual.erase("prepared")
		assert(equivalent(actual,expected_calculations[str(int(row.expected.amount))+":"+str(int(row.expected.signature))]))
	print("PASS:5586 native explosion preparations and damage compositions")
	print("PASS:160 native explosion neighbor/falloff cases; saved marker suppresses repeat pass")
	quit()
