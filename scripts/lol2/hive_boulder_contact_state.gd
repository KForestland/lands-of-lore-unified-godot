extends RefCounted
## Saved player impulse; seconds-based decay is a modern movement adapter.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func initial() -> Dictionary:
	return {"version":1,"angle":0,"magnitude":0.0}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not Values.integer(value.get("version"),1) or value.version!=1 or not Values.integer(value.get("angle"),65535): return "Invalid boulder contact impulse."
	var magnitude=value.get("magnitude")
	if not (magnitude is int or magnitude is float) or not is_finite(float(magnitude)) or magnitude<0 or magnitude>255: return "Invalid boulder impulse magnitude."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	return {"version":1,"angle":int(value.angle),"magnitude":float(value.magnitude)}
