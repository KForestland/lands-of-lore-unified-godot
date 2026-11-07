extends RefCounted
## Fighting progression earned before Jungle quests exist (cave melee) travels as
## the "fighting" packet, mirroring the "magic" packet. On Jungle arrival it becomes
## quests.player_reward_state/cave_melee_seed, the owners Hive already restores.
const Reward=preload("res://scripts/lol2/hive_reward_application.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const KEYS:=["player_reward_state","cave_melee_seed"]

static func pack(quests: Dictionary) -> Dictionary:
	var result: Dictionary={}
	for key in KEYS:
		if quests.has(key): result[key]=quests[key].duplicate(true) if quests[key] is Dictionary else int(quests[key])
	return result

static func restore(value: Variant) -> Dictionary:
	if not value is Dictionary: return {"error":"Invalid fighting progression."}
	for key in value:
		if not key in KEYS: return {"error":"Invalid fighting progression."}
	var result: Dictionary={}
	if value.has("player_reward_state"):
		var reward:=Reward.restore(value.player_reward_state)
		if reward.has("error"): return reward
		result.player_reward_state=reward.checkpoint
	if value.has("cave_melee_seed"):
		if not result.has("player_reward_state") or not Values.integer(value.cave_melee_seed,0x7fffffff): return {"error":"Invalid cave melee reward RNG."}
		result.cave_melee_seed=int(value.cave_melee_seed)
	return {"checkpoint":result}

## An incoming packet may not silently replace different progression already in quests.
static func transport_error(inventory: Dictionary, quests: Dictionary) -> String:
	if not inventory.has("fighting"): return ""
	var incoming:=restore(inventory.fighting)
	if incoming.has("error"): return incoming.error
	var existing:=restore(pack(quests))
	if existing.has("error"): return existing.error
	for key in incoming.checkpoint:
		if existing.checkpoint.has(key) and existing.checkpoint[key]!=incoming.checkpoint[key]: return "Conflicting fighting handoff states."
	return ""

static func merge(quests: Dictionary, packet: Dictionary) -> void:
	var restored:=restore(packet)
	if restored.has("error"): return
	for key in restored.checkpoint: quests[key]=restored.checkpoint[key]
