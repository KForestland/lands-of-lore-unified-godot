extends RefCounted
## Spark bolts: effects20..23 -> mode2 -> D8B94 magic bank.
## Damage and RNG remain explicit modern combat adapters.
const Planner = preload("res://scripts/lol2/executioner_spell_reward.gd")
const Magic = preload("res://scripts/lol2/hive_magic_reward.gd")
static func apply(saved: Dictionary, seed: int, loss: int, effect: int = 20, scale: int = 8) -> Dictionary:
	if effect not in [20,21,22,23]: return {"error":"Unsupported live Spark effect."}
	var checked := Magic.restore(saved)
	if checked.has("error"): return checked
	var bases: Array = []
	bases.resize(256)
	bases.fill(0)
	for level in 4: bases[20+level] = [12,16,20,25][level] # Source modes/effects in spark-max-effect.md.
	var plan := Planner.plan({"mode":2,"effect":effect,"scale":scale,"loss":loss,"remaining":0,"special":0},{"fighting_level":1,"magic_level":checked.checkpoint.player.level},bases)
	if plan.has("error"): return plan
	var maxima: Array = []
	maxima.resize(31)
	maxima.fill(159)
	var random := preload("res://scripts/lol2/hive_rune_transaction.gd").draws(seed,maxima)
	var result := Magic.award_checkpoint(checked.checkpoint,plan.award,random.values)
	if result.has("error"): return result
	return {"checkpoint":result.checkpoint,"seed":int(random.seeds[result.draws_used]),"award":plan.award}
