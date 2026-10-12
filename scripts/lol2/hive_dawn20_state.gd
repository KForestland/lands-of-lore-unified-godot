extends RefCounted
## Source Hive Dawn20 (L5_HC actor20, definition3 DAWNL4) and her link prop71. Same engine and effect vocabulary as
## jungle_dawn_state.gd (Dawn63): talk chain over E075E segments, kind2 timer, kind5 records (values 6/262, producer unbound),
## native first-eligible kind4 offers (two mode1 records: any held item), kind9 one-shot hit.
## Link: prop71 kind6/20 is raised by opcode9 prop71 property21 in the RUNES room entry (control0 group5244 and the
## region event1 groups). ADDE0 evaluates predicates when the event is queued, and queued groups run FIFO after the
## raising group (whose blocking room call returns first), so link() records the admitted groups and run_link()
## executes them when the room closes. The queue is saved.
## The host owns shared writes (GV_RUNES_TRANSLATED, soul, relationship), player properties and presentation.
## Clip ends are internal clocks only (no external presenter callback), so no stale-callback entry point exists.
## Adapters: segment clocks on a 1/4096 s grid; timer ticks at 60/s; timer RNG seeded per encounter (native RNG is global).
const SOURCE="res://scripts/lol2/hive_dawn20_source.json"
const MEDIA="res://assets/lol2/generated/hive_dawn20_media/media.json"
const EventTimer=preload("res://scripts/lol2/hive_event_timer.gd")
const ACTOR:=20
const PROP:=71
static func source() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func media() -> Dictionary:return JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
static func initial(src: Dictionary) -> Dictionary:
	var locals: Dictionary={}
	for n in src.owned_locals:locals[str(int(n))]=0
	var timers: Array=[]
	for t in src.timers:timers.append({"version":1,"flags":int(t.flags),"remaining":int(t.remaining)})
	return {"version":1,"present":bool(src.actor.present),"owner_state":0,"selector":0,"health":int(src.actor.health),"b5":0,"loaded":false,"repeat":false,
		"clip":{},"locals":locals,"timers":timers,"rng":1,"ticks":0.0,"sighted":false,"hit_latches":[],"region":-1,"items":[],"death":0.0,"pending":[]}
static func integer(v: Variant,lo: int,hi: int) -> bool:return (v is int or v is float) and is_finite(float(v)) and v==floor(float(v)) and v>=lo and v<=hi
## Values the pinned source can write to actor20: op16 owner states, op5/op13 sub4 selectors, op3 actor grants.
static func reachable(src: Dictionary) -> Dictionary:
	var states: Array=[0];var selectors: Array=[0];var items: Array=[]
	for g in src.groups:
		for c in g.commands:
			var b: PackedByteArray=str(c).hex_decode()
			if b.size()<6 or b[1]!=2 or b.decode_u16(2)!=ACTOR:continue
			if b[0]==16 and int(b[4]) not in states:states.append(int(b[4]))
			if (b[0]==5 or (b[0]==13 and b[4]==4)) and int(b[5] if b[0]==13 else b[4]) not in selectors:selectors.append(int(b[5] if b[0]==13 else b[4]))
			if b[0]==3 and b.size()>=8:items.append("%08x"%b.decode_u32(4))
	return {"states":states,"selectors":selectors,"items":items}
