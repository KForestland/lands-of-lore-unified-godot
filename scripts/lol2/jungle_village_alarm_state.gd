extends RefCounted
## Pure state of the Huline village alarm from the pinned contract (tools/prepare_jungle_village_alarm.py →
## jungle_village_alarm_source.json).
## - Region3805 (the gate passage) g7956 and Bacatta57's g10162 start control216 timer1. On expiry g27172 runs under
##   predicate192 (GV_HULINE_ALERT==1 AND local32==0). Its effects:
##   - local52=1, local32=1, local8=30, soul −2 and Kelsrick hostility: forwarded as one bundle to the Kelsrick owner,
##     the single owner of those locals and of his B5;
##   - control100 event20 (g21372 if local33==1, g21418 if local52==1): more Kelsrick commands;
##   - gates 78/79 and 74/75 → 0, the Bacatta57 doors 56/57 → 100; local7=2 (owned here);
##   - the timers of controls 77, 216 (index0, index2) and 217.
## - Control216 index0 → g27162: sound 403 (bells1) at prop510 while the alert holds.
## - Controls 77/216 index2/217 → op15 sub-op93: an Arrow (SPELL.ODF 12) from the control at Luther. Every kind2 row
##   reloads by a random draw over its range × 60 ticks. No source command stops these timers.
## Unbound commands (op9 property17 on 78/79, op5 control82, op2 player 0x25, op210 music) are kept as receipts.
const SOURCE:="res://scripts/lol2/jungle_village_alarm_source.json"
const EventTimer=preload("res://scripts/lol2/hive_event_timer.gd")
const TICKS:=60
const MOVABLES:=["56","57","74","75","78","79"]
const MAX_RECEIPTS:=32

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

static func initial(src: Dictionary) -> Dictionary:
	var timers:={}
	for c in src.timers:
		timers[c]=src.timers[c].map(func(row): return {"version":1,"flags":int(row.flags),"remaining":int(row.remaining)})
	var movables:={}
	for m in MOVABLES: movables[m]=-1
	return {"version":1,"timers":timers,"rng":1,"ticks":0.0,"locals":{"7":0},"movables":movables,"receipts":[]}

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)==floorf(float(v)) and v>=lo and v<=hi

static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.size()!=7 or not _int(s.get("version"),1,1): return "Invalid village alarm version."
	if not s.get("timers") is Dictionary or s.timers.size()!=src.timers.size(): return "Invalid village alarm timers."
	for c in src.timers:
		if not s.timers.get(c) is Array or s.timers[c].size()!=src.timers[c].size(): return "Invalid village alarm timers."
		for t in s.timers[c]:
			if EventTimer.restore(t).has("error"): return "Invalid village alarm timer."
	if not _int(s.get("rng"),0,4294967295): return "Invalid village alarm seed."
	var ticks=s.get("ticks")
	if not (ticks is float or ticks is int) or not is_finite(float(ticks)) or ticks<0 or ticks>=1: return "Invalid village alarm tick clock."
	if not s.get("locals") is Dictionary or s.locals.size()!=1 or not _int(s.locals.get("7"),0,255): return "Invalid village alarm local."
	if not s.get("movables") is Dictionary or s.movables.size()!=MOVABLES.size(): return "Invalid village alarm movables."
	for m in MOVABLES:
		if not _int(s.movables.get(m),-1,100) or int(s.movables[m]) not in [-1,0,100]: return "Invalid village alarm movable target."
	if not s.get("receipts") is Array or s.receipts.size()>MAX_RECEIPTS: return "Invalid village alarm receipts."
	for r in s.receipts:
		if not r is String or r.length()>64 or not r.is_valid_hex_number() or s.receipts.count(r)!=1: return "Invalid village alarm receipt."
	return ""

static func canonical(s: Dictionary) -> Dictionary:
	var r: Dictionary=s.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks=float(r.ticks);r.locals={"7":int(r.locals["7"])}
	for c in r.timers: r.timers[c]=r.timers[c].map(func(t): return EventTimer.restore(t).checkpoint)
	for m in r.movables: r.movables[m]=int(r.movables[m])
	return r

## ---- predicates (shared29 from the village gate, locals from the Kelsrick owner) ---------------------------------
static func _operand(s: Dictionary, o: Dictionary, ctx: Dictionary) -> int:
	if o.has("immediate"): return int(o.immediate)
	if o.has("shared"): return int(ctx.get("shared",{}).get(str(int(o.shared)),0))
	if o.has("local"):
		var key:=str(int(o.local))
		return int(s.locals[key]) if s.locals.has(key) else int(ctx.get("locals",{}).get(key,0))
	return 0
static func test(s: Dictionary, src: Dictionary, p: Variant, ctx: Dictionary) -> bool:
	if p==null: return true
	return _expr(s,src.predicates[str(int(p))],src,ctx)
static func _expr(s: Dictionary, e: Dictionary, src: Dictionary, ctx: Dictionary) -> bool:
	match str(e.op):
		"AND": return _expr(s,e.left.expression,src,ctx) and _expr(s,e.right.expression,src,ctx)
		"OR": return _expr(s,e.left.expression,src,ctx) or _expr(s,e.right.expression,src,ctx)
		"==": return _operand(s,e.left,ctx)==_operand(s,e.right,ctx)
		"!=": return _operand(s,e.left,ctx)!=_operand(s,e.right,ctx)
	return false

