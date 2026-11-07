extends SceneTree
const Controls=preload("res://scripts/lol2/cave_rapids_control_state.gd")
func finished(state: Dictionary) -> bool:
	for item in state.controls.values():
		if not item.complete:return false
	return true
func _initialize() -> void:
	var fixtures: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/control_speed_refresh_native.json"))
	for row in fixtures.cases:assert(Controls.speed_refresh(int(row.distance),int(row.tick_fixed))==int(row.speed))
	var endpoints: Dictionary={}
	for mode in 4:
		var state:=Controls.initial(mode)
		assert(Controls.validate(state).is_empty())
		var before:=JSON.stringify(state)
		assert(Controls.advance_accepted(state,65536,1).is_empty() and before==JSON.stringify(state))
		assert(Controls.start(state) and not Controls.start(state))
		var snapshots: Array=[]
		var completions: Array=[]
		var frame:=0
		while not finished(state) and frame<6000:
			if frame in [0,1,30,60,150,300,600]:snapshots.append({"frame":frame,"state":JSON.parse_string(JSON.stringify(state))})
			completions.append_array(Controls.advance_accepted(state,65536,1));frame+=1
		assert(finished(state),str(state))
		assert(completions.size()==5 and Controls.validate(state).is_empty())
		var final_text:=JSON.stringify(Controls.canonical(state))
		assert(Controls.advance_accepted(state,65536,1).is_empty() and JSON.stringify(Controls.canonical(state))==final_text)
		for snapshot in snapshots:
			assert(Controls.validate(snapshot.state).is_empty())
			var resumed:=Controls.canonical(snapshot.state)
			for index in range(int(snapshot.frame),frame):Controls.advance_accepted(resumed,65536,1)
			assert(JSON.stringify(resumed)==final_text)
		endpoints[str(mode)]={"frames":frame,"restores":snapshots.size()}
	var bad:=Controls.initial(0);bad.controls["103"].position[0]+=1;assert(not Controls.validate(bad).is_empty())
	bad=Controls.initial(0);bad.started=true;bad.controls["103"].complete=true;assert(not Controls.validate(bad).is_empty())
	bad=Controls.initial(0);bad.controls.erase("99");assert(not Controls.validate(bad).is_empty())
	print("PASS five rapids controls reach exact original endpoints with one-shot completion and JSON continuation across all four explicit FPU modes: ",endpoints,". All movement admission supplied; not an actual-world collision or trigger test.")
	quit()