static func validate(s: Variant,src: Dictionary,m: Dictionary) -> String:
	if not s is Dictionary or s.size()!=initial(src).size() or not integer(s.get("version"),1,1):return "Invalid Dawn version."
	var reach:=reachable(src)
	if not integer(s.get("owner_state"),0,255) or int(s.owner_state) not in reach.states:return "Unreachable Dawn owner state."
	if not integer(s.get("selector"),0,255) or int(s.selector) not in reach.selectors:return "Unreachable Dawn selector."
	if not integer(s.get("b5"),0,255) or (int(s.b5)&~13)!=0:return "Unreachable Dawn B5."
	if not integer(s.get("health"),0,int(src.actor.health)) or not integer(s.get("rng"),0,4294967295) or not integer(s.get("region"),-1,65535):return "Invalid Dawn actor."
	for k in ["present","loaded","repeat","sighted"]:
		if not s.get(k) is bool:return "Invalid Dawn latch."
	if not s.get("locals") is Dictionary or s.locals.size()!=src.owned_locals.size():return "Invalid Dawn locals."
	for n in src.owned_locals:
		if not integer(s.locals.get(str(int(n))),0,255):return "Invalid Dawn local."
	if not s.get("timers") is Array or s.timers.size()!=src.timers.size():return "Invalid Dawn timers."
	for t in s.timers:
		if EventTimer.restore(t).has("error"):return "Invalid Dawn timer."
	var ticks=s.get("ticks")
	if not (ticks is float or ticks is int) or not is_finite(float(ticks)) or ticks<0 or ticks>=1:return "Invalid Dawn tick clock."
	if not s.get("hit_latches") is Array or s.hit_latches.size()>1 or s.hit_latches.any(func(n):return not integer(n,0,65535) or int(n)!=int(src.hit_group)):return "Invalid Dawn hit latch."
	var link_groups: Array=src.groups.filter(func(g):return g.owner_kind=="prop").map(func(g):return int(g.group))
	if not s.get("pending") is Array or s.pending.size()>link_groups.size() or s.pending.any(func(n):return not integer(n,0,65535) or int(n) not in link_groups):return "Invalid Dawn link queue."
	if not s.get("items") is Array or s.items.size()>1 or s.items.any(func(i):return not i is String or i not in reach.items):return "Invalid Dawn actor inventory."
	var death=s.get("death")
	if not (death is float or death is int) or not is_finite(float(death)) or death<0 or death>10 or (int(s.health)>0 and death!=0):return "Invalid Dawn death clock."
	var c=s.get("clip")
	if not c is Dictionary:return "Invalid Dawn clip."
	if not c.is_empty():
		if c.size()!=3 or not integer(c.get("segment"),0,m.clip.segments.size()-1) or not c.get("repeat") is bool:return "Invalid Dawn clip."
		var elapsed=c.get("elapsed")
		if not (elapsed is float or elapsed is int) or not is_finite(float(elapsed)) or elapsed<0 or elapsed>=float(m.clip.segments[int(c.segment)].duration):return "Invalid Dawn clip clock."
		if not s.loaded or not s.present or int(s.health)==0 or int(s.selector)!=int(src.selector):return "Dawn clip disagrees with actor."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true)
	for k in ["version","owner_state","selector","health","b5","rng","region"]:r[k]=int(r[k])
	r.ticks=float(r.ticks);r.death=float(r.death)
	for k in r.locals:r.locals[k]=int(r.locals[k])
	r.hit_latches=r.hit_latches.map(func(v):return int(v))
	r.pending=r.pending.map(func(v):return int(v))
	for i in range(r.timers.size()):r.timers[i]=EventTimer.restore(r.timers[i]).checkpoint
	if not r.clip.is_empty():r.clip={"segment":int(r.clip.segment),"elapsed":float(r.clip.elapsed),"repeat":bool(r.clip.repeat)}
	return r
static func operand(s: Dictionary,o: Dictionary,ctx: Dictionary) -> int:
	if o.has("immediate"):return int(o.immediate)
	if o.has("owner_state"):return int(s.owner_state)
	if o.has("local"):return int(s.locals.get(str(int(o.local)),ctx.get("locals",{}).get(str(int(o.local)),0)))
	if o.has("shared"):return int(ctx.get("shared",{}).get(str(int(o.shared)),0))
	if o.has("expression"):return int(predicate(s,o.expression,ctx))
	return 0
static func predicate(s: Dictionary,p: Dictionary,ctx: Dictionary) -> bool:
	var a:=operand(s,p.left,ctx);var b:=operand(s,p.right,ctx)
	match p.op:
		"==":return a==b
		"!=":return a!=b
		"<":return a<b
		">":return a>b
		"<=":return a<=b
		">=":return a>=b
		"AND":return a!=0 and b!=0
		"OR":return a!=0 or b!=0
	return false
static func groups_by_id(src: Dictionary,id: int) -> Array:return src.groups.filter(func(g):return int(g.group)==id)
## ADDE0: predicates are evaluated when queued (before any queued command runs); only the low event byte is compared.
static func select(s: Dictionary,src: Dictionary,kind: String,owner: int,event: int,value: int,ctx: Dictionary) -> Array:
	var queue: Array=[]
	for g in src.groups:
		if g.owner_kind!=kind or int(g.owner)!=owner or int(g.event)!=event or (int(g.value)&255)!=(value&255):continue
		if g.predicate!=null and not predicate(s,src.predicates[str(int(g.predicate))],ctx):continue
		queue.append(g)
	return queue
