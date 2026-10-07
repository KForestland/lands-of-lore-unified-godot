extends RefCounted
## Native59EE8 action scoring. Input bank and pending goal are caller-owned.
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")
const SOURCE := "res://assets/lol2/generated/hive_attack/action_choice.json"
var _weights: Array = []
var _goals: Array = []
var _initial_goal_bias: Array = []
var _candidate_count := 15

func configure_source() -> String:
	return configure(JSON.parse_string(FileAccess.get_file_as_string(SOURCE)))

func configure(table: Variant, candidate_count: int = 15) -> String:
	if candidate_count not in [14,15,113]: return "Invalid candidate count."
	if not table is Dictionary: return "Invalid action choice table."
	for field in ["weights","goals"]:
		var rows: Variant = table.get(field)
		if not rows is Array or rows.size() != (30 if field == "weights" else 14): return "Invalid action choice rows."
		for row in rows:
			if not row is Array or row.size() != candidate_count: return "Invalid action choice columns."
			for value in row:
				if not (value is int or value is float) or not is_finite(float(value)) or value != floor(float(value)) or value < -128 or value > 127: return "Invalid signed action weight."
	# Native goal14 indexes the adjacent profile table. Require its pinned row
	# explicitly instead of inventing zeros or silently mapping14 to another goal.
	var initial: Variant=table.get("initial_goal_bias",[])
	if not initial is Array or (not initial.is_empty() and initial.size()!=candidate_count): return "Invalid initial-goal bias."
	for value in initial:
		if not (value is int or value is float) or not is_finite(float(value)) or value!=floor(float(value)) or value < -128 or value > 127: return "Invalid initial-goal weight."
	_candidate_count = candidate_count
	_weights = table.weights.duplicate(true)
	_goals = table.goals.duplicate(true)
	_initial_goal_bias=initial.duplicate()
	return ""

@warning_ignore("integer_division")
func choose(stats: Variant, goal: Variant) -> Dictionary:
	if _weights.is_empty(): return {"error":"Action choice table unavailable."}
	if not stats is Array or stats.size() != 30 or not Numbers._integer(goal,13 if _initial_goal_bias.is_empty() else 14): return {"error":"Invalid action choice context."}
	for value in stats:
		if not Numbers._integer(value,255): return {"error":"Invalid action stat byte."}
	var scores: Array[int] = [];scores.resize(_candidate_count);scores.fill(0)
	var counts: Array[int] = [];counts.resize(_candidate_count);counts.fill(0)
	for row in range(30):
		var value := int(stats[row])
		for candidate in range(_candidate_count):
			var weight := int(_weights[row][candidate])
			if weight == 0: continue
			counts[candidate] += 1
			if weight > 0: scores[candidate] += weight*value
			elif weight < -100: scores[candidate] += (weight*4+400)*value
			else: scores[candidate] -= weight*(255-value)
	var best := 0
	for candidate in range(_candidate_count):
		# Zero totals skip the entire bias/normalization/comparison branch.
		if scores[candidate] == 0: continue
		var bias := int(_initial_goal_bias[candidate] if int(goal)==14 else _goals[int(goal)][candidate])
		if bias == -127:
			scores[candidate] = -9999
			continue
		if bias != 0:
			scores[candidate] += bias*128
			counts[candidate] += 1
		scores[candidate] = scores[candidate]/counts[candidate]
		if scores[candidate] > scores[best]: best = candidate
	return {"action":best,"scores":scores,"contributors":counts}

func update_pending(saved: Variant, stats: Variant) -> Dictionary:
	if _candidate_count != 15: return {"error":"Action profile required."}
	if not saved is Dictionary: return {"error":"Invalid pending AI state."}
	for field in ["b5","a9","ab"]:
		if not Numbers._integer(saved.get(field),255): return {"error":"Invalid pending AI field: "+field}
	var state: Dictionary = saved.duplicate(true)
	if (int(state.b5)&1) != 0 or (int(state.b5)&8) == 0: return {"state":state,"chosen":false}
	var result := choose(stats,state.a9)
	if result.has("error"): return result
	state.ab = result.action
	return {"state":state,"chosen":true,"choice":result}

static func validate_ai_state(saved: Variant) -> String:
	if not saved is Dictionary: return "Invalid AI state."
	for field in ["a8","a9","aa","ab","b8","b9","ba","bb"]:
		if not Numbers._integer(saved.get(field),255): return "Invalid AI field: "+field
	return ""

static func commit_postdecision(saved: Variant, mode: Variant) -> Dictionary:
	return _commit(saved,mode,1,true)

static func commit_animation_boundary(saved: Variant, mode: Variant) -> Dictionary:
	return _commit(saved,mode,2,false)

static func _commit(saved: Variant, mode: Variant, required_mode: int, clear_pending_bit: bool) -> Dictionary:
	var error := validate_ai_state(saved)
	if not error.is_empty(): return {"error":error}
	if not Numbers._integer(mode,255): return {"error":"Invalid AI commit mode."}
	var state: Dictionary = saved.duplicate(true)
	if clear_pending_bit: state.b8 = int(state.b8)&0xfe
	var goal_changed := int(mode)==required_mode and int(state.a8)!=int(state.a9)
	var action_changed := int(mode)==required_mode and int(state.aa)!=int(state.ab)
	if int(mode)==required_mode:
		if goal_changed:
			state.a8 = int(state.a9)
			# The native write clears a full dword, including B9/BA/BB.
			state.b8 = 1;state.b9 = 0;state.ba = 0;state.bb = 0
		state.aa = int(state.ab)
	return {"state":state,"goal_changed":goal_changed,"action_changed":action_changed,"committed":int(mode)==required_mode}
