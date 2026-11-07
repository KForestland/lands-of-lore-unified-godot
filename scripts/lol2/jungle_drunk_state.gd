extends RefCounted
## Control110 encounter. Local7 belongs to village_alarm; writes are effects, never a duplicate saved bank.
## Modern presentation clock, source segment ordering and event predicates. Unknown commands remain receipts.
const SOURCE="res://scripts/lol2/jungle_drunk_source.json"
static func source() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func initial() -> Dictionary:
	return {"version":1,"present":true,"owner_state":0,"segment":-1,"elapsed":0.0,"passes":0,"hold":false,"focus":false,"blocked":false}
static func integer(v: Variant, lo: int, hi: int) -> bool:
	return (v is int or v is float) and is_finite(float(v)) and floorf(float(v))==float(v) and v>=lo and v<=hi
static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or s.size()!=9 or not integer(s.get("version"),1,1): return "Invalid drunk encounter packet."
	for k in ["present","hold","focus","blocked"]:
		if not s.get(k) is bool: return "Invalid drunk encounter flag."
	if not integer(s.get("owner_state"),0,1) or not integer(s.get("segment"),-1,2) or not integer(s.get("passes"),0,65535): return "Invalid drunk encounter state."
	var clock=s.get("elapsed")
	if not (clock is int or clock is float) or not is_finite(float(clock)) or clock<0: return "Invalid drunk encounter clock."
	if int(s.segment)==-1:
		if clock!=0 or s.hold: return "Stopped drunk encounter clock/hold."
	elif clock>=float(src.movie.segments[int(s.segment)].duration): return "Expired drunk encounter clock."
	if not s.present and (int(s.segment)!=-1 or s.hold or s.focus): return "Absent drunk encounter is active."
	return ""
static func operand(s: Dictionary, v: Dictionary, ctx: Dictionary) -> int:
	if v.has("immediate"): return int(v.immediate)
	if v.has("owner_state"): return int(s.owner_state)
	if v.has("local"): return int(ctx.get("locals",{}).get(str(int(v.local)),0))
	if v.has("shared"): return int(ctx.get("shared",{}).get(str(int(v.shared)),0))
	return 0
static func predicate(s: Dictionary, p: Variant, ctx: Dictionary) -> bool:
	if p==null: return true
	match str(p.op):
		"AND": return predicate(s,p.left.expression,ctx) and predicate(s,p.right.expression,ctx)
		"OR": return predicate(s,p.left.expression,ctx) or predicate(s,p.right.expression,ctx)
		"==": return operand(s,p.left,ctx)==operand(s,p.right,ctx)
		"!=": return operand(s,p.left,ctx)!=operand(s,p.right,ctx)
	return false
static func event(s: Dictionary, src: Dictionary, kind: String, owner: int, code: int, value: int, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if kind=="control" and not s.present: return effects
	for record in src.records:
		if record.owner_kind!=kind or int(record.owner)!=owner or int(record.event)!=code or int(record.value)!=value: continue
		if not predicate(s,record.predicate_expression,ctx): continue
		# Gate/admission owners retain their other commands. This module only receives their control110 commands.
		var own_group: bool=(kind=="control" and owner==110) or (kind=="prop" and owner in [484,485]) or (kind=="region" and int(record.group) in [7380,7434,7470,7506,7530,7560,7596,7626,7656,7686])
		for command in record.commands:
			var raw: String=command.raw_hex
			var b:=raw.hex_decode()
			if not own_group and not (b[1]==16 and b.decode_u16(2)==110): continue
			apply(s,b,effects)
	return effects
static func stop(s: Dictionary) -> void:
	s.segment=-1;s.elapsed=0.0;s.hold=false;s.focus=false
static func apply(s: Dictionary, b: PackedByteArray, effects: Array) -> void:
	var on_self: bool=b[1]==16 and b.decode_u16(2)==110
	match int(b[0]):
		198:
			if int(b[4])==7: effects.append({"type":"local7","value":int(b[5])})
			else: effects.append({"type":"external","raw":b.hex_encode()})
		206: effects.append({"type":"soul","delta":int(b[5]) if b[5]<128 else int(b[5])-256})
		8:
			if not on_self: effects.append({"type":"external","raw":b.hex_encode()});return
			match int(b[4]):
				0: pass # load-only; segment command follows in every startup group
				1: stop(s)
				7: s.passes=int(b.decode_u16(6))
				9,10:
					s.segment=int(b.decode_u16(6));s.elapsed=0.0
					effects.append({"type":"clip","segment":s.segment})
				_: effects.append({"type":"external","raw":b.hex_encode()})
		9:
			if on_self and b[4]==2: s.present=false;stop(s)
			else: effects.append({"type":"external","raw":b.hex_encode()})
		16:
			if on_self: s.owner_state=int(b[4])
			else: effects.append({"type":"external","raw":b.hex_encode()})
		2:
			if on_self and b[4] in [5,6]: s.focus=b[4]==5
			elif b[1]==1 and b[4] in [38,39]: s.hold=b[4]==38
			else: effects.append({"type":"external","raw":b.hex_encode()})
		197:
			if b.decode_u16(2)==3355 and b[4] in [4,5]: s.blocked=b[4]==4
			else: effects.append({"type":"external","raw":b.hex_encode()})
		18:
			if b[1]==1: effects.append({"type":"reposition","position":[b.decode_s16(4),b.decode_s16(8),-b.decode_s16(6)]})
			else: effects.append({"type":"external","raw":b.hex_encode()})
		_: effects.append({"type":"external","raw":b.hex_encode()})
static func advance(s: Dictionary, src: Dictionary, delta: float, ctx: Dictionary) -> Array:
	var effects: Array=[]
	if not is_finite(delta) or delta<=0 or int(s.segment)<0 or not s.present: return effects
	var duration: float=src.movie.segments[int(s.segment)].duration
	s.elapsed=float(s.elapsed)+delta
	if s.elapsed<duration: return effects
	# One source callback per world update; long stalls do not replay a backlog of dialogue.
	if int(s.passes)>0:
		s.elapsed=fmod(s.elapsed,duration)
		if int(s.passes)!=65535: s.passes=int(s.passes)-1
		effects=event(s,src,"control",110,6,1,ctx)
	else:
		stop(s)
		effects=event(s,src,"control",110,6,0,ctx)
	return effects

static func canonical(s: Dictionary) -> Dictionary:
	var out: Dictionary=s.duplicate(true)
	for key in ["version","owner_state","segment","passes"]:out[key]=int(out[key])
	out.elapsed=float(out.elapsed)
	return out