static func actor_event(s: Dictionary,src: Dictionary,event: int,ctx: Dictionary) -> Array:return run(s,src,select(s,src,"actor",ACTOR,6,event,ctx),ctx)
static func enter_region(s: Dictionary,src: Dictionary,region: int,ctx: Dictionary) -> Array:
	if int(s.region)==region:return []
	s.region=region
	return run(s,src,select(s,src,"region",region,2,0,ctx),ctx)
## Kind5 support: the host raises value0 on her first sighting (Dawn63's bound producer). Dawn20's own kind5 records
## carry values 6/262 (low byte 6), whose native producer is not bound, so a sighting admits none of them; her wait is
## ended by the bound kind2 timer (group9988). The latch is set only when a record is admitted.
static func sight(s: Dictionary,src: Dictionary,ctx: Dictionary,value: int=0) -> Array:
	if not s.present or s.sighted or int(s.health)==0:return []
	var queue:=select(s,src,"actor",ACTOR,5,value,ctx)
	if queue.is_empty():return []
	s.sighted=true
	return run(s,src,queue,ctx)
## RUNES room entry raised prop71 property21: queue the admitted kind6/20 groups now (ADDE0), run them on close.
static func link(s: Dictionary,src: Dictionary,ctx: Dictionary) -> void:
	for g in select(s,src,"prop",PROP,6,20,ctx):
		if int(g.group) not in s.pending:s.pending.append(int(g.group))
static func run_link(s: Dictionary,src: Dictionary,ctx: Dictionary) -> Array:
	var queue: Array=[]
	for id in s.pending:queue.append_array(groups_by_id(src,int(id)))
	s.pending=[]
	return run(s,src,queue,ctx)
## Native first eligible kind4 record: mode3 needs the exact held identity, mode1 any held item; empty hand admits none.
static func offer(s: Dictionary,src: Dictionary,identity: int,ctx: Dictionary) -> Array:
	if identity==0 or not s.present or int(s.health)==0:return []
	for r in src.records:
		if int(r.kind)!=4:continue
		var b: PackedByteArray=str(r.raw).hex_decode()
		var mode:=int(b[4])
		if not ((mode==1) or (mode==3 and b.decode_u32(6)==identity)):continue
		if r.predicate!=null and not predicate(s,src.predicates[str(int(r.predicate))],ctx):continue
		return run(s,src,groups_by_id(src,b.decode_u16(2)),ctx)
	return []
## Kind9 (src.hit_group): wildcard masks, threshold byte8 (1), one-shot bit7.
static func hit(s: Dictionary,src: Dictionary,mask0: int,mask2: int,damage: int,ctx: Dictionary) -> Array:
	if not s.present or int(s.health)<=0 or damage<=0:return []
	var queue: Array=[]
	for r in src.records:
		if int(r.kind)!=9:continue
		var b: PackedByteArray=str(r.raw).hex_decode();var group:=b.decode_u16(2)
		if group in s.hit_latches:continue
		if (b.decode_u16(4)!=0 and (mask0&b.decode_u16(4))==0) or (b.decode_u16(6)!=0 and (mask2&b.decode_u16(6))==0) or damage<int(b[8]):continue
		if r.predicate!=null and not predicate(s,src.predicates[str(int(r.predicate))],ctx):continue
		queue.append_array(groups_by_id(src,group))
		if b[9]&128:s.hit_latches.append(group)
	var effects:=run(s,src,queue,ctx)
	s.health=maxi(0,int(s.health)-damage)
	if int(s.health)==0:s.clip={};s.death=0.0;effects.append_array(actor_event(s,src,11,ctx))
	return effects
