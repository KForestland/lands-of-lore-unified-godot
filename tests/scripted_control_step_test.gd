extends SceneTree
const Step=preload("res://scripts/lol2/scripted_control_step.gd")
func _initialize() -> void:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_step_native.json"))
	assert(source.passed and source.cases.size()==480)
	for row in source.cases:
		var before:=JSON.stringify(row)
		var result:=Step.step(row)
		assert(not result.is_empty())
		assert(result.flags==row.next_flags and result.elapsed==row.next_elapsed and result.pitch==row.next_pitch, str(row)+"\n"+str(result))
		assert(result.position==row.next_position and result.heading==row.next_heading and result.result==row.result, str(row)+"\n"+str(result))
		for index in 3:assert(int(result.vector[index])==int(row.vector[index]), str(row)+"\n"+str(result))
		assert(JSON.stringify(row)==before)
		assert(Step.step(JSON.parse_string(before))==result)
	var bad: Dictionary=source.cases[0].duplicate(true)
	bad.ticks=-1;assert(Step.step(bad).is_empty())
	bad=source.cases[0].duplicate(true);bad.position=[0,0];assert(Step.step(bad).is_empty())
	print("PASS 480 complete native control steps: source starts/near/endpoints, direct/smoothed headings, full math, command latches and JSON. Collision/world commit remains caller-owned.")
	quit()
