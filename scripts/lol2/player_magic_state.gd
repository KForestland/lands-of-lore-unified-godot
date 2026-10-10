extends RefCounted
## Shared starting mana and validated transport into the existing quest owner.
const Progress = preload("res://scripts/lol2/hive_magic_reward.gd")
static func initial() -> Dictionary:
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/player_progression_initial.json"))
	return Progress.restore({"version":1,"player":source.magic}).checkpoint
static func restore(saved: Variant) -> Dictionary:
	return Progress.restore(saved)
static func transport_error(inventory: Dictionary, quests: Dictionary) -> String:
	if not inventory.has("magic"): return ""
	var incoming := restore(inventory.magic)
	if incoming.has("error"): return incoming.error
	if quests.has("player_magic_reward_state"):
		var existing := restore(quests.player_magic_reward_state)
		if existing.has("error"): return existing.error
		if existing.checkpoint != incoming.checkpoint: return "Conflicting magic handoff states."
	return ""
