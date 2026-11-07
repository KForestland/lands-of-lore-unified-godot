extends RefCounted
const DURATION := 501.0/15.0
static func initial() -> Dictionary:
	return {"shared18":0,"local18":0,"elapsed":0.0,"speech":0.0}
static func validate(s: Variant) -> String:
	if not s is Dictionary: return "Invalid village follow-up."
	for key in ["shared18","local18"]:
		var v = s.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or v != floorf(float(v)) or v < 0 or v > 255: return "Invalid follow-up flag."
	if not int(s.local18) in [0,1,2,40,50]: return "Unsupported follow-up phase."
	for key in ["elapsed","speech"]:
		var v = s.get(key)
		var limit := 1.2 if key == "elapsed" else DURATION
		if not (v is int or v is float) or not is_finite(float(v)) or v < 0 or v > limit: return "Invalid follow-up clock."
	if int(s.local18) in [0,1] and (s.elapsed != 0 or s.speech != 0): return "Inactive follow-up progressed."
	return ""
static func can_arm(s: Dictionary, shared29: int) -> bool:
	return s.local18 == 0 and shared29 == 0
static func can_speak(s: Dictionary, local46: int) -> bool:
	return s.local18 == 1 and s.shared18 == 0 and local46 == 0
