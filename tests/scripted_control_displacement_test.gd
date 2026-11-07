extends SceneTree
const Displacement=preload("res://scripts/lol2/scripted_control_displacement.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_displacement_native.json"))
	assert(source.passed and source.cases.size()==252)
	for row in source.cases:
		var result:=Displacement.step(int(row.heading),int(row.length))
		assert(result.dx==row.dx and result.dy==row.dy)
		assert(int(row.x)+result.dx==row.next_x and int(row.y)+result.dy==row.next_y)
		var saved: Dictionary=JSON.parse_string(JSON.stringify(result))
		assert(saved.dx==row.dx and saved.dy==row.dy)
	assert(Displacement.step(-1,0).is_empty())
	assert(Displacement.step(65536,0).is_empty())
	assert(Displacement.step(0,-1).is_empty())
	print("PASS 252 original proposed XY displacements: quantized sine, signed fixed multiplication, source headings and quadrant edges. Collision/commit remain caller-owned.")
	quit()
