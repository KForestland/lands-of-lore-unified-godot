extends RefCounted
## Huline Jungle alert-before-first-meeting Bacatta: prop553 (template84 talk movie) and actor65 (BACL4), from the
## pinned source groups (tools/prepare_jungle_bacatta65.py). Pure saved state; the controller supplies the producers
## (prop3235 sighting, region entry, E-use offers, hits) and presents effects. Shared globals are read from ctx.shared
## and written by the host ("shared" effects).
## Native bindings (static, LOLG.DAT):
## - ADDE0(list, value): kind6 records whose value byte matches; predicates evaluated when queued, groups run FIFO.
## - opcode5 (F2944) restarts the selector's one-resource frame run; its end raises kind3 value=selector.
## - opcode8 via B43EC: property2 loads AND starts (9EC7C + 113D24, repeat count = command word +6); property0 only
##   loads (9EC7C); property1 stops; property7 sets the running repeat count; property9/10 play one LIND segment.
## - Movie status 9EBFC/113BF0: a finished pass with repeat count left raises kind6 value1 (count decremented),
##   the final pass raises kind6 value0.
## - Creature opcode13 (A677A): sub13 sets B5 0x0C, sub7 clears bit1 (hostile); sub17 = A7544(actor,0), the actor's
##   own behaviour decision (no state written here: a linked non-hostile actor65 keeps its placement behaviour).
## - kind9: AE2C8 mode1, threshold byte8, wildcard masks, not one-shot. kind4: mode1 (any held item), first eligible.
## Adapters (deliberate, documented in docs/jungle-bacatta65.md):
## - property0 (walk-away group13102 only) plays its line once: native load-only would leave state32 waiting forever.
## - Clocks: VQA clip/segment durations from the staged media; timer ticks at 60/s on a 1/4096 s grid.
const SOURCE:="res://scripts/lol2/jungle_bacatta65_source.json"
const MEDIA:="res://assets/lol2/generated/jungle_bacatta65_media/media.json"
const EventTimer=preload("res://scripts/lol2/hive_event_timer.gd")
const PROP:=553
const ACTOR:=65
const STARTER:=3235
const MAX_ELAPSED:=120.0

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

## Durations per selector: whole clip = max(frames/fps, voice); segment = LIND span / fps; frame run = 1/fps.
static func timing(path: String=MEDIA) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var m=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not m is Dictionary or not m.get("clips") is Dictionary: return {}
	var t:={"clip":{},"frames":{},"segments":{}}
	for s in m.clips:
		var c: Dictionary=m.clips[s]
		t.clip[s]=float(c.duration);t.frames[s]=1.0/float(c.fps)
		t.segments[s]=c.segments.map(func(g): return float(g.duration))
	return t

static func initial(src: Dictionary) -> Dictionary:
	var locals:={}
	for n in src.owned_locals: locals[str(int(n))]=0
	var timers: Array=[]
	for row in src.timers: timers.append({"version":1,"flags":int(row.flags),"remaining":int(row.remaining)})
	return {"version":1,"locals":locals,"hold":false,"focus":false,"sighted":false,
		"prop":{"present":false,"state":0,"selector":0,"clip":{},"frames":{}},
		"actor":{"present":false,"b5":0},"timers":timers,"rng":1,"ticks":0.0}

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)==floorf(float(v)) and v>=lo and v<=hi
static func _clock(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v)) and v>=0 and v<=MAX_ELAPSED

## Values the pinned groups can write: prop owner states and selectors (op16/op5 on prop553), B5 masks.
static func reachable(src: Dictionary) -> Dictionary:
	var states: Array=[0];var selectors: Array=[0]
	for r in src.records:
		for c in r.commands:
			var b: PackedByteArray=str(c).hex_decode()
			if b.size()<5 or b[1]!=3 or b.decode_u16(2)!=PROP: continue
			if b[0]==16 and int(b[4]) not in states: states.append(int(b[4]))
			if b[0]==5 and int(b[4]) not in selectors: selectors.append(int(b[4]))
	return {"states":states,"selectors":selectors}

