extends RefCounted
## Native prop214: selector0 loops39 frames; E selects1 (61 frames), mode8.
## F2310 cadence branch0x20 adds template49<<8 =1024 source clock units.
## Caller must supply source clock units; wall-clock conversion is deliberately external.
const FRAME_UNITS := 1024.0
static func initial() -> Dictionary:
	return {"version":1,"phase":"idle","frame":0,"remaining":0.0}
static func validate(value: Variant) -> String:
	if value==null:return ""
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1 or not value.get("phase") in ["idle","active","gone"]:return "Invalid Belial checkpoint."
	var frame=value.get("frame")
	if not (frame is int or frame is float) or not is_finite(float(frame)) or float(frame)!=floor(float(frame)):return "Invalid Belial frame."
	var last:=38 if value.phase=="idle" else 60
	if frame<0 or frame>last or (value.phase=="active" and frame==60):return "Invalid Belial sequence."
	var remaining=value.get("remaining")
	if not (remaining is int or remaining is float) or not is_finite(float(remaining)) or remaining<0 or remaining>FRAME_UNITS:return "Invalid Belial clock."
	if value.phase=="gone" and (frame!=60 or remaining!=0):return "Invalid Belial completion."
	return ""
static func use(state: Dictionary) -> bool:
	if state.phase=="gone":return false
	# Repeated E selects the same selector; F2944 preserves its frame.
	if state.phase=="active":return true
	# Native selector change resets frame, but does not reset owner34 cadence remainder.
	state.phase="active";state.frame=0
	return true
static func advance_units(state: Dictionary, units: float) -> bool:
	if state.phase=="gone" or not is_finite(units) or units<=0:return false
	state.remaining-=units
	# Native timer compares signed remainder<0, preserving exact-zero boundary.
	while state.remaining<0:
		state.remaining+=FRAME_UNITS
		if state.phase=="idle":state.frame=(int(state.frame)+1)%39
		else:
			state.frame+=1
			if state.frame==60:
				# Source event6/value2 group4490 stops/unlinks owner, local12=1.
				state.phase="gone";state.remaining=0.0
				return true
	return false
