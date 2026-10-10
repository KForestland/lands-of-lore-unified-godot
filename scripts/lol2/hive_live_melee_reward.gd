extends RefCounted
## Source EXEC scale and mode1 feedback, composed with the modern melee adapter.
## Progression's source health bank remains separate from playable health30.
const Feedback = preload("res://scripts/lol2/hive_sword_feedback.gd")
const Fighting = preload("res://scripts/lol2/hive_reward_application.gd")
static func apply(saved: Dictionary, seed: int, remaining: int, scale: int = -1) -> Dictionary:
	if scale==-1:
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/executioner_melee_reward.json"))
		scale=int(source.scale)
	var checkpoint := saved
	if checkpoint.is_empty():
		var initial: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
		checkpoint = {"version":1,"player":initial.fighting}
	var checked := Fighting.restore(checkpoint)
	if checked.has("error"): return checked
	var prepared := Feedback.reward_seed({"scale":scale,"level":checked.checkpoint.player.level,"remaining":remaining,"special":0})
	if prepared.has("error"): return prepared
	var scaled := Feedback.scale_reward(prepared.base,prepared.difference)
	if scaled.has("error"): return scaled
	var maxima: Array = []
	for level in range(31): maxima.append_array([95,63,63])
	var random := preload("res://scripts/lol2/hive_rune_transaction.gd").draws(seed,maxima)
	var result := Fighting.award_checkpoint(checked.checkpoint,scaled.award,random.values)
	if result.has("error"): return result
	return {"checkpoint":result.checkpoint,"seed":int(random.seeds[result.draws_used]),"award":scaled.award}
