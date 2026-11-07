extends SceneTree
const Step=preload("res://scripts/lol2/floor_motion_step.gd")
func _initialize() -> void:
	var fixture: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/floor_motion_native.json"))
	assert(fixture.passed and fixture.cases.size()==120)
	for row in fixture.cases:
		var s: Dictionary={"height":row.height,"remaining":row.remaining,"fraction":row.fraction,"speed":row.speed}
		assert(Step.valid(s))
		var complete:=Step.advance_one(s,int(row.tick_fixed))
		assert(s.height==row.next_height and s.remaining==row.next_remaining and s.fraction==row.next_fraction)
		assert(complete==(row.next_remaining==0))
		assert(Step.valid(JSON.parse_string(JSON.stringify(s))))
	# Completion emits once; paused caller need not advance. Invalid state cannot mutate.
	var s: Dictionary={"height":-395,"remaining":3,"fraction":0,"speed":100}
	assert(Step.advance_one(s,65536));var finished:=s.duplicate(true)
	assert(not Step.advance_one(s,65536) and s==finished)
	var bad:=s.duplicate(true);bad.fraction=65536;var before:=bad.duplicate(true)
	assert(not Step.valid(bad));assert(not Step.advance_one(bad,65536) and bad==before)
	print("PASS 120 original x86 floor quota/fraction/clamp/height vectors, JSON state and one-shot completion; collision admission and world host remain caller-owned.")
	quit()
