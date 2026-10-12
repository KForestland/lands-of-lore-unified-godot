extends RefCounted
## Source frame events; 15fps and supplied base/range are host adapters.
const Core=preload("res://scripts/lol2/hive_attack_runtime.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const CONTRACT={"version":1,"clips":[{"selector":11,"resource":1549,"frames":18,"interval":1024,"events":[{"kind":1,"frame":11,"raw_hex":"010b3c000c010400"},{"kind":2,"frame":11,"raw_hex":"020bf20180000a14"}]},{"selector":12,"resource":1053,"frames":16,"interval":1024,"events":[{"kind":2,"frame":10,"raw_hex":"020aee0180000a14"},{"kind":1,"frame":11,"raw_hex":"010b64000c010400"}]},{"selector":13,"resource":1531,"frames":18,"interval":1024,"events":[{"kind":1,"frame":8,"raw_hex":"0108140004000400"},{"kind":2,"frame":8,"raw_hex":"0208210280000a14"}]},{"selector":14,"resource":1203,"frames":16,"interval":1024,"events":[{"kind":2,"frame":8,"raw_hex":"02081c0280000a14"},{"kind":1,"frame":9,"raw_hex":"0109320004000400"}]}]}
const LAST={11:17,12:15,13:17,14:15}
static func initial(selector: int) -> Dictionary:
	return {"selector":selector,"frame":0,"timer":0,"fraction":0.0,"flags":1}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not Values.integer(value.get("selector"),14) or not LAST.has(int(value.selector)): return "Invalid warrior attack selector."
	if not Values.integer(value.get("frame"),LAST[int(value.selector)]-1) or not Values.integer(value.get("timer"),1023): return "Invalid warrior attack clock."
	if not Values.integer(value.get("flags"),17) or int(value.flags) not in [1,17]: return "Invalid warrior attack flags."
	var f=value.get("fraction")
	if not (f is int or f is float) or not is_finite(float(f)) or f<0 or f>=1: return "Invalid warrior attack fraction."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"selector":int(value.selector),"frame":int(value.frame),"timer":int(value.timer),"fraction":float(value.fraction),"flags":int(value.flags)}
static func advance(value: Dictionary, delta: float, admitted: bool, base: int=6) -> Dictionary:
	var error:=validate(value)
	if not error.is_empty(): return {"error":error}
	if not is_finite(delta) or delta<0 or base<0 or base>255: return {"error":"Invalid warrior attack update."}
	var units:=float(value.fraction)+delta*15360.0
	# Bound the step at the first terminal event; never wrap into a second attack.
	var until_terminal:=int(value.timer)+(int(LAST[int(value.selector)])-int(value.frame)-1)*1024+1
	var ticks:=int(minf(floorf(units),float(until_terminal)))
	var core=Core.new(CONTRACT)
	var saved: Dictionary=core.checkpoint()
	saved.merge({"selector":int(value.selector),"frame":int(value.frame),"timer":int(value.timer),"flags":int(value.flags),"base":base,"gate":admitted},true)
	error=core.restore(saved)
	if not error.is_empty(): return {"error":error}
	var result: Dictionary=core.advance_native(ticks)
	if result.has("error"): return result
	var terminal:=false
	for event in result.events:
		if event.type=="terminal": terminal=true
	value.frame=int(result.state.frame);value.timer=int(result.state.timer);value.flags=int(result.state.flags)
	value.fraction=0.0 if terminal else units-floorf(units)
	return {"events":result.events,"terminal":terminal}
