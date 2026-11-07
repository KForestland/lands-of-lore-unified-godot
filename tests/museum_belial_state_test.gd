extends SceneTree
const State=preload("res://scripts/lol2/museum_belial_state.gd")
func _initialize() -> void:
	var s=State.initial()
	assert(State.validate(s)=="")
	State.advance_units(s,1.0)
	assert(s.frame==1 and s.remaining==1023)
	State.advance_units(s,1023.0)
	assert(s.frame==1 and s.remaining==0)
	State.advance_units(s,1.0)
	assert(s.frame==2 and s.remaining==1023)
	assert(State.use(s) and s.frame==0 and s.remaining==1023)
	s.frame=12
	assert(State.use(s) and s.frame==12 and s.remaining==1023)
	for frame in range(60):
		var active={"version":1,"phase":"active","frame":frame,"remaining":0.0}
		assert(State.validate(active)=="")
		var completed=State.advance_units(active,1.0)
		assert(completed==(frame==59))
		assert(active.frame==frame+1)
		assert(active.phase==("gone" if completed else "active"))
		assert(State.validate(active)=="")
		var loaded=JSON.parse_string(JSON.stringify(active))
		assert(State.validate(loaded)=="")
		if completed:assert(not State.use(loaded) and not State.advance_units(loaded,99999.0))
	var serial=JSON.parse_string(JSON.stringify(s))
	State.advance_units(s,321.0);State.advance_units(serial,321.0)
	assert(s.phase==serial.phase and s.frame==serial.frame and s.remaining==serial.remaining)
	for field in ["frame","remaining"]:
		var bad=State.initial();bad[field]=NAN
		assert(State.validate(bad)!="")
	var bad=State.initial();bad.frame=0.5
	assert(State.validate(bad)!="")
	print("PASS museum_belial_state_test: source-clock boundaries,60 native active transitions,repeat E,serialized continuation,invalid checkpoints")
	quit(0)
