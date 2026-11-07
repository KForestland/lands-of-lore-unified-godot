extends RefCounted
## Native 5A024 uses the same signed-weight arithmetic as goals/actions, then
## collects every positive spell score in ascending ID order. No admission/RNG.
const Scoring=preload("res://scripts/lol2/hive_ai_action_choice.gd")
var _scoring:=Scoring.new()

func configure(table: Variant) -> String:
	return _scoring.configure(table,113)

func score(stats: Variant, goal: Variant) -> Dictionary:
	# Unlike goal selection, this caller requires an actual goal row (0..13).
	if not Scoring.Numbers._integer(goal,13): return {"error":"Invalid spell scoring goal."}
	var result:=_scoring.choose(stats,goal)
	if result.has("error"): return result
	var candidates: Array[int]=[]
	var maximum:=0
	for spell in range(113):
		var value:=int(result.scores[spell])
		if value>0:
			candidates.append(spell)
			maximum=maxi(maximum,value)
	return {"scores":result.scores,"contributors":result.contributors,"candidates":candidates,"maximum":maximum}
