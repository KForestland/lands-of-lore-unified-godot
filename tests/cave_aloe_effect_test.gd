extends SceneTree
const Effect = preload("res://scripts/lol2/cave_aloe_effect.gd")
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/cave-aloe-use.json"))
	for row in source.use_cases:
		var r := Effect.use(int(row.pending_before), int(row.event), int(row.consume_gate) != 0)
		assert(r.result == int(row.result) and r.consumed == row.consumed and r.pending == int(row.pending))
	for row in source.tick_cases:
		var r := Effect.tick(row.before)
		for key in ["health", "base", "pending"]: assert(r[key] == int(row.after[key]))
		assert(r.ui == row.after.ui)
	# Boundaries: completion needs health > base+pending, so unclamped 3 -> 9 at 27 units/tick.
	var s := {"health": 3, "maximum": 30, "base": 3, "pending": 0, "pause": 0, "hold": false, "frac": 0, "delta": 0}
	s.pending = Effect.use(s.pending).pending
	var steps := 0
	while s.pending != 0 and steps < 64:
		s = Effect.advance(s, 27)
		steps += 1
	assert(s.health == 9 and s.base == 8 and steps == 7)
	# Clamped to maximum; dead or paused players keep the pending heal.
	s = {"health": 6, "maximum": 8, "base": 6, "pending": 5, "pause": 0, "hold": false, "frac": 0, "delta": 0}
	for i in 8: s = Effect.advance(s, 27)
	assert(s.health == 8 and s.pending == 0)
	for key in ["health", "pause"]:
		s = {"health": 4, "maximum": 8, "base": 4, "pending": 5, "pause": 0, "hold": false, "frac": 0, "delta": 0}
		s[key] = 0 if key == "health" else 1
		for i in 8: s = Effect.advance(s, 27)
		assert(s.pending == 5 and s.health == (0 if key == "health" else 4))
	# Delta is clamped below one clock unit: a full wrap would otherwise heal nothing.
	s = {"health": 3, "maximum": 30, "base": 3, "pending": 5, "pause": 0, "hold": false, "frac": 0, "delta": 0}
	assert(Effect.advance(s, 4096).delta == 4095)
	print("PASS cave aloe effect: %d use, %d tick fixtures" % [source.use_cases.size(), source.tick_cases.size()])
	quit(0)
