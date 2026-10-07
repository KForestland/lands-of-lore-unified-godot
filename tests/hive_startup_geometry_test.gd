extends SceneTree
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_startup_geometry_native.json"))
	var differences := 0
	for row in rows:
		var result := Geometry.distance_startup(row.actor_fixed,row.point,row.fixed_units)
		assert(not result.has("error") and result.distance == row.distance)
		assert(result.integer_invalid == row.integer_invalid)
		if row.distance != row.extended_distance: differences += 1
	assert(differences == 128)
	var context := {"distance9":-1,"radius9":255,"distance41":-1,"radius41":255}
	var original := context.duplicate(true)
	var point := {"coordinates":[0,0],"radius":1}
	var bound := Geometry.bind_startup_regions(context,[32*65536,0],point,point,0x127f)
	assert(not bound.has("error"))
	assert(bound.context.distance9 == 2097152 and bound.context.distance41 == 32)
	assert(bound.context.radius9 == 1 and bound.context.radius41 == 1 and bound.context.geometry41_enabled)
	assert(context == original)
	bound = Geometry.bind_startup_regions(context,[0,0],point,null,0x127f)
	assert(not bound.has("error") and not bound.context.geometry41_enabled)
	for invalid in [null,true,0x37f,0x167f,0x127f+0.5]:
		assert(Geometry.bind_startup_regions(context,[0,0],point,null,invalid).has("error"))
	assert(Geometry.bind_startup_regions(context,[0,0],null,null,0x127f).has("error"))
	assert(Geometry.bind_startup_regions(context,[0,0],point,{},0x127f).has("error"))
	print("PASS:1536 native startup-precision distances,128 precision differences, explicit control-word binding")
	quit(0)
