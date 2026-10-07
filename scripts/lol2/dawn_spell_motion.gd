extends RefCounted
## Original spell32 update tail: movement request only, not collision application.
## Native fixed-point clock, planar target distance and vertical difference supplied.
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")
## Original GLOBAL effect definition0, selector1 (spell32 variant1).
const SPRITE_HEIGHT := 20

static func player_target(position: Array, height: int, offset: int) -> Dictionary:
	return target_snapshot({"position":position,"player_height":height,"player_offset":offset,"sprite_height":SPRITE_HEIGHT})

@warning_ignore("integer_division")
static func target_snapshot(context: Variant) -> Dictionary:
	if not context is Dictionary or not context.get("position") is Array or context.position.size()!=3: return {"error":"Invalid spell target."}
	var point: Array[int]=[]
	for coordinate in context.position:
		if not (coordinate is int or coordinate is float) or not is_finite(float(coordinate)) or float(coordinate)!=floorf(float(coordinate)) or absf(float(coordinate))>0x3fff0000: return {"error":"Unsupported fixed-point target coordinate."}
		point.append(int(coordinate))
	for field in ["player_height","player_offset","sprite_height"]:
		if not Numbers.integer(context.get(field),255): return {"error":"Invalid spell target height."}
	var height: int=(int(context.player_height)-int(context.player_offset))&255
	point[2]+=(height-int(context.sprite_height)/2)*65536
	return {"position":point}

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
