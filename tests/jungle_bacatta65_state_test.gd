extends SceneTree
## Bacatta65 source chain on the pure state: alert/met predicates gate the prop3235 sighting; first-entry region talk
## sets GV_MET_BACATTA at the first line end; idle waits advance on loop wraps (kind6 value1); state16 timer leads to
## the peaceful outcome (actor65 linked, prop553 removed); a hit leads through the Luther lines to the hostile
## outcome; a second hit is immediately hostile; offers adjust the relationship and return to the wait; walk-away
## replays selector29 once; region3157 removes actor65 once met; checkpoints round-trip through JSON.
const State=preload("res://scripts/lol2/jungle_bacatta65_state.gd")
var src: Dictionary
var t: Dictionary
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok

func ctx_for(g: Dictionary) -> Dictionary: return {"shared":g}
## Host stand-in for shared writes (caps from the source).
func apply(g: Dictionary, fx: Array, log: Array) -> void:
	for e in fx:
		log.append(e)
		if e.type=="shared":
			var key:=str(int(e.index));var cap:=int(src.shared_caps.get(key,255))
			g[key]=clampi(int(e.value) if e.op=="set" else int(g.get(key,0))+int(e.value),0,cap)

func play(s: Dictionary, g: Dictionary, seconds: float, log: Array, until: Callable=Callable()) -> bool:
	for i in int(seconds*60):
		apply(g,State.advance(s,src,t,1.0/60,ctx_for(g)),log)
		if until.is_valid() and until.call(): return true
	return not until.is_valid()

func fresh(g: Dictionary) -> Dictionary:
	var s:=State.initial(src);var log: Array=[]
	apply(g,State.sighted(s,src,t,ctx_for(g)),log)
	return s

