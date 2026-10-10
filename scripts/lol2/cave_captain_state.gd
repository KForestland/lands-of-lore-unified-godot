extends RefCounted
## Cave captain chain (control89 plate → control120 → GGCAPT actor56) from pinned source groups.
## Pure saved state; the caller presents returned effects and supplies the producers.
## Source rules: ADDE0 predicates at queue time, FIFO groups; opcode13 B5 bits (A6348 table);
## opcode16 byte25; opcode207 signed add (0x648AF); opcode14 operation3 enable / 4 disable;
## kind9 = native AE2C8 mode1 gate (record masks vs hit-context words0/2, threshold <= +0x1E).
## Adapters: opcode8 accepted at once (native may retain the cursor until the backend accepts);
## control120 event0 completion, captain event3 pose endpoint, event8, kind10 and kind3/kind5
## value0 producers are supplied; timers tick at 60/s.
const EventTimer = preload("res://scripts/lol2/hive_event_timer.gd")
const CAPTAIN := 56

static func source(path: String="res://scripts/lol2/cave_captain_source.json") -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(path))

static func initial(src: Dictionary) -> Dictionary:
	var locals: Dictionary={}
	for id in src.owned_locals: locals[str(int(id))]=0
	return {"version":1,"locals":locals,
		"objects":{"control89":{"present":true,"state":0},"control120":{"present":true,"state":0}},
		"captain":{"present":bool(src.captain.present),"state":0,"b5":0,"health":int(src.captain.health),"selector":-1,"defeated":false,"items":[]},
		"timer":{"version":1,"flags":int(src.timer.flags),"remaining":int(src.timer.countdown)},
		"ticks_fraction":0.0,"rng":1,"granted":[]}

static func _integer(value: Variant, maximum: int, minimum: int=0) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value)==floor(float(value)) and value>=minimum and value<=maximum

static func validate(state: Variant, src: Dictionary) -> String:
	if not state is Dictionary or not _integer(state.get("version"),1,1): return "Invalid captain version."
	if not state.get("locals") is Dictionary or state.locals.size()!=src.owned_locals.size(): return "Invalid captain locals."
	for id in src.owned_locals:
		if not _integer(state.locals.get(str(int(id))),255): return "Invalid captain local."
	if not state.get("objects") is Dictionary or state.objects.size()!=2: return "Invalid captain objects."
	for key in ["control89","control120"]:
		var o=state.objects.get(key)
		if not o is Dictionary or not o.get("present") is bool or not _integer(o.get("state"),255): return "Invalid captain object."
	var c=state.get("captain")
	if not c is Dictionary or not c.get("present") is bool or not c.get("defeated") is bool: return "Invalid captain actor."
	if not _integer(c.get("state"),255) or not _integer(c.get("b5"),255) or not _integer(c.get("health"),int(src.captain.health)) or not _integer(c.get("selector"),255,-1): return "Invalid captain actor."
	if c.defeated!=(int(c.health)==0): return "Captain defeat disagrees with health."
	if not c.get("items") is Array or not state.get("granted") is Array: return "Invalid captain items."
	for name in c.items+state.granted:
		if not name is String or not name in src.items.values(): return "Invalid captain item."
	if state.granted.size()>2 or state.captain.items.size()>1:return "Invalid repeated captain grant."
	for i in state.granted.size():
		if state.granted[i]!=["5-Short swd","37-Brnt Chain"][i]:return "Invalid captain grant order."
	if EventTimer.restore(state.get("timer")).has("error"): return "Invalid captain timer."
	var f=state.get("ticks_fraction")
	if not (f is float or f is int) or not is_finite(float(f)) or float(f)<0 or float(f)>=1: return "Invalid captain clock."
	if not _integer(state.get("rng"),4294967295): return "Invalid captain RNG."
	return ""

static func canonical(state: Dictionary, src: Dictionary) -> Dictionary:
	var r: Dictionary=state.duplicate(true)
	r.version=1;r.rng=int(r.rng);r.ticks_fraction=float(r.ticks_fraction)
	for key in r.locals: r.locals[key]=int(r.locals[key])
	for key in r.objects: r.objects[key].state=int(r.objects[key].state)
	for key in ["state","b5","health","selector"]: r.captain[key]=int(r.captain[key])
	r.timer=EventTimer.restore(r.timer).checkpoint
	return r

