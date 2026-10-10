extends SceneTree
const Target=preload("res://scripts/lol2/dawn_cast_target.gd")
func _initialize() -> void:
	var data=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_cast_target_native.json"))
	assert(data.rows.size()==192)
	for row in data.rows:
		var result:=Target.prepare(row.context,37)
		assert(not result.has("error"),str(result))
		for field in ["b4","flags","direct_target","saved_heading","heading"]: assert(result[field]==row.expected[field],str(field,row,result))
		for i in range(3):assert(result.position[i]==row.expected.position[i],str(row,result))
		var alternate: String="remembered" if int(row.expected.other_target)==0x400040 else "object" if int(row.expected.other_target)==int(row.context.target) else "none"
		assert(result.alternate_binding==alternate)
		assert(result.rng_requested==row.calls.any(func(c):return c.site=="0xa82d6"))
		assert(Target.prepare_with_heading(row.context).heading==Target.Heading.between(row.context.actor.slice(0,2),result.position.slice(0,2)).word)
	var targetless=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_targetless_native.json"))
	assert(targetless.rows.size()==624)
	for row in targetless.rows:
		var result:=Target.without_target(row.context)
		assert(not result.has("error"),str(result))
		for i in range(3):assert(result.position[i]==row.expected[i],str(row,result))
		assert(result.heading==row.context.heading and result.direct_target==0 and result.alternate_binding=="local" and not result.rng_requested)
	assert(Target.without_target({}).has("error"))
	print("PASS:624 native targetless and192 native non-null cast-target preparations; remembered XY/current height, radius boundary, target routing and RNG bit")
	quit()
