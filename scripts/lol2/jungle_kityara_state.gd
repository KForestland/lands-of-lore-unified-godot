extends RefCounted
## Pure state of Kityara's Jungle follow-up from the pinned contract (tools/prepare_jungle_kityara.py →
## jungle_kityara_source.json): controls 0/83 (her two locations, original E066E.VQA segments), props 64/67 (dropped
## knife) and 65/66 (knife givers with their kind2 fallback timer).
## Owns local21 Has_Kityara_been_triggered plus control/prop/timer state. Locals 23/35/41/54 belong to the existing
## weapon-shop room bank (by source name) and leave as "shop_local" effects; shared globals leave as "shared" effects.
## Source chain: presence regions link (p150/p151) or unlink a control; a start region (p151: local21==0, local35==1,
## runes translated, not dead) sets local21, starts the timer prop, holds Luther and plays segment1. The segment end
## (owner state0) or the 19 s timer raises prop65/66 event20: local41 kityara_gave_knife=1, prop state1 and the
## definition29 grant, once. Offers (exact held identity, first eligible), hits and the leave/death groups follow source.
## Commands without a port owner are kept as saved receipts.
const SOURCE:="res://scripts/lol2/jungle_kityara_source.json"
const EventTimer=preload("res://scripts/lol2/hive_event_timer.gd")
const TICKS:=60
const MAX_RECEIPTS:=48
const CONTROLS:=["0","83"]
const PROPS:=["64","65","66","67"]

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

static func control_initial(present: bool) -> Dictionary:
	return {"present":present,"owner_state":0,"segment":-1,"elapsed":0.0,"passes":0,"hold":false,"focus":false}

## Placement bit 0x1000 marks an absent object (both controls and props 64/67 at load; props 65/66 present).
static func initial(src: Dictionary) -> Dictionary:
	var controls:={}
	for c in CONTROLS: controls[c]=control_initial((int(src.locations[c].control.flags)&0x1000)==0)
	var props:={}
	for p in PROPS: props[p]={"present":(int(src.props[p].flags)&0x1000)==0,"owner_state":0}
	var timers:={}
	for p in src.timers: timers[p]=src.timers[p].map(func(r): return {"version":1,"flags":int(r.flags),"remaining":int(r.remaining)})
	return {"version":1,"locals":{"21":0},"controls":controls,"props":props,"timers":timers,"rng":1,"ticks":0.0,"receipts":[]}