func run() -> void:
	src=State.source();t=State.timing()
	if not check(not t.is_empty(),"Media missing: run tools/prepare_jungle_bacatta65_media.py"): return
	# Predicates: no alert, or already met -> no sighting.
	for g in [{"29":0,"18":0},{"29":1,"18":1}]:
		var s:=State.initial(src)
		if not check(State.sighted(s,src,t,ctx_for(g)).is_empty() and not s.prop.present and not s.sighted,"Sighting admitted outside alert-before-meeting"): return
	# Sighting: present + event20 idle loop (BC08 segment1, 255 passes), focus.
	var g:={"29":1,"18":0,"13":0,"0":5}
	var s:=fresh(g)
	if not check(s.prop.present and s.sighted and int(s.prop.clip.segment)==1 and int(s.prop.clip.passes)==255 and s.focus,"Sighting did not start the idle loop: %s"%[s.prop]): return
	var log: Array=[]
	play(s,g,3.5,log)
	if not check(int(s.prop.state)==0 and log.filter(func(e): return e.type=="clip_wrap").size()>=3,"Idle loop wraps changed state"): return
	# First entry: hold, reposition, local2=1, state2/selector1; first line end sets MET.
	log=[]
	apply(g,State.enter_region(s,src,t,577,ctx_for(g)),log)
	if not check(int(s.locals["2"])==1 and int(s.prop.state)==2 and int(s.prop.selector)==1 and s.hold and log.any(func(e): return e.type=="reposition"),"First entry differs"): return
	if not check(State.movement_locked(s,src),"Line does not hold movement"): return
	apply(g,State.enter_region(s,src,t,582,ctx_for(g)),log)
	if not check(int(s.prop.state)==2,"Second first-entry region re-ran"): return
	if not check(play(s,g,12.0,log,func(): return int(g.get("18",0))==1),"MET not set by the first line"): return
	# Waiting path: reaches state6 idle, wraps on, state16 timer -> outcome B.
	if not check(play(s,g,40.0,log,func(): return int(s.prop.state)==6),"State6 not reached"): return
	if not check(not State.movement_locked(s,src) and int(s.prop.selector)==5,"Idle wait locks movement"): return
	var snap: Dictionary=JSON.parse_string(JSON.stringify(s))
	if not check(State.validate(snap,src,t).is_empty() and State.canonical(snap)==State.canonical(s),"Checkpoint round-trip differs"): return
	if not check(play(s,g,120.0,log,func(): return int(s.prop.state)==16),"State16 not reached"): return
	if not check(play(s,g,60.0,log,func(): return s.actor.present),"Timer did not lead to outcome B"): return
	if not check(not s.prop.present and not State.hostile(s) and not s.hold and not s.focus and int(s.locals["2"])==5 and log.any(func(e): return e.type=="actor_behaviour"),"Outcome B differs: %s"%[s]): return
	if not check(int(g["13"])==0 and int(g["0"])==5,"Peaceful outcome changed soul/relationship"): return
	# Region3157 (met) removes actor65 and reports actor57 as unowned.
	log=[]
	apply(g,State.enter_region(s,src,t,3157,ctx_for(g)),log)
	if not check(not s.actor.present and log.any(func(e): return e.type=="external" and e.raw=="090239000200"),"Region3157 removal differs"): return
	# Restored state continues identically: from the snap (state6), offer -> relationship+1, selector28, back to 6.
	g={"29":1,"18":1,"13":0,"0":5}
	s=State.canonical(snap);log=[]
	apply(g,State.offer(s,src,t,false,ctx_for(g)),log)
	if not check(int(g["13"])==0 and int(s.prop.state)==6,"Empty hand admitted an offer"): return
	apply(g,State.offer(s,src,t,true,ctx_for(g)),log)
	if not check(int(g["13"])==1 and int(s.prop.state)==29 and int(s.prop.selector)==28,"Offer at state6 differs"): return
	if not check(play(s,g,20.0,log,func(): return int(s.prop.state)==6),"Offer line did not return to state6"): return
	# Hit before state16: MET, local3, Luther lines (19 -> 17 -> 18), hostile outcome A; soul/relationship unchanged.
	apply(g,State.hit(s,src,t,5,ctx_for(g)),log)
	if not check(int(s.locals["3"])==1 and int(s.locals["2"])==10 and int(s.prop.state)==19,"First hit differs"): return
	if not check(play(s,g,30.0,log,func(): return s.actor.present),"Hit path did not reach outcome A"): return
	if not check(State.hostile(s) and not s.prop.present and not s.hold and int(g["13"])==1 and int(g["0"])==5,"Outcome A differs: %s %s"%[s,g]): return
	# Hit at state>15 with local3==0: soul and relationship -1. Second hit: immediate hostile.
	g={"29":1,"18":1,"13":1,"0":5}
	s=State.canonical(snap);s.prop.state=16;s.prop.selector=15
	apply(g,State.hit(s,src,t,5,ctx_for(g)),log)
	if not check(int(g["0"])==4 and int(g["13"])==0 and int(s.prop.state)==19,"Late hit differs: %s"%[g]): return
	apply(g,State.hit(s,src,t,5,ctx_for(g)),log)
	if not check(State.hostile(s) and not s.prop.present,"Second hit not immediately hostile"): return
	# Walk-away while local2==1: reposition, local2=3, selector29 plays once (adapter), resumes at state7.
	g={"29":1,"18":1,"13":0,"0":5}
	s=State.canonical(snap);log=[]
	apply(g,State.enter_region(s,src,t,3890,ctx_for(g)),log)
	if not check(int(s.locals["2"])==3 and int(s.prop.state)==32 and int(s.prop.selector)==29,"Walk-away differs"): return
	if not check(play(s,g,10.0,log,func(): return int(s.prop.state)==7),"Walk-away line did not resume the talk"): return
	apply(g,State.enter_region(s,src,t,3891,ctx_for(g)),log)
	if not check(int(s.prop.state)==7,"Walk-away replayed"): return
	# Malformed checkpoints are rejected.
	for bad in [{"k":"selector","v":31},{"k":"state","v":33},{"k":"state","v":1.5}]:
		var b:=State.canonical(snap);b.prop[bad.k]=bad.v
		if not check(not State.validate(b,src,t).is_empty(),"Malformed accepted: %s"%[bad]): return
	print("PASS bacatta65 state: alert/met gate, idle wraps, first entry hold/MET, timer -> peaceful actor65, offer +1 and return, hit -> Luther lines -> hostile, late hit soul/relationship -1, second hit hostile, walk-away once, region3157 removal, JSON round-trip, malformed rejected.")
	quit()