static func advance(s: Dictionary,src: Dictionary,m: Dictionary,delta: float,ctx: Dictionary) -> Array:
	if not is_finite(delta) or delta<=0 or not s.present:return []
	if int(s.health)==0:s.death=minf(10.0,snappedf(float(s.death)+delta,1.0/1024));return []
	var effects: Array=[]
	var total:=float(s.ticks)+delta*60.0;var ticks:=int(floorf(total));s.ticks=snappedf(total-ticks,1.0/4096)
	if s.ticks>=1.0:s.ticks=0.0
	for i in range(src.timers.size()):
		var row: Dictionary=src.timers[i]
		var result:=EventTimer.advance_with_rng(s.timers[i],ticks,s.rng,int(row.range[0]),int(row.range[1]),60)
		s.timers[i]=result.checkpoint;s.rng=int(result.rng)
		if not result.fired:continue
		if row.predicate!=null and not predicate(s,src.predicates[str(int(row.predicate))],ctx):continue
		effects.append_array(run(s,src,groups_by_id(src,int(row.group)),ctx))
	if s.clip.is_empty():return effects
	var c: Dictionary=s.clip;var duration:=float(m.clip.segments[int(c.segment)].duration)
	c.elapsed=snappedf(float(c.elapsed)+delta,1.0/4096)
	if c.elapsed<duration:return effects
	if c.repeat:
		# A looping segment wraps without an end event (the idle loop never advances the talk by itself).
		c.elapsed=fmod(float(c.elapsed),duration)
		return effects
	s.clip={}
	effects.append_array(actor_event(s,src,0,ctx))
	return effects
static func run(s: Dictionary,src: Dictionary,queue: Array,ctx: Dictionary) -> Array:
	var effects: Array=[];var guard:=0
	while not queue.is_empty() and guard<64:
		guard+=1;var g: Dictionary=queue.pop_front();effects.append({"type":"group","group":int(g.group)})
		for raw in g.commands:
			var b: PackedByteArray=str(raw).hex_decode();var target:=b.decode_u16(2);var own:=b[1]==2 and target==ACTOR
			match b[0]:
				198:
					if s.locals.has(str(b[4])):s.locals[str(b[4])]=int(b[5])
					else:effects.append({"type":"external","raw":raw})
				199,206:effects.append({"type":"shared","index":int(b[4]),"op":"set" if b[0]==199 else "add","value":int(b[5]) if b[0]==199 or b[5]<128 else int(b[5])-256})
				16:
					if own:s.owner_state=int(b[4])
					else:effects.append({"type":"external","raw":raw})
				5:
					if own:s.selector=int(b[4])
					else:effects.append({"type":"external","raw":raw})
				8:
					if not own:effects.append({"type":"external","raw":raw});continue
					match b[4]:
						0:s.loaded=true
						1:s.loaded=false;s.clip={}
						7:s.repeat=b.decode_u16(6)!=0
						9,10:
							if s.loaded:s.clip={"segment":int(b.decode_u16(6)),"elapsed":0.0,"repeat":bool(s.repeat)};effects.append({"type":"clip"})
				9:
					if not own:effects.append({"type":"external","raw":raw});continue
					match b[4]:
						2:s.present=false;s.clip={}
						3:s.present=true
						21:queue.append_array(select(s,src,"actor",ACTOR,6,20,ctx))
						_:effects.append({"type":"actor_property","property":int(b[4]),"raw":raw})
				14:
					if not own:effects.append({"type":"external","raw":raw});continue
					var index:=int(b[6])
					match b[4]:
						3:s.timers[index].flags=int(s.timers[index].flags)&254
						4:s.timers[index]=EventTimer.stop(s.timers[index]).checkpoint
						5:
							var row: Dictionary=src.timers[index]
							var draw:=EventTimer.draw_reload(s.rng,int(row.range[0]),int(row.range[1]),60)
							s.rng=int(draw.rng);s.timers[index].remaining=int(draw.reload)
				13:
					if not own:effects.append({"type":"external","raw":raw});continue
					match b[4]:
						4:s.selector=int(b[5])
						6:s.b5=int(s.b5)|1
						7:s.b5=int(s.b5)&254
						10:s.b5=int(s.b5)&243
						11:s.b5=int(s.b5)|4
						12:s.b5=int(s.b5)|8
						13:s.b5=(int(s.b5)&243)|12
						_:effects.append({"type":"actor_command","sub":int(b[4]),"raw":raw})
				18:
					if b[1]==1:effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":raw})
					else:effects.append({"type":"external","raw":raw})
				3:
					# Actor-directed grant (30324) stays Dawn's own inventory: never dropped loot without a producer.
					if own:
						var item:="%08x"%b.decode_u32(4)
						if item not in s.items:s.items.append(item)
					else:effects.append({"type":"external","raw":raw})
				2:
					if b[1]==1:effects.append({"type":"player_property","property":int(b[4]),"value":int(b[5]),"raw":raw})
					elif own:effects.append({"type":"actor_property","property":int(b[4]),"value":int(b[5]),"raw":raw})
					else:effects.append({"type":"external","raw":raw})
				_:effects.append({"type":"external","raw":raw})
	return effects