static func _records(s: Dictionary, src: Dictionary, kind: String, owner: int, event: int, value: int, ctx: Dictionary) -> Array:
	return src.records.filter(func(r): return str(r.owner_kind)==kind and int(r.owner)==owner and int(r.kind)==event and int(r.value)==value and test(s,src,r.predicate,ctx))

## ---- producers ---------------------------------------------------------------------------------------------------
static func enter_region(s: Dictionary, src: Dictionary, region: int, ctx: Dictionary) -> Array:
	var effects: Array=[]
	for r in _records(s,src,"region",region,2,0,ctx): _run(s,src,r,ctx,effects)
	return effects

## An op14 on these controls emitted by another owner (Bacatta57's g10162).
static func arm(s: Dictionary, src: Dictionary, raw: String) -> bool:
	var b: PackedByteArray=raw.hex_decode()
	if b.size()<7 or b[0]!=14 or b[1]!=0x10 or not s.timers.has(str(b.decode_u16(2))): return false
	_op14(s,src,b)
	return true

static func advance(s: Dictionary, src: Dictionary, delta: float, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if not is_finite(delta) or delta<=0: return effects
	var total: float=float(s.ticks)+delta*TICKS
	var ticks:=int(floor(total));s.ticks=total-ticks
	if ticks<=0: return effects
	for c in src.timers:
		for i in src.timers[c].size():
			var row: Dictionary=src.timers[c][i]
			var result:=EventTimer.advance_with_rng(s.timers[c][i],ticks,s.rng,int(row.range[0]),int(row.range[1]),TICKS)
			s.timers[c][i]=result.checkpoint;s.rng=int(result.rng)
			if not result.fired: continue
			# kind2 expiry: the record's predicate is tested when it fires.
			for r in src.records:
				if str(r.owner_kind)=="control" and int(r.owner)==int(c) and int(r.kind)==2 and int(r.group)==int(row.group) and test(s,src,r.predicate,ctx):
					_run(s,src,r,ctx,effects)
	return effects

## ---- commands ----------------------------------------------------------------------------------------------------
static func _receipt(s: Dictionary, raw: String, effects: Array) -> void:
	effects.append({"type":"external","raw":raw})
	if raw not in s.receipts and s.receipts.size()<MAX_RECEIPTS: s.receipts.append(raw)

static func _op14(s: Dictionary, src: Dictionary, b: PackedByteArray) -> void:
	var c:=str(b.decode_u16(2));var index:=int(b[6])
	if not s.timers.has(c) or index>=s.timers[c].size(): return
	var t: Dictionary=s.timers[c][index]
	match int(b[4]):
		3:
			# B485C: a running timer is left alone; a stopped one starts (argument≠0 redraws its countdown).
			if (int(t.flags)&1)==0: return
			t.flags=int(t.flags)&254
			if b[5]!=0:
				var row: Dictionary=src.timers[c][index]
				var draw:=EventTimer.draw_reload(s.rng,int(row.range[0]),int(row.range[1]),TICKS)
				s.rng=int(draw.rng);t.remaining=int(draw.reload)
		4: s.timers[c][index]=EventTimer.stop(t).checkpoint

static func _run(s: Dictionary, src: Dictionary, record: Dictionary, ctx: Dictionary, effects: Array) -> void:
	effects.append({"type":"group","group":int(record.group)})
	# Kelsrick-owned commands keep their order in one bundle; locals written here are visible to later predicates.
	var bundle: Array=[]
	var overlay: Dictionary=ctx.duplicate(true)
	if not overlay.has("locals"): overlay.locals={}
	if not overlay.has("shared"): overlay.shared={}
	for c in record.commands:
		var raw:=str(c);var b: PackedByteArray=raw.hex_decode();var target: int=b.decode_u16(2)
		match int(b[0]):
			198:
				var key:=str(int(b[4]))
				if s.locals.has(key): s.locals[key]=int(b[5])
				else: bundle.append(raw);overlay.locals[key]=int(b[5])
			199,206:
				bundle.append(raw)
				if int(b[0])==199: overlay.shared[str(int(b[4]))]=int(b[5])
			8,13:
				if b[1]==2 and target==64: bundle.append(raw)
				else: _receipt(s,raw,effects)
			9:
				if b[1]==2 and target==64: bundle.append(raw)
				elif b[1]==0x10 and target==100 and b[4]==21:
					for q in _records(s,src,"control",100,6,20,overlay): _run(s,src,q,overlay,effects)
				else: _receipt(s,raw,effects)
			1:
				if b[1]==0x20 and s.movables.has(str(target)):
					s.movables[str(target)]=int(b.decode_u16(4))
					effects.append({"type":"movable","movable":target,"target":int(b.decode_u16(4))})
				else: _receipt(s,raw,effects)
			14:
				if b[1]==0x10 and s.timers.has(str(target)): _op14(s,src,b)
				else: _receipt(s,raw,effects)
			15:
				if b[1]==0x10 and b[4]==0x5d and b[5]==1: effects.append({"type":"arrow","control":target})
				else: _receipt(s,raw,effects)
			20: effects.append({"type":"sound","request":int(b.decode_u16(4)),"object":target})
			_: _receipt(s,raw,effects)
	if not bundle.is_empty(): effects.append({"type":"kelsrick","group":int(record.group),"commands":bundle})
