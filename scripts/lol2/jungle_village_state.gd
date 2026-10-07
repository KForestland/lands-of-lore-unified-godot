extends RefCounted
## Source region2443/predicate154/group4354 admission; modern gate clock.
const DURATION := 1.2
const SPEECH_DURATION := 415.0/15.0
static func dialogue_initial() -> Dictionary:
	return {"started":false,"elapsed":0.0,"local15":0,"local46":0}
static func initial() -> Dictionary:
	return {"shared29":0,"local24":0,"elapsed":0.0,"dialogue":dialogue_initial(),"followup":preload("res://scripts/lol2/jungle_followup_state.gd").initial()}
static func validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid village gate state."
	for key in ["shared29","local24"]:
		var value = state.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < 0 or value > 255: return "Invalid village gate flag."
	if state.local24 > 1: return "Unsupported village trigger state."
	var time = state.get("elapsed")
	if not (time is int or time is float) or not is_finite(float(time)) or time < 0 or time > DURATION: return "Invalid village gate clock."
	if state.local24 == 0 and time != 0: return "Untriggered village gate is moving."
	if state.has("dialogue"):
		var d = state.dialogue
		if not d is Dictionary or not d.get("started") is bool: return "Invalid village dialogue."
		for key in ["local15","local46"]:
			var value = d.get(key)
			if not (value is int or value is float) or not is_finite(float(value)) or value != floorf(float(value)) or value < 0 or value > 1: return "Invalid villager flag."
		var clock = d.get("elapsed")
		if not (clock is int or clock is float) or not is_finite(float(clock)) or clock < 0 or clock > SPEECH_DURATION: return "Invalid village speech clock."
		if not d.started and (clock != 0 or d.local15 != 0): return "Unstarted village speech progressed."
		if d.started and (state.local24 != 1 or d.local46 != 0): return "Invalid village speech admission."
		if (d.local15 == 1) != (clock == SPEECH_DURATION): return "Inconsistent village speech completion."
	if state.has("followup"):
		var error := preload("res://scripts/lol2/jungle_followup_state.gd").validate(state.followup)
		if not error.is_empty(): return error
	return ""
static func admits(shared38: int, state: Dictionary) -> bool:
	return shared38 == 1 and state.shared29 == 0 and state.local24 == 0
