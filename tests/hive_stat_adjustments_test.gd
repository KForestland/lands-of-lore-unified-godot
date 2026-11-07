extends SceneTree
const Runtime = preload("res://scripts/lol2/hive_attack_runtime.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_stat_adjustments_native.json"))
	var count := 0
	for group in [data.vectors,data.composed]:
		for vector in group:
			var before := JSON.stringify(vector)
			var result = Runtime.apply_stat_adjustments(vector.stats,vector.rows,vector.events)
			assert(not result.has("error"))
			assert(result.stats.size() == vector.expected.size())
			for i in range(30): assert(result.stats[i] == vector.expected[i],"Native stat byte mismatch")
			assert(JSON.stringify(vector) == before)
			count += 1
	var bank: Array = []
	bank.resize(30);bank.fill(250)
	var plus: Array = []
	plus.resize(30);plus.fill(10)
	var minus: Array = []
	minus.resize(30);minus.fill(-10)
	var rows := {"7":plus,"8":minus}
	var forward := [{"type":"adjustment","operation":7},{"type":"adjustment","operation":8}]
	var reverse := [{"type":"adjustment","operation":8},{"type":"adjustment","operation":7}]
	# Saturating arithmetic is order-sensitive: combining rows first is incorrect.
	assert(Runtime.apply_stat_adjustments(bank,rows,forward).stats[0] == 245)
	assert(Runtime.apply_stat_adjustments(bank,rows,reverse).stats[0] == 250)
	for invalid in [null,true,"0",-1,256,0.5,INF,NAN]:
		var corrupt = bank.duplicate();corrupt[17] = invalid
		assert(Runtime.apply_stat_adjustments(corrupt,rows,forward).has("error"))
	for invalid in [null,true,"0",-129,128,0.5,INF,NAN]:
		var corrupt = plus.duplicate();corrupt[17] = invalid
		assert(Runtime.apply_stat_adjustments(bank,{"7":corrupt},forward).has("error"))
	for invalid in [null,{},[],[1],"bad"]:
		assert(Runtime.apply_stat_adjustments(invalid,rows,forward).has("error"))
	assert(Runtime.apply_stat_adjustments(bank,{},forward).has("error"))
	assert(Runtime.apply_stat_adjustments(bank,rows,[{"type":"adjustment","operation":9}]).has("error"))
	var before := bank.duplicate()
	assert(Runtime.apply_stat_adjustments(bank,rows,forward+[{}]).has("error"))
	assert(bank == before)
	var no_events = Runtime.apply_stat_adjustments(bank,{},[])
	no_events.stats[0] = 0
	assert(bank[0] == 250)
	print("PASS: Hive stat adjustments; ",count," native vectors, order-sensitive saturation, invalid-input isolation")
	quit(0)