static func validate(s: Variant, src: Dictionary, t: Dictionary) -> String:
	if not s is Dictionary or s.size()!=initial(src).size() or not _int(s.get("version"),1,1): return "Invalid Bacatta65 version."
	if not s.get("locals") is Dictionary or s.locals.size()!=src.owned_locals.size(): return "Invalid Bacatta65 locals."
	for n in src.owned_locals:
		if not _int(s.locals.get(str(int(n))),0,255): return "Invalid Bacatta65 local."
	for k in ["hold","focus","sighted"]:
		if not s.get(k) is bool: return "Invalid Bacatta65 latch."
	var reach:=reachable(src)
	var p=s.get("prop")
	if not p is Dictionary or p.size()!=5 or not p.get("present") is bool or not _int(p.get("state"),0,255) or int(p.state) not in reach.states or not _int(p.get("selector"),0,255) or int(p.selector) not in reach.selectors:
		return "Invalid Bacatta65 prop."
	if not p.get("clip") is Dictionary or not p.get("frames") is Dictionary: return "Invalid Bacatta65 playback."
	if not p.frames.is_empty():
		if not p.present or p.frames.size()!=2 or not _int(p.frames.get("selector"),0,255) or int(p.frames.selector)!=int(p.selector) or not _clock(p.frames.get("elapsed")): return "Invalid Bacatta65 frame run."
	if not p.clip.is_empty():
		var c: Dictionary=p.clip
		if t.is_empty(): return "Bacatta65 media missing (run tools/prepare_jungle_bacatta65_media.py)."
		if not p.present or c.size()!=4 or not _int(c.get("selector"),0,255) or not t.clip.has(str(int(c.selector))) or not _int(c.get("segment"),-1,255) or not _int(c.get("passes"),0,65535) or not _clock(c.get("elapsed")):
			return "Invalid Bacatta65 clip."
		if int(c.segment)>=t.segments[str(int(c.selector))].size() or float(c.elapsed)>_length(t,c): return "Invalid Bacatta65 clip clock."
	var a=s.get("actor")
	if not a is Dictionary or a.size()!=2 or not a.get("present") is bool or not _int(a.get("b5"),0,255) or (int(a.b5)&~13)!=0: return "Invalid Bacatta65 actor."
	if not s.get("timers") is Array or s.timers.size()!=src.timers.size(): return "Invalid Bacatta65 timers."
	for timer in s.timers:
		if EventTimer.restore(timer).has("error"): return "Invalid Bacatta65 timer."
	if not _int(s.get("rng"),0,4294967295): return "Invalid Bacatta65 timer seed."
	var ticks=s.get("ticks")
	if not (ticks is float or ticks is int) or not is_finite(float(ticks)) or ticks<0 or ticks>=1: return "Invalid Bacatta65 tick clock."
	return ""

## JSON loads every number as float: restore integer fields so checkpoints compare exactly.
static func canonical(s: Dictionary) -> Dictionary:
	var r: Dictionary=s.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks=float(r.ticks)
	for k in r.locals: r.locals[k]=int(r.locals[k])
	r.prop.state=int(r.prop.state);r.prop.selector=int(r.prop.selector)
	if not r.prop.frames.is_empty(): r.prop.frames={"selector":int(r.prop.frames.selector),"elapsed":float(r.prop.frames.elapsed)}
	if not r.prop.clip.is_empty():
		var c: Dictionary=r.prop.clip
		r.prop.clip={"selector":int(c.selector),"segment":int(c.segment),"passes":int(c.passes),"elapsed":float(c.elapsed)}
	r.actor.b5=int(r.actor.b5)
	for i in range(r.timers.size()): r.timers[i]=EventTimer.restore(r.timers[i]).checkpoint
	return r

