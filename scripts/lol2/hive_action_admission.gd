extends RefCounted
## Native A3DEC action admission. Caller owns AA dispatch, globals and helper effects.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func run(saved: Variant, context: Variant, hooks: Dictionary) -> Dictionary:
	if not saved is Dictionary or not context is Dictionary: return {"error":"Invalid action context."}
	for field in ["b4","b5","b7","b9","ad"]:
		if not Numbers._integer(saved.get(field),255): return {"error":"Invalid actor field: "+field}
	if not Numbers._integer(saved.get("target"),4294967295): return {"error":"Invalid actor target."}
	if not Numbers._integer(context.get("action"),255) or not context.get("terminal") is bool:
		return {"error":"Invalid animation context."}
	for name in ["vertical","random","lookup","start","behavior"]:
		if not hooks.get(name) is Callable or not hooks[name].is_valid(): return {"error":"Missing action helper: "+name}
	var state: Dictionary = saved.duplicate(true)
	for field in ["b4","b5","b7","b9","ad","target"]: state[field] = int(state[field])
	if state.target == 0: state.target = 0x22574
	state.b9 &= 0xef
	if (state.b7&1) == 0:
		hooks.behavior.call(state)
		state.b4 &= 0xfc
		return {"state":state}
	var vertical: Variant = hooks.vertical.call(state,0x400000)
	if not Numbers._integer(vertical,255): return {"error":"Invalid vertical helper result."}
	if int(vertical) != 4:
		hooks.behavior.call(state)
		state.b4 &= 0xfc
		return {"state":state}
	if context.terminal:
		if int(context.action) == 5:
			var signed_ad: int = state.ad if state.ad < 128 else state.ad-256
			var maximum := 95 if signed_ad >= -2 else 63
			var random_value: Variant = hooks.random.call(state,maximum)
			if not Numbers._integer(random_value,maximum): return {"error":"Invalid random helper result."}
			state.b4 = (int(state.b4)&0xfc)|((int(random_value)>>5)&3)
			if signed_ad >= -2:
				signed_ad = state.ad if state.ad < 128 else state.ad-256
				if signed_ad > 2: state.b4 = (int(state.b4)&0xfc)|(((int(state.b4)&3)+1)&3)
		elif (int(state.b4)&3) != 0:
			state.b4 = (int(state.b4)&0xfc)|(((int(state.b4)&3)-1)&3)
		if (int(state.b4)&3) != 0:
			hooks.behavior.call(state)
			return {"state":state}
	else:
		if int(context.action) in [3,5]: return {"state":state}
		var signed_ad: int = state.ad if state.ad < 128 else state.ad-256
		if (int(state.b9)&0x60) != 0x40 or signed_ad > -2:
			hooks.behavior.call(state)
			return {"state":state}
	if (int(state.b5)&1) == 0:
		var selector: Variant = hooks.lookup.call(state,5,-1)
		if not (selector is int or selector is float) or (selector != -1 and not Numbers._integer(selector,2147483647)):
			return {"error":"Invalid action selector."}
		if selector != -1: hooks.start.call(state,int(selector),0)
	state.b4 &= 0xfc
	return {"state":state}
