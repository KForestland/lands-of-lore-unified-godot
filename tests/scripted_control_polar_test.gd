extends SceneTree
const Polar=preload("res://scripts/lol2/scripted_control_polar.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_polar_native.json"))
	assert(source.passed and source.cases.size()==68)
	for row in source.cases:
		var result:=Polar.from_delta(int(row.dx),int(row.dy),int(row.rounding_mode))
		assert(result.heading==row.heading and result.distance==row.distance)
	assert(Polar.from_delta(0,0,-1).is_empty())
	assert(Polar.from_delta(0,0,4).is_empty())
	print("PASS 68 native x87 polar cases, explicit four rounding modes, source paths and quadrant edges; live game control word remains unestablished.")
	quit()
