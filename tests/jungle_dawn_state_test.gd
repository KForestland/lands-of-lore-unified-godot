extends SceneTree
## Dawn63 source-state fixture (supplied story context; not an earned route).
const State=preload("res://scripts/lol2/jungle_dawn_state.gd")
const WAX:=0xb45b2813
var src: Dictionary
var media: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func ctx(runes: int=1) -> Dictionary: return {"shared":{"0":5,"9":runes,"10":0,"12":1,"40":0},"locals":{}}
func groups(effects: Array) -> Array: return effects.filter(func(e):return e.type=="group").map(func(e):return e.group)
func has(effects: Array, type: String, key: String="", value: Variant=null) -> bool:
	return effects.any(func(e):return e.type==type and (key=="" or e.get(key)==value))
func shared(effects: Array, index: int) -> Array:
	return effects.filter(func(e):return e.type=="shared" and e.index==index).map(func(e):return [e.op,e.value])
func enter(s: Dictionary, region: int, c: Dictionary) -> Array:
	s.region=-1
	return State.enter_region(s,src,region,c)
## Run the current segment to its end (plus timers) and return everything emitted.
func finish(s: Dictionary, c: Dictionary, limit: float=60.0) -> Array:
	var all: Array=[]
	var start: Dictionary=s.clip.duplicate()
	for i in range(int(limit*30)):
		all.append_array(State.advance(s,src,media,1.0/30.0,c))
		if s.clip!=start and (s.clip.is_empty() or s.clip.segment!=start.segment or float(s.clip.elapsed)<float(start.elapsed)): break
	return all
func roundtrip(s: Dictionary) -> Dictionary:
	var parsed=JSON.parse_string(JSON.stringify(s,"  ",true,true))
	if not State.validate(parsed,src,media).is_empty(): push_error("Roundtrip rejected: "+State.validate(parsed,src,media));quit(1)
	return State.canonical(parsed)
func talked() -> Dictionary:
	var s:=State.initial(src)
	enter(s,2812,ctx());State.sight(s,src,ctx());enter(s,2842,ctx())
	finish(s,ctx());finish(s,ctx());finish(s,ctx()) # seg1 → seg2 → seg3 → waiting (state3, idle loop)
	return s
