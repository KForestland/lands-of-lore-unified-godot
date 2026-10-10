extends SceneTree
const Calculation=preload("res://scripts/lol2/hive_damage_calculation.gd")
const Preparation=preload("res://scripts/lol2/hive_damage_preparation.gd")

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
	var counts: Array=[]
	for spec in [["hive_damage_calculation_native",2048,false],["dawn_spell32_calculation_native",5760,false],["hive_damage_preparation_native",4096,true],["dawn_spell32_preparation_native",294,true]]:
		var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/%s.json"%spec[0]))
		assert(rows.size()==spec[1])
		for row in rows:
			var before: Dictionary=row.duplicate(true)
			var result: Dictionary=Preparation.prepare(row) if spec[2] else Calculation.calculate(row)
			assert(equivalent(result,row.expected),str(row))
			assert(row==before)
		counts.append(rows.size())
	var request={"amount":10,"scalar":0,"signature":4,"damage_mask":256,"request_kind":2,"request_tag":32,"caster_factor":10,"player_magic_level":1,"current":30,"descriptors":[]}
	for field in ["request_kind","request_tag","caster_factor","player_magic_level"]:
		var bad:=request.duplicate(true);bad.erase(field)
		assert(Calculation.calculate(bad).has("error"))
	for value in [true,0,-1,0.5,31]:
		var bad:=request.duplicate(true);bad.player_magic_level=value
		assert(Calculation.calculate(bad).has("error"))
	print("PASS portable damage fixtures ",counts," and invalid spell request rejection")
	quit()
