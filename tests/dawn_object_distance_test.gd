extends SceneTree
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
func _initialize() -> void:
	var rows=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/dawn_object_distance_native.json"))
	assert(rows.size()==1284)
	for row in rows:
		var result:=Geometry.distance_between_startup(row.first,row.second)
		assert(not result.has("error") and result.distance==row.expected.distance and result.integer_invalid==row.expected.integer_invalid,str(row,result))
	var prior=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_startup_geometry_native.json"))
	for row in prior:
		var result:=Geometry.distance_startup(row.actor_fixed,row.point,row.fixed_units)
		assert(not result.has("error") and result.distance==row.distance and result.integer_invalid==row.integer_invalid,str(row,result))
	for bad in [null,[],[1],[true,0],[2147483648,0],[0,0.5]]:
		assert(Geometry.distance_between_startup(bad,[0,0]).has("error"))
		assert(Geometry.distance_between_startup([0,0],bad).has("error"))
	print("PASS:1284 native object distances; ",prior.size()," existing startup distances unchanged; invalid inputs rejected")
	quit()
