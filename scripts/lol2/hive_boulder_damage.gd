extends RefCounted
## Source66130 request: player target, null attacker, mask256/flags28/kind4/tag255.
## Caller supplies native mode and defenses; contact scheduling is separate.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const Calculation=preload("res://scripts/lol2/hive_damage_calculation.gd")
static func calculate(context: Variant) -> Dictionary:
	if not context is Dictionary or not Values.integer(context.get("mode"),255): return {"error":"Invalid boulder damage mode."}
	var supplied: Dictionary=context.duplicate(true)
	supplied.amount=3 if int(context.mode)==0 else 20 if int(context.mode)==2 else 10
	supplied.damage_mask=256
	supplied.signature=28
	var result:=Calculation.calculate(supplied)
	if result.has("error"): return result
	result.prepared={"amount":int(supplied.amount),"signature":28,"heading_bonus":false,"attacker":0,"kind":4,"tag":255}
	return result
