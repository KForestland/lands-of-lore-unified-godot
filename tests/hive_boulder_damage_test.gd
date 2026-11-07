extends SceneTree
const Boulder=preload("res://scripts/lol2/hive_boulder_damage.gd")
const Calculation=preload("res://scripts/lol2/hive_damage_calculation.gd")
func _initialize() -> void:
	var fixtures: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_boulder_damage_native.json"))
	for row in fixtures:
		var result:=Boulder.calculate(row)
		assert(not result.has("error"))
		assert(result.prepared.amount==int(row.amount) and not result.prepared.heading_bonus)
		result.erase("prepared")
		for key in row.expected:
			if key=="virtual84":
				assert(result[key].size()==row.expected[key].size())
				for i in range(result[key].size()): assert(result[key][i]==int(row.expected[key][i]),str(row))
			else: assert(result[key]==row.expected[key],str(key,": ",result," expected ",row))
	# Source0x10 prevents ordinary reductions, but explicit filter0x14 can reduce.
	var context:={"mode":1,"scalar":65535,"current":30,"descriptors":[[[5,256,4]]]}
	assert(Boulder.calculate(context).loss==10)
	context.descriptors=[[[5,256,20]]]
	assert(Boulder.calculate(context).loss==5)
	context.descriptors=[[[2,256,4]]]
	assert(Boulder.calculate(context).loss==20)
	context.descriptors=[[[7,256,20]]]
	assert(Boulder.calculate(context).loss==0)
	# Existing EXEC/sword contracts remain restricted, including malformed input.
	for mask in [2,8]:
		assert(Calculation.calculate({"amount":10,"scalar":0,"current":30,"signature":28,"damage_mask":mask,"descriptors":[]}).has("error"))
	for bad in [-1,256,1.5,NAN,"1"]:
		context.mode=bad
		assert(Boulder.calculate(context).has("error"))
	print("PASS: 4096 native boulder kind4 results, flag16 reduction override, supplied defenses, scalar bypass and malformed modes")
	quit()
