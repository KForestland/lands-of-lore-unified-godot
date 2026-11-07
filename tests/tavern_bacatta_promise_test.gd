extends SceneTree
## JUNGLE-BACATTA (owner F10 2026-11-02 12:22:02, Huline tavern): the ordinary first tavern conversation must leave
## Bacatta friendly and leading. Pure state, headless; CAN.WOM evidence in tools/verify_tavern_return_sources.py.
## - CAN lines 625..636 set flag37 and arm the 2 s host timer; its deadline (message10, 0xD54) clears 37 and plays
##   Bacatta's promise 640..648. Leaving then (message8, 0x91B) plays 656/657, relationship +1 (1 -> 2), flag34.
## - Before this fix every exit took 0xE09 (relationship 0): Bacatta57 sealed the tavern on the next entry and the
##   jungle-exit prop552 chose predicate40, the hostile Bacatta61 (state41), instead of the escort (predicate39).
## - The walk-out (exit while 37 is still set, before the deadline) stays the original's hostile branch.
## - Mid-promise and mid-leave saves round-trip through JSON and the monastery validator.
const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
const Room=preload("res://scripts/lol2/monastery_quest_state.gd")
const Exit=preload("res://scripts/lol2/jungle_bacatta_state.gd")
const Door=preload("res://scripts/lol2/jungle_bacatta57_state.gd")
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
## Same writer settings as jungle_save.gd; the loaded bank must validate.
func reload(state: Dictionary) -> Dictionary:
	var parsed: Variant=JSON.parse_string(JSON.stringify(state,"  ",true,true))
	if not parsed is Dictionary: return {}
	var error: String=Room.validate(parsed)
	if not error.is_empty():
		push_error("Reload rejected: "+error)
		return {}
	return parsed
func same(a: Dictionary, b: Dictionary) -> bool:
	return str(a.sequence)==str(b.sequence) and int(a.cursor)==int(b.cursor) and is_equal_approx(float(a.elapsed),float(b.elapsed))
func play(state: Dictionary, seconds: float) -> void:
	var t:=0.0
	while t<seconds:
		Speech.advance(state,0.25);t+=0.25
func relationship(state: Dictionary) -> int: return int(state.globals.GV_BACATTA_RELATIONSHIP)
func visit() -> Dictionary:
	var state:=Room.initial()
	state.locals.Left_Village=2
	state.flags["41"]=1
	state.room="VILLAGE"
	return state
## The jungle-exit prop552 use: escort (state1) or the hostile Bacatta (state41).
func exit_state(rel: int) -> int:
	var src:=Exit.source();var t:=Exit.timing()
	var c:={"shared":{"0":5,"12":1,"13":rel,"14":1,"18":1,"25":0,"47":0},"locals":{"41":0},"guard60":{"present":true,"alive":true}}
	var s:=Exit.initial(src)
	Exit.enter_region(s,src,t,1921,c)
	Exit.external_commands(s,src,t,["050328020100","0803280200000000","080328020700ff00","080328020a000400"],c)
	Exit.use(s,src,t,c)
	return int(s.prop552.state)
func seals(rel: int) -> bool:
	var src:=Door.source();var s:=Door.initial(src)
	Door.enter_region(s,src,3501,{"shared":{"13":rel,"18":1}})
	return bool(s.sealed)
