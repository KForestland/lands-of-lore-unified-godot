extends SceneTree
const Horizontal=preload("res://scripts/lol2/scripted_control_horizontal.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_horizontal_native.json"))
	assert(source.passed and source.cases.size()==1296)
	for row in source.cases:
		var result:=Horizontal.step(int(row.distance),int(row.delta),int(row.quota),int(row.elapsed),row.extra_matches)
		assert(result.horizontal==row.horizontal and result.far==row.far and result.completion_candidate==row.completion_candidate and result.elapsed==row.next_elapsed)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(result))
		assert(saved.horizontal==row.horizontal and saved.elapsed==row.next_elapsed)
	assert(Horizontal.step(-1,0,0,0,false).is_empty())
	assert(Horizontal.step(0,0,0x10000000,0,false).is_empty())
	assert(Horizontal.step(0,0,0,256,false).is_empty())
	print("PASS 1296 original horizontal movement cases: near/far, half-distance, elapsed slowdown and provisional completion; world application/collision remain caller-owned.")
	quit()
