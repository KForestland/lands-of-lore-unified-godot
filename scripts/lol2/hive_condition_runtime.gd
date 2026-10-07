extends RefCounted
## Composes all predicates from a supplied decision snapshot. This does not
## construct live context, select a target, or reproduce the native AI loop.
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
const Player = preload("res://scripts/lol2/hive_player_conditions.gd")
const Remaining = preload("res://scripts/lol2/hive_remaining_conditions.gd")
const Geometry = preload("res://scripts/lol2/hive_condition_geometry.gd")
const Markers = preload("res://scripts/lol2/hive_marker_runtime.gd")
var _attack := Attack.new()
var _remaining := Remaining.new()

func configure_ai_adjustments(profile: Variant) -> String:
	return _attack.configure_ai_adjustments(profile)

func evaluate_with_marker_checkpoint(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant, actor_fixed: Variant, bank: Variant, saved: Variant, control_word: Variant) -> Dictionary:
	var restored := Markers.restore(bank,saved)
	if restored.has("error"): return restored
	return evaluate_with_marker_bank(stats,goal,actor,player,remaining,actor_fixed,bank,restored.checkpoint.actor_marker,restored.checkpoint.selected,control_word)

func evaluate_with_marker_bank(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant, actor_fixed: Variant, bank: Variant, actor_marker: Variant, selected: Variant, control_word: Variant) -> Dictionary:
	var records := Markers.resolve_geometry(bank,actor_marker,selected)
	if records.has("error"): return records
	return evaluate_with_startup_regions(stats,goal,actor,player,remaining,actor_fixed,records.region9,records.point41,control_word)

func evaluate_with_startup_regions(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant, actor_fixed: Variant, region9: Variant, point41: Variant, control_word: Variant) -> Dictionary:
	var bound := Geometry.bind_startup_regions(remaining,actor_fixed,region9,point41,control_word)
	if bound.has("error"): return bound
	var result := evaluate(stats,goal,actor,player,bound.context)
	if not result.has("error"): result.distance9_integer_invalid = bound.integer_invalid
	return result

func evaluate_with_geometry(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant, actor_fixed: Variant, point: Variant, rounding_mode: Variant) -> Dictionary:
	var bound := Geometry.bind_condition41(remaining,actor_fixed,point,rounding_mode)
	if bound.has("error"): return bound
	return evaluate(stats,goal,actor,player,bound.context)

func evaluate_with_regions(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant, actor_fixed: Variant, region9: Variant, point41: Variant, rounding_mode: Variant) -> Dictionary:
	var bound := Geometry.bind_condition9(remaining,actor_fixed,region9,rounding_mode)
	if bound.has("error"): return bound
	var result := evaluate_with_geometry(stats,goal,actor,player,bound.context,actor_fixed,point41,rounding_mode)
	if not result.has("error"): result.distance9_integer_invalid = bound.integer_invalid
	return result

func evaluate(stats: Variant, goal: Variant, actor: Variant, player: Variant, remaining: Variant) -> Dictionary:
	if not actor is Dictionary: return {"error":"Invalid actor condition context."}
	var local := Attack.executioner_actor_conditions(stats, actor.get("feedback"), actor.get("target_flags"), actor.get("group"), actor.get("flags_b8"), actor.get("flags_b4"))
	if local.has("error"): return local
	var player_result := Player.evaluate(player)
	if player_result.has("error"): return player_result
	var other := _remaining.evaluate(remaining)
	if other.has("error"): return other
	var evaluated: Array[int] = []
	var conditions: Array[int] = []
	for subset in [local, player_result, other]:
		for index in subset.evaluated:
			if index in evaluated: return {"error":"Overlapping condition coverage."}
			evaluated.append(index)
		for index in subset.conditions:
			if index not in subset.evaluated or index in conditions:
				return {"error":"Invalid condition coverage."}
			conditions.append(index)
	evaluated.sort()
	if evaluated != range(49): return {"error":"Incomplete condition coverage."}
	conditions.sort()
	var effective := _attack.executioner_effective_stats(stats, goal, conditions)
	if effective.has("error"): return effective
	return {"conditions":conditions, "evaluated":evaluated, "stats":effective.stats,
		"predicate_coverage_complete":true, "live_context_bound":false}