func run() -> void:
	if not check(not Exit.timing().is_empty(),"Exit media not staged (tools/prepare_jungle_bacatta_media.py)"): return
	# Control: the two consumers of the relationship read 0 as hostile, 1+ as friendly.
	if not check(exit_state(0)==41 and exit_state(1)==1 and exit_state(2)==1,"Jungle-exit predicate39/40 control"): return
	if not check(seals(0) and not seals(1) and not seals(2),"Bacatta57 predicate173 control"): return
	# ---- The ordinary path (owner's): talk, let Bacatta finish, leave ----
	var state:=visit()
	if not check(Speech.begin(state,"CAN") and state.room=="CAN" and state.flags["45"]==1 and relationship(state)==1,"First visit admission"): return
	var lines:=0.0
	for i in Speech.FRAMES.CAN.size(): lines+=Speech.duration("CAN",i)
	play(state,lines+0.5)
	# Line 636 set 37; the timer (2 s) expired during the lines, so the promise follows at once and clears 37.
	if not check(state.conversation.sequence=="CAN_PROMISE" and Speech.active(state.conversation) and state.flags["37"]==0 and not state.has("can_timer"),"Promise did not follow line 636: "+JSON.stringify(state.conversation)): return
	if not check(state.flags["32"]==1 and state.flags["33"]==1 and state.flags["34"]==0,"First-visit flags"): return
	# Leaving is refused while Bacatta speaks (the room's exit is disabled during lines).
	var mid:=reload(state)
	if not check(not mid.is_empty() and same(mid.conversation,state.conversation),"Mid-promise save"): return
	state=mid
	play(state,60.0)
	if not check(state.conversation.sequence=="CAN_PROMISE" and not Speech.active(state.conversation) and relationship(state)==1,"Promise did not finish"): return
	# Message8: Bacatta lets Luther go on his word.
	if not check(Speech.begin_can_exit(state) and state.conversation.sequence=="CAN_LEAVE","Exit did not take the leave branch"): return
	Speech.advance(state,0.5)
	mid=reload(state)
	if not check(not mid.is_empty() and same(mid.conversation,state.conversation) and mid.flags["34"]==0,"Mid-leave save"): return
	state=mid
	play(state,10.0)
	if not check(not Speech.active(state.conversation) and state.flags["34"]==1 and relationship(state)==2,"Leave did not finish friendly: rel %d" % relationship(state)): return
	var saved:=reload(state)
	if not check(not saved.is_empty() and relationship(saved)==2 and int(saved.flags["34"])==1,"Friendly farewell lost over save/reload"): return
	# Consequences: no tavern seal, Bacatta escorts at the jungle exit.
	if not check(not seals(relationship(saved)) and exit_state(relationship(saved))==1,"Friendly farewell still hostile"): return
	# A further exit after the farewell is plain (no second +1).
	if not check(not Speech.begin_can_exit(saved) and relationship(saved)==2,"Second exit changed the relationship"): return
	# ---- The original's walk-out: leave while 37 is still set (before the 2 s deadline) ----
	var walk:=visit()
	Speech.begin(walk,"CAN")
	play(walk,lines+0.5)
	walk.flags["37"]=1;walk.can_timer=1.0;walk.conversation={"sequence":"CAN","cursor":Speech.FRAMES.CAN.size(),"elapsed":0.0}
	if not check(not reload(walk).is_empty(),"Walk-out window save"): return
	if not check(Speech.begin_can_exit(walk) and walk.conversation.sequence=="CAN_EXIT" and walk.flags["34"]==1 and relationship(walk)==0,"Walk-out branch"): return
	if not check(seals(0) and exit_state(0)==41,"Walk-out consequences"): return
	# Older save made in the idle window after line 636 (37 set, no timer): the deadline has passed, so it resumes
	# into the promise, not the walk-out.
	var legacy:=visit()
	Speech.begin(legacy,"CAN")
	legacy.erase("can_timer")
	legacy.flags["37"]=1;legacy.conversation={"sequence":"CAN","cursor":Speech.FRAMES.CAN.size(),"elapsed":0.0}
	legacy=reload(legacy)
	Speech.advance(legacy,0.1)
	if not check(legacy.conversation.sequence=="CAN_PROMISE" and legacy.flags["37"]==0,"Legacy idle save did not resume the promise"): return
	# Malformed timer and impossible promise saves are rejected.
	var bad:=saved.duplicate(true);bad.can_timer=5.0
	if not check(not Room.validate(bad).is_empty(),"Timer above 2 s accepted"): return
	bad=saved.duplicate(true);bad.conversation={"sequence":"CAN_PROMISE","cursor":1,"elapsed":0.0}
	if not check(not Room.validate(bad).is_empty(),"Promise after the farewell accepted"): return
	print("PASS: tavern promise path keeps Bacatta friendly (relationship 1->2, no seal, jungle-exit escort) over save/reload; walk-out stays hostile")
	quit()
