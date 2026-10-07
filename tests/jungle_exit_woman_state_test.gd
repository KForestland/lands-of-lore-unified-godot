extends SceneTree
## Pinned prop554/L4WW source state driven by its own clip clocks (staged media durations): both
## Luther/speaker40 conversations, actor links, hold/release, local1 progression, kind9 mode4 hits,
## exit-spawn removal, generation-guarded callbacks (stale selector, restore, removal/relink) and
## mid-conversation JSON continuation. No presentation or earned-route claim.
const State=preload("res://scripts/lol2/jungle_exit_woman_state.gd")
var src: Dictionary
var t: Dictionary
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok
func starts(effects: Array, type: String="clip_start") -> Array:
	return effects.filter(func(e): return e.type==type).map(func(e): return int(e.selector))
func has(effects: Array, type: String, key: String="", value: Variant=null) -> bool:
	return effects.any(func(e): return e.type==type and (key=="" or e.get(key)==value))
func roundtrip(s: Dictionary) -> Dictionary:
	var restored: Dictionary=State.canonical(JSON.parse_string(JSON.stringify(s)))
	return restored if State.validate(restored,src).is_empty() else {}
## Runs the clocks in 1/30 s steps; returns all effects.
func play(s: Dictionary, seconds: float) -> Array:
	var all: Array=[]
	for i in int(ceil(seconds*30.0)): all.append_array(State.advance(s,src,t,1.0/30.0))
	return all

