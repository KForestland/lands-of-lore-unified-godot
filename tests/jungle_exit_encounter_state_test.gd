extends SceneTree
const State=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
## Every opcode8 is acknowledged at once here (explicit supplied adapter; see the wait cases below).
var POST:={"shared":{"13":0,"14":1,"18":1,"47":0},"locals":{"41":0,"49":0,"51":0},"opcode8":func(_c):return true}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func has_effect(effects: Array, type: String, key: String="", value: Variant=null) -> bool:
	for e in effects:
		if e.type==type and (key=="" or e.get(key)==value): return true
	return false
func roundtrip(s: Dictionary, src: Dictionary) -> Dictionary:
	var parsed=JSON.parse_string(JSON.stringify(s))
	assert(State.validate(parsed,src).is_empty())
	return State.canonical(parsed,src)
## Arms the sequence through the source regions and supplied spawn, then the guard59 cutscene.
func armed(src: Dictionary) -> Dictionary:
	var s:=State.initial(src)
	State.enter_region(s,src,4437,POST);State.enter_region(s,src,4435,POST)
	State.spawn_guards(s,src,POST);State.enter_region(s,src,4439,POST)
	State.enter_region(s,src,4442,POST);State.pose_finished(s,src,"59",POST)
	return s
func run() -> void:
	var src:=State.source()
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty() and roundtrip(s,src)==s,"Initial state invalid"):return
	if not check(State.GUARDS.all(func(id):return not s.actors[id].present) and not s.actors["61"].present,"Guards/Bacatta present at load"):return
	# Region4437 needs the post-translation predicate138 and arms once (local53 latch).
	State.enter_region(s,src,4437,{"shared":{"14":0,"18":1},"locals":{},"opcode8":POST.opcode8})
	if not check(s.locals["42"]==0,"Region4437 armed before translation"):return
	State.enter_region(s,src,4437,POST)
	if not check(s.locals["42"]==1 and s.locals["53"]==1,"Region4437 did not arm"):return
	s.locals["42"]=0;State.enter_region(s,src,4437,POST)
	if not check(s.locals["42"]==0,"Region4437 not one-shot"):return
	s.locals["42"]=1
	var e:=State.enter_region(s,src,4435,POST)
	if not check(s.locals["42"]==2 and s.prop4398==1 and has_effect(e,"object","target",552),"Region4435 effects differ"):return
	# Supplied prop552 kind5 spawn (producer unknown) needs predicate182.
	if not check(State.spawn_guards(State.initial(src),src,{"shared":{"14":1,"18":0},"locals":{}}).is_empty(),"Spawn ignored predicate182"):return
	e=State.spawn_guards(s,src,POST)
	if not check(State.GUARDS.all(func(id):return s.actors[id].present and not State.fighting(s,id)) and s.locals["56"]==1,"Spawn differs"):return
	State.enter_region(s,src,4439,POST)
	if not check(s.locals["56"]==2,"Region4439 differs"):return
	e=State.enter_region(s,src,4442,POST)
	if not check(s.locals["42"]==3 and s.actors["59"].state==1 and s.actors["59"].pose==8 and not State.fighting(s,"59") and has_effect(e,"group","group",28438),"Guard59 cutscene did not start"):return
	e=State.pose_finished(s,src,"59",POST)
	if not check(State.GUARDS.all(func(id):return State.fighting(s,id)) and (s.timers["58:0"].flags&1)==0,"Cutscene end did not wake guards/start timer0"):return
	s=roundtrip(s,src)
	State.advance(s,src,14.9,POST)
	if not check(s.actors["58"].pose==-1,"Timer0 fired early"):return
	e=State.advance(s,src,0.2,POST)
	if not check(has_effect(e,"group","group",28242) and s.actors["58"].pose==12 and not State.fighting(s,"58") and (s.timers["58:0"].flags&1)==1,"Timer0 expiry differs"):return
	State.pose_finished(s,src,"58",POST)
	if not check(State.fighting(s,"58") and (s.timers["58:1"].flags&1)==0,"Guard58 pose end did not start timer1"):return
	for id in State.GUARDS: State.damage(s,src,id,255,POST)
	if not check(s.locals["48"]==3 and s.actors["58"].state==10 and State.GUARDS.all(func(id):return s.actors[id].defeated),"Defeat count differs"):return
	if not check(State.damage(s,src,"58",5,POST).is_empty(),"Defeated guard damaged"):return
	State.advance(s,src,14.0,POST)
	if not check(s.ending.is_empty(),"Ending before timer1"):return
	e=State.advance(s,src,1.1,POST)
	if not check(s.ending.movie=="HW-BRDGE.VQA" and s.ending.movie_index==33 and has_effect(e,"reposition","position",[5559,0,-3922]) and s.locals["48"]==10 and s.locals["42"]==5,"All-defeated ending differs"):return
	if not check(roundtrip(s,src)==s,"Ending lost through JSON"):return
	# Guards alive when timer1 expires: prop4398 state1 selects E069E and removes all guards.
	s=armed(src)
	State.advance(s,src,15.05,POST);State.pose_finished(s,src,"58",POST)
	State.damage(s,src,"60",255,POST)
	e=State.advance(s,src,15.05,POST)
	if not check(s.ending.movie=="E069E.VQA" and s.locals["48"]==10 and State.GUARDS.all(func(id):return not s.actors[id].present) and has_effect(e,"remove","actor",59),"Captured ending differs"):return
	# Water-death latch local49 blocks timer1's ending (predicate2).
	s=armed(src)
	var drowned:={"shared":POST.shared,"locals":{"41":0,"49":1,"51":0},"opcode8":POST.opcode8}
	State.advance(s,src,15.05,drowned);State.pose_finished(s,src,"58",drowned)
	State.advance(s,src,15.05,drowned)
	if not check(s.ending.is_empty() and (s.timers["58:1"].flags&1)==0,"local49 did not block the ending"):return
	# Returning west through region4450 at local42==3 ends at once and stops timer1.
	s=armed(src)
	e=State.enter_region(s,src,4450,POST)
	if not check(s.ending.movie=="E069E.VQA" and (s.timers["58:1"].flags&1)==1,"Region4450 ending differs"):return
	# Striking a guard before region4442 (local42<3) starts the same cutscene (kind9 pred54).
	s=State.initial(src)
	State.enter_region(s,src,4437,POST);State.enter_region(s,src,4435,POST);State.spawn_guards(s,src,POST)
	e=State.damage(s,src,"60",20,POST)
	if not check(s.locals["42"]==3 and s.actors["59"].state==1 and s.actors["60"].health==235 and has_effect(e,"group","group",28884) and has_effect(e,"group","group",28438),"Early hit differs"):return
	State.damage(s,src,"58",20,POST)
	if not check(s.actors["59"].state==1 and s.locals["42"]==3,"Second hit repeated the cutscene"):return
	# Opcode8 waits: without an acknowledgement the cutscene group holds at its first opcode8
	# (before the pose request); the cursor survives JSON and resumes in order.
	var hold:={"shared":POST.shared,"locals":POST.locals}
	s=State.initial(src)
	for r in [4437,4435]: State.enter_region(s,src,r,POST)
	State.spawn_guards(s,src,POST);State.enter_region(s,src,4439,POST)
	e=State.enter_region(s,src,4442,hold)
	var waits:=State.waiting(s,src)
	if not check(waits.size()==1 and waits[0].group==28438 and waits[0].cursor==8 and waits[0].argument==1 and s.actors["59"].pose==-1 and s.actors["59"].state==1 and has_effect(e,"wait","group",28438),"Unacknowledged opcode8 did not hold group28438"):return
	if not check(State.pose_finished(s,src,"59",POST).is_empty() and State.resume(s,src,hold).is_empty(),"Held group advanced without acknowledgement"):return
	s=roundtrip(s,src)
	if not check(s.pending==[{"group":28438,"cursor":8}],"Opcode8 cursor lost through JSON"):return
	# Acknowledge only arguments 0/1: the pose request runs, then the group waits at opcode8 argument2.
	var partial:={"shared":POST.shared,"locals":POST.locals,"opcode8":func(c):return c.argument!=2}
	e=State.resume(s,src,partial)
	if not check(s.actors["59"].pose==8 and has_effect(e,"pose","selector",8) and s.pending==[{"group":28438,"cursor":11}] and has_effect(e,"wait","argument",2),"Partial acknowledgement differs"):return
	# Other source groups keep running while one group waits (a hit on guard60 still counts).
	State.damage(s,src,"60",255,hold)
	if not check(s.locals["48"]==1 and s.pending.size()==1,"Waiting group blocked an unrelated group"):return
	e=State.resume(s,src,POST)
	if not check(s.pending.is_empty() and has_effect(e,"opcode8","argument",2),"Final acknowledgement differs"):return
	State.pose_finished(s,src,"59",POST)
	if not check(State.fighting(s,"58") and State.fighting(s,"59") and not State.fighting(s,"60"),"Resumed sequence differs"):return
	# Malformed states are rejected.
	var waiting_state:=State.canonical(s,src)
	for bad_pending in [[{"group":28438,"cursor":3}],[{"group":99,"cursor":0}],[{"group":28438,"cursor":12}],[{"group":28438,"cursor":8.5}],"x"]:
		var bad:=waiting_state.duplicate(true);bad.pending=bad_pending
		if not check(not State.validate(bad,src).is_empty(),"Accepted pending "+str(bad_pending)):return
	var good:=State.canonical(s,src)
	for change in [["version",2],["prop4398",-1],["rng",-5],["ticks_fraction",1.0],["ticks_fraction",NAN],["ticks_fraction",INF],["ticks_fraction",-0.1]]:
		var bad:=good.duplicate(true);bad[change[0]]=change[1]
		if not check(not State.validate(bad,src).is_empty(),"Accepted "+str(change)):return
	var bad_actor:=good.duplicate(true);bad_actor.actors["58"].health=0
	if not check(not State.validate(bad_actor,src).is_empty(),"Accepted zero health without defeat"):return
	var bad_timer:=good.duplicate(true);bad_timer.timers["58:0"].remaining=70000
	if not check(not State.validate(bad_timer,src).is_empty(),"Accepted bad timer"):return
	for pose in [1.5,-2,256,NAN,"8"]:
		var bad_pose:=good.duplicate(true);bad_pose.actors["58"].pose=pose
		if not check(not State.validate(bad_pose,src).is_empty(),"Accepted pose "+str(pose)):return
	var ended:=armed(src);State.enter_region(ended,src,4450,POST)
	ended=roundtrip(ended,src)
	if not check(ended.ending=={"movie_index":57,"movie":"E069E.VQA","predicate":52},"Ending tuple differs"):return
	for ending in [{"movie_index":57,"movie":"HW-BRDGE.VQA","predicate":52},{"movie_index":33,"movie":"HW-BRDGE.VQA","predicate":51},{"movie_index":12,"movie":"X.VQA","predicate":50},{"movie_index":57,"movie":"E069E.VQA","predicate":52,"extra":1},{"movie_index":57.5,"movie":"E069E.VQA","predicate":52}]:
		var bad_ending:=ended.duplicate(true);bad_ending.ending=ending
		if not check(not State.validate(bad_ending,src).is_empty(),"Accepted ending "+str(ending)):return
	var legacy:=good.duplicate(true);legacy.erase("pending")
	if not check(State.validate(legacy,src).is_empty() and State.canonical(legacy,src).pending==[],"Pre-cursor packet rejected"):return
	var bad_local:=good.duplicate(true);bad_local.locals.erase("48")
	if not check(not State.validate(bad_local,src).is_empty(),"Accepted missing local"):return
	print("PASS: Jungle exit encounter source groups: 4437 arm/latch, 4435, supplied spawn (pred182), 4439, 4442 cutscene, 13/7 wake, 15 s timers, defeat count, HW-BRDGE/E069E endings with reposition, local49 block, region4450, early-hit pred54, JSON rollback, saved opcode8 cursors (hold/partial/resume, unrelated groups continue), malformed rejection incl. NaN/inf clock, fractional pose, unknown ending tuple")
	quit()
