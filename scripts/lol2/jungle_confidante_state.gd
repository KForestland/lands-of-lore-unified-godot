extends RefCounted
## Pure state of the Huline village Confidante from the pinned contract (tools/prepare_jungle_confidante.py →
## jungle_confidante_source.json; AI_COMMS/grok_act1_mechanics_20261025/VILLAGE_ESCAPE_CONTRACT.md): controls 112
## (E103E.VQA, second meeting) and 123 (E102E.VQA, first meeting), their sight props 492/1465 and timer prop68.
## Owns locals 20 Confidante_trigger_is_active, 27 Met_Confidant and 39 Killed_Confidante plus control/prop/timer
## state. Locals 6/33 belong to the Kelsrick owner and arrive through the context; shared globals leave as "shared".
## Source chain: a sighted barrel (p96) links 123 and loops its idle; region3408 (p198) holds Luther and focuses it; the
## next loop end (state1) plays the conversation; its end sets Met_Confidant and unlinks it; region3397 sets local20=2;
## prop492 sighted (p105) links 112; region3408 (p175) and its conversation (state2 end: Soul+1) follow the same way.
## A landed hit (kind9: wildcard masks, threshold1, mode1, one-shot) runs the kill group once: local39=1, Soul-1, death
## segment, state5; the state5 end unlinks the control. Commands without a port owner are kept as saved receipts.
const SOURCE:="res://scripts/lol2/jungle_confidante_source.json"
const EventTimer=preload("res://scripts/lol2/hive_event_timer.gd")
const TICKS:=60
const MAX_RECEIPTS:=48
const CONTROLS:=["112","123"]
const PROPS:=["68","492","1465"]
const LOCALS:=["20","27","39"]

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

static func control_initial(present: bool) -> Dictionary:
	return {"present":present,"owner_state":0,"segment":-1,"elapsed":0.0,"passes":0,"hold":false,"focus":false,"struck":false}

## Placement bit 0x1000 marks an absent object (both controls at load).
static func initial(src: Dictionary) -> Dictionary:
	var controls:={}
	for c in CONTROLS: controls[c]=control_initial((int(src.locations[c].control.flags)&0x1000)==0)
	var props:={}
	for p in PROPS: props[p]={"present":(int(src.props[p].flags)&0x1000)==0,"owner_state":0}
	var timers:={}
	for p in src.timers: timers[p]=src.timers[p].map(func(r): return {"version":1,"flags":int(r.flags),"remaining":int(r.remaining)})
	var locals:={}
	for n in LOCALS: locals[n]=0
	return {"version":1,"locals":locals,"controls":controls,"props":props,"timers":timers,"rng":1,"ticks":0.0,"receipts":[]}

static func _num(v: Variant) -> bool: return (v is int or v is float) and is_finite(float(v))
static func integer(v: Variant, lo: int, hi: int) -> bool: return _num(v) and float(v)==floor(float(v)) and v>=lo and v<=hi

static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.size()!=8 or not integer(s.get("version"),1,1): return "Invalid Confidante state."
	if not s.get("locals") is Dictionary or s.locals.size()!=LOCALS.size(): return "Invalid Confidante locals."
	for n in LOCALS:
		if not integer(s.locals.get(n),0,255): return "Invalid Confidante local."
	if not s.get("controls") is Dictionary or s.controls.size()!=CONTROLS.size(): return "Invalid Confidante controls."
	for c in CONTROLS:
		var k=s.controls.get(c)
		var segments: Array=src.locations[c].movie.segments
		if not k is Dictionary or k.size()!=8: return "Invalid Confidante control."
		for f in ["present","hold","focus","struck"]:
			if not k.get(f) is bool: return "Invalid Confidante control flag."
		if not integer(k.get("owner_state"),0,255) or not integer(k.get("segment"),-1,segments.size()-1) or not integer(k.get("passes"),0,65535): return "Invalid Confidante control state."
		if not _num(k.get("elapsed")) or k.elapsed<0: return "Invalid Confidante clock."
		if int(k.segment)<0 and float(k.elapsed)!=0.0: return "Stopped Confidante clip has a clock."
		if int(k.segment)>=0 and float(k.elapsed)>=float(segments[int(k.segment)].duration): return "Expired Confidante clip clock."
		if not k.present and (int(k.segment)>=0 or k.hold): return "Absent Confidante is speaking."
	if CONTROLS.filter(func(c): return bool(s.controls[c].hold)).size()>1: return "Two Confidante holds."
	if not s.get("props") is Dictionary or s.props.size()!=PROPS.size(): return "Invalid Confidante props."
	for p in PROPS:
		var q=s.props.get(p)
		if not q is Dictionary or q.size()!=2 or not q.get("present") is bool or not integer(q.get("owner_state"),0,255): return "Invalid Confidante prop."
	if not s.get("timers") is Dictionary or s.timers.size()!=src.timers.size(): return "Invalid Confidante timers."
	for p in src.timers:
		if not s.timers.get(p) is Array or s.timers[p].size()!=src.timers[p].size(): return "Invalid Confidante timers."
		for t in s.timers[p]:
			if EventTimer.restore(t).has("error"): return "Invalid Confidante timer."
	if not integer(s.get("rng"),0,4294967295) or not _num(s.get("ticks")) or s.ticks<0 or s.ticks>=1: return "Invalid Confidante timer clock."
	if not s.get("receipts") is Array or s.receipts.size()>MAX_RECEIPTS or s.receipts.any(func(v): return not v is String): return "Invalid Confidante receipts."
	return ""

