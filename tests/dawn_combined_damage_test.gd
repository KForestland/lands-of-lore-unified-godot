extends SceneTree
const Damage=preload("res://scripts/lol2/hive_damage_calculation.gd")
func _initialize() -> void:
	var cases: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_combined_damage_native.json"))
	assert(cases.size()==4320)
	for row in cases:
		var before: String=JSON.stringify(row.context)
		var result:=Damage.calculate(row.context)
		assert(not result.has("error"),str(row.context)+str(result))
		assert(result.size()==row.expected.size())
		for field in row.expected:
			if field=="virtual84":
				assert(result[field].size()==row.expected[field].size())
				for i in result[field].size():assert(result[field][i]==row.expected[field][i],str(row))
			else:
				assert(result[field]==row.expected[field],str(row.context)+" "+field+" "+str(result)+" expected "+str(row.expected))
		assert(JSON.stringify(row.context)==before)
	var valid: Dictionary=cases[0].context
	for field in ["environmental","request_tag","request_kind","caster_factor","player_magic_level"]:
		var bad:=valid.duplicate(true);bad.erase(field)
		assert(Damage.calculate(bad).has("error"))
	for pair in [["environmental",1],["request_tag",32],["request_tag",58.5],["signature",5],["scalar",129]]:
		var bad:=valid.duplicate(true);bad[pair[0]]=pair[1]
		assert(Damage.calculate(bad).has("error"))
	print("PASS: 4320 original chain/Plasma mask17 calculations, separate mask mitigation/cancellation, environmental bit1 doubling, ordered callbacks and explicit input validation.")
	quit()
