extends SceneTree
## Source-chain fixture for jungle_bacatta_state.gd (not an earned route): supplied producers only.
const State=preload("res://scripts/lol2/jungle_bacatta_state.gd")
const Exit=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const STEP:=1.0/30.0
var src: Dictionary
var t: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func ctx(shared13: int, guard: bool=true) -> Dictionary:
	return {"shared":{"0":5,"12":5,"13":shared13,"14":1,"18":1,"25":0,"47":0},"locals":{"41":0},"guard60":{"present":guard,"alive":guard}}
func has(effects: Array, type: String, key: String="", value: Variant=null) -> bool:
	for e in effects:
		if e.type==type and (key=="" or e.get(key)==value): return true
	return false
func roundtrip(s: Dictionary) -> Dictionary:
	var parsed=JSON.parse_string(JSON.stringify(s,"  ",true,true))  # same writer settings as jungle_save.gd
	assert(State.validate(parsed,src,t).is_empty())
	return State.canonical(parsed)
## Advance in fixed steps until cond(state, effects) holds; collects every effect.
func until(s: Dictionary, c: Dictionary, cond: Callable, seconds: float, log: Array) -> bool:
	var elapsed:=0.0
	while elapsed<seconds:
		var e:=State.advance(s,src,t,STEP,c);log.append_array(e);elapsed+=STEP
		if cond.call(s,e): return true
	return false
func sighted(c: Dictionary) -> Dictionary:
	var s:=State.initial(src)
	State.enter_region(s,src,t,1921,c)
	# Exit group10720 (first eligible render, Codex visibility) runs these prop552 commands.
	State.external_commands(s,src,t,["050328020100","0803280200000000","080328020700ff00","080328020a000400"],c)
	return s
