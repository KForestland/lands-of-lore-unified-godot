extends RefCounted
## Pure state of Kelsrick's inner village gate (movables 74/75) from the pinned contract
## (tools/prepare_jungle_inner_gate.py → jungle_inner_gate_source.json). Each leaf has its own travel target, because
## g27916 opens leaf 74 only. Shut at rest.
## - Open: region2752 g5160; control98 selector1 end g21156 (Kelsrick's talk1 end g30684); plain use on a leaf while
##   GV_KELSRICK_DEAD==1 (g27916/g27934).
## - Shut: control98 selector0 end g21138; direct op1 commands from the Kelsrick owner (g5084) and the village alarm
##   (g27172).
## Control98 is an invisible logic marker (assembly template36, resource 0/type 0, no movie). Its op5 "clip" ends at once, into kind3 value = selector.
const SOURCE:="res://scripts/lol2/jungle_inner_gate_source.json"
const LEAVES:="res://assets/lol2/generated/jungle_inner_gate/leaves.json"
## Modern swing time, as the village gate.
const DURATION:=1.2

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

static func initial(open: bool=false) -> Dictionary:
	var leaf:={"target":100 if open else 0,"elapsed":DURATION if open else 0.0}
	return {"version":1,"leaves":{"74":leaf.duplicate(),"75":leaf.duplicate()}}

static func validate(s: Variant) -> String:
	if not s is Dictionary or s.size()!=2 or not (s.get("version") is int or s.get("version") is float) or s.version!=1: return "Invalid inner gate version."
	if not s.get("leaves") is Dictionary or s.leaves.size()!=2: return "Invalid inner gate leaves."
	for k in ["74","75"]:
		var l=s.leaves.get(k)
		if not l is Dictionary or l.size()!=2: return "Invalid inner gate leaf."
		var t=l.get("target");var e=l.get("elapsed")
		if not (t is int or t is float) or not (float(t) in [0.0,100.0]): return "Invalid inner gate target."
		if not (e is int or e is float) or not is_finite(float(e)) or e<0 or e>DURATION: return "Invalid inner gate clock."
	return ""

static func canonical(s: Dictionary) -> Dictionary:
	var r:={"version":1,"leaves":{}}
	for k in ["74","75"]: r.leaves[k]={"target":int(s.leaves[k].target),"elapsed":float(s.leaves[k].elapsed)}
	return r

static func percent(s: Dictionary, leaf: String) -> int: return int(round(float(s.leaves[leaf].elapsed)/DURATION*100.0))
static func open(s: Dictionary, leaf: String) -> bool: return int(s.leaves[leaf].target)==100

static func _test(src: Dictionary, p: Variant, ctx: Dictionary) -> bool:
	if p==null: return true
	var e: Dictionary=src.predicates[str(int(p))]
	return int(ctx.get("shared",{}).get(str(int(e.left.shared)),0))==int(e.right.immediate)

static func _records(src: Dictionary, kind: String, owner: int, event: int, value: int, ctx: Dictionary) -> Array:
	return src.records.filter(func(r): return str(r.owner_kind)==kind and int(r.owner)==owner and int(r.kind)==event and int(r.value)==value and _test(src,r.predicate,ctx))

static func _run(s: Dictionary, records: Array) -> Array:
	var effects: Array=[]
	for r in records:
		effects.append({"type":"group","group":int(r.group)})
		for c in r.commands: effects.append_array(_command(s,str(c).hex_decode()))
	return effects

static func _command(s: Dictionary, b: PackedByteArray) -> Array:
	if b.size()>=6 and b[0]==1 and b[1]==0x20 and s.leaves.has(str(b.decode_u16(2))) and b.decode_u16(4) in [0,100]:
		s.leaves[str(b.decode_u16(2))].target=b.decode_u16(4)
		return [{"type":"leaf","movable":b.decode_u16(2),"target":b.decode_u16(4)}]
	return []

static func enter_region(s: Dictionary, src: Dictionary, region: int, ctx: Dictionary) -> Array:
	return _run(s,_records(src,"region",region,2,0,ctx))

static func use(s: Dictionary, src: Dictionary, leaf: int, ctx: Dictionary) -> Array:
	return _run(s,_records(src,"movable",leaf,4,0,ctx))

## A raw command emitted by another owner: op1 kind32 74/75 (Kelsrick g5084, the alarm), or op5 on control98, whose
## selector ends at once into control98 kind3 value = selector.
static func external(s: Dictionary, src: Dictionary, raw: String, ctx: Dictionary) -> Array:
	var b: PackedByteArray=raw.hex_decode()
	if b.size()>=6 and b[0]==5 and b[1]==0x10 and b.decode_u16(2)==98:
		return _run(s,_records(src,"control",98,3,int(b[4]),ctx))
	return _command(s,b)

static func advance(s: Dictionary, leaf: String, delta: float) -> void:
	s.leaves[leaf].elapsed=move_toward(float(s.leaves[leaf].elapsed),DURATION*float(s.leaves[leaf].target)/100.0,delta)
