extends SceneTree
const Impulse=preload("res://scripts/lol2/hive_boulder_impulse.gd")
func _initialize() -> void:
	var rows: Array=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_boulder_vector_native.json"))
	assert(rows.size()==4096)
	for row in rows:
		var result:=Impulse.combine(row)
		assert(not result.has("error"),str(row))
		for key in result: assert(result[key]==int(row[key]),str(key,": ",result," vs ",row))
	var context: Dictionary=rows[0].duplicate(true)
	for key in ["angle","previous_angle","impulse","previous_impulse","rounding_mode"]:
		var bad:=context.duplicate(true);bad.erase(key)
		assert(Impulse.combine(bad).has("error"))
		for invalid in [true,-1,0.5,NAN,"1"]:
			bad=context.duplicate(true);bad[key]=invalid
			assert(Impulse.combine(bad).has("error"))
	print("PASS: 4096 native impulse combinations, wrap and explicit rounding modes")
	quit()
