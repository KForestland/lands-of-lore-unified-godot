extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_condition_runtime.gd")
func _initialize() -> void: run.call_deferred()
func read_rows(name: String) -> Variant:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_"+name+"_native.json"))
func run() -> void:
	var core := Runtime.new()
	var actors = read_rows("actor_conditions")
	var players = read_rows("player_conditions")
	var remaining = read_rows("remaining_conditions")
	var adjustments = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_attack/ai_adjustments.json"))
	for n in range(1024):
		var actor: Dictionary = actors[n % actors.size()].duplicate(true)
		var player: Dictionary = players[n].context.duplicate(true)
		var other: Dictionary = remaining[n].context.duplicate(true)
		var before := [actor.duplicate(true),player.duplicate(true),other.duplicate(true)]
		var expected: Array = actor.conditions + players[n].conditions + remaining[n].conditions
		expected.sort()
		var goal := n % 256
		var bank: Array = actor.stats.duplicate()
		var rows: Array = []
		if goal < 14: rows.append(adjustments.goals[goal])
		for index in expected: rows.append(adjustments.conditions[int(index)])
		for row in rows:
			for i in range(30): bank[i] = clampi(int(bank[i])+int(row[i]),0,255)
		var result := core.evaluate(actor.stats,goal,actor,player,other)
		assert(not result.has("error"))
		assert(result.predicate_coverage_complete and not result.live_context_bound)
		assert(result.evaluated == range(49))
		assert(result.conditions.size() == expected.size())
		for i in range(expected.size()): assert(result.conditions[i] == expected[i])
		assert(result.stats == bank)
		result.stats[0] = -1
		assert([actor,player,other] == before)
	var a: Dictionary = actors[0]
	var p: Dictionary = players[0].context
	var r: Dictionary = remaining[0].context
	for field in ["feedback","target_flags","group","flags_b8","flags_b4"]:
		var invalid := a.duplicate(true);invalid.erase(field)
		assert(core.evaluate(a.stats,0,invalid,p,r).has("error"))
	for field in p:
		var invalid := p.duplicate(true);invalid.erase(field)
		assert(core.evaluate(a.stats,0,a,invalid,r).has("error"))
	for field in r:
		var invalid := r.duplicate(true);invalid.erase(field)
		assert(core.evaluate(a.stats,0,a,p,invalid).has("error"))
	assert(core.evaluate(a.stats,256,a,p,r).has("error"))
	assert(core.evaluate([],0,a,p,r).has("error"))
	assert(core.evaluate(a.stats,0,null,p,r).has("error"))
	print("PASS: 1024 composed predicate fixtures, ordered stat effects, missing-context rejection and copy safety")
	quit(0)
