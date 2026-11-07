extends RefCounted
## A4E54 after a valid target's approximate distance has been calculated.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func target_admission(actor: Variant, target_flags: Variant) -> Dictionary:
	if not actor is Dictionary or not Numbers._integer(actor.get("target"),4294967295) or not Numbers._integer(actor.get("b7"),255):
		return {"error":"Invalid target admission actor."}
	if int(actor.target)!=0 and not Numbers._integer(target_flags,255): return {"error":"Missing target flags15."}
	var valid := int(actor.target)!=0 and (int(target_flags)&16)==0
	var state: Dictionary = actor.duplicate(true)
	if not valid:
		state.target=0;state.b7=int(actor.b7)&254
		return {"state":state,"valid":false,"distance":0x27100000,"threshold":0x27100000,"edge_distance":0x27100000}
	return {"state":state,"valid":true}

static func evaluate_target(actor: Variant, target_flags: Variant, points: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	var admitted := target_admission(actor,target_flags)
	if admitted.has("error") or not admitted.valid: return admitted
	var measured := preload("res://scripts/lol2/hive_spatial_admission.gd").horizontal_approximate(points)
	if measured.has("error"): return measured
	var result := run(admitted.state,measured.distance,reach,obstruction,draw)
	if not result.has("error"):
		result.valid=true;result.distance=measured.distance
	return result

static func run(actor: Variant, distance: Variant, reach: Variant, obstruction: Variant, draw: Variant) -> Dictionary:
	if not actor is Dictionary: return {"error":"Invalid reach actor."}
	for field in ["byte9e","b4","b7"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid reach field: "+field}
	if not (distance is int or distance is float) or not is_finite(float(distance)) or distance != floor(float(distance)) or distance < -2147483648 or distance > 2147483647:
		return {"error":"Invalid approximate target distance."}
	var state: Dictionary = actor.duplicate(true)
	var threshold := -1
	var calls: Array = []
	var admitted := false
	if (int(actor.byte9e)&6) != 0:
		# Definition61 is signed16, shifted into the source fixed-point domain.
		if not Numbers._integer(reach,65535): return {"error":"Invalid definition reach word."}
		threshold = (int(reach) if int(reach)<32768 else int(reach)-65536)<<16
		if int(distance) <= threshold:
			if not Numbers._integer(obstruction,4294967295): return {"error":"Missing obstruction result."}
			calls.append("obstruction")
			if int(obstruction) == 0:
				admitted = true
				if (int(actor.b7)&1) == 0 and (int(actor.b4)&3) == 0:
					if not Numbers._integer(draw,95): return {"error":"Missing attack-delay random draw."}
					calls.append("random")
					state.b4 = (int(actor.b4)&252)|(int(draw)>>5)
			else: threshold = -1
	state.b7 = (int(actor.b7)|1) if admitted else (int(actor.b7)&254)
	return {"state":state,"threshold":threshold,"calls":calls}