## Captain fights when a source decision request is pending and unblocked (B5 0C set, bit01 clear).
static func fighting(state: Dictionary) -> bool:
	var c: Dictionary=state.captain
	return c.present and not c.defeated and (int(c.b5)&12)!=0 and (int(c.b5)&1)==0

## ---- supplied producers ------------------------------------------------------------------
## Support plate entry (source_control_contact.gd effect {owner, value, groups}).
static func plate_entered(state: Dictionary, src: Dictionary, control: int, value: int) -> Array:
	return _dispatch(state,src,"control",control,5,value)

## Control120 animation completion (event0); its media/clock are supplied.
static func control_animation_finished(state: Dictionary, src: Dictionary) -> Array:
	return _dispatch(state,src,"control",120,6,0)

## Hit on the captain: AE2C8 mode1 gate with the supplied hit-context masks, then health.
static func hit(state: Dictionary, src: Dictionary, mask0: int, mask2: int, damage: int) -> Array:
	var c: Dictionary=state.captain
	if not c.present or c.defeated: return []
	var k: Dictionary=src.kind9
	var effects: Array=[]
	if (int(k.mask0)==0 or (mask0&int(k.mask0))!=0) and (int(k.mask2)==0 or (mask2&int(k.mask2))!=0) and int(k.threshold)<=damage:
		effects=_dispatch(state,src,"actor",CAPTAIN,9,int(k.mask0))
	if damage>0 and not c.defeated:
		c.health=maxi(0,int(c.health)-damage)
		effects.append({"type":"damage","health":int(c.health)})
		if int(c.health)==0:
			c.defeated=true
			effects.append_array(_dispatch(state,src,"actor",CAPTAIN,6,11))
	return effects

## Captain selector endpoint (event3); supplied by the presentation clock.
static func pose_finished(state: Dictionary, src: Dictionary) -> Array:
	return _dispatch(state,src,"actor",CAPTAIN,6,3)

## Player use (kind4 value0) on the captain.
static func use(state: Dictionary, src: Dictionary) -> Array:
	if not state.captain.present or (state.captain.defeated and int(state.captain.state) not in [2,3]): return []
	return _dispatch(state,src,"actor",CAPTAIN,4,0)

## Other captain records with unknown producers: kind10 (word), kind3 value12, kind5 value0, event8.
static func record_event(state: Dictionary, src: Dictionary, kind: int, value: int, word: int=-1) -> Array:
	if kind==10:
		var effects: Array=[]
		for r in src.kind10:
			if int(r.word)==word: effects.append_array(_run(state,src,[_group(src,int(r.group))]))
		return effects
	return _dispatch(state,src,"actor",CAPTAIN,kind,value)

static func advance(state: Dictionary, src: Dictionary, delta: float) -> Array:
	if not is_finite(delta): return []
	var total: float=float(state.ticks_fraction)+maxf(delta,0.0)*float(src.tick_rate)
	var ticks:=int(floor(total));state.ticks_fraction=total-ticks
	if ticks==0: return []
	var t: Dictionary=src.timer
	var result: Dictionary=EventTimer.advance_with_rng(state.timer,ticks,state.rng,int(t.range[0]),int(t.range[1]),int(src.tick_rate))
	state.timer=result.checkpoint;state.rng=int(result.rng)
	return _run(state,src,[_group(src,int(t.group))]) if result.fired else []

## ---- interpreter -------------------------------------------------------------------------

static func _group(src: Dictionary, id: int) -> Dictionary:
	for g in src.groups:
		if int(g.group)==id: return g
	return {}

static func _owner_state(state: Dictionary, kind: String, owner: int) -> int:
	if kind=="actor": return int(state.captain.state)
	return int(state.objects.get("%s%d"%[kind,owner],{}).get("state",0))

static func _operand(state: Dictionary, node: Dictionary, kind: String, owner: int) -> int:
	if node.has("immediate"): return int(node.immediate)
	if node.has("owner_state"): return _owner_state(state,kind,owner)
	if node.has("predicate"): return int(_test(state,node.expression,kind,owner))
	if node.has("local"): return int(state.locals.get(str(int(node.local)),0))
	return 0

static func _test(state: Dictionary, p: Dictionary, kind: String, owner: int) -> bool:
	var l:=_operand(state,p.left,kind,owner);var r:=_operand(state,p.right,kind,owner)
	match str(p.op):
		"==": return l==r
		"!=": return l!=r
		"<=": return l<=r
		">=": return l>=r
		">": return l>r
		"<": return l<r
		"AND": return l!=0 and r!=0
		"OR": return l!=0 or r!=0
	return false

