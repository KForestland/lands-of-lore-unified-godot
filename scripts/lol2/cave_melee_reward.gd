extends RefCounted
## Shared melee RNG (key cave_melee_seed) for populations without their own owner
## (cave Roaches, Jungle DINOs, Museum skeletons/Rat); progression and target scales use source rules.
const Reward=preload("res://scripts/lol2/hive_live_melee_reward.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func apply(quests: Dictionary, health: int, damage: int, scale: int) -> Dictionary:
	if health<=0 or damage<=0 or scale<1 or scale>255: return {"error":"Invalid cave melee hit."}
	var seed=quests.get("cave_melee_seed",324508639)
	if not Values.integer(seed,0x7fffffff): return {"error":"Invalid cave melee RNG."}
	var reward:=Reward.apply(quests.get("player_reward_state",{}),int(seed),maxi(0,health-damage),scale)
	if reward.has("error"): return reward
	var next:=quests.duplicate(true)
	next.player_reward_state=reward.checkpoint
	next.cave_melee_seed=reward.seed
	return {"quests":next,"loss":mini(health,damage),"award":reward.award}
