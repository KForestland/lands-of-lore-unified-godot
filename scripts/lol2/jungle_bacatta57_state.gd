extends RefCounted
## Pure source-chain state of the village-entry Bacatta (actor57), from the pinned contract
## (tools/prepare_jungle_bacatta57.py → jungle_bacatta57_source.json):
## - region3501 g7026 raises prop482 event20 on every entry; predicate173 (GV_BACATTA_RELATIONSHIP==0) is tested when the
##   event is queued (ADDE0).
## - g10162: op14 control216 timer1 (the unowned Huline alarm g27172, reported); op197 region3501 sub2 (seal: region bit0
##   = player-impassable); op1 kind32 movables56/57 → 100 (the village double door shuts); op9 actor57 property3 (link).
## - region3157 g5570 (GV_MET_BACATTA==1): op9 property2 removes 57 (65's half is jungle_bacatta65's).
## Natively the relationship starts at 1 (GLOBAL.MIX); the CAN farewell (CAN.WOM 0xE09) sets it to 0, so this runs on a
## village re-entry. The link sets no op13 hostility bits; B5 0x0C appears only when Luther strikes her (modern adapter).
const SOURCE:="res://scripts/lol2/jungle_bacatta57_source.json"
const ACTOR:=57
const PROP:=482
## Modern door timing: the source gives the travel target (percent), not a duration.
const DOOR_SECONDS:=1.5

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

static func initial(_src: Dictionary={}) -> Dictionary:
	return {"version":1,"sealed":false,"doors":{"target":0,"elapsed":0.0},"actor":{"present":false,"b5":0}}

static func _int(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and float(v)==floorf(float(v)) and v>=lo and v<=hi

## Reachable: untouched, or after g10162 (sealed, doors target100). B5 is 0 or the struck mask 0x0C.
static func validate(s: Variant, _src: Dictionary={}) -> String:
	if not s is Dictionary or s.size()!=4 or not _int(s.get("version"),1,1): return "Invalid Bacatta57 version."
	if not s.get("sealed") is bool: return "Invalid Bacatta57 seal."
	var d=s.get("doors")
	if not d is Dictionary or d.size()!=2 or not _int(d.get("target"),0,100) or int(d.target) not in [0,100]: return "Invalid Bacatta57 doors."
	var e=d.get("elapsed")
	if not (e is int or e is float) or not is_finite(float(e)) or e<0 or e>DOOR_SECONDS: return "Invalid Bacatta57 door clock."
	var a=s.get("actor")
	if not a is Dictionary or a.size()!=2 or not a.get("present") is bool or not _int(a.get("b5"),0,255) or int(a.b5) not in [0,12]: return "Invalid Bacatta57 actor."
	if not s.sealed and (int(d.target)!=0 or float(e)!=0 or a.present or int(a.b5)!=0): return "Bacatta57 state is unreachable before the village is sealed."
	if s.sealed and int(d.target)!=100: return "Sealed Bacatta57 doors must be shutting."
	return ""

## JSON loads every number as float: restore integer fields so checkpoints compare exactly.
static func canonical(s: Dictionary) -> Dictionary:
	return {"version":1,"sealed":bool(s.sealed),"doors":{"target":int(s.doors.target),"elapsed":float(s.doors.elapsed)},
		"actor":{"present":bool(s.actor.present),"b5":int(s.actor.b5)}}

static func hostile(s: Dictionary) -> bool: return bool(s.actor.present) and (int(s.actor.b5)&12)!=0 and (int(s.actor.b5)&1)==0
static func door_percent(s: Dictionary) -> int: return int(round(float(s.doors.elapsed)/DOOR_SECONDS*100.0))

static func _shared(ctx: Dictionary, index: int) -> int: return int(ctx.get("shared",{}).get(str(index),0))
static func _test(src: Dictionary, p: Variant, ctx: Dictionary) -> bool:
	if p==null: return true
	var e: Dictionary=src.predicates[str(int(p))]
	var side:=func(o: Dictionary) -> int: return _shared(ctx,int(o.shared)) if o.has("shared") else int(o.immediate)
	return str(e.op)=="==" and side.call(e.left)==side.call(e.right)

static func _records(src: Dictionary, kind: String, owner: int, event: int, value: int, ctx: Dictionary) -> Array:
	return src.records.filter(func(r): return str(r.owner_kind)==kind and int(r.owner)==owner and int(r.kind)==event and int(r.value)==value and _test(src,r.predicate,ctx))

## Region event2 (grounded entry). Only the pinned 3501/3157 groups exist in the contract.
static func enter_region(s: Dictionary, src: Dictionary, region: int, ctx: Dictionary) -> Array:
	var effects: Array=[]
	for r in _records(src,"region",region,2,0,ctx): _run(s,src,r,ctx,effects)
	return effects

## A strike on the linked, non-hostile body: modern adapter (no own kind9 record) → B5 0x0C, bit0 clear.
static func struck(s: Dictionary) -> Array:
	if not s.actor.present or hostile(s): return []
	s.actor.b5=(int(s.actor.b5)&243)|12;s.actor.b5=int(s.actor.b5)&254
	return [{"type":"hostile","actor":ACTOR}]

static func advance(s: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	s.doors.elapsed=move_toward(float(s.doors.elapsed),DOOR_SECONDS*float(s.doors.target)/100.0,delta)

static func _run(s: Dictionary, src: Dictionary, record: Dictionary, ctx: Dictionary, effects: Array) -> void:
	effects.append({"type":"group","group":int(record.group)})
	for c in record.commands:
		var b: PackedByteArray=str(c).hex_decode()
		var target: int=b.decode_u16(2)
		match int(b[0]):
			9:
				if b[1]==3 and target==PROP and b[4]==21:
					# op9 property21 → prop482 event20, queued with its predicate tested now (ADDE0).
					for q in _records(src,"prop",PROP,6,20,ctx): _run(s,src,q,ctx,effects)
				elif b[1]==2 and target==ACTOR and b[4] in [2,3]:
					s.actor.present=b[4]==3
					effects.append({"type":"actor_presence","present":s.actor.present})
				else: effects.append({"type":"external","raw":b.hex_encode()})
			197:
				if b[1]==0x90 and target==int(src.threshold) and b[4]==2:
					s.sealed=true;effects.append({"type":"sealed","region":target})
				else: effects.append({"type":"external","raw":b.hex_encode()})
			1:
				if b[1]==0x20 and target in src.doors.map(func(v): return int(v)):
					s.doors.target=b.decode_u16(4);effects.append({"type":"doors","movable":target,"target":int(s.doors.target)})
				else: effects.append({"type":"external","raw":b.hex_encode()})
			18:
				# g7026's return point. Applied by the controller only once the threshold is sealed (adapter).
				effects.append({"type":"return_point","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)]})
			_: effects.append({"type":"external","raw":b.hex_encode()})
