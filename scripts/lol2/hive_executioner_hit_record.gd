extends RefCounted
## EXEC36 source kind9 record at archive5907005: mode1, threshold1, predicate54.
## Returns a staged script group; the caller owns predicate state and queue commit.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func evaluate(loss: Variant, predicate: Callable) -> Dictionary:
	if not Numbers._integer(loss,2147483647): return {"error":"Invalid actor hit loss."}
	if int(loss)==0: return {"groups":[],"result":0}
	if not predicate.is_valid(): return {"error":"Missing executioner hit predicate service."}
	var accepted: Variant = predicate.call(54)
	if accepted is Dictionary and accepted.has("error"): return accepted
	if not accepted is bool: return {"error":"Invalid executioner predicate result."}
	return {"groups":[10660] if accepted else [],"result":1 if accepted else 0}

static func evaluate_owner(loss: Variant, owner_state: Variant) -> Dictionary:
	if not Numbers._integer(owner_state,255): return {"error":"Invalid current event owner state."}
	return evaluate(loss,func(_index):return int(owner_state)!=0)

static func apply_group(actor: Variant, counter: Variant) -> Dictionary:
	if not actor is Dictionary or not Numbers._integer(actor.get("a8"),255) or not Numbers._integer(actor.get("b5"),255) or not Numbers._integer(counter,65535):
		return {"error":"Invalid executioner hit group state."}
	var state: Dictionary = actor.duplicate(true)
	state.a8=int(state.a8);state.b5=int(state.b5)
	if state.a8==15: return {"state":state,"counter":int(counter),"applied":false}
	state.b5=(state.b5|12)&254
	return {"state":state,"counter":0,"applied":true}
