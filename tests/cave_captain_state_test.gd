extends SceneTree
const State=preload("res://scripts/lol2/cave_captain_state.gd")
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
func spawned(src: Dictionary) -> Dictionary:
	var s:=State.initial(src)
	State.plate_entered(s,src,89,4);State.control_animation_finished(s,src)
	return s
func run() -> void:
	var src:=State.source()
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty() and roundtrip(s,src)==s and not s.captain.present,"Initial state differs"):return
	# Source plate value4 (ADA30, any form) at owner state0 runs group9786.
	if not check(State.plate_entered(s,src,89,7).is_empty(),"Wrong plate value admitted"):return
	var e:=State.plate_entered(s,src,89,4)
	if not check(s.objects.control89.state==1 and has_effect(e,"reposition","position",[-1649,0,-4725]) and has_effect(e,"animation","target",120) and not s.captain.present,"Plate group9786 differs"):return
	if not check(State.plate_entered(s,src,89,4).is_empty(),"Plate re-entry repeated"):return
	# Control120 completion (event0) runs both source groups10374/10472: captain appears and fights.
	e=State.control_animation_finished(s,src)
	if not check(s.captain.present and s.captain.state==5 and State.fighting(s) and not s.objects.control89.present and not s.objects.control120.present,"Captain spawn differs"):return
	if not check(has_effect(e,"group","group",10374) and has_effect(e,"group","group",10472),"Both control120 groups must run"):return
	s=roundtrip(s,src)
	# Fighting captain (state5): hits do not trigger the state0 surrender; death grants to the actor.
	e=State.hit(s,src,1,1,50)
	if not check(s.captain.state==5 and s.captain.health==150 and not has_effect(e,"group","group",14448),"State5 hit surrendered"):return
	e=State.hit(s,src,1,1,150)
	if not check(s.captain.defeated and s.captain.items==["5-Short swd"] and s.locals["50"]==10 and s.granted.is_empty(),"Defeat outcome differs"):return
	if not check(State.hit(s,src,1,1,5).is_empty() and State.use(s,src).is_empty(),"Defeated captain still interactive"):return
	# Surrender: kind10 word953 returns state0; AE2C8 mode1 needs mask bit0 in both context words and damage>=1.
	s=spawned(src)
	State.record_event(s,src,10,0,953)
	if not check(s.captain.state==0,"kind10 word953 did not set state0"):return
	State.hit(s,src,2,1,5)
	if not check(s.captain.state==0 and s.captain.health==195,"Mask mismatch admitted kind9"):return
	State.hit(s,src,1,1,0)
	if not check(s.captain.state==0,"Zero damage admitted kind9"):return
	e=State.hit(s,src,1,1,5)
	if not check(s.captain.state==1 and s.captain.health==0 and s.captain.defeated and s.locals["50"]==10 and s.captain.items.is_empty() and s.captain.selector==10 and has_effect(e,"actor_command","sub",18) and has_effect(e,"player_property","property",10),"Surrender differs"):return
	e=State.pose_finished(s,src)
	if not check(s.captain.state==2 and s.captain.selector==11,"Surrender endpoint differs"):return
	s=roundtrip(s,src)
	e=State.use(s,src)
	if not check(s.granted==["5-Short swd"] and s.captain.selector==12 and s.captain.state==3,"First use differs"):return
	e=State.use(s,src)
	if not check(s.granted==["5-Short swd","37-Brnt Chain"] and s.captain.state==4 and (s.timer.flags&1)==0,"Second use differs"):return
	if not check(State.use(s,src).is_empty() or s.granted.size()==2,"Third use granted again"):return
	State.advance(s,src,0.9)
	if not check((s.timer.flags&1)==0,"Timer fired early"):return
	e=State.advance(s,src,0.2)
	if not check(has_effect(e,"speech","request",1031) and (s.timer.flags&1)==1,"prop82 timer expiry differs"):return
	if not check(roundtrip(s,src)==s,"Use chain lost through JSON"):return
	# kind10 words 924/925/922 return the captain to state5.
	State.record_event(s,src,10,0,924)
	if not check(s.captain.state==5,"kind10 word924 differs"):return
	# Latched one-shot player lines: kind3 value12 (local16) and kind5 value0 (local18).
	e=State.record_event(s,src,3,12)
	if not check(s.locals["16"]==1 and State.record_event(s,src,3,12).is_empty(),"kind3 latch differs"):return
	e=State.record_event(s,src,5,0)
	if not check(s.locals["18"]==1 and State.record_event(s,src,5,0).is_empty(),"kind5 value0 latch differs"):return
	# event8 removes the captain.
	State.record_event(s,src,6,8)
	if not check(not s.captain.present,"event8 did not remove the captain"):return
	# Malformed states are rejected.
	var good:=State.canonical(s,src)
	var cases:=[["version",2],["rng",-1],["ticks_fraction",NAN],["ticks_fraction",1.0]]
	for change in cases:
		var bad:=good.duplicate(true);bad[change[0]]=change[1]
		if not check(not State.validate(bad,src).is_empty(),"Accepted "+str(change)):return
	var bad_item:=good.duplicate(true);bad_item.granted.append("99-Fake")
	var bad_health:=good.duplicate(true);bad_health.captain.health=1
	var bad_selector:=good.duplicate(true);bad_selector.captain.selector=1.5
	var bad_object:=good.duplicate(true);bad_object.objects.erase("control120")
	for bad in [bad_item,bad_health,bad_selector,bad_object]:
		if not check(not State.validate(bad,src).is_empty(),"Accepted malformed captain packet"):return
	print("PASS: cave captain source chain: plate89 value4 → group9786 (move/animate120, one-shot), control120 event0 → groups10374+10472 (spawn, state5, fighting), state5 death → actor grant 5-Short swd + local50; kind10 953→state0, AE2C8 mode1 surrender (masks/damage), event3 → selector11, two uses → 5-Short swd + 37-Brnt Chain, prop82 1 s timer → speech1031; kind10 924, kind3/kind5 latches, event8 removal, JSON rollback, malformed rejection")
	quit()