static func _num(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func integer(v: Variant, lo: int, hi: int) -> bool: return _num(v) and float(v)==floor(float(v)) and v>=lo and v<=hi

static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.size()!=8 or not integer(s.get("version"),1,1): return "Invalid Kityara state."
	if not s.get("locals") is Dictionary or s.locals.size()!=1 or not integer(s.locals.get("21"),0,1): return "Invalid Kityara local."
	if not s.get("controls") is Dictionary or s.controls.size()!=2: return "Invalid Kityara controls."
	var segments: Array=src.movie.segments
	for c in CONTROLS:
		var k=s.controls.get(c)
		if not k is Dictionary or k.size()!=7: return "Invalid Kityara control."
		for f in ["present","hold","focus"]:
			if not k.get(f) is bool: return "Invalid Kityara control flag."
		if not integer(k.get("owner_state"),0,255) or not integer(k.get("segment"),-1,segments.size()-1) or not integer(k.get("passes"),0,65535): return "Invalid Kityara control state."
		if not _num(k.get("elapsed")) or k.elapsed<0: return "Invalid Kityara clock."
		if int(k.segment)<0 and (float(k.elapsed)!=0.0 or k.hold): return "Stopped Kityara clip has a clock or hold."
		if int(k.segment)>=0 and float(k.elapsed)>=float(segments[int(k.segment)].duration): return "Expired Kityara clip clock."
		if not k.present and (int(k.segment)>=0 or k.hold): return "Absent Kityara is speaking."
	if not s.get("props") is Dictionary or s.props.size()!=4: return "Invalid Kityara props."
	for p in PROPS:
		var q=s.props.get(p)
		if not q is Dictionary or q.size()!=2 or not q.get("present") is bool or not integer(q.get("owner_state"),0,255): return "Invalid Kityara prop."
	if not s.get("timers") is Dictionary or s.timers.size()!=src.timers.size(): return "Invalid Kityara timers."
	for p in src.timers:
		if not s.timers.get(p) is Array or s.timers[p].size()!=src.timers[p].size(): return "Invalid Kityara timers."
		for t in s.timers[p]:
			if EventTimer.restore(t).has("error"): return "Invalid Kityara timer."
	if not integer(s.get("rng"),0,4294967295) or not _num(s.get("ticks")) or s.ticks<0 or s.ticks>=1: return "Invalid Kityara timer clock."
	if not s.get("receipts") is Array or s.receipts.size()>MAX_RECEIPTS or s.receipts.any(func(v): return not v is String): return "Invalid Kityara receipts."
	# No local21/knife invariant: the source death path (hit while present via p150, death segment, dropped knife
	# prop64/67 use) grants the knife with local21 still 0.
	return ""

static func canonical(s: Dictionary) -> Dictionary:
	var r: Dictionary=s.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks=float(r.ticks);r.locals={"21":int(r.locals["21"])}
	for c in CONTROLS:
		var k: Dictionary=r.controls[c]
		for f in ["owner_state","segment","passes"]: k[f]=int(k[f])
		k.elapsed=float(k.elapsed)
	for p in PROPS: r.props[p].owner_state=int(r.props[p].owner_state)
	for p in r.timers: r.timers[p]=r.timers[p].map(func(t): return EventTimer.restore(t).checkpoint)
	return r

static func speaking(s: Dictionary) -> String:
	for c in CONTROLS:
		if bool(s.controls[c].hold): return c
	return ""

## ---- predicates ---------------------------------------------------------------------------------------------------
static func operand(s: Dictionary, o: Dictionary, kind: String, owner: int, ctx: Dictionary) -> int:
	if o.has("immediate"): return int(o.immediate)
	if o.has("owner_state"):
		if kind=="control" and s.controls.has(str(owner)): return int(s.controls[str(owner)].owner_state)
		if kind=="prop" and s.props.has(str(owner)): return int(s.props[str(owner)].owner_state)
		return 0
	if o.has("local"): return int(s.locals.get(str(int(o.local)),ctx.get("locals",{}).get(str(int(o.local)),0)))
	if o.has("shared"): return int(ctx.get("shared",{}).get(str(int(o.shared)),0))
	return 0

static func expression(s: Dictionary, e: Dictionary, kind: String, owner: int, ctx: Dictionary) -> bool:
	match str(e.op):
		"AND": return expression(s,e.left.expression,kind,owner,ctx) and expression(s,e.right.expression,kind,owner,ctx)
		"OR": return expression(s,e.left.expression,kind,owner,ctx) or expression(s,e.right.expression,kind,owner,ctx)
		"==": return operand(s,e.left,kind,owner,ctx)==operand(s,e.right,kind,owner,ctx)
		"!=": return operand(s,e.left,kind,owner,ctx)!=operand(s,e.right,kind,owner,ctx)
		">": return operand(s,e.left,kind,owner,ctx)>operand(s,e.right,kind,owner,ctx)
	return false

static func _test(s: Dictionary, src: Dictionary, r: Dictionary, ctx: Dictionary) -> bool:
	return r.predicate==null or expression(s,src.predicates[str(int(r.predicate))],str(r.owner_kind),int(r.owner),ctx)

static func _overlay(ctx: Dictionary) -> Dictionary:
	var o: Dictionary=ctx.duplicate(true)
	if not o.has("locals"): o.locals={}
	if not o.has("shared"): o.shared={}
	return o

static func dispatch(s: Dictionary, src: Dictionary, kind: String, owner: int, event: int, value: int, ctx: Dictionary) -> Array:
	var effects: Array=[]
	var o:=_overlay(ctx)
	if kind=="control" and not bool(s.controls[str(owner)].present): return effects
	if kind=="prop" and event!=2 and not bool(s.props[str(owner)].present): return effects
	for r in src.records:
		if str(r.owner_kind)==kind and int(r.owner)==owner and int(r.kind)==event and int(r.value)==value and _test(s,src,r,o): _run(s,src,r,o,effects)
	return effects

## ---- producers ----------------------------------------------------------------------------------------------------
static func enter_region(s: Dictionary, src: Dictionary, region: int, ctx: Dictionary) -> Array:
	return dispatch(s,src,"region",region,2,0,ctx)

## E on a present control with a held item: kind4 mode3, exact source identity, first eligible record only.
static func offer(s: Dictionary, src: Dictionary, control: int, identity: int, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if identity==0 or not bool(s.controls[str(control)].present) or speaking(s)!="": return effects
	var o:=_overlay(ctx)
	for row in src.offers:
		if int(row.owner)!=control or int(row.identity)!=identity: continue
		var r: Dictionary=src.records.filter(func(x): return int(x.group)==int(row.group) and str(x.owner_kind)=="control")[0]
		if not _test(s,src,r,o): continue
		_run(s,src,r,o,effects)
		break
	return effects

## A melee/Spark hit on her body: control kind9 value0.
static func hit(s: Dictionary, src: Dictionary, control: int, ctx: Dictionary) -> Array:
	return dispatch(s,src,"control",control,9,0,ctx)

## E on a present dropped-knife prop (64/67): kind4 value0.
static func use_prop(s: Dictionary, src: Dictionary, prop: int, ctx: Dictionary) -> Array:
	return dispatch(s,src,"prop",prop,4,0,ctx)

## Clip clocks (one source callback per update; no backlog replay) and the kind2 timers.
static func advance(s: Dictionary, src: Dictionary, delta: float, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if not is_finite(delta) or delta<=0: return effects
	for c in CONTROLS:
		var k: Dictionary=s.controls[c]
		if int(k.segment)<0 or not bool(k.present): continue
		var duration: float=float(src.movie.segments[int(k.segment)].duration)
		k.elapsed=float(k.elapsed)+delta
		if float(k.elapsed)<duration: continue
		if int(k.passes)>0:
			k.elapsed=fmod(float(k.elapsed),duration)
			if int(k.passes)!=65535: k.passes=int(k.passes)-1
			effects.append_array(dispatch(s,src,"control",int(c),6,1,ctx))
		else:
			k.segment=-1;k.elapsed=0.0
			effects.append_array(dispatch(s,src,"control",int(c),6,0,ctx))
	var total: float=float(s.ticks)+delta*TICKS
	var ticks:=int(floor(total));s.ticks=total-ticks
	if ticks>0:
		for p in src.timers:
			for i in src.timers[p].size():
				var row: Dictionary=src.timers[p][i]
				var result:=EventTimer.advance_with_rng(s.timers[p][i],ticks,s.rng,int(row.range[0]),int(row.range[1]),TICKS)
				s.timers[p][i]=result.checkpoint;s.rng=int(result.rng)
				if result.fired: effects.append_array(dispatch(s,src,"prop",int(p),2,int(row.value),ctx))
	return effects

## ---- commands -----------------------------------------------------------------------------------------------------
static func _receipt(s: Dictionary, raw: String, effects: Array) -> void:
	effects.append({"type":"external","raw":raw})
	if raw not in s.receipts and s.receipts.size()<MAX_RECEIPTS: s.receipts.append(raw)

static func _op14(s: Dictionary, src: Dictionary, b: PackedByteArray) -> bool:
	var p:=str(b.decode_u16(2));var index:=int(b[6])
	if b[1]!=3 or not s.timers.has(p) or index>=s.timers[p].size(): return false
	var t: Dictionary=s.timers[p][index]
	match int(b[4]):
		3:
			if (int(t.flags)&1)==0: return true
			t.flags=int(t.flags)&254
			if b[5]!=0:
				var row: Dictionary=src.timers[p][index]
				var draw:=EventTimer.draw_reload(s.rng,int(row.range[0]),int(row.range[1]),TICKS)
				s.rng=int(draw.rng);t.remaining=int(draw.reload)
		4: s.timers[p][index]=EventTimer.stop(t).checkpoint
		_: return false
	return true

static func _run(s: Dictionary, src: Dictionary, r: Dictionary, ctx: Dictionary, effects: Array) -> void:
	effects.append({"type":"group","group":int(r.group)})
	for c in r.commands:
		var raw:=str(c);var b: PackedByteArray=raw.hex_decode();var target: int=b.decode_u16(2) if b.size()>=4 else 0
		var control: bool=b.size()>=4 and b[1]==0x10 and s.controls.has(str(target))
		var prop: bool=b.size()>=4 and b[1]==3 and s.props.has(str(target))
		match int(b[0]):
			198:
				var key:=str(int(b[4]))
				if s.locals.has(key): s.locals[key]=int(b[5])
				elif src.local_names.has(key): effects.append({"type":"shop_local","name":str(src.local_names[key]),"value":int(b[5])})
				else: _receipt(s,raw,effects);continue
				ctx.locals[key]=int(b[5])
			199,206:
				var index:=int(b[4]);var value: int=int(b[5]) if b[0]==199 or b[5]<128 else int(b[5])-256
				effects.append({"type":"shared","index":index,"name":str(src.shared_names.get(str(index),"")),"op":"set" if b[0]==199 else "add","value":value})
				ctx.shared[str(index)]=value if b[0]==199 else int(ctx.shared.get(str(index),0))+value
			3:
				if b[1]==1: effects.append({"type":"grant","identity":b.decode_u32(4),"raw":raw})
				else: _receipt(s,raw,effects)
			2:
				if b[1]==1 and int(b[4]) in [38,39]:
					var active:=_owner_control(s,r)
					if active!="": s.controls[active].hold=int(b[4])==38
					effects.append({"type":"hold","value":int(b[4])==38})
				elif b[1]==1 and int(b[4])==24: effects.append({"type":"consume_held"})
				elif control and int(b[4]) in [5,6]: s.controls[str(target)].focus=int(b[4])==5
				else: _receipt(s,raw,effects)
			8:
				if not control: _receipt(s,raw,effects);continue
				var k: Dictionary=s.controls[str(target)]
				match int(b[4]):
					0: pass
					1: k.segment=-1;k.elapsed=0.0;k.hold=false
					7: k.passes=int(b.decode_u16(6))
					9,10:
						# Adapter: start groups assume the surrounding p150/p151 presence regions were crossed. A clip
						# started on an absent control makes it present instead of holding Luther for an invisible speaker.
						if not bool(k.present): k.present=true;effects.append({"type":"presence","control":target,"present":true})
						k.segment=int(b.decode_u16(6));k.elapsed=0.0
						effects.append({"type":"clip","control":target,"segment":int(k.segment)})
					_: _receipt(s,raw,effects)
			9:
				if control and int(b[4]) in [2,3]:
					var k: Dictionary=s.controls[str(target)]
					k.present=int(b[4])==3
					if not k.present: k.segment=-1;k.elapsed=0.0;k.hold=false;k.focus=false
					effects.append({"type":"presence","control":target,"present":k.present})
				elif prop and int(b[4]) in [2,3]: s.props[str(target)].present=int(b[4])==3;effects.append({"type":"prop","prop":target,"present":int(b[4])==3})
				elif prop and int(b[4])==21:
					for q in src.records:
						if str(q.owner_kind)=="prop" and int(q.owner)==target and int(q.kind)==6 and int(q.value)==20 and _test(s,src,q,ctx): _run(s,src,q,ctx,effects)
				else: _receipt(s,raw,effects)
			16:
				if control: s.controls[str(target)].owner_state=int(b[4])
				elif prop: s.props[str(target)].owner_state=int(b[4])
				else: _receipt(s,raw,effects)
			14:
				if not _op14(s,src,b): _receipt(s,raw,effects)
			18:
				if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":raw})
				else: _receipt(s,raw,effects)
			20: effects.append({"type":"sound","request":int(b.decode_u16(4)),"object":target})
			_: _receipt(s,raw,effects)

## The control a start/clip group belongs to: its own control, or the location whose start region it is.
static func _owner_control(s: Dictionary, r: Dictionary) -> String:
	if str(r.owner_kind)=="control": return str(int(r.owner))
	if str(r.owner_kind)=="region":
		for c in CONTROLS:
			for b in r.commands:
				var x: PackedByteArray=str(b).hex_decode()
				if x.size()>=4 and x[0]==8 and x[1]==0x10 and x.decode_u16(2)==int(c): return c
	return ""
