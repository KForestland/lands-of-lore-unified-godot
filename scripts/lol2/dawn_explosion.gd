extends RefCounted
## Original mode1 Explosion98 first damage pass. World enumeration is supplied.
const Numbers = preload("res://scripts/lol2/save_value_rules.gd")
const RADIUS := 160*65536

@warning_ignore("integer_division")
static func first_pass(applied: Variant, neighbors: Variant) -> Dictionary:
	if not applied is bool or not neighbors is Array: return {"error":"Invalid explosion state/neighbors."}
	# Validate the whole batch before returning a state change or any damage.
	for target in neighbors:
		if not target is Dictionary: return {"error":"Invalid explosion neighbor."}
		for field in ["id","distance"]:
			if not Numbers.integer(target.get(field),2147483647): return {"error":"Invalid neighbor "+field}
		if int(target.id)==0 or not Numbers.integer(target.get("kind"),255) or not Numbers.integer(target.get("flags"),4294967295) or not target.get("direct") is bool: return {"error":"Invalid neighbor identity/filter."}
	var requests: Array = []
	if not applied:
		for target in neighbors:
			if (int(target.flags)&0x4000)==0 or int(target.kind) in [4,5]: continue
			var distance := 0 if target.direct else int(target.distance)
			if distance>=RADIUS: continue
			var amount := ((RADIUS-distance)>>16)*20/161
			if amount==0: continue
			requests.append({"target":int(target.id),"mask":16,"signature":5,"kind":2,"effect":98,"amount":amount})
	# Caller must store this marker before dispatching requests (including reentrant callbacks).
	return {"applied":true,"requests":requests}
