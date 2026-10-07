extends SceneTree
const Calculation = preload("res://scripts/lol2/hive_damage_calculation.gd")
const Preparation = preload("res://scripts/lol2/hive_damage_preparation.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")

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
	var fixture = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_damage_calculation_native.json"))
	assert(fixture.size()==2048)
	for row in fixture:
		var before: Dictionary = row.duplicate(true)
		assert(equivalent(Calculation.calculate(row),row.expected),str(row))
		assert(row==before)
	var spells = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_calculation_native.json"))
	assert(spells.size()==5760)
	for row in spells:
		var before: Dictionary = row.duplicate(true)
		assert(equivalent(Calculation.calculate(row),row.expected),str(row))
		assert(row==before)
	for field in ["request_kind","request_tag","caster_factor","player_magic_level"]:
		var bad: Dictionary=spells[0].duplicate(true);bad.erase(field)
		assert(Calculation.calculate(bad).has("error"))
	for value in [true,0,-1,0.5,31]:
		var bad: Dictionary=spells[0].duplicate(true);bad.player_magic_level=value
		assert(Calculation.calculate(bad).has("error"))
	for pair in [["request_kind",1],["request_tag",20],["caster_factor",9],["amount",11],["scalar",129]]:
		var bad: Dictionary=spells[0].duplicate(true);bad[pair[0]]=pair[1]
		assert(Calculation.calculate(bad).has("error"))
	var spell_preparations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_preparation_native.json"))
	assert(spell_preparations.size()==294)
	assert(Preparation.resolve_attack({"type":"damage","mask":8,"flags":4,"amount":10},{}).has("error"))
	for row in spell_preparations:
		assert(equivalent(Preparation.prepare(row),row.expected))
		var supplied: Dictionary=row.duplicate(true)
		supplied.scalar=64;supplied.current=30;supplied.descriptors=[];supplied.player_magic_level=5
		var before: Dictionary=supplied.duplicate(true)
		var result := Preparation.resolve_dawn_spell(supplied)
		assert(not result.has("error") and equivalent(result.prepared,row.expected))
		assert(supplied==before)
		var matched := false
		for native in spells:
			if native.amount==row.expected.amount and native.signature==row.expected.signature and native.scalar==64 and native.current==30 and native.player_magic_level==5 and native.descriptors.is_empty():
				var calculated := result.duplicate(true);calculated.erase("prepared")
				assert(equivalent(calculated,native.expected));matched=true;break
		assert(matched)
	var preparation = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_damage_preparation_native.json"))
	assert(preparation.size()==4096)
	for row in preparation: assert(equivalent(Preparation.prepare(row),row.expected),str(row))
	var baseline: Dictionary = fixture[0].duplicate(true)
	for field in ["amount","scalar","signature","current","descriptors"]:
		var bad := baseline.duplicate(true);bad.erase(field)
		assert(Calculation.calculate(bad).has("error"))
	for value in [true,-1,0,279,0.5]:
		var bad := baseline.duplicate(true);bad.amount=value
		assert(Calculation.calculate(bad).has("error"))
	var overflow := baseline.duplicate(true);overflow.amount=278;overflow.scalar=0
	overflow.descriptors=[[[4,0,0],[4,0,0],[4,0,0],[4,0,0]]]
	assert(Calculation.calculate(overflow).has("error"))
	for i in range(64):
		var attack := Attack.new();var state := attack.checkpoint()
		state.base=15;state.gate=true;state.flags=1
		assert(attack.restore(state).is_empty())
		var target := {"attacker_heading":32768,"player_heading":32768,"guard":i%2,"mode":i%3,"scalar":i,"current":1000,"descriptors":[]}
		var replies: Array = []
		var feedback := func(event):
			var result := Preparation.resolve_attack(event,target)
			assert(not result.has("error") and result.virtual84.is_empty() and result.remaining>0)
			replies.append(result)
			return result
		var result := attack.advance_native(6145,feedback)
		assert(not result.has("error") and replies.size()==1)
		assert(attack.checkpoint().result_count==1 and attack.checkpoint().result_total==replies[0].percentage)
		assert(target.current==1000) # Calculation emits data; health application is separate.
	print("PASS:2048 native damage calculations,5760 Dawn spell32 calculations,294 spell preparations/compositions,4096 melee preparations and64 synchronous attack-feedback compositions")
	quit()