func run() -> void:
	src=State.source();media=State.media()
	var s:=State.initial(src)
	if not check(State.validate(s,src,media).is_empty() and roundtrip(s)==s and not s.present,"Initial differs"):return
	# Spawn needs the runes (pred159).
	if not check(enter(s,2812,ctx(0)).is_empty() and not s.present,"Spawned without runes"):return
	var e:=enter(s,2812,ctx())
	if not check(groups(e)==[5214] and s.present and has(e,"player_property","property",0x3c) and has(e,"player_property","property",0x25),"Spawn differs"):return
	e=State.sight(s,src,ctx())
	if not check(groups(e)==[29646] and s.selector==10 and s.loaded and s.clip.segment==0 and s.clip.repeat,"Sighting idle differs"):return
	if not check(State.sight(s,src,ctx()).is_empty(),"Sighting repeated"):return
	# The idle loop wraps without an end event.
	for i in range(300): State.advance(s,src,media,1.0/30.0,ctx())
	if not check(s.owner_state==0 and s.clip.segment==0,"Idle loop advanced the talk"):return
	# Region2842: local19, hold 0x26, talk-focus property5, reposition, seg1.
	e=enter(s,2842,ctx())
	if not check(groups(e)==[5246] and s.locals["19"]==1 and s.clip.segment==1 and not s.clip.repeat and has(e,"player_property","property",0x26) and has(e,"actor_property","property",5) and has(e,"reposition"),"Talk start differs: "+str(groups(e))):return
	var mid:=roundtrip(s)
	if not check(mid==s,"Mid-talk JSON rollback differs"):return
	e=finish(s,ctx())
	if not check(groups(e)==[29682,29864] and s.owner_state==1 and s.clip.segment==2,"Seg1 end differs: "+str(groups(e))):return
	e=finish(s,ctx())
	if not check(groups(e)==[29682,29898] and s.owner_state==20 and s.clip.segment==3,"Seg2 end differs"):return
	e=finish(s,ctx())
	if not check(groups(e)==[29682,30134] and s.owner_state==3 and s.clip.segment==0 and s.clip.repeat and (int(s.timers[0].flags)&1)==0,"Seg3 end differs: "+str(groups(e))):return
	# Offers: empty hand none; wax first (mode3) → rewards, consume, timers off, seg6.
	var w:=s.duplicate(true)
	if not check(State.offer(w,src,0,ctx()).is_empty(),"Empty hand admitted"):return
	e=State.offer(w,src,WAX,ctx())
	if not check(groups(e)==[29704] and shared(e,0)==[["add",2]] and shared(e,12)==[["add",1]] and shared(e,10)==[["set",1]] and w.locals["17"]==1,"Wax rewards differ: "+str(e)):return
	if not check(has(e,"player_property","property",0x0b) and has(e,"player_property","property",0x0c) and has(e,"player_property","property",0x18) and (int(w.timers[0].flags)&1)==1 and (int(w.timers[1].flags)&1)==1 and w.clip.segment==6,"Wax offer effects differ"):return
	e=finish(w,ctx());if not check(w.owner_state==4 and w.clip.segment==7,"Wax seg6 end differs"):return
	e=finish(w,ctx());if not check(w.owner_state==10 and w.clip.segment==8,"Seg7 end differs"):return
	e=finish(w,ctx())
	if not check(groups(e)==[29682,30230] and not w.present and shared(e,12)==[["add",1]] and has(e,"player_property","property",0x27) and has(e,"player_property","property",0x24),"Wax farewell differs: "+str(groups(e))):return
	# Other held items: mode1 fallbacks by local25 (seg4, then seg5).
	var o:=s.duplicate(true)
	e=State.offer(o,src,0x12345678,ctx())
	if not check(groups(e)==[30066] and o.locals["25"]==1 and o.clip.segment==4,"First other-item differs"):return
	var o2:=o.duplicate(true);o2.clip={}
	e=State.offer(o2,src,0x12345678,ctx())
	if not check(groups(e)==[30100] and o2.locals["25"]==2 and o2.clip.segment==5,"Second other-item differs"):return
	# Waiting too long: timer0 → seg9/state6 → seg10/state30 → timer1 → seg11/state8 → departure without rewards.
	var t:=s.duplicate(true)
	var seen: Array=[]
	for i in range(30*120):
		var step:=State.advance(t,src,media,1.0/30.0,ctx())
		seen.append_array(groups(step))
		if not t.present: break
	if not check(seen.has(29932) and seen.has(29982) and seen.has(30162) and seen.has(30016) and seen.has(30190) and not t.present,"Timed departure differs: "+str(seen)):return
	if not check(State.validate(t,src,media).is_empty(),"Departed state invalid"):return
	# Hit (one-shot, local26 gate): soul-1, Dawn-1, state40, seg12 → hostile with her own item; latched.
	var h:=s.duplicate(true)
	e=State.hit(h,src,2,4,3,ctx())
	if not check(groups(e)==[30266] and shared(e,0)==[["add",-1]] and shared(e,12)==[["add",-1]] and h.owner_state==40 and h.locals["26"]==1 and h.clip.segment==12 and h.health==197,"Hit differs: "+str(e)):return
	if not check(State.hit(h,src,2,4,3,ctx()).filter(func(x):return x.type=="group").is_empty(),"Hit latch did not hold"):return
	e=finish(h,ctx())
	if not check(groups(e)==[30324] and h.owner_state==50 and (h.b5&12)==12 and (h.b5&1)==0 and h.items==["43f8bc0d"] and not h.loaded and h.clip.is_empty(),"Hostile turn differs: "+str(groups(e))):return
	if not check(roundtrip(h)==h,"Hostile JSON rollback differs"):return
	# Malformed and unreachable packets.
	var bad: Array=[]
	var b1:=mid.duplicate(true);b1.owner_state=2;bad.append(b1)
	var b2:=mid.duplicate(true);b2.clip.elapsed=99.0;bad.append(b2)
	var b3:=mid.duplicate(true);b3.items=["deadbeef"];bad.append(b3)
	var b4:=mid.duplicate(true);b4.hit_latches=[30266];bad.append(b4)
	var b5:=mid.duplicate(true);b5.b5=2;bad.append(b5)
	var b6:=mid.duplicate(true);b6.loaded=false;bad.append(b6)
	var b7:=mid.duplicate(true);b7.extra=1;bad.append(b7)
	var b8:=mid.duplicate(true);b8.ticks=1.0;bad.append(b8)
	for packet in bad:
		if not check(not State.validate(packet,src,media).is_empty(),"Accepted malformed packet %d"%bad.find(packet)):return
	print("PASS: Dawn63 source state: rune-gated spawn (revert form, transform off), first sighting idle loop (no end event), talk seg1 hold/focus/reposition → seg2 → seg3 → waiting; wax first-eligible: Soul+2 Dawn+1 GAVE_RUNES, XP 0B/0C, consume 18, timers off → seg6/7/8 → farewell Dawn+1 release; other items seg4 then seg5; timed departure via timers; one-shot hit Soul-1 Dawn-1 seg12 → hostile state50 with her own item 43f8bc0d; JSON rollback; malformed/unreachable rejected")
	quit()
