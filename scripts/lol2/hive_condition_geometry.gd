extends RefCounted
## Condition9 fixed-coordinate and condition41 whole-coordinate distances.
## Caller supplies x87 rounding (0 nearest,1 down,2 up,3 truncate), using
## 64-bit precision and masked exceptions. Live FPU state is not inferred.
## Coordinates remain in original axes and units, before Godot transforms.
const Validation = preload("res://scripts/lol2/hive_player_conditions.gd")

static func distance_startup(actor_fixed: Variant, point: Variant, fixed_units: bool = true) -> Dictionary:
	# Executable's initialized control word127F:53-bit precision, nearest-even,
	# masked exceptions. This models that configuration, not a live FPU capture.
	var validation := _validate_coordinates(actor_fixed,point,0)
	if validation.has("error"): return validation
	var delta: Array[int] = []
	for i in range(2):
		if fixed_units:
			delta.append((((int(point[i])<<16)-int(actor_fixed[i])+2147483648)&4294967295)-2147483648)
		else: delta.append(int(point[i])-(int(actor_fixed[i])>>16))
	return _startup_root(delta)

## Same original136594 helper for two objects with signed16.16 coordinates.
static func distance_between_startup(first: Variant, second: Variant) -> Dictionary:
	if not first is Array or first.size()!=2 or not second is Array or second.size()!=2:
		return {"error":"Invalid object coordinates."}
	var delta: Array[int] = []
	for i in range(2):
		if not Validation._integer(first[i],-2147483648,2147483647) or not Validation._integer(second[i],-2147483648,2147483647):
			return {"error":"Invalid object coordinate range."}
		delta.append(((int(second[i])-int(first[i])+2147483648)&4294967295)-2147483648)
	return _startup_root(delta)

static func _startup_root(delta: Array[int]) -> Dictionary:
	var xx := float(delta[0])*float(delta[0])
	var yy := float(delta[1])*float(delta[1])
	var value := sqrt(yy+xx)
	var nearest := int(floor(value))
	var fraction := value-float(nearest)
	if fraction > 0.5 or (fraction == 0.5 and nearest % 2 != 0): nearest += 1
	if nearest > 2147483647: return {"distance":-2147483648,"integer_invalid":true}
	return {"distance":nearest,"integer_invalid":false}

static func bind_startup_regions(context: Variant, actor_fixed: Variant, region9: Variant, point41: Variant, control_word: Variant) -> Dictionary:
	if not Validation._integer(control_word,0,65535) or int(control_word) != 0x127f:
		return {"error":"Unsupported startup geometry control word."}
	if not context is Dictionary: return {"error":"Invalid condition context."}
	if not region9 is Dictionary or not Validation._integer(region9.get("radius"),0,255):
		return {"error":"Invalid condition9 region."}
	var distance := distance_startup(actor_fixed,region9.get("coordinates"))
	if distance.has("error"): return distance
	var bound: Dictionary = context.duplicate(true)
	bound.distance9 = distance.distance
	bound.radius9 = int(region9.radius)
	bound.geometry41_enabled = point41 != null
	bound.distance41 = 0
	bound.radius41 = 0
	if point41 != null:
		if not point41 is Dictionary or not Validation._integer(point41.get("radius"),0,255):
			return {"error":"Invalid condition41 point."}
		var other := distance_startup(actor_fixed,point41.get("coordinates"),false)
		if other.has("error"): return other
		bound.distance41 = other.distance
		bound.radius41 = int(point41.radius)
	return {"context":bound,"integer_invalid":distance.integer_invalid}

static func bind_condition9(context: Variant, actor_fixed: Variant, region: Variant, rounding_mode: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid condition context."}
	if not region is Dictionary or not Validation._integer(region.get("radius"),0,255):
		return {"error":"Invalid condition9 region."}
	var result := distance9(actor_fixed,region.get("coordinates"),rounding_mode)
	if result.has("error"): return result
	var bound: Dictionary = context.duplicate(true)
	bound.distance9 = result.distance
	bound.radius9 = int(region.radius)
	return {"context":bound,"integer_invalid":result.integer_invalid}

static func bind_condition41(context: Variant, actor_fixed: Variant, point: Variant, rounding_mode: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid condition context."}
	var bound: Dictionary = context.duplicate(true)
	# Native AAC06 skips the distance calculation when the optional point is null.
	bound.geometry41_enabled = point != null
	bound.distance41 = 0
	bound.radius41 = 0
	if point != null:
		if not point is Dictionary or not Validation._integer(point.get("radius"),0,255):
			return {"error":"Invalid condition point."}
		var result := distance41(actor_fixed,point.get("coordinates"),rounding_mode)
		if result.has("error"): return result
		bound.distance41 = result.distance
		bound.radius41 = int(point.radius)
	return {"context":bound}

static func distance41(actor_fixed: Variant, point: Variant, rounding_mode: Variant) -> Dictionary:
	var validation := _validate_coordinates(actor_fixed,point,rounding_mode)
	if validation.has("error"): return validation
	var dx := (int(actor_fixed[0]) >> 16) - int(point[0])
	var dy := (int(actor_fixed[1]) >> 16) - int(point[1])
	return {"distance":_rounded_root(dx*dx+dy*dy,int(rounding_mode))}

static func distance9(actor_fixed: Variant, point: Variant, rounding_mode: Variant) -> Dictionary:
	var validation := _validate_coordinates(actor_fixed,point,rounding_mode)
	if validation.has("error"): return validation
	var dx := (((int(point[0])<<16)-int(actor_fixed[0])+2147483648)&4294967295)-2147483648
	var dy := (((int(point[1])<<16)-int(actor_fixed[1])+2147483648)&4294967295)-2147483648
	var xx := dx*dx
	var yy := dy*dy
	# Avoid overflowing int64 at (-2^31,-2^31). Any sum >=2^62 already
	# exceeds the signed32 FISTP range, including under downward rounding.
	if xx >= 4611686018427387904 or yy >= 4611686018427387904-xx:
		return {"distance":-2147483648,"integer_invalid":true}
	var result := _rounded_root(xx+yy,int(rounding_mode))
	if result > 2147483647: return {"distance":-2147483648,"integer_invalid":true}
	return {"distance":result,"integer_invalid":false}

static func _validate_coordinates(actor_fixed: Variant, point: Variant, rounding_mode: Variant) -> Dictionary:
	if not Validation._integer(rounding_mode,0,3): return {"error":"Invalid distance rounding mode."}
	if not actor_fixed is Array or actor_fixed.size() != 2 or not point is Array or point.size() != 2:
		return {"error":"Invalid condition coordinates."}
	for i in range(2):
		if not Validation._integer(actor_fixed[i],-2147483648,2147483647) or not Validation._integer(point[i],-32768,32767):
			return {"error":"Invalid condition coordinate range."}
	return {}

static func _rounded_root(squared: int, rounding_mode: int) -> int:
	# The coordinate bounds keep squares within int64. Integer corrections make
	# the rounding decision independent of the host sqrt implementation.
	var root := int(sqrt(float(squared)))
	while root*root > squared: root -= 1
	while (root+1)*(root+1) <= squared: root += 1
	if int(rounding_mode) == 0 and squared-root*root > root: root += 1
	elif int(rounding_mode) == 2 and squared != root*root: root += 1
	return root
