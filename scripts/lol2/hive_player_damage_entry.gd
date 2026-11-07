extends RefCounted
## Optional native player entry gates around the supplied damage calculation.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const Damage = preload("res://scripts/lol2/hive_damage_preparation.gd")

static func resolve(event: Variant, context: Variant) -> Dictionary:
	if not context is Dictionary: return {"error":"Invalid player damage context."}
	if context.has("global223d4") or context.has("flags228"):
		for field in ["global223d4","flags228"]:
			if not Numbers._integer(context.get(field),255): return {"error":"Invalid player entry field: "+field}
		if not Numbers._integer(context.get("current"),1000000): return {"error":"Invalid current health."}
		if int(context.global223d4)!=0:
			return {"loss":0,"remaining":int(context.current),"percentage":0,"virtual84":[],"callback":false,"blocked":true}
		if (int(context.flags228)&8)!=0: return {"error":"Player entry requires zero-state continuation."}
	return Damage.resolve_attack(event,context)
