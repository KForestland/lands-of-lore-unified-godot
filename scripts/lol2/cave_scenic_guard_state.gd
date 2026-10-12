extends RefCounted
## Exact source consumers with saved command cursors. Environment helpers and event
## admission are supplied. Unacknowledged commands block; no effect is discarded.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Effects=preload("res://scripts/lol2/cave_scenic_guard_effects.gd")
const SOURCE="res://scripts/lol2/cave_scenic_guard_source.json"
static func source() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func initial() -> Dictionary:
	return {"version":1,"present":true,"prop_present":true,"prop223_present":false,"selector":0,"elapsed":0.0,"actor_state":0,"prop_state":0,"actor_mode":0,"local0":0,"movables":{"21":false,"22":false},"seen":[],"pending":[],"effects":Effects.initial()}
static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or not Values.integer(s.get("version"),1) or s.version!=1: return "Invalid scenic guard packet."
	for key in ["present","prop_present","prop223_present"]:
		if not s.get(key) is bool: return "Invalid scenic guard presence."
	for key in ["actor_state","prop_state","local0"]:
		if not Values.integer(s.get(key),1): return "Invalid scenic guard state."
	if not Values.integer(s.get("actor_mode"),4) or int(s.actor_mode) not in [0,4] or not Values.integer(s.get("selector"),4): return "Invalid scenic guard pose."
	if not s.get("movables") is Dictionary or s.movables.keys().size()!=2 or not s.movables.get("21") is bool or not s.movables.get("22") is bool: return "Invalid scenic movable receipts."
	var t=s.get("elapsed")
	if not (t is int or t is float) or not is_finite(float(t)) or t<0 or t>duration(src,int(s.selector)): return "Invalid scenic guard clock."
	if not s.get("seen") is Array or not s.get("pending") is Array: return "Invalid scenic guard queue."
	if s.has("effects"):
		var effect_error:=Effects.validate(s.effects)
		if not effect_error.is_empty():return effect_error
	var seen: Array=[]
	for group in s.seen:
		if not group is String or not src.groups.has(group) or group in seen: return "Invalid scenic guard event history."
		seen.append(group)
	var pending: Array=[]
	for entry in s.pending:
		if not entry is Dictionary or not entry.get("group") is String or entry.group not in seen or entry.group in pending: return "Invalid scenic guard pending group."
		if not Values.integer(entry.get("cursor"),src.groups[entry.group].commands.size()-1): return "Invalid scenic guard command cursor."
		pending.append(entry.group)
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var copy:=s.duplicate(true)
	if not copy.has("effects"):copy.effects=Effects.initial()
	copy.effects=Effects.canonical(copy.effects)
	for key in ["version","selector","actor_state","prop_state","actor_mode","local0"]:copy[key]=int(copy[key])
	copy.elapsed=float(copy.elapsed)
	for entry in copy.pending:entry.cursor=int(entry.cursor)
	return copy
static func duration(src: Dictionary, selector: int) -> float:
	var row: Dictionary=src.selectors[str(selector)]
	# Existing8fps adapter, retaining source1280/1024 interval ratio for collapse.
	return float(row.frames)*float(row.native_interval_units)/8192.0
static func advance(s: Dictionary, src: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta<=0 or not s.present:return
	var full:=duration(src,int(s.selector))
	var next:=snappedf(float(s.elapsed)+delta,1.0/1024)
	s.elapsed=fmod(next,full) if s.selector<3 else minf(next,full)
static func frame(s: Dictionary,src: Dictionary) -> int:
	var row: Dictionary=src.selectors[str(int(s.selector))]
	return mini(int(s.elapsed*8192.0/float(row.native_interval_units)),int(row.frames)-1)
## Entry names denote supplied, already-admitted source events, not user gestures.
static func enqueue(s: Dictionary, event: String) -> bool:
	var group: String={"supplied_hit":"5926","prop_event0":"6364","actor_event3":"14410","region969":"560"}.get(event,"")
	if group.is_empty() or group in s.seen:return false
	if event=="supplied_hit" and (not s.prop_present or s.prop_state!=0):return false
	if event=="actor_event3" and (not s.present or s.actor_state!=1):return false
	if event=="region969" and s.local0!=0:return false
	s.seen.append(group);s.pending.append({"group":group,"cursor":0});return true
static func internal(c: Dictionary) -> bool:
	return (c.kind==2 and c.target==55 and ((c.op==13 and int(c.argument) in [4,6]) or c.op==16 or (c.op==9 and c.argument==2))) or (c.kind==3 and c.target==574 and c.op==16) or (c.op==198 and c.raw_hex=="c60000000001")
static func apply(s: Dictionary, c: Dictionary) -> void:
	if c.kind==2 and c.target==55:
		if c.op==13 and c.argument==4:s.selector=int(c.value);s.elapsed=0.0
		elif c.op==13 and c.argument==6:s.actor_mode=int(c.value)
		elif c.op==16:s.actor_state=int(c.argument)
		elif c.op==9 and c.argument==2:s.present=false
	elif c.kind==3 and c.target==574:
		if c.op==16:s.prop_state=int(c.argument)
		elif c.op==9 and c.argument==2:s.prop_present=false
	elif c.kind==3 and c.target==223 and c.op==9 and c.argument==3:s.prop223_present=true
	elif c.kind==4 and int(c.target) in [21,22] and c.op==9 and c.argument==3:s.movables[str(int(c.target))]=true
	elif c.op==198 and c.raw_hex=="c60000000001":s.local0=1
## Each group retains its own cursor so a supplied completion event can run while
## an earlier opcode8 waits. External callback must commit its effect before true.
## It must return false (without mutation) for unavailable/not-yet-complete effects.
static func drain(s: Dictionary,src: Dictionary,effect: Callable=Callable()) -> Dictionary:
	var blocked: Array=[];var applied:=0
	for entry in s.pending.duplicate():
		var commands: Array=src.groups[entry.group].commands
		while int(entry.cursor)<commands.size():
			var c: Dictionary=commands[int(entry.cursor)]
			if not internal(c):
				if not effect.is_valid() or effect.call(c.duplicate(true))!=true:
					blocked.append({"group":entry.group,"cursor":entry.cursor,"command":c.duplicate(true)});break
			apply(s,c);entry.cursor+=1;applied+=1
		if int(entry.cursor)==commands.size():s.pending.erase(entry)
	return {"applied":applied,"blocked":blocked}
