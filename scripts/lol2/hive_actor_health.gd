extends RefCounted
## A7A74 setter. Virtual8C reads actor wordB0; definition bytes remain caller inputs.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Stats = preload("res://scripts/lol2/hive_attack_runtime.gd")
static func run(actor: Variant, context: Variant) -> Dictionary:
	if not actor is Dictionary or not context is Dictionary: return {"error":"Invalid actor health context."}
	context=context.duplicate(true)
	if actor.has("b0"):
		if not Numbers._integer(actor.b0,65535): return {"error":"Invalid actor maximum health word."}
		if context.has("maximum") and context.maximum!=actor.b0: return {"error":"Health maximum disagrees with actor wordB0."}
		context.maximum=int(actor.b0)
	for field in ["a8","b5","ac"]:
		if not Numbers._integer(actor.get(field),255): return {"error":"Invalid health actor field: "+field}
	if not Numbers._integer(actor.get("health"),65535): return {"error":"Invalid actor health."}
	var bank := Stats.apply_stat_adjustments(actor.get("stats"),{},[])
	if bank.has("error"): return bank
	for field in ["definition3c","definition7f","mode"]:
		if not Numbers._integer(context.get(field),255): return {"error":"Invalid health context field: "+field}
	if not Numbers._integer(context.get("requested"),4294967295) or not Numbers._integer(context.get("maximum"),65535) or int(context.maximum)==0:
		return {"error":"Invalid health request/maximum."}
	var state: Dictionary = actor.duplicate(true)
	if state.has("b0"): state.b0=int(state.b0)
	for field in ["a8","b5","ac","health"]: state[field]=int(state[field])
	state.stats=bank.stats
	for i in range(30): state.stats[i]=int(state.stats[i])
	if state.a8==15:
		state.health=0
		return {"state":state,"outcome":false,"maximum_calls":0}
	var requested := int(context.requested)
	if requested==0:
		if (int(context.definition3c)&16)!=0: requested=1
		else: return {"state":state,"outcome":(state.b5&1)==0,"maximum_calls":0}
	var health := mini(requested,int(context.maximum))
	if health==state.health: return {"state":state,"outcome":false,"maximum_calls":1}
	state.health=health
	if state.ac==1:
		if health<=int(context.definition7f): state.ac=4 if int(context.mode)==2 else 2
	elif health>int(context.definition7f): state.ac=1
	state.stats[4]=((health*256/int(context.maximum))-1)&255
	return {"state":state,"outcome":false,"maximum_calls":2}

static func initialize_fresh(actor: Variant, source: Variant) -> Dictionary:
	if not actor is Dictionary or not source is Dictionary: return {"error":"Invalid fresh health source."}
	if not Numbers._integer(source.get("requested"),65535) or not Numbers._integer(source.get("maximum"),65535): return {"error":"Invalid fresh health words."}
	var state: Dictionary = actor.duplicate(true)
	state.b0=int(source.maximum)
	state.health=(int(source.requested)+1)&65535
	var context: Dictionary = source.duplicate(true);context.mode=0
	return run(state,context)
