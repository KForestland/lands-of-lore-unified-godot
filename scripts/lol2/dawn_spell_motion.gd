extends RefCounted
## Original spell32 update tail: movement request only, not collision application.
## Native fixed-point clock, planar target distance and vertical difference supplied.
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")

@warning_ignore("integer_division")
static func request(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid spell motion context."}
	for field in {"heading":65535,"delta":131072,"planar_distance":6553600}:
		if not Numbers.integer(context.get(field),int({"heading":65535,"delta":131072,"planar_distance":6553600}[field])): return {"error":"Unsupported spell motion input."}
	var height=context.get("height_delta")
	if not (height is int or height is float) or not is_finite(float(height)) or float(height)!=floorf(float(height)) or height < -1310720 or height > 1966080: return {"error":"Unsupported spell height difference."}
	var distance: int=int(context.delta)*500/60
	var vertical:=int(height)
	if int(context.planar_distance)>distance:
		# SHRD16 floors the signed product; integer division would truncate negatives.
		var fraction: int=(distance*65536)/int(context.planar_distance)
		vertical=(vertical*fraction)>>16
	return {"heading":int(context.heading),"distance":distance,"vertical":vertical}
