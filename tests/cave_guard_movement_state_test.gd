extends SceneTree
const State=preload("res://scripts/lol2/cave_guard_movement_state.gd")
func _initialize() -> void:
	var src:=State.source();var s:=State.initial(src)
	assert(State.validate(s,src).is_empty())
	for row in src.movables:
		var id:=int(row.motion.index)
		for percent in [0,25,50,75,100]:
			assert(State.command(s,src,id,percent))
			assert(s.objects[str(id)].target==int(int(row.motion.travel)*percent/100)*65536)
		assert(State.validate(s,src).is_empty())
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/cave_guard_movement_native.json"))
	for sample in native.cases:
		s=State.initial(src)
		var id:=64 if sample.speed==40 else 70
		s.objects[str(id)]={"current":int(sample.current),"target":int(sample.target),"status":2 if sample.increasing else 3}
		var events:=State.advance(s,src,int(sample.tick_fixed))
		assert(s.objects[str(id)].current==sample.result)
		assert(events.size()==(2 if sample.callback else 0))
		assert(State.validate(s,src).is_empty())
		var restored=JSON.parse_string(JSON.stringify(s));assert(State.validate(restored,src).is_empty());assert(State.canonical(restored)==s)
		var expected: float=float(sample.result)/65536*(1 if State.record(src,id).mode==0 else -1)
		assert(State.vertical_offset(s,src,id)==expected)
	s=State.initial(src);var before:=s.duplicate(true);assert(not State.command(s,src,999,100));assert(not State.command(s,src,64,101));assert(s==before)
	var bad:=s.duplicate(true);bad.objects["64"].current=999999999;assert(not State.validate(bad,src).is_empty())
	print("PASS movement state: native60 clock/clamp cases, eight source percentage targets, JSON roundtrip, direction, endpoint callbacks and invalid packets. Collision/host clock remain external.")
	quit()
