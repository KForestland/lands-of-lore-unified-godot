extends SceneTree
const PathControl = preload("res://scripts/lol2/hive_path_control.gd")
func _initialize() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_path_control_native.json"))
	assert(fixtures.size() == 7408)
	for row in fixtures:
		var route := {"first":19,"count":row.count,"flags":row.flags}
		assert(PathControl.select_marker(route,row.index).marker == 19+absi(int(row.index)))
		var result := PathControl.advance_index(route,row.index,row.b8)
		assert(result.index == row.next_index and result.b8 == row.next_b8 and result.event22_requested == row.event22_requested)
	# Original executioner path0 reverses from its last point, then returns through9.
	var route := {"first":0,"count":11,"flags":0}
	var result := PathControl.advance_index(route,10,0x30)
	assert(result.index == -9 and result.event22_requested and result.b8 == 0)
	assert(PathControl.select_marker(route,result.index).marker == 9)
	for bad in [null,true,"0",0.5,NAN,INF,-128,-11,11]:
		assert(PathControl.advance_index(route,bad,0).has("error"))
	for count in [0,1,128,256]:
		assert(PathControl.select_marker({"first":0,"count":count,"flags":0},0).has("error"))
	print("PASS:7408 native path index steps,source executioner reversal and invalid domains")
	quit(0)
