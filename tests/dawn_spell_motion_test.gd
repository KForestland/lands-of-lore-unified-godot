extends SceneTree
const Motion=preload("res://scripts/lol2/dawn_spell_motion.gd")
func _initialize() -> void:
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_motion_native.json"))
	assert(rows.size()==1029)
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
	for field in Motion.MOTION_LIMITS:
		var bad: Dictionary=rows[0].duplicate(true);bad[field]=Motion.MOTION_LIMITS[field]+1
		assert(Motion.request(bad).has("error"))
	var targets=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_spell32_target_native.json"))
	assert(targets.size()==90)
	for row in targets:
		var before: Dictionary=row.duplicate(true)
		var result:=Motion.target_snapshot(row)
		assert(not result.has("error"))
		for i in range(3): assert(result.position[i]==row.expected[i])
		if int(row.sprite_height)==Motion.SPRITE_HEIGHT:
			var source_target:=Motion.player_target(row.position,int(row.player_height),int(row.player_offset))
			for i in range(3): assert(source_target.position[i]==row.expected[i])
		result.position[0]+=1
		assert(row==before)
	for field in ["position","player_height","player_offset","sprite_height"]:
		var bad: Dictionary=targets[0].duplicate(true);bad.erase(field)
		assert(Motion.target_snapshot(bad).has("error"))
	print("PASS1029 native spell32 movement requests and90 target snapshots; original sprite height; arithmetic boundary rejection")
	quit()