static func _dispatch(state: Dictionary, src: Dictionary, kind: String, owner: int, record: int, value: int) -> Array:
	var queue: Array=[]
	for g in src.groups:
		if str(g.owner_kind)!=kind or int(g.owner)!=owner or int(g.record)!=record or (int(g.value)&255)!=(value&255): continue
		if g.predicate!=null and not _test(state,src.predicates[str(int(g.predicate))],kind,owner): continue
		queue.append(g)
	return _run(state,src,queue)

static func _run(state: Dictionary, src: Dictionary, queue: Array) -> Array:
	var effects: Array=[]
	while not queue.is_empty():
		var g: Dictionary=queue.pop_front()
		if g.is_empty(): continue
		effects.append({"type":"group","group":int(g.group)})
		for raw in g.commands: _command(state,src,str(raw).hex_decode(),effects)
	return effects

static func _object(state: Dictionary, kind: int, target: int) -> Dictionary:
	if kind==16: return state.objects.get("control%d"%target,{})
	return {}

static func _command(state: Dictionary, src: Dictionary, b: PackedByteArray, effects: Array) -> void:
	var op:=b[0];var target:=b[2]|(b[3]<<8)
	var captain: bool=b[1]==2 and target==CAPTAIN
	var c: Dictionary=state.captain
	match op:
		198:
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=b[5]
			else: effects.append({"type":"local","local":b[4],"value":b[5]})
		207:
			if state.locals.has(str(b[4])): state.locals[str(b[4])]=clampi(int(state.locals[str(b[4])])+(b[5]-256 if b[5]>127 else b[5]),0,255)
		16:
			if captain: c.state=b[4]
			elif not _object(state,b[1],target).is_empty(): _object(state,b[1],target).state=b[4]
			else: effects.append({"type":"state","kind":b[1],"target":target,"value":b[4]})
		9:
			var o: Dictionary=c if captain else _object(state,b[1],target)
			if b[4] in [2,3] and not o.is_empty():
				var present: bool=b[4]==3
				if bool(o.present)!=present:
					o.present=present
					effects.append({"type":"spawn" if present else "remove","kind":b[1],"target":target})
			else: effects.append({"type":"object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		13:
			if not captain: return
			match b[4]:
				6: c.b5=int(c.b5)|1
				7: c.b5=int(c.b5)&254
				11: c.b5=int(c.b5)|4
				12: c.b5=int(c.b5)|8
				13: c.b5=(int(c.b5)&243)|12
				18:
					c.health=0;c.defeated=true
					effects.append({"type":"actor_command","sub":18,"value":b[5]})
					effects.append_array(_dispatch(state,src,"actor",CAPTAIN,6,11))
				_: effects.append({"type":"actor_command","sub":b[4],"value":b[5]})
		5:
			if captain:
				c.selector=b[4]
				effects.append({"type":"selector","target":target,"selector":b[4]})
			else: effects.append({"type":"selector","kind":b[1],"target":target,"selector":b[4]})
		3: # item grant: kind1 player, kind2 actor
			var ident:=b.decode_u32(4)
			var name: String=str(src.items.get(str(ident),""))
			if b[1]==1:
				state.granted.append(name);effects.append({"type":"grant_player","item":name,"identity":ident})
			elif captain:
				c.items.append(name);effects.append({"type":"grant_actor","item":name,"identity":ident,"note":"actor inventory; retirement drop presented by cave_captain_loot"})
		14:
			if b[1]==3 and target==int(src.timer.owner):
				if b[4]==3 and (int(state.timer.flags)&1)!=0: state.timer.flags=int(state.timer.flags)&254
				elif b[4]==4: state.timer=EventTimer.stop(state.timer).checkpoint
		18:
			if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)],"raw":b.hex_encode()})
		20, 24:
			effects.append({"type":"sound" if op==20 else "speech","target":target,"request":b.decode_u16(4),"raw":b.hex_encode()})
		8:
			effects.append({"type":"animation","kind":b[1],"target":target,"property":b[4],"raw":b.hex_encode()})
		2:
			effects.append({"type":"player_property" if b[1]==1 else "object_property","kind":b[1],"target":target,"property":b[4],"value":b[5]})
		_: effects.append({"type":"presentation","raw":b.hex_encode()})
