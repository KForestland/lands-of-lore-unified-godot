extends RefCounted
## A77A1 outcome phase. World/group preparation must precede this operation.
## Helpers mutate the private state and must stage external effects for commit.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const BYTE_FIELDS = ["flags14","flags15","a8","a9","aa","ab","ae","b4","b5","b6","b7"]

static func _validate(state: Variant) -> String:
	if not state is Dictionary: return "Invalid outcome actor."
	for field in BYTE_FIELDS:
		if not Numbers._integer(state.get(field),255): return "Invalid outcome field: "+field
	if not Numbers._integer(state.get("health"),65535): return "Invalid outcome health."
	return ""

static func _call(hooks: Dictionary, name: String, state: Dictionary, args: Array = []) -> Dictionary:
	var result: Variant = hooks[name].callv([state]+args)
	if result is Dictionary and result.has("error"): return result
	var error := _validate(state)
	return {"error":error} if not error.is_empty() else {}

static func _select(state: Dictionary, hooks: Dictionary, action: int, variant: int) -> Dictionary:
	if (int(state.b5)&1)!=0: return {"selected":false}
	var selector: Variant = hooks.lookup.call(state,action,variant)
	var error := _validate(state)
	if not error.is_empty(): return {"error":error}
	if selector != -1 and not Numbers._integer(selector,255): return {"error":"Invalid outcome selector."}
	if selector == -1: return {"selected":false}
	var result := _call(hooks,"start",state,[int(selector),0])
	if result.has("error"): return result
	return {"selected":true}

static func run(saved: Variant, context: Variant, hooks: Dictionary) -> Dictionary:
	var error := _validate(saved)
	if not error.is_empty(): return {"error":error}
	if not context is Dictionary: return {"error":"Invalid outcome context."}
	for field in ["flags","action","definition77"]:
		if not Numbers._integer(context.get(field),255): return {"error":"Invalid outcome context field: "+field}
	for field in ["effect21","effect22"]:
		if not Numbers._integer(context.get(field),65535): return {"error":"Invalid outcome resource."}
	if not Numbers._integer(context.get("effect_template"),4294967295) or not context.get("effects_disabled") is bool: return {"error":"Invalid outcome effect context."}
	for name in ["event","release","lookup","start","effect"]:
		if not hooks.get(name) is Callable or not hooks[name].is_valid(): return {"error":"Missing outcome helper: "+name}
	var state: Dictionary = saved.duplicate(true)
	for field in BYTE_FIELDS+["health"]: state[field]=int(state[field])
	var result := _call(hooks,"event",state,[10])
	if result.has("error"): return result
	result = _call(hooks,"release",state)
	if result.has("error"): return result
	state.flags15=int(state.flags15)&0xbf
	state.aa=15;state.ab=16;state.a8=15;state.a9=15;state.health=0
	state.ae=int(context.definition77)
	if (int(context.flags)&2)!=0:
		state.aa=16;state.ab=16
		result=_call(hooks,"event",state,[11])
		return result if result.has("error") else {"state":state}
	var mode := (int(state.b7)>>1)&3
	if mode in [2,3]:
		var action := 21 if mode==2 else 22
		if int(context.action)==action:
			result=_select(state,hooks,action,2)
			if result.has("error"): return result
			if result.selected:
				if not context.effects_disabled:
					var parameter: Variant = (int(context.effect_template)&0xffff0000)|200 if mode==2 else null
					result=_call(hooks,"effect",state,[int(context.effect21 if mode==2 else context.effect22),parameter])
					if result.has("error"): return result
				return {"state":state}
		state.b7=int(state.b7)&0xf9
	elif mode==1:
		state.b7=int(state.b7)&0xf9
	result=_select(state,hooks,14,-1)
	if result.has("error"): return result
	if result.selected: return {"state":state}
	result=_select(state,hooks,15,-1)
	if result.has("error"): return result
	state.flags14=(int(state.flags14)&0xfc)|2
	result=_call(hooks,"event",state,[11])
	return result if result.has("error") else {"state":state}
