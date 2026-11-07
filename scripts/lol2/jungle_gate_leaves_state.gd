extends RefCounted
## Pure state of the village gate-leaf hit consumers (tools/prepare_jungle_gate_leaves.py → jungle_gate_leaves_source.json;
## VILLAGE_ESCAPE_CONTRACT.md groups 28068/28140). It accepts an explicitly supplied hit context and never computes
## damage: mask0 must share bit 0x0800 with the record (AE2C8; mask1 0 is not tested), the after-durability
## (context +0x26) must be <= the record threshold 1 (mode4, AE3BA; Jungle level index4 skips the level5 special), and
## predicate196 must hold (local39 Killed_Confidante==1 AND shared29 GV_HULINE_ALERT==1). An accepted context runs the
## source group: sound452 at control81, link control81 (leaf78) or control80 (leaf79), unlink the leaf. A rejected
## context changes nothing. Regions 588/3895/3896/3897 (no predicate) relink both leaves and unlink both controls.
## The alarm only moves leaf poses (jungle_village_alarm owns the targets); it never relinks an unlinked leaf.
const SOURCE:="res://scripts/lol2/jungle_gate_leaves_source.json"
const LEAVES:=["78","79"]
const CONTROLS:=["80","81"]
const MAX_RECEIPTS:=16

static func source(path: String=SOURCE) -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(path))

## Leaves are linked at load; controls 80/81 carry placement bit 0x1000 (absent).
static func initial(src: Dictionary) -> Dictionary:
	var leaves:={}
	for l in LEAVES: leaves[l]=true
	var controls:={}
	for c in CONTROLS: controls[c]=(int(src.controls[c].flags)&0x1000)==0
	return {"version":1,"leaves":leaves,"controls":controls,"receipts":[]}

static func validate(s: Variant, _src: Dictionary={}) -> String:
	if not s is Dictionary or s.size()!=4 or not (s.get("version") is int or s.get("version") is float) or int(s.version)!=1 or float(s.version)!=1.0: return "Invalid gate leaf state."
	for key in ["leaves","controls"]:
		var names: Array=LEAVES if key=="leaves" else CONTROLS
		if not s.get(key) is Dictionary or s[key].size()!=names.size(): return "Invalid gate leaf %s."%key
		for n in names:
			if not s[key].get(n) is bool: return "Invalid gate leaf link."
	# Source pairing: control81 is linked exactly when leaf78 is unlinked by its group, control80 for leaf79.
	if bool(s.leaves["78"])==bool(s.controls["81"]) or bool(s.leaves["79"])==bool(s.controls["80"]): return "Gate leaf and fallen leaf disagree."
	if not s.get("receipts") is Array or s.receipts.size()>MAX_RECEIPTS or s.receipts.any(func(v): return not v is String): return "Invalid gate leaf receipts."
	return ""

static func canonical(s: Dictionary) -> Dictionary:
	var r: Dictionary=s.duplicate(true);r.version=1
	return r

static func linked(s: Dictionary, leaf: int) -> bool: return bool(s.leaves.get(str(leaf),true))

## Predicate196 on the supplied context (local39 from the Confidante owner, shared29 from the village gate).
static func predicate(ctx: Dictionary) -> bool:
	return int(ctx.get("locals",{}).get("39",0))==1 and int(ctx.get("shared",{}).get("29",0))==1

## Why a context would be refused ("" when admitted). Order: presence, mask, durability, predicate.
static func refusal(s: Dictionary, src: Dictionary, leaf: int, hit: Dictionary, ctx: Dictionary) -> String:
	var row: Dictionary=src.leaves.get(str(leaf),{})
	if row.is_empty(): return "not a gate leaf"
	if not linked(s,leaf): return "leaf unlinked"
	for k in ["mask0","before","after"]:
		var v=hit.get(k)
		if not (v is int or v is float) or not is_finite(float(v)) or float(v)!=floor(float(v)): return "invalid context"
	if int(row.mask0)!=0 and (int(hit.mask0)&int(row.mask0))==0: return "mask"
	if int(row.mode)!=4 or int(hit.after)>int(row.threshold): return "durability"
	if not predicate(ctx): return "predicate"
	return ""

## The consumer: a supplied hit context on leaf78/79 (kind9 value2048).
static func hit(s: Dictionary, src: Dictionary, leaf: int, context: Dictionary, ctx: Dictionary) -> Array:
	if not refusal(s,src,leaf,context,ctx).is_empty(): return []
	var row: Dictionary=src.leaves[str(leaf)]
	var effects: Array=[{"type":"group","group":int(row.group)}]
	for c in row.commands: _command(s,str(c),effects)
	return effects

static func enter_region(s: Dictionary, src: Dictionary, region: int) -> Array:
	var row: Dictionary=src.relink.get(str(region),{})
	if row.is_empty(): return []
	var effects: Array=[]
	# Only report a group that changes something (the source runs it on every entry edge).
	var before:=JSON.stringify([s.leaves,s.controls])
	for c in row.commands: _command(s,str(c),effects)
	if JSON.stringify([s.leaves,s.controls])==before: return []
	effects.push_front({"type":"group","group":int(row.group)})
	return effects

static func _command(s: Dictionary, raw: String, effects: Array) -> void:
	var b: PackedByteArray=raw.hex_decode();var target: int=b.decode_u16(2)
	match int(b[0]):
		20: effects.append({"type":"sound","request":int(b.decode_u16(4)),"object":target})
		9:
			if b[1]==0x20 and s.leaves.has(str(target)) and int(b[4]) in [2,3]:
				s.leaves[str(target)]=int(b[4])==3;effects.append({"type":"leaf","leaf":target,"linked":int(b[4])==3})
			elif b[1]==0x10 and s.controls.has(str(target)) and int(b[4]) in [2,3]:
				s.controls[str(target)]=int(b[4])==3;effects.append({"type":"control","control":target,"linked":int(b[4])==3})
			else: _receipt(s,raw,effects)
		_: _receipt(s,raw,effects)

static func _receipt(s: Dictionary, raw: String, effects: Array) -> void:
	effects.append({"type":"external","raw":raw})
	if raw not in s.receipts and s.receipts.size()<MAX_RECEIPTS: s.receipts.append(raw)
