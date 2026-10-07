extends RefCounted
## Original EXEC action14/15 lookup and absent explicit action21/22 variants.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func select(actor: Variant, action: Variant, variant: Variant, random_draw: Callable) -> Dictionary:
	if not actor is Dictionary or not Numbers._integer(actor.get("ac"),255) or not Numbers._integer(actor.get("b7"),255): return {"error":"Invalid outcome lookup actor."}
	if not Numbers._integer(action,255) or not (variant is int or variant is float): return {"error":"Invalid outcome action."}
	if int(action) in [21,22] and variant==2: return {"selector":-1,"draws":0}
	if int(action) not in [14,15] or variant!=-1: return {"error":"Unsupported outcome lookup."}
	if not random_draw.is_valid(): return {"error":"Missing outcome random source."}
	# A7D4C captures the mask before A1E44 calls the shared random source.
	var mask := 1 if ((int(actor.b7)>>1)&3)>1 else int(actor.ac)
	var sample: Variant = random_draw.call(actor,100)
	if not Numbers._integer(sample,100): return {"error":"Invalid outcome random result."}
	var selector: int
	if int(action)==14:
		selector=18 if (mask&6)!=0 and (mask&1)==0 else 17
	else:
		selector=20 if (mask&1)!=0 and (mask&6)==0 else 19
	return {"selector":selector,"draws":1}