static func hostile(s: Dictionary) -> bool: return bool(s.actor.present) and (int(s.actor.b5)&12)!=0 and (int(s.actor.b5)&1)==0
static func talking(s: Dictionary) -> bool: return bool(s.prop.present) and int(s.locals["2"]) in [1,3]
## Player hold (0x26) applies while a spoken line runs; idle selectors (BC08) leave the player free to offer,
## strike or walk away, which the source's offer/hit/walk-away records require.
static func movement_locked(s: Dictionary, src: Dictionary) -> bool:
	return bool(s.hold) and bool(s.prop.present) and int(s.prop.selector) not in src.idle_selectors.map(func(v): return int(v))

static func _length(t: Dictionary, c: Dictionary) -> float:
	var key:=str(int(c.selector))
	return float(t.clip[key]) if int(c.segment)<0 else float(t.segments[key][int(c.segment)])

## ---- producers -------------------------------------------------------------------------------------------
## prop3235 kind5 value0 (first eligible sighting, F6C87 as for prop552); latched only when a record is admitted.
static func sighted(s: Dictionary, src: Dictionary, t: Dictionary, ctx: Dictionary) -> Array:
	if s.sighted: return []
	var queue:=_records(s,src,"prop",STARTER,5,0,ctx)
	if queue.is_empty(): return []
	s.sighted=true
	return _run(s,src,t,queue,ctx)

static func enter_region(s: Dictionary, src: Dictionary, t: Dictionary, region: int, ctx: Dictionary) -> Array:
	return _run(s,src,t,_records(s,src,"region",region,2,0,ctx),ctx)

## kind4 mode1: any held item, first eligible record (predicates are the prop owner state).
static func offer(s: Dictionary, src: Dictionary, t: Dictionary, held: bool, ctx: Dictionary) -> Array:
	if not held or not s.prop.present: return []
	for r in src.records:
		if str(r.owner_kind)!="prop" or int(r.owner)!=PROP or int(r.kind)!=4: continue
		if r.predicate!=null and not _test(s,src.predicates[str(int(r.predicate))],ctx): continue
		return _run(s,src,t,[r],ctx)
	return []

## kind9 AE2C8 mode1 on prop553: wildcard masks, admitted when damage >= threshold; all matching records queue.
static func hit(s: Dictionary, src: Dictionary, t: Dictionary, damage: int, ctx: Dictionary) -> Array:
	if not s.prop.present or damage<=0: return []
	var queue: Array=[]
	for r in _records(s,src,"prop",PROP,9,0,ctx):
		if damage>=int(str(r.raw).hex_decode()[8]): queue.append(r)
	return _run(s,src,t,queue,ctx)

## Clocks: frame runs (kind3), clip passes (kind6 value1/value0), the prop553 timer (kind2 group12438).
static func advance(s: Dictionary, src: Dictionary, t: Dictionary, delta: float, ctx: Dictionary) -> Array:
	if not is_finite(delta) or delta<=0.0 or t.is_empty(): return []
	var effects: Array=[]
	var total:=float(s.ticks)+delta*60.0;var ticks:=int(floorf(total));s.ticks=snappedf(total-ticks,1.0/4096)
	if s.ticks>=1.0: s.ticks=0.0
	for i in range(src.timers.size()):
		var row: Dictionary=src.timers[i]
		var result:=EventTimer.advance_with_rng(s.timers[i],ticks,s.rng,int(row.range[0]),int(row.range[1]),60)
		s.timers[i]=result.checkpoint;s.rng=int(result.rng)
		if not result.fired: continue
		# The kind2 record of this timer (group12438, predicate222 state==16), tested when it fires.
		var fired: Array=src.records.filter(func(r): return str(r.owner_kind)=="prop" and int(r.kind)==2 and int(r.group)==int(row.group))
		fired=fired.filter(func(r): return r.predicate==null or _test(s,src.predicates[str(int(r.predicate))],ctx))
		effects.append_array(_run(s,src,t,fired,ctx))
	var f: Dictionary=s.prop.frames
	if not f.is_empty():
		f.elapsed=minf(float(f.elapsed)+delta,MAX_ELAPSED)
		if float(f.elapsed)>=float(t.frames.get(str(int(f.selector)),0.0)):
			s.prop.frames={}
			effects.append_array(_dispatch(s,src,t,"prop",PROP,3,int(f.selector),ctx))
	var c: Dictionary=s.prop.clip
	if not c.is_empty():
		c.elapsed=minf(float(c.elapsed)+delta,MAX_ELAPSED)
		var length:=_length(t,c)
		if float(c.elapsed)>=length:
			if int(c.passes)>0:
				c.passes=int(c.passes)-1;c.elapsed=minf(float(c.elapsed)-length,length)
				effects.append({"type":"clip_wrap","selector":int(c.selector),"segment":int(c.segment)})
				effects.append_array(_dispatch(s,src,t,"prop",PROP,6,1,ctx))
			else:
				s.prop.clip={}
				effects.append_array(_dispatch(s,src,t,"prop",PROP,6,0,ctx))
	return effects

