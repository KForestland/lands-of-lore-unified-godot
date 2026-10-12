extends RefCounted
## Original D8B94 magic experience and mana growth. RNG draws supplied by caller.
const CAST_REGEN_SECONDS := 3.0 # Provisional playable regeneration clock.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
static func validate(player: Variant) -> String:
	if not player is Dictionary: return "Invalid magic progression."
	for field in ["experience","maximum","mana"]:
		if not Numbers._integer(player.get(field),0xffffffff): return "Invalid magic progression field: "+field
	if not Numbers._integer(player.get("level"),30): return "Invalid magic level."
	return ""
static func apply_reward(player: Variant, award: Variant, draws: Variant) -> Dictionary:
	var error := validate(player)
	if not error.is_empty(): return {"error":error}
	if not Numbers._integer(award,0xffffffff) or not draws is Array: return {"error":"Invalid magic reward."}
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json"))
	var state: Dictionary = player.duplicate(true)
	for field in ["experience","maximum","mana","level"]: state[field] = int(state[field])
	state.experience = (state.experience+int(award))&0xffffffff
	if state.experience >= 0x7fffffff: state.experience = 0x7ffffff0
	var cursor := 0
	while state.level <= 30 and state.experience >= int(source.thresholds[state.level]):
		if cursor >= draws.size() or not Numbers._integer(draws[cursor],159): return {"error":"Missing or invalid magic reward draw."}
		state.experience -= int(source.thresholds[state.level])
		state.level += 1
		var gain := 11+(int(draws[cursor])>>5)
		state.maximum = (state.maximum+gain)&0xffffffff
		state.mana = (state.mana+gain)&0xffffffff
		cursor += 1
	return {"state":state,"draws_used":cursor,"leveled":state.level != int(player.level)}

static func restore(saved: Variant) -> Dictionary:
	if not saved is Dictionary or not Numbers._integer(saved.get("version"),1) or int(saved.version) != 1: return {"error":"Invalid magic reward checkpoint."}
	var error := validate(saved.get("player"))
	if not error.is_empty(): return {"error":error}
	if saved.has("spell") and saved.spell not in ["spark","heal"]: return {"error":"Invalid selected spell."}
	if saved.has("cooldown") and (not (saved.cooldown is int or saved.cooldown is float) or not is_finite(float(saved.cooldown)) or saved.cooldown<0 or saved.cooldown>0.5): return {"error":"Invalid spell cooldown."}
	if saved.has("regen_elapsed") and (not (saved.regen_elapsed is int or saved.regen_elapsed is float) or not is_finite(float(saved.regen_elapsed)) or saved.regen_elapsed<0 or saved.regen_elapsed>=CAST_REGEN_SECONDS): return {"error":"Invalid mana regeneration clock."}
	if saved.has("spark_reward_seed") and not Numbers._integer(saved.spark_reward_seed,0x7fffffff): return {"error":"Invalid Spark reward RNG."}
	if saved.has("spark_aura"):
		var aura_error := preload("res://scripts/lol2/player_spark_aura_state.gd").validate(saved.spark_aura)
		if not aura_error.is_empty(): return {"error":aura_error}
	var state: Dictionary = saved.player.duplicate(true)
	for field in ["experience","maximum","mana","level"]: state[field] = int(state[field])
	var checkpoint := {"version":1,"player":state}
	if saved.has("spark_reward_seed"): checkpoint.spark_reward_seed=int(saved.spark_reward_seed)
	if saved.has("spell"): checkpoint.spell=saved.spell
	if saved.has("cooldown"): checkpoint.cooldown=float(saved.cooldown)
	if saved.has("regen_elapsed"): checkpoint.regen_elapsed=float(saved.regen_elapsed)
	if saved.has("spark_aura"): checkpoint.spark_aura = preload("res://scripts/lol2/player_spark_aura_state.gd").canonical(saved.spark_aura)
	return {"checkpoint":checkpoint}
static func award_checkpoint(saved: Variant, award: Variant, draws: Variant) -> Dictionary:
	var checked := restore(saved)
	if checked.has("error"): return checked
	var result := apply_reward(checked.checkpoint.player,award,draws)
	if result.has("error"): return result
	result.checkpoint = checked.checkpoint.duplicate(true)
	result.checkpoint.player = result.state.duplicate(true)
	return result
