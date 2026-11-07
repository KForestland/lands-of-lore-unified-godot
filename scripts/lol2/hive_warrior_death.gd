extends RefCounted
## Ordinary HIVEW outcome: zero health selects wounded death20, then corpse21.
## Native frame updates; 15fps host conversion and migration are explicit adapters.
const Core=preload("res://scripts/lol2/hive_attack_runtime.gd")
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")
const CONTRACT={"version":1,"clips":[{"selector":20,"frames":13,"interval":1024,"events":[{"kind":2,"frame":0,"raw_hex":"0200530380000a14"}]},{"selector":21,"frames":1,"interval":1024,"events":[]}]}
static func initial(corpse: bool=false) -> Dictionary:
	return {"corpse":corpse,"frame":0,"timer":0,"fraction":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not value.get("corpse") is bool: return "Invalid warrior death phase."
	if not Numbers.integer(value.get("frame"),0 if value.corpse else 12) or not Numbers.integer(value.get("timer"),1023): return "Invalid warrior death frame or clock."
	var fraction=value.get("fraction")
	if not (fraction is int or fraction is float) or not is_finite(float(fraction)) or fraction<0 or fraction>=1: return "Invalid warrior death clock fraction."
	if value.corpse and (value.timer!=0 or fraction!=0): return "Corpse clock must be stopped."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"corpse":bool(value.corpse),"frame":int(value.frame),"timer":int(value.timer),"fraction":float(value.fraction)}
static func advance(value: Dictionary, delta: float) -> void:
	if value.corpse or not is_finite(delta) or delta<=0: return
	if value.frame==12:
		value.merge(initial(true),true)
		return
	var units:=float(value.fraction)+delta*15360.0
	var ticks:=int(floorf(units))
	value.fraction=units-float(ticks)
	var core=Core.new(CONTRACT)
	var saved: Dictionary=core.checkpoint()
	saved.merge({"selector":20,"frame":int(value.frame),"timer":int(value.timer)},true)
	var restore_error: String=core.restore(saved)
	if not restore_error.is_empty(): push_error(restore_error);return
	while ticks>0:
		var amount:=mini(ticks,32767)
		ticks-=amount
		var result: Dictionary=core.advance_native(amount)
		if result.has("error"): push_error(result.error);return
		value.frame=int(result.state.frame);value.timer=int(result.state.timer)
		for event in result.events:
			if event.type=="terminal":
				value.merge(initial(true),true)
				return
