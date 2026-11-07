extends RefCounted
## Player virtual84 and surviving-target result-write ordering; display is output.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func adjust(context: Variant, amount: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid player health context."}
	if not Numbers._integer(context.get("current"),1000000) or not Numbers._integer(context.get("maximum"),1000000) or int(context.maximum)<1: return {"error":"Invalid player current/maximum health."}
	if not Numbers._integer(context.get("flags229"),255) or not Numbers._integer(amount,8192): return {"error":"Invalid health adjustment control."}
	var current := int(context.current)
	var display := current!=0 and (int(context.flags229)&2)==0
	if display: current=mini(current+int(amount),int(context.maximum))
	return {"current":current,"display":display}

static func finalize(context: Variant, result: Variant) -> Dictionary:
	if not context is Dictionary or not Numbers._integer(context.get("current"),1000000): return {"error":"Invalid current health."}
	if not result is Dictionary: return {"error":"Invalid damage result."}
	for field in ["loss","remaining"]:
		if not Numbers._integer(result.get(field),1000000): return {"error":"Invalid damage result field: "+field}
	if int(result.loss)>int(context.current) or int(result.remaining)!=int(context.current)-int(result.loss): return {"error":"Damage result disagrees with current health."}
	if not result.get("virtual84") is Array: return {"error":"Missing virtual84 requests."}
	var state: Dictionary = context.duplicate(true)
	var displays: Array[int] = []
	for amount in result.virtual84:
		var update := adjust(state,amount)
		if update.has("error"): return {"error":"Damage virtual84 requires valid maximum/flags: "+update.error}
		state.current=update.current
		if update.display: displays.append(update.current)
	if int(result.loss)!=0:
		if int(result.remaining)==0: return {"error":"Lethal damage requires player continuation."}
		state.current=int(result.remaining)
	return {"current":int(state.current),"displays":displays}
