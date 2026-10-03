extends RefCounted
## Source6778 -> ceiling794 completion ->6250 -> floor1216 completion ->6806.
## Surface speeds in world units/second are explicit modern clock adapters.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const CLOSE_SECONDS=128.0/125.0
const LOWER_SECONDS=313.0/25.0
const OPEN_SECONDS=100.0/50.0
static func initial() -> Dictionary:
	return {"version":1,"phase":0,"elapsed":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not Values.integer(value.get("version"),1) or value.version!=1 or not Values.integer(value.get("phase"),3): return "Invalid Hive boulder sequence."
	var t=value.get("elapsed")
	if not (t is int or t is float) or not is_finite(float(t)) or t<0: return "Invalid Hive boulder clock."
	if value.phase==0 and t!=0: return "Idle boulder sequence has elapsed time."
	if value.phase==1 and t>=CLOSE_SECONDS: return "Ceiling completion was not dispatched."
	if value.phase==2 and t>=LOWER_SECONDS: return "Floor completion was not dispatched."
	if value.phase==3 and t>OPEN_SECONDS: return "Boulder exit clock exceeded its target."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"phase":int(value.phase),"elapsed":float(value.elapsed)}
static func restore(value: Variant) -> Dictionary:
	var error:=validate(value)
	if not error.is_empty(): return {"error":error}
	return {"state":canonical(value)}
static func begin(value: Dictionary) -> Array:
	if not validate(value).is_empty() or value.phase!=0: return []
	value.phase=1
	return [6778]
static func advance(value: Dictionary, delta: float) -> Dictionary:
	var error:=validate(value)
	if not error.is_empty(): return {"error":error}
	if not is_finite(delta) or delta<0: return {"error":"Invalid Hive boulder update."}
	var groups: Array=[]
	var remaining:=delta
	while value.phase in [1,2] and remaining>0:
		var duration: float=CLOSE_SECONDS if value.phase==1 else LOWER_SECONDS
		var used:=minf(remaining,duration-float(value.elapsed))
		value.elapsed=float(value.elapsed)+used
		remaining-=used
		if value.elapsed>=duration:
			groups.append(6250 if value.phase==1 else 6806)
			value.phase=int(value.phase)+1
			value.elapsed=0.0
		else: break
	if value.phase==3: value.elapsed=minf(OPEN_SECONDS,float(value.elapsed)+remaining)
	return {"groups":groups}
static func offsets(value: Dictionary) -> Dictionary:
	var close:=minf(128.0,float(value.elapsed)*125.0) if value.phase==1 else 128.0 if value.phase>=2 else 0.0
	var lower:=minf(313.0,float(value.elapsed)*25.0) if value.phase==2 else 313.0 if value.phase==3 else 0.0
	var opening:=minf(100.0,float(value.elapsed)*50.0) if value.phase==3 else 0.0
	# Translate each complete original quad: retain its source slope and UVs.
	return {"ceiling794":-close,"floor1216":-lower,"floor1217":-lower,"floor1218":-lower,"ceiling801":opening}