func run() -> void:
	src=State.source();t=State.timing()
	if not check(not t.is_empty() and src.records.size()==29 and src.regions.size()==5 and src.prop.selectors["6"]=="4040604E.VQA","Source/media contract differs"):return
	var s:=State.initial(src)
	if not check(State.validate(s,src).is_empty(),"Initial state invalid"):return
	var e:=State.sighted(s,src)
	if not check(starts(e)==[0] and s.prop.repeat and s.prop.state==1,"Sighting differs"):return
	if not check(play(s,5.0).is_empty() and not s.prop.clip.is_empty(),"World idle loop advanced the chain"):return
	e=State.enter_region(s,src,4387)
	if not check(has(e,"hold","held",true) and has(e,"reposition") and s.prop.selector==6 and s.local1==3 and s.prop.clip.is_empty() and int(s.prop.frames.selector)==6,"First meeting entry differs"):return
	# Lead reproducer: a stale selector15 callback while selector6 plays changes nothing.
	var before:=s.duplicate(true)
	if not check(State.selector_finished(s,src,15,int(s.prop.generation)).is_empty() and s==before,"Stale selector15 callback mutated state"):return
	if not check(State.selector_finished(s,src,6,int(s.prop.generation)-1).is_empty() and s==before,"Older-generation callback admitted"):return
	if not check(State.clip_ended(s,src,6,int(s.prop.generation)).is_empty() and s==before,"Wrong-track callback admitted"):return
	# Restore makes in-flight callbacks stale.
	var gen_before:=int(s.prop.generation)
	State.restored(s,gen_before)
	if not check(State.selector_finished(s,src,6,gen_before).is_empty() and int(s.prop.frames.generation)==int(s.prop.generation),"Pre-restore callback admitted"):return
	# Lead reproducer (repeated restore of one packet): with the owner's runtime high-water mark the
	# second restore resumes above every generation the first issued, including its later playback.
	var saved:=s.duplicate(true);var high:=int(s.prop.generation)
	var r1:=State.canonical(saved);State.restored(r1,high);high=maxi(high,int(r1.prop.generation))
	var g1:=int(r1.prop.frames.generation);var sel1:=int(r1.prop.frames.selector)
	play(r1,8.0);high=maxi(high,int(r1.prop.generation))
	var later:=int(r1.prop.generation)
	var r2:=State.canonical(saved);State.restored(r2,high)
	var r2_before:=r2.duplicate(true)
	if not check(int(r2.prop.generation)>later and State.selector_finished(r2,src,sel1,g1).is_empty() and State.clip_ended(r2,src,int(r1.prop.clip.get("selector",0)),later).is_empty() and r2==r2_before,"Repeated restore admitted a callback from the earlier presentation"):return
	# Exhaustion fails closed instead of wrapping into reused generations.
	var x2:=State.canonical(saved);State.restored(x2,State.MAX_GENERATION)
	var x2_before:=x2.duplicate(true)
	if not check(int(x2.prop.generation)==State.MAX_GENERATION and State.selector_finished(x2,src,6,State.MAX_GENERATION).is_empty() and x2==x2_before,"Generation wrap reused or admitted"):return
	# Native op5 (F2944) frame run is one template frame: the voiced line follows within two clock steps,
	# so each meeting's first line is presented once (no silent full-length pre-run).
	if not check(float(t.frames["6"])<=0.1 and has(e,"focus","held",true) and s.focus,"Op5 frame run/op2 focus differs"):return
	var probe:=s.duplicate(true);var lead: Array=[]
	for i in 2: lead.append_array(starts(State.advance(probe,src,t,1.0/30.0)))
	if not check(lead==[6],"Voiced first line did not follow the one-frame run: %s"%[lead]):return
	var first: Array=[]
	var mid:={}
	for i in 2000:
		if not s.prop.present: break
		if s.prop.state==5 and mid.is_empty(): mid=s.duplicate(true)
		first.append_array(starts(State.advance(s,src,t,1.0/30.0)))
	if not check(first==[6,15,8,7,14,13,9,0],"First conversation order differs: %s"%[first]):return
	if not check(not s.prop.present and s.actors["0"].present and not s.hold and not s.focus and s.local1==3,"First conversation outcome differs"):return
	var restored:=roundtrip(mid)
	if not check(not restored.is_empty() and restored==State.canonical(mid),"Mid-conversation round trip differs"):return
	var replay: Array=[]
	for i in 2000:
		if not restored.prop.present: break
		replay.append_array(starts(State.advance(restored,src,t,1.0/30.0)))
	if not check(replay.slice(-4)==[14,13,9,0] and restored.actors["0"].present and restored.local1==3,"Restored conversation diverged: %s"%[replay]):return
	if not check(has(State.actor_event(s,src,0,6,8),"remove","actor",0),"Actor0 removal differs"):return
	# Second meeting; a removal/relink makes the old playback's callbacks stale.
	State.enter_region(s,src,4407)
	e=State.enter_region(s,src,1902)
	var relink_gen:=int(s.prop.generation)
	if not check(s.local1==1 and s.prop.present and starts(e)==[0],"Second-meeting relink differs"):return
	e=State.enter_region(s,src,4387)
	if not check(int(s.prop.frames.selector)==5 and s.local1==4 and s.hold and State.clip_ended(s,src,0,relink_gen).is_empty(),"Second meeting entry differs"):return
	var second: Array=[]
	for i in 3000:
		if not s.prop.present: break
		second.append_array(starts(State.advance(s,src,t,1.0/30.0)))
	if not check(second==[5,4,12,11,10,3,2,1,16] and s.actors["66"].present and not s.hold and not s.focus,"Second conversation differs: %s"%[second]):return
	# Hits: threshold2 mode4, one-shot.
	var h:=State.initial(src);State.sighted(h,src);State.enter_region(h,src,4387);play(h,3.0)
	if not check(State.hit(h,src,{"after":3}).is_empty() and h.prop.present,"Hit above threshold admitted"):return
	State.hit(h,src,{"after":2})
	var stale:=int(h.prop.generation)-1
	if not check(h.actors["0"].present and not h.prop.present and h.local1==2 and not h.hold and h.latches.size()==1 and State.clip_ended(h,src,15,stale).is_empty(),"First-conversation hit differs"):return
	# Exit guard spawn removes prop554 and blocks both meetings.
	var x:=State.initial(src);State.sighted(x,src)
	State.external_commands(x,src,src.external["1:10720"])
	if not check(x.local1==5 and not x.prop.present and x.prop.clip.is_empty() and State.enter_region(x,src,4387).is_empty() and State.enter_region(x,src,1902).is_empty(),"Exit spawn removal differs"):return
	# Validation.
	var b1:=s.duplicate(true);b1.prop.selector=17
	var b2:=mid.duplicate(true);b2.prop.clip.generation=int(b2.prop.generation)+1
	var b3:=mid.duplicate(true);b3.prop.clip.elapsed=-1
	var b4:=s.duplicate(true);b4.latches=[123]
	for b in [b1,b2,b3,b4]:
		if not check(not State.validate(b,src).is_empty(),"Accepted malformed state"):return
	if failed: return
	print("PASS jungle exit woman state: clocked conversations [6,15,8,7,14,13,9,0]→actor0 and [5,4,12,11,10,3,2,1,16]→actor66, hold/release, local1 0→3→1→4, relink, mode4 one-shot hit, exit removal; stale selector/generation/track/restore/relink callbacks rejected without mutation; mid-conversation JSON continuation; op5 one-frame run, op2 p5/p6 focus, first line once; repeated-restore high-water, no generation wrap.")
	quit()
