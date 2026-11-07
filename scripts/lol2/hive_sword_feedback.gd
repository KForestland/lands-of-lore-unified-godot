extends RefCounted
## Player virtual74 mode1 reward preparation, after target/loss admission.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func reward_seed(context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid sword feedback context."}
	for field in ["scale","level"]:
		if not Numbers._integer(context.get(field),255): return {"error":"Invalid sword feedback scale."}
	if int(context.scale)<1 or not Numbers._integer(context.get("remaining"),65535) or not Numbers._integer(context.get("special"),0xffffffff): return {"error":"Invalid sword feedback request."}
	var multiplier := 10 if int(context.remaining)==0 else 3 if int(context.special)!=0 else 1
	return {"base":int(context.scale)*multiplier,"difference":int(context.scale)-int(context.level),"byte1b2":0}

@warning_ignore("integer_division")
static func scale_reward(base: Variant, difference: Variant) -> Dictionary:
	if not Numbers._integer(base,2550) or int(base)<1: return {"error":"Invalid reward base."}
	if not (difference is int or difference is float) or not is_finite(float(difference)) or float(difference)!=floor(float(difference)) or difference < -255 or difference > 255: return {"error":"Invalid reward difference."}
	var value := int(base);var delta := int(difference);var award := 0
	if delta==-3: award=value/4
	elif delta==-2: award=value-value/2
	elif delta==-1: award=value-value/4
	elif delta==0: award=value
	elif delta==1: award=value+value/4
	elif delta==2: award=value+value/2
	elif delta==3: award=value*2-value/4
	elif delta==4: award=value*2
	elif delta>4: award=value*2+value/2
	return {"award":award}