func run() -> void:
	src=State.source();t=State.timing()
	if not check(not t.is_empty(),"Media not staged (run tools/prepare_jungle_bacatta_media.py)"):return
	var s:=State.initial(src)
	if not check(State.validate(s,src,t).is_empty() and roundtrip(s)==s and not s.prop552.present,"Initial state differs"):return
	# Region1921 links prop552 only after translation (predicate119).
	State.enter_region(s,src,t,1921,{"shared":{"14":0,"18":1},"locals":{}})
	if not check(not s.prop552.present,"prop552 linked before translation"):return
	var friendly:=ctx(1)
	s=sighted(friendly)
	if not check(s.prop552.present and s.prop552.selector==1 and s.prop552.repeat and s.prop552.clip.selector==1 and s.prop552.clip.segment==4,"Sighting loop differs"):return
	# Friendly use (shared13>=1, predicate39): signed shared writes, local51, reposition, state1, repeat off.
	var e:=State.use(s,src,t,friendly)
	if not check(has(e,"shared","index",0) and has(e,"shared","index",13) and s.locals["51"]==1 and has(e,"reposition") and s.prop552.state==1 and not s.prop552.repeat and s.prop552.clip.segment==11,"Friendly use differs (wake segment11)"):return
	var writes:=e.filter(func(x):return x.type=="shared")
	if not check(writes.size()==2 and writes.all(func(x):return x.op=="add" and x.value==1),"Friendly shared writes differ"):return
	if not check(State.use(s,src,t,friendly).filter(func(x):return x.type=="shared").is_empty(),"Repeated use re-applied shared writes"):return
	# The BC07 cycle completes, then selectors2..13 play in order and state13 hands over to Bacatta.
	var log: Array=[]
	if not check(until(s,friendly,func(st,_e):return st.bacatta.present,140.0,log),"Bacatta never appeared"):return
	var played:=log.filter(func(x):return x.type=="clip" and x.owner=="prop552").map(func(x):return x.selector)
	if not check(played==[2,3,4,5,6,7,8,9,10,11,12,13],"Prop sequence differs: "+str(played)):return
	if not check(not s.prop552.present and s.bacatta.goal==7 and s.bacatta.state==5 and s.locals["37"]==1 and (s.timers["0"].flags&1)==0,"Bacatta handover differs"):return
	# Timer0 (2 s) → property22 escort; sounds follow the timer/kind8 chain in source order.
	log=[]
	if not check(until(s,friendly,func(st,_e):return st.escort,2.2,log) and State.escort_target(s)!=null,"Escort did not start"):return
	var mid: Dictionary
	if not check(until(s,friendly,func(st,_e):return not st.sounds.is_empty() and st.sounds[0].request==3 and float(st.sounds[0].elapsed)>1.0,8.0,log),"Request3 did not start"):return
	mid=roundtrip(s)
	if not check(mid==s,"Mid-voice JSON rollback differs"):return
	if not check(until(s,friendly,func(st,_e):return has(_e,"escort","focus",false),120.0,log),"Event22 never released the escort"):return
	var sounds:=log.filter(func(x):return x.type=="sound").map(func(x):return x.request)
	if not check(sounds.slice(0,3)==[3,1,4] and s.bacatta.state==10 and s.guard60.selector==8 and s.guard60.clip.selector==8,"Escort/sound/event22 chain differs: "+str(sounds)):return
	# Mid-animation rollback: two copies continue identically.
	var copy:=roundtrip(s)
	var a:=State.advance(s,src,t,0.5,friendly);var b:=State.advance(copy,src,t,0.5,friendly)
	if not check(a==b and s==copy,"Mid-animation rollback diverged"):return
	# Guard60/Bacatta choreography reaches prop4398 event20 exactly once.
	log=[]
	if not check(until(s,friendly,func(st,_e):return st.ending_requested,60.0,log),"Choreography never requested the ending"):return
	if not check(s.guard60.state==6 and s.bacatta.state==14 and log.filter(func(x):return x.type=="exit_event20").size()==1,"Choreography end differs"):return
	var guard_clips:=log.filter(func(x):return x.type=="clip" and x.owner=="guard60").map(func(x):return x.selector)
	var bac_clips:=log.filter(func(x):return x.type=="clip" and x.owner=="bacatta").map(func(x):return x.selector)
	if not check(guard_clips==[9,10,11] and bac_clips==[1,2],"Choreography clips differ: %s %s"%[guard_clips,bac_clips]):return
	if not check(not log.any(func(x):return x.type=="zero_health"),"Friendly walk through region1897 triggered kind10"):return
	if not check(not until(s,friendly,func(_st,_e):return has(_e,"exit_event20"),5.0,[]),"Ending requested twice"):return
	# Composition with the real exit selector: friendly branch kept prop4398=0 and local51=1 → E068E.
	var xs:=Exit.source();var x:=Exit.initial(xs)
	var xctx:={"shared":{"13":1,"14":1,"18":1,"47":0},"locals":{"41":0,"49":0,"51":s.locals["51"]}}
	Exit.spawn_guards(x,xs,xctx)
	Exit._dispatch(x,xs,"prop",4398,6,20,xctx)
	if not check(str(x.ending.get("movie",""))=="E068E.VQA" and int(x.ending.predicate)==51,"Exit selector did not choose E068E: "+str(x.ending)):return
	# Without guard60 the chain stops at event22 (no ending request).
	var lone:=sighted(ctx(1,false));State.use(lone,src,t,ctx(1,false))
	until(lone,ctx(1,false),func(st,_e):return st.bacatta.state==10,240.0,[])
	if not check(lone.bacatta.state==10 and not until(lone,ctx(1,false),func(st,_e):return st.ending_requested,30.0,[]),"Chain continued without guard60"):return
	# Hostile use (shared13==0, predicate40): local42 for the exit, music, state41 → hostile Bacatta, no escort.
	var hostile:=ctx(0);s=sighted(hostile)
	e=State.use(s,src,t,hostile)
	if not check(s.prop552.state==41 and has(e,"local","local",42) and has(e,"presentation") and s.locals["51"]==1,"Hostile use differs"):return
	if not check(until(s,hostile,func(st,_e):return st.bacatta.present,60.0,[]) and State.bacatta_fighting(s) and not s.escort and not s.prop552.present,"Hostile Bacatta differs"):return
	# Kind10: a hostile (state0) Bacatta entering region1897 gets state1 and A7544 mode0 (ordinary death outcome).
	var poly: Array=src.regions.filter(func(r):return int(r.region)==1897)[0].polygon
	var centre:=Vector2.ZERO
	for v in poly: centre+=Vector2(v[0],v[1])
	centre/=poly.size()
	e=State.actor_moved(s,src,t,centre,hostile)
	if not check(s.bacatta.state==1 and has(e,"zero_health","mode",0) and not State.bacatta_fighting(s) and has(e,"group","group",28932),"Hostile kind10 region1897 differs"):return
	if not check(State.actor_moved(s,src,t,centre+Vector2(1,0),hostile).is_empty(),"kind10 repeated inside the region"):return
	# Hit (kind9 mode4): after>2 refused; after<=2 admitted once; signed shared writes; selector14 then Bacatta.
	s=sighted(friendly)
	if not check(State.hit(s,src,t,{"after":3},friendly).is_empty(),"Hit admitted above threshold"):return
	e=State.hit(s,src,t,{"after":2},friendly)
	var hw:=e.filter(func(x):return x.type=="shared")
	if not check(s.prop552.state==40 and not s.prop552.armed and hw.size()==3 and hw[0].value==-1 and hw[1].value==-1 and hw[2].op=="set" and hw[2].value==0,"Hit branch differs: "+str(hw)):return
	if not check(State.hit(s,src,t,{"after":0},friendly).is_empty(),"Hit latch did not hold"):return
	if not check(State.hit(sighted(friendly),src,t,{"after":1,"special":5},friendly).is_empty(),"Special 0x23331==5 admitted without supplied result"):return
	log=[]
	if not check(until(s,friendly,func(st,_e):return st.bacatta.present,80.0,log) and log.any(func(x):return x.type=="clip" and x.owner=="prop552" and x.selector==14) and State.bacatta_fighting(s),"Hit branch did not reach hostile Bacatta"):return
	# Malformed packets are rejected.
	var good:=roundtrip(mid)
	var bad: Array=[]
	var b1:=good.duplicate(true);b1.version=2;bad.append(b1)
	var b2:=good.duplicate(true);b2.sounds[0].elapsed=999.0;bad.append(b2)
	var b3:=good.duplicate(true);b3.sounds[0].request=77;bad.append(b3)
	var b4:=good.duplicate(true);b4.bacatta.present=false;bad.append(b4)
	var b5:=good.duplicate(true);b5.ticks_fraction=NAN;bad.append(b5)
	var b6:=good.duplicate(true);b6.extra=1;bad.append(b6)
	var b7:=good.duplicate(true);b7.prop552.clip={"selector":99,"elapsed":0.0};bad.append(b7)
	var b8:=good.duplicate(true);b8.bacatta.path_index=40;bad.append(b8)
	for packet in bad:
		if not check(not State.validate(packet,src,t).is_empty(),"Accepted malformed packet "+str(bad.find(packet))):return
	print("PASS: Bacatta source chain: region1921 link (pred119), exit group10720 loop, friendly use (pred39, signed shared once, local51, reposition) → BC07 end → prop selectors2..13 → state13 handover (goal7, timer0) → property22 escort → sounds 3,1,4 via timer/kind8 → path1 event22 releases escort → guard60 8 / Bacatta pose7, clips 1,2 / guard60 9,10,11 → one prop4398 event20 → real exit selector E068E (pred51); no guard60 → stops; hostile use (pred40, local42) and hit mode4 (latched, signed writes, selector14) → hostile Bacatta; mid-voice/mid-clip JSON rollback; 8 malformed packets rejected")
	quit()
