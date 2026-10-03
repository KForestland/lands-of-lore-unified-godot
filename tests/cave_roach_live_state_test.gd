extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
func _initialize() -> void:
	var s:=State.initial();State.initialize_visuals(s);State.initialize_live(s)
	assert(State.validate(s).is_empty() and s.live.size()==23 and s.live["42"].heading==int(JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE)).actors.filter(func(r):return int(r.actor)==42)[0].heading))
	# Perception: out of range, blocked sight and dead player all stay idle.
	assert(State.advance_live(s,"42",0.1,181,true,false,30)==0 and s.live["42"].mode==State.IDLE)
	assert(State.advance_live(s,"42",0.1,100,false,false,30)==0 and s.live["42"].mode==State.IDLE)
	assert(State.advance_live(s,"42",0.1,100,true,false,0)==0 and s.live["42"].mode==State.IDLE)
	assert(State.advance_live(s,"42",0.1,100,true,false,30)==0 and s.live["42"].mode==State.PURSUE)
	assert(State.advance_live(s,"42",0.1,40,true,false,30)==0 and s.live["42"].mode==State.ATTACK and s.live["42"].elapsed==0)
	# Source selector6 impact at frame12/8fps: exactly one7-point bite per clip.
	assert(State.advance_live(s,"42",1.49,40,true,false,30)==0 and not s.live["42"].hit)
	assert(State.validate(s).is_empty())
	assert(State.advance_live(s,"42",0.01,40,true,false,30)==State.DAMAGE and s.live["42"].hit)
	assert(State.advance_live(s,"42",0.25,40,true,false,23)==0 and s.live["42"].mode==State.ATTACK)
	var mid: Dictionary=JSON.parse_string(JSON.stringify(s))
	assert(State.validate(mid).is_empty() and State.canonical(mid)==State.canonical(s))
	assert(State.advance_live(s,"42",0.25,100,true,false,23)==0 and s.live["42"].mode==State.PURSUE and not s.live["42"].hit)
	# A long step crossing the impact still lands only once, then the clip ends.
	s.live["42"].merge({"mode":State.ATTACK,"elapsed":0.0,"hit":false},true)
	assert(State.advance_live(s,"42",5.0,30,true,false,30)==State.DAMAGE and s.live["42"].mode==State.ATTACK and s.live["42"].elapsed==0)
	# Leaving reach, losing sight or protection at the impact frame misses but the clip completes.
	for case in [[60,true,false],[30,false,false],[30,true,true]]:
		s.live["42"].merge({"mode":State.ATTACK,"elapsed":1.4,"hit":false},true)
		assert(State.advance_live(s,"42",0.2,case[0],case[1],case[2],30)==0 and s.live["42"].hit and s.live["42"].mode==State.ATTACK)
	s.live["42"].merge({"mode":State.ATTACK,"elapsed":1.4,"hit":false},true)
	assert(State.advance_live(s,"42",0.2,30,true,false,4)==4)
	# Defeat stops behavior and validates.
	s.live["42"].merge({"mode":State.ATTACK,"elapsed":1.0,"hit":false},true)
	assert(State.damage(s,"42",99)==10 and s.live["42"].mode==State.IDLE and State.validate(s).is_empty())
	assert(State.advance_live(s,"42",0.5,10,true,false,30)==0 and s.live["42"].mode==State.IDLE)
	# Malformed packets are rejected.
	for change in [{"mode":3},{"mode":State.IDLE,"elapsed":0.5},{"mode":State.ATTACK,"elapsed":1.0,"hit":true},{"mode":State.ATTACK,"elapsed":2.0},{"heading":65536},{"hit":1}]:
		var bad: Dictionary=State.canonical(s)
		bad.live["41"].merge(change,true)
		assert(not State.validate(bad).is_empty())
	var dead: Dictionary=State.canonical(s);dead.live["42"].mode=State.PURSUE
	assert(not State.validate(dead).is_empty())
	var missing: Dictionary=State.canonical(s);missing.live.erase("41")
	assert(not State.validate(missing).is_empty())
	for v in [Vector2(0,1),Vector2(1,0),Vector2(-0.3,-0.9).normalized()]:
		assert(State.heading_vector(State.heading_units(v)).distance_to(v)<0.0002)
	print("PASS: Roach perception/pursuit/attack modes, single source7 bite at frame12, miss/protection/cap, defeat stop, JSON and malformed rejection")
	quit()
