extends SceneTree
const Admission = preload("res://scripts/lol2/hive_action_admission.gd")
func _initialize() -> void:
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_action_admission_native.json"))
	assert(fixtures is Array and fixtures.size() == 2048)
	for fixture in fixtures:
		var operations: Array = []
		var before: Dictionary = fixture.state.duplicate(true)
		var hooks := {
			"vertical":func(_state,margin):
				assert(margin == 0x400000)
				operations.append(["vertical"])
				return fixture.context.vertical_result,
			"random":func(_state,maximum):
				operations.append(["random",maximum])
				return int(fixture.context.random_value)%(maximum+1),
			"lookup":func(_state,action,variant):
				assert(variant == -1)
				operations.append(["lookup",action])
				return fixture.context.selector,
			"start":func(_state,selector,flags):
				assert(flags == 0)
				operations.append(["start",selector]),
			"behavior":func(_state): operations.append(["behavior"])}
		var result := Admission.run(fixture.state,fixture.context,hooks)
		assert(not result.has("error") and fixture.state == before)
		if JSON.parse_string(JSON.stringify(result.state)) != fixture.after or JSON.parse_string(JSON.stringify(operations)) != fixture.operations:
			printerr("Admission mismatch: ",fixture," actual=",result," ops=",operations)
			quit(1);return
	# Helpers see target binding and B9 clearing; native trailing writes preserve
	# callback effects except for the explicitly cleared B4 low bits.
	var state := {"b4":0,"b5":0,"b7":0,"b9":255,"ad":0,"target":0}
	var hooks := {"vertical":func(_s,_m):return 4,"random":func(_s,_m):return 0,
		"lookup":func(_s,_a,_v):return -1,"start":func(_s,_i,_f):pass,
		"behavior":func(s):
			assert(s.target == 0x22574 and s.b9 == 239)
			s.b4 = 255;s.target = 123}
	var result := Admission.run(state,{"action":0,"terminal":true},hooks)
	assert(result.state.b4 == 252 and result.state.target == 123 and state.target == 0)
	assert(Admission.run(state,{"action":0,"terminal":true},{}).has("error"))
	print("PASS: 2048 native action admission cases and synchronous callback mutation ordering")
	quit(0)
