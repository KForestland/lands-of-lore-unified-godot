extends SceneTree
const Effect = preload("res://scripts/lol2/ancient_stone_effect.gd")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/ancient-stone-use.json"))
	assert(int(source.definition.index) == Effect.DEFINITION)
	assert(int(source.definition.identity) == Effect.IDENTITY)
	assert(int(source.definition.handler) == Effect.HANDLER)
	var saw_last := false
	var saw_keep := false
	var saw_shape26 := false
	var saw_event9 := false
	var saw_masked := false
	for row in source.use_cases:
		var got: Dictionary = Effect.use(int(row.event), int(row.counter), int(row.hold), int(row.flag_42c), int(row.field_400), int(row.flag_42d), int(row.present), int(row.word))
		assert(got.result == int(row.result))
		assert(got.consumed == row.consumed and got.release == row.release and got.presentation == row.presentation)
		assert(got.counter == int(row.counter_after) and got.shape == int(row.shape))
		var args: Array = got.presentation_args
		var expect: Array = row.presentation_args
		assert(args.size() == expect.size())
		for i in args.size():
			assert(int(args[i]) == int(expect[i]))
		if int(row.event) == 1 and int(row.counter) == 8 and int(row.result) == 1:
			saw_last = true
		if int(row.hold) == 255 and int(row.event) == 1 and int(row.counter) == 0 and int(row.result) == 1 and not got.consumed:
			saw_keep = true
		if int(row.shape) == 0x26:
			saw_shape26 = true
		if int(row.event) == 9 and int(row.counter) == 8 and int(row.result) == 1:
			saw_event9 = true
		if int(row.present) == 0xfe and got.presentation:
			saw_masked = true
	assert(saw_last and saw_keep and saw_shape26 and saw_event9 and saw_masked)
	var counter := 0
	for step in source.sequence.steps:
		var step_result: Dictionary = Effect.use(1, counter, 0)
		assert(step_result.result == 1 and step_result.consumed and step_result.counter == int(step.counter_after) and step_result.shape == 0x25)
		counter = step_result.counter
	var closed: Dictionary = Effect.use(1, counter, 0)
	assert(counter == int(source.sequence.closed_counter) and closed.result == 0 and closed.counter == 9 and not closed.consumed and closed.shape == -1)
	assert(Effect.use(0, 0, 0).result == 0 and Effect.use(2, 0, 0).result == 0)
	assert(Effect.use(8, 0, 0).counter == 0 and Effect.use(10, 8, 0).result == 0)
	assert(Effect.use(1, 9, 0).result == 0 and Effect.use(9, 255, 0).counter == 255)
	var kept: Dictionary = Effect.use(9, 8, 1, 0, 5, 0, 0, 0xffff)
	assert(kept.result == 1 and not kept.consumed and kept.counter == 9 and kept.shape == 0x27 and kept.presentation)
	assert(kept.presentation_args == [0x23c68, 0xffff, 0, 0, 1])
	var indexed: Dictionary = Effect.use(1, 0, 255, 0x80, 5, 0x7f, 2)
	assert(indexed.result == 1 and not indexed.consumed and indexed.counter == 1 and indexed.shape == 0x26 and indexed.presentation)
	var quiet: Dictionary = Effect.use(1, 0, 1, 0, 0, 0, 1)
	assert(quiet.result == 1 and not quiet.consumed and quiet.counter == 1 and quiet.shape == 0x25 and not quiet.presentation)
	print("PASS ancient stone effect: %d use fixtures, gate closes at %d" % [source.use_cases.size(), closed.counter])
	quit(0)
