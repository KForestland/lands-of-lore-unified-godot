extends SceneTree
const State=preload("res://scripts/lol2/hive_return_population_state.gd")
func _initialize() -> void:
	var s:=State.initial()
	assert(State.validate(s).is_empty())
	assert(State.arrive(s,{}).is_empty())
	assert(State.arrive(s,{"shared_flag_38":1})==[27,29,28])
	s.actors["27"].health=0
	assert(State.arrive(s,{"shared_flag_38":1}).is_empty() and s.actors["27"].health==0)
	assert(State.arrive(s,{"monastery":{"globals":{"GV_MET_BACATTA":1}}})==[25,26,24,23])
	assert(State.canonical(JSON.parse_string(JSON.stringify(s)))==s)
	for pair in [["health",401],["health",-1],["health",1.5],["windup",1.2],["cooldown",INF],["seed",-1],["position",[0,NAN,0]],["active",1]]:
		var bad:=s.duplicate(true)
		bad.actors["23"][pair[0]]=pair[1]
		assert(not State.validate(bad).is_empty())
	var bad:=s.duplicate(true)
	bad.actors.erase("29")
	assert(not State.validate(bad).is_empty())
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://docs/hive-return-population.json"))
	for row in native.source_bindings:
		assert(State.initial().actors[str(int(row.actor))].position==row.position)
		assert(row.maximum==State.MAX_HEALTH and row.reward_scale==8)
	for row in native.representative_cases:
		if row.event!=9: continue
		var supplied: Dictionary={"shared_flag_38":row.rescued,"monastery":{"globals":{"GV_MET_BACATTA":row.bacatta}}}
		var expected: Array=[]
		for g in row.groups:
			if State.GROUPS.has(int(g)): expected.append_array(State.GROUPS[int(g)])
		assert(State.arrive(State.initial(),supplied)==expected)
	print("PASS return warriors: native admission fixtures, source positions/health, saved activation/defeat and malformed rejection")
	quit()
