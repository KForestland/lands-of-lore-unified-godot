extends SceneTree
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
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_explosion_calculation_native.json"))
	assert(rows.size()==2880)
	for row in rows:
		var result := Calculation.calculate(row)
		assert(equivalent(result,row.expected),str(row,result))
	var bad: Dictionary = rows[0].duplicate(true)
	for change in [{"amount":41},{"request_tag":32},{"signature":4},{"caster_factor":9},{"player_magic_level":0}]:
		var request := bad.duplicate(true)
		request.merge(change,true)
		assert(Calculation.calculate(request).has("error"))
	print("PASS:2880 native explosion98 calculations including split mitigation and signed multiplication overflow")
	quit()