static func canonical(s: Dictionary) -> Dictionary:
	var r: Dictionary=s.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks=float(r.ticks)
	for n in LOCALS: r.locals[n]=int(r.locals[n])
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
	var effects: Array=[]
	# Modern adapter: a start group that will hold Luther for a control that is not idling first gets that control's
	# sight event (its barrel/prop stands beside region3408; the start group itself sets prop1465 state1).
	var o:=_overlay(ctx)
	for r in src.records:
		if str(r.owner_kind)!="region" or int(r.owner)!=region or not _test(s,src,r,o): continue
		var c:=_owner_control(s,r)
		if c!="" and int(s.controls[c].segment)<0: effects.append_array(sight(s,src,int(src.locations[c].starter_prop),ctx))
	effects.append_array(dispatch(s,src,"region",region,2,0,ctx))
	effects.append_array(_keep_speaker(s,src,ctx))
	return effects

## Sight of a starter prop (kind5): 1465 for control123, 492 for control112.
static func sight(s: Dictionary, src: Dictionary, prop: int, ctx: Dictionary) -> Array:
	return dispatch(s,src,"prop",prop,5,0,ctx)

## A landed melee/Spark hit on the control body (kind9 value0). The source record is the wildcard one-shot mode1
## shape (masks 0, threshold1, mode 0x81). Mode1 (AE358) admits only when the hit-context dword +0x1E >= threshold;
## the port binds the delivered damage amount to that dword. Native replay (Grok b63a4ba, rerun by Codex:
## AI_COMMS/codex_act1_review_20261025/village_dispatch): +0x1E 0 queues nothing and keeps the one-shot; >=1 queues the
## kill exactly once. A rejected hit therefore changes nothing; an admitted one spends the 0x80 one-shot.
static func hit(s: Dictionary, src: Dictionary, control: int, ctx: Dictionary, amount: int=1) -> Array:
	var k: Dictionary=s.controls[str(control)]
	var row: Dictionary=src.hits.get(str(control),{})
	if row.is_empty() or not bool(k.present) or bool(k.struck) or amount<int(row.threshold): return []
	k.struck=true
	return dispatch(s,src,"control",control,9,0,ctx)

## Modern adapter: the source start groups assume the speaker's idle loop is already running (its sight prop was seen
## first). If Luther is still held for a control that is not playing, release him instead of holding him for a silent
## speaker.
static func _keep_speaker(s: Dictionary, src: Dictionary, ctx: Dictionary) -> Array:
	var c:=speaking(s)
	if c=="" or int(s.controls[c].segment)>=0: return []
	var effects: Array=[]
	if bool(s.controls[c].hold):
		s.controls[c].hold=false;s.controls[c].focus=false
		effects.append({"type":"hold","value":false})
		_receipt(s,"adapter:release_silent_%s"%c,effects)
	return effects

## Clip clocks (one source callback per update; no backlog replay) and the kind2 timer.
static func advance(s: Dictionary, src: Dictionary, delta: float, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if not is_finite(delta) or delta<=0: return effects
	for c in CONTROLS:
		var k: Dictionary=s.controls[c]
		if int(k.segment)<0 or not bool(k.present): continue
		var duration: float=float(src.locations[c].movie.segments[int(k.segment)].duration)
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
				if not s.locals.has(key): _receipt(s,raw,effects);continue
				s.locals[key]=int(b[5]);ctx.locals[key]=int(b[5])
				effects.append({"type":"local","index":int(b[4]),"name":str(src.local_names.get(key,"")),"value":int(b[5])})
			199,206:
				var index:=int(b[4]);var value: int=int(b[5]) if b[0]==199 or b[5]<128 else int(b[5])-256
				effects.append({"type":"shared","index":index,"name":str(src.shared_names.get(str(index),"")),"op":"set" if b[0]==199 else "add","value":value})
				ctx.shared[str(index)]=value if b[0]==199 else int(ctx.shared.get(str(index),0))+value
			2:
				if b[1]==1 and int(b[4]) in [38,39]:
					var active:=_owner_control(s,r)
					if active!="": s.controls[active].hold=int(b[4])==38
					effects.append({"type":"hold","value":int(b[4])==38})
				elif control and int(b[4]) in [5,6]: s.controls[str(target)].focus=int(b[4])==5
				else: _receipt(s,raw,effects)
			8:
				if not control: _receipt(s,raw,effects);continue
				var k: Dictionary=s.controls[str(target)]
				match int(b[4]):
					0: pass
					1: k.segment=-1;k.elapsed=0.0
					7: k.passes=int(b.decode_u16(6))
					9,10:
						if not bool(k.present): _receipt(s,raw,effects);continue
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
			20: effects.append({"type":"sound","request":int(b.decode_u16(4)),"object":target,"kind":int(b[1])})
			_: _receipt(s,raw,effects)

## The control a hold belongs to: the group's own control, or the control a region start group focuses (op2 sub5).
static func _owner_control(s: Dictionary, r: Dictionary) -> String:
	if str(r.owner_kind)=="control": return str(int(r.owner))
	for b in r.commands:
		var x: PackedByteArray=str(b).hex_decode()
		if x.size()>=6 and x[0]==2 and x[1]==0x10 and x[4]==5 and s.controls.has(str(x.decode_u16(2))): return str(x.decode_u16(2))
	return ""
