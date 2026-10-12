extends SceneTree
## Pinned Hive Dawn20/prop71 source state on its own clocks: RUNES-entry link admitted only under pred184 (evaluated
## at queue time), runes translated, talk segments 1→2→3 under hold, idle wait ended by the kind2 timer (segment7),
## mode1 offers (segments 4 then 5, then none), kind9 one-shot hit (soul/relationship −1, segment8, goals13/7),
## removal on a later entry (pred192), mid-talk JSON continuation and validation. No presentation claim.
const State=preload("res://scripts/lol2/hive_dawn20_state.gd")
var src: Dictionary
var m: Dictionary
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok
func clips(effects: Array, s: Dictionary) -> Array: return effects.filter(func(e): return e.type=="clip").map(func(e): return int(s.clip.get("segment",-1)))
func segments_played(s: Dictionary, ctx: Dictionary, seconds: float) -> Array:
	var out: Array=[]
	var last:=-1
	for i in int(seconds*30.0):
		State.advance(s,src,m,1.0/30.0,ctx)
		var seg:=int(s.clip.get("segment",-1))
		if seg!=last and seg>=0: out.append(seg)
		last=seg
	return out
func squash(a: Array) -> Array:
	var out: Array=[]
	for v in a:
		if out.is_empty() or out[-1]!=v: out.append(v)
	return out
func shared(effects: Array) -> Array: return effects.filter(func(e): return e.type=="shared").map(func(e): return [int(e.index),str(e.op),int(e.value)])
func props(effects: Array, type: String) -> Array: return effects.filter(func(e): return e.type==type).map(func(e): return int(e.property))

