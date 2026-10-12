extends RefCounted
## Native59DAC goal scoring; goal selection precedes action selection.
const Scoring = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const SOURCE := "res://assets/lol2/generated/hive_attack/goal_choice.json"
var _scoring := Scoring.new()

func configure_source() -> String:
	return configure(JSON.parse_string(FileAccess.get_file_as_string(SOURCE)))

func configure(table: Variant) -> String:
	return _scoring.configure(table,14)

func choose(stats: Variant, previous_goal: Variant) -> Dictionary:
	var result := _scoring.choose(stats,previous_goal)
	if result.has("error"): return result
	result.goal = result.action
	result.erase("action")
	return result

func update_pending(saved: Variant, stats: Variant) -> Dictionary:
	if not saved is Dictionary: return {"error":"Invalid pending AI state."}
	for field in ["b5","a9"]:
		if not Numbers._integer(saved.get(field),255): return {"error":"Invalid pending AI field: "+field}
	var state: Dictionary = saved.duplicate(true)
	if (int(state.b5)&1) != 0 or (int(state.b5)&4) == 0: return {"state":state,"chosen":false}
	var result := choose(stats,state.a9)
	if result.has("error"): return result
	state.a9 = result.goal
	return {"state":state,"chosen":true,"choice":result}
