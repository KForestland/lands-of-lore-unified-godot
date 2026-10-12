extends SceneTree
## actor62 source-state fixture (not an earned route).
const State=preload("res://scripts/lol2/jungle_actor62_state.gd")
var src: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func groups(effects: Array) -> Array: return effects.filter(func(e):return e.type=="group").map(func(e):return e.group)
func roundtrip(s: Dictionary) -> Dictionary:
	var parsed=JSON.parse_string(JSON.stringify(s,"  ",true,true))
	if not State.validate(parsed,src).is_empty(): push_error("Rejected: "+State.validate(parsed,src));quit(1)
	return State.canonical(parsed)
func run() -> void:
	src=State.source()
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty() and roundtrip(s)==s and not s.present,"Initial differs"):return
	var e:=State.enter_region(s,src,1698)
	if not check(groups(e)==[3408,29396] and s.present and s.owner_state==2 and s.sound.request==333 and s.selector==4,"Region talk start differs: "+str(groups(e))):return
	if not check(e.any(func(x):return x.type=="reposition") and e.any(func(x):return x.type=="actor_reposition") and e.any(func(x):return x.type=="player_property" and x.property==0),"Talk start effects differ"):return
	var mid:=roundtrip(s)
	if not check(mid==s,"Mid-line rollback differs"):return
	var seen: Array=[]
	for i in range(30*12):
		seen.append_array(groups(State.advance(s,src,1.0/30.0)))
	# 29578 (state10, action2) → action2 clip end raises event3 (Grok 0xA56B3) → 29610: state11, action1, B5 0x0C, unblocked.
	if not check(seen==[29512,29534,29556,29578,29610] and s.owner_state==11 and s.sound.is_empty() and s.action==1 and s.b5==12 and s.anim.is_empty(),"Line chain differs: "+str(seen)):return
	# Re-entry links again but event20 is admitted only at state0.
	s.region=-1
	e=State.enter_region(s,src,1672)
	if not check(groups(e)==[3384] and s.owner_state==11,"Talk repeated"):return
	if not check(roundtrip(s)==s,"Final rollback differs"):return
	var bad: Array=[]
	var b1:=mid.duplicate(true);b1.owner_state=11;bad.append(b1)
	var b2:=mid.duplicate(true);b2.sound.request=325;bad.append(b2)
	var b3:=mid.duplicate(true);b3.sound={};bad.append(b3)
	var b4:=mid.duplicate(true);b4.locals["44"]=1;bad.append(b4)
	var b5:=mid.duplicate(true);b5.sound.elapsed=9.0;bad.append(b5)
	var b6:=mid.duplicate(true);b6.anim={"action":2,"elapsed":0.1};bad.append(b6)
	for packet in bad:
		if not check(not State.validate(packet,src).is_empty(),"Accepted malformed %d"%bad.find(packet)):return
	print("PASS: actor62 source state: region link + event20 (state0) → four original lines 333→325→258→243 by sound-finished chain (states2..5), player/actor reposition + talk focus, release at state10 → action2 clip end event3 → 29610 state11/action1/B5 0x0C/unblock; no repeat; mid-line rollback; talk-state/line mismatch, local44 and action-clip mismatch rejected")
	quit()
