extends SceneTree
## Kelsrick inner gate (74/75) on the pure state.
## - Shut at rest. Control98 selector1 (Kelsrick's talk1 end) opens both leaves; selector0 shuts them.
## - Region2752 opens; direct op1 commands (Kelsrick g5084, the alarm) shut.
## - Use acts only once Kelsrick is dead: leaf 74 opens 74 alone (source quirk), leaf 75 opens both.
## - The clock swings and stops. Validation and JSON round trip.
const State=preload("res://scripts/lol2/jungle_inner_gate_state.gd")
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func targets(s: Dictionary) -> Array: return [int(s.leaves["74"].target),int(s.leaves["75"].target)]

func run() -> void:
	var src:=State.source()
	var alive:={"shared":{"11":0}};var dead:={"shared":{"11":1}}
	var s:=State.initial()
	if not check(targets(s)==[0,0] and State.percent(s,"74")==0,"Must be shut at rest"): return
	if not check(not State.external(s,src,"051062000100",alive).is_empty() and targets(s)==[100,100],"Control98 selector1 must open"): return
	State.external(s,src,"051062000000",alive)
	if not check(targets(s)==[0,0],"Control98 selector0 must shut"): return
	State.enter_region(s,src,2752,alive)
	if not check(targets(s)==[100,100],"Region2752 must open"): return
	State.external(s,src,"01204a000000",alive);State.external(s,src,"01204b000000",alive)
	if not check(targets(s)==[0,0],"Direct op1 must shut"): return
	if not check(State.external(s,src,"051052000000",alive).is_empty() and State.external(s,src,"0903e4010a00",alive).is_empty(),"Unrelated raw commands must do nothing"): return
	if not check(State.use(s,src,74,alive).is_empty() and targets(s)==[0,0],"Use must need Kelsrick dead"): return
	State.use(s,src,74,dead)
	if not check(targets(s)==[100,0],"Leaf74 use opens 74 only (g27916)"): return
	State.use(s,src,75,dead)
	if not check(targets(s)==[100,100],"Leaf75 use opens both (g27934)"): return
	for i in 120: State.advance(s,"74",1.0/60)
	if not check(State.percent(s,"74")==100 and State.percent(s,"75")==0 and float(s.leaves["74"].elapsed)==State.DURATION,"Clock differs"): return
	var saved=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(saved).is_empty() and State.canonical(saved)==s,"Round trip"): return
	if not check(State.initial(true).leaves["75"]=={"target":100,"elapsed":State.DURATION},"Open initial differs"): return
	for bad in [{"version":2,"leaves":s.leaves},{"version":1,"leaves":{"74":{"target":50,"elapsed":0.0},"75":{"target":0,"elapsed":0.0}}},
		{"version":1,"leaves":{"74":{"target":0,"elapsed":5.0},"75":{"target":0,"elapsed":0.0}}},{"version":1,"leaves":{"74":{"target":0,"elapsed":0.0}}}]:
		if not check(not State.validate(bad).is_empty(),"Accepted %s"%[bad]): return
	print("PASS jungle_inner_gate_state_test: shut at rest; control98 1/0 open/shut; region2752 opens; op1 shuts; use only after Kelsrick death (74 alone / both); clock; validation")
	quit(0)