## ---- interpreter -------------------------------------------------------------------------------------------
static func _dispatch(s: Dictionary, src: Dictionary, t: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	return _run(s,src,t,_records(s,src,kind,owner,record,value,ctx),ctx)

static func _records(s: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: int, ctx: Dictionary) -> Array:
	var out: Array=[]
	for r in src.records:
		if str(r.owner_kind)!=kind or int(r.owner)!=owner or int(r.kind)!=record or (int(r.value)&255)!=(value&255): continue
		if r.predicate!=null and not _test(s,src.predicates[str(int(r.predicate))],ctx): continue
		out.append(r)
	return out

static func _operand(s: Dictionary, o: Dictionary, ctx: Dictionary) -> int:
	if o.has("immediate"): return int(o.immediate)
	if o.has("owner_state"): return int(s.prop.state)
	if o.has("local"): return int(s.locals.get(str(int(o.local)),ctx.get("locals",{}).get(str(int(o.local)),0)))
	if o.has("shared"): return int(ctx.get("shared",{}).get(str(int(o.shared)),0))
	if o.has("expression"): return 1 if _test(s,o.expression,ctx) else 0
	return 0

static func _test(s: Dictionary, p: Dictionary, ctx: Dictionary) -> bool:
	var a:=_operand(s,p.left,ctx);var b:=_operand(s,p.right,ctx)
	match str(p.op):
		"==": return a==b
		"!=": return a!=b
		"<=": return a<=b
		">=": return a>=b
		">": return a>b
		"<": return a<b
		"AND": return a!=0 and b!=0
		"OR": return a!=0 or b!=0
	return false

static func _run(s: Dictionary, src: Dictionary, t: Dictionary, queue: Array, ctx: Dictionary) -> Array:
	var effects: Array=[];var guard:=0
	queue=queue.duplicate()
	while not queue.is_empty() and guard<64:
		guard+=1
		var r: Dictionary=queue.pop_front()
		effects.append({"type":"group","owner_kind":str(r.owner_kind),"owner":int(r.owner),"group":int(r.group)})
		for raw in r.commands: _command(s,src,t,str(raw).hex_decode(),queue,effects,ctx)
	return effects

static func _start(s: Dictionary, t: Dictionary, segment: int, passes: int, effects: Array) -> void:
	var key:=str(int(s.prop.selector))
	if not t.clip.has(key) or segment>=t.segments[key].size(): return
	s.prop.clip={"selector":int(s.prop.selector),"segment":segment,"passes":passes,"elapsed":0.0}
	effects.append({"type":"clip_start","selector":int(s.prop.selector),"segment":segment,"passes":passes})

static func _command(s: Dictionary, src: Dictionary, t: Dictionary, b: PackedByteArray, queue: Array, effects: Array, ctx: Dictionary) -> void:
	var op:=b[0];var target:=b.decode_u16(2) if b.size()>=4 else 0
	var on_prop:=b.size()>=4 and b[1]==3 and target==PROP
	var on_actor:=b.size()>=4 and b[1]==2 and target==ACTOR
	match op:
		198:
			if s.locals.has(str(b[4])): s.locals[str(b[4])]=int(b[5])
			else: effects.append({"type":"local","local":int(b[4]),"value":int(b[5])})
		199, 206:
			effects.append({"type":"shared","index":int(b[4]),"op":"set" if op==199 else "add","value":int(b[5]) if op==199 or b[5]<128 else int(b[5])-256})
		16:
			if on_prop: s.prop.state=int(b[4])
			else: effects.append({"type":"external","raw":b.hex_encode()})
		5:
			if not on_prop: effects.append({"type":"external","raw":b.hex_encode()});return
			s.prop.selector=int(b[4])
			s.prop.frames={"selector":int(b[4]),"elapsed":0.0}
			effects.append({"type":"selector","selector":int(b[4])})
		8:
			if not on_prop: effects.append({"type":"external","raw":b.hex_encode()});return
			match b[4]:
				0:
					if s.prop.clip.is_empty(): _start(s,t,-1,0,effects)  # adapter: see header
				1:
					if not s.prop.clip.is_empty(): s.prop.clip={};effects.append({"type":"clip_stop"})
				2: _start(s,t,-1,b.decode_u16(6) if b.size()>=8 else 0,effects)
				7:
					if not s.prop.clip.is_empty(): s.prop.clip.passes=b.decode_u16(6)
				9, 10:
					var passes:=int(s.prop.clip.passes) if not s.prop.clip.is_empty() else 0
					_start(s,t,b.decode_u16(6),passes,effects)
				_: effects.append({"type":"external","raw":b.hex_encode()})
		9:
			if on_prop and b[4] in [2,3]:
				var present:=b[4]==3
				if bool(s.prop.present)!=present:
					s.prop.present=present
					if not present: s.prop.clip={};s.prop.frames={}
					effects.append({"type":"prop_presence","present":present})
			elif on_prop and b[4]==21:
				queue.append_array(_records(s,src,"prop",PROP,6,20,ctx))
			elif on_actor and b[4] in [2,3]:
				var present:=b[4]==3
				if bool(s.actor.present)!=present:
					s.actor.present=present
					if not present: s.actor.b5=0
					effects.append({"type":"actor_presence","present":present})
			else: effects.append({"type":"external","raw":b.hex_encode()})
		13:
			if not on_actor: effects.append({"type":"external","raw":b.hex_encode()});return
			match b[4]:
				7: s.actor.b5=int(s.actor.b5)&254
				13: s.actor.b5=(int(s.actor.b5)&243)|12
				17: effects.append({"type":"actor_behaviour"})
				_: effects.append({"type":"external","raw":b.hex_encode()})
		14:
			if not on_prop: effects.append({"type":"external","raw":b.hex_encode()});return
			var index:=int(b[6])
			if index>=s.timers.size(): return
			match b[4]:
				3: s.timers[index].flags=int(s.timers[index].flags)&254
				4: s.timers[index]=EventTimer.stop(s.timers[index]).checkpoint
				_: effects.append({"type":"external","raw":b.hex_encode()})
		2:
			if b[1]==1 and b[4] in [0x26,0x27]:
				s.hold=b[4]==0x26;effects.append({"type":"hold","held":s.hold})
			elif on_prop and b[4] in [5,6]:
				s.focus=b[4]==5;effects.append({"type":"focus","held":s.focus})
			else: effects.append({"type":"external","raw":b.hex_encode()})
		18:
			if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)]})
			else: effects.append({"type":"external","raw":b.hex_encode()})
		_: effects.append({"type":"external","raw":b.hex_encode()})
