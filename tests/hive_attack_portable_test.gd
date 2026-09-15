extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	# Authored synthetic contract; deliberately different from original clips.
	var contract := {"version":1,"clips":[
		{"selector":11,"frames":3,"interval":10,"events":[]},
		{"selector":12,"frames":4,"interval":10,"events":[
			{"kind":1,"frame":1,"raw_hex":"0101140008004400"},
			{"kind":1,"frame":2,"raw_hex":"0102140008004400"}]}]}
	var core = Runtime.new(contract)
	var initial = core.checkpoint()
	initial.base = 100;initial.flags = 1;initial.gate = true
	assert(core.restore(initial).is_empty())
	assert(core.advance_native(0).events.is_empty())
	var resolve := func(_request): return {"loss":5,"remaining":95,"percentage":5}
	var hit = core.advance_native(20,resolve)
	assert(hit.state.frame == 2 and hit.state.timer == 0 and hit.state.flags == 9)
	assert(hit.events.size() == 4 and hit.events[0].amount == 20)
	assert(hit.events[1].operation == 7 and hit.events[3].operation == 7)
	assert(core.checkpoint().result_count == 2 and core.checkpoint().result_total == 10)
	var restored = Runtime.new(contract)
	assert(restored.restore(JSON.parse_string(JSON.stringify(core.checkpoint()))).is_empty())
	contract.clips[1].frames = 99
	assert(core.advance_native(1).events[0].type == "terminal")
	assert(restored.advance_native(1).events[0].type == "terminal")
	assert(core.restore(initial).is_empty())
	var calls := [0]
	var invalid_second := func(_request):
		calls[0] += 1
		return {"loss":5,"remaining":95,"percentage":5} if calls[0] == 1 else {"remaining":0}
	assert(core.advance_native(20,invalid_second).has("error"))
	assert(core.checkpoint() == initial)
	var old = initial.duplicate();old.version = 1;old.erase("result_count");old.erase("result_total")
	assert(core.restore(old).is_empty() and core.checkpoint().version == 2)
	var bad = initial.duplicate();bad.timer = NAN
	assert(not core.restore(bad).is_empty())
	assert(core.select_attack(11) and not core.select_attack(11))
	var frozen = core.checkpoint();frozen.frozen = true
	assert(core.restore(frozen).is_empty())
	assert(core.advance_native(32767).events.is_empty() and core.checkpoint() == frozen)
	var stats: Array = [];stats.resize(30);stats.fill(250)
	var up: Array = [];up.resize(30);up.fill(10)
	var down: Array = [];down.resize(30);down.fill(-10)
	var events := [{"type":"adjustment","operation":7},{"type":"adjustment","operation":8}]
	assert(Runtime.apply_stat_adjustments(stats,{"7":up,"8":down},events).stats[0] == 245)
	assert(stats[0] == 250)
	assert(Runtime.damage_split(30,3,50,50) == 15)
	assert(Runtime.damage_split(30,3,0,50) == 3)
	assert(Runtime.damage_split(30,3,50,0) == 30)
	assert(Runtime.damage_split(30,3,NAN,50) == -1)
	print("PASS: asset-free combat contract, feedback, rollback, migration, pause and ordered stats")
	quit(0)