func run() -> void:
	src=State.source();m=State.media()
	if not check(src.groups.size()==16 and src.records.size()==13 and int(src.hit_group)==10024 and m.clip.segments.size()==13,"Source/media contract differs"):return
	var ctx:={"shared":{"9":1,"40":0},"locals":{}}
	var s:=State.initial(src)
	if not check(State.validate(s,src,m).is_empty() and not s.present,"Initial state differs"):return
	# Not attacked in the monastery: entry admits nothing.
	State.link(s,src,ctx)
	if not check(s.pending.is_empty() and State.run_link(s,src,ctx).filter(func(e): return e.type=="group").is_empty(),"Link admitted without GV_DAWN_ATTACKED_IN_MONASTERY"):return
	# Attacked, but runes copied only during this visit: predicate is evaluated at queue time (entry).
	ctx.shared["40"]=1;ctx.shared["9"]=0
	State.link(s,src,ctx);ctx.shared["9"]=1
	if not check(s.pending.is_empty(),"Link admitted before GV_HAS_RUNES at queue time"):return
	State.link(s,src,ctx)
	if not check(s.pending==[84],"Link queue differs: %s"%[s.pending]):return
	var e:=State.run_link(s,src,ctx)
	if not check(s.present and int(s.locals["31"])==1 and [14,"set",1] in shared(e) and s.items==["43f8bc0d"],"Link group84 differs: %s"%[shared(e)]):return
	if not check(0x26 in props(e,"player_property") and 5 in props(e,"actor_property") and int(s.owner_state)==1 and int(s.clip.segment)==1 and not s.clip.repeat,"Talk start differs"):return
	# Mid-talk JSON continuation.
	var played:=segments_played(s,ctx,15.0)
	var mid: Dictionary=State.canonical(JSON.parse_string(JSON.stringify(s)))
	if not check(State.validate(mid,src,m).is_empty() and mid==State.canonical(s),"Mid-talk round trip differs"):return
	played.append_array(segments_played(s,ctx,40.0))
	if not check(squash(played).slice(0,4)==[1,2,3,0] and int(s.owner_state)==5 and bool(s.clip.repeat) and int(s.clip.segment)==0,"Talk chain differs: %s state=%s"%[played,s.owner_state]):return
	var twin: Dictionary=mid.duplicate(true);var twin_played:=segments_played(twin,ctx,40.0)
	if not check(squash(twin_played).slice(-2)==[3,0] and int(twin.owner_state)==5,"Restored talk diverged: %s"%[twin_played]):return
	# Offers while she waits: any held item (mode1), local32 0 → segment4, 1 → segment5, then none.
	var o:=State.offer(s,src,1,ctx)
	if not check(int(s.clip.segment)==4 and int(s.locals["32"])==1 and int(s.owner_state)==6,"First offer differs"):return
	if not check(State.offer(s,src,0,ctx).is_empty(),"Empty hand admitted"):return
	segments_played(s,ctx,6.0)
	if not check(int(s.owner_state)==5 and bool(s.clip.repeat),"First offer did not return to the wait"):return
	State.offer(s,src,1,ctx);segments_played(s,ctx,9.0)
	if not check(int(s.locals["32"])==5 and int(s.owner_state)==5 and State.offer(s,src,1,ctx).is_empty(),"Second/third offer differs"):return
	# The bound kind2 timer ends her wait: focus cleared, segment7 once, then still (state5, no clip).
	var waited:=segments_played(s,ctx,25.0)
	if not check(7 in waited and s.clip.is_empty() and int(s.owner_state)==5,"Timer wait end differs: %s clip=%s"%[waited,s.clip]):return
	# Kind9 hit: one-shot, soul/relationship −1, release, segment8, then goals13/7 (hostile body, no attacks here).
	var h:=State.hit(s,src,2,4,3,ctx)
	if not check([0,"add",-1] in shared(h) and [12,"add",-1] in shared(h) and 0x27 in props(h,"player_property") and int(s.clip.segment)==8 and int(s.owner_state)==15,"Hit differs"):return
	if not check(State.hit(s,src,2,4,3,ctx).filter(func(x): return x.type=="group").is_empty(),"Hit not one-shot"):return
	segments_played(s,ctx,5.0)
	if not check(int(s.owner_state)==20 and not s.loaded and (int(s.b5)&12)!=0 and (int(s.b5)&1)==0,"Hit ending differs: state=%s b5=%s"%[s.owner_state,s.b5]):return
	# A later RUNES entry removes her (pred192 local31==1).
	State.link(s,src,ctx)
	if not check(s.pending==[126],"Removal queue differs"):return
	State.run_link(s,src,ctx)
	if not check(not s.present and s.clip.is_empty(),"Removal differs"):return
	# Region478 (group906, pred192 local31==1): inert before the link; afterwards unloads her clip (prop318 receipt).
	var r:=State.initial(src)
	if not check(State.enter_region(r,src,478,ctx).filter(func(x): return x.type=="group").is_empty(),"Region478 ran before the link"):return
	State.link(r,src,ctx);State.run_link(r,src,ctx);r.region=-1
	var u:=State.enter_region(r,src,478,ctx)
	if not check(not r.loaded and r.clip.is_empty() and u.any(func(x): return x.type=="external" and str(x.raw)=="09033e010a00"),"Region478 unload differs"):return
	if not check(State.enter_region(r,src,478,ctx).is_empty(),"Region478 repeated without leaving"):return
	# Validation.
	var b1:=mid.duplicate(true);b1.pending=[999]
	var b2:=mid.duplicate(true);b2.owner_state=10
	var b3:=mid.duplicate(true);b3.hit_latches=[30266]
	var b4:=mid.duplicate(true);b4.clip.segment=40
	for b in [b1,b2,b3,b4]:
		if not check(not State.validate(b,src,m).is_empty(),"Accepted malformed state"):return
	if failed: return
	print("PASS hive dawn20 state: pred184 at queue time (needs attacked+runes), link group84 (local31, GV_RUNES_TRANSLATED, item, hold), talk 1→2→3→idle, JSON continuation, offers 4/5/none, timer wait end 7, one-shot hit (soul/relationship −1, 8, goals13/7), later-entry removal, region478 unload (pred192, edge), validation.")
	quit()
