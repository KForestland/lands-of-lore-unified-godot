extends RefCounted
## Source local55 predicates and ordered first-use movie/level-change effects.
const DURATION := 478484.0/22050.0
static func initial() -> Dictionary:
	return {"local55":0,"phase":"idle","elapsed":0.0}
static func validate(s: Variant) -> String:
	if not s is Dictionary: return "Invalid departure state."
	var local = s.get("local55")
	if not (local is int or local is float) or not is_finite(float(local)) or local != floorf(local) or local < 0 or local > 255: return "Invalid departure local55."
	if not s.get("phase") is String or s.phase not in ["idle","movie","arrival","arrived"]: return "Invalid departure phase."
	var elapsed = s.get("elapsed")
	if not (elapsed is int or elapsed is float) or not is_finite(float(elapsed)) or elapsed < 0: return "Invalid departure clock."
	if s.phase == "movie":
		if local != 1 or elapsed >= DURATION: return "Invalid active departure movie."
	elif elapsed != 0 or (s.phase in ["arrival","arrived"] and local != 1): return "Invalid departure phase/clock."
	return ""
static func begin(s: Dictionary) -> bool:
	if not validate(s).is_empty() or s.phase != "idle" or int(s.local55) not in [0,1]: return false
	s.phase = "movie" if s.local55 == 0 else "arrival"
	s.local55 = 1
	s.elapsed = 0.0
	return true
static func advance(s: Dictionary, delta: float) -> void:
	if not is_finite(delta) or delta < 0 or s.phase != "movie": return
	s.elapsed += delta
	if s.elapsed >= DURATION:
		s.elapsed = 0.0
		s.phase = "arrival"
