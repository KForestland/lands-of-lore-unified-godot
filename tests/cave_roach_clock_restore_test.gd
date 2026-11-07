extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const Population=preload("res://scripts/lol2/cave_roach_population.gd")
class Host extends Node3D:
	var roach_population: Dictionary
	var native_translation:=Vector3.ZERO
var failures:=0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	var single=State.initial()
	State.player_hit(single,"40")
	State.advance_ai(single,10.0)
	for hz in [30,60,120,240]:
		for reload_midway in [false,true]:
			var state=State.initial()
			State.player_hit(state,"40")
			for i in hz*10:
				State.advance_ai(state,1.0/hz)
				if reload_midway and i==hz*3+hz/2:
					state=State.canonical(JSON.parse_string(JSON.stringify(state)))
			check(State.validate(state).is_empty(),"Invalid clock packet at %d Hz"%hz)
			check(state.actors["40"].stats[State.ATTACKED_STAT]==single.actors["40"].stats[State.ATTACKED_STAT],"Decay partition mismatch %d Hz reload=%s"%[hz,reload_midway])
			check(absf(state.ai.clock-single.ai.clock)<0.00000001,"Remainder partition mismatch %d Hz"%hz)
	# The real save path (cave_walkthrough _save_state -> State.saved -> full-precision JSON) must round-trip exactly,
	# and a load shifts the clock by under one 1/1024 s grid step (once per load, independent of physics Hz).
	# Decay is compared 0.5 s away from a whole second: a load may resume up to one grid step (<1 ms) earlier.
	var single_half=State.initial()
	State.player_hit(single_half,"40")
	State.advance_ai(single_half,10.5)
	for hz in [30,60,120,240]:
		var state=State.initial()
		State.player_hit(state,"40")
		for i in hz*10+hz/2:
			State.advance_ai(state,1.0/hz)
			if i==hz*3+hz/2:
				var packet:=State.saved(state)
				var loaded:=State.canonical(JSON.parse_string(JSON.stringify(packet,"  ",true,true)))
				check(loaded==State.canonical(packet) and State.saved(loaded)==packet,"Save packet did not round-trip exactly at %d Hz"%hz)
				check(float(state.ai.clock)-float(loaded.ai.clock)>=0.0 and float(state.ai.clock)-float(loaded.ai.clock)<1.0/1024,"Load shifted the clock by a grid step or more at %d Hz"%hz)
				state=loaded
		check(State.validate(state).is_empty(),"Invalid clock packet after save-path load at %d Hz"%hz)
		check(state.actors["40"].stats[State.ATTACKED_STAT]==single_half.actors["40"].stats[State.ATTACKED_STAT],"Decay mismatch after save-path load %d Hz"%hz)
	var host=Host.new()
	host.roach_population=State.initial()
	var owner=Population.new()
	owner.host=host
	owner._legs["40"]={"left":1.25,"count":99,"heading":Vector3.RIGHT}
	owner.restore()
	check(owner._legs.is_empty(),"Reload retained an unsaved future scurry leg")
	owner.free()
	host.free()
	if failures: quit(1); return
	print("PASS roach decay partition invariance at30/60/120/240Hz with JSON restore, exact save-packet round trip (1/1024 s grid at save), transient legs cleared on restore")
	quit()
