extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_initial_stats_native.json"))
	var expected: PackedByteArray = data.lookup_hex.hex_decode()
	for first in range(256):
		for second in range(256):
			assert(Runtime.damage_split(data.initial.total,data.initial.minimum,first,second) == expected[first*256+second])
	var core = Runtime.new()
	var fresh = core.executioner_fresh_stats()
	assert(not fresh.has("error") and fresh.a3 == 0 and fresh.base == 15 and fresh.reserve == 15)
	# Fresh construction returns data and must not reset an active/restored attack.
	var before_fresh = core.checkpoint()
	fresh.stats[0] = 255
	assert(core.executioner_fresh_stats().stats[0] == data.initial.stats[0])
	assert(core.checkpoint() == before_fresh)
	for row in data.constructors:
		var actual = core.executioner_initial_stats(row.flag != 0)
		assert(not actual.has("error"))
		assert(actual.base == row.base and actual.reserve == row.reserve)
		for i in range(30): assert(actual.stats[i] == data.initial.stats[i])
		assert(actual.copied_tail == data.initial.copied_tail)
		# Feed the recovered constructor base into the existing source event pipeline.
		var state = core.checkpoint()
		state.selector = 12;state.frame = 6;state.timer = 0;state.base = actual.base
		state.flags = 1;state.gate = true;state.frozen = false
		assert(core.restore(state).is_empty())
		var tick = core.advance_native(1)
		assert(tick.events[0].type == "damage" and tick.events[0].amount == row.request_amount)
		actual.stats[0] = 255
		assert(core.executioner_initial_stats(row.flag != 0).stats[0] == data.initial.stats[0])
	var recalculations = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_stat_recompute_native.json"))
	for row in recalculations:
		var bank: Array = data.initial.stats.duplicate()
		bank[2] = row.second;bank[3] = row.first
		var before := bank.duplicate()
		var result = Runtime.recompute_attack_stats(bank,30,3,row.flag != 0)
		assert(result.base == row.base and result.reserve == row.reserve)
		assert(bank == before)
	# Original operation8 shifts the damage weights; operation7 leaves them alone.
	var adjusted = core.apply_executioner_adjustments(data.initial.stats,[{"type":"adjustment","operation":8}])
	assert(not adjusted.has("error"))
	assert(Runtime.recompute_attack_stats(adjusted.stats,30,3,false).base == 16)
	assert(Runtime.recompute_attack_stats(adjusted.stats,30,3,true).base == 12)
	assert(Runtime.recompute_attack_stats([],30,3,false).has("error"))
	for invalid in [null,true,"1",-1,256,0.5,INF,NAN]:
		assert(Runtime.damage_split(invalid,3,50,50) == -1)
		assert(Runtime.damage_split(30,invalid,50,50) == -1)
		assert(Runtime.damage_split(30,3,invalid,50) == -1)
		assert(Runtime.damage_split(30,3,50,invalid) == -1)
	print("PASS: EXEC initial stats;65536 native damage splits,256 constructors and source damage events;1168 live-bank recalculations")
	quit(0)
