extends SceneTree
const Motion=preload("res://scripts/lol2/dawn_spell_motion.gd")
func _initialize() -> void:
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_motion_native.json"))
	assert(rows.size()==180)
	for row in rows:
		var before: Dictionary=row.duplicate(true)
		var actual:=Motion.request(row)
		assert(not actual.has("error"))
		for field in row.expected: assert(actual[field]==row.expected[field],str(row))
		assert(row==before)
	for field in ["heading","delta","planar_distance","height_delta"]:
		var bad: Dictionary=rows[0].duplicate(true);bad.erase(field)
		assert(Motion.request(bad).has("error"))
	for field in ["heading","delta","planar_distance"]:
		for value in [true,-1,0.5,2147483648]:
			var bad: Dictionary=rows[0].duplicate(true);bad[field]=value
			assert(Motion.request(bad).has("error"))
	print("PASS180 native spell32 movement requests; malformed input rejection")
	quit()
