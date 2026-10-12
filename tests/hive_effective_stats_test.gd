extends SceneTree
const Choice = preload("res://scripts/lol2/hive_ai_action_choice.gd")
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var core = Runtime.new()
	var rows = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_effective_stats_native.json"))
	for row in rows:
		var before: Array = row.stats.duplicate()
		var selected: Array = row.conditions.duplicate();selected.reverse()
		var result = core.executioner_effective_stats(row.stats,row.goal,selected)
		assert(not result.has("error"))
		for i in range(30): assert(result.stats[i] == row.expected[i])
		assert(row.stats == before)
		result.stats[0] = -1
		assert(row.stats == before)
	var live = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_ai_conditions_live.json"))
	assert(live.executioner.size()==26)
	var chooser := Choice.new();assert(chooser.configure_source().is_empty())
	for row in live.executioner:
		var effective := core.executioner_effective_stats(row.base_stats,row.effective_goal,row.conditions)
		assert(not effective.has("error"))
		for i in range(30): assert(effective.stats[i]==int(row.stats[i]))
		assert(chooser.choose(effective.stats,row.goal).action==int(row.result))
	var bank: Array = core.executioner_initial_stats(false).stats
	var wander = core.executioner_effective_stats(bank,6,[])
	var attack = core.executioner_effective_stats(bank,4,[])
	assert(Runtime.recompute_attack_stats(wander.stats,30,3,false).base == 15)
	assert(Runtime.recompute_attack_stats(attack.stats,30,3,false).base == 21)
	for goal in [-1,256,true,null,0.5]: assert(core.executioner_effective_stats(bank,goal,[]).has("error"))
	for conditions in [[0,0],[-1],[49],[true],null,[0.5]]:
		assert(core.executioner_effective_stats(bank,6,conditions).has("error"))
	assert(core.executioner_effective_stats([],6,[]).has("error"))
	print("PASS: 512 native effective-stat vectors and26 live condition→bank→choice witnesses; ordering, copy safety and damage recomputation")
	quit(0)
