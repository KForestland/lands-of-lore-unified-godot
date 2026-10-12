extends RefCounted
## Entry/exit portion of the source rune-room sequence; lighting/effects are separate.
static func initial() -> Dictionary:
	return {"room":"","marker642_enabled":false,"flag286":false,"lights":false,"flag8":false,"flag7":false,"stone_playing":false,"stone_elapsed":0.0,"speech_key":"","speech_elapsed":0.0,"speech_next":"","response_mask":0,"response_seed":324508639,"reward_seed":324508639}
static func validate(value: Variant) -> String:
	if not value is Dictionary or not value.get("room") is String or value.room not in ["","RUNES","RUNECL"]: return "Invalid Hive rune room."
	for key in ["marker642_enabled","flag286"]:
		if not value.get(key) is bool: return "Invalid Hive rune entry state."
	if value.room != "" and not value.marker642_enabled: return "Rune room requires its entry marker."
	for key in ["lights","flag8"]:
		if not value.get(key,false) is bool: return "Invalid rune room flag."
	var seed = value.get("reward_seed",324508639)
	if not preload("res://scripts/lol2/hive_clock_runtime.gd")._integer(seed,0x7fffffff): return "Invalid rune reward RNG."
	if value.room == "RUNECL" and not value.get("lights",false): return "Unlit rune inscription is unavailable."
	var error := preload("res://scripts/lol2/hive_ancient_stone.gd").validate(value)
	return error if not error.is_empty() else preload("res://scripts/lol2/hive_rune_speech.gd").validate(value)
