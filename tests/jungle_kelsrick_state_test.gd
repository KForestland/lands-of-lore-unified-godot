extends SceneTree
## Kelsrick64 source-state fixture (supplied story context; not an earned route).
const State=preload("res://scripts/lol2/jungle_kelsrick_state.gd")
var src: Dictionary
var media: Dictionary
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func ctx(local15: int=1) -> Dictionary:
	return {"shared":{"0":5,"11":0,"29":0},"locals":{"15":local15}}
func has(effects: Array, type: String, key: String="", value: Variant=null) -> bool:
	for e in effects:
		if e.type==type and (key=="" or e.get(key)==value): return true
	return false
func groups(effects: Array) -> Array: return effects.filter(func(e):return e.type=="group").map(func(e):return e.group)
func finish_clip(s: Dictionary, c: Dictionary) -> Array:
	var all: Array=[]
	for i in range(4000):
		var e:=State.advance(s,src,media,1.0/30.0,c);all.append_array(e)
		if s.clip.is_empty(): break
	return all
func roundtrip(s: Dictionary) -> Dictionary:
	var parsed=JSON.parse_string(JSON.stringify(s,"  ",true,true))
	assert(State.validate(parsed,src,media).is_empty())
	return State.canonical(parsed)
## Enter a region afresh (the state latches the current region to model entry edges).
func enter(s: Dictionary, region: int, c: Dictionary) -> Array:
	s.region=-1
	return State.enter_region(s,src,region,c)
func run() -> void:
	src=State.source();media=State.media()
	var s:=State.initial(src)
	if not check(State.validate(s,src,media).is_empty() and roundtrip(s)==s and s.present and s.items==["6-Fine longswd"],"Initial state differs"):return
	# Talk 1 needs the village gate speech (local15==1, pred176).
	if not check(enter(s,3567,ctx(0)).is_empty(),"Talk1 ran before the village speech"):return
	var e:=enter(s,3567,ctx())
	if not check(groups(e)==[7146,30632] and has(e,"player_property","property",0x26) and has(e,"reposition") and s.locals["8"]==1 and s.clip.selector==9 and s.clip.segment==1,"Talk1 start differs: "+str(groups(e))):return
	var mid:=roundtrip(s)
	if not check(mid==s,"Mid-clip JSON rollback differs"):return
	e=finish_clip(s,ctx())
	if not check(groups(e)==[30684] and has(e,"player_property","property",0x27) and has(e,"external"),"Talk1 end differs: "+str(groups(e))):return
	if not check(enter(s,3567,ctx()).is_empty(),"Talk1 repeated"):return
	# Region2750 (local6==0) → local8=3; talk2 at 3567 (pred172) plays E081E.
	e=enter(s,2750,ctx())
	if not check(s.locals["8"]==3 and s.owner_state==1,"Region2750 differs"):return
	e=enter(s,3567,ctx())
	if not check(groups(e)==[7194,30798] and s.clip.selector==11 and s.locals["8"]==4,"Talk2 start differs: "+str(groups(e))):return
	e=finish_clip(s,ctx())
	if not check(groups(e)==[30862] and s.locals["8"]==5,"Talk2 end differs"):return
	# Region3791 (local8==5) → owner2/local8=6; talk3 plays E080E, then talk4 plays E082E.
	enter(s,3791,ctx())
	if not check(s.owner_state==2 and s.locals["8"]==6,"Region3791 differs"):return
	e=enter(s,3567,ctx())
	if not check(groups(e)==[7242,30888] and s.clip.selector==10,"Talk3 start differs: "+str(groups(e))):return
	e=finish_clip(s,ctx())
	if not check(s.locals["8"]==8 and s.owner_state==3,"Talk3 end differs"):return
	e=enter(s,3567,ctx())
	if not check(groups(e)==[7140,30966] and s.clip.selector==12 and s.locals["8"]==9,"Talk4 start differs: "+str(groups(e))):return
	finish_clip(s,ctx())
	if not check(enter(s,3567,ctx()).is_empty(),"Talk4 repeated"):return
	# Held-item use (sole kind4 mode1): refusal segment2 at owner0 only; empty hand does nothing.
	var t:=State.initial(src)
	if not check(State.offer(t,src,false,ctx()).is_empty(),"Empty hand admitted"):return
	e=State.offer(t,src,true,ctx())
	if not check(groups(e)==[30710] and t.clip.selector==9 and t.clip.segment==2,"Held-item refusal differs"):return
	# Melee hit (context 2/4): record30456 (mask2 0x1F, pred31) → hostile state40, HULINE_ALERT, local52, segment3, then fight.
	t=State.initial(src)
	e=State.hit(t,src,2,4,10,ctx())
	if not check(groups(e).has(30456) and not groups(e).has(30402) and t.owner_state==40 and t.locals["52"]==1 and has(e,"shared","index",29) and t.clip.segment==3,"Melee hit differs: "+str(groups(e))):return
	e=finish_clip(t,ctx())
	if not check(groups(e)==[30756] and (t.b5&12)==12 and (t.b5&1)==0,"Hostile wake differs"):return
	if not check(State.hit(t,src,2,4,10,ctx()).filter(func(x):return x.type=="group").is_empty(),"Hit latch did not hold"):return
	# Hit type 0x60 (record30402): GV_KELSRICK_DEAD, A7544 death (op13 sub17), event11 lowers the soul.
	t=State.initial(src)
	e=State.hit(t,src,0,0x20,5,ctx())
	if not check(groups(e).has(30402) and groups(e).has(31122) and t.health==0 and has(e,"shared","index",11),"Type-0x60 hit differs: "+str(groups(e))):return
	if not check(e.any(func(x):return x.type=="shared" and x.index==0 and x.value==-1),"Death did not lower the soul"):return
	# Malformed packets.
	var good:=roundtrip(mid)
	var bad: Array=[]
	var b1:=good.duplicate(true);b1.version=2;bad.append(b1)
	var b2:=good.duplicate(true);b2.clip.elapsed=999.0;bad.append(b2)
	var b3:=good.duplicate(true);b3.items=[];bad.append(b3)
	var b4:=good.duplicate(true);b4.hit_latches=[1];bad.append(b4)
	var b5:=good.duplicate(true);b5.extra=1;bad.append(b5)
	# Unreachable values (Codex review): owner state 255, pose 0, health0 outside death pose, living death pose, stray B5 bit.
	var i0:=State.initial(src)
	var b6:=i0.duplicate(true);b6.owner_state=255;bad.append(b6)
	var b7:=i0.duplicate(true);b7.selector=0;bad.append(b7)
	var b8:=i0.duplicate(true);b8.health=0;bad.append(b8)
	var b9:=i0.duplicate(true);b9.selector=16;bad.append(b9)
	var b10:=i0.duplicate(true);b10.b5=2;bad.append(b10)
	for packet in bad:
		if not check(not State.validate(packet,src,media).is_empty(),"Accepted malformed packet "+str(bad.find(packet))):return
	print("PASS: Kelsrick64 source state: village-gated talk1 (E079E seg1, hold 0x26/release 0x27), region2750 → talk2 E081E, region3791 → talk3 E080E → talk4 E082E, no repeats; held-item refusal seg2, empty hand none; melee hit → hostile state40/HULINE_ALERT/seg3 → wake, latched; type-0x60 hit → KELSRICK_DEAD + A7544 death + soul-1; mid-clip JSON rollback; malformed and unreachable owner/pose/death/B5 rejected")
	quit()
