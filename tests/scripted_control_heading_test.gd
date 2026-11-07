extends SceneTree
const Heading=preload("res://scripts/lol2/scripted_control_heading.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_heading_native.json"))
	assert(source.passed and source.cases.size()==900)
	for row in source.cases:
		var result:=Heading.step(int(row.current),int(row.path_heading),int(row.desired),int(row.flags),row.far,int(row.quota))
		assert(result.heading==row.next_heading and result.flags==row.next_flags and result.completion_allowed==row.completion_allowed)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(result))
		assert(saved.heading==row.next_heading and saved.flags==row.next_flags)
	assert(Heading.step(65536,0,0,0x101,false,0).is_empty())
	assert(Heading.step(0,0,0,0x301,false,1).is_empty())
	assert(Heading.step(0,0,0,0x101,false,-1).is_empty())
	print("PASS 900 original opcode18 heading vectors: fixed/smoothed headings, wrap branches, aligned latch, zero-quota snap, completion gate and JSON; path/vertical/collision remain caller-owned.")
	quit()
