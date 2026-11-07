extends RefCounted
## Script player properties 0x0B/0x0C (native D84D6 → D8A1C fighting, D8B94 magic): value×100 experience,
## through the same accumulation/level loops as combat rewards and the host's existing RNG streams.
const Fighting=preload("res://scripts/lol2/hive_reward_application.gd")
const Magic=preload("res://scripts/lol2/hive_magic_reward.gd")
const Draws=preload("res://scripts/lol2/hive_rune_transaction.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")

## Fighting experience on quests.player_reward_state, RNG quests.cave_melee_seed (shared melee stream).
static func fighting(quests: Dictionary, award: int) -> Dictionary:
	var seed=quests.get("cave_melee_seed",324508639)
	if not Values.integer(seed,0x7fffffff) or award<0 or award>6375: return {"error":"Invalid fighting property award."}
	var checkpoint: Dictionary=quests.get("player_reward_state",{})
	if checkpoint.is_empty():
		var initial: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
		checkpoint={"version":1,"player":initial.fighting}
	var maxima: Array=[]
	for level in range(31): maxima.append_array([95,63,63])
	var random:=Draws.draws(int(seed),maxima)
	var result:=Fighting.award_checkpoint(checkpoint,award,random.values)
	if result.has("error"): return result
	var next:=quests.duplicate(true)
	next.player_reward_state=result.checkpoint
	next.cave_melee_seed=int(random.seeds[result.draws_used])
	return {"quests":next}

## Magic experience on the host magic checkpoint, RNG spark_reward_seed (shared Spark stream).
static func magic(saved: Dictionary, award: int) -> Dictionary:
	var seed=saved.get("spark_reward_seed",324508639)
	if not Values.integer(seed,0x7fffffff) or award<0: return {"error":"Invalid magic property award."}
	var maxima: Array=[];maxima.resize(31);maxima.fill(159)
	var random:=Draws.draws(int(seed),maxima)
	var result:=Magic.award_checkpoint(saved,award,random.values)
	if result.has("error"): return result
	result.checkpoint.spark_reward_seed=int(random.seeds[result.draws_used])
	return {"checkpoint":result.checkpoint}
